#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= quadrature and differential equations

Chapter #xref-to("math", "univariate") proved the fundamental theorem that
turns an integral into an antiderivative evaluation, and chapter
#xref-to("math", "interp") built the polynomials that stand in for
functions without closed forms. This chapter spends those assets twice.
First quadrature: approximate the integral itself when no antiderivative
is available, with error ladders you can predict to four digits. Then
differential equations: step a state forward in time, where the same
discretization question decides whether a simulation decays like the
physics or blows up by a factor of a million in three steps. Six moves:
composite trapezoid and simpson with their $h^2$ and $h^4$ error ladders
measured against the FTC truth, adaptive simpson that subdivides where
the integrand actually lives, explicit and implicit euler against a stiff
system, classic runge-kutta 4 with the cost and determinism story the
physics capstone needs, absolute stability regions on the complex plane,
and the symplectic leapfrog integrator the capstone's fixed-timestep
core is built from. Every behavioral claim below is one of the 58 checks
in the 4 samples of chapter 22 or a sentence quoted from a canonical
source fetched 2026-09-22. Chapter #xref-to("dsa", "numerical") of the
dsa book drives simpson as a contest tool, this chapter is the error and
stability theory under it plus the entire ode half.

== composite quadrature

The problem: approximate $integral_a^b f(x) dif x$ from node values
$f(x_0), ..., x_n$ spaced $h = (b - a)\/n$ apart. The composite
trapezoid rule chords each panel,

$ T_n = h (1\/2 f(x_0) + f(x_1) + dots.c + f(x_(n-1)) + 1\/2 f(x_n)), $

and the composite simpson rule fits a parabola through each pair of
panels, which collapses to alternating weights 1, 4, 2, 4, ..., 4, 1
over a double interval of width $2h$ (DLMF §3.5(i) and (ii), fetched
2026-09-22). Chapter #xref-to("math", "inner") already used these
weights as an inner product with 4000 panels, here they arrive with
their price tags.

The fixture is $integral_0^1 e^x dif x$, chosen because chapter
#xref-to("math", "univariate") proved the antiderivative of $e^x$ is
$e^x$, so the truth is $e - 1 = 1.718281828459045$ to the last bit.

The dry run: with $n = 2$, $h = 0.5$, and nodes 0, 0.5, 1, the
trapezoid sum is $0.5 (0.5 + 1.6487212707 + 1.3591409142) =
1.7539310925$, an error of 3.6e-2. Simpson on the same three nodes
takes $1\/6 (1 + 4 dot 1.6487212707 + 2.7182818285) = 1.7188611519$,
an error of 5.8e-4: the same evaluations, 61.5 times closer. On $f(x) =
x^3$ with $n = 2$, simpson lands on exactly 0.25, not approximately:
the parabola through the three nodes of a cubic on a double interval
interpolates the cubic itself, so a rule built from degree 2 pieces
integrates degree 3 exactly, the one order of accuracy simpson gets for
free.

Halving $h$ exposes the rates. The measured ladders:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*$n$*], [*trapezoid error*], [*simpson error*], [*ratio*]),
  [1], [1.409e-1], [], [],
  [2], [3.565e-2], [5.793e-4], [],
  [4], [8.940e-3], [3.701e-5], [$15.7 x$],
  [8], [2.237e-3], [2.326e-6], [$15.9 x$],
  [16], [5.593e-4], [1.456e-7], [$16.0 x$],
)

The trapezoid column divides by 4 per row, simpson by 16: errors like
$c h^2$ and $c h^4$. Euler-maclaurin supplies the constants too: the
leading error terms are $h^2\/12 (f'(b) - f'(a))$ and $h^4\/180
(f'''(b) - f'''(a))$, which on this fixture are $(e - 1) h^2 \/12$ and
$(e - 1) h^4 \/180$. At $n = 16$ those predictions give 5.5934e-4 and
1.4566e-7 against the measured 5.593e-4 and 1.456e-7: four digits
from a two-term expansion. Two numbers to keep: at 16 panels simpson is
3841 times closer to the truth than trapezoid on the same nodes, and
its ladder collapses 16-fold per doubling while trapezoid manages 4.

