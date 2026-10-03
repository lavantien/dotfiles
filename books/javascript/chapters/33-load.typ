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
guess, and a deploy that has never been drained is a deploy that drops
requests every time it ships. This chapter closes the operations side
in `api/src/load`: the event loop as the whole concurrency story,
graceful shutdown with a real drain order, the admission gate that
answers overload at the cap, the two load loops over injected seams,
p99 by nearest rank with the bucket approximation labeled as the bound
it is, socket backpressure as the node lane's own flow control, and
the orphan check that keeps every run honest after it ends.

== the event loop is the worker

The go chapters spend their first lesson on goroutines, a scheduler,
and the mutexes that protect shared maps. This lane needs none of that
story, and the reason is structural: one thread runs every line of
this api. A request handler is an async function, its awaits are the
only places another request's code can interleave, and everything
between two awaits is atomic by construction. The limit chapter's
buckets map needed no mutex for exactly this reason, and the load
harness gets its workers for free: an async function per worker under
`Promise.all` is a pool, and each worker fires strictly one request at
a time because its loop awaits each send.

The closed-loop test pins the serialization honestly. Three workers
fire four requests each through an injected server whose sends each
advance a fake clock by five milliseconds, and the elapsed total is
sixty: the twelve sends ran one after another on the one thread,
overlapping only between their awaits, because the fake server is one
thread like the real one. What a node service parallelizes is io
waiting, never compute, which is the fact the admission gate and the
backpressure section both lean on:

#listing("javascript/api/test/load/harness.test.mjs", first: 35, last: 54, caption: [three workers, twelve sends, sixty fake milliseconds: one thread serialized them])

#diagram([one thread, many async frames], length: 13pt, {
  cdraw.line((0.6, 4.0), (23.2, 4.0), stroke: luma(120))
  cdraw.content((23.4, 4.0), [t], size: 6pt)
  cdraw.rect((1.0, 4.6), (5.4, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 5.2), [frame a], size: 6pt)
  cdraw.rect((6.0, 4.6), (10.4, 5.8), fill: luma(218), radius: 0.02)
  cdraw.content((8.2, 5.2), [frame b], size: 6pt)
  cdraw.rect((11.0, 4.6), (15.4, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((13.2, 5.2), [frame a], size: 6pt)
  cdraw.content((3.2, 6.4), [compute, atomic], size: 6pt)
  cdraw.content((13.2, 6.4), [resumed at its await], size: 6pt)
  cdraw.circle((5.7, 4.0), radius: 0.3, fill: luma(60))
  cdraw.circle((10.7, 4.0), radius: 0.3, fill: luma(60))
  cdraw.content((5.7, 3.2), [await], size: 6pt)
  cdraw.content((10.7, 3.2), [await], size: 6pt)
  cdraw.content((17.4, 5.2), [io waits overlap, code never does], size: 6pt)
  pane(16.2, 23.2, 3.4, [no mutexes], [the await is the seam], [go's whole lesson, absent])
  cdraw.content((11.5, 1.6), [what blocks the loop blocks everything, one slow handler stalls them all], size: 6pt)
})

== graceful shutdown with drain

Shutdown has an order, and the order is the contract. Readiness flips
first: the drainer's state moves to draining, `/readyz` answers its
503 overload envelope, and every load balancer watching the service
stops routing new requests here while the old ones are still being
answered well. Then the listener stops accepting, and node needs one
extra move the go lane did not: idle keep-alive sockets count as
active connections, so `closeIdleConnections` retires them before the
close, which is what lets the close callback mean drained. Then the
drain waits for in-flight requests under a grace deadline and reports
the deadline instead of pretending the drain succeeded, because the
caller decides whether to force the hard exit itself.

The kernel takes the drainer's `ready` function as its readiness
probe, the same hook the contract's overload ruling flows through, and
the grace timer is a thunk seam for the same reason the limit clock
is, a captured reference escapes `mock.timers`:

#listing("javascript/api/src/load/shutdown.mjs", first: 27, last: 50, caption: [drain: flip readiness, retire idle sockets, wait under grace, report the deadline])

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
  t(9.4, 4.6, [idle sockets retired], luma(215))
  t(14.2, 4.6, [in-flight drain], luma(205))
  t(19.0, 4.2, [exit 0], luma(235))
  cdraw.content((4.6, 2.5), [the in-flight request still gets its 200], size: 6pt)
  cdraw.content((16.5, 4.2), [grace deadline], size: 6pt)
  cdraw.content((11.5, 1.4), [the hard kill: everything between SIGTERM and exit 0 becomes a dropped connection], size: 6pt)
})

== admission control

The rate limit bounds arrivals over time. The admission gate bounds
requests inside the service at once, and little's law states the
trade in one line: the average number inside equals the arrival rate
times the time each spends there. Offered load raises that product two
ways, more arrivals or slower service, and past the point where every
arrival finds the gate full, latency rises steeply while throughput
stops moving, the hockey stick the harness measures. The gate caps the
inside count directly, one plain number up on admission and down in a
`finally`, and a caller at the cap gets the `overload` envelope
immediately, because queueing it would spend memory the service just
proved it cannot keep up with.

