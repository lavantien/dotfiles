// book 10, chapter 15: fast big integer arithmetic, the ladder the finals
// never needed but the education does. a dynamic bigint core, karatsuba,
// exact ntt, complex fft plain and split, and knuth algorithm d division,
// from scratch in seven languages, every measured number from the ch14
// benches and suites plus the java ch15 bench reported by the streams,
// bench dates 2026-09-19 and 2026-10-06
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= fast big arithmetic

Six finals, 68 problems, and not one accepted submission needed more
than schoolbook multiply or small-divisor division: no C or Lua year
solver loads the toolbox bigint, and the native-stack languages stay in
the one-to-three limb regime where a 64-bit word already carries the
answer. This chapter builds the missing ladder anyway, because the
education is the point: a dynamic bigint core, karatsuba, exact ntt
convolution, complex fft in a plain and a packed-split path, and full
long division by Knuth's algorithm D, from scratch in all seven
languages, one algorithm per section in the fixed order c, go, java,
c\#, javascript, python, lua. Every suite chains all four multipliers
to the same decimal string on shared random operands, and the measured
section reports this machine's crossovers, dated 2026-09-19 and
2026-10-06.

== the dynamic bigint core

Sign-magnitude over base one billion, dynamic in every language. A limb
holds nine decimal digits, 0 through 999999999, limbs sit least
significant first, and the sign lives in its own cell as +1 or -1.
Zero canonicalizes to sign +1 with zero limbs, and every operation
normalizes on the way out: strip high zero limbs first, then fix the
sign, so no result ever carries a phantom leading limb. Comparison
reads sign, then limb count, then limb values from the top, and decimal
io accepts a leading '-' and nothing else, no '+', no leading zeros,
"0" for zero. Parsing cuts the decimal string into nine-digit chunks
from the right, so the chapter's 23-digit fixture 12345678901234567890123
parses to exactly three limbs, 12345, 678901234, 567890123 from most
to least significant, and printing is the reverse, top limb bare,
every limb below it padded to nine digits.

The C toolbox of #xref-to("icpc", "toolbox-c") already carries a
bigint, but its twelve fixed slots, 108 digits of headroom, cannot host
a karatsuba recursion that needs dynamically sized halves down the
tree, and its zero convention, sign +1 with one zero limb, disagrees
with the Lua toolbox's sign-0 zero of #xref-to("icpc", "toolbox-lua"),
so chapter 15 grows one new canonical core rather than importing
either sibling. The language mappings keep contest discipline: C packs
`struct {int sign; int n; unsigned limb[4096];}` with `BIG_MAX 4096`
limbs, 36864 decimal digits, static arrays, assert guards, no malloc.
C\# builds a sealed class over `uint[]`, go a struct of sign plus
`[]uint32`, java a nested Big class over an explicit-capacity `int[]`,
javascript keeps limbs as plain Number, each under 2^30
and exact in f64, with every exact limb product routed through BigInt
because 999999999 squared passes 2^53, python keeps an int list, lua
integer table entries.

The dry run: the C suite's round-trip and carry facts walk the 23-digit
fixture and the 20-nine addend, `ch14_bigint_test.c` asserting the limb
layout, both printed strings, and `r.n = 3` on either result, the same
family every suite pins.

+ Parse cuts `12345678901234567890123` nine digits at a time from the
  right: `567890123`, then `678901234`, top limb `12345`, three limbs
  under sign +1.
+ Print reverses the walk, top limb bare, both limbs below padded to
  nine digits, and the same 23 come back.
+ The carry opener parses `99999999999999999999` to limbs 999999999,
  999999999, 99, then adds 1.
+ Limb 0: 999999999 + 1 = 1000000000, writes 0, carries 1. Limb 1
  repeats the rollover, writes 0, carries 1.
+ Limb 2: 99 + 1 = 100, the new top, so the result limbs are 0, 0, 100.
+ Printing pads the two low limbs to nine zeros each, and the string
  lands `100000000000000000000`, a 1 with 20 zeros.
+ The zero side canonicalizes the other way, `a - a` leaving sign +1
  with zero limbs, while "+5" and "007" die at parse.

