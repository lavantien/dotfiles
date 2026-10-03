#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= virtual memory and paging

Chapter 11 built the container and named its second layer a private
virtual address space. This chapter opens that layer. Every address a C
pointer holds is virtual, the number means nothing to dram, and the
system rewrites it on every single memory reference. The plan is four
moves: the mapping fiction that makes one address mean different memory
in different processes, a two-level page table and tlb simulated in
plain c23 with every translation hand computed first, the real
allocator interface `VirtualAlloc` with its staged reserve and commit
asserted through `VirtualQuery`, and the fault counter that prices the
difference between promising memory and touching it. The posix
counterpart `mmap(2)` sits beside the windows material as citation,
never execution: no mmap call runs on this machine in this book. Every
behavioral claim below is one of the 47 checks in the two samples or a
sentence quoted from a canonical page fetched 2026-09-12.

== the mapping fiction

The Memory Management conceptual pages state the fiction in two
sentences. "A virtual address does not represent the actual physical
location of an object in memory; instead, the system maintains a page
table for each process, which is an internal data structure used to
translate virtual addresses into their corresponding physical
addresses. Each time a thread references an address, the system
translates the virtual address to a physical address." The privacy rule
is the same page's opening line: "The address space for each process is
private and cannot be accessed by other processes unless it is shared."
On this machine's x64 target that private space is enormous: the Memory
Limits page gives each 64-bit process 128 TB of user-mode virtual
address space with `LARGEADDRESSAWARE` set, the default, on Windows 8.1
and later.

The unit of translation is the page. `GetSystemInfo` reports the two
sizes this chapter needs, and `SYSTEM_INFO` documents both fields:
`dwPageSize` is "The page size and the granularity of page protection
and commitment. This is the page size used by the VirtualAlloc
function", and `dwAllocationGranularity` is "The granularity for the
starting address at which virtual memory can be allocated." The sample
asserts 4096 and 65536 on this box, probed 2026-09-12. Translation cuts
every address at the page boundary: the low bits of a page never enter
a table, only the page number does.

The simulator shrinks that split to fit in one head, 16 bits instead of
48, pages of 256 bytes instead of 4096:

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 21, last: 30, caption: [the toy address split: 4 bits of level-1 index, 4 of level-2, 8 of offset])

The worked example runs through the whole chapter. Virtual address
`0x1234` is `0001 0010 0011 0100` binary: level-1 index `0x1`,
level-2 index `0x2`, offset `0x34`. If page `0x1200` maps to physical
frame `0x0A`, then `0x1234` translates to `0x0A34`. The offset `0x34`
rides through untouched, and only the page number moves:

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 97, last: 114, caption: [the hand-computed translations, both fault flavors, the untouched offset])

Four checks walk the arithmetic, then the two negative ones mark where
translation stops. An address whose level-1 entry was never mapped
faults. An address whose entry exists but has its present bit cleared
faults too, the level-2 table stands while its entry says no page, and
that is precisely the state a demand-paged page starts in. Both fault
checks assert the stronger fact that no address is delivered at all:
the output variable keeps the `0xFFFF` sentinel the caller planted.

The fiction's sharpest form is one address in two processes. Two `mmu`
instances, two private page tables, the same virtual address, two
different frames. The privacy is what makes identical binaries cheap
to load: a module asks for its preferred base in a fresh process
without consulting any other process, because there is nothing to
consult, every table answers only for its owner. It cuts the other
way too: no process reaches another one's memory by guessing an
address, the number means nothing without the tables that translate
it.

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 116, last: 127, caption: [the same va 0x1234, two processes, two physical frames])

Process a reads `0x0A34`, process b reads `0x0334` from the identical
pointer value, and the check that matters is `pa_a != pa_b`. This is
why every process in chapter 11 could load at the same preferred image
base without colliding, and why two processes can share a physical
page only by the kernel deliberately mapping the same frame into both
tables.

