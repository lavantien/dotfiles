#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= root finding

Root finding asks for the $x$ where a known function crosses zero, and
this chapter builds the four iteration machines that answer it plus the
weld that makes them safe: bisection trades speed for a proof,
fixed-point iteration makes the rearrangement the whole story, newton's
method squares the error once it gets close, the secant method buys
nearly the same speed for one function value per step, and a guard
turns the fast local methods into globally convergent hybrids. Six
moves: the halving guarantee, contraction and its 0.381966 constant,
tangent steps and error squaring, the golden order 1.618, one error
model $e_(n+1) = C e_n^p$ that classifies all four, and the
bisection-newton hybrid on a function where pure newton explodes.
Every behavioral claim below is one of the 60 checks in the 4 samples
of chapter 20 or a fact quoted from cppreference fetched 2026-09-22.
Where the numerical chapter of the dsa book (#xref-to("dsa",
"numerical")) tunes these drivers as contest templates with pinned
stopping rules, this chapter asks why each one converges, how fast, and
what breaks it. The derivatives come from #xref-to("math", "univariate"),
the conditioning lens from #xref-to("math", "error").

== bisection and the halving guarantee

If $f$ is continuous on $[a, b]$ and $f(a) f(b) < 0$, the intermediate
value theorem puts a root inside, and the midpoint test keeps that
certificate alive forever: evaluate at $m = (a+b)\/2$, keep the half
where the signs still disagree. Each step halves the bracket, so after
$n$ evaluations the surviving interval has width $(b-a)\/2^n$ and every
point of it, including the midpoint just tested, sits within $(b-a)\/2^n$
of some root. The rate is fixed, one bit per evaluation, and nothing
about $f$ beyond continuity and the sign change is used.

The fixture is $f(x) = x^3 - 2x - 5$ on $[2, 3]$, with $f(2) = -1$ and
$f(3) = 16$. Every midpoint on this bracket is an exact dyadic double, so
the whole ladder pins with bit equality in bisection.c, and the root
alpha = 2.0945514815423265 is the nearest double, itself the fixed point
of an 80-step newton ladder in the playground.

The dry run: eight rungs of halving, all exact.

+ Rung 1: $m = 2.5$, $f = 5.625 > 0$, root is left, bracket $[2, 2.5]$.
+ Rung 4: $m = 2.0625$, $f = -0.351318359375 < 0$, first sign flip,
  bracket $[2.0625, 2.125]$: alpha was in the smaller half.
+ Rung 8: $m = 2.09765625$, error $3.105 times 10^-3$ against the bound
  $2^-8 = 3.906 times 10^-3$, tight to a factor of 1.26.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*rung*], [*midpoint*], [*f(mid)*], [*abs(mid - alpha)*], [*bound 2^-n*]),
  [1], [2.5], [+5.625], [4.054e-1], [5.000e-1],
  [2], [2.25], [+1.891], [1.554e-1], [2.500e-1],
  [3], [2.125], [+0.346], [3.045e-2], [1.250e-1],
  [4], [2.0625], [-0.351], [3.205e-2], [6.250e-2],
  [5], [2.09375], [-0.009], [8.015e-4], [3.125e-2],
  [6], [2.109375], [+0.167], [1.482e-2], [1.563e-2],
  [7], [2.1015625], [+0.079], [7.011e-3], [7.813e-3],
  [8], [2.09765625], [+0.035], [3.105e-3], [3.906e-3],
)

The two-number play on this root and this tolerance: bisection needs 50
halvings to push the bracket width under $10^(-15)$, newton from the same
start $x_0 = 2$ needs 4 updates to land on the exact double.

#listing("math/samples/src/Ch20/bisection.c", first: 63, last: 85, caption: [bisection.c, the pinned rung ladder: dyadic midpoints, sign decisions, the 2^-n bound checked every rung])

#listing("math/samples/src/Ch20/bisection.c", first: 41, last: 57, caption: [bisection.c, the halvings driver that counts evaluations to a width tolerance])

#listing("math/samples/src/Ch20/bisection.c", first: 87, last: 103, caption: [bisection.c, 40 halvings land on the exact width 2^-40, and the sign invariant survives 50])

