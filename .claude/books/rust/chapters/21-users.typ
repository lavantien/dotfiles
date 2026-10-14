#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the user resource

The service's first real resource is the user: an id, an email, a
display name, a role set, a creation instant, and a version. This
chapter builds the resource layer on the chapter 19 kernel in
`rustapi::user`: the representation and its two projections, create
with validation from first principles, the store as a port with an
in-memory implementation, the password seam carrying
hand-rolled pbkdf2 because the zero-dependency law leaves no other
option, keyset pagination with byte-frozen cursors, the etag
contract on read, and the vector-driven tests that pin all of it
over a real socket. The go book built the same layer,
#xref-to("go", "users"), the java book the same,
#xref-to("java", "users"), and this chapter keeps their contracts
while the 16 frozen vectors measure the parity.

One staging decision stated up front. The authn family is chapter
22 and the authz family chapter 23, and until they land no caller
is authenticated: the get route answers the full record to any
caller the way the java chapter's did at this point in its arc,
while the list route already answers the public projection because
vector 13 pins that projection byte for byte. Chapter 23 tightens
the get route with owner-or-admin and upgrades the list
projection for admins, and neither change touches this chapter's
wire shape.

== the representation and its two projections

The stored record is one struct, and the wire is a method on it,
two of them, because the list projection is the contract's too:

#listing("rust/api/src/user.rs", first: 30, last: 74, caption: [the record and its two writers: the members on the wire are the members the writer lists, member order frozen by the vectors])

The explicit writer is what keeps the password hash off the wire:
go needed a dash tag on `PasswordHash` so its reflection serializer
would skip it, java needed the writer to list its members, and
rust's version of the java answer writes what it lists and nothing
else exists. The member order is not style, it is the contract:
the strong etag is the sha256 of these exact bytes, and the frozen
vector's etag pins the order `id`, `email`, `display_name`,
`roles`, `created_at`, `version`. The creation instant is stored
as unix milliseconds and rendered by `iso8601_utc`, arithmetic on
the days-from-civil relation rather than a library calendar, so
`1790830800000` renders as `2026-10-01T05:00:00Z` and a nonzero
millisecond tail renders as a three-digit fraction:

#listing("rust/api/src/user.rs", first: 86, last: 111, caption: [millis to iso 8601 by arithmetic: the vector instants render exactly, fractions only when nonzero])

== create, validation, and the 422 versus 409 boundary

The create handler is the decode ladder from chapter 19 with a
resource on top, and the order is the contract: the ladder answers
415, 413, the parse 400, and the unknown member 400, the typed
member read answers a 400 for a non-string value, validation sees
clean strings, and only then does the store answer:

#listing("rust/api/src/user.rs", first: 612, last: 639, caption: [strict bind, typed members, every rule checked, hash, then the store and the 201 with location and etag])

The rules come from the contract, not a crate, because the numbers
should be greppable: passwords 12 to 128 characters, display names
1 to 64, one email shape, every rule reporting into one details
array in field order so one round trip tells the client everything
wrong:

#listing("rust/api/src/user.rs", first: 523, last: 567, caption: [one detail per violated rule in field order, and the email shape: one at sign, dotted domain, no whitespace, 254 cap])

#callout("verify", "the ceiling counts codepoints, not bytes", [
  Go's `len` counts bytes, so a 64-character name of three-byte
  characters is 192 bytes and far over its 64-byte ceiling. Rust's
  `chars().count()` counts codepoints, and this lane pins the
  ceiling there deliberately: a 64-character name of `世`
  characters is exactly at the ceiling and registers, the 65th is
  refused, and both are test cases. Java's `String.length` would
  have counted utf-16 units, a third answer, which is why the
  distinction is stated rather than left to whatever a language's
  `len` happens to do.
])

The 422 and the 409 are different animals. A rule violation is
about the request alone, checkable without touching state, 422
validation. The email conflict is about the store's contents, 409
conflict, and it surfaces only after validation passed. The store
speaks outcomes, the handler maps them to statuses, and no layer
does the other's job. Normalization closes the last gap: emails
are lower-cased before the store sees them, so
`Ada@Example.ORG` cannot dodge a conflict with `ada@example.org`,
pinned by registering both spellings.

