#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= fast big arithmetic

Chapter 2 multiplied digit strings by the schoolbook grid and chapter
16 squared numbers mod a prime. This chapter builds the whole ladder
above those floors, a dynamic bignum core, karatsuba's three-way
split, exact convolution through a two-prime number-theoretic
transform, complex fft with a measured drift cap, knuth's long
division, and polynomials over a transform-friendly prime. Every
constant quoted here, the two primes 998244353 and 754974721, the
inverse 416537774, the 2^14 fft cap, the per-language karatsuba cuts,
flows from the rulings of #xref-to("icpc", "fastarith"), the measured
contest companion whose benches this book does not repeat. The
fixtures are fresh and didactic, the work is counted rather than
timed, and all six languages pin the same digits.

== the dynamic bignum core

Everything above this section stands on one representation:
sign-magnitude over base 1e9, limbs stored least significant first.
Zero is the canonical pair of sign +1 and no limbs, normalize strips
high zero limbs and then fixes the sign, and a minus a collapses to
exactly that canonical zero instead of a negative empty list. Parse
cuts nine-digit chunks from the right of the digit string, accepts a
leading minus and nothing else, no plus sign, no leading zeros, no
minus zero, and print reverses the cut, the top limb bare and every
limb below it zero-padded to nine. Comparison reads sign, then limb
count, then limbs top-down, and addition and subtraction route across
signs by magnitude, equal signs add magnitudes, mixed signs subtract
the smaller from the larger and keep the larger's sign. The
schoolbook multiply rides along as the oracle, every later section
cross-checks its products against this one.

The dry run: the fixture is the add pair 1234567890123456789012345
and 987654321098765432109876, asserted by the C\# suite with the
sibling suites on the same digits.

+ Parse cuts the 25-digit operand from the right into three limbs,
  789012345, 890123456, 1234567 least significant first, and the
  24-digit one into 432109876, 321098765, 987654.
+ Limb 0 adds 789012345 + 432109876 = 1221122221, lands 221122221,
  carries 1.
+ Limb 1 folds the carry in, 890123456 + 321098765 + 1 = 1211222222,
  lands 211222222, carries 1 again.
+ Limb 2 closes 1234567 + 987654 + 1 = 2222222 with carry 0, and the
  headroom limb dies in normalize.
+ Print reverses the cut, the top limb bare and the rest padded to
  nine, reading 2222222, 211222222, 221122221 top down.
+ The carry chain runs the same fold one level up: 999999999 + 1 =
  1000000000 lands 0 and carries 1, three times over, finishing at
  limbs 0, 0, 0, 1.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*limb*], [*cur*], [*lands*], [*carry*]),
  [0], [789012345 + 432109876 = 1221122221], [221122221], [1],
  [1], [890123456 + 321098765 + 1 = 1211222222], [211222222], [1],
  [2], [1234567 + 987654 + 1 = 2222222], [2222222], [0],
)

The pinned sum 2222222211222222221122221 with the 0, 0, 0, 1 chain is
what the listings below build in six languages.

#listing("dsa/samples-c/src/Ch29/bigint.c", first: 31, last: 71, caption: [c, normalize then parse, chunks cut from the right, static limbs capped at 512])

#listing("dsa/samples/src/Ch29/BigNum.cs", first: 32, last: 63, caption: [c\#, Parse with the three refusals, limbs least significant first])

#listing("dsa/samples-go/ch29/bigint.go", first: 36, last: 83, caption: [go, normalize strips high zeros, ParseBig takes a leading minus only])

#listing("dsa/samples-js/src/ch29-bigint.mjs", first: 16, last: 43, caption: [javascript, normalize, parse, print, Number limbs with every exact product on BigInt])

#listing("dsa/samples-py/src/Ch29/bigint.py", first: 25, last: 72, caption: [python, parse, print, compare, and the carry add beneath])

#listing("dsa/samples-lua/ch29_bigint.lua", first: 12, last: 43, caption: [lua, the canonical zero, then parse cutting chunks from the right])

The integer roads: C keeps a static u32 limb array capped at 512
limbs, 4608 digits, with no allocation anywhere. JavaScript stores
limbs as Numbers but runs every exact limb product through BigInt,
because 999999999 squared passes 2^53. Lua keeps integer tables,
every schoolbook product 1e18 stays under 2^63. Fixtures pin the
round trip first: the 36-digit string
314159265358979323846264338327950288 parses to four limbs reading
327950288, 846264338, 358979323, 314159265 least significant first,
and prints back exactly. Then 2^100 =
1267650600228229401496703205376 with limbs 703205376, 229401496,
650600228, 1267, built by a hundred doublings in the languages that
do not exponentiate, and reduced mod 1000000007 to 976371285, the
same exponent chapter 16 pins from the other side. Arithmetic: 27
nines plus 1 runs the full carry chain into limbs 0, 0, 0, 1, the
pair 1234567890123456789012345 and 987654321098765432109876 adds to
2222222211222222221122221 and subtracts to
246913569024691356902469, a minus a canonicalizes to zero, and the
compare ladder on the pair returns 1, -1, 0. The oracle anchor:
987654321 squared is 975461057789971041, the schoolbook anchor
chapters 2 and 16 both pinned, re-pinned here as the reference every
multiply below must match. Parse refuses "-0", "007", and "+5"
through each language's refusal channel, and a zero multiplicand
returns zero. One finals solver in the corpus ever needed this
ladder, icpc 2018 problem C (book 10, chapter 9), whose cost
accumulator peaks at 2.5e17 past 2^53 and carries BigInt in
javascript, and the icpc book's chapter 14 owns that contest-suite
twin.