#diagram([nested brackets funnel onto alpha, each rung halves the interval that still certifies a root], length: 13pt, {
  let y(n) = 6.5 - (n - 1) * 0.72
  let cx(v) = 1.5 + (v - 2.0) * 18.0
  // axis
  cdraw.line((1.0, 0.9), (20.0, 0.9), stroke: luma(60))
  for (v, lab) in ((2.0, [2]), (2.25, [2.25]), (2.5, [2.5]), (3.0, [3])) {
    cdraw.line((cx(v), 0.78), (cx(v), 1.02), stroke: luma(60))
    cdraw.content((cx(v), 0.3), lab, size: 6pt)
  }
  cdraw.content((20.2, 0.9), [x], size: 6pt)
  // alpha line
  cdraw.line((cx(2.0945514815), 0.9), (cx(2.0945514815), 7.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((cx(2.0945514815), 7.25), [alpha], size: 6pt)
  // brackets per rung: (lo, hi, midpoint)
  let rungs = ((2.0, 3.0, 2.5), (2.0, 2.5, 2.25), (2.0, 2.25, 2.125),
    (2.0, 2.125, 2.0625), (2.0625, 2.125, 2.09375), (2.09375, 2.125, 2.109375),
    (2.09375, 2.109375, 2.1015625), (2.09375, 2.1015625, 2.09765625))
  for (i, r) in rungs.enumerate() {
    let (lo, hi, mid) = r
    let yy = y(i + 1)
    cdraw.line((cx(lo), yy), (cx(hi), yy), stroke: luma(100))
    cdraw.line((cx(lo), yy - 0.08), (cx(lo), yy + 0.08), stroke: luma(100))
    cdraw.line((cx(hi), yy - 0.08), (cx(hi), yy + 0.08), stroke: luma(100))
    cdraw.circle((cx(mid), yy), radius: 0.1, fill: luma(205), stroke: luma(60))
  }
  cdraw.content((0.2, 6.5), [rung 1], size: 6pt)
  cdraw.content((0.2, 1.46), [rung 8], size: 6pt)
})

#callout("note", "a bracket is a proof", [The sign change is a certificate that survives every halving, which is why bisection is the only method here with a global guarantee: no derivative, no smoothness, no start close enough. The price is the fixed rate of one bit per evaluation, and the certificate is unavailable when a root has even multiplicity, because no interval then shows a sign change at all.])

== fixed points and contraction

Any equation $f(x) = 0$ can be rewritten as $x = g(x)$, and then iterated:
$x_(n+1) = g(x_n)$. Whether that converges is decided by the
rearrangement, not the equation. If $g$ is differentiable near a fixed
point $alpha$ then $e_(n+1) = g(x_n) - alpha approx g'(alpha) e_n$, so
the iteration converges locally exactly when $abs(g'(alpha)) < 1$, and
the convergence is linear with one constant: each error is the previous
error times $g'(alpha)$, gaining $log_10 1\/abs(g'(alpha))$ digits per
step. A derivative above 1 in magnitude does not merely slow the
iteration, it repels the orbit.

The fixture is the golden ratio: $phi^2 = phi + 1$ rearranged as
$x = 1 + 1\/x$, whose fixed point has $g'(x) = -1\/x^2$ and
$abs(g'(phi)) = 1\/phi^2 = 0.38196601125010515$. Starting from $x_0 = 1$
the iterates are the continued-fraction convergents of $phi$, the ratios
of consecutive fibonacci numbers, and the double ladder rides them
exactly: rungs 1, 2, 4, 5, 8, 15, and 20 land bit-for-bit on the nearest
doubles to $2\/1$, $3\/2$, $8\/5$, $13\/8$, $55\/34$, $1597\/987$,$17711\/10946$. Rung 3 is the visible exception, one ulp below the
correctly rounded $5\/3$, because the map computes $1 + 0.66666666666666663$
while direct rounding of the fraction lands one grid step up.

The dry run: the error walks down a geometric ladder with alternating
sign.

+ $e_1 = phi - 2 = -0.382$, then $e_2 = +0.118$, $e_3 = -0.0486$,
  $e_5 = -0.00697$: the sign flips every step because $g'$ is negative.
+ Ratios close on the constant from both sides, $-0.381979$ at rung 11
  and $-0.381966004$ at rung 21 against $-1\/phi^2 = -0.38196601125010515$.
+ The derivative read along the ladder, $-1\/x_n^2$, is already
  $-0.38196601301237004$ at rung 20: the contraction constant is not
  magic, it is the observed slope.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*rung*], [*x*], [*e = phi - x*], [$bold(e_(n+1)\/e_n)$]),
  [0], [1], [+6.180e-1], [-0.618034],
  [1], [2], [-3.820e-1], [-0.309017],
  [2], [1.5], [+1.180e-1], [-0.412023],
  [3], [1.6666666666666665], [-4.863e-2], [-0.370820],
  [5], [1.625], [-6.966e-3], [-0.380329],
  [10], [1.6179775280898876], [+5.646e-5], [-0.381979],
  [20], [1.618033985017358], [+3.733e-9], [-0.3819660],
)

The same equation rearranged as $x = 1\/(x - 1)$ has the same two fixed
points and the opposite fate at each: $g'(x) = -1\/(x-1)^2$ gives
$abs(g'(phi)) = phi^2 = 2.618$ and $abs(g'(beta)) = 0.382$ where
$beta = (1 - sqrt(5))\/2$. From $x_0 = 1.7$ the orbit leaves phi
immediately, 1.4285714285714286, 2.333333333333333, 0.75000000000000022,
$-4.0000000000000036$, five rungs that run from distance 0.082 to 5.618,
and then settles onto beta with the same 0.381966 factor in reverse:
rung 40 is $-0.61803398874989601$, one part in $10^15$ from the conjugate
root, and its rung-30 error ratio reads $-0.3819727622439244$. The
two-number play: one equation, two rearrangements, contraction constants
0.382 and 2.618 at the same root.

