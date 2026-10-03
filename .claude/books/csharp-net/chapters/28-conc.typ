#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= concurrency control

The store chapter gave one writer the lock and made the loser's failure
visible as a version mismatch. This chapter moves that fact to the http
edge and builds everything around it: If-Match preconditions end to end
with the duel two released patchers settle, If-None-Match and the 304
that saves the body, idempotency keys with stored response snapshots
and in-flight dedup, singleflight collapsing a herd into one fill, the
synchronization primitives revisited as shapes with jobs, and a race
canary built for a platform that ships no race detector.

== the lost update prevented

Two clients read the same user, both patch, and without protection one
write silently vanishes. The stack answers in three layers. The
precondition ladder fails fast: a PATCH with no If-Match is refused
with 412 before anything in the update runs, an anonymous caller
still meeting the 401 edge first, the contract chose 412 over the 428
the RFC suggests. The handler still compares the header against the
etag of the representation it just fetched, because the value can move
between the wrapper and the write. And the store's guarded update from
the previous chapter, check, bump, and write inside one BEGIN IMMEDIATE
transaction, is the guarantee itself, the only layer that is atomic.
Fast fail, invariant, atomicity, in that order.

The duel stages the whole chain over the real route table with the
sqlite store behind it: the users family wired over SqliteUserStore, an
actor installed by a test middleware, two PATCHers carrying the same
valid etag, and one TaskCompletionSource as the barrier. Both requests
are created parked on the barrier, one close releases both, and whether
the second request reads its user before or after the first commits,
the outcome is the same set: exactly one 200, exactly one 412, version
2 standing after, the winner's name in the row, and a new etag on the
winner's response. No sleep exists anywhere in the file, and the
assertion is on the sorted pair of statuses, so either racer may win:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Concurrency/EtagDuelTests.cs", first: 90, last: 109, caption: [the duel: one barrier releases both writers, the guarded update crowns one]) // PIN: the etag duel

