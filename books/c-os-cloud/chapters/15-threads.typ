#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= threads and synchronization

Chapter 11 built a process and its primary thread in one `CreateProcessW`
call and left the thread half unopened. This chapter opens it. The
Multiple Threads page fixes the object in three sentences: "A thread is
the entity within a process that can be scheduled for execution. All
threads of a process share its virtual address space and system
resources. Each process is started with a single thread, but can create
additional threads from any of its threads." Everything here is a
consequence of those sentences. Shared address space is why two workers
adding to one total need a lock between them. One schedulable entity per
thread is why a c23 `thrd_t` and a win32 handle from `CreateThread` are
two spellings of the same kernel scheduling object, and why the last
section's portability ladder climbs from the standard's header down to
that object without ever leaving it. Every behavioral claim below is a
CHECK in the three samples, 36 in total, or a sentence quoted from a
canonical page fetched 2026-09-12.

== threads and the scheduler's view

`CreateThread` states its own contract in one line: it "Creates a thread
to execute within the virtual address space of the calling process."
Measured against chapter 11's creation call, half the machinery is
missing on purpose. No new address space, no new process object, no pid.
What appears is a kernel object with a thread identifier, "By default,
every thread has one megabyte of stack space", and a handle back to the
caller. The page also fixes the parent's view of the creation race: with
no creation flags "The thread runs immediately after creation", and in
general "the thread can start running before CreateThread returns and,
in particular, before the caller receives the handle and identifier of
the created thread". The samples below take that seriously. Every worker
records its own `GetCurrentThreadId()` inside the thread, because the
creator cannot assume it observed anything before the worker ran.

The scheduler's view of one thread is a state machine, and every
synchronization call in this chapter names an edge of it. The thread
object is born unsignaled with its exit code pending. While the thread
function runs, the machine can drop it into a wait, and a waiting thread
holds no lock and no cpu. When the thread function returns, the page
writes the ending: "the DWORD return value is used to terminate the
thread in an implicit call to the ExitThread function", the exit code
is set, and "When a thread terminates, the thread object attains a
signaled state, satisfying any threads that were waiting on the
object." The object outlives the execution by exactly one rule, the same
one chapter 11 proved for process handles: "The thread object remains
in the system until the thread has terminated and all handles to it
have been closed through a call to CloseHandle." The Terminating a
Thread page states the twin from the other side: "When a thread
terminates, its thread object is not freed until all open handles to
the thread are closed."

The wait side of the machine belongs to `WaitForSingleObject`, whose
waitable list includes thread, and the Synchronizing Execution of
Multiple Threads page says when that wait ends: "Process and thread
handles are signaled when the process or thread terminates." A parent
that waits on a thread handle therefore blocks until the state machine
above reaches its signaled state, and the return constants are pinned
on the function's page: `WAIT_OBJECT_0`, 0x00000000, "The state of the
specified object is signaled", `WAIT_TIMEOUT`, 0x00000102, when the
interval elapsed.

