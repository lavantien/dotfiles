// ch20, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 32 checks in kdd/samples/src/Ch20/knn.c (19) and census.c (13) or a
// pinned note of kdd-contract-s4s5.md: the 9-point fixture and the tie
// rules of its shared machinery, neighbors sorted by (squared euclidean
// distance, training index), equal distance to the lower index, vote tie
// to the class of the single nearest neighbor, weighted votes w = 1/d2 as
// exact fractions. all pinned values are witnessed by the sheet +
// playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0. D0 integers
// and fraction pairs throughout, no doubles asserted anywhere.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= nearest neighbor

Two samples carry the chapter: `knn.c` sorts the neighbors of two queries
and votes them five ways, plain and distance-weighted, 19 checks, and
`census.c` classifies all 25 cells of a 5x5 grid at k = 3 and walks the
boundary, 13 checks. The chapter makes 5 moves: the sorted neighbor list
as the entire model, the majority vote and its tie rule, the weighted
vote that uses all 9 neighbors, the decision region the votes paint over
the grid, and the training point that gets outvoted inside its own cell.
Every behavioral claim below is one of the 32 checks of chapter 20's
samples or a pinned note of the contract sheet. The metric doing the
sorting is the squared euclidean of #xref-to("kdd", "distance"), the
eager learners this one refuses to be are #xref-to("kdd", "bayes") and
#xref-to("kdd", "ann"), and the k to vote with is chosen by the
resampling of #xref-to("kdd", "evaluation").

== the sorted list is the model

There is no training phase. The model is the 9 pinned training points,
0:(1,1,A) through 8:(5,4,B), five A then four B in index order, and a
query is answered by sorting all 9 by squared distance, distance ties
broken to the lower training index, and reading the list from the front.
Q1 is (3,3), sitting between the A pocket on the left and the B cluster
up right.

The dry run: the sorted line prints `q1 sorted (d2,idx,label): (1,4,A)
(1,5,B) (2,3,A) (2,6,B) (5,1,A) (5,2,A) (5,7,B) (5,8,B) (8,0,A)`. The
front is a distance tie, idx4 at (2,3) one unit away and idx5 at (3,2)
one unit away, and idx4 sorts first by index, the check "ch20 q1 sorted
(d2,idx) order, ties to lower index" pinning the whole 18-tuple. Second
place ties again at d2 = 2, idx3 before idx6 the same way, and d2 = 5
holds a four-way tie settled into index order 1, 2, 7, 8. Distances are
squared on purpose, integers throughout, no root ever taken.

#listing("kdd/samples/src/Ch20/knn.c", first: 29, last: 32,
  caption: [nine training points, pinned index order, two classes])

#listing("kdd/samples/src/Ch20/knn.c", first: 68, last: 85,
  caption: [insertion sort by squared distance, index as tiebreak])

