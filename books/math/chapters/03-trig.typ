#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= trigonometry

Trigonometry enters programs as the pair of coordinates on a circle, and
this chapter builds it in six moves: the unit circle and radians with the
quadrant sign map, the identity kit checked to tight ulp tolerances,
atan2 as the quadrant-honest inverse, Cody-Waite range reduction feeding
a polynomial sin and cos measured against the C runtime, the laws of
sines and cosines with the ambiguous SSA case, and the large-argument
trap where argument reduction dominates accuracy. Every behavioral claim
below is one of the 62 checks in the 3 samples of chapter 03 or a
sentence quoted from a canonical source fetched 2026-09-21. The
algorithm-first treatment of circles and angles on contest boards stays
in #xref-to("dsa", "geometry2"), this chapter is the theory the
algorithms stand on.

== the unit circle and radians

Definition first. An angle in radians is the arc length it cuts on the
unit circle, so a full turn is $2 pi$, a half turn is $pi$, and a right
angle is $pi \/ 2$. The cosine and sine of that angle are the x and y
coordinates of the point the arc ends on. That single sentence is the
whole geometric content, and the mml-book says it through projections:
"If ||x|| = 1, then x lies on the unit circle. It follows that the
projection onto the horizontal axis spanned by b is exactly cos omega"
(draft 2024-01-15, sec 3.8, eq 3.44, printed p 84). The angle between
two vectors lives in $[0, pi]$ because the normalized dot product (the
componentwise sum chapter #xref-to("math", "coordgeo") writes
$bold(u)^T bold(v)$) sits in $[-1, 1]$ (sec 3.4, eqs 3.24-3.25,
printed p 76).

The dry run: walk four landmark angles around the circle and read the
coordinates as sign plus magnitude. The values are pinned in
`identities.c` and were produced by mpmath at 200 bits on the exact
double inputs.

+ At $x = 0.7$ (about 40.1 degrees) the point is $(0.7648421872844885,
  0.64421768723769102)$, both coordinates positive, quadrant 1.
+ At $x = 2.3$ (about 131.8 degrees) the point is $(-0.66627602127982399,
  0.74570521217672026)$, cosine negative, sine positive, quadrant 2.
  The runtime value pins one ulp off the correctly rounded
  $-0.6662760212798241$.
+ At $x = 4.0$ (about 229.2 degrees) both go negative,
  $(-0.65364362086361194, -0.7568024953079282)$, quadrant 3.
+ At $x = 5.5$ (about 315.1 degrees) cosine recovers first,
  $(0.70866977429125999, -0.70554032557039192)$, quadrant 4.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*angle rad*], [*degrees*], [*(cos, sin)*], [*quadrant*]),
  [0.7], [40.1], [$(0.765, 0.644)$], [1: +, +],
  [2.3], [131.8], [$(-0.666, 0.746)$], [2: -, +],
  [4.0], [229.2], [$(-0.654, -0.757)$], [3: -, -],
  [5.5], [315.1], [$(0.709, -0.706)$], [4: +, -],
)

Two numbers carry the section. The double nearest $pi \/ 6$ still has
`sin(PIO6) == 0.5` exactly, because the true sine of that double rounds
to 0.5. The double nearest $pi \/ 2$ has `cos(PIO2)` equal to
6.123233995736766e-17, not 0, because $pi \/ 2$ is irrational and the
coordinate lands one ulp scale off the axis. The circle is continuous,
binary64 is not, and every axis value below inherits that residue.

#listing("math/samples/src/Ch03/identities.c", first: 35, last: 58, caption: [identities.c, the axis pins and the quadrant sign walk over the four landmarks])

