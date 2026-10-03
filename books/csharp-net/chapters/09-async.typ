#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= async

The async model in C\# is cooperative single thread handoff. An `await`
marks a point where the method may suspend: it registers the rest of
the method as a continuation, returns control to the caller
immediately, and resumes on completion, by default back on the same
synchronization context or thread pool work item. A synchronization
context is a queue-and-post abstraction binding continuations to an
environment, the UI thread being the classic one, and console apps
have none, so their continuations ride the thread pool. The compiler
builds this from your code as a state machine, so async methods read
sequentially and run concurrently where it matters.

== async, await, Task

`async` on a method enables `await` inside it. The return type
describes the future: `Task` for no value, `Task<T>` for one,
`ValueTask<T>` as an allocation avoiding refinement, and
`IAsyncEnumerable<T>` for a stream of values over time:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 26, last: 30, caption: [the smallest useful async method])

#flow(
  [await as suspension, one method lowered to a state machine],
  node((0, 0), [caller]),
  node((2.4, 0), [async method]),
  node((4.8, 0), [await: the rest #linebreak() becomes a continuation]),
  node((7.4, 0), [resumes #linebreak() on completion]),
  node((4.8, 1.7), [caller keeps running]),
  edge((0, 0), (2.4, 0), "-|>", label: [calls]),
  edge((2.4, 0), (4.8, 0), "-|>"),
  edge((4.8, 0), (7.4, 0), "-|>"),
  edge((4.8, 0), (4.8, 1.7), "-|>", label: [control returns]),
)

Awaiting a `Task<T>` yields the `T`. Awaiting a faulted task rethrows
the original exception at the await site, which means async code needs
no special error plumbing:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 84, last: 88, caption: [the throw site and the await site])

== concurrency with WhenAll

Independent awaits run one at a time if you await them in sequence.
`Task.WhenAll` starts them together and completes when every task
does, returning the results in input order no matter which finished
first. The sample schedules the digits so the last one completes
first, then asserts the order anyway:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 32, last: 48, caption: [three tasks, reverse completion order, input order results])

#flow(
  [WhenAll fans in, one await point, results in input order],
  node((0, 1.4), [task one]),
  node((0, 0), [task two]),
  node((0, -1.4), [task three]),
  node((2.6, 0), [await WhenAll]),
  node((4.8, 0), [results: 1, 2, 3]),
  edge((0, 1.4), (2.6, 0), "-|>"),
  edge((0, 0), (2.6, 0), "-|>"),
  edge((0, -1.4), (2.6, 0), "-|>"),
  edge((2.6, 0), (4.8, 0), "-|>", label: [completion order irrelevant]),
)

`Task.WhenAny` is the sibling for races: it completes when the first
task does and is the base for timeout patterns. One caution that
follows from WhenAll's error model: when several tasks fail, await
throws only the first exception. `task.Exception.InnerExceptions`
holds the rest.

== ValueTask

Every `Task<T>` you return that is not already running is a heap
allocation. When a method often completes synchronously, a cache hit,
a validation failure, `ValueTask<T>` lets the synchronous path return
a value with no allocation and only pay for a Task on the slow path:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 5, last: 21, caption: [a read through cache: hits return a value, misses return a task])

