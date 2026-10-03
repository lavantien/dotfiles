#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

// provenance: every value below is pinned by the signed fixture
// contracts (kdd-contract-s1s2.md for ch04/05, kdd-contract-s4s5.md
// for ch18, kdd-contract-s7.md for ch31, each witnessed by its
// playground/kdd-matrix generator) and replayed on both sides of the
// bridge: the c samples print them under their gates
// (tools/run-c-samples.ps1, 127 checks over the four chapters,
// 2026-09-22) and the go tests in books/kdd/capstone/internal/kddcore
// assert them (18 tests, the contract replay suite). the fixture
// tables quote the sheets verbatim. no external page was fetched for
// this chapter.

= the bridge: c to go

== the port and its gates

The dry run: the four c samples print 127 ok lines between them,
ch04 with 44, ch05 with 28, ch18 with 25 over two files, and ch31
with 30. The go package `kddcore` runs its 18 tests in under a
quarter second, and every contract fixture they replay was printed by
the c side first.

Chapters 1 to 46 taught one algorithm family per chapter in c23,
small enough to verify by hand. The capstone needs four of them
running for real inside a go pipeline, so `internal/kddcore` ports
the spine: chapter #xref-to("kdd", "normalize") (min-max, z-score,
mad), chapter #xref-to("kdd", "distance") (minkowski and diagonal
mahalanobis), chapter #xref-to("kdd", "roc") (the threshold sweep and
concordant auc), and chapter #xref-to("kdd", "kmeans") (lloyd with
the pinned tie rules). The bridge is not a rewrite at arm's length:
the fixture contracts name this package's tie rules as binding for
both lanes, and the chapter 31 sheet reuses this package's own tie
test as its TIE fixture. The same numbers, the same order of
operations, two compilers.

#diagram([the bridge: four c chapters on the left, the kddcore functions in the middle, the pipeline consumers on the right], length: 13pt, {
  let cbox(x, y, label) = {
    cdraw.rect((x, y), (x + 4.4, y + 0.85), fill: luma(235), stroke: luma(120), radius: 0.12)
    cdraw.content((x + 2.2, y + 0.42), label, size: 7pt)
  }
  let gbox(x, y, label) = {
    cdraw.rect((x, y), (x + 4.4, y + 0.85), fill: luma(220), stroke: luma(120), radius: 0.12)
    cdraw.content((x + 2.2, y + 0.42), label, size: 7pt)
  }
  cbox(0.6, 8.6, [ch 04, znorm.c, 44 checks])
  cbox(0.6, 6.9, [ch 05, distance.c, 28 checks])
  cbox(0.6, 5.2, [ch 18, roc.c + degenerate.c, 25])
  cbox(0.6, 3.5, [ch 31, kmeans.c + elbow.c, 30])
  gbox(6.6, 7.75, [MinMax, MinMaxSigned, ZScore, MADScore])
  gbox(6.6, 6.05, [Minkowski, Chebyshev, MahalanobisDiag])
  gbox(6.6, 4.35, [ROC, ConcordantCounts, AUC, TrapezoidAUC])
  gbox(6.6, 2.65, [Lloyd])
  gbox(6.6, 0.9, [the bridge tests, 18 replay and unit tests])
  cdraw.line((5.0, 9.0), (6.6, 8.2), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.0, 7.3), (6.6, 6.5), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.0, 5.6), (6.6, 4.8), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.0, 3.9), (6.6, 3.1), stroke: luma(120), mark: (end: ">"))
  cdraw.line((8.8, 7.75), (8.8, 3.5), stroke: luma(140))
  cdraw.line((8.8, 2.65), (8.8, 1.75), stroke: luma(120), mark: (end: ">"))
  cdraw.content((8.8, 0.1), [consumers in #xref-to("kdd", "capstone")], size: 6pt)
})

== chapter 04, normalization

The dry run: the c sample prints `range 16 minmax01: 0 0.25 0.375 0.5
0.75 1` and, two blocks later, `A median 6 MAD 1 robust z: -2 0 0 0 4
10`. The go test asserts the same literals with plain equality, every
value dyadic, and adds the signed mirror `-1 -0.5 -0.25 0 0.5 1` from
the `2v-1` variant.