#diagram([the unit circle with the four landmark points at their pinned coordinates], length: 13pt, {
  let cx = 3.2
  let cy = 3.2
  let r = 1.4
  // circle as 12 chords at 30 degrees
  let pt(k) = {
    let a = k * 30.0
    let rad = a * 3.1415926535897931 / 180.0
    (cx + r * calc.cos(rad), cy + r * calc.sin(rad))
  }
  for k in range(12) {
    let p1 = pt(k)
    let p2 = pt(calc.rem(k + 1, 12))
    cdraw.line(p1, p2, stroke: luma(100))
  }
  // axes
  cdraw.line((cx - r - 0.5, cy), (cx + r + 0.5, cy), stroke: luma(140))
  cdraw.line((cx, cy - r - 0.5), (cx, cy + r + 0.5), stroke: luma(140))
  cdraw.content((cx + r + 0.7, cy), [cos], size: 6pt)
  cdraw.content((cx, cy + r + 0.7), [sin], size: 6pt)
  // landmarks at the checked coordinate pairs, scaled to the radius,
  // labels pushed radially outward off the rim
  let mark(m, dx, dy, t) = {
    cdraw.circle((cx + r * dx, cy + r * dy), radius: 0.05, fill: luma(60))
    cdraw.content((cx + (r + 0.5) * dx, cy + (r + 0.5) * dy), t, size: 6pt)
  }
  mark(0.7, 0.7648421872844885, 0.64421768723769102, [0.7])
  mark(2.3, -0.66627602127982399, 0.74570521217672026, [2.3])
  mark(4.0, -0.65364362086361194, -0.7568024953079282, [4.0])
  mark(5.5, 0.70866977429125999, -0.70554032557039192, [5.5])
})

== the identity kit

The identities are the working set. Pythagorean: $sin^2 x + cos^2 x =
1$. Angle sum and difference: $sin(a + b) = sin a cos b + cos a sin
b$, $cos(a + b) = cos a cos b - sin a sin b$. Double angle by
setting $b = a$: $sin 2a = 2 sin a cos a$ and three cosine forms, $cos^2
a - sin^2 a$, $2 cos^2 a - 1$, $1 - 2 sin^2 a$. Half angle by solving
the second form: $cos^2 (a\/2) = (1 + cos a) \/ 2$. All four families
are one theorem deep, the angle sum, and DLMF sections 4.14, 4.17, and
4.21 carry the definitions, symmetries, and multiple-angle formulas.

The dry run: fix $a = 0.7$, $b = 0.4$, take `sin` and `cos` from the
runtime, and evaluate both sides of each identity in the exact order the
sample does.

+ Pythagorean over the four landmarks: the sum is 1.0 at 0.7 and 5.5,
  and 0.99999999999999978 at 2.3, one eps low, zero deviation
  elsewhere. Worst case 2.2204460492503131e-16.
+ Sum: `sin(1.1)` is 0.89120736006143542 against the expansion's
  0.89120736006143531, gap 1.1102230246251565e-16. Difference:
  `sin(0.3)` matches `sa*cb - ca*sb` bit for bit.
+ Double: `sin(1.4)` against $2 s_a c_a$, gap 1.1102230246251565e-16.
  The three cosine forms land at gaps 8.3e-17, 1.4e-16, 2.8e-17 from
  `cos(1.4)`, so the $1 - 2 sin^2 a$ form is the closest here.
+ Half: `cos(0.35)^2` against $(1 + c_a) \/ 2$, gap
  1.1102230246251565e-16.

The two-number play: at this one angle the three algebraically identical
cosine forms differ from each other by up to 1.4e-16 and the winner is
the one that subtracts nothing, $1 - 2 sin^2 a$ at 2.8e-17. An identity
is exact in real arithmetic and a choice among rounding patterns in
floating point, so pick the form whose inputs you already hold.

#listing("math/samples/src/Ch03/identities.c", first: 60, last: 92, caption: [identities.c, the pythagorean, sum, difference, double, and half checks with the pinned gaps])

