#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the user resource

The service's first real resource is the user: a record with an id, an
email, a display name, roles, a creation time, and a version. This
chapter builds the whole resource layer on the chapter 18 kernel: the
representation and its two projections, strict json/v2 decoding,
validation from first principles, merge-patch semantics for updates,
keyset pagination for lists, the status contract that binds failures
to codes, and the golden handler tests that pin all of it against the
frozen contract vectors.

== the representation

A resource is three things at once: the bytes on the wire, the fields
each reader may see, and the strong etag that names one exact version
of the body. Go structs express all three cheaply. The stored record
and the full wire representation are one type, because json/v2 tags
map every field to its member and a dash tag keeps the password hash
out of every marshal without a second struct to drift. The projection
is a second struct, and one method chooses between them:

#listing("go/api/internal/user/user.go", first: 25, last: 45, caption: [the record, its wire tags, and the public projection])

The projection is where field-level authorization lives. Email and
roles are admin-only data, so the list handler never decides what to
hide, it calls one method and writes whatever comes back. That is the
whole trick: a rule enforced in one function cannot be forgotten in a
second handler. The version member is the quiet third actor. It bumps
exactly once per successful write, and the chapter 24 concurrency
material will promote it into the compare-and-swap substrate.

The etag is not stored anywhere, it is computed: marshal the full
representation once, sha256 those exact bytes, quote the hex. Because
the etag is a function of the body, the two can never disagree, and a
client that saves the etag has effectively saved the body's
fingerprint:

#snippet(
  "func ETagBody(body []byte) string {\n"
  + "\tsum := sha256.Sum256(body)\n"
  + "\treturn `\"` + hex.EncodeToString(sum[:]) + `\"`\n"
  + "}",
  lang: "go",
)

