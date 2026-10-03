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

Authentication answers one question, who is calling, and this chapter
builds every piece of the answer in `books/javascript/api/src/authn/`:
scrypt password storage with parameters carried in the hash string, a
login path flattened so unknown emails and wrong passwords cost the
same, server-side sessions behind a store port, the cookie that
carries the refresh token, HS256 and EdDSA json web tokens built from
cryptographic primitives rather than a library, rotation with reuse
detection on the refresh family, and the injected-clock test
discipline that keeps all of it under a second. The go lane hashed
with argon2id because go's platform extension ships it. Node ships
`crypto.scrypt` natively and ships no argon2, so scrypt is the
platform's memory-hard lane at zero dependencies, ratified for lesson
parity, and the construction is decomposed below the way the argon2id
lesson was.

== password storage with scrypt

Passwords are never stored, only proofs that cost an attacker real
time and memory to reproduce. Scrypt is the memory-hard answer: it
fills and re-reads a block of memory a set number of times, so a gpu
farm cannot parallelize guesses the way it parallelizes sha256, and
the parameter set travels inside the encoded string. The tiers are
named values, not magic numbers:

#listing("javascript/api/src/authn/password.mjs", first: 21, last: 36, caption: [the issue tier is the owasp floor, the test tier is the same code path at 1 MiB])

The issue tier follows the OWASP password storage cheat sheet's
scrypt floor, `N=2^17` at 128 MiB with `r=8` and `p=1`, and one
probed fact on node 26.3.0 matters more than the numbers: the default
`maxmem` budget of 32 MiB rejects that floor outright with
`memory limit exceeded`, so the tier carries an explicit 160 MiB
budget or the strongest parameters never run at all. The test tier is
deliberately named `TEST_PARAMS`, a confession, 1 MiB and roughly two
milliseconds per hash on this machine while exercising the identical
code path. A structural test pins the issue floor, `N` above the test
tier and the budget above 128 MiB, without ever running it.

Scrypt is worth naming as a construction, because it is a schedule
over primitives, not a new primitive. The inner KDF is pbkdf2 with
HMAC-SHA256, itself a chain of sha256 compressions over the salt and
a counter, and the same pbkdf2 is the comparison the cheat sheet
offers at 600000 iterations as the non-memory-hard fallback. The
schedule around it is ROMix: fill a memory array of `128 * N * r`
bytes by walking a pseudorandom index chain, each new block mixing
one block from earlier in the chain, then re-read the whole array in
the same order and re-mix, so an attacker who shrinks the array
cannot answer the mixing chain. BlockMix is the permutation that
shuffles each round of `2r` blocks through salsa20/8, and `N`, `r`,
`p` travel in the PHC-style string so verification replays the
parameters the hash was written with, never today's defaults. Node's
`scryptSync` takes exactly those three plus `maxmem`:

#diagram([scrypt: pbkdf2 seeds it, ROMix fills and re-reads memory, the params ride along], length: 13pt, {
  pane(0.4, 7.6, 8.0, [pbkdf2 sha256], [the inner KDF,], [seed plus salt])
  cdraw.line((4.0, 6.6), (4.0, 5.4), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 7.6, 5.2, [ROMix], [fill 128 N r bytes,], [then re-read in order])
  cdraw.line((4.0, 4.2), (4.0, 3.0), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 7.6, 2.8, [BlockMix], [salsa20 8 per,], [round of 2r blocks])
  cdraw.line((7.8, 5.4), (8.4, 5.4), stroke: luma(100), mark: (end: ">>"))
  pane(8.6, 15.4, 8.0, [encoded string], [dollar scrypt v 1], [N r p, salt, key])
  cdraw.content((11.7, 3.2), [verify parses the string and re-derives, constant time], size: 6pt)
  cdraw.content((11.7, 2.2), [a hash minted at one tier verifies at any tier], size: 6pt)
})

== login and timing flattening

