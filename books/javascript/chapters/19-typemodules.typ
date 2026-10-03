#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= declarations, namespaces, and emit

Chapter 11 proved the founding asymmetry on one function: annotations
are checked, then deleted. This chapter owns the seams around that
fact. How the checker resolves and types the module graph part one's
chapter 7 already runs, what a declaration file is and how to write
one by hand for plain javascript, where the pre-module namespace
still pays its way, and exactly what emit leaves behind, sourcemaps
included. The parked chapter that used to carry erasure alone is
dissolved into this one, and every claim below is checked against
the emitted files in `dist`, not argued in prose.

== resolution for the type layer

Typescript modules are ecmascript modules, one file is one module,
and the checker reads the same graph node executes. The `nodenext`
pair from chapter 11's tsconfig is what keeps the two honest: the
checker resolves exactly the way node does, extensions included.
The chapter's barrel uses every form at once:

#listing("javascript/tssamples/ch19/modules.ts", first: 3, last: 9, caption: [default, named, type-only, attribute, and re-exports in one header])

#diagram([every import form in one header, and the rule each one carries], length: 13pt, {
  cdraw.content((3.2, 12.5), [form], size: 6.5pt, fill: luma(100))
  cdraw.content((10.9, 12.5), [spelled], size: 6.5pt, fill: luma(100))
  cdraw.content((19.1, 12.5), [rule], size: 6.5pt, fill: luma(100))

  let row(y, f, s, r, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.2, y + 0.7), f, size: 6pt)
    cdraw.content((10.9, y + 0.7), s, size: 6pt)
    cdraw.content((19.1, y + 0.7), r, size: 6pt)
  }
  row(10.8, [default], [`import G from ...`], [one per module], false)
  row(9.0, [named], [`{ Casual, Formal }`], [binds exported names], true)
  row(7.2, [type only], [`import type { Lens }`], [verbatim demands it], false)
  row(5.4, [json attribute], [`with { type: "json" }`], [replaced `assert`, removed], true)
  row(3.6, [re-export], [`export { Lens }`], [values and types apart], false)
  row(1.8, [extensions], [`"./greeter.js"`], [nodenext wants it], true)

  for x in (6.4, 15.4) { cdraw.line((x, 1.8), (x, 12.2), stroke: luma(220)) }
  cdraw.content((11.6, 0.8), [one header, every form, checker and node read one graph], size: 6.5pt)
})

Three details in that header carry the whole discipline. Imports
name files with extensions, `./greeter.js`, because node wants the
extension and the checker agrees. `import type` is not decoration:
with `verbatimModuleSyntax` on, importing a type without the `type`
modifier is an error, since the emitted statement would import a
name that does not exist at runtime. And the json import carries an
import attribute, `with { type: "json" }`, which replaced the older
`assert` syntax that 7.0 removed. The re-exported type still needs
its own local `import type` to be usable in the file doing the
re-exporting, and dynamic import returns a promise of the module,
which makes lazy loading an ordinary async function body:

#listing("javascript/tssamples/ch19/modules.ts", first: 40, last: 47, caption: [dynamic import, and a re-exported type used locally])

== namespaces against modules

Namespaces predate modules and group names under one emitted
object. Nested namespaces nest objects, and members are exported
from the namespace explicitly, exactly like a module:

#listing("javascript/tssamples/ch19/shapes.ts", first: 3, last: 15, caption: [nested namespaces emitting real objects])

They remain the right tool in exactly one place, merging with an
interface of the same name to attach helpers to a type, the
declaration merging chapter 15 demonstrated on plain interfaces:

#listing("javascript/tssamples/ch19/modules.ts", first: 14, last: 21, caption: [interface and namespace merging into one entity])

