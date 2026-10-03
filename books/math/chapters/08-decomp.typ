#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= matrix decompositions

A matrix decomposition factors one matrix into simpler pieces whose shape
tells you what the matrix does. This chapter builds six of them on paper and
pins each one in c: the determinant and trace as the two scalar fingerprints
of a matrix, eigenvalues and eigenvectors from the characteristic polynomial,
the Cholesky square root of a symmetric positive definite matrix, QR from
Gram-Schmidt, the singular value decomposition, and the Eckart-Young rank-k
approximation that low-rank compression and pca rest on. The sibling dsa
book calls a factorization library inside its solvers, this chapter derives
each factor by hand on fixed matrices and verifies it against exact
precomputed values. Every behavioral claim below is one of the 52 checks in
the 4 samples of chapter 08 or a sentence quoted from the mml-book draft
2024-01-15, read 2026-09-21. Chapter #xref-to("math", "matrices") supplies
Gaussian elimination and the inverse, chapter #xref-to("math", "inner")
supplies the projection machinery that Gram-Schmidt uses.

== determinant and trace

The determinant maps a square matrix to one number: for a 2x2 matrix it is
$a_(11) a_(22) - a_(12) a_(21)$ (mml Example 4.1, eq 4.4), and a matrix is
invertible exactly when that number is nonzero (mml Theorem 4.1). Geometric
reading, quoted: "the determinant $det(A)$ is the signed volume of an
$n$-dimensional parallelepiped formed by columns of the matrix $A$" (mml
Example 4.2, printed pp 101-102). The sign carries orientation, swapping two
columns flips it. For a 3x3 matrix Sarrus' rule (mml eq 4.7) expands the
determinant into six triple products, and Laplace expansion (mml Theorem
4.2) reduces an $n times n$ determinant to $n$ determinants of size
$(n-1) times (n-1)$, so both give the same number on our fixtures. The trace
is the other scalar fingerprint: $tr(A) := sum_(i=1)^n a_(i i)$, the sum of
the diagonal (mml Definition 4.4). Its one non-obvious identity is cyclic:
$tr(A B) = tr(B A)$ even for rectangular $A in RR^(n times k)$, $B in RR^(k
times n)$ where the two products have different sizes, and the two counts
meet the same eigenvalues in section 2: $det(A) = product_(i=1)^n lambda_i$
(mml Theorem 4.16) and $tr(A) = sum_(i=1)^n lambda_i$ (mml Theorem 4.17).

The dry run: the volume fixture is the mml Example 4.2 matrix
$A = mat(2, 6, 1; 0, 1, 4; -8, 0, -1)$.

+ Sarrus: $2 dot 1 dot (-1) + 0 dot 0 dot 1 + (-8) dot 6 dot 4 = -194$
  against the counter-diagonal $(-8) dot 1 dot 1 + 2 dot 0 dot 4 + 0 dot 6
  dot (-1) = -8$, and $-194 + 8 = -186$. The volume is $|det(A)| = 186$,
  the negative sign says the column triple is orientation flipping.
+ Laplace along the first row gives the same -186 by three cofactors:
  $2(-1 - 0) - 6(0 + 32) + 1(0 + 8)$.
+ The trace pair: with the mml Example 2.3 rectangles $A B = mat(2, 3; 2,
  5)$ has trace $2 + 5 = 7$ and $B A = mat(6, 4, 2; -2, 0, 2; 3, 2, 1)$ has
  trace $6 + 0 + 1 = 7$. Different shapes, one number.
+ Eigenvalue handshake on $mat(4, 2; 1, 3)$: eigenvalues 5 and 2 give
  $det = 5 dot 2 = 10$ and $tr = 5 + 2 = 7$, both matching direct
  computation.

#callout("pitfall", "DETERMINANT NOTATION", [mml warns that the
alternative notation $|A|$ "must not be confused with the absolute value".
The determinant of $mat(2, 6, 1; 0, 1, 4; -8, 0, -1)$ is -186 while its
absolute value, the volume, is 186. This book writes $det(A)$.])

