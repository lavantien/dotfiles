#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= allocation: mspans, size classes, escape analysis, sync.Pool

Every go allocation funnels through one function, `mallocgc`, and
almost all of them resolve without a lock. This chapter walks the
path a 17-byte allocation actually takes on go 1.27, quotes the
runtime's own size class table, makes escape analysis print its
verdicts, demonstrates the pool layer the runtime sanctions on top,
and closes on the corpus particle kernel in both memory layouts,
measured on this machine.

== the fast path

`mallocgc` sorts every request into tiny, small, or large before
anything else: noscan objects under 16 bytes go to the tiny
allocator, everything up to 32 KiB takes the size class path through
the per-P `mcache`, and everything larger goes straight to `mheap`
in whole pages. The 1.27 runtime compiles the small path into 81
size-specialized routines (`runtime/malloc_tables_generated.go`,
`mallocScanTable`), the change behind the up to 30 percent faster
sub-80-byte allocations the runtime chapter cites, and ordinary
code can watch the decisions it makes:

#listing("go/samples/ch10/classes.go", first: 8, last: 38, caption: [one allocation, then read the bucket that moved])

`ReadMemStats` stops the world, so the `BySize` histogram it
returns is exact: bucket N counts the mallocs the runtime charged
to that size class. The test built on this helper feeds it 8, 16,
17, 24, 25, 32, 33, 48, 64, and 80 byte requests and reads back 16,
16, 24, 24, 32, 32, 48, 48, 64, 80, the table's rounding decisions
observed live rather than trusted from a book.

#flow(
  [every request sorted at the door, three doors out],
  node((0, 0), [mallocgc(size, type)]),
  edge((0.9, 0.35), (2.2, 1.1), "-|>", label: [under 16 b, noscan]),
  edge((0.9, 0), (2.2, 0), "-|>", label: [under 32 kib]),
  edge((0.9, -0.35), (2.2, -1.1), "-|>", label: [over 32 kib]),
  node((3.5, 1.1), [tiny block, 16 b class]),
  node((3.5, 0), [mcache, size class]),
  node((3.5, -1.1), [mheap, whole pages]),
)

The sorting is why allocation cost in go is roughly constant per
size class, not per byte: a 40-byte and a 48-byte allocation cost
the same work, both are class 5.

== the mspan

The unit underneath every small allocation is the mspan, a run of
8 KiB pages (`PageShift` is 13) carved into same-size objects. Each
span carries `startAddr` and `npages`, an `allocBits` bitmap with
one bit per object slot, and a `freeindex` cursor so the next
allocation scans forward from the last hit instead of from the
start. Classes cap at `MaxObjsPerSpan` 1024 objects and
`MaxSizeClassNPages` 10 pages, which is why the smallest classes
fill 8192-byte spans with 1024 objects of 8 bytes and the largest
small class, 32768 bytes, is a span of one object. Every span also
carries a scan or noscan flavor, 68 classes times 2, because
pointer-free spans sweep and scan differently.

#diagram([one mspan: pages, the object bitmap, and the free cursor], length: 13pt, {
  cdraw.rect((0.3, 3.6), (23.3, 7.2), fill: luma(240), radius: 0.02)
  cdraw.content((11.8, 6.75), [one mspan, npages of 8 kib pages], size: 6.5pt)
  for i in range(10) {
    cdraw.rect((0.8 + i * 2.28, 4.4), (2.6 + i * 2.28, 5.9), fill: luma(222), radius: 0.02)
    cdraw.content((1.7 + i * 2.28, 5.15), [obj], size: 6pt)
    if calc.even(i) {
      cdraw.rect((0.8 + i * 2.28, 3.9), (2.6 + i * 2.28, 4.25), fill: luma(120), radius: 0.02)
    } else {
      cdraw.rect((0.8 + i * 2.28, 3.9), (2.6 + i * 2.28, 4.25), fill: luma(255), stroke: luma(180), radius: 0.02)
    }
  }
  cdraw.content((11.8, 2.9), [allocBits: dark slot taken, light slot free], size: 6pt)
  cdraw.line((17.0, 3.6), (17.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.8, 1.8), [freeindex scans forward from the last hit], size: 6pt)
  pane(0.3, 11.3, 0.8, [spans come in two flavors], [68 size classes], [x 2: scan, noscan])
  cdraw.content((18.0, 0.1), [span class encodes both], size: 6pt)
})