#listing("math/samples/src/Ch22/quadrature.c", first: 52, last: 66, caption: [quadrature.c, the composite trapezoid and simpson sums, both pure weightings of the same node values])

#diagram([the e^x fixture with 4 trapezoid chords and the first simpson parabola over [0, 0.5]], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.000, 0.600), (2.000, 0.973), (3.000, 1.395), (4.000, 1.874), (5.000, 2.416), (6.000, 3.031), (7.000, 3.728), (8.000, 4.517), (9.000, 5.411)), luma(140))
  poly(((1.000, 0.600), (3.000, 1.395), (5.000, 2.416), (7.000, 3.728), (9.000, 5.411)), luma(60))
  poly(((1.000, 0.600), (1.500, 0.778), (2.000, 0.969), (2.500, 1.175), (3.000, 1.395), (3.500, 1.629), (4.000, 1.878), (4.500, 2.140), (5.000, 2.416)), (paint: luma(100), dash: "dashed"))
  cdraw.line((0.7, 0.3), (9.4, 0.3), stroke: luma(100), mark: (end: ">"))
  for x in ((1.000, 0.600), (3.000, 1.395), (5.000, 2.416), (7.000, 3.728), (9.000, 5.411)) {
    cdraw.circle(x, radius: 0.09, fill: luma(30), stroke: none)
  }
  cdraw.content((9.55, 5.55), [$e^x$], size: 6.5pt)
  cdraw.content((7.0, 2.1), [chords], size: 6pt)
  cdraw.content((2.6, 2.1), [first parabola], size: 6pt)
  cdraw.content((1.0, -0.1), [0], size: 6pt)
  cdraw.content((5.0, -0.1), [0.5], size: 6pt)
  cdraw.content((9.0, -0.1), [1], size: 6pt)
})

#callout("pitfall", "SIMPSON NEEDS AN EVEN PANEL COUNT",
  [The alternating 1, 4, 2, ..., 4, 1 weights tile double intervals, so an
  odd $n$ leaves a stranded panel and the formula has no last weight to
  give it. The ladder cannot hit that trap by construction: $n$ doubles
  from 2, so every rung is even structurally. What the sample does pin at
  compile time is the depth of that ladder: the rung count is derived
  from the pinned value array and a `static_assert` demands at least
  three rungs, because the $h^4$ ratio needs two halvings to be measured
  at all.])

== adaptive quadrature

A tolerance flips the question from how accurate to when to stop. The
adaptive idea: compute simpson on an interval and on its two halves,
compare, and treat the difference as the error estimate. When simpson
refines, its error drops by $2^4 = 16$, so the difference $|S_2 - S|$
between coarse and refined values overstates the finer error by a factor
of about 15, and $|S_2 - S|\/15$ is the standard estimate. Subdivide
while $|S_2 - S| > 15 "tol"$, halving the tolerance with the interval
width.

The dry run: on the runge bell $1\/(1 + 25 x^2)$ from chapter
#xref-to("math", "interp"), integrated over $[-1, 1]$, the initial
coarse simpson is $(1\/3)(0.0385 + 4 + 0.0385) = 1.358974$ while its
refinement into halves gives $0.265031 + 0.265031 = 0.530062$. The gap
is enormous, so the root splits, and the leftmost chain keeps splitting
until the interval $[-1, -0.875]$ accepts at depth 4 with $S = 0.005463$
against a refinement gap inside $15 dot 10^-6\/16$. The true value of
that leaf is pinned, and by symmetry the last leaf of the run mirrors
it: the accepted trace is 30 leaves wide, 121 function evaluations,
final error 6.3e-10 against a requested $10^-6$.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*leaf*], [*interval*], [*depth*], [*width*]),
  [1], [$[-1, -0.875]$], [4], [0.125],
  [2], [$[-0.875, -0.75]$], [4], [0.125],
  [5], [$[-0.5, -0.4375]$], [5], [0.0625],
  [10], [$[-0.1875, -0.15625]$], [6], [0.03125],
  [15], [$[-0.03125, 0]$], [6], [0.03125],
  [30], [$[0.875, 1]$], [4], [0.125],
)

