#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the heap and allocators

Automatic storage lives and dies with the block that declares it. Heap
storage is the counterexample: `malloc` hands out storage whose lifetime
outlives the call, the program decides when that lifetime ends, and
everything between those two points is a contract. This chapter reads the
contract from two sources, the C23 final draft n3220 and the ucrt
reference pages for the allocator this machine actually links, then
rebuilds it from scratch: a free-list allocator over one static arena,
the two placement policies real allocators choose between, and finally
the windows-only window into a live heap, `HeapWalk`. Three samples
carry the chapter with 61 checks, and the address-sanitizer leg of the
gate reruns the arena allocator instrumented, because a chapter that
builds an allocator owes the reader proof it never writes outside it.

== the malloc contract

The whole contract sits in one paragraph of n3220, 7.24.3 p1, and it
opens by listing what is not promised: "The order and contiguity of
storage allocated by successive calls to the `aligned_alloc`, `calloc`,
`malloc`, and `realloc` functions is unspecified." What is promised
follows immediately: "The pointer returned if the allocation succeeds is
suitably aligned so that it may be assigned to a pointer to any type of
object with a fundamental alignment requirement and size less than or
equal to the size requested." Two sentences fix the lifetime and the
geometry, "The lifetime of an allocated object extends from the
allocation until the deallocation" and "Each such allocation shall yield
a pointer to an object disjoint from any other object", and the
paragraph closes with the address and failure rules, "The pointer
returned points to the start (lowest byte address) of the allocated
space. If the space cannot be allocated, a null pointer is returned."

Zero-size requests keep their own escape hatch: "If the size of the
space requested is zero, the behavior is implementation-defined: either
a null pointer is returned to indicate an error, or the behavior is as
if the size were some nonzero value, except that the returned pointer
shall not be used to access an object." The ucrt picks the second arm
and documents it: "If size is 0, `malloc` allocates a zero-length item
in the heap and returns a valid pointer to that item." The sample pins
both halves of that pairing on this box, and the same ucrt page fixes
the alignment number this machine delivers: the returned storage is
"suitably aligned for storage of any type of object that has an
alignment requirement less than or equal to that of the fundamental
alignment", and "In code that targets 64-bit platforms, it's 16 bytes",
the value chapter 4 already pinned for `_aligned_malloc`'s threshold.
The page also states the allocator's freedom in one sentence, "The
`malloc` function allocates a memory block of at least size bytes. The
block may be larger than size bytes because of the space that's
required for alignment and maintenance information", maintenance being
the allocator's own bookkeeping, invisible above the interface.

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 174, last: 186, caption: [the ucrt half of the contract, executed: no-op null free, 16-byte alignment, the zero-size arm])

The first three checks of the sample run against the real allocator.
`free(NULL)` executes the 7.24.3.3 sentence "If ptr is a null pointer,
no action occurs" and continues, every size from 1 to 17 comes back
16-aligned, and `malloc(0)` returns a pointer that is freed like any
other. The page marks both `malloc` and `realloc` with
`__declspec(noalias)` and `__declspec(restrict)`, "the pointer returned
isn't aliased", the compiler-facing form of the standard's disjointness
promise. The pattern check turns that promise into bytes: two live
64-byte allocations filled with distinct patterns still hold them after
both writes, which is only possible if the ranges do not overlap.

`realloc` is where the standard, the platform, and history disagree.
The standard text, 7.24.3.7, is careful: "The `realloc` function
deallocates the old object pointed to by `ptr` and returns a pointer to
a new object that has the size specified by size. The contents of the
new object shall be the same as that of the old object prior to
deallocation, up to the lesser of the new and old sizes", any bytes
beyond the old size have unspecified values, and on failure "the old
object is not deallocated and its value is unchanged". A null `ptr`
"behaves like the `malloc` function for the specified size". Then the
sentence that changed in C23: "if `ptr` does not match a pointer
earlier returned by a memory management function, or if the space has
been deallocated by a call to the `free` or `realloc` function, or if
the size is zero, the behavior is undefined." Zero was not always
undefined, cppreference's timeline shows it implementation-defined and
deprecated via C DR 400 since C17, undefined since C23, and the ucrt
page openly sides with history: "If size is zero, then the block
pointed to by `memblock` is freed; the return value is `NULL`, and
`memblock` is left pointing at a freed block", under a note that
`realloc` "hasn't been updated to implement C17 behavior because the
new behavior isn't compatible with the Windows operating system."

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 187, last: 206, caption: [disjoint live storage, then a grow that moves and preserves the prefix])

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 207, last: 215, caption: [shrink keeps the prefix, realloc of NULL allocates, the zero-size ucrt contract])

