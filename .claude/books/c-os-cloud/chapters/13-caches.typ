#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= caches and locality

The caches sit between the code of the earlier chapters and the metal
of this one, and nothing in the C standard mentions them. Everything
this chapter claims comes from three places: the operating system,
asked through `GetLogicalProcessorInformation` what caches this cpu
actually declares; a simulator, whose hit, miss, and eviction counts
are computed by hand first and asserted second; and the wall clock,
printed and never checked, because timing is a machine fact and this
book only asserts facts that cannot drift. The constant under all of
it is the 64-byte line, the unit of traffic at every level, verified
below by probe rather than assumed from folklore.

== the hierarchy and line granularity

The probe walks the documented buffer protocol exactly. The first call
passes `NULL` and a length of 0, fails, and leaves the required size
in `ReturnedLength` with `GetLastError` reporting
`ERROR_INSUFFICIENT_BUFFER`; the second call passes a buffer of that
size and succeeds. The function page states the protocol in one
breath: on failure the error is reported and the length is set to the
buffer size required, and the struct page warns that the returned
order may change between calls, so the walk treats the records as an
unordered set. Each record carries a `Relationship`, and only
`RelationCache` records matter here: their payload is a
`CACHE_DESCRIPTOR` with `Level` (1, 2, 3 for L1 through L3),
`Associativity` (`CACHE_FULLY_ASSOCIATIVE`, 0xff, marks a fully
associative cache), `LineSize` documented as the cache line size in
bytes, and `Size` in bytes. The struct page is candid about
completeness: there is one record returned for each cache reported,
some or all caches may not be reported depending on how the processor
identifies them, so the absence of any particular cache is not a fact.

#listing("c-os-cloud/samples/src/Ch13/cachesim.c", first: 100, last: 119, caption: [the probe: sizing by refusal, then one `CACHE_DESCRIPTOR` per `RelationCache` record])

On this machine the probe prints 34 cache records and they sketch a
hybrid cpu. Eight P cores, each with a 48 KiB 12-way L1 data cache, a
32 KiB L1 code cache, and a private 1280 KiB 10-way L2, every record's
mask pairing two logical processors. Four E cores with 32 KiB L1 data
and 64 KiB L1 code, sharing one 2048 KiB 16-way L2 per cluster of
four. One 25600 KiB 10-way L3 whose mask, 0xFFFFF, spans every
logical processor the os knows. The type names printed beside each
level, unified, data, code, are the `PROCESSOR_CACHE_TYPE` values.
Two checks close the probe: at least three levels are reported, and
all 34 records carry the same line size, 64 bytes. That number is the
`LINE` constant the simulator runs on, and every later section of
this chapter is a consequence of it.

The simulator is a set-associative model with least-recently-used
replacement, small enough to read in one sitting. A cache is
`sets * ways` slots, each holding a tag or -1, with a stamp per slot
and a clock bumped on every access. One access takes an address,
divides by 64 to get the line number, takes the set index as `line %
sets` and the tag as `line / sets`, then scans the set:

#listing("c-os-cloud/samples/src/Ch13/cachesim.c", first: 56, last: 71, caption: [first half of one access: the set and tag arithmetic, the hit path, the empty-slot scan])

A hit refreshes the slot's stamp and returns. The scan also remembers
the first empty slot it sees, which is what the second half uses:

#listing("c-os-cloud/samples/src/Ch13/cachesim.c", first: 72, last: 83, caption: [second half: evict the least recently used slot when the set is full, fill, count the miss])

Every trace below runs on a fresh 4-set, 2-way cache: 8 lines, 512
bytes, small enough to hand-simulate. The first two traces pin the
line granularity itself. Walking bytes 0 through 63 is one miss and
63 hits, because the whole range is one line; walking it twice is one
miss and 127 hits, temporal reuse the simulator charges nothing for.

#listing("c-os-cloud/samples/src/Ch13/cachesim.c", first: 148, last: 160, caption: [traces 1 and 2: one line walked once, then twice])

The third trace is the conflict miss: addresses 0, 512, and 1024 are
lines 0, 8, and 16, and with 4 sets all three land in set 0. Two ways
cannot hold three rotating lines, so every access misses, and the
model counts 6 misses, 0 hits, and 4 evictions, the evictions being
the fills that displaced a line which came back one access later.

#listing("c-os-cloud/samples/src/Ch13/cachesim.c", first: 162, last: 168, caption: [trace 3: three rotating lines thrash the 2-way set])

