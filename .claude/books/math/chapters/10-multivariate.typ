#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= multivariate calculus

A function of several variables arrives in C as a function of several arguments, and its derivative arrives as a vector or a matrix rather than a scalar. This chapter builds those objects in six moves: partial derivatives as the single-variable limit already owned from #xref-to("math", "univariate"), the gradient with its orthogonality to level sets, the jacobian of a vector-valued map with the chain rule as matrix multiplication, the hessian with its definiteness test, the linearization and second-order taylor model, and the short identity list that keeps hand gradients cheap. Where #xref-to("dsa", "numerical") consumes derivatives as oracles inside search drivers, this chapter produces the derivative objects themselves. Every behavioral claim below is one of the 59 checks in the 4 samples of chapter 10 or a sentence from the mml-book draft 2024-01-15 anchor sheet read 2026-09-21.

== partial derivatives as limits

Definition first. For $f : RR^n -> RR$ the partial derivative with respect to $x_1$ holds every other variable fixed and runs the ordinary difference quotient, mml definition 5.5 eq 5.39 [printed p 146 / pdf p 152]:

$ (partial f)/(partial x_1) = lim_(h -> 0) (f(x_1 + h, x_2, ..., x_n) - f(x_1, x_2, ..., x_n)) / h $

Each partial is a derivative with respect to a scalar, so the rules from the univariate chapter transfer one variable at a time. The univariate chain rule even works inside a partial: for $f(x, y) = (x + 2y^3)^2$ the mml example 5.6 [printed pp 146-147 / pdf pp 152-153] reads off $(partial f)/(partial x) = 2(x + 2y^3)$ and $(partial f)/(partial y) = 12(x + 2y^3) y^2$. The worked function for the checks is the mml example 5.7 polynomial [printed p 147 / pdf p 153], $f(x_1, x_2) = x_1^2 x_2 + x_1 x_2^3$, whose analytic partials are $2 x_1 x_2 + x_2^3$ and $x_1^2 + 3 x_1 x_2^2$.

The dry run: pin $x_2 = 3$ and the surface collapses to the slice $g(x) = 3x^2 + 27x$, an ordinary parabola in one variable.

+ The slice derivative is $g'(x) = 6x + 27$, so $g'(2) = 39$, and the coded partial returns exactly 39.0 at $(2, 3)$.
+ The forward quotient $(f(2 + h, 3) - f(2, 3)) / h$ walks 39.02999999999821, 39.003000000008115, 39.000300000111565 as $h$ steps through $10^(-2)$, $10^(-3)$, $10^(-4)$, each value pinned to a billionth.
+ The error column 3.0e-2, 3.0e-3, 3.0e-4 drops tenfold per decade of $h$. That is the $O(h)$ truncation of the one-sided quotient, the ladder shape the univariate chapter already pinned on its own functions.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*h*], [*(f(2 + h, 3) - f(2, 3)) / h*], [*error against 39*]),
  [$10^(-2)$], [39.02999999999821], [3.0e-2],
  [$10^(-3)$], [39.003000000008115], [3.0e-3],
  [$10^(-4)$], [39.000300000111565], [3.0e-4],
)

Second derivatives arrive the same way, and the one theorem worth quoting is that differentiation order does not matter, mml eq 5.146 [printed p 164 / pdf p 170]: if $f$ is twice continuously differentiable then $(partial^2 f)/(partial x partial y) = (partial^2 f)/(partial y partial x)$. On the fixed polynomial $f_2 = x^3 y^2 + 2 x^2 y^3$ the chain x first then y gives $6x^2 y + 12 x y^2$, the chain y first then x gives the same expression, and at $(2, 1)$ both evaluate to 48, both analytically and through nested central differences at $h = 10^(-5)$.

#listing("math/samples/src/Ch10/partials.c", first: 21, last: 35, caption: [the coded function, its x2 pinned slice, and its two analytic partials in partials.c])
#listing("math/samples/src/Ch10/partials.c", first: 57, last: 70, caption: [the limit ladder with pinned quotients and the tenfold error drop in partials.c])

