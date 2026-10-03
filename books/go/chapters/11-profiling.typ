#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= profiling: pprof, the tracer, benchstat, p99

The runtime chapter listed the profile set. This chapter uses it:
capture a profile from a real workload, read it with the tools, make
one measured change, prove it with benchstat, and state latencies as
percentiles instead of averages. Every capture in this chapter was
taken on this machine and committed with its date, and the suite
re-asserts the load-bearing parts of each one.

== the profile set

One workload feeds every capture below: a deterministic chunk loop,
sha256 over seeded bytes, cheap enough for the suite and real enough
to profile:

#listing("go/samples/ch11/service.go", first: 23, last: 41, caption: [one chunk: pcg-seeded bytes, hashed, checksummed])

The six captures: cpu profiles sample the instruction pointer,
heap profiles carry allocation sites, goroutine dumps hold every
stack, block and mutex profiles time contention, the 1.27
`goroutineleak` detector flags unreachable blocked goroutines, and
the execution tracer records scheduler events on a timeline. Cpu,
heap, and trace answer why is it slow, the contention pair answers
why is it waiting, the goroutine set answers what is alive.

#diagram([six captures, three questions], length: 13pt, {
  let cell(xc, ytop, text, fill) = {
    cdraw.rect((xc - 3.4, ytop - 1.0), (xc + 3.4, ytop), fill: fill, radius: 0.02)
    cdraw.content((xc, ytop - 0.5), [#text], size: 6pt)
  }
  cell(3.7, 7.0, [cpu], luma(235))
  cell(11.1, 7.0, [heap], luma(235))
  cell(18.5, 7.0, [trace], luma(235))
  cell(3.7, 5.6, [goroutine +, goroutineleak], luma(222))
  cell(11.1, 5.6, [block], luma(235))
  cell(18.5, 5.6, [mutex], luma(235))
  cdraw.content((3.7, 4.4), [why is it slow], size: 6.5pt)
  cdraw.content((11.1, 4.4), [why is it waiting], size: 6.5pt)
  cdraw.content((18.5, 4.4), [what is alive], size: 6.5pt)
  pane(0.3, 11.3, 2.9, [how to take them], [runtime/pprof in process,], [net/http/pprof over http,], [go test -trace, -cpuprofile])
  cdraw.content((18.4, 1.4), [the tracer is the only one], size: 6pt)
  cdraw.content((18.4, 0.3), [with time inside the format], size: 6pt)
})

== pprof, read as text

`go tool pprof` needs no browser: `-top` prints the flat and
cumulative table. The capture below came from `go test -cpuprofile`
over the chunk loop's own test, then `go tool pprof -top` over the
profile file:

#listing("go/samples/ch11/pprof-top.txt", first: 12, last: 20, caption: [the whole cost of 1024 hashed chunks, flat table in nine lines])

Flat is time inside a frame, cum is time inside the subtree, and the
sample math is visible: 40 ms of samples over a 42.74 ms profile
window, 93.59 percent of it. The story is two rows. 75 percent is
`blockSHANI`, the hardware sha extension inner loop, and 25 percent
is the kernel's own `ProcessChunk`, the pcg fill loop. The in-suite
test that mirrors this capture asserts the file starts with the gzip
magic `1f 8b` (a pprof profile is gzipped protobuf) and holds real
bytes, so the artifact cannot rot.

#flow(
  [profile to answer],
  node((0, 0), [capture, cpuprofile flag]),
  edge("-|>"),
  node((1.7, 0), [go tool pprof -top]),
  edge("-|>"),
  node((3.4, 0), [flat table, two rows decide]),
  edge((3.4, 0), (3.4, -1.1), "-|>"),
  node((3.4, -1.1), [flame graph or web ui, optional]),
)

== the execution tracer

Cpu profiles say where cycles went, the tracer says what the
scheduler did while they went there: goroutine park and resume,
channel operations, network polls, gc phases, all on one timeline.
`go test -trace trace.out` captures a whole test run,
`trace.Start` scopes it, and `go tool trace trace.out` opens the
viewer over the same events. The suite captures one loop and checks
the format itself:

