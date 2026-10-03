#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= continuous optimization

Training a model means picking parameters that make an objective small,
and the picking is done by an algorithm, not by algebra: mml-book opens
its optimization chapter with the sentence "Training a machine learning
model often boils down to finding a good set of parameters" (draft
2024-01-15, ch 7 opener [printed pp 225-226 / pdf pp 231-232]). This
chapter builds the machinery in six moves: the terrain of local and
global minima on one pinned quartic, gradient descent with its
step-size bound and momentum correction, newton's method as the hessian
correction, constrained optimization through lagrange multipliers and
kkt, convexity as the property that turns stationary into global, and
the two program families (linear and quadratic) that close the story.
Every behavioral claim below is one of the 81 checks in the 4 samples
of chapter 11 or a definition quoted from the mml anchor sheet (mml-book
draft 2024-01-15, every sheet number reverified by 53 numpy recomputes).
Where the #xref-to("dsa", "numerical") chapter of the sibling book times
these loops for contest boards, this chapter stays theory first: why the
steps shrink, why the ball remembers, and why convexity removes the
search. Gradients and Hessians come from #xref-to("math", "multivariate").

== stationary points and basins

Optimization is minimization by convention. A point is stationary when
its gradient vanishes, and on a 1D slice that means the derivative's
real roots: "Stationary points are the real roots of the derivative"
(mml ch 7 opener). The chapter's running example is the quartic

$ ell(x) = x^4 + 7x^3 + 5x^2 - 17x + 3, $

with derivative $4x^3 + 21x^2 + 10x - 17$ and second derivative
$12x^2 + 42x + 10$ (mml eqs 7.1-7.3). Abel-Ruffini says degree 5 and up
has no root formula in general, so even finding stationary points is an
iterative job, and the derivative here is only cubic, which is why this
quartic makes a fair test fixture: its three stationary points can be
pinned once and reused all chapter. The second-derivative test sorts
them: positive curvature means a minimum, negative means a maximum.

The dry run: the three roots of $4x^3 + 21x^2 + 10x - 17$ pin as
-4.48026848037364, -1.43211239686132, and 0.662380877234966.

+ At $x = -4.48026848037364$ the value is $-47.0747900996365$ and
  $12x^2 + 42x + 10$ gives $62.7023916991 > 0$: the global minimum.
+ At $x = -1.43211239686132$ the curvature is $-25.5373696612 < 0$: a
  local maximum, value $21.2467239746817$.
+ At $x = 0.662380877234966$ the curvature is $43.0849779622 > 0$:
  a second, shallower local minimum, value $-3.83990262504519$.

The recognition in two numbers: the global minimum sits at $-47.07$
while the local trap two basins away bottoms out at $-3.84$. An
iterative method that only walks downhill lands in whichever basin it
starts in, and the mml opener notes that starting this same function at
$x_0 = 0$ "would have led us to the wrong minimum". Convexity, previewed
in the last third of this chapter, is the property that deletes the
word local from that sentence.

#listing("math/samples/src/Ch11/newtonopt.c", first: 20, last: 27, caption: [the quartic fixture with its two derivatives, the chapter's pinned terrain])
#listing("math/samples/src/Ch11/newtonopt.c", first: 82, last: 90, caption: [the sign test reading max, min, min from the curvature at the three roots])

#diagram([the quartic terrain: one global minimum, one local maximum, one local trap], length: 13pt, {
  let px(u) = 0.8 + (u + 6.0) * 1.5
  let py(v) = 0.6 + (v + 50.0) * 0.052
  let pts = ((-6.0, 69.0), (-5.75, 28.4), (-5.5, -1.8), (-5.25, -23.2), (-5.0, -37.0), (-4.75, -44.6), (-4.5, -47.1), (-4.25, -45.5), (-4.0, -41.0), (-3.75, -34.3), (-3.5, -26.3), (-3.25, -17.7), (-3.0, -9.0), (-2.75, -0.8), (-2.5, 6.4), (-2.25, 12.5), (-2.0, 17.0), (-1.75, 19.9), (-1.5, 21.2), (-1.25, 20.8), (-1.0, 19.0), (-0.75, 15.9), (-0.5, 11.9), (-0.25, 7.5), (0.0, 3.0), (0.25, -0.8), (0.5, -3.3), (0.75, -3.7), (1.0, -1.0), (1.25, 5.7), (1.5, 17.4), (1.75, 35.5), (2.0, 61.0))
  for i in range(pts.len() - 1) {
    let a = pts.at(i)
    let b = pts.at(i + 1)
    cdraw.line((px(a.first()), py(a.at(1))), (px(b.first()), py(b.at(1))), stroke: luma(60))
  }
  cdraw.line((0.8, py(0.0)), (12.8, py(0.0)), stroke: luma(140))
  cdraw.line((px(0.0), 0.3), (px(0.0), 6.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((px(-4.4803), py(-47.07)), radius: 0.09, fill: luma(60))
  cdraw.content((px(-4.4803), py(-47.07) - 0.45), [global min -47.07], size: 6pt)
  cdraw.circle((px(-1.4321), py(21.25)), radius: 0.09, fill: luma(60))
  cdraw.content((px(-1.4321), py(21.25) + 0.4), [local max], size: 6pt)
  cdraw.circle((px(0.6624), py(-3.84)), radius: 0.09, fill: luma(60))
  cdraw.content((px(0.6624) + 0.15, py(-3.84) - 0.45), [local min -3.84], size: 6pt)
  cdraw.content((12.6, py(0.0) + 0.3), [x], size: 6pt)
})

