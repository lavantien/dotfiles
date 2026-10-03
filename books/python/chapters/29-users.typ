#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the user resource

The service's first real resource is the user: a record with an id,
an email, a display name, roles, a creation time, and a version. The
chapter builds the resource layer on the chapter 27 kernel: the
representation and its two projections, a strict decode over the
stdlib `json` module, validation from first principles, merge-patch
updates, keyset pagination, the status contract, and the golden
handler tests that pin all of it against the frozen vectors, all in
the `pyapi/users/` package.

== the representation

A resource is three things at once: the bytes on the wire, the fields
each reader may see, and the strong etag that names one exact version
of the body. The stored record is one frozen dataclass and the wire
shape is a dict in a fixed member order, the struct-with-tags
discipline stated in python: dict literal order is wire order, and
the frozen vectors are byte-authoritative:

#listing("python/api/pyapi/users/record.py", first: 60, last: 82, caption: [the record, its wire members, and the public projection])

The projection is where field-level authorization lives: email and
roles are admin-only data, the list handler calls one method and
marshals whatever comes back, and a rule enforced in one function
cannot be forgotten in a second handler. The version member bumps
once per successful write. The password hash rides the dataclass, and
because `to_wire` never mentions it, no marshal can leak it.

The etag is not stored anywhere, it is computed: marshal the
representation once, sha256 those exact bytes, quote the hex. The
etag is a function of the body, so the two can never disagree, and
the kernel's one success writer keeps it that way: handlers hash
`response.body`, the bytes about to go on the wire, never a second
marshal that could drift:

#snippet(
  "def etag_body(body: bytes) -> str:\n"
  + "    return f'\"{hashlib.sha256(body).hexdigest()}\"'",
  lang: "python",
)

