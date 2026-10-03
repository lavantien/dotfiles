#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= inner products and projections

Chapter #xref-to("math", "vectors") measured vectors with norms and chapter
#xref-to("math", "matrices") moved them with matrices. This chapter installs
the machine that generates both: the inner product, a symmetric bilinear
positive definite form whose single definition produces lengths, distances,
angles, orthogonal bases, projections, and the least squares solution of an
overdetermined system. Six moves: the axioms with the dot product as one
instance among many, Cauchy-Schwarz and the angle it licenses, Gram-Schmidt
with the orthogonal complement, projections as closest points, the same
theory over functions where sums become integrals, and rotations as the maps
that preserve the whole structure. Every behavioral claim below is one of
the 53 checks in the 4 samples of chapter 7 or a sentence quoted from
mml-book draft 2024-01-15. The dsa book's linalg chapter runs elimination as
an algorithm, this chapter only borrows its solved systems to build geometry.

== the inner product

A norm can say how long a vector is but not what an angle is. The missing
structure is a function of two vectors. mml definition 3.3 [printed p 73 /
pdf p 79]: a bilinear mapping $Omega : V times V -> RR$ that is symmetric,
$Omega(x, y) = Omega(y, x)$, and positive definite, $Omega(x, x) > 0$ for
every $x != 0$ and $Omega(0, 0) = 0$, is an inner product, written
$lr(⟨dot, dot⟩)$. The pair $(V, lr(⟨dot, dot⟩))$ is an inner product
space.

The dot product of chapter 5 is one instance,
$x^top y = sum_(i=1)^n x_i y_i$ (mml eq 3.5) [printed p 72 / pdf p 78], and
a space carrying it is called Euclidean. It is not the only one. mml example
3.5 [printed p 75 / pdf p 81] weights the coordinates instead:

$ lr(⟨x, y⟩) := x^top mat(1, -1/2; -1/2, 1) y = x_1 y_1 - 1/2 (x_1 y_2 + x_2 y_1) + x_2 y_2 $

The dry run: the vector (1,1) under both products.

+ Dot product: $lr(⟨x, x⟩) = 1 + 1 = 2$, so the length is
  $sqrt(2) = 1.414214$.
+ Weighted product: $lr(⟨x, x⟩) = 1 - 1/2 (1 + 1) + 1 = 1$, so the length
  is 1.

Same vector, two lengths. mml theorem 3.5 [printed p 74 / pdf p 80] makes
the correspondence exact: for a finite dimensional space with an ordered
basis, every inner product is $lr(⟨x, y⟩) = hat(x)^top A hat(y)$ for a
symmetric positive definite matrix $A$ and conversely, so picking an inner
product is picking a metric matrix. The sample pins the three axioms on
fixed vectors, $x = (1,2,2)$, $y = (2,1,0)$, $z = (0,3,1)$, with exact
integer arithmetic.

#listing("math/samples/src/Ch07/inner.c", first: 47, last: 74, caption: [inner.c, the three axioms and the induced norm pinned on fixed vectors])

