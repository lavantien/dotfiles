#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= authn

Authentication answers one question, who is calling, and this chapter
builds every piece of the answer: argon2id password storage with
parameters carried in the hash string, a login path flattened so
unknown emails and wrong passwords cost the same, server-side
sessions behind a store port, the cookie that carries the refresh
token, HS256 and EdDSA json web tokens built from cryptographic
primitives rather than a library, rotation with reuse detection on
the refresh family, and the injected-clock test discipline that keeps
all of it under a second.

== password storage with argon2id

Passwords are never stored, only proofs that cost an attacker real
time and memory to reproduce. Argon2id is the memory-hard answer: it
fills and re-reads a block of memory a set number of times, so a gpu
farm cannot parallelize guesses the way it parallelizes sha256, and
the parameter set travels inside the encoded string. The tiers are
named values, not magic numbers:

#listing("go/api/internal/authn/password.go", first: 22, last: 45, caption: [the parameter tiers and the hashing port, one type for both])

The issue tier follows the OWASP recommendation for interactive
logins, 19 MiB and two passes. The test tier is deliberately named
`TestParams`, a confession: 8 MiB and one pass keep every hash in the
suite in the tens of milliseconds while exercising the identical code
path. A structural test pins the production floor, memory at least
19456 KiB and time at least two passes, without ever running it, so
the suite stays fast and the tier cannot silently decay.

Hashing mints a fresh 16-byte salt and renders one PHC-style string,
version, parameters, salt, derived key, so verification replays the
exact parameters the hash was written with, never today's defaults.
Upgrading the tier re-hashes opportunistically on the next login,
because the string says which tier wrote it:

#snippet(
  "func (a *Argon2) Hash(password string) (string, error) {\n"
  + "\tsalt := make([]byte, 16)\n"
  + "\tif _, err := rand.Read(salt); err != nil {\n"
  + "\t\treturn \"\", fmt.Errorf(\"authn: salt: %w\", err)\n"
  + "\t}\n"
  + "\tkey := argon2.IDKey([]byte(password), salt, a.Params.Time,\n"
  + "\t\ta.Params.Memory, a.Params.Threads, a.Params.KeyLen)\n"
  + "\treturn encode(a.Params, salt, key), nil\n"
  + "}",
  lang: "go",
)

#diagram([argon2id: lanes fill a memory block, passes re-read it, the salt and params ride along], length: 13pt, {
  cdraw.rect((1.2, 5.6), (11.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.1, 7.6), [memory, 19456 KiB], size: 6.5pt)
  cdraw.content((6.1, 6.6), [filled once per pass,], size: 6pt)
  cdraw.content((6.1, 5.8), [lanes share it, p = 1], size: 6pt)
  cdraw.line((2.2, 8.2), (2.2, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.4, 8.8), [pass 1, then pass 2], size: 6pt)
  cdraw.rect((12.4, 5.6), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((17.3, 7.6), [encoded string], size: 6.5pt)
  cdraw.content((17.3, 6.6), [dollar argon2id v 19 m t p], size: 6pt)
  cdraw.content((17.3, 5.8), [salt and key, base64], size: 6pt)
  cdraw.line((11.2, 6.9), (12.2, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [verify parses the string and re-derives, constant time], size: 6pt)
})

Argon2id is worth naming as a construction, because it is a schedule
over a primitive, not a new primitive. Everything it hashes, it hashes
with blake2b: the first block is the compression of the parameters,
the salt, and the output length, each lane then fills its strip of the
memory array by compressing the previous block with a referenced block
from an earlier lane, and each additional pass re-reads and re-compresses
the whole array in a different order. The memory hardness is the
schedule's property, an attacker who shrinks the array cannot answer
the compression chain, and the gpu resistance is the lane structure
forcing the same memory traffic a cpu pays. The x/crypto function is
therefore a pure function of stdlib-shaped parts, and its
`IDKey` call is the entire contract the chapter's hashing port wraps.

