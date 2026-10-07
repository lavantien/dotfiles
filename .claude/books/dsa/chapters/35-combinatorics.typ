#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= combinatorics

Counting is its own skill, separate from finding and optimizing, and
this chapter is the counting course. Binomial tables come first
because half the sections stand on them, then catalan numbers, stars
and bars, and inclusion-exclusion, the four engines. Burnside counts
under symmetry, k-subset generation walks objects in order, sperner
bounds antichains, the frobenius problem counts what coin systems
cannot reach, and josephus counts around a circle. The back half
applies the engines: bishops on a chessboard by a per-color dp,
balanced brackets by ballot numbers, labeled graphs by an exponential
recurrence, and one prose-only stop at the fifteen puzzle, whose
solvability test is a single parity predicate with nothing to port.
Chapter 16 owns the modular arithmetic underneath, and the mobius
table rides in from #xref-to("dsa", "numtheory2").

== binomial tables on three roads

One value, three representations, three jobs. The modular road builds
factorial and inverse-factorial tables over a prime, one forward pass
and one backward pass seeded by a fermat inverse, and then answers
C(n, k) mod p in constant time as three table lookups and two
multiplies. The exact road runs the product ladder, multiply by
n - i and divide by i + 1 at each step, and stays an integer at every
step because each prefix divides evenly. The log-space road keeps a
cumulative lnfact table and compares binomials by ln of the value,
tolerance-based, the only road that ranks C(999, 500) against its
neighbors when the integer itself has 299 decimal digits. The p-adic
road reads the exponent of a prime in the answer off legendre's sum,
the difference of three floor-sums.

The dry run: the fixture is the four-road anchor set of the C\# suite,
with C and Java pinning the same modular digits and javascript riding
BigInt past its 2^53 ceiling.

+ The exact ladder walks C(10, 3) one dividing step at a time:
  1 × 10 / 1 = 10, then 10 × 9 / 2 = 45, then 45 × 8 / 3 = 120.
+ The modular road answers from the tables: C(1000, 500) = 159835829
  as fact × invfact × invfact, and the row sanity sum over k of
  C(30, k) = 2^30 with C(30, 15) = 155117520.
+ The ln road subtracts cumulative logs, lnf 1000 - 2 × lnf 500 =
  689.467261567851, the table and a direct log sum agreeing to 1e-9.
+ The p-adic road reads legendre's floors: 50 + 25 + 12 + 6 + 3 + 1 =
  97 for 100, 25 + 12 + 6 + 3 + 1 = 47 for 50, and 97 - 2 × 47 = 3.
+ So C(100, 50) is 2^3 times an odd part, and that part carries the
  residue 538992043.
+ The exact ceilings pin the boundary: C(62, 31) = 465428353255261088
  holds and C(67, 33) refuses past 2^63.

#table(
  columns: (auto, 1.9fr, 1.6fr),
  inset: 4pt,
  table.header([*road*], [*the walk*], [*pinned landing*]),
  [modular], [fact × invfact × invfact], [C(1000,500) = 159835829],
  [exact], [1 × 10 / 1 = 10, then 45 × 8 / 3 = 120], [C(10,3) = 120],
  [ln], [lnf1000 - 2 lnf500], [689.467261567851],
  [p-adic], [97 - 2 × 47 = 3], [v2 of C(100,50) = 3],
)

The 120, the 159835829, and the 3 are the asserted landings, and the
listings below build all four roads in seven languages.

#listing("dsa/samples-c/src/Ch35/binom.c", first: 43, last: 78, caption: [c, both table builds, the O(1) query, the legendre sum])

#listing("dsa/samples-go/ch35/binom.go", first: 28, last: 54, caption: [go, the cached table pair, the query, the 128-bit exact ladder below])

#listing("dsa/samples-java/src/Ch35/Binom.java", first: 42, last: 77, caption: [java, both prime-pair table builds, the O(1) query, the legendre sum])

#listing("dsa/samples/src/Ch35/Binom.cs", first: 18, last: 60, caption: [c\#, the tables and ln table in one constructor, the exact ladder through UInt128])

#listing("dsa/samples-js/src/ch35-binom.mjs", first: 22, last: 56, caption: [javascript, BigInt tables, the fermat inverse from the top, the ladder on BigInt past C(56,28)])

#listing("dsa/samples-py/src/Ch35/binom.py", first: 20, last: 42, caption: [python, the table build, the query, the exact ladder])

#listing("dsa/samples-lua/ch35_binom.lua", first: 28, last: 63, caption: [lua, the two passes, the query, the overflow-guarded ladder returning nil past 2^63])

The fixtures pin all four roads against each other. Modular:
C(10,3) = 120; C(1000,500) mod 1e9+7 = 159835829; the same value
mod 998244353, one of the chapter 29 transform primes, = 640488516,
a digit the alignment brief originally carried differently and two
independent exact roads disproved, so the proven value is what the
suites pin; the row sanity sum over k of C(30,k) = 2^30 with
C(30,15) = 155117520. Exact and boundary: C(62,31) =
465428353255261088; C(66,33) = 7219428434016265740 is the last
central binomial under 2^63 and C(67,33) = 14226520737620288370
crosses, java pinning it through Long.parseUnsignedLong with the
identical decimal string and comparing unsigned, with javascript's
own ceiling at n = 56, C(56,28) =
7648690600760440, the last under 2^53, its ladder riding BigInt from
there. Log and p-adic: ln C(1000,500) = 689.467261567851 within
1e-9, the cumulative table and the lgamma road agreeing to 9e-13
where the language has lgamma, java's stdlib shipping none so its
twin runs a nine-coefficient lanczos series and agrees with the
summed table to 1e-9; v2 of C(100,50) = 3, read as 97 - 2
times 47 by legendre, and the exact 30-digit value 1008913445455641
93334812497256 pins as 2^3 times an odd number with residue
538992043 mod 1e9+7.

Two finals problems ride this section. Icpc world finals 2018
problem D (book 10, chapter 9), gem island, prices its drop recursion
in floats from an lnfact table because the raw binomials near
C(999,500) overflow doubles before the division. Icpc world finals
2023 problem B (book 10, chapter 12), schedule, searches for the
smallest k with C(k-1, ceil(k/2)) at least n, the modular road with
the search loop living in the k-subset section below.

#diagram([one value C(100,50) on three roads: the 30-digit exact integer, its residue, its log], length: 13pt, {
  // the three roads as three panels over C(100,50)
  let panel = (x0, title, lines, hot: -1) => {
    cdraw.rect((x0, 4.2), (x0 + 5.6, 7.2), fill: luma(240), radius: 0.04, stroke: luma(180))
    cdraw.content((x0 + 2.8, 6.85), title, size: 6.5pt)
    for (i, l) in lines.enumerate() {
      cdraw.content((x0 + 2.8, 6.2 - i * 0.62), l, size: if i == hot { 6.5pt } else { 6pt })
    }
  }
  panel(0.8, [exact ladder], ([1008913445455641933348], [124972256], [30 digits, 2^3 \* odd]), hot: 0)
  panel(7.0, [mod 1e9+7], ([fact \* invfact], [C(100,50) = 538992043], [O(1) after O(n) tables]), hot: 1)
  panel(13.2, [ln space], ([lnf100 - 2 lnf50], [ln C(100,50) = 66.78], [ranks C(999,500): 689.47]))
  cdraw.content((13.2, 3.6), [v~2~ = 97 - 2 \* 47 = 3], size: 6pt)
  cdraw.content((9.0, 3.2), [the same value answers different questions on each road], size: 6pt)
  cdraw.content((9.0, 2.4), [exact: the integer itself, to the 2^53 or 2^63 ceiling], size: 6pt)
  cdraw.content((9.0, 1.6), [modular: identities and searches, 2018/D and 2023/B], size: 6pt)
  cdraw.content((9.0, 0.8), [ln: ranking values too large to hold], size: 6pt)
})

== catalan numbers

The catalan numbers count everything nested: balanced bracket
shapes, triangulations, binary trees, mountain profiles. Two roads
compute them, and the sweep proving the roads equal is the fixture
that matters. The closed form reads C~n~ = C(2n, n) over n + 1
straight off the binomial tables, one modular inverse. The
convolution recurrence builds the row bottom up, C~n+1~ = sum over i
of C~i~ C~n-i~, each number folding from the two halves of everything
shorter, O(n^2) against the closed form's O(1) after tables.

The dry run: the fixture is the row C~0~ through C~10~ with the sweep
and the two rungs, asserted by the C\# suite; lua lands C~20~ by its
own exact ladder, C(40, 20) = 137846528820 over 21.

+ The convolution folds from C~0~ = 1: C~1~ = 1 × 1 = 1, C~2~ = 1 × 1
  + 1 × 1 = 2, C~3~ = 1 × 2 + 1 × 1 + 2 × 1 = 5.
+ C~4~ pairs every short prefix against its mirror: 1 × 5 + 1 × 2 +
  2 × 1 + 5 × 1 = 14, and C~5~ reads 14 + 5 + 4 + 5 + 14 = 42.
+ The row runs on to C~10~ = 16796, and the sweep asserts recurrence
  against closed form for every n to 30.
+ The closed form lands the same numbers off the tables: C(8, 4) = 70
  and 70 / 5 = 14, C(10, 5) = 252 and 252 / 6 = 42.
+ Exact C~20~ = 6564120420 while C~30~ mod 1e9+7 = 475387402.

