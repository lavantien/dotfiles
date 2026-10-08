#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= range queries

Range queries ask about slices of an array: the sum of a span, the
minimum of a moving window, the nearest larger neighbor of every
element. Five tools cover the practical space, and each ships with
a meter here, reads per query, nodes touched, pushes and pops, so
the logarithmic claims become numbers the tests can check. Prefix
sums answer a static array with one subtraction, the fenwick tree
handles point updates against prefix sums, the segment tree when
the query or the update hits whole ranges, the sparse table when
nothing changes at all, and two monotonic scans when the window
moves one step at a time. The four matrix structures and the two
monotonic scans are built seven languages deep.

== prefix sums

The zeroth tool: never recompute a running total. One pass turns
the array into its prefix sums, P of i plus one holds the sum of
the first i elements, and every range sum becomes two lookups and a
subtraction. The 2d version inverts inclusion-exclusion, each cell
of the summed-area table adds the cell above and to the left and
subtracts the overlap, and a rectangle query takes four corners.

The dry run: the fixtures are 1, 2, 3, 4, 5 for the 1d pass and the
grid 1 through 9 by rows for the table, asserted by the C\#, C,
Java, and Python suites.

+ The 1d pass seeds P[0] = 0 and folds one element in per step:
  0 + 1 = 1, 1 + 2 = 3, 3 + 3 = 6, 6 + 4 = 10, 10 + 5 = 15.
+ Every range is two lookups: the whole span reads 15 - 0 = 15, the
  interior elements 2, 3, 4 read 10 - 1 = 9.
+ The 2d build starts from a zero border, so the top grid row 1, 2,
  3 folds cell plus above plus left minus overlap: 1 + 0 + 0 - 0 =
  1, 2 + 0 + 1 - 0 = 3, 3 + 0 + 3 - 0 = 6.
+ Grid row 4, 5, 6 lands 4 + 0 + 1 - 0 = 5, 5 + 3 + 5 - 1 = 12,
  6 + 6 + 12 - 3 = 21.
+ Grid row 7, 8, 9 finishes at the far corner: 7 + 0 + 5 - 0 = 12,
  8 + 12 + 12 - 5 = 27, 9 + 21 + 27 - 12 = 45.
+ The bottom-right block then costs four corners off the finished
  table: 45 - 6 - 12 + 1 = 28.

