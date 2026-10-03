#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the user resource

The service's first real resource is the user: a record with an id, an
email, a display name, roles, a creation time, and a version. This
chapter builds the whole resource family in
`books/javascript/api/src/users/`: the representation and its two
projections as object literals, strict decoding on top of the kernel's
codec, validation from first principles, merge-patch semantics for
updates, keyset pagination for lists, the status contract that binds
failures to codes, and the golden handler tests that pin all of it
against the frozen vectors. The go mirror built the same layer
over typed structs and `json/v2` tags, and node has none, so the
discipline moves into the literals themselves, insertion order is
serialization order, and the vectors prove the bytes.

== the representation

A resource is three things at once: the bytes on the wire, the fields
each reader may see, and the strong etag that names one exact version
of the body. The stored record keeps a `passwordHash` field for the
authn family, and the projection literals simply never mention it, so
the hash cannot leak by construction, the same trick the go lane
played with a dash tag. One function chooses between the two
projections:

#listing("javascript/api/src/users/model.mjs", first: 25, last: 44, caption: [the two projections, one chooser, field-level authorization lives here])

The projection is where field-level authorization lives. Email and
roles are admin-only data, so the list handler never decides what to
hide, it calls one function and writes whatever comes back, and a
rule enforced in one function cannot be forgotten in a second
handler. The literal's insertion order is the wire order, javascript
specifies it for string keys, so `wireBody` is `JSON.stringify` over
this literal and nothing else. The `version` member bumps exactly
once per successful write, and the concurrency chapter promotes it
into the compare-and-swap substrate.

The etag is not stored anywhere, it is computed: `etagOf` takes the
exact body string, sha256s it through `createHash`, and quotes the
hex. Because the etag is a function of the body, the two can never
disagree, and a client that saves the etag has saved the body's
fingerprint.

