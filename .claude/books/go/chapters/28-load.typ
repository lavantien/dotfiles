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
part with the tools that make both claims checkable: the open-loop
and closed-loop harness in `goapi/internal/loadtest`, the report
table and its honest percentiles, a benchstat comparison over
captures committed with the code, graceful shutdown as a new file in
the kernel's package, the admission gate that answers overload at the
cap, and the go 1.27 goroutine leak check that holds it all honest
after a run.

== the load harness

The two loops differ in what they hold constant. The closed loop
holds concurrency constant: `workers` goroutines, each firing one
request at a time and starting the next only after the previous
response lands, so offered load is whatever the server can keep up
with and never exceeds the worker count. It measures a system at a
chosen concurrency. The open loop holds arrival rate constant:
request `i` is scheduled at `i` over rate seconds past the start,
fired whether or not anything has come back, so when the server
slows, requests pile up exactly the way they do in production, and
the cliff becomes visible. Little's law from the rate limiting
chapter predicts the pile: in-flight equals arrival rate times
service time, and an open loop at fixed arrival rate turns rising
latency directly into rising in-flight count.

Both loops share one harness with three injected seams: the client,
so tests drive deterministic responses through a `RoundTripper`
function with no socket, the clock, so latency is arithmetic on
ticks, and the sleeper, so the open loop's pacing is a function the
test can call instantly while still asserting the schedule. Warmup
runs first on every loop and never touches the sink, because the
first request pays for the dial, the dns lookup, and the cold caches,
and none of that is the number the run exists to measure:

#listing("go/api/internal/loadtest/harness.go", first: 93, last: 114, caption: [the closed loop: warmup first, one request at a time per worker, elapsed from the injected clock])

#diagram([workers, server, latency sink: one harness, two clocks], length: 13pt, {
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
  step(13.1, [http client], [injected transport], [or real sockets])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [sink], [latencies, statuses], [warmup excluded])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [fixed rate, watch L climb])
  cdraw.content((17.2, 1.4), [same harness, two loops, one report format], size: 6pt)
  cdraw.content((17.2, 0.3), [warmup fires first and lands nowhere], size: 6pt)
})

== the report

One run folds into one row. The percentiles are nearest rank, the
corpus definition, computed by the observability package's helper
over the sorted latencies, and the achieved rate is the recorded
count over the elapsed span the injected clock measured. Rendering
goes through `tabwriter`, one header row and one row per run with
columns that name their unit, because a latency column that does not
say milliseconds is a unit error waiting for a reader.

The golden test pins the bytes from a fixed latency set, and it pins
them twice. The first row summarizes the raw samples. The second
summarizes the same samples as a scraper would see them, cumulative
histogram counts, exact count and sum, percentiles read out of the
buckets, and the row says so in its source column: six latencies of
1, 1, 2, 3, 5, and 8 milliseconds give an exact p50 of 2 and p99 of
8, while the bucketed row reads p50 as 2.5 and p99 as 10, the bounds
the rank lands in. Two rows, same run, the difference is the
resolution a histogram throws away, stated in the table instead of
hidden in a footnote:

#listing("go/api/internal/loadtest/report.go", first: 100, last: 111, caption: [the table: tabwriter aligned, units in the header, source column labeling the approximation])

#diagram([p99 under offered-load steps: where the cliff shows in the table], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [offered load], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.2), stroke: luma(120))
  cdraw.content((0.6, 7.4), [p99, ms], size: 6pt)
  // three load steps, p99 flat then climbing
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

== benchstat over committed captures

A single benchmark number is weather, the profiling chapter already
said so, and the discipline is the same one it taught: run both sides
ten times, let `benchstat` compute the statistics, quote the table,
commit the capture. The two sides here are the route bare, one
recorder round trip through the kernel's json write path, and the
same route under the full cross-cutting stack the shipped binary
runs, request id, access log, metrics with the histogram tick, the
admission gate, and recover. The capture lives with the code in
`captures/`, dated, twenty raw runs, and the summary is what the
chapter quotes:

#listing("go/api/internal/loadtest/captures/2026-09-25-benchstat.txt", first: 1, last: 9, caption: [benchstat over the committed capture, 2026-09-25, this machine])

Reading it: the bare route answers in 606.8 nanoseconds with a two
percent spread, the observed route in 2.002 microseconds with a nine
percent spread, about 3.3 times, which is the per-request price of
every cross-cutting chapter combined, and the intervals do not
overlap, so the ratio is structural rather than noise. Two
microseconds is also the right scale check: the stack costs about two
microseconds against a login that costs tens of milliseconds of
argon2, and knowing which costs dominate is the whole skill.

