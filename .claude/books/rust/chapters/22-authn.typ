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
the use, in `rustapi::authn`: a json web token assembled from the
sha256 and hmac primitives chapter 21 already proved against
published vectors, the session family that gives a token something to
be revoked through, refresh rotation with reuse detection that kills
a stolen family, the login endpoint whose two failure branches cost
the same and answer the same bytes, and the identity layer that
resolves a caller over either channel and installs the actor
everything later reads. The go book built the same machine over
argon2id, #xref-to("go", "authn"), the java book the smaller
token-only scope, #xref-to("java", "authn"), and this lane takes the
go scope on the java argument: the refresh family is where the
revocation story lives, and the primitives are already paid for.

One staging statement, chapter 21's own: until chapter 23's guard
lands, no route is closed by this chapter. The identity layer
installs an actor or does not, the way go's `Identify` did, and a
request that carries nothing still reaches the resource routes it
reached before. The routes that demand an actor here are the ones
this chapter owns, login, refresh, logout, and the last demands one
of its own.

== the token, three segments and one primitive

A json web token is a header, a claims object, and a signature over
the first two, base64url without padding, dots between. That is the
whole format, and every byte of it comes from this crate: the json
writer from the kernel, the encoder and hmac from the user module.
The claims are five, in alphabetical wire order so the same secret
and the same facts always produce the same bytes, which is what lets
a test freeze a token exactly:

#listing("rust/api/src/authn.rs", first: 34, last: 72, caption: [five claims in fixed wire order, and the five refusals: a policy-free encoding of every way a token can die])

#listing("rust/api/src/authn.rs", first: 74, last: 88, caption: [sign: the kernel writer serializes, chapter 21's hmac signs the first two segments, base64url unpadded])

#diagram([three segments, the signature covers exactly the first two, dots included], length: 13pt, {
  cdraw.rect((0.8, 5.4), (6.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.6), [header], size: 6.5pt)
  cdraw.content((3.6, 6.6), [alg, typ], size: 6pt)
  cdraw.content((3.6, 5.8), [base64url], size: 6pt)
  cdraw.rect((7.2, 5.4), (14.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.7, 7.6), [claims], size: 6.5pt)
  cdraw.content((10.7, 6.6), [exp iat iss sid sub], size: 6pt)
  cdraw.content((10.7, 5.8), [fixed member order], size: 6pt)
  cdraw.rect((15.0, 5.4), (22.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((18.5, 7.6), [signature], size: 6.5pt)
  cdraw.content((18.5, 6.6), [hmac sha256 of], size: 6pt)
  cdraw.content((18.5, 5.8), [header dot claims], size: 6pt)
  cdraw.content((11.5, 4.3), [no roles claim: authorization reads the store, so a token stays cheap to revoke through its sid], size: 6pt)
})

The `sid` claim is the whole revocation seam. There is no roles
claim, the same reasoning both siblings kept: a role baked into a
token goes stale the moment an admin revokes it, while a token that
names a session dies the moment the session does, which is the next
section's machinery.

== verification, order and constant time

Verification is a fixed order and the order is the security: shape,
algorithm pin, signature, then claims. The algorithm check runs
before any payload byte is trusted, so the classic `alg: none`
forgery and a token correctly signed under a foreign algorithm both
die at the header, and the signature comparison is a xor fold across
both digests:

#listing("rust/api/src/authn.rs", first: 90, last: 135, caption: [verify: shape, alg pin, constant-time signature, then the claim rules, issuer and expiry against the clock])

#callout("verify", "the constant-time property, stated not measured", [
  The fold starts from the length difference and xors every byte of
  both digests unconditionally, so the answer does not depend on
  where the bytes differ, only on whether they do. A timing test
  would measure the optimizer, not the property, so the tests pin
  tamper rejection, one flipped signature byte and one wrong secret
  both refused, and the chapter pins the contract: equality decided
  in time independent of the position of the first difference.
])

Cost is part of the story, measured on this machine, dated
2026-10-15: one hand-rolled hmac over the 150 byte signing span
answers in 1.5 to 2 microseconds in a `-O` binary driving the same
primitive, while chapter 21 measured one 100,000-iteration pbkdf2 at
120 to 140 ms under `--release`, nearly five orders of magnitude
apart. That gap
is the entire argument for tokens as the per-request credential and
passwords as the once-per-login one.

== the session family and reuse detection

The session is the server-side state one login owns, and the refresh
token itself never lives in it: only `sha256(token)`, so a store
dump cannot be replayed. The port is five verbs, frozen now the way
chapter 21 froze the user port, with rotation carrying the reuse
rule in its contract:

#listing("rust/api/src/authn.rs", first: 138, last: 184, caption: [the session record, the hash transform, and the port: rotation is where a stolen family dies])

#listing("rust/api/src/authn.rs", first: 247, last: 292, caption: [rotate under one mutex: a superseded or revoked presenter flips the family dead, and the freshly minted next never enters the store])

