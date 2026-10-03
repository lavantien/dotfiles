#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= authentication

Authentication answers one question, who is calling, and this chapter
builds every piece of the answer in pure lua: sha-256 from the fips
spec over the bitwise operators, hmac and pbkdf2 over it, login
flattened so every miss costs and answers the same, sessions in a
fixed preallocated table with rotation and family revocation, the
cookie as exact bytes, and HS256 tokens from the primitives rather
than a library.

== sha-256 from the spec

Lua's stdlib ships no crypto, so the hash is written from fips 180-4:
the message schedule, the 64 rounds, the length as a big endian
64-bit count. Everything runs on 5.3-era integers, 64-bit words
masked back to 32 bits after every add, because lua integers do not
wrap at 32 and sums drift high without the mask. Rotation composes
from the two shifts, the one place the shift-only set needs help:

#listing("lua/service/crypto.lua", first: 58, last: 75, caption: [the compression rounds, masked to 32 bits after every add])

The one-shot form pads with `string.pack`, a 1 bit, zeros to 56 mod
64, then the bit length as `>I8`, and walks whole 64-byte blocks.
Ground truth is never this prose, it is rfc 6234's vectors: the empty
string, `abc`, the 56-byte message, the 448-bit message, and the
million-a message, all asserted as hex literals in the module's own
test list, and they said no more than once while this module grew.

#diagram([one block through the machine: schedule, 64 rounds, eight words out], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [schedule], [16 words from bytes,], [48 derived], luma(235))
  stage(6.0, [rounds], [64 steps, two sigmas,], [ch and maj], luma(235))
  stage(11.4, [feed forward], [h plus the work,], [eight words], luma(235))
  stage(16.8, [digest], [big endian bytes,], [32 per block], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [64-bit integers masked to 32, rfc 6234 is the truth], size: 6pt)
})

== hmac and pbkdf2

Hmac is rfc 2104's two-hash construction: a key longer than the block
hashes down first, then the key xor one constant pads to 64 bytes and
the inner hash feeds the outer. Both pads build with one `gsub` over
the key's bytes, and the rfc 4231 cases 1 through 7 pin the result,
including the two cases with 131-byte keys that force the hash-down.
Pbkdf2 is the same hmac in rfc 8018's loop, each output block
chaining the previous block's macs:

#listing("lua/service/crypto.lua", first: 111, last: 123, caption: [pbkdf2: the block counter rides the salt, the chain xors every round])

The rfc 7914 one-iteration vector plus two literals cross-checked
against python's hashlib pin the loop. The tiers are named numbers,
never magic. The issue tier is the 210000-iteration recommendation,
and its cost was measured on the tools/lua55 pin on 2026-09-27: one
derive takes 19.811 s of cpu. That is the chapter's honest platform
fact, a pure-lua kdf prices in seconds on this vm, so the tier is
pinned as a constant, structurally asserted, never run by the suite.
Tests hash at 1000 iterations, 0.093 s per derive measured the same
day, and the encoded string carries the tier that wrote it, so
verification replays the writer's parameters, never today's defaults.

#diagram([the measured ladder: cost against iteration count, 2026-09-27 pin], length: 13pt, {
  cdraw.line((1.2, 1.8), (1.2, 8.6), stroke: luma(140))
  cdraw.line((1.2, 1.8), (21.8, 1.8), stroke: luma(140))
  cdraw.rect((2.4, 1.8), (6.8, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.6, 2.4), [1000 iters], size: 6pt)
  cdraw.content((4.6, 1.2), [0.093 s], size: 6pt)
  cdraw.rect((8.4, 1.8), (20.6, 7.9), fill: luma(222), radius: 0.02)
  cdraw.content((14.5, 5.0), [210000 iters, the issue tier], size: 6.5pt)
  cdraw.content((14.5, 4.1), [19.811 s measured], size: 6pt)
  cdraw.content((11.5, 8.9), [seconds per derive, linear in the iteration count], size: 6pt)
  cdraw.content((11.5, 0.3), [the test tier runs in verify, the issue tier is stated], size: 6pt)
})

