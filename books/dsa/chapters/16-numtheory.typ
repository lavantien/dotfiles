#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= number theory and modular arithmetic

The integer toolkit competitive and puzzle problems lean on: gcd and
lcm, the sieve, factorization, modular exponentiation and inverses,
and the chinese remainder theorem. Every algorithm here is a dozen
lines or less, and the chapter's real subject is the boundary each
language draws around its integers, because modular arithmetic is
exactly where silent overflow turns a right algorithm into a wrong
answer. Six suites, one pinned anchor per family, four different
roads through the multiplication problem.

== gcd, lcm, and the binary variant

Euclid's gcd replaces the pair (a, b) with (b, a mod b) until the
second slot hits zero, and the first is the answer. The remainder
shrinks strictly every step, so it always terminates, and the worst
case is consecutive fibonacci numbers. lcm must go through the gcd
with the division first, a divided by gcd then times b, because
multiplying first can overflow an intermediate that the final answer
never needed. Stein's binary variant needs no division at all: strip
the common factors of two, keep subtracting the smaller from the
larger, an odd minus an odd is even so more twos keep falling out,
then shift the saved twos back in.

The dry run: the fixtures are gcd(48, 18), the sign pair, and
lcm(4, 6), asserted by the C\# suite, Go cross-checks its binary
variant row by row, and C and Lua pin the 4 000 000 000 by
3 000 000 000 lcm through the divide-first formula.

+ Euclid stops at 6 on (48, 18), with the zero conventions beside
  it: gcd(0, 7) = 7 and gcd(0, 0) = 0, both pinned.
+ Signs fold in before the loop: gcd(-24, 36) enters as (24, 36)
  and leaves 12.
+ The lcm divides first: gcd(4, 6) = 2, then 4 / 2 = 2, and
  2 × 6 = 12, so the product in flight never reaches 4 × 6 = 24.
+ The binary variant saves the one common two: 48 >> 4 = 3 stands
  against 18 >> 1 = 9, both odd.
+ The subtract loop runs 9 - 3 = 6, halves to 3, and 3 - 3 = 0
  stops it on the core.
+ The saved two lands back, 3 << 1 = 6, and the sweep agrees with
  euclid everywhere C checks, both sides 0 through 40.

