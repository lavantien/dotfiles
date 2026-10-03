#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the c23 library

The library is where the standard touches running code. Four samples pin
four corners of it on this toolchain: checked arithmetic from
`stdckdint.h`, the sized integers and the clock from `stdint.h` and
`time.h`, the sort and search contract from `stdlib.h`, and `defer`, the
newest arrival, riding in from technical specification 25755 through
clang's `stddefer.h`. Every number in the prose below was printed by a
check the gate counted.

== stdckdint, checked arithmetic

C23 answers the oldest question in C, did that operation wrap, with
three macros. `ckd_add`, `ckd_sub`, and `ckd_mul` take a pointer to the
result, two operands, and return `bool`: true when the mathematical
result did not fit the result type. The wrapped value is stored either
way, and the truth table fits in one listing:

#listing("c-os-cloud/samples/src/Ch06/ckdint.c", first: 22, last: 39, caption: [five truth table rows, every wrapped value still stored])

Walk the rows. `INT_MAX + 1` reports true and stores `INT_MIN`.
`INT_MIN - 1` reports true and stores `INT_MAX`. `0u - 1u` into an
unsigned result reports true, because unsigned wraparound is real
overflow for these macros, and stores `UINT_MAX`. `65536 * 65536`
reports true and stores exactly 0. The identity row, `INT_MAX + 0`,
reports false: not every operation overflows, and the table has a
negative control.

#listing("c-os-cloud/samples/src/Ch06/ckdint.c", first: 41, last: 53, caption: [the result type decides what counts as overflow, not the operands])

The result type `R` is the yardstick. Two `int` operands that would
overflow `int` are clean when they land in a `long long`. The same
`40000 + 40000` trips over a `uint16_t` result, storing 14464, and
lands as 80000 in an `int`. One macro, two destinations, two verdicts:
the check is made in the width of the destination, never in the width
the operands happened to carry through integer promotion. That is the
trap the macros close, a hand-rolled guard written against the operand
types silently checks the wrong arithmetic.

#listing("c-os-cloud/samples/src/Ch06/ckdint.c", first: 55, last: 71, caption: [signed math into an unsigned destination, the `_Bool` return, one row alive at -O2])

`-3 * 5` is -15, which cannot exist in an `unsigned long long`, so the
macro reports true and stores the wrapped 18446744073709551601. The
return value is a real `_Bool`, one byte. The last row runs on `argc`
and `INT_MAX - argc`, a pair that sums to exactly `INT_MAX` for every
`argc` the gate can pass: deterministic in behavior, opaque to the
compiler. That opacity is deliberate, it keeps the checked add alive at
`-O2`, where the emitted ir carries `llvm.sadd.with.overflow.i32`, the
intrinsic that becomes one overflow-flagged add and a conditional branch
on x86-64. The gate pins that substring at `-O2` for this file.

