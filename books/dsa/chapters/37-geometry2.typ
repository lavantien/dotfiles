#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= computational geometry ii

Chapter 23 built the predicates: the orientation cross, the monotone
chain hull, closest pair, and the shamos-hoey boolean sweep. Chapter
24 added the exact lattice arithmetic and ray casting. This chapter
takes those as read and adds the layer above them: circles as
first-class objects with tangent lines and radical axes, region
algebra over half-planes, polygons summed and measured, and the
reporting sweep that lists every crossing instead of stopping at
the first one. Everything runs in float64 across the six languages,
decision predicates at eps 1e-9, pinned outputs rounded to six
decimals and asserted within 1e-6, negative zero normalized to
zero. The anchor application is icpc 2018 problem G (book 9,
chapter 9), whose panda preserve builds voronoi cells by exactly
this chapter's clip.

== line and circle intersections, tangents

Three o(1) constructions carry the section. Line against circle:
parametrize the line and project, which turns the intersection
into a quadratic in t whose discriminant classifies the answer,
negative for a miss, zero for tangency, positive for two hits.
Circle against circle: the radical line, project both centers onto
the center axis at distance a = (r1^2 - r2^2 + d^2) / (2d) and
erect the half-chord height h = sqrt(r1^2 - a^2), giving both
points at once and the tangency cases when h collapses. Common
tangents: from the base angle atan2(dy, dx), the outer pair sits
at acos((r1 - r2) / d) off the axis, the inner pair at
acos((r1 + r2) / d), and the count reads off the geometry, 0 when
one circle nests inside the other, 1 at the internal touch, 2
while they overlap, 3 at the outer touch, 4 when separate. Tangent
lines report normalized so the six languages pin identical lists:
unit normal (a, b), constant c with a times x plus b times y
equal to c, the first nonzero of (a, b) positive, the list sorted
by (a, b, c). Identical centers report the sentinel -1.

The dry run: the fixtures are the discriminant family on line
(0,0)-(4,0), the radical-line pairs around (0,0) r 2, and the
tangent quartet at distance 6, asserted by the C\# suite and
pinned to the same six-decimal values by the five sibling suites.

+ The discriminant classifies before any sqrt runs: center (2,2)
  r 1 sits 2 away from the line, miss, and (2,1) r 1 sits exactly
  1 away, the tangent point (2, 0).
+ Center (2,0.5) r 1 sits 0.5 away, so the half-chord is
  sqrt(1 - 0.25) = 0.866025 either side of the foot (2,0): the
  pair (1.133975, 0) and (2.866025, 0).
+ Circle (0,0) r 2 against (3,0) r 1 projects a = (4 - 1 +
  9) / 6 = 2 along the center axis with h = sqrt(4 - 4) = 0: the touch
  (2, 0).
+ Against (2,0) r 2: a = (4 - 4 + 4) / 4 = 1 and
  h = sqrt(4 - 1) = 1.732051, the pair (1, 1.732051) and (1, -1.732051), while
  (5,0) r 1 is too far and (1,0) r 1 inside r 3 nests, both empty.
+ Tangents (0,0) r 2 against (6,0) r 1: the outer pair sits
  acos(1/6) off the axis, normalized (0.166667, 0.986013, 2) and
  its mirror, and the inner pair acos(3/6) = 60 degrees off,
  (0.5, 0.866025, 2) and its mirror.
+ The count family: equal circles at distance 4 fold the inner
  pair into one line, 3 after normalization, the overlap at
  distance 2 keeps the 2 outer lines, the internal touch at
  distance 3 lands 3, and concentric input answers the sentinel.

#table(
  columns: (auto, 1.5fr, auto, 1.9fr),
  inset: 4pt,
  table.header([*probe*], [*one number*], [*verdict*], [*pinned*]),
  [line vs (2,2) r 1], [distance 2 > 1], [miss], [empty],
  [line vs (2,1) r 1], [distance 1 = 1], [tangent], [(2, 0)],
  [line vs (2,0.5) r 1], [sqrt(0.75) = 0.866025], [cut], [(1.133975, 0), (2.866025, 0)],
  [circles vs (3,0) r 1], [h = sqrt(4 - 4) = 0], [touch], [(2, 0)],
  [circles vs (2,0) r 2], [h = sqrt(4 - 1) = 1.732051], [cut], [(1, 1.732051) and (1, -1.732051)],
  [circles vs (5,0) r 1], [d = 5 > 3], [far], [empty],
  [circles r 3 vs (1,0) r 1], [d = 1 < 2], [nested], [empty],
)

The quartet of four normalized lines is the pinned landing, and
the listings below build all three constructions in six languages.

#listing("dsa/samples-c/src/Ch37/circles.c", first: 90, last: 131, caption: [c, the tangent count classifier plus the two angle loops])
#listing("dsa/samples/src/Ch37/Geometry2.cs", first: 82, last: 128, caption: [c\#, local functions emit the pair, the normalization a linq pass])
#listing("dsa/samples-go/ch37/circles.go", first: 63, last: 108, caption: [go, the add closure, normalized and sorted in place])
#listing("dsa/samples-js/src/ch37-circles.mjs", first: 64, last: 102, caption: [javascript, the map over emitted lines normalizes, the sort chain orders])
#listing("dsa/samples-py/src/Ch37/circles.py", first: 60, last: 93, caption: [python, the four branches with their tangency singles])
#listing("dsa/samples-lua/ch37_circles.lua", first: 60, last: 100, caption: [lua, emit closure, sign fix, three-key sort])

The fixtures pin every family. Line (0,0)-(4,0) against center
(2,2) r 1 misses, against (2,1) r 1 touches at (2, 0), against
(2,0.5) r 1 cuts at (1.133975, 0) and (2.866025, 0). Circle (0,0)
r 2 against (3,0) r 1 touches at (2, 0), against (2,0) r 2 cuts at
(1, 1.732051) and (1, -1.732051), against (5,0) r 1 is too far,
against (1,0) r 1 nests. The tangent family pins the normalized
lists whole: (0,0) r 2 against (6,0) r 1 gives the 4 lines
(0.166667, -0.986013, 2), (0.166667, 0.986013, 2), (0.5,
-0.866025, 2), (0.5, 0.866025, 2), the equal circles at distance 4
give 3 after normalization, the overlapping pair at distance 2
gives the 2 outer lines, and the internal touch at distance 3
gives 3. Concentric circles report the sentinel and zero
intersection points. Javascript carries all the trig in Number
with a comment saying so: the pinned six-decimal values sit far
from any double ambiguity, and the assert tolerance is the same
1e-6 everywhere.

#diagram([two circles at distance 6 with the four common tangent lines labeled by their normalized (a, b, c)], length: 13pt, {
  let m = (x, y) => (2.2 + x * 1.5, 4.6 + y * 1.5)
  // circles (0,0) r2 and (6,0) r1
  cdraw.circle(m(0, 0), radius: 3.0, stroke: luma(100))
  cdraw.circle(m(6, 0), radius: 1.5, stroke: luma(100))
  cdraw.content((m(0, 0).at(0) - 0.3, m(0, 0).at(1) - 3.5), [(0,0), r 2], size: 6pt)
  cdraw.content((m(6, 0).at(0) - 0.4, m(6, 0).at(1) - 2.0), [(6,0), r 1], size: 6pt)
  // a tangent line n=(a,b), c=2: touches circle1 at 2n, circle2 at
  // (c - 6a) n + (6,0); draw through both with a small extension
  let tan = (a, b, hot) => {
    let t1 = (a * 2, b * 2)
    let s2 = 2 - a * 6
    let t2 = (6 + a * s2, b * s2)
    let ext = (p, q, k) => (p.at(0) + (q.at(0) - p.at(0)) * k, p.at(1) + (q.at(1) - p.at(1)) * k)
    cdraw.line(m(..ext(t1, t2, -0.12)), m(..ext(t1, t2, 1.12)), stroke: if hot { luma(60) } else { luma(150) })
    cdraw.circle(m(..t1), radius: 0.09, fill: luma(60))
    cdraw.circle(m(..t2), radius: 0.09, fill: luma(60))
  }
  tan(0.166667, 0.986013, false)
  tan(0.166667, -0.986013, false)
  tan(0.5, 0.866025, true)
  tan(0.5, -0.866025, true)
  cdraw.content((m(3, 3.1).at(0), m(3, 3.1).at(1)), [inner pair crosses between the circles], size: 6pt)
  cdraw.content((m(3, -3.1).at(0), m(3, -3.1).at(1)), [outer pair keeps both circles on one side], size: 6pt)
  // the pinned normalized list as the legend
  cdraw.content((14.6, 7.6), [(0.166667, 0.986013, 2), outer], size: 6pt)
  cdraw.content((14.6, 6.7), [(0.166667, -0.986013, 2), outer], size: 6pt)
  cdraw.content((14.6, 5.8), [(0.5, 0.866025, 2), inner], size: 6pt)
  cdraw.content((14.6, 4.9), [(0.5, -0.866025, 2), inner], size: 6pt)
  cdraw.content((14.6, 3.6), [unit normal, first nonzero of], size: 6pt)
  cdraw.content((14.6, 2.7), [(a, b) positive, sorted by (a, b, c)], size: 6pt)
  cdraw.content((14.6, 1.8), [dots: the tangency points], size: 6pt)
})

Coverage questions under circle distance are the natural
consumers, but no finals problem in the six mined years reduces to
these constructions, so the row reads general technique.

== the length of a union of segments

Split every segment into two events, its left end tagged +1 and
its right end tagged -1, sort all 2n events by coordinate with
opens before closes at a tie, and sweep left to right adding x
minus last to the total whenever the coverage counter is positive.
The core is fifteen lines and the whole file under 120 sloc. The
same length falls out of #xref-to("dsa", "compression")'s merged
intervals, and the cross-name is the point: the event sweep is the
stream form, the one that generalizes to weighted coverage counts
and repeated sweeps over changing sets.

The dry run: the fixture is (1,4), (2,6), (8,10) with the nested
and float families beside, asserted by the C\# suite and pinned by
the five sibling suites.

+ The six events sort to (1,+1), (2,+1), (4,-1), (6,-1), (8,+1),
  (10,-1), opens before closes at a tie.
+ The counter is positive across 1 to 2, 2 to 4, and 4 to 6, so
  the sweep pays 2 - 1 = 1, 4 - 2 = 2, 6 - 4 = 2.
+ The counter is 0 across the gap to 8, which pays nothing, and
  the last span pays 10 - 8 = 2: 1 + 2 + 2 + 2 = 7.
+ The nested family (0,3), (1,2), (3,5) exercises the tie: the
  open at 3 sorts before the close, the touching ends merge, and
  the spans total 1 + 1 + 1 + 2 = 5.
+ The floats (0.5,1.5) and (1.0,2.5) pay 0.5 + 0.5 + 1.0 = 2.0,
  the overlap counted once.
