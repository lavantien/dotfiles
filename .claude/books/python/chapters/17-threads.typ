#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= threads and the gil

Chapter 16 started separate processes and paid for every one with a spawn
and a pickle. This chapter stays inside one process and starts threads,
which share the address space the interpreter already built. The win and
the trap come from the same fact: two threads can both touch the same
list, so neither needs a copy, and neither can assume it is alone. The
threading page fixes the contract in one paragraph, quoted here from the
3.14 documentation: "In CPython, due to the Global Interpreter Lock, only
one thread can execute Python code at once (even though certain
performance-oriented libraries might overcome this limitation)." The same
paragraph ends with the trade this chapter measures instead of asserting:
"threading is still an appropriate model if you want to run multiple
I/O-bound tasks simultaneously." Every behavioral claim below is a check
in the 5 samples under `Ch17/`, 39 in total, run on the pinned 3.14.7
interpreter.

== threads and the interpreter

A thread is `threading.Thread(target=fn, args=...)` plus `start()` and
`join()`. The target runs in a new kernel thread with its own stack and
its own ident, and `start()` returns immediately, so the creator needs
`join()` to observe completion. The first sample keeps the whole
discipline in one block:

#listing("python/samples/src/Ch17/basics.py", first: 32, last: 48, caption: [four threads built, started, joined, each recording its own name])

The workers write `threading.current_thread().name` from inside the
thread because the creator cannot assume it observed anything before the
worker ran. After the joins, `results` is exactly `["w0", "w1", "w2",
"w3"]`. The timing assertion in the same file is the io promise made
concrete: 4 sleeps of 0.25 s finish in about 0.25 s of wall time, while
the same 4 sleeps run sequentially in the main thread cost about 1 s:

#listing("python/samples/src/Ch17/basics.py", first: 50, last: 62, caption: [overlapped waits versus sequential waits, one measured ratio])

The join page hands over one more contract this book leans on: "you must
call `is_alive()` after `join()` to decide whether a timeout happened".
`join()` itself always returns `None`, so the sample times out a 1 s
sleeper with a 0.05 s join, reads `is_alive()` as True, then joins again
without a hit and requires it dead:

#listing("python/samples/src/Ch17/basics.py", first: 64, last: 74, caption: [a timed-out join leaves the thread alive, is\_alive decides])

The daemon flag closes the section, because it is the most
misunderstood line on the page. Two sentences carry the whole weight:
"The entire Python program exits when no alive non-daemon threads are
left", and the note that follows: "Daemon threads are abruptly stopped
at shutdown. Their resources (such as open files, database transactions,
etc.) may not be released properly. If you want your threads to stop
gracefully, make them non-daemonic and use a suitable signalling
mechanism such as an `Event`." A daemon thread is not a background
worker you can forget about, it is a thread the interpreter reserves the
right to kill mid-sentence. The sample only checks the flag mechanics,
default False and settable at construction, and every worker in this
book stays non-daemonic and exits through an `Event`, a queue shutdown,
or a completed loop.

