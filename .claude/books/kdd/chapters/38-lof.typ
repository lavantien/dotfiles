// ch38, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 63 checks in kdd/samples/src/Ch38/lof.c (48) and contrast.c (15) or
// a definition quoted from a banked source: Breunig, Kriegel, Ng, Sander,
// "LOF: Identifying Density-Based Local Outliers", SIGMOD 2000, banked by
// kdd-contract-s8s9.md. all pinned values are witnessed by the same sheet
// + playground/kdd-matrix/gen_s8.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= proximity and density anomalies

Two samples carry the chapter: `lof.c` walks the full LOF chain on a
one-dimensional fixture where every distance is an integer and every
density an exact fraction, 48 checks, and `contrast.c` runs two
clustering-based anomaly rules over the same points, 15 checks. The
chapter makes 4 moves: the k-distance neighborhood, reachability and the
local reach density it induces, the LOF ratio and its strict 3\/2 flag,
and the clustering contrast where a size rule flags four points LOF
leaves quiet. Every behavioral claim below is one of the 63 checks of
chapter 38's samples or a definition from Breunig et al. The statistical
detectors of #xref-to("kdd", "anomaly") graded each point against one
global distribution; here the yardstick is local, each point measured
against its own neighbors, and #xref-to("kdd", "hypothesis") next asks
how often any such rule cries wolf.

== the k-distance neighborhood

The fixture is nine points on a line, L9 = {10, 12, 14, 16, 30, 31, 32,
33, 60} with k = 3: one loose cluster, one tight cluster, one point
stranded far right. Breunig et al define the k-distance of a point as the
distance to its k-th nearest neighbor, and $N_k(p)$ as the points within
it, and both are pure order statistics on this fixture: sort the other
eight by distance, take the third.

The dry run: the sample prints one row per point. `pt 10 kdist=6
N={12,14,16}`, because the distances from 10 read 2, 4, 6, 20, 21, 22, 23,
50 in sorted order and the third is 6. The tight cluster prints
`pt 31 kdist=2 N={30,32,33}` and `pt 32 kdist=2 N={30,31,33}`, the
straggler prints `pt 60 kdist=29 N={31,32,33}`, all nine rows checked as
"ch38 kdist(10) = 6" through "ch38 N_k(60) = {31,32,33}". The ranking
line prints `kdist_rank 60:29,10:6,16:6,12:4,14:4,30:3,33:3,31:2,32:2`,
descending k-distance with ties broken by point ascending, and the gap
witness closes the facet: 29 > 2 x 6, asserted as "ch38 gap witness 29 >
2*6 isolates 60". A global sort sees the gap; the rest of the chapter
asks whether the gap is all there is to see.

#listing("kdd/samples/src/Ch38/lof.c", first: 74, last: 87,
  caption: [the nine points, k = 3, and the pinned k-distances and neighbor sets])

#listing("kdd/samples/src/Ch38/lof.c", first: 114, last: 131,
  caption: [k-dist as the 3rd smallest distance, N_k collected within it])

#diagram([nine points, three neighborhoods: loose, tight, and stranded], length: 13pt, {
  let px(v) = { 0.9 + (v - 10.0) * 0.36 }
  cdraw.line((0.7, 3.3), (19.7, 3.3), stroke: luma(60), mark: (end: ">"))
  let pts = (10, 12, 14, 16, 30, 31, 32, 33, 60)
  let rows = (3.8, 2.65)
  for i in range(9) {
    let x = px(pts.at(i) * 1.0)
    cdraw.circle((x, 3.3), radius: 0.1, fill: luma(210), stroke: luma(60))
    cdraw.content((x, rows.at(calc.rem(i, 2))), [#pts.at(i)], size: 6pt)
  }
  let brack(y, x0, x1, label) = {
    cdraw.line((x0, y), (x1, y), stroke: luma(110))
    cdraw.line((x0, y - 0.14), (x0, y + 0.14), stroke: luma(110))
    cdraw.line((x1, y - 0.14), (x1, y + 0.14), stroke: luma(110))
    cdraw.content(((x0 + x1) / 2, y + 0.44), label, size: 6pt)
  }
  brack(5.6, px(10.0), px(16.0), [kdist(10) = 6, N = {12,14,16}])
  brack(4.55, px(30.0), px(33.0), [kdist(30) = 3])
  brack(5.6, px(31.0), px(60.0), [kdist(60) = 29, N = {31,32,33}])
  cdraw.content((9.6, 1.4), [one loose cluster, one tight, one point 27 past the edge], size: 6pt)
})

