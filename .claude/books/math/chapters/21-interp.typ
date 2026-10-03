#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= interpolation and approximation

Chapter #xref-to("math", "inner") built the inner product that turns an
overdetermined system into a projection and chapter #xref-to("math",
"decomp") factored the matrices that solve systems stably. Between them
sits the question this chapter answers: given points from a function,
which polynomial should stand in for it, and what does that substitution
cost in error. Six moves: the interpolation problem as a vandermonde
linear system solved exactly in rationals and then in doubles, the
lagrange and newton forms that evaluate the same polynomial without
solving anything, the runge phenomenon where more equally spaced nodes
make the answer worse, chebyshev nodes where the same count makes it
better, cubic splines that trade one global polynomial for joined
pieces, and least squares fitting that abandons interpolation on
purpose. Every behavioral claim below is one of the 63 checks in the 4
samples of chapter 21 or a sentence quoted from a canonical source
fetched 2026-09-22. The dsa book's numerical chapter runs iterative
drivers for contest boards, this chapter is the approximation theory
those drivers lean on.

== the interpolation problem

The problem: given $n + 1$ distinct nodes $x_0, ..., x_n$ and values
$y_i = f(x_i)$, find the polynomial $p$ of degree at most $n$ with
$p(x_i) = y_i$ for every node. At most one exists, because the
difference of two candidates has $n + 1$ distinct roots and degree at
most $n$, which forces it to be the zero polynomial. One exists because
the coefficients solve a linear system: writing $p(x) = a_0 + a_1 x +
dots.c + a_n x^n$, the interpolation conditions read $bold(V) bold(a) =
bold(y)$ with the vandermonde matrix $V_(i j) = x_i^j$, and

$ "det" bold(V) = product_(i < j) (x_j - x_i) $

is nonzero whenever the nodes are distinct (the product formula is
standard, Higham, Accuracy and Stability of Numerical Algorithms, SIAM
2002, 2nd ed., by name). Uniqueness and existence in one determinant.

The dry run: the fixture is the runge function $f(x) = 1/(1 + 25 x^2)$
at the nodes $-1, 0, 1$, so $bold(y) = (1/26, 1, 1/26)$.

+ The middle row of $bold(V)$ is $(1, 0, 0)$, so it reads $a_0 = 1$
  outright.
+ The two end rows are $1 - a_1 + a_2 = 1/26$ and $1 + a_1 + a_2 =
  1/26$; subtracting them kills $a_1 = 0$, and either one gives $a_2 =
  1/26 - 1 = -25/26$.
+ The interpolant is $p(x) = 1 - 25/26 x^2$, and "det" $bold(V) = (0 -
  (-1))(1 - (-1))(1 - 0) = 2$, both pinned exactly in the sample.

The exact solve is the easy half. The vandermonde matrix of equally
spaced nodes on $[-1, 1]$ becomes a trap as $n$ grows, and the ladder
is pinned by the playground one-off (numpy 2.5.3, 2-norm):

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*degree n*], [*nodes*], [*cond(V)*], [*double-solve error*]),
  [4], [5], [23.5], [4.4 times 10^(-16)],
  [8], [9], [1.61 times 10^3], [-],
  [12], [13], [1.23 times 10^5], [-],
  [16], [17], [9.98 times 10^6], [4.1 times 10^(-8)],
)

The two-number play: the same solve, the same function, the same
machine, and between $n = 4$ and $n = 16$ the condition number climbs
six orders while the computed coefficients drift from 4.4 times
10^(-16) of the exact ones to 4.1 times 10^(-8). The exact degree 16
interpolant of this smooth bump is itself a warning: its coefficients
reach 63743.77 in magnitude, and the sample CHECKs that the double
solve picks up a real error band around the exact values.

#listing("math/samples/src/Ch21/interp.c", first: 186, last: 216, caption: [interp.c, the 3-node system solved exactly in rationals and again in doubles])

