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
chapter builds the resource's decision core in `c-os-cloud/api/src` as
plain functions over plain data: the record's bounds and its two
projections, strict decode of everything a client hands back, field
validation stated from the contract rather than imported, merge-patch
semantics for updates, keyset pagination for lists, the failure ladder
that orders refusals, and the golden vector tests that pin the cursor
bytes exactly. The kernel owns the wire, the one json codec and the
one error writer, so everything here tests without a socket.

== the record and its projection

A resource is three things at once: the stored record, the bytes each
reader may see, and the strong etag that names one exact body. The
stored record carries the password hash, which never reaches the wire.
The full representation carries id, email, display name, roles,
creation time, and version. The public projection carries four of
those six: email and roles are admin-only data, and a reader who is
not the owner and not an admin never learns an account exists beyond
its id and name. One function will choose between the two at wiring
time, which is the whole trick: a rule enforced in one place cannot be
forgotten in a second handler.

The bounds and the role set live in the shared header next to the
functions that enforce them, one set of numbers for the handlers, the
tests, and this chapter:

#listing("c-os-cloud/api/api.h", first: 123, last: 128, caption: [the field bounds and the closed role set, the contract's numbers in one place])

The version member is the quiet third actor. It bumps exactly once per
successful write, and the store's guarded update compares it before
committing, which is what turns a stale If-Match into a clean 412
instead of a silent clobber. The etag is not stored anywhere, it is
computed: marshal the representation, hash those exact bytes, quote
the hex. Because the etag is a function of the body the two can never
disagree, and the digest itself is the hand-rolled sha-256 of the next
chapter, introduced here as just a function from bytes to 32 bytes.

#diagram([one record, two projections, the hash member never on the wire], length: 13pt, {
  let row(y, member, dimmed) = {
    cdraw.content((4.0, y), member, size: 6pt)
    if dimmed {
      cdraw.line((1.6, y - 0.35), (9.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.0, 8.7), [the stored record], size: 6.5pt)
  row(7.6, [id, a uuid v7], false)
  row(6.5, [email], false)
  row(5.4, [display name], false)
  row(4.3, [roles], false)
  row(3.2, [created at, version], false)
  row(2.1, [password hash], true)
  cdraw.line((10.2, 5.0), (12.6, 5.0), stroke: luma(100), mark: (end: ">>"))
  pane(13.0, 23.4, 7.6, [the public projection], [id], [display name], [created at, version])
  cdraw.content((18.2, 2.2), [email and roles ride only for an admin], size: 6pt)
  cdraw.content((4.0, 0.7), [the etag is sha256 over the exact body bytes, computed, never stored], size: 6pt)
})

== strict decode

Input is hostile until proven otherwise. The kernel's decode ladder
already answers the media type question, the 1 MiB cap, and the parse
itself, all through the one codec. What this family adds is shape
strictness: the closed member set for register bodies, enforced at
binding, and the exact-shape parse for everything a client hands back
that this service issued. The cursor is the teaching example. A cursor
is either exactly the bytes this service encoded or it is garbage, and
garbage answers 422, never 404, because a mangled cursor is not a
missing page, it is a broken request:

#listing("c-os-cloud/api/src/users_cursor.c", first: 103, last: 114, caption: [the shape check: 36 characters, hex and dashes in their fixed lanes])

The decoder around it accepts one spelling, `raw(member)` then digits
then the id then the close brace, with the total length checked by
arithmetic before any byte is trusted. A timestamp of zero refuses,
overlong digit runs refuse, a stray character anywhere refuses. The
same discipline governs the patch member set in the walk below: a
member the contract does not name refuses the moment it appears. The
payoff is symmetrical with the typed bind: a typo in a member name
surfaces at the border as a 400 or a 422, never as a silently ignored
field corrupting state ten layers in.

#diagram([the decode ladder, each rung rejects a class of bad input], length: 13pt, {
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
  rung(1.9, [shape the contract knows?], [400 or 422])
  cdraw.content((11.5, 0.3), [everything left reaches validation], size: 6pt)
})