== reachability, and the local density

The k-distance has a flaw as a yardstick: it grows when a point sits in a
sparse region through no fault of its own. Breunig et al smooth it with
the reach distance, $"reach"_k (p, o) = max("kdist"(o), d(p, o))$: never
closer than the neighbor's own k-distance, so points inside a tight
cluster cannot report artificially tiny distances. The local reach
density inverts the mean: $"lrd"(p) = 1 \/ (sum_(o in N_k(p))
"reach"_k(p, o) \/|N_k(p)|)$, a density in units of points per distance.

The dry run: the sample prints the reach rows, and the smoothing shows
immediately. For point 10, `reach 10: 12=4 14=4 16=6`: the raw distances
to 12 and 14 are 2 and 4, but kdist(12) = 4 lifts the first to 4. For
the straggler, `reach 60: 31=29 32=28 33=27`, the raw distances 29, 28,
27 dominate every kdist of the tight cluster, so nothing is lifted. The
densities then print as nine exact fractions: `lrd 10=3/14` from mean
reach $(4 + 4 + 6)\/3 = 14\/3$, `lrd 31=3/8` from $(3 + 2 + 3)\/3 = 8\/3$,
and `lrd 60=1/28` from $(29 + 28 + 27)\/3 = 84\/3 = 28$. The landscape is
the story: the tight cluster doubles the loose one, roughly 3\/8 against
3\/16, and the straggler's 1\/28 is an order of magnitude below both.

#listing("kdd/samples/src/Ch38/lof.c", first: 148, last: 163,
  caption: [reach as max of the neighbor's k-dist and the raw distance, row printed])

#listing("kdd/samples/src/Ch38/lof.c", first: 170, last: 173,
  caption: [lrd is one division of the reach sum, asserted as a reduced fraction])

#diagram([the density landscape: lrd per point, tight cluster high, straggler near zero], length: 13pt, {
  let px(v) = { 1.2 + (v - 10.0) * 0.36 }
  let py(v) = { 0.7 + v * 12.8 }
  let pts = (10, 12, 14, 16, 30, 31, 32, 33, 60)
  let lrds = (3.0 / 14.0, 3.0 / 16.0, 3.0 / 16.0, 3.0 / 14.0, 3.0 / 7.0,
    3.0 / 8.0, 3.0 / 8.0, 3.0 / 7.0, 1.0 / 28.0)
  for i in range(9) {
    let x = px(pts.at(i) * 1.0)
    cdraw.rect((x - 0.11, 0.7), (x + 0.11, py(lrds.at(i))),
      fill: if i == 8 {luma(170)} else {luma(224)}, radius: 0.01)
    cdraw.content((x, if calc.even(i) {0.3} else {-0.18}), [#pts.at(i)], size: 6pt)
  }
  cdraw.content((px(10.0), py(lrds.at(0)) + 0.42), [3\/14], size: 6pt)
  cdraw.content((px(16.0), py(lrds.at(3)) + 0.42), [3\/14], size: 6pt)
  cdraw.content((px(30.0), py(lrds.at(4)) + 0.42), [3\/7], size: 6pt)
  cdraw.content((px(31.0), py(lrds.at(5)) + 0.42), [3\/8], size: 6pt)
  cdraw.content((px(33.0), py(lrds.at(7)) + 0.42), [3\/7], size: 6pt)
  cdraw.content((px(60.0), py(lrds.at(8)) + 0.42), [1\/28], size: 6pt)
  cdraw.content((9.6, 7.4), [local reach density, same vertical scale on every bar], size: 6pt)
})

#callout("note", "the 12 and 14 rows are not typos", [
  Every reach distance of 10 to 12 is 4 even though the two points sit 2
  apart, because reach pays the neighbor's k-distance floor, asserted in
  the pinned row "ch38 reach(10): 12=4 14=4 16=6". The floor is what
  makes lrd stable inside clusters: without it, arbitrarily close pairs
  would drive each other's densities to infinity, and LOF would be a
  division by noise.
])

== the ratio that flags