#callout("pitfall", "NEVER SOLVE VANDERMONDE IN PRODUCTION",
[The coefficient route is the demonstration, not the tool. The forms in
the next section evaluate the interpolant directly, at better cost and
without handing the answer to a matrix whose condition number grows
exponentially in the node count (Higham, by name).])

#diagram([the runge bump on three nodes and its exact parabola, agreeing at the nodes and nowhere else], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.00, 1.07), (1.50, 1.11), (2.00, 1.17), (2.50, 1.24), (3.00, 1.35), (3.50, 1.53), (4.00, 1.81), (4.50, 2.30), (5.00, 3.17), (5.50, 4.54), (6.00, 5.45), (6.50, 4.54), (7.00, 3.17), (7.50, 2.30), (8.00, 1.81), (8.50, 1.53), (9.00, 1.35), (9.50, 1.24), (10.00, 1.17), (10.50, 1.11), (11.00, 1.07)), luma(140))
  poly(((1.00, 1.07), (2.00, 2.65), (3.00, 3.87), (4.00, 4.75), (5.00, 5.27), (6.00, 5.45), (7.00, 5.27), (8.00, 4.75), (9.00, 3.87), (10.00, 2.65), (11.00, 1.07)), (paint: luma(150), dash: "dashed"))
  cdraw.line((0.6, 0.9), (11.4, 0.9), stroke: luma(100), mark: (end: ">"))
  for x in ((1.00, 1.07), (6.00, 5.45), (11.00, 1.07)) {
    cdraw.circle(x, radius: 0.09, fill: luma(30), stroke: none)
  }
  cdraw.content((6.0, 5.85), [$f$], size: 6.5pt)
  cdraw.content((9.4, 4.6), [$p$], size: 6.5pt)
  cdraw.content((1.0, 0.45), [$-1$], size: 6pt)
  cdraw.content((6.0, 0.45), [0], size: 6pt)
  cdraw.content((11.0, 0.45), [1], size: 6pt)
})

== the lagrange and newton forms

The vandermonde detour asks a matrix for coefficients. The lagrange
form writes the interpolant straight down:

$ p(x) = sum_(i=0)^n y_i L_i(x), quad L_i(x) = product_(j != i) (x - x_j) / (x_i - x_j) $

Each basis polynomial $L_i$ is degree $n$, vanishes at every node
except $x_i$, and takes the value 1 there, so the weighted sum hits
every $y_i$ by construction. The basis is also a partition of unity,
$sum_i L_i(x) = 1$, because the constant 1 is its own interpolant.

The dry run: nodes $0, 1, 2, 3$ carrying $f(x) = x^3$, evaluated at
$x = 1/2$.

+ $L_0(1/2) = ((1/2 - 1)(1/2 - 2)(1/2 - 3))\/((0 - 1)(0 - 2)(0 - 3)) =
  5/16$, and the same three quotients give $15/16, -5/16, 1/16$ for
  $L_1, L_2, L_3$.
+ The four values sum to 1, and the weighted sum is $0 dot 5/16 + 1 dot
  15/16 + 8 dot (-5/16) + 27 dot 1/16 = 1/8 = (1/2)^3$, exact in binary
  because every entry is dyadic.

The newton form reorganizes the same polynomial into nested pieces that
grow with the data. Divided differences are defined level by level,
$f[x_i, ..., x_(i+k)] = (f[x_(i+1), ..., x_(i+k)] - f[x_i, ...,
x_(i+k-1)])\/(x_(i+k) - x_i)$, and the interpolant is $p(x) = f[x_0] +
f[x_0, x_1](x - x_0) + f[x_0, x_1, x_2](x - x_0)(x - x_1) + dots.c$.
For $x^3$ at $0, 1, 2, 3$ the whole table is integers:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*values*], [*1st*], [*2nd*], [*3rd*]),
  [0, 1, 8, 27], [1, 7, 19], [3, 6], [1],
)