#listing("go/samples/ch11/metrics_test.go", first: 96, last: 125, caption: [trace start, work, stop, then assert the format])

The header the test asserts is literally `go 1.26 trace` on a go
1.27 runtime, the format is versioned independently of the compiler,
and the file grows with the events recorded, so a few hundred bytes
minimum is the floor that says events landed. When a latency question
is about coordination rather than computation, a cpu profile shows
nothing and this file shows everything.

#diagram([one timeline, every actor on it], length: 13pt, {
  cdraw.line((0.3, 3.4), (23.3, 3.4), stroke: luma(100))
  cdraw.content((11.8, 4.0), [time], size: 6pt)
  let lane(y, name) = {
    cdraw.content((2.4, y + 0.15), [g#name], size: 6pt)
    cdraw.line((3.2, y), (23.2, y), stroke: luma(200))
  }
  lane(2.6, "1: hashing")
  lane(1.8, "2: parked on recv")
  lane(1.0, "3: gc mark")
  cdraw.rect((3.4, 2.3), (9.8, 2.9), fill: luma(170), radius: 0.02)
  cdraw.content((6.6, 2.6), [running], size: 6pt)
  cdraw.content((15.5, 2.6), [running again after unpark], size: 6pt)
  cdraw.rect((11.2, 2.3), (20.0, 2.9), fill: luma(170), radius: 0.02)
  cdraw.content((15.6, 1.8), [blocked: a gap the cpu profile cannot show], size: 6pt)
  cdraw.rect((5.0, 0.7), (8.6, 1.3), fill: luma(205), radius: 0.02)
  cdraw.content((6.8, 1.0), [stw mark], size: 6pt)
  pane(0.3, 11.3, -0.6, [go tool trace], [opens the viewer], [over these events])
  cdraw.content((18.4, -0.4), [the only capture with time inside], size: 6pt)
})

== benchstat, honest comparison

A single benchmark number is weather, not climate. The discipline:
run both sides ten times, let `benchstat` (golang.org/x/perf)
compute the statistics, and quote the table it prints. The pair
lives in the samples: the loop concatenation every language has
warned about since its first manual, and the builder:

#listing("go/samples/ch11/build.go", first: 14, last: 31, caption: [the A side and the B side, same output])

#listing("go/samples/ch11/benchstat-ab.txt", first: 7, last: 11, caption: [what benchstat printed over the ten-run capture])

The table carries three verdicts at once: 5.868 microseconds against
554 nanoseconds, about ten times, 15240 bytes against 1016, and 63
allocations against 7, both allocation columns flat enough that the
delta is structural, not noise. The capture underneath
(`bench-ab.txt`) holds all twenty raw runs. Note what the tool does
not let you do: with +-21 percent on the A side, a 10 percent
improvement claim from one run each would be unprovable, and
benchstat would show overlapping intervals instead of the clean
column above.

