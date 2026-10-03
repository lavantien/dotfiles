#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= typescript 7: the type layer

Part one ran javascript with no build step: `.mjs` files, `node --test`,
and nothing between the source and the runtime. Part two adds exactly
one tool, `tsc`, and the tool is compile time only. It reads annotated
javascript, checks it against promises the annotations make, then
erases every one of those annotations and emits plain javascript that
node 26 runs exactly as part one taught. The split is the language's
own shape: typescript is a checker whose types vanish, so every rule
in these chapters is a claim about code whose runtime behavior
chapters 1 through 10 already own, and the emit side of that contract,
declarations and namespaces and what survives compilation, is chapter
19's subject. This chapter installs the compiler, configures it, and
proves the erasure on the record.

== a checker, not a runtime

The founding asymmetry: annotations are checked, then deleted. A
parameter typed `string` compiles, and a caller who smuggles `null`
past the checker with a cast still meets the plain runtime the
annotation promised to describe. No check is injected, because the
type never survived compilation:

#listing("javascript/tssamples/ch11/tstoolchain.ts", first: 44, last: 48, caption: [greet is ordinary typed code, shout is the erasure probe])

The test passes `null as unknown as string`, the emitted javascript
throws `Cannot read properties of null` at the `toUpperCase` call, and
the second observation is made against the emitted file itself: the
module reads its own compiled output from `dist` and reports whether
the annotation text is still present. It is not. The needles are
assembled from halves so the probe cannot vouch for its own source:

#listing("javascript/tssamples/ch11/tstoolchain.ts", first: 50, last: 61, caption: [the erasure observed in the emitted file rather than asserted in prose])

#diagram([the founding asymmetry, annotations erased at emit while the null cast reaches the runtime], length: 13pt, {
  // band one: the signature before and after emit
  cdraw.content((5.6, 9.1), [source], size: 6.5pt, fill: luma(100))
  cdraw.content((5.6, 7.6), [`shout(s: string): string`], size: 6pt)
  cdraw.content((5.6, 6.5), [`s.toUpperCase()`], size: 6pt)
  cdraw.line((11.6, 7.0), (13.2, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.4, 7.5), [`tsc`], size: 6pt)
  cdraw.content((18.6, 9.1), [emitted], size: 6.5pt, fill: luma(100))
  cdraw.content((18.6, 7.6), [`shout(s)`], size: 6pt)
  cdraw.content((18.6, 6.5), [`s.toUpperCase()`], size: 6pt)
  cdraw.content((12.1, 5.6), [annotations gone, body identical], size: 6.5pt)

  // band two: one input, two verdicts
  cdraw.content((12.1, 4.4), [the founding asymmetry], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 2.2), (11.2, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 2.9), [checker: the cast compiles], size: 6pt)
  cdraw.content((5.8, 1.6), [`null as unknown as string`], size: 6pt)
  cdraw.line((11.8, 2.9), (13.0, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.4, 2.2), (22.8, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((18.1, 2.9), [runtime: the call throws], size: 6pt)
  cdraw.content((18.1, 1.6), [throws at `toUpperCase`], size: 6pt)
})

That asymmetry, checked by the machine rather than argued in prose,
is the mental model for everything in part two. When a type must be
enforced in running code, the tool is a runtime check plus the
`unknown` type of chapter 13, never a fancier annotation.

== the native 7 compiler

TypeScript 7, released july 2026, is the native port: the compiler
rewritten in Go, compiled ahead of time, reporting 8 to 12 times
faster full builds and a fraction of the memory. For a command line
user almost nothing moved. The compiler still installs as the
`typescript` package and still answers to `tsc`, nightlies still live
on the `next` tag, and `tsconfig.json` is still the configuration
surface. What moved is everything underneath: the old
`@typescript/native-preview` package is retired, and the js api of
5.x and 6.x is gone from the stable entry point, whose root export
carries nothing beyond the version string. A compiler api does ship
in 7.0.2, but as `unstable` subpath exports, sync, async, fs, proto,
and ast entry points under `typescript/unstable`. This book builds on
none of that unstable surface and waits for the stable api promised
for 7.1. Projects that need the old api run 6.0 side by side through
the `@typescript/typescript6` package and its `tsc6` binary.

The project pins `typescript` `^7.0.2` and the measurement is part of
the contract: `npx tsc --version` in `tssamples` prints
`Version 7.0.2`, probed 2026-09-13, and the sample reads the same
string from the installed package manifest so the suite fails if the
compiler under it changes.