and $p(x) = x + 3 x (x - 1) + x (x - 1)(x - 2)$. Evaluated nested,
innermost out, at $x = 1/2$: start 1, wrap to $1 dot (1/2 - 2) + 3 =
3/2$, then $3/2 dot (1/2 - 1) + 1 = 1/4$, then $1/4 dot (1/2 - 0) + 0 =
1/8$. The trace is pinned in the sample, all dyadic.

The two-number play: one evaluation of the lagrange form at $n = 3$
costs 12 multiplied quotients in the four basis products, while the
nested newton form costs 3 multiplications after the table. The counts
generalize to $n^2$ products versus $n$. The newton table also updates
incrementally: append a node, append one difference, and the sample
CHECKs the first three coefficients do not move. Both forms reproduce
$x^3$ at the off-node probes $-0.3, 0.7, 1.9$, the uniqueness argument
of the first section as a measured fact.

#listing("math/samples/src/Ch21/interp.c", first: 263, last: 286, caption: [interp.c, lagrange basis values and the partition of unity on four nodes])

#diagram([the divided-difference triangle, its diagonal marked as the newton coefficient list], length: 13pt, {
  let box(x, y, t, hl) = {
    cdraw.rect((x - 0.55, y - 0.32), (x + 0.55, y + 0.32), fill: if hl { luma(205) } else { luma(245) }, stroke: luma(100), radius: 0.02)
    cdraw.content((x, y), t, size: 6pt)
  }
  box(2.6, 6.0, [0], true)
  box(6.0, 6.0, [1], false)
  box(9.4, 6.0, [8], false)
  box(12.8, 6.0, [27], false)
  box(4.3, 4.6, [1], true)
  box(7.7, 4.6, [7], false)
  box(11.1, 4.6, [19], false)
  box(6.0, 3.2, [3], true)
  box(9.4, 3.2, [6], false)
  box(7.7, 1.8, [1], true)
  cdraw.line((2.6, 5.68), (4.0, 4.95), stroke: luma(140), mark: (end: ">"))
  cdraw.line((6.0, 5.68), (4.6, 4.95), stroke: luma(140), mark: (end: ">"))
  cdraw.line((6.0, 5.68), (7.4, 4.95), stroke: luma(140), mark: (end: ">"))
  cdraw.line((9.4, 5.68), (8.0, 4.95), stroke: luma(140), mark: (end: ">"))
  cdraw.line((9.4, 5.68), (10.8, 4.95), stroke: luma(140), mark: (end: ">"))
  cdraw.line((12.8, 5.68), (11.4, 4.95), stroke: luma(140), mark: (end: ">"))
  cdraw.line((4.3, 4.28), (5.7, 3.55), stroke: luma(140), mark: (end: ">"))
  cdraw.line((7.7, 4.28), (6.3, 3.55), stroke: luma(140), mark: (end: ">"))
  cdraw.line((7.7, 4.28), (9.1, 3.55), stroke: luma(140), mark: (end: ">"))
  cdraw.line((11.1, 4.28), (9.7, 3.55), stroke: luma(140), mark: (end: ">"))
  cdraw.line((6.0, 2.88), (7.4, 2.15), stroke: luma(140), mark: (end: ">"))
  cdraw.line((9.4, 2.88), (8.0, 2.15), stroke: luma(140), mark: (end: ">"))
  cdraw.content((14.6, 6.0), [$f(x_i)$], size: 6pt)
  cdraw.content((12.9, 4.6), [1st], size: 6pt)
  cdraw.content((11.2, 3.2), [2nd], size: 6pt)
  cdraw.content((9.5, 1.8), [3rd], size: 6pt)
  cdraw.content((7.7, 0.9), [shaded diagonal is the newton coefficient list 0, 1, 3, 1], size: 6pt)
})

== the runge phenomenon

Interpolating a smooth function at more equally spaced nodes can make
the result worse, not better. The demonstration function is the same
runge bump, and the ladder is measured on a fixed probe grid of 2001
points across $[-1, 1]$, worst $|p(x) - f(x)|$.

