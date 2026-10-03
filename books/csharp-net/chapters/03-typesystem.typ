#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the type system

Every type in C\# is either a value type or a reference type. The split runs
through the whole language: it decides what assignment does, what `==`
means, where data lives, and which keywords can declare what. This chapter
builds the full model: the two categories and their conversions, tuples,
the record family, enums, and the two nullable systems, one for value
types and one for references.

== value types and reference types

A value type variable holds its data directly. A reference type variable
holds a reference to an object on the heap. Assignment is where the
difference shows up, so the samples declare one of each:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 3, last: 14, caption: [a struct and a class, same shape, different semantics])

Assigning a struct copies the entire value. Assigning a class copies only
the reference, so both names end up looking at one object:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 49, last: 55, caption: [struct assignment copies the data])

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 57, last: 63, caption: [class assignment copies the reference])

#diagram([what assignment does in each category], length: 13pt, {
  // left: two stack slots each holding a full copy
  cdraw.content((4.6, 6.9), [value type, assignment copies], size: 7pt)
  let vs(x, t) = {
    cdraw.rect((x, 4.8), (x + 2.6, 5.6), fill: luma(230), radius: 0.05)
    cdraw.content((x + 1.3, 5.2), [#t], size: 6.5pt)
  }
  vs(0, "a: 10, 20"); vs(6.6, "b: 10, 20")
  cdraw.line((2.6, 5.2), (6.6, 5.2), mark: (end: ">"))
  cdraw.content((4.6, 5.9), [b = a copies the bytes], size: 6.5pt)
  cdraw.content((4.6, 4.0), [later b.x = 5 leaves a alone], size: 6.5pt)

  // right: two reference slots aimed at one heap object
  cdraw.content((17.4, 6.9), [reference type, assignment aliases], size: 7pt)
  let rs(x, t) = {
    cdraw.rect((x, 4.8), (x + 2.6, 5.6), fill: luma(230), radius: 0.05)
    cdraw.content((x + 1.3, 5.2), [#t], size: 6.5pt)
  }
  rs(11.2, "c -> ref"); rs(17.8, "d -> ref")
  cdraw.rect((13.6, 1.6), (17.6, 3.2), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((15.6, 2.4), [one heap object], size: 6.5pt)
  cdraw.line((12.5, 4.8), (14.8, 3.2)); cdraw.line((19.1, 4.8), (16.4, 3.2))
  cdraw.line((13.8, 5.2), (17.8, 5.2), mark: (end: ">"))
  cdraw.content((15.8, 5.9), [d = c copies the reference], size: 6.5pt)
  cdraw.content((17.4, 0.6), [later d.x = 5 is visible through c], size: 6.5pt)
})

The unified hierarchy sits on top: every type derives from `object`, value
types through `System.ValueType`. A value type becomes an object by
*boxing*, a heap allocation that copies the value in. The box is separate
storage, which the sample proves by mutating the original afterwards:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 65, last: 71, caption: [boxing copies, later mutations do not reach the box])

#callout("pitfall", "boxing hides in hot paths", [
  Boxing happens implicitly whenever a value type is assigned to `object`
  or to an interface it implements, including calls like
  `Console.WriteLine($"{x}")` in older code shapes and non generic
  collections. Each box is an allocation the garbage collector must later
  track. Chapter 10 covers spans and generics as the standard tools that
  keep numeric and collection code boxing free.
])

== choosing a kind of type

The official guidance orders the options by weight. Use a tuple for a
temporary grouping that never leaves the method. Use a `struct` or
`record struct` for small data, roughly 64 bytes or less, where value
semantics fit. Use a `record class` for data centric types that want
value equality and nondestructive mutation. Use a `class` when there is
real behavior, mutable state, or polymorphism, which is most custom types.
Use an `interface` for a contract unrelated types can share. Use an
`enum` for a fixed set of named constants.