#diagram([the build as a sequence, the totals rising one element at a time, the table landing one row at a time], length: 13pt, {
  // left: the 1d running totals, one column per prefix, height grows with the value
  let vals = (0, 1, 3, 6, 10, 15)
  for (i, v) in vals.enumerate() {
    let x = 0.9 + i * 1.3
    cdraw.rect((x, 0.6), (x + 0.85, 0.74 + v * 0.24), fill: if v == 15 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.425, 1.04 + v * 0.24), [#v], size: 6pt)
  }
  for k in range(1, 6) {
    cdraw.content((1.975 + (k - 1) * 1.3, 1.04 + vals.at(k - 1) * 0.24), [+#k], size: 6pt)
  }
  // right: the summed-area table mid-build, rows 1 and 2 landed, row 3 pending
  let rows = (((0, 0, 0, 0), 0), ((0, 1, 3, 6), 0), ((0, 5, 12, 21), 1), ((0, none, none, none), 2))
  for (r, row) in rows.enumerate() {
    for (c, v) in row.at(0).enumerate() {
      let (x, y) = (10.6 + c, 4.3 - (r + 1) * 0.9)
      cdraw.rect((x, y), (x + 1.0, y + 0.9), fill: if row.at(1) == 2 and c > 0 { none } else if row.at(1) == 1 and c > 0 { luma(205) } else { luma(235) }, stroke: if row.at(1) == 2 and c > 0 { (paint: luma(160), dash: "dashed") }, radius: 0.02)
      if v != none { cdraw.content((x + 0.5, y + 0.45), [#v], size: 6pt) }
    }
  }
  // the next fold pulls the cell above and the cell to the left
  cdraw.line((12.1, 1.9), (12.1, 1.65), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.3, 1.15), (11.62, 1.15), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.0, 2.95), [after row 1: 1, 3, 6], size: 6pt)
  cdraw.content((18.0, 2.05), [after row 2: 5, 12, 21], size: 6pt)
  cdraw.content((18.0, 1.15), [row 3 next: 7 + 5 + 0 - 0 = 12], size: 6pt)
  cdraw.content((18.0, 0.3), [far corner ends at 45], size: 6pt)
})

The 45 and the 28 are asserted by all four suites, and the
listings below build these two tables in seven languages.

#listing("dsa/samples-c/src/Ch21/prefix.c", first: 22, last: 47, caption: [c, the 1d pass, then the 2d table and its four-corner query])

#listing("dsa/samples-go/ch21/prefix.go", first: 8, last: 47, caption: [go, both builds, the rectangle read from four corners])

#listing("dsa/samples-java/src/Ch21/Prefix.java", first: 15, last: 45, caption: [java, the 1d pass and range subtraction, the 2d corners])

#listing("dsa/samples/src/Ch21/Prefix.cs", first: 12, last: 37, caption: [c\#, both builds, the rectangle read from four corners])

#listing("dsa/samples-js/src/ch21-prefix.mjs", first: 5, last: 29, caption: [javascript, the running total and the summed-area grid])

#listing("dsa/samples-py/src/Ch21/prefix.py", first: 13, last: 43, caption: [python, prefix 1d, range sum, the 2d corners])

#listing("dsa/samples-lua/ch21_prefix.lua", first: 7, last: 43, caption: [lua, the same two builds, corners by four table reads])

The 1d anchors hold wherever the topic lands: the table 0, 1, 3, 6,
10, 15 over 1 through 5, the whole-range 15, the interior 9, and a
single element reading its own slot. The fixture family from the
fenwick section below, 3, 1, 4, 1, 5, 9, 2, 6, does double duty in
Python and Lua, range 0 to 4 at 14, range 2 to 5 at 19, the whole
array at 31. The 2d grid 1 through 9 by rows pins the rectangle
arithmetic, 45 for the whole grid, 28 for the bottom-right block,
and the four-corner subtraction is the entire trick, add the far
corner, subtract the two near ones, add back the doubly-subtracted
overlap.

#diagram([the summed-area table, every rectangle is four corners, the overlap added back once], length: 13pt, {
  let g = ((1, 2, 3), (4, 5, 6), (7, 8, 9))
  cdraw.content((4.2, 7.9), [the grid and its table], size: 6.5pt)
  for (r, row) in g.enumerate() {
    for (c, v) in row.enumerate() {
      cdraw.rect((1.4 + c * 1.0, 6.6 - r * 0.9), (2.4 + c * 1.0, 7.5 - r * 0.9), fill: luma(235), radius: 0.02)
      cdraw.content((1.9 + c * 1.0, 7.05 - r * 0.9), [#v], size: 6pt)
    }
  }
  let labels = (((0, 0), (0, 0), (0, 0)), ((0, 1), (0, 3), (0, 6)), ((1, 5), (3, 12), (6, 21)), ((5, 12), (12, 27), (21, 45)))
  for (r, row) in labels.enumerate() {
    for (c, v) in row.enumerate() {
      cdraw.rect((6.2 + c * 1.0, 6.6 - r * 0.9), (7.2 + c * 1.0, 7.5 - r * 0.9), fill: if r == 3 and c == 2 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((6.7 + c * 1.0, 7.05 - r * 0.9), [#(v.at(1))], size: 6pt)
    }
  }
  cdraw.content((4.2, 3.5), [table cell = sum of the rectangle above-left], size: 6pt)
  cdraw.content((4.2, 2.5), [range sum = two cells subtracted], size: 6pt)
  cdraw.content((4.2, 1.5), [1d: P[r+1] - P[l]], size: 6pt)
  cdraw.content((4.2, 0.5), [2d: four corners, overlap back once], size: 6pt)
  cdraw.content((13.4, 6.0), [rect(1,1,2,2) = 28], size: 6pt)
  cdraw.content((13.4, 5.0), [45 - 6 - 12 + 1 = 28], size: 6pt)
  cdraw.content((13.4, 4.0), [no recompute, ever], size: 6pt)
  cdraw.content((13.4, 3.0), [static array only], size: 6pt)
  cdraw.content((13.4, 2.0), [one update spoils a suffix], size: 6pt)
  cdraw.content((13.4, 1.0), [then the fenwick tree, below], size: 6pt)
})

== the fenwick tree

A fenwick tree stores partial sums in the array itself. Internal
node j is responsible for the run of cells ending at j, from
j - lowbit(j) + 1 through j in 1-based terms, where lowbit is the
lowest set bit. A prefix query starts at the endpoint and strips
its own lowbit each step, a point update climbs by adding it, and
both directions touch one cell per set bit along the way.

The dry run: the fixture is 3, 1, 4, 1, 5, 9, 2, 6, pinned by the
C\#, JavaScript, Python, and Lua suites, the walk uses the C\# labels
with 0-based public indices over the 1-based table, so Prefix(4)
sums the first five elements, and the build is Go's O(n) pass.

+ Slot 0 stays unused and slots 1 through 8 start as the array
  itself: 3, 1, 4, 1, 5, 9, 2, 6.
+ Each j pushes its sum up to the parent p = j + lowbit(j): slot
  2 lands 1 + 3 = 4, slot 4 takes two pushes to 1 + 4 = 5 then
  5 + 4 = 9, and slot 6 lands 9 + 5 = 14.
+ Slot 8 collects three pushes, 6 + 9 = 15, 15 + 14 = 29, 29 +
  2 = 31, while j = 8 itself climbs to 16, past the tree.
+ The finished table reads 3, 4, 4, 9, 5, 14, 2, 31: slot 4 owns
  the first four cells at 9, slot 6 the fifth and sixth at 14,
  slot 8 all eight at 31.
+ A prefix query strips lowbit: Prefix(4), the first five
  elements, runs at 1-based j = 5, reads slots 5 and 4: 5 + 9 = 14.
+ A range is two prefixes: through j = 6 it reads 14 + 9 = 23,
  through j = 2 it reads 4, so 23 - 4 = 19. The whole array,
  Prefix(7), runs at j = 8 and reads its single slot, 31.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*j*], [*lowbit(j)*], [*p*], [*tree[p] += tree[j]*], [*slot p now*]),
  [1], [1], [2], [1 + 3], [4],
  [2], [2], [4], [1 + 4], [5],
  [3], [1], [4], [5 + 4], [9],
  [4], [4], [8], [6 + 9], [15],
  [5], [1], [6], [9 + 5], [14],
  [6], [2], [8], [15 + 14], [29],
  [7], [1], [8], [29 + 2], [31],
  [8], [8], [16], [past the end], [],
)

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*query*], [*walk*], [*arithmetic*], [*lands*]),
  [Prefix(4)], [j = 5 then 4], [5 + 9], [14],
  [RangeSum(2, 5)], [j = 6 then 4, minus j = 2], [(14 + 9) - 4], [19],
  [Prefix(7)], [j = 8 only], [31], [31],
)