#callout("pitfall", "THE STARTING POINT CHOOSES THE BASIN", [Downhill-only methods are blind to the far valley. On this quartic, a start at $x_0 = 0$ walks into the $-3.84$ trap and never sees $-47.07$. The fix is not a smarter step, it is either many starts or, when the objective is convex, the guarantee developed in the convexity section below that no trap exists.])

== gradient descent

The gradient points uphill, so we step against it. With $f : RR^d -> RR$
differentiable and no closed-form minimizer, mml eq 7.6 iterates

$ bold(x)_(i+1) = bold(x)_i - gamma_i ((nabla f)(bold(x)_i))^top $

for a step-size $gamma_i >= 0$ (the transpose is the book's row-vector
gradient convention, and the margin names $gamma$ the learning rate).
The pinned fixture is mml example 7.1: $f(bold(x)) = 1/2 bold(x)^top
bold(Q) bold(x) - bold(b)^top bold(x)$ with $bold(Q) = mat(2, 1; 1, 20)$
and $bold(b) = (5, 3)$, whose analytic minimum is $bold(Q)^(-1) bold(b)
= (97/39, 1/39) approx (2.487, 0.026)$. The condition number of
$bold(Q)$ is $20.0554 \/ 1.9446 approx 10.3$: one flat valley direction
and one steep one, the shape that makes plain descent zigzag.

The dry run: from $bold(x)_0 = (-3, -1)$ with $gamma = 0.085$ the
gradient is $(-12, -26)$, so the step adds $1.02$ and $2.21$.

+ One step lands at $(-1.98, 1.21)$, and mml prints exactly these
  coordinates in its figure 7.3 walk-through.
+ Recomputing the gradient there, $(-7.75, 19.22)$, the second step
  lands at $(-1.32125, -0.4237)$, already oscillating across the
  valley: the second coordinate flips sign every step.
+ After 8 steps the iterate is $(1.20693630992, 0.0156794647305)$ at
  distance $1.28028193209$ from the minimum, and $f$ fell on every
  single step.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*k*], [*$x_1$*], [*$x_2$*], [*f*], [*distance*]),
  [0], [-3], [-1], [40], [5.5822],
  [1], [-1.98], [1.21], [22.4356], [4.6215],
  [2], [-1.32125], [-0.4237], [11.9781], [3.8348],
  [4], [-0.158998], [-0.155699], [1.55455], [2.6524],
  [8], [1.206936], [0.015679], [-4.60364], [1.2803],
)

#listing("math/samples/src/Ch11/descent.c", first: 42, last: 77, caption: [the fixed-step ladder on the example 7.1 quadratic, iterates pinned against the precomputed column])

The step-size question has a hard edge. The eigenvalues of $bold(Q)$
are $11 plus.minus sqrt(82)$, so the largest curvature is $L = 20.0554$
and any fixed $gamma > 2\/L = 0.0997238$ amplifies the error in the
steep direction each step: the error $bold(x) - bold(x)^*$ (with
$bold(x)^*$ the minimum) is mapped by $bold(I) - gamma bold(Q)$, which
then has an eigenvalue outside the unit circle. Pinning it: at $gamma
= 2.2\/L = 0.1097$ the 30th iterate reaches magnitude $|bold(x)_30| =
314.967$ with $f = 995753$, monotonically worse. The same edge
explains the two
heuristics mml quotes from Toussaint (2012): when the value increases
after a step, undo and decrease, and when it decreases, try growing
the step, which "guarantees monotonic convergence". A schedule that
decays on its own, $gamma_i = 0.15\/(i+1)$, buys the same safety
differently: fixed $0.15$ explodes past $10^(17)$ within 60 steps,
while the decayed ladder from the same unsafe $0.15$ start is alive at
distance $1.27588449602$ after 60 steps, and the honest fixed $0.085$
is far ahead at 1.06226e-4. Decay trades speed for survival when $L$
is unknown.

