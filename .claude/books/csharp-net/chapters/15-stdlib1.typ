#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= stdlib tour 1: collections, memory, numerics

Two chapters walk the parts of the base class library a working C\#
programmer touches weekly. This one covers collections, the memory
utilities that pair with chapter 10, and the numerics stack. Chapter 16
covers io, text, networking, channels, and diagnostics.

== collections

The workhorse types and their contracts. `List<T>` is the dynamic
array, amortized growth, indexed access, the default sequence holder.
`Dictionary<TKey, TValue>` is the hash map, and its idioms matter:
`GetValueOrDefault` reads a possibly missing key without a throw,
`TryGetValue` reads and tests in one step, and the indexer writes or
replaces in one:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 8, last: 16, caption: [List as the dynamic array])

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 18, last: 28, caption: [counting words the dictionary way])

.NET 11 removes the wrapper record for one small hashing problem:
`EqualityComparer<T>.Create` builds a comparer from a key selector,
so a dictionary can hash by the trimmed, cased, or otherwise
projected form of its keys:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 74, last: 85, caption: [equality keyed through a projection, no wrapper record])

`HashSet<T>` is the membership structure with set algebra built in.
`Queue<T>` and `Stack<T>` are fifo and lifo. `PriorityQueue<TElement,
TPriority>` pops by priority, and `SortedList` and
`SortedDictionary` keep order at the cost of operations becoming
logarithmic:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 30, last: 37, caption: [set union and membership])

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 39, last: 54, caption: [fifo, lifo, and priority order in one method])

