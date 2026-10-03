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

The store chapter's engine gave one writer the lock: one writer
wins, the loser learns the fact. This chapter moves that fact to the http edge
and builds everything around it: If-Match preconditions end to end
with the ETag duel two released PATCHers settle, If-None-Match and the
304 that saves the body, idempotency keys with stored response
snapshots so a retried register replays instead of double-creating,
singleflight collapsing a herd into one fill, the synchronization
primitives revisited as shapes with jobs, errgroup with bounded
fan-out and first-error cancel, and the race canary that documents
what the detector actually proves.

== the lost update prevented

Two clients read the same user, both patch, and without protection one
write silently vanishes. The stack answers in three layers. The
precondition wrapper fails fast: an If-Match that is missing, the
contract chose 412 over the 428 the RFC suggests, or stale against the
current representation refuses the request before the handler burns
its decode. The handler still checks the etag against the body it
fetched, because a route can exist without the wrapper. And the
store's compare-and-swap inside one write transaction is the
guarantee itself, the only layer that is atomic. Fast fail, invariant,
atomicity, in that order.

The duel stages the whole chain over the real routes: the store,
the user handlers, the wrapper, two PATCHers carrying the same
valid etag, released together by one close of a barrier. Both pass the
wrapper, both pass the handler's check, and the CAS decides. Exactly
one 200, exactly one 412, version 2 standing after, every run:

#listing("go/api/internal/conc/conc_test.go", first: 88, last: 107, caption: [the duel: one barrier releases both writers, the store's CAS crowns one])

