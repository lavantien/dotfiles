#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= concurrency: threads to atomics

Rust's pitch is a compile-time one: the same ownership machinery that
decides memory safety also decides what may cross a thread boundary.
A `thread::spawn` demands a closure that is `Send` and `'static`, so
sharing mutable state by accident is a compile error before it is a
race. This chapter walks the ladder in order: spawn and join, scoped
threads for borrowing (since 1.63), mpsc channels, `Mutex`, `RwLock`,
and `Condvar`, then atomics with every ordering demonstrated by a
sample whose output carries the proof. The memory model underneath is
#xref-to("patterns", "concfundamentals")'s subject, this chapter covers
the rust surfaces and stays honest about what safe rust does and does
not prevent.

#diagram([safe rust layers the guarantees, the primitives below stay os shaped], length: 13pt, {
  cdraw.rect((0.3, 3.6), (11.3, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.05), [the borrow checker], size: 6.5pt)
  cdraw.content((5.8, 5.1), [Send and Sync gate every spawn,], size: 6pt)
  cdraw.content((5.8, 4.1), [data races are compile errors], size: 6pt)
  cdraw.rect((0.3, 0.3), (11.3, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 2.65), [std::thread and std::sync], size: 6.5pt)
  cdraw.content((5.8, 1.7), [spawn, scope, mpsc, Mutex, RwLock,], size: 6pt)
  cdraw.content((5.8, 0.75), [Condvar, atomics with orderings], size: 6pt)
  cdraw.rect((0.3, -3.0), (11.3, -0.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, -1.15), [os threads], size: 6.5pt)
  cdraw.content((5.8, -2.1), [1:1, preemptively scheduled], size: 6pt)
  cdraw.line((5.8, 3.3), (5.8, 3.55), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((5.8, 0.05), (5.8, 0.25), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.1, 4.9), [no green threads, no runtime:], size: 6pt)
  cdraw.content((13.1, 4.0), [async is chapter 14], size: 6pt)
  cdraw.content((13.1, 1.7), [every primitive here is a], size: 6pt)
  cdraw.content((13.1, 0.8), [thin wrap over the os], size: 6pt)
})

== spawn, join, and move

`thread::spawn` takes a closure and returns a `JoinHandle<T>` where T
is whatever the closure returns. The handle is the only rope: `join()`
waits for the thread and yields its value as `Result<T, Box<dyn Any +
Send>>`, and the `Err` arm is how a panic crosses back, with the
payload downcastable to what was thrown. Closures capture by reference
by default, and a spawned closure must own its world for `'static`, so
the normal shape is the `move` keyword transferring every capture.

#listing("rust/samples/src/Ch13/SpawnJoin.rs", first: 22, last: 53, caption: [spawn returns a value through join, move transfers captures, panics cross as Err])

The three checks the sample prints: the loop computes 333,833,500 which
is the closed form for the sum of the first 1000 squares, the vector
moves in and its length comes back, and a `panic!("boom")` joins as an
`Err` whose payload downcasts to the thrown `&str`. A silent panic hook
keeps the intentional panic off stderr, the same discipline the
poisoning sample below uses.

`Builder` configures the spawn: a name for diagnostics, a stack size.
Parking is the minimal handshake, and it is token based: `unpark` that
arrives before `park` is remembered, so the ordering race between the
two calls cannot lose the wakeup.

#listing("rust/samples/src/Ch13/SpawnJoin.rs", first: 55, last: 75, caption: [a named thread, and the park and unpark token handshake])

`available_parallelism`, since 1.59, reads the scheduler hint rather
than `std::thread::count` folklore. Measured 2026-10-13 on the pinned
build: 20. Fixed thread counts rule every sample in this book, joined
before any assert, no assertion ever rides on timing.

== scoped threads, borrowing since 1.63

`spawn` demands `'static` because the child can outlive its parent.
Most real parallelism wants the opposite: borrow local data, join
before the function returns. `thread::scope`, stable since 1.63,
guarantees every spawned child joins before the scope closure returns,
so borrows of stack locals are sound and the compiler accepts them.

