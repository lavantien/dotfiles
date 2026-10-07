#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= advanced number theory

Chapter 16 built the first toolkit, gcd and the sieve, trial division,
modpow, modinv, and the chinese remainder fold, and this chapter is
the second course built on top of it, #xref-to("dsa", "numtheory")
never repeated below. Eight tools make the rung. The linear sieve
computes, not just crosses, filling least prime factors plus the phi
and mu tables in one pass. Deterministic miller-rabin decides
primality for every 64-bit integer and pollard rho factors what it
calls composite. Divisor count and divisor sum arrive by
accumulation, carrying the phi identities and pillai's gcd-sum.
Baby-step giant-step takes discrete logs and finds smallest primitive
roots. Garner's algorithm rebuilds an integer from its residues the
constructive way, beside factorials mod p and the legendre exponent.
Linear diophantine equations solve exactly with no rounding. Gray
code and balanced ternary are the two odd numerations worth owning.
Continued fractions, the stern-brocot tree, and the farey sequence
close the chapter as one structure seen three ways. Every fixture
pins the same digits in all seven languages.

== the linear sieve and multiplicative functions

The eratosthenes sieve of chapter 16 crosses a composite once per
prime that divides it, which costs O(n log log n) and leaves nothing
behind but a boolean. The linear sieve trades the boolean for the
least prime factor and gets two things for the trade: a factorization
machine, since peeling lp values factors any n in the table, and a
linear pass, since every composite is now crossed exactly once, by
the product i times lp[i]. The inner loop walks the prime list and
stops the moment p would exceed lp[i], because a larger p would
cross i times p with a prime that is not its least one. The same
loop extends to multiplicative functions for free, and the fork is
the whole teaching. When p equals lp[i], the prime is already
inside i, so phi of i times p scales by p and
mu collapses to 0 on the squared factor. When p is new to i, phi
scales by p minus 1 and mu flips sign.

The dry run: the fixture is the C\# Build(1000) tables, the prime
count, the phi and mu heads, and the lp anchors all asserted by the
C\# suite, the other six pinning the same rung.

+ i = 2 has no least factor, joins the prime list, and crosses its
  first composite as 2 × 2 = 4 with lp = 2.
+ i = 3 joins the list and crosses twice: 6 = 3 × 2 gets
  phi = 2 × 1 = 2 and mu = -(-1) = 1 since 2 is new to 3, then
  9 = 3 × 3 gets phi = 2 × 3 = 6 and mu = 0 since 3 already sits
  inside.
+ i = 5 crosses 10 with 2 new, phi = 4 × 1 = 4 and mu = 1, then 25
  with 5 inside, phi = 4 × 5 = 20 and mu = 0.
+ i = 6 meets p = 2 equal to lp[6], so the fork scales
  phi[12] = 2 × 2 = 4, zeroes mu[12], and the break ends the pass:
  12 is never crossed again.
+ The heads land as asserted, phi over 1 to 12 reading 1, 1, 2, 2,
  4, 2, 6, 4, 6, 4, 10, 4 and mu zeroing at the squares 4, 8, 9,
  12, 16.
+ The pass to 1000 closes at 168 primes with the 168th at 997, and
  phi(1000) = 400.

#diagram([the early passes as a sequence, each i crossing its composites left to right, the fork results written inside every target], length: 13pt, {
  // one row per i: the source box, arrows to targets with phi/mu births
  let rows = (
    ([i = 2], (([4], [lp 2], [prime]),)),
    ([i = 3], (([6], [phi 2, mu 1], [2 new]), ([9], [phi 6, mu 0], [3 inside]))),
    ([i = 5], (([10], [phi 4, mu 1], [2 new]), ([25], [phi 20, mu 0], [5 inside]))),
    ([i = 6], (([12], [phi 4, mu 0], [p = lp, break]),)),
  )
  for (r, row) in rows.enumerate() {
    let (label, targets) = row
    let y = 7.0 - r * 2.0
    cdraw.rect((1.2, y - 0.35), (3.0, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((2.1, y), label, size: 6.5pt)
    for (k, tgt) in targets.enumerate() {
      let (num, fork, note) = tgt
      let x = 4.6 + k * 6.6
      cdraw.line((3.1, y), (x - 0.1, y), stroke: luma(100), mark: (end: ">"))
      cdraw.rect((x, y - 0.45), (x + 1.4, y + 0.45), fill: luma(205), radius: 0.02)
      cdraw.content((x + 0.7, y), num, size: 6.5pt)
      cdraw.content((x + 0.7, y - 0.85), fork, size: 6pt)
      cdraw.content((x + 0.7, y + 0.8), note, size: 6pt)
    }
  }
  cdraw.content((2.1, 8.5), [the passes in order], size: 6.5pt)
  cdraw.content((1.2, 0.0), [each composite crossed once, by i times lp of i], size: 6pt, anchor: "west")
  cdraw.content((1.2, -0.6), [the break at p = lp keeps the pass linear], size: 6pt, anchor: "west")
})

The 400 closes the table, and the listings below sieve it in seven
languages.

#listing("dsa/samples-c/src/Ch28/linsieve.c", first: 26, last: 50, caption: [c, one pass, every composite crossed once by i times lp of i, the phi and mu fork inside])

#listing("dsa/samples-go/ch28/linsieve.go", first: 14, last: 43, caption: [go, the fork closes the inner loop itself, the hinge that keeps the pass linear])

#listing("dsa/samples-java/src/Ch28/Linsieve.java", first: 14, last: 38, caption: [java, static lp, phi, mu, and prime arrays, the fork inside, the break tested at the top of the inner loop])

#listing("dsa/samples/src/Ch28/LinSieve.cs", first: 14, last: 51, caption: [c\#, the same build, the break spelled out in a comment])

#listing("dsa/samples-js/src/ch28-linsieve.mjs", first: 8, last: 37, caption: [javascript, four 0-based arrays out, plain Number under 1000])

#listing("dsa/samples-py/src/Ch28/linsieve.py", first: 16, last: 44, caption: [python, lp, primes, phi, mu from one loop, the break carried in the branch])

#listing("dsa/samples-lua/ch28_linsieve.lua", first: 10, last: 33, caption: [lua, tables indexed by the domain value, so lp of 60 reads lp of 60])

The languages split on where the loop stops and it does not matter.
C, C\#, JavaScript, and Java test p against lp[i] at the top of the
inner
loop, Go, Python, and Lua break inside the p equals lp[i] branch, and
both forms leave the inner loop exactly when the prime reaches the
least factor. Fixtures pin the rung above chapter 16's pi(100) = 25:
pi(1000) = 168, the prime list opening 2, 3, 5, 7, 11, 13, the 168th
prime 997, and least factors lp(60) = 2, lp(97) = 97, lp(997) = 997,
lp(998) = 2, lp(1000) = 2. The function tables read phi over 1 to 12
as 1, 1, 2, 2, 4, 2, 6, 4, 6, 4, 10, 4 and mu over 1 to 16 as 1,
-1, -1, 0, -1, 1, -1, 0, 0, 1, -1, 0, -1, 1, 1, 0, with phi(1000) =
400. The n = 1 convention holds everywhere, lp(1) = 0 with phi and mu
both 1, phi multiplies over the coprime pair as phi(4) times phi(9)
equal to phi(36) equal to 12, mu(30) = -1 on three primes and
mu(12) = 0 on the square, and the lp chain peels 998 = 2 times 499
with 499 prime. Python cross-checks all three tables the slow way, lp against
trial division everywhere, phi against gcd counting to 200, mu
against a factored form over the whole table. No finals problem in
the corpus needed this sieve, chapter 16's carried every year, and
the mobius table stays a table here, the inversion identity that uses
it lands in chapter 35.

