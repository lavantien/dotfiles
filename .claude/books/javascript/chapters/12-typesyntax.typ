#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= type syntax

Typescript inherits the ecmascript grammar whole and adds type syntax
in positions javascript leaves empty: after a colon, inside angle
brackets, between `type` and `=`. The runtime side of every value
here is already chapter 2's, the seven primitives, the lying
`typeof`, the two equalities, so this chapter is deliberately slim:
what an annotation is, what inference does when you omit one, how
literal and union literal types refine the primitives, how arrays
and tuples are spelled, and how aliases and `typeof` queries give
names to shapes. None of it survives compilation, chapter 11 proved
that against the emitted file, so every test below exercises the
value the annotation promised to describe.

The added layer is contextual, never reserved. Words like `keyof`,
`satisfies`, `readonly`, and the type words `string`, `number`,
`never` parse as keywords only where type syntax is expected, and as
ordinary identifiers everywhere else:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 81, last: 87, caption: [type words bind as identifiers outside type position])

== annotations and inference

An annotation is a promise attached to a binding, checked at compile
time and erased at emit. Inference is the checker deriving the same
promise from the initializing expression, and the interesting case is
the literal. A `let` binding widens: `let mode = "read"` infers
`string`, because the binding may be reassigned, so writing `"write"`
back into it compiles. A `const` binding keeps the literal type,
because nothing can change it:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 15, last: 36, caption: [let widens to the primitive, const keeps the literal, and only the narrow one calls the union])

