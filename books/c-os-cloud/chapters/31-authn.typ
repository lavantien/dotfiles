#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= authn

This book has no crypto chapter, so this one is the home for the
primitives the service needs, built from their specifications rather
than imported: sha-256 from FIPS 180-4, hmac from RFC 2104, pbkdf2
from RFC 8018, all verified against the published test vectors. On
those primitives the chapter builds password storage, login with
flattened timing, server-side sessions with rotating refresh tokens,
the cookie that carries them, and the hs256 jwt, byte-exact against
the frozen vectors. Nothing here dials, nothing sleeps, and every
random byte enters through the rand seam so the tests stay
deterministic.

== sha-256 from the spec

Sha-256 is a compression function over 64-byte blocks chained through
eight 32-bit words, plus a padding rule that makes the message length
a multiple of the block size. The initial words and the round
constants are the first 32 bits of the fractional parts of the square
and cube roots of the first primes, tabulated once. The message
schedule expands each block's 16 words to 64 with two rotation
mixtures, and the round mixes with a choice function, a majority
function, and two more rotations:

#listing("c-os-cloud/api/src/authn_sha.c", first: 36, last: 49, caption: [the message schedule: 16 words expanded to 64 by two rotation mixtures])

The streaming form carries the eight words, the byte count, and a
partial block, so a caller can feed a body in chunks and finish once.
The padding appends one set bit, zeros to the 56-byte mark, then the
64-bit big endian bit count, which is why the length field caps the
message at just under 2 exabytes and why the final function is a
one-way door. The proof the implementation is right is not this prose,
it is the RFC 6234 test set: the empty string, one letter, the
two-block message, and the stream form split across a block seam all
hash to the published constants, checked one by one in the family's
tests.