#diagram([the identity kit as one derivation: pythagorean at the base, angle sum above, double and half by substitution and solving], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, size: 6pt)
  }
  box(2.7, 6.2, 6.6, [pythagorean $sin^2 x + cos^2 x = 1$])
  box(3.0, 4.4, 6.0, [angle sum $sin(a + b)$, $cos(a + b)$])
  box(0.6, 2.6, 4.0, [double: set $b = a$])
  box(7.4, 2.6, 4.4, [half: solve $2 cos^2 a - 1$])
  box(0.3, 0.8, 5.2, [$sin 2a$, three $cos 2a$ forms])
  box(7.2, 0.8, 5.0, [$cos^2 (a\/2) = (1 + cos a)\/2$])
  cdraw.line((6.0, 6.2), (6.0, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.4), (2.6, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.4), (9.6, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.4, 2.6), (2.9, 1.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.6, 2.6), (9.7, 1.7), stroke: luma(100), mark: (end: ">"))
})

#callout("pitfall", "IDENTICAL IDENTITIES ROUND DIFFERENTLY", [The three $cos 2a$ forms are the same real number and differ by up to 1.4e-16 in binary64 at $a = 0.7$. The $cos^2 a - sin^2 a$ form squares and subtracts two rounded terms, so it is the one to avoid near $a = pi \/ 4$ where they nearly cancel. Compute from what you hold, and when in doubt measure the gap the way the sample does.])

== atan2, the quadrant-honest inverse

Every inverse trigonometric function has to throw away information, the
question is how much. `acos` returns $[0, pi]$, matching the mml-book's
angle between vectors (sec 3.4, printed p 76), and loses the sign of the
sine entirely. `atan(y/x)` loses the quadrant of the ratio: the division
maps $(1, 1)$ and $(-1, -1)$ to the same value. `atan2(y, x)` takes
both coordinates separately and returns the angle of the point $(x, y)$
in $[-pi, pi]$, which is the argument of the complex number $x + i y$
and the reason cppreference describes it as the angle of the vector.
Both endpoints are live: positive zero over the negative x axis gives
$pi$, negative zero gives $-pi$, and the sample pins both.
The mml-book reaches the same place with rotations: the map that sends
$e_1$ to $(cos theta, sin theta)$ and $e_2$ to $(-sin theta, cos
theta)$ is the rotation matrix $bold(R)(theta)$ (sec 3.9, eqs 3.75 and
3.76, printed pp 91-92), and atan2 is its inverse on points. For the
angle between vectors, mml-book example 3.6 (printed p 77) has $cos
omega = 3\/sqrt(10)$ for $[1,1]$ against $[1,2]$, about 0.32 rad, and
the atan2 form of the 2d cross over the dot returns 0.32175055439664219
directly, with no clamp guarding a rounded ratio that drifts outside
$[-1, 1]$ before an `acos`.

The dry run: the four axis crossings, then the quadrant lie.

+ Axis walk: `atan2(0,1)` is 0, `atan2(1,0)` is the double $pi \/ 2$,
  `atan2(0,-1)` is the double $pi$, `atan2(-1,0)` is $-pi \/ 2$.
  All four are exact equality checks in the sample.
+ The lie: `atan(-1.0 / -1.0)` returns 0.78539816339744828, the same as
  `atan(1.0)`, while `atan2(-1.0, -1.0)` returns -2.3561944901923448,
  and the sample checks the two differ by exactly the double $pi$.
+ Infinities follow the coordinate map: `atan2(inf, -inf)` is $3 pi
  \/ 4$, `atan2(inf, 0)` is $pi \/ 2$.
+ Folding: for an angle already outside the principal range,
  `atan2(sin(4), cos(4))` returns -2.2831853071795867, within
  4.4e-16 of $4 - 2 pi$.

The two-number play: 0.7854 versus -2.3562, the same ratio, two
different points, and only the two-argument call can tell them apart.