#diagram([reuse detection: the replay of r0 kills r1 with it, the family is one unit], length: 13pt, {
  cdraw.content((3.4, 8.9), [login], size: 6.5pt)
  cdraw.rect((1.4, 6.9), (5.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.4, 7.9), [session s1], size: 6pt)
  cdraw.content((3.4, 7.1), [current: r0], size: 6pt)
  cdraw.content((10.4, 8.9), [rotate], size: 6.5pt)
  cdraw.rect((8.4, 6.9), (12.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.4, 7.9), [r0 superseded], size: 6pt)
  cdraw.content((10.4, 7.1), [current: r1], size: 6pt)
  cdraw.content((17.4, 8.9), [replay r0], size: 6.5pt)
  cdraw.rect((15.4, 6.9), (19.4, 8.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 7.9), [family revoked], size: 6pt)
  cdraw.content((17.4, 7.1), [r1 dies too], size: 6pt)
  cdraw.line((5.6, 7.6), (8.2, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.6, 7.6), (15.2, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.8), [a thief holding r0 and the owner holding r1 share one death], size: 6pt)
  cdraw.content((11.5, 4.9), [the unit test pins both directions at the port], size: 6pt)
})

The superseded record is kept, not deleted, because presenting one
is the theft signal. The in-memory implementation holds two maps
under one mutex, sessions and token hashes, and the engine chapter
will implement the same port over durable storage without a handler
learning of the change.

== login, prove then issue, both branches the same cost

The login route is chapter 19's decode ladder wearing one job: bind
the two members, prove the password, mint the family. The proof runs
against the stored form through an injected verifier, so a test
fixture never pays 100,000 iterations. The one security argument is
timing: a login that answers fast for unknown emails and slowly for
wrong passwords hands out an account census to anyone with a
stopwatch, and the fix is one line in the unknown-email branch, burn
the same verification against a dummy hash, discard the answer,
return the identical envelope:

#listing("rust/api/src/authn.rs", first: 490, last: 537, caption: [strict bind, presence rules, the dummy burn, then issue: session, refresh cookie, and the access token])

The counting wrapper around the injected verifier is the test's
proof: the unknown-email lane increments the same counter the
wrong-password lane does, and the two envelopes, stripped of their
request ids, compare byte equal. The success path is two facts,
prove then issue, and issue is one movement: mint the refresh token
from the injected source, create the session with the token's hash,
sign the access token, answer the full user representation plus the
token with the cookie beside it.

The email lookup rides a walk, and the reason is a landed seam:
chapter 21's port froze create, get, and list, with no
by-email read, and this chapter does not touch landed modules. The
injected `find_user` closes over `email_lookup_over`, which pages
through the keyset order until the normalized email appears. At book
scale, a few hundred records, that is a cheap honest price, stated
here rather than paid silently by widening a frozen port.

== refresh and logout, the routes that move the family

Refresh reads its credential from either channel, the bearer header
or the cookie, and the route's order is the policy. An expired but
never-rotated session does not come back to life. A merely revoked
one keeps flowing into rotation, so its holders read `session
revoked`, not a generic miss. And the next token is minted before
the rotation attempt, so a failed rotation discards it unwritten,
which is why the reuse test seeds four tokens for three requests:

#listing("rust/api/src/authn.rs", first: 539, last: 567, caption: [refresh: expired answers invalid credentials, superseded answers session revoked, and the family dies inside rotate])

#listing("rust/api/src/authn.rs", first: 569, last: 600, caption: [logout demands an actor, tolerates an already-dead session, clears the cookie, and the token mint is one function])

Logout is the one route in this chapter that demands an actor, and
revoking the session is what kills the outstanding access tokens:
the bearer stays cryptographically valid for its fifteen minutes,
but the resolve below reads the session by `sid` and a dead session
resolves no actor, which the test pins by logging out twice.

== the identity layer and its two channels

The identity layer is a chapter 20 layer, one function from handler
to handler. It resolves an actor from the bearer token or the
session cookie and installs it into the request's `extras` map as
its wire form, or installs nothing, and a presented-but-invalid
credential and no credential at all are the same non-identity:

#listing("rust/api/src/authn.rs", first: 410, last: 455, caption: [bearer first then cookie, both lanes end at the same actor-for-session check, and the scheme word is case-insensitive])

The bearer lane verifies the signature, then reads the session by
`sid`, so revocation kills outstanding tokens, then reads the user,
so roles come from the record at request time: a demoted admin loses
the role on the next request, not at the next login, pinned by
reseeding ada's record between two resolves of the same token. The
cookie lane resolves the opaque refresh token by hash and lands at
the same check. The scheme word matches `bearer`, `Bearer`, and
`BEARER` alike, rfc 9110 section 11.1's case-insensitive
auth-scheme, while the token that follows is exact bytes. The actor
travels as its json wire form under one `extras` key, and the
round trip through `parse_wire` is pinned, the same
serialization discipline the cursor used.

