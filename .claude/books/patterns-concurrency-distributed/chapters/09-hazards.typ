#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= hazards and detectors

Four failure modes own concurrent code: races, deadlocks,
starvation, and leaks. Chapter 6 defined the first one and its cure
in the large, and chapter 8 closed the leak account with one
instrument per tree. This chapter makes the middle two concrete
across seven trees, shows the code that survives each, and equips
the reader with the detectors each toolchain actually ships: the go
race detector, the contention instruments of the other lanes, the
goroutine leak profile new in go 1.27, and `testing/synctest`, the
fake-clock bubble that turns time dependent concurrency tests
deterministic, plus the six portable rebuilds of that bubble the
sibling trees carry.

== deadlock, and the cycle rule

A deadlock is a cycle of workers where each waits for the next. The
go runtime detects only the total version, every goroutine in the
program asleep with no possibility of waking, and reports it as
`fatal error: all goroutines are asleep - deadlock!`. A partial
deadlock, 2 of a thousand workers circling each other while the rest
work, produces no message at all, just a counter that stops moving,
and none of the seven runtimes here detects that one for you.

The classic generator of the partial kind is dining philosophers
with the naive rule, everyone picks up the left fork, then the
right:

#snippet(
  "// the bug: a cycle of left-then-right waits\n"
  + "t.forks[left].Lock()\n"
  + "t.forks[right].Lock()  // holds left, waits for right\n",
  lang: "go",
)

#flow(
  [the wait cycle, each goroutine holds one lock and waits for the next],
  node((0, 0), [g1, holds L1]),
  node((2.4, 0), [g2, holds L2]),
  node((1.2, -1.6), [g3, holds L3]),
  edge((0, 0), (2.4, 0), "-|>", label: [waits for L2]),
  edge((2.4, 0), (1.2, -1.6), "-|>", label: [waits for L3]),
  edge((1.2, -1.6), (0, 0), "-|>", label: [waits for L1]),
)

5 diners, 5 forks, everyone holds their left and waits for
their right, the wait graph is a cycle. The fix is total resource
ordering: assign every lock a number and always acquire in ascending
order, which makes a cycle impossible because the last holder of the
highest lock cannot be waiting for a lower one.

The dry run: 5 diners x 100 bites each under the ordering rule and
the guard, every seat eats exactly 100, the table total is 500. The
counter-lanes pin the bug side by hand: lua runs the same scheduler
on the naive left-then-right rule and all 5 diners park at 0
bites, python proves the naive rule closes a cycle in the fork graph
and the ordered rule leaves it acyclic, java runs the same proof as
a coloring DFS over the rule itself before the live table eats its
500.

#listing("patterns-concurrency-distributed/samples-c/src/Ch09/dining.c", first: 70, last: 107, caption: [C, 5 mtx_t forks, first and second by fork number, the run wrapped in the guard below])

#listing("patterns-concurrency-distributed/samples/ch09/hazards.go", first: 22, last: 39, caption: [Go, first and second by fork number, the cycle cannot form])

#listing("patterns-concurrency-distributed/samples-java/src/Ch09/Dining.java", first: 24, last: 67, caption: [Java, both rules as data, a coloring DFS over the wait graph proves the naive order cyclic and the ordered one acyclic])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch09/Dining.cs", first: 8, last: 40, caption: [C\#, a fork is a binary SemaphoreSlim, the owned mutual exclusion shape, acquired ascending])

#listing("patterns-concurrency-distributed/samples-js/src/ch09-dining.mjs", first: 37, last: 62, caption: [JavaScript, forks are promise-queue mutexes, a naive rule would park every diner on a promise that never resolves])

#listing("patterns-concurrency-distributed/samples-py/src/Ch09/dining.py", first: 65, last: 79, caption: [Python, 5 real locks under the GIL, the cycle logic applies even where threads cannot tear memory])

#listing("patterns-concurrency-distributed/samples-lua/ch09_dining.lua", first: 59, last: 98, caption: [Lua, forks hand ownership to the head waiter, the ordering rule is the whole lesson, the window stands in for preemption])

