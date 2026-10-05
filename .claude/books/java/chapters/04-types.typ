#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= types and values

Java values come in exactly two kinds, and the split explains most of
the language's daily friction. A primitive value is its own bits, one
of eight fixed types. A reference value is a pointer the program can
never dereference by hand, null or an object. Assignment and argument
passing always copy the value, the bits or the reference, never the
object contents, so java is pass by value with references among its
values. This chapter walks the primitives and their arithmetic,
`boolean` and `char` as the two odd members, the `String` and boxing
story on the reference side, `var` inference, records and sealed
hierarchies as the modern data shapes, null and `Optional`, and the
conversion lattice that ties the numeric types together. Chapter 2
walked the ladder, and most of what follows arrived on its rungs:
boxing in 5, `var` in 10, records final in 16, sealed in 17.

== the eight primitives

#table(
  columns: (auto, 1fr, auto, 1fr),
  inset: 4pt,
  table.header([*type*], [*kind*], [*bits*], [*range and default*]),
  [`byte`], [signed integer], [8], [-128 to 127, default 0],
  [`short`], [signed integer], [16], [-32768 to 32767, default 0],
  [`int`], [signed integer], [32], [-2147483648 to 2147483647, default 0],
  [`long`], [signed integer], [64], [-9223372036854775808 to 9223372036854775807, default 0],
  [`float`], [ieee 754 binary32], [32], [1.4E-45 to 3.4028235E38, default 0.0],
  [`double`], [ieee 754 binary64], [64], [4.9E-324 to 1.7976931348623157E308, default 0.0],
  [`char`], [unsigned utf-16 code unit], [16], [0 to 65535, default NUL],
  [`boolean`], [truth value], [jvm-dependent], [true or false, default false],
)

Widths are fixed by the specification, not by the machine the code
runs on, which is the portability promise c never made: a `long` is 64
bits everywhere and `Integer.MAX_VALUE` is the same constant on every
vm. The two counts the sample pins first.

#listing("java/samples/src/Ch04/Primitives.java", first: 18, last: 24, caption: [widths through the SIZE constants, ranges through MIN and MAX])

== integer arithmetic wraps

Integer overflow is not an error in java, it is the two's-complement
wrap the hardware already does. The compiler says nothing, the runtime
says nothing, and the one value with no positive counterpart,
`Integer.MIN_VALUE`, negates to itself through the same wrap, which is
why `Math.abs` can return a negative number.

#listing("java/samples/src/Ch04/Primitives.java", first: 26, last: 44, caption: [the wrap measured, and the exact family that refuses instead])

When silence is the bug, java 8 shipped the escape hatch: `addExact`,
`subtractExact`, `multiplyExact`, and `incrementExact` check and throw
`ArithmeticException` on overflow, the message a plain `integer
overflow`. Anything that accumulates counts from the outside world,
money, sequence ids, timestamps summed over a queue, belongs on the
exact forms. Division has its own discipline: it truncates toward
zero, `modulo` takes the dividend's sign, and integer division by zero
is the one arithmetic error that always throws.

#listing("java/samples/src/Ch04/Primitives.java", first: 46, last: 55, caption: [truncation toward zero on both signs, and the one throwing operation])

== float and double at the bit level

Both floating types are ieee 754 with a fixed layout: one sign bit, 8
or 11 exponent bits, 23 or 52 stored mantissa bits, the biased
exponents 127 and 1023 for 1.0. The representation is why 0.1 has no
exact resident and why adding money in doubles corrupts it:
#xref-to("math", "float") takes the format apart bit by bit and owns
the depth, this chapter only needs the measured behavior and the
special values.

#listing("java/samples/src/Ch04/Primitives.java", first: 57, last: 63, caption: [the bit patterns of 1.0 in both widths, and the tenths that do not add])

Floating arithmetic never throws. Overflow runs to infinity,
underflow runs to a signed zero that equals zero under `==` but keeps
its sign through division, and the illegal operations produce NaN, the
only value in the language unequal to itself, so NaN tests go through
`Double.isNaN`. One naming trap: `Float.MIN_VALUE` is the smallest
positive value, not the most negative, the opposite convention from
`Integer.MIN_VALUE`.

#listing("java/samples/src/Ch04/Primitives.java", first: 65, last: 73, caption: [infinities, the two zeros, NaN, and the MIN_VALUE naming trap])

== boolean, the type that converts to nothing

`boolean` has exactly two values and no arithmetic, and it is the only
primitive that converts to and from no other type, not int, not
anything. The c idiom of testing an integer's truth is a compile
error, which forces the comparison into the source and is generally
counted a win:

#snippet("int count = 1;\nif (count) { }        // error: int cannot be converted to boolean\nif (count != 0) { }  // the explicit form the language demands", lang: "java")