The conventions had to be settled before either side was written:
population variance with the n divisor, and the mad standardization of
Leys, Allen, Fisher, and Lumley 2013, (x-median)/MAD with no 0.6745
scaling, the row the sheet banks. On symmetric series B, where sigma
equals MAD, classic z and robust z coincide elementwise, which both
sides assert as the closing check of the chapter.

#listing("kdd/samples/src/Ch04/znorm.c", first: 166, last: 189, caption: [the c side: median, mad, robust z, and the outlier contrast at 16])

#listing("kdd/capstone/internal/kddcore/normalize.go", first: 84, last: 99, caption: [the go side: same definition, one loop, zeros when MAD is zero])

#diagram([series a of chapter 04, classic z against robust z, the point 16 sits two sigmas out but ten MADs out], length: 13pt, {
  let px(v) = 1.4 + v * 1.9
  let z(v) = 1.0 + (v + 2.0) * 1.15
  let rz(v) = 1.0 + (v + 2.0) * 0.55
  cdraw.line((1.4, 1.0), (10.4, 1.0), stroke: luma(120))
  for x in (4.0, 6.0, 10.0, 16.0) {
    cdraw.circle((px(x), z((x - 8.0) / 4.0)), radius: 0.12, fill: luma(140), stroke: none)
    cdraw.circle((px(x), rz((x - 6.0) / 1.0)), radius: 0.12, fill: luma(210), stroke: none)
    cdraw.content((px(x), 0.5), [#x], size: 6pt)
  }
  cdraw.content((9.0, 4.3), [classic z, (x - 8) slash 4], size: 6pt)
  cdraw.content((9.0, 3.4), [robust z, (x - 6) slash MAD 1], size: 6pt)
  cdraw.line((px(16.0), z(2.0)), (px(16.0), rz(10.0)), stroke: (dash: "dashed", thickness: 0.6pt, paint: luma(100)))
  cdraw.content((px(16.0) + 0.1, 5.6), [2 vs 10 at the planted outlier], size: 6pt)
})

== chapter 05, distance

The dry run: `d1 = 12`, then `d2^2 = 50, d2 = 7.0710678118654755`
print-only, then the cube witness 216 = 6^3 and the fourth-power sum
962. The go side asserts sqrt(50) bit-exactly against its own
computation and the two irrational roots at the sheet's 1e-12 bound.

The chapter owns the minkowski DISTANCE, the L_p metric; the
minkowski SUM of convex geometry is a different object, and the
disambiguation belongs to #xref-to("dsa", "geometry2"). The ladder
monotonicity 12 > 7.071 > 6 > 5.569 is pinned on both sides, and so
is the diagonal mahalanobis row, where population variances 2 and 8
put every fixture point on an exact integer distance.

#listing("kdd/samples/src/Ch05/distance.c", first: 46, last: 68, caption: [the c side: p=1 as integers, p=2 with the squared-sum witness before the print-only root])

#listing("kdd/capstone/internal/kddcore/distance.go", first: 12, last: 41, caption: [the go side: one loop, the p cases, index-order accumulation])

