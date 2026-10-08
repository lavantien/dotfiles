#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= computational geometry

Computational geometry reduces to one integer question asked
thousands of times: for a directed segment a to b, which side is c
on. The cross product answers exactly, and the convex hull, the
closest pair, and the segment sweep are three classic algorithms
built on nothing more than its sign. This chapter keeps every
coordinate in an integer type and every predicate free of division,
and the tests hold each algorithm against brute force at seeded
scales.

== the orientation predicate

The cross product of b minus a with c minus a is twice the signed
area of the triangle a b c, and its sign is the whole engine:
positive when c sits left of the ray a to b, negative right, zero on
the line.

The dry run: the fixture is the right triangle (0,0), (4,0), (4,3)
with its swap and a collinear triple, plus one billion-scale pair,
asserted by the C\# suite with lua pinning the billion value again,
the other five settling for unit arms and their own segment shapes.

+ Cross of (0,0), (4,0), (4,3) reads 4 × 3 - 0 × 4 = 12, twice the
  triangle's area, and the turn is counter clockwise.
+ Swapping the last two arguments walks the same triangle from the
  other side: -12, clockwise.
+ The triple (0,0), (2,2), (4,4) sits on one line: 2 × 4 - 2 × 4 =
  0, collinear.
+ At a billion scale the products stay exact, 1,000,000,000 ×
  1,000,000,000 - 1 × 1 = 999999999999999999, a value no double can
  represent.

#table(
  columns: (1.9fr, 1.5fr, auto, auto),
  inset: 4pt,
  table.header([*a, b, c*], [*cross*], [*value*], [*turn*]),
  [(0,0), (4,0), (4,3)], [4 × 3 - 0 × 4], [12], [ccw],
  [(0,0), (4,3), (4,0)], [the same, swapped], [-12], [cw],
  [(0,0), (2,2), (4,4)], [2 × 4 - 2 × 4], [0], [collinear],
  [(0,0), (1e9, 1), (1, 1e9)], [1e18 - 1], [999999999999999999], [ccw],
)

The 999999999999999999, the value a double rounds away, is what the
listings below keep exact in seven integer types.

#listing("dsa/samples-c/src/Ch23/orientation.c", first: 21, last: 49, caption: [c, the sign of the cross, on-segment by bounding box, the four-orientation predicate])
#listing("dsa/samples-go/ch23/orientation.go", first: 27, last: 58, caption: [go, the bounding-box helper and the straddle predicate over orientation signs])
#listing("dsa/samples-java/src/Ch23/Orientation.java", first: 17, last: 50, caption: [java, the record point, `Long.signum` off the exact cross, the four-orientation predicate with bounding-box containment])
#listing("dsa/samples/src/Ch23/Geometry.cs", first: 19, last: 36, caption: [c\#, cross product, orientation sign, collinear containment])
#listing("dsa/samples-js/src/ch23-orientation.mjs", first: 4, last: 29, caption: [javascript, ccw sign then the same four-case predicate])
#listing("dsa/samples-py/src/Ch23/orientation.py", first: 13, last: 45, caption: [python, cross, turn sign, and the straddle predicate])
#listing("dsa/samples-lua/ch23_orientation.lua", first: 7, last: 39, caption: [lua, orientation answers by name, min and max for the box test])

The tests pin all three signs on one shape: cross of (0,0), (4,0),
(4,3) is 12, twice the area of legs 4 and 3, swapping the last two
arguments flips it to -12, and (0,0), (2,2), (4,4) gives 0.
Exactness is the point. Cross of (0,0), (1000000000, 1),
(1, 1000000000) is 999999999999999999, and a double rounds 1e18 - 1
up to 1e18 because adjacent doubles at that magnitude sit 128 apart.
Worse, a skinny triangle whose true cross is 1 rounds to 0 and the
predicate calls it collinear, and every wrong sign propagates into a
dropped hull corner or a missed crossing. In longs, coordinates in a
billion-wide box keep each product under 1e18 and the cross under
2e18, far inside the long ceiling of 9.22e18.

The seven listings agree on the shape and on the answers. Every suite
computes the sign in integer arithmetic, c in long long, go in
int64, java in long through `Long.signum`, lua in its native int64
and pins the billion-scale cross at
999999999999999999 with `math.type` reporting integer, the same
fixture and the same number as the c\# paragraph above. The segment
predicate is the same four orientations plus a bounding-box test in
all seven languages, and the crossing X, (0,0)-(4,4) against
(0,4)-(4,0) meeting at (2,2), is pinned true in c, go, java,
javascript, python, and lua, while the c\# suite meets its crossings
through
the sweep section below. The c, go, and java suites all add the T
shape
with a gap at the crossbar, parallel segments that never meet, and
collinear pairs both disjoint and overlapping, java pinning the
shared endpoint lane beside them, and lua pins its
collinear pair in both directions.

