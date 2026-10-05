#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= load and p99

A service whose p99 is a guess is a service shipped on faith. This
chapter builds the tool that replaces the guess, `javabook.load`, and
then points it at the real server: the closed loop and the open loop
over 3 injected seams, the report with its honest percentiles read out
of chapter 28's arithmetic, and the dated captures this machine
produced, ladder, cliff, and budget, committed beside the code. The go
book built the same harness around a `RoundTripper` seam,
#xref-to("go", "load"), and the java lane builds it around a virtual
thread per worker and a blocking `send`, which is the same design in
the other idiom: park the thread, never pool it.

== the two loops

The closed loop holds concurrency constant: `workers` virtual threads,
each firing one request at a time and starting the next only after the
previous response lands, so offered load is whatever the server can
keep up with and never exceeds the worker count. The open loop holds
arrival rate constant: one pacer schedules arrival `i` at `i` periods
past the start and fires it on its own virtual thread whether or not
anything has come back, so when the server slows, requests pile up
exactly the way they do in production, and the cliff becomes visible.
Little's law, in flight equals arrival rate times service time,
predicts the pile: an open loop at fixed arrival rate turns rising
latency directly into a rising in-flight count:

#listing("java/api/src/javabook/load/Harness.java", first: 73, last: 86, caption: [the closed loop: one virtual thread per worker, joined, warmup lands nowhere in the sink])

#listing("java/api/src/javabook/load/Harness.java", first: 94, last: 118, caption: [the open loop: warmup establishes the pool, the pacer fires on schedule regardless of in flight])

#diagram([workers, pacer, server, sink: one harness, two loops], length: 13pt, {
  let step(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.8), (x0 + 5.6, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.8, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.8, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.8, 4.2), [#l2], size: 6pt)
  }
  step(0.3, [closed loop], [workers wait for each], [offered = workers])
  cdraw.line((6.1, 5.2), (6.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(6.7, [open loop], [arrival i at i periods], [fires regardless])
  cdraw.line((12.5, 5.2), (13.1, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(13.1, [the op], [injected: fake or socket], [status answers])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [the sink], [latencies, statuses], [warmup excluded])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [fixed rate, watch L climb])
  cdraw.content((17.2, 1.4), [a fire that never answers is data, not a crash], size: 6pt)
  cdraw.content((17.2, 0.3), [the errors row is where a run reads its own ceiling], size: 6pt)
})

Both loops share the 3 seams: the op, so tests drive deterministic
responses with no socket, the clock, so latency is arithmetic on
ticks, and the sleeper, so the open loop's pacing is a function the
test steps instead of a wall it waits on. A fire that throws is not a
crash, the round records it as an error and keeps offering, because a
load tool that dies on the first refused connection loses exactly the
data the cliff produces. Only a run where nothing ever answered exits
red.

== tested without sleeping

The harness tests run under a frozen clock and a fake sleeper, the
same discipline every time-dependent test in this spine kept: the
closed loop with 1 worker, 3 warmup, 5 measured, and an op that costs
100 ticks answers with 8 fires, 5 latencies of exactly 100, and a
warmup count of 3, deterministic under any scheduler because the
clock only moves when the fakes move it:

#listing("java/api/test/javabook/load/LoadTests.java", first: 60, last: 73, caption: [warmup excluded and latencies exact, all under arithmetic])

The open loop's own test pins the property the loop exists for: with
one arrival per 10 nanos and an op costing 50, all 4 arrivals fire,
because a slow server never holds back an open loop's schedule. The
interleaved latencies are asserted only from below, at least the op's
cost, since 2 workers sharing one frozen clock can stretch a window
but never shrink one.

== the report

One run folds into one report: the mode line naming the loop's
parameters, the elapsed window measured from the first measured start
to the last measured end so warmup cannot inflate the rate, the status
histogram, the protocol the responses actually rode, and the 4
percentiles by nearest rank, every column naming its unit:

#listing("java/api/src/javabook/load/Report.java", first: 19, last: 45, caption: [the whole report: units in every header, nearest rank underneath, errors only when they happened])

The golden test pins the bytes from a fixed vector, 6 latencies of 1,
1, 2, 3, 5, and 8 milliseconds over an 8 millisecond window: 750 rps,
p50 of 2, and p90, p99, and p99.9 all clamped to 8, the largest,
because a percentile past the data is a bound. The protocol column is
the report's honesty lever, and the client earns it a sentence: the
harness's one real op builds its `HttpClient` for HTTP/2, the kernel's
`jdk.httpserver` listener is HTTP/1.1 and refuses the upgrade, and the
client settles, so the report prints `HTTP_1_1` from
`response.version()` rather than pretending the negotiation won:

#listing("java/api/src/javabook/load/Load.java", first: 34, last: 46, caption: [one shared client built for HTTP/2, connect and request both timed, the version it actually got])

A blocking `send` on a virtual thread parks it, chapter 10's whole
contract, so 128 workers cost 128 parked stacks and no pool tuning,
and the one client shares its connections across all of them.

== the ladder, measured

The capture is dated, machine-named, and committed at
`books/java/api/captures/2026-10-05-load.txt`. The server is the real
`Main` on this machine's loopback, its budget raised through the
wiring's own `JBAPI_RATE_BURST` knob because the measurement's
subject is the stack, not the limiter, and the production budget gets
its own capture below:

#listing("java/api/captures/2026-10-05-load.txt", first: 10, last: 49, caption: [the ladder: 4 closed loops and one open loop, this machine, 2026-10-05])

