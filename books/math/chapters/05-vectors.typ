#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= vectors and vector spaces

Chapter 4 moved single points through coordinates. This chapter works
on the space those points live in, in six moves: vectors as tuples with
an addition and a scaling that obey the vector space axioms, span and
subspace recognized by closure tests, linear independence decided by
counting the pivots elimination leaves behind, basis and dimension as
the unique coordinates theorem, the three workhorse norms with the
triangle inequality and the constants that compare them, and a first
change of basis that shows what coordinates really are. Every
behavioral claim below is one of the 55 checks in the 3 samples of
chapter 05 or a sentence quoted from the mml book draft fetched
2026-09-21. The dsa book runs elimination as a solver over GF(p), this
chapter only borrows its pivot count as a recognition tool, see
#xref-to("dsa", "linalg").

== vectors and linear combinations

A real vector space is a set $V$ where vector addition forms an abelian
group (commutative and associative, with a zero and negatives, the axioms
chapter #xref-to("math", "groups") states as loops) and scaling by reals
distributes over both additions and fixes
$1 x = x$ (mml def 2.9, p 37). The space this book computes in is
$RR^n$, written as column vectors $bold(x) = (x_1, dots, x_n)^T$, with
the convention that $bold(a) bold(b)^T$ is the only outer product and
$bold(a)^T bold(b)$ the inner one (mml ex 2.11 with equation 2.64,
p 38). A linear combination of vectors $bold(x)_1, dots, bold(x)_k$ is
any sum $sum_i lambda_i bold(x)_i$ with real coefficients (mml def 2.11
with equation 2.65, p 40).

Floating point blurs every one of those axioms, so the samples of this
chapter run the algebra on exact rationals: a numerator and denominator
stored as long long, reduced by gcd, denominator positive by
construction. Thirty-five lines of C, and no coefficient ever rounds.

The dry run: $bold(a) = (1,2,0)^T$, $bold(b) = (0,1,2)^T$,
$bold(v) = (2,5,2)^T$.

+ The combination $2 bold(a) + bold(b)$ is coordinatewise:
  $(2 dot 1 + 0, 2 dot 2 + 1, 2 dot 0 + 2) = (2,5,2) = bold(v)$,
  exactly.
+ The membership probe $"det"[bold(a) space bold(b) space bold(v)]$
  expands $bold(b) times bold(v) = (-8,4,-2)^T$ and
  $bold(a) dot (-8,4,-2)^T = 0$: zero, so $bold(v)$ lies in the plane
  of $bold(a)$ and $bold(b)$.
+ The same probe on $bold(w) = (1,0,0)^T$ reads
  $bold(a) dot (0,2,-1)^T = 4$: nonzero, so $bold(w)$ is off the
  plane.

The two numbers of the section: 0 versus 4. One determinant sign
decision separates inside the plane from outside it.

#listing("math/samples/src/Ch05/span.c", first: 23, last: 57, caption: [the exact rational core, every fraction reduced by gcd])

#listing("math/samples/src/Ch05/span.c", first: 115, last: 127, caption: [the combination rebuild and the determinant membership probes])

#diagram([linear combinations of b1=(1,2) and b2=(2,-1) as a lattice through the origin, 2b1+b2 marked], length: 13pt, {
  let dot_(x, y) = cdraw.circle((x, y), radius: 0.05, fill: luma(100), stroke: none)
  cdraw.line((3.0, 3.0), (3.75, 4.5), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.0, 3.0), (4.5, 2.25), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.0, 3.0), (4.5, 6.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.5, 6.0), (6.0, 5.25), stroke: (paint: luma(150), dash: "dashed"))
  dot_(3.0, 3.0)
  dot_(3.75, 4.5)
  dot_(4.5, 6.0)
  dot_(4.5, 2.25)
  dot_(6.0, 1.5)
  dot_(5.25, 3.75)
  dot_(6.75, 3.0)
  cdraw.circle((6.0, 5.25), radius: 0.08, fill: luma(60), stroke: none)
  cdraw.content((2.7, 2.7), [O], size: 6pt)
  cdraw.content((3.0, 4.72), [b1], size: 6pt)
  cdraw.content((4.7, 2.0), [b2], size: 6pt)
  cdraw.content((6.2, 5.65), [2b1+b2=(4,3)], size: 6pt)
})