#listing("math/samples/src/Ch03/triangles.c", first: 23, last: 42, caption: [triangles.c, the atan2 axis walk, the atan versus atan2 quadrant lie, infinity cases, and principal folding])

#diagram([the atan2 return map: four quadrants, four ranges, both coordinates kept], length: 13pt, {
  let cx = 4.2
  let cy = 3.4
  cdraw.line((cx - 4.0, cy), (cx + 4.0, cy), stroke: luma(140), mark: (end: ">"))
  cdraw.line((cx, cy - 2.6), (cx, cy + 2.6), stroke: luma(140), mark: (end: ">"))
  cdraw.content((cx + 4.2, cy - 0.35), [x], size: 6pt)
  cdraw.content((cx + 0.3, cy + 2.7), [y], size: 6pt)
  cdraw.content((cx + 1.7, cy + 1.4), [x > 0, y > 0], size: 6pt)
  cdraw.content((cx + 1.7, cy + 0.9), [$(0, pi\/2)$], size: 6pt)
  cdraw.content((cx - 1.7, cy + 1.4), [x < 0, y >= 0], size: 6pt)
  cdraw.content((cx - 1.7, cy + 0.9), [$(pi\/2, pi)$], size: 6pt)
  cdraw.content((cx - 1.8, cy - 1.4), [x < 0, y < 0], size: 6pt)
  cdraw.content((cx - 1.8, cy - 1.9), [$[-pi, -pi\/2)$], size: 6pt)
  cdraw.content((cx + 1.8, cy - 1.4), [x > 0, y < 0], size: 6pt)
  cdraw.content((cx + 1.8, cy - 1.9), [$(-pi\/2, 0)$], size: 6pt)
  cdraw.circle((cx - 1.4, cy - 0.9), radius: 0.05, fill: luma(60))
  cdraw.content((cx - 0.95, cy - 0.85), [(-1,-1)], size: 6pt)
})

== range reduction and a polynomial sin cos

A polynomial approximates sine well only near the origin, so a
production sin starts by reducing its argument: find the integer $n$
nearest to $2 x \/ pi$, subtract $n$ copies of $pi \/ 2$ from $x$ to get
a reduced argument $r$ in $[-pi \/ 4, pi \/ 4]$, evaluate short
polynomials $s(r)$ and $c(r)$ there, then dispatch on $n "mod" 4$ for
the signs and the swap. This is the Cody-Waite scheme, and its whole
difficulty is that $n dot (pi\/2)$ must be subtracted without rounding
error proportional to $n$.

The fix is to split $pi \/ 2$ into pieces whose products with $n$ stay
exact. $C_1$ is the double $pi \/ 2$ with its low 29 bits cleared, $C_2$
is the rest of the double, and $C_3$ is the 6.123233995736766e-17 tail
of true $pi \/ 2$ beyond the double. The split sums to true $pi \/ 2$
within 1.5e-33, against -6.1e-17 for the unsplit double, and for the
$|n| <= 13$ this file ever sees, every product $n C_1$, $n C_2$ is
exact.

The dry run: reduce $x = 5.5$.

+ $t = 5.5 dot 0.63661977236758138 = 3.5014087480...$, so $n =
  "round"(t) = 4$ and the quadrant index is $4 "mod" 4 = 0$.
+ $r = ((5.5 - 4 C_1) - 4 C_2) - 4 C_3 = -0.78318530717958645$, inside
  $[-pi\/4, pi\/4]$ with room to spare.
+ Quadrant 0 means no swap: $"sin"(5.5) = s(r) = -0.70554032557039181$
  against the runtime's -0.70554032557039192, and $"cos"(5.5) = c(r) =
  0.7086697742912591$ against 0.70866977429125999.
