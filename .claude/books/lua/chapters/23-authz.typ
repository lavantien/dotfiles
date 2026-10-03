#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= authorization and roles

Authentication settled who is calling. Authorization decides what
that caller may do, and this chapter builds the whole answer as one
data table and one walk over it: the two questions kept apart with
their two codes, the policy rows keyed by method and pattern, the
object routes asked by their pattern and never a raw path, roles as
store data with the never-zero-admins guard, the two-direction audit
that keeps the route table and the policy table honest, and the
matrix replay that runs every route against every actor kind.

== two questions, two codes

The identity layer resolves one actor from the credentials and
installs it on the request, or installs nothing. Everything past
that point reads the actor and never parses a token, checks a
signature, or touches a cookie. Two failure codes carry the two
questions: 401 means no proof of identity arrived, try again with
credentials, and 403 means the identity is known and still may not,
do not bother retrying. Conflating them produces the classic broken
answer, a 403 for an anonymous request that leaks what standing the
route wants:

#listing("lua/service/authz.lua", first: 64, last: 75, caption: [the walk: 401 before any 403, no row the loud failure])

The order inside is policy, not accident. An anonymous caller learns
nothing about a route's rules, because the 401 answers before any
rule is consulted, and a present actor that fails a rule gets the
403 with the rule's own words, a statement about the actor and never
about the resource. No handler re-derives any of this. The handlers
read an actor or return the 401 fail value, and the walk is the only
place a verdict is computed in the whole vehicle.

#diagram([two layers in wiring order: identity outside, the walk, the handler last], length: 13pt, {
  cdraw.rect((1.0, 6.6), (22.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.4), [the identity layer, installs an actor or nothing], size: 6.5pt)
  cdraw.content((11.5, 7.4), [bearer jwt or session cookie, one actor either way], size: 6pt)
  cdraw.rect((3.0, 3.8), (20.0, 6.2), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 5.6), [the policy walk], size: 6.5pt)
  cdraw.content((11.5, 4.6), [row per route pattern, 401 or 403 here, no row is loud], size: 6pt)
  cdraw.rect((6.4, 1.0), (16.6, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 2.8), [the handler], size: 6.5pt)
  cdraw.content((11.5, 1.9), [object checks live here, the store in reach], size: 6pt)
  cdraw.line((11.5, 6.3), (11.5, 3.5), stroke: luma(100), mark: (end: ">>"))
})

== the policy table

The whole surface is fifteen rows of data, method and pattern as the
key, three flags as the value, readable in one screen and greppable
in one search. Plain data beats a rules dsl or annotation mining at
this size because the audit test can walk it, a new route is a row
next to its siblings, and nothing about the table needs a second
parser:

#listing("lua/service/authz.lua", first: 42, last: 58, caption: [the contract's whole route surface as fifteen rows])

The flags read as demands. `auth` demands a resolved actor, `admin`
demands the admin role, `self_or_admin` accepts the object's owner
or an admin. The object routes carry the owner flag in the row, but
the check itself runs in the ladder the next section builds, because
ownership needs the record. Later chapters append rows for the
reports pair, and none ever edit an existing one, the same
append-only discipline the route table keeps.

#diagram([rows as data: one key, three flags, the walk reads them in order], length: 13pt, {
  cdraw.rect((0.8, 6.2), (21.8, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 7.9), [method space pattern], size: 6.5pt)
  cdraw.content((11.3, 6.9), [the key the router's dispatch installs on the request], size: 6pt)
  cdraw.rect((1.6, 3.2), (7.4, 5.8), fill: luma(222), radius: 0.02)
  cdraw.content((4.5, 5.0), [auth], size: 6.5pt)
  cdraw.content((4.5, 4.0), [an actor, else 401], size: 6pt)
  cdraw.rect((8.4, 3.2), (14.2, 5.8), fill: luma(222), radius: 0.02)
  cdraw.content((11.3, 5.0), [admin], size: 6.5pt)
  cdraw.content((11.3, 4.0), [the role, else 403], size: 6pt)
  cdraw.rect((15.2, 3.2), (21.0, 5.8), fill: luma(222), radius: 0.02)
  cdraw.content((18.1, 5.0), [self or admin], size: 6.5pt)
  cdraw.content((18.1, 4.0), [owner or admin, else 403], size: 6pt)
  cdraw.content((11.3, 1.9), [rows append, none ever edit], size: 6pt)
})