#diagram([the kind of type ladder, lightest to heaviest], length: 13pt, {
  // need on the left, the type that buys it on the right
  let rows = (
    ([temporary grouping, method local], [`tuple`]),
    ([small data, ~64 bytes, value copy], [`struct`, `record struct`]),
    ([data centric, value equality], [`record class`]),
    ([behavior, state, polymorphism], [`class`]),
    ([a contract shared types implement], [`interface`]),
    ([a fixed set of named constants], [`enum`]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.5 - i * 1.1
    cdraw.content((5.6, y), row.at(0), size: 6.5pt)
    cdraw.line((11.6, y), (12.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((17.0, y), row.at(1), size: 6.5pt)
  }
})

== tuples

A tuple groups values into a lightweight value type with no declared type
at all. Elements can carry names, tuples deconstruct into variables with
discards for the parts you do not want, and `==` compares element by
element, names irrelevant:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 73, last: 79, caption: [named elements, deconstruction with a discard, tuple equality])

#diagram([a tuple, inline elements, borrowed names, element wise equality], length: 13pt, {
  // one inline value type, the names live only in metadata
  cdraw.content((7.0, 6.9), [a struct with no declared type], size: 7pt)
  cdraw.rect((1.6, 4.8), (12.4, 6.2), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.rect((2.0, 5.1), (6.6, 5.9), fill: luma(230), radius: 0.02)
  cdraw.content((4.3, 5.5), [`Min: 5`], size: 6pt)
  cdraw.rect((7.4, 5.1), (12.0, 5.9), fill: luma(230), radius: 0.02)
  cdraw.content((9.7, 5.5), [`Max: 15`], size: 6pt)
  cdraw.line((12.4, 5.5), (13.8, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.6, 5.5), [the names are metadata, #linebreak() erased at runtime], size: 6.5pt)
  cdraw.content((7.0, 3.5), [`(1, 2) == (1, 2)`: element by element, names irrelevant], size: 6.5pt)
  cdraw.content((7.0, 2.0), [`var (min, _) = stats`: deconstruction binds or discards], size: 6.5pt)
})

Tuples are the honest return type for a function that computes several
things at once. The moment the grouping grows a meaning of its own and
travels between methods, promote it to a record.

== records

A record is a type whose members and equality the compiler synthesizes
from a positional declaration. One line declares a type with
`init`-only positional properties, a primary constructor, value equality,
a readable `ToString`, and a `Deconstruct` method:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 16, last: 27, caption: [record class, derived record, and record struct in three declarations])

#diagram([one record declaration, the six members the compiler synthesizes], length: 13pt, {
  // the declaration on the left, what it buys on the right
  cdraw.rect((0.2, 2.2), (7.2, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((3.7, 3.5), [one positional line #linebreak() `record Book(string Title)`], size: 6pt)
  cdraw.line((7.2, 3.5), (9.0, 3.5), stroke: luma(100), mark: (end: ">"))
  let chips = (
    [`primary ctor`],
    [`init` only props],
    [`ToString`],
    [`Deconstruct`],
    [`with` expression],
    [equality + #linebreak() `EqualityContract`],
  )
  for i in range(6) {
    let col = calc.rem(i, 2)
    let row = calc.floor(i / 2)
    let x0 = 9.4 + col * 6.2
    let y0 = 5.0 - row * 1.8
    cdraw.rect((x0, y0 - 0.8), (x0 + 5.4, y0 + 0.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.7, y0), chips.at(i), size: 6pt)
  }
})

The `with` expression is nondestructive mutation: it copies the instance
and applies changes to the copy, leaving the original untouched. Records
print their contents, which makes them the natural currency of tests and
logs:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 81, last: 87, caption: [with produces a changed copy, equality and printing are synthesized])

Record equality is structural but not blind. The synthesized equality
compares the runtime type first through an `EqualityContract`, so a base
record and a derived record with identical data are not equal:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 89, last: 94, caption: [same data, different runtime type, not equal])

A `record struct` puts the same conveniences on a value type. Its
positional properties are read-write rather than init-only, it cannot
inherit, and `default` gives the all-zero value without running any
constructor:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 96, last: 102, caption: [record struct equality and the zero default])

== union types

