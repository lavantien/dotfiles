#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= authz and rbac

Authentication settled who is calling; authorization decides what that
caller may do, and this chapter builds the whole answer: the
distinction between the two questions, roles as stored data with a
grant and revoke surface, policies as plain functions, the 401 versus
403 discipline, object-level authorization on the routes that carry
ids, a deny-by-default guard with a route audit that keeps every
pattern honest, and the role by endpoint matrix test that pins the
whole grid in one table.

== authentication versus authorization

Two questions, two layers, two failure codes. Authentication runs
first and installs an actor or does not; authorization reads that
actor against the route and the object. The service's wiring order
makes the sequence physical: the identity middleware wraps the guard,
the guard wraps the route table, so by the time a policy runs, the
actor question is settled and a policy never parses a token, checks a
signature, or reads a cookie:

#listing("go/api/internal/authz/policy.go", first: 22, last: 33, caption: [the two cheapest policies: open, and any-actor])

Conflating the two questions produces the classic broken answer, a
403 for an anonymous request. A caller that never proved anything has
no authorization to deny, only an authentication demand, and the
distinction is observable: 401 means try again with credentials, 403
means do not bother, this identity will never pass. Every layer in
this chapter keeps that boundary, and the wiring order enforces it
before any handler runs.

#diagram([two layers in wiring order: identity outside, guard inside, handler last], length: 13pt, {
  cdraw.rect((1.0, 6.6), (22.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.4), [identity middleware, installs actor or nothing], size: 6.5pt)
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
invariant that matters is never zero admins, and it lives in the
store where both mutating verbs run it, grant and revoke alike:

#listing("go/api/internal/user/store.go", first: 208, last: 225, caption: [grant adds a role, the admin invariant gates both verbs])

A revoke computes the post state, checks that some admin still stands
across the whole table, and only then persists, so the rejected
demotion leaves no trace. The frozen vector walks the story: demoting
the only admin answers 409 conflict, last admin, granting admin to a
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
  cdraw.line((10.0, 6.6), (11.0, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.0, 5.9), [grant admin], size: 6pt)
  cdraw.rect((9.2, 4.4), (12.8, 5.7), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 5.0), [admin], size: 6pt)
  cdraw.content((11.5, 3.4), [revoke grace now: fine, ada stands], size: 6pt)
  cdraw.content((11.5, 2.5), [revoke ada first: 409, the table would empty], size: 6pt)
  cdraw.content((11.5, 1.6), [both verbs run the same check, by construction], size: 6pt)
})

== policies as functions

A policy is one function from request plus pattern to verdict: nil
allows, a contract error denies. The whole surface composes from four
of them, open, any-actor, a required role, an owner-or-admin check,
and each is short enough to read in one breath:

#listing("go/api/internal/authz/policy.go", first: 54, last: 66, caption: [the object policy: own the id or hold admin])

The pattern rides along as an argument because of one subtlety: the
guard wrapper runs before the mux dispatches, and the request's path
values are filled only at dispatch. So the policy extracts the
wildcard itself, walking path and pattern in lockstep, the same
segment match the mux performs. Plain functions beat a rules dsl or
annotation mining at this size because the compiler type-checks the
table, the audit test can walk it, and a new rule is a function next
to its three siblings.

#diagram([four policies, one signature, the table maps routes onto them], length: 13pt, {
  let poly(x0, title, l1) = {
    cdraw.rect((x0, 5.8), (x0 + 5.0, 8.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 7.5), title, size: 6.5pt)
    cdraw.content((x0 + 2.5, 6.5), l1, size: 6pt)
  }
  poly(0.8, [open], [register, login])
  poly(6.6, [any actor], [list, logout])
  poly(12.4, [role admin], [grant, revoke])
  poly(18.2, [owner or admin], [object routes])
  cdraw.rect((4.6, 2.2), (18.4, 4.6), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 3.9), [route table to policy], size: 6.5pt)
  cdraw.content((11.5, 3.0), [pattern string keys, function values], size: 6pt)
  cdraw.content((11.5, 2.1), [one signature: request plus pattern to error], size: 6pt)
})

== 401 versus 403

The boundary lives in one place per policy: the actor check answers
401, the rule check answers 403, and nothing in between exists:

#listing("go/api/internal/authz/policy.go", first: 35, last: 49, caption: [the discipline: no actor is 401, wrong actor is 403])

Read it as a state machine. Anonymous gets 401 with the same message
every time, authentication required, no hint about the route's
existence or its rules. A present actor that fails the rule gets 403
with the rule's own words, insufficient role or not the owner, which
is a statement about the actor, never about the resource. The one
deliberate blur is existential: this service answers 404 for an
unknown id before 403 for a stranger's id, which reveals that an id
exists to anyone authenticated. Hiding it instead means answering 404
for both, and the tradeoff is real, disclosure against debuggability.
What is never acceptable is mixing the codes by accident, a 403 for a
missing Authorization header, a 401 for a demoted admin.

#diagram([the two failure codes, and the one deliberate blur], length: 13pt, {
  cdraw.rect((1.2, 6.4), (10.6, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 8.2), [401], size: 7pt)
  cdraw.content((5.9, 7.2), [no proof of identity], size: 6pt)
  cdraw.content((5.9, 6.3), [retry with credentials], size: 6pt)
  cdraw.rect((12.4, 6.4), (21.8, 8.8), fill: luma(222), radius: 0.02)
  cdraw.content((17.1, 8.2), [403], size: 7pt)
  cdraw.content((17.1, 7.2), [identity, no permission], size: 6pt)
  cdraw.content((17.1, 6.3), [do not retry, ask an admin], size: 6pt)
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
only the any-actor policy in the table and the ownership rule runs
in the handler:

#listing("go/api/internal/authz/authz_test.go", first: 239, last: 261, caption: [the IDOR test: stranger on every object verb, unknown id 404])

The test pins both edges. Linus touching ada's id gets 403 on read,
write, and delete, whatever etag he presents, and an unknown id gets
404 for everyone, the ordering the last section discussed. Putting
the owner check in the guard instead would flatten unknown and
forbidden into one 403, leak existence, and duplicate the store read
the handler needs anyway, so the layering is not style, it is the
only arrangement that answers all three questions correctly.

#diagram([horizontal versus vertical: two axes of privilege, two different checks], length: 13pt, {
  cdraw.content((5.4, 8.9), [same account], size: 6.5pt)
  cdraw.rect((1.4, 6.6), (9.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 7.6), [linus reads ada], size: 6pt)
  cdraw.content((5.4, 6.7), [owner check, after fetch], size: 6pt)
  cdraw.content((16.6, 8.9), [same route], size: 6.5pt)
  cdraw.rect((12.6, 6.6), (20.6, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((16.6, 7.6), [grace calls admin route], size: 6pt)
  cdraw.content((16.6, 6.7), [role check, before handler], size: 6pt)
  cdraw.content((11.5, 5.4), [horizontal is IDOR, vertical is privilege escalation], size: 6pt)
  cdraw.content((11.5, 4.5), [one needs the object, one needs only the actor], size: 6pt)
  cdraw.content((11.5, 3.6), [both end in 403, never in a leaked row], size: 6pt)
})

== deny by default with a route audit

One table maps every registered pattern to its policy. A guard
wrapper sits in the middleware stack, resolves the pattern the mux
would match, and refuses any pattern missing from the table before a
handler byte runs:

#listing("go/api/internal/authz/guard.go", first: 21, last: 37, caption: [the guard: no table row, no response])

The audit test closes the loop from the other side: every table row
must resolve to a registered route with exactly that pattern, and a
hand-written inventory of the contract's routes must be present,
twelve here and fourteen once chapter 23 appends the reports pair, so
a route cannot exist unaudited, a row cannot point at
nothing, and a new route that forgets its policy becomes instantly,
loudly unreachable instead of quietly open. Requests that match no
pattern at all fall through to the kernel fallback, because 404 and
405 are routing answers, not authorization verdicts:

#snippet(
  "for pattern := range RoutePolicies {\n"
  + "\tmethod, path, _ := strings.Cut(pattern, \" \")\n"
  + "\treq := httptest.NewRequest(method, wildcardFree(path), nil)\n"
  + "\t_, matched := f.mux.Handler(req)\n"
  + "\tif matched != pattern {\n"
  + "\t\tt.Errorf(\"table row %q resolves to %q\", pattern, matched)\n"
  + "\t}\n"
  + "}",
  lang: "go",
)

#diagram([the audit: table and mux face each other, both directions checked], length: 13pt, {
  cdraw.rect((0.8, 5.4), (9.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.6), [route table], size: 6.5pt)
  cdraw.content((4.9, 6.6), [12 patterns,], size: 6pt)
  cdraw.content((4.9, 5.8), [one policy each], size: 6pt)
  cdraw.rect((14.0, 5.4), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((18.1, 7.6), [mux], size: 6.5pt)
  cdraw.content((18.1, 6.6), [registered patterns,], size: 6pt)
  cdraw.content((18.1, 5.8), [resolved on probe], size: 6pt)
  cdraw.line((9.2, 7.1), (13.8, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 7.6), [row must match], size: 6pt)
  cdraw.line((13.8, 6.1), (9.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.9), [no row: guard answers 403], size: 6pt)
  cdraw.content((11.5, 4.0), [no route: row is dead, test fails], size: 6pt)
  cdraw.content((11.5, 3.1), [no pattern at all: kernel 404 or 405], size: 6pt)
})

== the rbac matrix test

The grid is the proof: every route times every actor kind, anonymous,
regular user, admin, stranger on someone else's object, one expected
status per cell, asserted in one table-driven test through the full
guarded stack, the same path production traffic takes:

#listing("go/api/internal/authz/authz_test.go", first: 186, last: 207, caption: [the matrix rows: actor times route, one status each])

Each row is a cell with a name that fails loudly. The grid runs the
vector's last-admin chain alongside, so the 409 and the two 200s
around it are pinned by frozen bytes, not just by intent. Adding a
route costs three lines, one table row per interesting actor, and the
audit plus the matrix together answer the two questions reviewers
actually ask: is every route covered, and does every covered route
behave for every kind of caller.

#diagram([the matrix: routes one way, actors the other, statuses in the cells], length: 13pt, {
  let col(x, head) = cdraw.content((x, 8.8), head, size: 6pt)
  let cell(x, y, v, hot) = {
    cdraw.rect((x - 1.5, y - 0.5), (x + 1.5, y + 0.5), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), v, size: 6pt)
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
  cell(10.4, 3.8, [204], false)
  cell(14.6, 3.8, [403], true)
  cell(18.8, 3.8, [204], false)
  cell(6.2, 2.5, [401], true)
  cell(10.4, 2.5, [403], true)
  cell(14.6, 2.5, [403], true)
  cell(18.8, 2.5, [200], false)
})

sources: OWASP, Insecure Direct Object Reference Prevention Cheat
Sheet and Access Control Cheat Sheet, at cheatsheetseries.owasp.com,
for the IDOR class and the deny-by-default guidance; RFC 9110
sections 15.5.1 to 15.5.4 on 401, 403, and 404 semantics; the go 1.27
net/http ServeMux documentation for pattern matching and
request-scoped path values. Accessed 2026-09-25. Verified by
`go/api/internal/authz` tests under `go test` and `go vet`, race
detector on.
