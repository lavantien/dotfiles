#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= asynchronous patterns in c

Chapter 15 bought parallelism with coordination: every worker needed a
lock, and chapter 16 made the fast paths lock free. Asynchronous io buys
concurrency the other way, one thread, no waiting, the operating system
holding the pending work and handing back completions in order. The
machinery is built from three pieces this chapter assembles in sequence:
the callback, the unit of exchange; the event loop, the discipline that
drives it; and the completion port, the kernel doing the loop's queueing
for real. Every behavioral claim below is a CHECK in the three samples,
68 in total, or a sentence quoted from a canonical page fetched
2026-09-12. The linux counterparts, `epoll` and `io_uring`, are cited
from man7 and never executed on this windows box, the same treatment
chapter 11 gave `fork`.

== callbacks and ownership

Every asynchronous api in c is a variation on one registration: a
function pointer plus a context pointer. Chapter 6 already passed this
shape to `qsort_s`, whose comparator receives the caller's context
pointer instead of reaching for a global, and chapter 15 passed it to
`thrd_create`, whose `thrd_start_t` is spelled `int (*)(void*)`. The
function is the work. The context pointer is the answer to the question
every registration forces: when the callback finally runs, whose data
does it see, and who owns that data? An api that does not answer that
question in writing is an api with a leak or a use-after-free waiting
in it.

The registry below answers it explicitly, in one sentence of contract:
the registry stores the context pointer, calls through it, and never
frees it. The data model is 4 fields per slot:

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 25, last: 35, caption: [the registry's data model: a function, a context pointer, an id, a liveness bit])

The `id` is assigned at registration and never reused, which is what
makes dispatch order well defined once slots start being recycled. The
unregister side is where ownership is decided, and this registry decides
it by doing nothing:

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 63, last: 74, caption: [unregister takes the id and never the memory: ownership stays where it was])

No `free`, no destructor hook, no reference count. Three ownership
regimes ride through this one contract unchanged. Static storage
outlives the registry by construction. Heap storage is freed by the
caller, once, on the caller's schedule. The null context needs nothing
at all, and is a legal registration, not a special case to guard
against. The dispatch side has one hazard of its own, calling user code
while walking the registry, and the walk is built for it:

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 76, last: 92, caption: [dispatch walks registration ids, so slot reuse never reorders, and a self-unregister mid-walk is safe])

The outer loop climbs ids, not slot indexes, so a slot freed and reused
keeps its place in line by its original id, and liveness is re-read
inside the walk, so a callback that removes itself mid-dispatch has run
exactly once by the time the walk passes its id again. The same
function registered twice with two contexts demonstrates what the
context pointer is for, no shared state between the two answers:

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 94, last: 108, caption: [the context pointer is the channel: one function, two thresholds, two answers])

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 129, last: 146, caption: [regime 1, static contexts: dispatch order, both results, and the null context asserted exactly])

The samples array is fixed, the arithmetic is countable, and the checks
land on exact numbers: over a threshold of 10 the six samples score 3
hits, over 20 they score 2, the same function both times. The heap
regime then proves the contract the only way it can be proven without
an allocator audit, by surviving:

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 154, last: 166, caption: [regime 2, caller-owned heap: the sentinel is intact after unregister, then the owner frees once])

The heap context registers, fires once, unregisters, and is still
readable afterwards, hits 3 and threshold 15 untouched, which is only
possible if unregister neither freed it nor scribbled it. Then the
owner frees it exactly once. The self-unregistering callback closes the
section on the mid-walk hazard:

#listing("c-os-cloud/samples/src/Ch18/callbacks.c", first: 168, last: 178, caption: [the callback that unregisters itself: it runs once, the next fire skips it])

Its context is a pointer to storage holding the registration id, and
the id is written into that storage after `register_cb` returns, which
is itself a proof: the registry stored the pointer, not a copy of what
it pointed at. Five fires into the file the survivor totals are exact,
the marker has dispatched 5 times and the high threshold has
accumulated 10 hits, 2 per fire, 5 fires.