== the object routes and the id

Route rules cannot guard a route whose danger lives in the path
parameter. Reading `/api/users/` followed by someone else's id is
the IDOR class, and it survives every route-level check because the
route is the same for everyone. The check needs the record, which is
why the object routes run a ladder: the 401 before anything touches
the store, the store's 404 for an unknown id, then the walk asked
with the pattern and the fetched record's ownership:

#listing("lua/service/authz.lua", first: 127, last: 145, caption: [the ladder: 401, then the store's 404, then the walk's 403])

The walk is asked with the route's pattern, never the raw path, and
that distinction is the biggest catch of this whole part's review
history. The table keys on patterns, `GET /api/users/{id}` with
braces, while a request carries a concrete path with a real uuid in
it, so a walk fed the raw path answers `no_row` for every object
request and the owner check silently never runs, leaving any
authenticated actor free to touch any user. The router seam hands
the pattern over at dispatch, `req.pattern` installed beside the
params, so the ladder reads what the table is keyed by. The 404
before the 403 is a stated tradeoff: this service lets an
authenticated stranger distinguish an unknown id from a forbidden
one, and an api that prefers hiding existence answers 404 for both,
a policy choice the audit records either way.

#diagram([pattern in, verdict out: the raw path never reaches the table], length: 13pt, {
  cdraw.rect((0.8, 5.6), (9.0, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.7), [the request], size: 6.5pt)
  cdraw.content((4.9, 6.7), [concrete path,], size: 6pt)
  cdraw.content((4.9, 5.9), [an id in it], size: 6pt)
  cdraw.rect((10.2, 5.6), (15.4, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((12.8, 7.7), [dispatch], size: 6.5pt)
  cdraw.content((12.8, 6.7), [pattern plus,], size: 6pt)
  cdraw.content((12.8, 5.9), [params installed], size: 6pt)
  cdraw.rect((16.6, 5.6), (22.0, 8.4), fill: luma(205), radius: 0.02)
  cdraw.content((19.3, 7.7), [the walk], size: 6.5pt)
  cdraw.content((19.3, 6.7), [row found,], size: 6pt)
  cdraw.content((19.3, 5.9), [verdict out], size: 6pt)
  cdraw.line((9.2, 7.0), (10.0, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.6, 7.0), (16.4, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [a raw path fed to the table answers no row, the check never runs], size: 6pt)
  cdraw.content((11.5, 3.5), [the c lane's review catch, restated as this lane's test], size: 6pt)
})

== roles as data

Roles are rows, not magic. The closed set is two names, the grant
and revoke verbs live in the user store where the data lives, and
the one invariant that matters is never zero admins, enforced on the
post state of both verbs: the scan substitutes the candidate role
set for the stored one, and only a post state with some admin
standing persists, so a rejected demotion leaves no trace:

#listing("lua/service/users.lua", first: 366, last: 386, caption: [both verbs run the same guard on the post state])

The frozen vector walks the story at store level and through the
routes: demoting the only admin answers 409 conflict, last admin,
granting admin to a second user succeeds, and revoking that second
admin then succeeds too, because the first stands again. The
bootstrap rule makes the lockout unreachable in practice, the first
registration in an empty store holds admin, and the guard makes it
unreachable in theory. A plain user cannot self-grant admin for a
simpler reason: the roles routes' rows demand the admin flag, and
ownership of the target id means nothing there, the matrix section
pins that cell at 403.

#diagram([the grant table: the admin row must never empty, both verbs checked], length: 13pt, {
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
  cdraw.content((11.5, 1.6), [both verbs run the same guard, by construction], size: 6pt)
})

== deny by default and the audit

