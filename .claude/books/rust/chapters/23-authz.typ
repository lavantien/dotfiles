#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= authz and rbac

Chapter 22 answered who is calling. This chapter answers what that
caller may do, in `rustapi::authz`: roles as stored data with a grant
and revoke surface, the policy table that maps every route pattern
to one plain function, the object-level check whose absence the
industry names IDOR, the never-zero-admins guard that refuses a
demotion or a removal which would leave the table without one admin,
and the 401 versus 403 discipline that keeps the two answers from
swapping places. The go book built the same layer riding its mux's
own pattern resolution, #xref-to("go", "authz"), the java book asked
its kernel for the pattern instead, #xref-to("java", "authz"), and
this lane's kernel is this book's own chapter 19 router, whose table
cannot be queried, so the guard carries its own matcher and the
audit closes the loop from both sides. That divergence is stated
where it lives, in the table section.

== authentication versus authorization

Two questions, two layers, two failure codes. Authentication ran in
chapter 22's identity layer and installed an actor or did not.
Authorization reads that actor against the route and, on the object
routes, against the record. A caller that never proved anything has
no authorization to deny, only an authentication demand: 401 means
try again with credentials, 403 means do not bother, this identity
will never pass. The wiring makes the sequence physical, the
identity layer outside the middleware stack, the guard inside it,
and by the time a policy runs the actor question is settled, so a
policy never parses a token, checks a signature, or hashes a
password:

#diagram([the wired order: identity outside everything, guard inside the stack, handler last], length: 13pt, {
  cdraw.rect((1.0, 7.2), (22.0, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.8), [identify, installs the actor or nothing], size: 6.5pt)
  cdraw.content((11.5, 7.9), [chapter 22, answers nothing itself], size: 6pt)
  cdraw.rect((1.0, 4.0), (22.0, 6.6), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 6.0), [request id, access log, timing, recover], size: 6.5pt)
  cdraw.content((11.5, 5.1), [then the guard: verdicts land inside, timed and logged], size: 6pt)
  cdraw.rect((6.4, 1.2), (16.6, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 2.9), [router and handlers], size: 6.5pt)
  cdraw.content((11.5, 2.0), [read the actor, never a token], size: 6pt)
  cdraw.line((11.5, 6.8), (11.5, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.2, 0.6), [401 here means no actor, 403 means the wrong one], size: 6pt)
})

The 401 this chapter emits carries the rfc 9110 challenge header,
`WWW-Authenticate: Bearer`, which section 11.6.1 requires a 401 to
carry and most hand-rolled servers forget, and the two messages
stay honest to their layer, `authentication required` against
`insufficient role` and `not the owner`.

== policies as functions

A policy is one function from the request and the match it produced
to a verdict: `Ok` allows, an `ApiError` denies with its own status.
Four of them compose the whole surface, and each is short enough to
read in one breath:

#listing("rust/api/src/authz.rs", first: 39, last: 83, caption: [actor read, challenge-building 401, then the four policies: anyone, authenticated, role, owner-or-admin])

The role vocabulary is two constants, admin and user, and
deliberately flat: `has_role` is a contains check, `admin` a
shortcut for that one word. The only hierarchy in the system is the
explicit outranking rule the owner check applies, an admin passes
where an owner would, and it is spelled out at every call site
rather than implied by a rank lattice, because the day an implicit
`admin implies user` expansion hides a grant from the person
auditing the table, that one line of expansion costs more than it
ever bought. The java chapter made the same argument and this lane
keeps it.

== object-level authorization

Route rules cannot guard a route whose danger lives in the path
parameter. `GET /api/users/` followed by someone else's id is the
IDOR class, insecure direct object reference, and it survives every
route-level check because the route is the same for everyone. The
check needs the record, whether it exists at all and who owns it,
and the policy extracts the wildcard itself from the match it was
handed, so the object check lives in the table and still answers
all three questions in the right order:

#listing("rust/api/src/authz.rs", first: 69, last: 83, caption: [the object policy: 404 the unknown id first, 403 the stranger, allow owner or admin])