The seven lanes all carry the same rule and differ in what a fork
is. C, go, java, and python hold real kernel locks, C through
`mtx_t`, go through `sync.Mutex`, java through `synchronized` on a
plain object per fork, python through `threading.Lock`, and python's
row is the honest one about scope: the GIL stops torn memory, it
does nothing to a wait cycle, the graph logic is identical. C\#
reaches for a binary `SemaphoreSlim` because C\# locks are
monitor-bound to objects and a counting semaphore of 1 is the clean
owned-exclusion primitive. Javascript builds the mutex as a promise
queue, one thread but many coroutines, so the deadlock would be just
as real, every diner parked on a resolver nobody calls. Lua's
scheduler makes the hazard visible instead of preventing it: the
naive run is a pinned fixture, 5 diners parked, 0 bites, and the
ordered run feeds everyone.

== the guard, hangs become failures

Any test that could hang needs a deadline, because a suite that
freezes reports nothing. `MustFinishWithin` converts a would-be hang
into a failure with a stack.

The dry run: an instant body passes everywhere. A stuck body trips
the deadline in go, C, java, javascript, and python, each with a
real timer of a few tens of milliseconds, the one real-time
primitive those trees allow in an asserted path, and java's stuck
body announces entry on its own latch, so a fired deadline is
provably a stuck body, never one that never started. C\# pins only
the pass path, tripping its guard would demand asserting on a real
timed wait, which the tree's determinism policy refuses. Lua runs
the whole contract on the virtual clock, a 30ms budget against a
1000ms hang trips at clock 30 in zero real time.

#listing("patterns-concurrency-distributed/samples-c/src/Ch09/guard.c", first: 84, last: 97, caption: [C, the body on its own thread, a timed cond wait for the deadline, true only when the body returned])

#listing("patterns-concurrency-distributed/samples/ch09/hazards.go", first: 114, last: 128, caption: [Go, timeout guard: deadlocks fail the test instead of freezing the suite])

#listing("patterns-concurrency-distributed/samples-java/src/Ch09/Guard.java", first: 24, last: 42, caption: [Java, the body on its own thread, the caller awaits a done latch with the deadline, the returned worker lets a tripped guard still release it])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch09/Guard.cs", first: 9, last: 22, caption: [C\#, the body on the pool, WhenAny against a Task.Delay, the one sanctioned real-time wait])

#listing("patterns-concurrency-distributed/samples-js/src/ch09-guard.mjs", first: 9, last: 32, caption: [JavaScript, one real setTimeout races the body, a body that rejects surfaces its own error instead of the guard's false])

#listing("patterns-concurrency-distributed/samples-py/src/Ch09/guard.py", first: 18, last: 30, caption: [Python, the body in a daemon worker, Event.wait with the limit, the worker returned so a tripped guard can still release it])

#listing("patterns-concurrency-distributed/samples-lua/ch09_guard.lua", first: 86, last: 115, caption: [Lua, the deadline is one more racer on the virtual clock, cancel aborts the body's pending sleeps])

Every concurrency test in the capstone wraps its cluster in this
guard. The general rule the pattern encodes: any wait that could
plausibly never end must have a deadline, in production code as a
timeout context, in tests as this helper, and the guarded body must
be fast enough that a green run never trips it.

== starvation, and the rwmutex decision

Starvation is a worker making progress while another never does.
The sample pins the instance go programmers actually meet, a writer
behind an unbroken stream of readers:

The dry run: 8 readers in an unbroken flood, 1 writer taking the
write side 50 times, the writer completes 50 of 50 in every tree.
Java pins the policy predicates pure before the flood runs, a
waiting writer blocks new readers while active readers keep the
writer out. The counter-lanes pin the failure mode: lua runs the
same flood without the pending-writer rule and the writer's single
acquisition lands only after all 1600 reader sections.

#listing("patterns-concurrency-distributed/samples-c/src/Ch09/starvation.c", first: 45, last: 77, caption: [C, the hand-rolled writer-preferring rwlock, readers wait while a writer is active or pending, the policy is the while condition])

#listing("patterns-concurrency-distributed/samples/ch09/hazards.go", first: 44, last: 80, caption: [Go, 8 readers in a tight loop, one writer counting acquisitions])

#listing("patterns-concurrency-distributed/samples-java/src/Ch09/Starvation.java", first: 31, last: 71, caption: [Java, the rwlock hand-rolled on a monitor because ReentrantReadWriteLock documents no reader fencing, the while condition is the policy])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch09/Starvation.cs", first: 8, last: 43, caption: [C\#, ReaderWriterLockSlim, the documented fairness policy that favors writers])

#listing("patterns-concurrency-distributed/samples-js/src/ch09-starvation.mjs", first: 9, last: 60, caption: [JavaScript, the rw lock as one fifo of requests, the pending-writer count is what stops read grants from cutting in line])

