#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= typescript idioms

The language gives structure no identity and the runtime no checks,
so the idioms of typescript are the patterns that restore both at
the boundaries where it matters, and nowhere else. Chapter 13 set
the rule, `unknown` at the edges, ordinary types inside, and chapter
14 built the guard machinery, predicates, assertions, the
discriminator. This chapter assembles those parts into the shapes a
codebase actually keeps: branded ids, the exhaustiveness alarm,
errors as values, deep freezing, state machines, typed events, and
the two precision tools that arrived from chapter 17, `satisfies`
and the `const` type parameter.

== branding

A brand is a phantom member carrying a name in the type:

#listing("javascript/tssamples/ch20/idioms.ts", first: 4, last: 15, caption: [branded ids over one primitive])

#diagram([the phantom member, two ids over one string], length: 13pt, {
  cdraw.content((8.6, 8.4), [one primitive, two names], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.8, 6.6), (6.2, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.5, 7.1), [`UserId`], size: 6pt)
  cdraw.content((8.2, 7.1), [unrelated], size: 6pt)
  cdraw.rect((10.2, 6.6), (15.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.9, 7.1), [`OrderId`], size: 6pt)
  cdraw.line((3.5, 6.6), (3.5, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.9, 6.6), (12.9, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.0, 4.6), (15.0, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((8.5, 5.1), [`"u1"`, a plain string at runtime], size: 6pt)

  cdraw.rect((16.8, 6.6), (22.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((19.7, 7.1), [`UserId(raw)`], size: 6pt)
  cdraw.line((19.7, 6.6), (19.7, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.8, 4.6), (22.6, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((19.7, 5.3), [the cast lives here, #linebreak() nowhere else], size: 6pt)
  cdraw.content((11.6, 3.4), [the phantom member exists only in the type], size: 6.5pt)
  cdraw.content((11.6, 2.4), [a `unique symbol` key is invisible even to `Object.keys`], size: 6.5pt)
})

`UserId` and `OrderId` are both strings at runtime, the test
confirms the erasure, but they are unrelated types to the checker,
and a function demanding one rejects the other without a cast. This
is the deliverable chapter 15's callout promised when it said
identity is buyable: construction goes through the smart
constructors, which are the only place the cast appears, and the
boundary validation inside them is chapter 16's type predicate, so
the branded type is earned by a runtime check exactly once. The
alternative spelling uses a `unique symbol` key instead of a string
one, invisible even to `Object.keys`, at the cost of one extra
declaration.

== the exhaustiveness alarm

Chapter 16 ended switches with a `never` default. The idiom extracts
it into a helper, so every switch in a codebase fails the same loud
way when a union grows:

#listing("javascript/tssamples/ch20/idioms.ts", first: 17, last: 19, caption: [the exhaustiveness helper])

#flow(
  [assertNever as the alarm circuit],
  node((0, 0), [every `default` arm]),
  node((3.2, 0), [`assertNever(value)`]),
  node((6.4, 0), [throws, the value named]),
  node((0, 2.4), [a union member added]),
  node((3.2, 2.4), [`value` is not `never`]),
  node((6.4, 2.4), [the build error lands, #linebreak() at exactly that spot]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((3.2, 0), (6.4, 0), "-|>"),
  edge((0, 2.4), (3.2, 2.4), "-|>"),
  edge((3.2, 2.4), (6.4, 2.4), "-|>"),
)

The rest of the boundary discipline is chapters 13 and 16's, restated
as one sentence each because it is the sentence people skip:
untrusted input arrives as `unknown` and leaves through a predicate
or assertion, `any` is quarantined to the legacy file that forced
it, and member access that has not been narrowed does not compile.
No idiom in this chapter relaxes that, they all build on it.

== errors as values

Throwing is for exceptional paths. For expected failures the
idiom is a result union, a discriminated pair the caller must
narrow before touching the payload:

#listing("javascript/tssamples/ch20/idioms.ts", first: 21, last: 40, caption: [result constructors, a parser, and a defaulting consumer])

#diagram([the result union, two arms one contract], length: 13pt, {
  cdraw.content((11.6, 8.4), [one union, two arms], size: 6.5pt, fill: luma(100))
  cdraw.rect((8.0, 6.8), (15.2, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 7.3), [`Result<T, E>`], size: 6pt)
  cdraw.line((10.0, 6.8), (4.0, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 6.8), (19.0, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 4.6), (7.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 5.4), [`{ ok: true, value }` #linebreak() built by `Ok(value)`], size: 6pt)
  cdraw.rect((15.6, 4.6), (22.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((19.1, 5.4), [`{ ok: false, error }` #linebreak() built by `Err(error)`], size: 6pt)
  cdraw.rect((2.6, 2.8), (10.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 3.4), [`TryInt` picks one], size: 6pt)
  cdraw.line((10.2, 3.4), (11.8, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 2.8), (19.6, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((15.8, 3.4), [`ValueOr`, the only default], size: 6pt)
  cdraw.content((11.6, 1.6), [the caller narrows before touching the payload], size: 6.5pt)
})

This is the same shape #xref-to("go", "errors") builds from multiple
returns and the comma ok test, and it composes with every narrowing
tool from chapter 16.

== freezing deep

`readonly` stops at the first object. The deep version is a
recursive mapped type over a recursive `Object.freeze`, type and
runtime walking the same shape, and every operator in it is chapter
15's, `extends` for the object test, the mapped type for the rebuild,
recursion through the member position:

#listing("javascript/tssamples/ch20/idioms.ts", first: 42, last: 55, caption: [DeepReadonly over DeepFreeze])

#diagram([freezing deep, one recursion in two worlds], length: 13pt, {
  cdraw.content((11.6, 9.8), [one recursion in two worlds], size: 6.5pt, fill: luma(100))
  cdraw.rect((7.6, 8.2), (15.6, 9.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 8.7), [the nested object, #linebreak() type and value the same shape], size: 6pt)

  cdraw.content((5.8, 7.4), [the type world], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.8), (11.2, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.35), [`DeepReadonly<T>`: #linebreak() `extends` tests the object], size: 6pt)
  cdraw.line((5.8, 5.8), (5.8, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 4.3), (11.2, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 4.8), [the mapped type rebuilds #linebreak() every member `readonly`], size: 6pt)
  cdraw.line((5.8, 4.3), (5.8, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 2.9), (11.2, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 3.4), [recursion through #linebreak() the member position], size: 6pt)

  cdraw.content((17.3, 7.4), [the value world], size: 6.5pt, fill: luma(100))
  cdraw.rect((11.8, 5.8), (22.8, 6.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 6.35), [`DeepFreeze(value)`: #linebreak() `Object.keys` walks the members], size: 6pt)
  cdraw.line((17.3, 5.8), (17.3, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.8, 4.3), (22.8, 5.3), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 4.8), [`typeof === "object"` gates the #linebreak() recursion into each member], size: 6pt)
  cdraw.line((17.3, 4.3), (17.3, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.8, 2.9), (22.8, 3.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 3.4), [`Object.freeze` on each object, #linebreak() inside out], size: 6pt)

  cdraw.rect((0.4, 1.5), (22.8, 2.5), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.0), [the mutation through a cast throws: assignment to a frozen property #linebreak() throws in an es module], size: 6pt)
  cdraw.content((11.6, 0.5), [`Object.freeze`, one of the few runtime enforcements javascript has], size: 6.5pt)
})

The test mutates through a cast and gets a `TypeError`, because
`Object.freeze` is one of the few runtime enforcements javascript
has, and in an es module assignment to a frozen property throws.

== state machines

A discriminated union of states plus a transition function is a
finite state machine the checker audits: every state and event pair
is either handled or it throws, and adding a state stops the
build until every transition table row exists:

#listing("javascript/tssamples/ch20/idioms.ts", first: 57, last: 81, caption: [states, events, and one exhaustive transition function])

#diagram([the transition table as a machine, four states], length: 13pt, {
  cdraw.content((11.6, 8.6), [four states, four events], size: 6.5pt, fill: luma(100))
  cdraw.rect((1.0, 4.6), (4.2, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.6, 5.1), [`idle`], size: 6pt)
  cdraw.rect((10.0, 7.0), (13.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 7.5), [`loading`], size: 6pt)
  cdraw.rect((19.4, 4.6), (22.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((21.0, 5.1), [`loaded`], size: 6pt)
  cdraw.rect((10.0, 2.2), (13.8, 3.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 2.7), [`failed`], size: 6pt)
  cdraw.line((4.2, 5.4), (10.0, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.3, 6.9), [start], size: 6pt)
  cdraw.line((13.6, 7.2), (19.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.0, 6.9), [success], size: 6pt)
  cdraw.line((11.8, 7.0), (11.9, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.4, 5.7), [failure], size: 6pt)
  cdraw.line((19.4, 5.1), (4.2, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.6, 5.55), [reset], size: 6pt)
  cdraw.line((10.0, 2.9), (2.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.4, 3.4), [reset], size: 6pt)
  cdraw.content((11.6, 1.1), [every unhandled pair throws by construction], size: 6.5pt)
  cdraw.content((11.6, 0.2), [add a state, the build stops until every row exists], size: 6.5pt)
})

== typed events

An interface of tuple-valued keys parameterizes a pub sub, so
`emit` and `on` agree on arity and types per event name, with no
stringly typed dispatch anywhere. The map over `keyof E` is chapter
15's mapped type doing real work:

#listing("javascript/tssamples/ch20/idioms.ts", first: 83, last: 106, caption: [a typed emitter and one wired consumer])

#diagram([the emitter, one interface behind both doors], length: 13pt, {
  cdraw.content((11.6, 8.4), [one interface, two doors], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.3), (9.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 7.6), [`OrderEvents`], size: 6pt)
  cdraw.content((5.0, 6.65), [`created: [id: string]`], size: 6pt)
  cdraw.content((5.0, 5.7), [`shipped: [id, at]`], size: 6pt)
  cdraw.line((9.6, 7.1), (11.4, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.6, 6.3), (11.4, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.4, 6.6), (17.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((14.4, 7.1), [`on("shipped", fn)`], size: 6pt)
  cdraw.line((17.4, 7.1), (18.4, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.6, 6.6), (22.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((20.6, 7.1), [arity checked], size: 6pt)
  cdraw.rect((11.4, 5.2), (17.4, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((14.4, 5.7), [`emit("shipped", ...)`], size: 6pt)
  cdraw.line((17.4, 5.7), (18.4, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.6, 5.2), (22.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.6, 5.7), [types checked], size: 6pt)
  cdraw.content((11.6, 3.8), [no stringly dispatch: the name is checked, never trusted], size: 6.5pt)
  cdraw.content((11.6, 2.8), [one consumer wired end to end in the sample], size: 6.5pt)
})

== defaults

The functional options pattern in typescript is a `Partial<Config>`
merged over defaults, one spread, no builder. `Partial` is chapter
17's one line mapped type, and the spread is part one's chapter 4:

#listing("javascript/tssamples/ch20/idioms.ts", first: 108, last: 116, caption: [Partial overrides over a default record])

#diagram([defaults, Partial over one spread, no builder], length: 13pt, {
  cdraw.content((11.6, 8.8), [one spread, no builder], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.2), (9.8, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.1, 6.8), [the default record: #linebreak() `host: "local", port: 8080, retries: 1`], size: 6pt)
  cdraw.line((5.1, 6.2), (5.1, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 6.2), (17.0, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 6.2), (22.8, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.6, 6.8), [`Partial<ServerConfig>`, #linebreak() the caller's overrides], size: 6pt)
  cdraw.rect((2.0, 4.2), (21.2, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 4.8), [the defaults inlined, `...overrides` last, #linebreak() `Server` returns the whole `ServerConfig`], size: 6pt)
  cdraw.rect((0.4, 2.8), (22.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.3), [later sources win: the caller overrides only what differs], size: 6pt)
  cdraw.content((11.6, 1.7), [`Partial` is chapter 17's one line mapped type, the spread is part one's chapter 4], size: 6.5pt)
})

== satisfies and const parameters

The two precision tools that moved here from chapter 17's operators.
`satisfies` checks a value against a contract without widening it,
and pairing it with `as const` keeps the literals while the
assignment is still verified, `port` stays `8080`, not `number`, so
`config.port + 1` is fine. A `const` type parameter does the same
for function arguments, supported in tsc 7.0.2 and pinned by this
suite: the rest parameter of `TupleOf` keeps its exact tuple type,
length and literal elements included, so destructuring the result is
precise:

#listing("javascript/tssamples/ch20/idioms.ts", first: 126, last: 135, caption: [satisfies plus as const, and a const type parameter])

#diagram([widening against satisfies, literals kept while checked], length: 13pt, {
  cdraw.content((5.5, 8.3), [the annotation widens], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.6), (10.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.1), [`config: Record<...>`], size: 6pt)
  cdraw.line((5.5, 6.6), (5.5, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 5.2), (10.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((5.5, 5.7), [`port` widened to `number`], size: 6pt)

  cdraw.content((17.5, 8.3), [satisfies keeps it], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.6), (22.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.5, 7.1), [`satisfies Record<...>`], size: 6pt)
  cdraw.line((17.5, 6.6), (17.5, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.4, 5.2), (22.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.7), [`port` stays `8080`, still checked], size: 6pt)

  cdraw.rect((2.6, 3.0), (10.6, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 3.5), [`<const T>` on a parameter], size: 6pt)
  cdraw.line((10.6, 3.5), (12.6, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.0, 3.0), (22.6, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((17.8, 3.5), [the tuple keeps length and literals], size: 6pt)
  cdraw.content((11.6, 2.0), [checked at the boundary, precise inside], size: 6.5pt)
})

== overloads against unions, and generics economy

Chapter 14 taught the overload mechanics, one implementation under
signatures callers see, and the default is still a union: most
functions with several input shapes want `input: string |
readonly string[]` and one body, because the caller who narrows the
input can narrow the output. The overload earns its place exactly
when the input shape decides the output shape, and no union
signature can say that:

#listing("javascript/tssamples/ch20/idioms.ts", first: 118, last: 124, caption: [the one overload that earns its place, input shape deciding output shape])

With the two overloads, `Parse("42")` is `number` and arithmetic on
it compiles bare, while `Parse(["1", "2"])` is `number[]` and has a
length. With the union signature alone, both callers would own
`number | number[]` and narrow it themselves, so the overloads
spend two lines to delete two guards at every call site.

#flow(
  [one body, two promises, the caller's guards deleted],
  node((0, 0), [`Parse("42")`]),
  node((3.4, 0), [overload 1: `number`]),
  node((6.8, 0), [`+ 1` compiles bare]),
  node((0, 2.4), [`Parse(["1", "2"])`]),
  node((3.4, 2.4), [overload 2: `number[]`]),
  node((6.8, 2.4), [`.length` compiles bare]),
  edge((0, 0), (3.4, 0), "-|>"),
  edge((3.4, 0), (6.8, 0), "-|>"),
  edge((0, 2.4), (3.4, 2.4), "-|>"),
  edge((3.4, 2.4), (6.8, 2.4), "-|>"),
)

The same economy question governs type parameters. Chapter 14's
rule, a generic must connect two positions or license member access
through a constraint, is the whole test, and most violations fail it
by being casts in disguise:

#snippet(
  "export function parse<T>(text: string): T {\n"
  + "  // compiles, and that is the problem: T connects nothing,\n"
  + "  // it is a double cast the caller gets to aim\n"
  + "  return JSON.parse(text) as T;\n"
  + "}\n",
  lang: "ts",
)

A generic that appears once in a signature buys no checking, hides
the real return type from inference, and pushes a cast onto every
caller. Write the concrete type, `unknown` plus a chapter 16
predicate when the value is untrusted, or a real parameter that
relates two positions the way `Parse` relates input to output.

sources: typescriptlang.org handbook more on functions, satisfying
the contract with satisfies, and const type parameters pages, the
community branding and result type conventions, accessed 2026-09-13.
Behavior verified live with tsc 7.0.2 and node 26.3.0 on windows,
12 tests in ch20 green through `npm run verify`, const type
parameter support confirmed by the compiling suite itself.
