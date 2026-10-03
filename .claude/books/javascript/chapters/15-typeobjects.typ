#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= typing objects

Chapter 13 established the rule, the checker compares shape, not
name. This chapter applies it to the object: how a member is
declared optional or readonly, what an index signature trades away,
where the interface and the type alias part ways, and the one place
shape checking tightens, the fresh object literal. The runtime side
of objects, literal forms, key order, spread and rest, is part
one's chapter 4, and nothing here changes it: every modifier and
every declaration below erases at emit.

== interfaces against aliases

An interface and a type alias with the same members are the same
type to the checker. The test proves it by passing one value to
consumers typed with each, and neither consumer can tell which
declaration its parameter came from:

#listing("javascript/tssamples/ch15/typeobjects.ts", first: 6, last: 27, caption: [an interface, its alias twin, and two consumers that cannot tell them apart])

#diagram([interfaces against aliases, the same members as the same type], length: 13pt, {
  cdraw.content((11.6, 10.2), [the same members, the same type], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 8.4), (7.4, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 8.9), [`interface Book`], size: 6pt)
  cdraw.rect((7.8, 8.4), (14.8, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 8.9), [`type Article`], size: 6pt)
  cdraw.content((18.8, 8.9), [the same members, #linebreak() both directions], size: 6pt)

  cdraw.rect((4.0, 6.6), (11.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((7.7, 7.1), [one value, the book], size: 6pt)
  cdraw.line((6.5, 6.6), (4.0, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.9, 6.6), (11.6, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 4.8), (7.4, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 5.4), [`Describe(b: Book)`], size: 6pt)
  cdraw.rect((8.2, 4.8), (15.2, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.7, 5.4), [`DescribeArticle(a: Article)`], size: 6pt)

  cdraw.content((11.6, 3.9), [neither consumer can tell which declaration its parameter came from], size: 6.5pt)
  cdraw.content((11.6, 3.3), [where they part ways], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 1.6), (11.2, 2.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 2.2), [interfaces stay object shapes, #linebreak() they extend and merge across declarations], size: 6pt)
  cdraw.rect((11.8, 1.6), (22.8, 2.8), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 2.2), [aliases compose: a union, a tuple, #linebreak() a conditional type, chapter 17's raw material], size: 6pt)
  cdraw.content((11.6, 0.6), [the checker compares shape, not declaration kind], size: 6.5pt)
})

The declarations part ways in three places, and only the third
matters for object shapes. Interfaces extend and merge, aliases
compose: an alias can be a union, a tuple, a conditional type, the
raw material of chapter 17, while an interface is always an object
shape. And interfaces can be augmented across declarations, which is
the capability below.

== optional and readonly

An optional member, `pages?`, may be absent, and the consumer
defaults it with `??`, because reading it yields `undefined` at
runtime exactly as part one's property access rules say. A readonly
member is a checker promise with no runtime side: the cast below
compiles because it routes through a type without the modifier, and
the mutation runs:

#listing("javascript/tssamples/ch15/typeobjects.ts", first: 37, last: 42, caption: [readonly members mutate through casts, exactly like the readonly members above])

#diagram([the two modifiers, no runtime side on either], length: 13pt, {
  cdraw.content((5.8, 8.6), [`pages?`, the optional member], size: 6.5pt, fill: luma(100))
  cdraw.content((17.4, 8.6), [`readonly isbn`, the readonly member], size: 6.5pt, fill: luma(100))
  cdraw.line((11.6, 3.4), (11.6, 8.2), stroke: luma(220))

  cdraw.rect((0.4, 6.8), (11.2, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 7.4), [may be absent: the consumer #linebreak() defaults it with `??`], size: 6pt)
  cdraw.rect((0.4, 5.2), (11.2, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 5.8), [reading yields `undefined` at runtime, #linebreak() exactly as property access says], size: 6pt)
  cdraw.rect((12.0, 6.8), (22.8, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 7.4), [a checker promise #linebreak() with no runtime side], size: 6pt)
  cdraw.rect((12.0, 5.2), (22.8, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 5.8), [the cast routes through a type without #linebreak() the modifier, and the mutation runs], size: 6pt)

  cdraw.rect((0.4, 3.6), (22.8, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.1), [nothing at runtime enforces either modifier], size: 6pt)
  cdraw.rect((0.4, 2.2), (22.8, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 2.7), [what they buy: call sites that fail at compile time #linebreak() instead of surprising a reader], size: 6pt)
  cdraw.content((11.6, 1.1), [worth having precisely because it is free], size: 6.5pt)
})

Nothing at runtime enforces either modifier. What they buy is call
sites that fail at compile time instead of surprising a reader, and
the discipline is worth having precisely because it is free.

== excess properties

The one place shape checking tightens is the fresh object literal,
which gets excess property checks so a typo in a property name fails
at the assignment instead of riding along forever. The check
applies to literals only. A variable whose type is `Book & {
extra }` is a perfectly valid `Book`, and the extra member survives
every assignment, because nothing at runtime ever strips properties:

#listing("javascript/tssamples/ch15/typeobjects.ts", first: 29, last: 35, caption: [extra members ride along through variables, the literal check never sees them])

#diagram([excess property checks and readonly, where the tightening stops], length: 13pt, {
  cdraw.content((11.6, 8.6), [where checking tightens], size: 6.5pt, fill: luma(100))
  // the fresh literal, rejected
  cdraw.content((5.5, 7.7), [fresh literal], size: 6.5pt)
  cdraw.rect((0.4, 6.1), (10.6, 7.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 6.7), [`{ ...book, extra }`], size: 6pt)
  cdraw.line((5.5, 6.1), (5.5, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 4.5), (10.6, 5.5), fill: luma(205), radius: 0.02)
  cdraw.content((5.5, 5.0), [rejected at the assignment], size: 6pt)

  // the variable, accepted forever
  cdraw.content((17.5, 7.7), [the same shape, in a variable], size: 6.5pt)
  cdraw.rect((12.4, 6.1), (22.6, 7.3), fill: luma(235), radius: 0.02)
  cdraw.content((17.5, 6.7), [`b: Book & { extra }`], size: 6pt)
  cdraw.line((17.5, 6.1), (17.5, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.4, 4.5), (22.6, 5.5), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.0), [accepted, `extra` rides forever], size: 6pt)

  // readonly, the same escape
  cdraw.content((11.6, 3.5), [readonly, the same escape], size: 6.5pt, fill: luma(100))
  cdraw.rect((3.4, 2.0), (11.0, 3.0), fill: luma(235), radius: 0.02)
  cdraw.content((7.2, 2.5), [`as { isbn: string }`], size: 6pt)
  cdraw.line((11.0, 2.5), (13.0, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.4, 2.0), (22.6, 3.0), fill: luma(205), radius: 0.02)
  cdraw.content((18.0, 2.5), [the mutation compiles and runs], size: 6pt)
  cdraw.content((11.6, 1.0), [nothing at runtime ever strips properties], size: 6.5pt)
})

#snippet(
  "const typo: Book = { isbn: \"i1\", title: \"go\", pagse: 321 };\n"
  + "// error TS2561: object literal may only specify known properties,\n"
  + "// but 'pagse' does not exist in type 'Book'. Did you mean 'pages'?\n",
  lang: "ts",
)

== index signatures

An index signature types every key at once, which trades precision
for openness. The cost is the missing key: the signature says
`number`, the runtime says `undefined`, and the checker believes the
signature:

#listing("javascript/tssamples/ch15/typeobjects.ts", first: 44, last: 55, caption: [index signatures, and the missing key that types as number])

#flow(
  [the index signature's promise against the missing key],
  node((0, 0), [`counts["ghost"]`]),
  node((3.4, 0), [checker: `number`, #linebreak() the signature believed]),
  node((6.8, 0), [runtime: `undefined`, #linebreak() the honest read]),
  node((0, 2.4), [the flag, on]),
  node((3.4, 2.4), [`number | undefined`]),
  node((6.8, 2.4), [guarded reads, #linebreak() everywhere]),
  edge((0, 0), (3.4, 0), "-|>"),
  edge((3.4, 0), (6.8, 0), "-|>"),
  edge((0, 2.4), (3.4, 2.4), "-|>", label: [`noUncheckedIndexedAccess`]),
  edge((3.4, 2.4), (6.8, 2.4), "-|>"),
)

`noUncheckedIndexedAccess`, off by default in this book, would type
the read `number | undefined` instead and force every indexed access
to be guarded. The honest middleware is a `Map` when the key set is
open and unknown, part one's chapter 5, or a guard at the boundary
when it is not.

== extension and merging

Interfaces extend one another and also merge: two declarations of
the same name union their members. Merging is how `Array` grows
extension methods in library code, and it is the one capability a
type alias cannot copy, aliases are single declarations and
redeclaring them is an error:

#listing("javascript/tssamples/ch15/typeobjects.ts", first: 57, last: 82, caption: [extension, declaration merging, and one implementation])

#diagram([declaration merging, two boxes into one type], length: 13pt, {
  cdraw.content((4.2, 8.0), [two declarations], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.4), (8.0, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.2, 6.9), [`Box { load(...): void }`], size: 6pt)
  cdraw.rect((0.4, 5.0), (8.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.2, 5.5), [`Box { unload(): string[] }`], size: 6pt)
  cdraw.line((8.0, 6.9), (10.2, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.0, 5.5), (10.2, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 5.3), (19.8, 6.7), fill: luma(205), radius: 0.02)
  cdraw.content((15.1, 6.05), [one type: `load` and `unload`], size: 6pt)
  cdraw.line((15.1, 5.3), (15.1, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.6, 5.0), [satisfies], size: 6pt)
  cdraw.rect((11.0, 3.4), (19.8, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((15.4, 4.0), [`NewBox()` builds one], size: 6pt)
  cdraw.content((11.6, 2.2), [merging is the one capability an alias cannot copy], size: 6.5pt)
})

#callout("note", "when shape is not enough", [
  Structural typing admits any object with the right members, so a
  `UserId` and a `OrderId` both typed `string` substitute for each
  other freely. When identity matters, the idiom is branding, a
  nominal marker carried in the type. Chapter 20 builds it from the
  tools of this part.
])

sources: typescriptlang.org handbook object types and interfaces,
accessed 2026-09-13. Behavior verified live with tsc 7.0.2 and node
26.3.0 on windows, 8 tests in ch15 green through `npm run verify`,
the excess property counterfactual confirmed by `tsc --noEmit`
before being shown as a fragment.
