#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= authn

Chapter 21 stored a password hash and never used it. This chapter is
the use: `javabook.authn` builds the whole answer to who is calling,
a json web token assembled from `javax.crypto.Mac` rather than a
library, the login endpoint that proves a password against chapter
21's pbkdf2 form and issues a fifteen minute token, the filter that
extracts a bearer token and installs the actor everything else reads,
and the 401 that closes every route the wiring does not declare open.
The go book built the same layer with argon2id, sessions, refresh
rotation, and cookies, #xref-to("go", "authn"), and the smaller scope
here is deliberate: the token and the proof carry every idea the
larger machine adds machinery around, and one chapter owes them
justice before the authz chapter decides what the caller may do.

== the token, three segments and one primitive

A json web token is a header, a claims object, and a signature over
the first two, all base64url without padding. That is the entire
format, and the jdk's crypto floor covers it: `Mac` with `HmacSHA256`
is the signature, `Base64.getUrlEncoder` is the alphabet, and the
kernel's json writer is the serializer. The one representation choice
worth naming is determinism: the header and claims serialize through
`LinkedHashMap` in fixed member order, so the same secret and the
same facts always produce the same bytes, which is what lets a test
pin a token exactly:

#listing("java/api/src/javabook/authn/Jwt.java", first: 58, last: 78, caption: [the claims and sign: json through the kernel writer, hmac over the first two segments, base64url unpadded])

#diagram([three segments, the signature covers exactly the first two], length: 13pt, {
  cdraw.rect((0.8, 5.4), (6.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.6), [header], size: 6.5pt)
  cdraw.content((3.6, 6.6), [alg, typ], size: 6pt)
  cdraw.content((3.6, 5.8), [base64url], size: 6pt)
  cdraw.rect((7.2, 5.4), (14.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.7, 7.6), [claims], size: 6.5pt)
  cdraw.content((10.7, 6.6), [exp iat iss sub], size: 6pt)
  cdraw.content((10.7, 5.8), [base64url, fixed order], size: 6pt)
  cdraw.rect((15.0, 5.4), (22.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((18.5, 7.6), [signature], size: 6.5pt)
  cdraw.content((18.5, 6.6), [hmac sha256 of], size: 6pt)
  cdraw.content((18.5, 5.8), [header dot claims], size: 6pt)
  cdraw.content((11.5, 4.3), [dots included, padding stripped, no fourth segment exists], size: 6pt)
})

The claims are four, and the two that matter as policy are `exp`,
answered against the clock at verification, and `iss`, the service's
own name. There is no roles claim, on the same reasoning the go book
kept: authorization reads the store, so a token carries identity and
nothing that can go stale. And there is no session id, which is a
real divergence from the go chapter and worth its own sentence: this
book keeps no server-side session, so a token cannot be revoked
before its fifteen minutes run out, and revocation is expiry. At the
scale a book ships that is the cheap honest trade, and the store
chapter's engine would be the place a session row would live if the
trade ever needed revisiting.

== verification, order and constant time

Verification is a fixed order and the order is the security: shape,
algorithm pin, signature, then claims. The algorithm check runs
before any payload byte is trusted, so the classic `alg: none`
forgery and a token correctly signed under `HS384` both die at the
header, and the signature comparison is `MessageDigest.isEqual`,
whose contract in this build's own sources states that the
calculation time depends only on the length of the first argument:

#listing("java/api/src/javabook/authn/Jwt.java", first: 87, last: 124, caption: [verify: shape, alg pin, constant-time signature, then the claim rules])

#callout("verify", "the constant-time property, stated not measured", [
  `MessageDigest.isEqual`'s documentation in the pinned build carries
  the `@implNote` that when the second digest is nonempty, calculation
  time depends only on the first argument's length, never on either
  digest's contents, and the implementation is a loop that xors every
  byte unconditionally. A timing test would measure the jvm's jit,
  not the property, so the tests pin tamper rejection and the chapter
  pins the contract: equality decided in time independent of where
  the bytes differ.
])

Every refusal is one of five reasons, malformed, algorithm mismatch,
bad signature, wrong issuer, expired, and the caller that matters,
the filter, maps all five onto one 401, because a forged token and
an expired one are the same non-event to a caller. Cost is part of
the story too, measured on this machine: one hmac over a 150 byte
span answers in 0.3 microseconds, while one pbkdf2 verification of
chapter 21's stored form answers in 28 to 34 milliseconds across four
runs, five orders of magnitude apart, which is the whole argument
for tokens as the per-request credential and passwords as the
once-per-login one.

