#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= profiling: cprofile, sys.monitoring, and p99

Measurement is where this book stops quoting and starts counting. The
interpreter chapter disclaimed timing on purpose, "no timing claims
anywhere in this chapter", and this chapter is the other half of that
bargain: the tools that make a timing claim honest, the deterministic
profiler, the clocks underneath it, percentiles by hand, the PEP 669
event plane, and the two kernels this corpus shares across all six
language books, a particle step and a sqlite row crunch, measured on
this machine under the gate interpreter, cpython 3.14.7. The chapter
owns 30 ok lines across five samples, and its slow numbers live in an
opt-in bench under `samples/bench/`, never in the gate.

== cprofile and pstats

The profiler's contract is stated in its first line: "cProfile and
profile provide *deterministic profiling* of Python programs", and
deterministic means every event is caught, "all *function call*,
*function return*, and *exception* events are monitored, and precise
timings are made for the intervals between these events". A
deterministic profile of a fixed workload has a stable ranking even
when its timings wobble, and the sample holds the profiler to the
ranking, not the microseconds: a workload whose center of gravity is
a named function must show that name at the top of `tottime`, which
the manual defines as "for the total time spent in the given function
(and excluding time made in calls to sub-functions)", run after run.

#listing("python/samples/src/Ch14/cprofile_top.py", first: 12, last: 35, caption: [the workload: dominant\_work carries the loop, light\_work is the foil, fib recurses for the call-count column])

#listing("python/samples/src/Ch14/cprofile_top.py", first: 38, last: 45, caption: [the top by tottime among local functions, the assertion the whole section stands on])

The pstats half reads the same table the profiler wrote. The sort is
documented to descend, "all sorts on statistics are in descending
order (placing most time consuming items first)", and the recursion
column is two numbers in one: "When there are two numbers in the
first column (for example `3/1`), it means that the function
recursed. The second value is the number of primitive calls and the
former is the total number of calls". The sample pins `fib(12)` at
465 total calls over 1 primitive, which is the arithmetic of the
recursion tree, not a timing, so it cannot drift with load.

#diagram([one profile, two time columns: tottime owns the bar for dominant\_work, cumtime credits the callers, and the recursion column splits 465 over 1], length: 13pt, {
  let bar(y, label, t, c, scale) = {
    cdraw.content((5.4, y), [label], wrap: text.with(size: 6pt), anchor: "east")
    cdraw.rect((5.8, y - 0.28), (5.8 + t / scale * 14.2, y + 0.28), fill: luma(170), radius: 0.0)
    cdraw.rect((5.8, y + 0.30), (5.8 + c / scale * 14.2, y + 0.86), fill: luma(220), radius: 0.0)
  }
  bar(8.2, [dominant\_work], 10, 10, 10)
  bar(6.2, [light\_work], 0.6, 0.9, 10)
  bar(4.2, [fib], 0.9, 1.4, 10)
  cdraw.content((12.0, 9.3), [dark tottime, light cumtime], wrap: text.with(size: 6.5pt))
  cdraw.line((5.8, 2.9), (20.6, 2.9), stroke: 0.5pt + luma(180))
  cdraw.content((12.0, 2.4), [the ranking by tottime is the deterministic fact: the name on top survives every rerun], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.0, 1.3), [fib reads 465/1: total calls over primitive, the recursion column], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.0, 0.4), [call counts and the top name are asserted, timings are quoted with a date], wrap: text.with(size: 6pt, fill: luma(100)))
})

== clocks: timeit versus perf_counter

Every number in this chapter rides one clock. `time.get_clock_info`
names it: `perf_counter` is "QueryPerformanceCounter()" on this
machine, monotonic, with a resolution of 1e-07, while the wall clock
`time` reads "GetSystemTimePreciseAsFileTime()". `timeit` rides the
same counter, `timeit.default_timer` is `perf_counter` here, and the
module's promise is process, not hardware: "It avoids a number of
common traps for measuring execution times". Two of the traps are
documented behavior: "By default, `timeit()` temporarily turns off
garbage collection during the timing", and the interpreter of the
result vector is spelled out, "the `min()` of the result is probably
the only number you should be interested in" because higher values
come from interference, not from Python getting slower.

#listing("python/samples/src/Ch14/clocks.py", first: 10, last: 15, caption: [the cost probe: one loop, one closure, nanoseconds a call])