#diagram([the slice x2 pinned to 3 is the parabola g(x) = 3x^2 + 27x, tangent slope 39 at x = 2], length: 13pt, {
  let pt(x, g) = ((x - 0.8) * 4.4 + 0.8, (g - 20) / 90 * 4.4 + 0.8)
  // axis and the x = 2 marker
  cdraw.line((0.9, 0.8), (10.8, 0.8), stroke: luma(140))
  cdraw.line(pt(2, 20), pt(2, 66), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((6.08, 0.45), [x = 2], size: 6pt)
  cdraw.content((10.9, 0.55), [x1], size: 6pt)
  // the slice parabola, sampled at x = 1, 1.5, 2, 2.5, 3
  cdraw.line(pt(1, 30), pt(1.5, 47.25), stroke: luma(60))
  cdraw.line(pt(1.5, 47.25), pt(2, 66), stroke: luma(60))
  cdraw.line(pt(2, 66), pt(2.5, 86.25), stroke: luma(60))
  cdraw.line(pt(2.5, 86.25), pt(3, 108), stroke: luma(60))
  // canvas pins from playground/math-ch10/gen.py: curve samples
  // (1.68, 1.289), (3.88, 2.132), (6.08, 3.049), (8.28, 4.039), (10.48,
  // 5.102), tangent (3.88, 2.096) to (10.48, 4.956) through (6.08, 3.049),
  // gap arrow at x = 3 from (10.48, 4.956) to (10.48, 5.102)
  // tangent through (2, 66) with slope 39: T(x) = 66 + 39(x - 2)
  cdraw.line(pt(1.5, 46.5), pt(3, 105), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.0, 1.9), [g(x) = 3x^2 + 27x], size: 6pt)
  cdraw.content((6.2, 3.2), [tangent, slope 39], size: 6pt)
  // the true gap at x = 3 is 3(x-2)^2 = 3, drawn at scale, 0.147 canvas units
  cdraw.line((10.48, 4.9556), (10.48, 5.1022), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.62, 5.03), [gap 3(x-2)^2], size: 6pt)
  cdraw.rect((6.03, 3.00), (6.13, 3.10), fill: luma(60))
})

#callout("verify", "gradient checking", [Before trusting any coded gradient, mml remark 5.2.2 [printed p 149 / pdf p 155] compares it against central differences at $h = 10^(-4)$ with the criterion $sqrt((sum_i (d h_i - d f_i)^2) / (sum_i (d h_i + d f_i)^2)) < 10^(-6)$, where $d h_i$ is the finite-difference value and $d f_i$ the analytic one. partials.c pins both difference values, 39.00000000008674 and 58.000000020115294, and the criterion evaluates to 1.4390243727509478e-10, five orders inside the gate. The same test guards every hand gradient in the rest of the book.])

== the gradient and level sets

Collect the partials into a row and you have the gradient, mml eq 5.40 [printed p 146 / pdf p 152]:

$ nabla f = [(partial f)/(partial x_1), (partial f)/(partial x_2), dots, (partial f)/(partial x_n)] in RR^(1 times n) $

For the worked polynomial the gradient at $(2, 3)$ is the row $(39, 58)$ and at $(1, -1)$ it is $(-3, 4)$, all four numbers exact in gradient.c. The gradient answers two questions a slice cannot.

First, rate of climb in an arbitrary unit direction $bold(d)$: the directional derivative is $D_bold(d) f = nabla f dot bold(d)$, a dot product you can evaluate by hand. Second, which direction climbs fastest: by Cauchy-Schwarz $nabla f dot bold(d)$ is at most $|nabla f|$, with equality exactly when $bold(d)$ points along the gradient.

The dry run: stand at $(2, 3)$ on $f(x_1, x_2) = x_1^2 x_2 + x_1 x_2^3$ with $nabla f = (39, 58)$ and read the table.

+ Due east along $(1, 0)$ the climb rate is 39, due north along $(0, 1)$ it is 58.
+ Along the diagonal $(3, 4) / 5$ it is 69.8, and reversing the direction gives exactly -69.8.
+ Along $nabla f / |nabla f|$ it is $sqrt(4885) = 69.8927750200262$, the unique maximum, beating 69.8 and 68.53846153846155 along $(5, 12) / 13$.

