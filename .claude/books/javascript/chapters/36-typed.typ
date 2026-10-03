#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the typed layer

The service part has run for 13 chapters on plain `.mjs`, and this
chapter runs it again in TypeScript without forking a single decision.
The vehicle is one package: `src/` stays the teaching spine every
chapter before this one pinned, `src-ts/` is the same vehicle
re-expressed, and the two trees share one contract directory, one set
of frozen vectors, and one lockfile. Nothing about the wire changes.
The typed layer is the lesson, the same lesson the `f#` tour taught
over its `c#` artifacts: a second notation over the first, never a
second service.

== one vehicle, two languages

Node 26.3.0 runs `.ts` sources natively. The probe is one property
read off the process itself, `process.features.typescript`, and it
answers `"strip"` on this machine: the runtime parses type syntax and
erases it, no emit step, no loader flag, no build watcher between
saving a file and running it. The probe is a committed test, so the
mechanism is pinned the way every other platform fact in this book is
pinned, by an assertion that runs. The stripping mode also draws the
one hard line the sources obey: only erasable syntax is allowed, no
enums, no namespaces, no parameter properties, and chapter 35's ruling
that the suite owns no compiler step stays intact because there is no
step to own.

The compiler still matters, so TypeScript rides along as the package's
one devDependency, pinned at 7.0.2 and lockfile-committed the way the
`c#` lane pins xunit: a toolchain dependency, never a module graph
dependency. Nothing in `src-ts/` imports from `typescript`. The verify
script states the whole arrangement in three legs, the js suite over
`src/`, the ts suite over `src-ts/`, and `tsc --noEmit` over the
typed trees, and every commit of this wave ran all three.

The composition mirrors with the same discipline. `src-ts/server.ts`
holds the same one-writer shape chapter 23 pinned, one import and one
wire call per family at its chapter slot, the store constructed first
for the single-store ruling, the operations layers mounted
position-aware, the keyed runner built over the store's idem adapter.
A reader who knows `src/server.mjs` can diff the two files line for
line and find only the type annotations, which is the point: the typed
layer claims nothing the spine did not already claim.

#listing("javascript/api/package.json", first: 9, last: 18, caption: [one package, two source trees, one toolchain dependency, three verify legs])