== span and subspaces

The span of a set is the collection of all its linear combinations, and
it is the smallest subspace containing that set (mml def 2.13, p 44). A
subset $U$ of a vector space is a subspace when $U$ contains the zero
vector and is closed under addition and under scaling (mml def 2.10,
p 39). Closure is the recognition tool: you never enumerate a subspace
of $RR^n$, you check that its defining condition survives both
operations. Three one-sided tests, and failing any one ends the
question.

The dry run: the plane $U$ of $RR^3$ defined by $x + y - z = 0$, and
the rival set $W$ of vectors with third coordinate 1.

+ Zero: $0 + 0 - 0 = 0$, so $bold(0)$ is in $U$.
+ $bold(u) = (1,2,3)^T$ and $bold(s) = (4,-1,3)^T$ each read 0, so
  both are in $U$.
+ Closure: $bold(u) + bold(s) = (5,1,6)^T$ reads $5 + 1 - 6 = 0$,
  $-3 bold(u) = (-3,-6,-9)^T$ reads $-3 - 6 + 9 = 0$, and
  $7 bold(s) = (28,-7,21)^T$ reads $28 - 7 - 21 = 0$.
+ $W$ fails twice: the zero vector has third coordinate 0, and doubling
  $(0,0,1)^T$ gives $(0,0,2)^T$, third coordinate 2, off the set.

Two structural facts frame the test (mml ex 2.12 and the remark on
p 39-40): the solution set of a homogeneous system $bold(A) bold(x) =
bold(0)$ is always a subspace, an inhomogeneous one with a nonzero
right side never is, and every subspace of $RR^n$ arises as a
homogeneous solution set. The sample pins the homogeneous side of the
ledger: the plane $U$ is the solution set of $x + y - z = 0$, it is
$"span"((1,-1,0)^T, (1,0,1)^T)$, and $2 bold(p) + 3 bold(q) =
(5,-2,3)^T$ reads $5 - 2 - 3 = 0$. Scaling a generator moves nothing:
$"span"((1,2)^T) = "span"((2,4)^T)$ because each generator is a
multiple of the other, $(3,6)^T = 3/2 dot (2,4)^T$ sits on the line,
$(3,7)^T$ misses it.

The two numbers of the section: 0 against 2. Every combination probed
inside $U$ reads 0 on the form $x + y - z$, and doubling the seed
$(0,0,1)^T$ of $W$ reads 2 on the third coordinate, the exact step
where closure breaks.

#listing("math/samples/src/Ch05/span.c", first: 141, last: 173, caption: [closure probes on the plane U, the counterexample W, and the homogeneous solution set])

#listing("math/samples/src/Ch05/span.c", first: 175, last: 188, caption: [equal spans, scaling a generator leaves the line in place])

#diagram([the subspace test as a decision flow, the W counterexamples on the fail branches], length: 13pt, {
  let box(x, y, w, t, fill_) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill_, radius: 0.02, stroke: luma(100))
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(3.2, 8.6, 5.2, [candidate set U], luma(235))
  cdraw.line((5.8, 8.6), (5.8, 7.9), stroke: luma(100), mark: (end: ">"))
  box(3.2, 6.9, 5.2, [contains the zero vector?], luma(235))
  cdraw.line((5.8, 6.9), (5.8, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.05, 6.45), [yes], size: 6pt)
  box(3.2, 5.2, 5.2, [closed under addition?], luma(235))
  cdraw.line((5.8, 5.2), (5.8, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.05, 4.75), [yes], size: 6pt)
  box(3.2, 3.5, 5.2, [closed under scaling?], luma(235))
  cdraw.line((5.8, 3.5), (5.8, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.05, 3.05), [yes], size: 6pt)
  box(3.2, 1.8, 5.2, [subspace of R^n], luma(205))
  cdraw.line((8.4, 7.4), (10.5, 7.4), stroke: luma(140), mark: (end: ">"))
  cdraw.content((10.7, 7.25), [no: 0 not in W], size: 6pt)
  cdraw.line((8.4, 5.7), (10.5, 5.7), stroke: luma(140), mark: (end: ">"))
  cdraw.content((10.7, 5.55), [no: doubling escapes W], size: 6pt)
})

