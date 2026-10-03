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
drops requests every time it ships. This chapter closes the family
with the tools that make both claims checkable, all in
`pyapi/load.py`: the admission gate that answers overload at the
cap, the graceful drain whose order is the contract and whose exit
code reports what the drain earned, the two harness loops over
injected client, clock, and pacing seams, the report table with its
honest percentiles, and the thread census that holds the harness
itself honest after a run. Chapter 35 capped lambda, this chapter
caps `L` and measures what both bought.

== admission control

The rate limit bounds arrivals over time. The admission gate bounds
requests inside the service at once, and the mechanism is a counting
semaphore: one `threading.BoundedSemaphore` of the deployment's
honest concurrency, `acquire(blocking=False)` to take a slot, the
release riding a `finally` so a handler that raises still gives the
slot back. The nonblocking acquire is the whole policy: a slot is
taken when one is free, and when the gate is full the answer is
immediate, the contract's overload envelope at 503, never a queue,
because a queued request holds a thread and memory the service just
proved it cannot spend.

Two details make the gate trustworthy rather than merely present.
The semaphore is bounded, so releasing past the initial count raises
`ValueError`, and the suite pins that loudness with its own test: an
unbalanced release is a bug this vehicle wants named, not a slot
invented from nothing. And the counter beside the semaphore is
observation, not enforcement: `in_flight` exists so the drain and
the tests can see the occupancy, while the semaphore alone decides
who enters. The gate as one middleware layer refuses through the
kernel's failure writer, so a 503 carries the standard envelope with
the request id like every other failure:

#listing("python/api/pyapi/load.py", first: 76, last: 93, caption: [the gate as a layer: nonblocking take, finally release, overload envelope at the cap])

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
  pane(13.6, 23.2, 3.0, [past the cap], [503 overload, instantly], [no thread spent])
  cdraw.content((7.2, 6.0), [L = rate x W: chapter 35 capped rate], size: 6pt)
  cdraw.content((7.2, 4.9), [the gate caps L itself], size: 6pt)
})

== the drain contract

Shutdown has an order, and the order is the contract. Readiness
flips first: the drainer's state moves to draining, `/readyz`
answers its 503 overload envelope through the kernel's config hook,
and every load balancer watching the service stops routing new
requests here while the old ones are still being answered well.
Then the listener closes, so new connections are refused at the tcp
level. Then the in-flight requests finish under a grace deadline,
and the helper returns what happened instead of pretending the drain
succeeded.

The platform's own behavior explains why the accounting is the
gate's job. The docs are explicit: "`ThreadingMixIn.server_close`
waits until all non-daemon threads complete", and the kernel's
server runs its request threads as daemons precisely so the
platform's close does not join them. That makes `shutdown` plus
`server_close` stop the accept loop and close the socket without
waiting on handlers, and the gate's condition, `wait_empty`, is
what actually waits, releasing the caller the moment the last slot
goes back or the grace runs out:

#listing("python/api/pyapi/load.py", first: 135, last: 146, caption: [Drain: readiness flips, listener closes, in-flight finish under the grace])

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

== the exit code reports the drain

A drain that returns nothing is a drain that cannot be alerted on.
The helper answers a `DrainResult` carrying three facts: whether
everything in flight finished inside the grace, how many requests
were still holding slots when the grace ran out, and the grace that
was on the clock. The composition turns that into the process exit
code, zero when the last slot went back in time, one when the grace
expired with work still inside, and an operator watching a deploy
sees the difference in the container's exit status without reading
a single log line. The result is the caller's to judge, never
swallowed by the helper, which is the same discipline the kernel
applies to failures: report, do not absorb:

#listing("python/api/pyapi/load.py", first: 147, last: 153, caption: [the exit code: zero when drained, one when the grace expired with work inside])