#diagram([the record's fields against the wire members, one field never sent], length: 13pt, {
  let row(y, stored, json, dimmed) = {
    cdraw.content((4.6, y), [#stored], size: 6pt)
    cdraw.content((13.6, y), [#json], size: 6pt)
    if dimmed {
      cdraw.line((2.6, y - 0.35), (7.2, y - 0.35), stroke: luma(140))
      cdraw.line((11.0, y - 0.35), (16.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.6, 8.6), [stored field], size: 6.5pt)
  cdraw.content((13.6, 8.6), [json member], size: 6.5pt)
  row(7.5, [id], [#"id"], false)
  row(6.4, [email], [#"email"], false)
  row(5.3, [displayName], [#"display_name"], false)
  row(4.2, [roles], [#"roles"], false)
  row(2.4, [createdAtMs, version], [#"created_at, version"], false)
  row(1.0, [passwordHash], [never on the wire], true)
})

== decoding with strictness

Input is hostile until proven otherwise, and the decode ladder answers
four questions in a fixed order: is the media type json at all, is the
body inside the 1 MiB cap, does it parse, and does it carry only
members the contract knows. The kernel's `readJson` owns the first
three, chapter 23 built them. The family owns the fourth, because the
accepted member set differs per route and only the route knows it:

#listing("javascript/api/src/users/handlers.mjs", first: 50, last: 63, caption: [the schema rung: unknown member or wrong type is a decode failure, 400])

The strictness that pays rent is the unknown-member refusal. A client
that sends a `pet` member against a contract with no `pet` gets a 400,
not a silently ignored field, so a typo surfaces at the border instead
of corrupting data six layers in. Go bought this with
`RejectUnknownMembers` on the typed decode, and the js vehicle buys it
with a plain loop over `Object.entries`, the wrong-type check riding
the same loop because a registration email that arrives as a number
is a decode problem, not a validation rule. A missing member arrives
as `undefined` and the presence rules answer 422, so the rungs keep
the go lane's split, decode failures 400, rule failures 422.

#diagram([the decode ladder: each rung rejects a class of bad input], length: 13pt, {
  let rung(y, q, bad) = {
    cdraw.rect((1.5, y - 0.9), (9.8, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((5.6, y - 0.25), [#q], size: 6pt)
    cdraw.line((10.2, y - 0.25), (13.0, y - 0.25), stroke: luma(100), mark: (end: ">>"))
    cdraw.content((16.4, y - 0.25), [#bad], size: 6pt)
    cdraw.line((5.6, y - 1.15), (5.6, y - 1.7), stroke: luma(100))
  }
  rung(7.6, [content type json?], [415 invalid_json])
  rung(5.7, [body under 1 MiB?], [413 payload_too_large])
  rung(3.8, [parses as json?], [400 invalid_json])
  rung(1.9, [known members, right types?], [400 invalid_json])
  rung(0.0, [field rules hold?], [422, else 201 or 409])
})

== validation from first principles

Validation rules come from the contract, not from a library: passwords
at least 12 characters and at most 128, one email shape, display names
1 to 64 characters. Stating them as plain code keeps every number
greppable and every message owned. The function returns one detail per
violated rule rather than failing on the first, so the 422 body's
`details` array tells the whole story and a client fixes everything in
one round trip:

#listing("javascript/api/src/users/validate.mjs", first: 14, last: 34, caption: [one detail per broken rule, in field order, every bound a named constant])

Three classes of rule run here. Presence rules catch missing members.
Shape rules catch an email that parses as nothing, where the go lane
reached for `net/mail` and its `ParseAddress`, node ships no mail
parser, so the shape is stated directly: exactly one at sign, a
non-empty local part, a dotted domain with no leading or trailing dot
and no doubled dot, no whitespace, a length cap. It approximates the
real grammar without rejecting addresses people hold. Range rules
catch lengths, and the bounds live in named constants next to the
rules so the handler, the tests, and this chapter quote one set of
numbers.

The 422 and the 409 are different animals and the boundary is worth
stating. A rule violation is about the request alone, checkable
without touching state, so it is 422. The email conflict is about the
store's current contents, so it is 409, and it surfaces only after
validation passed and the create call answered its conflict outcome.
Same request shape, two different truths. Normalization closes one
gap before it opens: emails lower-case and trim on the way in, so
`Ada@Example.ORG` cannot dodge a conflict or mint a second account.

#diagram([three rule classes, one details array], length: 13pt, {
  let col(x, title, l1) = {
    cdraw.content((x, 8.1), [#title], size: 6.5pt)
    cdraw.content((x, 7.1), [#l1], size: 6pt)
  }
  col(4.0, [presence], [email, password required])
  col(11.5, [shape], [one at sign, dotted domain])
  col(19.0, [range], [password 12 to 128, name 1 to 64])
  cdraw.content((11.4, 4.3), [every violation, one row in the 422 details array], size: 6pt)
})

== patch merge semantics

RFC 7386 merge-patch gives updates three-way semantics a fixed member
list cannot express: an absent member leaves the field alone, null
deletes it, a value replaces it. So the patch decodes into a plain
parsed object, and the handler walks the members in sorted order so
details are deterministic:

#listing("javascript/api/src/users/handlers.mjs", first: 220, last: 241, caption: [the member walk: null on the name refuses, immutable members refuse, unknown refuse])

The contract makes one member writable, the display name, and the
walk shows the full policy in one `if` chain. A null on it answers
422, because deleting the display name would leave the record invalid.
The immutable members, `id`, `email`, `created_at`, `version`,
`roles`, refuse the moment they appear, null or not: patching them is
not a validation typo, it is an attempt to write a field the contract
closed, and the same strictness the schema rung gave register arrives
here through the walk because a parsed object cannot carry that rung.
The empty patch object is legal and answers 200 with the current
representation, nothing bumped.

After the walk, the precondition and the write run in order. The
client's `If-Match` must equal the etag of the current body, else 412,
and the update carries the expected version into the store so a write
that lost a race answers 412 rather than clobbering. The no-op case
short-circuits: the store is never called, the current body answers.

#diagram([a patch walks the members, then the precondition, then the store], length: 13pt, {
  let stage(x0, title, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.4), [#title], size: 6.5pt)
  }
  stage(0.6, [decode, 415 413 400], luma(235))
  stage(6.0, [walk, null 422], luma(235))
  stage(11.4, [If-Match, else 412], luma(235))
  stage(16.8, [store, bump on win], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [200 plus a new etag, version 1 to 2], size: 6pt)
  cdraw.content((11.5, 3.5), [an empty object answers 200, nothing bumped], size: 6pt)
})

== keyset pagination

Offset pagination asks for row 86041 onward, and it fails twice. The
store still walks and discards every skipped row, so page 4000 costs
what a table scan costs. And offsets are positions in a moving file:
one registration between requests and a row appears twice or vanishes.
Keyset pagination fixes both by remembering where it stopped rather
than counting from the front. The order is the pair `created_at` then
`id`, the cursor encodes the last row's position, and the next page is
everything strictly after it:

Encoding is three statements, stringify the two-member literal, wrap
it in `Buffer.from`, call `toString("base64url")`, and vector 13
freezes the exact bytes. Decoding answers null for every malformed
shape:

#listing("javascript/api/src/users/pagination.mjs", first: 22, last: 44, caption: [decode: every malformed shape answers null, the timestamp bounded to the renderable range])

The payload is deliberately tiny, two members, because the cursor is a
position, not a page number. Time is milliseconds since the epoch, the
id breaks ties when two users share a creation millisecond, and uuid
v7 ids sort by their own embedded time, so the composite order is
total. The encoding is `Buffer.toString("base64url")`, node's one-call
form of what the go lane built from `encoding/base64`, opaque to
clients and trivially decodable in a test. Decode rejects padding,
non-objects, non-integer `t`, and an empty `i`, all with null, because
garbage is a 422, never a 404. The limit must be an integer in 1..100
with a default of 20, and one probe from the full stack earned its
keep here: `URLSearchParams.get` answers null for a missing key, not
undefined, so the absence check reads both.

#diagram([offset walks the whole prefix, keyset jumps to the remembered position], length: 13pt, {
  cdraw.content((2.6, 8.8), [offset], size: 6.5pt)
  cdraw.line((0.8, 7.9), (21.6, 7.9), stroke: luma(140))
  cdraw.line((0.8, 7.6), (14.2, 7.6), stroke: (paint: luma(100), thickness: 1.2pt))
  cdraw.content((7.5, 8.3), [reads and discards every row here], size: 6pt)
  cdraw.rect((14.4, 7.3), (17.4, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((15.9, 7.7), [page], size: 6pt)
  cdraw.content((2.6, 5.4), [keyset], size: 6.5pt)
  cdraw.line((0.8, 4.5), (21.6, 4.5), stroke: luma(140))
  cdraw.line((0.8, 4.2), (12.2, 4.2), stroke: (paint: luma(140)))
  cdraw.rect((12.4, 3.9), (15.4, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((13.9, 4.35), [cursor, then page], size: 6pt)
  cdraw.content((11.5, 1.6), [cost flat, no rows skipped, ties break by id], size: 6pt)
})

== the status contract

Every failure this layer can produce already has a code in the
kernel's table, so the resource layer states outcomes and the table
states statuses. The get handler is the whole ladder in one screen:
401 without an actor, 404 for an unknown id, 403 for a stranger
touching someone else's record, then the etag work:

#listing("javascript/api/src/users/handlers.mjs", first: 136, last: 154, caption: [the failure ladder, then the one status that is not a failure, 304])

After the ladder comes the 304. If the client's `If-None-Match` equals
the computed etag, the body it already holds is current, and the
service answers the header and nothing else. The order inside the
ladder is a policy choice this chapter owns: the 404 answers before
the 403, so an unknown id and a stranger's id are distinguishable,
and the authz chapter walks that tradeoff explicitly. What the
contract forbids is a third path, no route here invents a status or
an envelope shape, because every failure goes through one `fail`
throw the kernel renders.

The store underneath speaks outcomes, not statuses, `StoreError`
codes mapped once in one helper. And node's single thread deletes a
whole go concern: the memory store is a map, an email index, and a
sorted id array with no mutex anywhere, because every method is
synchronous and nothing awaits mid-mutation. The store chapter
revisits the point when the sqlite engine lands, `DatabaseSync` is
synchronous by design.

#diagram([one request climbs the ladder, each rung one contract code], length: 13pt, {
  let rung(y, label, fill) = {
    cdraw.rect((4.8, y), (18.2, y + 1.25), fill: fill, radius: 0.02)
    cdraw.content((11.5, y + 0.6), [#label], size: 6pt)
  }
  rung(6.6, [401 no actor], luma(235))
  rung(5.0, [404 unknown id], luma(235))
  rung(3.4, [403 stranger on another account], luma(235))
  rung(1.8, [304 If-None-Match equal, else 200 plus ETag], luma(222))
  cdraw.line((11.5, 6.5), (11.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 3.3), (11.5, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 0.7), [patch adds 412 above the ladder, one envelope for every failure], size: 6pt)
})

== golden handler tests

The frozen vectors under `contract/testdata` are the fixture source of
truth, and the tests read them as data: ids, timestamps, etag strings,
cursor bytes all come from the JSON files, so a test never re-derives
a constant the contract already froze. The harness is the kernel
chapter's recorder pair plus a request double that carries its body
as one async-iterable chunk, `readJson` runs its real ladder over it,
and a `drive` helper runs one handler the way the stack runs it, the
recover adapter rendering a thrown `ApiError` into the recorder:

#listing("javascript/api/test/users/handlers.test.mjs", first: 314, last: 327, caption: [the vector walk: two pages, cursor bytes exact, items exact])

Exactness is the point. The etag assertion proves the body bytes byte
for byte, the etag is the sha256 of those bytes, and the cursor
assertion proves the encoding down to the missing padding. The
fixture injects everything time-dependent: a mutable millisecond
clock advanced by hand, an id source handing out the vector's uuids,
a fake hasher whose value never reaches the wire, and every response
comes out of the recorder. Vector 02's replay is asserted here as the
property the concurrency chapter's keyed wrapper replays, the same
inputs produce the same snapshot bytes. The rest of the slice covers
register 201 and 409, the 422 details array, unknown and immutable
patch members, the stale `If-Match` 412, and the ownership grid. When
a vector changes the code is wrong, and drift has nowhere to hide.

#diagram([a golden test: the vector file drives the fixture and judges the recorder], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), [#l1], size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), [#l2], size: 6pt)
  }
  stage(0.6, [vector json], [ids, offsets,], [frozen bytes], luma(235))
  stage(6.0, [fixture], [clock, ids,], [fake hasher], luma(235))
  stage(11.4, [handler], [recorder,], [no socket], luma(235))
  stage(16.8, [assert], [etag, cursor,], [status, body], luma(222))
  cdraw.content((11.5, 4.9), [drift means the code is wrong, never the vector], size: 6pt)
})

sources: RFC 7386, JSON Merge Patch, and RFC 9110 sections 8.8.3 and
13.1.1 on etags and conditional requests, at rfc-editor.org.
nodejs.org/api/crypto.html for `createHash` and `digest`.
nodejs.org/api/buffer.html for `Buffer.from` and the base64url
family. nodejs.org/api/url.html for `URLSearchParams.get` answering
null on a miss. developer.mozilla.org for `Object.entries`,
`JSON.stringify` own-key ordering, and `String.includes`. Accessed
2026-09-26. Verified by `books/javascript/api/test/users` tests, 50
of them, under `npm run verify` with prettier clean.