The bell is smooth everywhere, so the census stays shallow and uniform
simpson at $n = 128$ (129 evaluations) enters the same tolerance: no
prize for adaptivity. The spike fixture $1\/(1 + 10000 (x - 0.7)^2)$ is
where the method earns its recursion. Adaptive simpson honors $10^-6$
with 153 evaluations, 38 leaves, 34 of them intersecting $(0.55, 0.85)$
where the spike lives, refining to depth 9, a leaf width of $1\/512$
around 0.7. Uniform simpson needs $n = 512$, 513 evaluations, to enter
the same tolerance: $n = 256$ misses at 5.45e-6. The two numbers of
the section: 153 adaptive evaluations against 513 uniform ones, and a
subdivision census that puts 34 of 38 leaves where the integrand
actually is.

#listing("math/samples/src/Ch22/quadrature.c", first: 86, last: 113, caption: [quadrature.c, the adaptive recursion, two fresh evaluations per call and the 15-fold error estimate that decides acceptance])

#diagram([the spike fixture true to scale with its leaf intervals stacked by depth below, the census clustering under 0.7, the depth 9 bar enlarged to stay visible], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.0, 0.10), (1.4, 0.10), (1.8, 0.10), (2.2, 0.10), (2.6, 0.10), (3.0, 0.10), (3.4, 0.10), (3.8, 0.10), (4.2, 0.10), (4.6, 0.11), (5.0, 0.11), (5.4, 0.11), (5.8, 0.13), (6.2, 0.22), (6.6, 3.30), (7.0, 0.22), (7.4, 0.13), (7.8, 0.11), (8.2, 0.11), (8.6, 0.11), (9.0, 0.10)), luma(60))
  cdraw.line((0.7, 0.02), (9.3, 0.02), stroke: luma(100), mark: (end: ">"))
  let bar(a, b, y, f) = {
    cdraw.rect((a, y), (b, y + 0.22), fill: f, stroke: luma(100))
  }
  bar(1.0, 3.0, -0.5, luma(235))
  bar(3.0, 4.0, -1.0, luma(235))
  bar(4.0, 5.0, -1.0, luma(235))
  bar(5.0, 5.5, -1.5, luma(235))
  bar(5.5, 5.75, -2.0, luma(235))
  cdraw.content((4.9, -2.2), [dots], size: 6pt, frame: none)
  bar(6.52, 6.72, -2.5, luma(205))
  cdraw.content((7.55, -2.72), [[1/512 wide]], size: 6pt, frame: none)
  cdraw.content((0.4, -0.4), [d2], size: 6pt)
  cdraw.content((0.4, -0.9), [d3], size: 6pt)
  cdraw.content((0.4, -1.4), [d4], size: 6pt)
  cdraw.content((0.4, -1.9), [d5], size: 6pt)
  cdraw.content((0.4, -2.4), [d9], size: 6pt)
  cdraw.content((6.6, 3.6), [spike], size: 6pt)
  cdraw.content((9.0, -0.16), [1], size: 6pt)
  cdraw.content((6.6, -0.16), [0.7], size: 6pt)
  cdraw.content((1.0, -0.16), [0], size: 6pt)
})

#callout("note", "TOLERANCE HONORED IS NOT TOLERANCE GUARANTEED",
  [The $|S_2 - S|\/15$ estimate is a heuristic about smooth integrands,
  not a bound. Both fixtures here honor their tolerance with room, errors
  6.3e-10 and 3.4e-8 against a requested $10^-6$, but a proof of
  error needs interval arithmetic or a priori bounds on high derivatives.
  Chapter #xref-to("dsa", "numerical") pins its stopping rules the same
  way: measured, not assumed.])

== euler and the stability question

Quadrature discretizes space, an initial value problem discretizes time.
The state $y' = f(t, y)$, $y(0) = y_0$ steps by explicit euler
$y_(n+1) = y_n + h f(t_n, y_n)$, one line of code, and everything wrong
with numerical simulation starts here.

For the linear decay $y' = -25 y$, one step multiplies the state by the
amplification factor $1 + h lambda$ with $lambda = -25$: the fixed
point of this chapter. The step decays exactly when $|1 + h lambda| < 1$,
which for real negative $lambda$ is $h < 2\/|lambda| = 0.08$. The
boundary is not asymptotic folklore, it is exact, and the sample pins
both sides of it.

