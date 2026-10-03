// ch45, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 54 checks in kdd/samples/src/Ch45/sommap.c or a banked provenance
// note: the metrics are the standard SOM quality measures of T. Kohonen,
// Self-Organizing Maps, Springer 3rd ed. 2001, applied to the chapter 44
// final map, which this sample retrains from the same seed and re-pins
// so divergence localizes to one chapter. all pinned values are witnessed
// by kdd-contract-s8s9.md + playground/kdd-matrix/gen_s9.py, run
// 2026-09-22, exit 0. D0 fractions for TE and topo counts, D1 for the
// dyadic k-means arithmetic, D3 for every SOM double: one operation per
// statement, FP_CONTRACT off, only + - * / and IEEE sqrt, asserted ==.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= som analysis and visualization

One sample carries the chapter: `sommap.c` retrains the chapter 44 map
from the same seed, re-pins its final grid, then grades it, quantization
error and SSE per input, topographic error over second-best units, the
u-matrix and component planes, a k-means k=2 contrast with exact
arithmetic, and the ring-topology census, 54 checks. The chapter makes 4
moves: error measures that treat the map as a quantizer, a topology
measure that treats it as a manifold, structural views that expose fold
and stretch, and the head-to-head against #xref-to("kdd", "kmeans") that
prices what the grid buys. The chapter is the map-side counterpart of
#xref-to("kdd", "validation"), which graded clusterings by index, and
every distance it sums is the squared euclidean of
#xref-to("kdd", "distance") under the same one-op-per-statement
discipline #xref-to("kdd", "som") pinned.

== quantization error and SSE

The retrained map lands bit-for-bit on the chapter 44 pins, six `==`
checks of the form "ch45 final
u0=(1.7736785518636009,6.7858215993753985) equals ch44 pin", the
chapter-local divergence guard: if any metric below
looks wrong, the fault is here or upstream, never ambiguity about which
map was measured. Then each input is scored against its best unit. The
quantization error is the mean euclidean distance to the winner, the sum
of eight `sqrt(d2)` in input order divided by 8, and SSE_som is the sum
of the eight squared distances in the same order.

The dry run: eight rows, `finalbmu x1=u2 d2=1.5359862538166922
d=1.2393491250719839` through `finalbmu x8=u2 d2=0.65739133701155228
d=0.81079672977359274`, each triple, unit, d2, d, its own check. The
totals print `QE=1.4362362499549604` and `SSE_som=18.326103126534949`,
both asserted with `==`, D3. Reading the winners: u2 takes x1 and x8,
the low-y end of the ring, u4 takes x2 and x3, u3 takes x4 alone, u0
takes x5 and x6, u5 takes x7 alone, and u1, the dead unit, takes nothing,
its distance column is absent because it is never a BMU. The worst fit is
x3 at d = 2.048, the ring's far corner stretching toward a unit that
must also serve x2.

#listing("kdd/samples/src/Ch45/sommap.c", first: 147, last: 173,
  caption: [the QE pass: BMU d2, its sqrt, a running total in input order])

