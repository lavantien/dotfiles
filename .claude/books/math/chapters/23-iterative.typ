#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= iterative methods and conditioning

Chapter #xref-to("math", "matrices") solved linear systems by elimination,
chapter #xref-to("math", "decomp") factored matrices into eigenvalues and
singular values, and chapter #xref-to("math", "error") defined the condition
number that prices the whole business. This chapter is the iterative
counterpart of all three: methods that never factor anything, just multiply
by the matrix and converge. Six moves: the operation-count argument for
why iteration beats elimination on sparse systems, jacobi and gauss-seidel
as splittings $bold(A) = bold(M) - bold(N)$, the spectral radius criterion
that decides convergence before you run it, power iteration with deflation
and its equal-magnitude failure mode, condition numbers measured with the
chapter's own iterations plus the perturbation bound observed flipping a
solution end to end, and iterative refinement pinned exactly as it behaves
in doubles. Every behavioral claim below is one of the 68 checks in the 4
samples of chapter 23, a theorem attributed by name to a canonical text, or
the fixed-point iteration form of mml-book draft 2024-01-15 ch 2.3.4 eq
2.60, $x^((k+1)) = bold(C) x^((k)) + d$, cross verified against the pdf
2026-09-22. Chapter #xref-to("math", "roots") already ran fixed-point
iteration in one variable; the dsa book's
#xref-to("dsa", "numerical") chapter drives such solvers as contest
tooling, while this chapter builds the linear algebra underneath.

== why iterate

Chapter #xref-to("math", "matrices") priced gaussian elimination at about
$(2\/3) n^3$ flops and chapter #xref-to("math", "decomp") needed the same
order for the eigenvalue machinery. That price buys a factorization, and a
factorization is dense knowledge: it answers for every right-hand side at
once. When the matrix is sparse and you need one answer, the matrix-vector
product $bold(A) bold(x)$ costs one flop pair per stored nonzero, and a
method that only ever multiplies can win by four orders of magnitude.

The fixture is the 5-point laplacian on an $m times m$ interior grid, the
discretized $-u''$ of chapter #xref-to("math", "quadrature") in two
dimensions: $n = m^2$ unknowns, diagonal 4, off-diagonal -1 for the four
grid neighbors. At $m = 20$, $n = 400$: the stencil form of the product
computes $4 x_i$ then subtracts each present neighbor, 1920 counted flops,
and stores 1920 nonzeros. Assemble the same matrix densely and run LU with
partial pivoting: 42586600 counted flops and 15638 stored nonzeros in the
factors. The two-number play: one elimination equals 22180 matrix-vector
sweeps, and elimination stores 8.14 times what the stencil stores, because
the zeros between the stencil diagonals fill in as elimination proceeds.
The band of fill is what sparse direct solvers fight and what iterative
ones refuse to create.

The dry run: the $m = 3$ grid by hand. With $bold(x) = "ones"$ every node
keeps 4 minus its neighbor count, so the corners (2 neighbors) hold 2, the
edges (3 neighbors) hold 1, the center holds 0, and the product reads
$(2, 1, 2, 1, 0, 1, 2, 1, 2)$, the pinned first check of the sample. At
$m = 20$ the same sweep on $bold(b) = bold(A) "ones"$ leaves exactly 76
nonzeros, 4 corners at 2 and 72 edge nodes at 1, and the counted flop
total is $n + 2 dot 2 m (m - 1) = 1920$.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*quantity*], [*stencil*], [*dense LU*], [*ratio*]),
  [flops], [1920], [42586600], [22180.5],
  [stored nonzeros], [1920], [15638], [8.14],
)

#listing("math/samples/src/Ch23/stencil.c", first: 56, last: 84, caption: [stencil.c, the counted 5-point sweep, one multiply on the diagonal and one subtract per present neighbor])

#listing("math/samples/src/Ch23/stencil.c", first: 187, last: 223, caption: [stencil.c, the measurements: zero swaps, the 42586600 flop count, the 15638-entry fill, and the solve that returns ones])

