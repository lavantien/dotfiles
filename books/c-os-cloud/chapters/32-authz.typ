#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= authz and rbac

Authentication answers who is calling, authorization answers what they
may do, and conflating the two is how an api ends up where every
logged-in user can touch every row. This chapter builds the
authorization layer as one fixed table and one decision function: a
row per installed route stating its requirements, a verdict function
that walks the caller's facts through the row, the 401 before 403
ordering, object-level checks for routes that name an id, and the
never-zero-admins invariant the role endpoints share with the store.

== authentication versus authorization

The previous chapter's output is an actor or its absence: a resolved
user id, a session id, and roles read from the store, never trusted
from the token. That is the whole input this layer accepts. What it
produces is a verdict about the route, the actor, and sometimes the
object, and the verdict vocabulary is four values, allow, missing
actor, missing standing, no row. The row type is the layer in one
screen:

#listing("c-os-cloud/api/api.h", first: 973, last: 980, caption: [the policy row: a route's exact text and its three requirements])

The split keeps each side honest. Because roles ride the actor and
not the jwt, granting or revoking a role takes effect at the next
request without reissuing anything, which the last section's invariant
depends on. Because the policy reads facts rather than headers, the
same table answers in a test with three integers as it does in the
wired service with a session behind them. And because the layer never
parses credentials, a bug here cannot accidentally authenticate
anyone, it can only be too strict, which is the failure direction a
security layer wants.

#diagram([the boundary: authn resolves, authz decides], length: 13pt, {
  pane(0.6, 8.6, 8.2, [authn, previous chapter], [token or cookie], [an actor or none])
  cdraw.line((8.8, 6.6), (10.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(10.2, 18.0, 8.2, [the facts], [actor, admin, owner], [three integers])
  cdraw.line((18.2, 6.6), (19.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(19.6, 25.0, 8.2, [authz], [the table], [a verdict])
  cdraw.content((11.5, 3.6), [roles come from the store, the token carries none], size: 6pt)
  cdraw.content((11.5, 2.4), [authz never parses a credential, only facts], size: 6pt)
})

== roles and the grant table

The service knows two roles, admin and user, and the set is closed at
the border: a grant or revoke payload carrying anything else answers
422 before the store is touched. The bootstrap rule gives the first
registered user the admin role and every later user the plain one, so
the system starts with exactly one administrator and grows them only
by explicit grants. The closed set is one comparison wide:

#listing("c-os-cloud/api/src/users_validate.c", first: 98, last: 105, caption: [the closed role set, one refusal message for everything outside it])

Roles are user data, so the role endpoints are user routes under an
admin guard, and the registrar is guarded: the wiring wraps each route
with its policy row at registration, so the protection travels with
the route and cannot be forgotten by a handler that mounts later. The
grant and revoke handlers validate the payload, call the store, and
map the store's outcomes, and the one conflict the family can produce
is the last-admin rule at the end of this chapter.

#diagram([the grant table: a closed set, guarded doors, the bootstrap admin], length: 13pt, {
  pane(0.6, 7.6, 8.2, [the closed set], [admin, user], [anything else 422])
  pane(8.2, 15.2, 8.2, [the registrar], [route plus row], [wrapped at mount])
  pane(15.8, 23.4, 8.2, [the store rows], [grant, revoke, list], [versioned rows])
  cdraw.content((11.5, 3.6), [the first registration holds admin, every later one user], size: 6pt)
})

== the fixed policy table

Every installed route has exactly one row, and the row's text is the
router's own pattern string, so the table and the route table cannot
drift apart silently. The whole policy is visible in one screen, which
is the point: a reader can audit who may do what by reading 15 lines,
not by tracing middleware chains:

#listing("c-os-cloud/api/src/authz_policy.c", first: 12, last: 28, caption: [the whole policy: one row per route, flags for auth, admin, and object standing])

Three flags answer three questions. Does the route need an actor at
all, the health checks and login do not. Does it need the admin role,
the two role endpoints do. Does it operate on an object the caller
might or might not own, the three user-by-id routes do. Field-level
authorization rides the same flag at the list route: an admin reader
sees email and roles members, everyone else sees the public
projection, the rule the user resource chapter placed in one function.
The table is static const, indexed by a linear scan over 15 rows,
which at this size beats any hash and allocates nothing.

#diagram([the table: rows of routes, flags of requirements, one scan], length: 13pt, {
  let rowy(y, route, flags) = {
    cdraw.rect((1.4, y - 0.9), (13.6, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((7.5, y - 0.25), route, size: 6pt)
    cdraw.content((18.2, y - 0.25), flags, size: 6pt)
  }
  rowy(7.6, [healthz, readyz, login, refresh], [open])
  rowy(5.7, [logout, list users, reports], [actor])
  rowy(3.8, [get, patch, delete user by id], [actor plus owner])
  rowy(1.9, [grant, revoke roles], [actor plus admin])
  cdraw.content((9.0, 0.4), [15 rows, one scan, zero allocation], size: 6pt)
})

