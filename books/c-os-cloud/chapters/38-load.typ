#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= load and p99

A service that has never carried load has never been tested. The
questions load answers are quantitative: how many requests per second
sustains, what the 99th percentile latency does as concurrency rises,
where the queueing starts, and whether a deploy can stop without
dropping a single in-flight request. This chapter builds the load side
of the service in `c-os-cloud/api/src`: the measurement half of the
harness with its committed captures, the percentile math done honestly
on sorted samples and on the metrics histogram, the admission gate
that refuses excess concurrency at the edge, the drain that flips
readiness before it joins the in-flight, and the handle ledger that
catches what a load run leaks.

== the load harness

A load harness is a driver and a ledger. The driver offers work at a
chosen concurrency: a fixed number of closed-loop workers, each doing
one request at a time, so the offered load is the worker count divided
by the observed latency and the harness never piles up an unbounded
queue of its own making. The ledger is what this chapter owns outright
today: every request's milliseconds land in a sample array, the array
is sorted in a caller-owned scratch, and the report renders count,
min, p50, p99, and max from the sorted copy while the original samples
stay untouched for any later question. The wave over the live server
sequences behind the kernel's socket layer, and when it lands the
capture is committed data under the chapter 20 discipline: a file
labeled with the toolchain and the date, never re-measured by the
verify chain, because a benchmark that runs on every build is a flaky
test wearing a lab coat:

#listing("c-os-cloud/api/src/load_report.c", first: 26, last: 37, caption: [the report: sorted in scratch, nearest-rank percentiles, the samples untouched])

#diagram([the harness: closed-loop workers into samples into the report], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [closed-loop workers], [1 request at a time each])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [the service], [gate, handler, metrics])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [sample array], [1 double per request, ms])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [the report], [count, min, p50, p99, max])
  pane(0.3, 11.2, 3.0, [offered load], [workers / observed latency], [never an unbounded queue])
  pane(12.0, 23.0, 3.0, [the capture], [committed, toolchain labeled], [never run by verify])
})

== p99 from the histogram

A percentile has exactly one honest definition here, nearest rank: the
ceil of p over 100 times n, the k-th smallest value, clamped at both
ends. p99 of 1 through 100 is 99, p99 of 200 values is 198, p99.9 of
100 values clamps to the max, and p0 clamps up to the smallest. Averages
hide tails, medians hide them better, and a 99th percentile computed
any other way is usually an interpolation nobody agreed to.

The histogram answers the same question from the metrics the service
already keeps, and its answer is an upper bound stated as one: walk
the cumulative buckets, return the smallest finite bound whose
cumulative count reaches the rank. The walk never guesses inside a
bucket, and a rank that lands in the +Inf bucket answers unknown,
because the only true statement there is "worse than the last bound".
That refusal is the difference between an approximation and a lie:

#listing("c-os-cloud/api/src/load_quantile.c", first: 20, last: 38, caption: [the cumulative walk: smallest bound reaching the rank, +Inf answers unknown])

