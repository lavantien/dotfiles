#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= toolchain and project model

C\# 14 compiles on .NET 10, the long term support release this book teaches
from, and the C\# 15 chapters fold in .NET 11 builds. This chapter covers
what you install, how projects are shaped, and the command line used
throughout the book. Every listing in this book is a slice of a
real file in this repo's sample solution, and every sample file is compiled
and tested before the book is, the Makefile target `verify-csharp` runs the
whole suite.

== the sdk

The .NET SDK is one download that includes the compiler (Roslyn), the
runtime, and the build tooling. .NET 10 stays the teaching base, and since
the C\# 15 folds the book builds and tests on the .NET 11 SDK pinned by the
book local `global.json`:

```
$ dotnet --version
11.0.100-rc.1
```

#diagram([the sdk, one download stacking compiler, runtime, and build tooling], length: 13pt, {
  // the outer box is what you install, the three layers are what you got
  cdraw.content((5.9, 6.35), [.net sdk], size: 7pt)
  cdraw.rect((-0.4, 0.6), (12.2, 6.0), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.rect((0.0, 4.6), (11.8, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.9, 5.1), [compiler: roslyn], size: 6pt)
  cdraw.rect((0.0, 2.8), (11.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 3.5), [runtime: clr + base class library], size: 6pt)
  cdraw.rect((0.0, 1.0), (11.8, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 1.7), [build tooling: msbuild + cli verbs], size: 6pt)
  // the version thread running out of the same download
  cdraw.line((12.2, 3.5), (13.4, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.7, 3.5), [the sdk version carries #linebreak() the language version], size: 6.5pt)
})

The runtime layer is the clr, the common language runtime: it executes il,
the intermediate language every .NET compiler emits, and the jit, its just
in time compiler, turns that il into machine code while the program runs.

The SDK version carries the language version. Targeting `net10.0` defaults
to C\# 14 and targeting `net11.0` defaults to C\# 15, no `LangVersion`
property needed in either case. .NET 10 is LTS, supported to November 2028,
so it stays the teaching base, while the C\# 15 chapters build under the
book local pin at 11.0.100-rc.1; the appendices' rc1 build pin note records
what re-pinning at GA will mean.

== projects and solutions

A C\# project is an XML file with a target framework and properties. One
project compiles to one assembly, the dll or exe the runtime loads. The
sample solution's project file is the whole configuration:

#listing("csharp-net/samples/src/CsharpBook.Samples.csproj", caption: [the sample project file, complete])

#diagram([three csproj properties, what each one controls], length: 13pt, {
  // property on the left, the behavior it switches on the right
  let rows = (
    ("TargetFramework", [picks runtime and language together #linebreak() net10.0 defaults to c\# 14]),
    ("ImplicitUsings", [injects the common usings #linebreak() into every file, silently]),
    ("Nullable", [switches on null flow analysis #linebreak() the posture of this book]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.2 - i * 2.2
    cdraw.rect((0, y), (6.6, y + 1.2), fill: luma(205), radius: 0.02)
    cdraw.content((3.3, y + 0.6), row.at(0), size: 6.5pt)
    cdraw.line((6.6, y + 0.6), (8.2, y + 0.6), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.2, y + 0.6), row.at(1), size: 6.5pt)
  }
})

Three properties do real work. `TargetFramework` picks runtime and language
version together. `ImplicitUsings` adds the common namespace usings
(`System`, `System.Linq`, `System.Collections.Generic`, and friends) to
every file silently. `Nullable` turns on nullable reference types, the
compiler flow analysis that warns when a reference might be null, which is
the default posture of modern C\# and the posture of every line in this
book.

Solutions group projects. With the .NET 10 SDK, `dotnet new sln` creates the
new XML based `.slnx` format rather than the historical `.sln`:

```
$ dotnet new sln -n CsharpBook
CsharpBook.slnx created.
```

The old `.sln` still works, `dotnet sln` reads both, but new solutions
default to `.slnx` and that is what this repo uses.

== the command surface

The verbs this book uses:

```
dotnet new console -o src            scaffold a project
dotnet build                         compile
dotnet test                          build and run the test suite
dotnet run                           build and execute
dotnet publish -c Release            produce deployable output
```

#flow(
  [the dev loop as a pipeline, test the gate every listing depends on],
  node((0, 0), [new]),
  node((1.8, 0), [build]),
  node((3.6, 0), [test]),
  node((5.4, 0), [run]),
  node((7.2, 0), [publish]),
  edge((0, 0), (1.8, 0), "-|>"),
  edge((1.8, 0), (3.6, 0), "-|>"),
  edge((3.6, 0), (5.4, 0), "-|>"),
  edge((5.4, 0), (7.2, 0), "-|>"),
  node((3.6, 1.5), [verify-csharp]),
  edge((3.6, 0), (3.6, 1.5), "-|>"),
)

`dotnet test` on the solution runs the xunit suite over every test project.
The sample suite is what gives book listings their guarantee: a listing
exists here because its file passed that suite.

== xunit v3 and why this suite is not on it

xUnit.net v3 is the current major version of the test framework this
book runs on. It ships its own templates, installed explicitly:

```
$ dotnet new install xunit.v3.templates
xUnit.net v3 Test Project       xunit3            [C#],F#,VB  Test/xUnit
xUnit.net v3 Extension Project  xunit3-extension  [C#],F#,VB  Test/xUnit
```

#diagram([the v2/v3 fork in one property, a v3 suite executes itself while this book stays on the shared v2 pins], length: 13pt, {
  // left: the v3 shape the templates ship, right: the v2 shape this suite pins
  cdraw.content((5.6, 6.9), [xunit v3, the templates' shape], size: 6.5pt)
  cdraw.rect((0.0, 5.4), (11.2, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.6, 5.9), [test project is a stand-alone executable], size: 6pt)
  cdraw.line((5.6, 5.4), (5.6, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.0, 2.4), (11.2, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.6, 3.6), [outputtype exe, `dotnet run` #linebreak() executes it, `dotnet test` via #linebreak() microsoft testing platform], size: 6pt)
  cdraw.content((18.0, 6.9), [this suite, the shared v2 pins], size: 6.5pt)
  cdraw.rect((12.4, 5.4), (23.6, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((18.0, 5.9), [test project plus the vstest packages], size: 6pt)
  cdraw.line((18.0, 5.4), (18.0, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.4, 2.4), (23.6, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((18.0, 3.6), [`xunit` 2.9.3, runner 3.1.4 #linebreak() test sdk 17.14.1 #linebreak() `dotnet test` over vstest], size: 6pt)
  cdraw.content((11.8, 1.0), [the fork in one property: v3's project is a stand-alone executable, #linebreak() this book stays on the 2.9.3 pins every c\# book's verify shares], size: 6.5pt)
})

A v3 project differs from the v2 shape this book uses in one structural
way: the test project is a stand-alone executable, `OutputType` set to
`Exe`, so `dotnet run` executes the suite directly and `dotnet test`
goes through Microsoft Testing Platform by default. Choosing the VSTest
runner instead adds back the two packages the v2 world knows,
`xunit.runner.visualstudio` and `Microsoft.NET.Test.Sdk`. The SDK side
grew a companion feature for single file programs: file-based apps,
configured by `#:` directives at the top of the file. The `#:include`
directive, available since .NET SDK 10.0.300 and .NET 11 Preview 3,
pulls another file into the build, `*.cs` files map to `Compile`,
globs and MSBuild properties are allowed, and the included files can
add declarations but not top level statements:

```
#:include helpers.cs
#:include models/customer.cs
#:include shared/**/*.cs
```

This suite stays on xunit 2.x, and the csproj is the honest statement:
`xunit` 2.9.3, `xunit.runner.visualstudio` 3.1.4, `Microsoft.NET.Test.Sdk`
17.14.1. Two reasons. Every C\# suite in this repo, four books, runs
through the same `make verify-csharp` `dotnet test` pipeline on those
identical pins, and the v3 packages the templates reference were still
4.0.0 pre-release when this was written. Nothing this book teaches
needs the v3 additions, `[Fact]` and `[Theory]` mean the same thing in
both versions, so the upgrade would buy runner changes and nothing
pedagogical. When the 4.0.0 packages go stable the delta to record is
mechanical: install the templates, swap the packages, keep the tests.

== top level statements

Since C\# 9, a console program needs no `Main` method declaration. A file of
top level statements becomes the entry point, and the magic `args`
contextual keyword carries the command line arguments:

#listing("csharp-net/samples/src/Program.cs", caption: [the whole entry point of the sample project])

#flow(
  [top level statements and explicit main, the same program in two shapes],
  node((0, 0), [file of statements #linebreak() Console.WriteLine(...)]),
  edge((1.8, 0), (4.8, 0), "-|>", label: [compiler synthesizes #linebreak() the entry point]),
  node((6.4, 0), [static Program.Main #linebreak() with (string[] args)]),
)

Top level statements are a convenience with rules: only one file per
project may have them, any classes must come after the statements, and the
compiler synthesizes a `Main` under the hood. For programs that grow, the
ordinary shape with an explicit `Program.Main` returns, and that shape gets
its full treatment in the structure chapter of book 3's Go material for
comparison, and in the idioms chapter here.

== how this book verifies claims

#callout("verify", "the claim discipline for this book", [
  Every chapter ends with a sources line naming the official documentation
  sections it was written against, fetched while writing. Code claims are
  backed by the sample suite, run with `make verify-csharp`. When a
  behavior surprised the suite, the chapter says so.
])

#flow(
  [the evidence chain, from a sample file to a prose claim],
  node((0, 0), [sample file]),
  node((3.0, 0), [suite green]),
  node((6.0, 0), [listing slices the file]),
  node((8.2, 0), [prose claim]),
  edge((0, 0), (3.0, 0), "-|>", label: [verify-csharp]),
  edge((3.0, 0), (6.0, 0), "-|>"),
  edge((6.0, 0), (8.2, 0), "-|>"),
)

sources: learn.microsoft.com, what is new in c\# 14 and .net 10, accessed
2026-09-07; learn.microsoft.com, c\# language reference keywords page,
accessed 2026-09-08; xunit.net, getting started with xunit.net v3 and
what's new in v3 pages; learn.microsoft.com, file-based apps page,
accessed 2026-09-13; the sample solution in this repo, built under the
book local `global.json` pin at 11.0.100-rc.1.