#diagram([the orientation predicate on one fixed segment, c left of a to b gives +12, on the line 0, right gives -12], length: 13pt, {
  // a -> b horizontal, c at (4,3), (2,0), (4,-3), scale 0.5 per unit
  let panel = (cx, c, cdx, cdy, title, note) => {
    let a = (cx - 1.0, 4.1)
    let b = (cx + 1.0, 4.1)
    cdraw.content((cx, 6.95), title, size: 6.5pt)
    cdraw.line(a, b, c, close: true, fill: luma(235), stroke: none)
    cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
    cdraw.line(a, c, stroke: luma(160))
    cdraw.line(b, c, stroke: luma(160))
    cdraw.circle(a, radius: 0.1, fill: luma(100))
    cdraw.circle(b, radius: 0.1, fill: luma(100))
    cdraw.circle(c, radius: 0.1, fill: luma(100))
    cdraw.content((a.at(0) - 0.05, a.at(1) - 0.45), [a], size: 6pt)
    cdraw.content((b.at(0) + 0.05, b.at(1) - 0.45), [b], size: 6pt)
    cdraw.content((c.at(0) + cdx, c.at(1) + cdy), [c], size: 6pt)
    cdraw.content((cx, 1.45), note, size: 6pt)
  }
  panel(4.0, (5.0, 5.6), 0.32, 0.0, [cross = +12], [left of a->b, ccw])
  panel(11.5, (11.5, 4.1), 0.0, 0.42, [cross = 0], [on the line])
  panel(19.0, (20.0, 2.6), 0.32, 0.0, [cross = -12], [right of a->b, cw])
})

#callout("pitfall", "doubles round the truth away", [
  At billion scale a cross lands near 1e18, where adjacent doubles
  sit 128 apart, and 1e18 - 1 rounds up to 1e18. A skinny triangle
  whose true cross is 1 rounds to 0 and the predicate calls it
  collinear. The fix costs nothing: keep coordinates in longs and
  every predicate exact, with 9.22e18 of headroom, and take the
  square root only when a distance, not a decision, is needed.
])

== the convex hull

The hull is the smallest convex polygon containing the set, and
Andrew's monotone chain builds it with the orientation predicate as
the only geometric operation. Sort the points lexicographically,
sweep left to right, and keep a chain of strict left turns: when the
top two chain points plus the candidate fail to turn left, pop. One
pass gives the lower chain, the reverse pass the upper, and the
concatenation walks the hull counter clockwise from the
lexicographically smallest point.

The dry run: the fixture is the seven point set, the 4 by 3
rectangle with (1,2), (2,1), and (3,2) inside, asserted by the C\#
suite, while C and java run their own squares, go adds an exterior
nub at (5,2), python pins a hexagon, and lua checks two properties.

+ Sorted by x then y the sweep enters (0,0), (0,3), (1,2), (2,1),
  (3,2), (4,0), (4,3), and the lower chain walks first.
+ Candidate (1,2) pops (0,3): the turn (0,0), (0,3), (1,2) reads
  0 × 2 - 3 × 1 = -3, not a left turn.
+ Candidate (2,1) pops (1,2) the same way at 1 × 1 - 2 × 2 = -3,
  and (3,2) survives its test at 2 × 2 - 1 × 3 = 1.
+ Candidate (4,0) pops twice, (3,2) at -3 then (2,1) at -4, leaving
  (0,0), (4,0), and (4,3) closes the pass at 4 × 3 - 0 × 4 = 12.
+ The upper sweep mirrors back through the same candidates, and on
  the way down the collinear triple (4,3), (3,2), (2,1) reads 0
  exactly, so the <= 0 test pops the middle point.
+ The mirrored pops leave the cycle (0,0), (4,0), (4,3), (0,3), the
  asserted four corners with all three interior points gone.

#table(
  columns: (auto, 1.1fr, 1.6fr, 1.9fr),
  inset: 4pt,
  table.header([*candidate*], [*turn*], [*action*], [*chain after*]),
  [(0,0)], [first], [push], [(0,0)],
  [(0,3)], [too short], [push], [(0,0), (0,3)],
  [(1,2)], [-3], [pop (0,3), push], [(0,0), (1,2)],
  [(2,1)], [-3], [pop (1,2), push], [(0,0), (2,1)],
  [(3,2)], [+1], [push], [(0,0), (2,1), (3,2)],
  [(4,0)], [-3, then -4], [pop twice, push], [(0,0), (4,0)],
  [(4,3)], [+12], [push, pass closes], [(0,0), (4,0), (4,3)],
)

