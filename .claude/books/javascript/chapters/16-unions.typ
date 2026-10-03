#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= unions and narrowing

A union type lists the shapes a value may take, and narrowing is how
the language lets you use one. Nothing here is new machinery at
runtime: the guards are part one's own operators, `typeof` from
chapter 2, `instanceof` from chapter 4, and a switch is a switch. The checker's whole contribution is bookkeeping, remembering
what each branch proved and applying it to the types inside that
branch. The discriminator pattern, one literal member shared by
every arm of the union, is the central data modeling tool of
typescript, and the closest cousin elsewhere in this corpus is
#xref-to("csharp-net", "patterns"), where a closed set of shapes is
matched over a class hierarchy instead:

#listing("javascript/tssamples/ch16/unions.ts", first: 7, last: 10, caption: [a discriminated union of three shapes])

Inside a `switch` over the discriminator, each case body sees the
exact member, `s.r` in the circle arm, `s.w` and `s.h` in the rect
arm, with no casts anywhere. The default arm is where the language
pays out its strongest guarantee: after every case, `s` has type
`never`, and assigning it to a `never` variable compiles. Add a
fourth shape to the union and that one line stops compiling, which
converts every forgotten switch in the codebase into a build error:

#listing("javascript/tssamples/ch16/unions.ts", first: 12, last: 28, caption: [the exhaustive switch, with its never default])

#diagram([the exhaustive switch over three tagged shapes], length: 13pt, {
  cdraw.content((11.6, 8.8), [three tagged shapes, one discriminator], size: 6.5pt, fill: luma(100))
  let shape(x, kind, members) = {
    cdraw.rect((x, 6.4), (x + 6.6, 8.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.3, 7.25), kind + [ #linebreak() ] + members, size: 6pt)
  }
  shape(0.5, [`kind: "circle"`], [`r: number`])
  shape(8.0, [`kind: "rect"`], [`w, h: number`])
  shape(15.5, [`kind: "triangle"`], [`base, height`])
  for x in (3.8, 11.3, 18.8) { cdraw.line((x, 6.4), (x, 5.8), stroke: luma(100), mark: (end: ">")) }
  let arm(x, t) = {
    cdraw.rect((x, 4.6), (x + 6.6, 5.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.3, 5.2), t, size: 6pt)
  }
  arm(0.5, [the arm sees `s.r`])
  arm(8.0, [the arm sees `s.w`])
  arm(15.5, [the arm sees `s.base`])
  cdraw.line((11.6, 4.6), (11.6, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.5, 2.8), (22.1, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.3, 3.4), [`default`: `s` is `never`, the assignment compiles], size: 6pt)
  cdraw.content((11.6, 1.8), [add a fourth shape and that line is the build error], size: 6.5pt)
  cdraw.content((11.6, 0.6), [every forgotten switch fails the build at its own line], size: 6.5pt)
})

The runtime half is honest too: the test smuggles a fake `hexagon`
member in through a double cast, and the default throws, so even a
lie stays inside the guarded arm. The emitted switch is the same
switch part one runs, with no injected checks.

== built in guards

`typeof` narrows to the primitive categories, `Array.isArray` to
arrays, `in` to members, and `instanceof` down class lines. `in`
asks own or inherited anywhere on the chain, and throws on a
primitive right side. The `instanceof` chain must run most specific
first, since `SyntaxError` and `TypeError` are both `Error`
subclasses and the supertype test would swallow them, a runtime fact
part one's chapter 4 established when it walked the prototype chain:

#listing("javascript/tssamples/ch16/unions.ts", first: 30, last: 48, caption: [typeof, in, and instanceof narrowing])

