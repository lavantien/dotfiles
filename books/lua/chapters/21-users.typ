#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the user resource

The service's first real resource is the user: a record with an id, an
email, a display name, roles, a creation time, and a version. This
chapter builds the resource layer on the chapter 19 substrate: the
record and its two projections, validation from first principles,
merge-patch semantics, keyset pagination, the in-memory store the
store chapter later swaps for sqlite behind the same verbs, and the
golden vector replay that pins all of it against the frozen bytes.

== the record and its etag

A lua table is the record, and the wire form is the same table walked
in a fixed member order, because a lua table's string keys hash into
no order at all. Two order lists name the members, and the stored
password hash appears in neither, which is the lua answer to the go
lane's dash tag: a field that no order list names never serializes,
and there is no second record type to drift. The etag is not stored
anywhere, it is computed, the sha256 hex of the exact body bytes the
codec produced, quoted:

#listing("lua/service/users.lua", first: 141, last: 145, caption: [the strong etag, a function of the body bytes])

Because the etag is a function of the body, the two can never
disagree, and a client that saves the etag has saved the body's
fingerprint. The handler marshals once, hashes those exact bytes, and
writes those same bytes, so the etag on the wire always describes the
body on the wire. Creation time is stored as unix seconds and rendered
at the edge by `os.date` with the bang prefix, the utc form with no
locale and no zone arithmetic, one format string and nothing else. The
conditional read answers before any body work repeats: an
If-None-Match that equals the computed etag gets the header and an
empty 304, which is the whole point of having saved the fingerprint.