#diagram([the final map in data space, dashed lines tie each input to its winner], length: 13pt, {
  let px(v) = { 2.2 + v * 1.62 }
  let py(v) = { 8.3 - v * 0.8 }
  let units = (([u0], 1.773678551863601, 6.7858215993753985, -0.75, 0.5),
    ([u1], 2.9240485376881993, 3.1672306950233438, -0.4, 0.72),
    ([u2], 2.780351270798715, 0.22009823073887433, -0.85, -0.28),
    ([u3], 5.161490764968483, 7.3650730481977105, 0.45, 0.55),
    ([u4], 6.385954300279085, 3.738742321493029, 0.7, 0.0),
    ([u5], 0.7880215092308555, 1.739651086093076, -0.8, 0.0))
  let grid_edges = ((0, 1), (1, 2), (3, 4), (4, 5), (0, 3), (1, 4), (2, 5))
  for e in grid_edges {
    let a = units.at(e.at(0))
    let b = units.at(e.at(1))
    cdraw.line((px(a.at(1)), py(a.at(2))), (px(b.at(1)), py(b.at(2))),
      stroke: luma(190))
  }
  let assigns = ((1, 2), (2, 4), (3, 4), (4, 3), (5, 0), (6, 0), (7, 5), (8, 2))
  let ins = ((4, 0), (7, 2), (8, 5), (6, 8), (3, 8), (0, 6), (0, 2), (2, 0))
  for a in assigns {
    let x = ins.at(a.at(0) - 1)
    let u = units.at(a.at(1))
    cdraw.line((px(x.at(0) * 1.0), py(x.at(1) * 1.0)), (px(u.at(1)), py(u.at(2))),
      stroke: (paint: luma(150), dash: "dashed"))
  }
  for u in units {
    cdraw.rect((px(u.at(1)) - 0.28, py(u.at(2)) - 0.26), (px(u.at(1)) + 0.28, py(u.at(2)) + 0.26),
      fill: luma(244), radius: 0.02, stroke: luma(120))
    cdraw.content((px(u.at(1)) + u.at(3), py(u.at(2)) + u.at(4) * -1.0), u.at(0), size: 6pt)
  }
  let offs = ((0.5, -0.5), (0.5, 0.4), (0.55, 0.0), (0.0, 0.6), (-0.4, 0.55), (-0.75, 0.0),
    (-0.75, 0.0), (-0.5, -0.5))
  for i in range(8) {
    let x = ins.at(i)
    cdraw.circle((px(x.at(0) * 1.0), py(x.at(1) * 1.0)), radius: 0.11,
      fill: luma(150), stroke: luma(60))
    cdraw.content((px(x.at(0) * 1.0) + offs.at(i).at(0),
      py(x.at(1) * 1.0) + offs.at(i).at(1) * -1.0), [x#(i + 1)], size: 6pt)
  }
  cdraw.content((11.2, 8.4), [thin lines: grid topology, dashed: BMU assignment], size: 6pt)
  cdraw.content((11.2, 0.4), [u1 wins nothing, the dead unit], size: 6pt)
})

== topographic error

A quantizer can be perfect at distances and still fold the manifold, so
the second measure is topological. For each input, take the best and the
second-best unit, if the input really sits between two neighboring
lattice positions the runner-up should be the winner's grid neighbor. The
topographic error is the fraction of inputs whose two best units are not
von Neumann adjacent, $|d_r| + |d_c| = 1$ exactly, diagonal does not
count.

The dry run: eight rows, `te x1 best=u2 second=u1 adjacent=true` down to
`te x8 best=u2 second=u5 adjacent=true`, each row a check, and one
failure among them, `te x7 best=u5 second=u1 adjacent=false`: u5 is row 1
column 2, u1 is row 0 column 1, one row apart and one column apart,
diagonal, not adjacent. The total prints `TE=1/8`, asserted as "ch45
TE=1/8" and cross-multiplied as a fraction pair, D0. Seven of eight
inputs have their two best units side by side on the lattice, the map is
close to topology-preserving, and the single fold sits exactly where the
worst quantization error sat, the far corner around x3, x4 and x7 where
the ring bends hardest.

#listing("kdd/samples/src/Ch45/sommap.c", first: 176, last: 209,
  caption: [second-best by strict scan, adjacency by von Neumann, one fold found])