#flow(
  [the guard ladder, four ways to narrow one value],
  node((0, 0), [`typeof x`]),
  node((3.4, 0), [the primitive categories]),
  node((0, 1.5), [`Array.isArray(x)`]),
  node((3.4, 1.5), [arrays, whatever the mix]),
  node((0, 3.0), [`"fly" in p`]),
  node((3.4, 3.0), [which member exists]),
  node((0, 4.5), [`instanceof`]),
  node((3.4, 4.5), [class lines, specific first: #linebreak() `SyntaxError` before `Error`]),
  edge((0, 0), (3.4, 0), "-|>"),
  edge((0, 1.5), (3.4, 1.5), "-|>"),
  edge((0, 3.0), (3.4, 3.0), "-|>"),
  edge((0, 4.5), (3.4, 4.5), "-|>"),
)

== user defined guards and assertions

When the check is a shape test, the guard moves into a function with
a predicate return type, `value is BookShape`, which teaches the
checker what the runtime proved. This is the standard boundary
function: `unknown` in, chapter 13's safe top, validated type out,
`undefined` for the rest:

#listing("javascript/tssamples/ch16/unions.ts", first: 50, last: 71, caption: [a type predicate parsing untrusted json])

The assertion function is the throwing sibling: `asserts value is T`
means "if this returns, the narrowing holds". The assertion return
type must be written out, which an inferred arrow binding cannot
carry, and after the call the `undefined` arm is gone without a
cast:

#listing("javascript/tssamples/ch16/unions.ts", first: 73, last: 80, caption: [an assertion function that narrows by throwing])

#flow(
  [two boundary functions, predicate against assertion],
  node((0, 0), [`unknown` in]),
  node((3.2, 0), [`value is BookShape`]),
  node((6.4, 0), [validated out, #linebreak() `undefined` for the rest]),
  node((0, 2.4), [`T | undefined` in]),
  node((3.2, 2.4), [`asserts value is T`]),
  node((6.4, 2.4), [narrows by throwing, #linebreak() the type written out, never inferred]),
  edge((0, 0), (3.2, 0), "-|>", label: [returns bool]),
  edge((3.2, 0), (6.4, 0), "-|>"),
  edge((0, 2.4), (3.2, 2.4), "-|>", label: [returns nothing]),
  edge((3.2, 2.4), (6.4, 2.4), "-|>"),
)

== intersections

The dual of the union is the intersection, every member of both:
`Named & Aged` demands `name` and `age` together. Intersecting
disjoint primitives yields `never`, the type with no values, which
is usually a modeling bug announcing itself:

#listing("javascript/tssamples/ch16/unions.ts", first: 82, last: 91, caption: [an intersection and a literal equality narrowing])

#diagram([the duality table, union against intersection], length: 13pt, {
  cdraw.content((4.4, 7.1), [type], size: 6.5pt, fill: luma(100))
  cdraw.content((15.8, 7.1), [what it demands], size: 6.5pt, fill: luma(100))

  let row(y, t, d, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.4, y + 0.7), t, size: 6pt)
    cdraw.content((15.8, y + 0.7), d, size: 6pt)
  }
  row(5.4, [`Circle | Rect`], [one of the alternatives], false)
  row(3.6, [`Named & Aged`], [every member of both], true)
  row(1.8, [`string & number`], [`never`, a bug announcing itself], false)
  row(0.0, [`mode === "read"`], [the smallest guard], true)

  cdraw.line((8.6, 0.0), (8.6, 6.8), stroke: luma(220))
  cdraw.content((11.6, -1.0), [a union lists, an intersection demands], size: 6.5pt)
})

Narrowing is control flow analysis: assignments, returns, throws,
truthiness, and literal equality all refine, and the refinements
reset after closures capture the variable or `await` intervenes.
The compiler forgets on purpose rather than guessing, and the escape
hatches are the casts of chapter 11, which silence the checker but
add no check.

#flow(
  [a value narrowing as it flows through guards, the default arm to never],
  node((0, 0), [Shape union]),
  node((2.4, 0), [kind == circle]),
  node((4.8, 0), [s.r is number]),
  node((0, 2.4), [default arm, no case left]),
  node((2.4, 2.4), [s is never, a new shape #linebreak() is a build error]),
  edge((0, 0), (2.4, 0), "-|>", label: [literal equality]),
  edge((2.4, 0), (4.8, 0), "-|>", label: [member access]),
  edge((0, 0), (0, 2.4), "-|>"),
  edge((0, 2.4), (2.4, 2.4), "-|>"),
)

sources: typescriptlang.org handbook narrowing and instanceof guards,
accessed 2026-09-13. Behavior verified live with tsc 7.0.2 and node
26.3.0 on windows, 9 tests in ch16 green through `npm run verify`.