+ The axis cases come out bit-identical to the runtime:
  $"red"\_"sin"(pi\/2) = 1$ and $"red"\_"cos"(pi\/2) =
  6.123233995736766e-17$, exactly the libm values.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*$n "mod" 4$*], [*$"sin"(x)$*], [*$"cos"(x)$*]),
  [0], [$s(r)$], [$c(r)$],
  [1], [$c(r)$], [$-s(r)$],
  [2], [$-s(r)$], [$-c(r)$],
  [3], [$-c(r)$], [$s(r)$],
)

#listing("math/samples/src/Ch03/sincos.c", first: 22, last: 32, caption: [sincos.c, the cody-waite split of pi over 2 in three exact pieces])

#listing("math/samples/src/Ch03/sincos.c", first: 54, last: 79, caption: [sincos.c, the reduction and the odd taylor pair evaluated by horner in z = r^2])

#diagram([the reduction pipeline for x = 5.5: nearest multiple, three-piece subtraction, polynomial, quadrant dispatch], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.3), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.9), t, size: 6pt)
  }
  box(0.0, 3.4, 4.8, [x = 5.5])
  cdraw.content((2.4, 3.65), [$n = "round"(2x\/pi) = 4$], size: 6pt)
  box(5.5, 3.4, 5.4, [$r = x - n(C_1+C_2+C_3)$])
  cdraw.content((8.2, 3.65), [$r = -0.7832$], size: 6pt)
  box(11.6, 3.4, 6.6, [horner in $z = r^2$])
  cdraw.content((14.6, 3.55), [$s(r)$, $c(r)$ on $[{-pi\/4}, pi\/4]$], size: 6pt)
  box(5.6, 1.0, 6.0, [$q = n "mod" 4 = 0$])
  cdraw.content((8.6, 1.25), [$"sin" = s(r)$, $"cos" = c(r)$], size: 6pt)
  cdraw.line((4.8, 4.05), (5.5, 4.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.9, 4.05), (11.6, 4.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 3.4), (8.9, 2.3), stroke: luma(100), mark: (end: ">"))
})

#callout("verify", "THE SWEEP CONTRACT", [The sample walks 327681 dyadic grid points $i dot 2^(-13)$ over $[-20, 20]$ and measures the ulp distance against the runtime sin and cos with the monotone-integer key. Measured maxima, identical in the binary and in the python mirror: 10 ulp for sin, 10 ulp for cos, absolute gap 1.1102230246251565e-15 for both, and the reduced argument never leaves $[-0.78539593616989667, 0.78539593616989667]$. The asserts carry headroom at 16 ulp and 2e-15.])

Deterministic fixed-point rotations take this another way, CORDIC
instead of polynomials, and #xref-to("game-systems", "math") builds that
engine for lockstep multiplayer.

== laws of sines and cosines

A triangle is three sides and three angles with two laws tying them
together. The law of sines: $a \/ sin A = b \/ sin B = c \/ sin C = 2 R$
with $R$ the circumradius. The law of cosines: $c^2 = a^2 + b^2 - 2 a b
cos gamma$, the Pythagorean theorem with a correction term that dies on
right angles. Both rules and Heron's formula, area from the three sides
alone, $K = sqrt(s(s-a)(s-b)(s-c))$ with $s$ the semiperimeter, are
DLMF section 4.42, solution of triangles. Heron is the independent
cross-check, and the area also equals $(1\/2) a b sin gamma$.

The dry run: two triangles, one exact, one measured.

+ The 3-4-5 right triangle: `atan2(3,4)` gives A =
  0.64350110879328437, `atan2(4,3)` gives B = 0.92729521800161219, and
  A + B equals the double $pi \/ 2$ exactly. The three sine ratios
  agree to 2.8e-17. Heron's product under the square root is exactly
  36, so K = 6 and the circumradius `abc/4K` = 2.5, exactly the
  hypotenuse over 2.
+ The 7-8-1 triangle: sides $a = 7$, $b = 8$ flanking $gamma = 1$ rad.
  The law of cosines gives $c^2 = 52.486141742768346$ and $c =
  7.2447319993750181$. Feeding $c^2$ back through the recovered cosine
  returns gamma = 1.0 bit-exactly through `acos`. Heron and $(1\/2) a b
  sin gamma$ agree to 7.1054273576010019e-15.