#listing("math/samples/src/Ch20/fixedpoint.c", first: 26, last: 46, caption: [fixedpoint.c, one orbit driver: a map, a start, and a length, run through a compound literal])

#listing("math/samples/src/Ch20/fixedpoint.c", first: 83, last: 95, caption: [fixedpoint.c, the fibonacci convergents pinned bit for bit, and the one-ulp miss at rung 3])

#listing("math/samples/src/Ch20/fixedpoint.c", first: 111, last: 135, caption: [fixedpoint.c, the divergent twin: away from phi in five rungs, onto beta in forty, same 0.381966 constant])

#diagram([two cobwebs for one equation: the convergent staircase into phi on the left, the repelling orbit that escapes on the right], length: 13pt, {
  // left panel: v in [0.9, 2.1] mapped to [0.8, 7.0]
  let lx(v) = 0.8 + (v - 0.9) * 5.1667
  let ly(v) = 0.8 + (v - 0.9) * 5.1667
  cdraw.line((0.8, 0.8), (7.0, 7.0), stroke: luma(100))
  cdraw.content((6.6, 7.3), [y = x], size: 6pt)
  let g1 = ((0.9, 2.1111), (1.0, 2.0), (1.2, 1.8333), (1.4, 1.7143),
    (1.6, 1.625), (1.8, 1.5556), (2.0, 1.5), (2.1, 1.4762))
  for i in range(g1.len() - 1) {
    cdraw.line((lx(g1.at(i).at(0)), ly(g1.at(i).at(1))),
      (lx(g1.at(i + 1).at(0)), ly(g1.at(i + 1).at(1))), stroke: luma(60))
  }
  cdraw.content((1.0, 6.4), [y = 1 + 1\/x], size: 6pt)
  // staircase: (1,1) -> curve -> diagonal -> curve -> ...
  let p1 = ((1.3167, 1.3167), (1.3167, 6.4833), (6.4833, 6.4833),
    (6.4833, 3.9000), (3.9000, 3.9000), (3.9000, 4.7565),
    (4.7565, 4.7565), (4.7565, 4.4180), (4.4180, 4.4180))
  for i in range(p1.len() - 1) {
    cdraw.line(p1.at(i), p1.at(i + 1), stroke: (paint: luma(150), dash: "dashed"))
  }
  cdraw.circle((lx(1.618034), ly(1.618034)), radius: 0.14, fill: luma(205), stroke: luma(60))
  cdraw.content((4.6, 1.6), [staircase into phi], size: 6pt)
  // right panel: v in [0.4, 2.4] mapped to [9.2, 15.4]
  let rx(v) = 9.2 + (v - 0.4) * 3.1
  let ry(v) = 0.8 + (v - 0.4) * 3.1
  cdraw.line((9.2, 0.8), (15.4, 7.0), stroke: luma(100))
  let g2 = ((1.4167, 2.4), (1.5, 2.0), (1.7, 1.4286), (2.0, 1.0), (2.4, 0.7143))
  for i in range(g2.len() - 1) {
    cdraw.line((rx(g2.at(i).at(0)), ry(g2.at(i).at(1))),
      (rx(g2.at(i + 1).at(0)), ry(g2.at(i + 1).at(1))), stroke: luma(60))
  }
  cdraw.content((10.2, 6.6), [y = 1\/(x - 1)], size: 6pt)
  let p2 = ((13.22, 4.27), (13.22, 3.99), (12.39, 3.99), (12.39, 6.79),
    (15.19, 6.79), (15.19, 1.885), (10.285, 1.885), (10.285, 0.4))
  for i in range(p2.len() - 1) {
    cdraw.line(p2.at(i), p2.at(i + 1), stroke: (paint: luma(150), dash: "dashed"))
  }
  cdraw.content((10.285, 0.1), [to -4], size: 6pt)
  cdraw.circle((rx(1.618034), ry(1.618034)), radius: 0.14, fill: luma(245), stroke: luma(100))
  cdraw.content((13.5, 1.2), [escapes phi], size: 6pt)
})

#callout("pitfall", "the rearrangement chooses the fate", [Two algebraically equivalent forms of $x^2 = x + 1$ contract at 0.382 and 2.618 at the same root. Before iterating any fixed-point form, evaluate $abs(g')$ at the answer you want: the equation cannot tell you which rewrite to use, the derivative can. This is the theory behind every "does my iteration converge" question, and it is why newton's method, next, derives its rearrangement from the function instead of trusting one.])

== newton's method and quadratic convergence