#diagram([the sparsity of the stencil against the fill band of its LU factors], length: 13pt, {
  let sq(x, y, w) = cdraw.rect((x, y), (x + w, y + w), fill: none, stroke: luma(60), radius: 0.02)
  sq(1.2, 2.6, 4.4)
  sq(11.4, 2.6, 4.4)
  // five stencil diagonals, slope 2, each clipped to the square edges
  for x0 in (2.3, 2.85, 3.4, 3.95, 4.5) {
    let xe = calc.min(x0 + 2.2, 5.6)
    let ye = 2.6 + 2.0 * (xe - x0)
    cdraw.line((x0, 2.6), (xe, ye), stroke: luma(100))
  }
  // the LU band, filled
  cdraw.rect((12.7, 2.6), (15.7, 7.0), fill: luma(235), stroke: none)
  cdraw.rect((13.4, 2.6), (15.0, 7.0), fill: luma(205), stroke: none)
  for x0 in (12.5, 13.05, 13.6, 14.15, 14.7) {
    let xe = calc.min(x0 + 2.2, 15.6)
    let ye = 2.6 + 2.0 * (xe - x0)
    cdraw.line((x0, 2.6), (xe, ye), stroke: luma(140))
  }
  cdraw.content((3.4, 8.0), [A: 5 diagonals, 1920 stored], size: 6pt)
  cdraw.content((3.4, 1.8), [1920 flops per sweep], size: 6pt)
  cdraw.content((13.6, 8.0), [L + U: fill band, 15638 stored], size: 6pt)
  cdraw.content((13.6, 1.8), [42586600 flops, once], size: 6pt)
  cdraw.content((8.0, 4.8), [22180 sweeps], size: 6pt)
  cdraw.line((9.6, 5.0), (11.0, 5.0), stroke: luma(100), mark: (end: ">"))
})

#callout("verify", "COUNTED VERSUS TEXTBOOK", [The sample's counter counts the arithmetic this code performs, one op per multiply, add, subtract, or division on entries. The textbook $(2\/3) n^3 = 42666667$ sits 0.2 percent above the count 42586600 because the leading term ignores the lower-order $n^2$ corrections the counter does see. Both numbers are checks, not estimates.])

== splittings: jacobi and gauss-seidel

Write $bold(A) = bold(M) - bold(N)$ with $bold(M)$ easy to invert, start
from any $x_0$, and iterate $bold(M) x^((k+1)) = bold(N) x^((k)) + b$.
That is the mml-book eq 2.60 form $x^((k+1)) = bold(C) x^((k)) + d$ with
$bold(C) = bold(M)^(-1) bold(N)$, the iteration matrix. Jacobi takes
$bold(M) = bold(D)$, the diagonal: every component of the new sweep is one
row of arithmetic on values that are all old. Gauss-seidel takes $bold(M) =
bold(D) + bold(L)$, lower triangle included: component $i$ is updated from
components $1, ..., i - 1$ that are already new. Same flops per sweep,
different information flow.

The model fixture is the 1d laplacian $"tridiag"(-1, 2, -1)$ with $n = 5$
and $b = (1, 0, 0, 0, 1)$, chosen so the solution is $x^* = "ones"$: the
first and last rows of $bold(A) "ones"$ give 1, the interior rows give 0.
The jacobi sweep is $x_i^((k+1)) = (b_i + x_(i-1)^((k)) + x_(i+1)^((k))) \/ 2$.

The dry run: from $x_0 = 0$, the first sweep copies $b\/2$, giving
$(0.5, 0, 0, 0, 0.5)$; the second pulls neighbors, giving
$(0.5, 0.25, 0, 0.25, 0.5)$; the third gives
$(0.625, 0.25, 0.25, 0.25, 0.625)$; six sweeps reach
$(0.71875, 0.578125, 0.4375, 0.578125, 0.71875)$, every entry dyadic, every
step exact in doubles. Gauss-seidel's first sweep feeds on its own output,
$(0.5, 0.25, 0.125, 0.0625, 0.53125)$, a different ladder from the same
arithmetic. The jacobi error column stalls in pairs, 1, 1, 0.75, 0.75,
0.5625, 0.5625, a plateau pattern the next section explains, while the
gauss-seidel column declines every sweep. Jacobi needs 99 sweeps to push
$||x^* - x^((k))||_inf$ under $10^(-6)$, gauss-seidel needs 50. The
two-sweep factor of jacobi and the one-sweep factor of gauss-seidel are
the same number, 0.75, pinned both ways: for this model young's identity
$rho(bold(M)_("GS")) = rho(bold(M)_J)^2$ holds exactly (the matrix is
consistently ordered, Young 1971 by name), so one gauss-seidel sweep buys
what two jacobi sweeps buy.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*sweep*], [*jacobi $x^((k))$*], [*gauss-seidel $x^((k))$*]),
  [1], [(0.5, 0, 0, 0, 0.5)], [(0.5, 0.25, 0.125, 0.0625, 0.53125)],
  [2], [(0.5, 0.25, 0, 0.25, 0.5)], [(0.625, 0.375, 0.21875, 0.375, 0.6875)],
  [3], [(0.625, 0.25, 0.25, 0.25, 0.625)], [(0.6875, 0.453125, 0.4140625, 0.55078125, 0.775390625)],
  [6], [(0.71875, 0.578125, 0.4375, 0.578125, 0.71875)], [(0.8364..., 0.7534..., 0.7528..., 0.8145..., 0.9072...)],
)