The dry run: the same runge bump on equally spaced nodes, measured as
the worst miss over the 2001-point probe grid. The ladder reads
0.438356640 at degree 4, 1.045173912 at degree 8, 3.663262143 at degree
12, and 14.393851285 at degree 16.

+ degree 4, 5 nodes: 0.438356640
+ degree 8, 9 nodes: 1.045173912
+ degree 12, 13 nodes: 3.663262143
+ degree 16, 17 nodes: 14.393851285

The two-number play: quadrupling the degree multiplies the worst miss
by 33, and the degree 16 miss, 14.4, is more than fourteen times the
entire height of the curve, which never leaves $[1/26, 1]$. The
oscillation concentrates just inside the ends, near $x plus.minus 0.95$
for degree 12, where the sample pins the 3.663 miss.

The cause is a race between two facts. A polynomial through $n + 1$
nodes commits the error $f(x) - p(x) = f^((n+1))(xi)\/(n+1)! product_i
(x - x_i)$ at each $x$ (the standard remainder formula, stated here
without proof), and equally spaced nodes make $product_i (x - x_i)$
explode near the ends: the product of distances from an end-adjacent
point to the far nodes is enormous. Meanwhile the runge function has
poles at $plus.minus 0.2 i$, close to the real axis, so the high
derivatives in the remainder do not cooperate (Trefethen, Approximation
Theory and Approximation Practice, SIAM 2019, 2nd ed., by name;
Wikipedia, Runge's phenomenon, fetched 2026-09-22).

#callout("verify", "HOW THE LADDER WAS MEASURED",
[The probe grid is $x = -1 + j\/1000$ for $j = 0, ..., 2000$, the same
grid in the playground one-off and in the C sample, and every ladder
entry is CHECKed to 1e-6 against the pinned value. The chebyshev ladder
in the next section uses the identical grid, so the comparison is
apples to apples.])

#listing("math/samples/src/Ch21/runge.c", first: 73, last: 87, caption: [runge.c, the equispaced ladder, each entry CHECKed against the pinned constant])

#diagram([degree 12 interpolation of the runge bump on 13 equally spaced nodes, plunging out of frame near both ends], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.00, 4.17), (1.70, 4.18), (2.40, 4.19), (3.10, 4.21), (3.80, 4.23), (4.50, 4.27), (5.20, 4.34), (5.90, 4.45), (6.60, 4.65), (7.30, 4.96), (8.00, 5.17), (8.70, 4.96), (9.40, 4.65), (10.10, 4.45), (10.80, 4.34), (11.50, 4.27), (12.20, 4.23), (12.90, 4.21), (13.60, 4.19), (14.30, 4.18), (15.00, 4.17)), luma(140))
  poly(((1.00, 4.17), (1.07, 2.50), (1.14, 1.39)), luma(60))
  poly(((1.49, 0.78), (1.56, 1.13), (1.63, 1.54), (1.70, 1.96), (2.05, 3.79), (2.40, 4.62), (2.75, 4.65), (3.10, 4.38), (3.45, 4.15), (3.80, 4.09), (4.15, 4.16), (4.50, 4.27), (4.85, 4.36), (5.20, 4.39), (5.55, 4.40), (5.90, 4.42), (6.25, 4.49), (6.60, 4.63), (6.95, 4.80), (7.30, 4.98), (7.65, 5.12), (8.00, 5.17), (8.35, 5.12), (8.70, 4.98), (9.05, 4.80), (9.40, 4.63), (9.75, 4.49), (10.10, 4.42), (10.45, 4.40), (10.80, 4.39), (11.15, 4.36), (11.50, 4.27), (11.85, 4.16), (12.20, 4.09), (12.55, 4.15), (12.90, 4.38), (13.25, 4.65), (13.60, 4.62), (13.95, 3.79), (14.30, 1.96), (14.37, 1.54), (14.44, 1.13), (14.51, 0.78)), luma(60))
  poly(((14.86, 1.39), (14.93, 2.50), (15.00, 4.17)), luma(60))
  cdraw.line((0.6, 0.8), (15.4, 0.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((0.6, 4.13), (15.4, 4.13), stroke: (paint: luma(150), dash: "dashed"))
  for x in ((1.00, 4.17), (2.17, 4.18), (3.33, 4.21), (4.50, 4.27), (5.67, 4.40), (6.83, 4.74), (8.00, 5.17), (9.17, 4.74), (10.33, 4.40), (11.50, 4.27), (12.67, 4.21), (13.83, 4.18), (15.00, 4.17)) {
    cdraw.circle(x, radius: 0.08, fill: luma(30), stroke: none)
  }
  cdraw.content((8.0, 5.55), [$f$], size: 6.5pt)
  cdraw.content((2.5, 5.35), [interpolant], size: 6pt)
  cdraw.content((1.05, 0.45), [$-1$], size: 6pt)
  cdraw.content((15.0, 0.45), [1], size: 6pt)
  cdraw.content((0.35, 4.13), [0], size: 6pt)
})