The fourth trace is this chapter's thesis in miniature: the same 64
additions, two address sequences. `by_int` walks 64 consecutive ints
inside 256 bytes, 4 lines, so 4 misses. `by_line` spreads the same
count one int per line across 4096 bytes: 64 misses and 56 evictions.
Nothing about the arithmetic changed. The stride is the whole story,
and the next section scales it to a real matrix.

#listing("c-os-cloud/samples/src/Ch13/cachesim.c", first: 170, last: 183, caption: [trace 4: 64 additions as 4 misses or as 64, only the stride differs])

#diagram([the hierarchy the probe reported, one layer per level, the 64-byte line riding every boundary], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (15.6, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((8.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  layer(7.4, [core registers: where the additions from trace 4 happen], fill: luma(205))
  layer(6.1, [l1d: 48 KiB 12-way per P core, 32 KiB per E core])
  layer(4.8, [l2: 1280 KiB per P core, 2048 KiB per E cluster])
  layer(3.5, [l3: 25 MiB 10-way, one for the whole package])
  layer(2.2, [dram: the 64 MiB matrix of the next section lives here], fill: luma(205))
  cdraw.content((8.3, 1.1), [every boundary moves whole 64-byte lines, the probe's one stable constant], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((20.4, 6.6), [P cores: masks 0x3 to 0xC000], wrap: text.with(size: 6pt))
  cdraw.content((20.4, 4.15), [E cluster L2: mask 0xF0000], wrap: text.with(size: 6pt))
  cdraw.content((20.4, 2.6), [L3 mask: 0xFFFFF], wrap: text.with(size: 6pt))
})

== row-major versus column-major

C stores a 2-D array as one flat block, so `m[r][c]` is the int at
`r * N + c` and the language has said nothing about caches. The dsa
book's arrays chapter built a line-count model for exactly this shape
and asserted counts without timing; this chapter rebuilds the model
in C, asserts the same style of counts, and then does what the dsa
chapter declined to do: put a clock on it.

#listing("c-os-cloud/samples/src/Ch13/locality.c", first: 40, last: 48, caption: [the line model in c: lines fetched by a walk of evenly spaced touches])

A walk of 4096 ints at stride 4 touches 256 lines. A walk of 4096
ints at stride 16384, the column stride of a 4096 by 4096 matrix,
touches 4096 lines: sixteen times the traffic for the same additions.
Both walks in the sample run over the whole matrix, both accumulate
into an `unsigned long long`, and both must equal the closed form,
523776 per period of 1024 values times 16384 periods, which also pins
the iteration count: any walk that skipped or repeated an element
would miss the total.

#listing("c-os-cloud/samples/src/Ch13/locality.c", first: 62, last: 84, caption: [fill, closed form, row-major and column-major walks, both sums checked against the same total])

The measured result is the chapter's first surprise. Across the runs
observed while writing, the 64 MiB column walk lands within a few
percent of the row walk, a ratio between 0.9 and 1.1, nothing like
the 16x the line model charges. The model is not wrong, the machine
is generous: a constant stride is a pattern, and the hardware
prefetchers this cpu documents as a tunable feature fetch ahead of
it. Intel publishes a paper titled Hardware Prefetch Controls whose
own description is tuning methods used to optimize the performance of
hardware prefetchers, and the effect is measurable here as the
collapse of the column-walk penalty. The strided sweep makes the same
point from another side: stride 4 costs 12.3 ms for 16777216
accesses, stride 64 costs 2.8 ms for 1048576, and time tracks the
1048576 lines both fetch, not the wildly different access counts.

#listing("c-os-cloud/samples/src/Ch13/locality.c", first: 86, last: 104, caption: [four strided walks, model exact for each, time printed never checked])

What the machine cannot hide is order with no pattern. The last walk
reads the first int of every one of the 1048576 lines, once in
address order and once through a fixed-seed linear congruential
generator driving a Fisher-Yates shuffle of the line indices, so the
two walks touch identical lines, fetch identical traffic, and produce
identical sums. Only the order differs, and the shuffled walk costs
between 2.3 and 3.4 times the sequential one across the runs observed
while writing. That gap, not the row-versus-column gap, is what
locality buys on this machine: sequential streams are free, pattern
dependence is not.

#listing("c-os-cloud/samples/src/Ch13/locality.c", first: 124, last: 138, caption: [the two orderings: same lines, same sum, only the address sequence differs])