The characteristic polynomial packages both fingerprints into one object,
$p_A (lambda) = det(A - lambda I) = c_0 + c_1 lambda + dots +
(-1)^n lambda^n$ with $c_0 = det(A)$ and $c_(n-1) = (-1)^(n-1) tr(A)$ (mml
Definition 4.5). Faddeev-LeVerrier computes all coefficients from traces of
matrix powers, no symbolic algebra: $M_1 = A$, $p_1 = -tr(M_1)$, then $M_k =
A (M_(k-1) + p_(k-1) I)$ and $p_k = -tr(M_k) / k$.

#listing("math/samples/src/Ch08/dettrace.c", first: 69, last: 93, caption: [dettrace.c, faddeev-leverrier turns traces of powers into polynomial coefficients])

On the symmetric fixture $mat(3, 2, 2; 2, 3, 2; 2, 2, 3)$ the recurrence
yields $p_A (lambda) = -lambda^3 + 9 lambda^2 - 15 lambda + 7$, with $c_0 =
7 = det(A)$ and $c_2 = 9 = tr(A)$, both integers exactly representable in
doubles. The sample then pins volume, sign flip under a column swap,
multiplicativity $det(A B) = det(A) det(B)$ as $49 = 7^2$, the trace
identities $tr(A^2) = 51$ and $tr(A^3) = 345$, and both eigenvalue
handshakes.

#listing("math/samples/src/Ch08/dettrace.c", first: 103, last: 115, caption: [dettrace.c, sarrus and laplace agree on the signed volume -186])

#diagram([unit square and its image, area scales by det a = 3], length: 13pt, {
  // unit square, scaled 1.2
  cdraw.rect((0.8, 0.6), (2.0, 1.8), fill: luma(245), stroke: luma(100))
  cdraw.content((1.4, 2.1), [area 1], size: 6pt)
  // image under [[2,1],[1,2]]: (1,0) -> (2,1), (0,1) -> (1,2), corner (3,3)
  let p = ((6.2, 0.6), (8.6, 1.8), (9.8, 4.2), (7.4, 3.0))
  cdraw.line(..p, close: true, fill: luma(205), stroke: luma(60))
  cdraw.content((8.0, 4.5), [area 3], size: 6pt)
  cdraw.line((2.6, 2.2), (5.6, 2.2), stroke: luma(140), mark: (end: ">"))
  cdraw.content((4.1, 2.5), [a scales area by det a], size: 6pt)
})

The two-number play: the same column triple scores -186 and +186, identical
volume, opposite orientation. And one matrix owns two scalar fingerprints,
here 7 and 9, whose factorization and sum the eigenvalues reproduce.

== eigenvalues and eigenvectors

An eigenvalue $lambda$ with eigenvector $x != 0$ solves $A x = lambda x$
(mml Definition 4.6, eq 4.25): $A$ leaves the line through $x$ invariant and
stretches it by $lambda$. The eigenvalues are exactly the roots of $p_A
(lambda)$ (mml Theorem 4.8), and the eigenvectors for a given $lambda$ span
the eigenspace $E_lambda$, the null space of $A - lambda I$ (mml Definition
4.10). When $A$ has $n$ linearly independent eigenvectors they form a basis
(mml Theorem 4.12), $P = [p_1, dots, p_n]$ is invertible, and the
diagonalization $A = P D P^(-1)$ holds with the eigenvalues on the diagonal
of $D$ (mml Definition 4.19, Theorem 4.20). The key lemma is columnwise:
$A P = P D$ holds if and only if $A p_i = lambda_i p_i$ for every column
(mml eq 4.50).

The dry run: the fixture is the mml Example 4.5 matrix $A = mat(4, 2; 1,
3)$, trace 7, determinant 10.

+ Characteristic polynomial: $(4 - lambda)(3 - lambda) - 2 = lambda^2 - 7
  lambda + 10$. Quadratic formula: $(7 plus.minus sqrt(49 - 40)) / 2 = (7
  plus.minus 3) / 2$, eigenvalues 5 and 2.
+ Eigenvector for 5: $A - 5 I = mat(-1, 2; 1, -2)$, rows collinear, null
  direction $(2, 1)$. Check: $A (2, 1) = (10, 5) = 5 (2, 1)$.
