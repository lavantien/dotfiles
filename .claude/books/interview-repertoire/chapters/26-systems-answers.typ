#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= systems and runtime answers

The runtime round asks what the machine is doing under the code:
where the bytes live, who translates an address, what a context
switch pays, and how one thread talks to ten thousand sockets.
The honest version of every answer here is the one you can say in
three sentences and then defend, and the floor is the c manual,
whose chapters run the real allocators, the real page tables, and
a real socket server under gates. No new code rides with this
chapter: it is the spoken layer, answer, follow-up, floor.

== stack, heap, and allocators [DRILL]

What lives where: locals, arguments, and return addresses live on
the stack, one frame per call, and the frame dies with the return.
Anything whose lifetime must outlive the call that made it goes
to the heap, and the heap knows nothing about calls.

Why the stack is fast and bounded: pushing a frame moves one
pointer, the return frees it by moving the pointer back, the
frames sit contiguous so the hot edge stays in cache, and there
is nothing to search. The price of the speed is the bound, fixed
at thread creation, and recursion past that bound is the stack
overflow, the error to name before the interviewer does.

What the allocator does with a `malloc`: it walks its bins or
free lists for a block that fits, splits off the loose tail,
stamps the size and state into the block header, and returns a
pointer to the interior. A `free` writes the block back into a
bin and coalesces it with free neighbors. The follow-up is
fragmentation, and it has two faces: external, where the free
bytes exist but no contiguous run is large enough for the next
request, and internal, where size-class rounding leaves slack
inside every returned block. Both faces are the argument for
arenas and pools, and the gated implementations floor to
#xref-to("c-os-cloud", "heap") and #xref-to("c-os-cloud",
"allocators").

#diagram([the stack bumps and dies with the return, the heap waits for the free], length: 13pt, {
  // one frame and the bump on the left, a live block and a hole on the right
  cdraw.content((3.4, 6.6), [the stack], size: 6pt)
  cdraw.rect((1.0, 5.3), (5.8, 6.3), fill: luma(230), stroke: luma(120), radius: 0.02)
  cdraw.content((3.4, 5.8), [frame: locals, return], size: 6pt)
  cdraw.content((3.4, 4.7), [one pointer bumps down and back], size: 6pt)
  cdraw.line((5.8, 5.8), (11.6, 5.8), stroke: luma(150), mark: (end: ">"))
  cdraw.content((8.6, 6.2), [a pointer escapes the frame], size: 6pt)
  cdraw.content((16.4, 6.6), [the heap], size: 6pt)
  cdraw.rect((12.0, 5.3), (20.8, 6.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.4, 5.8), [a live block, header stamped], size: 6pt)
  cdraw.rect((12.0, 4.0), (20.8, 5.0), fill: luma(252), stroke: luma(120), radius: 0.02)
  cdraw.content((16.4, 4.5), [a hole, coalesced with a neighbor], size: 6pt)
  cdraw.content((11.6, 3.0), [external: no run big enough, internal: slack inside], size: 6pt)
})

== virtual memory, pages, and the tlb [DRILL]

Every address a program touches is virtual, and the mmu translates
it page by page, the textbook 4kb split of an address into a page
number and an offset that never gets translated. The tlb is the
cache of translations: a hit answers with no walk at all, a miss
walks the page tables in memory, and that walk is the cost the
tlb exists to skip, which is why locality of access pays twice,
once in the cache and once in the tlb.

A page fault is not an error, and saying so plainly is the point
of the question. The fault says the page is mapped but not
resident: the kernel reads it in from the file or the swap, maps
the zero page for fresh anonymous memory, or resolves a
copy-on-write, then restarts the instruction that faulted, and
the program never knows it happened. The error case is the fault
on an address with no valid mapping behind it, that is the
segfault. The follow-up to expect is copy-on-write: a `fork`
shares the parent's frames read-only, and the write fault is what
finally copies a frame, which is why fork can be cheap and the
first write after it is not. The gated implementation floors to
#xref-to("c-os-cloud", "virtualmemory").

