#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= typing functions

A typescript function is a javascript function: one object, one
`typeof` category, callable, holdable, comparable only by identity,
and every rule about receivers, closures, and recursion is part
one's chapter 3. What the type layer adds is the signature surface:
parameter and return forms, overloads, generics, and the
compatibility rule that decides when one function substitutes for
another. All of it erases, chapter 11 proved that against the emitted
file, so a typescript call site compiles to the same call part one
already runs.

== overloads

Overloads are separate signatures stacked above one implementation.
The implementation signature is invisible to callers, and resolution
takes the first matching overload:

#listing("javascript/tssamples/ch14/typefunctions.ts", first: 7, last: 15, caption: [two overloads, one implementation])

#diagram([the overload stack, two signatures callers see over one body], length: 13pt, {
  cdraw.content((7.0, 8.4), [the stack callers see], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 6.8), (16.0, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((9.0, 7.3), [`(x: number, y: number): Point`], size: 6pt)
  cdraw.content((17.8, 7.3), [overload 1], size: 6pt)
  cdraw.rect((2.0, 5.6), (16.0, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((9.0, 6.1), [`(label: string): Point`], size: 6pt)
  cdraw.content((17.8, 6.1), [overload 2], size: 6pt)
  cdraw.line((9.0, 5.6), (9.0, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.6, 5.2), [resolution takes the first match], size: 6.5pt)
  cdraw.rect((2.0, 3.2), (16.0, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((9.0, 4.15), [`(a: number | string, b?: number)`], size: 6pt)
  cdraw.content((9.0, 3.6), [takes the union of every input], size: 6.5pt)
  cdraw.content((17.8, 3.9), [the body], size: 6pt)
  cdraw.content((11.6, 2.2), [the implementation signature is invisible to callers], size: 6.5pt)
  cdraw.content((11.6, 1.2), [exactly one function exists at runtime], size: 6.5pt)
})

The body has to accept the union of all overload inputs, which is
why the implementation takes `number | string`. Overloads are a
documentation and precision tool, not polymorphism: there is exactly
one function at runtime, and the emitted javascript keeps only the
implementation.

== parameter forms

Optional parameters are `?` suffixed or defaulted, and only one rest
parameter may appear, last. Defaults make their parameter optional
for free, and the rest parameter is a true array:

#listing("javascript/tssamples/ch14/typefunctions.ts", first: 17, last: 19, caption: [default and rest parameters])

#diagram([the arity table, what each parameter form asks of the caller], length: 13pt, {
  cdraw.content((4.4, 7.1), [form], size: 6.5pt, fill: luma(100))
  cdraw.content((11.8, 7.1), [optionality], size: 6.5pt, fill: luma(100))
  cdraw.content((18.9, 7.1), [what arrives], size: 6.5pt, fill: luma(100))

  let row(y, f, o, a, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.4, y + 0.7), f, size: 6pt)
    cdraw.content((11.8, y + 0.7), o, size: 6pt)
    cdraw.content((18.9, y + 0.7), a, size: 6pt)
  }
  row(5.4, [`name: string`], [required], [the argument itself], false)
  row(3.6, [`greeting = "hello"`], [optional for free], [the default, filled in], true)
  row(1.8, [`...punct: string[]`], [one, and last], [a true array], false)

  for x in (8.6, 15.0) { cdraw.line((x, 1.8), (x, 6.8), stroke: luma(220)) }
  cdraw.content((11.6, 0.8), [the `?` marks a parameter optional, a default marks and fills it], size: 6.5pt)
})

== generics with constraints

Type parameters may be constrained to a structural shape, and the
constraint is what lets the body read `item.size` at all. Inference
from the argument list means callers never spell the parameter out:

#listing("javascript/tssamples/ch14/typefunctions.ts", first: 21, last: 38, caption: [a constrained generic, a plain one returning a tuple, and composition in three parameters])