The measured cost ladder on this machine, dated 2026-09-13, reads
about 50 to 80 ns for a bare `perf_counter` read depending on the
run, roughly 350 ns for `Timer.timeit(number=0)`, and about 42000 ns
for the top-level `timeit.timeit(number=0)`, whose autocalibration
machinery runs before the empty call is timed at all. The sample
asserts the shape, read below method below top-level and the read
under a 1000 ns pin, and the prose carries the dated values, because
a nanosecond pin on a cache-warm loop would be a lie the first time
Windows schedules something else.

#diagram([the cost ladder from the counter to the module: each step adds machinery, the top level adds autocalibration], length: 13pt, {
  let step(y, label, cost, width) = {
    cdraw.content((8.6, y), [label], wrap: text.with(size: 6pt), anchor: "east")
    cdraw.rect((9.0, y - 0.3), (9.0 + width, y + 0.3), fill: luma(170), radius: 0.0)
    cdraw.content((9.4 + width, y), [cost], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  }
  step(7.6, [a perf\_counter read], [50 to 80 ns], 2.0)
  step(5.6, [Timer.timeit(number=0)], [about 350 ns], 5.2)
  step(3.6, [timeit.timeit(number=0)], [about 42 \u{b5}s], 14.0)
  cdraw.line((23.4, 7.6), (23.4, 3.6), stroke: luma(140), mark: (end: ">"))
  cdraw.content((17.0, 2.2), [the machine code is the same at every rung, the machinery above it is not], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((17.0, 1.1), [min of the repeats, the manual's rule, the gate's bench and this chapter both take it], wrap: text.with(size: 6pt, fill: luma(100)))
})

== percentiles by hand

A latency claim is a distribution, and the honest summary of a
distribution is its quantiles. The stdlib ships `quantiles()` in
`statistics`, chapter 23's territory, and it interpolates; the
cross-language contract this corpus uses is nearest rank, defined so
the answer is always a sample someone waited for: rank
`ceil(q/100 * n)` into the sorted copy, 1-based. On the integers 0
through 999 that is p50 499, p95 949, p99 989, p99.9 998, and on 1
through 10 it is p50 5 with everything from p95 up equal to 10.

#listing("python/samples/src/Ch14/percentiles.py", first: 9, last: 18, caption: [nearest rank: sort a copy, take the ceil-rank element, every answer is an actual sample])

The pinned case is 4096 gaussian draws from `random.Random(7)`,
`gauss(100, 15)`: p50 100.293, p95 124.819, p99 134.594, p99.9
144.713, pinned to full precision because the seed fixes the list.
The tail is the story the mean hides: the p99.9 sits almost ten
standard deviations of the sample spread above the median, and no
average of the two would represent either customer.