#table(
  columns: (auto, auto),
  inset: 4pt,
  table.header([*unit direction*], [*directional derivative at (2, 3)*]),
  [$(1, 0)$], [39],
  [$(0, 1)$], [58],
  [$(3, 4) / 5$], [69.8],
  [$(5, 12) / 13$], [68.53846153846155],
  [$nabla f / |nabla f|$], [69.8927750200262],
)

The gradient also knows where the level sets run. On the quadratic $q(x, y) = x^2 + 4 y^2$ the level curve $q = 8$ is an ellipse through $(2, 1)$, the gradient there is $(4, 8)$, and a tangent direction of the curve at that point is $(2, -1)$. The dot product $4 dot 2 + 8 dot (-1)$ is exactly 0: the gradient is perpendicular to the level set, pointing straight out of the ellipse. gradient.c pins the same zero at a second curve point $(1.2, sqrt(1.64))$ where the tangent is $(-8y, 2x)$, and the dot vanishes again. Flip the sign and the same perpendicular points into the level set: the negative gradient is the steepest descent direction, the workhorse of #xref-to("math", "optimization").

#listing("math/samples/src/Ch10/gradient.c", first: 46, last: 59, caption: [level curve membership and gradient-tangent orthogonality pinned at two points in gradient.c])

#diagram([the ellipse x^2 + 4y^2 = 8 with grad q = (4, 8) leaving the level curve at a right angle at (2, 1)], length: 13pt, {
  let s = 1.72
  let cx = 6.0
  let cy = 3.4
  let pt(p) = (cx + p.at(0) * s, cy + p.at(1) * s)
  // the level curve, 29 hand-computed samples around the ellipse
  let ring = (
    (2.828, 0.0), (2.6, 0.557), (2.2, 0.889), (1.8, 1.091), (1.3, 1.256), (0.8, 1.356), (0.3, 1.407), (0.0, 1.414),
    (-0.3, 1.407), (-0.8, 1.356), (-1.3, 1.256), (-1.8, 1.091), (-2.2, 0.889), (-2.6, 0.557), (-2.828, 0.0),
    (-2.6, -0.557), (-2.2, -0.889), (-1.8, -1.091), (-1.3, -1.256), (-0.8, -1.356), (-0.3, -1.407), (0.0, -1.414),
    (0.3, -1.407), (0.8, -1.356), (1.3, -1.256), (1.8, -1.091), (2.2, -0.889), (2.6, -0.557),
  )
  for i in range(ring.len() - 1) {
    cdraw.line(pt(ring.at(i)), pt(ring.at(i + 1)), stroke: luma(60))
  }
  cdraw.line(pt(ring.last()), pt(ring.at(0)), stroke: luma(60))
  // the point (2, 1), the outward gradient arrow, the tangent direction
  cdraw.rect((9.39, 5.07), (9.49, 5.17), fill: luma(60))
  cdraw.content((8.6, 5.25), [(2, 1)], size: 6pt)
  cdraw.line((9.44, 5.12), (9.92, 6.08), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.9, 6.5), [grad q = (4, 8)], size: 6pt)
  cdraw.line((9.44, 5.12), (11.54, 4.07), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((9.44, 5.12), (8.39, 5.65), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((10.9, 3.6), [tangent (2, -1)], size: 6pt)
  cdraw.content((10.1, 4.85), [dot = 0], size: 6pt)
  cdraw.content((6.0, 3.4), [level q = 8], size: 6pt)
})

#callout("pitfall", "the gradient is a row", [The mml book keeps $nabla f$ as a $1 times n$ row, the numerator layout, so that the gradient of $f : RR^n -> RR^m$ generalizes to an $m times n$ matrix and the chain rule becomes plain matrix multiplication with no transposes [mml remark, printed p 147 / pdf p 153]. Treat the gradient as a column and the dimension bookkeeping flips silently. The samples store gradients as flat arrays and document each one as row or column before multiplying.])

== jacobians and the chain rule

A vector-valued map $f : RR^n -> RR^m$ stacks $m$ scalar functions, and its first derivative stacks their gradients into a matrix, mml definition 5.6 eqs 5.57-5.59 [printed p 150 / pdf p 156]:

$ bold(J) = mat((partial f_1)/(partial x_1), (partial f_1)/(partial x_2), dots, (partial f_1)/(partial x_n); dots.v, , , dots.v; (partial f_m)/(partial x_1), (partial f_m)/(partial x_2), dots, (partial f_m)/(partial x_n)) $

The entry rule is one line: $J(i, j) = (partial f_i)/(partial x_j)$. The scalar gradient of the previous section is the $m = 1$ special case, a single row. The full shape inventory, after the mml dimension summary [printed p 152 / pdf p 158]:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*map*], [*derivative object*], [*shape*]),
  [$f : RR -> RR$], [scalar], [$1 times 1$],
  [$f : RR^D -> RR$], [gradient], [$1 times D$ row],
  [$f : RR -> RR^E$], [gradient], [$E times 1$ column],
  [$f : RR^D -> RR^E$], [jacobian], [$E times D$ matrix],
)

Two fixed maps carry the section in jacobian.c.

The linear one is the mml basis change $y_1 = -2x_1 + x_2$, $y_2 = x_1 + x_2$ [eqs 5.63-5.66, printed p 151 / pdf p 157]. Its jacobian is the constant matrix $mat(-2, 1; 1, 1)$ with determinant -3, and the columns are the images $c_1 = (-2, 1)$ and $c_2 = (1, 1)$ of the standard basis. The unit square, area 1, maps to the parallelogram those columns span, area $|det J| = 3$. The same holds for $y = bold(A) x$ with any $bold(A)$: the jacobian of $bold(A) x$ is $bold(A)$ itself, mml example 5.9, and the sample pins all four entries through forward differences at $h = 10^(-4)$.

The nonlinear one is $f(x_1, x_2) = (x_1 x_2 + x_1^2, 3 x_1 - x_2^2)$ evaluated at $(2, 3)$: the analytic jacobian is $mat(7, 2; 3, -6)$ with determinant -48, and the finite-difference columns 7.000100000027487 and 1.9999999999953388 agree to a part in a billion.

The chain rule is where the row convention pays. For a composition $h(t) = f(g(t))$ with $g : RR -> RR^2$ and $f : RR^2 -> RR$, mml eqs 5.51-5.53 and example 5.10 [printed pp 148-153 / pdf pp 154-159]:

$ (d h)/(d t) = (partial f)/(partial x) (partial x)/(partial t) $

a $1 times 2$ row times a $2 times 1$ column, and the middle dimension cancels. The mml book offers the reading aid that $partial f$ shows up in the denominator of the first factor and the numerator of the second, so the dimensions match and the symbol seems to cancel, then immediately warns that this is intuition rather than mathematics since a partial derivative is not a fraction [printed p 148 / pdf p 154]. The row convention is what makes the compact matrix form legal in the first place.

The dry run: take $g(t) = (t^2, t^3)$ and $f(u, v) = u v + 2u$, so $h(t) = t^5 + 2t^2$.

+ At $t = 2$ the inner point is $g(2) = (4, 8)$ and the inner jacobian is the column $(2t, 3t^2) = (4, 12)$.
+ The outer gradient at $(4, 8)$ is the row $(v + 2, u) = (10, 4)$.
+ The product $10 dot 4 + 4 dot 12 = 88$ equals the analytic $h'(2) = 5t^4 + 4t = 88$, and a central difference of the coded $h$ pins 88.00000040007916.

#listing("math/samples/src/Ch10/jacobian.c", first: 57, last: 65, caption: [the forward-difference jacobian helper, one column per input variable, in jacobian.c])
#listing("math/samples/src/Ch10/jacobian.c", first: 135, last: 151, caption: [the two-stage composition checked as a row times a column against the analytic 88 in jacobian.c])