== linear independence and elimination

Vectors $bold(x)_1, dots, bold(x)_k$ are linearly independent when the
only combination $sum_i lambda_i bold(x)_i = bold(0)$ is the one with
every coefficient zero; otherwise the set is dependent (mml def 2.12,
p 40). For a fixed finite set the question is decidable by elimination:
put the vectors side by side as columns, reduce to echelon form, and
count pivots. The set is independent exactly when every column carries
a pivot, the pivot columns are independent on their own, and every
non-pivot column is a combination of the pivot columns before it (mml
pp 41-42). Three shortcuts come from the same pages: a zero vector in
the set forces dependence, a duplicate forces dependence, and one
vector being a combination of the others is equivalent to the whole set
being dependent.

The counting bound turns the test into a corollary: m linear
combinations of k vectors are linearly dependent whenever m > k (mml
p 43). Take k = n and the standard basis of $RR^n$, which reaches every
vector: n + 1 vectors in $RR^n$ always lose, because elimination on n
rows cannot leave more than n pivots.

The dry run: three fixed sets plus the mml example 2.14 (p 42) with
$x_1 = (1,2,-3,4)^T$, $x_2 = (1,1,0,2)^T$, $x_3 = (-1,-2,1,1)^T$.

+ Example 2.14: elimination on the 4 by 3 matrix leaves a pivot in
  every column, rank 3 of 3, independent. The echelon form (2.69) is
  the identity block.
+ The pair $(1,2)^T, (2,4)^T$: the second column is twice the first,
  one pivot, and $2 bold(a) - bold(b) = bold(0)$ exhibits the
  dependency outright.
+ Three vectors in $RR^2$: rank 2 of 3, and
  $bold(e)_1 + bold(e)_2 - (1,1)^T = bold(0)$. Four vectors in
  $RR^3$: rank 3 of 4, and $2 bold(e)_1 - 3 bold(e)_2 + 5 bold(e)_3 -
  (2,-3,5)^T = bold(0)$.
+ A zero vector or a duplicate in a 2 column set each collapse the
  rank to 1.

The two numbers of the section: 3 pivots in 3 columns against 2 pivots
in 3 columns, independent against dependent, decided by one integer.

#listing("math/samples/src/Ch05/independence.c", first: 125, last: 155, caption: [fraction gaussian elimination that returns the pivot count])

#listing("math/samples/src/Ch05/independence.c", first: 166, last: 180, caption: [the fixtures, mml examples 2.14, 2.15 and the set A as fixed columns])

#listing("math/samples/src/Ch05/independence.c", first: 182, last: 226, caption: [fixed-set verdicts, duplicates, the zero vector, and n+1 vectors losing in R^n])

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*set*], [*ambient*], [*columns*], [*pivots*], [*verdict*]),
  [ex 2.14], [$RR^4$], [3], [3], [independent],
  [$(1,2), (2,4)$], [$RR^2$], [2], [1], [dependent, $2a - b = 0$],
  [$bold(0), (3,4)$], [$RR^2$], [2], [1], [dependent, zero column],
  [$e_1, e_2, (1,1)$], [$RR^2$], [3], [2], [dependent, 3 in 2],
  [$e_1, e_2, e_3, (2,-3,5)$], [$RR^3$], [4], [3], [dependent, 4 in 3],
  [set A (2.80)], [$RR^4$], [3], [3], [independent, short],
)

#callout("pitfall", "NEVER DECIDE INDEPENDENCE IN DOUBLES", [Elimination in floating point turns exact zeros into residues like 1e-17, and the pivot search then answers a question you did not ask. The samples run the fractions exactly. When doubles are unavoidable, as in the physics chapters, compare each residual against a stated epsilon the way #xref-to("math", "error") teaches, and pin the epsilon in a comment.])

