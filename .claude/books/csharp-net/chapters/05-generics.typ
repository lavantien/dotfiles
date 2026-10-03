#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= generics

Generics let one declaration work over many types with compile time
checking, no casts at use sites, and one copy of the logic. A type
parameter like `T` is filled in at each use, producing a *constructed
type* such as `List<int>`. Unlike Java's erasure, .NET generics are
reified: `List<int>` and `List<string>` are distinct types at runtime,
and `typeof(List<int>)` knows its own argument. This chapter covers the
three parts that matter: constraints, variance, and static abstract
members.

== constraints

A bare `T` can do almost nothing, because the compiler only knows it
derives from `object`. A `where` clause narrows T, and every constraint
purchases operations. `IComparable<T>` unlocks `CompareTo`. `new()`
unlocks construction. `class`, `struct`, `notnull`, `unmanaged`, and base
type constraints restrict the argument domain, and a parameterless
constructor constraint composes with them:

#listing("csharp-net/samples/src/Ch05/Generics.cs", first: 5, last: 17, caption: [two constraints, each one unlocking an operation])

#diagram([each constraint purchases the operations it unlocks], length: 13pt, {
  // the constraint on the left, what it buys on the right
  let rows = (
    ([bare `T`], [`object` members only]),
    ([`IComparable<T>`], [`CompareTo`, ordering]),
    ([`new()`], [`new T()`, construction]),
    ([static abstract], [`Zero`, the `+` operator]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.4
    cdraw.rect((0.4, y - 0.55), (5.4, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((2.9, y), row.at(0), size: 6pt)
    cdraw.line((5.4, y), (6.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((11.4, y), row.at(1), size: 6.5pt)
  }
})

The standard library leans on constraints everywhere, `List<T>` itself
enumerates fine as bare `T` but sorts only when the element is
`IComparable<T>`.

== variance

Should `IProducer<Cat>` convert to `IProducer<Animal>`? With an invariant
type parameter, no: the two constructed types are unrelated even though
their arguments are related. Variance is the declaration that makes the
conversion legal. Mark a parameter `out` when it only appears in output
positions, then everyone producing cats produces animals, which is safe.
Mark it `in` when it only appears in input positions, then anything that
consumes objects consumes strings:

#listing("csharp-net/samples/src/Ch05/Generics.cs", first: 19, last: 28, caption: [covariant out and contravariant in declared])

Both conversions are happening in the sample's callers, through classes
that implement the narrow forms:

#listing("csharp-net/samples/src/Ch05/Generics.cs", first: 30, last: 46, caption: [a cat producer read as an animal producer, an object renderer used as a string consumer])

#callout("verify", "the sample suite hit this rule itself", [
  The first draft of this chapter's sample produced `int` and tried to
  view it as `IProducer<object>`. The compiler rejected it: variance
  conversions are reference conversions, and a value type argument makes
  the constructed type invariant. The fix was the `Cat` to `Animal`
  hierarchy above. The rule costs nothing in practice, because boxing
  an `IEnumerable<int>` into an `IEnumerable<object>` would allocate a
  wrapper and destroy the point.
])

#snippet(
  "IProducer<object> wide = new IntProducer(7);\n"
  + "// error CS0029: cannot implicitly convert type 'IntProducer'\n"
  + "// to 'IProducer<object>'   value types do not vary\n",
  lang: "cs",
)

#diagram([variance legality, out and in convert, value types freeze], length: 13pt, {
  // the declaration on the left, the conversion it licenses on the right
  let rows = (
    ([`out T`], [`IProducer<Cat>` reads as `IProducer<Animal>`]),
    ([`in T`], [`IConsumer<object>` used as `IConsumer<string>`]),
    ([value type], [`IProducer<int>` to `IProducer<object>` is CS0029]),
  )
  for (i, row) in rows.enumerate() {
    let y = 4.8 - i * 1.6
    cdraw.rect((0.4, y - 0.55), (4.4, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((2.4, y), row.at(0), size: 6pt)
    cdraw.line((4.4, y), (5.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((12.6, y), row.at(1), size: 6.5pt)
  }
})

Variance annotations are only allowed on interfaces and delegates,
never on classes or structs. `IEnumerable<out T>`, `Func<in T, out
TResult>`, and `Action<in T>` from the standard library are all variant,
which is why lambdas and sequences compose across related types without
casts.

== static abstract members and generic math

The oldest gap in generics: `T a + T b` did not compile, because
operators were static members of concrete types and static members were
invisible to type parameters. C\# 11 closed it by letting interfaces
declare `static abstract` members, including operators. A type parameter
constrained to such an interface can then use the operator, and each
concrete type supplies its own
implementation:

#listing("csharp-net/samples/src/Ch05/Generics.cs", first: 48, last: 61, caption: [a monoid interface: a zero element and a plus operator])

With that interface, summation over any complying type is one generic
method. `TSelf.Zero` and `+=` both resolve through the constraint:

#listing("csharp-net/samples/src/Ch05/Generics.cs", first: 65, last: 71, caption: [generic summation driven entirely by the constraint])

The standard library ships this pattern as `System.Numerics`. `INumber<T>`
constrains the whole numeric tower, integers, floats, and decimals, so
one `Sum` covers them all with no overloads and no boxing:

#listing("csharp-net/samples/src/Ch05/Generics.cs", first: 73, last: 79, caption: [the same summation over the standard numeric hierarchy])

#diagram([generic math, one sum resolved through per-type static slots], length: 13pt, {
  // the method above, the interface slots in the middle, the concrete types below
  cdraw.rect((0.4, 5.4), (7.8, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((4.1, 5.9), [`Sum<TSelf>`, one body], size: 6pt)
  cdraw.line((4.1, 5.4), (4.1, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.0, 3.2), (14.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((8.0, 3.9), [`ICounter<TSelf>` declares static slots: `Zero`, `+`], size: 6pt)
  cdraw.line((4.4, 3.2), (4.4, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.6, 3.2), (11.6, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.2, 1.2), (7.6, 2.6), fill: luma(230), radius: 0.02)
  cdraw.content((4.4, 1.9), [`Tally` #linebreak() its own `Zero`, `+`], size: 6pt)
  cdraw.rect((8.4, 1.2), (14.8, 2.6), fill: luma(230), radius: 0.02)
  cdraw.content((11.6, 1.9), [`int` #linebreak() its own `Zero`, `+`], size: 6pt)
  cdraw.content((8.0, -0.5), [no boxing, no overload family #linebreak() `INumber<T>` is the stdlib instance of this shape], size: 6.5pt)
})

#callout("note", "generic math, not numeric reflection", [
  Before static abstracts, generic numeric code either boxed to `dynamic`
  or shipped one overload per type. The `INumber<T>` family replaced both.
  The interpreter capstone uses the same monoid shape to fold values over
  a visitor, which is the pattern to reach for whenever a generic
  algorithm needs an identity element and a combine operation.
])

sources: learn.microsoft.com, generic type parameters, constraints on
type parameters, covariance and contravariance in generics, variance in
generic interfaces, generic math, and system.numerics pages, accessed
2026-09-08. Sample behavior verified by `make verify-csharp`, 6 tests.