#diagram([the basis change matrix sends the unit square, area 1, to the column parallelogram, area 3 = |det J|], length: 13pt, {
  // shared origin vertex at (5.2, 1.4), uniform scale 2.2
  let pt(p) = (5.2 + p.at(0) * 2.2, 1.4 + p.at(1) * 2.2)
  // unit square on b1 = (1, 0), b2 = (0, 1)
  cdraw.rect(pt((0, 0)), pt((1, 1)), fill: luma(245), stroke: luma(100))
  // image parallelogram on c1 = (-2, 1), c2 = (1, 1)
  cdraw.line(pt((0, 0)), pt((-2, 1)), stroke: luma(60))
  cdraw.line(pt((-2, 1)), pt((-1, 2)), stroke: luma(60))
  cdraw.line(pt((-1, 2)), pt((1, 1)), stroke: luma(60))
  cdraw.line(pt((1, 1)), pt((0, 0)), stroke: luma(60))
  cdraw.content((6.0, 1.95), [area 1], size: 6pt)
  cdraw.content((4.1, 3.6), [area 3], size: 6pt)
  cdraw.content((6.3, 1.05), [b1], size: 6pt)
  cdraw.content((5.5, 2.5), [b2], size: 6pt)
  cdraw.content((2.7, 2.6), [c1 = (-2, 1)], size: 6pt)
  cdraw.content((6.6, 2.3), [c2 = (1, 1)], size: 6pt)
})

#callout("warning", "the area scaling is local", [For a linear map $|det bold(J)|$ scales areas exactly. For a nonlinear map the same number is the magnification in an infinitesimal neighborhood, because the jacobian approximates the nonlinear transformation locally with a linear one [mml, printed pp 151-152 / pdf pp 157-158]. The pinned determinant -48 of the nonlinear map at $(2, 3)$ is that local factor at that point only, and it varies from point to point. The same determinant reappears as the change of variables correction in probability and as the reparametrization trick in deep network samplers [mml, printed p 152 / pdf p 158].])

== the hessian and curvature

Why collect second derivatives at all: Newton's method for optimization needs them, and so does any multivariate taylor model beyond first order, the two motivations the mml sec 5.7 opening names [printed p 164 / pdf p 170]. Second derivatives collect into a matrix too. For $f : RR^n -> RR$ the hessian is the $n times n$ matrix of all second-order partials, mml eq 5.147 [printed p 164 / pdf p 170], and the mixed-partials equality of the first section makes it symmetric whenever $f$ is twice continuously differentiable. The hessian measures the curvature of $f$ locally around the point of evaluation. For a vector field $f : RR^n -> RR^m$ the same collection is an $m times n times n$ tensor, one hessian per output component, mml remark [printed p 165 / pdf p 171], and the samples stay with scalar $f$ where the matrix picture holds.

The worked function from here to the end of the chapter is the mml example 5.15 cubic [printed pp 167-169 / pdf pp 173-175]:

$ F(x, y) = x^2 + 2 x y + y^3, quad H(x, y) = mat(2, 2; 2, 6y), quad H(1, 2) = mat(2, 2; 2, 12) $

The dry run: classify four fixed $2 times 2$ matrices with the sylvester test and confirm each verdict against eigenvalues, the machinery of #xref-to("math", "decomp").

+ The $H(1, 2)$ above has determinant 20 and trace 14, so both eigenvalues are positive, and the closed forms $(tr plus.minus sqrt(tr^2 - 4 det)) / 2$ give 12.385164807134505 and 1.6148351928654963, which is $7 plus.minus sqrt(29)$. Positive definite: a bowl.
+ $mat(2, 4; 4, 2)$ has determinant -12 and eigenvalues 6 and -2 of opposite sign. Indefinite: a saddle.
+ $mat(-4, 2; 2, -4)$ has determinant 12, negative diagonal, eigenvalues -2 and -6. Negative definite: a dome.
+ $mat(4, 4; 4, 4)$ has determinant 0 and eigenvalues 8 and 0. Semidefinite with a flat direction.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*matrix*], [*det*], [*eigenvalues*], [*class*]),
  [$mat(2, 2; 2, 12)$], [20], [12.385, 1.615], [bowl],
  [$mat(2, 4; 4, 2)$], [-12], [6, -2], [saddle],
  [$mat(-4, 2; 2, -4)$], [12], [-2, -6], [dome],
  [$mat(4, 4; 4, 4)$], [0], [8, 0], [flat],
)

jacobian.c codes the sylvester classifier and the closed-form eigenvalues side by side, pins every determinant and eigenvalue above, and asserts the two routes agree on all four verdicts.