#diagram([the run as a sequence, the string cut from the right into three limbs then printed back top-bare, the carry opener rolling over beneath], length: 12pt, {
  let cell = (x, y, w, t, f) => {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: if f { luma(225) } else { luma(242) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.content((8.6, 8.7), [parse cuts nine from the right], size: 6.5pt)
  cdraw.rect((0.6, 7.1), (7.0, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 7.6), [12345678901234567890123], size: 6pt)
  cell(0.6, 5.1, 2.0, [12345], false)
  cell(3.0, 5.1, 2.6, [678901234], true)
  cell(6.0, 5.1, 2.6, [567890123], true)
  cdraw.line((7.6, 7.1), (7.3, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.4, 5.6), [limb 2, limb 1, limb 0, print pads below the top], size: 6pt, anchor: "west", fill: luma(100))

  cdraw.content((8.6, 4.2), [the carry opener, plus 1], size: 6.5pt)
  cell(0.6, 2.6, 2.6, [999999999], true)
  cell(3.6, 2.6, 2.6, [999999999], true)
  cell(6.6, 2.6, 2.0, [99], false)
  cdraw.content((9.4, 3.1), [+1 enters at limb 0], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.line((1.9, 2.6), (1.9, 1.5), stroke: luma(100), mark: (end: ">"))
  cell(0.6, 0.4, 2.6, [0], false)
  cell(3.6, 0.4, 2.6, [0], false)
  cell(6.6, 0.4, 2.0, [100], true)
  cdraw.content((9.4, 0.9), [both full limbs roll, the 2-digit top takes the carry], size: 6pt, anchor: "west", fill: luma(100))
})

The three-limb round trip and the 100-topped rollover are what the
checks read, and the listings below build the core in seven languages.

#listing("icpc/samples-c/src/Ch14/ch14_bigint.h", first: 15, last: 52, caption: [c, the base constants, the sign-magnitude struct over 4096 static limbs, and the normalize that strips high zeros then fixes the sign])

#listing("icpc/samples-go/ch14/bigint.go", first: 9, last: 31, caption: [go, the Big struct and normalize, zero collapsing to sign +1 with no limbs])

#listing("icpc/samples-java/src/Ch15/Bigint.java", first: 377, last: 408, caption: [java, the nested Big core, sign plus a live limb count over an explicit-capacity int array, the constructor itself the normalization contract])

#listing("icpc/samples/src/Ch14/FastArith.cs", first: 6, last: 33, caption: [c\#, the sealed Big class whose constructor is the normalization contract, every factory routed through it])

#listing("icpc/samples-js/src/ch14-bigint.mjs", first: 1, last: 17, caption: [javascript, Number limbs under 2^30, BigInt at every exact product, make as the normalize gate])

#listing("icpc/samples-py/src/Ch14/ch14_bigint.py", first: 1, last: 24, caption: [python, base, the shared lcg constants, the size ladder, and the normalizing Big constructor])

#listing("icpc/samples-lua/ch14_bigint.lua", first: 1, last: 21, caption: [lua, base-1e9 limbs in a plain table, norm trimming high limbs and pinning zero to sign +1])

The fixture families pin the contract in every suite: the 23-digit
round trip through those exact three limbs, the carry opener
`99999999999999999999 + 1 = 100000000000000000000` whose result limbs
are 0, 0, 100, zero canonicalized from `a - a`, "-0" and "007" and
"+5" refused at parse, signed subtraction across signs, and the
compare ladder sign first then length then top limb. Random agreement
runs on the shared 64-bit lcg, `x' = (6364136223846793005 * x +
1442695040888963407) mod 2^64` seeded `0x9E3779B97F4A7C15`, one draw
per limb reduced mod 1e9, top limb forced nonzero, over the size
ladder 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233 limbs, 4 pairs per
class, against native integers where the language has them. Counts:
C 237 checks, javascript 12 tests, python 293 checks, lua 7 named
checks, beside the anchor `123456789 * 987654321 = 121932631112635269`
that chapter 2 already pins on the schoolbook.

#diagram([memory layout: the chapter 15 core as one sign cell plus exactly the limbs it needs, beside the ch2 toolbox's twelve fixed slots], length: 12pt, {
  cdraw.content((9.6, 8.5), [ch2 toolbox: 12 fixed slots, 108 digits], size: 6.5pt)
  for i in range(12) {
    let x = 0.6 + i * 1.52
    cdraw.rect((x, 6.7), (x + 1.36, 7.9), fill: if i < 3 { luma(235) } else { luma(210) }, radius: 0.02)
  }
  cdraw.content((1.28, 7.3), [12345], size: 5.5pt)
  cdraw.content((2.80, 7.3), [678901234], size: 4.5pt)
  cdraw.content((4.32, 7.3), [567890123], size: 4.5pt)
  cdraw.content((13.4, 7.3), [9 dead slots], size: 6pt, fill: luma(100))
  cdraw.content((0.6, 6.0), [carry past limb 12 is dropped on the floor], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.6, 5.2), [zero: sign +1, n = 1], size: 6pt, anchor: "west", fill: luma(100))

  cdraw.content((9.6, 4.3), [ch14 core: dynamic, zero is sign +1, n = 0], size: 6.5pt)
  cdraw.rect((0.6, 1.4), (3.2, 2.8), fill: luma(225), radius: 0.02)
  cdraw.content((1.9, 2.35), [sign], size: 6pt)
  cdraw.content((1.9, 1.85), [+1], size: 6.5pt)
  cdraw.rect((3.5, 1.4), (5.2, 2.8), fill: luma(225), radius: 0.02)
  cdraw.content((4.35, 2.35), [n], size: 6pt)
  cdraw.content((4.35, 1.85), [3], size: 6.5pt)
  for (i, v) in ((5.5, [567890123]), (9.0, [678901234]), (12.5, [12345])) {
    cdraw.rect((i, 1.4), (i + 3.2, 2.8), fill: luma(242), radius: 0.02)
    cdraw.content((i + 1.6, 2.35), v, size: 4.5pt)
    cdraw.content((i + 1.6, 1.8), [limb], size: 5.5pt, fill: luma(100))
  }
  cdraw.line((15.9, 1.4), (15.9, 2.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((17.1, 1.4), (17.1, 2.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((18.1, 2.1), [grows], size: 6pt, fill: luma(100))
  cdraw.content((0.6, 0.5), [c caps the growth at BIG_MAX 4096 limbs, 36864 digits], size: 6pt, anchor: "west", fill: luma(100))
})

== karatsuba multiplication

Split both operands at m, half the larger limb count rounded down:
`a = a1 * B^m + a0` and `b = b1 * B^m + b0`. The product expands to
`a0*b0 + (a0*b1 + a1*b0) * B^m + a1*b1 * B^2m`, four half-size
multiplies in the schoolbook grid. Karatsuba's move computes the middle
term without ever forming its two pieces: `z0 = a0*b0`, `z2 = a1*b1`,
and `z1 = (a0+a1)*(b0+b1) - z0 - z2`, three multiplies where the grid
crosses four, and the recurrence `T(n) = 3T(n/2) + O(n)` lands at
n^1.585 against n^2. The operand sums cost one limb of headroom per
level, the recursion runs on magnitudes only with the sign applied
once at the end, and the base case falls back to schoolbook below
KARA_CUT limbs. The cut is a measured constant, not a constant of
nature, and section 6 retunes it per language: go and lua moved it,
the other four held the contract's 24. The C slice here is that base
case, the schoolbook every recursion bottoms out in.

The dry run: the C suite's carry stressor pins `(10^30 - 1) x (10^30 +
1) = 10^60 - 1` through `big_mul_kara`, sixty nines asserted by string
compare, one recursion level hand-derived here because the four-limb
pair rides the schoolbook base case under `KARA_CUT` 24, the recursion
itself pinned by the CUT-1, CUT, CUT+1 and ladder agreements.

+ The operands parse to 4 limbs each: a = 10^30 - 1 carries 999999999
  three times with top 999, b = 10^30 + 1 carries 1, 0, 0 with top 1000.
+ m = 4 / 2 = 2. The halves: a0 = 999999999 + 999999999 x 10^9 =
  10^18 - 1, a1 = 999999999 + 999 x 10^9 = 10^12 - 1, b0 = 1 + 0 = 1,
  b1 = 0 + 1000 x 10^9 = 10^12.
+ z2 = (10^12 - 1) x 10^12 = 10^24 - 10^12, and z0 =
  (10^18 - 1) x 1 = 10^18 - 1.
+ The sums cost their headroom: a0 + a1 = 10^18 + 10^12 - 2 and
  b0 + b1 = 10^12 + 1, so (a0 + a1) x (b0 + b1) = 10^30 + 10^24 +
  10^18 - 10^12 - 2.
+ z1 = 10^30 + 10^24 + 10^18 - 10^12 - 2 - (10^18 - 1) - (10^24 -
  10^12) = 10^30 - 1, one multiply covering the grid's two crossed
  products.
+ The recombination at offsets 2m, m, 0 telescopes: (10^24 - 10^12) x
  10^36 + (10^30 - 1) x 10^18 + (10^18 - 1) = 10^60 - 1.
+ The suite's compare reads sixty nines against the memset-built
  expectation, digit for digit.

#diagram([one level on the carry stressor, both operands cut at m = 2, three multiplies, the recombination telescoping to sixty nines], length: 12pt, {
  let bar = (y, t, lab) => {
    for (i, v) in t.enumerate() {
      cdraw.rect((0.6 + i * 2.2, y), (2.6 + i * 2.2, y + 1.0), fill: if i >= 2 { luma(225) } else { luma(242) }, radius: 0.02)
      cdraw.content((1.6 + i * 2.2, y + 0.5), v, size: 5.5pt)
    }
    cdraw.content((10.2, y + 0.5), lab, size: 6pt, anchor: "west")
  }
  cdraw.content((5.6, 9.2), [the cut at m = 2], size: 6.5pt)
  bar(7.6, ([999999999], [999999999], [999999999], [999]), [a = 10^30 - 1])
  bar(6.2, ([1], [0], [0], [1000]), [b = 10^30 + 1])
  cdraw.line((5.0, 7.6), (5.0, 6.2), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((0.6, 5.5), [high halves a1 = 10^12 - 1 and b1 = 10^12, low halves a0 = 10^18 - 1 and b0 = 1], size: 6pt, fill: luma(100))
  let box = (y, t) => {
    cdraw.rect((0.6, y), (6.6, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((3.6, y + 0.55), t, size: 6pt)
  }
  box(3.9, [z2 = 10^24 - 10^12, folded in at offset 2m = 4])
  box(2.5, [z1 = 10^30 - 1 after the subtraction chain, offset m = 2])
  box(1.1, [z0 = 10^18 - 1, offset 0])
  cdraw.content((7.4, 2.6), [the three terms telescope to 10^60 - 1,], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((7.4, 1.9), [sixty nines, the suite's pinned string], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((7.4, 0.9), [the pair itself rides the base case, cut 24], size: 6pt, anchor: "west")
})

The pinned sixty nines close the run, and the listings below build the
split and the recombination in seven languages.

#listing("icpc/samples-c/src/Ch14/ch14_bigint.h", first: 202, last: 229, caption: [c, the schoolbook base case on raw limb arrays, column accumulate in u64, carry written one limb past each row])

#listing("icpc/samples-c/src/Ch14/ch14_karatsuba.h", first: 12, last: 60, caption: [c, the karatsuba core, cut 24, depth-indexed static scratch, no malloc, the split with the z0 and z2 recursions, both operand sums costing a limb of headroom, the z1 chain and the offset add past the slice])

#listing("icpc/samples-go/ch14/karatsuba.go", first: 3, last: 37, caption: [go, the measured cut comment, the recursion, and magAddInto folding z2, z1, z0 back at offsets 2m, m, 0])

#listing("icpc/samples-java/src/Ch15/Karatsuba.java", first: 94, last: 137, caption: [java, cut 24 held, the recursion over arena windows travelling as array, offset, length triples, one shared scratch with offsets pushed and popped, zero allocation, the pieces folding back at offsets 2m, m, 0])

#listing("icpc/samples/src/Ch14/Karatsuba.cs", first: 10, last: 18, caption: [c\#, the split and the two half products, the z1 subtraction chain and the shift recombination follow in the same routine])

#listing("icpc/samples-js/src/ch14-karatsuba.mjs", first: 1, last: 43, caption: [javascript, the full recursion, recombination by pure limb addition through accum, exact in Number])

#listing("icpc/samples-py/src/Ch14/ch14_karatsuba.py", first: 17, last: 48, caption: [python, the pinned 40-digit operands beside the cut, the recursion with list-slice halves])

#listing("icpc/samples-lua/ch14_karatsuba.lua", first: 42, last: 75, caption: [lua, the recursion at cut 64, prefilled output so no nil hole survives the three offset adds, canonicalized against phantom top zeros])

The suites pin one 40-digit by 40-digit product against schoolbook and
the native oracle, python carrying the drawn operands
5916048252185557676338477592399929538048 and
7927103211688619806813789552134930986995, lua carrying the algebraic
twin `(10^40 - 1) * (10^40 + 1) = 10^80 - 1`, then all four sign
combinations, zero operands, the cut boundary at CUT-1, CUT, CUT+1
limbs, asymmetric pairs like 144 by 21, and the full ladder agreement
with schoolbook, lua extending its cross-check past its 89-limb
quadratic cap at 90, 92, 144, and 233 limbs. Two stream bugs became
warnings: javascript's `subMag` left phantom high zeros in karatsuba
returns, caught by an unbalanced-length sweep because the phantom limb
flipped a later comparison's operand order, and lua returned
unnormalized magnitudes from the same trap's other side, both fixed by
trimming before the value leaves the routine. Counts: C 79 checks,
javascript 6 tests, python 71 checks, lua 4 named checks.

#diagram([one karatsuba level: three half-size multiplies against the schoolbook grid's four crossed products], length: 12pt, {
  cdraw.content((4.8, 8.6), [a = a1 B^m + a0, b = b1 B^m + b0], size: 6.5pt)
  cdraw.rect((0.6, 6.9), (2.8, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((1.7, 7.4), [a1], size: 6.5pt)
  cdraw.rect((3.2, 6.9), (5.4, 7.9), fill: luma(245), radius: 0.02)
  cdraw.content((4.3, 7.4), [a0], size: 6.5pt)
  cdraw.content((4.3, 6.2), [m = max(la, lb) / 2, floored], size: 6pt, fill: luma(100))
  cdraw.rect((0.6, 4.6), (2.8, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((1.7, 5.1), [b1], size: 6.5pt)
  cdraw.rect((3.2, 4.6), (5.4, 5.6), fill: luma(245), radius: 0.02)
  cdraw.content((4.3, 5.1), [b0], size: 6.5pt)

  cdraw.line((4.3, 6.9), (7.6, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.3, 4.6), (7.6, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.5, 5.5), [a0 b0], size: 6pt, fill: luma(100))
  cdraw.rect((7.6, 3.1), (11.0, 4.3), fill: luma(225), radius: 0.02)
  cdraw.content((9.3, 3.95), [z0 = a0 b0], size: 6pt)
  cdraw.content((9.3, 3.45), [recurse], size: 6pt, fill: luma(100))

  cdraw.rect((7.6, 6.4), (11.0, 7.6), fill: luma(225), radius: 0.02)
  cdraw.content((9.3, 7.25), [z2 = a1 b1], size: 6pt)
  cdraw.content((9.3, 6.75), [recurse], size: 6pt, fill: luma(100))
  cdraw.line((1.7, 6.9), (7.6, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((1.7, 5.6), (7.6, 7.0), stroke: luma(100), mark: (end: ">"))

  cdraw.rect((7.6, 0.4), (11.0, 2.6), fill: luma(215), radius: 0.02)
  cdraw.content((9.3, 2.05), [z1 = (a0+a1)(b0+b1)], size: 6pt)
  cdraw.content((9.3, 1.55), [- z0 - z2], size: 6pt)
  cdraw.content((9.3, 0.85), [recurse], size: 6pt, fill: luma(100))
  cdraw.content((7.0, 4.9), [3 multiplies], size: 6.5pt, fill: luma(100), anchor: "east")

  let cell = (x, y, t, dim) => {
    cdraw.rect((x, y), (x + 2.3, y + 1.0), fill: if dim { luma(210) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 1.15, y + 0.5), t, size: 6pt)
  }
  cdraw.content((15.5, 7.6), [schoolbook grid: 4 products], size: 6.5pt)
  cell(13.0, 5.9, [a1 b1], false)
  cell(16.0, 5.9, [a1 b0], true)
  cell(13.0, 4.4, [a0 b1], true)
  cell(16.0, 4.4, [a0 b0], false)
  cdraw.content((13.0, 3.4), [the two crossed products each get their own], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((13.0, 2.7), [multiply, karatsuba recovers their sum], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((13.0, 2.0), [from one, (a0+a1)(b0+b1)], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.6, 0.4), [result = z2 B^2m + z1 B^m + z0, T(n) = 3T(n/2) + O(n)], size: 6pt, anchor: "west")
})

== exact ntt multiplication

The transforms want small limbs, so they regroup first: a base-1e4
limb is four decimal digits, every convolution column stays below
`n * 9999^2`, and the fft gets 14-bit inputs. Regrouping always hops
through the decimal string, `to_string` then four digits per limb
packed from the right, one rule in all seven languages: the hop is O(n)
against the transforms' O(n log n) and cannot drift a digit. The
transform length is the next power of two at or above la+lb, capped at
2^16 base-1e4 limbs, 262144 decimal digits for the pair, refused
loudly past it.

Exactness needs primes whose multiplicative group orders swallow that
length. `P1 = 998244353` factors as `P1 - 1 = 2^23 \* 119` with
primitive root 3, and `P2 = 754974721` factors as `P2 - 1 = 2^24 \* 45`
with root 11, so every power of two up to the cap divides both orders.
The transform itself is the iterative Cooley-Tukey shape, identical
control flow in all seven languages: bit-reversal permutation, then
doubling stages, the stage root by fast exponentiation and a running
power within the stage, the inverse the same routine on inverted roots
plus a scale by `pow(n, P-2, P)`. Each prime convolves the pair
independently, then the chinese remainder theorem folds them: `x = x1
+ P1 * t` with `t = ((x2 - x1) mod P2) * INV mod P2`, and INV, the
inverse of P1 mod P2, is pinned as `416537774`, the same digits in all
seven sources so no language drifts a constant, lua and java asserting
`(243269632 * INV) mod P2 = 1` outright. The combined modulus `P1*P2 =
753649251896000513` stays under 2^63 while the true column value tops
out at `n * 9999^2 = 6.55e12`, five orders of headroom, and that
headroom is what makes the strange paths exact: butterfly products are
a residue times a residue, `(P-1)^2 < 9.97e17`, inside signed 64-bit for
c, c\#, go, java, and lua's int64, trivially fine for python, and beyond
f64 precision in javascript, whose butterflies run on BigInt, the
reconstructed columns always under 6.6e12 and exact back on plain
arithmetic.

The dry run: the C suite pins the hand convolution 9999, 5926, 5358 by
3238, 4626 through `ntt_conv4`, asserting the five output limbs 6762,
6999, 9424, 584, 2479 with `lc = 5`.

+ Both operands are base-1e4 limbs already, la + lb = 5, so the
  transform runs at the next power of two, 8, one convolution per prime
  folded by the CRT with the pinned INV = 416537774.
+ The folded columns are the polynomial products: column 0 is
  9999 x 3238 = 32376762, column 1 is 9999 x 4626 + 5926 x 3238 =
  65443762, column 2 is 5926 x 4626 + 5358 x 3238 = 44762880, and
  column 3 is 5358 x 4626 = 24786108.
+ The carry pass walks little-endian: 32376762 = 3237 x 10^4 + 6762
  writes limb 6762, carrying 3237.
+ 65443762 + 3237 = 65446999 = 6544 x 10^4 + 6999 writes 6999,
  carrying 6544.
+ 44762880 + 6544 = 44769424 = 4476 x 10^4 + 9424 writes 9424,
  carrying 4476.
+ 24786108 + 4476 = 24790584 = 2479 x 10^4 + 584 writes 584, and the
  last carry stands alone as limb 2479, so `lc = 5`.

#table(
  columns: (auto, auto, 1.5fr, auto, auto),
  inset: 4pt,
  table.header([*j*], [*column + carry in*], [*split k x 10^4 + limb*], [*limb*], [*carry out*]),
  [0], [32376762], [3237 x 10^4 + 6762], [6762], [3237],
  [1], [65446999], [6544 x 10^4 + 6999], [6999], [6544],
  [2], [44769424], [4476 x 10^4 + 9424], [9424], [4476],
  [3], [24790584], [2479 x 10^4 + 584], [584], [2479],
  [4], [2479], [the final carry alone], [2479], [],
)

The five limbs are exactly what the CHECK lines read, and the listings
below run both primes and the fold in seven languages.

#listing("icpc/samples-c/src/Ch14/ch14_ntt.h", first: 41, last: 73, caption: [c, the iterative transform, bit reversal, doubling stages, stage root by powmod, running power, inverted roots plus the n^-1 scale])

#listing("icpc/samples-go/ch14/ntt.go", first: 63, last: 98, caption: [go, the same transform over uint64 butterflies, inverted roots for the inverse pass])

#listing("icpc/samples-java/src/Ch15/Ntt.java", first: 52, last: 87, caption: [java, the iterative transform over long butterflies, bit reversal, doubling stages, one root per stage by modpow, inverted roots plus the len^-1 scale])

#listing("icpc/samples/src/Ch14/NttMul.cs", first: 47, last: 60, caption: [c\#, one convolution per prime, the identical routine over P1 then P2, pointwise between the two transforms])

#listing("icpc/samples-js/src/ch14-ntt.mjs", first: 30, last: 56, caption: [javascript, the transform on BigInt, stated openly, exactness outranks speed here])

#listing("icpc/samples-py/src/Ch14/ch14_ntt.py", first: 70, last: 94, caption: [python, the wrapper, both primes, the CRT fold with the pinned INV, carry back to base 1e4])

#listing("icpc/samples-lua/ch14_ntt.lua", first: 95, last: 115, caption: [lua, the CRT reconstruction per column, x = x1 + P1*t inside int64, then the carry pass])

The pinned stressor is `(10^60 - 1) * (10^60 + 1) = 10^120 - 1`, every
digit a 9, with all four sign combinations, zero operands, the hand
convolutions `9999 * 9999 = 99980001` and a seam-crossing product, and
the ladder agreeing with schoolbook everywhere. The cap is tested at
the cap, not just past it: C\# squares 131072-digit operands in the
exact-at-cap fact, go runs n = 65536 exactly against `math/big`, and
java squares 80000 nines into 160000 digits at transform length 2^16
exactly.
Two stream bugs shaped the listings above. Go's CRT wrapped: P1
exceeds P2, so a residue above P2 made the subtraction `x2 - x1` go
negative in uint64, hidden below 89 limbs until a reproducer replayed
the lcg operands, fixed as `x2 + 2*P2 - x1`. C shipped its first
transform without the inverse pass before CRT, caught by the
stressor. Counts: C 83 checks, javascript 5 tests, python 59 checks,
lua 5 named checks.

#diagram([one butterfly over w^k, then the CRT fold: two prime residues rebuilt into one column under the 2^63 ceiling], length: 12pt, {
  cdraw.content((4.0, 8.6), [butterfly at stage length L], size: 6.5pt)
  cdraw.rect((0.8, 7.0), (2.8, 8.0), fill: luma(240), radius: 0.02)
  cdraw.content((1.8, 7.5), [u], size: 6.5pt)
  cdraw.rect((0.8, 5.2), (2.8, 6.2), fill: luma(240), radius: 0.02)
  cdraw.content((1.8, 5.7), [v], size: 6.5pt)
  cdraw.rect((4.6, 7.0), (7.6, 8.0), fill: luma(225), radius: 0.02)
  cdraw.content((6.1, 7.5), [u + w^k v], size: 6.5pt)
  cdraw.rect((4.6, 5.2), (7.6, 6.2), fill: luma(225), radius: 0.02)
  cdraw.content((6.1, 5.7), [u - w^k v], size: 6.5pt)
  cdraw.line((2.8, 7.7), (4.6, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.8, 5.9), (4.6, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.8, 5.5), (4.6, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.8, 7.3), (4.6, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.8, 6.9), [w^k], size: 6pt, fill: luma(100))
  cdraw.content((0.8, 4.9), [straight edges carry 1], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 4.35), [(P-1)^2 < 9.97e17, int64 product, js on BigInt], size: 6pt, anchor: "west", fill: luma(100))

  cdraw.content((14.0, 8.6), [crt reconstruction], size: 6.5pt)
  cdraw.rect((10.0, 6.9), (12.8, 7.9), fill: luma(240), radius: 0.02)
  cdraw.content((11.4, 7.5), [x1 mod P1], size: 6pt)
  cdraw.rect((14.6, 6.9), (17.4, 7.9), fill: luma(240), radius: 0.02)
  cdraw.content((16.0, 7.5), [x2 mod P2], size: 6pt)
  cdraw.rect((10.9, 4.7), (16.5, 5.9), fill: luma(225), radius: 0.02)
  cdraw.content((13.7, 5.55), [t = (x2 - x1) \* INV mod P2], size: 6pt)
  cdraw.content((13.7, 5.05), [INV = 416537774, pinned], size: 6pt, fill: luma(100))
  cdraw.line((11.4, 6.9), (11.4, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 6.9), (16.0, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.9, 2.6), (16.5, 3.8), fill: luma(215), radius: 0.02)
  cdraw.content((13.7, 3.45), [x = x1 + P1 t + carry], size: 6pt)
  cdraw.content((13.7, 2.95), [base-1e4 limb out], size: 6pt, fill: luma(100))
  cdraw.line((13.7, 4.7), (13.7, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.6, 8.4), (8.6, 2.0), stroke: luma(160))
  cdraw.rect((0.8, 0.5), (18.6, 2.0), fill: luma(248), radius: 0.02)
  cdraw.content((9.7, 1.6), [true column bound n \* 9999^2 = 6.55e12], size: 6pt)
  cdraw.content((9.7, 1.15), [combined modulus P1 \* P2 = 753649251896000513 < 2^63], size: 6pt)
  cdraw.content((9.7, 0.72), [five orders of headroom], size: 6pt, fill: luma(100))
})

== fft multiplication, plain and split

Complex fft trades exactness for speed and then earns the exactness
back with an error budget. Pack base-1e4 limbs into doubles, transform,
multiply pointwise, transform back, round. With unit roundoff
`u = 2^-53` and columns up to `(10^4 - 1)^2`, the plain path's drift
is bounded by `n * (10^4-1)^2 * (3*log2(n) + 4) * u`, which evaluates
to 0.0378 at n = 2^16. The split path is the main one: pack
`P[j] = a[j] + i*b[j]`, two 14-bit limbs riding one complex number
inside a 15-bit envelope, one forward transform, recover both spectra
by conjugate reversal, `Ahat[k] = (Phat[k] + conj(Phat[n-k])) / 2` and
`Bhat[k] = -i * (Phat[k] - conj(Phat[n-k])) / 2`, pointwise, one
inverse. Half the transforms, roughly half the error.

That budget assumed exact twiddles, and the pinned twiddle policy does
not buy them: one `cos(2*pi/L)` and one `sin(2*pi/L)` per stage form
the principal root, powers advance by repeated multiplication, the
inverse flips the imaginary sign, nothing else touches libm, fixed so
seven libms agree. Measured on full-range random limbs, max fractional
distance at transform 2^14, 2^15, 2^16:
javascript 0.049, 0.250, 0.334 on its draw, python 0.049, 0.261,
0.807 on a fresh seed, c 0.049, 0.262, 0.500, go 0.049, 0.270, 0.500,
java 0.0477, 0.2617, 0.500 under its pinned jdk 27,
c\# 0.048, 0.261, 0.500 split with plain within 0.001, and lua, probed
on worst-case all-9999 limbs, 0.191, 0.500, 0.500. Go ran the control
experiment: with twiddles computed directly per power, drift stays
under 0.0004 at the same sizes, which isolates the recurrence, not the
transform, as the cause.

#callout("verify", "the cap followed the measurement, not the plan", [
  The plan's 0.0378 at 2^16 was an 18x underestimate of what the
  pinned recurrence does, about 0.5 across languages at 2^16 where a
  half-integer distance means rounding can flip a limb. The ruling,
  identical in every language: both fft paths cap at transform 2^14,
  about 5x inside the 0.25 guard, rounding stays `floor(x + 0.5)`
  everywhere, never rint, and the guard stays the tripwire, a loud
  failure per language, c and java return a status, go error, c\#
  InvalidOperationException, javascript and python throw, lua
  `error()`. The loud 2^16 trip is pinned suite behavior, python
  asserting the throw on its fresh-seed probe, java the guard trip on
  its uncapped 2^16 probe, lua the cap refusal one
  doubling past the boundary product that passes exactly at the cap.
])

The dry run: the python suite pins the stressor `(10^100 - 1)^2`
through both paths against the constructed string of 99 nines, one 8,
99 zeros, one 1, and unit-tests the guard `_roundc` on 3.0, 2.76,
2.24, and the refusals, the C suite carrying the same stressor.

+ Regroup 100 nines into base-1e4 limbs: 100 / 4 = 25 limbs, every one
  9999, and la + lb = 50 puts the transform at the next power of two,
  64, far under the 2^14 cap.
+ The split path packs `P[j]` as 9999 + 9999i, and a square makes the
  two recovered spectra equal, so the pointwise stage squares each
  entry.
+ One inverse, then rounding under the guard: 2.76 rounds up to 3 at
  distance 0.24 and 2.24 down to 2 at the same distance, both inside
  the 0.25 band.
+ The refusals sit on the band's edge and past it: 2.25 and 2.75 at
  exactly 0.25, 0.5 at half a unit, all three loud.
+ The identity behind the fixture: (10^100 - 1)^2 = 10^200 - 2 x
  10^100 + 1.
+ The carry pass lands it as digits, 99 nines, one 8, 99 zeros, one 1,
  200 digits, both paths printing the same string.

#diagram([the split run on the stressor as a sequence, pack, one forward, recovery, square, one inverse, round under the guard, carry], length: 12pt, {
  let box = (x, y, w, t, f) => {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: if f { luma(225) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.content((9.8, 8.8), [a square, so both recovered spectra are equal], size: 6.5pt)
  box(0.6, 7.2, 3.2, [25 limbs, all 9999], false)
  box(4.4, 7.2, 3.6, [pack P\[j\] = 9999 + 9999i], true)
  box(8.6, 7.2, 3.0, [one forward], false)
  box(12.6, 7.2, 3.4, [recovery, A = B], false)
  box(0.6, 5.4, 3.2, [pointwise square], true)
  box(4.4, 5.4, 3.0, [one inverse], false)
  box(8.6, 5.4, 3.4, [floor(x + 0.5)], true)
  box(12.6, 5.4, 3.4, [carry, base 1e4], false)
  cdraw.line((3.8, 7.7), (4.4, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.0, 7.7), (8.6, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.6, 7.7), (12.6, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.3, 7.2), (14.3, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.6, 5.9), (12.0, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.6, 5.9), (7.4, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.4, 5.9), (3.8, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.6, 4.3), [the guard watches every rounded coefficient], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.6, 3.5), [2.24 to 2 and 2.76 to 3 pass at distance 0.24], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.6, 2.7), [2.25, 2.75, 0.5 refused loudly], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.6, 1.6), [the carry lands 99 nines, 8, 99 zeros, 1, both paths equal], size: 6.5pt, anchor: "west")
})

The 99 nines, one 8, 99 zeros, one 1 string is the suite's constructed
expectation, and the listings below carry both paths in seven languages.

#listing("icpc/samples-c/src/Ch14/ch14_fft.h", first: 33, last: 71, caption: [c, the hand-rolled cpx transform, one cos and one sin per stage, powers by repeated multiplication, the drift source in plain sight])

#listing("icpc/samples-go/ch14/fft.go", first: 53, last: 99, caption: [go, the split path, the packed spectrum recovered in one loop, the measured-cap comment at the head of the file])

#listing("icpc/samples-java/src/Ch15/Fft.java", first: 89, last: 123, caption: [java, the split path over plain double arrays, the cap refusal at the entry, pack, one forward, conjugate-reversal recovery staged through scratch, pointwise, one inverse])

#listing("icpc/samples/src/Ch14/FftMul.cs", first: 42, last: 67, caption: [c\#, the split path over native Complex, pack, one forward, conjugate-reversal recovery, pointwise, one inverse])

#listing("icpc/samples-js/src/ch14-fft.mjs", first: 121, last: 161, caption: [javascript, the capped split entry beside the uncapped raw hook the test pins use, then fftSplit on paired Float64Arrays with the recovery formulas at the seam])

#listing("icpc/samples-py/src/Ch14/ch14_fft.py", first: 96, last: 130, caption: [python, both paths, the plain two-transform multiply and the shared split spectrum with its conjugate reversal])

#listing("icpc/samples-lua/ch14_fft.lua", first: 68, last: 94, caption: [lua, the split branch of convolve, packed forward, conjugate-reversal recovery into four tables, coefficients returned with the max fractional distance for the caller's guard])

The stressor is `(10^100 - 1)^2 = 10^200 - 2*10^100 + 1`, both paths,
all sign combinations, zero operands, the rounding guard unit-tested on
exact integers, on values 0.24 below and 0.76 above the half, and on
the refusals at 0.5, 2.25, 2.75, then the ladder with both paths
agreeing with schoolbook, the four-way chain `schoolbook == karatsuba
== ntt == fft_split` on every ladder pair, and python's exactness
probe at 300 limbs against native integers. C's first fft padded zero
limbs into the packing and go's first version skipped the base-1e4
carry pass after rounding, both caught by the chain. Counts: C 461
checks, javascript 7 tests, python 165 checks, lua 4 named checks.

#diagram([measured fractional drift against the 0.25 guard and the 0.5 rounding cliff, the safe range shaded under the 2^14 cap], length: 12pt, {
  let x(t) = 2.5 + (calc.log(t, base: 2) - 12) * 4.0
  let ly(d) = 1.0 + (calc.log(d, base: 10) + 1.55) / 1.55 * 7.0
  cdraw.line((1.6, 1.0), (19.2, 1.0), stroke: luma(100))
  cdraw.line((1.6, 1.0), (1.6, 8.6), stroke: luma(100))
  for (t, lab) in ((4096, [2^12]), (16384, [2^14]), (65536, [2^16])) {
    cdraw.line((x(t), 0.7), (x(t), 1.15), stroke: luma(100))
    cdraw.content((x(t), 0.3), lab, size: 6pt)
  }
  cdraw.rect((1.7, 1.05), (x(16384), ly(0.25)), fill: luma(245), radius: 0.02)
  cdraw.line((1.6, ly(0.25)), (19.2, ly(0.25)), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((1.9, ly(0.25) + 0.18), [0.25 guard], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.line((1.6, ly(0.5)), (19.2, ly(0.5)), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.content((1.9, ly(0.5) + 0.18), [0.5, rounding flips], size: 6pt, anchor: "west", fill: luma(100))
  let bar(t, lo, hi) = {
    cdraw.line((x(t), ly(lo)), (x(t), ly(hi)), stroke: 2pt + luma(140))
    cdraw.circle((x(t), ly(lo)), radius: 0.14, fill: luma(225))
    cdraw.circle((x(t), ly(hi)), radius: 0.14, fill: luma(215))
  }
  bar(16384, 0.048, 0.191)
  bar(32768, 0.250, 0.500)
  bar(65536, 0.334, 0.807)
  cdraw.content((x(16384), ly(0.191) + 0.4), [2^14: 0.048 to 0.191], size: 6pt, anchor: "south")
  cdraw.content((x(16384) + 0.5, 3.3), [lua all-9s worst case], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((x(32768), ly(0.250) - 0.5), [2^15: 0.250 to 0.500], size: 6pt, anchor: "north")
  cdraw.content((x(65536), ly(0.807) + 0.4), [2^16: 0.334 to 0.807], size: 6pt, anchor: "south")
  cdraw.content((x(65536) - 0.5, 7.2), [py fresh seed], size: 6pt, anchor: "east", fill: luma(100))
  cdraw.circle((x(65536), ly(0.0378)), radius: 0.16, fill: luma(205))
  cdraw.content((x(65536) - 0.4, ly(0.0378) + 0.4), [derived 0.0378, exact twiddles], size: 6pt, anchor: "east")
  cdraw.content((1.6, 8.2), [vertical: log max fractional distance], size: 6pt, fill: luma(100))
  cdraw.content((1.9, 7.5), [shaded: under the guard, at or below the 2^14 cap], size: 6pt, fill: luma(100))
})

== long division, knuth algorithm d

One-limb divisors take the fast path, per-limb 64 over 32 division with
the remainder carried down, and everything else runs Knuth's algorithm
D over magnitudes. Normalize first, multiplying dividend and divisor
by `s = B / (v[n-1] + 1)` floored so the divisor's top limb reaches at
least B/2, the dividend buffer gaining one high sentinel limb.
Estimate each quotient digit two limbs over one: `qhat = (u[j+n]*B +
u[j+n-1]) / v[n-1]`, a numerator under 1e18 and inside 2^63 in plain
64/64 division, no 128-bit anywhere, clamp `qhat >= B` down to `B-1`,
then refine while `qhat * v[n-2] > rhat*B + u[j+n-2]`, at most two
decrements once the top limb is normalized. Multiply and subtract
`qhat * v` from the window with a 64-bit borrow chain, and if the
final borrow goes negative, qhat was one too large: decrement it and
add the divisor back once, Knuth's theorem bounding the correction to
a single add. The remainder is the window's low limbs divided by s
again. Every product in the loop stays under 1e18, under 2^60,
which is why C bans `__uint128_t` outright, grepping every commit for
it, javascript routes qhat and the mulsub products through BigInt, and
java holds every product in plain longs.
The signed wrapper truncates q toward zero and gives r the dividend's
sign, python computing its oracle by hand as `abs(a) // abs(b)` with
the sign pasted on, because native divmod floors. Zero divisors are
loud per language: C and java return a status, C\# throws
ArgumentOutOfRangeException, go returns an error, javascript RangeError,
python ZeroDivisionError, lua `error()`.

The dry run: the C suite's anchor fact walks `10^21 / 7`, asserting the
quotient string `142857142857142857142` and remainder 6.

+ 10^21 parses to 3 limbs, 0, 0, 1000 top, and 7 is one limb, so the
  fast path runs, 64 over 32 per limb, top down.
+ Top limb: cur = 0 x 10^9 + 1000 = 1000, quotient limb 1000 / 7 =
  142, remainder 1000 - 7 x 142 = 6.
+ Middle limb: cur = 6 x 10^9 + 0 = 6000000000, quotient limb
  6000000000 / 7 = 857142857, remainder 6000000000 - 7 x 857142857 =
  1.
+ Bottom limb: cur = 1 x 10^9 = 1000000000, quotient limb
  1000000000 / 7 = 142857142, remainder 1000000000 - 7 x 142857142 =
  6.
+ Printing pads below the bare top: 142, 857142857, 142857142
  concatenate to the 21-digit quotient, the remainder standing at 6.
+ The multi-limb side is quoted where the suite pins it, the add-back
  pair 7500000000000000000000000000 over 500000000000000000999999999
  landing quotient 14 and remainder 499999999999999986000000014.

#table(
  columns: (auto, auto, 1.5fr, auto, auto),
  inset: 4pt,
  table.header([*step*], [*limb*], [*cur = rem x 10^9 + limb*], [*out*], [*rem*]),
  [1], [1000], [0 x 10^9 + 1000 = 1000], [142], [6],
  [2], [0], [6 x 10^9 + 0 = 6000000000], [857142857], [1],
  [3], [0], [1 x 10^9 + 0 = 1000000000], [142857142], [6],
  [4], [print], [142, 857142857, 142857142], [142857142857142857142], [6],
)