The store read inside the policy is the price of the 404-first
order, and it is stated rather than hidden: the handler fetches
again, one row read twice on the object route, in exchange for the
unknown id answering the same 404 a nonexistent route would. What
the order does not hide is existence from an authenticated caller:
a stranger probing ids still splits 404 from 403, and which ids are
real is exactly what that split reveals. Both siblings made the
same trade and named it, debuggability over disclosure at book
scale, and the alternative, 404 for both, is one `if` away if the
trade ever turns.

#diagram([horizontal versus vertical: two axes of privilege, two different checks], length: 13pt, {
  cdraw.content((5.4, 8.9), [same account], size: 6.5pt)
  cdraw.rect((1.4, 6.6), (9.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 7.6), [linus reads ada], size: 6pt)
  cdraw.content((5.4, 6.7), [owner check, needs the record], size: 6pt)
  cdraw.content((16.6, 8.9), [same route], size: 6.5pt)
  cdraw.rect((12.6, 6.6), (20.6, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((16.6, 7.6), [linus calls admin route], size: 6pt)
  cdraw.content((16.6, 6.7), [role check, needs only the actor], size: 6pt)
  cdraw.content((11.5, 5.4), [horizontal is IDOR, vertical is privilege escalation], size: 6pt)
  cdraw.content((11.5, 4.5), [one needs the object, one needs only the actor], size: 6pt)
  cdraw.content((11.5, 3.6), [both end in 403, never in a leaked row], size: 6pt)
})

== roles as stored data and the never-zero-admins guard

Roles are rows, not magic. The port is four verbs over user id to
role set, and the invariant that matters lives where the only verbs
that can break it run: a change whose post state would leave the
whole table without one admin is refused with nothing written, and
the refusal is the contract's 409 both siblings froze. The
demotion, a revoke of `admin`, and the removal, the whole row, are
both covered, because a deletion that empties the admin set is the
same lockout a demotion is:

#listing("rust/api/src/authz.rs", first: 159, last: 176, caption: [the roles port: two outcomes, NotFound and LastAdmin, the second the 409 lane])

#listing("rust/api/src/authz.rs", first: 237, last: 276, caption: [the guard's body: post state computed first, invariant checked against it, one mutex over the whole move])

#diagram([the grant table: one column per user, the admin row must never empty], length: 13pt, {
  cdraw.content((4.0, 8.7), [ada, first], size: 6.5pt)
  cdraw.content((11.0, 8.7), [linus], size: 6.5pt)
  cdraw.content((18.0, 8.7), [grace], size: 6.5pt)
  cdraw.rect((2.2, 6.9), (5.8, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 7.5), [admin], size: 6pt)
  cdraw.rect((9.2, 6.9), (12.8, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 7.5), [user], size: 6pt)
  cdraw.rect((16.2, 6.9), (19.8, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.0, 7.5), [user], size: 6pt)
  cdraw.line((10.0, 6.6), (11.0, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.0, 5.9), [grant admin], size: 6pt)
  cdraw.rect((9.2, 4.4), (12.8, 5.7), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 5.0), [admin], size: 6pt)
  cdraw.content((11.5, 3.4), [revoke linus now: fine, ada stands], size: 6pt)
  cdraw.content((11.5, 2.5), [revoke ada first: 409, the table would empty], size: 6pt)
  cdraw.content((11.5, 1.6), [remove ada's row: same 409, at the port], size: 6pt)
})

One rust-specific split the siblings did not have, stated here
because vector 01 forces it: the user record carries a roles member,
frozen by the register vector, so the record's member stays the
registration-time snapshot while the grants table adopted from those
records at boot is the live truth. The bridge is one function,
`table_roles`, which binds the roles port into chapter 22's
`roles_of` seam, so the identity layer reads the table at request
time and a demoted admin loses the role on the very next request,
pinned by the same bearer crossing the admin route before the
revoke and failing after it with no reissue anywhere. The removal
half of the guard has no route yet, the delete route is chapter
25's concurrency family, so it is pinned at the port, removal of
the standing admin refused, removal of anyone else returning the
row.