#diagram([the C~4~ fold as four mirrored products summing into 14], length: 13pt, {
  let vals = (1, 1, 2, 5)
  for (i, v) in vals.enumerate() {
    let x = 1.6 + i * 2.7
    cdraw.rect((x - 0.5, 5.7), (x + 0.5, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x, 6.1), [#v], size: 6.5pt)
    cdraw.content((x, 5.25), [C~#i~], size: 6pt)
  }
  let prods = ((0, 3), (1, 2), (2, 1), (3, 0))
  for (j, p) in prods.enumerate() {
    let x = 2.3 + j * 2.7
    cdraw.rect((x - 1.0, 3.3), (x + 1.0, 4.5), fill: luma(238), radius: 0.02)
    cdraw.content((x, 4.15), [C~#(p.at(0))~ × C~#(p.at(1))~], size: 6pt)
    cdraw.content((x, 3.7), [#(vals.at(p.at(0))) × #(vals.at(p.at(1)))], size: 6.5pt)
  }
  cdraw.rect((3.0, 1.6), (9.6, 2.5), fill: luma(205), radius: 0.02)
  cdraw.content((6.3, 2.05), [5 + 2 + 2 + 5 = 14], size: 6.5pt)
  cdraw.content((6.3, 0.7), [C~5~: 14 + 5 + 4 + 5 + 14 = 42], size: 6pt)
  cdraw.content((15.6, 5.4), [fold i against n - i], size: 6pt)
  cdraw.content((15.6, 4.2), [C(10,5) / 6 = 42, the same 42], size: 6pt)
  cdraw.content((15.6, 3.0), [C~30~ mod 1e9+7 = 475387402], size: 6pt)
  cdraw.content((15.6, 1.8), [O(n^2) adds, one inverse], size: 6pt)
})

The 14, the 42, and the 6564120420 are the pinned landings, and the
listings below build both roads in seven languages.

#listing("dsa/samples-c/src/Ch35/catalan.c", first: 50, last: 81, caption: [c, the closed form, the table anchors, the recurrence sweep and agreement check])

#listing("dsa/samples-go/ch35/catalan.go", first: 6, last: 32, caption: [go, closed form, exact form, the recurrence])

#listing("dsa/samples-java/src/Ch35/Catalan.java", first: 43, last: 53, caption: [java, binom and the closed form, the recurrence array swept in main])

#listing("dsa/samples/src/Ch35/Catalan.cs", first: 18, last: 31, caption: [c\#, the closed form from the binomial class, the recurrence below it])

#listing("dsa/samples-js/src/ch35-catalan.mjs", first: 12, last: 30, caption: [javascript, the closed form as C(2n,n) - C(2n,n+1), no inverse needed, and the recurrence])

#listing("dsa/samples-py/src/Ch35/catalan.py", first: 40, last: 52, caption: [python, the closed form, the convolution recurrence])

#listing("dsa/samples-lua/ch35_catalan.lua", first: 31, last: 44, caption: [lua, the closed form and the recurrence, C~0~ at lua index 1])

The fixtures pin the row C~0~ through C~10~ as 1, 1, 2, 5, 14, 42,
132, 429, 1430, 4862, 16796, exact C~20~ = 6564120420, C~30~ mod
1e9+7 = 475387402, and the sweep asserting the recurrence equals the
closed form for every n up to 30. The interpretations read off the
row: triangulations of a hexagon = C~4~ = 14, binary trees on 5
nodes = C~5~ = 42, and C~0~ = 1 counting the one empty object. The
javascript port computes the closed form as C(2n,n) - C(2n,n+1),
which needs no division at all, and lua carries the exact ladder
inline, C(40,20) = 137846528820 divided by 21 landing the same
6564120420. This is a general technique section, the counting shape
beneath the bracket section and the nesting facet of icpc world
finals 2019 problem D (book 10, chapter 10).

#diagram([triangulations of a convex (n+2)-gon count as C~n~: the hexagon's 14 (C~4~) with one fan drawn], length: 13pt, {
  // hexagon with a fan from vertex 0
  let cx = 4.2
  let cy = 5.6
  let r = 1.7
  let pt = (k) => (cx + r * calc.cos(k * 60deg + 90deg), cy + r * calc.sin(k * 60deg + 90deg))
  let hex = range(6).map(pt)
  cdraw.line(..hex, close: true, stroke: luma(100), fill: luma(242))
  // fan from vertex 0 to vertices 2, 3, 4
  for k in (2, 3, 4) {
    cdraw.line(pt(0), pt(k), stroke: luma(150))
  }
  for k in range(6) {
    cdraw.circle(pt(k), radius: 0.09, fill: luma(100))
  }
  cdraw.content((cx, cy + r + 0.7), [the hexagon, n + 2 = 6 sides], size: 6.5pt)
  cdraw.content((cx, cy - r - 0.6), [fan from one vertex: 3 diagonals], size: 6pt)
  cdraw.content((cx, cy - r - 1.3), [all fans and non-fans: C~4~ = 14], size: 6pt)
  // the row beside it
  cdraw.content((12.6, 7.2), [C~0..10~:], size: 6.5pt)
  cdraw.content((12.6, 6.5), [1 1 2 5 14 42 132 429], size: 6.5pt)
  cdraw.content((12.6, 5.8), [1430 4862 16796], size: 6.5pt)
  cdraw.content((12.6, 4.7), [closed form: C(2n,n) / (n+1)], size: 6pt)
  cdraw.content((12.6, 3.9), [recurrence: C~n+1~ = sum C~i~ C~n-i~], size: 6pt)
  cdraw.content((12.6, 3.1), [equal for all n <= 30, swept], size: 6pt)
  cdraw.content((12.6, 2.3), [C~20~ = 6564120420 exact], size: 6pt)
  cdraw.content((12.6, 1.5), [binary trees on 5 nodes: 42], size: 6pt)
})

== stars and bars with bounds

Compositions of n into k non-negative parts count as C(n + k - 1,
k - 1), the bars choosing their slots among the stars. Requiring
positive parts burns one unit per part and lands C(n - 1, k - 1).
Upper bounds are where the work is: subtract the arrangements where
some part exceeds the cap, by inclusion-exclusion over the set of
violated parts, each subset of size s contributing C(k, s) times the
shifted count with s caps plus one removed,

sum over s of (-1)^s C(k, s) C(n - s(cap+1) + k - 1, k - 1).

The dry run: the fixtures are both identities and the two bounded
counts, asserted by the C\# suite with its own nested-loop brute
counting the same tuples.

+ Unbounded first: 10 stars cut by 2 bars gives C(12, 2) = 66
  arrangements, and positive parts burn 3 units for C(9, 2) = 36.
+ The bounded walk on 20 into 3 with cap 10 keeps a running total:
  s = 0 adds C(22, 2) = 231, s = 1 subtracts 3 × C(11, 2) = 165, and
  s = 2 dies at 20 - 22 below zero, landing 231 - 165 = 66.
+ The s = 1 term reads one violated part holding 11 of the 20, 9
  stars left, C(11, 2) = 55 arrangements, 3 choices of violator.
+ The 4-part walk on 30 with cap 10 swings negative first: s = 0 adds
  C(33, 3) = 5456, s = 1 subtracts 4 × 1540 = 6160 for -704, s = 2
  adds 6 × 165 = 990, landing 286.
+ The brute twins enumerate every capped tuple and agree, 66 and 286,
  and the edges hold: k = 1 counts 1 while n fits the cap, x + y = 5
  with cap 2 gives 0.

#table(
  columns: (1.5fr, auto, 1.5fr, auto),
  inset: 4pt,
  table.header([*fixture*], [*s*], [*term*], [*running*]),
  [20 into 3, cap 10], [0], [+ C(22,2) = +231], [231],
  [20 into 3, cap 10], [1], [- 3 C(11,2) = -165], [66],
  [30 into 4, cap 10], [0], [+ C(33,3) = +5456], [5456],
  [30 into 4, cap 10], [1], [- 4 C(22,3) = -6160], [-704],
  [30 into 4, cap 10], [2], [+ 6 C(11,3) = +990], [286],
)

Both bounded answers, 66 and 286, survive their brute twins, and the
listings below build the three counters in seven languages.

#listing("dsa/samples-c/src/Ch35/starsbars.c", first: 51, last: 80, caption: [c, the two identities, the bounded IE loop in modular arithmetic])

#listing("dsa/samples-go/ch35/starsbars.go", first: 5, last: 33, caption: [go, the same three over the cached tables])

#listing("dsa/samples-java/src/Ch35/Starsbars.java", first: 50, last: 75, caption: [java, the two identities, the bounded IE loop with p added before the subtraction])

#listing("dsa/samples/src/Ch35/StarsBars.cs", first: 13, last: 32, caption: [c\#, the three counters over the binomial class, the IE loop breaking on negative remainder])

#listing("dsa/samples-js/src/ch35-starsbars.mjs", first: 7, last: 27, caption: [javascript, the small exact ladder and the three counters on it])

#listing("dsa/samples-py/src/Ch35/starsbars.py", first: 24, last: 41, caption: [python, the three counters, the IE sum over violated parts])

#listing("dsa/samples-lua/ch35_starsbars.lua", first: 32, last: 56, caption: [lua, the three counters and the IE loop, brute tuples below])

The fixtures pin both identities and the bounded form.
Compositions of 10 into 3 = 66 = C(12,2), positive ones = 36 =
C(9,2). Bounded: x + y + z = 20 with each at most 10 gives 66, the
IE terms reading C(22,2) - 3 C(11,2) = 231 - 165, and x + y + z +
w = 30 with each at most 10 gives 286 as C(33,3) - 4 C(22,3) +
6 C(11,3), both brute-counted in-suite by nested loops. The edges
read k = 1 as 1 exactly when n fits the cap, n = 0 into k parts as
the one all-zero tuple, and x + y = 5 each at most 2 as 0, the
impossible bound. The application is icpc world finals 2018 problem
D (book 10, chapter 9) again, whose drop allocations are compositions
walking this bounded and unbounded ladder in log space.

#diagram([10 stars cut by 2 bars into one of the 66 arrangements, a bounded row struck out by the IE term], length: 13pt, {
  // stars and bars row
  let row = ("*", "*", "*", "|", "*", "*", "*", "*", "|", "*", "*", "*")
  for (i, c) in row.enumerate() {
    let x = 0.8 + i * 0.62
    cdraw.content((x, 6.6), c, size: 9pt)
  }
  cdraw.content((4.5, 7.4), [3 parts: 3, 4, 5 stars, one of C(12,2) = 66], size: 6.5pt)
  // a violated row struck out
  let bad = ("*", "*", "*", "*", "*", "*", "*", "*", "*", "*", "|", "|")
  for (i, c) in bad.enumerate() {
    let x = 0.8 + i * 0.62
    cdraw.content((x, 5.4), c, size: 9pt, fill: luma(140))
  }
  cdraw.line((0.7, 5.4), (8.3, 5.4), stroke: luma(100))
  cdraw.content((4.5, 4.8), [11 in one part: past cap 10, struck by the s = 1 term], size: 6pt)
  cdraw.content((4.5, 3.9), [bounded = sum (-1)^s C(k,s) C(n - s(cap+1) + k - 1, k - 1)], size: 6pt)
  cdraw.content((4.5, 3.1), [20 into 3, cap 10: 231 - 165 = 66], size: 6pt)
  cdraw.content((4.5, 2.3), [30 into 4, cap 10: 5456 - 4\*1540 + 6\*165 = 286], size: 6pt)
  cdraw.content((14.4, 6.6), [non-negative: C(n+k-1, k-1)], size: 6pt)
  cdraw.content((14.4, 5.7), [positive: C(n-1, k-1)], size: 6pt)
  cdraw.content((14.4, 4.8), [brute loops agree in-suite], size: 6pt)
})

== the inclusion-exclusion principle

The union of sets counts as the alternating sum of intersections:
add the singles, subtract the pairs, add the triples, and the
elements in r sets cancel to exactly one. The principle runs whole
families of counting questions once the sets are chosen. Derangements
are permutations avoiding every fixed-point set, the subfactorial sum
!n = n! times the alternating reciprocal series, computable exactly
by the recurrence !n = (n-1) times (!(n-1) + !(n-2)). Coprime
counting is legendre's form: integers up to m divisible by none of a
prime set, the alternating sum over subset products. Squarefree
counting swaps the prime set for the mobius function, the table from
#xref-to("dsa", "numtheory2")'s linear sieve, summed as mu of d times
the floor of n over d squared.

The dry run: the fixtures are the derangement anchors and the coprime
ledger, asserted by the C\# suite, with the C suite writing the ledger
out term by term as its own check.

+ Derangements climb by the recurrence from !0 = 1 and !1 = 0: !2 =
  1 × (0 + 1) = 1, !3 = 2 × (1 + 0) = 2, !4 = 3 × (2 + 1) = 9, !5 =
  4 × (9 + 2) = 44.
+ The next rung reads !6 = 5 × (44 + 9) = 265, the suite sweeps sum
  against recurrence for every n to 10, and a brute walk over all 120
  permutations of 5 finds exactly 44 fixed-point-free.
+ The coprime ledger over 2, 3, 5 on 1..100 runs 100 - 50 = 50, 50 -
  33 = 17, 17 - 20 = -3, then the pairs pull back, -3 + 16 = 13, 13 +
  10 = 23, 23 + 6 = 29, and the triple closes 29 - 3 = 26.
+ The running sum dips to -3 midwalk: the singles pull out 103 in
  all, the pairs push back 32, the triple pulls 3.
+ Squarefree up to 100 reads 61 by the mobius sum, and the exactly-r
  fork on sizes 20 and 15 sharing 8 gives 20 + 15 - 8 = 27, 12, 7.

#diagram([the coprime ledger as eight running boxes, the dip below zero shaded, closing at 26], length: 13pt, {
  let run = (([100], [100]), ([-50], [50]), ([-33], [17]), ([-20], [-3]), ([+16], [13]), ([+10], [23]), ([+6], [29]), ([-3], [26]))
  for (i, e) in run.enumerate() {
    let x = 1.0 + i * 2.35
    cdraw.rect((x, 3.6), (x + 2.0, 5.4), fill: if e.at(1) == [-3] { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((x + 1.0, 4.95), e.at(0), size: 5.5pt)
    cdraw.content((x + 1.0, 4.2), e.at(1), size: 7pt)
    if i < 7 {
      cdraw.line((x + 2.05, 4.5), (x + 2.3, 4.5), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((10.0, 6.55), [one box per mask, 2^3 boxes], size: 6pt)
  cdraw.content((10.0, 5.85), [the dip: the singles went too far], size: 6pt)
  cdraw.content((15.8, 3.0), [ledger literal in the c suite], size: 6pt)
  cdraw.content((15.8, 2.0), [!6 = 265, brute at 5 = 44], size: 6pt)
})

The 44, the 26, and the 61 are the pinned landings, and the listings
below run these families in seven languages.

#listing("dsa/samples-c/src/Ch35/incexc.c", first: 46, last: 72, caption: [c, the subfactorial sum and recurrence, the recurrence's agreement loop in main])

#listing("dsa/samples-go/ch35/incexc.go", first: 26, last: 67, caption: [go, the derangement recurrence and the subset-sum coprime count with overflow skip])

#listing("dsa/samples-java/src/Ch35/Incexc.java", first: 45, last: 71, caption: [java, the subfactorial sum and recurrence, the falling-product terms])

#listing("dsa/samples/src/Ch35/IncExc.cs", first: 12, last: 46, caption: [c\#, the derangement recurrence and the coprime mask sum over the ch28 mu])

#listing("dsa/samples-js/src/ch35-incexc.mjs", first: 30, last: 54, caption: [javascript, the recurrence array and the mask walk, mu imported from the ch28 sieve])

#listing("dsa/samples-py/src/Ch35/incexc.py", first: 17, last: 34, caption: [python, the subfactorial sum and the recurrence, brute permutations below])

#listing("dsa/samples-lua/ch35_incexc.lua", first: 7, last: 24, caption: [lua, the recurrence and the scaled alternating sum, the coprime mask below])

The fixtures pin each family. Derangements: !3 = 2, !4 = 9, !5 = 44
with the brute permutation count agreeing at 5, !6 = 265, !10 =
1334961, and the sum and recurrence equal for every n to 10.
Coprime: integers in 1..100 sharing no factor with 2, 3, 5 = 26, the
terms reading 100 - 50 - 33 - 20 + 16 + 10 + 6 - 3. Squarefree up to
100 = 61 by the mobius sum, brute-verified. The edges cover the
empty prime set leaving all 100, a single prime leaving 100 minus
100 over p, and the exactly-r profile on two sets of sizes 20 and 15
sharing 8: union 27, A-only 12, B-only 7. The application is icpc
world finals 2017 problem K (book 10, chapter 8), tarot sham boast,
which ranks predictions by first-order inclusion-exclusion terms that
turn out identical for all strings of one length, the differences
coming only from self-overlaps.

#diagram([three sets with plus and minus signs, above the 26 survivors of {2,3,5} in 1..100], length: 13pt, {
  // venn of A, B, C
  let cx = (3.4, 5.6, 4.5)
  let cy = (5.6, 5.6, 6.9)
  let r = 1.7
  cdraw.circle((cx.at(0), cy.at(0)), radius: r, stroke: luma(100), fill: none)
  cdraw.circle((cx.at(1), cy.at(1)), radius: r, stroke: luma(100))
  cdraw.circle((cx.at(2), cy.at(2)), radius: r, stroke: luma(100))
  cdraw.content((2.2, 6.6), [+A], size: 8pt)
  cdraw.content((6.8, 6.6), [-B], size: 8pt)
  cdraw.content((4.5, 8.1), [+C], size: 8pt)
  cdraw.content((4.5, 4.2), [subtract pairwise intersections, add the triple], size: 6pt)
  // the ledger for {2,3,5} over 1..100
  cdraw.content((4.5, 3.2), [100 - 50 - 33 - 20 + 16 + 10 + 6 - 3 = 26], size: 6.5pt)
  cdraw.content((4.5, 2.4), [the 26 survivors share no factor 2, 3, or 5], size: 6pt)
  cdraw.content((12.6, 7.4), [derangements: !5 = 44], size: 6pt)
  cdraw.content((12.6, 6.5), [!n = (n-1)(!(n-1) + !(n-2))], size: 6pt)
  cdraw.content((12.6, 5.6), [squarefree to 100: 61, by mu], size: 6pt)
  cdraw.content((12.6, 4.7), [exactly-r: 27, 12, 7], size: 6pt)
  cdraw.content((12.6, 3.8), [O(2^s) subsets, s the set count], size: 6pt)
})

== burnside's lemma and polya enumeration

Counting configurations up to symmetry fails by direct division:
dividing k^n colorings by n rotations counts orbits only when every
orbit has exactly n members, which runs of a single color break.
Burnside's lemma fixes the accounting the other way around: the
number of orbits is the average, over the group, of the count of
configurations each group element fixes. For necklaces under
rotation, the rotation by i positions fixes exactly k to the
gcd(n, i) colorings, the string repeating a block of that length, so
the necklace count is the sum of k^gcd over all i, divided by n.
Bracelets add the dihedral half: reflections through a bead when n is
odd, n of them each fixing k^((n+1)/2), and the two axis families
when n is even, (n/2) times the sum of k^(n/2+1) and k^(n/2), all
divided by 2n. The cube face colorings ride a pinned cycle-index
table of the 24 rotations.

The dry run: the fixtures are the necklace and bracelet anchors,
asserted by the C\# suite with brute canonical forms agreeing; the
seven languages share the counts, lua by generating the rotation group
itself.

+ The bracelet fork on (6, 2) starts from the rotation half, six
  rotations fixing 64, 2, 4, 8, 4, 2 colorings for the sum 84.
+ n = 6 splits its 6 reflections into two families: 3 axes through
  opposite beads hold 2 beads and pair the other 4, fixing 2^4 = 16
  colorings each.
+ The 3 axes through opposite edges pair all 6 beads, fixing 2^3 = 8
  each, so the reflection half reads 3 × 16 + 3 × 8 = 72.
+ The dihedral average divides by 2n: (84 + 72) / 12 = 13, one fewer
  than the necklaces' 14, mirror images now counted once.
+ The brute twin canonicalizes all 64 colorings by orbit minimum and
  counts the same 13.
+ The cube table reads its 24 rotations at k = 3: 1 × 729 + 6 × 27 +
  3 × 81 + 8 × 9 + 6 × 27 = 1368, and 1368 / 24 = 57.

#diagram([the six reflection axes of the 6-bead ring, bead axes solid at 16 fixed each, edge axes dashed at 8], length: 13pt, {
  let cx = 4.0
  let cy = 4.4
  let r = 2.0
  let pt = k => (cx + r * calc.cos(k * 60deg + 90deg), cy + r * calc.sin(k * 60deg + 90deg))
  for (a, b) in ((0, 3), (1, 4), (2, 5)) {
    cdraw.line(pt(a), pt(b), stroke: luma(120))
  }
  let mpt = k => (cx + r * calc.cos(120deg + k * 60deg), cy + r * calc.sin(120deg + k * 60deg))
  for k in range(3) {
    let (mx, my) = mpt(k)
    cdraw.line((mx, my), (cx - (mx - cx), cy - (my - cy)), stroke: (paint: luma(150), dash: "dashed"))
  }
  for k in range(6) {
    cdraw.circle(pt(k), radius: 0.14, fill: luma(190), stroke: luma(140))
  }
  cdraw.content((cx, 7.3), [bead axes solid, edge axes dashed], size: 6.5pt)
  cdraw.content((12.8, 6.6), [bead axis: 2^4 = 16, three of them], size: 6pt)
  cdraw.content((12.8, 5.6), [edge axis: 2^3 = 8, three of them], size: 6pt)
  cdraw.content((12.8, 4.6), [3 × 16 + 3 × 8 = 72], size: 6pt)
  cdraw.content((12.8, 3.6), [(84 + 72) / 12 = 13], size: 6pt)
  cdraw.content((12.8, 2.6), [cube at k = 3: 1368 / 24 = 57], size: 6pt)
  cdraw.content((12.8, 1.6), [necklaces alone: 14], size: 6pt)
})