#diagram([three axioms feed one inner product, which generates the geometry], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0, 3.6, 4.0, [bilinear])
  box(0, 2.2, 4.0, [symmetric])
  box(0, 0.8, 4.0, [positive definite])
  cdraw.line((4.0, 4.1), (5.7, 3.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((4.0, 2.7), (5.7, 2.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((4.0, 1.3), (5.7, 2.4), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((5.7, 1.9), (9.9, 3.5), fill: luma(205), stroke: luma(60), radius: 0.02)
  cdraw.content((7.8, 2.7), [$lr(⟨dot, dot⟩)$ inner product], size: 6.5pt)
  cdraw.line((9.9, 2.7), (11.2, 2.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((13.4, 2.7), [norm, angle, projection], size: 6pt)
})

#callout("pitfall", "ONLY TWO VECTOR PRODUCTS EXIST", [For column vectors exactly two multiplications are defined, the outer product $a b^top in RR^(n times n)$ and the inner product $a^top b in RR$, a remark mml attaches to its vector space definition [printed pp 37-38 / pdf pp 43-44]. In C there is no such restriction: the samples always contract with an explicit loop over $a[i] * b[i]$, because a componentwise product of two vectors is the Hadamard product, a different object that never produces a scalar.])

== lengths, distances, angles

An inner product induces a norm, $norm(x) := sqrt(lr(⟨x, x⟩))$ (mml eq
3.16) [printed p 75 / pdf p 81], and the norm induces a distance, $d(x, y) :=
norm(x - y)$ (mml definition 3.6) [printed p 75 / pdf p 81], called
Euclidean when the product is the dot product. The converse fails: the
Manhattan norm of chapter 5 is a norm no inner product induces [mml,
printed p 75 / pdf p 81]. The bridge from products to angles is one
inequality.

Cauchy-Schwarz (mml eq 3.17) [printed p 75 / pdf p 81]: for an inner product
space with induced norm,

$ |lr(⟨x, y⟩)| <= norm(x) norm(y) $

Equality holds exactly for collinear vectors. Both sides are pinned:
$x = (1,2,2)$ against $y = (2,1,0)$ gives the strict case $|x^top y| = 4$
versus $3 sqrt(5) = 6.708204$, while the collinear pair $(1,2,2)$, $(2,4,4)$
hits $18 = 3 dot 6$ exactly. Because the quotient is trapped in $[-1, 1]$,
the angle is well defined (mml eq 3.25) [printed p 76 / pdf p 82]:

$ cos omega = (lr(⟨x, y⟩))/(norm(x) norm(y)), quad omega in [0, pi] $

The dry run: mml example 3.6 [printed p 77 / pdf p 83], $x = (1,1)$,
$y = (1,2)$.

+ The product is 3, the norms are $sqrt(2)$ and $sqrt(5)$.
+ $cos omega = 3/sqrt(10) = 0.948683$, so $omega = 0.321751$ rad, printed as
  18.434949 degrees, which the book rounds to 0.32 rad at about 18 degree.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*pair*], [*metric*], [*cos omega*], [*omega*]),
  [$(1,1), (1,2)$], [dot], [$0.948683$], [$0.321751$ rad],
  [$(1,1), (-1,1)$], [dot], [$0$], [[$pi/2$ = 1.570796 rad]],
  [$(1,1), (-1,1)$], [diag(2,1)], [$-1/3$], [$1.910633$ rad],
)

Orthogonality (mml definition 3.7) [printed p 77 / pdf p 83]: $x bot y$ iff
$lr(⟨x, y⟩) = 0$, and if both are unit vectors they are orthonormal. The
zero vector is orthogonal to everything. The table's last row is the
two-number play: $(1,1)$ and $(-1,1)$ sit at 90 degrees under the dot
product, but under $lr(⟨x, y⟩) = x^top mat(2, 0; 0, 1) y$ (mml example
3.7) [printed pp 77-78 / pdf pp 83-84] the cosine becomes $-1/3$ and the
angle opens to $109.471221$ degrees. Orthogonality is a property of the
pair and the metric together, never of the pair alone.

#listing("math/samples/src/Ch07/inner.c", first: 76, last: 111, caption: [inner.c, Cauchy-Schwarz on both sides, the angle, and the metric that moves it])

#diagram([cos on [0, pi] is bijective, so every cosine is one angle], length: 13pt, {
  cdraw.line((0.7, 0.7), (11.4, 0.7), stroke: luma(100))
  cdraw.line((1, 0.4), (1, 4.9), stroke: luma(100))
  cdraw.content((1.3, 0.2), [0], size: 6pt)
  cdraw.content((6, 0.2), [pi/2], size: 6pt)
  cdraw.content((10.9, 0.2), [pi], size: 6pt)
  cdraw.content((0.55, 4.4), [1], size: 6pt)
  cdraw.content((0.55, 2.7), [0], size: 6pt)
  cdraw.content((0.5, 1.15), [-1], size: 6pt)
  // cos curve through 5 hand-plotted points, value v at height 2.7 + 1.7 v
  cdraw.line((1, 4.40), (3.5, 3.90), stroke: luma(60))
  cdraw.line((3.5, 3.90), (6, 2.70), stroke: luma(60))
  cdraw.line((6, 2.70), (8.5, 1.50), stroke: luma(60))
  cdraw.line((8.5, 1.50), (11, 1.00), stroke: luma(60))
  // omega = 0.321751 lands at cos = 0.948683, height 4.31
  cdraw.circle((2.02, 4.31), radius: 0.07, fill: luma(60))
  cdraw.line((2.02, 4.31), (2.02, 0.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((3.7, 4.5), [omega = 0.322], size: 6pt)
  cdraw.content((6.9, 4.2), [3/sqrt(10) = 0.949], size: 6pt)
})

== orthonormal bases and the orthogonal complement

A basis is orthonormal (mml definition 3.9) [printed p 79 / pdf p 85] when
$lr(⟨b_i, b_j⟩) = 0$ for $i != j$ and $lr(⟨b_i, b_i⟩) = 1$ for all
$i$. Orthonormality is what makes coefficient reading trivial: for an
orthonormal basis matrix $B$ the projection needs no inverse, $pi_U (x) = B
B^top x$ with $lambda = B^top x$ (mml eqs 3.65-3.66) [printed p 88 / pdf
p 94].

Gram-Schmidt builds such a basis from any basis (mml eqs 3.67-3.68)
[printed p 89 / pdf p 95]:

$ u_1 := b_1, quad u_k := b_k - pi_(lr("span"[u_1, ..., u_(k-1)]))(b_k), quad k = 2, ..., n $

Each new vector sheds its projection onto the directions already built. In
code, projecting $u$ onto a single direction $w$ costs one quotient,
$(lr(⟨u, w⟩) / lr(⟨w, w⟩)) w$, and if the inputs are rational the
whole run stays rational: no square root appears before normalization, so
the sample computes in exact fractions.

#listing("math/samples/src/Ch07/gramschmidt.c", first: 83, last: 105, caption: [gramschmidt.c, the rational inner product and the two Gram-Schmidt loops])

The dry run: the basis $(1,0,1)$, $(1,1,1)$, $(0,1,2)$ of $RR^3$.

+ $u_1 = (1,0,1)$ passes through, $lr(⟨u_1, u_1⟩) = 2$.
+ $lr(⟨b_2, u_1⟩) = 2$ over 2 subtracts one copy: $u_2 = (1,1,1) - (1,0,1)
  = (0,1,0)$.
+ The third vector first pays $2/2$ against $u_1$, landing $(-1,1,1)$, then
  $1/1$ against $u_2$: $u_3 = (-1,0,1)$, with $lr(⟨u_3, u_3⟩) = 2$.

All three outputs are integer vectors, all three cross products are exactly
0, and the coordinate loop rebuilds every input from the $u$ basis. mml
example 3.12 [printed pp 89-90 / pdf pp 95-96] runs the same subtraction on
$(2,0)$, $(1,1)$ and lands $(2,0)$, $(0,1)$.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*k*], [*b_k*], [*u_k*], [*$lr(⟨u_k, u_k⟩)$*]),
  [1], [$(1,0,1)$], [$(1,0,1)$], [2],
  [2], [$(1,1,1)$], [$(0,1,0)$], [1],
  [3], [$(0,1,2)$], [$(-1,0,1)$], [2],
)

