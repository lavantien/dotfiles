#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= f\# 11: collections, pipelines, and async

Chapter 19 read the port's types. This chapter reads its motion: how
F\# code moves values from one function to the next. The pipe and
compose operators make function application read in data order, the
List, Array, and Seq modules carry the vocabulary LINQ gives C\#,
chapter 14, and computation expressions wrap both patterns around
effects like asynchrony. The same four files are the evidence, and
the parser and lexer carry most of the chapter: their slices show the
pipelines running in the working interpreter.

== the pipe and compose operators

`|>` applies left to right, `x |> f` is `f x`, so the data flows in
reading order instead of inside out. `>>` composes forward, `f >>
g` is a function that runs `f` then `g`. Both are ordinary functions
in the core library, `(|>)` and `(>>)`, not syntax, which is the
difference from C\#: chapter 4's extension members made LINQ read left
to right by putting every operator on the receiver, F\# reaches the
same reading with one infix operator over plain functions. The test
helper for the whole evaluator is the idiom in six lines:

#listing("csharp-net/fsharp/tests/FSharpBook.Tests/EvalTests.fs", first: 8, last: 13, caption: [the run helper, one pipe per stage, list out at the end])

#diagram([pipe and compose, library functions that read in data order], length: 13pt, {
  // the application lane and the composition lane, the c# note below
  cdraw.rect((0.0, 4.8), (3.2, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((1.6, 5.3), [x], size: 6pt)
  cdraw.line((3.2, 5.3), (5.2, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.2, 5.75), [`|>`], size: 6pt)
  cdraw.rect((5.4, 4.8), (8.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((7.0, 5.3), [f], size: 6pt)
  cdraw.line((8.6, 5.3), (10.6, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 5.75), [`|>`], size: 6pt)
  cdraw.rect((10.8, 4.8), (14.0, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((12.4, 5.3), [g], size: 6pt)
  cdraw.line((14.0, 5.3), (15.6, 5.3), stroke: luma(100))
  cdraw.content((14.8, 5.75), [=], size: 6pt)
  cdraw.content((18.6, 5.3), [`g (f x)`, data order], size: 6pt)
  cdraw.rect((0.0, 3.0), (3.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((1.6, 3.5), [f], size: 6pt)
  cdraw.line((3.2, 3.5), (5.2, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.2, 3.95), [`>>`], size: 6pt)
  cdraw.rect((5.4, 3.0), (8.6, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((7.0, 3.5), [g], size: 6pt)
  cdraw.line((8.6, 3.5), (10.2, 3.5), stroke: luma(100))
  cdraw.content((9.4, 3.95), [=], size: 6pt)
  cdraw.content((15.0, 3.5), [a function that runs `f` then `g`], size: 6pt)
  cdraw.content((11.3, 1.4), [both are core library functions, `(|>)` and `(>>)`, not syntax, #linebreak() c\# reached the same reading by putting every operator on the receiver], size: 6.5pt)
})

`Scan()` returns a `Token list`, `|> Array.ofList` rehouses it as an
array, and the parser wants the array because its cursor indexes by
position, constant time on arrays and linear on the linked list. The
last line converts the BCL `ResizeArray` back into an F\# list, the
boundary traffic this chapter keeps returning to. The `|> ignore`
idiom in the parser, applying the discard function to a value that
must be consumed, is the same operator doing ceremony removal.

== the collection modules against linq

F\#'s vocabulary lives in three modules, `List`, `Array`, and `Seq`,
one per collection kind: `List` over the immutable linked list,
`Array` over the CLR array, `Seq` over `IEnumerable<'T>`. LINQ's
operators from chapter 14's the operator families section all have
their counterparts, `List.filter` is `Where`, `List.map` is `Select`,
`List.collect` is `SelectMany`, `List.sortBy` is `OrderBy`, and
chapter 14's grouping and aggregation section maps `GroupBy` to
`List.groupBy` and `Aggregate` to `List.fold`. The lookup chapter 19
showed in the options section, `List.tryFind` feeding a `match`, is
the module's option returning flavor of LINQ's `FirstOrDefault`.

Two differences from LINQ are structural rather than notational.
Eagerness: `List` and `Array` functions materialize their result when
called, while `Seq` is lazy, the same split as chapter 14's deferred
execution section, where `Where` builds a plan and `ToList` runs it.
In F\# the choice is by module: `Seq.filter` returns a lazily
computed sequence, `List.filter` returns a finished list, and no
operator returns to change the decision. Joins: chapter 14's join and
let and outer joins sections have no `List` counterpart, relational
joining is LINQ's home ground, and the F\# posture is to fold or
recurs instead. The argument list in a call expression shows the
accumulate and convert pattern the modules are built on:

#listing("csharp-net/fsharp/src/FSharpBook/Parser.fs", first: 132, last: 141, caption: [resizearray accumulates, list.ofseq converts, the boundary is explicit])

`ResizeArray<'T>` is `List<'T>` under an F\# alias, chosen when
mutation is the honest tool, and converted back the moment it crosses
a boundary, which keeps each side of the code base in its own
vocabulary.

#diagram([the linq operator, the module function, and what changes], length: 13pt, {
  // three columns: operator, module, the structural difference
  let rows = (
    ([`Where`], [`List.filter`], [eager list, lazy seq]),
    ([`Select`], [`List.map`], [same two flavors]),
    ([`SelectMany`], [`List.collect`], [flatten, both modules]),
    ([`OrderBy`], [`List.sortBy`], [no thenby, sort by tuple]),
    ([`GroupBy`], [`List.groupBy`], [pairs of key and list]),
    ([`Aggregate`], [`List.fold`], [explicit seed and state]),
    ([`join`, `group join`], [none], [linq's home ground]),
  )
  cdraw.content((2.6, 6.9), [linq], size: 6.5pt)
  cdraw.content((8.0, 6.9), [f\# module], size: 6.5pt)
  cdraw.content((16.4, 6.9), [what to know], size: 6.5pt)
  for (i, row) in rows.enumerate() {
    let y = 6.0 - i * 0.92
    cdraw.content((2.6, y), row.at(0), size: 6pt)
    cdraw.content((8.0, y), row.at(1), size: 6pt)
    cdraw.line((12.0, y), (13.2, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((16.4, y), row.at(2), size: 6pt)
  }
})

== the lexer, index arithmetic over a string

The port's lexer walks the source string by index, the same design
as the C\# capstone's lexer, chapter 35's lexer section, with one
honest substitution: C\# walked a `ReadOnlySpan<char>` from a `ref
struct`, chapter 10's allocation free shape, and F\# indexes the
immutable `string` directly, `src.[pos]`, which is constant time but
not span based. The dispatch on the current character is four
branches:

#listing("csharp-net/fsharp/src/FSharpBook/Lexer.fs", first: 28, last: 37, caption: [digit, quote, letter, everything else, four dispatch branches])

Number scanning enforces the same malformed-double rule against the
character stream, one decimal point, digits after it, no second one:

#listing("csharp-net/fsharp/src/FSharpBook/Lexer.fs", first: 53, last: 67, caption: [digits, one decimal point, invariant parse at the end])

The symbol scanner is the chapter's payoff listing, a `match` over a
pair of characters with a tuple pattern per two character operator:

#listing("csharp-net/fsharp/src/FSharpBook/Lexer.fs", first: 111, last: 136, caption: [the two character operators first, then singles, else an error])

#diagram([the lexer, index arithmetic over the immutable string], length: 13pt, {
  // the one substitution on top, the four branch dispatch below
  cdraw.rect((0.0, 5.1), (10.4, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 5.95), [c\#: `ReadOnlySpan<char>` #linebreak() walked from a `ref struct`], size: 6pt)
  cdraw.line((10.4, 5.95), (11.6, 5.95), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.8, 5.1), (22.2, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((17.0, 5.95), [f\#: `src.[pos]`, indexing #linebreak() the immutable `string`], size: 6pt)
  cdraw.content((11.1, 4.75), [the same lexer design, one substitution, then four dispatch branches], size: 6.5pt)
  let branches = ([digit, #linebreak() number scan], [quote, #linebreak() string scan], [letter, #linebreak() word scan], [else, #linebreak() symbol scan])
  for (i, t) in branches.enumerate() {
    let x = 0.6 + i * 5.6
    cdraw.rect((x, 2.4), (x + 4.8, 4.1), fill: luma(205), radius: 0.02)
    cdraw.content((x + 2.4, 3.25), t, size: 6pt)
    cdraw.line((x + 2.4, 4.55), (x + 2.4, 4.12), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.1, 1.2), [symbols: a tuple match, one pattern #linebreak() per two character operator], size: 6.5pt)
})

== the parser, precedence by recursion

The C\# capstone encodes precedence as method depth, chapter 35's
parser section. The port encodes it as recursive local functions,
each level a `let rec loop` that folds its own operator set over the
next level down:

#listing("csharp-net/fsharp/src/FSharpBook/Parser.fs", first: 86, last: 119, caption: [the ladder, equality to unary, one loop per level])

The shape is the same claim as C\#'s: tighter binding operators sit
deeper and finish first, and each level looping over its own set is
what makes subtraction left associative. Statement dispatch is a
flat match over the leading token, `Check Let`, `Check Ident`, and
company, replacing the C\# if chain:

#listing("csharp-net/fsharp/src/FSharpBook/Parser.fs", first: 21, last: 33, caption: [statement dispatch, one branch per leading token])

#diagram([precedence as call depth, one recursive loop per level], length: 13pt, {
  // the ladder as a stack, loosest on top
  let levels = ([`Equality`], [`Comparison`], [`Additive`], [`Multiplicative`], [`Unary`], [`Primary`])
  for (i, t) in levels.enumerate() {
    let y = 6.2 - i * 1.05
    let f = if i == 5 { luma(205) } else { luma(230) }
    cdraw.rect((2.0, y - 0.45), (12.0, y + 0.45), fill: f, radius: 0.02)
    cdraw.content((7.0, y), t, size: 6pt)
  }
  cdraw.content((16.4, 6.2), [loosest, called first], size: 6.5pt)
  cdraw.content((16.4, 0.95), [tightest, finishes first], size: 6.5pt)
  cdraw.content((9.0, -0.5), [each level is a `let rec loop` over its operator set, #linebreak() the c\# capstone runs the same ladder as methods], size: 6.5pt)
})

== computation expressions

Sequences, asynchronous workflows, and tasks are not special cased
syntax in F\#, they are instances of one pattern, the computation
expression: braces after a builder name, `let!` binds a value in the
computation's world, `return` wraps, `use!` scopes a resource, and
the builder class supplies the plumbing. `seq { 1..10 }` builds a
lazy sequence because the `seq` builder's `Bind` yields, `async {
... }` builds a workflow because the `async` builder schedules. F\#
9 added empty bodied expressions, `seq { }`, by giving builders a
`Zero` default.

The one computation expression this book's C\# side cares about is
`task`, which maps directly onto `System.Threading.Tasks.Task`, the
same type chapter 9's async and await consume:

#snippet(
  "task {\n"
  + "    let! a = fetchA()\n"
  + "    and! b = fetchB()\n"
  + "    return a + b\n"
  + "}\n",
  lang: "f#",
)

#diagram([computation expressions, one pattern behind seq, async, and task], length: 13pt, {
  // the builder braces on top, the three instances below, the bind verbs in the note
  cdraw.rect((0.2, 5.6), (23.6, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 6.1), [braces after a builder name, the builder class supplies the plumbing], size: 6pt)
  let builders = ([`seq { 1..10 }`, #linebreak() its `Bind` yields, lazy], [`async { ... }`, #linebreak() its `Bind` schedules], [`task { ... }`, #linebreak() maps onto `Task`])
  for (i, t) in builders.enumerate() {
    let x = 0.2 + i * 8.0
    cdraw.rect((x, 3.1), (x + 7.4, 4.8), fill: luma(205), radius: 0.02)
    cdraw.content((x + 3.7, 3.95), t, size: 6pt)
    cdraw.line((x + 3.7, 5.6), (x + 3.7, 4.85), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.9, 1.9), [`let!` binds in the computation's world, `return` wraps, `use!` scopes, #linebreak() `and!` joins the two fetches, an f\# 10 addition], size: 6.5pt)
})

`and!` binds two computations together, so the two fetches run
concurrently rather than in sequence, the semantics of
`Task.WhenAll` without the combinator. The honest label: `and!` in
task expressions is an F\# 10 addition, the F\# 10 release notes
name it as such, it is not new in 11.

#callout("note", "the port contains no computation expression", [
  The four files behind chapters 19 through 21 use none of this.
  The lexer and parser are loops and recursion, the evaluator is
  synchronous end to end, and the code comment on the builtin table
  says why: `clock_async` left with async. The constructs matter
  here as the native form of what chapter 9 does with `await` and
  what chapter 35's evaluator section does with an awaited
  `RunAsync`, the F\# port deliberately took the smaller scope.
])

== async, deliberately absent

The C\# capstone's evaluator is async end to end, a cancellation
token through every await, chapter 35. The port is not, and the
omission is a scope decision the code states in a comment: async
came out, and the one async builtin, `clock_async`, came out with
it. What remains is the synchronous core, a dictionary of names, a
match per statement, and the remaining builtins computing values
with no awaits anywhere. The two designs are the two languages'
resting positions: C\# reaches for `async` methods that return
`Task<T>`, F\# for `task { ... }` blocks that build one. The port's
choice keeps the comparison honest, the same tree, the same tests,
one async dimension removed, and chapter 21 returns to what that
buys on the .NET side.

#diagram([async, deliberately absent, the port's smaller scope], length: 13pt, {
  // the capstone's async evaluator against the port's synchronous one
  cdraw.content((5.2, 6.9), [c\# capstone evaluator], size: 6.5pt)
  cdraw.rect((0.0, 4.8), (10.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 5.6), [async end to end, a cancellation #linebreak() token through every await], size: 6pt)
  cdraw.content((17.4, 6.9), [the f\# port], size: 6.5pt)
  cdraw.rect((12.2, 4.8), (22.6, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 5.6), [synchronous end to end, #linebreak() `clock_async` left with async], size: 6pt)
  cdraw.content((11.3, 3.1), [the same tree, the same tests, one async dimension removed, #linebreak() the omission keeps the two-language comparison honest], size: 6.5pt)
})

sources: learn.microsoft.com, f\# language reference, lists, arrays,
sequences, computation expressions, and task expressions pages, the
f\# 10 what's new page for `and!` in task expressions, accessed
2026-09-13. Sample behavior verified by `dotnet test
fsharp/FSharpBook.slnx`, 20 tests, zero skipped.
