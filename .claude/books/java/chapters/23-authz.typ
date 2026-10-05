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
caller may do, in `javabook.authz`: roles as stored data with a grant
and revoke surface, the policy table that maps every route pattern to
one plain function, the object-level check whose absence the industry
names IDOR, the 401 versus 403 discipline that keeps the two answers
from swapping places, and the deny-by-default guard that makes an
unaudited route unreachable instead of quietly open. The go book
built the same layer over its mux's own pattern matching,
#xref-to("go", "authz"), and the java difference runs through the
whole chapter: java's filters run before the kernel dispatches, so
the table asks the kernel's own route resolution instead of reading
path values the framework would have filled.

== authentication versus authorization

Two questions, two layers, two failure codes. Authentication runs
first and installs an actor or does not, chapter 22's filter.
Authorization reads that actor against the route and, on the object
routes, against the record. A caller that never proved anything has
no authorization to deny, only an authentication demand, so 401 means
try again with credentials and 403 means do not bother, this identity
will never pass. The wiring makes the sequence physical, the authn
filter sits outside the guard, so by the time a policy runs the actor
question is settled and a policy never parses a token, checks a
signature, or hashes a password:

#diagram([two layers in wiring order: authn outside, guard inside, handler last], length: 13pt, {
  cdraw.rect((1.0, 6.6), (22.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.4), [authn filter, installs actor or answers 401], size: 6.5pt)
  cdraw.content((11.5, 7.4), [bearer token verified, roles read from the grants store], size: 6pt)
  cdraw.rect((3.0, 3.8), (20.0, 6.2), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 5.6), [authorization guard], size: 6.5pt)
  cdraw.content((11.5, 4.6), [policy per route pattern, 403 here], size: 6pt)
  cdraw.rect((6.4, 1.0), (16.6, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 2.8), [handler], size: 6.5pt)
  cdraw.content((11.5, 1.9), [reads the actor attribute, never a token], size: 6pt)
  cdraw.line((11.5, 6.3), (11.5, 3.5), stroke: luma(100), mark: (end: ">>"))
})

== policies as functions

A policy is one function from exchange, actor, and pattern to a
verdict: return to allow, throw the contract's `ApiError` to deny.
The whole surface composes from four of them, open, any actor, a
required role, an owner-or-admin check, and each is short enough to
read in one breath:

#listing("java/api/src/javabook/authz/Policy.java", first: 29, last: 57, caption: [open, authenticated, and role: the 401 versus 403 discipline lives in the last two lines of role])

#diagram([four policies, one signature, the table maps routes onto them], length: 13pt, {
  let poly(x0, title, l1) = {
    cdraw.rect((x0, 5.8), (x0 + 5.0, 8.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 7.5), title, size: 6.5pt)
    cdraw.content((x0 + 2.5, 6.5), l1, size: 6pt)
  }
  poly(0.8, [open], [probes, register, login])
  poly(6.6, [any actor], [the user list])
  poly(12.4, [role admin], [grant, revoke])
  poly(18.2, [owner or admin], [get by id])
  cdraw.rect((4.6, 2.2), (18.4, 4.6), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 3.9), [route table to policy], size: 6.5pt)
  cdraw.content((11.5, 3.0), [pattern string keys, function values], size: 6pt)
  cdraw.content((11.5, 2.1), [one signature: exchange, actor, pattern, throw to deny], size: 6pt)
})

Plain functions beat a rules dsl or annotation mining at this size
because the compiler type-checks the table, the audit test can walk
it, and a new rule is a function beside its siblings. The role
vocabulary itself is two constants and deliberately flat, admin and
user with no hierarchy: an `admin implies user` rule would be one
line, and the day the implicit expansion hides a grant from the
person auditing the table, that line costs more than it ever bought.

== object-level authorization