#diagram([pivot patterns, every column carrying a pivot against one column left over], length: 13pt, {
  let cell(x, y, t, piv) = {
    cdraw.rect((x, y), (x + 1.0, y + 1.0), fill: if piv { luma(205) } else { luma(245) }, stroke: luma(140))
    cdraw.content((x + 0.5, y + 0.5), t, size: 6pt)
  }
  cdraw.content((3.0, 8.85), [echelon of ex 2.14], size: 6.5pt)
  for r in range(3) {
    for c in range(3) {
      let piv = r == c
      cell(1.5 + c, 5.5 + r, if piv { [1] } else { [0] }, piv)
    }
  }
  cdraw.content((3.0, 4.9), [3 pivots in 3 columns: independent], size: 6pt)
  cdraw.content((12.0, 7.55), [3 vectors in R^2], size: 6.5pt)
  for r in range(2) {
    for c in range(3) {
      let piv = c < 2 and r == c
      cell(10.5 + c, 5.5 + r, if piv { [1] } else { [0] }, piv)
    }
  }
  cdraw.content((12.0, 4.9), [2 pivots in 3 columns: dependent], size: 6pt)
})

== basis and dimension

A basis of a vector space is a generating set that is also linearly
independent (mml def 2.14, p 44): every vector is a combination of the
basis, and no basis vector is a combination of the others. Coordinates
in a basis are then unique (equation 2.77, p 45): if two coefficient
vectors both rebuilt $bold(x)$, their difference would be a nonzero
combination giving zero, which independence forbids. Every vector space
has a basis, all bases of one space have the same size, and that size
is the dimension (mml pp 45-46). For subspaces, $"dim" U <= "dim" V$
with equality exactly when $U = V$. To build a basis of a span, run
elimination and keep the pivot columns; mml example 2.17 (pp 46-47)
does exactly that and keeps ${x_1, x_2, x_4}$.

The dry run: the set A of mml example 2.16, equation (2.80), p 45,
with $a_1 = (1,2,3,4)^T$, $a_2 = (2,-1,0,2)^T$, $a_3 = (1,1,0,-4)^T$
in $RR^4$.

+ Elimination: rank 3, the set is independent.
+ Reachability of $bold(e)_1 = (1,0,0,0)^T$: the leading 3 by 3 block
  of $[a_1 space a_2 space a_3]$ has determinant 9, and Cramer on it
  returns $lambda_1 = 0$, $lambda_2 = 1/3$, $lambda_3 = 1/3$.
+ The fourth equation reads $4 dot 0 + 2 dot 1/3 - 4 dot 1/3 = -2/3$,
  so $bold(e)_1$ is not in the span. Independent but short: a basis of
  $RR^4$ needs exactly 4 vectors.

The companion example 2.15 (mml pp 43-44) shows the other direction:
from four vectors whose first three carry rank 3, back substitution
reads the fourth off the others as
$x_4 = -7 x_1 - 15 x_2 - 18 x_3$, and ${x_1, x_2, x_3}$ is then a
basis of the span. The sample verifies that relation coordinate by
coordinate, all four rows reading 0.

The two numbers of the section: 3 pivots against the residue -2/3. The
rank says the set is independent, the residue says it stops short of
generating, and the gap between them is exactly one basis vector.

#listing("math/samples/src/Ch05/independence.c", first: 228, last: 240, caption: [ex 2.15, the fourth vector hangs off the first three])

#listing("math/samples/src/Ch05/independence.c", first: 242, last: 268, caption: [set A, cramer coordinates 0, 1/3, 1/3 and the fourth-row residue -2/3])

#callout("note", "DIMENSION COUNTS DIRECTIONS, NOT ELEMENTS", [The line $"span"((0,1)^T)$ has infinitely many vectors and dimension 1, and $RR^4$ has infinitely many vectors and dimension 4 (mml pp 45-46). A basis of $RR^n$ always has exactly n vectors: fewer independent ones do not generate, and any n + 1 lose by the counting bound of the previous section.])

#diagram([spanning sets against independent sets, bases in the overlap], length: 13pt, {
  cdraw.rect((1.5, 3.5), (9.5, 7.5), fill: luma(245), stroke: luma(100), radius: 0.5)
  cdraw.rect((6.0, 3.5), (14.0, 7.5), fill: luma(245), stroke: luma(100), radius: 0.5)
  cdraw.rect((6.0, 3.5), (9.5, 7.5), fill: luma(205), stroke: none, radius: 0.02)
  cdraw.content((3.9, 6.9), [spanning sets], size: 6.5pt)
  cdraw.content((11.8, 6.9), [independent sets], size: 6.5pt)
  cdraw.content((7.75, 6.9), [bases], size: 6.5pt)
  cdraw.content((7.75, 5.6), [standard basis], size: 6pt)
  cdraw.content((7.75, 5.1), [of R^n], size: 6pt)
  cdraw.content((3.9, 5.35), [5 vectors spanning R^4:], size: 6pt)
  cdraw.content((3.9, 4.85), [dependent], size: 6pt)
  cdraw.content((11.8, 5.35), [set A: rank 3 in R^4], size: 6pt)
  cdraw.content((11.8, 4.85), [short of spanning], size: 6pt)
})