A span's objects are contiguous, so freeing never compacts, it only
clears bits, and the mark-sweep collector from the runtime chapter
walks the same bitmaps when it decides what survives.

== mcache, mcentral, mheap

Three levels, one rule: the level that answers most allocations
takes no lock. Each P owns an `mcache` with one span per span class,
so a small allocation on the fast path is a bump inside a span the
running thread already owns. When a cache empties it refills from
the `mcentral` for that class, which holds partial and full span
sets split by swept and unswept, and that refill takes the class's
lock, amortized over a whole span of objects. `mheap` sits under
everything: the page allocator over arenas, and the direct source
for large objects.

#listing("go/samples/ch10/classes.go", first: 60, last: 81, caption: [totalalloc tells large objects from class hits])

The test around this helper measures the boundary from above: a
32768-byte allocation is accounted as exactly 32768 bytes, still the
top size class, while 32769 is accounted as 40960, five 8 KiB pages
from `mheap`, measured on this machine, 2026-09-13. There is no
class table entry in between, the large path rounds to whole pages.
Both readers retry until their reading is self-consistent, exactly one
bucket moved or exactly the allocation and nothing else, so a neighbor
goroutine's allocation landing inside the window cannot inflate or
misroute the count.

#diagram([the hierarchy: no lock, one lock, the global lock], length: 13pt, {
  cdraw.rect((0.3, 4.6), (23.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.4, 6.7), [mcache, one per P], size: 6.5pt)
  cdraw.content((4.4, 5.6), [tiny + one span per class], size: 6pt)
  cdraw.content((4.4, 4.95), [no lock on the fast path], size: 6pt)
  for i in range(4) {
    cdraw.rect((9.0 + i * 1.5, 5.3), (10.1 + i * 1.5, 6.5), fill: luma(222), radius: 0.02)
  }
  cdraw.content((12.3, 6.7), [mspan per class], size: 6pt)
  cdraw.content((12.3, 5.8), [bitmap, freeindex], size: 6pt)
  pane(16.6, 23.3, 7.0, [allocation = a bump], [take the next free slot], [clear its bitmap bit])
  cdraw.line((11.8, 4.5), (11.8, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((14.9, 4.1), [refill: empty cache to mcentral], size: 6pt)
  cdraw.rect((4.5, 2.2), (19.1, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 3.25), [mcentral, one per span class], size: 6.5pt)
  cdraw.content((11.8, 2.5), [partial and full spans, swept and unswept], size: 6pt)
  cdraw.line((11.8, 2.1), (11.8, 1.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((4.5, -0.2), (19.1, 1.3), fill: luma(222), radius: 0.02)
  cdraw.content((11.8, 0.9), [mheap: pages over arenas], size: 6.5pt)
  cdraw.content((11.8, 0.1), [large objects come here directly], size: 6pt)
  cdraw.content((2.2, 2.5), [locks live below,], size: 6pt)
  cdraw.content((2.2, 1.4), [amortized per span], size: 6pt)
})

== the size class table

Go 1.27 moved the table out of `runtime/sizeclasses.go` into
`internal/runtime/gc/sizeclasses.go`, generated by
`runtime/_mkmalloc`, 67 real classes numbered 1 to 67, class 0
reserved for large objects. The excerpt below is a verbatim copy
from this machine's go 1.27.0 source, and every row the chapter
leans on is re-asserted against the live runtime by the tests:

#listing("go/samples/ch10/sizeclasses-go127.txt", first: 7, last: 30, caption: [classes 1 through 24, verbatim from the go 1.27 runtime source])

Read the columns as: class number, bytes per object, bytes per
span, objects per span, tail waste, max waste at the worst
request size, and minimum alignment. Class 3 is where a 17-byte
allocation lands, 24 bytes per object, 341 objects in an 8192-byte
span with 8 bytes of tail waste. The constants close the system:

#listing("go/samples/ch10/sizeclasses-go127.txt", first: 76, last: 88, caption: [the boundaries: 32 kib small, 16 byte tiny, 8 kib pages])

#listing("go/samples/ch10/classes_test.go", first: 25, last: 33, caption: [the 17-byte cost asserted as a measured heap slope])

That test retained 65536 objects of 17 bytes and measured the heap
grow by 24.000 bytes per object, 1572864 bytes total, the class 3
row holding up under measurement on this machine, 2026-09-13.

#diagram([class size against max waste, the spacing is the trade], length: 13pt, {
  cdraw.line((1.2, 0.6), (1.2, 6.8), stroke: luma(100))
  cdraw.line((1.2, 0.6), (23.0, 0.6), stroke: luma(100))
  cdraw.content((0.6, 4.0), [max, waste], size: 6pt)
  cdraw.content((12.1, 0.1), [the class ladder to 32 kib], size: 6pt)
  let cls = ((1, 8, 87.5), (2, 16, 43.75), (3, 24, 29.24), (4, 32, 21.88), (6, 64, 23.44), (10, 128, 11.72), (18, 256, 5.86), (26, 512, 6.05), (32, 1024, 12.4), (38, 2048, 12.45), (44, 4096, 15.6), (51, 8192, 15.61), (59, 16384, 12.49), (67, 32768, 12.5))
  for (c, size, waste) in cls {
    let x = 1.2 + calc.log(size, base: 2) / 15 * 21.5
    let y = 0.6 + waste / 100 * 6.2
    cdraw.rect((x - 0.25, y - 0.25), (x + 0.25, y + 0.25), fill: luma(140), radius: 0.02)
    if c == 1 or c == 4 or c == 18 or c == 44 or c == 67 {
      cdraw.content((x, y + 0.55), [#size #text(size: 6pt)[b]], size: 6pt)
    }
  }
  cdraw.content((19.5, 6.3), [max waste %], size: 6pt)
  cdraw.content((8.0, 5.6), [power-of-two classes align], size: 6pt)
  cdraw.content((8.0, 4.5), [and waste least], size: 6pt)
})

The alignment column encodes the same fact: class 1, 4, 6, 10, 18,
26 and friends are the power-of-two sizes, minimal waste, special
alignment, and go 1.27's specialized routines are densest exactly
there.

== tiny and large

Under 16 bytes and pointer-free, the tiny allocator packs multiple
objects into one 16-byte block, with a worst case of 2x waste when
all but one sub-object dies, a bound the runtime chose because 8
would waste nothing but combine nothing and 32 could waste 4x. The
measured consequence on this machine:

#listing("go/samples/ch10/classes_test.go", first: 35, last: 43, caption: [two 8-byte objects per 16-byte block, asserted as a slope])

65536 retained 8-byte objects grew the heap by exactly 8.000 bytes
per object, 524288 bytes, half the class 2 cost, the packing
observed. The `race_on.go` companion file flips the expectation to
16 under `go test -race`, because shadow memory needs one shadow
per object and the race detector disables the tiny allocator
entirely, a build mode visible in allocation counts. Above 32 KiB
the size classes end and pages begin:

#listing("go/samples/ch10/classes_test.go", first: 53, last: 63, caption: [the boundary: 32768 stays, 32769 pays five pages])

#diagram([tiny packing below, page rounding above], length: 13pt, {
  cdraw.rect((0.3, 3.8), (11.3, 7.2), fill: luma(240), radius: 0.02)
  cdraw.content((5.8, 6.75), [one 16-byte tiny block], size: 6.5pt)
  cdraw.rect((1.0, 4.6), (5.4, 6.2), fill: luma(222), radius: 0.02)
  cdraw.content((3.2, 5.4), [8 b, noscan], size: 6pt)
  cdraw.rect((5.6, 4.6), (10.0, 6.2), fill: luma(222), radius: 0.02)
  cdraw.content((7.8, 5.4), [8 b, noscan], size: 6pt)
  cdraw.content((5.8, 4.1), [freed only when every sub-object dies], size: 6pt)
  pane(12.7, 23.3, 7.2, [over 32 kib], [no class, no mcache], [mheap pages, 8 kib each])
  cdraw.content((5.8, 2.9), [32768 bytes -> 32768], size: 6pt)
  cdraw.content((5.8, 1.8), [32769 bytes -> 40960], size: 6pt)
  cdraw.content((5.8, 0.7), [measured on this machine, 2026-09-13], size: 6pt)
})