The four corners (0,0), (4,0), (4,3), (0,3) are the pinned cycle,
and the listings below build them in seven languages.

#listing("dsa/samples-c/src/Ch23/hull.c", first: 36, last: 60, caption: [c, two chain sweeps, popping on a non-left turn])
#listing("dsa/samples-go/ch23/hull.go", first: 12, last: 47, caption: [go, monotone chain, exact duplicates dropped before the sweep])
#listing("dsa/samples-java/src/Ch23/Hull.java", first: 20, last: 51, caption: [java, the record point, the monotone chain over ArrayLists, cross \<= 0 pops])
#listing("dsa/samples/src/Ch23/Geometry.cs", first: 38, last: 69, caption: [c\#, monotone chain, two passes, strict turns pop collinear points])
#listing("dsa/samples-js/src/ch23-hull.mjs", first: 6, last: 28, caption: [javascript, one build helper run forward then reversed])
#listing("dsa/samples-py/src/Ch23/hull.py", first: 17, last: 31, caption: [python, sorted(set(...)) dedupes, two chain loops])
#listing("dsa/samples-lua/ch23_hull.lua", first: 10, last: 36, caption: [lua, a chain closure over the lexicographically sorted points])

A strict left turn fails on collinear too, since the pop tests <= 0,
so edge midpoints drop out: the four point set with (2,0) sitting on
the bottom edge returns only the triangle corners. The seven point
set keeps its four rectangle corners and drops all three interior
points. Seeded agreement holds against a brute force that keeps
exactly the points no triangle of the others covers, and the meter
counts each cross: every point is pushed once and popped at most once
per chain, so after the n log n sort the walk is linear.

Every suite pops on cross <= 0, so collinear edge points vanish and
the hull cycle carries only corners, and the c\# shape above is the
same code in the other six languages. The fixtures push in different
directions: c's square with three interior points returns its four
corners and a fully collinear input degenerates to two endpoints,
java carries that square, that collinear degenerate, python's
centered square and six vertex hull, and its own pentagon with one
interior point, go
adds an exterior nub at (5,2) to the square and pins the five vertex
cycle, python pins a six vertex hexagon and proves duplicates
collapse before the sweep, and lua checks two properties instead of
one answer, every cycle turn strictly counter clockwise and every
input point inside or on the hull by the half-plane test.