The table's last row is what the two asserts read, and the listings
below run algorithm D in seven languages.

#listing("icpc/samples-c/src/Ch14/ch14_divmod.h", first: 52, last: 96, caption: [c, the full quotient loop, qhat estimate, clamp and refine, mulsub borrow, the single add-back, remainder descale])

#listing("icpc/samples-go/ch14/divmod.go", first: 47, last: 95, caption: [go, D1 through D8 annotated in place, int64 borrows, the add-back on a negative top with the dead slot normalized])

#listing("icpc/samples-java/src/Ch15/Divmod.java", first: 60, last: 100, caption: [java, the full quotient loop, qhat two-over-one in plain long division, clamp then refine, mulsub borrow chain, the counted add-back, remainder descale])

#listing("icpc/samples/src/Ch14/DivMod.cs", first: 43, last: 91, caption: [c\#, the same loop, clamp folded into the refinement condition, add-back restoring the window])

#listing("icpc/samples-js/src/ch14-divmod.mjs", first: 60, last: 98, caption: [javascript, qhat and mulsub on BigInt, floored-mod limb recovery, the add-back branch])

#listing("icpc/samples-py/src/Ch14/ch14_divmod.py", first: 48, last: 95, caption: [python, the algorithm with the ADDBACK counter beside the branch, remainder descaled by dividing by s])