Replace the wholesale rewrite with a local linear model: at $x_n$, follow
the tangent of $f$ down to the axis,
$x_(n+1) = x_n - f(x_n)\/f'(x_n)$, the derivative machinery of
#xref-to("math", "univariate"). Near a
simple root with $f'(alpha) != 0$, a Taylor expansion of $f$ at $alpha$
turns the update into $e_(n+1) approx (f''(alpha)\/(2 f'(alpha))) e_n^2$:
the error is squared and rescaled, so correct digits double per step,
which is the definition of quadratic convergence.

The fixture keeps $f(x) = x^3 - 2x - 5$, the example newton himself
worked in 1669, starting from $x_0 = 2$ where $f = -1$ and $f' = 10$.

The dry run: four updates to the exact double.

+ Update 1 is one fraction: $2 - (-1)\/10 = 2.1$, exactly the dyadic
  double.
+ Update 2: $f(2.1) = 0.061$, $f'(2.1) = 11.23$, giving
  $2.0945681211041851$, error $1.66 times 10^-5$.
+ Update 3: error $1.56 times 10^-10$, the square of the previous error
  times 0.563.
+ Update 4: $2.0945514815423265$, the nearest double to alpha, and the
  double map then never moves again, update 5 returns the same value.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*update*], [*x*], [*e = x - alpha*], [$bold(e_(n+1)\/e_n^2)$]),
  [0], [2], [-9.455148e-2], [0.609455],
  [1], [2.1], [+5.448518e-3], [0.560512],
  [2], [2.0945681211041851], [+1.663956e-5], [0.562971],
  [3], [2.0945514816981992], [+1.558726e-10], [0.562979],
  [4], [2.0945514815423265], [0, at the double], [-],
)

