#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= authn

Authentication answers one question, who is calling, and this chapter
builds every piece of the answer in `pyapi/authn/`, one package
mirroring the go lane's `internal/authn`: pbkdf2 password storage with
parameters carried in the hash string, a login path flattened so
unknown emails and wrong passwords cost the same, sessions with
rotation and reuse detection, the cookie line the vectors freeze, and
the HS256 jwt hand-rolled over `hmac` plus `hashlib`.

== password storage with pbkdf2

Passwords are never stored, only proofs that cost an attacker real
time to reproduce. The platform's answer is `hashlib.pbkdf2_hmac`,
salted sha256 iterated 210000 times to derive a 32 byte key from a 16
byte salt, the frozen contract's tier, with `ISSUE_ITERATIONS` at
210000 asserted structurally and never run in tests,
`TEST_ITERATIONS` at 2000 exercising the identical path, and the salt
source a seam:

#listing("python/api/pyapi/authn/password.py", first: 37, last: 50, caption: [one hash: fresh salt, contract iterations, phc-style rendering])

Iteration count is the whole defense. A single sha256 over a password
is microseconds on a gpu, while two hundred ten thousand sequential
rounds move each guess into the tens of milliseconds, and the store
thief pays the same because the count travels inside the string.

#diagram([pbkdf2: the salt and iteration count ride beside the derived key], length: 13pt, {
  cdraw.rect((1.2, 5.6), (11.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.1, 7.6), [pbkdf2 hmac sha256], size: 6.5pt)
  cdraw.content((6.1, 6.6), [210000 rounds, sequential,], size: 6pt)
  cdraw.content((6.1, 5.8), [16 byte salt in, 32 byte key out], size: 6pt)
  cdraw.line((2.2, 8.2), (2.2, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.4, 8.8), [password plus salt, every round], size: 6pt)
  cdraw.rect((12.4, 5.6), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((17.3, 7.6), [encoded string], size: 6.5pt)
  cdraw.content((17.3, 6.6), [dollar pbkdf2-sha256 i=..., l=...], size: 6pt)
  cdraw.content((17.3, 5.8), [salt and key, base64], size: 6pt)
  cdraw.line((11.2, 6.9), (12.2, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.3, 4.4), [verify parses and re-derives, constant time], size: 6pt)
})

== the phc string and the memory-hard alternative

The encoded string is the contract between hashing today and
verifying years later. This service uses the phc style,
`$pbkdf2-sha256$i=210000,l=32$salt$key` with salt and key in standard
base64, so verification replays the exact parameters the hash was
written with, never today's defaults. the parameters ride the string
rather than the code's opinion, which is what a future tier change
would turn: a new hash carries its own count and verifies beside the
old ones, at the cost of a rehash on login this vehicle deliberately
does not build:

#listing("python/api/pyapi/authn/password.py", first: 51, last: 65, caption: [verify re-derives under the string's parameters and compares in constant time])

The parse refuses what an attacker would plant in a stolen row,
absurd iterations, absurd key lengths, base64 that fails
`validate=True`, a tiny salt, all answered with the same false a
wrong password gets: verification failure is a boolean fact, never a
signal about which check failed. Argon2id is the construction the
industry moved to, worth decomposing though this vehicle never
imports it. Parameters, salt, and output length compress into a first
block, lanes fill a large memory array by compressing the previous
block with a referenced block from an earlier lane, each extra pass
re-reads the array in a different order, and shrinking the array
breaks the compression chain, so a gpu pays the memory traffic a cpu
pays. The standard library ships none of it, so argon2 arrives
through `argon2-cffi` and its kin, dated meta.

#diagram([the phc string: parameters, salt, and key all travel together], length: 13pt, {
  let part(x0, x1, label) = {
    cdraw.rect((x0, 6.2), (x1, 8.0), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 7.1), label, size: 6pt)
  }
  part(0.8, 4.4, [pbkdf2-sha256])
  part(4.8, 9.6, [i=210000, l=32])
  part(10.0, 16.0, [salt, base64])
  part(16.4, 22.4, [key, base64])
  cdraw.content((11.5, 5.0), [the string is the contract: verify replays these parameters, never defaults], size: 6pt)
})