== login, prove then issue

The login endpoint is chapter 19's decode ladder wearing one job:
bind the two members, prove the password, mint the token. The proof
runs against the stored form through an injected verifier so a test
fixture never pays 100,000 iterations, and the production verifier
is `Passwords.verify`, which parses the self-describing string
chapter 21 wrote, algorithm label, iteration count, salt, digest,
re-derives with exactly those parameters, and compares digests
through the same `isEqual`:

#listing("java/api/src/javabook/authn/Passwords.java", first: 28, last: 53, caption: [verify replays the stored parameters, never today's defaults, and never throws on a foreign string])

The endpoint's one security argument is timing. A login that answers
fast for unknown emails and slowly for wrong passwords hands out an
account census to anyone with a stopwatch, and the fix is one line
in the unknown-email branch: run the same pbkdf2 against a dummy
hash, discard the answer, return the identical envelope. Both
branches cost one derivation and answer the same bytes:

#listing("java/api/src/javabook/authn/Login.java", first: 60, last: 71, caption: [both failure branches answer the same 401 after the same work])

#diagram([the timing-equalized login: unknown email pays what a wrong password pays], length: 13pt, {
  cdraw.content((5.0, 8.9), [known email], size: 6.5pt)
  cdraw.rect((1.6, 6.9), (8.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 7.7), [pbkdf2 verify,], size: 6pt)
  cdraw.content((5.0, 6.8), [mismatch], size: 6pt)
  cdraw.content((16.4, 8.9), [unknown email], size: 6.5pt)
  cdraw.rect((13.0, 6.9), (19.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.4, 7.7), [pbkdf2 verify on], size: 6pt)
  cdraw.content((16.4, 6.8), [the dummy hash], size: 6pt)
  cdraw.line((5.0, 6.6), (10.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.4, 6.6), (11.9, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.4, 3.4), (16.2, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.3, 4.7), [identical 401 bytes], size: 6.5pt)
  cdraw.content((11.3, 3.8), [invalid credentials, same latency], size: 6pt)
  cdraw.content((11.3, 2.3), [measured 2026-10-05: 24 to 37 ms on either branch], size: 6pt)
})

The success path is two facts, prove then issue, and the issue is one
call: `Jwt.sign` over the clock's second, fifteen minutes ahead, the
service's issuer, and the user's id. The response body is
`access_token` and nothing else, no user representation, because the
caller just proved which user it is and can ask chapter 21's routes
with the token it holds.

== the filter, and the routing question it must ask first

The identity layer is a `Filter`, like chapter 20's stack, and
chapter 20 established the constraint that shapes it: filters run
before the kernel dispatches, so the path parameters a handler reads
do not exist yet and the filter cannot ask them. What the filter
needs instead is the route pattern the request will match, open or
not, and that is a question only the kernel's table can answer. The
chapter adds one query method to `App`, `resolvePattern`, which walks
the same table the dispatcher walks and answers the `METHOD pattern`
string or nothing:

#listing("java/api/src/javabook/httpx/App.java", first: 156, last: 172, caption: [the pattern query: filters ask the table instead of guessing at paths])

The filter itself is then short. Extract the bearer, verify it,
install the actor as an exchange attribute, and for a pattern that is
not open and an actor that did not resolve, answer the 401 envelope
with the rfc 9110 challenge header and stop the chain:

#listing("java/api/src/javabook/authn/Authn.java", first: 59, last: 97, caption: [install the actor, close the closed routes, one message for missing and invalid alike])

Three decisions in those lines. A bad token on an open route is not
a failure: it means no actor, exactly like a request that carried
nothing, so health checks and registrations do not break because a
stale token rode along. A request that matches no pattern at all
falls through untouched, because 404 and 405 are the kernel's
answers, not authentication verdicts. And the 401 carries
`WWW-Authenticate: Bearer`, the header rfc 9110 section 11.6.1
requires a 401 to carry, which most hand-rolled servers forget and
every standards-strict client checks. The scheme word itself is
matched case-insensitively, `bearer` and `Bearer` both parse,
because rfc 9110 section 11.1 makes the auth-scheme
case-insensitive, while the token that follows is exact bytes and
the test pins that the same token upper-cased answers no actor.

The actor is the whole handoff to the rest of the book: a record of
the user id and the roles a function reads from the store at request
time. The roles function arrives in the next chapter's wiring as the
grants table, and the token never carries them, so a demoted admin
loses the role on the next request, not at the next login.