== char, the utf-16 code unit

`char` is a 16-bit unsigned integer that also spells a character, so
it widens into arithmetic and reads as a number when cast. The same 16
bits walk through `char` unsigned and through `short` signed, one of
the quiet asymmetries worth seeing once. Unicode outgrew the 16 bits
long ago: code points past U+FFFF, the supplementary planes, ride a
surrogate pair of two chars, a high followed by a low, so `length`
counts units while `codePointCount` counts characters, and the emoji
in the sample is two of one and one of the other.

#listing("java/samples/src/Ch04/Primitives.java", first: 75, last: 85, caption: [char as number, the signed and unsigned readings, and the surrogate pair])

The working rule that follows: apis that index text by `int` code
point, `codePointAt`, `codePoints`, `offsetByCodePoints`, are the safe
vocabulary on text that might hold anything beyond the basic
multilingual plane, and chapter 13's string api sits on top of it.

== String, immutable and pooled

`String` is a reference type with literal syntax, immutable by design,
and every method returns a new string rather than moving the original,
which is what makes sharing one across threads free of races and keys
safe in hash structures. The pool is the other half: string literals
are interned into one shared copy per value at class load, constant
expressions fold and intern at compile time as chapter 3 measured, and
runtime-built strings join the pool only through an explicit
`intern()`.

#listing("java/samples/src/Ch04/References.java", first: 42, last: 52, caption: [the pool through intern, and the new object every method returns])

== boxing and the cache

Every primitive has a wrapper class, `Integer` for `int` and so on,
and since 5 the conversion runs automatically in both directions.
Autoboxing calls `Integer.valueOf`, which serves small values from a
cache that runs -128 to 127 by default, its top measured at 127 on
this jvm, and constructs fresh
objects above it, so `==` on boxed integers is a reference comparison
that happens to work in the cache band and fails right past it. The
constructors are deprecated since 9, measured on the pinned build with
`forRemoval` false, and `valueOf` is the only spelling worth keeping.
The reverse direction has its own trap: unboxing a null wrapper throws
`NullPointerException`, because there is no such thing as a null int.

#listing("java/samples/src/Ch04/References.java", first: 54, last: 66, caption: [the cache boundary measured, 127 true at == and 128 not])

#listing("java/samples/src/Ch04/References.java", first: 67, last: 82, caption: [the deprecation read reflectively, and unboxing null])

#callout("pitfall", "the == that works until it does not", [
  Boxed small integers compare equal under `==` inside the cache band
  and stop the moment a value crosses 127, which is why the failure
  surfaces in production and not in the test that used small fixtures.
  The same holds for `String` and every wrapper: reference equality is
  identity, `equals` is content, and the cache is an implementation
  detail the spec permits, not a promise to rely on.
])

== var, inference for locals

`var` since 10 infers a local's type from its initializer. It works
wherever the initializer pins a type: constructors, factory calls,
generic calls with real arguments, lambda parameters since 11. It
cannot name a field or a parameter or any member, it cannot stand
alone or hold a bare `null`, array brackets do not survive it, and a
lambda or method reference needs a target type to give `var` something
to read.

#snippet("class C {\n  var count = 1;            // error: fields carry declared types\n  void send(var text) { }   // error: parameters too, lambdas since 11 only\n  void init() {\n    var nothing = null;     // error: null has no type to infer\n    var pair[] = {1, 2};    // error: brackets belong on the type\n  }\n}", lang: "java")

One interaction surprises people: the conditional expression, which
normally waits for a target type, turns standalone under `var` and
merges its arms, so an `int` arm beside a `double` arm widens to
`double` on the spot.

#listing("java/samples/src/Ch04/References.java", first: 84, last: 91, caption: [inference from the constructor, and the ternary that widened to double])

== records, the data shape

A record, final since 16, is a transparent carrier for a fixed set of
components: the header names them, and the compiler generates the
accessor per component, `equals`, `hashCode`, `toString`, and the
canonical constructor. Validation rides the compact constructor, the
form without parentheses that runs before the fields settle. Chapter 5
takes records deep, the reflection contract included, this chapter
only needs the shape as the default way to write a value type:

#listing("java/samples/src/Ch04/References.java", first: 22, last: 29, caption: [a record with a validating compact constructor])

#listing("java/samples/src/Ch04/References.java", first: 93, last: 104, caption: [the generated members measured, and validation throwing])

== sealed, the closed hierarchy

A sealed type, since 17 after previews in 15 and 16, lists exactly
which types may implement or extend it, and every permitted subtype
must itself be `final`, `sealed`, or marked `non-sealed` to reopen the
branch. The closure is what makes exhaustiveness checkable, the reason
chapter 9's pattern switch can prove it covered every case with no
default clause, and the runtime knows the shape through `isSealed` and
`getPermittedSubclasses`.

