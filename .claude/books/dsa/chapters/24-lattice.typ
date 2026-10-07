#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= lattice geometry and grid algorithms

Integer grids get their own geometry. Polygons with corners on the
lattice have exact areas, exact boundary counts, and an exact
interior count, all in integer arithmetic, and grid traversal
reduces to a handful of neighbor deltas walked with a visited set.
Four tools cover the space: the shoelace formula with pick's
theorem, even-odd ray casting, flood fill, and the delta tables.
They are the working core of grid puzzle solving, the same pair
that answers polygon digging problems.

== shoelace area and pick's theorem

Walk the polygon's vertices in order and sum x~i~ y~j~ minus x~j~
y~i~ over each edge. The total is twice the signed area, positive
when the cycle runs counter clockwise, and doubling keeps every
coordinate product an integer. The boundary count comes from the
same walk: an edge between lattice points crosses exactly gcd of
dx, dy interior lattice points, so the boundary sum is one gcd per
edge. Pick's theorem closes the triangle, area equals interior plus
boundary over 2 minus 1, so the interior count falls out of two
exact integers.

The dry run: the fixture is the notch, a 6 by 4 block with a 2 by 2
bite out of the top, asserted by the C\# and lua suites as the
triple 40, 24, 9, while C runs a square and a pentagon, java a
square, a legs-6 triangle, and a pentagon, python a
4 by 3 rectangle, and javascript halves the sum early.

+ The walk circles counter clockwise from (0,0) through (6,0), (6,4),
  (4,4), (4,2), (2,2), (2,4), (0,4), eight edges, one shoelace term
  and one gcd each.
+ The eight terms sum 0 + 24 + 8 - 8 + 4 + 4 + 8 + 0 = 40, the
  6 × 4 block minus the 2 × 2 bite, doubled.
+ The eight gcds sum 6 + 4 + 2 + 2 + 2 + 2 + 2 + 4 = 24, the
  notch's four short walls adding 2 each.
+ Pick in doubled units lands (40 - 24 + 2) / 2 = 9 interior points.
+ The sibling square reads 32 counter clockwise and -32 reversed,
  the sign carrying the walk direction, and its pick is the same 9.
+ The brute sweep over the bounding box, boundary excluded, counts
  the same 9, the cross-check both suites run.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*edge*], [*term*], [*gcd*]),
  [(0,0) to (6,0)], [0], [6],
  [(6,0) to (6,4)], [24], [4],
  [(6,4) to (4,4)], [8], [2],
  [(4,4) to (4,2)], [-8], [2],
  [(4,2) to (2,2)], [4], [2],
  [(2,2) to (2,4)], [4], [2],
  [(2,4) to (0,4)], [8], [2],
  [(0,4) to (0,0)], [0], [4],
)

The triple 40, 24, 9 is what both suites assert, and the listings
below walk it in seven languages.

#listing("dsa/samples-c/src/Ch24/shoelace.c", first: 21, last: 49, caption: [c, the doubled signed area, gcd, and the per-edge boundary sum])
#listing("dsa/samples-go/ch24/shoelace.go", first: 8, last: 52, caption: [go, the same three functions, points borrowed from chapter 23])
#listing("dsa/samples-java/src/Ch24/Shoelace.java", first: 16, last: 51, caption: [java, the record point, doubled area kept whole, gcd boundary, pick with the parity-exact division])
#listing("dsa/samples/src/Ch24/Lattice.cs", first: 6, last: 38, caption: [c\#, shoelace, boundary points, pick in doubled units])
#listing("dsa/samples-js/src/ch24-shoelace.mjs", first: 6, last: 34, caption: [javascript, halves the sum early, pick flows from the half area])
#listing("dsa/samples-py/src/Ch24/shoelace.py", first: 13, last: 44, caption: [python, doubled area, gcd, floor-division pick])
#listing("dsa/samples-lua/ch24_shoelace.lua", first: 11, last: 38, caption: [lua, doubled area, boundary gcds, pick with floor division])

