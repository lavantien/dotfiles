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

A service that has never been loaded is a service whose p99 is a
guess, and a deploy that has never been drained is a deploy that
drops requests every time it ships. This chapter closes the service
part with the tools that make both claims checkable: the closed-loop
and open-loop harness over an injected clock and delayer, the report
table and its honest percentiles, the benchmark discipline with its
committed capture, graceful shutdown over the host's lifetime events,
the admission gate that answers overload at the cap, and the task
leak guard that holds the harness itself honest after a run.

== the load harness

The two loops differ in what they hold constant. The closed loop
holds concurrency constant: worker tasks, each firing one request at
a time and starting the next only after the previous response lands,
so offered load is whatever the host can keep up with and never
exceeds the worker count. It measures a system at a chosen
concurrency. The open loop holds arrival rate constant: request i is
scheduled at i over rate seconds past the start, fired whether or not
anything has come back, so when the host slows, requests pile up
exactly the way they do in production, and the cliff becomes visible.
Little's law from chapter 30 predicts the pile: in-flight equals
arrival rate times service time, and an open loop at fixed arrival
rate turns rising latency directly into rising in-flight count.

Both loops share one harness with three injected seams: the client,
so tests drive deterministic responses through a stub transport that
advances the clock one millisecond per request and never opens a
socket, the clock, so latency is arithmetic on ticks, and the
delayer, so the open loop's pacing is a function the test can call
instantly while still asserting the schedule. Warmup runs first on
every loop and never touches the sink, because the first request pays
for the dial and the cold caches, and none of that is the number the
run exists to measure:

#listing("csharp-net/api/src/CsharpBook.Api/Load/LoadHarness.cs", first: 79, last: 104, caption: [the closed loop: warmup first, one request at a time per worker, elapsed from the injected clock])

#diagram([workers, host, latency sink: one harness, two loops], length: 13pt, {
  let step(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.8), (x0 + 5.6, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.8, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.8, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.8, 4.2), [#l2], size: 6pt)
  }
  step(0.3, [closed loop], [workers wait for each], [response, capped])
  cdraw.line((6.1, 5.2), (6.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(6.7, [open loop], [schedule i/rate s], [fires regardless])
  cdraw.line((12.5, 5.2), (13.1, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(13.1, [http client], [injected transport], [or the test server])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [sink], [latencies, statuses], [warmup excluded])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [fixed rate, watch L climb])
  cdraw.content((17.2, 1.4), [same harness, two loops, one report format], size: 6pt)
})

== the report

One run folds into one row. The percentiles are nearest rank, the
corpus definition from chapter 31, computed over the sorted
latencies, and the achieved rate is the recorded count over the
elapsed span the injected clock measured. Rendering pads fixed
columns with the unit in the header, because a latency column that
does not say milliseconds is a unit error waiting for a reader.

The golden test pins the bytes from a fixed latency set, and it pins
them twice. The first row summarizes the raw samples. The second
summarizes the same samples as a scraper would see them, cumulative
histogram counts, exact count and sum, percentiles read out of the
buckets, and the row says so in its source column: six latencies of
1, 1, 2, 3, 5, and 8 milliseconds give an exact p50 of 2 and p99 of
8, while the bucketed row reads p50 as 2.5 and p99 as 10, the bounds
the ranks land in. Two rows, same run, the difference is the
resolution a histogram throws away, stated in the table instead of
hidden in a footnote:

#listing("csharp-net/api/src/CsharpBook.Api/Load/LoadReport.cs", first: 28, last: 53, caption: [Summarize: nearest rank over the sorted latencies, the source column labels every approximation])

#diagram([p99 under offered-load steps: where the cliff shows in the table], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [offered load], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.2), stroke: luma(120))
  cdraw.content((0.6, 7.4), [p99, ms], size: 6pt)
  cdraw.line((0.6, 2.0), (7.0, 2.2), stroke: luma(60))
  cdraw.line((7.0, 2.2), (14.0, 3.0), stroke: luma(60))
  cdraw.line((14.0, 3.0), (18.0, 5.6), stroke: luma(60))
  cdraw.line((18.0, 5.6), (23.2, 7.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((7.0, 0.7), (7.0, 6.4), stroke: luma(180), dash: "dashed")
  cdraw.line((14.0, 0.7), (14.0, 6.4), stroke: luma(180), dash: "dashed")
  cdraw.content((3.6, 1.3), [warm and flat], size: 6pt)
  cdraw.content((10.4, 1.5), [queueing starts], size: 6pt)
  cdraw.content((16.0, 3.6), [saturation], size: 6pt)
  cdraw.content((21.0, 5.9), [cliff], size: 6pt)
  pane(8.0, 23.2, 7.0, [each step is one row], [same rps, rising p99], [the table, not the vibe])
})

== the benchmark discipline