#diagram([a page number through the tables to a frame, the tlb skipping the walk], length: 13pt, {
  // the translation path on top, the fault detour and the segfault line below
  cdraw.rect((0.5, 4.6), (5.3, 6.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((2.9, 5.9), [virtual address], size: 6pt)
  cdraw.content((2.9, 5.0), [page number + offset], size: 6pt)
  cdraw.line((5.5, 5.5), (7.3, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.5, 4.6), (13.3, 6.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((10.4, 5.9), [the page tables], size: 6pt)
  cdraw.content((10.4, 5.0), [walked on a miss], size: 6pt)
  cdraw.rect((7.5, 7.0), (13.3, 8.4), fill: luma(228), stroke: luma(120), radius: 0.02)
  cdraw.content((10.4, 8.0), [the tlb], size: 6pt)
  cdraw.content((10.4, 7.3), [translations, cached], size: 6pt)
  cdraw.line((7.4, 7.7), (5.4, 6.5), stroke: luma(150), mark: (end: ">"))
  cdraw.line((13.5, 5.5), (15.3, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.5, 4.6), (21.5, 6.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((18.5, 5.5), [a frame, offset unchanged], size: 6pt)
  cdraw.line((10.4, 4.6), (10.4, 3.4), stroke: luma(150), mark: (end: ">"))
  cdraw.content((10.4, 2.9), [mapped, not resident: read it in, restart], size: 6pt)
  cdraw.content((10.4, 1.8), [no mapping behind it: the segfault], size: 6pt)
})

== processes versus threads [DRILL]

A process owns an address space, the page tables behind it, and a
file descriptor table, and the isolation is the point: one
process crashing leaves its neighbors standing. A thread owns a
stack and a register set and shares everything else with its
siblings, the heap, the code, the descriptors, which is why
threads are cheap to talk through and cheap to corrupt, and why
locks exist at all.

What a scheduler actually switches: the general registers, the
program counter, the stack pointer, and the floating point state,
and that is the whole of a thread switch. A switch between
processes additionally swaps the page tables, and that swap taxes
the tlb, which is why a process switch costs more, while two
threads of one process need no swap because they already share
the tables. State the trade and stop: threads buy cheaper
switches and pay in races, processes buy isolation and pay the
page-table swap, and the everyday example of the second is the
browser keeping each tab in its own process. The gated chapters
are #xref-to("c-os-cloud", "processes"),
#xref-to("c-os-cloud", "threads"), and
#xref-to("c-os-cloud", "scheduling").

#diagram([two private address spaces beside one space with three stacks in it], length: 13pt, {
  // two isolated rows on the left, three stacks over one shared space on the right
  cdraw.content((5.5, 8.8), [two processes], size: 6pt)
  cdraw.rect((1.0, 7.2), (9.9, 8.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.5, 7.8), [process a: private space, page tables], size: 6pt)
  cdraw.rect((1.0, 5.6), (9.9, 6.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.5, 6.2), [process b: a crash stays inside], size: 6pt)
  cdraw.content((17.5, 8.8), [one process, three threads], size: 6pt)
  for x in (13.1, 16.9, 20.7) {
    cdraw.rect((x - 1.5, 6.9), (x + 1.5, 8.1), fill: luma(252), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 7.5), [stack, regs], size: 6pt)
  }
  cdraw.rect((11.6, 5.6), (22.0, 6.6), fill: luma(228), stroke: luma(120), radius: 0.02)
  cdraw.content((16.8, 6.1), [shared: heap, code, descriptors], size: 6pt)
  cdraw.content((11.4, 4.6), [a thread switch swaps registers, a process swap retires the tlb too], size: 6pt)
})

== epoll and the event loop [DRILL]

The readiness model: instead of parking one thread per socket,
register every descriptor with the kernel once, then wait on the
ready list. `epoll_wait` returns exactly the descriptors that can
be read or written now, and the loop services those and waits
again, so ten thousand open connections ride one thread and one
stack.

Level versus edge triggered, the fork the follow-up probes: level
reports a descriptor ready for as long as data remains, so a
partial read is fine, the next wait reports it again. Edge
reports the state change once, so the handler must drain until
the read comes back empty or the remainder sits unread behind a
notification already spent.

The contrast to draw on purpose is the javascript loop of
#xref-to("repertoire", "js-core"), the same single-threaded
discipline at a different layer. There the queue is the runtime's
own, one call stack, the microtask queue drained to empty after
every macrotask turn, timers waiting for a macrotask slot, and it
schedules language jobs. Epoll schedules descriptors, and node's
loop is the second wearing the first's clothes, the poll phase
feeding the queues the language drains. The go answer hides the
loop entirely, the netpoller parking a goroutine on the socket
and the scheduler waking it, which is why
#xref-to("repertoire", "go-runtime") hands you blocking reads and
still runs thousands of goroutines. The loop itself is gated in
#xref-to("c-os-cloud", "async").

#diagram([descriptors registered once, the ready list returned, the loop drains it], length: 13pt, {
  // interest list into the kernel, ready list out, the trigger fork under it
  cdraw.rect((0.5, 6.6), (6.3, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.4, 7.9), [the descriptors], size: 6pt)
  cdraw.content((3.4, 7.1), [registered once], size: 6pt)
  cdraw.line((6.5, 7.5), (8.3, 7.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.5, 6.6), (14.3, 8.4), fill: luma(228), stroke: luma(120), radius: 0.02)
  cdraw.content((11.4, 7.9), [the kernel], size: 6pt)
  cdraw.content((11.4, 7.1), [interest list, ready list], size: 6pt)
  cdraw.line((14.5, 7.5), (16.3, 7.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.5, 6.6), (22.5, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((19.5, 7.9), [the ready set], size: 6pt)
  cdraw.content((19.5, 7.1), [service only these], size: 6pt)
  cdraw.line((19.5, 6.6), (19.5, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.5, 5.3), [the loop, one thread, one stack], size: 6pt)
  cdraw.content((11.4, 4.2), [level: still readable, reported again each wait], size: 6pt)
  cdraw.content((11.4, 3.1), [edge: reported once, drain or lose the rest], size: 6pt)
  cdraw.content((11.4, 1.9), [js, ch07: one call stack, microtasks drained per turn], size: 6pt)
})

#callout("pitfall", "the edge-triggered drain rule", [
  Under edge-triggered epoll a descriptor reports its state change
  once. Read part of the buffer, return to the wait, and the rest
  of that buffer never reports again: no new state change occurs,
  so the connection hangs with bytes waiting in the kernel. The
  rule is to loop the read until it returns short or empty, and
  the same discipline covers writes, which block whenever the
  socket's send buffer fills. This is the lost-wakeup class, one
  notification spent on work only partially done.
])

