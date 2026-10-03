// ch01, overwriting the stub 2026-09-21. every behavioral claim is one of
// the 63 checks in math/samples/src/Ch01 or a quote banked from a
// canonical source fetched the same day. values outside the checks come
// from the exact fraction probe playground/math-ch01/probe.py, run the
// same day the samples were probed.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= floating point anatomy

Three samples carry the chapter: `anatomy.c` decodes bit patterns and
asserts them, `rounding.c` pins all four rounding modes against fenv, and
`frontier.c` walks the 2^53 integer wall and the subnormal floor. The
chapter makes 6 moves: the layout of a double, one ulp, rounding pinned,
the subnormal floor, what `math.h` promises, and the integer frontier
where doubles stop counting. The dsa chapters treat floats as a tool with
tolerances; here the format itself is opened and every bit is asserted.
Every behavioral claim below is one of the 63 checks in the 3 samples of
chapter 01 or a sentence quoted from a canonical source fetched
2026-09-21. The physics game capstone leans on all of it in
#xref-to("game-systems", "math").

== the bits of a double

Goldberg, fetched 2026-09-21: "Squeezing infinitely many real numbers into
a finite number of bits requires an approximate representation." The
representation is 64 bits in 3 fields: a 1 bit sign $s$, an 11 bit biased
exponent $e$, and a 52 bit fraction $f$. For every normal value the decode
is

$ "value" = (-1)^s dot (1 + frac(f, 2^52)) dot 2^(e - 1023) $

The exponent is stored biased by 1023 so that, within one sign, comparing
two bit patterns as unsigned integers compares the values, ordering comes
free with the layout. The free ordering stops at the sign bit: any
negative value's pattern compares greater than every nonnegative one as
unsigned integers, the sign bit sits above the magnitude. The fraction
stores everything right of the leading 1, which is never stored. The two worked examples of the section:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*field*], [*width*], [*1.0*], [*0.15625*]),
  [sign $s$], [1 bit], [0], [0],
  [biased exponent $e$], [11 bits], [0x3ff], [0x3fc],
  [fraction $f$], [52 bits], [0x0000000000000], [0x4000000000000],
)

The dry run: 0.15625 is 5/32, which is $1.01_2$ times $2^(-3)$. The biased
exponent must satisfy $e - 1023 = -3$, so $e = 1020$, stored as 0x3fc. The
single fraction bit carries weight $2^(-2)$, and scaled by $2^52$ it
stores as $f = 2^50$, the pattern 0x4000000000000. Concatenated, the full
64 bits are 0x3fc4000000000000, and the sample asserts exactly that, then
reassembles the 3 fields back into 0.15625 bit for bit with `ldexp`.

#listing("math/samples/src/Ch01/anatomy.c", first: 13, last: 57,
  caption: [the check harness, field extraction, and the bit exact rebuild])

#diagram([the 64 bits of a double, and the decode of 1.0], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(1.0, 6.4, 2.0, [sign s])
  box(3.0, 6.4, 5.0, [biased exponent e])
  box(8.0, 6.4, 11.0, [fraction f, the 52 stored bits])
  cdraw.content((2.0, 7.7), [1 bit], size: 6pt)
  cdraw.content((5.5, 7.7), [11 bits], size: 6pt)
  cdraw.content((13.5, 7.7), [52 bits], size: 6pt)
  cdraw.line((2.0, 6.4), (2.0, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.5, 6.4), (5.5, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.5, 6.4), (13.5, 5.6), stroke: luma(100), mark: (end: ">"))
  box(1.0, 4.6, 2.0, [s = 0])
  box(3.0, 4.6, 5.0, [e = 0x3ff])
  box(8.0, 4.6, 11.0, [f = 0x0000000000000])
  cdraw.content((16.8, 6.0), [reads back as 1.0], size: 6pt)
})

#callout("note", "the hidden bit is a free bit", [
  The leading 1 of the significand is implied, never stored, so 52 stored
  fraction bits carry 53 bits of significand on every normal value. The
  bill arrives at the edges: when the exponent field is 0 the implied bit
  is gone and the value degenerates to $f dot 2^(-1074)$, which is
  exactly the subnormal floor of the fourth section.
])