#listing("patterns-concurrency-distributed/samples-py/src/Ch09/starvation.py", first: 18, last: 54, caption: [Python, the rwlock built on a Condition, read_allowed excludes readers once a writer waits])

#listing("patterns-concurrency-distributed/samples-lua/ch09_starvation.lua", first: 59, last: 107, caption: [Lua, the priority rule behind a flag so one walk shows both worlds, handoff prefers the oldest writer])

The `sync.RWMutex` documentation states the guarantee being
exercised: if a goroutine calls `Lock` while readers hold it,
concurrent calls to `RLock` block until that writer has acquired and
released. The reader flood cannot starve the writer, and the price
is printed in the same paragraph: recursive read locking is
prohibited, because a reentrant reader could wedge a pending writer
forever. Choosing `RWMutex` over `Mutex` is choosing this scheduling
policy as much as any performance. The policy is exactly what the
hand-rolled lanes encode in their wait conditions, C and python
because `threads.h` and the python stdlib ship no rwlock at all,
java because `ReentrantReadWriteLock` documents no fencing of new
readers behind a pending writer, so fairness becomes a policy you
implement and can read off the while
loop. C\# documents the same writer preference for
`ReaderWriterLockSlim`. Javascript and lua have no kernel to blame,
so their floods are coroutine choreography, and the js lane keeps
one fifo of requests where the pending-writer count is the
priority, a read request enqueued while a writer waits is granted
only after it.