#listing("icpc/samples-lua/ch14_divmod.lua", first: 66, last: 100, caption: [lua, the quotient loop with the Hacker's Delight floored-division borrow, add-back once on a negative top])

The anchors: `10^21 / 7` leaves quotient 142857142857142857142 and
remainder 6, the sign matrix over `(±123456789012345678901234,
±98765)` against the truncating oracle, zero dividend, `|b| > |a|`
giving q = 0 and r = a, one-limb divisors, power-of-base carries, and
the invariants `q*b + r == a` and `0 <= |r| < |b|` asserted on every
random ladder pair. The add-back branch is the part random testing
never reaches, so every language pins a constructed pair that forces
it: c uses `7500000000000000000000000000 / 500000000000000000999999999
= 14 r 499999999999999986000000014`, built analytically and
cross-verified over 250000 random divisions against a python algorithm
D simulation. C\# scoured for one, 3.2M random and 209k structured
divisions finding nothing, then found the family by exhaustive base-10
scan, `2*B^2 / (B^2+1)` and `3*B^2 / (B^2+1)`, the base-10 analog
200/101, and cobertura confirms the branch ran exactly twice. Go pins
`(10^27 + 2*10^17) / (5*10^26 + 10^17 + 123456789) = 1 r
500000000099999999876543211`, firing exactly once. Javascript lifts
1110/101 one digit per limb. Python's counter watches
`1500000000000000000000000000 / 500000000000000000001 = 2999999 r
499999999999997000001` walk the branch, and java counts its branch on
the same pair, the counter moving by exactly one. Lua derives its pair,
`999999998999999999000000001000000000 / (27 nines) = 999999998 r
999999999000000001999999998`, from the D = 0 escape of its two-limb
qhat test. Lua also owns the borrow lesson: a single conditional wrap
in mulsub is wrong when the difference dips below -BASE, fixed with
the Hacker's Delight floored-division borrow, limb from `t % BASE`,
borrow from `p//B - t//B`. Counts: C 180 checks, javascript 9 tests,
python 233 checks, lua 8 named checks.

