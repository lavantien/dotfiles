#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= concurrency control

The store chapter's guard gave one writer the win and the other a
refusal. This chapter moves that fact to the edge and builds around
it: the etag preconditions as two pure decisions, the duel two
released patchers stage over the guard, idempotency keys with their
24 hour snapshots, the in-flight window closed by a table,
singleflight rebuilt from the ch15 primitives over the ch16 atomics,
and the bounded fan-out whose first error latches while the queued
rest stop early.

== the lost update prevented

Two clients read the same user, both patch, and without protection
one write silently vanishes. The stack answers in layers. The
decision layer refuses fast: an If-Match that is missing or stale
against the current representation answers 412 before the handler
burns its decode, and the contract chose 412 over the 428 the RFC
suggests, so missing and stale refuse alike. The atomic layer is the
store's guarded update from the previous chapter, the check, the
bump, and the write in one statement, the only layer nobody can slip
between. Fast fail, then the invariant, in that order.

The duel stages the whole chain with no scheduler luck anywhere. Both
patchers read the user and hold version 1, both arrive at a gate and
park on one event, the test closes the gate once both have arrived,
and both race into the same guarded update. Exactly one 200 and one
412 every run, version 2 standing after, because the outcome is a
fact about the where clause, not about the interleaving:

#listing("c-os-cloud/api/tests/test_conc.c", first: 317, last: 329, caption: [the duel: read version 1, park at the gate, race the guard, one winner]) // PIN: duel racer

