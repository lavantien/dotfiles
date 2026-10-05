#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= concurrency: threads to virtual threads

Java shipped threads in 1.0, before any of its peers made them central.
The platform rode that head start for 25 years on one model: every
`Thread` is an operating system thread, 1:1, with a fixed megabyte-scale
stack. Java 21 broke the mapping. Virtual threads are managed by the
jvm, cost a fraction of a platform thread, and turn thread-per-request
back into the sane default. This chapter walks the whole ladder, from
the raw thread api through monitors and the memory model to the
virtual era and the scoped-value replacement for `ThreadLocal`.
#xref-to("patterns", "concfundamentals") owns
the deep treatment of races, memory models, and detectors, this chapter
covers the java surfaces.

== the platform thread model

`Thread t = new Thread(runnable); t.start();` delegates straight to the
os: the thread gets its own stack, its own program counter, and the os
scheduler decides when it runs. Every java program is already
multithreaded before `main` starts, the vm runs its own threads for gc
and jit work alongside the main thread. Threads share one heap and see
each other's objects by default, which is exactly why the rest of this
chapter exists.

`Thread.State` wraps the os view into six values: new, runnable,
blocked, waiting, timed waiting, terminated. Blocked means waiting for
a monitor, the state a sample proves below. The methods that matter:
`start()` schedules the thread, `join()` waits it out, `interrupt()`
asks it to stop, `isDaemon()` marks threads that never keep the jvm
alive. `stop()`, `suspend()`, and `resume()` are the deprecated
failures of the original api, `stop()` can kill a thread mid-mutation
and leave objects in illegal states, they must never appear in code.

== synchronized and the monitor story

Every object carries a monitor. `synchronized` on a method or block
acquires it, and the acquire is exclusive: a second thread blocks until
the holder releases. The point is never the code inside the block, it
is the state the code can temporarily make inconsistent. Acquiring the
monitor does not fence the object off, an unsynchronized method can
still read a half-updated field while the monitor is held.
Synchronization is cooperative, all the mutating and reading paths
must take the same monitor, one missing keyword breaks the whole
contract.

#listing("java/samples/src/Ch10/Monitors.java", first: 15, last: 33, caption: [a counter guarded by its own monitor, and a reentrancy proof])

Two threads run 100,000 increments each through `increment()` and the
total is exactly 200,000, every time. Without `synchronized` the
read-modify-write of `i = i + 1` interleaves and loses updates, the
lost update anomaly. `incrementTwice()` shows reentrancy: java locks
are reentrant, a thread holding a monitor re-enters its synchronized
regions freely, a non-reentrant lock would deadlock right there.

`wait()` and `notifyAll()` complete the monitor story. They live on
`Object` and must run inside a synchronized region: `wait()` releases
the monitor and parks the thread, `notifyAll()` wakes everyone parked
on that monitor, and the woken thread re-acquires before continuing.

#listing("java/samples/src/Ch10/Monitors.java", first: 36, last: 56, caption: [a one-slot buffer, the wait and notify handshake])

The guarded `while` loop around `wait()` is not decoration, a wakeup
does not guarantee the condition holds again. The sample drives 1,000
productions and 1,000 consumptions through one slot and both sides
finish exactly. Real code reaches for `ArrayBlockingQueue` instead,
but every developer should be able to read this shape, it is what the
queue does underneath.

== volatile and happens-before

Monitors fix both exclusion and visibility. `volatile` buys only the
second half. The java memory model lets each thread cache field values
in registers and per-core caches, so a plain `boolean running` flag may
never be seen as false by the thread spinning on it. A `volatile`
write pushes the value to main memory and a volatile read pulls it
back, and more precisely the write and the read form a happens-before
edge: everything the writer did before the volatile write is visible
to the reader after the volatile read. Monitor release and acquire,
thread start and join, all create the same edges.

#snippet("private volatile boolean shutdown = false;\n\npublic void shutdown() {\n  shutdown = true;\n}\n\npublic void run() {\n  while (!shutdown) {\n    // ... process another task\n  }\n}", lang: "java")

The run-until-shutdown pattern, the textbook volatile use. The
keyword carries no exclusion at all: a volatile counter still loses
updates under `i = i + 1`, because the read-modify-write is three
steps and volatile only orders the individual reads and writes.
`AtomicLong` or a monitor is the fix. The full happens-before algebra
and its counterexamples are
#xref-to("patterns", "concfundamentals")'s
subject, java's rules are one instance of that general story.

== executors and CompletableFuture