Density alone still cannot flag: a point at the edge of a sparse but
healthy cluster is legitimately sparse. The local outlier factor compares
a point's density to its neighbors' densities, $"LOF"(p) = (sum_(o in
N_k(p)) "lrd"(o) \/|N_k(p)|) \/ "lrd"(p)$. Values near 1 mean the point
is as dense as its company; the flag rule is strict, $"LOF" > 3\/2$.

The dry run: the nine LOFs print as exact fractions, `lof 10=11/12`,
`lof 12=23/21`, `lof 31=23/21`, through `lof 33=11/12`. Every inlier
lands at one of two values, 11\/12 at the loose cluster's rim points and
23\/21 just over 1 at its interior, and the tight cluster repeats the
same pair. The straggler prints `lof 60=11/1` and the flag line
`lof_flags_3_2={60}`, asserted as "ch38 only 60 exceeds LOF 3/2". The
hand walk for 60 is one line of fraction arithmetic: mean lrd of
{31, 32, 33} is $(3\/8 + 3\/8 + 3\/7)\/3 = 11\/28$, divided by lrd(60) =
1\/28 gives exactly 11.

#listing("kdd/samples/src/Ch38/lof.c", first: 176, last: 199,
  caption: [LOF as mean neighbor lrd over own lrd, strict 3/2 flag by cross multiply])

#diagram([nine LOF values against the 3/2 flag line, one bar above it], length: 13pt, {
  let px(v) = { 1.2 + (v - 10.0) * 0.36 }
  let py(v) = { 0.7 + v * 0.44 }
  let pts = (10, 12, 14, 16, 30, 31, 32, 33, 60)
  let lofs = (11.0 / 12.0, 23.0 / 21.0, 23.0 / 21.0, 11.0 / 12.0, 11.0 / 12.0,
    23.0 / 21.0, 23.0 / 21.0, 11.0 / 12.0, 11.0)
  for i in range(9) {
    let x = px(pts.at(i) * 1.0)
    cdraw.rect((x - 0.11, 0.7), (x + 0.11, py(lofs.at(i))),
      fill: if i == 8 {luma(150)} else {luma(224)}, radius: 0.01)
    cdraw.content((x, if calc.even(i) {0.3} else {-0.18}), [#pts.at(i)], size: 6pt)
  }
  cdraw.line((0.9, py(1.5)), (19.6, py(1.5)), stroke: luma(90))
  cdraw.line((0.9, py(1.0)), (19.6, py(1.0)), stroke: (paint: luma(200), dash: "dashed"))
  cdraw.content((12.8, py(1.5) + 0.36), [flag line, LOF = 3\/2], size: 6pt)
  cdraw.content((16.5, py(1.0) - 0.42), [LOF = 1], size: 6pt)
  cdraw.content((px(10.0), py(11.0 / 12.0) + 0.4), [11\/12], size: 6pt)
  cdraw.content((px(14.0), py(23.0 / 21.0) + 0.4), [23\/21], size: 6pt)
  cdraw.content((8.9, 1.95), [tight cluster repeats 11\/12 and 23\/21], size: 6pt)
  cdraw.content((px(60.0), py(11.0) + 0.4), [LOF(60) = 11], size: 6pt)
})

#callout("pitfall", "why 11, and not 21 over 2", [
  The sheet records a resolved discrepancy worth retelling: a first hand
  pass scored LOF(60) = 21\/2 by treating all three neighbors as lrd
  3\/8. Point 33 is an edge point of the tight cluster, kdist(33) = 3,
  reach distances 3, 2, 2, so its lrd is 3\/7, not 3\/8. That one neighbor
  mispriced moves the answer by half: the mean lifts by $(3\/7 - 3\/8)\/3
  = 1\/56$, the ratio by $(1\/56)\/(1\/28) = 1\/2$, from 21\/2 up to 11.
  That fragility is exactly why the book asserts LOF as a reduced
  fraction pair, never a double: "ch38 lof(60) = 11/1".
])

== what clustering sees instead

The same fixture through clustering glasses flags different points.
#xref-to("kdd", "kmeans") owns Lloyd's algorithm; here the sample
verifies the two partitions are its fixed points and reads two rules off
them. The global rule scores each point by distance to its own centroid;
the size rule calls any cluster under 3 members anomalous.

