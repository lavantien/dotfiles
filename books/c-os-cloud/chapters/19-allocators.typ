#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow

= allocator designs

Chapter 14 rebuilt `malloc` once, as a free list over one arena, and
proved the contract. This chapter builds five more allocators, each one
a different answer to the same three questions: how fast is the happy
path, how many bytes does bookkeeping cost per allocation, and what
happens to the holes that freeing leaves behind. The bump allocator
answers fast and never looks back. The slab answers cheap for one fixed
object size. The buddy answers the holes, splitting and merging blocks
by powers of two. A tracking wrapper answers none of the three and
instead makes every other allocator observable. Everything deterministic
is asserted, every timing is printed and never checked, and the last
section does the arithmetic the capstone kernel in chapter 21 spends.

== the allocator's contract

The contract is unchanged from chapter 14: hand out pointers that do not
overlap, aligned well enough for any fundamental type, take them back
without charging the caller for the bookkeeping, and stay correct when
the caller frees in any order. What changes per allocator is which
promise is implicit. The free list of chapter 14 paid 32 bytes of header
per allocation to buy individual frees and coalescing. The allocators
below trade that freedom away in both directions: the bump allocator
refuses individual frees entirely, and the slab refuses individual
sizes. Neither trade is exotic. Every production heap in the survey
below is a hybrid of exactly these shapes, per-thread caches of fixed
size classes over an arena backend, and the reason is the same every
time: the general contract is expensive, and most allocations in a real
program do not need all of it.

#diagram([the contract triangle and where each allocator in this chapter sits], length: 13pt, {
  let corner(pos, t) = cdraw.content(pos, t, wrap: text.with(size: 6.5pt))
  corner((5.5, 8.4), [fast alloc])
  corner((16.5, 8.4), [compact bookkeeping])
  corner((11.0, 0.6), [reuse and coalescing])
  cdraw.line((5.5, 8.1), (16.5, 8.1), stroke: 0.5pt + luma(200))
  cdraw.line((5.5, 8.1), (11.0, 0.95), stroke: 0.5pt + luma(200))
  cdraw.line((16.5, 8.1), (11.0, 0.95), stroke: 0.5pt + luma(200))
  let fam(x, y, t, f) = {
    cdraw.rect((x, y), (x + 3.1, y + 0.9), fill: f, radius: 0.02)
    cdraw.content((x + 1.55, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  fam(7.6, 6.4, [bump, ch 19], luma(235))
  fam(12.0, 6.4, [slab, ch 19], luma(235))
  fam(9.8, 3.4, [buddy, ch 19], luma(235))
  fam(3.4, 1.9, [free list, ch 14], luma(245))
  fam(15.6, 1.9, [ucrt heap], luma(245))
  cdraw.content((11.0, 5.15), [no allocator occupies all three corners], wrap: text.with(size: 6pt, fill: luma(100)))
})

== alignment, size classes, and headers

Every allocator in this chapter rounds requests, and the ladder it
rounds on is a property of the target, pinned here before anything is
built on it. The fundamental types align at 1, 2, 4, and 8 bytes, and
`long double` is the first surprise: this target makes it exactly
`double`, 8 and 8, where a linux target would say 16. The struct
arithmetic follows the members, one `char` before a `double` pads the
whole struct to 16 bytes at alignment 8, and `_Alignas` raises a struct
past every member, at the price of padding the size up to the raised
alignment. One absence matters for the same story: this crt declares no
`max_align_t` at all, probed 2026-09-13, the same family of absences as
`aligned_alloc` and `free_sized` in chapters 4 and 14, so the "suitably
aligned for any fundamental type" language is quoted from the `malloc`
page rather than measured through a type.

#listing("c-os-cloud/samples/src/Ch19/align.c", first: 24, last: 43, caption: [the ladder and the two round-up functions, one 16-byte class and one power-of-two class])

The probe side of the file asks what the ucrt actually delivers, and
the answer is stronger than its own documentation promises: the page
guarantees fundamental alignment, "the alignment that's required for a
`double`, or 8 bytes", 16 on 64-bit targets, and every one of 32 odd
request sizes came back 16-aligned. The page also states the tax in one
sentence, the block "may be larger than `size` bytes because of the
space that's required for alignment and maintenance information", which
is the exact cost the next three sections measure two ways.

#listing("c-os-cloud/samples/src/Ch19/align.c", first: 66, last: 74, caption: [the probe: 32 odd sizes through the real heap, alignment asserted not assumed])

The two round-up functions are the whole grammar of the chapter.
`round16` is the size-class function, tcmalloc's own worked example on
its design page, "an allocation of 12 bytes will get rounded up to the
16 byte size-class", compressed to one expression. `pow2ceil` is the
buddy function, and the checks pin the fragmentation it causes as
arithmetic: a 5-byte request strands 11 bytes in its class, a 17-byte
request strands 15, and a 5000-byte buddy request strands 3192 in the
next section.

#listing("c-os-cloud/samples/src/Ch19/align.c", first: 45, last: 51, caption: [the buddy class function: smallest power of two that fits])

#diagram([the type ladder and the class ladders: where every request lands], length: 13pt, {
  let bar(y, w, t) = {
    cdraw.rect((0.8, y), (0.8 + w, y + 0.75), fill: luma(235), radius: 0.02)
    cdraw.content((0.8 + w + 0.25, y + 0.37), t, wrap: text.with(size: 6pt), anchor: "west")
  }
  bar(7.4, 1.2, [char, short: 1 and 2])
  bar(6.3, 2.4, [int: 4])
  bar(5.2, 4.8, [double, long double: 8, ld is double here])
  bar(4.1, 9.6, [\_Alignas(16) header: one size class])
  bar(3.0, 19.2, [chapter 14 header: two size classes])
  cdraw.content((11.5, 1.95), [the 16-byte classes: 1 to 16, 17 to 32, 33 to 48], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 1.15), [the buddy classes: 1, 2, 4, ..., 1 MiB, one xor apart], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 0.45), [stranded bytes: class size minus request, 11 of 16, 15 of 32, 3192 of 8192], wrap: text.with(size: 6pt))
})

