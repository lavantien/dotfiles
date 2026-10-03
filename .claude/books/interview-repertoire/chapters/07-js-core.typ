#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= javascript core: scope, closures, event loop

The js core questions are conceptual with executable answers. This
chapter's workspace, `ch07-js`, is plain javascript under
`node --test`, no build step, no framework, 22 tests, and every
demo returns its evidence instead of printing it so the suite can
pin it.

== hoisting and the temporal dead zone [EWC]

Hoisting is a compile-time fact: declarations move to the top of
their scope, but what moves depends on the keyword. `var` hoists
the binding with value undefined, function declarations hoist
whole, and `let` with `const` hoist the binding into a dead zone
where reading throws:

#listing("interview-repertoire/samples/ch07-js/src/scope.mjs", first: 5, last: 43, caption: [var reads undefined above its line, let throws, functions call from above])

#diagram([what moves at compile time, per keyword], length: 13pt, {
  // one column per keyword, the row above the declaration line is the story
  let col(x, head, above, below, dead: false) = {
    cdraw.content((x + 3.1, 6.7), head, size: 6.5pt)
    if dead {
      cdraw.rect((x, 4.9), (x + 6.2, 5.9), fill: luma(205), radius: 0.02)
    } else {
      cdraw.rect((x, 4.9), (x + 6.2, 5.9), fill: luma(235), radius: 0.02)
    }
    cdraw.content((x + 3.1, 5.4), above, size: 6pt)
    cdraw.rect((x, 2.9), (x + 6.2, 3.9), fill: luma(245), radius: 0.02)
    cdraw.content((x + 3.1, 3.4), below, size: 6pt)
  }
  // the declaration line, broken to hold its own label
  cdraw.line((0.5, 4.45), (8.6, 4.45), stroke: luma(100))
  cdraw.line((15.4, 4.45), (23.5, 4.45), stroke: luma(100))
  cdraw.content((12.0, 4.45), [the declaration line], size: 6pt)
  col(0.5, "var", [reads as undefined], [binding, then value])
  col(8.4, "function", [callable from above], [whole body hoists])
  col(16.3, "let, const", [reads throw: dead zone], [usable at its line], dead: true)
  cdraw.content((12.0, 1.9), [everything moves at compile time, what moves differs], size: 6.5pt)
})

The block scope demo is the one that still surprises: two sibling
loops, one `var`, one `let`, and after both run the `var` binding
leaked to the function while the `let` binding is gone. The
`constBinding` demo separates binding from value, the array
mutates, the reassignment throws.

== closures [EWC]

A closure is a function plus the environment it captured. The
counter factory gives each returned function its own `n`, and the
loop-capture demo is the classic gotcha now inverted by spec:
since es2015 semantics gave `let` loops per-iteration bindings,
the `let` callbacks each see their own index while a `var` loop
still shares one:

#listing("interview-repertoire/samples/ch07-js/src/closures.mjs", first: 10, last: 30, caption: [the shared var binding versus per-iteration let])

