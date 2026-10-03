#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the user resource

The service's first real resource is the user: a record with an id, an
email, a display name, roles, a creation time, and a version. This
chapter builds the resource layer on the chapter 22 kernel: the
representation and its two projections, strict decoding, validation
from first principles, merge-patch semantics, keyset pagination, the
status contract that binds failures to codes, and the golden handler
tests that pin all of it against the frozen contract vectors.

== the representation

A resource is three things at once: the bytes on the wire, the fields
each reader may see, and the strong etag that names one exact version
of the body. One c\# record expresses all three cheaply: the stored
record and the full wire representation stay one type, because
System.Text.Json maps each property to a member through the snake case
naming policy and a JsonIgnore keeps the password hash off the wire
without a second type drifting beside the first:

#listing("csharp-net/api/src/CsharpBook.Api/Users/User.cs", first: 14, last: 28, caption: [the record, its wire members, and the hash that never rides])

Declaration order is wire order, which is why the frozen vectors'
bytes come out of the serializer with no configuration beyond the
policy. The projection is a second record, and one method chooses
between them: Project answers the full record for an admin and a
four-member public shape for everyone else, so email and roles stay
admin-only data, and a rule enforced in one method cannot be
forgotten in a second handler. The version member is the quiet third
actor: it bumps exactly once per successful write, and the
concurrency chapter promotes it into the compare-and-swap substrate.

The etag is not stored anywhere, it is computed: serialize the full
representation once, sha256 those exact bytes with SHA256.HashData,
quote the hex with Convert.ToHexStringLower. The etag is a function
of the body, so the two can never disagree, and the one UserWire
ETagBody call serves every handler.