== bump allocation

The bump allocator is one cursor over one arena. Allocation rounds the
cursor up to the requested alignment, checks that the rounded start and
the size both fit, hands out the pointer, and moves the cursor. There is
no header, no free list, and no way to free anything individually:
`free` does not exist, and the overflow guard is written so the addition
cannot wrap, the start is compared against the arena bound before the
size is subtracted from it.

#listing("c-os-cloud/samples/src/Ch19/bump.c", first: 34, last: 43, caption: [the whole allocator: round up, bound check, hand out, advance, and the one-word reset])

The checks pin the arithmetic from both ends. Two adjacent 16-byte
bumps land 16 bytes apart, zero overhead against the 32 bytes a
chapter 14 pair would pay. A failing request leaves the cursor exactly
where it was, and the arena can be filled to its last byte, which pins
that the bound check wastes nothing. Reset is one store, and the
strongest property follows from it: replaying the same request sequence
after a reset returns the identical addresses, determinism chapter 21's
kernel leans on. At `-O2` the fast path compiles to a single mask, an
`and i64` against `-16` or the 64-byte mask `0xffffc0`, one branch for
the bound, and the gate pins the substring.

#listing("c-os-cloud/samples/src/Ch19/bump.c", first: 75, last: 88, caption: [zero overhead pinned as an address delta, and failure pinned as a no-op])

The clock, printed three times across the runs observed while writing:
200000 allocations of 32 bytes plus one reset cost 0.61 to 0.64 ms,
against 5.38 to 6.63 ms for the ucrt `malloc` and `free` of the same,
a ratio of 8.8x to 10.3x. That is the whole price of the general
contract, alignment negotiation, size-class lookup, bookkeeping, and
a `free` that must find what it is freeing, paid on every allocation
by a heap that cannot know the caller does not need any of it.

#listing("c-os-cloud/samples/src/Ch19/bump.c", first: 112, last: 129, caption: [the clock: bump against the ucrt heap, same request stream])