The whole array closes the walk at one read, 31, and the listings
below build and query this same table in seven languages.

#listing("dsa/samples/src/Ch21/Ranges.cs", first: 3, last: 34, caption: [point add climbs by lowbit, prefix strips it, reads counted per query])

The tests pin the build 3, 1, 4, 1, 5, 9, 2, 6: Prefix(4) is 14,
RangeSum(2,5) is 19, Prefix(7) is 31. The meter carries the real
claim: a prefix ending at 1-based i reads exactly one cell per set
bit, so the suite asserts ReadsLastQuery equals PopCount(i) for
all sixteen endpoints of a 16-tree, where 16 reads one cell and 15
reads four. Two hundred seeded random ops interleaving adds and
range sums then match a running array exactly, the cross-check
that climbing and stripping agree.

The six sibling builds keep the same contract in their own shape:

#listing("dsa/samples-c/src/Ch21/fenwick.c", first: 21, last: 33, caption: [c, add climbs by lowbit, prefix strips it, a naive twin cross-checks])

#listing("dsa/samples-go/ch21/fenwick.go", first: 6, last: 44, caption: [go, the struct, O(n) build from the array, range as two prefixes])

#listing("dsa/samples-java/src/Ch21/Fenwick.java", first: 16, last: 47, caption: [java, the static tree and its shadow array, add climbs, prefix strips, every prefix cross-checked])

#listing("dsa/samples-js/src/ch21-fenwick.mjs", first: 5, last: 31, caption: [javascript, the class, prefix and range on the same climb])

#listing("dsa/samples-py/src/Ch21/fenwick.py", first: 14, last: 33, caption: [python, the class with a shadow list agreeing after every mutation])

#listing("dsa/samples-lua/ch21_fenwick.lua", first: 6, last: 33, caption: [lua, 0-based outside shifted to 1-based inside, cross-checked against a prefix array])

The fixture family splits exactly as the history of the book does.
C\#, JavaScript, Python, and Lua share 3, 1, 4, 1, 5, 9, 2, 6 and
pin the same three numbers, prefix 5 at 14, range 2 to 5 at 19, the
whole array at 31, and Python watches a shadow list agree after
every add. Go builds 2, 4, 1, 6, 3 and pins every prefix, and C and
Java load 1 through 8 and pin the triangular prefixes 1, 3, 6, 10,
28. The inside-outside indexing split is worth one read: C, C\#,
Go, and Java keep the 1-based indexing inside the structure, Lua
and Python shift a 0-based public face down to the 1-based table,
and the C and Java suites keep a naive twin answering every prefix,
the cross-check that climbing and stripping never drift.

