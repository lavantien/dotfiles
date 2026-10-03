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

The store chapter's guarded update gave one writer the win: one
commit lands, the loser learns the fact. This chapter moves that fact
to the http edge and builds everything around it: strong etags over
the exact response body bytes, the If-Match and If-None-Match duel
two released patchers settle, idempotency keys with stored response
snapshots replayed byte for byte, singleflight as a lock plus a
handoff event, the synchronization primitives revisited as shapes
with jobs, bounded fan-out that latches the first error, and the race
canary python runs without a detector. The mechanisms live in
pyapi/conc.py with injected clocks and duck-typed backends, the
composition root wires them to the routes, and the frozen vectors 09
through 12 pin the etag lane against bytes this code reproduces.

== the lost update prevented

Two clients read the same user, both patch, and without protection one
write silently vanishes. The stack answers in three layers. The
precondition decision fails fast: an If-Match that is missing, the
contract chose 412 over the 428 the RFC suggests, or stale against the
current representation refuses the request before the handler burns
its decode. The etag itself is the sha256 of the exact body bytes,
quoted the way RFC 9110 spells an entity tag, computed over the same
wire representation the handlers stamp, so the decision layer and the
handler can never disagree about a version. And the store's guarded
update inside one write transaction is the guarantee itself, the only
layer that is atomic. Fast fail, invariant, atomicity, in that order.

The duel stages the whole chain over the real store: two patchers
read the row, build the etag over the body they read, both carry the
same valid tag and both pass the verdict, released together by one
close of a barrier, and the guarded update decides. Exactly one 200,
exactly one VersionError, version 2 standing after, every run, no
sleep anywhere, the barrier is the schedule:

#listing("python/api/tests/test_duel.py", first: 50, last: 64, caption: [the duel: one barrier releases both writers, the guarded update crowns one]) // PIN: the duel

#diagram([two patchers, one barrier, one winner], length: 13pt, {
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
  cdraw.content((7.5, 4.1), [the guarded update in one write transaction], size: 6pt)
  cdraw.content((7.5, 3.4), [version check and bump, one begin immediate], size: 6pt)
  pane(14.6, 21.6, 4.6, [A commits], [200, version 2], [new etag])
  pane(14.6, 21.6, 1.4, [B refused], [412, zero rows], [retry from v2])
})

== if-none-match and 304

The read side of the same coin costs nothing when nothing changed. A
GET carrying an If-None-Match that names the current representation
answers 304 Not Modified, and the decision answers it before the
handler runs: the store read and the marshal are both skipped, and
the client, which already holds the body the etag names, keeps it.
The response carries the etag and nothing else, because a 304 with a
body would make the client cache the wrong thing for the wrong
reason, the body it was told it already has.

The check is four decisions in order: no header means an ordinary
read, a missing resource passes through so the handler's own 404
answers and the wrapper never invents statuses, a header that does
not name the current etag is a normal read too because the client's
copy is stale, and only the match answers 304. The comparison accepts
the header's list form and its star form, because RFC 9110 defines
both, and the frozen vector 10 pins the single-tag case byte for
byte: its If-None-Match is the digest of the body vector 09 carries,
which the test computes rather than copies:

#listing("python/api/pyapi/conc.py", first: 42, last: 50, caption: [the conditional get decision: no header, no resource, no match, then the 304]) // PIN: conditional get

