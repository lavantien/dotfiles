#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= pymalloc: arenas, freelists, and tracemalloc

Every object this book has built so far, from the tuples of chapter 3 to
the arrays of #xref-to("python", "numpy"), came out of the same private
heap, and this chapter opens it. The C API manual states the design in
one sentence: "Python has a *pymalloc* allocator optimized for small
objects (smaller or equal to 512 bytes) with a short lifetime", and "It
falls back to `PyMem_RawMalloc()` and `PyMem_RawRealloc()` for
allocations larger than 512 bytes." The plan of the chapter is to hold
that sentence against the binary: the allocator prints its own census
under `PYTHONMALLOCSTATS`, `id()` reveals the size classes, and
`tracemalloc` attributes what survives. Everything below is either
quoted from the 3.14 manual, fetched 2026-09-13, or measured on this
machine under the gate interpreter, cpython 3.14.7, the same day. The
chapter owns 39 ok lines across six samples, and the particle kernel it
closes with is the same kernel #xref-to("python", "profiling") measures
at full scale.

== why a private heap

The default C heap is a general servant: it serves every allocation of
every size with the same bookkeeping, and it cannot know that this
program allocates and frees millions of 24-byte floats. The manual
assigns the layers plainly: pymalloc "is the default allocator of the
`PYMEM_DOMAIN_MEM` (ex: `PyMem_Malloc()`) and `PYMEM_DOMAIN_OBJ` (ex:
`PyObject_Malloc()`) domains", while the raw domain keeps the system
allocators, `malloc()` and `free()`, in every configuration. Object
headers, interned strings, frames, and code objects all come through
the OBJ domain, so the small-object path is the hot path of the whole
interpreter, which is why it gets a private geometry instead of a
general one.

#listing("python/samples/src/Ch13/arenas.py", first: 8, last: 24, caption: [the interpreter pin, then the census probe: the env var must exist before interpreter start, so a child carries it])

The two tools of this chapter meet in that listing. The environment
variable `PYTHONMALLOCSTATS` makes the allocator print its statistics
"every time a new pymalloc object arena is created, and on shutdown",
and because environment variables are read before Python code runs, a
child interpreter has to carry it. `id()` is the other tool: it returns
"the identity of an object", and in CPython that identity is the
object's address, so the distance between two live objects is the
distance between their blocks.

