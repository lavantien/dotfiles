#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= store

The service has run so far on in-memory maps, which tests love and
restarts hate. The earlier answer was a translated sqlite driver, the
module's one community dependency, and the dependency ruling retired
it: whatever the platform lacks gets built from the platform's own
primitives. This chapter owns the machinery outright. A write-ahead
log of CRC32C framed records, replay that recovers state and
tolerates a torn tail, transaction markers that make groups atomic,
snapshot compaction whose body carries an append-only version
list, and a hand-rolled database/sql driver, goapiwal, taught as the
bridge to the standard interface while the service paths call the
engine directly, a split the chapter states where it matters. Above
the engine sit the documented key scheme, keyset scans over sorted
keys, analytics aggregated in plain loops, and the isolation lessons
restated over locks the module built itself.

== database/sql from first principles

database/sql is a pool and a protocol. It is not itself a database:
a program opens a driver by name, gets a pool of connections it does
not schedule itself, and executes statements whose arguments are
values, never string concatenation. The surface an implementer owes
is small, driver.Driver handing out driver.Conn, each conn preparing
driver.Stmt values, and anything that satisfies that shape can sit
under sql.DB. The engine satisfies it through a driver registered
under the name goapiwal, sync.Once guarding the double registration
a second import could cause, and its DSN is a plain file path. The
driver's tests go through database/sql itself, sql.Open, prepared
statements, a BeginTx through both exits under the deferred
rollback, two pools on one engine.

The driver is the teaching bridge, and the split is stated plainly.
The service's store surfaces call the engine directly and skip
database/sql, because a pool adds nothing when the write side
already serializes and every conn would borrow the same
process-wide engine for the path. The driver exists because the
standard interface is the ecosystem's common tongue, and because
implementing it is the proof that the engine is a database by the
definition go programs use. Its statement set is fixed, four shapes
over the op vocabulary, and every argument is a value:

#snippet("// the whole dialect the driver speaks\n// \"GET ?\"      one key\n// \"PUT ? ?\"    key and value\n// \"DEL ?\"      one key\n// \"SCAN ? ?\"  range bounds", lang: "go")

#listing("go/api/internal/store/engine/driver.go", first: 103, last: 117, caption: [prepare recognizes the four op strings and nothing else parses]) // PIN: the fixed op set enforced at prepare

#diagram([the stack the store sits on: standard interface, owned engine, wal plus snapshot, no cgo], length: 13pt, {
  let stage(y, title, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.6, [handlers and stores], [#"user.Store, authn.SessionStore over the engine"], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.3, [database/sql + goapiwal], [the taught bridge, fixed dialect], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  stage(2.0, [the engine core], [map, sorted keys, write tx], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  stage(-0.3, [goapi.wal + snapshot], [framed appends, compaction], luma(245))
  pane(14.4, 22.6, 6.6, [the split], [service: engine direct,], [driver: taught, pinned])
})

== migrations test driven

Schema changes are code changes, so they ship as records, and the
history is append-only by contract: a shipped version is frozen, a
correction is a new numbered version, and no record is ever edited.
The registry is no longer a table the database keeps about itself.
It is the version list at the head of the snapshot body, and
appending a version is a compaction: the registry and the state it
describes land together in one snapshot file, written to a
temporary, fsynced, and renamed into place. Version records never
ride the WAL, they live only in the snapshot body, and the fsync the
commit path skips is spent here, at rotation. A snapshot that
arrives torn despite the fsync is not trusted: the open sequence
falls back to WAL-only recovery and the pre-compaction state is
gone, the one loss the design accepts and the torn-snapshot test
documents. Migrate applies each pending version at most once, so a
version that fails halfway leaves nothing durable and can be
retried: the in-memory registry takes the label only once the
snapshot holds it. There is no sql to embed anymore: the binary
carries its history as code and appends it to the store on
migration.