Signed zero shows the sign bit doing real work. +0.0 and -0.0 compare
equal yet divide differently: cppreference, fetched 2026-09-21, "1.0 / 0.0
== INFINITY, but 1.0 / -0.0 == -INFINITY". The sample holds both halves
as checks on volatile operands, comparison and division.

#listing("math/samples/src/Ch01/anatomy.c", first: 140, last: 174,
  caption: [the decode table, one row per value, printed live])

Two numbers: 0x3ff0000000000000 is 1.0 and 0xbfe8000000000000 is -0.75.
The pair looks unrelated, but 0x3fe8000000000000 is 0.75, and flipping
the top bit alone is the whole difference. One sign bit, two zeros, and
division keeps the zero's sign.

== one ulp

Goldberg, fetched 2026-09-21: "This rounding error is the characteristic
feature of floating-point computation." The unit of that error is the
ulp, unit in the last place: the spacing between a value and its
representable neighbor. `nextafter(v, INFINITY)` returns exactly that
neighbor, so subtracting the original back out measures the spacing, and
the sample walks 6 rungs from the smallest positive double to $2^60$.

#listing("math/samples/src/Ch01/frontier.c", first: 59, last: 81,
  caption: [measuring one ulp with nextafter, six rungs])

The spacing doubles at every exponent step. The bottom is dense: the
minimum normal value $2^(-1022)$ still sits $2^(-1074)$ from its
neighbor, because the subnormal rungs below it hold the floor at that
spacing. At $2^52$ the spacing reaches 1, and at $2^53$ doubles stop
counting every integer, section 6's subject. At $2^60$ the spacing is
256, and nothing in the type records that neighbors a quintillion apart
now step by whole hundreds.

#diagram([one ulp doubles at every exponent step], length: 13pt, {
  cdraw.line((1.0, 2.4), (16.2, 7.0),
    stroke: (paint: luma(150), dash: "dashed"))
  let step(x0, h, t) = {
    cdraw.rect((x0, 1.0), (x0 + 2.4, 1.0 + h), fill: luma(245), radius: 0.02)
    cdraw.content((x0 + 1.2, 0.6), t, size: 6pt)
  }
  step(1.0, 1.0, [$2^(-1074)$ at the min normal])
  step(4.2, 2.2, [$2^(-52)$ at 1.0])
  step(7.4, 3.4, [$2^(-51)$ at 2.0])
  step(10.6, 4.6, [1 at $2^52$])
  step(13.8, 5.8, [256 at $2^60$])
  cdraw.content((8.6, 7.5), [the dashed line is the doubling], size: 6pt)
})

The same doubling is what `DBL_EPSILON` measures from the middle of the
range: at 1.0 the spacing is $2^(-52)$, or 2.220446049250313e-16, the
smallest step any computation near one can take or even request.

Two numbers: the spacing at the minimum normal is $2^(-1074)$, about
5e-324, and at $2^60$ it is 256. Between those two rungs the spacing
grows by a factor of $2^1082$, and the format reports all of it with the
same calm 8 byte pattern.

== rounding, pinned

An exact result that does not fit must go somewhere. Goldberg, fetched
2026-09-21: "There are four rounding modes: round toward nearest, round
toward $oo$, round toward 0, and round toward $-oo$." The startup mode is
round to nearest, ties to even, and the tie rule is where it earns its
keep.

The dry run: 1.0 + 2^(-53) is the exact midpoint between 1.0, whose
stored tail is even, and its neighbor 0x3ff0000000000001, whose tail is
odd. Ties to even keeps 1.0. Goldberg's own example: "thus 12.5 rounds to
12 rather than 13 because 2 is even."

#listing("math/samples/src/Ch01/rounding.c", first: 35, last: 76,
  caption: [the 1.0 tie recomputed under all four fenv modes])