+ A single point covers 0, empty input covers 0, and the unsorted
  copy of the first family still totals 7.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*event*], [*counter after*], [*added*], [*total*]),
  [(1, +1)], [1], [0], [0],
  [(2, +1)], [2], [2 - 1 = 1], [1],
  [(4, -1)], [1], [4 - 2 = 2], [3],
  [(6, -1)], [0], [6 - 4 = 2], [5],
  [(8, +1)], [1], [0], [5],
  [(10, -1)], [0], [10 - 8 = 2], [7],
)

The 7 over two covered spans and one gap is the pinned landing,
and the listings below run the sweep in six languages.

#listing("dsa/samples-c/src/Ch37/segunion.c", first: 25, last: 57, caption: [c, the composite qsort comparator and the coverage sweep])
#listing("dsa/samples/src/Ch37/Geometry2.cs", first: 131, last: 151, caption: [c\#, tuple events, the tie rule inside the sort lambda])
#listing("dsa/samples-go/ch37/segunion.go", first: 9, last: 37, caption: [go, the event struct and one sort call])
#listing("dsa/samples-js/src/ch37-segunion.mjs", first: 7, last: 25, caption: [javascript, the comparator chain by subtraction])
#listing("dsa/samples-py/src/Ch37/segunion.py", first: 14, last: 29, caption: [python, tuple sort gives the tie rule for free])
#listing("dsa/samples-lua/ch37_segunion.lua", first: 8, last: 27, caption: [lua, table.sort with the two-key closure])

The fixtures run integers, nesting, floats, and edges. Segments
(1,4), (2,6), (8,10) cover 7, two spans and one gap. The nested
family (0,3), (1,2), (3,5) totals 5, the touching ends merge
because the open event at 3 sorts before the close. Floats sweep
the same: (0.5,1.5) and (1.0,2.5) give 2.0. A single point covers
nothing, empty input covers nothing, and unsorted or reversed
input normalizes to the same totals, the suites pin that
invariance. Any comparable coordinate type works, which is why c
runs the sweep over doubles with a composite comparator while the
python version sorts raw tuples.

#diagram([three segments on one axis, the covered spans shaded on the ruler below, the gap marked], length: 13pt, {
  let m = (x) => (2.0 + x * 1.5, 0)
  let segrow = (y, a, b, hot) => {
    cdraw.line((m(a).at(0), y), (m(b).at(0), y), stroke: if hot { luma(100) } else { luma(160) })
    cdraw.circle((m(a).at(0), y), radius: 0.07, fill: luma(100))
    cdraw.circle((m(b).at(0), y), radius: 0.07, fill: luma(100))
  }
  segrow(6.4, 1, 4, true)
  cdraw.content((1.1, 6.4), [(1,4)], size: 6pt)
  segrow(5.3, 2, 6, true)
  cdraw.content((1.1, 5.3), [(2,6)], size: 6pt)
  segrow(4.2, 8, 10, true)
  cdraw.content((1.1, 4.2), [(8,10)], size: 6pt)
  // the event rail with coverage counts
  let rail = 2.6
  cdraw.line((m(0).at(0), rail), (m(11).at(0), rail), stroke: luma(120))
  for x in range(12) {
    cdraw.line((m(x).at(0), rail - 0.12), (m(x).at(0), rail + 0.12), stroke: luma(120))
  }
  // covered spans shaded under the rail
  cdraw.rect((m(1).at(0), rail - 0.75), (m(6).at(0), rail - 0.35), fill: luma(205))
  cdraw.rect((m(8).at(0), rail - 0.75), (m(10).at(0), rail - 0.35), fill: luma(205))
  // the gap bracket
  cdraw.line((m(6).at(0), rail + 0.5), (m(8).at(0), rail + 0.5), stroke: luma(100), mark: (start: "|", end: "|"))
  cdraw.content((m(7).at(0), rail + 0.9), [gap of 2], size: 6pt)
  // event ticks with deltas
  for (x, d, dy) in ((1, 1, 0.45), (2, 1, 0.45), (4, -1, 0.45), (6, -1, 0.45), (8, 1, 0.45), (10, -1, 0.45)) {
    cdraw.content((m(x).at(0), rail + dy), [#d], size: 6pt)
  }
  cdraw.content((m(3.4).at(0), rail + 1.5), [coverage positive: add x - last], size: 6pt)
  cdraw.content((2.0, 0.7), [3 + 2 + 2 = 7], size: 6pt)
  cdraw.content((16.4, 5.0), [2n events, opens before closes], size: 6pt)
  cdraw.content((16.4, 4.1), [one counter, one running last], size: 6pt)
  cdraw.content((16.4, 3.2), [O(n log n), the sort owns it], size: 6pt)
  cdraw.content((16.4, 2.3), [any comparable coordinate type], size: 6pt)
})

The application row reads general technique: painted-length
questions are common but none of the six mined finals reduces to
this exact sweep.

== point in a convex polygon

The fan test. Triangulate the strictly convex ccw polygon from
vertex 0: every interior point lands in exactly one wedge p0, pi,
pi+1, so binary search the wedge by the cross of p0 to pi against
q, then a single triangle orientation decides inside or outside.
The boundary is the honest part, and the exact branch earns its
lines: collinear cross within eps plus the edge's bounding box,
applied to the two fan edges up front, since the wedge search
itself cannot see them, and to the found wedge's closing edge.
Degenerate polygons of one or two vertices answer outside unless q
equals the point or an endpoint. The strict convexity
precondition is stated and asserted by the tests, every triple
turning left.

The dry run: the fixture is the pentagon (0,0), (4,0), (5,2),
(2,5), (-1,2) with the square (0,0), (4,0), (4,4), (0,4) beside,
asserted by the C\# suite and by the five sibling suites.

+ The two fan edges answer before any search: q = (-1,2) is
  vertex 4 itself, collinear with edge (0,0)-(-1,2) and inside its
  bounding box, boundary on the spot.
+ For q = (2,1) the wedge search opens lo = 1, hi = 4 and probes
  the middle ray: cross((5,2), (2,1)) = 5 - 4 = 1 nonnegative, so
  lo moves to 2.
+ The next probe reads cross((2,5), (2,1)) = 2 - 10 = -8, hi
  settles at 3, and the wedge is (0,2,3).
+ The closing edge decides: cross((-3,3), (2,1) - (5,2)) =
  3 + 9 = 12 positive, inside.
+ q = (3.5,3.5) lands the same wedge with closing cross exactly
  0, on the edge midpoint, boundary. q = (6,0) probes -12 at the
  middle ray, falls to wedge (0,1,2), and its closing cross of -4
  rules it outside.
+ On the square, (2,2) answers inside, (4,2) lands boundary on
  the closing edge, and (-0.001, 2) trips the fan door:
  cross((0,4), q) = 0.004, just past eps, outside.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*q*], [*cross(p0,p2,q)*], [*cross(p0,p3,q)*], [*wedge*], [*verdict*]),
  [(2,1)], [1], [-8], [(0,2,3)], [inside],
  [(3.5,3.5)], [10.5], [-10.5], [(0,2,3)], [boundary],
  [(2,5)], [21], [0], [(0,3,4)], [boundary],
  [(6,0)], [-12], [], [(0,1,2)], [outside],
  [(-1,2)], [], [], [fan edge], [boundary],
)

The inside, boundary, outside split over both polygons is the
pinned landing, and the listings below run the fan in six
languages.

#listing("dsa/samples-c/src/Ch37/pinconvex.c", first: 46, last: 76, caption: [c, the fan edges checked first, then the wedge search and the one-triangle verdict])
#listing("dsa/samples/src/Ch37/Geometry2.cs", first: 154, last: 186, caption: [c\#, locate as the enum answer, on-segment a boolean expression])
#listing("dsa/samples-go/ch37/pinconvex.go", first: 33, last: 67, caption: [go, the on-seg closure and the binary search])
#listing("dsa/samples-js/src/ch37-pinconvex.mjs", first: 22, last: 45, caption: [javascript, string answers, the shift-divide midpoint])
#listing("dsa/samples-py/src/Ch37/pinconvex.py", first: 29, last: 54, caption: [python, the degenerate family up front, the wedge loop after])
#listing("dsa/samples-lua/ch37_pinconvex.lua", first: 34, last: 74, caption: [lua, the two fan edges explicit, the bounding box spelled out])

The square (0,0), (4,0), (4,4), (0,4) answers inside at (2,2),
outside at (5,5) and at (-0.001, 2), boundary at (4,2), at the
vertex (0,0), and at the corner (4,4). The pentagon (0,0), (4,0),
(5,2), (2,5), (-1,2) answers inside at (2,1), boundary at the
vertices (2,5) and (-1,2), at the edge midpoint (3.5,3.5), outside
at (6,0). Every suite asserts strict convexity of its fixtures
before querying, and the lua suite keeps an all-edges oracle that
agrees with the fan on every query, the in-suite cross-check the
others get from their own fixture tables. O(log n) per query, no
preprocessing beyond having the polygon.

#diagram([the pentagon split into its fan from vertex 0, one query point per wedge shaded by answer], length: 13pt, {
  let m = (x, y) => (2.2 + x * 1.6, 0.8 + y * 1.6)
  let poly = ((0, 0), (4, 0), (5, 2), (2, 5), (-1, 2))
  // the fan wedges shaded alternately
  cdraw.line(..poly.map(p => m(p.at(0), p.at(1))), close: true, fill: luma(242), stroke: luma(100))
  for i in (2, 3) {
    cdraw.line(m(0, 0), m(..poly.at(i)), stroke: (paint: luma(170), dash: "dashed"))
  }
  let q = (x, y, lab, hot, dx, dy) => {
    cdraw.circle(m(x, y), radius: 0.13, fill: if hot { luma(170) } else { none }, stroke: luma(60))
    cdraw.content((m(x, y).at(0) + dx, m(x, y).at(1) + dy), lab, size: 6pt)
  }
  q(2, 1, [inside], true, 0.35, 0.12)
  q(6, 0, [outside], false, 0.3, -0.55)
  q(3.5, 3.5, [boundary], false, 0.35, 0.15)
  q(-1, 2, [vertex], false, -1.15, -0.15)
  q(2, 5, [vertex], false, -0.15, 0.55)
  // vertex indices placed toward the centroid so labels stay inside
  let cx = 2.0
  let cy = 1.4
  for (i, p) in poly.enumerate() {
    cdraw.circle(m(..p), radius: 0.09, fill: luma(100))
    let d = calc.sqrt((cx - p.at(0)) * (cx - p.at(0)) + (cy - p.at(1)) * (cy - p.at(1)))
    cdraw.content((m(..p).at(0) + (cx - p.at(0)) / d * 0.55, m(..p).at(1) + (cy - p.at(1)) / d * 0.55), [#i], size: 5.5pt)
  }
  cdraw.content((m(0, 0).at(0) - 0.4, m(0, 0).at(1) - 1.05), [vertex 0], size: 6pt)
  cdraw.content((m(1.0, 0.55).at(0), m(1.0, 0.55).at(1)), [wedge (0,1,2)], size: 5.5pt)
  cdraw.content((16.6, 6.2), [binary search the wedge], size: 6pt)
  cdraw.content((16.6, 5.3), [one cross per probe, O(log n)], size: 6pt)
  cdraw.content((16.6, 4.4), [fan edges hold the exact boundary], size: 6pt)
  cdraw.content((16.6, 3.5), [strict convexity asserted first], size: 6pt)
})