This wave ships three versions. The first marks the base key scheme,
users, grants, sessions with their refresh token history,
idempotency keys, events, reports, one record for the whole
vocabulary. The second marks the version field inside user values,
and stands as its own record because it is the substrate the next
chapter's optimistic concurrency stands on. The third marks the
idempotency header keys the concurrency chapter fills. Each
demonstrates the same discipline on its own day: a new fact is a new
record. The test drives the runner from an empty directory, proves
all three records applied in order, re-runs, and proves nothing
applies twice, then closes and reopens the store to prove the
registry came back with it.

#listing("go/api/internal/store/store.go", first: 55, last: 71, caption: [one version, one compaction, one append to the record list, applied at most once]) // PIN: migrate appends pending labels via AppendVersion

#diagram([the version list only grows right], length: 13pt, {
  cdraw.line((0.6, 4.4), (22.0, 4.4), stroke: luma(140))
  cdraw.content((11.3, 5.4), [open time], size: 6.5pt)
  let tick(x, label, l1, hot) = {
    cdraw.line((x, 4.7), (x, 4.1), stroke: luma(100))
    cdraw.rect((x - 3.2, 1.6), (x + 3.2, 4.0), fill: hot, radius: 0.02)
    cdraw.content((x, 3.3), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#l1], size: 6pt)
  }
  tick(4.0, [version 1], [base key scheme], luma(235))
  tick(11.3, [version 2], [version field], luma(235))
  tick(18.6, [version 3], [idempotency keys], luma(235))
  cdraw.content((11.3, 0.7), [version records at the head of the snapshot body, one per version, forever], size: 6pt)
})

== queries with context every time

Every method takes a context, because the ports froze that shape and
the request's own context is what every handler passes down. What
the engine does with it is stated in the code, and the statement is
the design: nothing. The surface accepts the context and hands it to
the callback, and its own steps go without, the comment at the
wrapper naming the trade, the engine has no cancellation point,
transactions run short, and open says the same about recovery,
synchronous and uncancellable by design. A dead context therefore
never tears a frame mid-write, because there is no interruption
point to cancel, and the work a canceled request started still
lands, bounded by how short every transaction is kept. The timeout
middleware keeps the other half of the bargain, stopping the
response path while the store finishes a step that was always going
to be quick.

The adapters implement the two ports the earlier chapters froze,
user Store and authn SessionStore, error for error, so no handler
can tell the engine from the in-memory maps the tests grew up on.
A read runs inside a read tx: take the read lock, clone the key
space into an immutable snapshot, release the lock, then every
lookup is a map hit on a key the scheme names and a decode of
deterministic json/v2 bytes into a domain value that carries no
engine types. The clone is the stated price of the design: the
engine copies the map and the sorted key slice per read, shares the
value slices because puts replace and never mutate them, and at
book scale, a map of a few hundred entries cloned per read, that is
cheap enough to keep the engine plain. The scheme is documentation
the keys enforce, user records under u:id: with the created_at
inside as sign-flipped fixed-width hex milliseconds beside the id, a
u:byid: index beside the u:email: uniqueness claim, grants under
r:grant:, sessions under s:id: with their whole token history under
t:hash:, events under e: with day and id inside the key so day order
is key order, idempotency and report rows under idem: and rep:. The
fixed-width pair inside the key is exactly the (created_at, id) pair
the pagination cursor carries, so storage and keyset order share one
notion of position. The one translation the contract cares about
survives as an explicit existence check: the email key already taken
maps to ErrConflict and nothing else, because that is the only
store error a client ever caused.

#listing("go/api/internal/store/engine_user.go", first: 186, last: 204, caption: [a read through the store surface: ctx in, one snapshot, key lookup, decode, roles]) // PIN: read path over the captured view

