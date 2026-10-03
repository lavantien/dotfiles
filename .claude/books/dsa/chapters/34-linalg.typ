#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= linear algebra

Matrices earn a chapter in an algorithms book the moment counting
walks, solving systems, and pricing determinants stop being
hand work. The arithmetic partners are chapter 16's modpow and
modinv, #xref-to("dsa", "numtheory") cross-named once and used
throughout, and the exactness ruling is the same one the rest of the
book runs on: elimination over the prime field Z~p~ with p = 1e9+7
gives answers all six languages pin digit for digit, and integer
determinants travel fraction-free so no rounding ever enters. Six
tools make the chapter: gauss-jordan over a prime field, the
bareiss determinant and rank, cramer on the small systems, matrix
exponentiation, kirchhoff's spanning tree count, and hensel lifting
over prime powers.

== gaussian elimination over a prime field

Dense gauss-jordan over Z~p~ with p = 1e9+7 walks the columns left to
right: pick the first nonzero row as the pivot, swap it into place,
normalize the whole pivot row by the inverse of the pivot computed
as pow(pivot, p - 2), then eliminate the pivot column out of every
other row. Because the field is prime, every nonzero element
inverts and the algorithm never divides by zero mid-flight, and
because the arithmetic is exact, a solved system verifies by
plugging back. Three statuses come out of the walk: unique when
every column found a pivot, inconsistent when a zero row carries a
nonzero right-hand side, and underdetermined when some column never
found one. O(n^3).

The dry run: the fixture is the 3x3 system with rows 1, 2, 3, 4, 5,
6, and 7, 8, 10 against 6, 15, 25, whose solution 1, 1, 1 the C\#
suite asserts together with its plug-back, identical in the other
five.

+ Column 0 opens with pivot 1 in place and eliminates 4 and 7
  copies of row 0: row 1 lands 0, -3, -6 | -9 with 5 - 4 × 2 = -3,
  row 2 lands 0, -6, -11 | -17.
+ Column 1 pivots on -3, normalizes row 1 to 0, 1, 2 | 3, then
  clears the column both ways: row 2 lands 0, 0, 1 | 1 with -11 +
  12 = 1 and -17 + 18 = 1, row 0 lands 1, 0, -1 | 0.
+ Column 2 pivots on 1 and clears upward, finishing row 0 at 1, 0,
  0 | 1 and row 1 at 0, 1, 0 | 1: the identity with x = 1, 1, 1
  sitting in the last column.
+ The plug-back is the suite's own assert: 1 + 2 + 3 = 6,
  4 + 5 + 6 = 15, 7 + 8 + 10 = 25.
+ The modular twist solves 2x = 1 in the field, the pivot row
  normalized by pow(2, p - 2) = 500000004, the pinned half, so the
  diagonal system answers 500000004, 1.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*after*], [*row 0*], [*row 1*], [*row 2*]),
  [start], [1, 2, 3 | 6], [4, 5, 6 | 15], [7, 8, 10 | 25],
  [column 0], [1, 2, 3 | 6], [0, -3, -6 | -9], [0, -6, -11 | -17],
  [column 1], [1, 0, -1 | 0], [0, 1, 2 | 3], [0, 0, 1 | 1],
  [column 2], [1, 0, 0 | 1], [0, 1, 0 | 1], [0, 0, 1 | 1],
)

The 1, 1, 1 closes the walk as pinned, and the listings below run
the same column walk in six languages.

#listing("dsa/samples-c/src/Ch34/gauss.c", first: 55, last: 80, caption: [c, the column walk, swap, inverse normalize, elimination, the column-to-row map])

#listing("dsa/samples/src/Ch34/Gauss.cs", first: 37, last: 61, caption: [c\#, the same loop, modpow pulled from the chapter 16 class])

#listing("dsa/samples-go/ch34/gauss.go", first: 47, last: 73, caption: [go, the loop with modinv inline, the where map read at the end])

#listing("dsa/samples-js/src/ch34-gauss.mjs", first: 29, last: 49, caption: [javascript, the same loop, every residue product on BigInt past the 2^53 boundary])

#listing("dsa/samples-py/src/Ch34/gauss.py", first: 18, last: 43, caption: [python, the whole solver, three statuses, one list comprehension per row op])

#listing("dsa/samples-lua/ch34_gauss.lua", first: 31, last: 53, caption: [lua, the same loop, plain products with a percent every step])

The fixture families pin the behavior. The 3x3 system with
coefficients 1, 2, 3 by rows, 4, 5, 6, and 7, 8, 10 against the
right-hand side 6, 15, 25 solves to 1, 1, 1, with the plug-back
asserted. The modular twist is the teaching row: the diagonal system
2, 0, 0, 1 against 1, 1 solves to 500000004 and 1, because one half
in this field is the pinned inverse of 2, the same constant chapter
16 carries. The dependent pair 1, 1 and 2, 2 refuses twice, once as
inconsistent against 0, 1, the zero-times-x-equals-one row, and once
as underdetermined against 2, 4, no solution emitted either way. The
edges run the 1x1 system 2x = 4 to x = 2 and the identity returning
its right-hand side untouched.

The application is icpc world finals 2022 problem P (book 9,
chapter 11), turning red, where lights and buttons form a linear
system over Z~3~, each light one equation in the press counts
and each press contributing its color's shift. The official
solution propagates per connected component because each variable
appears in at most two equations, and plain elimination answers the
same question: any subset of independent equations solves, and the
component structure only changes the bookkeeping, never the
solution set.