#diagram([one cursor, no holes: allocation moves the arrow, reset moves it home], length: 13pt, {
  cdraw.rect((0.8, 5.6), (21.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.rect((0.8, 5.6), (4.9, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((2.85, 6.05), [16 B], wrap: text.with(size: 6pt))
  cdraw.rect((5.4, 5.6), (8.4, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((6.9, 6.05), [3 B, rounded], wrap: text.with(size: 6pt))
  cdraw.rect((8.9, 5.6), (14.2, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((11.55, 6.05), [4096-aligned ask], wrap: text.with(size: 6pt))
  cdraw.line((15.0, 5.2), (15.0, 6.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((15.0, 7.25), [the cursor], wrap: text.with(size: 6pt))
  cdraw.content((18.2, 6.05), [free space, one word of state], wrap: text.with(size: 6pt))
  cdraw.content((11.2, 4.4), [free does not exist: holes are impossible, reset is one store], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.2, 3.3), [measured: 0.61 to 0.64 ms per 200k asks, 8.8x to 10.3x over the ucrt pair], wrap: text.with(size: 6pt))
  cdraw.content((11.2, 2.4), [-O2: the round-up is one and-mask, pinned in the ir], wrap: text.with(size: 6pt))
})

== the slab

Fix the object size and half the contract disappears. A slab is one
arena cut into equal slots, and because every slot is the same size
class, no slot needs a header: the free list is threaded through the
free slots themselves, the first 8 bytes of a free slot hold the next
free slot. The entire allocator is one pointer and two counters of
static state, `salloc` is a pop, `sfree` is a push, and the arena holds
exactly 1024 objects of 64 bytes with no per-object byte spent on
bookkeeping.

#listing("c-os-cloud/samples/src/Ch19/slab.c", first: 33, last: 60, caption: [the whole slab: build the list inside the slots, then pop and push])

The permutation check is the slab's integrity proof: draining all 1024
slots must yield each address exactly once, every one 64-byte strided
inside the arena, with a bitmap proving no duplicates and no gaps. LIFO
is then pinned exactly, three frees returned in reverse, and the
strongest check closes the loop: freed in reverse order, a second full
drain replays the identical address sequence. Mixed traffic over a
256-slot window, three allocations and one free per round for 64
rounds, ends with the live count exact to the byte.

#listing("c-os-cloud/samples/src/Ch19/slab.c", first: 80, last: 94, caption: [the permutation: drain everything, see each slot exactly once])

The clock prints the same shape as bump's. One million pop-and-push
pairs of 64 bytes cost 3.40 to 3.81 ms across the runs observed while
writing, against 28.25 to 28.47 ms for the ucrt pair on the same
request stream, 7.4x to 8.3x. The gap is smaller than bump's because
the slab's pop is a dependent load, the head pointer must arrive before
the next head can be read, where bump's cursor is a plain increment.
At `-O2` the pop is one `load ptr, ptr @head` and the gate pins it.

#listing("c-os-cloud/samples/src/Ch19/slab.c", first: 139, last: 153, caption: [the clock: a million pop-push pairs against the ucrt pair])

#diagram([free slots carry the list: the link lives inside the storage it is handing out], length: 13pt, {
  for i in range(8) {
    let x = 0.8 + i * 2.7
    let used = not calc.even(i)
    let f = if used { luma(205) } else { luma(238) }
    cdraw.rect((x, 5.4), (x + 2.2, 6.3), fill: f, radius: 0.02)
    if not used {
      cdraw.content((x + 1.1, 5.85), [next], wrap: text.with(size: 6pt))
    } else {
      cdraw.content((x + 1.1, 5.85), [#i], wrap: text.with(size: 6pt))
    }
  }
  cdraw.content((11.4, 4.55), [dark slots are live objects, light slots are their own free list], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.4, 3.7), [zero header bytes: 1024 x 64 B exactly, chapter 14 would need 96 B each], wrap: text.with(size: 6pt))
  cdraw.content((11.4, 2.8), [the pop is one dependent load, reset does not exist, drain replays lifo], wrap: text.with(size: 6pt))
  cdraw.content((11.4, 1.9), [measured: 3.40 to 3.81 ms per million pairs, 7.4x to 8.3x over ucrt], wrap: text.with(size: 6.5pt))
})

== the buddy allocator

The buddy allocator over 1 MiB answers the question bump refuses: holes.
Every block is a power of two between 4 KiB and 1 MiB, an allocation
rounds up to the next power of two and splits larger blocks in half
until one fits, and the partner of every block is one xor away in the
offset. Freeing merges equal-order partners back up the ladder as long
as the partner is free, so interleaved traffic can always return to one
whole block.

#listing("c-os-cloud/samples/src/Ch19/buddy.c", first: 93, last: 96, caption: [the whole addressing scheme: one bit flip at the block's order])

#listing("c-os-cloud/samples/src/Ch19/buddy.c", first: 106, last: 122, caption: [allocation: find a fit order, split the high halves back onto their lists])

#listing("c-os-cloud/samples/src/Ch19/buddy.c", first: 125, last: 138, caption: [freeing: absorb the partner while it is free, then push the merged block])

The checks walk the structure by hand. One 4 KiB request from a fresh
arena leaves exactly one free block at every order below the top, the
split chain, and drops the free byte count by exactly 4096. Two 8 KiB
blocks are partners, the first free cannot merge because its partner is
busy, and freeing the partner walks the merge ladder all the way back
to one 1 MiB block. The fragmentation story is arithmetic, a 5000-byte
request lives in an 8192 block and 3192 bytes stay unusable, and the
exhaustion story is exact: 1 MiB is precisely 256 minimum blocks, the
257th fails, freeing every other block leaves 128 partners that never
meet, and freeing the rest closes back to the whole.

#listing("c-os-cloud/samples/src/Ch19/buddy.c", first: 203, last: 222, caption: [exact exhaustion, then interleaved frees that cannot merge])

One placement fact bounds the whole design: blocks are aligned to
their order relative to the arena base, and the base is only as aligned
as its placement. This target caps static `_Alignas` at 8192 bytes, a
compile error probes it, so a 1 MiB buddy in production takes its arena
from `VirtualAlloc`, whose base is page aligned, rather than from a
static array. The sample checks base-relative alignment and says so in
its comments.

#diagram([the split chain: one 4 KiB request leaves one partner at every order below], length: 13pt, {
  cdraw.rect((9.6, 8.0), (12.6, 8.7), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, 8.35), [1 MiB], wrap: text.with(size: 6pt))
  cdraw.line((10.35, 7.95), (8.4, 7.35), stroke: luma(100))
  cdraw.line((11.85, 7.95), (14.0, 7.35), stroke: luma(100))
  cdraw.rect((7.1, 6.9), (9.7, 7.5), fill: luma(205), radius: 0.02)
  cdraw.content((8.4, 7.2), [512 KiB], wrap: text.with(size: 6pt))
  cdraw.rect((12.7, 6.9), (15.3, 7.5), fill: luma(238), radius: 0.02)
  cdraw.content((14.0, 7.2), [512 KiB free], wrap: text.with(size: 6pt))
  cdraw.line((8.4, 6.85), (6.6, 6.25), stroke: luma(100))
  cdraw.content((3.9, 6.6), [the chain walks down, 8 KiB at each step], wrap: text.with(size: 6pt))
  cdraw.rect((1.0, 4.2), (4.6, 4.9), fill: luma(205), radius: 0.02)
  cdraw.content((2.8, 4.55), [4 KiB, yours], wrap: text.with(size: 6pt))
  cdraw.rect((5.4, 4.2), (9.0, 4.9), fill: luma(238), radius: 0.02)
  cdraw.content((7.2, 4.55), [4 KiB partner], wrap: text.with(size: 6pt))
  cdraw.content((11.4, 3.4), [one request, eight leftover partners, one per order down to 4 KiB], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.4, 2.5), [every partner is one xor away; free both and the ladder merges home], wrap: text.with(size: 6pt))
  cdraw.content((11.4, 1.6), [257th 4 KiB ask fails: 1 MiB is exactly 256 minimum blocks], wrap: text.with(size: 6pt))
})

== a tracking wrapper

None of the allocators above can answer "who allocated this". The
tracking wrapper is not an allocator at all, it is a table wrapped
around `malloc` and `free` that records pointer, size, and a caller
supplied site id for every live allocation, and flips records to
tombstones on free. The two failure modes a leak report needs fall out
of the state machine: freeing a pointer with no record is a never
allocated pointer, freeing a record already in the tombstone state is a
double free, and both return codes are asserted with the accounting
untouched.

#listing("c-os-cloud/samples/src/Ch19/track.c", first: 48, last: 76, caption: [the wrap: record the address, size, and site; rewrite tombstones on address reuse])

#listing("c-os-cloud/samples/src/Ch19/track.c", first: 80, last: 97, caption: [the four frees: clean, unknown, double, and the null arm])

The wrapper states its own limits as checks. The table keys on
address, so an address the heap reuses rewrites its own tombstone
rather than shadowing it, and a recycled tombstone whose address
differs loses that old address's double-free memory, the trade stated
in the comment. Capacity is a hard limit: 64 slots track 64, and the
65th allocation is refused loudly rather than silently lost. The clock
prints the question's price, 100000 tracked pairs of 32 bytes against
the bare loop, 2.66x to 3.68x across the runs observed while writing,
and that ratio is the honest reason production allocators sample rather
than record everything.

#diagram([three record states and the transitions the two error returns guard], length: 13pt, {
  let st(x, y, w, t, f) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: f, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  st(1.2, 6.6, 3.4, [free slot], luma(238))
  st(8.0, 6.6, 3.4, [live], luma(205))
  st(15.2, 6.6, 3.6, [tombstone], luma(238))
  cdraw.line((4.6, 7.05), (8.0, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.3, 7.35), [t_malloc], wrap: text.with(size: 6pt))
  cdraw.line((11.4, 7.05), (15.2, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.3, 7.35), [t_free, 0], wrap: text.with(size: 6pt))
  cdraw.line((16.9, 6.55), (9.7, 6.55), stroke: luma(150), mark: (end: ">"))
  cdraw.content((13.3, 6.2), [t_free, 2: the double], wrap: text.with(size: 6pt))
  cdraw.content((11.6, 4.7), [no record: t_free returns 1, never allocated; null returns 3], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.6, 3.6), [live_n, live_bytes, sites: the leak ledger, exact to the byte], wrap: text.with(size: 6pt))
  cdraw.content((11.6, 2.6), [measured: 2.66x to 3.68x over bare malloc/free, the observability tax], wrap: text.with(size: 6.5pt))
})