#diagram([the sign cell plus exactly the limbs it needs, the 36-digit fixture cut into four nine-digit chunks from the right], length: 13pt, {
  cdraw.content((1.2, 7.7), [parse cuts from the right], size: 6.5pt, anchor: "west")
  let groups = ([314159265], [358979323], [846264338], [327950288])
  for (i, g) in groups.enumerate() {
    let x = 1.2 + i * 2.7
    cdraw.rect((x, 6.3), (x + 2.6, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.3, 6.75), g, size: 7pt)
  }
  cdraw.content((13.0, 5.85), [the digit string, most significant first], size: 6pt, anchor: "west")
  // storage: sign cell plus limbs lsb first
  cdraw.rect((1.2, 3.9), (2.4, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((1.8, 4.35), [sign], size: 6.5pt)
  let limbs = ([327950288], [846264338], [358979323], [314159265])
  for (i, l) in limbs.enumerate() {
    let x = 2.6 + i * 2.7
    cdraw.rect((x, 3.9), (x + 2.6, 4.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.3, 4.35), l, size: 7pt)
    cdraw.content((x + 1.3, 3.55), [limb #i], size: 5.5pt)
  }
  // the chunks reverse: the most significant group lands in the top limb
  for i in range(4) {
    let gx = 1.2 + i * 2.7 + 1.3
    let lx = 2.6 + (3 - i) * 2.7 + 1.3
    cdraw.line((gx, 6.25), (lx, 4.85), stroke: (paint: luma(170), dash: "dashed"))
  }
  cdraw.content((11.5, 2.6), [zero: sign +1, no limbs], size: 6pt, anchor: "west")
  cdraw.content((11.5, 1.95), [a - a canonicalizes, never -0], size: 6pt, anchor: "west")
  cdraw.content((11.5, 1.3), [print: top limb bare, rest padded to nine], size: 6pt, anchor: "west")
  cdraw.content((11.5, 0.65), [compare: sign, then length, then limbs], size: 6pt, anchor: "west")
  cdraw.content((1.2, 2.6), [base 1e9, products 1e18 stay under 2^63], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.95), [js limb products on BigInt, past 2^53], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.3), [c: static array, 512 limbs, no malloc], size: 6pt, anchor: "west")
})

== karatsuba multiplication

Schoolbook spends la times lb limb multiplies because it computes all
four partial products of the halves. Karatsuba's move computes three.
Split both operands at m, half the larger length floored, into low
parts a0, b0 and high parts a1, b1. Then z0 is a0 times b0, z2 is a1
times b1, and the middle comes algebraically, z1 is (a0 + a1) times
(b0 + b1) minus z0 minus z2, one multiply replacing two. The three
products recombine by limb addition at offsets 0, m, and 2m, the base
case is schoolbook below the cut, and the sign applies once at the
end. The fresh teaching angle here is counted work: a counter ticks
one per scalar limb multiply in the base case, and the recursion
always calls (a0, b0), (a1, b1), and the two sums padded to max plus
one limb, the plus one being the carry headroom, so the count is a
pure function of operand length and cut, identical in every language
that shares a cut.

The dry run: the fixture is the pattern operand, limb 123456789
repeated k times, squared at k = 24, 48, and 96 under the 24 cut
shared by C, C\#, JavaScript, and Python, asserted by the C\# suite,
while Go walks its measured 48 cut and Lua its 64.

+ At k = 24 the operands sit exactly at the cut: one schoolbook leaf
  at 24 × 24 = 576, equal to the schoolbook square.
+ At k = 48 the split at m = 24 makes z0 and z2 leaves at 576 each,
  576 + 576 = 1152, and the middle recurses on the sums padded to 25
  limbs.
+ The 25-limb middle splits at m = 12: 12 × 12 = 144, 13 × 13 = 169,
  and the 14-limb sums leaf at 14 × 14 = 196, so the middle costs
  144 + 169 + 196 = 509 and the node lands 1152 + 509 = 1661 against
  schoolbook 48 × 48 = 2304.
+ At k = 96 the two 48-limb halves cost 1661 + 1661 = 3322, and the
  pinned 4941 leaves 4941 - 3322 = 1619 for the 49-limb middle
  recursion.
+ The counts sit under the squares everywhere past the cut, 1661
  against 2304 and 4941 against 96 × 96 = 9216.
+ The algebra checks the arithmetic beside the meter: (10^24 + 7) ×
  (10^24 - 7) = 10^48 - 49, forty-six nines then 51, matching the
  oracle above.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*limbs*], [*the recursion*], [*karatsuba*], [*schoolbook*]),
  [24], [one leaf, 24 × 24], [576], [576],
  [48], [576 + 576 + 509], [1661], [2304],
  [96], [1661 + 1661 + 1619], [4941], [9216],
)

The 4941 against 9216 at 96 limbs is the counted claim, and the
listings below tick the same counter in six languages.

#listing("dsa/samples-c/src/Ch29/karatsuba.c", first: 175, last: 215, caption: [c, the recursion over a static arena, three multiplies and the offset recombination])

#listing("dsa/samples/src/Ch29/Karatsuba.cs", first: 24, last: 63, caption: [c\#, Rec with padded sums, then Combine at offsets 0, m, 2m])

#listing("dsa/samples-go/ch29/karatsuba.go", first: 15, last: 57, caption: [go, the counted recursion, base case at go's measured cut of 48])

#listing("dsa/samples-js/src/ch29-karatsuba.mjs", first: 76, last: 102, caption: [javascript, karaRaw and combine, the counter ticking in the base case])

#listing("dsa/samples-py/src/Ch29/karatsuba.py", first: 86, last: 112, caption: [python, the recursion returning product and leaf-multiplies together])

#listing("dsa/samples-lua/ch29_karatsuba.lua", first: 85, last: 122, caption: [lua, split, pad the sums to max plus one, recurse, recombine])

The cuts are the icpc book's chapter 14 measured crossovers reused
without re-benching, 24 limbs for C, C\#, JavaScript, and Python, 48
for Go, 64 for Lua, and each language asserts its own cut's pinned
rows. At cut 24 the counts run (24, 576, 576), (48, 1661, 2304), and
(96, 4941, 9216) for limbs, karatsuba, schoolbook, go's cut 48 gives
(48, 2304, 2304), (96, 6485, 9216), and (144, 12031, 20736), and
lua's cut 64 gives (64, 4096, 4096) and (128, 11461, 16384). At the
cut karatsuba degenerates to schoolbook, one limb past it the count
already drops below the square, and at 96 limbs karatsuba spends 4941
against 9216. The algebraic identities pin the arithmetic:
(10^40 - 1)(10^40 + 1) is 10^80 - 1, eighty nines, and (10^24 +
7)(10^24 - 7) is 10^48 - 49. The cut boundary walks the pattern
operand, limb 123456789 repeated k times, squared at k one below, at,
and one above the cut: the square holds exactly 18k - 1 digits, 413,
431, 449 at the 24 cut, 845, 863, 881 at go's 48, 1133, 1151, 1169 at
lua's 64, and every square opens 15241578780673678546 and closes
20515622620750190521. A zero operand returns zero, the asymmetric 144
by 21 limb product equals schoolbook, and all four sign combinations
on +-(10^24 + 7) times +-(10^24 - 7) agree with the oracle, the sign
applied exactly once.