The dry run: at $h = 0.081$ the factor is $1 - 25 dot 0.081 =
-1.025$, and three steps give $-1.025, +1.0506, -1.0769$, oscillating
and growing. At $h = 0.08$ the factor is exactly $-1.0$ in binary
floating point: the orbit is $(-1)^n$, pinned at $y_10 = 1.0$ exactly,
marginal, neither decaying nor growing. At $h = 0.079$ the factor is
$-0.975$ and $y_10 = 0.7763$.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*$h$*], [*factor*], [*$y_10$ from $y_0 = 1$*], [*exact at $t = 10 h$*]),
  [0.079], [$-0.975$], [$0.7763$], [2.65e-9],
  [0.080], [$-1.0$], [$1.0$], [2.06e-9],
  [0.081], [$-1.025$], [$1.2801$], [1.61e-9],
)

Stiffness is what happens when the interesting timescale and the
stability timescale disagree. Take the 2x2 system with matrix rows
$(-1001, 999)$ and $(999, -1001)$: its eigenvalues are $-2$ and $-2000$
(the symmetric formula $(a_11 + a_22)\/2 plus.minus (a_12 + a_21)\/2$
from chapter #xref-to("math", "matrices")), a stiffness ratio of 1000.
The slow mode wants $h$ near 0.1 for accuracy, the fast mode demands $h
< 0.001$ for explicit stability. At $h = 0.1$ explicit euler's fast-mode
factor is $-199$: after three steps the state is $(-3940299.2,
3940299.8)$, norm 5.57e6 from a start of norm 1, all of it at $t = 0.3$.
The two numbers: 5.57 million against a truth of 0.274 per component.

Implicit euler removes the barrier by hiding the new state in a linear
system: $y_(n+1) = y_n + h bold(A) y_(n+1)$ rearranges to $(bold(I) - h
bold(A)) y_(n+1) = y_n$, one 2x2 solve per step by the cramer route of
chapter #xref-to("math", "matrices"). At $h = 0.1$, ten steps land on
$(0.080753, 0.080753)$ with the components bit-for-bit equal. The start
$(1, 0)$ is not symmetric, so the equality has a mechanism worth
naming: the components are the symmetric mode plus and minus the
antisymmetric half-difference, which starts at 0.5 and shrinks by the
factor $1\/201$ per implicit step, the fast eigenvalue again. By step 8
it sits below half an ulp of the values it is added to, and after that
the two recurrences round to the same double every step. The true
slow-mode value at $t = 1$
is $0.0677$: implicit euler is stable at any $h$ for decaying systems,
A-stable in Dahlquist's sense (Hairer and Wanner, Solving Ordinary
Differential Equations II, Springer 1996 2nd rev ed, by name), but still
first order, and its error here is 1.3e-2.

#listing("math/samples/src/Ch22/euler.c", first: 52, last: 68, caption: [euler.c, the stiff right-hand side and the implicit step as one cramer solve of a 2x2 system])

#listing("math/samples/src/Ch22/euler.c", first: 72, last: 90, caption: [euler.c, the boundary pinned from both sides, 0.079 decays, 0.08 sits exactly on it, 0.081 grows])

#diagram([ten euler steps on the decay fixture, h = 0.081 grows to 1.28 while h = 0.079 decays toward the exact solution, flat zero on this scale], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.50, 4.60), (2.25, 0.55), (3.00, 4.70), (3.75, 0.45), (4.50, 4.81), (5.25, 0.34), (6.00, 4.92), (6.75, 0.22), (7.50, 5.04), (8.25, 0.10), (9.00, 5.16)), luma(60))
  poly(((1.50, 4.60), (2.25, 0.65), (3.00, 4.50), (3.75, 0.75), (4.50, 4.41), (5.25, 0.84), (6.00, 4.32), (6.75, 0.92), (7.50, 4.23), (8.25, 1.01), (9.00, 4.15)), (paint: luma(120), dash: "dashed"))
  cdraw.line((1.0, 2.60), (9.4, 2.60), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 5.2), [h = 0.081], size: 6pt)
  cdraw.content((9.6, 1.1), [h = 0.079], size: 6pt)
  cdraw.content((7.6, 3.1), [exact], size: 6pt)
  cdraw.content((1.5, 5.0), [$y_0$], size: 6pt)
  cdraw.content((0.9, 2.2), [0], size: 6pt)
  cdraw.content((9.0, 2.2), [10], size: 6pt)
})

