#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= javascript and its toolchain

This book is two books in one language, with a third layer on top.
Part one, chapters 1 through 10, is javascript itself: values,
functions, objects, iteration, async, modules, the standard library,
the heap, and the profiler, written as plain `.mjs` files that node
26 executes directly with no compiler, no bundler, and no
configuration file. Part two, chapters 11 through 20, is the
typescript layer on top of the same runtime, and it adds exactly one
tool, `tsc`. Part three, chapters 21 and 22, is the framework layer,
react and svelte, and it adds the second tool, `vite`. The splits
are the language's own shape: typescript is a checker whose
annotations erase, and every rule in part two is a promise about
code that part one already explains, while the browser target of
part three is the first place in this book where two engines with
two module graphs have to be reconciled at all.

The runtime under both parts is measured, not assumed. This book runs
node v26.3.0 with V8 14.6.202.34-node.20 and npm 12.0.2 on windows,
probed 2026-09-13, and the first sample reads its facts from the
process itself:

#listing("javascript/samples/src/ch01-toolchain.mjs", first: 4, last: 12, caption: [the runtime report, read from the process rather than transcribed])

Everything a chapter claims about engine behavior is either executed
by a test in the samples project or marked as a fragment and never
executed. Where the specification and this node disagree, the chapter
says so out loud, and the disagreements start early.

== editions, approval against shipping

The language ships as annual editions. Ecma's tc39 committee approves
one each june, and the edition then fans out: spec text first, engine
implementations on their own schedules, node releases picking up V8
versions on a third schedule. The seven editions this book's runtime
spans:

#listing("javascript/samples/src/ch01-toolchain.mjs", first: 80, last: 88, caption: [the edition timeline as data, es2020 through es2026])

#diagram([two clocks, approval in june, engines trailing on their own schedules], length: 13pt, {
  // the approval rail: one tick every june
  cdraw.content((1.4, 7.7), [approval], size: 6.5pt, fill: luma(100))
  cdraw.line((4.4, 7.7), (22.4, 7.7), stroke: luma(100))
  for x in (7.4, 11.4, 15.4, 19.4) { cdraw.line((x, 7.5), (x, 7.9), stroke: luma(100)) }
  cdraw.content((7.4, 8.25), [es2024], size: 6pt)
  cdraw.content((11.4, 8.25), [es2025], size: 6pt)
  cdraw.content((15.4, 8.25), [es2026], size: 6pt)
  cdraw.content((19.4, 8.25), [es2027], size: 6pt)

  // the engine rail: uneven, and crossing the approval rail
  cdraw.content((1.4, 4.6), [engines], size: 6.5pt, fill: luma(100))
  cdraw.line((4.4, 5.6), (22.4, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.4, 6.15), [temporal, stage 4, shipped here already], size: 6pt)
  cdraw.content((17.9, 4.95), [es2026: one feature still missing], size: 6pt)

  // the gap the book measures
  cdraw.rect((14.4, 2.4), (22.4, 3.5), fill: luma(235), radius: 0.02)
  cdraw.content((18.4, 2.95), [approved june 2026], size: 6pt)
  cdraw.line((18.4, 3.5), (18.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 1.5), [a feature joins an edition, an engine ships it when it ships], size: 6.5pt)
})

ES2026 was approved 2026-06-30 with seven features: `Array.fromAsync`,
`Error.isError`, `Math.sumPrecise`, base64 and hex codecs on
`Uint8Array`, `Iterator.concat`, JSON source text access with
`JSON.rawJSON`, and `Map` and `WeakMap` `getOrInsert`. On this node,
five of the seven are present, one is half shipped, and one is
absent, and the matrix says which is which:

#listing("javascript/samples/src/ch01-toolchain.mjs", first: 27, last: 50, caption: [the es2026 matrix, each feature probed by typeof against this runtime])

`Math.sumPrecise` is the absent one, `typeof Math.sumPrecise` is
`"undefined"` here. The json feature is the half: `JSON.rawJSON` and
`JSON.isRawJSON` exist, but `JSON.parse` still takes two parameters,
text and reviver, so the spec's source text access through a third
argument does not run on this node. The arity is the whole evidence:

#listing("javascript/samples/src/ch01-toolchain.mjs", first: 52, last: 68, caption: [the arity probe, and temporal shipped ahead of its edition])

Temporal runs the other direction: stage 4 and slated for the ES2027
edition, yet fully present and unflagged on this runtime, which the
part one chapters on dates use without ceremony. A chapter states
what this node does, names the edition a feature belongs to, and
marks spec text that cannot execute here as a fragment.

== the test framework