== login and the dummy verify

A login route that answers fast for unknown emails and slowly for
wrong passwords hands out an account census to anyone with a
stopwatch. The flatten sits in every miss: the hash of a fixed dummy
password is computed once at wire time, and each failure branch runs
the same verify against it, discards the result, and answers the
identical bytes, empty member, unknown email, wrong password alike:

#listing("lua/service/authn.lua", first: 307, last: 321, caption: [every miss past the wire pays the same work and answers the same 401])

The ruling this lane hardened past its go mirror: any miss after the
decode ladder is the 401, including an empty member, because a
missing email that answered 422 would itself be a distinguishable
branch. The wire ladder still runs first, a body that is not json at
all is the 400 of the decode step, and the rate bucket is drawn
exactly once by the limit layer upstream. No handler here draws a
bucket or stamps a rate header, and the replay proves it: vectors 04,
05, and 06 carry the three headers with remaining 4 on both allowed
draws and the 429 on the sixth.

#diagram([three misses, one lane: the stopwatch learns nothing], length: 13pt, {
  cdraw.content((4.4, 8.9), [empty member], size: 6.5pt)
  cdraw.content((11.5, 8.9), [unknown email], size: 6.5pt)
  cdraw.content((18.6, 8.9), [wrong password], size: 6.5pt)
  cdraw.rect((1.2, 6.8), (7.6, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.4, 7.6), [dummy verify], size: 6pt)
  cdraw.rect((8.3, 6.8), (14.7, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 7.6), [dummy verify], size: 6pt)
  cdraw.rect((15.4, 6.8), (21.8, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.6, 7.6), [real verify, miss], size: 6pt)
  cdraw.line((4.4, 6.6), (4.4, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 6.6), (11.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.6, 6.6), (18.6, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.4, 3.6), (16.6, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 4.9), [identical 401 bytes], size: 6.5pt)
  cdraw.content((11.5, 4.0), [invalid credentials, same latency shape], size: 6pt)
})

== sessions in a fixed table

A session is the server's own record of one login, and the table that
holds them is fixed and preallocated: a pool of slot tables built once
at construction, recycled through a freelist, so a login mutates
existing tables instead of allocating. There is no lock anywhere. The
vm runs one instruction stream, no handler can observe a table
mid-mutation, and the single thread is the lock, stated as the
platform's own fact rather than apologized for:

#listing("lua/service/authn.lua", first: 81, last: 97, caption: [the preallocated pool, and reads that close over the live slot])

Reads return copies, but the copy's `alive` closes over the slot, not
over the copied fields, so a family revoked after the copy still
answers dead on the same clock tick. The refresh index maps every
hash this family ever held to its slot, and retired hashes stay
forever, because presenting one is the theft signal the next section
builds on. The pool has a hard capacity and answers `full` rather
than growing, an in-memory service's honest bound, and the wiring
refuses with it: a login at a full pool answers 503 overload instead
of minting a token no table backs, so the bound lives on the wire.