#listing("math/samples/src/Ch10/jacobian.c", first: 67, last: 88, caption: [the sylvester classifier and the closed-form 2x2 eigenvalues cross-checking each other in jacobian.c])

#diagram([definiteness of a 2x2 hessian read off det and the diagonal, each verdict confirmed by eigenvalues], length: 13pt, {
  let box(x, y, w, h) = cdraw.rect((x, y), (x + w, y + h), fill: luma(235), radius: 0.02)
  let leaf(x, l1, l2) = {
    box(x, 3.0, 3.2, 1.6)
    cdraw.content((x + 1.6, 4.15), l1, size: 6pt)
    cdraw.content((x + 1.6, 3.55), l2, size: 6pt)
  }
  box(5.9, 6.0, 3.6, 1.0)
  cdraw.content((7.7, 6.5), [sign of det and H00], size: 6pt)
  for tipx in (2.0, 5.8, 9.6, 13.4) {
    cdraw.line((7.7, 6.0), (tipx, 4.6), stroke: luma(100), mark: (end: ">"))
  }
  leaf(0.4, [det < 0], [saddle, eigs 6, -2])
  leaf(4.2, [det > 0, H00 > 0], [bowl, eigs 12.39, 1.61])
  leaf(8.0, [det > 0, H00 < 0], [dome, eigs -2, -6])
  leaf(11.8, [det = 0], [flat, eigs 8, 0])
})

#callout("note", "symmetry is a hypothesis", [The mixed-partials equality that makes the hessian symmetric needs $f$ twice continuously differentiable, mml eq 5.146 [printed p 164 / pdf p 170]. Every function in this chapter is a polynomial, so the hypothesis holds and the samples pin the symmetry directly. A function with a kink or a jump in a second derivative can break it, and with it every downstream conclusion.])

== linearization and taylor

The gradient gives the best first-order model of $f$ near a point $x_0$, mml eq 5.148 [printed p 165 / pdf p 171]:

$ f(x) approx f(x_0) + nabla f(x_0)(x - x_0) $

The model is locally accurate and degrades as you walk away from $x_0$, the behavior the mml Figure 5.12 discussion pins on its own example [printed p 165 / pdf p 171]. Everything below quantifies that degradation: first order dies as $|delta|^2$, second order as $|delta|^3$.

The taylor series stacks higher-order corrections on top, and the second-order term is the one that earns its keep, mml definition 5.7-5.8 and eqs 5.156-5.158 [printed p 166 / pdf p 172]. With the displacement $delta = x - x_0$ and the hessian $H(x_0)$:

$ T_2(x) = f(x_0) + nabla f(x_0) delta + 1/2 delta^top H(x_0) delta $

For the cubic $F(x, y) = x^2 + 2 x y + y^3$ at $(1, 2)$ the mml example 5.15 numbers are $F(1, 2) = 13$, $nabla F(1, 2) = (6, 14)$, and the quadratic term $1/2 delta^top H delta = d x^2 + 2 d x d y + 6 d y^2$. Because the only live third derivative of $F$ is $(partial^3 F)/(partial y^3) = 6$, the remainder is exactly $(y - 2)^3$ and the full expansion of eq 5.180 [printed p 169 / pdf p 175] reproduces the polynomial term for term:

$ F(x, y) = 13 + 6(x - 1) + 14(y - 2) + (x - 1)^2 + 2(x - 1)(y - 2) + 6(y - 2)^2 + (y - 2)^3 $

taylor.c pins that identity at three probe points to the last bit.

The series continues past second order: the k-th term multiplies the k-th total derivative, a k-dimensional tensor, against the k-fold outer product $delta^k$, so $D_x^3 f(x_0) delta^3$ is a triple sum over all third partials, mml eqs 5.153-5.155 and 5.159 [printed p 166 / pdf p 172]:

$ delta^2 = delta delta^top, quad delta^2 [i, j] = delta[i] delta[j] $

For the cubic above only one of those partials survives, which is why the remainder collapses to a single cube.

The dry run: walk the ray $(1, 2) + t (0.1, 0.1)$ and watch what each order of model costs in error.