Route rules cannot guard a route whose danger lives in the path
parameter. `GET /api/users/` followed by someone else's id is the
IDOR class, insecure direct object reference, and it survives every
route-level check because the route is the same for everyone. The
check needs the record, whether it exists and who owns it, and in go
that meant the handler after the fetch. Java's guard has another
option worth taking: the policy extracts the wildcard itself, walking
the raw path and the pattern in lockstep, so the object check can
live in the table and still answer all three questions correctly:

#listing("java/api/src/javabook/authz/Policy.java", first: 64, last: 85, caption: [the object policy: extract the wildcard, 404 the unknown id, 403 the stranger, allow owner or admin])

The store read inside the policy is the price of the 404-first order,
and it is stated rather than hidden: the handler fetches again, one
row read twice on the object route, in exchange for keeping the
unknown id answering the same 404 a nonexistent route would. What
the order does not hide is existence from an authenticated caller:
a stranger probing ids still splits 404 from 403, and which ids are
real is exactly what that split reveals. The go chapter made the
same trade and named it, the alternative is answering 404 for both,
and the choice here is debuggability over disclosure at book scale,
stated where the code states it rather than paid silently.

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

== roles as stored data

Roles are rows, not magic. The port is three verbs over user id to
role set, the in-memory implementation is one monitor, and the
invariant that matters lives where the only verb that can break it
runs: a revoke that would leave the whole table without one admin
throws, so the demotion is refused with nothing written:

#listing("java/api/src/javabook/authz/MemGrants.java", first: 34, last: 58, caption: [the never-zero-admins invariant, checked before the row changes])

The admin routes are the grant surface, add one role, remove one
role, answering the resulting set, and they are themselves governed
by the admin policy row, so the only way in is to already hold the
role. The first admin cannot come from this surface, and the
bootstrap rule is a decorator at the wiring seam instead: a create
that lands while the grants table has never granted anything mints
the admin. The question the decorator asks is the empty grants
table, not the empty user store, and the difference is fail-safety:
a crash between one create and its grant leaves the table still
empty, so the next registration bootstraps instead of an admin
surface locked out forever, which the fail-safe test pins with a
grants source whose first grant throws. Chapter 21's handlers and
this chapter's table read the same wrapped store, and neither knows
the rule ran:

#listing("java/api/src/javabook/authz/FirstAdmin.java", first: 32, last: 38, caption: [the bootstrap rule as a decorator: the empty grants table mints the admin])

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
  cdraw.content((11.5, 1.6), [roles read at request time, never off the token], size: 6pt)
})

The decorator is also where the actor's role source meets the token:
chapter 22's filter reads `grants.of(user)` at request time, so a
demoted admin loses the role on the very next request, not at the
next login, and the matrix test's last cell pins exactly that, the
same bearer token crossing an admin route successfully before the
grant and again after it with no reissue anywhere.

== the table and deny by default

One map names every registered pattern and its policy, and the guard
wraps the whole route set in it. A resolved pattern missing from the
table answers 403 before a handler byte runs, so a new route that
forgets its policy is loudly unreachable instead of quietly open.
Requests that match no pattern at all fall through untouched, because
404 and 405 are the kernel's answers, not authorization verdicts:

#listing("java/api/src/javabook/authz/Policy.java", first: 87, last: 98, caption: [the production table: eight rows today, later chapters append, none ever edit])

#listing("java/api/src/javabook/authz/Guard.java", first: 35, last: 57, caption: [the guard: no row, no response, routing answers pass through])

The open set chapter 22 wired as a hand-written predicate is now read
off this same table, `table.get(pattern) == Policy.OPEN`, so there is
one source of truth for what takes anonymous traffic and the authn
filter and the guard cannot drift apart. An anonymous call to an
unaudited route meets the authn layer's 401 first and an
authenticated one meets the guard's 403, and either way the route is
unreachable, which is the property deny by default buys.

