#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow

= measurement, profiling, and p99

Chapters 13 through 18 printed clocks everywhere and never once checked
one. This chapter is what that discipline costs and buys: the clock
measured on this box, the percentile arithmetic written out by hand, a
sampling profiler built from `SuspendThread` and a context record, and
the variance of a real workload quoted as a range because a single
number is a coincidence wearing a unit. Every deterministic fact is
asserted, every timing is printed, and the harness at the end is the
one the capstone in chapter 21 reuses.

== clocks, measured

The clock is `QueryPerformanceCounter`, and the first thing the sample
does is ask it what it is. The frequency is fixed at boot and identical
across processors, the timestamps page says to query it once and cache
it, and on this box it answers 10 MHz: one tick every 100.0
nanoseconds. Monotonicity is not assumed from the faq's sentence, "QPC
does not go backward", it is measured, a thousand successive reads with
no decrease. The cost of reading is measured too, 14 to 16 ns per call
across the runs observed while writing, which is the overhead every
timed section in this book already carries.

#listing("c-os-cloud/samples/src/Ch20/qpc.c", first: 36, last: 43, caption: [the frequency once, cached, and the resolution it implies])

A sleep cross-checks the clock against `GetTickCount64`, whose own
granularity is the 15.625 ms scheduler tick. A 10 ms sleep measured
10.59 to 21.66 ms on the qpc clock across runs while the tick counter
stepped 16 or 31, both clocks telling the truth at their own
resolution: sleep is a promise to sleep at least that long, and both
bounds are asserted, not the value. The last probe is the faq's own
warning about conversion order, scale before dividing, and the two
orders agree to well under a microsecond at millisecond magnitudes
here, printed, not checked.

#listing("c-os-cloud/samples/src/Ch20/qpc.c", first: 45, last: 62, caption: [monotonicity as a measured fact, and the gap bound that keeps it honest])

