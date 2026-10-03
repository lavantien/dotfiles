#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= matrices and linear systems

A system of linear equations, the matrix notation that compresses it, and
the elimination algorithm that solves it. This chapter runs six moves: the
row picture and the column picture of one fixed 2x2 system with its three
possible outcomes, the algebra of matrices with non-commutativity pinned on
one pair, gaussian elimination with partial pivoting on doubles judged
against exact rational precomputation, the elimination record reused as an
LU factorization with two triangular solves, rank and the null space with
the rank-nullity count, and the inverse with its adjugate shortcut and its
round trip. Every behavioral claim below is one of the 60 checks in the 4
samples of chapter 06 or a sentence quoted from the mml-book draft of
2024-01-15, fetched 2026-09-21 and pinned in the anchor sheet
ref/mml/anchors-la.md. The sibling dsa book runs elimination modulo a prime
for contest determinism (#xref-to("dsa", "linalg")), this chapter runs it
on binary64 doubles with python Fractions as the exact referee, the same
split between measurement and arithmetic that chapter
#xref-to("math", "float") set up for single numbers.

== systems of linear equations

A factory produces $n$ products from $m$ resources, one unit of product
$j$ consumes $a_(i j)$ units of resource $i$, and a production plan
$x_1, ..., x_n$ must exactly consume the stock $b_i$. That bookkeeping
demand, mml Example 2.1 [printed pp 19-21 / pdf pp 25-27], is the system

$ a_(i 1) x_1 + a_(i 2) x_2 + dots + a_(i n) x_n = b_i, quad i = 1, dots, m, $

and mml states the payoff plainly: "In general, for a real-valued system
of linear equations we obtain either no, exactly one, or infinitely many
solutions." This section pins all three outcomes on one family and reads
them twice, once as rows and once as columns.

The fixed 2x2 fixture for the whole chapter is mml's worked illustration
[printed p 21 / pdf p 27]:

$ 4x_1 + 4x_2 = 5, quad 2x_1 - 4x_2 = 1 $

The row picture reads each equation as a line in the $x_1 x_2$ plane, and
the solution as where the lines meet. mml's remark on the geometry: the
solution set "can be a line (if the linear equations describe the same
line), a point, or empty (when the lines are parallel)". The column
picture reads the same system as one vector equation, how much of column
$(4, 2)$ plus how much of column $(4, -4)$ builds the right side $(5, 1)$.

The dry run: eliminate $x_2$ from the second equation using the first.
The multiplier is $2/4 = 1/2$, the second row becomes
$(0, -6 |- 3/2)$, so $x_2 = (-3/2) / (-6) = 1/4$, and back in the first
equation $4x_1 = 5 - 1 = 4$ gives $x_1 = 1$. The two lines cross in
exactly one point, $(1, 1/4)$. The column reading of the same numbers:
$1 (4, 2) + 1/4 (4, -4) = (5, 1)$, one whole first column and a quarter
of the second.

+ The multiplier $1/2$ is exact in binary, so the doubles trace the
  fractions bit for bit.
+ Both intermediate values stay integers or halves: $-6$ and $-3/2$ are
  exactly representable, no rounding enters the trace.
+ The answer $(1, 1/4)$ satisfies both original equations with residual
  exactly 0, checks 1 through 4 of systems.c.

The three outcomes come from mml Example 2.2 [printed pp 19-21 / pdf
pp 25-27], one family with the same first two equations
$x_1 + x_2 + x_3 = 3$ and $x_1 - x_2 + 2x_3 = 2$ and three different
thirds. Elimination with no row swaps classifies all three, and because
every value is an integer or a half, binary64 holds the trace exactly:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*third equation*], [*last row after elimination*], [*outcome*], [*solution set*]),
  [$2x_1 + 3x_3 = 1$], [$0 = -4$], [none], [empty],
  [$x_2 + x_3 = 2$], [$3/2 x_3 = 3/2$], [unique], [$(1, 1, 1)$],
  [$2x_1 + 3x_3 = 5$], [$0 = 0$], [infinite], [$(5/2, 1/2, 0) + t(-3/2, 1/2, 1)$],
)

