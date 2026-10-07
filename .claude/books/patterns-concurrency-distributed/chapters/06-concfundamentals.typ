#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= concurrency fundamentals and the memory model

Book 3 toured the syntax of goroutines and channels. This chapter is
about what the language actually promises when two goroutines touch
the same memory, because the promise is narrower than most
programmers assume and everything later in this book, the sync
primitives, the hazards chapter, the raft capstone, is built on its
edges. The question now runs in seven voices, and the voices disagree
about the substrate before they agree about anything else: real
operating system threads in C, goroutines in go, virtual threads on
the jvm in java, pool tasks in C\#, one event loop plus
message-passing workers in javascript, threads under the GIL plus
asyncio in python, coroutines in lua. The fixtures stay identical
anyway, exact totals, exact counts, bounds forced by gates, because
those are the claims a memory model can actually keep.

== the model in one rule

A data race is a write to a memory location concurrent with another
read or write of the same location, unless every access is atomic
through `sync/atomic`. Racy programs are broken programs, not
programs with unspecified timing. What separates go from c and c++
is the floor under the wreckage: a racing read must observe some
preceding or concurrent write, never an out of thin air value, and
the race detector can flag the program, at runtime when a racy
interleaving actually executes, never at build time. But races on
multiword values, interfaces, slices, maps, strings, can tear
pointer and length pairs and corrupt memory, so the floor is not a
place to stand.

The guarantee for correct programs is DRF-SC, data race free
programs execute as if multiplexed on a single processor,
sequentially consistent. The whole engineering discipline of go
concurrency is getting into that category and staying there, and the
memory model names exactly which constructs are doors in.

Each sibling tree faces its own model instead. C's is the C11 one:
plain racy accesses are undefined, and the doors are thread
creation, join, mutex and condition variables, and the stdatomic
ordering ladder. #xref-to("c-os-cloud", "threads") puts C23
`<threads.h>` and the win32 layer beneath it side by side. C\#, go,
and java promise the
same DRF-SC shape over tasks, goroutines, and virtual threads, and
java names the same ordering ladder stdatomic.h walks through
`VarHandle` access modes. Javascript runs one
thread per realm, so its model question is queue ordering, not
memory tearing, until `worker_threads` or a `SharedArrayBuffer`
enters. Python's GIL keeps bytecode-granular atomicity but switches
threads between bytecodes, so compound reads and writes still tear.
Lua has no preemption at all, and its lanes demonstrate races by
yielding on purpose inside a read-modify-write.

#diagram([one memory cell, which concurrent access pairs race], length: 13pt, {
  cdraw.content((3.6, 6.9), [g2 read], size: 6.5pt)
  cdraw.content((9.8, 6.9), [g2 write], size: 6.5pt)
  cdraw.content((-1.6, 4.9), [g1 read], size: 6.5pt)
  cdraw.content((-1.6, 3.0), [g1 write], size: 6.5pt)
  cdraw.rect((0.2, 4.2), (6.8, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 4.9), [safe], size: 6pt)
  cdraw.rect((7.0, 4.2), (13.6, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.3, 4.9), [race], size: 6pt)
  cdraw.rect((0.2, 2.3), (6.8, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((3.5, 3.0), [race], size: 6pt)
  cdraw.rect((7.0, 2.3), (13.6, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((10.3, 3.0), [race], size: 6pt)
  cdraw.content((6.9, 1.0), [unless every access is atomic, racy means broken, multiword values can tear], size: 6pt)
})

== happens-before, the doors

Happens before is the transitive closure of program order within a
goroutine plus the synchronization edges between them. The edges
that matter:

#callout("note", "the synchronization edges", [
  `go f()`: the statement is synchronized before the goroutine
  starts, so data written before `go` is visible inside it. The
  reverse is false, a goroutine's exit orders nothing. Channel send:
  a send is synchronized before the completion of the corresponding
  receive. Unbuffered, the reverse also holds: the receive is
  synchronized before the send completes, a full rendezvous.
  Buffered capacity C: the kth receive is synchronized before the
  k+Cth send completes, which makes a buffered channel a counting
  semaphore. Close: closing is synchronized before a receive that
  returns zero because of it. Mutex: for n under m, the nth Unlock
  is synchronized before the mth Lock returns. Once: the completion
  of f in once.Do is synchronized before any once.Do returns.
  Atomics: if B observes A's effect, A is synchronized before B, and
  all atomics behave as one sequentially consistent order.
])