== login and timing flattening

A login endpoint that answers fast for unknown emails and slowly for
wrong passwords hands out an account census to anyone with a
stopwatch. The flattening fix sits in the unknown-email branch: run
the same pbkdf2 verification the wrong-password path runs, against a
dummy hash computed once at construction, discard the result, and
answer the identical bytes:

#listing("python/api/pyapi/authn/routes.py", first: 139, last: 158, caption: [both failure branches answer the same 401 after the same work])

Both branches raise the same envelope, so the only observable
difference left is network jitter. The success path runs on through
`issue`, which mints the session, refresh token, cookie, and access
token in one place: prove, then issue.

#diagram([the timing-equalized login: unknown email pays what a wrong password pays], length: 13pt, {
  cdraw.content((5.0, 8.9), [known email], size: 6.5pt)
  cdraw.rect((1.6, 6.9), (8.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 7.7), [pbkdf2 verify,], size: 6pt)
  cdraw.content((5.0, 6.8), [mismatch], size: 6pt)
  cdraw.content((16.4, 8.9), [unknown email], size: 6.5pt)
  cdraw.rect((13.0, 6.9), (19.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.4, 7.7), [pbkdf2 verify on,], size: 6pt)
  cdraw.content((16.4, 6.8), [the dummy hash], size: 6pt)
  cdraw.line((5.0, 6.6), (10.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.4, 6.6), (11.9, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.4, 3.4), (16.2, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.3, 4.7), [identical 401 bytes], size: 6.5pt)
  cdraw.content((11.3, 3.8), [invalid credentials, same latency], size: 6pt)
  cdraw.content((11.3, 2.3), [a stopwatch learns nothing about which branch ran], size: 6pt)
})

== server-side sessions

A session is the server's own record of one login: an id, the user,
the expiry, a revoked flag, and the sha256 of the current refresh
token, never the token itself, so a stolen store dump cannot be
replayed live:

#listing("python/api/pyapi/authn/session.py", first: 52, last: 69, caption: [the session record and the one time policy both channels share])

The lifetime rules stay with the caller, on purpose: the store knows
which token is current and which session is revoked, the service
applies the time policy through `alive`, so every expiry test is pure
arithmetic on an injected clock. The store is one lock over a session
map and a token map, and it keeps superseded records because
presenting one is the theft signal rotation builds on.

#diagram([the session lifecycle: login creates, refresh extends, logout or reuse revokes], length: 13pt, {
  let state(x, y, label, fill) = {
    cdraw.rect((x - 2.1, y - 0.55), (x + 2.1, y + 0.55), fill: fill, radius: 0.02)
    cdraw.content((x, y), label, size: 6.5pt)
  }
  state(3.4, 7.8, [absent], luma(235))
  state(11.5, 7.8, [alive], luma(222))
  state(19.6, 7.8, [revoked], luma(205))
  cdraw.line((5.5, 7.8), (9.4, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.4, 8.5), [login], size: 6pt)
  cdraw.line((13.6, 7.8), (17.5, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((15.5, 8.5), [logout, reuse], size: 6pt)
  cdraw.content((11.5, 5.8), [refresh rotates the token and extends expiry], size: 6pt)
  cdraw.content((11.5, 4.8), [every path checks: not revoked, not expired], size: 6pt)
})

== cookie mechanics

The browser carries the refresh token in a cookie, and the cookie's
attributes are its entire protection: Path scopes it to the api tree,
HttpOnly keeps scripts from reading it, Secure keeps it off plain
http, SameSite Lax blocks cross-site posts while allowing top-level
navigation.

#listing("python/api/pyapi/authn/cookie.py", first: 13, last: 35, caption: [the line builders and the incoming reader, plain templates])