#diagram([the two exits and what each one claims], length: 13pt, {
  let st(x0, name, l1, l2, fill) = {
    cdraw.rect((x0, 3.6), (x0 + 7.4, 6.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 3.7, 5.6), [#name], size: 6.5pt)
    cdraw.content((x0 + 3.7, 4.7), [#l1], size: 6pt)
    cdraw.content((x0 + 3.7, 3.9), [#l2], size: 6pt)
  }
  st(0.4, [exit 0], [every slot returned], [in-flight got their answers], luma(235))
  cdraw.line((8.0, 4.9), (8.6, 4.9), stroke: luma(100), mark: (end: ">>"))
  st(8.8, [exit 1], [grace expired, work inside], [in_flight says how many], luma(215))
  pane(17.0, 23.2, 6.0, [the composition], [#"sys.exit(drain_exit_code(r))"], [the deploy pipeline reads it])
  cdraw.content((11.5, 1.4), [the helper reports, the caller judges], size: 6pt)
})

== testing the drain without sleeps

The drain test is observations on real state, and none of them wait
on the clock. The full test holds two slots through a real
ThreadingHTTPServer, starts the drain on its own thread, and gates
on the drainer's `flipped` Event, a `threading.Event` the flip sets,
so the assertion that readiness moved costs nothing. Fresh dials are
polled, not slept on: the probe opens new connections until the
refused one arrives, the poll of real socket state, and the held
slots are released by the test so the drain's condition fires and
the join completes. The expired-grace leg is a zero-second look:
`Condition.wait_for` with a timeout of zero checks the predicate
once and returns its falsity, so the deadline path is exercised
with no waiting at all, which is the honest python analog of the go
lane's synctest bubble:

#listing("python/api/tests/test_load.py", first: 121, last: 135, caption: [the expired grace: a zero-second look at a held slot, the deadline reported])

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
  st(14.4, [closed], [drained, or the deadline], luma(205))
  pane(0.4, 11.0, 2.4, [the 503 carries], [code overload], [contract ruling])
  pane(8.0, 21.0, 2.4, [the gates], [flipped Event, condition], [never time.sleep])
})

== the load harness

The two loops differ in what they hold constant. The closed loop
holds concurrency constant: worker threads, each firing one request
at a time and starting the next only after the previous answer
lands, so offered load never exceeds the worker count and the loop
measures a system at a chosen concurrency. The open loop holds
arrival rate constant: request `i` is scheduled at `i` over rate
seconds past the start and fired whether or not anything has come
back, so when the service slows, requests pile up exactly the way
they do in production, and the cliff becomes visible. Little's law
predicts the pile: in-flight equals arrival rate times service time,
and an open loop at fixed rate turns rising latency directly into
rising in-flight count.

Three seams are injected, which is what keeps every number in a
test a planned value rather than scheduling. The client answers one
`(status, seconds)` pair per request index and owns its own timing,
so latency is reported by the seam, not measured around whatever
the thread scheduler did. The clock reads now for the elapsed span.
The pacing seam receives target instants, the real one sleeping the
delta, the test one recording the schedule and returning instantly,
so the open loop's arithmetic is asserted exactly. Warmup fires
first on every loop and never reaches the result, because the first
request pays for the dial, the dns lookup, and the cold caches, and
none of that is the number the run exists to measure:

#listing("python/api/tests/test_load.py", first: 159, last: 169, caption: [the strict fake client: one planned pair per index, no clock reads, no sockets])

#diagram([workers, client seam, result: one harness, two loops], length: 13pt, {
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
  step(13.1, [client seam], [(status, seconds)], [or a real socket])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [result], [statuses, latencies], [warmup excluded])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [fixed rate, watch L climb])
  cdraw.content((17.2, 1.4), [same harness, two loops, one report format], size: 6pt)
})

== the report and honest percentiles

One run folds into one row, and the percentiles are nearest rank,
the definition chapter 36 pinned, computed over the sorted
latencies the client seam reported. The exact row and the bucketed
row sit in the same table over the same samples: the bucketed row
feeds the latencies through a histogram and answers each percentile
as the bound the rank lands in, which is what a scraper sees. Six
latencies of 1, 1, 2, 3, 5, and 8 milliseconds give an exact p50 of
2 and p99 of 8, while the bucketed row reads p50 as 2.5 and p99 as
10, the bounds, and a rank that falls past the largest finite bound
renders as a dash, because inventing a digit the samples never had
is the one sin the definition forbids. Two rows, same run, the
difference is the resolution a histogram throws away, stated in the
table's source column instead of hidden in a footnote, and the
units live in the header where a latency column cannot be misread:

#listing("python/api/pyapi/load.py", first: 276, last: 292, caption: [summarize exact by nearest rank, bucket_summarize as the scraper sees it])

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
  pane(8.0, 23.2, 7.0, [each step is one row], [same rps, rising p99], [the table, not the vibe])
})

== the thread census

A load tool that leaks a thread per run silently slows every later
run and lies about the service it measures, and python names the
leak directly: `threading.enumerate()` lists every live thread, so
the census is a set difference against a snapshot taken before the
run, and the harness test asserts the difference is empty after
both loops have finished. The snapshot is taken in the same process
the harness ran in, which is also its honesty: whatever the loops
started and did not join appears by name, no profile required. The
go lane needed a runtime profile to say this, python says it with
one function over the thread list, and the discipline is the same
in both: leak nothing per run, or the numbers are fiction:

#listing("python/api/pyapi/load.py", first: 264, last: 271, caption: [the census: threads alive now that were not in the snapshot])

#diagram([a thread lifecycle: born, joined, or leaked], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [born], [Thread(..).start()])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [does its work], [one request, or pacing])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [joins], [the harness joins all])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [gone], [not in enumerate])
  pane(0.3, 11.4, 2.6, [the leak], [alive, past the run], [the census names it])
  pane(12.0, 23.2, 2.6, [the check], [diff against the snapshot], [empty, or the test is red])
  cdraw.content((11.5, 1.5), [worker threads are joined by both loops before any row is rendered], size: 6pt)
})

sources: docs.python.org, the 3.14 socketserver page for
ThreadingMixIn's daemon_threads and the server_close joining rule,
the 3.14 threading page for BoundedSemaphore, Event, and
Condition.wait_for, accessed 2026-09-27. Verified by
`python/api/tests/test_load.py`, 17 tests under unittest discover
on the pinned cpython 3.14.7, with the report table pinned from
fixed latencies and the drain observed over a real loopback
listener without a single sleep.