#diagram([the monotone chain on the fixed seven point set, candidates tested against the chain, failing turns shaded, the hull closed], length: 13pt, {
  // set (0,0),(0,3),(1,2),(2,1),(3,2),(4,0),(4,3), lower chain walk
  // frame 1 and the closed hull carry the coordinates, the rest stay bare
  let side-offs = (
    ((0, 0), -0.55, 0.0), ((0, 3), -0.05, 0.42), ((1, 2), 0.0, 0.42),
    ((2, 1), 0.0, -0.75), ((3, 2), 0.0, 0.42), ((4, 0), 0.6, 0.0),
    ((4, 3), 0.05, 0.42),
  )
  let frame = (fx, fy, chain, cand, pops, caption, labeled) => {
    let m = p => (fx + p.at(0) * 1.15, fy + p.at(1) * 0.62)
    cdraw.line(..chain.map(m), stroke: luma(100))
    if cand != none {
      cdraw.line(m(chain.last()), m(cand), stroke: (paint: luma(160), dash: "dashed"))
      cdraw.circle(m(cand), radius: 0.2, stroke: luma(60))
      cdraw.circle(m(cand), radius: 0.04, fill: luma(60))
    }
    for p in ((0, 0), (0, 3), (1, 2), (2, 1), (3, 2), (4, 0), (4, 3)) {
      if p == cand {
        continue
      }
      let pop = pops.find(x => x.at(0) == p)
      cdraw.circle(m(p), radius: if pop != none { 0.13 } else { 0.1 },
        fill: if p in chain or pop != none { luma(205) } else { luma(240) }, stroke: luma(150))
      if labeled {
        let off = side-offs.find(x => x.at(0) == p)
        cdraw.content((m(p).at(0) + off.at(1), m(p).at(1) + off.at(2)), [(#p.at(0), #p.at(1))], size: 6pt)
      }
      if pop != none {
        cdraw.content((m(p).at(0) + 0.55, m(p).at(1) - 0.45), pop.at(1), size: 6pt)
      }
    }
    cdraw.content((fx + 2.3, fy - 1.05), caption, size: 6pt)
  }
  frame(0.7, 6.5, ((0, 0), (0, 3)), (1, 2), (((0, 3), [-3]),), [(1,2): -3, pop], true)
  frame(6.9, 6.5, ((0, 0), (2, 1)), (3, 2), (), [(3,2): +1, keep], false)
  frame(13.1, 6.5, ((0, 0), (2, 1), (3, 2)), (4, 0), (((3, 2), [-3]), ((2, 1), [-4])), [(4,0): pop twice], false)
  frame(3.8, 1.7, ((0, 0), (4, 0), (4, 3)), none, (), [lower chain], false)

  // the closed hull, coordinates back for the reading, interior to the right
  let m5 = p => (10.0 + p.at(0) * 1.15, 1.7 + p.at(1) * 0.62)
  cdraw.line(m5((0, 0)), m5((4, 0)), m5((4, 3)), m5((0, 3)), close: true, fill: luma(235), stroke: luma(100))
  let in-offs = (((0, 0), -0.55, 0.0), ((0, 3), -0.05, 0.42), ((1, 2), 0.85, 0.0),
    ((2, 1), 0.85, 0.0), ((3, 2), 0.85, 0.0), ((4, 0), 0.6, 0.0), ((4, 3), 0.05, 0.42))
  for (p, dx, dy) in in-offs {
    let corner = p in ((0, 0), (4, 0), (4, 3), (0, 3))
    cdraw.circle(m5(p), radius: if corner { 0.1 } else { 0.13 }, fill: if corner { luma(205) } else { white }, stroke: luma(150))
    cdraw.content((m5(p).at(0) + dx, m5(p).at(1) + dy), [(#p.at(0), #p.at(1))], size: 6pt)
  }
  cdraw.content((12.3, 0.65), [hull closed, ccw], size: 6pt)
  cdraw.content((20.0, 4.3), [fixed set of seven], size: 6.5pt)
  cdraw.content((20.3, 3.4), [dark: chain], size: 6pt)
  cdraw.content((20.3, 2.55), [ring: candidate], size: 6pt)
  cdraw.content((20.3, 1.7), [shaded: popped], size: 6pt)
})

== closest pair

The closest pair splits at the median x, solves both halves, and
merges over the vertical strip of width 2δ, where δ is the smaller
recursive answer. A pair straddling the split must have both points
in that strip, the strip is scanned sorted by y, and each point is
compared only while the vertical gap stays under δ, because each δ by
δ half of the window holds at most 4 pairwise δ separated points, so
at most 7 others can sit above a point inside the window.

The dry run: the fixture is (0,0), (3,4), (10,10), (10,9), (2,2),
asserted by the C\# suite with lua pinning the same pair, while C,
go, and java land diagonal neighbors, javascript floats on hypot to
Math.SQRT2, and every suite cross-checks a brute double loop.

+ Sorted by x the array reads (0,0), (2,2), (3,4), (10,9), (10,10),
  and the top split lands after (3,4), the midpoint at x = 3.
+ The left half bottoms out at two points, (0,0) against (2,2)
  reading 2 × 2 + 2 × 2 = 8 squared.
+ The right half tries its three pairs: (3,4) against (10,9) reads
  49 + 25 = 74, against (10,10) reads 85, and (10,9) against (10,10)
  reads 0 + 1 = 1, the winner.
+ The smaller answer 1 prices the strip, points with (x - 3)² < 1:
  (3,4) survives alone, and (2,2) fails at exactly 1.
+ A strip of one point compares nothing, and the merge hands the
  winner up unchanged.

#diagram([the fixture's own run, the split with each half's best squared distance, then the strip holding exactly one point], length: 13pt, {
  // left frame: five points, split after (3,4), half answers 8 and 1
  let lx = p => (1.0 + p.at(0) * 1.05, 0.8 + p.at(1) * 0.42)
  cdraw.content((6.0, 6.0), [divide at the median, x = 3], size: 6.5pt)
  for p in ((0, 0), (2, 2), (3, 4), (10, 9), (10, 10)) {
    cdraw.circle(lx(p), radius: 0.11, fill: luma(235), stroke: luma(160))
  }
  cdraw.line((1.0 + 3 * 1.05, 0.4), (1.0 + 3 * 1.05, 5.5), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.line(lx((0, 0)), lx((2, 2)), stroke: luma(60))
  cdraw.line(lx((10, 9)), lx((10, 10)), stroke: luma(60))
  cdraw.circle(lx((10, 9)), radius: 0.24, stroke: luma(60))
  cdraw.circle(lx((10, 10)), radius: 0.24, stroke: luma(60))
  cdraw.content((2.3, 0.95), [left pair: 8], size: 6pt)
  cdraw.content((12.3, 4.0), [right best: 1], size: 6pt, anchor: "west")
  // right frame: the strip band x in (2, 4), only (3,4) strictly inside
  cdraw.content((17.0, 6.0), [the strip, squared width 1], size: 6.5pt)
  cdraw.rect((14.0 + 2 * 1.2, 0.4), (14.0 + 4 * 1.2, 5.5), fill: luma(240), stroke: none)
  for (p, hot) in (((0, 0), false), ((2, 2), false), ((3, 4), true)) {
    let rx = (14.0 + p.at(0) * 1.2, 0.8 + p.at(1) * 0.42)
    cdraw.circle(rx, radius: 0.11, fill: if hot { luma(205) } else { luma(235) }, stroke: luma(160))
  }
  cdraw.content((14.0 + 3 * 1.2, 0.8 + 4 * 0.42 + 0.5), [(3,4) alone], size: 6pt)
  cdraw.content((14.0 + 2 * 1.2, 0.8 + 2 * 0.42 - 0.55), [(2,2) fails at 1], size: 6pt)
  cdraw.content((19.2, 3.0), [10,9 and 10,10 sit outside], size: 6pt, anchor: "west")
  cdraw.content((19.2, 2.1), [49 away from the line], size: 6pt, anchor: "west")
  cdraw.content((19.2, 1.2), [one point, no comparisons], size: 6pt, anchor: "west")
})

The squared 1 between (10,9) and (10,10) is the pinned answer, and
the listings below find it in seven languages.

#listing("dsa/samples-c/src/Ch23/closestpair.c", first: 36, last: 74, caption: [c, the recursion with the strip insertion-sorted by y])
#listing("dsa/samples-go/ch23/closestpair.go", first: 25, last: 78, caption: [go, y order merged through the recursion, the textbook n log n])
#listing("dsa/samples-java/src/Ch23/Closestpair.java", first: 19, last: 64, caption: [java, squared long distances, the strip y-sorted by a comparator, the break when dy squared passes the best])
#listing("dsa/samples/src/Ch23/Geometry.cs", first: 71, last: 126, caption: [c\#, divide and conquer closest pair, the strip scanned in y with the break])
#listing("dsa/samples-js/src/ch23-closestpair.mjs", first: 7, last: 40, caption: [javascript, hypot distances, the strip filtered from a y-sorted copy])
#listing("dsa/samples-py/src/Ch23/closestpair.py", first: 29, last: 54, caption: [python, squared integer distances, the strip kept in y order])
#listing("dsa/samples-lua/ch23_closestpair.lua", first: 25, last: 60, caption: [lua, ys split by membership, the strip scan with the y break])

Distances stay squared, no square root until a human reads one. The
5 point test finds the vertical pair (10,9)-(10,10) at squared
distance 1, seeded 500 point runs match an O(n^2) scan exactly, and
at n = 1000 the strip meter stays under the classical 7 comparisons
per point. One honesty note: this version sorts the strip at every
merge instead of merging y order through the recursion, so it is
n log^2 n against the textbook n log n, and the packing bound
survives either way.

The strip handling is where the seven builds differ, and
every variant is honest about it. Go merges y order through the
recursion and is the textbook n log n, c re-sorts the strip with an
insertion sort, java re-sorts it with a plain comparator over
squared longs, and python and lua carry a y-sorted list through the
split, python by filtering it and lua by membership. The distance
type splits the same way: c, java, python, and lua compare squared
integers, go keeps the int64 products but accumulates the best as a
float64, and javascript is the one float suite, `Math.hypot`
distances with the fixture answer asserted as exactly `Math.SQRT2`.
Fixtures overlap where it matters: lua pins the same vertical pair
(10,9)-(10,10) at squared distance 1 as c\#, c, go, and java all
land on
a squared 2 answer from diagonal neighbors, java adding a unit
5 by 5 grid pinning 1 and a vertical line whose 4 gap squares to
16, and every suite
cross-checks the recursion against a brute-force double loop, lua
over five deterministic 37-point LCG clouds with no clock and no
`math.random`.

#diagram([closest pair as a pipeline of lanes, divide at the median x, recurse for the two best halves, merge over the strip in y order], length: 13pt, {
  // left (0,0),(0,3),(4,2), right (6,1),(6,4),(10,2): deltas 9 and 9, cross pair (4,2)-(6,1) = 5
  let pts = ((0, 0), (0, 3), (4, 2), (6, 1), (6, 4), (10, 2))
  let tx = p => 3.2 + p.at(0) * 1.05
  let dot = (p, ly, hot) => cdraw.circle((tx(p), ly + p.at(1) * 0.32), radius: 0.1,
    fill: if hot { luma(205) } else { luma(235) }, stroke: luma(160))

  cdraw.content((1.3, 7.0), [divide], size: 6.5pt)
  for p in pts {
    dot(p, 7.0, false)
  }
  cdraw.line((3.2, 6.15), (13.7, 6.15), stroke: luma(100))
  for x in (0, 6, 10) {
    cdraw.line((3.2 + x * 1.05, 6.15), (3.2 + x * 1.05, 5.98), stroke: luma(100))
    cdraw.content((3.2 + x * 1.05, 5.78), [#x], size: 6pt)
  }
  cdraw.line((9.5, 6.6), (9.5, 7.9), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((9.5, 8.3), [median x], size: 6pt)

  cdraw.content((1.3, 4.4), [recurse], size: 6.5pt)
  for p in pts {
    dot(p, 4.4, p == (0, 0) or p == (0, 3) or p == (6, 1) or p == (6, 4))
  }
  cdraw.line((3.2, 4.4), (3.2, 5.36), stroke: luma(60))
  cdraw.content((3.5, 4.9), [9], size: 6pt)
  cdraw.line((9.5, 4.72), (9.5, 5.68), stroke: luma(60))
  cdraw.content((9.8, 5.2), [9], size: 6pt)

  cdraw.content((1.3, 1.8), [merge], size: 6.5pt)
  cdraw.rect((6.35, 0.95), (12.65, 3.25), fill: luma(240), stroke: none)
  for p in pts {
    dot(p, 1.8, p == (4, 2) or p == (6, 1))
  }
  cdraw.line((tx((4, 2)), 1.8 + 2 * 0.32), (tx((6, 1)), 1.8 + 1 * 0.32), stroke: luma(60))
  cdraw.content((8.4, 2.75), [cross pair: 5], size: 6pt)

  cdraw.content((18.2, 7.3), [split at the median x], size: 6pt)
  cdraw.content((18.2, 6.4), [both halves recurse], size: 6pt)
  cdraw.content((18.2, 4.75), [left best 9, right best 9], size: 6pt)
  cdraw.content((18.2, 3.85), [the smaller is delta], size: 6pt)
  cdraw.content((18.2, 2.15), [strip of width 2δ, y sorted], size: 6pt)
  cdraw.content((18.2, 1.25), [the scan stops when dy passes δ], size: 6pt)
  cdraw.content((18.2, 0.35), [at most 7 comparisons per point], size: 6pt)
})

== the sweep line

Shamos-Hoey asks whether any two of n segments intersect and answers
in n log n by sweeping a vertical line across the endpoints. Events
are the endpoints, sorted by x with inserts ahead of erases at a
shared point, so segments touching at a corner meet inside the
status. The status orders the segments crossing the sweep line by
height there, compared exactly by cross multiplication. Two crossing
segments must become neighbors in that order, so it suffices to
compare an inserted segment against its immediate neighbors and to
compare the pair an erasure makes newly adjacent.

The dry run: the clean fixtures are asserted with identical
literals by all seven suites, the answers are (min, max) index
pairs with none for a disjoint input, and the error lanes reject
vertical segments and triple points, each tree picking its own
instance of three non-vertical segments through one point.

+ Both segments normalize left to right and emit four events, and
  the sort reads x first, then y, then inserts ahead of erases at a
  shared point.
+ The sweep opens at (0,0): s0 enters an empty status, no neighbors
  exist to test.
+ At (0,4) the insert compares heights by cross multiplication, s1
  reading 4 against s0's 0 at x = 0, so s1 lands above with s0 its
  only neighbor.
+ The check runs the four orientations and s1's endpoints read
  4 × 4 - 4 × 0 = 16 and 4 × 0 - 4 × 4 = -16 off s0's line, signs
  that straddle, so the pair crosses and the sweep returns (0, 1).
+ The touching pair (0,0)-(2,2) and (2,2)-(4,0) shares the corner
  (2,2): the second insert sorts ahead of the first's erase, they
  meet as neighbors inside the status, and the answer is (0, 1)
  again.
+ Disjoint back to back segments erase cleanly with no pair, and
  the C\# suite's 200 seeded segments agree with the O(n²)
  orientation scan.
+ The later pair fixture holds two safe horizontals in front of a
  crossing pair at x = 5 and answers (2, 3), and the early pair
  never touches.
+ The removal adjacency fixture slides a flat middle segment
  between the crossing pair, and when it erases at x = 6 the check
  on the newly adjacent neighbors finds the crossing at (10.5,
  10.5), answer (0, 1).
+ The error lanes mirror the C\# ArgumentException per tree: Go
  returns an error, JavaScript and Lua raise, Python raises
  ValueError, C reports a rejected input, Java returns minus one,
  each with its own valid
  triple point instance.
+ The oracle lane: the O(n^2) pairwise orientation test agrees on
  the yes/no answer of every clean fixture, in every suite.
+ Per-tree honesty: the C\# suite pins the crossing, the disjoint
  pair, the touch, and the seeded agreement, and the six sibling
  suites pin all five clean fixtures plus both error lanes.

#table(
  columns: (1.4fr, 1.2fr, 1.1fr, 1.8fr),
  inset: 4pt,
  table.header([*event*], [*action*], [*status*], [*neighbor check*]),
  [(0,0) insert s0], [place], [s0], [none, empty status],
  [(0,4) insert s1], [above s0], [s1, s0], [s0 × s1 straddles: crossing],
  [(4,4) erase s0], [never reached], [], [returned (0, 1)],
  [(4,0) erase s1], [never reached], [], [],
)

The pair (0, 1) at the crossing X is the pinned answer, and the
C\# listing below sweeps it in full, the six sibling windows
further down picking the walk up at the status.

#listing("dsa/samples/src/Ch23/Geometry.cs", first: 128, last: 181, caption: [shamos-hoey sweep, endpoint events, status by height, neighbor checks])

The preconditions are not decoration. A vertical segment has no single
height at the sweep, and three segments through one point make the
neighbor order ambiguous, so both are rejected with an exception, the
triple point check exact by collecting every crossing as a reduced
fraction. Touching endpoints count as intersections and back to back
disjoint segments do not, the crossing X returns the pair (0, 1), and
200 seeded segments agree with the O(n^2) orientation test. The
status is a plain list, so an insertion costs a shift and the worst
case is quadratic, and the discipline the chapter keeps is neighbors
only, never all pairs.

The six sibling builds now carry the full sweep themselves. The
windows below pick it up at the status walk, and the event sort
sits a few lines above in each file:

#listing("dsa/samples-c/src/Ch23/sweep.c", first: 185, last: 228, caption: [c, the status walk over a fixed array, binary insert by height, neighbor checks on insert, erase, and removal])

#listing("dsa/samples-go/ch23/sweep.go", first: 81, last: 109, caption: [go, the status slice with insert and delete by height, the removal adjacency check])

#listing("dsa/samples-java/src/Ch23/Sweep.java", first: 163, last: 203, caption: [java, the ArrayList status, the binary insert by cross-multiplied height, the three neighbor checks])

#listing("dsa/samples-js/src/ch23-sweep.mjs", first: 122, last: 161, caption: [javascript, the status array with a splice insert, the three neighbor checks])

#listing("dsa/samples-py/src/Ch23/sweep.py", first: 112, last: 139, caption: [python, the status list walk with the binary insert inlined])

#listing("dsa/samples-lua/ch23_sweep.lua", first: 124, last: 156, caption: [lua, the status walk over 1-based positions, the adjacency check after removal])

The substrate splits along the same lines as the rest of the
chapter. C shifts the status with memmove inside a fixed array,
Go inserts and deletes through the slices package, Java
binary-inserts into an ArrayList of segment indices and finds its
erasures by indexOf, JavaScript
splices and Python inserts into a list, both with the binary
search inlined, and Lua moves table positions. The height compare
and the binary insert sit in helper functions just above the
window in C, Go, Java, and Lua, and every height compare stays an
exact
cross multiplication, the same integer predicate the orientation
section opened with. The triple point detector needs crossings
as reduced fractions so distinct points never collide, integer
triple keys in C, Go, and Python, string keys in JavaScript and
Lua, a tuple key in the C\# original, and in Java the reduced
fraction carried as a three-long array compared elementwise. Each
tree picked its
own three non-vertical segments through one point for that error
lane, so the instance differs while the contract does not.

#diagram([the sweep at two consecutive events, the status stack beside each frame, the neighbor comparison at the insert finds the crossing], length: 13pt, {
  // s0 (0,0)-(9,3), s1 (0,6)-(9,6), s2 (3,2)-(8,7), s2 crosses s1 at (7,6)
  let draw-seg = (m, a, b, hot) => {
    cdraw.line(m(a), m(b), stroke: if hot { luma(60) } else { luma(150) })
    cdraw.circle(m(a), radius: 0.07, fill: luma(100))
    cdraw.circle(m(b), radius: 0.07, fill: luma(100))
  }
  let stack-box = (x, y, label, hot) => {
    cdraw.rect((x, y - 0.24), (x + 1.1, y + 0.24), fill: if hot { luma(205) } else { luma(235) }, stroke: luma(150), radius: 0.02)
    cdraw.content((x + 0.55, y), label, size: 6pt)
  }

  // frame 1: both left events at x = 0, status [s0, s1], compared and cleared
  let m1 = p => (1.0 + p.at(0) * 0.85, 2.5 + p.at(1) * 0.36)
  cdraw.content((4.8, 7.1), [the sweep at x = 0], size: 6.5pt)
  cdraw.line((1.0, 2.1), (1.0, 5.75), stroke: (paint: luma(120), dash: "dashed"))
  draw-seg(m1, (0, 0), (9, 3), false)
  draw-seg(m1, (0, 6), (9, 6), false)
  cdraw.content((9.15, 3.68), [s0], size: 6pt)
  cdraw.content((9.15, 4.76), [s1], size: 6pt)
  cdraw.content((10.65, 6.6), [status], size: 6pt)
  stack-box(10.1, 5.9, [s1], false)
  stack-box(10.1, 5.15, [s0], false)
  cdraw.content((4.8, 1.6), [both left events, neighbors disjoint], size: 6pt)

  // frame 2: insert s2 at x = 3, its neighbor s1 intersects, found
  let m2 = p => (13.0 + p.at(0) * 0.85, 2.5 + p.at(1) * 0.36)
  cdraw.content((17.3, 7.1), [the sweep at x = 3], size: 6.5pt)
  cdraw.line((15.55, 2.1), (15.55, 5.75), stroke: (paint: luma(120), dash: "dashed"))
  draw-seg(m2, (0, 0), (9, 3), false)
  draw-seg(m2, (0, 6), (9, 6), true)
  draw-seg(m2, (3, 2), (8, 7), true)
  cdraw.content((19.55, 5.3), [s2], size: 6pt)
  cdraw.circle(m2((7, 6)), radius: 0.2, stroke: luma(60))
  cdraw.content((18.3, 5.35), [(7,6)], size: 6pt)
  cdraw.content((21.55, 6.6), [status], size: 6pt)
  stack-box(21.0, 5.9, [s1], true)
  stack-box(21.0, 5.15, [s2], true)
  stack-box(21.0, 4.4, [s0], false)
  cdraw.content((17.3, 1.6), [insert s2, its neighbor s1 crosses], size: 6pt)
  cdraw.content((17.3, 0.75), [the test sees whole segments], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's four matrix topics, the c\# file covering all four in
one file:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [487], [`qsort` + fixed arrays], [long long coordinates, every fixture cross-checked by brute force, the sweep over event structs and memmove shifts],
  [go], [326], [`slices`, `cmp`], [merges y order through the recursion, int64 products into a float64 best, the sweep on slices insert and delete],
  [java], [488], [jdk 27 stdlib], [records for the points and events, segments as long arrays in the sweep, `Long.signum` off the cross, the strip re-sorted by a comparator, not one double in the chapter],
  [c\#], [228], [`List<T>`, `Enumerable.OrderBy`], [one file for the whole chapter, seeded 500-point agreement],
  [javascript], [227], [`Array.sort` comparators], [float only in the closest pair, the sweep exact in integer doubles],
  [python], [296], [`sorted`, `set`], [tuple points, squared integer distances, the sweep keyed by fraction tuples],
  [lua], [413], [`table.sort`], [native int64 exactness, deterministic LCG clouds, no `math.random`],
)

The sweep line section measured the same way, the c\# column
counting its region of the shared `Geometry.cs`:

#table(
  columns: (1.7fr, auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*section*], [*c*], [*c\#*], [*go*], [*java*], [*javascript*], [*python*], [*lua*]),
  [the sweep line], [240], [126], [175], [218], [140], [136], [190],
)

The sweep is the widest section in every tree, the status
machinery, the triple point rejection, and the segment predicate
all riding in one file per language, against a region of the
shared C\# file that leans on the orientation helpers above it.

sources: learn.microsoft.com, `List<T>.Insert` behind the status,
`Dictionary.GetValueOrDefault` counting crossings, `Enumerable.OrderBy`
sorting the hull input, clrs third edition chapter 33 for the sweep
and the strip argument, go.dev for `slices.SortFunc` and `cmp.Compare`,
developer.mozilla.org for `Math.hypot`, docs.python.org for `sorted`
and `set`, lua.org for `table.sort` and `math.type`, accessed
2026-09-12 and 2026-09-14. Sample behavior verified by the seven suite
gates scoped to chapter 23: c 4 files and 51 checks, c\# 11 tests,
go 13 tests, java 4 files and 72 checks, javascript 16 tests, python
4 files and 41 asserts, lua
21 checks, zero skipped.
