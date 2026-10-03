#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the type system

Every size in this chapter is a fact about this machine until the standard
says otherwise, and the gate checks each one. The walk follows the order
the compiler does: objects and their representations, then `_BitInt(N)`,
exact widths and the promotions it refuses, then
`constexpr` objects, then the spellings c23 added for naming types and
values, `typeof`, `typeof_unqual`, `auto`, and `nullptr`. The support
timeline is already history, from llvm's C status page: `_BitInt` and the
`() means (void)` rule landed in clang 15, `typeof` in 16, `nullptr` in
17, `auto` in 18, `constexpr` objects in 19. Everything here runs on
clang 23.1.1 under `-std=c23`.

== objects and representation

An object is a region of storage. Its declared type says how the bytes
are meant to be read, the value is what that reading produces, and the
object representation is the raw byte sequence, the layer `unsigned
char` is allowed to inspect. The standard fixes almost nothing about
sizes: `char` holds at least 8 bits, the chain of `sizeof` values from
`char` through `short`, `int`, and `long` to `long long` never
decreases, and the target decides the rest. The first sample pins what
this target decided:

#listing("c-os-cloud/samples/src/Ch03/typesizes.c", first: 20, last: 34, caption: [the width contract, and which basic type each exact-width typedef names here])

Line 21 is `CHAR_BIT` from `limits.h`, 8 on this machine. Lines 22-24
assert the exact-width contract from `stdint.h`: `int8_t` through
`int64_t` at 1, 2, 4, 8 bytes, with the `least` and `fast` variants at
least as wide as promised. The `_Generic` selections at 27-32 identify
which basic types the typedefs name here: `int8_t` is `signed char`,
`int32_t` is `int`, `int64_t` is `long long`. Line 33 carries the
subtlety textbooks skip: `char` is a third character type, distinct from
`signed char` and `unsigned char` even where its range matches one of
them. The selection proves it twice, because two compatible type names
in one `_Generic` would be a constraint violation before any check
could run.

#listing("c-os-cloud/samples/src/Ch03/typesizes.c", first: 35, last: 46, caption: [the data model, two's complement, and the bytes behind one uint32_t value])

Line 35 is the data model: llp64, so `long` stayed 4 bytes when pointers
grew to 8, which is why `int64_t` typedefs `long long` and never `long`
on windows. C23 made two's complement the only allowed signed
representation, and line 37 shows it through the exact width: `~0` read
as `int8_t` is -1. Lines 38-42 read the object representation of the
value 0x11223344: `memcpy` into an `unsigned char` array is the
sanctioned way to look, and the bytes come back 44 33 22 11, the lowest
address holds the lowest value bits, little endian on this target.
Lines 43-44 close on `_Bool`: one byte of storage, and conversion onto
it maps every nonzero value to 1.