#diagram([the session pool: slots from a freelist, one refresh index, no lock], length: 13pt, {
  cdraw.rect((0.8, 5.4), (9.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.6), [the slot pool], size: 6.5pt)
  cdraw.content((4.9, 6.6), [built once, recycled,], size: 6pt)
  cdraw.content((4.9, 5.8), [a create pops the freelist], size: 6pt)
  cdraw.rect((11.0, 5.4), (21.4, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((16.2, 7.6), [the refresh index], size: 6.5pt)
  cdraw.content((16.2, 6.6), [every hash ever current,], size: 6pt)
  cdraw.content((16.2, 5.8), [retired ones kept forever], size: 6pt)
  cdraw.line((9.2, 6.8), (10.8, 6.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [one instruction stream, the thread is the lock], size: 6pt)
  cdraw.content((11.5, 3.5), [alive reads the live slot, capacity is hard], size: 6pt)
})

== the cookie line

The browser carries the refresh token in a cookie, and the cookie's
attributes are its entire protection. The line is rendered as exact
bytes, not assembled by a library, and the frozen vector pins it:

#listing("lua/service/authn.lua", first: 158, last: 178, caption: [the set line, the clear line, and the first-member reader])

Path scopes the cookie to the api tree so it never rides on requests
to other origins hosted beside the service. HttpOnly keeps scripts
from reading it, so an injected snippet cannot exfiltrate what it
cannot see. Secure keeps it off plain http. SameSite Lax blocks the
cookie on cross-site posts while allowing ordinary top-level
navigation. Logout clears it with Max-Age=0 rendered exactly, the
attributes staying set so the deletion overwrites the exact cookie it
replaces. The reader side is deliberately small, the first
goapi_session member of a Cookie header and no attribute grammar.
The bearer lane is accepted everywhere the cookie is, and both
resolve to one actor, one identity either way.

#diagram([four attributes, four attacks, zero script visibility], length: 13pt, {
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
  cdraw.content((11.5, 3.3), [logout renders Max-Age=0 with the attributes kept], size: 6pt)
  cdraw.content((11.5, 2.4), [bearer and cookie resolve to one actor], size: 6pt)
})

== HS256 from scratch

A json web token is three base64url parts, and the whole format fits
in two functions over the chapter's primitives. The header and the
claims render as fixed-order bytes with `string.format`, member order
frozen by construction, so the same facts always produce the same
token and the golden test reproduces the vector's token byte for
byte, signature included:

#listing("lua/service/authn.lua", first: 179, last: 198, caption: [fixed-order bytes in, one hmac, base64url unpadded out])

The parse is the mirror discipline. Three strict segments, the
signature decoded and compared in constant time before any payload
byte is read, the algorithm pinned by comparing the header against
the exact bytes this service writes, so the alg none forgery dies at
the header. One bug the suite caught while this grew is worth naming:
the signed message is header dot claims with the trailing dot
excluded, and one early draft hashed one byte more than it verified.
Issuer is checked, expiry always runs, and there is no roles claim,
because authorization reads the store, which keeps every outstanding
token revocable through its sid. The asymmetric variant is the one
thing this platform cannot hand-roll at book scale: the stdlib has no
curves, ed25519 would be a chapter of its own, and the dependency
ruling forbids a crypto library. So the split-key argument stays
prose, whoever can verify can also mint under HS256, and one binary
with one signer makes that fine.

#diagram([three segments, the signature covers exactly the first two], length: 13pt, {
  cdraw.rect((0.8, 5.4), (6.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.6), [header], size: 6.5pt)
  cdraw.content((3.6, 6.6), [alg typ, fixed bytes], size: 6pt)
  cdraw.content((3.6, 5.8), [b64url unpadded], size: 6pt)
  cdraw.rect((7.2, 5.4), (14.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.7, 7.6), [claims], size: 6.5pt)
  cdraw.content((10.7, 6.6), [exp iat iss sid sub], size: 6pt)
  cdraw.content((10.7, 5.8), [rendered by string.format], size: 6pt)
  cdraw.rect((15.0, 5.4), (22.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((18.5, 7.6), [signature], size: 6.5pt)
  cdraw.content((18.5, 6.6), [hmac of header dot claims,], size: 6pt)
  cdraw.content((18.5, 5.8), [the trailing dot excluded], size: 6pt)
  cdraw.content((11.5, 4.3), [alg pinned first, expiry always runs, no roles claim], size: 6pt)
})

== rotation and reuse detection