#callout("pitfall", "STABLE IS NOT ACCURATE",
  [Implicit euler at $h = 0.1$ never blows up on the stiff system and
  still finishes with error 1.3e-2, twenty times the size of the answer
  it is tracking. Stability says the error stops growing, accuracy says
  how big it was allowed to be in the first place. A method earns both
  numbers separately, and only the pair means anything.])

== runge-kutta 4 and the fixed step

Explicit euler pays one derivative evaluation per step and buys one
order of accuracy. Classic runge-kutta 4 pays four evaluations and buys
four orders: sample the field at the step start, twice at the midpoint
with staged corrections, and at the end, then weight the four slopes
$1, 2, 2, 1$ over $h\/6$. The order conditions behind those weights
(twelve equations in the couplings of stages, Hairer, Nørsett and
Wanner, Solving Ordinary Differential Equations I, Springer 1993 2nd rev
ed, by name) are what make the $h^4$ ladder below appear without any
tuning.

The fixture is the logistic equation $y' = y(1 - y)$ from $y_0 = 0.5$,
whose exact solution $y(t) = 1\/(1 + e^(-t))$ gives $y(1) =
0.7310585786300049$.

The dry run: one step of $h = 0.5$. The four slopes from $(0, 0.5)$ are
$k_1 = 0.25$, then $k_2 = 0.5625 dot 0.4375 = 0.24609375$, then $k_3 =
0.246215$ off the $k_2$ midpoint, then $k_4 = 0.234845$ at the trial
end. The step lands at $0.6224551$, and the second step finishes at
$0.7310474$, error 1.12e-5: two steps, eight evaluations, already
carrying four correct digits.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*$h$*], [*steps*], [*evals*], [*error*], [*ratio*]),
  [0.5], [2], [8], [1.117e-5], [],
  [0.25], [4], [16], [7.180e-7], [$15.6 x$],
  [0.125], [8], [32], [4.512e-8], [$15.9 x$],
  [0.0625], [16], [64], [2.823e-9], [$16.0 x$],
)

The cost play settles the efficiency question: explicit euler at
$h = 1\/16$ spends 16 evaluations and ends with error 1.47e-3, rk4 at
$h = 0.5$ spends 8 evaluations and ends with error 1.12e-5, 131 times
closer on half the budget. Higher order is not decoration, it is the
cheaper ticket once accuracy matters at all.

Fixed-step determinism is the property the physics capstone in chapter
#xref-to("math", "capstone-design") is built on, and rk4 with a literal
$h$ has it: the same binary stepping the same state runs the same
instructions on the same operands, and the sample verifies a replay is
bit identical. The bookkeeping around the loop matters too: adding $h$ into a running $t$ a thousand times
at $h = 0.1$ ends at $99.9999999999986$,
while computing $t = i h$ rounds once per lookup and lands on exactly
$100.0$. One rounding beats a thousand compounded ones.

#listing("math/samples/src/Ch22/rk4.c", first: 46, last: 61, caption: [rk4.c, the two steppers side by side, four staged slopes against one])

#listing("math/samples/src/Ch22/rk4.c", first: 96, last: 124, caption: [rk4.c, the cost play, the bit-identical replay, and the time bookkeeping comparison])

