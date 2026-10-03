#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= functions, scope, and closures

A function in javascript is a value first: it can be stored, passed,
returned, compared by identity, and it carries two pieces of metadata
the engine maintains for free, its name and its arity. Around that
value the language builds scope, the rules for which bindings a
function can see, and closures, the mechanism by which those
bindings outlive the call that created them. Everything in this
chapter runs without a compiler on node 26.

== three forms, one value

Functions come written three ways. A declaration is a statement with
a name, hoisted and initialized before the module body runs. An
expression is a value assigned to a binding. An arrow is an
expression with a shorter syntax, a lexical `this`, and no
`arguments` object of its own:

#listing("javascript/samples/src/ch03-functions.mjs", first: 4, last: 20, caption: [the three forms, with the name and arity the engine tracks])

#diagram([the three forms as columns, one callable value with free metadata], length: 13pt, {
  cdraw.content((11.5, 10.4), [three spellings, one value, name and arity kept for free], size: 6.5pt, fill: luma(100))
  let col(x, w, head, one, two) = {
    cdraw.rect((x, 7.2), (x + w, 8.2), fill: luma(205), radius: 0.02)
    cdraw.content((x + w / 2, 7.7), head, size: 6pt)
    cdraw.rect((x, 5.2), (x + w, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.0), one, size: 6pt)
    cdraw.rect((x, 3.2), (x + w, 4.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 4.0), two, size: 6pt)
  }
  col(0.4, 7.0, [declaration], [`function declared(a, b)` #linebreak() hoisted whole], [name `"declared"`, length 2])
  col(7.9, 7.0, [expression], [a value assigned to a binding], [name `"named"`, length 1, #linebreak() the default stops the count])
  col(15.4, 7.2, [arrow], [lexical `this`, no `arguments` #linebreak() of its own], [name `"arrow"` from the binding, #linebreak() length 1])
  cdraw.content((11.5, 1.9), [a call above `declared` works, #linebreak() a call above `const arrow` lands in the dead zone], size: 6.5pt)
})

`length` counts parameters up to the first default, so
`expressed.length` is 1, and inferred names like `arrow` come from
the binding when the expression has no name of its own. Declarations
hoist whole, which chapter 2's timeline already drew: a call above
the declaration line works, while a call above a `const` arrow lands
in the dead zone.

== this binds by call site

The `this` of an ordinary function is decided by how it is called,
not where it is written. Called through its receiver, a method sees
the receiver. Detached and called bare in module code, it sees
`undefined`, and the property read throws. `call`, `apply`, and
`bind` reattach a receiver explicitly, `bind` permanently, and the
arrow sidesteps the whole mechanism by not having a `this` at all:

#listing("javascript/samples/src/ch03-functions.mjs", first: 22, last: 48, caption: [five calls, five receivers, one detached call that throws])

#flow(
  [receiver resolution, four ways a call finds its this],
  node((0, 0), [a method call]),
  node((3.2, 0), [binds the receiver]),
  node((0, 1.5), [detached call]),
  node((3.2, 1.5), [`undefined` in a module, #linebreak() the read throws]),
  node((0, 3.0), [`.bind(fn, obj)`]),
  node((3.2, 3.0), [reattached, permanently]),
  node((0, 4.5), [an arrow function]),
  node((3.2, 4.5), [lexical: no this here, #linebreak() resolved outward]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((0, 1.5), (3.2, 1.5), "-|>"),
  edge((0, 3.0), (3.2, 3.0), "-|>"),
  edge((0, 4.5), (3.2, 4.5), "-|>"),
)

Arrows exist largely for this rule. A callback that must keep seeing
the enclosing `this` is an arrow, a method that needs its receiver
is an ordinary function, and the two forms split work along exactly
that line.

== parameters

Default parameters may read the parameters before them, one rest
parameter collects everything after its position into a true array,
and the `arguments` object belongs to ordinary functions, arrows
resolve the name outward instead:

#listing("javascript/samples/src/ch03-functions.mjs", first: 50, last: 60, caption: [defaults reading earlier parameters, rest as a true array, legacy arguments])

#diagram([the three parameter forms, what each spells and what arrives], length: 13pt, {
  cdraw.content((3.2, 8.9), [form], size: 6.5pt, fill: luma(100))
  cdraw.content((10.0, 8.9), [spelling], size: 6.5pt, fill: luma(100))
  cdraw.content((17.6, 8.9), [arrival], size: 6.5pt, fill: luma(100))
  let row(y, f, s, a, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.2, y + 0.7), f, size: 6pt)
    cdraw.content((10.0, y + 0.7), s, size: 6pt)
    cdraw.content((17.6, y + 0.7), a, size: 6pt)
  }
  row(6.9, [defaults], [`b = a * 2`], [may read earlier parameters], false)
  row(4.9, [rest], [`(head, ...rest)`], [one, last, a true array], true)
  row(2.9, [legacy], [`arguments`], [ordinary functions only], false)
  for x in (6.6, 13.6) { cdraw.line((x, 2.9), (x, 8.3), stroke: luma(220)) }
  cdraw.content((11.6, 1.5), [arrows resolve `arguments` outward, defaults do not count toward `length`], size: 6.5pt)
})

== closures and the module pattern

A closure is a function plus the bindings it kept. The counter below
closes over `count`, and after `createCounter` returns, `count` is
unreachable except through the two functions that captured it. That
is encapsulation without classes, and at file scale it is the module
pattern: the module's top level is the function, the exports are the
returned object, and everything else is private:

#listing("javascript/samples/src/ch03-functions.mjs", first: 62, last: 82, caption: [a counter and a wallet, state visible only through the returned functions])

#diagram([the closure kept per call, and the module as the same trick at file scale], length: 13pt, {
  cdraw.content((11.5, 9.5), [a closure is a function plus the bindings it kept], size: 6.5pt, fill: luma(100))

  // two counters and one wallet, each with its hidden binding
  let cell(x, w, name, binding) = {
    cdraw.rect((x, 6.6), (x + w, 8.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 8.15), name, size: 6pt)
    cdraw.rect((x + 1.2, 6.9), (x + w - 1.2, 7.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + w / 2, 7.25), binding, size: 6pt)
    cdraw.line((x + w / 2, 6.6), (x + w / 2, 5.6), stroke: luma(100), mark: (end: ">"))
  }
  cell(0.4, 6.8, [`createCounter()`], [`count`])
  cell(7.9, 6.8, [`createCounter()`], [`count`])
  cell(15.4, 7.4, [`createWallet()`], [`balance`])

  // the returned functions, the only doors
  let door(x, w, t) = {
    cdraw.rect((x, 4.6), (x + w, 5.6), fill: none, stroke: luma(160), radius: 0.02)
    cdraw.content((x + w / 2, 5.1), t, size: 6pt)
  }
  door(0.4, 3.3, [`increment`])
  door(3.9, 3.3, [`value`])
  door(7.9, 3.3, [`increment`])
  door(11.4, 3.3, [`value`])
  door(15.4, 3.5, [`deposit`])
  door(19.3, 3.5, [`balance()`])
  cdraw.content((7.5, 3.8), [two counters, two independent `count` bindings], size: 6.5pt)
  cdraw.content((19.1, 3.6), [`Object.keys` sees the two functions, #linebreak() `balance` the number is not a property], size: 6pt)

  // the module pattern band
  cdraw.rect((0.4, 1.4), (22.8, 2.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.1), [the module pattern, the same trick at file scale: #linebreak() the top level is the function, the exports are the returned object], size: 6pt)
})

Two counters close over two independent bindings, which the tests
pin, and `Object.keys` on the wallet sees the two functions and
nothing else, `balance` the number does not exist as a property at
all. Chapter 4 shows the same privacy built from `#private` fields,
and part two's chapter on modules shows the file scale version.

== the iife, retired

The immediately invoked function expression was the pre-2015 way to
buy a scope, wrap the whole file in a function, call it at once,
keep the private names inside. Block scoped `let` and `const` bought
the same scope with two characters, and modules bought the file
scale version natively:

#listing("javascript/samples/src/ch03-functions.mjs", first: 84, last: 99, caption: [the iife and the block that replaced it, buying the same scope])

#diagram([the iife against the block that replaced it, the same scope re-priced], length: 13pt, {
  cdraw.content((5.5, 8.4), [before es2015], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.6), (10.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.1), [`(function () { ... })()`, called at once], size: 6pt)
  cdraw.rect((0.4, 5.2), (10.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.7), [the whole file wrapped, `var` private inside], size: 6pt)

  cdraw.content((17.5, 8.4), [since es2015], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.6), (22.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.1), [a block, `{ let scoped = 41 }`], size: 6pt)
  cdraw.rect((12.4, 5.2), (22.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.7), [the same scope for two characters of `let`], size: 6pt)

  cdraw.rect((4.0, 2.2), (19.2, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.9), [modules bought the file scale version natively], size: 6pt)
  cdraw.content((11.6, 1.2), [the form survives in old codebases and one shot async setup], size: 6.5pt)
})

The form survives in older codebases and as an idiom for one-shot
async setup, but this book writes blocks and modules instead.

== higher order functions

A higher order function takes functions as arguments or returns
them. Composition threads one function's output into the next
function's input, and memoization wraps a function with a cache
keyed by argument, one line on top of ES2026's
`getOrInsertComputed`, which calls its callback only on a cache miss:

#listing("javascript/samples/src/ch03-functions.mjs", first: 101, last: 116, caption: [compose, memoize over getOrInsertComputed, twice])

#diagram([compose threading one lane, memoize branching on the cache], length: 13pt, {
  // compose: one output into the next input
  cdraw.content((11.5, 9.4), [compose, one output into the next input], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.6, 7.6), (4.2, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((2.4, 8.2), [`x`], size: 6pt)
  cdraw.line((4.2, 8.2), (5.4, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.4, 7.6), (11.2, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((8.3, 8.2), [`g(x)`], size: 6pt)
  cdraw.line((11.2, 8.2), (12.4, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.4, 7.6), (18.2, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.3, 8.2), [`f(g(x))`], size: 6pt)
  cdraw.content((20.6, 8.2), [threaded], size: 6pt)

  // memoize: the argument arrives at the cache
  cdraw.content((11.5, 6.3), [memoize, one line over `getOrInsertComputed`], size: 6.5pt, fill: luma(100))
  cdraw.rect((10.3, 5.0), (12.7, 5.8), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((11.5, 5.4), [`(arg)`], size: 6pt)
  cdraw.line((11.5, 5.0), (11.5, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.0, 3.2), (16.0, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 3.8), [the cache `Map`, keyed by argument], size: 6pt)

  // hit and miss
  cdraw.line((9.0, 3.2), (5.2, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.4, 3.1), [hit], size: 6pt)
  cdraw.rect((1.0, 1.2), (9.4, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 1.8), [the stored value, no call], size: 6pt)
  cdraw.line((14.0, 3.2), (17.8, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.6, 3.1), [miss], size: 6pt)
  cdraw.rect((13.8, 1.2), (22.4, 2.4), fill: luma(205), radius: 0.02)
  cdraw.content((18.1, 1.8), [the callback runs, the entry inserted], size: 6pt)
  cdraw.content((11.5, 0.3), [the contract in a call count: once per distinct argument, the callback only on the miss], size: 6.5pt)
})

The test proves the memoized function calls its wrapped function
once per distinct argument, twice for two arguments, which is the
whole contract of a cache. Higher order functions are how the
standard library's `map`, `filter`, and `reduce` are built, and
chapter 5 leans on them heavily.

== recursion and the tail call promise

Functions may recurse directly or mutually with no forward
declaration. The es2015 specification also requires proper tail
calls, a tail position call reusing the caller's frame, and the
engines split on it: javascriptcore implemented the requirement,
v8 and spidermonkey declined it, citing debugging and stack trace
costs. On this runtime the spec's promise does not hold, and the
probe measures the fact rather than trusting either side:

#listing("javascript/samples/src/ch03-functions.mjs", first: 118, last: 130, caption: [a tail recursive countdown of a million frames, overflowing on v8])

#diagram([the tail call promise against this engine's stack], length: 13pt, {
  // what the spec promised
  cdraw.content((5.5, 8.4), [the spec's promise], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.6), (10.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.1), [tail frame reuses the caller's], size: 6pt)
  cdraw.rect((0.4, 5.2), (10.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.7), [constant stack, any depth], size: 6pt)

  // what v8 does
  cdraw.content((17.5, 8.4), [v8, measured], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.6), (22.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.1), [every call is a real frame], size: 6pt)
  cdraw.rect((12.4, 5.2), (22.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.7), [1e6 tail frames, `RangeError`], size: 6pt)

  // the honest number
  cdraw.rect((4.0, 2.2), (19.2, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.9), [plain recursion bottoms out near 12,500 frames here], size: 6pt)
  cdraw.content((11.6, 1.2), [recursion stays for trees and parsers, loops take the depth], size: 6.5pt)
})

The practical rule follows from the measurement: recursion is for
structures naturally shaped like trees, where depth is logarithmic,
and a loop is for anything that might go deep. javascriptcore is the
one engine where the spec's promise holds, so portable code assumes
it holds nowhere.

sources: developer.mozilla.org function and arrow function
documentation, tc39.es es2015 tail calls clause, v8 dev blog on tail
call elimination, accessed 2026-09-13. Behavior verified live with
node v26.3.0 on windows, 36 tests green through `npm run verify` in
`javascript/samples`, 13 of them this chapter's.