The two-number play: the right triangle closes on exact doubles, K = 6
with nothing after the decimal, while the 7-8-1 triangle carries a
7.1e-15 gap between its two area routes. Integer sides plus a right
angle are the only free lunch here, every other triangle pays rounding.

#listing("math/samples/src/Ch03/triangles.c", first: 44, last: 61, caption: [triangles.c, the 3-4-5 angles, sine ratios, heron area, and the circumradius rule])

#listing("math/samples/src/Ch03/triangles.c", first: 63, last: 76, caption: [triangles.c, the law of cosines round trip on the 7-8-1 triangle with the heron cross-check])

#diagram([the 7-8-1 triangle to scale: gamma = 1 rad between a = 7 and b = 8, c = 7.2447 opposite], length: 13pt, {
  let ox = 1.2
  let oy = 0.9
  let bx = ox + 8.0 * 0.8 // b = 8 drawn at 0.8 scale
  let ax = ox + 7.0 * 0.8 * 0.54030230586813977
  let ay = oy + 7.0 * 0.8 * 0.8414709848078965
  cdraw.line((ox, oy), (bx, oy), stroke: luma(60))
  cdraw.line((ox, oy), (ax, ay), stroke: luma(60))
  cdraw.line((ax, ay), (bx, oy), stroke: luma(60), mark: (end: ">"))
  cdraw.content((ox + 3.0, oy - 0.45), [b = 8], size: 6pt)
  cdraw.content((ox - 0.7, oy + 2.6), [a = 7], size: 6pt)
  cdraw.content((ox + 4.6, oy + 3.1), [c = 7.2447], size: 6pt)
  cdraw.arc((ox, oy), start: 0deg, stop: 57.3deg, radius: 1.5, stroke: luma(140))
  cdraw.content((ox + 1.75, oy + 0.7), [gamma = 1], size: 6pt)
  cdraw.circle((ox, oy), radius: 0.06, fill: luma(60))
  cdraw.circle((bx, oy), radius: 0.06, fill: luma(60))
  cdraw.circle((ax, ay), radius: 0.06, fill: luma(60))
})

== the ambiguous ssa case

Given one angle, the side opposite it, and one more side, the SSA
configuration does not determine a triangle. The law of sines gives
$sin B = b sin A \/ a$ and the sine is symmetric under $B -> pi - B$,
so whenever both roots are geometrically valid, two triangles answer
the same data. The sample fixes $A = pi \/ 6$ and $b = 7$ and sweeps
the opposite side $a$ through the three regimes.

The dry run:

+ $a = 3$: the ratio is $7 dot 0.5 \/ 3 = 1.1667$, above 1, no
  triangle exists, the side is too short to close.
+ $a = 8$: the ratio is 0.4375 and $a > b$, so only the acute root is
  consistent, one triangle.
+ $a = 5$: the ratio is 0.7 (the double 0.69999999999999996), and $b
  sin A = 3.5 < 5 < 7 = b$ puts the case inside the ambiguity band.
  `asin` returns B1 = 0.77539749661075297, the supplement B2 =
  $pi -$ B1 = 2.3661951569790403, and `sin(B1) == sin(B2)` holds bit
  for bit. The two third angles give the two sides, $c_1 =
  9.6328920407624956$ and $c_2 = 2.4914636122196407$ against the mpmath
  truths 9.6328920407624938 and 2.4914636122196443.
+ Heron on the first triangle reproduces the area of $(1\/2) b c_1 sin
  A$ exactly, both 16.857561071334366.

The two-number play: one ratio, 0.7, and sides 9.633 against 2.491, a
factor of 3.87 between the two triangles that share it.