+ Eigenvector for 2: $A - 2 I = mat(2, 2; 1, 1)$, null direction $(1, -1)$,
  and $A (1, -1) = (2, -2)$.
+ Diagonalization: $P = mat(2, 1; 1, -1)$ with $det(P) = -3$, so $P^(-1) =
  mat(1/3, 1/3; 1/3, -2/3)$. Then $A P = mat(10, 2; 5, -2) = P D$ entry by
  entry, and $P D P^(-1)$ rebuilds $A$ to $10^(-12)$.

#listing("math/samples/src/Ch08/eigen.c", first: 83, last: 106, caption: [eigen.c, quadratic formula for the eigenvalue pair, eigenvector checks against exact integer arithmetic])

#diagram([unit circle mapped to an ellipse, semi-axes 5 and 2 along the eigen-directions], length: 13pt, {
  // A (cos t, sin t) = (4 cos t + 2 sin t, cos t + 3 sin t), 16 sample points
  let pts = ((4.0, 1.0), (4.46, 2.37), (4.24, 2.83), (3.73, 3.10), (2.0, 3.0),
    (-0.27, 2.10), (-1.41, 1.41), (-2.46, 0.63), (-4.0, -1.0), (-4.46, -2.37),
    (-4.24, -2.83), (-3.73, -3.10), (-2.0, -3.0), (0.27, -2.10), (1.41, -1.41),
    (2.46, -0.63))
  cdraw.line(..pts, close: true, stroke: luma(60))
  // eigen-directions: 5 (2,1)/sqrt5 and 2 (1,-1)/sqrt2
  cdraw.line((-4.47, -2.24), (4.47, 2.24), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.41, -1.41), (-1.41, 1.41), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((4.6, 2.5), [stretch 5], size: 6pt)
  cdraw.content((-1.9, 1.8), [stretch 2], size: 6pt)
})

The ellipse is the point of the section: the unit circle maps to an ellipse
whose semi-axes are the eigenvalues, each pointing along its eigenvector.
The two-number play: 5 and 2, the stretch factors along $(2, 1)$ and $(1,
-1)$, multiply to the area scale 10 and add to the trace 7.

The symmetric case is where the theory closes. The spectral theorem (mml
Theorem 4.15) says a symmetric $A in RR^(n times n)$ has an orthonormal
basis of eigenvectors and all real eigenvalues, so a symmetric matrix is
always diagonalizable (mml Theorem 4.21) and $P$ can be taken orthogonal
with $P^(-1) = P^top$. The 3x3 symmetric fixture $mat(3, 2, 2; 2, 3, 2; 2,
2, 3)$ from section 1 has $p_A (lambda) = -(lambda - 1)^2 (lambda - 7)$, a
repeated root. The sample finds 7 among the integer divisors of $det = 7$,
deflates to the quotient $lambda^2 - 2 lambda + 1$ with discriminant 0, and
reads off the double root 1. Algebraic multiplicity 2 for $lambda = 1$, and
the geometric multiplicity is honest too: $A - I$ is the all-2s matrix of
rank 1, so $E_1$ is 2-dimensional with basis $(-1, 1, 0)$ and $(-1, 0, 1)$
(mml Example 4.8, eq 4.39). Inside $E_1$ one Gram-Schmidt step orthogonalizes
them to $(-1, 1, 0)$ and $1/2 (-1, -1, 2)$ (mml eq 4.41), and appending
$(1, 1, 1) / sqrt(3)$ from $E_7$ gives the orthogonal $P$ with $A = P D
P^top$ verified to $10^(-12)$.

#listing("math/samples/src/Ch08/eigen.c", first: 160, last: 184, caption: [eigen.c, integer root, deflation, and the rank count that certifies the eigenspace dimension])

#callout("note", "SIGN FREEDOM", [If $x$ is an eigenvector so is $c x$ for
any $c != 0$, mml's collinearity remark after Definition 4.7. The checks pin
one representative per line, $(2, 1)$ and $(1, -1)$, and the sample verifies
the eigen equation on exactly those representatives with integer
arithmetic.])