#diagram([the fenwick tree above the flat array it lives in, node j responsible for the run ending at j, one prefix walk of three reads shaded], length: 13pt, {
  // 8 array cells below, responsibility nodes above, prefix(6) reads 7, 6, 4
  let depth = (3, 2, 2, 1, 2, 1, 1, 0)
  let cx = (j) => 2.95 + (j - 1) * 1.5
  let pos = (j) => (cx(j), 6.9 - depth.at(j - 1) * 1.5)
  for (c, p) in ((1, 2), (2, 4), (3, 4), (4, 8), (5, 6), (6, 8), (7, 8)) {
    cdraw.line(pos(c), pos(p), stroke: luma(220))
  }
  let labels = ([1], [1-2], [3], [1-4], [5], [5-6], [7], [1-8])
  for j in range(1, 9) {
    let (x, y) = pos(j)
    cdraw.rect((x - 0.55, y - 0.25), (x + 0.55, y + 0.25), fill: if j in (4, 6, 7) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), labels.at(j - 1), size: 6pt)
  }
  for j in range(1, 9) {
    cdraw.rect((2.2 + (j - 1) * 1.5, 0.1), (3.7 + (j - 1) * 1.5, 0.95), fill: if j in (4, 6, 7) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.95 + (j - 1) * 1.5, 0.52), [#j], size: 6pt)
  }
  cdraw.content((7.45, -0.3), [3rd], size: 6pt)
  cdraw.content((10.45, -0.3), [2nd], size: 6pt)
  cdraw.content((11.95, -0.3), [1st], size: 6pt)
  cdraw.content((8.2, 7.8), [the responsibility tree over its own array], size: 6.5pt)
  cdraw.content((18.5, 6.1), [cover: j - lowbit(j) + 1 to j], size: 6pt)
  cdraw.content((18.5, 5.0), [0-based prefix(6) reads 7, 6, 4], size: 6pt)
  cdraw.content((18.5, 3.9), [three reads, one per set bit], size: 6pt)
  cdraw.content((18.5, 2.8), [an add climbs: 5, 6, 8], size: 6pt)
  cdraw.content((18.5, 1.7), [update and query logarithmic], size: 6pt)
  cdraw.content((18.5, 0.6), [slot j holds node j's sum], size: 6pt)
})

== the segment tree with lazy propagation

The segment tree halves the array recursively and lets every node
answer for its whole segment, so a range query decomposes into a
handful of canonical nodes, at most two per level. Lazy propagation
gives updates the same deal: a range add parks its delta at the
highest nodes that fit inside the range and stops there, and the
tag moves down only when a later descent needs those children:

#listing("dsa/samples/src/Ch21/Ranges.cs", first: 36, last: 124, caption: [range add and range sum, tags pushed only when the descent needs the children])

On 1, 2, 3, 4, 5 the whole-range sum is 15, and after
AddRange(1,3,10) it is 45 while SumRange(0,0) still returns 1: the
leaf never saw the tag because nothing descended to it. The meter
bounds the traversal, a whole-range add touches exactly one node,
and across a hundred seeded random ops on 8 leaves no operation
touches more than 9 of the 15 nodes, inside the 4 times
ceil(log2 n) = 12 the test allows, with every sum matching brute
force. The figure runs the same story on 1 through 8: an
AddRange(0,3,10) then SumRange(2,6) lands on covers 2-3, 4-5 and
6-6, which sum to 45.

The six sibling builds drop the lazy tags and answer the matrix
contract instead, point update with range sum and range min:

#listing("dsa/samples-c/src/Ch21/segtree.c", first: 22, last: 55, caption: [c, sum and min trees in one build, both queries])

#listing("dsa/samples-go/ch21/segtree.go", first: 40, last: 83, caption: [go, set, sum, min, one fold drives both])

#listing("dsa/samples-java/src/Ch21/Segtree.java", first: 15, last: 67, caption: [java, the recursive sum and min trees, and the iterative bottom-up shape as a nested class])

#listing("dsa/samples-js/src/ch21-segtree.mjs", first: 4, last: 52, caption: [javascript, an iterative bottom-up tree, lo and hi walk to the root])

#listing("dsa/samples-py/src/Ch21/segtree.py", first: 13, last: 66, caption: [python, sum and min in one class, brute mirrors both])

#listing("dsa/samples-lua/ch21_segtree.lua", first: 6, last: 53, caption: [lua, the fold and identity as arguments, two trees from one build])

The C\# tree above and these five are honestly different
structures, and the comparison note is the point: lazy tags exist
to update whole ranges in logarithmic time, and once the update is
a single point the tag machinery is overhead, so the sibling builds
carry sum and min arrays straight down. JavaScript's is the odd
shape worth a second look, an iterative tree over doubled indices
with no recursion at all, and Lua builds one engine and hands it
the sum fold with identity 0 and the min fold with maxinteger.
Fixtures differ per suite, C and Java over 2, 1, 5, 3, 4, Go over
2, 4, 1, 6, 3, Python back on 3, 1, 4, 1, 5, 9, 2, 6 with
whole-range 31 and range 2 to 5 at 19 again, Java running that same
fixture through the iterative bottom-up shape as a nested class,
and every suite cross-checks every query against a linear scan,
Python and Java after each of their updates.

#diagram([a lazy segment tree in two frames, the parked add moving down one level only when the shaded query descends], length: 13pt, {
  // two 8-leaf trees over 1..8, left after addrange 0-3, right after sumrange 2-6
  let tree = (x0, hot) => {
    let lx = (0.6, 1.75, 2.9, 4.05, 5.2, 6.35, 7.5, 8.65).map(v => v + x0)
    let px = (1.175, 3.475, 5.775, 7.975).map(v => v + x0)
    let qx = (2.325, 6.875).map(v => v + x0)
    let rx = x0 + 4.6
    let lid = range(8).map(i => "l" + str(i))
    let pid = ("01", "23", "45", "67")
    let qid = ("03", "47")
    let node = (x, y, w, label, id) => {
      cdraw.rect((x - w / 2, y - 0.25), (x + w / 2, y + 0.25), fill: if id in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x, y), label, size: 6pt)
    }
    for (i, p) in ((0, 0), (1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 3)) {
      cdraw.line((lx.at(i), 0.85), (px.at(p), 2.05), stroke: if lid.at(i) in hot { luma(100) } else { luma(220) })
    }
    for (p, q) in ((0, 0), (1, 0), (2, 1), (3, 1)) {
      cdraw.line((px.at(p), 2.55), (qx.at(q), 3.75), stroke: if pid.at(p) in hot { luma(100) } else { luma(220) })
    }
    for q in range(2) {
      cdraw.line((qx.at(q), 4.25), (rx, 5.45), stroke: if qid.at(q) in hot { luma(100) } else { luma(220) })
    }
    node(rx, 5.7, 1.0, [0-7], "07")
    node(qx.at(0), 4.0, 1.0, [0-3], qid.at(0))
    node(qx.at(1), 4.0, 1.0, [4-7], qid.at(1))
    node(px.at(0), 2.3, 1.0, [0-1], pid.at(0))
    node(px.at(1), 2.3, 1.0, [2-3], pid.at(1))
    node(px.at(2), 2.3, 1.0, [4-5], pid.at(2))
    node(px.at(3), 2.3, 1.0, [6-7], pid.at(3))
    for i in range(8) { node(lx.at(i), 0.6, 0.9, [#(i + 1)], lid.at(i)) }
  }
  tree(0.7, ())
  tree(11.4, ("23", "45", "l6"))
  // pending tags park beside their node, a dashed leader across the empty row band
  let tag = (bx, y, from-x) => {
    cdraw.rect((bx, y - 0.22), (bx + 0.7, y + 0.22), fill: luma(248), stroke: luma(160), radius: 0.02)
    cdraw.content((bx + 0.35, y), [+10], size: 6pt)
    cdraw.line((bx + 0.7, y), (from-x, y), stroke: (paint: luma(160), dash: "dashed"))
  }
  tag(0.8, 4.0, 2.5)
  tag(10.9, 2.3, 12.03)
  tag(13.3, 2.3, 14.33)
  cdraw.content((5.3, 6.55), [after addrange 0-3, plus 10], size: 6.5pt)
  cdraw.content((16.0, 6.55), [sumrange 2-6 pushes it down], size: 6.5pt)
  cdraw.line((9.9, 3.4), (11.35, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.6, 3.9), [descends], size: 6pt)
  cdraw.content((5.3, -0.5), [one touch, tag parked at 0-3], size: 6pt)
  cdraw.content((16.0, -0.5), [2-3, 4-5, index 6 shaded: 45], size: 6pt)
  cdraw.content((16.0, -1.3), [0-1 was tagged but never entered], size: 6pt)
})

#callout("pitfall", "push before you descend", [
  The lazy tag is a promise the parent's sum already keeps and its
  children know nothing about. Any traversal that reads or writes
  below a tagged node must move the tag down first, or it mixes
  stale children into an updated parent and returns a wrong sum
  with no crash to announce it. The NodesTouched meter at least
  keeps the traversal visible while debugging.
])