Records model data with one fixed shape. A union models a choice: a
value that is exactly one of a declared set of case types. Until
C\# 15 the idiom was a record hierarchy plus a discard arm, correct
but trusted only by discipline. C\# 15, the default language version
when targeting `net11.0` under the book's pinned SDK 11.0.100-rc.1
(RC1, GA November 2026), declares the domain in one line:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 5, last: 11, caption: [three case records and the one line union declaration])

The declaration compiles to a sealed struct implementing
`System.Runtime.CompilerServices.IUnion`: an `object Value` property
holds the active case, one public constructor per case type builds the
union, and an implicit conversion from each case type means the
wrapper does not appear at the construction site:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 33, last: 38, caption: [the case converts into the union implicitly])

Patterns are union aware, `is` and switch arms reach the case rather
than the wrapper:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 40, last: 46, caption: [is testing unwraps to each case])

A switch that names every case is exhaustive, no discard arm, which
removes the silent default arm chapter 6 examines with its failure
modes:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 48, last: 54, caption: [exhaustive over the declared cases, no fallback arm])

#diagram([a union declaration, the struct the compiler generates], length: 13pt, {
  // the declaration at left, the generated struct at right, the reach below
  cdraw.rect((0.4, 4.6), (7.6, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 5.3), [`union Pet(Cat, Dog, Bird)`], size: 6pt)
  cdraw.line((7.6, 5.3), (9.0, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.3, 5.9), [compiles to], size: 6pt)
  cdraw.rect((9.2, 2.8), (16.4, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.8, 5.4), [`struct Pet` : `IUnion`], size: 6pt)
  cdraw.content((12.8, 4.3), [`object Value` holds the case], size: 6pt)
  cdraw.content((12.8, 3.2), [one ctor per case, #linebreak() implicit conversions in], size: 6pt)
  cdraw.line((16.4, 5.3), (17.8, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.0, 4.2), (24.4, 6.4), fill: luma(230), radius: 0.02)
  cdraw.content((21.2, 5.3), [`pet is Cat` #linebreak() reaches the case], size: 6pt)
  cdraw.content((12.8, 1.4), [a value type: assigning it to `object` boxes the wrapper], size: 6.5pt)
})

The union is a value type, so the boxing rules from the start of this
chapter apply unchanged. Assigning the union to `object` copies the
wrapper to the heap, and the box holds the union, not the case inside
it: `boxed is Pet` is true while `boxed is Cat` is false, and the
direct `pet is Cat` still unwraps:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 68, last: 73, caption: [the box holds the union, only the direct is unwraps])

#callout("warning", "a boxed union hides its case from object tests", [
  Code that receives `object` and pattern tests it, the `KindOf`
  classifier of chapter 6, sees the wrapper type and nothing else once
  a union is boxed. Keep unions statically typed across boundaries or
  unbox with a cast before matching.
])

The declaration covers the common case. When the type needs members of
its own, `[Union]` on a class implementing `IUnion` makes the
constructors that take case types the union creation members. Delete
them all and the compiler rejects the type with error CS9385, a union
type must have at least one union creation member. This minimal form
keeps construction explicit and consumes through `Value`: the compiler
did not generate implicit conversions or unwrap patterns for it, and
supplying the `TryGetValue` and `HasValue` members the union reference
calls the non boxing access pattern is what lets patterns match a
custom union's cases directly:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 13, last: 23, caption: [a custom union, constructors are the creation members])

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 56, last: 66, caption: [ok and err paths through the custom union])

#callout("note", "two union attributes exist", [
  `System.Runtime.CompilerServices.UnionAttribute` is the compiler's,
  it is what `[Union]` resolves to in the listings above.
  `System.Text.Json.Serialization.JsonUnionAttribute` is the
  serializer's customization point for how cases are discovered and
  named, part of .NET 11's union serialization support. Same word,
  different machinery, do not swap them.
])

== closed hierarchies

Unions declare their cases inline on a new struct. `closed` solves the
other half of the problem: an existing class hierarchy whose
descendant set should be complete. A `closed` base class can only be
derived from inside its declaring assembly, so the compiler knows
every direct descendant and a switch that handles them all is
exhaustive:

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 25, last: 29, caption: [a closed record class root with three descendants])