#listing("java/samples/src/Ch04/References.java", first: 31, last: 39, caption: [a sealed interface permitting two records])

#listing("java/samples/src/Ch04/References.java", first: 106, last: 111, caption: [the sealing visible to Class, and pattern dispatch over the closed set])

== null and Optional

The null literal belongs to every reference type, the null type sits
below them all as their bottom, and `instanceof` answers false for it
without throwing. The pointer is unchecked at the type level, so 8
shipped `Optional` as the explicit maybe for returns: a container that
forces the caller to acknowledge the empty case, not a general null
replacement but a return contract. Chapter 8 owns the full discipline
and its stream interactions.

#listing("java/samples/src/Ch04/References.java", first: 113, last: 118, caption: [null's instanceof, and the empty Optional carrier])

== the conversion lattice

Between the numeric primitives sits one small graph. Widening
conversions, the arrows, are implicit and always safe on range.
Everything else is a narrowing cast, explicit by rule, and the cast is
where bits die: a truncating double to int, a masking byte cast that
turns 130 into -126, and the quiet one, int or long to float, which is
widening by range yet lossy on precision because 24 effective mantissa
bits cannot hold a 32-bit integer's low digits. `boolean` stands
outside the lattice entirely.

#diagram([the conversion lattice: arrows widen implicitly, everything else casts], length: 13pt, {
  let types = (("byte", 1.0), ("short", 3.4), ("int", 5.8), ("long", 8.2), ("float", 10.6), ("double", 13.0))
  for (name, x) in types {
    cdraw.rect((x - 0.95, 3.0), (x + 0.95, 4.2), fill: luma(235), radius: 0.02)
    cdraw.content((x, 3.6), [#name], size: 6.5pt)
  }
  for i in range(types.len() - 1) {
    let from = types.at(i).at(1) + 0.95
    let to = types.at(i + 1).at(1) - 0.95
    cdraw.line((from + 0.1, 3.6), (to - 0.1, 3.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.rect((4.85, 5.6), (6.75, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.2), [char], size: 6.5pt)
  cdraw.line((5.8, 5.55), (5.8, 4.25), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.2, 6.2), [boolean sits outside], size: 6pt)
  cdraw.content((7.0, 1.9), [int and long reach float and double by range yet lose low digits], size: 6pt)
})

The sample walks the widening chain for free, then measures each loss:
the byte cast that wraps, the double truncation toward zero, and the
123456789 that comes back from a float as 123456792.

#listing("java/samples/src/Ch04/Primitives.java", first: 87, last: 97, caption: [widening free and narrowing lossy, each loss measured])

#callout("verify", "the lossy widening, read as range not precision", [
  The lattice calls int to float a widening conversion because every
  int value stays inside float's range, and the same page's rules let
  low digits fall off, 123456789 to 123456792 measured here. Any
  integer above 2^24 crossing into a float, or above 2^53 into a
  double, needs either the exact integer types or an honest rounding
  decision, which is chapter 13 territory.
])

sources: Java in a Nutshell 8th edition chapter 2 (primitive data
types, primitive type conversions, string literals) and chapter 5
(java values, pass by value) for the type inventory, the conversion
table, the string and boxing stories, grounded and rewritten.
docs.oracle.com/javase/specs/jls/se27/html/jls-3.html accessed
2026-10-04 for the literal grammar behind the arithmetic.
openjdk.org/projects/jdk/14 and /jdk/15 accessed 2026-10-04 anchor
records preview 14 final 16 and sealed preview 15 final 17 alongside
the ladder spine, jeps/286 for var in 10 and the ladder chapter's own
row for lambda parameters in 11, and the oracle javadoc for Math and
Integer read on the pinned build for the exact family since 8 and the
measured deprecation. Everything
behavioral verified live on tools/jdk27/build/jdk-27 by the Ch04
samples under pwsh tools/run-java-samples.ps1 -Chapter Ch04: 42
checks, Primitives 24 and References 18, covering widths and ranges,
the overflow wrap and Math.addExact's exact message, truncating
division and the throwing zero, the bit patterns of 1.0 in both
floats, 0.1 plus 0.2, the special values and both zeros, NaN, the
MIN_VALUE trap, char signed and unsigned readings, the surrogate pair
and code point count, intern and pool identity, the Integer cache
boundary measured at 127, the deprecation read reflectively as since 9
forRemoval false, the unboxing null throw, var inference and the
standalone ternary widening, the record's generated members and
compact constructor validation, isSealed with two permitted
subclasses, null's instanceof, Optional.empty, and every conversion
loss in the lattice, all dated 2026-10-04.
