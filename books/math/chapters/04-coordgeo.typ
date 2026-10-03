#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= coordinate geometry

A plane of coordinates is where geometry becomes arithmetic, and this chapter
builds the arithmetic carefully enough to trust. The moves: separate points
from vectors and give both a length and a direction, take the 2D cross
product as one exact orientation predicate, solve parametric lines, rays,
and segments through that predicate with no division, cut circles with
lines by a squared discriminant and pass a circle through three points by
bisectors, compose translate, rotate, and scale as matrices where order is
the meaning, and walk polar and parametric curves point by point. Every
behavioral claim below is one of the 51 checks in the 4 samples of chapter
4 or a sentence quoted from the mml draft fetched 2026-09-21. Where
#xref-to("dsa", "geometry") and #xref-to("dsa", "geometry2") hunt winning
contest algorithms, this chapter builds the coordinate algebra underneath
them and leaves the algorithmics out.

== points, vectors, direction

A point is a location, a vector is a displacement, and two operations
connect them, only two. The difference of two points is a vector,
$bold(v) = p - q$, and a point plus a vector is a point, $q + bold(v) =
p$. The sum of two points is on neither list. It compiles, it runs, and it
answers a question nobody asked, which is how it breaks code: averaging
positions is legal only as an affine combination whose weights sum to 1,
so the centroid $(p_1 + p_2 + p_3) / 3$ is fine while a bare $p_1 + p_2$
is a type error the compiler cannot see.

Length comes from an inner product. The mml draft opens its analytic
geometry chapter by saying "we equip the vector space with an inner
product that induces the geometry of the vector space" (draft 2024-01-15,
ch 3 opener). With the dot product $bold(u)^T bold(v) = sum u_i v_i$
(its eq 3.5) the default ruler is the Euclidean norm $norm(bold(v))_2 =
sqrt(bold(v)^T bold(v))$ (eq 3.4), with the Manhattan norm
$norm(bold(v))_1 = sum |v_i|$ (eq 3.3) as the other classic. Both satisfy
the three axioms of its definition 3.1: absolute homogeneity, the triangle
inequality, positive definiteness. The distance between points rides on
the norm, $d(x, y) = norm(x - y)$ (eq 3.21), and is a metric: positive
definite, symmetric, triangle. Direction is the vector with its length
divided out, $hat(bold(v)) = bold(v) / norm(bold(v))$, and the angle
between two directions is read off

$ cos omega = (bold(u)^T bold(v)) / (norm(bold(u)) norm(bold(v))) $

which is the mml eq 3.25, valid because the ratio is pinned between -1
and 1 (its eq 3.24) for a unique $omega in [0, pi]$.

The dry run: from (1, 2) to (4, 6) the difference is the vector (3, 4),
the distance is $sqrt(9 + 16) = 5$, and the unit direction is (0.6, 0.8)
$= (3/5, 4/5)$. Stepping twice as far, (1, 2) + 2 (3, 4) = (7, 10),
scales the displacement and never the start. The two-number play for
length: the same vector (3, 4) measures 7 under the Manhattan norm and 5
under the Euclidean one, two axioms-compliant rulers that disagree, which
is why a codebase picks one and names it.

#listing("math/samples/src/Ch04/lines.c", first: 19, last: 25, caption: [the vector substrate: integer points, difference, dot, cross])

#callout("pitfall", "POINTS ARE NOT VECTORS", [Storing both as a pair of
numbers is fine, but the operations must respect the split. $p - q$ is a
vector, $p + bold(v)$ is a point, and $p + q$ is undefined. Any formula
that adds two locations, or scales a location by 2, is wrong in a way no
compiler catches. The fix travels with the types: think "point minus
point" before writing a single plus.])

