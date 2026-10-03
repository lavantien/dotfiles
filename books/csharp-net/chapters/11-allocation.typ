#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= allocation: the managed heap, pools, and arenas

Chapter 10 described the collector from the language side, spans,
`stackalloc`, and the rules that keep references honest. This chapter
walks the heap itself: how the allocator is organized, where big
objects land, what pinning costs and how .NET 5 gave it a home, how
the write barrier is observable without a debugger, and then the two
reuse disciplines the base class library ships, `ArrayPool` and
`MemoryPool`, plus the arena pattern you build yourself when a run of
work should allocate once and reset. The chapter closes on the
particle kernel the whole corpus measures: one workload in four
representations, checksums asserted equal in the suite, nanoseconds
per particle per step measured on this machine.

== the managed heap

The heap is one virtual address space the collector carves into
segments, reserved from the OS and committed as needed. Logically it
is three generations plus two special heaps. Allocation is a bump of
a generation 0 pointer, which is why small allocation is cheap: no
free list, no coalescing, just a pointer and a bounds check. Each
generation carries a *budget*, and when an allocation would exceed
it, that generation is collected. Budgets are tuned by the runtime as
the program runs, which is why the same code can collect at different
times across runs. The suite watches the two probes that anchor the
rest of the chapter:

#listing("csharp-net/samples/src/Ch11/Heap.cs", first: 10, last: 34, caption: [threshold constants and the two generation probes])

