#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= atomics and memory ordering

Chapter 15 gave every thread its own stack and a shared heap. Nothing stops
two threads from touching the same bytes at the same instant: two accesses to
the same object, at least one a write, not both atomic, with no ordering
between them, are a data race. The `volatile` keyword does not help: cppreference's memory ordering page states the case
plainly, "volatile accesses are not atomic (concurrent read and write is a
data race) and do not order memory." The portable tool is `stdatomic.h`, and
this chapter reads it the way the rest of the book reads everything: which
header actually resolves on this target, what each of the six orderings
buys, what the instructions look like on x86-64, and where the operating
system's own waiter, `WaitOnAddress`, plugs in. Every behavioral claim below
is a CHECK in the three samples, 41 in total, an ir or objdump pin in
`Ch16/expect-ir.txt`, or a sentence quoted from a canonical page fetched
2026-09-12.

== stdatomic.h on this target

The header trail is a probed fact, not an assumption. The gate compiles
every sample with `-isystem` paths for the msvc 14.44 toolset and the
windows sdk, and `clang -v` prints the resulting search order: the toolset
include directory comes first, then ucrt, um, shared, and only then clang's
own resource directory. So `#include <stdatomic.h>` finds the msvc header,
`...\VC\Tools\MSVC\14.44.35207\include\stdatomic.h`, whose entire C-mode
body is one line, `#include <vcruntime_c11_stdatomic.h>`, probed with
`clang -H` on this box. Clang's own `stdatomic.h` sits behind it in the
search order and is never reached. The msvc header defines `memory_order`
as a real enum with probed values `relaxed 0`, `consume 1`, `acquire 2`,
`release 3`, `acq_rel 4`, `seq_cst 5`, defines every `ATOMIC_*_LOCK_FREE`
macro as 1, the
standard's "sometimes lock free" answer, and defines every generic
operation as a macro that forwards to a clang builtin,
`atomic_fetch_add` to `__c11_atomic_fetch_add`, `atomic_load` to
`__c11_atomic_load`, with the non-`_explicit` forms hard-wiring
`seq_cst`, the standard's default ordering.

`atomic_is_lock_free` is where this header's answer is most visible. The
macro expands to `_Atomic_is_lock_free(sizeof(__typeof_unqual__(*(_Obj))))`,
an inline function in `vcruntime_c11_atomic_support.h` whose body reads
`return _Sz <= 8 && (_Sz & _Sz - 1) == 0;`. The answer is a width
predicate, not a cpu probe: power of two, at most 8 bytes.

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 29, last: 45, caption: [the width map: 1, 2, 4, 8 report lock free, 16 reports not])

The checks confirm both halves on this target: the 16-byte pair really is
16 bytes. `long` is 4 bytes on windows, so the struct needs two of the
8-byte `long long` fields. The four hardware widths all report lock free,
and the `LOCK_FREE`
macros all print 1. Two more target facts round out the map. First,
`ATOMIC_CHAR8_T_LOCK_FREE` is undefined on this target, probed with
`#ifdef`: the msvc header predates C23's `char8_t` atomics, while clang's
builtin `__CLANG_ATOMIC_CHAR8_T_LOCK_FREE` is 2, "always lock free", the
value the resource header would have printed. Second, operations on a
16-byte atomic compile only past a warning: `-Watomic-alignment`, "large
atomic operation may incur significant performance penalty", is on by
default and turns fatal under the gate's `-Werror`, so the compiler itself
enforces the same 8-byte ceiling the predicate reports.

The operation set is the standard's, and the checks walk it in order:

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 52, last: 66, caption: [the arithmetic and swap family: default load, fetch add, sub, or, exchange])

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 67, last: 80, caption: [`compare_exchange` both ways, the expected writeback, and the consume load])

Line by line: the default `atomic_store` and `atomic_load` carry no
ordering argument, so they are `seq_cst`. `fetch_add` returns the old
value, 5, and the load sees 15. The relaxed `fetch_sub` and `fetch_or`
still count exactly, because atomicity is not an ordering property.
`exchange` swaps and reports what was there. `compare_exchange_strong`
succeeds against a matching expectation, and on the mismatch it does the
quiet thing worth pinning: the failed call writes the actual value, 7,
back into `expected`, which is how retry loops learn what moved. The
final load names `memory_order_consume`, which reads 7 like any other
load, and whose emitted code is chapter evidence in the next section.