The dry run: at k = 2 the fixed point splits {10, 12, 14, 16} from the
rest, centroids printed as `km2 centroids 13/1,186/5` and the decision
boundary checked at 251\/10. Point 60 sits $60 - 186\/5 = 114\/5$ from
its centroid, the runner-up 30 sits 36\/5, ratio 19\/6, printed as
`centroid_dist 60=114/5 next=36/5 ratio=19/6`. The median own-cluster
distance is 21\/5, so the 3 x median threshold is 63\/5, and only 60
clears it: `centroid_dist median=21/5 thr3med=63/5 flags={60}`. At k = 3
the fixed point is {10, 12}, {14, 16}, the rest, boundaries 13 and
261\/10, sizes 2, 2, 5, printed as `km3 centroids 11/1,15/1,186/5 sizes
2,2,5`. The size rule then flags `size_rule_lt3 flags={10,12,14,16}` and
the contrast lands: the four flagged points carry LOFs 11\/12, 23\/21,
23\/21, 11\/12, printed as `lof_of_flagged 11/12,23/21,23/21,11/12
all<3/2` and asserted as "ch38 LOF misses all four size-flagged points
(< 3/2)". A small cluster is not a sparse point.

#listing("kdd/samples/src/Ch38/contrast.c", first: 80, last: 87,
  caption: [the k=2 Lloyd fixed point and its exact centroids])

#listing("kdd/samples/src/Ch38/contrast.c", first: 114, last: 127,
  caption: [the 3*median global rule, exact fractions, one flag])

#listing("kdd/samples/src/Ch38/contrast.c", first: 171, last: 185,
  caption: [the size rule flags four points whose LOFs all sit under 3/2])

#diagram([two fixed-point partitions; the size rule flags what LOF forgives], length: 13pt, {
  let px(v) = { 1.4 + (v - 10.0) * 0.28 }
  let pts = (10, 12, 14, 16, 30, 31, 32, 33, 60)
  let lane(y, name) = {
    cdraw.content((0.6, y), name, size: 6pt)
    cdraw.line((1.25, y), (15.95, y), stroke: luma(170))
    for p in pts {
      cdraw.circle((px(p * 1.0), y), radius: 0.09, fill: luma(210), stroke: luma(60))
    }
  }
  lane(6.4, [k = 2])
  cdraw.line((px(25.1), 5.75), (px(25.1), 7.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(25.1), 7.35), [boundary 251\/10], size: 6pt)
  cdraw.content((2.3, 5.9), [sizes 4 and 5], size: 6pt)
  cdraw.content((9.3, 5.9), [centroid 186\/5, 60 off by 114\/5], size: 6pt)
  lane(3.4, [k = 3])
  cdraw.line((px(13.0), 2.95), (px(13.0), 3.85), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((px(26.1), 2.95), (px(26.1), 3.85), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(13.0), 4.2), [13], size: 6pt)
  cdraw.content((px(26.1), 4.2), [261\/10], size: 6pt)
  cdraw.line((1.2, 2.6), (3.3, 2.6), stroke: luma(110))
  cdraw.line((1.2, 2.46), (1.2, 2.74), stroke: luma(110))
  cdraw.line((3.3, 2.46), (3.3, 2.74), stroke: luma(110))
  cdraw.content((4.5, 2.0), [size rule flags {10,12,14,16}], size: 6pt)
  cdraw.content((10.5, 2.6), [sizes 2, 2, 5], size: 6pt)
  cdraw.content((10.2, 1.1), [their LOFs 11\/12, 23\/21, 23\/21, 11\/12, all under 3\/2], size: 6pt)
})

Three rules, three different flag sets on nine fixed points: LOF flags
{60}, the centroid rule flags {60}, the size rule flags {10, 12, 14, 16}.
Which rule is right is not a mathematical question but a question about
what the pipeline is hunting, and that is the cue for the statistics
chapters: a rule that flags has a false-positive rate, and
#xref-to("kdd", "hypothesis") measures exactly that.

sources: Markus M. Breunig, Hans-Peter Kriegel, Raymond T. Ng, Jorg
Sander, "LOF: Identifying Density-Based Local Outliers", Proceedings of
SIGMOD 2000, 93-104, definitions of k-distance, reach distance, lrd, and
LOF, banked by kdd-contract-s8s9.md with the LOF(60) = 11 discrepancy
resolution recorded. All 63 pinned values witnessed by the sheet and
playground/kdd-matrix/gen_s8.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch38`, 48 + 15 checks in chapter 38 of
the kdd suite.