The no-solution case is a derived contradiction: adding the first two
equations yields $2x_1 + 3x_3 = 5$, and a third equation claiming
$2x_1 + 3x_3 = 1$ says $5 = 1$, which elimination compresses to the dead
row $0 = -4$. The infinite case is the mirror image, the third equation
is exactly the sum of the first two so it adds no information, one
variable runs free and the solution set is a line through
$(5/2, 1/2, 0)$ with direction $(-3/2, 1/2, 1)$. The two-number play of
this section: the family's unique member has 1 solution point, its
contradiction member has 0, and nothing in between exists, because a
linear system cannot have 2.

#listing("math/samples/src/Ch06/systems.c", first: 27, last: 47, caption: [the outcome classifier, elimination without swaps on exact fixtures])

#listing("math/samples/src/Ch06/systems.c", first: 89, last: 114, caption: [the Example 2.2 family, three thirds, three outcomes, two pinned members of the solution line])

#diagram([two lines, one crossing point at (1, 1/4), the row picture of the fixed system], length: 13pt, {
  cdraw.line((-2.4, 0), (18.4, 0), stroke: luma(140))
  cdraw.line((0, -8.8), (0, 12.8), stroke: luma(140))
  cdraw.line((-2.4, 12.4), (18.4, -8.4), stroke: luma(60))
  cdraw.content((0.5, 10.6), [$4x_1 + 4x_2 = 5$], size: 6pt)
  cdraw.line((-2.4, -3.2), (18.4, 7.2), stroke: luma(100))
  cdraw.content((13.8, 5.9), [$2x_1 - 4x_2 = 1$], size: 6pt)
  cdraw.circle((8, 2), radius: 0.35, fill: luma(60))
  cdraw.line((8, 2), (8, 0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((8, 2), (0, 2), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((9.2, 3.0), [$(1, 1/4)$], size: 6pt)
  cdraw.content((18.0, 1.0), [$x_1$], size: 6pt)
  cdraw.content((0.8, 12.0), [$x_2$], size: 6pt)
})

== matrix algebra

Stack the coefficients of the system into a rectangle and the notation
collapses. mml Definition 2.1 [printed p 22 / pdf p 28]: "With $m, n in
NN$ a real-valued $(m, n)$ matrix $A$ is an $m dot n$-tuple of elements
$a_(i j)$, $i = 1, ..., m$, $j = 1, ..., n$, which is ordered according
to a rectangular scheme consisting of $m$ rows and $n$ columns". Rows are
$(1, n)$ matrices, columns are $(m, 1)$ matrices, and both are just
vectors with a shape, the same objects chapter #xref-to("math", "vectors")
tested for independence. The system becomes
$bold(A) bold(x) = bold(b)$ and, in mml's words from the compact
representations of section 2.2.4 [printed p 26 / pdf p 32], "the product
$A x$ is a (linear) combination of the columns of $A$", which is the
column picture of the previous section promoted to notation.

The operations are deliberately boring. Addition and scalar multiplication
touch every entry independently, $a_(i j) + b_(i j)$ and $lambda
a_(i j)$. The transpose, mml Definition 2.4 [printed p 25 / pdf p 31],
flips rows with columns: "For $A in RR^(m times n)$ the matrix $B in
RR^(n times m)$ with $b_(i j) = a_(j i)$ is called the transpose of $A$."
The identity, mml Definition 2.2 [printed pp 23-24 / pdf pp 29-30], is
the matrix of doing nothing: "In $RR^(n times n)$, we define the identity
matrix $I_n$ as the $n times n$-matrix containing 1 on the diagonal and
0 everywhere else", and it satisfies $I_m bold(A) = bold(A) I_n =
bold(A)$. The one operation with structure is the product, mml eq 2.13
[printed pp 22-24 / pdf pp 28-30], an all-pairs grid of dot products:

$ c_(i j) = sum_(l=1)^n a_(i l) b_(l j), quad i = 1, dots, m, quad j = 1, dots, k $

Entry $c_(i j)$ is row $i$ of $bold(A)$ dotted against column $j$ of
$bold(B)$, and the shapes must chain: $bold(A) in RR^(m times n)$ times
$bold(B) in RR^(n times k)$ lands in $RR^(m times k)$, the neighboring
dimensions must agree or the dots have nothing to sum over.

The dry run: mml Example 2.3 [printed p 23 / pdf p 29] pins the whole
structure on

$ bold(A) = mat(1, 2, 3; 3, 2, 1) in RR^(2 times 3), quad bold(B) = mat(0, 2; 1, -1; 0, 1) in RR^(3 times 2) $

+ $c_(1 1)$ is row 1 of $bold(A)$ against column 1 of $bold(B)$:
  $1 dot 0 + 2 dot 1 + 3 dot 0 = 2$.
+ $c_(1 2)$ is row 1 against column 2: $1 dot 2 + 2 dot (-1) + 3 dot 1 =
  3$.
+ The remaining entries follow the same grid, $bold(A) bold(B) = mat(2,
  3; 2, 5)$ in $RR^(2 times 2)$, mml eq 2.15.
+ The reverse order multiplies a different grid, $bold(B) bold(A) =
  mat(6, 4, 2; -2, 0, 2; 3, 2, 1)$ in $RR^(3 times 3)$, mml eq 2.16.

The two-number play: the same two matrices produce 4 entries in one order
and 9 in the other. mml draws the moral: "From this example, we can
already see that matrix multiplication is not commutative, i.e., $A B !=
B A$." What does hold is the rest of the algebra, associativity
$(bold(A) bold(B)) bold(C) = bold(A) (bold(B) bold(C))$ and distributivity
over addition, mml eqs 2.18-2.20, so long chains of products parse without
parentheses ambiguity and factoring works as usual. The triple loop below
is the dot grid made literal, running mml Example 2.4's inverse pair
[printed p 25 / pdf p 31] and confirming the product lands on $I_3$.

#listing("math/samples/src/Ch06/inverse.c", first: 100, last: 113, caption: [the dot grid as a triple loop, Example 2.4 pair multiplied to the identity])

#diagram([one grid entry is one dot product, row 1 of $bold(A)$ against column 2 of $bold(B)$], length: 13pt, {
  let cell(x, y, w, h, v, fill) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, stroke: luma(140), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), v, size: 6pt)
  }
  cell(0.5, 3.6, 0.9, 0.6, [1], luma(205))
  cell(1.4, 3.6, 0.9, 0.6, [2], luma(205))
  cell(2.3, 3.6, 0.9, 0.6, [3], luma(205))
  cell(0.5, 3.0, 0.9, 0.6, [3], luma(245))
  cell(1.4, 3.0, 0.9, 0.6, [2], luma(245))
  cell(2.3, 3.0, 0.9, 0.6, [1], luma(245))
  cdraw.content((1.85, 4.5), [$bold(A)$], size: 6.5pt)
  cell(5.0, 3.6, 0.9, 0.6, [0], luma(245))
  cell(5.9, 3.6, 0.9, 0.6, [2], luma(205))
  cell(5.0, 3.0, 0.9, 0.6, [1], luma(245))
  cell(5.9, 3.0, 0.9, 0.6, [-1], luma(205))
  cell(5.0, 2.4, 0.9, 0.6, [0], luma(245))
  cell(5.9, 2.4, 0.9, 0.6, [1], luma(205))
  cdraw.content((5.9, 4.5), [$bold(B)$], size: 6.5pt)
  cell(9.4, 3.6, 0.9, 0.6, [2], luma(245))
  cell(10.3, 3.6, 0.9, 0.6, [3], luma(205))
  cell(9.4, 3.0, 0.9, 0.6, [2], luma(245))
  cell(10.3, 3.0, 0.9, 0.6, [5], luma(245))
  cdraw.content((10.3, 4.5), [$bold(A) bold(B)$], size: 6.5pt)
  cdraw.line((3.2, 3.9), (4.0, 4.9), stroke: luma(100))
  cdraw.line((4.0, 4.9), (10.75, 4.9), stroke: luma(100))
  cdraw.line((10.75, 4.9), (10.75, 4.28), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.2, 5.15), [row 1], size: 6pt)
  cdraw.line((6.35, 2.4), (11.6, 2.4), stroke: luma(100))
  cdraw.line((11.6, 2.4), (11.6, 3.9), stroke: luma(100))
  cdraw.line((11.6, 3.9), (11.28, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.3, 2.15), [column 2], size: 6pt)
  cdraw.content((10.7, 1.6), [$1 dot 2 + 2 dot (-1) + 3 dot 1 = 3$], size: 6pt)
})

