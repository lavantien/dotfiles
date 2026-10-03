#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= the type landscape

Chapter 12 built the syntax of one type at a time. This chapter is
about the relations between types: which values a type admits, which
types substitute for which, and what the checker compares when it
decides. Four special types anchor the map, `any`, `unknown`,
`never`, and `void`, and one rule organizes everything else:
typescript compares shape, not name.

== the two tops and two bottoms

`any` is the escape hatch. Assignments in, member access out, all of
it unchecked, and the failure moves from compile time to runtime.
The call below compiles, the member does not exist, and the program
dies at the call site. Real codebases lint `any` toward zero:

#listing("javascript/tssamples/ch13/types.ts", first: 5, last: 8, caption: [any: the hole in the checking, demonstrated by falling into it])

`unknown` is the safe top type. Anything assigns into it, which
makes it the honest type for data from outside the program, and
nothing reads out of it without a runtime guard. The guards are not
new machinery, they are part one's own operators, and each guard
narrowing the value inside its branch is the preview of chapter 16:

#listing("javascript/tssamples/ch13/types.ts", first: 10, last: 17, caption: [unknown consumed only through the runtime guards of part one])

`never` is the bottom type, inhabited by nothing. A function whose
body always throws returns it, the return type is not a formality,
and chapter 16 uses it to prove switches exhaustive. `void` is the
return contract, and it is weaker than it looks: a function typed
`() => void` may be assigned one that returns 42, the call still
evaluates to 42, and only the type of the call forbids using the
value, which the sample has to smuggle out through a double cast to
observe:

#listing("javascript/tssamples/ch13/types.ts", first: 19, last: 30, caption: [never throws, void only forbids])

#diagram([the two tops and two bottoms, by what each one admits], length: 13pt, {
  cdraw.content((3.0, 7.1), [type], size: 6.5pt, fill: luma(100))
  cdraw.content((10.0, 7.1), [what goes in], size: 6.5pt, fill: luma(100))
  cdraw.content((17.0, 7.1), [what comes out], size: 6.5pt, fill: luma(100))

  let row(y, t, into, out, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.0, y + 0.7), t, size: 6pt)
    cdraw.content((10.0, y + 0.7), into, size: 6pt)
    cdraw.content((17.0, y + 0.7), out, size: 6pt)
  }
  row(5.4, [`any`], [all, unchecked], [member access unchecked], false)
  row(3.6, [`unknown`], [all, checked], [reads only via guards], true)
  row(1.8, [`never`], [nothing], [proves exhaustiveness], false)
  row(0.0, [`void`], [any return in], [the value is forbidden], true)

  for x in (6.2, 13.6) { cdraw.line((x, 0.0), (x, 6.8), stroke: luma(220)) }
  cdraw.content((11.6, -1.0), [two tops, two bottoms: only the checker sees the difference], size: 6.5pt)
})

The rule of thumb: `unknown` at boundaries, ordinary types inside,
`never` for the impossible, `any` for the legacy file you have not
migrated yet.

== structural typing

A value is a `Printable` because it has the members a `Printable`
needs. No name, no declaration lineage, no nominal identity. The
interface and the alias below are interchangeable in every position,
the class implements neither, and its instances satisfy both anyway,
because structure is the only thing the checker compares:

#listing("javascript/tssamples/ch13/types.ts", first: 32, last: 59, caption: [an interface, its alias twin, a class that declares neither, and one value through both consumers])

#diagram([nominal against structural, one value through both worlds], length: 13pt, {
  // the nominal world, for contrast
  cdraw.content((5.5, 8.4), [nominal, for contrast], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.6), (10.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.1), [identity by birth name], size: 6pt)
  cdraw.rect((0.4, 5.2), (10.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.7), [a wider shape is a stranger], size: 6pt)

  // the structural world
  cdraw.content((17.5, 8.4), [structural, what typescript does], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.6), (22.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.1), [the members are the identity], size: 6pt)
  cdraw.rect((12.4, 5.2), (22.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.7), [more members fine, fewer not], size: 6pt)

  // one value through both consumers
  cdraw.rect((4.0, 3.4), (19.6, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 4.0), [`new Page("types")`], size: 6pt)
  cdraw.line((9.0, 3.4), (6.7, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 3.4), (17.3, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.2, 1.2), (10.6, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 1.8), [`Print(p: Printable)`], size: 6pt)
  cdraw.rect((12.4, 1.2), (22.0, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.2, 1.8), [`TitleOf(t: Titled)`], size: 6pt)
  cdraw.content((11.6, 0.5), [both accept it, neither can tell them apart], size: 6.5pt)
})