== the production survey

Four production allocators, all cited from their own documentation and
none of them installed on this machine, every one a hybrid of the
shapes above. The ucrt heap this book links is the baseline: its page
promises fundamental alignment and admits the maintenance tax, and its
debug builds swap in a tracking heap, the crt debug heap, that records
exactly what `track.c` records. jemalloc describes itself as "a general
purpose malloc(3) implementation that emphasizes fragmentation
avoidance and scalable concurrency support", became the FreeBSD libc
allocator in 2005, and has shipped heap profiling and tuning hooks
since 2010: the buddy's merge discipline scaled by arenas. mimalloc,
Microsoft's allocator born in the Koka and Lean runtimes, calls itself
"a general purpose allocator with excellent performance characteristics",
keeps the core near 10k lines of code, shards its free lists per
roughly 64 KiB page "which reduces fragmentation and increases
locality", reports about 0.2 percent metadata overhead, and notes that
freeing from another thread "can now be a single CAS": the slab, sharded.
tcmalloc is "Google's customized implementation of C's `malloc()` and
C++'s `operator new`", "a fast, multi-threaded malloc implementation",
and its design page describes the exact two layers this chapter built,
"a thread cache contains one singly linked list of free objects per
size-class" over a backend, with small allocations "mapped onto one of
60-80 allocatable size-classes" and the same 12-rounds-to-16 example
`round16` compresses. The survey is documentation-verified only, the
same boundary the cloud chapters use: no benchmark here compares
against an allocator that is not installed.

