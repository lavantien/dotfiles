// ch09, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 25 checks in kdd/samples/src/Ch09/pca.c or a pinned note of
// kdd-contract-s1s2.md (the sample-divisor pin, the never-pin-Q rule,
// the generator's measured handshake residuals). all pinned values are
// witnessed by kdd-contract-s1s2.md + playground/kdd-matrix/gen_s2.py,
// run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= principal component analysis

One sample carries the chapter: `pca.c` builds the sample covariance of
5 centered points, recognizes its eigenvalues by hand, diagonalizes it
with a cyclic 3x3 Jacobi eigensolver, certifies the factorization with
the handshake $A = Q D Q^T$, and projects the points onto the first
component, 25 checks in all. The chapter makes 4 moves: the covariance
and its divisor, the eigenvalues known before the solver runs, the
Jacobi rotations and the handshake that makes them trustworthy, and the
projection invariance that ties scores to eigenvalues. Every behavioral
claim below is one of the 25 checks of chapter 09's sample or a pinned
note of the contract sheet. The prose authority for covariance
eigendecomposition is #xref-to("math", "decomp"); this chapter owns the
runnable solver and its gates. #xref-to("kdd", "wavelet") reduces by
discarding detail instead of rotating axes, and the two close the
transformation half of the book's first arc.

== five points, one covariance

The fixture is 5 points on 3 features, integers, already centered: P =
(3,0,0), (0,3,0), (0,0,3), (-2,-2,-2), (-1,-1,-1). Centering is the
quiet precondition, each coordinate sums to 0, printed as `means (0, 0,
0)` and checked, which is why the scatter matrix, the plain sum of outer
products, is also the covariance up to one division. The divisor is the
sample one, n - 1 = 4, pinned per chapter: #xref-to("kdd", "distance")
divided by n for its Mahalanobis fixture, and this chapter divides by n
- 1, the same per-row convention the sheet has enforced since
#xref-to("kdd", "cleaning").

The dry run: the scatter diagonal is $9 + 0 + 0 + 4 + 1 = 14$ per
coordinate and every off-diagonal is $0 + 0 + 0 + 4 + 1 = 5$, asserted
as "ch09 scatter diagonal 14,14,14" and three single-entry checks.
Dividing by 4, the covariance is diag 3.5, off-diagonal 1.25, all
dyadic, asserted with `==`. The last structural check is the symmetry
precondition, covariance equals its transpose, a D0 fact the solver is
allowed to assume but the sample verifies anyway.

#listing("kdd/samples/src/Ch09/pca.c", first: 138, last: 158,
  caption: [means, scatter as integer outer-product sums, covariance over 4])

#diagram([the 5 points, their scatter, and their covariance over n minus 1], length: 13pt, {
  let pts = ([P1 (3,0,0)], [P2 (0,3,0)], [P3 (0,0,3)], [P4 (-2,-2,-2)], [P5 (-1,-1,-1)])
  for i in range(5) {
    cdraw.rect((1.0, 6.8 - i * 0.78), (4.6, 7.42 - i * 0.78), fill: luma(244), radius: 0.01)
    cdraw.content((2.8, 7.11 - i * 0.78), pts.at(i), size: 6pt)
  }
  cdraw.content((2.8, 7.9), [5 centered points], size: 6pt)
  let grid(x0, vals, cap) = {
    cdraw.content((x0 + 1.95, 7.9), cap, size: 6pt)
    for i in range(3) {
      for j in range(3) {
        cdraw.rect((x0 + j * 1.3, 6.2 - i * 1.05), (x0 + j * 1.3 + 1.2, 7.25 - i * 1.05),
          fill: if i != j {luma(230)} else {luma(246)}, radius: 0.01)
        cdraw.content((x0 + j * 1.3 + 0.6, 6.72 - i * 1.05), vals.at(i).at(j), size: 6.5pt)
      }
    }
  }
  grid(5.8, (([14], [5], [5]), ([5], [14], [5]), ([5], [5], [14])), [scatter, integers])
  grid(10.6, (([3.5], [1.25], [1.25]), ([1.25], [3.5], [1.25]), ([1.25], [1.25], [3.5])), [covariance = scatter/4])
  cdraw.line((10.1, 4.55), (10.5, 4.55), stroke: luma(60), mark: (end: ">"))
  cdraw.content((2.8, 3.3), [off-diagonals tinted: every feature pair covaries 1.25], size: 6pt)
  cdraw.content((2.8, 2.5), [the tinted grid reads 2.25 I + 1.25 J], size: 6pt)
})

