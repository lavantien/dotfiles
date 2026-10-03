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
guess, and this platform says so twice: the vm is single threaded, so
concurrency is a script, and the clocks are a millisecond cpu tick
and whole-second wall time, so a sub-second latency is not a number
this book can honestly quote. This chapter closes the ops family with
what is checkable anyway: nearest-rank percentiles and the histogram
walk that answers bounds, the closed-loop harness over the real host
wire with every seam injected, the committed capture dated and
toolchain-labeled, and the leak discipline for a garbage collected
language, where a leak is a table the composition root keeps alive
and counting is finding.

== what load means here

The c seam owns the only server thread, and that thread accepts one
connection and serves it to completion before the next. Offered load
beyond that one request at a time does not pile up inside the service,
it piles up in the winsock accept backlog, and the queue the load
chapter usually draws inside the server is drawn here at the socket
layer the kernel does not own. Little's law still holds at the wire,
`L = lambda W`, with in-flight capped at one in service plus whatever
the backlog holds, which is why the honest load question on this
platform is throughput and cost per request rather than a concurrency
sweep.

The harness measures exactly that. Every worker fires once per round
before any answer is awaited, so each round deposits the worker count
into the backlog and drains it in accept order, warmup runs first as
round zero and lands nowhere, and the sink's arrival order is the
scripted worker order, deterministic by construction. The seams are
three injected functions, open, fire, and await, which is what lets
the unit tests script the whole interleave over recording fakes while
the real driver rides actual sockets:

#listing("lua/service/load.lua", first: 67, last: 89, caption: [the closed loop: round-major fire then await, warmup round zero unrecorded])

#diagram([the wire under load: workers, backlog, one server thread], length: 13pt, {
  let step(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.8), (x0 + 5.6, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.8, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.8, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.8, 4.2), [#l2], size: 6pt)
  }
  step(0.3, [the workers], [4 drivers, one fd each], [fire all, then await])
  cdraw.line((6.1, 5.2), (6.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(6.7, [the backlog], [accept queue, 16 deep], [the queue lives here])
  cdraw.line((12.5, 5.2), (13.1, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(13.1, [one thread], [accept, serve, close], [sequential by construction])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [answers], [in accept order], [the only synchronization])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [L capped at 1 plus backlog])
  cdraw.content((17.2, 1.4), [no goroutine storm exists to measure, the queue is the story], size: 6pt)
})

== nearest rank and the bucket walk

The percentile definition is nearest rank, the one the profiling
chapter pinned: sort the latencies, take the value at
`ceil(p/100 * n)`. No interpolation anywhere, p99 of one hundred
values is the ninety-ninth smallest, not a blend of the ninety-ninth
and hundredth, and a rank that runs past the end clamps to the
largest, because a percentile past the data is a bound, not a
measurement. The histogram walk answers from what a scraper can see,
the cumulative buckets: the smallest finite bound whose cumulative
count reaches the rank, which is the bound itself, never a value
inside the bucket, and therefore an upper bound on the true
percentile that says so. When the rank falls into the `+Inf` bucket
the walk answers nil, meaning the true value exceeds the largest
finite bound and only worse than that is knowable.

The fixed pair pins the contrast. Six latencies of 1, 1, 2, 3, 5, and
8 milliseconds over millisecond bounds of 1, 2.5, 5, and 10 give an
exact p50 of 2 and p99 of 8, while the walk answers 2.5 and 10, the
bounds the ranks land in, the resolution a histogram throws away:

#listing("lua/service/load.lua", first: 14, last: 28, caption: [nearest rank: the rank ceiled, the ends clamped, nothing interpolated])

#diagram([the sorted ladder, the exact answer and the bucket's bound beside it], length: 13pt, {
  cdraw.line((1.0, 4.6), (23.0, 4.6), stroke: luma(120))
  cdraw.content((23.2, 4.6), [sorted ms], size: 6pt)
  let vals = (1, 1, 2, 3, 5, 8)
  for (i, v) in vals.enumerate() {
    cdraw.line((3.0 + i * 3.4, 4.3), (3.0 + i * 3.4, 4.9), stroke: luma(160))
    cdraw.content((3.0 + i * 3.4, 5.4), [#str(v)], size: 6pt)
  }
  cdraw.line((8.1, 4.6), (8.1, 6.4), stroke: luma(100))
  cdraw.content((8.1, 6.9), [p50: rank 3, exact 2], size: 6pt)
  cdraw.line((20.0, 4.6), (20.0, 6.4), stroke: luma(100))
  cdraw.content((20.0, 6.9), [p99: rank 6, exact 8], size: 6pt)
  pane(1.0, 11.0, 2.2, [the walk on p50], [cum 3 reaches at 2.5], [the bound, not the value])
  pane(13.0, 23.0, 2.2, [the walk on p99], [cum 6 reaches at 10], [upper bound, stated])
  cdraw.content((11.5, 1.4), [rank = ceil(p/100 x n), clamped to the largest], size: 6pt)
})

