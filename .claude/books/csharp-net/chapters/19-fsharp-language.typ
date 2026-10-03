#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= f\# 11: values, functions, and types

Chapter 18 ended with a promise: the five pieces of functional C\# are
loans, and the lender is a real language. These three chapters pay the
visit. The same repo carries a second implementation of the
interpreter, `books/csharp-net/fsharp/`, four F\# files and a test
project, built with the same `dotnet test` verbs on the same pinned
SDK 11.0.100-rc.1. This chapter reads the language core on that code,
let bindings through options, chapter 20 reads collections, pipelines,
and async, and chapter 21 reads the .NET side. The tree is real and
small, 497 lines across four files, so every claim below has a file
and a line.

== let bindings and immutability

`let` is the only binding form. It binds a name to a value or a
function, and the binding is immutable by default: reassigning a `let`
bound name is a compile error, so the value a name refers to cannot
change under a reader. Mutation exists but must ask for it, `let
mutable`, and assignment uses `<-` rather than `=`, so the two
intentions never look alike. The lexer is the one place in the port
that needs mutable state, a cursor over the source string, and its
declaration is honest about it:

#listing("csharp-net/fsharp/src/FSharpBook/Lexer.fs", first: 12, last: 17, caption: [the lexer class, two mutable fields, everything else immutable])