== norms, unit vectors, and equivalence

A norm on $RR^n$ is a function with absolute homogeneity
$norm(lambda bold(v)) = |lambda| norm(bold(v))$, the triangle
inequality $norm(bold(u) + bold(v)) <= norm(bold(u)) + norm(bold(v))$,
and positive definiteness, $norm(bold(v)) = 0$ only at
$bold(v) = bold(0)$ (mml def 3.1, p 71). Three workhorses carry all
the numerics of this book. The manhattan norm
$norm(bold(v))_1 = sum_i |v_i|$ (mml example 3.1 with equation 3.3,
p 71), the euclidean norm
$norm(bold(v))_2 = sqrt(bold(v)^T bold(v))$ (mml example 3.2 with
equation 3.4, p 72), and the max norm
$norm(bold(v))_oo = max_i |v_i|$. The first two are the draft's, with
its remark to use the euclidean norm by default (p 72). The max norm
appears nowhere in the draft: its three axioms are defined here and
verified by the sample.

The dry run on the fixed vector $bold(v) = (3,-4,12)^T$.

+ Values: $19 = 3 + 4 + 12$, $13 = sqrt(169)$ from $9 + 16 + 144$,
  $12 = max(3,4,12)$. The chain $12 < 13 < 19$ orders all three norms
  on one vector.
+ Homogeneity: $7 bold(v)$ has $norm_1 = 133 = 7 dot 19$ and
  $norm_oo = 84 = 7 dot 12$, and $-2 bold(v)$ has
  $norm_2 = sqrt(676) = 26 = 2 dot 13$.
+ Unit vectors: $norm_2(bold(v)) = 13$ is exact because 169 is a
  perfect square under the root, and the three squares of
  $bold(v) \/ 13$ then round to a sum of exactly 1, so the scaled
  vector sits on the l2 shell. $bold(v) \/ 19$ has $norm_1$ exactly 1.
  The l1 sum of $bold(v) \/ 13$ lands one ulp above the rational
  $19/13$: 1.4615384615384617 against 1.4615384615384615.
+ Triangle equality: with $bold(p) = (1,2,2)^T$ and $bold(q) =
  2 bold(p)$, all three norms hit equality, $9 = 3 + 6$,
  $15 = 5 + 10$, $6 = 2 + 4$. With $bold(r) = (2,0,-1)^T$, which is
  not a nonnegative multiple of $bold(p)$, all three are strict:
  $sqrt(14) = 3.7416573867739413 < 3 + sqrt(5) = 5.23606797749979$,
  $6 < 8$, $3 < 4$.

Equality in the triangle inequality holds when one side is a
nonnegative multiple of the other. For the euclidean norm that is
equality in Cauchy-Schwarz. For the manhattan norm the exact condition
is derived, not cited: per coordinate, $|a + b| = |a| + |b|$ holds
exactly when $a b >= 0$, so equality means no coordinatewise sign
cancellation, and a nonnegative multiple guarantees it. The sample
shows the guarantee and one strict counterexample.

Norm equivalence: on a fixed $RR^n$ any two norms compare through
constants, so convergence or boundedness questions get the same
answers in every one of them. On $RR^3$ the chain is
$norm_oo <= norm_2 <= norm_1$ termwise, $norm_2 <= sqrt(3) norm_oo$
and $norm_1 <= sqrt(3) norm_2$, the sum bound
$sum |v_i| <= sqrt(n) norm_2$ on $|bold(v)|$ against the all-ones
vector that chapter #xref-to("math", "inner") names Cauchy-Schwarz,
and $norm_1 <= 3 norm_oo$ termwise. The
draft does not state equivalence. On the fixed vector: 19 sits under
$sqrt(3) dot 13 = 22.516660498395403$, 13 under
$sqrt(3) dot 12 = 20.784609690826528$, and 19 under 36.