#diagram([the lp ladder on the diff triple (3,4,5), bar length is the distance, all strictly decreasing], length: 13pt, {
  let rows = (("p = 1", 12.0, "12"), ("p = 2", 7.0710678118654755, "7.0710678"),
    ("p = 3", 6.0, "6"), ("p = 4", 5.569212227823757, "5.5692122"))
  let y = 5.4
  for row in rows {
    let w = row.at(1) * 0.75
    cdraw.rect((4.0, y - 0.28), (4.0 + w, y + 0.28), fill: luma(205), radius: 0.0)
    cdraw.content((1.6, y), [#row.at(0)], size: 6pt)
    cdraw.content((4.0 + w + 0.5, y), [#row.at(2)], size: 6pt)
    y -= 1.2
  }
  cdraw.line((4.0, 6.1), (4.0, 0.9), stroke: luma(100))
})

== chapter 18, roc

The dry run: the c sample prints seven `point k (a/3,b/3)` rows,
`(0,0)` through `(1,1)`, then `concordant=8 discordant=1 ties=0`, then
the trapezoid cross-check against 8/9 at 1e-12. The go test walks the
same seven corners as exact thirds and reads the same tally.

Two conventions the sheet fixed and both sides carry: the sweep
predicts positive when score >= threshold and the curve starts at the
origin, and a single-class input closes with a final (1,1) corner,
eight points total, area 1 all-positive and 0 all-negative, with the
concordant auc undefined. The degenerate rendering has its own c file
in Ch18 and its own go assertion.

#listing("kdd/samples/src/Ch18/roc.c", first: 84, last: 101, caption: [the c side: concordant pairs over every cross-class pair, ties half])

#listing("kdd/capstone/internal/kddcore/roc.go", first: 16, last: 41, caption: [the go side: the same double loop, the same half-credit ties])

#diagram([the seven pinned corners in thirds, the staircase from (0,0) to (1,1), concordant area 8/9], length: 13pt, {
  let px(v) = 1.6 + v * 7.2
  let py(v) = 0.9 + v * 5.4
  let pts = ((0.0, 0.0), (0.0, 1.0 / 3.0), (0.0, 2.0 / 3.0), (1.0 / 3.0, 2.0 / 3.0), (1.0 / 3.0, 1.0), (2.0 / 3.0, 1.0), (1.0, 1.0))
  cdraw.rect((px(0.0), py(0.0)), (px(1.0 / 3.0), py(2.0 / 3.0)), fill: luma(230), stroke: none)
  for i in range(1, pts.len()) {
    let a = pts.at(i - 1)
    let b = pts.at(i)
    if a.at(0) != b.at(0) {
      cdraw.line((px(a.at(0)), py(a.at(1))), (px(a.at(0)), py(b.at(1))), stroke: luma(60))
    }
    cdraw.line((px(a.at(0)), py(b.at(1))), (px(b.at(0)), py(b.at(1))), stroke: luma(60))
  }
  for p in pts {
    cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.09, fill: luma(30), stroke: none)
  }
  cdraw.line((1.6, 0.9), (9.4, 0.9), stroke: luma(100))
  cdraw.line((1.6, 0.9), (1.6, 6.7), stroke: luma(100))
  cdraw.content((5.5, 0.4), [false positive rate in thirds], size: 6pt)
  cdraw.content((0.4, 3.8), [true positive rate], size: 6pt)
  cdraw.content((6.9, 2.4), [area 8/9], size: 6pt)
})

== chapter 31, k-means

The dry run: the c sample prints `iter0 cents=(0,0),(24,0),(12,16)
assign=012000111222 sse=288`, then `iter1 cents=(2,2),(26,2),(14,20)
assign=012000111222 sse=144`, then `final iters=2`. The go replay
asserts the same assignment string, the same integer centroids, the
same two passes, and the same 144.

The tie rules are the bridge's own, adopted by the sheet: seeds are
the first k distinct points in input order, assignment goes to the
nearest centroid by squared distance with ties to the lowest cluster
index, update is the arithmetic mean with an emptied cluster keeping
its centroid, and the confirming pass counts in iters. The F12b row
is the honest caveat both sides pin: reseed the same twelve points so
the first three distinct are two-of-A plus one-of-B, and lloyd lands
in a split-A local minimum with sse 540 against the planted 216,
which is why chapter #xref-to("kdd", "validation") cares about
initialization and the icpc book's k-means chain in
#xref-to("icpc", "y2017") probes exactly this failure mode.

#listing("kdd/samples/src/Ch31/kmeans.c", first: 152, last: 176, caption: [the c side: the pass loop, lowest-index ties, the confirming pass returns])

#listing("kdd/capstone/internal/kddcore/kmeans.go", first: 27, last: 41, caption: [the go side: the same loop shape, same tie rule in nearest])