#diagram([valuetask, one allocation free fast path and one slow path], length: 13pt, {
  // the method at left, its two return shapes at right
  cdraw.rect((0.4, 3.8), (7.8, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.1, 4.7), [`ReadThrough(key)` #linebreak() returns `ValueTask<T>`], size: 6pt)
  cdraw.line((7.8, 4.9), (8.8, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.8, 4.5), (8.8, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.0, 4.8), (16.2, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.6, 5.6), [cache hit: the value itself, #linebreak() zero allocations], size: 6pt)
  cdraw.rect((9.0, 2.4), (16.2, 4.0), fill: luma(230), radius: 0.02)
  cdraw.content((12.6, 3.2), [cache miss: exactly one #linebreak() `Task` allocation], size: 6pt)
  cdraw.content((12.0, 0.6), [single shot: await once, never store, never concurrent, #linebreak() `.AsTask()` when a caller must store the future], size: 6.5pt)
})

#callout("warning", "ValueTask is single shot", [
  Unlike Task, a ValueTask may only be awaited once, never stored and
  never concurrently awaited, because the fast path result lives on the
  stack. If a caller needs to await twice or store the future, convert
  with `.AsTask()`. The book's rule: default to Task, switch to
  ValueTask where a profile shows allocation pressure on a hot
  synchronous path.
])

== cancellation

Cooperative cancellation is a `CancellationToken` threaded through the
call chain. Code that respects it checks `ThrowIfCancellationRequested`
at loop boundaries and passes the token into every awaitable call,
including `Task.Delay`. Calling `ThrowIfCancellationRequested` raises
`OperationCanceledException`, which callers are expected to treat as
control flow, not error:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 50, last: 60, caption: [a loop that checks before and inside its delay])

#diagram([cancellation, one token threaded to every await], length: 13pt, {
  // source, token, checks, and the exception as control flow
  cdraw.rect((0.2, 4.1), (8.2, 5.7), fill: luma(230), radius: 0.02)
  cdraw.content((4.2, 4.9), [`CancellationTokenSource`, #linebreak() anyone can trigger it], size: 6pt)
  cdraw.line((8.2, 4.9), (9.0, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.0, 4.1), (15.0, 5.7), fill: luma(230), radius: 0.02)
  cdraw.content((12.0, 4.9), [a `token` threaded #linebreak() through the chain], size: 6pt)
  cdraw.line((15.0, 4.9), (15.8, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.8, 4.1), (23.8, 5.7), fill: luma(235), radius: 0.02)
  cdraw.content((19.8, 4.9), [checks at boundaries #linebreak() and inside every delay], size: 6pt)
  cdraw.line((19.3, 4.1), (19.3, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.8, 1.4), (23.8, 3.0), fill: luma(205), radius: 0.02)
  cdraw.content((19.3, 2.2), [`OperationCanceledException`, #linebreak() control flow, not an error], size: 6pt)
})

The token itself comes from a `CancellationTokenSource`, which a
timeout, another task, or caller code can trigger. Cancellation is
also the one exception type async code should let propagate, the
filter in chapter 8's snippet exists for exactly that.

== async streams

An async method can also be a producer. `yield return` inside an
`async IAsyncEnumerable<T>` method makes an iterator whose
advancement is asynchronous, consumed with `await foreach`:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 62, last: 70, caption: [an async iterator producing three ticks])

The `[EnumeratorCancellation]` attribute marks which parameter the
consumer's token should flow into when the caller uses
`WithCancellation`, the composition that makes iterators cancellable
without a second overload:

#listing("csharp-net/samples/src/Ch09/AsyncWork.cs", first: 72, last: 82, caption: [WithCancellation feeding the iterator's token])

#flow(
  [async streams, one value per movenextasync, pulled by the consumer],
  node((0, 0), [consumer, #linebreak() `await foreach`]),
  node((3.0, 0), [`MoveNextAsync()`]),
  node((5.8, 0), [resumes to the #linebreak() next `yield return`]),
  node((8.4, 0), [value arrives]),
  node((5.8, 1.7), [pull again]),
  edge((0, 0), (3.0, 0), "-|>"),
  edge((3.0, 0), (5.8, 0), "-|>"),
  edge((5.8, 0), (8.4, 0), "-|>"),
  edge((8.4, 0), (5.8, 1.7), "-|>"),
  edge((5.8, 1.7), (3.0, 0), "-|>"),
)

== the rules that keep async honest

Async methods flow one direction. The compounding list:

#callout("warning", "never block on async code", [
  `.Result`, `.Wait()`, and `.GetAwaiter().GetResult()` on a task that
  is not complete can deadlock when a synchronization context exists,
  and they burn a thread either way. Await instead, all the way up.
  `await` cannot appear inside `lock` or a `catch`/`finally` in older
  code shapes, cannot preserve a `ref struct` across suspension
  (chapter 10 owns the stack-only type), and
  `async void` is reserved for event handlers, where exceptions crash
  the process because nothing can await them.
])

#diagram([the banned list, each rule with its cause], length: 13pt, {
  // the shape on the left, why it is banned on the right
  let rows = (
    ([`.Result`, `.Wait()`], [deadlock risk on a context, #linebreak() and a thread burned either way]),
    ([`await` in `lock`], [a lock cannot span a suspension]),
    ([`async void`], [nothing can await it, #linebreak() exceptions crash the process]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.7
    cdraw.rect((0.4, y - 0.8), (6.4, y + 0.8), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y), row.at(0), size: 6pt)
    cdraw.line((6.4, y), (7.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.4, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((10.9, 0.0), [await instead, all the way up], size: 6.5pt)
})

sources: learn.microsoft.com, async programming with async and await,
task asynchronous programming model, async return types, await
operator, cancellation in managed threads, and iasyncenumerable pages,
accessed 2026-09-08. Sample behavior verified by `make verify-csharp`,
8 tests.