#diagram([integration error against evaluation budget on the logistic fixture, log scale heights], length: 13pt, {
  cdraw.line((0.8, 0.4), (12.6, 0.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((1.7, 0.4), (1.7, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.0, 0.4), (4.4, 3.98), fill: luma(205), stroke: luma(60))
  cdraw.rect((6.0, 0.4), (8.4, 2.92), fill: luma(235), stroke: luma(60))
  cdraw.rect((10.0, 0.4), (12.4, 1.12), fill: luma(235), stroke: luma(60))
  cdraw.content((3.2, 4.25), [1.5e-3], size: 6pt)
  cdraw.content((7.2, 3.19), [1.1e-5], size: 6pt)
  cdraw.content((11.2, 1.39), [2.8e-9], size: 6pt)
  cdraw.content((3.2, 0.1), [euler, 16 evals], size: 6pt)
  cdraw.content((7.2, 0.1), [rk4, 8 evals], size: 6pt)
  cdraw.content((11.2, 0.1), [rk4, 64 evals], size: 6pt)
  cdraw.content((0.6, 4.6), [log error], size: 6pt)
})

#callout("verify", "THE DETERMINISM CLAIM, PRECISELY",
  [The replay check is equality, not a tolerance: run the same 16 steps
  twice into separate state variables and the doubles compare equal. What
  is claimed is replay determinism of one compiled binary on one
  machine, which is exactly what a fixed-timestep game loop and its
  recorded demos need. It is not a claim that another compiler or
  another evaluation order reproduces the bits.])

== stability regions

The $h < 2\/|lambda|$ boundary of the euler section generalizes to the
whole complex plane. Apply a method to $y' = lambda y$ with $lambda =
a + b i$: one step multiplies the state by an amplification $R(h
lambda)$, a polynomial in $h lambda$, and the absolute stability region
is the set where $|R(h lambda)| < 1$. For explicit euler, $R(z) = 1 +
z$, the closed description is the disk $|1 + z| < 1$ of radius 1
centered at $-1$. For rk4, $R(z) = 1 + z + z^2\/2 + z^3\/6 + z^4\/24$,
and its region reaches $z = -2.78529356$ on the real axis where euler
stops at $-2$, and $2.83 i$ on the imaginary axis where euler touches
nothing at all: $|1 + i h| = sqrt(1 + h^2) > 1$ for every $h > 0$, so
explicit euler cannot hold a pure oscillation at any step size. That
single fact is the doorway to the symplectic section.

The dry run: three probe points settle membership by hand. At $z = -1$,
the center of euler's disk, $|1 + z| = 0$, as deep inside as the plane
gets, and rk4's polynomial reads $R(-1) = 0.375$. At $z = -2.5$,
euler's amplification is $|1 - 2.5| = 1.5$, outside, while $R(-2.5) =
0.648$ stays in. Straight up the imaginary axis at $z = 2.5 i$, euler
sits at $|1 + 2.5 i| = 2.69$, far outside, and rk4 at $0.508$ is still
inside: the imaginary reach in one column.

The sample counts cells instead of drawing curves: a census over the
grid of half-integer multiples covering $[-4, 2] times [-3, 3]$, 625
points, evaluating both amplifications in cartesian form. Euler holds
45 cells, rk4 holds 209, 4.6 times the cells on this grid and about 4
times by monte carlo area, with a 1.39 times longer real-axis reach.
Against a single fast eigenvalue that reprieve is small: for $lambda =
-2000$ explicit euler must run $h < 0.001$ and rk4 $h < 0.00139$. The
thousandfold gap in the stiff system is stability against accuracy, it
binds both explicit methods equally, and only the implicit step of the
previous section removes it.

The region is a linear idea applied to nonlinear problems: what enters
the plane is $h lambda$ for each eigenvalue of the local jacobian, the
object chapter #xref-to("math", "matrices") computes for symmetric
systems. A solver
chooses its step so every eigenvalue times $h$ lands inside its
method's region, and stiffness is the diagnosis that this constraint,
not accuracy, sets the step.

#listing("math/samples/src/Ch22/rk4.c", first: 126, last: 158, caption: [rk4.c, the polynomial boundary checks and the 625-point census of both regions in cartesian arithmetic])