#diagram([composite 12 crossed exactly once, then the fork: the prime already in i scales phi by p and zeroes mu, a new prime scales by p minus 1 and flips mu], length: 13pt, {
  // left: the crossing 6 * 2 = 12 with lp[12] = 2
  cdraw.rect((1.2, 6.4), (3.2, 7.3), fill: luma(235), radius: 0.02)
  cdraw.content((2.2, 6.85), [i = 6], size: 7pt)
  cdraw.rect((1.2, 5.0), (3.2, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((2.2, 5.45), [p = 2], size: 7pt)
  cdraw.line((2.2, 6.3), (2.2, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.3, 5.45), (4.5, 5.45), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.6, 5.0), (6.6, 5.9), fill: luma(205), radius: 0.02)
  cdraw.content((5.6, 5.45), [12], size: 8pt)
  cdraw.content((1.2, 4.55), [p = lp of 6, so 12 = 6 \* 2 and lp of 12 = 2], size: 6pt, anchor: "west")
  cdraw.content((1.2, 3.9), [crossed once, never again], size: 6pt, anchor: "west")
  // the number strip
  for (i, v) in (10, 11, 12, 13, 14).enumerate() {
    let x = 8.4 + i * 1.05
    cdraw.rect((x, 6.4), (x + 0.95, 7.3), fill: if v == 12 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.47, 6.85), [#v], size: 7pt)
  }
  cdraw.content((10.85, 6.0), [only 12 is touched], size: 6pt)
  // right: the fork
  cdraw.content((13.9, 7.7), [the fork at i \* p], size: 6.5pt, anchor: "west")
  cdraw.rect((13.9, 6.4), (19.1, 7.1), fill: luma(245), radius: 0.02)
  cdraw.content((14.1, 6.75), [p equals lp of i: p divides i], size: 6pt, anchor: "west")
  cdraw.rect((13.9, 5.1), (19.1, 5.8), fill: luma(245), radius: 0.02)
  cdraw.content((14.1, 5.45), [p is new to i], size: 6pt, anchor: "west")
  cdraw.line((16.5, 6.3), (16.5, 5.85), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.1, 4.5), [phi: times p, mu: 0], size: 6pt, anchor: "west")
  cdraw.content((14.1, 3.85), [phi of 12 = 2 \* 2 = 4], size: 6pt, anchor: "west")
  cdraw.content((14.1, 3.2), [mu of 12 = 0, a square], size: 6pt, anchor: "west")
  cdraw.content((14.1, 2.55), [phi: times p - 1, mu flips], size: 6pt, anchor: "west")
  cdraw.content((14.1, 1.9), [phi of 10 = 4 \* 1 = 4], size: 6pt, anchor: "west")
  cdraw.content((14.1, 1.25), [mu of 10 = -(-1) = 1], size: 6pt, anchor: "west")
  cdraw.content((1.2, 2.5), [one multiplication per composite, O(n)], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.85), [ch16 sieve: O(n log log n), booleans only], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.2), [peeling lp factors any table entry], size: 6pt, anchor: "west")
})

== deterministic miller-rabin and pollard rho

Primality becomes a settled question at 64 bits because a fixed
witness set settles it. Miller-rabin decomposes n minus 1 as d times
2^s with d odd, then asks each witness a whether a^d or one of its
doublings hits 1 or n minus 1. A prime always answers yes, and a
composite that answers yes for a particular a is a strong
pseudoprime to base a. The first twelve primes, 2 through 37, are
known to expose every composite below 3.317e24, which covers all of
uint64, so the test is deterministic with the small divisors
pre-checked first. The famous liar at this scale is 3215031751, the
product 151 \* 751 \* 28351, which passes the four bases 2, 3, 5, 7
that settle all of 32 bits and dies on witness 11. Factoring what
survives is pollard rho's job: iterate f(x) = x^2 + c mod n with a
floyd cycle, one tortoise step against two hare steps, and take the
gcd of the gap with n at every step, a nontrivial gcd is a factor.
The constants c and every restart draw from the house seeded lcg,
x' = 6364136223846793005 \* x + 1442695040888963407 mod 2^64 seeded
0x9E3779B97F4A7C15, the same constants the icpc book's chapter 14
pins, so all seven languages walk the identical rho trajectory.

The dry run: the fixtures are the liar 3215031751 asserted both
ways and the rho factorizations, carried by the C\# suite, the other
six walking the same seeded trajectory.

+ The small-divisor gate settles the carmichaels before any witness
  runs: 5 + 6 + 1 = 12 exposes the 3 in 561, and 41041 opens at 7.
+ The liar decomposes as 3215031751 - 1 = 3215031750 =
  2 × 1607515875, so s = 1 and d = 1607515875, one squaring per
  round.
+ Under the four-base helper {2, 3, 5, 7} every round answers
  probable prime, the suite asserting true, and under the pinned
  twelve the first kill lands at witness 11, the suite asserting
  false, so the public gate reads composite.
+ Rho splits the exposed composites on the shared seed: 561 factors
  3, 11, 17 with the product folding back 3 × 11 × 17 = 561, and
  41041 factors 7, 11, 13, 41.
+ The semiprime 1000036000099 returns 1000003 and 1000033, the two
  primes the anchors already declared prime, and the square
  2147483647 squared returns its twin halves, rho of 4 returning 2.

#diagram([the verdict as a pipeline, the liar entering at the left, the pre-check, the s = 1 decomposition, the four lying witnesses, the kill at 11, rho folding the factors back], length: 13pt, {
  // five stages left to right, the number flowing through
  let stages = (
    ([small divisors], [561 dies here], [the liar survives]),
    ([decompose], [s = 1], [d = 1607515875]),
    ([witnesses 2, 3, 5, 7], [all four lie], [probable prime]),
    ([witness 11], [composite], [exposed]),
    ([rho], [561 = 3 × 11 × 17], []),
  )
  for (i, st) in stages.enumerate() {
    let (name, n1, n2) = st
    let x = 1.2 + i * 3.9
    cdraw.rect((x, 4.6), (x + 3.3, 5.8), fill: if i == 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.65, 5.2), name, size: 6.5pt)
    cdraw.content((x + 1.65, 4.15), n1, size: 6pt)
    if n2 != [] { cdraw.content((x + 1.65, 3.6), n2, size: 6pt) }
    if i < 4 { cdraw.line((x + 3.4, 5.2), (x + 3.8, 5.2), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((2.85, 6.6), [3215031751 = 151 × 751 × 28351 enters], size: 6pt)
  cdraw.content((9.0, 2.7), [the four bases settle 32 bits, the liar is why they cannot settle 64], size: 6pt)
  cdraw.content((9.0, 1.9), [the pinned twelve expose every composite below 3.317e24], size: 6pt)
  cdraw.content((9.0, 1.1), [the mr gate refuses before rho ever runs on a prime], size: 6pt)
  cdraw.content((9.0, 0.3), [every factor list multiplies back to its input], size: 6pt)
})

The two-way liar closes the run, and the listings below carry the
gate and rho in seven languages.

#listing("dsa/samples-c/src/Ch28/primality.c", first: 64, last: 99, caption: [c, one strong-pseudoprime round, then the witness loop over any base set])

#listing("dsa/samples-go/ch28/primality.go", first: 25, last: 64, caption: [go, small divisors pre-checked, ch16 mulmod and modpow underneath])

#listing("dsa/samples-java/src/Ch28/Primality.java", first: 104, last: 129, caption: [java, the seeded lcg draws through `Long.remainderUnsigned`, floyd cycle rho, the add-and-double mulmod above])

#listing("dsa/samples/src/Ch28/Primality.cs", first: 25, last: 65, caption: [c\#, IsPrimeWith takes the base set, the pinned twelve ride the public gate])

#listing("dsa/samples-js/src/ch28-primality.mjs", first: 60, last: 91, caption: [javascript, the seeded lcg, then rho with the floyd cycle and a restart on a collapsed gcd])

#listing("dsa/samples-py/src/Ch28/primality.py", first: 49, last: 78, caption: [python, the rho driver, c and starts drawn from the shared stream])

#listing("dsa/samples-lua/ch28_primality.lua", first: 61, last: 89, caption: [lua, the shared seed, then rho splitting with bounded restarts])

The integer roads split exactly where chapter 16 left them. Rho on
these moduli squares residues at 4.6e18, past 2^63, so C multiplies by
add-and-double with a remainder every step because the ch16 link
ruling bans 128-bit help, Lua does the same with its silently wrapping
int64, Java walks C's add-and-double road too and pushes its rho
modulus draws through `Long.remainderUnsigned` because the seeded lcg
wraps negative in a signed long, C\# rides every product through
System.UInt128, Go goes through
ch16's Mul64 and Div64, and JavaScript puts the whole computation on
BigInt. Fixtures agree digit for digit. The miller-rabin anchors: 2,
3, and 97 prime, 4 not, 1000003 and 1000033 prime, the mersenne prime
2^61 - 1 prime, the carmichael numbers 561 and 41041 exposed, and the
liar 3215031751 asserted both ways, true under the four-base helper
and false under the pinned twelve. The factorizations: 561 = 3, 11,
17, 41041 = 7, 11, 13, 41, 123456789012345678 = 2, 3, 3, 3,
21491747, 106377431, the semiprime 1000036000099 splitting into
1000003 and 1000033, and 2147483647 squared giving the twin factors
again, the perfect-square edge where rho must not loop on equal
halves. Edge behavior: 1 is not prime, rho of 4 returns 2, factoring
a prime refuses through the miller-rabin gate in every refusal
channel, and every factor list multiplies back to its input. Two
finals problems live one rung below and one rung above this section:
icpc 2025 problem F (book 10, chapter 13) takes the largest prime up
to n/3 by trial division, and icpc 2025 problem B (book 10, chapter
13) bipartitions its graph by the parity of the prime factor count,
omega read off exactly these factorizations.