#diagram([the writer announces, new readers queue behind it], length: 13pt, {
  cdraw.content((0.6, 4.2), [readers], size: 6.5pt)
  cdraw.line((1, 3.4), (22, 3.4), stroke: 1pt)
  cdraw.rect((1, 3.0), (2.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((1.9, 3.4), [R], size: 6pt)
  cdraw.rect((3.0, 3.0), (4.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 3.4), [R], size: 6pt)
  cdraw.rect((5.0, 3.0), (6.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 3.4), [R], size: 6pt)
  cdraw.rect((7.6, 3.0), (15, 3.8), radius: 0.02, stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((11.3, 3.4), [new RLocks blocked], size: 6pt)
  cdraw.rect((15.4, 3.0), (17.2, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((16.3, 3.4), [R], size: 6pt)
  cdraw.content((0.6, 1.4), [writer], size: 6.5pt)
  cdraw.line((1, 0.6), (22, 0.6), stroke: 1pt)
  cdraw.rect((6, 0.2), (11, 1.0), radius: 0.02, stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((8.5, 0.6), [Lock pending], size: 6pt)
  cdraw.rect((11.5, 0.2), (15, 1.0), fill: luma(205), radius: 0.02)
  cdraw.content((13.1, 0.6), [writer holds], size: 6pt)
  cdraw.content((11.5, -1.1), [recursive read locking is prohibited, a reentrant reader would wedge the pending writer forever], size: 6pt)
})

Livelock, the third cousin, is workers that keep waking and
retrying without progressing, two `TryLock` spinners politely
backing off forever. The detector story is the same as starvation,
a counter that never advances, and the cure is always the same
family: randomize backoff or serialize through a tie breaker.

== the detectors

The race detector remains the primary instrument. `go test -race`
instruments every memory access through shadow memory and vector
clocks, reports races the moment they happen at runtime, and the
documented cost is 2 to 20 times the execution time and 5 to 10
times the memory. Two limits to keep
straight: it finds races that execute, a racy path the tests never
walk is invisible to it, and it is unavailable on platforms without
the instrumentation, `wasm` among them. This platform adds a third
limit for the C lane: the clang that builds the samples has no
thread sanitizer binary for the msvc target, the asan staging
exists and tsan does not, the same wall the icpc book documents for
its C toolbox's sanitizer legs, #xref-to("icpc", "toolbox-c"). The
C tree earns its concurrency claims by construction instead, every
observed interleaving either scripted or invariant checked, the rule
chapter 1 stated, restated here because this is the chapter where a
detector would be missed most.

The dry run: 8 workers x 5000 increments through one lock total
exactly 40000, and every lane's contention instrument records at
least one event. The six new trees pin the total itself, while the
frozen go test enables the mutex profile at rate 1 and asserts only
a nonzero sample count. The six siblings count contention on an
instrumented lock because their runtimes expose nothing finer: C
counts trylocks that found the lock held, java counts tryLock
failures on a ReentrantLock before blocking, C\# counts
Monitor.TryEnter failures before blocking, javascript counts
acquisitions that queued on the promise-queue mutex, python counts
failed non-blocking acquires, lua counts parks and the waiter
queue's peak depth. The python, C\#, and java lanes add a forced
window, a holder announces while holding and a waiter probes after,
recording exactly 1 contended acquisition, and java's window is
airtight by construction, the release latch opens only after the
probe latch proves the waiter already found the lock held.

#listing("patterns-concurrency-distributed/samples-c/src/Ch09/contention.c", first: 65, last: 79, caption: [C, the instrumented acquire, a trylock that finds the lock held counts one contention event before blocking])

#listing("patterns-concurrency-distributed/samples/ch09/hazards.go", first: 83, last: 111, caption: [Go, contended section as bait, mutex profile enabled at rate 1])

#listing("patterns-concurrency-distributed/samples-java/src/Ch09/Contention.java", first: 26, last: 45, caption: [Java, the instrumented acquire, tryLock finds the lock held, count one contention then block, onContended reports the bounce])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch09/Contention.cs", first: 8, last: 35, caption: [C\#, TryEnter fails, count, then block, OnContended fires on the bounce itself])

#listing("patterns-concurrency-distributed/samples-js/src/ch09-contention.mjs", first: 10, last: 23, caption: [JavaScript, the mutex's own contended counter, how many acquisitions arrived while the lock was held])

#listing("patterns-concurrency-distributed/samples-py/src/Ch09/contention.py", first: 19, last: 31, caption: [Python, the profiled lock, a non-blocking acquire that fails counts one contended event])

#listing("patterns-concurrency-distributed/samples-lua/ch09_contention.lua", first: 30, last: 58, caption: [Lua, parks and queue depth on the lock itself, the counter exact under a scripted interleaving])

The test enables the mutex profile, runs 8 goroutines through
5000 contended lock cycles, and asserts
`pprof.Lookup("mutex").Count()` is nonzero, the profile is really
wired. In a live service the same profile, plus `block` for channel
and `goroutine` for dumps, rides the `/debug/pprof` endpoint of
`net/http/pprof` on the default mux, and the profile family's home
in this corpus is the runtime chapter, #xref-to("go", "profiling").

The python row points at its own runtime's instruments: cprofile
and, since 3.12, sys.monitoring, either of which shows the hot
function but neither of which surfaces per-acquisition contention,
which is why the lane counts, #xref-to("python", "profiling").

The lua row reaches for its real sampler, `debug.sethook` counting
hook fires, the counting profiler its book builds, the instrument
to reach for when stacks matter, while this lane's counters answer
the question the fixture asks, #xref-to("lua", "profiling").

The C row has no runtime profiler at all, so measurement discipline
replaces one, count the events you care about and read percentiles
off them, the habit the systems book's measurement chapter teaches,
#xref-to("c-os-cloud", "measurement").

Go 1.27 promotes the sharpest of the family to general
availability: the `goroutineleak` profile detects goroutines blocked
on channels, mutexes, or conds that garbage collection reachability
proves can never wake, the difference between "many goroutines" and
"many dead goroutines". Chapter 8's poll-the-count test catches
leaks eventually, this profile names them with stacks.

#diagram([three detectors, three mechanisms, one endpoint], length: 13pt, {
  cdraw.content((3.4, 7.15), [detector], size: 6.5pt)
  cdraw.content((9.8, 7.15), [mechanism], size: 6.5pt)
  cdraw.content((15.4, 7.15), [cost], size: 6.5pt)
  cdraw.content((20.6, 7.15), [rides at], size: 6.5pt)
  let cols = ((0.4, 6.4), (6.6, 13.0), (13.2, 17.6), (17.8, 23.4))
  let rows = (
    ([race detector], [shadow memory], [about 2x], [go test -race]),
    ([mutex, block], [sampled stacks], [nearly free], [/debug/pprof]),
    ([goroutine leak], [gc reachability], [ga in 1.27], [/debug/pprof]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.2 - i * 1.6
    for (j, cell) in row.enumerate() {
      let c = cols.at(j)
      cdraw.rect((c.at(0), y), (c.at(1), y + 1.4), fill: luma(235), radius: 0.02)
      cdraw.content(((c.at(0) + c.at(1)) / 2, y + 0.7), cell, size: 6pt)
    }
  }
  cdraw.content((11.9, -0.5), [the race detector only flags races on paths the tests actually execute], size: 6pt)
})

== synctest, deterministic time

`testing/synctest` runs a test inside a bubble where the `time`
package is fake and the clock advances only when every goroutine in
the bubble is durably blocked. Timers fire in order, instantly, and
a deadlock inside the bubble fails the test instead of hanging it,
an extension of the toolchain's own testing discipline,
#xref-to("go", "testing").

The dry run: `Backoff(6, 10ms)` walks 6 tries, the ladder doubles
10, 20, 40, 80, 160, 320, cumulative 10, 30, 70, 150, 310, 630,
total 630ms, and the run costs zero real sleep. The contract is
identical in all 7 trees. The bubble is go's tool and only go's: the
go lane runs inside `synctest.Test`, where the runtime refuses to
advance the clock while any participant can still run. The six
siblings rebuild the same rule by construction, C's discrete-event
scheduler jumps time to the earliest wake only once every
participant parks, java has no bubble and no coroutine to park
mid-function, so participants run as scripts of work and sleep
steps and a discrete scheduler sweeps one step per participant
while anyone still has work, jumping time to the earliest wake only
once everybody parks, C\#'s fake TimeProvider fires the earliest due
timer while its driver holds the clock for the continuations to
drain, javascript's timer queue fires only when nothing else can run
and reports a deadlock when nothing can, python advances its heap
clock only when the event loop's ready deque is empty, lua parks
lanes on a time-ordered event queue the runner pops in order.

#listing("patterns-concurrency-distributed/samples-c/src/Ch09/synctest.c", first: 60, last: 102, caption: [C, the bubble runner, someone still working holds time still, everyone parked jumps to the earliest wake])

#listing("patterns-concurrency-distributed/samples/ch09/hazards.go", first: 131, last: 140, caption: [Go, exponential backoff, 6 attempts, all schedule and no sleep])

#listing("patterns-concurrency-distributed/samples-java/src/Ch09/Synctest.java", first: 74, last: 124, caption: [Java, no coroutine to park mid-function, participants run as work and sleep scripts, time jumps to the earliest wake only once everybody parks])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch09/Synctest.cs", first: 3, last: 29, caption: [C\#, every delay is a Task.Delay on the injected TimeProvider, the ladder is schedule and no sleep])

#listing("patterns-concurrency-distributed/samples-js/src/ch09-synctest.mjs", first: 60, last: 112, caption: [JavaScript, runInBubble is the bubble port, fire the earliest timer when nothing else can run, deadlock says so])

#listing("patterns-concurrency-distributed/samples-py/src/Ch09/synctest.py", first: 22, last: 62, caption: [Python, the heap clock, advance only when the loop's ready deque is empty, the bubble rule])

#listing("patterns-concurrency-distributed/samples-lua/ch09_synctest.lua", first: 32, last: 74, caption: [Lua, run every ready lane to its next block, then advance to the earliest pending event])

The test side is half the fixture, and each tree answers with its
own test artifact: the frozen go test's bubble, the xunit and node
test files, and the check regions of the C, java, python, and lua
modules.

#listing("patterns-concurrency-distributed/samples-c/src/Ch09/synctest.c", first: 146, last: 165, caption: [C, the check region: the ladder and cumulative arrays exact, the clock advanced by exactly 630ms in 6 jumps])

#listing("patterns-concurrency-distributed/samples/ch09/hazards_test.go", first: 65, last: 81, caption: [Go, inside the bubble the full backoff ladder runs and the clock reads exactly 630ms])

#listing("patterns-concurrency-distributed/samples-java/src/Ch09/Synctest.java", first: 139, last: 168, caption: [Java, the check region: the two-sleeper interleaving pinned byte for byte, ladder and cumulative exact, the clock at 630 in 6 advances])

#listing("patterns-concurrency-distributed/samples-cs/tests/Ch09/SynctestTests.cs", first: 6, last: 56, caption: [C\#, xunit: the ladder exact, virtual time moved 630ms and no further, no scheduling slop])

#listing("patterns-concurrency-distributed/samples-js/test/ch09.test.mjs", first: 48, last: 57, caption: [JavaScript, node:test: backoff in the bubble, ladder and cumulative deep-equal, clock at 630])

#listing("patterns-concurrency-distributed/samples-py/src/Ch09/synctest.py", first: 100, last: 118, caption: [Python, the check region: ladder and cumulative exact, the bubble clock at 630, wall cost under half a second])

#listing("patterns-concurrency-distributed/samples-lua/ch09_synctest.lua", first: 76, last: 105, caption: [Lua, the row table: ladder and cumulative exact, the clock advanced exactly 630 in zero real time])

6 retries with a doubling base execute in microseconds of wall
time in every tree, and the bubble's clock reads exactly 630
milliseconds, the sum of the ladder, asserted as equality rather
than a bounded interval. That equality is what fake time buys:
timing behavior becomes value behavior. The boundaries are as
documented for the go lane: the test must be self contained, no
network, no goroutines outside the bubble, which is why the
in-memory transport of the raft capstone is channels instead of
sockets, it fits a bubble if the tests ever want one. The sibling
lanes inherit the same demand in their own grain, everything the
walk touches must resolve through the injected clock, one real
sleep hiding anywhere breaks the equality.

#diagram([wall clock microseconds, bubble clock exactly 630ms], length: 13pt, {
  cdraw.content((0.8, 4.4), [wall clock], size: 6.5pt)
  cdraw.line((1, 4.0), (12, 4.0), stroke: luma(100))
  cdraw.circle((3, 4.0), radius: 0.12, fill: luma(30))
  cdraw.content((8.4, 4.7), [6 sleeps run in microseconds], size: 6pt)
  cdraw.content((0.8, 1.6), [bubble clock], size: 6.5pt)
  cdraw.line((1, 1.0), (22, 1.0), stroke: luma(100))
  let marks = ((3.0, [10]), (6.5, [70]), (11.5, [310]), (21, [630]))
  for (x, label) in marks {
    cdraw.line((x, 0.8), (x, 1.2), stroke: luma(100))
    cdraw.content((x, 0.3), label, size: 6pt)
  }
  cdraw.content((11.5, 1.9), [cumulative ms, the ladder 10+20+40+80+160+320], size: 6pt)
  cdraw.content((11.5, -0.9), [a deadlock inside the bubble fails the test instead of hanging it], size: 6pt)
})

#callout("pitfall", "detectors are the gate, not decoration", [
  A concurrency suite without `-race` in its CI line is testing
  luck. The book's own chain splits the work: the pre-commit hook
  is gofmt and vet for speed, and the Makefile's `verify-go` runs
  the plain suite and then the race pass over every go module, so
  each chapter's race claim is machine-checked. The deeper
  repetition, `go test -race -count=2`, stays a workstation step
  run before a chapter ships. The sibling trees have no race
  detector to lean on, so their suites earn the same claims the
  other way, every interleaving scripted, every total exact, and
  the guards convert anything that might hang into a failure.
])

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [707], [libc plus threads.h, stdatomic.h],
  [fork order under mtx_t, trylock failures counted, a discrete-event bubble],
  [go], [110], [stdlib],
  [frozen reference lane, synctest the bubble only go has, mutex profile at rate 1],
  [java], [575], [jdk 27 stdlib],
  [monitor forks, the rwlock hand-rolled because ReentrantReadWriteLock documents no reader fencing, a script-swept bubble],
  [c\#], [147], [bcl],
  [a binary SemaphoreSlim fork, documented writer preference, TimeProvider delays],
  [javascript], [238], [node stdlib, one sibling module],
  [promise-queue mutex forks, one real setTimeout guard, a timer-queue bubble],
  [python], [382], [stdlib only],
  [real locks under the GIL, the rwlock a Condition, the bubble a heap clock],
  [lua], [687], [lib.lua harness],
  [the naive fork order a pinned 0-bite fixture, the guard on the virtual clock],
)

sources: go.dev/pkg/sync for the RWMutex writer guarantee and the
recursive read prohibition, go.dev/pkg/runtime for
`SetMutexProfileFraction`, go.dev/pkg/runtime/pprof for profile
lookup, go.dev/doc/go1.27 for the goroutine leak profile GA,
go.dev/pkg/testing/synctest for bubble semantics and `Sleep`,
go.dev/doc/articles/race_detector for the detector's mechanics and
limits, accessed 2026-09-08. Verified by the seven chapter legs: 5 C programs
with 55 embedded checks, `go test` at 5 tests in
`patternsbook/ch09`, 5 java programs with 42 embedded checks under
`samples-java/src/Ch09`, 7 xunit facts, node's 5 cases in
`test/ch09.test.mjs`, 5 python modules with 38 embedded checks, and
the lua runner's 19 ch09 rows.