#listing("csharp-net/samples/src/Ch03/Unions.cs", first: 75, last: 81, caption: [exhaustive over the direct descendants, no fallback arm])

The modifier is honest about what it does. A closed class is
implicitly abstract, `new PaymentMethod()` does not compile, and
`closed` cannot combine with `sealed`, `static`, or an explicit
`abstract`. Derivation is not transitive: a descendant stays open
unless it is itself closed or sealed, and marking intermediate
descendants `closed` pushes exhaustiveness checking down the tree. One
boundary from the language reference: exhaustiveness follows
visibility. A direct descendant less accessible than the closed base,
an `internal` case under a `public` root, makes switches in other
assemblies warn as non exhaustive because the case cannot be named
there.

#diagram([closed, the descendant set is fixed inside the assembly], length: 13pt, {
  // the root at top, descendants below, the dashed assembly boundary
  cdraw.rect((0.2, 0.4), (14.0, 6.8), stroke: (paint: luma(170), dash: "dashed"), radius: 0.02)
  cdraw.content((2.2, 6.2), [declaring assembly], size: 6pt)
  cdraw.rect((4.4, 4.6), (9.6, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((7.0, 5.2), [`closed` root, abstract], size: 6pt)
  let kids = ((0.8, [`Cash`]), (5.2, [`Card`]), (9.6, [`BankTransfer`]))
  for (x0, t) in kids {
    cdraw.line((7.0, 4.6), (x0 + 2.2, 3.4), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((x0, 2.2), (x0 + 4.4, 3.4), fill: luma(230), radius: 0.02)
    cdraw.content((x0 + 2.2, 2.8), t, size: 6pt)
  }
  cdraw.content((16.6, 4.8), [derive from outside:], size: 6.5pt)
  cdraw.content((16.6, 3.6), [compile error], size: 6.5pt)
  cdraw.content((7.0, 0.9), [every direct descendant handled, the switch is exhaustive], size: 6.5pt)
})

== enums

An enum names a fixed set of integral constants. The underlying type
defaults to `int` and can be any integral type except `char`, which
matters for interop and for packing enums into structs. A `[Flags]` enum
defines members as powers of two so that combinations are themselves
values, with named combinations thrown in:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 29, last: 45, caption: [a simple enum and a flags enum])

The operators `|`, `&`, `^`, and `~` work on every enum type because they
operate on the underlying integer. `ToString` on a flags enum prints the
combination as names, and `HasFlag` tests membership:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 104, last: 108, caption: [combining, printing, and testing flags])

#diagram([enum bits, powers of two combine, names print, casts unchecked], length: 13pt, {
  // one bit per member, the or operator makes combinations
  cdraw.content((6.3, 6.9), [flags are powers of two, `|` makes combinations], size: 7pt)
  let bits = ((0.4, `Read = 1`), (4.6, `Write = 2`), (8.8, `Execute = 4`))
  for (x0, t) in bits {
    cdraw.rect((x0, 4.9), (x0 + 3.8, 5.9), fill: luma(230), radius: 0.02)
    cdraw.content((x0 + 1.9, 5.4), t, size: 6pt)
  }
  // the combination shades exactly the bits it contains
  cdraw.rect((0.4, 3.1), (4.2, 4.1), fill: luma(205), radius: 0.02)
  cdraw.rect((4.6, 3.1), (8.4, 4.1), fill: luma(205), radius: 0.02)
  cdraw.rect((8.8, 3.1), (12.6, 4.1), fill: luma(245), radius: 0.02)
  cdraw.content((6.3, 2.3), [`ReadWrite = Read | Write = 3`], size: 6.5pt)
  cdraw.line((12.6, 5.4), (14.0, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.2, 5.4), [`ToString` prints names #linebreak() `HasFlag` tests membership], size: 6.5pt)
  cdraw.content((18.2, 2.6), [casts never validate, #linebreak() `(Permissions)418` compiles], size: 6.5pt)
  cdraw.content((6.3, 0.9), [underlying type: any integral except `char`], size: 6.5pt)
})

#callout("warning", "numeric to enum casts do not validate", [
  Casting any integer to any enum type compiles and produces a value,
  defined or not. The literal `0` converts implicitly, which is why every
  enum should define a zero member. The sample checks the boundary with
  `Enum.IsDefined`, the standard guard when numbers arrive from outside.
])

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 110, last: 115, caption: [418 is not a member, the cast still succeeds])