The go gate is a channel of slots, a buffered send to take and a
deferred receive to release. The node gate is a number and a try, and
the panic-proofing transfers exactly: the release rides the `finally`
of an async function, so a handler that throws still gives the slot
back, and the barrier test observes `inFlight` at exactly the cap
before the third request eats its 503:

#listing("javascript/api/src/load/admission.mjs", first: 15, last: 34, caption: [the gate: a plain count, finally release, overload thrown at the cap])

#diagram([latency versus in-flight: the hockey stick the gate cuts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight, L], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.6, 7.6), [latency, W], size: 6pt)
  cdraw.line((0.6, 1.3), (11.0, 1.8), stroke: luma(60))
  cdraw.line((11.0, 1.8), (15.0, 5.4), stroke: luma(60))
  cdraw.line((15.0, 5.4), (17.8, 7.3), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.5, 1.0), [below capacity: frames busy, no queue], size: 6pt)
  cdraw.content((13.6, 3.3), [queueing], size: 6pt)
  cdraw.line((12.4, 0.7), (12.4, 6.6), stroke: luma(150), dash: "dashed")
  cdraw.content((12.4, 7.0), [the cap], size: 6pt)
  pane(13.6, 23.2, 3.0, [past the cap], [503 overload, instantly], [no memory spent])
  cdraw.content((7.2, 6.0), [L = rate x W: the rate limit caps rate], size: 6pt)
  cdraw.content((7.2, 4.9), [the gate caps L itself], size: 6pt)
})

== the load harness

The two loops differ in what they hold constant. The closed loop holds
concurrency constant: workers each firing one request at a time, so
offered load is whatever the server can keep up with and never exceeds
the worker count. The open loop holds arrival rate constant: request
`i` is scheduled at `i` over rate seconds past the start, fired
whether or not anything has come back, so when the server slows,
requests pile up exactly the way they do in production, and the cliff
becomes visible. Warmup runs first on every loop and never touches the
sink, because the first request pays for the dial and the cold caches.

Three seams make the whole scheduler testable: `send`, so tests drive
deterministic responses with no socket, `now`, so latency is
arithmetic, and `sleep`, so the pacing is a function the test
replaces. Two platform facts earned their way into this module's
comments. An `async` sleep wrapper adds a microtask hop between the
timer firing and the caller resuming, and under fake timers that hop
lets the test's next tick advance the clock before the fired request
observes its own deadline, so the default sleep is a plain promise.
Fake timers replace `setImmediate` too, so tests under mocks signal
through latches, never through immediate polls:

#listing("javascript/api/src/load/harness.mjs", first: 111, last: 131, caption: [the open loop: schedule math, concurrent pacing, independent of every response])

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
  step(13.1, [injected send], [no socket in tests], [or real http])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [sink], [latencies, statuses], [warmup excluded])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [fixed rate, watch L climb])
  cdraw.content((17.2, 1.4), [same harness, two loops, one report format], size: 6pt)
  cdraw.content((17.2, 0.3), [warmup fires first and lands nowhere], size: 6pt)
})

== p99 from nearest rank

The percentile definition is nearest rank: sort the latencies, take
the ceiling of `p` over 100 times n as the rank, answer that rank's
value. Its honesty is in what it refuses to do: no interpolation
between samples, so p99 of one hundred values is the ninety ninth
smallest, not an average of two neighbors, and a rank that runs past
the data clamps to the largest, because a percentile past the sample
is a bound, not a measurement. P99.9 of ten samples says "the worst
one", and says so honestly.

The bucket approximation is the second half of honesty. A scraped
histogram cannot answer nearest rank, it can only say which bucket the
rank lands in, so the bucketed row of the report answers the smallest
bound whose cumulative count reaches the rank, an upper bound on the
true value, and not knowable when the rank falls into `+Inf`. The
report table states the difference instead of hiding it: the golden
set of six latencies, 1, 1, 2, 3, 5, 8 milliseconds, renders an exact
row with p50 of 2 and p99 of 8, and a buckets row with p50 of 2.5 and
p99 of 10, the source column naming which row is which:

#listing("javascript/api/src/load/quantile.mjs", first: 7, last: 18, caption: [nearest rank: ceil the rank, clamp the ends, no interpolation anywhere])

