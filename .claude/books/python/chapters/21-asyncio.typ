#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= asyncio

Chapter 17 bought io concurrency with threads and paid for each one, chapter 18
paid again in processes when the work turned cpu bound. asyncio buys the same
io concurrency with zero extra execution vehicles: one thread, one loop, and
coroutines that hand control back at every wait. The chapter assembles the
machine in four steps, the loop itself and the windows fact about which loop
you actually get, then tasks and the groups that make their failures honest,
then queues as the backpressure layer between producers and workers, and
finally the three escape hatches that leave the loop without losing it,
threads, subprocesses, and streams. Every behavioral claim below is an ok line
in the four samples, 54 in total, or a sentence quoted from a page at
docs.python.org fetched 2026-09-12. The async web framework of
#xref-to("python", "fastapi") rides this loop unchanged, and the capstone
pipeline of
#xref-to("python", "capstone1") is this chapter's queue discipline at full
size.

== the event loop

A coroutine is a function that cannot run itself. The docs put the first
hazard in one line, "Note that simply calling a coroutine will not schedule it
to be executed", and the interpreter is not bluffing: calling the function
builds a coroutine object and returns it, body untouched. The sample proves it
the direct way, by checking the log the body would have written, then closes
the object so the interpreter never has to warn about it:

#listing("python/samples/src/Ch21/loop.py", first: 34, last: 41, caption: [calling a coroutine builds an object and runs nothing, `close` retires it])

The entry point is `asyncio.run`, and the runner page states the whole
contract: "This function runs the awaitable, taking care of managing the
asyncio event loop, *finalizing asynchronous generators*, and closing the
executor", "The loop is closed at the end", it "should be used as a main entry
point for asyncio programs, and should ideally only be called once", and "This
function cannot be called when another asyncio event loop is running in the
same thread". The last sentence has a runtime check with no loop of your own
making, `asyncio.get_running_loop` outside a coroutine context is a
`RuntimeError` by definition:

#listing("python/samples/src/Ch21/loop.py", first: 43, last: 48, caption: [outside any loop, `get_running_loop` refuses rather than inventing one])

What the loop actually does to a running coroutine is measured, not asserted.
One probe coroutine grabs the running loop, checks that the object identity
survives an await, and times a sleep on `loop.time`, the loop's own monotonic
clock:

#listing("python/samples/src/Ch21/loop.py", first: 13, last: 18, caption: [the probe: one loop object, identity checked across the suspension, duration measured on loop time])

`await` is that suspension. The docs guarantee the delay is a floor, and the
sample holds the loop to it, `elapsed >= 0.05` on a `sleep(0.05)`, while the
value carried through the suspension comes back unchanged. The same probe
returns the loop object to `main`, where two more of the runner page's
sentences turn into checks, the loop is closed after `asyncio.run` returns,
and on this platform the loop it built is the windows one:

#listing("python/samples/src/Ch21/loop.py", first: 59, last: 68, caption: [after `run` returns the loop is closed, and on windows it was a `ProactorEventLoop`])

That is the platform fact of the chapter. The platforms page states it flatly,
"Changed in version 3.8: On Windows, `ProactorEventLoop` is now the default
event loop", and the sample asserts the class at runtime rather than trusting
the default to persist. The runner page also carries the future of the old
configuration route: "The asyncio policy system is deprecated and will be
removed in Python 3.16; from there on, an explicit *loop_factory* is needed
to configure the event loop". The fourth section's selector leg already uses
`loop_factory` the modern way.

The last two facts of the section are ordering facts. Plain awaits, one after
another with no tasks anywhere, stay strictly sequential, start and end
nested per coroutine, because a coroutine that never yields to the scheduler
cannot be interleaved with:

#listing("python/samples/src/Ch21/loop.py", first: 84, last: 91, caption: [sequential awaits without tasks stay sequential, the log is fully nested])

And the nesting check closes the loop on `run` itself: calling `asyncio.run`
from inside a running loop is the `RuntimeError` the runner page promises,
here caught with the inner coroutine explicitly closed so no warning escapes.