The grow check asks exactly what the standard guarantees and nothing
more: 32 bytes filled with a ramp, `realloc` to 200, the ramp intact,
the result 16-aligned. Probed on this box the grow moved the block and
a shrink to 8 bytes stayed in place, but both of those are freedoms,
the checks assert only the contents and the alignment. The last check
pins the ucrt's documented zero-size behavior, `realloc(p, 0)`
returning `NULL` after freeing, which is precisely the call C23 now
declares undefined, so this is one place where the sample asserts the
platform's documented contract rather than the standard's.

The standard also grew a sibling for `free` in C23. `free_sized`,
7.24.3.4, states "If `ptr` is a null pointer or the result obtained
from a call to `malloc`, `realloc`, or `calloc`, where size is equal to
the requested allocation size, this function is equivalent to
`free(ptr)`. Otherwise, the behavior is undefined." Probed through the
gate's exact flags, this crt does not declare it, the compile dies with
`use of undeclared identifier 'free_sized'`, the same absence chapter 4
recorded for `aligned_alloc`. The deallocation side of this chapter
therefore uses plain `free`, and the free page's sentence about what
deallocation means reads as the thesis of everything below: "Freed
memory that isn't released to the operating system is restored to the
free pool and is available for allocation again."

#diagram([the contract as a decision table: what every call must do, and where the implementation chooses], length: 13pt, {
  cdraw.rect((7.0, 8.2), (17.4, 9.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.2, 8.8), [a call to malloc, calloc, realloc, aligned\_alloc], wrap: text.with(size: 6pt))
  let fixed = ([suitably aligned for any fundamental alignment],
               [disjoint from every other live object],
               [points to the lowest byte address],
               [lifetime runs from allocation to free],
               [a null pointer when it cannot serve])
  let free = ([order and contiguity unspecified],
              [the block may be larger than asked],
              [malloc(0): null, or a phantom nonzero],
              [realloc may move the object or keep it],
              [realloc(p, 0): undefined since c23])
  for (i, t) in fixed.enumerate() {
    let y = 6.6 - i * 1.05
    cdraw.rect((0.6, y), (8.8, y + 0.9), fill: luma(238), radius: 0.02)
    cdraw.content((4.7, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  for (i, t) in free.enumerate() {
    let y = 6.6 - i * 1.05
    cdraw.rect((14.6, y), (23.8, y + 0.9), fill: luma(238), radius: 0.02)
    cdraw.content((19.2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((4.7, 7.35), [the standard fixes these], wrap: text.with(size: 6.5pt))
  cdraw.content((19.2, 7.35), [the implementation chooses these], wrap: text.with(size: 6.5pt))
  cdraw.line((9.2, 8.4), (4.7, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.2, 8.4), (19.2, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.6, 0.3), (20.8, 2.2), fill: luma(235), radius: 0.02)
  cdraw.content((12.2, 1.6), [ucrt on this box: 16-byte alignment, a valid pointer for malloc(0)], wrap: text.with(size: 6pt))
  cdraw.content((12.2, 0.95), [realloc(p, 0) frees and returns NULL, its documented choice], wrap: text.with(size: 6pt))
})

#callout("pitfall", "the three-line portability trap at size zero", [
  `malloc(0)` is implementation-defined and the two arms behave
  oppositely, one returns `NULL`, the other a pointer that must be
  freed, so `if (malloc(0) == NULL) die();` is wrong on half the
  implementations. `realloc(p, 0)` was the same kind of split until
  C23 deleted the choice and made it undefined. And `free_sized`,
  C23's answer to "the callee already knows the size", is not declared
  by the ucrt at all. Three size-zero questions, three different
  answers on this one machine.
])

== a free-list allocator

The allocator under the arena is one data structure and under 150
lines. The arena is a static 64 KiB array aligned to 16, carved into
blocks, and
every block opens with the same 32-byte header. The `_Alignas` on the
first member raises the whole header struct to alignment 16, which
forces `sizeof` from 24 to 32, so every payload begins at a header
address plus 32, and headers only ever sit at 16-aligned arena
offsets. The header carries the whole block size, a free-list link,
and an in-use bit, and the static assert freezes the layout the rest
of the file computes against.

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 28, last: 40, caption: [the 32-byte header and the arena it carves, one alignment rule for both])

The free list is kept sorted by address, and that one decision is
what makes coalescing cheap. Returning a block walks the list to the
insertion point, links the block in, and then merges twice, forward
when this block ends exactly where the next free block starts, and
backward when the previous free block ends exactly where this one
starts. Adjacent free blocks therefore cannot survive a `my_free`,
the list is invariantly coalesced, and the ucrt's own words describe
the same maintenance: `_heapmin` works "by coalescing the unused
regions", and freed memory "is restored to the free pool and is
available for allocation again".

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 49, last: 70, caption: [address ordered insertion, then both coalescing directions])