== nullable value types

`T?` on a value type is `System.Nullable<T>`, a small wrapper struct that
adds "no value" to a type whose domain could not otherwise express it.
`HasValue` and `Value` inspect it, `??` supplies a fallback, and
`GetValueOrDefault` reads without throwing:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 117, last: 122, caption: [the three ways to read a nullable value type])

#diagram([nullable value types, a wrapper with a has flag beside the value], length: 13pt, {
  // bare T against Nullable<T>, then the three safe reads
  cdraw.content((2.8, 6.0), [bare `T`], size: 7pt)
  cdraw.rect((0.4, 3.8), (5.2, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 4.7), [the value], size: 6pt)
  cdraw.line((5.2, 4.7), (6.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.8, 6.0), [`Nullable<T>`], size: 7pt)
  cdraw.rect((6.4, 3.8), (15.2, 5.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.rect((6.8, 4.1), (10.6, 5.3), fill: luma(230), radius: 0.02)
  cdraw.content((8.7, 4.7), [`HasValue`], size: 6pt)
  cdraw.rect((11.0, 4.1), (14.8, 5.3), fill: luma(230), radius: 0.02)
  cdraw.content((12.9, 4.7), [the value], size: 6pt)
  let reads = ((0.4, 3.4, `HasValue`), (4.4, 3.0, `??`), (8.2, 5.9, `GetValueOrDefault`))
  for (x0, w, t) in reads {
    cdraw.rect((x0, 1.0), (x0 + w, 2.0), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 1.5), t, size: 6pt)
  }
  cdraw.content((18.4, 1.5), [three reads, #linebreak() zero exception risk], size: 6.5pt)
})

The predefined operators are lifted over `T?` as well: arithmetic
yields null when either operand is null, the relational operators
evaluate to false instead, and equality treats two nulls as equal.
`GetValueOrDefault` or `??` before the arithmetic is what keeps a
null from cascading through a whole calculation.

== nullable reference types

`T?` on a reference type is not a wrapper and not a different runtime
type. It is a compile time annotation, one of three parts that together
form nullable reference types: annotations say which variables may hold
`null`, flow analysis tracks whether each expression is *not null* or
*maybe null* at every point, and attributes on APIs express contracts the
syntax cannot, such as "returns null only when the argument was null".
The runtime behavior of a `string` and a `string?` is identical. What
changes is which code the compiler accepts without a warning:

#listing("csharp-net/samples/src/Ch03/Types.cs", first: 124, last: 128, caption: [a null check narrows the flow state of the parameter])

#diagram([nullable reference types, three compile time layers over one runtime type], length: 13pt, {
  // three layers of compile time machinery, nothing changes at run time
  cdraw.rect((0.0, 4.6), (13.2, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((6.6, 5.5), [annotations #linebreak() `string?` says who may hold null], size: 6pt)
  cdraw.rect((0.0, 2.6), (13.2, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 3.5), [flow analysis #linebreak() an `is null` return narrows the state], size: 6pt)
  cdraw.rect((0.0, 0.6), (13.2, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 1.5), [attributes #linebreak() contracts the syntax cannot state], size: 6pt)
  cdraw.line((13.2, 3.5), (14.6, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.4, 3.5), [the runtime sees no difference, #linebreak() one type at run time], size: 6.5pt)
})

After the `is null` return, the compiler knows `name` is not null, so
`name.Length` needs no forgiveness operator. The `!` operator exists for
the cases where you know better than the analysis, and chapter 17 covers
when that is ever justified.

sources: learn.microsoft.com, c\# type system, value types, reference
types, records, record structs, tuple types, enumeration types, nullable
value types, nullable reference types pages accessed 2026-09-08, union
types, custom union types, closed modifier, closed hierarchy patterns
pages accessed 2026-09-13. Sample behavior verified by
`make verify-csharp`, 26 tests.