#diagram([from pointer to dram: what each layer owns and who sees it], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (15.6, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((8.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  layer(6.8, [every process: 128 TB of virtual addresses, private], fill: luma(205))
  layer(5.5, [page tables, one set per process, kernel owned])
  layer(4.2, [the tlb: the few hot translations cached on core])
  layer(2.9, [physical memory and the paging file, shared by all])
  layer(1.6, [the mmu walk: address to tlb to tables to frame, every reference], fill: luma(205))
  cdraw.content((18.4, 7.1), [the pointer's number is an index #linebreak() into the owning process's tables], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 4.9), [translation is per process: #linebreak() the same va, different frames], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 2.4), [the walk is hardware speed, #linebreak() faults are the slow path out], wrap: text.with(size: 6pt))
  cdraw.content((8.3, 0.6), [simulated above, asserted through the kernel below], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== page tables and tlbs, simulated

Why two levels instead of one flat table: the address space is sparse.
A flat 16-bit space needs all 256 table entries whether the process
maps 4 pages or 200, and a flat 48-bit space would need half a
terabyte per process. The two-level trick puts a `NULL` where whole
subtrees are unmapped, 15 of the 16 possible first-level entries in
the sample's case, and the walk stops right there.

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 52, last: 66, caption: [map writes a present pte, unmap clears the bit and leaves the table standing])

`map` lazily creates the level-2 table the first time an address
inside it is mapped, which is what a real kernel does when a process
first maps into a fresh 2 MiB extent. `unmap` clears the present bit
only, and the fault check two listings back uses exactly the state it
leaves: table present, entry absent. That is the state hardware hands
the kernel on a demand paging fault, which is where section four picks
the story up.

#diagram([va 0x1234 through the machine: the split, the tlb, both levels, the frame], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.2, 2.6, [l1 index 0x1])
  box(3.8, 6.2, 2.6, [l2 index 0x2])
  box(7.0, 6.2, 3.0, [offset 0x34])
  cdraw.content((5.6, 7.7), [va 0x1234, split once at the page boundary], wrap: text.with(size: 6.5pt))
  box(0.6, 4.4, 3.6, [level-1 table, #linebreak() entry 1])
  box(5.0, 4.4, 4.4, [level-2 table, #linebreak() entry 2, present])
  box(11.4, 4.4, 4.2, [the tlb, first stop, #linebreak() 4 direct slots], fill: luma(205))
  box(5.0, 2.6, 4.4, [pte: frame 0x0A, #linebreak() present bit set])
  box(0.6, 0.8, 5.6, [pa 0x0A34 = frame 0x0A + offset 0x34], fill: luma(205))
  cdraw.line((1.9, 6.2), (1.9, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.2, 4.9), (5.0, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.2, 4.4), (7.2, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.0, 3.1), (3.4, 1.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.5, 6.2), (11.4, 5.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((13.5, 3.4), [hit: answers alone, #linebreak() miss: fall through to the walk], wrap: text.with(size: 6pt))
  cdraw.content((18.6, 6.6), [the offset never enters #linebreak() a table, asserted twice], wrap: text.with(size: 6pt))
  cdraw.content((18.6, 3.0), [a miss costs 2 reads here, #linebreak() 4 levels on real x64], wrap: text.with(size: 6pt))
})

The walk order is the whole point. The tlb is checked first and
answers without touching a single table, the hit path returns in three
lines. A miss pays two table reads in this toy, one per level, both
from memory, both counted. A faulting lookup pays the same two reads
and delivers nothing: `*pa` is only written on the success paths, so
the caller's sentinel survives the fault. The fill path installs the
translation it just walked so the next reference to the page hits:

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 68, last: 90, caption: [one translation: tlb first, then the two-level walk, never both])

The fixed trace runs seven accesses and every verdict was computed by
hand before the loop ran:

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 129, last: 147, caption: [the trace table: va, expected verdict, expected pa, hand computed first])

Two rows of the table are teaching moments the loop then proves. Vpn
`0x88` and vpn `0x34` share tlb slot 0, because the slot index is the
vpn's low two bits and both values are multiples of 4, so the fifth
access evicts the third's translation. The seventh access, a repeat of
the third, then misses an address that was already cached once: a
direct-mapped conflict turned a warm page cold. Real tlbs are set
associative precisely to soften this, but the eviction math is the
same arithmetic with a wider slot.

#listing("c-os-cloud/samples/src/Ch12/pagetable.c", first: 148, last: 168, caption: [the loop scores the trace: 4 fills, 2 hits, 1 fault, 10 table reads])

The counters come out exactly as the comment table predicts: 4 fills,
2 hits, 1 fault, and 10 table reads, two for each of the 5 non-hits.
The two hits are the entire economic argument for the tlb: they
skipped 4 table reads that the walk would otherwise have paid. On real
hardware the same argument is louder in both directions, the walk is
four levels deep on x64, and the tlb covers a handful of entries per
core with a second larger shared level beside it.

#callout("note", "a model, not a cycle counter", [
  The simulator gets the order of operations right, tlb, then tables,
  then fault, and the arithmetic exact, because the trace is fixed and
  the classification was done by hand. It simplifies everything else:
  real x64 page tables are four levels with 512 entries per level, the
  tlb is set associative and split across core levels, table reads go
  through their own paging-structure caches, and the pte carries
  dirty, accessed, and protection bits this model folds away. What
  transfers is the shape: the hit is cheap because it skips the walk,
  and the fault is expensive because it leaves the hardware entirely.
])

== virtualalloc versus mmap

The windows allocator interface is one function with a state machine
inside. `VirtualAlloc` "Reserves, commits, or changes the state of a
region of pages in the virtual address space of the calling process",
and its two allocation flags are the two halves of the staging.
`MEM_RESERVE` "Reserves a range of the process's virtual address space
without allocating any actual physical storage in memory or in the
paging file on disk." `MEM_COMMIT` "Allocates memory charges (from the
overall size of memory and the paging files on disk) for the specified
reserved memory pages", and the same paragraph carries the promise
this chapter keeps returning to: "Actual physical pages are not
allocated unless/until the virtual addresses are actually accessed."
The remarks section names the pattern directly: "You can use
VirtualAlloc to reserve a block of pages and then make additional
calls to VirtualAlloc to commit individual pages from the reserved
block. This enables a process to reserve a range of its virtual
address space without consuming physical storage until it is needed."

The sample reads every step back through `VirtualQuery`, whose
contract is a region definition: it reports "a region of consecutive
pages beginning at a specified address" sharing state, original
allocation, and protection, stopping at the first page that
disagrees. The two size probes come first:

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 29, last: 51, caption: [the readback helpers: fault counter, commit charge, page states, and the two granularities])

The `PSAPI_VERSION 2` define is a documented remap, worth one sentence
because it explains why the gate's `-lkernel32` is enough: "If
PSAPI_VERSION is 2 or greater, this function is defined as
K32GetProcessMemoryInfo in Psapi.h and exported in Kernel32.lib and
Kernel32.dll." `PagefileUsage` is the commit charge, "The Commit
Charge value in bytes for this process", the meter that shows reserve
and commit are different events.

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 56, last: 74, caption: [stage 1, reserve five pages: exact size, 64 KiB aligned base, zero charge])

Two of these checks corrected the draft and are labeled probed for it.
The reservation comes back exactly 20480 bytes, `dwSize` rounded up to
the page boundary and no further, while the 64 KiB allocation
granularity governs only where the base lands, `base mod 65536 == 0`.
The draft assumed reservations snap to whole 64 KiB units. They do
not, and neither do the docs say they should: the rounding rule is
"rounded up to the next page boundary", the granularity rule is about
addresses. The second surprise waits in stage eight. The commit charge
check is the documented one: reserve charges nothing, the page tables
behind it cost kernel memory but no promise of backing storage.

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 76, last: 89, caption: [stage 2, one committed page splits the region in two])

Committing page two of five splits what was one region into two
answers. The query at the base now reports `MEM_RESERVE` for exactly
4096 bytes, one page, because page two no longer matches its state.
The query one page over reports `MEM_COMMIT`, `PAGE_READWRITE`, one
page, and both halves still report the same `AllocationBase`, the
original reserve. The `MEMORY_BASIC_INFORMATION` page documents the
three states in exactly these words: committed pages are those "for
which physical storage has been allocated, either in memory or in the
paging file on disk", reserved pages are "reserved without any
physical storage being allocated", and for reserved pages "the
information in the Protect member is undefined", which is why the
sample never asserts `Protect` on a reserve.

The free side of the state machine is `VirtualFree`, and its trap is
best read straight off the listing that springs it:

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 126, last: 139, caption: [stage 7, the failed partial release, the free run that merges with its neighbors])

#callout("pitfall", "release owns the whole region or fails", [
  The VirtualFree page is categorical: "If you specify this value,
  dwSize must be 0 (zero), and lpAddress must point to the base
  address returned by the VirtualAlloc function when the region is
  reserved. The function fails if either of these conditions is not
  met." There is no partial release of one reservation, the page says
  elsewhere that "The entire range of pages originally reserved by
  the VirtualAlloc function must be released at the same time", and
  committed pages ride along: "If any pages in the region are
  committed currently, the function first decommits, and then
  releases them." The sample asserts the failure, probed as
  `ERROR_INVALID_PARAMETER`, and then the release.
])

After the release the query reports `MEM_FREE` and a `RegionSize`
larger than the reservation on every run observed, because free pages
merge with adjacent free address space into one long run. The
VirtualQuery remarks give this exact example: "if there is a 40
megabyte (MB) region of free memory, and VirtualQuery is called on a
page that is 10 MB into the region, the function will obtain a state
of MEM_FREE and a size of 30 MB." The check therefore asserts state
and a lower bound, and prints the run it saw.

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 141, last: 153, caption: [stage 8, the one-shot reserve plus commit of the malloc shape])

The one-shot `MEM_COMMIT | MEM_RESERVE` is what every higher
allocator, `malloc` included, ultimately does for large blocks, and
the probe result is the chapter's second surprise: committing one page
this way commits exactly one page. The rest of the 64 KiB granularity
unit the base sits in stays free, the query at `one + 4096` says so,
and the reservation is one page deep. The fusion is total: there is no
state between the reservation and the commitment, and the release
side is one call with `dwSize` zero.

The posix counterpart is one call that fuses both stages by design.
`mmap(2)` with `MAP_ANONYMOUS`: "The mapping is not backed by any
file; its contents are initialized to zero." The commit discipline
that windows splits into two calls is a kernel accounting question
inside posix, surfaced only through the `MAP_NORESERVE` flag, "Do not
reserve swap space for this mapping", the closest thing to refusing
the promise. Alignment differs the same direction as the granularity
findings: munmap "deletes the mappings for the specified address
range" and "The address addr must be a multiple of the page size (but
length need not be)", where windows requires the release base to be
the allocation base and rounds nothing on the way out. None of it runs
here: the posix pages are citations, the windows behavior is checked.

#diagram([the same ladder on two systems: windows names each rung, mmap fuses them], length: 13pt, {
  let col(x, title) = {
    cdraw.rect((x, 6.5), (x + 9.8, 7.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + 4.9, 7.05), title, wrap: text.with(size: 6.5pt))
    cdraw.rect((x, 4.6), (x + 9.8, 6.3), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 2.7), (x + 9.8, 4.4), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 0.8), (x + 9.8, 2.5), fill: luma(235), radius: 0.02)
  }
  col(0.6, [windows: VirtualAlloc, staged])
  cdraw.content((5.5, 5.85), [MEM\_RESERVE: address range held,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 5.25), [no storage, no charge, PAGE\_NOACCESS], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.95), [MEM\_COMMIT: charge from ram + paging,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.35), [file, contents zero, pages still absent], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 2.05), [first touch: page materializes,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 1.45), [the only step that faults], wrap: text.with(size: 6pt))
  col(13.2, [posix: mmap(2), fused])
  cdraw.content((18.1, 5.85), [MAP\_ANONYMOUS: one call, zero,], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 5.25), [not backed by any file], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.95), [reserve and commit are kernel,], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.35), [accounting, MAP\_NORESERVE the only knob], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 2.05), [first touch faults the same way,], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 1.45), [munmap deletes the whole range], wrap: text.with(size: 6pt))
  cdraw.content((11.8, -0.5), [both ladders charge the bill at the bottom rung: the touch, not the call], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== demand paging and fault cost

The Page State page compresses this section into one sentence: "The
system initializes and loads each committed page into physical memory
only during the first attempt to read or write to that page." Commit
is a promise, first touch is the bill, and the sample counts both
sides with two different meters. The commit charge rises the moment
`MEM_COMMIT` succeeds. The fault counter does not move at all until
the store lands:

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 91, last: 109, caption: [stages 3 and 4: one store one fault, warm pages free, three pages three faults])