#listing("math/samples/src/Ch23/jacobi.c", first: 48, last: 72, caption: [jacobi.c, the two model sweeps, one reading only old values, one updating in place])

#listing("math/samples/src/Ch23/jacobi.c", first: 187, last: 231, caption: [jacobi.c, the pinned dyadic ladders for both splittings and the two sweep counts, 99 against 50])

Divergence is one fixture away. The 2 by 2 system $mat(1, 2; 3, 1) bold(x) =
(1, 1)$ has solution $(0.2, 0.4)$, but row 0 carries off-diagonal mass 2
against diagonal 1, and both splittings blow up: jacobi's iterates are the
integers $(1, 1), (-1, -2), (5, 4), (-7, -14), (29, 22), (-43, -86),
(173, 130)$, gaining the factor 6 per two sweeps because its iteration
matrix has eigenvalues $plus.minus sqrt(6)$, while gauss-seidel's iterates
$(1, -2), (5, -14), (29, -86), (173, -518)$ gain exactly 6 every sweep on
its single eigenvalue 6. Nothing oscillates by accident here: the
eigenvalues predict both rates, and both ladders are pinned checks.

#listing("math/samples/src/Ch23/jacobi.c", first: 281, last: 313, caption: [jacobi.c, the divergence fixture, dominance violated, jacobi at factor 6 per two sweeps and gauss-seidel at 6 per sweep])

#diagram([digits of accuracy gained per sweep, gauss-seidel climbing at twice jacobi's slope], length: 13pt, {
  let px(k, d) = (1.2 + (k / 60.0) * 9.0, 1.6 + (d / 7.4) * 5.6)
  let jac = ((10, 0.50), (20, 1.12), (40, 2.37), (60, 3.62))
  let gsw = ((5, 0.48), (10, 1.11), (20, 2.36), (40, 4.85), (60, 7.35))
  for i in range(jac.len() - 1) {
    cdraw.line(px(jac.at(i).at(0), jac.at(i).at(1)), px(jac.at(i + 1).at(0), jac.at(i + 1).at(1)), stroke: (paint: luma(140), dash: "dashed"))
  }
  for i in range(gsw.len() - 1) {
    cdraw.line(px(gsw.at(i).at(0), gsw.at(i).at(1)), px(gsw.at(i + 1).at(0), gsw.at(i + 1).at(1)), stroke: luma(60))
  }
  for t in jac {
    cdraw.circle(px(t.at(0), t.at(1)), radius: 0.1, fill: none, stroke: luma(60))
  }
  for t in gsw {
    cdraw.circle(px(t.at(0), t.at(1)), radius: 0.1, fill: luma(30), stroke: none)
  }
  cdraw.line((1.2, 1.6), (10.4, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((1.2, 1.6), (1.2, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.6, 0.9), [sweeps, $-"log"_10 ||e||_inf$ on the vertical], size: 6pt)
  cdraw.content((5.8, 0.3), [gauss-seidel solid dots, 0.125 digits per sweep, jacobi dashed, 0.0625], size: 6pt)
})

== convergence: the spectral radius decides

Subtract the fixed point from the iteration and the affine part cancels:
the error $e^((k)) = x^* - x^((k))$ satisfies $e^((k)) = bold(C)^k e^((0))$
for whichever iteration matrix $bold(C)$ the splitting produced. If
$bold(C)$ is diagonalizable, $bold(C) = bold(V)
bold(D) bold(V)^(-1)$, then $bold(C)^k = bold(V) bold(D)^k bold(V)^(-1)$,
and $bold(D)^k$ dies exactly when every $|lambda_i| < 1$, that is when the
spectral radius $rho(bold(C)) = max |lambda_i (bold(C))|$ is under 1. The
jordan form extends the same conclusion to every matrix, the polynomial
factors $k^(j) rho^k$ still dying when $rho < 1$ (Varga 1962 by name). So
convergence is a property of the splitting, checkable before the first
sweep, and the model problem's plateau pattern from the last section is
now explained: $bold(M)_J$ for the tridiagonal has eigenvalues $plus.minus
cos(pi\/6), plus.minus cos(2 pi\/6), 0$, a sign pair at the dominant
magnitude $sqrt(3)\/2 = 0.8660254$, and a sign pair alternates the error
direction every sweep, which stalls the $inf$-norm for one step and drops
it by $rho^2 = 0.75$ over two. Gauss-seidel's iteration matrix has no sign
pair, its dominant eigenvalue is exactly $3\/4$, and it drops 0.75 every
sweep.