#diagram([the clock ladder on this box: three time bases, three resolutions, one chosen], length: 13pt, {
  let row(y, name, res, note) = {
    cdraw.rect((0.8, y), (7.6, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((4.2, y + 0.5), name, wrap: text.with(size: 6pt))
    cdraw.content((8.0, y + 0.5), res, wrap: text.with(size: 6pt), anchor: "west")
    cdraw.content((12.2, y + 0.5), note, wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  }
  row(6.6, [qpc], [100.0 ns/tick], [10 MHz, fixed at boot, 14 to 16 ns to read])
  row(5.1, [GetTickCount64], [15.625 ms], [the scheduler tick, for sanity bounds only])
  row(3.6, [time(null)], [1 s], [wall time, never for intervals])
  cdraw.content((11.4, 2.3), [measured 2026-09-13 on this machine, every number a printed line], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the doctrine: assert the count, print the clock

The rule this book runs on was stated in chapter 13 and has not moved:
assertions are for facts that cannot drift, prints are for facts that
can. A checksum, a count of records, an offset, a sorted order: these
are deterministic, so a check pins them and the gate holds them forever.
A duration, a rate, a ratio: these are machine facts, so they are
printed with their unit and quoted in prose as the range observed
across runs, never as a single blessed number, and no check anywhere
depends on them. The reason is not aesthetics. Chapter 14's allocator
holds under every timing, chapter 19's ratios moved 8.8x to 10.3x
between two runs of the same binary on the same afternoon, and a suite
that asserted either of those would be a suite that fails on
Tuesdays. The one thing the doctrine adds in this chapter is the
middle case: a timing harness can be deterministic in what it measures
and statistical in what it observes, and that is exactly what
percentiles are for.

#diagram([the doctrine as a decision: every fact goes down one of two legs], length: 13pt, {
  cdraw.rect((8.6, 7.4), (15.4, 8.5), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 7.95), [a fact the code produced], wrap: text.with(size: 6pt))
  cdraw.line((10.4, 7.35), (5.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.6, 7.35), (18.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.6, 6.5), [can it drift run to run?], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((17.3, 6.5), [same question, other answer], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.rect((2.0, 5.0), (9.0, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((5.5, 5.5), [no: CHECK it], wrap: text.with(size: 6pt))
  cdraw.rect((15.2, 5.0), (22.2, 6.0), fill: luma(238), radius: 0.02)
  cdraw.content((18.7, 5.5), [yes: print it, quote a range], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 4.3), [counts, offsets, sums, order], wrap: text.with(size: 6pt))
  cdraw.content((18.7, 4.3), [durations, rates, ratios, percentiles], wrap: text.with(size: 6pt))
  cdraw.content((12.0, 3.2), [the gate holds the left column forever, the prose quotes the right column with a date], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== percentiles, nearest-rank, by hand

An average hides the tail, and the tail is where the users are. The
sample works in permilles so every rank is integer arithmetic: the rank
of p is `ceil(p * n / 1000)` written as `(p * n + 999) / 1000`, and the
percentile is the sorted array's value at that rank, nothing
interpolated. The hand-checkable arrays come first, the identity array
1 through 10 and an array of duplicates, and they pin the edges: p50 of
ten values is the 5th, p95 is the 10th because 9.5 rounds up, and
nearest-rank has no p0 because rank zero names nothing.

#listing("c-os-cloud/samples/src/Ch20/p99.c", first: 28, last: 34, caption: [the whole method: an integer ceil and one array index])

The seeded sample of 1000 carries the invariants that make the method
trustworthy at scale, sorted, monotone in p, and every percentile an
actual element of the sample, and because the generator is splitmix64
with a fixed seed, the sample is byte-identical run after run: p50
5267, p95 9532, p99 9915, p99.9 9988, min 17, max 9996, checked, not
quoted.

#listing("c-os-cloud/samples/src/Ch20/p99.c", first: 109, last: 132, caption: [the seeded sample, its invariants, and the reproducibility check that pins min and max])

#diagram([a sorted sample of ten with the rank marks p50, p90, p99 sit on], length: 13pt, {
  for i in range(10) {
    let x = 0.8 + i * 2.15
    cdraw.rect((x, 5.2), (x + 1.75, 6.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.87, 5.7), [#(i + 1)], wrap: text.with(size: 6pt))
  }
  let mark(rank, label, y) = {
    cdraw.line((0.8 + (rank - 0.5) * 2.15, y + 0.35), (0.8 + (rank - 0.5) * 2.15, 6.35), stroke: luma(120))
    cdraw.content((0.8 + (rank - 0.5) * 2.15, y), label, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  mark(5, [p50, rank 5], 4.4)
  mark(9, [p90, rank 9], 3.7)
  mark(10, [p99, rank 10], 3.0)
  cdraw.content((12.0, 2.0), [rank = ceil(p x n / 1000), no interpolation, every value a real sample], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.0, 1.2), [at n = 1000: p50 is the 500th, p99 the 990th, p99.9 the 999th], wrap: text.with(size: 6pt))
})

== a sampling profiler thread

A tracing profiler sees every call and slows everything down. A
sampling profiler sees almost nothing and costs almost nothing: suspend
the thread, read its instruction pointer, resume it, repeat about a
thousand times a second, and count where the pointers land. The
documented pairing is exact, the `GetThreadContext` page says "You
cannot get a valid context for a running thread. Use the SuspendThread
function to suspend the thread before calling GetThreadContext", and
the sample does precisely that, with `CONTEXT_CONTROL` asking only for
the control registers the instruction pointer lives in.

#listing("c-os-cloud/samples/src/Ch20/sampler.c", first: 120, last: 148, caption: [the sampling loop: suspend, read the rip, attribute, resume, sleep a millisecond])

The worker is built to be profiled: two `noinline` functions burning a
fixed 3:1 ratio of iterations, so the answer is known before the
question is asked. The suspend and resume counts pin the api contract,
`SuspendThread` returns the previous suspend count, 0 here, every time,
and `ResumeThread` returns the pre-resume count, 1, every time, 1600
sample cycles with zero failures. Every sample attributes to exactly
one symbol, and the histogram recovers the construction: 1199 samples
in `spin_hot` against 400 in `spin_cold`, 74.9 against 25.0 percent, a
measured ratio of 3.00 to 1 against the 3.0 it was built with, with
2.94 to 3.07 across the runs observed while writing.

#listing("c-os-cloud/samples/src/Ch20/sampler.c", first: 45, last: 53, caption: [the worker: a fixed 3:1 burn between two noinline functions])

#diagram([the sampling pipeline: one sample's round trip, a thousand times a second], length: 13pt, {
  let box(x, w, t, f) = {
    cdraw.rect((x, 5.4), (x + w, 6.4), fill: f, radius: 0.02)
    cdraw.content((x + w / 2, 5.9), t, wrap: text.with(size: 6pt))
  }
  box(0.8, 3.0, [SuspendThread], luma(235))
  box(4.6, 3.4, [GetThreadContext], luma(235))
  box(8.8, 2.6, [ctx.Rip], luma(205))
  box(12.2, 3.0, [attribute], luma(235))
  box(15.8, 3.0, [ResumeThread], luma(235))
  for x in (3.8, 8.0, 11.4, 15.2) {
    cdraw.line((x, 5.9), (x + 0.8, 5.9), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.4, 4.5), [sleep(1), about 1 kHz, 1600 samples in this run], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.4, 3.6), [prev count 0 in, prev count 1 out, every cycle, checked], wrap: text.with(size: 6pt))
  cdraw.content((11.4, 2.7), [measured: hot 74.9%, cold 25.0%, ratio 3.00 to 1, built as 3.0], wrap: text.with(size: 6.5pt))
})

== attribution without a toolchain

The rip is an address, not a name, and turning it into a name is the
attribution problem. The sample's answer is the one real symbolizers
use at their core: a table of symbols sorted by address, and each
sample attributed to the greatest symbol at or below it. The table is
emitted by the sample itself, three names and addresses, because the
binary knows its own functions, and the walk is four lines. The
measured result on this workload is total attribution, zero unknown
samples in 1600, because the worker never leaves its own two functions
plus the thread proc, and any address below every symbol attributes to
nothing rather than to a wrong name, asserted on a deliberate
out-of-range probe.

The platform's own answer is Event Tracing for Windows, "an efficient
kernel-level tracing facility that lets you log kernel or
application-defined events to a log file", with controllers, providers,
and consumers, recorded by the Windows Performance Recorder, "a
performance recording tool that is based on Event Tracing for Windows
(ETW)", and analyzed by WPA. The honest boundary on this box, probed
2026-09-13: the tools are present, `wpr.exe` in system32 and `wpa.exe`
with `xperf.exe` under the Windows Kits performance toolkit, but a
capture attempt from this book's unelevated shell fails at the first
step, "Failed to enable the policy to profile system performance",
error 0xc5585011. No capture is taken, no WPA graph is quoted, and the
hand sampler above is the profiler this book actually runs. The
`SuspendThread` page carries its own warning worth keeping, the
function "is primarily designed for use by debuggers. It is not
intended to be used for thread synchronization", and the sampler
respects it: the worker owns no lock while sampled.

#listing("c-os-cloud/samples/src/Ch20/sampler.c", first: 84, last: 90, caption: [attribution: greatest symbol at or below the rip, one linear walk])

#diagram([attribution: each rip walks down to the nearest symbol at or below it], length: 13pt, {
  let sym(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 0.85), fill: luma(205), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.42), t, wrap: text.with(size: 6pt))
  }
  cdraw.line((2.0, 8.2), (2.0, 2.0), stroke: 0.5pt + luma(180), mark: (start: "|", end: ">"))
  cdraw.content((2.5, 8.35), [address order], wrap: text.with(size: 6pt), anchor: "west")
  sym(4.2, 6.8, 3.4, [worker])
  sym(4.2, 5.2, 3.4, [spin_hot])
  sym(4.2, 3.6, 3.4, [spin_cold])
  cdraw.circle((2.0, 5.55), radius: 0.12, fill: luma(60))
  cdraw.content((2.6, 5.55), [a rip here], wrap: text.with(size: 6pt), anchor: "west")
  cdraw.line((2.15, 5.5), (4.2, 5.62), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.0, 6.0), [attributes to spin_hot, the nearest at or below], wrap: text.with(size: 6pt))
  cdraw.circle((2.0, 2.6), radius: 0.12, fill: luma(60))
  cdraw.content((9.0, 2.6), [below every symbol: no name, a bucket that stayed 0], wrap: text.with(size: 6pt))
  cdraw.content((11.4, 1.4), [etw and wpr exist here but the unelevated gate cannot start a trace: 0xc5585011], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== warmup, drift, and variance, measured

The workload is deliberately boring, sum 8 million seeded doubles, and
the check that matters is that it is exactly the same boring every
time: the generator fills the identical array from the same seed, and
all eight rounds produce the identical checksum to the last bit. The
timings then refuse to sit still, 16.07 to 19.33 ms per round across
the runs observed while writing, a spread of 15.7 to 17.4 percent
between min and median, with the first round landing anywhere from 94
to 108 percent of the median. That is this machine on this afternoon:
no clean warmup penalty, no steady state, noise that a single-run
number would silently launder into a fact.

#listing("c-os-cloud/samples/src/Ch20/variance.c", first: 102, last: 120, caption: [eight rounds, one checksum, and the statistics printed as ranges])

The statistics helpers are checked against hand-computable arrays
before they are trusted, the median of three and of four, min and max
bracketing, because a percentile library that is wrong in the small is
wrong in the large. The moral for every later chapter, including the
capstone: report min, median, and max over repeated runs, say how many
runs, and let the spread be part of the answer.

#diagram([eight rounds of one workload: the spread is the answer, not noise around it], length: 13pt, {
  let vals = (16.31, 17.95, 17.58, 18.67, 17.09, 19.33, 17.14, 16.70)
  let lo = 15.5
  for (i, v) in vals.enumerate() {
    let h = (v - lo) * 1.1
    cdraw.rect((1.0 + i * 2.6, 2.0), (1.0 + i * 2.6 + 1.6, 2.0 + h), fill: luma(225), radius: 0.02)
    cdraw.content((1.0 + i * 2.6 + 0.8, 1.5), [#i], wrap: text.with(size: 6pt))
  }
  let med_y = 2.0 + (17.36 - lo) * 1.1
  cdraw.line((0.8, med_y), (22.0, med_y), stroke: 0.5pt + luma(120))
  cdraw.content((22.2, med_y), [median], wrap: text.with(size: 6pt), anchor: "west")
  cdraw.content((11.4, 8.4), [one checksum, eight durations, spread 15.7 to 17.4 percent across runs], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the p99 harness this book reuses

Everything above condenses into one small type: a buffer of intervals,
a push, and a report that sorts a copy and prints p50 through p99.9
with the max. The capstone pushes commit latencies into it by the
thousand and quotes the tail, because ingestion throughput is an
average and an average is exactly the wrong summary for a database
commit. On the toy workload here, 2000 timed iterations of a
100-addition step, the harness prints p50 300 ns, p95 400 ns, p99 400
ns, p99.9 400 ns, max 15.5 microseconds: a flat little distribution
with one scheduler blip at the top, and the honesty is in the max line
the averages never show.

#listing("c-os-cloud/samples/src/Ch20/p99.c", first: 56, last: 76, caption: [the harness: push intervals, sort a copy, report the tail])

#listing("c-os-cloud/samples/src/Ch20/p99.c", first: 134, last: 146, caption: [one timed push loop: the pattern every later measurement fills in])

#diagram([the harness shape: many intervals in, five numbers out, the tail on the right], length: 13pt, {
  for i in range(24) {
    let x = 0.8 + i * 0.9
    let h = if calc.even(i) { 1.2 } else { 1.7 }
    cdraw.rect((x, 5.0), (x + 0.62, 5.0 + h), fill: luma(225), radius: 0.02)
  }
  cdraw.rect((18.2, 4.5), (19.4, 6.9), fill: luma(150), radius: 0.02)
  cdraw.content((18.8, 4.0), [max], wrap: text.with(size: 6pt))
  cdraw.line((9.0, 4.2), (16.0, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.5, 3.6), [sort, then index by rank], wrap: text.with(size: 6pt))
  let out(x, t) = cdraw.content((x, 2.4), t, wrap: text.with(size: 6pt))
  out(3.6, [p50])
  out(7.8, [p95])
  out(12.0, [p99])
  out(16.2, [p99.9])
  out(20.0, [max])
  cdraw.content((11.4, 1.0), [the tail is the product: chapter 21 pushes 1000+ commit latencies through this shape], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "one chapter, one clock, one tail", [
  39 checks run at `-O0` and assert only deterministic facts: rank
  arithmetic on hand-checkable arrays, the reproducible sample's pinned
  min and max, the suspend and resume counts, total attribution, the
  identical checksums, and the statistics helpers against known inputs.
  No ir pins and no roundtrip legs run in this chapter, every sample
  prints timings so their stdouts must stay out of byte-comparisons.
  The timings quoted in this chapter, the 10 MHz clock at 14 to 16 ns
  per read, sleep bounds, the 15.7 to 17.4 percent spread, the 3.00 to
  1 recovered ratio, are printed observations from the runs during
  writing, and no check anywhere depends on them.
])

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

sources: learn.microsoft.com, the acquiring high-resolution time stamps
page, and the SuspendThread, GetThreadContext, about Event Tracing, and
Windows Performance Recorder pages, accessed 2026-09-13. Clock facts,
qpc cost, sleep behavior, sampler counts, and variance measured on this
machine 2026-09-13; the wpr capture attempt and its 0xc5585011 failure
probed the same day from this book's unelevated shell. Sample behavior
verified by `make verify-c`, 39 checks in chapter 20 of the samples
suite.