#listing("rust/samples/src/Ch13/ScopedThreads.rs", first: 16, last: 41, caption: [split_at_mut hands each scoped thread half a buffer, no Arc, no clone])

Two details the borrow checker enforces and the sample makes visible.
First, `split_at_mut` partitions the buffer into non-overlapping
mutable borrows, the shape every data-parallel loop wants. Second, a
mutable borrow captured by a spawned closure lasts the whole scope even
after that handle joins, so `logs[2] = 30` above had to move after the
scope: within one scope you partition borrows, you do not reuse them.

Shared borrows fan out freely. One `&String` reaches four threads with
no `Arc` in sight, because shared references are `Copy`:

#listing("rust/samples/src/Ch13/ScopedThreads.rs", first: 55, last: 83, caption: [a shared borrow fans out, scopes nest])

Before 1.63 the same program needed `Arc<Vec<_>>` with clones counted
at runtime. Scope moves that bookkeeping to the type system, and the
corpus api in chapter 19 prefers it for request fan-out.

== channels: mpsc

`std::sync::mpsc` is multi-producer, single-consumer. `channel()`
returns an unbounded `(Sender, Receiver)`: `send` never waits for a
receiver, values queue without bound, and delivery order per sender is
preserved. The lifecycle errors are part of the type story: a send
after the receiver drops is `SendError`, and iteration ends when the
last sender drops.

#listing("rust/samples/src/Ch13/Channels.rs", first: 18, last: 51, caption: [order, disconnection, and the three try_recv states])

Fan-in is the everyday shape: clone the sender per producer, join the
producers, drop the original, drain the receiver. The assert compares
against a value set built independently of the channel, so exactly
1000 arrivals of exactly the right values is the check, order across
producers is asserted only after sorting because interleave order is
scheduler business.

#listing("rust/samples/src/Ch13/Channels.rs", first: 53, last: 78, caption: [fan-in, four producers into one receiver])

`sync_channel(n)` is the bounded sibling: capacity n accepts n sends
with no receiver, the n+1st blocks until space frees. Capacity 0 is a
rendezvous, the send completes only against a matching receive, which
the sample proves by the join returning after the receive.

#listing("rust/samples/src/Ch13/Channels.rs", first: 80, last: 99, caption: [bounded capacity 2, then the capacity 0 rendezvous])

Crossbeam-flavored channels live off the std menu: select over many
channels, mpmc, deadlines. The book stays zero-dependency, so this
chapter builds what std gives and chapter 14 composes futures over
them. What matters is the taxonomy, and std already shows all three
synchronization behaviors: queue, bound, rendezvous.

== mutex, rwlock, and condvar

When data stays put and many threads touch it, `Mutex<T>` is the
default. The lock guards the value inside, the guard derefs to it, and
dropping the guard releases the lock, so scopes do the unlocking. The
counting sample is the discipline in one line per iteration:

#listing("rust/samples/src/Ch13/Locks.rs", first: 20, last: 47, caption: [8 threads x 10000 locked increments total exactly 80000])

Poisoning is rust's answer to the panic-while-holding question. A
thread that panics with the lock held marks the mutex poisoned, and
every later `lock()` returns `Err(PoisonError)`. The value is still
there: `into_inner()` takes it out. The design reads as pessimism but
is a fence: if the panicking thread died between two mutations of a
multi-field invariant, the protected data may be inconsistent, and
forcing every caller through an explicit `Err` makes that possibility
visible instead of silent.

#listing("rust/samples/src/Ch13/Locks.rs", first: 49, last: 69, caption: [a panic while holding poisons, into_inner recovers])

`RwLock<T>` splits the exclusion: many readers or one writer. The
probes are cross-thread while the main thread holds a guard, so
`try_write` failing and `try_read` succeeding is measured behavior,
not documented hope. One shape to know: a guard is bound to its lock
and `RwLockReadGuard` is `!Send`, so a guard cannot ride a join
boundary, the compiler rejects the attempt outright.

#listing("rust/samples/src/Ch13/Locks.rs", first: 71, last: 97, caption: [readers coexist, writers wait, guards die with their scope])

