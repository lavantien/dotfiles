#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= modules and resources

A module is a file with its own scope, evaluated once, exporting
names it chooses. Since 2015 that system is native, and since node
22 it is the runtime's default answer: `.mjs` is always a module,
`.cjs` is always a script, and `.js` follows the package manifest's
`type` field, which the samples project sets to `"module"`. The
second half of the chapter spends the same discipline on resources:
`using` declarations tie a value's release to the end of its block,
the ES2025 answer to `finally` cleanup.

One sentence of scope on the script side: importing a `.cjs` file
yields its `module.exports` as the default export, named imports
from it work only where static analysis finds them on that object,
and `require` of a module is not this book's path.

== the export forms, and live bindings

One module, four ways to publish: a named `const`, a mutable named
`let` with its mutator, and a default, which is just another export
with the special name `default`:

#listing("javascript/samples/src/ch07-shapes.mjs", caption: [the exporter: a constant, a live let, a function, a default])

#diagram([the exporter's bindings, and the importer's live views], length: 13pt, {
  cdraw.content((11.6, 10.2), [four ways to publish, the import a view not a copy], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.6, 5.0), (11.0, 9.4), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((5.8, 8.95), [the exporter], size: 6pt)
  cdraw.rect((1.0, 7.9), (10.6, 8.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 8.3), [`export const answer`], size: 6pt)
  cdraw.rect((1.0, 6.8), (10.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 7.2), [`export let tally`, moved by `bump`], size: 6pt)
  cdraw.rect((1.0, 5.7), (10.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.1), [`export function fn`], size: 6pt)
  cdraw.rect((1.0, 5.1), (10.6, 5.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.3), [`export default`], size: 6pt)
  cdraw.rect((13.0, 5.0), (22.8, 9.4), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((17.9, 8.95), [the importer], size: 6pt)
  cdraw.rect((13.4, 7.9), (22.4, 8.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 8.3), [`import { answer }`], size: 6pt)
  cdraw.rect((13.4, 6.8), (22.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.9, 7.2), [`import { tally }`], size: 6pt)
  cdraw.rect((13.4, 5.7), (22.4, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 6.1), [`import fn from`, the name `default`], size: 6pt)
  cdraw.line((13.4, 7.2), (10.6, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.0, 7.5), [live], size: 6pt)
  cdraw.rect((0.4, 3.2), (22.8, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.85), [`bump` moves the exporter's `tally`, every importer's view moves with it, #linebreak() no reimport anywhere, the view is not a copy], size: 6pt)
  cdraw.rect((0.4, 1.6), (22.8, 2.9), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 2.25), [a re-export, `export { x } from "./other.mjs"`: #linebreak() another module's binding published under a local name], size: 6pt)
  cdraw.content((11.6, 0.7), [the default is just another export, its special name `default`], size: 6.5pt)
})

The consumer picks names with braces and the default without. Named
imports are live views of the exporter's bindings, not copies, which
is the part that surprises programmers from other languages: `bump`
moves the exporter's `tally`, and every importer's view of `tally`
moves with it, no reimport anywhere. A re-export publishes another
module's binding under a local name:

#listing("javascript/samples/src/ch07-modules.mjs", first: 7, last: 24, caption: [named and default imports, a live view, a re-export])

== dynamic import

`import()` is an expression that returns a promise of the module
namespace, evaluates the module on first call, and returns the same
namespace object on every later call, one instance per specifier per
process. It is how code loads on demand, and how a module that might
fail can be wrapped in a normal `try`:

#listing("javascript/samples/src/ch07-modules.mjs", first: 32, last: 43, caption: [two dynamic imports of one specifier, one namespace object])

#diagram([the dynamic import, one namespace per specifier], length: 13pt, {
  cdraw.content((11.6, 10.0), [an expression, one instance per specifier per process], size: 6.5pt, fill: luma(100))
  cdraw.rect((8.0, 8.6), (15.2, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 9.1), [`import("...")`, an expression], size: 6pt)
  cdraw.line((11.6, 8.6), (11.6, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 6.6), (15.6, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 7.2), [the first call for this specifier?], size: 6pt)
  cdraw.line((7.6, 7.2), (4.3, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.6, 7.5), [yes], size: 6pt)
  cdraw.rect((0.8, 4.8), (7.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.3, 5.4), [the module evaluates, #linebreak() once, on demand], size: 6pt)
  cdraw.line((15.6, 7.2), (18.6, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.5, 7.5), [no], size: 6pt)
  cdraw.rect((15.4, 4.8), (22.4, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((18.9, 5.4), [nothing re-evaluates], size: 6pt)
  cdraw.line((4.3, 4.8), (6.2, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.9, 4.8), (17.0, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.2, 2.7), (17.0, 3.9), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.3), [the same namespace object, #linebreak() every later call], size: 6pt)
  cdraw.line((11.6, 2.7), (11.6, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.6, 0.8), (18.6, 2.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 1.4), [a promise of the namespace, a module that #linebreak() might fail: wrappable in an ordinary `try`], size: 6pt)
})

== json modules and import attributes

A JSON module's whole document arrives as its default export, and
the `with` clause is what admits it. The attribute exists because
file extensions are not a security boundary: without the declaration
of intent, node refuses the import, and the refusal message says
exactly what is missing:

#listing("javascript/samples/src/ch07-modules.mjs", first: 26, last: 30, caption: [a json module, imported with its type attribute])

#diagram([the with clause, declared intent against the refusal], length: 13pt, {
  cdraw.content((5.5, 8.4), [without the clause], size: 6.5pt, fill: luma(100))
  cdraw.content((17.5, 8.4), [with declared intent], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.8), (10.6, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.35), [`import data from "./x.json"`], size: 6pt)
  cdraw.rect((12.4, 6.8), (22.6, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.35), [`with { type: "json" }`], size: 6pt)
  cdraw.rect((0.4, 5.4), (10.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.95), [node refuses the import], size: 6pt)
  cdraw.rect((12.4, 5.4), (22.6, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.95), [the import admitted], size: 6pt)
  cdraw.rect((0.4, 4.0), (10.6, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 4.55), [the refusal names #linebreak() the required attribute], size: 6pt)
  cdraw.rect((12.4, 4.0), (22.6, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 4.55), [the whole document #linebreak() as the default export], size: 6pt)
  cdraw.rect((4.0, 2.2), (19.2, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.8), [file extensions are not a security boundary, #linebreak() the clause is the declaration of intent], size: 6pt)
  cdraw.content((11.6, 1.2), [the legacy `assert` keyword: a `TypeError` on this runtime, stage 4 with es2025], size: 6.5pt)
})

Two adjacent facts the tests pin. Dropping the `with` clause rejects
the import with a message naming the required attribute, and the
legacy `assert` keyword that carried this job before ES2025 is gone
on this runtime, it throws a `TypeError`. Import attributes reached
stage 4 with the ES2025 edition.

== import.meta and module relative paths

Inside a module, `import.meta` carries the module's own url, and
node adds `dirname` and `filename`. `fileURLToPath` converts to a
native path, and the `node:path` functions build on it, which is the
portable recipe for "a file next to this module", posix and windows
alike:

#listing("javascript/samples/src/ch07-modules.mjs", first: 45, last: 56, caption: [url, dirname, and a sibling resolved two equivalent ways])

#diagram([the module's own address, made native], length: 13pt, {
  cdraw.content((11.6, 9.8), [the portable recipe for a file next to this module], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 8.0), (19.6, 9.1), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 8.55), [`import.meta.url`, node adds `dirname`, `filename`], size: 6pt)
  cdraw.content((21.0, 8.55), [own url], size: 6pt)
  cdraw.line((10.8, 8.0), (10.8, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.0, 6.2), (19.6, 7.3), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 6.75), [`fileURLToPath`, url to a native path], size: 6pt)
  cdraw.content((21.0, 6.75), [converts], size: 6pt)
  cdraw.line((10.8, 6.2), (10.8, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.0, 4.4), (19.6, 5.5), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 4.95), [`node:path` builds on it], size: 6pt)
  cdraw.content((21.0, 4.95), [portable], size: 6pt)
  cdraw.rect((0.4, 2.6), (11.2, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 3.2), [the `node:` prefix: a dependency named `path` #linebreak() can never shadow the real one], size: 6pt)
  cdraw.rect((11.8, 2.6), (22.8, 3.8), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 3.2), [`#` subpath imports: package private names, #linebreak() only the package's own modules], size: 6pt)
  cdraw.content((11.6, 1.5), [posix and windows alike], size: 6.5pt)
})

The same `node:` prefix that marks those two builtins marks all of
them, `node:url`, `node:path`, `node:util`, and it exists so that a
project dependency named `path` can never shadow the real one. The
package manifest can also define private subpath imports, names
beginning with `#` that only the package's own modules can use:

#snippet(
  "// package.json\n"
  + "{\n"
  + "  \"imports\": {\n"
  + "    \"#cfg\": \"./src/config.mjs\",\n"
  + "    \"#internal/*\": \"./src/internal/*.mjs\"\n"
  + "  }\n"
  + "}\n"
  + "\n"
  + "// any module in the package\n"
  + "import { answer } from \"#cfg\";\n"
  + "import { hidden } from \"#internal/lib\";\n",
  lang: "javascript")

Subpath imports were measured on this node, in a scratch package
with exactly that manifest: both specifiers resolve, and the samples
project keeps a minimal manifest instead, so chapter 1's manifest
listing stays as it was.

== explicit resource management

`Symbol.dispose` marks a value as releasable. A `using` declaration
binds one and runs its disposer at the closing brace, in reverse
declaration order, on the normal path and the throw path alike, and
a `null` or `undefined` binding disposes nothing. With `await using`
and `Symbol.asyncDispose`, the block waits for the release:

#listing("javascript/samples/src/ch07-modules.mjs", first: 58, last: 86, caption: [using: reverse order, the throw path still disposes, null allowed])

#listing("javascript/samples/src/ch07-modules.mjs", first: 88, last: 107, caption: [await using: an async connection opened, used, awaited closed])

#diagram([the block scope as a resource scope], length: 13pt, {
  cdraw.content((11.6, 9.0), [the brace is the finally], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.6, 7.0), (6.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.4, 7.6), [`using a`], size: 6pt)
  cdraw.line((6.2, 7.6), (6.8, 7.6), stroke: luma(100))
  cdraw.rect((7.0, 7.0), (12.6, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 7.6), [`using b`], size: 6pt)
  cdraw.line((12.6, 7.6), (13.2, 7.6), stroke: luma(100))
  cdraw.rect((13.4, 7.0), (19.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((16.2, 7.6), [the body runs], size: 6pt)
  cdraw.line((19.0, 7.6), (19.6, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((19.8, 7.0), (22.6, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((21.2, 7.6), [the closing brace], size: 6pt)

  cdraw.content((3.4, 6.2), [declared first], size: 6pt)
  cdraw.content((9.8, 6.2), [declared second], size: 6pt)
  cdraw.line((9.8, 6.8), (9.8, 6.5), stroke: luma(150))
  cdraw.line((3.4, 6.8), (3.4, 6.5), stroke: luma(150))

  cdraw.rect((0.6, 4.2), (22.6, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.8), [at the brace: b disposed, then a, throw or not], size: 6pt)
  cdraw.line((11.6, 5.4), (11.6, 6.4), stroke: luma(100), mark: (end: ">"))

  cdraw.rect((0.6, 2.0), (11.0, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 2.7), [`await using` + `Symbol.asyncDispose`, #linebreak() the block awaits the release], size: 6pt)
  cdraw.rect((12.0, 2.0), (22.6, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 2.7), [`DisposableStack`: #linebreak() the pile, run last in first out], size: 6pt)
  cdraw.content((11.6, 0.9), [the ES2025 edition shipped all of it, measured live here], size: 6.5pt)
})

`DisposableStack` is the imperative form, a pile of disposers run
last in first out, `defer` pushes a function, `use` pushes a
disposable, `adopt` pairs an arbitrary value with a disposer, and
`move` hands the whole pile to a fresh stack:

#listing("javascript/samples/src/ch07-modules.mjs", first: 109, last: 125, caption: [defer, use, adopt, dispose, exactly once])

The using declaration form belongs to the common case, one function,
one scope, one resource. The stack belongs to code that assembles
resources dynamically, the way a server builds a request's cleanup
list as it goes.

sources: developer.mozilla.org on modules, import attributes, and
symbol.dispose, nodejs.org esm documentation and api for url, path,
and util, tc39.es explicit resource management and import attributes
clauses, accessed 2026-09-13. Behavior verified live with node
v26.3.0 on windows, 97 tests green through `npm run verify` in
`javascript/samples`, 11 of them this chapter's.
