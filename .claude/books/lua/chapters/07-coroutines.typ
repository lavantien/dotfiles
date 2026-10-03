#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= coroutines

A coroutine is a value of type thread, a collaborative execution
context with its own stack. `create` only builds it, `resume` runs
it, `yield` suspends it, and the status field walks `suspended`,
`running`, `suspended`, `dead` across that life. A coroutine that
resumes another is `normal` while the callee runs, and the main
thread reports itself through `coroutine.running`'s second result:

#listing("lua/samples/ch07_coroutines.lua", first: 5, last: 31, caption: [the status walk, dead resume])
#listing("lua/samples/ch07_coroutines.lua", first: 33, last: 55, caption: [normal status of a resumer])

Values flow both ways: extra `resume` arguments enter the body and
then each `yield`, and each `yield`'s arguments come back out of the
matching `resume`:

#listing("lua/samples/ch07_coroutines.lua", first: 22, last: 31, caption: [the resume yield channel])

== errors and the un-unwound stack

An unprotected error terminates the coroutine without unwinding its
stack, on purpose, so the debug library can inspect the corpse. The
consequence for to-be-closed variables is that they wait: nothing
runs at error time, and the single call to `coroutine.close` both
performs the closing and returns false plus the original error.
Error objects cross the boundary by identity, tables included:

#listing("lua/samples/ch07_coroutines.lua", first: 57, last: 80, caption: [deferred cleanup, the close error report, object identity])

#diagram([an error kills the coroutine without unwinding, close settles it later], length: 13pt, {
  // the timeline of an errored coroutine, boxes tall enough for two lines
  cdraw.line((0.8, 6.0), (21.5, 6.0), stroke: luma(100), mark: (end: ">"))
  let event(x, half, txt, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x - half, 4.5), (x + half, 6.5), fill: f, radius: 0.02)
    cdraw.content((x, 5.5), txt, size: 6pt)
  }
  event(3.2, 2.6, [an error hits], false)
  event(9.0, 3.6, [no unwinding, #linebreak() the corpse stays], false)
  event(15.0, 3.4, [guards wait, #linebreak() nothing ran yet], false)
  event(20.2, 1.6, [close], true)
  // what close answers
  cdraw.content((12.4, 3.5), [close runs the guards now and returns false plus the original error], size: 6.5pt)
  cdraw.line((20.2, 4.45), (20.2, 4.0), stroke: luma(180), mark: (end: ">"))
  // the inspectability and identity notes
  cdraw.content((12.4, 2.2), [debug can read the dead stack, the error did not unwind it], size: 6.5pt)
  cdraw.content((12.4, 0.9), [error objects cross the boundary by identity, tables included], size: 6.5pt)
})

== close as cancellation

`coroutine.close` accepts dead, suspended, or the running coroutine,
and its default argument is the running one. On a suspended
coroutine it runs the guards in reverse order and reports true. On
the running coroutine it is a cancel: it does not return, not even
through `pcall`, the pending guards run, the code after the call is
unreachable, and the `resume` that started the body returns plain
`true`:

#listing("lua/samples/ch07_coroutines.lua", first: 96, last: 107, caption: [self close as a non catchable cancel])

#flow(
  [close over each coroutine state],
  node((0, 0), [suspended]),
  node((3.0, 0), [running]),
  node((6.2, 0), [dead]),
  node((6.2, 1.7), [close: ok, true]),
  node((2.6, 2.4), [the cancel does not return, #linebreak() not even through pcall]),
  node((3.0, -3.2), [the resume that started the body #linebreak() returns plain true]),
  edge((0, 0), (6.2, 0), "-|>", bend: 30deg, label: [close: guards run in reverse, true]),
  edge((3.0, 0), (6.2, 0), "-|>", bend: -30deg, label: [close: a cancel]),
  edge((6.2, 0), (6.2, 1.7), "-|>"),
)

`coroutine.wrap` trades `resume`'s error tuple for exceptions: errors
propagate to the caller and the coroutine gets closed on the way,
guards and all:

#listing("lua/samples/ch07_coroutines.lua", first: 109, last: 121, caption: [wrap closing the coroutine while propagating])

== coroutines as iterators

`wrap` returns a plain function, which is exactly what a generic
`for` wants, so a producer loop becomes an iterator with no state
plumbing:

#listing("lua/samples/ch07_coroutines.lua", first: 123, last: 132, caption: [range as a wrapped producer])

#flow(
  [wrap turns a producer into the function the generic for wants],
  node((0, 0), [a producer body, #linebreak() one yield per value]),
  node((3.2, 0), [coroutine.wrap]),
  node((6.4, 0), [a plain function]),
  node((3.2, -1.8), [the generic for consumes it, #linebreak() no iterator state to thread]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((3.2, 0), (6.4, 0), "-|>"),
  edge((6.4, 0), (3.2, -1.8), "-|>", bend: -35deg),
)

== yielding through C

A yield inside nested Lua calls resumes correctly, and 5.4's deeper
guarantee holds in 5.5: yields cross `pcall` bodies and metamethods.
An `__index` metamethod can suspend the table access mid-flight and
the resumed value becomes the indexing result:

#listing("lua/samples/ch07_coroutines.lua", first: 134, last: 146, caption: [yield inside pcall and inside a metamethod])

#diagram([the boundaries a yield crosses, and the one it cannot], length: 13pt, {
  // nested layers, yield at the center, plain c code as the outer wall
  cdraw.rect((0.5, 0.2), (21.5, 11.0), stroke: luma(150), radius: 0.02)
  cdraw.content((11.0, 10.3), [plain c code between caller and callee, the wall], size: 6pt)
  cdraw.rect((1.7, 1.6), (20.3, 9.6), fill: luma(243), radius: 0.02)
  cdraw.content((11.0, 8.9), [nested lua calls], size: 6pt)
  cdraw.rect((2.9, 3.0), (19.1, 8.2), fill: luma(238), radius: 0.02)
  cdraw.content((11.0, 7.5), [an \_\_index metamethod], size: 6pt)
  cdraw.rect((4.1, 4.2), (17.9, 6.8), fill: luma(232), radius: 0.02)
  cdraw.content((11.0, 6.15), [a pcall body], size: 6pt)
  cdraw.rect((5.3, 4.8), (16.7, 5.7), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 5.25), [yield], size: 6.5pt)
  // the arrow out through every lua layer, stopped at the wall
  cdraw.line((16.7, 5.25), (21.5, 5.25), stroke: luma(100), mark: (end: "x"))
  cdraw.content((11.0, 3.6), [isyieldable follows the running coroutine], size: 6.5pt)
  cdraw.content((11.0, 2.3), [the resumed value becomes the indexing result], size: 6.5pt)
})

The state machine of the whole system is small enough to draw:

#flow(
  [coroutine states],
  node((0, 0), [suspended]),
  node((2, 0), [running]),
  node((4, 0), [dead]),
  node((2, 1.1), [normal]),
  edge((0, 0), (2, 0), "-|>", bend: 30deg, label: [resume]),
  edge((2, 0), (0, 0), "-|>", bend: 45deg, label: [yield]),
  edge((2, 0), (4, 0), "-|>", label: [return, error, close]),
  edge((2, 0), (2, 1.1), "-|>", label-side: right, label: [resume another]),
  edge((2, 1.1), (2, 0), "-|>", label-side: right, label: [callee returns]),
)

sources: lua.org manual 5.5 sections 2.6 and 6.3, accessed 2026-09-08.
Close and self close semantics verified live with lua 5.5.1, 12 tests
green through `make verify-lua`.