+ The linear model misses $F$ by 0.09099999999999753 at $t = 1$, by 0.0009010000000007068 at $t = 0.1$, and by 9.000999998676207e-06 at $t = 0.01$.
+ Each decade of $t$ divides the linear error by about 100, ratios 0.009901098901106938 and 0.009990011097302048: quadratic shrinkage, the signature of a first-order model.
+ The second-order model at $(1.1, 2.1)$ is off by exactly $(y - 2)^3 = 0.001$, and 0.001 stays under the bound $|delta|^3 = 0.0028284271247461983$ from the third-derivative magnitude.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*t on the ray*], [*linear error*], [*ratio to previous*]),
  [1], [9.1e-2], [],
  [0.1], [9.0e-4], [0.0099],
  [0.01], [9.0e-6], [0.0100],
)

#listing("math/samples/src/Ch10/taylor.c", first: 24, last: 37, caption: [the first and second-order models with the hessian quadratic form in taylor.c])
#listing("math/samples/src/Ch10/taylor.c", first: 49, last: 71, caption: [the linearization error ladder with pinned values and pinned ratios in taylor.c])
#listing("math/samples/src/Ch10/taylor.c", first: 72, last: 101, caption: [the exact cubic remainder and its bound against |delta|^3 at three points in taylor.c])

#diagram([linearization error at t = 1, 0.1, 0.01 on a log height scale, each decade of t cutting the error by 100], length: 13pt, {
  cdraw.line((1.0, 1.2), (13.5, 1.2), stroke: luma(140))
  cdraw.rect((1.8, 1.2), (4.0, 5.5), fill: luma(205))
  cdraw.rect((5.8, 1.2), (8.0, 3.6), fill: luma(235))
  cdraw.rect((9.8, 1.2), (12.0, 1.7), fill: luma(245))
  cdraw.content((2.9, 5.8), [9.1e-2], size: 6pt)
  cdraw.content((6.9, 3.9), [9.0e-4], size: 6pt)
  cdraw.content((10.9, 2.0), [9.0e-6], size: 6pt)
  cdraw.content((2.9, 0.8), [t = 1], size: 6pt)
  cdraw.content((6.9, 0.8), [t = 0.1], size: 6pt)
  cdraw.content((10.9, 0.8), [t = 0.01], size: 6pt)
  cdraw.content((7.2, 6.5), [bar height on a log scale, error falls 100x per decade of t], size: 6pt)
})

== gradient identities that pay rent

Hand differentiation of a composition needs a small rule set, not creativity. The scalar rules of mml sec 5.2.1 [printed pp 147-148 / pdf pp 153-154] keep their shape, and the vector rules add the caveat that matrix multiplication does not commute, so the order of the factors is part of the rule: $(partial)/(partial x) f g = (partial f)/(partial x) g + f (partial g)/(partial x)$ for the product, termwise addition for the sum, and $(partial)/(partial x) g(f(x)) = (partial g)/(partial f) (partial f)/(partial x)$ for the chain, mml eqs 5.46-5.48:

$ (partial)/(partial x) f g = (partial f)/(partial x) g + f (partial g)/(partial x), quad (partial)/(partial x) (f + g) = (partial f)/(partial x) + (partial g)/(partial x) $

The dry run: the worked polynomial at $(2, 3)$ splits as $f_1 = u + v$ with $u = x_1^2 x_2$ and $v = x_1 x_2^3$.

+ Sum: $nabla u = (12, 4)$ and $nabla v = (27, 54)$, and the componentwise sum is $(39, 58)$, the pinned gradient of $f_1$ from the second section.
+ Product: $w = u v = x_1^3 x_2^4$ has $nabla w = (972, 864)$, and $nabla u dot v + u dot nabla v = (648, 216) + (324, 648)$ lands on the same pair.
+ Chain: the composition of the third section gave $(10, 4) dot (4, 12) = 88$, matching the analytic derivative to the last integer.