The 13 and the 57 land with their brute twins agreeing, and the
listings below average the group in seven languages.

#listing("dsa/samples-c/src/Ch35/burnside.c", first: 37, last: 53, caption: [c, the necklace sum by gcd classes, the bracelet reflection families])

#listing("dsa/samples-go/ch35/burnside.go", first: 3, last: 29, caption: [go, both sums in modular arithmetic through the chapter tables])

#listing("dsa/samples-java/src/Ch35/Burnside.java", first: 36, last: 52, caption: [java, the necklace sum by gcd classes, the bracelet reflection families])

#listing("dsa/samples/src/Ch35/Burnside.cs", first: 13, last: 31, caption: [c\#, the necklace sum folded by gcd counts, the bracelet fork])

#listing("dsa/samples-js/src/ch35-burnside.mjs", first: 18, last: 35, caption: [javascript, both sums over plain integer powers])

#listing("dsa/samples-py/src/Ch35/burnside.py", first: 17, last: 32, caption: [python, the two sums, the cube table below])

#listing("dsa/samples-lua/ch35_burnside.lua", first: 19, last: 38, caption: [lua, the two sums; the lua suite generates the actual 24-rotation group and counts fixed colorings directly])

The fixtures pin the orbits and brute-check them by canonical form,
the minimum over each configuration's orbit. Necklaces: (6,2) = 14,
(4,3) = 24, (5,2) = 8, (12,2) = 352, with the canonical-rotation
brute agreeing on the first three. Bracelets, reflections included
in the orbit: (6,2) = 13, (7,2) = 18, (5,3) = 39, again
brute-checked. The cube under its 24 face rotations colors in 10
ways with 2 colors and 57 with 3, every language carrying the same
cycle-index table, and lua verifying it the honest way, closing a
quarter face turn and a vertex turn under composition until exactly
24 permutations exist, then counting fixed colorings per rotation
over all k^6 colorings. The edges read the one-bead necklace as k
and (2,2) as 3. General technique, no finals problem in the mined
set needed it.