#diagram([the flow that earns a number], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.2), (x0 + 5.2, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.8), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 4.8), [#l1], size: 6pt)
  }
  stage(0.3, [count=10], [both sides])
  cdraw.line((5.7, 5.3), (6.1, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [benchstat], [mean and interval])
  cdraw.line((11.5, 5.3), (11.9, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [the delta table], [overlapping = unproven])
  cdraw.line((17.3, 5.3), (17.7, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [prose quotes it], [dated, with the capture])
  cdraw.content((11.8, 3.0), [one run each is weather: the intervals overlap], size: 6pt)
  cdraw.content((11.8, 1.8), [ten runs each, quoted with the spread, is climate], size: 6pt)
})

== runtime/metrics

`GODEBUG` output is for humans. Programs that report on themselves
read `runtime/metrics`: named values, one `Sample` slice, one `Read`
call, versions discoverable at runtime so a wrong name is a loud
panic, never a silent zero:

#listing("go/samples/ch11/metrics.go", first: 7, last: 28, caption: [one gauge, by name, every scalar kind covered])

The panel the chapter reads covers allocation bytes, gc cycles, gc
cpu share, mutex wait seconds, live goroutines, and the heap goal,
and the tests use it the way production code would: the allocation
gauge moves at least a mebibyte when a mebibyte is allocated, the
cycle gauge counts two forced collections as two. Histogram-valued
metrics come back as `Float64Histogram` with explicit bucket
boundaries, the honest form of a latency gauge, and the helper's
fallback of a median bucket is marked as exactly that.

#diagram([the gauge board, by path], length: 13pt, {
  let cell(xc, ytop, text, fill) = {
    cdraw.rect((xc - 3.3, ytop - 1.0), (xc + 3.3, ytop), fill: fill, radius: 0.02)
    cdraw.content((xc, ytop - 0.5), [#text], size: 6pt)
  }
  cell(3.6, 7.0, [/gc/...], luma(235))
  cell(10.9, 7.0, [/memory/...], luma(235))
  cell(18.2, 7.0, [/cpu/classes/...], luma(235))
  cell(3.6, 5.6, [/sched/...], luma(235))
  cell(10.9, 5.6, [/sync/...], luma(235))
  cell(18.2, 5.6, [/gc/heap/...], luma(235))
  cdraw.content((3.6, 4.5), [cycles, scan, goals], size: 6pt)
  cdraw.content((10.9, 4.5), [heap sizes], size: 6pt)
  cdraw.content((18.2, 4.5), [gc, user, idle], size: 6pt)
  cdraw.content((3.6, 3.4), [goroutines], size: 6pt)
  cdraw.content((10.9, 3.4), [mutex wait seconds], size: 6pt)
  cdraw.content((18.2, 3.4), [allocs, objects], size: 6pt)
  pane(0.3, 11.3, 1.9, [the contract], [names checked at runtime,], [KindBad panics loudly])
  cdraw.content((18.3, 0.7), [allvalues doc lists every path], size: 6pt)
})

== gctrace, the raw feed

`GODEBUG=gctrace=1` prints one line per collection to stderr, ugly
and indispensable in a pinch. A capture of this chapter's own suite
run is committed, and the test parses it structurally rather than
trusting the prose:

#listing("go/samples/ch11/gctrace.txt", first: 8, last: 12, caption: [five of the 38 lines, 2026-09-13, this machine])

Reading one line: cycle 4 started 33 ms into the process, gc has
cost 2 percent of cpu so far, the three clock numbers are sweep
termination, concurrent mark, and mark termination, the heap triple
is 3->5->2, mb at cycle start, after mark, and live after sweep,
then the 4 mb goal the pacer set for the next cycle, stack and
global bytes, and the P count. Two details the capture documents:
`(forced)` marks `runtime.GC` calls, and cycle numbers restart
mid-file because `GODEBUG` propagates to the go tool's child
processes, so the compile step's collections appear too. The parser
in the samples turns each line into those numbers and the test
asserts cycles count up within each process and the goal never
sits under the live set.

#diagram([one gctrace line, annotated], length: 13pt, {
  let seg(x0, w, text, fill) = {
    cdraw.rect((x0, 4.4), (x0 + w, 5.6), fill: fill, radius: 0.02)
    cdraw.content((x0 + w / 2, 5.0), [#text], size: 6pt)
  }
  seg(0.3, 2.6, [gc 4], luma(235))
  seg(3.1, 2.8, [#"@0.033s"], luma(235))
  seg(6.1, 2.4, [#"2%:"], luma(235))
  seg(8.7, 6.6, [sweep+mark+term], luma(222))
  seg(15.5, 7.8, [3->5->2 MB], luma(205))
  cdraw.content((11.8, 3.6), [clock: the three gc phases], size: 6pt)
  cdraw.content((19.4, 3.6), [heap: start, mark, live], size: 6pt)
  cdraw.line((19.4, 4.2), (19.4, 3.9), stroke: luma(100), mark: (end: ">>"))
  seg(0.3, 5.2, [4 MB goal], luma(235))
  seg(5.7, 4.6, [stacks, globals], luma(235))
  seg(10.5, 3.0, [20 P], luma(235))
  cdraw.content((2.9, 2.0), [the pacer's next target], size: 6pt)
  cdraw.content((2.9, 0.9), [(forced) marks runtime.GC], size: 6pt)
  cdraw.content((13.5, 2.0), [all of it parseable, the test does], size: 6pt)
})

== p99, the honest latency

Averages hide the tail, and the tail is what users feel. The corpus
percentile definition is nearest-rank: sort the chunk latencies,
take the ceil(p*n)-th. The harness is deliberately small:

#listing("go/samples/ch11/p99.go", first: 17, last: 45, caption: [record, sort, index: the whole definition])


One measured gotcha belongs here because the suite hit it: this
machine's monotonic clock advances in roughly 0.5 ms steps (40
distinct readings in 20 ms, measured 2026-09-13), so timing a 20
microsecond chunk with `time.Now` mostly returns 0, and 193 of 200
timings of a 32 KiB hash read exactly that. Sub-tick work must be
summed over many iterations, which is precisely why the benchmark
harness runs `b.N` or `b.Loop` repetitions instead of one timed call.
The suite's 1024-chunk run therefore asserts the harness mechanics,
monotone percentiles and a non-zero tail, while the percentile
numbers worth quoting come from chunks big enough to dwarf the tick,
in the row kernel below.

#diagram([the tail ladder over 1000 chunks], length: 13pt, {
  cdraw.line((1.2, 0.6), (1.2, 6.8), stroke: luma(100))
  cdraw.line((1.2, 0.6), (23.0, 0.6), stroke: luma(100))
  let bar(x0, w, y, label) = {
    cdraw.rect((x0, y - 0.35), (x0 + w, y + 0.35), fill: luma(160), radius: 0.02)
    cdraw.content((x0 + w + 1.4, y), [#label], size: 6pt)
  }
  bar(1.6, 2.0, 5.8, [p50])
  bar(1.6, 5.2, 4.5, [p95])
  bar(1.6, 7.6, 3.2, [p99])
  bar(1.6, 9.8, 1.9, [p99.9])
  cdraw.content((11.8, 0.1), [latency, ms], size: 6pt)
  cdraw.content((11.8, 6.4), [nearest rank: sort, take ceil(p*n)-th], size: 6pt)
  pane(16.8, 23.3, 4.4, [measured, row kernel], [34.7 / 59.6 / 68.0 / 75.8 ms], [over 1000 chunks])
  cdraw.content((11.8, -0.7), [the average would sit near p50 and hide all of it], size: 6pt)
})

== the row kernel, ten million rows

The corpus row kernel gives go a real database to profile: one
`readings` table, station plus 8 REAL columns, 412 stations, seeded
rows written 10000 at a time through a prepared statement inside a
transaction, pure go sqlite underneath:

#listing("go/samples/ch11/rowkernel.go", first: 54, last: 79, caption: [one 10k-row chunk: begin, prepare, insert, commit])

Measured on this machine, 2026-09-13, modernc.org/sqlite v1.58.0,
one goroutine, `go/samples/ch11/row-10m.txt`: 10,000,000 rows
inserted in 37.321 s, 267942 rows per second, over exactly 1000
chunks whose latencies were p50 34.688 ms, p95 59.607 ms, p99
67.957 ms, p99.9 75.824 ms, into a 0.81 GiB database. The SQL
aggregation pass, `GROUP BY` with min, max, and avg over all eight
columns, returned 412 station rows scanning 10m rows in 30.805 s,
324614 rows per second, and the manual cursor walk over the same
data folded sums in go at 610720 rows per second. The walk beats
the aggregate because sqlite computes 24 values per group while the
walk adds 8 per row, and the pass choice is exactly the kind of
decision a profile should drive, not a hunch.

The aggregation pass both ways:

#listing("go/samples/ch11/rowkernel.go", first: 109, last: 125, caption: [the group by over all eight columns])

#diagram([the kernel: seed, commit, aggregate, walk], length: 13pt, {
  let stage(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.8), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.6, 4.2), [#l2], size: 6pt)
  }
  stage(0.3, [seed], [10k rows per tx], [prepared stmt])
  cdraw.line((5.7, 5.2), (6.1, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.9, 5.9), [x1000], size: 6pt)
  stage(6.1, [commit], [wal journal], [one connection])
  cdraw.line((11.5, 5.2), (11.9, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [aggregate], [group by, min,], [max, avg x 8])
  cdraw.line((17.3, 5.2), (17.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [walk], [cursor over rows,], [sums folded in go])
  cdraw.content((11.8, 2.6), [insert 267942 rows/s, aggregate 324614, walk 610720], size: 6pt)
  cdraw.content((11.8, 1.5), [all measured 2026-09-13 on this machine], size: 6pt)
  cdraw.content((11.8, 0.3), [smoke: 1000 rows, both passes, under 1s in suite], size: 6pt)
})

#callout("note", "scale ladder honesty", [
  10m rows is the quoted in-prose run. The 100m one-off ran alone
  and sequentially the same day, `row-100m.txt`: 100,000,000 rows
  in 6m45.78s, 246439 rows per second, 8 percent under the 10m rate
  so the extrapolation held, into an 8.14 GiB database deleted
  after the run, chunk percentiles p50 38.530, p99 66.462, p99.9
  71.699 ms over 10000 chunks, sql aggregate 225924 rows per
  second, walk 613804. One billion rows is arithmetic, roughly
  81 GiB at this schema, not a measurement on this machine.
])

=== the duckdb lane, same kernel

The infrastructure book runs the same row kernel on duckdb, and its
engine chapter #xref-to("infrastructure", "duckdb") is where the
engine questions live. This book's lane exists to drive it from go:
the twin keeps the shape and swaps the plumbing, rows entering
through the driver's appender (`sql.Conn.Raw` down to the
`*duckdb.Conn`, `NewAppenderFromConn`, vectors of 2048 rows, one Flush
per 10000-row batch), the group by running unchanged SQL over
vectorized aggregation, and the walk analog scanning the result
stream chunk by chunk with sums folded in go. sqlite's REAL is a
float64, duckdb's is a float32, so the twin table declares DOUBLE,
and the whole lane rides the duckdb_use_lib build tag because the
driver links the pinned official duckdb.dll.

Measured 2026-09-20, duckdb 1.5.5, one connection over the engine's
own thread pool, `go/samples/ch11/row-10m-duckdb.txt`: 10,000,000
rows appended in 12.913 s, 774437 rows per second, p99 68.56 ms per
10k-row batch, the group by returning 412 stations at 124918491 rows
per second, and the chunk-scan walk at 4864899 rows per second. The
aggregate is not a like-for-like cell against the sqlite row: the
engine parallelizes the scan across its thread pool while every
other row in the table is one thread, so that column compares engine
architecture, not language.

== which tool when

#diagram([one question, one tool], length: 13pt, {
  let row(y, q, tool) = {
    cdraw.line((0.3, y - 0.45), (23.3, y - 0.45), stroke: luma(220))
    cdraw.content((4.6, y), [#q], size: 6pt)
    cdraw.content((15.4, y), [#tool], size: 6pt)
  }
  cdraw.content((4.6, 7.5), [the question], size: 6.5pt)
  cdraw.content((15.4, 7.5), [the tool], size: 6.5pt)
  row(6.5, [which function is hot], [pprof -top over a cpu profile])
  row(5.5, [where do allocations come from], [heap profile, alloc_space])
  row(4.5, [why is it blocked], [block and mutex profiles])
  row(3.5, [what leaks], [goroutine + goroutineleak dumps])
  row(2.5, [when did scheduling cost time], [the tracer, go tool trace])
  row(1.5, [did the change work], [bench -count=10, then benchstat])
  row(0.5, [how bad is the tail], [nearest-rank percentiles, this chapter])
})

The undercurrent is the same everywhere: capture from the real path,
quote the tool's output, keep the capture beside the claim, and let
a test re-derive what a test can re-derive. The capstone chapter
applies all of it to the crawler.

== across the six books

The same two kernels ran in all six language books under one
contract, N particles of 8 float64 fields stepped 16 times and 10
million readings rows of one station key plus 8 real columns, every
number below quoted from the chapter that measured it on this
machine, 2026-09-13. The first two columns are the particle step at
1m in each language's row-of-objects repr and its flat column repr,
and they disagree on purpose: the flat repr wins 1.4x in c, 2.6x in
javascript, and 21x in python, the object repr wins 2.3x in c\# and
3.8x in go because the step touches all eight fields of every
particle and one cache line per particle beats eight streams in
flight, and lua's ffi cdata wins 11.5x over boxed tables. The last
four columns are the row kernel at 10m rows under the shared
contract, insert through 10k-row batches (committed transactions on
sqlite, appender flushes on duckdb), the sql group by, the manual
scan (cursor walk on sqlite, chunk stream on duckdb), and the p99 of
one 10k-row batch. Lua's p99 cell sits
empty on purpose: its os.clock ticks at 1 ms and the chapter refuses
to quote a percentile it cannot read, the boundary every book states
in its own clock. The duckdb row is the engine lane this chapter
measured: same kernel over the pinned 1.5.5 dll, its group by
parallelized across the engine's thread pool. Its particle columns
sit empty on purpose: the engine is the subject there, not a
language repr, so there is no object or flat step to time.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto),
    inset: 4pt,
    align: (auto, right, right, right, right, right, right),
    table.header([*book*], [*objects ns*], [*flat ns*], [*insert/s*], [*group/s*], [*walk/s*], [*p99 ms*]),
    [c, clang -O2], [6.15 to 6.75], [4.53 to 4.91], [468,803], [584,696], [2,242,885], [28.3],
    [c\#, .net 11], [5.7], [13.1], [339,091], [723,248], [501,820], [48.5],
    [go 1.27], [8.2], [30.9], [267,942], [324,614], [610,720], [67.957],
    [javascript, node 26], [12.4], [4.72], [530.42k], [851k], [562.3k], [17.914],
    [python 3.14], [345.7], [16.18], [327,703], [536,378], [307,199], [39.60],
    [lua 5.5 + luajit], [114.1], [9.9], [504,765], [573,915], [580,353], [],
    [duckdb 1.5.5], [], [], [774,437], [124.92m], [4,864,899], [68.56],
  ),
  caption: [the two kernels across the six language books plus the duckdb engine lane: particle step ns at 1m in each book's object and flat repr, then the 10m row kernel with insert, group by, and walk in rows per second and p99 in milliseconds per 10k-row batch, every cell quoted from the chapter that measured it],
)

The ladder above the table stays in its own book: the 100m particle
one-off measured 5.768 ns flat and 7.229 ns object in c, 21.815 ns
flat in c\# (memory bound, soa only), 8.898 ns flat in go, 4.63 ns
flat in javascript, 16.88 ns flat in python, and 8.2 ns ffi in lua,
with the boxed 100m priced at 13.9 GB and refused. The 100m row
one-off held its 10m insert rate within 5 percent in c, javascript,
and lua, gained 4 percent in python, and paid 8 percent in go and 21
percent in c\#. One billion is arithmetic in every book, 64 GB of
particle state and roughly 81 to 87 GB of rows, not measured on this
machine.

sources: go.dev/doc/diagnostics (profiling, tracing, runtime
metrics, gdb), pkg.go.dev/runtime/pprof, runtime/trace, runtime/metrics,
and testing, the go.dev/blog tracer and execution tracer posts, plus
pkg.go.dev/modernc.org/sqlite and
pkg.go.dev/github.com/duckdb/duckdb-go/v2, accessed 2026-09-13.
Measured numbers are from runs on this machine, 2026-09-13, pinned
in `go/samples/ch11/pprof-top.txt`, `bench-ab.txt`,
`benchstat-ab.txt`, `gctrace.txt`, `row-10m.txt`, and
`row-100m.txt`, the duckdb lane 2026-09-20 in
`row-10m-duckdb.txt`, re-asserted by the 14 tests of
`go/samples/ch11` plus the duckdb_use_lib-gated parity gate.