#diagram([the 4096 gaussian draws as a rank ladder: the four marked percentiles climb the right tail, each an actual draw], length: 13pt, {
  cdraw.line((2.0, 8.6), (21.0, 8.6), stroke: 0.5pt + luma(180))
  for i in range(48) {
    let x = 2.6 + i * 0.38
    let h = 1.4 + 3.0 * calc.sin(i / 47 * calc.pi)
    cdraw.rect((x, 1.2), (x + 0.3, 1.2 + h), fill: luma(220), radius: 0.0)
  }
  let mark(x, label) = {
    cdraw.line((x, 1.0), (x, 5.4), stroke: 0.5pt + luma(170), dash: "dashed")
    cdraw.content((x, 6.4), [label], wrap: text.with(size: 6pt, fill: luma(100)))
  }
  mark(4.4, [p50 #linebreak() 100.293])
  mark(11.8, [p95 #linebreak() 124.819])
  mark(17.2, [p99 #linebreak() 134.594])
  mark(20.3, [p99.9 #linebreak() 144.713])
  cdraw.content((11.0, 0.3), [sorted draws, the height is the density, the marks are nearest-rank answers, seeded Random(7)], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== sys.monitoring, pep 669

#xref-to("python", "interpreter") met the event plane from the eval
loop's side. The profiler's side starts with why the plane exists, in
PEP 669's own words: "Using a profiler or debugger in CPython can
have a severe impact on performance. Slowdowns by an order of
magnitude are common." The replacement is tool slots and event masks,
"The VM can support up to 6 tools at once", and the module doc
reserves the ids, debugger 0, coverage 1, profiler 2, optimizer 5.
The import form this book pinned still holds on 3.14.7: `import
sys.monitoring` fails with "'sys' is not a package", `from sys import
monitoring` is the door.

#listing("python/samples/src/Ch14/monitoring.py", first: 35, last: 50, caption: [global PY\_START through tool 0: two calls, two events, everything else counted too])

The distinction this chapter adds to the interpreter chapter's
treatment is local against global. "Events can be turned on or off by
setting the events either globally and/or for a particular code
object", the local list covers the branch and line events, and the
deprecation note points the way: "The `BRANCH` event is deprecated in
3.14. Using `BRANCH_LEFT` and `BRANCH_RIGHT` events will give much
better performance as they can be disabled independently." The sample
puts the mask on one function's code object and pins the census: 15
branch-left, 6 branch-right on the fixed 10-iteration loop, zero
events for the function that calls it, mask 768 read back, cleared to
nothing, tool freed to a `None` name.

#listing("python/samples/src/Ch14/monitoring.py", first: 52, last: 72, caption: [local events on one code object: the mask, the census, the zero from the unmonitored caller])

#diagram([two scopes of the same event plane: global events fire for every code object, local events for one, and a double-set event fires once], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  box(7.2, 8.0, 7.6, [set\_events: the global mask])
  box(0.8, 5.8, 9.0, [every code object in the run], fill: luma(220))
  box(12.6, 5.8, 8.6, [set\_local\_events: one code object], fill: luma(245))
  box(0.8, 3.4, 9.0, [alpha, beta, and everything else])
  box(12.6, 3.4, 8.6, [alpha alone: 15 left, 6 right])
  cdraw.line((9.0, 8.0), (5.3, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 8.0), (16.9, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.3, 5.8), (5.3, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.9, 5.8), (16.9, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 2.2), [an event set both ways triggers once, the manual says so and the census agrees], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 1.1), [six tool slots, pep 669's fix for order-of-magnitude tracing slowdowns], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the free-threaded sidebar

The free-threaded build is the one measurement this book refuses to
make. The guard is a probe, not a flag: `sys._is_gil_enabled()` on
this interpreter returns True, the machine has no 3.14t binary, `py
-0p` lists 3.14 and 3.13 only, probed 2026-09-13, and so the sidebar
script prints its refusal and exits 1:

#listing("python/samples/bench/free_thread_sidebar.py", first: 28, last: 39, caption: [the guard: on the gil build the script refuses, explains, and exits nonzero])

#callout("note", "no free-threaded interpreter on this machine", [
  `py -0p` on 2026-09-13 lists `3.14` and `3.13`, neither with the
  free-threaded suffix. The refusal output above is the measured
  behavior of `free_thread_sidebar.py` under the gate interpreter,
  captured 2026-09-13: exit code 1, the message on stderr, nothing
  else. #xref-to("python", "threads") carries the PEP 779 status
  story and #xref-to("python", "pymalloc") records that mimalloc,
  the free-threaded build's required allocator, is compiled into
  this binary while the build that requires it is absent. What this
  book will not do is extrapolate a speedup from a build it never
  ran: free-threaded performance on this machine is unmeasured, and
  the honest number is the exit code.
])

#diagram([the sidebar's decision: probe the gil, refuse loudly on the gil build, measure only under a real 3.14t], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.15), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.58), t, wrap: text.with(size: 6pt))
  }
  box(7.2, 7.8, 7.6, [sys.\_is\_gil\_enabled()])
  box(0.8, 5.4, 9.2, [true, the gil build], fill: luma(220))
  box(12.8, 5.4, 8.4, [false, a 3.14t binary], fill: luma(245))
  box(0.8, 2.8, 9.2, [refuse on stderr, exit 1, no numbers], fill: luma(215))
  box(12.8, 2.8, 8.4, [burn one against four threads, report overlap])
  cdraw.line((9.0, 7.8), (5.4, 6.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 7.8), (17.0, 6.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.4, 5.4), (5.4, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 5.4), (17.0, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 1.3), [this machine: the left door, measured, exit 1, captured 2026-09-13], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 0.4), [fabricating the right door's number would be a lie with a decimal point], wrap: text.with(size: 6pt, fill: luma(100)))
})

== the particle kernel measured

The kernel is #xref-to("python", "pymalloc")'s: N particles, 8
float64 fields, 16 steps of pure arithmetic, seeded per
representation. The gate smoke is 10000 particles with pinned
checksums, and everything slower lives in the opt-in bench. At a
million particles the array path measured 14.26 ns a particle a step
as the sum of 16 individually timed steps, 2026-09-13, with a step
p50 of 13.9 ms, p99 and max 18.6 ms; the best-of-repeats ladder in
#xref-to("python", "pymalloc") reads 11.48 ns at the same N, the gap
between the two being the timer pairs and the absence of repeats,
which is exactly why both are quoted with their method.

The 100 million one-off ran alone, sequential, on 2026-09-13, 6.4 GB
of SoA plus two 800 MB scratch rows:

#listing("python/samples/bench/captures/2026-09-13-particle-100m.txt", first: 1, last: 6, caption: [the 100m particle one-off: build, 16 steps, the step latency ladder, the checksum])

The per-step cost at 100 million, 16.88 ns, is the 10m ladder's
16.18 ns with nothing left in any cache, pure DRAM streaming at 192
MB of traffic a step. One billion particles is math this machine does
not run: 64 GB of buffer against the measured working set, "not
measured on this machine" is the only honest sentence about it.

#diagram([the array path across five decades of N: the dispatch dive, the cache sweet spot at 10000, the DRAM climb through 100m], length: 13pt, {
  let pos(k, v) = (
    2.0 + k * 3.55,
    8.4 - v / 90.0 * 6.6,
  )
  let logn = (2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let vals = (82.94, 10.24, 3.12, 4.50, 11.48, 16.18, 16.88)
  let pts = logn.enumerate().map(p => pos(p.at(1) - 2.0, vals.at(p.at(0))))
  cdraw.line((2.0, 1.2), (2.0, 8.4), stroke: 0.5pt + luma(180))
  cdraw.line((2.0, 8.4), (23.2, 8.4), stroke: 0.5pt + luma(180))
  cdraw.line(..pts, stroke: luma(120), mark: (end: ">"))
  for p in pts { cdraw.circle(p, radius: 0.09, fill: luma(120)) }
  cdraw.content((4.6, 4.4), [3.12 ns at 10k, the sweet spot], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((17.4, 5.2), [100m, 16.88 ns, #linebreak() dram streaming], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.0, 0.5), [log N from 100 to 100m, y in ns a particle a step to 90, one-off marked at 100m], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the row kernel measured

The second kernel is a sqlite table, `readings`, 412 stations
`st000` through `st411`, eight REAL columns each, inserted in
10000-row batched transactions through `executemany`, the
transaction rule the manual states: "The `INSERT` statement
implicitly opens a transaction, which needs to be committed before
changes are saved". The engine is the interpreter's own bundled
library, `sqlite3.sqlite_version`, "Version number of the runtime
SQLite library as a `string`", 3.50.4 on this 3.14.7 build, asserted
from inside the sample, and worth a sentence of drift honesty: the
corpus elsewhere loads a 3.53.4 sqlite3.dll, this module carries its
own older library, and both numbers are measured facts about their
own binaries.

#listing("python/samples/src/Ch14/rowkernel.py", first: 40, last: 57, caption: [the smoke scale: 1000 seeded rows, ten committed chunks, the two aggregation passes ready])

The 10 million row run, `row_bench.py --rows 10000000`, alone and
sequential on 2026-09-13, wrote a 0.87 GB database and deleted it
after:

#listing("python/samples/bench/captures/2026-09-13-row-10m.txt", first: 1, last: 10, caption: [the 10m row kernel: insert rate, the chunk latency ladder over 1000 commits, gc counts, both aggregation passes])

The commit ladder is the reason the percentile section exists: p50
25.71 ms against p99.9 114.16 ms says the median chunk tells almost
nothing about the worst one in a thousand, and the tail is where a
backpressure story lives. The two aggregation passes bracket the
engine from both sides, the SQL GROUP BY folding at 536378 rows a
second while the manual cursor walk manages 307199, and they agree:
min and max exact on all 412 stations, every average within
1.67e-15 of the walk's own sum over count.

The 10m rate extrapolated sanely, 0.87 GB an order and change, so
the 100 million row one-off ran too, alone, sequential, an 8.74 GB
database written and deleted on 2026-09-13:

#listing("python/samples/bench/captures/2026-09-13-row-100m.txt", first: 1, last: 9, caption: [the 100m row one-off: insert held its rate, the tail thinned by count but never disappeared, the walk caught the engine])

The insert rate held at 340936 rows a second, ten times the rows in
9.6 times the seconds, and the tail tells the same story at both
scales: p50 barely moves, 25.71 to 24.75 ms, while the max climbs to
138.31 ms across 10000 commits. The aggregation gap closed as the
table outgrew the caches, the SQL pass falling to 390718 rows a
second and the walk nearly catching it at 332489, because at 8.74 GB
both passes are disk-bound and the interpreter's per-row tax
shrinks to a share of the seek. One billion rows is math only,
roughly 87 GB by the measured rate, "not measured on this machine".

#diagram([the 10m run as two rates and a tail: insert and both aggregates in rows a second, the commit ladder underneath in milliseconds], length: 13pt, {
  let rate(x, label, r) = {
    cdraw.content((x, 8.6), [label], wrap: text.with(size: 6pt), anchor: "east")
    let w = r / 550000 * 8.2
    cdraw.rect((x + 0.4, 8.28), (x + 0.4 + w, 8.92), fill: luma(170), radius: 0.0)
    cdraw.content((x + 0.6 + w, 8.6), [#(str(int(r))) /s], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  }
  rate(8.2, [insert], 327703)
  rate(8.2, [sql group by], 536378)
  rate(8.2, [manual walk], 307199)
  cdraw.line((8.6, 1.0), (8.6, 9.6), stroke: 0.5pt + luma(180))
  let bar(x, label, ms) = {
    let h = ms / 120.0 * 5.0
    cdraw.rect((x, 1.2), (x + 1.3, 1.2 + h), fill: luma(200), radius: 0.0)
    cdraw.content((x + 0.65, 1.2 + h + 0.34), [label], wrap: text.with(size: 6pt))
    cdraw.content((x + 0.65, 0.9 - 0.0), [#ms ms], wrap: text.with(size: 6pt, fill: luma(100)))
  }
  bar(11.4, [p50], 25.71)
  bar(14.4, [p95], 30.13)
  bar(17.4, [p99], 39.60)
  bar(20.4, [p99.9], 114.16)
  cdraw.content((16.0, 7.6), [the commit tail over 1000 chunks], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((16.0, 6.6), [the median is not the story, the 1 in 1000 is], wrap: text.with(size: 6pt, fill: luma(100)))
})

=== the same kernel on duckdb

The corpus ran this kernel on duckdb too, from c and from go, and
those chapters hold the engine-side numbers. The c twin, same 412
stations and rows bit-identical to its sqlite lane, measured the
appender at 1.05 to 1.12 million rows a second against sqlite's
batched 464,047, the group by at 79.6 to 83.3 million against
555,402, 143x to 150x, while the go lane appended 774,437 rows a
second with its group by at 124,918,491 over the engine's own thread
pool, all 2026-09-20 on duckdb 1.5.5. This book's lane stays the
stdlib `sqlite3` anyway: the kernel's story is the commit ladder,
percentiles over 10k-row transactions, and the module ships inside
the interpreter with nothing to install. Pandas is the adjacent
name: a frame converts into duckdb, and duckdb queries arrow and
parquet directly. Which engine a workload wants is measured in
#xref-to("infrastructure", "duckdb") and chosen in
#xref-to("infrastructure", "duckdb-sqlite").

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

#callout("verify", "30 checks, the boundary asserted first", [
  A scoped run, `pwsh tools/run-py-samples.ps1 -Chapter Ch14`, walks
  the five samples through the run and format legs and reports: 5
  files, 30 checks, format clean. `cprofile_top.py` carries the
  interpreter pin and contributes 5, the call totals, the top name by
  tottime, the ten-times margin, and the 465 over 1 recursion column.
  `clocks.py` adds 6, the two clock identities, the default timer,
  monotonicity, the read-cost pin, and the cost ladder's shape.
  `percentiles.py` adds 6, the two exact ladders, the sample-membership
  rule, the pinned gaussian percentiles, monotonicity, and the edges.
  `monitoring.py` adds 7, the import refusal, the tool ids, the
  global count, the mask readback, the 15 and 6 census, the squat
  refusal, and the clean teardown. `rowkernel.py` adds 6, the sqlite
  pin with the removed attribute, the seeded checksum, the two passes
  agreeing on 412 stations, the distinct count, and the cleanup. The
  slow numbers this chapter quotes all live in
  `samples/bench/`, never in the gate.
])

sources: docs.python.org/3/library/profile.html (deterministic
profiling defined, tottime and cumtime, the sort order, the
recursion column), docs.python.org/3/library/timeit.html (the common
traps, gc off during timing, the min of the repeats),
docs.python.org/3/library/time.html (get\_clock\_info and the two
clock implementations),
docs.python.org/3/library/sys.monitoring.html (tool ids 0 to 5, the
local event list, global and local activation, the BRANCH
deprecation), peps.python.org/pep-0669/ (the order-of-magnitude
tracing slowdown, six tools at once, local events add to global),
docs.python.org/3/library/sqlite3.html (sqlite\_version defined, the
implicit insert transaction, executemany's transaction handling, the
version constants removed in 3.14), all accessed 2026-09-13. The
gauss draws ride the random module page chapter 23 already pins, and
every quoted capture, the sidebar refusal, and both 100m one-offs
are this machine's own, dated 2026-09-13. Sample behavior verified
by `make verify-py`, 30 checks in chapter 14.