A single benchmark number is weather, the profiling chapter of the
language part already said so, and this part's discipline is the same
one: measure both sides over many iterations, commit the capture,
quote it with its date and machine. The language part's benchmark
harness is BenchmarkDotNet in the samples tree, and the suite chapter
carries the full story of why a vehicle that is stdlib exclusive by
ruling runs its book-side benchmarks there and its vehicle-side
measurements here: a separate csproj outside the solution is not this
chapter's to add, so the leg is an xunit fact tagged
[Trait("bench", "true")], runnable on demand with a filter, and the
capture is a hand-run of it committed beside the code.

The two sides are the route bare, one write through the kernel's json
path, and the same route under the cross-cutting stack this part
built, tracing with a collector attached so spans cost real work, the
request id scope, metrics with the histogram tick, admission, and
drain counting. The leg asserts only the structural claim, that the
observed stack costs more than the bare route, and prints the
numbers, and the capture quotes them:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Load/captures/2026-09-26-bench.txt", first: 1, last: 12, caption: [the committed capture, 2026-09-26, a hand-run of the trait-filtered leg, this machine])

Reading it: the bare route answers in about 1.9 to 2.1 microseconds
with a spread under ten percent, the observed route in about 5.0 to
5.3 microseconds, roughly 2.5 times, which is the per-request price
of every cross-cutting chapter combined. Five microseconds is also
the right scale check: the stack costs microseconds against a login
that costs tens of milliseconds of pbkdf2, and knowing which costs
dominate is the whole skill.

#diagram([the bench flow: leg, capture, quote], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.2), (x0 + 5.2, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.8), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 4.8), [#l1], size: 6pt)
  }
  stage(0.3, [two legs], [bare, observed])
  cdraw.line((5.7, 5.3), (6.1, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [20k iterations], [after 2k warmup])
  cdraw.line((11.5, 5.3), (11.9, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [capture], [3 runs, committed])
  cdraw.line((17.3, 5.3), (17.7, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [the quote], [dated, this machine])
  cdraw.content((17.6, 2.9), [1.9 to 2.1 vs 5.0 to 5.3 microseconds, about 2.5x], size: 6pt)
  cdraw.content((17.6, 1.8), [asserts only: observed costs more], size: 6pt)
})

== graceful shutdown

Shutdown has an order, and the order is the contract. Readiness
flips first: the drainer's state moves to draining, /readyz answers
its 503 overload envelope, and every load balancer watching the
service stops routing new requests here while the old ones are still
being answered well. Then the host stops the server, which refuses
new connections at the transport level. Then the drain waits for
in-flight requests to finish under a grace deadline, and reports the
deadline instead of pretending the drain succeeded when grace expires
with work still inside, so the caller decides whether that is fatal.

The platform hook is IHostApplicationLifetime. The host raises
ApplicationStopping before it stops the server and waits for the
registered callbacks under its own shutdown timeout, which is what
makes the drain run while the listener is still answering the in
flight requests, and the drainer's readiness probe re-binds the
kernel's config hub, last registration wins, so the frozen /readyz
route of chapter 22 answers the drain state without a line of its
own changing:

#listing("csharp-net/api/src/CsharpBook.Api/Load/WireLoad.cs", first: 48, last: 66, caption: [the host hook: flip readiness on ApplicationStopping, drain under grace before the server stops])

#diagram([SIGTERM to drain to exit, against the hard kill], length: 13pt, {
  let t(x0, w, title, fill) = {
    cdraw.rect((x0, 5.0), (x0 + w, 6.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + w / 2, 5.6), [#title], size: 6pt)
  }
  cdraw.content((11.5, 8.1), [graceful], size: 6.5pt)
  t(0.4, 4.0, [serving], luma(235))
  cdraw.line((4.6, 5.6), (4.6, 4.4), stroke: luma(100))
  cdraw.content((4.6, 3.8), [SIGTERM], size: 6pt)
  t(4.8, 4.4, [readyz 503], luma(215))
  t(9.4, 4.6, [server stopping], luma(215))
  t(14.2, 4.6, [in-flight drain], luma(205))
  t(19.0, 4.2, [exit 0], luma(235))
  cdraw.content((4.6, 2.5), [the in-flight request still gets its 200], size: 6pt)
  cdraw.content((16.5, 4.2), [grace deadline], size: 6pt)
  cdraw.content((11.5, 1.4), [the hard kill: everything between SIGTERM and exit 0 becomes a dropped connection], size: 6pt)
})

== testing shutdown without sleeps

The drain tests are observations on gated state, and none of them
wait on a timer. The slow request blocks on a completion source the
test holds. BeginDrain flips readiness synchronously, no yield
needed. DrainAsync is observed pending while the gate holds, then
the release completes the source, the in-flight count reaches zero,
and the drain returns true on the same asynchronous flow. The grace
expiry test runs DrainAsync with a zero deadline over a held request
and asserts the false it owes, and the empty-service test drains
instantly because there is nothing inside. The watchdog guards are
WaitAsync timeouts on real state, not sleeps:

#listing("csharp-net/api/src/CsharpBook.Api/Load/Drainer.cs", first: 104, last: 118, caption: [DrainAsync: wait on real in-flight state under a deadline, report the expiry])

#diagram([the drain lifecycle: serving, draining, closed], length: 13pt, {
  let st(x0, name, l1, fill) = {
    cdraw.rect((x0, 3.6), (x0 + 6.0, 5.8), fill: fill, radius: 0.02)
    cdraw.content((x0 + 3.0, 5.2), [#name], size: 6.5pt)
    cdraw.content((x0 + 3.0, 4.2), [#l1], size: 6pt)
  }
  st(0.4, [serving], [readyz 200, requests counted], luma(235))
  cdraw.line((6.6, 4.7), (7.4, 4.7), stroke: luma(100), mark: (end: ">>"))
  st(7.4, [draining], [readyz 503, fresh refused], luma(215))
  cdraw.line((13.6, 4.7), (14.4, 4.7), stroke: luma(100), mark: (end: ">>"))
  st(14.4, [closed], [drained or deadline reported], luma(205))
  pane(0.4, 11.0, 2.4, [the 503 carries], [code overload], [contract ruling])
  pane(8.0, 21.0, 2.4, [the two exits], [true: everything drained], [false: grace expired])
})

== admission control

The rate limit of chapter 30 bounds arrivals over time. The admission
gate bounds requests inside the service at once, and the mechanism is
a counting semaphore: one SemaphoreSlim sized to the capacity, a
nonblocking Wait to take a slot, the release riding a finally block,
so a handler that throws still releases. The nonblocking wait is the
whole policy: a slot is taken when one is free, and when the gate is
full the answer is immediate, the contract's overload envelope at
503, never a queue, because a queued request holds memory and a
connection the service just proved it cannot spend. The capacity is
the deployment's honest concurrency, worker and memory budget, not
what a client would like.

The barrier test pins exactly who gets in: a gate of four, four
holders each blocked after entering, observed through their own
completion sources, InFlight reads exactly the cap, four synchronous
arrivals all answer the envelope, the barrier opens and the holders
finish. Little's law closes the loop: at a fixed arrival rate the
gate caps L, and capped L with rising service time means the excess
is refused at the door instead of queueing inside:

#listing("csharp-net/api/src/CsharpBook.Api/Load/AdmissionGate.cs", first: 31, last: 52, caption: [the gate: nonblocking take, finally release, overload envelope at the cap])

#diagram([latency versus in-flight: the hockey stick the gate cuts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight, L], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.6, 7.6), [latency, W], size: 6pt)
  cdraw.line((0.6, 1.3), (11.0, 1.8), stroke: luma(60))
  cdraw.line((11.0, 1.8), (15.0, 5.4), stroke: luma(60))
  cdraw.line((15.0, 5.4), (17.8, 7.3), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.5, 1.0), [below capacity: no queue], size: 6pt)
  cdraw.content((13.6, 3.3), [queueing], size: 6pt)
  cdraw.line((12.4, 0.7), (12.4, 6.6), stroke: luma(150), dash: "dashed")
  cdraw.content((12.4, 7.0), [the cap], size: 6pt)
  pane(13.6, 23.2, 3.0, [past the cap], [503 overload, instantly], [no task spent])
  cdraw.content((7.2, 6.0), [L = rate x W: the rate limit caps rate], size: 6pt)
  cdraw.content((7.2, 4.9), [the gate caps L itself], size: 6pt)
})