#diagram([four production heaps as hybrids of this chapter's shapes], length: 13pt, {
  let row(y, name, layers) = {
    cdraw.content((4.4, y), name, wrap: text.with(size: 6pt), anchor: "east")
    let x = 5.0
    for t in layers {
      let w = t.len() * 0.72
      cdraw.rect((x, y - 0.45), (x + w, y + 0.45), fill: luma(238), radius: 0.02)
      cdraw.content((x + w / 2, y), [#t], wrap: text.with(size: 6pt))
      x += w + 0.35
    }
  }
  row(7.6, [ucrt], ("size classes", "heap blocks", "debug: track"))
  row(5.9, [jemalloc], ("arenas", "size classes", "runs, merges"))
  row(4.2, [mimalloc], ("pages ~64 KiB", "sharded slabs", "cas free"))
  row(2.5, [tcmalloc], ("thread cache", "one list per class", "backend"))
  cdraw.content((12.0, 1.1), [cited from their own docs, none installed here, no numbers borrowed], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the particle kernel's memory budget

The capstone kernel in chapter 21 simulates N particles behind these
allocators, 8 `double` fields each, position, velocity, mass, and
charge, and the budget is pure arithmetic this chapter can close. One
particle is 64 bytes, so 1 million particles are 64 MiB, 100 million
are 6.4 GiB, and 1 billion are 64 GiB, and the layout does not change
the total: 8 doubles pad to nothing, the array-of-structs and
struct-of-arrays forms of this data are the same bytes, the difference
chapter 13 measured is which lanes a sweep touches, not how many bytes
exist. The bookkeeping is where the layouts diverge. Behind the bump
allocator the kernel pays zero per particle beyond the 64. Behind a
chapter 14 free list it would pay a 32-byte header per particle, 50
percent on top, 32 MiB stranded per million particles and 3.2 GiB per
hundred million. The kernel uses bump and slab shapes because the
budget says so, and chapter 21 measures what the arithmetic predicts.

#diagram([the budget ladder: 8 doubles per particle, three scales, two bookkeeping costs], length: 13pt, {
  let bar(y, w, t, f) = {
    cdraw.rect((6.2, y), (6.2 + w, y + 0.85), fill: f, radius: 0.02)
    cdraw.content((6.45 + w, y + 0.42), t, wrap: text.with(size: 6pt), anchor: "west")
  }
  cdraw.content((5.8, 7.6), [1m], wrap: text.with(size: 6pt), anchor: "east")
  bar(7.35, 1.9, [64 MiB payload, +0 bump, +32 MiB headers], luma(205))
  cdraw.content((5.8, 5.9), [100m], wrap: text.with(size: 6pt), anchor: "east")
  bar(5.65, 6.4, [6.4 GiB payload, one-off in chapter 21, alone], luma(205))
  cdraw.content((5.8, 4.2), [1b], wrap: text.with(size: 6pt), anchor: "east")
  bar(3.95, 12.4, [64 GiB, by math only, not measured on this machine], luma(238))
  cdraw.content((11.5, 2.6), [one particle is exactly 64 bytes: x y z vx vy vz m q], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 1.7), [aos and soa cost the same bytes here, no padding, chapter 13 owns the lane story], wrap: text.with(size: 6pt))
})

#callout("verify", "one chapter, five allocators, one clock", [
  63 checks run at `-O0` and assert only deterministic facts: the
  alignment ladder, header sizes, class arithmetic, split chains, merge
  ladders, permutations, lifo orders, and the tracker's four frees. 3
  ir substrings and 2 roundtrip legs are asserted on `-O2` output the
  runtime never executes. The timings quoted in this chapter, bump 8.8x
  to 10.3x over the ucrt pair, the slab 7.4x to 8.3x, the tracker 2.66x
  to 3.68x, are printed observations from the runs during writing, and
  no check anywhere in the chapter depends on them.
])

sources: learn.microsoft.com, the `malloc` page (fundamental alignment,
the maintenance-information sentence) and the acquiring high-resolution
time stamps page, accessed 2026-09-13; jemalloc.net, mimalloc
(microsoft.github.io/mimalloc), and tcmalloc
(google.github.io/tcmalloc and its design page), accessed 2026-09-13,
cited and documentation-verified only, none installed here. Alignment
facts, the 8192-byte `_Alignas` cap, the absent `max_align_t`, and all
timings probed on this machine 2026-09-13. Sample behavior verified by
`make verify-c`, 63 checks in chapter 19 of the samples suite.