#callout("note", "the model and the clock disagree, correctly", [
  The line model is an upper bound on traffic and a predictor of
  nothing by itself. The dsa book kept counts and refused to time;
  this chapter times and keeps the counts, and the two disagree in
  exactly one direction: measurements land at or below the model's
  predictions, because prefetchers and out-of-order execution can
  only remove waits the model counted, never add lines it did not.
  Assert the count, print the clock, and never the other way around.
])

#diagram([before and after: the same matrix column by column and row by row], length: 13pt, {
  // column walk: four lines, one int used per line (shaded dark)
  cdraw.content((12.6, 8.1), [column-major: 16 KiB stride between touches], wrap: text.with(size: 6.5pt))
  for b in range(4) {
    let x = 0.6 + b * 6.2
    for i in range(16) {
      let f = if i == 0 { luma(175) } else { luma(240) }
      cdraw.rect((x + i * 0.34, 6.9), (x + (i + 1) * 0.34, 7.6), fill: f, radius: 0.02)
    }
    cdraw.line((x, 6.75), (x + 5.44, 6.75), stroke: luma(100))
    cdraw.content((x + 2.72, 6.45), [line, 64 B], wrap: text.with(size: 6pt))
  }
  cdraw.content((12.6, 5.9), [one int used per line fetched, 4096 lines per column], wrap: text.with(size: 6pt, fill: luma(100)))
  // row walk: one line, sixteen ints used
  cdraw.content((8.2, 5.1), [row-major: stride 4 between touches], wrap: text.with(size: 6.5pt))
  for i in range(16) {
    cdraw.rect((0.6 + i * 0.95, 3.9), (1.55 + i * 0.95, 4.6), fill: luma(175), radius: 0.02)
  }
  cdraw.line((0.6, 3.75), (15.8, 3.75), stroke: luma(100))
  cdraw.content((8.2, 3.45), [one line, 64 B, every int used], wrap: text.with(size: 6pt))
  cdraw.content((12.6, 2.9), [256 lines per row: the model's 16x, measured near parity], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.6, 2.1), [same 1048576 lines, sequential against shuffled: 2.3x to 3.4x, order is the cost], wrap: text.with(size: 6.5pt))
})

== false sharing and padding

Two threads, two counters, and a program with no data race can still
share a cache line. The layout below is the whole story: in `struct
tight`, both 8-byte atomics sit inside the one line that `_Alignas`
started at `a`; in `struct padded`, the second `_Alignas` pushes `b`
to the next line boundary at the cost of 56 bytes. Every one of those
facts is a compile-time constant the checks pin, `offsetof`, `sizeof`,
`_Alignof`, plus one runtime check that the statics really landed on
64-byte boundaries.

#listing("c-os-cloud/samples/src/Ch13/falsesharing.c", first: 32, last: 46, caption: [the two layouts: one line with both counters, or one line each, 56 bytes paid])

Each worker runs N relaxed fetch-adds on its own counter and never
reads the other's, so `memory_order_relaxed` is the honest ordering:
no synchronization is being purchased. The workers come from
`threads.h`, pinned in chapter 1 as working through the msvc 14.44
crt. `thrd_create` and `thrd_join` are chapter 15's calls, start and
reap, and the ordering vocabulary behind `relaxed` is chapter 16's.
Here it only matters that a fetch-add is one indivisible
read-modify-write.

#listing("c-os-cloud/samples/src/Ch13/falsesharing.c", first: 57, last: 64, caption: [the worker: N relaxed atomic increments of one counter])

The pairing function times create-and-join as one interval with the
`QueryPerformanceCounter` clock the previous section used, documented
as a high resolution timestamp for interval measurement that always
succeeds with valid parameters on current windows. At `-O2` the
fetch-add of 1 lowers to locked increments, `lock incq`, 45 of them
in the unrolled loops of this build, and the gate pins the `lock`
prefix in the disassembly: an atomic read-modify-write demands
exclusive ownership of its line.

#listing("c-os-cloud/samples/src/Ch13/falsesharing.c", first: 66, last: 77, caption: [the timed pair: two workers on two counters, one clock])

That ownership requirement is why the tight pair loses. Both threads
issue `lock incq` against the same 64 bytes, and every locked
instruction forces the line through cache coherence, the protocol that
keeps per-core caches consistent, so the two threads serialize on
ownership even though no C object is shared.
The padded pair issues the same instructions against different lines
and the ping-pong disappears. The correctness story is deliberately
boring: each thread adds exactly N, both layouts end with N and N,
and the checks say so. The timing is printed once per layout, and
across the runs observed while writing the tight pair costs 345 to
410 ms against 96 to 151 ms padded, a gap of 3 to 4 times that the
gate will never assert.