#listing("math/samples/src/Ch03/triangles.c", first: 78, last: 101, caption: [triangles.c, the three SSA regimes and the supplementary pair with the heron cross-check])

#diagram([the ambiguous case: a = 5 swings an arc through the base ray at two points, two triangles share A = 30 degrees and b = 7], length: 13pt, {
  let ax = 1.0
  let ay = 0.8
  let bxx = ax + 7.0 * 0.85 * 0.86602540378443865
  let by = ay + 7.0 * 0.85 * 0.5
  let c1 = ax + 9.6328920407624956 * 0.85
  let c2 = ax + 2.4914636122196407 * 0.85
  // base ray
  cdraw.line((ax - 0.4, ay), (ax + 9.2, ay), stroke: luma(140), mark: (end: ">"))
  // shared sides
  cdraw.line((ax, ay), (bxx, by), stroke: luma(60))
  cdraw.line((ax, ay), (c1, ay), stroke: luma(60))
  cdraw.line((bxx, by), (c1, ay), stroke: luma(60))
  // second triangle dashed
  cdraw.line((ax, ay), (c2, ay), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((bxx, by), (c2, ay), stroke: (paint: luma(150), dash: "dashed"))
  // the a = 5 locus arc through both crossings
  cdraw.arc((bxx, by), start: -135.6deg, stop: -44.4deg, radius: 5.0 * 0.85, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.arc((ax, ay), start: 0deg, stop: 30deg, radius: 1.6, stroke: luma(140))
  cdraw.content((ax + 1.85, ay + 0.35), [A = 30 deg], size: 6pt)
  cdraw.content((ax + 3.3, by + 0.4), [b = 7], size: 6pt)
  cdraw.content((c1 + 0.3, ay + 0.35), [c = 9.633], size: 6pt)
  cdraw.content((c2 - 0.5, ay - 0.5), [c = 2.491], size: 6pt)
  cdraw.content((bxx + 0.9, by - 2.2), [a = 5], size: 6pt)
})

#callout("pitfall", "ASIN RETURNS ONE ROOT", [`asin` covers $[-pi\/2, pi\/2]$ only. When the SSA ratio lands strictly between $sin A$ and 1, the mirror root $pi - B$ is a second valid angle and the program must add it by hand, the way the sample does. Forgetting it is the classic wrong-answer in any solver that reads two sides and a non-included angle.])

== large arguments and payne-hanek

The reduction, not the polynomial, is where a sin gains or loses its
accuracy. The polynomial works on $r in [-pi\/4, pi\/4]$ and is
accurate to about 4.2e-17 for sine and 1.0e-15 for cosine by
truncation, but $r$ can only be as good as the $pi \/ 2$ used to
compute it. The double $2 pi$ sits 2.4492935982947064e-16 below true
$2 pi$, and a naive reduction `fmod(x, 2*pi)` subtracts a wrong period
every turn, so the phase error grows as $k dot 2.45 dot 10^(-16)$ with
$k$ the number of turns.

The dry run: ask for `sin(1e16)`.

+ $k = 10^16 \/ 2 pi approx 1.59 dot 10^15$ turns. The accumulated
  phase error is $1.59 dot 10^15 dot 2.45 dot 10^(-16) =
  0.38981718325193748$ rad.
+ `fmod(1e16, 2*pi_d)` returns 2.637242432414304, but the true reduced
  phase is 2.2474252491623665. The phases differ by the predicted
  0.3898 rad.
+ `sin` of the wrong phase is 0.48323866838796636. The runtime
  `sin(1e16)` returns 0.77968800660697879, which mpmath confirms as
  correctly rounded: the C runtime reduces exactly, and the sample
  checks the naive shortcut is off by at least 0.29 in sine.