#diagram([the six rotations of a 6-bead ring with fixed counts 64, 2, 4, 8, 4, 2 averaging to 14], length: 13pt, {
  // six small rings, one per rotation, each with its fixed count
  let fixed = (64, 2, 4, 8, 4, 2)
  let gcds = (6, 1, 2, 3, 2, 1)
  for t in range(6) {
    let cx = 2.2 + calc.rem(t, 3) * 3.6
    let cy = 6.4 - calc.floor(t / 3) * 3.4
    cdraw.circle((cx, cy), radius: 1.05, stroke: luma(140))
    for b in range(6) {
      let a = b * 60deg
      cdraw.circle((cx + 0.95 * calc.cos(a), cy + 0.95 * calc.sin(a)), radius: 0.13, fill: if calc.rem(b, gcds.at(t)) == 0 { luma(120) } else { luma(230) }, stroke: luma(150))
    }
    cdraw.content((cx, cy - 1.5), [by #t, fixed #fixed.at(t)], size: 6pt)
  }
  cdraw.content((7.6, 8.5), [2 colors, 6 beads: k^gcd(6, i) per rotation], size: 6.5pt)
  cdraw.content((7.6, 7.9), [64 + 2 + 4 + 8 + 4 + 2 = 84, / 6 = 14], size: 6.5pt)
  cdraw.content((14.2, 6.4), [orbits = average fixed points], size: 6pt)
  cdraw.content((14.2, 5.4), [dark beads repeat a gcd block], size: 6pt)
  cdraw.content((14.2, 4.4), [bracelets: reflections too, / 2n], size: 6pt)
  cdraw.content((14.2, 3.4), [brute: min over the orbit], size: 6pt)
  cdraw.content((14.2, 2.4), [cube faces: 24 rotations, 10 at k = 2], size: 6pt)
})

== generating k-subsets

Iteration is the quiet half of counting: the solver that proves a
count often also needs the objects. Lexicographic k-combinations are
sorted 0-based index tuples, and next-combination advances one step:
scan from the right for the first index below its maximum, n - k +
i, increment it, and reset everything after it to consecutive
integers. When no index can advance the walk wraps and the tuple
(3,4,5)-style ceiling has been reached. Each step is O(k) and the
walk visits all C(n, k) tuples in lexicographic order.

The dry run: the fixture is the 20-tuple walk with its transitions and
the k = 6 office strings, asserted by the C\# suite.

+ The walk opens (0,1,2), (0,1,3), (0,1,4), (0,1,5): index 2 alone
  climbs toward its maximum 5 while the frozen prefix holds.
+ (0,2,4) climbs index 2 once more, 4 to 5, landing (0,2,5).
+ (0,2,5) finds index 2 at its maximum, so index 1 climbs 2 to 3 and
  the tail resets to consecutive: (0,3,4).
+ (0,4,5) is the frozen-prefix extreme: index 0 climbs 0 to 1 and the
  whole tail resets, (1,2,3).
+ (3,4,5) has no mobile index, and the walk wraps after 20 tuples,
  C(6,3) = 20.
+ The office-string walk at k = 6 turns (0,1,2) into 011100, ones at
  bits 1, 2, 3 after the leading 0, and ten strings later (2,3,4) is
  000111.
+ The search closes at n = 10: C(5,3) = 10 first reaches it, so the
  smallest k is 6.

#table(
  columns: (auto, auto, 1.9fr, auto),
  inset: 4pt,
  table.header([*tuple*], [*mobile index*], [*action*], [*next*]),
  [(0,2,4)], [i = 2], [4 climbs to 5], [(0,2,5)],
  [(0,2,5)], [i = 1], [2 climbs, tail resets], [(0,3,4)],
  [(0,4,5)], [i = 0], [0 climbs, tail resets], [(1,2,3)],
  [(3,4,5)], [none], [wrap after 20], [],
)

The 20, the reset, and the ten strings are the pinned landings, and
the listings below run the walk in seven languages.

#listing("dsa/samples-c/src/Ch35/ksubset.c", first: 55, last: 78, caption: [c, next-combination, the emit turning a tuple into the office string])

#listing("dsa/samples-go/ch35/ksubset.go", first: 9, last: 52, caption: [go, the advance and the string walk over it])

#listing("dsa/samples-java/src/Ch35/Ksubset.java", first: 52, last: 77, caption: [java, nextComb, the emit turning a tuple into the office string])

#listing("dsa/samples/src/Ch35/KSubset.cs", first: 13, last: 48, caption: [c\#, next, and the office string generator yielding largest-first])

#listing("dsa/samples-js/src/ch35-ksubset.mjs", first: 16, last: 40, caption: [javascript, the advance, the 2023/B string family, no backwards walk])

#listing("dsa/samples-py/src/Ch35/ksubset.py", first: 15, last: 36, caption: [python, next-combination and the walk collecting tuples])

#listing("dsa/samples-lua/ch35_ksubset.lua", first: 9, last: 43, caption: [lua, the advance and the office strings emitted descending])

The 2023/B construction rides the same walk. Icpc world finals 2023
problem B (book 10, chapter 12), schedule, builds its candidate
strings as length-k binary strings with first bit 0 and exactly
ceil(k/2) ones among the remaining k - 1 bits, and it needs the n
largest compatible strings. The walk over the one-positions emits
exactly that: ascending index-tuple order places earlier one-positions
first, and earlier ones lex to larger strings, so one forward walk
emits the strings largest-first with no backwards traversal. At k = 6
the ten strings pin as 011100, 011010, 011001, 010110, 010101,
010011, 001110, 001101, 001011, 000111.

The walk fixtures pin 3-subsets of 6: 20 in all, opening (0,1,2),
(0,1,3), (0,1,4), (0,1,5), (0,2,3), closing at (3,4,5), with the
transitions (0,2,4) to (0,2,5) to (0,3,4) showing the reset, and
(0,4,5) jumping to (1,2,3). The edges read k = 0 as the one empty
subset that wraps immediately, k = n as the full set wrapping the
same way, and the search answers the smallest k with C(k-1,
ceil(k/2)) at least n: 4, 4, 6 for n = 2, 3, 10, the feasibility
threshold 2023/B actually solves for.

