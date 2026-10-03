#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= f\# on .net 11

F\# is not a separate runtime. It compiles to the same IL, runs on
the same CLR, ships in the same SDK download, and calls the same base
class library, which is why the port behind chapters 19 and 20 builds
with the verbs chapter 1 already covered. This chapter reads the .NET
side of the language: the toolchain as the port uses it, interop in
both directions, what .NET 11's serializer does with a discriminated
union, the trimming and compilation notes from the F\# release
documentation, the versioning story verified against the docs and the
SDK, and the side quest's own accounting.

== the toolchain

The pin is the book's pin. `global.json` in `books/csharp-net`
selects SDK 11.0.100-rc.1, and everything the part claims was built
under it:

```
$ dotnet --version
11.0.100-rc.1.26425.128

$ dotnet test fsharp/FSharpBook.slnx
Passed! - Failed: 0, Passed: 20, Skipped: 0, Total: 20
```

The project file is a plain fsproj: `TargetFramework` `net11.0`,
`IsPackable` false, and four `Compile` items, one per file. The order
of those items is load bearing, the one structural difference from a
csproj: F\# compiles files top to bottom and a file may only use what
earlier files define, so the list reads `Ast.fs`, `Lexer.fs`,
`Parser.fs`, `Evaluator.fs`, dependency order made explicit. C\#
resolves symbols across the whole project regardless of file order,
chapter 1's project model, which is why the C\# capstone's file order
is a convention and the port's is a constraint.

F\# Interactive ships inside the SDK, no separate install, `dotnet
fsi` runs a session or a script. A session on this SDK reports
itself:

```
$ dotnet fsi --quiet version.fsx
runtime: 11.0.0
FSharp.Core 11.0.0.0
FSharp.Compiler.Service 43.13.101.0
```

#diagram([the toolchain, one pin from global.json down to fsi], length: 13pt, {
  // three layers: the pin, the project file, the interactive session
  cdraw.rect((0.2, 5.2), (23.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.9, 5.7), [`global.json` selects sdk 11.0.100-rc.1, the book's own pin], size: 6pt)
  cdraw.rect((0.2, 3.4), (23.6, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 4.35), [the fsproj: `net11.0`, four `Compile` items in dependency order, #linebreak() the order is load bearing, a csproj's is convention], size: 6pt)
  cdraw.rect((0.2, 1.8), (23.6, 3.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 2.4), [`dotnet fsi` reports `FSharp.Core 11.0.0.0` #linebreak() on a runtime reporting 11.0.0], size: 6pt)
  cdraw.content((11.9, 0.8), [the same verbs on the same pin, `dotnet test` green at 20 of 20], size: 6.5pt)
})

The script is three lines that enumerate the loaded assemblies and
print their versions. `FSharp.Core 11.0.0.0` is the number this
chapter's versioning section leans on: the core library the RC SDK
carries is versioned 11. The wire shapes and the compiled shapes
quoted below were measured the same way, a script that `#r` loads
the built FSharpBook.dll and prints what reflection sees.

== c\# interop, both directions

F\# toward .NET needs no ceremony, and the port leans on the BCL
throughout: `System.Char.IsDigit` classifies characters in the lexer,
`System.Text.StringBuilder` accumulates string bodies, `Double.Parse`
takes a `CultureInfo.InvariantCulture` so decimal points never
localize, and the evaluator's name table is a BCL
`Dictionary<string, Value>`, created and indexed from F\# with no
adapter. `ResizeArray<'T>` in the parser is the same BCL generic
list under an F\# name, chapter 20 showed the boundary crossing.

.NET toward F\# is a question about compiled shape, and it has a
measured answer. Reflection over the built library shows `Expr`
compiles to an abstract class with one nested class per case, each
deriving from it, and `Token` compiles to a class with five read only
properties, one constructor over all five fields, and a
`CompilationMapping` attribute marking it as an F\# record. A C\#
consumer therefore sees ordinary classes: instantiate the case class
directly, read its properties, branch with `is` and `switch` over
the hierarchy. What the C\# consumer does not get is the F\# side of
the deal, structural equality and comparison live in the F\# core
library's generated code, and C\# 15's union patterns reach unions
built with the C\# `union` keyword through `IUnion`, chapter 3, not
an F\# discriminated union compiled as a class hierarchy.

