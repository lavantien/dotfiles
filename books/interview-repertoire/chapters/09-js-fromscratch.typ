#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= javascript from scratch

"Write X from scratch" checks whether the candidate has used the
primitive or only the convenience. This chapter implements five of
them, test driven, in `ch09-js`: word count in one loop, an event
emitter, map filter reduce, a promise subset that native
async/await can drive, and a signals core, with the combinator
ladder beside the promise and the diamond, disposal, and the
branch switch closing the signals. 40 tests, no dependencies.

== word count in one loop [TDD]

One pass over the characters, one state machine: a word opens on
the first separator-to-letter transition and closes on the first
letter-to-separator one after it. No split, no regex, no
intermediate array:

#listing("interview-repertoire/samples/ch09-js/src/wordcount.mjs", first: 5, last: 18, caption: [the single-loop counter])

#diagram([a state machine over characters, no split and no regex], length: 13pt, {
  // two states, the transitions are the whole algorithm
  cdraw.rect((0.8, 4.9), (6.3, 6.1), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((3.55, 5.5), [in separator], size: 6pt)
  cdraw.rect((12.5, 4.9), (16.5, 6.1), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((14.5, 5.5), [in a word], size: 6pt)
  cdraw.line((6.3, 5.75), (12.5, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.4, 6.6), [letter: open, count + 1], size: 6pt)
  cdraw.line((12.5, 5.25), (6.3, 5.25), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.4, 4.75), [separator: close], size: 6pt)
  // the stream the machine walks
  let stream = ("o", "n", "e", " ", "t", "w", "o")
  for i in range(stream.len()) {
    let f = if stream.at(i) == " " { luma(205) } else { luma(245) }
    cdraw.rect((5.0 + i * 0.95, 1.9), (5.95 + i * 0.95, 2.8), fill: f, radius: 0.02)
    cdraw.content((5.475 + i * 0.95, 2.35), stream.at(i), size: 6pt)
  }
  cdraw.content((16.0, 2.35), [two words, one pass], size: 6pt)
})

The follow-up answer ships in the same file: `wordsOf` collects
the words with the same single loop, because an interviewer who
asks for a count is two minutes from asking for the words.

== the event emitter [TDD]

The node shape: `on`, `off`, `once`, `emit`, handlers in
registration order, and `once` implemented as a wrapper that
removes itself:

#listing("interview-repertoire/samples/ch09-js/src/emitter.mjs", first: 5, last: 37, caption: [on, off, once as a self-removing wrapper, emit over a copy])

#diagram([registration-ordered list, emit iterates a copy], length: 13pt, {
  // top: the stored list; bottom: the snapshot emit walks while h2 unsubscribes
  cdraw.content((6.4, 6.6), [handlers for the event, in order], size: 6.5pt)
  let hs = ("h1", "h2", "h3")
  for i in range(3) {
    cdraw.rect((2.5 + i * 2.6, 5.2), (5.1 + i * 2.6, 6.1), fill: luma(235), radius: 0.02)
    cdraw.content((3.8 + i * 2.6, 5.65), hs.at(i), size: 6pt)
  }
  cdraw.line((6.4, 5.2), (6.4, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.1, 4.75), [snapshot], size: 6pt)
  for i in range(3) {
    let f = if i == 1 { luma(205) } else { luma(245) }
    cdraw.rect((2.5 + i * 2.6, 3.2), (5.1 + i * 2.6, 4.1), fill: f, stroke: luma(190), radius: 0.02)
    cdraw.content((3.8 + i * 2.6, 3.65), hs.at(i), size: 6pt)
  }
  cdraw.content((6.4, 2.4), [the copy emit walks], size: 6.5pt)
  cdraw.content((16.5, 4.6), [h2 unsubscribes mid-emit,], size: 6pt)
  cdraw.content((16.5, 3.5), [the running loop is safe], size: 6pt)
  cdraw.content((16.5, 2.4), [the stored list already lost it], size: 6pt)
})