The exact reducers use Payne-Hanek: instead of a precomputed constant
of 53 bits, they read the binary expansion of $2 \/ pi$ from a table at
the bit position the argument demands, so the subtraction recovers the
phase to full precision no matter how large $x$ is. This chapter states
the scheme and does not implement it, the three-piece Cody-Waite split
in `sincos.c` is documented for $|x| <= 20$ where $|n| <= 13$ keeps the
products exact, and the sweep asserts that domain.

The two-number play: 0.39 rad of phase error from a 2.45e-16 constant
error, and 0.29644933821901243 of error in the sine, all from one
`fmod` against the wrong $2 pi$.

#listing("math/samples/src/Ch03/sincos.c", first: 180, last: 193, caption: [sincos.c, the 1e16 trap: the runtime is right, the naive double-2pi reduction is 0.39 rad out of phase])

#diagram([phase error of the naive double-2pi reduction against turns, one decade per step], length: 13pt, {
  let x0 = 1.2
  let y0 = 0.9
  // axis: k in decades, error in decades
  cdraw.line((x0, y0), (x0 + 13.4, y0), stroke: luma(140), mark: (end: ">"))
  cdraw.line((x0, y0), (x0, y0 + 5.6), stroke: luma(140), mark: (end: ">"))
  cdraw.content((x0 + 13.6, y0 - 0.3), [turns k], size: 6pt)
  cdraw.content((x0 + 0.3, y0 + 5.7), [phase error, rad], size: 6pt)
  // points: k = 1, 1e9, 1.6e15
  cdraw.circle((x0, y0 + 0.35), radius: 0.06, fill: luma(60))
  cdraw.content((x0 + 0.5, y0 + 0.55), [k = 1: 2.4e-16], size: 6pt)
  cdraw.circle((x0 + 6.5, y0 + 3.1), radius: 0.06, fill: luma(60))
  cdraw.content((x0 + 5.2, y0 + 3.6), [k = 1e9: 2.5e-7], size: 6pt)
  cdraw.circle((x0 + 12.0, y0 + 5.2), radius: 0.06, fill: luma(60))
  cdraw.content((x0 + 9.6, y0 + 5.45), [k = 1.6e15: 0.39], size: 6pt)
  cdraw.line((x0, y0 + 0.35), (x0 + 6.5, y0 + 3.1), stroke: luma(100))
  cdraw.line((x0 + 6.5, y0 + 3.1), (x0 + 12.0, y0 + 5.2), stroke: luma(100))
})

#callout("warning", "NEVER REDUCE WITH THE DOUBLE 2 PI", [Any loop of the form `x - k*2*M_PI` or `fmod(x, 2*M_PI)` inherits a 2.45e-16 period error and multiplies it by the turn count. At 1e16 that is 0.39 rad. Either keep arguments inside a domain your split covers, the way this chapter does, or call a sin that reduces exactly.])

== next

Points, lines, and the transforms that move them, including the
rotation matrix this chapter only quoted, are chapter 4.

sources: mml-book draft 2024-01-15, ch 3, printed pp 76-78 (angles,
orthogonality, example 3.6), p 81 (sin and cos as orthogonal functions),
pp 83-85 (projection length and eq 3.44), pp 91-94 (rotation matrices,
eqs 3.75-3.76, the rotation group), read from the cached text layer and
cross-verified against the pdf pages. NIST DLMF, sections 4.14, 4.17,
and 4.21 for the definitions, symmetries, and multiple-angle formulas,
4.23 for the inverse functions, 4.42 for the solution of triangles,
https://dlmf.nist.gov/4.14 and neighbors, fetched
2026-09-21. cppreference, `sin` and `atan2`, special value tables,
https://en.cppreference.com/w/c/numeric/math/sin and .../atan2,
fetched 2026-09-21. Cody and Waite 1980, the split-reduction scheme,
and Payne and Hanek 1971, stated not implemented, as named in Muller,
"Elementary Functions", 2nd ed. Probed on this machine the same day.
Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter
Ch03`, 62 checks in chapter 03 of the math suite.