#diagram([the conditional GET decision], length: 13pt, {
  let step(y, q, yes, no) = {
    cdraw.content((6.0, y), [#q], size: 6pt)
    cdraw.content((2.8, y - 0.6), [#"no: " + no], size: 6pt)
    cdraw.content((9.9, y - 0.6), [#"yes: " + yes], size: 6pt)
  }
  step(7.0, [If-None-Match present?], [], [ordinary read])
  cdraw.line((6.0, 6.6), (6.0, 5.9), stroke: luma(100), mark: (end: ">>"))
  step(5.6, [resource exists?], [], [pass through, handler 404s])
  cdraw.line((6.0, 5.2), (6.0, 4.5), stroke: luma(100), mark: (end: ">>"))
  step(4.2, [header names current etag?], [fresh read, 200], [])
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
freely. The first successful run is stored as a snapshot, status,
header set, body, and a later request with the same key and the same
hash replays those bytes at the stored status: the retried register
returns the original 201, Location and ETag included, byte for byte.

The two failure paths are as deliberate. The same key under a
different hash raises the mismatch, the client is misusing the
contract, the caller maps it to a 422 with details, and the stored
snapshot is untouched. And a failing first run is never stored, a
retry after a validation error deserves a fresh run, not a replayed
refusal, so only outcomes under 400 become snapshots. The backend is
a protocol the guard never imports, the in-memory dict under a lock
for tests, the sqlite table from the store chapter for the wired
service, and both answer the same three states.

The half that is hard is concurrency. A lookup that misses, a handler
that runs, a save that lands only after the handler returns: two
callers under the same key inside that window both miss, both run,
and the loser answers the handler's own conflict for an operation
that succeeded and is recorded under its key. The guard closes the
window with an in-flight table keyed by the same route, identity, and
key triple the rows live under: the first caller claims the slot and
answers a release on the way in, a later caller waits on that event
and then reads the settled row again, so a concurrent double submit
replays the 201 the first caller stored. A waiter whose row is still
absent, because the first run failed or its save failed, runs fresh
in the freed slot, exactly the no-op release the settle rule allows:

#listing("python/api/pyapi/conc.py", first: 177, last: 200, caption: [run: replay a match, wait on the in-flight handoff, settle and release]) // PIN: keyed run

#diagram([one key's life: first run, snapshot, replay], length: 13pt, {
  let node(x, y, t, l1) = {
    cdraw.rect((x - 2.4, y - 1.0), (x + 2.4, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.45), [#t], size: 6pt)
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
n identical reads. The loader collapses the herd: the first caller
for a key runs the function, every concurrent caller with the same
key parks on that run's handoff event and receives its settled
outcome. The entry is forgotten the moment the run settles, which is
the property that keeps this honest: the herd that arrives after the
lull fills again. A collapse tool, not a cache, and the distinction
is a design decision, not a limitation, the next chapter puts a cache
in front of this loader and gets both behaviors explicitly.

The whole mechanism is one lock plus one dict plus one event per
flight, built from the platform's own primitives the way the go lane
decomposed the x/sync group it wrapped. Registration is synchronous
under the lock: once claim returns, the caller has provably joined an
in-flight run or started the only one, because the map lookup and the
entry creation share one critical section, so joining has no
scheduling window, and the collapse test leans on exactly that. The
settle path removes the entry from the map before it sets the event,
so a caller arriving after the settle starts a new flight, never
joins a dead one:

#listing("python/api/pyapi/conc.py", first: 287, last: 300, caption: [claim: the registration seam, one critical section for lookup and creation]) // PIN: claim seam

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
  pane(4.8, 10.0, 3.4, [the fill], [one origin read], [held open on an event])
  cdraw.line((10.2, 2.4), (11.6, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 17.4, 3.4, [release], [all three receive], [the same outcome])
  pane(17.8, 22.6, 3.4, [after the lull], [entry forgotten], [next wave fills])
})

== the primitives revisited

The threading family is small and each shape has one job. Lock is the
whole story in two methods, shared mutable state, one lock, nothing
clever between them, and Counter is that story in code. RLock is the
reentrant twin for when one lock-holder must re-enter, the price is a
count the unlock must drain. Event is a one-shot signal any number of
waiters can park on, the loader's handoff and the canary's gates are
both it. Barrier is the rendezvous, all parties arrive or nobody
proceeds, and the duel releases through one. Semaphore and its bounded
twin are admission tokens, capacity waiting slots, release gives one
back, and the bounded form refuses to release what was never taken.
Condition is the shape the others compose into when a state change
must wake selected waiters, lock plus wait plus notify, and it is
also the recipe for the one lock the stdlib does not ship, there is
no read-write lock in threading, unlike the go and c\# platforms this
book mirrors, and the honest statement is that cpython's own dict does
not need one because the interpreter's lock is the reader lock.

Under all of them the same honesty the go chapter stated: a lock at
the wrong altitude loses updates while holding everything tidy, and
free-threaded builds, officially supported in 3.14 under PEP 779,
make the question sharper, not new. The canary at the end of this
chapter exists to keep the claim tested:

#listing("python/api/pyapi/conc.py", first: 333, last: 351, caption: [the lock story in two methods: shared state, one lock]) // PIN: counter

#diagram([each primitive, the guarantee it buys], length: 13pt, {
  let row(y, name, guarantee, costs) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y + 0.85), [#name], size: 6pt)
    cdraw.content((10.6, y + 0.85), [#guarantee], size: 6pt)
    cdraw.content((18.4, y + 0.85), [#costs], size: 6pt)
  }
  row(6.0, [Lock], [mutual exclusion, one holder], [readers queue too])
  row(4.2, [RLock], [re-entry by the holder], [a count to drain])
  row(2.4, [Event], [one-shot signal, many waiters], [no payload])
  row(0.6, [Barrier], [all parties rendezvous], [one use, then renew])
  row(-1.2, [Semaphore], [bounded admission tokens], [no read-write split])
  cdraw.content((3.4, 7.5), [no read-write lock ships: the recipe is a Condition], size: 6.5pt)
})

== bounded fan-out with first error

Spawn a thread per item and the size of your input becomes the size of
your origin's worst day: the queue you built to protect it becomes
the stampede you meant to prevent. The valve is a worker pool over
`queue.Queue`, at most limit workers, each pulling items until it
draws a sentinel. The first exception is latched under a lock, later
errors cannot overwrite it, the latch trips a cancel event every
worker checks before starting a task, so work still queued when the
first error lands is skipped, and the pool raises the latched error
after it drains, the one worth acting on, never the last cancel noise
to land.

This is the errgroup of the go lane rebuilt from the platform's own
parts, a pool plus a latched first error plus a cancel, and the
platform's packaged spelling of the same thing is
`concurrent.futures.ThreadPoolExecutor` with `max_workers=limit`,
stdlib surface that adds futures and joins on top of exactly this
loop. The chapter builds it from the primitives it teaches because
reading the loop is the lesson. The tests pin both promises
deterministically: the bound holds, the tasks in flight observed
together at a barrier of size limit exactly limit, and with a single
worker the first error is the raised one and every item still queued
is provably skipped:

#listing("python/api/pyapi/conc.py", first: 374, last: 390, caption: [the worker: pull, skip when cancelled, latch the first error, always task done]) // PIN: pool worker

#diagram([the first error travels left through the cancel event], length: 13pt, {
  for x in (1.6, 6.4, 11.2, 16.0, 20.8) {
    cdraw.rect((x - 1.7, 3.6), (x + 1.7, 5.6), fill: luma(235), radius: 0.02)
    cdraw.content((x, 5.0), [task], size: 6pt)
  }
  cdraw.content((6.4, 4.2), [errors], size: 6pt)
  cdraw.line((6.4, 3.4), (6.4, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((1.4, 0.8), (21.8, 2.4), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, 2.0), [cancel event set], size: 6pt)
  cdraw.content((11.6, 1.2), [remaining tasks see it and skip], size: 6pt)
  cdraw.content((11.6, 6.6), [at most limit in flight, the rest wait in the queue], size: 6pt)
  cdraw.content((11.6, 7.5), [the pool raises the latched first error], size: 6pt)
})

== the race canary without a detector

The go lane's canary leaned on a race detector that cpython does not
ship, so the python canary manufactures the interleaving instead. Its
broken half is a read-modify-write with no lock, two writers forced
into the losing order by a barrier: both read the cell, both meet at
the barrier, both write what they read plus one, and the final value
is old plus one, one increment gone. The interleave is not a timing
hope, the barrier is the schedule, so the lost update is a
deterministic fact about the code, exactly what a detector would
report and what a test can assert. The guarded twin is the same two
writers through Counter's lock and it keeps both.

The trap the canary guards against is the comfortable one: the gil
makes byte-granular tears rare, so an unlocked counter can pass a
thousand runs and fail the week it meets a free-threaded build or an
interleave that lands between two bytecodes. Rare is not absent, and
3.14 ships free-threading as officially supported, so the discipline
is the lock, not the luck. Delete the lock in the guarded twin and
the deterministic broken half still passes its assertions while the
twin fails, which is the demo the canary exists to keep honest:

#listing("python/api/tests/test_conc.py", first: 468, last: 482, caption: [the deliberately broken half: both read, both wait, both write what they read]) // PIN: canary broken half

#diagram([the canary's two verdicts, one schedule], length: 13pt, {
  pane(0.4, 10.4, 7.2, [the barrier schedule], [both writers read the cell], [both wait, then both write], [old + 1, one increment gone])
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.2, [the locked twin], [the same two writers], [through Counter's lock], [old + 2, both kept])
  cdraw.content((5.4, 2.6), [the gil makes the tear rare, not absent], size: 6pt)
  cdraw.content((17.0, 2.6), [free-threaded 3.14 sharpens the question], size: 6pt)
  cdraw.content((11.3, 0.9), [no detector ships, so the barrier is the detector], size: 6pt)
})

sources: docs.python.org for the threading module page, accessed
2026-09-27, the Lock, RLock, Event, Barrier, Semaphore, BoundedSemaphore,
and Condition entries read for their guarantees, the queue module page
for Queue's FIFO and sentinel idioms, the hashlib page for sha256 and
hexdigest, and the 3.14 what's new page for threading.Thread.start
setting the operating system thread name (gh-59705) and PEP 779 making
free-threaded builds officially supported, the If-Match and
If-None-Match semantics read from RFC 9110 sections 13.1.1 and 13.1.2
at rfc-editor.org at the same date. Verified by the conc family's 25
tests in tests/test_conc.py plus the two duel tests in
tests/test_duel.py, under the pyapi gate, with the etag lane pinned
against the frozen vectors 09 through 12 by computing their digests
rather than copying them.