#diagram([the bench flow: code, capture, statistics, quote], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.2), (x0 + 5.2, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.8), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 4.8), [#l1], size: 6pt)
  }
  stage(0.3, [two benchmarks], [bare, observed])
  cdraw.line((5.7, 5.3), (6.1, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [count=10 each], [20 raw runs])
  cdraw.line((11.5, 5.3), (11.9, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [benchstat], [mean and interval])
  cdraw.line((17.3, 5.3), (17.7, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [the quote], [capture committed too])
  pane(0.3, 11.4, 3.2, [the capture], [captures/2026-09-25-stack.txt], [dated, 20 runs, raw])
  cdraw.content((17.6, 2.9), [overlapping intervals would mean: unproven], size: 6pt)
  cdraw.content((17.6, 1.8), [606.8n vs 2.002u, about 3.3x, structural], size: 6pt)
})

== graceful shutdown

Shutdown has an order, and the order is the contract. Readiness
flips first: the drainer's state moves to draining, `/readyz` answers
its 503 overload envelope, and every load balancer watching the
service stops routing new requests here while the old ones are still
being answered well. Then the listener closes, so new connections
are refused at the tcp level. Then `Server.Shutdown` waits for
in-flight requests to finish under a grace deadline, and returns the
deadline error when grace expires with work still inside, so the
caller decides whether that is fatal instead of the helper pretending
the drain succeeded.

The serve helper is one new file in the kernel's package, `shutdown.go`,
next to the code it drains, touching none of the kernel's pinned
files. It takes the listener rather than an address, which is what
makes it testable: the test owns the port, the helper owns the
lifecycle, and the drainer is shared state the readiness route
already reads through the config hook. The wiring in the program's
table replaces the plain serve tail: build the drainer, install it as
the app's readiness probe, serve on a signal context, drain with
thirty seconds of grace. The frozen `main.go` prefix keeps its
byte-stable tail and simply never reaches it, which is the one
sanctioned way this part adds a serve path without editing a pinned
listing:

#listing("go/api/internal/httpx/shutdown.go", first: 83, last: 98, caption: [Serve: serve until ctx dies, flip readiness, drain under grace, report the deadline])

#snippet("dr := httpx.NewDrainer()\napp.SetReady(dr.Ready)\nsrv := &http.Server{Handler: app.Handler(), ReadHeaderTimeout: 5 * time.Second}\nctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)\ndefer stop()\nln, err := net.Listen(\"tcp\", httpx.ConfigFromEnv().Addr)\nif err != nil { log.Fatal(err) }\nif err := httpx.Serve(ctx, ln, srv, dr, 30*time.Second); err != nil { log.Fatal(err) }", lang: "go")

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
  t(9.4, 4.6, [listener closed], luma(215))
  t(14.2, 4.6, [in-flight drain], luma(205))
  t(19.0, 4.2, [exit 0], luma(235))
  cdraw.content((4.6, 2.5), [the in-flight request still gets its 200], size: 6pt)
  cdraw.content((16.5, 4.2), [grace deadline], size: 6pt)
  cdraw.content((11.5, 1.4), [the hard kill: everything between SIGTERM and exit 0 becomes a dropped connection], size: 6pt)
})

== testing shutdown without sleeps

The drain test is four observations on one gated request, and none of
them wait on the clock. The handler blocks on a channel the test
holds. Cancel the context. First, readiness flips on the same tick:
the test yields until the drainer's state moves, `runtime.Gosched`
in a loop, no sleep anywhere. Second, fresh dials are refused: the
test probes with a client that disables keep-alive, so every probe is
a new connection, and once the listener closes every probe fails,
which is the poll of real state, not of a timer. Third, the gated
request still completes: release the channel, the in-flight response
arrives a 200, and the serve helper returns nil. Fourth, in the
sibling test, an expired grace is reported as the deadline error
rather than success. The listener-failure path has its own test,
because a helper that swallows the listen error would hide a
misconfigured port behind a clean exit:

#listing("go/api/internal/loadtest/shutdown_test.go", first: 99, last: 122, caption: [cancel, yield until the flip, then poll fresh dials until the listener refuses])

