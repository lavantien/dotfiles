#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= type-level programming

Everything before this chapter ran types alongside values. This
chapter runs types alone: querying them, transforming them, and
computing new ones from old, all erased to nothing at emit. The
split is the discipline of the whole subject. A type-level construct
is a function the checker evaluates between parsing and emit, its
inputs and outputs are types, and it cannot read a value, call a
function, or branch on anything the program did. So every construct
below keeps a runtime companion beside it, `keyof Book` beside
`Object.keys`, a recursive conditional beside a loop, because a type
utility nobody can call is a page of prose, not a tool.

== querying types

`keyof T` is the union of member names, `T[K]` is the member type at
`K`, and `typeof value` lifts a value into the type world. The
generic `GetField` uses indexed access with a constrained key, so
reading `title` types as `string` and reading `pages` types as
`number | undefined`, one function, per member precision:

#listing("javascript/tssamples/ch17/typelevel.ts", first: 4, last: 16, caption: [keyof and indexed access against one interface])

#diagram([keyof, indexed access, and typeof against one interface], length: 13pt, {
  cdraw.content((16.0, 9.1), [one interface, three queries], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 4.9), (9.4, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 7.5), [`readonly isbn: string`], size: 6pt)
  cdraw.content((4.9, 6.5), [`title: string`], size: 6pt)
  cdraw.content((4.9, 5.5), [`pages?: number`], size: 6pt)
  cdraw.content((4.9, 4.4), [`Book`], size: 6.5pt, fill: luma(100))
  cdraw.line((9.4, 7.5), (11.0, 7.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 6.5), (11.0, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 5.5), (11.0, 3.6), stroke: luma(100), mark: (end: ">"))

  let chip(y, t) = {
    cdraw.rect((11.2, y), (22.6, y + 1.9), fill: luma(205), radius: 0.02)
    cdraw.content((16.9, y + 0.95), t, size: 6pt)
  }
  chip(6.6, [`keyof Book` #linebreak() `"isbn" | "title" | "pages"`])
  chip(4.6, [`Book["pages"]` #linebreak() `number | undefined`])
  chip(2.6, [`typeof value` #linebreak() the value's own shape, as a type])
  cdraw.content((11.6, 1.8), [`GetField(b, "title")` is `string`, `"pages"` adds `| undefined`], size: 6.5pt)
})

The pairing in `KeysOf` is the honest one: `Object.keys` returns
`string[]` at runtime, because javascript has no type to consult,
and the cast back to `(keyof Book)[]` marks exactly where the
checker's knowledge ends. That cast is the seam of the whole
chapter, and it appears in every companion below.

== mapped types

A mapped type iterates the members of `T` and rebuilds them, and the
`as` clause remaps names while iterating. `Getters` renames every
member `m` to `getM` through the `Capitalize` intrinsic, and the
runtime companion builds the matching object, key by key:

#listing("javascript/tssamples/ch17/typelevel.ts", first: 18, last: 32, caption: [a homomorphic mapped type with key remapping, and its builder])

#diagram([the mapped type pipeline, rebuild and rename every member], length: 13pt, {
  cdraw.content((4.9, 7.6), [the members of `T`], size: 6.5pt)
  let inchip(x, t) = {
    cdraw.rect((x, 6.2), (x + 2.8, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.4, 6.7), t, size: 6pt)
  }
  inchip(0.6, [`isbn`])
  inchip(4.0, [`title`])
  inchip(7.4, [`pages`])
  cdraw.content((5.4, 5.6), [optionality and readonly copy along], size: 6pt)
  cdraw.line((10.6, 6.7), (12.0, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.2, 4.85), (22.6, 8.95), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 6.9), [rename through #linebreak() `get${Capitalize<K>}` #linebreak() rebuild each value #linebreak() as `(): T[K]`], size: 6pt)
  cdraw.line((13.2, 4.85), (10.2, 4.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.9, 4.9), [the rebuilt members], size: 6.5pt)
  let outchip(x, t) = {
    cdraw.rect((x, 3.2), (x + 3.4, 4.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.7, 3.7), t, size: 6pt)
  }
  outchip(0.6, [`getIsbn`])
  outchip(4.6, [`getTitle`])
  outchip(8.6, [`getPages`])
  cdraw.rect((0.4, 1.4), (13.4, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((6.9, 2.0), [`Partial<T> = { [K in keyof T]?: T[K] }`], size: 6pt)
  cdraw.content((18.4, 2.0), [one line of the same shape], size: 6.5pt)
})

Homomorphic mapped types copy modifiers, optionality and readonly,
from the source, which is why `Partial<T>` in the library is one
line of this shape, `{ [K in keyof T]?: T[K] }`, and the sample's
`MakePartial` is its runtime shadow. Chapter 20 deepens the same
move into a recursive `DeepReadonly` walking a frozen value.

== conditional types, infer, and recursion

The conditional type is a type-level ternary, and `infer` names a
position inside the matched branch. The recursive `Unwrap` peels
arrays until a non array remains, `[[5]]` unwrapping to `5`, and the
runtime `Flat` loop does the same walk over values:

#listing("javascript/tssamples/ch17/typelevel.ts", first: 34, last: 41, caption: [a recursive conditional with infer])

#flow(
  [the conditional type as routing, arrays peeled until they are not],
  node((0, 0), [`T` enters]),
  node((3.2, 0), [`T extends readonly unknown[]`]),
  node((6.4, 0), [yes: the element position, #linebreak() peel and recurse]),
  node((3.2, 2.2), [no: `T` itself, done]),
  node((6.4, 2.2), [the runtime `Flat` walks #linebreak() the same shape]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((3.2, 0), (6.4, 0), "-|>", label: [`T[number]`]),
  edge((3.2, 0), (3.2, 2.2), "-|>", label: [not an array]),
  edge((3.2, 2.2), (6.4, 2.2), "-|>"),
)

A type alias may reference itself, but only through a deferring
position, an object member or an array element, so the checker
always has a smaller problem to solve before it needs the
definition again. `Unwrap` defers through `T[number]`, and recursion
plus `infer` is how the standard library writes its hardest utilities:
`ReturnType<F>` infers a function's return, `Parameters<F>` its
parameter tuple, and `Awaited<T>` is a recursive conditional that
follows `then` chains of unknown depth to the value a promise
eventually delivers.

== template literal types

Template literal types compose strings at the type level. `Endpoint`
below is four strings exactly, `"db.dev"` through `"web.prod"`, and a
parameter of that type rejects every fifth. Patterns may embed
`${string}` or `${number}` holes:

#listing("javascript/tssamples/ch17/typelevel.ts", first: 43, last: 49, caption: [a domain composed from two unions])

#diagram([a cross product of unions, and the 7.0 code point fix], length: 13pt, {
  // the cross product: services against environments
  cdraw.content((6.2, 8.6), [the cross product], size: 6.5pt, fill: luma(100))
  cdraw.content((2.0, 6.7), [`"db"`], size: 6pt)
  cdraw.content((2.0, 5.5), [`"web"`], size: 6pt)
  cdraw.content((4.6, 7.7), [`"dev"`], size: 6pt)
  cdraw.content((7.8, 7.7), [`"prod"`], size: 6pt)
  let cell(x, y, t, dark) = {
    cdraw.rect((x, y), (x + 2.8, y + 1.0), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.4, y + 0.5), t, size: 6pt)
  }
  cell(3.2, 6.2, [`db.dev`], false)
  cell(6.4, 6.2, [`db.prod`], true)
  cell(3.2, 5.0, [`web.dev`], true)
  cell(6.4, 5.0, [`web.prod`], false)
  cdraw.content((5.2, 4.0), [four endpoints exactly, a fifth rejected], size: 6.5pt)

  // the 7.0 fix, before and after
  cdraw.content((17.4, 8.6), [the 7.0 fix], size: 6.5pt, fill: luma(100))
  cdraw.content((12.8, 7.7), [6.x], size: 6pt)
  cdraw.rect((14.4, 7.2), (22.6, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.5, 7.7), [split the surrogate pair], size: 6pt)
  cdraw.content((12.8, 5.85), [7.0], size: 6pt)
  cdraw.rect((14.4, 4.9), (22.6, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((18.5, 5.85), [the whole emoji, #linebreak() code point aware], size: 6pt)
  cdraw.content((18.3, 4.1), [runtime `[...text][0]` agrees since 7.0], size: 6.5pt)
})

#callout("note", "7.0 makes template inference code point aware", [
  In 6.x, `Head<"😀abc">` split the emoji's surrogate pair, yielding
  a broken half character. The native compiler preserves unicode
  code points, so the head of `"😀abc"` is `"😀"`. The runtime
  companion iterates code points through the string iterator,
  `[...text][0]`, which has agreed with the type system only since
  this release. The book's test pins both sides.
])

== variadic tuples and the library operators

The variadic tuple type splices arrays inside another tuple type,
`[...A, ...B]`, so `Concat` can promise the exact length and element
order of its result. `PickKeys` pairs the library's `Pick` with the
loop that copies the members, and `CapName` wraps the `Capitalize`
intrinsic the mapped type already used:

#listing("javascript/tssamples/ch17/typelevel.ts", first: 58, last: 77, caption: [variadic splice, Pick, and an intrinsic wrapper])

`Pick` and its siblings `Omit`, `Record`, `Readonly`, `Required`,
`Exclude`, and `Extract` are all built from the operators of this
chapter. Two close cousins live one chapter ahead, because they are
idioms rather than operators: `satisfies` checks a value against a
contract without widening it, and a `const` type parameter keeps a
literal's precision through a call, both chapter 20's.

#diagram([the type level against the value level, four pairs from this chapter], length: 13pt, {
  cdraw.content((5.5, 8.5), [type level, erased], size: 6.5pt, fill: luma(100))
  cdraw.content((17.2, 8.5), [value level, running], size: 6.5pt, fill: luma(100))
  let row(y, t, v, dark) = {
    cdraw.rect((0.4, y), (10.6, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.5, y + 0.7), t, size: 6pt)
    cdraw.rect((12.0, y), (22.6, y + 1.4), fill: if dark { luma(235) } else { luma(205) }, radius: 0.02)
    cdraw.content((17.3, y + 0.7), v, size: 6pt)
  }
  row(6.6, [`keyof Book`], [`Object.keys`, then a cast], false)
  row(4.8, [`Getters<T>`], [`BuildGetters`, key by key], true)
  row(3.0, [`Unwrap<T>`], [`Flat`, one loop], false)
  row(1.2, [`Endpoint`, the template], [`EnvOf`, one split], true)
  cdraw.content((11.6, 0.2), [the cast in each companion marks where the checker's knowledge ends], size: 6.5pt)
})

The pairs are the chapter's whole claim. The left column is
computation over types, finished before any code runs, and the right
column is ordinary javascript from part one, correct on its own.
The checker is the only thing that ever connects them, which is why
the seam always shows up as a cast, and why a wrong promise on the
left is caught at the boundary call site or not at all.

sources: typescriptlang.org handbook 2, mapped types, conditional
types, and template literal types pages, devblogs.microsoft.com
typescript 7.0 announcement for the unicode inference change,
accessed 2026-09-13. Behavior verified live with tsc 7.0.2 and node
26.3.0 on windows, 10 tests in ch17 green through `npm run verify`.