#callout("note", "one loop per run, and 3.14 hands you more eyes", [
  `asyncio.run` builds, drives, and closes one loop per call, and the samples
  call it exactly once per program except `offload.py`, whose selector leg
  needs a second, different loop, which is the "ideally" in the docs'
  "ideally only be called once". Python 3.14 also adds loop introspection to
  the module, `capture_call_graph` and `print_call_graph`, and a `python -m
  asyncio ps PID` CLI that dumps a running program's task table with awaiter
  chains. This book verifies the primitives the CLI is built from, tasks,
  cancellation, and timeouts, and leaves the introspection tools as the
  stated boundary.
])

#diagram([the lifecycle of one `asyncio.run` as a state machine: no loop, loop created and driven, closed on return, the proactor default on windows], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.9, 4.6, 1.5, [no loop: a call #linebreak() returns a coroutine #linebreak() object, nothing ran])
  box(5.9, 6.9, 5.2, 1.5, [`asyncio.run`: create #linebreak() the loop, schedule #linebreak() the first task])
  box(11.8, 6.9, 4.0, 1.5, [running: await #linebreak() suspends, values #linebreak() cross back])
  box(16.5, 6.9, 5.2, 1.5, [teardown: finalize #linebreak() async generators, #linebreak() close executor, loop], fill: luma(215))
  cdraw.line((5.2, 7.65), (5.9, 7.65), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.1, 7.65), (11.8, 7.65), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.8, 7.65), (16.5, 7.65), stroke: luma(100), mark: (end: ">"))
  box(0.6, 3.9, 6.4, 2.2, [`get_running_loop` #linebreak() outside a loop: #linebreak() RuntimeError])
  box(7.6, 3.9, 5.2, 2.2, [nested `asyncio.run`: #linebreak() RuntimeError, #linebreak() same thread])
  box(14.2, 3.9, 5.4, 2.2, [after return: #linebreak() `loop.is_closed()` #linebreak() is True])
  cdraw.line((2.9, 6.9), (2.9, 6.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((13.8, 6.9), (10.2, 6.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((19.1, 6.9), (16.9, 6.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  box(0.6, 1.6, 9.6, 1.9, [the loop windows builds by default: #linebreak() `ProactorEventLoop` since 3.8, asserted at runtime], fill: luma(215))
  box(11.4, 1.6, 10.2, 1.9, [policy system deprecated, removal in 3.16, #linebreak() configure with `loop_factory` instead])
  cdraw.content((11.0, 0.5), [one thread throughout: concurrency comes from suspension, not from more threads], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== tasks and groups

A coroutine that someone awaits is a subroutine. A coroutine wrapped in a
`Task` is a unit the loop owes turns to. `create_task` "Wrap[s] the *coro*
into a Task and schedule[s] its execution", raises `RuntimeError` if no loop
is running, and the scheduling half of that sentence is checkable: between
the `create_task` call and the first `await`, the body has not run, because
the loop cannot take a turn while the current coroutine keeps the thread:

#listing("python/samples/src/Ch21/tasks.py", first: 48, last: 57, caption: [a fresh task has not started, and awaiting it returns the result])

The task page also carries a warning worth internalizing: "Save a reference
to the result of this function, to avoid a task disappearing mid-execution.
The event loop only keeps weak references to tasks." `TaskGroup` keeps
strong references, which is one of the reasons it is the default recommendation.

`gather` runs awaitables concurrently and hands back results in input order
no matter the completion order, the sample's three sleeps finish in the order
b, c, a while the result list still reads a, b, c:

#listing("python/samples/src/Ch21/tasks.py", first: 59, last: 71, caption: [gather results keep input order while the calls log the true completion order])

Failure is where `gather`'s contract gets interesting. The docs: "If
*return_exceptions* is `False` (default), the first raised exception is
immediately propagated to the task that awaits on `gather()`. Other
awaitables in the *aws* sequence won't be cancelled and will continue to
run." The sample proves both halves, the propagation, and the survivor still
delivering its result after the `ValueError` passed through:

#listing("python/samples/src/Ch21/tasks.py", first: 85, last: 96, caption: [gather propagates the first failure and abandons the rest to keep running])

`TaskGroup`, added in 3.11, is the structured answer. The docs' failure rule
is exact: "The first time any of the tasks belonging to the group fails with
an exception other than `asyncio.CancelledError`, the remaining tasks in the
group are cancelled", and the errors "are combined in an `ExceptionGroup`
or `BaseExceptionGroup` (as appropriate) which is then raised". The sample
runs both legs, two healthy children collected at context exit, then one
failing child beside a slower healthy one:

#listing("python/samples/src/Ch21/tasks.py", first: 98, last: 122, caption: [taskgroup, both legs: children awaited at exit, failure cancels the sibling and raises one error group])

The task page states the comparison outright: "`TaskGroup` provides
stronger safety guarantees than `gather` for scheduling a nesting of
subtasks: if a task (or a subtask, a task scheduled by a task) raises an
exception, `TaskGroup` will, while `gather` will not, cancel the remaining
scheduled tasks." `except*` from #xref-to("python", "exceptions") selects
the group's payload, here exactly one `ValueError`.

Cancellation is a delivered exception, not a kill. "`CancelledError` will be
raised in the task at the next opportunity", `cancel()` returns `True` on a
pending task and `False` on a finished one, and the coroutine "has a chance
to clean up or even deny the request by suppressing the exception", at the
price of calling `Task.uncancel()` "in addition to catching the exception".
The victim leg checks the whole discipline, the raise inside, the cleanup
that runs first, the cancelled state, and the `False` on re-cancel:

#listing("python/samples/src/Ch21/tasks.py", first: 124, last: 141, caption: [cancel delivers `CancelledError` at the next await, cleanup runs, re cancelling a done task is False])

The denial path exists and the sample walks it once, deliberately, because
the counting it exposes is what `TaskGroup` and `asyncio.timeout` are built
on. `cancelling()` reports "the number of calls to `cancel()` less the
number of `uncancel()` calls":

#listing("python/samples/src/Ch21/tasks.py", first: 23, last: 31, caption: [the denier: catches the cancellation, records the count, uncancels, returns normally])

#listing("python/samples/src/Ch21/tasks.py", first: 143, last: 154, caption: [the denier survives, and the count drains from 1 to exactly 0])

Timeouts are cancellation wearing a clock. `asyncio.timeout`, added in 3.11,
"will cancel the current task and handle the resulting
`asyncio.CancelledError` internally, transforming it into a `TimeoutError`",
with the subtlety the docs flag in italics worth repeating plainly: "the
`TimeoutError` can only be caught _outside_ of the context manager".
`wait_for` is the one-shot form, raising the same `TimeoutError` since 3.11:

#listing("python/samples/src/Ch21/tasks.py", first: 156, last: 179, caption: [timeout as a context manager and wait_for as a call, both floors measured on loop time])

#callout("pitfall", "fire and forget is a weak reference gamble", [
  The tempting pattern, `asyncio.create_task(coro())` with the result
  discarded, is exactly what the task page's warning is about: the loop holds
  only a weak reference, so the task can be collected mid-execution and the
  exception it raised goes with it. Hold the task, or enter a `TaskGroup`,
  or add the done callback to a background set as the docs show. The samples
  keep every task in a variable and await or cancel each one, which is also
  why their failure accounting is exact.
])

#diagram([tasks through the machine: scheduling, gather's abandoned siblings, taskgroup's cancelled ones, and the two clocks that end a task], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.4, 4.4, 1.5, [coroutine, #linebreak() created, not running])
  box(5.8, 7.4, 4.6, 1.5, [`create_task`, #linebreak() scheduled, still #linebreak() not started])
  box(11.2, 7.4, 4.6, 1.5, [next loop pass: #linebreak() body runs, #linebreak() awaits suspend])
  box(16.8, 7.4, 5.0, 1.5, [await collects: #linebreak() result, exception, #linebreak() or cancellation])
  cdraw.line((5.0, 8.15), (5.8, 8.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.4, 8.15), (11.2, 8.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.8, 8.15), (16.8, 8.15), stroke: luma(100), mark: (end: ">"))
  box(0.6, 5.0, 10.4, 1.5, [gather: first failure propagates, #linebreak() the other awaitables keep running], fill: luma(245))
  box(11.2, 5.0, 10.6, 1.5, [taskgroup: first failure cancels the rest, #linebreak() errors combined into one group], fill: luma(215))
  cdraw.line((5.8, 7.4), (5.8, 6.5), stroke: luma(140), dash: "dashed")
  cdraw.line((13.5, 7.4), (13.5, 6.5), stroke: luma(140), dash: "dashed")
  box(0.6, 2.6, 10.4, 1.5, [`cancel`: `CancelledError` at the next await, #linebreak() cleanup then re raise, uncancel to deny])
  box(11.2, 2.6, 10.6, 1.5, [`timeout` and `wait_for`: cancel at the deadline, #linebreak() resurface as `TimeoutError`])
  cdraw.line((5.8, 5.0), (5.8, 4.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((13.5, 5.0), (13.5, 4.1), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((10.5, 1.2), [structured concurrency is cancellation underneath: #linebreak() group and timeout are users, not peers, of `cancel`], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.line((18.0, 2.6), (18.0, 2.05), stroke: luma(140), dash: "dashed", mark: (end: "x"))
})

== queues and producers

The queue page opens with the two facts that drive everything else:
`asyncio.Queue` "is a first in, first out (FIFO) queue", and "This class is
not thread safe", it is the coroutine sibling of the `queue.Queue` that
#xref-to("python", "threads") used, with the same join and task_done
protocol and none of the locks. `maxsize` is the whole backpressure story in
one parameter: "If *maxsize* is less than or equal to zero, the queue size
is infinite. If it is an integer greater than `0`, then `await put()` blocks
when the queue reaches *maxsize* until an item is removed by `get()`", and
with the default `maxsize=0`, "`full()` never returns `True`". The
backpressure leg pins all of it, a producer parked on its third `put` with
exactly 2 items buffered, then drained to completion:

#listing("python/samples/src/Ch21/queues.py", first: 7, last: 11, caption: [the producer: one `put` per item, completion logged after the last])

#listing("python/samples/src/Ch21/queues.py", first: 77, last: 91, caption: [backpressure, asserted: the third put suspends, six gets release the producer])

The consumer side is the fan-out unit of the capstone pipeline, a `while
True` loop over `await q.get()` ending in `q.task_done()`. The docs define
the handshake precisely: "The count of unfinished tasks goes up whenever an
item is added to the queue. The count goes down whenever a consumer
coroutine calls `task_done()`", and "`join()`" blocks "until all items in
the queue have been received and processed". Overcall it and the queue
answers, "`task_done()` raises `ValueError` if called more times than there
were items placed on the queue":

#listing("python/samples/src/Ch21/queues.py", first: 14, last: 20, caption: [the worker: get, process, task_done, forever])

#listing("python/samples/src/Ch21/queues.py", first: 93, last: 112, caption: [three workers drain six items, join returns, then the idle workers are cancelled])

That closing sequence is the graceful shutdown pattern: `join` first, so
every accepted item is finished, `cancel` after, so no worker dies holding
one. The queue page also sets the timeout boundary, "methods of asyncio
queues don't have a *timeout* parameter; use `asyncio.wait_for()` function
to do queue operations with a timeout", which is the same `wait_for` the
last section already proved.

Lazy production is the async generator, `yield` inside `async def`, consumed
by `async for` one item per suspension. Fed into a queue it becomes a
pipeline stage whose order survives, and whose pull timing is the consumer's,
not the producer's:

#listing("python/samples/src/Ch21/queues.py", first: 23, last: 26, caption: [an async generator yields one value per suspension])

#listing("python/samples/src/Ch21/queues.py", first: 114, last: 121, caption: [`async for` consumes the generator lazily, order preserved])

When the bound must be on concurrency rather than inventory, `Semaphore` is
the primitive. The sample tracks the high water mark of a 2 permit semaphore
over 6 jobs and gets exactly 2, never 3, with all 6 results collected:

#listing("python/samples/src/Ch21/queues.py", first: 133, last: 150, caption: [the overcalled `task_done` raises, and a 2 permit semaphore caps observed concurrency at exactly 2])

#diagram([the queue as a data structure: bounded inventory between producer and workers, the unfinished counter gating join, the semaphore gating concurrency], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.6, 4.4, 1.7, [producer, #linebreak() `put` suspends #linebreak() at maxsize])
  box(5.8, 6.6, 5.0, 1.7, [queue, maxsize 2: #linebreak() 2 buffered, third put parked], fill: luma(215))
  box(11.6, 6.6, 5.2, 1.7, [workers x3: #linebreak() get, process, #linebreak() `task_done`])
  box(17.6, 6.6, 4.0, 1.7, [join gate: #linebreak() counter at 0], fill: luma(215))
  cdraw.line((5.0, 7.45), (5.8, 7.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 7.45), (11.6, 7.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 7.45), (17.6, 7.45), stroke: luma(100), mark: (end: ">"))
  box(0.6, 3.6, 9.8, 1.7, [shutdown order: `join` first, #linebreak() every accepted item finished, #linebreak() then cancel the idle workers])
  box(11.0, 3.6, 10.6, 1.7, [overcall `task_done`: #linebreak() ValueError, the counter never goes negative])
  cdraw.line((8.0, 6.6), (5.5, 5.3), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.line((14.0, 6.6), (14.0, 5.3), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  box(0.6, 1.2, 9.8, 1.7, [async generator: `yield` per suspension, #linebreak() pipeline order survives the queue])
  box(11.0, 1.2, 10.6, 1.7, [semaphore, 2 permits: #linebreak() concurrency capped, inventory unbounded], fill: luma(245))
  cdraw.content((11.0, 0.4), [backpressure lives in `maxsize`, concurrency control lives in the semaphore, shutdown lives in the join order], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== streams, subprocess, and threads

The loop is only worth having while everything on it awaits. The sample
measures both sides of that sentence with a heartbeat task that ticks every
0.05 s of loop time. The same 0.3 s blocking sleep runs twice, once through
`asyncio.to_thread`, where the heartbeat keeps counting, and once called
inline, where the count is exactly zero for the whole block:

#listing("python/samples/src/Ch21/offload.py", first: 27, last: 44, caption: [the heartbeat keeps ticking through `to_thread`, the blocking sleep runs on a pool thread])

#listing("python/samples/src/Ch21/offload.py", first: 46, last: 52, caption: [the identical sleep called inline starves the loop, zero heartbeats in 0.3 s])

That zero is the detection method: a blocked loop is not an error, it is a
silence, and any periodic task will measure it. `to_thread` itself is
transparent about arguments, return value, and thread identity:

#listing("python/samples/src/Ch21/offload.py", first: 54, last: 63, caption: [to_thread passes arguments through, returns the value, and runs on a worker thread])

The streams api is the loop's io surface. The streams page: "Streams are
high-level async/await-ready primitives to work with network connections.
Streams allow sending and receiving data without using callbacks or
low-level protocols and transports", and `open_connection` will "return a
pair of `(reader, writer)` objects". This chapter never opens a socket, a
loopback listener on windows is an interactive firewall event, not a
deterministic check, so the reader half arrives the other documented way:
the subprocess page states that "If *PIPE* is passed to *stdout* or *stderr*
arguments, the `Process.stdout` and `Process.stderr` attributes will point
to `StreamReader` instances". The child is a fresh `sys.executable` run with
`-c`, under the same spawn realities #xref-to("python", "multiprocessing")
documented for process workers, and its pipe is exercised with the reader's
real methods, `readline` for each line, `read` to drain, `at_eof` to confirm
the end:

#listing("python/samples/src/Ch21/offload.py", first: 65, last: 76, caption: [a subprocess on the default loop, its stdout asserted to be a real `StreamReader`])

#listing("python/samples/src/Ch21/offload.py", first: 78, last: 95, caption: [readline delivers each line, crlf included, read drains to eof, wait reports the exit code])

Subprocess support is the second windows fact of the chapter, and the
subprocess page states it without hedging: "On Windows subprocesses are
provided by `ProactorEventLoop` only (default), `SelectorEventLoop` has no
subprocess support." The platforms page itemizes what else the selector loop
gives up on windows, `SelectSelector` "supports sockets and is limited to
512 sockets", `add_reader` and `add_writer` "only accept socket handles",
and "Subprocesses are not supported, i.e. the `loop.subprocess_exec()` and
`loop.subprocess_shell()` methods are not implemented". The mirror leg runs
the identical `create_subprocess_exec` call on a selector loop built with
`loop_factory`, the 3.16-proof configuration route, and it is a
`NotImplementedError`, machine-checked:

#listing("python/samples/src/Ch21/offload.py", first: 102, last: 122, caption: [the same subprocess call on a selector loop: `NotImplementedError`, exactly as documented])

#callout("warning", "why the book defaults to the proactor and never says its name in anger", [
  On windows the proactor loop has no `add_reader` or `add_writer`, which
  strands libraries built on those callbacks, the documented reason people
  historically switched to the selector policy and then lost subprocesses,
  pipes beyond overlapped handles, and the 512 socket ceiling became their
  world instead. The default buys subprocess support and unbounded socket
  counts. The samples assert the default class at runtime, and the selector
  leg proves the tradeoff exists by tripping it, so neither fact is folklore.
])

#diagram([the three ways off the loop as a layer stack: pool threads for blocking calls, child processes for real work, streams as the shared io surface, the selector alternative gated], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 7.6, 21.0, 1.5, [your coroutines: producers, workers, timeouts, all awaiting], fill: luma(215))
  box(0.6, 5.4, 10.2, 1.5, [event loop, proactor default on windows: #linebreak() subprocesses, unbounded sockets])
  box(11.6, 5.4, 10.0, 1.5, [`asyncio.to_thread`: #linebreak() pool threads, loop keeps ticking])
  cdraw.line((5.6, 7.6), (5.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.6, 7.6), (16.6, 6.9), stroke: luma(100), mark: (end: ">"))
  box(0.6, 3.2, 10.2, 1.5, [`create_subprocess_exec`: #linebreak() child processes, spawn rules from ch 16])
  cdraw.rect((11.6, 3.2), (18.2, 4.7), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((14.9, 3.95), [inline blocking call: #linebreak() zero heartbeats, silence], wrap: text.with(size: 6pt))
  cdraw.line((5.6, 5.4), (5.6, 4.7), stroke: luma(100), mark: (end: ">"))
  box(0.6, 1.0, 13.4, 1.5, [streams: `StreamReader` over subprocess pipes, #linebreak() over `open_connection` sockets in the capstone])
  cdraw.line((5.6, 3.2), (5.6, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.0, 3.2), (12.0, 2.5), stroke: luma(100), mark: (end: ">"))
  box(15.4, 1.0, 6.4, 1.5, [selector loop: subprocess #linebreak() is NotImplementedError], fill: luma(245))
  cdraw.line((19.5, 5.4), (19.5, 2.7), stroke: luma(140), dash: "dashed", mark: (end: "x"))
  cdraw.content((10.5, 0.3), [one reader api over two transports: pipe or socket], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "54 checks, every one deterministic on this box", [
  `loop.py` pins the interpreter at 3.14.7 and contributes 12 checks, the
  coroutine that does not run, the runner contract, the closed loop, the
  proactor class, suspension timing, sequential order, and the nested run.
  `tasks.py` adds 19, scheduling, gather order and failure abandonment,
  taskgroup's exception group and sibling cancellation, the full cancel
  discipline with `uncancel` counts, and both timeout forms. `queues.py`
  adds 12, fifo order, maxsize backpressure, join and task_done accounting,
  the graceful shutdown order, the async generator pipeline, and the
  semaphore high water mark. `offload.py` adds 11, the heartbeat contrast,
  thread identity, the subprocess stream reader, and the selector loop's
  refusal. The timing checks use 5 to 20 fold margins between the measured
  and the competing values, so scheduling jitter cannot flip them.
])

sources: docs.python.org/3/library/asyncio-runner.html (asyncio.run's
contract, the policy deprecation note), asyncio-task.html (calling a
coroutine does not schedule it, create_task and the weak reference warning,
gather semantics, TaskGroup failure and safety guarantees, cancel, uncancel,
cancelling, timeout, wait_for), asyncio-queue.html (fifo, thread safety,
maxsize, put, get, join and task_done, the wait_for note),
asyncio-platforms.html (the proactor default since 3.8, the selector loop's
512 socket limit and missing add_reader, add_writer, and subprocess
methods), asyncio-subprocess.html (proactor only on windows, PIPE producing
StreamReader instances), asyncio-streams.html (the streams intro,
open_connection's reader and writer pair, readline, read, at_eof), and
docs.python.org/3/whatsnew/3.14.html (create_task kwargs pass-through,
capture_call_graph and print_call_graph), all accessed 2026-09-12. Sample
behavior verified by `make verify-py`, 54 checks in chapter 21.