== the eigenvalues, before the solver

Nothing about this covariance needs an eigensolver. It reads $2.25 I +
1.25 J$ with J the all-ones matrix: diagonal $2.25 + 1.25 = 3.5$,
off-diagonal 1.25. J carries the vector (1,1,1) to 3 times itself and
annihilates the plane $x + y + z = 0$, so $a I + b J$ has eigenvalue $a +
3b$ on (1,1,1) and a twice on the plane. Here that is $2.25 + 3(1.25) =
6$ and 2.25, 2.25. The full theory behind that one sentence is
#xref-to("math", "decomp"); the sample's job is to witness it in
arithmetic.

The dry run: with $a = 3.5 - 1.25 = 2.25$, printed as `a = 2.25,
lambda1 = 6`, every row of the covariance sums to $3.5 + 1.25 + 1.25 =
6$, printed as `row sums (6, 6, 6)`, which is the eigenvector equation
for (1,1,1) read off row by row. A plane vector, (1,-1,0), multiplies
to (2.25, -2.25, 0), printed as `C*(1,-1,0) = (2.25, -2.25, 0)`,
exactly 2.25 times itself. The second fixture is the stock Jacobi shape
$M = [[3, 2, 2], [2, 3, 2], [2, 2, 3]] = 1 I + 2 J$: row sums all 7,
plane eigenvalue 1, printed as `M row sums all 7, M*(1,-1,0) = (1, -1,
0)`, the same family one integer step over.

#listing("kdd/samples/src/Ch09/pca.c", first: 175, last: 195,
  caption: [a = diag - off-diagonal, lambda1 = a + 3b, row sums witness it])

#listing("kdd/samples/src/Ch09/pca.c", first: 196, last: 206,
  caption: [a plane vector multiplied, eigenvalue 2.25 exact])

#diagram([one axis at 6, a whole plane at 2.25, the same for M at 7 and 1], length: 13pt, {
  let ox = 6.6
  let oy = 3.3
  cdraw.line((ox, oy), (ox + 3.9, oy), stroke: luma(120))
  cdraw.content((ox + 4.15, oy), [f1], size: 6pt)
  cdraw.line((ox, oy), (ox, oy + 2.9), stroke: luma(120))
  cdraw.content((ox + 0.2, oy + 3.05), [f2], size: 6pt)
  cdraw.line((ox, oy), (ox - 3.1, oy - 1.5), stroke: luma(120))
  cdraw.content((ox - 3.5, oy - 1.7), [f3], size: 6pt)
  let plane = ((4.6, 3.6), (6.4, 4.9), (8.6, 3.8), (6.8, 2.5))
  for i in range(4) {
    cdraw.line(plane.at(i), plane.at(calc.rem(i + 1, 4)), stroke: luma(150))
  }
  cdraw.content((6.6, 5.6), [the plane x + y + z = 0], size: 6pt)
  cdraw.content((6.6, 5.0), [eigenvalue 2.25, twice], size: 6pt)
  cdraw.line((ox, oy), (ox + 1.65, oy + 1.85), stroke: luma(60), mark: (end: ">"))
  cdraw.content((ox + 2.3, oy + 2.3), [(1,1,1), lambda = 6], size: 6pt)
  cdraw.content((12.6, 4.4), [M = I + 2 J, same shape], size: 6pt)
  cdraw.content((12.6, 3.7), [axis (1,1,1) at 7], size: 6pt)
  cdraw.content((12.6, 3.0), [plane at 1, twice], size: 6pt)
  cdraw.content((6.0, 1.2), [J maps (1,1,1) to 3(1,1,1) and flattens the plane], size: 6pt)
})

== the jacobi solver, and the handshake