`Condvar` completes the trio as the wait side. The pattern is rigid
and the rigidity is the point: lock, re-check the predicate in a
`while` loop because a wakeup never promises the condition holds,
`wait(guard)` atomically parks and releases, and every state change
notifies. The sample is a one-slot handoff, 1000 rounds, both sides
finish with the exact sum 500,500, no lost wakeup in any run.

#listing("rust/samples/src/Ch13/Locks.rs", first: 99, last: 121, caption: [the producer side of the condvar handshake])

#listing("rust/samples/src/Ch13/Locks.rs", first: 122, last: 155, caption: [the consumer side, predicate loop and all])

== atomics and the orderings

`AtomicBool`, `AtomicI64`, `AtomicUsize`, and the rest give single
word operations that are atomic in the hardware sense, plus a memory
ordering argument that decides which other writes become visible
around them. The orderings are not decoration, they are the contract,
and the samples each prove the property they claim.

`Relaxed` is atomicity with no synchronization promise: perfect for
counters and statistics where only the total matters. Eight threads
run 10,000 relaxed increments each and the total is exactly 80,000
every run: no torn updates, because the read-modify-write is one
instruction, no ordering, because none was asked for. The
read-modify-write family returns the previous value, which is what
makes fetch strategies possible:

#listing("rust/samples/src/Ch13/Atomics.rs", first: 67, last: 100, caption: [relaxed counters stay exact, and the fetch family returns old values])

`compare_exchange` is the compare-and-swap at the bottom of every
lock-free algorithm, with two orderings because it is a read and a
write when it succeeds and a plain read when it fails. The spinlock at
the end of the sample is the canonical use: acquire on the way in,
release on the way out, a plain `u64` guarded underneath.

#listing("rust/samples/src/Ch13/Atomics.rs", first: 102, last: 112, caption: [compare_exchange, success and failure arms])

`Release` on a store pairs with `Acquire` on a load that observes it:
everything the writer did before the release store is visible to the
reader after the acquire load sees it. That is the publication pattern,
data written plainly, then a flag released, then a reader that can
trust the data the moment the flag acquires. The sample's assert is
the contract, the plain store of 42 is never seen stale after the
acquire observed `true`:

#listing("rust/samples/src/Ch13/Atomics.rs", first: 114, last: 140, caption: [the publication pattern, release store against acquire load])

`SeqCst` is the strongest and the only ordering with a total order
across all SeqCst operations. The proof is the store-buffer litmus:
two threads each store their own flag then read the other's. Can both
read stale, both see false? Under Relaxed the model permits it, so the
sample measures whether this machine does it, with a gate harness that
starts both threads on the same round instead of paying a spawn per
round:

#listing("rust/samples/src/Ch13/Atomics.rs", first: 22, last: 64, caption: [the store-buffer litmus harness, one gate, two spinning threads])

Measured 2026-10-13 on the pinned build, 20 reported cores, three
runs: relaxed produced 891, 4, and 168 double-zero rounds out of
20,000, seqcst produced 0 in every run. The asymmetry is the lesson:
the relaxed count proves the hardware permits the outcome, its exact
value is scheduler noise and no assert rides on it, while the seqcst
assert holds in every run because the model forbids the outcome
entirely. `AcqRel` is the load-store combination used on
read-modify-writes, and the rule of thumb holds: default to acquiring
loads and releasing stores, pay for seqcst only when a total order
across variables is the algorithm's actual requirement, the double
checked locking shape being the classic.

The spinlock folds the whole section into one type. Note the seam: the
protected `u64` rides an `UnsafeCell` with an `unsafe impl Sync`, two
lines of trust that the lock discipline is correct, which is chapter
17's exact subject.

#listing("rust/samples/src/Ch13/Atomics.rs", first: 152, last: 170, caption: [four threads x 25000 guarded adds total exactly 100000])

#listing("rust/samples/src/Ch13/Atomics.rs", first: 172, last: 211, caption: [the spinlock type, acquire in, release out, UnsafeCell underneath])

== Send, Sync, and the honest race claim

`Send` says a value may move to another thread. `Sync` says a shared
reference may, `&T` is `Send`. Both are auto traits, derived
structurally from the fields, both are marker traits with no methods,
and both can be granted manually only in `unsafe impl`, never
negated. The sample pins the positive facts at compile time:

#listing("rust/samples/src/Ch13/SendSync.rs", first: 21, last: 45, caption: [compile-time Send and Sync bounds, asserted for the standard types])

The negative facts cannot be asserted in a file that must compile, and
probing them live turns each into its compile error: `Rc<u64>` is
neither `Send` nor `Sync` because its refcount is unsynchronized,
`*const u8` is neither because pointers alias freely, `RefCell` is
`Send` but not `Sync` because its borrow flag is thread-local state,
`MutexGuard` is `!Send` because unlocking from a different thread is
not allowed. Those impls are read straight off the pinned std docs.

#snippet("use std::rc::Rc;\n\nlet shared = Rc::new(vec![1, 2, 3]);\nstd::thread::spawn(move || {\n    println!(\"{}\", shared.len());\n});\n// error[E0277]: `Rc<Vec<i32>>` cannot be sent between threads safely\n// required by the `Send` bound on the spawn closure", lang: "rust")

`Arc<T>` is the count-safe sibling, `Send` and `Sync` exactly when `T`
is `Send + Sync`, and `Arc<Mutex<T>>` is the idiom for shared mutable
state because `Mutex<T>` is `Sync` whenever `T` is `Send`. The sample
probes the counts directly: six clones live across six joined threads,
each observes a live strong count between 2 and 8, and the count is
back to 1 after the joins.

#listing("rust/samples/src/Ch13/SendSync.rs", first: 59, last: 82, caption: [Arc counts across joined threads, deterministic bounds])

#callout("pitfall", "what safe rust prevents", [
  Safe rust prevents data races: two threads touching the same memory
  with at least one write and no synchronization. It does not prevent
  races. Deadlock is fully available, two mutexes taken in opposite
  order by two threads parks both forever. Lost updates through a
  check-then-act gap between two locked regions are available too.
  The compile-time machinery removes the undefined behavior class,
  logic bugs in the interleaving remain the programmer's, and
  #xref-to("patterns", "hazards") collects the detector side.
])

The deadlock shape, deliberately unexecuted:

#snippet("let a = &mutex_a;\nlet b = &mutex_b;\n\n// thread 1: lock a, then b\n// thread 2: lock b, then a\n// both hold one and wait on the other, forever\n// rustc accepts it, the borrow checker has no opinion on order", lang: "rust")

sources: the rust book concurrency chapter and its four sections
(doc.rust-lang.org/stable/book/ch16-00-concurrency.html through
ch16-04-extensible-concurrency-sync-and-send.html), std::thread
including thread::scope, Scope, and ScopedJoinHandle
(doc.rust-lang.org/stable/std/thread/index.html,
doc.rust-lang.org/stable/std/thread/fn.scope.html), std::sync with
mpsc, Mutex, MutexGuard, RwLock, and Condvar
(doc.rust-lang.org/stable/std/sync/index.html and the struct pages
under it), the atomic module and Ordering
(doc.rust-lang.org/stable/std/sync/atomic/index.html,
doc.rust-lang.org/stable/core/sync/atomic/enum.Ordering.html),
Send and Sync (doc.rust-lang.org/stable/std/marker/trait.Send.html,
doc.rust-lang.org/stable/std/marker/trait.Sync.html, negative impls
read off the Rc, RefCell, MutexGuard, Sender, and Receiver pages), all
read from the offline 1.99.0 html share under
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html
and accessed 2026-10-13. Version facts verified in
doc.rust-lang.org/stable/releases.md, accessed 2026-10-13: thread::scope
stabilized in 1.63.0 (2022-08-11), available_parallelism in 1.59.0
(2022-02-24). Measurements (80000 locked and relaxed increments, the
publication pattern, store-buffer litmus 891, 4, 168 relaxed against 0
seqcst in 20000 rounds across three runs, available_parallelism 20,
Arc counts 2 through 8 across 6 joined threads) produced by
`rust/samples/src/Ch13` under `pwsh tools/run-rust-samples.ps1
-Chapter Ch13`, dated 2026-10-13 on the pinned rustc 1.99.0.