== the sparse table

Flip the premise: if the array never changes, precompute every
power-of-two cover once. Level k holds the minimum of every
2^k-wide span, and a query takes the two covers of the largest
power of two that fits, one anchored at each end. The two overlap
in the middle, which is legal because min is idempotent, folding
the same element in twice changes nothing:

#listing("dsa/samples/src/Ch21/Ranges.cs", first: 126, last: 155, caption: [two overlapping power-of-two covers per query, overlap legal because min is idempotent])

Over 5, 2, 8, 1, 9, 3, 7, 4 the tests pin Min(1,5) and Min(0,3)
at 1, Min(5,7) at 3, Min(4,4) at 9, and Levels at 4 for n = 8, the
top cover spanning the whole array. Min(1,6) deliberately lands on
two 4-wide covers anchored at 1 and 3, overlapping at 3 and 4, and
every range of seeded arrays up to 64 elements agrees with brute
force.

The six sibling builds stack the same doubling levels:

#listing("dsa/samples-c/src/Ch21/sparsetable.c", first: 23, last: 55, caption: [c, level k over level k - 1, the two-cover query])

#listing("dsa/samples-go/ch21/sparsetable.go", first: 9, last: 37, caption: [go, the doubling build, the query by two covers])

#listing("dsa/samples-java/src/Ch21/Sparsetable.java", first: 16, last: 49, caption: [java, the doubling levels, the query answering with the index])

#listing("dsa/samples-js/src/ch21-sparsetable.mjs", first: 5, last: 32, caption: [javascript, the class, levels logged at build])

#listing("dsa/samples-py/src/Ch21/sparsetable.py", first: 16, last: 46, caption: [python, log2 by hand, levels pinned open])

#listing("dsa/samples-lua/ch21_sparsetable.lua", first: 6, last: 31, caption: [lua, the table and the two-cover read, 1-based])

The C\# and Lua suites share the fixture 5, 2, 8, 1, 9, 3, 7, 4,
and both pin queries at 1, 1, 3, and 9 for the single element at
index 4. Python and Java open their levels to inspection, level 0
the array itself and level 1 the pair minima, C and Java run 5, 2,
4, 1, 3, 7, 6, 8 and pin rmq(0, 3) at 3 for the value 1, Go runs
5, 2, 4, 1, 3 with seven pinned queries, and JavaScript's table
carries the level exponent alongside. Every suite keeps the linear
scan as the oracle over seeded ranges.

