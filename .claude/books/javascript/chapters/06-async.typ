#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= async javascript

Async code here is one thread and two queues. Synchronous code runs
to completion, the microtask queue drains after it, and timers and
other macrotasks fire one turn later. Promises are the currency of
that loop: a value that settles once, consumed by `then` chains or
by `await`, with errors propagating through the chain like values.
Everything in this chapter runs on node 26 with no build step.

== the loop, one run through

The ordering is deterministic and the sample pins it. Synchronous
code first, then every microtask in front of the timers, and a zero
millisecond timer fires in a later macrotask than all of them.
`await` suspends to the microtask queue even when the awaited value
is not a promise:

#listing("javascript/samples/src/ch06-async.mjs", first: 3, last: 21, caption: [sync, microtask, await, and timer order, recorded in sequence])

#diagram([one run through the queues, in order], length: 13pt, {
  cdraw.content((11.6, 7.6), [one turn, three phases], size: 6.5pt, fill: luma(100))
  cdraw.content((4.5, 5.4), [sync code first], size: 6.5pt)
  cdraw.content((12.0, 5.4), [the microtask queue drains], size: 6.5pt)
  cdraw.content((19.2, 5.4), [a later macrotask], size: 6.5pt)
  cdraw.line((0.8, 4.6), (22.2, 4.6), stroke: luma(100), mark: (end: ">"))
  for x in (4.5, 12.0, 19.2) { cdraw.line((x, 4.4), (x, 4.8), stroke: luma(100)) }
  cdraw.content((4.5, 3.8), [`sync`], size: 6pt)
  cdraw.content((12.0, 3.95), [`microtask`, #linebreak() then `after-await`], size: 6pt)
  cdraw.content((19.2, 3.95), [`after-timer` queued, #linebreak() then `timer` fires], size: 6pt)
  cdraw.content((11.6, 1.6), [deterministic: `await null` still queues, the timer waits], size: 6.5pt)
})

The recorded order is `sync`, `microtask`, `after-await`,
`after-timer`, `timer`, every run, because microtasks scheduled
during the turn run before the next macrotask begins. Node also
drains a `process.nextTick` queue ahead of promise microtasks, a
third lane this book stays off by scheduling with
`queueMicrotask`.

== promises from scratch

A promise takes an executor that runs immediately with two
settlers, and the contract is settle once: the first `resolve` or
`reject` wins and every later call is ignored. That single fact is
what makes a promise safe to hand to any number of consumers:

#listing("javascript/samples/src/ch06-async.mjs", first: 23, last: 36, caption: [a second resolve and a late reject, both ignored])

#diagram([the settle once machine, the chain riding beneath], length: 13pt, {
  cdraw.content((11.6, 10.4), [the first settle wins, later calls are ignored], size: 6.5pt, fill: luma(100))
  cdraw.rect((7.0, 8.6), (16.2, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 9.2), [the executor runs immediately, #linebreak() two settlers handed in], size: 6pt)
  cdraw.line((11.6, 8.6), (11.6, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 6.6), (14.6, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 7.2), [pending], size: 6pt)
  cdraw.line((8.6, 7.2), (6.4, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.3, 7.5), [`resolve` first], size: 6pt)
  cdraw.line((14.6, 7.2), (16.8, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.9, 7.5), [`reject` first], size: 6pt)
  cdraw.rect((0.8, 4.9), (6.4, 6.1), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((3.6, 5.5), [fulfilled], size: 6pt)
  cdraw.rect((16.8, 4.9), (22.4, 6.1), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((19.6, 5.5), [rejected], size: 6pt)
  cdraw.rect((0.4, 3.5), (22.8, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.0), [settled once: a second `resolve` and a late `reject` both ignored, #linebreak() safe to hand to any number of consumers], size: 6pt)
  cdraw.content((11.6, 2.95), [`then` builds the chain, each callback one microtask, a returned value flows to the next link], size: 6pt)
  cdraw.rect((4.6, 1.5), (8.6, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 1.95), [`then`], size: 6pt)
  cdraw.line((8.6, 1.95), (10.6, 1.95), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.6, 1.5), (14.6, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((12.6, 1.95), [`then`], size: 6pt)
  cdraw.line((14.6, 1.95), (16.6, 1.95), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.6, 1.5), (20.6, 2.4), fill: luma(205), radius: 0.02)
  cdraw.content((18.6, 1.95), [`catch`], size: 6pt)
  cdraw.content((11.6, 0.7), [a rejection skips every fulfillment callback to the nearest `catch`], size: 6.5pt)
})

`then` builds the chain. Each callback runs as a microtask, a
returned value flows to the next link, and a rejection skips every
fulfillment callback until the nearest `catch`, which is why the
test's chain sees only the caught message. A callback or an `async`
function that returns a promise makes the next link wait for that
promise's settlement, then-adoption in the spec, and `await`
unwraps thenables the same way.

== async and await, and Promise.try

An `async` function is syntax over promise construction: every
return resolves the result, every throw rejects it. `await` is
syntax over `then`, with the same microtask suspension. The gap the
syntax left was the sync throw: wrapping callback style code meant a
try block around the call. `Promise.try`, from ES2025, lifts any
function into the chain, a returned value resolves and a
synchronous throw rejects:

#listing("javascript/samples/src/ch06-async.mjs", first: 38, last: 52, caption: [Promise.try on a value and on a synchronous throw])

#diagram([the syntax against the hand built forms it replaces], length: 13pt, {
  cdraw.content((5.5, 8.4), [hand built], size: 6.5pt, fill: luma(100))
  cdraw.content((17.5, 8.4), [the syntax], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.8), (10.6, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.35), [`new Promise` over an executor], size: 6pt)
  cdraw.rect((12.4, 6.8), (22.6, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.35), [`async`: every `return` resolves, #linebreak() every `throw` rejects], size: 6pt)
  cdraw.rect((0.4, 5.4), (10.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.95), [`.then` chains, callbacks queued], size: 6pt)
  cdraw.rect((12.4, 5.4), (22.6, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.95), [`await`: syntax over `then`, #linebreak() the same microtask suspension], size: 6pt)
  cdraw.rect((0.4, 4.0), (10.6, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 4.55), [a sync throw: #linebreak() a `try` block around the call], size: 6pt)
  cdraw.rect((12.4, 4.0), (22.6, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 4.55), [`Promise.try`, es2025: the function lifted, #linebreak() a throw becomes a rejection], size: 6pt)
  cdraw.rect((4.0, 2.2), (19.2, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.8), [`finally` runs on the error path #linebreak() and on completion by return alike], size: 6pt)
  cdraw.content((11.6, 1.2), [error paths compose from there], size: 6.5pt)
})

Error paths compose from there. A throw inside an async function is
a rejection awaiting its catch, an awaited rejection propagates to
the nearest handler, and `finally` runs on the error path and on
completion by return alike:

#listing("javascript/samples/src/ch06-async.mjs", first: 145, last: 169, caption: [rejections propagating, finally on both paths])

== the four combinators

The static combinators differ only in failure policy: `all` rejects
on first rejection, `allSettled` never rejects and reports every
outcome, `race` takes the first settlement of any kind, and `any`
takes the first fulfillment, ignoring rejections unless all fail,
which rejects with an `AggregateError` carrying every reason:

#listing("javascript/samples/src/ch06-async.mjs", first: 54, last: 90, caption: [the four combinators, one policy each, all five outcomes pinned])

#diagram([the four combinators, one failure policy each], length: 13pt, {
  cdraw.content((3.6, 7.1), [combinator], size: 6.5pt, fill: luma(100))
  cdraw.content((11.0, 7.1), [on rejection], size: 6.5pt, fill: luma(100))
  cdraw.content((18.6, 7.1), [resolves with], size: 6.5pt, fill: luma(100))

  let row(y, c, r, w, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.6, y + 0.7), c, size: 6pt)
    cdraw.content((11.0, y + 0.7), r, size: 6pt)
    cdraw.content((18.6, y + 0.7), w, size: 6pt)
  }
  row(5.4, [`Promise.all`], [rejects on the first], [argument order, kept], false)
  row(3.6, [`allSettled`], [never rejects], [every outcome, reported], true)
  row(1.8, [`race`], [first settlement wins], [either kind, once], false)
  row(0.0, [`any`], [ignored, unless all fail], [the first fulfillment], true)

  for x in (7.2, 14.8) { cdraw.line((x, 0.0), (x, 6.8), stroke: luma(220)) }
  cdraw.content((11.6, -1.0), [the policy is the only difference between them], size: 6.5pt)
})

`Promise.all` resolves in argument order whatever the completion
order, which the reversed delays in the sample prove, and the racing
test shows an already resolved promise beating a rejection that
never gets a say.

== async iteration

The iterator protocol of chapter 5 has an async pair:
`Symbol.asyncIterator` returns an iterator whose `next` yields
promises of `{ value, done }`, and `for await..of` consumes it,
suspending between steps. Hand built first, then as syntax:

#listing("javascript/samples/src/ch06-async.mjs", first: 106, last: 124, caption: [a hand built async iterable])

#listing("javascript/samples/src/ch06-async.mjs", first: 126, last: 143, caption: [an async generator awaiting between yields, the same protocol as syntax])

The generator's log interleaves `yield` and `body` lines, which is
the interleaving the test asserts: each `yield` suspends, the loop
body runs, then the generator resumes. `Array.fromAsync`, one of the
ES2026 seven, collects the whole stream into one array, and accepts
an iterable of plain promises too:

#listing("javascript/samples/src/ch06-async.mjs", first: 92, last: 104, caption: [fromAsync over an async generator and over promises])

#diagram([the async pair of the protocol, stacked], length: 13pt, {
  cdraw.content((11.6, 9.0), [the same shape, suspending between steps], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 7.2), (19.6, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 7.8), [`for await..of`, `Array.fromAsync`], size: 6pt)
  cdraw.content((21.0, 7.8), [consume], size: 6pt)
  cdraw.rect((2.0, 5.6), (19.6, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 6.2), [`Symbol.asyncIterator` returns an async iterator], size: 6pt)
  cdraw.content((21.0, 6.2), [protocol], size: 6pt)
  cdraw.rect((2.0, 4.0), (19.6, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 4.6), [`next()` yields promises of `{ value, done }`], size: 6pt)
  cdraw.content((21.0, 4.6), [shape], size: 6pt)
  cdraw.rect((2.0, 2.4), (19.6, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 3.0), [hand built objects, async generators], size: 6pt)
  cdraw.content((21.0, 3.0), [direct], size: 6pt)
  cdraw.content((11.6, 1.5), [each `yield` suspends, the loop body runs, the generator resumes], size: 6.5pt)
  cdraw.content((11.6, 0.6), [`Array.fromAsync` collects the whole stream, plain promises included], size: 6.5pt)
})

== cancellation

A promise cannot be cancelled from outside, and that gap is what
`AbortSignal` fills: the work listens, the caller signals. The
signal carries a reason, an explicit abort produces a `DOMException`
named `AbortError`, and `AbortSignal.timeout` builds a self aborting
signal whose reason is named `TimeoutError`. `AbortSignal.any`
merges sources into one:

#listing("javascript/samples/src/ch06-async.mjs", first: 171, last: 202, caption: [abortable work, an explicit abort, a timeout, and a merged signal])

#flow(
  [cancellation, the signal the work listens to],
  node((0, 0), [a running promise]),
  node((3.4, 0), [no outside cancel exists]),
  node((0, 2.4), [the caller signals]),
  node((3.4, 2.4), [`AbortSignal`]),
  node((6.8, 2.4), [the work hears it, #linebreak() rejects immediately]),
  node((0, 4.8), [node's `fetch`, timers, streams]),
  node((3.4, 4.8), [the same one signal]),
  edge((0, 0), (3.4, 0), "-|>"),
  edge((0, 2.4), (3.4, 2.4), "-|>"),
  edge((3.4, 2.4), (6.8, 2.4), "-|>"),
  edge((0, 4.8), (3.4, 4.8), "-|>"),
)

The test aborts immediately and the half second of work rejects at
once with the given reason. Node threads signals through its fetch,
timers, and streams, so this one object is the cancellation currency
across the runtime.

sources: developer.mozilla.org on promises, microtasks, the event
loop, for await..of, and abort controller, nodejs.org event loop
guide, tc39.es promise.try clause, tc39 array.fromAsync proposal,
accessed 2026-09-13. Behavior verified live with node v26.3.0 on
windows, 86 tests green through `npm run verify` in
`javascript/samples`, 19 of them this chapter's.