Raw threads have no result and no pool. `java.util.concurrent`, in the
jdk since 5, added the runtime-managed layer: an `ExecutorService`
owns the threads, code submits work. A fixed pool of platform threads
is the classic shape, and since 19 an executor is `AutoCloseable`,
try-with-resources waits for submitted work to finish.

`CompletableFuture`, since 8, layers composition on top: stages that
map, combine, and recover, with exceptions flowing through the
pipeline instead of breaking it.

#listing("java/samples/src/Ch10/Async.java", first: 24, last: 53, caption: [pipelines over a virtual-thread-per-task executor])

`supplyAsync` starts a stage on the given executor, `thenApply` maps
the eventual value, `thenCombine` joins two stages, `exceptionally`
recovers a failed one, and `allOf` fans in. The executor passed here
is the 19 addition `newVirtualThreadPerTaskExecutor`, every task gets
its own virtual thread and the pool never needs sizing, which is the
bridge to the centerpiece.

== ThreadLocal and its costs

`ThreadLocal`, since 1.2, gives each thread a private slot: the
per-thread `SimpleDateFormat`, the per-transaction context. The cost
profile was fine when a program ran tens of threads. It breaks on
tens of thousands. Each thread carries a mutable map of bindings, the
values live as long as the thread, and pooled platform threads glue
one task's leftovers onto the next task's run. On virtual threads the
jep 444 guidance is blunt: thread locals only after real thought,
never to pool costly objects, since virtual threads are plentiful and
short-lived, not pooled. The jdk itself stripped thread-local uses out
of `java.base` to shrink per-thread footprint, and
`-Djdk.traceVirtualThreadLocals` flags the first write to a thread
local in a virtual thread. The replacement is scoped values, the last
section of this chapter.

== virtual threads

Previewed in 19 and 20 (jeps 425, 436), final in 21 (jep 444). A
virtual thread is a `java.lang.Thread` whose stack lives on the heap
in resizable stack chunks and whose body runs on a carrier platform
thread from a fork join pool, by default one pool sized to the core
count. Blocking unmounts the virtual thread, frees the carrier, and
remounts it when the operation completes. The api is deliberately the
same: `Thread.ofVirtual()`, or the executor above, and everything
written against `Thread` keeps working.

#listing("java/samples/src/Ch10/Virtual.java", first: 14, last: 41, caption: [ten thousand virtual threads, spawned, started, joined])

Measured 2026-10-04 on the pinned build, 20 reported cores: the whole
spawn, start, and join of 10,000 virtual threads took 38 ms. Platform
threads at a 1 mb default stack cannot stack 10,000 deep on a normal
machine, virtual threads at a few hundred bytes to start can, and
order-of-magnitude more. `currentThread()` inside the task is the
virtual thread itself, the carrier's identity is unavailable to it.

Identity is the one place the old instincts misfire. Virtual threads
are cheap and plentiful, so caching per-thread resources keyed on
identity is an anti-pattern, and the jep discourages identity-sensitive
operations on them. `getId()` was deprecated in 19 because subclasses
could override it, the final `threadId()` (since 19) is the
replacement, and the sample confirms ids stay unique and positive.

=== pinning, before and after

The original jep 444 caveat: a virtual thread that blocks inside a
`synchronized` method or block could not unmount, it pinned its
carrier. One monitor held across a slow io call froze a whole carrier,
and a fleet of them starved the pool. The standard mitigation was to
swap `synchronized` for `java.util.concurrent.locks.ReentrantLock`,
which never pinned. Jep 491 in 24 removed the limitation: monitors are
now owned by the virtual thread, not the carrier, blocking on a
monitor or in `Object.wait()` unmounts like any other blocking
operation, and the `jdk.tracePinnedThreads` diagnostic was retired
with the problem it tracked. What still pins on 27: native frames on
the stack, blocking during class loading or in a class initializer,
and jni or foreign-function calls that block inside native code.

#listing("java/samples/src/Ch10/Pinning.java", first: 61, last: 79, caption: [the pinning probe, measured against the serialization floor])

The math the check rides on: if sleeping inside `synchronized` still
pinned, 1,000 sleepers of 40 ms each would serialize onto 20 carriers
for a 2,000 ms floor. Measured 2026-10-04: 64 ms synchronized, 50 ms
under `ReentrantLock`. Both sit far under the floor, monitors no
longer pin, and the pre-24 `ReentrantLock` workaround is back to
being just a lock with more features, try-lock and timed waits.