General technique in the topics row: point-in-polygon queries show
up everywhere, but the logged sweep and the fan search together
cover this book's needs and no mined finals problem pins the fan
specifically.

== minkowski sums

The sum of two convex polygons is the polygon swept by adding
every point of one to every point of the other, and it is convex
with a corner for every pair of corners that touch. The
construction rides the edge cycles. Normalize both operands ccw
starting at their lexicographic minima, read off both edge lists,
and merge them by polar angle exactly like a merge sort, because a
convex polygon's edges already wind by angle once around. Parallel
edges of the two operands advance together and fold into one step,
so collinear-carried vertices drop out and only true corners
survive, the same strict-hull convention as
#xref-to("dsa", "geometry"). The sum starts at the sum of the two
minima and closes when the merged edges return there. O(n + m),
integer inputs exact.

The dry run: the fixture is the unit square plus the triangle
(0,0), (2,0), (0,2), asserted by the C\# suite and by the five
sibling suites.

+ Both operands normalize ccw from their lexicographic minima, so
  the square's edges read (1,0), (0,1), (-1,0), (0,-1) and the
  triangle's (2,0), (-2,2), (0,-2).
+ The merge starts on the shared east direction: (1,0) and (2,0)
  are parallel, the walk advances both and folds them into the
  single step (3,0).
+ It then emits the square's (0,1), the triangle's (-2,2), the
  square's (-1,0), and folds the shared south direction (0,-1) +
  (0,-2) into (0,-3).
+ Accumulated from the start (0,0) + (0,0): (3,0), (3,1), (1,3),
  (0,3), and (0,-3) closes the cycle at (0,0), the pinned
  pentagon.
+ The edge lengths add 3 + 1 + 2 × sqrt(2) + 1 + 3 = 10.828427,
  the perimeter identity, 4 + 4 + 2 × sqrt(2) on the operand side.
+ The square plus the diamond (0,0), (1,1), (2,0), (1,-1) shares
  no direction with it, nothing folds, and 8 edges trace the
  pinned octagon, while a point operand is pure translation.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*angle*], [*square edge*], [*triangle edge*], [*merged step*], [*vertex now*]),
  [0], [(1,0)], [(2,0)], [(3,0), folded], [(3,0)],
  [90], [(0,1)], [], [(0,1)], [(3,1)],
  [135], [], [(-2,2)], [(-2,2)], [(1,3)],
  [180], [(-1,0)], [], [(-1,0)], [(0,3)],
  [270], [(0,-1)], [(0,-2)], [(0,-3), folded], [(0,0)],
)

The pentagon with its folded pair and the 10.828427 perimeter are
the pinned landing, and the listings below merge the cycles in six
languages.

#listing("dsa/samples-c/src/Ch37/minkowski.c", first: 87, last: 132, caption: [c, normalize, the edge lists, the two-pointer merge with the fold])
#listing("dsa/samples/src/Ch37/Geometry2.cs", first: 196, last: 229, caption: [c\#, the turn cross steering i and j, collinear advancing both])
#listing("dsa/samples-go/ch37/minkowski.go", first: 64, last: 107, caption: [go, unwrapped edge angles for the merge, a strict hull to finish])
#listing("dsa/samples-js/src/ch37-minkowski.mjs", first: 31, last: 66, caption: [javascript, the reorder helper then the cross-steered walk])
#listing("dsa/samples-py/src/Ch37/minkowski.py", first: 54, last: 87, caption: [python, the merge with the fold branch, a strict hull to drop carriers])
#listing("dsa/samples-lua/ch37_minkowski.lua", first: 61, last: 110, caption: [lua, the merge walk dropping collinear carriers as they form])

The fixtures pin canonical cycles starting at the lexicographic
minimum. The unit square plus the triangle (0,0), (2,0), (0,2)
sums to the pentagon (0,0), (3,0), (3,1), (1,3), (0,3) with
perimeter 10.828427, and the fold is visible: the square's east
edge (1,0) and the triangle's east edge (2,0) merge into the
single step (3,0). Two far squares sum to a square, 3 by 3. The
square plus the diamond (0,0), (1,1), (2,0), (1,-1) sums to the
octagon (0,0), (1,-1), (2,-1), (3,0), (3,1), (2,2), (1,2), (0,1),
no parallel edges to fold. A point plus the square is the square
translated. The property fixture pins the perimeter identity for
the first family: the perimeter of the sum equals the sum of the
perimeters, 10.828427 exact against the pinned value, and every
suite cross-checks the cycle against the strict hull of all
pairwise sums, the brute the construction must match.

#diagram([left: square plus triangle with the folded edge pair highlighted, right: square plus diamond tracing the octagon], length: 13pt, {
  let m1 = (x, y) => (1.6 + x * 0.95, 6.6 - y * 0.95)
  // square and triangle at left, sum edges as arrows beside
  cdraw.rect(m1(0, 0), m1(1, 1), fill: luma(240), stroke: luma(100))
  cdraw.line(m1(0, 0), m1(2, 0), stroke: luma(100))
  cdraw.line(m1(2, 0), m1(0, 2), stroke: luma(100))
  cdraw.line(m1(0, 2), m1(0, 0), stroke: luma(100))
  cdraw.content(m1(0.5, 0.5), [sq], size: 5.5pt)
  cdraw.content(m1(0.7, 1.3), [tri], size: 5.5pt)
  // the sum pentagon to the mid-left, folded pair highlighted
  let m2 = (x, y) => (6.4 + x * 0.95, 6.6 - y * 0.95)
  let p = ((0, 0), (3, 0), (3, 1), (1, 3), (0, 3))
  cdraw.line(..p.map(v => m2(..v)), close: true, fill: luma(242), stroke: luma(100))
  // the folded bottom edge bold: (1,0) + (2,0) = (3,0)
  cdraw.line(m2(0, 0), m2(3, 0), stroke: luma(40))
  cdraw.content(m2(1.5, -0.45), [(1,0) + (2,0) folds to (3,0)], size: 6pt)
  // the octagon at right
  let m3 = (x, y) => (13.0 + x * 0.95, 6.6 - y * 0.95)
  let sq = ((0, 0), (1, 0), (1, 1), (0, 1))
  let dia = ((0, 0), (1, 1), (2, 0), (1, -1))
  cdraw.line(..sq.map(v => m3(..v)), close: true, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line(..dia.map(v => m3(..v)), close: true, stroke: (paint: luma(150), dash: "dashed"))
  let oct = ((0, 0), (1, -1), (2, -1), (3, 0), (3, 1), (2, 2), (1, 2), (0, 1))
  cdraw.line(..oct.map(v => m3(..v)), close: true, fill: luma(242), stroke: luma(100))
  cdraw.content((m3(1.5, 1.9).at(0), m3(1.5, 1.9).at(1) + 0.7), [square + diamond = octagon], size: 6pt)
  cdraw.content((1.6, 2.6), [edges merge by polar angle], size: 6pt)
  cdraw.content((1.6, 1.7), [parallel edges fold, corners survive], size: 6pt)
  cdraw.content((1.6, 0.8), [perimeter of the sum = sum of perimeters], size: 6pt)
  cdraw.content((13.0, 0.8), [dashed operands, solid sum], size: 6pt)
})

General technique again: minkowski sums answer collision and
dilation questions directly, and no mined finals problem pins
them.

== rotating calipers

Diameter and width of a convex polygon in one linear walk after
the hull. Keep an antipodal index j: for each hull edge i, advance
j while the triangle area over that edge keeps growing, the cross
of the edge vector with the next edge at j staying positive. Every
(vertex, edge) antipodal event is visited exactly once, the
diameter is the maximum vertex pair distance over those events,
and the width is the minimum over edges of the maximum vertex
distance to the edge's supporting line. The hull is the
#xref-to("dsa", "geometry") monotone chain rebuilt in file so
every run stays standalone.

The dry run: the fixtures are the pentagon (0,0), (4,0), (5,2),
(2,5), (-1,2), its own hull, and the rectangle (0,0), (6,0),
(6,4), (0,4), asserted by the C\# suite and by the five sibling
suites.

+ Over the rectangle the antipodal events visit both diagonals:
  the pair (0,0)-(6,4) reads sqrt(36 + 16) = sqrt(52) = 7.211103,
  the diameter, and the horizontal edges hold every vertex within
  4, the width.
+ The pentagon's diameter peaks at (-1,2)-(5,2), distance 6.0,
  every other antipodal pair shorter.
+ The width scan measures each edge's supporting line: edge
  (0,0)-(4,0) holds (2,5) at 5, edge (4,0)-(5,2) holds (-1,2) at
  12 / sqrt(5) = 5.366563, and edge (-1,2)-(0,0) holds (5,2) at
  the same 5.366563.
+ Edge (5,2)-(2,5) on the line x + y = 7 holds (0,0) at 7 /
  sqrt(2) = 4.949747, and edge (2,5)-(-1,2) holds (4,0) at the
  same value: the twin minima.
+ The minimum over edges, 4.949747, is the width, and the
  collinear family (0,0), (3,0), (1,0) degenerates to a 2-point
  hull: diameter 3.0, width 0.

#diagram([the width scan as five bars, one per pentagon edge, the twin minima shaded, the axis truncated at 4.5], length: 13pt, {
  let vals = ((5.0, false), (5.366563, false), (4.949747, true), (4.949747, true), (5.366563, false))
  let names = ([0-1], [1-2], [2-3], [3-4], [4-0])
  for (i, e) in vals.enumerate() {
    let x = 3.0 + i * 2.3
    let h = (e.at(0) - 4.5) * 2.4
    cdraw.rect((x, 1.1), (x + 1.5, 1.1 + h), fill: if e.at(1) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 1.55 + h), [#e.at(0)], size: 6pt)
    cdraw.content((x + 0.75, 0.45), names.at(i), size: 6pt)
  }
  cdraw.line((2.5, 1.1), (14.8, 1.1), stroke: luma(120))
  cdraw.content((1.2, 1.1), [4.5], size: 6pt)
  cdraw.content((8.6, 4.6), [max vertex distance to each supporting line], size: 6.5pt)
  cdraw.content((8.6, -0.5), [the min over edges is the width, hit twice], size: 6pt)
  cdraw.content((17.8, 3.6), [diameter 6.0 at (-1,2)-(5,2)], size: 6pt)
  cdraw.content((17.8, 2.7), [rectangle: sqrt(52) and 4], size: 6pt)
  cdraw.content((17.8, 1.8), [every suite brute-checks the pairs], size: 6pt)
})