#listing("c-os-cloud/samples/src/Ch13/falsesharing.c", first: 79, last: 89, caption: [the layout facts as compile-time constants, checked before any thread starts])

#listing("c-os-cloud/samples/src/Ch13/falsesharing.c", first: 91, last: 105, caption: [both runs, exact totals either way, timing printed only])

#diagram([one line, two owners, and the coherence traffic that follows], length: 13pt, {
  // tight panel
  cdraw.content((5.5, 8.3), [tight: both counters, one line], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.8, 6.9), (3.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.0, 7.25), [thread 1], wrap: text.with(size: 6pt))
  cdraw.rect((7.8, 6.9), (10.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((9.0, 7.25), [thread 2], wrap: text.with(size: 6pt))
  cdraw.rect((1.6, 5.2), (3.5, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((2.55, 5.6), [a, 8 B], wrap: text.with(size: 6pt))
  cdraw.rect((3.5, 5.2), (5.4, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((4.45, 5.6), [b, 8 B], wrap: text.with(size: 6pt))
  cdraw.rect((5.4, 5.2), (10.6, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((8.0, 5.6), [48 bytes of the same line], wrap: text.with(size: 6pt))
  cdraw.line((10.6, 5.05), (10.6, 4.8), stroke: luma(100))
  cdraw.line((1.6, 4.8), (10.6, 4.8), stroke: luma(100))
  cdraw.content((6.1, 4.5), [one 64-byte line], wrap: text.with(size: 6pt))
  cdraw.line((2.0, 6.9), (2.55, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.0, 6.9), (4.45, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.5, 3.6), [every lock incq from either side takes the whole line], wrap: text.with(size: 6pt, fill: luma(100)))
  // padded panel
  cdraw.content((18.6, 8.3), [padded: one counter per line], wrap: text.with(size: 6.5pt))
  cdraw.rect((12.6, 6.9), (15.0, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((13.8, 7.25), [thread 1], wrap: text.with(size: 6pt))
  cdraw.rect((21.4, 6.9), (23.8, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((22.6, 7.25), [thread 2], wrap: text.with(size: 6pt))
  cdraw.rect((12.6, 5.2), (14.5, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((13.55, 5.6), [a, 8 B], wrap: text.with(size: 6pt))
  cdraw.rect((14.5, 5.2), (19.7, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 5.6), [56 bytes of padding], wrap: text.with(size: 6pt))
  cdraw.rect((19.7, 5.2), (21.6, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((20.65, 5.6), [b, 8 B], wrap: text.with(size: 6pt))
  cdraw.rect((21.6, 5.2), (23.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((22.7, 5.6), [56 B], wrap: text.with(size: 6pt))
  cdraw.line((19.7, 5.05), (19.7, 4.8), stroke: luma(100))
  cdraw.line((12.6, 4.8), (23.8, 4.8), stroke: luma(100))
  cdraw.content((16.3, 4.5), [two 64-byte lines], wrap: text.with(size: 6pt))
  cdraw.line((13.8, 6.9), (13.55, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((22.6, 6.9), (20.65, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.6, 3.6), [ownership never crosses threads, same instructions], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.6, 2.4), [measured: tight 345 to 410 ms, padded 96 to 151 ms, totals identical], wrap: text.with(size: 6.5pt))
})

== array of structs versus struct of arrays

Layout is a cache decision the type system silently makes. One
particle is four ints, 16 bytes, exactly four per line. The
array-of-structs layout interleaves `x` with the three fields an
x-only sweep never reads; the struct-of-arrays layout gives every
field its own contiguous array. Both x kernels are marked `noinline`
so their `-O2` bodies survive as separate functions and the gate can
pin what each became.

#listing("c-os-cloud/samples/src/Ch13/aossoa.c", first: 31, last: 47, caption: [the particle and the two x kernels, noinline to keep their bodies inspectable])

The model prices the difference immediately: sweeping x over
1048576 particles fetches 262144 lines from the interleaved array,
one line per four particles, and 65536 lines from the `xs` array, one
per sixteen. Four times the traffic for the same additions, and the
fill guarantees the two sweeps read equal values, so both sums must
equal the closed form 133693440. The all-field query is the control:
touching every field of every particle uses every byte of every line
the interleaved array fetches, and the model charges both layouts the
same 262144 lines. Layout follows the query mix, and there is no
universal winner.

#listing("c-os-cloud/samples/src/Ch13/aossoa.c", first: 91, last: 113, caption: [fill with identical values both ways, then the two x sweeps against one closed form])

#listing("c-os-cloud/samples/src/Ch13/aossoa.c", first: 115, last: 125, caption: [the all-field control: same lines both ways, sums equal])

The optimizer finishes the argument, and chapter 9 already pinned the
terms: the target's feature string is sse2, four `i32` lanes, no
gather instruction. At `-O2` the soa kernel is a textbook vectorized
reduction, two `load <4 x i32>` per pass feeding `add <4 x i32>`
accumulators, closing with `llvm.vector.reduce.add.v4i32`. The aos
kernel vectorizes too, but its lanes arrive one at a time: eight
scalar `load i32` strided 16 bytes apart, then eight `insertelement`
instructions building the two vectors by hand. Same arithmetic, same
reduction intrinsic, and every vector load the soa kernel got for
free the aos kernel had to assemble. The gate pins all three
substrings. Measured, the x sweep costs 1.0 to 1.7 ms interleaved
against 0.6 to 0.8 ms separate, and the all-field sweep, whose line
counts are identical, measures within noise of itself on both
layouts, exactly what the model predicted.

#diagram([the same particles two ways, and what each -O2 kernel loads], length: 13pt, {
  // aos strip
  cdraw.content((8.0, 8.3), [array of structs: x shaded, one line holds 4 particles], wrap: text.with(size: 6.5pt))
  for p in range(4) {
    for f in range(4) {
      let x = 0.8 + (p * 4 + f) * 1.2
      let fillc = if f == 0 { luma(205) } else { luma(235) }
      cdraw.rect((x, 7.1), (x + 1.2, 7.9), fill: fillc, radius: 0.02)
      cdraw.content((x + 0.6, 7.5), [#(("x", "y", "z", "c").at(f))], wrap: text.with(size: 6pt))
    }
  }
  cdraw.line((0.8, 6.95), (20.0, 6.95), stroke: luma(100))
  cdraw.content((10.4, 6.65), [the sweep uses 16 of every 64 bytes fetched], wrap: text.with(size: 6pt))
  // soa strips
  cdraw.content((8.0, 5.7), [struct of arrays: xs first, 16 per line], wrap: text.with(size: 6.5pt))
  for i in range(16) {
    cdraw.rect((0.8 + i * 0.75, 4.5), (1.55 + i * 0.75, 5.3), fill: luma(205), radius: 0.02)
  }
  cdraw.content((8.0, 4.05), [xs: every byte of every line is an x], wrap: text.with(size: 6pt))
  cdraw.content((8.0, 3.4), [ys, zs, cs: three more arrays, untouched by the x sweep], wrap: text.with(size: 6pt, fill: luma(100)))
  // ir note
  cdraw.content((10.4, 2.5), [-O2: soa loads \<4 x i32\> vectors, aos inserts eight scalar loads per pass], wrap: text.with(size: 6pt))
  cdraw.content((10.4, 1.8), [same sums, same reduce intrinsic, 262144 lines against 65536], wrap: text.with(size: 6pt))
  cdraw.content((10.4, 0.9), [layout decided the vector loads before the optimizer ran], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "one chapter, three kinds of evidence", [
  32 checks run at `-O0` and assert only deterministic facts: probe
  records, model counts, struct offsets, exact totals, equal sums.
  3 ir substrings and 1 disassembly substring are asserted on `-O2`
  output the runtime never executes. The timings quoted in this
  chapter, near parity for constant strides, 2.3x to 3.4x for
  shuffled order, 3x to 4x for the tight pair, 1.5x to 2x for the
  interleaved x sweep, are printed observations from the runs during
  writing, and no check anywhere in the chapter depends on them.
])

sources: learn.microsoft.com, GetLogicalProcessorInformation,
`SYSTEM_LOGICAL_PROCESSOR_INFORMATION`, CACHE_DESCRIPTOR,
`PROCESSOR_CACHE_TYPE`, and QueryPerformanceCounter pages, and
intel.com, Hardware Prefetch Controls for Intel Atom Cores, accessed
2026-09-12; cache hierarchy, timings, and emitted ir probed on this
machine the same day. Sample behavior verified by `make verify-c`,
32 checks in chapter 13 of the samples suite.