#diagram([the schoolbook grid needs four partial products, karatsuba needs three, the measured cuts beneath], length: 13pt, {
  cdraw.content((2.9, 7.7), [schoolbook: four], size: 6.5pt)
  let cells = ((1.6, 6.7, [a1 \* b1]), (4.2, 6.7, [a1 \* b0]), (1.6, 5.6, [a0 \* b1]), (4.2, 5.6, [a0 \* b0]))
  for (x, y, t) in cells {
    cdraw.rect((x, y - 0.4), (x + 2.2, y + 0.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.1, y), t, size: 6.5pt)
  }
  cdraw.content((2.9, 4.9), [4 muls at every node], size: 6pt)
  cdraw.content((9.6, 7.7), [karatsuba: three], size: 6.5pt)
  cdraw.rect((7.4, 6.3), (9.4, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((8.4, 6.7), [z2], size: 7pt)
  cdraw.content((8.4, 6.05), [a1 \* b1], size: 6pt)
  cdraw.rect((9.9, 6.3), (11.9, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((10.9, 6.7), [z0], size: 7pt)
  cdraw.content((10.9, 6.05), [a0 \* b0], size: 6pt)
  cdraw.rect((8.65, 4.9), (10.65, 5.7), fill: luma(205), radius: 0.02)
  cdraw.content((9.65, 5.3), [z1], size: 7pt)
  cdraw.content((9.65, 4.65), [(a0 + a1)(b0 + b1) - z0 - z2], size: 6pt)
  cdraw.line((8.4, 6.25), (9.4, 5.75), stroke: luma(170))
  cdraw.line((10.9, 6.25), (9.9, 5.75), stroke: luma(170))
  cdraw.content((15.3, 7.4), [recombine at offsets 2m, m, 0], size: 6pt, anchor: "west")
  cdraw.content((15.3, 6.7), [sign applied once, at the end], size: 6pt, anchor: "west")
  cdraw.content((15.3, 5.9), [the counted rows are pure functions], size: 6pt, anchor: "west")
  cdraw.content((15.3, 5.2), [of length and cut, the +1 limb is], size: 6pt, anchor: "west")
  cdraw.content((15.3, 4.75), [the sums' carry headroom], size: 6pt, anchor: "west")
  cdraw.content((1.6, 3.7), [cuts: c, c\#, js, py at 24 limbs, go 48, lua 64], size: 6pt, anchor: "west")
  cdraw.content((1.6, 3.05), [at 96 limbs: 4941 leaf muls against 9216], size: 6pt, anchor: "west")
  cdraw.content((1.6, 2.4), [O(n^1.585) against O(n^2)], size: 6pt, anchor: "west")
  cdraw.content((1.6, 1.75), [the base case counts la \* lb leaf multiplies], size: 6pt, anchor: "west")
})

== exact convolution with two primes

Multiplication is a convolution of limbs, and the
number-theoretic transform computes a convolution exactly, no
floating point anywhere. The operands regroup to base-1e4 limbs
through the decimal string, four digits per limb from the right, a
linear pass that cannot drift a digit. The transform runs over a
prime that admits power-of-two roots, and one prime is not enough:
the true column values of a convolution at these limb sizes pass the
product of two primes, so the suite transforms twice. P1 is
998244353 = 119 \* 2^23 + 1 with primitive root 3, P2 is 754974721 =
45 \* 2^24 + 1 with root 11, each column folds by t = (x2 + 2 P2 - x1)
times INV
mod P2 with INV = 416537774, and the exact value is x1 + P1 t. The
wrap-safe ordering, x2 plus twice P2 minus x1, keeps the difference
positive before the reduction, the lesson the icpc book's chapter 14
go stream paid for once. The transform itself is the iterative
cooley-tukey shape, a bit-reversal permutation then doubling stages,
one stage root by fast pow and running powers by repeated
multiplication inside the stage, the inverse through inverted roots
and the n^(-1) scale.

The dry run: the fixtures are the plain integer convolutions and the
stressor limb counts, asserted by the C\# suite with Python on the
same rows.

+ The walk convolves [1, 2, 3] with [4, 5, 6] column by column:
  column 0 is 1 × 4 = 4, column 1 is 1 × 5 + 2 × 4 = 5 + 8 = 13.
+ Column 2 folds the full diagonal, 1 × 6 + 2 × 5 + 3 × 4 = 6 + 10 +
  12 = 28, and the tail tapers, 2 × 6 + 3 × 5 = 12 + 15 = 27, then
  3 × 6 = 18.
+ No column reaches the base, so 4, 13, 28, 27, 18 are the answer
  themselves, what the transform must land exactly through both
  primes.
+ The stressor regroups through the decimal string: 10^48 + 7 becomes
  13 limbs [7, 0 eleven times, 1], 10^48 - 7 becomes 12 limbs [9993,
  9999 eleven times].
+ The transform length is the next power of two past 13 + 12 = 25,
  which is 32, far under the 2^16 cap.
+ The exact product lands at 10^96 - 49, ninety-four nines then 51,
  cross-checked against the 29.1 oracle.

#diagram([the limb-product grid folding along anti-diagonals into the five carry-free columns], length: 13pt, {
  let a = (1, 2, 3)
  let b = (4, 5, 6)
  for j in range(3) { cdraw.content((2.7 + j * 1.7, 7.7), [b#j = #(b.at(j))], size: 6pt) }
  for i in range(3) {
    cdraw.content((0.7, 6.55 - i * 1.1), [a#i = #(a.at(i))], size: 6pt)
    for j in range(3) {
      let x = 1.9 + j * 1.7
      let y = 6.0 - i * 1.1
      cdraw.rect((x, y), (x + 1.6, y + 1.0), fill: if i + j == 2 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.8, y + 0.5), [#(a.at(i) * b.at(j))], size: 6.5pt)
    }
  }
  cdraw.line((6.0, 6.5), (2.7, 4.3), stroke: (paint: luma(160), dash: "dashed"))
  let out = (4, 13, 28, 27, 18)
  for k in range(5) {
    cdraw.rect((1.9 + k * 1.7, 1.5), (3.5 + k * 1.7, 2.5), fill: if k == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.7 + k * 1.7, 2.0), [#out.at(k)], size: 6.5pt)
  }
  cdraw.content((0.7, 2.0), [column k], size: 6pt)
  cdraw.content((11.0, 6.4), [column k sums the diagonal i + j = k], size: 6pt)
  cdraw.content((11.0, 5.3), [k = 2: 6 + 10 + 12 = 28, shaded], size: 6pt)
  cdraw.content((11.0, 4.2), [no column reaches the base 1e4], size: 6pt)
  cdraw.content((11.0, 3.1), [stressor: 13 + 12 = 25 limbs, length 32], size: 6pt)
  cdraw.content((11.0, 2.0), [the product lands 10^96 - 49], size: 6pt)
})

10^96 - 49, ninety-four nines then 51, is the pinned product, and the
listings below fold it through both primes in six languages.

#listing("dsa/samples-c/src/Ch29/ntt.c", first: 43, last: 76, caption: [c, the iterative transform, bit reversal then doubling stages, butterflies inside u64])

#listing("dsa/samples/src/Ch29/Ntt.cs", first: 52, last: 85, caption: [c\#, the crt fold per column, then one prime's convolution driver])

#listing("dsa/samples-go/ch29/ntt.go", first: 37, last: 78, caption: [go, the transform, add-subtract butterflies staying inside int64])

#listing("dsa/samples-js/src/ch29-ntt.mjs", first: 31, last: 58, caption: [javascript, transform on BigInt, stated openly, one stage root by fast pow])

#listing("dsa/samples-py/src/Ch29/ntt.py", first: 52, last: 77, caption: [python, one convolution per prime, the wrap-safe crt fold at the bottom])

#listing("dsa/samples-lua/ch29_ntt.lua", first: 26, last: 59, caption: [lua, the transform over 1-based tables, powers by repeated multiply])

The butterfly arithmetic is where the languages split, and the note is
short: a residue product stays under (P-1)^2 < 9.97e17, inside signed
64 bits for C, C\#, Go, and Lua, while JavaScript runs the butterflies
on BigInt. The ceiling note: P1 times P2 is 753649251896000513,
under 2^63, and every true column value the fold rebuilds sits below
it. The transform length is the next power of two at or past la plus
lb, capped at 2^16 base-1e4 limbs, 262144 decimal digits for the
pair, with a loud refusal past the cap in every refusal channel.
Fixtures pin carry-free columns first, [1, 2, 3] convolved with [4,
5, 6] gives [4, 13, 28, 27, 18], the delta identity holds, and a
single column squares 9999 into 99980001. The bignum stressor: 10^48
+ 7 regroups to 13 limbs reading [7, 0 eleven times, 1], 10^48 - 7 to
12 limbs reading [9993, 9999 eleven times], the product pins 24 limbs
[9951, then 9999 twenty-three times], and the value is 10^96 - 49,
checked against the 29.1 schoolbook oracle. The INV contract asserts
243269632 times 416537774 equals 1 mod 754974721, the same constant
chapter 28's garner fixture cross-names. Zero convolves to zero, all
four sign combinations pin, the 29.2 pattern operands at k = 12 and
24 limbs match schoolbook digit for digit, a pair forcing transform
length 2^15 is accepted and one forcing 2^17 refused loudly.

#diagram([one butterfly over w^k beside the two-prime crt fold with INV = 416537774 pinned], length: 13pt, {
  cdraw.content((1.2, 7.7), [one butterfly], size: 6.5pt, anchor: "west")
  cdraw.content((2.4, 6.6), [a~k~], size: 7pt)
  cdraw.content((2.4, 4.6), [a~k+half~], size: 7pt)
  cdraw.circle((3.5, 5.6), radius: 0.38, stroke: luma(100))
  cdraw.content((3.5, 5.6), [w^k], size: 5.5pt)
  cdraw.line((2.8, 6.5), (3.25, 5.9), stroke: luma(100))
  cdraw.line((2.8, 4.7), (3.25, 5.3), stroke: luma(100))
  cdraw.line((3.9, 5.75), (4.9, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.9, 5.45), (4.9, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.6, 6.6), [a~k~ + v], size: 7pt)
  cdraw.content((5.6, 4.6), [a~k~ - v], size: 7pt)
  cdraw.content((3.6, 3.7), [add and subtract, one multiply], size: 6pt)
  // the crt fold
  cdraw.content((9.0, 7.7), [the crt fold, per column], size: 6.5pt, anchor: "west")
  cdraw.rect((9.0, 6.3), (11.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((10.1, 6.7), [x1 over P1], size: 6.5pt)
  cdraw.rect((12.0, 6.3), (14.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((13.1, 6.7), [x2 over P2], size: 6.5pt)
  cdraw.content((9.0, 5.4), [t = (x2 + 2 P2 - x1) \* INV mod P2], size: 6pt, anchor: "west")
  cdraw.content((9.0, 4.6), [x = x1 + P1 \* t], size: 6.5pt, anchor: "west")
  cdraw.content((9.0, 3.8), [INV = 416537774 = P1^(-1) mod P2], size: 6pt, anchor: "west")
  cdraw.content((9.0, 3.1), [P1 \* P2 = 753649251896000513 < 2^63], size: 6pt, anchor: "west")
  cdraw.content((9.0, 2.4), [butterflies < 9.97e17, signed 64], size: 6pt, anchor: "west")
  cdraw.content((9.0, 1.7), [js runs its butterflies on BigInt], size: 6pt, anchor: "west")
  cdraw.content((1.2, 2.6), [base 1e4 limbs, four digits each], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.95), [cap 2^16 limbs, 262144 digits], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.3), [refusal past the cap, every channel], size: 6pt, anchor: "west")
})

== complex fft, plain and split

The complex fft multiplies the same polynomials in floating point,
and the engineering is all in the rounding. Two paths run side by
side. The plain path transforms both operands forward, multiplies
pointwise, and transforms back, three transforms. The split path, the
headline, packs both operands into one complex array, P of j equals
a of j plus i times b of j, runs one forward transform, and recovers
both spectra from it by conjugate reversal, A-hat of k is P-hat of k
plus the conjugate of P-hat of n minus k over 2, and B-hat of k is
minus i times their difference over 2. Two transforms total. Every
coefficient rounds by floor of x plus 0.5, never a nearest-integer
builtin, and the guard refuses any value landing 0.25 or more from an
integer, the tripwire that turns silent drift into a loud error. The
transform cap is 2^14 points, pinned by the icpc book's chapter 14
drift measurement: 0.048 to 0.191 fractional distance at 2^14 against
0.334 to 0.807 at 2^16, so the cap sits about five times inside the
guard. The twiddle policy is the drift source in plain sight, one cos
and one sin per stage with powers by repeated multiplication.

The dry run: the fixtures are the rounding guard's unit values and
the stressor square, asserted by the C\# suite on both paths with the
sibling suites on the same digits.

+ The guard walks its policy first: exact 5.0 rounds to 5 unchanged,
  and 2.24 rounds down because floor(2.24 + 0.5) = 2.
+ 2.76 rounds up, floor(2.76 + 0.5) = 3, while 2.25 and 2.75 sit
  exactly 0.25 from an integer and 0.5 half a unit away, so all three
  refuse.
+ The stressor squares 10^50 - 3: the identity gives 10^100 - 6 ×
  10^50 + 9, digits 49 nines, a 4, 49 zeros, a closing 9.
+ The plain path transforms twice forward and once back; the split
  path packs a + i b into one array, recovers both spectra by
  conjugate reversal, and inverts once: two transforms.
+ Every coefficient of both paths lands inside the guard, rounds by
  floor(x + 0.5), and prints the same 100 digits.
+ At the cap exactly, 8192 limbs of 9999 square with 8192 + 8192 =
  16384 = 2^14 points, and one doubling past refuses on both paths.

#diagram([the stressor through both paths, three transforms against two, the guard at the shared exit], length: 13pt, {
  let box = (x, y, w, t, hot: false) => {
    cdraw.rect((x, y), (x + w, y + 0.85), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.425), t, size: 6pt)
  }
  let arrow = (x1, y, x2) => cdraw.line((x1, y), (x2, y), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.0, 7.5), [plain path: 3 transforms], size: 6.5pt)
  box(1.0, 5.9, 2.1, [fwd a]); arrow(3.1, 6.325, 3.5); box(3.5, 5.9, 2.1, [fwd b])
  arrow(5.6, 6.325, 6.0); box(6.0, 5.9, 2.3, [pointwise ×])
  arrow(8.3, 6.325, 8.7); box(8.7, 5.9, 2.1, [inverse])
  cdraw.content((1.0, 4.8), [split path: 2 transforms], size: 6.5pt)
  box(1.0, 3.2, 2.6, [pack a + i b], hot: true); arrow(3.6, 3.625, 4.0)
  box(4.0, 3.2, 2.1, [fwd once], hot: true); arrow(6.1, 3.625, 6.5)
  box(6.5, 3.2, 2.7, [conjugate split]); arrow(9.2, 3.625, 9.6)
  box(9.6, 3.2, 2.1, [inverse])
  box(1.0, 1.3, 5.6, [floor(x + 0.5), refuse at 0.25])
  arrow(6.6, 1.725, 7.0); box(7.0, 1.3, 7.0, [10^100 - 6 × 10^50 + 9, 100 digits], hot: true)
  cdraw.content((1.0, 0.2), [at the cap: 8192 + 8192 = 16384 = 2^14 points], size: 6pt)
  cdraw.content((16.6, 6.3), [plain: one spectrum per operand], size: 6pt)
  cdraw.content((16.6, 5.2), [split: one array, both spectra], size: 6pt)
  cdraw.content((16.6, 4.1), [recovered by conjugate reversal], size: 6pt)
  cdraw.content((16.6, 3.0), [the guard turns drift loud], size: 6pt)
  cdraw.content((16.6, 1.9), [the cap sits 5x inside it], size: 6pt)
})

The same 100 digits off both paths is the pinned stressor, and the
listings below run plain and split in six languages.

#listing("dsa/samples-c/src/Ch29/fft.c", first: 83, last: 119, caption: [c, the split branch, pack, one forward, spectra by conjugate reversal, one inverse])

#listing("dsa/samples/src/Ch29/Fft.cs", first: 62, last: 93, caption: [c\#, plain and split side by side, both spectra from conjugate partners])

#listing("dsa/samples-go/ch29/fft.go", first: 76, last: 121, caption: [go, both paths in one driver, the mirror index spelled out])

#listing("dsa/samples-js/src/ch29-fft.mjs", first: 70, last: 112, caption: [javascript, plain then split, the two recovery formulas on doubles])

#listing("dsa/samples-py/src/Ch29/fft.py", first: 83, last: 114, caption: [python, mul plain and mul split, guarded rounding at the end])

#listing("dsa/samples-lua/ch29_fft.lua", first: 73, last: 118, caption: [lua, plain and split on parallel re and im tables])

Fixtures pin the policy numbers as units first: exact integers round
unchanged, 2.24 rounds down and 2.76 rounds up, and 0.5, 2.25, and
2.75 all refuse, the last because a quarter-integer distance is
exactly the guard. The stressor runs on both paths and they agree
digit for digit: (10^50 - 3) squared is 10^100 - 6 times 10^50 + 9, all
four sign combinations pin, and zero operands return zero. At the cap
exactly, all-9999 base-1e4 operands of 8192 limbs each, 32768 digits
with la plus lb equal to 2^14, square to 10^65536 - 2 \* 10^32768 + 1
by identity, 65536 digits asserted by count and pattern, and one
doubling past the cap refuses loudly on both paths. JavaScript and
Lua ride plain double arrays and tables the whole way, which is the
point, the cap and the guard are what make doubles safe here, not a
wider type.

#diagram([measured fractional drift at 2^14, 2^15, 2^16 against the 0.25 guard and the 0.5 rounding cliff, the safe range shaded under the cap], length: 13pt, {
  let x = (t) => 1.4 + (calc.log(t, base: 2) - 12) * 2.5
  let ly = (v) => 7.0 - v * 5.2
  // shaded safe region under the cap
  cdraw.rect((1.3, ly(0.0)), (x(16384), ly(0.25)), fill: luma(245), radius: 0.02)
  cdraw.line((1.3, ly(0.5)), (12.4, ly(0.5)), stroke: luma(150))
  cdraw.content((1.5, ly(0.5) + 0.24), [0.5 cliff], size: 6pt, anchor: "west")
  cdraw.line((1.3, ly(0.25)), (12.4, ly(0.25)), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((1.5, ly(0.25) - 0.34), [0.25 guard], size: 6pt, anchor: "west")
  let bar = (t, lo, hi) => {
    cdraw.rect((x(t) - 0.55, ly(hi)), (x(t) + 0.55, ly(lo)), fill: luma(180), radius: 0.02)
  }
  bar(16384, 0.048, 0.191)
  bar(32768, 0.250, 0.500)
  bar(65536, 0.334, 0.807)
  for (t, lab) in ((4096, [2^12]), (16384, [2^14]), (32768, [2^15]), (65536, [2^16])) {
    cdraw.content((x(t), 7.45), lab, size: 6pt)
  }
  cdraw.content((x(16384), 7.0), [0.048 to 0.191], size: 6pt)
  cdraw.content((x(32768), 6.6), [0.250 to 0.500], size: 6pt)
  cdraw.content((x(65536), 7.0), [0.334 to 0.807], size: 6pt)
  cdraw.content((1.4, 0.6), [vertical: fractional distance from an integer], size: 6pt, anchor: "west")
  cdraw.content((1.4, -0.1), [shaded: under the guard, at or below the 2^14 cap], size: 6pt, anchor: "west")
  cdraw.content((13.4, 5.8), [ranges as measured by the], size: 6pt, anchor: "west")
  cdraw.content((13.4, 5.15), [icpc book's chapter 14 benches], size: 6pt, anchor: "west")
  cdraw.content((13.4, 4.3), [floor(x + 0.5), never rint], size: 6pt, anchor: "west")
  cdraw.content((13.4, 3.55), [split path: two transforms], size: 6pt, anchor: "west")
  cdraw.content((13.4, 2.8), [plain path: three transforms], size: 6pt, anchor: "west")
  cdraw.content((13.4, 1.95), [the cap sits about 5x inside], size: 6pt, anchor: "west")
  cdraw.content((13.4, 1.3), [the guard, one doubling refused], size: 6pt, anchor: "west")
})

== long division, knuth algorithm d

Division is the one operation where the schoolbook you learned by hand
is already the right algorithm, and knuth's algorithm D is that
algorithm made careful. A one-limb divisor takes the fast path, a
64-over-32 division walking down the limbs with the remainder carried
each step. Otherwise, on magnitudes: normalize both operands by s = B
over (v top + 1) so the divisor's top limb reaches B over 2, which
bounds the estimate, and give the dividend one sentinel limb of
headroom. Each quotient limb comes from the two-limbs-over-one
estimate, the top two window limbs over the divisor top, a numerator
under 1e18 that fits plain 64-bit division with no 128-bit help
anywhere, C bans `__uint128_t` by the icpc book's grep rule. Clamp the
estimate to B - 1, refine it against the divisor's second limb at
most twice, multiply and subtract down the window, and when the top
goes negative add the divisor back once, the branch decades of
implementations get wrong. The remainder descales by s, and the
signed wrapper truncates toward zero with the remainder carrying the
dividend's sign.

The dry run: the fixture is 10^30 over 23 on the one-limb fast path,
asserted by the C\# suite beside its 2^100 over 97 anchor, the
siblings pinning the same quotients.

+ 10^30 parses to four limbs reading 0, 0, 0, 1000 least significant
  first, the divisor 23 is a single limb, so the fast path walks the
  limbs top-down carrying the remainder.
+ Top limb: cur = 0 × 1e9 + 1000 = 1000, and 43 × 23 = 989, so the
  quotient limb is 43 with remainder 1000 - 989 = 11.
+ Next limb: cur = 11 × 1e9 + 0 = 11000000000, and 478260869 × 23 =
  10999999987, remainder 13.
+ Next limb: cur = 13 × 1e9 = 13000000000, and 565217391 × 23 =
  12999999993, remainder 7.
+ Last limb: cur = 7 × 1e9 = 7000000000, and 304347826 × 23 =
  6999999998, remainder 2, the pinned r.
+ The quotient prints top-down, 43 bare then three limbs padded to
  nine, 43478260869565217391304347826, and q × 23 + 2 rebuilds 10^30,
  the invariant every sign cell asserts.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*limb*], [*cur*], [*q limb*], [*q × 23*], [*r*]),
  [1000], [0 × 1e9 + 1000], [43], [989], [11],
  [0], [11000000000], [478260869], [10999999987], [13],
  [0], [13000000000], [565217391], [12999999993], [7],
  [0], [7000000000], [304347826], [6999999998], [2],
)

43478260869565217391304347826 with remainder 2 is the pinned pair,
and the listings below divide in six languages.

#listing("dsa/samples-c/src/Ch29/divmod.c", first: 200, last: 237, caption: [c, the quotient loop, estimate, clamp, refine, mulsub, the rare add-back])

#listing("dsa/samples/src/Ch29/DivMod.cs", first: 49, last: 87, caption: [c\#, the knuth D loop, rhat refinement, floor-dividing mulsub, add-back])

#listing("dsa/samples-go/ch29/divmod.go", first: 65, last: 107, caption: [go, the loop with the add-back branch restoring the window])

#listing("dsa/samples-js/src/ch29-divmod.mjs", first: 61, last: 104, caption: [javascript, estimate and mulsub through BigInt, add-back when the top goes negative])

#listing("dsa/samples-py/src/Ch29/divmod.py", first: 89, last: 120, caption: [python, the loop, the add-back, then the descale])

#listing("dsa/samples-lua/ch29_divmod.lua", first: 125, last: 157, caption: [lua, the loop over the sentinel-topped window, add-back last])

Fixtures pin the anchors: 2^100 over 97 gives quotient
13068562888950818572130960880 with remainder 16, and 10^30 over 23
gives quotient 43478260869565217391304347826 with remainder 2. The
sign matrix runs plus and minus 10^30 + 3 against plus and minus 10^15
+ 7, quotient 999999999999993 signed by the product of operand signs,
remainder 52 carrying the dividend's sign, and every cell asserts the
invariants, q times b plus r equals a with the remainder's magnitude
below the divisor's. The add-back families are the ones the icpc
book's chapter 14 C\# stream discovered by exhaustive base-10 scan,
cross-named here: 2 B^2 over B^2 + 1 gives quotient 1 with remainder
999999999999999999, and 3 B^2 over B^2 + 1 gives quotient 2 with
remainder 999999999999999998, both forcing the branch. A divisor
larger in magnitude than the dividend gives quotient 0 and remainder
the dividend, a zero dividend divides cleanly, and a zero divisor
refuses in every channel.

#diagram([one quotient digit of algorithm D, normalize, estimate two-over-one, refine, mulsub down the window, the rare add-back], length: 13pt, {
  cdraw.content((1.2, 7.7), [one quotient limb], size: 6.5pt, anchor: "west")
  // the divisor window
  cdraw.content((1.2, 6.9), [divisor v, top limb scaled to B/2 by s], size: 6pt, anchor: "west")
  for i in range(4) {
    let x = 1.2 + i * 1.0
    cdraw.rect((x, 5.8), (x + 0.9, 6.5), fill: if i == 3 { luma(205) } else { luma(235) }, radius: 0.02)
  }
  cdraw.content((5.4, 6.15), [v~n-1~], size: 6pt, anchor: "west")
  cdraw.content((7.2, 6.15), [v~n-2~], size: 6pt, anchor: "west")
  // the dividend window with sentinel
  for i in range(6) {
    let x = 1.2 + i * 1.0
    cdraw.rect((x, 4.3), (x + 0.9, 5.0), fill: if i >= 4 { luma(225) } else { luma(235) }, radius: 0.02)
  }
  cdraw.content((7.4, 4.65), [the window, plus one sentinel limb], size: 6pt, anchor: "west")
  cdraw.content((1.2, 3.7), [1 estimate: (u~j+n~ B + u~j+n-1~) / v~n-1~], size: 6pt, anchor: "west")
  cdraw.content((1.2, 3.0), [2 clamp to B - 1, then refine against v~n-2~], size: 6pt, anchor: "west")
  cdraw.content((1.2, 2.3), [3 mulsub: window minus qhat times v, borrow chain], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.6), [4 top negative: add v back once, qhat minus 1], size: 6pt, anchor: "west")
  cdraw.content((1.2, 0.9), [5 descale the remainder window by s], size: 6pt, anchor: "west")
  cdraw.content((11.8, 3.7), [numerator < 1e18, plain 64/64], size: 6pt, anchor: "west")
  cdraw.content((11.8, 3.0), [no 128-bit anywhere, c bans uint128], size: 6pt, anchor: "west")
  cdraw.content((11.8, 2.3), [refinement fires at most twice], size: 6pt, anchor: "west")
  cdraw.content((11.8, 1.6), [2 B^2 over B^2 + 1 forces add-back], size: 6pt, anchor: "west")
  cdraw.content((11.8, 0.9), [r carries the dividend's sign], size: 6pt, anchor: "west")
})

== polynomials over one prime

Coefficient vectors over F_998244353 close the chapter, because the
transform prime makes the polynomial ops ride the machinery above.
Multiply picks its road by size, schoolbook for the short and sparse,
the 29.3 transform once both operands reach 32 terms, dense and long.
Evaluation is horner at an arbitrary point, folding the coefficients
from the top. Interpolation is lagrange at n + 1 distinct points, no
more than 64 in the fixtures, built from prefix and suffix products,
the basis polynomial that vanishes at every node but x~i~ is the
product of (x - x~j~) over j below i times the product over j above
i, and each basis scales by the inverse of its denominator, O(n^2)
all in. Remainder mod a small polynomial is schoolbook long division,
killing the leading term until the degree drops below the divisor's.

The dry run: the fixtures are the eighth binomial row and the
quadratic interpolation family, asserted by the C\# suite with the
sibling suites on the same rows.

+ The row starts at 1 and multiplies (1 + x) eight times, each
  multiply adding neighbors: the seventh row 1, 7, 21, 35, 35, 21, 7,
  1 gives 1 + 7 = 8, 7 + 21 = 28, 21 + 35 = 56, 35 + 35 = 70,
  mirroring back down.
+ The eighth row reads 1, 8, 28, 56, 70, 56, 28, 8, 1, all below the
  modulus, exact over the integers.
+ Horner at 10 folds from the top: 1, then 18, 208, 2136, 21430,
  214356, 2143588, 21435888, 214358881, which is 11^8.
+ The quadratic family samples x^2 + 3x + 5 at 0 through 4 for 5, 9,
  15, 23, 33: first differences 4, 6, 8, 10, second difference 2
  throughout.
+ Lagrange over the five points returns the coefficients [5, 3, 1],
  and horner at 4 checks the round trip, 1 × 4 + 3 = 7 then 7 × 4 +
  5 = 33.
+ The remainder edge reads the algebra: x^3 = 1 mod x^2 + x + 1 and
  100 = 3 × 33 + 1, so x^100 + 1 reduces to x + 1.

#diagram([the row build adding neighbors into the eighth row, the horner chain at 10 beside it], length: 13pt, {
  let r7 = (1, 7, 21, 35, 35, 21, 7, 1)
  let r8 = (1, 8, 28, 56, 70, 56, 28, 8, 1)
  cdraw.content((0.9, 7.1), [row 7, multiplied by (1 + x)], size: 6pt)
  for (i, v) in r7.enumerate() {
    cdraw.rect((0.9 + i * 1.5, 5.7), (2.3 + i * 1.5, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((1.6 + i * 1.5, 6.1), [#v], size: 6pt)
  }
  for (i, v) in r8.enumerate() {
    cdraw.rect((0.15 + i * 1.5, 3.7), (1.55 + i * 1.5, 4.5), fill: if v == 70 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((0.85 + i * 1.5, 4.1), [#v], size: 6pt)
  }
  cdraw.content((0.15, 5.1), [row 8], size: 6pt)
  cdraw.line((4.6, 5.65), (5.1, 4.55), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((6.1, 5.65), (5.6, 4.55), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((7.3, 5.1), [21 + 35 = 56], size: 6pt)
  cdraw.content((15.0, 7.1), [neighbors sum, pascal's rule], size: 6pt)
  cdraw.content((15.0, 6.1), [every entry below the modulus], size: 6pt)
  cdraw.content((15.0, 5.1), [second difference 2: a quadratic], size: 6pt)
  cdraw.content((15.0, 4.1), [lagrange returns 5, 3, 1], size: 6pt)
  let chain = (1, 18, 208, 2136, 21430, 214356, 2143588, 21435888, 214358881)
  for (i, v) in chain.enumerate() {
    cdraw.content((0.4 + i * 2.6, 1.9), [#v], size: 6pt)
  }
  cdraw.content((0.4, 2.7), [each hop folds × 10 + the next coefficient], size: 6pt)
  cdraw.content((0.4, 0.8), [horner at 10 from the top coefficient], size: 6pt)
  cdraw.content((0.4, 0.0), [lands 11^8 = 214358881], size: 6pt)
})

The eighth row and the 214358881 are the pinned pair, and the
listings below fold all of it over one prime in six languages.

#listing("dsa/samples-c/src/Ch29/polyops.c", first: 125, last: 163, caption: [c, mul_lin builds (x - r), interp folds prefix times suffix over the denominator])

#listing("dsa/samples/src/Ch29/PolyOps.cs", first: 39, last: 64, caption: [c\#, Interpolate over prefix and suffix products, the vanishing basis])

#listing("dsa/samples-go/ch29/polyops.go", first: 59, last: 89, caption: [go, Interpolate with polyMulLin and the basis product])

#listing("dsa/samples-js/src/ch29-polyops.mjs", first: 99, last: 133, caption: [javascript, linMul then the lagrange fold, residues on BigInt])

#listing("dsa/samples-py/src/Ch29/polyops.py", first: 92, last: 114, caption: [python, lagrange by prefix and suffix products, O(n^2)])

#listing("dsa/samples-lua/ch29_polyops.lua", first: 91, last: 124, caption: [lua, the incremental numerator and the scaled accumulation])

The fixtures cross-name #xref-to("dsa", "combinatorics") for the
binomial machinery landing there: multiplying (1 + x) by itself eight
times pins the row 1, 8, 28, 56, 70, 56, 28, 8, 1, all below the
modulus, and horner at x = 10 returns 11^8 = 214358881. The
interpolation fixture: f of x = x^2 + 3x + 5 sampled at 0 through 4
gives the points 5, 9, 15, 23, 33, lagrange recovers the coefficient
list [5, 3, 1], and evaluating the result at 4 returns 33. The
remainder edge reads off the algebra: x^3 is 1 mod x^2 + x + 1 and
100 = 3 \* 33 + 1, so x^100 + 1 reduces to x + 1, coefficients [1,
1], asserted beside the division that produces it. Multiplying by [1]
is the identity. The dense check convolves (1..16) with itself, 31
coefficients peaking at 1240, plain integers below the modulus, and
the transform path equals schoolbook term for term. Every op
cross-checks against schoolbook at small sizes. The finals reality,
cross-named from the icpc book's chapter 14 opener, is that no finals
submission in the corpus needed this ladder, the education is the
point.

#diagram([lagrange basis polynomials as products of lines, each vanishing at all nodes but one, summing back to the coefficient list 5, 3, 1], length: 13pt, {
  // the node axis
  let nodes = (0, 1, 2, 3, 4)
  let nx = (v) => 1.6 + v * 1.55
  cdraw.line((1.3, 5.4), (9.5, 5.4), stroke: luma(100), mark: (end: ">"))
  for v in nodes {
    cdraw.circle((nx(v), 5.4), radius: 0.07, fill: luma(100))
    cdraw.content((nx(v), 5.75), [#v], size: 6pt)
  }
  cdraw.content((1.3, 6.15), [nodes 0 to 4, values 5, 9, 15, 23, 33], size: 6pt, anchor: "west")
  // basis i = 2: product of (x - x_j) for j != 2
  let by = (v) => 5.4 - (v + 1.6) * 0.62
  cdraw.content((1.3, 2.9), [basis for node 2:], size: 6pt, anchor: "west")
  cdraw.content((1.3, 2.25), [(x)(x - 1)(x - 3)(x - 4)], size: 6pt, anchor: "west")
  cdraw.content((1.3, 1.6), [denominator 2 \* 1 \* -1 \* -2 = 4], size: 6pt, anchor: "west")
  // zeros on the axis at 0,1,3,4; passes through 1 at x=2
  for v in (0, 1, 3, 4) {
    cdraw.circle((nx(v), by(0.0)), radius: 0.08, fill: none, stroke: luma(60))
  }
  cdraw.content((nx(2), by(1.0) + 0.28), [1], size: 6pt)
  cdraw.circle((nx(2), by(1.0)), radius: 0.08, fill: luma(60))
  // the normalized basis quartic: zeros at 0, 1, 3, 4, value 1 at 2
  let pts = ((nx(0), by(0.0)), (nx(0.5), by(-0.55)), (nx(1), by(0.0)), (nx(1.5), by(0.7)), (nx(2), by(1.0)), (nx(2.5), by(0.7)), (nx(3), by(0.0)), (nx(3.5), by(-0.55)), (nx(4), by(0.0)), (nx(4.4), by(1.1)))
  cdraw.line(..pts, stroke: luma(120))
  cdraw.content((11.0, 4.6), [each basis vanishes at every], size: 6pt, anchor: "west")
  cdraw.content((11.0, 3.95), [node but its own], size: 6pt, anchor: "west")
  cdraw.content((11.0, 3.1), [scale basis i by y~i~ over the], size: 6pt, anchor: "west")
  cdraw.content((11.0, 2.45), [denominator and sum: [5, 3, 1]], size: 6pt, anchor: "west")
  cdraw.content((11.0, 1.6), [eval at 4 returns 33], size: 6pt, anchor: "west")
  cdraw.content((11.0, 0.75), [n + 1 distinct points, n <= 64], size: 6pt, anchor: "west")
})

== across the six languages

Build size counts non-blank, non-comment lines over the chapter's
six sample files per language, embedded checks included:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [1603], [libc and libm], [static arrays throughout, 512-limb caps, no malloc, uint128 banned by the icpc ch14 grep rule, every divmod numerator under 1e18],
  [c\#], [718], [bcl, System.Numerics], [long limbs with (p-1)^2 inside signed 64, Complex for the fft, BigNum shared by every later file],
  [go], [811], [stdlib only], [one package over six files, errors carry the refusals, add-subtract butterflies stay inside int64],
  [javascript], [691], [node stdlib], [BigInt at each named boundary: exact limb products, ntt butterflies, qhat and mulsub, residue products],
  [python], [912], [stdlib only], [native ints, three-argument pow as the ground-truth cross-check, guards raise ValueError],
  [lua], [1046], [lib.lua harness], [integer tables with every product under 2^63, 1-based tables documented per file, error() carries refusals],
)

sources: the cp-algorithms articles, all cc by-sa 4.0, rewritten in
our own words, accessed 2026-09-20: "Arbitrary-Precision Arithmetic"
at cp-algorithms.com/algebra/big-integer.html for the 29.1 core and
the 29.2 multiplication treatment, "Fast Fourier transform" at
cp-algorithms.com/algebra/fft.html for its number theoretic transform
section behind 29.3 and the complex transform behind 29.4, and
"Operations on polynomials and series" at
cp-algorithms.com/algebra/polynomial.html for 29.6. Karatsuba cites
Karatsuba and Ofman, 1962, and division cites Knuth, The Art of
Computer Programming volume 2, section 4.3.1, algorithm D, both
exactly as the icpc book's chapter 14 sources row pins them. The
measured constants quoted in the text, the two primes, INV, the 2^14
drift cap with its ranges, and the karatsuba cuts, come from the
icpc book's chapter 14 benches run 2026-09-19, and icpc 2018 problem
C is named as the application. Sample behavior verified by the six
suite gates scoped to chapter 29: c 6 files and 123 checks, c\# 37
facts, go 19 tests, javascript 20 tests, python 6 files and 118
asserts, lua 24 checks, zero skipped. This chapter carries 36
listings and 9 figures.