#diagram([namespaces as emitted objects, and the cargo merge], length: 13pt, {
  // nested namespaces become nested real objects
  cdraw.content((5.0, 8.8), [one real object per namespace], size: 6.5pt, fill: luma(100))
  let chip(x, y, w, t, dark) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, size: 6pt)
  }
  chip(0.6, 6.9, 2.8, [`Metrics`], false)
  chip(4.4, 7.3, 2.4, [`Area`], true)
  chip(4.4, 6.1, 2.4, [`Unit`], true)
  chip(0.6, 4.5, 2.4, [`Tree`], false)
  chip(4.0, 4.5, 2.4, [`Root`], true)
  chip(7.0, 4.5, 3.0, [`Branch`], true)
  chip(10.6, 4.5, 2.4, [`Leaf`], true)
  cdraw.line((3.4, 7.35), (4.4, 7.75), stroke: luma(100))
  cdraw.line((3.4, 7.35), (4.4, 6.55), stroke: luma(100))
  cdraw.line((3.0, 4.95), (4.0, 4.95), stroke: luma(100))
  cdraw.line((1.8, 4.5), (1.8, 4.05), stroke: luma(100))
  cdraw.line((1.8, 4.05), (8.3, 4.05), stroke: luma(100))
  cdraw.line((8.3, 4.05), (8.3, 4.5), stroke: luma(100))
  cdraw.line((10.0, 4.95), (10.6, 4.95), stroke: luma(100))
  cdraw.content((5.6, 3.4), [`Tree.Branch.Leaf`, one object deep], size: 6pt)

  // the interface and namespace merge
  cdraw.content((18.0, 8.4), [the merge], size: 6.5pt, fill: luma(100))
  chip(13.2, 6.9, 4.4, [interface `Cargo`], false)
  chip(13.2, 5.6, 4.4, [namespace `Cargo`], false)
  cdraw.line((17.6, 7.35), (18.8, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.6, 6.05), (18.8, 6.2), stroke: luma(100), mark: (end: ">"))
  chip(18.8, 6.2, 3.8, [a type], true)
  cdraw.content((20.7, 5.4), [and a value], size: 6pt)
  cdraw.content((17.6, 4.3), [the `Array` and `Promise` trick], size: 6.5pt)
  cdraw.content((11.6, 2.3), [namespaces emit objects, modules never do], size: 6.5pt)
})

`Cargo` is now simultaneously a type, the interface, and a value,
the namespace, which is how `Array` and `Promise` carry their static
methods and how library types grow companion functions.

#callout("warning", "the module keyword is gone from namespaces", [
  7.0 rejects `declare module Foo { ... }` inside namespace
  declarations outright, the `module` keyword was the pre-ecmascript
  spelling of `namespace`. Ambient module declarations, `declare
  module "name"`, are unaffected, they describe a real module name.
])

== hand written declarations

A declaration file, `.d.ts`, describes types with no implementation,
and every `@types/node` import in this book is one, pulled in by the
`types` array chapter 11 configured by hand since 7.0 defaults it to
empty. The interesting case is authoring one. When the runtime is
already plain javascript, part one's kind of file, the checker knows
nothing about it until a declaration is placed beside it, and that
declaration is written by hand. The boundary in miniature, three
files:

#listing("javascript/tssamples/ch19/store.mjs", caption: [the plain module, no types anywhere near it])

#listing("javascript/tssamples/ch19/store.d.mts", caption: [the hand written declaration beside it, the checker's whole knowledge of that file])

#listing("javascript/tssamples/ch19/declarations.ts", caption: [a typed consumer, checked against the d.mts, run by node's stripping])

#diagram([the declaration boundary, who reads which file], length: 13pt, {
  cdraw.content((5.5, 8.6), [`store.mjs`], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.8), (10.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.3), [plain runtime, part one's file], size: 6pt)
  cdraw.content((17.5, 8.6), [`store.d.mts`], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.8), (22.6, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.3), [types only, never runs], size: 6pt)
  cdraw.content((5.5, 5.6), [the checker reads the right one], size: 6pt)
  cdraw.line((5.5, 5.2), (5.5, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 3.2), (10.6, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 3.8), [`declarations.ts` checks clean], size: 6pt)
  cdraw.content((17.5, 5.6), [node reads the left one], size: 6pt)
  cdraw.line((17.5, 5.2), (17.5, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.4, 3.2), (22.6, 4.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 3.8), [`StockTitle("b7")` returns], size: 6pt)
  cdraw.content((11.6, 2.0), [`tsc` emits the consumer and neither of the pair], size: 6.5pt)
})

The test runs the consumer under node's own type stripping, where
`./store.mjs` resolves beside it, and the emitted `dist` proves the
asymmetry the diagram claims: the compiled `declarations.js` lands
in `dist`, while neither `store.mjs` nor `store.d.mts` rides the
emit, so a compiled consumer ships with an import that only resolves
beside the sources. The extension math is worth stating exactly:
node maps `.mjs` to the `.d.mts` declaration, `.js` to `.d.ts`, and
`.cjs` to `.d.cts`, and chapter 38's capstone uses this same move,
a hand written `store.d.ts` over a plain `.mjs` store, to type its
persistence layer.

#snippet(
  "// ambient.d.ts, for a dependency with no types of its own\n"
  + "declare module \"legacy-markdown\" {\n"
  + "  export function render(text: string): string;\n"
  + "}\n",
  lang: "ts",
)