#diagram([the hand-rolled post-check against the ckd truth table], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  // before: the hand-rolled guard and what the optimizer does to it
  cell(0.3, 5.5, 7.2, 1.4, [before: #linebreak() `if (a + b < a)`], fill: luma(215))
  cdraw.content((3.9, 4.6), [the post-check reads a wrap that #linebreak() signed overflow never produced, #linebreak() the optimizer deletes it, chapter 5], wrap: text.with(size: 6.5pt))
  // after: the truth table the gate runs
  cell(8.8, 6.6, 9.2, 0.9, [expression], fill: luma(205))
  cell(18.0, 6.6, 2.4, 0.9, [reports], fill: luma(205))
  cell(20.4, 6.6, 3.6, 0.9, [stores], fill: luma(205))
  let trow(y, e, o, s) = {
    cell(8.8, y, 9.2, 0.9, e)
    cell(18.0, y, 2.4, 0.9, o)
    cell(20.4, y, 3.6, 0.9, s)
  }
  trow(5.6, [ckd_add(INT_MAX, 1)], [true], [INT_MIN])
  trow(4.6, [ckd_sub(INT_MIN, 1)], [true], [INT_MAX])
  trow(3.6, [ckd_sub(0u, 1u) to unsigned], [true], [UINT_MAX])
  trow(2.6, [ckd_mul(65536, 65536)], [true], [0])
  trow(1.6, [ckd_add(INT_MAX, INT_MAX) to long long], [false], [4294967294])
  cdraw.line((3.9, 5.5), (3.9, 5.9), stroke: luma(140), mark: (end: ">"))
  cdraw.content((16.6, 0.5), [after: three macros, mixed operand types, the destination width is the contract], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("note", "what the macros refuse", [
  The C23 rule: operands and result must be integer types other than
  plain `char`, `bool`, a bit-precise type, or an enumeration. Probed
  on clang 23.1.1: `ckd_add` on `_BitInt(40)` operands fails to compile
  with "operand argument to checked integer operation must be an
  integer type other than plain 'char', 'bool', bit-precise, or an
  enumeration". The header's own comment also advises against a short
  result type, and no diagnostic follows that advice: the `uint16_t`
  row above compiled silently.
])

== sized integers and timespec_get

Exact-width integers are a compile-time contract, so the sample asserts
them at compile time, five `static_assert` lines next to the includes:

#listing("c-os-cloud/samples/src/Ch06/time.c", first: 19, last: 24, caption: [intN_t widths and intmax_t, asserted where they are declared])

The clock side of the library reports sizes and behavior. `time_t` is 64
bit on this target. `struct timespec` is 8 byte `tv_sec` plus 4 byte
`tv_nsec` padded to 16, because `long` is 4 bytes on windows even on a
64 bit target. `timespec_get` returns the value of its base argument on
success and zero on failure, the ucrt supports exactly one base,
`TIME_UTC`, defined as seconds and nanoseconds since midnight january
1 1970 utc. The only timing claim a deterministic test can make is the
weak one, and the sample makes exactly that one: two reads never go
backwards.

#listing("c-os-cloud/samples/src/Ch06/time.c", first: 26, last: 37, caption: [sizes, two timespec_get calls, the never-backwards invariant, tv_nsec range])

A fixed `time_t` through the utc calendar is fully deterministic,
because utc has no timezone and no locale. 1700000000 is november 14
2023 at 22:13:20, a tuesday, day 318 of the year: eight fields checked
against the printed calendar, with months 0 based and the year counted
from 1900, the two conventions that bite everyone once. And because
`time_t` is a plain second count, adding 86400 is day arithmetic, the
sample lands on the 15th.

#listing("c-os-cloud/samples/src/Ch06/time.c", first: 39, last: 54, caption: [a fixed epoch through gmtime_s, and one day of arithmetic on it])

#listing("c-os-cloud/samples/src/Ch06/time.c", first: 56, last: 58, caption: [intptr_t exists to round-trip a pointer])

#callout("pitfall", "gmtime does not survive the gate", [
  The ucrt marks `gmtime` with a deprecation annotation pointing at
  `gmtime_s`, and the gate's `-Werror` turns that annotation into a
  compile error, probed on this box. The sample uses `gmtime_s`, and
  there is a trap inside the fix: the microsoft signature is
  `errno_t gmtime_s(struct tm *, const time_t *)` while Annex K spells
  it `struct tm *gmtime_s(const time_t *, struct tm *)`, parameters
  reversed. Microsoft documents `_CRT_USE_CONFORMING_ANNEX_K_TIME` as
  the switch to the conforming variant.
])

The library also grows by removal. `gets` read a line with no bound and
no way to be made safe, C11 removed it from the standard, and microsoft
removed it from the crt beginning with visual studio 2015, the
conformance table credits VS 2019 16.8 for the C11 removal. `fgets` is
the portable replacement. The ucrt carries the annex K spellings
alongside, the `scanf_s` family takes a buffer size argument for every
`c` and `s` conversion, and `qsort_s` below takes a context pointer.

#diagram([library eras, what arrived when, and what was removed], length: 13pt, {
  let era(x, y, t, sub, fill: luma(235)) = {
    cdraw.rect((x, y), (x + 7.6, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((x + 3.8, y + 1.0), t, wrap: text.with(size: 6.5pt))
    cdraw.content((x + 3.8, y + 0.4), sub, wrap: text.with(size: 6pt, fill: luma(110)))
  }
  era(0.3, 5.4, [int8_t to int64_t], [c99, stdint.h])
  era(8.4, 5.4, [timespec_get, TIME_UTC], [c11, ucrt supports one base])
  era(16.5, 5.4, [gets], [removed in c11, out of the crt since VS 2015], fill: luma(215))
  era(0.3, 3.4, [scanf_s family, gets_s], [annex k, buffer sizes required])
  era(8.4, 3.4, [ckd_add, ckd_sub, ckd_mul], [c23, stdckdint.h], fill: luma(215))
  era(16.5, 3.4, [defer], [ts 25755, february 2026], fill: luma(215))
  cdraw.content((12.2, 1.6), [the c23 library is layered history: three standards and one technical specification, all live in one ucrt link], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== qsort, bsearch, and the comparator contract

`qsort` sorts an array it cannot see: it knows a base, a count, an
element width, and nothing else. Everything it learns about the elements
comes through one function pointer, called with two `const void *`
arguments, expected to return negative, zero, or positive. The sample's
comparators use the subtraction-free idiom, `(a > b) - (a < b)`, which
cannot overflow the way `a - b` can:

#listing("c-os-cloud/samples/src/Ch06/qsort.c", first: 25, last: 38, caption: [two comparators: plain, and the qsort_s spelling with a context pointer])

The contract on that function is the part every wrong qsort program
gets wrong. It must be irreflexive, `cmp(x, x) == 0`, and
antisymmetric, the signs of `cmp(a, b)` and `cmp(b, a)` must oppose. The
sample checks both properties over every ordered pair of the real array
before it sorts anything, because a comparator that violates them makes
`qsort` behavior undefined, not merely wrong:

#listing("c-os-cloud/samples/src/Ch06/qsort.c", first: 44, last: 57, caption: [irreflexivity and antisymmetry, checked on every ordered pair])

#listing("c-os-cloud/samples/src/Ch06/qsort.c", first: 59, last: 77, caption: [qsort orders the shuffled keys, bsearch finds 19 and reports 55 absent])

`bsearch` needs the array already sorted by the same comparator, and it
returns NULL for an absent key, both pinned. The microsoft docs state
the stability caveat in one sentence: if compare indicates two elements
are the same, their order in the resulting sorted array is unspecified.
So the search array carries unique keys, and where the sample does sort
duplicate keys it checks only the guaranteed property, non-decreasing
order with both duplicates present, never their relative order.

#listing("c-os-cloud/samples/src/Ch06/qsort.c", first: 79, last: 98, caption: [qsort_s over duplicate keys, every comparison through the context])

`qsort_s` is the annex K spelling present in the ucrt: same behavior,
one added `context` pointer that travels into every comparator call.
The docs' stated purpose is reentrancy, the context replaces the static
variable a comparator would otherwise need, which is what makes a sort
usable from two threads at once. Here it carries a counter, and the
sample asserts the invariant any comparison sort must obey, at least
`n - 1` calls, then prints the observed 10 comparisons for 4 elements,
a number owned by this ucrt build, not by the standard.

#diagram([bsearch probing the sorted array for key 42], length: 13pt, {
  let vals = ([3], [7], [19], [42], [90])
  for (i, v) in vals.enumerate() {
    cdraw.rect((1.0 + i * 2.4, 5.2), (3.4 + i * 2.4, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((2.2 + i * 2.4, 6.0), v, wrap: text.with(size: 7pt))
  }
  // probe 1: lo 0, hi 4, mid 2
  cdraw.line((7.0, 7.6), (7.0, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.0, 8.0), [probe 1: lo 0, hi 4, mid 2, #linebreak() 19 < 42, go right], wrap: text.with(size: 6pt))
  // probe 2: lo 3, hi 4, mid 3
  cdraw.line((11.8, 7.6), (11.8, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.6, 8.0), [probe 2: lo 3, hi 4, mid 3, #linebreak() 42 found, two probes], wrap: text.with(size: 6pt))
  cdraw.content((6.6, 3.4), [every probe is one comparator call, #linebreak() the same function qsort used to order the array], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== defer and stddefer

`defer` is not in C23. It arrives from technical specification 25755,
and clang 23.1.1 ships it as `stddefer.h`, a 19 line header that
aliases `defer` to the keyword `_Defer` when
`__STDC_DEFER_TS25755__` is defined, which happens only under the
driver flag `-fdefer-ts`. The gate's tool flags carry it, and the
sample's first check pins the header's version macro, 202602L. The
semantics fit one sentence: a deferred statement runs when its scope
exits, last registered first out.

#listing("c-os-cloud/samples/src/Ch06/defer.c", first: 21, last: 29, caption: [the recorder, every deferred statement appends one tag])

#listing("c-os-cloud/samples/src/Ch06/defer.c", first: 36, last: 48, caption: [nested scopes, one early return, registration order against unwind order])

The recorded orders are the whole lesson. On the early path the marks
read `r`, `b`, `a`: the body marks `r`, the return unwinds the block's
`b`, then the function's `a`. On the normal path they read `b`, `x`,
`d`, `a`, and the surprise is in the middle: `b` fires when its block
closes, before `d` is even registered, a defer lives and dies with its
scope, not with its function. In a loop each iteration is a scope, so
each defer fires at its own iteration's end, giving `AaBbCc`, the
immediate uppercase mark followed by that iteration's deferred
lowercase one.

#listing("c-os-cloud/samples/src/Ch06/defer.c", first: 50, last: 55, caption: [one defer per iteration, each fires at that iteration's end])

#listing("c-os-cloud/samples/src/Ch06/defer.c", first: 57, last: 74, caption: [the pinned unwind orders: rba early, bxda normal, AaBbCc in the loop])

#listing("c-os-cloud/samples/src/Ch06/defer.c", first: 76, last: 85, caption: [the statement after defer can be a compound statement])

#callout("verify", "the zero-cost claim, checked in the emitted code", [
  At `-O2` the cleanup is not calls at all. The whole unwind sequence
  of the early path compiles to one instruction, `movl $0x616272`,
  writing the four bytes of "rba" and its terminator to the marks
  array, and the ir shows it as a single
  `store <4 x i8> <i8 114, i8 98, i8 97, i8 0>`. A grep over the
  emitted module finds zero `personality`, `landingpad`, or `invoke`
  lines: there is no unwinding machinery, no tables, no runtime, the
  deferred code is ordinary straight-line code the optimizer inlines
  like any other. The gate pins `@marks`, `getelementptr inbounds`, and
  the `movl` for this file.
])

#diagram([registration order against unwind order, both paths through scoped], length: 13pt, {
  let box3(x, t, fill: luma(235)) = {
    cdraw.rect((x, 4.6), (x + 2.3, 5.9), fill: fill, radius: 0.02)
    cdraw.content((x + 1.15, 5.25), t, wrap: text.with(size: 7pt))
  }
  cdraw.content((5.2, 6.6), [registration: a, then b, then d], wrap: text.with(size: 6.5pt))
  box3(4.0, [a], fill: luma(215))
  box3(5.5, [b])
  box3(7.0, [d])
  cdraw.content((5.2, 4.0), [function scope, block scope, function scope #linebreak() after the block closed], wrap: text.with(size: 6pt, fill: luma(110)))
  // early path strip
  cdraw.content((1.6, 2.9), [early return path], wrap: text.with(size: 6.5pt))
  let strip(y, x0, seq, sub) = {
    for (i, ch) in seq.enumerate() {
      cdraw.rect((x0 + i * 2.0, y), (x0 + i * 2.0 + 1.8, y + 1.0), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + i * 2.0 + 0.9, y + 0.5), ch, wrap: text.with(size: 7pt))
    }
    cdraw.content((x0 + 3 * 2.0 + 1.0, y + 0.5), sub, wrap: text.with(size: 6pt, fill: luma(110)))
  }
  strip(1.6, 4.2, ([r], [b], [a]), [body, block unwinds, function unwinds])
  // normal path strip
  cdraw.content((1.6, 1.0), [normal path], wrap: text.with(size: 6.5pt))
  strip(0.0, 4.2, ([b], [x], [d], [a]), [block close, body, return, return])
  cdraw.line((6.4, 4.6), (5.1, 2.6), stroke: luma(140), mark: (end: ">"))
  cdraw.line((6.4, 4.6), (5.1, 1.0), stroke: luma(140), mark: (end: ">"))
})

sources: clang.llvm.org C support page (N2683 towards integer safety,
status clang 18), learn.microsoft.com ucrt pages for timespec_get,
gmtime_s, qsort, qsort_s, the scanf_s family, gets, and the visual
studio C standard library conformance table, all accessed 2026-09-12;
the stdckdint.h and stddefer.h text read from the clang 23.1.1 resource
directory on this machine the same day. Sample behavior verified by
`make verify-c`, 33 checks in chapter 6 of the samples suite.