== chebyshev nodes

The remainder formula of the last section separates the error into a
function factor and a node factor, $product_i (x - x_i)$. The nodes are
the part you choose, so choose them to minimize the maximum of that
product. On $[-1, 1]$ the winner is the zero set of the chebyshev
polynomial: DLMF eq 18.5.1 gives $T_m(x) = "cos"(m theta)$ with $x =
"cos" theta$ (https://dlmf.nist.gov/18.5, fetched 2026-09-22), so the
zeros of $T_(n+1)$ sit at

$ x_k = "cos" ((2 k + 1) pi / (2 n + 2)), quad k = 0, ..., n $

(DLMF 18.16(iii), https://dlmf.nist.gov/18.16, fetched 2026-09-22),
which piles nodes near the ends exactly where the equally spaced grid
starves them. Minimality is chebyshev's theorem: among monic degree
$n + 1$ polynomials, $2^(-n) T_(n+1)$ has the smallest maximum norm on
$[-1, 1]$, the minimax statement behind the equioscillation theory
(Trefethen, ATAP, by name, no proof here).

The dry run: for $n = 4$ the five nodes are $cos 18 degree = 0.951057$,
$cos 54 degree = 0.587785$, $cos 90 degree = 0$, and their mirrors,
pinned to 12 decimals in the sample. The same runge bump, the same
probe grid, the same degrees:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*degree n*], [*equally spaced*], [*chebyshev*]),
  [4], [0.438356640], [0.402016742],
  [8], [1.045173912], [0.170833740],
  [12], [3.663262143], [0.069215708],
  [16], [14.393851285], [0.032613371],
  [24], [-], [0.006948418],
)

The two-number play: at degree 16 the equally spaced interpolant misses
by 14.394 and the chebyshev interpolant by 0.032614, a factor of 441,
and the chebyshev column is strictly decreasing all the way down. The
crossover is already visible at degree 4, where both miss by about 0.4
and the node placement has barely started to matter.

#listing("math/samples/src/Ch21/runge.c", first: 89, last: 116, caption: [runge.c, chebyshev placement, the shrinking ladder, and the degree 16 head to head])

#diagram([chebyshev nodes as equal angles projected onto the axis, against equally spaced dots], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((12.50, 1.20), (12.35, 2.36), (11.90, 3.45), (11.18, 4.38), (10.25, 5.10), (9.16, 5.55), (8.00, 5.70), (6.84, 5.55), (5.75, 5.10), (4.82, 4.38), (4.10, 3.45), (3.65, 2.36), (3.50, 1.20)), luma(140))
  cdraw.line((2.7, 1.2), (13.4, 1.2), stroke: luma(100), mark: (end: ">"))
  for k in range(5) {
    let th = (2 * k + 1) * calc.pi / 10.0
    let cx = 8.0 + 4.5 * calc.cos(th)
    let cy = 1.2 + 4.5 * calc.sin(th)
    cdraw.line((cx, cy), (cx, 1.2), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.circle((cx, cy), radius: 0.10, fill: none, stroke: luma(60))
    cdraw.circle((cx, 1.2), radius: 0.11, fill: luma(30), stroke: none)
  }
  for x in (3.72, 5.86, 8.0, 10.14, 12.28) {
    cdraw.circle((x, 0.6), radius: 0.10, fill: none, stroke: luma(60))
  }
  cdraw.content((10.9, 6.15), [equal angles], size: 6pt)
  cdraw.content((2.0, 1.75), [cos spacing], size: 6pt)
  cdraw.content((1.9, 0.6), [equal spacing], size: 6pt)
  cdraw.content((8.0, 0.0), [the ends crowd, the middle thins], size: 6pt)
})

