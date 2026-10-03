#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= authn

Authentication answers one question, who is calling, and this chapter
builds every piece of the answer: pbkdf2 password storage with
parameters carried in the hash string, a login path flattened so
unknown emails and wrong passwords cost the same, server-side
sessions behind a store port, the cookie that carries the refresh
token, HS256 and ES256 json web tokens built from cryptographic
primitives rather than a library, rotation with reuse detection on
the refresh family, and the injected-clock test discipline that keeps
all of it fast.

== password storage with pbkdf2

Passwords are never stored, only proofs that cost an attacker real
time to reproduce. The BCL's answer is Rfc2898DeriveBytes.Pbkdf2 over
HMAC-SHA256, and the parameter set travels inside the encoded string,
so verification replays the exact parameters the hash was written
with, never today's defaults:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/Pbkdf2Hasher.cs", first: 48, last: 59, caption: [a fresh salt, one derive call, one PHC-style string])

The issue tier is 210000 iterations, 16 salt bytes, a 32 byte key,
the values the frozen contract pins for this lane. The OWASP cheat
sheet read the same day recommends 600000 iterations for
pbkdf2-hmac-sha256, and the lane sits below it on purpose: the
tier is frozen cross-lane vector bytes, and the honesty lives in the
PHC string carrying its own parameters, not in chasing a guidance
table. The test tier is a
separate named constant, 2000 iterations, a confession that keeps
every hash in the suite instant while exercising the identical code
path, and a structural test pins the production floor without ever
running it, so the tier cannot silently decay. Verification parses
the string, re-derives under the carried parameters, and compares in
constant time, and malformed strings answer false without throwing,
so a stolen store row cannot force absurd work through crafted
parameters: the parser caps both iteration count and key length.

The memory-hard alternative deserves its name even though the BCL
does not ship it. Argon2id is a schedule over a primitive, not a new
primitive: each lane fills its strip of a memory array by compressing
the previous block and a referenced block from an earlier lane, and
each pass re-reads and re-compresses the whole array in a different
order. The memory hardness is the schedule's property, an attacker
who shrinks the array cannot answer the compression chain, and the
parameter string is the same PHC shape, dollar argon2id v 19 m t p
salt hash. The platform gap is real, the BCL ships no argon2, so the
c\# community reaches for a third-party package while this vehicle
stays on the platform's pbkdf2 and states the maintenance tradeoff
the suite chapter returns to.

#diagram([pbkdf2: one hmac chain, parameters riding in the string], length: 13pt, {
  cdraw.rect((1.2, 5.6), (11.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.1, 7.6), [derive loop], size: 6.5pt)
  cdraw.content((6.1, 6.6), [210000 hmac rounds,], size: 6pt)
  cdraw.content((6.1, 5.8), [fresh 16 byte salt], size: 6pt)
  cdraw.line((2.2, 8.2), (2.2, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.4, 8.8), [password plus salt in], size: 6pt)
  cdraw.rect((12.4, 5.6), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((17.3, 7.6), [encoded string], size: 6.5pt)
  cdraw.content((17.3, 6.6), [dollar pbkdf2-sha256 i, l], size: 6pt)
  cdraw.content((17.3, 5.8), [salt and key, base64], size: 6pt)
  cdraw.line((11.2, 6.9), (12.2, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [verify parses the string and re-derives, constant time], size: 6pt)
})

== login and timing flattening

A login endpoint that answers fast for unknown emails and slowly for
wrong passwords hands out an account census to anyone with a
stopwatch. The flattening fix sits in the unknown-email branch: run
the same pbkdf2 verification the wrong-password path runs, against a
dummy hash computed once at service construction, discard the result,
and answer the identical bytes:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/AuthnEndpoints.cs", first: 47, last: 70, caption: [both failure branches answer the same 401 after the same work])

Both branches return the same envelope, code, message, and no
distinguishing header, and the counting hasher in the tests proves
the dummy verify ran on the unknown-email path: two verifies for two
failed logins, one real, one dummy, no matter which branch each
request took. The success path runs on through Issue, which mints the
session row, the refresh token, the cookie, and the access token in
one place, so login stays readable as two facts: prove, then issue.

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
token. The token itself is never stored, only its hash, so a stolen
store dump cannot be replayed against the live service. The store
port mirrors the user store's: an interface frozen here, the
in-memory implementation in this chapter, the sqlite implementation
the store chapter already ships against the same seam:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/ISessionStore.cs", first: 37, last: 51, caption: [the session store port: five verbs, four outcomes])

