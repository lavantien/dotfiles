#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the store

The service has run on tables in memory, which tests love and restarts
hate. The platform ruling gives this lane a different answer than the
other books took: the logic half stays pure lua 5.5, and the store
rides the jit lane built in chapter 17, sqlite 3.53.4 through the
book's own ffi wrapper against the mingw dll. No driver is
translated, no engine is rebuilt, and no community dependency enters
the graph, because the wrapper already exists as book content and the
engine arrives as a pinned binary. What this chapter owns is the
surface the service codes against: users, roles, sessions with their
refresh history, events, and the analytics reports, every statement
parameterized, every write group one `BEGIN IMMEDIATE` transaction,
and every verdict read from a row.

The lane boundary is stated where it lives. The plain 5.5 interpreter
has no ffi library, so `store.lua` never enters the plain runner's
table: its suite rides `run-jit.lua` and the `verify-lua-jit` gate
runs it green, a boundary the suite chapter owns, not a skip.

== the ffi lane to the pinned engine

The wrapper is chapter 17's own `books/lua/jit/sqlite.lua`, reused
without duplication. It pins the dll by `arg[0]` depth and asserts
the engine version at require time, and the service tree sits at the
same depth the wrapper was built for, so the same line resolves from
here. The wrapper's surface is deliberately small: `open`, `exec`,
`rows`, `close`, and the statement methods behind `rows`. What the
store needs beyond that surface it composes over the wrapper's own
contract rather than editing frozen book content.

That contract has a sharp edge the store's first red run found twice.
The `rows` iterator finalizes its statement exactly when it observes
a non-row step. A caller that abandons the iterator early leaks an
unfinalized statement, and the close then refuses with `unable to
close due to unfinalized statements`. A caller that resumes the
iterator after the `nil` steps a handle sqlite already freed, and the
process dies with a segmentation fault, no error message anywhere.
Both exits sit one call apart, and the discipline that avoids both is
the same: run every iterator exactly to its first `nil`:

#listing("lua/service/store.lua", first: 130, last: 143, caption: [first takes the leading row, then steps to the nil that finalizes])

`first` answers the leading row of a query and, only when there was
one, keeps stepping to the `nil` that finalizes. `run` executes a
write, whose single step observes `done` and finalizes on the spot.
Every read and write in the module goes through one of the two, and
the one place the walk needs an early exit, the list's `has_more`
probe, drives its iterator by hand for exactly this reason: a
`return` inside a generic `for` breaks the loop before the finalizing
step.

#diagram([the lane the store rides, and the one it never crosses], length: 13pt, {
  let stage(y, title, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.6, [the handlers], [users, authn, authz over plain tables], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.3, [store.lua], [the seam this chapter owns], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  stage(2.0, [the ch17 wrapper], [open, exec, rows, close], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  stage(-0.3, [sqlite3.dll 3.53.4], [pinned at require, mingw build], luma(245))
  pane(14.4, 22.6, 6.6, [the boundary], [plain 5.5 has no ffi,], [jit lane owns the suite])
})

== migrations as append-only records

Schema changes are code changes, so they ship as records. The
registry is the `PRAGMA user_version` integer the database keeps
about itself, each record is a numbered entry in a lua table, and the
history is append-only by contract: a shipped version is frozen, a
correction is a new numbered version, and no record is ever edited.
Two records ship with the store. The first is the whole base
vocabulary, users with their email uniqueness index, roles as the one
many-to-many edge, sessions with their refresh token history, events
as one presence row per user per day, and reports with their body
claim. The second is the optimistic currency substrate, the `version`
column the guarded update checks and bumps, and the keyset index in
the exact order the list walk sorts on.

Each record applies inside its own `BEGIN IMMEDIATE` group with the
version bump in the same group, so a record that fails halfway leaves
nothing durable and can simply be retried. A pragma value cannot be
bound, the one formatted integer in the module, and it is the
module's own loop counter rather than caller data. The reopen test
pins the ladder end to end: a file that closes at version 2 reopens
at version 2, asserted on the pragma itself, and applies nothing
again.

#listing("lua/service/store.lua", first: 163, last: 173, caption: [one record, one group, one bump, applied at most once])

#diagram([the version ladder only grows right], length: 13pt, {
  cdraw.line((0.6, 4.4), (22.0, 4.4), stroke: luma(140))
  cdraw.content((11.3, 5.4), [open time], size: 6.5pt)
  let tick(x, label, l1) = {
    cdraw.line((x, 4.7), (x, 4.1), stroke: luma(100))
    cdraw.rect((x - 3.2, 1.6), (x + 3.2, 4.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, 3.3), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#l1], size: 6pt)
  }
  tick(4.0, [version 1], [the base vocabulary])
  tick(11.3, [version 2], [version column, keyset index])
  tick(18.6, [a correction], [a new record, never an edit])
  cdraw.content((11.3, 0.7), [PRAGMA user_version, one begin immediate group per record], size: 6pt)
})