== cubic splines

The global polynomial is the problem, so drop it: fit one cubic per
interval and glue them smoothly. A cubic spline on knots $x_0, ..., x_n$
is a function $S$ that is a cubic polynomial on each $[x_i, x_(i+1)]$
and twice continuously differentiable across every interior knot. The
natural spline pins $S'' (x_0) = S'' (x_n) = 0$, and with the second
derivatives $M_i = S'' (x_i)$ as unknowns the smoothness conditions
collapse to one tridiagonal system per interior knot,

$ h_(i-1)/6 M_(i-1) + (h_(i-1) + h_i)/3 M_i + h_i/6 M_(i+1) = (y_(i+1) - y_i)/h_i - (y_i - y_(i-1))/h_(i-1) $

with $h_i = x_(i+1) - x_i$ (the M-form, Burden and Faires, Numerical
Analysis, by name). Solved by the thomas sweep in $O(n)$, no matrix
stored.

The dry run: knots $0, 1, 2, 3$ on $f(x) = 1/(1 + x^2)$, values
$1, 1/2, 1/5, 1/10$, all $h_i = 1$.

+ The right sides are the second differences, $1/5 - 2 dot 1/2 + 1 =
  1/5$ and $1/10 - 2 dot 1/5 + 1/2 = 1/5$, equal by symmetry.
+ The system is $2/3 M_1 + 1/6 M_2 = 1/5$ and its mirror, so $M_1 =
  M_2 = 6/25$, with $M_0 = M_3 = 0$.
+ On $[0, 1]$ the local form gives $S(1/2) = 147/200 = 0.735$, and at
  the knot $S(1) = 1/2$, $S'(1) = -21/50$, $S'' (1) = 6/25$, each
  CHECKed from both adjoining pieces to 1e-12.

The head-to-head returns to the runge bump with 13 equally spaced
knots. The natural spline misses by 0.006908626 where the degree 12
interpolant on the same knots misses by 3.663262143, a factor of 530,
and the second derivatives tell the story: $M_6 = -52.306077941$ at the
center, where the curve bends hardest, easing to exactly 0 at the
natural ends. The two-number play: one global polynomial, 3.663;
thirteen joined cubics, 0.0069.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*knot $x_i$*], [*$y_i = 1/(1+x_i^2)$*], [*$M_i$*]),
  [0], [1], [0],
  [1], [$1/2$], [$6/25$],
  [2], [$1/5$], [$6/25$],
  [3], [$1/10$], [0],
)

#listing("math/samples/src/Ch21/spline.c", first: 32, last: 84, caption: [spline.c, the tridiagonal M system by thomas, then S, S', S'' from the local form])

#callout("note", "WHY NOT MORE PIECES",
[Halving every interval divides cubic spline error by roughly 16,
fourth-order convergence, while the global interpolant on those same
nodes heads the other way. Piecewise wins by refusing to coordinate:
each cubic only answers for its own interval.])