#diagram([one quotient digit: normalize, estimate two-over-one, refine, multiply-subtract down the window, add back on the rare negative top], length: 12pt, {
  cdraw.content((7.2, 9.2), [u window over v at limb j], size: 6.5pt)
  let ucell = (x, t, f) => {
    cdraw.rect((x, 7.4), (x + 2.9, 8.4), fill: if f { luma(225) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 1.45, 7.9), t, size: 6pt)
  }
  ucell(0.8, [u\[j+n\]], true)
  ucell(4.05, [u\[j+n-1\]], true)
  ucell(7.3, [u\[j+n-2\]], false)
  ucell(10.55, [u\[j\]], false)
  cdraw.content((2.25, 8.75), [sentinel 0 or 1], size: 6pt, fill: luma(100))

  cdraw.rect((0.8, 5.4), (9.4, 6.6), fill: luma(248), radius: 0.02)
  cdraw.content((5.1, 6.2), [qhat = (u\[j+n\] B + u\[j+n-1\]) / v\[n-1\]], size: 6pt)
  cdraw.content((5.1, 5.7), [clamp to B-1, refine against v\[n-2\], twice max], size: 6pt, fill: luma(100))

  let vcell = (x, t, f) => {
    cdraw.rect((x, 3.4), (x + 2.9, 4.4), fill: if f { luma(215) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 1.45, 3.9), t, size: 6pt)
  }
  vcell(0.8, [v\[n-1\]], true)
  vcell(4.05, [v\[n-2\]], true)
  vcell(7.3, [v\[0\]], false)
  cdraw.content((10.9, 4.1), [s = B / (v\[n-1\]+1)], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((10.9, 3.4), [shifts v\[n-1\] to B/2 or above], size: 6pt, anchor: "west", fill: luma(100))

  cdraw.line((2.25, 7.4), (2.25, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.5, 7.4), (5.0, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.25, 4.4), (3.2, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.5, 4.4), (5.6, 5.4), stroke: luma(100), mark: (end: ">"))

  cdraw.line((10.2, 4.4), (9.8, 7.4), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.0, 6.35), [qhat \* v subtracted from the window,], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((11.0, 5.65), [borrow chains toward the sentinel], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((14.0, 7.9), [top below 0, rare], size: 6pt, fill: luma(100))
  cdraw.line((17.2, 7.4), (17.2, 2.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((13.2, 1.7), [add-back: qhat--, window += v, once], size: 6pt, anchor: "west")
  cdraw.content((0.8, 0.8), [remainder = low n limbs, divided by s], size: 6pt, anchor: "west", fill: luma(100))
})

== measured: four multipliers, seven languages

Measured 2026-09-19 on this machine, one bench per language, medians
over repeated runs on shared lcg operands, never inside `make verify`,
java's bench joining 2026-10-06.
Karatsuba crosses schoolbook at 16 limbs in C, 16 to 48 in python with
the clear win from 48 and 2.2x at 233, 28 in javascript, about 48 in
java with the clear win from 48, 48 to 64 in
C\# with the strict win at 64, 64 in go, first clear win 1.15x, 1.6x
at 128 limbs, 1.9x at 233, and 89 to 144 in lua. The cut moved where
the crossover said to: go swept 24/32/48/64 and retuned KARA_CUT from
24 to 48, fastest at 128 limbs and within noise of the best at 233,
and lua swept 24/32/48/64/96 and retuned 24 to 64, PUC lua's table
overhead punishing the recursion, cut 64 dominant at 613 against 781
microseconds over schoolbook at 144 limbs and 1375 against 1953 at
233. C held 24, its first karatsuba win at 16 limbs by a 10 percent
margin inside timer granularity, C\# held 24 on its 48-to-64
crossover, java held 24 on its clear-from-48 crossover,
javascript held 24, parity at 24 with the clear win from 28
at 0.183 against 0.247 milliseconds, a cold phantom at 24 that never
reproduced warm, python held 24. The transforms split by runtime: fft
split overtakes schoolbook at 13 limbs in C, about 55 in javascript,
about 233 in python at 8.48 against 8.81 milliseconds, and about 444
limbs, 4k digits, in lua, while C\#, go, and java keep the transforms
behind schoolbook through the 233-limb ladder, java at 6 to 46x
behind, narrowest at 233 limbs and widest at 55 on the quiet box,
regroup and allocation
overhead eating the asymptotics, so in go and java karatsuba is the
multiplier at ICPC scales. Lua caps its ladders at 89 limbs for the quadratic
checks and 233 for the transforms, and its digit-cap bench runs 1k,
4k, 16k digits:

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*digits*], [*schoolbook*], [*karatsuba*], [*ntt*], [*fft split*]),
  [1000], [0.43 ms], [0.41 ms], [1.22 ms], [1.06 ms],
  [4000], [7.56 ms], [3.94 ms], [5.13 ms], [3.50 ms],
  [16000], [113 ms], [37 ms], [23 ms], [21.5 ms],
)