#diagram([the 7.0 port as a release timeline, three rails against the version axis], length: 13pt, {
  // rail one: the cli surface, flat across the whole span
  cdraw.content((1.4, 7.7), [surface], size: 6.5pt, fill: luma(100))
  cdraw.line((4.4, 7.7), (22.4, 7.7), stroke: luma(100))
  cdraw.content((13.4, 8.35), [same `tsc`, same `tsconfig.json`, nightlies on `next`], size: 6pt)

  // rail two: the engine underneath, stepping up at 7.0
  cdraw.content((1.4, 5.2), [engine], size: 6.5pt, fill: luma(100))
  cdraw.line((4.4, 4.4), (14.0, 4.4), stroke: luma(100))
  cdraw.line((14.0, 4.4), (14.0, 5.9), stroke: luma(100))
  cdraw.line((14.0, 5.9), (22.4, 5.9), stroke: luma(100))
  cdraw.content((9.2, 4.7), [one js compiler], size: 6pt)
  cdraw.content((18.2, 6.2), [aot go build, 8 to 12x], size: 6pt)

  // rail three: the compiler api, dropped then returning
  cdraw.content((1.4, 2.7), [api], size: 6.5pt, fill: luma(100))
  cdraw.line((4.4, 2.7), (14.0, 2.7), stroke: luma(100))
  cdraw.line((14.0, 2.7), (14.0, 1.5), stroke: luma(100))
  cdraw.line((14.0, 1.5), (20.6, 1.5), stroke: luma(220))
  cdraw.line((20.6, 1.5), (20.6, 2.7), stroke: luma(100))
  cdraw.line((20.6, 2.7), (22.4, 2.7), stroke: luma(100))
  cdraw.content((9.2, 3.0), [js api on the stable root], size: 6pt)
  cdraw.content((17.3, 0.85), [dropped, `tsc6` bridges], size: 6pt)
  cdraw.content((21.5, 3.0), [stable], size: 6pt)

  // the version axis the three rails read against
  cdraw.line((4.4, 0.3), (22.4, 0.3), stroke: luma(220))
  cdraw.line((4.4, 0.1), (4.4, 0.5)); cdraw.line((14.0, 0.1), (14.0, 0.5))
  cdraw.line((20.6, 0.1), (20.6, 0.5))
  cdraw.content((4.4, -0.35), [6.0], size: 6pt)
  cdraw.content((14.0, -0.35), [7.0], size: 6pt)
  cdraw.content((20.6, -0.35), [7.1], size: 6pt)
})

== the honest es2026 story

Part one closed on an edition gap: es2026 was approved june 2026,
node 26 ships most of it, and `Math.sumPrecise` is still absent. The
type layer has its own gap, measured the same way, and it runs the
other direction. `tsc` 7.0.2 knows no es2026 at all: `--target
es2026` answers `TS6046` and lists every target it does accept,
ending at `es2025` then `esnext`, and `--lib es2026` answers the same
error over the library list. The default target is `es2025`, the
newest edition the compiler knows, so this book's node runtime is
ahead of its checker's edition vocabulary, not behind it.

The bridge is the lib fragment. A `lib` entry names a library
description file, and the `esnext.*` fragments carry es2026 era api
declarations ahead of an edition lib: `esnext.temporal` for Temporal,
`esnext.disposable` for `using` and `Disposable`,
`esnext.typedarrays` for the `Uint8Array` base64 and hex codecs, and
`esnext.collection` for `Map.getOrInsert`, each fragment listed by
the same `TS6046` message. The worked example is Temporal, and it is
the honest case because the runtime ships it while the node type
package does not: `@types/node` 26 declares no Temporal globals, so
without the fragment the file below fails with `TS2503`, cannot find
namespace `Temporal`, measured live, and with the fragment it
typechecks and runs:

#listing("javascript/tssamples/ch11/tstoolchain.ts", first: 24, last: 38, caption: [temporal typed through the esnext.temporal fragment, the api part one's chapter 8 already runs])

#diagram([es2026 era apis reaching the checker one fragment at a time], length: 13pt, {
  cdraw.content((4.6, 8.4), [fragment], size: 6.5pt, fill: luma(100))
  cdraw.content((13.6, 8.4), [what it declares], size: 6.5pt, fill: luma(100))
  cdraw.content((20.9, 8.4), [part one], size: 6.5pt, fill: luma(100))

  let row(y, frag, what, ch, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.3), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.6, y + 0.65), frag, size: 6pt)
    cdraw.content((13.6, y + 0.65), what, size: 6pt)
    cdraw.content((20.9, y + 0.65), ch, size: 6pt)
  }
  row(6.8, [`esnext.temporal`], [the Temporal namespace], [ch 8], false)
  row(5.3, [`esnext.disposable`], [`using`, `Disposable`, `Symbol.dispose`], [ch 7], true)
  row(3.8, [`esnext.typedarrays`], [`Uint8Array` base64 and hex], [ch 5], false)
  row(2.3, [`esnext.collection`], [`Map.getOrInsert`], [ch 5], true)
  cdraw.content((11.6, 1.1), [the runtime shipped first, part one measured it, fragments let the checker agree], size: 6.5pt)
})

== tsconfig anatomy

Every chapter of part two keeps its samples in one npm project under
`javascript/tssamples/`, and the whole configuration is one file.
`tsc --showConfig` against it prints the resolved configuration and
exposes two settings 7.0 forces on with no opt out:
`isolatedModules`, every file must be transpilable alone, which is
what the native compiler's parallel checking assumes, and
`preserveConstEnums`, const enums emit like plain enums:

#listing("javascript/tssamples/tsconfig.json", caption: [the part ii configuration, one file, node's resolution, es2025 with two esnext fragments])

The `nodenext` pair opts into node's own module resolution over the
`esnext` default, which is what makes `import x from "./x.json" with
{ type: "json" }` check without ceremony. The `types` line is the
migration trap: its default changed to an empty list, so installing
`@types/node` no longer auto includes node types, and imports from
`node:test` fail to resolve until `"types": ["node"]` says so out
loud. `strict` is on without being asked, inherited from the 6.0
default move, and does not appear in the resolved output because
nothing here overrides it.

`verbatimModuleSyntax` is the load bearing discipline for a book
about erasure: whatever the import spelling, that exact spelling is
emitted. A type imported plainly would emit an import of a name that
no longer exists, so type-only imports must say `import type`, and
the flag turns every silent violation into a build error. The
chapters ahead use it everywhere, which is why their test files
import interfaces with `import type` and everything else plainly.

#diagram([tsconfig options by what 7.0 lets a project still turn], length: 13pt, {
  let row(y, label, opts, dark) = {
    cdraw.rect((0.4, y), (5.4, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.9, y + 0.7), label, size: 6pt)
    cdraw.content((14.4, y + 0.7), opts, size: 6pt)
  }
  row(6.4, [defaults moved], [`strict` on, `module` esnext, `target` es2025], false)
  row(4.3, [opted out here], [the `nodenext` pair, `types` carries `node`], true)
  row(2.2, [forced on], [`isolatedModules`, `preserveConstEnums`], false)
  row(0.1, [added ahead], [the `esnext.temporal` fragment], true)
})

#callout("warning", "removed in 7.0", [
  The native compiler dropped a pile of legacy surface: `target:
  es5` and `downlevelIteration`, `moduleResolution: node10` and
  `classic`, the `amd`, `umd`, `systemjs`, and `none` module formats,
  and `baseUrl`, whose `paths` are now project root relative. Import
  `asserts` became `with`, the `module` keyword inside a namespace
  declaration is an error, and the `esnext` target list itself stops
  at `es2025`, verified live against 7.0.2.
])

== the two stage verify chain

The manifest declares the module system and one script, and the
script is two stages: `tsc` typechecks and emits, then node's own
runner tests the emitted `dist`. The script opens by deleting
`dist`, because `tsc` never removes old outputs itself: after this
book's renumber moved `erasure.ts` out of ch17, a stale emitted
`dist/ch17/erasure.test.js` still matched the test glob and failed
the gate on files that no longer existed. Testing the emitted output rather
than the sources is deliberate. Part one's file is byte for byte the
file that ran, and part two's honest equivalent is the file `tsc`
produced, annotations gone, which is also what lets enum and
namespace samples, which node's own type stripping cannot handle,
still run:

#listing("javascript/tssamples/package.json", caption: [the part ii manifest, one script, two stages])

#flow(
  [the two stage verify chain, sources tested only as emitted output],
  node((0, 0), [`ch*/*.ts` #linebreak() sources]),
  node((2.6, 0), [`tsc -p` #linebreak() typecheck, emit]),
  node((5.2, 0), [`dist/*.js` #linebreak() plus `.map`]),
  node((7.8, 0), [`node --test` #linebreak() runs dist]),
  edge((0, 0), (2.6, 0), "-|>"),
  edge((2.6, 0), (5.2, 0), "-|>"),
  edge((5.2, 0), (7.8, 0), "-|>", label: [plain js only]),
)

Around `tsc -p` sit the inspection commands this chapter used while
writing: `tsc --version` to pin the build, `tsc --showConfig` for the
resolved configuration and the forced options, and the new
parallelism knobs, `--checkers` for the count of parallel type
checking threads, `--builders` for parallel project references under
`--build`, and `--singleThreaded` to disable both for profiling.

The harness itself is `node:test` with `describe` and `it`, asserting
through `node:assert/strict`, the same runner part one uses on
sources, here aimed at `dist`:

#listing("javascript/tssamples/ch11/tstoolchain.test.ts", first: 1, last: 24, caption: [the node:test harness every part two chapter reuses])

#callout("note", "no stable api means no introspection", [
  The go book found its compiler version through `runtime.Version`
  and the scanner through `go/token`. Typescript 7 offers no stable
  equivalent: the package root exports nothing beyond its version,
  and the compiler api that does ship lives under `unstable`
  exports this book does not build on. The sample reads the
  installed package manifest from disk, which is also the honest
  answer to which compiler checked this file.
])

sources: devblogs.microsoft.com/typescript announcing typescript 7.0,
typescriptlang.org tsconfig reference and compiler options in js,
nodejs.org api test runner docs, accessed 2026-09-13. Toolchain
behavior verified live with tsc 7.0.2 (`npx tsc --version` prints
`Version 7.0.2`) and node 26.3.0 on windows, the es2026 rejections
and the `TS2503` temporal failure reproduced against the cli, 7 tests
green in ch11 through `npm run verify` in `javascript/tssamples`.