Allocation is first fit down that address-ordered list: round the
request up to a multiple of 16, add the header, take the first free
block that holds it, and `split_off` carves the block to size,
returning the remainder to the free list whenever the remainder can
hold a header plus a minimal payload. `my_free` is the mirror image
plus the null clause, and the two together implement the 7.24.3
geometry, a disjoint 16-aligned lowest-address payload per call, with
reuse for free.

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 84, last: 102, caption: [first fit with split: the carve that serves every request])

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 104, last: 122, caption: [the deallocator, and realloc's three cheap clauses: null, zero, shrink])

`my_realloc` gets the same clauses the standard gives the real one.
`NULL` delegates to `my_malloc`, zero frees and returns `NULL` by this
allocator's stated choice, matching the ucrt probed above, and a
shrink keeps the block, legal because the block "may be larger than
size bytes". A grow first tries to absorb the physical successor: the
coalesced-list invariant guarantees that successor is free at most
once, so a single absorb either fits the request or the grow must
move, allocate fresh, `memcpy` the old contents, and free the old
block, exactly the copy arm of 7.24.3.7.

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 123, last: 140, caption: [the in-place grow: find the successor in the free list, absorb it, split the excess])

Everything the allocator claims is re-derived by an audit that never
trusts the allocator's own bookkeeping. Because blocks tile the arena
by construction, a walk from the first header that follows `size`
fields must land exactly on the arena end. The walk counts blocks,
free blocks, free bytes, and the largest free block, and flags
`true` only when the walk covered the arena with no gap and no
overlap. Every phase of `main` ends in an `audit()` and a check on
its numbers, so the no-overlap invariant is not a comment, it is a
property the gate re-proves after every mutation.

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 149, last: 170, caption: [the structural audit: headers chain by size, a clean heap tiles the arena exactly])

