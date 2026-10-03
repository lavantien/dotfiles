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

Authentication settled who is calling. Authorization decides what
that caller may do, and this chapter builds the whole answer in
`books/javascript/api/src/authz/`: the distinction between the two
questions, roles as stored data with a grant and revoke surface,
policies as plain functions, the 401 versus 403 discipline,
object-level authorization on the routes that carry ids, a
deny-by-default guard with a route audit that keeps every pattern
honest, and the role by endpoint matrix test that pins the whole grid
in one table. The actor is chapter 26's product, the roles live in
chapter 25's store, and this chapter is the thin, total layer between
them and the routes.

== authentication versus authorization

Two questions, two layers, two failure codes. Authentication runs
first and installs an actor or does not, the identity layer from the
last chapter writing `ctx.actor`. Authorization reads that actor
against the route and the object. A policy never parses a token,
checks a signature, or reads a cookie, because by the time one runs
the actor question is settled:

#listing("javascript/api/src/authz/policy.mjs", first: 12, last: 21, caption: [the two cheapest policies: open, and any-actor])

Conflating the two questions produces the classic broken answer, a
403 for an anonymous request. A caller that never proved anything has
no authorization to deny, only an authentication demand, and the
distinction is observable: 401 means try again with credentials, 403
means do not bother, this identity will never pass. Policies deny the
way handlers fail, one thrown `ApiError` the kernel renders, so a
policy is three lines of plain code and nothing else.

#diagram([two layers in wiring order: identity outside, guard inside, handler last], length: 13pt, {
  cdraw.rect((1.0, 6.6), (22.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.4), [identity layer, installs actor or nothing], size: 6.5pt)
  cdraw.content((11.5, 7.4), [bearer jwt or session cookie, one actor either way], size: 6pt)
  cdraw.rect((3.0, 3.8), (20.0, 6.2), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 5.6), [authorization guard], size: 6.5pt)
  cdraw.content((11.5, 4.6), [policy per route pattern, 401 or 403 here], size: 6pt)
  cdraw.rect((6.4, 1.0), (16.6, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 2.8), [handler], size: 6.5pt)
  cdraw.content((11.5, 1.9), [object checks live here, store in reach], size: 6pt)
  cdraw.line((11.5, 6.3), (11.5, 3.5), stroke: luma(100), mark: (end: ">>"))
})

== roles and the grant table

Roles are rows, not magic. Each account carries a set, the bootstrap
rule grants the first registration admin, and the admin routes add
and remove one role at a time, answering the resulting set. The
invariant that matters is never zero admins, and it lives in the user
store where both mutating verbs run it, grant and revoke alike:

#listing("javascript/api/src/users/store.mjs", first: 54, last: 64, caption: [the admin invariant: the scan substitutes the candidate, a rejected demotion leaves no trace])

A revoke computes the post state, checks that some admin still stands
across the whole table, and only then persists, so the rejected
demotion leaves no trace. The frozen vector 14 walks the story:
demoting the only admin answers 409 `last admin`, granting admin to a
second user succeeds, and revoking that second admin then succeeds
too, because the first one is standing again. The bootstrap rule
makes the lockout unreachable in practice, the invariant makes it
unreachable in theory.

#diagram([the grant table: one column per user, the admin row must never empty], length: 13pt, {
  cdraw.content((4.0, 8.7), [ada], size: 6.5pt)
  cdraw.content((11.0, 8.7), [grace], size: 6.5pt)
  cdraw.content((18.0, 8.7), [linus], size: 6.5pt)
  cdraw.rect((2.2, 6.9), (5.8, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 7.5), [admin], size: 6pt)
  cdraw.rect((9.2, 6.9), (12.8, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 7.5), [user], size: 6pt)
  cdraw.rect((16.2, 6.9), (19.8, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.0, 7.5), [user], size: 6pt)
  cdraw.content((11.0, 5.9), [grant admin to grace, then revoke her: fine, ada stands], size: 6pt)
  cdraw.content((11.0, 5.0), [revoke ada first: 409, the table would empty], size: 6pt)
  cdraw.content((11.0, 4.1), [both verbs run the same check, by construction], size: 6pt)
})

== policies as functions

A policy is one function from the context to a verdict: return to
allow, throw to deny. The whole surface composes from four of them,
open, any-actor, a required role, an owner-or-admin check, and each
is short enough to read in one breath:

#listing("javascript/api/src/authz/policy.mjs", first: 35, last: 46, caption: [the object policy: own the id or hold admin])