== elimination with partial pivoting

Solving is row bookkeeping. mml section 2.3.2 [printed pp 28-32 / pdf
pp 34-38] names the three elementary transformations that preserve the
solution set: exchange of two rows, multiplication of a row by a nonzero
constant, and addition of one row to another. Repeated in the right order
they drive a matrix to the staircase shape of mml Definition 2.6 [printed
p 30 / pdf p 36]: "A matrix is in row-echelon form if (i) All rows that
contain only zeros are at the bottom of the matrix ... (ii) Looking at
nonzero rows only, the first nonzero number from the left (also called
the pivot or the leading coefficient) is always strictly to the right of
the pivot of the row above it." mml's own definition of the algorithm
aims one step further, to the reduced form: "Gaussian elimination is an
algorithm that performs elementary transformations to bring a system of
linear equations into reduced row-echelon form" [printed p 31 / pdf
p 37]. Numerical code stops at the echelon form and finishes with back
substitution, the same answers for a fraction of the sweeps.

The classification logic falls out of the staircase. mml Example 2.6
[printed pp 29-30 / pdf pp 35-36] runs a 4x5 system whose echelon form
ends in the row $(0, 0, 0, 0, 0 | a + 1)$, and "only for $a = -1$ this
system can be solved": a dead row with a live right side is a
contradiction, a fully dead row is a free variable, a pivot in every
column is a unique solution.