Jacobi's method diagonalizes a symmetric matrix by planar rotations. One
step picks an off-diagonal pair (p, q), computes the angle $theta = 0.5
"atan2"(-2 a_(p q), a_(p p) - a_(q q))$ that cancels it, and applies the
rotation to columns, rows, and the accumulating Q. A sweep is the cyclic
pass over pairs (0,1), (0,2), (1,2), a step fires only when $|a_(p q)| >
10^(-12)$, and the loop stops when a whole sweep fires nothing.

The dry run: on the covariance the printed summary is `jacobi cov:
sweeps 2 rotations 2`, and on M it is `jacobi M: sweeps 2 rotations 2`,
both D3 pins, identical across runs. Both rotations land in the first
sweep, and the second sweep is the empty confirming pass that trips the
stop. The eigenvalues print as `cov eigen sorted (6, 2.25,
2.2499999999999996)` and `M eigen sorted (7.0000000000000018,
1.0000000000000002, 0.99999999999999978)`: a few parts in $10^16$ off,
which is why the eigenvalue pins carry 1e-9 tolerances instead of `==`.
The gate that matters is the handshake, $A = Q D Q^T$ recomputed entry
by entry: `handshake residuals: cov 8.8817841970012523e-16, M
1.3322676295501878e-15`, both asserted under 1e-12. The generator
measured 4.44e-16 and 1.78e-15 on its own run, the same order, and the
assertion is the bound, not the digits.

#listing("kdd/samples/src/Ch09/pca.c", first: 57, last: 79,
  caption: [one rotation: theta from atan2, columns, rows, and Q all turned])

#listing("kdd/samples/src/Ch09/pca.c", first: 96, last: 115,
  caption: [the handshake, Q D Q^T rebuilt and compared entrywise])

#listing("kdd/samples/src/Ch09/pca.c", first: 210, last: 227,
  caption: [both matrices solved, sweeps, rotations, eigenvalues pinned])

#listing("kdd/samples/src/Ch09/pca.c", first: 229, last: 235,
  caption: [the residual gate, under 1e-12 on both matrices])

#diagram([one rotation kills an off-diagonal pair, the sweep repeats until nothing fires], length: 13pt, {
  let before = (([3.5], [1.25], [1.25]), ([1.25], [3.5], [1.25]), ([1.25], [1.25], [3.5]))
  let after = (([6], [0], [0]), ([0], [2.25], [0]), ([0], [0], [2.25]))
  let grid(x0, vals, cap) = {
    cdraw.content((x0 + 1.95, 7.7), cap, size: 6pt)
    for i in range(3) {
      for j in range(3) {
        cdraw.rect((x0 + j * 1.3, 5.9 - i * 1.05), (x0 + j * 1.3 + 1.2, 6.95 - i * 1.05),
          fill: if i != j {luma(230)} else {luma(246)}, radius: 0.01)
        cdraw.content((x0 + j * 1.3 + 0.6, 6.42 - i * 1.05), vals.at(i).at(j), size: 6.5pt)
      }
    }
  }
  grid(1.0, before, [covariance])
  grid(8.6, after, [after the rotations])
  cdraw.line((5.1, 6.4), (8.3, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.7, 6.85), [G(0,1), G(1,2)], size: 6pt)
  cdraw.content((1.0, 2.0), [theta = 0.5 atan2(-2 a_pq, a_pp - a_qq), fire iff abs(a_pq) > 1e-12], size: 6pt)
  cdraw.content((1.0, 1.25), [sweep 1: two rotations fire, sweep 2: none, stop], size: 6pt)
  cdraw.content((12.3, 4.0), [Q D Q^T rebuilds A], size: 6pt)
  cdraw.content((12.3, 3.3), [residual 8.9e-16 < 1e-12], size: 6pt)
  cdraw.content((12.3, 2.6), [the real gate of the solver], size: 6pt)
})

#callout("pitfall", "never pin Q's entries", [
  The eigenvalue 2.25 is repeated, so the two plane columns of Q are
  implementation-defined: any orthonormal basis of the plane
  diagonalizes the matrix equally well, and a different atan2, a
  different pair order, even a different compiler's sine, can rotate
  them into different vectors with the same handshake. The sample pins
  eigenvalues, sweep count, rotation count, and the residual bound,
  never Q itself. Repeated eigenvalues are the rule in mining data, not
  the exception, and this fixture makes the trap visible on purpose.
])

