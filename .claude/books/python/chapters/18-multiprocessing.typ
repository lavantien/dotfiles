#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= multiprocessing and process patterns

Chapter 17 proved the gil serializes bytecode and released the lock only
for waits. The way around it on the standard build is the oldest one:
more processes, each with its own interpreter and its own gil. The
multiprocessing module sells that with three prices stamped on the
receipt, and this chapter pays each one measured: on windows every
child is spawned, never forked, every argument crosses as a pickle, and
every byte of shared state needs a mechanism bought on purpose. The 4
samples under `Ch18/` carry 26 checks on the pinned 3.14.7 interpreter,
and the threads-versus-processes decision at the end is measured, not
asserted, #xref-to("python", "threads").

== processes on windows

The start-method table is short on this platform. Of the three methods
the documentation lists, spawn is "The default on Windows and macOS",
and only spawn exists here at all, asserted directly:

#listing("python/samples/src/Ch18/spawn.py", first: 39, last: 45, caption: [windows offers exactly one start method, and it is spawn])

The posix half of the table changed under this version. The fork entry
carries the note: "Changed in version 3.14: This is no longer the
default start method on any platform. Code that requires fork must
explicitly specify that via `get_context()` or `set_start_method()`",
with the reason one line up: "On POSIX platforms the default start
method was changed from fork to forkserver to retain the performance
but avoid common multithreaded process incompatibilities." Fork still
exists on posix, but nothing defaults to it anywhere in 3.14, which
makes spawn discipline a portable habit instead of a windows quirk.

Spawn means the child is a fresh interpreter that re-imports your main
file before running the target. The sample watches it happen: the child
reports its own pid, its name `Process-1`, and the module name it saw
on import, `__mp_main__`, probed:

#listing("python/samples/src/Ch18/spawn.py", first: 47, last: 63, caption: [the child's own report: new pid, parent recorded, this file re-imported])

That re-import is why every sample in this chapter, and every program
that starts processes on windows, guards its entry point with
`if __name__ == "__main__":`. Without the guard the child's import
would run the parent code again and fork the process tree recursively.
The guard is not style, it is the spawn protocol, and the function the
child runs must live at module level so the import can find it. The
exit-code protocol follows the same discipline: a clean child leaves
0, a child that raises `SystemExit(3)` leaves 3, and a child that lets
an exception escape leaves 1 with the traceback on stderr:

#listing("python/samples/src/Ch18/spawn.py", first: 65, last: 77, caption: [exitcode 3 for systemexit(3), exitcode 1 for the uncaught exception])

The second price is pickling. The Process page states it: "In general,
all arguments to `Process` must be picklable", and the target crosses
the same way, by qualified name, which is why a lambda cannot ride
along while a module-level function can. The mechanics of what pickle
will and will not take are chapter 15's subject,
#xref-to("python", "files"), the boundary here is only observed:

#listing("python/samples/src/Ch18/spawn.py", first: 79, last: 88, caption: [the pickle boundary: a lambda refuses, a named function pickles by reference])

The third price is isolation, and it cuts in the parent's favor: the
child mutates the list it was handed and the parent's list is
untouched, because the child unpickled its own copy:

#listing("python/samples/src/Ch18/spawn.py", first: 90, last: 98, caption: [the child doubled its copy, the parent's list never moved])