#diagram([point difference as the one bridge between points and vectors], length: 13pt, {
  let dot(p, label, below: false) = {
    cdraw.circle(p, radius: 0.07, stroke: none, fill: luma(60))
    cdraw.content((p.at(0), p.at(1) + if below { -0.35 } else { 0.35 }), label, size: 6pt)
  }
  cdraw.line((1.2, 1.0), (4.2, 2.0), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.line((1.2, 1.0), (10.4, 5.4), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.line((4.2, 2.0), (10.4, 5.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.0, 4.3), [p - q], size: 6pt)
  cdraw.content((1.0, 0.6), [o], size: 6pt)
  dot((4.2, 2.0), [q], below: true)
  dot((10.4, 5.4), [p], below: true)
})

Vectors as a space, with bases, coordinates, and the full algebra, are the
subject of #xref-to("math", "vectors"), and this chapter only needs the
plane.

== orientation: one sign, exactly

The 2D cross product of two vectors is the scalar

$ a times b = a_x b_y - a_y b_x, $

the z component of the 3D cross product, and also twice the signed area
of the triangle with corners $0$, $a$, $b$. One subtraction of point
differences turns it into a predicate on triples:

#snippet("orient(p0, p1, p2) = sign(cross(p1 - p0, p2 - p0))", lang: "c")

The sign is +1 when p0, p1, p2 turn counterclockwise, -1 clockwise, and 0
when collinear, the right-hand-rule convention with z pointing out of the
plane. That one integer is the workhorse of computational
geometry: inside-or-outside, left-or-right, hull order, and the
intersection tests of the next section all reduce to it.

On an integer grid the predicate is exact. With coordinates bounded by
$10^9$, differences reach $2 dot 10^9$, products $4 dot 10^18$, and their
difference $8 dot 10^18$, under the signed 64-bit ceiling of about $9.22
dot 10^18$: the sample pins the bound with a `static_assert` at compile
time, so the exactness is a checked property, not a hope.

The dry run: for the triple (0,0), (1,0), (1,1) the differences are
$a = (1,0)$ and $b = (1,1)$, the cross is $1 dot 1 - 0 dot 1 = 1$, and
the verdict is +1, counterclockwise. For the near-degenerate pair $b_1 =
(2^53 + 3, 1)$ and $b_2 = (2^53 + 5, 1)$ the exact cross is $b_1 - b_2 =
-2$, a small but real clockwise turn. In doubles both coordinates round
to the same value $2^53 + 4 = 9007199254740996.0$ (spacing is 2 at
$2^53$, and both ties round to even), so the double cross is exactly 0.0
and the verdict flips to collinear. The two-number play of the chapter:
exact cross -2 against double cross 0.0, one triple, two answers, and
only one of them true.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*triple*], [*exact cross*], [*exact verdict*], [*double cross*], [*double verdict*]),
  [$(0,0), (b_1, 1), (b_2, 1)$], [-2], [clockwise, -1], [0.0], [collinear],
  [$(0,0), (b_2, 1), (b_1, 1)$], [+2], [counterclockwise, +1], [0.0], [collinear],
)

#listing("math/samples/src/Ch04/orientation.c", first: 19, last: 42, caption: [cross, orient, and the compile-time grid bound with the big pair declared])

#listing("math/samples/src/Ch04/orientation.c", first: 59, last: 71, caption: [the two-number play: one near-degenerate triple through both predicates])

#callout("verify", "EXACTNESS IS A COMPILE-TIME FACT", [The sample's
`static_assert(2000000000LL * 4000000000LL < INT64_MAX, ...)` encodes the
worst case of the $10^9$ grid. Raise the grid bound without re-deriving
the inequality and the build stops, which is the correct place for a
geometry bug to die. The rounding wall at $2^53$ is the float spacing
story of #xref-to("math", "float").])