#diagram([the record against its wire members, one field in no order list], length: 13pt, {
  let row(y, field, member, dimmed) = {
    cdraw.content((4.6, y), field, size: 6pt)
    cdraw.content((13.6, y), member, size: 6pt)
    if dimmed {
      cdraw.line((2.6, y - 0.35), (7.2, y - 0.35), stroke: luma(140))
      cdraw.line((11.0, y - 0.35), (16.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.6, 8.6), [table field], size: 6.5pt)
  cdraw.content((13.6, 8.6), [wire member], size: 6.5pt)
  row(7.5, [id], [#"id"], false)
  row(6.4, [email], [#"email"], false)
  row(5.3, [display_name], [#"display_name"], false)
  row(4.2, [roles], [#"roles"], false)
  row(3.1, [created_at], [#"created_at"], false)
  row(2.0, [version], [#"version"], false)
  row(0.9, [password_hash], [in no order list], true)
  cdraw.content((11.5, -0.4), [marshal once, hash those bytes, write those bytes], size: 6pt)
})

== validation from first principles

Validation rules come from the contract, not from a library, and lua's
stdlib needs no help stating them: passwords 12 to 128 bytes, display
names 1 to 64, one email shape with the 254 ceiling folded in. The
bounds live in named constants at the top of the module so the
handlers, the tests, and this chapter quote one set of numbers. The
email check is a handful of plain finds over bytes:

#listing("lua/service/users.lua", first: 41, last: 55, caption: [one email shape, the 254 cap folded in])

The folding is a contract of details, not of behavior: an overlong
address answers the same shape detail a missing dot answers, because
the ceiling is part of what a valid address is, never a third tier of
mistake. Emptiness is its own tier. A missing email and a malformed
email are different failures, `email is required` against `email is
not a valid address`, and the same split runs for the password and
the display name, so a 422 details array tells the whole story of
one request in field order. Length is bytes, the `#` operator, so a
multi-byte name counts its utf-8 bytes exactly as the ceilings mean.
The normalize step trims and lower-cases before any store contact.

#diagram([the two tiers of wrong, one details array per request], length: 13pt, {
  let cell(x0, x1, title, l1, l2) = {
    cdraw.rect((x0, 5.4), (x1, 8.1), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 7.4), title, size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, 6.5), l1, size: 6pt)
    cdraw.content(((x0 + x1) / 2, 5.7), l2, size: 6pt)
  }
  cell(0.8, 7.2, [absent], [email is required,], [password is required])
  cell(8.2, 14.6, [present but wrong], [not a valid address,], [254 cap folded in])
  cell(15.6, 22.0, [range], [password 12 to 128,], [name 1 to 64])
  cdraw.content((11.4, 4.3), [one detail per broken rule, in field order], size: 6pt)
  cdraw.content((11.4, 3.4), [no truncate and accept anywhere], size: 6pt)
})

== merge patch semantics

RFC 7386 merge-patch gives an update three-way semantics: an absent
member leaves the field alone, a null deletes it, a value replaces it.
A lua table cannot hold absent and null apart, so the distinction
cannot live in the decoded table, it lives in the adapter. The codec
hands back an ordered object with a null sentinel, and
`patch_members` walks the codec's own order list into triples, key,
value, and the null flag, before any rule runs. The walk itself sorts
by member name so the details array is deterministic no matter how the
body ordered its members:

#listing("lua/service/users.lua", first: 117, last: 137, caption: [the member walk: null deletes, immutables refuse on presence])

The contract makes one member writable, the display name, and the walk
shows the whole policy in one branch chain. A null on it answers 422,
because deleting the display name would leave the record invalid, so
the delete semantics run and the range rules answer. The immutable
members, id, email, created_at, version, roles, refuse the moment
they appear, null or not: patching one is not a typo, it is an attempt
to write a field the contract closed. Unknown members refuse too, the
same strictness the register bind enforced with its accepted-member
set, enforced here by the walk because a member map cannot carry a
set. After the walk the precondition runs, the client's If-Match against
the etag of the current body, else 412, and the store's update carries
the expected version so a lost race answers 412 as well. The empty
patch is legal and answers 200 with the current representation.

#diagram([absent, null, value: the three-way walk before any write], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [decode], [ordered object,], [null sentinel], luma(235))
  stage(6.0, [adapt], [key value is_null,], [sorted by key], luma(235))
  stage(11.4, [walk], [null deletes,], [immutable 422], luma(235))
  stage(16.8, [precondition], [If-Match equals,], [else 412], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [absent members never reached the walk at all], size: 6pt)
  cdraw.content((11.5, 3.5), [a lua table cannot hold absent and null apart, the adapter can], size: 6pt)
})

== keyset cursors

Offset pagination asks for row 86041 onward and fails twice: the
store walks and discards every skipped row, and offsets are positions
in a moving file, so one registration between requests makes a row
appear twice or vanish. Keyset pagination remembers where it stopped.
The order is the pair, creation time then id as the tiebreaker, and
uuid v7 ids sort by their own embedded time, so the composite order is
total. The cursor is the position encoded, base64url without padding
over a two-member envelope fixed by the frozen vectors, rendered with
one `string.format` call rather than through the json codec, because
the shape is frozen and lives entirely in this file, the same ruling
the c lane made for its cursor. The decode is strict in layers, the
b64url codec first with its own refusals, the padding character, the
wrong alphabet, impossible lengths, then the exact envelope shape,
then the id's uuid shape:

#listing("lua/service/users.lua", first: 167, last: 177, caption: [strict decode: any miss is garbage, never a missing page])

The milliseconds parse as integer arithmetic, multiply by ten and
add, which lua's 64-bit integers hold exactly where a float would
blur at the thirteenth digit. A cursor the service never issued is
garbage, so every miss answers 422, never a 404, and the limit must
be a whole number in 1..100 with 20 the default. One unit seam is
stated where it lives: the cursor carries milliseconds, the store
keys seconds, and the handler divides once at the boundary.

#diagram([offset walks the prefix, keyset jumps to the remembered position], length: 13pt, {
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
  cdraw.content((11.5, 1.4), [flat cost, no drift, the id breaks same-second ties], size: 6pt)
})

== the store as three tables

The in-memory store is three tables behind one seam: records keyed by
id, ids keyed by normalized email for the login lookup, and the ids in
keyset order so a list page walks a sorted array and reads the live
records through the map, never a stale copy. Every read returns a
copy, field by field and roles array by roles array, so a handler that
mutates what it read cannot corrupt the store, the value semantics
the go lane got from its structs, stated here as a function. There is
no lock anywhere, and that is not an omission: the vm runs one
instruction stream, a table cannot be mid-mutation under a second
reader, and the honest statement is that the single thread is the
lock. Errors are strings, `not_found`, `conflict`, `version`,
`last_admin`, mapped to the envelope by the handlers, so the store
speaks outcomes and never statuses:

#listing("lua/service/users.lua", first: 297, last: 317, caption: [create: bootstrap roles, then the binary-search insert])

The insert position comes from a binary search over the order array,
so the array stays sorted across inserts. The bootstrap rule lives
here: the first registration in an empty store holds both roles,
admin and user, every later one holds user alone. The store chapter
swaps this object for sqlite over the ffi behind the same verbs, and
the contract it must match row for row is this one's behavior.

#diagram([three tables, one seam: by id, by email, and the ordered ids], length: 13pt, {
  cdraw.rect((0.8, 5.2), (7.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 7.6), [by_id], size: 6.5pt)
  cdraw.content((3.9, 6.6), [id to record,], size: 6pt)
  cdraw.content((3.9, 5.8), [the live rows], size: 6pt)
  cdraw.rect((8.2, 5.2), (14.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 7.6), [by_email], size: 6.5pt)
  cdraw.content((11.3, 6.6), [email to id,], size: 6pt)
  cdraw.content((11.3, 5.8), [the login lookup], size: 6pt)
  cdraw.rect((15.6, 5.2), (22.0, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((18.8, 7.6), [order], size: 6.5pt)
  cdraw.content((18.8, 6.6), [ids in keyset order,], size: 6pt)
  cdraw.content((18.8, 5.8), [binary-search insert], size: 6pt)
  cdraw.line((7.2, 6.7), (8.0, 6.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.6, 6.7), (15.4, 6.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.9), [reads return copies, errors are strings, no lock exists], size: 6pt)
  cdraw.content((11.5, 3.0), [the sqlite store must match this row for row], size: 6pt)
})

== projections and the admin list

Field-level authorization lives in one function, the projection. An
admin reader gets the full order, everyone else gets the public four,
id, display name, created_at, version, and no handler decides what to
hide because the decision is not in any handler:

#listing("lua/service/users.lua", first: 197, last: 210, caption: [the projection: one function, two orders])

The admin list is where this earns its keep. List rows for an admin
are full records with email and roles, the same representation the
register route answers, and that is a lesson a sibling lane paid for:
its admin list once hid email behind the public projection, a
field-level bug that survived every route-level test because the
route was allowed and only the row was wrong. The frozen vector walks
the public side instead, a non-admin reader listing three users and
seeing exactly the four members, and the replay asserts both
projections' exact bytes. The roles array rides the record in sorted
order, admin before user, so the wire order is the store order and
grant answers sort before they persist.

#diagram([two orders out of one record, the reader decides nothing], length: 13pt, {
  cdraw.rect((0.8, 4.8), (7.6, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.2, 7.8), [admin reader], size: 6.5pt)
  cdraw.content((4.2, 6.9), [id email display_name], size: 6pt)
  cdraw.content((4.2, 6.0), [roles created_at version], size: 6pt)
  cdraw.content((4.2, 5.3), [six members], size: 6pt)
  cdraw.rect((13.4, 4.8), (20.2, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((16.8, 7.8), [anyone else], size: 6.5pt)
  cdraw.content((16.8, 6.9), [id display_name], size: 6pt)
  cdraw.content((16.8, 6.0), [created_at version], size: 6pt)
  cdraw.content((16.8, 5.3), [four members], size: 6pt)
  cdraw.content((11.5, 3.6), [email and roles are admin-only data, the row not the route], size: 6pt)
  cdraw.content((11.5, 2.7), [the admin list emits full records, the sibling lesson], size: 6pt)
})

== golden vector replay

The frozen vectors under `contract/testdata` are the fixture source of
truth, and the replay reads them as expectations, never as hints. One
fact the fixture had to face: the vectors are scenarios, not one
story. Decoding every bearer's sid shows vectors 09 through 12 acting
with the very session family vector 08 revokes, so the replay runs
four fresh states, the happy walk, the login limits, the reuse attack,
and the roles chain, each seeded by its own setup the way each
vector's setup field describes. Every time-dependent byte comes from
an injected clock ticked to the vector's offset, an id queue loaded
with the vector's own uuids in pop order, and a rand queue carrying
the pinned refresh bytes:

#listing("lua/service/tests/vectors_test.lua", first: 189, last: 211, caption: [the etag pair: 200 with the body, 304 with only the header])

Exactness is the point. The etag assertion proves the body bytes byte
for byte, because the etag is the sha256 of those bytes, the cursor
assertion proves the encoding down to the missing padding, and the
rate header arithmetic proves the bucket's refill to the second. The
render point sits between dispatch and the limit layer, so a
handler's fail value becomes the envelope response the rate headers
stamp. When the vectors change the code is wrong.

#diagram([the replay: frozen bytes in, frozen bytes judged], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector json], [ids, offsets,], [frozen bytes], luma(235))
  stage(6.0, [injected], [clock, ids, rand,], [queues in pop order], luma(235))
  stage(11.4, [the stack], [identity limit idem,], [dispatch and render], luma(235))
  stage(16.8, [assert], [body, etag, cursor,], [status, headers], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [four scenarios, fresh state each, no shared story], size: 6pt)
  cdraw.content((11.5, 3.5), [drift means the code is wrong, never the vector], size: 6pt)
})

sources: RFC 7386, JSON Merge Patch, and RFC 9110 sections 8.8.3 and
13.1.1 on etags and conditional requests, both at rfc-editor.org.
lua.org manual 5.5 sections 6.4 for string.find's plain mode,
string.format, and gsub, 6.6 for table.insert, table.sort, and
table.concat, and 6.9 for os.date's utc form, all verified against
the tools/lua55 pin. The structural mirror is books/go/api/internal/
user, and the cursor's frozen-envelope ruling follows books/
c-os-cloud/api/src/users_cursor.c. Accessed 2026-09-27. Verified by
the service suite through `make verify-lua`: users 18 checks, the
family replay 13, all green on the pinned runner.