#diagram([the witness ladder: 3215031751 slips past bases 2, 3, 5, 7 and dies on witness 11], length: 13pt, {
  let ws = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
  let states = (1, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0) // 1 lied, 2 killed it, 0 unreached
  for (i, w) in ws.enumerate() {
    let y = 7.2 - i * 0.58
    let x0 = 1.6
    let fill = if states.at(i) == 1 { luma(225) } else if states.at(i) == 2 { luma(120) } else { luma(245) }
    cdraw.rect((x0, y - 0.2), (x0 + 2.9, y + 0.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 1.45, y), [witness #w], size: 6.5pt,
      fill: if states.at(i) == 2 { white } else { black })
    cdraw.line((x0 + 2.9, y), (x0 + 4.1, y), stroke: if states.at(i) == 2 { luma(100) } else { luma(210) }, mark: (end: ">"))
    cdraw.content((x0 + 4.25, y), if states.at(i) == 1 { [lied: strong pseudoprime] } else if states.at(i) == 2 { [composite exposed] } else { [never consulted] }, size: 6pt, anchor: "west")
  }
  cdraw.content((12.4, 7.6), [3215031751 = 151 \* 751 \* 28351], size: 6pt, anchor: "west")
  cdraw.content((12.4, 6.7), [bases 2, 3, 5, 7 settle 32 bits], size: 6pt, anchor: "west")
  cdraw.content((12.4, 5.8), [this liar is why they cannot], size: 6pt, anchor: "west")
  cdraw.content((12.4, 5.35), [settle 64 bits], size: 6pt, anchor: "west")
  cdraw.content((12.4, 4.45), [the first twelve primes expose], size: 6pt, anchor: "west")
  cdraw.content((12.4, 4.0), [every composite below 3.317e24], size: 6pt, anchor: "west")
  cdraw.content((12.4, 3.1), [so the pinned set is deterministic], size: 6pt, anchor: "west")
  cdraw.content((12.4, 2.2), [the verdict stops at the first failure], size: 6pt, anchor: "west")
  cdraw.content((12.4, 1.3), [rho factors the composites next], size: 6pt, anchor: "west")
  cdraw.content((12.4, 0.4), [seeded lcg, one trajectory in all six], size: 6pt, anchor: "west")
})

== divisor counts, divisor sums, and the phi identities

The multiplicative closed forms for d(n) and sigma(n) need prime
factorizations. The accumulation sieve needs nothing but a loop nest:
for every d from 1 to n, walk the multiples of d and add 1 to dcnt of
each multiple and d itself to sigma of it. Every divisor of m
contributes exactly once to each table, the work is the harmonic sum
O(n log n), and the tables come out for every m at once. It is the
deliberately simple form, the closed forms are the fast road when one
n is wanted, and this is the road that fills a table. Three identities
ride the tables. The divisor sum of phi closes on n itself, the sum
of phi over every divisor of n equals n. The summatory totient sums
phi of 1 through n. And pillai's identity prices the gcd-sum, the sum
of gcd(k, n) over k from 1 to n equals the sum of d times phi(n/d)
over the divisors d of n.

The dry run: the fixtures are the 360 anchors with the smaller pair
d(36) = 9 and sigma(36) = 91 asserted beside them by the C\# suite,
the pillai value brute-counted in-suite.

+ The pass at d = 1 walks every cell, so both tables open at 1
  everywhere, and cell 36 starts collecting.
+ Its divisor rail arrives in d order, 1, 2, 3, 4, 6, 9, 12, 18, 36,
  each arrival adding 1 to dcnt and d itself to sigma.
+ Nine arrivals close dcnt[36] at 9 while sigma climbs the running
  sums below, ending 55 + 36 = 91.
+ The same rail at 360 collects the pinned 24 contributions and
  closes d(360) = 24 with sigma(360) = 1170.
+ The phi identity reads the rail: phi summed over those divisors
  returns exactly 360, and the summatory totient to 100 lands 3044.
+ Pillai prices the gcd-sum of 360 at 3780 both ways, the fold over
  d times phi(360/d) and the brute gcd count agreeing.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*d arrives*], [*dcnt[36]*], [*sigma added*], [*sigma[36] now*]),
  [1], [1], [1], [1],
  [2], [2], [2], [3],
  [3], [3], [3], [6],
  [4], [4], [4], [10],
  [6], [5], [6], [16],
  [9], [6], [9], [25],
  [12], [7], [12], [37],
  [18], [8], [18], [55],
  [36], [9], [36], [91],
)

The 91 closes the accumulation at the pinned 9 divisors, and the
listings below sieve both tables in seven languages.

#listing("dsa/samples-c/src/Ch28/totdiv.c", first: 23, last: 47, caption: [c, the accumulation sieve, then phi by the same linear pass as 28.1])

#listing("dsa/samples-go/ch28/totdiv.go", first: 3, last: 47, caption: [go, the sieve, the ground-truth divisor walk, pillai over the 28.1 phi table])

#listing("dsa/samples-java/src/Ch28/Totdiv.java", first: 11, last: 36, caption: [java, the accumulation loops, then phi by the same linear pass inlined])

#listing("dsa/samples/src/Ch28/TotDiv.cs", first: 9, last: 53, caption: [c\#, both tables, the divisor list, and the pillai fold taking phi as a parameter])

#listing("dsa/samples-js/src/ch28-totdiv.mjs", first: 9, last: 50, caption: [javascript, the tables, the fold, and the brute gcd twin beside it])

#listing("dsa/samples-py/src/Ch28/totdiv.py", first: 16, last: 28, caption: [python, the accumulation loops with phi sieved in place by subtraction])

#listing("dsa/samples-lua/ch28_totdiv.lua", first: 8, last: 35, caption: [lua, both tables by accumulation, phi kept self-contained by the linear sieve])

Python is the one that builds phi differently, and the difference is
worth the read: it initializes phi to the identity and subtracts
phi of m over p for every prime multiple, the eratosthenes-shaped
totient sieve, while the other six reuse the 28.1 linear pass. The
anchors: d(360) = 24 and sigma(360) = 1170 with the full 24-entry
divisor list pinned 1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 18, 20, 24,
30, 36, 40, 45, 60, 72, 90, 120, 180, 360, and the smaller pair
d(36) = 9, sigma(36) = 91. The identities: phi summed over the
divisors of 360 returns exactly 360, the summatory totient to 100
is 3044, and the pillai fold values the gcd-sum of 360 at 3780, with
every suite brute-counting the gcds as the cross-check. The edges:
sigma(28) = 56 and sigma(496) = 992, both perfect, a prime owns
exactly 1 and itself with d(997) = 2 and sigma(997) = 998, and
d(1) = sigma(1) = 1. Python sweeps both tables against trial
division to 200. No finals problem demanded these functions, they
are the general technique that keeps showing up under counting
problems.