#diagram([one block through the digest: expand, mix, fold back into the eight words], length: 13pt, {
  pane(0.6, 6.0, 8.0, [the block], [64 bytes in], [16 words])
  cdraw.line((6.2, 6.6), (7.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(7.6, 14.6, 8.0, [the schedule], [16 to 64 words], [two rotations])
  cdraw.line((14.8, 6.6), (16.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(16.2, 23.4, 8.0, [64 rounds], [choice, majority], [add and rotate])
  cdraw.content((11.5, 4.0), [the eight words fold in and out, chained block to block], size: 6pt)
  cdraw.content((11.5, 2.8), [the vectors are the proof, the prose is the map], size: 6pt)
})

== hmac and pbkdf2

Hashing a key together with a message by concatenation is broken by
length-extension: sha256(key + message) lets anyone who knows one
output append more message and compute the new output without the
key. Hmac fixes this with two padded passes, an inner hash of the
message under the key xor'd with one pad and an outer hash of that
digest under the key xor'd with another pad. A key longer than the
block is hashed first, a shorter one is zero-padded:

#listing("c-os-cloud/api/src/authn_hmac.c", first: 9, last: 32, caption: [hmac-sha256: two padded passes over the shared digest, keys hashed or padded to one block])

Pbkdf2 turns the hmac into a password proof by iterating it, chaining
xor'd outputs, with the salt and a big-endian block index as the first
message. Each 32-byte block of output costs the iteration count times
one hmac, so work is the product of what the honest issuer chose and
what an attacker must repeat per guess. The RFC 7914 vectors pin the
construction at one pass and at 80000, and the family's tests run
both. The iteration count is a parameter everywhere it appears,
never a hidden default, which is what lets the password tier below
carry its own number in the stored string.

#diagram([hmac: the key padded to one block, two xor pads, two digest passes], length: 13pt, {
  pane(0.6, 7.0, 8.0, [the key], [longer than 64: hash it], [shorter: zero pad])
  cdraw.line((7.2, 6.6), (8.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(8.6, 15.6, 8.0, [inner], [key xor 0x36], [+ message, digest])
  cdraw.line((15.8, 6.6), (17.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(17.2, 24.0, 8.0, [outer], [key xor 0x5c], [+ inner digest])
  cdraw.content((11.5, 3.8), [length extension dies: the outer pass re-hides the inner], size: 6pt)
  cdraw.content((11.5, 2.6), [pbkdf2: chain this n times, xor the outputs], size: 6pt)
})

== password storage with pbkdf2

A stored password must be a proof, not a secret: verification
re-derives and compares, nothing decrypts. The proof is
pbkdf2-hmac-sha256 at the contract's 210000 passes over a 16-byte
per-user salt with a 32-byte key, and the encoded string carries the
parameters it was written with, so verification replays the issuer's
choice, never today's defaults:

#listing("c-os-cloud/api/src/authn_pass.c", first: 102, last: 119, caption: [the proof string: algorithm, iterations, length, salt, key, the reader replays all four])

The salt kills rainbow tables, because a table built for one salt
answers no other row. The iteration count is the cost dial, 210000 at
the issue tier and 2000 at the named test tier the suite actually
runs, with the issue tier asserted structurally, the string says
210000, rather than burned in every test pass. Verification guards
against crafted store rows too: a stolen row cannot force absurd work
through an inflated iteration count or key length, both are capped
before any derivation runs.

#diagram([one password, two rows, no shared work between attackers], length: 13pt, {
  pane(0.6, 7.4, 8.0, [row one], [salt a, 16 bytes], [210000 passes])
  pane(8.6, 15.4, 8.0, [row two], [salt b, 16 bytes], [210000 passes])
  pane(16.0, 23.4, 8.0, [verification], [re-derive, compare], [constant time])
  cdraw.content((11.5, 3.6), [a guess pays the full chain once per row], size: 6pt)
  cdraw.content((11.5, 2.4), [the string carries its own parameters, upgrades replay old rows], size: 6pt)
})

== login and timing flattening

Login answers one question, do these credentials match a row, and two
tiers stand in front of the answer. The first tier is emptiness: an
empty email or an empty password answers 422 with one body naming
both, the go lane's exact tier, so the answer never tells which field
alone was wrong. Everything else is a miss. Unknown email and wrong
password answer the same 401 with the same bytes, because a different
body would let an attacker enumerate accounts by response shape, and
an overlong field is a miss too rather than a validation error,
deliberately: an email past the row's width finds no row, a password
past its cap pays the dummy proof and fails it, so even a field's
length cannot be probed through the login route. The timing must
flatten the same way: an unknown email still runs a full proof
verification against a fixed dummy row, so the fast path of no row
found and the slow path of a real mismatch cost the same. The verify
function itself answers one boolean for every failure shape, malformed
string and wrong password alike, and its final comparison walks every
byte regardless:

#listing("c-os-cloud/api/src/authn_pass.c", first: 175, last: 190, caption: [verify: re-derive under the carried parameters, compare in constant time, one boolean out])

The wrong-password check in the tests pins the refusal, and the
malformed-string checks pin that a broken row answers false rather
than crashing or leaking which part failed. The rate limiter,
chapter 36's middleware layer, keys on the lower-cased email, so the
flattening is layered: identical bytes, identical timing, and a
bounded number of tries per address before the 429 takes over.

#diagram([two ways to fail, one answer], length: 13pt, {
  pane(0.6, 9.0, 8.2, [unknown email], [run the dummy proof], [full cost])
  pane(10.0, 18.4, 8.2, [wrong password], [run the real proof], [full cost])
  cdraw.line((9.2, 6.6), (9.8, 6.6), stroke: luma(100))
  cdraw.line((9.5, 6.6), (9.5, 3.4), stroke: luma(100))
  cdraw.line((9.5, 3.4), (11.6, 3.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.0, 3.9, [one 401], [same code, same bytes])
  cdraw.content((5.0, 1.6), [the account cannot be enumerated by shape or by clock], size: 6pt)
})

== server-side sessions

The access token is short-lived and carries no roles, so the session
is the real seat of state. Each login mints an opaque refresh token,
32 random bytes from the rand seam, hex on the wire as the cookie
value and sha256 hex as the only form the store keeps, so a database
leak does not leak live tokens:

#listing("c-os-cloud/api/src/authn_session.c", first: 11, last: 23, caption: [the token's two forms: hex for the client, the digest of that hex for the store])

The token is never a jwt, because a refresh token is a lookup key,
not a bearer of claims, and making it self-describing would only
widen what a leak reveals. Rotation issues fresh material on every
use, and the family id is the session id the access token also
carries, which is what makes revocation cheap: one session row down
and every access token for it dies at its next boundary check, no
token blacklist needed.

#diagram([the token's two forms and the one the store keeps], length: 13pt, {
  pane(0.6, 8.0, 8.2, [32 random bytes], [from the rand seam], [never stored raw])
  cdraw.line((8.2, 6.6), (9.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(9.6, 16.4, 8.2, [hex, 64 chars], [the cookie value], [the wire form])
  cdraw.line((16.6, 6.6), (17.8, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(18.0, 25.0, 8.2, [sha256 of the hex], [the store's row], [leak-safe])
  cdraw.content((12.0, 3.6), [rotation mints a new triple on every use], size: 6pt)
})

== cookie mechanics

The cookie is the browser's side of the session and its attributes
are the security posture, in an exact order the vectors carry:
http only so script cannot read it, secure so it never rides plain
http, same site lax so cross-site posts do not carry it, path scoped
to the api so static assets never see it. Logout answers the same
attributes plus a zero max-age, which deletes the cookie at the
client while the server revokes the session row:

#listing("c-os-cloud/api/src/authn_session.c", first: 25, last: 38, caption: [the session cookie and its clearing twin, attributes in the contract's order])

One identity rides either channel, the cookie or the bearer token,
and the authn check accepts both everywhere. That single rule keeps
browsers and programmatic clients on one path through every guarded
route, and the identical-bytes discipline from login has its echo
here: a missing cookie and a revoked session answer the same 401.

#diagram([the cookie's attributes, each one closing a named hole], length: 13pt, {
  let attr(y, name, why) = {
    cdraw.rect((1.4, y - 0.9), (9.6, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((3.2, y - 0.25), name, size: 6pt)
    cdraw.content((16.2, y - 0.25), why, size: 6pt)
    cdraw.line((9.8, y - 0.25), (11.4, y - 0.25), stroke: luma(100), mark: (end: ">>"))
  }
  attr(7.6, [HttpOnly], [script cannot read it])
  attr(5.7, [Secure], [never plain http])
  attr(3.8, [SameSite=Lax], [cross-site posts do not send it])
  attr(1.9, [Path=/api], [assets never see it])
  cdraw.content((9.0, 0.4), [logout: same attributes plus Max-Age=0], size: 6pt)
})

== jwt from scratch with hs256

The access token is a jwt with the hs256 algorithm: three base64url
segments over a fixed header, a fixed claim order, and an hmac
signature. The claim set is exactly what the contract says, issuer,
issue time, expiry at issue plus 900, the session id, and the subject
user id, and no roles claim at all, because authorization reads the
store-backed truth rather than trusting a token to still be honest
about roles:

#listing("c-os-cloud/api/src/authn_jwt.c", first: 98, last: 112, caption: [the claim parser: one fixed member order, no general json anywhere])

The verifier checks the shape first, re-derives the signature over
the ascii header and payload segments, and compares in constant time
before it parses a single claim, so a forged token never reaches the
claim reader. Any deviation refuses: a different header, a fourth
segment, a tampered byte anywhere, a wrong secret, an expiry at or
before now. The signing side is snprintf over the fixed shape and the
family's own base64url codec, and the test asserts the whole token
byte for byte against the frozen vector, which only passes because
every choice, claim order, header bytes, encoding, matches the
oracle.

#diagram([the token: three segments, the signature over the first two], length: 13pt, {
  pane(0.6, 7.4, 8.0, [header], [alg hs256, typ jwt], [fixed bytes])
  cdraw.content((8.9, 7.2), [.], size: 9pt)
  pane(9.4, 16.4, 8.0, [claims], [exp iat iss sid sub], [no roles])
  cdraw.content((17.0, 7.2), [.], size: 9pt)
  pane(17.4, 24.0, 8.0, [signature], [hmac over the], [first two ascii])
  cdraw.content((12.0, 4.2), [verify: constant-time compare before any claim parses], size: 6pt)
  cdraw.content((12.0, 3.0), [expiry at now or past refuses, code 5], size: 6pt)
})

== the refresh rotation and reuse detection

Refresh rotation is a theft detector. Every refresh issues new token
material and retires the old, and each token remembers the family it
belongs to, the session id. A client that holds only the newest token
never notices. A client that presents a retired token has, by
construction, either a stale tab or a copy that left the legitimate
holder's machine, and the contract picks the safe reading: the reuse
revokes the whole family, the replay gets a 401, and the rotated
token the thief did not use dies with it:

#listing("c-os-cloud/api/tests/test_authn.c", first: 213, last: 224, caption: [the token's two forms pinned: 32 bytes, hex on the wire, the digest stored])

The vector pair shows the whole story in three requests: the rotate
answers 200 with new material, the replay of the superseded token
answers 401 with the session revoked, and the follow-up with the
rotated token answers the same 401, because the family died. The
fixed session table that tracks current and retired hashes is this
chapter's own, the decision that a reuse means revocation is stated
once where both sides can see it.

#diagram([rotation as a tripwire: the retired token is the alarm], length: 13pt, {
  let tok(y, label, state, fill) = {
    cdraw.rect((6.0, y - 0.9), (18.0, y + 0.35), fill: fill, radius: 0.02)
    cdraw.content((8.6, y - 0.25), label, size: 6pt)
    cdraw.content((15.0, y - 0.25), state, size: 6pt)
  }
  tok(7.4, [token one], [retired on first use], luma(235))
  tok(5.6, [token two], [current], luma(222))
  cdraw.content((12.0, 4.2), [presenting token one again: the family revokes], size: 6pt)
  cdraw.content((12.0, 3.0), [token two dies with it, both answer the same 401], size: 6pt)
})

== testing auth without walls

Every time-dependent input in this chapter is a seam. The clock is a
counter the test steps, the id source is a list of the vector's
uuids, the rand seam hands back fixed bytes, so the proofs, the
tokens, and the cookies are all reproducible byte for byte. The tests
run the named 2000-pass tier for the verify legs and assert the issue
tier structurally, the encoded string carries 210000, which keeps the
suite fast without lying about what production writes. Nothing
sleeps, nothing dials, and every refusal path has its own check:

#listing("c-os-cloud/api/tests/test_authn.c", first: 175, last: 186, caption: [the vector oracle: sign with the fixed secret, compare the whole token])

The discipline is the same one the user resource chapter stated:
frozen bytes are the oracle, drift means the code is wrong, and the
assertion that looks trivial, comparing one string, is actually
checking the header bytes, the claim order, the encoding, and the
signature chain all at once. When the wiring layer lands over the
kernel exchange, these same functions answer the same bytes through
the full request path, and the vectors judge them again end to end.

#diagram([the seams: fixed inputs in, reproducible bytes out], length: 13pt, {
  pane(0.6, 6.6, 8.2, [the seams], [clock, ids, rand], [fixed in tests])
  cdraw.line((6.8, 6.6), (8.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(8.2, 15.6, 8.2, [this chapter], [proofs, tokens], [cookies])
  cdraw.line((15.8, 6.6), (17.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(17.2, 24.4, 8.2, [the vectors], [04, 07, 08], [byte for byte])
  cdraw.content((12.0, 3.6), [no wall clock, no socket, no sleep anywhere in the family], size: 6pt)
})

sources: FIPS 180-4 for the sha-256 specification and RFC 6234 for
its test vectors, RFC 2104 for hmac with the RFC 4231 test vectors,
RFC 8018 section 5.2 for pbkdf2 with the RFC 7914 section 11 vectors
for the sha-256 variant, RFC 7519 for the jwt claim set, and RFC 6265
for the cookie attributes, all accessed 2026-09-27. The frozen
vectors at `c-os-cloud/api/contract/testdata/` are the byte oracle,
04 for the token, 07 and 08 for rotation and reuse. Verified by the
authn family's 63 checks under the pinned clang 23 through
`make verify-capi`, plus clang-format over every file touched.