A login endpoint that answers fast for unknown emails and slowly for
wrong passwords hands out an account census to anyone with a
stopwatch. The flattening fix sits in the unknown-email branch: run
the same scrypt verification the wrong-password path runs, against a
dummy hash computed once at service construction, discard the result,
and answer the identical bytes:

#listing("javascript/api/src/authn/handlers.mjs", first: 99, last: 117, caption: [both failure branches answer the same 401 after the same verify work])

Both branches return the same envelope, code, message, and no
distinguishing header, and the rate limiting chapter adds the same
three rate headers to both when its wrapper wraps this route. The
only observable difference left is network jitter. A counting double
in the suite pins the flatten itself, exactly one verify call on each
failure branch. The success path runs on through `issue`, which mints
the session, the refresh token, the cookie, and the access token in
one place, so login stays readable as two facts: prove, then issue.

#diagram([the timing-equalized login: unknown email pays what a wrong password pays], length: 13pt, {
  pane(1.0, 9.0, 8.4, [known email], [scrypt verify,], [mismatch])
  pane(14.0, 22.0, 8.4, [unknown email], [scrypt verify on,], [the dummy hash])
  cdraw.line((5.0, 6.4), (10.7, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.0, 6.4), (12.3, 5.0), stroke: luma(100), mark: (end: ">>"))
  pane(6.4, 16.0, 4.6, [identical 401 bytes], [invalid credentials, same latency])
  cdraw.content((11.2, 2.2), [a stopwatch learns nothing about which branch ran], size: 6pt)
})

== server-side sessions

A session is the server's own record of one login: an id, the user,
the expiry, a revoked flag, and the sha256 of the current refresh
token. The token itself is never stored, only its hash, so a stolen
store dump cannot be replayed against the live service. The store
port mirrors the user family's: the shape frozen here, the in-memory
implementation in this chapter, the engine implementation in the
store chapter. The lifetime rules stay with the caller, on purpose:
the store knows structural state, the service knows the time, and
`alive` is one boolean expression both share:

#listing("javascript/api/src/authn/session.mjs", first: 79, last: 94, caption: [rotate: superseded tokens revoke the family, unknown ones miss])

Rotation is where the design earns its keep. A superseded token's
record is kept, not deleted, because presenting one is the strongest
theft signal the design gets: the legitimate holder moved on, so
someone else is replaying. The answer is family revocation, the
session row flips to revoked and every token it ever minted dies,
the replayed one and its successor together.