When the argument itself is a matrix the derivative becomes a four-dimensional tensor, $J_(i j k l) = (partial A_(i j)) / (partial B_(k l))$, mml sec 5.4 [printed pp 155-158 / pdf pp 161-164]. The practical route is the one C programmers would pick anyway: matrices form a vector space isomorphic to $R^(m n)$, so flatten by stacking columns and differentiate against the flattened argument, which turns the chain rule back into plain matrix multiplication. The worked cases are $f = A x$ against $A$, where the partial of $f_i$ with respect to row $i$ of $A$ is the row $x^top$ and zero elsewhere, eqs 5.89-5.92, and $K = R^top R$ against $R$, where $(partial K_(p q)) / (partial R_(i j))$ is $R_(i q)$, $R_(i p)$, $2 R_(i q)$, or 0 depending on which indices coincide, eqs 5.96-5.98.

For matrix arguments the same discipline produces the identities programmers actually reach for, mml sec 5.5 eqs 5.99-5.108 [printed pp 158-159 / pdf pp 164-165], after Petersen and Pedersen, the matrix cookbook, 2012: $(partial a^top x)/(partial x) = a^top$, $(partial a^top X b)/(partial X) = a b^top$, $(partial x^top B x)/(partial x) = x^top (B + B^top)$, and $(partial f(X)^(-1))/(partial X) = -f(X)^(-1) (partial f(X))/(partial X) f(X)^(-1)$. Two more carry the pattern through the trace and determinant: $(partial)/(partial X) tr(f(X)) = tr((partial f(X))/(partial X))$ and $(partial)/(partial X) det(f(X)) = det(f(X)) tr(f(X)^(-1) (partial f(X))/(partial X))$. The computational payoff is the least squares loss of mml example 5.11 [printed p 154 / pdf p 160]: for $L(theta) = norm(y - Phi theta)^2$ the chain rule through the residual collapses to $(partial L)/(partial theta) = -2 e^top Phi$, one matrix product instead of a symbolic expansion, and that single identity is where #xref-to("math", "optimization") picks up the trail with descent methods and the hessian-based newton step. #xref-to("math", "autodiff") then mechanizes the chain identity so no hand gradient is needed at all.

#listing("math/samples/src/Ch10/gradient.c", first: 85, last: 102, caption: [sum and product rules pinned against the exact gradients at (2, 3) in gradient.c])

#diagram([the three rules that keep hand gradients cheap, each pinned by a chapter 10 check], length: 13pt, {
  let box(x, y, w, h) = cdraw.rect((x, y), (x + w, y + h), fill: luma(235), radius: 0.02)
  box(5.0, 6.0, 4.4, 1.0)
  cdraw.content((7.2, 6.5), [rules for hand gradients], size: 6pt)
  for tipx in (2.7, 7.2, 11.7) {
    cdraw.line((7.2, 6.0), (tipx, 5.0), stroke: luma(100), mark: (end: ">"))
  }
  box(0.6, 3.2, 4.2, 1.8)
  cdraw.content((2.7, 4.45), [sum], size: 6pt)
  cdraw.content((2.7, 3.85), [(12, 4) + (27, 54)], size: 6pt)
  cdraw.content((2.7, 3.45), [(39, 58)], size: 6pt)
  box(5.1, 3.2, 4.2, 1.8)
  cdraw.content((7.2, 4.45), [product], size: 6pt)
  cdraw.content((7.2, 3.85), [u'v + uv'], size: 6pt)
  cdraw.content((7.2, 3.45), [(648, 216) + (324, 648) = (972, 864)], size: 6pt)
  box(9.6, 3.2, 4.2, 1.8)
  cdraw.content((11.7, 4.45), [chain], size: 6pt)
  cdraw.content((11.7, 3.85), [row times column], size: 6pt)
  cdraw.content((11.7, 3.45), [(10, 4) dot (4, 12) = 88], size: 6pt)
  cdraw.content((7.2, 2.4), [each rule pinned by a check in gradient.c or jacobian.c], size: 6pt)
})

sources: mml-book draft 2024-01-15, ch 5, def 5.5-5.8, examples 5.6-5.7, 5.9-5.11, 5.15, eqs 5.39-5.53, 5.57-5.66, 5.99-5.108, 5.146-5.180 [printed pp 146-169 / pdf pp 152-175], read from the verified anchor sheet ref/mml/anchors-calc.md. Matrix identity list after Petersen and Pedersen, the matrix cookbook, 2012, cited by name through mml sec 5.5. Probed on this machine the same day. Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch10`, 59 checks in chapter 10 of the math suite.