#diagram([one arena through the fragmentation checks: five carves, two frees, and the merge that follows], length: 13pt, {
  let cell(x, w, t, fill) = {
    cdraw.rect((x, 4.6), (x + w, 5.6), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 5.1), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 3.4, [a used], luma(205))
  cell(4.0, 3.4, [b free], luma(238))
  cell(7.4, 3.4, [c used], luma(205))
  cell(10.8, 3.4, [d free], luma(238))
  cell(14.2, 3.4, [e used], luma(205))
  cell(17.6, 4.4, [tail free], luma(238))
  cdraw.content((11.5, 3.95), [after free(b) and free(d): the free list is b, d, tail, address order], wrap: text.with(size: 6.5pt))
  let cell2(x, w, t, fill) = {
    cdraw.rect((x, 2.0), (x + w, 3.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 2.5), t, wrap: text.with(size: 6pt))
  }
  cell2(0.6, 3.4, [a used], luma(205))
  cell2(4.0, 10.2, [b + c + d merged free], luma(238))
  cell2(14.2, 3.4, [e used], luma(205))
  cell2(17.6, 4.4, [tail free], luma(238))
  cdraw.line((7.4, 4.5), (7.4, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.9, 1.35), [free(c): both neighbors end and start exactly at c's edges, one merge], wrap: text.with(size: 6.5pt))
})

The main function walks the same road against the arena. The fresh
arena audits as one free block, `my_malloc(0)` returns `NULL`, this
allocator's chosen arm, two carve-outs for sizes 1 and 17 land
16-aligned leaving exactly the computed free bytes behind, and
freeing both coalesces back to a single block. The reuse check is
the deterministic form of the contract-section probe: allocate 100,
free, allocate 100 again, and the same address returns, because
first fit over an address-ordered list always takes the same hole.

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 248, last: 261, caption: [the fragmentation windows: scrambled frees and the observed merge])

#listing("c-os-cloud/samples/src/Ch14/freelist.c", first: 262, last: 269, caption: [the last frees coalesce the arena, and the full-width request succeeds])

The fragmentation windows are the point of the data structure. Five
equal carves, then `free(b)` alone leaves two holes, `free(d)` leaves
three, and `free(c)`, allocated between the two freed neighbors,
merges all three into one, after which the audit sees two free blocks
where three existed a line earlier. While `a` and `e` still hold
their blocks, no hole spans the arena, so a full-width request fails,
and freeing the last two coalesces everything back until that same
request succeeds. The exhaustion phase carves 8192-byte blocks until
the 8th fails, exactly 7 fit in 65536 bytes with headers, checks that
a failed request leaves the audit unchanged, and frees its way back
to a single block. The realloc phases run the three growth paths,
absorb-in-place with the successor free, move-and-copy with the
successor busy, and the copy check that started the contract section,
and the closing audit is one block, `tiled` true, 65536 free bytes.

#callout("verify", "why the asan leg runs this file", [
  The gate's address-sanitizer pass reruns `freelist.c` instrumented.
  The arena design makes that leg natural rather than heroic: there
  is no `malloc` inside the allocator, every header and payload lives
  inside one static array, and the audit already walks the same bytes
  the sanitizer shadows. The instrumented run prints the same 32
  checks, which is the point: an allocator that only works unwatched
  is not an allocator.
])

== first fit versus best fit fragmentation

A placement policy answers one question inside every allocator: given
several holes that each hold the request, which one gets carved. First
fit takes the lowest address, best fit takes the tightest hole. Both
run in this chapter's second sample against one fixed nine-operation
script, and because the script is data, both runs are byte-for-byte
deterministic. The arena is 1024 units; the script allocates 100,
500, 100, 100, frees the 500, then asks for 60, 70, 80, and finally
350. The first four operations never face a choice, there is only one
hole, and the sample asserts both policies place all four identically.
The divergence starts at the 60: after the free, the holes are 500 at
offset 100 and 224 at the tail.

#listing("c-os-cloud/samples/src/Ch14/frag.c", first: 70, last: 94, caption: [the policy choice: first fit stops at the lowest address that fits, best fit keeps scanning for the tightest])

First fit carves the 60 out of the 500, best fit out of the 224. The
70 and the 80 follow the same split, first fit shredding the big hole
into 440, 370, 290, best fit consuming the small one down to 164, 94,
14. Then the 350 arrives: first fit's largest hole is 290, the request
fails; best fit still holds an untouched 500 at offset 100, and the
request lands at 100 leaving a 150 hole. Same script, same total free
bytes at every step until the end, opposite outcomes on the one
request that mattered. The sample prints both hole lists after every
operation, and the transcript lines are the figure below.