#diagram([the exact midpoint between neighbors goes to the even tail],
  length: 13pt, {
  cdraw.line((2.0, 4.6), (18.0, 4.6), stroke: luma(60))
  cdraw.line((2.0, 4.3), (2.0, 4.9), stroke: luma(60))
  cdraw.line((10.0, 4.3), (10.0, 4.9), stroke: luma(100))
  cdraw.line((18.0, 4.3), (18.0, 4.9), stroke: luma(60))
  cdraw.content((2.0, 3.9), [1.0, tail even], size: 6pt)
  cdraw.content((18.0, 3.9), [1.0 + 2^(-52), tail odd], size: 6pt)
  cdraw.content((10.0, 5.3), [midpoint 1.0 + 2^(-53)], size: 6pt)
  cdraw.line((10.0, 5.0), (5.0, 6.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.8, 6.6), [nearest, downward, toward zero], size: 6pt)
  cdraw.line((10.0, 5.0), (15.0, 6.2),
    stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((14.6, 6.6), [upward], size: 6pt)
})

#callout("pitfall", "the pragma that would make this clean is off by default", [
  The c standard gates mode dependent code behind `#pragma STDC FENV_ACCESS ON`.
  Clang's users manual, fetched 2026-09-21, supports the pragma but leaves
  it off: "by default `FENV_ACCESS` is disabled", so an ordinary build is
  free to fold what looks like a runtime computation under the default
  mode. The samples stand on two measures instead: `volatile` operands
  force every sum through a runtime instruction that honors the installed
  mode, and each `fesetround` is verified with a `fegetround` readback
  before any tie is recomputed.
])

The other three modes are not curiosities. Interval arithmetic runs its
lower bounds downward and its upper bounds upward, and directed rounding
turns a wrong last digit into an interval that contains the true value.
The sample walks the 1.0 tie through upward, downward, and toward zero,
reads the stored bits back in each mode, and restores nearest last.

#listing("math/samples/src/Ch01/rounding.c", first: 78, last: 101,
  caption: [0.1 + 0.2 lands one ulp above 0.3, flag and all])

#callout("warning", "0.1 + 0.2 is not 0.3", [
  Each literal stores a slight overestimate, the exact sum needs one bit
  more than 53, and the hardware rounds that sum up to
  `0x3fd3333333333334` while the literal 0.3 stores
  `0x3fd3333333333333`. The raised flag is `FE_INEXACT`, and it fires on
  nearly every interesting computation. Never test computed sums with
  `==`, compare within a tolerance, which is chapter 02's whole subject.
])

Two numbers: the sum stores 0x3fd3333333333334 and 0.3 stores
0x3fd3333333333333. The bit patterns differ by exactly 1, one ulp, and
the sample asserts that difference numerically.

== the subnormal floor

Below $2^(-1022)$ the exponent field would be 0, and an implied leading 1
would have nowhere to live. The format spends the field differently: the
value degenerates to $f dot 2^(-1074)$ with no implied 1, and the
spacing holds at the floor instead of collapsing. This is gradual
underflow, and its whole point is algebraic: with it, a subtraction
rounds to zero only when the operands were equal. Flush to zero, the
alternative still common in graphics code and on some gpus, breaks that:
every subnormal becomes +0, distinct tiny values cancel into a fake
zero, and the interval below $2^(-1022)$ turns into a cliff.

The dry run: the smallest subnormal, 5e-324, halved, lands exactly
halfway between 0 and itself. The tie goes to the even significand 0, so
the value drains to +0, and the hardware raises `FE_UNDERFLOW` and
`FE_INEXACT`. The sample asserts the all zero bits and both flags.

#listing("math/samples/src/Ch01/frontier.c", first: 83, last: 116,
  caption: [round trip betrayal, the overflow walk, the underflow drain])