#diagram([two patchers, one barrier, one winner], length: 13pt, {
  cdraw.content((2.6, 7.4), [writer A], size: 6.5pt)
  cdraw.content((12.4, 7.4), [writer B], size: 6.5pt)
  cdraw.line((0.6, 6.6), (4.6, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((2.6, 5.9), [#"If-Match: v1 etag"], size: 6pt)
  cdraw.line((10.4, 6.6), (14.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.4, 5.9), [#"If-Match: v1 etag"], size: 6pt)
  cdraw.rect((5.6, 6.1), (9.4, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((7.5, 6.8), [the barrier], size: 6pt)
  cdraw.content((7.5, 6.3), [one close, both go], size: 6pt)
  cdraw.line((4.8, 5.6), (4.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.2, 5.6), (10.2, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.0, 3.0), (12.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.5, 4.1), [the guarded update, one begin immediate], size: 6pt)
  cdraw.content((7.5, 3.4), [check, bump, write in one statement], size: 6pt)
  pane(14.6, 21.6, 4.6, [A commits], [200, version 2], [new etag])
  pane(14.6, 21.6, 1.4, [B refused], [412, zero rows], [retry from v2])
})

== If-None-Match and 304

The read side of the same coin costs nothing when nothing changed. A
GET carrying an If-None-Match that matches the current representation
answers 304 Not Modified before the response body is built, and the
client, which already holds the body the etag names, keeps it. The 304
carries the etag and nothing else, because a 304 with a body would make
the client cache the wrong thing for the wrong reason.

The etag is the sha256 of the exact response bytes, computed the same
way on every user representation, so the comparison in the conditional
branch is one string equality over a value the handler just computed
for the normal path anyway. The decisions are four: no header means an
ordinary read, a missing resource passes through so the handler's own
404 answers, a header that does not match is a fresh 200 because the
client's copy is stale, and only the match answers 304:

#listing("csharp-net/api/src/CsharpBook.Api/Users/UserEndpoints.cs", first: 88, last: 97, caption: [the conditional GET: one comparison, an empty body, the etag stamped]) // PIN: conditional GET

#diagram([the conditional GET decision], length: 13pt, {
  let step(y, q, yes, no) = {
    cdraw.content((6.0, y), [#q], size: 6pt)
    cdraw.content((3.2, y - 0.6), [#"no: " + no], size: 6pt)
    cdraw.content((9.6, y - 0.6), [#"yes: " + yes], size: 6pt)
  }
  step(7.0, [If-None-Match present?], [], [ordinary read])
  cdraw.line((6.0, 6.6), (6.0, 5.9), stroke: luma(100), mark: (end: ">>"))
  step(5.6, [resource exists?], [], [pass through, handler 404s])
  cdraw.line((6.0, 5.2), (6.0, 4.5), stroke: luma(100), mark: (end: ">>"))
  step(4.2, [header = current etag?], [fresh read, 200], [])
  cdraw.line((6.0, 3.8), (6.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  pane(2.2, 9.8, 3.0, [304], [etag stamped,], [empty body])
  cdraw.content((13.5, 4.2), [the body build is skipped entirely], size: 6pt)
  cdraw.content((13.5, 3.1), [the etag is the sha256 of the exact bytes], size: 6pt)
})

== idempotency keys

A client that times out retries, and a register route that recreates on
retry is a double-charge machine. The contract's answer is the
Idempotency-Key header, scoped by route and caller identity, bound to
the sha256 of the exact request bytes. The first successful run is
stored as a snapshot, status, content type, body, over the
idempotency_keys table the store chapter shipped, and a later request
with the same key and the same hash replays those bytes at the stored
status: the retried register returns the original 201 byte for byte.

The failure paths are as deliberate. The same key under a different
hash answers Mismatch, the client is misusing the contract, and the
stored snapshot is untouched. A failing first run is never stored,
because a retry after a validation error deserves a fresh run, so only
outcomes under 400 become snapshots. Keys live 24 hours on the injected
clock, and expiry is arithmetic the test advances by hand.

The missing half was concurrency. A lookup that misses, a handler that
runs, a save that lands only after the handler returns: two callers
under the same key inside that window both miss and both run. The guard
closes it with the singleflight this chapter builds, keyed by route,
identity, and key alone. The first caller claims the flight and runs
the handler, a second caller joins the flight and never invokes it, and
once the fill settles every joiner re-reads the row and classifies
against its own hash, so the same key under a different body answers
Mismatch whether it arrived before or after the winner:

#listing("csharp-net/api/src/CsharpBook.Api/Concurrency/IdempotencyGuard.cs", first: 48, last: 67, caption: [the guard: fast-path lookup, then the flight, then the settle re-read]) // PIN: idempotency execute

#diagram([one key's life: first run, snapshot, replay], length: 13pt, {
  let node(x, y, title, l1) = {
    cdraw.rect((x - 2.4, y - 1.0), (x + 2.4, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.45), [#title], size: 6pt)
    cdraw.content((x, y - 0.45), [#l1], size: 6pt)
  }
  node(2.8, 5.8, [first request], [#"key k, hash h"])
  cdraw.line((5.2, 5.8), (7.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 5.8, [one flight], [the handler runs once])
  cdraw.line((12.0, 5.8), (14.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 5.8, [store snapshot], [#"under 400, 24 h"])
  cdraw.line((2.8, 4.6), (2.8, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.2, 3.7), [retry: same key, same hash], size: 6pt)
  node(2.8, 1.8, [replay 201], [stored bytes, verbatim])
  cdraw.line((9.6, 4.6), (9.6, 2.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 1.8, [same key, new hash], [])
  cdraw.content((9.6, 1.2), [422 with details], size: 6pt)
  cdraw.line((16.4, 4.6), (16.4, 2.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 1.8, [first run 4xx], [])
  cdraw.content((16.4, 1.2), [not stored, retry fresh], size: 6pt)
  cdraw.content((11.3, 7.4), [a concurrent joiner re-reads the settled row], size: 6pt)
})

== singleflight

When a hot cache key expires, every request for it computes the same
expensive thing at once, the thundering herd, and the origin pays for n
identical reads. Singleflight collapses the herd: the first caller runs
the function, every concurrent caller with the same key parks on that
one run and receives its result, and the shared flag tells the caller
its answer was shared. The entry is forgotten the moment the call
completes, the property that keeps this honest, because the herd that
arrives after the lull fills again. A collapse tool, not a cache, and
the next chapter puts a cache in front of this loader and gets both
behaviors explicitly.

The implementation is two primitives and nothing else, and the
decomposition is the whole lesson. A SemaphoreSlim is the lock over the
in-flight map. A TaskCompletionSource per entry is the handoff, the
value published once before the map forgets the entry. Registration is
synchronous under the lock: by the time ExecuteAsync returns a task,
the caller has provably joined an in-flight fill or started the only
one, so the collapse test, three callers, one fill held open on a
completion source the test controls, asserts one factory invocation
with no scheduling window to flake through. The first caller is the
runner, waiters park on the completion source with their own token, so
a waiter that cancels cancels only its await while the fill keeps
running for everyone else. This is the same decomposition as go's
x/sync singleflight, one mutex over a map of calls each carrying its
own wait group and handoff, and reading either source is reading the
same shape twice:

#listing("csharp-net/api/src/CsharpBook.Api/Concurrency/Singleflight.cs", first: 32, last: 52, caption: [registration under the lock: join the entry or start the only one, synchronously]) // PIN: singleflight registration

#diagram([three requests arrive together, one origin read happens], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  for x in (2.6, 7.4, 12.2) {
    cdraw.content((x, 6.9), [caller], size: 6pt)
    cdraw.line((x, 6.3), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.rect((0.8, 4.2), (14.0, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((7.4, 5.1), [one entry in the in-flight map], size: 6pt)
  cdraw.content((7.4, 4.5), [two join, the first runs], size: 6pt)
  cdraw.line((7.4, 4.1), (7.4, 3.4), stroke: luma(100), mark: (end: ">>"))
  pane(4.8, 10.0, 3.4, [the fill], [one factory run], [held on the TCS])
  cdraw.line((10.2, 2.4), (11.6, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 17.4, 3.4, [the handoff], [all three receive], [the same result])
  pane(17.8, 22.6, 3.4, [after the lull], [entry forgotten], [next wave fills])
})

== the primitives revisited

Each synchronization shape has one job, and the revisit prices them.
Monitor, the lock keyword, is the whole mutex story in two methods:
shared mutable state, one gate, nothing clever between them, reentrant
and thread-affine, and it cannot be awaited inside. SemaphoreSlim is
the bounded-concurrency valve: WaitAsync takes a cancellation token, so
a caller queued for a permit can cancel out of the wait, and the permit
is not bound to the thread that took it. Lazy with
ExecutionAndPublication is the platform's run-exactly-once cell, and
the distinction the docs draw is worth teaching: LazyInitializer
guarantees a single published value but may invoke the factory more
than once under contention, while ExecutionAndPublication guarantees
the single run, which is what the hand-rolled Once over Monitor
guarantees too. System.Threading.Channels closes the tour: a bounded
channel is the queue and the backpressure in one call, the writer parks
when the buffer is full, the reader drains in order.

Every guarantee is a test. The counter stays exact under an eight-task
hammer. The valve admits exactly its permit count, and the assertion is
permit math, not timing: with both permits held, the third and fourth
tasks provably have not entered, whatever the scheduler is doing with
them. Once and Lazy each run their factory exactly once with two racing
readers staged on a manual-reset gate. The bounded channel parks its
second writer on a buffer of one, and the read frees it in order:

#listing("csharp-net/api/src/CsharpBook.Api/Concurrency/SyncPrimitives.cs", first: 10, last: 24, caption: [the Monitor story in two methods: shared state, one gate]) // PIN: counter

#diagram([each primitive, the guarantee it buys], length: 13pt, {
  let row(y, name, guarantee, costs) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y + 0.85), [#name], size: 6pt)
    cdraw.content((10.6, y + 0.85), [#guarantee], size: 6pt)
    cdraw.content((18.4, y + 0.85), [#costs], size: 6pt)
  }
  row(6.0, [lock, Monitor], [mutual exclusion, one writer], [thread-affine, no await inside])
  row(4.2, [SemaphoreSlim], [bounded permits, cancelable wait], [an allocation heavier])
  row(2.4, [Lazy E+P], [exactly one factory run], [result frozen forever])
  row(0.6, [bounded channel], [ordered queue plus backpressure], [no cancellation until added])
  cdraw.content((3.4, 7.5), [LazyInitializer: one published value, possibly several factory runs], size: 6.5pt)
})

== the race canary

Go's canary proved a detector, a child process compiled with the race
finder failing on cue. The dotnet sdk ships no race detector, so this
canary proves the bug class instead, and its honesty about that is the
point. The staged half is deterministic: two tasks run the same
read-modify-write on one field, each reads, signals, waits for the
other's read, then writes, so the interleave is scripted by completion
sources and the loss is exact, two increments land, one survives, no
timing anywhere:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Concurrency/RaceCanaryTests.cs", first: 26, last: 44, caption: [the staged interleave: both read 0, both write 1, one increment is lost]) // PIN: staged lost update

The stress half runs eight tasks fifty thousand increments each. The
guarded twins, the locked counter and Interlocked.Increment, come out
exactly at four hundred thousand, and those asserts are what the gate
keeps. The plain read-modify-write beside them loses increments on real
hardware, observed run after run, but a suite cannot assert a
statistical loss without becoming a flake factory, so the canary pins
the bug class with the staged interleave and pins the discipline with
the exact twins, and the prose is where the observed loss is stated.
What no tool checks for you here, the equivalent of happens-before
reasoning, is that every shared field's accesses share an edge, a lock,
an interlocked op, a channel, and the duel, the guard, and the canary
are that reasoning written down as tests:

#diagram([the canary's two halves, one bug class], length: 13pt, {
  pane(0.4, 10.4, 7.2, [the staged half], [both read, barrier, both write], [loss is exact, every run])
  cdraw.line((10.6, 5.4), (11.4, 5.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.6, 22.4, 7.2, [the stress half], [guarded twins exact, always], [plain twin loses, observed])
  cdraw.content((11.4, 3.2), [no race detector ships with the sdk], size: 6pt)
  cdraw.content((11.4, 2.1), [the discipline is the edge shared by every access pair], size: 6pt)
  cdraw.content((11.4, 1.0), [a statistical assert would be a flake factory], size: 6pt)
})

sources: learn.microsoft.com for SemaphoreSlim, TaskCompletionSource,
LazyInitializer and Lazy with LazyThreadSafetyMode,
System.Threading.Channels, Interlocked, and Task.WaitAsync, accessed
2026-09-26, the LazyInitializer publication-versus-single-run
distinction read from the EnsureInitialized remarks on the same date,
and the singleflight semantics stated from the go x/sync v0.22.0
source the go book's chapter pins. Verified by
`dotnet test Api.slnx` over the concurrency suite, 22 tests across
SingleflightTests, IdempotencyGuardTests, EtagDuelTests,
PrimitivesTests, and RaceCanaryTests, zero sleeps, every schedule
staged on completion sources or permit math.