#diagram([interop both directions, plain bcl calls out, ordinary classes in], length: 13pt, {
  // left: f# consuming the bcl, right: .net reading the compiled shape
  cdraw.content((5.2, 7.1), [f\# toward .net], size: 6.5pt)
  cdraw.rect((0.0, 4.3), (10.4, 6.7), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 5.5), [no adapter, the BCL throughout #linebreak() `Char.IsDigit`, `StringBuilder` #linebreak() `Dictionary<string, Value>`], size: 6pt)
  cdraw.content((17.4, 7.1), [.net toward f\#], size: 6.5pt)
  cdraw.rect((12.2, 4.3), (22.6, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 5.5), [a question of compiled shape #linebreak() `Expr`: an abstract class, #linebreak() one nested class per case], size: 6pt)
  cdraw.content((11.3, 2.7), [a c\# consumer sees ordinary classes, `is` and `switch` over the hierarchy, #linebreak() structural equality stays in the f\# core library's generated code], size: 6.5pt)
})

#callout("note", "one direction is measured from the outside", [
  The BCL consumption direction runs inside a green test suite, the
  port's 20 tests exercise every BCL call listed above. The C\#
  consumption direction has no such suite, no C\# project in this
  repo references FSharpBook.dll, so its claims rest on the measured
  compiled shape and the language reference, not on a test.
])

== two unions, two wire shapes

.NET 11's serializer learned both union families in the same
release. The what's new in .NET 11 libraries page lists "F\#
discriminated union support" in System.Text.Json alongside the C\#
union serialization chapter 16 measured. The two do not write the
same bytes, and both shapes below were measured on the pinned SDK
with default options.

The F\# discriminated union writes an envelope: a `$type`
discriminator naming the case, then the case's fields by their
declared names:

```
{"$type":"NumberExpr","value":1.5,"line":1}
{"$type":"BinaryExpr","op":"Plus","left":{...},"right":{...},"line":3}
```

Reading runs one rule: the discriminator must be present. A payload
without `$type` is refused with a `JsonException`, "required type
discriminator property not found", measured. Unnamed case fields
serialize as `Item`, a two case evaluator value measured
`{"$type":"Number","Item":2.5}`, and web defaults camel case both
the case name and the field names.

The C\# 15 union of chapter 16's unions on the wire section writes
the bare case payload, no envelope, the JSON value kind names the
case, and object cases that share a kind need the
`JsonUnionTypeStructuralClassifier`. Both round trip with zero
configuration under their own conventions, and the trade sits in the
envelope:

#diagram([one case, two wires, the envelope is the difference], length: 13pt, {
  // the same NumberExpr case at top, two payloads below, single line rows
  cdraw.rect((0.2, 5.0), (23.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 5.6), [`NumberExpr(1.5, 1)`], size: 6.5pt)
  cdraw.line((6.0, 5.0), (6.0, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.8, 5.0), (17.8, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 0.9), (11.8, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((6.0, 4.1), [f\# du], size: 6.5pt)
  cdraw.content((6.0, 3.0), [`{"$type":"NumberExpr",` #linebreak() `"value":1.5,"line":1}`], size: 6pt)
  cdraw.content((6.0, 2.1), [always names its case on the wire], size: 6pt)
  cdraw.content((6.0, 1.35), [reading demands the discriminator], size: 6pt)
  cdraw.rect((12.0, 0.9), (23.6, 4.6), fill: luma(230), radius: 0.02)
  cdraw.content((17.8, 4.1), [c\# 15 union], size: 6.5pt)
  cdraw.content((17.8, 3.0), [the bare case payload, #linebreak() the value kind names the case], size: 6pt)
  cdraw.content((17.8, 2.1), [object cases need the classifier], size: 6pt)
  cdraw.content((17.8, 1.35), [chapter 16 measured it], size: 6pt)
})

#callout("warning", "the two shapes are not interchangeable", [
  A C\# reader handed F\# union JSON must cope with the `$type`
  envelope, and an F\# reader handed C\# union JSON will refuse it
  for lacking the discriminator. One serializer, one release, two
  conventions: agree on the writer before the wire exists.
])

== trimming and parallel compilation

Two F\# release notes claims carry into .NET 11 and both are worth
the source. Trimming: F\# assemblies carry metadata resources the
compiler wants and the runtime does not, and F\# 10 removed the
manual `ILLink.Substitutions.xml` maintenance by generating the
substitutions file automatically when publishing with
`PublishTrimmed`, so trimmed F\# output is smaller by default with
the opt out named `DisableILLinkSubstitutions`. Compilation: the
`ParallelCompilation` project property groups graph based type
checking, parallel IL generation, and parallel optimization behind
one switch. F\# 10 turned it on by default only for
`LangVersion=Preview` projects, the notes state the plan to enable
it for all projects in .NET 11, and they state the cost, it does not
combine with deterministic builds.

#diagram([two f\# 10 release claims carried into .net 11], length: 13pt, {
  // left: the trimming before and after, right: the one compilation switch
  cdraw.rect((0.0, 5.0), (10.4, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 5.6), [the substitutions file, #linebreak() once maintained by hand], size: 6pt)
  cdraw.line((5.2, 5.0), (5.2, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.0, 2.4), (10.4, 4.3), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 3.35), [generated automatically #linebreak() under `PublishTrimmed`, output #linebreak() smaller by default], size: 6pt)
  cdraw.rect((12.2, 5.0), (22.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 5.6), [`ParallelCompilation`, #linebreak() three passes, one switch], size: 6pt)
  cdraw.line((17.4, 5.0), (17.4, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.2, 2.4), (22.6, 4.3), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 3.35), [graph based type checking, #linebreak() parallel il generation, #linebreak() parallel optimization], size: 6pt)
  cdraw.content((11.3, 1.2), [on by default only for `LangVersion=Preview`, the notes plan #linebreak() all projects in .net 11, at the cost of deterministic builds], size: 6.5pt)
})

What the .NET 11 docs at RC1 do not carry is an F\# section, the
overview's language coverage names C\# 15 and nothing for F\#. The
plan is in writing, the confirmation is not yet, and this chapter
records the gap rather than assuming the flip.

== the versioning story, verified

The F\# release numbering has tracked the .NET release numbering
since F\# 9, and the docs confirm the pairing link by link. The .NET
9 overview: "F\# 9 ships with the .NET 9 SDK." The F\# 10 page:
"F\# 10 ships with .NET 10 and Visual Studio 2026." For F\# 11 the
docs are not yet written, there is no what's new in F\# 11 page at
RC1 and the .NET 11 overview names no F\# language version, so the
claim rests on the SDK itself: `dotnet fsi` under 11.0.100-rc.1
loads `FSharp.Core 11.0.0.0` on a runtime reporting 11.0.0, the
same alignment the last two releases documented.

#diagram([three releases, the pairing in the docs and the sdk], length: 13pt, {
  // three columns, f# version over .net version, the evidence in one line below
  let cols = (
    ([f\# 9], [.net 9]),
    ([f\# 10], [.net 10]),
    ([f\# 11], [.net 11 rc]),
  )
  for (i, c) in cols.enumerate() {
    let x0 = 1.2 + i * 7.6
    cdraw.rect((x0, 4.2), (x0 + 6.4, 6.2), fill: luma(205), radius: 0.02)
    cdraw.content((x0 + 3.2, 5.5), c.at(0), size: 7pt)
    cdraw.content((x0 + 3.2, 4.8), c.at(1), size: 6.5pt)
  }
  cdraw.content((12.0, 3.2), [the docs confirm the first two pairings, #linebreak() the sdk's fsharp.core 11.0.0.0 carries the third], size: 6.5pt)
  cdraw.content((12.0, 1.6), [no what's new in f\# 11 page exists at rc1, #linebreak() the sdk is the only witness so far], size: 6.5pt)
})

== the side quest: the evaluator in f\#

The port is four files, all read across this part: `Ast.fs`, 39
lines, the token kinds, the token record, and the two unions,
chapter 19, `Lexer.fs`, 136 lines, chapter 20, `Parser.fs`, 183
lines, chapter 20, and `Evaluator.fs`, 139 lines, this section. The
evaluator's value domain is one more discriminated union with a
printing rule per case, integer valued numbers printed without a
decimal point, invariant culture throughout:

#listing("csharp-net/fsharp/src/FSharpBook/Evaluator.fs", first: 12, last: 24, caption: [the value union, one tostring for the whole domain])

The builtin table is where the port's scope is stated in the code
itself. The C\# capstone registers builtins with a source generator,
chapter 35's builtins section, the port is a two entry map, and the
comment on it says what left: the C\# registry is source generated,
here it is a plain map, and `clock_async` left with async:

#listing("csharp-net/fsharp/src/FSharpBook/Evaluator.fs", first: 67, last: 86, caption: [sqrt and abs kept, clock async dropped, a plain map])

#diagram([the side quest's deliberate scope, kept and dropped], length: 13pt, {
  // the kept column and the dropped column, the suite that pins both below
  cdraw.rect((0.0, 4.7), (10.4, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 5.55), [kept: `sqrt` and `abs`, #linebreak() the synchronous builtins, a plain map], size: 6pt)
  cdraw.rect((12.2, 4.7), (22.6, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 5.55), [dropped: async end to end, #linebreak() the checker, the persistence], size: 6pt)
  cdraw.content((11.3, 3.0), [no sqlite file, no `Names`, no `LoadNames`, the dictionary #linebreak() lives and dies with the process, 20 tests pin the lot], size: 6.5pt)
})

The class comment above the evaluator says the rest of it: "the C\#
capstone's evaluator minus async, sqlite persistence, and the source
generated builtin registry, synchronous end to end". The optional
constructor parameters, `?write` and `?builtins`, default through
`defaultArg`, and the name table is the BCL dictionary:

#listing("csharp-net/fsharp/src/FSharpBook/Evaluator.fs", first: 88, last: 96, caption: [deliberate scope in a comment, defaults in two lines, a dictionary for names])

Statement execution is a match over the six `Stmt` cases, no
wildcard, chapter 19's exhaustiveness posture. Undefined names raise
here, at evaluation, because the port has no checker:

#listing("csharp-net/fsharp/src/FSharpBook/Evaluator.fs", first: 102, last: 113, caption: [six named arms, no discard, assignment writes the dictionary])

Expression evaluation is the same discipline over `Expr`, and it is
where the evaluator owns what the C\# capstone's checker pass owned,
undefined names and operand kinds, the test comment states it
outright: "no check pass in this port, the evaluator owns kind
errors":

#listing("csharp-net/fsharp/src/FSharpBook/Evaluator.fs", first: 115, last: 139, caption: [the eval match, kind errors and unknown builtins raised here])

That is the whole deliberate scope. Kept: `sqrt` and `abs` as the
synchronous builtins. Dropped: async end to end with `clock_async`,
the checker pass, and the persistence that chapter 35's saves
section describes, no SQLite file, no `Names`, no `LoadNames`, the
evaluator's dictionary lives and dies with the process. The suite
that pins all of it: 20 tests, 5 lexer, 4 parser, 11 evaluator, zero
skipped, green under the pinned SDK.

sources: learn.microsoft.com, what's new in .net 11 libraries and
overview pages, what's new in f\# 9 and f\# 10 pages, accessed
2026-09-13. fsi, compiler, runtime, and serializer behavior measured
in `dotnet fsi` sessions under SDK 11.0.100-rc.1.26425.128. Sample
behavior verified by `dotnet test fsharp/FSharpBook.slnx`, 20 tests,
zero skipped.