#diagram([gradual underflow drains smoothly, flush to zero cliffs],
  length: 13pt, {
  cdraw.content((5.0, 7.4), [gradual underflow, the standard], size: 6pt)
  cdraw.content((15.0, 7.4), [flush to zero, the cliff], size: 6pt)
  cdraw.line((1.5, 6.6), (3.0, 5.4), stroke: luma(60))
  cdraw.line((3.0, 5.4), (4.2, 4.4), stroke: luma(60))
  cdraw.line((4.2, 4.4), (5.2, 3.6), stroke: luma(60))
  cdraw.line((5.2, 3.6), (6.0, 3.0), stroke: luma(60))
  cdraw.line((6.0, 3.0), (6.6, 2.6), stroke: luma(60))
  cdraw.line((6.6, 2.6), (7.0, 2.3), stroke: luma(60))
  cdraw.line((1.5, 2.0), (8.5, 2.0), stroke: luma(100))
  cdraw.content((8.1, 2.3), [floor 2^(-1074)], size: 6pt)
  cdraw.line((11.5, 6.6), (13.0, 5.4), stroke: luma(60))
  cdraw.line((13.0, 5.4), (14.0, 4.4), stroke: luma(60))
  cdraw.line((14.0, 4.4), (14.6, 3.6), stroke: luma(60))
  cdraw.line((14.6, 3.6), (15.0, 3.0), stroke: luma(60))
  cdraw.line((15.0, 3.0), (15.0, 2.1),
    stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((16.0, 2.0), [+0], size: 6pt)
  cdraw.line((11.5, 2.0), (14.6, 2.0), stroke: luma(100))
})

Two numbers: 5e-324 halved drains to +0 with `FE_UNDERFLOW` raised, while
`nextafter(DBL_MAX, INFINITY)` jumps to $oo$ with `FE_OVERFLOW` raised.
The two edges of the type fail in opposite directions, and both leave a
status flag as the only evidence that anything happened.

== what math.h promises

The arithmetic operators, `sqrt`, and `fma` carry the strongest contract
in the library: compute the true result exactly, round it once.
cppreference, fetched 2026-09-21: "`sqrt` is required by the IEEE
standard to be correctly rounded from the infinitely precise result. ...
The only other operations which require this are the arithmetic operators
and the function `fma`. Other functions, including `pow`, are not so
constrained." That sentence is the taxonomy of the whole header: one
small required group, and everything else free to land an ulp or two off
today and a different ulp or two after the next toolchain update.

#listing("math/samples/src/Ch01/anatomy.c", first: 93, last: 138,
  caption: [classifiers, specials, boundary constants, and the rounded square])

Goldberg states the stakes for the required group: "The IEEE standard
requires that the result of addition, subtraction, multiplication and
division be exactly rounded." `pow` makes no such promise, and nothing in
the standard objects when its error moves between compiler versions.

The floating point environment is the observability layer. Every
operation records what it did in status flags: cppreference pins
`nextafter`'s contract, a finite `from` with an infinite result "raises
FE_INEXACT and FE_OVERFLOW", and the sample watches both flags set on the
walk past `DBL_MAX`. Goldberg adds a mode dependent edge: "when round
toward 0 or round toward $-oo$ is in effect, an overflow of positive
magnitude causes the default result to be the largest representable
number, not $oo$." Toward zero, overflow saturates instead of escaping
to infinity.

#diagram([what math.h promises, in 4 boxes], length: 13pt, {
  let panel(x0, y0, title, t2, fill) = {
    cdraw.rect((x0, y0), (x0 + 8.0, y0 + 1.8), fill: fill, radius: 0.02)
    cdraw.content((x0 + 4.0, y0 + 1.3), title, size: 6.5pt)
    cdraw.content((x0 + 4.0, y0 + 0.5), t2, size: 6pt)
  }
  panel(1.0, 5.4, [required correctly rounded],
    [add, sub, mul, div, sqrt, fma], luma(245))
  panel(11.0, 5.4, [unconstrained], [pow, exp, log, sin, cos], luma(245))
  panel(1.0, 2.8, [status flags, what happened],
    [FE_INEXACT, FE_OVERFLOW, FE_UNDERFLOW], luma(235))
  panel(11.0, 2.8, [rounding modes, 4 directions],
    [nearest, upward, downward, toward zero], luma(235))
  cdraw.line((9.0, 6.3), (11.0, 6.3), stroke: luma(100))
  cdraw.line((9.0, 3.7), (11.0, 3.7), stroke: luma(100))
})