#diagram([the tail ladder: where p50, p90, p99 sit in one sorted sample], length: 13pt, {
  cdraw.line((1.0, 4.6), (23.0, 4.6), stroke: luma(120))
  cdraw.content((23.2, 4.6), [sorted latencies], size: 6pt)
  for i in range(20) {
    cdraw.line((1.4 + i * 1.08, 4.3), (1.4 + i * 1.08, 4.9), stroke: luma(160))
  }
  let mark(x, label) = {
    cdraw.line((x, 4.6), (x, 6.2), stroke: luma(100))
    cdraw.content((x, 6.8), [#label], size: 6pt)
  }
  mark(11.6, [p50: rank 10 of 20])
  mark(19.1, [p90: rank 18])
  mark(21.0, [p99: clamped 20])
  cdraw.content((11.5, 2.9), [rank = ceil(p/100 x n)], size: 6pt)
  cdraw.content((11.5, 1.8), [p99 of 20 asks for rank 19.8, ceil 20, the largest], size: 6pt)
  pane(0.6, 10.2, 0.6, [buckets answer bounds], [rank lands in a bucket], [the bound is the answer])
  cdraw.content((17.4, -0.3), [interpolated percentiles invent digits the samples never had], size: 6pt)
})

== backpressure and writable sockets

Node's own flow control is the one thing the go chapters never had to
name, because go's goroutines made every write look free. A response
is a writable stream: `res.write` returns false when the socket's
buffer has reached the high watermark, `writableLength` is how many
bytes sit in that buffer, and the drain event is the socket saying it
caught up. Ignoring the return value is the classic node memory leak,
bytes accumulating for a client that has stopped reading, and the
honest response to a false write is to stop offering until the drain:

#listing("javascript/api/src/load/backpressure.mjs", first: 10, last: 16, caption: [the whole rule: a false return waits for the drain event])

The test pins the rule with a stalled writable: a four byte watermark,
a first chunk parked in a consumer whose callback waits on a latch,
and the proof the second chunk is never offered until the latch opens
and the drain fires, with no wall time anywhere:

#diagram([the write path: offer, buffer, drain, offer again], length: 13pt, {
  cdraw.content((2.4, 8.0), [caller], size: 6.5pt)
  cdraw.content((11.5, 8.0), [the stream buffer], size: 6.5pt)
  cdraw.content((20.6, 8.0), [the socket], size: 6.5pt)
  cdraw.line((2.4, 7.7), (2.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.6, 5.2), (4.2, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.4, 5.9), [#"write(chunk)"], size: 6pt)
  cdraw.line((4.4, 5.9), (7.4, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.6, 5.2), (15.4, 6.6), fill: luma(218), radius: 0.02)
  cdraw.content((11.5, 5.9), [buffered to watermark], size: 6pt)
  cdraw.line((15.6, 5.9), (18.6, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((18.8, 5.2), (22.4, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((20.6, 5.9), [consumer], size: 6pt)
  cdraw.content((11.5, 4.4), [#"write returns false at the watermark"], size: 6pt)
  cdraw.line((11.5, 4.1), (11.5, 3.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.6, 2.0), (15.4, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 2.7), [await once(res, "drain")], size: 6pt)
  cdraw.line((11.5, 1.8), (11.5, 1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 0.6), [then, and only then, the next chunk], size: 6pt)
  pane(16.2, 23.2, 3.6, [if ignored], [writableLength grows], [memory for a stalled client])
})

== no orphans left behind

A load tool that leaks sockets or timers per run silently slows every
later run and lies about the service it measures. The go lane asks its
runtime for leaked goroutines after a run, and node's documented
equivalent is `process.getActiveResourcesInfo`, the strings naming
every handle and request still holding the event loop open. The check
runs a real closed loop against a real server over real sockets,
closes everything, and asserts that no `TCPSocketWrap`, no `Timeout`,
and no `Immediate` remains. Teardown is asynchronous, sockets wind
down over the next loop turns, so the check polls the real state until
it is quiescent instead of sleeping a guess. This is the same
discipline the runner enforces on this machine, a leaked handle fails
the suite's exit, and this test is the committed proof the harness
leaks nothing:

#listing("javascript/api/test/load/leak.test.mjs", first: 26, last: 41, caption: [run, close everything, then ask the process what is still alive])

#diagram([a handle lifecycle: born, released, or leaked], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [born], [connect, setTimeout])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [does its work], [request, pacing sleep])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [released], [response read, timer cleared])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [gone], [the loop lets the process exit])
  pane(0.3, 11.4, 2.6, [the leak], [handle alive, owner gone], [the process names it])
  pane(12.0, 23.2, 2.6, [the check], [getActiveResourcesInfo], [polled to quiescence])
  cdraw.content((11.5, 1.5), [node --test orphans are a standing trap on this machine, this test holds the line], size: 6pt)
})

sources: nodejs.org/api/http.html for `server.close`,
`closeIdleConnections`, and `closeAllConnections`, plus
nodejs.org/api/process.html for `process.hrtime.bigint` and
`process.getActiveResourcesInfo`, nodejs.org/api/stream.html for the
writable `write` return value, `writableLength`, and the `drain`
event, nodejs.org/api/events.html for `events.once`, and
nodejs.org/api/test.html for what the mock timers replace including
`setImmediate`, all read 2026-09-26 on node 26.3.0, with the
microtask-hop and immediate-replacement behaviors probed on this
machine the same day. Verified by `javascript/api` tests, 26 of them
under `test/load`, green under `npm run verify`, on the real-socket
closed loop with the orphan assertion green after every run.