On doubles the bookkeeping acquires an ordering rule. The multiplier
$m = a_(i k) \/ a_(k k)$ divides by the pivot, and a tiny pivot inflates
$m$, which then multiplies every rounding error already sitting in the
pivot row. Partial pivoting swaps the largest magnitude entry of the
elimination column into the pivot seat, which bounds every multiplier by
1 and keeps the error growth tame.

The dry run: the fixture is mml's compact system of eq 2.36 [printed
p 26 / pdf p 32], $2x_1 + 3x_2 + 5x_3 = 1$, $4x_1 - 2x_2 - 7x_3 = 8$,
$9x_1 + 5x_2 - 3x_3 = 2$.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*pivot*], [*multipliers*]),
  [1], [9, row 3 swaps up], [$4/9$, $2/9$],
  [2], [$-38/9$], [$-17/38$],
  [3], [$119/38$], [none left],
)

Back substitution up the staircase gives the exact answer
$x = (291/119, -23/7, 142/119)$, approximately $(2.4454, -3.2857,
1.1933)$, computed once with python Fractions and pinned. The double run
reproduces all three entries to under $10^(-12)$, checks 2 through 4 of
gauss.c, and the largest residual against the original rows measures
$4.4 dot 10^(-16)$, check 5, the referee pattern of chapter
#xref-to("math", "float") scaled up from one arithmetic operation to a
whole algorithm.

The pivot rule earns its keep on the fixture
$mat(10^(-16), 1; 1, 1) bold(x) = vec(1, 2)$. The exact solution is
$x_1 = 10^16 \/ (10^16 - 1)$ and $x_2 = 1 - 1 \/ (10^16 - 1)$, which
equals the shorthand $1 - 10^(-16)$ only after binary64 rounds, both
indistinguishable from 1. Eliminating in the given order computes the multiplier
$1 \/ 10^(-16) = 10^16$, the updated second diagonal
$1 - 10^16 dot 1$ cannot be represented (the odd integer below $10^16$
is not a binary64 value, it rounds back to $-10^16$), and the damage
propagates to $x_1 = (1 - x_2) \/ 10^(-16) = 2.220446049250313$. That
number is machine epsilon at scale 1, the cancellation of two almost
equal numbers divided by something tiny. Swapping the rows first makes
the multiplier $10^(-16)$ and every stored quantity small, and the solve
returns $(1, 0.9999999999999999)$ with error exactly 0. The two-number
play: 1.220446049250313 of error without pivoting, 0.0 with it, on the
same four coefficients in the same precision.

#callout("warning", "THE DISEASE IS THE MULTIPLIER, NOT THE SMALL NUMBER",
[A pivot of $10^(-16)$ is harmless by itself, the system above is barely
sensitive to its data and the pivoted solve is exact. What kills the
plain solve is the multiplier $10^16$ amplifying rounding error that
already exists. Partial pivoting is a bound on multipliers, every one at
most 1 in magnitude, and that is the whole mechanism.])

#listing("math/samples/src/Ch06/gauss.c", first: 25, last: 56, caption: [partial pivoting, the largest magnitude entry leads the column, back substitution up the staircase])

#listing("math/samples/src/Ch06/gauss.c", first: 138, last: 149, caption: [the disaster and the repair, one function, two row orders, errors 1.22 and 0])