== 401 versus 403

The two codes say different things and the order they are answered in
is a disclosure decision. A 401 means the caller is nobody, no actor
resolved, and the fix is credentials. A 403 means the caller is
somebody who lacks the standing, and the fix does not exist client
side. The rule this layer enforces is that the 401 answers first:
an anonymous caller on an admin route learns that credentials are
missing, never that the route wants the admin role, because a 403
body to an anonymous caller is a disclosure of the route's
protections:

#listing("c-os-cloud/api/src/authz_policy.c", first: 40, last: 53, caption: [decide: no row, then 401, then the two 403 shapes, then allow])

The function is short enough to verify by reading, which is the
security argument. Four checks in a fixed order, each returning one
of the four verdicts, no state, no side effects, no allocation. The
no-row check is first because it is not a verdict about a caller at
all, it is a programming error caught at wiring, and it must not
shadow behind a 401 that would make a missing row look like a
protected route.

#diagram([the verdict order, each rung one answer], length: 13pt, {
  let rung(y, label, fill) = {
    cdraw.rect((4.8, y), (18.2, y + 1.25), fill: fill, radius: 0.02)
    cdraw.content((11.5, y + 0.6), label, size: 6pt)
  }
  rung(6.6, [no row, the wiring error], luma(235))
  rung(5.0, [401 no actor], luma(235))
  rung(3.4, [403 route wants admin], luma(235))
  rung(1.8, [403 object route, not the owner], luma(235))
  cdraw.line((11.5, 6.5), (11.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 4.9), (11.5, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 3.3), (11.5, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 0.7), [everything left is allow], size: 6pt)
})

== object-level authorization

Route-level checks answer what kind of caller may use a route.
Object-level checks answer whether this caller may touch this row, and
it is the layer where idor bugs live: a route guarded perfectly at the
route level still leaks if it forgets to compare the id in the path
against the id in the actor. The policy carries that requirement as
the owner-or-admin flag, and the object routes read it:

#listing("c-os-cloud/api/tests/test_authz.c", first: 112, last: 120, caption: [the object rule pinned: stranger refused, owner and admin through])

The 404 answers before the 403 at the handler, the trade the user
resource chapter stated: an unknown id and a stranger's id stay
distinguishable, an api that prefers hiding existence answers 404 for
both, and the contract picks the distinguishable reading. What no
reading permits is the third path, a guarded route with an unguarded
object, and the flag makes that impossible to write by accident,
because the object routes read their standing from the same row their
route guard did.