The orthogonal complement (mml section 3.6) [printed pp 79-80 / pdf pp
85-86]: for an $M$ dimensional subspace $U$ of a $D$ dimensional $V$, the
complement $U^bot$ is the $(D - M)$ dimensional subspace of vectors
orthogonal to every vector of $U$, $U ∩ U^bot = {0}$, and every $x in V$
splits uniquely (mml eq 3.36):

$ x = sum_(m=1)^M lambda_m b_m + sum_(j=1)^(D-M) psi_j b_j^bot $

The dry run: the line $U = "span"[(1,2,2)]$ in $RR^3$, so $M = 1$ and the
complement is a 2 dimensional plane.

+ Two seeds orthogonal to the line: $(2,-1,0)$ and $(2,0,-1)$.
+ One Gram-Schmidt step against the first: $(2,0,-1) - 4/5 (2,-1,0) =
  (2/5, 4/5, -1)$, and 5 times that is the integer $(2,4,-5)$.
+ The three vectors $(1,2,2)$, $(2,-1,0)$, $(2,4,-5)$ are pairwise
  orthogonal, an orthogonal basis of $RR^3$ split as 1 + 2 = 3 dimensions.

A plane's complement is even shorter. The residual $(1,-2,1)$ of the next
section's projection spans the complement of $"span"[(1,1,1),(0,1,2)]$,
exactly the normal direction mml draws for a plane in $RR^3$.

#listing("math/samples/src/Ch07/gramschmidt.c", first: 188, last: 208, caption: [gramschmidt.c, the complement of a line as one exact subtraction step])