The pattern's params arrive as an argument because of one subtlety:
the guard layer runs before the router dispatches, `ctx.params` fills
only at dispatch, so the guard resolves the wildcard itself, walking
path and pattern in lockstep with the same static-beats-param rule
the router holds. Plain functions beat a rules dsl or decorator
mining at this size because the table is data the audit test can
walk, and a new rule is a function next to its three siblings.

#diagram([four policies, one shape, the table maps routes onto them], length: 13pt, {
  pane(0.8, 5.8, 8.2, [open], [register, login])
  pane(6.6, 11.6, 8.2, [any actor], [list, logout])
  pane(12.4, 17.4, 8.2, [role admin], [grant, revoke])
  pane(18.2, 23.2, 8.2, [owner or admin], [object routes])
  cdraw.content((11.5, 4.9), [route table: method plus pattern to policy], size: 6pt)
  cdraw.content((11.5, 4.0), [one shape: context in, throw or return], size: 6pt)
})

== 401 versus 403

The boundary lives in one place per policy: the actor check answers
401, the rule check answers 403, and nothing in between exists. Read
it as a state machine. Anonymous gets 401 with the same message every
time, `authentication required`, no hint about the route's existence
or its rules. A present actor that fails the rule gets 403 with the
rule's own words, `insufficient role` or `not the owner`, a statement
about the actor, never about the resource. The one deliberate blur is
existential: this service answers 404 for an unknown id before 403
for a stranger's id, which reveals that an id exists to anyone
authenticated. Hiding it instead means answering 404 for both, and
the tradeoff is real, disclosure against debuggability. What is never
acceptable is mixing the codes by accident, a 403 for a missing
`Authorization` header, a 401 for a demoted admin:

#listing("javascript/api/src/authz/policy.mjs", first: 23, last: 33, caption: [the discipline: no actor is 401, wrong actor is 403])

#diagram([the two failure codes, and the one deliberate blur], length: 13pt, {
  pane(1.2, 10.6, 8.8, [401], [no proof of identity,], [retry with credentials])
  pane(12.4, 21.8, 8.8, [403], [identity, no permission,], [do not retry, ask an admin])
  cdraw.content((11.5, 5.1), [404 hides existence when the threat model wants it], size: 6pt)
  cdraw.content((11.5, 4.2), [this service: 404 first, the audit states it], size: 6pt)
  cdraw.content((11.5, 3.3), [never: 403 for an anonymous call], size: 6pt)
})

== object-level authorization

Route rules cannot guard a route whose danger lives in the path
parameter. `GET /api/users/` followed by someone else's id is the
IDOR class, insecure direct object reference, and it survives every
route-level check because the route is the same for everyone. The
check must happen after the fetch, where the code knows whether the
object exists and who owns it, which is why the object routes carry
only the any-actor row in the table and the ownership rule runs in
the handler:

#listing("javascript/api/test/authz/authz.test.mjs", first: 295, last: 316, caption: [the idor test: a stranger on every object verb, unknown id 404])

The test pins both edges. A stranger touching ada's id gets 403 on
read, write, and delete, whatever etag he presents, and an unknown id
gets 404 for everyone, the ordering the last section discussed. The
stranger is a real account, registered through the open route and
logged in through the real stack, holding a living bearer token the
identity layer resolves, because a hand-built actor would test the
policy table but not the wiring. Putting the owner check in the guard
instead would flatten unknown and forbidden into one 403, leak
existence, and duplicate the store read the handler needs anyway, so
the layering is not style, it is the only arrangement that answers
all three questions correctly.

#diagram([horizontal versus vertical: two axes of privilege, two different checks], length: 13pt, {
  pane(1.4, 9.4, 8.4, [same account], [linus reads ada,], [owner check, after fetch])
  pane(12.6, 20.6, 8.4, [same route], [grace calls admin route,], [role check, before handler])
  cdraw.content((11.5, 5.4), [horizontal is idor, vertical is privilege escalation], size: 6pt)
  cdraw.content((11.5, 4.5), [one needs the object, one needs only the actor], size: 6pt)
  cdraw.content((11.5, 3.6), [both end in 403, never in a leaked row], size: 6pt)
})

== deny by default with a route audit

One table maps every registered pattern to its policy. The guard
sits in the middleware chain inside the identity layer, resolves the
pattern itself, runs the row's policy, and refuses what the table
never saw:

#listing("javascript/api/src/authz/guard.mjs", first: 50, last: 90, caption: [the guard: a row runs its policy, a known path defers to the router, an unaudited route answers 403])