#diagram([the drain lifecycle: serving, draining, closed], length: 13pt, {
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
  pane(0.4, 11.0, 2.4, [the 503 carries], [code overload], [contract ruling])
  pane(8.0, 21.0, 2.4, [the two exits], [nil: everything drained], [error: grace expired])
  cdraw.content((11.0, 0.9), [load balancers see the 503 before the listener dies, clients see 200s to the end], size: 6pt)
})

== admission control

The rate limit bounds arrivals over time. The admission gate bounds
requests inside the service at once, and the mechanism is a counting
semaphore: one buffered channel of capacity `n`, a send to take a
slot, the receive riding a `defer` to give it back, so a handler that
panics still releases, the recover layer beside it does the rest. The
nonblocking select is the whole policy: a slot is taken when one is
free, and when the gate is full the answer is immediate, the
contract's overload envelope at 503, never a queue, because a queued
request holds a goroutine and memory the service just proved it
cannot spend. The cap is the deployment's honest concurrency, worker
and memory budget, not what a client would like.

The barrier test pins exactly who gets in. A gate of four, four
concurrent requests each blocked on a barrier after entering, so the
test observes `InFlight` at exactly the cap, then four synchronous
requests that all answer 503 with the envelope, then the barrier
opens and the holders finish. Little's law closes the loop: at a
fixed arrival rate, the gate caps `L`, and capped `L` with rising
service time means the excess is refused at the door instead of
queueing inside:

#listing("go/api/internal/admission/admission.go", first: 35, last: 49, caption: [the gate: nonblocking take, defer release, overload envelope at the cap])

#diagram([latency versus in-flight: the hockey stick the gate cuts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight, L], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.6, 7.6), [latency, W], size: 6pt)
  cdraw.line((0.6, 1.3), (11.0, 1.8), stroke: luma(60))
  cdraw.line((11.0, 1.8), (15.0, 5.4), stroke: luma(60))
  cdraw.line((15.0, 5.4), (17.8, 7.3), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.5, 1.0), [below capacity: workers busy, no queue], size: 6pt)
  cdraw.content((13.6, 3.3), [queueing], size: 6pt)
  cdraw.line((12.4, 0.7), (12.4, 6.6), stroke: luma(150), dash: "dashed")
  cdraw.content((12.4, 7.0), [the cap], size: 6pt)
  pane(13.6, 23.2, 3.0, [past the cap], [503 overload, instantly], [no goroutine spent])
  cdraw.content((7.2, 6.0), [L = rate x W: the rate limit caps rate], size: 6pt)
  cdraw.content((7.2, 4.9), [the gate caps L itself], size: 6pt)
})

== the goroutine leak check

A load tool that leaks goroutines per run silently slows every later
run and lies about the service it measures. Go 1.27 ships the answer
in the runtime: the `goroutineleak` profile, whose write runs a
detection GC and reports the goroutines that are blocked and
unreachable from anything live, which is the definition of a leak.
The check is four lines at the end of the harness test: run the
closed loop against a real `httptest` server, close the server,
close the client's idle connections, look the profile up, write it
once to trigger detection, and assert the count is zero. On failure
the test dumps the leaked stacks at verbosity 2, because a leak
assertion that says only a number sends the reader hunting blind:

#listing("go/api/internal/loadtest/leak_test.go", first: 19, last: 40, caption: [run, close everything, then ask the runtime what is still alive])

#diagram([a goroutine lifecycle: born, joined, or leaked], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [born], [wg.Go, go func])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [does its work], [request, pacing timer])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [returns], [channel closed, wg.Done])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [gone], [no one holds it])
  pane(0.3, 11.4, 2.6, [the leak], [blocked, unreachable], [the runtime names it])
  pane(12.0, 23.2, 2.6, [the check], [WriteTo runs the GC], [Count reads the cycle])
  cdraw.content((11.5, 1.5), [the runtime chapter's goroutine states, one level up], size: 6pt)
  cdraw.content((11.5, 0.4), [leak profile empty after every harness run, or the test is red], size: 6pt)
})

sources: pkg.go.dev for net/http Server.Shutdown semantics, the
ListenAndServe and Serve contract, testing/synctest is absent here
but runtime/pprof's goroutineleak profile is read from the go 1.27
source in GOROOT including its detection GC, golang.org/x/perf
benchstat for the summary statistics, and the little's law statement
as used across the corpus, accessed 2026-09-25. Verified by
`goapi/internal/loadtest` and `goapi/internal/admission` tests, 15
of them, under `go test -race`, plus the committed capture
`2026-09-25-stack.txt` and the benchstat summary over it, quoted
above, measured on this machine, a 12th gen i7-12700F under
windows/amd64.
