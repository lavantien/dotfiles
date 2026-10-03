#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= algebraic data types in c23

Chapters 1 to 25 built mathematics out of numbers. The last arc of the
book builds it out of values, and the load-bearing notion is the
algebraic data type: a product bundles a fixed set of fields, a sum
chooses exactly one alternative, and every structure of the next four
chapters, option, result, functors, pipelines, is one of those two
shapes or a composition of both. This chapter makes six moves: the
cardinality arithmetic that separates products from sums, the tagged
union as a c23 struct with an anonymous union and a fixed-type enum,
the exhaustive switch as the pattern-match idiom with a compile-time
miss detector, the product machinery of typeof, auto, and constexpr
with compound-literal values, defer as the ownership story for sums
whose payload lives on the heap, and the two-tag sum that chapter 27
grows into option. Every behavioral claim below is one of the 59
checks in the 4 samples of chapter 26 or a sentence quoted from a
canonical source fetched 2026-09-22. Book 1 owns these features as
language spellings, #xref-to("c-os-cloud", "types") for the type
namers and #xref-to("c-os-cloud", "pointers") for compound literals,
while this chapter owns the type arithmetic and the discipline those
spellings serve.

== products and sums

A product type is a cartesian product of fields: the struct holding
one $a$ and one $b$ has exactly the pairs of an element of $a$ with an
element of $b$, so its inhabitant count multiplies, $|a times b| =
|a| dot |b|$. A sum type is a tagged choice: one value that is either
an $a$ or a $b$, never both, so its count adds, $|a + b| = |a| + |b|$.
Every compound datum in this book is built from these two and they
obey ordinary set arithmetic, including distributivity, $a times (b +
c) = a times b + a times c$, which says a pair whose second component
is a choice is the same data as a choice between two pair shapes. The
set counting behind these identities is the machinery of
#xref-to("math", "proof"), restated here for types.

The two-number play: two octets as a product have $256 times 256 =
65536$ inhabitants, the same two octets as a sum have $256 + 256 =
512$. One byte of tag buys a factor of 128 in expressiveness at the
cost of one live reading. The miniature below draws the same contrast
with two-bit values so the cells stay countable, 16 against 8.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*form*], [*c23 spelling*], [*two bits each*], [*octets*]),
  [product $a times b$], [struct with both fields], [$4 times 4 = 16$], [$256 times 256 = 65536$],
  [sum $a + b$], [tagged union], [$4 + 4 = 8$], [$256 + 256 = 512$],
  [distribution $a times (b + c)$], [pair of a tagged second], [$4 (4 + 4) = 32 = 16 + 16$], [$a = 4, b = 6, c = 10$: $64 = 24 + 40$],
)