== projection, and the variance that comes back

The first principal component is the eigenvector of the largest
eigenvalue, here the unnormalized loading (1,1,1). Projecting each point
$p$ onto it is one dot product, $s = p dot (1, 1, 1)$, and the chapter's
closing fact is the invariance: the variance of the projections onto a
unit eigenvector equals the eigenvalue.

The dry run: the raw scores print as `PC1 raw scores (3, 3, 3, -6, -3)`,
three axis points at 3, the two negative octant points at -6 and -3.
Divided by the loading's length $sqrt(3)$, the unit scores squared print
as `unit scores squared (3, 3, 3, 12, 3)`, that is $9\/3, 9\/3, 9\/3,
36\/3, 9\/3$. The unit-score variance is $24\/4 = 6$, exactly
$lambda_1$, printed as `var raw 18 (= 3*lambda1 18), var unit 6 (=
lambda1 6)`, and the raw-score variance is 18, three times the
eigenvalue because the loading's squared length is 3. Component scores
inherit their scale from the loading, and pinning both variances shows
the bookkeeping explicitly.

#listing("kdd/samples/src/Ch09/pca.c", first: 266, last: 283,
  caption: [scores on (1,1,1), unit scores squared, sums accumulated])

#listing("kdd/samples/src/Ch09/pca.c", first: 284, last: 295,
  caption: [variance 6 equals lambda1, raw variance 18 equals 3 lambda1])

#diagram([five scores on the first component, variance 6 is the eigenvalue], length: 13pt, {
  let px(s) = { 8.4 + s * 0.78 }
  cdraw.line((2.2, 3.2), (15.6, 3.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((15.9, 3.2), [s], size: 6pt)
  for t in (-6, -3, 0, 3) {
    cdraw.line((px(t * 1.0), 3.02), (px(t * 1.0), 3.38), stroke: luma(60))
    cdraw.content((px(t * 1.0), 2.55), [#t], size: 6pt)
  }
  cdraw.circle((px(3.0), 3.2), radius: 0.11, fill: luma(210), stroke: luma(60))
  cdraw.circle((px(3.0), 3.75), radius: 0.11, fill: luma(210), stroke: luma(60))
  cdraw.circle((px(3.0), 2.65), radius: 0.11, fill: luma(210), stroke: luma(60))
  cdraw.content((px(3.0) + 0.45, 3.75), [P1 P2 P3], size: 6pt)
  cdraw.circle((px(-6.0), 3.2), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(-6.0), 3.75), [P4], size: 6pt)
  cdraw.circle((px(-3.0), 3.2), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(-3.0) - 0.4, 3.75), [P5], size: 6pt)
  cdraw.content((8.4, 5.6), [unit scores squared (3, 3, 3, 12, 3)], size: 6pt)
  cdraw.content((8.4, 4.9), [variance 24/4 = 6 = lambda1], size: 6pt)
  cdraw.content((8.4, 1.7), [raw variance 72/4 = 18 = 3 lambda1, the loading has length^2 3], size: 6pt)
})

One rotation family, one handshake, one invariance. The solver is fifty
lines of c23, its certificate is a matrix rebuild under 1e-12, and the
economics of the whole method sit in the last figure: one axis carries
variance 6 of the total $6 + 2.25 + 2.25 = 10.5$, 57 percent of the
spread in one number per point. #xref-to("kdd", "wavelet") next keeps
two coefficients out of eight for 99 percent of the energy, a different
trade on the same idea.

sources: all 25 pinned values, the sample-divisor pin (n - 1 here, n in
#xref-to("kdd", "distance")), the never-pin-Q rule for repeated
eigenvalues, and the generator-measured handshake residuals witnessed by
kdd-contract-s1s2.md and playground/kdd-matrix/gen_s2.py, run 2026-09-22,
exit 0. The aI + bJ eigenvalue derivation is the prose territory of the
math book's decomposition chapter, #xref-to("math", "decomp"). Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch09`, 25 checks in chapter
09 of the kdd suite.