#listing("math/samples/src/Ch11/descent.c", first: 79, last: 101, caption: [the 2/L bound and the divergence ladder past it])
#listing("math/samples/src/Ch11/descent.c", first: 103, last: 125, caption: [the decaying schedule rescuing an unsafe first step])

#callout("note", "STEP-SIZE IS THE LEARNING RATE", [mml's margin on section 7.1.1: "The step-size is also called the learning rate." Too small crawls, too large overshoots or diverges as pinned above, and adaptive methods rescale it per iteration. The 2/L analysis here is exact only for quadratics, but the qualitative edge is universal: curvature times step must stay under 2.])

Momentum is the heavy-ball correction, mml eq 7.11:

$ bold(x)_(i+1) = bold(x)_i - gamma_i ((nabla f)(bold(x)_i))^top + alpha Delta bold(x)_i, quad Delta bold(x)_i = bold(x)_i - bold(x)_(i-1), $

with $alpha in [0, 1]$: "This memory dampens oscillations and smoothes
out the gradient updates", a heavy ball reluctant to change direction.
On a quadratic with curvatures $l$ and $L$, the theoretically optimal
pair is $alpha = ((sqrt(L) - sqrt(l)) \/ (sqrt(L) + sqrt(l)))^2 =
0.275732$ and $gamma = (2 \/ (sqrt(L) + sqrt(l)))^2 = 0.115976$, and
note the second number exceeds $2\/L$: momentum extends the stability
region. The sample derives both constants from $L$ and $l$ in code, no
magic numbers, then pins the ladder.

#listing("math/samples/src/Ch11/descent.c", first: 127, last: 166, caption: [optimal fixed step versus heavy ball, both parameterized by the eigenvalues])

The two-number play: at step 30, plain descent with its own optimal
fixed step sits $0.0163$ from the minimum while the heavy ball sits
$4.19 times 10^(-7)$ away, five orders for one line of memory.

#diagram([the 0.085 zigzag across the valley toward (2.487, 0.026)], length: 13pt, {
  let px(u) = 0.8 + (u + 3.3) * 1.75
  let py(v) = 0.6 + (v + 1.0) * 1.35
  let path = ((-3.0, -1.0), (-1.98, 1.21), (-1.32, -0.42), (-0.64, 0.66), (-0.16, -0.16), (0.31, 0.38), (0.65, -0.04), (0.97, 0.22), (1.21, 0.02))
  for i in range(path.len() - 1) {
    let a = path.at(i)
    let b = path.at(i + 1)
    cdraw.line((px(a.first()), py(a.at(1))), (px(b.first()), py(b.at(1))), stroke: luma(60), mark: (end: ">"))
  }
  for p in path {
    cdraw.circle((px(p.first()), py(p.at(1))), radius: 0.08, fill: luma(205))
  }
  cdraw.rect((px(2.487) - 0.12, py(0.026) - 0.12), (px(2.487) + 0.12, py(0.026) + 0.12), fill: luma(60))
  cdraw.content((px(2.487) - 0.2, py(0.026) - 0.5), [minimum (2.487, 0.026)], size: 6pt)
  cdraw.content((px(-3.0), py(-1.0) - 0.45), [x0 (-3, -1)], size: 6pt)
  cdraw.content((px(-1.98) - 0.15, py(1.21) + 0.35), [step 1], size: 6pt)
})

== newton's method for optimization

Newton for minimization is #xref-to("math", "univariate") root-finding
applied to the derivative, with curvature in the denominator. In 1D the
update is $x_(i+1) = x_i - f'(x_i) \/ f''(x_i)$, and in $d$ dimensions
the gradient gets premultiplied by the inverse Hessian, the matrix of
second partials from #xref-to("math", "multivariate"). On the running
quartic from $x_0 = -6$:

The dry run: at $x_0 = -6$ the residual is $f' = -185$ on curvature
$f'' = 190$.

+ The first step is one fraction: $-6 - (-185)\/190 = -6 + 0.973684 =
  -5.02631578947$.
+ The errors then square: $1.520$, $5.460 times 10^(-1)$, $1.085 times
  10^(-1)$, $5.658 times 10^(-3)$, $1.665 times 10^(-5)$, $1.448
  times 10^(-10)$, $8.9 times 10^(-16)$, six steps to machine
  precision on the derivative.