#flow(
  [the inference path, constraint to licensed member access],
  node((0, 0), [arguments flow in]),
  node((3, 0), [`T extends` #linebreak() `{ size: number }`]),
  node((6, 0), [`item.size` legal, #linebreak() licensed by it]),
  node((0, 2.4), [any `T` at all]),
  node((3, 2.4), [no member access]),
  node((6, 2.4), [returns `[T, T]`]),
  edge((0, 0), (3, 0), "-|>", label: [inference]),
  edge((3, 0), (6, 0), "-|>"),
  edge((0, 2.4), (3, 2.4), "-|>"),
  edge((3, 2.4), (6, 2.4), "-|>"),
)

Contextual typing runs the other direction: annotate the variable
with the function type and the lambdas inside infer their
parameters, which is how a table of operations stays typed without a
single parameter annotation in sight:

#listing("javascript/tssamples/ch14/typefunctions.ts", first: 40, last: 46, caption: [parameters inferred from the contextual type])

== function type compatibility

The checker compares function types by three rules, and the three
demos below each compile one legal direction and leave the illegal
reverse to a fragment. Arity: fewer parameters than expected is
fine, the function ignores the rest, while more parameters than
expected does not compile. Returns: a narrower return type
substitutes where a wider one is expected. Parameters: under the
strict function type checking 7.0 defaults to, a function accepting
a wider parameter substitutes where a narrower one is expected,
which is contravariance, the same direction as chapter 13's
assignability arrows read backwards:

#listing("javascript/tssamples/ch14/typefunctions.ts", first: 48, last: 69, caption: [arity, return covariance, and parameter contravariance, all three compiling])

#diagram([the three compatibility rules, each one way], length: 13pt, {
  cdraw.content((6.4, 8.0), [rule], size: 6.5pt, fill: luma(100))
  cdraw.content((16.4, 8.0), [the legal direction], size: 6.5pt, fill: luma(100))

  let row(y, r, d, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((6.4, y + 0.7), r, size: 6pt)
    cdraw.content((16.4, y + 0.7), d, size: 6pt)
  }
  row(6.2, [arity], [fewer parameters where more expected], false)
  row(4.4, [returns], [narrower where wider expected, covariant], true)
  row(2.6, [parameters], [wider accepted where narrower expected, contravariant], false)

  cdraw.line((11.6, 2.6), (11.6, 7.6), stroke: luma(220))
  cdraw.content((11.6, 1.2), [every reverse direction is a compile error, not a runtime one], size: 6.5pt)
})

#snippet(
  "const more: (a: number) => number = (a: number, b: number) => a + b;\n"
  + "// error TS2322: type '(a: number, b: number) => number' is not\n"
  + "// assignable to type '(a: number) => number'\n",
  lang: "ts",
)

== the checked this

One piece of the receiver story belongs to the signature: a `this`
parameter, checked like any other. `this: void` documents that a
function reads no receiver at all, and the checker then rejects any
`this` access inside its body, so a free function cannot silently
grow dependent on a call site. The runtime rules of `this`, method
calls, detached calls throwing in a module, `bind`, lexical arrows,
are part one's chapter 3:

#listing("javascript/tssamples/ch14/typefunctions.ts", first: 71, last: 75, caption: [a this void signature, callable as a free function])

#diagram([the checked this, a written promise the checker enforces], length: 13pt, {
  cdraw.content((11.6, 10.2), [this: void, the written promise], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 8.4), (10.6, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 9.0), [`ThisFree(this: void, x: number)`], size: 6pt)
  cdraw.content((5.5, 8.7), [the function reads no receiver at all], size: 6pt)
  cdraw.line((5.5, 8.4), (5.5, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 6.4), (10.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.5, 7.0), [any `this` access inside its body?], size: 6pt)

  cdraw.line((2.9, 6.4), (2.9, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.7, 6.0), [yes], size: 6pt)
  cdraw.rect((0.4, 4.4), (10.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.0), [rejected by the checker, #linebreak() the compile fails], size: 6pt)
  cdraw.line((8.1, 6.4), (8.1, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.3, 6.0), [no], size: 6pt)
  cdraw.rect((11.2, 4.4), (22.8, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.0, 5.0), [compiles, callable #linebreak() as a free function], size: 6pt)
  cdraw.line((10.6, 5.0), (11.2, 5.0), stroke: luma(100), mark: (end: ">"))

  cdraw.rect((0.4, 2.8), (22.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.3), [a free function cannot silently grow dependent on a call site], size: 6pt)
  cdraw.content((11.6, 1.6), [the runtime rules of the receiver, method calls, detached calls throwing in a module, #linebreak() `bind`, lexical arrows, are part one's chapter 3], size: 6.5pt)
})

#callout("note", "what moved out of this chapter", [
  The old functions chapter demonstrated receivers, closures, and
  hoisting at runtime. All of that is part one's chapter 3 now,
  typed samples included, and the suite cases that pinned it went
  with them. What stays here is the signature layer: overloads,
  parameter forms, generics, compatibility, and the checked `this`.
])

sources: typescriptlang.org handbook more on functions and
typescript handbook function compatibility, accessed 2026-09-13.
Behavior verified live with tsc 7.0.2 and node 26.3.0 on windows,
10 tests in ch14 green through `npm run verify`, the arity
counterfactual confirmed by `tsc --noEmit` before being shown as a
fragment.