== the store seam

The persistence port is three methods, create, get, list, frozen
now because chapter 24 implements the same trait over a real
engine and two chapters build against one shape:

#listing("rust/api/src/user.rs", first: 434, last: 448, caption: [the port, and the in-memory state: two maps and the keyset order in a b-tree])

Every method runs under one mutex, the whole locking story at this
size, and the keyset order is the b-tree's own: `(created_at,
id)` keys make `list` a range walk that never sorts and never
scans, with the bootstrap rule and the version stamp inside
create:

#listing("rust/api/src/user.rs", first: 477, last: 520, caption: [bootstrap roles for the first user, version 1, and list as a range strictly after the cursor position])

A `seed` method stores a record exactly as given, for fixtures
and later chapters, and it exists because this chapter has no
update route: the walk fixture needs a version-2 record and
chapter 25's scope is where updates arrive.

== the password seam, primitives not crates

Storing plaintext is not an option and std ships no kdf, so the
chapter builds one from the same primitives a crypto crate would:
sha256 from FIPS 180-4, hmac over it per RFC 2104, pbkdf2 on top
per RFC 8018, all in this module, all verified against published
vectors:

#listing("rust/api/src/user.rs", first: 256, last: 280, caption: [pbkdf2 as hmac chained c times, xor-folded, and the self-describing stored form])

The stored string carries its own parameters, algorithm,
iterations, salt, digest, so the authn chapter verifies against a
value that explains itself, and the comparison in verify folds a
xor across both digests rather than comparing bytes, so the answer
does not leak through early exit. The salt comes from the one
entropy faucet std offers, per-instance `RandomState` keys, the
same seam the request-id mint uses. Measured on the pinned build,
dated 2026-10-15: one 100,000-iteration hash costs 2 to 3 s under
the cargo test debug profile and 120 to 140 ms under `--release`, which
is why every fixture injects a fake hasher and the production
cost is paid exactly once per registration, on purpose. The
tests cross-check against an independent oracle, the RFC 4231
hmac vector and pbkdf2 outputs derived from python 3's `hashlib`
on this machine the same day, so the implementation is fitted to
the standard, not to itself.

== keyset pagination with frozen cursor bytes

Offset pagination asks for row 86041 onward and fails twice: the
store walks and discards every skipped row, and offsets are
positions in a moving file, so one registration between requests
makes a row appear twice or vanish. Keyset pagination remembers
where it stopped. The order is the pair, creation millisecond
then id, and the cursor is that pair as json, base64url without
padding, opaque to clients and byte-frozen by vector 13:

#listing("rust/api/src/user.rs", first: 395, last: 432, caption: [the keyset key, the cursor codec, and the limit clamp 1 to 100 with the default 20])

The decode path is strict in the direction of everything else in
the kernel: a cursor is either one this service issued or
garbage, never a missing page, so every failure down the base64,
the json, and the member checks answers the same 422, and the
test pins the frozen bytes
`eyJ0IjoxNzkwODMwODAzMDAwLCJpIjoiMDFhMGY1ZDUtNzgzOC03MTAzLThhN2YtYmFhOThlMjBmODA4In0`
as the encoding of grace's position, 2026-10-01T05:00:03Z plus
her id. The handler reads `limit + 1` rows so the presence of one
extra row is the whole has-more computation, no counts, no second
query:

#listing("rust/api/src/user.rs", first: 671, last: 704, caption: [limit plus one read, public projection items, the cursor names the last row kept, null on the last page])

#diagram([offset walks the whole prefix, keyset jumps to the remembered position], length: 13pt, {
  cdraw.content((2.6, 8.8), [offset], size: 6.5pt)
  cdraw.line((0.8, 7.9), (21.6, 7.9), stroke: luma(140))
  cdraw.line((0.8, 7.6), (14.2, 7.6), stroke: (paint: luma(100), thickness: 1.2pt))
  cdraw.content((7.5, 8.3), [reads and discards every row here], size: 6pt)
  cdraw.rect((14.4, 7.3), (17.4, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((15.9, 7.7), [page], size: 6pt)
  cdraw.content((2.6, 5.4), [keyset], size: 6.5pt)
  cdraw.line((0.8, 4.5), (21.6, 4.5), stroke: luma(140))
  cdraw.line((0.8, 4.2), (10.2, 4.2), stroke: luma(140))
  cdraw.rect((10.4, 3.9), (11.4, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.9, 4.35), [t], size: 5.5pt)
  cdraw.content((13.4, 5.1), [cursor, remembered], size: 6pt)
  cdraw.line((11.6, 4.35), (14.2, 4.35), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((14.4, 3.9), (17.4, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((15.9, 4.35), [page], size: 6pt)
  cdraw.content((11.5, 1.4), [b-tree range from the key, no rows skipped, ties break by id], size: 6pt)
})

== get and the etag

The etag is not stored, it is computed: sha256 over the exact
wire bytes, hex, quoted, three lines on the record:

#listing("rust/api/src/user.rs", first: 76, last: 84, caption: [wire bytes once, sha256 hex quoted: the etag is a function of the body so the two cannot disagree])

The get handler is four moves, and the `If-None-Match` comparison
is the rfc's, not string equality: a star matches any current
representation, a comma list matches when the etag appears in it,
and both comparisons are weak, so a `W/` prefix still counts:

#listing("rust/api/src/user.rs", first: 641, last: 669, caption: [404 or 304 or 200, and the rfc 9110 none-match rules: star, list, weak])

The 304 rides the kernel's bodyless rule from chapter 19, the
empty frame with the etag and no content-length, and the same
etag string rides both answers so a client caching on it cannot
be misled.

== the vectors drive the tests

The fixture owns everything time-dependent: the frozen ids come
straight out of the vector files, the clock starts at the
contract's origin `1790830800000`, and the hasher is a fake, so
every byte out is deterministic:

#listing("rust/api/tests/user.rs", first: 51, last: 70, caption: [the fixture: vector ids, frozen clock, fake hash, real routes on an ephemeral port])

Vector 01 is the parity proof: the register request from the file
answers 201 with the vector's `Location`, the vector's `ETag`, and
a body that parses equal to the vector's body. The etag assertion
is the byte-exactness, since the etag is the sha256 of the body
and the vector froze both. Vector 02 replays the same
idempotency key and answers 409 here, stated as the staging it
is: the idempotency layer is chapter 25's concurrency family and
lands there. Vector 03 pins the conflict envelope, code, message,
a parseable request id, no details member. Vector 13 seeds the
three walk records directly, ada patched to version 2 through the
seed seam, and walks both pages: the first page equals the
vector's body whole, cursor bytes included, the second returns
the remainder with a null cursor. On the pinned 1.99.0 build,
dated 2026-10-13, the user test file carries 16 green tests: the
three vector runs, the validation table with the codepoint
ceiling, the decode ladder, the normalized conflict, the cursor
round trip and garbage refusal, the limit bounds and the default
20, the etag contract with all four none-match forms, the store
keyset and tie order under 8 concurrent hammering threads, the
sha256, hmac, and pbkdf2 oracles, the production hasher's fresh
salts, and the iso rendering of the vector instants.

sources: RFC 9110, HTTP Semantics, section 8.8.3 on etags and
section 13.1.2 on `If-None-Match`, RFC 8018 for the pbkdf2 construction,
RFC 2104 for hmac, RFC 4231 test case 1 for the hmac-sha256
vector, and FIPS 180-4 for sha256, all at rfc-editor.org and
nvlpubs.nist.gov, accessed 2026-10-13. The pbkdf2 outputs at
iterations 1, 2, and 4096 and the sha256 known answers derived
from python 3 `hashlib` on this machine, dated 2026-10-13, as
the independent oracle. The envelope, the ladder, the bootstrap
rule, the projection, the cursor bytes, and the etag values from
the sibling user chapters, go book 4 chapter 21 and java book 4
chapter 21 of this corpus, and the frozen vectors under
`books/go/api/contract/testdata` hashed byte-exact into this
lane's `contract/testdata`. The hash cost, 2 to 3 s debug and
120 to 140 ms release, re-measured on 2026-10-15 under
`cargo test` and `cargo test --release` on the pinned build. All
other measurements, 16 tests, produced by `cargo test --locked`
under `CARGO_NET_OFFLINE=true`, dated 2026-10-13.