#diagram([the nine points, q1 among them, three nearest ranked], length: 13pt, {
  let px(v) = { 1.8 + (v - 0.5) * 2.6 }
  let py(v) = { 0.8 + (v - 0.5) * 1.15 }
  for g in range(1, 6) {
    cdraw.line((px(g * 1.0), py(0.5)), (px(g * 1.0), py(5.5)),
      stroke: (paint: luma(225), dash: "dashed"))
    cdraw.line((px(0.5), py(g * 1.0)), (px(5.5), py(g * 1.0)),
      stroke: (paint: luma(225), dash: "dashed"))
    cdraw.content((px(g * 1.0), 0.42), [#g], size: 6pt)
    cdraw.content((1.35, py(g * 1.0)), [#g], size: 6pt)
  }
  let pts = (((1, 1), 0, (-0.45, -0.4), true), ((1, 2), 1, (-0.45, 0.05), true),
    ((2, 1), 2, (0.0, -0.45), true), ((2, 2), 3, (-0.5, 0.0), true),
    ((2, 3), 4, (-0.45, -0.4), true), ((3, 2), 5, (0.45, 0.0), false),
    ((4, 4), 6, (-0.5, 0.0), false), ((4, 5), 7, (-0.5, 0.05), false),
    ((5, 4), 8, (0.45, 0.0), false))
  for t in pts {
    let c = (px(t.at(0).at(0) * 1.0), py(t.at(0).at(1) * 1.0))
    if t.at(3) {
      cdraw.circle(c, radius: 0.11, fill: luma(120))
    } else {
      cdraw.rect((c.at(0) - 0.11, c.at(1) - 0.11), (c.at(0) + 0.11, c.at(1) + 0.11),
        fill: luma(120))
    }
    cdraw.content((c.at(0) + t.at(2).at(0), c.at(1) + t.at(2).at(1)), [#{t.at(1)}], size: 6pt)
  }
  let q1 = (px(3.0), py(3.0))
  for r in (((2, 3), [1], (7.0, 4.0)), ((3, 2), [2], (8.8, 3.1)), ((2, 2), [3], (7.1, 2.68))) {
    let c = (px(r.at(0).at(0) * 1.0), py(r.at(0).at(1) * 1.0))
    cdraw.line(q1, c, stroke: (paint: luma(150), dash: "dashed"))
    cdraw.content(r.at(2), r.at(1), size: 6.5pt)
  }
  cdraw.circle(q1, radius: 0.17, stroke: luma(40))
  cdraw.content((8.35, 4.1), [q1 = (3,3)], size: 6pt)
  cdraw.circle((2.1, 6.1), radius: 0.11, fill: luma(120))
  cdraw.content((2.8, 6.1), [class A], size: 6pt)
  cdraw.rect((4.45, 5.99), (4.67, 6.21), fill: luma(120))
  cdraw.content((5.4, 6.1), [class B], size: 6pt)
  cdraw.circle((2.1, 5.4), radius: 0.14, stroke: luma(40))
  cdraw.content((2.8, 5.4), [query], size: 6pt)
  cdraw.content((6.9, 5.4), [ranks 1, 2, 3 by (d2, idx)], size: 6pt)
})

== five ks, two ties

Take the first k entries of the sorted list and count labels. The vote
is majority, and when k splits evenly the sheet's rule fires: the class
of the single nearest neighbor wins, which hands the decision back to
the top of the list. Q1 is built to need it twice.

The dry run: `q1 k=1 -> A`, then `q1 k=2 votes A=1 B=1 -> A (tie to
nearest)`, the tie falling to idx4 because it sorted first, then `q1 k=3
votes A=2 B=1 -> A`, `q1 k=4 votes A=2 B=2 -> A (tie to nearest)`, the
same resolution a second time, and `q1 k=5 votes A=3 B=2 -> A`. Q2 =
(4,3) lives inside the B cluster: its sorted front is (1,6,B) (2,5,B)
(2,8,B), asserted as "ch20 q2 nearest set idx 6,5,8", and every k
agrees, `q2 k=1 -> B`, `q2 k=3 votes A=0 B=3 -> B`, `q2 k=5 votes A=1
B=4 -> B`, the k=5 minority vote being idx4's, the nearest A at d2 = 4.

#listing("kdd/samples/src/Ch20/knn.c", first: 87, last: 99,
  caption: [the vote, majority with the tie falling to the nearest])

#listing("kdd/samples/src/Ch20/knn.c", first: 116, last: 133,
  caption: [k = 1..5 on q1, two planted ties, one rule])

#diagram([both queries across k, the two tie rows highlighted], length: 13pt, {
  cdraw.content((8.7, 8.35), [votes as k grows, dashes mean the sample does not pin that cell], size: 6pt)
  let cols = ((1.4, 1.5, [k]), (3.6, 3.5, [q1 votes]), (7.6, 2.0, [q1 says]),
    (10.0, 3.5, [q2 votes]), (14.0, 2.0, [q2 says]))
  for c in cols {
    cdraw.content((c.at(0) + c.at(1) / 2, 7.6), c.at(2), size: 6.5pt)
  }
  let rows = ((1, [1 - 0], [A], [0 - 1], [B], false),
    (2, [1 - 1 tie], [A, nearest], [-], [-], true),
    (3, [2 - 1], [A], [0 - 3], [B], false),
    (4, [2 - 2 tie], [A, nearest], [-], [-], true),
    (5, [3 - 2], [A], [1 - 4], [B], false))
  for i in range(5) {
    let r = rows.at(i)
    let y = 6.6 - i * 0.95
    let spans = ((1.4, 1.5), (3.6, 3.5), (7.6, 2.0), (10.0, 3.5), (14.0, 2.0))
    let cells = ([#{r.at(0)}], r.at(1), r.at(2), r.at(3), r.at(4))
    for j in range(5) {
      let s = spans.at(j)
      let hot = r.at(5) and (j == 1 or j == 2)
      cdraw.rect((s.at(0), y), (s.at(0) + s.at(1), y + 0.85),
        fill: if hot {luma(224)} else {luma(246)}, radius: 0.02)
      cdraw.content((s.at(0) + s.at(1) / 2, y + 0.42), cells.at(j), size: 6pt)
    }
  }
  cdraw.content((8.7, 1.2), [both ties resolve to idx4, the nearest neighbor of q1], size: 6pt)
})

#callout("pitfall", "an even k begs the question it was asked", [
  With two classes, every even k can split its ballot, and q1 does it
  twice, at k = 2 and k = 4. The pinned rule resolves the deadlock
  locally, the single nearest neighbor decides, which is exactly k = 1
  sneaking back in. The usual engineering outs are odd k, which only
  postpones the problem to three-way races, or the weighted vote of the
  next facet, which cannot tie short of exact fraction equality.
])