Part one tests with `node:test`, the runner built into the runtime:
no dependency, no configuration, discovery by glob. The samples
project opened with one smoke suite that pinned two edition facts:

#listing("javascript/samples/test/smoke.test.mjs", caption: [the smoke suite, temporal and getOrInsert measured on day one])

#diagram([the test framework stacked, blocks to assertions to the exit code], length: 13pt, {
  cdraw.content((11.6, 10.2), [the zero dependency runner, top to bottom], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 8.4), (19.6, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 9.0), [`describe` and `it` blocks], size: 6pt)
  cdraw.content((21.0, 9.0), [suites], size: 6pt)
  cdraw.rect((2.0, 6.8), (19.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 7.4), [assertions through `node:assert/strict`], size: 6pt)
  cdraw.content((21.0, 7.4), [asserts], size: 6pt)
  cdraw.rect((2.0, 5.2), (19.6, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 5.8), [no dependency, no configuration, discovery by glob], size: 6pt)
  cdraw.content((21.0, 5.8), [runner], size: 6pt)
  cdraw.rect((2.0, 3.6), (19.6, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 4.2), [any failure exits nonzero], size: 6pt)
  cdraw.content((21.0, 4.2), [exit], size: 6pt)
  cdraw.content((11.6, 2.4), [the runner reports per test, `make` reads only the exit code, #linebreak() the same contract `go test`, `dotnet test`, and pytest keep], size: 6.5pt)
})

Suites grow into `describe` and `it` blocks asserting through
`node:assert/strict`, the runner reports per test, and any failure
exits nonzero. That exit code is the only interface `make` needs, the
same contract every other book in this corpus keeps with its own
runner, `go test`, `dotnet test`, or pytest.

== the no build step thesis

Part one's project is `javascript/samples/`, and its whole manifest
is fifteen lines:

#listing("javascript/samples/package.json", caption: [the part i manifest, no dependencies, no build])

`type: module` makes every file an es module, `engines` records the
node floor, and `verify` is one stage: node's own test runner over
the sources. Nothing compiles, nothing is emitted, and the file a
listing shows is byte for byte the file the test executed. Part two's
`tssamples` project keeps the two stage chain instead, `tsc`
typechecks and emits, then node tests the emitted `dist`, and that
contrast is deliberate: the typescript chapters are about what a
checker adds, so they test what the checker produced.

#flow(
  [the two verify chains, one stage for part i, two for part ii],
  node((0, 0), [`src/*.mjs` #linebreak() plain javascript]),
  node((3.2, 0), [`node --test` #linebreak() runs sources]),
  node((0, 2.4), [`ch*/*.ts` #linebreak() annotated]),
  node((3.2, 2.4), [`tsc -p` #linebreak() checks, emits]),
  node((6.4, 2.4), [`dist/*.js` #linebreak() then tested]),
  edge((0, 0), (3.2, 0), "-|>", label: [no build step]),
  edge((0, 2.4), (3.2, 2.4), "-|>"),
  edge((3.2, 2.4), (6.4, 2.4), "-|>"),
)

Two more projects arrive with their own chapters, part three's
fwsamples project for react and svelte and the capstone project of
chapter 38, each reusing the chain its layer built.
Every chapter of part one adds one module under `samples/src/` and
one suite under `samples/test/`, and the sample reads its own
manifest to keep the contract honest:

#listing("javascript/samples/src/ch01-toolchain.mjs", first: 70, last: 78, caption: [the project manifest read from the sample that runs under it])

#callout("note", "the two tools, and why a bundler waits for part three", [
  Tooling enters this book twice, once per layer that needs it.
  Part two adds `tsc`, a checker whose annotations erase, and part
  three adds `vite`, a bundler. The honest argument for the wait:
  a book pinned to one runtime has nothing to reconcile, node 26
  runs the editions of the last seven years natively, and the one
  feature it lacks cannot be polyfilled anyway, since
  `Math.sumPrecise` is a built in whose absence is the fact being
  reported. A browser island target is the first place a bundler
  reconciles anything real: the island ships jsx the browser cannot
  parse and a component graph the server never runs, and one build
  step turns both into a single esm file a script tag can load.
  Vite stays a build step, never a runtime, and `node --test`
  remains the only runner through the last page.
])

sources: nodejs.org api and release documentation, tc39.es ecma 262
edition list and finished proposals, developer.mozilla.org edition
guides, accessed 2026-09-13. Runtime behavior verified live with node
v26.3.0, V8 14.6.202.34-node.20, npm 12.0.2 on windows, 10 tests
green through `npm run verify` in `javascript/samples`.