#diagram([gram-schmidt as subtraction, the shadow leaves and the residual stays], length: 13pt, {
  cdraw.line((0.8, 0.8), (7.0, 0.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.0, 0.8), [$u_1 = (2,0)$], size: 6pt)
  cdraw.line((0.8, 0.8), (2.6, 2.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.4, 2.9), [$b_2 = (1,1)$], size: 6pt)
  cdraw.rect((2.46, 0.66), (2.74, 0.94), fill: luma(205), stroke: luma(100))
  cdraw.content((5.2, 1.6), [$pi_(u_1)(b_2) = (1,0)$], size: 6pt)
  cdraw.line((2.6, 2.6), (2.6, 0.8), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((2.6, 0.2), [$u_2 = (0,1)$], size: 6pt)
})

#callout("note", "GRAM-SCHMIDT KEEPS THE SPAN", [The algorithm only subtracts projections, which are themselves combinations of the vectors built so far, so $"span"[b_1, ..., b_k] = "span"[u_1, ..., u_k]$ at every step $k$. mml states the span equality alongside its equations 3.67-3.68 and the samples pin it by rebuilding each input from the computed $u$ coordinates in exact arithmetic. The payoff arrives in the next section: an orthonormal basis turns projection into a plain product with $B^top$.])

== orthogonal projections

A projection (mml definition 3.10) [printed p 82 / pdf p 88] is a linear
mapping $pi : V -> U$ onto a subspace with $pi^2 = pi$, idempotence as the
defining property. The orthogonal projection of $x$ onto $U$ is the point
of $U$ closest to $x$, and its residual $x - pi_U (x)$ is orthogonal to
$U$.

A line first. With $U = "span"[b]$ and $pi_U (x) = lambda b$, the
orthogonality condition $lr(⟨x - lambda b, b⟩) = 0$ solves for the
coefficient (mml eqs 3.39-3.46) [printed pp 83-85 / pdf pp 89-91]:

$ lambda = (lr(⟨x, b⟩))/(norm(b)^2), quad P_pi = (b b^top)/(b^top b) $

The dry run: mml example 3.10 [printed p 85 / pdf p 91], $b = (1,2,2)$,
$x = (1,1,1)$.

+ $lambda = 5/9$ and $pi_U (x) = (5/9, 10/9, 10/9)$, with the rank 1
  projector $P_pi = 1/9 mat(1, 2, 2; 2, 4, 4; 2, 4, 4)$.
+ The residual $(4/9, -1/9, -1/9)$ is orthogonal to $b$ and carries squared
  norm $2/9$.

A subspace of dimension $m$ needs the normal equations. With $B = [b_1,
dots, b_m]$ (mml eqs 3.55-3.59) [printed pp 85-87 / pdf pp 91-93]:

$ B^top (x - B lambda) = 0 <==> B^top B lambda = B^top x <==> lambda = (B^top B)^(-1) B^top x $

The dry run: mml example 3.11 [printed pp 87-88 / pdf pp 93-94], $U =
"span"[(1,1,1), (0,1,2)]$, $x = (6,0,0)$.

+ $B^top B = mat(3, 3; 3, 5)$ with determinant 6, and $B^top x = (6, 0)$, so
  $lambda = (5, -3)$.
+ $pi_U (x) = 5 (1,1,1) - 3 (0,1,2) = (5, 2, -1)$. The residual $(1,-2,1)$
  is orthogonal to both columns and has norm $sqrt(6) = 2.449490$.
+ $P_pi = 1/6 mat(5, 2, -1; 2, 2, 2; -1, 2, 5)$, and $P_pi P_pi = P_pi$
  holds exactly in rational arithmetic.

#listing("math/samples/src/Ch07/proj.c", first: 58, last: 94, caption: [proj.c, the normal equations, the closest point, and the projection matrix route])

Two routes, two coefficient vectors, one point. The normal equations return
$lambda = (5, -3)$. The Gram-Schmidt basis of the previous section, $u_1 =
(1,1,1)$ and $u_2 = (-1,0,1)$, returns the orthogonal coordinates
$(lr(⟨x, u_j⟩))/(lr(⟨u_j, u_j⟩)) = (2, -3)$, and $2 u_1 - 3 u_2 =
(5, 2, -1)$ again, with no inverse anywhere.

#listing("math/samples/src/Ch07/proj.c", first: 96, last: 124, caption: [proj.c, the inverse-free route and the closest point walk along U])

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*route*], [*coefficients*], [*pi_U (x)*]),
  [normal equations], [$(5, -3)$], [$(5, 2, -1)$],
  [orthogonal basis], [$(2, -3)$], [$(5, 2, -1)$],
  [projection matrix], [], [$(5, 2, -1)$],
)