The 6.0 and the twice-hit 4.949747 are the pinned landing, and the
listings below walk the antipodal loop in six languages.

#listing("dsa/samples-c/src/Ch37/calipers.c", first: 104, last: 146, caption: [c, the antipodal walk, the candidate pairs, the width loop])
#listing("dsa/samples/src/Ch37/Calipers.cs", first: 14, last: 35, caption: [c\#, the walk and both measurements in one loop])
#listing("dsa/samples-go/ch37/calipers.go", first: 52, last: 96, caption: [go, the triangle-area advance and the two-candidate diameter update])
#listing("dsa/samples-js/src/ch37-calipers.mjs", first: 30, last: 81, caption: [javascript, the edge-cross advance, the width scan tracked forward])
#listing("dsa/samples-py/src/Ch37/calipers.py", first: 39, last: 81, caption: [python, antipodal-events as a list, diameter and width read off it])
#listing("dsa/samples-lua/ch37_calipers.lua", first: 53, last: 98, caption: [lua, the area-advance loop, then the width function])

The rectangle (0,0), (6,0), (6,4), (0,4) pins diameter 7.211103,
exactly sqrt(52), at the pair (0,0)-(6,4), width 4. The pentagon
hull pins diameter 6.0 at (-1,2)-(5,2) and width 4.949747, which
is 7 over sqrt(2), the max distance from vertex (0,0) to the line
through (5,2) and (2,5). The collinear edge case degenerates to a
2-point hull with diameter 3.0 and width 0, and every suite
cross-checks the diameter against a brute vertex-pair scan. The
honest contest note belongs here: icpc 2017 problem A (book 9,
chapter 8) asks for an optimal strip, and its answer equals the
point-set diameter only in special shapes. The finals solution
enumerates the O(n^2) vertex-pair chords, so this section
cross-names that problem as the kin without claiming its solution.

#diagram([the pentagon with both caliper support lines touching the diameter pair, one width measurement drawn], length: 13pt, {
  let m = (x, y) => (3.4 + x * 1.35, 0.9 + y * 1.35)
  let poly = ((0, 0), (4, 0), (5, 2), (2, 5), (-1, 2))
  cdraw.line(..poly.map(p => m(..p)), close: true, fill: luma(242), stroke: luma(100))
  for p in poly {
    cdraw.circle(m(..p), radius: 0.09, fill: luma(100))
  }
  // diameter pair (-1,2)-(5,2) bold with support lines
  cdraw.line(m(-1, 2), m(5, 2), stroke: luma(40))
  cdraw.line((m(-1.8, 2).at(0), m(-1, 2).at(1)), (m(5.8, 2).at(0), m(5, 2).at(1)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content(m(2, 2.35), [diameter 6.0], size: 6pt)
  // width: perpendicular from (0,0) to the line through (5,2)-(2,5)
  // foot of perpendicular from (0,0): param p = (5,2)+t(-3,3), t = -( (5,2).(-3,3) )/18 = -9/18*... compute t = -(5*-3+2*3)/18 = 9/18 = 0.5 -> (3.5,3.5)
  cdraw.line(m(0, 0), m(3.5, 3.5), stroke: luma(40), mark: (end: ">"))
  cdraw.content(m(1.1, 2.4), [width 4.949747], size: 6pt)
  cdraw.content(m(1.05, 1.75), [7 / sqrt(2)], size: 5.5pt)
  // the edge the width is measured against
  cdraw.line(m(5, 2), m(2, 5), stroke: luma(40))
  cdraw.content((16.4, 6.4), [advance j while the triangle], size: 6pt)
  cdraw.content((16.4, 5.5), [area over edge i still grows], size: 6pt)
  cdraw.content((16.4, 4.6), [diameter: max vertex pair], size: 6pt)
  cdraw.content((16.4, 3.7), [width: min over edge lines], size: 6pt)
  cdraw.content((16.4, 2.8), [O(n) after the hull], size: 6pt)
  cdraw.content((16.4, 1.9), [2017/A cross-named as kin only], size: 6pt)
})

== half-plane intersection

A half-plane is a triple (a, b, c) meaning a times x plus b times
y at most c. The book algorithm bootstraps a world box of 1e6,
four box half-planes prepended so unbounded regions have edges to
cut, normalizes every constraint to a unit normal, sorts by normal
angle folding same directions onto the tightest c, and rejects
contradictory opposite pairs, n dot p at most c1 together with
minus n dot p at most c2, which is empty exactly when c1 + c2 is
negative, before any geometry runs. Then the sort-and-incremental
deque: for each line in angle order pop the back while the back
corner violates the new line, pop the front likewise, push, and
after the sweep run both cleanups again because the last lines can
invalidate the first corners. The output is the ccw vertex cycle
rotated to the lexicographic minimum, plus a box-touch flag
reporting true unboundedness, any corner out past the box rim.

The dry run: the fixture is the 2018/G cell, the park box plus
three bisector half-planes, asserted by the C\# suite and by the
five sibling suites.

+ The park box normalizes to x at most 10, x at least 0, y at
  most 6, y at least 0, and the angle sort folds nothing: four
  distinct normal directions.
+ The bisector against (10,0) reads 20x at most 100, that is x at
  most 5, and the one against (0,10) reads 12y at most 36, that
  is y at most 3.
+ The diagonal bisector reads 20x + 12y at most 136, that is 5x +
  3y at most 34, and it passes exactly through the corner (5,3):
  25 + 9 = 34, an edge of zero length, dropped by the cleanup.
+ The deque sweep over the angle order leaves the 5 by 3 rectangle
  (0,0), (5,0), (5,3), (0,3), area 5 × 3 = 15, box flag false.
+ The triangle family clips y at least 1.5 under x + y at most 2
  and -x + y at most 2: at height 1.5 the base runs
  0.5 - (-0.5) = 1 and the apex sits at (0,2), area 0.25.
+ x at most 0 against x at least 1 is the contradictory pair,
  rejected before any geometry runs, and x at most 0 with y at
  most 0 alone reports unbounded, pinned at the world box corner.

#diagram([the 2018/G cell as a sequence of clips, the 10 by 6 park box narrowing to the 5 by 3 rectangle, the diagonal touching at the corner], length: 13pt, {
  let s = 0.42
  let frames = (
    ((0.8, 10, 6), [the park box]),
    ((6.4, 5, 6), [x at most 5]),
    ((12.0, 5, 3), [y at most 3]),
    ((17.6, 5, 3), [5x + 3y touches]),
  )
  for f in frames {
    let ((x0, w, h), title) = f
    cdraw.rect((x0, 2.0), (x0 + w * s, 2.0 + h * s), fill: luma(235), radius: 0.02)
    cdraw.rect((x0, 2.0), (x0 + 10 * s, 2.0 + 6 * s), stroke: luma(150), radius: 0.02)
    cdraw.content((x0 + 5 * s, 1.4), title, size: 6pt)
  }
  // the diagonal 5x + 3y = 34 crosses the box from (5,3) to (6, 4/3)
  cdraw.line((17.6 + 5 * s, 2.0 + 3 * s), (17.6 + 6 * s, 2.0 + 1.333 * s), stroke: luma(100))
  cdraw.circle((17.6 + 5 * s, 2.0 + 3 * s), radius: 0.08, fill: luma(60))
  cdraw.content((10.5, 5.6), [each bisector is one clip, the cell shrinks to 5 by 3], size: 6.5pt)
  cdraw.content((10.5, 0.6), [area 5 × 3 = 15, the zero-length edge dropped], size: 6pt)
  cdraw.content((10.5, -0.2), [touch point (5,3): 25 + 9 = 34], size: 6pt)
})

The area 15 cell is the pinned landing, and the listings below run
the deque sweep in six languages.

#listing("dsa/samples-c/src/Ch37/halfplane.c", first: 109, last: 153, caption: [c, the deque sweep, the two final cleanups, the corner sweep])
#listing("dsa/samples/src/Ch37/Calipers.cs", first: 93, last: 128, caption: [c\#, opposite-pair rejection, the linked-list deque, the unbounded flag])
#listing("dsa/samples-go/ch37/halfplane.go", first: 75, last: 124, caption: [go, slice deque popping front and back, the violation sweep at the end])
#listing("dsa/samples-js/src/ch37-halfplane.mjs", first: 52, last: 81, caption: [javascript, opposite pairs grouped by direction, the shift-and-pop deque])
#listing("dsa/samples-py/src/Ch37/halfplane.py", first: 84, last: 118, caption: [python, the slab test, the deque, the ccw fix and the box flag])
#listing("dsa/samples-lua/ch37_halfplane.lua", first: 46, last: 96, caption: [lua, table.remove at both ends, the orientation sum])

The square family, x and y each between -1 and 1, returns the
cycle (-1,-1), (1,-1), (1,1), (-1,1), area 4, box flag false. The
clip family y at least 0, x + y at most 2, minus x plus y at most
2, y at least 1.5 returns the triangle (-0.5,1.5), (0.5,1.5),
(0,2), area 0.25. The edges: x at most 0 against x at least 1 is
empty, and x at most 0 with y at most 0 alone is unbounded, box
flag true with the polygon pinned out at the world box corner
(-1000000,-1000000), (0,-1000000), (0,0), (-1000000,0). The
2018/G anchor is the fourth fixture: the voronoi cell of corner
(0,0) among the park corners (0,0), (10,0), (10,6), (0,6), clipped
to the park box, is the intersection of the bisector half-planes
x at most 5, y at most 3, 20x + 12y at most 136 with the box, and
it pins the cycle (0,0), (5,0), (5,3), (0,3), area 15. The 5x +
3y at most 34 bisector passes exactly through (5,3), so the
implementation drops the zero-length edge it would create, the
consecutive rounded-equal vertex cleanup every suite runs before
comparing cycles.