== escape analysis

Allocation avoidance is decided before the runtime ever sees a
request: escape analysis in the compiler assigns every value to a
stack frame or to the heap. The tool is `go build -gcflags=-m`,
and its verdicts for this chapter's own sample file were captured
verbatim and committed:

#listing("go/samples/ch10/escape.go", first: 33, last: 52, caption: [the quiet function allocates nothing, its neighbors say why])

#listing("go/samples/ch10/escape-m.txt", first: 73, last: 80, caption: [the compiler's verdicts for exactly those lines, captured 2026-09-13])

`moved to heap` is the returned pointer, `escapes to heap` marks
values boxed into `fmt`'s interface arguments or an `any` return,
and `does not escape` is the callee borrowing caller memory, the
verdict every hot function wants. `Sum` appears nowhere in the
output: nothing it touches leaves the frame, and the test asserts
`testing.AllocsPerRun` of 0 on it. A second test re-runs the
compiler with the same flag and asserts the four pinned verdicts
still appear, so the capture cannot rot into fiction as the
toolchain moves.

#flow(
  [where a value lives, decided at compile time],
  node((0, 0), [a value, born in a frame]),
  edge((1.3, 0), (2.5, 0.9), "-|>", label: [address outlives the frame]),
  edge((1.3, 0), (2.5, 0), "-|>", label: [flows to fmt or any]),
  edge((1.3, 0), (2.5, -0.9), "-|>", label: [stays local]),
  node((3.9, 0.9), [heap]),
  node((3.9, 0), [heap, boxed]),
  node((3.9, -0.9), [stack]),
)