#diagram([the record properties against the wire members, one property kept off the wire], length: 13pt, {
  let row(y, cs, json, dimmed) = {
    cdraw.content((4.6, y), cs, size: 6pt)
    cdraw.content((13.6, y), json, size: 6pt)
    if dimmed {
      cdraw.line((2.6, y - 0.35), (7.2, y - 0.35), stroke: luma(140))
      cdraw.line((11.0, y - 0.35), (16.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.6, 8.6), [c\# property], size: 6.5pt)
  cdraw.content((13.6, 8.6), [json member], size: 6.5pt)
  row(7.5, [Id string], [#"id"], false)
  row(6.4, [Email string], [#"email"], false)
  row(5.3, [DisplayName string], [#"display_name"], false)
  row(4.2, [Roles list], [#"roles"], false)
  row(3.1, [CreatedAt offset], [#"created_at"], false)
  row(2.0, [Version int], [#"version"], false)
  row(0.9, [PasswordHash string], [JsonIgnore, never sent], true)
})

One converter carries the timestamps: whole seconds render as RFC 3339
utc with the Z suffix, because the vectors freeze those exact bytes
and the BCL default would render a numeric offset instead. That
converter is the one addition this layer makes to the kernel's shared
options instance, and every DTO in the vehicle serializes through the
combined result.

== decoding with strictness

Input is hostile until proven otherwise, and the kernel's bind helper
answers three questions in a fixed order: is the media type json, is
the body parseable inside the 1 MiB cap, and does it carry only
members the contract knows. The register route runs the whole ladder
in one call, with the strictness riding as one attribute on the dto:

#listing("csharp-net/api/src/CsharpBook.Api/Users/UserEndpoints.cs", first: 43, last: 53, caption: [strict bind, rule validation, then the store, in that order])

JsonUnmappedMemberHandling.Disallow is the strictness that pays rent,
and it is an attribute rather than a decode flag because
System.Text.Json puts the decision on the contract type itself: a
client that sends a pet member against a dto with no pet gets a 400,
not a silently ignored field, so a typo'd member name surfaces at the
border instead of corrupting data six layers in. The kernel's bind
helper maps the thrown JsonException to the invalid_json envelope.

The order matters for the client's sake: the 415 fires before a body
byte is read, the 400 at parse time, and only then does validation
answer 422 with one detail per broken rule. A client fixing its
request learns everything wrong with it in one round trip.

#diagram([the decode ladder: each rung rejects a class of bad input], length: 13pt, {
  let rung(y, q, bad) = {
    cdraw.rect((1.5, y - 0.9), (9.8, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((5.6, y - 0.25), q, size: 6pt)
    cdraw.line((10.2, y - 0.25), (13.0, y - 0.25), stroke: luma(100), mark: (end: ">>"))
    cdraw.content((16.4, y - 0.25), bad, size: 6pt)
    cdraw.line((5.6, y - 1.15), (5.6, y - 1.7), stroke: luma(100))
  }
  rung(7.6, [content type json?], [415 invalid_json])
  rung(5.7, [body under 1 MiB?], [413 payload_too_large])
  rung(3.8, [parses as json?], [400 invalid_json])
  rung(1.9, [known members only?], [400 invalid_json])
  rung(0.0, [field rules hold?], [422, else 201 or 409])
})

== validation from first principles

Validation rules come from the contract, not from a library:
passwords at least 12 characters and at most 128, one email shape,
display names 1 to 64 characters. Stating them as plain code keeps
every number greppable and every message owned. The method returns
one detail per violated rule rather than failing on the first, so the
422 body's details array tells the whole story:

#listing("csharp-net/api/src/CsharpBook.Api/Users/UserValidation.cs", first: 18, last: 44, caption: [one detail per broken rule, in field order])

Three classes of rule run here. Presence rules catch missing members.
Shape rules catch an email that parses as nothing, where MailAddress
plus an exact-address check and a dotted-domain test approximates the
real grammar without rejecting the addresses people actually hold.
Range rules catch lengths. The bounds live in named constants next to
the rules, so handler, tests, and prose quote one set of numbers.

The 422 and the 409 are different animals. A rule violation is about
the request alone, checkable without touching state, so it is 422
validation. The email conflict is about the store's current contents,
so it is 409 conflict, and it surfaces only after validation passed
and the create call answered its conflict outcome. Same request
shape, two different truths.

#diagram([three rule classes, one details array], length: 13pt, {
  let cell(x0, x1, title, l1, l2) = {
    cdraw.rect((x0, 5.4), (x1, 8.1), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 7.4), title, size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, 6.5), l1, size: 6pt)
    cdraw.content(((x0 + x1) / 2, 5.7), l2, size: 6pt)
  }
  cell(0.8, 7.2, [presence], [email required,], [password required])
  cell(8.2, 14.6, [shape], [one at sign,], [dotted domain])
  cell(15.6, 22.0, [range], [password 12 to 128,], [name 1 to 64])
  cdraw.content((11.4, 4.3), [every violation, one row in the 422 details array], size: 6pt)
})

== patch merge semantics

RFC 7386 merge-patch gives updates three-way semantics a typed record
cannot express: an absent member leaves the field alone, null deletes
it, a value replaces it. So the patch decodes into a member map of
JsonElement values, not a dto, and the handler walks the members in
sorted order so details are deterministic:

#listing("csharp-net/api/src/CsharpBook.Api/Users/UserEndpoints.cs", first: 149, last: 173, caption: [the member walk: immutable members refuse, null on the display name too, the rest validate])

The contract makes one member writable, the display name, and the
switch shows the full policy in one expression: null answers 422,
because deleting the display name would leave the record invalid, a
non-string answers 422, and a string runs the same range rules
registration runs. The immutable members, id, email, created_at,
version, roles, refuse the moment they appear, null or not: patching
them is not a validation typo, it is an attempt to write a field the
contract closed. Unknown members refuse too, the same strictness the
typed register decode enforced with an attribute, enforced here by
the member walk because a dictionary cannot carry that attribute.

After the walk, the precondition and the write run in order. The
client's If-Match must equal the etag of the current body, else 412,
and the update carries the expected version so a write that lost a
race answers 412 as well rather than silently clobbering. The no-op
patch, an empty object, is legal and answers 200 with the current
representation, nothing bumped.

#diagram([a patch request walks the members, then the precondition, then the store], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [decode], [member map,], [415 413 400], luma(235))
  stage(6.0, [walk], [null deletes,], [immutable 422], luma(235))
  stage(11.4, [precondition], [If-Match equals,], [etag, else 412], luma(235))
  stage(16.8, [store], [version check,], [bump on win], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [200 plus a new etag, version 1 to 2], size: 6pt)
  cdraw.content((11.5, 3.5), [absent members never reached the store at all], size: 6pt)
})

== keyset pagination

Offset pagination asks for row 86041 onward, and it fails twice. The
database still walks and discards every skipped row, so page 4000
costs what a table scan costs, and offsets are positions in a moving
file: one registration between requests and a row appears twice or
vanishes. Keyset pagination fixes both by remembering where it stopped
rather than counting from the front. The order is the pair
(created_at, id), the cursor encodes the last row's position, and the
next page is everything strictly after it:

#listing("csharp-net/api/src/CsharpBook.Api/Users/Pagination.cs", first: 52, last: 65, caption: [the cursor: created_at milliseconds plus the id tiebreaker, base64url unpadded])

The payload is deliberately tiny, two members, because the cursor is
a position, not a page number. Time is milliseconds since the epoch,
the id breaks ties when two users share a creation millisecond, and
uuid v7 ids sort by their own embedded time, so the composite order
is total. The encoding rides the BCL's Base64Url type, unpadded by
construction: opaque to clients, trivially decodable in a test, and
the frozen vectors carry its exact bytes. A cursor the service never
issued is garbage, not a missing page, so decode failures answer 422,
and the limit must be an integer in 1..100, 422 otherwise, default 20. The store query asks for one row over the limit, so the
has-more signal comes from data the page returned.

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
  cdraw.content((11.5, 1.4), [cost flat, no rows skipped, no drift; ties break by id], size: 6pt)
})

== the status contract

Every failure this layer can produce already has a code in the
chapter 22 table, so the resource layer states outcomes and the table
states statuses. The get handler is the whole ladder in one screen:
401 without an actor, 404 for an unknown id, 403 for a stranger on
someone else's record, then the etag work:

#listing("csharp-net/api/src/CsharpBook.Api/Users/UserEndpoints.cs", first: 82, last: 98, caption: [the failure ladder before any body is written])

After the ladder comes the one status that is not a failure, 304. If
the client's If-None-Match equals the computed etag, the body it
already holds is current, and the service answers the header and
nothing else. Each failure is one thrown ApiError the kernel's
exception middleware renders as the one envelope, so no handler in
this chapter writes a failure body itself.

The order inside the ladder is a policy choice this chapter owns: the
404 answers before the 403, so an unknown id and a stranger's id are
distinguishable. APIs that prefer to hide existence answer 404 for
both, and the authz chapter walks that tradeoff. No route here
invents a status or an envelope shape.

#diagram([one request climbs the ladder, each rung one contract code], length: 13pt, {
  let rung(y, label, fill) = {
    cdraw.rect((4.8, y), (18.2, y + 1.25), fill: fill, radius: 0.02)
    cdraw.content((11.5, y + 0.6), label, size: 6pt)
  }
  rung(6.6, [401 no actor], luma(235))
  rung(5.0, [404 unknown id], luma(235))
  rung(3.4, [403 stranger on another account], luma(235))
  rung(1.8, [304 If-None-Match equal, else 200 plus ETag], luma(222))
  cdraw.line((11.5, 6.5), (11.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 4.9), (11.5, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 3.3), (11.5, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 0.7), [patch adds 412 above the ladder, one envelope for every failure], size: 6pt)
})

== golden handler tests

The frozen vectors under `contract/testdata` are the fixture source of
truth, and the tests read them as data: ids, offsets, expected etag
strings, expected cursor bytes all come from the json files, so a test
never re-derives a constant the contract already froze. The walk test
shows the shape: seed three users at the vector's offsets, ask for a
page as a non-admin, and demand both pages against the vector bodies:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Users/UsersApiVectorTests.cs", first: 185, last: 193, caption: [the vector walk: both pages judged against the frozen bodies])

Exactness is the point. The etag assertion proves the body bytes byte
for byte, because the etag is the sha256 of those bytes, and the
cursor assertion proves the encoding down to the missing padding. The
harness around it injects everything time-dependent: a stepped
TimeProvider, a scripted id source handing out the vector's uuids, a
scripted request-id source the middleware stamps into every envelope,
and a fake hasher standing in for the pbkdf2 the authn chapter brings.
The whole service runs over TestServer, the framework's in-memory
host, so nothing sleeps, nothing dials a socket, and every response
comes out of the same pipeline production traffic takes.

The same discipline covers the rest of the slice: register 201 and
409, the 422 details array, unknown and immutable patch members, the
stale If-Match 412, the 25-user default-limit walk, and the ownership
grid. The register replay vector, 02, rides the idempotency guard the
concurrency chapter ships: the register route buffers the keyed body,
the guard stores the 201 snapshot, and the retry answers those exact
bytes again, Location and etag derived back from the body because the
etag is a function of the body. The same key under a different body
answers 422, contract misuse. When a vector changes the code is
wrong, and when the code changes an output byte a vector fails.

#diagram([a golden test: the vector file drives the fixture and judges the harness], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector json], [ids, offsets,], [frozen bytes], luma(235))
  stage(6.0, [harness], [stepped clock, ids,], [fake hasher], luma(235))
  stage(11.4, [test server], [in-memory host,], [no socket], luma(235))
  stage(16.8, [assert], [etag, cursor,], [status, body], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [drift means the code is wrong, never the vector], size: 6pt)
})

sources: RFC 7386, JSON Merge Patch, and RFC 9110, HTTP Semantics
sections 8.8.3 and 13.1.1 on etags and conditional requests, both at
rfc-editor.org. Microsoft Learn, verified 2026-09-26:
learn.microsoft.com/dotnet/api/system.text.json.serialization.jsonunmappedmemberhandling
for Disallow semantics,
learn.microsoft.com/dotnet/standard/serialization/system-text-json/missing-members
for the attribute placement,
learn.microsoft.com/dotnet/api/system.buffers.text.base64url for the
base64url codec, and
learn.microsoft.com/dotnet/api/system.security.cryptography.sha256.hashdata
plus learn.microsoft.com/dotnet/api/system.convert.tohexstringlower
for the etag digest rendering. The keyset-versus-offset argument
follows use-the-index-luke.com on offset paging. Verified by
`books/csharp-net/api` tests under `dotnet test`, the users and authn
suites green.