The two measured squaring ratios, 0.560512 and 0.562971, close on the
theory constant $f''(alpha)\/(2 f'(alpha)) = 0.56297894577790075$,
computed from alpha inside the same sample.

The same squaring law powers the division-free reciprocal. Applying
newton to $f(y) = 1\/y - a$ gives $y_(n+1) = y_n (2 - a y_n)$, an update
that multiplies and subtracts only, with error law
$e_(n+1) = -a e_n^2$. For $a = 7$ from $y_0 = 0.2$ the ladder runs 0.12,
0.1392, 0.14276352, 0.14285708150046722, 0.14285714285711651, and the
measured ratios read $-7$ to within $10^(-8)$, the constant being
exactly $-a$. The contest template for this refinement lives in
#xref-to("dsa", "numerical").

Quadratic convergence is a local promise. On $x^3 - 2x + 2$ from
$x_0 = 0$: $f(0) = 2$ on slope $f'(0) = -2$ sends the update to 1, and
$f(1) = 1$ on slope 1 sends it straight back to 0. The double map cycles
between exact integers forever, checks 11 and 12 witness the cycle after
ten and eleven steps, while the same polynomial has a real root in
$(-2, -1)$ that this start never sees. Away from a root, the tangent
line knows nothing.

#listing("math/samples/src/Ch20/newton.c", first: 26, last: 45, caption: [newton.c, the driver struct carries a function and its derivative together, one tangent step uses both])

#listing("math/samples/src/Ch20/newton.c", first: 50, last: 76, caption: [newton.c, the pinned ladder and the squaring ratios against the theory constant computed from alpha])

#listing("math/samples/src/Ch20/newton.c", first: 78, last: 89, caption: [newton.c, the exact 2-cycle on x^3 - 2x + 2 from 0, and the bracketed root it never finds])

#listing("math/samples/src/Ch20/newton.c", first: 91, last: 122, caption: [newton.c, the division-free reciprocal ladder for a = 7, errors squaring with constant -7])

#diagram([tangent steps down the curve: each tangent crosses the axis at the next iterate, the error spans shrink quadratically], length: 13pt, {
  // window: x in [1.9, 2.2] -> [1.0, 19.5]; f in [-2, 1.25] -> [1.2, 6.8]
  let cx(v) = 1.0 + (v - 1.9) * 61.667
  let cy(v) = 1.2 + (v + 2.0) * 1.723
  // axis at f = 0
  cdraw.line((0.8, cy(0.0)), (19.7, cy(0.0)), stroke: luma(60))
  // curve
  let pts = ((1.90, -1.941), (1.95, -1.485), (2.00, -1.0), (2.05, -0.485),
    (2.10, 0.061), (2.15, 0.638), (2.20, 1.248))
  for i in range(pts.len() - 1) {
    cdraw.line((cx(pts.at(i).at(0)), cy(pts.at(i).at(1))),
      (cx(pts.at(i + 1).at(0)), cy(pts.at(i + 1).at(1))), stroke: luma(60))
  }
  cdraw.content((19.2, 6.6), [f], size: 6pt)
  // tangency points on the curve at x0 and x1
  cdraw.circle((cx(2.0), cy(-1.0)), radius: 0.11, fill: luma(205), stroke: luma(60))
  cdraw.circle((cx(2.1), cy(0.061)), radius: 0.11, fill: luma(205), stroke: luma(60))
  // tangent at x0 = 2: y = -1 + 10 (x - 2), from 1.93 to 2.12
  cdraw.line((cx(1.93), cy(-1.7)), (cx(2.12), cy(0.2)), stroke: (paint: luma(150), dash: "dashed"))
  // tangent at x1 = 2.1: y = 0.061 + 11.23 (x - 2.1), from 2.06 to 2.105
  cdraw.line((cx(2.06), cy(-0.388)), (cx(2.105), cy(0.117)), stroke: (paint: luma(150), dash: "dashed"))
  // iterate ticks on the axis
  for (v, lab) in ((2.0, [x0]), (2.0945514815, [alpha])) {
    cdraw.line((cx(v), cy(0.0) - 0.12), (cx(v), cy(0.0) + 0.12), stroke: luma(60))
    cdraw.content((cx(v), cy(0.0) - 0.55), lab, size: 6pt)
  }
  cdraw.line((cx(2.1), cy(0.0) - 0.12), (cx(2.1), cy(0.0) + 0.12), stroke: luma(60))
  cdraw.content((cx(2.1), cy(0.0) + 0.75), [x1], size: 6pt)
  cdraw.circle((cx(2.0945514815), cy(0.0)), radius: 0.12, fill: luma(205), stroke: luma(60))
  // error spans e0 and e1
  cdraw.line((cx(2.0), 2.2), (cx(2.0945514815), 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((cx(2.045), 2.5), [e0 = 9.5e-2], size: 6pt)
  cdraw.line((cx(2.0945514815), 3.0), (cx(2.1), 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.75, 3.0), [e1 = 5.4e-3], size: 6pt)
})

#callout("warning", "quadratic convergence is a local promise", [The squaring law assumes a simple root with $f'$ bounded away from zero and a start close enough, and neither is free: the cycle fixture cycles from $x_0 = 0$ on a polynomial that does have a root, and a root of multiplicity $m$ drops the rate to linear with constant $(m-1)\/m$, the standard result in Higham, Accuracy and Stability of Numerical Algorithms, 2nd ed. Speed near the root says nothing about getting there, which is the subject of the safeguards section.])

== the secant method and the golden order

The derivative in newton's update can be replaced by the slope through
the last two iterates,
$x_(n+1) = x_n - f(x_n) (x_n - x_(n-1))\/(f(x_n) - f(x_(n-1)))$,
one function evaluation per step instead of two. The cost is a slightly
weaker law: $e_(n+1) approx C e_n e_(n-1)$, and asking how the error must
scale to satisfy it, if $e_n$ behaves like $e_(n-1)^p$, forces
$p^2 = p + 1$. That is the golden-ratio equation of the fixed-point
section, so the secant order is $p = (1 + sqrt(5))\/2 = 1.6180339887498949$,
superlinear: better than any fixed number of digits per step, worse than
doubling.

The dry run: the same root, the same tolerance, from the pair $(2, 3)$.

+ Update 1: the chord from $(2, -1)$ to $(3, 16)$ has slope 17 and
  crosses the axis at $35\/17 = 2.0588235294117645$.
+ Updates 2 through 4: 2.0812636598450229, 2.0948241460940524,
  2.0945494310352473, errors $1.3 times 10^-2$, $2.7 times 10^-4$,
  $2.1 times 10^-6$.
+ Update 6: error $3.1 times 10^-10$. Update 7 lands one ulp above the
  exact double, update 8 on it.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*update*], [*x*], [*abs(e)*], [*measured p*]),
  [1], [3], [9.054e-1], [-],
  [2], [2.0588235294117645], [3.573e-2], [0.306],
  [3], [2.0812636598450229], [1.329e-2], [3.929],
  [4], [2.0948241460940524], [2.727e-4], [1.258],
  [5], [2.0945494310352473], [2.051e-6], [1.796],
  [6], [2.0945514812275992], [3.147e-10], [1.534],
  [7], [2.094551481542327], [4.441e-16], [-],
  [8], [2.0945514815423265], [0, at the double], [-],
)