#callout("pitfall", "the interface tax is silent", [
  Converting a value to `any` or passing it to a `fmt` verb boxes
  it, and the boxing allocates even when the value itself is two
  integers. The escape lines for `p.x` and `p.y` above are that
  tax, printed. In hot paths pass values, not interfaces.
])

== sync.Pool

When allocation is unavoidable but objects are interchangeable,
`sync.Pool` is the layer the runtime blesses: each P keeps a
private slot and a shared list, `Get` checks the private slot,
then the shared head, then steals from other Ps, then falls back
to `New`. Collection interacts with pools through a two-generation
victim cache: one GC moves pool contents aside where `Get` can
still reach them, the next drops them, so a pool can never pin
memory across two collections.

#listing("go/samples/ch10/pool.go", first: 36, last: 64, caption: [a census: fill, collect once, drain, collect twice, drain])

Measured on this machine, 2026-09-13, with 44 objects over a
20-P machine: after one GC at most `GOMAXPROCS` of them came back
from the constructor, the shared lists served the rest from the
victim cache, and after the second GC every one of the 44 Gets
allocated fresh. The test asserts both bounds, and the bounds are
provable, not sampled: each P parks at most one object in its
private slot, everything else rides shared lists.

#diagram([the pool across two collections], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 3.6), (x0 + 5.2, 6.6), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.6, 4.2), [#l2], size: 6pt)
  }
  stage(0.3, [put], [private slot, then], [shared lists], luma(235))
  cdraw.line((5.7, 5.1), (6.1, 5.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.9, 5.8), [gc 1], size: 6pt)
  stage(6.1, [victim], [still serves Get], [survives one cycle], luma(235))
  cdraw.line((11.5, 5.1), (11.9, 5.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.7, 5.8), [gc 2], size: 6pt)
  stage(11.9, [dropped], [nothing pooled], [the memory is gone], luma(205))
  cdraw.line((17.3, 5.1), (17.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [new], [the constructor], [answers every get], luma(235))
  cdraw.content((11.8, 3.0), [a Get/Put cycle allocates 0, asserted at 1000 rounds], size: 6pt)
  cdraw.content((11.8, 1.9), [a fresh 512-byte buffer allocates exactly 1, the control], size: 6pt)
  cdraw.content((11.8, 0.6), [per-P slots mean no lock on the warm path], size: 6pt)
})