#diagram([fixture F12: three 4-point rectangles, the three seeds ringed, final centroids crossed, sse 144], length: 13pt, {
  let px(v) = 1.0 + v * 0.42
  let py(v) = 0.8 + v * 0.34
  let groups = (
    (((0.0, 0.0), (4.0, 0.0), (0.0, 4.0), (4.0, 4.0)), luma(200)),
    (((24.0, 0.0), (28.0, 0.0), (24.0, 4.0), (28.0, 4.0)), luma(140)),
    (((12.0, 16.0), (16.0, 16.0), (12.0, 24.0), (16.0, 24.0)), luma(80)),
  )
  for g in groups {
    for p in g.at(0) {
      cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.11, fill: g.at(1), stroke: none)
    }
  }
  for p in ((0.0, 0.0), (24.0, 0.0), (12.0, 16.0)) {
    cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.24, stroke: luma(30), fill: none)
  }
  for p in ((2.0, 2.0), (26.0, 2.0), (14.0, 20.0)) {
    cdraw.line((px(p.at(0)) - 0.2, py(p.at(1)) - 0.2), (px(p.at(0)) + 0.2, py(p.at(1)) + 0.2), stroke: 0.8pt + luma(30))
    cdraw.line((px(p.at(0)) - 0.2, py(p.at(1)) + 0.2), (px(p.at(0)) + 0.2, py(p.at(1)) - 0.2), stroke: 0.8pt + luma(30))
  }
  cdraw.line((1.0, 0.8), (17.2, 0.8), stroke: luma(100))
  cdraw.line((1.0, 0.8), (1.0, 9.4), stroke: luma(100))
  cdraw.content((9.0, 0.3), [F12 plane, seeds ringed, centroids crossed after one update], size: 6pt)
})

== the agreement table

The ledger, one row per fixture, both sides' receipts:

#table(
  columns: (auto, 1.5fr, 2.2fr, 2.2fr, auto),
  inset: 4pt,
  table.header([*ch*], [*fixture*], [*c pins*], [*go asserts*], [*lane*]),
  [04], [series M], [`minmax01 0, .25, .375, .5, .75, 1` and the 2v-1 mirror], [the six plus six dyadic literals with ==], [D1],
  [04], [series A], [pop var 16, z ends at 2, robust z ends at 10], [z and robust z elementwise], [D1],
  [04], [series B], [z equals robust z, all seven values], [same, elementwise ==], [D1],
  [05], [diff (3,4,5)], [d1 12, squared 50, cube 216, fourth 962, monotone], [sqrt(50) exact, roots at 1e-12, witnesses], [D0+D2],
  [05], [pythagorean], [sqrt(25.0) is 5, sqrt(169.0) is 13], [the same two == checks], [D1],
  [05], [diag covariance], [var 2 and 8, D 0,1,2,2,3], [the five exact distances], [D1],
  [18], [6-score sweep], [seven corners in thirds], [the same corners as exact thirds], [D0],
  [18], [concordance], [8, 1, 0, auc 8/9, trapezoid], [both auc routes], [D0+D2],
  [18], [degenerate], [8 points, areas 1 and 0, undefined], [NaN concordance, closed curves], [D0],
  [31], [F12], [iters 2, assign 012000111222, sse 144], [same, integer centroids ==], [D0+D1],
  [31], [F12b], [local minimum sse 540 vs planted 216], [same split, same 540], [D0+D1],
  [31], [TIE], [joins cluster 0, cents (1/2,0),(2,0), sse 1/2], [the same three values], [D1],
)

The lane column is the agreement class: D0 and D1 rows are bit-exact
on both sides, which is possible because the fixtures are integers and
dyadic rationals, and D2 rows agree at the sheet's stated 1e-12. The
c side computes its fractions in exact integer arithmetic where the
sheet demands it; the go side uses float64 throughout, and on these
fixtures the two agree to the bit, which is the whole point of
choosing dyadic pins.