`PageFaultCount` is documented in one flat line, "The number of page
faults", and the exact-delta checks hold on every run observed,
2026-09-12, three direct runs plus two gate legs. The first store
faults exactly once. The read-back from the warm page faults zero
times, the `volatile` qualifiers keep the compiler from collapsing
either access into nothing, and the ir gate leg pins what survives
optimization: at -O1 the first-touch store emits as
`store atomic volatile`, volatile lowered to an atomic-order access
on this target, and the substring assertion in `expect-ir.txt` holds
it there. Three more committed pages touched once each cost exactly
three faults. The commits themselves, seconds earlier in the same
run, cost zero.

The decommit half of `VirtualFree` is the promise being withdrawn.
Its page: "Decommits the specified region of committed pages. After
the operation, the pages are in the reserved state", and "Decommitting
a page releases its physical storage, either in memory or in the
paging file on disk." The memory is gone with the promise, the same
page's warning that "After memory is released or decommited, you can
never refer to the memory again", and the sample relearns the price
on purpose:

#listing("c-os-cloud/samples/src/Ch12/valloc.c", first: 111, last: 124, caption: [stages 5 and 6: decommit returns storage, recommit buys the fault again])

The address never changed. The decommitted page reads `MEM_RESERVE`,
the charge drops a page, and the recommit of the same address starts
the promise over from zero: the next store faults exactly once again,
asserted. A decommitted page is not slow memory, it is absent memory,
and the access violation sentences in the docs draw the hard edge:
"Attempts to read from or write to a reserved page results in an
access violation exception", and for free pages, "Attempting to read
from or write to a free page results in an access violation
exception." The book's rule from chapter 5 applies verbatim: the crash
is cited, never executed.