#table(
  columns: (auto, auto, 1.1fr, 2.3fr),
  inset: 4pt,
  table.header([*language*], [*KARA_CUT*], [*crossover, limbs*], [*why the cut landed there*]),
  [c], [24, held], [16], [first win 10 percent inside timer granularity, the pinned constant stays],
  [go], [24 to 48], [64], [cut swept, 48 fastest at 128 limbs, within noise at 233],
  [java], [24, held], [about 48], [clear win from 48 limbs, the c\#/go class, transforms 6 to 46x behind schoolbook through the ladder, cut unchanged],
  [c\#], [24, held], [48 to 64], [noise boundary 24 to 48, strict win at 64, cut unchanged],
  [javascript], [24, held], [28], [parity at 24, clear win from 28, cold phantom not reproducible warm],
  [python], [24, held], [16 to 48], [clear win from 48, 2.2x at 233, cut unchanged],
  [lua], [24 to 64], [89 to 144], [table overhead punishes recursion, 64 dominant across the scan],
)

Each bench is a named invocation, none wired into verify: C runs the
ladder behind the `CH14_BENCH` environment variable, printing
`ok 1 bench gated` without it, C\# gates one fact the same way, go
exposes four `Benchmark` functions under `-bench`, javascript runs
`node src/ch14-bench.mjs` from outside the test glob, python's
`ch14_bench.py` unlocks the crossover scan and the ladder on `--bench`,
java's `Bench.java` keeps the runner-invoked run bare at 7 checks with
the crossover matrix and the four-multiplier ladder behind `--bench`,
and lua's `ch14_bench.lua` is manual and unlisted, the `ch10_pf_runs`
precedent.

#listing("icpc/samples-java/src/Ch15/Bench.java", first: 116, last: 138, caption: [java, the bare run a sanity chain over the pinned size-34 pair and the cut boundary, the crossover matrix and the four-multiplier ladder printing only behind the --bench flag])

The dry run: no suite carries the bench, the gates keep it out of every
verify run by design, so this walk reads the medians the lua digit-cap
bench printed on 2026-09-19, every ratio below derived in one step.

+ At 1k digits, about 112 limbs, karatsuba already leads schoolbook
  0.41 against 0.43 ms, ratio 0.43 / 0.41 = 1.05, inside the 89-to-144
  limb crossover window quoted above.
+ The lead compounds: 7.56 / 3.94 = 1.92 at 4k digits and 113 / 37 =
  3.05 at 16k.
+ Schoolbook's own climb from 1k to 16k, 16 times the digits, costs
  113 / 0.43 = 263 against the quadratic's 16^2 = 256, 3 percent
  over prediction.
+ Karatsuba climbs 37 / 0.41 = 90 over the same span against the
  recurrence's 16^1.585 = 81, 11 percent over.
+ The transforms pass everything at 16k, ntt at 23 and fft split at
  21.5 ms, factors 23 / 1.22 = 18.9 and 21.5 / 1.06 = 20.3 over their
  1k selves, between linear 16 and the n log n envelope.

#table(
  columns: (auto, auto, auto, auto, 1.7fr),
  inset: 4pt,
  table.header([*multiplier*], [*1k*], [*16k*], [*factor*], [*prediction*]),
  [schoolbook], [0.43 ms], [113 ms], [263], [16^2 = 256, quadratic],
  [karatsuba], [0.41 ms], [37 ms], [90], [16^1.585 = 81, the recurrence],
  [ntt], [1.22 ms], [23 ms], [18.9], [n log n, above linear 16],
  [fft split], [1.06 ms], [21.5 ms], [20.3], [n log n, above linear 16],
)