#diagram([the lane ladder across the bridge: exact rows cross unchanged, tolerance rows cross at the stated bound], length: 13pt, {
  cdraw.rect((1.0, 4.6), (5.4, 6.6), fill: luma(235), stroke: luma(120), radius: 0.12)
  cdraw.rect((1.0, 1.6), (5.4, 3.6), fill: luma(245), stroke: luma(120), radius: 0.12)
  cdraw.content((3.2, 5.6), [D0 and D1 rows, integers and dyadics], size: 7pt)
  cdraw.content((3.2, 5.0), [cross the bridge bit-exact], size: 7pt)
  cdraw.content((3.2, 2.6), [D2 rows, irrational roots], size: 7pt)
  cdraw.content((3.2, 2.0), [cross at 1e-12, stated per row], size: 7pt)
  cdraw.line((0.5, 5.6), (1.0, 5.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((0.5, 2.6), (1.0, 2.6), stroke: luma(120), mark: (end: ">"))
  cdraw.content((0.5, 6.4), [c23], size: 7pt)
  cdraw.content((0.5, 3.4), [c23], size: 7pt)
  cdraw.line((5.4, 5.6), (5.9, 5.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.4, 2.6), (5.9, 2.6), stroke: luma(120), mark: (end: ">"))
  cdraw.content((6.6, 5.6), [go, float64], size: 7pt)
  cdraw.content((6.6, 2.6), [go, float64], size: 7pt)
  cdraw.content((3.2, 0.7), [12 fixture rows, 10 exact, 2 carrying tolerance legs], size: 6pt)
})

== what the bridge buys

The dry run: the capstone run of chapter #xref-to("kdd", "capstone")
grades its tree with the auc of this package and its clusters with
this lloyd, and the digest moves if either drifts.

Nothing in the pipeline reimplements a bridged algorithm: the anomaly
stage scores with minkowski at p=2 through the lof engine, the
segmentation calls lloyd directly, the tree evaluation reads the auc
and the panel's roc curve comes from the same corner walk. The port
also inherits the book's determinism discipline: float64 in index
order, tie rules written down and tested, and every fixture the c
chapters pinned replayed in go on every untagged test run, so the
two languages cannot quietly diverge.

#diagram([the consumers: every bridged function has a pipeline caller, the digest watches all of them], length: 13pt, {
  let fbox(x, y, w, label) = {
    cdraw.rect((x, y), (x + w, y + 0.85), fill: luma(235), stroke: luma(120), radius: 0.12)
    cdraw.content((x + w / 2, y + 0.42), label, size: 7pt)
  }
  let pbox(x, y, w, label) = {
    cdraw.rect((x, y), (x + w, y + 0.85), fill: luma(220), stroke: luma(120), radius: 0.12)
    cdraw.content((x + w / 2, y + 0.42), label, size: 7pt)
  }
  fbox(0.8, 6.8, 3.6, [Minkowski])
  fbox(0.8, 5.2, 3.6, [Lloyd])
  fbox(0.8, 3.6, 3.6, [AUC and ROC])
  fbox(0.8, 2.0, 3.6, [MinMax family])
  pbox(5.6, 6.8, 4.8, [mine lof, neighbor distances])
  pbox(5.6, 5.2, 4.8, [mine k-means, segmentation])
  pbox(5.6, 3.6, 4.8, [eval auc, panel curve])
  pbox(5.6, 2.0, 4.8, [store views, same formula in sql])
  cdraw.line((4.4, 7.2), (5.6, 7.2), stroke: luma(120), mark: (end: ">"))
  cdraw.line((4.4, 5.6), (5.6, 5.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((4.4, 4.0), (5.6, 4.0), stroke: luma(120), mark: (end: ">"))
  cdraw.line((4.4, 2.4), (5.6, 2.4), stroke: luma(120), mark: (end: ">"))
  cdraw.rect((5.4, 0.6), (10.6, 1.6), stroke: (dash: "dashed", thickness: 0.6pt, paint: luma(100)), fill: none, radius: 0.1)
  cdraw.content((8.0, 1.1), [the golden digest watches every arrow], size: 6pt)
})

sources: no external pages fetched for this chapter, none cited. Every
fixture value is quoted from the signed contract sheets and printed by
the c samples under their gates, both rerun green on 2026-09-22, and
asserted by the go tests of books/kdd/capstone/internal/kddcore, 18
tests green the same day.