#diagram([the 2x3 lattice with each input's two best units, the diagonal pair highlighted], length: 13pt, {
  let cellx(c) = { 4.6 + c * 3.2 }
  let celly(r) = { 6.4 - r * 2.6 }
  for r in range(2) {
    for c in range(3) {
      cdraw.rect((cellx(c) - 1.3, celly(r) - 1.0), (cellx(c) + 1.3, celly(r) + 1.0),
        fill: luma(246), radius: 0.02, stroke: luma(150))
      cdraw.content((cellx(c), celly(r)), [u#(3 * r + c)], size: 7.5pt)
    }
  }
  let rows = (([x1], [u2], [u1], true), ([x2], [u4], [u1], true),
    ([x3], [u4], [u3], true), ([x4], [u3], [u4], true),
    ([x5], [u0], [u3], true), ([x6], [u0], [u1], true),
    ([x7], [u5], [u1], false), ([x8], [u2], [u5], true))
  cdraw.content((13.9, 8.4), [best \/ second, adjacency], size: 6pt)
  let ys = (7.3, 6.4, 5.5, 4.6, 3.7, 2.8, 1.9, 1.0)
  for i in range(8) {
    let r = rows.at(i)
    cdraw.rect((12.2, ys.at(i) - 0.38), (17.4, ys.at(i) + 0.38),
      fill: if r.at(3) {luma(248)} else {luma(214)}, radius: 0.02, stroke: luma(160))
    cdraw.content((13.4, ys.at(i)), r.at(0), size: 6pt)
    cdraw.content((14.9, ys.at(i)), r.at(1), size: 6pt)
    cdraw.content((16.0, ys.at(i)), r.at(2), size: 6pt)
    cdraw.content((17.1, ys.at(i)), [#r.at(3)], size: 6pt)
  }
  cdraw.line((11.0, 3.8), (7.8, 6.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((9.6, 5.35), [x7 folds: u5 to u1], size: 6pt)
  cdraw.content((4.6, 0.3), [the one non-adjacent pair is diagonal], size: 6pt)
})

== the u-matrix and the component planes

Structure the scalar scores cannot show lives in two visualizations. The
u-matrix paints each lattice edge with the distance between the two units
it joins, 4 horizontal and 3 vertical edges here, so a dark long edge is
a tear in the map, two neighboring grid positions whose weights drifted
apart. The component planes show one weight dimension across the grid,
where the map's low and high ends of each input feature landed.

The dry run: seven edge rows, `umatrix u0-u1 d2=14.417551237345508
d=3.7970450665412847` and its siblings, each d2 and d asserted `==`,
with the longest being `umatrix u4-u5 d2=35.333217300545932
d=5.944175073174236`, the tear, u4 and u5 are grid neighbors but their
weights sit at opposite ends of the data, u4 serving the x2, x3 corner
and u5 serving x7 alone. The two plane rows print `plane dim0
min=u5:0.78802150923085545 max=u4:6.3859543002790851` and `plane dim1
min=u2:0.22009823073887433 max=u3:7.3650730481977105`, asserted as "ch45
plane dim0 min=u5 max=u4" and "ch45 plane dim1 min=u2 max=u3": the first
input dimension runs from u5 to u4, the same torn edge, and the second
from u2, the bottom of the ring, to u3, the top, the full vertical span
of the data compressed into one grid column step.

#listing("kdd/samples/src/Ch45/sommap.c", first: 211, last: 224,
  caption: [seven inter-node distances, one per lattice edge, each asserted])

#diagram([u-matrix on the lattice: edge length encodes distance, the u4-u5 tear], length: 13pt, {
  let cellx(c) = { 4.9 + c * 3.0 }
  let celly(r) = { 6.0 - r * 3.0 }
  let ds = (((0, 1), 3.80), ((1, 2), 2.95), ((3, 4), 3.83), ((4, 5), 5.94),
    ((0, 3), 3.44), ((1, 4), 3.51), ((2, 5), 2.51))
  for e in ds {
    let p = e.at(0)
    let r1 = if p.at(0) >= 3 {1} else {0}
    let c1 = p.at(0) - 3 * r1
    let r2 = if p.at(1) >= 3 {1} else {0}
    let c2 = p.at(1) - 3 * r2
    let w = (e.at(1) - 2.0) / 4.5
    cdraw.line((cellx(c1), celly(r1)), (cellx(c2), celly(r2)),
      stroke: (paint: luma(calc.clamp(220 - w * 160, 30, 230)), thickness: 0.6pt + w * 2.4pt))
    cdraw.content(((cellx(c1) + cellx(c2)) / 2 + 0.75, (celly(r1) + celly(r2)) / 2 + 0.42),
      [#e.at(1)], size: 6pt)
  }
  for r in range(2) {
    for c in range(3) {
      cdraw.circle((cellx(c), celly(r)), radius: 0.34, fill: luma(246), stroke: luma(120))
      cdraw.content((cellx(c), celly(r)), [u#(3 * r + c)], size: 6.5pt)
    }
  }
  cdraw.content((8.9, 8.4), [u-matrix: thicker, darker edge = farther weights], size: 6pt)
  cdraw.content((8.9, 0.2), [the 5.94 edge is the tear, matching the TE fold], size: 6pt)
})

#callout("note", "two adjacencies, two purposes", [
  This chapter uses adjacency twice with different rules. The topographic
  error asks whether the two best units are strictly von Neumann adjacent,
  $|d_r| + |d_c| = 1$, equality excluded because a unit is trivially its
  own neighbor. The ring census below counts a pair as fine when the two
  BMUs are equal or adjacent, $|d_r| + |d_c| <= 1$, because consecutive
  ring inputs landing on the same unit is perfect behavior, not a fold.
  The two signs, strict for the error, inclusive for the census, are both
  pinned in checks, and conflating them would change both counts.
])

== k-means contrast, and the ring census

The k-means comparison plants k = 2 at x1 and x5, runs Lloyd to its fixed
point, and scores it exactly. The point is not that one algorithm wins a
beauty contest, it is that the same fixture prices the grid's extra
units: six prototypes against two, and topology for free.

The dry run: `kmeans iter1 A={1,2,7,8} B={3,4,5,6} c1=(3.25,1)
c2=(4.25,6.75) stable=false`, then `kmeans iter2` with the identical
partition and centroids and `stable=true`, each iteration's membership,
centroid and stability a check, and "ch45 kmeans fixed point reached at
iter 2". The partition is horizontal, the low ring against the high ring,
with exact dyadic centroids $(13\/4, 1)$ and $(17\/4, 27\/4)$. The
energy prints `SSE_kmeans2=1188/16=74.25`, asserted three ways, the
numerator 1188 over 16, the reduced pair 297/4 cross-multiplied, and the
dyadic value 74.25 with `==`. The hand witness behind it: $492\/16$ from
cluster A plus $696\/16$ from cluster B. Against SSE_som =
18.326103126534949 the check "ch45 SOM SSE 18.326... beats k-means 74.25"
fires, about a factor of 4, which is mostly the 6-to-2 prototype count
and partly the SOM's freedom to place units off centroid. The census
closes the chapter: consecutive ring inputs, including the wrap pair
x8 to x1, map to equal-or-adjacent BMUs in 6 of 8 cases, the failures
`topo x1->x2 u2->u4 ok=false` and `topo x6->x7 u0->u5 ok=false`,
asserted, and `topo_adjacent_pairs=6/8`, asserted as the reduced 3/4.
The two failures are the two places the ring changes grid rows, exactly
where the tear and the topographic fold already pointed.

#listing("kdd/samples/src/Ch45/sommap.c", first: 254, last: 329,
  caption: [Lloyd planted at x1 and x5, two iterations to the fixed point, all dyadic])

#listing("kdd/samples/src/Ch45/sommap.c", first: 331, last: 350,
  caption: [the exact k-means SSE in sixteenths, reduced to 297/4, compared against SSE_som])

#diagram([k-means splits the ring in two, the SOM walks it around the lattice], length: 13pt, {
  let px(v) = { 1.6 + v * 0.72 }
  let py(v) = { 7.6 - v * 0.7 }
  cdraw.content((4.4, 8.3), [k-means k=2], size: 6.5pt)
  let lo = ((4, 0), (7, 2), (2, 0), (0, 2))
  let hi = ((8, 5), (6, 8), (3, 8), (0, 6))
  for p in lo {
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1) * 1.0)), radius: 0.12, fill: luma(214), stroke: luma(90))
  }
  for p in hi {
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1) * 1.0)), radius: 0.12, fill: luma(170), stroke: luma(60))
  }
  cdraw.content((2.55, 7.15), [cA], size: 6pt)
  cdraw.content((5.35, 3.15), [cB], size: 6pt)
  cdraw.circle((px(3.25), py(1.0)), radius: 0.17, fill: white, stroke: luma(60))
  cdraw.circle((px(4.25), py(6.75)), radius: 0.17, fill: white, stroke: luma(60))
  cdraw.content((4.4, 0.85), [white circles: exact centroids, SSE = 297\/4 = 74.25], size: 6pt)
  cdraw.content((4.4, 0.35), [SOM SSE = 18.326..., about 4 times lower], size: 6pt)
  cdraw.content((12.9, 8.3), [SOM census, ring order], size: 6.5pt)
  let order = ([x1 -> u2], [x2 -> u4], [x3 -> u4], [x4 -> u3],
    [x5 -> u0], [x6 -> u0], [x7 -> u5], [x8 -> u2])
  let ok = (false, true, true, true, true, false, true, true)
  for i in range(8) {
    cdraw.rect((9.2, 6.9 - i * 0.83 - 0.35), (16.8, 6.9 - i * 0.83 + 0.35),
      fill: if ok.at(i) {luma(248)} else {luma(214)}, radius: 0.02, stroke: luma(160))
    cdraw.content((13.0, 6.9 - i * 0.83), order.at(i), size: 6pt)
    cdraw.content((15.9, 6.9 - i * 0.83), [ok = #ok.at(i)], size: 6pt)
  }
  cdraw.content((12.9, 0.4), [6\/8 adjacent-or-equal, the 2 misses change grid rows], size: 6pt)
})

sources: quantization error, topographic error, the u-matrix and
component planes are the standard quality measures of T. Kohonen,
Self-Organizing Maps, Springer Series in Information Sciences 30, 3rd
ed. 2001, chapters 3 and 4, with every pinned double witnessed by
kdd-contract-s8s9.md and playground/kdd-matrix/gen_s9.py, run 2026-09-22,
exit 0. The k-means contrast follows the Lloyd fixed-point machinery of
#xref-to("kdd", "kmeans") with exact dyadic arithmetic. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch45`, 54 checks in chapter 45 of the kdd
suite.