The anchor numbers agree across the fixture families. The 4 by 4
square gives doubled area 32, the reversed walk gives -32, and
pick's interior is 9 in c, c\#, java, and lua. C\# and lua share the
notch
fixture, a 6 by 4 block with a 2 by 2 bite out of the top, and pin
its doubled area 40, boundary 24, interior 9 as a triple. Python
uses a 4 by 3 rectangle, doubled 24, boundary 14, interior 6, and
cross-checks pick against a direct sweep of the bounding box that
counts strictly interior lattice points, as does lua on three
shapes. Java runs the square, a legs-6 right triangle at 36, 18,
10, and a pentagon at 40, 16, 13, carries python's rectangle as a
lane, and sweeps the box for the same strictly interior count. The
one structural difference is javascript, which halves
the shoelace sum immediately and lets the half flow into pick,
while the other six keep doubled units until the final division.

#diagram([the notch fixture with its shoelace terms, boundary gcds, and pick's interior count], length: 13pt, {
  // notch: (0,0) (6,0) (6,4) (4,4) (4,2) (2,2) (2,4) (0,4), area2 40, B 24, I 9
  let m = p => (2.2 + p.at(0) * 1.5, 1.2 + p.at(1) * 1.5)
  let poly = ((0, 0), (6, 0), (6, 4), (4, 4), (4, 2), (2, 2), (2, 4), (0, 4))
  cdraw.line(..poly.map(m), close: true, fill: luma(240), stroke: luma(100))
  for (i, p) in poly.enumerate() {
    cdraw.circle(m(p), radius: 0.09, fill: luma(100))
    let out = ((-0.15, -0.5), (0.15, -0.5), (0.5, 0.1), (0.5, 0.35), (0.45, -0.45), (-0.45, 0.45), (-0.5, 0.35), (-0.5, 0.1))
    cdraw.content((m(p).at(0) + out.at(i).at(0), m(p).at(1) + out.at(i).at(1)), [(#p.at(0), #p.at(1))], size: 6pt)
  }
  for x in range(0, 7) {
    for y in range(0, 5) {
      if not ((x == 0 or x == 6 or y == 0 or y == 4) or (x == 2 and y >= 2) or (x == 3 and y >= 2) or (x == 4 and y >= 2)) {
        if not (x, y) in poly {
          cdraw.circle(m((x, y)), radius: 0.045, fill: luma(160))
        }
      }
    }
  }
  cdraw.content((4.6, 8.3), [8 vertices, ccw from the origin], size: 6.5pt)
  cdraw.content((17.6, 7.3), [sum of x~i~y~j~ - x~j~y~i~ = 40], size: 6pt)
  cdraw.content((17.6, 6.4), [area 20 exactly, no float], size: 6pt)
  cdraw.content((17.6, 5.5), [boundary: one gcd per edge, 24], size: 6pt)
  cdraw.content((17.6, 4.6), [pick: I = 20 - 12 + 1 = 9], size: 6pt)
  cdraw.content((17.6, 3.7), [dark dots: the 9 interior points], size: 6pt)
  cdraw.content((17.6, 2.8), [reversed walk: -40], size: 6pt)
})

== even-odd ray casting

Shoot a horizontal ray east from the probe and count polygon edges
that cross it. An odd count means inside. The whole craft is in the
edge test: an edge crosses only when exactly one endpoint sits above
the ray's height, the half-open rule, which makes vertex hits and
horizontal edges count once or never instead of twice. The second
craft question is the boundary. A point exactly on an edge is a case
the parity rule does not settle, and the honest answers are an exact
on-boundary predicate or a stated convention, never a shrug.

The dry run: the fixture is the notch again, five inside probes and
five outside asserted by the C\# suite with the boundary cases
separated by the exact predicate, while the siblings split over
floats, integer division, and a third answer for the edge, java
carrying the float and the third-answer lanes in one file.

+ The probe (1,1) meets one straddling edge, the right wall, and its
  cross-multiplied test reads (1 - 6) × (-4) = 20 against 0: one
  east crossing, the parity flips once, inside.
+ The probe (3,3), inside the notch hole, straddles four edges, the
  two outer walls and the two notch walls.
+ The left walls cross west and do not count, while the outer right
  wall and the notch's right wall cross east: two flips, the parity
  lands even, the hole reads outside.
+ OnBoundary settles what parity cannot: (3,2) on the notch floor
  and the vertex (6,4) read true by the exact cross and span test,
  while (3,4), above the open notch, reads false.
+ The census closes at five trues and five falses, the far away
  (100,100) among the falses.

#table(
  columns: (1.7fr, 1.1fr, auto, auto),
  inset: 4pt,
  table.header([*edge of the notch*], [*above y = 3*], [*crossing*], [*flip*]),
  [floor (0,0)-(6,0)], [none], [-], [skip],
  [right wall (6,0)-(6,4)], [one], [east], [yes],
  [top lip (6,4)-(4,4)], [both], [-], [skip],
  [notch wall (4,4)-(4,2)], [one], [east], [yes],
  [notch floor (4,2)-(2,2)], [none], [-], [skip],
  [notch wall (2,2)-(2,4)], [one], [west], [skip],
  [top lip (2,4)-(0,4)], [both], [-], [skip],
  [left wall (0,4)-(0,0)], [one], [west], [skip],
)