#diagram([the allocator stack: objects ride the mem and obj domains into pymalloc, raw memory and everything above 512 bytes ride the c heap], length: 13pt, {
  let layer(y, t, sub, fill: luma(235)) = {
    cdraw.rect((3.0, y), (19.0, y + 1.3), fill: fill, radius: 0.02)
    cdraw.content((11.0, y + 0.92), t, wrap: text.with(size: 6pt))
    cdraw.content((11.0, y + 0.36), sub, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  layer(7.6, [python objects], [tuples, floats, frames, code objects, dicts])
  layer(5.9, [pymalloc, the mem and obj domains], [arenas, pools, size classes, 512 bytes and below], fill: luma(220))
  layer(4.2, [the raw domain and the 512+ fallback], [PyMem\_RawMalloc, the system heap], fill: luma(245))
  layer(2.5, [the c heap], [VirtualAlloc for arenas, malloc for the rest])
  cdraw.line((11.0, 7.6), (11.0, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 5.9), (11.0, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 4.2), (11.0, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 1.3), [the small path is the interpreter's hot path: millions of 24-byte floats a day], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== arenas, pools, and blocks

The manual fixes the arena size for this platform: "It uses memory
mappings called 'arenas' with a fixed size of either 256 KiB on 32-bit
platforms or 1 MiB on 64-bit platforms", and on Windows those mappings
come from "VirtualAlloc() and VirtualFree()". This is a 64-bit build,
so arenas here are 1 MiB, and the binary says so itself in its census,
committed as the dated capture behind this page:

#listing("python/samples/bench/captures/2026-09-13-mallocstats.txt", first: 1, last: 10, caption: [the allocator's own banner and the head of its class table, captured 2026-09-13 under `PYTHONMALLOCSTATS=1`])

#listing("python/samples/bench/captures/2026-09-13-mallocstats.txt", first: 37, last: 50, caption: [the tail of the class table and the arena totals: 1048576 bytes an arena, 16384 a pool, 8,848 lost to quantization])

The census carries three numbers this chapter pins: 1048576 bytes per
arena, 16384 bytes per pool, and the class table running 16 to 512 in
16-byte steps. The arithmetic those imply is asserted in the sample: 64
pools per arena, and after the pool's own 48-byte header, 510 blocks of
the 32-byte class or 1021 of the 16-byte class. The quantization line
is the tail of the pools: a 32-class pool spends its 16,384 bytes as 48
of header plus 510 blocks at 32, and the 16 left over cannot form one
more block. Summed over every pool in the census those tails come to
exactly 8,848, the arena total 2,097,152 minus 1,808,192 in allocated
blocks, 273,968 in available ones, and 6,144 of pool headers. The
allocator never records a request size, so the census cannot report
body-versus-block rounding at all: a 24-byte float in a 32-byte block
pays its 8 lost bytes inside the allocated column, 160,000 of them for
20000 floats.

The `id()` measurements agree with the census to the byte. Two thousand
held floats sit on a 32-byte stride, every one of them at an address
that is 16 modulo 32, which is the pool header plus the class stride.
Sixty thousand held floats, 1.44 MB of payload in 1.92 MB of blocks,
hit all 510 distinct slot offsets a 32-class pool owns and span at least
two arenas, four to five in the runs behind this page, because an arena
holds 32640 floats of this class and the rest spills into the next
mapping.

#listing("python/samples/src/Ch13/arenas.py", first: 60, last: 76, caption: [the census arithmetic and the stride check: 64 pools, 510 blocks, every id 16 mod 32])

#diagram([one arena of 64 pools: each pool owns one class, the header costs 48 bytes, and blocks of the 32 class fill the rest at a fixed stride], length: 13pt, {
  cdraw.rect((0.8, 5.2), (21.4, 9.4), fill: luma(245), radius: 0.02)
  cdraw.content((11.1, 9.0), [one arena, 1,048,576 bytes, 64 pools], wrap: text.with(size: 6.5pt))
  for i in range(12) {
    let x = 1.2 + i * 1.7
    cdraw.rect((x, 5.6), (x + 1.5, 8.4), fill: luma(225), radius: 0.02)
    cdraw.content((x + 0.75, 6.0), [pool], wrap: text.with(size: 6pt))
  }
  cdraw.content((11.1, 5.35), [each pool 16,384 bytes], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.rect((2.0, 1.0), (20.2, 4.4), fill: luma(235), radius: 0.02)
  cdraw.rect((2.0, 1.0), (4.0, 4.4), fill: luma(205), radius: 0.0)
  cdraw.content((3.0, 2.7), [48 B #linebreak() header], wrap: text.with(size: 6pt))
  let x = 4.0
  for k in range(10) {
    cdraw.rect((x + k * 1.6, 1.6), (x + k * 1.6 + 1.5, 3.8), fill: luma(250), radius: 0.0)
    cdraw.content((x + k * 1.6 + 0.75, 2.7), [32], wrap: text.with(size: 6pt))
  }
  cdraw.content((11.1, 0.5), [a 32-class pool: 510 blocks, first block at offset 48, stride 32, every address 16 mod 32], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.line((11.1, 5.6), (11.1, 4.4), stroke: luma(100), mark: (end: ">"))
})

== freelists and the 512-byte boundary

A freed small object does not return its memory to the operating system
or even to the arena. Its block goes back to its pool, and the next
allocation of the same size class takes the cheapest block on the free
list. The sample holds that to five trials per shape: a freed 4-tuple
returns as the next 4-tuple, a freed float as the next float, a freed
short list as the next short list, five for five each, and the extreme
form is the one-line classic, `id([]) == id([])`, true here because the
dropped empty list is the next free 64-class block when the second
empty list asks for one.

#listing("python/samples/src/Ch13/freelists.py", first: 11, last: 22, caption: [the reuse probe: free one object, immediately build a same-shape replacement, five trials])

The boundary the manual draws is 512 bytes, and the dispatch is a size
class lookup, not a search: requests of 16 through 512 bytes in
16-byte steps, 32 classes, round up to their class and take a block
from that class's pool. Above 512 nothing rounds up at all, the
request goes to `PyMem_RawMalloc`, and the census confirms the edge:
its table stops at 512 and a 513-byte request would buy a raw block
sized to the byte. The small-int cache rides the same cheap-reuse
logic and stops at a fixed line: `int("256") is int("256")` holds,
`int("257") is int("257")` does not, the boundary chapter 3 taught as
the cached range minus 5 through 256.

#diagram([the dispatch: a request rounds up to its class through 512, above it the raw heap takes the request unsized], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.6), t, wrap: text.with(size: 6pt))
  }
  box(7.6, 8.2, 6.8, [a request for n bytes])
  box(0.8, 5.9, 10.4, [n rounds up to 16, 32, ... 512], fill: luma(220))
  box(12.4, 5.9, 7.8, [n is 513 or more], fill: luma(245))
  box(0.8, 3.6, 10.4, [the class's pool, one block off the free list])
  box(12.4, 3.6, 7.8, [PyMem\_RawMalloc, the c heap])
  cdraw.line((9.5, 8.2), (6.0, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.5, 8.2), (16.3, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 5.9), (6.0, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.3, 5.9), (16.3, 4.8), stroke: luma(100), mark: (end: ">"))
  box(0.8, 1.3, 10.4, [freed blocks return to the same free list])
  cdraw.line((6.0, 3.6), (6.0, 2.5), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((11.1, 0.45), [32 classes, the census table is the whole dispatch, no search anywhere], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== what getsizeof measures

`sys.getsizeof` answers a narrow question: the storage of the object
itself, header included, the objects it points to excluded. That makes
it a ladder reader. The builtin containers grow in jumps rather than
per element, and the jumps are the allocator's neighbors showing
through: a list owns 56 bytes empty and grows by whole over-allocated
segments, 72, 88, 120, 184, 312, 568, 1080, 2104 as it passes 1, 2, 4,
8, 16, 32, 64, 128, 256 elements, a dict jumps 64, 224, 352, 632,
1168, 2264, 4688 on the same ladder, and a set starts expensive, 216
bytes empty, because its table exists before its first member:

#listing("python/samples/src/Ch13/getsizeof.py", first: 9, last: 18, caption: [the ladder reader: one builder, one size list, pinned per container])

#listing("python/samples/src/Ch13/getsizeof.py", first: 20, last: 32, caption: [the pinned ladders: list, dict, set, tuple, each jump asserted exactly])

The scalars carry their own arithmetic: an empty string is 41 bytes and
each ASCII character adds exactly one, an int is 28 bytes at one digit
and 36 at `2**60` because the digits live in a 30-bit limb array, and
an empty bytes is 33. The numpy contrast is the point of the ladder:
an `(8, 10000)` float64 array reports 640128 bytes, its 640000-byte
buffer plus a 128-byte ndarray header, 64 bytes per particle, while
the tuple representation of the same particles costs 112 bytes for the
8-slot tuple plus 8 objects of 24 bytes, 304 bytes a particle before
the list slot that points at it, 4.75 times the buffer and 4.875 with
the slot counted.

#diagram([the ladders side by side: tuple grows exactly, list over-allocates ahead of need, dict and set jump when their tables double], length: 13pt, {
  let col(x, label, vals, fill) = {
    cdraw.content((x, 9.2), label, wrap: text.with(size: 6pt))
    for (k, v) in vals.enumerate() {
      let h = v / 2104 * 6.4
      cdraw.rect((x - 0.55 + k * 1.05, 9.0 - h), (x + 0.1 + k * 1.05, 9.0), fill: fill, radius: 0.0)
    }
  }
  col(2.2, [tuple], (48, 56, 64, 80, 112, 176, 304, 560, 1072), luma(170))
  col(8.0, [list], (56, 72, 72, 88, 120, 184, 312, 568, 1080, 2104), luma(150))
  col(13.8, [dict], (64, 224, 224, 352, 632, 1168, 2264, 4688), luma(190))
  col(19.6, [set], (216, 216, 216, 728, 728, 2264, 2264, 8408), luma(210))
  cdraw.line((1.0, 9.0), (21.4, 9.0), stroke: 0.5pt + luma(180))
  cdraw.content((11.1, 0.4), [x axis: elements 0, 1, 2, 4, 8, 16, 32, 64, 128, 256, heights to scale against 8408], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== tracemalloc attribution

`getsizeof` reads one object at a time. "The tracemalloc module is a
debug tool to trace memory blocks allocated by Python", and its
snapshots answer the aggregate questions: where allocations were born
and what survived. The manual defines the knobs exactly, tracing
"collected tracebacks of traces will be limited to *nframe* frames",
one frame by default, and warns that "Storing more frames increases
the memory and CPU overhead". The statistics call groups by `key_type`,
and for the lineno grouping "The result is sorted from the biggest to
the smallest by: `Statistic.size`, `Statistic.count` and then by
`Statistic.traceback`", so index zero is the top line by bytes, not a
matter of luck.

#listing("python/samples/src/Ch13/tracemalloc_demo.py", first: 9, last: 15, caption: [the workload: one dict per row, one list per row, two distinct allocation sites])

#listing("python/samples/src/Ch13/tracemalloc_demo.py", first: 24, last: 45, caption: [snapshot, top stat, current and peak: the vals line owns the ledger and the pins hold it])

On the 2000-row workload the attribution is lopsided and pinned: the
list-build line owns 750768 bytes across 15980 blocks, and the traced
current after the build is 807355 bytes, both exact run over run,
while the peak sits a few hundred bytes above 807000 and drifts a few
dozen bytes between runs, because a high-water mark records whatever
transient was alive at the crest. The manual's companion call,
`reset_peak()`, exists for exactly that shape: it "resets the peak
size of memory blocks traced by the tracemalloc module" so a second
phase reports its own crest instead of inheriting the first. At
kernel scale the same tool reads the in-place claim directly: traced
current lands at 64777603 bytes after building the 1m-particle
buffer, and after 16 steps of the chapter kernel it sits at 80777795
with a peak of 80778259, the two 8 MB scratch rows accounting for the
difference to the byte and nothing else growing.

#diagram([the attribution ledger: two allocation sites, one owns the bytes, and the peak marks the crest of the transients], length: 13pt, {
  let bar(x, label, val, maxv, fill) = {
    let w = val / maxv * 15.6
    cdraw.rect((x + 3.4, 6.4 - 0), (x + 3.4 + w, 7.6), fill: fill, radius: 0.0)
    cdraw.content((x + 3.3, 7.0), label, wrap: text.with(size: 6pt), anchor: "east")
  }
  bar(0.0, [the vals lists], 750768, 810000, luma(160))
  bar(0.0, [the dict rows], 50000, 810000, luma(200))
  bar(0.0, [everything else], 6715, 810000, luma(220))
  cdraw.line((3.4, 5.6), (3.4, 8.2), stroke: 0.5pt + luma(180))
  cdraw.line((3.4, 8.0), (21.0, 8.0), stroke: 0.5pt + luma(180))
  cdraw.content((12.0, 8.4), [traced current 807355, pinned], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.line((3.4, 4.6), (21.0, 4.6), stroke: luma(140), dash: "dashed")
  cdraw.content((12.0, 4.2), [the peak, a few hundred bytes above current, drifts a little run to run], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 1.9), [one frame by default: the traceback names the line that allocated, not the call path], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.5, 0.9), [reset\_peak() gives a second phase its own crest instead of the first phase's], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== pythonmalloc and the mimalloc option

The allocator is selectable before the interpreter starts, through the
`PYTHONMALLOC` environment variable, and the manual's table names the
defaults per build: `pymalloc` for a release build, `pymalloc_debug`
for a debug build, `malloc` where pymalloc is compiled out,
`malloc_debug` for that build's debug flavor, and `mimalloc` for the
free-threaded build. The debug hooks are byte-level and worth quoting:
newly allocated memory is filled with `0xCD`, freed memory with
`0xDD`, and the blocks are surrounded by forbidden bytes `0xFD` that
turn an underrun or overrun into a loud crash instead of silent
corruption.

The sample measures the dispatch on this binary. The gate never sets
the variable, so the default rules. An unknown value is fatal before
any user code: the child exits 1 at preinit with "unknown allocator".
All three of `malloc`, `pymalloc`, and `mimalloc` start cleanly on
this 3.14.7 Windows build, mimalloc included, because 3.14 grew the
mimalloc option for the standard build. What this machine does not
have is the free-threaded interpreter where mimalloc stops being an
option: "In the free-threaded build, mimalloc is the default and
required allocator", running "per-thread mimalloc heaps". That build
is chapter 17's boundary and #xref-to("python", "profiling")'s
sidebar, and nothing in this chapter pretends to measure it.

#listing("python/samples/src/Ch13/mallocenv.py", first: 9, last: 18, caption: [the probe: one child per value, the exit code and the startup text are the measurement])

#diagram([the env var table: which name a build starts under, what the debug hooks fill, and where this book stands], length: 13pt, {
  let row(y, name, note, fill: luma(235)) = {
    cdraw.rect((1.0, y), (9.6, y + 1.05), fill: fill, radius: 0.02)
    cdraw.content((5.3, y + 0.53), name, wrap: text.with(size: 6pt))
    cdraw.rect((10.0, y), (21.2, y + 1.05), fill: luma(245), radius: 0.02)
    cdraw.content((15.6, y + 0.53), note, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  row(8.0, [pymalloc], [the release default, this book's allocator])
  row(6.8, [pymalloc\_debug], [release allocator plus the 0xCD, 0xDD, 0xFD hooks])
  row(5.6, [malloc, malloc\_debug], [pymalloc compiled out, asan builds])
  row(4.4, [mimalloc], [free-threaded default and required, per-thread heaps], fill: luma(225))
  row(3.2, [anything else], [fatal at preinit, unknown allocator, exit 1])
  cdraw.content((11.1, 1.8), [all three of malloc, pymalloc, mimalloc measured starting on this 3.14.7 binary, 2026-09-13], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.1, 0.8), [no free-threaded interpreter on this machine, so mimalloc under contention stays unmeasured], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== refcounts and the collector recap

The geometry above explains why the chapter's objects are cheap to
free: a decref to zero hands the block to a free list and the next
same-shape build takes it back, measured five for five in the freelist
sample. Reference cycles are the case that path cannot solve, and the
generational collector behind them belongs to chapter 3, which pinned
its thresholds on this interpreter. This chapter only re-asserts the
recap so the memory story stands complete on one page: the thresholds
read `(2000, 10, 10)`, generation zero trips after 2000 net
allocations minus deallocations, and the churn of 3000 built-and-
dropped 4-tuples rides the freelists with at most a generation zero
collection along the way, counted from `gc.get_stats()` before and
after.

#listing("python/samples/src/Ch13/freelists.py", first: 50, last: 71, caption: [the recap checks: thresholds unchanged from chapter 3, the churn absorbed, gen0 counted])

#diagram([the two reclamation paths: refcount zero returns the block now, a cycle waits for the collector, and both end at the same free list], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.15), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.58), t, wrap: text.with(size: 6pt))
  }
  box(7.4, 8.4, 7.2, [an object's refcount drops to zero])
  box(0.8, 6.0, 9.4, [the block returns to its class free list], fill: luma(220))
  box(12.2, 6.0, 8.0, [a reference cycle survives], fill: luma(245))
  box(0.8, 3.6, 9.4, [the next same-shape build reuses it, 5 of 5 measured])
  box(12.2, 3.6, 8.0, [the gc, thresholds 2000, 10, 10, chapter 3's pin])
  box(7.4, 1.2, 7.2, [both paths end at the same pool])
  cdraw.line((9.5, 8.4), (5.5, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.5, 8.4), (16.2, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.5, 6.0), (5.5, 4.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 6.0), (16.2, 4.75), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((5.5, 3.6), (9.0, 2.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 3.6), (13.0, 2.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.1, 0.35), [the freelists absorb churn so the collector only owes the cycles], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the particle kernel: numpy versus tuples

The chapter closes on the workload the whole memory story serves, N
particles of 8 float64 fields advanced by a pure arithmetic step, 16
steps, `x += vx * dt` then `vx += (q / m) * e * dt` under a constant
field. The two representations of the same physics could not be more
different for the allocator. The array path is one 64-bytes-a-particle
buffer plus two scratch rows that the step reuses through `out=`
parameters, so after the build, tracemalloc sees no growth at all.
The tuple path is the ladder chapter of this book in a loop: every
step rebuilds an 8-slot tuple per particle, 112 bytes plus 8 floats,
and every rebuilt tuple is a freed tuple's block coming back off the
free list.

#listing("python/samples/src/Ch13/particle.py", first: 23, last: 45, caption: [the array path: one buffer, per-field rows, the step in place through two scratch rows])

#listing("python/samples/src/Ch13/particle.py", first: 47, last: 63, caption: [the tuple path: the same math, a rebuilt 8-slot tuple per particle per step])

The seeding is stated per path and honest about the difference: the
array path draws from `numpy.random.Generator(np.random.PCG64(42))`,
the tuple path from `random.Random(42)`, the Mersenne twister, same
ranges, different streams, so the two checksums are not comparable and
the sample asserts their inequality as the record of that fact. The
in-suite smoke holds both at 10000 particles with pinned checksums,
-51.506064417 for the array path and 60.225451136 for the tuple path.

The measured ladder belongs to the opt-in bench,
`samples/bench/particle_bench.py`, run alone on 2026-09-13, best of
repeats per the timeit doctrine. The crossover scan, `crossover
--repeat 11`, and the ladder run, committed as the dated capture:

#listing("python/samples/bench/captures/2026-09-13-particle-ladder.txt", first: 1, last: 15, caption: [the crossover scan: the tuple path holds the lead through 40 particles, the array path takes it at 50 and never gives it back])

#listing("python/samples/bench/captures/2026-09-13-particle-ladder.txt", first: 16, last: 29, caption: [the ladder: soa cost dives with N then rises with cache misses, the tuple cost stays flat])

The tuple cost sits near 210 to 240 ns a particle a step from 100
particles through 100000, then climbs to 346 at a million and holds
there: past the caches, every step walks boxed floats scattered
across the heap, so the per-object interpreter work gains a memory
tax. The array cost dives as N amortizes the ufunc dispatches, 82.9
ns at 100 particles, 3.12 at 10000, then rises as the buffer leaves
the caches behind, 11.5 at a million, 16.2 at ten million. The flip
lands between 40 and 50 particles: below it the fixed cost of a
dozen ufunc dispatches outweighs the work, above it the vector loop
wins and never gives the lead back, 73 times faster at the
10000-particle sweet spot. The 100 million one-off, 6.4 GB of SoA, is
measured alone in
#xref-to("python", "profiling"); the tuple path is capped at ten
million by footprint, 3.1 GB of boxed doubles, and one billion is
math on paper, 64 GB, not a run this machine makes.

#diagram([the two cost curves against N: the tuple line near 210 to 240 ns until the caches give out, the array line diving under it by N of 50 and bottoming at 10000 before rising with cache misses], length: 13pt, {
  let pos(k, v) = (
    1.6 + k * 3.76,
    8.6 - v / 400.0 * 6.8,
  )
  let logn = (2.0, 3.0, 4.0, 5.0, 6.0, 7.0)
  let pts(vals) = logn.enumerate().map(p => pos(p.at(1) - 2.0, vals.at(p.at(0))))
  let tup = pts((211.0, 209.6, 227.7, 238.0, 345.7, 345.6))
  let soa = pts((82.94, 10.24, 3.12, 4.50, 11.48, 16.18))
  cdraw.line((1.6, 1.2), (1.6, 8.6), stroke: 0.5pt + luma(180))
  cdraw.line((1.6, 8.6), (20.8, 8.6), stroke: 0.5pt + luma(180))
  cdraw.line(..soa, stroke: luma(120), mark: (end: ">"))
  cdraw.line(..tup, stroke: luma(170), dash: "dashed")
  for p in soa { cdraw.circle(p, radius: 0.09, fill: luma(120)) }
  for p in tup { cdraw.circle(p, radius: 0.09, fill: white) }
  cdraw.content((16.5, 4.6), [tuples, 210 to 346], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((6.2, 7.0), [soa, the dive and the rise], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((3.4, 1.0), [log N from 100 to 10m, y in ns a particle a step to 400], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((13.0, 8.0), [the flip at 40 to 50], wrap: text.with(size: 6pt, fill: luma(100)))
})

#callout("verify", "39 checks, the pins asserted first", [
  A scoped run, `pwsh tools/run-py-samples.ps1 -Chapter Ch13`, walks
  the six samples through the run and format legs and reports: 6
  files, 39 checks, format clean. `arenas.py` carries the interpreter
  pin and contributes 7, the census banner, the arena and pool lines,
  the 64/510/1021 arithmetic, the class table, the 32-byte stride, and
  the 510-slot census. `freelists.py` adds 9, the five-trial reuse for
  tuples, floats, and lists, the `id([])` one-liner, the 256/257 cache
  boundary, the tuple ladder, the class arithmetic, and the gc recap
  with its gen0 count. `getsizeof.py` adds 7, the four container
  ladders, the scalar sizes, and the 64-against-304 footprint.
  `tracemalloc_demo.py` adds 5, the arm and disarm, the top-line
  attribution, and the pinned current and bounded peak. `mallocenv.py`
  adds 5, the unset default, the fatal unknown value, the three
  starting allocators, the 16-byte alignment, and the threshold edge.
  `particle.py` adds 6, the numpy 2.5.3 pin, the deterministic
  redraw, the two pinned checksums, their asserted inequality, and the
  buffer arithmetic. Every expected value was produced by this venv,
  then pinned.
])

sources: docs.python.org/3/c-api/memory.html (pymalloc and the 512
byte threshold, the arena sizes and VirtualAlloc, the domain defaults,
the PYTHONMALLOC table, the 0xCD 0xDD 0xFD debug hooks, mimalloc as
the free-threaded default, PYTHONMALLOCSTATS),
docs.python.org/3/library/tracemalloc.html (the module purpose, the
nframe limit and its overhead note, the statistics key\_type table and
its sort order, get\_traced\_memory and reset\_peak),
numpy.org/doc/2.5/reference/random/generator.html (the Generator
interface behind the PCG64 seed), all accessed 2026-09-13. The
`sys.getsizeof` ladder definitions, the `gc` thresholds, and the
`random.Random` seeding live on pages this book already pins in
chapters 1, 3, and 23, and the census capture, every id measurement,
the reuse trials, and both bench runs are this machine's own, dated
2026-09-13. Sample behavior verified by `make verify-py`, 39 checks in
chapter 13.