The measured exponent $p = log abs(e_(n+1)\/e_n)\/log abs(e_n\/e_(n-1))$
swings early, 0.31, 3.93, then settles: 1.796 and 1.534 straddle 1.618.
The two-number play is the accounting: to land on the exact double,
newton spends 4 updates but 8 evaluations (each needs $f$ and $f'$),
secant spends 7 updates and 9 evaluations of $f$ alone, bisection spends
50. When the derivative is unavailable or costs more than one extra
evaluation, secant wins the race: the classical efficiency index, order
per evaluation, is $1.618^1 = 1.618$ against $2^(1\/2) = 1.414$.

#listing("math/samples/src/Ch20/safeguard.c", first: 28, last: 33, caption: [safeguard.c, one secant update: the chord through the last two iterates])

#listing("math/samples/src/Ch20/safeguard.c", first: 69, last: 98, caption: [safeguard.c, the pinned ladder, the ulp off the exact double, and the measured exponents straddling 1.618])

#diagram([the two local models on one curve: the tangent uses a point and its derivative, the chord uses two points, both aim at the next iterate], length: 13pt, {
  // schematic window, no fixture numbers: curve crosses the axis at 11.8
  cdraw.line((0.8, 1.0), (19.8, 1.0), stroke: luma(60))
  cdraw.line((0.8, 0.8), (0.8, 6.4), stroke: luma(60))
  cdraw.content((0.8, 6.7), [f], size: 6pt)
  cdraw.content((20.0, 1.0), [x], size: 6pt)
  let curve = ((1.5, 5.8), (3.0, 5.6), (5.0, 5.0), (7.0, 4.2), (9.0, 3.4),
    (10.0, 3.0), (11.0, 2.4), (11.4, 1.8), (11.8, 1.0), (12.5, 0.5),
    (14.0, 0.3), (16.0, 0.6), (18.5, 1.2))
  for i in range(curve.len() - 1) {
    cdraw.line(curve.at(i), curve.at(i + 1), stroke: luma(60))
  }
  // points P and Q on the curve
  cdraw.circle((5.0, 5.0), radius: 0.12, fill: luma(205), stroke: luma(60))
  cdraw.content((4.9, 5.4), [P], size: 6pt)
  cdraw.circle((10.0, 3.0), radius: 0.12, fill: luma(205), stroke: luma(60))
  cdraw.content((9.9, 3.4), [Q], size: 6pt)
  // tangent at Q, dashed, hits the axis at t = 13.33
  cdraw.line((5.5, 5.7), (13.33, 1.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((13.33, 1.0), (13.33, 0.55), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((13.33, 0.2), [t], size: 6pt)
  // chord P Q, solid, hits the axis at s = 15.0
  cdraw.line((5.0, 5.0), (15.0, 1.0), stroke: luma(100))
  cdraw.line((15.0, 1.0), (15.0, 0.55), stroke: luma(100))
  cdraw.content((15.0, 0.2), [s], size: 6pt)
  // root
  cdraw.circle((11.8, 1.0), radius: 0.12, fill: luma(245), stroke: luma(100))
  cdraw.content((11.5, 0.2), [root], size: 6pt)
  cdraw.content((14.8, 6.0), [tangent at Q: needs f prime], size: 6pt)
  cdraw.content((14.8, 5.5), [chord P Q: needs only f], size: 6pt)
})

== one error model, three speeds

Every ladder in this chapter fits one model:
$ e_(n+1) = C e_n^p $
with constant $C$ and order $p$, and the order is the whole taxonomy:
linear for $p = 1$, where each step multiplies the error by $C$ and buys
a fixed digit count $log_10 1\/abs(C)$, quadratic for $p = 2$, where
digits double, superlinear in between, where the digits gained per step
grow geometrically with ratio $p$. All four machines of this chapter fall
in line, with the constants and orders measured, not asserted.

The dry run: bisection holds bracket width $2^(-50)$ at 50 halvings, the
fixed-point ratios close on $-0.381966004$ at rung 21, secant reads
measured orders 1.796 and 1.534, and newton reads squaring constants
0.560512 and 0.562971.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*method*], [*error model*], [*measured*], [*digits per step*], [*sample*]),
  [bisection], [$e_(n+1) = e_n\/2$], [width $2^(-50)$ at 50], [0.301 fixed], [14 in bisection.c],
  [fixed point], [$e_(n+1) = 0.381966 e_n$], [ratio -0.381966004 at rung 21], [0.418 fixed], [15 in fixedpoint.c],
  [secant], [$e_(n+1) = C e_n^1.618$], [p 1.796, 1.534], [0.43 to 5.85, growing], [15 in safeguard.c],
  [newton], [$e_(n+1) = 0.562979 e_n^2$], [0.560512, 0.562971], [digits double], [16 in newton.c],
)

Bisection is linear on the bracket width, a bound rather than an observed
error: its constant is exact and global, every other constant in the
table is asymptotic, visible only once the ladder is near its root. The
digits column is where intuition
should land: 0.301 and 0.418 are budgets, secant's grows by a factor
near 1.6 each step, newton's doubles. A multiple root moves a method
down this table, as the warning in the newton section recorded: order
$m$ at the root makes newton linear with constant $(m-1)\/m$, so a
double root halves the error per step, no better than the fixed-point
ladder. The conditioning of the root itself, how error in $f$'s
coefficients or evaluations moves alpha, is the subject of
#xref-to("math", "error") and decides whether extra digits are even
meaningful.