The final metric is the difference between the free total and the
largest hole, the bytes that are free but cannot serve a request as
large as the biggest hole that remains. First fit ends with 514 free
bytes and a 290 largest, 224 stranded; best fit ends with 164 free
and 150 largest, 14 stranded, having served one more request. Neither
policy wins in general, best fit's tight packing is exactly what let
it keep the 500 whole, and both samples end the same way: freeing
every live slot coalesces both heaps back to a single hole covering
all 1024 units, the same reversibility the arena allocator asserted.

#listing("c-os-cloud/samples/src/Ch14/frag.c", first: 150, last: 158, caption: [the fixed script, one data table driving both policies])

#listing("c-os-cloud/samples/src/Ch14/frag.c", first: 164, last: 180, caption: [the checks: identical prefix, the served counts, and both fragmentation metrics])

#diagram([largest contiguous hole after each operation, both policies, same script], length: 13pt, {
  let ff = (924, 424, 324, 224, 500, 440, 370, 290, 290)
  let bf = (924, 424, 324, 224, 500, 500, 500, 500, 150)
  let x(i) = { 2.2 + i * 2.5 }
  let y(v) = { 1.2 + v * 0.0072 }
  // axes
  cdraw.line((2.2, 1.2), (22.8, 1.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.2, 1.2), (2.2, 8.6), stroke: luma(100), mark: (end: ">"))
  for v in (0, 224, 500, 1024) {
    cdraw.line((2.15, y(v)), (22.8, y(v)), stroke: luma(220))
    cdraw.content((1.7, y(v)), [#v], wrap: text.with(size: 6pt), anchor: "east")
  }
  for (i, op) in ("100", "500", "100", "100", "free", "60", "70", "80", "350").enumerate() {
    cdraw.content((x(i), 0.75), [#op], wrap: text.with(size: 6pt))
  }
  for i in range(8) {
    cdraw.line((x(i), y(ff.at(i))), (x(i + 1), y(ff.at(i + 1))), stroke: rgb("#8B0000"))
    cdraw.line((x(i), y(bf.at(i))), (x(i + 1), y(bf.at(i + 1))), stroke: rgb("#006400"))
  }
  cdraw.content((5.0, 6.9), [first fit], wrap: text.with(size: 6.5pt, fill: rgb("#8B0000")))
  cdraw.content((8.6, 4.5), [best fit holds the 500], wrap: text.with(size: 6.5pt, fill: rgb("#006400")))
  cdraw.content((19.5, 4.9), [op 9: 350 fails here], wrap: text.with(size: 6.5pt, fill: rgb("#8B0000")))
  cdraw.content((21.6, 2.9), [served at 100], wrap: text.with(size: 6.5pt, fill: rgb("#006400")))
  cdraw.content((12.5, 0.1), [x axis: the nine operations in script order; y axis: largest hole in bytes; the free totals match until op 9], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The windows allocator is the standing counterexample to treating
either policy as the end of the story. Its own page states the
constraint, "Memory allocated by `HeapAlloc` is not movable", the
address "is valid until the memory block is freed or reallocated",
and "Because the system cannot compact a private heap, it can become
fragmented", the same non-compaction that made this section's holes
sticky. Real allocators answer with size classes and lookaside
structures instead of one linear list, glibc's field names alone
disclose the machinery, the man page counts `smblks`, "free fastbin
blocks", separately from ordinary free chunks and `hblks`, "mmapped
regions", and the windows heap "can use the low-fragmentation heap to
reduce heap fragmentation" for workloads "that allocate large amounts
of memory in various allocation sizes". The next section opens the
one real heap this machine owns and looks inside it.

== HeapWalk over a live heap

Windows exposes the enumeration the chapter has been asserting by
hand. `HeapWalk` "Enumerates the memory blocks in the specified heap",
taking a heap handle from `HeapCreate` or `GetProcessHeap` and a
`PROCESS_HEAP_ENTRY` that carries the whole walk state. The protocol
is two sentences: "To initiate a heap enumeration, set the `lpData`
field of the `PROCESS_HEAP_ENTRY` structure pointed to by `lpEntry`
to NULL", and to continue, call again "with no changes to `hHeap`,
`lpEntry`, or any of the members". The end is not a timeout or a
sentinel entry, it is a documented error code: "If the heap
enumeration terminates successfully by reaching the end of the heap,
the function returns FALSE, and GetLastError returns the error code
`ERROR_NO_MORE_ITEMS`." The page also states the cost and the hazard,
enumerating "is a potentially time-consuming operation", and
"HeapWalk can fail in a multithreaded application if the heap is not
locked during the heap enumeration", with `HeapLock` and `HeapUnlock`
named as the guard, and "no enumeration state data is maintained
outside the contents of the `PROCESS_HEAP_ENTRY` structure", so
walking needs no separate close call.

#listing("c-os-cloud/samples/src/Ch14/heapwalk.c", first: 34, last: 41, caption: [the entry protocol: a zeroed entry, a locked heap, nothing else])

#listing("c-os-cloud/samples/src/Ch14/heapwalk.c", first: 42, last: 63, caption: [the loop, the four entry kinds, and the `ERROR_NO_MORE_ITEMS` terminator])

Each entry classifies by `wFlags`: busy entries carry
`PROCESS_HEAP_ENTRY_BUSY` with `cbData` as "the size of the data
portion of the heap element, in bytes", regions open with
`PROCESS_HEAP_REGION`, uncommitted ranges report
`PROCESS_HEAP_UNCOMMITTED_RANGE`, and everything else is a free
block, the same free pool the contract section described. The struct
page adds the depth: "A heap consists of one or more regions of
virtual memory, each with a unique region index", and `cbOverhead`
is "the size of the data used by the system to maintain information
about the heap element", "in addition to the `cbData` bytes", the
real allocator's maintenance made countable, 8 to 32 bytes per block
in the probe below, against the arena allocator's fixed 32.

The discipline the docs demand shapes the helper: between `HeapLock`
and `HeapUnlock` the code only counts, because the lock page is
blunt about what holding it means, "the calling thread owns the heap
lock. Only the calling thread will be able to allocate or release
memory from the heap", and a `printf` between the two would itself
allocate on the process heap. Counts leave the locked region, the
printing happens after. The same page binds the pair, "Each
successful call to `HeapLock` must be matched by a corresponding
call to `HeapUnlock`."

#listing("c-os-cloud/samples/src/Ch14/heapwalk.c", first: 65, last: 88, caption: [the process heap: terminator, region, startup allocations, then one watched block through its life])

The process heap is already busy before `main` runs, and the ucrt
page says why: "The startup code uses `malloc` to allocate storage
for the `_environ`, `envp`, and `argv` variables", with `printf` on
the same caller list. The walk confirms it structurally: a region
entry, busy entries, a termination on `ERROR_NO_MORE_ITEMS`. One
`HeapAlloc` of a watched 777 bytes then makes a block's lifecycle
visible from outside: it appears as exactly one busy entry whose
`cbData` reports 777, the busy count grows, and after `HeapFree` the
match count returns to zero, freed into the free pool where the
page's warning lives, "Calling `HeapFree` twice with the same
pointer can cause heap corruption, resulting in subsequent calls to
`HeapAlloc` returning the same pointer twice", the platform's
phrasing of the 7.24.3.3 undefined behavior.

#listing("c-os-cloud/samples/src/Ch14/heapwalk.c", first: 90, last: 100, caption: [a private heap of three known blocks, this sample is its only allocator])

#listing("c-os-cloud/samples/src/Ch14/heapwalk.c", first: 101, last: 113, caption: [the walks: three busy entries, exact sizes, then one coalesced free])

The private heap is where the enumeration turns exact, because this
sample is its only allocator. `HeapCreate(0, 0, 0)` builds a private
growable heap, growable because "If `dwMaximumSize` is 0, the heap
can grow in size", and lockable because a heap created with
`HEAP_NO_SERIALIZE` "cannot be locked" and this one was not. Three
blocks of 100, 200, and 1000 bytes walk as exactly 3 busy entries
inside 1 region, two consecutive walks of the untouched heap agree
on every count, and `cbData` reports each requested size exactly.
Freeing all three adjacent blocks leaves the walk with zero busy
entries and exactly one free entry, the windows heap coalesced
[4640 + 112 + 208 + 1008 = 5968] bytes into it in the probe run,
the same merge the arena allocator's middle window asserts.
`HeapDestroy` then "de-commits and releases all the pages of
a private heap object", permitted without freeing first, and
forbidden for the process heap handle outright.

The posix counterpart is `mallinfo(3)`, cited here and never
executed, no linux binary stands behind this chapter. The man page
summarizes it as a way to "obtain memory allocation information",
returning a struct of counters, `arena` for non-mmapped space,
`ordblks` for "the number of free chunks", `uordblks` and `fordblks`
for total allocated and free space, the same quantities `HeapWalk`
counts by enumeration. The page's own metadata is the honesty the
walk above earns structurally: its standards field says "None", the
original `mallinfo` is deprecated because its `int` fields wrap,
`mallinfo2` fixed that in glibc 2.33, and even then "Information is
returned for only the main memory allocation area". `HeapWalk`
enumerates whatever heap handle it is given, which is how this
chapter could verify one private heap's numbers exactly.

#diagram([the walk pipeline, lock to unlock, and the cited posix counterpart], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 5.4, 3.6, [HeapLock])
  box(5.0, 5.4, 4.6, [entry zeroed, lpData NULL])
  box(10.4, 5.4, 5.0, [HeapWalk loop: region, busy, free, uncommitted])
  box(16.2, 5.4, 4.4, [FALSE + GetLastError 259])
  box(21.2, 5.4, 3.4, [HeapUnlock])
  cdraw.line((4.2, 5.9), (5.0, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.6, 5.9), (10.4, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 5.9), (16.2, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.6, 5.9), (21.2, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((22.9, 5.35), (22.9, 4.0), stroke: luma(100), mark: (end: ">"))
  box(18.6, 3.0, 5.6, [print the counts, after the lock])
  cdraw.rect((2.0, 1.4), (13.4, 3.0), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((7.7, 2.5), [glibc mallinfo(3), cited, never run], wrap: text.with(size: 6pt))
  cdraw.content((7.7, 1.85), [arena, ordblks, uordblks, fordblks], wrap: text.with(size: 6pt))
  cdraw.content((12.9, 0.5), [count inside the lock, allocate only outside it], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The chapter closes the pipeline it opened with. Chapter 1 built the
gate, chapters 5 and 6 ran its sanitizer legs, and this chapter used
both ends: the contract sections read the standard and the platform
pages, the arena rebuilt the machinery under the checks, and the walk
looked inside a real heap to find the same shapes, headers, free
pools, and coalesced neighbors. The two heaps this machine owns are
not mysterious, they are lists with invariants, and every invariant
named here was asserted green in the gate run this chapter quotes.

sources: learn.microsoft.com, HeapWalk, GetProcessHeap, HeapLock,
HeapCreate, HeapAlloc, HeapFree, HeapDestroy, and `PROCESS_HEAP_ENTRY`
pages, and the ucrt malloc, free, and realloc pages, accessed
2026-09-12; open-std.org n3220 (7.24.3 p1 common rules, 7.24.3.3
free, 7.24.3.4 `free_sized`, 7.24.3.6 malloc, 7.24.3.7 realloc),
accessed 2026-09-12; en.cppreference.com realloc page for the C17
and C23 zero-size timeline, accessed 2026-09-12; man7.org
mallinfo(3), accessed 2026-09-12. The ucrt behavior probes, the
private-heap walk transcript, the `free_sized` compile failure, and
the 5968-byte coalesced free entry are real output from this machine
the same day. Sample behavior verified by `make verify-c`, 61 checks
in chapter 14 of the samples suite.