For a package rather than a relative file, the ambient `declare
module "name"` block types every import of that name across the
project, which is also what a `@types` package is: a folder of such
files plus a package manifest. Declaration emit, `--declaration`,
runs the other direction and generates a `.d.ts` beside every
emitted file from the sources themselves. It is off by default, and
the suite confirms no `erasure.d.ts` lands in `dist`.

== what emit leaves behind

The audit module reads its own emitted file from `dist` and checks
what the compiler left in and took out, building its search needles
by concatenation so the emitted checker cannot match its own
strings:

#listing("javascript/tssamples/ch19/erasure.ts", first: 10, last: 36, caption: [a module that audits its own compiled output])

#diagram([what emit leaves behind, the struck against the survivor], length: 13pt, {
  cdraw.content((11.6, 10.2), [the audit reads its own compiled output], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 7.2), (10.6, 8.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 8.35), [the source, `erasure.ts`], size: 6pt)
  cdraw.content((5.5, 7.7), [types, interfaces, aliases, generics, #linebreak() modifiers, parameter annotations], size: 6pt)
  cdraw.line((10.6, 8.05), (12.6, 8.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 8.5), [struck], size: 6pt)
  cdraw.rect((13.0, 7.2), (22.8, 8.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.9, 8.35), [the output, `erasure.js`], size: 6pt)
  cdraw.content((17.9, 7.7), [the same calls and the same code, #linebreak() none of the above riding along], size: 6pt)

  cdraw.rect((0.4, 5.8), (22.8, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 6.3), [line counts make the erasure quantitative: source longer than output, always], size: 6pt)
  cdraw.rect((0.4, 4.4), (22.8, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 4.9), [what remains is the enum, real runtime code with a real object], size: 6pt)

  cdraw.rect((0.4, 2.8), (11.2, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 3.35), [`instanceof` asks a class, #linebreak() it exists at runtime], size: 6pt)
  cdraw.rect((11.8, 2.8), (22.8, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 3.35), [never an interface, #linebreak() it erased to nothing], size: 6pt)
  cdraw.content((11.6, 1.7), [the needles built by concatenation, so the emitted checker cannot match its own strings], size: 6.5pt)
})

Types, interfaces, aliases, generics, modifiers, and parameter
annotations all vanish, and the line counts make the erasure
quantitative, source longer than output, always. What remains is the
enum, real code with a real object, because an enum is a runtime
construct wearing type syntax. The same question, which promises
have runtime shape, decides `instanceof`: it walks a prototype
chain, part one's chapter 4 territory, so it can ask a class, which
exists at runtime, and cannot ask an interface, which erased to
nothing:

#listing("javascript/tssamples/ch19/erasure.ts", first: 99, last: 114, caption: [instanceof asks classes, never interfaces])

#snippet(
  "const s: Shaped = new Square();\n"
  + "console.log(s instanceof Shaped);\n"
  + "// error TS2693: 'Shaped' only refers to a type, but is being\n"
  + "// used as a value here.\n",
  lang: "ts",
)

This is why chapter 16's narrowing ladder leans on runtime facts,
`typeof`, `in`, `Array.isArray`, real constructors, and why a shape
that must be distinguished at runtime carries a discriminator or a
brand rather than an interface name.

The one emit behavior that reaches into field declarations: since
the es2022 target, and 7.0's target floor makes it the only behavior
left, class fields install with `Object.defineProperty` semantics
rather than assignment. The sample installs a throwing setter on a
base prototype after declaration, invisible to the checker, then
declares a field over it in a subclass:

#listing("javascript/tssamples/ch19/erasure.ts", first: 116, last: 142, caption: [define semantics: the setter never runs, bare declarations still create properties])

The field lands on the instance without invoking the prototype
setter, which assignment semantics would have called, and even the
bare `declared` field with no initializer creates an own property.
The checker blocks the worst version of the trap outright:
overriding an accessor with a field is error TS2610.

== node's type stripping

Node 26 runs typescript files directly by stripping the erasable
syntax itself, no compiler in the loop. The sample writes a probe
with a `bigint` annotation, executes it with plain `node`, and gets
42. The same treatment rejects the audit module itself, because its
enum is real runtime code:

#listing("javascript/tssamples/ch19/erasure.ts", first: 46, last: 58, caption: [a stripped probe that runs, and the audit module which does not])

#diagram([the strip only subset, and the workflow split], length: 13pt, {
  cdraw.content((5.5, 8.3), [node strips these], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.4), (10.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.5), [annotations, interfaces,], size: 6pt)
  cdraw.content((5.5, 6.9), [generics, modifiers], size: 6pt)

  cdraw.content((17.5, 8.3), [only tsc emits these], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.4), (22.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.5), [enums, namespaces,], size: 6pt)
  cdraw.content((17.5, 6.9), [parameter props, decorators], size: 6pt)

  cdraw.content((5.5, 5.6), [the erasable subset], size: 6.5pt)
  cdraw.rect((0.4, 3.4), (10.6, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 4.6), [run the sources with node,], size: 6pt)
  cdraw.content((5.5, 4.0), [`tsc --noEmit` as checker], size: 6pt)

  cdraw.content((17.5, 5.6), [everything else], size: 6.5pt)
  cdraw.rect((12.4, 3.4), (22.6, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 4.6), [compile first with `tsc`,], size: 6pt)
  cdraw.content((17.5, 4.0), [test the dist output], size: 6pt)

  cdraw.content((11.6, 2.2), [the boundary is the enum: real runtime code node refuses], size: 6.5pt)
})

The rejection names the enum specifically,
`ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX: TypeScript enum is not supported
in strip-only mode`, and parameter properties get the same shaped
diagnostic. Decorators do not even get that: measured on 26.3.0, a
decorated class under stripping dies with a plain `SyntaxError:
Invalid or unexpected token` at the `@`. Node strips, it does not
transform, and there is no transform flag anymore.

#callout("note", "two runtimes, one language", [
  Strip only mode defines a practical subset: if a codebase keeps to
  erasable syntax, it can run its sources directly with node and use
  `tsc --noEmit` as a pure checker, the modern library workflow. The
  moment it needs enum like emit, namespaces, parameter properties,
  or decorators, it must compile first, like this book's typescript
  samples do, and the declaration boundary above is the same trick
  in reverse, plain javascript that never compiles at all.
])