#diagram([a virtual thread mounts on a carrier, blocks, unmounts, remounts], length: 13pt, {
  cdraw.rect((0.3, 0.0), (5.6, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.95, 2.05), [virtual thread], size: 6.5pt)
  cdraw.content((2.95, 1.15), [heap stack chunk,], size: 6pt)
  cdraw.content((2.95, 0.35), [cheap, many, never pooled], size: 6pt)
  cdraw.rect((7.6, 0.0), (13.1, 2.6), fill: luma(222), radius: 0.02)
  cdraw.content((10.35, 2.05), [carrier thread pool], size: 6.5pt)
  cdraw.content((10.35, 1.15), [fork join, one per core,], size: 6pt)
  cdraw.content((10.35, 0.35), [runs the mounted body], size: 6pt)
  cdraw.rect((7.6, 3.6), (13.1, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.35, 5.65), [os threads], size: 6.5pt)
  cdraw.content((10.35, 4.75), [preemptively scheduled,], size: 6pt)
  cdraw.content((10.35, 3.95), [1:1 with carriers], size: 6pt)
  cdraw.line((5.7, 1.3), (7.5, 1.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.6, 1.75), [mount], size: 6pt)
  cdraw.line((10.35, 2.7), (10.35, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.6, 3.1), [is a], size: 6pt)
  cdraw.content((4.9, 4.2), [block in io, monitor, sleep:], size: 6pt)
  cdraw.content((4.9, 3.3), [unmount, carrier freed], size: 6pt)
  cdraw.content((4.9, 5.1), [native frame on the stack: pinned, 27], size: 6pt)
})

== structured concurrency, the shape of the future

Virtual threads make thread-per-task cheap, and the missing half is
lifecycle: a parent that forks subtasks, waits for them as a unit, and
cancels the rest on first failure. Structured concurrency is that api,
still previewing, in its seventh preview in 27 (jep 533, incubated in
19, first previewed in 21).

#snippet("try (var scope = StructuredTaskScope.open(Joiner.<String>anySuccessfulOrThrow())) {\n  scope.fork(() -> fetchLeft());\n  scope.fork(() -> fetchRight());\n  // throws if both subtasks fail, cancels the slower one otherwise\n  String firstDone = scope.join();\n}", lang: "java")

The 27 preview makes `StructuredTaskScope` an interface with `open`
factories and `Joiner` policies, adds a third type parameter for the
exception `join()` can throw, and replaces `onTimeout()` with
`timeout()`. It compiles only with `--enable-preview`, so it lives
here as a snippet while the final sections use only shipped api. The
pairing with scoped values is the design center: a scope's children
are exactly the threads that inherit its bindings.

== scoped values

Final in 25 (jep 506, previewed from 21). A `ScopedValue` is bound for
the dynamic extent of a block, visible to everything the block calls,
and gone when it exits. There is no `set` and no `remove`, so no
leaked binding can outlive its scope, the failure mode `ThreadLocal`
normalized.

#listing("java/samples/src/Ch10/Scoped.java", first: 18, last: 40, caption: [bind, rebind, and the structured sharing rule])

Rebinding nests: the inner `where` wins and the outer value is
restored when it exits. Sharing across threads is structured only,
the javadoc's rule: bindings are captured by a `StructuredTaskScope`
and inherited by its forked children, and the probed check above shows
the inverse, an unstructured executor child sees no binding at all.
That is the deliberate design, scoped values ride structured
concurrency, which is why the two features grew up together.

The guidance in one line: new code on virtual threads uses scoped
values for context, leaves `ThreadLocal` to interop, never pools
threads, and treats thread identity as none of its business.

sources: jep 444 (openjdk.org/jeps/444, thread locals, identity,
carrier identity unavailable), jep 491 (openjdk.org/jeps/491,
synchronized no longer pins, remaining native-frame pins,
jdk.tracePinnedThreads removed), jep 506 scoped values final 25, jep
533 seventh preview 27 with the interface plus Joiner shape (the
canonical open example read from the pinned jdk's own src.zip
java.base/java/util/concurrent/StructuredTaskScope.java), jep 425 and
436 preview lineage, all accessed 2026-10-04. Thread.getId deprecated
since 19 and threadId() final since 19 verified against the pinned
build's src.zip java.base/java/lang/Thread.java, accessed 2026-10-04.
The 8-to-17 arcs (thread lifecycle, monitors, wait and notify,
volatile, the executor story) ground on Java in a Nutshell 8th
edition chapter 6, pages 249 to 263. Measurements (10,000 joins in 38
ms, synchronized 64 ms against a 2,000 ms pinning floor, reentrant
lock 50 ms, 20 cores, executor children do not inherit scoped
bindings) produced by `java/samples/src/Ch10` under
`pwsh tools/run-java-samples.ps1 -Chapter Ch10`, dated 2026-10-04 on
tools/jdk27/build/jdk-27.