The contrast is with the nominal systems of the other books in this
corpus, where a `UserId` and an `OrderId` over the same primitive are
different by declaration. Structural typing trades that safety for
openness, and when identity matters the fix is branding, chapter 20's
idiom.

== assignability

Substitution is the checker's daily work, and width subtyping is the
rule: more members than required is assignable, fewer is not. The
extra member is not stripped, because nothing at runtime ever strips
properties, part one's chapter 4 established that, so the wide value
keeps its `speed` after passing through the narrow parameter:

#listing("javascript/tssamples/ch13/types.ts", first: 61, last: 76, caption: [width subtyping, the wider value assigning down and keeping its extra member])

Direction matters as much as width. A member of a union assigns to
the union, a literal assigns to its primitive, `never` assigns to
everything, and none of the reverse moves compile without a narrowing
step in between:

#listing("javascript/tssamples/ch13/types.ts", first: 78, last: 92, caption: [the direction table as code: literal into union, never into all])

#flow(
  [assignability's one way streets],
  node((0, 0), [`"read"`]),
  node((2.6, 0), [`Mode`, its union]),
  node((5.2, 0), [`string`, widened]),
  node((0, 2.2), [`never`]),
  node((2.6, 2.2), [every type, #linebreak() the bottom type]),
  node((5.2, 2.2), [`unknown`, the top]),
  edge((0, 0), (2.6, 0), "-|>", label: [up, yes]),
  edge((2.6, 0), (5.2, 0), "-|>", label: [up, yes]),
  edge((0, 2.2), (2.6, 2.2), "-|>"),
  edge((2.6, 2.2), (5.2, 2.2), "-|>"),
)

The reverse of every arrow in that diagram needs either a guard that
narrows or a cast that lies, and the cast is exactly chapter 11's
`null as unknown as string` in miniature: it silences the checker
and adds no check.

== narrowing, previewed

The `unknown` section already did it: a runtime guard, `typeof` or
`Array.isArray`, and inside the branch the value's type shrinks to
what the guard proved. Chapter 16 is the full treatment, union types
and the discriminator pattern and exhaustiveness, and its runtime
half is entirely part one's: the guards are operators the language
always had, the checker merely tracks what each branch proved and
forgets it when control flow can no longer guarantee it.

#diagram([narrowing previewed, the guard shrinking the type inside its branch], length: 13pt, {
  cdraw.content((11.6, 9.4), [the guard shrinks the type inside its branch], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 7.6), (6.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.4, 8.1), [`u: unknown`], size: 6pt)
  cdraw.line((6.4, 8.1), (7.6, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 7.6), (14.4, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 8.1), [`typeof u === "string"`], size: 6pt)
  cdraw.line((14.4, 8.1), (15.6, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.6, 7.6), (22.8, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 8.1), [inside the branch #linebreak() `u: string`], size: 6pt)

  cdraw.rect((0.4, 6.0), (6.4, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.4, 6.5), [`a: unknown`], size: 6pt)
  cdraw.line((6.4, 6.5), (7.6, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 6.0), (14.4, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 6.5), [`Array.isArray(a)`], size: 6pt)
  cdraw.line((14.4, 6.5), (15.6, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.6, 6.0), (22.8, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 6.5), [inside the branch #linebreak() `a` is an array], size: 6pt)

  cdraw.rect((0.4, 4.4), (22.8, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.9), [the checker tracks what each branch proved], size: 6pt)
  cdraw.rect((0.4, 3.0), (22.8, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.5), [and forgets it when control flow can no longer guarantee it], size: 6pt)

  cdraw.content((11.6, 1.8), [the guards are part one's own operators, the language always had them], size: 6.5pt)
  cdraw.content((11.6, 0.8), [already consumed on unknown, chapter 16 is the full treatment: unions, discriminators, exhaustiveness], size: 6.5pt)
})

#callout("note", "what moved out of this chapter", [
  The typeof table now lives in part one's chapter 2, where the
  operator is measured on runtime values. Arrays and tuples, literal
  unions, and aliases are chapter 12's syntax. Enums, the one
  construct that emits an object, wait for the emit chapters, and
  their suite cases went with them.
])

sources: typescriptlang.org handbook more on functions and narrowing,
typescriptlang.org any vs unknown documentation, accessed 2026-09-13.
Behavior verified live with tsc 7.0.2 and node 26.3.0 on windows,
10 tests in ch13 green through `npm run verify`.