== symmetric matrices and cholesky

Symmetric positive definite matrices are the square matrices of positive
numbers: $A = A^top$ and $x^top A x > 0$ for every $x != 0$ (mml Definition
3.4). Their square root is the Cholesky factorization, quoted: "A symmetric,
positive definite matrix $A$ can be factorized into a product $A = L L^top$,
where $L$ is a lower-triangular matrix with positive diagonal elements"
(mml Theorem 4.18). The factor $L$ is unique, and matching entries of $A =
L L^top$ gives the computing pattern directly (mml Example 4.10, eqs
4.47-4.48): the diagonal entries are nested square roots
$l_(j j) = sqrt(a_(j j) - sum_(k<j) l_(j k)^2)$ and the below-diagonal
entries are nested divisions, each computable top to bottom from entries
already known.

The dry run: the fixture is $A = mat(4, 2, -2; 2, 5, 5; -2, 5, 14)$, built
as $L L^top$ for $L = mat(2, 0, 0; 1, 2, 0; -1, 3, 2)$ so the factorization
must return exactly that $L$.

+ First column: $l_(11) = sqrt(4) = 2$, $l_(21) = 2 \/ 2 = 1$, $l_(31) =
  -2 \/ 2 = -1$.
+ Second column: $l_(22) = sqrt(5 - 1^2) = 2$, then $l_(32) = (5 - (-1)
  dot 1) \/ 2 = 3$.
+ Third column: $l_(33) = sqrt(14 - (-1)^2 - 3^2) = sqrt(4) = 2$.
+ Determinant bonus, mml Section 4.3: $det(A) = det(L)^2 = product_i
  l_(i i)^2 = (2 dot 2 dot 2)^2 = 64$, and Sarrus on $A$ agrees.
+ Failure trace on the mml Example 3.4 matrix $mat(9, 6; 6, 3)$:
  symmetric, but $l_(11) = 3$, $l_(21) = 2$, then the radicand $3 - 2^2 =
  -1$. A negative radicand is not a rounding artifact, it is the proof that
  $x^top A x$ takes negative values, here with witness $x = (2, -3)$.

#listing("math/samples/src/Ch08/factor.c", first: 27, last: 51, caption: [factor.c, the nested cholesky recurrence, returning false on a negative radicand])

#listing("math/samples/src/Ch08/factor.c", first: 98, last: 108, caption: [factor.c, the non-spd input fails at l22 with radicand -1])

#diagram([cholesky splits a into two triangular shadows of itself], length: 13pt, {
  let cell(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + w), fill: luma(235), stroke: luma(140))
    cdraw.content((x + w / 2, y + w / 2), t, size: 6pt)
  }
  let blank(x, y, w) = {
    cdraw.rect((x, y), (x + w, y + w), fill: luma(245), stroke: (paint: luma(150), dash: "dashed"))
  }
  // A
  cell(0.6, 4.2, 1.0, [4])
  cell(1.6, 4.2, 1.0, [2])
  cell(2.6, 4.2, 1.0, [-2])
  cell(0.6, 3.2, 1.0, [2])
  cell(1.6, 3.2, 1.0, [5])
  cell(2.6, 3.2, 1.0, [5])
  cell(0.6, 2.2, 1.0, [-2])
  cell(1.6, 2.2, 1.0, [5])
  cell(2.6, 2.2, 1.0, [14])
  cdraw.content((2.1, 5.6), [a], size: 6.5pt)
  // L
  cell(5.0, 4.2, 1.0, [2])
  blank(6.0, 4.2, 1.0)
  blank(7.0, 4.2, 1.0)
  cell(5.0, 3.2, 1.0, [1])
  cell(6.0, 3.2, 1.0, [2])
  blank(7.0, 3.2, 1.0)
  cell(5.0, 2.2, 1.0, [-1])
  cell(6.0, 2.2, 1.0, [3])
  cell(7.0, 2.2, 1.0, [2])
  cdraw.content((6.5, 5.6), [l], size: 6.5pt)
  // L^T
  cell(9.4, 4.2, 1.0, [2])
  cell(10.4, 4.2, 1.0, [1])
  cell(11.4, 4.2, 1.0, [-1])
  blank(9.4, 3.2, 1.0)
  cell(10.4, 3.2, 1.0, [2])
  cell(11.4, 3.2, 1.0, [3])
  blank(9.4, 2.2, 1.0)
  blank(10.4, 2.2, 1.0)
  cell(11.4, 2.2, 1.0, [2])
  cdraw.content((10.9, 5.6), [l^top], size: 6.5pt)
  // equals sign drawn as two strokes, never a label
  cdraw.line((4.2, 3.85), (4.7, 3.85), stroke: luma(60))
  cdraw.line((4.2, 3.55), (4.7, 3.55), stroke: luma(60))
  cdraw.content((8.7, 3.7), [times], size: 6.5pt)
})