#diagram([row echelon form of Example 2.6, pivots shaded, zeros below the staircase, the last row decides solvability], length: 13pt, {
  let w = 1.5
  let h = 0.9
  let vals = (([1], [-2], [1], [-1], [1], [0]), ([0], [0], [1], [-1], [3], [-2]), ([0], [0], [0], [1], [-2], [1]), ([0], [0], [0], [0], [0], [$a+1$]))
  let piv = ((0, 0), (1, 2), (2, 3))
  let dead = ((1, 0), (2, 0), (2, 1), (3, 0), (3, 1), (3, 2), (3, 3), (3, 4))
  for (i, row) in vals.enumerate() {
    for (j, v) in row.enumerate() {
      let f = if piv.contains((i, j)) { luma(205) } else if dead.contains((i, j)) { luma(245) } else { white }
      cdraw.rect((0.5 + j * w, 5.8 - (i + 1) * h), (0.5 + (j + 1) * w, 5.8 - i * h), fill: f, stroke: luma(140), radius: 0.02)
      cdraw.content((0.5 + (j + 0.5) * w, 5.8 - (i + 0.5) * h), v, size: 6pt)
    }
  }
  cdraw.line((0.35, 5.8), (0.35, 4.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((0.35, 4.9), (3.35, 4.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((3.35, 4.9), (3.35, 4.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((3.35, 4.0), (4.85, 4.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.85, 4.0), (4.85, 3.1), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.85, 3.1), (9.5, 3.1), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((-0.9, 5.35), [pivot], size: 6pt)
  cdraw.line((-0.55, 5.35), (0.45, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.2, 1.9), [$0 = a + 1$: solvable only for $a = -1$], size: 6pt)
})

== lu factorization

Elimination on $bold(A)$ alone, right sides forgotten, produces two
triangular matrices, and that factorization is worth more than any single
solve. Every multiplier $m$ that cleared a column position is an entry of
a lower triangular $bold(L)$ with unit diagonal, the surviving staircase
is the upper triangular $bold(U)$, and the row swaps collect into a
permutation $bold(P)$, so the whole elimination record reads
$bold(P) bold(A) = bold(L) bold(U)$. Solving $bold(A) bold(x) = bold(b)$
becomes two triangular sweeps, forward through $bold(L)$ for
$bold(L) bold(y) = bold(P) bold(b)$, then backward through $bold(U)$ for
$bold(U) bold(x) = bold(y)$, each sweep just a running sum because the
matrices are triangular. Chapter #xref-to("dsa", "linalg") factors the
same way over $G F (p)$, the multipliers are modular inverses there and
exact, here they are divisions and the pivoting rule of the previous
section carries over unchanged.

The dry run: the eq 2.36 fixture again, factored in place with the
multipliers stored exactly where the zeros came out.

+ The permutation is $(2, 1, 0)$, row 3 leads, mml's coefficients
  reordered before the first sweep.
+ $bold(L) = mat(1, 0, 0; 4/9, 1, 0; 2/9, -17/38, 1)$, the three
  multipliers of the pivot ledger below the diagonal.
+ $bold(U) = mat(9, 5, -3; 0, -38/9, -17/3; 0, 0, 119/38)$, the
  staircase, and $bold(P) bold(A) = bold(L) bold(U)$ holds entrywise to
  under $10^(-12)$, check 14 of gauss.c.
+ Forward: $bold(y) = (2, 64/9, 71/19)$. Backward: $bold(x)$ reproduces
  $(291/119, -23/7, 142/119)$, the same answer as the direct solve.

The counting argument is what makes the record worth keeping. The house
flop currency is the fused multiply-subtract, one multiply and one
subtract per unit, the unit lu3 counts. In that currency the
factorization costs $(2n^3 - 3n^2 + n) \/ 6$ units, 5 at $n = 3$,
328350 at $n = 100$, and each additional right side costs $n^2 - n$
units through both sweeps, 9900 at $n = 100$. Trefethen and Bau III,
Numerical Linear Algebra, SIAM 1997, lecture 20, count the operations
singly, which doubles the factorization to $(2n^3 - 3n^2 + n) \/ 3$,
656700 at $n = 100$, the number factor_flops checks. The two-number
play: at $n = 100$ the factorization costs as much as 33 extra right
sides, so the second through thirty-third solves are free riders, and
the ratio widens like $n^3 \/ n^2 = n$: at $n = 1000$ the one
factorization is worth 333 fresh right sides.

#listing("math/samples/src/Ch06/gauss.c", first: 71, last: 104, caption: [lu3, the multipliers stored where the zeros came out, the permutation recorded alongside])

#listing("math/samples/src/Ch06/gauss.c", first: 187, last: 218, caption: [two triangular sweeps and the flop ledger, counted units pinned at 5 and 3])

#diagram([one array holds the record, multipliers below the diagonal, staircase above, two sweeps out], length: 13pt, {
  let cellv = (([9], [5], [-3]), ([$4/9$], [$-38/9$], [$-17/3$]), ([$2/9$], [$-17/38$], [$119/38$]))
  for (i, row) in cellv.enumerate() {
    for (j, v) in row.enumerate() {
      let f = if i > j { luma(205) } else if i == j { luma(235) } else { luma(245) }
      cdraw.rect((0.4 + j * 1.7, 5.4 - (i + 1) * 0.9), (0.4 + (j + 1) * 1.7, 5.4 - i * 0.9), fill: f, stroke: luma(140), radius: 0.02)
      cdraw.content((0.4 + (j + 0.5) * 1.7, 5.4 - (i + 0.5) * 0.9), v, size: 6pt)
    }
  }
  cdraw.content((2.95, 1.9), [multipliers of $bold(L)$ shaded], size: 6pt)
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(6.8, 3.9, 2.6, [$bold(L) bold(y) = bold(P) bold(b)$])
  box(10.1, 3.9, 2.6, [$bold(U) bold(x) = bold(y)$])
  cdraw.line((5.6, 4.4), (6.7, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.5, 4.4), (10.0, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.7, 4.4), [x], size: 6pt)
  cdraw.line((12.9, 4.4), (13.45, 4.4), stroke: luma(100), mark: (end: ">"))
})

== rank and the null space

How many independent directions does a matrix actually carry. mml
section 2.6.2 [printed p 47 / pdf p 53] defines it: "The number of
linearly independent columns of a matrix $A in RR^(m times n)$ equals the
number of linearly independent rows and is called the rank of $A$ and is
denoted by $r k (A)$." The same page collects the working facts:
$r k (bold(A)) = r k (bold(A)^top)$, $bold(A)$ square is invertible exactly
when $r k (bold(A)) = n$, and $bold(A) bold(x) = bold(b)$ is solvable
exactly when $r k (bold(A)) = r k (bold(A) | bold(b))$, rank of the
coefficient matrix and of the augmented one. Elimination computes it:
the rank is the pivot count, because pivot columns are independent and
every non-pivot column is a combination of the pivot columns to its left.

The dry run: mml Example 2.18 [printed pp 47-48 / pdf pp 53-54],

$ bold(A) = mat(1, 2, 1; -2, -3, 1; 3, 5, 0) arrow mat(1, 2, 1; 0, 1, 3; 0, 0, 0) $

+ Two pivots survive, columns 1 and 2, so $r k (bold(A)) = 2$ and the third
  column is a combination of the first two.
+ Reading the combination off the staircase: column 3 equals 3 copies of
  column 2 minus 5 copies of column 1, that is $5 bold(c)_1 - 3 bold(c)_2
  + bold(c)_3 = 0$, a non-trivial dependence, exactly what the
  independence test of chapter #xref-to("math", "vectors") refuses to
  find in an independent set.
+ The witness vector $(5, -3, 1)$ maps to the zero vector, rank.c check
  4, and the same elimination run on $bold(A)^top$ also counts 2, column
  rank equals row rank as the definition promises.

The null space is where those witnesses live. mml section 2.7.3
[printed p 59 / pdf p 65]: "the kernel/null space $ker(Phi)$ is the
general solution to the homogeneous system of linear equations $A x =
0$". For mml Example 2.7's echelon matrix [printed pp 31-32 / pdf
pp 37-38], $mat(1, 3, 0, 0, 3; 0, 0, 1, 0, 9; 0, 0, 0, 1, -4)$ with
pivots in columns 1, 3 and 4, the free columns 2 and 5 each generate one
witness, $(3, -1, 0, 0, 0)$ and $(3, 0, 9, -4, -1)$, both mapped to zero
by rank.c. The dimension budget that ties it together is mml Theorem 2.24
[printed p 60 / pdf p 66], the rank-nullity theorem: "For vector spaces
$V, W$ and a linear mapping $Phi : V -> W$ it holds that $dim(ker(Phi)) +
dim(Im(Phi)) = dim(V)$." For a matrix with $n$ columns the reading is
$n = r k (bold(A)) + dim(ker(bold(A)))$, every column is either a pivot or
a free parameter, never both, never neither. The fixtures pin both
instances: $3 = 2 + 1$ for the 3x3 above, $5 = 3 + 2$ for the 3x5.

#callout("note", "RANK-NULLITY IS A BUDGET, NOT AN IDENTITY",
[The theorem does not compute anything, it audits. Count the pivots
elimination found, subtract from the column count, and you know how many
free parameters any solution set carries before you look at the right
side. A full rank square matrix spends the whole budget on pivots, nullity
0, unique solutions. A rank deficient one owes you witnesses, and every
free column is an IOU the null space pays.])