== the particle kernel

The corpus particle kernel is N particles times 8 float64 fields,
a pure arithmetic step with an analytic force, and go holds it two
ways: `[8][]float64`, eight columns, or `[]particle`, rows of one
64-byte struct, which lands on exactly class 6 when it escapes:

#listing("go/samples/ch10/particle.go", first: 33, last: 46, caption: [the row type, and the seeded pcg every book shares])

#listing("go/samples/ch10/particle.go", first: 95, last: 110, caption: [the SoA step: read five columns, write six, allocate nothing])

The same arithmetic in row order is `StepAoS` four lines shorter,
and both step functions assert `AllocsPerRun` of 0 at fixed input,
so representation is a locality question, not an allocation one.
The smoke test runs 10000 particles through both forms from the
same seed and requires bit-identical fields afterward, which holds
because per-particle arithmetic runs in the same order either way.

Measured on this machine, 2026-09-13, go1.27.0, 12th gen i7-12700F,
20 hardware threads, one goroutine, 16 steps over 1m particles
(`go/samples/ch10/bench-1m.txt`, summarized with benchstat):
`[]particle` 136.8 ms per K-step, 8.2 ns per particle per step,
within a 7 percent band, `[8][]float64` 518.3 ms, 30.9 ns, within
12 percent. The row form wins here because the kernel touches all
eight fields of every particle each step, one cache line per
particle in one stream, while the column form walks eight streams
the hardware prefetcher tracks worse. Column layout pays off when
a pass touches a subset of fields, not when every pass touches
everything.

The same day's runs bracket the column number honestly: a first
bench session of the same binary measured 187 ms before sustained
load, and the 100m one-off below measured 8.9 ns per step in a
single pass. Bandwidth-bound loops swing with machine state, so
the pinned numbers are the dated capture's, with the spread
recorded rather than hidden.

The 100m one-off ran alone and sequentially with `GOGC=off`, so
the 6.4 GB working set could not double under the default heap
goal: 5.237 s to allocate and seed eight 800 MiB columns, 14.236 s
for the 16 steps, 8.898 ns per particle per step, 5.96 GiB live,
checksum 25003226.600833, then the memory was released and the
scratch program deleted. One billion particles is 64 GB of columns
and stays arithmetic on this machine, not a measurement.

#diagram([one particle, two layouts, one cache line either way], length: 13pt, {
  cdraw.rect((0.3, 3.4), (11.3, 7.2), fill: luma(240), radius: 0.02)
  cdraw.content((5.8, 6.75), [soa, eight columns], size: 6.5pt)
  for i in range(8) {
    cdraw.rect((0.8 + i * 1.31, 4.4), (1.95 + i * 1.31, 6.3), fill: luma(222), radius: 0.02)
    cdraw.content((1.375 + i * 1.31, 5.35), [#i], size: 6pt)
  }
  cdraw.content((5.8, 3.9), [one step touches all eight columns], size: 6pt)
  pane(12.7, 23.3, 7.2, [aos, rows], [x y z vx vy vz m q], [64 bytes = 1 line], [1m rows = 64 mib])
  cdraw.content((17.9, 2.6), [both assert allocsperrun 0], size: 6pt)
  cdraw.content((17.9, 1.5), [smoke: 10k, bit identical], size: 6pt)
  cdraw.content((17.9, 0.4), [measured 8.2 vs 30.9 ns per step], size: 6pt)
})

sources: go.dev/src runtime and internal/runtime/gc sources on this
machine (`malloc.go`, `malloc_tables_generated.go`, `mheap.go`,
`mcache.go`, `mcentral.go`, `sizeclasses.go`, `sync/pool.go` from
go1.27.0), pkg.go.dev/runtime for MemStats and testing, and
pkg.go.dev/sync for Pool, accessed 2026-09-13. All measured numbers
are from runs on this machine, 2026-09-13, pinned in
`go/samples/ch10/escape-m.txt`, `sizeclasses-go127.txt`, and
`bench-1m.txt`, re-asserted by the 20 tests of `go/samples/ch10`.