Three lanes leave the loop. A matched row runs its policy and passes
to the router. A path that carries rows only under other methods
defers, 405 with `Allow` is the router's answer, not an authorization
verdict, and so is the 404 for a path nobody registered. The third
lane is the deny-by-default leg: a route registered on the router but
absent from the table answers 403 `no policy for route` before a
handler byte runs. The shipped guard runs row-driven, `registered`
null: the guard wraps the dispatch and cannot see the router's
registrations, and the kernel's pattern list stays closed this pass,
so a constructor-injected oracle seam carries the leg, filled by the
tests and reserved for a later wiring. The audit test closes the
other direction only, and says so: every table row must resolve to a
living route, probed request by request through the full stack, none
answering 404 or 405, so a row cannot point at nothing. A route
registered without a row is the oracle's half, and until that wiring
lands the audit does not claim it:

#listing("javascript/api/test/authz/authz.test.mjs", first: 450, last: 466, caption: [the audit: every row probed through the stack, none dead])

#diagram([the audit: table and router face each other, both directions checked], length: 13pt, {
  pane(0.8, 9.0, 8.2, [route table], [12 patterns,], [one policy each])
  pane(14.0, 22.2, 8.2, [router], [registered patterns,], [resolved on probe])
  cdraw.content((11.5, 7.4), [row must match], size: 6pt)
  cdraw.content((11.5, 4.9), [no row and oracle wired: guard answers 403], size: 6pt)
  cdraw.content((11.5, 4.0), [no route: row is dead, test fails], size: 6pt)
  cdraw.content((11.5, 3.1), [no pattern at all: router 404 or 405], size: 6pt)
})

== the rbac matrix test

The grid is the proof: every route times every actor kind, anonymous,
regular user, the stranger on someone else's object, admin, one
expected status per cell, asserted through the full guarded stack
with living bearer credentials, the same path production traffic
takes:

#listing("javascript/api/test/authz/authz.test.mjs", first: 357, last: 381, caption: [the matrix: actor times route, one status each, real logins])

Each row is a cell with a name that fails loudly. The grid runs the
vector's last-admin chain alongside, so the 409 and the two 200s
around it are pinned by frozen bytes, not just by intent. Adding a
route costs three lines, one case per interesting actor, and the
audit plus the matrix together answer the two questions reviewers
actually ask: is every route covered, and does every covered route
behave for every kind of caller.

#diagram([the matrix: routes one way, actors the other, statuses in the cells], length: 13pt, {
  let col(x, head) = cdraw.content((x, 8.8), [#head], size: 6pt)
  let cell(x, y, v, hot) = {
    cdraw.rect((x - 1.5, y - 0.5), (x + 1.5, y + 0.5), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), [#v], size: 6pt)
  }
  col(6.2, [anon])
  col(10.4, [user])
  col(14.6, [stranger])
  col(18.8, [admin])
  cdraw.content((2.6, 7.7), [list], size: 6pt)
  cdraw.content((2.6, 6.4), [get id], size: 6pt)
  cdraw.content((2.6, 5.1), [patch], size: 6pt)
  cdraw.content((2.6, 3.8), [delete], size: 6pt)
  cdraw.content((2.6, 2.5), [roles], size: 6pt)
  cell(6.2, 7.7, [401], true)
  cell(10.4, 7.7, [200], false)
  cell(14.6, 7.7, [200], false)
  cell(18.8, 7.7, [200], false)
  cell(6.2, 6.4, [401], true)
  cell(10.4, 6.4, [200], false)
  cell(14.6, 6.4, [403], true)
  cell(18.8, 6.4, [200], false)
  cell(6.2, 5.1, [401], true)
  cell(10.4, 5.1, [200], false)
  cell(14.6, 5.1, [403], true)
  cell(18.8, 5.1, [200], false)
  cell(6.2, 3.8, [401], true)
  cell(10.4, 3.8, [403], true)
  cell(14.6, 3.8, [403], true)
  cell(18.8, 3.8, [204], false)
  cell(6.2, 2.5, [401], true)
  cell(10.4, 2.5, [403], true)
  cell(14.6, 2.5, [403], true)
  cell(18.8, 2.5, [200], false)
})

sources: OWASP, Insecure Direct Object Reference Prevention Cheat
Sheet and Access Control Cheat Sheet, at cheatsheetseries.owasp.org,
for the idor class and the deny-by-default guidance, accessed
2026-09-26. RFC 9110 sections 15.5.1 to 15.5.4 on 401, 403, and 404
semantics, at rfc-editor.org. developer.mozilla.org for `Map`
iteration order and `Array.prototype.some`. Accessed 2026-09-26.
Verified by `books/javascript/api/test/authz` tests, 12 of them, under
`npm run verify` with prettier clean.