#callout("note", "windows counts one number, posix splits it in two", [
  `PageFaultCount` lumps every fault together. The posix accounting
  vocabulary is finer, and the man page for `getrusage(2)` defines the
  split: `ru_minflt` is "The number of page faults serviced without
  any I/O activity", pages reclaimed from memory, and `ru_majflt` is
  "The number of page faults serviced that required I/O activity",
  pages that had to come back from disk. Every fault this chapter's
  sample manufactures is minor, demand-zero pages materialized from
  nothing, no disk anywhere. The first major fault in a process is a
  different chapter's event: it is what happens when the working set
  loses an argument with physical memory.
])

#diagram([cumulative faults across the sample's lifetime: flat through reserve and commit, one step per first touch], length: 13pt, {
  // x: the sample's events in order, y: cumulative fault count
  let evx = (0.8, 3.2, 5.6, 8.0, 10.4, 12.8, 15.2, 17.6, 20.0)
  // reserve, commit 4, touch 1..4, decommit, recommit, touch again
  let ys = (2.2, 2.2, 3.1, 4.0, 4.9, 5.8, 5.8, 5.8, 6.7)
  cdraw.line((0.6, 1.0), (21.4, 1.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((0.6, 1.0), (0.6, 7.1), stroke: luma(100), mark: (end: ">"))
  for k in range(1, 6) {
    let yy = 2.2 + (k - 1) * 0.9
    cdraw.line((0.48, yy), (0.6, yy), stroke: luma(100))
    cdraw.content((-0.55, yy), [#k], wrap: text.with(size: 6pt))
  }
  // the promise segment: reserve, then commit, zero faults
  cdraw.line((evx.at(0), ys.at(0)), (evx.at(1), ys.at(1)), stroke: (paint: luma(140), dash: "dashed"))
  for i in range(1, evx.len() - 1) {
    cdraw.line((evx.at(i), ys.at(i)), (evx.at(i + 1), ys.at(i + 1)), stroke: luma(60))
  }
  for i in range(evx.len()) {
    cdraw.circle((evx.at(i), ys.at(i)), radius: 0.09, fill: luma(60))
  }
  cdraw.content((1.8, 0.55), [reserve], wrap: text.with(size: 6pt))
  cdraw.content((4.4, 0.55), [commit 4], wrap: text.with(size: 6pt))
  cdraw.content((10.4, 0.55), [touch 1, 2, 3, 4], wrap: text.with(size: 6pt))
  cdraw.content((16.2, 0.55), [decommit, recommit], wrap: text.with(size: 6pt))
  cdraw.content((19.9, 0.55), [touch], wrap: text.with(size: 6pt))
  cdraw.content((4.6, 1.5), [the promise costs nothing], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((14.4, 6.4), [one fault per first touch, asserted exact], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The working set, the pages currently resident in physical memory, reads
the same story from the other side:
`WorkingSetSize`, "The current working set size, in bytes", is printed
by the sample's closing line, never asserted, because the process's
other pages make it drift between runs. The fault counts do not drift,
and that is why they carry the checks. Chapter 13 takes the next step
down this same staircase: once a page is resident, the cost of
touching it stops being a fault and becomes the cache line traffic
the next chapter counts. The allocator that sits on top of this
layer, the one `malloc` really calls, is chapter 14's subject.

sources: learn.microsoft.com, VirtualAlloc, VirtualFree, VirtualQuery,
`MEMORY_BASIC_INFORMATION`, GetSystemInfo and `SYSTEM_INFO`,
GetProcessMemoryInfo and `PROCESS_MEMORY_COUNTERS`, Virtual Address
Space, Virtual Address Space in 64-bit Windows, Memory Limits for
Windows Releases, and Page State pages, accessed 2026-09-12;
man7.org mmap(2) and getrusage(2), accessed 2026-09-12, cited only,
never executed; the 4096 and 65536 granularities, the exact 5-page
reservation, the one-page one-shot commit, the merged free run, the
`ERROR_INVALID_PARAMETER` on partial release, and the exact per-touch
fault deltas probed on this machine the same day, three direct runs
plus two gate legs. Sample behavior verified by `make verify-c`, 47
checks in chapter 12 of the samples suite.