#diagram([the 3x3 fixture mid-elimination, the pivot row normalized by the modular inverse, zeros above and below, the plug-back underneath], length: 13pt, {
  // A x = b mid-elimination after the second pivot normalized
  let rows = (
    ([1], [0], [-1], [0]),
    ([0], [1], [2], [3]),
    ([0], [0], [1], [1]),
  )
  for (r, row) in rows.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 2.2 + c * 1.5
      let y = 6.4 - r * 1.0
      let piv = c == r
      cdraw.rect((x, y - 0.4), (x + 1.5, y + 0.4), fill: if c == r { luma(205) } else { luma(238) }, radius: 0.02)
      cdraw.content((x + 0.75, y), v, size: 8pt)
      if c < 3 {
        cdraw.content((x + 1.5, y), [ ], size: 6pt)
      }
    }
  }
  cdraw.line((7.0, 4.7), (7.0, 6.9), stroke: luma(160))
  cdraw.content((4.6, 7.4), [augmented tableau, pivots shaded], size: 6.5pt)
  cdraw.content((4.0, 3.4), [row 1 normalized by the inverse of -3], size: 6pt)
  cdraw.content((4.0, 2.6), [the last pivot then reads x = 1, 1, 1], size: 6pt)
  cdraw.content((4.0, 1.8), [plug-back: 1 + 2 + 3 = 6, 4 + 5 + 6 = 15, 7 + 8 + 10 = 25], size: 6pt)
  cdraw.content((13.4, 6.4), [p = 1e9+7, every nonzero inverts], size: 6pt)
  cdraw.content((13.4, 5.4), [half = 500000004, the ch16 pin], size: 6pt)
  cdraw.content((13.4, 4.4), [zero row, nonzero rhs: inconsistent], size: 6pt)
  cdraw.content((13.4, 3.4), [a column without a pivot: underdetermined], size: 6pt)
  cdraw.content((13.4, 2.4), [O(n^3), exact modular arithmetic], size: 6pt)
})

== the fraction-free determinant and rank

Elimination over the rationals trades exactness for fractions, and
over the reals it trades exactness for rounding. The bareiss
variant keeps integers: each step subtracts cross products, the
cell times the pivot minus the cell's column mate times the pivot
row, and divides exactly by the previous pivot. The division is
exact because every intermediate entry is itself an integer minor
of the original matrix, which is the whole theorem, and the suites
assert the remainder of that division is zero. When the matrix is
square and full rank the determinant is the sign times the last
pivot, a swap flipping the sign, otherwise 0, and the rank is the
pivot count, valid over the rationals for integer matrices.

The dry run: the fixtures are det of 1, 2, 3, 4 at -2 and the
singular 1, 2, 3 by 4, 5, 6 by 7, 8, 9 at det 0, rank 2, both
asserted by the C\# suite, identical in the other five.

+ The 2x2 pivots on 1 with prev = 1, so the exact division divides
  silently: det = 1 × 4 - 2 × 3 = -2 at rank 2.
+ The 3x3 pivots on 1 again, and the cross-product step computes
  each cell as the cell times the pivot minus its column mate times
  the pivot row: row 1 lands -3, -6 with 1 × 5 - 4 × 2 = -3, row 2
  lands -6, -12 with 1 × 8 - 7 × 2 = -6.
+ The second pivot is -3 and row 2 divides exactly: (-3 × -12 -
  -6 × -6) / 1 = 36 - 36 = 0.
+ The third column holds no nonzero pivot, so the walk stops at
  det 0 with rank 2, the two pivots placed.

#diagram([the singular 3x3 collapsing one pivot at a time, the cross products of the shaded cell spelled out, the 2x2 corner -2 alongside], length: 13pt, {
  // frames: original, schur complement after pivot 1, dead cell after pivot -3
  let frames = (
    (((1, 2, 3), (4, 5, 6), (7, 8, 9)), [pivot 1], (1, 0)),
    (((-3, -6), (-6, -12)), [pivot -3], (1, 1)),
    (((0,),), [no third pivot], (0, 0)),
  )
  for (f, fr) in frames.enumerate() {
    let (grid, cap, hot) = fr
    let x0 = 1.2 + f * 6.2
    for (r, row) in grid.enumerate() {
      for (c, v) in row.enumerate() {
        cdraw.rect((x0 + c * 1.25, 6.4 - r * 1.05), (x0 + c * 1.25 + 1.25, 7.45 - r * 1.05), fill: if (r, c) == hot { luma(205) } else { luma(238) }, radius: 0.02)
        cdraw.content((x0 + c * 1.25 + 0.625, 6.925 - r * 1.05), [#v], size: 8pt)
      }
    }
    cdraw.content((x0 + 0.625 * grid.at(0).len(), 8.0), cap, size: 6.5pt)
  }
  cdraw.content((2.6, 3.7), [1 × 5 - 4 × 2 = -3], size: 6pt)
  cdraw.content((8.9, 3.7), [(-3 × -12 - -6 × -6) / 1 = 0], size: 6pt)
  cdraw.content((2.6, 2.8), [the 2x2: 1 × 4 - 2 × 3 = -2, rank 2], size: 6pt)
  cdraw.content((2.6, 1.9), [division by prev exact, remainder 0 asserted], size: 6pt)
  cdraw.content((2.6, 1.0), [det 0 here, rank = pivots placed = 2], size: 6pt)
})

The -2 and the rank-2 zero land as pinned, and the listings below
run bareiss in six languages.

#listing("dsa/samples-c/src/Ch34/determinant.c", first: 27, last: 67, caption: [c, the bareiss function, cross products divided by the previous pivot, det and rank out])

#listing("dsa/samples/src/Ch34/Determinant.cs", first: 10, last: 47, caption: [c\#, the same function over longs, the exact division on one line])

#listing("dsa/samples-go/ch34/determinant.go", first: 9, last: 50, caption: [go, bareiss with the pivot search, the permutation expansion below])

#listing("dsa/samples-js/src/ch34-determinant.mjs", first: 10, last: 43, caption: [javascript, bareiss, the division asserted exact, an integer minor per cell])

#listing("dsa/samples-py/src/Ch34/determinant.py", first: 17, last: 41, caption: [python, the function with the exactness assert inline])

#listing("dsa/samples-lua/ch34_determinant.lua", first: 8, last: 40, caption: [lua, the same function, error thrown if the division goes inexact])

The anchors open small, det of 1, 2, 3, 4 is -2 at rank 2 and the
identity gives 1, then the singular family: 1, 2, 3 by 4, 5, 6 by
7, 8, 9 has determinant 0 at rank 2, the doubled row ranks 1, the
zero matrix ranks 0, and the diagonal 2, 3, 4 gives 24. The 4x4
pair carries the real weight, det 3 and det 12, with their product
matrix pinning det(A B) = det(A) det(B) = 36 and every 4x4 answer
re-derived by permutation-sign expansion in each suite. The sphinx
family rides the same core: the five question rows 1, 0, 0 and
0, 1, 0 and 0, 0, 1 and 1, 1, 1 and 1, 2, 3 give ten triple
determinants reading -2, -2, -1, 1, 1, 1, 1, 1, 1, 3 sorted, all
nonzero, so every choice of three questions is an independent
system. Nine of the ten are plus or minus 1 or 2, and the triple
holding the first, second, and fifth rows gives 3, one more than
the icpc problem statement's parenthetical claims.