#diagram([digits of accuracy per iteration: bisection and fixed point crawl at fixed slopes, secant accelerates, newton doubles], length: 13pt, {
  // n in [0,8] -> [1.0, 19.0]; digits d -> cy = 0.8 + 0.72 d, smaller error maps higher
  let cx(n) = 1.0 + n * 2.25
  let cy(d) = 0.8 + d * 0.72
  // axes
  cdraw.line((0.8, 0.8), (19.6, 0.8), stroke: luma(60))
  cdraw.line((0.8, 0.8), (0.8, 13.0), stroke: luma(60))
  for (d, lab) in ((0.0, [0]), (5.0, [5]), (10.0, [10]), (15.0, [15])) {
    cdraw.line((0.68, cy(d)), (0.92, cy(d)), stroke: luma(60))
    cdraw.content((0.2, cy(d)), lab, size: 6pt)
  }
  for (n, lab) in ((0, [0]), (2, [2]), (4, [4]), (6, [6]), (8, [8])) {
    cdraw.line((cx(n), 0.68), (cx(n), 0.92), stroke: luma(60))
    cdraw.content((cx(n), 0.25), lab, size: 6pt)
  }
  cdraw.content((-0.6, 12.6), [digits], size: 6pt)
  cdraw.content((19.6, 0.3), [step], size: 6pt)
  // bisection bound: 0.301 n
  let bis = ((0, 0.0), (1, 0.301), (2, 0.602), (3, 0.903), (4, 1.204),
    (5, 1.505), (6, 1.806), (7, 2.107), (8, 2.408))
  for i in range(bis.len() - 1) {
    cdraw.line((cx(bis.at(i).at(0)), cy(bis.at(i).at(1))),
      (cx(bis.at(i + 1).at(0)), cy(bis.at(i + 1).at(1))),
      stroke: (paint: luma(150), dash: "dashed"))
  }
  // fixed point digits
  let fp = ((1, 0.42), (2, 0.93), (3, 1.31), (4, 1.74), (5, 2.16),
    (6, 2.58), (7, 2.99), (8, 3.41))
  for i in range(fp.len() - 1) {
    cdraw.line((cx(fp.at(i).at(0)), cy(fp.at(i).at(1))),
      (cx(fp.at(i + 1).at(0)), cy(fp.at(i + 1).at(1))), stroke: luma(140))
  }
  // secant digits
  let sec = ((1, 0.04), (2, 1.45), (3, 1.88), (4, 3.56), (5, 5.69),
    (6, 9.50), (7, 15.35), (8, 16.09))
  for i in range(sec.len() - 1) {
    cdraw.line((cx(sec.at(i).at(0)), cy(sec.at(i).at(1))),
      (cx(sec.at(i + 1).at(0)), cy(sec.at(i + 1).at(1))), stroke: luma(100))
  }
  // newton digits
  let nw = ((0, 1.02), (1, 2.26), (2, 4.78), (3, 9.81), (4, 16.09))
  for i in range(nw.len() - 1) {
    cdraw.line((cx(nw.at(i).at(0)), cy(nw.at(i).at(1))),
      (cx(nw.at(i + 1).at(0)), cy(nw.at(i + 1).at(1))), stroke: luma(60))
  }
  // legend
  cdraw.line((11.6, 12.0), (12.6, 12.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((12.8, 12.0), [bisection], size: 6pt)
  cdraw.line((11.6, 11.3), (12.6, 11.3), stroke: luma(140))
  cdraw.content((12.8, 11.3), [fixed point], size: 6pt)
  cdraw.line((11.6, 10.6), (12.6, 10.6), stroke: luma(100))
  cdraw.content((12.8, 10.6), [secant], size: 6pt)
  cdraw.line((11.6, 9.9), (12.6, 9.9), stroke: luma(60))
  cdraw.content((12.8, 9.9), [newton], size: 6pt)
})

== safeguards: keep the bracket

Every fast method above is local, and the fix is old and standard: carry
a bisection bracket as a certificate, propose each new iterate with the
fast method, and if the proposal leaves the bracket, or the step does not
shrink the bracket, throw it away and bisect instead. The bracket's sign
invariant $f("lo") f("hi") < 0$ survives every step by construction, so
the hybrid inherits bisection's global guarantee while still finishing
at newton's quadratic pace once the iterates behave. Production root
finders are all of this shape: Brent's zeroin interleaves bisection,
secant, and inverse quadratic interpolation under exactly this guard,
and it is the default solver of the major numerical libraries, the
safeguarded-iteration practice Higham, Accuracy and Stability of
Numerical Algorithms, 2nd ed, records.

The fixture needs a function where pure newton genuinely fails:
$f(x) = "atan" x$. It is monotone with $f'(x) = 1\/(1 + x^2)$, its one
root is 0, and cppreference pins its values inside $[-pi\/2, pi\/2]$ with
$"atan"(plus.minus 0) = plus.minus 0$, fetched 2026-09-22. Newton from
$x_0 = 2$ walks into the trap: the slope there is only $0.2$, so the
step overshoots to $-3.535743588970452$, and the ladder explodes,
$13.95095908692749$, $-279.34406653361731$, $1.2 times 10^5$,
$-2.3 times 10^10$, $8.59 times 10^20$: for large $x$ the step grows
like $x^2$, quadratic divergence running backwards.

The dry run: the hybrid, bracket $[-1, 4]$, newton candidate from 2.

+ Step 1: newton proposes $-3.535743588970452$, outside the bracket,
  rejected. Bisect: $t = 1.5$, bracket tightens to $[-1, 1.5]$.