The first admin cannot come from the grant surface, because the
surface is itself behind the admin policy, so the bootstrap is the
adoption at wiring time: the table reads every record's roles once,
and the first user's `[admin, user]`, chapter 21's bootstrap rule,
becomes the table's first column.

== the table and deny by default

One vec names every route pattern the service wires and its policy,
and the guard wraps the whole route set in it. The pattern walk is
the guard's own matcher, segments in lockstep with literals and
`{wildcards}` binding params, the same walk the router performs at
dispatch:

#listing("rust/api/src/authz.rs", first: 85, last: 133, caption: [the matcher and the guard: first row to match decides, no row falls through to the kernel])

#listing("rust/api/src/authz.rs", first: 135, last: 158, caption: [the production table: ten rows today, later chapters append, none ever edit])

Here is the honest divergence from both siblings. Go's guard asked
its mux which pattern a request would match and answered 403 for a
pattern missing from the table; java asked its kernel the same
question through `resolvePattern`. This lane's router offers no
such query and this chapter does not edit a landed module, so the
guard matches against its own table and a request matching no row
falls through to the kernel untouched, because 404 and 405 are the
router's answers, not authorization verdicts, and that rule is
pinned by test. Deny by default therefore lives in the audit, both
directions: every table row is driven through the full stack and
must reach a real route, never the kernel's route-not-found 404 or
its 405, and the set of table patterns must equal the set of
patterns the wiring registered, asserted against the wiring
function's own returned inventory. A route registered without a row
breaks the equality, a row pointing at nothing breaks the drive,
and the two sides cannot drift apart in either direction. The
admin routes carry a second belt, their handlers are individually
wrapped in the role policy at registration, go's `GuardRole`
shape, so they stay protected even on a bare router the guard
never saw.

#diagram([the audit: table and wiring face each other, both directions checked], length: 13pt, {
  cdraw.rect((0.8, 5.4), (9.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.6), [policy table], size: 6.5pt)
  cdraw.content((4.9, 6.6), [10 patterns,], size: 6pt)
  cdraw.content((4.9, 5.8), [one policy each], size: 6pt)
  cdraw.rect((14.0, 5.4), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((18.1, 7.6), [wiring inventory], size: 6.5pt)
  cdraw.content((18.1, 6.6), [the registered], size: 6pt)
  cdraw.content((18.1, 5.8), [pattern set], size: 6pt)
  cdraw.line((9.2, 7.1), (13.8, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 7.6), [row must drive], size: 6pt)
  cdraw.line((13.8, 6.1), (9.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.9), [no row for a route: the sets diverge, test fails], size: 6pt)
  cdraw.content((11.5, 4.0), [row for no route: the drive answers 404, test fails], size: 6pt)
  cdraw.content((11.5, 3.1), [no pattern at all: kernel 404 or 405, pinned], size: 6pt)
})

== the grant surface

The admin family is two routes, grant one role and revoke one role,
both answering the resulting set, both validating the closed role
vocabulary before the store is touched, the unknown user 404 and
the unrecognized role 422:

#listing("rust/api/src/authz.rs", first: 278, last: 344, caption: [the vocabulary check, the roles seam into chapter 22, and the grant route: validate, then map the port's two errors])

The grant surface is idempotent in both directions, granting a held
role and revoking an absent one answer the current set with 200,
which is what makes the race test's mixed waves orderly: every
reply is a 200 or the guard's 409, never a surprise.

== the matrix and the races

The fixture wires the whole guarded stack over a real socket, the
same path production traffic takes, and the grid is the proof:
every route times every actor kind, anonymous, regular user, the
stranger on someone else's object, the owner, the admin, one
expected status per cell:

#listing("rust/api/tests/authz.rs", first: 94, last: 146, caption: [the wiring: every family on one router, the inventory returned, identity outside and guard inside])