#listing("math/samples/src/Ch06/rank.c", first: 21, last: 53, caption: [rank as the pivot count, elimination with the same partial pivoting rule on a scratch copy])

#listing("math/samples/src/Ch06/rank.c", first: 79, last: 105, caption: [witness vectors mapped to zero and the two rank-nullity counts, 3 = 2 + 1 and 5 = 3 + 2])

#diagram([pivot columns shaded, free columns light, each free column generates one null space witness], length: 13pt, {
  let vals = (([1], [3], [0], [0], [3]), ([0], [0], [1], [0], [9]), ([0], [0], [0], [1], [-4]))
  let freecols = (1, 4)
  for (i, row) in vals.enumerate() {
    for (j, v) in row.enumerate() {
      let f = if freecols.contains(j) { luma(245) } else { luma(205) }
      cdraw.rect((0.5 + j * 1.5, 5.8 - (i + 1) * 0.9), (0.5 + (j + 1) * 1.5, 5.8 - i * 0.9), fill: f, stroke: luma(140), radius: 0.02)
      cdraw.content((0.5 + (j + 0.5) * 1.5, 5.8 - (i + 0.5) * 0.9), v, size: 6pt)
    }
  }
  let stack(x, vals2) = {
    for (i, v) in vals2.enumerate() {
      cdraw.rect((x, 2.6 - (i + 1) * 0.45), (x + 0.8, 2.6 - i * 0.45), fill: luma(235), stroke: luma(140), radius: 0.02)
      cdraw.content((x + 0.4, 2.6 - (i + 0.5) * 0.45), v, size: 6pt)
    }
  }
  stack(1.7, ([3], [-1], [0], [0], [0]))
  stack(6.9, ([3], [0], [9], [-4], [-1]))
  cdraw.line((2.75, 3.1), (2.1, 2.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.25, 3.1), (7.35, 2.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.5, -0.4), [$r k = 3$, nullity $= 2$, $3 + 2 = 5$ columns], size: 6pt)
})