#diagram([the orientation sign: counterclockwise +1, clockwise -1, collinear 0], length: 13pt, {
  cdraw.line((1.2, 1.2), (4.2, 1.2), stroke: luma(60))
  cdraw.line((4.2, 1.2), (2.7, 3.4), stroke: luma(60))
  cdraw.line((2.7, 3.4), (1.2, 1.2), stroke: luma(60), fill: luma(235), closed: false)
  cdraw.content((2.7, 1.6), [+1 ccw], size: 6pt)
  cdraw.line((6.2, 3.4), (9.2, 3.4), stroke: luma(60))
  cdraw.line((9.2, 3.4), (7.7, 1.2), stroke: luma(60))
  cdraw.line((7.7, 1.2), (6.2, 3.4), stroke: luma(60))
  cdraw.content((7.7, 2.7), [-1 cw], size: 6pt)
  cdraw.line((11.2, 2.3), (14.8, 2.3), stroke: luma(100))
  for x in (11.2, 13.2, 14.8) {
    cdraw.circle((x, 2.3), radius: 0.07, stroke: none, fill: luma(60))
  }
  cdraw.content((13.0, 1.7), [0 collinear], size: 6pt)
})

The algorithms this predicate feeds, convex hulls, point-in-polygon,
sweeps, are the business of #xref-to("dsa", "geometry"), and here it stays
a definition.

== lines, rays, segments

One parametric form covers all three shapes: $l(t) = p + t bold(r)$ with
$p$ a point and $bold(r)$ a direction vector. The line is every $t$, the
ray is $t >= 0$, the segment is $t in [0, 1]$. Ranges, not formulas, are
what separate them, so one solver serves all three by changing the bound
on $t$.

Two such curves meet where $p + t bold(r) = q + u bold(s)$. Rearranged,
$t bold(r) - u bold(s) = bold(w)$ with $bold(w) = q - p$. Cross both
sides with $bold(s)$: the $u$ term dies because
$bold(s) times bold(s) = 0$, leaving $t = (bold(w) times bold(s)) /
(bold(r) times bold(s))$. Cross with $bold(r)$ the same way and
$u = (bold(w) times bold(r)) / (bold(r) times bold(s))$. No square roots,
no trigonometry, and a zero denominator is exactly the parallel case.

The dry run: the X crossing fixture has $p = (0,0)$, $bold(r) = (4,4)$,
$q = (0,4)$, $bold(s) = (4,-4)$. The denominator is $bold(r) times
bold(s) = 4(-4) - 4 dot 4 = -32$, and with $bold(w) = (0,4)$ both
numerators are $0(-4) - 4 dot 4 = -16$, so $t = u = -16 \/ -32 = 1/2$ and
the shared point is $(2,2)$, mid of both segments. The extended-lines
fixture $(0,0)$ to $(1,1)$ against $(3,0)$ to $(4,1)$ solves to $t = 0$,
$u = -3$: the infinite lines cross at the origin, but $u$ falls outside
$[0,1]$ and the segments miss. Two numbers, 1/2 against -3, are the whole
difference between hit and miss.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*fixture*], [*denominator*], [*t*], [*u*], [*verdict*]),
  [x crossing], [-32], [1/2], [1/2], [hit at (2,2)],
  [parallel], [0], [--], [--], [abstain],
  [collinear overlap], [0], [--], [--], [abstain],
  [endpoint touch], [-8], [1], [0], [hit at (2,2)],
  [ray against segment], [4], [3], [1/2], [hit at (3,1)],
  [extended miss], [-1], [0], [-3], [miss],
)

The same solve projects a point onto a line: the foot of the
perpendicular from x to $p + t bold(r)$ sits at $t^* = ((x - p) dot
bold(r)) \/ (bold(r) dot bold(r))$, and the distance from x to the line
is $| (x - p) times bold(r) | \/ norm(bold(r))$. Verified on the diagonal
fixture $p = (0,0)$, $bold(r) = (4,4)$, $x = (4,0)$: $t^* = 16\/32 =
1/2$, the foot is (2,2), and the distance squared is $16^2\/32 = 8$, a
distance of $2 sqrt(2)$. The collinear overlap of the callout below is
the same projection read twice: the pinned dots give $t^* = 8\/16 = 1/2$
and $t^* = 24\/16 = 3/2$, the second foot landing past the segment end,
which is what overlap means numerically.

#listing("math/samples/src/Ch04/lines.c", first: 27, last: 49, caption: [the segment solver: cross-multiplied bounds, scaled intersection point])