#diagram([the matrix: routes one way, actors the other, statuses in the cells], length: 13pt, {
  let col(x, head) = cdraw.content((x, 8.8), head, size: 6pt)
  let cell(x, y, v, hot) = {
    cdraw.rect((x - 1.6, y - 0.5), (x + 1.6, y + 0.5), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), v, size: 6pt)
  }
  col(7.0, [anon])
  col(11.4, [user])
  col(15.8, [owner])
  col(20.2, [admin])
  cdraw.content((2.8, 7.7), [list], size: 6pt)
  cdraw.content((2.8, 6.4), [get id], size: 6pt)
  cdraw.content((2.8, 5.1), [get unknown], size: 6pt)
  cdraw.content((2.8, 3.8), [grant], size: 6pt)
  cdraw.content((2.8, 2.5), [revoke], size: 6pt)
  cell(7.0, 7.7, [401], true)
  cell(11.4, 7.7, [200], false)
  cell(15.8, 7.7, [200], false)
  cell(20.2, 7.7, [200], false)
  cell(7.0, 6.4, [401], true)
  cell(11.4, 6.4, [403], true)
  cell(15.8, 6.4, [200], false)
  cell(20.2, 6.4, [200], false)
  cell(7.0, 5.1, [401], true)
  cell(11.4, 5.1, [404], false)
  cell(15.8, 5.1, [404], false)
  cell(20.2, 5.1, [404], false)
  cell(7.0, 3.8, [401], true)
  cell(11.4, 3.8, [403], true)
  cell(15.8, 3.8, [403], true)
  cell(20.2, 3.8, [200], false)
  cell(7.0, 2.5, [401], true)
  cell(11.4, 2.5, [403], true)
  cell(15.8, 2.5, [403], true)
  cell(20.2, 2.5, [200], false)
  cdraw.content((13.6, 1.2), [shaded: the refused cells. ownership opens nothing administrative], size: 6pt)
})

Around the matrix, on the pinned 1.99.0 build, dated 2026-10-13,
the authz test file carries 10 green tests: the twenty matrix
cells, the challenge header beside the two 403 messages and the
404-first order, the owner's full record against the stranger's
public projection, the last-admin chain replayed from vector 14
with the two 200 bodies asserted equal to the vector's, the grant
surface's 422 and 404 and idempotence lanes, the removal guard at
the port with the record snapshot left standing, the same bearer
before and after the table revoke, the two-direction audit at ten
rows against ten routes, the fall-through 404 and 405 for the
rowless path, and the race.

The race is the chapter's spine and it is deterministic where a
socket race usually is not. A first wave, eight threads through the
pool hammering grants and revokes of `admin` on two of three
admins, every reply asserted to be a 200 or the guard's 409 and the
table asserted to still hold an admin at the end. Then the two
contenders are demoted sequentially, ada stands alone, and a second
wave of forty concurrent demotions of ada runs where no thread can
possibly grant anyone admin, so all forty must answer 409 and the
guard's fire under the pool is pinned by count, not by luck:

#listing("rust/api/tests/authz.rs", first: 842, last: 870, caption: [the deterministic wave: ada provably the last admin, forty concurrent refusals counted])

sources: OWASP, Insecure Direct Object Reference Prevention Cheat
Sheet and Access Control Cheat Sheet, at cheatsheetseries.owasp.com,
for the IDOR class and the deny-by-default guidance, RFC 9110
sections 11.6.1 and 15.5.1 to 15.5.4 for the challenge header and
the 401, 403, 404, and 409 semantics, at rfc-editor.org, accessed
2026-10-13. The guard-cannot-ask-the-router divergence stated
against this corpus's own kernels, go book 4 chapter 22 with its
mux-driven lookup and java book 4 chapter 22 with `resolvePattern`.
The last-admin chain, the 409 envelope, and the roles response
bodies from `contract/testdata/14-roles-lastadmin.json`, the go
oracle's file hashed byte-exact into this lane's vectors. All
measurements, 10 tests, the twenty cells, the forty counted
refusals, produced by `cargo test --locked` under
`CARGO_NET_OFFLINE=true` on the pinned build, dated 2026-10-13.
