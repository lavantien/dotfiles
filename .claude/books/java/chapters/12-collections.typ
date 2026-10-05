#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= collections and streams

Almost every java program moves values through `List`, `Set`, `Map`,
and the stream pipeline that replaced half the loops in the language
at 8. This chapter walks the framework top to bottom: the interface
hierarchy, the implementations and their complexity contracts, the 21
unification of first and last access, the factory methods since 9,
streams at full depth including the 24 gatherer extension point, and
the swing from imperative loops to pipelines, taught as a refactor
arc rather than a religion.

== the hierarchy

`Collection` is the grouping contract, `Map` sits beside it, not
above it, because a map of pairs is not a collection of elements.
Under `Collection`: `List` is ordered with duplicates and index
access, `Set` rejects duplicates, `Queue` hands out the head. `SortedSet`
and `SortedMap` add ordering, `Iterator` and `Iterable` power the
foreach loop over all of it. The contracts are old, 1.2 for the
framework, 5 for generics, and stable since.

The implementations are the performance story, and the complexity
contracts decide which one a workload wants:

#diagram([the implementation shelf, representation against the operations it wins], length: 13pt, {
  let row(y, name, rep, ops, fill) = {
    cdraw.rect((0.3, y - 1.0), (5.3, y), fill: luma(235), radius: 0.02)
    cdraw.content((2.8, y - 0.5), [#name], size: 6.5pt)
    cdraw.rect((5.5, y - 1.0), (12.0, y), fill: fill, radius: 0.02)
    cdraw.content((8.75, y - 0.5), [#rep], size: 6pt)
    cdraw.rect((12.2, y - 1.0), (23.5, y), fill: luma(235), radius: 0.02)
    cdraw.content((17.85, y - 0.5), [#ops], size: 6pt)
  }
  cdraw.content((2.8, 7.2), [type], size: 6.5pt)
  cdraw.content((8.75, 7.2), [representation], size: 6.5pt)
  cdraw.content((17.85, 7.2), [the contract that picks it], size: 6.5pt)
  row(6.4, [ArrayList], [dynamic array], [get and set O(1), add amortized O(1), middle inserts O(n)], luma(228))
  row(5.2, [LinkedList], [doubly linked], [ends O(1), indexed access O(n), also a Deque], luma(228))
  row(4.0, [ArrayDeque], [circular array], [stack and queue ends O(1), the Stack replacement], luma(228))
  row(2.8, [HashSet], [hash table], [add, remove, contains O(1), no order], luma(228))
  row(1.6, [TreeSet], [red-black tree], [sorted iteration, O(log n) ops, range views], luma(228))
  row(0.4, [HashMap], [hash table], [put, get, remove O(1), one null key], luma(228))
  row(-0.8, [TreeMap], [red-black tree], [sorted keys, O(log n), head, tail, sub views], luma(228))
})

`LinkedHashMap` keeps a list threaded through the hash table for
insertion or access order, the access-order mode builds an lru cache
in one line. `Vector` and `Stack` are the synchronized 1.0 fossils,
`ArrayDeque` replaces the second. Nothing in `java.util` is
threadsafe, the concurrent package carries that load:
`ConcurrentHashMap` for lock-striped maps, `CopyOnWriteArrayList`
for read-mostly lists, and the blocking queues chapter 10 met as the
executor handoff.

The `equals` and `hashCode` contract governs membership in every
hash structure: equal objects must hash equal, or a `HashSet` loses
elements it is holding. Records get both for free from their
components, classes write them by hand at their peril.

== sequenced collections

Before 21 the ends were a dialect: `list.get(0)` and
`list.get(list.size() - 1)`, `set.first()` on sorted sets only,
`map.keySet().iterator()` to find a map's first key. Jep 431 (final
in 21) made one interface, `SequencedCollection`, that `List`,
`Deque`, and `LinkedHashSet` implement, with `SequencedSet` and
`SequencedMap` beside it. One vocabulary: `getFirst`, `getLast`,
`addFirst`, `addLast`, `removeFirst`, `removeLast`, `reversed`, and
on maps `putFirst`, `putLast`, `firstEntry`, `lastEntry`, and the
two polls.

#listing("java/samples/src/Ch12/Sequenced.java", first: 15, last: 27, caption: [a list speaks the unified ends vocabulary])

`reversed()` returns a view, not a copy, mutations through it write
through to the original, and the view costs one object. The sample
then walks the same vocabulary across `LinkedHashSet` and
`LinkedHashMap`:

#listing("java/samples/src/Ch12/Sequenced.java", first: 28, last: 53, caption: [sets and maps answer the same first and last questions])

Twelve checks cover the three families. The interface shows up in
api signatures too: a parameter declared `SequencedCollection`
states it cares about encounter order, and `HashSet` cannot even
be passed, it does not implement the interface.

== factories since 9

`List.of("a", "b")`, `Set.of(1, 2, 3)`, `Map.of("one", 1)` and
`Map.entry(k, v)` for the varargs form, `Map.ofEntries(entry(...),
entry(...))`. All return unmodifiable collections, fixed-arity
overloads up to ten arguments and a varargs fallback, `Set.of`
throws on duplicate elements at creation rather than silently
dropping them. Since 10 they carry the immutable collections' fight
against interface bloat: `List.copyOf`, `Set.copyOf`, `Map.copyOf`
take any source and return the unmodifiable shape, reusing the
argument itself when it already qualifies. The empty forms,
`List.of()` and friends, replace `Collections.emptyList`.

== the stream api

Streams arrived at 8 as the collection pipeline: a source, zero or
more lazy intermediate stages, one eager terminal. The first fact
worth internalizing is the laziness itself:

#listing("java/samples/src/Ch12/Streams.java", first: 16, last: 32, caption: [no terminal operation, no work, and short circuits cut the run])

`peek` counts element visits, and the counter reads zero until the
terminal runs. `findFirst` stops the pull after the first passing
element, three visits for this data, which is the semantics infinite
streams ride: `IntStream.iterate` produces forever, only a
short-circuiting terminal makes it finite. Streams are single use,
a consumed stream throws `IllegalStateException` on a second
terminal, and they are not collections, nothing is stored, elements
flow through.

Primitive streams exist because generics cannot specialize:
`IntStream`, `LongStream`, `DoubleStream` avoid the `Integer` boxing
on every element and carry the math terminals, `sum`, `average`,
`min`, `max`, `summaryStatistics`, plus `range` and `rangeClosed`
as sources. `mapToInt`, `mapToObj`, and `boxed` cross between the
worlds.

#listing("java/samples/src/Ch12/Streams.java", first: 33, last: 57, caption: [primitive streams and the standard collectors])

The collectors are the terminal vocabulary: `groupingBy` with a map
factory and a downstream collector, `counting`, `joining`,
`toMap`, `partitioningBy`, `mapping`, and `collectingAndThen` to
post-process. `toList()` (16) is the unmodifiable shortcut for the
most common collection of all, the sample proves the immutability
by failing to add to it.

== stream gatherers

The fixed stages could not express windowing, running state, or
custom cardinality, and the pre-24 answer was always "write a
collector or a spliterator", both wrong shapes for a mid-pipeline
operation. Jep 485 (final in 24) added `Stream.gather`, taking a
`Gatherer`: an initializer for per-pipeline state, an integrator
that sees state, element, and a downstream push, and optional
finisher and combiner for parallel merges. The jdk ships five in
`java.util.stream.Gatherers`.

#listing("java/samples/src/Ch12/Gatherers.java", first: 17, last: 30, caption: [the built-in windows, fixed and sliding])

`windowFixed` batches, `windowSliding` rolls, `fold` scans a
running value, `mapConcurrent` maps with bounded concurrency on
virtual threads. Writing one is the point of the api:

#listing("java/samples/src/Ch12/Gatherers.java", first: 31, last: 62, caption: [two custom gatherers, state carried, cardinality changed])

The running maximum keeps its state in a mutable cell the
initializer supplies, one cell per pipeline evaluation, so parallel
splits stay safe. The lesson the sample teaches by construction:
the state must be mutable, the first draft used an `Integer` and
the maximum silently reset to the input every element, the
integrator can read an immutable state but never writes it back.
The collapse-runs gatherer shows the cardinality freedom, fewer
outputs than inputs, which no intermediate stage before 24 could
do. Gatherers are lazy like every stage, the last check builds a
gathered pipeline and proves zero work happens until the terminal.

== the swing from imperative

The arc every codebase rides, in one shape. First the loop:

#snippet("int total = 0;\nfor (String w : words) {\n  if (w.length() > 3) {\n    total += w.length();\n  }\n}", lang: "java")

Then the pipeline:

#snippet("int total = words.stream()\n  .filter(w -> w.length() > 3)\n  .mapToInt(String::length)\n  .sum();", lang: "java")

The pipeline names its stages, composes, parallelizes with one
`.parallel()`, and drops the loop scaffolding. The discipline that
keeps it readable: stages stay pure, side effects live in `peek`
for debugging and `forEach` for terminal effect only, the whole
pipeline fits a screen, and the terminal is where the answer
leaves. When the shape needs mid-pipeline state or windowing, a
gatherer extends the vocabulary instead of falling back to the
loop. Loops remain correct code: small, index-coupled, or
short-circuiting-on-two-conditions logic is often clearer as a
loop, and the best java developers carry both and choose per
problem, the service spine in chapter 19 leans on pipelines
throughout because request handling is a pipeline.

sources: JEP 431 sequenced collections (openjdk.org/jeps/431) and
JEP 485 stream gatherers (openjdk.org/jeps/485), accessed 2026-10-04.
API since tags verified against the pinned build's own source:
SequencedCollection 21, Gatherer and Gatherers 24, read from
tools/jdk27/build/jdk-27/lib/src.zip. The 8-to-17 arcs (the
interface hierarchy, implementation tables with complexity
contracts, optional operations and UnsupportedOperationException,
iteration and ConcurrentModificationException, queue semantics,
Collections and Arrays utilities, the stream api's filter map
reduce core and laziness) ground on Java in a Nutshell 8th edition
chapter 8, pages 283 to 317. Behavior verified by
`java/samples/src/Ch12` under `pwsh tools/run-java-samples.ps1
-Chapter Ch12`: 28 checks, including the mutable-state gatherer
lesson (an Integer state silently no-ops, an int array state works)
probed on the pinned jdk 27, dated 2026-10-04.