#diagram([sizes this target chose, and the two views of one uint32_t object], length: 13pt, {
  let rows = (("char", 1), ("short", 2), ("int", 4), ("long", 4), ("long long", 8), ("void *", 8))
  for (i, row) in rows.enumerate() {
    let y = 7.0 - i * 1.05
    cdraw.content((1.25, y + 0.42), row.at(0), wrap: text.with(size: 5.5pt))
    cdraw.rect((2.9, y), (2.9 + row.at(1) * 0.72, y + 0.85), fill: luma(235), radius: 0.02)
    cdraw.content((2.9 + row.at(1) * 0.72 + 0.35, y + 0.42), [#(row.at(1))], wrap: text.with(size: 6pt))
  }
  cdraw.content((5.7, 8.45), [sizes in bytes, this llp64 target], wrap: text.with(size: 6.5pt))
  cdraw.content((5.7, 0.9), [long stayed 4 bytes #linebreak() when pointers grew to 8], wrap: text.with(size: 6.5pt))

  cdraw.content((17.8, 8.55), [one object, two views], wrap: text.with(size: 6.5pt))
  cdraw.rect((11.8, 6.9), (23.8, 7.95), fill: luma(205), radius: 0.02)
  cdraw.content((17.8, 7.42), [declared type uint32_t, #linebreak() value 0x11223344], wrap: text.with(size: 6pt))
  cdraw.line((17.8, 6.65), (17.8, 6.3), stroke: luma(100), mark: (end: ">"))
  let vals = ("44", "33", "22", "11")
  for (i, t) in vals.enumerate() {
    let x = 12.2 + i * 2.85
    cdraw.rect((x, 5.45), (x + 2.7, 6.3), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.35, 5.87), t, wrap: text.with(size: 7pt))
    cdraw.content((x + 1.35, 5.15), [byte #i], wrap: text.with(size: 6pt))
  }
  cdraw.line((12.2, 4.7), (23.4, 4.7), stroke: luma(100))
  cdraw.line((12.2, 4.7), (12.2, 4.45), stroke: luma(100))
  cdraw.line((23.4, 4.7), (23.4, 4.45), stroke: luma(100))
  cdraw.content((17.8, 4.0), [low address left, high address right], wrap: text.with(size: 6.5pt))
  cdraw.content((17.8, 3.1), [unsigned char reads this layer: 44 33 22 11], wrap: text.with(size: 6.5pt))
  cdraw.content((17.8, 1.9), [the standard fixes only minimums #linebreak() and the sizeof chain that never decreases], wrap: text.with(size: 6.5pt))
})

#callout("note", "the portable part is the typedef, not the number", [
  Every size in the two listings is a target fact, not a standard fact:
  the same file compiled on a 64 bit linux fails the line 35 check,
  because lp64 makes `long` 8 bytes there. Where a width is a
  requirement, the exact-width typedefs state it and the `_Generic`
  checks document which basic type backs each one here. `char` is the
  trap in the other direction: its signedness is implementation
  defined, so this chapter spells `signed char` or `unsigned char`
  whenever the sign matters.
])

== bitint

`_BitInt(N)` requests exactly N bits, sign bit included, and gives the
language integer types at widths no standard type offers. The width is
an exact arithmetic fact, not a minimum: `_BitInt(24)` holds -8388608
through 8388607, signed needs at least 2 bits, unsigned goes down to a
single bit, and this clang accepts widths up to 2^23, the
`__BITINT_MAXWIDTH__` predefine asserted at line 45. The overflow
rules are the standard's own, not new ones: the proposal that added
the types, N2763, states in its safety section that "(`_BitInt(3)`)7 +
(`_BitInt(3)`)2 overflows, and the result is undefined as with other
signed integer types", while "overflow of an unsigned `_BitInt` is
well-defined and the value wraps around with twos complement
semantics". Every wrap asserted below is either unsigned arithmetic,
defined modulo 2^N by the standard, or a conversion onto the type,
which is implementation defined and probed to reduce modulo on this
clang. The C23 spelling `BITINT_MAXWIDTH` is a `limits.h` macro this
target's msvc headers do not define, so the compiler predefine carries
the fact.

#listing("c-os-cloud/samples/src/Ch03/bitint.c", first: 20, last: 33, caption: [exact ranges, and the wraps the standard defines])

Lines 20-22 pin the range, both ends, using in-range values only.
Lines 23-25 are the conversion story: `w` ranks below `int`, so `w + 1`
runs in `int` and produces 8388608, defined, and the assignment
converts that back onto `_BitInt(24)`, where the standard leaves the
out-of-range result to the implementation and this clang reduces
modulo 2^24 to the minimum. Lines 26-28 are the standard's own wrap:
both operands `unsigned _BitInt(24)`, the common type keeps the width,
and 2^24 - 1 plus 1 is 0 by definition. `tiny` at 29-30 shows the
narrowest signed range on in-range values, -2..1, and `bit` at 31-33
is the narrowest object in the language, one unsigned bit, wrapping to
0 by definition.

#listing("c-os-cloud/samples/src/Ch03/bitint.c", first: 34, last: 49, caption: [the promotion `_BitInt` refuses, the int8_t that gets one, and the 64 bit parity])

The pair at 34-39 is the promotion story, both lanes defined. The
`unsigned _BitInt(8)` add refuses the integer promotions: both
operands keep 8 bits, the operation happens there, and 200 + 100 wraps
to 44, modulo 2^8. The `int8_t` line promotes both operands to `int`,
so the same kind of arithmetic survives as 200 with no wrap at all.
That refusal is the feature, a `_BitInt(8)` never silently widens into
a type with a different range, and N2763 records why: promoting to
"avoid" overflow can quietly pick a type that still cannot hold the
result. Lines 40-42 set the parity straight: `_BitInt(64)` has
`int64_t`'s exact range, size, and overflow rules, signed overflow is
undefined in both. Defined modulo arithmetic at widths past 64 belongs
to `unsigned _BitInt(N)`, probed working at 65 and 1024 bits on this
machine. Storage still pays for whole bytes, lines 43-44: 24 bits
occupy 4 bytes, 64 occupy 8. The check at 47-48 records the rank rule
from the other side: beside a plain `int`, a lower ranked bit-precise
operand converts, so `w + 0` has type `int`. The gate's ir leg pins
the widths below the source: the `-O0` ir of this file contains
`add i24` and `add i8`, the arithmetic really runs at the requested
widths. The lanes lean on two rules used as premises so far. The
integer promotions say an operand narrower than `int` converts to `int`
before the operation runs, the lane `int8_t` takes. Integer conversion
rank orders the types for conversions: when two operand types must
meet, the lower ranked converts toward the higher, the rule `w + 0`
records.

#diagram([the promotion lanes, int8_t widens to int, unsigned `_BitInt(8)` wraps in place], length: 13pt, {
  cdraw.content((4.3, 8.45), [int8_t operands promote to int], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 7.0), (2.2, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((1.4, 7.45), [100], wrap: text.with(size: 7pt))
  cdraw.content((2.85, 7.45), [+], wrap: text.with(size: 7pt))
  cdraw.rect((3.1, 7.0), (4.7, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 7.45), [100], wrap: text.with(size: 7pt))
  cdraw.line((4.9, 7.45), (5.8, 7.45), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.9, 7.0), (7.5, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((6.7, 7.45), [200], wrap: text.with(size: 7pt))
  cdraw.rect((8.1, 6.6), (14.5, 8.3), stroke: luma(160), radius: 0.02)
  cdraw.content((11.3, 7.45), [type int: both operands #linebreak() widened to 32 bits], wrap: text.with(size: 6pt))

  cdraw.content((4.6, 5.9), [unsigned `_BitInt(8)` keeps its width], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 4.3), (2.2, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((1.4, 4.75), [200], wrap: text.with(size: 7pt))
  cdraw.content((2.85, 4.75), [+], wrap: text.with(size: 7pt))
  cdraw.rect((3.1, 4.3), (4.7, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 4.75), [100], wrap: text.with(size: 7pt))
  cdraw.line((4.9, 4.75), (5.8, 4.75), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.9, 4.3), (7.5, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((6.7, 4.75), [44], wrap: text.with(size: 7pt))
  cdraw.rect((8.1, 4.0), (14.5, 5.5), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((11.3, 4.75), [300 wraps modulo 2^8: #linebreak() the add itself is 8 bit], wrap: text.with(size: 6pt))

  cdraw.content((19.6, 8.45), [exact widths, exact ranges], wrap: text.with(size: 6.5pt))
  cdraw.content((16.9, 6.7), [`_BitInt(2)`, signed], wrap: text.with(size: 6pt))
  let s2 = ("-2", "-1", "0", "1")
  for (i, t) in s2.enumerate() {
    let x = 15.2 + i * 1.15
    cdraw.rect((x, 5.5), (x + 1.05, 6.35), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.52, 5.92), t, wrap: text.with(size: 6.5pt))
  }
  cdraw.content((16.9, 4.9), [unsigned `_BitInt(1)`], wrap: text.with(size: 6pt))
  let u1 = ("0", "1")
  for (i, t) in u1.enumerate() {
    let x = 15.2 + i * 1.15
    cdraw.rect((x, 3.7), (x + 1.05, 4.55), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.52, 4.12), t, wrap: text.with(size: 6.5pt))
  }
  cdraw.content((11.8, 2.5), [storage rounds to whole bytes: #linebreak() 24 bits sit in 4 bytes, 64 in 8], wrap: text.with(size: 6.5pt))
  cdraw.content((11.8, 1.1), [beside a plain int, a lower ranked bitint #linebreak() converts: w + 0 has type int], wrap: text.with(size: 6.5pt))
})

#callout("verify", "two red drafts behind this section", [
  The first probe declared signed `_BitInt(1)`. Clang refused it,
  "signed `_BitInt` must have a bit size of at least 2", and the
  compile went red before any check could run. The first draft of this
  section then asserted signed `_BitInt` wraparound as defined
  behavior, because clang 23 runs it deterministically. The proposal
  text says otherwise, "the result is undefined as with other signed
  integer types", and a generous compiler is not a contract. The
  sample now wraps only where the standard defines it, unsigned
  arithmetic, and labels the conversion wrap as this target's choice.
  A red draft is the harness doing its job, the discipline chapter 1
  established.
])

== constexpr

C23 `constexpr` is a storage-class specifier for scalar objects, not
the c++ keyword. The standard's deal, as cppreference summarizes it: a
`constexpr` object "must be fully and explicitly initialized according
to the static initialization rules", it "exists at runtime to have its
address taken", and it "cannot be modified at runtime in any way", so
the compiler may use its fixed value in any other constant expression.
The restrictions follow from scalar: no pointers except null pointers,
no variably modified, atomic, or volatile types, no `restrict`
pointers. There are no `constexpr` functions in c23. That is the c++
difference and the entire difference: c23 names objects, c++
additionally annotates function definitions so calls fold.

#listing("c-os-cloud/samples/src/Ch03/constexpr.c", first: 18, last: 23, caption: [an ordinary function holding a local constexpr, beside the enum trick])

`fold_demo` at 18-21 is a plain static function whose body holds a
local `constexpr`. There is no `constexpr` on its declarator, because
the grammar has no such position for functions. The enum at 23 is the
old trick beside the new keyword: enum constants work in constant
expressions, but they are always `int`.

#listing("c-os-cloud/samples/src/Ch03/constexpr.c", first: 25, last: 39, caption: [constexpr objects feeding every kind of constant expression])

The walk through `main`: `k` enters a `_Static_assert` at line 27,
`cap` sizes `buf` at 28-29, `k + 5` is a case label at 32 with the
switch value `2 * k` built from the same constant, `&k` is taken at
38, and `ratio` at 39 names a double, which the enum trick could
never do. The checks close the loop: the address reads 5 at line 43,
so `constexpr` is an object and not a macro; the enum and `cap` agree
on the one thing the enum could do at line 45; and `fold_demo` returns
91 at line 46, which the gate's ir leg also asserts appears in the
`-O0` ir of this file as `ret i32 91` inside `fold_demo`: `k * 13`
folds before any optimization level is chosen. That is constant
folding of a `constexpr` object, not the c++ function machinery.

#diagram([named constants before c23 and after], length: 13pt, {
  cdraw.rect((0.6, 1.6), (10.4, 8.7), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((5.5, 8.15), [before c23], wrap: text.with(size: 7pt))
  let lrow(y, t) = {
    cdraw.rect((1.0, y), (10.0, y + 1.4), fill: luma(248), radius: 0.02)
    cdraw.content((5.5, y + 0.7), t, wrap: text.with(size: 6pt))
  }
  lrow(6.5, [enum \{ CAP = 16 \} #linebreak() int constants, nothing else])
  lrow(4.9, [\#define CAP 16 #linebreak() untyped text, no scope])
  lrow(3.3, [static const int cap #linebreak() typed, but not a constant])
  cdraw.content((5.5, 2.25), [no double or size_t constants #linebreak() in any of the three], wrap: text.with(size: 6.5pt))

  cdraw.rect((11.2, 1.6), (23.6, 8.7), stroke: luma(100), radius: 0.02)
  cdraw.content((17.4, 8.15), [c23 constexpr], wrap: text.with(size: 7pt))
  let rrow(y, t) = {
    cdraw.rect((11.6, y), (23.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((17.4, y + 0.7), t, wrap: text.with(size: 6pt))
  }
  rrow(6.5, [constexpr size_t cap = 16 #linebreak() constexpr double ratio = 0.5])
  rrow(4.9, [`_Static_assert`, case labels, #linebreak() array bounds, all accept cap])
  rrow(3.3, [still an object: #linebreak() the address is real, reads 16])
  cdraw.content((17.4, 2.25), [objects only: c23 has no #linebreak() constexpr functions, c++ does], wrap: text.with(size: 6.5pt))
})

== typeof, nullptr, unqualified types

Four spellings close the chapter. `typeof` and `typeof_unqual` (c23
6.7.2.5) name a type from an expression or a type name: `typeof`
preserves every qualifier, `typeof_unqual` strips them, and the
operand is not evaluated unless it names a variably modified type.
`auto` infers an object's type from its initializer and is no longer a
storage class. `nullptr` is a keyword denoting the null pointer
constant, a non-lvalue of type `nullptr_t` that converts to any
pointer. An lvalue is an expression that designates an object, usually
one whose address can be taken, the `register` qualifier being the
exception, so `nullptr` names a value, never an object. And the grammar
cleanup: `()` in a declarator now means `(void)`, and the K&R
identifier-list definition, the pre-ansi parameter style that names
parameters in a list after the parentheses, is gone from the
language.

#listing("c-os-cloud/samples/src/Ch03/typeof.c", first: 17, last: 43, caption: [typeof, typeof_unqual, nullptr, auto, and the () grammar in one file])

Line 17 is the grammar fact: `noargs` declared with empty parens
compiles and returns 7, and those parens are `(void)` in c23, not an
unspecified parameter list. A call with an argument is now a hard
error, probed directly: the compiler reports "too many arguments to
function call, expected 0, have 1". Lines 21-24 copy types: `y` gets
`x`'s declared type, `z` gets the type of the expression `1 + 1L`,
which is `long`. Lines 25-30 are the qualifier pair: `ci` is
`const int`, `typeof_unqual(ci)` is `int` so `m += 1` compiles,
while `typeof(ci) *pc` keeps the const in the pointee, a pointer to
const int. Lines 31-34 put `nullptr` through its paces: it
initializes a `void *`, compares equal to `NULL`, and its type is
pointer sized. Lines 35-40 deduce `int`, `double`, and `char *` from
initializers, the checks dispatching on `_Generic`. The chapter spells
the type as `typeof(nullptr)` on purpose:

#callout("note", "the header trail for nullptr_t on this box", [
  `stddef.h` on this machine resolves to the msvc header set, which
  defines no `nullptr_t` (probed 2026-09-12, the same shadow that
  hides `BITINT_MAXWIDTH` in `limits.h`, where clang offers
  `__BITINT_MAXWIDTH__` at 8388608 instead). Clang ships its own
  `__stddef_nullptr_t.h`, and its entire c23 content is one line,
  `typedef typeof(nullptr) nullptr_t`. The sample spells the type the
  way that header does. The atomics chapter walks the same trail for
  `stdatomic.h`.
])

#diagram([the four spellings, what each names and what the sample proves], length: 13pt, {
  let cols = ("typeof", "typeof_unqual", "auto", "nullptr")
  let cw = 5.15
  let cx(i) = 2.5 + i * 5.35
  for (i, h) in cols.enumerate() {
    cdraw.rect((cx(i), 7.6), (cx(i) + cw, 8.4), fill: luma(205), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, 8.0), h, wrap: text.with(size: 7pt))
  }
  let cell(i, y, t) = {
    cdraw.rect((cx(i), y), (cx(i) + cw, y + 1.75), fill: luma(235), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, y + 0.87), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((1.4, 6.47), [names], wrap: text.with(size: 6.5pt))
  cdraw.content((1.4, 4.37), [proves], wrap: text.with(size: 6.5pt))
  cdraw.content((1.4, 2.27), [edges], wrap: text.with(size: 6.5pt))
  cell(0, 5.6, [the operand's type, #linebreak() qualifiers kept])
  cell(1, 5.6, [the type, qualifiers #linebreak() and atomic stripped])
  cell(2, 5.6, [the initializer's type, #linebreak() not a storage class])
  cell(3, 5.6, [the null pointer constant, #linebreak() type typeof(nullptr)])
  cell(0, 3.5, [typeof(ci) \*pc is a #linebreak() pointer to const int])
  cell(1, 3.5, [m += 1 compiles off a #linebreak() const int source])
  cell(2, 3.5, [int, double, char \* each #linebreak() deduced and checked])
  cell(3, 3.5, [vp == nullptr, and #linebreak() nullptr == NULL])
  cell(0, 1.4, [operand not evaluated, #linebreak() bit fields refused])
  cell(1, 1.4, [the result is the #linebreak() plain unqualified type])
  cell(2, 1.4, [initializer required, #linebreak() old auto removed])
  cell(3, 1.4, [stddef.h nullptr_t shadowed #linebreak() by msvc headers here])
  cdraw.content((12.6, 0.55), [() now means (void), noargs() returns 7, #linebreak() the K&R identifier list is gone], wrap: text.with(size: 6.5pt))
})

sources: clang.llvm.org C language support status page (N2763 `_BitInt`
and N2841 `()` prototypes in clang 15, N2927 `typeof` in 16, N3042
`nullptr` in 17, N3007 `auto` in 18, N3018 `constexpr` objects in 19),
accessed 2026-09-12; open-std.org N2763, the `_BitInt` proposal,
safety section (signed overflow "undefined as with other signed
integer types", unsigned wrap well-defined), accessed 2026-09-12;
cppreference.com pages, constexpr specifier, typeof
operators, nullptr, and arithmetic types, citing ISO/IEC 9899:2024
6.7.2.5 and 6.4.4.6, accessed 2026-09-12; every size, wrap, fold, and
header shadow probed on this machine the same day. Sample behavior
verified by `make verify-c`, 39 checks in chapter 3 of the samples
suite.