#diagram([one synchronizes-with edge carrying visibility across goroutines], length: 13pt, {
  // two goroutine timelines, time flows right
  cdraw.content((0, 4.1), [goroutine 1], size: 6.5pt)
  cdraw.content((0, -0.1), [goroutine 2], size: 6.5pt)
  cdraw.line((0, 3.4), (24, 3.4), stroke: 1pt)
  cdraw.line((0, 0.6), (24, 0.6), stroke: 1pt)
  cdraw.content((12, -0.9), [time], size: 6pt)
  cdraw.line((23.4, 0.35), (24, 0.6))
  cdraw.line((23.4, 0.85), (24, 0.6))

  cdraw.circle((3, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((3, 3.85), [x = 1], size: 6.5pt)
  cdraw.circle((10, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((9.2, 3.85), [send ch], size: 6.5pt)
  cdraw.circle((11.2, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((10.2, 0.05), [receive ch], size: 6.5pt)
  cdraw.line((10, 3.25), (11.2, 0.78), stroke: 1pt)
  cdraw.content((16.5, 2.3), [synchronizes-with], size: 6.5pt)
  cdraw.circle((18, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((18, 0.05), [reads x, sees 1], size: 6.5pt)
  cdraw.content((12, 5.0), [everything g1 did before the send is visible to g2 after the receive], size: 6.5pt)
})

#diagram([all eight synchronizes-with edges and what each one orders], length: 13pt, {
  cdraw.content((4.4, 8.35), [the edge], size: 6.5pt)
  cdraw.content((16.1, 8.35), [what it orders], size: 6.5pt)
  let cols = ((0.4, 8.4), (8.8, 23.4))
  let rows = (
    ([go f()], [before the goroutine starts]),
    ([send], [before the matching receive completes]),
    ([unbuffered receive], [before the send completes, the rendezvous]),
    ([buffered cap C], [kth receive before the (k+C)th send]),
    ([close], [before the zero receive it causes]),
    ([mutex], [nth Unlock before the mth Lock]),
    ([once.Do], [f completes before any Do returns]),
    ([atomics], [observing A's effect puts A before B]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.7 - i * 1.1
    for (j, cell) in row.enumerate() {
      let c = cols.at(j)
      cdraw.rect((c.at(0), y), (c.at(1), y + 0.9), fill: luma(235), radius: 0.02)
      cdraw.content(((c.at(0) + c.at(1)) / 2, y + 0.45), cell, size: 6pt)
    }
  }
})

The go list is go's, and the four sections below walk one fixture
through each tree's own doors. The C lane answers with C11: thread
creation and `thrd_join` are edges, mutexes and condition variables
are edges, and the `stdatomic.h` ordering ladder is the fine-grained
one, #xref-to("c-os-cloud", "atomics") traces that ladder and the
single-producer ring it is asked to justify.

The C\# row keeps the channel shape native: `System.Threading.Channels`
makes completion an edge and bounded capacity a counting rule,
#xref-to("csharp-net", "stdlib2") is where the BCL surface lives.

The python row splits by substrate: real threads order through
`threading` locks and queues, the GIL underneath making each
bytecode atomic but nothing more, #xref-to("python", "threads")
is the locks-and-queues tour this lane rides.

The javascript row has no shared memory to order, one thread per
realm, so every edge is a queue boundary instead: an `await` is a
park and a resolve is a wake, #xref-to("javascript", "async")
tours the loop every javascript goroutine rides. Lua's rows are
cooperative, a yield is the only place an interleaving can happen,
which is why its races are scripted, never suffered.

== the wait edge

SumParallel splits the input, sums each part concurrently, and
totals the partials. The wait is the whole lesson, the edge that
makes every unlocked partial write visible:

The dry run: 1 through 10001 totals 50015001 under all 5
partitionings, parts 1, 2, 7, 100, and 5000, and the empty input
totals 0. The chunk ladder pins at 10001, 5001, 1429, 101, and 3,
asserted by the six new trees, the go lane's frozen test pins the
totals and the nil case without the ladder.

+ Each partial slot has exactly one writer, and the wait is ordered
  after every done, itself ordered after the write, so the unlocked
  writes are safe by construction.
+ The partitioning is ceil-div chunks with trailing empties skipped,
  every element in exactly one part across all 5 shapes.
+ The wait is a join in every substrate: the zero-count condition
  broadcast in C and python, the 15-line synchronized waitgroup in
  java, `WhenAll` in C\#, the drained promise in javascript, the
  last done waking the parked total lane in lua.

#listing("patterns-concurrency-distributed/samples-c/src/Ch06/waitgroup.c", first: 20, last: 52, caption: [C, the waitgroup by hand, one mutex and one condition, the wait loop rechecking the count])

#listing("patterns-concurrency-distributed/samples/ch06/memorymodel.go", first: 11, last: 46, caption: [Go, waitgroup parallel sum: partial writes become visible at wait])

#listing("patterns-concurrency-distributed/samples-java/src/Ch06/Waitgroup.java", first: 23, last: 74, caption: [Java, the waitgroup hand-rolled on synchronized and notifyAll, CountDownLatch being one-shot only, the parts on virtual threads])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch06/Waitgroup.cs", first: 3, last: 39, caption: [C\#, Task.Run per part, Task.WhenAll is the wait edge])

#listing("patterns-concurrency-distributed/samples-js/src/ch06-waitgroup.mjs", first: 7, last: 28, caption: [JavaScript, the waitgroup as a pending counter that wakes parked promise resolvers])

#listing("patterns-concurrency-distributed/samples-py/src/Ch06/waitgroup.py", first: 18, last: 36, caption: [Python, the waitgroup over a Condition, notify_all when the count drains])

#listing("patterns-concurrency-distributed/samples-lua/ch06_waitgroup.lua", first: 36, last: 84, caption: [Lua, Add before spawn, Done at exit, the last Done wakes the parked total lane])

Each slot has exactly one writer, and `wg.Wait` is ordered after
every `wg.Done`, itself ordered after the write. The test drives 5
partitionings over 10001 elements plus the nil case
and demands the exact total every time. That determinism is DRF-SC
paying off: under a race the same code is wrong in unbounded ways.
The sibling trees build the wait
out of their own substrate, mutex plus condition in C and python,
`synchronized` plus `notifyAll` in java, task completion in C\#, a
promise registry in javascript, and a parked-coroutine list in lua,
the same 20-line scheduler shape every lua lane in this chapter
carries.

== the rendezvous edge

PingPong bounces a token between two workers n times, and every
bounce is causally ordered, the count can be neither lost nor
doubled:

The dry run: 1000 round trips count exactly 1000 and a single
round trip counts 1, all seven lanes pinning both counts. The
degenerate shapes are per-tree lanes, zero rounds counting zero and
an odd 17 holding in java and python, and the logged walk strictly
alternating sent and received, 16 entries for 8 trips, in lua.

+ Each exchange costs 2 synchronization edges, the receive completing
  before the send returns, the unbuffered rule made visible.
+ The pinger only counts a trip after its pong came back, so no
  interleaving can lose or double one.
+ The lane shapes differ, two threads in C and go, two virtual
  threads in java, two tasks in C\#, two async closures in
  javascript, two asyncio tasks in python, two coroutines in lua,
  and the counts agree anyway.

#listing("patterns-concurrency-distributed/samples-c/src/Ch06/rendezvous.c", first: 20, last: 70, caption: [C, two threads over one mutex and two condition variables, every wait guaranteed a partner])

#listing("patterns-concurrency-distributed/samples/ch06/memorymodel.go", first: 49, last: 73, caption: [Go, strict alternation through two unbuffered channels])

#listing("patterns-concurrency-distributed/samples-java/src/Ch06/Rendezvous.java", first: 21, last: 58, caption: [Java, SynchronousQueue is the unbuffered channel native, put returns only when a take takes the value])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch06/Rendezvous.cs", first: 3, last: 37, caption: [C\#, a pair of binary SemaphoreSlims, no unbuffered channel exists])

#listing("patterns-concurrency-distributed/samples-js/src/ch06-rendezvous.mjs", first: 7, last: 34, caption: [JavaScript, the Handoff class, send parks until a receiver takes])

#listing("patterns-concurrency-distributed/samples-py/src/Ch06/rendezvous.py", first: 18, last: 42, caption: [Python, two asyncio tasks over plain queues, the get before the put])

#listing("patterns-concurrency-distributed/samples-lua/ch06_rendezvous.lua", first: 30, last: 59, caption: [Lua, the unbuffered channel as parked sender and receiver lists])

Go's unbuffered channel is the native shape and C\#'s channels have
no unbuffered mode, so its rendezvous is two binary semaphores, the
waiter blocking until the releaser acts. Java's `SynchronousQueue`
is the unbuffered channel native, `put` returning only when a
`take` takes the value, the one stdlib in this chapter that needs
no rebuilding. C builds the same binary
handoff from a mutex and two condition variables, where the
zero-waiter forgetfulness trap from chapter 15 of the C book cannot
bite because every wait is guaranteed a partner. The dynamic three
park continuations instead of threads, javascript resolvers,
python asyncio waits, lua parked coroutines, and the alternation
comes from the queue edges themselves.

== atomics, the word-sized escape hatch

100 workers adding 1000 each into one word must land
on exactly 100000, and only the atomic add guarantees
it:

The dry run: the exact 100000 total pins in every lane with real
shared memory, go's goroutines, C's threads over an `_Atomic` cell,
java's threads over an `AtomicLong`, C\#'s workers over
`Interlocked`, javascript's workers over one `SharedArrayBuffer`
cell. The two coroutine lanes state their
boundary the honest way: a scripted 2 by 5 read, pause, write walk
loses 5 of 10 updates in python and lua alike, and the locked or
non-yielding versions reach 10, the same code reaching 100000 when
the whole section is atomic.

+ The add must be one linearizable step, an interleaved read then
  write loses updates, pinned at 5 of 10 in the scripted lanes.
+ Atomics are the model's smallest door, correct for single words
  with no invariants spanning them, two-field invariants need the
  mutex of chapter 7.
+ The javascript lane's inline-eval worker over a `SharedArrayBuffer`
  is the one sanctioned SAB home in this corpus, the only place two
  javascript heaps share memory.

#listing("patterns-concurrency-distributed/samples-c/src/Ch06/atomics.c", first: 20, last: 42, caption: [C, an atomic long long with fetch_add, the relaxed ordering stated where it is chosen])

#listing("patterns-concurrency-distributed/samples/ch06/memorymodel.go", first: 76, last: 85, caption: [Go, atomic adds are linearizable, lost updates impossible])

#listing("patterns-concurrency-distributed/samples-java/src/Ch06/Atomics.java", first: 25, last: 59, caption: [Java, VarHandle aims every access mode at one field, the plain payload published by a release flag])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch06/Atomics.cs", first: 3, last: 24, caption: [C\#, Interlocked.Add, with the plain += control group beside it])

#listing("patterns-concurrency-distributed/samples-js/src/ch06-atomics.mjs", first: 9, last: 38, caption: [JavaScript, worker_threads over one SharedArrayBuffer, Atomics.add into the shared cell])

#listing("patterns-concurrency-distributed/samples-py/src/Ch06/atomics.py", first: 18, last: 49, caption: [Python, the scripted tear, read, pause, write, 5 of 10 updates lost on display])

#listing("patterns-concurrency-distributed/samples-lua/ch06_atomics.lua", first: 30, last: 45, caption: [Lua, the non-yielding add is the atomic, the torn version opens the window with a yield])

C names the ordering it wants, `memory_order_relaxed` for the count
where only the arithmetic needs to be atomic, the ladder chapter 16
of the C book walks in full. Java walks the same ladder through
`VarHandle` access modes, plain, opaque, release and acquire,
volatile, with `AtomicLong` as the counter and `Thread.onSpinWait`
the hint the acquire spin rides. C\#'s `Interlocked` is the same
facility with one default. The javascript lane is the corpus's one
real shared-memory lane, a worker pool inside an inline-eval module
adding into the same `Int32Array` cell, joined on exit messages,
and it is the only such lane because a second heap is a cost this
tree pays once and points at. Python has no word-sized escape
hatch: `+=` is a load, an add, and a store the GIL may split, so
the sample shows the tear with a hand-driven interleaving and buys
the exact total with a lock, the honest row. Lua has no preemption,
so a read-modify-write with no yield inside is atomic however the
lanes interleave, and the sample tears it on purpose with a yield
to show what the preemptive worlds suffer, the lost-update walk on
the cooperative scheduler#xref-to("lua", "coroutines") this whole
book scripts.

#diagram([many adders, one word, an exact total every run], length: 13pt, {
  cdraw.content((7.5, 5.6), [100 goroutines, 1000 adds each], size: 6.5pt)
  for k in range(7) {
    let x = 1.0 + k * 2.2
    cdraw.content((x, 4.3), [+1000], size: 6pt)
    cdraw.line((x, 3.95), (7.5, 2.35), stroke: luma(220))
  }
  cdraw.rect((4, 0.2), (11, 2.2), fill: luma(205), radius: 0.02)
  cdraw.content((7.5, 1.7), [atomic counter], size: 6.5pt)
  cdraw.content((7.5, 0.7), [100000 exactly], size: 6pt)
  cdraw.content((18.0, 1.2), [single words only,#linebreak()two-field invariants need a mutex], size: 6pt)
})

== close and capacity

The closing edge and the counting rule, one channel carrying both
lessons:

The dry run: the values 5, 3, 9, 1, 7 fill a channel, close it, and
the drain totals 25, the empty input closes and drains to 0, and
sending on a closed channel is a loud error where a tree pins it,
lua's row the explicit one. 50 jobs through a gate of 3 all finish,
the observed peak never passes 3.

+ Close is ordered after every send before it, so the range sees all
  values, and close never erases the buffer, the lagging receiver
  still drains.
+ The kth receive admits the k+Cth send, so capacity C bounds C
  workers at once, the counting semaphore rule.
+ The peak probe asserts a bound forced by the gate, an invariant,
  never a timing.

#listing("patterns-concurrency-distributed/samples-c/src/Ch06/channels.c", first: 24, last: 63, caption: [C, the bounded channel over one mutex and one condition, close broadcasts])

#listing("patterns-concurrency-distributed/samples/ch06/memorymodel.go", first: 87, last: 117, caption: [Go, close orders the terminal receive, capacity C bounds C workers])

#listing("patterns-concurrency-distributed/samples-java/src/Ch06/Channels.java", first: 32, last: 77, caption: [Java, the channel hand-rolled over ReentrantLock and one Condition, close broadcasts, recv answers false once drained])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch06/Channels.cs", first: 5, last: 50, caption: [C\#, Complete before ReadAllAsync, the bounded channel doubling as the gate])

#listing("patterns-concurrency-distributed/samples-js/src/ch06-channels.mjs", first: 7, last: 54, caption: [JavaScript, the Chan class, send waits when full, close wakes every parked side])

#listing("patterns-concurrency-distributed/samples-py/src/Ch06/channels.py", first: 21, last: 59, caption: [Python, the Chan over one asyncio Condition, a CLOSED sentinel ending the drain])

#listing("patterns-concurrency-distributed/samples-lua/ch06_channels.lua", first: 30, last: 77, caption: [Lua, buffered tables with parked senders, close without erasing])

C's channel is one mutex, one condition, a ring of integers, and a
closed flag, the chapter 7 bounded queue arriving one chapter early
in miniature. Java rolls the same channel by hand on
`ReentrantLock` and one `Condition`, and parks its stdlib lanes
beside it: `Semaphore` is the gate and `ArrayBlockingQueue` the
buffered channel minus the close. C\# gets both edges from the BCL
channel, `Writer.Complete` is the close and bounded capacity is the
gate. The dynamic three park continuations, javascript on promise
resolvers, python on the condition, lua on the scheduler's parked
list, and go's semaphore is the idiom the memory model document
itself suggests, a buffered channel of capacity C where sending
acquires and receiving releases.

== broken idioms, named

The memory model document closes with broken idioms worth naming
because every go codebase grows one eventually. Double checked
locking, checking a plain flag before `once.Do`, fails because the
racing read may observe the flag set without observing the writes
sequenced before it. Busy waiting on a plain bool may spin forever,
since nothing forces the loop to see the update. Publishing a
pointer through a plain field may surface a non-nil pointer with
stale contents. The document's own advice ends the argument: if you
must read the rest of the model to understand your program, you are
being too clever. Don't be clever. The sibling trees inherit the
same graves: C's data race is undefined behavior with no floor, and
the cooperative lanes can only exhibit the bug by building it, which
is the strongest argument for never shipping it.

#diagram([three idioms the memory model document names as broken], length: 13pt, {
  cdraw.rect((0, 6.0), (22, 8.5), fill: luma(235), radius: 0.02)
  cdraw.content((11, 8.0), [double-checked locking on a plain flag], size: 6.5pt)
  cdraw.content((11, 6.85), [the flag read can see the flag without the writes sequenced before it], size: 6pt)
  cdraw.rect((0, 3.1), (22, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((11, 5.1), [busy waiting on a plain bool], size: 6.5pt)
  cdraw.content((11, 3.95), [nothing forces the loop to ever see the update, it may spin forever], size: 6pt)
  cdraw.rect((0, 0.2), (22, 2.7), fill: luma(235), radius: 0.02)
  cdraw.content((11, 2.2), [publishing a pointer through a plain field], size: 6.5pt)
  cdraw.content((11, 1.05), [a non-nil pointer with stale contents can surface], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [411], [libc plus threads.h, stdatomic.h], [waitgroup, channel, and semaphore by hand over mtx and cnd, relaxed ordering named at the add],
  [go], [91], [stdlib], [frozen reference lane, the five fixtures this chapter's contracts derive from],
  [java], [354], [jdk 27 stdlib], [the VarHandle ladder named rung by rung, SynchronousQueue the native rendezvous, waitgroup and channel rolled by hand],
  [c\#], [134], [bcl], [WhenAll waits, SemaphoreSlim rendezvous, Interlocked counters, Channels for close and capacity],
  [javascript], [217], [node stdlib], [promise-resolver waits, Handoff rendezvous, the corpus's one SharedArrayBuffer lane],
  [python], [269], [stdlib only], [Condition waitgroup, asyncio queues, the scripted tear where atomics do not exist],
  [lua], [529], [lib.lua harness], [one 20-line scheduler under every lane, races built on purpose with yields, the torn 5 beside the serialized 10],
)

sources: go.dev/ref/mem for the definition of data race, every
synchronization edge quoted above, DRF-SC, and the broken idioms,
accessed 2026-09-08. Verified by the seven chapter legs: 4 Ch06 C
programs with 327 embedded checks, `go test -race` at 6 tests in
`patternsbook/ch06`, 4 Ch06 java programs with 37 checks under
`run-java-samples`, 10 C\# facts over `PatternsBook.slnx`, 9
`node --test` cases, 23 Python checks across 4 files, and 17 Lua
rows under `run.lua`.