+ The squaring constant pins at $0.5225$: each error is that multiple
  of the previous error squared, the measured face of quadratic
  convergence.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*k*], [*$x_k$*], [*$e_k = x_k - r_1$*], [*$e_k \/ e_(k-1)^2$*]),
  [0], [-6], [1.520], [--],
  [1], [-5.026316], [0.5460], [0.236],
  [2], [-4.588747], [0.1085], [0.364],
  [3], [-4.485926], [5.658e-3], [0.481],
  [4], [-4.480285], [1.665e-5], [0.520],
  [5], [-4.48026848052], [1.448e-10], [0.523],
)

#listing("math/samples/src/Ch11/newtonopt.c", first: 56, last: 80, caption: [the newton ladder with the error-squaring pins])

On a quadratic the Hessian is constant, so one newton step is exact:
$x_1 = bold(x)_0 - bold(Q)^(-1)(bold(Q) bold(x)_0 - bold(b)) =
bold(Q)^(-1) bold(b)$, and the sample pins the landing on $(97/39,
1/39)$ to $10^(-12)$ from $(-3, -1)$, where fixed-step descent after 8
steps was still $1.28$ away. That one-step exactness is also the
weakness: the inverse Hessian is $d times d$ and only local, so the
workhorse middle ground is a descent direction with a searched step
length. Along $bold(d) = -nabla f$ on a quadratic, the exact minimizer
of $f(bold(x) + t bold(d))$ is closed form, $t^* = (bold(d) dot
bold(d)) \/ (bold(d)^top bold(Q) bold(d))$: from $bold(x)_0$ it pins
at $t^* = 820\/14432 = 5\/88 = 0.0568182$, landing on $(-51/22, 21/44)$
with $f = 735\/44 = 16.7045$. Backtracking approximates the same thing
with evaluations only: halve $t$ from 1 until the armijo inequality
$f(bold(x) + t bold(d)) <= f(bold(x)) + c t dot nabla f dot bold(d)$
holds, here 4 rejections down to $t = 1\/16$ and $f = 271\/16 =
16.9375$, above the exact search but found without knowing $bold(Q)$.

#listing("math/samples/src/Ch11/newtonopt.c", first: 92, last: 115, caption: [the one-step hessian solve and the closed-form line search])
#listing("math/samples/src/Ch11/newtonopt.c", first: 117, last: 130, caption: [armijo backtracking, 4 halvings to the accepted step])

The two-number play: after 6 newton steps the log error is $-15$, after
8 fixed-gradient steps at $gamma = 0.008$ it is $-3.5$.

#diagram([log10 error per step: newton's squaring cliff versus the fixed-step straight line], length: 13pt, {
  let kx(k) = 1.0 + k * 1.35
  let ey(e) = 5.6 - (1.0 - e) * 0.28
  let gd = ((0, 0.18), (1, -1.40), (2, -1.71), (3, -2.02), (4, -2.32), (5, -2.63), (6, -2.93), (7, -3.23), (8, -3.54))
  let nw = ((0, 0.18), (1, -0.26), (2, -0.96), (3, -2.25), (4, -4.78), (5, -9.84), (6, -15.05))
  cdraw.line((1.0, ey(0.0)), (12.0, ey(0.0)), stroke: luma(140))
  for t in (0, -4, -8, -12, -16) {
    cdraw.line((1.0, ey(t)), (0.85, ey(t)), stroke: luma(100))
    cdraw.content((0.6, ey(t)), [#t], size: 6pt)
  }
  for i in range(gd.len() - 1) {
    let a = gd.at(i)
    let b = gd.at(i + 1)
    cdraw.line((kx(a.first()), ey(a.at(1))), (kx(b.first()), ey(b.at(1))), stroke: (paint: luma(150), dash: "dashed"))
  }
  for i in range(nw.len() - 1) {
    let a = nw.at(i)
    let b = nw.at(i + 1)
    cdraw.line((kx(a.first()), ey(a.at(1))), (kx(b.first()), ey(b.at(1))), stroke: luma(60), mark: (end: ">"))
  }
  for p in nw {
    cdraw.circle((kx(p.first()), ey(p.at(1))), radius: 0.07, fill: luma(205))
  }
  cdraw.content((kx(6), ey(-15.05) + 0.45), [newton], size: 6pt)
  cdraw.content((kx(8), ey(-3.54) - 0.4), [fixed step], size: 6pt)
  cdraw.content((12.0, ey(0.0) + 0.3), [step k], size: 6pt)
})

== constrained optimization and lagrange multipliers

Reality adds side conditions: minimize $f(bold(x))$ subject to $g_i
(bold(x)) <= 0$ (mml eq 7.17). The book's move is to replace the
infinite penalty for violated constraints with a linear one, the
lagrangian (mml eq 7.20)

$ L(bold(x), lambda) = f(bold(x)) + sum_(i=1)^m lambda_i g_i (bold(x)), quad lambda_i >= 0, $