#diagram([one rank walking the cumulative buckets], length: 13pt, {
  cdraw.line((0.6, 0.8), (23.2, 0.8), stroke: luma(120))
  cdraw.content((23.4, 0.8), [bound, seconds], size: 6pt)
  let bars = ((.001, 1), (.005, 2), (.05, 2), (.5, 2), ("+Inf", 3))
  let x = 1.0
  for (label, h) in bars {
    cdraw.rect((x, 0.8), (x + 3.6, 0.8 + h * 1.6), fill: luma(215), radius: 0.02)
    cdraw.content((x + 1.8, 0.4), [#label], size: 6pt)
    cdraw.content((x + 1.8, 0.8 + h * 1.6 + 0.4), [#h], size: 6pt)
    x += 4.6
  }
  cdraw.content((4.5, 6.4), [rank 2: first cum reaching 2 is the 0.005 bound], size: 6pt)
  cdraw.content((4.5, 5.5), [rank 3: only +Inf holds 3, answer unknown], size: 6pt)
  pane(15.4, 23.2, 4.6, [never a guess], [no interpolation inside], [a bucket is a floor, not a value])
})

== admission control

Little's law from chapter 36 caps the argument: the requests inside
the system equal the arrival rate times the time each spends there,
and past the point where every arriving request finds all workers
busy, latency climbs while throughput does not. The gate caps the
inside count directly. It is a counting semaphore with the service's
honest concurrency as its capacity, 64 slots for this lane's worker
budget, and the admission edge never blocks: `try` takes a slot under
the lock or refuses immediately, and the refused caller gets the
contract's overload envelope, never a queue, because a queued request
spends memory and a thread on work the service has already proven it
cannot keep up with. A reachability fact belongs beside the capacity:
the shipped process runs 8 pool workers plus the single metrics
accept thread, so held slots top out at 9 and the accept queue bounds
concurrency below the gate, which means the 503 refusal, real and
pinned by the composition suite in isolation with 64 dedicated
holders and a refused 65th, is not reachable through the running
binary until the pool grows or the gate shrinks. The go lane's gate
is the true bound there because goroutines are unbounded.

The semaphore is composed, not taken: a counter, an srw lock, and one
auto-reset event, which is the derivation this book owes instead of
calling `CreateSemaphore` and moving on. The blocking leg exists for
callers that must wait, and its park is the chapter's centerpiece:
the event holds one signal, so a release that fires between a waiter's
check and its park is still consumed, the lost-wake bug of chapter 16
fixed by the primitive's own durability where a condition variable
would have forgotten the wake entirely:

#listing("c-os-cloud/api/src/load_gate.c", first: 26, last: 48, caption: [the gate: refuse at the edge under the lock, park on the durable event])

#diagram([the gate as a slot counter: try at the edge, park only if you must], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [held < capacity?], size: 6pt)
  cdraw.line((9.2, 5.5), (5.4, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.8, 5.5), (17.6, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.4, 9.4, 4.4, [admitted], [held++, whole request life], [release: held--, SetEvent])
  pane(13.6, 21.6, 4.4, [refused], [the overload envelope], [503 now, never a queue])
  for i in range(8) {
    cdraw.rect((1.4 + i * 2.7, 1.0), (3.6 + i * 2.7, 2.4),
      fill: luma(if i < 5 { 160 } else { 235 }), radius: 0.02)
  }
  cdraw.content((11.5, 0.3), [the slot row: 5 of 8 held, the 6th arrival is told the truth], size: 6pt)
})

== graceful shutdown

Shutdown has an order, and the order is the contract. Readiness flips
first: the drain's state moves to draining and every load balancer
watching the service stops routing new requests here while the old
ones are still being answered. Then the listener closes, so new
connections are refused at the tcp level, a step that lands with the
kernel's socket layer. Then the drain joins the in-flight: it waits
until the gate holds nothing, and its return value is the deploy's
exit code, 0 when everything drained, 1 when grace expired with work
still inside, so the caller decides whether that is fatal instead of
the helper pretending the drain succeeded. Since the admission layer
takes a slot around every request, the in-flight this joins is real,
and the wait's scope is the stack: a slot releases when the answer
exists, before the serve loop writes it, so an answer past the
handler can still be cut mid-send at exit, the boundary the ship
chapter states plainly.

The wait polls real state, not a timer. Each pass checks the gate's
held count under its lock, parks on the gate's durable event until a
release fires, and only the deadline leg reads a clock at all. The
misuse answer is its own value: waiting before the drain began is a
programmer error, reported as minus 1, not a success:

#listing("c-os-cloud/api/src/load_gate.c", first: 128, last: 152, caption: [the drain: poll held under the lock, park on the event, report the deadline])

#diagram([the drain lifecycle: serving, draining, closed, the two exits], length: 13pt, {
  let st(x0, name, l1, fill) = {
    cdraw.rect((x0, 3.6), (x0 + 6.0, 5.8), fill: fill, radius: 0.02)
    cdraw.content((x0 + 3.0, 5.2), [#name], size: 6.5pt)
    cdraw.content((x0 + 3.0, 4.2), [#l1], size: 6pt)
  }
  st(0.4, [serving], [readyz 200, listener open], luma(235))
  cdraw.line((6.6, 4.7), (7.4, 4.7), stroke: luma(100), mark: (end: ">>"))
  st(7.4, [draining], [readyz 503, new refused], luma(215))
  cdraw.line((13.6, 4.7), (14.4, 4.7), stroke: luma(100), mark: (end: ">>"))
  st(14.4, [closed], [in-flight drained or deadline], luma(205))
  pane(0.4, 11.0, 2.4, [readiness first], [the 503 carries overload], [contract ruling])
  pane(8.0, 21.0, 2.4, [the two exits], [0: everything drained], [1: grace expired])
  cdraw.content((11.0, 0.9), [load balancers see the 503 first, the join covers the stack, a mid-send answer can still be cut], size: 6pt)
})

== shutdown without sleeps

Every interleaving in this family's tests is chosen with event
handles, not timed with sleeps, the discipline chapter 15 established.
A worker parks on a named event the test fires, the test parks on the
worker's acknowledgement event, and the orderings that would be races
become sequences a reader can step through. The one bounded timeout in
the file is the drain's 40 millisecond grace under test, which is the
deadline doing its job, not a sleep sequencing a test.

The centerpiece proves the durable wake. The worker signals that it
saw a full gate, then parks in the blocking acquire. The test releases
the slot the instant it sees the signal, so the release's `SetEvent`
almost certainly fires before the worker's wait even begins, and the
join still succeeds: the auto-reset event held the signal. The same
shape on a condition variable is the lost wake of chapter 16, where a
wake with nobody asleep on the condition is forgotten and the sleeper
burns its timeout. Workers run on both thread surfaces the book
teaches, c23 `thrd_create` for the parking workers and one win32
`CreateThread` leg in the lifecycle test, because the chapter 15
ruling is that the reader meets both, side by side, not one hidden
behind a macro:

#listing("c-os-cloud/api/tests/test_load.c", first: 95, last: 112, caption: [the durable wake test: release immediately after the refusal, join still succeeds])

#diagram([the same interleaving on two primitives: the cv forgets, the event holds], length: 13pt, {
  let lane(y0, title) = {
    cdraw.content((2.6, y0 + 1.9), [#title], size: 6.5pt)
  }
  lane(6.0, [condition variable])
  cdraw.content((0.6, 6.2), [wake fires, nobody asleep], size: 6pt)
  cdraw.content((13.4, 6.2), [sleeper parks, waits, times out], size: 6pt)
  cdraw.line((12.6, 6.6), (13.2, 6.6), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((0.6, 5.5), (23.2, 5.5), stroke: luma(120))
  lane(2.6, [auto-reset event])
  cdraw.content((0.6, 2.8), [SetEvent fires, event stays set], size: 6pt)
  cdraw.content((13.4, 2.8), [waiter takes the pending signal], size: 6pt)
  cdraw.line((12.6, 3.2), (13.2, 3.2), stroke: luma(60), mark: (end: ">"))
  pane(6.4, 17.4, 0.4, [durability], [one signal held until consumed], [the lost wake cannot happen])
  cdraw.content((11.5, -0.3), [the gate composes the second row, and its tests force the risky interleaving on purpose], size: 6pt)
})

== the handle ledger

In go a leak is a goroutine that never returns, found by counting
them. In c a leak is a handle that never closes, and the kernel keeps
the ledger for you: `GetProcessHandleCount` reports the process's open
handles, and a load family that creates an event per gate and a
thread per worker must return the count to baseline after every run.
The test is 50 gate lifetimes, init through try, release, close, and
the count after is the count before. Handles are the resource the
whole chapter spends, the gate's event, the test's scheduling events,
the worker threads, and each has an owner whose close is checked,
because a handle leaked per request is a service that dies at some
exact number of requests and takes the deploy pipeline with it:

#listing("c-os-cloud/api/src/load_gate.c", first: 65, last: 81, caption: [close owns the handle once, and the ledger probe reads the kernel's own count])

#diagram([the ledger: 50 lifetimes, flat by construction], length: 13pt, {
  cdraw.line((0.6, 0.8), (23.2, 0.8), stroke: luma(120))
  cdraw.line((0.6, 0.8), (0.6, 6.4), stroke: luma(120))
  cdraw.content((0.2, 6.6), [handles], size: 6pt)
  cdraw.line((0.6, 4.6), (23.0, 4.6), stroke: luma(60))
  cdraw.content((23.4, 4.6), [baseline], size: 6pt)
  for i in range(12) {
    cdraw.line((1.6 + i * 1.8, 4.6), (2.6 + i * 1.8, 4.6 + 1.4), stroke: luma(140))
    cdraw.line((2.6 + i * 1.8, 6.0), (3.2 + i * 1.8, 4.6), stroke: luma(140))
  }
  cdraw.content((7.0, 2.6), [50 gate lifetimes, each closes], size: 6pt)
  pane(15.0, 23.2, 6.2, [the assertion], [after <= before + 2], [the kernel is the witness])
})

== the service under load

One wave ties the part together. Workers offer closed-loop requests
through the gate, each admitted request holds its slot for its whole
life, the metrics family counts it and observes its seconds, the
access log writes its line with the request id, and when the wave ends
the drain flips readiness, joins the last in-flight, and hands the
deploy its exit code. The lifecycle test runs the shape with one
win32 worker: the worker takes a slot and parks on a named event, the
drain begins, readiness reads 0 while the slot is still held, the
worker completes and carries its exit code out of the thread, and the
drain closes clean. 48 checks carry the family, the quantile tables
included, and not one of them sleeps to sequence anything:

#listing("c-os-cloud/api/tests/test_load.c", first: 133, last: 155, caption: [the lifecycle: flip readiness with work inside, join, close, carry the exit code])

#diagram([one wave: gate, metrics, log, drain, exit code], length: 13pt, {
  let hit(x, label) = {
    cdraw.circle((x, 4.0), radius: 0.28, fill: luma(160))
    cdraw.content((x, 4.9), [#label], size: 6pt)
  }
  cdraw.line((0.6, 4.0), (23.4, 4.0), stroke: luma(120))
  cdraw.content((23.6, 4.0), [time], size: 6pt)
  hit(1.8, [gate admits])
  hit(5.4, [handler runs])
  hit(9.0, [metrics, log])
  hit(12.6, [release])
  hit(16.2, [drain begins])
  hit(19.8, [exit 0])
  pane(0.6, 8.6, 2.0, [per request], [slot held for life], [id in every signal])
  pane(13.8, 23.4, 2.0, [at the end], [readiness 503 first], [join, then exit code])
  cdraw.content((11.5, 1.2), [little's law holds the whole picture: the gate caps the inside count, the drain empties it], size: 6pt)
})

sources: learn.microsoft.com's synchapi pages for CreateEventW and its
auto-reset semantics, SetEvent, WaitForSingleObject, and
SleepConditionVariableSRW's wake rules, the handleapi page for
GetProcessHandleCount, and the processthreadsapi page for GetExitCodeThread,
all accessed 2026-09-27, prometheus.io's histogram documentation for
why bucket quantiles are approximations, accessed 2026-09-27, and
Little's 1961 proof of the queuing formula for the load arithmetic
chapter 36 previewed. Verified by the load family's 48 checks, run
from its one entry in the lane's test runner under the pinned clang 23,
workers on both thread surfaces, plus clang-format over every file
touched.