#diagram([inhabitants: a 4 by 4 pair grid against a 4 plus 4 tagged row, two bit cells], length: 13pt, {
  // left: the product of two two-bit values, 16 cells
  for i in range(4) {
    for j in range(4) {
      cdraw.rect((i * 0.8, j * 0.8), (i * 0.8 + 0.72, j * 0.8 + 0.72),
        fill: luma(235), stroke: luma(140))
    }
  }
  cdraw.content((1.44, 4.3), [pair of two bits], size: 6pt)
  cdraw.content((1.44, -0.75), [4 times 4 = 16 cells], size: 6.5pt)
  for i in range(4) {
    cdraw.content((i * 0.8 + 0.36, -0.3), [#i], size: 6pt)
  }
  // right: the sum of the same two values, a tag then one payload row
  for row in range(2) {
    let y = 2.4 - row * 1.3
    cdraw.rect((6.6, y), (7.6, y + 1.0), fill: luma(205), stroke: luma(60))
    cdraw.content((7.1, y + 0.5), [tag #row], size: 6pt)
    for k in range(4) {
      cdraw.rect((8.0 + k * 0.8, y), (8.0 + k * 0.8 + 0.72, y + 1.0),
        fill: luma(235), stroke: luma(140))
      cdraw.content((8.0 + k * 0.8 + 0.36, y + 0.5), [#k], size: 6pt)
    }
  }
  cdraw.content((9.2, 4.3), [either of two bits], size: 6pt)
  cdraw.content((9.2, -0.75), [4 + 4 = 8 cells], size: 6.5pt)
  cdraw.content((13.7, 1.9), [one tag byte,#linebreak() one live reading], size: 6pt)
})

The dry run: the counting loops in the sample walk both encodings of
two octets. The product loop nests 256 inside 256 and counts 65536
iterations. The sum loop walks 2 tags by 256 payloads and counts 512.
Distributivity uses $a = 4$, $b = 6$, $c = 10$: the left side counts
pairs of an $x in {0, 1, 2, 3}$ with a tagged $t in {0, ..., 15}$,
that is $4 dot 16 = 64$, and the right side counts $4 dot 6 = 24$
pairs into $b$ plus $4 dot 10 = 40$ pairs into $c$, also 64. One
witness round trips: the c-branch pair $(x = 2, y = 1)$ encodes as $t
= b + y = 7$, and $t = 7$ decodes back to the c branch with $y = 1$
while $x$ rides along untouched, which is the bijection distributivity
promises, executed rather than asserted.

#listing("math/samples/src/Ch26/product.c", first: 97, last: 141, caption: [the counting loops: product multiplies, sum adds, distributivity counts both encodings, one witness round trips])

== the tagged union

The c23 sum type is a struct with three parts: an enum tag with a
fixed underlying type, an anonymous union holding one struct per
alternative, and static_asserts pinning the layout so the tag
discipline rests on measured bytes. The anonymous union is the c23
convenience that matters here: because it has no member name, its
members are reached directly, `s.circle.r` rather than `s.u.circle.r`,
which keeps the constructor and every case body honest about which
alternative they touch.

The dry run: construct `circle(2)` and the object is 56 bytes. The tag
byte is 0 at offset 0, 7 bytes of padding follow because the union of
doubles aligns to 8, and the payload region starts at offset 8 with
`r = 2.0`. The area is the pi double times 2 times 2, and doubling a
double is exact in binary, so `12.566370614359172` is the pinned
answer. The static_asserts in the sample pin all of this at compile
time: the enum is 1 byte, the point struct 16, the whole shape 56, and
the tags enumerate 0, 1, 2.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*constructor*], [*tag byte*], [*payload at offset 8*], [*area*]),
  [`circle(1)`], [0], [`r = 1`], [3.141592653589793],
  [`rect(3, 5)`], [1], [`w, h = 3, 5`], [15],
  [`tri345()`], [2], [`(0,0) (4,0) (0,3)`], [6],
)

#listing("math/samples/src/Ch26/shape.c", first: 33, last: 78, caption: [the sum type: fixed-type enum, anonymous union, layout static_asserts, compound-literal constructors])

#diagram([struct shape, 56 bytes: one tag byte, 7 of padding, then the 48 byte union with the three payload footprints], length: 13pt, {
  let bx(b) = b * 0.27
  cdraw.rect((bx(0), 0), (bx(1), 1.0), fill: luma(205), stroke: luma(60))
  cdraw.rect((bx(1), 0), (bx(8), 1.0), fill: luma(245), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.rect((bx(8), 0), (bx(56), 1.0), fill: luma(235), stroke: luma(60))
  cdraw.content((bx(0.5), 1.35), [tag 1], size: 6pt)
  cdraw.content((bx(4.5), 1.35), [pad 7], size: 6pt)
  cdraw.content((bx(32), 1.35), [union payload 48], size: 6pt)
  cdraw.content((bx(28), 2.0), [56 bytes total, alignment 8, probed clang 23.1.1], size: 6.5pt)
  // the three alternatives overlay the same payload region
  cdraw.line((bx(8), 0), (bx(8), -3.85), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.rect((bx(8), -1.55), (bx(16), -0.75), fill: none, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((6.8, -1.15), [circle: 8 bytes live], size: 6pt)
  cdraw.rect((bx(8), -2.7), (bx(24), -1.9), fill: none, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((9.1, -2.3), [rect: 16 bytes live], size: 6pt)
  cdraw.rect((bx(8), -3.85), (bx(56), -3.05), fill: none, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((bx(32), -3.45), [poly: all 48 bytes live], size: 6pt)
})

The dispatch reads the tag first and touches only the payload the tag
names. The area switch returns `PI * r * r` for the circle, `w * h`
for the rect, and the shoelace formula for the triangle, whose pinned
fixture (0,0), (4,0), (0,3) gives area 6 and sides 4, 5, 3, perimeter
12, every one an exact double because the coordinates are integers.

#listing("math/samples/src/Ch26/shape.c", first: 80, last: 93, caption: [tag first, then the one honest payload reading, per case])

#callout("pitfall", "THE TAG IS THE ONLY WITNESS", [The union stores at most one member at a time, and cppreference states the rest plainly: "If the member used to access the contents of a union is not the same as the member last used to store a value, the object representation of the value that was stored is reinterpreted as an object representation of the new type (this is known as type punning)". The sample leans on this: after `circle(1)`, reading `s.rect.w` sees the same 8 bytes and returns 1.0, because both members start at union offset 0. Nothing in the bytes distinguishes a radius from a width. The tag byte is the only witness of which reading is honest, which is why every constructor sets it and every consumer switches on it before touching payload. Fetched 2026-09-22.])

== exhaustive switch

Pattern matching in c23 is a switch over the enum tag with every case
present and no default clause. The compiler carries the discipline:
`-Wswitch` lives inside `-Wall` and fires when a switch over an enum
misses an enumerator, so under the corpus gate, `-std=c23 -Werror
-Wall -Wextra`, a forgotten case stops the build. A default clause
would silence exactly that guard by catching every value, which is why
an exhaustive switch over a closed tag set never carries one. Because
the switch is total, there is nothing after it, and clang's return
analysis agrees.

The dry run: delete the `POLY` case from `shape_name` and rebuild. The
build fails before any code runs. The other direction is the runtime
half of the contract: a dispatch table, indexed by designated
initializer and sized by the same constexpr object that counts the
tags, gets one handler per tag, and a loop over all tag values checks
every slot is filled. The table turns tag discipline into data, one
function pointer per alternative, while a static_assert ties the table
length to `TAG_COUNT` so a new tag widens the table or fails.

#listing("math/samples/src/Ch26/exhaustive.c", first: 51, last: 73, caption: [the idiom: every case, no default, nothing after the total switch, fall-through shares one body])

#diagram([exhaustive dispatch: three cases return, a fourth tag with no case stops the build], length: 13pt, {
  cdraw.rect((0.5, 3.6), (3.5, 5.4), fill: luma(235), stroke: luma(60), radius: 0.02)
  cdraw.content((2.0, 4.5), [switch#linebreak() s.tag], size: 6.5pt)
  let handler(y, t) = {
    cdraw.rect((8.0, y), (12.6, y + 0.8), fill: luma(235), stroke: luma(100))
    cdraw.content((10.3, y + 0.4), t, size: 6pt)
    cdraw.line((3.5, 4.5), (8.0, y + 0.4), stroke: luma(100), mark: (end: ">"))
  }
  handler(6.2, [case CIRCLE -> "circle"])
  handler(4.3, [case RECT -> "rect"])
  handler(2.4, [case POLY -> "polygon"])
  // the negative case: a tag with no case, routed below the live handlers
  cdraw.line((2.0, 3.6), (2.0, 0.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((2.0, 0.5), (8.0, 0.5), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((8.0, 0.1), (12.6, 0.9), fill: none, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((10.3, 0.5), [case POLY2: none], size: 6pt)
  cdraw.line((8.5, 0.2), (12.1, 0.8), stroke: luma(60))
  cdraw.line((8.5, 0.8), (12.1, 0.2), stroke: luma(60))
  cdraw.content((6.3, -1.0), [-Wswitch: enumeration value not handled,#linebreak() an error under -Werror], size: 6pt)
})

#callout("verify", "THE NEGATIVE COMPILE", [The claim "a missing case fails the build" was probed, not assumed, on 2026-09-22 with clang 23.1.1 under the gate flags. The diagnostic, verbatim: `error: enumeration value 'POLY' not handled in switch [-Werror,-Wswitch]`. The probe lives in the chapter playground beside the samples, and the same flags build every sample in this book, so the guarantee is the gate itself.])

The dispatch table is the same discipline as data. Slot `[CIRCLE]`
holds `circle_area`, and calling through the table for the r = 2
fixture returns the 4 pi double, the rect handler returns 15, the
polygon handler runs Heron's formula on sides 3, 4, 5 where every
intermediate is an integer-valued double, semiperimeter 6, product
36, and `sqrt(36)` is exactly 6.

#listing("math/samples/src/Ch26/exhaustive.c", first: 150, last: 170, caption: [the table: designated initializer per tag, static_assert on length, a filled-slot loop, three dispatched areas])

== product machinery: typeof, auto, constexpr

The product side runs on c23 type-level spellings that book 1
introduces as language facts, and this section composes them into one
working idiom. A macro stamps the pair type, `DEFINE_PAIR(long long,
ll)` expands to a struct typedef, so the product of any two same-typed
fields is one line. `typeof` names a type from an expression and
preserves its qualifiers, `typeof_unqual` strips them, `auto` infers
an obvious type from its initializer, and `constexpr` declares a
scalar object usable in constant expressions, which is how the fixture
table gets its length. The one boundary to keep straight: c23 has
constexpr objects but no constexpr functions, and the macro plus
compound literal pair above is the idiom that replaces them.

The dry run: `typeof(d.second)` where `d` is a `pair_dbl` is `double`,
so squaring 2.5 through that type yields 6.25 exactly. A `const
pair_ll` makes `cp.first` a `const long long`, `typeof_unqual(cp.first)`
is a mutable `long long`, the copy increments to 13 while the source
stays 12. A compound literal is an unnamed object written as a value:
`(pair_ll){.first = 20, .second = 22}` passes by value into
`pair_sum_ll` and returns 42, and because the literal is an lvalue its
address survives as `pp`. Designated initializers zero what they do
not name, so `{.second = 5}` reads back `first == 0`.

#listing("math/samples/src/Ch26/product.c", first: 31, last: 53, caption: [the stamp macro, the layout static_asserts, the constexpr-sized fixture table])

#listing("math/samples/src/Ch26/product.c", first: 62, last: 88, caption: [compound literal by value and by address, designated zeroing, typeof, typeof_unqual, auto])

#diagram([one macro stamps every pair type, constexpr sizes the fixture, typeof picks the field type], length: 13pt, {
  cdraw.rect((0.5, 5.0), (4.9, 6.2), fill: luma(205), stroke: luma(60))
  cdraw.content((2.7, 5.6), [DEFINE_PAIR(T)], size: 6.5pt)
  cdraw.content((2.7, 5.15), [one template], size: 6pt)
  cdraw.rect((0.5, 2.7), (4.9, 3.7), fill: luma(235), stroke: luma(100))
  cdraw.content((2.7, 3.2), [pair_ll, 16 bytes], size: 6pt)
  cdraw.rect((0.5, 0.7), (4.9, 1.7), fill: luma(235), stroke: luma(100))
  cdraw.content((2.7, 1.2), [pair_dbl, 16 bytes], size: 6pt)
  cdraw.line((2.7, 5.0), (2.7, 3.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((1.7, 2.7), (1.7, 1.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  // right: constexpr sizes the fixture grid
  cdraw.rect((8.0, 5.4), (12.6, 6.4), fill: luma(245), stroke: luma(100))
  cdraw.content((10.3, 5.9), [constexpr ROWS = 3], size: 6pt)
  for r in range(3) {
    for c in range(2) {
      cdraw.rect((8.6 + c * 1.6, 2.4 - r * 0.8), (8.6 + c * 1.6 + 1.5, 3.1 - r * 0.8),
        fill: luma(235), stroke: luma(140))
    }
  }
  cdraw.line((9.6, 5.4), (9.6, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.5, 4.5), [FIXTURE[ROWS],#linebreak() 3 rows of pairs], size: 6pt)
  // typeof names the field type, noted under the stamped types
  cdraw.line((2.7, 0.7), (2.7, 0.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((2.7, -0.5), [typeof(d.second) is double], size: 6pt)
})

#callout("note", "CONSTEXPR OBJECTS ONLY", [C23 constexpr is a storage-class specifier for scalar objects with an explicit constant initializer, usable in array bounds and static_asserts the way `ROWS` sizes the fixture. There are no constexpr functions in c23, that is the c++ machinery. When a compile-time table of values is wanted, the idiom is the one above: a constexpr dimension plus a static const array of compound structures, initialized once at file scope.])

== defer and ownership

A sum whose payload lives on the heap owns that memory, and every path
out of the owning scope must release it exactly once. C23 itself has
no answer yet. Technical specification 25755 adds `defer`, and clang
23.1.1 ships it behind `stddefer.h` and the `-fdefer-ts` gate flag,
which defines `__STDC_DEFER_TS25755__` and reports version 202602L.
The semantics fit the sentence book 1 pins: a deferred statement runs
when its scope exits, last registered first out. That single rule
covers early returns, normal returns, and loop bodies, and it is the
whole ownership story for this arc.

The dry run: `build_area(1)` allocates the triangle points, registers
one deferred free, hits the bail branch, marks `b`, and returns -1.0.
The scope exit runs the defer, marking `f` and counting 1 free, so the
trace reads `bf` and the counter reads 1. The normal path marks `a`
before the same exit, trace `af`, value 6.0. `two_regions` registers
two defers and returns 12, and the unwind runs them in reverse, trace
`21`, two allocations, two frees. The move block is the transfer case:
`owned_move` copies the pointer and nulls the source with `nullptr`,
so the single deferred free on the destination is the only free, and
the source provably owns nothing.

#listing("math/samples/src/Ch26/defer.c", first: 79, last: 110, caption: [one defer per owned allocation: the early return still frees, two defers unwind last first])

#listing("math/samples/src/Ch26/defer.c", first: 211, last: 226, caption: [the move block: the source reads nullptr, one deferred free at block exit])

#diagram([scope timeline: defers register left to right and fire last first, on the early path too], length: 13pt, {
  cdraw.rect((0.5, 4.2), (14.5, 5.4), fill: luma(235), stroke: luma(60), radius: 0.02)
  cdraw.content((2.0, 4.8), [alloc t1], size: 6pt)
  cdraw.content((4.4, 4.8), [defer 1], size: 6pt)
  cdraw.content((7.0, 4.8), [alloc t2], size: 6pt)
  cdraw.content((9.4, 4.8), [defer 2], size: 6pt)
  cdraw.content((12.6, 4.8), [return 12], size: 6pt)
  cdraw.line((9.4, 4.2), (9.4, 3.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.5, 3.45), [early return path], size: 6pt)
  // unwind strip: last registered fires first
  cdraw.line((14.5, 4.2), (14.5, 1.5), stroke: luma(100))
  cdraw.line((14.5, 1.5), (12.0, 1.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 1.05), (8.0, 1.95), fill: luma(245), stroke: luma(100))
  cdraw.content((6.5, 1.5), [1st: free t2], size: 6pt)
  cdraw.rect((8.3, 1.05), (11.3, 1.95), fill: luma(245), stroke: luma(100))
  cdraw.content((9.8, 1.5), [2nd: free t1], size: 6pt)
  cdraw.content((2.7, 1.5), [unwind,#linebreak() LIFO], size: 6pt)
  cdraw.rect((4.6, -0.35), (11.7, 0.55), fill: luma(205), stroke: luma(60))
  cdraw.content((8.15, 0.1), [frees == 2, one per allocation], size: 6pt)
})

#callout("note", "DEFER IS A TECHNICAL SPECIFICATION", [`defer` is not in C23 proper. It arrives from TS 25755, and the corpus gate carries `-fdefer-ts` precisely because clang only defines `__STDC_DEFER_TS25755__` and enables the keyword under that flag, the toolchain fact #xref-to("c-os-cloud", "toolchain") records and #xref-to("c-os-cloud", "stdlib") demonstrates with the same LIFO traces. Every sample in chapters 26 to 29 relies on this lane being pinned, and the version macro check at the top of the sample guards it at runtime.])

== from sums to option

The smallest useful sum has two tags and one payload, and it is famous
under another name. A value of `opt_i64` is either `NONE`, an
alternative whose payload is empty, or `SOME` carrying a `long long`.
The layout is the tagged union again, 16 bytes on this machine, 1 tag
byte, 7 of padding, 8 of payload. The constructors are compound
literals, and the consumers are exhaustive switches: `get_or` returns
the payload or a caller-supplied default without ever reading `.v` on
the `NONE` side, and the doubling function maps `SOME 3` to `SOME 6`
while carrying `NONE` through untouched, the mapping law chapter 28
states precisely.

The dry run: `find_first_greater` walks `{3, 41, 7, 19, 23}` looking
past 30. The 3 fails the test, the 41 passes, and the function returns
`SOME 41` without carrying the index or a sentinel. The same walk
looking past 99 exhausts the array and returns `NONE`, and the two
results are distinguished by the tag alone. This is the shape
sentinel error handling cannot copy: a function that returns -1 for
miss has to hope -1 is never a payload, and the sum removes the hope
by construction.

#listing("math/samples/src/Ch26/exhaustive.c", first: 93, last: 140, caption: [opt_i64: constructors, get_or, a mapping switch, and a real search returning some or none])

#diagram([the sentinel question against the two tag sum, and the road to chapter 27], length: 13pt, {
  cdraw.rect((0.5, 2.6), (5.6, 5.0), fill: none, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((3.05, 4.5), [sentinel convention], size: 6.5pt)
  cdraw.content((3.05, 3.8), [returns -1 on miss], size: 6pt)
  cdraw.content((3.05, 3.15), [is -1 a miss#linebreak() or a payload?], size: 6pt)
  cdraw.line((5.6, 3.8), (7.6, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.7, 4.6), [the sum#linebreak() separates], size: 6pt)
  cdraw.rect((7.7, 4.1), (10.3, 5.1), fill: luma(205), stroke: luma(60))
  cdraw.content((9.0, 4.6), [NONE], size: 6.5pt)
  cdraw.content((9.0, 4.3), [empty], size: 6pt)
  cdraw.rect((7.7, 2.3), (10.3, 3.3), fill: luma(235), stroke: luma(60))
  cdraw.content((9.0, 2.8), [SOME v], size: 6.5pt)
  cdraw.content((9.0, 2.5), [long long], size: 6pt)
  cdraw.content((12.4, 3.9), [one sum,#linebreak() 16 bytes], size: 6pt)
  cdraw.line((10.3, 2.8), (12.2, 2.8), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((12.4, 2.3), (14.9, 3.3), fill: none, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((13.65, 2.8), [railway,#linebreak() ch 27], size: 6pt)
})

#callout("warning", "SENTINELS COLLIDE WITH PAYLOADS", [A miss encoded as -1 works until -1 is a legitimate value, and the collision is silent: the caller cannot tell the absent from the present. The sum type spends one tag byte to make absence a first-class value, and the exhaustive switch spends one case to force the caller to acknowledge it. Chapters 27 to 29 build every error path on this trade.])

The next chapter, #xref-to("math", "railway"), widens this two-tag
sum into the option and result types and chains their consumers into
the railway, the error handling idiom the rest of the capstone runs on.

sources: cppreference, "union member access and type punning",
en.cppreference.com/w/c/language/union, fetched 2026-09-22, quoted
once in the pitfall callout. The c23 feature record, typeof and
typeof_unqual at 6.7.2.5, constexpr objects, auto, nullptr, and the
compound literal lifetime rules of 6.5.2.5, verified against this
repo's book 1, chapters types and pointers, version 2.0, read
2026-09-22. Defer verified against technical specification 25755 as
shipped by clang 23.1.1, stddefer.h version macro 202602L under
-fdefer-ts, probed on this machine 2026-09-22, and the exhaustiveness
diagnostic quoted verbatim from a negative compile under the gate
flags the same day. This chapter has no mml-book mapping, the type
arithmetic is the set counting of #xref-to("math", "proof") at
elementary sizes, verified by enumeration in the samples rather than
by page citation. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter
Ch26`, 59 checks in chapter 26 of the math suite, format and asan
clean.