The copy in `emit` is the detail that scores: a handler that
unsubscribes mid-emit must not corrupt the loop that is running,
and the test does exactly that. The returned unsubscribe handle is
the modern ergonomics worth offering unprompted.

== map, filter, reduce [TDD]

The spec behaviors beyond the obvious: the index and array
arguments, holes skipped by `i in xs`, and reduce's two
signatures, with an initial value folding from it, without one
adopting the first element and throwing on empty:

#listing("interview-repertoire/samples/ch09-js/src/arraymethods.mjs", first: 5, last: 35, caption: [the three loops with the spec's edge behavior])

#diagram([the spec edges ride the same three loops], length: 13pt, {
  // the pipeline every js developer writes, with the edges the spec adds
  let stage(x, t) = {
    cdraw.rect((x, 4.6), (x + 4.4, 5.7), fill: luma(235), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 2.2, 5.15), [#t], size: 6.5pt)
  }
  stage(0.5, "xs")
  stage(6.2, "map f")
  stage(11.9, "filter p")
  stage(17.6, "reduce g")
  cdraw.line((4.95, 5.15), (6.15, 5.15), mark: (end: ">"))
  cdraw.line((10.65, 5.15), (11.85, 5.15), mark: (end: ">"))
  cdraw.line((16.35, 5.15), (17.55, 5.15), mark: (end: ">"))
  cdraw.content((7.0, 3.7), [map gets i and xs], size: 6pt)
  cdraw.content((13.6, 3.7), [holes skipped], size: 6pt)
  cdraw.content((13.6, 2.6), [i in xs], size: 6pt)
  cdraw.content((19.8, 3.7), [two signatures,], size: 6pt)
  cdraw.content((19.8, 2.6), [empty no-initial throws], size: 6pt)
})

The empty-array-no-initial-value test pins the exact TypeError
message of the native implementation, which is a flex that costs
one line.

== a promise subset [TDD]

The teaching core of the A+ spec: settle once, callbacks always
microtasked, chaining through a returned promise, and the
resolution procedure that waits on thenables instead of storing
them:

#listing("interview-repertoire/samples/ch09-js/src/minipromise.mjs", first: 15, last: 40, caption: [first settle wins, thenables are assimilated, callbacks ride queueMicrotask])