How to get $rho$ without a full eigensolver, chapter
#xref-to("math", "decomp") style: power iteration on the explicit
iteration matrix, next section's tool used early. Building $bold(M)_J =
bold(D)^(-1) (bold(L) + bold(U))$ is one division per off-diagonal entry;
building $bold(M)_("GS") = -(bold(D) + bold(L))^(-1) bold(U)$ column by
column is forward substitution, and the pinned result on the model is zero
above its superdiagonal, 0.5 on that superdiagonal, halving down each
column below it, $(0, .5, 0, 0, 0), (0, .25, .5, 0, 0), (0, .125, .25, .5,
0), (0, .0625, .125, .25, .5), (0, .03125, .0625, .125, .25)$. Power
iteration pins 0.75 on it.

The easy sufficient condition is strict diagonal dominance, and its proof
is one line: for any induced norm $rho(bold(C)) <= ||bold(C)||$, because
$bold(C) v = lambda v$ at the maximal component of $v$ gives $|lambda| <=
sum_j |bold(C)_("ij")|$, and for jacobi that row sum is exactly the
off-diagonal mass over the diagonal. The strict fixture
$"tridiag"(1, 4, 1)$ with $n = 3$ checks it: the bound is $0.5$, the true
radius measured by power iteration is $sqrt(2)\/4 = 0.3536$, honest but
pessimistic, and two pinned sweeps land $(0.875, 0.875, 0.875)$. The model
problem itself is only weakly dominant, $2 = 1 + 1$ every interior row, so
$||bold(M)_J||_inf = 1$ exactly, a bound that proves nothing: the true
radius $0.866$ lives under 1 only because the tridiagonal has extra
structure (irreducibility, Varga 1962 by name). A norm bound sitting at
exactly 1 next to a spectrum well inside it is the pinned two-number play
of this section.

#listing("math/samples/src/Ch23/jacobi.c", first: 113, last: 147, caption: [jacobi.c, power iteration returning the norm ratio and the rayleigh quotient side by side])

#diagram([eigenvalues of the iteration matrices against the unit circle, inside converges, outside blows up], length: 13pt, {
  let ox = 8.2
  let oy = 3.9
  let u(t) = (ox + t * 1.15, oy)
  let uo(t, dy) = (ox + t * 1.15, oy + dy)
  // dots sit ON the axis at their eigenvalue; thin leaders tie labels to dots
  let ev(t, filled, up, h, label, labh) = {
    cdraw.circle(uo(t, 0.0), radius: 0.07, fill: if filled { luma(30) } else { none }, stroke: if filled { none } else { luma(60) })
    if label != none {
      cdraw.line(uo(t, if up { 0.12 } else { -0.12 }), uo(t, if up { h - 0.2 } else { -h + 0.2 }), stroke: (paint: luma(150), dash: "dashed"))
      cdraw.content(uo(t, if up { labh } else { -labh }), label, size: 6pt)
    }
  }
  cdraw.circle((ox, oy), radius: 1.15, fill: luma(245), stroke: luma(100))
  cdraw.line(u(-3.2), u(7.2), stroke: luma(100), mark: (end: ">"))
  // jacobi: pair at the rim, +/-0.5, and 0; gauss-seidel: open dot at 0.75
  ev(0.866, true, false, 1.0, [0.866], 1.0)
  ev(-0.866, true, true, 1.0, none, 0.0)
  ev(0.5, true, true, 1.0, none, 0.0)
  ev(-0.5, true, true, 1.0, none, 0.0)
  ev(0.0, true, true, 1.0, none, 0.0)
  // gauss-seidel's 0.75 raised off the axis so it cannot merge with 0.866
  cdraw.line(uo(0.75, 0.0), uo(0.75, 0.28), stroke: luma(140))
  cdraw.circle(uo(0.75, 0.28), radius: 0.07, fill: none, stroke: luma(60))
  cdraw.line(uo(0.75, 0.4), uo(0.75, 1.15), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content(uo(0.75, 1.4), [0.75], size: 6pt)
  // divergence: jacobi +/-sqrt6, GS at 6
  ev(2.449, false, true, 0.85, [sqrt(6)], 1.25)
  ev(-2.449, false, true, 0.85, [-sqrt(6)], 1.25)
  ev(6.0, false, true, 0.85, [6], 1.25)
  cdraw.content(uo(-1.55, 0.85), [rho = 1], size: 6pt)
  cdraw.content((4.6, 7.1), [model splittings inside], size: 6pt)
  cdraw.content((10.9, 1.3), [divergent fixture outside], size: 6pt)
})

