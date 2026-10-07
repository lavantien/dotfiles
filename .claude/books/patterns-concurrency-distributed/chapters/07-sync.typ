#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= sync primitives in depth

Chapter 6 established that synchronization is the only currency the
memory model accepts. This chapter is the price list, read in seven
voices: what each primitive in go's `sync` and `sync/atomic` buys in
its home grain, and what the same guarantee costs where the language
hands you more or less. C carries the locks of C23 `threads.h` raw and
pays for every convenience go wraps around them. Java splits the
family across three shelves, `synchronized` blocks, the
`java.util.concurrent` toolbox, and `VarHandle` fences. C\# finds
half the family native in the bcl, `Lazy`, `Interlocked`,
`ConcurrentDictionary`. Javascript runs one thread per realm and pays
in queue discipline where go pays in kernel waits, python threads
under the GIL with `threading.Condition` a near 1:1 mirror of `Cond`,
and lua schedules coroutines by hand, so its waits are parking lists
the driver owns. One artifact per primitive, seven trees, and the go
tests stay the frozen reference the six siblings cross-check.

== mutex and rwmutex

The mutex is the default tool because it is the tool that composes:
it guards an invariant, not a variable. The convention that keeps
guarded code auditable is on display in `SafeMap`, spelled seven
ways.

The dry run: 50 concurrent writers each set 100 values over 20 keys
and the map holds exactly 20 keys afterward, never a torn row, in
every tree that spawns real workers. The read-modify-write lane then
demands exact totals under the guard: 400 in C, 400 in java beside
2000 more through its lock-free `ConcurrentHashMap.compute`, 2000 in
C\#, 10 in javascript, 2000 in python, 5000 in lua, each tree at its
own fan-in. The frozen go test pins the key set and the under-lock
count, C\# matches that shape and pins the concurrent total, and go
alone leaves the increment totals to the siblings.

#listing("patterns-concurrency-distributed/samples-c/src/Ch07/safemap.c", first: 29, last: 70, caption: [C, the mutex is a field in the struct, find runs under it, and threads.h ships one flavor so the reader-writer split collapses])

#listing("patterns-concurrency-distributed/samples/ch07/syncdeep.go", first: 12, last: 47, caption: [Go, lock as a field beside its data, defer on every path, rwlock for reads])

#listing("patterns-concurrency-distributed/samples-java/src/Ch07/Safemap.java", first: 24, last: 53, caption: [Java, the lock an object field beside its map, synchronized the release, underLock the read-modify-write shape])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch07/Safemap.cs", first: 6, last: 39, caption: [C\#, ReaderWriterLockSlim beside the dictionary, try and finally on every path])

#listing("patterns-concurrency-distributed/samples-js/src/ch07-safemap.mjs", first: 7, last: 32, caption: [JavaScript, one thread cannot tear the map, underLock chains a promise tail so awaiting sections run alone])

#listing("patterns-concurrency-distributed/samples-py/src/Ch07/safemap.py", first: 16, last: 37, caption: [Python, the lock beside a plain dict, the with statement is the unlock])

#listing("patterns-concurrency-distributed/samples-lua/ch07_safemap.lua", first: 31, last: 44, caption: [Lua, a cooperative world makes the lock nominal, UnderLock is the promise the callback yields nothing])

Three rules do most of the work and every lane keeps them. The lock
lives in the same struct as the data, so the pairing is visible.
Every method locks and releases on every path, go through `defer`,
C\# through `finally`, java through the `synchronized` block's own
release, C through paired calls because it has neither. And
`RWMutex` is paid for only when readers outnumber writers and hold
the lock long enough for the read lock's bookkeeping to amortize, a
getter on a map is usually faster under a plain `Mutex` because
`RLock` is itself atomic work. `UnderLock` shows the
read-modify-write shape: when the operation spans check then act, the
caller gets the whole thing under one hold instead of two
acquisitions with a window between.

