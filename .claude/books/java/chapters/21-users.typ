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

The service's first real resource is the user: a record with an id,
an email, a display name, a creation time, and a version. This
chapter builds the whole resource layer on the chapter 19 kernel in
`javabook.user`: the representation and its explicit wire writer,
registration with validation from first principles, the store as a
port with an in-memory implementation, the password hashing seam that
carries chapter 17's cryptography into the service, keyset pagination
with byte-exact cursors, the etag contract on read, and the handler
tests that pin all of it over a real socket with a fixture the code
owns. The go book built the same layer, #xref-to("go", "users"), and
this chapter keeps its contracts while spending its java differences,
explicit writers instead of struct tags, injected functions instead
of interface fields, where they earn their keep.

== the representation

A record is the whole stored type: six components, one line of
syntax, equality and accessors free. The wire representation is a
method, not a second type: `toJson` builds a `LinkedHashMap` in fixed
member order, and that explicitness is what keeps the password hash
off the wire. Go needed a dash tag on `PasswordHash` so its reflection
serializer would skip it, and the tag was the one line where a
missing character leaks a hash. Here the writer writes what it lists,
nothing else exists, and the test that pins the 201 body asserts the
absence directly:

#listing("java/api/src/javabook/user/User.java", first: 15, last: 33, caption: [the record and its wire writer: the members on the wire are the members toJson puts])

The `created_at` member is `Instant.toString`, the iso-8601 form with
a `Z` suffix, deterministic for a fixed instant, which is what makes
the etag and the test bytes stable. The version member is the quiet
third actor: it starts at 1, bumps once per successful write when
updates arrive in chapter 25's scope, and becomes the compare-and-swap
substrate there.