The two-number play: the honest matrix hits radicand 4 at its second pivot
while the impostor hits -1 at the same spot. The decomposition is also the
cheap determinant: 64 as $8^2$ from three diagonal entries of $L$, against
64 from a full Sarrus pass.

== qr factorization

Gram-Schmidt orthogonalization, met in chapter #xref-to("math", "inner") as
eqs 3.67-3.68 of mml Section 3.8.3, subtracts from each new vector its
projection onto the span of the previous ones. Run it on the columns of a
matrix $A$ and you get the QR factorization: $A = Q R$ with $Q$ orthogonal
and $R$ upper triangular. The entries fall out of the construction, $r_(i j)
= q_i^top a_j$ for the projections and $r_(j j)$ the length of what is left
over. Orthogonal $Q$ means $Q^top Q = I$ and $|det(Q)| = 1$, and $R$ carries
the entire determinant in its diagonal: $det(A) = det(Q) product_i r_(i i)$,
with the sign of $det(Q)$ deciding orientation. This is the pattern the
numerical solvers in the dsa book lean on, $Q$ preserves lengths and angles
(mml eqs 3.31-3.32) while $R$ records the elimination. The
orthogonalization itself is mml's, eqs 3.67-3.68, the packaging into $Q R$
and the determinant split are this book's own derivation, carried by the
sample checks.

The dry run: the fixture is $A = mat(1, 1, 0; 1, 0, 1; 0, 1, 1)$,
determinant -2 by Sarrus.

+ Column 1: $u_1 = (1, 1, 0)$, $r_(11) = sqrt(2)$, $q_1 = (1, 1, 0) /
  sqrt(2)$.
+ Column 2: $r_(12) = q_1^top a_2 = 1 \/ sqrt(2)$, and $a_2 - r_(12) q_1 =
  (1, 0, 1) - 1/2 (1, 1, 0) = (1/2, -1/2, 1)$ of length $sqrt(3/2)$, so
  $q_2 = (1, -1, 2) \/ sqrt(6)$.
+ Column 3: $r_(13) = 1 \/ sqrt(2)$, $r_(23) = 1 \/ sqrt(6)$, remainder
  $(-2/3, 2/3, 2/3)$ of length $2 \/ sqrt(3)$, $q_3 = (-1, 1, 1) \/ sqrt(3)$.
+ Determinant: $det(Q) = -1$ exactly (the closed form is $1 \/ sqrt(36)$
  times a determinant of -6), $product_i r_(i i) = sqrt(2) dot sqrt(3/2)
  dot 2\/sqrt(3) = 2$, and $-1 dot 2 = -2$ matches Sarrus.

#listing("math/samples/src/Ch08/factor.c", first: 110, last: 131, caption: [factor.c, gram-schmidt as qr, projections into r and leftover lengths on the diagonal])