#diagram([annotation and inference, let widening against const keeping], length: 13pt, {
  cdraw.content((11.6, 10.4), [the direction of information], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 8.4), (7.4, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 8.9), [`mode: string`], size: 6pt)
  cdraw.line((7.4, 8.9), (8.6, 8.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 8.4), (22.8, 9.4), fill: luma(205), radius: 0.02)
  cdraw.content((15.7, 8.9), [the annotation: the type says what the value is, #linebreak() checked at compile time, erased at emit], size: 6pt)

  cdraw.rect((0.4, 6.2), (7.4, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 6.7), [`"read"`, the initializer], size: 6pt)
  cdraw.line((7.4, 6.9), (8.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.4, 6.4), (8.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 6.2), (15.4, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 6.7), [`let` widens to `string`], size: 6pt)
  cdraw.line((15.4, 6.7), (15.8, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.8, 6.2), (22.8, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((19.3, 6.7), [`"write"` back into it #linebreak() compiles], size: 6pt)
  cdraw.rect((8.6, 4.6), (15.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 5.1), [`const` keeps `"read"`], size: 6pt)
  cdraw.line((15.4, 5.1), (15.8, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.8, 4.6), (22.8, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((19.3, 5.1), [`ModeLabel(mode)`, #linebreak() no cast needed], size: 6pt)

  cdraw.rect((0.4, 3.0), (22.8, 4.0), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, 3.5), [`type T = typeof x`, the query naming what inference found], size: 6pt)

  cdraw.content((11.6, 1.9), [inference runs one binding at a time and never looks at how a value is used later], size: 6.5pt)
  cdraw.content((11.6, 0.9), [annotations exist for the places where the future use matters more than the initializer], size: 6.5pt)
})

The call in `NarrowConst` typechecks without a cast because the
checker still knows `mode` is exactly `"read"`. The counterfactual
does not compile, and that is the point:

#snippet(
  "export function Broken(): string {\n"
  + "  let mode = \"read\";      // inferred string, widened\n"
  + "  return ModeLabel(mode);  // error: string is not \"read\" | \"write\"\n"
  + "}\n",
  lang: "ts",
)

Inference runs one binding at a time and never looks at how a value
is used later; annotations exist for the places where the future use
matters more than the initializing expression.

== primitives against their runtime values

The primitive annotations correspond to runtime values chapter 2
already measured, and the correspondence has one asymmetry worth a
table: `typeof null` is `"object"`, the 1995 lie, while the
annotation for the value is `null`:

#diagram([annotation against typeof, the one starred row is chapter 2's lie], length: 13pt, {
  cdraw.content((4.4, 7.1), [annotation], size: 6.5pt, fill: luma(100))
  cdraw.content((11.4, 7.1), [typeof at runtime], size: 6.5pt, fill: luma(100))
  cdraw.content((18.4, 7.1), [binding of], size: 6.5pt, fill: luma(100))

  let row(y, ann, res, note, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.4, y + 0.7), ann, size: 6pt)
    cdraw.content((11.4, y + 0.7), res, size: 6pt)
    cdraw.content((18.4, y + 0.7), note, size: 6pt)
  }
  row(5.4, [`string`], ["string"], [by value, immutable], false)
  row(3.6, [`number`, `bigint`], ["number", "bigint"], [ieee 754, arbitrary], true)
  row(1.8, [`boolean`], ["boolean"], [`true`, `false` only], false)
  row(0.0, [`null`, `undefined`], ["object" \*, "undefined"], [the lie, the absence], true)

  cdraw.content((11.6, -1.0), [the checker's names are cleaner than the operator's answers], size: 6.5pt)
})

The boxed forms, `String` and `Number` and friends, are object types,
not primitive ones: two boxes over the same primitive are two
identities, never equal, and the test pins it:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 38, last: 43, caption: [the box is an object, identity comparison fails, and the checker keeps string and String apart])

== literal and union literal types

A literal type admits exactly one value, and a union of literals is
the cheapest enum-like checking there is: no runtime footprint, the
members are the values themselves. `Mode` below is two string
literals, and inside `ModeLabel` the `===` comparison narrows which
one the parameter is, a preview of chapter 16's full treatment:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 25, last: 31, caption: [the union literal type and its consumer])

#diagram([literal and union literal types, the members are the values themselves], length: 13pt, {
  cdraw.content((3.9, 9.7), [the literal type], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 7.9), (7.4, 9.1), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.rect((1.0, 8.2), (6.8, 8.9), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 8.55), [`"read"`], size: 6pt)
  cdraw.content((3.9, 7.4), [admits exactly one value], size: 6pt)

  cdraw.content((15.4, 9.7), [the union of literals, `Mode`], size: 6.5pt, fill: luma(100))
  cdraw.rect((8.0, 7.9), (22.8, 9.1), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.rect((9.2, 8.2), (14.6, 8.9), fill: luma(205), radius: 0.02)
  cdraw.content((11.9, 8.55), [`"read"`], size: 6pt)
  cdraw.rect((16.2, 8.2), (21.6, 8.9), fill: luma(205), radius: 0.02)
  cdraw.content((18.9, 8.55), [`"write"`], size: 6pt)
  cdraw.content((15.4, 7.4), [the members are the values themselves], size: 6pt)

  cdraw.rect((0.4, 5.8), (22.8, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 6.3), [inside `ModeLabel`, the `===` comparison narrows which one the parameter is, chapter 16's preview], size: 6pt)

  cdraw.rect((0.4, 3.9), (7.6, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 4.5), [a fresh literal fits #linebreak() `ModeLabel("read")`], size: 6pt)
  cdraw.rect((8.0, 3.9), (15.2, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.5), [a `const` binding fits #linebreak() `NarrowConst`], size: 6pt)
  cdraw.rect((15.6, 3.9), (22.8, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((19.2, 4.5), [the widened `let` does not #linebreak() `string` is not `Mode`], size: 6pt)

  cdraw.content((11.6, 2.7), [the cheapest enum-like checking there is, no runtime footprint], size: 6.5pt)
  cdraw.content((11.6, 1.7), [no cast anywhere changes a runtime value], size: 6.5pt)
})

Literal unions compose with the widening rule above: a fresh literal
argument fits, a `const` binding fits, a widened `let` does not, and
no cast anywhere changes a runtime value.

== arrays and tuples

Arrays carry one element type in two spellings, `number[]` and
`Array<number>`, and the spellings are the same type: the second
function below calls the first with its argument, unchecked and
uncast, because they agree:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 6, last: 13, caption: [one array type, two spellings, one calling the other])

A tuple is an array with a fixed shape: the arity is part of the
type, each position has its own element type, and the labels are
names for humans and error messages. The length claim is enforced by
the checker alone, part one's arrays know nothing about it, which is
why `OptionalTail` can report a length the tuple's full form would
forbid:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 45, last: 55, caption: [labeled tuple positions, and an optional tail one short])

#diagram([arrays in two spellings, the tuple's fixed shape], length: 13pt, {
  cdraw.content((11.6, 10.0), [one array type, one fixed shape], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 8.4), (22.8, 9.5), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 8.95), [`number[]` and `Array<number>` are the same type: #linebreak() `TotalAliased` calls `Total` unchecked and uncast], size: 6pt)

  cdraw.content((11.6, 7.5), [the tuple, arity in the type], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.8, 6.0), (7.0, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 6.6), [`label: string` #linebreak() position one], size: 6pt)
  cdraw.rect((7.4, 6.0), (13.6, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.5, 6.6), [`value: number` #linebreak() position two], size: 6pt)
  cdraw.content((17.8, 6.6), [the labels are for humans #linebreak() and error messages], size: 6pt)

  cdraw.content((11.6, 5.1), [the optional tail], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.8, 3.6), (7.0, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 4.2), [`name: string`], size: 6pt)
  cdraw.rect((7.4, 3.6), (13.6, 4.8), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((10.5, 4.2), [`age?: number` #linebreak() absent here], size: 6pt)
  cdraw.line((13.6, 4.2), (14.8, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.0, 3.6), (22.8, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((18.9, 4.2), [`["ada"]` is legal #linebreak() `pair.length` is 1], size: 6pt)

  cdraw.content((11.6, 2.4), [the tuple's full form would forbid that length, the arity is the checker's claim alone], size: 6.5pt)
  cdraw.content((11.6, 1.4), [part one's arrays know nothing about it], size: 6.5pt)
})

== aliases and typeof queries

A type alias is a name, not a new type. `type ID = string | number`
adds a word to the checker's vocabulary and nothing to the runtime,
and narrowing an `ID` is narrowing the union it names:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 57, last: 63, caption: [an alias to a union, narrowed by the runtime operator])

The `typeof` query is the bridge from values to types: in type
position, `typeof x` is the type the checker currently has for `x`.
Deriving a type from one object literal and consuming it elsewhere
keeps the shape and the value from drifting apart, and querying a
function yields its full signature, which another binding must then
match exactly:

#listing("javascript/tssamples/ch12/typesyntax.ts", first: 65, last: 79, caption: [typeof deriving a shape from a value, and a signature from a function])

#flow(
  [the direction of information, annotation, inference, and query],
  node((0, 0), [annotation #linebreak() `x: string`]),
  node((3.2, 0), [the type says #linebreak() what the value is]),
  node((0, 2.2), [inference #linebreak() `let x = "a"`]),
  node((3.2, 2.2), [the value says #linebreak() what the type is]),
  node((0, 4.4), [query #linebreak() `type T = typeof x`]),
  node((3.2, 4.4), [a name for what #linebreak() inference found]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((0, 2.2), (3.2, 2.2), "-|>", label: [widens on `let`]),
  edge((0, 4.4), (3.2, 4.4), "-|>", label: [literal kept on `const`]),
)

#callout("note", "what this chapter is not", [
  This is not the lexical chapter it replaced. The reserved word
  strata and the semicolon insertion note live in part one's
  chapter 2, the full census of all 75 words in chapter 39's
  appendix, and the private name lexeme in chapter 4's classes. The
  typescript specific residue, that the type layer's words are
  contextual rather than reserved, is the one grammar fact kept
  here, pinned by the `ContextualWords` test.
])

sources: typescriptlang.org handbook everyday types and more on
functions, accessed 2026-09-13. Behavior verified live with tsc 7.0.2
and node 26.3.0 on windows, 10 tests in ch12 green through
`npm run verify`, the widening counterfactual confirmed by
`tsc --noEmit` before being shown as a fragment.