#listing("math/samples/src/Ch04/lines.c", first: 76, last: 88, caption: [endpoint touch and the ray with its bound lifted, exact t and u])

#callout("warning", "PARALLEL IS AN ANSWER, NOT AN ERROR", [When the
denominator is 0 the solver abstains, and the collinear overlap of (0,0)
to (4,0) against (2,0) to (6,0) shows why: the parametric solve has no
unique meeting point. Overlap then lives in dot-product projections, 8/16
$= 1/2$ against 24/16 $= 3/2$ of $bold(r)^2 = 16$ in the sample. The full
case analysis, touching, overlapping, disjoint, belongs to
#xref-to("dsa", "geometry2"), which owns the contest-grade template.])

#diagram([the x crossing: two parametric segments meeting at t = u = 1\/2], length: 13pt, {
  cdraw.line((1.0, 0.8), (11.4, 11.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.0, 11.2), (11.4, 0.8), stroke: luma(100), mark: (end: ">"))
  cdraw.circle((6.2, 6.0), radius: 0.13, stroke: luma(60), fill: luma(245))
  cdraw.content((1.0, 0.4), [p], size: 6pt)
  cdraw.content((11.6, 11.2), [p + r], size: 6pt)
  cdraw.content((0.4, 11.2), [q], size: 6pt)
  cdraw.content((11.6, 0.4), [q + s], size: 6pt)
  cdraw.content((6.6, 6.0), [(2,2)], size: 6pt)
  for (pt, lab) in (((3.6, 3.4), [1/4]), ((8.8, 8.6), [3/4])) {
    cdraw.circle(pt, radius: 0.06, stroke: none, fill: luma(60))
    cdraw.content((pt.at(0) + 0.3, pt.at(1) - 0.2), lab, size: 6pt)
  }
})

== circles and conics

A circle is the set of points at a fixed squared distance $r^2$ from a
center, and the squared form is the honest one: keep $r^2 = 10$ as an
integer, do not open the $sqrt$ door, because `isqrt` shows it only
floors, `isqrt(10) = 3`, a one-way loss of information.

The vertical line $x = k_x$ against $x^2 + y^2 = r^2$ gives $y^2 = r^2 -
k_x^2$ on sight, and the sign of that one integer is the discriminant:
positive cuts a chord, zero is tangent, negative misses. In general the
half chord is $sqrt(r^2 - h^2)$ where $h$ is the perpendicular distance
from center to line, by the right triangle from center to foot to hit
point, and tangency is exactly $h = r$. For a line $a x + b y = c$ the
nearest point to the origin lies along the normal $(a, b)$ at parameter
$c\/(a^2 + b^2)$, so the distance is $|c| \/ sqrt(a^2 + b^2)$.

The dry run: with $r = 5$, the line $x = 3$ yields $y^2 = 25 - 9 = 16$
and cuts at $(3, 4)$ and $(3, -4)$, $x = 5$ yields 0 and touches at
$(5, 0)$, $x = 6$ yields $-11$ and misses. The tangent at the circle
point $(3, 4)$ is $3x + 4y = 25$: its distance from the origin is
$25\/sqrt(9 + 16) = 5 = r$, and its direction $(-4, 3)$ dots with the
radius to 0, perpendicular as tangency demands.

A circle through three points comes from perpendicular bisectors, the set
of points equidistant from two given ones. For (0,0), (6,0), (2,4):
equidistance from (0,0) and (6,0) is $x = 3$, and expanding $x^2 + y^2 =
(x-2)^2 + (y-4)^2$ gives $x + 2y = 5$. The bisectors meet at $(3, 1)$,
which sits at squared distance 10 from all three corners, so the circle
is center $(3,1)$ with $r^2 = 10$. Three collinear points, orientation 0
back in the orientation section, have parallel bisectors and carry
no circle at all.