The attribute line is frozen by the vectors, order included, and the
stdlib `http.cookies` is the one place the platform and the contract
disagree: it prints a fixed order of its own, alphabetical,
`HttpOnly; Path; SameSite; Secure`, identical in meaning and
different in bytes from the vector's `Path; HttpOnly; Secure;
SameSite`, so the vectors win and the builders are plain templates.
Logout clears with Max-Age 0 rendered exactly.

#diagram([the cookie attribute matrix: what each one stops], length: 13pt, {
  let row(y, attr, threat, verdict) = {
    cdraw.content((3.6, y), attr, size: 6pt)
    cdraw.content((11.4, y), threat, size: 6pt)
    cdraw.content((18.4, y), verdict, size: 6pt)
  }
  cdraw.content((3.6, 9.2), [attribute], size: 6.5pt)
  cdraw.content((11.4, 9.2), [stops], size: 6.5pt)
  cdraw.content((18.4, 9.2), [scope], size: 6.5pt)
  row(8.1, [Path /api], [leak on sibling paths], [one tree])
  row(7.0, [HttpOnly], [script exfiltration], [read denied])
  row(5.9, [Secure], [plaintext transit], [https only])
  row(4.8, [SameSite Lax], [cross-site post], [top nav only])
  cdraw.content((11.5, 3.3), [four attributes, four attacks, zero javascript visible], size: 6pt)
})

== jwt from scratch with hmac

A json web token is three base64url parts, header, claims, signature,
and the whole format fits in two functions of primitives the standard
library owns. HMAC-SHA256 signs the first two segments with a shared
secret, verification recomputes and compares in constant time, and
the claim rules run after the signature, never before:

#listing("python/api/pyapi/authn/jwt.py", first: 64, last: 79, caption: [sign HS256, no library, hmac plus hashlib plus base64])

The claims dict is built in a fixed order, exp, iat, iss, sid, sub,
so the serialized form is deterministic and the golden test
reproduces the frozen vector's token exactly, signature included.
There is no roles claim on purpose: authorization reads the store,
and the sid claim makes every token revocable by killing one session
row. The parser kills the classics: the alg pin runs before anything
trusts a payload byte, tampering and wrong secrets fail the
constant-time compare, and the caller always gets one 401.

#diagram([three segments, the signature covers exactly the first two], length: 13pt, {
  cdraw.rect((0.8, 5.4), (6.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.6), [header], size: 6.5pt)
  cdraw.content((3.6, 6.6), [alg, typ], size: 6pt)
  cdraw.content((3.6, 5.8), [base64url], size: 6pt)
  cdraw.rect((7.2, 5.4), (14.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.7, 7.6), [claims], size: 6.5pt)
  cdraw.content((10.7, 6.6), [exp iat iss sid sub], size: 6pt)
  cdraw.content((10.7, 5.8), [base64url, fixed order], size: 6pt)
  cdraw.rect((15.0, 5.4), (22.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((18.5, 7.6), [signature], size: 6.5pt)
  cdraw.content((18.5, 6.6), [hmac sha256 of], size: 6pt)
  cdraw.content((18.5, 5.8), [header dot claims], size: 6pt)
  cdraw.content((11.5, 4.3), [dots included, padding stripped, alg pinned before payload reads], size: 6pt)
})

== the asymmetric variant in prose

HMAC has one secret and both sides hold it, so whoever can verify
tokens can also mint them, fine in one process and the reason the
issued lane stays HS256. When verification spreads, EdDSA over
ed25519 earns its complexity: the private key signs, the public key
verifies, and the verification side provably cannot forge. The
standard library ships no ed25519, so this vehicle signs nothing with
it and the `cryptography` package is dated meta. The algorithm is the
only part that changes, the envelope and habits are shared, and this
is the entire surface that would fork:

#listing("python/api/pyapi/authn/jwt.py", first: 108, last: 120, caption: [the claim rules both algorithms share, issuer then expiry])

The header still pins the algorithm, so the alg confusion attack dies
before any payload byte is read.

#diagram([shared secret versus split key: who can mint, who can check], length: 13pt, {
  cdraw.content((5.4, 8.9), [HS256], size: 6.5pt)
  cdraw.rect((1.0, 6.6), (9.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 7.7), [one secret, both sides], size: 6pt)
  cdraw.content((5.4, 6.8), [verifier can mint], size: 6pt)
  cdraw.content((16.8, 8.9), [EdDSA], size: 6.5pt)
  cdraw.rect((12.4, 6.6), (21.2, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((16.8, 7.7), [private signs, public verifies], size: 6pt)
  cdraw.content((16.8, 6.8), [verifier cannot mint], size: 6pt)
  cdraw.content((11.5, 5.0), [one process, one signer: the issued lane stays HS256], size: 6pt)
})

== the refresh rotation and reuse detection

Access tokens live fifteen minutes, the refresh token is the
long-lived credential, and it rotates on every use. Rotation means
the store remembers the token it just retired, marked superseded,
because presenting a superseded token is the strongest theft signal
the design gets: the holder moved on, so someone else is replaying.
The answer is family revocation, the replay and its successor die
together:

#listing("python/api/pyapi/authn/session.py", first: 108, last: 125, caption: [rotate: superseded tokens revoke the family, unknown ones miss])

The vector pair pins the whole story. Refresh at plus twenty returns
a new cookie and a new token with the same session id. Replay the old
cookie at plus twenty-one and both die: the replay and the successor
both answer 401 session revoked, a second apart. A thief gets one
use, then loses the family with the victim.

#diagram([the refresh family: rotation forks, reuse revokes everything], length: 13pt, {
  let state(x, y, label, fill) = {
    cdraw.rect((x - 2.3, y - 0.55), (x + 2.3, y + 0.55), fill: fill, radius: 0.02)
    cdraw.content((x, y), label, size: 6.5pt)
  }
  state(3.4, 7.8, [token A issued], luma(235))
  state(11.5, 7.8, [token B current], luma(222))
  state(19.6, 7.8, [family revoked], luma(205))
  cdraw.line((5.7, 7.8), (9.2, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.4, 8.5), [refresh, A retired], size: 6pt)
  cdraw.line((13.8, 7.8), (17.3, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((15.5, 8.5), [B replayed next], size: 6pt)
  cdraw.line((3.4, 7.1), (17.3, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.0, 6.1), [A replayed: theft signal], size: 6pt)
  cdraw.content((11.5, 4.5), [either replay revokes the session row, every token dies], size: 6pt)
})

== testing auth without walls

Every time-dependent behavior here is tested as math: the clock is
one attribute moved by hand, the id source hands out the vector's
uuids, and the random source is a re-armed iterator over the vector's
32 byte tokens, so the sid claim, the refresh token, and the
Set-Cookie line reproduce the frozen vector byte for byte:

#listing("python/api/tests/test_authn_routes.py", first: 37, last: 47, caption: [a strict double that counts verifies, the flatten as a measured fact])

No test sleeps, no test opens a socket, and the test tier keeps the
suite under a second. The request_id column of the 401 bodies is
pinned through the kernel's client header resolution, so even failure
envelopes compare byte for byte.

#diagram([an auth golden test: fixed inputs in, frozen bytes out], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vectors 04 07 08], [clock offsets,], [token bytes], luma(235))
  stage(6.0, [injected], [ids, random source,], [counting hasher], luma(235))
  stage(11.4, [login refresh], [dispatch,], [no socket], luma(235))
  stage(16.8, [assert], [cookie, token,], [401 bytes], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [signature, cookie line, and failure bytes all exact], size: 6pt)
})

sources: docs.python.org/3/library/hashlib.html for pbkdf2_hmac,
docs.python.org/3/library/hmac.html for compare_digest,
docs.python.org/3/library/base64.html for urlsafe_b64encode and
validate, docs.python.org/3/library/secrets.html for token_bytes, and
docs.python.org/3/library/http.cookies.html for the attribute order,
all accessed 2026-09-27 against the pinned cpython 3.14.7, with RFC
8018, RFC 7519, the phc format at github.com/P-H-C/phc-string-format,
RFC 9106, and cheatsheetseries.owasp.com. Verified by
`tests/test_authn.py` and `tests/test_authn_routes.py` under
`make verify-pyapi`, 29 tests green, ruff clean at 88 columns.