#diagram([what a process buys and what a thread buys: chapter 16's two heaps against this chapter's one], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 7.4, 9.2, 1.0, [chapter 16: two processes], fill: luma(205))
  cell(1.0, 5.2, 3.8, 1.9, [process a #linebreak() own heap, own pid])
  cell(5.6, 5.2, 3.8, 1.9, [process b #linebreak() own heap, own pid])
  cdraw.content((5.2, 4.4), [no shared memory, #linebreak() data crosses by pickle], wrap: text.with(size: 6pt))
  cell(12.6, 7.4, 9.2, 1.0, [this chapter: one process], fill: luma(205))
  cell(13.0, 5.2, 8.4, 1.9, [one address space: heap, modules, #linebreak() globals, open files], fill: luma(220))
  cell(13.4, 2.6, 3.6, 1.5, [thread 1 #linebreak() own stack, own ident])
  cell(17.4, 2.6, 3.6, 1.5, [thread 2 #linebreak() own stack, own ident])
  cdraw.line((15.2, 4.1), (15.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.2, 4.1), (19.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.2, 4.5), [both reach everything], wrap: text.with(size: 6pt))
  cdraw.content((11.2, 1.2), [one ident per thread, one heap per process: the gil guards the shared heap], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the gil

The Global Interpreter Lock is one mutex inside cpython that a thread
must hold to run Python bytecode. The threading page states the
consequence for cpu work plainly: "the GIL limits the performance gains
of threading when it comes to CPU-bound tasks, as only one thread can
execute Python bytecode at a time." The interpreter does not even run
its own scheduler for the handoffs, in the `sys` page's words: "which
thread becomes scheduled at the end of the interval is the operating
system's decision. The interpreter doesn't have its own scheduler." What
the interpreter sells is the interval itself, `sys.setswitchinterval`,
whose page reads: "This floating-point value determines the ideal
duration of the 'timeslices' allocated to concurrently running Python
threads", with the honest caveat that "the actual value can be higher".
The default is 0.005 s, probed and asserted in the sample:

#listing("python/samples/src/Ch17/gil.py", first: 32, last: 44, caption: [the gil flag on this interpreter, the default interval, one round trip])

`sys._is_gil_enabled()` is the probe that makes the rest of the file
meaningful: everything after it runs on the standard gil build. The
measurement is two loops of the same arithmetic, one in the main thread
and one spread over 4 threads, each thread doing the full workload:

#listing("python/samples/src/Ch17/gil.py", first: 46, last: 73, caption: [one thread versus 4 threads on identical cpu work, exact results])

The arithmetic is checked exactly both times, `(LIMIT-1)*LIMIT//2`, so
the only variable is time: 4 threads take about 4 times as long as 1,
because the bytecode cannot overlap. The guard asserts the wall time of
the 4-thread run is at least twice the single-thread run, which is
arithmetic over the gil's own promise. Then the same file flips the
workload to `time.sleep`, and 4 sleeps of 0.25 s finish in about 0.25 s:
a blocking call releases the gil, so waiting overlaps even when
computing cannot.

#listing("python/samples/src/Ch17/gil.py", first: 75, last: 84, caption: [the same four threads sleeping instead: the gil is released])

#callout("note", "free-threaded builds exist, and this book does not run one", [
  PEP 779, "Criteria for supported status for free-threaded Python",
  was accepted for 3.14: "Phase II would make the free-threaded build
  officially supported but still optional", following the phase I of
  3.13 that made the build "available but explicitly experimental". On
  windows the free-threaded runtime is a separate binary with a `t`
  suffix, installed as `py install 3.14t` and run as `py -V:3.14t`,
  with `python3.14t.exe` as its alias. The threading page keeps the
  boundary visible: "As of Python 3.13, free-threaded builds can
  disable the GIL, enabling true parallel execution of threads, but
  this feature is not available by default (see PEP 703)." This book
  pins the standard build, and check 2 of `gil.py` asserts the gil is
  enabled before any serialization claim is made. The multiprocessing
  chapter, #xref-to("python", "multiprocessing"), is how this book gets
  parallel cpu work on the standard build.
])

#diagram([one thread through the gil: the states and the two ways out of running], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 5.6, 5.0, 1.2, [running: holds the gil, #linebreak() executing bytecode])
  box(8.2, 5.6, 5.6, 1.2, [gil queue: waiting, #linebreak() no bytecode, no lock])
  box(15.6, 5.6, 6.0, 1.2, [blocked in a system call: #linebreak() gil released])
  cdraw.line((5.6, 6.2), (8.2, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.9, 6.7), [interval ends, #linebreak() drop request], wrap: text.with(size: 6pt))
  cdraw.line((8.2, 5.9), (5.6, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.9, 5.3), [acquire wins, #linebreak() os picks the winner], wrap: text.with(size: 6pt))
  cdraw.line((13.8, 6.2), (15.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.7, 6.7), [read, sleep, #linebreak() wait], wrap: text.with(size: 6pt))
  cdraw.line((15.6, 5.9), (13.8, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.7, 5.3), [call returns, #linebreak() requeue], wrap: text.with(size: 6pt))
  box(8.2, 2.4, 13.4, 1.2, [one thread holds the gil at a time: the cpu-bound path cycles the left pair, the io-bound path steps out right], fill: luma(220))
  cdraw.content((10.9, 1.0), [switch interval 0.005 s default, probed: how long a running thread may keep the token when others wait], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== locks and queues

Shared state needs serialization, and the toolbox has exactly the pieces
the samples exercise. `Lock` is the base one: one holder, `acquire`
refuses everyone including the owner while held, `release` hands it
back. `RLock` is the reentrant variant, the owner may acquire again and
must release once per acquire. `Semaphore(n)` bounds concurrent holders
to n, `Event` is a one-bit broadcast that any thread can set and any
number can wait on, and `Condition` adds the predicate loop, wait until
something becomes true. The mutual exclusion check runs 4 workers
through 20000 locked increments each and watches the inside counter
never exceed 1:

#listing("python/samples/src/Ch17/locks.py", first: 62, last: 71, caption: [the lock gate: one holder at a time, refused while held])

#listing("python/samples/src/Ch17/locks.py", first: 73, last: 89, caption: [80 000 locked increments, exact total, zero double entries])

The semaphore check runs 4 workers through a `BoundedSemaphore(2)` and
asserts the observed peak of simultaneous holders never exceeds 2 while
all 800 entries complete, the event check wakes a waiter with `set()`
and resets it with `clear()`, and the condition check moves one payload
through a one-slot handoff with `wait_for`:

#listing("python/samples/src/Ch17/locks.py", first: 123, last: 138, caption: [semaphore(2): peak holders bounded, all work done])

#listing("python/samples/src/Ch17/locks.py", first: 155, last: 166, caption: [condition: wait\_for the predicate, notify the other side])

Between threads, the safe channel is `queue.Queue`, whose page opens
with the promise that matters: "The `Queue` class in this module
implements all the required locking semantics." The producer and the
consumer never share a bare list, they share the queue, and the queue
owns the lock. Completion has a protocol of its own: "Blocks until all
items in the queue have been gotten and processed", the `join` contract,
paid back one `task_done()` per `get()`. Since 3.13 the shutdown has
been first-class: "Put a `Queue` instance into a shutdown mode", after
which "Future calls to `put()` raise `ShutDown`" and a drained queue
refuses `get()` the same way:

#listing("python/samples/src/Ch17/queues.py", first: 15, last: 24, caption: [the drain worker: get, task\_done, exit on shutdown])

#listing("python/samples/src/Ch17/queues.py", first: 54, last: 83, caption: [put 60, join, shutdown, then both refusals are checked])

The thread pool wraps the same channel in a manager:
`ThreadPoolExecutor` takes submit calls, hands each to a worker thread,
and hands back a future. Its default width is documented arithmetic,
"min(32, (os.process_cpu_count() or 1) + 4)" since 3.13, enough workers
for io overlap without a thread per task. The sample checks ordered
results from `submit`, the re-raise of a worker's exception at
`result()`, and that `map` returns results in input order however the
finishes interleave:

#listing("python/samples/src/Ch17/queues.py", first: 102, last: 107, caption: [submit and result: the future carries the value out])

#listing("python/samples/src/Ch17/queues.py", first: 126, last: 130, caption: [map keeps input order under staggered finish times])

#diagram([the toolbox around one queue: producers, the lock inside, consumers, the pool under them], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(1.0, 7.6, 4.2, 1.1, [producer thread])
  cell(1.0, 6.2, 4.2, 1.1, [producer thread])
  cell(7.6, 6.4, 6.8, 2.4, [queue.queue #linebreak() own lock, own condition, #linebreak() put and get are safe], fill: luma(205))
  cell(16.8, 7.6, 4.4, 1.1, [consumer thread])
  cell(16.8, 6.2, 4.4, 1.1, [consumer thread])
  cdraw.line((5.2, 8.15), (7.6, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.2, 6.75), (7.6, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 7.4), (16.8, 8.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 7.0), (16.8, 6.75), stroke: luma(100), mark: (end: ">"))
  cell(7.6, 4.4, 6.8, 1.1, [task\_done per get, join until empty])
  cdraw.line((11.0, 6.4), (11.0, 5.5), stroke: luma(140))
  cell(0.6, 2.6, 5.4, 1.2, [lock, rlock: serialize])
  cell(6.5, 2.6, 4.6, 1.2, [semaphore: bound holders])
  cell(11.6, 2.6, 4.0, 1.2, [event: broadcast])
  cdraw.content((18.0, 3.2), [threadpoolexecutor #linebreak() owns the workers #linebreak() and the futures], wrap: text.with(size: 6pt))
  cdraw.rect((16.8, 2.6), (22.0, 3.8), fill: luma(220), radius: 0.02)
  cdraw.content((11.3, 1.2), [the primitives guard shared state, the queue moves it, the pool schedules the workers], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== races demonstrated safely

A race needs two ingredients: a check and an act with a gap between
them, and a second thread stepping into the gap. The last sample builds
the gap on purpose, first as pure arithmetic with no threads at all. One
thread's `counter += 1` is three micro-steps, read, add, store, and the
simulator round-robins two threads one micro-step at a time:

#listing("python/samples/src/Ch17/race.py", first: 16, last: 32, caption: [one increment as three yield points, the locked whole-increment variant])

Both threads read 0, both store 1, and 6 intended adds leave 3 in the
counter. The locked generator yields once per whole increment, the same
scheduler interleaves, and the total is 6:

#listing("python/samples/src/Ch17/race.py", first: 48, last: 63, caption: [the same round-robin at step granularity loses 3, at increment granularity loses 0])

Real threads do not interleave on request, so the sample widens the gap
instead of gambling on timing. The check-then-act worker reads the
counter, spins a 64-iteration loop across compiler and interpreter
checkpoint territory, then writes back. The tight worker keeps the whole
update inside one stretch:

#listing("python/samples/src/Ch17/race.py", first: 83, last: 96, caption: [the wide window loses updates, the tight loop cannot be entered mid-update])

With the switch interval pushed to a microsecond, the tight loop lost 0
updates out of 100000 in every run on this box, probed, while the wide
window lost thousands of its 8000, a separation of three orders of
magnitude that holds every run. The practical reading: absence of a
crash is not correctness, it is a gap the scheduler has not stepped
into yet, and the shape of the code decides the size of the gap. The fix
is the lock around the whole span, and the sample prices it:

#listing("python/samples/src/Ch17/race.py", first: 127, last: 165, caption: [forced switching, the two loop shapes measured, the loss asserted])

The locked run of the wide workload completes all 8000 exactly and costs
about the same wall time as the broken one, measured around 1 to 1 on
this box, because 8000 lock acquisitions are cheap next to the work they
guard. Correctness bought for nothing is the good trade, the one the
c-os-cloud book made with its mutexes, #xref-to("c-os-cloud", "threads"),
and the one this chapter closes on.

#diagram([the same two threads, unlocked and locked: where the second write lands], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((5.8, 8.9), [unlocked: both read v, both write v+1], wrap: text.with(size: 6.5pt, weight: 700))
  cell(0.6, 6.6, 4.2, 1.1, [thread a: read counter, v])
  cell(0.6, 5.2, 4.2, 1.1, [thread a: store v+1])
  cell(12.2, 6.6, 4.2, 1.1, [thread b: read counter, v])
  cell(12.2, 5.2, 4.2, 1.1, [thread b: store v+1])
  cdraw.line((4.8, 7.15), (12.2, 7.15), stroke: luma(140), mark: (end: ">"))
  cdraw.content((8.5, 7.45), [b reads before a stores], wrap: text.with(size: 6pt))
  cdraw.content((8.5, 5.75), [two stores, one survivor, +1 not +2], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((5.8, 3.9), [locked: the whole span is one critical section], wrap: text.with(size: 6.5pt, weight: 700))
  cell(0.6, 1.4, 4.6, 1.6, [with lock: #linebreak() read, add, store])
  cell(8.4, 1.4, 4.6, 1.6, [waits at acquire #linebreak() until release])
  cell(16.2, 1.4, 4.6, 1.6, [then reads v+1 #linebreak() and stores v+2])
  cdraw.line((5.2, 2.2), (8.4, 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 2.2), (16.2, 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.9, 0.5), [the serialization is the cost, the exact total is the purchase], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "chapter 17 in the gate", [
  The 5 samples under `python/samples/src/Ch17/` print 39 ok lines:
  `basics.py` 7, `gil.py` 8, `locks.py` 8, `queues.py` 9, `race.py` 7.
  Every timing claim is bounded on both sides, the deterministic race
  arithmetic is exact, and the interpreter pin asserts 3.14.7 before
  the first check of every file. A red line here is a real behavior
  change, not a flake: the lost-update check fails if the gil stops
  serializing, and the overlap checks fail if waits stop releasing it.
])

sources: docs.python.org/3.14/library/threading.html (the global
interpreter lock paragraph, daemon and join semantics, the
free-threading note pointing at PEP 703), docs.python.org/3.14/library/
sys.html (setswitchinterval, getswitchinterval, \_is\_gil\_enabled),
docs.python.org/3.14/library/queue.html (locking semantics, task\_done
and join, shutdown and the ShutDown exception, both added in 3.13),
docs.python.org/3.14/library/concurrent.futures.html (threadpool
executor default max\_workers since 3.13), all accessed 2026-09-12;
peps.python.org PEP 779 (phase II makes the free-threaded build
officially supported but still optional, phase I experimental in 3.13)
and docs.python.org/3.14/using/windows.html (free-threaded binaries via
the t tag, python3.14t.exe alias, py -V:3.14t), accessed 2026-09-12;
the 0.005 s default interval, the zero-loss tight loop, and the
thousands lost through the widened window probed on this machine the
same day. Sample behavior verified by `make verify-py`, 39 checks in
chapter 17.