#diagram([one read's path from caller to view to domain value], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.3), (x0 + 5.0, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 5.9), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 4.9), [#l1], size: 6pt)
  }
  step(0.3, [caller's ctx], [deadline, cancel])
  cdraw.line((5.5, 5.4), (5.9, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [read tx], [lock, clone the view, unlock])
  cdraw.line((11.1, 5.4), (11.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [key lookup], [#"u:byid:" + id, then the record])
  cdraw.line((16.7, 5.4), (17.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [user.User], [json/v2 decode, no engine types])
  cdraw.content((8.7, 3.4), [no interruption point: a dead ctx tears nothing], size: 6pt)
  cdraw.content((8.7, 2.3), [the cloned view outlives the lock by design], size: 6pt)
  cdraw.content((8.7, 1.2), [email taken maps to ErrConflict, the rest surface raw], size: 6pt)
})

== the transaction idiom

One shape covers every write in the module: take the transaction,
run, commit, and let the error exit discard. The engine's write tx
gives the shape new bones. The write side takes the full lock, so
exactly one writer holds the group at a time, and the function's ops
accumulate into a pending group memory has never seen. Commit is
append then mutate: the group's frames, the begin marker, the ops,
the commit marker, are encoded into one buffer and written in one
call, and only then does memory take the group's puts and deletes.
The write reaches the OS but is not fsynced, the line sqlite's
synchronous NORMAL draws, durable across application crashes,
relaxed about power loss, with Sync as the operator's stronger call.
Discard is the rollback: the wrapper defers it, so fn's error and a
panic unwinding through both roll back, and after commit the same
call is a no-op, the idiom the sqlite era taught, with nothing left
to undo because nothing was appended until commit. The suite proves
the unwind path with a test that fires a panicking fn and then
writes again, a leaked lock would hang it forever. The engine has
no cancellation point that could add a third exit, ctx is discarded
on purpose, and every fn the module writes is short, straight-line
staging over the locked engine.

The order is the guarantee. Frames first, memory second, means the
log is always at least as current as memory, so a crash between the
append and the mutation recovers to the committed state, and the
inverse order would leave memory holding a state the log cannot
rebuild, the exact failure recovery exists to prevent. The store
wraps the shape twice, WithTx over the write tx and WithReadTx over
the read view, and the session store's Rotate is still the hardest
caller: on a superseded or revoked presentation the family
revocation commits even though Rotate answers with an error, the
revocation runs inside the write tx and the error is returned after
it, so the family cannot be rolled back to life. The plain read
keeps the older discipline: GetByRefresh answers a superseded hash
exactly as an unknown one, ErrUnknownRefresh, because which of the
two it is only matters to Rotate, which reacts by revoking.

#listing("go/api/internal/store/engine/engine.go", first: 170, last: 192, caption: [the commit order: the group's frames append in one write, then memory mutates]) // PIN: write tx append-then-mutate

#diagram([a transaction's exits, every one of them clean], length: 13pt, {
  cdraw.rect((0.4, 5.4), (6.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.6), [write tx, full lock], size: 6pt)
  cdraw.content((3.3, 5.8), [ops gather in the group], size: 6pt)
  cdraw.line((3.3, 5.3), (3.3, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 3.0), (6.2, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [run fn(ctx, tx)], size: 6pt)
  cdraw.content((3.3, 3.3), [puts, deletes, checks], size: 6pt)
  pane(8.6, 14.6, 4.5, [fn returns nil], [frames append in one write], [then memory takes the group])
  cdraw.line((6.4, 3.7), (8.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(15.8, 21.8, 4.5, [fn returns an error], [group never written], [memory never held it])
  cdraw.line((14.8, 3.7), (15.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.3, 1.9), [the deferred rollback covers the error and panic exits], size: 6pt)
  cdraw.content((3.3, 0.8), [the log stays at least as current as memory], size: 6pt)
})

== isolation levels and what the engine actually gives you

The textbook menu, read uncommitted through serializable, is a menu
of guarantees a general engine picks among, and none of its items
is what this engine serves. A read tx clones the key space under the
read lock and keeps the clone for its whole life. No dirty reads,
because memory only mutates after the group is logged and a
reader's view is a state that was committed. No non-repeatable
reads within one transaction, because the view never moves. Write
skew stays possible under the weak discipline, reading a snapshot
outside the write tx and committing after: two serialized writers
can act on disjoint stale reads, each commit clean, the combined
fact wrong. Writers serialize, one at a time, on the full lock.
That is snapshot isolation, and this module built it, so the
boundary is a fact about its own locks stated where the code states
it, with no configuration file standing between the claim and the
mechanism.

The demo stays deterministic and single threaded, which is the
whole trick. The reader opens a read tx and reads version 1,
capturing its view. A second writer commits version 2. The reader
reads again inside its tx and still sees 1, and a fresh read
outside sees 2. No goroutine, no barrier, no sleep, the interleave
is the test's own statement order, so the demonstration cannot
flake:

#listing("go/api/internal/store/engine/engine_test.go", first: 116, last: 135, caption: [pin a view, commit past it, read again: the interleave is the statement order]) // PIN: snapshot pin demo

#diagram([one timeline: the reader's view holds], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  cdraw.content((11.5, 6.9), [reader tx], size: 6.5pt)
  cdraw.line((2.0, 6.3), (6.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.2, 5.6), [open, first read], size: 6pt)
  cdraw.line((6.4, 6.3), (16.2, 6.3), stroke: luma(80))
  cdraw.content((11.3, 5.6), [view pinned at version 1], size: 6pt)
  cdraw.line((16.2, 6.3), (21.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.8, 5.6), [second read: still 1], size: 6pt)
  cdraw.content((11.5, 3.9), [writer], size: 6.5pt)
  cdraw.line((9.6, 3.3), (14.6, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.1, 2.6), [commits version 2], size: 6pt)
  cdraw.line((14.6, 3.3), (14.6, 1.2), stroke: luma(120), mark: (end: ">>"))
  cdraw.content((12.1, 1.4), [fresh read outside sees 2], size: 6pt)
  pane(16.9, 22.4, 3.3, [what it is], [snapshot isolation,], [not full serializability])
})

== the lost update demo and the CAS answer

Two writers read the same user, both compute, both write, and one
update silently vanishes. The engine reproduces it with two blind
writes: both succeed, the second name is all that survives, and the
version field never moved, so nothing anywhere records that anything
was lost. Serialization does not fix this, and owning the machinery
makes the reason visible: the full lock guarantees each write lands
whole, and says nothing about the stale read the write was computed
from, so the serialized blind writers merely lose the update in a
tidy order. That invisibility is what makes the lost update the
classic concurrency bug, the writer that caused it gets a success
answer.

The version field is the detector and compare-and-swap is the fix,
the strong discipline in the engine's vocabulary. The whole
exchange, read the current value under the write lock, refuse
anything but the expected version, bump and write, runs inside one
write tx, so no second writer can slip between the read and the
write, and the lock holding the window shut is the same lock the
blind demo ran under, the difference is entirely the check. A
mismatch answers ErrVersion. Of two racers holding version 1 exactly
one wins, and the loser gets ErrVersion, a fact it must handle,
which over http is exactly the 412 the next chapter's ETag duel
stages with two released PATCHers:

#listing("go/api/internal/store/engine_user.go", first: 261, last: 284, caption: [the CAS: check and bump share one write tx, one winner]) // PIN: CAS inside one write tx

#diagram([same race, two outcomes: silent loss versus a refused writer], length: 13pt, {
  pane(0.3, 10.6, 7.4, [before, blind writes], [both read name, version 1], [both write, both succeed], [one write vanished])
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.4, [after, the CAS], [both read version 1], [one commits version 2], [loser answers ErrVersion])
  cdraw.content((5.4, 2.6), [version never moves, loss invisible], size: 6pt)
  cdraw.content((17.0, 2.6), [version bumps, the loss is a 412], size: 6pt)
  cdraw.content((11.3, 0.9), [the full write lock holds the window shut, the check is the fix], size: 6pt)
})

== the analytics query as an in-Go walk

Reports were sql's home turf, and window functions kept them one
query. Owning the store means owning the iteration too, so the
report is now a walk over the events range, and the invariants the
windows encoded are loops with names. The scan reads the e: prefix
in day order inside one read tx, so one report always reads one
snapshot of the events keys, never a torn view of an insert in
flight. Presence collapses events to one entry per user per day,
because actives count users, not actions. A user's first day inside
the window is the newcomer, which is what ROW_NUMBER's nth = 1 used
to mark. The delta is today's active minus yesterday's, the first
day 0, LAG's arithmetic without the self-join. Leaders rank by
count descending then user id ascending, a total order, so a
replayed report cannot differ run to run.

The report routes keep their shape over the walk. Create validates
the window, hashes the exact request bytes, and answers 202 pending
or replays an earlier submission of the same key, refusing the same
key under different bytes with 422 and details, the replay check
running inside the write tx that stores the row. Get computes the
series on first read, flips the row to done, and answers the frozen
golden body, which is why the replay in the contract's reports pair
upgrades to 200 with identical bytes.

#listing("go/api/internal/analytics/analytics.go", first: 37, last: 57, caption: [the walk: the e: range scan in day order, each event one (day, user) presence]) // PIN: in-Go aggregation walk

#diagram([keys to walk to the report body], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.4, [events keys], [one row per action])
  cdraw.line((4.9, 5.1), (5.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.8, [range scan], [e: prefix, day order])
  cdraw.line((10.3, 5.1), (10.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.2, [the walk], [presence, first day, delta])
  cdraw.line((16.1, 5.1), (16.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.5, 5.8, [report body], [actives, new, delta])
  cdraw.content((9.0, 2.7), [all inside one read tx, one snapshot], size: 6pt)
  cdraw.content((9.0, 1.6), [leaders: count desc, then user id asc, replay stable], size: 6pt)
})

== store tests without docker

Every test in the package starts the same way: open an engine in a
fresh temp directory, which loads the snapshot if one survived and
replays the WAL over it, migrate it, run, close. No container, no
shared server, no ordering between tests, and nothing in the
package sleeps, because the file facts the engine adds are
deterministic by construction: corruption flips every byte of the
log one at a time, truncation cuts at every length, and a torn tail
is geometry, not timing. The walk that reads a log stops at the
first frame that does not hold: a remaining tail shorter than the
eight-byte header ends it, a payload under two bytes is refused,
the version byte and the op byte being the floor, and a length that
overruns, a checksum that lies, or a payload this build cannot
parse stop it the same way.

The recovery property rides a fuzz target, FuzzWALReplayPrefix,
whose invariant is named in prose: for any framed log and any
truncation of it, replaying the decodable prefix answers exactly
the state of the ops whose transactions committed inside that
prefix. Its seeds, among them a multi transaction log, a torn
mid-frame tail, and a frame whose checksum lies, run as plain table
cases under go test, and the mutation engine stays in the opt-in
lane, the suite chapter's discipline applied to recovery. The
concurrency tests, the readers racing a writer, meet on channels,
and the CAS duel and the snapshot demo need no goroutine at all
because the statement order is the schedule. The clock stays
injected, the analytics fixture seeds exactly the three events the
frozen vector's setup names, and the golden report body the tests
assert is the contract's own bytes:

#listing("go/api/internal/store/store_test.go", first: 19, last: 39, caption: [the whole test story: a temp dir, an open that recovers, a migrate, per test]) // PIN: test lifecycle temp dir + open + migrate

#diagram([a store test's lifecycle, nothing shared between runs], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [TempDir], [fresh directory])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [Open + Migrate], [snapshot, wal replay, versions])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [seed, act, assert], [fixed clock, golden bytes])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [Close], [os removes the dir])
  cdraw.content((9.4, 3.5), [no container, no port, no sleep], size: 6pt)
  cdraw.content((9.4, 2.4), [40 test functions, race detector on], size: 6pt)
  cdraw.content((9.4, 1.3), [the fuzz seeds ride the plain gate], size: 6pt)
})

sources: pkg.go.dev for hash/crc32, database/sql, database/sql/driver,
os, and testing, accessed 2026-09-26, the Castagnoli polynomial and
MakeTable construction read from the hash/crc32 documentation, the
Rename replace semantics read from the os documentation, and the
driver surface, Driver, Conn, Stmt, and the sql.DB pooling contract,
read from the database/sql and database/sql/driver pages. Verified
by `go/api/internal/store`, `go/api/internal/store/engine`, and
`go/api/internal/analytics` tests, 40 of them, with
FuzzWALReplayPrefix's seeds riding the same plain `go test`, and
the module gates: go vet, go test, and the race detector pass over
the whole goapi module in `make verify-go`.