#diagram([the run as two pipelines, the lcm dividing before it multiplies, the binary variant subtracting to the odd core], length: 13pt, {
  // top lane: the divide-first lcm
  cdraw.content((6.8, 7.5), [lcm(4, 6): divide first], size: 6.5pt)
  let lsteps = ([gcd(4, 6) = 2], [4 / 2 = 2], [2 × 6 = 12])
  for (i, s) in lsteps.enumerate() {
    let x = 0.8 + i * 4.4
    cdraw.rect((x, 5.9), (x + 3.2, 6.8), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.6, 6.35), s, size: 6pt)
    if i < 2 { cdraw.line((x + 3.3, 6.35), (x + 4.3, 6.35), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((6.8, 5.0), [in flight: 2, never 4 × 6 = 24], size: 6pt)

  // bottom lane: the binary variant
  cdraw.content((9.8, 3.9), [binary gcd(48, 18): no division], size: 6.5pt)
  let bsteps = ([strip: 3, 9], [9 - 3 = 6], [6 >> 1 = 3], [3 - 3 = 0], [3 << 1 = 6])
  for (i, s) in bsteps.enumerate() {
    let x = 0.8 + i * 3.9
    cdraw.rect((x, 2.3), (x + 2.9, 3.2), fill: if i == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.45, 2.75), s, size: 6pt)
    if i < 4 { cdraw.line((x + 3.0, 2.75), (x + 3.8, 2.75), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((9.8, 1.4), [core 3, one two saved, shifted back], size: 6pt)
  cdraw.content((9.8, 0.4), [stein and euclid agree on every pair], size: 6pt)
})

The 6 and the divide-first 12 are the suite's pins, and the
listings below run both variants in six languages.

#listing("dsa/samples-c/src/Ch16/gcdlcm.c", first: 17, last: 59, caption: [c, euclid, stein, and the divide-first lcm over unsigned long long])

#listing("dsa/samples/src/Ch16/NumTheory.cs", first: 6, last: 39, caption: [c\#, sign-normalized gcd and lcm, trailing-zero binary gcd])

#listing("dsa/samples-go/ch16/gcdlcm.go", first: 6, last: 60, caption: [go, both gcd variants on int64, abs applied at the edges])

#listing("dsa/samples-js/src/ch16-gcdlcm.mjs", first: 6, last: 35, caption: [javascript, all BigInt, lcm products cross 2^53 early])

#listing("dsa/samples-py/src/Ch16/gcdlcm.py", first: 13, last: 46, caption: [python, divide-first lcm, halving in the subtract loop])

#listing("dsa/samples-lua/ch16_gcdlcm.lua", first: 6, last: 36, caption: [lua, integer division and shifts, no overflow at these sizes])

Every suite pins the same fixture family, gcd(48, 18) = 6, gcd(7,
13) = 1 on the coprime pair, and the zero conventions, gcd(0, n) = n
and gcd(0, 0) = 0. The binary variant is cross-checked against
euclid everywhere, over the shared fixtures and over a full sweep in
C, Lua, and Python. C and Lua pin lcm(4 000 000 000, 3 000 000 000)
recomputed through the divide-first formula, the case where
multiplying first would wrap. JavaScript runs the whole file on
BigInt for the same reason in the other direction, its comment pins
the boundary: lcm products cross 2^53 long before interesting
inputs.

#diagram([euclid walks the remainder chain, stein strips twos and subtracts, both land on 6 for 48 and 18], length: 13pt, {
  cdraw.content((5.6, 7.6), [euclid: the remainder chain], size: 6.5pt)
  let rows = ((48, 18), (18, 12), (12, 6), (6, 0))
  for (r, pair) in rows.enumerate() {
    let y = 6.3 - r * 1.0
    cdraw.rect((2.6, y - 0.3), (4.4, y + 0.3), fill: if r == 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.5, y), [#(pair.at(0)) #(pair.at(1))], size: 6pt)
    if r < 3 {
      cdraw.line((3.5, y - 0.3), (3.5, y - 0.7), stroke: luma(100), mark: (end: ">"))
      cdraw.content((4.9, y - 0.5), [#(pair.at(1)) mod #(pair.at(0))], size: 6pt)
    }
  }
  cdraw.content((5.6, 1.2), [b = 0: a is the gcd], size: 6pt)
  cdraw.content((5.6, 0.2), [worst case: fibonacci neighbors], size: 6pt)

  cdraw.content((17.0, 7.6), [stein: twos out, subtract, twos back], size: 6.5pt)
  let srows = ((48, 18, [strip 1 two]), (24, 9, [strip 1 two]), (12, 9, [strip 1 two]), (6, 9, [strip 1 two]), (3, 9, [odd: subtract]), (3, 3, [equal: stop]))
  for (r, row) in srows.enumerate() {
    let y = 6.5 - r * 0.95
    let (a, b, note) = row
    cdraw.rect((13.5, y - 0.28), (15.5, y + 0.28), fill: if r == 5 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((14.5, y), [#a #b], size: 6pt)
    cdraw.content((16.3, y), note, size: 6pt)
  }
  cdraw.content((17.0, 0.4), [3 shifted left 1 = 6, no division anywhere], size: 6pt)
})

== the sieve of eratosthenes

Cross off the multiples of every prime as it is found and whatever
survives is prime. The loop bound p squared is the whole argument: a
composite below p squared has a prime factor below p, so it was
already crossed off. Recording which prime does the crossing turns
the sieve into a smallest-prime-factor table, and that table is a
factorizer, divide it out repeatedly and the number peels into its
primes.

The dry run: the fixture is the limit 100, asserted by the C\#
suite on the count and the spf spot checks, and the siblings
split only on where the crossing starts, 2p against p squared.

+ Every flag opens true, then 0 and 1 close, and prime 2 starts
  crossing at 2 × 2 = 4, stepping by 2 through the evens.
+ The spf table fills in the same pass: 4 meets 2's run first and
  stamps it, spf[4] = 2, pinned.
+ Prime 3 starts at 3 × 3 = 9: 9 takes spf 3, and the evens keep
  the 2 they already carry.
+ Prime 5 starts at 5 × 5 = 25, prime 7 at 7 × 7 = 49, and 11
  never runs: 11 × 11 = 121 sits past 100, the loop bound.
+ 91 meets its crossing only at 7, as 7 × 13 = 91: composite with
  spf 7 despite looking prime, both pinned.
+ The survivors count 25, pi(100), and 97 closes the run keeping
  itself, spf[97] = 97.

#diagram([the crossing schedule in run order, each prime starting at its square, 11 stopped by the bound, spf stamped as each run passes], length: 13pt, {
  let runs = (
    ([p = 2], [starts 2 × 2 = 4], [evens stamp spf 2]),
    ([p = 3], [starts 3 × 3 = 9], [9 takes spf 3]),
    ([p = 5], [starts 5 × 5 = 25], [25 takes spf 5]),
    ([p = 7], [starts 7 × 7 = 49], [91 = 7 × 13 takes spf 7]),
    ([p = 11], [11 × 11 = 121 > 100], [the bound stops it]),
  )
  for (i, r) in runs.enumerate() {
    let y = 6.6 - i * 1.4
    cdraw.rect((0.8, y - 0.32), (1.8, y + 0.32), fill: if i == 4 { luma(248) } else { luma(235) }, stroke: if i == 4 { luma(160) }, radius: 0.02)
    cdraw.content((1.3, y), r.at(0), size: 6.5pt)
    cdraw.line((1.9, y), (2.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((2.7, y - 0.32), (6.3, y + 0.32), fill: luma(235), radius: 0.02)
    cdraw.content((4.5, y), r.at(1), size: 6pt)
    cdraw.content((8.3, y), r.at(2), size: 6pt)
  }
  cdraw.content((11.5, 6.6), [survivors to 100: 25, closing at 97], size: 6pt)
  cdraw.content((11.5, 5.2), [spf[97] = 97, a prime is its own], size: 6pt)
  cdraw.content((11.5, 3.8), [spf[1] = 1 by convention], size: 6pt)
  cdraw.content((11.5, 2.4), [the bound is the whole argument], size: 6pt)
})

The 25 with 91 stamped 7 is the pinned pair, and the listings
below sieve in six languages.

#listing("dsa/samples-c/src/Ch16/sieve.c", first: 16, last: 43, caption: [c, crossing from 2p so the spf table fills in the same pass])

#listing("dsa/samples/src/Ch16/NumTheory.cs", first: 52, last: 75, caption: [c\#, flags and spf together, primes stamped last])

#listing("dsa/samples-go/ch16/sieve.go", first: 3, last: 50, caption: [go, the p-squared sieve, then spf as a second recording])

#listing("dsa/samples-js/src/ch16-sieve.mjs", first: 8, last: 33, caption: [javascript, composite flags and the identity-init spf array])

#listing("dsa/samples-py/src/Ch16/sieve.py", first: 13, last: 39, caption: [python, the sieve, the prime list, spf defaulting to itself])

#listing("dsa/samples-lua/ch16_sieve.lua", first: 9, last: 34, caption: [lua, one table pass filling flags and spf together])

All six suites pin pi(100) = 25, the opening run 2, 3, 5, 7, the
close on 97, and that 91 is composite despite looking prime, it is 7
times 13. The crossing start splits by purpose: C and Lua walk
multiples from 2p because the spf table wants to catch every
composite with its smallest prime, C\# starts at p squared and still
fills spf in the same pass since every composite sits at or above
its smallest prime's square, while the pure primality sieves
in Go, JavaScript, and Python start at p squared and skip the work
below it, then record spf in a second pass when they record it at
all. Python peels factors straight off its spf table, the sieve as
factorizer, and the integer boundary is a non-event here: every
value sits at or below the limit, so even JavaScript stays on
Number.

#diagram([the sieve to 36, each prime crosses off from its square, spf remembers who did the crossing], length: 13pt, {
  let grid = (2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36)
  let prime = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31)
  for (i, v) in grid.enumerate() {
    let col = calc.rem(i, 9)
    let row = calc.floor(i / 9)
    let isp = v in prime
    cdraw.rect((1.2 + col * 1.55, 6.1 - row * 1.05), (2.6 + col * 1.55, 7.0 - row * 1.05), fill: if isp { luma(235) } else { luma(205) }, radius: 0.02)
    cdraw.content((1.9 + col * 1.55, 6.55 - row * 1.05), [#v], size: 6pt)
  }
  cdraw.content((7.5, 8.1), [shaded: crossed off, spf remembers the prime that did it], size: 6pt)
  cdraw.content((0.4, 6.55), [2 starts at 4, 3 at 9, 5 at 25], size: 6pt)
  cdraw.content((0.4, 5.5), [p^2: composites below it were claimed already], size: 6pt)
  cdraw.content((0.4, 4.4), [pi(100) = 25, closing prime 97], size: 6pt)
  cdraw.content((0.4, 3.3), [91 = 7 \* 13, the trap], size: 6pt)
})

== factorization by trial division

Trial division divides out each candidate as many times as it goes,
and the survivor past the square root of what remains is itself
prime, so 360 peels 2, 2, 2, 3, 3 and leaves 5.

The dry run: the fixtures are 360, 97, 1, and 1024, asserted by
the C\# suite, Python adds the survivor 999 983, and every suite
holding the expanded list rebuilds the input from it.

+ 360 peels under 2 three times: 360 / 2 = 180, 180 / 2 = 90,
  90 / 2 = 45, recording the pair (2, 3).
+ 45 refuses 2, so 3 runs: 45 / 3 = 15 and 15 / 3 = 5, the pair
  (3, 2).
+ The loop stops before 5 because 3 × 3 = 9 sits past the
  remainder, so the survivor appends itself as (5, 1).
+ The expanded list reads 2, 2, 2, 3, 3, 5, pinned, and the
  product rebuilds 360.
+ 1024 peels ten twos into the single pair (2, 10), 97 appends
  itself, and 1 appends nothing, all pinned.
+ Python's 999 983 rides the frontier to the end: 999 × 999 =
  998 001 still inside, 1000 × 1000 = 1 000 000 past it, and the
  survivor returns as (999 983, 1), a prime proven by exhaustion.

#diagram([the pairs landing in peel order beside the frontier, 360 stops early, 999 983 rides to the bound], length: 13pt, {
  // left: the recorded pairs
  cdraw.content((3.4, 7.4), [360 peels into pairs], size: 6.5pt)
  let pairs = (([(2, 3)], [three halvings]), ([(3, 2)], [two thirds]), ([(5, 1)], [the survivor]))
  for (i, p) in pairs.enumerate() {
    let x = 0.7 + i * 3.0
    cdraw.rect((x, 5.3), (x + 2.0, 6.2), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.0, 5.75), p.at(0), size: 6.5pt)
    cdraw.content((x + 1.0, 4.8), p.at(1), size: 6pt)
    if i < 2 { cdraw.line((x + 2.05, 5.75), (x + 2.95, 5.75), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((3.4, 3.7), [the loop stops when d × d passes the remainder], size: 6pt)

  // right: the frontier on 999 983, squares against the limit
  cdraw.content((13.3, 7.4), [999 983 rides the frontier], size: 6.5pt)
  cdraw.line((16.0, 4.6), (16.0, 6.7), stroke: luma(100))
  cdraw.content((16.0, 7.0), [999 983], size: 6pt)
  cdraw.rect((10.0, 5.7), (15.97, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((13.0, 5.95), [999 × 999 = 998 001, inside], size: 6pt)
  cdraw.rect((10.0, 4.8), (16.35, 5.3), fill: luma(248), stroke: luma(160), radius: 0.02)
  cdraw.content((13.2, 5.05), [1000 × 1000 = 1 000 000, past], size: 6pt)
  cdraw.content((13.3, 4.0), [the survivor appends itself, (999 983, 1)], size: 6pt)
  cdraw.content((13.3, 3.0), [the same stop at 3 × 3 = 9 > 5], size: 6pt)
  cdraw.content((13.3, 2.0), [1 factors to nothing, 97 to itself], size: 6pt)
})

The 2, 2, 2, 3, 3, 5 of 360 is the pinned peel, and the listings
below divide six ways.

#listing("dsa/samples-c/src/Ch16/factors.c", first: 20, last: 47, caption: [c, the (prime, exponent) pairs, then the expanded list])

#listing("dsa/samples/src/Ch16/NumTheory.cs", first: 77, last: 99, caption: [c\#, strip each prime, flatten to the sorted list])

#listing("dsa/samples-go/ch16/factors.go", first: 9, last: 41, caption: [go, trial division with the early stop, then the flat list])

#listing("dsa/samples-js/src/ch16-factors.mjs", first: 8, last: 28, caption: [javascript, pairs and list, everything under 2^53])

#listing("dsa/samples-py/src/Ch16/factors.py", first: 13, last: 31, caption: [python, odd divisors after 2, powers by counting])

#listing("dsa/samples-lua/ch16_factors.lua", first: 6, last: 24, caption: [lua, the peel loop, survivor prime appended])

The 360 anchor, three twos, two threes, one five, holds in every
suite, as do the boundary cases: a prime factors to itself, 1
factors to nothing, and 1024 is ten twos. The rebuild property,
multiplying the expanded list back into the input, is asserted
wherever the list exists. Python adds the discriminator between the
variants, 999 983 surviving trial division as a big prime, and
JavaScript's file carries the boundary comment: the loop stops at
the square root, so Number stays exact for these fixtures, and
reconstructed products in the tests stay below 2^53.

#diagram([360 peels under trial division, the survivor past the square root is prime], length: 13pt, {
  cdraw.content((8.5, 7.4), [360 = 2^3 \* 3^2 \* 5], size: 6.5pt)
  let steps = ((360, 2, 180), (180, 2, 90), (90, 2, 45), (45, 3, 15), (15, 3, 5), (5, 5, 1))
  for (r, s) in steps.enumerate() {
    let (x, d, y) = s
    let yy = 6.1 - r * 1.05
    cdraw.rect((5.6, yy - 0.3), (7.4, yy + 0.3), fill: luma(235), radius: 0.02)
    cdraw.content((6.5, yy), [#x], size: 6pt)
    cdraw.content((8.5, yy), [divide by #d], size: 6pt)
    cdraw.rect((10.6, yy - 0.3), (12.4, yy + 0.3), fill: if y == 1 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((11.5, yy), [#y], size: 6pt)
    cdraw.line((7.5, yy), (10.5, yy), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((15.3, 5.0), [the loop stops at sqrt], size: 6pt)
  cdraw.content((15.3, 3.9), [a survivor above it is prime], size: 6pt)
  cdraw.content((15.3, 2.8), [5 rides out unchanged], size: 6pt)
  cdraw.content((15.3, 1.7), [1 factors to nothing], size: 6pt)
  cdraw.content((15.3, 0.6), [1024 peels ten twos], size: 6pt)
})

== modular exponentiation

Square-and-multiply computes base to the exponent mod m by reading
the exponent in binary: square at every bit, multiply into the
result only when the bit is set, reduce after every operation. One
hundred multiplications collapse to seven squarings and three
multiplies, and the anchor lands everywhere: 2^100 mod 1e9+7 is
976371285 in all six suites. The chapter's hard problem is hiding
inside that innocent sentence, because squaring a residue near 1e9
makes a product near 1e18, and every language draws its own line
there.

The dry run: the anchor is 2^100 mod 1e9+7 = 976371285, pinned by
all six suites, the ladder walks C's small pin 3^4 mod 10^6 = 81,
and the identity family is the C\# suite's.

+ The exponent reads in binary from the bottom: 4 is 100, one set
  bit at the top, two clear bits below it.
+ Two clear bits mean two bare squarings: the base runs 3 × 3 = 9,
  then 9 × 9 = 81.
+ The set bit multiplies, 1 × 81 = 81, the pinned answer, then the
  loop squares once more into 81 × 81 = 6561 and stops.
+ The same machine at 2^100 costs 7 squarings and 3 multiplies,
  every product reduced in flight, and lands 976371285 everywhere.
+ The identity family: exponent 0 returns 1, exponent 1 the base,
  and modulus 1 collapses even 5^10 to 0.
+ The wrap story C and Lua share: 10^9 sits at -7 mod the prime,
  so 6e9 sits at 6 × (-7) = -42, and (-42) × (-42) = 1764, the
  pinned mulmod.

#diagram([the ladder on 3^4, one frame per exponent bit, every frame squares, only the set bit multiplies], length: 13pt, {
  let frames = (
    ([bit 0 = 0], [square: 3 × 3 = 9], [no multiply]),
    ([bit 1 = 0], [square: 9 × 9 = 81], [no multiply]),
    ([bit 2 = 1], [multiply: 1 × 81 = 81], [square: 81 × 81 = 6561]),
  )
  for (i, f) in frames.enumerate() {
    let x = 0.7 + i * 5.5
    cdraw.content((x + 2.25, 7.4), f.at(0), size: 6.5pt)
    cdraw.rect((x + 0.2, 5.3), (x + 4.3, 6.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.25, 5.7), f.at(1), size: 6pt)
    cdraw.rect((x + 0.2, 4.2), (x + 4.3, 5.0), fill: if i == 2 { luma(205) } else { luma(248) }, stroke: luma(180), radius: 0.02)
    cdraw.content((x + 2.25, 4.6), f.at(2), size: 6pt)
    if i < 2 { cdraw.line((x + 4.4, 5.7), (x + 5.4, 5.7), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((7.2, 3.2), [3^4 mod 10^6 = 81, three loop turns], size: 6pt)
  cdraw.content((7.2, 2.2), [the machine at 2^100: 7 squarings, 3 multiplies], size: 6pt)
  cdraw.content((7.2, 1.2), [reduce after every operation], size: 6pt)
  cdraw.content((7.2, 0.2), [6e9 × 6e9 lands 1764 via -42], size: 6pt)
})

The 976371285, pinned six times over, is the chapter's anchor
number, and the listings below climb the ladder six ways.

#listing("dsa/samples-c/src/Ch16/modpow.c", first: 21, last: 48, caption: [c, mulmod by add-and-double after the `__uint128` link failure])

#listing("dsa/samples/src/Ch16/NumTheory.cs", first: 101, last: 123, caption: [c\#, plain long products, modulus ceiling stated in the contract])

#listing("dsa/samples-go/ch16/modpow.go", first: 5, last: 31, caption: [go, the 128-bit product from bits.Mul64, bits.Div64])

#listing("dsa/samples-js/src/ch16-modpow.mjs", first: 6, last: 16, caption: [javascript, everything BigInt, exact and unbounded])

#listing("dsa/samples-py/src/Ch16/modpow.py", first: 13, last: 21, caption: [python, nine lines, the built-in pow as ground truth])

#listing("dsa/samples-lua/ch16_modpow.lua", first: 11, last: 38, caption: [lua, the wrap proof beside the doubling mulmod])

#callout("warning", "four roads through one multiplication", [
  C probed `__uint128_t` first: it compiles, but the link step needs
  compiler-rt's `__umodti3` helper for a 128-bit remainder and this
  toolchain does not ship it, so the landed mulmod adds and doubles
  with a remainder after every step and no product of two 64-bit
  values ever forms. Go gets the same 128 bits as a first-class
  operation, `math/bits.Mul64` hands back the high and low words and
  `bits.Div64` reduces them. C\# states a precondition instead: the
  modulus stays at or below 3 037 000 499, the square root of the
  `long` range, so residue products always fit. JavaScript and Lua
  sit at the extremes, one escapes to BigInt, the other proves
  `math.maxinteger * 2 == -2` in a test and then never multiplies
  two big values again.
])

Every suite also pins the identity family, exponent zero gives 1,
exponent one gives the base, modulus 1 collapses everything to 0,
and Fermat's little theorem, 2 to the 1e9+6 is 1 mod 1e9+7. C and
Lua share one more fixture worth reading: 6e9 times 6e9 wraps any
64-bit product, but since 1e9 is congruent to minus 7 mod 1e9+7, the
reduced answer is 36 times 49, which is 1764, and the add-and-double
mulmod lands it. Python cross-checks the whole sweep against the
built-in three-argument `pow`, the ground-truth move that language
allows.

#diagram([square and multiply on 2^100, seven squarings, three multiplies, every product reduced], length: 13pt, {
  cdraw.content((9.0, 7.5), [the exponent in binary drives the ladder], size: 6.5pt)
  let bits = ("1", "1", "0", "0", "1", "0", "0")
  for (i, b) in bits.enumerate() {
    cdraw.rect((11.8 - i * 0.8, 6.1), (12.6 - i * 0.8, 6.9), fill: if b == "1" { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((12.2 - i * 0.8, 6.5), [#b], size: 6pt)
  }
  cdraw.content((9.6, 6.5), [100 =], size: 6pt)
  cdraw.content((5.4, 6.5), [set bits multiply, clear bits only square], size: 6pt)
  let ladder = (([2], [square]), ([4], [square]), ([16], [square]), ([256], [square]), ([65536], [square]), ([2^32], [square]), ([2^64], [square]))
  let vals = ([2], [4], [16], [256], [65536], [2^32], [2^64])
  let mult = ((0, [x2]), (2, [x2^32]), (6, [x2^64]))
  for (i, v) in vals.enumerate() {
    let y = 5.0 - i * 0.72
    cdraw.rect((4.6, y - 0.26), (6.4, y + 0.26), fill: luma(235), radius: 0.02)
    cdraw.content((5.5, y), v, size: 6pt)
    if i < 6 { cdraw.line((5.5, y - 0.26), (5.5, y - 0.46), stroke: luma(100), mark: (end: ">")) }
  }
  for m in mult {
    let (i, lab) = m
    cdraw.content((7.3, 5.0 - i * 0.72), lab, size: 6pt)
  }
  cdraw.content((4.0, 0.1), [reduce mod 1e9+7 after every op], size: 6pt)
  cdraw.content((13.6, 5.2), [2^100 mod 1e9+7], size: 6pt)
  cdraw.content((13.6, 4.1), [\= 976371285], size: 6.5pt)
  cdraw.content((13.6, 3.0), [7 squarings, 3 multiplies], size: 6pt)
  cdraw.content((13.6, 1.9), [a residue near 1e9 squares], size: 6pt)
  cdraw.content((13.6, 0.8), [to 1e18: the mulmod question], size: 6pt)
})

== modular inverses

Division mod m is multiplication by the inverse, and the inverse
exists exactly when a and m share no factor. Two roads compute it:
Fermat's little theorem, a to the p minus 2 mod a prime p, and the
extended euclidean algorithm, which works for any coprime modulus
and hands back the Bezout coefficients as a bonus, a times x plus m
times k equals 1 means a times x is 1 mod m.

The dry run: the fixtures are the small inverses asserted by the
C\# suite, 3 to 4 mod 11, 10 to 12 mod 17, 7 to 15 mod 26, the big
inverse 333333336 pinned by Lua, and C pins the bezout bonus on
(240, 46).

+ The check is multiply back to 1: 3 × 4 = 12, and 12 - 11 = 1
  mod 11.
+ 10 × 12 = 120, and 120 - 119 = 1 mod 17, with 7 × 17 = 119.
+ 7 × 15 = 105, and 105 - 104 = 1 mod 26, with 4 × 26 = 104.
+ The bezout bonus: C reads x = -9 and y = 47 off (240, 46), with
  240 × (-9) + 46 × 47 = 2, the gcd.
+ The big inverse: 3 × 333333336 = 1000000008, and 1000000008 -
  1000000007 = 1, Lua's pin multiplied back.
+ The guard fires first: gcd(6, 9) = 3, so 6 has no inverse mod 9,
  and the six refusal channels all answer before any arithmetic.

#diagram([four multiply-backs in run order, every inverse times its base landing on 1 over its modulus], length: 13pt, {
  let rows = (
    ([mod 11], [3 × 4 = 12], [12 - 11 = 1]),
    ([mod 17], [10 × 12 = 120], [120 - 119 = 1]),
    ([mod 26], [7 × 15 = 105], [105 - 104 = 1]),
    ([mod 1e9+7], [3 × 333333336], [1000000008 - 1000000007 = 1]),
  )
  for (i, r) in rows.enumerate() {
    let y = 6.9 - i * 1.45
    cdraw.content((1.1, y), r.at(0), size: 6pt)
    cdraw.rect((2.2, y - 0.33), (5.4, y + 0.33), fill: luma(235), radius: 0.02)
    cdraw.content((3.8, y), r.at(1), size: 6pt)
    cdraw.line((5.5, y), (5.9, y), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((6.0, y - 0.33), (13.9, y + 0.33), fill: luma(205), radius: 0.02)
    cdraw.content((9.95, y), r.at(2), size: 6pt)
  }
  cdraw.content((16.2, 6.9), [bezout: 240 × (-9) + 46 × 47 = 2], size: 6pt)
  cdraw.content((16.2, 5.45), [both roads land the same inverse], size: 6pt)
  cdraw.content((16.2, 4.0), [fermat needs a prime modulus], size: 6pt)
  cdraw.content((16.2, 2.55), [euclid takes any coprime modulus], size: 6pt)
  cdraw.content((16.2, 1.1), [non-coprime: refuse, six ways], size: 6pt)
})

The 333333336 multiplied back to 1 is the biggest pin, and the
listings below invert six ways.

#listing("dsa/samples-c/src/Ch16/modinv.c", first: 46, last: 93, caption: [c, fermat inverse, extended euclid, zero on non-coprime])

#listing("dsa/samples/src/Ch16/NumTheory.cs", first: 125, last: 152, caption: [c\#, the bezout bookkeeping, throws when no inverse exists])

#listing("dsa/samples-go/ch16/modinv.go", first: 5, last: 41, caption: [go, both roads, errors carry the refusal])

#listing("dsa/samples-js/src/ch16-modinv.mjs", first: 11, last: 29, caption: [javascript, recursive extGcd on BigInt, null refuses])

#listing("dsa/samples-py/src/Ch16/modinv.py", first: 25, last: 42, caption: [python, fermat and euclid, None refuses])

#listing("dsa/samples-lua/ch16_modinv.lua", first: 30, last: 47, caption: [lua, fermat beside euclid, nil refuses])

The fixture families agree on the small primes, 3 inverts to 4 mod
11 and 10 inverts to 12 mod 17, and Lua pins the big one, 3 inverse
mod 1e9+7 is 333333336, verified by multiplying back to 1. C and
Python sweep every unit mod 97 and check both roads agree. The
refusal channel is the per-language story: C returns 0, Go returns
an error naming the shared factor, JavaScript and Python return
null and None, Lua returns nil, and C\# throws
`InvalidOperationException`. Six conventions, one mathematical
fact, a non-coprime pair has no inverse, and the gcd guard fires
before any of them is reached.

#diagram([the inverse is the bezout coefficient, a times x plus m times k equals 1], length: 13pt, {
  cdraw.content((9.5, 7.2), [3 \* 4 = 12 = 1 mod 11], size: 6.5pt)
  let ticks = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
  for t in ticks {
    let x = 2.0 + t * 1.35
    cdraw.line((x, 4.6), (x, 4.9), stroke: luma(100))
    cdraw.content((x, 4.25), [#t], size: 6pt)
  }
  cdraw.line((2.0, 4.75), (18.2, 4.75), stroke: luma(100))
  cdraw.content((1.0, 4.75), [0], size: 6pt)
  for k in range(3) {
    let x = 2.0 + 12 + k * 1.35 - 1.35 * 11
    cdraw.rect((x - 0.45, 5.6), (x + 0.45, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x, 6.0), [#(k * 11 + 1)], size: 6pt)
    cdraw.line((x, 5.6), (2.0 + (k * 11 + 1) * 1.35, 4.9), stroke: (paint: luma(160), dash: "dashed"))
  }
  cdraw.content((9.5, 3.3), [the numbers hitting 1 mod 11], size: 6pt)
  cdraw.content((9.5, 2.2), [bezout: 3 \* 4 + 11 \* (-1) = 1], size: 6pt)
  cdraw.content((9.5, 1.1), [gcd(6, 9) = 3: 6 never lands on 1], size: 6pt)
  cdraw.content((9.5, 0.0), [the guard fires first, every language], size: 6pt)
})

== the chinese remainder theorem

Two congruences, x = 2 mod 3 and x = 3 mod 5, describe one class mod
15 when the moduli are coprime, and the theorem folds a whole list
pairwise: combine two into one residue over the lcm, then bring in
the next. The classic three-congruence fixture, 2 mod 3, 3 mod 5, 2
mod 7, lands on 23 mod 105 in every suite.

The dry run: the fixture is the sun tzu triple, 2 mod 3, 3 mod 5,
2 mod 7, pinned at 23 mod 105 by every suite, the walk follows
the C\# pairwise fold with each lift spelled as the steps C's
search would take, and Python refuses the non-coprime merge the
other five accept.

+ Fold 2 mod 3 with 3 mod 5: the moduli share nothing, and the
  lift steps the first modulus twice, 2 + 3 = 5 then 5 + 3 = 8,
  where 8 mod 5 = 3 satisfies the second: 8 mod 15.
+ Fold 8 mod 15 with 2 mod 7: the lift needs one step, 8 + 15 =
  23, and 23 mod 7 = 2 lands 23 mod 105, the pinned class.
+ The residue check reads 23 mod 3 = 2 and 23 mod 5 = 3, both
  quoted in the C suite.
+ The non-coprime merge, 1 mod 6 with 3 mod 10: the moduli share
  2, the residues differ by 3 - 1 = 2, divisible, so the lift runs
  1 + 6 = 7, 7 + 6 = 13, and 13 mod 10 = 3 lands 13 mod 30.
+ The contradiction refuses: 1 mod 6 against 2 mod 10 differs by
  1, not divisible by the shared 2, so every suite rejects the
  system, Go and C\# naming the shared factor in the refusal.

#diagram([the fold as stepped lifts, two coprime folds reaching 23 mod 105, the non-coprime merge reaching 13 mod 30], length: 13pt, {
  let lane = (y, title, steps, end, endmod) => {
    cdraw.content((4.6, y), title, size: 6.5pt)
    let by = y - 1.3
    for (i, s) in steps.enumerate() {
      let x = 0.8 + i * 2.6
      cdraw.rect((x, by - 0.34), (x + 2.3, by + 0.34), fill: luma(235), radius: 0.02)
      cdraw.content((x + 1.15, by), s, size: 6pt)
      cdraw.line((x + 2.35, by), (x + 2.55, by), stroke: luma(100), mark: (end: ">"))
    }
    let xe = 0.8 + steps.len() * 2.6
    cdraw.rect((xe, by - 0.34), (xe + 2.3, by + 0.34), fill: luma(205), radius: 0.02)
    cdraw.content((xe + 1.15, by), end, size: 6pt)
    cdraw.content((xe + 3.6, by), endmod, size: 6pt)
  }
  lane(7.9, [fold 1, stepping 3], ([2], [2 + 3 = 5], [5 + 3 = 8]), [8], [mod 15])
  lane(5.9, [fold 2, stepping 15], ([8], [8 + 15 = 23]), [23], [mod 105])
  lane(3.9, [non-coprime, stepping 6], ([1], [1 + 6 = 7], [7 + 6 = 13]), [13], [mod 30])
  cdraw.content((4.6, 1.6), [each step checks the second residue], size: 6pt)
  cdraw.content((4.6, 0.7), [the difference must divide the shared factor], size: 6pt)
})

The 23 mod 105 is the pinned fold, and the listings below combine
six ways.

#listing("dsa/samples-c/src/Ch16/crt.c", first: 31, last: 47, caption: [c, the consistency check, then a step search over the lcm])

#listing("dsa/samples/src/Ch16/NumTheory.cs", first: 154, last: 180, caption: [c\#, pairwise fold, non-coprime merge, contradictions throw])

#listing("dsa/samples-go/ch16/crt.go", first: 10, last: 45, caption: [go, extGCD drives the lift, the error names the shared factor])

#listing("dsa/samples-js/src/ch16-crt.mjs", first: 12, last: 32, caption: [javascript, the lift through the inverse mod m/g, all BigInt])

#listing("dsa/samples-py/src/Ch16/crt.py", first: 32, last: 46, caption: [python, the coprime fold, every non-coprime system refused])

#listing("dsa/samples-lua/ch16_crt.lua", first: 13, last: 33, caption: [lua, the merge via extended euclid, nil on contradiction])

#callout("pitfall", "the non-coprime split is real, read your library twice", [
  The suites disagree on purpose about moduli that share a factor.
  Python refuses every non-coprime system, and its own comment says
  so: consistent non-coprime systems exist, they combine mod the lcm
  instead of the product, and the implementation stays out of scope.
  Go, C\#, JavaScript, Lua, and C accept them when the residues agree
  modulo the shared factor, merging mod the lcm, and reject them
  when they do not, Go and C\# with an error that names the shared
  factor, JavaScript and Lua with null and nil, C with a return code.
  The 23 mod 105 anchor holds everywhere, but 1 mod 6 with 3 mod 10
  is 13 mod 30 in five suites and a refusal in the sixth. This is
  the exact shape of bug a shared library papers over and a handbook
  has to name.
])

The mechanism under the fold: the difference of residues must be
divisible by the gcd of the moduli or no x satisfies both, and when
it is, the extended euclid inverse of one modulus over the other,
taken mod the shared-factor quotient, sizes the jump. C is the
honest exception, it steps the first congruence through the lcm and
looks for the second, fine at book sizes and free of any inverse
subtlety. The residue bookkeeping returns with real workload sizes
where bus schedules are congruences
and the answer is a chinese remainder in disguise. The contest form
is the same test with the merge dropped: the icpc book's 2023
finals, problem F (tilting tiles), reduces its reachability question
to linear congruences checked pairwise, one canonical residue per
distinct modulus and the gcd of each pair of moduli dividing the
residue difference. The moduli are never combined by lcm there, the
accumulator was observed overflowing 64 bits at contest sizes,
and existence is the whole answer.

#diagram([two congruence families on one number line, the intersection is one class mod the lcm], length: 13pt, {
  cdraw.content((9.5, 7.5), [x = 2 mod 3 and x = 3 mod 5: 8 mod 15], size: 6.5pt)
  for i in range(16) {
    let x = 2.2 + i * 1.05
    cdraw.line((x, 4.5), (x, 4.8), stroke: luma(100))
    cdraw.content((x, 4.15), [#i], size: 6pt)
  }
  cdraw.line((2.2, 4.65), (18.0, 4.65), stroke: luma(100))
  for i in range(6) {
    let x = 2.2 + (2 + 3 * i) * 1.05
    cdraw.circle((x, 5.55), radius: 0.13, fill: none, stroke: luma(100))
  }
  cdraw.content((0.9, 5.55), [mod 3], size: 6pt)
  for i in range(4) {
    let x = 2.2 + (3 + 5 * i) * 1.05
    cdraw.rect((x - 0.22, 6.15), (x + 0.22, 6.6), fill: none, stroke: luma(100), radius: 0.02)
  }
  cdraw.content((0.9, 6.35), [mod 5], size: 6pt)
  cdraw.circle((2.2 + 8 * 1.05, 5.55), radius: 0.3, stroke: 1.2pt + luma(30))
  cdraw.content((2.2 + 8 * 1.05, 7.0), [8], size: 6.5pt)
  cdraw.content((9.5, 3.0), [2 mod 3 with 3 mod 10: moduli share 2], size: 6pt)
  cdraw.content((9.5, 1.9), [residues agree mod 2: combine mod 30], size: 6pt)
  cdraw.content((9.5, 0.8), [disagree: refuse, python refuses both ways], size: 6pt)
})

== across the six languages

The build sizes count non-comment source lines over this chapter's
six featured files per language, checks included where they share
the file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [407], [libc only], [`__uint128` compiles but `__umodti3` fails to link, so mulmod adds and doubles with a remainder every step],
  [c\#], [152], [bcl only], [plain long products, modulus contract caps at 3 037 000 499 so squares fit, crt throws on contradiction],
  [go], [212], [math/bits], [mulmod through Mul64 and Div64, a real 128-bit product, errors carry the refusals],
  [javascript], [117], [node stdlib], [gcd, modpow, modinv, and crt on BigInt, sieve and factors stay on Number under 2^53],
  [python], [275], [stdlib only], [native ints, pow() and math.gcd are ground-truth cross-checks, crt refuses all non-coprime systems],
  [lua], [386], [lib.lua harness], [integers wrap silently, the suite proves math.maxinteger \* 2 == -2 then never multiplies big values],
)

sources: learn.microsoft.com, `Math.Abs` and argument-checking
guidance for the throwing guards, accessed 2026-09-08,
go.dev/pkg/math/bits for `Mul64` and `Div64`, developer.mozilla.org
for BigInt arithmetic, accessed 2026-09-14, and the sun tzu
remainder problem plus the CLRS number theory treatments cited in
the chapter text. Sample behavior verified by `make verify-csharp`,
17 tests in chapter 16 of the samples suite. The six-language layer
verifies the same way: 6 C programs with 119 embedded checks under
`make verify-c`, 24 Go tests, 21 `node --test` cases, 63 Python
checks across 6 files, and 28 Lua checks under `run.lua`.