and then trade variables: the primal problem in $bold(x)$ becomes the
dual problem $max_(lambda >= 0) D(lambda)$ with $D(lambda) =
min_bold(x) L(bold(x), lambda)$. Weak duality is one line: $L$ with
$lambda >= 0$ never exceeds the penalized original, so maximizing the
lower bound and then minimizing can only understate the optimum, and
the gap closes exactly for the convex programs of the next section.
Equality constraints $h(bold(x)) = 0$ join as two inequalities, which
leaves their multipliers unconstrained.

The pinned fixture is $min x^2 + 2y^2$ subject to $2x + y = 5$. The
lagrangian is $L = x^2 + 2y^2 + lambda (2x + y - 5)$ and the
stationarity system is three linear equations.

The dry run: eliminate by hand before any code.

+ $partial L \/ partial x = 2x + 2 lambda = 0$ gives $x = -lambda$.
+ $partial L \/ partial y = 4y + lambda = 0$ gives $y = -lambda\/4$.
+ The constraint then reads $-2lambda - lambda\/4 = 5$, so $lambda =
  -20/9$, $x = 20/9$, $y = 5/9$, and $f^* = 50/9 = 5.5556$.

#listing("math/samples/src/Ch11/lagrange.c", first: 41, last: 77, caption: [the 3x3 stationarity system solved by cramer determinants])
#listing("math/samples/src/Ch11/lagrange.c", first: 84, last: 113, caption: [the rational pins, the gradient alignment, and the cost of sliding along the constraint])

The geometric reading is where the multiplier stops being bookkeeping:
at the optimum $nabla f = (2x, 4y) = (40/9, 20/9)$ and $nabla h = (2,
1)$, and the cross product is exactly zero, pinned to $10^(-12)$. Level
sets of the objective are ellipses, the constraint is a line, and the
constrained optimum is the tangency: moving along the line to first
order changes nothing, which is only possible when the objective's
gradient is perpendicular to the line's direction, that is, parallel to
$nabla h$. The relation $nabla f = -lambda nabla h$ with $lambda =
-20/9$ is that alignment as an equation, and sliding $(x + t, y - 2t)$
along the line costs exactly $9t^2$: $131/9$ at $t = 1$, $f^* + 9/4$
at $t = 1/2$.

#diagram([the tangency: level ellipses of the objective against the constraint line, gradients aligned at the optimum], length: 13pt, {
  let px(u) = 6.5 + u * 1.15
  let py(v) = 3.3 + v * 0.78
  let e1 = ((2.36, 0.0), (2.18, 0.64), (1.67, 1.18), (0.9, 1.54), (0.0, 1.67), (-0.9, 1.54), (-1.67, 1.18), (-2.18, 0.64), (-2.36, 0.0), (-2.18, -0.64), (-1.67, -1.18), (-0.9, -1.54), (0.0, -1.67), (0.9, -1.54), (1.67, -1.18), (2.18, -0.64), (2.36, 0.0))
  let e2 = ((3.46, 0.0), (3.2, 0.94), (2.45, 1.73), (1.33, 2.26), (0.0, 2.45), (-1.33, 2.26), (-2.45, 1.73), (-3.2, 0.94), (-3.46, 0.0), (-3.2, -0.94), (-2.45, -1.73), (-1.33, -2.26), (0.0, -2.45), (1.33, -2.26), (2.45, -1.73), (3.2, -0.94), (3.46, 0.0))
  let e3 = ((4.47, 0.0), (4.13, 1.21), (3.16, 2.24), (1.71, 2.92), (0.0, 3.16), (-1.71, 2.92), (-3.16, 2.24), (-4.13, 1.21), (-4.47, 0.0), (-4.13, -1.21), (-3.16, -2.24), (-1.71, -2.92), (0.0, -3.16), (1.71, -2.92), (3.16, -2.24), (4.13, -1.21), (4.47, 0.0))
  for e in (e3, e2, e1) {
    for i in range(e.len() - 1) {
      let a = e.at(i)
      let b = e.at(i + 1)
      cdraw.line((px(a.first()), py(a.at(1))), (px(b.first()), py(b.at(1))), stroke: luma(140))
    }
  }
  cdraw.line((px(0.8), py(3.4)), (px(4.2), py(-3.4)), stroke: luma(60))
  cdraw.circle((px(2.222), py(0.556)), radius: 0.09, fill: luma(60))
  cdraw.content((px(1.6), py(-0.6)), [optimum (20/9, 5/9)], size: 6pt)
  cdraw.line((px(2.222), py(0.556)), (px(3.42), py(1.156)), stroke: luma(100), mark: (end: ">"))
  cdraw.content((px(3.9), py(2.3)), [$nabla h = (2, 1)$], size: 6pt)
  cdraw.line((px(2.102), py(0.496)), (px(2.802), py(0.846)), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((px(1.0), py(0.85)), [$nabla f$], size: 6pt)
  cdraw.content((px(0.8), py(3.4) + 0.3), [2x + y = 5], size: 6pt)
})