#diagram([two PATCHers, one barrier, one winner], length: 13pt, {
  cdraw.content((2.6, 7.4), [writer A], size: 6.5pt)
  cdraw.content((12.4, 7.4), [writer B], size: 6.5pt)
  cdraw.line((0.6, 6.6), (4.6, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((2.6, 5.9), [#"If-Match: v1"], size: 6pt)
  cdraw.line((10.4, 6.6), (14.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.4, 5.9), [#"If-Match: v1"], size: 6pt)
  cdraw.rect((5.6, 6.1), (9.4, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((7.5, 6.8), [the barrier], size: 6pt)
  cdraw.content((7.5, 6.3), [one close, both go], size: 6pt)
  cdraw.line((4.8, 5.6), (4.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.2, 5.6), (10.2, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.0, 3.0), (12.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.5, 4.1), [the CAS in one write transaction], size: 6pt)
  cdraw.content((7.5, 3.4), [version check and bump, one write tx], size: 6pt)
  pane(14.6, 21.6, 4.6, [A commits], [200, version 2], [new etag])
  pane(14.6, 21.6, 1.4, [B refused], [412, ErrVersion], [retry from v2])
})

== If-None-Match and 304

The read side of the same coin costs nothing when nothing changed. A
GET carrying an If-None-Match that matches the current representation
answers 304 Not Modified, and the wrapper answers it before the
handler runs: the store read and the marshal are both skipped, and the
client, which already holds the body the etag names, keeps it. The
response carries the etag and nothing else, because a 304 with a body
would make the client cache the wrong thing for the wrong reason, the
body it was told it already has.

The check is four decisions in order: no header means an ordinary
read; a missing resource passes through so the handler's own 404
answers, the wrapper never invents statuses; a header that does not
match the current etag is a normal read too, the client's copy is
stale, so it gets a fresh one; only the match answers 304:

#listing("go/api/internal/conc/etag.go", first: 80, last: 97, caption: [the conditional GET: one comparison, an empty body, the etag stamped])

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
  cdraw.content((13.5, 4.2), [store read and marshal both skipped], size: 6pt)
  cdraw.content((13.5, 3.1), [a 304 with a body would poison the client], size: 6pt)
})

== idempotency keys

A client that times out retries, and a register route that recreates
on retry is a double-charge machine. The contract's answer is the
Idempotency-Key header. The exact request bytes are hashed under
sha256, whitespace drift is a different request, and the key is scoped
by route and caller identity, so two clients may use the same key
freely. The first successful run is stored as a snapshot, status, full
header set, body, and a later request with the same key and the same
hash replays those bytes at the stored status: the retried register
returns the original 201, Location and ETag included, byte for byte.

The two failure paths are as deliberate. The same key under a
different hash is a 422 with details, the client is misusing the
contract, and the stored snapshot is untouched. And a failing first
run is never stored: a retry after a validation error deserves a fresh
run, not a replayed 422, so only outcomes under 400 become
snapshots, and no 3xx exists on this route today. The
store side is one engine keyspace under the idem: prefix with a 24
hour expiry, lazily swept on read, and the reports route is deliberately not on this guard,
because its replay upgrades a stored 202 to the completed report, a
sanctioned divergence that is the handler's own logic:

#listing("go/api/internal/conc/idempotency.go", first: 70, last: 83, caption: [the guard: route and key resolved, everything keyed delegated])

The missing half was concurrency. A lookup that misses, a handler that
runs, a save that lands only after the handler returns: two callers
under the same key inside that window both miss, both run, and the
loser answers the handler's own 409 for an operation that succeeded
and is recorded under its key. The adversarial pass opened exactly
this window by parking one register inside the injected hash and
letting a second run to completion. The guard closes it with an
in-flight table keyed by the same route, identity, and key triple the
store rows live under: the first caller claims the slot and answers a
release on the way in, a later caller waits on its channel and then
reads the settled row, so the concurrent double submit replays the 201
the first caller stored:

#listing("go/api/internal/conc/idempotency.go", first: 149, last: 163, caption: [settle: first caller runs and releases, later callers wait and re-read the settled row])

#diagram([one key's life: first run, snapshot, replay], length: 13pt, {
  let node(x, y, title, l1) = {
    cdraw.rect((x - 2.4, y - 1.0), (x + 2.4, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.45), [#title], size: 6pt)
    cdraw.content((x, y - 0.45), [#l1], size: 6pt)
  }
  node(2.8, 5.8, [first request], [#"key k, hash h"])
  cdraw.line((5.2, 5.8), (7.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 5.8, [run handler], [only on a miss])
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
})

== singleflight

When a hot key expires, every request for it computes the same
expensive thing at once, the thundering herd, and the origin pays for
N identical reads. singleflight collapses the herd: the first caller
runs the function, every concurrent caller with the same key waits on
that one run and receives its result, and the shared flag tells
callers their answer was shared. The entry is forgotten the moment the
call completes, which is the property that keeps this honest: the herd
that arrives after the lull fills again. A collapse tool, not a cache,
and the distinction is a design decision, not a limitation, the next
chapter puts a cache in front of this loader and gets both behaviors
explicitly.

The loader wraps the group with two doors. Do is the plain form,
synchronous, the caller blocks until the fill lands. DoChan registers
the caller synchronously and answers through a channel, and that
synchronous registration is what the tests lean on: once DoChan
returns, the caller has provably joined an in-flight fill or started
the only one, so the collapse assertion, exactly one fill for three
registered callers, has no scheduling window to flake through:

#listing("go/api/internal/conc/singleflight.go", first: 12, last: 34, caption: [the loader: one door synchronous, one door provably registered])

The x/sync group the loader wraps is the same honesty. Its source is
one `sync.Mutex` over a lazily built `map[string]*call`, each call
carrying its own `sync.WaitGroup`, the value and error written once
before `Done`, a duplicate count, and the channel list `DoChan`
appends to. The first caller for a key creates the entry under the
mutex and runs the function, a later caller finds the entry, bumps the
duplicate count, unlocks, and parks on that call's `WaitGroup`, and
the runner wakes the waiters and deletes the map entry inside one
locked defer, which is the forget-on-completion property the next
chapter's cache leans on. The provable registration the tests rely on
is simply the map lookup and the channel append sharing one critical
section, so joining an in-flight fill has no scheduling window.

#diagram([three requests arrive together, one origin read happens], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  for x in (2.6, 7.4, 12.2) {
    cdraw.content((x, 6.9), [request], size: 6pt)
    cdraw.line((x, 6.3), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.rect((0.8, 4.2), (14.0, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((7.4, 5.1), [one in-flight entry for the key], size: 6pt)
  cdraw.content((7.4, 4.5), [two join, one runs], size: 6pt)
  cdraw.line((7.4, 4.1), (7.4, 3.4), stroke: luma(100), mark: (end: ">>"))
  pane(4.8, 10.0, 3.4, [the fill], [one origin read], [held open on a channel])
  cdraw.line((10.2, 2.4), (11.6, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 17.4, 3.4, [release], [all three receive], [the same result])
  pane(17.8, 22.6, 3.4, [after the lull], [entry forgotten], [next wave fills])
})

== the primitives revisited

The mutex family is small and each shape has one job. Counter is the
whole mutex story in two methods: shared mutable state, one lock,
nothing clever between them. Stats is the RWMutex case, and the rule
is measured, not assumed, readers must dominate and the sections must
be long enough to pay for the heavier bookkeeping, otherwise a plain
mutex wins. The buffered channel is a semaphore for free, capacity
tokens, acquire takes, release gives, with a context exit added
because a plain channel cannot be canceled out of. The Once family
memoizes one expensive computation, OnceFunc for the void case,
OnceValue when the error or value must be carried, OnceValues for
pairs, and wg.Go removes the loop-carried Add that leaked waiters for
a decade.

Under all of them the race detector, and what it proves is narrower
than folklore: it verifies happens-before, that every pair of
accesses to shared state is ordered by some synchronization edge, a
lock, a channel, a WaitGroup, an atomic. It does not prove your
locking policy correct, a data-race-free program still loses updates
happily if the lock is held at the wrong altitude, and it does not
find races in interleavings a run never took. That is why the gate
runs it on every commit and why the canary at the end of this chapter
exists:

#listing("go/api/internal/conc/locks.go", first: 12, last: 30, caption: [the mutex story in two methods: shared state, one lock])

#snippet("sem := make(Semaphore, 2)  // capacity is the concurrency bound\nsem.Acquire(ctx)              // or ctx.Done()\nsem.Release()                 // give the token back", lang: "go")

#diagram([each primitive, the guarantee it buys], length: 13pt, {
  let row(y, name, guarantee, costs) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y + 0.85), [#name], size: 6pt)
    cdraw.content((10.6, y + 0.85), [#guarantee], size: 6pt)
    cdraw.content((18.4, y + 0.85), [#costs], size: 6pt)
  }
  row(6.0, [mutex], [mutual exclusion, one writer at a time], [readers queue too])
  row(4.2, [RWMutex], [readers share, writers alone], [heavier, needs read dominance])
  row(2.4, [chan semaphore], [bounded concurrency], [no cancellation until added])
  row(0.6, [Once family], [exactly one computation], [result frozen forever])
  row(-1.2, [wg.Go], [every spawned fn awaited], [nothing, it is free])
  cdraw.content((3.4, 7.5), [the race detector under all of them: happens-before, not policy], size: 6.5pt)
})

== errgroup with bounded fan-out

Spawn a goroutine per item and the size of your input becomes the size
of your database connection pool's worst day: the queue you built to
protect the origin becomes the stampede you meant to prevent. errgroup
with SetLimit is the valve. The helper runs one task per index with at
most limit in flight, and the group's context is canceled the moment
any task errors, so tasks still queued or blocked on their own context
see Done and stop early, and Wait answers with that first error, the
one worth acting on, not the last cancel noise to land.

Because the valve is an x/sync type, it earns its keep here by being
nothing but this chapter's primitives in a named shape. The v0.22.0
source declares the whole mechanism in five fields: a `sync.WaitGroup`
every `Go` adds to and every exit releases, a `sem chan token` whose
buffer is the SetLimit bound, one token taken on the way in and given
back on the way out, an `errOnce sync.Once` guarding the `err` slot it
latches, so the first error is stored once and later ones cannot
overwrite it, and a cancel saved from `context.WithCancelCause`,
fired on that first error or at Wait. The
cancellation traveling left through the context is the ch06 close, the
bound is the buffered-channel semaphore from the primitives section,
and the first-error discipline is the Once family. A dependency that
decomposes into primitives you already own is cheap to trust, because
reading its source beats reading its documentation.

The test pins both promises deterministically. The bound holds, two
tasks observed in flight together while the rest queue, the peak
exactly the limit. And the first error cancels, the one failing task
returns the error, the other nine hold on the group's context and
leave when it closes, no work between them:

#listing("go/api/internal/conc/errgroup.go", first: 9, last: 25, caption: [bounded fan-out: SetLimit is the valve, the group ctx is the alarm])

#diagram([the first error travels left through the context], length: 13pt, {
  for x in (1.6, 6.4, 11.2, 16.0, 20.8) {
    cdraw.rect((x - 1.7, 3.6), (x + 1.7, 5.6), fill: luma(235), radius: 0.02)
    cdraw.content((x, 5.0), [task], size: 6pt)
  }
  cdraw.content((6.4, 4.2), [errors], size: 6pt)
  cdraw.line((6.4, 3.4), (6.4, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((1.4, 0.8), (21.8, 2.4), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, 2.0), [group context canceled], size: 6pt)
  cdraw.content((11.6, 1.2), [remaining tasks see Done and stop early], size: 6pt)
  cdraw.content((11.6, 6.6), [at most limit in flight, the rest queue inside g.Go], size: 6pt)
  cdraw.content((11.6, 7.5), [Wait answers with the first error], size: 6pt)
})

== the race canary

The canary is a test whose subject is the tool. Its broken half is a
counter with no lock, two goroutines hammering one variable with
nothing between them, pure shared state. Its guarded twin is the same
hammering through the Counter from this chapter, clean by
construction. The suite runs the guarded twin in process, always
green, and executes the broken twin as a child process, then asserts
what the build mode proves: compiled with the detector, the child must
fail, because unsynchronized shared state is a detected fact, and
compiled without it, the child must pass, silently losing increments,
which is the entire argument for the gate.

The child-process construction is what keeps the suite green while the
canary stays live. A broken test run in process under `-race` fails
the build, which is the detector doing its job at the worst possible
altitude, in the gate instead of the finding. Spawned behind an
environment key, the broken path runs only when the parent asks for
it, and the parent turns the child's exit code into the assertion.
Delete the lock in the guarded twin and the in-process run fails under
`-race` with a report naming the exact accesses and the goroutines
that raced, which is the demo the canary exists to keep honest:

#listing("go/api/internal/conc/race_canary_test.go", first: 10, last: 33, caption: [the deliberately broken half: two goroutines, one variable, no lock])

#diagram([the canary's two verdicts, one mechanism], length: 13pt, {
  pane(0.4, 10.4, 7.2, [parent suite], [runs the guarded twin], [spawns the broken twin])
  cdraw.line((5.4, 4.6), (5.4, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 10.4, 3.4, [child, with -race], [unsynchronized accesses], [exit != 0, detected])
  cdraw.content((13.2, 6.2), [the detector's model], size: 6.5pt)
  cdraw.content((16.0, 5.2), [every access pair must share], size: 6pt)
  cdraw.content((16.0, 4.2), [a happens-before edge: lock,], size: 6pt)
  cdraw.content((16.0, 3.2), [channel, WaitGroup, atomic], size: 6pt)
  cdraw.content((16.0, 2.0), [no edge means report], size: 6pt)
  cdraw.content((16.0, 0.9), [without -race: silent loss], size: 6pt)
})

sources: pkg.go.dev for sync, sync/atomic, testing/synctest, and
golang.org/x/sync, accessed 2026-09-25, the Once family and wg.Go
signatures quoted from the go 1.27 source in GOROOT, singleflight's
Do and DoChan registration semantics read from the x/sync v0.22.0
source in the module cache, and the happens-before model stated as
the race detector's own documentation does. Verified by
`go/api/internal/conc` tests, 14 of them, the canary pair and the
flight pair included, under go vet, go test, and the module-wide
race leg, where the
canary's child fails on cue and the guarded twin stays clean.