#diagram([the divisor sieve donating 6 to every multiple of 6, beneath the phi identity closing on 360], length: 13pt, {
  cdraw.content((1.2, 7.75), [the pass for d = 6], size: 6.5pt, anchor: "west")
  cdraw.rect((1.2, 6.3), (3.2, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((2.2, 6.75), [d = 6], size: 7pt)
  cdraw.line((3.3, 6.75), (4.3, 6.75), stroke: luma(100), mark: (end: ">"))
  for (i, m) in (6, 12, 18, 24, 30, 36).enumerate() {
    let x = 4.4 + i * 2.2
    cdraw.rect((x, 6.3), (x + 1.9, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.95, 6.75), [#m], size: 7pt)
    // one riser per multiple off the rail below
    cdraw.line((x + 0.95, 5.95), (x + 0.95, 6.25), stroke: (paint: luma(170), dash: "dashed"))
  }
  cdraw.line((5.35, 5.95), (16.35, 5.95), stroke: (paint: luma(170), dash: "dashed"), mark: (end: ">"))
  cdraw.content((1.2, 5.6), [+6 to sigma, +1 to dcnt, once per pair], size: 6pt, anchor: "west")
  cdraw.content((12.6, 4.7), [sigma of m gains d, dcnt of m gains 1], size: 6pt, anchor: "west")
  cdraw.content((12.6, 4.05), [each pair counted exactly once], size: 6pt, anchor: "west")
  cdraw.content((12.6, 3.4), [O(n log n), the harmonic sum], size: 6pt, anchor: "west")
  cdraw.rect((1.2, 0.9), (11.0, 2.6), fill: luma(245), radius: 0.02)
  cdraw.content((6.1, 2.1), [the sum of phi over the divisors of 360 equals 360], size: 6.5pt)
  cdraw.content((6.1, 1.45), [phi(1) + phi(2) + ... + phi(180) + phi(360) = 360], size: 6pt)
  cdraw.content((1.2, 0.35), [pillai: the gcd-sum of 360 is 3780, brute-counted in-suite], size: 6pt, anchor: "west")
})

== discrete logs and primitive roots

Multiplication mod p is a group, and the discrete logarithm asks which
power: given a, b, and a prime p, find the smallest x with a^x = b.
Baby-step giant-step squares the search away. Build a table of the m
baby powers a^0 through a^(m-1) where m is floor of the square root
of p, hashed by value to the smallest exponent, then walk giant steps
from b multiplying by a^(-m), built by fermat as a^(p-1-m). Any hit
gives x = i \* m + j, the loop runs at most m + 1 times, and the cost
is O(sqrt p) time and space, 31623 table entries at the 1e9+7 anchor.
Primitive roots invert the question: g is a primitive root of p when
its order is exactly p - 1, and the smallest one is found by factoring
p - 1 with the 28.2 machinery, then testing that g^((p-1)/q) differs
from 1 for every prime q in that factorization, since the order
divides p - 1 and misses it exactly when such a power lands on 1.
The order of any a comes off the same walk, shrinking p - 1 by every
prime that still yields 1.

The dry run: the fixture is dlog(2, 5, 29) = 22 asserted with its
substitution check by the C\# suite, the 1e9+7 anchor and the root
table pinned beside it.

+ m is the floor of the square root of 29, so the baby table holds
  j = 0 through 4: the powers 1, 2, 4, 8, 16, one multiplication by
  2 each step.
+ The giant factor is a^(-m): 2^5 = 32 = 3 mod 29, and
  3 × 10 = 30 = 1, so every giant step multiplies by 10.
+ The walk from b = 5 runs 5 × 10 = 50 = 21, 21 × 10 = 210 = 7,
  7 × 10 = 70 = 12, 12 × 10 = 120 = 4.
+ The value 4 already sits in the baby table at j = 2, so
  x = 4 × 5 + 2 = 22, checked back as 2^22 mod 29 = 5.
+ The same solver at 1e9+7 reads m = 31623 and pins
  dlog(2, 3) = 385273928, verified by pow.
+ The root side: the smallest root of 29 is 2, the orders of 2 and 3
  both read 28, and phi(28) = 12 primitive roots exist.

#diagram([the search as a sequence, the exponent line 0 to 27 tiled into giant windows of five, the hit landing in window 4 at offset 2], length: 13pt, {
  // the exponent rail with giant windows and the giant values beneath
  for i in range(28) {
    let x = 1.2 + i * 0.62
    let win = int(i / 5)
    let hot = i == 22
    cdraw.rect((x, 4.2), (x + 0.58, 5.1), fill: if hot { luma(205) } else if win == 4 { luma(225) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.29, 4.65), [#i], size: 6pt)
  }
  let gvals = (5, 21, 7, 12, 4)
  for w in range(5) {
    let x = 1.2 + w * 3.1
    cdraw.line((x, 4.05), (x + 3.05, 4.05), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x + 1.55, 3.5), [giant #w: #gvals.at(w)], size: 6pt)
  }
  cdraw.content((1.2, 6.1), [baby offsets j = 0 to 4 inside every window], size: 6pt, anchor: "west")
  cdraw.content((1.2, 5.5), [the hit: window 4 holds 4, baby j = 2], size: 6pt, anchor: "west")
  cdraw.line((1.2 + 22 * 0.62 + 0.29, 4.15), (8.0, 2.4), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((8.2, 2.4), [x = 4 × 5 + 2 = 22], size: 6pt, anchor: "west")
  cdraw.content((8.2, 1.5), [check: 2^22 mod 29 = 5], size: 6pt, anchor: "west")
  cdraw.content((8.2, 0.6), [at 1e9+7: m = 31623, x = 385273928], size: 6pt, anchor: "west")
  cdraw.content((1.2, 1.4), [the walk stops at the first window], size: 6pt, anchor: "west")
  cdraw.content((1.2, 0.8), [whose giant value sits in the table], size: 6pt, anchor: "west")
})

The 22 closes the meet, and the listings below run both walks in
seven languages.

#listing("dsa/samples-c/src/Ch28/dlog.c", first: 46, last: 82, caption: [c, the baby table sorted for binary search, giant steps by a^(p-1-m)])

#listing("dsa/samples-go/ch28/dlog.go", first: 15, last: 48, caption: [go, ch16 mulmod and the fermat inverse, errors on refusal])

#listing("dsa/samples-java/src/Ch28/Dlog.java", first: 34, last: 60, caption: [java, the HashMap baby table keeping the smallest exponent by `putIfAbsent`, giant factor by fermat, plain long products under 2^63])

#listing("dsa/samples/src/Ch28/DLog.cs", first: 11, last: 40, caption: [c\#, a dictionary keyed by value keeps the smallest exponent])

#listing("dsa/samples-js/src/ch28-dlog.mjs", first: 26, last: 47, caption: [javascript, bsgs on BigInt, residues pass 2^53 at 1e9+7])

#listing("dsa/samples-py/src/Ch28/dlog.py", first: 16, last: 37, caption: [python, the table as a dict, the giant factor by three-argument pow])

#listing("dsa/samples-lua/ch28_dlog.lua", first: 17, last: 37, caption: [lua, smallest exponent kept per value, plain products under 2^63])

The baby table must keep the smallest exponent per value, exponents
repeat whenever the order of a is below m, and the suites that skip
that check can return a larger x than asked for, java's HashMap
holding its table through `putIfAbsent` so the first, smallest
exponent survives every repeat. Fixtures pin the
1e9+7 anchor, dlog of 2 to 3 is 385273928, verified back by pow, and
the mod 29 triple dlog(2, 5) = 22, dlog(3, 6) = 18, dlog(2, 14) = 13,
each verified by substitution. The primitive roots land on the two
transform primes of chapter 29, cross-named in every comment: the
smallest root of 29 is 2, of 998244353 is 3, of 754974721 is 11, and
of 1000000007 is 5. Orders pin at 28 for both 2 and 3 mod 29, and the
count of primitive roots mod 29 is phi(28) = 12. Edges: dlog of 2 to
0 refuses because 0 is never a power, dlog of a to 1 returns 0, and
modulus 2 with 1 to 1 returns 0. No finals problem needed a discrete
log, this is the general technique.

#diagram([the sqrt 29 baby column and the giant walk meeting at 4, the answer 22 = 4 \* 5 + 2], length: 13pt, {
  cdraw.content((1.4, 7.7), [baby table], size: 6.5pt, anchor: "west")
  for (j, v) in (1, 2, 4, 8, 16).enumerate() {
    let y = 6.8 - j * 0.85
    cdraw.rect((1.4, y - 0.3), (3.8, y + 0.3), fill: if v == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.0, y), [2^#j], size: 6.5pt)
    cdraw.content((3.3, y), [#v], size: 6.5pt)
  }
  cdraw.content((5.2, 7.7), [giant walk from b = 5], size: 6.5pt, anchor: "west")
  let walk = ((0, 5), (1, 21), (2, 7), (3, 12), (4, 4))
  for (i, v) in walk {
    let y = 6.8 - i * 0.85
    cdraw.rect((5.2, y - 0.3), (7.6, y + 0.3), fill: if v == 4 { luma(205) } else { luma(245) }, radius: 0.02)
    cdraw.content((5.8, y), [i = #i], size: 6.5pt)
    cdraw.content((7.0, y), [#v], size: 6.5pt)
  }
  cdraw.line((3.9, 6.8 - 2 * 0.85), (5.1, 6.8 - 4 * 0.85), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.5, 4.6), [meet], size: 6pt)
  cdraw.content((8.6, 6.8), [both sides hold 4 = 2^2], size: 6pt, anchor: "west")
  cdraw.content((8.6, 5.9), [x = i \* m + j = 4 \* 5 + 2 = 22], size: 6pt, anchor: "west")
  cdraw.content((8.6, 5.0), [check: 2^22 mod 29 = 5], size: 6pt, anchor: "west")
  cdraw.content((8.6, 3.9), [O(sqrt p) time and space], size: 6pt, anchor: "west")
  cdraw.content((8.6, 3.0), [at p = 1e9+7: a 31623-entry table], size: 6pt, anchor: "west")
  cdraw.content((8.6, 2.1), [dlog(2, 3, 1e9+7) = 385273928], size: 6pt, anchor: "west")
  cdraw.content((8.6, 1.4), [998244353 opens at root 3,], size: 6pt, anchor: "west")
  cdraw.content((8.6, 0.7), [754974721 at 11, ch29's primes], size: 6pt, anchor: "west")
})

== garner's algorithm and factorials mod p

Chapter 16 folds the chinese remainder theorem pairwise, each merge
combining two congruences into one over the lcm, and that fold proves
existence one step at a time. Garner's algorithm is the constructive
rebuild: write the unknown as a mixed-radix number whose digit moduli
are the original moduli. Digit x~i~ is the residue r~i~ minus the
already-known digits times their moduli, times the inverse of the
running product mod m~i~, and the value folds back from the top as
x = ((x~k-1~) \* m~k-2~ + x~k-2~) \* ... . Two properties make it the
working form. It never forms the combined modulus as a number, each
digit computation stays inside m~i~, and it accepts any pairwise
coprime moduli, primes are not required, which is exactly what the
composite moduli below need. The inverse of 998244353 mod 754974721 is
416537774, the pinned INV of chapter 29's transform fold, cross-named
here by the fixture that asserts it. Beside the rebuild sit the
factorial facts mod a prime: the table 0 to n multiplies one factor
per entry, any n at or past p collapses to 0 exactly when the factor
p enters, wilson's pair reads (p-1)! = p - 1 and (p-2)! = 1, and the
legendre exponent counts the p-adic valuation of n! as the sum of
floor(n / p^k) over k.

The dry run: the fixture is the 2019 K departure time 1736 over the
moduli 8, 9, 5, 7, asserted digit by digit by the C\# suite, the
12345678987654321 rebuild pinned beside it.

+ Digit x~0~ is the residue itself: 0 mod 8.
+ x~1~ subtracts the known digits, 8 - 0 = 8, then scales by the
  inverse of m~0~ = 8 mod 9: 8 × 8 = 64 = 1 mod 9, so x~1~ =
  8 × 8 = 1 mod 9.
+ x~2~ subtracts the running value 0 + 1 × 8 = 8, leaving 1 - 8 =
  -7; m~0~m~1~ = 72 = 2 mod 5 with inverse 3 since 2 × 3 = 6 = 1,
  and -7 × 3 = -21 = 4 mod 5.
+ x~3~ subtracts the running value 8 + 4 × 72 = 296, leaving -296;
  8 × 9 × 5 = 360 = 3 mod 7 with inverse 5 since 3 × 5 = 15 = 1,
  and -296 × 5 lands 4 mod 7.
+ The digits read 0, 1, 4, 4, the pin, and the rebuild folds from
  the top: ((4 × 5 + 4) × 9 + 1) × 8 + 0 = 1736.
+ The big fixture runs the same ladder blind, digits 901234575,
  12345678, 0 rebuilding 12345678987654321 exactly, and the
  factorials ride beside it, 10! mod 11 = 10 with the legendre
  exponents 97, 498, 505.

#table(
  columns: (auto, auto, auto, 1.6fr, auto),
  inset: 4pt,
  table.header([*i*], [*m~i~*], [*r~i~*], [*the subtraction*], [*digit*]),
  [0], [8], [0], [the residue itself], [0],
  [1], [9], [8], [(8 - 0) × 8 mod 9], [1],
  [2], [5], [1], [(1 - 8) × 3 mod 5], [4],
  [3], [7], [0], [(0 - 296) × 5 mod 7], [4],
)

The 1736 closes the rebuild, and the listings below carry the
digits in seven languages.

#listing("dsa/samples-c/src/Ch28/garner.c", first: 19, last: 57, caption: [c, inverse by extended euclid for composite moduli, then the digit loop and the rebuild])

#listing("dsa/samples-go/ch28/garner.go", first: 10, last: 39, caption: [go, the telescoping digit update, moduli reduced mod m~i~])

#listing("dsa/samples-java/src/Ch28/Garner.java", first: 18, last: 54, caption: [java, extended euclid inverse for the composite moduli, the telescoping digit update, the rebuild in plain longs])

#listing("dsa/samples/src/Ch28/Garner.cs", first: 11, last: 42, caption: [c\#, digits then the top-down rebuild in checked arithmetic])

#listing("dsa/samples-js/src/ch28-garner.mjs", first: 8, last: 38, caption: [javascript, extgcd inverse and the fold, BigInt throughout, the combined modulus passes 2^53])

#listing("dsa/samples-py/src/Ch28/garner.py", first: 14, last: 29, caption: [python, the digit loop over running products, pow with -1 for the inverse])

#listing("dsa/samples-lua/ch28_garner.lua", first: 18, last: 48, caption: [lua, extended euclid again, m need not be prime, rebuild under 2^63])

The inverse here must be extended euclid, not fermat, because the
2019 fixture works mod 8 and 9. The pinned rebuild: x =
12345678987654321 over the moduli 1000000007, 998244353, 754974721
has residues 901234575, 760561298, 160985081, digits 901234575,
12345678, 0, and the rebuild returns the input exactly, JavaScript
doing it through BigInt because the combined modulus reaches 1.2e16
past 2^53, java rebuilding in plain longs where every intermediate
stays under 2^63, and cross-naming the 416537774 INV beside its
digits. Factorials: 10! mod 11 = 10 with 9! mod 11 = 1, the
wilson pair, 30! mod 1000000007 = 109361473, 100! mod 1000000007 =
437918130, 1000! mod 998244353 = 421678599, and 101! mod 101 = 0.
Legendre: v~2~ of 100! is 97, v~3~ of 1000! is 498, v~5~ of 2026! is
505, and 0! = 1! = 1. The contest tie is the third fixture: icpc
2019 problem K (book 10, chapter 10) multiplies survival fractions
over residue classes of a departure time mod 2520 = 8 \* 9 \* 5 \* 7,
chapter 16 names the crt existence clause, and the departure time
1736 with residues (0, 8, 1, 0) and digits (0, 1, 4, 4) rebuilds
through exactly this code, the constructive half of that solution.

#diagram([the mixed-radix odometer, three digit wheels winding back to 12345678987654321], length: 13pt, {
  cdraw.content((1.2, 7.7), [digit wheels], size: 6.5pt, anchor: "west")
  let wheels = (([x~2~ = 0], [mod 754974721]), ([x~1~ = 12345678], [mod 998244353]), ([x~0~ = 901234575], [mod 1000000007]))
  for (i, (d, m)) in wheels.enumerate() {
    let y = 6.4 - i * 1.3
    cdraw.rect((1.2, y - 0.45), (5.0, y + 0.45), fill: luma(235), radius: 0.06)
    cdraw.content((3.1, y + 0.1), d, size: 7pt)
    cdraw.content((3.1, y - 0.28), m, size: 6pt)
  }
  cdraw.content((5.7, 6.4), [v = 0], size: 6.5pt, anchor: "west")
  cdraw.content((5.7, 5.1), [v = 0 \* 998244353 + 12345678], size: 6pt, anchor: "west")
  cdraw.content((5.7, 3.8), [v = 12345678 \* 1000000007 + 901234575], size: 6pt, anchor: "west")
  cdraw.rect((5.7, 2.2), (14.4, 3.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.9, 2.65), [v = 12345678987654321], size: 7.5pt, anchor: "west")
  cdraw.content((15.4, 7.4), [digits mod m~i~ only,], size: 6pt, anchor: "west")
  cdraw.content((15.4, 6.85), [never the combined product], size: 6pt, anchor: "west")
  cdraw.content((15.4, 6.0), [any coprime moduli, 8 and 9 included], size: 6pt, anchor: "west")
  cdraw.content((15.4, 5.15), [inv(998244353 mod 754974721)], size: 6pt, anchor: "west")
  cdraw.content((15.4, 4.6), [416537774, ch29's pinned INV], size: 6pt, anchor: "west")
  cdraw.content((15.4, 3.75), [js rebuilds through BigInt, past 2^53], size: 6pt, anchor: "west")
  cdraw.content((15.4, 2.9), [2019/K modulus 2520 = 8 \* 9 \* 5 \* 7], size: 6pt, anchor: "west")
  cdraw.content((15.4, 2.05), [rebuild from the top, one fold per wheel], size: 6pt, anchor: "west")
})

== linear diophantine equations

The equation ax + by = c over the integers either has infinitely many
solutions or none, and gcd decides which: solvable exactly when
g = gcd(a, b) divides c. The extended euclid run already produces
x and y with ax + by = g, scaling both by c over g gives one
particular solution, and the full family steps by (b/g, -a/g), the
move that adds ab/g and subtracts ba/g, a net zero. The two practical
questions are then floor-and-ceiling arithmetic: shift the particular
solution to the family member with the smallest non-negative x by
one ceil division, and count the fully non-negative members by the
t-window where x stays at or past 0 and y stays at or past 0.

The dry run: the fixture is 39x + 15y = 12 solved end to end with
substitution asserted by the C\# suite, the count family pinned
beside it.

+ The euclid run on 39, 15 leaves g = 3, and 3 divides 12, so the
  line is solvable, the same test refusing 4x + 6y = 3.
+ Unwinding the quotients gives 39 × 2 + 15 × (-5) = 3, and scaling
  by 12 / 3 = 4 lands the particular (8, -20), checked
  39 × 8 + 15 × (-20) = 312 - 300 = 12.
+ The family steps by (b/g, -a/g) = (5, -13), each move adding
  39 × 5 = 195 and subtracting 15 × 13 = 195, a net zero.
+ Walking x down to the smallest non-negative: 8 - 5 = 3 lifts y to
  -20 + 13 = -7, the pinned (3, -7), and y negative with every step
  in either direction worse means 0 non-negative pairs.
+ The count family walks up instead: 2x + 3y = 10 lands (2, 2) then
  (5, 0) for its 2, and 3x + 5y = 30 lands (0, 6), (5, 3), (10, 0)
  for its 3.

#diagram([the family walk of 3x + 5y = 30 as a sequence, the three non-negative members stepping by (5, -3), the first equation's shift boxed beside it], length: 13pt, {
  // a small grid, x 0..10, y 0..6, with the three members and arrows
  let m = p => (2.4 + p.at(0) * 1.15, 1.0 + p.at(1) * 0.78)
  for x in range(0, 11) {
    for y in range(0, 7) {
      cdraw.circle(m((x, y)), radius: 0.035, fill: luma(190))
    }
  }
  let pts = ((0, 6), (5, 3), (10, 0))
  for (i, p) in pts.enumerate() {
    if i < 2 {
      let q = pts.at(i + 1)
      cdraw.line(m(p), m(q), stroke: 1.2pt + luma(60), mark: (end: ">"))
    }
    cdraw.circle(m(p), radius: 0.11, fill: luma(100))
    cdraw.content((m(p).at(0), m(p).at(1) + 0.42), [(#p.at(0), #p.at(1))], size: 6pt)
  }
  cdraw.content((8.2, 6.9), [3x + 5y = 30, three members], size: 6.5pt)
  cdraw.content((8.2, 6.1), [every step (5, -3)], size: 6pt)
  cdraw.content((8.2, 5.3), [the count is the t-window], size: 6pt)
  // the shift of the first equation
  cdraw.rect((14.2, 4.0), (19.4, 6.3), fill: luma(245), radius: 0.02)
  cdraw.content((16.8, 5.9), [39x + 15y = 12], size: 6.5pt)
  cdraw.content((16.8, 5.2), [(8, -20) shifts to (3, -7)], size: 6pt)
  cdraw.content((16.8, 4.5), [y negative, count 0], size: 6pt)
  cdraw.content((2.4, 0.2), [2x + 3y = 10 holds (2, 2) and (5, 0)], size: 6pt, anchor: "west")
})

The three pairs close the count at the pinned 3, and the listings
below solve the family in seven languages.

#listing("dsa/samples-c/src/Ch28/diophantine.c", first: 18, last: 66, caption: [c, iterative extgcd, the scaled solve, ceil and floor division, the minimal-x shift])

#listing("dsa/samples-go/ch28/diophantine.go", first: 9, last: 43, caption: [go, ch16 extgcd underneath, the negative-x shift into the fundamental window])

#listing("dsa/samples-java/src/Ch28/Diophantine.java", first: 19, last: 72, caption: [java, iterative extgcd, the scaled solve, truncating remainder with explicit ceil and floor corrections, the t-window count])

#listing("dsa/samples/src/Ch28/Diophantine.cs", first: 9, last: 48, caption: [c\#, solve, minimal non-negative x, and the count from one t-window])

#listing("dsa/samples-js/src/ch28-diophantine.mjs", first: 6, last: 36, caption: [javascript, recursive extgcd, the modular shift to minimal x])

#listing("dsa/samples-py/src/Ch28/diophantine.py", first: 16, last: 58, caption: [python, extgcd, the family shift, and the non-negative count])

#listing("dsa/samples-lua/ch28_diophantine.lua", first: 7, last: 45, caption: [lua, sign folds for negative coefficients, x reduced mod the step])

Fixtures pin three equations end to end, each particular solution
verified by substitution in-suite. 39x + 15y = 12 gives (8, -20),
2x + 3y = 10 gives (-10, 10), and 7x + 11y = 100 gives (-300, 200),
the extended euclid coefficients landing far from the first quadrant
and the shift doing the walking, java keeping its coefficients in
static fields with the same explicit ceil and floor corrections C
carries for a truncating remainder. Minimal non-negative x: the first
lands at (3, -7) with zero fully non-negative solutions, the second
at (2, 2) with exactly 2, the pairs (2, 2) and (5, 0), the third at
(8, 4) with exactly 1, and 3x + 5y = 30 lands at (0, 6) with 3, the
pairs (10, 0), (5, 3), (0, 6). Family spacing is asserted directly,
consecutive members differ by exactly (b/g, -a/g), which is (5, -13)
on the first equation. Edges: 4x + 6y = 3 refuses because gcd 2 does
not divide 3, zero coefficients solve on their own branches with 0x +
5y = 15 at (0, 3) and 5x + 0y = 15 at (3, 0). The contest kin: icpc
2023 problem A (book 10, chapter 12) solves an overdetermined integer
3 by 3 system whose triples have determinant 1 or 2, and the exact
two-variable theory here is the same no-rounding backbone. This is
general technique beyond that one problem.

#diagram([the line 39x + 15y = 12 through the lattice, solutions spaced (5, -13), the shaded quadrant holding none], length: 13pt, {
  let m = p => (2.6 + p.at(0) * 0.92, 1.1 + p.at(1) * 0.4)
  // first quadrant shading: x in [0, 4.5], y in [0, 6.5]
  cdraw.rect(m((0, 0)), m((4.5, 6.5)), fill: luma(240), radius: 0.02)
  for x in range(-3, 11) {
    for y in range(-4, 8) {
      cdraw.circle(m((x, y)), radius: 0.035, fill: luma(170))
    }
  }
  let pts = ((-2, 6), (3, -7), (8, -20), (13, -33))
  cdraw.line(m((-3, 8.5)), m((13.5, -33.9)), stroke: luma(100))
  for (i, p) in pts.enumerate() {
    cdraw.circle(m(p), radius: 0.09, fill: if i == 1 { luma(60) } else { luma(100) })
  }
  // labels placed on the clear side of each point, away from the steep line
  cdraw.content((m((-2, 6)).at(0) - 0.1, m((-2, 6)).at(1) - 0.55), [(-2, 6)], size: 6pt, anchor: "east")
  cdraw.content((m((3, -7)).at(0) - 0.15, m((3, -7)).at(1)), [(3, -7)], size: 6pt, anchor: "east")
  cdraw.content((m((8, -20)).at(0) - 0.15, m((8, -20)).at(1)), [(8, -20)], size: 6pt, anchor: "east")
  cdraw.content((m((13, -33)).at(0) + 0.15, m((13, -33)).at(1) + 0.4), [(13, -33)], size: 6pt, anchor: "west")
  cdraw.line(m((3, -7)), m((8, -20)), stroke: 1.2pt + luma(60), mark: (end: ">"))
  cdraw.content((m((8, -20)).at(0) + 0.2, m((8, -20)).at(1) - 0.45), [step (5, -13)], size: 6pt, anchor: "west")
  cdraw.content((m((8, -20)).at(0) + 0.2, m((8, -20)).at(1) - 1.0), [that is (b/g, -a/g)], size: 6pt, anchor: "west")
  cdraw.content((1.2, 7.6), [the shaded quadrant holds no solution], size: 6pt, anchor: "west")
  cdraw.content((1.2, 6.95), [minimal x >= 0 lands at (3, -7), y negative], size: 6pt, anchor: "west")
  cdraw.content((13.3, 4.6), [the particular (8, -20) comes], size: 6pt, anchor: "west")
  cdraw.content((13.3, 4.05), [from extgcd scaled by c/g], size: 6pt, anchor: "west")
  cdraw.content((13.3, 3.2), [solvable iff gcd(a, b) divides c], size: 6pt, anchor: "west")
  cdraw.content((13.3, 2.35), [count = one floor window in t], size: 6pt, anchor: "west")
  cdraw.content((13.3, 1.5), [2x + 3y = 10: two solutions], size: 6pt, anchor: "west")
  cdraw.content((13.3, 0.65), [3x + 5y = 30: three solutions], size: 6pt, anchor: "west")
})

== gray code and balanced ternary

Two numerations earn their keep by what they avoid. Gray code avoids
the multi-bit jump: gray(i) = i ^ (i >> 1), and adjacent codes differ
in exactly one bit, the bit where the underlying counter carries. The
inverse folds prefix xors back, each output bit is the parity of the
input bits above it, because the gray map xor-ed with its own right
shift returns the original. Balanced ternary avoids the sign bit
entirely: write integers in base 3 with digits -1, 0, and 1, printed
here as -, 0, and +. The encoder takes remainders and lifts a
remainder of 2 to the digit -1 with a carry of +1 into the next
division, decode is horner at base 3, negation is flipping every
digit, and k trits span exactly the interval from -(3^k - 1)/2 to
(3^k - 1)/2.

The dry run: the fixtures are the gray table over 0 to 15 and
gray(1234) = 1723 with the balanced ternary strings, asserted by the
C\# suite and identical in all seven.

+ gray folds one shift: i ^ (i >> 1) walks 0, 1, 3, 2, 6, 7, 5, 4
  across 0 to 7, each code one bit from its neighbor.
+ The inverse folds prefix xors back: gray 6 = 110 returns bit 1,
  then 1 ^ 1 = 0, then 0 ^ 0 = 0, landing 100 = 4.
+ gray(1234) = 1723 with ungray(1723) = 1234 round-trips, and
  ungray(1789) = 1193.
+ The ternary encoder walks 2026 by remainders, each row one mod and
  one divide, the lift firing once.
+ That lift is the interesting step: 8 mod 3 = 2 becomes the digit -
  with a carry, so the next n is (8 + 1) / 3 = 3.
+ The digits close at +0-+000+ and negation flips every sign for
  -0+-000-, while 1093 = (3^7 - 1) / 2 prints +++++++ and 1094
  needs the eighth trit.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*n*], [*n mod 3*], [*digit*], [*next n*]),
  [2026], [1], [+], [675],
  [675], [0], [0], [225],
  [225], [0], [0], [75],
  [75], [0], [0], [25],
  [25], [1], [+], [8],
  [8], [2], [- (carry)], [3],
  [3], [0], [0], [1],
  [1], [1], [+], [0],
)

The 1723 round trip closes the numerations, and the listings below
build both in seven languages.

#listing("dsa/samples-c/src/Ch28/graytern.c", first: 19, last: 61, caption: [c, the gray pair, then encode by remainder lift, decode by horner])

#listing("dsa/samples-go/ch28/graytern.go", first: 3, last: 33, caption: [go, the gray pair and the k-trit span walk, the encoder below])

#listing("dsa/samples-java/src/Ch28/Graytern.java", first: 17, last: 54, caption: [java, the gray pair with the bit-by-bit inverse fold, encode handling the lifted -1 and -2])

#listing("dsa/samples/src/Ch28/GrayTern.cs", first: 7, last: 50, caption: [c\#, the closed five-shift inverse fold, floored remainder lifted to -1])

#listing("dsa/samples-js/src/ch28-graytern.mjs", first: 7, last: 52, caption: [javascript, shifts inside 32-bit Number territory, js keeps the dividend sign on %])

#listing("dsa/samples-py/src/Ch28/graytern.py", first: 13, last: 58, caption: [python, the bit-by-bit inverse fold, encode with the r = 2 lift])

#listing("dsa/samples-lua/ch28_graytern.lua", first: 5, last: 47, caption: [lua, the doubling-shift fold, chunks cut from the right])

The remainder-lift branch structure differs by language because %
differs, C, Go, JavaScript, and Java keep the dividend's sign so their
encoders handle a lifted -1 and a lifted -2, Python and Lua floor, so
only r = 2 ever needs lifting, and C\# normalizes into 0, 1, 2 first.
All seven pin the same strings. The gray table over 0 to 15 reads 0, 1,
3, 2, 6, 7, 5, 4, 12, 13, 15, 14, 10, 11, 9, 8, gray(1234) = 1723
with ungray(1723) = 1234 and ungray(1789) = 1193, and the sweeps
assert one-bit adjacency and round trips across 0 to 999. The
balanced ternary encodings, identical digit strings in all six:
2026 is +0-+000+, -2026 is -0+-000-, 121393 is +-0+-----00+, 1093 is
+++++++, -1093 is -------, 547 is +-+-+-+, and 0, 1, -1 are 0, +, -.
The edge is the span: (3^7 - 1)/2 = 1093 is the 7-trit maximum, all
plus signs, and 1094 needs 8 trits, with round-trip and
negation-by-flip sweeps over -2000 to 2000. No finals problem called
for either numeration, they are general technique.

#diagram([the 4-bit gray cycle as a 16-node ring, beside the trit place values stacking 2026], length: 13pt, {
  let vals = (0, 1, 3, 2, 6, 7, 5, 4, 12, 13, 15, 14, 10, 11, 9, 8)
  let c = (3.4, 4.4)
  for i in range(16) {
    let ang = 90 - i * 22.5
    let rad = ang * calc.pi / 180
    let p = (c.at(0) + 2.5 * calc.cos(rad), c.at(1) + 2.5 * calc.sin(rad))
    if i > 0 {
      let pang = 90 - (i - 1) * 22.5
      let prad = pang * calc.pi / 180
      let q = (c.at(0) + 2.5 * calc.cos(prad), c.at(1) + 2.5 * calc.sin(prad))
      cdraw.line(p, q, stroke: luma(170))
    }
    cdraw.circle(p, radius: 0.26, fill: if i == 0 { luma(205) } else { luma(245) }, stroke: luma(140))
    cdraw.content(p, [#vals.at(i)], size: 6pt)
  }
  let pang0 = 90 - 15 * 22.5
  let q0 = (c.at(0) + 2.5 * calc.cos(pang0 * calc.pi / 180), c.at(1) + 2.5 * calc.sin(pang0 * calc.pi / 180))
  cdraw.line(q0, (c.at(0) + 2.5 * calc.cos(90 * calc.pi / 180), c.at(1) + 2.5 * calc.sin(90 * calc.pi / 180)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((3.4, 7.6), [adjacent codes differ in one bit], size: 6pt)
  cdraw.content((3.4, 0.7), [the ring closes 8 back to 0], size: 6pt)
  // right: the trit places over 2026
  cdraw.content((12.6, 7.6), [2026 in balanced ternary], size: 6.5pt)
  let places = (2187, 729, 243, 81, 27, 9, 3, 1)
  let digs = ([+], [0], [-], [+], [0], [0], [0], [+])
  for (i, pl) in places.enumerate() {
    let x = 8.3 + i * 1.12
    cdraw.rect((x, 4.6), (x + 1.0, 5.5), fill: if digs.at(i) == [+] { luma(225) } else if digs.at(i) == [-] { luma(205) } else { luma(245) }, radius: 0.02)
    cdraw.content((x + 0.5, 5.05), digs.at(i), size: 7pt)
    cdraw.content((x + 0.5, 4.25), [#pl], size: 5.5pt)
  }
  cdraw.content((12.7, 3.55), [2187 - 243 + 81 + 1 = 2026], size: 6pt)
  cdraw.content((12.7, 2.75), [k trits span +-(3^k - 1) / 2], size: 6pt)
  cdraw.content((12.7, 1.95), [1093 = +++++++ is the 7-trit max], size: 6pt)
  cdraw.content((12.7, 1.15), [negate by flipping every digit], size: 6pt)
  cdraw.content((12.7, 0.35), [gray: i ^ (i >> 1), inverse by prefix xor], size: 6pt)
})

== continued fractions, convergents, and the stern-brocot tree

The euclidean algorithm divides and keeps quotients, and those
quotients are a numeration: p over q equals the continued fraction
whose terms are the quotients in order. The convergents, the values
of each prefix, approximate the fraction from alternating sides and
satisfy a two-term recurrence, h~i~ = a~i~ h~i-1~ + h~i-2~ and the
same for k, off the seeds h = 1, 0 and k = 0, 1, and the last
convergent is the fraction itself. Square roots have no finite
expansion but a periodic one, computed exactly by the (m, d, a) state
machine on integers, no floating point anywhere, closing when a term
reaches twice the integer square root. The same tree organizes all
positive rationals: the stern-brocot tree starts at 1 over 1 between
the bounds 0/1 and 1/0, each step compares the target with the
mediant of the bounds and descends left or right, every positive
rational appears exactly once, and the path is a finite L/R string.
Read the tree's levels in order and the farey sequence falls out,
each next term computable from the previous two by one division.

The dry run: the fixture is 415/93 asserted term by term with its
convergents by the C\# suite, the stern-brocot path to 5/7 pinned
beside it.

+ The euclid quotients are the terms: 415 = 4 × 93 + 43,
  93 = 2 × 43 + 7, 43 = 6 × 7 + 1, then 7 = 7 × 1, so cf reads
  4, 2, 6, 7.
+ The convergent recurrence folds off the seeds: h = 2 × 4 + 1 = 9
  with k = 2 × 1 + 0 = 2, then 6 × 9 + 4 = 58 with 6 × 2 + 1 = 13,
  closing 7 × 58 + 9 = 415 with 7 × 13 + 2 = 93.
+ The four rungs read 4/1, 9/2, 58/13, 415/93, alternating above and
  below the value, the last the fraction itself.
+ The tree walk to 5/7 opens at the mediant 1/1 and descends left,
  5 × 1 < 7 × 1.
+ Against 1/2 the cross products 10 and 7 point right, against 2/3
  the pair 15 and 14 points right again, and against 3/4 the pair
  20 and 21 points left, the path LRRL.
+ The new mediant of 2/3 and 3/4 is 5/7 itself, the landing, and F5
  keeps its 11 terms with every neighbor determinant 1.

#diagram([the division cascade on the left, each euclid step yielding one term, the convergent ladder climbing on the right, one rung per term], length: 13pt, {
  // the cascade: 415 -> 93 -> 43 -> 7 -> 1 with the quotients
  let steps = ((415, 93, 4, 43), (93, 43, 2, 7), (43, 7, 6, 1), (7, 1, 7, 0))
  for (i, st) in steps.enumerate() {
    let (a, b, q, r) = st
    let y = 6.8 - i * 1.15
    cdraw.content((1.4, y), [#a], size: 6.5pt, fill: if i == 0 { black } else { black })
    cdraw.content((2.9, y), [\= #q × #b + #r], size: 6pt)
    cdraw.rect((5.6, y - 0.3), (6.6, y + 0.3), fill: luma(205), radius: 0.02)
    cdraw.content((6.1, y), [#q], size: 6.5pt)
    if r > 0 { cdraw.line((2.4, y - 0.4), (2.4, y - 0.75), stroke: (paint: luma(160), dash: "dashed")) }
  }
  cdraw.content((3.4, 8.1), [the division cascade], size: 6.5pt)
  cdraw.content((6.1, 7.5), [terms], size: 6pt)
  // the convergent ladder
  let rungs = ((4, 1), (9, 2), (58, 13), (415, 93))
  for (i, rk) in rungs.enumerate() {
    let y = 5.6 - i * 1.4
    cdraw.rect((10.6, y - 0.4), (13.8, y + 0.4), fill: if i == 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((12.2, y), [#rk.at(0) / #rk.at(1)], size: 6.5pt)
    cdraw.content((14.1, y), [rung #(i + 1)], size: 6pt, anchor: "west")
    if i > 0 { cdraw.line((12.2, y + 0.5), (12.2, y + 0.9), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((12.2, 8.1), [the convergents climb], size: 6.5pt)
  cdraw.content((10.6, 0.6), [9 = 2 × 4 + 1, 58 = 6 × 9 + 4], size: 6pt, anchor: "west")
  cdraw.content((10.6, -0.2), [the walk to 5/7: L R R L], size: 6pt, anchor: "west")
})

The 415/93 closes as its own last convergent, and the listings
below build all three faces in seven languages.

#listing("dsa/samples-c/src/Ch28/cfrac.c", first: 45, last: 91, caption: [c, the periodic sqrt machine on exact integers, then the stern-brocot walk])

#listing("dsa/samples-go/ch28/cfrac.go", first: 16, last: 52, caption: [go, convergents and the sqrt cycle with its period length])

#listing("dsa/samples-java/src/Ch28/Cfrac.java", first: 49, last: 87, caption: [java, the (m, d, a) sqrt machine on exact longs, then the stern-brocot walk keeping bounds])

#listing("dsa/samples/src/Ch28/CFrac.cs", first: 19, last: 51, caption: [c\#, the convergent recurrence and the (m, d, a) cycle as head plus period])

#listing("dsa/samples-js/src/ch28-cfrac.mjs", first: 35, last: 68, caption: [javascript, the sqrt machine and the mediant walk, floor keeps it exact])

#listing("dsa/samples-py/src/Ch28/cfrac.py", first: 25, last: 63, caption: [python, convergents, the sqrt machine, the walk, and farey in four small functions])

#listing("dsa/samples-lua/ch28_cfrac.lua", first: 16, last: 62, caption: [lua, the walk keeps the current node and compares cross-multiplied])

Fixtures pin all three faces of the structure. The rational
expansions: cf of 415/93 is 4, 2, 6, 7 with convergents 4/1, 9/2,
58/13, 415/93, cf of 10/7 is 1, 2, 3 with convergents 1/1, 3/2,
10/7, and cf of 355/113 is 3, 7, 16, the approximation constant
wearing its expansion. The periodic square roots: sqrt(19) gives 4
then the period 2, 1, 3, 1, 2, 8, sqrt(2) gives 1 then 2 with period
1, and sqrt(61) gives 7 then a period of eleven terms closing on 14.
The tree: the path to 5/7 is LRRL, to 8/13 is LRLRL, to 3/8 is LLRL,
and the root 1/1 walks the empty path. F5 holds its 11 terms 0/1,
1/5, 1/4, 1/3, 2/5, 1/2, 3/5, 2/3, 3/4, 4/5, 1/1, every adjacent
pair satisfies the neighbor invariant with determinants exactly 1 in
absolute value, and python closes the loop by checking the last
convergent of each farey term equals the term. No finals problem
needed these, they are general technique with a long half-life under
any approximation question.

#diagram([415/93 walked down the stern-brocot tree, path RRRRLLRRRRRRLLLLLL, the convergents 9/2 and 58/13 met on the way], length: 13pt, {
  let nodes = (([1/1], 0), ([2/1], 0), ([3/1], 0), ([4/1], 0), ([5/1], 0), ([9/2], 1), ([13/3], 0), ([22/5], 0), ([31/7], 0), ([40/9], 0), ([49/11], 0), ([58/13], 1), ([67/15], 0), ([125/28], 0), ([183/41], 0), ([241/54], 0), ([299/67], 0), ([357/80], 0), ([415/93], 2))
  let letters = ([R], [R], [R], [R], [L], [L], [R], [R], [R], [R], [R], [R], [L], [L], [L], [L], [L], [L])
  let xy = (i) => (1.4 + i * 1.05, 6.1 - i * 0.42)
  for (i, (lab, hot)) in nodes.enumerate() {
    let (x, y) = xy(i)
    if i > 0 {
      let (px, py) = xy(i - 1)
      // the step letter rides to the right of the upper label, clear of both
      cdraw.content((px + 0.68, py - 0.08), [#letters.at(i - 1)], size: 6pt, anchor: "west", fill: luma(100))
    }
    if hot > 0 {
      cdraw.rect((x - 0.62, y - 0.2), (x + 0.62, y + 0.2), fill: if hot == 2 { luma(120) } else { luma(205) }, radius: 0.02)
    }
    cdraw.content((x, y), lab, size: 5.5pt, fill: if hot == 2 { white } else { black })
  }
  cdraw.content((1.4, 7.6), [start at 1/1, compare with the mediant, descend], size: 6pt, anchor: "west")
  cdraw.content((1.4, 7.0), [bounds 0/1 and 1/0 tighten every step], size: 6pt, anchor: "west")
  cdraw.content((13.7, 6.2), [path RRRRLLRRRRRRLLLLLL], size: 6pt, anchor: "west")
  cdraw.content((13.7, 5.55), [18 steps, 19 nodes], size: 6pt, anchor: "west")
  cdraw.content((13.7, 4.7), [9/2 and 58/13 are the], size: 6pt, anchor: "west")
  cdraw.content((13.7, 4.15), [convergents of [4, 2, 6, 7]], size: 6pt, anchor: "west")
  cdraw.content((13.7, 3.3), [runs of one letter], size: 6pt, anchor: "west")
  cdraw.content((13.7, 2.75), [match the cf terms], size: 6pt, anchor: "west")
  cdraw.content((13.7, 1.9), [F5 neighbors: |ad - bc| = 1], size: 6pt, anchor: "west")
  cdraw.content((1.4, 0.6), [sqrt periods stay on exact integers,], size: 6pt, anchor: "west")
  cdraw.content((1.4, 0.0), [sqrt(61) closes at period 11, sqrt(2) at 1], size: 6pt, anchor: "west")
})

== across the seven languages

Build size counts non-blank, non-comment lines over the chapter's
eight sample files per language, embedded checks included:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [858], [libc only], [static tables to 1000 and cap 512 limbs of scratch, add-and-double mulmod with a remainder every step because rho moduli reach 4.6e18],
  [c\#], [494], [bcl, Ch16 NumTheory], [UInt128 carries every product past 2^63, NumTheory and the rho lcg shared by import, refusals throw],
  [go], [563], [dsabook/ch16], [MulMod and ModPow from ch16 over bits.Mul64, errors name the cause, one package for all eight files],
  [java], [839], [jdk 27 stdlib], [self-contained files, the ch16 helpers re-carried inline, add-and-double mulmod with rho draws through `Long.remainderUnsigned`, plain long products at the 1e9+7 moduli, rebuild under 2^63],
  [javascript], [399], [node stdlib], [BigInt at each named boundary: rho moduli, dlog modmul at 1e9+7, the garner rebuild past 2^53],
  [python], [627], [stdlib only], [native ints, three-argument pow as the ground-truth cross-check, phi sieved in place by subtraction in 28.3],
  [lua], [693], [lib.lua harness], [1-based tables documented per file, add-and-double mulmod keeps products under 2^63, error() carries refusals],
)

sources: the cp-algorithms articles, all cc by-sa 4.0, rewritten in
our own words, accessed 2026-09-20: "Linear Sieve" and "Euler's
totient function" for 28.1, "Primality tests" and "Integer
factorization" for 28.2, "Number of divisors / sum of divisors" for
28.3, "Discrete Logarithm" and "Primitive Root" for 28.4, "Garner's
Algorithm" and "Factorial modulo p" for 28.5, "Linear Diophantine
Equations" and "Extended Euclidean Algorithm" for 28.6, "Gray code"
and "Balanced Ternary" for 28.7, and "Continued fractions" plus "The
Stern-Brocot tree and Farey sequences" for 28.8, at
cp-algorithms.com/algebra/prime-sieve-linear.html, phi-function.html,
primality_tests.html, factorization.html, divisors.html,
discrete-log.html, primitive-root.html, garners-algorithm.html,
factorial-modulo.html, linear-diophantine-equation.html,
extended-euclid-algorithm.html, gray-code.html, balanced-ternary.html,
continued-fractions.html, and
cp-algorithms.com/others/stern_brocot_tree_farey_sequences.html.
Mobius has no cp-algorithms article, the table treatment follows
Hardy and Wright, An Introduction to the Theory of Numbers. The icpc
problems named as applications: 2025 F and B, 2019 K, and 2023 A,
pinned in the icpc book. Sample behavior verified by the seven suite
gates scoped to chapter 28: c 8 files and 142 checks, c\# 57 facts,
go 26 tests, java 8 files and 228 checks, javascript 26 tests,
python 8 files and 113 asserts,
lua 32 checks, zero skipped. This chapter carries 56 listings and 8
figures.