#diagram([the sparse table as stacked doubling levels, query 1-6 answered by two overlapping 4-wide covers], length: 13pt, {
  // levels k=0..3 over 5,2,8,1,9,3,7,4 with the two query covers shaded
  let vals = (5, 2, 8, 1, 9, 3, 7, 4)
  let x0 = 2.0
  for i in range(8) {
    cdraw.rect((x0 + i * 1.5, 0.15), (x0 + (i + 1) * 1.5, 0.95), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + i * 1.5 + 0.75, 0.55), [#vals.at(i)], size: 6pt)
  }
  cdraw.content((1.0, 0.55), [k=0], size: 6pt)
  let pw = 12.0 / 7
  for (i, v) in (2, 2, 1, 1, 3, 3, 4).enumerate() {
    cdraw.rect((x0 + i * pw, 1.5), (x0 + (i + 1) * pw, 2.3), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + i * pw + pw / 2, 1.9), [#v], size: 6pt)
  }
  cdraw.content((1.0, 1.9), [k=1], size: 6pt)
  let qw = 12.0 / 5
  for (i, v) in (1, 1, 1, 1, 3).enumerate() {
    let hot = i == 1 or i == 3
    cdraw.rect((x0 + i * qw, 2.8), (x0 + (i + 1) * qw, 3.6), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x0 + i * qw + qw / 2, 3.2), [#v], size: 6pt)
  }
  cdraw.content((1.0, 3.2), [k=2], size: 6pt)
  // the two covers as labeled spans, dashed rules marking their overlap
  cdraw.rect((3.5, 3.75), (9.5, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((5.0, 3.98), [cover 1-4], size: 6pt)
  cdraw.rect((6.5, 4.3), (12.5, 4.75), fill: none, stroke: luma(100), radius: 0.02)
  cdraw.content((11.0, 4.53), [cover 3-6], size: 6pt)
  cdraw.line((6.5, 3.6), (6.5, 4.85), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((9.5, 3.6), (9.5, 4.85), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((8.0, 5.15), [they overlap at 3 and 4], size: 6pt)
  cdraw.rect((2.0, 5.5), (14.0, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((8.0, 5.9), [1], size: 6pt)
  cdraw.content((1.0, 5.9), [k=3], size: 6pt)
  cdraw.content((8.0, 6.95), [one level per power of two], size: 6.5pt)
  cdraw.content((18.8, 5.9), [widths double each level], size: 6pt)
  cdraw.content((18.8, 4.6), [query 1-6, two 4-wide covers], size: 6pt)
  cdraw.content((18.8, 3.2), [overlap at 3 and 4 is fine], size: 6pt)
  cdraw.content((18.8, 1.9), [k is log2 of the length], size: 6pt)
  cdraw.content((18.8, 0.55), [the table is read only], size: 6pt)
})

#callout("pitfall", "overlap is only legal for idempotent ops", [
  min, max and gcd tolerate the doubled overlap because applying
  them twice to the same element changes nothing. sum does not,
  the overlap would be counted twice. The other price is
  permanence, one changed cell invalidates every cover above it,
  and at that point this chapter's fenwick tree or a segment tree
  belongs in the slot instead.
])

== sliding window maxima

When the window slides one position per step, the running max
needs no tree at all. Keep a deque of indices whose values
strictly decrease front to back: the front is the current maximum,
a new arrival evicts every smaller or equal index off the back,
and the front retires by index distance when it slides out.

The dry run: the fixture is 1, 3, -1, -3, 5, 3, 6, 7 with k = 3,
the same literals in all seven suites, and the meters count one push
per arrival with both eviction kinds summed into the pops.

+ The classic run outputs 3, 3, 5, 5, 6, 7 over 8 pushes and 7
  pops, back evictions and front aging counted together.
+ The deque after each output reads 1, 2, then 1, 2, 3, then 4,
  then 4, 5, then 6, then 7, the maximum always at the front.
+ The ties lane runs 4, 4, 4, 4 with k = 2 and outputs 4, 4, 4
  over 4 pushes and 3 pops, the deque after each output holding
  only the newest index, the older equal value gone.
+ The degenerate windows: k = 1 on 5, 1, 5 echoes 5, 1, 5, and
  k = n on 2, 9, 4, 1 keeps the single maximum 9.
+ The bound lane: pushes equal n on every fixture, and pushes plus
  pops stay within 2n, an index enters once and leaves at most
  once.
+ Per-tree honesty: the C\# meter pins the 8 pushes and the 2n
  ceiling without the 7 pops, the Python and Java suites add a k = 1
  meter reading of 2 pops for the front aging out twice, and the
  deque trace is pinned by the C, Java, JavaScript, Python, and Lua
  suites.

#listing("dsa/samples/src/Ch21/Ranges.cs", first: 157, last: 197, caption: [the meter and the deque, back eviction and front expiry both counted])

The classic run, 1, 3, -1, -3, 5, 3, 6, 7 with k = 3, produces
3, 3, 5, 5, 6, 7. The meter is the proof of linearity: 8 arrivals
make exactly 8 pushes, and since an index leaves the deque at most
once, pushes plus pops never reach past 16 for the whole scan. The
nested while loop only looks quadratic, every eviction was paid
for by the push that preceded it.

The six sibling builds keep the same deque contract over six
substrates:

#listing("dsa/samples-c/src/Ch21/maxima.c", first: 19, last: 47, caption: [c, the deque in a fixed array under head and tail cursors, both eviction kinds metered, the trace through an out parameter])

#listing("dsa/samples-go/ch21/maxima.go", first: 13, last: 41, caption: [go, one slice grown at the back and shortened at both ends, the meter passed beside])

#listing("dsa/samples-java/src/Ch21/Maxima.java", first: 21, last: 62, caption: [java, the fixed-array deque under two cursors, the trace through a parameter, both pop kinds metered, an ArrayDeque lane beside])

#listing("dsa/samples-js/src/ch21-maxima.mjs", first: 6, last: 25, caption: [javascript, pop off the back, shift off the front, both counted as pops])

#listing("dsa/samples-py/src/Ch21/maxima.py", first: 14, last: 32, caption: [python, the deque as a list, front aging pops index 0, the trace recorded per output])

#listing("dsa/samples-lua/ch21_maxima.lua", first: 7, last: 33, caption: [lua, a back eviction nils the last slot, aging removes position 1, the trace snapped per output])

The deque substrate is where the six builds differ. C and Java
never move an element, they walk two cursors through one fixed
array and hand the teaching trace out through a parameter, Go
grows a slice and shortens it from either end, JavaScript pops the
back and shifts the front of a plain array, Python pops index 0
when the front ages, and Lua nils the back slot and removes
position 1, Java carrying the ArrayDeque substrate as a second lane
beside its cursor build. The
meter arithmetic lands the same everywhere, 8 pushes with 7 pops
on the classic run, 4 with 3 on the ties lane, and the 2n ceiling
on the combined count. The trace lane splits by reach, C, Java,
Python, and Lua record it inside the walk, JavaScript keeps a twin
walker in the same file for it, and Go checks every output against
a brute window maximum instead.

#diagram([sliding window maxima column by column, the deque of survivors under each arrival, the shaded front output as the max], length: 13pt, {
  // 1,3,-1,-3,5,3,6,7 with k = 3, one column per arrival
  let a = (1, 3, -1, -3, 5, 3, 6, 7)
  let deques = ((1,), (3,), (3, -1), (3, -1, -3), (5,), (5, 3), (6,), (7,))
  let outs = (0, 0, 3, 3, 5, 5, 6, 7)
  for i in range(8) {
    let c = 2.2 + i * 2.5
    cdraw.content((c, 7.0), [#i], size: 6pt)
    cdraw.rect((c - 0.45, 6.1), (c + 0.45, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((c, 6.45), [#a.at(i)], size: 6.5pt)
    if i >= 2 { cdraw.content((c, 5.75), [#(i - 2)-#i], size: 6pt) }
    for (j, v) in deques.at(i).enumerate() {
      let y = 5.2 - j * 0.75
      cdraw.rect((c - 0.45, y - 0.275), (c + 0.45, y + 0.275), fill: if j == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((c, y), [#v], size: 6pt)
    }
    if i >= 2 {
      cdraw.line((c, 3.35), (c, 2.32), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
      cdraw.rect((c - 0.45, 1.6), (c + 0.45, 2.3), fill: luma(205), radius: 0.02)
      cdraw.content((c, 1.95), [#outs.at(i)], size: 6pt)
    } else {
      cdraw.content((c, 1.95), [...], size: 6pt)
    }
  }
  cdraw.content((11.0, 7.8), [k = 3, one column per arrival], size: 6.5pt)
  cdraw.content((11.0, 0.8), [the shaded front is the window max], size: 6pt)
  cdraw.content((11.0, 0.0), [equal or smaller evicted off the back], size: 6pt)
  cdraw.content((11.0, -0.8), [8 pushes, at most 8 pops, 6 outputs], size: 6pt)
})

== next greater, both sides

The same monotonic idea with a stack answers the nearest larger
neighbor. Scanning left to right, the stack holds indices with
strictly decreasing values, and when a bigger value arrives it
pops everything smaller: each pop is an answer, the popper is the
poppee's next greater to the right. The right to left pass fills
the left array identically, and whatever survives a scan keeps
its -1.

The dry run: the answers are indices with -1 when no greater
element exists, and only a strictly greater value pops. The six
sibling suites assert the family below with identical literals,
and the C\# suite pins the first row together with its seeded
brute agreement.

+ On 2, 1, 3, 2, 5 the right array reads 2, 2, 4, 4, -1 and the
  left array reads -1, 0, -1, 2, -1.
+ Equals never pop, 7, 7, 7 answers -1 on both sides.
+ The falling run 5, 4, 3, 2, 1 keeps right all -1 and answers
  left -1, 0, 1, 2, 3, and the rising run 1, 2, 3 answers right
  1, 2, -1 with left all -1.
+ The circular lane wraps one pass over 2n - 1 steps with no push
  after the first lap, so no element answers itself: 3, 1, 4, 0, 2
  answers 2, 2, -1, 4, 0, 1, 2, 1 answers 1, -1, 1, and 5, 0, 5
  answers -1, 2, -1, where an answer may wrap to a lower index
  than its query.
+ The oracle lane: a brute scan outward in each direction, and
  once around the circle, agrees on every fixture in every suite.

#listing("dsa/samples/src/Ch21/Ranges.cs", first: 199, last: 232, caption: [one pass per direction, pops are answers, survivors stay -1])

On 2, 1, 3, 2, 5 the right scan pops 1 and 0 when 3 arrives and 3
and 2 when 5 arrives, giving Right 2, 2, 4, 4, -1, and the left
pass gives -1, 0, -1, 2, -1. Brute force agrees with both sides on
seeded arrays. This scan is a workhorse beyond its own question:
histogram rectangles, stock spans and trapping rainwater all
reduce to it.

The six sibling builds carry the two directional scans plus a
circular walk the C\# ground truth stops short of:

#listing("dsa/samples-c/src/Ch21/nextgreater.c", first: 19, last: 51, caption: [c, one stack pass per direction, the circular walk over 2n - 1 steps])

#listing("dsa/samples-go/ch21/nextgreater.go", first: 22, last: 65, caption: [go, the directional scan and the circular wrap, strict greater pops])

#listing("dsa/samples-java/src/Ch21/Nextgreater.java", first: 16, last: 58, caption: [java, one dir-flagged stack pass for both directions, the circular walk over 2n - 1 steps])

#listing("dsa/samples-js/src/ch21-nextgreater.mjs", first: 5, last: 41, caption: [javascript, the scan, the both sides wrapper, the circular wrap])

#listing("dsa/samples-py/src/Ch21/nextgreater.py", first: 14, last: 42, caption: [python, both directions from one scan, the circular walk beside it])

#listing("dsa/samples-lua/ch21_nextgreater.lua", first: 6, last: 50, caption: [lua, the scans over 1-based stacks answering in 0-based indices])

Every tree runs the same discipline twice, one pass left to right
for the right array and one right to left for the left array, and
the circular variant repeats the walk over 2n - 1 steps, pushing
only during the first lap so a second visit never answers itself.
C, Go, Java, JavaScript, and Python pick the visit index from a
direction flag, Lua from a backward flag, and the Go window leaves
out only the wrapper that fills the two answer arrays, it sits a
few lines above the scan in the same file. Lua alone shifts its
1-based stack positions back to 0-based answers, and its meter
row pins the push count at one per index per pass, 10 over both
directions of the 5 element fixture. The circular lane belongs to
the six sibling trees alone, and every brute oracle agrees with
every answer they give.

#diagram([next greater both ways, the stack under each arrival, every pop recording one answer], length: 13pt, {
  // 2,1,3,2,5: the left table scans right, the right table scans left
  let table = (x0, title, rows) => {
    cdraw.content((x0 + 3.6, 7.4), title, size: 6.5pt)
    for (r, row) in rows.enumerate() {
      let y = 6.5 - r * 0.95
      let (label, stack, pops) = row
      cdraw.content((x0 + 0.3, y), label, size: 6pt)
      for (j, v) in stack.enumerate() {
        cdraw.rect((x0 + 1.5 + j * 0.7, y - 0.26), (x0 + 2.2 + j * 0.7, y + 0.26), fill: luma(235), radius: 0.02)
        cdraw.content((x0 + 1.85 + j * 0.7, y), [#v], size: 6pt)
      }
      if pops != none {
        cdraw.rect((x0 + 4.9, y - 0.26), (x0 + 7.4, y + 0.26), fill: luma(205), radius: 0.02)
        cdraw.content((x0 + 6.15, y), pops, size: 6pt)
      }
    }
  }
  table(0.4, [scan left to right], (
    ([0: 2], (2,), none),
    ([1: 1], (2, 1), none),
    ([2: 3], (3,), [1, 0 -> 2]),
    ([3: 2], (3, 2), none),
    ([4: 5], (5,), [3, 2 -> 4]),
  ))
  table(10.6, [scan right to left], (
    ([4: 5], (5,), none),
    ([3: 2], (5, 2), none),
    ([2: 3], (5, 3), [3 -> 2]),
    ([1: 1], (5, 3, 1), none),
    ([0: 2], (5, 3, 2), [1 -> 0]),
  ))
  // the array with arrows to the next greater on the right
  let centers = (3.15, 4.25, 5.35, 6.45, 7.55)
  for (i, v) in (2, 1, 3, 2, 5).enumerate() {
    cdraw.rect((centers.at(i) - 0.55, 0.35), (centers.at(i) + 0.55, 1.05), fill: luma(235), radius: 0.02)
    cdraw.content((centers.at(i), 0.7), [#v], size: 6pt)
  }
  cdraw.line((3.25, 1.75), (5.25, 1.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.35, 1.4), (5.25, 1.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.45, 1.75), (7.45, 1.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.55, 1.4), (7.45, 1.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.55, 1.75), [-1], size: 6pt)
  cdraw.content((5.35, -0.35), [right: 2, 2, 4, 4, -1], size: 6pt)
  cdraw.content((5.35, -1.1), [left: -1, 0, -1, 2, -1], size: 6pt)
  cdraw.content((16.0, -0.35), [pops are answers, survivors stay -1], size: 6pt)
  cdraw.content((16.0, -1.1), [one pass per side, linear in total], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines over this chapter's
six featured files per language. The C\# row is its whole
`Ranges.cs`, including the lazy segment tree with range updates the
other six replace with point-update builds and the monotonic
deque with both scans, plus the prefix sums file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [471], [libc only], [static tables sized 4n and log n, a naive twin answers every query, sum and min trees in one build, the deque under two cursors],
  [go], [247], [none], [zero imports, the O(n) fenwick build, one fold drives sum and min queries, the deque resliced off both ends],
  [java], [717], [jdk 27 stdlib], [both segment tree shapes in one file, the recursive 4n arrays beside the iterative nested class, the fenwick shadow array re-checked after every op, rmq answering with indices],
  [c\#], [221], [bcl only], [the lazy range-add tree is the deep cut, meters count reads and nodes, BitOperations behind the level counts, prefix sums aboard],
  [javascript], [176], [node stdlib], [the iterative segment tree over doubled indices, no recursion in any of the six builds],
  [python], [368], [stdlib only], [shadow lists agree after every mutation, levels opened to inspection, log2 by hand, the k = 1 pops meter],
  [lua], [462], [lib.lua harness], [the segment tree takes fold and identity as arguments, maxinteger the min identity, 1-based tables with a 0-based face],
)

The two monotonic sections measured the same way, with the C\#
column counting each region of the one shared `Ranges.cs` and the
shared Meter booked on the maxima row:

#table(
  columns: (1.7fr, auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*section*], [*c*], [*c\#*], [*go*], [*java*], [*javascript*], [*python*], [*lua*]),
  [sliding window maxima], [92], [37], [32], [141], [33], [60], [72],
  [next greater, both sides], [113], [31], [54], [119], [33], [72], [105],
)

The next greater spread carries the circular walk, the 6 sibling
files ship it and the C\# region stops at the two directional
scans, which is most of the distance down to 31.

sources: learn.microsoft.com, `LinkedList<int>` as the deque
substrate, `Stack<int>` for the scans, `BitOperations.Log2` and
`PopCount` behind the level and read counts, `Array.Fill`,
accessed 2026-09-12. Sample behavior verified by
`make verify-csharp`, 17 tests in chapter 21 of the samples suite.
The seven-language layer verifies the same way: 6 C programs with
108 embedded checks under `make verify-c`, 6 Ch21 java programs
with 135 checks under `run-java-samples`, 18 Go tests, 18
`node --test` cases, 93 Python checks across 6 files, and 29 Lua
checks under `run.lua`.
