#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= profilers: benchmarkdotnet, counters, and p99

Chapter 11 made allocation measurable from inside the process. This
chapter is the tooling around it: how to A/B two implementations
honestly, how to watch a live process without touching it, how to read
a trace, and how to report latency as percentiles instead of an
average. Every command and every number below ran on this machine
under the pinned SDK 11.0.100-rc.1, and the two slow workloads, the
particle kernel and the ten-million-row SQLite kernel, are the same
contract the other language books in this corpus measure.

== benchmarkdotnet, the grammar

BenchmarkDotNet is the standard harness, and its grammar is small.
Mark methods with `[Benchmark]`, one of them `Baseline = true` so the
table reports ratios against it, do setup once in `[GlobalSetup]`,
return the result so the JIT cannot dead-code the loop, and let the
runner own the iterations: warmup runs, measured runs, outlier
removal, and a Mean, Error, StdDev, Ratio block at the end. The
opt-in bench project under `samples/bench/` carries the book's copy:

#listing("csharp-net/samples/bench/Bdn.cs", first: 14, last: 41, caption: [the chapter 11 step as an a slash b, baseline, setup, checksum returned])

#diagram([what the harness adds around your method], length: 13pt, {
  // your benchmark in the middle, the harness stages around it
  cdraw.rect((0.2, 4.6), (5.6, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.9, 5.5), [`[GlobalSetup]`, #linebreak() once, not timed], size: 6pt)
  cdraw.line((5.6, 5.5), (7.4, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 4.6), (16.0, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 5.5), [`[Benchmark(Baseline = true)]`, #linebreak() your method, timed], size: 6pt)
  cdraw.line((16.0, 5.5), (17.8, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.0, 4.6), (23.6, 6.4), fill: luma(230), radius: 0.02)
  cdraw.content((20.8, 5.5), [mean, error, #linebreak() stddev, ratio], size: 6pt)
  cdraw.rect((7.6, 2.6), (16.0, 4.2), fill: luma(230), radius: 0.02)
  cdraw.content((11.8, 3.4), [warmup iterations, #linebreak() then measured iterations, #linebreak() outliers removed], size: 6pt)
  cdraw.content((11.8, 1.2), [the runner owns the clock, the method only does the work], size: 6.5pt)
})

The number one rule is isolation: the harness exists so a quick
`Stopwatch` around two candidates, with a cold JIT and one iteration
each, cannot masquerade as a measurement. The table it prints carries
its own honesty, Error is half the confidence interval and Ratio is
the distribution of per-iteration ratios, not a division of two
means.

== the rc gap and the inprocess toolchain

On a stable SDK the default toolchain generates a project per
benchmark, builds it, and runs it out of process. On this RC SDK that
path dies before the first benchmark, reproduced by the `bdnclassic`
mode of the bench, exit code 82, 2026-09-13, this machine:

```text
// Validating benchmarks:
Unhandled exception. System.NotImplementedException: GetRuntimeVersion not implemented for NotRecognized
   at BenchmarkDotNet.Extensions.RuntimeMonikerExtensions.GetRuntimeVersion(RuntimeMoniker runtimeMoniker)
   at BenchmarkDotNet.Validators.DotNetSdkValidator.ValidateCoreSdks(...)
```

BenchmarkDotNet 0.15.8 does not recognize the RC runtime moniker, so
its SDK validation throws instead of validating. The working
toolchain on this SDK is `[InProcess]` territory:
`InProcessEmitToolchain` runs every benchmark inside the host process,
no generated project, no toolchain resolution. That is the toolchain
this book runs:

#listing("csharp-net/samples/bench/Bdn.cs", first: 44, last: 64, caption: [inprocess for the runs, the classic entry kept as the documented failure])

#diagram([two toolchains, one dead on the rc sdk, one working], length: 13pt, {
  // the request at top, the two paths below, one ending in the exception
  cdraw.rect((7.0, 5.0), (16.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 5.6), [`BenchmarkRunner.Run<T>()`], size: 6pt)
  cdraw.line((8.4, 5.0), (4.6, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.2, 5.0), (19.0, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 0.6), (9.0, 3.8), fill: luma(180), radius: 0.02)
  cdraw.content((4.6, 2.9), [default toolchain, #linebreak() generate, build, run out of process], size: 6pt)
  cdraw.content((4.6, 1.6), [`NotImplementedException`, #linebreak() at validation, on 11.0.100-rc.1], size: 6pt)
  cdraw.rect((14.6, 0.6), (23.4, 3.8), fill: luma(205), radius: 0.02)
  cdraw.content((19.0, 2.9), [`InProcessEmitToolchain`, #linebreak() run inside this process], size: 6pt)
  cdraw.content((19.0, 1.6), [same benchmarks, same table, #linebreak() exit 0, measured], size: 6pt)
})

The measured run, 100,000 particles, 16 steps plus the checksum fold,
warmup 3, 15 iterations, this machine, 2026-09-13:

```text
| Method | Mean     | Error     | StdDev    | Ratio | Allocated | Alloc Ratio |
|------- |---------:|----------:|----------:|------:|----------:|------------:|
| Soa    | 4.935 ms | 0.0335 ms | 0.0313 ms |  1.00 |         - |          NA |
| Aos    | 4.909 ms | 0.0258 ms | 0.0229 ms |  0.99 |         - |          NA |
```

One outlier was removed from `Aos` automatically, and the ratio at
this scale is parity, which is itself a result: at 100k particles both
representations are 6.4 MB and L3 resident, where chapter 11's 1m
run, 64 MB each, measured the AoS loop 2.3 times faster. Scale moved
the answer, which is the argument for keeping both numbers rather
than a favorite. The GA SDK is expected to fix the classic toolchain;
when it does, re-run `bdnclassic` and record the delta here instead
of silently deleting the gap.

== dotnet-counters, live

`dotnet-counters` watches a process through the EventPipe, no
profiler attach, no code change. The bench installs it as a local
tool from its own manifest, so nothing pollutes the machine:

#snippet(
  "dotnet tool restore\n"
  + "dotnet dotnet-counters collect --counters System.Runtime --format csv \\\n"
  + "    --output counters.csv -p <pid> --refresh-interval 1 \\\n"
  + "    --duration 00:00:00:04\n",
  lang: "text",
)

The capture committed with this book was taken that way against the
bench's spinner, a busy loop churning short-lived arrays, 4 seconds at
a one second refresh, this machine, 2026-09-13. The names are the new
meter names, `dotnet.gc.*`, not the legacy counter names:

#listing("csharp-net/samples/captures/counters-spinner-2026-09-13.csv", first: 1, last: 6, caption: [the committed capture, five of its 104 rows])

#listing("csharp-net/samples/src/Ch12/CountersParse.cs", first: 24, last: 46, caption: [the capture parses into records, header skipped, five fields per row])

#callout("pitfall", "never pipe these tools through select-object -first", [
  The capture commands are long, and trimming their output with
  `Select-Object -First` in PowerShell kills the capture: the early
  pipeline stop tears down the session and leaves a 1 KB stub file.
  Measured twice on this machine. Redirect to a file and read the
  file, the way `run-bench.ps1` does.
])

== dotnet-trace and eventpipe

`dotnet-trace` writes the same EventPipe stream to a `.nettrace` file
for after-the-fact analysis. The capture that quoted this section,
3 seconds of the same spinner:

```text
$ dotnet dotnet-trace collect -p <pid> --duration 00:00:00:03 -o spinner.nettrace
...
Trace completed.
```

1,061,498 bytes for 3 seconds of a busy loop, measured 2026-09-13.
The file is a stream of events: CPU samples, GC events, JIT events,
thread switches. `--format speedscope` rewrites it for the speedscope
flame graph viewer, and `--profile gc-verbose` narrows the stream to
allocation and collection events when only the collector is in
question. The spinner being observed:

#listing("csharp-net/samples/bench/ParticleBench.cs", first: 162, last: 184, caption: [the workload the captures watched: allocation churn plus sleep])

#diagram([one eventpipe stream, three consumers], length: 13pt, {
  // the process at left, the eventpipe in the middle, three tools at right
  cdraw.rect((0.2, 3.0), (5.8, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 4.3), [the process, #linebreak() events emitted inside], size: 6pt)
  cdraw.line((5.8, 4.3), (9.0, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.4, 4.85), [eventpipe], size: 6pt)
  let tools = (
    ([dotnet-counters], [live numbers]),
    ([dotnet-trace], [a .nettrace file]),
    ([dotnet-dump], [a heap snapshot]),
  )
  for (i, (name, what)) in tools.enumerate() {
    let y = 5.6 - i * 1.35
    cdraw.line((9.0, 4.3), (11.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((11.8, y - 0.5), (23.6, y + 0.5), fill: luma(205), radius: 0.02)
    cdraw.content((15.6, y), name, size: 6pt)
    cdraw.content((20.4, y), what, size: 6.5pt)
  }
  cdraw.content((11.8, -0.4), [no code change, no attach, the same stream read three ways], size: 6.5pt)
})

== the gc panel

Percent time in GC, generation counts, and pause time together tell
you which of chapter 11's levers to pull, and all three are meters in
the committed capture. Reading it:

#listing("csharp-net/samples/src/Ch12/CountersParse.cs", first: 66, last: 74, caption: [pause time is a rate, seconds of pause per second, so the mean is the fraction])

#table(
  columns: (auto, auto, 1fr),
  inset: 4pt,
  table.header([*meter*], [*measured*], [*reading*]),
  [`dotnet.gc.pause.time`], [about 0.0037 s per s], [0.37% of wall time paused, healthy for this churn],
  [`dotnet.gc.collections` gen 0], [65 to 66 per s], [the ephemeral budget recycling the spinner's arrays],
  [`dotnet.gc.collections` gen 1, 2], [0], [nothing survives the loop, no promotion pressure],
  [`dotnet.gc.heap.total_allocated`], [about 858 MB per s], [the allocation rate the gen 0 cadence is paying for],
  [`dotnet.gc.last_collection.heap.size` gen 0], [560 B], [the post-collection ephemeral remainder],
  [`dotnet.process.memory.working_set`], [47.7 to 49.1 MB], [the process cost of the churn],
)

The panel is a diagnosis loop: allocation rate explains the gen 0
cadence, the cadence times the pause rate gives the wall-clock tax,
and if the tax is too high, chapter 11's pools and arenas are the
lever, verified by capturing again and watching the gen 0 count fall.

== p99 for a managed loop

The mean of a latency distribution is a marketing number. The honest
report is nearest-rank percentiles over a count of samples: sort, take
the value at `ceil(p / 100 * n)`. The suite pins the math on known
inputs, p50 of 1..100 is 50, p99 of 1..1000 is 990, and one floating
point trap is handled in code, the rank product rounded to ten
decimals before the ceiling, because `99.9 / 100 * 1000` computes to
999.00000000000006 and a bare ceiling silently asks for rank 1000:

#listing("csharp-net/samples/src/Ch12/P99.cs", first: 14, last: 43, caption: [nearest rank percentiles and the four-number summary])

The harness loop runs deterministic chunks with a shaped load, every
16th chunk does 8 times the work, so the tail is designed rather than
accidental:

#listing("csharp-net/samples/src/Ch12/P99.cs", first: 45, last: 77, caption: [a chunk loop with a real tail, one latency per chunk])

#diagram([the distribution a shaped tail produces: the median floor, the p95 step, the p99 cliff], length: 13pt, {
  // latency rank on the x axis, a step function rising at 95 and 99
  cdraw.line((1.0, 0.4), (1.0, 5.8), stroke: luma(100))
  cdraw.line((1.0, 0.4), (21.0, 0.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, -0.5), [rank, 15 chunks of every 16 are light, one is heavy], size: 6pt)
  cdraw.line((1.0, 1.2), (14.6, 1.2), stroke: luma(100))
  cdraw.line((14.6, 1.2), (14.6, 3.0), stroke: luma(100))
  cdraw.line((14.6, 3.0), (19.2, 3.0), stroke: luma(100))
  cdraw.line((19.2, 3.0), (19.2, 4.4), stroke: luma(100))
  cdraw.line((19.2, 4.4), (21.0, 4.4), stroke: luma(100))
  cdraw.content((7.8, 1.75), [p50, the light chunk], size: 6pt)
  cdraw.content((16.9, 2.2), [p95, onto the heavy ones], size: 6pt)
  cdraw.content((19.6, 5.0), [p99, p99.9, #linebreak() scheduler noise on top], size: 6pt)
  cdraw.content((0.4, 2.8), [latency], size: 6pt)
})

Measured through the bench, 2,000 chunks of 1,000 doubles, run twice
back to back, this machine, 2026-09-13: run 1 measured p50 0.0035 ms,
p95 0.0244, p99 0.0245, p99.9 0.0454, max 1.1676; run 2 measured p50
0.0035, p95 0.0244, p99 0.0381, p99.9 0.0558, max 1.2187. The median
and p95 repeat, the p99 and beyond move, and the checksum,
-383.24379846230437, is identical in both runs. That split is the
lesson: the deterministic half of the tail belongs to your workload,
the moving half belongs to the machine, and a latency claim that does
not say which is which is not a claim.

== the row kernel

The second corpus workload: ten million rows into SQLite through
`Microsoft.Data.Sqlite` 10.0.12 over the pinned `bundle_e_sqlite3`
3.0.5 build, both reporting engine version 3.53.4, the same pins the
capstone's save store uses. The schema is fixed across every book in
the corpus, 412 stations, 8 REAL columns, and the values are a stated
integer hash of station, row, and field, so any run resumable
anywhere produces the identical stream:

#listing("csharp-net/samples/src/Ch12/RowKernel.cs", first: 50, last: 93, caption: [10k-row batched transactions, one prepared statement, per-batch commit latency])

The suite runs the 1,000-row smoke against a temp file and asserts
the two aggregation passes agree, SQL `GROUP BY` min, max, and avg
times 8 against a manual cursor walk of the same data. At measurement
scale, 10,000,000 rows through the bench, 1,000 batches, db deleted
after, this machine, 2026-09-13:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*stage*], [*measured*], [*rate*]),
  [insert, 10k-row transactions], [29.5 s for 10,000,000 rows], [339,091 rows/s],
  [batch commit p50 / p95], [27.1 ms / 37.9 ms], [over 1,000 batches],
  [batch commit p99 / p99.9], [48.5 ms / 120.8 ms], [the tail the inserts buy],
  [aggregate, sql group by], [13.8 s], [723,248 rows/s],
  [aggregate, manual cursor walk], [19.9 s], [501,820 rows/s],
  [agreement fold, sql against cursor], [3296.2817847056854 both], [delta 0.00],
  [database size], [870,072,320 bytes], [about 830 MB, deleted after],
)

The engine's aggregate beats the cursor walk by 1.4 times at this
scale, the GROUP BY does the same scan in C with the page cache hot.
The 10m rate extrapolates sanely, so the 100 million row one-off ran,
alone and sequentially, database deleted after, this machine,
2026-09-13: insert 371.4 s at 269,216 rows/s across 10,000 batches
with p50 36.5 ms, p99 50.2 ms, p99.9 135.0 ms, aggregate 314,663
rows/s by SQL against 267,968 by cursor walk, folds equal at
3296.81315815615, database 8,735,449,088 bytes. The rates drop a
fifth from the 10m run and the SQL-to-cursor gap narrows from 1.4 to
1.2, both the page cache giving way to disk, and both one-off
databases are gone. One billion rows is arithmetic, not a measurement
on this machine, roughly 87 GB at this row shape and half an hour of
insert at the measured rate.

=== the same kernel on duckdb

The corpus ran this kernel on duckdb too, from c and from go, and
those chapters hold the engine-side numbers. The c twin, same 412
stations and rows bit-identical to its sqlite lane, measured the
appender at 1.05 to 1.12 million rows a second against sqlite's
batched 464,047, the group by at 79.6 to 83.3 million against
555,402, 143x to 150x, while the go lane appended 774,437 rows a
second with its group by at 124,918,491 over the engine's own thread
pool, all 2026-09-20 on duckdb 1.5.5. `Microsoft.Data.Sqlite` stays
the engine here anyway: the tail quoted above is a batch commit's,
p99 over 1,000 transactions, and the capstone's save store rides the
same pins, while the appender opens no transaction and offers no
per-batch commit to time. Which engine a workload wants is measured
in #xref-to("infrastructure", "duckdb") and chosen in
#xref-to("infrastructure", "duckdb-sqlite").

== which tool when

#diagram([which tool answers which question], length: 13pt, {
  // the question on the left, the tool and its product on the right
  let rows = (
    ([which of two implementations], [benchmarkdotnet, #linebreak() mean, ratio, alloc per op]),
    ([is the process healthy right now], [dotnet-counters, #linebreak() live rates, no restart]),
    ([where did the time go], [dotnet-trace, #linebreak() a .nettrace, flame input]),
    ([what does the user feel], [the p99 harness, #linebreak() nearest rank over >= 1000 chunks]),
    ([how much garbage did that make], [gc allocated bytes deltas, #linebreak() chapter 11's probe style]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.0 - i * 1.25
    cdraw.rect((0.2, y - 0.52), (8.4, y + 0.52), fill: luma(235), radius: 0.02)
    cdraw.content((4.3, y), row.at(0), size: 6pt)
    cdraw.line((8.4, y), (9.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((16.6, y), row.at(1), size: 6pt)
  }
  cdraw.content((11.4, -0.9), [one workload, four lenses: measure before believing any of them], size: 6.5pt)
})

The tools compose: the counters panel flags a GC tax, the trace says
which phase pays it, the benchmark A/Bs the fix, and the percentile
harness proves the tail moved. Nothing in this chapter replaces the
discipline chapter 11 closed on, the representation you pick has to
be re-measured at your scale, because both of this chapter's measured
workloads changed their answer between 100k and 1m particles and
between a cache-hot engine scan and a manual walk.

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
four columns are the shared sqlite contract at 10m rows, insert
through 10k-row batched transactions, the sql group by, the manual
cursor walk, and the p99 of one 10k-row commit. Lua's p99 cell sits
empty on purpose: its os.clock ticks at 1 ms and the chapter refuses
to quote a percentile it cannot read, the boundary every book states
in its own clock.

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
  ),
  caption: [the two kernels across the six language books: particle step ns at 1m in each book's object and flat repr, then the 10m row kernel with insert, group by, and walk in rows per second and p99 in milliseconds per 10k-row commit, every cell quoted from the chapter that measured it],
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

sources: benchmarkdotnet.org, benchmarkdotnet docs overview and the
inprocess toolchain page, learn.microsoft.com, dotnet-counters,
dotnet-trace, well-known event counters in .net, and the .net runtime
metrics pages, accessed 2026-09-13. Counter and trace behavior
verified against the committed capture in `samples/captures/` and the
bench under `samples/bench/`, both made on this machine, 2026-09-13.
Sample behavior verified by `make verify-csharp`, 12 tests.