#callout("pitfall", "A BOUND OF EXACTLY 1 IS SILENT", [Weak diagonal dominance gives $||bold(M)_J||_inf = 1$ on the laplacian model, which neither proves nor refutes convergence: norms bound the spectrum from above and the gap can be the whole story, here 1.0 against 0.866. Always measure the radius, or check irreducibility before trusting a weak bound.])

== power iteration and deflation

The dominant eigenvalue hides inside one repeated product. Normalize any
start vector, multiply, normalize again, and the iterate turns toward the
eigenvector of the largest $|lambda|$ at the rate of the second ratio
$|lambda_2| \/ |lambda_1|$. The rayleigh quotient
$(x^T bold(A) x) \/ (x^T x)$ then converges to $lambda_1$ at the squared
rate, because the components orthogonal to the winning eigenvector shrink
before they are squared by the quotient.

The fixture wears its spectrum on its sleeve: $bold(A) = bold(R)
"diag"(6, 3, 1) bold(R)^T$ with $bold(R)$ the rational rotation carrying
$cos = 3\/5, sin = 4\/5$ in the (1,2) plane, so in exact arithmetic

$ bold(A) = 1\/25 mat(102, 36, 0; 36, 123, 0; 0, 0, 25) $

with eigenvector $(0.6, 0.8, 0)$ for 6. In doubles the entries land within
an ulp, $4.08, 1.4399999999999997, 4.920000000000001$, and the mirror
pinned every ladder.

The dry run: from $x_0 = "ones"$ (normalization is a common factor, so it
cancels in the quotient), the first product is $bold(A) "ones" =
(4.08 + 1.44, 1.44 + 4.92, 1) = (5.52, 6.36, 1)$ and the first rayleigh
quotient is $(5.52 + 6.36 + 1)\/3 = 4.293333333333$, the pinned first
rung. The ladder then climbs 5.915461624027, 5.994214746109, 5.998989023559,
and after 30 sweeps pins 6 one ulp out, $6 + 8.9 dot 10^(-16)$, with the
iterate $(0.6, 0.8, 0)$ and the error ratios closing on $(3\/6)^2 = 0.25$,
0.24998 at the eighth rung: the iterate error loses the factor $1\/2$
per sweep and the quotient error its square, so the quotient gains digits
exactly twice as fast.

Deflation hands you the second eigenpair from the first: subtract the rank
one piece, $bold(A)' = bold(A) - 6 v v^T$, and 6 is gone from the
spectrum while everything else stands. Power iteration on $bold(A)'$
converges to 3 at rate $1\/3$, and the pinned 30-sweep iterate is
$(-0.8, 0.6, 0)$, the second rotation column, to $2.1 dot 10^(-10)$, the
measured worst deviation.

The failure mode is equal magnitudes with opposite signs. Build
$bold(B) = bold(S) "diag"(6, -6, 1) bold(S)^T$ with the same rotation moved
to the (2,3) plane and run the identical loop: the norm ratio
$||bold(B) x|| \/ ||x||$ still converges to 6, magnitudes survive, but the
iterate never settles. Its direction flips every step between two mirror
states, consecutive iterates lock at $|cos angle| = 12\/37 = 0.3243$, about
71 degrees apart, and the rayleigh quotient pins at
$6 (a^2 - b^2)\/(a^2 + b^2) = -144\/74 = -1.945945945945946$, a number
that is not an eigenvalue of anything. The two-number play of the section:
the norm ratio says 6, the quotient says -1.946, and only the ratio is
telling the truth. The fix in practice is a shift, $bold(B) + mu bold(I)$,
or the QR iteration of chapter #xref-to("math", "decomp").

#listing("math/samples/src/Ch23/power.c", first: 60, last: 96, caption: [power.c, the symmetric builder in mirror order and the power loop carrying quotient, norm ratio, and the previous iterate])

