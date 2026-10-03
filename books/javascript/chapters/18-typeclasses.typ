#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= classes and decorators

The runtime half of the class keyword is part one's chapter 4:
prototypes and the method chain, `#` private fields as runtime
brands, static fields and static blocks, accessors, and the
`instanceof` walk. Nothing here changes any of it, and the sample
file deliberately repeats none of it. What this chapter owns is the
type layer over that runtime: typed members, parameter properties,
`abstract`, the polymorphic `this` type, generic classes, and the
stage 3 decorator system. The one thing the class keyword still does
not buy is nominal typing, the instance type stays structural like
every other object type in chapter 15:

#listing("javascript/tssamples/ch18/classes.ts", first: 12, last: 26, caption: [parameter properties, ts private, and hash private in one class])

#diagram([three property systems, one bike, three visibilities], length: 13pt, {
  cdraw.content((4.2, 7.1), [member], size: 6.5pt, fill: luma(100))
  cdraw.content((10.4, 7.1), [checker], size: 6.5pt, fill: luma(100))
  cdraw.content((15.4, 7.1), [Object.keys], size: 6.5pt, fill: luma(100))
  cdraw.content((20.0, 7.1), [at emit], size: 6.5pt, fill: luma(100))

  let row(y, m, c, k, e, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.2, y + 0.7), m, size: 6pt)
    cdraw.content((10.4, y + 0.7), c, size: 6pt)
    cdraw.content((15.4, y + 0.7), k, size: 6pt)
    cdraw.content((20.0, y + 0.7), e, size: 6pt)
  }
  row(5.4, [param `owner: string`], [modifier decides], [listed], [own property], false)
  row(3.6, [`private n`], [forbidden outside], [listed], [plain property], true)
  row(1.8, [`#serial`], [invisible], [hidden], [runtime brand], false)

  for x in (7.2, 13.0, 17.4) { cdraw.line((x, 1.8), (x, 6.8), stroke: luma(220)) }
  cdraw.content((11.6, 0.8), [the getter is the only door to `#serial`], size: 6.5pt)
})

Parameter properties declare and assign in one place, and they still
exist in tsc 7.0.2: the constructor line `private readonly owner:
string` compiles through this book's own project and emits an own
data property named `owner` that `Object.keys` can see. The `#serial`
field compiles to the runtime brand chapter 4 measured, invisible to
`Object.keys` and unreachable by any cast, exposed only through the
typed getter. The ts `private` modifier sits between them: forbidden
by the checker, trivially present at runtime, the same erasure
story chapter 11 proved against the emitted file.

== abstract classes

`abstract` members must be overridden, and the `override` keyword
makes the override explicit, catching renamed base members at
compile time:

#listing("javascript/tssamples/ch18/classes.ts", first: 5, last: 10, caption: [an abstract base with one concrete requirement])

`abstract` is a checker fact only, and the sample proves it the rude
way, constructing the abstract base through a cast and calling into
the missing method:

#listing("javascript/tssamples/ch18/classes.ts", first: 69, last: 75, caption: [constructing the inconstructible])