#diagram([the 10 by 6 park split into four voronoi cells meeting at the center, the (0,0) cell shaded, the covering radius arc drawn], length: 13pt, {
  let m = (x, y) => (2.4 + x * 1.35, 0.9 + y * 1.35)
  // park box
  cdraw.rect(m(0, 0), m(10, 6), stroke: luma(100))
  // center and bisectors
  cdraw.line(m(5, 0), m(5, 6), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line(m(0, 3), m(10, 3), stroke: (paint: luma(170), dash: "dashed"))
  // the diagonal bisectors of the (0,0) cell and its opposite
  cdraw.line(m(0, 0), m(5, 3), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line(m(10, 6), m(5, 3), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line(m(10, 0), m(5, 3), stroke: (paint: luma(205), dash: "dotted"))
  cdraw.line(m(0, 6), m(5, 3), stroke: (paint: luma(205), dash: "dotted"))
  // the (0,0) cell shaded
  let cell = ((0, 0), (5, 0), (5, 3), (0, 3))
  cdraw.line(..cell.map(p => m(..p)), close: true, fill: luma(215), stroke: luma(60))
  // the covering radius arc sqrt(34) around (0,0), through (5,3)
  cdraw.arc(m(0, 0), start: -8deg, stop: 88deg, radius: calc.sqrt(34) * 1.35, stroke: luma(100))
  cdraw.circle(m(0, 0), radius: 0.09, fill: luma(60))
  cdraw.circle(m(5, 3), radius: 0.09, fill: luma(60))
  cdraw.content((m(5, 3).at(0) + 0.4, m(5, 3).at(1) + 0.35), [(5,3)], size: 6pt)
  cdraw.content(m(2.5, 1.5), [area 15], size: 6pt)
  cdraw.content((m(8.6, 0.5).at(0), m(8.6, 0.5).at(1)), [bisectors: 2(t - s) . p at most |t|^2 - |s|^2], size: 6pt)
  cdraw.content((16.6, 6.4), [world box 1e6 prepended], size: 6pt)
  cdraw.content((16.6, 5.5), [sort by normal angle, fold repeats], size: 6pt)
  cdraw.content((16.6, 4.6), [empty slab: c1 + c2 below 0], size: 6pt)
  cdraw.content((16.6, 3.7), [incremental deque, both cleanups], size: 6pt)
  cdraw.content((16.6, 2.8), [radius sqrt(34) to the far corner], size: 6pt)
  cdraw.content((16.6, 1.9), [icpc 2018/G, book 9 chapter 9], size: 6pt)
})

The application is icpc 2018 problem G (book 9, chapter 9), the
panda preserve: each receiver's voronoi cell is built by exactly
this clip, cell against cell, and the covering radius comes from
voronoi vertices and edge crossings.

== the minimum enclosing circle

Welzl's move-to-front in its three-nested-loop form, the honest
deterministic shell around the randomized argument. Add points in
order, keep the current circle, and on a violation reset and
re-add the point on the boundary: the outer loop resets to the
point alone, the middle loop re-adds a second boundary point and
takes the circle on that diameter, the inner loop re-adds a third
and takes the circumcenter. The circle from two points is the
perpendicular bisector's midpoint, the circle from three is the
circumcenter determinant dividing by twice the signed area, and
the fixtures never approach the degeneracy where that denominator
collapses. Fixtures are at most 6 points with a unique enclosing
circle, so input order decides everything deterministically, and
the reference itself checked that a seeded shuffle posts the same
answers. The textbook note stays in prose: move-to-front runs in
expected O(n) under a random order, worst case O(n^3), and the
expected bound is why production versions shuffle first.

The dry run: the fixtures are the right triangle (0,0), (4,0),
(0,3) and the obtuse family (0,0), (1,0), (0.2,0.1), asserted by
the C\# suite and by the five sibling suites.

+ The outer loop opens on (0,0) alone, radius 0, and (4,0) lands
  outside: the reset keeps both as boundary points, and the circle
  on that diameter is center (2, 0), radius 2.
+ (0,3) checks in at distance sqrt(4 + 9) = sqrt(13) = 3.605551,
  past radius 2, a violation.
+ The middle loop resets to (0,0) and (4,0), the inner loop re-adds
  (0,3) as the third boundary point, and the circumcenter of the
  right triangle is the hypotenuse midpoint (2, 1.5) at half the
  hypotenuse, 5 / 2 = 2.5.
+ The obtuse family never violates: the diameter circle (0.5, 0)
  radius 0.5 holds (0.2,0.1) at sqrt(0.09 + 0.01) = 0.316228
  inside, so the pair answer stands and the circumcenter, which
  would fall outside, is never consulted.
+ The square corners pin the circumcircle (0, 0) radius 1.414214,
  the fourth corner checking in without a reset, and python's
  interior point (1,1) changes nothing.
+ A single point is its own radius-0 circle, and the pair (0,0),
  (6,8) meets at (3,4) radius 5.

#diagram([the welzl loop on the right triangle as three frames, the diameter circle violated, then the hypotenuse circumcircle closing], length: 13pt, {
  let s = 0.62
  // frame 1: (0,0) alone
  cdraw.circle((0.9, 6.9), radius: 0.07, fill: luma(60))
  cdraw.content((1.7, 4.9), [(0,0) alone, r 0], size: 6pt)
  // frame 2: circle on the diameter (0,0)-(4,0), (0,3) outside
  cdraw.circle((6.6 + 2 * s, 6.9), radius: 2 * s, stroke: luma(150))
  cdraw.line((6.6, 6.9), (6.6 + 4 * s, 6.9), stroke: (paint: luma(150), dash: "dashed"))
  for p in ((0, 0), (4, 0), (0, 3)) {
    cdraw.circle((6.6 + p.at(0) * s, 6.9 + p.at(1) * s), radius: 0.07, fill: luma(60))
  }
  cdraw.line((6.6 + 2 * s, 6.9), (6.6, 6.9 + 3 * s), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.75, 8.35), [sqrt(13) > 2], size: 5.5pt)
  cdraw.content((7.84, 4.9), [(4,0) violates: the diameter circle], size: 6pt)
  // frame 3: the circumcircle on the hypotenuse
  cdraw.circle((12.9 + 2 * s, 6.9 + 1.5 * s), radius: 2.5 * s, stroke: luma(100))
  cdraw.line((12.9, 6.9), (12.9 + 4 * s, 6.9 + 3 * s), stroke: (paint: luma(150), dash: "dashed"))
  for p in ((0, 0), (4, 0), (0, 3)) {
    cdraw.circle((12.9 + p.at(0) * s, 6.9 + p.at(1) * s), radius: 0.07, fill: luma(60))
  }
  cdraw.circle((12.9 + 2 * s, 6.9 + 1.5 * s), radius: 0.07, fill: luma(100))
  cdraw.line((11.55, 7.9), (13.9, 7.86), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((10.8, 7.9), [(2, 1.5)], size: 6pt)
  cdraw.content((14.14, 4.9), [(0,3) violates: the circumcircle], size: 6pt)
  cdraw.content((18.8, 5.6), [obtuse: no violation, no reset], size: 6pt)
  cdraw.content((18.8, 4.7), [r 2.5: half the hypotenuse 5], size: 6pt)
  cdraw.content((18.8, 3.8), [square: r 1.414214], size: 6pt)
  cdraw.content((18.8, 2.9), [expected O(n), shuffle first], size: 6pt)
})

The (2, 1.5) radius 2.5 circle is the pinned landing, and the
listings below run the triple loop in six languages.

#listing("dsa/samples-c/src/Ch37/mincircle.c", first: 44, last: 76, caption: [c, circle2 by the bisector, circle3 by the determinant, the welzl triple loop])
#listing("dsa/samples/src/Ch37/Calipers.cs", first: 186, last: 212, caption: [c\#, the enclosing local function, the nested resets])
#listing("dsa/samples-go/ch37/mincircle.go", first: 10, last: 55, caption: [go, the three closures and the triple loop])
#listing("dsa/samples-js/src/ch37-mincircle.mjs", first: 13, last: 50, caption: [javascript, destructured reassignments carrying the current circle])
#listing("dsa/samples-py/src/Ch37/mincircle.py", first: 22, last: 55, caption: [python, the determinant with its degeneracy guard])
#listing("dsa/samples-lua/ch37_mincircle.lua", first: 9, last: 53, caption: [lua, circle2 and circle3 above the same triple loop])

The right triangle (0,0), (4,0), (0,3) pins center (2, 1.5)
radius 2.5, the hypotenuse is the diameter. The obtuse family
(0,0), (1,0), (0.2,0.1) pins center (0.5, 0) radius 0.5, the
longest side wins because the circumcenter would fall outside.
The square corners pin the circumcircle, center (0,0) radius
1.414214. A single point is its own circle of radius 0, the pair
(0,0), (6,8) meets midways at (3,4) radius 5, and python adds the
fixture that an interior point changes nothing: the square plus
(1,1) still pins 1.414214.

#diagram([the right triangle inside its diameter circle with the midpoint marked, beside the square inside its circumcircle], length: 13pt, {
  // left: triangle (0,0),(4,0),(0,3), circle center (2,1.5) r 2.5
  let m1 = (x, y) => (1.7 + x * 1.5, 0.9 + y * 1.5)
  cdraw.circle(m1(2, 1.5), radius: 2.5 * 1.5, stroke: luma(100))
  let tri = ((0, 0), (4, 0), (0, 3))
  cdraw.line(..tri.map(p => m1(..p)), close: true, fill: luma(242), stroke: luma(60))
  cdraw.circle(m1(2, 1.5), radius: 0.1, fill: luma(60))
  cdraw.content((m1(2, 1.5).at(0) + 0.3, m1(2, 1.5).at(1) + 0.3), [(2, 1.5)], size: 6pt)
  cdraw.content(m1(2, -1.45), [r 2.5: the hypotenuse is the diameter], size: 6pt)
  // right: square corners, circumcircle
  let m2 = (x, y) => (11.6 + x * 1.5, 1.4 + y * 1.5)
  cdraw.circle(m2(0, 0), radius: 1.414214 * 1.5, stroke: luma(100))
  let sq = ((-1, -1), (1, -1), (1, 1), (-1, 1))
  cdraw.line(..sq.map(p => m2(..p)), close: true, fill: luma(242), stroke: luma(60))
  cdraw.circle(m2(0, 0), radius: 0.1, fill: luma(60))
  cdraw.content((m2(0, 0).at(0) - 0.2, m2(0, 0).at(1) - 0.55), [(0,0)], size: 6pt)
  cdraw.content(m2(0, -1.9), [r 1.414214: the circumcircle], size: 6pt)
  cdraw.content((16.8, 6.2), [obtuse: the longest side wins], size: 6pt)
  cdraw.content((16.8, 5.3), [violation resets, boundary re-adds], size: 6pt)
  cdraw.content((16.8, 4.4), [expected O(n), shuffle in prose], size: 6pt)
  cdraw.content((16.8, 3.5), [determinant divides 2 x the signed area], size: 6pt)
})

== voronoi cells and delaunay edges

The cell of site i is the set of points closer to i than to every
other site, and each such constraint is one half-plane: the
perpendicular bisector of s and t, written 2(t - s) dot p at most
|t|^2 - |s|^2, the same form the half-plane section already
computes. So build each cell as the world box clipped by one
bisector per other site, sutherland-hodgman against each in turn,
O(n) clips per cell and O(n^2) total. A delaunay edge exists
between two sites exactly when their cells share an edge segment
of positive length, adjacency read off rounded cells so clip noise
cannot invent or destroy an edge, and duplicate sites empty their
cells by rule. This is the 2018/G construction scaled to a family,
stated honestly against the literature: no flip algorithm, no
divide and conquer, the duality taught on the clipping construction
itself.

The dry run: the fixture is the four corners (0,0), (10,0),
(10,10), (0,10) over the world box (-10,-10) to (30,30), asserted
by the C\# suite and by the five sibling suites.

+ Cell 0 opens as the whole 40 by 40 box. The bisector against
  (10,0) is 20x at most 100, x at most 5, and the bisector against
  (0,10) reads y at most 5 the same way.