#diagram([the registry as a data structure: three ownership regimes feeding one slot array, one dispatch path], length: 13pt, {
  let regime(y, t) = {
    cdraw.rect((0.6, y), (8.2, y + 1.3), fill: luma(235), radius: 0.02)
    cdraw.content((4.4, y + 0.65), t, wrap: text.with(size: 6pt))
  }
  regime(6.2, [static storage: outlives #linebreak() the registry itself])
  regime(4.5, [caller heap: freed once #linebreak() by its owner, later])
  regime(2.8, [null context: registered #linebreak() without state, fires])
  let slot(y, t) = {
    cdraw.rect((9.6, y), (17.0, y + 1.3), fill: luma(215), radius: 0.02)
    cdraw.content((13.3, y + 0.65), t, wrap: text.with(size: 6pt))
  }
  slot(6.2, [slot: fn, ctx, id, live])
  slot(4.5, [slot: fn, ctx, id, live])
  slot(2.8, [slot: fn, ctx, id, live])
  cdraw.line((7.4, 6.85), (9.6, 6.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.4, 5.15), (9.6, 5.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.4, 3.45), (9.6, 3.45), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.8, 7.5), [ctx, by pointer], wrap: text.with(size: 6pt))
  cdraw.rect((18.8, 4.4), (25.4, 6.3), fill: luma(205), radius: 0.02)
  cdraw.content((22.1, 5.35), [fire(): ids ascending, #linebreak() fn(ctx) per live slot], wrap: text.with(size: 6pt))
  cdraw.line((17.0, 5.35), (18.8, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.3, 1.4), [the registry never frees ctx: the contract every async api states, here in unregister], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== an event loop from scratch

A registry full of callbacks needs a driver, and the driver is the
event loop: one thread, one queue of timed work, one loop that drains
what is due. The sample loop owns two structures and one rule. The
timer queue holds what to do later. The ready list holds what to do
now. The rule, work scheduled during a dispatch waits for the next
tick's collection pass, is what keeps every dispatch finite even when a
handler schedules more work. The whole file is deterministic by
construction: time is a `uint64_t` the tick function itself advances by
a fixed 10 ms, no wall clock exists anywhere in it, so fire counts and
fire order are asserted exactly.

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 27, last: 35, caption: [one timer: absolute deadline, period, handler, caller-owned context, two flags])

The two flags carry the whole dispatch discipline. `live` says the
timer sits on the queue. `armed` says it has been collected into the
current tick's ready list and is owed a dispatch, which is a different
state entirely: a collected one-shot is already off the queue, but its
callback has not run yet. One tick is three phases:

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 110, last: 123, caption: [collection: the earliest expired deadline moves to the ready list, ties by registration order])

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 125, last: 135, caption: [the two arms: repeating requeues at deadline plus period, one-shot collection is the dequeue])

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 138, last: 155, caption: [dispatch runs the frozen ready list; the armed flag is the handshake with cancel])

The run then plays the whole instrument. Six timers: one-shots at 30,
10, 50, and 60 ms, a deliberate tie at 30 ms, and a repeating timer
every 40 ms starting at 40. One of them is canceled before it can fire.
Ten ticks move the clock to 100:

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 180, last: 195, caption: [the job set, one cancel, ten ticks of virtual time])

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 197, last: 211, caption: [the verdict: fire log and fire tick arrays compared byte for byte])

The expected log reads B at tick 1, its delay-0 child Z at tick 2, the
30 ms tie A then E at tick 3, the repeating R at 4 and again at 8, C at
5, and nothing at tick 6, the tick the canceled timer would have owned.
Two checks deserve their own reading. The tie at 30 ms fires in
registration order because collection breaks ties by id, and the
delay-0 child of B fires at tick 2 and not tick 1, which is the next
tick rule earning its keep: B's handler ran during tick 1's dispatch,
the ready list for tick 1 was already frozen, so the child waits for
tick 2's collection no matter that its deadline equals the current
time. Without that rule a self-feeding handler would spin one tick
forever. The repeating timer's arithmetic is checked where it lives, in
the queue: after two fires its next deadline is exactly 120, its
original 40 plus two periods.

The mid-dispatch cancel is the last discipline, and it is the reason
the `armed` flag exists. X and Y share a deadline. Both are collected
into the same tick's ready list. X dispatches first and cancels Y,
which by then is already off the queue but not yet fired:

#listing("c-os-cloud/samples/src/Ch18/eventloop.c", first: 244, last: 252, caption: [a handler cancels its collected sibling mid-dispatch: the armed flag clears, the dispatch skips it])

Cancel works on the timer wherever the loop still owes it something,
queued, or collected but undispatched. And cancel, like unregister in
the first section, never touches `*ctx`: the ownership contract is
identical, here checked with a sentinel the caller reads back intact
after the cancel.

#diagram([one tick as a state machine: collect freezes the ready list, dispatch runs it, delay-0 work schedules one tick ahead], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.6), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.8, 5.4, [advance now\_ms by 10])
  box(8.0, 6.8, 7.2, [collect expired: #linebreak() earliest deadline, ties by id])
  box(17.2, 6.8, 7.0, [dispatch the frozen #linebreak() ready list])
  box(5.4, 4.2, 5.0, [timer queue #linebreak() (live timers)])
  box(14.0, 4.2, 5.0, [ready list #linebreak() (armed timers)])
  cdraw.line((6.0, 7.4), (8.0, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.2, 6.8), (17.2, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.9, 5.4), (8.6, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.1, 6.8), (15.8, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.5, 6.8), (18.5, 5.9), stroke: luma(140), dash: "dashed")
  cdraw.line((18.5, 5.9), (10.4, 5.9), stroke: luma(140), dash: "dashed")
  cdraw.line((10.4, 5.9), (10.4, 5.4), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((14.5, 6.55), [a handler's schedule lands in the queue], wrap: text.with(size: 6pt))
  cdraw.line((21.5, 6.8), (21.5, 6.2), stroke: luma(140), dash: "dashed")
  cdraw.line((21.5, 6.2), (3.3, 6.2), stroke: luma(140), dash: "dashed")
  cdraw.line((3.3, 6.2), (3.3, 6.8), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((5.4, 6.5), [next tick], wrap: text.with(size: 6pt))
  cdraw.content((13.0, 2.9), [cancel strikes the queue or an armed entry: the loop still owes it #linebreak() nothing after either, and never touches ctx], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.line((7.9, 4.8), (11.4, 3.3), stroke: luma(140), dash: "dashed", mark: (end: "x"))
  cdraw.line((16.5, 4.2), (14.6, 3.3), stroke: luma(140), dash: "dashed", mark: (end: "x"))
})

== overlapped io and GetQueuedCompletionStatus

The loop above polls a virtual clock. Real async io is the same shape
with the kernel holding the queue. On windows the entry point is
`FILE_FLAG_OVERLAPPED` at open time, 0x40000000, which the CreateFile
page defines in one line: the flag means "The file or device is being
opened or created for asynchronous I/O", and with it "the file can be
used for simultaneous read and write operations". Without it, "I/O
operations are serialized, even if the calls to the read and write
functions specify an OVERLAPPED structure". The flag changes the
handle's kind, not the call's spelling. ReadFile then states the
consequence: "A pointer to an OVERLAPPED structure is required if the
hFile parameter was opened with `FILE_FLAG_OVERLAPPED`, otherwise it can
be NULL", and the requirement is per-operation, "the lpOverlapped
parameter must point to a valid and unique OVERLAPPED structure,
otherwise the function can incorrectly report that the read operation
is complete". The read position comes from the structure, not the
handle: "This offset is specified by setting the Offset and OffsetHigh
members of the OVERLAPPED structure". And the return value that looks
like failure is not: "The GetLastError code `ERROR_IO_PENDING` is not a
failure; it designates the read operation is pending completion
asynchronously."

The completion port is the queue those pends complete into. The
CreateIoCompletionPort page names the gate the handle must already
pass: "If a handle is provided, it has to have been opened for
overlapped I/O completion. For example, you must specify the
`FILE_FLAG_OVERLAPPED` flag when using the CreateFile function to obtain
the handle." Its `CompletionKey` parameter is this chapter's context
pointer wearing kernel clothes, and the page says exactly what the
registry said: "This value is not used by CreateIoCompletionPort for
functional control; rather, it is attached to the file handle specified
in the FileHandle parameter at the time of association with an I/O
completion port", and it "accompanies the file handle throughout the
internal completion queuing process". One sentence on the I/O
Completion Ports conceptual page is the ordering rule the whole sample
turns on: the functions that start completions require "an instance of
the OVERLAPPED structure and a file handle previously associated with
an I/O completion port (by a call to CreateIoCompletionPort) to enable
the I/O completion port mechanism". Previously associated. Not
associated eventually.

The sample builds both orders against a 4096 byte pattern file it
writes itself and deletes on exit. The wrapper type is the standard
container idiom, and it is also the ownership statement: the whole
struct, `OVERLAPPED`, slot, and 512 byte buffer, must outlive the
in-flight request, exactly as the ReadFile page demands of the buffer,
it "must remain valid for the duration of the read operation":

#listing("c-os-cloud/samples/src/Ch18/overlapped.c", first: 53, last: 73, caption: [the wrapper: OVERLAPPED first, so the completion's pointer recovers the request with one cast])

The working order, and the three reads, offsets 0, 1365, and 4000, each
into its own wrapper:

#listing("c-os-cloud/samples/src/Ch18/overlapped.c", first: 78, last: 97, caption: [the working order: the flag at open, the port associated before the first request])

Each issue accepts either documented return, TRUE or FALSE with
`ERROR_IO_PENDING`, because on a local file either is legal and the
packet is the deliverer of record either way. The drain then holds the
kernel to one-packet-per-request:

#listing("c-os-cloud/samples/src/Ch18/overlapped.c", first: 99, last: 124, caption: [drain three completions: per-handle key, one packet per request, the eof short read exact])

Arrival order across three concurrent reads is the kernel's business,
so the loop asserts set equality, each slot exactly once, plus the
checks that do not move: the key is the per-handle key on every packet,
the transferred count matches each request, including the third read
whose 512 byte request ends at the file's edge and returns the 96 bytes
that exist, the short-read rule quoted verbatim on the ReadFile page,
and the bytes themselves are exact, every one compared against the
pattern function that wrote them. `PostQueuedCompletionStatus` then
proves the queue carries arbitrary values, not just io results, with
the page's own guarantee under it, "The system does not use or validate
these values. In particular, the lpOverlapped parameter need not point
to an OVERLAPPED structure":

#listing("c-os-cloud/samples/src/Ch18/overlapped.c", first: 126, last: 141, caption: [a synthetic packet: three user values posted with no io at all, received untouched])

That is a loop's wake and shutdown channel in one call, the same role a
posted message plays in a window's message loop. The mirror leg is the
one the section exists to assert:

#listing("c-os-cloud/samples/src/Ch18/overlapped.c", first: 143, last: 167, caption: [the broken order: the read issued first, the port associated after, the completion never arrives])

The sleep between issue and association gives the read every chance to
finish, 100 ms for an operation that takes microseconds, so the miss
cannot be blamed on timing: it is the association order. The bounded
wait returns FALSE with the page's own signature of the miss, "the
function times out, returns FALSE, and sets `*lpOverlapped` to NULL",
which is why the sample poisons the variable with a non-null value
first. Nothing dequeues. The completion from a request issued before
association has no port to queue to. Probed on this machine 2026-09-12
and now asserted rather than remembered.
Cleanup follows the docs' own accounting, the port and its associated
handles "are known as references to the I/O completion port", all of
which must close for the port to release, and CloseHandle's object
list includes I/O completion port by name:

#listing("c-os-cloud/samples/src/Ch18/overlapped.c", first: 169, last: 175, caption: [every reference closes, then the temp file is deleted])

#callout("pitfall", "the order the docs state and the probe proved", [
  The conceptual page's sentence, a handle "previously associated with
  an I/O completion port" is what "enable[s] the I/O completion port
  mechanism", reads like a footnote. It is the difference between the
  two legs of the sample. Associate before the first request and every
  completion queues, including completions of operations that finish
  synchronously. Associate after and the already-issued request's
  completion is gone, silently, with no error anywhere: the read's
  data lands in the buffer, the wait times out, and the only evidence
  anything happened is the timeout. The address-sanitizer leg of the
  gate runs this file, so the wrappers' lifetimes are checked, not
  asserted politely.
])

#diagram([the two orders side by side: associate before the request, packets flow; issue first, the completion has no port], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.6), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.0, 4.6, [createfilew #linebreak() FILE\_FLAG\_OVERLAPPED])
  box(6.0, 7.0, 5.2, [createiocompletionport: #linebreak() associate, key 0x1F1E])
  box(11.8, 7.0, 4.4, [3 x readfile, #linebreak() one ov each])
  box(11.8, 4.4, 7.6, [kernel: packets queue fifo #linebreak() at the associated port])
  box(0.6, 4.4, 4.6, [gqcs: bytes, key, #linebreak() the ov pointer])
  box(0.6, 2.2, 4.6, [one cast recovers #linebreak() the request and its bytes])
  cdraw.line((5.2, 7.6), (6.0, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 7.6), (11.8, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.0, 7.0), (14.0, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 5.2), (5.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.9, 4.4), (2.9, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.9, 6.5), [the working order, 33 checks], wrap: text.with(size: 6.5pt, fill: luma(100)))
  box(6.0, 1.8, 4.6, [readfile first: #linebreak() the same read, pended])
  box(11.4, 1.8, 5.0, [sleep 100, then #linebreak() associate the port])
  cdraw.rect((17.2, 0.8), (23.4, 3.6), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((20.3, 2.2), [gqcs 1500 ms: FALSE, #linebreak() \*ov NULL, #linebreak() nothing dequeued], wrap: text.with(size: 6pt))
  cdraw.line((10.6, 2.6), (11.4, 2.6), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((16.4, 2.6), (17.2, 2.6), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((12.8, 0.4), [the broken order: identical calls, #linebreak() opposite association sequence, #linebreak() the completion vanishes], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== epoll and io\_uring, cited

The two linux models for the same problem are cited here from man7,
fetched 2026-09-12, and never executed on this box, the standing
treatment for the posix side since chapter 11's `fork`. Both are the
chapter's own shapes with the kernel deeper inside.

`epoll(7)` is the event loop's collection phase as a syscall family.
"The central concept of the epoll API is the epoll instance, an
in-kernel data structure" holding two lists, the interest list, "the
set of file descriptors that the process has registered an interest in
monitoring", and the ready list, "the set of file descriptors that are
'ready' for I/O", "dynamically populated by the kernel as a result of
I/O activity". That ready list is the same ready list the loop above
freezes each tick; epoll just never lets user space see the queue, only
its drained contents. Three calls build the loop: `epoll_create`
"creates a new epoll instance and returns a file descriptor referring
to that instance", `epoll_ctl` registers interest, and `epoll_wait`
"waits for I/O events, blocking the calling thread if no events are
currently available", which "can be thought of as fetching items from
the ready list". One behavioral fork has no windows counterpart in this
chapter: "The epoll event distribution interface is able to behave both
as edge-triggered (ET) and level-triggered (LT)", and the edge variant
changes the contract, "An application that employs the EPOLLET flag
should use nonblocking file descriptors", with readiness honored "until
the next (nonblocking) read/write yields EAGAIN". The completion port
never poses that question because it does not report readiness at all;
it reports finished operations.

`io_uring(7)` is the completion port's closest kin. "`io_uring` is a
Linux-specific API for asynchronous I/O" that "gets its name from ring
buffers which are shared between user space and kernel space", two of
them: "You place I/O requests you want to make on the SQ, while the
kernel places the results of those operations on the CQ." Submission
entries are io requests by another spelling, "Each I/O operation is, in
essence, the equivalent of a system call you would have made
otherwise", and completion is one for one: "The kernel places exactly
one matching CQE in the CQ for every SQE you submit on the SQ", the
same one-packet-per-request the sample asserted against
`GetQueuedCompletionStatus`. The context channel travels in `user_data`,
"passed unchanged from SQE to CQE, used to correlate completions", the
same job the completion key and the `OVERLAPPED` wrapper do together on
windows. The batching escape hatch is where `io_uring` passes the others:
"you can batch several requests in one go, simply by queueing up
multiple SQEs", and with SQ polling "there is no need for you to call
`io_uring_enter(2)`" at all, the submission ring drained by a kernel
thread. The ordering caution mirrors this chapter's arrays: "I/O
requests submitted to the kernel can complete in any order."

All three systems land on the same three answers, registration before
readiness or submission, one wait point, and a context value that
travels with each completion. The differences are in what the wait
returns and who owns the queues, and the matrix is the chapter in one
picture:

#diagram([three completion systems, one matrix: what registers, what waits, what comes back, what carries the context], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  let colw = 6.4
  let lx = 0.6
  cell(lx, 8.6, 3.4, 1.1, [windows], fill: luma(205))
  cell(lx + 3.8, 8.6, colw, 1.1, [GQCS], fill: luma(205))
  cell(lx + 10.6, 8.6, colw, 1.1, [linux epoll], fill: luma(205))
  cell(lx + 17.4, 8.6, colw, 1.1, [linux io\_uring], fill: luma(205))
  cell(lx, 6.6, 3.4, 1.7, [registration])
  cell(lx + 3.8, 6.6, colw, 1.7, [the handle is #linebreak() associated at the port])
  cell(lx + 10.6, 6.6, colw, 1.7, [epoll\_ctl adds an fd #linebreak() to the interest list])
  cell(lx + 17.4, 6.6, colw, 1.7, [an SQE is placed #linebreak() on the shared ring])
  cell(lx, 4.5, 3.4, 1.7, [the wait])
  cell(lx + 3.8, 4.5, colw, 1.7, [gqcs dequeues one #linebreak() completion packet])
  cell(lx + 10.6, 4.5, colw, 1.7, [epoll\_wait fetches #linebreak() ready-list items])
  cell(lx + 17.4, 4.5, colw, 1.7, [read CQEs, or enter #linebreak() once per batch])
  cell(lx, 2.4, 3.4, 1.7, [delivery])
  cell(lx + 3.8, 2.4, colw, 1.7, [finished operation: #linebreak() bytes, key, ov])
  cell(lx + 10.6, 2.4, colw, 1.7, [readiness, level #linebreak() or edge triggered])
  cell(lx + 17.4, 2.4, colw, 1.7, [one CQE per SQE: #linebreak() user\_data plus res])
  cell(lx, 0.3, 3.4, 1.7, [context channel])
  cell(lx + 3.8, 0.3, colw, 1.7, [completion key #linebreak() plus the ov wrapper])
  cell(lx + 10.6, 0.3, colw, 1.7, [epoll\_event data, #linebreak() set at registration])
  cell(lx + 17.4, 0.3, colw, 1.7, [user\_data, passed #linebreak() unchanged sqe to cqe])
  cdraw.content((12.9, -1.1), [the queue owner moves left to right: user loop, kernel interest list, shared rings], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The epilogue writes itself from the matrix. The event loop of the
second section is the left column by hand, a user-space queue polled by
a tick. `epoll` keeps the registration in the kernel but still reports
readiness, so the caller re-issues the operation and owns the
completion question. `io_uring` and GQCS both move the completion
across the boundary, one matching completion per request, a context
value riding each one untouched. The async chapters of this book end
where the cloud chapters begin, with the observation that a server is
a loop like this one holding ten thousand sockets instead of six
timers, and the loop that survives is the loop whose ownership answers
were written down before the first request was issued.

sources: learn.microsoft.com, CreateFileA (`FILE_FLAG_OVERLAPPED` and the
synchronous versus asynchronous handle section), ReadFile (lpOverlapped
requirement, `ERROR_IO_PENDING`, the eof short read, buffer lifetime),
CreateIoCompletionPort (the overlapped gate, the completion key, the
references rule), GetQueuedCompletionStatus (return values, the
timeout that nulls lpOverlapped), PostQueuedCompletionStatus (values
not used or validated), CloseHandle (the object list, I/O completion
port included), and the I/O Completion Ports conceptual page (FIFO
packet queue, LIFO thread release, the concurrency value, the
"previously associated" mechanism sentence), all accessed 2026-09-12;
man7.org epoll(7) and `io_uring(7)`, accessed 2026-09-12; the
association-order behavior, the timeout shape of the vanished
completion, and the per-packet values probed on this machine the same
day. Sample behavior verified by `make verify-c`, 68 checks in chapter
18 of the samples suite.