Every factor lands within 11 percent of its asymptote, and the
figure below charts the medians these ratios read.

#diagram([lua medians, log milliseconds: karatsuba passes schoolbook between 1k and 4k digits, the transforms take over by 16k], length: 12pt, {
  let xx(d) = if d == 1000 { 3.0 } else if d == 4000 { 9.5 } else { 16.0 }
  let yy(m) = 1.0 + (calc.log(m, base: 10) + 0.55) / 2.65 * 7.0
  cdraw.line((1.6, 1.0), (18.8, 1.0), stroke: luma(100))
  cdraw.line((1.6, 1.0), (1.6, 8.6), stroke: luma(100))
  for (d, lab) in ((1000, [1k digits]), (4000, [4k digits]), (16000, [16k digits])) {
    cdraw.line((xx(d), 0.7), (xx(d), 1.15), stroke: luma(100))
    cdraw.content((xx(d), 0.3), lab, size: 6pt)
  }
  for (m, lab) in ((1.0, [1]), (10.0, [10 ms])) {
    cdraw.line((1.35, yy(m)), (1.85, yy(m)), stroke: luma(100))
    cdraw.content((1.1, yy(m)), lab, size: 6pt, anchor: "east")
  }
  let series = (
    ([schoolbook], ((1000, 0.43), (4000, 7.56), (16000, 113.0)), luma(205)),
    ([karatsuba], ((1000, 0.41), (4000, 3.94), (16000, 37.0)), luma(225)),
    ([ntt], ((1000, 1.22), (4000, 5.13), (16000, 23.0)), luma(240)),
    ([fft split], ((1000, 1.06), (4000, 3.50), (16000, 21.5)), luma(252)),
  )
  let anchors = ((7.4, 6.4), (7.4, 5.5), (12.6, 3.2), (12.6, 2.3))
  for (i, s) in series.enumerate() {
    let (name, pts, fill) = s
    let prev = none
    for p in pts {
      let (d, m) = p
      if prev != none {
        cdraw.line((xx(prev.at(0)), yy(prev.at(1))), (xx(d), yy(m)), stroke: 1.4pt + luma(90))
      }
      cdraw.rect((xx(d) - 0.22, yy(m) - 0.22), (xx(d) + 0.22, yy(m) + 0.22), fill: fill, radius: 0.02)
      prev = p
    }
    let (ax, ay) = anchors.at(i)
    cdraw.rect((ax - 0.2, ay - 0.2), (ax + 0.2, ay + 0.2), fill: fill, radius: 0.02)
    cdraw.content((ax + 0.5, ay), name, size: 6pt, anchor: "west")
  }
  cdraw.content((2.5, yy(0.43)), [0.43], size: 6pt, anchor: "east")
  cdraw.content((9.0, yy(7.56) + 0.55), [7.56], size: 6pt, anchor: "east")
  cdraw.content((15.55, yy(113.0)), [113], size: 6pt, anchor: "east")
  cdraw.content((16.0, yy(21.5) - 0.55), [21.5], size: 6pt, anchor: "north")
  cdraw.content((1.6, 8.2), [vertical: log median milliseconds], size: 6pt, fill: luma(100))
})