The audit closes the loop from the other side and both directions
walk it: every table row must resolve, through the kernel's own
`resolvePattern`, to a registered route with exactly that pattern,
and every registered route, enumerated by the `App.routes()` inventory
chapter 22 added, must carry a row. A route cannot exist unaudited, a
row cannot point at nothing, and the counts face each other in the
test, eight against eight today.

== the wiring

The program's `Main` grows the family once more. The grants table and
the store are constructed before the filters because the policy table
reads the store and the authn filter reads the grants, and one store
instance wrapped in the bootstrap decorator serves registration,
login, the policy table, and the admin routes alike:

#listing("java/api/src/javabook/Main.java", first: 59, last: 70, caption: [the guarded wiring: table before filters, one store under everything])

#diagram([the audit: table and route inventory face each other, both directions checked], length: 13pt, {
  cdraw.rect((0.8, 5.4), (9.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.6), [policy table], size: 6.5pt)
  cdraw.content((4.9, 6.6), [8 patterns,], size: 6pt)
  cdraw.content((4.9, 5.8), [one policy each], size: 6pt)
  cdraw.rect((14.0, 5.4), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((18.1, 7.6), [route inventory], size: 6.5pt)
  cdraw.content((18.1, 6.6), [App.routes(),], size: 6pt)
  cdraw.content((18.1, 5.8), [resolved on probe], size: 6pt)
  cdraw.line((9.2, 7.1), (13.8, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 7.6), [row must match], size: 6pt)
  cdraw.line((13.8, 6.1), (9.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.9), [no row: guard answers 403], size: 6pt)
  cdraw.content((11.5, 4.0), [no route: row is dead, test fails], size: 6pt)
  cdraw.content((11.5, 3.1), [no pattern at all: kernel 404 or 405], size: 6pt)
})

One honest omission against the go chapter: its user package
projected the wire representation per reader, the public projection
for everyone but admins, field-level authorization inside the record.
This book keeps chapter 21's one representation and guards routes,
so an authenticated caller on the list route sees emails. The reason
is the same discipline the whole part runs on, the pinned test bytes:
a second projection would fork the writer and the etag with it, and
the trade is stated here rather than paid silently.

== the rbac matrix

The grid is the proof: every route times every actor kind, anonymous,
regular user, the stranger on someone else's object, the admin, one
expected status per cell, asserted in one table-driven test through
the full guarded stack over a real socket, the same path production
traffic takes. Each row is a cell with a name that fails loudly:

#listing("java/api/test/javabook/authz/AuthzTests.java", first: 124, last: 150, caption: [the matrix rows: route times actor, one status each, the promoted cell last])

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

Around the matrix: the code split pinned on its own, the 401
envelope with its challenge header beside the 403 with the rule's own
words and the 404 the unknown id answers first, the last-admin
chain, demote the only admin for the 409, grant a second for the
200, demote the first again for the 200, and the 409 returns to
whoever now stands alone, the grant surface validating unknown users
and unrecognized roles, the deny-by-default counterexample wired with
one row deleted and proving the 403 by name, the fail-safe
bootstrap with a throwing grants source, and the audit walking both
directions. Eight tests this chapter, green three consecutive runs
in a module now numbering 92.

sources: OWASP, Insecure Direct Object Reference Prevention Cheat
Sheet and Access Control Cheat Sheet, at cheatsheetseries.owasp.com,
for the IDOR class and the deny-by-default guidance, and RFC 9110
sections 15.5.1 to 15.5.4 for the 401, 403, and 404 semantics,
accessed 2026-10-05. The go contrasts, the handler-side owner check,
the field-level projection, and the mux-driven audit, against book 3,
chapter 22. Verified live 2026-10-05 by the `javabook.authz` tests
under the vendored junit 6.1.3 lane, 8 tests green three consecutive
runs in a module of 92, covering the twelve matrix cells, the code
split with messages, the last-admin chain, the grant surface's 404
and 422 lanes, the deny-by-default counterexample, the fail-safe
bootstrap, the two direction audit at eight rows against eight
routes, and the flat role set with the bootstrap grant.