The general second-degree curve $a x^2 + b x y + c y^2 + d x + e y + f =
0$ is a conic, sorted by the sign of $b^2 - 4 a c$: negative is an
ellipse, the circle being the special case $b = 0, a = c$. Zero is a
parabola, positive a hyperbola. Substituting canonical members confirms
the sort, the unit circle gives $-4$, $x y = 1$ gives $+1$, $y = x^2$
gives 0, a one-off fraction pinned in the playground.

The two-number play sits near the tangent: with $r = 10^8$ and $k_x =
10^8 - 1$ the exact half chord squared is $r^2 - k_x^2 = 199999999$,
while in doubles $(10^8)^2 = 10^16$ is exact but $(10^8 - 1)^2 =
9999999800000001$ rounds to 9999999800000000.0, and the subtraction
drifts to 200000000.0. One unit of drift on a quantity whose sign is the
answer, the same wall as the orientation pair, and the same cure: exact
integers on a bounded grid.

#listing("math/samples/src/Ch04/circles.c", first: 19, last: 29, caption: [squared half chord and exact floor sqrt, no floating point])

#listing("math/samples/src/Ch04/circles.c", first: 55, last: 65, caption: [the big near-tangent: exact 199999999 versus double 200000000.0])

#diagram([circumcircle of (0,0), (6,0), (2,4): bisectors meet at (3,1), r^2 = 10], length: 13pt, {
  cdraw.circle((5.5, 2.2), radius: 4.743, stroke: luma(100))
  cdraw.line((5.5, -2.2), (5.5, 6.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((0.5, 4.7), (10.5, -0.3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((5.5, 2.2), (4.0, 6.7), stroke: luma(60))
  for (pt, lab, dx, dy) in (
    ((1.0, 0.7), [(0,0)], -0.7, -0.35),
    ((10.0, 0.7), [(6,0)], 0.2, -0.35),
    ((4.0, 6.7), [(2,4)], 0.0, 0.35),
    ((5.5, 2.2), [(3,1)], 0.45, -0.3),
  ) {
    cdraw.circle(pt, radius: 0.07, stroke: none, fill: luma(60))
    cdraw.content((pt.at(0) + dx, pt.at(1) + dy), lab, size: 6pt)
  }
  cdraw.content((5.9, 4.6), [r^2 = 10], size: 6pt)
  cdraw.content((6.2, -1.6), [x = 3], size: 6pt)
})

== affine transforms and order

Translate, rotate, and scale all have the shape $x' = a x + b y + c$,
$y' = d x + e y + f$: an affine map, storable as 6 numbers, the 2x3
matrix of the sample. Rotation by $theta$ counterclockwise is

$ mat(delim: "[", cos theta, -sin theta; sin theta, cos theta), $

and the mml draft asks exactly this object of the reader as a linear map
$RR^2 -> RR^2$ in its exercise 2.16e, there written $x |-> mat(delim:
"[", cos theta, sin theta; -sin theta, cos theta) x$ for $theta in
[0, 2 pi)$, which is the same family read clockwise, rotation by
$-theta$. Rotation preserves dot products, so it preserves lengths and
the angle measure of the first section, and reading an angle from
coordinates is trigonometry, #xref-to("math", "trig").

The rotation that a 3-4-5 triangle knows, $cos theta = 3\/5$ and $sin
theta = 4\/5$, maps the integer grid onto itself: (5, 0) goes to (3, 4)
and (0, 5) goes to (-4, 3), exactly, in the sample's integer routine.

The dry run: composition order, starting from (1,1). Translate by (1,2)
first, giving (2,3), then rotate 90 degrees counterclockwise, giving
(-3,2). Rotate first instead, giving (-1,1), then translate, giving
(0,3). Same two maps, same start, two different answers: the two-number
play of the section, (-3,2) against (0,3). In matrix language the maps do
not commute, $bold(A) bold(B) != bold(B) bold(A)$, while associativity
holds, $(bold(A) bold(B)) bold(C) = bold(A) (bold(B) bold(C))$, pinned
entry by entry in the sample with the pinned products $bold(A)
bold(B) = mat(delim: "[", 0, -1, -2; 1, 0, 1; 0, 0, 1)$ and $bold(A)
bold(B) bold(C) = mat(delim: "[", 0, -3, -2; 2, 0, 1; 0, 0, 1)$, which
sends (1,1) to (-5,3).

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*order*], [*after the first map*], [*after the second*]),
  [translate (1,2), then rotate 90], [(2,3)], [(-3,2)],
  [rotate 90, then translate (1,2)], [(-1,1)], [(0,3)],
)