== login and timing flattening

A login endpoint that answers fast for unknown emails and slowly for
wrong passwords hands out an account census to anyone with a stopwatch.
The flattening fix sits in the unknown-email branch: run the same
argon2 verification the wrong-password path runs, against a dummy
hash computed once at service construction, discard the result, and
answer the identical bytes:

#listing("go/api/internal/authn/handlers.go", first: 146, last: 166, caption: [both failure branches answer the same 401 after the same work])

Both branches return the same envelope, code, message, and no
distinguishing header, and the rate limiter of chapter 26 will add
the same headers to both. The only observable difference left is
network jitter. The success path runs on through `issue`, which mints
the session, the refresh token, the cookie, and the access token in
one place, so login stays readable as two facts: prove, then issue.

#diagram([the timing-equalized login: unknown email pays what a wrong password pays], length: 13pt, {
  cdraw.content((5.0, 8.9), [known email], size: 6.5pt)
  cdraw.rect((1.6, 6.9), (8.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 7.7), [argon2 verify,], size: 6pt)
  cdraw.content((5.0, 6.8), [mismatch], size: 6pt)
  cdraw.content((16.4, 8.9), [unknown email], size: 6.5pt)
  cdraw.rect((13.0, 6.9), (19.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.4, 7.7), [argon2 verify on,], size: 6pt)
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
port mirrors the user package's: an interface frozen here, the
in-memory implementation in this chapter, the engine implementation
in chapter 23:

#listing("go/api/internal/authn/session.go", first: 47, last: 69, caption: [the session store port: five verbs, three errors])

The lifetime rules stay with the caller, on purpose. The store knows
structural state, which token is current, which session is revoked;
the service knows the time and applies the policy, a session counts
as alive while not revoked and not expired. That split keeps the
engine implementation free of clock reads and makes every expiry test
pure arithmetic on an injected clock:

#snippet(
  "type Session struct {\n"
  + "\tID          string\n"
  + "\tUserID      string\n"
  + "\tRefreshHash [32]byte\n"
  + "\tExpiresAt   time.Time\n"
  + "\tRevoked     bool\n"
  + "}\n\n"
  + "func HashToken(token string) [32]byte {\n"
  + "\treturn sha256.Sum256([]byte(token))\n"
  + "}",
  lang: "go",
)

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
allowing ordinary top-level navigation, except a top-level post within
two minutes of the cookie's creation, the 6265bis
lax-allowing-unsafe window:

#listing("go/api/internal/authn/cookie.go", first: 16, last: 27, caption: [the session cookie: four attributes, one line of go])

Logout clears it with Max-Age 0, rendered exactly. Go's cookie writer
emits a delete only for a negative Max-Age, which serializes as
Max-Age 0, the byte form every browser honors, and the attributes
stay set so the deletion overwrites the exact cookie it replaces.
The tests assert the whole Set-Cookie line byte for byte against the
frozen vector, attributes, order, and semicolons included:

#snippet(
  "func ClearSessionCookie(w http.ResponseWriter) {\n"
  + "\thttp.SetCookie(w, &http.Cookie{\n"
  + "\t\tName: CookieName, Value: \"\",\n"
  + "\t\tPath: \"/api\", MaxAge: -1,\n"
  + "\t\tHttpOnly: true, Secure: true,\n"
  + "\t\tSameSite: http.SameSiteLaxMode,\n"
  + "\t})\n"
  + "}",
  lang: "go",
)

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

== JWT from scratch with HMAC

A json web token is three base64url parts, header, claims, signature,
and the whole format fits in two functions of cryptographic
primitives. HMAC-SHA256 signs the first two segments with a shared
secret, verification recomputes and compares in constant time, and
the claim rules run after the signature, never before:

#listing("go/api/internal/authn/jwt.go", first: 81, last: 105, caption: [sign and verify HS256, no library, two primitives])