Inequalities get the same machinery with a sign condition, the kkt
system: stationarity of the lagrangian, feasibility, multipliers
$lambda >= 0$, and complementary slackness $lambda_i g_i = 0$, meaning
only tight constraints may carry a nonzero multiplier. The pinned
example is mml example 7.6, the quadratic $1/2 bold(x)^top mat(2, 1; 1,
4) bold(x) + (5, 3)^top bold(x)$ on the box $|x_i| <= 1$. Its
unconstrained minimum sits at $-bold(Q)^(-1) bold(c) = (-17/7, -1/7)$
with value $-44/7$, which is also the dual value $D(0)$, and the box
clips it to $(-1, -1/2)$ with value $-9/2$. There the gradient pins at
$(5/2, 0)$: the free coordinate has zero slope, and the active bound
$-x_1 <= 1$ absorbs the remaining $5/2$ through its multiplier,
exactly the kkt ledger with all other multipliers at zero.

#listing("math/samples/src/Ch11/lagrange.c", first: 115, last: 140, caption: [the box qp: clip, gradient readout, and the kkt multiplier ledger])

The two-number play: the constraint costs $25/14$, unconstrained
$-44/7 = -6.286$ versus clipped $-9/2 = -4.5$.

== convex sets and functions

Convexity is the property that removes local traps. A set is convex
when it contains every segment between its points, and a function is
convex when its domain is such a set and chords never dip below the
graph, mml definitions 7.2 and 7.3: for $0 <= theta <= 1$,

$ f (theta bold(x) + (1 - theta) bold(y)) <= theta f(bold(x)) + (1 - theta) f(bold(y)). $

The same inequality read at a weighted average is Jensen's inequality
in mml's phrasing, "a whole class of inequalities for taking
nonnegative weighted sums of convex functions are all called Jensen's
inequality", and it is the one-line consequence of the definition. Two
more equivalences make it checkable: the first-order one, $f(bold(y))
>= f(bold(x)) + nabla f(bold(x))^top (bold(y) - bold(x))$, every
tangent plane a global lower bound (mml eq 7.31), and the second-order
one: a twice-differentiable $f$ is convex if and only if its Hessian
is positive semidefinite everywhere. The descent quadratic's Hessian
$mat(2, 1; 1, 20)$ has eigenvalues $11 plus.minus sqrt(82) = 1.9446$
and $20.0554$, both positive, so that bowl is convex, which is why its
only stationary point, the $(97/39, 1/39)$ every method in this
chapter walked toward, is its global minimum.

The dry run: negative entropy $f(x) = x log_2 x$ is convex for $x > 0$
(mml example 7.3), and both tests pin on it at $x = 2$, $y = 4$.

+ Midpoint: $f(3) = 3 log_2 3 = 4.75489$ while the chord reads $0.5
  f(2) + 0.5 f(4) = 1 + 4 = 5$, so the definition holds by $0.245$.
+ Tangent: $f(2) + f'(2)(4 - 2) = 2 + 2 (1 + 1\/ln 2) = 6.88539 <= 8 =
  f(4)$, with $f'(x) = log_2 x + 1\/ln 2$ pinning at $2.44270$.
+ The quartic fails the same midpoint test by $43.71$: at the midpoint
  of its two minima the graph sits at $18.257$ over a chord at
  $-25.457$, the measured face of nonconvexity.

#listing("math/samples/src/Ch11/programs.c", first: 125, last: 156, caption: [midpoint and tangent tests for the entropy, the quartic violation, and the hessian eigenvalues])

Closure extends the class: "A nonnegative weighted sum of convex
functions is convex" (mml example 7.4), so sums of squared errors and
nonnegative combinations inherit the property for free. And the payoff
for optimization: if $f$ is convex and differentiable and $nabla
f(bold(x)^*) = 0$, then the tangent bound at that point says
$f(bold(y)) >= f(bold(x)^*)$ for every $bold(y)$, so a stationary
point of a convex differentiable function is automatically a global
minimum. For convex programs, where the objective and inequality
constraints are convex and the equality constraints cut convex sets,
mml states strong duality: the dual optimum equals the primal optimum,
and the search that opened this chapter, over basins and starts,
collapses to finding one stationary point.

