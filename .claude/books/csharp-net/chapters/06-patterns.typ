#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= pattern matching and control flow

Control flow in C\# is pattern driven. An `if` or `switch` does not merely
compare a value against constants, it matches an input against patterns
that can test runtime type, deconstruct position, walk properties, and
slice sequences, all while binding parts of the input to variables. This
chapter covers the full pattern inventory, the loop family, and the null
handling operators that remove most guards.

== the three constructs, the ten patterns

Patterns appear in three places: the `is` expression, the `switch`
statement, and the `switch` expression. The pattern kinds are: constant
(`32`), declaration (`string s`), type (`int[]`), relational (`> 212`),
logical (`and`, `or`, `not`), property (`{ Length: 3 }`), positional,
`var`, discard (`_`), and list. The property, positional, and list kinds
are recursive, any pattern can nest inside them.

#diagram([the pattern inventory, ten kinds, three hosts, the recursive three], length: 13pt, {
  // ten kinds in two columns, the hosts and the nesting rule at right
  let kinds = (
    [constant `32`], [declaration `string s`], [type `int[]`], [relational `> 212`], [logical `and or not`],
    [property `{ }`], [positional `(x, y)`], [`var`], [discard `_`], [list `[1, ..]`],
  )
  for i in range(10) {
    let col = calc.floor(i / 5)
    let row = calc.rem(i, 5)
    let x0 = 0.4 + col * 7.8
    let y = 6.0 - row * 1.15
    cdraw.rect((x0, y - 0.5), (x0 + 7.0, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 3.5, y), kinds.at(i), size: 6pt)
  }
  cdraw.rect((16.2, 3.6), (23.6, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((19.9, 5.2), [three hosts: `is`, #linebreak() `switch` statement, #linebreak() `switch` expression], size: 6pt)
  cdraw.rect((16.2, 0.2), (23.6, 3.0), fill: luma(230), radius: 0.02)
  cdraw.content((19.9, 1.6), [property, positional, #linebreak() and list nest #linebreak() any pattern], size: 6pt)
})

== the switch expression

The switch expression turns selection into an expression that produces a
value. Arms are tested top to bottom and the first match wins:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 16, last: 24, caption: [relational, constant, and discard arms in one switch expression])

#diagram([switch expression arms, top to bottom, first match wins], length: 13pt, {
  // the input flows into a stack of arms, evaluation walks down it
  cdraw.rect((0.4, 3.4), (2.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((1.4, 3.9), [`f`], size: 6pt)
  cdraw.line((2.4, 3.9), (3.8, 3.9), stroke: luma(100), mark: (end: ">"))
  let arms = (`< 32`, `32`, `< 212`, `212`, `_`)
  for i in range(5) {
    let y = 6.0 - i * 1.25
    cdraw.rect((3.8, y - 0.5), (7.0, y + 0.5), fill: luma(230), radius: 0.02)
    cdraw.content((5.4, y), arms.at(i), size: 6pt)
  }
  cdraw.line((7.6, 5.3), (7.6, 1.2), stroke: luma(220))
  cdraw.line((7.0, 5.3), (7.6, 5.3), stroke: luma(220))
  cdraw.line((7.0, 1.2), (7.6, 1.2), stroke: luma(220))
  cdraw.content((13.4, 5.4), [tested top to bottom, #linebreak() first match wins], size: 6.5pt)
  cdraw.content((13.4, 2.4), [compiler warns when the #linebreak() arms can miss inputs], size: 6.5pt)
  cdraw.content((7.0, 0.0), [`_` covers the rest, without it a runtime miss throws `SwitchExpressionException`], size: 6.5pt)
})

The compiler warns when the arms do not cover all possible inputs, which
is why explicit boundary arms like `32` and `212` exist even where the
relational arms would return the same string. If no arm matches at
runtime, the expression throws `SwitchExpressionException`, so an
exhaustive arm set or a discard is not cosmetic.

A `when` clause guards an arm with an arbitrary boolean expression when
the pattern alone cannot express the condition:

#snippet(
  "var label = reading switch\n"
  + "{\n"
  + "    { Celsius: < 0 } r when r.Sensor == \"north\" => \"frozen north\",\n"
  + "    { Celsius: < 0 } => \"frozen\",\n"
  + "    _ => \"ok\",\n"
  + "};\n",
  lang: "cs",
)

== switching over unions without a fallback

The union from chapter 3 hands this machinery a complete domain. A
switch over `Pet` that names every case is exhaustive, the compiler
accepts it with no discard arm, and the `_ =>` habit that silently
swallowed future cases is gone:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 124, last: 131, caption: [every case named, no fallback arm])

Leave a case out and the compiler says so. Dropping the `Bird` arm
from that switch produces warning CS8509, verbatim: The switch
expression does not handle all possible values of its input type (it
is not exhaustive). For example, the pattern
'CsharpBook.Samples.Ch03.Bird' is not covered. The message names the
missing case by its fully qualified name. It is a warning, so the
build still succeeds, and the failure moves to runtime: feed the
switch a bird and it throws
`System.Runtime.CompilerServices.SwitchExpressionException`.
That combination, clean build plus a value that crashes later, is why
CS8509 should not stay a warning:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 132, last: 140, caption: [the bird arm deliberately missing, CS8509 suppressed at this one spot])

#callout("warning", "promote CS8509 to an error", [
  The samples suite compiles with zero warnings because its switches
  are exhaustive, with one exception: the helper above exists to
  demonstrate the runtime failure, so it suppresses CS8509 on that
  one method and the test suite watches the throw. CI should do the
  opposite of that pragma, `<WarningsAsErrors>CS8509</WarningsAsErrors>`
  in the project file or `dotnet build -warnaserror:CS8509`, so a
  missed case can never ride a green build into production.
])

#diagram([exhaustive versus non exhaustive, where the unmatched value lands], length: 13pt, {
  // left: three arms close the domain, right: a gap falls to the throw
  cdraw.content((4.6, 6.8), [exhaustive], size: 7pt)
  cdraw.rect((0.4, 3.0), (8.8, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.6, 4.6), [`Cat`, `Dog`, `Bird` #linebreak() the domain, covered], size: 6pt)
  cdraw.line((8.8, 4.6), (10.2, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 3.4), (15.2, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 4.6), [no `_` arm #linebreak() none needed], size: 6pt)
  cdraw.content((15.6, 6.8), [bird arm dropped], size: 7pt)
  cdraw.rect((15.6, 3.0), (24.0, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((19.8, 5.3), [`Cat`, `Dog` handled], size: 6pt)
  cdraw.rect((16.4, 3.6), (23.2, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((19.8, 4.1), [the `Bird` value falls through], size: 6pt)
  cdraw.content((19.8, 2.2), [`SwitchExpressionException` #linebreak() after a warning-free-looking build], size: 6.5pt)
})

== property patterns

A property pattern matches when the input is non-null and every nested
pattern matches the corresponding property. Extended property patterns
walk with dots, and the `or` combinator joins alternatives:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 26, last: 28, caption: [an extended property pattern with a logical or inside])

#diagram([a property pattern, every nested sub-pattern must match], length: 13pt, {
  // the input drops onto a row of gates, all of them must say yes
  cdraw.rect((10.3, 5.4), (12.7, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 5.9), [`r`], size: 6pt)
  cdraw.line((11.5, 5.4), (11.5, 4.3), stroke: luma(100), mark: (end: ">"))
  let gates = (
    ((0.4, 8.0), [`Sensor: "north"`]),
    ((8.6, 8.0), [`Hour: > 22 or < 4`]),
    ((16.8, 7.6), [`Celsius: > 30m`]),
  )
  for ((x0, w), t) in gates {
    cdraw.rect((x0, 3.0), (x0 + w, 4.2), fill: luma(230), radius: 0.02)
    cdraw.content((x0 + w / 2, 3.6), t, size: 6pt)
  }
  cdraw.content((4.2, 2.2), [and], size: 6.5pt)
  cdraw.content((12.4, 2.2), [and], size: 6.5pt)
  cdraw.content((11.5, 1.0), [the input must be non-null and every sub-pattern must match], size: 6.5pt)
  cdraw.content((11.5, -0.3), [`is { } x` matches any non-null input and binds it], size: 6.5pt)
})

The empty property pattern `is { } x` matches anything non-null and binds
it, a compact form of the not-null check that also produces a variable.

== positional patterns

A positional pattern calls the type's `Deconstruct` method and matches
the results against nested patterns. Records deconstruct for free, so a
record becomes a set of coordinates you can branch on:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 30, last: 40, caption: [a plane split by nested relational patterns])

#diagram([positional patterns, deconstructed coordinates split the plane], length: 13pt, {
  // the record feeds Deconstruct, the pair of values lands on a quadrant
  cdraw.rect((0.4, 3.4), (2.2, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((1.3, 3.9), [`v`], size: 6pt)
  cdraw.line((2.2, 3.9), (3.4, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.4, 3.1), (8.6, 4.7), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 3.9), [`Deconstruct` #linebreak() free on records], size: 6pt)
  cdraw.line((8.6, 4.2), (9.8, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.6, 3.6), (9.8, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 5.0), [`x`], size: 6pt)
  cdraw.content((9.6, 2.7), [`y`], size: 6pt)
  cdraw.line((13.4, 2.4), (20.8, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 0.3), (16.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.4, 3.7), [northwest], size: 6.5pt)
  cdraw.content((18.4, 3.7), [northeast], size: 6.5pt)
  cdraw.content((14.4, 1.2), [southwest], size: 6.5pt)
  cdraw.content((18.4, 1.2), [southeast], size: 6.5pt)
  cdraw.content((17.5, 2.75), [(0, 0)], size: 6pt)
})

== list patterns

A list pattern matches an array or list element by element. A slice
`..` absorbs zero or more elements and can itself capture with `var`:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 42, last: 49, caption: [empty, single, and first-middle-last shapes])

#diagram([list patterns, element wise with a slice in the middle], length: 13pt, {
  // the pattern at left, the cells it eats at right, shapes below
  cdraw.rect((0.4, 4.4), (6.0, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 5.1), [`[first,` #linebreak() `.. middle, last]`], size: 6pt)
  cdraw.line((6.0, 5.1), (7.2, 5.1), stroke: luma(100), mark: (end: ">"))
  for i in range(6) {
    let f = if i == 0 or i == 5 { luma(205) } else { luma(230) }
    cdraw.rect((7.6 + i * 1.4, 4.6), (8.9 + i * 1.4, 5.6), fill: f, radius: 0.02)
  }
  cdraw.content((8.25, 3.9), [`first`], size: 6pt)
  cdraw.content((15.25, 3.9), [`last`], size: 6pt)
  cdraw.line((9.3, 5.9), (14.5, 5.9), stroke: luma(220))
  cdraw.line((9.3, 5.6), (9.3, 5.9), stroke: luma(220))
  cdraw.line((14.5, 5.6), (14.5, 5.9), stroke: luma(220))
  cdraw.content((11.9, 6.5), [`..` absorbs zero or more, `var` captures it], size: 6.5pt)
  let shapes = (
    ((0.6, 4.2), [`[]` #linebreak() empty]),
    ((5.4, 4.6), [`[x]` #linebreak() single]),
    ((10.6, 6.4), [`[a, .., z]` #linebreak() first and last]),
  )
  for ((x0, w), t) in shapes {
    cdraw.rect((x0, 0.8), (x0 + w, 2.6), fill: luma(245), radius: 0.02)
    cdraw.content((x0 + w / 2, 1.7), t, size: 6pt)
  }
})

== one switch, several patterns

The classifier below mixes constant, declaration, type, property, and
var patterns in a single expression. Note the `int[] { Length: var n }`
arm, a type pattern extended with a property pattern that binds through
a var pattern:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 51, last: 58, caption: [constant, declaration, type, and nested var patterns])

#diagram([one switch expression, four pattern kinds composed], length: 13pt, {
  // the kind on the left, the arm that uses it on the right
  let rows = (
    ([constant], [`null` => -1]),
    ([declaration], [`string s` => `s.Length`]),
    ([type + property + `var`], [`int[] { Length: var n }` => `n`]),
    ([discard], [`_` => -2]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.4
    cdraw.content((2.4, y), row.at(0), size: 6.5pt)
    cdraw.line((6.2, y), (7.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.2, y), row.at(1), size: 6pt)
  }
})

#callout("note", "pattern combinators have precedence", [
  `not` binds before `and`, which binds before `or`. The pattern
  `not >= 'a' and <= 'z'` parses as `(not >= 'a') and <= 'z'` and never
  matches what you meant. Parenthesize the range: `not (>= 'a' and
  <= 'z')`. The compiler cannot help you here, the wrong version is
  legal code.
])

== the switch statement and goto

The `switch` statement is the older form, a statement per arm with no
fall-through between sections. Multiple labels may share one section,
and `goto case` moves control deliberately when a section should
continue into another:

#snippet(
  "switch (shape.Kind)\n"
  + "{\n"
  + "    case Kind.Circle:\n"
  + "    case Kind.Ellipse:        // two labels, one section\n"
  + "        return Round(shape);\n"
  + "    case Kind.Path when shape.Points > 100:\n"
  + "        goto case Kind.Polygon;  // explicit fall-through\n"
  + "    case Kind.Polygon:\n"
  + "        return Triangulate(shape);\n"
  + "    default:\n"
  + "        return shape;\n"
  + "}\n",
  lang: "cs",
)

#flow(
  [switch statement sections, shared labels and the one explicit goto],
  node((0, 0), [Circle]),
  node((0, 1.1), [Ellipse]),
  node((3.0, 0.55), [section: Round]),
  node((0, 2.6), [Path, #linebreak() when Points > 100]),
  node((0, 4.2), [Polygon]),
  node((3.0, 4.2), [section: Triangulate]),
  edge((0, 0), (3.0, 0.55), "-|>"),
  edge((0, 1.1), (3.0, 0.55), "-|>"),
  edge((0, 2.6), (0, 4.2), "-|>", label: [goto case]),
  edge((0, 4.2), (3.0, 4.2), "-|>"),
)

New code prefers the switch expression, which cannot fall through at
all. Reach `if` and the ternary `?:` before reaching for a switch when
there are one or two cases.

== loops

The four loops. `for` when an index is needed, `foreach` over anything
enumerable, `while` tests before running, `do` tests after and so runs
at least once:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 60, last: 80, caption: [for with continue, foreach with break])

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 82, last: 92, caption: [while counts down])

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 94, last: 103, caption: [do while runs before it checks])

#diagram([four loop shapes, where the test sits in each], length: 13pt, {
  // four panels, a two node cycle each, the test placed differently
  let panels = (
    ([`for`], [test: `i < n`], [body, `i++`], [index carried]),
    ([`foreach`], [`MoveNext()`], [body], [pulls each item]),
    ([`while`], [test first], [body], [may skip entirely]),
    ([`do`], [body first], [test], [never skips]),
  )
  for (i, (title, a, b, note)) in panels.enumerate() {
    let x0 = i * 6.0
    cdraw.content((x0 + 2.5, 6.5), title, size: 7pt)
    cdraw.rect((x0 + 0.4, 4.6), (x0 + 4.6, 5.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 5.1), a, size: 6pt)
    cdraw.line((x0 + 2.5, 4.6), (x0 + 2.5, 3.4), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((x0 + 0.4, 2.4), (x0 + 4.6, 3.4), fill: luma(230), radius: 0.02)
    cdraw.content((x0 + 2.5, 2.9), b, size: 6pt)
    cdraw.line((x0 + 0.7, 2.9), (x0 + 0.7, 5.1), stroke: luma(220), mark: (end: ">"))
    cdraw.content((x0 + 2.5, 1.3), note, size: 6.5pt)
  }
})

`goto` also jumps to a label and cannot jump into a block, only out
of one. For escaping nested loops, the labeled jumps below have
retired it, `goto case` in a switch statement is its remaining
everyday use.

== labeled break and continue

C\# 15 lets `break` and `continue` name their target. The label sits
directly on an enclosing loop, `rows: foreach (...)`, and the jump
names it: `continue rows;` starts the next iteration of that loop,
`break rows;` leaves it and everything nested inside it. The two
workarounds this replaces are the Boolean flag copied out level by
level and the `goto` aimed past the loops, and the IDE0410 style rule
flags both:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 142, last: 158, caption: [continue rows abandons a row, break rows ends the whole scan])

The rules are small. `break` can name an enclosing loop or `switch`
statement, `continue` names loops only, because starting the next
iteration of a `switch` is meaningless. Only the statement immediately
under a label carries it, `a: b: while (...)` labels the `while` as
`b`, so `break a;` inside finds no target. Naming a label with no
enclosing loop or switch to break is error CS9393, no enclosing loop
to continue is CS9394. The label can sit on any of the four loop
kinds, the second sample names a `foreach` and jumps from a `while`
nested two levels down:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 160, last: 178, caption: [the label names a foreach, the break comes from a nested while])

#diagram([labeled exits, break rows leaves, continue rows advances], length: 13pt, {
  // three rows of cells, a poison cell, the two labeled exits
  for r in range(3) {
    for c in range(3) {
      let f = if r == 1 and c == 1 { luma(205) } else { luma(235) }
      cdraw.rect((6.0 + c * 2.2, 4.6 - r * 1.4), (7.8 + c * 2.2, 5.6 - r * 1.4), fill: f, radius: 0.02)
    }
  }
  cdraw.content((9.1, 3.1), [poison], size: 6pt)
  cdraw.content((4.6, 5.1), [rows:], size: 6.5pt)
  cdraw.line((5.4, 5.1), (6.0, 5.1), stroke: luma(100))
  cdraw.content((3.4, 3.7), [row two], size: 6pt)
  cdraw.line((12.8, 5.1), (15.4, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.2, 5.6), [`continue rows`, #linebreak() next row, rest skipped], size: 6.5pt)
  cdraw.line((12.8, 3.1), (15.4, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.2, 2.6), [`break rows`, #linebreak() every loop ends], size: 6.5pt)
  cdraw.content((8.4, 0.3), [`break` also names a switch, `continue` names loops only], size: 6.5pt)
})

== the null operators

Four operators carry most null handling. `?.` accesses a member only
when the receiver is non-null, short-circuiting the rest of the chain.
`?[]` is the same for element access. `??` yields the right operand when
the left is null. `??=` assigns only when the left is null:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 105, last: 106, caption: [null conditional indexer access])

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 108, last: 114, caption: [coalescing assignment as lazy init])

C\# 14 extends the family with null conditional assignment, making
`?.` and `?[]` valid assignment targets. The right side evaluates only
when the receiver is non-null, so the guard and the write are one
statement:

#listing("csharp-net/samples/src/Ch06/Flow.cs", first: 116, last: 122, caption: [chains, fallbacks, and C\# 14 conditional assignment])

#diagram([the null operators, what each short circuits], length: 13pt, {
  // the operator on the left, the rule it follows on the right
  let rows = (
    ([`?.`], [receiver once, null skips the rest]),
    ([`?[]`], [the same rule for element access]),
    ([`??`], [the right operand when the left is null]),
    ([`??=`], [assigns only when the left is null]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.3
    cdraw.rect((0.4, y - 0.5), (2.6, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((1.5, y), row.at(0), size: 6pt)
    cdraw.line((2.6, y), (3.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((10.6, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((10.6, 0.0), [c\# 14 makes `?.` a valid assignment target, #linebreak() the guard and the write are one statement], size: 6.5pt)
})

#callout("note", "why ?. exists", [
  `a?.M()` evaluates `a` once and cannot be rewritten as a plain check
  when `a` is a field another thread may write to between the test and
  the call. That single evaluation rule is also what makes
  `handler?.Invoke(...)` the thread safe way to raise an event, chapter
  7 covers that use.
])

sources: learn.microsoft.com, patterns, switch expression, selection
statements, iteration statements, member access operators, null
coalescing operator, and c\# null operators pages accessed 2026-09-08,
labeled break and continue, jump statements, and jump statement errors
pages accessed 2026-09-13. Sample behavior verified by
`make verify-csharp`, 29 tests.