The closest point property is pinned by walking: from $x = (6,0,0)$ to any
other point of $U$, say $pi_U (x) + t (1,1,1)$ for $t$ in $(-1, -1/2, 1/2,
1)$, the squared distance climbs 6 to 6.75 to 9 while the projection holds
6. For affine subspaces the same computation applies after subtracting the
support point, $pi_L (x) = x_0 + pi_U (x - x_0)$ (mml eq 3.72) [printed
p 90 / pdf p 96].

Least squares falls out. When $A lambda = y$ has no solution, projecting
$y$ onto the column space of $A$ gives the closest attainable right hand
side and the coefficients of that projection are the least squares
solution (mml [printed p 88 / pdf p 94]).

The dry run: fit $y = a + c t$ through $(0,1)$, $(1,3)$, $(2,3)$.

+ The design matrix has columns $(1,1,1)$ and $(0,1,2)$, the same $B$ as
  example 3.11, so the same normal equations run with $A^top y = (7, 9)$.
+ $lambda = (4/3, 1)$, the line $y = 4/3 + t$.
+ Residuals $(-1/3, 2/3, -1/3)$, exactly orthogonal to both columns, with
  squared norm $2/3$ and norm $0.816497$.

#listing("math/samples/src/Ch07/proj.c", first: 126, last: 147, caption: [proj.c, an overdetermined fit solved as a projection])