#diagram([the 4-knot fixture, one smooth curve from three cubics, second derivative continuous across the interior knots], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.00, 5.45), (1.65, 5.08), (2.30, 4.71), (2.95, 4.36), (3.60, 4.01), (4.25, 3.68), (4.90, 3.37), (5.55, 3.08), (6.20, 2.81), (6.85, 2.57), (7.50, 2.35), (8.15, 2.16), (8.80, 1.99), (9.45, 1.85), (10.10, 1.73), (10.75, 1.64), (11.40, 1.56), (12.05, 1.49), (12.70, 1.44), (13.35, 1.40), (14.00, 1.35)), luma(60))
  cdraw.line((0.7, 0.9), (14.3, 0.9), stroke: luma(100), mark: (end: ">"))
  for k in ((5.33, 3.17), (9.67, 1.81)) {
    cdraw.line(k, (k.at(0), 0.9), stroke: (paint: luma(150), dash: "dashed"))
  }
  for x in ((1.00, 5.45), (5.33, 3.17), (9.67, 1.81), (14.00, 1.35)) {
    cdraw.circle(x, radius: 0.12, fill: luma(30), stroke: none)
  }
  cdraw.content((1.0, 0.5), [0], size: 6pt)
  cdraw.content((5.33, 0.5), [1], size: 6pt)
  cdraw.content((9.67, 0.5), [2], size: 6pt)
  cdraw.content((14.0, 0.5), [3], size: 6pt)
  cdraw.content((3.2, 4.95), [$S'': 0 -> 6/25$], size: 6pt)
  cdraw.content((7.5, 3.0), [$S'' = 6/25$], size: 6pt)
  cdraw.content((2.7, 3.15), [$S' (1) = -21/50$], size: 6pt)
})

== least squares fitting

Sometimes the honest answer is to miss every point. With $m$ data
points and a degree $d$ model, $m > d + 1$, no polynomial hits them
all, and chapter #xref-to("math", "inner") already built the right
machinery: the design matrix $bold(A)$ with rows $(1, x_i, ...,
x_i^d)$, and the fit $bold(c)$ solving the normal equations
$bold(A)^top bold(A) bold(c) = bold(A)^top bold(y)$, the projection
of $bold(y)$ onto the column space under the standard inner product.

The fixture: five points at $x = -2, -1, 0, 1, 2$, a line of slope
1/2 carrying bumps $(1/16, 0, 1/4, 0, 1/16)$, so every value is an
exact dyadic rational.

+ Degree 1: $bold(A)^top bold(A)$ is "diag"(5, 10) on the symmetric
  grid and $bold(A)^top bold(y) = (43/8, 5)$, so $bold(c) = (43/40,
  1/2)$.
+ The residuals are $(-1/80, -3/40, 7/40, -3/40, -1/80)$, and the two
  orthogonality sums $sum r_i = 0$ and $sum x_i r_i = 0$ hold as exact
  rational zeros, the sample CHECKs them in fraction arithmetic.
+ Degree 2: $bold(c) = (311/280, 1/2, -1/56)$, all three orthogonality
  sums $sum x_i^k r_i = 0$ for $k = 0, 1, 2$ still exactly zero.

The residual sum of squares falls from $27/640 = 0.0421875$ to
$169/4480 = 0.0377232$, an 11 percent drop for one extra parameter.
The cautionary contrast is the degree 4 interpolant through the same
five points: at $x = 1/2$ it stands $179/1024 = 0.1748$ away from the
generating line while the degree 2 fit stands $17/160 = 0.1063$ away.
The honest grid-wide statement is about the worst case, not every
point: sweeping 801 points across $[-2, 2]$ the interpolant's largest
departure from the line is $1/4$, at the noisy knot $x = 0$, while the
fit's largest is $31/280 = 0.111$. Pointwise the picture is mixed, the
interpolant sits exactly on the line at the two noise-free knots and is
closer than the fit at 268 of the 801 points, but it pays for those
with the 0.25 spike. The two-number play: 0.175 bought by hitting
every point, 0.106 bought by missing all of them on purpose, and 0.25
versus 0.111 as the worst each risks anywhere.

#listing("math/samples/src/Ch21/lsq.c", first: 128, last: 156, caption: [lsq.c, the degree 1 normal equations, residuals, and exact orthogonality in rationals])