== the emitted companions

With `sourceMap` on, every emitted file grows a `.map` companion
whose `sources` point back at the typescript and whose `mappings`
carry the position translation, which is why the verify script runs
node with `--enable-source-maps` and test failures report source
lines, not dist lines. The suite reads the map for this chapter's
own emitted file and checks both facts. Declaration emit stays off,
so a `.d.ts` is a thing this book writes by hand or reads from
`@types`, never a build artifact, and the plain `store` pair from
the boundary section rides no artifact at all.

#listing("javascript/tssamples/ch19/erasure.ts", first: 60, last: 69, caption: [the sourcemap reader the test asserts against])

#diagram([the emitted companions, what lands in dist beside the javascript], length: 13pt, {
  cdraw.content((11.6, 9.6), [every emitted file grows a companion], size: 6.5pt, fill: luma(100))
  cdraw.content((2.0, 8.7), [dist], size: 6pt)
  cdraw.rect((0.4, 6.6), (22.8, 8.5), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.rect((0.8, 7.0), (8.6, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.7, 7.55), [the emitted `.js`, #linebreak() what node runs], size: 6pt)
  cdraw.rect((9.4, 7.0), (17.2, 8.1), fill: luma(205), radius: 0.02)
  cdraw.content((13.3, 7.55), [its `.map` companion, #linebreak() `sourceMap` writes it], size: 6pt)
  cdraw.rect((18.0, 7.0), (22.6, 8.1), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((20.3, 7.55), [no `.d.ts`, #linebreak() emit off], size: 6pt)

  cdraw.rect((0.4, 5.2), (11.2, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.7), [`sources`: point back #linebreak() at the typescript], size: 6pt)
  cdraw.rect((11.8, 5.2), (22.8, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 5.7), [`mappings`: the position #linebreak() translation], size: 6pt)
  cdraw.rect((0.4, 3.8), (22.8, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 4.3), [`--enable-source-maps`: test failures report source lines, not dist lines], size: 6pt)

  cdraw.content((11.6, 2.7), [a `.d.ts` is written by hand or read from `@types`, never a build artifact], size: 6.5pt)
  cdraw.content((11.6, 1.7), [the plain `store` pair rides no artifact at all], size: 6.5pt)
})

sources: typescriptlang.org handbook modules, namespaces, and
declaration files pages, tsconfig reference for declaration emit and
erasable syntax, nodejs.org esm, import attributes, and type
stripping documentation, accessed 2026-09-13. Behavior verified live
with tsc 7.0.2 and node 26.3.0 on windows, 18 tests in ch19 green
through `npm run verify`, the declaration boundary and the strip
mode probes executed end to end, the TS2693 counterfactual confirmed
by `tsc --noEmit` before being shown as a fragment.