== the wiring and the tests

The program grows the family the way the fixture does, one store
instance under both families, the secret from `RUSTAPI_SECRET` when
the environment carries one and a fresh 32 random bytes otherwise,
the ephemeral lane stated in the code: every token dies with the
process that signed it, correct for a dev boot and a lockout for a
production one. The dummy hash is the one real pbkdf2 this wiring
pays, computed once at boot from the pinned dummy password. The
listing is read as the part closes it: the `roles_of` seam and the
guard line are chapters 23 and 24 arriving, and this chapter's own
fixture binds `record_roles` over the store while the shipped
wiring binds the grants table:

#listing("rust/api/src/main.rs", first: 59, last: 96, caption: [the wiring as the part closes it: one store under every family, identity outside the stack, the chapter 23 guard inside it])

#diagram([the wired order: identity outside, so a defect in it fails closed, past chapter 20's boundary], length: 13pt, {
  cdraw.rect((1.0, 6.6), (22.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.4), [identify, installs the actor or nothing], size: 6.5pt)
  cdraw.content((11.5, 7.4), [answers nothing itself, so it sits outside timing and recover], size: 6pt)
  cdraw.rect((3.0, 3.8), (20.0, 6.2), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 5.6), [request id, access log, timing, recover], size: 6.5pt)
  cdraw.content((11.5, 4.6), [chapter 20's stack, unchanged], size: 6pt)
  cdraw.rect((6.4, 1.0), (16.6, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 2.8), [router], size: 6.5pt)
  cdraw.content((11.5, 1.9), [kernel, user, and auth routes], size: 6pt)
  cdraw.line((11.5, 6.3), (11.5, 3.5), stroke: luma(100), mark: (end: ">>"))
})

The identity layer sits outside the whole chapter 20 stack, and the
position is the java chapter's boundary argument in rust's shape:
this layer answers nothing, so there is nothing of its own to time
or log, and a panic inside it escapes recover and closes the
connection, fail closed, exactly the boundary java drew around its
own filter. Every verdict the service emits still passes through
the stack, because the verdicts live in handlers and, from the next
chapter, in the guard.

The fixture owns everything time-dependent: the frozen ids straight
from the vector chain, the clock pinned at the contract origin, the
verifier a fake with a counter, the refresh tokens a seeded queue,
and the routes real over an ephemeral port:

#listing("rust/api/tests/authn.rs", first: 224, last: 278, caption: [the fixture: vector ids, frozen clock, counting verifier, seeded refreshes, identify over the real routes])

The frozen token is the discipline. The header, the claims with
their `sid` and `sub` from the vector chain, the fixed secret, and
the contract's origin instant produce bytes the test carries as a
constant, derived offline from python 3's `hmac` and `hashlib` on
this machine the same day, so any drift in the writer, the encoder,
or the hmac fails a string comparison. Around it, on the pinned
1.99.0 build, dated 2026-10-13, the authn test file carries 16 green
tests: the frozen bytes and their round trip, the tamper ladder
with the wrong secret, the flipped signature byte, `alg: none` both
unsigned and signed, a correctly signed `HS384`, the wrong issuer,
and eight malformed shapes, expiry to the second on both sides of
the boundary, the case-insensitive scheme with its exact-bytes
token, the actor wire round trip, the vector login with the frozen
token and the cookie, the two failure branches byte-identical with
the dummy burn counted, the presence rules and the decode ladder,
the rotation-replay-family chain over the socket, the bearer refresh
channel, the expired session's refusal to return, the credentialless
401, logout revoking the family with the second logout refused, the
anonymous logout 401, the resolve lanes with roles reread from the
record, and the port-level rotation and reuse unit.

sources: RFC 7519 for the json web token claims and the `exp`
semantics, RFC 9110 sections 11.1, 11.6.1, and 15.5.1 for the
case-insensitive auth-scheme, the bearer challenge semantics, and
the 401, at rfc-editor.org, accessed 2026-10-13. The frozen token
bytes derived from python 3 `hmac` and `hashlib` on this machine,
dated 2026-10-13, as the independent oracle, and the hmac cost,
1.5 to 2 microseconds over the 150 byte span, re-measured
2026-10-15 by a `-O` binary driving the crate's own primitive. The
pbkdf2 cost, 120 to 140 ms release and 2 to 3 s debug, is chapter
21's measurement on the same build. The session family, rotation, reuse detection,
and the cookie attributes from the go sibling, book 4 chapter 21,
and the identity-layer boundary and the smaller scope from the java
sibling, book 4 chapter 22, of this corpus. The login vector's
request body and user representation from `contract/testdata/04-login-200.json`,
the go oracle's file hashed byte-exact into this lane's vectors. All
other measurements, 16 tests, produced by `cargo test --locked`
under `CARGO_NET_OFFLINE=true` on the pinned build, dated 2026-10-13.