#diagram([two notations, one contract underneath], length: 13pt, {
  let layer(y, title, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  layer(6.6, [src/, the js spine], [#"13 chapters of pinned listings"], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  layer(4.3, [src-ts/, the typed layer], [#"same vehicle, type syntax, stripped at run"], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  layer(2.0, [one contract], [#"16 frozen vectors, the vectors gate both trees"], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  layer(-0.3, [one lockfile], [#"typescript 7.0.2, devDependency, toolchain only"], luma(245))
  pane(14.4, 22.6, 6.6, [the ruling], [the js sources stay], [the teaching spine])
})

== the strict tsconfig

Seventeen lines carry the whole configuration, and every flag in them
paid its way during the port. `strict` turns on the family: no implicit
`any`, no unchecked `null`. `exactOptionalPropertyTypes` refuses to
write `undefined` into an optional member, which is why every deps
bundle in `src-ts/` declares its optionals as `X | undefined` or
restructures, the difference between a member that is absent and one
that is present holding `undefined` is now a stated fact instead of a
silent coercion. `noUncheckedIndexedAccess` reads every index lookup
as possibly absent, so `ctx.params` answers `string | undefined` and
the loop-bounded reads in the router carry the `!` assertion, the
compiler saying out loud that a matched route guarantees presence
while being unable to see the invariant itself.
`verbatimModuleSyntax` forces `import type` for type-only imports, so
what erases at runtime is exactly what says it erases.

The last two flags state the architecture. `erasableSyntaxOnly`
refuses any syntax the stripping runtime cannot erase, the compiler
enforcing the same line the runtime draws, and `allowImportingTsExtensions`
with `noEmit` lets module specifiers name `.ts` files directly, which
is what node's own resolution expects. `types` is the empty array,
no ambient package loads, and the platform surface the sources touch
is declared by hand in the next section's file.

#listing("javascript/api/tsconfig.json", first: 1, last: 17, caption: [the strict line: five families of flags, one erasable-syntax ruling, no ambient packages])

#diagram([each flag buys one stated fact], length: 13pt, {
  let flag(x0, name, gain) = {
    cdraw.rect((x0, 3.6), (x0 + 6.9, 6.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 3.45, 5.5), [#name], size: 6pt)
    cdraw.content((x0 + 3.45, 4.4), [#gain], size: 6pt)
  }
  flag(0.3, [strict], [no implicit any, no silent null])
  flag(7.6, [exactOptionalPropertyTypes], [absent is not present undefined])
  flag(15.0, [noUncheckedIndexedAccess], [every index read may miss])
  flag(0.3 + 11.4, [verbatimModuleSyntax], [type imports say they erase])
  cdraw.line((11.3, 3.4), (11.3, 2.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.5, 0.6), (17.1, 2.5), fill: luma(225), radius: 0.02)
  cdraw.content((11.3, 1.9), [erasableSyntaxOnly], size: 6pt)
  cdraw.content((11.3, 1.0), [the runtime's line, compiler enforced], size: 6pt)
})

== types at the kernel seams

The js chapters kept the context shape implicit, a plain object every
handler happened to agree on. The typed layer names it once, in
`src-ts/kernel/ctx.ts`, and every family that touches a context
imports from that file, all but the cache, whose lru and singleflight
never see one, so kernel, middleware, and handlers cannot drift apart the way js
silently lets them. `Ctx` carries the request, the response, the
params map, the query, the edge-resolved id, and the two members later
layers install, the route label and the stashed body parse, plus the
actor the identity layer resolves. `Handler` and `Layer` are one line
each and the whole middleware discipline of chapter 24 typechecks
against them.

Two seams deserve their own words. `Res` is the minimal writer
contract, the status, the answered flags, the members the envelope,
the access log, and the metrics recorder touch, and the real
`ServerResponse`, the register replay's recording double, and the
suite's `FakeRes` all satisfy it structurally, no inheritance
anywhere. And because no `@types/node` rides in the toolchain ruling,
`env.d.ts` declares the platform surface by hand, exactly the members
the sources import and nothing more, `node:test` with its `mock`
timers, `node:sqlite` with `StatementSync`, the handful of `node:crypto`
primitives, the globals. Every declaration in that file is a seam this
chapter can point at, and the compiler refuses a member nobody
declared, which keeps the surface honest in both directions.

#listing("javascript/api/src-ts/kernel/ctx.ts", first: 35, last: 61, caption: [the seam module: the actor, the context every family builds against, the handler and layer types])

#diagram([one seam module, three consumers, no drift], length: 13pt, {
  let box(x0, y, w, title, l1) = {
    cdraw.rect((x0, y), (x0 + w, y + 1.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, y + 1.05), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, y + 0.35), [#l1], size: 6pt)
  }
  box(0.3, 5.6, 6.0, [kernel], [#"births Ctx at the edge"])
  box(8.3, 5.6, 6.0, [middleware], [#"Layer over Handler, verbatim"])
  box(16.3, 5.6, 6.0, [handlers], [#"read params, actor, body"])
  cdraw.line((3.3, 5.5), (3.3, 4.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.3, 5.5), (11.3, 4.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((19.3, 5.5), (19.3, 4.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.3, 2.8), (17.3, 4.6), fill: luma(225), radius: 0.02)
  cdraw.content((11.3, 4.0), [ctx.ts], size: 6pt)
  cdraw.content((11.3, 3.1), [#"Ctx, Res, Handler, Layer, App, RunKeyed"], size: 6pt)
  cdraw.content((11.3, 1.7), [js kept the shape implicit, ts names it once], size: 6pt)
  cdraw.content((11.3, 0.7), [the doubles satisfy Res structurally, no inheritance], size: 6pt)
})

== the store port as interfaces

Chapter 25 froze the user store port in prose and discipline, two
implementations that happened to agree. The typed layer freezes it in
the compiler. `UserStore` is the interface, the memory store from
chapter 25 and the sqlite adapter from chapter 28 both satisfy it, and
a verb signature that drifts in either tree is a compile error before
it is a bug. `StoreError` narrows its `code` to the four-outcome
union, so the handlers' `mapStoreError` exhausts the arms against a
closed set instead of comparing free strings. `UserRecordInput` is
`UserRecord` without the version, the type stating what the js code
already did, the store stamps the version on the way in and a caller
who claims one is ignored.

The parity property survives unchanged. The seeded loop from chapter
28's tests, splitmix32 at seed `0x12345678`, drives the sqlite adapter
and the memory store through the same op stream and asserts identical
records and identical thrown codes, and the loop runs again in the ts
suite over the ts stores. The port is the oracle because it is the
contract two chapters share, and now the compiler reads the contract
too.

#listing("javascript/api/src-ts/users/store.ts", first: 46, last: 58, caption: [the port as an interface: both stores satisfy it, the compiler holds them to it])

#diagram([two implementations, one interface, one property loop], length: 13pt, {
  let box(x0, y, w, title, l1, fill) = {
    cdraw.rect((x0, y), (x0 + w, y + 1.6), fill: fill, radius: 0.02)
    cdraw.content((x0 + w / 2, y + 1.05), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, y + 0.35), [#l1], size: 6pt)
  }
  box(0.3, 5.2, 7.0, [memory store], [#"maps and keyset order, ch25"], luma(235))
  box(15.0, 5.2, 7.0, [sqlite adapter], [#"stmt, tx, cas, ch28"], luma(235))
  cdraw.line((3.8, 5.1), (3.8, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.5, 5.1), (18.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  box(4.5, 2.6, 13.5, [UserStore], [#"the frozen verbs, satisfied or a compile error"], luma(225))
  cdraw.line((11.3, 2.5), (11.3, 1.7), stroke: luma(100), mark: (end: ">>"))
  box(4.5, 0.0, 13.5, [the parity loop], [#"seed 0x12345678, identical answers"], luma(245))
})

== what the types prove

The honest accounting has two columns. The compiler proves the
internal wiring: a handler registered where a layer belongs is a
compile error, a deps bundle missing its clock is a compile error, a
store without `getByEmail` is a compile error, and the discriminated
unions narrow without casts, the idem lookup answers miss, mismatch,
or match with the snapshot riding only the last arm, and narrowing on
`state` makes the snapshot readable exactly where it exists. Those are
guarantees about the seams, and they hold before any test runs.

The other column is what only the runtime owns, and the port kept
every one of those checks. The strict decode ladder still inspects
the parsed body member by member, because the wire hands over
`unknown` and the type only describes what survived the inspection.
`readJson` still runs the media type, the cap, and the parse, the
cookie reader still validates shape by hand, and `isUuid` still tests
the string, a type can name a uuid but cannot know the runtime
produced one. Where a type would make a js check redundant the check
stayed anyway, commented only when the reason is not obvious, because
the js sources are the spine and the two trees must answer
identically. What the types prove is the wiring. What the vectors
prove, next chapter, is the behavior.

#listing("javascript/api/src-ts/store/idem.ts", first: 10, last: 21, caption: [the outcome union: three states, the snapshot on one arm, narrowed without casts])

#diagram([two columns, both true], length: 13pt, {
  pane(0.3, 10.6, 7.0, [the compiler proves], [seam wiring, arity], [port satisfaction], [union narrowing])
  cdraw.line((10.8, 4.4), (11.6, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.0, [the runtime still owns], [wire bytes and order], [decoded body shape], [timing, uuids, presence])
  cdraw.content((5.4, 1.9), [holds before any test runs], size: 6pt)
  cdraw.content((17.0, 1.9), [holds because the checks stayed], size: 6pt)
  cdraw.content((11.3, 0.8), [the runtime checks survive the port, commented only when non-obvious], size: 6pt)
})

sources: nodejs.org/api/typescript.html for the stripping mode and the
erasable syntax rules, accessed 2026-09-27, devblogs.microsoft.com and
typescriptlang.org for the typescript 7.0.2 release and the
strict-flag family, accessed 2026-09-27. The mechanism facts are the
committed probe on node 26.3.0, `process.features.typescript` with the
value `strip`, 2026-09-27. Verified by the live chain: 317 js tests,
319 ts tests, and `tsc --noEmit` clean in `npm run verify`.