== the inverse

The inverse is the undo button, when it exists. mml Definition 2.3
[printed p 24 / pdf p 30]: "Consider a square matrix $A in RR^(n times
n)$. Let matrix $B in RR^(n times n)$ have the property that $A B = I_n =
B A$. $B$ is called the inverse of $A$ and denoted by $A^(-1)$." The
follow-up sets the vocabulary and the stakes: "Unfortunately, not every
matrix $A$ possesses an inverse $A^(-1)$. If this inverse does exist,
$A$ is called regular/invertible/nonsingular, otherwise
singular/noninvertible. When the matrix inverse exists, it is unique."
The rank section just gave the test: $r k (bold(A)) = n$ or nothing, and
two chapters ahead the determinant carries the same verdict
(#xref-to("math", "decomp")), Sarrus and Laplace there.

For 2x2 the inverse is a closed formula, mml's remark [printed p 24 /
pdf p 30] multiplying $bold(A)$ by the adjugate $mat(a_(22), -a_(12);
-a_(21), a_(11))$ to obtain $(a_(11) a_(22) - a_(12) a_(21)) bold(I)$,
so

$ bold(A)^(-1) = 1/(a_(11) a_(22) - a_(12) a_(21)) mat(a_(22), -a_(12); -a_(21), a_(11)) $

whenever that scalar is nonzero. The dry run: the chapter fixture
$mat(4, 4; 2, -4)$ has determinant $-16 - 8 = -24$, so the inverse is
$mat(1/6, 1/6; 1/12, -1/6)$, and multiplying back,
$bold(A) bold(A)^(-1)$ and $bold(A)^(-1) bold(A)$ both land on $bold(I)$
to under $10^(-12)$, inverse.c check 7. The inverse also solves
the opening system in one stroke, $bold(A)^(-1) (5, 1) = (1, 1/4)$, the
same crossing point the row picture found, recovered by pure algebra.