#diagram([gram-schmidt subtracts the projection, mml example 3.12 in two dimensions], length: 13pt, {
  // axes
  cdraw.line((0.6, 0.8), (9.6, 0.8), stroke: luma(140), mark: (end: ">"))
  cdraw.line((1.0, 0.4), (1.0, 5.0), stroke: luma(140), mark: (end: ">"))
  // u1 along the axis, b2 = (1,1) scaled 2.6
  cdraw.line((1.0, 0.8), (6.2, 0.8), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.0, 0.8), (3.6, 3.4), stroke: luma(60), mark: (end: ">"))
  // projection foot marked, residual u2 is the solid drop
  cdraw.circle((3.6, 0.8), radius: 0.05, fill: luma(60))
  cdraw.line((3.6, 0.8), (3.6, 3.4), stroke: luma(60), mark: (end: ">"))
  // right angle mark at the foot
  cdraw.line((3.3, 0.8), (3.3, 1.1), stroke: luma(140))
  cdraw.line((3.3, 1.1), (3.6, 1.1), stroke: luma(140))
  // dashed parallelogram side from the u2 tip to the b2 tip
  cdraw.line((1.0, 3.4), (3.6, 3.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((6.6, 1.0), [u1], size: 6pt)
  cdraw.content((2.6, 3.8), [b2], size: 6pt)
  cdraw.content((3.9, 2.1), [u2 = b2 - proj], size: 6pt)
})

The two-number play: det Q = -1 and diagonal product 2, the sign and the
magnitude of one determinant split across the two factors. Sample pins the
irrational diagonal $sqrt(2), sqrt(3\/2), 2\/sqrt(3)$ to 12 decimals and
verifies $Q^top Q = I$, the triangular shape of $R$, and the $Q R = A$
round trip.

== singular value decomposition

The SVD drops every restriction the eigendecomposition needs. Quoted from
mml Theorem 4.22: "The SVD of $A$ is a decomposition of the form $A = U
Sigma V^top$ with an orthogonal matrix $U in RR^(m times m)$ ... and an
orthogonal matrix $V in RR^(n times n)$", $Sigma$ rectangular with
nonnegative diagonal $sigma_1 >= sigma_2 >= ... >= 0$, and it "exists for
any matrix $A in RR^(m times n)$". The construction runs through the
symmetric theory of section 3: the eigenvectors of $A^top A$ are the
right-singular vectors $V$, its eigenvalues are the squared singular
values, $sigma_i^2 = lambda_i$ (mml eq 4.75), and the left-singular vectors
come from normalizing the images, $u_i = 1\/sigma_i A v_i$ (mml eq 4.78).
Geometrically $V^top$ rotates the domain onto its principal axes, $Sigma$
scales axis $i$ by $sigma_i$, and $U$ rotates into the codomain (mml
Section 4.5.1, Figure 4.8).

The dry run: the fixture is $A = mat(2, 3; 0, 2)$.

+ $A^top A = mat(4, 6; 6, 13)$, trace 17, determinant 16, eigenvalues $(17
  plus.minus 15)\/2 = 16$ and 1, so $sigma_1 = 4$ and $sigma_2 = 1$.
+ Right-singular vectors: eigenvector of $A^top A$ for 16 is $(1, 2)\/sqrt(5)$,
  for 1 it is $(-2, 1)\/sqrt(5)$.
+ Left-singular vectors by eq 4.78: $u_1 = 1\/4 A (1, 2)\/sqrt(5) = (8,
  4)\/(4 sqrt(5)) = (2, 1)\/sqrt(5)$, and $u_2 = A (-2, 1)\/sqrt(5) =
  (-1, 2)\/sqrt(5)$.
+ The full statement: $mat(2, 3; 0, 2) = 1\/sqrt(5) mat(2, -1; 1, 2)
  mat(4, 0; 0, 1) 1\/sqrt(5) mat(1, 2; -2, 1)$, verified to $10^(-12)$,
  and $det(A) = 4 = sigma_1 sigma_2$, orientation preserved since both
  factors are rotations.

#listing("math/samples/src/Ch08/svd.c", first: 36, last: 80, caption: [svd.c, singular values from the eigenvalues of a transposed a, then the pinned u and v round trip])