#diagram([let as the only binding form, immutable by default, mutation asking], length: 13pt, {
  // the form on the left, what it buys on the right
  let rows = (
    ([`let x = v`], [immutable by default, reassignment #linebreak() is a compile error]),
    ([`let mutable`, then `<-`], [mutation must ask, the assignment #linebreak() sign never looks like `=`]),
    ([the lexer's cursor], [`pos` and `line` over the source, #linebreak() the port's one honest mutable use]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.6 - i * 1.6
    cdraw.rect((0.2, y - 0.5), (6.6, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y), row.at(0), size: 6pt)
    cdraw.line((6.6, y), (7.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.4, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((13.4, 0.4), [a `let` binding initializes from its right #linebreak() hand side, always], size: 6.5pt)
})

The `src` parameter, the `pos` and `line` cursors, and every helper
bound below them are values with fixed identity. The C\# reflex of
declaring first and assigning later does not exist: a `let` binding
initializes from its right hand side, always. Chapter 3's nullable
reference types exist because C\# locals and fields can hold `null`.
In F\# a name either has a value or has type `option`, the last
section of this chapter.

== functions as values

Functions are let bindings too, with argument names before the colon
and no ceremony around passing them around. A function value can sit
in a list, travel as an argument, come back as a return value, and the
test suite opens with two:

#listing("csharp-net/fsharp/tests/FSharpBook.Tests/LexerTests.fs", first: 7, last: 10, caption: [two helpers, one wrapping a method, one transforming a list])

`lex` wraps constructor and method calls into a plain function of
`string` to `Token list`. `kinds` composes `lex` with a lambda over
`List.map`, and the lambda is just another value passed as the
argument. There is no delegate type, no `Func<_,_>`, no declaration
tax on a function the way chapter 7's `delegate` family taxes C\#:
every function is curried by default, `f a b` means apply `f` to `a`
and then to `b`, and partial application, fixing the first argument
and keeping the rest, falls out of the syntax with no new constructs.

The xunit facts make the same point from another side. A test is a
let bound function marked with an attribute:

#listing("csharp-net/fsharp/tests/FSharpBook.Tests/LexerTests.fs", first: 12, last: 20, caption: [a fact is a let bound function, the attribute names the unit])

#diagram([functions as values, the delegate tax c\# pays against the f\# default], length: 13pt, {
  // left: the c# declaration tax, right: the f# shape where none is owed
  cdraw.content((5.2, 6.9), [c\#, the declaration tax], size: 6.5pt)
  cdraw.rect((0.0, 4.7), (10.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 5.55), [a delegate type per shape, #linebreak() `Func<_,_>` wrappers, chapter 7], size: 6pt)
  cdraw.content((17.4, 6.9), [f\#, functions are values], size: 6.5pt)
  cdraw.rect((12.2, 4.0), (22.6, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 5.2), [a function is a `let` binding #linebreak() curried by default, `f a b` #linebreak() partial application falls out], size: 6pt)
  cdraw.content((11.3, 2.7), [a fact is a `let` bound function under `[<Fact>]`, it sits in a list, #linebreak() travels as an argument, comes back as a return value], size: 6.5pt)
})

#callout("note", "an attribute on a non function is now a warning", [
  F\# 10 enforces attribute targets across let bound values and
  functions. Before it, `[<Fact>]` on a value rather than a function
  compiled silently and the test runner ignored it, a test that could
  never fail. The compiler now warns FS0842 that the attribute's valid
  target is a method. The fact above takes `()` and is a real
  function, so it runs.
])

== type inference

Annotations are rare. `Token list` on `Scan`, `TokenKind` and `string`
on the record fields, and almost nothing else: the lexer infers
`ResizeArray<Token>` from its constructor, the parser infers the
`Stmt list` it accumulates, and `kinds` above infers
`string -> TokenKind list` from use alone. The inference is two phase
and left to right, values are generalized where the language allows,
and the places F\# still wants a type are the places a reader would:
method arguments at object boundaries and recursive functions, which
name themselves with `rec` so the compiler knows the cycle. Compared
with `var` in C\#, the inference runs in the other direction: `var`
infers a left hand side from a known right hand side, F\# infers the
right hand side from how the value is used.

#diagram([the two inference directions, `var` from a known right, f\# from use], length: 13pt, {
  // the c# lane and the f# lane, each read left to right, notes below
  cdraw.content((3.4, 6.6), [c\#: `var`], size: 6.5pt)
  cdraw.content((3.4, 5.5), [a known right hand side], size: 6pt)
  cdraw.line((6.6, 5.5), (7.6, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.8, 5.5), [`var x = ...`], size: 6pt)
  cdraw.line((13.0, 5.5), (14.0, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.8, 5.5), [the left hand side, inferred], size: 6pt)
  cdraw.content((3.4, 3.9), [f\#: use alone], size: 6.5pt)
  cdraw.content((3.4, 2.8), [how the value is used], size: 6pt)
  cdraw.line((6.6, 2.8), (7.6, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.8, 2.8), [inference], size: 6pt)
  cdraw.line((13.0, 2.8), (14.0, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.8, 2.8), [the right hand side, inferred], size: 6pt)
  cdraw.content((11.0, 1.0), [`kinds` infers `string -> TokenKind list` from use alone, #linebreak() a cycle names itself `rec`], size: 6.5pt)
})

== records

The `Token` type is a record, five labeled fields in braces:

#listing("csharp-net/fsharp/src/FSharpBook/Ast.fs", first: 13, last: 18, caption: [the token record, five fields, immutable, structurally compared])

#diagram([one brace declaration, the compiled shape reflection measures], length: 13pt, {
  // the source form on top, the measured compiled shape below
  cdraw.rect((0.2, 5.5), (23.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 6.0), [`{ Kind: TokenKind; Text: string; ... Line: int }`], size: 6pt)
  cdraw.line((11.9, 5.5), (11.9, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.9, 5.0), [reflection on the built library], size: 6.5pt)
  cdraw.rect((0.2, 0.9), (23.6, 4.5), fill: luma(205), radius: 0.02)
  cdraw.content((11.9, 3.7), [a class with five read-only properties], size: 6pt)
  cdraw.content((11.9, 2.95), [one constructor taking all five fields], size: 6pt)
  cdraw.content((11.9, 2.2), [no `Deconstruct`, no init setters, no `with` cloning], size: 6pt)
  cdraw.content((11.9, 1.45), [equality and printing live in the f\# core library], size: 6pt)
})

One declaration buys what C\# spends a `record` on, chapter 3's
records section: structural equality, a readable printing, and
immutability without opting in. Copy and update uses `with` in braces,
`{ token with Line = 3 }`, the same nondestructive mutation the C\#
keyword offers. The compiled shape differs from a C\# record in one
way a consumer feels: measured by reflection on the built library, F\#
compiles `Token` to a class with five read-only properties, one
constructor taking all five fields, and no `Deconstruct`, `with`-
style cloning, or init setters. Equality and printing live in the F\#
core library and generated code, not in the type's own members.

== discriminated unions

The expression tree is one declaration:

#listing("csharp-net/fsharp/src/FSharpBook/Ast.fs", first: 21, last: 39, caption: [expressions, statements, and the program, three unions over labeled fields])

`Expr` is a choice of seven cases, each carrying labeled fields inline,
and one case nests the type itself, `UnaryExpr` holds an `Expr`, which
is the whole recursion with no extra declaration. The file also
carries `TokenKind`, a union whose cases carry nothing, F\#'s
spelling of C\#'s `enum`, chapter 3's enums section.

This is the same idea as the C\# 15 union of chapter 3's union types
section, and the difference is entirely in the runtime representation.
The measured shapes, reflection over both builds under the pinned SDK:

#diagram([same idea, two runtimes, the union in c\# and the du in f\#], length: 13pt, {
  // declaration at top, the two compiled shapes below, one text line per row
  cdraw.rect((0.2, 5.0), (23.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 5.6), [`type Expr = NumberExpr of value: float * line: int | ...`], size: 6pt)
  cdraw.line((6.0, 5.0), (6.0, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.8, 5.0), (17.8, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 1.0), (11.8, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((6.0, 3.7), [f\# du], size: 6.5pt)
  cdraw.content((6.0, 2.95), [an abstract class], size: 6pt)
  cdraw.content((6.0, 2.2), [one nested class per case], size: 6pt)
  cdraw.content((6.0, 1.45), [a reference type, equality generated], size: 6pt)
  cdraw.rect((12.0, 1.0), (23.6, 4.2), fill: luma(230), radius: 0.02)
  cdraw.content((17.8, 3.7), [c\# 15 union], size: 6.5pt)
  cdraw.content((17.8, 2.95), [a sealed struct implementing `IUnion`], size: 6pt)
  cdraw.content((17.8, 2.2), [`object Value` holds the case], size: 6pt)
  cdraw.content((17.8, 1.45), [a value type, conversions in], size: 6pt)
})

F\# compiles the union to an abstract class `Expr` with a nested class
per case, each deriving from it, heap allocated and polymorphic. C\#
15 compiles its union to a sealed struct wrapping an `object` that
holds the case, stack friendly and boxing under the rules chapter 3
measured. Neither carries a discriminant field: the runtime type is
the tag in F\#, the case type's identity is the tag in C\#. The C\#
record cases of the capstone tree, `Kind` tag and all, chapter 35's
tree section, correspond to F\#'s labeled fields, `of value: float *
line: int`, which ride inside the case class as read-only properties.

== pattern matching and exhaustiveness

`match` is the branch form and it deconstructs as it branches. The
lexer's keyword table is the smallest honest example:

#listing("csharp-net/fsharp/src/FSharpBook/Lexer.fs", first: 99, last: 109, caption: [keywords as a match over the scanned word, the wildcard closes it])

#diagram([match deconstructing as it branches, the incomplete case warned], length: 13pt, {
  // a match over the domain flows to two outcomes, the missing case warned
  cdraw.rect((0.6, 5.0), (10.6, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.6, 5.85), [a `match` over the union, #linebreak() deconstructing in the arm], size: 6pt)
  cdraw.line((5.6, 5.0), (5.6, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 2.6), (10.6, 4.3), fill: luma(205), radius: 0.02)
  cdraw.content((5.6, 3.45), [names every case #linebreak() compiles, the proof holds], size: 6pt)
  cdraw.content((5.6, 1.75), [the wildcard `_` is the discard, #linebreak() the evaluator's six `Stmt` arms carry none], size: 6.5pt)
  cdraw.line((10.6, 5.85), (11.8, 5.85), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 5.35), (21.8, 6.35), fill: luma(235), radius: 0.02)
  cdraw.content((16.9, 5.85), [misses a case], size: 6pt)
  cdraw.line((16.9, 5.35), (16.9, 4.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 2.95), (21.8, 4.65), fill: luma(205), radius: 0.02)
  cdraw.content((16.9, 3.8), [FS0025, incomplete pattern #linebreak() match, a warning by default], size: 6pt)
  cdraw.content((16.9, 2.2), [CS8509's parity, the same #linebreak() warning for a c\# switch], size: 6.5pt)
})

The wildcard `_` is the discard chapter 6 measured in C\#. What F\#
adds is deconstruction in the arm: `match x.MatchAny [EqEq; BangEq]
with | Some op -> ... | None -> ...` tests and unwraps in one line,
the same reach C\# 15 patterns get through union aware `is`, chapter
3. A `match` that misses a case is FS0025, an incomplete pattern
match, a warning by default, exactly as CS8509 is for a C\# switch.
The evaluator's
statement walk names all six `Stmt` cases and carries no wildcard, so
adding a case turns every match over the tree amber until handled,
the compiler as a test suite, the posture chapter 18 called
exhaustiveness as a type level test.

#callout("pitfall", "fs0025 is a warning, promote it", [
  The F\# compiler does not refuse an incomplete match, it warns.
  The parity move with chapter 18's advice on CS8509 is to treat
  FS0025 as an error in the project file, so an added case stops the
  build rather than shipping a match that throws at runtime.
])

== options

`option<'T>` is a two case union, `Some 'T` or `None`, and it is the
language's answer to "may not be there". A lookup returns it, the
caller must match, and the type checker holds the caller to both
arms. The parser's optional consume is the pattern in miniature:

#listing("csharp-net/fsharp/src/FSharpBook/Parser.fs", first: 149, last: 154, caption: [tryfind returns an option, the match unwraps or falls through])

#diagram([option, absence as a value the type system counts], length: 13pt, {
  // the two case union at left, what the caller owes it at right
  cdraw.rect((0.2, 5.2), (6.0, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((3.1, 5.7), [`option<'T>`], size: 6pt)
  cdraw.line((1.7, 5.25), (1.7, 4.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.5, 5.25), (4.5, 4.35), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 3.0), (3.2, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((1.7, 3.7), [Some `'T`], size: 6pt)
  cdraw.rect((3.4, 3.0), (6.0, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.7, 3.7), [None], size: 6pt)
  cdraw.line((6.0, 5.7), (7.6, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 1.8), (21.8, 6.4), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((14.7, 5.6), [the caller must match both arms], size: 6pt)
  cdraw.content((14.7, 4.3), [BCL `TryGet` arrives as a tuple pattern, #linebreak() `| true, value` and `| false, _`], size: 6pt)
  cdraw.content((14.7, 2.9), [`None` cannot be passed #linebreak() where `'T` was wanted], size: 6pt)
  cdraw.content((10.9, 0.9), [`List.tryFind` returns it, `Token option` is the whole contract], size: 6.5pt)
})

`List.tryFind` is the option returning sibling of `List.find`, and
`Token option` in the signature is the whole contract. The BCL's
`TryGet` idiom, `bool` plus `out`, arrives as a tuple pattern in F\#:
the evaluator's name lookup matches `names.TryGetValue name` against
`| true, value` and `| false, _`, chapter 21 shows the site. Against
C\#'s nullable reference types, chapter 3's two nullable systems, the
difference is placement: absence is a value the type system counts,
and `None` cannot be passed where `'T` was wanted.

sources: learn.microsoft.com, f\# language reference let bindings, records,
unions, pattern matching, and options pages, the f\# 9 and f\# 10 what's new
pages, accessed 2026-09-13. Compiled shapes measured by reflection on the
built library. Verified by `dotnet test fsharp/FSharpBook.slnx`, 20 tests.