#diagram([abstract classes, a checker fact against the cast], length: 13pt, {
  cdraw.content((5.8, 8.9), [what the checker holds], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 7.2), (11.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 7.7), [`new Vehicle()` rejected, the base is abstract], size: 6pt)
  cdraw.rect((0.4, 5.7), (11.2, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.2), [the missing `wheels()` must be overridden], size: 6pt)
  cdraw.rect((0.4, 4.2), (11.2, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 4.7), [`override` written out, #linebreak() a renamed base member fails the build], size: 6pt)

  cdraw.content((17.3, 8.9), [what the cast proves], size: 6.5pt, fill: luma(100))
  cdraw.rect((11.8, 7.2), (22.8, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 7.7), [`Vehicle as unknown as new () => Vehicle`], size: 6pt)
  cdraw.line((17.3, 7.2), (17.3, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.8, 5.7), (22.8, 6.7), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 6.2), [the construction runs, the base exists at runtime], size: 6pt)
  cdraw.rect((11.8, 4.2), (22.8, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 4.7), [`describe()` reaches the missing method], size: 6pt)

  cdraw.rect((0.4, 2.8), (22.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.3), [the rude proof: constructed through a cast, calling into the missing method], size: 6pt)
  cdraw.content((11.6, 1.7), [the checker's rejection is the only thing abstract ever was], size: 6.5pt)
})

== this types

A method may return `this` as its type, and the meaning is
polymorphic: through a `Loud` instance, `add` returns `Loud`, not
the `Fluent` that declared it, so a chain that ends in a subclass
method still compiles. A return type of the declaring class would
break the chain, since `Fluent` has no `shout`:

#listing("javascript/tssamples/ch18/classes.ts", first: 28, last: 45, caption: [a this typed chain that stays polymorphic through the subclass])

#flow(
  [one chain, two declarations, the subclass stays reachable],
  node((0, 0), [`new Loud()`]),
  node((2.6, 0), [`.add("a")` returns `this`]),
  node((5.2, 0), [`.shout()` compiles]),
  node((0, 2.4), [if `add` returned #linebreak() `Fluent<T>`]),
  node((2.6, 2.4), [`shout` is not on it]),
  node((5.2, 2.4), [the chain ends there]),
  edge((0, 0), (2.6, 0), "-|>"),
  edge((2.6, 0), (5.2, 0), "-|>"),
  edge((0, 2.4), (2.6, 2.4), "-|>"),
  edge((2.6, 2.4), (5.2, 2.4), "-|>"),
)

This is the class member's half of the checked `this`. Chapter 14
typed the receiver as a parameter, `this: void` on a free function,
and here the same word works as a return type inside a class, one
spelling, two positions, both erased.

== generic classes and structure

A generic class carries its type parameter per instance, and a
`Stack<T>` reads like the generic structures of the other books in
this series. The structural reminder sits beside it: a plain object
literal with `x` and `y` is a valid `Point2`, because instance types
do not carry identity:

#listing("javascript/tssamples/ch18/classes.ts", first: 47, last: 67, caption: [a generic stack, and a literal satisfying a class type])

#diagram([the generic class, the structural instance type, and the abstract cast], length: 13pt, {
  cdraw.content((5.0, 9.0), [per instance], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.4), (9.6, 8.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 6.85), [`class Stack\<T\>` #linebreak() the parameter rides #linebreak() each instance], size: 6pt)

  cdraw.content((17.5, 9.0), [structural], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 5.4), (22.6, 8.3), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 6.85), [`{ x: 1, y: 2 }` #linebreak() satisfies `Point2`, #linebreak() no lineage asked], size: 6pt)

  cdraw.content((11.6, 4.6), [the only runtime identity is the prototype chain, chapter 4's walk], size: 6.5pt)
})

== decorators

Stage 3 decorators are functions receiving the decorated element and
a context object carrying kind and name metadata. A class decorator
returns the class, a method decorator returns a replacement, and
both run once at class definition time, not per instance:

#listing("javascript/tssamples/ch18/classes.ts", first: 77, last: 98, caption: [a class decorator and a method decorator using their contexts])

#listing("javascript/tssamples/ch18/classes.ts", first: 100, last: 112, caption: [decorated class and method, and an auto accessor field])

The `accessor` keyword declares an auto accessor: one line of
declaration, a backing store plus getter and setter at runtime. The
descriptor on the prototype proves the member became an accessor
pair rather than a data field. `@registered` pushes the class name
into the log when `Widget` is defined, which is module evaluation
time, so the test observes it without constructing anything.
`@counted` wraps `double`, reads the method's name out of the
context, and records each call.

#flow(
  [decorators at definition time, wrappers at call time],
  node((0, 0), [the class is evaluated]),
  node((3.4, 0), [`@registered` runs, once]),
  node((6.8, 0), [the name is logged, #linebreak() the class returned]),
  node((0, 2.4), [the method is defined]),
  node((3.4, 2.4), [`@counted` wraps it]),
  node((6.8, 2.4), [each call logged, #linebreak() then the body runs]),
  node((0, 4.8), [`accessor value`]),
  node((3.4, 4.8), [becomes a pair]),
  node((6.8, 4.8), [over one backing store]),
  edge((0, 0), (3.4, 0), "-|>"),
  edge((3.4, 0), (6.8, 0), "-|>"),
  edge((0, 2.4), (3.4, 2.4), "-|>"),
  edge((3.4, 2.4), (6.8, 2.4), "-|>"),
  edge((0, 4.8), (3.4, 4.8), "-|>"),
  edge((3.4, 4.8), (6.8, 4.8), "-|>"),
)

#callout("note", "the measured status, 7.0.2 on this machine", [
  Stage 3 decorators are the default and need no flag: the sample
  above compiles through the project's `tsc` with nothing but the
  book's tsconfig. The `experimentalDecorators` flag still exists in
  7.0.2, it is not one of the removed options, and setting it
  selects the legacy one argument invocation: the same `registered`
  signature then fails with TS1238, which names the argument count.
  On the node side, 26.3.0 strip only mode rejects a decorated
  class with a plain `SyntaxError: Invalid or unexpected token`,
  without the typed `ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX` diagnostic
  enums and parameter properties get, so decorated code must ride
  the `tsc` emit of chapter 19, exactly what this book's verify
  chain does.
])

== implements and protected

`implements` closes the chapter the way it opens the type system:
the class is checked against an interface, `public` is the default
modifier written out, and `protected` reaches subclasses only, which
the test file confirms by reading `prefix` through `Rush` and
nowhere else:

#listing("javascript/tssamples/ch18/classes.ts", first: 114, last: 134, caption: [implements, public, and protected in one hierarchy])

#diagram([implements, public, and protected, who reaches what], length: 13pt, {
  cdraw.content((2.6, 8.0), [modifier], size: 6.5pt, fill: luma(100))
  cdraw.content((7.8, 8.0), [what it is], size: 6.5pt, fill: luma(100))
  cdraw.content((15.0, 8.0), [who reaches it], size: 6.5pt, fill: luma(100))
  cdraw.content((20.6, 8.0), [at emit], size: 6.5pt, fill: luma(100))

  let row(y, m, w, r, e, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.6, y + 0.7), m, size: 6pt)
    cdraw.content((7.8, y + 0.7), w, size: 6pt)
    cdraw.content((15.0, y + 0.7), r, size: 6pt)
    cdraw.content((20.6, y + 0.7), e, size: 6pt)
  }
  row(6.2, [`implements`], [the class checked #linebreak() against `Runnable`], [the members must exist], [gone], false)
  row(4.4, [`public`], [the default, written out], [everyone], [gone], true)
  row(2.6, [`protected`], [`prefix = "task:"`], [subclasses only: `Rush` reads it, #linebreak() the test file cannot], [gone], false)

  for x in (5.2, 11.8, 18.6) { cdraw.line((x, 2.6), (x, 7.6), stroke: luma(220)) }
  cdraw.content((11.6, 1.4), [the whole hierarchy erases to the same runtime], size: 6.5pt)
})

#callout("note", "what moved out of this chapter", [
  The old classes chapter demonstrated static evaluation order,
  static blocks, and accessor pairs as runtime behavior. All of that
  is part one's chapter 4 now, measured on plain javascript, and the
  suite cases that pinned it went with it. What stays here is the
  declaration layer over that runtime.
])

sources: typescriptlang.org handbook classes and decorators pages,
mdn class documentation, tc39 decorators proposal, accessed
2026-09-13. Behavior verified live with tsc 7.0.2 and node 26.3.0 on
windows, 11 tests in ch18 green through `npm run verify`. The
decorator counterfactuals measured against the cli with
`--ignoreConfig`, since 7.0 refuses a file argument beside a
tsconfig otherwise: stage 3 clean with no flags, TS1238 under
`--experimentalDecorators`, and the strip only `SyntaxError`
reproduced on node 26.3.0 directly.