#callout("pitfall", "generics are macros, brace your arguments", [
  C23 specifies the atomic operations as generic functions, and generic
  functions in C are function-like macros. The consequence bit this
  chapter's own probe: `atomic_exchange(&w, (wide_pair){3, 4})` fails with
  "too many arguments provided to function-like macro invocation", because
  the comma inside the braced initializer splits the macro argument. The
  compiler's own note gives the fix: parenthesize the whole initializer,
  `((wide_pair){3, 4})`. The same rule applies to every `_Generic`-based
  family in the library.
])

#diagram([the width taxonomy: what the crt answers, per width, and where each api caps out], length: 13pt, {
  let row(y, w, a, b) = {
    cdraw.rect((0.6, y), (5.2, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((2.9, y + 0.45), w, wrap: text.with(size: 6pt))
    cdraw.rect((5.6, y), (9.6, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((7.6, y + 0.45), a, wrap: text.with(size: 6pt))
    cdraw.rect((10.0, y), (16.2, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((13.1, y + 0.45), b, wrap: text.with(size: 6pt))
  }
  row(6.6, [width], [is\_lock\_free here], [the crt answer])
  row(5.4, [1, 2, 4, 8 bytes], [true, probed], [sz <= 8 and a power of two])
  row(4.2, [16 bytes], [false, probed], [blocked by -Werror here])
  row(3.0, [WaitOnAddress sizes], [1, 2, 4, 8 only], [same ceiling, enforced])
  cdraw.content((13.1, 7.6), [the crt answers by width alone], wrap: text.with(size: 6pt))
  cdraw.content((8.4, 1.6), [two apis, one width set: predicate and syscall agree on 1, 2, 4, 8], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the happens-before ladder

`memory_order` names six constants, and the ladder from weakest to
strongest is the entire mental model. cppreference's page defines each
rung. Relaxed: "there are no synchronization or ordering constraints
imposed on other reads or writes, only this operation's atomicity is
guaranteed", and again, relaxed operations "only guarantee atomicity and
modification order consistency." Acquire on a load: "no reads or writes in
the current thread can be reordered before this load. All writes in other
threads that release the same atomic variable are visible in the current
thread." Release on a store: "no reads or writes in the current thread can
be reordered after this store. All writes in the current thread are
visible in other threads that acquire the same atomic variable."
`acq_rel` gives a read-modify-write both halves. `seq_cst` is the default
and adds the global property: "a single total order exists in which all
threads observe all modifications in the same order." Consume exists in
the enum but is hollow here: "no known production compilers track
dependency chains: consume operations are lifted to acquire", and the
ir pin proves the lift on this compiler, the consume load of `@gate`
emits `load atomic i32, ptr @gate acquire`.

#diagram([the happens-before ladder, weakest at the bottom, what each rung adds], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (15.6, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((8.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  layer(6.8, [seq\_cst: one total order every thread agrees on], fill: luma(205))
  layer(5.5, [acq\_rel: both halves on one read-modify-write])
  layer(4.2, [acquire pairs with release: synchronizes-with])
  layer(2.9, [release: everything sequenced before it becomes visible])
  layer(1.6, [relaxed: atomicity and one modification order, nothing else], fill: luma(205))
  cdraw.content((19.9, 7.1), [the default of every #linebreak() non-explicit form], wrap: text.with(size: 6pt))
  cdraw.content((19.9, 4.9), [publication is this rung: #linebreak() payload then release store], wrap: text.with(size: 6pt))
  cdraw.content((19.9, 2.4), [counters live here: exact #linebreak() totals, zero ordering], wrap: text.with(size: 6pt))
  cdraw.content((8.3, 0.6), [consume would sit beside acquire but is lifted to it by this compiler], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The first demonstration is deliberately unglamorous. Two threads each add
100000 to one counter with `memory_order_relaxed`, and the total is
exactly 200000:

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 87, last: 94, caption: [relaxed adds: atomicity without ordering, no lost updates])

The count is exact because every read-modify-write is one indivisible
step, the property relaxed does guarantee. The ordering it does not
guarantee is the one the next rung demonstrates. An `atomic_flag` spinlock
is the textbook acquire/release pair, and the data it guards is plain,
non-atomic memory:

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 99, last: 111, caption: [the `atomic_flag` lock: `test_and_set` acquires, `clear` releases])

`guarded++` has no atomic in sight. The plain increments are correct
between threads because `test_and_set` with `memory_order_acquire` pairs
with `clear` with `memory_order_release`, the same pairing cppreference
names for mutual exclusion locks: when the lock is released by one thread
and acquired by another, everything before the release is visible after
the acquire. Two threads, 100000 guarded increments each, and the check
reads exactly 200000. The publication demo makes the mechanism one-shot
and even more minimal:

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 116, last: 126, caption: [the publisher: plain payload first, one release store last])

#listing("c-os-cloud/samples/src/Ch16/atomics.c", first: 151, last: 161, caption: [the reader: an acquire load is the only synchronization, no join yet])

Main does not join before reading. It spins on the acquire load, and the
release store is the only event that could have made `payload` visible,
so the check of all three plain values is a direct assertion of
synchronizes-with, cppreference's term for what a release store and an
acquire load of the same variable establish.

The ladder's rungs differ far less on this cpu than on paper. The page
states why: "On strongly-ordered systems, x86, SPARC TSO, IBM mainframe,
etc., release-acquire ordering is automatic for the majority of
operations. No additional CPU instructions are issued for this
synchronization mode; only certain compiler optimizations are affected."
The objdump pins in `Ch16/expect-ir.txt` show exactly that at `-O0`:
every `fetch_add`, whatever its ordering argument, `seq_cst`, `acq_rel`,
or relaxed, lowers to `lock xaddl`, acquire loads and release stores
compile to the same `movl` as relaxed ones, and `compare_exchange` is
`lock cmpxchgl`. The one visible upgrade is the `seq_cst` store, which
lowers to `xchgl`, an implicitly locked exchange: the page again,
"Total sequential ordering requires a full memory fence CPU instruction
on all multi-core systems." On x86-64 the ladder is a compiler contract
whose hardware bill is almost always zero, except on the top rung's
stores. One more inherited default belongs in the margin: the cc1
transcript that carries `-relaxed-aliasing` and `-fwrapv` also carries
`-fms-volatile`, and cppreference documents the microsoft reading it
enables, "every volatile write has release semantics and every volatile
read has acquire semantics" under default msvc settings, one more reason
the atomics layer is the only portable ordering tool this book uses.

== a lock-free spsc ring

The single-producer single-consumer ring puts the ladder to work in both
directions at once. Capacity is a power of two so the slot index is a
mask, the counters are unbounded so full and empty are `t - h == CAP` and
`t == h` with no wasted slot, and the two indices live on different cache
lines because the producer writes one and the consumer writes the other:

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 29, last: 35, caption: [the ring: two atomic indices, padded to separate cache lines])

The producer owns `tail` and the consumer owns `head`, so each side reads
its own index relaxed and the other side's with acquire, and publishes
its own with release:

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 45, last: 53, caption: [push: relaxed own tail, acquire consumer head, release new tail])

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 56, last: 64, caption: [pop: relaxed own head, acquire producer tail, release new head])

Line by line, `push` loads its own `tail` relaxed, loads the consumer's
`head` with acquire so any slot the consumer freed is safe to overwrite,
refuses when the ring holds `CAP` items, writes the slot, and only then
releases the new `tail`. The payload write lands before the release
store, and the consumer's acquire load of `tail` drags the payload into
visibility: the same publication pairing from the ladder, run at
production tempo. `pop` mirrors it. One thread at a time may call each
side, which is what spsc means. The atomics make the two sides safe
against each other without any lock, kernel call, or waiting.

#diagram([the ring with two items in flight: counters, mask, and who publishes what], length: 13pt, {
  for i in range(8) {
    let f = if i == 2 or i == 3 { luma(205) } else { luma(235) }
    cdraw.rect((4.0 + i * 1.7, 4.4), (5.7 + i * 1.7, 5.3), fill: f, radius: 0.02)
    cdraw.content((4.85 + i * 1.7, 4.85), [#i], wrap: text.with(size: 6pt))
  }
  cdraw.content((4.85, 5.95), [head h = 8], wrap: text.with(size: 6pt))
  cdraw.content((8.25, 5.95), [tail t = 10], wrap: text.with(size: 6pt))
  cdraw.content((13.6, 5.95), [slot index = counter & 7], wrap: text.with(size: 6.5pt))
  cdraw.line((4.85, 5.7), (4.85, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.25, 5.7), (8.25, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.8, 3.3), [t - h = 2 items in flight, capacity 8], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 2.2), [producer: write the slot, then release tail], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 1.3), [consumer: acquire tail, read slot, release head], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 0.4), [head and tail one cache line apart: \_Alignas(64) plus padding], wrap: text.with(size: 6pt))
})

The single-thread leg pins the container itself before any concurrency
enters. The ring fills to eight, refuses the ninth, drains 1 through 8 in
order, refuses the empty pop, and then twenty more items ride through one
at a time:

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 66, last: 82, caption: [the single-thread self pass: full, empty, in-order drain])

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 83, last: 95, caption: [the wrap leg: counters climb past CAP, only indexing wraps])

After the wrap leg both counters read 28 against a capacity of 8: the
mask does the wrapping, the counters never do, which is why full and
empty never need modular arithmetic beyond the subtraction. The
two-thread leg is the real claim, 64 items through 8 slots, eight laps:

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 109, last: 115, caption: [the producer: spin while full, yield])

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 117, last: 131, caption: [the consumer: spin while empty, demand in-order arrival])

#listing("c-os-cloud/samples/src/Ch16/spsc.c", first: 139, last: 153, caption: [the transfer: all 64 received, in producer order, ring empty after])

Both sides spin and `thrd_yield` rather than block, which is honest for a
sample but wasteful in production: a spinning consumer burns a core the
moment the ring runs dry. Closing that gap is the next section's api.

== WaitOnAddress versus the futex

The spin loop is the only piece of the ring a real system replaces. The
windows primitive is `WaitOnAddress`, four parameters and one promise:
"If the value at Address differs from the value at CompareAddress, the
function returns immediately. If the values are the same, the function
does not return until another thread in the same process signals that the
value at Address has changed by calling WakeByAddressSingle or
WakeByAddressAll or the timeout elapses, whichever comes first."

The sample pins the semantics single-threaded, `GetLastError` read after
every call:

#listing("c-os-cloud/samples/src/Ch16/waitaddr.c", first: 28, last: 40, caption: [the pinned error codes and the first two polls])

#listing("c-os-cloud/samples/src/Ch16/waitaddr.c", first: 41, last: 50, caption: [the width rejection and the changed-before-INFINITE probe])

Four probes, four exact answers. An unchanged value with a zero timeout
returns FALSE with `GetLastError` reporting `ERROR_TIMEOUT`, 1460, the
pair the page documents, "if the operation times out, GetLastError
returns `ERROR_TIMEOUT`." A value that already differs returns TRUE with
no wait at all. A 16-byte size returns FALSE with
`ERROR_INVALID_PARAMETER`, 87, and the page fixes the widths, `AddressSize`
"can be 1, 2, 4, or 8", the same ceiling as the crt's lock-free
predicate, exported from Synchronization.lib, which is why the gate
passes `-lsynchronization`, as chapter 1 noted. And a value that changed
before an
INFINITE wait returns TRUE immediately, because the comparison runs
before any sleeping, the poll-then-wait shape. The page supplies the
discipline that follows from one more property, WaitOnAddress "is
guaranteed to return when the address is signaled, but it is also
allowed to return for other reasons", so "after WaitOnAddress returns
the caller should compare the new value with the original undesired
value to confirm that the value has actually changed", in a loop, and
the page's own example is exactly that loop:

#listing("c-os-cloud/samples/src/Ch16/waitaddr.c", first: 62, last: 76, caption: [the waiter: capture, announce, wait, re-check, exactly the documented loop])

The armed handshake makes the two-thread check deterministic. The waiter
captures the value, then stores `armed`, then enters the loop, so main
knows the capture happened before it changes anything. Whether main's
store and wake win the race or trail it, `WaitOnAddress` is entered with
the old value in hand, and the loop's re-check reads the new one:

#listing("c-os-cloud/samples/src/Ch16/waitaddr.c", first: 82, last: 98, caption: [store, wake all, join: TRUE and the observed value 7])

`WakeByAddressAll` "wakes all threads that are waiting for the value of
an address to change", returns nothing, and waking an address nobody
waits on is harmless, probed. Its page adds the scope: "Only threads
within the same process can be woken." The page argues the placement
too: WaitOnAddress "is more efficient than using the Sleep function
inside a while loop because WaitOnAddress does not interfere with the
thread scheduler", and "is also simpler to use than an event object
because it is not necessary to create and initialize an event and then
make sure it is synchronized correctly with the value."

Linux has the same primitive one level down, and the man page names the
concept: a futex is "short for 'Fast user-space mutexes'", "identified
by a piece of memory which can be shared between processes or threads",
"a 32-bit value", and the kernel side blocks conditionally, "the kernel
will block only if the futex word has the value that the calling thread
supplied", with "the comparison of that value with the expected value,
and the actual blocking" happening atomically. The futex(7) page states
the layering that explains both systems: "Most programmers will in fact
not be using futexes directly" but rely on system libraries built on
them, such as NPTL, and "Futex operation occurs entirely in user space
for the noncontended case. The kernel is involved only to arbitrate the
contended case." Windows' built path is chapter 15's condition variable:
`SleepConditionVariableSRW` "sleeps on the specified condition variable
and releases the specified lock as an atomic operation", with the same
loop discipline, its page warns of "spurious wakeups" and "stolen
wakeups" and says "you should recheck a predicate (typically in a while
loop) after a sleep operation returns."

#diagram([the same primitive on both systems: compare in user space, sleep only when contended], length: 13pt, {
  let col(x, title) = {
    cdraw.rect((x, 6.5), (x + 9.8, 7.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + 4.9, 7.05), title, wrap: text.with(size: 6.5pt))
    cdraw.rect((x, 4.6), (x + 9.8, 6.3), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 2.7), (x + 9.8, 4.4), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 0.8), (x + 9.8, 2.5), fill: luma(235), radius: 0.02)
  }
  col(0.6, [windows: WaitOnAddress])
  cdraw.content((5.5, 5.85), [poll: compare the address], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 5.25), [against the captured value], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.95), [sleep if equal, any 1, 2, 4, 8 byte], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.35), [address, same process only], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 2.05), [built path: SleepConditionVariableSRW,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 1.45), [chapter 15's producer and consumer], wrap: text.with(size: 6pt))
  col(13.2, [linux: futex(2)])
  cdraw.content((18.1, 5.85), [compare the 32 bit futex word], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 5.25), [against the expected value], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.95), [sleep if it matches, the compare], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.35), [and the blocking are atomic], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 2.05), [built path: NPTL mutexes,], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 1.45), [condition variables, semaphores], wrap: text.with(size: 6pt))
  cdraw.content((11.8, -0.6), [both run uncontended in user space and involve the kernel only to arbitrate the contended case], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The ring in the previous section plus this section's waiter is the
complete pattern production code uses: spin on the atomic indices, and
when the ring is full or empty, sleep on the index address until the
other side publishes. Chapter 17 leaves the single machine for the
scheduler's own model, where the thread's wait, ready, and run states
become the unit of study.

sources: learn.microsoft.com, WaitOnAddress, WakeByAddressAll, and
SleepConditionVariableSRW pages, accessed 2026-09-12; man7.org futex(2)
and futex(7), accessed 2026-09-12; en.cppreference.com memory order page,
accessed 2026-09-12; the header trail, the search order, the lock-free
predicate, the enum values, the `char8_t` absence, the
`-Watomic-alignment` block, and the instruction-level lowers probed on
this machine the same day. Sample behavior verified by `make verify-c`,
41 checks in chapter 16 of the samples suite.