The application is icpc world finals 2023 problem A (book 9,
chapter 12), riddle of the sphinx, whose solvability after any
single lie is exactly this argument: whichever answer is false, the
surviving three rows stay independent, so the system always solves.

#diagram([the 4x4 bareiss tableau with the exact-division minors shaded and det 3 landing in the corner cell, the zero-pivot rank-2 example beside it], length: 13pt, {
  // A4 = [[2,1,0,3],[1,0,1,1],[4,2,1,7],[1,1,1,1]], pivots 2, -1, -1, corner 3
  let m = ((2, 1, 0, 3), (1, 0, 1, 1), (4, 2, 1, 7), (1, 1, 1, 1))
  for (r, row) in m.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 1.4 + c * 1.3
      let y = 6.6 - r * 0.95
      let corner = r == 3 and c == 3
      let piv = c == r and r < 3
      cdraw.rect((x, y - 0.42), (x + 1.3, y + 0.42), fill: if corner { luma(180) } else if piv { luma(205) } else { luma(238) }, radius: 0.02)
      cdraw.content((x + 0.65, y), [#v], size: 8pt)
    }
  }
  cdraw.content((4.0, 7.6), [pivots 2, -1, -1 shaded, det 3 in the corner], size: 6.5pt)
  cdraw.content((4.0, 1.9), [cell = (cell * piv - col mate * piv row) / prev], size: 6pt)
  cdraw.content((4.0, 1.1), [every intermediate an integer minor, division exact], size: 6pt)
  // the singular 3x3 beside it
  let s = ((1, 2, 3), (4, 5, 6), (7, 8, 9))
  for (r, row) in s.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 11.6 + c * 1.3
      let y = 6.6 - r * 0.95
      let dead = r == 2 and c >= 2
      cdraw.rect((x, y - 0.42), (x + 1.3, y + 0.42), fill: if dead { luma(215) } else { luma(238) }, radius: 0.02)
      cdraw.content((x + 0.65, y), [#v], size: 8pt)
    }
  }
  cdraw.content((13.5, 7.6), [the rank-2 stop], size: 6.5pt)
  cdraw.content((13.5, 1.9), [third pivot never found: 0, 0], size: 6pt)
  cdraw.content((13.5, 1.1), [det 0, rank = pivots placed = 2], size: 6pt)
  cdraw.content((18.6, 5.4), [sign flips once per swap], size: 6pt)
  cdraw.content((18.6, 4.4), [det(A B) = det(A) det(B) = 36], size: 6pt)
  cdraw.content((18.6, 3.4), [sphinx triples: all nonzero], size: 6pt)
})

== cramer on the small systems

When the system is 2x2 or 3x3, determinants solve it directly:
component i of the solution is the determinant of A with column i
replaced by b, divided by det(A). Cramer's rule is not the tool for
large systems, O(n!) if generalized naively, but at these sizes the
expansions are three products each and the answer stays exact in
integers. The cross-language value is the reduced fraction pair:
each component travels as a numerator and denominator reduced by
their gcd with the denominator kept positive, so a negative
determinant flips both signs and all six languages assert identical
pairs. det 0 reports no unique solution.

The dry run: the fixture is the 2x2 system 2, 3, 4, 5 against 7, 9,
whose determinant -2 and answers -4 and 5 the C\# suite asserts as
reduced pairs, identical in the other five.

+ The denominator comes first: det(A) = 2 × 5 - 3 × 4 = -2.
+ Replacing column 0 by b reads 7, 3, 9, 5: det = 7 × 5 - 3 × 9 =
  8, so x1 = 8 / -2 = -4, the negative determinant flipping the
  sign.
+ Replacing column 1 reads 2, 7, 4, 9: det = 2 × 9 - 7 × 4 = -10,
  so x2 = -10 / -2 = 5.
+ Both answers travel as pairs over a positive denominator, -4
  over 1 and 5 over 1, the cross-language shape.
+ The diagonal 2, 0, 0, 4 against 1, 1 goes to fractions the same
  way: det 2 × 4 = 8, the swapped columns read 4 and 2, and the
  answers land at 1 over 2 and 1 over 4.
+ The singular pair 1, 2, 2, 4 reads det 1 × 4 - 2 × 2 = 0 and
  reports no unique solution.