#diagram([one shared cell prints 3, per-iteration cells print 0 1 2], length: 13pt, {
  // left: the var loop, three callbacks one cell; right: the let loop, three cells
  let cb(x, y, t) = {
    cdraw.rect((x, y), (x + 4.0, y + 0.7), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.0, y + 0.35), [#t], size: 6pt)
  }
  let cell(x, y, t, hot: false) = {
    cdraw.rect((x, y), (x + 2.0, y + 0.8), fill: if hot { luma(205) } else { luma(245) }, stroke: luma(120), radius: 0.02)
    cdraw.content((x + 1.0, y + 0.4), [#t], size: 6pt)
  }
  cdraw.content((4.0, 7.0), [the var loop], size: 6.5pt)
  cb(0.8, 5.4, "callback 0")
  cb(0.8, 4.2, "callback 1")
  cb(0.8, 3.0, "callback 2")
  cell(7.6, 4.2, "n = 3", hot: true)
  cdraw.line((4.8, 5.75), (7.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.8, 4.55), (7.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.8, 3.35), (7.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.0, 1.9), [prints 3, 3, 3], size: 6pt)
  cdraw.content((16.2, 7.0), [the let loop], size: 6.5pt)
  cb(11.6, 5.4, "callback 0")
  cb(11.6, 4.2, "callback 1")
  cb(11.6, 3.0, "callback 2")
  cell(18.6, 5.5, "n = 0")
  cell(18.6, 4.2, "n = 1")
  cell(18.6, 2.9, "n = 2")
  cdraw.line((15.6, 5.75), (18.6, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.6, 4.55), (18.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.6, 3.35), (18.6, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.2, 1.9), [prints 0, 1, 2], size: 6pt)
})

Say it plainly in the room: the `var` callbacks all close over the
same variable and print 3, the `let` callbacks close over three
variables and print 0, 1, 2. The wallet demo is privacy, the
balance reachable only through the two returned functions.

== precedence, coercion, and equality [EWC]

`1 + "1"` is `"11"` because plus prefers concatenation when either
side is a string, `"3" * "2"` is 6 because multiplication has only
the numeric path, and `[] + []` is the empty string. The demo file
returns the whole table at once:

#listing("interview-repertoire/samples/ch07-js/src/precedence.mjs", first: 27, last: 41, caption: [the coercion table, plus binds looser than the arithmetic operators])

#diagram([plus prefers strings, arithmetic coerces, == coerces and === does not], length: 13pt, {
  // one row per surprise, expression, result, the rule
  let row(y, e, r, rule) = {
    cdraw.rect((0.5, y), (6.5, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((3.5, y + 0.5), [#e], size: 6pt)
    cdraw.rect((7.0, y), (11.0, y + 1.0), fill: luma(245), radius: 0.02)
    cdraw.content((9.0, y + 0.5), [#r], size: 6pt)
    cdraw.content((17.5, y + 0.5), [#rule], size: 6pt)
  }
  row(5.2, "1 + \"1\"", "\"11\"", [plus prefers strings])
  row(3.9, "\"3\" * \"2\"", "6", [arithmetic coerces numerically])
  row(2.6, "null == undefined", "true", [the one true mixed pair])
  row(1.3, "typeof null", "\"object\"", [the first-version wart, forever])
})

Equality lives beside it: `==` coerces, `===` does not, and the
one pair that surprises under `==` is `null == undefined` being
true while every other mixed comparison is coercion at work. The
`typeof` table carries the famous wart, `typeof null ===
"object"`, a first-version-js bug the language can never remove.

== null, undefined, NaN, and the optionals [EWC]

Null is assigned absence, undefined is unassigned absence, and NaN
is the only value not equal to itself, which is why
`Number.isNaN` exists beside the coercing global `isNaN`:

#listing("interview-repertoire/samples/ch07-js/src/values.mjs", first: 21, last: 46, caption: [the three absences, the self-inequality, and the ?. ?? pair])

#flow([three absences, three distinct tests, ?? touches only two of them],
  node((0, 0), [an absent value]),
  node((3.6, 1.5), [null,#linebreak()assigned absence]),
  node((3.6, 0), [undefined,#linebreak()unassigned absence]),
  node((3.6, -1.5), [NaN,#linebreak()a failed number]),
  node((7.2, 1.5), [x === null]),
  node((7.2, 0), [x === undefined]),
  node((7.2, -1.5), [Number.isNaN(x),#linebreak()never the coercing isNaN]),
  edge((0, 0), (3.6, 1.5), "-|>"),
  edge((0, 0), (3.6, 0), "-|>"),
  edge((0, 0), (3.6, -1.5), "-|>"),
  edge((3.6, 1.5), (7.2, 1.5), "-|>"),
  edge((3.6, 0), (7.2, 0), "-|>"),
  edge((3.6, -1.5), (7.2, -1.5), "-|>"),
)

The optionals are the modern answer to the absences: `?.`
short-circuits a chain on null and undefined, and `??` defaults
only those two. The test's sharpest row: an empty-string nickname
is replaced by `||` but kept by `??`, because empty string is
falsy but not nullish.

== prototypes [EWC]

Property reads walk the prototype chain, writes never do. The demo
builds the chain with `Object.create`, then mutates through the
child and checks the parent stayed whole:

#listing("interview-repertoire/samples/ch07-js/src/prototypes.mjs", first: 33, last: 47, caption: [reads walk up, writes stay on the receiver])

#diagram([reads walk the chain, writes stay on the receiver], length: 13pt, {
  // the three places things live, top to bottom, chained in the middle
  cdraw.rect((6.0, 6.0), (14.0, 7.0), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((10.0, 6.5), [the instance], size: 6.5pt)
  cdraw.rect((6.0, 4.0), (14.0, 5.0), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((10.0, 4.5), [the prototype], size: 6.5pt)
  cdraw.rect((6.0, 2.0), (14.0, 3.0), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((10.0, 2.5), [the constructor], size: 6.5pt)
  cdraw.line((10.0, 6.0), (10.0, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 4.0), (10.0, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.3, 5.5), [reads], size: 6pt)
  cdraw.content((15.3, 3.5), [reads], size: 6pt)
  // the write never leaves the top box
  cdraw.content((3.0, 7.0), [a write stays], size: 6pt)
  cdraw.content((3.0, 5.9), [on the receiver], size: 6pt)
  cdraw.line((5.6, 6.5), (6.0, 6.5), stroke: luma(40))
  cdraw.content((19.0, 6.5), [own properties only], size: 6pt)
  cdraw.content((19.0, 4.5), [methods, not per instance], size: 6pt)
  cdraw.content((19.0, 2.5), [statics, not inherited], size: 6pt)
})

The `classShape` demo pins where the moving parts sit: methods on
`Greeter.prototype`, statics on the constructor itself, and neither
on the instance. Class syntax is sugar over those links, and the
test proves the sugar does not move them.

== the event loop [EWC]

One call stack, one microtask queue drained to empty after every
macrotask, and timers queued as macrotasks. The demo records
rather than prints:

#listing("interview-repertoire/samples/ch07-js/src/eventloop.mjs", first: 6, last: 20, caption: [microtasks scheduled before an await run before the resume, the timer still pending])

#diagram([one call stack, the microtask queue drained to empty between macrotask turns], length: 13pt, {
  // the stack runs one turn at a time, awaits park and come back
  cdraw.content((2.85, 6.0), [call stack], size: 7pt)
  cdraw.rect((0.7, 2.9), (5.0, 5.6), fill: luma(235), radius: 0.05)
  cdraw.rect((1.1, 3.6), (4.6, 4.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((2.85, 4.1), [one turn], size: 6.5pt)
  // microtasks: everything queued drains before anything else runs
  cdraw.content((14.8, 6.0), [microtask queue, drained to empty first], size: 7pt)
  let mq = ("microtask", "resume 1", "resume 2")
  for i in range(3) {
    cdraw.rect((8.2 + i * 4.4, 4.7), (12.6 + i * 4.4, 5.6), fill: luma(230), radius: 0.02)
    cdraw.content((10.4 + i * 4.4, 5.15), [#mq.at(i)], size: 6pt)
  }
  cdraw.line((8.1, 4.5), (5.1, 4.3), mark: (end: ">"))
  // macrotasks: one timer per turn, and its order is the unspecified part
  cdraw.content((12.8, 2.65), [macrotask queue, one per turn], size: 7pt)
  let tq = ("timer 0ms", "setImmediate")
  for i in range(2) {
    cdraw.rect((8.2 + i * 5.0, 1.4), (13.2 + i * 5.0, 2.3), fill: luma(215), radius: 0.02)
    cdraw.content((10.7 + i * 5.0, 1.85), [#tq.at(i)], size: 6pt)
  }
  cdraw.line((8.1, 2.4), (5.1, 3.1), mark: (end: ">"))
  cdraw.content((11.0, 0.3), [both chained awaits resume before the 0ms timer fires], size: 6.5pt)
})

The two facts the tests pin: a microtask queued before an `await`
runs before the resumption, and two chained awaits still both
return before a `setTimeout(0)` fires, because awaits ride the
microtask queue and timers wait for a macrotask turn. The third
demo records what node's own docs warn: from the main module,
`setImmediate` versus `setTimeout(0)` is unspecified order, and
the test asserts only the guaranteed part, the microtask in front
of both.

#callout("pitfall", "the returned array keeps mutating", [
  The first draft of the microtask demo returned the live events
  array, and the assertion saw entries pushed after the function
  returned, because the caller's own `await` yields to the same
  microtask queue. The fix is the snapshot, `return [...events]`,
  and the lesson travels: a log you hand to an async caller is a
  log they read later.
])

sources: verified by `npm run verify` under node 26.3.0, 22 tests
in `ch07-js`. Language semantics floor to
#xref-to("javascript", "lexical") and the typescript handbook it
cites.