#diagram([the workhorse collections, one contract each], length: 13pt, {
  // the type on the left, its shape and cost story on the right
  let rows = (
    ([`List<T>`], [dynamic array, amortized growth]),
    ([`Dictionary<K,V>`], [hash map, `TryGetValue` idioms]),
    ([`HashSet<T>`], [membership, set algebra]),
    ([`Queue<T>`], [fifo, fairness]),
    ([`Stack<T>`], [lifo, the most recent first]),
    ([`PriorityQueue<E,P>`], [pops by priority, urgency]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.6 - i * 1.15
    cdraw.rect((0.4, y - 0.5), (5.0, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.7, y), row.at(0), size: 6pt)
    cdraw.line((5.0, y), (6.0, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.4, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((11.5, -1.0), [sorted types keep order at logarithmic cost, #linebreak() immutable siblings return new collections on change], size: 6.5pt)
})

The immutable siblings (`ImmutableList<T>`,
`ImmutableDictionary<TKey, TValue>`, and friends) share interfaces
with these but return new collections on every change, the functional
option for state you want to share without defensive copies.

== frozen collections

`FrozenDictionary<TKey, TValue>` and `FrozenList<T>` (.NET 8) are the
read heavy end of the spectrum. Building one costs more than a
dictionary, reads after that are measurably faster because the
structure optimizes for the actual keys at freeze time. The rule:
build once at startup from a dictionary, read for the process
lifetime:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 56, last: 62, caption: [freeze a dictionary once, look up forever])

#diagram([frozen collections, pay at freeze, read cheaper forever], length: 13pt, {
  // total cost against lookups, two lines, one crossover
  cdraw.line((2.0, 0.4), (2.0, 5.8), stroke: luma(100))
  cdraw.line((2.0, 0.4), (14.2, 0.4), stroke: luma(100))
  cdraw.content((1.1, 6.2), [total cost], size: 6.5pt)
  cdraw.content((13.4, -0.2), [lookups], size: 6.5pt)
  cdraw.line((2.0, 0.9), (13.8, 5.3), stroke: luma(100))
  cdraw.line((2.0, 2.5), (13.8, 3.9), stroke: luma(100))
  cdraw.content((10.4, 4.9), [`Dictionary`], size: 6pt)
  cdraw.content((10.6, 2.7), [`FrozenDictionary`], size: 6pt)
  cdraw.circle((8.85, 3.49), radius: 0.14, stroke: luma(100))
  cdraw.content((8.85, 1.0), [reads win from here on], size: 6.5pt)
  cdraw.content((4.3, 3.3), [dearer build], size: 6pt)
  cdraw.content((8.5, -1.35), [build once at startup, read for the process lifetime], size: 6.5pt)
})

== memory utilities

Chapter 10 covered `Span<T>`, `Memory<T>`, and `stackalloc`. The
collection side of that story is `ArrayPool<T>`, the shared pool for
large temporary arrays: rent, use, return, and let the next caller
reuse the same allocation instead of feeding the large object heap.
`ReadOnlySequence<T>` chains buffer segments for parsers. Chapter 11
goes deep on the pool's contract and its ownership rules, and both
matter in parsing and networking code, which chapter 16 revisits.

#diagram([arraypool cycles arrays, the sequence chains segments], length: 13pt, {
  // the rent-use-return cycle at left, the segment chain at right
  cdraw.rect((1.6, 4.6), (5.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 5.2), [`Rent`], size: 6pt)
  cdraw.line((5.6, 5.2), (7.6, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.8, 4.6), (11.8, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 5.2), [use it], size: 6pt)
  cdraw.line((9.8, 4.6), (8.6, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 1.8), (11.4, 3.0), fill: luma(235), radius: 0.02)
  cdraw.content((9.4, 2.4), [`Return`], size: 6pt)
  cdraw.line((7.4, 2.4), (3.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.0, 3.2), [the next caller #linebreak() gets the same array], size: 6.5pt)
  cdraw.rect((14.6, 4.6), (17.0, 5.8), fill: luma(230), radius: 0.02)
  cdraw.rect((17.4, 4.6), (19.8, 5.8), fill: luma(230), radius: 0.02)
  cdraw.rect((20.2, 4.6), (22.6, 5.8), fill: luma(230), radius: 0.02)
  cdraw.line((17.0, 5.2), (17.4, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.8, 5.2), (20.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.6, 3.6), [`ReadOnlySequence<T>`: #linebreak() segments chained for parsers], size: 6.5pt)
  cdraw.content((9.0, 0.4), [the pool starves the large object heap], size: 6.5pt)
})

== numerics

`Math` carries the scalar functions, `Math.Clamp`, `Math.Sqrt`, and
friends, with no surprises. `BigInteger` is arbitrary precision with
no operator limits. The `System.Numerics` vector types, `Vector<T>`
and the fixed size `Vector128<T>` through `Vector512<T>`, expose SIMD
(single instruction, multiple data) without intrinsics, one expression
that the JIT compiles to the
widest register the machine has:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 64, last: 72, caption: [big integers, scalar math, and a hardware check])

#diagram([simd lanes, one wide add against four narrow ones], length: 13pt, {
  // the scalar column at left, the vector column at right
  let cells = ((0.2, 4.8), (8.6, 4.8))
  cdraw.content((3.2, 6.4), [scalar], size: 6.5pt)
  cdraw.content((11.6, 6.4), [vector], size: 6.5pt)
  for (x0, _) in cells {
    for i in range(4) {
      cdraw.rect((x0 + i * 1.5, 4.9), (x0 + 1.3 + i * 1.5, 5.9), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + 0.65 + i * 1.5, 5.4), [a#i], size: 6pt)
      cdraw.rect((x0 + i * 1.5, 3.3), (x0 + 1.3 + i * 1.5, 4.3), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + 0.65 + i * 1.5, 3.8), [b#i], size: 6pt)
    }
  }
  for i in range(4) {
    cdraw.content((0.85 + i * 1.5, 4.6), [+], size: 6pt)
  }
  cdraw.content((11.55, 4.6), [+], size: 6pt)
  for i in range(4) {
    cdraw.rect((0.2 + i * 1.5, 1.7), (1.5 + i * 1.5, 2.7), fill: luma(230), radius: 0.02)
    cdraw.content((0.85 + i * 1.5, 2.2), [s#i], size: 6pt)
  }
  cdraw.rect((8.6, 1.7), (14.6, 2.7), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 2.2), [all four sums], size: 6pt)
  cdraw.content((17.6, 5.4), [one expression, #linebreak() the widest register], size: 6.5pt)
  cdraw.content((18.0, 3.0), [`Vector128` through #linebreak() `Vector512`], size: 6.5pt)
  cdraw.content((11.6, 0.4), [`BigInteger` lifts the precision limit], size: 6.5pt)
})

The `INumber<T>` family from chapter 5 is the bridge between these:
generic algorithms written once run over `int`, `double`,
`BigInteger`, and the vectors' element types.

== decimal floating point

`double` cannot store one tenth: 0.1 is an infinitely repeating
binary fraction, and ten additions land just under one. .NET 11 adds
the IEEE 754-2019 decimal encodings, `Decimal32` with 7 significant
digits, `Decimal64` with 16, and `Decimal128` with 34, where a
decimal digit is stored directly and one tenth is exact. They carry
infinities and NaN like the binary floats, they implement the
generic math interfaces so the chapter 5 algorithms run over them,
and conversion from `decimal` keeps the scale:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 87, last: 99, caption: [tenths sum to exactly one, the binary sum misses])

Decimal encodings also make trailing zeros meaningful. `1.00` and
`1` are equal values at different quantum, the unit of the last
stored digit, which is what `decimal`'s scale was approximating all
along. Two values can be equal and still fail `HaveSameQuantum`,
money that claims cent precision against money that does not:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 101, last: 109, caption: [equal values, different quantum, trailing zeros are data])

#diagram([binary cannot name one tenth, decimal can], length: 13pt, {
  // the binary side with its repeating expansion, the decimal side exact
  cdraw.rect((0.2, 3.8), (9.0, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 4.9), [`double`: 0.1 is #linebreak() 0.000110011... repeating], size: 6pt)
  cdraw.content((4.6, 4.2), [ten sums: 0.99999999999999989], size: 6pt)
  cdraw.line((9.2, 4.7), (10.2, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 3.8), (19.2, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((14.8, 4.9), [`Decimal128`: one digit after #linebreak() the point, 0.1 exact], size: 6pt)
  cdraw.content((14.8, 4.2), [ten sums: 1.0 exactly], size: 6pt)
  cdraw.content((9.7, 2.9), [`1.00` and `1`: equal values, #linebreak() quantum 0.01 against 1], size: 6.5pt)
  cdraw.content((9.7, 1.2), [`Decimal32` 7 digits, `Decimal64` 16, `Decimal128` 34], size: 6.5pt)
})

The same release adds `BFloat16`, the 16-bit brain float from the ML
world: `float`'s exponent range with 8 mantissa bits, roughly three
decimal digits, for storing tensors that are computed elsewhere at
full width. `BitConverter` converts it to and from bits, and
`Complex<T>` now runs over it, the decimal types, `float`, and
`Half` alike:

#listing("csharp-net/samples/src/Ch15/Stdlib.cs", first: 111, last: 118, caption: [range kept, precision spent: 1.23456789 lands on 1.234])

#callout("note", "decimal the type against decimal the encodings", [
  `decimal` stays the money type for in-process arithmetic: base-10
  scaled integers, exact for addition and subtraction, no NaN, and
  every existing API takes it. Reach for the IEEE decimal types when
  something outside the process speaks decimal, SQL `DECIMAL`, JSON
  numbers past 28 digits, or another implementation of the standard,
  or when the huge exponent range, infinities, and NaN are the shape
  of the data rather than a bug.
])

#callout("note", "choosing a collection", [
  Default to `List<T>` for order and `Dictionary<TKey, TValue>` for
  lookup. Switch to `HashSet<T>` when membership questions dominate,
  `Queue<T>` when fairness matters, `PriorityQueue` when urgency does,
  sorted types when iteration order is the product, immutable types
  when sharing beats mutation, and frozen types when reads outnumber
  writes by thousands to one. Book 9 implements most of these from
  first principles, which is where the performance intuition comes
  from.
])

sources: learn.microsoft.com, system.collections.generic overview,
frozen collections, arraypool, system.numerics, and bigint pages
accessed 2026-09-08, what's new in .NET 11 libraries, decimal32,
decimal64, decimal128, bfloat16, and equalitycomparer.create pages
accessed 2026-09-13. Sample behavior verified by `make verify-csharp`,
10 tests.