+ The bisector against (10,10) reads x + y at most 10, which only
  touches the remaining 15 by 15 square at its (5,5) corner: cell
  0 closes at area 225.
+ The opposite cell 2 is the 25 by 25 square at 625 and the two
  side cells run 15 by 25 at 375, and 225 + 375 + 625 + 375 = 1600
  tiles the box exactly.
+ The four cells meet only at the single point (5,5), so no shared
  segment crosses the diagonal: the delaunay list is the rim (0,1),
  (0,3), (1,2), (2,3), the cocircular degeneracy.
+ Adding the center site (5,5) grows its cell into the diamond
  (0,5), (5,0), (10,5), (5,10) of area 50 and cuts cell 0 by the
  new bisector x + y at most 5: 225 - 12.5 = 212.5, the corner
  triangle gone.
+ The delaunay list grows to the 4 rim edges plus the 4 spokes, 8
  total, and duplicate sites empty every copy but one.

#diagram([cell 0 as a sequence of clips, the 40 by 40 box narrowing to the 15 by 15 corner square, then the center site cutting the last triangle], length: 13pt, {
  let s = 0.085
  // local coords t = (x + 10, y + 10) inside [0, 40] squared
  let frames = (
    ((0.8, 40, 40, false), [the world box]),
    ((6.0, 15, 40, false), [x at most 5]),
    ((11.2, 15, 15, false), [y at most 5]),
    ((16.4, 15, 15, true), [center site: x + y at most 5]),
  )
  for f in frames {
    let ((x0, w, h, cut), title) = f
    cdraw.rect((x0, 1.6), (x0 + w * s, 1.6 + h * s), fill: luma(235), radius: 0.02)
    if cut {
      let p = (t) => (x0 + t.at(0) * s, 1.6 + t.at(1) * s)
      cdraw.line(p((15, 10)), p((15, 15)), p((10, 15)), close: true, fill: white)
      cdraw.line(p((15, 10)), p((10, 15)), stroke: luma(100))
    }
    cdraw.rect((x0, 1.6), (x0 + 40 * s, 1.6 + 40 * s), stroke: luma(150), radius: 0.02)
    cdraw.content((x0 + 20 * s, 1.0), title, size: 6pt)
  }
  cdraw.content((9.6, 5.7), [each bisector is one sutherland-hodgman clip], size: 6.5pt)
  cdraw.content((9.6, 0.2), [225 then 212.5, the cut triangle is 12.5], size: 6pt)
  cdraw.content((20.3, 4.4), [center diamond area 50], size: 6pt)
  cdraw.content((20.3, 3.5), [cocircular: no diagonal edge], size: 6pt)
  cdraw.content((20.3, 2.6), [areas always sum to 1600], size: 6pt)
})

The 225, 625, 50, and 212.5 areas are the pinned landing, and the
listings below clip the cells in six languages.

#listing("dsa/samples-c/src/Ch37/voronoi.c", first: 47, last: 92, caption: [c, the sutherland-hodgman clip and the cell-of loop])
#listing("dsa/samples/src/Ch37/Voronoi.cs", first: 10, last: 59, caption: [c\#, cells over the box list, the clip with its eps guards])
#listing("dsa/samples-go/ch37/voronoi.go", first: 8, last: 59, caption: [go, clip-half and the cells loop, duplicates emptying out])
#listing("dsa/samples-js/src/ch37-voronoi.mjs", first: 45, last: 87, caption: [javascript, the clip keeping the inside and cutting the crossing])
#listing("dsa/samples-py/src/Ch37/voronoi.py", first: 47, last: 82, caption: [python, the same pair, the canonical form beside])
#listing("dsa/samples-lua/ch37_voronoi.lua", first: 13, last: 52, caption: [lua, the clip and cells over the world box table])

The world box runs (-10,-10) to (30,30) and the fixtures pin
canonical cells and areas rounded to six decimals. Four corners
(0,0), (10,0), (10,10), (0,10): every cell is a 5-wide quadrant
rectangle of the box cut at x = 5 and y = 5, areas 225, 375, 625,
375, summing to the box's 1600. The cocircular degeneracy is
visible and pinned: all four cells meet only at (5,5), so the
delaunay edge list is exactly the rim (0,1), (0,3), (1,2), (2,3)
with no diagonal. Adding the center site (5,5) makes the center
cell the diamond (0,5), (5,0), (10,5), (5,10) with area 50, corner
cells gain one diagonal corner each, cell 0 cycling (-10,-10),
(5,-10), (5,0), (0,5), (-10,5) at area 212.5, and the delaunay
list grows to the 4 rim edges plus the 4 spokes (0,4), (1,4),
(2,4), (3,4), 8 total. Duplicate sites (2,2), (2,2), (5,1) leave
exactly 1 nonempty cell. The property fixture runs the 37.3 fan
test: every cell is convex and contains its site, and cell areas
always sum to the box area. The application is icpc 2018 problem
G (book 9, chapter 9) again, at n = 2000 receivers, this
construction verbatim.

#diagram([the four-corner box with the center site added, cells shaded, one shared edge bolded with its delaunay spoke], length: 13pt, {
  let m = (x, y) => (3.4 + x * 1.15, 0.9 + y * 1.15)
  // world window 0..10 shown, box rim dotted beyond
  cdraw.rect(m(0, 0), m(10, 10), stroke: luma(100))
  // the four corner cells shaded alternately (cut at 5)
  cdraw.rect(m(0, 0), m(5, 5), fill: luma(225))
  cdraw.rect(m(5, 0), m(10, 5), fill: luma(240))
  cdraw.rect(m(5, 5), m(10, 10), fill: luma(225))
  cdraw.rect(m(0, 5), m(5, 10), fill: luma(240))
  // the center diamond
  let dia = ((5, 0), (10, 5), (5, 10), (0, 5))
  cdraw.line(..dia.map(p => m(..p)), close: true, fill: luma(205), stroke: luma(60))
  // one shared edge bolded: cell0-cell4 edge (0,5)-(5,0)
  cdraw.line(m(0, 5), m(5, 0), stroke: luma(20))
  // the delaunay spoke 0-4
  cdraw.line(m(0, 0), m(5, 5), stroke: (paint: luma(20), dash: "dashed"), mark: (end: ">"))
  for (i, s) in (((0, 0)), ((10, 0)), ((10, 10)), ((0, 10)), ((5, 5))).enumerate() {
    cdraw.circle(m(..s), radius: 0.11, fill: luma(60))
    cdraw.content((m(..s).at(0) + 0.35, m(..s).at(1) + 0.3), [#i], size: 6pt)
  }
  cdraw.content((m(2.5, 8.6).at(0), m(2.5, 8.6).at(1)), [cell areas sum to the box], size: 6pt)
  cdraw.content((16.6, 6.2), [cell = box clipped by bisectors], size: 6pt)
  cdraw.content((16.6, 5.3), [shared segment = delaunay edge], size: 6pt)
  cdraw.content((16.6, 4.4), [center cell area 50], size: 6pt)
  cdraw.content((16.6, 3.5), [cocircular: no diagonal edge], size: 6pt)
  cdraw.content((16.6, 2.6), [O(n^2) cells, honest], size: 6pt)
  cdraw.content((16.6, 1.7), [2018/G at n = 2000], size: 6pt)
})

== the bentley-ottmann sweep

Report every crossing of a segment set in general position: no
vertical segments, no shared endpoints, no crossing shared by two
pairs. Events are segment endpoints and discovered crossings in a
heap ordered by (x, y). The status is an ordered list of segment
ids by height at the sweep x, tie-broken by slope. The discipline
is the same one #xref-to("dsa", "geometry")'s shamos-hoey boolean
sweep uses, neighbors only, never all pairs: on a left endpoint
insert by height and check the two new neighbor pairs, on a right
endpoint remove and check the seam, and on a crossing event swap
the pair, which the precondition keeps adjacent, then check both
new neighbor pairs. Every scheduled crossing lies strictly ahead
of the sweep and each pair fires at most once.

The dry run: the fixture is the three segments (0,4)-(10,4),
(2,0)-(6,8), (5,9)-(9,0), asserted by the C\# suite and by the
five sibling suites.

+ The endpoint events open the sweep: s0 enters alone at (0,4),
  then s1 enters below it at (2,0), and the fresh neighbor pair
  (s1,s0) schedules its crossing.
+ The heap pops that crossing first, at (4,4): report, swap, and
  s0 now sits below s1 with no new neighbor pair to check.
+ s2 enters on top at (5,9), the status s0, s1, s2 bottom to top:
  the pair (s1,s2) schedules (5.705882, 7.411765), while (s0,s1)
  has already fired and stays quiet.
+ That crossing reports and swaps s2 below s1, and the fresh pair
  (s0,s2) schedules (7.222222, 4).
+ s1 retires at (6,8) and the seam check finds (s0,s2) already
  scheduled, then the third crossing reports at (7.222222, 4) and
  the swap puts s2 below s0.
+ The right endpoints (9,0) and (10,4) drain the status empty:
  3 crossings, each pair fired once.

