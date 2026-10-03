#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= stdlib tour 2: io, text, net, channels, diagnostics

The second half of the weekly toolbox: serialization, files, text,
http, channels, and the small utilities every program ends up
needing.

== System.Text.Json

JSON support is built around records and reflection-free speed. A
record serializes property by property and deserializes through its
constructor, and the source generated mode from chapter 13 removes
the reflection cost for trim-safe publishing. Options live in
`JsonSerializerOptions`, and reusing one instance matters, each new
options object rebuilds its metadata cache:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 29, last: 36, caption: [a record through serialize and deserialize])

#diagram([the json round trip, properties out, constructor back in], length: 13pt, {
  // record to json text to record, the options cache noted below
  cdraw.rect((0.2, 3.4), (5.8, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 4.3), [the record, #linebreak() typed properties], size: 6pt)
  cdraw.line((5.8, 4.3), (6.6, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.8, 3.4), (11.7, 5.2), fill: luma(230), radius: 0.02)
  cdraw.content((9.25, 4.3), [`Serialize`: #linebreak() properties out], size: 6pt)
  cdraw.line((11.7, 4.3), (12.5, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.7, 3.4), (16.0, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((14.35, 4.3), [json text], size: 6pt)
  cdraw.line((16.0, 4.3), (16.8, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((17.0, 3.4), (23.6, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.3, 4.3), [`Deserialize`: #linebreak() constructor back in], size: 6pt)
  cdraw.content((11.9, 1.7), [one reused `JsonSerializerOptions` #linebreak() keeps its metadata cache], size: 6.5pt)
  cdraw.content((11.9, -0.5), [round trip equality is the assertion], size: 6.5pt)
})

The naming policy set gains `JsonNamingPolicy.PascalCase` in .NET
11, so a .NET type can meet a Pascal-cased wire without renaming
anything on either side. The per-type `[JsonNamingPolicy]` attribute
covers the other policies but rejects `PascalCase` under the book's
pinned RC1 SDK, the options-level lever is the one that works:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 138, last: 147, caption: [the wire in Pascal, the record untouched])

The same namespace carries `Utf8JsonReader` and `Utf8JsonWriter` for
span level, allocation free work, and `JsonDocument` for read only
DOM access. The chapter 35 capstone uses none of them: its
serialization work is `JsonSerializer` round trips over the
c\# 15 union AST, and its save store is `Microsoft.Data.Sqlite`.

== unions on the wire

.NET 11 teaches the serializer the chapter 3 unions, reflection and
source generator both. Serialization writes the active case and
nothing else, no wrapper, no envelope: a union of `int`, `string`,
and a record puts `7`, `"ping"`, or the record's object on the wire.
Reading runs one rule: the JSON value kind must name the case.
Number, string, and object each own a kind, so a union whose cases
are distinct kinds round trips with no configuration at all:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 105, last: 115, caption: [the case is the payload, the value kind names the case on the way back])

Object cases collide, every record is a JSON object, and the
deserializer refuses to guess. The built-in
`JsonUnionTypeStructuralClassifier` resolves what the property names
can: registered once on a reused options instance, it picks the case
whose required properties the payload carries:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 117, last: 136, caption: [the structural classifier reads property names to pick the case])

#diagram([serialize writes the case, deserialize classifies it], length: 13pt, {
  // the union with three cases at left, the wire and its reader at right
  cdraw.rect((0.2, 3.4), (6.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.9), [the union, #linebreak() three cases], size: 6pt)
  cdraw.content((3.3, 4.0), [`7`, `"ping"`, `Sample`], size: 6pt)
  cdraw.line((6.4, 4.7), (7.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 3.4), (14.0, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 4.9), [write: the case payload, #linebreak() nothing else], size: 6pt)
  cdraw.line((14.0, 4.7), (15.0, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.2, 3.4), (23.4, 5.6), fill: luma(230), radius: 0.02)
  cdraw.content((19.3, 4.9), [read: value kind, then #linebreak() property names, then you], size: 6pt)
  cdraw.content((11.8, 2.0), [distinct value kinds need no config, object cases need the classifier], size: 6.5pt)
  cdraw.content((11.8, 0.6), [same-shaped cases: the classifier rejects them at configure, #linebreak() a custom `JsonTypeClassifier` or a discriminant property is the escape hatch], size: 6.5pt)
})

#callout("pitfall", "same-shaped cases are the wall", [
  The classifier only works while property names can tell the cases
  apart. Chapter 3's `Pet(Cat, Dog, Bird)`, three cases that each
  carry one `Name`, serializes fine, but the structural classifier
  refuses the union the first time the options touch it: a case
  that can never be selected uniquely, because `Cat` recognizes
  every property `Dog` does, is a design the classifier rejects
  rather than misreads. Same-shaped cases need a custom
  `JsonTypeClassifier` through `[JsonUnion]` or
  `TypeClassifiers`, or a discriminant property on the wire.
])

== files and streams

`File` and `Path` cover the common cases in one call each. Anything
owning a handle is `IDisposable`, and `using` scopes the lifetime to
the block, the compiler writes the `try`/`finally`. `Stream` is the
base abstraction, `MemoryStream` for buffers, `FileStream` for disk,
and readers and writers layer encoding on top:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 38, last: 51, caption: [write, read, and clean up a temp file])

#diagram([the io stack, one call helpers over streams over handles], length: 13pt, {
  // four layers, the convenience calls at top, the handle at bottom
  let layers = (
    ([`File`, `Path`: one-call helpers], luma(235)),
    ([readers, writers: encoding], luma(230)),
    ([`Stream`: bytes, seekable], luma(230)),
    ([the os handle], luma(205)),
  )
  for (i, (t, f)) in layers.enumerate() {
    let y0 = 5.4 - i * 1.25
    cdraw.rect((0.2, y0 - 1.1), (12.0, y0 + 0.1), fill: f, radius: 0.02)
    cdraw.content((6.1, y0 - 0.5), t, size: 6pt)
  }
  cdraw.content((17.4, 4.6), [`using` writes the #linebreak() try/finally for you], size: 6.5pt)
  cdraw.content((17.4, 2.2), [`MemoryStream` buffers, #linebreak() `FileStream` is disk], size: 6.5pt)
})

.NET 11 closes the gap between text and streams in one direction:
`StringStream` is a string as a read-only, forward-only UTF-8
stream, so an API that wants a `Stream` gets one without the
`GetBytes` array in the middle. Seeking is off, `CanSeek` is false
and `Length` throws, which is the honest contract for text being
consumed once. The span companions `ReadOnlyMemoryStream` and
`WritableMemoryStream` cover the seekable cases over buffers you
already own:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 149, last: 157, caption: [text handed to a stream api, no byte array in between])

== text

`string` is immutable UTF-16, so repeated concatenation in a loop
allocates a new string each pass. `StringBuilder` is the mutable
scratch buffer, and `Encoding.UTF8` converts between text and bytes,
with `GetByteCount` measuring before you allocate:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 96, last: 103, caption: [composing and measuring without churn])

#diagram([string churn against one builder buffer], length: 13pt, {
  // a fresh allocation per pass at left, one amended buffer at right
  cdraw.content((3.1, 6.2), [concatenation in a loop], size: 6.5pt)
  let passes = ([pass 1: allocated], [pass 2: allocated], [pass 3: allocated])
  for (i, t) in passes.enumerate() {
    let y = 5.0 - i * 1.4
    cdraw.rect((0.2, y - 0.55), (6.0, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((3.1, y), t, size: 6pt)
    if i < 2 { cdraw.line((3.1, y - 0.55), (3.1, y - 0.85), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((11.2, 6.2), [`StringBuilder`], size: 6.5pt)
  cdraw.rect((7.0, 2.6), (15.4, 4.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.2, 3.5), [one buffer, #linebreak() amended in place], size: 6pt)
  cdraw.content((19.6, 4.4), [immutable utf-16, #linebreak() every `+` allocates], size: 6.5pt)
  cdraw.content((11.2, 0.4), [`GetByteCount` measures the wire cost #linebreak() before you allocate the byte array], size: 6.5pt)
})

Compare strings with `string.Equals(a, b, StringComparison.Ordinal)`
or its case-insensitive sibling, never with `==` when the inputs come
from outside the process. The culture-aware comparisons belong to
display, not logic, and chapter 17 returns to this rule.

.NET 11 finishes the rune story on `string` itself. `IndexOf`,
`Contains`, `StartsWith`, `Trim`, and `Split` take a `Rune`,
`StringBuilder` enumerates, appends, and replaces by rune, and
`ToUpperOrdinal` and `ToLowerOrdinal` case text with no culture in
sight. One rune is not one `char`: the rocket below is one code
point, two UTF-16 units, and `IndexOf` reports the unit where it
starts:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 159, last: 167, caption: [six chars, five runes, and the unit index where the rocket starts])

== http

`HttpClient` is built for reuse, one client per process or per
endpoint, not one per request, sockets exhaust otherwise. Its handler
pipeline is injectable, which is what makes http code testable, the
sample ships a stub handler answering every request offline:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 11, last: 20, caption: [a stub handler, the seam for offline tests])

#diagram([the handler chain is the http test seam], length: 13pt, {
  // the stack at left, the stub sliding into the pipeline, notes at right
  cdraw.rect((0.2, 4.8), (8.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.1, 5.4), [`HttpClient`, one per endpoint], size: 6pt)
  cdraw.line((4.1, 4.8), (4.1, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 3.0), (8.0, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((4.1, 3.8), [the handler pipeline, injectable], size: 6pt)
  cdraw.line((4.1, 3.0), (4.1, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 1.2), (8.0, 2.8), fill: luma(230), radius: 0.02)
  cdraw.content((4.1, 2.0), [the socket], size: 6pt)
  cdraw.line((14.0, 3.8), (8.0, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.2, 3.0), (18.4, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((16.3, 3.8), [`StubHandler`, #linebreak() answers offline], size: 6pt)
  cdraw.content((21.2, 5.8), [one client per request #linebreak() exhausts sockets], size: 6.5pt)
  cdraw.content((21.2, 1.8), [retries and timeouts live #linebreak() in the resilience package], size: 6.5pt)
})

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 81, last: 87, caption: [the client through the stub, no network touched])

For real work, `IHttpClientFactory` manages handler lifetimes, and
resilience policies, retries, timeouts, circuit breakers, live in
`Microsoft.Extensions.Http.Resilience`, the same patterns book 10
implements by hand.

== channels

`System.Threading.Channels` is the bounded queue the thread pool era
wanted. A channel has a writer side and a reader side, unbounded or
bounded with a policy, and the bounded form gives you backpressure:
when the buffer is full, `WriteAsync` parks until the consumer takes
a value. The sample's buffer holds one element, so the producer and
consumer genuinely interleave, and `TryComplete` closes the stream so
`ReadAllAsync` can finish:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 53, last: 79, caption: [capacity one, backpressure real, completion observed])

#diagram([capacity one, the writer and reader interleave], length: 13pt, {
  // writer events above the axis, reader events below
  cdraw.line((0.5, 3.0), (16.0, 3.0), stroke: luma(100), mark: (end: ">"))
  let above = ((2.4, [write 1]), (7.2, [write 2]), (12.0, [`TryComplete`]))
  for (x, t) in above {
    cdraw.line((x, 3.2), (x, 3.5), stroke: luma(100))
    cdraw.content((x, 4.0), t, size: 6pt)
  }
  let below = ((4.8, [read 1]), (9.6, [read 2]), (14.4, [`ReadAllAsync` ends]))
  for (x, t) in below {
    cdraw.line((x, 2.8), (x, 2.5), stroke: luma(100))
    cdraw.content((x, 2.0), t, size: 6pt)
  }
  cdraw.content((7.2, 5.2), [parks until read 1 takes it], size: 6pt)
  cdraw.content((9.0, -0.7), [the buffer holds one, so backpressure is real, #linebreak() fill then drain deadlocks: pair the two sides], size: 6.5pt)
})

#callout("pitfall", "this sample deadlocked on its first draft", [
  The first version awaited both writes before it began reading.
  With capacity one, the second write waits for a reader that never
  comes, and the test hangs. Bounded channels pair a producer and a
  consumer, they are not a buffer you fill then drain. The fix, run
  the producer concurrently, is the shape to copy.
])

Channels are the in-process messaging primitive that book 10 builds
pipelines on, and `await foreach` from chapter 9 is how the reading
side consumes them.

== small utilities that matter

`Random` with an explicit seed is reproducible, which is how the game
systems book gets deterministic replays. `Guid` names things.
`Stopwatch` measures elapsed time without wall clock drift concerns.
`DateTimeOffset` over `DateTime` when the moment matters across
machines. `Interlocked` and `lock` belong to book 10's concurrency
chapters:

#listing("csharp-net/samples/src/Ch16/Streams.cs", first: 89, last: 94, caption: [seeded random, the determinism lever])

#diagram([the determinism levers, seed, name, and offset], length: 13pt, {
  // the utility on the left, the guarantee on the right
  let rows = (
    ([`new Random(42)`], [same seed, same sequence]),
    ([`Guid`], [names things uniquely]),
    ([`DateTimeOffset`], [the offset crosses machines]),
  )
  for (i, row) in rows.enumerate() {
    let y = 4.6 - i * 1.15
    cdraw.rect((0.4, y - 0.5), (5.4, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.9, y), row.at(0), size: 6pt)
    cdraw.line((5.4, y), (6.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.0, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((11.0, 0.0), [`Stopwatch` measures elapsed without wall clock drift, #linebreak() `DateTime` alone is ambiguous across machines], size: 6.5pt)
})

Diagnostics on this machine, `Stopwatch`, `dotnet-counters`,
`dotnet-trace`, and the benchmarking and percentile discipline around
them, get their full treatment in chapter 12. Authoring
observability, `EventSource`, `DiagnosticListener`, and the metrics
APIs you emit from a service, stays with book 10's distributed
observability material.

sources: learn.microsoft.com, system.text.json overview, system.io,
stream class, stringbuilder, system.net.http, system.threading.channels,
and random pages accessed 2026-09-08, what's new in .NET 11
libraries, serialize C\# union types, jsonuniontypestructuralclassifier,
jsonnamingpolicy.pascalcase, stringstream, and rune pages accessed
2026-09-13. Sample behavior verified by `make verify-csharp`,
11 tests.
