#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= profiling: hooks, clocks, and p99

Chapter 9 watched the collector. This chapter watches the program. Lua
gives one debug hook, one cpu clock, and no sampling profiler, so a
profiler here is built the honest way: exact hook counts over fixed
workloads, an instruction census that says instruction census and not
wall time, percentiles computed by hand, and on the LuaJIT side of the
tree the jit's own profiler dumping real numbers. Every figure in this
chapter is a real run on this machine, lua 5.5.1 and LuaJIT
2.1.1788856981 from `tools/`, dated 2026-09-13.

== clocks, on this machine

`os.clock` is process cpu time, the iso C `clock()` under it, and on
this windows build its smallest observed tick measured 1.000 ms over
200 changes: nothing faster than a millisecond can be timed by it, and
shorter intervals read as zero. `os.time` carries whole seconds. Stock
5.5 ships no monotonic clock at all, that is the honest boundary, and
one worth saying plainly: interval measurement below the tick, or
across wall-time disturbances, needs a host. The ffi side of the tree
has one, `QueryPerformanceCounter` declared through LuaJIT's ffi and
measured at 10000000 Hz on this machine:

#listing("lua/samples/ch10_profiling.lua", first: 19, last: 35, caption: [cpu time advances, wall time is whole seconds])
#listing("lua/samples/bench.lua", first: 76, last: 92, caption: [measuring the tick: the smallest observed os.clock step])

#diagram([three clocks, what each can and cannot see], length: 13pt, {
  // the three clock boxes
  cdraw.rect((0.8, 6.2), (7.4, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.1, 8.9), [os.clock], size: 6pt)
  cdraw.content((4.1, 7.9), [process cpu seconds], size: 6pt)
  cdraw.content((4.1, 6.9), [1.000 ms tick, measured], size: 6pt)
  cdraw.rect((8.0, 6.2), (14.4, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.2, 8.9), [os.time], size: 6pt)
  cdraw.content((11.2, 7.9), [wall clock], size: 6pt)
  cdraw.content((11.2, 6.9), [whole seconds only], size: 6pt)
  cdraw.rect((15.0, 6.2), (21.5, 9.4), fill: luma(205), radius: 0.02)
  cdraw.content((18.25, 8.9), [qpc, via ffi], size: 6pt)
  cdraw.content((18.25, 7.9), [monotonic, 10 mhz], size: 6pt)
  cdraw.content((18.25, 6.9), [jit side only], size: 6pt)
  // the verdict line
  cdraw.content((11.0, 5.0), [stock 5.5 has no monotonic clock, the host brings one], size: 6.5pt)
  cdraw.content((11.0, 3.8), [sub-millisecond intervals read zero under os.clock], size: 6.5pt)
  cdraw.content((11.0, 2.6), [every number here is cpu time unless it says wall], size: 6.5pt)
})

== the counting profiler

`debug.sethook` takes a mask of events and, for the count mask, a
budget: the hook fires after every budget instructions. On a fixed
workload the counts are exact, and that exactness is what makes a hook
usable as a deterministic instrument rather than a timing guess. The
50 iteration loop below compiles to a known instruction stream on this
build: a budget of 100 catches it once, a budget of 1 counts 112:

#listing("lua/samples/ch10_profiling.lua", first: 37, last: 53, caption: [exact counts on a fixed workload, no timing])

The line mask fires as the interpreter enters each new line, and the
call and return masks bracket every lua call. A tail call replaces the
frame, so it reports `tail call` and the caller's return never comes,
which is the profiler's view of chapter 6's proper tail calls:

#listing("lua/samples/ch10_profiling.lua", first: 55, last: 73, caption: [the line hook walks the three body lines])
#listing("lua/samples/ch10_profiling.lua", first: 75, last: 92, caption: [call and return events, the nesting exactly])
#listing("lua/samples/ch10_profiling.lua", first: 94, last: 116, caption: [a tail call erases the frame and its return])