#diagram([the absolute stability regions on the h lambda plane at equal scale, euler a disk of radius 1 inside the rk4 region reaching past minus 2.78], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  let rk4 = ((5.000, 4.621), (4.768, 4.705), (4.018, 4.203), (3.568, 3.933), (3.155, 3.565), (2.945, 3.048), (2.911, 2.500), (2.945, 1.953), (3.155, 1.435), (3.568, 1.068), (4.018, 0.797), (4.768, 0.295), (5.000, 0.379))
  poly(rk4, luma(60))
  cdraw.line((5.000, 0.379), (5.000, 4.621), stroke: luma(60))
  poly(((5.000, 2.500), (4.900, 2.875), (4.625, 3.150), (4.250, 3.250), (3.875, 3.150), (3.600, 2.875), (3.500, 2.500), (3.600, 2.125), (3.875, 1.850), (4.250, 1.750), (4.625, 1.850), (4.900, 2.125)), luma(100))
  cdraw.circle((4.250, 2.500), radius: 0.09, fill: luma(30), stroke: none)
  cdraw.line((1.7, 2.50), (6.9, 2.50), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((5.00, 0.0), (5.00, 5.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((4.25, 2.85), [euler], size: 6pt, frame: none)
  cdraw.content((4.25, 1.4), [45 cells], size: 6pt)
  cdraw.content((6.5, 4.55), [rk4, 209 cells], size: 6pt)
  cdraw.line((6.0, 4.5), (5.1, 4.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.3, 2.12), [$-2$], size: 6pt)
  cdraw.content((2.35, 1.5), [$-2.785$], size: 6pt)
  cdraw.content((5.3, 2.15), [0], size: 6pt)
  cdraw.content((5.0, 5.15), [$2.83 i$], size: 6pt)
  cdraw.content((7.15, 2.3), [$"Re" h lambda$], size: 6pt)
  cdraw.content((5.35, -0.15), [$"Im" h lambda$], size: 6pt)
})

== symplectic integrators and the capstone core

Euler drifts on oscillations because its amplification leaves the unit
circle everywhere on the imaginary axis. The fix is not a smaller step,
it is a step that respects the geometry. Newton's second law is a
hamiltonian system: the flow in $(q, p)$ phase space preserves area, and
an integrator that preserves a discrete version of that area, a
symplectic map, cannot spiral outward or inward, it can only wobble.

The leapfrog velocity verlet step for $q' = p$, $p' = -V'(q)$ is a
half kick, a full drift, a half kick:

$ p_(n + 1\/2) = p_n - h\/2 V'(q_n), quad q_(n+1) = q_n + h p_(n + 1\/2), quad p_(n+1) = p_(n + 1\/2) - h\/2 V'(q_(n+1)). $

The dry run: the harmonic oscillator $V(q) = q^2\/2$ from $(q, p) =
(1, 0)$ with $h = 0.05$. The half kick gives $p_(1\/2) = -0.025$, the
drift gives $q_1 = 1 + 0.05 dot (-0.025) = 0.99875$, the closing half
kick gives $p_1 = -0.0499688$. The energy $E = (q^2 + p^2)\/2$ after
one step is $0.4999992$: off by 7.8e-7, and it stays off by at most
$3.125 times 10^-4 = E_0 h^2\/4$ for a thousand steps, oscillating, never
drifting. Explicit euler on the same fixture ends those thousand steps
at $E = 6.072$, a $12.14 x$ blowup that equals $0.5 (1 + h^2)^1000$
exactly, because its step matrix $[[1, h], [-h, 1]]$ is a rotation
scaled by $sqrt(1 + h^2)$ every single step. The two numbers of the
chapter: 6.072 against 0.49998 for the same fixture, same step count,
same arithmetic.

Why the bound instead of a drift: the verlet map for the oscillator is
exactly a rotation by $theta = 2 "arcsin"(h\/2)$. The sample CHECKs it:
$q_1000 = 0.9663198469605475$ matches $cos(1000 theta)$ to 1.8e-15,
and $p_1000$ matches $-sin(1000 theta) sin(theta)\/h$ to 1e-15. The
orbit stays on the circle forever, only the angular speed is slightly
wrong: $theta - h = h^3\/24$ per step, a phase drift of 5.21e-3
radians over the thousand steps. Bounded energy, drifting phase, that
is the honest trade.

Time reversibility comes free: flip $p$, run the same steps, flip $p$
again, and the round trip of 500 plus 500 steps lands on $q =
1.0000000000000016$, $p = -8.7 times 10^-16$, machine precision. The step is its
own inverse, which is what a recorded demo replay needs.

This is the capstone contract. The physics game of chapter
#xref-to("math", "capstone-design") runs a fixed $h$, integrates
positions from velocities with verlet, evaluates forces once per step
between the half kicks, and leans on three behaviors this chapter
pinned: the energy wobble held inside $3.125 times 10^-4 = E_0 h^2\/4$
across the thousand-step oscillator run instead of drifting as euler
does, every replay of the same inputs is bit identical, and the scheme
costs one force evaluation per step, euler's price with none of euler's
failure modes. What the wobble does across a full game session, and
under contact forces stacking boxes, is for the capstone's own
verification chapter to measure, not for this oscillator fixture to
claim.

#listing("math/samples/src/Ch22/symplectic.c", first: 42, last: 62, caption: [symplectic.c, the euler step that rotates and scales, and the half kick, drift, half kick of verlet])

#listing("math/samples/src/Ch22/symplectic.c", first: 78, last: 111, caption: [symplectic.c, the energy bound, the rotation formulas, and the round trip])

#diagram([the harmonic oscillator in phase space, euler spiraling out while verlet rides the circle], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((5.70, 3.00), (3.20, 3.83), (5.34, 1.21), (4.83, 5.52), (2.41, 0.50), (8.49, 4.26)), (paint: luma(100), dash: "dashed"))
  poly(((5.700, 3.000), (5.539, 3.600), (5.100, 4.039), (4.500, 4.200), (3.900, 4.039), (3.461, 3.600), (3.300, 3.000), (3.461, 2.400), (3.900, 1.961), (4.500, 1.800), (5.100, 1.961), (5.539, 2.400)), luma(140))
  poly(((5.70, 3.00), (3.49, 3.65), (4.99, 1.90), (4.69, 4.18), (3.70, 2.11), (5.66, 3.31)), luma(60))
  for x in ((3.49, 3.65), (4.99, 1.90), (4.69, 4.18), (3.70, 2.11), (5.66, 3.31)) {
    cdraw.circle(x, radius: 0.09, fill: luma(30), stroke: none)
  }
  for x in ((3.20, 3.83), (5.34, 1.21), (4.83, 5.52), (2.41, 0.50), (8.49, 4.26)) {
    cdraw.circle(x, radius: 0.09, fill: none, stroke: luma(60))
  }
  cdraw.circle((5.70, 3.00), radius: 0.09, fill: luma(30), stroke: none)
  cdraw.content((8.6, 4.7), [euler, E x 12], size: 6pt)
  cdraw.content((2.4, 4.9), [verlet, r = 1], size: 6pt)
  cdraw.content((7.5, 2.0), [1000 steps], size: 6pt)
  cdraw.content((6.5, 3.45), [start], size: 6pt)
})