#diagram([the 2x2 fixture with each column swapped for b in turn, the replaced column shaded, each determinant and division written underneath], length: 13pt, {
  // A, A with column 0 = b, A with column 1 = b
  let mats = (
    (((2, 3), (4, 5)), none, [det = 2 × 5 - 3 × 4 = -2]),
    (((7, 3), (9, 5)), 0, [det = 8, x1 = 8 / -2 = -4]),
    (((2, 7), (4, 9)), 1, [det = -10, x2 = -10 / -2 = 5]),
  )
  for (k, m) in mats.enumerate() {
    let (grid, col, note) = m
    let x0 = 1.2 + k * 6.4
    for (r, row) in grid.enumerate() {
      for (c, v) in row.enumerate() {
        cdraw.rect((x0 + c * 1.3, 6.3 - r * 1.15), (x0 + c * 1.3 + 1.3, 7.45 - r * 1.15), fill: if c == col { luma(205) } else { luma(238) }, radius: 0.02)
        cdraw.content((x0 + c * 1.3 + 0.65, 6.875 - r * 1.15), [#v], size: 8pt)
      }
    }
    cdraw.content((x0 + 1.3, 8.0), if col == none { [A] } else { [column #col = b] }, size: 6.5pt)
    cdraw.content((x0 + 1.3, 4.5), note, size: 6pt)
  }
  cdraw.content((1.2, 3.4), [pairs: -4 over 1 and 5 over 1], size: 6pt)
  cdraw.content((1.2, 2.5), [diagonal case: 1 over 2 and 1 over 4], size: 6pt)
  cdraw.content((1.2, 1.6), [det 0 refuses, no unique solution], size: 6pt)
})

The -4 and the 5 land as pinned, and the listings below solve both
sizes in six languages.

#listing("dsa/samples-c/src/Ch34/cramer.c", first: 50, last: 89, caption: [c, the 2x2 and 3x3 minors, the fraction assembly with the gcd reduce])

#listing("dsa/samples/src/Ch34/Cramer.cs", first: 13, last: 49, caption: [c\#, solve, the reduce keeping the denominator positive, both minor expansions])

#listing("dsa/samples-go/ch34/cramer.go", first: 20, last: 64, caption: [go, the fraction pair reduce and the cramer driver over both sizes])

#listing("dsa/samples-js/src/ch34-cramer.mjs", first: 27, last: 45, caption: [javascript, det2, det3, and the column replacement building each minor])

#listing("dsa/samples-py/src/Ch34/cramer.py", first: 28, last: 52, caption: [python, det3, the column replacement, cramer emitting fraction pairs])

#listing("dsa/samples-lua/ch34_cramer.lua", first: 20, last: 45, caption: [lua, the two expansions and the fraction reduce, 1-based columns])

The fixtures pin the four systems. The integer pair 2, 3, 4, 5
against 7, 9 has determinant -2 and solves to -4 and 5, the pair
that shows the negative determinant flipping the numerator sign.
The diagonal 2, 0, 0, 4 against 1, 1 has determinant 8 and solves
to the fraction pairs 1 over 2 and 1 over 4, integers in, fractions
out, with no float anywhere. The 3x3 with a zero leading column
solves to 0, 2, 1 at determinant -1, and the sphinx-flavored system
with rows 1, 1, 1, 1, 2, 3, 2, 3, 1 against 14, 33, 26 has
determinant -3 and solves to 2, 5, 7, every suite plugging the
fractions back into A x = b exactly. The singular pair 1, 2, 2, 4
against 3, 6 reads det 0 and refuses.

The application is the same icpc world finals 2023 problem A
(book 9, chapter 12): once the lie is identified, the surviving
3x3 is solved exactly this way, and the answer's fractions stay
honest because no division ever rounds.

#diagram([the sphinx 5x3 question matrix with the ten triple determinants tallied beside it, the solve's 3x3 shaded, the three replaced-column matrices lined up], length: 13pt, {
  // question rows
  let rows = ((1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 1), (1, 2, 3))
  for (r, row) in rows.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 1.4 + c * 1.2
      let y = 6.8 - r * 0.85
      let kept = r == 3 or r == 4
      cdraw.rect((x, y - 0.38), (x + 1.2, y + 0.38), fill: if kept { luma(215) } else { luma(238) }, radius: 0.02)
      cdraw.content((x + 0.6, y), [#v], size: 8pt)
    }
    cdraw.content((5.3, 6.8 - r * 0.85), [q#(r + 1)], size: 6pt)
  }
  cdraw.content((3.0, 7.8), [the five question rows], size: 6.5pt)
  // the tally
  cdraw.content((8.6, 7.8), [ten triple determinants, sorted], size: 6.5pt)
  let tall = (-2, -2, -1, 1, 1, 1, 1, 1, 1, 3)
  for (i, v) in tall.enumerate() {
    let x = 8.0 + calc.rem(i, 5) * 1.0
    let y = 6.8 - calc.floor(i / 5) * 0.9
    cdraw.rect((x, y - 0.35), (x + 1.0, y + 0.35), fill: if v == 3 { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((x + 0.5, y), [#v], size: 8pt)
  }
  cdraw.content((11.2, 5.9), [all nonzero: any 3 solve], size: 6pt)
  cdraw.content((11.2, 5.1), [the 3 is q1, q2, q5], size: 6pt)
  // the solve's three replaced-column matrices, b = 14, 33, 26
  let mats = (
    (((14, 1, 1), (33, 2, 3), (26, 3, 1)), -6, 2),
    (((1, 14, 1), (1, 33, 3), (2, 26, 1)), -15, 5),
    (((1, 1, 14), (1, 2, 33), (2, 3, 26)), -21, 7),
  )
  for (k, mat) in mats.enumerate() {
    let x0 = 1.0 + k * 4.2
    for (r, row) in mat.at(0).enumerate() {
      for (c, v) in row.enumerate() {
        let x = x0 + c * 1.1
        let y = 3.1 - r * 0.8
        cdraw.rect((x, y - 0.35), (x + 1.1, y + 0.35), fill: if c == k { luma(205) } else { luma(238) }, radius: 0.02)
        cdraw.content((x + 0.55, y), [#v], size: 7pt)
      }
    }
    cdraw.content((x0 + 1.65, 0.7), [det #mat.at(1) over -3 = #mat.at(2)], size: 6.5pt)
  }
  cdraw.content((7.0, 4.1), [the solve's matrix, column k replaced by b: rows q4, q5, and the third true equation], size: 6pt)
  cdraw.content((16.6, 6.8), [det(A) = -3, x = 2, 5, 7], size: 6pt)
  cdraw.content((16.6, 5.8), [pairs reduced, denominator positive], size: 6pt)
  cdraw.content((16.6, 4.8), [negative det flips both signs], size: 6pt)
  cdraw.content((16.6, 3.8), [det 0: no unique solution], size: 6pt)
})

== matrix exponentiation

Binary exponentiation lifts from scalars to matrices unchanged:
seed the result with the identity, square the base per exponent bit,
multiply into the result on the set bits, and with a modulus given,
reduce every entry product mod p, O(n^3 log e). The scalar form is
chapter 16's, #xref-to("dsa", "numtheory"), and only the
associativity of matrix multiplication is new. Two applications
ride it. Fibonacci: the companion matrix 1, 1, 1, 0 raised to the
n has fib(n) in its upper right entry, so one exponentiation
replaces n additions, and the pins stay exact up to fib(78) =
8944394323791464, the largest value under the 2^53 ceiling that
keeps javascript's Number honest, with fib(100) mod 1e9+7 =
687995182 and fib(10^18) mod 1e9+7 = 209783453 beyond it. Walk
counting: the kth power of a digraph's adjacency matrix counts
length-k walks, entry i, j holding the walks from i to j, and the
sum of all entries counts them everywhere.

The dry run: the fixtures are the walk digraph 0 to 1, 0 to 2, 1 to
2, 2 to 0 with its square and fourth power pinned entry for entry
by the C\# suite, and fib(50) = 12586269025 off the companion
matrix, identical in the other five.

+ The adjacency matrix reads A = 0, 1, 1 over 0, 0, 1 over 1, 0, 0,
  four 1s, one per directed edge.
+ Squaring folds walks through every middle vertex: A^2 lands 1, 0,
  1 over 1, 0, 0 over 0, 1, 1, its five 1s exactly the five 2-walks
  0-2-0, 0-1-2, 1-2-0, 2-0-1, 2-0-2, total 5.
+ The fourth power squares again: row 0 of A^2 against its own
  column 2 gives 1 × 1 + 1 × 1 = 2, the two 4-walks from 0 to 2.
+ A^4 lands 1, 1, 2 over 1, 0, 1 over 1, 1, 1 at total 9, both
  matrices asserted entry for entry.
+ The fib side splits the exponent, 50 = 32 + 16 + 2, and keeps
  F^2, F^16, F^32, whose product F^50 reads fib(50) = 12586269025
  in the 0, 1 entry, F^2 itself the first squaring with 1 + 1 = 2
  in the corner.

#diagram([the walk digraph's matrix squared twice, A then A^2 then A^4 as grids of walk counts, the totals rising 5 then 9, the two 0 to 2 four-walks spelled out], length: 13pt, {
  // A = [[0,1,1],[0,0,1],[1,0,0]] over the 4-edge digraph
  let mats = (
    (((0, 1, 1), (0, 0, 1), (1, 0, 0)), [A], [four 1s, one per edge]),
    (((1, 0, 1), (1, 0, 0), (0, 1, 1)), [A^2], [five 2-walks, total 5]),
    (((1, 1, 2), (1, 0, 1), (1, 1, 1)), [A^4], [total 9, 0 to 2 twice]),
  )
  for (k, m) in mats.enumerate() {
    let (grid, cap, note) = m
    let x0 = 1.2 + k * 6.6
    for (r, row) in grid.enumerate() {
      for (c, v) in row.enumerate() {
        cdraw.rect((x0 + c * 1.15, 6.5 - r * 1.0), (x0 + c * 1.15 + 1.15, 7.5 - r * 1.0), fill: if v > 0 { luma(205) } else { luma(238) }, radius: 0.02)
        cdraw.content((x0 + c * 1.15 + 0.575, 7.0 - r * 1.0), [#v], size: 8pt)
      }
    }
    cdraw.content((x0 + 1.725, 8.0), cap, size: 6.5pt)
    cdraw.content((x0 + 1.725, 4.0), note, size: 6pt)
    if k < 2 { cdraw.content((x0 + 4.55, 7.0), [square], size: 6pt) }
  }
  cdraw.content((1.2, 2.8), [the five 2-walks: 0-2-0, 0-1-2, 1-2-0, 2-0-1, 2-0-2], size: 6pt)
  cdraw.content((1.2, 1.9), [0 to 2 in four steps: 0-1-2-0-2 and 0-2-0-1-2], size: 6pt)
  cdraw.content((1.2, 1.0), [fib side: F^50\[0\]\[1\] = 12586269025], size: 6pt)
})

The 5, the 9, and the 12586269025 land as pinned, and the listings
below raise matrices in six languages.

#listing("dsa/samples-c/src/Ch34/matpow.c", first: 27, last: 62, caption: [c, the triple-loop multiply with its optional mod, the square-and-multiply power])

#listing("dsa/samples/src/Ch34/Matpow.cs", first: 11, last: 49, caption: [c\#, pow skipping the last squaring, the multiply reducing per entry])

#listing("dsa/samples-go/ch34/matpow.go", first: 5, last: 48, caption: [go, matmul and matpow, the top-bit squaring skip spelled out])

#listing("dsa/samples-js/src/ch34-matpow.mjs", first: 13, last: 58, caption: [javascript, the number and bigint multiplies, the same power loop over both])

#listing("dsa/samples-py/src/Ch34/matpow.py", first: 18, last: 39, caption: [python, matmul with an optional mod, matpow over the exponent bits])

#listing("dsa/samples-lua/ch34_matpow.lua", first: 10, last: 47, caption: [lua, the multiply, the identity seed, the power loop])

The fixtures pin both applications. The identity anchors read
fib(0) through fib(3) as 0, 1, 1, 2 off F^0 and F^1 = F, the exact
ladder pins fib(10) = 55, fib(50) = 12586269025, and fib(78) =
8944394323791464 with every value re-derived by plain iterative
addition, and the modular pair pins the two residues above. The
walk graph runs four edges, 0 to 1, 0 to 2, 1 to 2, and 2 to 0:
its square is pinned entry for entry with 5 total 2-walks, and its
fourth power holds 2 walks from 0 to 2 with 9 walks total, the
modular road matching the exact one on the small entries.

#diagram([the fib 2x2 squaring chain against the bits of 50, the kept powers multiplied in, and the walk graph with its A^4 total], length: 13pt, {
  // 50 = 110010b: F^2, F^16, F^32 multiplied in
  let bits = (1, 1, 0, 0, 1, 0)
  for (i, b) in bits.enumerate() {
    let x = 1.6 + i * 1.5
    cdraw.rect((x, 6.5), (x + 1.5, 7.3), fill: if b == 1 { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((x + 0.75, 6.9), [#b], size: 8pt)
  }
  cdraw.content((5.4, 7.8), [50 = 110010, the kept bits shaded], size: 6.5pt)
  // the squaring chain: F^2, F^4, F^8, F^16, F^32 with values
  let chain = (
    ([F^2], ((2, 1), (1, 1)), true),
    ([F^4], ((5, 3), (3, 2)), false),
    ([F^8], ((34, 21), (21, 13)), false),
    ([F^16], ((1597, 987), (987, 610)), true),
    ([F^32], ((3524578, 2178309), (2178309, 1346269)), true),
  )
  for (k, c) in chain.enumerate() {
    let x0 = 0.8 + k * 3.8
    cdraw.content((x0 + 1.3, 5.6), c.at(0), size: 6.5pt)
    for (r, row) in c.at(1).enumerate() {
      for (q, v) in row.enumerate() {
        let x = x0 + q * 1.35
        let y = 4.7 - r * 0.85
        cdraw.rect((x, y - 0.38), (x + 1.35, y + 0.38), fill: if c.at(2) { luma(215) } else { luma(240) }, radius: 0.02)
        cdraw.content((x + 0.675, y), [#v], size: 6.5pt)
      }
    }
    if k < 4 {
      cdraw.line((x0 + 3.1, 4.3), (x0 + 3.7, 4.3), stroke: luma(120), mark: (end: ">"))
    }
  }
  cdraw.content((11.0, 2.9), [F^2 * F^16 * F^32 = F^50, entry 0,1 = fib(50) = 12586269025], size: 6pt)
  // the walk graph: 0->1, 0->2, 1->2, 2->0
  let nv = ((3.0, 1.4, [0]), (1.4, 0.1, [1]), (4.9, 0.1, [2]))
  let edge = (a, b) => cdraw.line(nv.at(a).slice(0, 2), nv.at(b).slice(0, 2), stroke: luma(100), mark: (end: ">"))
  edge(0, 1); edge(0, 2); edge(1, 2); edge(2, 0)
  for v in nv {
    cdraw.circle((v.at(0), v.at(1)), radius: 0.34, fill: luma(240), stroke: luma(120))
    cdraw.content((v.at(0), v.at(1)), v.at(2), size: 8pt)
  }
  cdraw.content((3.2, 0.9), [4 edges], size: 6pt)
  cdraw.content((18.4, 6.9), [kept powers multiply in], size: 6pt)
  cdraw.content((18.4, 5.9), [exact to fib(78) = 2^53 safe], size: 6pt)
  cdraw.content((18.4, 4.9), [fib(10^18) mod p by 60 squarings], size: 6pt)
  cdraw.content((18.4, 3.9), [A^4 total walks 9, 0 to 2 twice], size: 6pt)
  cdraw.content((18.4, 2.9), [O(n^3 log e)], size: 6pt)
  cdraw.content((9.5, 0.3), [A^k\[i\]\[j\] = length-k walks i to j], size: 6pt)
})

== kirchhoff's matrix-tree count

The spanning trees of an undirected multigraph are counted by a
determinant. Build the laplacian, the degree of each vertex on the
diagonal and minus the edge multiplicity off it, self loops
dropped because they join nothing, delete any one row and the same
column, and the determinant of the minor is the tree count. The
proof is an elimination argument on the incidence matrix, and the
tool here is the bareiss core from the determinant section carried
in file, the house standalone pattern, so every language answers
from its own small integer determinant.

The dry run: the fixture is the triangle with edge 0-1 doubled,
whose count 5 the C\# suite asserts against brute enumeration, the
plain triangle's 3 alongside, identical in the other five.

+ The doubled edge gives degrees 3, 3, 2, so the laplacian reads
  3, -2, -1 over -2, 3, -1 over -1, -1, 2, the doubled edge visible
  as the off-diagonal -2.
+ Deleting row and column 2 leaves the minor 3, -2 over -2, 3.
+ Its determinant is 3 × 3 - (-2) × (-2) = 9 - 4 = 5, the tree
  count.
+ The 5 trees are visible in the edge set: each doubled copy pairs
  with 1-2, each pairs with 2-0, and 1-2 pairs with 2-0, a 2 + 2 +
  1 = 5 that matches the determinant.
+ The plain triangle reads the same way, minor 2, -1 over -1, 2 at
  4 - 1 = 3.

#diagram([the laplacian of the doubled-edge triangle with its framed 2x2 minor at 5, the five spanning trees drawn underneath], length: 13pt, {
  // edges 0-1 twice, 1-2, 2-0: degrees 3, 3, 2, the doubled edge as -2
  let L = ((3, -2, -1), (-2, 3, -1), (-1, -1, 2))
  for (r, row) in L.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 2.0 + c * 1.15
      let y = 7.6 - r * 1.0
      cdraw.rect((x, y - 0.45), (x + 1.15, y + 0.45), fill: if r < 2 and c < 2 { luma(238) } else { luma(250) }, radius: 0.02)
      cdraw.content((x + 0.575, y), [#v], size: 7pt)
    }
  }
  cdraw.rect((2.0, 5.2), (4.3, 7.6), stroke: luma(60), radius: 0.02)
  cdraw.content((3.15, 8.2), [laplacian of the doubled triangle], size: 6.5pt)
  cdraw.content((3.15, 4.4), [3 × 3 - (-2) × (-2) = 5], size: 6.5pt)
  // the five trees, edge pairs over indices (0,1),(0,1),(1,2),(2,0)
  let E = ((0, 1), (0, 1), (1, 2), (2, 0))
  let trees = ((0, 2), (0, 3), (1, 2), (1, 3), (2, 3))
  for (t, pair) in trees.enumerate() {
    let x0 = 1.0 + t * 3.5
    let Q = ((x0, 3.1), (x0, 1.6), (x0 + 1.4, 2.35))
    for e in pair { cdraw.line(Q.at(E.at(e).at(0)), Q.at(E.at(e).at(1)), stroke: luma(120)) }
    for q in Q { cdraw.circle(q, radius: 0.17, fill: luma(240), stroke: luma(120)) }
  }
  cdraw.content((8.0, 0.8), [the five trees, 2 + 2 + 1 = 5], size: 6pt)
  cdraw.content((11.8, 6.6), [plain triangle: 4 - 1 = 3], size: 6pt)
  cdraw.content((11.8, 5.6), [disconnected trio: det 0], size: 6pt)
})

The 5 and the 3 land as pinned, and the listings below count
spanning trees in six languages.

#listing("dsa/samples-c/src/Ch34/kirchhoff.c", first: 59, last: 78, caption: [c, the laplacian assembly and the minor feeding the in-file bareiss det])

#listing("dsa/samples/src/Ch34/Kirchhoff.cs", first: 10, last: 31, caption: [c\#, the assembly calling the chapter's determinant class])

#listing("dsa/samples-go/ch34/kirchhoff.go", first: 7, last: 31, caption: [go, the assembly over the edge list, bareiss below])

#listing("dsa/samples-js/src/ch34-kirchhoff.mjs", first: 8, last: 47, caption: [javascript, the in-file integer det and the kirchhoff driver over it])

#listing("dsa/samples-py/src/Ch34/kirchhoff.py", first: 17, last: 52, caption: [python, the bareiss core and the assembly, singular minor meaning disconnected])

#listing("dsa/samples-lua/ch34_kirchhoff.lua", first: 41, last: 62, caption: [lua, the assembly over 0-based edge fixtures into 1-based tables])

The fixtures are brute-verified in every suite, union-find
enumerating all size n - 1 edge subsets that connect everything.
The basics: the triangle K3 counts 3, the path P4 counts 1, and
the 4-cycle C4 counts 4. Cayley's formula lands as the check, K4
counting 16 = 4^2. The multigraph family is the honest part: a
triangle with edge 0-1 doubled counts 5, both parallel edges
counted while the 2-cycle they form alone is rejected, the bowtie,
two triangles sharing vertex 0, counts 3 times 3 = 9, and the
disconnected trio counts 0, the singular minor reading exactly
that. The counts stay small exact integers identical across all
six languages, O(n^3):

#diagram([K4 with its laplacian grid, the 3x3 minor framed, det 16 annotated as the tree count with three of the sixteen trees drawn], length: 13pt, {
  // K4 graph
  let P = ((2.2, 6.9), (0.9, 5.6), (3.5, 5.6), (2.2, 4.3))
  let E = ((0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3))
  for (a, b) in E {
    cdraw.line(P.at(a).slice(0, 2), P.at(b).slice(0, 2), stroke: luma(150))
  }
  for (i, p) in P.enumerate() {
    cdraw.circle((p.at(0), p.at(1)), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((p.at(0), p.at(1)), [#i], size: 7pt)
  }
  cdraw.content((2.2, 7.7), [K4, six edges], size: 6.5pt)
  // the laplacian with the minor framed
  let L = ((3, -1, -1, -1), (-1, 3, -1, -1), (-1, -1, 3, -1), (-1, -1, -1, 3))
  for (r, row) in L.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 6.8 + c * 1.15
      let y = 6.8 - r * 0.9
      let inside = r < 3 and c < 3
      cdraw.rect((x, y - 0.4), (x + 1.15, y + 0.4), fill: if inside { luma(238) } else { luma(250) }, radius: 0.02)
      cdraw.content((x + 0.575, y), [#v], size: 7pt)
    }
  }
  cdraw.rect((6.8, 4.15), (10.25, 6.85), stroke: luma(60), radius: 0.02)
  cdraw.content((8.5, 7.6), [the laplacian, 3x3 minor framed], size: 6.5pt)
  cdraw.content((8.5, 3.4), [det(minor) = 16 spanning trees = 4^2], size: 6.5pt)
  // three of the sixteen trees
  let trees = (
    (((0, 1)), ((0, 2)), ((0, 3))),
    (((0, 1)), ((1, 2)), ((2, 3))),
    (((0, 2)), ((1, 3)), ((2, 3))),
  )
  for (t, es) in trees.enumerate() {
    let x0 = 1.2 + t * 2.6
    let Q = ((x0, 2.7), (x0 - 0.9, 1.7), (x0 + 0.9, 1.7), (x0, 0.7))
    for (a, b) in es {
      cdraw.line(Q.at(a).slice(0, 2), Q.at(b).slice(0, 2), stroke: luma(120))
    }
    for p in Q {
      cdraw.circle((p.at(0), p.at(1)), radius: 0.2, fill: luma(240), stroke: luma(120))
    }
  }
  cdraw.content((5.4, 0.1), [three of the sixteen], size: 6pt)
  cdraw.content((14.2, 5.9), [degree on the diagonal], size: 6pt)
  cdraw.content((14.2, 4.9), [minus multiplicity off it], size: 6pt)
  cdraw.content((14.2, 3.9), [self loops dropped], size: 6pt)
  cdraw.content((14.2, 2.9), [doubled edge triangle: 5], size: 6pt)
  cdraw.content((14.2, 1.9), [disconnected: singular, 0], size: 6pt)
})

== hensel lifting over prime powers

Linear algebra over Z~p~^k^, p prime, solves systems the plain
field cannot reach, and the tool is newton's iteration wearing
number theory. Solve A x = b mod p with the elimination core, which
needs A invertible there. Then lift one power at a time: compute
the residual r = b - A x mod p^(m+1), which is exactly divisible
by p^m because x already solves mod p^m, divide it down, solve
A t = r over p^m mod p, and add p^m t to x. Each step buys one
base-p digit of the solution, quadratic convergence in the p-adic
metric, and an exact integer solution simply stops moving.

The dry run: the fixture is 2, 1, 1, 1 against 14, 13 over p = 3,
whose climb 1, 0 then 1, 3 then 1, 12 the C\# suite asserts with
its mod 27 plug-back, identical in the other five.

+ Mod 3 the system reads 2x + y = 2 and x + y = 1, since 14 and 13
  reduce to 2 and 1: subtracting gives x = 1, then y = 0.
+ The residual is b - A x = 14 - 2, 13 - 1 = 12, 12, divisible by
  3 exactly, and divided down reads 4, 4, which is 1, 1 mod 3.
+ The correction solves A t = 1, 1 mod 3 to t = 0, 1, so x climbs
  by 3 × (0, 1) to 1, 3, solving mod 9.
+ The next residual is 14 - 5, 13 - 4 = 9, 9, divisible by 9, and
  1, 1 mod 3 gives t = 0, 1 again: x += 9 × (0, 1) lands at 1, 12,
  solving mod 27.
+ The plug-back is the suite's own assert: 2 × 1 + 12 = 14 and
  1 + 12 = 13, both 0 mod 27.
+ Against 5, 4 the same ladder stops early, 1, 0 then 1, 3 then
  1, 3: the residual hits 0, 0 and the exact solution stands
  still.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*solves mod*], [*x*], [*residual b - A x*], [*correction*]),
  [3], [1, 0], [12, 12], [divide by 3, t = 0, 1],
  [9], [1, 3], [9, 9], [divide by 9, t = 0, 1],
  [27], [1, 12], [0, 0], [exact, stands still],
)

The 1, 12 closes the climb as pinned, and the listings below lift
systems in six languages.

#listing("dsa/samples-c/src/Ch34/zpk.c", first: 83, last: 109, caption: [c, the lift loop, residual, divided rhs, correction solve])

#listing("dsa/samples/src/Ch34/Zpk.cs", first: 11, last: 40, caption: [c\#, the same loop over the gauss class, steps collected])

#listing("dsa/samples-go/ch34/zpk.go", first: 10, last: 49, caption: [go, the loop with the divisibility check made loud])

#listing("dsa/samples-js/src/ch34-zpk.mjs", first: 50, last: 67, caption: [javascript, the lift over the small in-file solver, plain Number exact at p = 3])

#listing("dsa/samples-py/src/Ch34/zpk.py", first: 35, last: 51, caption: [python, the loop with the mod-3 gauss core above it])

#listing("dsa/samples-lua/ch34_zpk.lua", first: 69, last: 91, caption: [lua, the lift with the in-file gauss riding along])

The second half of the file is the 2022 world finals Z machinery in
miniature. Cyclic convolution of count arrays over Z~p~^k^ is
the multiset-of-sums operator, out at i plus j mod m accumulating
a\[i\] times b\[j\], and iterating it over a list of levers counts
subset sums: each lever doubles the table into itself shifted by
its own value. The one-dimensional valuation lemma reads the
answer's arithmetic structure: the number of zero levers is the
minimum 2-adic valuation of the projected residue counts.

The fixtures run at p = 3. The matrix 2, 1, 1, 1 against 5, 4
lifts 1, 0 then 1, 3 then 1, 3, the exact solution reached and
standing still, each step's plug-back asserted mod 27. The same
matrix against 14, 13 climbs 1, 0 then 1, 3 then 1, 12, one
base-3 digit per step. The convolution family pins the two levers:
a zero lever doubles every residue count, 2, 0, 0 against 1, 1, 1
giving 2, 2, 2, while a nonzero lever permutes the counts as a
cycle, 1, 1, 0 against 1, 2, 0 giving 1, 3, 2. The levers 1, 1
over Z~3~ give subset-sum counts 1, 2, 1, the empty subset
included, and the levers 0,0, 1,0, 0,1 over Z~3~^2^ fill
the 3 by 3 grid 2, 2, 0 by 2, 2, 0 by 0, 0, 0, re-derived by
direct enumeration of all 8 subsets. The valuation family pins the
minima: 1, 1, 2 and 1, 2, 1 at 0, and 2, 4, 6 and 4, 2, 6 at 1.

The application is icpc world finals 2022 problem Z (book 9,
chapter 11), archaeological recovery, whose state multisets over
Z~3~^k^, projected residue counts, and subset-sum convolutions
are exactly this machinery, with the full recovery algorithm
living in the icpc book.

#diagram([the hensel ladder with x climbing mod 3 to 9 to 27 as base-3 digits, beside the 3x3 subset-sum grid with the four occupied cells shaded], length: 13pt, {
  // the ladder: b = 14, 13 climbing (1,0) -> (1,3) -> (1,12)
  let steps = (("mod 3", "1, 0", "1 | 0"), ("mod 9", "1, 3", "1 | 10"), ("mod 27", "1, 12", "1 | 110"))
  for (k, s) in steps.enumerate() {
    let y = 6.8 - k * 1.5
    cdraw.content((1.0, y), s.at(0), size: 7pt)
    cdraw.rect((2.6, y - 0.45), (4.6, y + 0.45), fill: luma(238), radius: 0.02)
    cdraw.content((3.6, y), s.at(1), size: 8pt)
    cdraw.content((6.6, y), [x digits base 3: #s.at(2)], size: 6.5pt)
    if k < 2 {
      cdraw.line((3.6, y - 0.6), (3.6, y - 0.9), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((3.6, 7.9), [A = 2, 1, 1, 1 against 14, 13], size: 6.5pt)
  cdraw.content((3.6, 1.4), [one newton step buys one digit], size: 6pt)
  cdraw.content((3.6, 0.6), [the exact case stops moving: 1, 3, 1, 3], size: 6pt)
  // the 3x3 subset-sum grid
  let g = ((2, 2, 0), (2, 2, 0), (0, 0, 0))
  for (r, row) in g.enumerate() {
    for (c, v) in row.enumerate() {
      let x = 11.2 + c * 1.2
      let y = 6.4 - r * 1.0
      cdraw.rect((x, y - 0.45), (x + 1.2, y + 0.45), fill: if v > 0 { luma(205) } else { luma(240) }, radius: 0.02)
      cdraw.content((x + 0.6, y), [#v], size: 8pt)
    }
  }
  cdraw.content((13.0, 7.6), [subset sums of 0,0, 1,0, 0,1 over Z~3~^2^], size: 6.5pt)
  cdraw.content((13.0, 2.4), [eight subsets, four cells, 2 each], size: 6pt)
  cdraw.content((13.0, 1.6), [counts 2, 4, 6: min v~2~ = 1], size: 6pt)
  cdraw.content((19.0, 5.9), [residual divisible by p^m exactly], size: 6pt)
  cdraw.content((19.0, 4.9), [convolution = multiset of sums], size: 6pt)
  cdraw.content((19.0, 3.9), [zero lever doubles, nonzero cycles], size: 6pt)
  cdraw.content((19.0, 2.9), [O(n^3 + k n^2) per system], size: 6pt)
})

== across the six languages

Featured build size counted as non-blank, non-comment lines of the
chapter's six sample files per language, go test files excluded:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [843], [static matrices, u64 residues], [plain 64-bit products at 1e9+7, add p before subtracting to stay positive, kirchhoff carries its own det],
  [c\#], [305], [jagged longs, tuples, linq], [reuses the ch16 modpow and the ch34 determinant across files, cramer pairs as value tuples],
  [go], [385], [slices, no imports beyond fmt], [hensel refuses loudly when the residual is not divisible, matrix ops as free functions],
  [javascript], [301], [nested arrays, BigInt at 1e9+7], [the zpk file stays on plain Number, p = 3 keeps every product tiny, exact ints to fib(78)],
  [python], [479], [list rows, inline asserts], [one list comprehension per row operation, permutation-sign cross-checks in-suite],
  [lua], [644], [tables, 1-based rows], [fraction pairs as two-slot tables, the kirchhoff fixtures shifting 0-based edges to 1-based],
)

sources: cp-algorithms, "Gauss & System of Linear Equations",
cp-algorithms.com/linear_algebra/linear-system-gauss.html,
"Kraut & Determinant",
cp-algorithms.com/linear_algebra/determinant-kraut.html, the
fraction-free variant taught here, "Rank of a matrix",
cp-algorithms.com/linear_algebra/rank-matrix.html, "Binary
Exponentiation", cp-algorithms.com/algebra/binary-exp.html, the
scalar base the matrix version lifts, there being no standalone
matrix exponentiation page, and "Kirchhoff Theorem",
cp-algorithms.com/graph/kirchhoff-theorem.html, all accessed
2026-09-20, cc by-sa 4.0, our own words and code throughout.
cp-algorithms carries no cramer or hensel article; those sections
cite the icpc world finals 2023 problem A and 2022 problem Z
solutions as their application sources, and cramer's rule as
standard linear algebra. Sample behavior verified by the six suite
gates scoped to chapter 34: c 6 files and 90 checks, c\# 28 facts,
go 24 test functions, javascript 24 tests and 69 asserts, python 6
files and 86 asserts, lua 24 checks, zero skipped.