#flow(
  [the hook masks, what each one sees],
  node((0, 0), [debug.sethook(f, mask, count)]),
  node((-2.9, 1.7), [call and return, #linebreak() c and r, every lua boundary]),
  node((0, 1.7), [line, l, #linebreak() each new source line]),
  node((2.9, 1.7), [count, every #linebreak() budget instructions]),
  node((0, 3.4), [all three are exact on fixed code, #linebreak() the whole chapter rests on that]),
  edge((0, 0), (-2.9, 1.7), "-|>"),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 0), (2.9, 1.7), "-|>"),
  edge((-2.9, 1.7), (0, 3.4), "-|>", bend: 20deg),
  edge((2.9, 1.7), (0, 3.4), "-|>", bend: -20deg),
)

== the census, honestly labeled

A real profiler in this world is a count hook at every K instructions
tallying `debug.getinfo` on the running line. Over a hot loop at
K = 200 the tally is a cliff: 327 hits standalone, all of them on the
loop line, none anywhere else. The honest label matters more than the
code: this counts instructions, not time. A hook costs far more than
the instruction it interrupts, samples are not uniform in wall time,
and attribution is exact only because the workload is one line. It is
an instruction census, and the chapter says so everywhere it quotes
one:

#listing("lua/samples/ch10_profiling.lua", first: 118, last: 140, caption: [the census: one hot line takes every sample])

#diagram([the census pipeline and its honest limits], length: 13pt, {
  // the pipeline
  cdraw.rect((0.8, 6.6), (5.6, 9.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 8.6), [count hook], size: 6pt)
  cdraw.content((3.2, 7.5), [every 200 #linebreak() instructions], size: 6pt)
  cdraw.line((5.8, 7.9), (6.8, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.0, 6.6), (12.4, 9.2), fill: luma(235), radius: 0.02)
  cdraw.content((9.7, 8.6), [getinfo(2, "l")], size: 6pt)
  cdraw.content((9.7, 7.5), [short_src and #linebreak() currentline], size: 6pt)
  cdraw.line((12.6, 7.9), (13.6, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.8, 6.6), (20.8, 9.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 8.6), [the tally], size: 6pt)
  cdraw.content((17.3, 7.5), [327 hits, one line, #linebreak() a cliff, not a curve], size: 6pt)
  // the honesty lines
  cdraw.content((11.0, 5.4), [it counts instructions, not time], size: 6.5pt)
  cdraw.content((11.0, 4.2), [a hook costs more than the instruction it stops], size: 6.5pt)
  cdraw.content((11.0, 3.0), [attribution is exact because the workload is one line], size: 6.5pt)
  cdraw.content((11.0, 1.8), [wall-time attribution needs sampling, and the host], size: 6.5pt)
})

== what a collector step costs

The collector's explicit step carries a measurable price. On the fixed
13 MB dropped heap of chapter 9's bench, step size 9600, a fresh
process cleared it in 4 steps and 2 cycle ends for 0.0050 s of cpu,
1250 us per step; inside the full sample suite the same heap needed
409 steps, the state dependence chapter 9 measured. The
number to carry is the shape, not a constant: step cost scales with
the step size knob and the collector's backlog:

#listing("lua/samples/bench.lua", first: 120, last: 143, caption: [timing the step loop at a fixed workload])

#diagram([one step's cost, measured against the heap it clears], length: 13pt, {
  // the axes: steps across, kb down
  cdraw.line((1.2, 3.0), (1.2, 9.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((1.2, 3.0), (20.8, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.9, 9.9), [13 MB], size: 6pt)
  cdraw.content((11.0, 2.4), [explicit steps], size: 6pt)
  // the drop
  cdraw.line((2.0, 9.4), (6.2, 3.1), stroke: luma(60))
  cdraw.content((5.4, 6.6), [fresh process: 4 steps, #linebreak() 2 cycle ends, 1250 us a step], size: 6pt)
  // the long tail comparison
  cdraw.line((7.0, 9.4), (18.6, 3.4), stroke: luma(120))
  cdraw.content((14.6, 7.0), [full suite state: 409 steps, #linebreak() same heap, same knob], size: 6pt)
  // the lesson
  cdraw.content((11.0, 1.6), [the shape is the fact, the count is the state], size: 6.5pt)
})

== percentiles by hand

Nearest-rank is the whole definition: sort, take the value at
`ceil(p/100 * n)`. No interpolation, nothing to get wrong. The suite
pins it against a fixed 1000 element vector with all four ranks as
literals, then measures 1024 real chunk latencies, one kernel step of
10000 particles each, sized above the 1 ms clock floor so the table
resolves. Measured on this machine, 2026-09-13: p50 1 ms, p95 2 ms,
p99 3 ms, p99.9 3 ms, max 3 ms, and 98 of 1024 chunks still read zero
at the floor, the quantization stated rather than smoothed away:

#listing("lua/samples/ch10_profiling.lua", first: 5, last: 16, caption: [the definition and the fixed workload])
#listing("lua/samples/ch10_profiling.lua", first: 142, last: 170, caption: [pinned literals, then measured latencies ordered])

#diagram([the nearest-rank ladder over the sorted vector], length: 13pt, {
  // the sorted vector as a strip
  cdraw.rect((1.2, 6.4), (20.8, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 7.0), [the sorted vector, n = 1024], size: 6pt)
  // the rank marks
  let mark(x, label) = {
    cdraw.line((x, 6.2), (x, 5.2), stroke: luma(100))
    cdraw.content((x, 4.6), label, size: 6pt)
  }
  mark(6.0, [p50: rank 512, #linebreak() 1 ms measured])
  mark(11.6, [p95: rank 973, #linebreak() 2 ms])
  mark(15.6, [p99: rank 1014, #linebreak() 3 ms])
  mark(18.8, [p99.9: rank 1023, #linebreak() 3 ms])
  // the rules
  cdraw.content((11.0, 3.2), [ceil(p of 100 times n), the value at that rank, nothing else], size: 6.5pt)
  cdraw.content((11.0, 2.0), [98 of 1024 chunks read zero at the 1 ms tick, quantization kept visible], size: 6.5pt)
})

== the jit side of the tree

LuaJIT brings its own profiler, `jit.p`, and it speaks in compiled
traces, not interpreted instructions. Over the ffi particle loop at 1m
the line mode and the function mode each collapse to one entry,
quoted exactly as the dump printed it, 2026-09-13, LuaJIT
2.1.1788856981, x64:

#snippet("line profile of the loop (jit.p mode l):\n100%\x20 bench.lua:125\n\nfunction profile of the loop (jit.p mode f):\n100%\x20 step", lang: "text")

The kernel itself is the same eight fields and the same sixteen steps,
but dense: eight cdata double arrays, 64 bytes per particle, seeded by
a 32-bit xorshift because lua 5.1 numbers have no 64-bit integer
arithmetic. Measured alone on this machine: 1m particles at 9.9 ns
per particle per step, 10m at 7.1 ns, and the one-off 100m run at 8.2
ns in 6.4 gb of cdata, init 1.259 s, slowest step 0.965 s, run alone
and sequentially, state discarded after. Against chapter 9's boxed
tables the ratios are 11.5x at 1m, 114.1 against 9.9, and 20.8x at
10m, 148.0 against 7.1: the boxed form pays twice over, 2.1x the
bytes and several times the arithmetic, and the gap widens with scale
as the boxed heap outruns cache:

#listing("lua/jit/bench.lua", first: 21, last: 44, caption: [the monotonic clock and the two extra ffi calls the bench declares])
#listing("lua/jit/bench.lua", first: 49, last: 59, caption: [the jit side generator, 32-bit and honest about it])

#diagram([two profilers over one tree of kernels], length: 13pt, {
  // the 5.5 side
  cdraw.rect((0.8, 6.0), (10.0, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 9.1), [the 5.5 side], size: 6pt)
  cdraw.content((5.4, 8.0), [debug.sethook census, #linebreak() exact counts, no sampling], size: 6pt)
  cdraw.content((5.4, 6.8), [os.clock cpu, 1 ms tick], size: 6pt)
  // the jit side
  cdraw.rect((10.8, 6.0), (21.5, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((16.15, 9.1), [the luajit side], size: 6pt)
  cdraw.content((16.15, 8.0), [jit.p over compiled traces, #linebreak() one loop, one entry, 100 percent], size: 6pt)
  cdraw.content((16.15, 6.8), [qpc wall plus os.clock cpu], size: 6pt)
  // the shared kernel row
  cdraw.rect((0.8, 3.6), (21.5, 5.6), fill: luma(245), radius: 0.02)
  cdraw.content((11.15, 5.1), [the same kernel, two representations], size: 6pt)
  cdraw.content((11.15, 4.1), [boxed 133.4 B, 114.1 ns versus cdata 64 B, 9.9 ns at 1m], size: 6pt)
  // the verdict
  cdraw.content((11.0, 2.6), [the interpreter counts instructions, the jit shows where code ceases to be interpreted], size: 6.5pt)
  cdraw.content((11.0, 1.4), [100m boxed is infeasible by design, 100m cdata ran at 8.2 ns], size: 6.5pt)
})

== the row kernel, ten million rows

The second corpus workload rides the ffi sqlite wrapper chapter 17
pinned, 3.53.4 asserted at require time, with two extra declarations
the teaching wrapper does not carry, `bind_double` and `reset`. The
schema is the shared contract, one station key and eight real columns;
412 stations st000 through st411; seeded values; 10k-row batched
transactions over one prepared statement. Measured alone on this
machine, 2026-09-13: 10m rows inserted at 504,765 rows per second,
the 24-aggregate SQL GROUP BY at 573,915 rows per second, the manual
cursor walk at 580,353 rows per second, and the two aggregation paths
agree, min and max exactly, averages within 1e-9 scaled by the column
max because the scan orders differ. The 100m-row one-off ran alone
and sequentially the same day: insert 100,000,000 rows in 203.886 s,
490,469 rows per second, 10000 batches, the insert rate holding its
10m pace within 3 percent, while the aggregations paid for the scale,
SQL group by 313.430 s at 319,050 rows per second and the manual walk
346.036 s at 288,987 rows per second, roughly half their 10m rates as
the table, past 8 gb on disk, outran cache. Agreement held intact,
and the database was deleted after the numbers were read off. The
one billion row scale stays by math only, not measured on this
machine:

#listing("lua/jit/bench.lua", first: 142, last: 177, caption: [schema, stations, prepared insert, batched transactions])
#listing("lua/jit/bench.lua", first: 178, last: 191, caption: [aggregation a, one group by with 24 aggregates])
#listing("lua/jit/bench.lua", first: 192, last: 224, caption: [aggregation b, the manual cursor walk])

#flow(
  [the row kernel, ingestion to two agreeing aggregates],
  node((0, 0), [prepared insert, #linebreak() one statement, reset per row]),
  node((0, 1.7), [10k row transactions, #linebreak() 1000 batches at 10m]),
  node((0, 3.4), [10m rows, #linebreak() 504765 rows per second measured]),
  node((3.0, 3.4), [sql group by, #linebreak() 24 aggregates, 573915 rows/s]),
  node((-3.0, 3.4), [manual walk, #linebreak() 580353 rows/s]),
  node((0, 5.1), [the paths agree: #linebreak() min max exact, avg within 1e-9]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (0, 3.4), "-|>"),
  edge((0, 3.4), (3.0, 3.4), "-|>"),
  edge((0, 3.4), (-3.0, 3.4), "-|>"),
  edge((3.0, 3.4), (0, 5.1), "-|>", bend: 20deg),
  edge((-3.0, 3.4), (0, 5.1), "-|>", bend: -20deg),
)

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

sources: lua.org manual 5.5 sections 6.10 (os.clock, os.time), 6.11
(debug.sethook, getinfo), accessed 2026-09-13; luajit.org profiler
page for jit.p semantics, accessed 2026-09-13. All measurements from
lua 5.5.1 and luajit 2.1.1788856981 built under `tools/`, run on this
machine, 11 tests green through `make verify-lua`.