#diagram([the session lifecycle: login creates, refresh rotates, logout or reuse revokes], length: 13pt, {
  let state(x, label, fill) = {
    cdraw.rect((x - 2.1, 7.2), (x + 2.1, 8.4), fill: fill, radius: 0.02)
    cdraw.content((x, 7.8), [#label], size: 6.5pt)
  }
  state(3.4, [absent], luma(235))
  state(11.5, [alive], luma(222))
  state(19.6, [revoked], luma(205))
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
attributes are its entire protection. The builders are plain string
templates because the line is frozen by the vectors, order included:

#listing("javascript/api/src/authn/cookie.mjs", first: 11, last: 23, caption: [the session cookie and its deletion, four attributes, one line each])

`Path` scopes it to the api tree so it never rides on requests to
other origins hosted beside the service. `HttpOnly` keeps scripts
from reading it, so an injected snippet cannot exfiltrate what it
cannot see. `Secure` keeps it off plain http. `SameSite=Lax` blocks
the cookie on cross-site posts while allowing ordinary top-level
navigation. Logout clears it with `Max-Age=0` rendered exactly, the
attributes staying set so the deletion overwrites the exact cookie it
replaces, and the tests assert both lines byte for byte against the
vectors. Reading is a small parser of its own: pairs split on the
first equals sign, first occurrence wins, and a longer name sharing a
prefix must not match.

#diagram([the cookie attribute matrix: what each one stops], length: 13pt, {
  let row(y, attr, threat, verdict) = {
    cdraw.content((3.6, y), [#attr], size: 6pt)
    cdraw.content((11.4, y), [#threat], size: 6pt)
    cdraw.content((18.4, y), [#verdict], size: 6pt)
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
secret, through `createHmac` and `timingSafeEqual`, and the claims
run after the signature, never before:

#listing("javascript/api/src/authn/jwt.mjs", first: 95, last: 115, caption: [parse: the alg pin runs before any payload byte is read])

The claims literal is alphabetical by key, `exp`, `iat`, `iss`,
`sid`, `sub`, insertion order is serialization order, so the same
facts marshal to the same bytes and the golden test reproduces the
frozen vector 04 token exactly, signature included. There is no
roles claim on purpose: authorization reads the store, and the `sid`
claim makes every outstanding token revocable by killing one session
row. The parser refuses what the classics try: an alg none header
dies at the pin before its payload is touched, a tampered claim or a
wrong secret fails the constant-time compare, an expired or
foreign-issuer token fails the claim checks. Every refusal answers
null, one boolean fact in the node idiom, and the tests pin which
check refused by constructing each input, not by an error taxonomy
the handler would only collapse into one 401.

#diagram([three segments, the signature covers exactly the first two], length: 13pt, {
  pane(0.8, 6.4, 8.2, [header], [alg, typ], [base64url])
  pane(7.2, 14.2, 8.2, [claims], [exp iat iss sid sub], [base64url, literal order])
  pane(15.0, 22.0, 8.2, [signature], [hmac sha256 of], [header dot claims])
  cdraw.content((11.5, 4.3), [dots included, padding stripped, alg pinned before payload reads], size: 6pt)
})

== jwt with eddsa

HMAC has one secret and both sides hold it, so whoever can verify
tokens can also mint them. In one process that is fine, and it is why
the issued lane stays HS256: one signer, one verifier, one process.
The moment verification spreads, a public-key scheme earns its
complexity. EdDSA splits the pair, the private key signs, the public
key verifies, and the verification side provably cannot forge:

#listing("javascript/api/src/authn/jwt.mjs", first: 65, last: 71, caption: [the same envelope, an ed25519 signature])

This is the true ed25519 lesson, and it is cross-language: the c sharp
lane could not deliver it. The windows base class library has no
ed25519, so that lane teaches ES256 over its ecdsa classes instead,
while node's `node:crypto` ships ed25519 keypairs and `sign` and
`verify` calls natively, probed on 26.3.0. The two parsers
cross-check each other in the tests: the HS256 parser refuses the
EdDSA token on the alg pin, the EdDSA parser refuses the HS256 token
the same way, and the alg confusion attack dies at the header. The
claim checks are shared through one `parse`, so issuer and expiry
rules never fork between algorithms.

#diagram([shared secret versus split key: who can mint, who can check], length: 13pt, {
  pane(1.0, 9.8, 8.4, [HS256], [one secret, both sides], [verifier can mint])
  pane(12.4, 21.2, 8.4, [EdDSA], [private signs, public verifies], [verifier cannot mint])
  cdraw.content((11.5, 5.4), [one process, one signer: the issued lane stays HS256], size: 6pt)
  cdraw.content((11.5, 4.5), [c sharp lane: no ed25519 in the windows bcl, ES256 there], size: 6pt)
  cdraw.content((11.5, 3.6), [node lane: ed25519 keypairs in node:crypto, tested live], size: 6pt)
})

== refresh rotation and reuse detection

Access tokens live fifteen minutes, the refresh token is the
long-lived credential, and it rotates on every use. Rotation means
the store remembers the token it just retired, marked superseded,
because presenting a superseded token is the theft signal, and the
answer is family revocation:

#listing("javascript/api/src/authn/handlers.mjs", first: 155, last: 174, caption: [the reuse answer: the family dies, the fresh successor never enters the store])

The vector pair pins the whole story. Refresh at plus twenty returns
a new cookie and a new access token, same session id. Replay the old
cookie at plus twenty-one and both die: the replay answers 401
`session revoked`, and the successor, still perfectly formed, answers
401 `session revoked` one second later. An attacker who stole the
token before the holder refreshed gets one use, then loses the family
along with the victim. One wrinkle the handler carries: a merely
expired session does not revive, while a revoked one keeps flowing
into rotate so its holders read `session revoked`, not a generic
miss, the message the vector freezes.

#diagram([the refresh family: rotation forks, reuse revokes everything], length: 13pt, {
  let state(x, label, fill) = {
    cdraw.rect((x - 2.3, 7.2), (x + 2.3, 8.4), fill: fill, radius: 0.02)
    cdraw.content((x, 7.8), [#label], size: 6.5pt)
  }
  state(3.4, [token A issued], luma(235))
  state(11.5, [token B current], luma(222))
  state(19.6, [family revoked], luma(205))
  cdraw.line((5.7, 7.8), (9.2, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.4, 8.5), [refresh, A retired], size: 6pt)
  cdraw.line((13.8, 7.8), (17.3, 7.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((15.5, 8.5), [B replayed next], size: 6pt)
  cdraw.content((11.5, 6.1), [either replay revokes the session row, every token dies], size: 6pt)
  cdraw.content((11.5, 5.2), [the thief and the victim both hold dead strings], size: 6pt)
})

== testing auth without walls

Every time-dependent behavior here is tested as arithmetic. The clock
is a mutable millisecond the fixture advances by hand, so token
expiry is one addition and the exp boundary is exact to the second.
The id source hands out the vector's uuids, so the `sid` claim lands
exact. The random source hands out the vector's 32-byte refresh
tokens, so the `Set-Cookie` line reproduces the frozen bytes, and a
counting double proves the dummy verify ran on the unknown-email
path:

#listing("javascript/api/test/authn/handlers.test.mjs", first: 84, last: 97, caption: [the fixture: clock, id source, random source, all injected])

No test sleeps, no test opens a socket, and the scrypt test tier
keeps the whole authn suite in tens of milliseconds. The identity
layer tests beside them: one actor per credential channel, the bearer
lane checking signature then session, the cookie lane resolving the
opaque token by hash, garbage and expiry answering nothing, and the
bearer dying the second its session row revokes. When the vectors
change the code is wrong, and nothing in this chapter has a second
source of truth to drift toward.

#diagram([an auth golden test: fixed inputs in, frozen bytes out], length: 13pt, {
  pane(0.6, 5.2, 8.2, [vectors 04 05 07 08], [clock offsets,], [token bytes])
  pane(6.0, 10.6, 8.2, [injected], [ids, random bytes,], [counting hasher])
  pane(11.4, 16.0, 8.2, [login refresh], [recorder,], [no socket])
  pane(16.8, 21.4, 8.2, [assert], [cookie, token,], [401 bytes])
  cdraw.content((11.0, 4.4), [signature, cookie line, and failure bytes all exact], size: 6pt)
})

sources: cheatsheetseries.owasp.org, Password Storage Cheat Sheet, for
the scrypt floor `N=2^17`, `r=8`, `p=1` and the pbkdf2-HMAC-SHA256
600000-iteration comparison, accessed 2026-09-26.
nodejs.org/api/crypto.html for `scryptSync` with its options and
`maxmem`, `createHmac`, `timingSafeEqual`, `generateKeyPairSync`,
`sign`, `verify`, and `randomBytes`. RFC 7914, The scrypt Password-Based
Key Derivation Function, and RFC 7519 plus RFC 8032 for jwt structure
and EdDSA, at rfc-editor.org. developer.mozilla.org for `Set-Cookie`
attributes and `Math.floor`. Accessed 2026-09-26. Verified by
`books/javascript/api/test/authn` tests, 46 of them, under
`npm run verify` with prettier clean.