#diagram([the chord test: entropy passes by 0.245, the quartic fails by 43.71], length: 13pt, {
  let ax(u) = 0.7 + (u - 1.8) * 2.5
  let ay(v) = 0.6 + v * 0.52
  let ent = ((2.0, 2.0), (2.5, 3.3), (3.0, 4.755), (3.5, 6.32), (4.0, 8.0))
  for i in range(ent.len() - 1) {
    let a = ent.at(i)
    let b = ent.at(i + 1)
    cdraw.line((ax(a.first()), ay(a.at(1))), (ax(b.first()), ay(b.at(1))), stroke: luma(60))
  }
  cdraw.line((ax(2.0), ay(2.0)), (ax(4.0), ay(8.0)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((ax(3.0), ay(4.755)), radius: 0.08, fill: luma(60))
  cdraw.line((ax(3.0), ay(4.755)), (ax(3.0), ay(5.0)), stroke: luma(100))
  cdraw.content((2.6, 2.15), [4.755 < 5], size: 6pt)
  cdraw.line((0.7, ay(0.0)), (6.3, ay(0.0)), stroke: luma(140))
  cdraw.content((ax(3.0), ay(0.0) + 0.35), [x log2 x convex], size: 6pt)
  let bx(u) = 7.1 + (u + 4.6) * 1.05
  let by(v) = 0.6 + (v + 50.0) * 0.065
  let qrt = ((-4.5, -47.1), (-4.25, -45.5), (-4.0, -41.0), (-3.75, -34.3), (-3.5, -26.3), (-3.25, -17.7), (-3.0, -9.0), (-2.75, -0.8), (-2.5, 6.4), (-2.25, 12.5), (-2.0, 17.0), (-1.75, 19.9), (-1.5, 21.2), (-1.25, 20.8), (-1.0, 19.0), (-0.75, 15.9), (-0.5, 11.9), (-0.25, 7.5), (0.0, 3.0), (0.25, -0.8), (0.5, -3.3), (0.662, -3.84))
  for i in range(qrt.len() - 1) {
    let a = qrt.at(i)
    let b = qrt.at(i + 1)
    cdraw.line((bx(a.first()), by(a.at(1))), (bx(b.first()), by(b.at(1))), stroke: luma(60))
  }
  cdraw.line((bx(-4.4803), by(-47.07)), (bx(0.662), by(-3.84)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((bx(-1.9089), by(18.257)), radius: 0.08, fill: luma(60))
  cdraw.content((8.7, 5.55), [18.26 vs -25.46], size: 6pt)
  cdraw.line((7.1, by(-47.5)), (12.7, by(-47.5)), stroke: luma(140))
  cdraw.content((9.3, 1.15), [quartic not convex], size: 6pt)
})

== programs: linear and quadratic

Two program families close the chapter, both convex. A linear program
minimizes a linear objective over linear inequalities, $min bold(c)^top
bold(x)$ subject to $bold(A) bold(x) <= bold(b)$ (mml eq 7.39), and
mml's margin calls it "one of the most widely used approaches in
industry". Its dual (mml eq 7.43) is another linear program in the
multipliers, $max -bold(b)^top lambda$ subject to $bold(c) +
bold(A)^top lambda = 0$ and $lambda >= 0$, so the solver can pick
whichever side has fewer variables. The geometry: a feasible
polytope, and an optimum at a vertex, because a linear objective has
no interior curvature to reward. In 2 variables, vertex enumeration is
the whole solver: cross every pair of constraint lines, keep the
feasible crossings, read off the best.

The dry run: our own fixture (the mml draft's example 7.5 figure
carries a known sign inconsistency in one constraint row, so this
chapter rolls its own): minimize $-2x_1 - 3x_2$ subject to $x_1 + x_2
<= 5$, $x_1 <= 3$, $x_2 <= 4$, $x_1 >= 0$, $x_2 >= 0$.

+ The 5 constraint rows pair into 10 combinations, 8 of which cross
  (rows 2 and 4, and rows 3 and 5, are parallel), and 5 of those
  crossings are feasible corners: $(0,0)$, $(3,0)$, $(3,2)$, $(1,4)$,
  $(0,4)$.
+ The corner $(3, 4)$ is crossed out by the budget row, $3 + 4 = 7 >
  5$, cut off by exactly 2.
+ Evaluating the objective at the survivors, $0, -6, -12, -14, -12$,
  the optimum is the vertex $(1, 4)$ with value $-14$, the crossing of
  rows 1 and 3.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*vertex*], [*$-2x_1 - 3x_2$*], [*status*]),
  [(0, 0)], [0], [feasible],
  [(3, 0)], [-6], [feasible],
  [(3, 2)], [-12], [feasible],
  [(1, 4)], [-14], [optimal],
  [(0, 4)], [-12], [feasible],
  [(3, 4)], [--], [cut by row 1],
)

#listing("math/samples/src/Ch11/programs.c", first: 49, last: 84, caption: [the lp solved by pair crossing and feasibility filtering])