The access token lives fifteen minutes. The refresh token is the
long-lived credential, 32 opaque bytes hex-rendered to the client and
stored only as its sha256, so a stolen store dump cannot be replayed
against the live service. It rotates on every use, and the store
retires the presented hash rather than deleting it, because
presenting a retired hash is the theft signal:

#listing("lua/service/authn.lua", first: 128, last: 142, caption: [rotate: a retired or revoked presentation kills the family])

The vector pair pins the whole story. Refresh at plus twenty retires
the first token and answers a new cookie and a new access token.
Replay the retired token at plus twenty-one and both die: the replay
answers 401 session revoked, and the successor, still perfectly
formed, answers 401 session revoked one second later. The freshly
minted next token on the refusal path never enters the store. A
thief holding the token from before the holder refreshed gets one
use, then loses the family along with the victim.

#diagram([the family: rotation forks, either replay revokes everything], length: 13pt, {
  let state(x, y, label, fill) = {
    cdraw.rect((x - 2.3, y - 0.55), (x + 2.3, y + 0.55), fill: fill, radius: 0.02)
    cdraw.content((x, y), label, size: 6.5pt)
  }
  state(3.4, 7.8, [token A current], luma(235))
  state(11.5, 7.8, [token B current], luma(222))
  state(19.6, 7.8, [family revoked], luma(205))
  cdraw.line((5.7, 7.8), (9.2, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.4, 8.5), [refresh, A retired], size: 6pt)
  cdraw.line((13.8, 7.8), (17.3, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((15.5, 8.5), [B replayed later], size: 6pt)
  cdraw.line((3.4, 7.1), (17.3, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.0, 6.1), [A replayed: theft signal], size: 6pt)
  cdraw.content((11.5, 4.9), [either replay revokes the session row, every token dies], size: 6pt)
  cdraw.content((11.5, 4.0), [the thief and the victim both hold dead strings], size: 6pt)
})

== golden vector replay

The login scenario replays vectors 04, 05, and 06 on one fresh state,
and the reuse scenario replays 07 and 08 on another. The clock ticks
to each offset, the queues hold the vector's session id and pinned
refresh bytes, so both cookies and tokens reproduce exactly as the
files carry them:

#listing("lua/service/tests/vectors_test.lua", first: 344, last: 362, caption: [the reuse pair: both 401 bodies byte exact])

The 429 is the middleware layer's answer, not a handler's, and the
replay proves the layer drew once: five allowed logins at one tick
show remaining 4, 3, 2, 1, 0, and the sixth answers the envelope with
Retry-After 1 and Reset on the next whole second. When the vectors
change the code is wrong, and nothing in this chapter has a second
source of truth to drift toward.

#diagram([two scenarios, five vectors, every byte from the fixture queues], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector json], [offsets, ids,], [token bytes], luma(235))
  stage(6.0, [injected], [clock, id queue,], [rand queue], luma(235))
  stage(11.4, [the stack], [identity limit idem,], [dispatch and render], luma(235))
  stage(16.8, [assert], [cookies, tokens,], [401 and 429 bytes], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [the rate layer draws once, zero sleeps], size: 6pt)
})

sources: fips 180-4 for the sha-256 specification, rfc 6234 for the
sha and hmac test vectors, rfc 4231 for the hmac cases, rfc 8018 for
pbkdf2, rfc 7914 for its one-iteration vector, rfc 7519 for jwt
claims, and rfc 6265 for cookie attributes, all at rfc-editor.org.
lua.org manual 5.5 section 3.4.2 for the bitwise operators and their
64-bit integer domain, 6.4 for string.pack, gsub, and format, all
verified against the tools/lua55 pin. The structural mirror is
books/go/api/internal/authn, whose argon2id contrast the pbkdf2 tier
measurement replaces with this platform's own numbers, and books/
c-os-cloud/api/src/authn_sha.c for the hand-rolled discipline.
Accessed 2026-09-27. Verified by the service suite through `make
verify-lua`: authn 10 checks, the family replay 13, all green.