The lifetime rules stay with the caller, on purpose. The store knows
structural state, which token is current, which session is revoked;
the service reads the clock and applies the policy, a session counts
as alive while not revoked and not expired. That split keeps the
engine implementation free of clock reads and makes every expiry test
pure arithmetic on an injected clock.

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
  cdraw.content((11.5, 6.4), [refresh rotates the token and extends expiry], size: 6pt)
  cdraw.content((11.5, 5.5), [every path checks: not revoked, not expired], size: 6pt)
  cdraw.content((11.5, 4.6), [the store hashes, the service reads the clock], size: 6pt)
})

== cookie mechanics

The browser carries the refresh token in a cookie, and the cookie's
attributes are its entire protection. Path scopes it to the api tree
so it never rides on requests to other origins hosted beside the
service. HttpOnly keeps scripts from reading it, so an injected
snippet cannot exfiltrate what it cannot see. Secure keeps it off
plain http. SameSite Lax blocks the cookie on cross-site posts while
allowing ordinary top-level navigation. The line is rendered by hand,
not through the framework's cookie writer, because the attributes are
the contract and the frozen vector freezes their order and spacing:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/SessionCookie.cs", first: 19, last: 31, caption: [set and clear: four attributes, one exact line each])

Logout clears it with Max-Age 0 rendered exactly, and the attributes
stay set so the deletion overwrites the exact cookie it replaces. The
tests assert the whole Set-Cookie line byte for byte against the
frozen vectors, attributes, order, and semicolons included.

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
and the whole format fits in two functions of cryptographic
primitives. HMAC-SHA256 signs the first two segments with a shared
secret, verification recomputes and compares in constant time, and
the claim rules run after the signature, never before:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/Jwt.cs", first: 28, last: 38, caption: [sign and verify HS256, no library, two primitives])

The claims record is small and alphabetical by declaration, exp, iat,
iss, sid, sub, which makes the serialized form deterministic, the
same bytes for the same facts, so the golden test reproduces the
frozen vector's token exactly, signature included: the login test at
plus ten seconds emits the vector's access token byte for byte under
the fixed test secret. There is no roles claim on purpose:
authorization reads the store, and the sid claim makes every
outstanding token revocable by killing one session row. The parser
refuses what the classics try: an alg none header never reaches the
payload, the alg pin runs before any payload byte is trusted, a
tampered claim fails the constant-time compare, and an expired or
foreign-iss token fails the claim checks with its own failure codes.

#diagram([three segments, the signature covers exactly the first two], length: 13pt, {
  cdraw.rect((0.8, 5.4), (6.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.6), [header], size: 6.5pt)
  cdraw.content((3.6, 6.6), [alg, typ], size: 6pt)
  cdraw.content((3.6, 5.8), [base64url], size: 6pt)
  cdraw.rect((7.2, 5.4), (14.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.7, 7.6), [claims], size: 6.5pt)
  cdraw.content((10.7, 6.6), [exp iat iss sid sub], size: 6pt)
  cdraw.content((10.7, 5.8), [base64url, sorted keys], size: 6pt)
  cdraw.rect((15.0, 5.4), (22.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((18.5, 7.6), [signature], size: 6.5pt)
  cdraw.content((18.5, 6.6), [hmac sha256 of], size: 6pt)
  cdraw.content((18.5, 5.8), [header dot claims], size: 6pt)
  cdraw.content((11.5, 4.3), [dots included, padding stripped, alg pinned before payload reads], size: 6pt)
})

== the asymmetric token over ecdsa

HMAC has one secret and both sides hold it, so whoever can verify
tokens can also mint them. In one process that is fine, and it is why
the issued lane stays HS256: one signer, one verifier, one binary.
The moment verification spreads, a public-key scheme earns its
complexity, and the platform's asymmetric lane here is ECDsa:
the private key signs, the public key verifies, and the verification
side provably cannot forge:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/Jwt.cs", first: 40, last: 54, caption: [the same envelope, an ES256 signature over a split key])

The two readers cross-check each other in the tests: an HS256 reader
refuses the ES256 token on the alg pin, the ES256 reader refuses the
HS256 token the same way, so the algorithm confusion attack, present
a token signed with the algorithm the attacker prefers, dies at the
header. The claim checks are shared, so issuer, expiry, and the
constant-time habits do not fork between algorithms.

EdDSA is the construction to reach for where the platform provides
it, and it decomposes the same way: Ed25519 is a Schnorr signature
over the twisted Edwards curve25519 with SHA-512, and the nonce is
derived deterministically from the key's hash prefix and the message,
so signing never reads a random generator. The gap that rules this
lane: Windows cryptography has no EdDSA at all, verified against the
platform docs, so the BCL cannot offer it here, and ES256 over a
NIST curve is the platform's answer. The lesson stands either way:
the envelope, the pin, and the claim rules are the design, the curve
is a parameter.