== c networking, sockets end to end [DRILL]

The ladder in call order: `socket` creates the endpoint and
returns a descriptor, `bind` pins the local address and port,
`listen` marks the endpoint passive and sizes the accept queue,
`accept` pops the next completed connection as a new descriptor,
and `connect` is the client's half of the same handshake. The
descriptor `accept` returns is not the listener, it is one
connection's private endpoint, and conflating the two is the
first bug this round checks for.

What blocking means: a read on a socket with no data yet parks
the calling thread until data arrives, so the naive server shape
is one thread per connection, each thread mostly asleep while
holding a whole stack. Scale the connections and the stacks and
the scheduler sweeping them are the wall, long before the cpu
is. The readiness loop breaks the shape: register the listener
and every accepted socket, one `epoll_wait` returns the ready
set, and the single loop accepts, reads, and writes only what is
ready, so one stack serves every connection. Two gotchas worth
volunteering before being asked: the send side blocks on a full
socket buffer exactly as the receive side blocks on an empty one,
and every descriptor `accept` returns must join the interest set
before the next wait or its first bytes sit unwatched. The c
manual runs both shapes under gates,
#xref-to("c-os-cloud", "http-kernel") with a fixed thread pool
and a stated reason for skipping the loop, and the event loop
itself in #xref-to("c-os-cloud", "async").

#diagram([socket, bind, listen, accept, connect, then the two shapes over the connections], length: 13pt, {
  // the ladder across the top, the two io shapes under it
  let rung(x0, name, sub) = {
    cdraw.rect((x0, 6.6), (x0 + 4.0, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.0, 7.9), [#name], size: 6pt)
    cdraw.content((x0 + 2.0, 7.1), [#sub], size: 6pt)
  }
  rung(0.4, "socket", "an endpoint fd")
  rung(5.0, "bind", "address, port")
  rung(9.6, "listen", "passive, queued")
  rung(14.2, "accept", "a new fd per peer")
  rung(18.8, "connect", "the client half")
  for x in (4.4, 9.0, 13.6, 18.2) {
    cdraw.line((x, 7.5), (x + 0.6, 7.5), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.rect((1.0, 3.8), (11.2, 5.6), fill: luma(252), stroke: luma(120), radius: 0.02)
  cdraw.content((6.1, 5.0), [blocking: a parked read per peer], size: 6pt)
  cdraw.content((6.1, 4.2), [one stack per connection], size: 6pt)
  cdraw.rect((12.4, 3.8), (22.6, 5.6), fill: luma(228), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 5.0), [readiness: one wait over every fd], size: 6pt)
  cdraw.content((17.5, 4.2), [one stack, every connection], size: 6pt)
  cdraw.content((11.8, 2.6), [the loop trades parked stacks for one ready list], size: 6pt)
})

floored to the gated implementations of the c manual:
#xref-to("c-os-cloud", "heap") and
#xref-to("c-os-cloud", "allocators") for the stack and heap
answers, #xref-to("c-os-cloud", "virtualmemory") for paging and
the tlb, #xref-to("c-os-cloud", "processes"),
#xref-to("c-os-cloud", "threads"), and
#xref-to("c-os-cloud", "scheduling") for the switch, and
#xref-to("c-os-cloud", "async") with
#xref-to("c-os-cloud", "http-kernel") for the loop and the
sockets, all under `make verify`.