#diagram([the record components against the wire members, one component never written], length: 13pt, {
  let row(y, field, json, dimmed) = {
    cdraw.content((4.6, y), field, size: 6pt)
    cdraw.content((13.6, y), json, size: 6pt)
    if dimmed {
      cdraw.line((2.6, y - 0.35), (7.2, y - 0.35), stroke: luma(140))
      cdraw.line((11.0, y - 0.35), (16.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.6, 8.6), [record component], size: 6.5pt)
  cdraw.content((13.6, 8.6), [wire member], size: 6.5pt)
  row(7.5, [id String], [#"id"], false)
  row(6.4, [email String], [#"email"], false)
  row(5.3, [displayName String], [#"display_name"], false)
  row(4.2, [createdAt Instant], [#"created_at"], false)
  row(3.1, [version int], [#"version"], false)
  row(2.0, [passwordHash String], [never written], true)
  cdraw.content((11.4, 0.7), [go needed a dash tag, java needs nothing: the writer is explicit], size: 6pt)
})

== create, validation, and the 422 versus 409 boundary

The create handler is the decode ladder from chapter 19 with a
resource on top of it, and the order is the contract: the kernel's
`bindJson` answers the 415, the 413, the parse 400, and the unknown
member 400, then the typed member read answers a 400 for a non-string
value, and only then does validation see clean strings:

#listing("java/api/src/javabook/user/Users.java", first: 41, last: 63, caption: [strict bind, typed members, every rule checked, then the store])

The rules come from the contract, not from a library, because the jdk
has no bean validation and the numbers should be greppable anyway:
passwords 12 to 128 characters, display names 1 to 64, one email
shape. The email rule is a seven-token regex, one `@`, nonempty local
part, dotted domain, no whitespace, capped at 254 characters, the
approximation that accepts the addresses people hold. Every rule
reports into one details array rather than failing on the first, so
one round trip tells the client everything wrong:

#listing("java/api/src/javabook/user/Validation.java", first: 34, last: 54, caption: [one detail per violated rule, in field order, nothing short-circuits])

The 422 and the 409 are different animals and the boundary is worth
stating. A rule violation is about the request alone, checkable
without touching state, so it is 422 validation. The email conflict
is about the store's current contents, so it is 409 conflict, and it
surfaces only after validation passed and the store answered its
exception. The store speaks outcomes, the handler maps them to
statuses, and no layer does the other's job. Normalization closes the
last gap: emails are trimmed and lower-cased before the store sees
them, so `Ada@Example.ORG` cannot dodge a conflict with
`ada@example.org`, and the test registers both spellings and asserts
the 409.

#diagram([same request shape, two truths: rules about the request, conflict about the store], length: 13pt, {
  pane(0.4, 10.6, 7.6, [the request alone], [email shape, password length,], [name presence: 422])
  cdraw.line((5.5, 5.4), (5.5, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 10.6, 4.2, [the store's contents], [duplicate normalized email], [409 conflict])
  cdraw.line((11.0, 6.0), (12.0, 6.0), stroke: luma(100), mark: (end: ">>"))
  pane(12.2, 22.8, 7.6, [the same ladder], [415, 413, 400, 400,], [then 422, then 409])
})

== the store seam

The persistence port is three methods, create, get, list, frozen now
because chapter 24 implements the same interface over a real engine
and two chapters build against one shape. The in-memory
implementation is deliberately boring: one monitor, an id map, an
email map, and an order list kept sorted by the keyset key with a
binary insertion, so `list` walks one sorted slice and reads live
records through the map:

#listing("java/api/src/javabook/user/MemStore.java", first: 22, last: 40, caption: [one monitor, two maps, a sorted order slice with binary insertion])

Every method is `synchronized`, the whole locking story for a page
this size. The chapter 10 concurrency material would replace the
monitor with a `ReentrantReadWriteLock` if reads dominated, and the
store chapter will replace the entire class with an engine, and
neither change touches a handler, which is the point of the seam.

== the password seam

The handler never hashes. It calls a `Hasher`, a one-method interface
whose production implementation is the pbkdf2 chapter 17 measured:
100,000 iterations of hmac-sha256 over a fresh 16 byte salt, the
salt, the count, and the digest all encoded into the stored string so
the authn chapter can verify against a self-describing value:

#listing("java/api/src/javabook/user/Hasher.java", first: 23, last: 43, caption: [the production hasher: chapter 17's pbkdf2, self-describing output])

Two choices worth their ink. The hash lands in the record at
registration because storing plaintext is not an option and computing
the hash lazily would mean a write path later. And the test fixture
injects a fake `p -> "fake:" + p`, because 100,000 iterations per
registration is the cost production pays on purpose and no fixture
wants to pay it 25 times a page test: measured on this machine, a
full register round trip through the booted program with the real
hasher took 186 ms on one run and 34 to 145 ms across a re-measured
set, all of it the hash, while the whole test class with the
fake runs its 11 tests in well under a second.

== keyset pagination

Offset pagination asks for row 86041 onward, and it fails twice: the
store walks and discards every skipped row, and offsets are positions
in a moving file, so one registration between requests makes a row
appear twice or vanish. Keyset pagination remembers where it stopped
instead of counting from the front. The order is the pair, creation
millisecond then id, and the cursor is that pair as json, base64url
without padding, opaque to clients and decodable in a test:

#listing("java/api/src/javabook/user/Cursor.java", first: 45, last: 53, caption: [the cursor: two members, json, base64url unpadded])

The decode path is strict in the same direction as everything else in
the kernel: a cursor is either one this service issued or garbage,
never a missing page, so every failure down the base64, the json
parse, and the member checks answers the same 422, and a forged
cursor carrying members this service never writes, an extra `junk`
key for instance, is refused the same way. The limit rejects
anything outside 1..100 with a default of 20, and the list handler
asks the store for `limit + 1` rows so the presence of one extra row
is the whole has-more computation, no counts, no second query:

#listing("java/api/src/javabook/user/Users.java", first: 105, last: 125, caption: [limit plus one read, one extra row means has-more, the cursor names the last row kept])

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
  cdraw.content((11.5, 1.4), [cost flat, no rows skipped, no drift, ties break by id], size: 6pt)
})

== get and the etag

The etag is not stored, it is computed: sha256 over the exact wire
bytes of the representation, hex, quoted. Because the etag is a
function of the body the two can never disagree, and because the
writer is deterministic the same record yields the same etag forever.
The get handler is four moves: resolve the id off the path parameter,
answer 404 through the one failure path, run the `If-None-Match`
comparison and answer 304 with the header and no body when it hits,
else 200 with the etag and the body. The comparison is the rfc's,
not plain string equality: a star matches any current
representation, a comma list matches when the etag appears in it,
and both comparisons are weak, so a `W/` prefix still counts:

#listing("java/api/src/javabook/user/Users.java", first: 65, last: 80, caption: [404 or 304 or 200: the conditional read in sixteen lines])

#listing("java/api/src/javabook/user/Users.java", first: 82, last: 104, caption: [noneMatch: star, list, and weak forms, the rfc 9110 rules])

The 304 uses the `RSPBODY_EMPTY` constant from chapter 19, the
no-body length the exchange api names, and the same etag string rides
both answers so a client caching on it cannot be misled. Chapter 25's
update scope will add `If-Match` against the same value, which is
when the version member starts earning its keep.

== handler tests over http

The fixture owns everything time-dependent, and in java that is three
lambdas and a clock subclass: a `StepClock` advancing one second per
`instant` call, so five registrations hold five distinct creation
times without sleeping, an id source counting `u1` through `u25`, and
the fake hasher. The boot helper reads like the production wiring in
`Main`, which is the review trick: the wiring table and the fixture
differ only in the injected functions:

#listing("java/api/test/javabook/user/UserResourceTests.java", first: 50, last: 59, caption: [the fixture: step clock, counted ids, fake hash, real routes])

#listing("java/api/src/javabook/Main.java", first: 71, last: 76, caption: [the wiring table: kernel routes, then the user family, one register call per family as later chapters add theirs])

Exactness is the point. The page-walk test seeds five users and
asserts the first page's whole body, byte for byte, including the
cursor, which for the fixture's second user is
`eyJ0IjoxNzY3MjI1NjAxMDAwLCJpIjoidTIifQ`: the base64url of
`{"t":1767225601000,"i":"u2"}`, the 2026-01-01 creation second the
step clock handed out. The rest of the slice covers the ladder, every
violation at once, the normalized conflict, the 404, the 304 on a
matching etag, the star, list, and weak forms beside it, the forged
cursor shape refused, the limit rejections, and the default 20 with
its 5-row tail, 11 tests, run green three times consecutively. When
the cursor changes the code is
wrong, and when the code changes an output byte the test fails:
drift has nowhere to hide.

#diagram([a golden test: the fixture drives the bytes, the socket carries them, the assertions read them back], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [fixture], [step clock, counted ids,], [fake hash], luma(235))
  stage(6.0, [routes], [the real handlers], [on an ephemeral port], luma(235))
  stage(11.4, [client], [the standard HttpClient], [real socket], luma(235))
  stage(16.8, [assert], [exact bodies, cursors,], [etags, details], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [nothing sleeps, nothing dials beyond localhost, no mocks over the jdk], size: 6pt)
})

sources: RFC 9110, HTTP Semantics, sections 8.8.3 and 13.1.1 on etags
and conditional requests, at rfc-editor.org. The pbkdf2 construction,
`PBKDF2WithHmacSHA256`, 100,000 iterations, 16 byte salt, is the one
chapter 17 verified against rfc 8018 and measured on this build, and the
register round trips through the booted `javabook.Main` with
the production hasher measured 186 ms once and 34 to 145 ms across a
re-measured set on 2026-10-04. The keyset versus
offset argument follows the same use-the-index-luke reasoning the go
book cited. Verified live 2026-10-04 by the `javabook.user` tests
under the vendored junit 6.1.3 lane, 11 tests green three consecutive
runs, 44 across the module, covering the 201 body, Location, and
64-hex etag, the whole decode ladder including the unknown member and
non-string messages, the three-violation 422 details array, the
normalized 409, the 404, the 304 and etag equality plus the star,
list, and weak forms, the byte-exact
three-page walk with cursor `eyJ0IjoxNzY3MjI1NjAxMDAwLCJpIjoidTIifQ`,
the forged cursor shape, the limit and cursor rejections, and the
default-20 tail page.