== every neighbor weighs 1/d2

The weighted vote drops the cutoff instead of moving it: every one of
the 9 neighbors contributes weight $w = 1\/d_2$ to its class, exact
fractions summed by the same integer arithmetic, and the heavier class
wins. Distance does the talking, near neighbors loudly, far ones at a
whisper.

The dry run: for q1 the weights sum to `weighted q1: A=81/40 B=19/10`,
hand-checkable as $1\/8 + 1\/5 + 1\/5 + 1\/2 + 1 = 81\/40$ for A against
$1 + 1\/2 + 1\/5 + 1\/5 = 19\/10$ for B, so A wins 2.025 to 1.9, the
same verdict as every plain vote. For q2 the line reads `weighted q2:
A=391/520 B=9/4`, A gathering $1\/13 + 1\/10 + 1\/8 + 1\/5 + 1\/4$ over
the common denominator 520, and B cruising 2.25 to about 0.752 on the
strength of idx6 sitting one unit away.

#listing("kdd/samples/src/Ch20/knn.c", first: 157, last: 175,
  caption: [w = 1/d2 over all nine, fractions summed exactly])

#diagram([class weight totals per query, fractions beside decimals], length: 13pt, {
  let sc(v) = { v * 2.2 }
  let panel(x0, title, wa, wad, wb, wbd, win) = {
    cdraw.content((x0 + 3.2, 7.5), title, size: 6.5pt)
    cdraw.rect((x0, 5.2), (x0 + sc(wa), 6.0), fill: luma(236), radius: 0.02)
    cdraw.content((x0 + sc(wa) + 0.25, 5.6), [A #wad], size: 6pt)
    cdraw.rect((x0, 3.6), (x0 + sc(wb), 4.4), fill: luma(220), radius: 0.02)
    cdraw.content((x0 + sc(wb) + 0.25, 4.0), [B #wbd], size: 6pt)
    cdraw.content((x0 + 3.2, 2.6), win, size: 6.5pt)
  }
  panel(1.2, [q1 = (3,3)], 2.025, "= 81/40", 1.9, "= 19/10", [A wins 2.025 to 1.9])
  panel(9.8, [q2 = (4,3)], 0.752, "= 391/520", 2.25, "= 9/4", [B wins 2.25 to 0.752])
  cdraw.content((9.4, 1.4), [longer bar, heavier class, all nine neighbors counted], size: 6pt)
})

== the census, and the region it paints

Classify every cell of the 5x5 grid, x and y from 0 to 4, at k = 3, and
the votes paint a decision region: what the classifier would say
anywhere in the square, not just at the two queries. Two training
points, idx7 at (4,5) and idx8 at (5,4), sit outside the grid and still
vote, the grid is queries, not points.

The dry run: the printed rows, `grid rows y=4..0:` then `A A A B B`, `A
A A A B`, `A A A A B`, `A A A A A`, `A A A A A`, and the census line
`census k=3: A cells=21 B cells=4`, the B pocket being exactly the
cells (4,2), (4,3), (3,4), (4,4) pinned as "ch20 B cells
(4,2),(4,3),(3,4),(4,4)". The boundary walk counts `boundary cells=7`,
one check per cell, (2,4), (3,2), (3,3), (3,4), (4,1), (4,2), (4,3),
every cell with a 4-connected neighbor of the other label.

#listing("kdd/samples/src/Ch20/census.c", first: 90, last: 114,
  caption: [25 classifications, the census, and the B pocket])

#listing("kdd/samples/src/Ch20/census.c", first: 127, last: 139,
  caption: [the 4-connected boundary walk, seven cells, seven checks])