#diagram([one thread object through the scheduler's state machine, the calls that drive each edge], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 4.6, 5.4, [created: object, handle, tid])
  box(8.6, 4.6, 5.4, [running: executing func(arg)])
  box(16.6, 4.6, 5.8, [terminated: code set, signaled])
  box(24.6, 4.6, 4.8, [freed: last handle closed])
  cdraw.content((3.3, 6.7), [createthread or thrd\_create], wrap: text.with(size: 6.5pt))
  cdraw.line((3.3, 6.2), (3.3, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 5.1), (8.6, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.3, 4.1), [the scheduler #linebreak() dispatches], wrap: text.with(size: 6pt))
  cdraw.line((12.6, 4.6), (12.6, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.4, 3.6), [waitforsingleobject on a #linebreak() nonsignaled object, #linebreak() sleepconditionvariablesrw], wrap: text.with(size: 6pt))
  cdraw.line((10.0, 2.8), (10.0, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 3.6), [wake, timeout, #linebreak() spurious return], wrap: text.with(size: 6pt))
  cdraw.rect((8.6, 1.4), (14.0, 2.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 2.1), [blocked: inside a wait, #linebreak() no lock, no cpu], wrap: text.with(size: 6pt))
  cdraw.line((14.0, 5.1), (16.6, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.3, 4.1), [func returns, #linebreak() exitthread implied], wrap: text.with(size: 6pt))
  cdraw.line((22.4, 5.1), (24.6, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((23.5, 4.0), [last closehandle #linebreak() or the join's close], wrap: text.with(size: 6pt))
  cdraw.content((19.5, 3.2), [thrd\_join and waitforsingleobject #linebreak() observe the signal here], wrap: text.with(size: 6pt))
  cdraw.content((13.0, 0.3), [waits and wakes move a thread between running and blocked; only termination is one-way], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== c23 threads.h and win32 side by side

The c23 layer first. The header clause, n3220 7.28.1: "The header
`<threads.h>` includes the header `<time.h>`, defines macros, and
declares types, enumeration constants, and functions that support
multiple threads of execution." Of those types, `thrd_t` "is a complete object
type that holds an identifier for a thread" and `thrd_start_t` "is the
function pointer type `int (*)(void*)` that is passed to `thrd_create`
to create a new thread". `thrd_create` at 7.28.5.1 "creates a new thread
executing func(arg)", sets the caller's `thrd_t` to the new thread's
identifier, and carries one ordering promise: "The completion of the
`thrd_create` function synchronizes with the beginning of the execution
of the new thread." The worker's side is one sentence: "Returning from
func has the same behavior as invoking `thrd_exit` with the value
returned from func." `thrd_join` at 7.28.5.6 "joins the thread
identified by thr with the current thread by blocking until the other
thread has terminated", stores the result code through its `res`
pointer, and closes the loop: "The termination of the other thread
synchronizes with the completion of the `thrd_join` function." That
synchronizes sentence is why the samples can read worker-written
fields after a join with no lock of their own.

On this box that vocabulary works, and the working set is larger than
the plan assumed: `thrd_create`, `thrd_join`, `mtx_t`, and `cnd_t` all
link and run under the gate's exact flags, probed 2026-09-12 through
the msvc 14.44 crt, which ships `threads.h` in the toolset's own
include directory rather than the Windows SDK's ucrt. The first sample
runs the same worker discipline twice, once per layer, and asserts the
same exact total both times:

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/threads.c", first: 44, last: 51, caption: [the c23 worker: lock, add, unlock, return a result code])]

The worker takes the `mtx_t`, adds its slice under it, and returns
`100 + index`. The standard is specific about what the lock buys at
7.28.4: "For purposes of determining the existence of a data race,
lock and unlock operations behave as atomic operations. All lock and
unlock operations on a particular mutex occur in some particular total
order." Eight workers therefore serialize into some order the
scheduler picks; addition commutes; the total does not depend on the
order picked. Without the lock, the read-modify-write is three
instructions wide and the total would be whatever interleaving
happened to allow. The sample asserts the with-lock arithmetic, not
the folklore:

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/threads.c", first: 80, last: 97, caption: [leg 1: one mutex total, eight creates, eight joins])]

Line by line: the pool is zeroed and its mutex initialized with
`mtx_plain`, which n3220 describes as the constant for "a mutex object
that does not support timeout". Each job points at the pool and
carries its index. Eight `thrd_create` calls start eight `thrd_t`.
Then the join loop, which is where the layer pays its rent: each
`thrd_join` blocks the parent until that worker terminated, hands the
worker's result through `res`, and releases the thread object it owns.

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/threads.c", first: 98, last: 103, caption: [leg 1 verdicts: every join result, the exact 8028])]

All 8 joins succeed, every result is `100 + index`, and the total is
8028, eight thousands plus the sum 0+1+...+7. The tid check is the
scheduler view made concrete: each worker wrote its own
`GetCurrentThreadId()` while running, and all eight differ from the
parent's.

The win32 twin underneath replaces the crt's types with the kernel's.
The worker is the same discipline over an `SRWLOCK`, which the
InitializeSRWLock page introduces as a "slim reader/writer (SRW) lock"
acquired "in exclusive mode" by `AcquireSRWLockExclusive`. No
initializer return value, no error code: the page returns none for
both, and the lock is a single 8 byte object, probed.

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/threads.c", first: 65, last: 72, caption: [the win32 twin worker over an srw lock])]

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/threads.c", first: 119, last: 133, caption: [leg 2 audit: wait on the handle, read the exit code, close])]

The audit follows the GetExitCodeThread page's own discipline. The
wait runs first, so the exit code is only read after "the thread has
been confirmed to have exited", exactly the order the page's warning
asks for: it "returns a valid error code defined by the application
only after the thread terminates", so "an application should not use
`STILL_ACTIVE` (259) as an error code", the same 259 collision chapter
11 measured on processes. After the wait, the exit code is "The return
value from the thread function", and all eight read back
`100 + index`. Then the closes, one per handle, and the SRWLOCK leg's total
is the same exact 8028. Two spellings, one scheduler object.

#diagram([the two layers side by side, paired steps, one scheduler object under both], length: 13pt, {
  let col(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  col(0.6, 7.0, 9.2, [the c23 layer: threads.h], fill: luma(205))
  col(13.4, 7.0, 9.2, [the win32 layer: kernel32], fill: luma(205))
  col(0.6, 5.6, 9.2, [thrd\_create(\&thr, fn, arg) #linebreak() hands back a thrd\_t])
  col(13.4, 5.6, 9.2, [createthread(...) hands back #linebreak() a HANDLE and a tid])
  col(0.6, 4.3, 9.2, [thrd\_join(thr, \&res) blocks #linebreak() until termination])
  col(13.4, 4.3, 9.2, [waitforsingleobject(h, infinite) #linebreak() blocks on the handle])
  col(0.6, 3.0, 9.2, [res receives the result code])
  col(13.4, 3.0, 9.2, [getexitcodethread(h) reads it])
  col(0.6, 1.7, 9.2, [the join releases the thread])
  col(13.4, 1.7, 9.2, [closehandle(h), one per thread])
  cdraw.line((9.8, 6.1), (13.4, 6.1), stroke: luma(140), mark: (end: ">"))
  cdraw.line((9.8, 4.8), (13.4, 4.8), stroke: luma(140), mark: (end: ">"))
  cdraw.line((9.8, 3.5), (13.4, 3.5), stroke: luma(140), mark: (end: ">"))
  cdraw.line((9.8, 2.2), (13.4, 2.2), stroke: luma(140), mark: (end: ">"))
  cdraw.rect((0.6, 0.2), (22.6, 1.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 0.7), [one kernel scheduling object under both columns: same tid space, signaled at exit, same 8028], wrap: text.with(size: 6pt))
})

#callout("pitfall", "createthread and the c runtime", [
  The CreateThread page carries one crt warning: "A thread in an
  executable that calls the C run-time library (CRT) should use the
  `_beginthreadex` and `_endthreadex` functions for thread management
  rather than CreateThread and ExitThread; this requires the use of
  the multithreaded version of the CRT. If a thread created using
  CreateThread calls the CRT, the CRT may terminate the process in
  low-memory conditions." The gate's workers call `printf` from both
  kinds of thread and hold, probed; the layer that owns the concern
  outright is the crt's own `thrd_create`, which is why it is the
  primary spelling in this book.
])

== condition variables and wake discipline

A lock serializes; a condition variable lets a thread wait for a state
it cannot see while holding that lock. The Condition Variables page
states the mechanism: "Condition variables enable threads to atomically
release a lock and enter the sleeping state", they "can be used with
critical sections or slim reader/writer (SRW) locks", and after the
wake "it re-acquires the lock it released when the thread entered the
sleeping state". `SleepConditionVariableSRW` says it again as a
function contract: "Sleeps on the specified condition variable and
releases the specified lock as an atomic operation", returning
nonzero on success and, "If the timeout expires", FALSE "and
GetLastError returns `ERROR_TIMEOUT`". One more sentence from the same
page sizes the sample's data structure: "It is often convenient to
use more than one condition variable with the same lock." The ring
below takes that advice: one `SRWLOCK`, `not_empty` for the consumer,
`not_full` for the producer, over a four-slot ring of ints with head,
tail, and count.

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/condvar.c", first: 41, last: 56, caption: [the producer: sleep on `not_full` while full, publish, wake `not_empty`])]

Both loops run under `thrd_create`, the c23 layer driving win32
synchronization underneath, and both follow the page's usage pattern
verbatim: acquire, recheck the predicate in a `while`, sleep on the
condition variable, act, release, then wake. The page even orders the
last two steps: "It is usually better to release the lock before
waking other threads to reduce the number of context switches", which
is why every `WakeConditionVariable` in the sample sits after its
`ReleaseSRWLockExclusive`.

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/condvar.c", first: 64, last: 79, caption: [the consumer: sleep on `not_empty` while empty, take, wake `not_full`])]

The hard check does not depend on the interleaving, and that is the
design. One producer publishes 0, 1, ..., 15 in order. The ring is
fifo. One consumer takes 16 items. Whatever order the scheduler
interleaves producer and consumer, the consumed sequence equals the
produced one, so the sample asserts exactly that, plus the drain: 16
items through a 4-slot ring leaves count 0 and head and tail wrapped
back to 0.

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/condvar.c", first: 103, last: 111, caption: [the deterministic verdicts: sequence equality, drained ring, three distinct threads])]

The wake discipline is where this territory earns its reputation, and
the docs hand over the reasons verbatim. The Condition Variables page:
"Condition variables are subject to spurious wakeups (those not
associated with an explicit wake) and stolen wakeups (another thread
manages to run before the woken thread). Therefore, you should recheck
a predicate (typically in a while loop) after a sleep operation
returns." The standard says why the loop cannot be an `if`, from the
other side, at 7.28.3.4: `cnd_signal` "unblocks one of the threads
that are blocked on the condition variable pointed to by cond at the
time of the call. If no threads are blocked on the condition variable
at the time of the call, the function does nothing and returns
success." A wake has no memory. Fired at a thread not yet asleep, it
is gone, and the sleeper sleeps on. The third sample makes that
interleaving happen deterministically instead of once in a while:

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/wake.c", first: 43, last: 60, caption: [the bug: check once, park at go while the wake fires, sleep once, never recheck])]

Two event objects act as scheduling gates. The consumer takes the
lock, sees `count == 0`, releases, and parks on `saw_empty`. The
parent, holding the ordering the events force, fills the slot and
fires the wake while the consumer is still parked on the event, then
releases it into the sleep:

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/wake.c", first: 99, last: 116, caption: [phase 1 interleave: the wake fires while nobody is asleep on the condition variable])]

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/wake.c", first: 118, last: 123, caption: [phase 1 verdicts: full timeout burned, item stranded])]

The wake was fired at a thread that was not blocked "at the time of
the call", so it did nothing. The consumer then sleeps its full
1000 ms, gets FALSE and `ERROR_TIMEOUT`, and exits without ever
looking again. The slot held item 7 the entire time. In a real
program this is the shape that deadlocks on an `INFINITE` timeout or
strands work behind an `if`; here the bounded timeout turns the bug
into an assertion.

The fix is the loop, and the sample proves both halves of it. The
consumer rechecks the predicate under the lock on every pass, so a
wake lost before the sleep cannot strand the item:

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/wake.c", first: 70, last: 85, caption: [the fix: recheck the predicate under the lock on every pass])]

The phase 2 interleave is the mirror of phase 1 with one decisive
difference: the consumer arms `saw_empty` while still holding the
lock, inside the loop, before the sleep call. The parent's acquire
can therefore only complete after the sleep call released the lock,
which means the parent's `WakeConditionVariable` always lands on a
thread that is already asleep on the condition variable. The join
returning is the proof: phase 2 sleeps with `INFINITE`, so its
termination is only possible if the wake was received. It consumes
the item 9, the loop body ran at least once, and the printed sleep
count, 1 in every run so far, stays a printed number rather than a
check because spurious and stolen wakes make the count the
scheduler's business, not the program's. That division is the entire
lesson: the program owns the predicate and the lock, the scheduler
owns the order.

#diagram([the wait protocol as a cycle: every exit from the sleep lands on the predicate again], length: 13pt, {
  let box(x, y, w, h, t) = {
    cdraw.rect((x, y), (x + w, y + h), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 5.0, 4.6, 1.0, [acquire the srw lock])
  box(7.6, 5.0, 6.6, 1.4, [evaluate the predicate #linebreak() while holding the lock])
  box(17.4, 5.0, 6.0, 1.4, [act: consume or publish, #linebreak() release, then wake])
  box(7.6, 1.8, 6.6, 1.4, [sleep: release the lock #linebreak() and block, atomically])
  cdraw.line((5.2, 5.5), (7.6, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 5.7), (17.4, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.8, 4.4), [predicate true], wrap: text.with(size: 6pt))
  cdraw.line((9.4, 5.0), (9.4, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.7, 4.1), [predicate false], wrap: text.with(size: 6pt))
  cdraw.line((12.4, 3.2), (12.4, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.6, 3.7), [wake, spurious return, #linebreak() or timeout: #linebreak() the lock is reacquired], wrap: text.with(size: 6pt))
  cdraw.line((12.4, 3.7), (16.9, 3.7), stroke: luma(140))
  cdraw.content((11.5, 0.4), [the recheck is the loop, not the if: no exit from the sleep skips the predicate], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the portability boundary

`<threads.h>` is optional by design, and the standard says how a
program is supposed to detect the option: "Implementations that define
the macro `__STDC_NO_THREADS__` may not provide this header nor
support any of its facilities", n3220 7.28.1. The macro is the
sanctioned preprocessor gate. On this box the gate and the ground
disagree:

#block(breakable: false)[#listing("c-os-cloud/samples/src/Ch15/threads.c", first: 26, last: 30, caption: [the compile-time gate and the probed fact on this box])]

Probed 2026-09-12: clang 23.1.1 predefines `__STDC_NO_THREADS__` as 1
on the `x86_64-pc-windows-msvc` target, visible in `clang -dM -E`
output before any header is read, while the msvc 14.44 toolset linked
right next to it ships a complete, working `threads.h`. The check
holds both facts together: the macro is defined and every
threads.h-based check in this chapter still passes. A portable
ladder that trusts the macro alone would step past a working
implementation and into a fallback it did not need. The chapter 2
vocabulary already has the honest probe: `__has_include(<threads.h>)`
asks the compiler what is actually in front of it. Trust the crt you
link, not the compiler's assumption about it.

Below the header, whatever provides it, the comparison target for
every explanation of this chapter's primitives is posix, cited here
from Issue 8 and never executed on this box, the same treatment
chapter 11 gave `fork`. `pthread_mutex_lock` "shall be locked by a
call to `pthread_mutex_lock()` that returns zero", and "If the mutex is
already locked by another thread, the calling thread shall block
until the mutex becomes available", the same contract `mtx_lock`
spelled with a `mtx_t`. The condition twin is
`pthread_cond_wait`: "These functions atomically release mutex and
cause the calling thread to block on the condition variable cond",
with the loop requirement stated as recommendation, "It is thus
recommended that a condition wait be enclosed in the equivalent of a
while loop that checks the predicate", and the allowance that makes
the loop mandatory in practice: "Spurious wakeups from the
`pthread_cond_clockwait()`, `pthread_cond_timedwait()`, or
`pthread_cond_wait()` functions may occur." Windows says may; posix
says may occur; the loop is not optional anywhere.

The win32 fallback every real project carries is exactly the set
this chapter probed: `CreateThread` for the object,
`WaitForSingleObject` for the signal, `SRWLOCK` for the mutex, and a
`CONDITION_VARIABLE` for the wait, all 8-byte user-mode objects,
none of them needing a destroy call, because the InitializeSRWLock
page documents the exemption: "An unlocked SRW lock with no waiting
threads is in its initial state and can be copied, moved, and
forgotten without being explicitly destroyed", and condition
variables carry no delete function at all. The samples take that
leave: no `SRWLOCK` is destroyed in chapter 15, and the gate's
handle accounting closes every event handle it opened.

#diagram([where threads.h exists, what each environment synchronizes with, and the fallback ladder], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 7.4, 6.8, 1.0, [environment], fill: luma(205))
  cell(7.4, 7.4, 8.6, 1.0, [threads.h], fill: luma(205))
  cell(16.0, 7.4, 9.8, 1.0, [the synchronization layer], fill: luma(205))
  cell(0.6, 5.4, 6.8, 1.9, [this box: clang 23, #linebreak() msvc 14.44 crt])
  cell(7.4, 5.4, 8.6, 1.9, [present and probed, #linebreak() the macro defined anyway])
  cell(16.0, 5.4, 9.8, 1.9, [srwlock plus condition #linebreak() variables, this chapter])
  cell(0.6, 3.3, 6.8, 1.9, [posix systems])
  cell(7.4, 3.3, 8.6, 1.9, [the libc's choice, #linebreak() not a posix promise])
  cell(16.0, 3.3, 9.8, 1.9, [pthread\_mutex\_lock, #linebreak() pthread\_cond\_wait, cited])
  cell(0.6, 1.2, 6.8, 1.9, [any target where the #linebreak() header is absent])
  cell(7.4, 1.2, 8.6, 1.9, [absent: the gate fires])
  cell(16.0, 1.2, 9.8, 1.9, [createthread, waitforsingleobject, #linebreak() the win32 fallback])
  cdraw.content((12.9, 0.4), [the preprocessor gate can lie on this box: has\_include of the header decides on the spot], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

sources: learn.microsoft.com, CreateThread, GetExitCodeThread,
WaitForSingleObject, InitializeSRWLock, AcquireSRWLockExclusive,
SleepConditionVariableSRW, WakeConditionVariable, Condition Variables,
Multiple Threads, Creating Threads, Terminating a Thread, and
Synchronizing Execution of Multiple Threads pages, accessed 2026-09-12;
open-std.org n3220 (7.28.1 threads.h introduction and
`__STDC_NO_THREADS__`, 7.28.3.1 through 7.28.3.6 condition
variables, 7.28.4 mutex total order, 7.28.5.1 `thrd_create`, 7.28.5.6
`thrd_join`), accessed 2026-09-12; pubs.opengroup.org Issue 8
`pthread_mutex_lock` and `pthread_cond_wait`, accessed 2026-09-12;
the working threads.h through the msvc 14.44 crt (header in the
toolset include, not the sdk ucrt), the predefined
`__STDC_NO_THREADS__` despite it, the 8 byte lock and condition
variable objects, and the lost-wake timeout probed on this machine
the same day. Sample behavior verified by `make verify-c`, 36 checks
in chapter 15 of the samples suite.