Reading it: 1 worker answers 3358 rps, latency-bound on one
connection at a p50 of 0.243 ms. 8 workers reach 24633, 32 reach
51314, and 128 reach 52989, the plateau that says the server is
saturated and more workers only queue. The tail tells the same story
from the other end: p50 holds 0.21 to 0.48 ms through 32 workers and
only then moves, 2.035 ms at 128, while p99.9 climbs 1.8, 5.5, 20.5,
then 95.2 ms, queueing is what grows, and the percentile ladder is
where it shows. The open loop at 5000 offered
per second achieves exactly 5000 with all 10000 arrivals served, an
unremarkable number that is the point: below capacity, the open loop
confirms the closed loop's story, and only above capacity do the 2
designs differ.

#diagram([the ladder's p50 and p99.9 against offered load, the tail is the story], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [workers], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.6, 7.6), [ms], size: 6pt)
  cdraw.line((0.9, 6.9), (6.2, 6.85), stroke: luma(60))
  cdraw.line((6.2, 6.85), (12.0, 6.7), stroke: luma(60))
  cdraw.line((12.0, 6.7), (18.2, 6.1), stroke: luma(60))
  cdraw.line((18.2, 6.1), (23.2, 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.0, 7.1), [p50, nearly flat], size: 6pt)
  cdraw.line((0.9, 6.5), (6.2, 6.3), stroke: luma(120), dash: "dashed")
  cdraw.line((6.2, 6.3), (12.0, 5.4), stroke: luma(120), dash: "dashed")
  cdraw.line((12.0, 5.4), (18.2, 3.0), stroke: luma(120), dash: "dashed")
  cdraw.line((18.2, 3.0), (23.2, 1.2), stroke: luma(120), dash: "dashed", mark: (end: ">"))
  cdraw.content((16.0, 4.4), [p99.9, the queue], size: 6pt)
  cdraw.line((17.6, 0.7), (17.6, 6.4), stroke: luma(170), dash: "dotted")
  cdraw.content((17.6, 0.2), [saturation], size: 6pt)
  pane(1.0, 9.6, 2.6, [what grew], [throughput: 3358 to 52989], [then it stopped])
  cdraw.content((19.4, 8.0), [the plateau and the tail are the same fact read twice], size: 6pt)
})

== the cliff

Offered far past capacity, the same loop finds a ceiling, and on one
machine the first ceiling it meets may not be the server's:

#listing("java/api/captures/2026-10-05-load.txt", first: 50, last: 58, caption: [80000 offered per second: the pile, the errors, and the client machine's own port ceiling])

31296 of 40000 arrivals never answered, `ConnectException` on the
loopback because the client and server share one machine's ephemeral
port space, and the 8704 that landed queued behind the pile, p50 at
7.5 seconds. The honest reading is stated rather than laundered: this
run measured where the loopback fills, not where the service bends,
and a real capacity number needs the client on its own machine. What
the run does prove is the tool's own contract, the errors row counts
every refused fire, the percentiles cover what landed, and the report
survives its ceiling instead of dying on the first exception, which is
the difference between a measurement and a crash. The exit policy is
stated with the same plainness: only a run where nothing landed exits
red, so this cliff run exits 0 by design, partial failure is data and
the errors row is the signal, and a caller who wants a stricter gate
reads the row instead of the code.

== the production budget under load

The ladder raised the budget through `JBAPI_RATE_BURST`, and the
wiring's defaults are unchanged from chapter 27, burst 30 with one
refill per second per address. Against those defaults the same closed
loop meets the layer that chapter built:

#listing("java/api/captures/2026-10-05-budget.txt", first: 5, last: 12, caption: [8 workers offer 1600, the budget answers 30, the exposition counts both])

22 of 200 measured requests per worker answered 200, 1578 answered
429, and the exposition off the ops port reads 30 and 1578, the warmup
8 included, because chapter 28's filter seats outside the limiter and
ticks the refusals at the status that really went out. The run's
pooled p99, 4.7 ms across both statuses, is the limiter's design claim
measured: refusing is cheap, the flood costs the handler nothing, and
the budget is spent exactly where the token bucket said it would be.
The report pools its percentiles over every measured sample, 200s and
429s together, and says so plainly rather than attributing the number
to one status.

#callout("note", "the knob, not a bypass", [
  The measurement boot raises the budget through the same environment variable the wiring reads, `JBAPI_RATE_BURST`, whose default stays 30. Nothing about the deployed service changes, and the capture names the knob and its value in its header, so the number can never be mistaken for the default's behavior.
])

== what the run leaves behind

Three artifacts outlive the session, and they are the point of the
chapter. The captures, dated and committed, so the next run on the
next machine has a baseline to diff against and no one re-derives
today's numbers from memory. The exposition, whose counter row and
histogram cells carry the same run the report printed, one registry
observed from 2 sides. And the tool itself, 6 tests green, which is
what makes next quarter's number comparable to this one: a load
report nobody can rebuild byte for byte is a slide, not a measurement.

sources: the java.net.http javadoc for HttpClient version negotiation,
the HTTP/2 upgrade attempt over cleartext and the fallback to
HTTP/1.1, and HttpResponse.version, at docs.oracle.com/en/java/javase/27,
accessed 2026-10-05, verified live by the protocol column reading
HTTP_1_1 against the kernel's listener on this machine. Little's law
as stated across the corpus, #xref-to("go", "profiling") owns the
profiling-side treatment. Verified live 2026-10-05 by the
javabook.load tests, 6 green three consecutive runs under the vendored
junit 6.1.3 lane on tools/jdk27/build/jdk-27, and by the 3 committed
captures quoted above, measured on a 12th gen i7-12700F under
windows/amd64 with client and server on one loopback.