#diagram([the managed heap: three generations with budgets, two special heaps beside them], length: 13pt, {
  // the ephemeral generations stacked at left, the two special heaps at right
  cdraw.rect((0.2, 4.4), (9.0, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((4.6, 5.4), [generation 0, #linebreak() bump pointer, a budget], size: 6pt)
  cdraw.line((4.6, 4.4), (4.6, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 4.05), [survivors promote], size: 6.5pt)
  cdraw.rect((0.2, 2.4), (9.0, 4.3), fill: luma(225), radius: 0.02)
  cdraw.content((4.6, 3.35), [generation 1, the buffer], size: 6pt)
  cdraw.line((4.6, 2.4), (4.6, 1.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 2.05), [survivors promote again], size: 6.5pt)
  cdraw.rect((0.2, 0.4), (9.0, 2.3), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 1.35), [generation 2, full collections], size: 6pt)
  cdraw.rect((10.6, 2.9), (19.0, 6.4), fill: luma(230), radius: 0.02)
  cdraw.content((14.8, 4.9), [large object heap, #linebreak() 85,000 bytes and up, #linebreak() swept, not compacted], size: 6pt)
  cdraw.rect((10.6, 0.4), (19.0, 2.7), fill: luma(240), radius: 0.02)
  cdraw.content((14.8, 1.55), [pinned object heap, #linebreak() allocated pinned, never moves], size: 6pt)
  cdraw.content((4.6, -0.9), [one segment reservation, five logical homes], size: 6.5pt)
})

Only two of those homes accept user allocations: generation 0 for
small objects, the large object heap for big ones. Generation 1 and 2
are filled by the collector promoting survivors, and the pinned
object heap is reached only through the pinned allocation APIs later
in this chapter.

== the large object heap

The documented default threshold is 85,000 bytes, configurable
through `System.GC.LOHThreshold` and `DOTNET_GCLOHThreshold`, and the
number came from performance tuning, not from an address boundary. An
object at or above the threshold allocates directly on the LOH, is
collected with generation 2, and is swept rather than compacted,
because copying megabytes to close a gap costs more than the gap. The
boundary is measurable from safe code, and it lands at exactly 85,000
object bytes: a `double` array crosses at 10,622 elements, 24 bytes of
array header plus 8 bytes per element, measured on this machine under
the pinned SDK:

#listing("csharp-net/samples/src/Ch11/Heap.cs", first: 35, last: 45, caption: [walking the boundary: the first length that reports generation 2])

#diagram([the threshold, measured: 24 header bytes plus 8 per element crosses at 10,622], length: 13pt, {
  // the size axis with the 85000 threshold, two arrays bracketed below
  cdraw.line((1.0, 4.6), (21.0, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 4.2), (14.4, 5.0), stroke: luma(100))
  cdraw.content((14.4, 5.5), [85,000 object bytes], size: 6pt)
  cdraw.rect((1.4, 2.4), (13.9, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.6, 3.0), [`new double[10_621]`, #linebreak() 84,992 bytes, generation 0], size: 6pt)
  cdraw.rect((14.9, 2.4), (20.6, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.7, 3.0), [`new double[10_622]`, #linebreak() 85,000 bytes, the loh], size: 6pt)
  cdraw.content((10.8, 1.0), [the header is 24 bytes on this runtime, measured by the same walk], size: 6.5pt)
  cdraw.content((10.8, -0.2), [loh objects report generation 2 out of the allocation], size: 6.5pt)
})

The LOH's failure mode is fragmentation: swept free space becomes a
free list, long-lived and short-lived large objects interleave, and
the gaps cannot close without a compaction. When one is genuinely
needed, `GCSettings.LargeObjectHeapCompactionMode = CompactOnce`
followed by `GC.Collect()` compacts it once, on demand, as an
explicit decision rather than a policy. The cheaper cure is not to
allocate large temporary arrays at all, which is the pool's job below.

== the pinned object heap

`fixed` pins an object wherever it lives, and every pinned object
blocks compaction around it. .NET 5 added the honest alternative:
allocate the object where it never moves in the first place.
`GC.AllocateArray(length, pinned: true)` and the uninitialized
variant put the array on the pinned object heap, a heap with no
compaction ever, so the address you take stays valid without pinning
anything. The restriction is the same as for `fixed` buffers: the
element type must not contain references, because a never-moving heap
cannot have its references rewritten. The suite watches the heap grow:

#listing("csharp-net/samples/src/Ch11/Heap.cs", first: 47, last: 72, caption: [pinned allocation grows the pinned object heap, measured across a collection])

#diagram([three heaps, three movement policies], length: 13pt, {
  // the policy per heap, compaction and sweep and never move
  let rows = (
    ([gen 0, 1, 2], [compacted: survivors move]),
    ([large object heap], [swept: free list, no moves]),
    ([pinned object heap], [never moves, allocated that way]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.0 - i * 1.5
    cdraw.rect((0.2, y - 0.55), (7.6, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((3.9, y), row.at(0), size: 6pt)
    cdraw.line((7.6, y), (8.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((15.6, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((10.8, -0.4), [`fixed` freezes an object in place, the poh allocates it there], size: 6.5pt)
})

The `GenerationInfo` array the listing reads has five entries on this
runtime, gen 0, gen 1, gen 2, LOH, POH, measured, and the pinned heap
is the fifth. Pinned arrays still report generation 2 through
`GC.GetGeneration`, both special heaps are collected with generation
2, the difference is only whether their objects can move.

== write barriers

A generational collector needs to find references from old objects
into young ones without scanning the whole old heap. The write
barrier is the trick: every store of a reference into an object older
than generation 0 marks a card, a coarse region of the old heap, so a
generation 0 collection only walks the dirty cards. You cannot call
the barrier, but you can watch it work: store a million young
references into a generation 2 array and they all survive the next
full collection, found through the cards the stores dirtied:

#listing("csharp-net/samples/src/Ch11/Heap.cs", first: 74, last: 92, caption: [young references stored into an old array survive through the dirty cards])

#diagram([the card table: a store into an old object dirties the card that names it], length: 13pt, {
  // young objects at left, a store arrow into the old array, the card row below
  cdraw.rect((0.2, 3.4), (4.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.4, 4.5), [a fresh object, #linebreak() generation 0], size: 6pt)
  cdraw.line((4.6, 4.5), (8.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.4, 5.0), [`old[i] = obj`, #linebreak() the barrier fires], size: 6pt)
  cdraw.rect((8.6, 3.4), (18.4, 5.6), fill: luma(230), radius: 0.02)
  cdraw.content((13.5, 5.05), [a generation 2 array], size: 6pt)
  for i in range(6) {
    let f = if i == 2 { luma(180) } else { luma(215) }
    cdraw.rect((9.6 + i * 1.4, 3.7), (10.8 + i * 1.4, 4.6), fill: f, radius: 0.02)
  }
  cdraw.content((13.5, 2.7), [the slot], size: 6pt)
  for i in range(6) {
    let f = if i == 2 { luma(180) } else { luma(235) }
    cdraw.rect((9.6 + i * 1.4, 0.6), (10.8 + i * 1.4, 1.5), fill: f, radius: 0.02)
  }
  cdraw.line((10.2, 3.7), (10.2, 1.5), stroke: luma(100), mark: (end: ">"), bend: 20deg)
  cdraw.content((13.5, 1.05), [a dirty card], size: 6pt)
  cdraw.content((6.2, -0.6), [gen 0 collection walks dirty cards only, not the old heap], size: 6.5pt)
})

The barrier has a cost the chapter measures rather than asserts:
storing a million young references into the old array ran 2 generation
0 collections where dropping them ran 1, measured on this machine,
2026-09-13, because every survivor keeps a little more of generation
0 alive per pass. The barrier is also why `fixed` and the POH matter
to throughput: pinned objects dirty no cards, but they block the
compaction that keeps generation 0's survivors dense.

== arraypool, deep

Chapter 15 sketched the pool as a line in the collections tour. The
deep version is the contract: one shared pool per process, buckets by
power of two from 16 up, `Rent` returns at least the requested length
and may return more, `Return` is voluntary and returns the array to
the bucket, and nothing is zeroed. The rounding is the first trap:
the caller must carry its own length, because `Rent(1000)` hands back
a 1024-slot array:

#listing("csharp-net/samples/src/Ch11/Pools.cs", first: 13, last: 47, caption: [bucket rounding, the rent-return-rent cycle, and the surviving bytes])

#diagram([the bucket ladder: rent rounds up, return is voluntary, nothing clears], length: 13pt, {
  // the ladder of powers of two at left, a rent and return cycle at right
  let buckets = ([16], [128], [1,024], [131,072])
  for (i, b) in buckets.enumerate() {
    let y = 5.6 - i * 1.15
    cdraw.rect((0.2, y - 0.45), (4.0, y + 0.45), fill: luma(230), radius: 0.02)
    cdraw.content((2.1, y), b, size: 6pt)
    cdraw.content((5.4, y), [a bucket of arrays], size: 6.5pt)
  }
  cdraw.content((2.1, 0.3), [powers of two], size: 6.5pt)
  cdraw.rect((12.0, 4.0), (16.2, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((14.1, 4.6), [`Rent(1000)`], size: 6pt)
  cdraw.line((14.1, 4.0), (14.1, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.6, 3.6), [1,024 slots], size: 6pt)
  cdraw.rect((12.0, 2.0), (16.2, 3.2), fill: luma(235), radius: 0.02)
  cdraw.content((14.1, 2.6), [your 1,000, #linebreak() plus 24 you never touch], size: 6pt)
  cdraw.line((14.1, 2.0), (14.1, 1.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.7, 1.6), [`Return`], size: 6pt)
  cdraw.rect((12.0, 0.2), (16.2, 1.2), fill: luma(205), radius: 0.02)
  cdraw.content((14.1, 0.7), [back to the bucket, bytes intact], size: 6pt)
  cdraw.content((20.0, 3.0), [the next renter #linebreak() sees your bytes], size: 6.5pt)
})

The second trap is ownership. `Return` is a give-up: the same instance
can be handed to the next renter on the same thread immediately, the
suite asserts the reference equality and the surviving 42, and a
returned-then-used buffer is a use-after-free the compiler cannot see.
The rule the platform docs state and the samples follow: keep `Rent`
and `Return` in one method, return in `finally` only when no escape
path can still hold the array, and pay `clearArray: true` when the
next renter must not read what you left.

== memorypool and imemoryowner

`ArrayPool` rents raw arrays, which is wrong the moment the buffer
must cross an async boundary or live in a class, because the
responsibility to return it has no type. `MemoryPool<T>` is the
owning form: `Rent` returns an `IMemoryOwner<T>`, the handle whose
`Dispose` returns the buffer, and the `Memory<T>` it hands out is
valid exactly as long as the owner is alive. It rounds to powers of
two like the array pool, measured, `Rent(1000)` yields a `Memory` of
length 1024:

#listing("csharp-net/samples/src/Ch11/Pools.cs", first: 63, last: 85, caption: [the owner handle: rent, use through the memory, dispose returns])

#diagram([ownership as a type: the owner outlives the memory it hands out], length: 13pt, {
  // the owner at left, the memory and span derived at right, dispose below
  cdraw.rect((0.2, 3.4), (8.0, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((4.1, 4.5), [`IMemoryOwner<double>`, #linebreak() the handle, `using` it returns], size: 6pt)
  cdraw.line((8.0, 4.9), (12.4, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 5.5), [`.Memory`], size: 6pt)
  cdraw.rect((12.6, 4.2), (20.4, 5.8), fill: luma(230), radius: 0.02)
  cdraw.content((16.5, 5.0), [`Memory<double>`, #linebreak() crosses await, lives with the owner], size: 6pt)
  cdraw.line((8.0, 3.9), (12.4, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 3.0), [`.Span`], size: 6pt)
  cdraw.rect((12.6, 2.6), (20.4, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.5, 3.3), [`Span<double>`, #linebreak() synchronous work only], size: 6pt)
  cdraw.content((10.2, 1.2), [dispose the owner and both views die with it], size: 6.5pt)
})

The pool boundary is a design decision, not a performance one. A
`Memory<T>` handed to an async consumer outliving its owner is the
same use-after-free with better syntax, which is why the owner is the
thing you pass, never the bare `Memory`.

== arenas as a pattern

A pool amortizes individual buffers. An arena changes the shape
entirely: one slab rented up front, allocations are bumps of a cursor,
nothing is garbage during the run because everything is reachable from
the arena, and the run ends with one `Reset` that rewinds the cursor
instead of freeing anything. Per-frame work, per-request parsing, any
phase whose allocations die together at a known point, fits an arena.
The sample arena is 60 lines over rented slabs:

#listing("csharp-net/samples/src/Ch11/Arena.cs", first: 33, last: 73, caption: [bump allocation with a rewind: rent, exhaust, reset])

#diagram([the arena slab: bump, spill, rewind, return], length: 13pt, {
  // one slab with a cursor, the spilled second slab, the reset arrow back
  cdraw.rect((0.2, 3.0), (18.4, 5.2), fill: luma(230), radius: 0.02)
  cdraw.content((3.0, 5.7), [slab 0, rented once], size: 6pt)
  cdraw.rect((0.9, 3.4), (7.2, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 4.1), [handed out], size: 6pt)
  cdraw.line((7.2, 3.0), (7.2, 6.1), stroke: luma(100))
  cdraw.content((8.4, 4.6), [the cursor], size: 6pt)
  cdraw.content((12.9, 4.1), [free until the slab fills], size: 6.5pt)
  cdraw.line((18.4, 4.1), (19.9, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((21.3, 4.1), [spill: slab 1], size: 6pt)
  cdraw.line((7.2, 6.4), (2.0, 6.4), stroke: luma(100), mark: (end: ">"), bend: 25deg)
  cdraw.content((4.6, 7.0), [`Reset`, rewind, keep the slab], size: 6pt)
  cdraw.content((9.4, 1.6), [`Dispose` returns the slabs to the pool, reset never does], size: 6.5pt)
  cdraw.content((9.4, 0.2), [a span from the arena dies at reset: the caller owns the rule], size: 6.5pt)
})

Two contracts make it honest. A rental bigger than a slab is refused,
the caller sizes the slab to the run, and `Reset` rewinds without
clearing, so a span from the previous pass aliases a span from the
next one, which the suite asserts on purpose: 5 written before the
reset is 5 read after it. That aliasing is the arena's power and its
whole hazard, and it is why arenas live behind a phase boundary, not
in general-purpose APIs.

== the particle kernel

The corpus-wide workload: N particles, eight float64 fields each
(x, y, z, vx, vy, vz, m, q), sixteen steps of pure arithmetic under a
constant analytic field, one stated seed for the PRNG so every
representation fills identically. Four representations of the same
state: owned `double[8][]` structure-of-arrays, `Particle[]`
array-of-structs, pool rentals sliced to N, and arena slices off one
slab. The step runs over spans, so the same code serves the last
three:

#listing("csharp-net/samples/src/Ch11/Particles.cs", first: 85, last: 106, caption: [the span step: pos += vel times dt plus half a dt squared, vel += a dt])

The suite asserts the four representations agree bitwise, and the
agreement is not free: the fold and the update had to associate
identically, one `+=` per field in checksum order and the update
parenthesized to match the span statement, or the last bits drift.
The bench, opt-in under `samples/bench/`, measured the step loop
only, warm, median of five reps after a warmup rep, 1,000,000
particles, .NET 11.0.0, this machine, 2026-09-13:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*representation*], [*ns per particle per step*], [*setup ms*], [*allocated per rep*]),
  [`double[8][]` soa], [13.1], [30], [64.0 MB],
  [`Particle[]` aos], [5.7], [39], [128.0 MB],
  [pooled soa], [6.4], [20], [432 B warm],
  [arena soa], [3.9], [27], [488 B warm],
)

The folklore answer, SoA always wins, is not what this loop measures.
The step touches all eight fields of every particle, so the AoS walk
reads one 64-byte cache line per particle, perfectly sequential, while
the SoA loop touches eight separate streams a stride apart, eight
lines in flight for the same particle, and loses despite zero
per-element bookkeeping. SoA pays off when work is field-wise or
vectorizable across a lane, which is exactly the split to test before
choosing, not assume. The arena's edge over the pooled variant, 3.9
against 6.4 ns, is the same locality story one level up: eight slices
of one contiguous slab against eight separately allocated segments.
The allocation column is the chapter's thesis in one number: the
owned arrays pay 64 to 128 MB of garbage per run at this scale, the
pooled and arena variants pay a few hundred bytes warm, and the
checksum, 6995752.357206226, is identical in every representation and
every rep.

The scale ladder above 1m is a one-off and arithmetic. 100 million
particles, SoA only, run alone and sequentially on this machine,
2026-09-13: fill 4,372 ms, the 16 steps 34,903 ms, which is 21.815 ns
per particle per step against 13.1 at 1m, the step loop is memory
bandwidth bound once the eight arrays are 800 MB each, and the
managed heap held 6,400,250,392 bytes with two collections in each
generation across the whole run, the arrays are all large objects,
the ephemeral machinery barely engages. One billion is arithmetic,
not a measurement on this machine: 64 GB of SoA state, ten times this
run, past this machine's 32 GB.

#diagram([four representations, one loop: lines in flight per particle], length: 13pt, {
  // aos: one line, one particle. soa: eight streams, one line each
  cdraw.content((4.6, 6.4), [aos, one cache line per particle], size: 6.5pt)
  cdraw.rect((0.2, 4.2), (9.0, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((4.6, 5.0), [`x y z vx vy vz m q`, #linebreak() 64 bytes, sequential], size: 6pt)
  cdraw.line((4.6, 4.2), (4.6, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.6, 2.9), [next particle, next line], size: 6pt)
  cdraw.content((15.2, 6.4), [soa, eight streams], size: 6.5pt)
  for i in range(8) {
    let y = 5.6 - i * 0.42
    cdraw.rect((10.4, y - 0.16), (20.0, y + 0.16), fill: luma(230), radius: 0.02)
    cdraw.content((11.0, y), [`x`], size: 4.5pt)
    cdraw.content((19.6, y), [`q`], size: 4.5pt)
  }
  cdraw.line((15.2, 2.05), (15.2, 1.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.2, 0.6), [one i touches all eight streams, eight lines in flight], size: 6.5pt)
})

sources: learn.microsoft.com, fundamentals of garbage collection, the
large object heap on windows systems, runtime configuration options
for garbage collection, gc.allocatearray and gc.allocateuninitializedarray,
arraypool, arraypool shared rent and return, and memorypool pages,
accessed 2026-09-13. Heap, pool, and arena behavior verified by `make
verify-csharp`, 20 tests. The 1m particle measurements above are from
`samples/bench/` on this machine, 2026-09-13, .NET 11.0.0 under SDK
11.0.100-rc.1.