#diagram([svd as rotate, scale, rotate], length: 13pt, {
  let box(x, w, t1, t2) = {
    cdraw.rect((x, 2.2), (x + w, 4.0), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, 3.4), t1, size: 6.5pt)
    cdraw.content((x + w / 2, 2.6), t2, size: 6pt)
  }
  box(0.6, 3.2, [V^top], [rotate domain])
  box(5.0, 3.2, [Sigma], [scale by 4 and 1])
  box(9.4, 3.2, [U], [rotate codomain])
  cdraw.line((3.8, 3.1), (5.0, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.2, 3.1), (9.4, 3.1), stroke: luma(100), mark: (end: ">"))
  // small schematic: unit circle, then scaled ellipse
  cdraw.circle((2.2, 0.9), radius: 0.55, stroke: luma(60))
  cdraw.content((6.6, 1.7), [circle -> ellipse with semi-axes 4 and 1, then rotated], size: 6pt)
})

Rectangular matrices get the same treatment. The mml Example 4.13 rectangle
$mat(1, 0, 1; -2, 1, 0)$ has rank 2 and singular values $sqrt(6)$ and 1,
and the third right-singular vector $(-1, -2, 1)\/sqrt(6)$ comes with
$A v_3 = 0$: the SVD hands you an orthonormal basis of the kernel for free
(mml Section 4.5.2). The sample pins $A v_3$ to zero and counts the rank as
the number of nonzero singular values. For symmetric matrices the two
decompositions coincide, the SVD of an SPD matrix is its eigendecomposition
(mml Section 4.5.2 remark).

The two-number play: singular values 4 and 1 against eigenvalues 2 and 2.
The same determinant 4 splits both ways, $4 dot 1 = 2 dot 2$, but the
repeated eigenvalue leaves $mat(2, 3; 0, 2)$ defective, its only
eigendirection is $(1, 0)$, so no diagonalization exists while the SVD
sails through.

#callout("pitfall", "DO NOT BUILD THE SVD THIS WAY IN PRODUCTION", [mml
warns at the end of Example 4.13: "on a computer the approach illustrated
here has poor numerical behavior, and the SVD of $A$ is normally computed
without resorting to the eigenvalue decomposition of $A^top A$." The sample
follows the textbook route because its job is to pin the definitions,
library svd routines use variants of the Golub-Reinsch iteration.])

== low-rank approximation and pca

An outer product $u_i v_i^top$ is a rank-1 matrix, and the SVD rewrites $A$
as a sum of them weighted by singular values, $A = sum_(i=1)^r sigma_i u_i
v_i^top$ (mml eq 4.91). Keep only the first $k$ terms and you get the
rank-k approximation $tilde(A)^((k))$ (mml eq 4.92), whose error is exactly
the tail: the dropped terms are themselves an SVD, so $norm(A - tilde(A)^((k)))_2
= sigma_(k+1)$ in the spectral norm, the largest singular value (mml
Definition 4.23, Theorem 4.24). Eckart-Young makes the truncation optimal,
quoted: the rank-k SVD truncation is the argmin of $norm(A - B)_2$ over all
matrices $B$ of rank $k$ (mml Theorem 4.25). The same tail controls the
Frobenius norm, $norm(A - tilde(A)^((k)))_F = sqrt(sum_(i > k) sigma_i^2)$,
and $norm(A)_F = sqrt(sum_i sigma_i^2)$ is the whole spectrum in one
number.

The dry run: the fixture is the mml Example 4.14 movie ratings matrix,
4 movies as rows, 3 viewers as columns, $A = mat(5, 4, 1; 5, 5, 0; 0, 0,
5; 1, 0, 4)$ with singular values $9.6438, 6.3639, 0.7056$.

+ Rank-1 reconstruction $sigma_1 u_1 v_1^top$ puts 4.7673 in the top-left
  cell where $A$ has 5, science fiction captured, everything else smeared.
+ Rank-2 reconstruction (mml eq 4.102) repairs row 1 to $4.7801, 4.2419,
  1.0244$ against the true $5, 4, 1$.
+ Errors: rank 1 misses by $sqrt(6.3639^2 + 0.7056^2) = 6.4029$ in
  Frobenius, rank 2 misses by exactly $sigma_3 = 0.7056$, both the direct
  residual and the tail sum agreeing to $10^(-9)$.
+ Whole-matrix scale: $norm(A)_F = sqrt(9.6438^2 + 6.3639^2 + 0.7056^2) =
  11.5758$.