The two east flips at (3,3) leave the hole honestly outside, and
the listings below cast this ray in seven languages.

#listing("dsa/samples-c/src/Ch24/raycast.c", first: 21, last: 36, caption: [c, the crossing loop with the half-open y rule, float intersection x])
#listing("dsa/samples-go/ch24/raycast.go", first: 5, last: 41, caption: [go, boundary declared inside up front, integer division for the crossing x])
#listing("dsa/samples-java/src/Ch24/Raycast.java", first: 16, last: 63, caption: [java, the float cast and the py lane in one file, on-boundary returning null before the parity count])
#listing("dsa/samples/src/Ch24/Lattice.cs", first: 47, last: 86, caption: [c\#, cross-multiplied comparison, no division anywhere, on-boundary separate])
#listing("dsa/samples-js/src/ch24-raycast.mjs", first: 8, last: 21, caption: [javascript, the parity loop, boundary deliberately unpromised])
#listing("dsa/samples-py/src/Ch24/raycast.py", first: 14, last: 42, caption: [python, on-boundary returns a third answer, none])
#listing("dsa/samples-lua/ch24_raycast.lua", first: 9, last: 36, caption: [lua, the parity loop plus an exact integer on-boundary predicate])

The exactness spectrum is the story. The c\# listing is the
canonical form, the crossing test multiplies out to
cross-multiplied integers and divides nowhere. Go computes the
crossing x with integer division but decides the boundary first.
Python and lua both cast the ray through float division and refuse
to let that decide the boundary, python's on-boundary test returns
a third answer, none, and lua's is an exact integer cross with a
min-max box, not a float equality cast. The c suite leans the other
way on purpose, floats throughout with the boundary behavior stated
as a convention: on the dented pentagon the apex reads inside while
a top-edge midpoint reads outside, and the tests pin that
asymmetry. Java carries both roads in one file, the same float cast
pinning that same asymmetry, apex inside, top-edge midpoint outside,
bottom-edge midpoint inside, beside a boundary-first lane whose
on-boundary test returns null, and it runs python's L-shape sweep
too, 11 half-step hits. Fixtures cover the same shapes, squares and
one concave
notch or dent each, and python sweeps an L-shape's bounding box on
half steps, counting hits against a parity argument.