#diagram([shared secret versus split key: who can mint, who can check], length: 13pt, {
  cdraw.content((5.4, 8.9), [HS256], size: 6.5pt)
  cdraw.rect((1.0, 6.6), (9.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 7.7), [one secret, both sides], size: 6pt)
  cdraw.content((5.4, 6.8), [verifier can mint], size: 6pt)
  cdraw.content((16.8, 8.9), [ES256], size: 6.5pt)
  cdraw.rect((12.4, 6.6), (21.2, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((16.8, 7.7), [private signs, public verifies], size: 6pt)
  cdraw.content((16.8, 6.8), [verifier cannot mint], size: 6pt)
  cdraw.content((11.5, 5.4), [one binary, one signer: the issued lane stays HS256], size: 6pt)
  cdraw.content((11.5, 4.5), [split the process, split the key: verification scales alone], size: 6pt)
})

== the refresh rotation and reuse detection

Access tokens live fifteen minutes, the refresh token is the
long-lived credential, and it rotates on every use. Rotation means
the store remembers the token it just retired, marked superseded,
because presenting a superseded token is the strongest theft signal
the design gets: the legitimate holder moved on, so someone else is
replaying. The answer is family revocation, the replayed token and
its successor die together:

#listing("csharp-net/api/src/CsharpBook.Api/Authn/AuthnService.cs", first: 106, last: 126, caption: [refresh: expired sessions stay dead, rotation revokes on reuse])

The vector pair pins the whole story. Refresh at plus twenty returns
a new cookie and a new access token. Replay the old cookie at plus
twenty-one and both die: the replay answers 401 session revoked, and
the successor, still perfectly formed, answers 401 session revoked
one second later. An attacker who stole the token before the holder
refreshed gets one use, then loses the family along with the victim.
An expired but never-rotated session does not come back to life
either: the expiry check runs before the rotation attempt and answers
invalid credentials.

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
  cdraw.content((11.5, 4.9), [either replay revokes the session row, every token dies], size: 6pt)
  cdraw.content((11.5, 4.0), [the thief and the victim both hold dead strings], size: 6pt)
})

== testing auth without walls

Every time-dependent behavior here is tested as math. The clock is a
stepped TimeProvider, so token expiry is one addition. The id source
hands out the vector's uuids, so the sid claim lands exact. The
refresh token source is scripted, so the cookie line and the access
token reproduce the frozen vector byte for byte, and a counting
hasher proves the dummy verify ran on the unknown-email path:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Authn/AuthnApiVectorTests.cs", first: 99, last: 112, caption: [the vector login: cookie line, rate headers, and token body all exact])

No test sleeps, no test opens a socket, and the whole service runs
over TestServer, the framework's in-memory host, the same pipeline
production traffic takes. The session store tests rotate one token
from eight concurrent callers and assert exactly one winner, the
token reader is probed with garbage, alg none, tampered payloads, and
foreign issuers, and the two algorithm readers refuse each other's
tokens. When the vectors change the code is wrong, and nothing in
this chapter has a second source of truth to drift toward.

#diagram([an auth golden test: fixed inputs in, frozen bytes out], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vectors 04 05 07 08], [clock offsets,], [token bytes], luma(235))
  stage(6.0, [injected], [ids, refresh tokens,], [counting hasher], luma(235))
  stage(11.4, [login refresh], [test server,], [no socket], luma(235))
  stage(16.8, [assert], [cookie, token,], [401 bytes], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [signature, cookie line, and failure bytes all exact], size: 6pt)
})

sources: RFC 8018 for PBKDF2, RFC 7519 for jwt structure, RFC 8032
for EdDSA, all at rfc-editor.org. OWASP Password Storage Cheat Sheet
at cheatsheetseries.owasp.com for the pbkdf2 parameter guidance; the
lane pins the contract's frozen 210000 iteration tier and states the
cheat sheet's current interactive table separately. Microsoft Learn,
verified 2026-09-26:
learn.microsoft.com/dotnet/api/system.security.cryptography.rfc2898derivebytes.pbkdf2
for the static derive call this chapter uses,
learn.microsoft.com/dotnet/api/system.security.cryptography.cryptographicoperations.fixedtimeequals
for the constant-time compare,
learn.microsoft.com/dotnet/api/system.security.cryptography.hmacsha256.hashdata,
learn.microsoft.com/dotnet/api/system.security.cryptography.ecdsa for
the ES256 lane, and
learn.microsoft.com/dotnet/core/compatibility/cryptography/11/compositemldsa-windows-native
for the Windows EdDSA gap, the cross-platform page now covering the
post-quantum tables instead. Verified by `books/csharp-net/api` tests
under `dotnet test`, the authn suite green through the frozen
vectors 04, 05, 07, and 08.