The 3x3 form is the homogeneous trick: append the row $(0, 0, 1)$ and
translation stops being a special case, composition becomes a plain
matrix product, and the last row stays $(0,0,1)$ across every product of
transforms.

One more read of the pinned composite closes the loop with the first
section. The composite sends (0,0) to $(-2, 1)$ by the same pinned
entries, so the difference of the two images is $(-5,3) - (-2,1) =
(-3,2)$: the translation column cancels and the linear part alone
carries differences of points, which is the point-minus-vector rule
walking in matrix clothes.

#listing("math/samples/src/Ch04/transforms.c", first: 26, last: 40, caption: [affine constructors: translate, rotate 90, scale as 2x3 matrices])

#listing("math/samples/src/Ch04/transforms.c", first: 79, last: 105, caption: [homogeneous 3x3 constants, associativity, and the pinned composite])

#callout("note", "THE HOMOGENEOUS ROW IS A PREVIEW", [Stacking $(x, y, 1)$
and closing with $(0, 0, 1)$ buys composition as multiplication and
nothing else yet. Why that trade pays off, inverses, ranks, the whole
matrix algebra, is the next stop in #xref-to("math", "matrices"). Read
the product right to left: in $bold(A) bold(B) bold(C) p$, the map
$bold(C)$ touches the point first.])

#diagram([translate then rotate versus rotate then translate from the same start], length: 13pt, {
  cdraw.line((5.9, 1.5), (6.8, 3.3), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.8, 3.3), (2.3, 2.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.9, 1.5), (4.1, 1.5), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((4.1, 1.5), (5.0, 3.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.circle((5.9, 1.5), radius: 0.07, stroke: none, fill: luma(60))
  cdraw.circle((2.3, 2.4), radius: 0.07, stroke: none, fill: luma(60))
  cdraw.circle((5.0, 3.3), radius: 0.07, stroke: none, fill: luma(60))
  cdraw.content((5.9, 1.1), [(1,1)], size: 6pt)
  cdraw.content((7.1, 3.3), [(2,3)], size: 6pt)
  cdraw.content((1.6, 2.4), [(-3,2)], size: 6pt)
  cdraw.content((3.9, 1.1), [(-1,1)], size: 6pt)
  cdraw.content((5.3, 3.3), [(0,3)], size: 6pt)
  cdraw.content((6.5, 2.4), [t then r], size: 6pt)
  cdraw.content((4.1, 2.4), [r then t], size: 6pt)
})

== polar and parametric curves

Polar coordinates trade the pair (x, y) for a radius and an angle:

$ x = r cos theta, quad y = r sin theta, $

and the way back is `atan2(y, x)`. At $r = 6$, $theta = pi\/3$ the point
is $(6 cos(pi\/3), 6 sin(pi\/3)) = (3.000000000000001,
5.196152422706632)$, because the double nearest $pi\/3$ has a cosine one
ulp above 1/2. The roundtrip stays honest: `atan2(4, 3)` followed by
multiplying by 5 returns $(3, 4)$ to within $10^(-12)$, pinned in the
sample. The angle conventions and the ulp arithmetic of $pi$ belong to
#xref-to("math", "trig").

A parametric curve is a point-valued function of one parameter, and the
closing example walks one: the ellipse

$ E(t) = (1 + 3 cos t, quad 2 + 2 sin t), $

which is the unit circle of this chapter's fourth section pushed through
the machine of the fifth: scale by $(3, 2)$, then translate by (1, 2). A
circle is the special case of equal axes.