#diagram([the 20 3-subsets of 6 as a lex ladder, the (0,2,5) to (0,3,4) reset step highlighted], length: 13pt, {
  // ladder of all 20 tuples in 4 columns
  let tuples = (
    (0, 1, 2), (0, 1, 3), (0, 1, 4), (0, 1, 5), (0, 2, 3),
    (0, 2, 4), (0, 2, 5), (0, 3, 4), (0, 3, 5), (0, 4, 5),
    (1, 2, 3), (1, 2, 4), (1, 2, 5), (1, 3, 4), (1, 3, 5),
    (1, 4, 5), (2, 3, 4), (2, 3, 5), (2, 4, 5), (3, 4, 5),
  )
  for (i, t) in tuples.enumerate() {
    let col = calc.floor(i / 5)
    let row = calc.rem(i, 5)
    let x = 1.2 + col * 4.0
    let y = 7.0 - row * 1.05
    let hot = i == 6
    cdraw.rect((x - 0.55, y - 0.34), (x + 2.3, y + 0.34), fill: if hot { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((x + 0.85, y), [#(t.at(0)), #(t.at(1)), #(t.at(2))], size: 7pt)
    cdraw.content((x - 0.75, y), [#i], size: 6pt)
  }
  cdraw.content((7.6, 1.2), [shaded: (0,2,5) advances the index 2 to its max, so (0,3,4) resets the tail], size: 6pt)
  cdraw.content((14.6, 7.0), [rightmost mobile index increments], size: 6pt)
  cdraw.content((14.6, 6.0), [tail resets to consecutive], size: 6pt)
  cdraw.content((14.6, 5.0), [O(k) per step, C(n,k) total], size: 6pt)
  cdraw.content((14.6, 4.0), [2023/B: ones walk = strings descend], size: 6pt)
  cdraw.content((14.6, 3.0), [search k: C(k-1, ceil k/2) >= n], size: 6pt)
})

== sperner's theorem and antichains

An antichain of subsets is a family where no member contains
another. Sperner's theorem, 1928, caps every antichain of the n-set
at C(n, floor n/2): the middle layer, all subsets of that one size,
is a maximum antichain, since equal sizes are automatically
incomparable and nothing larger is possible. The proof the book
states without carrying is the LYM inequality, which weights each
set by one over C(n, its size) and shows the weights sum to at most
1, a budget the middle layer spends exactly. The dedekind number
M(n) flips the question and counts the antichains themselves,
bruted here over all 2^(2^n) families with pairwise comparability
checks, feasible through n = 4's 65536 families.

The dry run: the fixtures are the middle-layer row and the dedekind
brute to n = 4, asserted by the C\# suite; the six families of the
n = 2 walk below are hand-derived off the pinned 6.

+ The middle layers read C(n, n/2) for n = 1 through 8: 1, 2, 3, 6,
  10, 20, 35, 70, and the n = 4 layer's 6 sets assert pairwise
  incomparable.
+ The dedekind brute at n = 2 scans all 2^4 = 16 families over the
  four subsets of a 2-set.
+ Hand-walking the 16: the empty family, the four single-set families,
  and the pair of singletons {1}, {2} survive, 6 in all.
+ Every other family dies by one containment: the empty set sits
  inside anything, and {1} or {2} sits inside {1, 2}.
+ n = 3 scans 256 families to 20, n = 4 scans 65536 to 168, so
  M(0..4) = 2, 3, 6, 20, 168, with M(5) = 7581 quoted as literature.
+ The counterexample chain, the empty set inside {1}, fails the
  antichain test by exactly one containment.

#diagram([the 16 families of a 2-set cut to 6 antichains, one dot per subset held], length: 13pt, {
  let subs = ([\{\}], [\{1\}], [\{2\}], [\{1,2\}])
  for (c, s) in subs.enumerate() {
    cdraw.content((2.4 + c * 2.2, 7.6), s, size: 6.5pt)
  }
  let fams = ((0, 0, 0, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1), (0, 1, 1, 0))
  for (r, f) in fams.enumerate() {
    let y = 6.7 - r * 0.95
    cdraw.rect((1.0, y - 0.32), (8.6, y + 0.32), fill: luma(238), radius: 0.02)
    for (c, b) in f.enumerate() {
      if b == 1 {
        cdraw.circle((2.4 + c * 2.2, y), radius: 0.14, fill: luma(120))
      }
    }
  }
  cdraw.content((11.2, 0.9), [the sixth row is the singleton pair], size: 6pt)
  cdraw.content((14.6, 6.8), [16 scanned, 6 live], size: 6pt)
  cdraw.content((14.6, 5.8), [M(3): 256 scanned, 20], size: 6pt)
  cdraw.content((14.6, 4.8), [M(4): 65536 scanned, 168], size: 6pt)
  cdraw.content((14.6, 3.8), [M(5) = 7581, quoted], size: 6pt)
})

The 6, the row 2, 3, 6, 20, 168, and the 6-set layer are the pinned
landings, and the listings below run the brute in seven languages.

#listing("dsa/samples-c/src/Ch35/sperner.c", first: 32, last: 68, caption: [c, the dedekind brute over family bitmasks, the middle layer, the antichain test])

#listing("dsa/samples-go/ch35/sperner.go", first: 36, last: 72, caption: [go, the antichain test and the dedekind brute over set maps])

#listing("dsa/samples-java/src/Ch35/Sperner.java", first: 24, last: 62, caption: [java, the dedekind brute over family bitmasks, the middle layer, the antichain test])

#listing("dsa/samples/src/Ch35/Sperner.cs", first: 11, last: 57, caption: [c\#, the layer walk reusing the k-subset iterator, the dedekind brute refusing past n = 4])

#listing("dsa/samples-js/src/ch35-sperner.mjs", first: 13, last: 34, caption: [javascript, the bitwise antichain test and the dedekind brute])

#listing("dsa/samples-py/src/Ch35/sperner.py", first: 16, last: 39, caption: [python, the layer, the incomparability test, the dedekind brute])

#listing("dsa/samples-lua/ch35_sperner.lua", first: 18, last: 55, caption: [lua, the same three pieces in 1-based masks])

The fixtures pin the layers and the counts. C(n, floor n/2) for n =
1 through 8 reads 1, 2, 3, 6, 10, 20, 35, 70, and the n = 4 middle
layer's 6 sets assert pairwise incomparable. Dedekind M(0..4) = 2,
3, 6, 20, 168 by the brute, where M(0) = 2 counts the empty family
and the family holding only the empty set and n = 1's singletons
lift M(1) to 3. M(5) = 7581 is stated as the literature constant
and never asserted as a derived number, the brute being 2^32
families out of sample reach. The pinned counterexample reads the
chain of the empty set inside {1} as not an antichain. The
application is the optimality half of icpc world finals 2023
problem B (book 10, chapter 12): its compatibility condition makes
the strings an antichain, so C(k-1, ceil(k/2)) is not just reachable
but the maximum, which is why the search of the previous section is
exactly optimal.

#diagram([the boolean lattice of n = 4 in five rank rows, the middle row of 6 shaded as the maximum antichain], length: 13pt, {
  // ranks 0..4 with sizes 1, 4, 6, 4, 1
  let sizes = (1, 4, 6, 4, 1)
  for (r, sz) in sizes.enumerate() {
    let y = 7.2 - r * 1.35
    for i in range(sz) {
      let x = 6.6 + (i - (sz - 1) / 2) * 1.35
      let mid = r == 2
      cdraw.circle((x, y), radius: 0.24, fill: if mid { luma(205) } else { luma(240) }, stroke: luma(130))
    }
    cdraw.content((1.6, y), [rank #r, size #(sz)], size: 6.5pt)
  }
  // a few cover edges
  let pos = (r, i, sz) => (6.6 + (i - (sz - 1) / 2) * 1.35, 7.2 - r * 1.35)
  for e in (((0, 0, 1), (1, 0, 4)), ((1, 0, 4), (2, 1, 6)), ((1, 1, 4), (2, 1, 6)), ((2, 1, 6), (3, 1, 4)), ((3, 2, 4), (4, 0, 1))) {
    cdraw.line(pos(..e.at(0)), pos(..e.at(1)), stroke: luma(200))
  }
  cdraw.content((6.6, 8.0), [the n = 4 subset lattice], size: 6.5pt)
  cdraw.content((6.6, 0.7), [middle rank: 6 sets, pairwise incomparable, maximum], size: 6pt)
  cdraw.content((15.2, 7.2), [sperner 1928: no antichain bigger], size: 6pt)
  cdraw.content((15.2, 6.2), [LYM: weights sum to at most 1], size: 6pt)
  cdraw.content((15.2, 5.2), [M(0..4) = 2, 3, 6, 20, 168], size: 6pt)
  cdraw.content((15.2, 4.2), [M(5) = 7581 stated, 2^32 families], size: 6pt)
})

== the frobenius problem

Given coin denominations with gcd 1, which totals cannot be bought.
The largest is the frobenius number, and two generators close by
formula, F = ab - a - b with genus (a-1)(b-1) / 2 and every larger
total reachable. General k has no closed form, and the sample answer
is a reachability sieve: mark 0, then walk values ascending, marking
v reachable when v minus some generator is, and stop at a cap chosen
past the conductor, p~max~ squared plus p~max~, the classical
schur-type bound that settles every value beyond it. The gaps read
off as the unmarked values, the largest is F, the conductor is F + 1,
and gcd above 1 refuses outright since the gaps are then infinite.

The dry run: the fixture is the (3,5) pair, asserted by the C\# suite
with the pair formula cross-checked against the sieve.

+ The sieve seeds 0 reachable and walks up from the smallest
  generator, marking v when v minus some generator is marked.
+ v = 1 and v = 2 find nothing below them marked and stay gaps; v = 3
  reads 3 - 3 = 0 and marks.
+ v = 4 reads 4 - 3 = 1, unmarked, and stays a gap; v = 5 reads
  5 - 5 = 0 and marks.
+ v = 6 chains off 3, v = 7 reads 7 - 3 = 4 and 7 - 5 = 2, both gaps,
  and dies as the largest gap.
+ v = 8 reads 8 - 3 = 5 marked and marks, and from there every value
  chains: 9 - 3 = 6, 10 - 5 = 5, 11 - 3 = 8.
+ The gaps read 1, 2, 4, 7, so F = 7, conductor 8, genus 4, and the
  pair formula agrees, 15 - 3 - 5 = 7 with (3-1)(5-1)/2 = 4.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*v*], [*v - 3*], [*v - 5*], [*verdict*]),
  [1], [-], [-], [gap],
  [2], [-], [-], [gap],
  [3], [0 marked], [-], [mark],
  [4], [1 gap], [-], [gap],
  [5], [2 gap], [0 marked], [mark],
  [6], [3 marked], [1 gap], [mark],
  [7], [4 gap], [2 gap], [gap],
  [8], [5 marked], [3 marked], [mark],
)

The 7, the four gaps, and the conductor 8 are the pinned landings,
and the listings below run the sieve in seven languages.

#listing("dsa/samples-c/src/Ch35/frobenius.c", first: 37, last: 72, caption: [c, the sieve with the cap, the gap scan, the conductor])

#listing("dsa/samples-go/ch35/frobenius.go", first: 14, last: 53, caption: [go, the closed form, the sieve, the gap list])

#listing("dsa/samples-java/src/Ch35/Frobenius.java", first: 36, last: 71, caption: [java, the sieve with the cap, the gap scan, the conductor])

#listing("dsa/samples/src/Ch35/Frobenius.cs", first: 14, last: 36, caption: [c\#, the same sieve returning the record])

#listing("dsa/samples-js/src/ch35-frobenius.mjs", first: 15, last: 47, caption: [javascript, the sieve with the refuses and the -1 convention])

#listing("dsa/samples-py/src/Ch35/frobenius.py", first: 17, last: 34, caption: [python, the sieve raising on gcd, the -1 convention for generator 1])

#listing("dsa/samples-lua/ch35_frobenius.lua", first: 14, last: 34, caption: [lua, the same sieve, errors on gcd, conductor bound asserted in the suite])

The fixtures walk the families. Pairs: frobenius(3,5) = 7 = 15 - 8
with gaps 1, 2, 4, 7 and genus 4 = (3-1)(5-1)/2; frobenius(4,7) = 17
with 9 gaps and conductor 18; frobenius(5,8) = 27 by the closed form
against the sieve. The mcnugget system (6, 9, 20) pins F = 43, 22
gaps, conductor 44, the gap list itself pinned digit for digit. The
edges refuse gcd(4,6) = 2 loudly, report -1 when a generator is 1
and everything is reachable, and assert the bound: every fixture's
conductor sits under p~max~ squared plus p~max~. The application is
icpc world finals 2025 problem H (book 10, chapter 13), score values,
whose reachable scores are exactly this semigroup capped at the
score ceiling, and past the frobenius region, bounded by the square
of the largest denomination, exactly the multiples of the gcd
survive, which is how that solver splits its work at 1e6.