The next chapter #xref-to("math", "iterative") leaves continuous time
for the fixed-point and iterative schemes that converge to answers
rather than step past them.

sources: DLMF §3.5 Quadrature, trapezoidal rules 3.5(i) and simpson's
rule 3.5(ii), https://dlmf.nist.gov/3.5, and DLMF §3.7 Ordinary
Differential Equations, runge-kutta method 3.7(v),
https://dlmf.nist.gov/3.7, both fetched 2026-09-22. Hairer, Nørsett
and Wanner, Solving Ordinary Differential Equations I: Nonstiff
Problems, Springer 1993 2nd rev ed (order conditions, absolute
stability, by name). Hairer and Wanner, Solving Ordinary Differential
Equations II: Stiff and Differential-Algebraic Problems, Springer 1996
2nd rev ed (stiffness, A-stability after Dahlquist 1963, by name).
LeVeque, Finite Difference Methods for Ordinary and Partial
Differential Equations, SIAM 2007 (stability regions per method, the
modified-equation view of leapfrog, by name). Higham, An Introduction
to Numerical Analysis, Springer 2002 2nd ed (quadrature error constants,
by name). Expected sample values computed by the playground one-off
playground/math-ch22/pin.py, python 3.14.7 double arithmetic mirroring
the C expression order, run 2026-09-22. Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/math/samples/src -Chapter Ch22`, 58 checks in chapter 22 of the
math suite, 4 files, zero failures.