== across the seven languages

Build size counts the implementation files each stream reported:

#table(
  columns: (auto, auto, 1.2fr, 2.6fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [842], [libc and libm only], [static arrays, no malloc, `__uint128_t` banned and grepped every commit, all products under 2^60],
  [go], [798], [stdlib, math/big oracle in tests], [errors carry the refusals, transforms stay behind schoolbook through 233 limbs, karatsuba owns ICPC scales],
  [java], [1530], [jdk 27 stdlib], [nested Big core over int limbs, arena windows as array, offset, length triples, BigInteger never appears, the dsa chapter 29 law],
  [c\#], [574], [bcl, System.Numerics], [sealed partial class split over five files, BigInteger oracle, one FftCap shared by both fft paths],
  [javascript], [604], [node stdlib, BigInt], [limbs as Number under 2^30, every exact limb product and every ntt butterfly on BigInt],
  [python], [958], [stdlib only], [native ints, the 4300-digit int-to-str guard lifted for the 300-limb oracle, truncating-sign oracle by hand],
  [lua], [911], [lib.lua harness], [integer tables, products under 2^63, worst-case all-9s probe validated the 2^14 cap with margin],
)

sources: Knuth, The Art of Computer Programming volume 2, sections
4.3.1 multiple-precision arithmetic and 4.3.3, algorithm D and the
fast multiplication survey, Karatsuba and Ofman, 1962, Cooley and
Tukey, 1965, and CLRS 3rd edition chapter 30 for the polynomial
multiplication framing. Native-library documentation: learn.microsoft.com
for `System.Numerics.BigInteger` and `System.Numerics.Complex`,
go.dev/pkg/math/big for the go oracle, developer.mozilla.org for BigInt
arithmetic, and docs.python.org for the int type and three-argument
`pow`, all accessed 2026-09-14. Benches run 2026-09-19, java's on
2026-10-06, medians quoted
from the seven streams' reports. Suite counts as measured: C 1041 checks
plus a 247-CHECK chain, 7 anchors and 240 ladder rows, C\# 29 facts
with the suite 278 of 278 green, go 1079 checks plus a 148-row chain,
java 889 checks across the six files of `samples-java/src/Ch15`,
Bigint 288, Karatsuba 77, Ntt 115, Divmod 232, Fft 170, and Bench 7
bare under `tools/run-java-samples.ps1`,
javascript 39 tests carrying 5941 instrumented assertions, python 825
checks plus a 52-check chain, 4 anchors and 48 ladder equalities, lua
28 named checks across five modules plus a 23-assertion chain, the run
suite 303 green from a 275 baseline at 0.42 seconds median. The java
tree numbers its chapter dir post-renumber, Ch15 matching the book's
chapter 15 while the six sibling trees keep their historical Ch14
dirs, and its file headers cross-cite the dsa chapter 29 bigint
family, the teaches-the-mechanism law that keeps BigInteger out of
every listing above.