== the wiring

The program's `Main` grows the family the way chapter 21's did, one
filter line and one register call, plus the secret. The secret comes
from `JBAPI_SECRET` when the environment carries one, else a fresh
random 32 bytes at boot, and the ephemeral lane is stated in the
code's own comment: every token dies with the process that signed
it, correct for a dev boot and a lockout for a production one. The
open set names the routes that take anonymous traffic, the two
probes, registration, and login itself, and everything else in the
table now demands a bearer token:

#listing("java/api/src/javabook/Main.java", first: 64, last: 76, caption: [the wiring: the filter stack in its order, login reading the same store registration writes])

One store instance serves both families, stated in a comment because
it is the one wiring mistake this chapter can make silently: a login
route reading a second `MemStore` would answer unknown email for
every registered user and nothing else would look wrong. The filter
sits inside timing, so its 401s are timed and logged like any
answer, and outside recover, which states a boundary worth knowing:
the recover filter protects the chain it wraps, not the stack that
wraps it, so a defect that throws inside the authn layer itself
escapes the envelope lane and closes the connection, fail closed,
the same boundary chapter 20 drew around its own layers.

== the tests

The vector is the discipline. A fixed secret, a fixed clock at
2026-01-01T00:00:00Z, and the token is bytes: the tests pin
`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjcyMjY1MDAs...`
through `xHf6iLieoQ5F_avvH6L0zHTlMJn_KDbL4-kBGZ3J4FQ`, signature
included, and any drift in the writer, the encoder, or the hmac
fails a string comparison. Around it: tampering each of the three
segments, the wrong secret, expiry to the second on both sides of
the boundary, the `alg: none` forgery and a foreign algorithm
correctly signed, malformed shapes from the empty token to a
padded segment to a non-object header, and a foreign issuer under a
valid signature. The socket side boots the chapter's whole wiring on
an ephemeral port: the deterministic token the fixture's step clock
mints, the two failure branches asserting byte-identical envelopes
minus the request id and the dummy hash's presence in the counting
verifier's log, presence validation, the ladder, the 401 with its
challenge header for anonymous, garbage, and expired bearers, the
open routes staying open with a garbage bearer aboard, the
case-insensitive scheme word beside the exact-bytes token, the 404
that authn never touches, and the real-hasher round trip that prints
its cost. Sixteen tests this chapter, green three consecutive runs
in a module now numbering 92.

#diagram([the golden flow: fixed inputs in, frozen bytes out, over a real socket], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [fixture], [step clock, fake hash,], [counting verifier], luma(235))
  stage(6.0, [register], [one store, both], [families], luma(235))
  stage(11.4, [login], [prove, then sign], [15 minute token], luma(235))
  stage(16.8, [assert], [exact token bytes,], [identical 401s], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [no sleeps, one real pbkdf2 lane printing its milliseconds], size: 6pt)
})

sources: RFC 7519 for the json web token claims and the exp
semantics, RFC 9110 sections 11.1, 11.6.1, and 15.5.1 for the
case-insensitive auth-scheme, the bearer challenge header, and the
401, rfc-editor.org, accessed 2026-10-05.
`MessageDigest.isEqual`'s time-independence `@implNote` read from
the pinned build's own sources, `tools/jdk27/build/jdk-27/lib/src.zip`,
oracle jdk 27 ga build 27+35-2325, as was `Mac`'s contract. The
pbkdf2 construction is chapter 17's, verified against rfc 8018
there. The go contrasts, argon2id, sessions, refresh rotation,
cookies, against book 3, chapter 21. Verified live 2026-10-05 by the
`javabook.authn` tests under the vendored junit 6.1.3 lane, 16 tests
green three consecutive runs in a module of 92: the frozen token
vector, tamper and wrong-key rejection, second-precise expiry, the
alg pin, malformed shapes, the foreign issuer, the deterministic
login token, identical failure envelopes with the dummy hash burned,
the 401 with WWW-Authenticate for missing, garbage, and expired
bearers, open routes staying open, the case-insensitive scheme word
with its exact-bytes token, the login ladder, and the real-hasher
round trip measuring 43 to 61 ms to register, 24 to 37 ms to log in,
and 24 to 31 ms to refuse a wrong password across the suite's runs
on this machine, beside 0.3 microseconds for one hmac-sha256 over a
150 byte span.
