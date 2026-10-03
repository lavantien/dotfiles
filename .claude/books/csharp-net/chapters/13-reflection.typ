#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= reflection, attributes, source generators

Three mechanisms let code talk about code. Reflection reads types,
members, and metadata at runtime. Attributes attach metadata to those
types. Source generators read the compilation at compile time and add
code to it, which moves work that reflection or hand written
boilerplate used to do into the build. `dynamic` sits at the edge of
the group, late bound dispatch without the reflection ceremony.

== attributes

An attribute is a class deriving from `Attribute`, applied in brackets.
`AttributeUsage` constrains where it can appear, and constructor
parameters plus properties become the stored data:

#listing("csharp-net/samples/src/Ch13/Meta.cs", first: 5, last: 10, caption: [a custom attribute with one payload])

#diagram([an attribute is a metadata row that materializes on demand], length: 13pt, {
  // source brackets, the stored row, the runtime instance
  cdraw.rect((0.2, 3.4), (7.2, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.7, 4.3), [`[Audited("payments")]`, #linebreak() written on a symbol], size: 6pt)
  cdraw.line((7.2, 4.3), (8.2, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.4, 3.4), (15.6, 5.2), fill: luma(230), radius: 0.02)
  cdraw.content((12.0, 4.3), [a metadata row #linebreak() stored in the assembly], size: 6pt)
  cdraw.line((15.6, 4.3), (16.6, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.8, 3.4), (23.8, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.3, 4.3), [an instance, #linebreak() built at runtime], size: 6pt)
  cdraw.content((11.5, 1.8), [`AttributeUsage` constrains where the attribute may appear], size: 6.5pt)
  cdraw.content((11.5, 0.4), [constructor parameters and properties are the stored data], size: 6.5pt)
})

Convention ends attribute class names in `Attribute` and lets the
suffix disappear at the use site, `[Audited("payments")]` in the
listing below is `AuditedAttribute`.

== reflection

`typeof(T)` and `obj.GetType()` produce `System.Type`, the entry point
to everything the runtime knows: base types, interfaces, properties,
methods, fields, and applied attributes. `MethodInfo.Invoke` calls a
method found by name:

#listing("csharp-net/samples/src/Ch13/Meta.cs", first: 12, last: 18, caption: [the attributed type the samples reflect over])

#listing("csharp-net/samples/src/Ch13/Meta.cs", first: 22, last: 31, caption: [listing properties, reading an attribute, invoking by name])

#diagram([system.type, the entry point to the metadata graph], length: 13pt, {
  // typeof on the left, the type hub, the member spokes at right
  cdraw.rect((0.2, 3.0), (5.0, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.6, 3.7), [`typeof`, `GetType`], size: 6pt)
  cdraw.line((5.0, 3.7), (5.8, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.8, 2.6), (10.2, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((8.0, 3.7), [`System.Type`, #linebreak() graph entry], size: 6pt)
  let spokes = ([base types], [properties, fields], [applied attributes], [`Invoke` by name])
  for (i, s) in spokes.enumerate() {
    let y = 5.1 - i * 1.3
    cdraw.line((10.2, 3.7), (11.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((11.6, y - 0.5), (17.6, y + 0.5), fill: luma(230), radius: 0.02)
    cdraw.content((14.6, y), s, size: 6pt)
  }
  cdraw.content((20.6, 4.4), [slow next to #linebreak() a direct call], size: 6.5pt)
  cdraw.content((20.6, 2.0), [invisible #linebreak() to trimming], size: 6.5pt)
})

Reflection is how test frameworks find your tests, how serializers map
records to JSON, and how dependency containers build object graphs. It
is also slow compared to a direct call and invisible to trimming, which
is why every hot use of it in the modern library has been replaced by
source generation. Trimming, the publish step that strips unreferenced
code to shrink the output, cannot see what reflection will look up at
runtime, the second reason the library moved to generators.

`nameof` is the compile time cousin: it produces the name of any symbol
as a string constant, so renames keep logs and argument checks honest:

#listing("csharp-net/samples/src/Ch13/Meta.cs", first: 39, last: 40, caption: [names without string literals])

== dynamic

`dynamic` defers binding from compile time to runtime. The compiler
skips checking member access on `dynamic` values, and the runtime binds
using the actual type:

#listing("csharp-net/samples/src/Ch13/Meta.cs", first: 33, last: 37, caption: [a call the compiler never checks])

#diagram([dynamic defers binding from compile time to run time], length: 13pt, {
  // the same call shape, two binding times
  cdraw.rect((7.0, 4.4), (13.2, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((10.1, 5.0), [`d.ToString()`], size: 6pt)
  cdraw.line((8.0, 4.4), (3.8, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.2, 4.4), (16.4, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 1.4), (7.8, 3.4), fill: luma(230), radius: 0.02)
  cdraw.content((4.0, 2.4), [static: #linebreak() checked before it runs], size: 6pt)
  cdraw.rect((12.4, 1.4), (20.0, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((16.2, 2.4), [`dynamic`: #linebreak() bound when it runs], size: 6pt)
  cdraw.content((10.1, 0.2), [no static checking, slower dispatch, #linebreak() errors surface only on the executed path], size: 6.5pt)
})

The cost is exactly what the listing says: no static checking, slower
dispatch, and errors that surface only on the executed path. It earns
its keep talking to COM, dynamic languages, and JSON payloads whose
shape is known but never modeled. Everywhere else, a record plus a
pattern match over `object` gives the same flexibility with the
compiler still in the room.

== source generators

A source generator is a small program the compiler runs during the
build. It reads the compilation's syntax trees, picks out what
interests it, and emits new source files that compile as if you wrote
them. Generated code is checked, debuggable, and free of the runtime
cost reflection pays. The modern Roslyn shape is the *incremental*
generator, a pipeline of cached stages so an edit re-runs only the
stages whose inputs changed.

The sample solution carries a real one. The consumer side is one
class with a marker attribute:

#listing("csharp-net/samples/src/Ch13/Generated.cs", first: 3, last: 12, caption: [the marker attribute and a class with no Describe method in sight])

The generator finds every class carrying `[GenerateSummary]` and emits
an extension method for it:

#listing("csharp-net/samples/src/CsharpBook.Generators/SummaryGenerator.cs", first: 9, last: 40, caption: [the initialize pipeline: filter syntax, emit source])

#diagram([the incremental generator, cached stages, static end to end], length: 13pt, {
  // three cached stages left to right, the edit rule below
  cdraw.rect((0.2, 3.0), (7.2, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.7, 3.9), [syntax predicate, #linebreak() cheap, every node], size: 6pt)
  cdraw.line((7.2, 3.9), (8.2, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.4, 3.0), (14.8, 4.8), fill: luma(230), radius: 0.02)
  cdraw.content((11.6, 3.9), [transform, #linebreak() syntax only, caches well], size: 6pt)
  cdraw.line((14.8, 3.9), (15.8, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.0, 3.0), (23.6, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((19.8, 3.9), [`RegisterSourceOutput`, #linebreak() emits one source file], size: 6pt)
  cdraw.content((11.9, 1.7), [an edit re-runs only the stages #linebreak() whose inputs changed], size: 6.5pt)
  cdraw.content((11.9, -0.5), [everything static: no per-edit state on the generator], size: 6.5pt)
})

The pipeline is the whole design. `CreateSyntaxProvider` runs a cheap
predicate over every syntax node, then a transform on the survivors.
`Where` filters by attribute name, still syntax only, no semantic
model, so the stage caches well. `RegisterSourceOutput` finally emits
one source file per match. Everything is `static` so no per-edit state
accumulates on the generator instance.

Wiring it in is one project reference with `OutputItemType="Analyzer"`,
a `netstandard2.0` target for the generator itself:

#listing("csharp-net/samples/src/CsharpBook.Samples.csproj", first: 10, last: 16, caption: [an analyzer reference, no runtime assembly])

The test is the proof. It was written first, failed to compile with
CS1061 because `Widget.Describe` did not exist, and passed only after
the generator ran:

#listing("csharp-net/samples/tests/Ch13/MetaTests.cs", first: 31, last: 32, caption: [the red test that the generator turned green])

#callout("note", "what generators replaced", [
  `[GeneratedRegex]` compiles a regex at build time instead of the
  first call. `System.Text.Json` source generation writes the
  serializer metadata a profile used to build with reflection. System
  interop uses generated marshallers instead of hand written `fixed`
  blocks, which is why chapter 10 called the pointer surface interop
  territory. The capstone interpreter uses the same shape to register
  its builtin functions.
])

sources: learn.microsoft.com, reflection overview, attributes, nameof,
dynamic type, the roslyn sdk overview, and the incremental generators
cookbook at github.com/dotnet/roslyn, accessed 2026-09-08. Generator
behavior verified by `make verify-csharp`, 6 tests.