One table maps every registered route to its row, and the audit
faces the two against each other in both directions. A route without
a row cannot pass: the walk answers `no_row`, the guards treat it as
a wiring bug and answer the internal envelope, and the build itself
runs this audit over the real route table and refuses to start on a
mismatch, so the failure is loud at every layer. A row without a
route is dead, and the audit names it too, because a policy for a
route nobody registered is a lie about the surface:

#listing("lua/service/authz.lua", first: 98, last: 121, caption: [both directions: no row and no route are both named])

The closed decision surface is the deeper point. One function
computes every verdict in the vehicle, handlers ask it or run the
ladder that asks it, and no second decision path exists anywhere, so
there is exactly one place to audit, one place to test, and one
place a mistake can hide. The suite runs the audit against the
shipped route list and it answers clean, and it answers with named
problems the moment either side drifts.

#diagram([the audit faces the tables: both directions, both named], length: 13pt, {
  cdraw.rect((0.8, 5.4), (9.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.6), [the route table], size: 6.5pt)
  cdraw.content((4.9, 6.6), [what dispatch,], size: 6pt)
  cdraw.content((4.9, 5.8), [actually serves], size: 6pt)
  cdraw.rect((14.0, 5.4), (22.2, 8.2), fill: luma(222), radius: 0.02)
  cdraw.content((18.1, 7.6), [the policy table], size: 6.5pt)
  cdraw.content((18.1, 6.6), [what the walk,], size: 6pt)
  cdraw.content((18.1, 5.8), [will answer for], size: 6pt)
  cdraw.line((9.2, 7.1), (13.8, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 7.6), [every route carries a row], size: 6pt)
  cdraw.line((13.8, 6.1), (9.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.9), [every row matches a route], size: 6pt)
  cdraw.content((11.5, 3.9), [no row: the walk answers no row, loudly], size: 6pt)
  cdraw.content((11.5, 3.0), [one walk, one verdict site, one audit], size: 6pt)
})

== the matrix replay

The grid is the proof. Every route against every actor kind,
anonymous, owner, stranger, admin, one expected status per cell,
asserted through the walk itself, and the vector's last-admin chain
replayed through the real routes beside it:

#listing("lua/service/authz.lua", first: 303, last: 321, caption: [the grid: six routes, four actors, one status each])

Each cell fails with a name when it fails. The stranger column is
the IDOR discipline, 403 on every object verb whatever etag the
stranger presents, and the admin column on the roles rows is the
self-grant refusal, 403 for a plain user even on their own id. The
vector chain pins the store-level guard the same way, the 409 and
the two 200s around it arriving as frozen bytes through dispatch.
One stated divergence lives here: the frozen register vectors answer
without rate headers, so the replay harness attaches only the login
rule while the production root composes both, the bytes outranking
the prose for replay. Adding a route costs one policy row and one
matrix cell, and the audit plus the grid together answer the two
questions a reviewer actually asks: is every route covered, and does
every covered route behave for every kind of caller.

#diagram([routes one way, actors the other, statuses in the cells], length: 13pt, {
  let col(x, head) = cdraw.content((x, 8.8), head, size: 6pt)
  let cell(x, y, v, hot) = {
    cdraw.rect((x - 1.5, y - 0.5), (x + 1.5, y + 0.5),
      fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), v, size: 6pt)
  }
  col(6.2, [anon])
  col(10.4, [owner])
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
Sheet and Access Control Cheat Sheet, at cheatsheetseries.owasp.org,
for the IDOR class and the deny-by-default guidance. RFC 9110
sections 15.5.1 through 15.5.4 for the 401, 403, and 404 semantics.
lua.org manual 5.5 section 6.6 for table.sort's stable use as a
deterministic ordering over the policy keys, verified against the
tools/lua55 pin. The structural mirror is books/go/api/internal/
authz, and the pattern-not-path ruling follows the c lane's
books/c-os-cloud/api/src/authz_policy.c and its review history.
Accessed 2026-09-27. Verified by the service suite through `make
verify-lua`: authz 9 checks, the family replay 13, all green.