The claims struct is small and alphabetical by declaration, exp, iat,
iss, sid, sub, which makes the serialized form deterministic, the
same bytes for the same facts, so the golden test reproduces the
frozen vector's token exactly, signature included. There is no roles
claim on purpose: authorization reads the store, and the sid claim
makes every outstanding token revocable by killing one session row.
The parser refuses what the classics try: an alg none header never
reaches the payload, a tampered claim fails the constant-time
compare, the wrong secret fails it too, and an expired or foreign-iss
token fails the claim checks with its own errors.

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

== JWT with EdDSA

HMAC has one secret and both sides hold it, so whoever can verify
tokens can also mint them. In one process that is fine, and it is why
the issued lane stays HS256: one signer, one verifier, one binary.
The moment verification spreads, a public-key scheme earns its
complexity. EdDSA splits the pair, the private key signs, the public
key verifies, and the verification side provably cannot forge:

#listing("go/api/internal/authn/jwt.go", first: 107, last: 129, caption: [the same envelope, an asymmetric signature])

The two parsers cross-check each other in the tests: an HS256 parser
refuses the EdDSA token on the alg pin, the EdDSA parser refuses the
HS256 token the same way, and the alg confusion attack, present a
token signed with the algorithm the attacker prefers, dies at the
header. The claim checks are shared, so issuer, expiry, and the
constant-time habits do not fork between algorithms.

#diagram([shared secret versus split key: who can mint, who can check], length: 13pt, {
  cdraw.content((5.4, 8.9), [HS256], size: 6.5pt)
  cdraw.rect((1.0, 6.6), (9.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 7.7), [one secret, both sides], size: 6pt)
  cdraw.content((5.4, 6.8), [verifier can mint], size: 6pt)
  cdraw.content((16.8, 8.9), [EdDSA], size: 6.5pt)
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

#listing("go/api/internal/authn/session.go", first: 125, last: 142, caption: [rotate: superseded tokens revoke the family, unknown ones miss])

The vector pair pins the whole story. Refresh at plus twenty returns
a new cookie and a new access token. Replay the old cookie at plus
twenty-one and both die: the replay answers 401 session revoked, and
the successor, still perfectly formed, answers 401 session revoked
one second later. An attacker who stole the token before the holder
refreshed gets one use, then loses the family along with the victim.

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
struct advanced by hand, so token expiry is one addition. The id
source hands out the vector's uuids, so the sid claim lands exact.
The random reader is a fixed byte buffer, so the refresh token and
the Set-Cookie line reproduce the frozen vector byte for byte, and a
counting hasher proves the dummy verify ran on the unknown-email
path:

#listing("go/api/internal/authn/authn_test.go", first: 313, last: 331, caption: [identical bytes asserted, the flatten count asserted])

No test sleeps, no test opens a socket, and the argon2 tier keeps
the whole suite under a second. The concurrency test rotates one
token from eight goroutines and asserts exactly one winner, which the
race detector reads as one clean critical section. When the vectors
change the code is wrong, and nothing in this chapter has a second
source of truth to drift toward.

#diagram([an auth golden test: fixed inputs in, frozen bytes out], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector 04 07 08], [clock offsets,], [token bytes], luma(235))
  stage(6.0, [injected], [ids, rand reader,], [counting hasher], luma(235))
  stage(11.4, [login refresh], [recorder,], [no socket], luma(235))
  stage(16.8, [assert], [cookie, token,], [401 bytes], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [signature, cookie line, and failure bytes all exact], size: 6pt)
})

sources: RFC 9106, Argon2, for the memory-hard function and parameter
format, and RFC 7519 plus RFC 8032 for jwt structure and EdDSA at
rfc-editor.org; cheatsheetseries.owasp.com, Password Storage Cheat
Sheet, for the argon2id tier recommendation; RFC 6265bis for cookie
attributes and Max-Age semantics; pkg.go.dev/golang.org/x/crypto/
argon2. Accessed 2026-09-25. Verified by `go/api/internal/authn`
tests under `go test` and `go vet`, race detector on.