== the register transaction

Registration is the one write that decides two facts, a user exists
and that user's roles, and the two must land together or not at all.
The whole exchange runs inside one `BEGIN IMMEDIATE` group: the email
claim, the insert, the bootstrap admin decision, and both grants.
`BEGIN IMMEDIATE` takes the write lock up front, so two first
registrations serialize at the lock and exactly one of them ever sees
an empty admin count, the count-then-insert race closed by
construction rather than by luck. The count reads the roles table
before this row's grants land, so a store with no admin crowns the
row and a store with one does not, and the granted set rides home in
the same committed fact that answers 201.

The email verdict is a select inside the group. A read decides, the
unique index behind it is the invariant's seat, and the test that
inserts a duplicate past the checked path still trips the index,
because the schema, not the read, owns the claim. The failed group
returns a sentinel, `nil, "conflict"`, that the handler maps to the
409 the contract freezes, and the rollback test stages a row mid
group and proves the exit discards it whole.

#listing("lua/service/store.lua", first: 190, last: 210, caption: [one group: claim, insert, count, grant, commit])

#diagram([the register group, one fence around four facts], length: 13pt, {
  cdraw.rect((0.8, 1.6), (14.2, 7.2), fill: luma(225), radius: 0.02)
  cdraw.content((7.5, 6.7), [BEGIN IMMEDIATE, the write lock up front], size: 6pt)
  let step(x, y, w, l1) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(245), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.4), [#l1], size: 6pt)
  }
  step(1.4, 4.6, 3.0, [email claim])
  step(4.9, 4.6, 3.0, [the insert])
  step(8.4, 4.6, 3.0, [admin count])
  step(11.9, 4.6, 1.9, [grants])
  cdraw.line((4.4, 5.1), (4.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((7.9, 5.1), (8.2, 5.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.4, 5.1), (11.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(1.4, 2.4, 3.0, [COMMIT])
  step(5.4, 2.4, 3.0, [or ROLLBACK])
  cdraw.content((3.0, 1.1), [all four facts, or none], size: 6pt)
  cdraw.content((8.6, 3.0), [the count reads roles,], size: 6pt)
  cdraw.content((8.6, 2.4), [before this row's grants land], size: 6pt)
  pane(15.4, 22.4, 5.4, [the races closed], [two first registers,], [one lock, one admin])
})

== guarded statements that keep an admin

The contract's never-zero-admins invariant rides the statement's own
predicate, so the count and the write cannot be raced apart even in
principle. A grant passes when the granted role is admin, the post
state keeps an admin by construction, or an admin already stands. A
revoke passes when the row is not an admin row, or another user holds
admin and survives the delete. Both are single statements, `INSERT OR
IGNORE ... SELECT` and `DELETE ... AND` a guard subquery, and a
refused statement touches nothing, so a rejected change leaves no
trace.

The verdict then reads the row itself. Standing after the grant means
the guard refused it, gone after the revoke means it landed or never
existed, and both are the caller's ok. Row existence is the
discriminator for a reason the wrapper makes plain: a change count
belongs to the connection rather than to the statement, and this
wrapper does not even surface one, so the row is the only honest
witness. A revoke of a role nobody holds is an idempotent no-op, and
the last admin revoke answers the sentinel the handler renders as the
409 the contract freezes.

#listing("lua/service/store.lua", first: 276, last: 292, caption: [the guarded pair, then the row itself decides])

#diagram([two guards, one verdict], length: 13pt, {
  pane(0.4, 10.6, 7.4, [the grant], ["INSERT OR IGNORE ... SELECT", "WHERE admin OR EXISTS(admin)"], [refused touches nothing])
  pane(11.8, 22.3, 7.4, [the revoke], ["DELETE ... WHERE role<>'admin'", "OR EXISTS(another admin)"], [the last admin stands])
  cdraw.line((10.8, 4.6), (11.6, 4.6), stroke: luma(100), mark: (end: ">>"))
  pane(4.8, 17.9, 2.4, [the verdict], ["SELECT 1 WHERE the row lives", "standing: refused, gone: ok"])
  cdraw.line((5.5, 7.0), (5.5, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((17.0, 7.0), (17.0, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.3, 1.2), [row existence, never a change count the connection shares], size: 6pt)
})

== reads, the keyset walk, the version guard

Reads are one statement each, by id, by email, the roles of a user,
and all of them through `first`. The list is the one read with
mechanics worth their own section. The cursor the contract defines is
the `(created_at, id)` pair, and the walk compares it as a sqlite row
value, `(created_ms,id) > (?1,?2)`, one comparison that covers the
first page, whose floor is the smallest time with an empty id, and
every continuation. The fetch asks for `limit+1` rows, and the extra
row is only the `has_more` observation: the answer carries the items
and the cursor of the last returned item, or no cursor when the walk
saw nothing beyond.

The walk drives its iterator by hand because its early exit is the
exact shape the generic `for` cannot express safely here: the moment
the extra row arrives, the walk has its answer, and breaking the loop
then would leak the statement. The version guard is the write side
of the same currency. `user_patch_cas` reads the row, refuses a
missing row as `not_found` and a stale version as `version`, then
runs the guarded update whose where clause still carries the version
check, the seat the invariant keeps on any host that ever threads
this code, because in this vm one instruction stream means nothing
can move the row between the read and the write at all.

#listing("lua/service/store.lua", first: 225, last: 246, caption: [the walk: row-value floor, limit+1 probe, a hand-driven iterator])

#diagram([pages chained by the same pair the sort uses], length: 13pt, {
  let page(x0, l1, l2) = {
    cdraw.rect((x0, 4.2), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.8), [#l1], size: 6pt)
    cdraw.content((x0 + 2.6, 4.8), [#l2], size: 6pt)
  }
  page(0.3, [page one], [(created_ms,id) > floor])
  cdraw.line((5.7, 5.4), (6.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  page(6.3, [the cursor], [last item's pair, base64url])
  cdraw.line((11.7, 5.4), (12.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  page(12.3, [page two], [limit+1 asked, extra row only says more])
  cdraw.content((8.9, 3.2), [one row-value comparison, first page and every continuation], size: 6pt)
  cdraw.content((8.9, 2.1), [ties break by id, the sort and the cursor share one order], size: 6pt)
  cdraw.content((8.9, 1.0), [the version guard reads, checks, then writes guarded], size: 6pt)
})

== the analytics report as committed queries

The report is where sql earns its seat back. Presence collapses
events to one row per user per day because actives count users, not
actions, and the primary key absorbs the duplicate write. The series
is one committed query: `ROW_NUMBER` over each user's days in day
order marks the first day in the window, the newcomer, daily counts
aggregate the marks, and `LAG` carries yesterday's count with today's
as its default so the first delta is zero, window functions doing in
one statement what the pre-store engines of the other books walked in
loops. Leaders rank by day count descending then user id ascending,
`RANK` over a total order, so a replayed report cannot differ run to
run.

The compute and the done flip share one write group, so a reader
never sees a done report with no computed rows behind it. The store
surface keeps the contract's shape: create stores a pending row, the
first read computes and flips, and a replay recomputes the same
deterministic series, which is why the reports pair in the frozen
vectors upgrades a replayed 202 to a 200 with identical bytes. The
seeded test walks the vector's fixture, three events over two days
and two users plus one duplicate write that presence absorbs, and
asserts the series rows the frozen body carries.

#listing("lua/service/store.lua", first: 356, last: 373, caption: [the series, the leaders, and the flip, one committed group])

#diagram([events to series, one committed walk], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.2, [events], [one row per user per day])
  cdraw.line((4.7, 5.1), (5.1, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.6, [row_number], [the first day is the newcomer])
  cdraw.line((10.1, 5.1), (10.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.0, [lag], [yesterday as the default, delta 0])
  cdraw.line((15.9, 5.1), (16.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.5, 5.8, [rank], [count desc, id asc])
  cdraw.content((8.9, 2.7), [the done flip rides the same group], size: 6pt)
  cdraw.content((8.9, 1.6), [replay recomputes the same series, hence the 200 upgrade], size: 6pt)
})

sources: sqlite.org for the statement lifecycle (c3ref/prepare.html,
c3ref/step.html, c3ref/finalize.html, c3ref/close.html), the
transaction semantics (lang_transaction.html, BEGIN IMMEDIATE takes
the reserved lock before the first read), the versioned schema
(`pragma.html` carrying `PRAGMA user_version`), row values
(rowvalue.html, the
pair comparison the cursor and the keyset index share), the upsert
clause (lang_conflict.html, `INSERT OR IGNORE` and `ON CONFLICT DO
NOTHING`), and the window functions (windowfunctions.html,
`ROW_NUMBER`, `LAG`, `RANK`), all accessed 2026-09-27, the luajit ffi
semantics from luajit.org/ext_ffi_semantics.html accessed 2026-09-27,
and the wrapper contract from this book's own chapter 17. Verified by
the jit store suite at `books/lua/service/store_jit.lua`, 18 checks
including the reopen ladder, the duplicate email, the last admin, the
keyset walk, the rotation family, and the report pair shape, run
green by `make verify-lua-jit` from the repo root.