#diagram([the number line to 44 with the 22 mcnugget gaps hatched and the conductor line drawn at 44], length: 13pt, {
  // number line 0..44, gaps hatched
  let gaps = (1, 2, 3, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 22, 23, 25, 28, 31, 34, 37, 43)
  let xof = (v) => 1.0 + v * 0.42
  cdraw.line((xof(0), 5.6), (xof(44), 5.6), stroke: luma(100))
  for v in range(45) {
    let x = xof(v)
    if v in gaps {
      cdraw.line((x, 5.6), (x, 4.9), stroke: luma(120))
      cdraw.content((x, 4.55), [#v], size: 5.5pt, fill: luma(90))
    } else if calc.rem(v, 5) == 0 {
      cdraw.line((x, 5.6), (x, 5.25), stroke: luma(120))
      cdraw.content((x, 5.0), [#v], size: 6pt)
    }
  }
  // conductor line at 44
  cdraw.line((xof(44), 6.4), (xof(44), 5.6), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.content((xof(44), 6.75), [conductor 44], size: 6.5pt)
  cdraw.content((xof(20), 7.3), [the (6, 9, 20) semigroup: 22 gaps, F = 43], size: 6.5pt)
  cdraw.content((9.6, 3.4), [every value past 44 is 6a + 9b + 20c], size: 6pt)
  cdraw.content((9.6, 2.6), [cap: p~max~^2 + p~max~ = 420 covers it], size: 6pt)
  cdraw.content((9.6, 1.8), [pairs close: F = ab - a - b, genus (a-1)(b-1)/2], size: 6pt)
  cdraw.content((9.6, 1.0), [gcd > 1: infinitely many gaps, refused], size: 6pt)
})

== the josephus problem

n people in a circle, every kth leaves, who survives. The recurrence
is one line and one index convention: number people 0-based, let
j(1) = 0, and j(n) = (j(n-1) + k) mod n, because the circle of n is
the circle of n - 1 re-indexed after the first departure. O(n) with
no simulation. The k = 2 case closes: with L = n - 2^floor(log2 n),
the amount by which n exceeds its largest power of two, the survivor
is 2L in the 0-based reading, 2L + 1 in the 1-based one, O(1) after
one scan for the top bit. The elimination order needs the actual
simulation, index removal on a live list.

The dry run: the fixtures are the recurrence anchors, the closed-form
sweep, and the 7-circle order, asserted by the C\# suite with C
pinning the 10^9 anchor on both fast roads.

+ The recurrence re-indexes upward from j(1) = 0:
  j(2) = (0 + 2) % 2 = 0, j(3) = (0 + 2) % 3 = 2, j(4) = (2 + 2) % 4 = 0, j(5) = (0 +
  2) % 5 = 2, the pinned j(5, 2).
+ The 7-circle order counts triples around the live circle: 0, 1, 2
  sends 2 out, then 3, 4, 5 sends 5 out.
+ From 6 the count wraps: 6, 0, 1 sends 1 out, then 3, 4, 6 sends 6
  out, then 0, 3, 4 sends 4 out, then 0, 3, 0 sends 0 out.
+ The order reads 2, 5, 1, 6, 4, 0 with 3 standing, and the
  recurrence agrees, j(7, 3) = 3.
+ The sweep runs the k = 2 closed form against the recurrence for
  every n to 2000, and both roads answer j(10^9, 2) = 926258176.

#table(
  columns: (auto, auto, 1.7fr),
  inset: 4pt,
  table.header([*counts*], [*leaves*], [*circle after*]),
  [0, 1, 2], [2], [0, 1, 3, 4, 5, 6],
  [3, 4, 5], [5], [0, 1, 3, 4, 6],
  [6, 0, 1], [1], [0, 3, 4, 6],
  [3, 4, 6], [6], [0, 3, 4],
  [0, 3, 4], [4], [0, 3],
  [0, 3, 0], [0], [3],
)

The standing 3 and the 926258176 are the pinned landings, and the
listings below run all three roads in seven languages.

#listing("dsa/samples-c/src/Ch35/josephus.c", first: 19, last: 31, caption: [c, the recurrence loop, the closed form by top-bit scan])

#listing("dsa/samples-go/ch35/josephus.go", first: 5, last: 21, caption: [go, the recurrence, the closed form from the top bit])

#listing("dsa/samples-java/src/Ch35/Josephus.java", first: 18, last: 30, caption: [java, the recurrence loop, the closed form by top-bit scan])

#listing("dsa/samples/src/Ch35/Josephus.cs", first: 9, last: 24, caption: [c\#, the recurrence, the closed form from bit 62 down])

#listing("dsa/samples-js/src/ch35-josephus.mjs", first: 6, last: 26, caption: [javascript, recurrence, closed form, the elimination simulation])

#listing("dsa/samples-py/src/Ch35/josephus.py", first: 15, last: 34, caption: [python, the recurrence, the closed form, the halving recurrence as a third road])

#listing("dsa/samples-lua/ch35_josephus.lua", first: 7, last: 19, caption: [lua, the recurrence and the closed form, the order below])

The fixtures pin all three roads. The recurrence anchors: j(5,2) = 2,
j(7,3) = 3, j(10,2) = 4, and the classic j(41,3) = 30, person 31 in
the 1-based reading. The closed form and a halving recurrence,
j(2m) = 2 j(m) and j(2m+1) = 2 j(m) + 2, each sweep-equal to the
recurrence for every n to 2000, and both fast roads answer
j(10^9, 2) = 926258176. The order family pins (7,3) eliminating 2,
5, 1, 6, 4 first with survivor 3 matching the recurrence. The edges:
n = 1 survives at 0 with an empty order, k = 1 leaves the last
person as an identity order, k above n wraps, j(3,7) = 2, and k = n
gives j(3,3) = 1. General technique.

#diagram([the 41-person circle closing on person 31, with the k = 2 doubling ladder marked on a small circle], length: 13pt, {
  // left: the 41-circle
  let cx = 3.6
  let cy = 5.4
  let r = 2.5
  for i in range(41) {
    let a = i * (360deg / 41)
    let p = (cx + r * calc.cos(a), cy + r * calc.sin(a))
    if i == 30 {
      cdraw.circle(p, radius: 0.22, fill: luma(120))
      cdraw.content(p, [31], size: 5.5pt, fill: rgb(255, 255, 255))
    } else {
      cdraw.circle(p, radius: 0.09, fill: luma(190))
    }
  }
  cdraw.content((cx, cy + 0.3), [k = 3], size: 7pt)
  cdraw.content((cx, cy - 0.3), [41 people], size: 7pt)
  cdraw.content((cx, 1.6), [survivor 30 zero-based, person 31], size: 6pt)
  // right: the k = 2 ladder on n = 10
  let cx2 = 11.2
  let cy2 = 5.4
  let r2 = 2.2
  for i in range(10) {
    let a = i * 36deg - 90deg
    let p = (cx2 + r2 * calc.cos(a), cy2 + r2 * calc.sin(a))
    if i == 4 {
      cdraw.circle(p, radius: 0.24, fill: luma(120))
      cdraw.content(p, [5], size: 6pt, fill: rgb(255, 255, 255))
    } else {
      cdraw.circle(p, radius: 0.15, fill: luma(240), stroke: luma(140))
      cdraw.content(p, [#i], size: 5.5pt)
    }
  }
  cdraw.content((cx2, cy2 + 0.3), [k = 2, n = 10], size: 6.5pt)
  cdraw.content((cx2, cy2 - 0.35), [10 = 8 + 2, L = 2], size: 6.5pt)
  cdraw.content((cx2, 1.6), [survivor 2L = 4, person 5], size: 6pt)
  cdraw.content((16.4, 6.2), [j(n) = (j(n-1) + k) mod n], size: 6pt)
  cdraw.content((16.4, 5.2), [k = 2: 2L, 1-based 2L + 1], size: 6pt)
  cdraw.content((16.4, 4.2), [L = n - 2^floor(log2 n)], size: 6pt)
  cdraw.content((16.4, 3.2), [j(10^9, 2) = 926258176], size: 6pt)
  cdraw.content((16.4, 2.2), [order: index removal, O(n^2) sim], size: 6pt)
})

== fifteen-puzzle solvability

No sample files ship for this section: the content is one parity
predicate, a boolean with two additions, and there is no algorithm to
port six ways, so the figure and the prose carry it whole. A sliding
puzzle move is a transposition of the blank with one tile, and on a
board of even width each move also shifts the blank's row by one, so
the parity of the tile permutation and the parity of the blank's row
distance from its goal row change together, making their sum the
invariant. A board is solvable exactly when the invariant matches the
solved board's: with width 4, inversions plus the blank's row
counted from the bottom must be even. The solved board has 0
inversions and the blank on the first row from the bottom, sum even,
solvable; the famous 14-15 swapped board has 1 inversion with the
blank in the same place, sum odd, unsolvable, which is the entire
1880 puzzle hoax. The rule generalizes to any n by m board, odd
widths needing only the inversion parity because the row shift there
preserves parity. General technique, taught by
cp-algorithms' "15 Puzzle Game: Existence Of The Solution".

The dry run: no suite carries this facet, so the numbers below are
hand-derived, one parity read per board.

+ The solved board reads 0 inversions with the blank on its goal row,
  sum even, solvable.
+ The 14-15 swap changes exactly one thing, 1 inversion with the blank
  unmoved, sum odd: unsolvable, the entire 1880 hoax.
+ One legal slide preserves the parity of the sum: slide 12 down and
  the reading order gains 3 inversions, 13, 14, 15 each passing 12,
  while the blank moves one row off its goal, 3 + 1 = 4, even again.
+ Every slide is one transposition of the blank with a tile, which
  flips inversion parity, and on width 4 one row shift, which flips
  row parity: the two flips cancel every time.
+ Odd widths drop the row term, since the shift there preserves
  parity and inversions alone decide.

#diagram([the 12-down slide, three inversions bought by one row shift, the parity ledger beneath], length: 13pt, {
  let board = (x0, slide: false) => {
    for r in range(4) {
      for c in range(4) {
        let n = r * 4 + c + 1
        let v = if slide and r == 3 and c == 3 { [12] } else if slide and r == 2 and c == 3 { [] } else if r == 3 and c == 3 { [] } else { [#n] }
        let hot = slide and (r == 2 and c == 3 or r == 3 and c == 3)
        cdraw.rect((x0 + c * 1.0, 6.9 - r * 1.0), (x0 + c * 1.0 + 0.95, 6.9 - r * 1.0 + 0.95), fill: if hot { luma(205) } else { luma(238) }, radius: 0.02)
        cdraw.content((x0 + c * 1.0 + 0.475, 6.9 - r * 1.0 + 0.475), v, size: 8pt)
      }
    }
  }
  board(1.2)
  board(7.0, slide: true)
  cdraw.content((3.2, 8.3), [solved], size: 6.5pt)
  cdraw.content((9.0, 8.3), [after 12 slides down], size: 6.5pt)
  cdraw.content((9.6, 2.2), [solved: 0 inversions + 0 row off = even], size: 6pt)
  cdraw.content((9.6, 1.4), [after: 3 inversions + 1 row off = 4, even], size: 6pt)
  cdraw.content((15.6, 5.4), [a slide = one transposition], size: 6pt)
  cdraw.content((15.6, 4.4), [even width: row flips too], size: 6pt)
  cdraw.content((15.6, 3.4), [odd width: inversions alone], size: 6pt)
  cdraw.content((15.6, 2.4), [the hoax board: 1 + 0, odd], size: 6pt)
})

Both boards read even and the hoax board reads odd, the whole test in
one parity check per board.

#diagram([the solved board beside the 14-15 swapped board with the parity ledger beneath], length: 13pt, {
  // two 4x4 boards
  let board = (x0, swap: false) => {
    for r in range(4) {
      for c in range(4) {
        let v = if r == 3 and c == 3 { [] } else {
          let n = r * 4 + c + 1
          if swap and n == 14 { [15] } else if swap and n == 15 { [14] } else { [#n] }
        }
        let hot = swap and (r * 4 + c + 1 == 14 or r * 4 + c + 1 == 15)
        cdraw.rect((x0 + c * 1.0, 6.9 - r * 1.0), (x0 + c * 1.0 + 0.95, 6.9 - r * 1.0 + 0.95), fill: if hot { luma(205) } else { luma(238) }, radius: 0.02)
        cdraw.content((x0 + c * 1.0 + 0.475, 6.9 - r * 1.0 + 0.475), v, size: 8pt)
      }
    }
  }
  board(1.2)
  board(7.0, swap: true)
  cdraw.content((3.2, 8.3), [solved], size: 6.5pt)
  cdraw.content((9.0, 8.3), [14-15 swapped], size: 6.5pt)
  cdraw.content((5.6, 2.2), [ledger: solved = 0 inversions, blank row 1 from bottom, sum even], size: 6pt)
  cdraw.content((5.6, 1.4), [swapped = 1 inversion, blank row 1, sum odd: unsolvable], size: 6pt)
  cdraw.content((14.6, 5.4), [a slide = one transposition], size: 6pt)
  cdraw.content((14.6, 4.4), [even width: blank row flips too], size: 6pt)
  cdraw.content((14.6, 3.4), [odd width: inversions alone], size: 6pt)
  cdraw.content((14.6, 2.4), [the invariant never lies], size: 6pt)
})

== placing bishops on a chessboard

Bishops attack along both diagonals, and the two square colors never
interact: a bishop on light squares can never attack one on dark.
So the count splits, k bishops over two independent boards, summed
across every split of k. Each color runs the same dp over its
diagonals of one direction, sorted by non-decreasing length:
f\[i\]\[j\] = f\[i-1\]\[j\] + f\[i-1\]\[j-1\] times (len~i~ - (j-1)),
place nothing on the new diagonal or place a bishop on it, and each
of the j - 1 bishops already on earlier diagonals blocks exactly one
cell of it, because the blocking bishop's cross diagonal always
meets a not-shorter diagonal, which is what the sort buys. k above
2n - 2 is zero, and the 2n - 2 maximum has exactly 2^n placements,
one per diagonal pair choice.

The dry run: the fixture is the n = 4 row, asserted by the C\# suite
and brute-verified placement by placement; the dp states inside the
walk are hand-derived off the recurrence.

+ The two colors of the 4x4 board sort their diagonals to lengths 1,
  1, 3, 3 and 2, 2, 4.
+ The even dp seeds f = 1 and folds the first single cell to f = 1, 1;
  the second single cell lands f = 1, 2, 0, two bishops cannot both
  sit, 1 - 1 = 0 free cells.
+ The first length-3 diagonal lands f = 1, 5, 4, 0: 2 + 1 × 3 = 5 and
  0 + 2 × 2 = 4, each earlier bishop blocking one cell.
+ The second lands f = 1, 8, 14, 4: 5 + 1 × 3 = 8, 4 + 5 × 2 = 14, 0
  + 4 × 1 = 4.
+ The odd color folds 2, 2, 4 the same way to 1, 8, 14, 4, capped at
  3 bishops by its 3 diagonals.
+ The combine reads the splits: k = 1 gives 8 + 8 = 16, k = 2 gives
  14 + 64 + 14 = 92, and the ceiling k = 6 gives 4 × 4 = 16, the
  2^4 of one diagonal pair each.

#table(
  columns: (auto, auto),
  inset: 4pt,
  table.header([*after diagonal*], [*f over j = 0..4*]),
  [seed], [1],
  [len 1], [1, 1],
  [len 1], [1, 2, 0],
  [len 3], [1, 5, 4, 0],
  [len 3], [1, 8, 14, 4, 0],
)

The full row 1, 16, 92, 232, 260, 112, 16 is the pinned landing, and
the listings below run the dp in seven languages.

#listing("dsa/samples-c/src/Ch35/bishops.c", first: 46, last: 71, caption: [c, the rolling dp over the length staircase, the color combine])

#listing("dsa/samples-go/ch35/bishops.go", first: 5, last: 44, caption: [go, the dp over the sorted lengths, the diagonal length frame])

#listing("dsa/samples-java/src/Ch35/Bishops.java", first: 43, last: 69, caption: [java, the rolling dp over the length staircase, the color combine])

#listing("dsa/samples/src/Ch35/Bishops.cs", first: 31, last: 66, caption: [c\#, the per-color length table and the dp, combined in Count])

#listing("dsa/samples-js/src/ch35-bishops.mjs", first: 9, last: 41, caption: [javascript, the diagonal lengths, the dp, the split sum])

#listing("dsa/samples-py/src/Ch35/bishops.py", first: 17, last: 46, caption: [python, the three pieces, brute placements below])

#listing("dsa/samples-lua/ch35_bishops.lua", first: 8, last: 52, caption: [lua, the color staircase, the dp, the combine, brute in the suite])

The fixtures pin whole rows. Bishops(4, k) for k = 0..6 reads 1, 16,
92, 232, 260, 112, 16, brute-verified over all placements at n = 4;
bishops(5, k) for k = 0..8 reads 1, 25, 240, 1124, 2728, 3368, 1960,
440, 32. The 8x8 row runs 1, 64, 1736, 26192, 242856, 1444928,
5599888, 14082528, 22522960, 22057472, 12448832, 3672448, 489536,
20224, 256, brute only at the small boards. The edges pin
bishops(8,1) = 64 = n squared, the 2n - 2 maximum at 2^n for n = 4,
5, 8 reading 16, 32, 256, bishops(4,7) = 0 past the maximum, and
bishops(2,2) = 4, the 2x2 corner. General technique, O(n k).

#diagram([the 4x4 board split by color, one color's diagonals as a length-sorted staircase feeding the dp], length: 13pt, {
  // left: 4x4 board, color 0 cells shaded
  for r in range(4) {
    for c in range(4) {
      let light = calc.rem(r + c, 2) == 0
      cdraw.rect((1.2 + c * 0.95, 7.0 - r * 0.95), (1.2 + c * 0.95 + 0.95, 7.0 - r * 0.95 + 0.95), fill: if light { luma(215) } else { luma(240) }, radius: 0.02)
    }
  }
  cdraw.content((3.1, 7.9), [the 4x4 board by color], size: 6.5pt)
  // right: the diagonal staircase of the shaded color, lengths 1, 1, 3, 3
  let lens = (1, 1, 3, 3)
  for (i, l) in lens.enumerate() {
    let y = 6.7 - i * 1.15
    cdraw.content((6.0, y), [diag #(i + 1), len #l], size: 6pt)
    for b in range(l) {
      cdraw.rect((8.6 + b * 0.55, y - 0.25), (8.6 + b * 0.55 + 0.5, y + 0.25), fill: luma(215), radius: 0.02)
    }
  }
  cdraw.content((9.2, 8.0), [sorted lengths: 1, 1, 3, 3], size: 6.5pt)
  cdraw.content((9.2, 1.6), [f\[i\]\[j\] = f\[i-1\]\[j\] + f\[i-1\]\[j-1\] (len - j + 1)], size: 6pt)
  cdraw.content((9.2, 0.8), [j - 1 earlier bishops block one cell each], size: 6pt)
  cdraw.content((15.4, 6.6), [colors never attack across], size: 6pt)
  cdraw.content((15.4, 5.6), [row k = sum over splits], size: 6pt)
  cdraw.content((15.4, 4.6), [bishops(4, 0..6):], size: 6pt)
  cdraw.content((15.4, 4.0), [1, 16, 92, 232, 260, 112, 16], size: 6pt)
  cdraw.content((15.4, 3.0), [max 2n - 2 holds 2^n], size: 6pt)
})

== balanced bracket sequences

The count of balanced sequences with n pairs is the catalan number
again, the nested-shape counter of the earlier section. Generation
walks a depth recursion: at each position, emit an open when opens
remain, then a close when the depth is positive, and lexicographic
order falls out because the open branch always precedes the close
branch at the same node. Rank and unrank price that order without
walking it: when the string emits a close while an open was legal,
every completion in the skipped open branch ranks earlier, and that
branch holds exactly ballot(o, c) = C(o+c, o) - C(o+c, o-1)
completions with o opens and c closes remaining. Summing those
skips ranks any string, and spending the rank against the same
ledger unranks.

The dry run: the fixture is the rank and unrank anchors over the 14
four-pair strings, asserted by the C\# suite.

+ Unrank(4, 9) prices the open branch before every emit: the first
  block holds ballot(3, 4) = C(7,3) - C(7,2) = 35 - 21 = 14, and
  9 < 14 takes the open.
+ The second block holds ballot(2, 4) = C(6,2) - C(6,1) = 15 - 6 = 9,
  9 is not below 9, so the spend empties the rank and the close
  emits.
+ Rank 0 rides the rest: blocks of 5, 3, and 1 keep taking opens
  until none remain, then three closes finish ()((())), the pinned
  unrank of 9.
+ The rank walk sums the same ledger on (()())(): the first close
  passes a legal open at ballot(1, 4) = 4, two later closes pass at
  1 each, 4 + 1 + 1 = 6.
+ The round trip returns every rank 0 through 13 through both roads,
  and the count itself is the catalan 14.

#table(
  columns: (auto, 1.6fr, auto, auto),
  inset: 4pt,
  table.header([*opens, closes*], [*block*], [*emit*], [*rank*]),
  [4, 4], [ballot(3,4) = 35 - 21 = 14], [(], [9],
  [3, 4], [ballot(2,4) = 15 - 6 = 9], [)], [0],
  [3, 3], [ballot(2,3) = 10 - 5 = 5], [(], [0],
  [2, 3], [ballot(1,3) = 4 - 1 = 3], [(], [0],
  [1, 3], [ballot(0,3) = 1 - 0 = 1], [(], [0],
  [0, 3], [no open left, block 0], [) × 3], [0],
)

The ()((())) and the 6 are the pinned landings, and the listings
below price the order in seven languages.

#listing("dsa/samples-c/src/Ch35/brackets.c", first: 55, last: 95, caption: [c, the ballot difference, rank, unrank over the same ledger])

#listing("dsa/samples-go/ch35/brackets.go", first: 5, last: 50, caption: [go, ballot, the generator, and the rank walk])

#listing("dsa/samples-java/src/Ch35/Brackets.java", first: 53, last: 94, caption: [java, the ballot difference, rank, unrank over the same ledger])

#listing("dsa/samples/src/Ch35/Brackets.cs", first: 67, last: 110, caption: [c\#, rank, unrank, and the ballot helper beneath them])

#listing("dsa/samples-js/src/ch35-brackets.mjs", first: 38, last: 69, caption: [javascript, rank and unrank over the ballot ledger])

#listing("dsa/samples-py/src/Ch35/brackets.py", first: 68, last: 97, caption: [python, rank and unrank, the ballot function above them])

#listing("dsa/samples-lua/ch35_brackets.lua", first: 58, last: 91, caption: [lua, rank and unrank over the same counts])

The fixtures pin the order and the arithmetic. Four pairs hold 14
sequences, opening (((()))), ((()())), ((())()), ((()))(), (()(())),
closing with ()()(()) and ()()()(). Rank of ((()))() is 3, rank of
(()())() is 6, unrank of 9 is ()((()))), and the round trip holds
on all 14 in both directions. Validity is the running depth that
never dips below zero and ends at zero, the profile of () reading 0,
1, 0, with ) ( and (() pinned invalid and unrank(0, 0) the empty
string. The application is icpc world finals 2019 problem D (book
9, chapter 10), circular dna, which decides per-type nesting under
rotation: a type is nested at the cut p exactly when its balance at
p - 1 equals its running minimum, the depth rule of this section
evaluated around the circle.

#diagram([the depth profile of (()())() as a mountain, the ballot-number shelf at the first fork], length: 13pt, {
  // profile 0,1,2,1,2,1,0,1,0 over ( ( ) ( ) ) ( )
  let prof = (0, 1, 2, 1, 2, 1, 0, 1, 0)
  let s = ("(", "(", ")", "(", ")", ")", "(", ")")
  for (i, d) in prof.enumerate() {
    let x = 1.6 + i * 1.15
    if i > 0 {
      cdraw.line((x - 1.15, 6.2 - prof.at(i - 1) * 1.05), (x, 6.2 - d * 1.05), stroke: luma(130))
    }
    cdraw.circle((x, 6.2 - d * 1.05), radius: 0.11, fill: luma(120))
    if i < 8 {
      cdraw.content((x, 7.0), s.at(i), size: 8pt)
    }
    cdraw.content((x, 4.6), [#d], size: 6pt)
  }
  cdraw.content((7.0, 8.0), [the depth mountain of (()())()], size: 6.5pt)
  // the first fork: position 2 emits ) while ( was legal
  cdraw.line((3.9, 3.6), (3.9, 5.05), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((7.0, 3.4), [first fork: ) emitted while ( was legal], size: 6pt)
  cdraw.content((7.0, 2.6), [skipped branch holds ballot(1, 4) = 4 completions], size: 6pt)
  cdraw.content((7.0, 1.8), [ballot(o, c) = C(o+c, o) - C(o+c, o-1)], size: 6pt)
  cdraw.content((7.0, 1.0), [rank = sum of skips, 6 for this string], size: 6pt)
  cdraw.content((14.8, 5.6), [count: catalan C~n~], size: 6pt)
  cdraw.content((14.8, 4.6), [14 at n = 4, round-tripped], size: 6pt)
  cdraw.content((14.8, 3.6), [never below zero, ends zero], size: 6pt)
})

== counting labeled graphs

A simple graph on n labeled vertices chooses each of the C(n,2)
potential edges independently, so the total is 2^C(n,2). The
connected count needs the exponential recurrence: subtract, from
the total, the graphs where vertex 1's component holds exactly k
vertices, choosing the k - 1 companions in C(n-1, k-1) ways,
connecting them in c~k~ ways, and letting the remaining n - k
vertices carry any graph at all, 2^C(n-k,2) ways,

c~n~ = 2^C(n,2) - sum over k of C(n-1, k-1) c~k~ 2^C(n-k,2).

The dry run: the fixture is the exact row to c~8~ with the n = 4
brute, asserted by the C\# suite; C carries the same row.

+ n = 5 holds 2^C(5,2) = 2^10 = 1024 graphs in all.
+ k = 1 isolates vertex 1: C(4,0) × 1 × 2^C(4,2) = 64.
+ k = 2 and k = 3 follow: C(4,1) × 1 × 2^3 = 32, then C(4,2) × 4 ×
  2^1 = 48.
+ k = 4 drags the brute-verified c~4~ along: C(4,3) × 38 × 2^0 = 152.
+ The subtractand sums to 64 + 32 + 48 + 152 = 296, and c~5~ =
  1024 - 296 = 728, the fifth rung of the pinned row 1, 1, 4, 38,
  728, 26704, 1866256, 251548592.
+ The modular twin answers connected(100) mod 1e9+7 = 686310291 off
  the same recurrence.

#diagram([the 1024 graphs of n = 5 split by the size of vertex 1's component, the 296 subtractand shaded against the 728], length: 13pt, {
  let w = v => 12.0 * v / 1024
  let segs = ((64, [k=1: 64]), (32, [32]), (48, [48]), (152, [k=4: 152]), (728, [c~5~ = 728]))
  let x = 2.0
  for (i, s) in segs.enumerate() {
    let (v, lab) = s
    cdraw.rect((x, 3.8), (x + w(v), 5.0), fill: if i < 4 { luma(205) } else { luma(235) }, stroke: luma(180), radius: 0.02)
    if w(v) > 1.6 {
      cdraw.content((x + w(v) / 2, 4.4), lab, size: 6pt)
    }
    x += w(v)
  }
  cdraw.line((2.0, 3.4), (2.0 + w(296), 3.4), stroke: luma(100))
  cdraw.content((2.0 + w(296) / 2, 3.0), [the shaded 296 leaves], size: 6pt)
  cdraw.content((10.0, 2.2), [1024 - 296 = 728], size: 6.5pt)
  cdraw.content((16.4, 6.6), [one term per component size], size: 6pt)
  cdraw.content((16.4, 5.6), [c~4~ = 38 brute over all 64], size: 6pt)
  cdraw.content((16.4, 4.6), [connected(100) mod p = 686310291], size: 6pt)
  cdraw.content((16.4, 3.6), [exact to n = 8, then modular], size: 6pt)
})

The 728 rung and the 686310291 are the pinned landings, and the
listings below run the recurrence in seven languages.

#listing("dsa/samples-c/src/Ch35/labeled.c", first: 54, last: 74, caption: [c, the power of two over pairs, the recurrence loop modular])

#listing("dsa/samples-go/ch35/labeled.go", first: 13, last: 44, caption: [go, one recurrence parameterized by modulus, zero meaning exact])

#listing("dsa/samples-java/src/Ch35/Labeled.java", first: 53, last: 73, caption: [java, the power of two over pairs, the recurrence loop modular])

#listing("dsa/samples/src/Ch35/Labeled.cs", first: 14, last: 51, caption: [c\#, the exact recurrence in longs, the modular twin])

#listing("dsa/samples-js/src/ch35-labeled.mjs", first: 20, last: 31, caption: [javascript, the exact recurrence, the BigInt modular twin below])

#listing("dsa/samples-py/src/Ch35/labeled.py", first: 30, last: 50, caption: [python, the exact and modular recurrences, the brute below])

#listing("dsa/samples-lua/ch35_labeled.lua", first: 35, last: 49, caption: [lua, the modular recurrence with the pow2 table precomputed])

The fixtures pin the row and the two rungs. Exact: graphs on 5
vertices = 1024, and c~1~ through c~8~ = 1, 1, 4, 38, 728, 26704,
1866256, 251548592, with c~4~ = 38 brute-verified over all 2^6 = 64
graphs by a union-find connectivity test. Modular: C(100,2) = 4950,
2^4950 mod 1e9+7 = 281603733, and connected(100) mod 1e9+7 =
686310291. The edges read n = 1 as one graph, connected, n = 2 as
two graphs with one connected, and the c~0~ = 0 convention pinned
explicitly. General technique, exact to n = 8 where every term fits
the native integer, O(n^2) modular beyond.

#diagram([n = 4 split by the size k of vertex 1's component, the blocks multiplying into the 38], length: 13pt, {
  // three block terms for k = 1, 2, 3, plus the total
  let rows = (
    ([k = 1], [C(3,0) \* c~1~ \* 2^3], [8]),
    ([k = 2], [C(3,1) \* c~2~ \* 2^1], [6]),
    ([k = 3], [C(3,2) \* c~3~ \* 2^0], [12]),
    ([c~4~], [64 - 8 - 6 - 12], [38]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.8 - i * 1.25
    cdraw.content((1.6, y), row.at(0), size: 7pt)
    cdraw.rect((4.0, y - 0.35), (9.2, y + 0.35), fill: if i == 3 { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((6.6, y), row.at(1), size: 7pt)
    cdraw.content((10.2, y), row.at(2), size: 7pt)
  }
  cdraw.content((6.6, 8.0), [vertex 1's component holds k of the 4 vertices], size: 6.5pt)
  cdraw.content((6.6, 0.9), [c~4~ = 38, brute-verified over all 64 graphs], size: 6pt)
  cdraw.content((14.6, 6.8), [total graphs: 2^C(n,2)], size: 6pt)
  cdraw.content((14.6, 5.8), [c~1..8~: 1, 1, 4, 38, 728, 26704,], size: 6pt)
  cdraw.content((14.6, 5.3), [1866256, 251548592], size: 6pt)
  cdraw.content((14.6, 4.3), [connected(100) mod p = 686310291], size: 6pt)
  cdraw.content((14.6, 3.3), [O(n^2) modular], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's twelve sample files per language, go test files excluded:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [1296], [static tables, family bitmasks], [modular binomials everywhere, dedekind over family bitmasks with long long, exact catalan through u64],
  [go], [621], [slices, cached table maps], [one recurrence parameterized by modulus for labeled graphs, exact binomials through bits.Div64],
  [java], [1289], [jdk 27 stdlib], [C(67,33) pinned through Long.parseUnsignedLong compared unsigned, the lgamma twin as a nine-coefficient lanczos series, sperner's dedekind over long family bitmasks],
  [c\#], [526], [linq, value tuples, class reuse], [binom, ksubset, and the ch16 and ch28 classes composed across files, dedekind refusing past n = 4],
  [javascript], [450], [BigInt tables, plain Number where small], [catalan as C(2n,n) - C(2n,n+1) with no division, two test files at the 400 sloc house split],
  [python], [853], [lists, inline asserts], [exact ladders with lgamma cross-checks, brute twins inside every family],
  [lua], [1079], [tables, 1-based masks], [the burnside suite generating the 24-rotation group itself and counting fixed colorings directly, decimal-string binomials past 2^63],
)

sources: cp-algorithms, "Binomial Coefficients",
cp-algorithms.com/combinatorics/binomial-coefficients.html,
"Catalan Numbers",
cp-algorithms.com/combinatorics/catalan-numbers.html, "Stars and
bars", cp-algorithms.com/combinatorics/stars_and_bars.html, "The
Inclusion-Exclusion Principle",
cp-algorithms.com/combinatorics/inclusion-exclusion.html,
"Burnside's lemma / Pólya enumeration theorem",
cp-algorithms.com/combinatorics/burnside.html, "Generating all
K-combinations",
cp-algorithms.com/combinatorics/generating_combinations.html, whose
subset-of-mask sibling "Enumerating submasks of a bitmask",
cp-algorithms.com/algebra/all-submasks.html, is named in prose,
"Placing Bishops on a Chessboard",
cp-algorithms.com/combinatorics/bishops-on-chessboard.html,
"Balanced bracket sequences",
cp-algorithms.com/combinatorics/bracket_sequences.html, "Counting
labeled graphs",
cp-algorithms.com/combinatorics/counting_labeled_graphs.html,
"Josephus problem", cp-algorithms.com/others/josephus_problem.html,
and "15 Puzzle Game: Existence Of The Solution",
cp-algorithms.com/others/15-puzzle.html, all accessed 2026-09-20,
cc by-sa 4.0, our own words and code throughout. cp-algorithms
carries no sperner or frobenius article; the sperner section cites
Sperner's 1928 theorem and the LYM inequality by name, and the
frobenius conductor bound is stated as the classical schur-type
result. Application sources: icpc world finals 2018 problem D (book
9, chapter 9), 2023 problem B (book 10, chapter 12), 2017 problem K
(book 10, chapter 8), 2025 problem H (book 10, chapter 13), and 2019
problem D (book 10, chapter 10). Sample behavior verified by the seven
suite gates scoped to chapter 35: c 12 files and 216 checks, go 39
test functions, java 12 files and 216 checks under run-java-samples,
c\# 57
facts, javascript 36 tests and 150 asserts
across the two-file split, python 12 files and 148 asserts, lua 42
checks, zero skipped.