== validation from first principles

Validation rules come from the contract, not from a library: passwords
at least 12 and at most 128 characters, one email shape, display names
1 to 64 characters. Stating them as plain code keeps every number
greppable and every message owned by this file. The walk returns one
detail per violated rule in field order rather than failing on the
first, so the 422 body tells the client everything wrong in one round
trip:

#listing("c-os-cloud/api/src/users_validate.c", first: 63, last: 85, caption: [one detail per broken rule, in field order, presence before shape before range])

Three classes of rule run in that walk. Presence rules catch missing
members, and an empty string is a missing member because json has no
way to omit what it sent. Shape rules catch an email that parses as
nothing, one at sign, a nonempty local part, a dotted domain, and no
whitespace anywhere, which approximates the real grammar without
rejecting the addresses people actually hold. The 254 character cap
folds into that same shape rule rather than standing as its own range
detail, the address grammar and its width one rule, the go lane's own
fold. Range rules catch lengths, the password and the display name.
Email normalization is the fourth piece: the store keys on
the trimmed and lower-cased form, so a registration cannot dodge a
conflict by varying case.

The 422 and the 409 are different animals and the boundary is worth
stating. A rule violation is about the request alone, checkable
without touching state, so it is 422 validation. The email conflict is
about the store's current contents, so it is 409 conflict, and it
surfaces only after validation passed and the create call answered its
conflict error. Same request shape, two different truths.

#diagram([three rule classes, one details array, two truths for one request], length: 13pt, {
  let cell(x0, x1, title, l1, l2) = {
    cdraw.rect((x0, 5.4), (x1, 8.1), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 7.4), title, size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, 6.5), l1, size: 6pt)
    cdraw.content(((x0 + x1) / 2, 5.7), l2, size: 6pt)
  }
  cell(0.8, 7.2, [presence], [email required,], [password required])
  cell(8.2, 14.6, [shape], [one at sign,], [dotted domain])
  cell(15.6, 22.0, [range], [password 12 to 128,], [name 1 to 64])
  cdraw.content((7.5, 4.2), [rule violations answer 422 with the details array], size: 6pt)
  cdraw.content((7.5, 3.1), [a taken email answers 409, a fact about the store], size: 6pt)
})

== merge patch semantics

RFC 7386 merge-patch gives updates three-way semantics a typed struct
cannot express: an absent member leaves the field alone, null deletes
it, a value replaces it. So the patch decodes into a member list, not
a struct, and this walk consumes it in sorted order so details are
deterministic. The contract makes one member writable, the display
name, and the walk states the full policy in one switch:

#listing("c-os-cloud/api/src/users_patch.c", first: 32, last: 55, caption: [the member walk: null on the name refuses, the immutable members refuse by name, the rest validate])

A null on the display name answers 422, because deleting it would
leave the record invalid, so the delete semantics run and the field
rules answer. The immutable members, id, email, creation time,
version, roles, refuse the moment they appear, null or not: patching
them is not a validation typo, it is an attempt to write a field the
contract closed. Unknown members refuse the same way the typed bind
would. The result carries the resulting name, a changed flag computed
against the current value so a no-op patch never bumps a version, and
a fixed table of rendered reasons, at most 16 rows of 64 characters,
no allocation anywhere in the walk. After the walk the precondition
runs at wiring: the If-Match must equal the etag of the current body
or the answer is 412, and the store's guarded update compares versions
under its own lock so a lost race answers 412 as well.

#diagram([a patch walks the members, then the precondition, then the store], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [decode], [member list,], [sorted], luma(235))
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

Offset pagination asks for row 86041 onward and fails twice. The
database still walks and discards every skipped row, so page 4000 costs
what a scan costs. And offsets are positions in a moving file: one
registration between requests and a row appears twice or vanishes.
Keyset pagination fixes both by remembering where it stopped rather
than counting from the front. The order is the pair, creation time
then id, the cursor encodes the last row's position, and the next page
is everything strictly after it:

#listing("c-os-cloud/api/src/users_cursor.c", first: 87, last: 101, caption: [the cursor payload, two members, base64url without padding over the exact bytes])

The payload is deliberately tiny, two members, because the cursor is a
position, not a page number. Time is milliseconds since the epoch, the
id breaks ties when two users share a creation millisecond, and uuid
v7 ids sort by their own embedded time, so the composite order is
total. The encoding is base64url without padding, the url-safe
alphabet the same codec the next chapter's jwt reuses, opaque to
clients and trivially decodable in a test. The compare the store walks
is one function, time first then id, strictly after, and the limit is
its own small window: absent means 20, digits mean 1 to 100, anything
else is a 422 with the reason in the details array.

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

== the failure ladder

Every refusal this family can produce already has a code in the
kernel's closed set, so the resource layer states outcomes and the
envelope states statuses. The ladder for one object request climbs in
a fixed order: 401 without an actor, 404 for an unknown id, 403 for a
stranger touching another account, then the etag work, 304 when the
client's If-None-Match matches, 200 with a fresh etag otherwise. Patch
adds its 412 rungs above the ladder, the missing If-Match and the
stale one, and the walk's refusals answer 422 before any of it. The
tests pin the refusal classes this core owns, one class per check:

#listing("c-os-cloud/api/tests/test_users.c", first: 202, last: 218, caption: [the refusal classes: null on the name, wrong type, immutable members null or not])

The order inside the ladder is a policy choice this chapter owns. The
404 answers before the 403, so an unknown id and a stranger's id are
distinguishable, the trade the next chapter's audit walks explicitly.
What the contract forbids is a third path: no route here invents a
status, a message family, or an envelope shape, because every failure
renders through the one writer the kernel owns. The register route
adds the one 409 this family can reach, the taken email, and only
after validation passed, the boundary the validation section stated.

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
  cdraw.content((11.5, 0.7), [patch adds its 422 and 412 rungs above the ladder], size: 6pt)
})

== golden vector tests

The frozen vectors under `contract/testdata` are the fixture source of
truth, and the tests read them as data: ids, timestamps, cursor bytes
all come from the files, so a test never re-derives a constant the
contract already froze. The cursor walk is the shape of the whole
discipline, one check asserts the exact 83 characters the encoder
produces for the vector's timestamp and id pair, and the frozen file
is the only place those characters live:

#listing("c-os-cloud/api/tests/test_users.c", first: 197, last: 222, caption: [the vector cursor: encode exact, round trip, refuse garbage and empty])

Exactness is the point. The etag assertion in the wiring layer proves
the body bytes byte for byte, because the etag is the sha-256 of those
bytes, and the cursor assertion proves the encoding down to the
missing padding. Everything time-dependent enters through seams, a
fake clock stepped by hand, an id source that hands out the vector's
uuids, so nothing sleeps and nothing dials. The same discipline covers
the rest of the slice: register bounds and field order, the email
shape classes, normalization, the closed role set, the limit window,
the keyset compare, and every patch refusal class. When a vector
changes the code is wrong. When the code changes an output byte a
vector fails. Drift has nowhere to hide.

#diagram([a golden test: the vector file drives the fixture and judges the result], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector json], [ids, offsets,], [frozen bytes], luma(235))
  stage(6.0, [fixture], [fake clock, ids,], [fixed salts], luma(235))
  stage(11.4, [the core], [plain calls,], [no socket], luma(235))
  stage(16.8, [assert], [cursor, details,], [status later], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [drift means the code is wrong, never the vector], size: 6pt)
})

sources: RFC 7386 for merge patch semantics and RFC 9110 sections
8.8.3 and 13.1.1 for strong etags and conditional requests, both
accessed 2026-09-27, RFC 4648 section 5 for the base64url alphabet
and its test vectors, and the frozen vectors at
`c-os-cloud/api/contract/testdata/` as the byte oracle for the cursor
and the register projections. Verified by the users family's 102
checks under the pinned clang 23 through `make verify-capi`, plus
clang-format over every file touched.