#diagram([two probes through the notch polygon, the eastward ray and its edge crossings, plus one boundary probe], length: 13pt, {
  // notch polygon again: inside probe (1,1) ray crosses right wall once; notch probe (3,3) crosses twice
  let m = p => (2.2 + p.at(0) * 1.5, 1.4 + p.at(1) * 1.5)
  let poly = ((0, 0), (6, 0), (6, 4), (4, 4), (4, 2), (2, 2), (2, 4), (0, 4))
  cdraw.line(..poly.map(m), close: true, fill: luma(240), stroke: luma(100))
  // probe at (1,1): ray east crosses x=6 wall -> 1 crossing, inside
  let p1 = m((1, 1))
  cdraw.circle(p1, radius: 0.1, fill: luma(60))
  cdraw.line((p1.at(0) + 0.15, p1.at(1)), (m((6, 1)).at(0) + 0.7, p1.at(1)), stroke: luma(100), mark: (end: ">"))
  cdraw.circle(m((6, 1)), radius: 0.12, stroke: luma(60))
  cdraw.content((p1.at(0), p1.at(1) - 0.45), [(1,1)], size: 6pt)
  cdraw.content((m((4, 1)).at(0), p1.at(1) + 0.4), [1 crossing, odd: inside], size: 6pt)
  // probe at (3,3) inside the notch: ray east re-enters at x=4, exits at x=6
  let p2 = m((3, 3))
  cdraw.circle(p2, radius: 0.1, fill: none, stroke: luma(60))
  cdraw.line((p2.at(0) + 0.15, p2.at(1)), (m((6, 3)).at(0) + 0.7, p2.at(1)), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.circle(m((4, 3)), radius: 0.12, stroke: luma(60))
  cdraw.circle(m((6, 3)), radius: 0.12, stroke: luma(60))
  cdraw.content((p2.at(0), p2.at(1) + 0.45), [(3,3)], size: 6pt)
  cdraw.content((m((4.5, 3)).at(0), p2.at(1) - 0.5), [2 crossings, even: outside], size: 6pt)
  cdraw.content((2.0, 8.6), [the notch is a hole: its points read outside], size: 6pt)
  cdraw.content((17.6, 5.6), [edge crosses when exactly one], size: 6pt)
  cdraw.content((17.6, 5.1), [endpoint sits above the ray], size: 6pt)
  cdraw.content((17.6, 4.0), [half-open rule: vertex hits count once], size: 6pt)
  cdraw.content((17.6, 2.9), [boundary: exact predicate or], size: 6pt)
  cdraw.content((17.6, 2.4), [a stated convention, never a shrug], size: 6pt)
})

== flood fill

Repainting a connected region is breadth-first or depth-first
search wearing work clothes. Seed the start cell, walk neighbors of
the same character, mark cells when you enqueue or push them so
nothing enters the frontier twice, and paint as you go. The two
orders visit the same component and paint the same picture, only
the discovery order differs, and every suite pins that equality.

The dry run: the fixture is the 3 by 5 land-water grid, asserted by
the C\# and lua suites, while python paints a 5 by 4 with two
pockets, c and java walk walled 4 by 4s, javascript pins visit
order under
fixed deltas, and go fills an int grid.

+ The grid holds a water component of 6 with a second water pocket
  of 1 at (2,3), land components of 3, 4, and 1, and the sizes come
  back ascending: 1, 1, 3, 4, 6.
+ The fill from (0,0) marks on enqueue: (0,0) enters, (1,0) and
  (0,1) join behind it, and the queue empties at 3 painted cells,
  XXWWL, XWWLL, WWLWL.
+ Seeded at (0,2) instead the fill floods the water: (1,2) and
  (0,3) join first, then (1,1), then (2,1) and (2,0), six cells
  painting LLXXL, LXXLL, XXLWL.
+ The dfs stack visits the same six in a different order, and the
  assert is the two grids equal, cell by cell.
+ Refilling with the original character is the identity, every cell
  back to its own kind.