#diagram([the projection is the foot of the perpendicular, everything else on U is farther], length: 13pt, {
  cdraw.rect((0.8, 0.4), (9.0, 2.0), fill: luma(245), stroke: luma(140))
  cdraw.content((2.1, 1.6), [subspace U], size: 6pt)
  cdraw.circle((5.4, 5.6), radius: 0.07, fill: luma(60))
  cdraw.content((5.4, 5.95), [x = (6,0,0)], size: 6pt)
  cdraw.rect((4.7, 1.16), (4.98, 1.44), fill: luma(205), stroke: luma(100))
  cdraw.content((4.84, 0.85), [$pi_U (x) = (5,2,-1)$], size: 6pt)
  cdraw.line((5.4, 5.6), (4.9, 1.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((2.2, 4.6), [residual, norm $sqrt(6)$], size: 6pt)
  cdraw.circle((7.6, 1.3), radius: 0.07, fill: luma(140))
  cdraw.line((5.4, 5.6), (7.55, 1.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((11.6, 3.4), [any other point, norm 3], size: 6pt)
})

#callout("warning", "DO NOT INVERT IN PRACTICE", [mml closes its projection section with two numerical caveats: computing the pseudo-inverse $(B^top B)^(-1) B^top$ is discouraged for precision reasons, and practitioners add a jitter term $epsilon I$ to $B^top B$ for stability, a ridge that also falls out of Bayesian inference [printed pp 87-88 / pdf pp 93-94]. The samples invert a 2 by 2 matrix with determinant 6 because the pedagogy is exact fractions, while chapter #xref-to("math", "decomp") handles the factorizations real solvers use.])

== inner products of functions

Nothing in the definition used finiteness. For functions $u, v$ on a
finite interval (mml eq 3.37) [printed p 80 / pdf p 86]:

$ lr(⟨u, v⟩) := integral_a^b u(x) v(x) dif x $

Symmetry and bilinearity are the linearity of the integral, positive
definiteness holds because a nonnegative continuous function integrates to
0 only by being 0, and every construction of this chapter carries over:
norms, Cauchy-Schwarz, orthogonality, projection. Chapter
#xref-to("math", "quadrature") owns quadrature itself, this sample only
borrows composite Simpson with 4000 panels as its measuring device.

The dry run: mml example 3.9 [printed p 81 / pdf p 87], $u = sin$, $v = cos$
on $[-pi, pi]$. The product $sin(x) cos(x)$ is odd, so the integral is 0
and sine is orthogonal to cosine. Measured: 1.1e-16. The wider family is
pinned the same way, ${1, cos t, cos 2t, cos 3t}$ orthogonal as a system,
$lr(⟨sin, sin⟩) = lr(⟨cos, cos⟩) = pi = 3.141593$ and $lr(⟨1, 1⟩)
= 2 pi = 6.283185$.

#listing("math/samples/src/Ch07/funcinner.c", first: 43, last: 58, caption: [funcinner.c, the integral inner product and one projection coefficient, both by Simpson])

Projection now runs in infinitely many dimensions. The sine modes are
mutually orthogonal, so projecting $f(x) = x$ onto the first three modes
uses the inverse-free formula of the previous section, one coefficient per
mode, and integration by parts gives the closed form:

$ a_k = (lr(⟨f, sin(k dot)⟩))/(lr(⟨sin(k dot), sin(k dot)⟩)) = (2 (-1)^(k+1))/k $

The dry run: $a_1 = 2$, $a_2 = -1$, $a_3 = 2/3$, measured by Simpson as
2.000000000, -1.000000000 and 0.666666667. The 3 mode approximation $2 sin
t - sin 2t + 2/3 sin 3t$ tracks the line closely mid interval and misses at
the endpoints, where the periodic extension of $x$ jumps: at $t = +- pi$
the projection returns 0 against the function's $+- 3.141593$.

#listing("math/samples/src/Ch07/funcinner.c", first: 87, last: 98, caption: [funcinner.c, the Fourier coefficients of f = x against their closed forms])

Energy accounting is the two-number play. The whole function holds
$lr(⟨f, f⟩) = 2 pi^3 / 3 = 20.670851$. One mode captures $4 pi =
12.566371$, a fraction of 0.607927. Three modes capture $(4 + 1 + 4/9) pi =
17.104227$, a fraction of 0.827456. mml remarks that projecting functions
onto the orthogonal cosine system "is the fundamental idea behind Fourier
series" [printed p 81 / pdf p 87].

#diagram([f = x against its 3 mode projection, hand-plotted at multiples of pi/4], length: 13pt, {
  cdraw.line((0.7, 3.3), (13.3, 3.3), stroke: luma(100))
  cdraw.content((1.0, 0.15), [-pi], size: 6pt)
  cdraw.content((4.0, 0.15), [-pi/2], size: 6pt)
  cdraw.content((7.0, 0.15), [0], size: 6pt)
  cdraw.content((10.0, 0.15), [pi/2], size: 6pt)
  cdraw.content((13.0, 0.15), [pi], size: 6pt)
  // f = x, solid, value v at height 3.3 + 0.8 v
  cdraw.line((1, 0.79), (2.5, 1.42), stroke: luma(60))
  cdraw.line((2.5, 1.42), (4, 2.04), stroke: luma(60))
  cdraw.line((4, 2.04), (5.5, 2.67), stroke: luma(60))
  cdraw.line((5.5, 2.67), (7, 3.30), stroke: luma(60))
  cdraw.line((7, 3.30), (8.5, 3.93), stroke: luma(60))
  cdraw.line((8.5, 3.93), (10, 4.56), stroke: luma(60))
  cdraw.line((10, 4.56), (11.5, 5.18), stroke: luma(60))
  cdraw.line((11.5, 5.18), (13, 5.81), stroke: luma(60))
  cdraw.content((8.7, 2.55), [f = x], size: 6pt)
  // 2 sin t - sin 2t + 2/3 sin 3t, dashed
  cdraw.line((1, 3.30), (2.5, 0.99), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((2.5, 0.99), (4, 2.23), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4, 2.23), (5.5, 2.59), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((5.5, 2.59), (7, 3.30), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((7, 3.30), (8.5, 4.01), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((8.5, 4.01), (10, 4.37), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((10, 4.37), (11.5, 5.61), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((11.5, 5.61), (13, 3.30), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((2.7, 0.55), [3 modes], size: 6pt)
})

#callout("pitfall", "INTEGRALS CAN DIVERGE", [mml is careful about the function inner product: limits must be finite, the product must be integrable, and "precise treatment requires measures and Hilbert spaces" beyond the book's scope [printed pp 80-81 / pdf pp 86-87]. The sample stays on safe ground, smooth products of sines, cosines and polynomials on a closed interval, where Simpson converges fast enough to pin coefficients to 12 digits.])

== rotations revisited

Chapter #xref-to("math", "trig") built the rotation matrix from the unit
circle. The inner product explains why that matrix is special. A square
matrix is orthogonal (mml definition 3.8) [printed p 78 / pdf p 84] when
its columns are orthonormal, $A A^top = I = A^top A$, so $A^(-1) = A^top$.
Then lengths and angles survive the map (mml eqs 3.31-3.32) [printed p 78 /
pdf p 84]:

$ norm(A x)_2^2 = (A x)^top (A x) = x^top A^top A x = norm(x)_2^2, quad cos omega = ((A x)^top (A y))/(norm(A x) norm(A y)) = (x^top y)/(norm(x) norm(y)) $

The dry run: $R(pi/3)$ in gramschmidt.c.

+ $R^top R = I$ to $1e-15$ and $det R = cos^2 + sin^2 = 1$.
+ $lr(⟨(1,2), (3,-1)⟩) = 1$ before the rotation and 1 after, and
  $norm(R (1,1)) = sqrt(2)$.

mml states the conclusion directly: "orthogonal matrices define
transformations that are rotations (with the possibility of flips)"
[printed p 78 / pdf p 84]. Section 3.9 assembles $R(theta) = mat(cos theta,
-sin theta; sin theta, cos theta)$ (mml eq 3.76) [printed p 92 / pdf p 98]
from the images of the standard basis vectors, which is the
orthonormal-columns condition in action, and lists the group properties:
rotations preserve distances and angles, and they commute only in 2
dimensions [mml section 3.9.4, printed p 94 / pdf p 100]. The two-number
play is the pair of images: $e_1$ moves to $(0.5, 0.866)$ and $e_2$ to
$(-0.866, 0.5)$, both still unit, still at a right angle, determinant +1
where a reflection would carry -1.

#listing("math/samples/src/Ch07/gramschmidt.c", first: 220, last: 248, caption: [gramschmidt.c, the rotation matrix certified orthogonal, determinant 1, inner product preserved])

#diagram([rotation by pi/3, the basis stays orthonormal], length: 13pt, {
  // unit circle through 12 points
  cdraw.line((6.5, 3.3), (6.165, 4.55), stroke: luma(140))
  cdraw.line((6.165, 4.55), (5.25, 5.465), stroke: luma(140))
  cdraw.line((5.25, 5.465), (4, 5.8), stroke: luma(140))
  cdraw.line((4, 5.8), (2.75, 5.465), stroke: luma(140))
  cdraw.line((2.75, 5.465), (1.835, 4.55), stroke: luma(140))
  cdraw.line((1.835, 4.55), (1.5, 3.3), stroke: luma(140))
  cdraw.line((1.5, 3.3), (1.835, 2.05), stroke: luma(140))
  cdraw.line((1.835, 2.05), (2.75, 1.135), stroke: luma(140))
  cdraw.line((2.75, 1.135), (4, 0.8), stroke: luma(140))
  cdraw.line((4, 0.8), (5.25, 1.135), stroke: luma(140))
  cdraw.line((5.25, 1.135), (6.165, 2.05), stroke: luma(140))
  cdraw.line((6.165, 2.05), (6.5, 3.3), stroke: luma(140))
  cdraw.line((4, 3.3), (6.5, 3.3), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.9, 3.3), [$e_1$], size: 6pt)
  cdraw.line((4, 3.3), (4, 5.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.6, 6.3), [$e_2$], size: 6pt)
  cdraw.line((4, 3.3), (5.25, 5.465), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.6, 6.0), [$R e_1 = (0.5, 0.866)$], size: 6pt)
  cdraw.line((4, 3.3), (1.835, 4.55), stroke: luma(60), mark: (end: ">"))
  cdraw.content((0.9, 4.8), [$R e_2$], size: 6pt)
  cdraw.line((4.9, 3.3), (4.79, 3.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.79, 3.75), (4.5, 4.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.2, 0.9), [det $R = +1$], size: 6pt)
})

The next chapter #xref-to("math", "decomp") breaks matrices into products of
simpler ones, and its central actors, the orthogonal factors of the
eigendecomposition and the singular value decomposition, are exactly the
maps this chapter certified as inner product preservers.

sources: mml-book draft 2024-01-15, ch 3 analytic geometry, sections 3.1 to
3.9, definitions 3.1 to 3.11, examples 3.5 to 3.12 and equations 3.5 to
3.76, worked from the verified anchor sheet ref/mml/anchors-la.md (printed
pp 71-94 / pdf pp 77-100), read 2026-09-21, with chapter 2 background on
elimination and vector spaces (printed pp 27-38 / pdf pp 33-44). Expected
sample values
computed by the playground one-off playground/math-ch07/pin.py, python
fractions, run 2026-09-21. Sample behavior verified by `pwsh -NoProfile
-File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter
Ch07`, 53 checks in chapter 7 of the math suite, 4 files, zero failures.