#callout("note", "FE_INEXACT fires on nearly everything", [
  `FE_INEXACT` means the exact result did not fit, which is the ordinary
  case, not a failure. Treating it as an error indicator poisons every
  check built on it. The usable signals are the extreme pair,
  `FE_OVERFLOW` and `FE_UNDERFLOW`, and the clean rule that a correctly
  rounded operation sets `FE_INEXACT` exactly when it had to round.
])

Two numbers: `sqrt(2)` stores 1.4142135623730951, the correctly rounded
true root, and squaring it back gives 2.0000000000000004, one ulp high.
A required rounded operation composed with itself is still not an
inverse, and this time the hardware says so: the square raised
`FE_INEXACT`, and the sample asserts root, square, and flag together.

== the 2^53 frontier

Doubles count integers exactly up to $2^53$: below the wall the 52 stored
fraction bits plus the implied 1 cover every integer bit. At $2^53$ the
spacing becomes 2. One more than the wall is the exact midpoint between
$2^53$ and $2^53 + 2$, ties to even keeps $2^53$, and the increment
vanishes.

The dry run: take $2^53$, add 1, compare with the original, equal. Add 2,
compare, different, one visible ulp. Add 3, it lands on $2^53 + 4$, the
tie between +2 and +4 goes to the even tail. Then subtract the original
back out of a nearby sum and it comes back exact, which is Sterbenz's
lemma: when $y\/2 <= x <= 2y$, the difference $x - y$ is representable,
so nearby subtraction never rounds.

#listing("math/samples/src/Ch01/frontier.c", first: 33, last: 57,
  caption: [the wall, the vanished increment, and sterbenz])

The round trip betrays the source text. The stored value is $2^53$, so
the integer cast in section 4's listing reads 9007199254740992, not the
9007199254740993 written. The cast is where the lie becomes visible, and
the integer view of the same bit patterns is
#xref-to("c-os-cloud", "machine").

#diagram([the integer wall at 2^53], length: 13pt, {
  cdraw.line((1.5, 4.0), (18.5, 4.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.0, 3.7), (5.0, 4.3), stroke: luma(60))
  cdraw.content((5.0, 3.3), [$2^52$, the last spacing of 1], size: 6pt)
  cdraw.line((11.0, 3.4), (11.0, 4.6), stroke: luma(60))
  cdraw.content((11.0, 4.9), [the wall $2^53$, spacing becomes 2], size: 6pt)
  cdraw.line((12.2, 5.5), (11.5, 4.7),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((14.0, 5.8), [plus 1 vanishes here], size: 6pt)
  cdraw.line((12.6, 4.0), (14.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.6, 3.3), [plus 2 is visible, one ulp], size: 6pt)
  cdraw.content((3.6, 4.4), [every integer exact], size: 6pt)
})

Two numbers: $2^53 + 1$ is invisible, equal to $2^53$, while $2^53 + 2$
is the first integer past the wall. A counter that steps by 1 past the
wall stops advancing, and a loop condition like `d < d + 1.0` is false on
its first test.

Every later chapter lives downstream of these bits. The error chapter
turns the ulp counting of section 2 and the tie rules of section 3 into
tolerance discipline, forward to #xref-to("math", "error").

sources: David Goldberg, "What Every Computer Scientist Should Know About
Floating-Point Arithmetic", ACM Computing Surveys 23-1,
docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html, fetched
2026-09-21. cppreference c pages fenv, FE_round, nextafter, math
functions, sqrt, and arithmetic_types, en.cppreference.com, fetched
2026-09-21. Clang users manual, floating point behavior section,
clang.llvm.org, fetched 2026-09-21. Probed on this machine the same day.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch01`,
63 checks in chapter 01 of the math suite.