#diagram([two patchers, one gate, one winner], length: 13pt, {
  cdraw.content((2.6, 7.4), [writer A], size: 6.5pt)
  cdraw.content((12.4, 7.4), [writer B], size: 6.5pt)
  cdraw.line((0.6, 6.6), (4.6, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((2.6, 5.9), [#"If-Match: v1"], size: 6pt)
  cdraw.line((10.4, 6.6), (14.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.4, 5.9), [#"If-Match: v1"], size: 6pt)
  cdraw.rect((5.6, 6.1), (9.4, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((7.5, 6.8), [the gate], size: 6pt)
  cdraw.content((7.5, 6.3), [one close, both go], size: 6pt)
  cdraw.line((4.8, 5.6), (4.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.2, 5.6), (10.2, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.0, 3.0), (12.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.5, 4.1), [the guarded update, one statement], size: 6pt)
  cdraw.content((7.5, 3.4), [version check and bump in the where and set], size: 6pt)
  pane(14.6, 21.6, 4.6, [one 200], [version 2], [the new etag])
  pane(14.6, 21.6, 1.4, [one 412], [zero changes], [retry from v2])
})

== if-none-match and 304

The read side of the same coin costs nothing when nothing changed. A
GET carrying an If-None-Match that matches the current representation
answers 304 Not Modified with an empty body, and the client, which
already holds the body the etag names, keeps it. The decision is four
facts in order: no header means an ordinary read, no current
representation means an ordinary read because there is nothing to
compare, the star matches any current representation, and only the
exact quoted string answers 304. The strong etag this service issues
is the quoted sha256 of the exact response body, compared whole and
never parsed, and a weak validator never appears on these
representations, so a w/ prefix is simply a non-match. One
composition cost rides the placement: the conditional read answers
before any authorization walk, this lane keeping the verdict inside
the handler and the go lane composing its wrapper outside the authz
guard the same way, so a caller who cannot read the row but once held
its etag still learns whether the representation changed, a 304
confirming their copy is current and a 200 revealing it moved. The
leak is a version oracle over a copy the caller held at some point,
never a body disclosure, and closing it would mean checking standing
before the revalidation, a deliberate divergence this lane records
rather than takes.

#listing("c-os-cloud/api/src/idem_cond.c", first: 11, last: 28, caption: [the two decisions: whole-string compares, one wildcard, no parser]) // PIN: cond decisions

#diagram([the conditional read decision], length: 13pt, {
  let step(y, q, yes, no) = {
    cdraw.content((6.0, y), [#q], size: 6pt)
    cdraw.content((2.8, y - 0.6), [#"no: " + no], size: 6pt)
    cdraw.content((9.8, y - 0.6), [#"yes: " + yes], size: 6pt)
  }
  step(7.0, [header present?], [], [ordinary read])
  cdraw.line((6.0, 6.6), (6.0, 5.9), stroke: luma(100), mark: (end: ">>"))
  step(5.6, [representation exists?], [], [ordinary read])
  cdraw.line((6.0, 5.2), (6.0, 4.5), stroke: luma(100), mark: (end: ">>"))
  step(4.2, [#"header = etag or *?"], [fresh read, 200], [])
  cdraw.line((6.0, 3.8), (6.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  pane(2.2, 9.8, 3.0, [304], [etag stamped,], [empty body])
  cdraw.content((13.5, 4.2), [a 304 with a body would poison the client], size: 6pt)
  cdraw.content((13.5, 3.1), [the same compare serves if-match], size: 6pt)
})

== idempotency keys and the 24 hour snapshot

A client that times out retries, and a register route that recreates
on retry is a double-charge machine. The contract's answer is the
Idempotency-Key header, scoped by route and caller identity so two
clients may share a key freely, with the exact request bytes' sha256
stored beside it, because whitespace drift is a different request.
The first successful run becomes a snapshot row, status, content
type, body, stamped with a 24 hour expiry, and a later request with
the same key and hash replays those bytes at the stored status, the
retried register returning its original 201 byte for byte.

Two deliberate refusals shape the table. The same key under a
different hash is a mismatch the caller answers as the 422, the
client is misusing the contract, and the stored snapshot is
untouched. And save refuses any status of 400 or more, because a
retry after a validation error deserves a fresh run, not a replayed
failure, so only outcomes under 400 ever become snapshots. Expiry is
lazy on read: a row past its 24 hours answers miss and deletes
itself on contact, so correctness never waits for a sweep, and the
delete carries the expiry in its own predicate so a save that
refreshes the row between the read and the delete survives, the same
one-statement serialization the store's cas update owns.

#listing("c-os-cloud/api/src/idem_store.c", first: 28, last: 50, caption: [the save: failing statuses refused at the door, everything else bound into one row]) // PIN: idem save

#diagram([one key's life: first run, snapshot, replay, expiry], length: 13pt, {
  let node(x, y, title, l1) = {
    cdraw.rect((x - 2.4, y - 1.0), (x + 2.4, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.45), [#title], size: 6pt)
    cdraw.content((x, y - 0.45), [#l1], size: 6pt)
  }
  node(2.8, 5.8, [first request], [#"key k, hash h"])
  cdraw.line((5.2, 5.8), (7.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 5.8, [run the handler], [#"201 under 400" ])
  cdraw.line((12.0, 5.8), (14.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 5.8, [snapshot row], [#"expires now + 24 h"])
  cdraw.line((2.8, 4.6), (2.8, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.2, 3.7), [retry: same key, same hash], size: 6pt)
  node(2.8, 1.8, [replay 201], [stored bytes verbatim])
  cdraw.line((9.6, 4.6), (9.6, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((9.6, 1.2), [same key, new hash: the 422], size: 6pt)
  cdraw.line((16.4, 4.6), (16.4, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((16.4, 1.2), [expired: miss, deleted on contact], size: 6pt)
})

== the in-flight window, closed by a table

The lookup alone has a hole. A caller misses, a handler runs, the
save lands only after the handler returns, and two callers under one
key inside that window both miss and both run, the loser answering
the handler's own 409 for an operation that succeeded and is recorded
under its key. The go lane's adversarial pass opened exactly this
window by parking one register inside the injected hash, and the
shape of the fix travels intact: the guard runs the fill under
singleflight keyed by the same scope triple the rows live under, the
first caller runs and settles, and the later caller waits and
re-reads the settled row, so the concurrent double submit replays the
201 the first caller stored.

The proof is the parked fill. The test parks the first submitter's
handler on an event, starts the second submitter into the open
window, and only closes the gate once the flight table shows both
callers inside the key's flight, a fact the join probe reads under
the lock. One handler run, one snapshot row, one caller replayed,
every time, with no sleep and no schedule luck:

#listing("c-os-cloud/api/src/idem_guard.c", first: 66, last: 84, caption: [the guard: miss, flight under the scope triple, settle and re-read]) // PIN: guard flight

#diagram([the window with and without the flight], length: 13pt, {
  pane(0.3, 10.6, 7.4, [without the flight], [both miss, both run], [a 409 for a success], [two rows or none])
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.4, [with the flight], [one runs, one joins], [the joiner re-reads], [one row, one 201])
  cdraw.content((11.3, 0.9), [the flight key is the store key's own scope triple], size: 6pt)
})

Who asks the guard is the composition's question, and the lane
answered it the same way it answered the limit's double draw: one
writer. The register handler holds no idem logic at all, it only
inserts, and the middleware stack's idempotency layer composes the
lookup, the replay, the snapshot, and the reuse 422 around whatever
handler runs, scoped to the register route by the router's own
pattern, over the same singleflight and the same rows this section
walked. The family harness rides the layer the composed way through
an idem_layer flag, so no handler-side logic stays alive just for the
tests.

== singleflight over the ch16 atomics

When a hot key expires, every request for it computes the same
expensive thing at once, and singleflight collapses the herd: the
first caller runs the fill, every caller that arrives before it
finishes waits and receives the same result, and the entry is
forgotten the moment its consumers drain, which is the property the
next chapter's cache leans on. The x/sync group is one mutex over a
map of in-flight calls each carrying its own handoff, and this
vehicle states that sentence in the platform's own parts: a fixed
table of slots, one slim reader-writer lock, one condition variable,
a generation counter per slot so a waiter can tell its flight ending
from a new flight beginning on the same slot.

The join is the load-bearing lines. A caller that finds the key's
slot running bumps the slot's refs under the lock, parks in the
predicate loop, and copies the result only when the slot still holds
its generation, so a wake is never trusted blind, the lost-wake
lesson written as the loop's shape. A latecomer after completion
never joins the old flight, finished slots are invisible to the scan,
so it starts a new one, and a full table runs uncollapsed rather than
allocating, bounded is the policy:

#listing("c-os-cloud/api/src/idem_single.c", first: 61, last: 85, caption: [the join: refs under the lock, the predicate loop, the copy only on a matching generation]) // PIN: sflight join

#diagram([three callers arrive together, one fill happens], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  for x in (2.6, 7.4, 12.2) {
    cdraw.content((x, 6.9), [caller], size: 6pt)
    cdraw.line((x, 6.3), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.rect((0.8, 4.2), (14.0, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((7.4, 5.1), [one slot, one generation], size: 6pt)
  cdraw.content((7.4, 4.5), [two join, one runs], size: 6pt)
  cdraw.line((7.4, 4.1), (7.4, 3.4), stroke: luma(100), mark: (end: ">>"))
  pane(4.8, 10.0, 3.4, [the fill], [one origin read], [parked on the cv])
  cdraw.line((10.2, 2.4), (11.6, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 17.4, 3.4, [release], [all three receive], [the same result])
  pane(17.8, 22.6, 3.4, [after the lull], [slot freed, gen bumped], [next wave fills])
})

== the primitives, one job each

The win32 vocabulary this chapter leans on is small and each shape
has one job. The slim reader-writer lock is mutual exclusion, one
writer at a time, readers queue too, and it needs no destructor. The
condition variable is the handoff, and its rule is written into every
wait this vehicle issues: sleep only inside the predicate loop,
because a wake with no waiter, or a wake that arrives before the
sleep, must be harmless by construction. The event handle is the
gate, auto-reset consuming one release, manual reset staying open,
and the duel's barrier is a manual reset closed once. The c23
atomics carry the arrivals and the counters, the acquire release
pairing the ch16 chapter pinned, and c23 threads.h spawns the workers
beside the win32 shapes exactly as the ch15 ruling taught both.

The depth discipline is the honesty under all of it. What a detector
would prove, if this box could run one, is happens-before, that every
pair of accesses to shared state is ordered by some synchronization
edge, a lock, a condition variable, an atomic. It does not prove the
locking policy right, a data-race-free program still loses updates if
the lock is held at the wrong altitude, and ubsan does not even run
here, a standing machine fact. That is why every wait in this family
is a loop with a reason and every collapse is a fact in a table a
test can read, the discipline substituting for the detector this
platform lacks.

#diagram([each primitive, the guarantee it buys, the cost it charges], length: 13pt, {
  let row(y, name, guarantee, costs) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y + 0.85), [#name], size: 6pt)
    cdraw.content((10.6, y + 0.85), [#guarantee], size: 6pt)
    cdraw.content((18.4, y + 0.85), [#costs], size: 6pt)
  }
  row(6.0, [srw lock], [mutual exclusion], [readers queue too])
  row(4.2, [condition variable], [the handoff, slept in a loop], [a stray wake must be harmless])
  row(2.4, [event handle], [the gate, one close or many], [auto reset consumes])
  row(0.6, [c23 atomics], [arrivals, counters, edges], [orderings must be named])
  cdraw.content((3.4, 7.5), [no detector on this box: every wait is a loop with a reason], size: 6.5pt)
})

== bounded fan-out, first error wins

Spawn a thread per item and the size of the input becomes the size of
the thread count's worst day. The valve is a fixed team: a bounded
count of threads drains an index range, the bound is the team size,
and every thread is joined before the run returns, so the first error
is an answer, never a leak. The latch is the other half: the first
task to fail sets it under the lock, later errors cannot overwrite
the first, and a latched error leaves every further claim denied, so
queued tasks stop early instead of piling onto a dead origin.

The test pins both promises with the same event discipline as the
duel. The bound holds: the first pair of tasks parks on a gate a
releaser thread closes only after observing 2 in flight, and the peak
is exactly the team size, a fact about the valve, not the schedule.
The first error cancels: of 8 tasks the failing one latches its code
as the run's answer and at most the 2 already claimed complete, the
rest were denied at the claim:

#listing("c-os-cloud/api/src/conc_fanout.c", first: 17, last: 40, caption: [the worker: claim under the lock, run without it, latch the first error]) // PIN: fanout worker

#diagram([the first error travels left through the latch], length: 13pt, {
  for x in (1.6, 6.4, 11.2, 16.0, 20.8) {
    cdraw.rect((x - 1.7, 3.6), (x + 1.7, 5.6), fill: luma(235), radius: 0.02)
    cdraw.content((x, 5.0), [task], size: 6pt)
  }
  cdraw.content((6.4, 4.2), [errors], size: 6pt)
  cdraw.line((6.4, 3.4), (6.4, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((1.4, 0.8), (21.8, 2.4), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, 2.0), [the latch: first error stored, claims denied], size: 6pt)
  cdraw.content((11.6, 1.2), [queued tasks stop early, every thread joins], size: 6pt)
  cdraw.content((11.6, 6.6), [at most the team size in flight], size: 6pt)
  cdraw.content((11.6, 7.5), [the run answers with the first error], size: 6pt)
})

sources: rfc-editor.org for RFC 9110 section 13.1.1 If-Match and
section 13.1.2 If-None-Match with the weak and strong validator
semantics of section 8.8.3, accessed 2026-09-27, learn.microsoft.com
for SRW locks, condition variables, event objects, and
WaitForSingleObject at the same date, the singleflight registration
semantics restated from the x/sync v0.22.0 source as the go lane's
chapter 24 quotes it, and the happens-before model stated as the go
memory model documentation does. Verified by the conc family suite,
51 checks in `tests/test_conc.c` over the store family's guard, green
in `make verify-capi`, 12 consecutive clean runs with zero sleeps:
every park is an event the test closes, every join is a fact in the
flight table.