#diagram([settle once, callbacks always microtasked, thenables assimilated], length: 13pt, {
  // top: the settle gate; bottom: where a then callback actually runs
  cdraw.rect((6.0, 5.4), (10.0, 6.5), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((8.0, 5.95), [pending], size: 6.5pt)
  cdraw.rect((1.0, 3.2), (5.0, 4.3), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((3.0, 3.75), [fulfilled], size: 6.5pt)
  cdraw.rect((11.5, 3.2), (15.5, 4.3), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((13.5, 3.75), [rejected], size: 6.5pt)
  cdraw.line((6.4, 5.4), (3.6, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.6, 5.4), (12.9, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.2, 4.9), [first resolve], size: 6pt)
  cdraw.content((14.8, 4.9), [first reject], size: 6pt)
  cdraw.content((7.0, 2.3), [no arrow back: settled is settled], size: 6pt)
  // the then path: queue, then run
  cdraw.rect((12.2, 0.8), (16.4, 1.9), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((14.3, 1.35), [then cb], size: 6.5pt)
  cdraw.rect((17.8, 0.8), (23.6, 1.9), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((20.7, 1.35), [queueMicrotask], size: 6pt)
  cdraw.line((16.4, 1.35), (17.7, 1.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.4, 2.6), [thenables are waited on, not stored], size: 6pt)
})

#listing("interview-repertoire/samples/ch09-js/src/minipromise.mjs", first: 42, last: 72, caption: [the chained promise, pass-through on missing handlers, catch as sugar])

Two red runs taught this file its shape, and both are interview
stories. A thenable stored instead of assimilated made
`MiniPromise.all` resolve with the promise object where its value
belonged. A single-argument `then` swallowed the rejection path of
`all`, and the fail-fast test hung forever, which is what a
swallowed rejection looks like from the outside. The final demo is
the payoff line for the whole exercise: a native `async` function
awaits a chain of MiniPromises, because `await` only requires the
thenable protocol, and the test drives three stages through it.

== the combinator ladder: race, allSettled, any [TDD]

`all` has three siblings, and interviewers ask for the four as a
table. Each is one sentence of semantics plus one accounting rule,
and the workspace runs all four:

#listing("interview-repertoire/samples/ch09-js/src/minipromise.mjs", first: 100, last: 156, caption: [race takes the first settle, allSettled treats rejection as data, any accumulates rejections into an AggregateError])

What each is: `race` settles with the first input to settle,
fulfillment or rejection alike. `allSettled` always fulfills,
with every input's outcome as a status pair at its own index.
`any` is `all` mirrored, the first fulfillment wins, and rejection
is the failure mode only when every input has rejected.

Why they exist: the four cover the two axes an async collection
cares about, first versus all, and success versus failure. `all`
is all plus success. `race` is first plus either. `allSettled` is
all plus either, with rejection demoted to data. `any` is first
plus success.

How, walked for `any` because its accounting is the one people
get wrong: every input is assimilated through
`MiniPromise.resolved` exactly as in `all`, but a fulfillment
resolves the whole thing on arrival, while each rejection only
writes its error into a slot and decrements the count, and only
at zero does the `AggregateError` leave with the errors in input
order. The empty input rejects immediately with an empty errors
list. `race` on an empty input never settles at all, which is the
spec's own answer and the trap worth volunteering, because what
`race` of nothing does has no intuitive guess. Every combinator
also takes any iterable, like the native ones, the input
materialized once with `[...promises]`, because the accounting
needs indexes and a Set's `forEach` hands its value back twice,
never an index.

When: `race` for a timeout raced against the real work,
`allSettled` when a batch must report every outcome, `any` for
redundant replicas where one success is enough.

#diagram([the combinator truth table: which settle wins, and what an empty input does], length: 13pt, {
  // rows: the four combinators, columns: the outcomes that decide the interview answer
  let head(x, t) = cdraw.content((x, 8.6), [#t], size: 6pt)
  let cell(x, y, t) = {
    cdraw.rect((x - 2.2, y - 0.55), (x + 2.2, y + 0.55), fill: luma(245), stroke: luma(120), radius: 0.05)
    cdraw.content((x, y), [#t], size: 6pt)
  }
  let rowLabel(y, t) = cdraw.content((2.0, y), [#t], size: 6pt)
  head(8.2, "first rejection")
  head(13.6, "first fulfillment")
  head(19.0, "empty input")
  rowLabel(7.4, "all")
  cell(8.2, 7.4, [rejects])
  cell(13.6, 7.4, [waits for the rest])
  cell(19.0, 7.4, [resolves []])
  rowLabel(5.9, "race")
  cell(8.2, 5.9, [rejects])
  cell(13.6, 5.9, [resolves])
  cell(19.0, 5.9, [pending forever])
  rowLabel(4.4, "allSettled")
  cell(8.2, 4.4, [recorded, resolves])
  cell(13.6, 4.4, [recorded, resolves])
  cell(19.0, 4.4, [resolves []])
  rowLabel(2.9, "any")
  cell(8.2, 2.9, [waits for the rest])
  cell(13.6, 2.9, [resolves])
  cell(19.0, 2.9, [rejects, empty errors])
  cdraw.content((12.0, 1.4), [any rejects with AggregateError only after every input rejected], size: 6pt)
})

The tests pin the table against node itself: the `allSettled`
statuses and the `any` error lists are compared with the native
`Promise` combinators over the same inputs, so the accounting,
not just the shape, matches the spec.

== a signals core [TDD]

The tc39 signals proposal shape reduced to its moving parts:
state with subscribers, computed with dependency tracking while it
evaluates, effects as the evaluation root:

#listing("interview-repertoire/samples/ch09-js/src/signal.mjs", first: 44, last: 62, caption: [state: track readers, notify on change, skip same-value writes under SameValue])

#listing("interview-repertoire/samples/ch09-js/src/signal.mjs", first: 64, last: 92, caption: [computed: evaluate under the tracking flag, subscribe the reader, invalidate on notify])

#diagram([the subscription edge, through the computed, never around it], length: 13pt, {
  let box(x, y, t, faded: false) = {
    let fill = if faded { luma(252) } else { luma(245) }
    let stroke = if faded { luma(190) } else { luma(120) }
    cdraw.rect((x, y), (x + 3.8, y + 0.9), fill: fill, stroke: stroke, radius: 0.05)
    cdraw.content((x + 1.9, y + 0.45), [#t], size: 6.5pt)
  }
  // left: the first draft, the effect wired straight past the computed
  cdraw.content((5.2, 6.4), [first draft, logged once and stopped], size: 7pt)
  box(3.3, 4.9, "state")
  box(3.3, 2.9, "computed", faded: true)
  box(3.3, 0.9, "effect")
  cdraw.line((3.3, 1.35), (1.7, 1.35), (1.7, 5.35), (3.3, 5.35), mark: (end: ">"))
  cdraw.content((2.5, 0.5), [subscribed direct], size: 6pt)
  cdraw.content((10.6, 3.35), [out of the chain], size: 6pt)
  // right: the fix, the subscription rides the same path as the data
  cdraw.content((17.2, 6.4), [the fix, the chain is the subscription], size: 7pt)
  box(15.3, 4.9, "state")
  box(15.3, 2.9, "computed")
  box(15.3, 0.9, "effect")
  cdraw.line((17.2, 1.85), (17.2, 2.85), mark: (end: ">"))
  cdraw.line((17.2, 3.85), (17.2, 4.85), mark: (end: ">"))
  cdraw.content((19.9, 2.35), [notify], size: 6pt)
  cdraw.content((19.9, 4.35), [notify], size: 6pt)
  cdraw.content((11.2, -0.4), [an effect reading through a computed re-runs when the state behind it changes], size: 6.5pt)
})

The observable the tests pin: an unrelated state change does not
recompute a computed, a same-value write fires nothing under
SameValue comparison, an effect reading through a computed re-runs
when the state behind it changes, and a conditional read re-tracks
on every run so the branch not taken stops notifying. The
subscription edge is the oldest of those stories, and the first
draft of this file got it wrong, effects subscribed to the state
directly and never to the computed between them, so the demo
logged once and stopped. The status of the real proposal, stage 1
with stage 2 blockers as the active work, is pinned in
#xref-to("repertoire", "react-hooks").

== signals edge cases: the diamond, disposal, and the branch switch [TDD]

Three edges finish the signals story, and two of them found real
bugs in this file's own first draft, which is the interview story
worth telling.

The diamond. What: one state feeding two computed branches that a
third computed joins, with one effect on the join. Why it is the
test: a naive push design invalidates branch one, the effect runs
immediately, the join recomputes from one fresh branch and one
stale, and the effect logs a value that never existed. That is the
glitch, and the first draft of this file produced it: with `a` at
1 the join reads 5, one `set` to 5 made the effect log 9 on the
way to 13, because it ran after the first branch landed and before
the second. How the fix works: invalidation only marks nodes
dirty and batches the effect runs, `drain()` fires once at the end
of the whole `set`, so the join recomputes exactly once from both
fresh branches and the effect logs `[5, 13]`. When to say it: the
follow-up about diamond dependencies is answered with this batch,
plus the honest boundary, real frameworks also order recomputation
topologically and dedupe across microtasks, and those semantics
are part of the stage 2 blockers the pinned proposal row names.

Disposal. What: an effect's `dispose()` removes it from every node
it subscribed to and kills any run still waiting in the batch. Why:
an effect that outlives its page or component leaks, because every
set keeps notifying it. How: the effect records its read edges on
every run, disposal walks them back, and a disposed flag checked
at drain time kills the pended run, because the wave is a snapshot
an editor cannot reach. When: unmount, cleanup, any effect with a
lifetime shorter than the graph.

The branch switch. What: a conditional read swaps the subscription
edges to the branch actually taken, on every run. Why: an
implementation that builds its edges once, on the first run, goes
wrong in both directions, it stops hearing the state it has
started reading and keeps hearing from the one it has left, a
missed update and a stale notification out of one bug. How: every
evaluation, effect or computed, re-collects its reads, and a
dependency left behind loses its subscriber. When: any read behind
a conditional, a flag choosing between two sources, a derived
value whose formula changes with a mode.

#listing("interview-repertoire/samples/ch09-js/src/signal.mjs", first: 9, last: 42, caption: [the batch and the evaluation wrapper: one wave per set, every run re-collects its reads])

#listing("interview-repertoire/samples/ch09-js/src/signal.mjs", first: 94, last: 112, caption: [the effect: notify batches and dedupes, dispose flags and walks the read edges back])

#listing("interview-repertoire/samples/ch09-js/src/signal.mjs", first: 130, last: 146, caption: [the diamond demo, its counters the tests pin])

#diagram([one set, one join recompute: the eager draft logged a value that never existed], length: 13pt, {
  // left: the diamond shape; right: the eager timeline against the batched one
  let box(x, y, t) = {
    cdraw.rect((x - 1.9, y - 0.45), (x + 1.9, y + 0.45), fill: luma(245), stroke: luma(120), radius: 0.05)
    cdraw.content((x, y), [#t], size: 6pt)
  }
  box(2.6, 7.6, "state a")
  box(2.6, 6.0, "computed b")
  box(2.6, 4.4, "computed c")
  box(2.6, 2.8, "computed d, the join")
  box(2.6, 1.2, "effect")
  cdraw.line((2.6, 7.15), (2.6, 6.45), mark: (end: ">"))
  cdraw.line((2.6, 5.55), (2.6, 4.85), mark: (end: ">"))
  cdraw.line((2.6, 3.95), (2.6, 3.25), mark: (end: ">"))
  cdraw.line((2.6, 2.35), (2.6, 1.65), mark: (end: ">"))
  cdraw.content((12.6, 8.4), [the eager draft], size: 6.5pt)
  cdraw.content((12.6, 7.4), [b lands, effect runs, d reads 6 + 3], size: 6pt)
  cdraw.content((12.6, 6.6), [logs 9, a value that never existed], size: 6pt)
  cdraw.content((12.6, 5.7), [c lands, effect runs again, d reads 13], size: 6pt)
  cdraw.content((20.2, 8.4), [the batch], size: 6.5pt)
  cdraw.content((20.2, 7.4), [b and c land, the wave ends], size: 6pt)
  cdraw.content((20.2, 6.6), [drain runs the effect once], size: 6pt)
  cdraw.content((20.2, 5.7), [d recomputes once, logs 13], size: 6pt)
  cdraw.content((16.4, 3.9), [the join recomputed twice and lied once,], size: 6pt)
  cdraw.content((16.4, 3.1), [against once and honestly], size: 6pt)
  cdraw.content((16.4, 2.0), [disposal is the same story for lifetimes:], size: 6pt)
  cdraw.content((16.4, 1.2), [the read edges walk back, the effect goes silent], size: 6pt)
})

The step by step for a signals question, said aloud: name the
three roles, state, computed, effect, name the two edges,
dependency tracking on the way down and invalidation on the way
up, then the diamond answer, one batch per set so nothing
observes a half updated graph, then disposal when the listener
has a lifetime, and the branch switch, reads re-collect on every
run so a conditional cannot leak a stale edge.

sources: verified by `npm run verify` under node 26.3.0, 40 tests
in `ch09-js`. Proposal shape read from the tc39 signals repository,
access date in the sources appendix.