#diagram([the sweep as event columns, the status stack under each event with the highest on top, the three reports shaded], length: 13pt, {
  let cols = (
    ([x=0, s0+], ((0,),), none),
    ([x=2, s1+], ((0,), (1,)), none),
    ([x=4, cross], ((1,), (0,)), [(4,4)]),
    ([x=5, s2+], ((2,), (1,), (0,)), none),
    ([x=5.71, cross], ((1,), (2,), (0,)), [(5.705882, 7.411765)]),
    ([x=6, s1-], ((2,), (0,)), none),
    ([x=7.22, cross], ((0,), (2,)), [(7.222222, 4)]),
  )
  for (i, c) in cols.enumerate() {
    let x = 1.0 + i * 2.9
    let (title, stack, rep) = c
    cdraw.content((x + 0.75, 7.6), title, size: 6pt)
    for (k, id) in stack.enumerate() {
      cdraw.rect((x + 0.35, 6.5 - k * 0.62), (x + 1.15, 7.05 - k * 0.62), fill: luma(235), radius: 0.02)
      cdraw.content((x + 0.75, 6.775 - k * 0.62), [s#id], size: 6pt)
    }
    if rep != none {
      cdraw.line((x + 0.75, 6.35 - (stack.len() - 1) * 0.62), (x + 0.75, 4.35), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
      cdraw.rect((x - 0.75, 3.6), (x + 2.25, 4.25), fill: luma(205), radius: 0.02)
      cdraw.content((x + 0.75, 3.925), rep, size: 6pt)
    } else {
      cdraw.content((x + 0.75, 3.925), [...], size: 6pt)
    }
  }
  cdraw.content((10.0, 8.5), [top of stack = highest at the sweep x], size: 6.5pt)
  cdraw.content((10.0, 2.5), [insert checks 2 new pairs, a crossing checks 2 after the swap], size: 6pt)
  cdraw.content((10.0, 1.7), [then (9,0) and (10,4) drain the status], size: 6pt)
})

The three pinned crossings in heap order are the landing, and the
listings below run the sweep in six languages.

#listing("dsa/samples-c/src/Ch37/ottmann.c", first: 197, last: 226, caption: [c, the crossing event: find, adjacency check, swap, both new pairs])
#listing("dsa/samples/src/Ch37/Voronoi.cs", first: 129, last: 160, caption: [c\#, the event loop over the sorted set, insert, remove, swap])
#listing("dsa/samples-go/ch37/ottmann.go", first: 148, last: 174, caption: [go, the stale-event guard, the swap, the two schedules])
#listing("dsa/samples-js/src/ch37-ottmann.mjs", first: 125, last: 158, caption: [javascript, the three kinds over the heap, results sorted at the end])
#listing("dsa/samples-py/src/Ch37/ottmann.py", first: 82, last: 118, caption: [python, check-pair guards the schedule, the crossing branch last])
#listing("dsa/samples-lua/ch37_ottmann.lua", first: 145, last: 186, caption: [lua, the run loop with all three event kinds])

The plain-list status keeps inserts linear, so the honest worst
case is O((n + k) n), with the O((n + k) log n) balanced-tree
claim stated in prose, the discipline matching chapter 23. Every
suite cross-checks its sweep against the all-pairs orientation
test on the same fixtures. The three-segment family (0,4)-(10,4),
(2,0)-(6,8), (5,9)-(9,0) reports 3 crossings (4, 4), (5.705882,
7.411765), (7.222222, 4). The four-segment family reports 5:
(2, 0), (4.25, 2.75), (4.4, 2.4), (4.5, 2.5), (7, 0). Three
mutually disjoint segments terminate after their 6 endpoint
events with nothing scheduled. The seeded family draws 12 segments
from the pinned lcg, seed 10, endpoints as 4 values mod 101 with
vertical and degenerate draws rejected, and the suite pins exactly
11 crossings, first (25.207353, 55.124721), last (79.084648,
79.760402).

#diagram([the sweep frozen at a crossing event, the status stack beside it, the swap making two new neighbor pairs, one new crossing scheduled], length: 13pt, {
  // the F2 fixture: s0 (0,0)-(10,0), s1 (0,-2)-(10,8), s2 (1,6)-(9,-2),
  // s3 (2,8)-(5,1); frozen at the s1-s3 crossing (4.4, 2.4)
  let m = (x, y) => (2.0 + x * 1.05, 9.4 - y * 0.82)
  let segs = (((0, 0), (10, 0)), ((0, -2), (10, 8)), ((1, 6), (9, -2)), ((2, 8), (5, 1)))
  let labpos = ((-0.6, -0.3), (-0.6, -0.5), (-0.6, 0.4), (-0.7, 0.2))
  for (i, s) in segs.enumerate() {
    cdraw.line(m(..s.at(0)), m(..s.at(1)), stroke: luma(120))
    cdraw.content((m(..s.at(0)).at(0) + labpos.at(i).at(0), m(..s.at(0)).at(1) + labpos.at(i).at(1)), [s#i], size: 6pt)
  }
  // frozen sweep line at x = 4.4
  cdraw.line(m(4.4, -2.2), m(4.4, 8.4), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.content((m(4.4, 8.8).at(0), m(4.4, 8.8).at(1)), [sweep x = 4.4], size: 6pt)
  // the event itself: s1 x s3 at (4.4, 2.4)
  let cr = m(4.4, 2.4)
  cdraw.circle(cr, radius: 0.14, fill: luma(205), stroke: luma(60))
  cdraw.content((cr.at(0) - 1.5, cr.at(1) - 0.45), [(4.4, 2.4), s1 x s3], size: 6pt)
  // behind the sweep: (2,0) and (4.25,2.75) already reported
  for p in ((2, 0), (4.25, 2.75)) {
    let q = m(..p)
    cdraw.circle(q, radius: 0.1, fill: luma(150), stroke: none)
  }
  cdraw.content((m(2, 0).at(0) - 0.4, m(2, 0).at(1) - 0.55), [reported], size: 6pt)
  // ahead: (4.5, 2.5) scheduled by this very swap, (7, 0) still unscheduled
  let q1 = m(4.5, 2.5)
  cdraw.circle(q1, radius: 0.14, fill: none, stroke: luma(60))
  cdraw.content((q1.at(0) + 0.4, q1.at(1) + 0.4), [scheduled now: s1 x s2], size: 6pt)
  let q2 = m(7, 0)
  cdraw.circle(q2, radius: 0.14, fill: none, stroke: luma(150))
  cdraw.content((q2.at(0) + 0.3, q2.at(1) - 0.6), [not yet neighbors], size: 6pt)
  // status stacks: heights at 4.4 minus epsilon
  let stack = (x0, title, order) => {
    cdraw.content((x0, 5.7), title, size: 6pt)
    for (k, id) in order.enumerate() {
      cdraw.rect((x0 - 0.42, 5.0 - k * 0.68), (x0 + 0.42, 5.55 - k * 0.68), fill: luma(235), stroke: luma(150), radius: 0.02)
      cdraw.content((x0, 5.275 - k * 0.68), [s#id], size: 6pt)
    }
  }
  stack(15.2, [before], (2, 3, 1, 0))
  stack(17.8, [after], (2, 1, 3, 0))
  cdraw.content((16.5, 1.9), [s1 and s3 swap], size: 6pt)
  cdraw.content((16.5, 6.7), [top of stack = highest at the sweep x], size: 6pt)
  cdraw.content((4.5, -1.2), [neighbors only, never all pairs], size: 6pt)
  cdraw.content((4.5, -2.0), [each pair crosses at most once], size: 6pt)
})

== planar faces and point location

No samples ship for this section: the interesting machinery is the
arrangement bookkeeping, not another metered port, and the ottmann
suite already carries the sweep it would build on. Euler's formula
closes the face count of a connected planar embedding,
V - E + F = 2: run the ottmann sweep, split every segment at its crossings,
count vertices as endpoints plus crossings and edges as the split
pieces, and the faces fall out by subtraction. The faces
themselves are the cycles of the arrangement graph walked by the
next-half-edge rule, at each vertex take the outgoing edge
clockwise-adjacent to the one you arrived on, and every edge is
bordered by exactly two faces walked in opposite directions.
Point location then answers which face holds a query: the slab
method sorts the segments into vertical slabs and binary searches
each slab's ordered list in O(log n), and persistence structures
answer arbitrary planar subdivisions the same way. Ties back into
this chapter twice: the 2018/G boundary walk is a face traversal
on the voronoi arrangement, and the voronoi section's
cell-containment check is point location run cell by cell.

The dry run: no suite carries this section, the numbers are
hand-derived, and they stand on the ottmann suite's pinned
crossings for the four-segment family.

+ The family (0,0)-(10,0), (0,-2)-(10,8), (1,6)-(9,-2), (2,8)-
  (5,1) pins 5 crossings, so the arrangement holds V = 8 + 5 = 13
  vertices, endpoints plus crossings.
+ Splitting at the crossings: s0 collects (2,0) and (7,0) into 3
  pieces, s1 its three into 4, s2 its three into 4, s3 its two
  into 3.
+ E = 3 + 4 + 4 + 3 = 14 split edges, and the embedding is
  connected, every segment crossing at least one other.
+ Euler closes the count: F = 2 - V + E = 2 - 13 + 14 = 3, two
  bounded faces plus the outer one.
+ The bounded pair reads straight off the pinned crossings: the
  large cycle through (2,0), (4.5,2.5), (7,0) and the sliver
  (4.25,2.75), (4.5,2.5), (4.4,2.4).
+ Point location on the same arrangement is the slab method:
  sort the split edges into vertical slabs, binary search the
  slab, compare against its ordered edges.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*segment*], [*crossings on it*], [*pieces*]),
  [s0 (0,0)-(10,0)], [(2,0), (7,0)], [3],
  [s1 (0,-2)-(10,8)], [(2,0), (4.4,2.4), (4.5,2.5)], [4],
  [s2 (1,6)-(9,-2)], [(4.25,2.75), (4.5,2.5), (7,0)], [4],
  [s3 (2,8)-(5,1)], [(4.25,2.75), (4.4,2.4)], [3],
)

The face count 3 out of V - E + F = 2 is the landing, and the
figure below shades the two bounded faces it counts.

#diagram([a 4-segment arrangement with its bounded faces shaded and counted against V - E + F], length: 13pt, {
  let m = (x, y) => (2.4 + x * 1.25, 7.6 - y * 1.0)
  let segs = (((0, 0), (10, 0)), ((0, -2), (10, 8)), ((1, 6), (9, -2)), ((2, 8), (5, 1)))
  for s in segs {
    cdraw.line(m(..s.at(0)), m(..s.at(1)), stroke: luma(120))
  }
  // the two bounded faces: the s0-s1-s2 triangle over (2,0),(4.5,2.5),
  // (7,0), and the small s1-s2-s3 triangle near (4.25..4.5, 2.4..2.75)
  let f1 = ((2, 0), (4.5, 2.5), (7, 0))
  cdraw.line(..f1.map(p => m(..p)), close: true, fill: luma(215), stroke: none)
  let f2 = ((4.25, 2.75), (4.5, 2.5), (4.4, 2.4))
  cdraw.line(..f2.map(p => m(..p)), close: true, fill: luma(195), stroke: none)
  for s in segs {
    for p in s {
      cdraw.circle(m(..p), radius: 0.07, fill: luma(60))
    }
  }
  for p in ((2, 0), (4.4, 2.4), (7, 0), (4.25, 2.75), (4.5, 2.5)) {
    cdraw.circle(m(..p), radius: 0.1, fill: none, stroke: luma(60))
  }
  cdraw.content((m(4.5, 1.0).at(0), m(4.5, 1.0).at(1)), [F 1], size: 6pt)
  cdraw.content((m(4.38, 2.55).at(0) + 0.8, m(4.38, 2.55).at(1) + 0.75), [F 2], size: 6pt)
  cdraw.content((16.8, 7.4), [V = 8 endpoints + 5 crossings = 13], size: 6pt)
  cdraw.content((16.8, 6.5), [E = 3 + 4 + 4 + 3 split pieces = 14], size: 6pt)
  cdraw.content((16.8, 5.6), [V - E + F = 2 gives F = 3], size: 6pt)
  cdraw.content((16.8, 4.7), [two bounded faces, one outer], size: 6pt)
  cdraw.content((16.8, 3.8), [next-half-edge walks each cycle], size: 6pt)
  cdraw.content((16.8, 2.9), [slab search locates a query face], size: 6pt)
})

== the manhattan transform

Map (x, y) to (u, v) = (x + y, x - y). The L1 distance of two
points equals the chebyshev distance of their images, |dx| + |dy|
against max(|du|, |dv|), because the transform is a scaling and
45-degree rotation: the L1 ball is a diamond, the chebyshev ball
is the square it rotates into. The L1 diameter of a point set is
then read off the four extreme images, minimum u, maximum u,
minimum v, maximum v, a linear scan after the transformation,
with the O(n^2) pairwise scan kept in every suite as the oracle.
Integer inputs keep everything exact in all six languages.

