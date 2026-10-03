#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= the heap and the collector

Part one so far treated memory as if it were free. Values came from
literals, arrays grew on demand, and no chapter asked where the bytes
lived or who took them back. This chapter opens that box. The heap
under node 26 is v8's, it is split into spaces with different jobs,
and two collectors move objects between them while the program runs.
Every number below was measured on this machine, 2026-09-13, node
v26.3.0 with V8 14.6.202.34-node.20 on windows, and the workload is
the particle kernel this book shares with the other language books:
eight float64 fields per particle, a pure arithmetic step, sixteen
steps per measurement, one stated prng.

== the heap as v8 reports it

`node:v8` exposes the spaces directly. `getHeapSpaceStatistics`
returns one record per segment of the heap, and the api promises
neither an ordering nor that any named space exists, so the sample
matches by name and the tests only floor the census. On this build
the call reports 15 spaces, among them `read_only_space`,
`new_space`, `old_space`, `code_space`, `trusted_space`, and
`large_object_space` with its per-kind variants:

#listing("javascript/samples/src/ch09-heap.mjs", first: 164, last: 177, caption: [the spaces read from the live process, matched by name])

An idle test process measured `new_space` at 0.5 MB and `old_space`
at 3 MB used. The names carry the collector's division of labor.
`new_space` is the nursery, two semispaces where every object is born
and most die. `old_space` holds survivors and pre-tenured
allocations and is the major collector's territory. `code_space`
keeps jitted machine code, `read_only_space` holds objects frozen at
snapshot time, and anything larger than v8's regular object limit
goes to `large_object_space` instead, never moving.

#diagram([the spaces and the collector that owns each], length: 13pt, {
  cdraw.content((11.6, 9.6), [fifteen spaces on this build, four collectors' worth of territory], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.6), (11.2, 8.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 8.3), [young generation], size: 6pt)
  cdraw.content((5.8, 7.3), [`new_space`, two semispaces], size: 6pt)
  cdraw.content((5.8, 6.3), [the scavenger], size: 6pt)
  cdraw.rect((11.8, 6.6), (22.8, 8.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 8.3), [old generation], size: 6pt)
  cdraw.content((17.3, 7.3), [`old_space`, `code_space`, `trusted_space`], size: 6pt)
  cdraw.content((17.3, 6.3), [mark compact, mark sweep], size: 6pt)
  cdraw.rect((0.4, 3.9), (11.2, 6.1), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.5), [oversized], size: 6pt)
  cdraw.content((5.8, 4.5), [`large_object_space` and variants], size: 6pt)
  cdraw.content((5.8, 3.6), [never moved, swept in place], size: 6pt)
  cdraw.rect((11.8, 3.9), (22.8, 6.1), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 5.5), [immutable], size: 6pt)
  cdraw.content((17.3, 4.5), [`read_only_space`, snapshot born], size: 6pt)
  cdraw.content((17.3, 3.6), [no collector touches it], size: 6pt)
  cdraw.content((11.6, 2.4), [external memory, `ArrayBuffer` backing stores, sits outside every space], size: 6.5pt)
})

== the scavenger: a semispace copy

Objects start in one half of the nursery, `from-space`. When it
fills, the minor collector, the scavenger, copies every reachable
young object into the other half, `to-space`, and the two swap names.
Copying is the whole algorithm: nothing is marked, nothing is
compacted, the dead simply never get copied. The walk is the classic
interleaved scan, evacuate a survivor, bepointer it, follow the next
pointer, with a forwarding address left in the old copy so every
other reference can be updated to the new location. Roots are the
stack and globals plus the old-to-new references the write barrier
recorded, so a scavenge never traces the old generation, and
survivors of a second scavenge are promoted to old space instead of
copied again. V8's write-up of the parallel scavenger, which gives
helper threads and the main thread disjoint pointer sets with atomic
 forwarding pointers, measures 20 to 50 percent less total main
thread young generation time than the sequential one.

A child run on this machine shows the shape in the trace. Each line
is one collection, heap before and after, the pause, and the
trigger:

#snippet(
  "24 ms: Scavenge 6.3 (7.4) -> 6.0 (8.2) MB, pooled: 0.0 MB,\n"
  + "  10.62 / 0.00 ms (average mu = 1.000, current mu = 1.000)\n"
  + "  allocation failure;\n"
  + "25 ms: Scavenge 7.3 (9.4) -> 7.3 (10.7) MB, ... 1.04 ms ...",
  lang: "text",
)

#diagram([the nursery as one copy, from space to to space], length: 13pt, {
  cdraw.content((11.6, 10.6), [copying is the whole algorithm, the dead never copied], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.6, 7.6), (10.4, 9.5), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((5.5, 9.0), [`from-space`, filled], size: 6pt)
  cdraw.rect((1.0, 7.9), (3.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.2, 8.25), [dead], size: 6pt)
  cdraw.rect((3.8, 7.9), (6.6, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 8.25), [live], size: 6pt)
  cdraw.rect((7.0, 7.9), (9.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((8.2, 8.25), [dead], size: 6pt)
  cdraw.line((10.4, 8.25), (12.8, 8.25), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 8.75), [copied], size: 6pt)
  cdraw.rect((12.8, 7.6), (22.6, 9.5), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((17.7, 9.0), [`to-space`, the copy], size: 6pt)
  cdraw.rect((13.2, 7.9), (16.0, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((14.6, 8.25), [the survivor], size: 6pt)
  cdraw.rect((16.4, 7.9), (19.2, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.8, 8.25), [the next one], size: 6pt)
  cdraw.content((11.6, 6.9), [the interleaved scan: evacuate a survivor, bepointer it, follow the next pointer], size: 6pt)
  cdraw.content((11.6, 6.2), [a forwarding address left in the old copy, every other reference updated to the new location, then the two swap names], size: 6pt)
  cdraw.rect((0.4, 4.8), (11.2, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.35), [roots: the stack, the globals, #linebreak() the barrier's old-to-new references], size: 6pt)
  cdraw.rect((11.8, 4.8), (22.8, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 5.35), [a scavenge never traces #linebreak() the old generation], size: 6pt)
  cdraw.rect((0.4, 3.2), (22.8, 4.3), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.75), [survivors of a second scavenge: promoted to old space, not copied again], size: 6pt)
  cdraw.content((11.6, 2.1), [v8's parallel scavenger, their measurement: 20 to 50 percent less main thread young generation time], size: 6.5pt)
  cdraw.content((11.6, 1.1), [sub-millisecond pauses, `allocation failure` the trigger, from the traced child run], size: 6.5pt)
})

Sub-millisecond pauses, heap barely moving, `allocation failure` as
the trigger: that is a nursery doing its job on short-lived objects.
The flags section at the end of this chapter runs the same churn at
three semi space sizes and counts the lines.

== marking, sweeping, and orinoco

Old space needs a collector that can claim garbage without moving
everything: mark and sweep. Marking is a graph walk from the roots
in which every object is white until discovered, grey once queued,
and black once its outgoing edges are all visited; when no grey
objects remain, the whites are garbage. Since 2011 v8 has done that
walk incrementally, interleaved with the program in paced chunks,
which trades a write barrier on every field store for pauses of
milliseconds instead of the several hundred a full stop could cost.
The barrier is Dijkstra style, it greys a white value stored into a
black object, which upholds the strong tri-color invariant: no black
object ever points at a white one, so nothing live can be hidden
from the walk. Since Chrome 64 and node 10 the marking itself is
mostly concurrent, worker threads drain the worklist while
javascript runs, and v8 measured 60 to 70 percent less main thread
marking time from it.

Sweeping returns the dead pages to the allocator, and compaction
evacuates fragmented pages. Orinoco is v8's project to make all of
the old generation work parallel and concurrent: compaction
parallelized at page level, remembered sets processed from per-page
bitmaps instead of store buffers, and black allocation giving
promoted objects dedicated pages that skip sweeping entirely. V8's
own measurements there: compaction 75 percent faster, from about
7 ms to under 2 ms, and the gmail benchmark's worst compacting pause
cut from 42 ms to 23 ms. The explicit `gc()` child run shows the
major collector in the same trace format, with the pause and the
mutation budget's `mu` gauge:

#snippet(
  "37 ms: Mark-Compact 16.5 (21.9) -> 16.0 (21.9) MB, pooled: 0.0 MB,\n"
  + "  4.86 / 0.00 ms (average mu = 0.855, current mu = 0.855)\n"
  + "  testing; GC in old space requested",
  lang: "text",
)

#diagram([the tri-color walk, and the barrier holding it honest], length: 13pt, {
  cdraw.content((11.6, 10.0), [no black object ever points at a white one], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.8, 7.4), (6.4, 8.6), fill: luma(245), radius: 0.02)
  cdraw.content((3.6, 8.0), [white, undiscovered], size: 6pt)
  cdraw.line((6.4, 8.0), (7.6, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.0, 8.45), [found], size: 6pt)
  cdraw.rect((7.6, 7.4), (13.2, 8.6), fill: luma(225), radius: 0.02)
  cdraw.content((10.4, 8.0), [grey, queued], size: 6pt)
  cdraw.line((13.2, 8.0), (14.4, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.8, 8.45), [edges walked], size: 6pt)
  cdraw.rect((14.4, 7.4), (20.0, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.2, 8.0), [black, done], size: 6pt)
  cdraw.content((21.6, 8.15), [no grey left: #linebreak() the whites #linebreak() are garbage], size: 6pt)
  cdraw.content((11.6, 6.6), [a graph walk from the roots, in paced chunks interleaved with the program], size: 6pt)
  cdraw.rect((0.4, 5.2), (22.8, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 5.7), [the Dijkstra barrier: a white value stored into a black object is greyed first, #linebreak() the write barrier on every field store is the price, nothing live hidden from the walk], size: 6pt)
  cdraw.rect((0.4, 3.6), (11.2, 4.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 4.15), [incremental since 2011: pauses of milliseconds, #linebreak() not the several hundred a full stop could cost], size: 6pt)
  cdraw.rect((11.8, 3.6), (22.8, 4.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 4.15), [concurrent since chrome 64 and node 10: #linebreak() worker threads drain the worklist while javascript runs], size: 6pt)
  cdraw.rect((0.4, 2.0), (22.8, 3.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.55), [sweeping returns the dead pages, compaction evacuates the fragmented ones, orinoco: #linebreak() page level parallel compaction, per-page bitmaps, black allocation pages that skip sweeping], size: 6pt)
  cdraw.content((11.6, 0.9), [v8's measurements, quoted as theirs: 60 to 70 percent less main thread marking, #linebreak() compaction 75 percent faster, 7 ms to under 2 ms, the gmail worst pause 42 ms to 23 ms], size: 6.5pt)
})

The pause is still single-digit milliseconds on a 16 MB heap, and
the interleaving is visible in real runs as mark steps of well under
a millisecond between program slices.

== external memory and the large object space

`process.memoryUsage()` separates the javascript heap from the
memory the process owns outside it: `heapUsed` counts the spaces
above, `external` counts c++ allocations, and `arrayBuffers` counts
the subset that is typed array backing stores. Measured on this
machine, allocating a 256 MiB `ArrayBuffer` moved `arrayBuffers` by
exactly 256 MB and `heapUsed` by 0 MB: the bytes never enter any v8
space, which is why the particle kernel below holds a million
particles in 61 MB of `arrayBuffers` while `heapUsed` stays flat. v8
counts that memory toward the heap limit through
`getHeapStatistics().external_memory` anyway, so an out-of-memory in
a typed array program can arrive from the outside accounting.

Oversized objects get their own lane inside the heap. A plain array
of ten million numbers measured `large_object_space` growing from
7.76 MB to 160.36 MB, the elements of one array sitting together on
pages nothing else shares, and large object pages are never
compacted because nothing else can fragment them.

#diagram([where a byte of state lands], length: 13pt, {
  cdraw.content((11.6, 8.6), [two programs, two counters], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.2), (11.2, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 7.3), [objects, arrays, strings], size: 6pt)
  cdraw.content((5.8, 6.3), [`heapUsed` counts them], size: 6pt)
  cdraw.content((5.8, 5.4), [collected, moved, compacted], size: 6pt)
  cdraw.rect((11.8, 5.2), (22.8, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 7.3), [`Float64Array` backing stores], size: 6pt)
  cdraw.content((17.3, 6.3), [`arrayBuffers` counts them], size: 6pt)
  cdraw.content((17.3, 5.4), [freed when the handle dies], size: 6pt)
  cdraw.line((11.6, 5.0), (11.6, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 3.6), [both count toward the heap limit, measured 256 MiB buffer: `heapUsed` +0 MB, `arrayBuffers` +256 MB], size: 6pt)
})

== weak references under a real collector

Chapter 5 pinned the deterministic side of `WeakRef` and
`FinalizationRegistry`, object keys only, no enumeration, collection
itself a runtime decision. With a real collector in hand the
interesting part is the job boundary: `deref` keeps the target alive
for the rest of the job it runs in, so a program that dereferences
while collecting can keep its own target alive. The first draft of
this chapter's child did exactly that and measured `[object
Object]` after two `gc()` calls, the target survived because the
same job had touched it. The corrected child creates the target
inside a function so its frame is gone, and observes from a later
macrotask:

#listing("javascript/samples/src/ch09-gc-child.mjs", caption: [a WeakRef cleared and a finalizer delivered, run under `--expose-gc`])

Run under `node --expose-gc` on this machine the child prints
`finalizer ran: ch09 target` and then `after two gc calls and a
macrotask: deref is undefined`, deterministically across repeated
runs, and the suite spawns that exact child and asserts both lines.
The finalizer callback runs on the collector's schedule, never
inline with the collection, which is why the registry is a cleanup
hook and not a destructor: by the time it fires the object is
already gone and only the held value remains.

#flow(
  [one target, one job boundary],
  node((0, 0), [target created, #linebreak() a popped frame]),
  edge(),
  node((2.4, 0), [only the `WeakRef` #linebreak() holds it]),
  edge(),
  node((4.8, 0), [`gc()` finds it white]),
  edge(),
  node((7.2, 0), [a later macrotask #linebreak() reads undefined]),
)

== the particle kernel: numbers against boxes

The corpus-wide kernel gives every language book the same workload:
N particles times eight float64 fields, `x`, `y`, `z`, `vx`, `vy`,
`vz`, `m`, `q`, one pure arithmetic step per field with an analytic
mass-weighted force, K of 16, and a stated seeded prng so runs are
reproducible. The javascript question is only the representation:
eight `Float64Array` columns, or one object literal per particle.

#listing("javascript/samples/src/ch09-heap.mjs", first: 7, last: 20, caption: [splitmix32, the stated prng, seed 0x12345678])

#listing("javascript/samples/src/ch09-heap.mjs", first: 25, last: 44, caption: [the SoA state, one contiguous column per field])

#listing("javascript/samples/src/ch09-heap.mjs", first: 46, last: 65, caption: [the step, pure arithmetic, no branches, identical operations in both representations])

At one million particles, measured on this machine through the
opt-in `samples/bench/particle.mjs`: the array-of-structs form
initializes in 178.41 ms and costs 216.75 MB of `heapUsed`, one box
per particle on the collector's heap. The struct-of-arrays form
initializes in 21.1 ms and costs 61.04 MB of `arrayBuffers`, eight
contiguous backing stores, with `heapUsed` moving 0.28 MB. Stepping
16 steps: 198.46 ms boxed, 12.4 ns per particle per step, against
75.48 ms flat, 4.72 ns, a 2.63x difference, and 2.63x to 2.82x
across three runs of the same binary. The checksum pass proves the
two representations compute the same eight sums, field by field in
particle order, because the step executes the same operations in the
same order either way.

The scale ladder is honest about its ceiling. One billion particles
is 64 GB of columns, arithmetic only, not measured on this machine.
One hundred million was measured once, alone, with nothing else
running: 6103.65 MB of `arrayBuffers` and an rss of 6159.15 MB, init
2.31 s, 16 steps in 7.42 s, 4.63 ns per particle per step, checksum
pass 379.14 ms, and the memory returned when the process exited.

#diagram([the same state, two shapes of memory], length: 13pt, {
  cdraw.content((5.8, 9.6), [array of structs], size: 6.5pt, fill: luma(100))
  cdraw.content((17.3, 9.6), [struct of arrays], size: 6.5pt, fill: luma(100))
  let boxy(y, x, w, label, dark) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), label, size: 6pt)
  }
  boxy(7.6, 0.4, 1.9, [`x`], false)
  boxy(7.6, 2.4, 1.9, [`y`], true)
  boxy(7.6, 4.4, 1.9, [`z`], false)
  boxy(7.6, 6.4, 1.9, [eight slots], true)
  cdraw.content((5.8, 6.6), [one object per particle], size: 6pt)
  boxy(7.6, 12.2, 2.4, [`x` column], false)
  boxy(6.1, 12.2, 2.4, [`y` column], true)
  boxy(4.6, 12.2, 2.4, [`z` column], false)
  boxy(3.1, 12.2, 2.4, [eight columns], true)
  cdraw.content((17.3, 6.6), [one column per field], size: 6pt)
  cdraw.content((5.8, 2.2), [measured 1m: 216.75 MB `heapUsed`, #linebreak() 12.4 ns per particle per step], size: 6pt)
  cdraw.content((17.3, 2.2), [measured 1m: 61.04 MB `arrayBuffers`, #linebreak() 4.72 ns per particle per step], size: 6pt)
})

== the flags, measured on a child run

Three v8 flags matter for reading this chapter's collectors, and
node passes them through. `--trace-gc` prints one line per
collection. `--expose-gc` installs a `globalThis.gc()` that runs the
major collector on demand, the child above depends on it. And
`--max-semi-space-size` caps the young generation semispace in MiB.
The child run is a churn workload, 400 rounds of 20,000 short-lived
objects, and the count is the scavenge lines in the trace:

#diagram([scavenge count against semi space size, one churn workload], length: 13pt, {
  cdraw.content((11.6, 8.6), [measured on this machine, node 26.3.0], size: 6.5pt, fill: luma(100))
  let bar(x, w, label, count) = {
    cdraw.rect((x, 5.2), (x + w, 6.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + w / 2, 5.9), [#count], size: 6pt)
    cdraw.content((x + w / 2, 4.4), label, size: 6pt)
  }
  bar(1.4, 2.6, [`--max-semi-space-size=1`], [48])
  bar(9.4, 2.6, [default, 16 MiB], [8])
  bar(17.4, 2.6, [=64], [8])
  cdraw.content((11.6, 3.0), [scavenges over the same 8m allocations, wall clock 131.1 ms against 117.0 ms], size: 6pt)
})

A six-times smaller nursery scavenged six times more often, 48
collections against 8, for the same work. The wall clock difference
on this workload is noise, 131.1 ms against 117.0 ms, because each
scavenge costs a fraction of a millisecond, but the shape is the
lever: raise the semispace and short-lived garbage dies in larger,
rarer batches, lower it and the pauses shrink while their count
climbs. The opt-in benches behind this chapter are
`samples/bench/particle.mjs` for the kernel at any N and
`samples/bench/rows.mjs` for the sqlite row kernel of chapter 10,
and neither is ever run by `make verify`.

#callout("note", "what this chapter measured", [
  Every number above came off this machine on 2026-09-13: the space
  census through `node:v8`, the trace lines from real child runs
  spawned by the chapter's own scripts, the footprint deltas from
  `process.memoryUsage`, and the kernel timings from the committed
  bench scripts. The scavenger, marking, and Orinoco internals are
  v8's published account, cited below, with v8's own measurements
  quoted as theirs: 20 to 50 percent less young generation main
  thread time from the parallel scavenger, 60 to 70 percent less
  main thread marking time from concurrent marking, compaction 75
  percent faster under Orinoco. Nothing in between was inferred.
])

sources: nodejs.org v8 module and cli options pages, nodejs.org
process memoryUsage, v8.dev trash talk on the parallel scavenger,
v8.dev orinoco on parallel compaction and black allocation, v8.dev
concurrent marking on incremental marking and the tricolor walk,
accessed 2026-09-13. Behavior verified live with node v26.3.0 on
windows: 125 tests green through `npm run verify` in
`javascript/samples`, 8 of them this chapter's, three consecutive
clean runs, plus the measured child and bench runs quoted above.