#listing("math/samples/src/Ch05/norms.c", first: 37, last: 57, caption: [the three norms as three straight functions over fabs and sqrt])

#listing("math/samples/src/Ch05/norms.c", first: 59, last: 97, caption: [values, homogeneity, the equivalence bounds, and unit vectors])

#listing("math/samples/src/Ch05/norms.c", first: 104, last: 131, caption: [triangle equality, the strict case, and positive definiteness])

#callout("verify", "THE EQUIVALENCE CONSTANTS ON ONE VECTOR", [Every bound in the chain is checked against the fixed $bold(v) = (3,-4,12)^T$ in norms.c: the lower chain 12 <= 13 <= 19 exactly, and the three upper bounds with their slack, 19 <= 22.516660498395403, 13 <= 20.784609690826528, 19 <= 36. The constants $sqrt(3)$ and 3 depend on the dimension, not on the vector.])

#callout("pitfall", "NORMALIZE WITH THE MATCHING NORM", [Dividing by one norm lands on that norm's unit shell only. $bold(v) \/ 13$ has $norm_2 = 1$ but $norm_1 = 19/13$ still, one ulp from the rational value in doubles. A distance test written with $norm_2$ against a threshold tuned for $norm_1$ is wrong by up to the equivalence constant, here a factor of $sqrt(3)$.])

#diagram([unit balls of the three norms, diamond, circle, square], length: 13pt, {
  let cx = 8.0
  let cy = 5.0
  let r = 1.7
  cdraw.line((5.5, cy), (10.5, cy), stroke: luma(150))
  cdraw.line((cx, 2.9), (cx, 7.0), stroke: luma(150))
  let ring = (
    (1.0, 0.0), (0.966, 0.259), (0.866, 0.5), (0.707, 0.707),
    (0.5, 0.866), (0.259, 0.966), (0.0, 1.0), (-0.259, 0.966),
    (-0.5, 0.866), (-0.707, 0.707), (-0.866, 0.5), (-0.966, 0.259),
    (-1.0, 0.0), (-0.966, -0.259), (-0.866, -0.5), (-0.707, -0.707),
    (-0.5, -0.866), (-0.259, -0.966), (0.0, -1.0), (0.259, -0.966),
    (0.5, -0.866), (0.707, -0.707), (0.866, -0.5), (0.966, -0.259),
  )
  let C = ring.map(p => (cx + r * p.at(0), cy + r * p.at(1)))
  for i in range(C.len() - 1) {
    cdraw.line(C.at(i), C.at(i + 1), stroke: luma(60))
  }
  cdraw.line(C.at(C.len() - 1), C.at(0), stroke: luma(60))
  cdraw.line((9.7, 5.0), (8.0, 6.7), stroke: luma(100))
  cdraw.line((8.0, 6.7), (6.3, 5.0), stroke: luma(100))
  cdraw.line((6.3, 5.0), (8.0, 3.3), stroke: luma(100))
  cdraw.line((8.0, 3.3), (9.7, 5.0), stroke: luma(100))
  cdraw.rect((6.3, 3.3), (9.7, 6.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((8.0, 7.2), [l2 circle], size: 6pt)
  cdraw.content((5.6, 6.4), [l1 diamond], size: 6pt)
  cdraw.content((9.9, 6.85), [linf square], size: 6pt)
  cdraw.content((8.0, 4.6), [unit ball = one shell per norm], size: 6pt)
})

== what a basis buys a programmer

An ordered basis $B = (bold(b)_1, dots, bold(b)_n)$ assigns to every
vector $bold(x)$ its unique coordinates $lambda_1, dots, lambda_n$
with $bold(x) = sum_i lambda_i bold(b)_i$ (mml def 2.18 with equations
2.89-2.91, p 50). Mml's figure 2.8 draws the punchline: the same
vector $x = [2,2]^T$ reads $[1.09, 0.72]^T$ in a tilted basis. The
vector does not move, the name does.

The purchase is a lossless compression. Fix a basis and every vector
in an n dimensional space is exactly n numbers, and every linear map
is exactly n^2 numbers: the transformation matrix whose columns are
the images of the basis vectors (mml def 2.19, p 51). Games store
positions in the standard basis and physics in whatever frame the
level designer tilted, and both are the same data wearing different
names.