#diagram([what spawn does between start and run: the steps and where the guard sits], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.6, 4.6, 1.5, [parent: #linebreak() process(target, args)], fill: luma(205))
  cell(6.4, 6.6, 4.6, 1.5, [pickle target name #linebreak() and args to a pipe])
  cell(12.2, 6.6, 4.6, 1.5, [new interpreter: #linebreak() spawn, no fork])
  cell(18.0, 6.6, 3.8, 1.5, [run, exitcode, #linebreak() join observes], fill: luma(205))
  cdraw.line((5.2, 7.35), (6.4, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 7.35), (12.2, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 7.35), (18.0, 7.35), stroke: luma(100), mark: (end: ">"))
  cell(6.4, 4.4, 10.4, 1.5, [child imports your main file as \_\_mp\_main\_\_: #linebreak() the \_\_main\_\_ guard keeps the import side-effect free], fill: luma(220))
  cdraw.line((14.5, 6.6), (14.5, 5.9), stroke: luma(100), mark: (end: ">"))
  cell(6.4, 2.4, 10.4, 1.5, [unpickle: target resolved by qualified name, #linebreak() args unpickled into fresh objects])
  cdraw.line((11.6, 4.4), (11.6, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 3.15), (18.9, 3.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.9, 3.15), (18.9, 6.6), stroke: luma(140))
  cdraw.content((10.9, 1.0), [anything in target or args that pickle refuses stops the spawn before the child runs], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== pools and executors

One process is plumbing, a pool is a schedule. The older
`multiprocessing.Pool` and the newer
`concurrent.futures.ProcessPoolExecutor` answer the same need, and the
second is where the book and the capstone live, but the first is still
everywhere in the field. The sample runs the same squaring workload
through every spelling the pool offers and requires one answer:

#listing("python/samples/src/Ch18/pools.py", first: 31, last: 45, caption: [map, chunksize, imap, and starmap produce the same ordered list])

`chunksize` is the one knob with documented teeth. The executor's
`map` "chops iterables into a number of chunks which it submits to the
pool as separate tasks", and "For very long iterables, using a large
value for chunksize can significantly improve performance compared to
the default size of 1", because every task costs a pickle round trip
and the default pays it per item. The executor half of the sample is
the api this book uses forward:

#listing("python/samples/src/Ch18/pools.py", first: 54, last: 71, caption: [submit and result, chunked map, and the worker exception re-raised in the parent])

The futures contract is the quiet improvement over `Pool.apply_async`:
`submit` returns immediately, `result()` carries the value or re-raises
the worker's exception in the parent with its message intact, and
`done()` reports without waiting. The width of the pool is documented
arithmetic, "If max_workers is None or not given, it will default to
`os.process_cpu_count()`" since 3.13, with a windows lid: "On Windows,
max_workers must be less than or equal to 61", and 0 is refused at
construction. The failure mode that matters operationally is the broken
pool, and it is documented behavior: "Should initializer raise an
exception, all currently pending jobs will raise a `BrokenProcessPool`,
as well as any attempt to submit more jobs to the pool":

#listing("python/samples/src/Ch18/pools.py", first: 80, last: 88, caption: [an initializer that raises turns every submit into BrokenProcessPool])

#diagram([the three ways to buy child processes, side by side], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 7.4, 6.8, 1.0, [process, direct], fill: luma(205))
  cell(7.8, 7.4, 6.8, 1.0, [multiprocessing.pool], fill: luma(205))
  cell(15.0, 7.4, 6.8, 1.0, [processpoolexecutor], fill: luma(205))
  cell(0.6, 6.1, 6.8, 1.1, [one child per call, #linebreak() you join it yourself])
  cell(7.8, 6.1, 6.8, 1.1, [map, imap, starmap, #linebreak() apply\_async])
  cell(15.0, 6.1, 6.8, 1.1, [submit, map, futures, #linebreak() as\_completed])
  cell(0.6, 4.8, 6.8, 1.1, [exitcode after join])
  cell(7.8, 4.8, 6.8, 1.1, [ordered results, #linebreak() chunksize knob])
  cell(15.0, 4.8, 6.8, 1.1, [future.result() re-raises #linebreak() the worker error])
  cell(0.6, 3.5, 6.8, 1.1, [queues or shared state #linebreak() for data])
  cell(7.8, 3.5, 6.8, 1.1, [value in, value out])
  cell(15.0, 3.5, 6.8, 1.1, [value in, value out, #linebreak() broken pool is loud])
  cell(0.6, 2.2, 21.2, 1.0, [all three spawn on windows, all three pickle every argument, all three need the \_\_main\_\_ guard], fill: luma(220))
  cdraw.content((11.2, 1.2), [the capstone offload uses the rightmost column], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== shared state

Processes start with nothing in common, so every shared number is a
purchase. The cheapest is `Value` and `Array`, ctypes storage in shared
memory wrapped with a lock you can take yourself: the sample's child
takes `value.get_lock()` around each increment, and 2 children adding
1000 each land exactly 2000, the same mutual exclusion discipline
chapter 17 proved for threads:

#listing("python/samples/src/Ch18/shared.py", first: 46, last: 56, caption: [one shared value, two children, increments under its own lock])

The raw page is `multiprocessing.shared_memory`, a named block of bytes
any process can attach to. Its lifecycle rule is the whole
programming model: "shared memory blocks may outlive the original
process that created them", so "the `close()` method should be called"
when one process is done, "and the `unlink()` method should be called"
exactly once, by whoever owns the deletion, when no process needs the
block. Windows bends the tracker in your favor, "track is ignored on
Windows, which has its own tracking and automatically deletes shared
memory when all handles to it have been closed", probed here by the
child attaching by name, reading the parent's bytes, and writing one
back:

#listing("python/samples/src/Ch18/shared.py", first: 68, last: 87, caption: [attach by name, read the parent's bytes, write one back, close and unlink])

Between the two sits `ShareableList`, fixed-length typed slots in one
block, and at the top of the price range the `Manager`, a server
process that owns real dict and list objects and hands out proxies
that forward every operation over a pipe. A proxy behaves like the
container, but every mutation is a message:

#listing("python/samples/src/Ch18/shared.py", first: 103, last: 115, caption: [manager proxies: the child's writes visible in the parent])

#diagram([where each flavor of shared state lives, against the private heaps], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.6, 8.4, 1.5, [parent process #linebreak() own heap, own gil, own pid], fill: luma(205))
  cell(13.4, 6.6, 8.4, 1.5, [child process #linebreak() own heap, own gil, own pid], fill: luma(205))
  cdraw.content((11.2, 7.35), [pickle #linebreak() both ways], wrap: text.with(size: 6pt))
  cdraw.line((9.0, 7.35), (13.4, 7.35), stroke: luma(140), mark: (end: ">"))
  cdraw.line((13.4, 7.0), (9.0, 7.0), stroke: luma(140), mark: (end: ">"))
  cell(0.6, 4.6, 10.2, 1.4, [value, array: ctypes storage #linebreak() in shared memory, own lock])
  cell(11.6, 4.6, 10.2, 1.4, [shared\_memory block: raw bytes, #linebreak() attach by name, close and unlink])
  cdraw.line((4.7, 6.6), (4.7, 6.0), stroke: luma(100))
  cdraw.line((17.6, 6.6), (17.6, 6.0), stroke: luma(100))
  cdraw.line((17.6, 6.0), (12.0, 5.3), stroke: luma(100))
  cell(0.6, 2.6, 10.2, 1.4, [manager process: real dict and list, #linebreak() every operation is a proxied message])
  cell(11.6, 2.6, 10.2, 1.4, [copies across spawn: the child's unpickled #linebreak() arguments, never aliased])
  cdraw.line((5.7, 4.6), (5.7, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 6.6), (16.4, 4.0), stroke: luma(140))
  cdraw.content((11.2, 1.2), [cheapest at the left, most general at the bottom: every step up costs a message or a syscall per access], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== process patterns

The patterns are short once the prices are paid. The worker pool is
`map` over an input list, the offload shape the capstone of
#xref-to("python", "capstone1") builds its analytics stage on. The queue
pipeline is two processes and two queues, producer to consumer, with a
`None` sentinel to stop the consumer without killing it:

#listing("python/samples/src/Ch18/patterns.py", first: 21, last: 35, caption: [produce to a sentinel, consume until it, count what passed])

The wiring drains results before joining, the deadlock discipline from
chapter 16's pipes applied to queues, and the sentinel keeps the
consumer's exit ordinary:

#listing("python/samples/src/Ch18/patterns.py", first: 55, last: 71, caption: [drain the results, then join, then close: 30 squares in order])

Scatter-gather is the pool pattern with the data pre-shaped: split the
input into batches, one task per batch, gather the partials in order,
and the recombination is checked against the sequential answer:

#listing("python/samples/src/Ch18/patterns.py", first: 73, last: 79, caption: [4 batches of 25, gathered order exact against the sequential sum])

The decision the chapter exists for is measured last. The same burn
loop from chapter 17 runs 4 times through a thread pool and 4 times
through a process pool, and on this box the processes win by about 3 to
1, 1.633 s threaded against 0.548 s in processes in the recorded run,
spawn cost included:

#listing("python/samples/src/Ch18/patterns.py", first: 81, last: 99, caption: [identical cpu work, threads serialized by the gil, processes parallel])

#diagram([the choice, and where each workload goes], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((11.2, 9.2), [what does the workload do between requests?], wrap: text.with(size: 6.5pt, weight: 700))
  cell(1.6, 6.9, 8.0, 1.3, [waits: sockets, files, sleeps])
  cell(12.8, 6.9, 8.0, 1.3, [computes: parses, hashes, folds])
  cdraw.line((11.2, 8.7), (5.6, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 8.7), (16.8, 8.2), stroke: luma(100), mark: (end: ">"))
  cell(1.6, 5.1, 8.0, 1.3, [threads or asyncio: #linebreak() the gil is released], fill: luma(220))
  cell(12.8, 5.1, 8.0, 1.3, [processes: one gil each, #linebreak() spawn and pickle per task])
  cdraw.line((5.6, 6.9), (5.6, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 6.9), (16.8, 6.4), stroke: luma(100), mark: (end: ">"))
  cell(12.8, 3.3, 8.0, 1.3, [processpoolexecutor.map, #linebreak() chunksize for long inputs])
  cdraw.line((16.8, 5.1), (16.8, 4.6), stroke: luma(100), mark: (end: ">"))
  cell(12.8, 1.5, 8.0, 1.3, [the capstone offload, #linebreak() measured 3 to 1 over threads])
  cdraw.line((16.8, 3.3), (16.8, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 3.6), [mix: io front, #linebreak() cpu behind a pool], wrap: text.with(size: 6pt))
  cdraw.line((9.6, 4.0), (12.8, 3.9), stroke: luma(140), mark: (end: ">"))
  cdraw.content((11.2, 0.5), [measured on this box, chapter 18 check 5 of patterns.py: 1.633 s threaded, 0.548 s in processes], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "chapter 18 in the gate", [
  The 4 samples under `python/samples/src/Ch18/` print 26 ok lines:
  `spawn.py` 7, `pools.py` 8, `shared.py` 6, `patterns.py` 5. Every
  sample that starts processes carries the `__main__` guard and passes
  only module-level targets, every join has a timeout, and every
  shared block is closed and unlinked. The two deliberate failures,
  the crashing child and the broken initializer, print their
  tracebacks on stderr by design: their exit codes and the
  `BrokenProcessPool` are what the checks assert.
])

sources: docs.python.org/3.14/library/multiprocessing.html (start
methods and the two 3.14 fork notes, picklability of Process arguments,
the \_\_main\_\_ guard requirement), docs.python.org/3.14/library/
concurrent.futures.html (processpoolexecutor max\_workers default and
the windows 61 cap, chunksize guidance, the 3.14 start-method note,
initializer and BrokenProcessPool), docs.python.org/3.14/library/
multiprocessing.shared\_memory.html (close and unlink lifecycle, the
windows tracking note, shareablelist), all accessed 2026-09-12; the
\_\_mp\_main\_\_ import name, the exitcode ladder, and the 3 to 1
thread-to-process ratio probed on this machine the same day. Sample
behavior verified by `make verify-py`, 26 checks in chapter 18.