#diagram([the water fill's discovery order, stamps 1 through 6 marking when the queue met each cell], length: 13pt, {
  // grid LLWWL / LWWLL / WWLWL, water cells painted, stamps in queue order
  let rows = ("LLWWL", "LWWLL", "WWLWL")
  let stamps = (((0, 2), 1), ((1, 2), 2), ((0, 3), 3), ((1, 1), 4), ((2, 1), 5), ((2, 0), 6))
  for (r, row) in rows.enumerate() {
    for c in range(5) {
      let ch = row.slice(c, c + 1)
      let st = stamps.find(s => s.at(0) == (r, c))
      let top = 6.6 - r * 0.95
      cdraw.rect((1.6 + c * 1.5, top - 0.95), (3.1 + c * 1.5, top),
        fill: if st != none { luma(205) } else { luma(235) }, stroke: luma(180), radius: 0.02)
      cdraw.content((2.35 + c * 1.5, top - 0.48),
        if st != none { [#st.at(1)] } else { [#ch] }, size: 6.5pt)
    }
  }
  cdraw.circle((2.35 + 2 * 1.5, 6.6 - 0.48), radius: 0.34, stroke: luma(60))
  cdraw.content((5.35, 7.9), [the fill from (0,2), stamps in queue order], size: 6.5pt)
  cdraw.content((13.0, 6.6), [six water cells, one component], size: 6pt)
  cdraw.content((13.0, 5.6), [the seed ringed, bfs wave outward], size: 6pt)
  cdraw.content((13.0, 4.6), [land cells untouched: L], size: 6pt)
  cdraw.content((13.0, 3.6), [dfs paints the same six,], size: 6pt)
  cdraw.content((13.0, 3.1), [only the order differs], size: 6pt)
  cdraw.content((13.0, 2.1), [sizes 1, 1, 3, 4, 6], size: 6pt)
})

The sizes 1, 1, 3, 4, 6 are the pinned family, and the listings
below flood this grid in seven languages.

#listing("dsa/samples-c/src/Ch24/floodfill.c", first: 33, last: 57, caption: [c, the bfs fill marking on enqueue, delta arrays above])
#listing("dsa/samples-go/ch24/floodfill.go", first: 14, last: 38, caption: [go, the fill returns cells in discovery order, marked on enqueue])
#listing("dsa/samples-java/src/Ch24/Floodfill.java", first: 36, last: 78, caption: [java, the ArrayDeque bfs and its dfs twin, one marking discipline, cells painted on enqueue])
#listing("dsa/samples/src/Ch24/Lattice.cs", first: 88, last: 121, caption: [c\#, component sizes for every same-character region, ascending])
#listing("dsa/samples-js/src/ch24-floodfill.mjs", first: 8, last: 34, caption: [javascript, one fill parameterized by take, shift for bfs, pop for dfs])
#listing("dsa/samples-py/src/Ch24/floodfill.py", first: 24, last: 41, caption: [python, queue plus head index, marks on enqueue])
#listing("dsa/samples-lua/ch24_floodfill.lua", first: 14, last: 36, caption: [lua, strings repainted by splice, seen keyed by r times 100 plus c])

The fixtures split by family. C\# and lua share the 3 by 5
land-water grid and pin its component sizes 1, 1, 3, 4, 6, lua also
pinning that the bfs and dfs fills return identical grids. Python's
5 by 4 grid carries two open pockets, 8 cells and 7 cells, and
component sizes 7, 8, with the whole painted picture asserted cell
by cell and dfs asserting the same. C walks a 4 by 4 with walls,
and java walks its own walled 4 by 4 holding one 9-cell region and
two isolated single-cell holes, its bfs and dfs twins pinned to the
same painted footprint, deltas in parallel up, down, left, right
arrays. Javascript pins visit orders under its fixed down, right,
up, left
delta order, and go fills an int grid and returns the repainted
cells in the order the queue found them. The invariant under all
seven: mark on enqueue, never on dequeue, or a cell enters the
frontier twice and the fill loops or doubles.

#diagram([python's 5 by 4 fixture, the left pocket of 8 painted by the fill, the right pocket of 7 untouched], length: 13pt, {
  // grid "..#.." / ".##.." / "..#.." / "...#.", left pocket painted
  let rows = ("..#..", ".##..", "..#..", "...#.")
  let painted = ("xx#..", "x##..", "xx#..", "xxx#.")
  for (r, row) in rows.enumerate() {
    for c in range(5) {
      let ch = row.slice(c, c + 1)
      let pch = painted.at(r).slice(c, c + 1)
      let hot = pch == "x"
      cdraw.rect((2.0 + c * 1.5, 6.2 - r * 0.9), (3.5 + c * 1.5, 7.1 - r * 0.9),
        fill: if ch == "#" { luma(120) } else if hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((2.75 + c * 1.5, 6.65 - r * 0.9),
        if ch == "#" { [\#] } else if hot { [x] } else { [.] }, size: 7pt)
    }
  }
  cdraw.circle((2.75, 6.65), radius: 0.32, stroke: luma(60))
  cdraw.content((2.75, 5.7), [seed (0,0)], size: 6pt)
  cdraw.content((11.0, 7.6), [walls \#, open cells .], size: 6.5pt)
  cdraw.content((11.0, 6.6), [the fill paints the pocket it seeds], size: 6pt)
  cdraw.content((11.0, 5.6), [left pocket: 8 cells, painted], size: 6pt)
  cdraw.content((11.0, 4.6), [right pocket: 7 cells, untouched], size: 6pt)
  cdraw.content((11.0, 3.6), [component sizes 7, 8], size: 6pt)
  cdraw.content((11.0, 2.6), [bfs and dfs paint the same picture], size: 6pt)
})

== neighbor deltas and 3d walks

Every grid walk in this book reduces to a delta table and a
bounds check. The 4-neighborhood is the von Neumann one, the
8-neighborhood adds the diagonals, and in 3d the 6-neighborhood is
the cube's faces. The delta order is free to differ between
languages because only the visit order depends on it, never the
reachable set.

The dry run: the fixture is a 3 by 3 for the delta enumeration and
three boxes for the 3d walks, asserted by the C\# suite, while C
and java price the 5 by 5 edge counts, lua walks a slab, python
blocks
cells, and javascript walks down first.

+ The corner (0,0) on a 3 by 3 keeps 2 of the 4 deltas, (1,0) then
  (0,1), the bounds check filtering in listing order.
+ The center (1,1) keeps all four, (0,1), (2,1), (1,0), (1,2), and
  all 8 with the diagonals.
+ A bfs seeded at (0,0) over the same grid visits 9, every cell,
  the deltas alone carrying the walk.
+ In 3d the 6 face deltas flood the 2 by 2 by 2 to 8 and the 3 by 3
  by 3 to 27.
+ The 1 by 2 by 3 slab still reads 6, the thin axis adds no wall
  and the box stays one component.

#diagram([delta order as a sequence, the center's four neighbors stamped in listing order, the corner keeping 2 of 4, and the bfs rings covering all 9], length: 13pt, {
  // three 3x3 panels: enumeration order, corner filter, bfs rings
  let cell = 1.15
  let panel = (x0, title) => {
    for r in range(3) {
      for c in range(3) {
        cdraw.rect((x0 + c * cell, 5.6 - r * cell), (x0 + (c + 1) * cell, 5.6 - (r - 1) * cell),
          fill: luma(235), stroke: luma(180), radius: 0.02)
      }
    }
    cdraw.content((x0 + 1.5 * cell, 2.7), title, size: 6pt)
  }
  // panel 1: center dark, neighbors stamped 1..4 in delta order
  panel(1.4, [4 deltas, listing order])
  cdraw.rect((1.4 + 1 * cell + 0.02, 5.6 - 1 * cell + 0.02), (1.4 + 2 * cell - 0.02, 5.6 - 0.02), fill: luma(120), radius: 0.02)
  cdraw.content((1.4 + 1.5 * cell, 5.6 - 0.5 * cell), [c], size: 6pt)
  for (c, n) in (((0, 1), 1), ((2, 1), 2), ((1, 0), 3), ((1, 2), 4)) {
    cdraw.rect((1.4 + c.at(1) * cell + 0.02, 5.6 - c.at(0) * cell + 0.02), (1.4 + (c.at(1) + 1) * cell - 0.02, 5.6 - (c.at(0) - 1) * cell - 0.02), fill: luma(205), radius: 0.02)
    cdraw.content((1.4 + (c.at(1) + 0.5) * cell, 5.6 - (c.at(0) - 0.5) * cell), [#n], size: 6pt)
  }
  // panel 2: corner dark, its two in-bounds neighbors stamped 2 and 4
  panel(8.4, [corner keeps 2 of 4])
  cdraw.rect((8.4 + 0.02, 5.6 - 2 * cell + 0.02), (8.4 + cell - 0.02, 5.6 - cell - 0.02), fill: luma(120), radius: 0.02)
  cdraw.content((8.4 + 0.5 * cell, 5.6 - 1.5 * cell), [c], size: 6pt)
  for (c, n) in (((1, 0), 2), ((0, 1), 4)) {
    cdraw.rect((8.4 + c.at(1) * cell + 0.02, 5.6 - c.at(0) * cell + 0.02), (8.4 + (c.at(1) + 1) * cell - 0.02, 5.6 - (c.at(0) - 1) * cell - 0.02), fill: luma(205), radius: 0.02)
    cdraw.content((8.4 + (c.at(1) + 0.5) * cell, 5.6 - (c.at(0) - 0.5) * cell), [#n], size: 6pt)
  }
  // panel 3: bfs distances from the corner, all 9 visited
  panel(15.4, [bfs rings, all 9])
  let dist = (((0, 0), 0), ((0, 1), 1), ((0, 2), 2), ((1, 0), 1), ((1, 1), 2), ((1, 2), 3), ((2, 0), 2), ((2, 1), 3), ((2, 2), 4))
  for (p, d) in dist {
    cdraw.rect((15.4 + p.at(1) * cell + 0.02, 5.6 - p.at(0) * cell + 0.02), (15.4 + (p.at(1) + 1) * cell - 0.02, 5.6 - (p.at(0) - 1) * cell - 0.02),
      fill: if d == 0 { luma(120) } else if d <= 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((15.4 + (p.at(1) + 0.5) * cell, 5.6 - (p.at(0) - 0.5) * cell), [#d], size: 6pt)
  }
  cdraw.content((11.0, 1.8), [only visit order rides the listing], size: 6pt)
  cdraw.content((11.0, 1.0), [3d: 8, 27, then 6 on a slab], size: 6pt)
  cdraw.content((11.0, 0.2), [c prices 80 and 144 on 5 by 5], size: 6pt)
})

The 27 of the open cube is the pinned flood, and the listings below
walk these tables in seven languages.

#listing("dsa/samples-c/src/Ch24/neighbors.c", first: 17, last: 51, caption: [c, both delta tables, in-bounds counting, and the recursive 3d flood])
#listing("dsa/samples-go/ch24/neighbors.go", first: 3, last: 23, caption: [go, east-first deltas, the bounds guard, walk3d below])
#listing("dsa/samples-java/src/Ch24/Neighbors.java", first: 21, last: 54, caption: [java, the two delta tables pinned cell by cell, the recursive 3d flood, walks keyed by packed longs])
#listing("dsa/samples/src/Ch24/Lattice.cs", first: 168, last: 191, caption: [c\#, the three delta arrays, neighbors filtered in delta order])
#listing("dsa/samples-js/src/ch24-neighbors.mjs", first: 4, last: 40, caption: [javascript, three tables, map and filter, a 3d walk over string keys])
#listing("dsa/samples-py/src/Ch24/neighbors.py", first: 13, last: 34, caption: [python, tuple deltas, a stack walk over a seen set])
#listing("dsa/samples-lua/ch24_neighbors.lua", first: 6, last: 29, caption: [lua, the tables and the bounds-checked emitter])

The c and java suites pin the arithmetic the others skip: over
a 5 by 5 grid the 4-neighborhood sums to 80 directed edges and the
8-neighborhood to 144, a corner keeps 2 of 4 and 3 of 8, java also
pricing an edge cell at 3 and 5. The 3d
walks agree on the volumes: all seven languages flood a box and
count
the visited cells, c pins 27 for the open 3 by 3 by 3, 26 with the
center blocked, and 9 when a full plane splits the cube into
halves, java pinning those same three counts and carrying python's
2 by 2 by 2 lanes, the center hole at 7 and the wall slab at 4, lua
pins 8, 27, and 6 for a 1 by 2 by 3 slab, python works
a 2 by 2 by 2 with a center hole, 7 of 8 visited, and a wall slab
cutting the count to 4. Delta order differs per language, c lists
up, down, left, right, go starts east, javascript walks down first,
java matching c's up, down, left, right in parallel delta arrays,
and the floodfill fixtures above prove the order never changes the
region.

#diagram([one 5 by 5 grid, the center cell's 4 and 8 neighborhoods, and a corner's 2 and 3], length: 13pt, {
  // left grid: 4-neighborhood of the center dark; right grid: 8-neighborhood of the corner
  let panel = (x0, center, n4) => {
    for r in range(5) {
      for c in range(5) {
        let dr = r - center.at(0)
        let dc = c - center.at(1)
        let d4 = (calc.abs(dr) + calc.abs(dc)) == 1
        let d8 = d4 or (calc.abs(dr) == 1 and calc.abs(dc) == 1)
        let hot = if n4 { d4 } else { d8 }
        cdraw.rect((x0 + c * 1.3, 5.6 - r * 1.3), (x0 + (c + 1) * 1.3, 6.9 - r * 1.3),
          fill: if (r, c) == center { luma(120) } else if hot { luma(205) } else { luma(235) }, radius: 0.02)
      }
    }
  }
  panel(1.5, (2, 2), true)
  cdraw.content((4.75, 7.8), [center cell: 4 neighbors], size: 6.5pt)
  panel(11.0, (0, 0), false)
  cdraw.content((14.25, 7.8), [corner cell: 3 of 8], size: 6.5pt)
  cdraw.content((6.0, 1.6), [4-neighborhood: 80 directed edges on 5x5], size: 6pt)
  cdraw.content((6.0, 0.6), [8-neighborhood: 144], size: 6pt)
  cdraw.content((17.5, 3.0), [dark: the cell], size: 6pt)
  cdraw.content((17.5, 2.1), [shaded: its neighbors], size: 6pt)
  cdraw.content((17.5, 1.2), [only visit order depends], size: 6pt)
  cdraw.content((17.5, 0.7), [on the delta listing order], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's four sample files, test scripts included where the
language embeds them:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [319], [fixed char arrays, int deltas], [float ray intersection with boundary conventions stated, long long shoelace],
  [c\#], [156], [tuples, `Queue`, `Stack`], [the one fully cross-multiplied ray cast, on-boundary separate],
  [go], [191], [slices, `ch23.Point` reuse], [integer division crossing x, boundary declared inside up front],
  [java], [442], [jdk 27 stdlib], [the float cast and the null boundary lane in one ray file, 3d walks keyed by coordinates packed into a long, component sizes sorted descending],
  [javascript], [130], [`Array` ops, `Set` keys], [halves the shoelace sum early, boundary unpromised],
  [python], [239], [`list` grids, `set` seen], [on-boundary returns a third answer, none],
  [lua], [306], [`table`, string splice fills], [exact integer on-boundary, seen keyed by r times 100 plus c],
)

sources: learn.microsoft.com for `Queue<T>` and `Stack<T>`, go.dev
for package layout and `min` and `max` builtins, developer.mozilla
.org for `Array.prototype.shift`, docs.python.org for `enumerate`
and floor division, lua.org for `table.unpack` and `math.abs`, and
the pick's theorem statement as standard lattice geometry, accessed
2026-09-14. Sample behavior verified by the seven suite gates scoped
to chapter 24: c 4 files and 63 checks, c\# 12 tests, go 12 tests,
java 4 files and 94 checks, javascript 12 tests, python 4 files and
36 asserts, lua 16 checks,
zero skipped.