The dry run: the fixture is (0,0), (1,5), (4,2), (6,6), asserted
by the C\# suite and by the five sibling suites.

+ The transform lands the images (u, v) = (x + y, x - y) at
  (0,0), (6,-4), (6,2), (12,0).
+ The u extremes are 0 at (0,0) and 12 at (6,6), spread 12 - 0 =
  12, and the v extremes are -4 at (1,5) and 2 at (4,2), spread
  2 - (-4) = 6.
+ The chebyshev diameter is the max of the spreads, 12, and the
  oracle agrees: the L1 distance of (0,0)-(6,6) is 6 + 6 = 12.
+ Every other pair sits at exactly 6 in both frames, so the four
  extreme images carry the whole answer.
+ The property family draws 20 seeded points and asserts the
  equality pairwise, and the edge family pins a single point at
  diameter 0 with the whole x = y line mapping to v = 0.

#diagram([the four uv images, the u spread of 12 shaded as the wide band, the v spread of 6 as the narrow one, the max wins], length: 13pt, {
  let m = (u, v) => (2.8 + (u + 1) * 0.72, 0.8 + (v + 5) * 0.72)
  cdraw.rect(m(0, -5), m(13, 3), stroke: luma(200))
  cdraw.rect(m(0, -4), m(12, 2), fill: luma(238), radius: 0.02)
  let pts = (((0, 0), [(0,0)], 0, -0.45), ((6, -4), [(6,-4)], 0.3, -0.45), ((6, 2), [(6,2)], 0.3, 0.35), ((12, 0), [(12,0)], 0, -0.8))
  for (p, lab, dx, dy) in pts {
    cdraw.circle(m(..p), radius: 0.1, fill: luma(60))
    cdraw.content((m(..p).at(0) + dx, m(..p).at(1) + dy), lab, size: 6pt)
  }
  cdraw.line((m(0, 3).at(0), m(0, 3).at(1) + 0.4), (m(12, 3).at(0), m(0, 3).at(1) + 0.4), stroke: luma(100), mark: (start: "|", end: "|"))
  cdraw.content((m(6, 3).at(0), m(0, 3).at(1) + 0.8), [u spread 12 - 0 = 12], size: 6pt)
  cdraw.line((m(13, -4).at(0) + 0.4, m(13, -4).at(1)), (m(13, 2).at(0) + 0.4, m(13, 2).at(1)), stroke: luma(100), mark: (start: "|", end: "|"))
  cdraw.content((m(13, 2).at(0) + 1.7, m(13, -1).at(1)), [v spread 6], size: 6pt)
  cdraw.content((m(6, -5).at(0), m(6, -5).at(1) - 0.95), [chebyshev = max(12, 6) = 12], size: 6pt)
  cdraw.content((17.6, 4.6), [diameter at the 4 extreme images], size: 6pt)
  cdraw.content((17.6, 3.7), [L1 oracle: 6 + 6 = 12], size: 6pt)
  cdraw.content((17.6, 2.8), [every other pair at 6], size: 6pt)
  cdraw.content((17.6, 1.9), [x = y maps to v = 0], size: 6pt)
})

The 12, the same number in both frames, is the pinned landing, and
the listings below transform and scan in six languages.

#listing("dsa/samples-c/src/Ch37/manhattan.c", first: 36, last: 71, caption: [c, the transform inline, the four extremes, the candidate pairs])
#listing("dsa/samples/src/Ch37/Calipers.cs", first: 230, last: 246, caption: [c\#, transform as a tuple, the diameter over image pairs])
#listing("dsa/samples-go/ch37/manhattan.go", first: 9, last: 44, caption: [go, the pick helper scanning for each extreme])
#listing("dsa/samples-js/src/ch37-manhattan.mjs", first: 8, last: 30, caption: [javascript, the index extremes, the u or v decision])
#listing("dsa/samples-py/src/Ch37/manhattan.py", first: 39, last: 65, caption: [python, the brute oracle and the four-corners scan side by side])
#listing("dsa/samples-lua/ch37_manhattan.lua", first: 8, last: 38, caption: [lua, to-uv and the four-extremes candidates])

The fixture points (0,0), (1,5), (4,2), (6,6) pin an L1 diameter
of 12 at the pair (0,0)-(6,6), and the chebyshev distance of the
images is also 12. The property family draws 20 seeded lcg points
and asserts the equality pairwise, every L1 distance in xy equal
to the chebyshev distance in uv, plus the four-extremes answer
against the full scan. The edges: a single point has diameter 0,
and every point on the x = y line maps to v = 0, pinned as a
family.

#diagram([the L1 ball, a diamond, rotating into the chebyshev ball, a square, with one distance pair drawn in both frames], length: 13pt, {
  // left frame: xy, diamond ball, pair (0,0)-(6,6) with the L1 path
  let m1 = (x, y) => (2.0 + x * 0.9, 6.4 - y * 0.9)
  let dia = ((-1.6, 0), (0, 1.6), (1.6, 0), (0, -1.6))
  cdraw.line(..dia.map(p => m1(..p)), close: true, fill: luma(240), stroke: luma(100))
  cdraw.line(m1(0, 0), m1(6, 0), stroke: luma(60))
  cdraw.line(m1(6, 0), m1(6, 6), stroke: luma(60))
  cdraw.circle(m1(0, 0), radius: 0.09, fill: luma(60))
  cdraw.circle(m1(6, 6), radius: 0.09, fill: luma(60))
  cdraw.content((m1(0, 0).at(0) - 0.4, m1(0, 0).at(1) - 0.4), [(0,0)], size: 6pt)
  cdraw.content((m1(6, 6).at(0) + 0.2, m1(6, 6).at(1) + 0.4), [(6,6)], size: 6pt)
  cdraw.content((m1(3, -0.9).at(0), m1(3, -0.9).at(1)), [L1 = 6 + 6 = 12], size: 6pt)
  cdraw.content((m1(0, 2.2).at(0), m1(0, 2.2).at(1)), [xy frame], size: 6.5pt)
  // right frame: uv, square ball, images (0,0) and (12,0)
  let m2 = (u, v) => (12.2 + u * 0.65, 6.4 - v * 0.65)
  let sq = ((-1.6, -1.6), (1.6, -1.6), (1.6, 1.6), (-1.6, 1.6))
  cdraw.line(..sq.map(p => m2(..p)), close: true, fill: luma(240), stroke: luma(100))
  cdraw.line(m2(0, 0), m2(12, 0), stroke: luma(60), mark: (end: ">"))
  cdraw.circle(m2(0, 0), radius: 0.09, fill: luma(60))
  cdraw.circle(m2(12, 0), radius: 0.09, fill: luma(60))
  cdraw.content((m2(0, 0).at(0) - 0.4, m2(0, 0).at(1) - 0.4), [(0,0)], size: 6pt)
  cdraw.content((m2(12, 0).at(0) + 0.2, m2(12, 0).at(1) + 0.4), [(12,0)], size: 6pt)
  cdraw.content((m2(6, -1.4).at(0), m2(6, -1.4).at(1)), [chebyshev = 12], size: 6pt)
  cdraw.content((m2(0, 2.2).at(0), m2(0, 2.2).at(1)), [uv frame], size: 6.5pt)
  // the rotation arrow between frames
  cdraw.line((9.9, 3.6), (11.4, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.6, 4.1), [rotate 45], size: 6pt)
  cdraw.content((16.8, 5.0), [u = x + y, v = x - y], size: 6pt)
  cdraw.content((16.8, 4.1), [diameter at the 4 extreme images], size: 6pt)
  cdraw.content((16.8, 3.2), [one linear scan after transform], size: 6pt)
  cdraw.content((16.8, 2.3), [x = y maps to v = 0], size: 6pt)
})

== across the six languages

Featured build size counted as non-blank, non-comment lines of the
chapter's sample files per language, the c\# family files carrying
their whole facet groups:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [1601], [static arrays, one file per facet], [qsort with composite comparators, memmove deque pops, all pins rounded 6 and asserted at 1e-6],
  [c\#], [662], [records, tuples, linq], [three family files, geometry2, calipers, voronoi, nullable tangents carry the sentinel],
  [go], [908], [math and sort only], [errors returned from halfplane, geo.go holds the shared point helpers],
  [javascript], [637], [node stdlib], [all trig in number with the safety comment, two per-chapter test files at 101 asserts],
  [python], [956], [stdlib math], [check harness with the ok-n print, brute oracles beside every construction],
  [lua], [1249], [lib.lua harness], [1-based tables throughout, string keys for delaunay segments, negative zero normalized in r6],
)

sources: cp-algorithms, "Circle-Line Intersection",
cp-algorithms.com/geometry/circle-line-intersection.html,
"Circle-Circle Intersection",
cp-algorithms.com/geometry/circle-circle-intersection.html,
"Finding common tangents to two circles",
cp-algorithms.com/geometry/tangents-to-two-circles.html, "Length
of the union of segments",
cp-algorithms.com/geometry/length-of-segments-union.html, "Check
if point belongs to the convex polygon in O(log N)",
cp-algorithms.com/geometry/point-in-convex-polygon.html,
"Minkowski sum of convex polygons",
cp-algorithms.com/geometry/minkowski.html, "Convex hull
construction", cp-algorithms.com/geometry/convex-hull.html,
"Half-plane intersection - S&I Algorithm in O(N log N)",
cp-algorithms.com/geometry/halfplane-intersection.html, "Minimum
Enclosing Circle",
cp-algorithms.com/geometry/enclosing-circle.html, "Delaunay
triangulation and Voronoi diagram",
cp-algorithms.com/geometry/delaunay.html, "Search for a pair of
intersecting segments",
cp-algorithms.com/geometry/intersecting_segments.html, "Finding
faces of a planar graph", cp-algorithms.com/geometry/planar.html,
"Point location in O(log n)",
cp-algorithms.com/geometry/point-location.html, and "Manhattan
Distance", cp-algorithms.com/geometry/manhattan-distance.html, all
accessed 2026-09-20, cc by-sa 4.0, our own words and code
throughout. Rotating calipers and the bentley-ottmann sweep have
no dedicated cp-algorithms article: the calipers section cites
"Convex hull construction" as the base plus clrs third edition
chapter 33 for the antipodal-pair argument, and the ottmann
section cites "Search for a pair of intersecting segments" for the
neighbor-ordering groundwork plus the same clrs chapter for the
full sweep. Application sources: icpc 2018 problem G (book 9,
chapter 9) for the half-plane, voronoi, and planar-faces sections,
and icpc 2017 problem A (book 9, chapter 8) cross-named as the
calipers kin. Sample behavior verified by the six suite gates
scoped to chapter 37: c 10 files and 113 checks, c\# 25 facts, go
31 test functions, javascript 35 tests and 101 asserts across the
two per-chapter files, python 10 files and 108 asserts, lua 38
checks, zero skipped.