#diagram([the decision region at k = 3, training points marked, boundary cells outlined], length: 13pt, {
  let px(x) = { 2.0 + x * 2.2 }
  let py(y) = { 1.15 + y * 1.12 }
  let grid = (("A", "A", "A", "B", "B"), ("A", "A", "A", "A", "B"),
    ("A", "A", "A", "A", "B"), ("A", "A", "A", "A", "A"), ("A", "A", "A", "A", "A"))
  let bset = ((2, 4), (3, 2), (3, 3), (3, 4), (4, 1), (4, 2), (4, 3))
  let tpts = ((1, 1, [0]), (1, 2, [1]), (2, 1, [2]), (2, 2, [3]), (2, 3, [4]),
    (3, 2, [5]), (4, 4, [6]))
  for x in range(5) {
    for y in range(5) {
      let b = (x, y) in bset
      cdraw.rect((px(x * 1.0), py(y * 1.0)), (px(x * 1.0) + 2.2, py(y * 1.0) + 1.12),
        fill: if grid.at(y).at(x) == "B" {luma(218)} else {luma(246)}, radius: 0.01,
        stroke: if b {0.9pt + luma(70)} else {none})
      cdraw.content((px(x * 1.0) + 0.4, py(y * 1.0) + 0.78), grid.at(y).at(x), size: 6.5pt)
    }
  }
  for t in tpts {
    let x = t.at(0) * 1.0
    let y = t.at(1) * 1.0
    cdraw.circle((px(x) + 1.5, py(y) + 0.3), radius: 0.07, fill: luma(90))
    cdraw.content((px(x) + 1.78, py(y) + 0.3), t.at(2), size: 6pt)
  }
  for i in range(5) {
    cdraw.content((px(i * 1.0) + 1.1, 0.72), [#i], size: 6pt)
    cdraw.content((1.5, py(i * 1.0) + 0.56), [#i], size: 6pt)
  }
  cdraw.rect((13.6, 5.7), (14.0, 6.05), fill: luma(246), radius: 0.02)
  cdraw.content((15.1, 5.87), [21 A cells], size: 6pt)
  cdraw.rect((13.6, 5.0), (14.0, 5.35), fill: luma(218), radius: 0.02)
  cdraw.content((15.1, 5.17), [4 B cells], size: 6pt)
  cdraw.rect((13.6, 4.3), (14.0, 4.65), fill: luma(246), radius: 0.02,
    stroke: 0.9pt + luma(70))
  cdraw.content((15.3, 4.47), [7 boundary], size: 6pt)
  cdraw.content((15.5, 3.6), [dots: in-grid], size: 6pt)
  cdraw.content((15.5, 3.1), [training idx], size: 6pt)
  cdraw.content((8.4, 0.24), [idx7 at (4,5) and idx8 at (5,4) sit outside the grid and still vote], size: 6pt)
})

== the cell that votes against itself

Cell (3,2) is special twice over: it is the site of training point idx5,
label B, and the census paints it A. The query lands exactly on a
training point, so the sorted list starts with that point at d2 = 0, and
self-inclusion hands B exactly one vote, no more.

The dry run: the highlight line prints `cell (3,2) votes A=2 B=1 -> A,
nearest idx5 at d2=0`, and its three checks pin the three facts
separately: idx5 is at (3,2) with label B, "ch20 cell (3,2) IS training
point idx5 label B", the grid says A, "ch20 cell (3,2) classifies A at
k=3", and the vote is 2-1 with the self at distance zero, "ch20 cell
(3,2) vote 2-1 A with self at d2=0". The two A votes come from idx3 at
(2,2), d2 = 1, and idx2 at (2,1), d2 = 2, which edges out idx4's equal
d2 = 2 at (2,3) on the index tiebreak, the same rule that ordered the
front of q1's list.

#listing("kdd/samples/src/Ch20/census.c", first: 116, last: 125,
  caption: [the highlight row, identity, verdict, and vote pinned apart])

#diagram([the self at d2 = 0 contributes one vote and loses], length: 13pt, {
  let box(y, main, sub, hot) = {
    cdraw.rect((1.0, y), (6.8, y + 1.4),
      fill: if hot {luma(224)} else {luma(246)}, radius: 0.02)
    cdraw.content((3.9, y + 0.9), main, size: 6pt)
    cdraw.content((3.9, y + 0.4), sub, size: 6pt)
  }
  box(6.0, [idx5 = (3,2), label B], [the query itself, d2 = 0], true)
  box(4.2, [idx3 = (2,2), label A], [d2 = 1, one step left], false)
  box(2.4, [idx2 = (2,1), label A], [d2 = 2, one step down-left], false)
  for y in (6.7, 4.9, 3.1) {
    cdraw.line((6.8, y), (8.2, y), stroke: luma(60), mark: (end: ">"))
  }
  cdraw.rect((8.4, 3.6), (13.2, 6.2), fill: luma(236), radius: 0.02)
  cdraw.content((10.8, 5.5), [k = 3 vote], size: 6.5pt)
  cdraw.content((10.8, 4.85), [A = 2, B = 1], size: 6.5pt)
  cdraw.content((10.8, 4.2), [verdict A], size: 6.5pt)
  cdraw.content((14.9, 4.9), [the region], size: 6pt)
  cdraw.content((14.9, 4.35), [paints it A], size: 6pt)
  cdraw.content((9.0, 2.0), [one training point, one vote: presence is not a veto], size: 6pt)
  cdraw.content((9.0, 1.2), [a purity-grown tree would have answered B by construction], size: 6pt)
})

#callout("note", "lazy learners do not memorize, they defer", [
  The tree of #xref-to("kdd", "id3") scored 14 of 14 on its own training
  rows because purity growth bakes the training labels into the leaves.
  Here a training point is just a voter, and the fixture plants one that
  loses the election in its own cell, 2 to 1, with itself at distance
  zero. That honesty is why nearest-neighbor error estimates want the
  query excluded from its own neighbor list on training data, and why
  the holdout and cross-validation splits of #xref-to("kdd",
  "evaluation") are the honest way to price any classifier, this one
  included.
])

sources: all 32 pinned values, the 9-point fixture, and both tie rules
witnessed by kdd-contract-s4s5.md and playground/kdd-matrix/gen_s4.py,
run 2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile
-File tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch20`, 19 + 13 checks in chapter 20 of the kdd suite.