== the task leak check

A load tool that leaks tasks per run silently slows every later run
and lies about the service it measures. The go lane asks its runtime:
the goroutine leak profile names the goroutines that are blocked and
unreachable, which is the definition of a leak. This lane asks the
harness itself, because the runtime offers no equivalent profile: the
harness tracks every task it starts through the counting tracker, the
count drops the moment each task completes by whatever outcome, and
the leak test runs one real harness pass against the in-process test
server, then asserts the count is zero and the tracker's idle task is
done, the WaitAsync guard a watchdog, not a sleep. On failure the
outstanding count is the number to read: a tool that fire and forgets
its workers reports it immediately:

#listing("csharp-net/api/src/CsharpBook.Api/Load/TaskTracker.cs", first: 26, last: 44, caption: [the tracker: count up at start, count down on completion, idle completes at zero])

#diagram([a task lifecycle: born, joined, or leaked], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [born], [worker, pacer])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [does its work], [request, pacing wait])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [completes], [count drops, any outcome])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [gone], [tracker idle])
  pane(0.3, 11.4, 2.6, [the leak], [count never drops], [the test reads the number])
  pane(12.0, 23.2, 2.6, [the check], [after one real run], [count zero, idle done])
})

sources: learn.microsoft.com for IHostApplicationLifetime and its
ApplicationStopping semantics with the host shutdown timeout, for
SemaphoreSlim's nonblocking Wait and its counter, and for
Task.WaitAsync as a deadline on real work, all accessed 2026-09-26,
plus the little's law statement as used across the corpus. Verified
by the `CsharpBook.Api.Load` tests, 14 of them under `dotnet test
Api.slnx`, one of them the bench leg whose committed capture is
quoted above from a Release hand-run on this machine, a 12th gen
i7-12700F under windows, plus `dotnet format` over the files the
chapter added.