#diagram([route level versus object level, two doors on one request], length: 13pt, {
  pane(0.6, 8.4, 8.2, [route level], [what kind of caller], [may use this route])
  cdraw.line((8.6, 6.6), (9.8, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(10.0, 18.0, 8.2, [object level], [this caller], [may touch this row])
  cdraw.line((18.2, 6.6), (19.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(19.6, 25.0, 8.2, [the row], [owner passes], [stranger 403])
  cdraw.content((11.5, 3.4), [idor is a route guarded at the first door and open at the second], size: 6pt)
})

== deny by default with a route audit

A route absent from the table has no verdict, and the wiring guard
turns that absence into a loud failure at startup rather than a
silent allow. The audit has two halves. The matrix test walks every
row against every actor class and demands the verdict follow from the
flags. The duplicate scan demands no two rows name the same route,
because a second row for one route is how an accidental allow hides
behind a correct one:

#listing("c-os-cloud/api/tests/test_authz.c", first: 93, last: 101, caption: [the audit's duplicate scan: two rows for one route is the hiding place])

The deny-by-default posture reads off the lookup: a route not in the
table is not in the service, and a caller sending its method against
its pattern reaches the router's own 404 before any policy question,
because there is no handler to guard. What the guard catches is the
programmer error in the other direction, a handler mounted without a
row, and it catches it at wiring time, when fixing it costs one line,
not after an audit finds the unguarded route in production.

#diagram([the audit: every row, every actor class, no duplicates], length: 13pt, {
  pane(0.6, 7.6, 8.2, [the matrix walk], [15 rows x 4 classes], [verdict from flags])
  cdraw.line((7.8, 6.6), (9.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(9.2, 16.6, 8.2, [the duplicate scan], [one route, one row], [no shadow allows])
  cdraw.line((16.8, 6.6), (18.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(18.2, 25.0, 8.2, [the wiring guard], [no row, no mount], [loud at startup])
  cdraw.content((11.5, 3.4), [absence denies, duplication hides, both are caught], size: 6pt)
})

== the last admin rule

An authorization system that can lock out every administrator has a
self-destruct button, and the role endpoints hold it. The invariant is
never zero admins: a revoke that would leave none standing answers
409, and the grant path runs the same check, the belt and suspenders
the contract asks for even though a grant can only add. The rule as
this layer states it is pure math, one line over the candidate's post
state and the count of everyone else:

#listing("c-os-cloud/api/src/authz_policy.c", first: 55, last: 59, caption: [the invariant: after the change, does an admin remain])

The store enforces it inside the write statement itself, the guard
riding the sentence's own predicate: a grant of admin passes because
the post state keeps an admin by construction, any other grant passes
only where an admin already stands, and a revoke deletes only when
the row is not an admin row or another holder survives it, so there
is no count-then-write window to race, the engine's write lock
serializing two revokers the same way the cas clause serializes two
patchers. The verdict then reads the row, not the engine's change
counter, because a pooled handle can answer another thread's count:
still standing after the statement means the guard refused it and the
answer is the 409, gone means the change landed or never existed, and
both are the caller's ok. A refused statement touches nothing, so a
rejected change leaves no trace. The frozen vector walks the whole
story: revoking the admin role from the last holder answers 409
with the last admin message, granting it to a second user succeeds,
and the same revoke that refused before now passes, because a spare
admin stands. Both endpoints answer with the resulting role list, so
the caller sees the state it reached.

#diagram([the invariant over one revoke: post state versus everyone else], length: 13pt, {
  pane(0.6, 8.0, 8.2, [the candidate], [post-change roles], [admin or not])
  cdraw.line((8.2, 6.6), (9.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(9.6, 16.4, 8.2, [the scan], [every other row], [any admin?])
  cdraw.line((16.6, 6.6), (17.8, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(18.0, 25.0, 8.2, [the verdict], [no admin left: 409], [else commit])
  cdraw.content((11.5, 3.4), [grant and revoke both run it, inside the write transaction], size: 6pt)
})

== the rbac matrix test

The matrix test is the audit made executable: every row against every
actor class, anonymous, plain actor, non-owner on an object route,
owner, admin, with the expected verdict derived from the row's own
flags. The test never lists expectations by hand, it computes them
from the same flags the decision function reads, so a new route added
to the table is covered the moment its row lands:

#listing("c-os-cloud/api/tests/test_authz.c", first: 72, last: 91, caption: [the matrix walk: expectations derived from the row's flags, not hand-listed])

The derivation is the interesting part. A hand-written table of
expectations would be a second copy of the policy, and the two copies
would drift. Reading the flags keeps one source of truth and turns
the test into an invariant check, the verdict function agrees with the
row's stated requirements for every combination, rather than a
snapshot. The refusal classes the matrix cannot express, the no-row
verdicts and the method-keyed lookup, carry their own checks, and the
never-zero-admins math is pinned from both directions, the refusing
revoke and every passing shape.

#diagram([the matrix: rows against actor classes, expectations from the flags], length: 13pt, {
  cdraw.content((4.0, 8.4), [rows down, actors across], size: 6.5pt)
  let cellr(y, label) = cdraw.content((2.4, y), label, size: 6pt)
  cellr(7.3, [open routes])
  cellr(6.0, [actor routes])
  cellr(4.7, [object routes])
  cellr(3.4, [admin routes])
  let cellc(x, label) = cdraw.content((x, 8.0), label, size: 6pt)
  cellc(9.0, [anon])
  cellc(13.0, [plain])
  cellc(17.0, [owner])
  cellc(21.0, [admin])
  cdraw.rect((7.6, 6.8), (11.0, 7.8), fill: luma(222), radius: 0.02)
  cdraw.content((9.3, 7.3), [401], size: 6pt)
  cdraw.rect((19.4, 2.9), (22.8, 3.9), fill: luma(222), radius: 0.02)
  cdraw.content((21.1, 3.4), [allow], size: 6pt)
  cdraw.rect((11.2, 3.0), (14.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((13.0, 3.6), [403], size: 6pt)
  cdraw.content((12.5, 1.2), [every cell derived from the row's flags, one truth], size: 6pt)
})

sources: RFC 9110 section 15.5.1 with 15.5.4 for the 401 and 403
semantics and their ordering as a disclosure trade, and section 15.5.5
for 404, accessed 2026-09-27, the frozen vector 14 at
`c-os-cloud/api/contract/testdata/` for the last-admin walk, 409 then
grant then revoke, and the go and c sharp mirrors' authz chapters for
the route-audit and matrix-test shapes this lane re-derives. Verified
by
the authz family's 40 checks under the pinned clang 23 through
`make verify-capi`, plus clang-format over every file touched.