The dry run: mml example 2.20 (p 51), $bold(x) = (2,3)^T$ in the basis
$bold(b)_1 = (1,-1)^T$, $bold(b)_2 = (1,1)^T$.

+ Solve $alpha bold(b)_1 + beta bold(b)_2 = bold(x)$: the two
  equations $alpha + beta = 2$ and $-alpha + beta = 3$ add to
  $2 beta = 5$, so $beta = 5/2$ and $alpha = -1/2$.
+ Rebuild exactly:
  $-1/2 (1,-1)^T + 5/2 (1,1)^T = (-1/2 + 5/2, 1/2 + 5/2) = (2,3)^T$.
+ Packaged as matrices: the basis matrix $bold(B) = mat(1, 1, -1, 1)$
  with columns $bold(b)_1, bold(b)_2$ carries tilted coordinates to
  standard ones, $bold(B) (-1/2, 5/2)^T = (2,3)^T$, and its inverse
  $1/2 mat(1, -1, 1, 1)$ is the solve as a table, reading
  $(-1/2, 5/2)^T$ back off $(2,3)^T$. Mml example 2.21 (pp 51-52)
  builds such a matrix column by column from the images of the basis
  vectors, and the text uses it to map coordinates in one ordered
  basis to coordinates in another.

The two numbers of the section: the same vector is named $(2,3)$ in
the standard basis and $(-1/2, 5/2)$ in the tilted one, and both names
rebuild it exactly.

#listing("math/samples/src/Ch05/span.c", first: 190, last: 198, caption: [change of basis, mml ex 2.20 in exact fractions])

#diagram([the same vector read in two bases, standard coefficients 2 and 3, tilted coefficients -1/2 and 5/2], length: 13pt, {
  cdraw.line((0.9, 3.6), (11.4, 3.6), stroke: luma(150), mark: (end: ">"))
  cdraw.line((4.0, 0.6), (4.0, 7.4), stroke: luma(150), mark: (end: ">"))
  cdraw.content((10.9, 3.2), [e1], size: 6pt)
  cdraw.content((3.55, 7.55), [e2], size: 6pt)
  cdraw.line((4.0, 3.6), (6.4, 6.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((4.0, 3.6), (6.4, 1.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.6, 6.2), [b2], size: 6pt)
  cdraw.content((6.6, 1.05), [b1], size: 6pt)
  cdraw.line((4.0, 3.6), (5.8, 3.6), stroke: (paint: luma(150), dash: "dotted"))
  cdraw.line((5.8, 3.6), (5.8, 6.3), stroke: (paint: luma(150), dash: "dotted"))
  cdraw.content((4.9, 3.25), [2], size: 6pt)
  cdraw.content((6.05, 5.0), [3], size: 6pt)
  cdraw.line((4.0, 3.6), (6.25, 5.85), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((6.25, 5.85), (5.8, 6.3), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((4.45, 5.2), [5/2], size: 6pt)
  cdraw.content((6.9, 6.55), [-1/2], size: 6pt)
  cdraw.circle((5.8, 6.3), radius: 0.07, fill: luma(60), stroke: none)
  cdraw.content((5.05, 6.75), [x=(2,3)], size: 6pt)
})

The transformation matrix is the subject of the next chapter,
#xref-to("math", "matrices"), where this 2 by 2 preview becomes the
general theory of linear maps.

sources: mml-book draft 2024-01-15, ch 2.4-2.5 pp 37-47 (vector
spaces, subspaces, linear independence, elimination test, basis and
dimension), ch 2 pp 50-52 (coordinates in a basis, transformation
matrix, examples 2.20 and 2.21), ch 3.1-3.2 pp 71-72 (norm definition,
manhattan and euclidean norms, dot product, the default-euclidean
remark), cross-checked 2026-09-21 against the verbatim extracted text
of pdf pp 43-58 and 77-80 of ref/mml-book.pdf, the page renders
themselves being unavailable on this machine. The max norm
and the norm equivalence constants are not in the draft, they are
defined and derived inline and pinned by the samples. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/math/samples/src -Chapter Ch05`, 55 checks in chapter 05 of the
math suite, 19 in span, 17 in independence, 19 in norms, zero
skipped, format and asan clean.