#listing("math/samples/src/Ch23/power.c", first: 152, last: 169, caption: [power.c, the equal-magnitude fixture, quotient at -144/74, norm ratio at 6, iterate flip at cos 12/37])

#diagram([the rayleigh quotient per sweep, one ladder climbing to 6, the equal-magnitude fixture flat at -1.946], length: 13pt, {
  let px(k, v) = (1.4 + (k / 8.0) * 8.8, 1.7 + ((v + 3.0) / 10.0) * 5.8)
  let good = ((1, 4.293), (2, 5.915), (3, 5.994), (4, 5.999))
  for i in range(good.len() - 1) {
    cdraw.line(px(good.at(i).at(0), good.at(i).at(1)), px(good.at(i + 1).at(0), good.at(i + 1).at(1)), stroke: luma(60))
  }
  for t in good {
    cdraw.circle(px(t.at(0), t.at(1)), radius: 0.08, fill: luma(30), stroke: none)
  }
  cdraw.line(px(0.8, -1.946), px(8.6, -1.946), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line(px(0.8, 6.0), px(8.6, 6.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.4, 1.7), (10.6, 1.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((1.4, 1.7), (1.4, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 7.9), [rayleigh quotient per sweep], size: 6pt)
  cdraw.content((8.6, 7.25), [6, the norm ratio says 6 on both fixtures], size: 6pt)
  cdraw.content((4.0, 2.68), [flat at -144/74 = -1.946], size: 6pt)
})

== condition numbers

Chapter #xref-to("math", "error") defined conditioning as the worst case
amplification of relative input error, and chapter
#xref-to("math", "decomp") identified the 2-norm condition number as
$kappa_2 = sigma_max \/ sigma_min$, the singular value ratio. This chapter
can measure both ends with its own machinery: power iteration for
$sigma_max$ on a symmetric positive definite matrix, and inverse iteration,
which is power iteration on $bold(A)^(-1)$ through a hand LU, for
$sigma_min$. No eigensolver is pulled in from outside.

The first fixture is $bold(K) = mat(1, 1; 1, 1.0001)$. Its exact spectrum
is available in closed form (mpmath 40 digits in the pin script), and the
measured pair agrees: $lambda_max = 2.00005000125$, $lambda_min =
4.999875 dot 10^(-5)$, $kappa_2 = 40002.00007500125$, the measured value
matching to 9 digits. The perturbation bound
$||delta x||\/||x|| <= kappa_2 (||delta b||\/||b||)$ is then observed, not
just quoted (Trefethen and Bau 1997 by name for the bound): take
$bold(x) = (1, 1)$, $bold(b) = bold(K) bold(x) = (2, 2.0001)$, and nudge
the second component of $b$ down by $10^(-4)$.

The dry run, by hand in exact arithmetic: $bold(K)^(-1) = 10^4
mat(1.0001, -1; -1, 1)$ because the determinant is $10^(-4)$, so
$bold(K)^(-1) (0, -10^(-4)) = 10^4 (10^(-4), -10^(-4)) = (1, -1)$ and the
solution moves to $(1, 1) + (1, -1) = (2, 0)$. The computed solution is
$(2.0000000000022204, -2.2 dot 10^(-12))$. A relative data change of
$3.535 dot 10^(-5)$, four digits of $b$, moved the answer by a relative
1.0: the flip is total, the amplification is 28285, and the bound reads
$40002 dot 3.535 dot 10^(-5) = 1.414 >= 1$: satisfied, with room of about
$sqrt(2)$, because the perturbation did not align with the worst singular
direction.

The residual is not the error. Solve the 10 by 10 hilbert system
$bold(H) bold(x) = bold(H) "ones"$ (entries $1\/(i + j + 1)$, the least
squares ghost of chapter #xref-to("math", "interp")) with the same LU:
the computed $z$ misses $"ones"$ by $3.2 dot 10^(-4)$ while its residual
$||bold(H) z - bold(H) "ones"||_inf$ is $1.8 dot 10^(-16)$, rounding noise.
The residual measures backward error, the solve is stable, and the forward
error is the residual amplified by the conditioning: measured $kappa_2 =
1.60 dot 10^13$, so the expected error scale is $kappa_2 dot 2^(-52) =
3.6 dot 10^(-3)$, and $3.2 dot 10^(-4)$ sits comfortably inside. That is
the whole story of "my solver lost 13 digits": it did not, the problem
never had them.

#listing("math/samples/src/Ch23/condition.c", first: 134, last: 161, caption: [condition.c, inverse iteration, power iteration on the LU inverse, one extra solve for the eigenvalue])

#listing("math/samples/src/Ch23/condition.c", first: 180, last: 201, caption: [condition.c, the perturbation flip, relative changes, amplification 28285 under kappa 40002, bound value 1.414])

#diagram([the input ball mapped through the matrix to a kappa-stretched ellipse, the flip as one endpoint], length: 13pt, {
  cdraw.circle((3.2, 4.6), radius: 1.3, fill: none, stroke: luma(60))
  cdraw.content((3.2, 7.0), [data ball], size: 6pt)
  cdraw.content((3.2, 6.5), [$|delta b|\/|b| = 3.5 dot 10^(-5)$], size: 6pt)
  cdraw.content((3.2, 2.9), [no preferred direction], size: 6pt)
  // stretched output ellipse, minor axis exaggerated, 16-point polyline
  let ell = ((15.0, 4.6), (14.726, 4.887), (13.946, 5.13), (12.778, 5.293), (11.4, 5.35), (10.022, 5.293), (8.854, 5.13), (8.074, 4.887), (7.8, 4.6), (8.074, 4.313), (8.854, 4.07), (10.022, 3.907), (11.4, 3.85), (12.778, 3.907), (13.946, 4.07), (14.726, 4.313))
  for i in range(ell.len()) {
    let a = ell.at(i)
    let b = ell.at(calc.rem(i + 1, ell.len()))
    cdraw.line(a, b, stroke: luma(60))
  }
  cdraw.line((7.8, 4.6), (15.0, 4.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((11.4, 3.85), (11.4, 5.35), stroke: luma(140))
  cdraw.content((15.0, 5.9), [sigma_max direction], size: 6pt)
  cdraw.content((9.4, 3.3), [sigma_min direction], size: 6pt)
  cdraw.circle((7.8, 4.6), radius: 0.12, fill: luma(30), stroke: none)
  cdraw.circle((15.0, 4.6), radius: 0.12, fill: none, stroke: luma(60))
  cdraw.content((7.2, 5.95), [$x = (1, 1)$], size: 6pt)
  cdraw.content((14.9, 3.4), [$x' = (2, 0)$], size: 6pt)
  cdraw.content((11.4, 6.9), [$kappa_2 = 40002$ stretches the ball $4 dot 10^4$ times along sigma_max], size: 6pt)
  cdraw.line((4.6, 4.6), (6.4, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.5, 5.0), [K], size: 6.5pt)
})

== iterative refinement

Elimination gives a backward stable $z$ with a tiny residual. One
refinement step computes the residual $r = b - bold(A) z$ in the same
doubles, solves $bold(A) d = r$ with the factors already in hand, and adds
$d$. If $z$ were exact the correction would be zero, and to the extent the
residual is honest, $z + d$ is a better solve. The method is two sentences;
the interesting part is when it stops helping.

The dry run: on $bold(K)$ the residual of the plain solve rounds to
exactly $(0, 0)$, three refinement steps change nothing, and the error
freezes at $3.1 dot 10^(-12)$. On the hilbert system one step buys the
5.5x gain from $3.2 dot 10^(-4)$ to $5.8 dot 10^(-5)$, then the ladder
wanders inside the $3.6 dot 10^(-3)$ band.

On $bold(K)$ it stops immediately, and the sample pins why: the residual
of the plain solve rounds to exactly $(0, 0)$, both components, so three
refinement steps are literally a no-op, the error frozen at $3.1 dot
10^(-12)$. Nothing is wrong with the solver. The stored $bold(K)$ and
$b$ differ from the real numbers by input rounding at $10^(-16)$ scale.
One estimate of the damage is $||bold(K)^(-1)||$ times that rounding,
about $4.4 dot 10^(-12)$; the check states the ceiling as the separate
quantity $kappa dot 2^(-52) = 8.9 dot 10^(-12)$, and the frozen $3.1 dot
10^(-12)$ error sits under both. The error was
never in the solve to begin with, so there is nothing for refinement to
retrieve.

On the hilbert system the ladder is livelier and pinned rung by rung:
$3.2 dot 10^(-4)$, one step to $5.8 dot 10^(-5)$, a 5.5x gain, then
$3.2 dot 10^(-4)$, $9.8 dot 10^(-4)$, $9.5 dot 10^(-4)$, $8.4 dot
10^(-4)$: the second correction hands back the first one's winnings and
the ladder wanders inside the $kappa dot 2^(-52) = 3.6 dot 10^(-3)$ band
without ever leaving it. The pin script's higher-precision audit explains
the wandering: the exact solution of the stored system is itself $5 dot
10^(-4)$ away from $"ones"$, because $b$ was rounded on the way in, so the
error being measured is dominated by input rounding, and each correction
injects fresh solve rounding at the same scale it removes. Refinement
converges reliably when the residual is computed more accurately than the
solve, the classical extended-precision recipe (Higham 2002 by name); in
plain doubles the honest statement is the band, and both ladders here are
checks, not anecdotes.

#listing("math/samples/src/Ch23/condition.c", first: 274, last: 307, caption: [condition.c, the hilbert ladder, one 5.5x gain, then wandering inside the kappa band, every rung a check])

#diagram([the refinement ladder in digits of accuracy, one gain then wandering above the band edge], length: 13pt, {
  let bar(i, digits, dark) = {
    let x = 0.8 + 1.4 * i
    let h = (digits / 4.6) * 5.4
    cdraw.rect((x, 1.6), (x + 1.05, 1.6 + h), fill: if dark { luma(205) } else { luma(235) }, stroke: luma(100), radius: 0.02)
  }
  bar(0, 3.50, false)
  bar(1, 4.24, true)
  bar(2, 3.50, false)
  bar(3, 3.01, false)
  bar(4, 3.02, false)
  bar(5, 3.07, false)
  let band = 1.6 + (2.45 / 4.6) * 5.4
  cdraw.line((0.5, band), (9.0, band), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((0.5, 1.6), (11.0, 1.6), stroke: luma(100), mark: (end: ">"))
  for i in range(6) {
    cdraw.content((1.32 + 1.4 * i, 1.1), [#i], size: 6pt)
  }
  cdraw.content((4.4, 0.55), [refinement step], size: 6pt)
  cdraw.content((6.0, 8.4), [digits of accuracy, $-"log"_10 ||e||_inf$], size: 6pt)
  cdraw.content((10.4, band + 0.6), [$kappa dot 2^(-52)$], size: 6pt)
  cdraw.content((10.4, band - 0.6), [band edge], size: 6pt)
  cdraw.content((2.5, 6.95), [5.5x], size: 6pt)
})

#callout("warning", "SMALL RESIDUAL, LARGE ERROR", [A residual at rounding level certifies the solve, never the answer. On the hilbert fixture the residual is $1.8 dot 10^(-16)$ while the error is $3.2 dot 10^(-4)$, and refinement cannot cross that gap because the gap belongs to the problem, not the algorithm. Chapter #xref-to("math", "error") made the distinction for subtraction; here it is the whole discipline of judging a linear solve.])

The next chapter #xref-to("math", "strategic") turns from converging on
answers to converging on opponents: the fixed points become equilibrium
strategies, and the iteration counts become rounds of play.

sources: mml-book draft 2024-01-15, ch 2.3.4 "algorithms for solving a
system of linear equations", printed pp 34-35 (pdf pp 40-41), the
fixed-point iteration form eq 2.60 and the iterative alternatives named
there (richardson, jacobi, gauss-seidel, sor, krylov cg/gmres/bicg),
cross verified against ref/mml-book.pdf on 2026-09-22. Trefethen and Bau,
Numerical Linear Algebra, SIAM 1997 (conditioning and perturbation bounds,
eigenvalue iterations, by name; siam.org and epubs.siam.org pages returned
cloudflare challenges on 2026-09-22). Higham, Accuracy and Stability of
Numerical Algorithms, 2nd ed, SIAM 2002, ISBN 0-89871-521-0 (iterative
refinement, extended-precision residuals, by name),
https://nhigham.com/accuracy-and-stability-of-numerical-algorithms/,
fetched 2026-09-22. Varga, Matrix Iterative Analysis, Prentice-Hall 1962
(spectral radius criterion, irreducible weak dominance, by name). Young,
Iterative Solution of Large Linear Systems, Academic Press 1971
(rho_GS = rho_J^2 for consistently ordered matrices, by name). Expected
sample values computed by the playground one-off
playground/math-ch23/pin.py, python 3.14.7 double arithmetic mirroring the
C expression order with numpy and mpmath 40-digit audits, run 2026-09-22.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/math/samples/src -Chapter Ch23`, 68 checks in chapter 23
of the math suite, 4 files, zero failures.