#listing("math/samples/src/Ch08/svd.c", first: 102, last: 156, caption: [svd.c, rank-1 and rank-2 reconstructions with frobenius errors checked against the sigma tail])

#diagram([singular values of the ratings matrix, the rank-2 tail is one small bar], length: 13pt, {
  // baseline
  cdraw.line((1.0, 0.8), (13.4, 0.8), stroke: luma(100), mark: (end: ">"))
  // bars, heights 0.42 per unit of sigma
  cdraw.rect((1.6, 0.8), (4.0, 4.85), fill: luma(205), stroke: luma(100))
  cdraw.rect((5.4, 0.8), (7.8, 3.47), fill: luma(235), stroke: luma(100))
  cdraw.rect((9.2, 0.8), (11.6, 1.10), fill: luma(235), stroke: luma(100))
  cdraw.content((2.8, 5.1), [sigma1 9.6438], size: 6pt)
  cdraw.content((6.6, 3.7), [sigma2 6.3639], size: 6pt)
  cdraw.content((10.4, 1.4), [sigma3 0.7056], size: 6pt)
  cdraw.line((9.2, 1.10), (11.6, 1.10), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((10.4, 0.4), [rank-2 error lives here], size: 6pt)
})

Principal component analysis is this machinery turned around on data. Take
the centered ratings, subtract each viewer's mean, here $(2.75, 2.25,
2.5)$, form the covariance $1\/3 C^top C$, and eigendecompose it. Its
eigenvectors are exactly the right-singular vectors of $C$ and its
eigenvalues are $sigma_i^2 \/ 3$: the generator pins $19.2612 = 7.6016^2
\/3$ for the top axis, a clean $1\/6$ from $sigma_2 = 1\/sqrt(2)$ in the
middle, and the projections of the data onto the first axis carry
$19.2612\/(19.2612 + 0.1667 + 0.0721) = 0.9878$ of the variance. The
ratings matrix is effectively two-dimensional, one science fiction axis
and one French art house axis, exactly the reading mml draws from the same
numbers in Example 4.15. Chapter #xref-to("math", "statistics") builds the
full inference story on this teaser.

#listing("math/samples/src/Ch08/svd.c", first: 158, last: 215, caption: [svd.c, mean-center, covariance eigen check, projected variance and explained ratio])

The two-number play: 6.4029 down to 0.7056, the Frobenius error dropping by
a factor of 9 when the second singular pair is kept, and 0.9878, the share
of variance one axis of the centered ratings already explains.

A map of the whole chapter is mml Section 4.7, the matrix phylogeny of
Figure 4.13: every rectangular matrix has the SVD, square invertible
matrices are marked by $det != 0$, non-defective ones diagonalize,
symmetric ones diagonalize orthogonally, positive definite ones own a
unique Cholesky factor, and orthogonal matrices are the rotations sitting
inside all of it. Determinant and trace, the two scalars of section 1,
label the same territory from above.

Calculus begins next in chapter #xref-to("math", "univariate"), and every
derivative there is a linear map whose decompositions are these.

sources: mml-book draft 2024-01-15, Deisenroth, Faisal, Ong, ch 4 matrix
decompositions, determinant and trace [printed pp 99-105, pdf pp 105-111],
eigenvalues and eigenvectors [printed pp 105-114, pdf pp 111-120], cholesky
decomposition [printed pp 114-115, pdf pp 120-121], eigendecomposition and
diagonalization [printed pp 115-119, pdf pp 121-125], singular value
decomposition [printed pp 119-129, pdf pp 125-135], matrix approximation
[printed pp 129-133, pdf pp 135-139], matrix phylogeny [printed pp 133-135,
pdf pp 139-141], plus ch 2 Example 2.3 [printed p 23, pdf p 29] and ch 3
Gram-Schmidt [printed pp 89-90, pdf pp 95-96] and Definition 3.4 [printed
p 74, pdf p 80], read from the verified anchor sheet and cross checked
against the pdf pages on 2026-09-21, our own words and code throughout.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/math/samples/src -Chapter Ch08`, 52 checks in chapter 08
of the math suite, zero skipped.