For larger matrices the inverse is a batch of eliminations. mml
[printed p 33 / pdf p 39] sets it up as one augmented sweep,
$(bold(A) | bold(I)_n) arrow (bold(I)_n | bold(A)^(-1))$, because
"determining the inverse of a matrix is equivalent to solving systems of
linear equations", one system per unit vector. mml Example 2.9 [printed
p 34 / pdf p 40] runs it on $mat(1, 0, 2, 0; 1, 1, 0, 0; 1, 2, 0, 1; 1,
1, 1, 1)$ and pins the integer answer $mat(-1, 2, -2, 2; 1, -1, 2, -2;
1, -1, 1, -1; -1, 0, -1, 2)$, which inverse.c reproduces by gauss-jordan
with partial pivoting and verifies by the round trip $bold(A)
bold(A)^(-1) = bold(I)_4$. The singular cases refuse on both paths: the
zero determinant $mat(1, 2; 2, 4)$ dies in the adjugate formula, the
4x4 embedding of the rank 2 Example 2.18 fixture dies in elimination when
a column arrives with no pivot left.

#callout("pitfall", "SOLVE, DO NOT INVERT",
[mml's own caveat from the algorithms section [printed p 35 / pdf
p 41]: "for reasons of numerical precision it is generally not
recommended to compute the inverse or pseudo-inverse." Computing
$bold(A)^(-1) bold(b)$ costs the elimination plus a full matrix product,
carries more rounding than the two triangular sweeps of LU, and feeds
the temptation to reuse the inverse as if it were free. The round-trip
checks here exist to characterize the object, the workflow they certify
is the factorization of the previous section.])

#listing("math/samples/src/Ch06/inverse.c", first: 24, last: 35, caption: [inv2, the adjugate shortcut with the determinant as the gatekeeper])

#listing("math/samples/src/Ch06/inverse.c", first: 115, last: 129, caption: [the 4x4 inverse by gauss-jordan, checked against Example 2.9's pinned integers])

#diagram([gauss-jordan moves the identity across, the right block becomes the inverse], length: 13pt, {
  let block(x, y, fill-a, fill-b, left-label, right-label) = {
    for j in range(8) {
      for i in range(4) {
        let f = if j < 4 { fill-a } else { fill-b }
        cdraw.rect((x + j * 0.62, y + (3 - i) * 0.45), (x + (j + 1) * 0.62, y + (4 - i) * 0.45), fill: f, stroke: luma(140), radius: 0.02)
      }
    }
    cdraw.content((x + 4 * 0.62 / 2, y - 0.55), left-label, size: 6pt)
    cdraw.content((x + 4 * 0.62 + 4 * 0.62 / 2, y - 0.55), right-label, size: 6pt)
  }
  block(0.3, 4.2, luma(205), luma(245), [$bold(A)$], [$bold(I)$])
  block(7.6, 4.2, luma(245), luma(205), [$bold(I)$], [$bold(A)^(-1)$])
  cdraw.line((5.5, 5.1), (7.4, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.45, 5.55), [sweeps], size: 6pt)
})

Chapter #xref-to("math", "inner") adds the inner product to these bare
columns and turns matrices into geometry, lengths, angles and the
projections that the rest of the book builds on.

sources: mml-book draft 2024-01-15, Deisenroth, Faisal, Ong, ch 2:
systems of linear equations [printed pp 19-21 / pdf pp 25-27], matrices
[printed pp 22-26 / pdf pp 28-32], solving systems of linear equations
[printed pp 27-35 / pdf pp 33-41] including Example 2.6 and Definition
2.6, rank [printed pp 47-48 / pdf pp 53-54], image and kernel with
Theorem 2.24 [printed pp 58-60 / pdf pp 64-66], read from the anchor
sheet ref/mml/anchors-la.md, numpy-verified there, fetched 2026-09-21.
Flop counts $(2n^3 - 3n^2 + n)\/3$ and $n^2 - n$ are the standard
elimination counts, Trefethen and Bau III, Numerical Linear Algebra,
SIAM 1997, cited by name and edition. Expected values computed by the
playground one-off playground/math-ch06/expected.py, exact Fractions
plus a binary64 simulation of the sample loops. Probed on this machine
the same day. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter
Ch06`, 60 checks in chapter 06 of the math suite.