#callout("pitfall", "THE NORMAL EQUATIONS SQUARE THE CONDITION",
["cond"(bold(A)^top bold(A)) = "cond"(bold(A))^2, so the route this
fixture takes for exactness is the wrong route in floating point when
the fit grows. The QR decomposition of chapter #xref-to("math",
"decomp") fits the same model without ever forming $bold(A)^top
bold(A)$ (Trefethen and Bau, Numerical Linear Algebra, SIAM 1997, by
name).])

#listing("math/samples/src/Ch21/lsq.c", first: 193, last: 235, caption: [lsq.c, the degree 4 interpolant of the same points, its deviation play, and the worst-departure sweep])

#diagram([deviation from the generating line: the interpolant swings, the fit stays flat], length: 13pt, {
  let poly(pts, s) = {
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: s)
    }
  }
  poly(((1.00, 3.47), (1.70, 1.64), (2.40, 0.93), (3.10, 1.02), (3.80, 1.66), (4.50, 2.60), (5.20, 3.64), (5.90, 4.62), (6.60, 5.41), (7.30, 5.92), (8.00, 6.10), (8.70, 5.92), (9.40, 5.41), (10.10, 4.62), (10.80, 3.64), (11.50, 2.60), (12.20, 1.66), (12.90, 1.02), (13.60, 0.93), (14.30, 1.64), (15.00, 3.47)), luma(60))
  poly(((1.00, 3.15), (1.70, 3.34), (2.40, 3.51), (3.10, 3.66), (3.80, 3.79), (4.50, 3.90), (5.20, 3.99), (5.90, 4.06), (6.60, 4.11), (7.30, 4.14), (8.00, 4.15), (8.70, 4.14), (9.40, 4.11), (10.10, 4.06), (10.80, 3.99), (11.50, 3.90), (12.20, 3.79), (12.90, 3.66), (13.60, 3.51), (14.30, 3.34), (15.00, 3.15)), (paint: luma(150), dash: "dashed"))
  cdraw.line((0.7, 2.60), (15.3, 2.60), stroke: luma(100), mark: (end: ">"))
  for x in ((1.00, 3.47), (4.50, 2.60), (8.00, 6.10), (11.50, 2.60), (15.00, 3.47)) {
    cdraw.circle(x, radius: 0.12, fill: luma(30), stroke: none)
  }
  cdraw.content((8.0, 6.5), [interpolant deviation], size: 6pt)
  cdraw.content((5.6, 4.4), [fit deviation], size: 6pt)
  cdraw.content((15.0, 2.25), [0], size: 6pt)
  cdraw.content((8.0, 0.6), [both measured against the line 1 + x/2], size: 6pt)
})

The next chapter #xref-to("math", "quadrature") turns interpolation
into areas under curves, and the error formulas pinned here become the
error bounds of every quadrature rule there.

sources: no mml anchor sheet maps this chapter, it is worked from
canonical references cited by name: Trefethen, Approximation Theory and
Approximation Practice, SIAM 2019 2nd ed (equioscillation, chebyshev
convergence); Trefethen and Bau, Numerical Linear Algebra, SIAM 1997
(normal equations conditioning); Higham, Accuracy and Stability of
Numerical Algorithms, SIAM 2002 2nd ed (vandermonde conditioning);
Burden and Faires, Numerical Analysis, Brooks/Cole Cengage 2011 9th ed
(natural spline M-form). Fetched: DLMF 18.5 eq 18.5.1, T_n(cos theta)
equals cos(n theta),
https://dlmf.nist.gov/18.5 and DLMF 18.16(iii) zeros note,
https://dlmf.nist.gov/18.16, both 2026-09-22; Wikipedia, Runge's
phenomenon, https://en.wikipedia.org/wiki/Runge%27s_phenomenon,
2026-09-22. Expected sample values computed by the playground one-off
playground/math-ch21/pin.py, python fractions and numpy 2.5.3, run
2026-09-22. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter
Ch21`, 63 checks in chapter 21 of the math suite, 4 files, zero
failures.