== the harness over the real wire

The driver lives at `tests/load/run.lua`, deliberately outside
`tests/drivers/`, because the verify lane runs every driver it finds
and a benchmark in verify is a flaky test. It is invoked the way
verify builds the host, the documented gcc line from the service root
with the mingw `lua55.dll` on the path, and it runs only when a
capture is being made.

The model is connection per request, and the serialized accept loop
is why: a second kept-alive connection would sit unaccepted while the
first is open, so each fire connects and sends, each await reads to
the connection end the server's close terminates, and the backlog is
the queue where the round's concurrency waits. The fd discipline is
the seam-level leak check, every open counted against every close,
and the run ends with a scrape of the exposition the load itself
produced. The composition this drives is the root's real chain, with
one adapter worth its sentence: the ops layers speak `(req, next)`
while the kernel chain folds next-handler wrappers, and one
three-line adapter in the root states that bridge once, so the same
layers serve the plain lane's in-process tests and the wire:

#listing("lua/service/tests/load/run.lua", first: 43, last: 66, caption: [the loop wired to the sockets, one connection per request, fds counted])

#diagram([one round of the driver: four connects, the backlog, answers in order], length: 13pt, {
  for w in range(4) {
    cdraw.rect((0.4, 6.8 - w * 1.2), (5.2, 7.6 - w * 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((2.8, 7.2 - w * 1.2), [#"worker " .. str(w + 1) .. " fires"], size: 6pt)
    cdraw.line((5.4, 7.2 - w * 1.2), (7.6, 7.2 - w * 1.2), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.rect((7.8, 2.6), (12.6, 8.0), fill: luma(228), radius: 0.02)
  cdraw.content((10.2, 7.5), [accept backlog], size: 6pt)
  for w in range(4) {
    cdraw.line((8.4, 6.8 - w * 1.2), (12.0, 6.8 - w * 1.2), stroke: luma(160))
  }
  cdraw.content((10.2, 3.4), [the queue, 16 deep], size: 6pt)
  cdraw.line((12.8, 5.2), (13.4, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((13.6, 3.8), (19.4, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((16.5, 6.0), [one server thread], size: 6pt)
  cdraw.content((16.5, 5.0), [drains in accept order], size: 6pt)
  cdraw.content((16.5, 4.2), [answers close the fd], size: 6pt)
  cdraw.line((19.6, 5.2), (20.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  pane(20.4, 23.4, 6.6, [await], [reads to the close], [no sleep anywhere])
  cdraw.content((11.5, 1.4), [the server's answer is the only synchronization in the run], size: 6pt)
})

== the report and its two sources

One run folds into one row with both percentile sources side by side:
the p columns from the raw samples through nearest rank, the b
columns from the histogram the registry kept through the walk,
unknown where the walk refuses, and the units in the header, because
a latency column that does not say its unit is an error waiting for a
reader. The golden test pins the bytes with the fixed six-sample set,
exact 2 and 8 beside bounded 2.5 and 10, and a second row whose every
sample exceeds the largest finite bound, all three b columns reading
unknown, the not-knowable the +Inf bucket honestly is:

#listing("lua/service/load.lua", first: 112, last: 132, caption: [the report row: exact and bounded percentiles, units in the header, unknown where the walk refuses])

#diagram([one row, two sources, the gap between them is the histogram's resolution], length: 13pt, {
  let step(x0, title, l1, l2) = {
    cdraw.rect((x0, 4.0), (x0 + 5.6, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.8, 6.2), [#title], size: 6pt)
    cdraw.content((x0 + 2.8, 5.2), [#l1], size: 6pt)
    cdraw.content((x0 + 2.8, 4.4), [#l2], size: 6pt)
  }
  step(0.3, [the samples], [sorted, every one kept], [p50 2, p99 8])
  cdraw.line((6.1, 5.4), (6.7, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(6.7, [the histogram], [cumulative buckets], [b50 2.5, b99 10])
  cdraw.line((12.5, 5.4), (13.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(13.1, [one row], [both, labeled by source], [unknown where +Inf])
  cdraw.line((18.9, 5.4), (19.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [the reader], [sees the gap], [and knows which side])
  pane(0.3, 11.4, 2.6, [the gap], [2 versus 2.5, 8 versus 10], [resolution, stated not hidden])
  cdraw.content((11.5, 1.6), [over +Inf the b columns read unknown, the walk refuses to invent], size: 6pt)
})

== committed captures

The capture discipline is the profiling chapter's: measure once,
commit the output, quote the table, never re-measure in verify. The
committed capture carries its own provenance, date and machine,
toolchain, the composition level it measured, the model, the clock
truths, and the invocation, so a reader knows exactly what ran. The
2026-09-28 capture quotes this run: 2000 measured requests at 4
workers over 20 wall seconds, 100.0 requests per second, process cpu
of 10.220 milliseconds per request counting both threads, every
request answered 200, every fd closed, and the scrape at the end
holding 2004 observations of `/healthz`, warmup included, because the
registry counts every request the server served while the driver's
sink holds only the measured ones.

The scrape also demonstrates the clock truth better than any
argument: every observation sits in the 0.001 bucket and the sum
reads 0, because the service clock is `os.time`, whole seconds, and a
sub-millisecond request reads as zero elapsed. The histogram is
honest about what it saw. A latency distribution this platform
cannot resolve is not invented, it is measured coarsely and labeled
with the resolution it was measured at:

#listing("lua/service/captures/2026-09-28-load.txt", first: 20, last: 26, caption: [the capture's run summary, 2026-09-28, quoted verbatim])

#diagram([the capture pipeline: run, capture, commit, quote, never verify], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.2), (x0 + 5.2, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.8), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 4.8), [#l1], size: 6pt)
  }
  stage(0.3, [run it], [manual, documented line])
  cdraw.line((5.7, 5.3), (6.1, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [capture], [provenance header, verbatim stdout])
  cdraw.line((11.5, 5.3), (11.9, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [commit], [dated and labeled, under captures/])
  cdraw.line((17.3, 5.3), (17.7, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [quote it], [the chapter cites the committed bytes])
  pane(0.3, 11.4, 3.2, [never verify], [a benchmark there is flaky], [verify builds, never loads])
  cdraw.content((11.5, 1.6), [the numbers are weather, the discipline is the climate], size: 6pt)
})

== the lua leak, found by counting

A leak in this language is not a lost pointer, it is a table the
composition root still reaches after the work it served is done, and
that means counting is finding. The root's registries answer counts:
the limiter's bucket table after a sweep, the metrics registry's
series rows, both bounded by policy, so the assertion is steady
state, run again, count again, same number. The collector's own
figure, live kilobytes under two full collects, is the floor under
the counting, two collects because the collector is incremental and
one pass can leave the finalizers' garbage for the next. At the seam
the same discipline counts file descriptors, every open against every
close, and the load driver asserts it at the end of every run.

The unit test demonstrates the failure mode on purpose: a session
table whose entries retire returns to zero, a table nothing ever
clears holds one hundred, and the difference is the leak, counted.
The sweep from the rate limiting chapter is the production instance
of the fix, idle buckets retire, the collector reclaims them, and the
root's count holds steady no matter how many distinct keys the day
brings:

#listing("lua/service/load.lua", first: 134, last: 150, caption: [root_count and the full-collect floor, the leak found by counting])

#diagram([a table's life under the root: born, reached, retired or counted], length: 13pt, {
  let stage(x0, title, l1, l2) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.6, 4.3), [#l2], size: 6pt)
  }
  stage(0.3, [born], [a request's entry], [root reaches it])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [the work ends], [retire, or forget to], [the fork])
  cdraw.line((11.5, 6.2), (12.0, 6.2), stroke: luma(100), mark: (end: ">>"))
  stage(12.0, [retired], [gc reclaims it], [count holds steady])
  cdraw.line((11.5, 4.6), (12.0, 4.6), stroke: luma(100), mark: (end: ">>"))
  stage(12.0, [still reached], [the leak, counted], [root_count says 100])
  cdraw.line((17.4, 6.2), (17.8, 6.2), stroke: luma(100), mark: (end: ">>"))
  stage(17.8, [the floor], [gc_kb, two collects], [live bytes])
  pane(0.3, 11.4, 2.6, [at the seam], [fds opened vs closed], [the driver asserts it])
  cdraw.content((11.5, 1.5), [no runtime report names a reachable table, the count does], size: 6pt)
})

sources: lua.org manual 5.5 sections 6.2 (basic functions,
collectgarbage), 6.7 (table manipulation, sort over the samples), and
6.8 (mathematical functions, ceil over the rank), the little's law
statement as used across the corpus, and the clock facts from this
book's profiling chapter, measured there. Verified by the service
plain lane under the pinned lua 5.5, `run.lua` green with this
module's 7 tests and the family's 3 composed walkthrough tests among
the total, the load driver green over the real wire with 4 checks,
and the capture committed at `captures/2026-09-28-load.txt`, measured
on this machine, a 12th gen i7-12700F under windows/amd64 with gcc
15.2.0, accessed 2026-09-28, never re-measured by verify.