+ Step 2: newton from 1.5 proposes $-1.694$, still outside. Bisect:
  $t = 0.25$, bracket $[-1, 0.25]$.
+ Step 3: newton from 0.25 proposes $-0.01028982957229313$, inside.
  Accepted, bracket $[-0.010289..., 0.25]$.
+ Steps 4 and 5: accepted newton steps, $7.26 times 10^-7$ then
  $-2.55 times 10^-19$, residual $"atan"$ of the final point under
  $10^(-16)$.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*guard*], [*accepted t*], [*bracket after*]),
  [1], [bisect], [1.5], [[-1, 1.5]],
  [2], [bisect], [0.25], [[-1, 0.25]],
  [3], [newton], [-0.010289829572293], [[-0.0103, 0.25]],
  [4], [newton], [+7.263134553e-7], [[-0.0103, 7.26e-7]],
  [5], [newton], [-2.554863127e-19], [[-2.55e-19, 7.26e-7]],
)

The two-number play, one function, one start, one guard apart: pure
newton ends the sixth update beyond $8.59 times 10^20$, the hybrid ends
the fifth at $-2.55 times 10^-19$. Two rejected proposals bought the
whole trajectory. The same discipline extends outward: #xref-to("math",
"optimization") guards fast descent directions with trust regions the
same way, and the contest drivers of #xref-to("dsa", "numerical") pin
fixed iteration counts so a cycle cannot silently burn the clock.

#listing("math/samples/src/Ch20/safeguard.c", first: 35, last: 66, caption: [safeguard.c, the guard step: newton proposal, bracket membership test, bisection fallback, sign invariant restored])

#listing("math/samples/src/Ch20/safeguard.c", first: 130, last: 159, caption: [safeguard.c, pure newton on atan diverges, rungs 1 through 5 pinned, rung 6 blown past 1e20])

#listing("math/samples/src/Ch20/safeguard.c", first: 161, last: 190, caption: [safeguard.c, the hybrid trace, two bisections then three newtons, invariant checked every step])

#diagram([the safeguard decision loop: propose with newton, test bracket membership, fall back to bisection, always re-establish the sign invariant], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.6, 6.2, 6.4, [newton proposal t = x - f\/f prime])
  box(8.6, 6.2, 4.8, [t inside (lo, hi)?])
  box(15.4, 6.2, 3.4, [accept t])
  box(8.6, 4.0, 4.8, [bisect: t = midpoint])
  box(13.2, 1.6, 6.4, [update bracket by sign, keep f(lo) f(hi) < 0])
  cdraw.line((7.0, 6.7), (8.6, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.4, 6.7), (15.4, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.4, 6.95), [yes], size: 6pt)
  cdraw.line((11.0, 6.2), (11.0, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.35, 5.6), [no], size: 6pt)
  cdraw.line((13.4, 4.5), (15.0, 4.5), stroke: luma(100))
  cdraw.line((15.0, 4.5), (15.0, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.1, 6.2), (17.1, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.2, 2.1), (3.8, 2.1), stroke: luma(100))
  cdraw.line((3.8, 2.1), (3.8, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.4, 4.4), [next step], size: 6pt)
  // trace strip
  let tr = ((12.2, [B]), (13.4, [B]), (14.6, [N]), (15.8, [N]), (17.0, [N]))
  for (x, s) in tr {
    cdraw.rect((x, 0.2), (x + 0.9, 1.1), fill: luma(245), stroke: luma(140))
    cdraw.content((x + 0.45, 0.65), s, size: 6pt)
  }
  cdraw.content((10.0, 0.65), [atan trace:], size: 6pt)
  cdraw.content((16.2, 1.5), [to 2.6e-19], size: 6pt)
})

#callout("note", "the practical default", [When you cannot analyze the function, use a bracket-maintaining hybrid: pay the two evaluations of a sign search for the bracket, then let the guard decide. Every method of this chapter is available in the samples as a 30-line driver, and the hybrid is the one worth copying first, because it is the only one whose worst case is bisection.])

The next chapter, #xref-to("math", "interp"), asks the mirror question:
instead of the point where a function is zero, find the polynomial that
passes through given points, and the error ladders of this chapter
become interpolation error bounds.

sources: Nicholas J. Higham, Accuracy and Stability of Numerical
Algorithms, 2nd ed, SIAM 2002, cited by name for the multiplicity rate
degeneration and the safeguarded-iteration practice behind Brent-style
solvers, no page text quoted. Lloyd N. Trefethen and David Bau,
Numerical Linear Algebra, SIAM 1997, cited by name for the linear,
superlinear, quadratic convergence taxonomy. cppreference atan,
en.cppreference.com/w/c/numeric/math/atan, fetched 2026-09-22, principal
value range and zero handling quoted from the page. Every iteration
ladder, ratio, and count pinned by the python mirrors in
playground/math-ch20 and re-measured by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch20`,
60 checks in chapter 20 of the math suite.