The dry run: four cardinal values of t. $t = 0$ gives (4, 2), $t =
pi\/2$ gives (1.0000000000000002, 4), $t = pi$ gives (-2,
2.0000000000000004), and $t = 3pi\/2$ gives (0.9999999999999994, 0):
$sin(3pi\/2)$ lands exactly on -1 while $cos(3pi\/2)$ carries
$-1.8 dot 10^(-16)$, the largest residue of the four. The residues are
the story: three of the four zero-expected values ($cos(pi\/2)$,
$sin(pi)$, $cos(3pi\/2)$, against an exact $sin(0)$) are not quite 0 in
doubles, so each "exact" cardinal point lands one rounding step off.
The two-number play: 2.0000000000000004 against 2, and the table's
exact-arithmetic (1, 0) at $3pi\/2$ against the pinned 0.9999999999999994.
The figure walks the same curve at twelve values of t, the
hand-computed points of the playground one-off joined by segments, and
the table lists the walk in exact arithmetic: the cardinal entries are
the ones whose double residues the listing pins.

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*t*], [0], [pi/6], [pi/3], [pi/2], [2pi/3], [5pi/6]),
  [*(x, y)*], [(4, 2)], [(3.598, 3)], [(2.5, 3.732)], [(1, 4)], [(-0.5, 3.732)], [(-1.598, 3)],
)
#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*t*], [pi], [7pi/6], [4pi/3], [3pi/2], [5pi/3], [11pi/6]),
  [*(x, y)*], [(-2, 2)], [(-1.598, 1)], [(-0.5, 0.268)], [(1, 0)], [(2.5, 0.268)], [(3.598, 1)],
)

#listing("math/samples/src/Ch04/transforms.c", first: 125, last: 146, caption: [polar pins and the ellipse residues at the four cardinal t])

#diagram([the parametric ellipse walked at twelve values of t], length: 13pt, {
  let pts = ((13.2, 3.1), (12.68, 4.4), (11.25, 5.35), (9.3, 5.7), (7.35, 5.35), (5.92, 4.4), (5.4, 3.1), (5.92, 1.8), (7.35, 0.85), (9.3, 0.5), (11.25, 0.85), (12.68, 1.8))
  for i in range(11) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(60))
  }
  cdraw.line(pts.at(11), pts.at(0), stroke: luma(60))
  cdraw.line((9.3, 3.1), (13.2, 3.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.circle((9.3, 3.1), radius: 0.07, stroke: none, fill: luma(60))
  cdraw.circle((13.2, 3.1), radius: 0.07, stroke: none, fill: luma(100))
  cdraw.content((9.3, 3.45), [(1,2)], size: 6pt)
  cdraw.content((13.2, 3.5), [t = 0], size: 6pt)
})

One parametric curve walked, the coordinate plane now carries points,
lines, circles, and transforms that compose. Vectors as a space, with
bases and the algebra that generalizes this plane, are next in
#xref-to("math", "vectors").

sources: mml-book draft 2024-01-15, ch 3 opener and section 3.1 norms
(pp 70-72 printed, eq 3.3 Manhattan, eq 3.4 Euclidean), section 3.2 dot
product (p 72 printed, eq 3.5), section 3.3 distance (p 75 printed, eq
3.21), section 3.4 angles (p 76 printed, eq 3.24 and eq 3.25), and ch 2
exercise 2.16e rotation as a linear map (p 68 printed), read from
ref/mml-book.pdf pages 74, 76-78, 81, and 82, cross verified page-scoped
on 2026-09-21 by text-layer extraction (this box has no pdf renderer,
and the inherited working notes cover pdf 74 and 76-82 the same way). Parametric
segment intersection, the line-circle
discriminant, circumcenter by bisectors, the conic sort, affine and
homogeneous matrices, and the polar and ellipse pins are derived in the
text and pinned exactly by the checks. The trig values behind them are
probed on this machine the same day, pins in the listings. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/math/samples/src -Chapter Ch04`, 51 checks in chapter
4 of the math suite.