The lanes that lack a kernel split say so instead of faking one. C
has one mutex flavor in `threads.h`, so the whole structure rides it
and the row reads honest. Java parks the sample on plain
`synchronized` blocks, its `ReadWriteLock` left on the shelf, and
the file's divergence lane runs the same increments through
`ConcurrentHashMap.compute`, the atomic read-modify-write with no
lock in sight. C\# has the split and a documented writer
preference, chapter 9 cashes that in. Javascript cannot tear a map on
one thread, so its real hazard is the critical section that awaits:
control returns to the loop mid-update and other tasks interleave,
which is why `underLock` serializes through a promise chain and the
test pins unlocked interleaving losing 10 increments down to 1.
Python puts a plain `threading.RLock` beside a plain dict and leans
on the with statement. Lua's lock is nominal, there is no preemption
to exclude, so `UnderLock` buys a different guarantee, the callback
yields nothing, and the lua file pins the counterpoint: a callback
that yields under it tears exactly like go code that slept holding
the mutex.

The violation worth naming in the reference lane: copying a struct
that contains a mutex copies the lock's state, and `go vet` flags it,
which is why guarded types are always handled by pointer.

#diagram([the lock lives in the struct, beside the data it guards], length: 13pt, {
  cdraw.rect((0, 2.6), (9, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.5, 5.5), [SafeMap], size: 6.5pt)
  cdraw.rect((0.4, 2.9), (4.8, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((2.6, 4.0), [mu RWMutex], size: 6pt)
  cdraw.rect((5.2, 2.9), (8.6, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((6.6, 4.0), [m map], size: 6pt)
  cdraw.content((4.5, 2.0), [mu guards m, the pairing is visible], size: 6pt)
  cdraw.rect((11, 3.2), (22, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.5, 5.5), [Set, UnderLock], size: 6.5pt)
  cdraw.content((16.5, 4.35), [write lock, defer unlock], size: 6pt)
  cdraw.rect((11, 0.3), (22, 2.9), fill: luma(235), radius: 0.02)
  cdraw.content((16.5, 2.4), [Get, Len], size: 6.5pt)
  cdraw.content((16.5, 1.25), [RLock when reads dominate], size: 6pt)
})

== once, the lazy family

Chapter 2 used `OnceValue` for lazy creation. The family has three
members, `OnceFunc` for effects, `OnceValue` and `OnceValues` for
results, and the memory model gives them their teeth: the completion
of the one call to f is synchronized before any call returns, which
is precisely the edge double checked locking lacks.

The dry run: `Lazy("a1b22c333")` folds every digit into one running
number and returns 122333, the parse runs exactly once, and 20
concurrent callers all read the value. The six new trees count the
parse and pin exactly 1. The go lane's frozen file carries no counter,
its test pins the value across the same 20 callers.

#listing("patterns-concurrency-distributed/samples-c/src/Ch07/once.c", first: 24, last: 54, caption: [C, call_once over a once_flag, the target pointer installed at init because call_once carries no context argument])

#listing("patterns-concurrency-distributed/samples/ch07/syncdeep.go", first: 49, last: 61, caption: [Go, one parse, concurrent callers, no flag anywhere])

#listing("patterns-concurrency-distributed/samples-java/src/Ch07/Once.java", first: 24, last: 58, caption: [Java, double-checked locking on a volatile flag, the value published before the flag flips])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch07/Once.cs", first: 6, last: 33, caption: [C\#, Lazy with ExecutionAndPublication is the once family, the counter makes exactly-once observable])

#listing("patterns-concurrency-distributed/samples-js/src/ch07-once.mjs", first: 6, last: 36, caption: [JavaScript, the check-and-fill is one synchronous block no other task can enter, the memo closes the race by construction])

#listing("patterns-concurrency-distributed/samples-py/src/Ch07/once.py", first: 16, last: 48, caption: [Python, the double-checked flag lives under the lock, the value publishes before the flag flips])

#listing("patterns-concurrency-distributed/samples-lua/ch07_once.lua", first: 32, last: 64, caption: [Lua, a running state with a waiter list, callers that overlap the parse park and wake holding the value])

Each tree spends the guarantee differently. Go's `OnceValue` ships
the edge in the standard library, pre-generics go needed a page of
boilerplate for it. C finds the direct standard analog in `call_once`
and `once_flag`, paying one indirection, the init function reads its
target through a pointer installed before any concurrent caller
exists. Java writes double-checked locking out longhand, the fast
path reading a `volatile` flag and the slow path rechecking under the
lock, publication safe because the flag's write is the last step.
C\# buys the whole thing off the shelf with `Lazy<T>` in
`ExecutionAndPublication` mode, publication serialized by the lazy
machinery itself. Javascript closes the window by construction, the
memoizing check-and-fill never awaits, so no other task can enter it,
and the 20 callers is a walk, not a race. Python writes the
classic shape out longhand, flag and value under one lock, because
that shape is the lesson. Lua has no preemption, so once is a
cooperative protocol: the first caller flips to running, callers that
arrive inside the parse window park as waiters and wake holding the
finished value, which the scheduler drives deterministically.

#diagram([one caller runs f, the rest wait and replay the value], length: 13pt, {
  cdraw.content((0.6, 3.85), [caller 1], size: 6.5pt)
  cdraw.line((1, 3.4), (21, 3.4), stroke: 1pt)
  cdraw.circle((3.5, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((3.5, 4.0), [calls f], size: 6pt)
  cdraw.rect((5.5, 2.9), (11.5, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((8.5, 3.4), [f runs once], size: 6pt)
  cdraw.circle((14.6, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((14.8, 4.0), [returns 122333], size: 6pt)
  cdraw.content((0.2, 1.05), [callers 2..N], size: 6.5pt)
  cdraw.line((1, 0.6), (5.4, 0.6), stroke: 1pt)
  cdraw.line((11.6, 0.6), (21, 0.6), stroke: 1pt)
  cdraw.circle((3.5, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((3.5, 1.2), [call f], size: 6pt)
  cdraw.rect((5.5, 0.1), (11.5, 1.1), radius: 0.02, stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((8.5, 0.6), [wait, then return], size: 6pt)
  cdraw.circle((14.6, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((14.6, 1.2), [same value], size: 6pt)
  cdraw.content((11, -0.9), [OnceFunc for effects, OnceValue and OnceValues for results], size: 6pt)
})

== cond, waiting for a predicate

`sync.Cond` is the primitive every hand rolled wait loop wants to
be. A `Wait` atomically releases the lock and sleeps, a `Signal`
wakes one waiter, `Broadcast` wakes all, and the rule that separates
correct code from deadlocks is the recheck loop, because a wake means
the predicate changed once, not that it is still true.

The dry run: capacity 3, puts 1, 2, 3 land, a fourth producer blocks
until a take frees a slot, two consumers drain, close unblocks both,
and the 4 puts total survive as the multiset 1, 2, 3, 4 summing to
10, with a take after close reporting false. C, java, javascript,
python, and lua pin the drained multiset 2, 3, 4, the go and C\#
lanes pin the sum and the closed take.

#listing("patterns-concurrency-distributed/samples-c/src/Ch07/cond.c", first: 47, last: 79, caption: [C, two cnd_t and one mutex, while loops around every wait, broadcast on close])

#listing("patterns-concurrency-distributed/samples/ch07/syncdeep.go", first: 64, last: 111, caption: [Go, bounded queue: two conds, one mutex, while loops around every wait])

#listing("patterns-concurrency-distributed/samples-java/src/Ch07/Cond.java", first: 26, last: 74, caption: [Java, ReentrantLock.newCondition twice, one condition per predicate, the go layout native])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch07/Cond.cs", first: 8, last: 55, caption: [C\#, one monitor, one wait set, PulseAll everywhere because every sleeper rechecks its own predicate])

#listing("patterns-concurrency-distributed/samples-js/src/ch07-cond.mjs", first: 6, last: 44, caption: [JavaScript, waiters are promise resolvers, signal wakes one, close resolves everyone on both sides])

#listing("patterns-concurrency-distributed/samples-py/src/Ch07/cond.py", first: 17, last: 49, caption: [Python, two asyncio conditions over one lock, the walk parks puts and consumers on queue state])

#listing("patterns-concurrency-distributed/samples-lua/ch07_cond.lua", first: 47, last: 90, caption: [Lua, waiter lists per predicate, park is a yield to the scheduler, Close wakes every parked consumer])

`BoundedQueue` is the canonical shape, producers sleep on `notFull`,
consumers on `notEmpty`, both conds share the queue's mutex because
the predicates read the same state. `Close` broadcasts so every
sleeping consumer wakes, rechecks, sees the closed flag, and exits.
The scripted walks drive the interesting interleavings directly: the
producer past capacity parks until a take frees a slot, then two
consumers drain everything and unblock on close, and the accounting
lands on exactly the values that were ever put.

The seven idioms all enforce the same wake discipline, that a wake only
means look again. C spends `cnd_wait` with the mutex held and
rechecks in a while loop, and the same zero-waiter forgetfulness that
makes a naked signal a losing bet is documented for win32 condition
variables in the systems book, #xref-to("c-os-cloud", "threads").
Java builds the two-condition shape native,
`ReentrantLock.newCondition` called twice, one wait set per
predicate, so its `signalAll` reaches only the sleepers that share
the waker's predicate.
C\# has one wait set per monitor where go used two conds, so every
wake is `PulseAll` and every sleeper rechecks its own predicate, the
queue works with one wait set because the predicates share one lock.
Javascript parks waiters as promise resolvers, signal resolves one,
close resolves everyone, and the recheck is the loop the await sits
in. Python's `threading.Condition` in its threaded form is the near
1:1 mirror of go's cond, wait, notify, notify_all under one lock, the
asyncio form the sample rides swaps the parking for the event loop,
#xref-to("python", "threads") covers both. Lua parks the running
coroutine on a waiter list the scheduler owns, and close walks the
list back into the ready queue.

The honest comparison: channels can express this queue too, and for
a queue, channels usually win on clarity. `Cond` earns its keep when
the wakeup condition is a predicate over shared state, with no
arriving value to hand off, and the pool of waiters must re-evaluate
it.

#diagram([queue states, waits at the edges, wake means look again], length: 13pt, {
  cdraw.rect((0, 3.2), (4, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((2, 4.0), [empty], size: 6.5pt)
  cdraw.rect((7, 3.2), (11, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((9, 4.0), [partial], size: 6.5pt)
  cdraw.rect((14, 3.2), (18, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((16, 4.0), [full], size: 6.5pt)
  cdraw.line((4, 4.4), (7, 4.4), stroke: luma(100))
  cdraw.line((6.7, 4.55), (7, 4.4), stroke: luma(100))
  cdraw.line((6.7, 4.25), (7, 4.4), stroke: luma(100))
  cdraw.content((5.5, 4.95), [Put], size: 6pt)
  cdraw.line((11, 4.4), (14, 4.4), stroke: luma(100))
  cdraw.line((13.7, 4.55), (14, 4.4), stroke: luma(100))
  cdraw.line((13.7, 4.25), (14, 4.4), stroke: luma(100))
  cdraw.content((12.5, 4.95), [Put], size: 6pt)
  cdraw.line((14, 3.6), (11, 3.6), stroke: luma(100))
  cdraw.line((11.3, 3.75), (11, 3.6), stroke: luma(100))
  cdraw.line((11.3, 3.45), (11, 3.6), stroke: luma(100))
  cdraw.content((12.5, 2.95), [Take], size: 6pt)
  cdraw.line((7, 3.6), (4, 3.6), stroke: luma(100))
  cdraw.line((4.3, 3.75), (4, 3.6), stroke: luma(100))
  cdraw.line((4.3, 3.45), (4, 3.6), stroke: luma(100))
  cdraw.content((5.5, 2.95), [Take], size: 6pt)
  cdraw.content((2, 6.05), [Take waits notEmpty], size: 6pt)
  cdraw.content((16, 6.05), [Put waits notFull], size: 6pt)
  cdraw.content((9, 1.6), [Close broadcasts, every waiter wakes, rechecks the closed flag, exits], size: 6pt)
})

== sync.map

`sync.Map` is not a faster map, it is a map for two specific access
shapes: write-once-read-many caches with disjoint keys, and
append-only sets. Its superpower over `Mutex` plus `map` is the
atomic read-mostly path plus fused operations like `LoadOrStore`,
which answer whether this caller created the entry.

The dry run: one key through 1000 racing canonical calls
creates exactly once, every caller walks away holding the same
canonical value, and a distinct key creates a second time. All seven
trees pin created 1 on the 1000, the siblings also pin the
identity of the returned handle.

#listing("patterns-concurrency-distributed/samples-c/src/Ch07/intern.c", first: 48, last: 68, caption: [C, find-or-insert under the mutex by hand, only the caller that performed the store counts as the creator])

#listing("patterns-concurrency-distributed/samples/ch07/syncdeep.go", first: 114, last: 131, caption: [Go, load or store reports the winner])

#listing("patterns-concurrency-distributed/samples-java/src/Ch07/Intern.java", first: 26, last: 40, caption: [Java, computeIfAbsent is the native load-or-store, the mapping function runs at most once per key])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch07/Intern.cs", first: 8, last: 24, caption: [C\#, ConcurrentDictionary.TryAdd is LoadOrStore, the winner is the only caller that counts as a creation])

#listing("patterns-concurrency-distributed/samples-js/src/ch07-intern.mjs", first: 6, last: 27, caption: [JavaScript, loadOrStore as one synchronous block, the loaded flag is the winner report])

#listing("patterns-concurrency-distributed/samples-py/src/Ch07/intern.py", first: 16, last: 32, caption: [Python, check-then-install under the lock, the created counter increments only on the insert path])

#listing("patterns-concurrency-distributed/samples-lua/ch07_intern.lua", first: 30, last: 61, caption: [Lua, the lookup-or-install as one non-yielding step, and the torn check-yield-store that loses it])

The fused check-then-act is the whole value: the same code with a
mutex map needs the lock held across the check, and the same code
with a plain map is a race. C writes find-or-insert under the mutex
and returns the canonical pointer, only the inserting caller counts a
creation, which is `LoadOrStore` disassembled to its parts. Java's
`computeIfAbsent` is the fused operation itself, the mapping function
guaranteed at most one run per key, and the file pins the identity
with `==` across 1000 concurrent callers each passing a freshly
built string. C\#
reaches for `ConcurrentDictionary.TryAdd`, the bcl row of the same
contract, and the wider concurrent-collection surface it belongs to
is the stdlib tour's territory, #xref-to("csharp-net", "stdlib2").
Javascript has one thread per realm, so check-then-set inside one
synchronous block is already atomic and the lane says so, no
concurrent variant exists to build. Python runs the same shape under
its lock, the GIL would make the plain dict version mostly safe but
the lock is what makes it stated. Lua demonstrates both sides: the
non-yielding canonical wins exactly once across 10 interleaved
lanes, and the torn version that yields between check and store hands
every lane its own creation, 10 winners where 1 is correct.

Outside those two shapes sync.Map loses to the guarded map, the
builtin map got swiss tables in go 1.24 and the spread only widened.

#diagram([1000 racing calls, exactly one created = true], length: 13pt, {
  for k in range(6) {
    let x = 1.4 + k * 2.3
    cdraw.content((x, 4.3), [g#k], size: 6pt)
    cdraw.line((x, 3.95), (8.2, 2.35), stroke: luma(220))
  }
  cdraw.line((1.4, 3.95), (7.4, 2.3), stroke: luma(100))
  cdraw.content((1.4, 4.95), [the one winner], size: 6pt)
  cdraw.rect((7, 0.2), (15, 2.2), fill: luma(205), radius: 0.02)
  cdraw.content((11, 1.7), [LoadOrStore(key, key)], size: 6.5pt)
  cdraw.content((11, 0.7), [one key, 1000 calls], size: 6pt)
  cdraw.content((18.6, 1.2), [one winner per key,#linebreak()losers load its entry], size: 6pt)
})

== atomics, beyond the counter

Chapter 6 used atomics as a counter. The general form is the
compare-and-swap loop, read, compute, try to install, retry if the
world moved.

The dry run: 64 racers each offer their racer number times 7 and the
shared maximum lands on the true max 448 in every tree, the loop
terminates because every failed exchange means someone else
installed a larger or equal candidate. The scripted lanes pin forced retries, 2 failed
exchanges in C, java, and C\#, 1 scripted move in javascript, 2 lost
installs over 3 loads in python, 3 retries in lua. A candidate at or
below the current value returns without ever attempting the swap.

#listing("patterns-concurrency-distributed/samples-c/src/Ch07/cas.c", first: 21, last: 52, caption: [C, atomic_compare_exchange_strong in the loop, the scripted interloper raises the target between load and exchange])

#listing("patterns-concurrency-distributed/samples/ch07/syncdeep.go", first: 131, last: 142, caption: [Go, cas loop raising a shared maximum])

#listing("patterns-concurrency-distributed/samples-java/src/Ch07/Cas.java", first: 22, last: 65, caption: [Java, VarHandle.compareAndSet in the loop, the scripted interloper raising the target between load and install])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch07/Cas.cs", first: 4, last: 36, caption: [C\#, Interlocked.CompareExchange behind a virtual swap so a scripted test can force retries])

#listing("patterns-concurrency-distributed/samples-js/src/ch07-cas.mjs", first: 27, last: 54, caption: [JavaScript, the scripted cell moves the value on cue so the swap fails and the caller must re-read])

#listing("patterns-concurrency-distributed/samples-py/src/Ch07/cas.py", first: 37, last: 59, caption: [Python, the rigged cell sabotages between load and install, the retry count is the pinned lesson])

#listing("patterns-concurrency-distributed/samples-lua/ch07_cas.lua", first: 30, last: 57, caption: [Lua, the loop with an injected cooperative window, retries counted only when the lane is slow])

The lanes earn the loop's atomicity differently. C and C\# hold the
real primitive, `atomic_compare_exchange_strong` and
`Interlocked.CompareExchange`, and pin the retry count by moving the
target inside the window, an interloper in C, a flaky subclass in
C\#. Go writes the same loop over `atomic.Int64`. Java holds the
primitive twice over, `VarHandle.compareAndSet` over a plain field
for the ladder lane and `AtomicLong` for the 64 racers, its scripted
interloper built exactly like C's. Javascript has
`Atomics.compareExchange` for shared-array-buffer cells, and this
lane's cell is plain, atomic by event-loop construction, with a
scripted subclass that pretends another racer installed first.
Python exposes no public compare-and-swap on ints, so the honest row
runs the identical loop under a lock and says the GIL is the cas, the
scripted rig still measures the retries. Lua has no atomics at all,
the cooperative lane injects the yield between load and swap and
counts the retries it causes, the lesson made visible where other
languages prevent it. The shape fails everywhere for the same
reasons: when the retry can livelock or the invariant spans two
words, it is a mutex wearing a disguise.

#flow(
  [read, compute, try to install, retry if the world moved],
  node((0, 0), [load current]),
  node((2.4, 0), [candidate#linebreak()<= current?]),
  node((5.0, 0), [try the CAS]),
  node((7.4, 1.0), [done]),
  edge((0, 0), (2.4, 0), "-|>"),
  edge((2.4, 0), (5.0, 0), "-|>", label: [no]),
  edge((2.4, 0), (7.4, 1.0), "-|>", bend: 25deg, label: [yes]),
  edge((5.0, 0), (7.4, 1.0), "-|>", label: [swapped]),
  edge((5.0, 0), (0, 0), "-|>", bend: 40deg, label: [lost the race, retry]),
)

== waitgroup and the error group

`WaitGroup.Go`, added in go 1.25, folds the add, the goroutine, and
the done into one call and removes the classic miscount where `Add`
runs after `Wait` has already passed zero. The pinned error group
keeps the classic `wg.Add` + `go` + `defer wg.Done` deliberately:
its tasks return errors, `WaitGroup.Go` accepts a plain `func()`,
so each task would need a wrapping closure anyway, and the
three-line form puts the error append where the goroutine starts.
Under the same wait the pattern grows an error slice, and this
sample closes with a compact error group.

The dry run: a clean task, a task failing alpha, a task failing
beta. Waiting joins both names into one error, the first-error view
matches, and a clean group waits out to nothing. C, java, C\#,
python, and lua pin alpha as the first error through a causal edge,
a first-error latch, a submission-order slot, gather order, and a
scripted yield, the go and javascript lanes accept either failure as
first because their landing order is genuinely free.

#listing("patterns-concurrency-distributed/samples-c/src/Ch07/errgroup.c", first: 63, last: 110, caption: [C, one thread per task, the done and error condvars, and the causal edge that makes the second failure observably second])

#listing("patterns-concurrency-distributed/samples/ch07/syncdeep.go", first: 145, last: 177, caption: [Go, go and wait, join every error or surface the first])

#listing("patterns-concurrency-distributed/samples-java/src/Ch07/Errgroup.java", first: 30, last: 68, caption: [Java, tasks on the virtual-thread executor, pool.close the wait edge, a first-error latch behind the group])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch07/Errgroup.cs", first: 7, last: 41, caption: [C\#, a slot per task at Go time, WhenAll is the barrier, both views deterministic in submission order])

#listing("patterns-concurrency-distributed/samples-js/src/ch07-errgroup.mjs", first: 5, last: 36, caption: [JavaScript, tasks are promises, allSettled semantics by hand, the joined error one per line])

#listing("patterns-concurrency-distributed/samples-py/src/Ch07/errgroup.py", first: 17, last: 42, caption: [Python, gather with return_exceptions keeps submission order, GroupError is the errors.Join analog])

#listing("patterns-concurrency-distributed/samples-lua/ch07_errgroup.lua", first: 33, last: 69, caption: [Lua, the last Done wakes the waiter, failures keep their landing order, the walk scripts it])

Every lane builds the same 3 parts, spawn, barrier, collect, and
differs in what makes the first error deterministic. Go and
javascript race the landing, so their honest assertion accepts either
failure as first. C makes the order causal, the beta task blocks
until alpha's error has landed, an edge in place of a sleep. Java
plays the same trick with a `CountDownLatch`, its beta task waiting
for the first error to land, and its barrier is `pool.close()`, the
virtual-thread executor waiting out every submitted task. C\#
assigns each task its slot at submission, so the collected array is
ordered no matter how the pool schedules. Python's `gather` preserves
submission order in its results even with `return_exceptions`, and
lua scripts the yields so the landing order is part of the fixture.
The x/sync `errgroup` packages go's version with context
cancellation, and the capstone's test harness will reuse this shape
to run a 5 node cluster to quiescence.

#flow(
  [spawn per task, one barrier, every error joined],
  node((0, 1.2), [Go(task1)]),
  node((0, 0), [Go(task2)]),
  node((0, -1.2), [Go(task3)]),
  node((2.8, 0), [wg.Wait]),
  node((5.6, 0), [errors.Join,#linebreak()or the first error]),
  edge((0, 1.2), (2.8, 0), "-|>"),
  edge((0, 0), (2.8, 0), "-|>"),
  edge((0, -1.2), (2.8, 0), "-|>"),
  edge((2.8, 0), (5.6, 0), "-|>"),
)

#callout("pitfall", "pool", [
  `sync.Pool` round trips temporary objects, buffers mostly, and
  two facts bound its usefulness: the GC may drop pool contents at
  any allocation cycle, so a pool is a cache, never a store, and
  `Put` hands out no guarantee the same object comes back. Pools
  earn their keep inside hot allocation loops measured by chapter
  9's profiling, not as a general object recycling facility. The
  idea needs a garbage collector to be safe, so the other six
  lanes have nothing to pool: C would be a free list you manage,
  java's jdk ships no pool type of its own, and the dynamic three
  hand allocation to their runtimes.
])

#diagram([a pool lives between gc cycles, a cache and never a store], length: 13pt, {
  cdraw.line((1, 1), (22, 1), stroke: luma(100))
  cdraw.line((13, -0.2), (13, 2.4), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((13, 2.9), [gc], size: 6.5pt)
  cdraw.circle((3, 1), radius: 0.12, fill: luma(30))
  cdraw.content((3, 1.75), [alloc], size: 6pt)
  cdraw.circle((5.6, 1), radius: 0.12, fill: luma(30))
  cdraw.content((5.6, 0.3), [Put], size: 6pt)
  cdraw.circle((8.4, 1), radius: 0.12, fill: luma(30))
  cdraw.content((8.4, 1.75), [Get returns it], size: 6pt)
  cdraw.circle((11, 1), radius: 0.12, fill: luma(30))
  cdraw.content((11, 0.3), [Put again], size: 6pt)
  cdraw.circle((16.5, 1), radius: 0.12, fill: luma(30))
  cdraw.content((16.5, 1.75), [Get allocates fresh], size: 6pt)
  cdraw.content((11.5, -0.9), [the pool may empty at any allocation cycle, no guarantee the same object returns], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [677], [libc plus threads.h, stdatomic.h],
  [one mutex flavor so the rw split collapses, call_once reads through a pointer],
  [go], [142], [stdlib],
  [frozen reference lane, OnceValue off the shelf, errgroup keeps classic wg.Add],
  [java], [517], [jdk 27 stdlib],
  [double-checked locking on a volatile flag, two conditions from newCondition, computeIfAbsent as the load-or-store],
  [c\#], [236], [bcl],
  [Lazy in ExecutionAndPublication, TryAdd is LoadOrStore, a virtual swap for cas],
  [javascript], [179], [node stdlib],
  [one thread per realm, underLock chains a promise tail, the memo never awaits],
  [python], [341], [stdlib only],
  [double-checked flag under the lock, the GIL is the cas, gather preserves order],
  [lua], [777], [lib.lua harness],
  [the lock nominal, once a waiter-list protocol, the cas window an injected yield],
)

sources: go.dev/pkg/sync for `RWMutex`, the `Once` family, `Cond`,
`Map`, `Pool`, and `WaitGroup.Go` including its memory model note,
go.dev/pkg/sync/atomic for CAS semantics, go.dev/ref/mem for the
Once and mutex edges quoted, accessed 2026-09-08. Verified by the
seven chapter legs: 6 Ch07 C programs with 339 embedded checks,
`go test` at 6 tests in `patternsbook/ch07`, 6 Ch07 java programs
with 42 checks under `run-java-samples`, 14 xunit facts, node's 13
cases in `test/ch07.test.mjs`, 6 python modules with 43 embedded
checks, and the lua runner's 25 ch07 rows.