#diagram([the record fields against the wire members, one field kept off the wire], length: 13pt, {
  let row(y, py, json, dimmed) = {
    cdraw.content((4.6, y), py, size: 6pt)
    cdraw.content((13.6, y), json, size: 6pt)
    if dimmed {
      cdraw.line((2.6, y - 0.35), (7.2, y - 0.35), stroke: luma(140))
      cdraw.line((11.0, y - 0.35), (16.0, y - 0.35), stroke: luma(140))
    }
  }
  cdraw.content((4.6, 8.6), [python field], size: 6.5pt)
  cdraw.content((13.6, 8.6), [json member], size: 6.5pt)
  row(7.5, [id: str], [#"id"], false)
  row(6.4, [email: str], [#"email"], false)
  row(5.3, [display_name: str], [#"display_name"], false)
  row(4.2, [roles: tuple], [#"roles"], false)
  row(3.1, [created_at: datetime], [#"created_at"], false)
  row(2.0, [version: int], [#"version"], false)
  row(0.9, [password_hash: str], [never sent], true)
})

== decoding with strictness

Input is hostile until proven otherwise, and the kernel's decode
ladder answers three questions in a fixed order: is the media type
json at all, is the body parseable inside the 1 MiB cap, and does it
carry only members the contract knows. The kernel's `read_json` owns
the first two, answering 415 and 413 and 400. The third belongs to
this package, because the stdlib `json.loads` answers any shape at
all, so strictness is a walk over the parsed object:

#listing("python/api/pyapi/users/routes.py", first: 74, last: 94, caption: [unknown members refuse with 400, every kept member a string])

Rejecting unknown members is the strictness that pays rent. A client
that sends a pet member against a contract with no pet gets a 400,
not a silently ignored field, so a typo'd member name surfaces at the
border instead of corrupting data six layers in. The accepted set is
the name tuple the caller passes, decode's business and not
validation's. A null member reads as the empty string, the zero value
the go lane's typed decode produced, so a null reaches validation and
answers 422 with the presence rule's own words, while a number where
a string belongs answers 400 at the border.

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
  rung(1.9, [known members, strings?], [400 invalid_json])
  rung(0.0, [field rules hold?], [422, else 201 or 409])
})

== validation from first principles

Validation rules come from the contract, not from a library:
passwords at least 12 characters and at most 128, one email shape,
display names 1 to 64 characters. Stating them as plain code keeps
every number greppable and every message owned. The function returns
one detail per violated rule rather than failing on the first, so the
422 body's details array tells the whole story:

#listing("python/api/pyapi/users/validate.py", first: 17, last: 36, caption: [one detail per broken rule, in field order, off the named constants])

Three classes of rule run here. Presence rules catch missing members.
Shape rules catch an email that parses as nothing, where the standard
library's `email.utils.parseaddr` plus a one-at-sign and dotted-domain
check approximates the real grammar without rejecting addresses
people actually hold. Range rules catch lengths, with the bounds in
named constants the detail strings interpolate rather than restate,
so a message can never drift from the rule it reports.

The 422 and the 409 are different animals. A rule violation is about
the request alone, checkable without touching state, so it is 422
validation. The email conflict is about the store's current contents,
so it is 409 conflict, and it surfaces only after validation passed
and the create call raised its conflict error. The normalize step
closes the last dodge: emails are lower-cased and trimmed before they
reach the store, so `Ada@Example.ORG` cannot register a second
account beside `ada@example.org`.

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

RFC 7386 merge-patch gives updates three-way semantics a typed decode
cannot express: absent leaves the field alone, null deletes it, a
value replaces it. So the patch decodes into whatever `json` produces,
a dict, and the handler walks the members in sorted order so details
are deterministic:

#listing("python/api/pyapi/users/routes.py", first: 188, last: 202, caption: [the member walk: null on the display name too, immutable members refuse, unknown members refuse])

The contract makes one member writable, the display name, and the walk
shows the full policy in one branching. A null on it answers 422,
because deleting the display name would leave the record invalid. The
immutable members, id, email, created_at, version, roles, refuse the
moment they appear, null or not: patching them is not a validation
typo, it is an attempt to write a field the contract closed. Unknown
members refuse too, here by the walk because a parsed dict cannot
carry the register route's name tuple.

After the walk, the precondition and the write run in order. The
client's If-Match must equal the current body's etag, else 412, and
the update carries the expected version into the store so a write
that lost a race answers 412 rather than silently clobbering. The
no-op patch answers 200 with the current representation, nothing
bumped.

#diagram([a patch request walks the members, then the precondition, then the store], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [decode], [member dict,], [415 413 400], luma(235))
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
vanishes. Keyset pagination fixes both by remembering where it
stopped. The order is the pair (created_at, id), the cursor encodes
the last row's position, and the next page is everything strictly
after it:

#listing("python/api/pyapi/users/pagination.py", first: 35, last: 52, caption: [the position, the composite order, and the base64url unpadded encoding])

The payload is deliberately tiny, two members, because the cursor is a
position, not a page number. Time is milliseconds since the epoch,
computed with pure integer arithmetic off a `datetime` because float
timestamps drift at this magnitude. The id breaks ties when two users
share a creation millisecond, and uuid v7 ids sort by their own
embedded time, so the composite order is total. The encoding is
`base64.urlsafe_b64encode` with the padding stripped: opaque to
clients, trivially decodable in a test, and the frozen vectors carry
its exact bytes. A cursor the service never issued is garbage, not a
missing page, so decode failures answer 422, and the limit must be an
integer in 1..100 with a default of 20. The decode is strict about
the alphabet, the member set, and the member types, because anything
looser would let a client smuggle a hand-built position past the
contract.

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

== the status contract

Every failure this layer can produce already has a code in the
chapter 27 table, so this layer states outcomes and the table states
statuses. The get handler is the whole ladder in one screen: 401
without an actor, 404 for an unknown id, 403 for a stranger touching
someone else's record, then the etag work:

#listing("python/api/pyapi/users/routes.py", first: 132, last: 143, caption: [the failure ladder before any body is written, 304 after it])

After the ladder comes the one status that is not a failure, 304. If
the client's If-None-Match equals the computed etag, the body it
already holds is current, and the service answers the header and
nothing else. The order inside the ladder is a policy choice this
chapter owns: the 404 answers before the 403, so an unknown id and a
stranger's id are distinguishable, and APIs that prefer to hide
existence answer 404 for both, a tradeoff the authorization chapter
walks. What the contract forbids is a third path: every failure
raises one kernel `APIError` the failure writer renders, exactly one
writer. The owner check is two lines, `user_id` equal or admin,
shared by every object verb.

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
truth, and the tests read them as data: ids, timestamps, etags, and
cursor bytes come from the json files, never re-derived by the test:

#listing("python/api/tests/test_users_routes.py", first: 104, last: 114, caption: [the vector drives the fixture and judges the response, bytes exact])

Exactness is the point. The etag assertion proves the body bytes byte
for byte, and the response body is compared against the vector's
compact form directly. The harness injects everything
time-dependent: a clock moved by hand between requests, an id source
with the vector's uuids, a fake hash for the authn chapter's pbkdf2,
and the actor installed into the contextvar the identity middleware
will own. Nothing sleeps, nothing dials.

The same discipline covers the rest of the slice: register 201 and
409, the 422 details array, unknown and immutable patch members, the
stale If-Match 412, the walk's exact cursors, and the ownership grid.
A seeded `random.Random` property loop walks shuffled insertions at
page sizes 1, 3, and 100 and asserts the invariant: the pages cover
every user exactly once, in (created_at, id) order, whatever order
the rows arrived in, and when a vector changes the code is wrong.

#diagram([a golden test: the vector file drives the fixture and judges the dispatch], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 4.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.3, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.3, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 5.9), l2, size: 6pt)
  }
  stage(0.6, [vector json], [ids, offsets,], [frozen bytes], luma(235))
  stage(6.0, [fixture], [moved clock, ids,], [fake hash, actor], luma(235))
  stage(11.4, [dispatch], [plain values,], [no socket], luma(235))
  stage(16.8, [assert], [etag, cursor,], [status, body], luma(222))
  cdraw.line((5.4, 6.9), (5.9, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 6.9), (11.3, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.2, 6.9), (16.7, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [drift means the code is wrong, never the vector], size: 6pt)
})

sources: docs.python.org/3/library/json.html for dumps separators
and loads, docs.python.org/3/library/email.utils.html for parseaddr,
docs.python.org/3/library/base64.html for urlsafe_b64encode and
b64decode validate, and docs.python.org/3/library/hashlib.html for
sha256, all accessed 2026-09-27 against the pinned cpython 3.14.7.
RFC 7386 and RFC 9110 sections 8.8.3 and 13.1.1 at rfc-editor.org,
the offset argument from use-the-index-luke.com. Verified by
`tests/test_users.py` and `tests/test_users_routes.py` under
`make verify-pyapi`, 39 tests green, ruff clean at 88 columns.