#diagram([the struct fields against the wire members, one field kept off the wire], length: 13pt, {
  let row(y, go, json, dimmed) = {
    cdraw.content((4.6, y), go, size: 6pt)
    cdraw.content((13.6, y), json, size: 6pt)
    if dimmed {
      cdraw.line((2.6, y - 0.35), (7.2, y - 0.35), stroke: luma(140))
      cdraw.line((11.0, y - 0.35), (16.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.6, 8.6), [go field], size: 6.5pt)
  cdraw.content((13.6, 8.6), [json member], size: 6.5pt)
  row(7.5, [ID string], [#"id"], false)
  row(6.4, [Email string], [#"email"], false)
  row(5.3, [DisplayName string], [#"display_name"], false)
  row(4.2, [Roles []string], [#"roles"], false)
  row(3.1, [CreatedAt time.Time], [#"created_at"], false)
  row(2.0, [Version int], [#"version"], false)
  row(0.9, [PasswordHash string], [dash, never sent], true)
})

== decoding with strictness

Input is hostile until proven otherwise, and the kernel's decode
ladder answers three questions in a fixed order: is the media type
json at all, is the body parseable inside the 1 MiB cap, and does it
carry only members the contract knows. The register route runs the
whole ladder in one call, because the kernel's bind helper already
owns the first two steps and json/v2 options ride through as the
third:

#listing("go/api/internal/user/handlers.go", first: 49, last: 73, caption: [strict bind, rule validation, then the store, in that order])

RejectUnknownMembers is the strictness that pays rent. A client that
sends a pet member against a contract with no pet gets a 400, not a
silently ignored field, so a typo'd member name surfaces at the
border instead of corrupting data six layers in. The typed struct
makes the accepted set explicit in its tags, which is why the unknown
member failure belongs to the decode step rather than validation.

The order matters for the client's sake: the 415 fires before a body
byte is read, the 400 at parse time, and only then does validation
answer 422 with one detail per broken rule. A client fixing its
request learns everything wrong with it in one round trip, and
nothing downstream, hashing, ids, the store, runs on input that
already failed.

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

Validation rules come from the contract, not from a library: passwords
at least 12 characters and at most 128, one email shape, display
names 1 to 64 characters. Stating them as plain code keeps every
number greppable and every message owned. The function returns one
detail per violated rule rather than failing on the first, so the 422
body's details array tells the whole story:

#listing("go/api/internal/user/validate.go", first: 23, last: 46, caption: [one detail per broken rule, in field order])

Three classes of rule run here. Presence rules catch missing members.
Shape rules catch an email that parses as nothing, where the standard
library's address parser plus a dotted-domain check approximates the
real grammar without rejecting addresses people actually hold. Range
rules catch lengths. The bounds live in named constants next to the
rules, so the handler, the tests, and this chapter quote one set of
numbers.

The 422 and the 409 are different animals and the boundary is worth
stating. A rule violation is about the request alone, checkable
without touching state, so it is 422 validation. The email conflict
is about the store's current contents, so it is 409 conflict, and it
surfaces only after validation passed and the create call answered
its conflict error. Same request shape, two different truths.

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

== PATCH merge semantics

RFC 7386 merge-patch gives updates three-way semantics a typed struct
cannot express: an absent member leaves the field alone, null deletes
it, a value replaces it. So the patch decodes into a member map, not a
struct, and the handler walks the members in sorted order so details
are deterministic:

#listing("go/api/internal/user/handlers.go", first: 188, last: 211, caption: [the member walk: immutable members refuse, null on the display name too, the rest validate])

The contract makes one member writable, the display name, and the
walk shows the full policy in one switch. A null on it answers 422,
because deleting the display name would leave the record invalid, so
the delete semantics run and the validation rules answer. The
immutable members, id, email, created_at, version, roles, refuse the
moment they appear, null or not: patching them is not a validation
typo, it is an attempt to write a field the contract closed. Unknown
members refuse too, the same strictness the typed register decode
enforced with an option, enforced here by the member walk because a
map cannot carry that option.

After the walk, the precondition and the write run in order. The
client's If-Match must equal the etag of the current body, else 412,
and the update itself carries the expected version into the store so
a write that lost a race answers 412 as well rather than silently
clobbering. The no-op patch, an empty object, is legal and answers
200 with the current representation, nothing bumped.

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
costs what a table scan costs. And offsets are positions in a moving
file: one registration between requests and a row appears twice or
vanishes. Keyset pagination fixes both by remembering where it stopped
rather than counting from the front. The order is the pair
(created_at, id), the cursor encodes the last row's position, and the
next page is everything strictly after it:

#listing("go/api/internal/user/pagination.go", first: 28, last: 51, caption: [the cursor: created_at milliseconds plus the id tiebreaker, base64url unpadded])

The payload is deliberately tiny, two members, because the cursor is a
position, not a page number. Time is milliseconds since the epoch, the
id breaks ties when two users share a creation millisecond, and uuid
v7 ids sort by their own embedded time, so the composite order is
total. The encoding is base64url without padding: opaque to clients,
trivially decodable in a test, and the frozen vectors carry its exact
bytes. A cursor the service never issued is garbage, not a missing
page, so decode failures answer 422, and the limit must be an integer
in 1..100, 422 otherwise, with a default of 20.

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
chapter 18 table, so the resource layer states outcomes and the table
states statuses. The get handler is the whole ladder in one screen:
401 without an actor, 404 for an unknown id, 403 for a stranger
touching someone else's record, then the etag work:

#listing("go/api/internal/user/handlers.go", first: 84, last: 100, caption: [the failure ladder before any body is written])

After the ladder comes the one status that is not a failure, 304. If
the client's If-None-Match equals the computed etag, the body it
already holds is current, and the service answers the header and
nothing else:

#snippet(
  "etag := ETagBody(body)\n"
  + "if r.Header.Get(\"If-None-Match\") == etag {\n"
  + "\tw.Header().Set(\"ETag\", etag)\n"
  + "\tw.WriteHeader(http.StatusNotModified)\n"
  + "\treturn nil\n"
  + "}\n"
  + "w.Header().Set(\"ETag\", etag)\n"
  + "writeBody(w, http.StatusOK, body)",
  lang: "go",
)

The order inside the ladder is a policy choice this chapter owns: the
404 answers before the 403, so an unknown id and a stranger's id are
distinguishable. APIs that prefer to hide existence answer 404 for
both, and the chapter 22 audit walks that tradeoff explicitly. What
the contract forbids is a third path: no route here invents a status,
a message family, or an envelope shape, because every failure goes
through the one Fail call the kernel renders.

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
truth, and the tests read them as data: ids, timestamps, expected
etag strings, expected cursor bytes all come from the JSON files, so a
test never re-derives a constant the contract already froze. The walk
test shows the shape, seed three users at the vector's offsets, ask
for a page as a non-admin, and demand the exact next cursor:

#listing("go/api/internal/user/user_test.go", first: 474, last: 491, caption: [the vector walk: cursor bytes exact, items exact])

Exactness is the point. The etag assertion proves the body bytes byte
for byte, because the etag is the sha256 of those bytes, and the
cursor assertion proves the encoding down to the missing padding. The
harness around it injects everything time-dependent: a fake clock
advanced by hand, an id source that hands out the vector's uuids, and
a fake hasher standing in for the argon2 the authn chapter brings.
Nothing sleeps, nothing dials, every response comes out of a
recorder.

The same discipline covers the rest of the slice: register 201 and
409, the 422 details array, unknown and immutable patch members, the
stale If-Match 412, the 25-user default-limit walk, and the ownership
grid. When a vector changes the code is wrong; when the code changes
an output byte a vector fails. Drift has nowhere to hide.

#diagram([a golden test: the vector file drives the fixture and judges the recorder], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector json], [ids, offsets,], [frozen bytes], luma(235))
  stage(6.0, [fixture], [fake clock, ids,], [fake hasher], luma(235))
  stage(11.4, [request], [recorder,], [no socket], luma(235))
  stage(16.8, [assert], [etag, cursor,], [status, body], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [drift means the code is wrong, never the vector], size: 6pt)
})

sources: RFC 7386, JSON Merge Patch, and RFC 9110, HTTP Semantics
sections 8.8.3 and 13.1.1 on etags and conditional requests, both at
rfc-editor.org; pkg.go.dev/encoding/json/v2 for RejectUnknownMembers
and omitzero in go 1.27; the keyset-versus-offset argument follows
use-the-index-luke.com on offset paging. Accessed 2026-09-25.
Verified by `go/api/internal/user` tests under `go test` and
`go vet`, race detector on.