#diagram([the feasible pentagon with level lines of the objective sliding to the optimal vertex], length: 13pt, {
  let px(u) = 1.0 + u * 2.6
  let py(v) = 0.7 + v * 1.15
  let poly = ((0.0, 0.0), (3.0, 0.0), (3.0, 2.0), (1.0, 4.0), (0.0, 4.0), (0.0, 0.0))
  for i in range(poly.len() - 1) {
    let a = poly.at(i)
    let b = poly.at(i + 1)
    cdraw.line((px(a.first()), py(a.at(1))), (px(b.first()), py(b.at(1))), stroke: luma(60))
  }
  for v in ((0.0, 0.0), (3.0, 0.0), (3.0, 2.0), (1.0, 4.0), (0.0, 4.0)) {
    cdraw.circle((px(v.first()), py(v.at(1))), radius: 0.08, fill: luma(205))
  }
  cdraw.line((px(-0.2), py(4.8)), (px(3.6), py(2.27)), stroke: luma(100))
  cdraw.line((px(-0.2), py(2.8)), (px(3.6), py(0.27)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(3.7), py(1.6)), [level -14], size: 6pt)
  cdraw.content((px(3.7), py(0.9)), [level -8], size: 6pt)
  cdraw.circle((px(1.0), py(4.0)), radius: 0.1, fill: luma(60))
  cdraw.content((px(1.0), py(4.0) + 0.35), [(1, 4), value -14], size: 6pt)
  cdraw.content((px(3.0), py(0.0) - 0.35), [(3, 0)], size: 6pt)
  cdraw.content((px(3.0) + 0.45, py(2.0) + 0.15), [(3, 2)], size: 6pt)
  cdraw.content((px(-0.1), py(4.0) + 0.35), [(0, 4)], size: 6pt)
  cdraw.content((px(0.0) - 0.2, py(0.0) - 0.35), [(0, 0)], size: 6pt)
})

A quadratic program keeps the linear constraints but minimizes $1/2
bold(x)^top bold(Q) bold(x) + bold(c)^top bold(x)$ with $bold(Q)$
positive definite (mml eq 7.45), convex by the second-order test since
its Hessian is $bold(Q)$ itself. The unconstrained minimizer is the
closed form $-bold(Q)^(-1) bold(c)$ from the lagrange section, and the
whole objective rearranges by completion of squares into $1/2
(bold(x) - bold(m))^top bold(Q) (bold(x) - bold(m)) - 44/7$ with
$bold(m) = (-17/7, -1/7)$: the constant is the unconstrained value,
the quadratic term is nonnegative, and the sample pins the identity at
4 probe points. On the unit box the clipped point $(-1, -1/2)$ carries
the kkt certificate from the previous section, and a 401 by 401 grid
scan of the box confirms no feasible point beats $-9/2$.

#listing("math/samples/src/Ch11/programs.c", first: 85, last: 107, caption: [the qp as completed squares, the center and constant pinned])

#callout("verify", "THE GRID IS THE LIE DETECTOR", [Algebra says the clipped point is optimal, and the kkt multipliers certify it, but a 401 by 401 sweep of the box is the check that needs no theory: its minimum pins at exactly -9/2 with the argmin within 0.01 of (-1, -1/2). When a certificate and a brute-force sweep agree, the fixture is trustworthy. This is the same discipline as #xref-to("math", "multivariate") gradient checking by finite differences.])

The two-number play: the lp reads its answer off 5 vertices, the qp
pays $25/14$ for its box. Where these programs meet adversaries,
zero-sum games solve to the same linear structure, which is
#xref-to("math", "strategic") territory, and where objectives stop
being hand-differentiable, the gradients that feed every method in
this chapter come from #xref-to("math", "autodiff"), the next chapter.

sources: mml-book draft 2024-01-15 (Deisenroth, Faisal, Ong,
"Mathematics for Machine Learning"), ch 7 continuous optimization,
sections 7.1-7.3 [printed pp 227-246 / pdf pp 233-252] and the ch 7
opener [printed pp 225-226 / pdf pp 231-232], read through the
verified anchor sheet ref/mml/anchors-calc.md (53 numpy recomputes),
no further pdf cross-verification per the coordinator dispatch naming
the sheet as this chapter's authority, all definitions quoted from that
sheet, our own
words and code throughout. The mml draft's example 7.5 (eq 7.44)
carries the sheet's documented sign inconsistency, so all lp fixtures
here are our own. Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/math/samples/src -Chapter Ch11`, 81 checks in chapter 11 of the
math suite (descent 19, lagrange 19, newtonopt 23, programs 20), zero
skipped, format and asan clean.
