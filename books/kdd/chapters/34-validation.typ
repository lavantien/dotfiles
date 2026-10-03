// ch34, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 41 checks in kdd/samples/src/Ch34/validate.c or a banked provenance
// note: the silhouette is Rousseeuw 1987, "Silhouettes: a graphical aid
// to the interpretation and validation of cluster analysis", J. Comp.
// Appl. Math. 20:53-65, and the second-difference elbow is Thorndike
// 1953, Psychometrika 18:267, the same rule chapter 31 read on its own
// table. the fixture S is purpose-built: three aligned same-spacing APs
// with gaps 204/168 tuned so the two metrics disagree in the pinned
// direction elbow=k2 / silhouette=k3 (the flipped direction is
// structurally unreachable on contiguous 1D clusters, per the sheet's
// sweep and algebra note). silhouette rows run on S because the 2D blobs
// of ch33 carry surds; ch33 is reused through its census row only. all
// pinned values are witnessed by kdd-contract-s7.md +
// playground/kdd-matrix/gen_s7.py, run 2026-09-22, exit 0. determinism:
// D0 throughout; every a, b, s and both means are reduced int64 pairs,
// the k2 mean denominator 278240524809196950 sits under 2^63, and the
// two means are compared through the exact 4/5 sandwich, never
// cross-multiplied.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= cluster validation

One sample carries the chapter: `validate.c` prices the optimal
contiguous k-partitions of a 12-position line by dynamic programming,
scores silhouettes at k=2 and k=3 as exact fractions, and records the
two metrics disagreeing, 41 checks. The chapter makes 4 moves: the
partition table that makes the elbow exact, the silhouette width as a
per-point fraction, the disagreement between the two metrics with its
int64-safe comparison, and the negative width that flags one planted
misassignment. The elbow rule is the one #xref-to("kdd", "kmeans") read
off its own table, the chain DP is the exact k-means that chapter priced
out to #xref-to("icpc", "y2017"), the census row borrowed below is
#xref-to("kdd", "dbscan")'s, and the mindset is the label-free cousin of
the evaluation chapters: #xref-to("kdd", "evaluation") graded
predictions against truth, cluster validation grades a partition against
geometry.

== the partition table, priced exactly

The fixture is 12 positions on a line: three aligned APs of spacing 12,
groups {x1..x4} at 0..36, {x5..x8} at 240..276, {x9..x12} at 444..480,
with gaps 204 and 168. The third group sits 14 times farther out than
the second relative to the internal spacing, and that asymmetry is what
splits the two metrics later. On sorted 1D data the optimal
k-partition is contiguous, a crossing pair of clusters could be
uncrossed without raising SSE, so the table is a chain DP over split
indices, the same DP #xref-to("icpc", "y2017") uses when exact k-means
must actually run.

The dry run: the DP prints `k=1 sse=397296
parts={1,2,3,4,5,6,7,8,9,10,11,12}`, `k=2 sse=85392
parts={1,2,3,4}|{5,6,7,8,9,10,11,12}`, `k=3 sse=2160
parts={1,2,3,4}|{5,6,7,8}|{9,10,11,12}`, `k=4 sse=1584
parts={1,2}|{3,4}|{5,6,7,8}|{9,10,11,12}`. Each AP of spacing 12
contributes 720 around its mean, deviations $plus.minus 18, plus.minus 6$
twice, so k=3 lands at $3 dot 720 = 2160$ and k=4 pays 72 per split
pair. The gains print `gains 311904,83232,576`, second differences `d2
228672,82656`, and the elbow row closes `elbow=2
kneedle_2b_gt_a_plus_c=false`: the largest second difference sits at
k=2, $228672 > 82656$, and the kneedle-style crosscheck agrees it is no
elbow, $2 dot 83232 = 166464 < 311904 + 576$. Same rule as chapter 31,
different verdict, because the gap structure is different: there the
second group of gains collapsed late, here the k=2 split already removes
the enormous cross-gap variance.

#listing("kdd/samples/src/Ch34/validate.c", first: 88, last: 137,
  caption: [segment sse and the chain dp over split indices])

#listing("kdd/samples/src/Ch34/validate.c", first: 210, last: 269,
  caption: [the four table rows, the gains, the second differences, elbow=2])

#diagram([the line, its gaps, and the optimal partitions the dp prices], length: 12pt, {
  let px = (0.0, 0.5, 1.0, 1.5, 10.0, 10.5, 11.0, 11.5, 18.5, 19.0, 19.5, 20.0)
  cdraw.line((-0.5, 8.0), (20.5, 8.0), stroke: luma(120))
  for x in px {
    cdraw.line((x, 7.8), (x, 8.2), stroke: luma(120))
  }
  cdraw.content((0.75, 9.0), [spacing 12], size: 5.5pt)
  cdraw.content((10.75, 9.0), [spacing 12], size: 5.5pt)
  cdraw.content((19.25, 9.0), [spacing 12], size: 5.5pt)
  cdraw.content((5.75, 8.9), [gap 204], size: 6pt)
  cdraw.content((15.0, 8.9), [gap 168], size: 6pt)
  cdraw.line((1.5, 7.7), (10.0, 7.7), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">", start: ">"))
  cdraw.line((11.5, 7.7), (18.5, 7.7), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">", start: ">"))
  let rows = (
    (6.3, ((0.0, 1.5, 10.0, 20.0)), [k=1: sse 397296]),
    (4.8, ((0.0, 1.5, 10.0, 20.0)), [k=2: 85392]),
    (3.3, ((0.0, 1.5, 10.0, 11.5, 18.5, 20.0)), [k=3: 2160]),
    (1.8, ((0.0, 0.5, 1.0, 1.5, 10.0, 11.5, 18.5, 20.0)), [k=4: 1584]),
  )
  for row in rows {
    let (y, cuts, lab) = row
    cdraw.content((-1.6, y), lab, size: 6pt)
  }
  let brack = (y, a, b) => {
    cdraw.line((a, y), (b, y), stroke: luma(70))
    cdraw.line((a, y), (a, y + 0.25), stroke: luma(70))
    cdraw.line((b, y), (b, y + 0.25), stroke: luma(70))
  }
  brack(6.3, 0.0, 20.0)
  brack(4.8, 0.0, 1.5)
  brack(4.8, 10.0, 20.0)
  brack(3.3, 0.0, 1.5)
  brack(3.3, 10.0, 11.5)
  brack(3.3, 18.5, 20.0)
  brack(1.8, 0.0, 0.5)
  brack(1.8, 0.5, 1.5)
  brack(1.8, 10.0, 11.5)
  brack(1.8, 18.5, 20.0)
  cdraw.content((9.5, 0.4), [optimal contiguous k-partitions of sorted 1d data], size: 6pt)
})

== silhouettes as reduced fractions

The silhouette width scores one point against its own cluster: $s(i) =
(b(i) - a(i))\/max(a(i), b(i))$ with $a(i)$ the mean distance to the
point's own cluster and $b(i)$ the smallest mean distance to any other
cluster. Near 1 the point sits snug, near 0 it straddles, below 0 it is
closer to a neighbor than to home. On fixture S every distance is an
integer difference, so every $a$, $b$, and $s$ is an exact fraction, and
the sample holds them as reduced int64 pairs.

The dry run at k=3: `sil x1 a=24 b=258 s=39/43`. x1's own-cluster mean
is $(12 + 24 + 36)\/3 = 24$, the aligned AP making the arithmetic
integer; the nearest foreign cluster is the middle one at mean distance
258 against 462 for the far group, so $s = 234\/258 = 39\/43$. The
interior points do better, `sil x2 a=16 b=246 s=115/123`, and the
symmetry is exact: `sil x4 ... s=33/37` and `sil x5 ... s=33/37` agree
digit for digit, the two groups mirror each other around the 204 gap.
The mean over all 12 prints `mean k3 s=247695666679/273264726735`,
about 0.906, and the check pins the reduced pair itself, numerator and
denominator, not a double.

#listing("kdd/samples/src/Ch34/validate.c", first: 140, last: 177,
  caption: [silhouettes: integer sums, fraction means, exact max])

#listing("kdd/samples/src/Ch34/validate.c", first: 179, last: 193,
  caption: [the mean over a common denominator, numerators kept under int64])

#diagram([one width, two arrows: a stays home, b visits the nearest stranger], length: 12pt, {
  let px = (0.0, 0.5, 1.0, 1.5, 10.0, 10.5, 11.0, 11.5, 18.5, 19.0, 19.5, 20.0)
  cdraw.line((-0.5, 7.0), (20.5, 7.0), stroke: luma(120))
  for x in px {
    cdraw.line((x, 6.8), (x, 7.2), stroke: luma(120))
  }
  cdraw.circle((0.0, 7.0), radius: 0.28, fill: luma(40), stroke: none)
  cdraw.content((0.0, 8.0), [x1], size: 6.5pt)
  cdraw.line((0.15, 7.35), (1.35, 7.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((0.75, 8.6), [a = 24 over {x2,x3,x4}], size: 6pt)
  cdraw.line((0.3, 6.6), (9.8, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.4, 6.6), [b = 258 to the middle AP], size: 6pt)
  cdraw.rect((13.8, 8.0), (20.6, 9.6), fill: luma(243), radius: 0.05)
  cdraw.content((17.2, 9.05), [s(x1) = (258-24)\/258], size: 6pt)
  cdraw.content((17.2, 8.35), "= 39/43, about 0.907", size: 6pt)
  cdraw.line((-0.5, 2.5), (20.5, 2.5), stroke: luma(120))
  for x in px {
    cdraw.line((x, 2.3), (x, 2.7), stroke: luma(120))
  }
  cdraw.circle((10.0, 2.5), radius: 0.28, fill: luma(40), stroke: none)
  cdraw.content((10.0, 3.5), [x5], size: 6.5pt)
  cdraw.line((10.15, 2.85), (11.35, 3.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.6, 3.9), [a = 24 over {x6,x7,x8}], size: 6pt)
  cdraw.line((9.8, 2.1), (1.7, 1.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.0, 2.1), [b = 222 to the first AP, not 462 to the far one], size: 6pt)
  cdraw.content((10.0, 0.4), [s(x5) = 198\/222 = 33\/37, mirroring x4 exactly], size: 6pt)
})

== two metrics, two answers

At k=2 the merged cluster is the eight-point right side, and its $a(i)$
carry a denominator 7, one mean over seven housemates: `sil x5 a=960/7
b=222 s=99/259` is the reduced shape of $(222 - 960\/7)\/222$. All 12
rows print as exact fractions, and the mean prints `mean k2
s=198009421810108463/278240524809196950`, about 0.712, a denominator of
$2.78 times 10^17$ that still fits an int64. Two fractions that large
are never cross-multiplied against each other, the products would
overflow: the sample decides the preference through the exact sandwich
instead, checking `k2mean < 4/5 < k3mean` with each comparison a single
int64-safe cross-multiply.

The dry run: the sandwich holds, the rows print `silhouette_prefers=k3`
and `disagreement elbow=k2 silhouette=k3`. The direction is pinned after
a ruled-out alternative: a parameter sweep over 1D cluster families
found zero configurations with silhouette preferring 2 while the elbow
sat at 3, and the algebra says why. The elbow needs the k=3 split to
remove gap-squared variance, so it wants gaps huge relative to spread;
the silhouette rewards a merged cluster whose cross-gap is about one
internal spread, $b$ only modestly larger than $a$. On contiguous
clusters those two scales contradict, and this fixture exhibits the
direction that exists: the elbow stops at 2, the silhouette climbs to 3.
The pedagogical point survives verbatim, the metrics can disagree, and
here they do, in print, with both exact.

#listing("kdd/samples/src/Ch34/validate.c", first: 292, last: 326,
  caption: [both means pinned as reduced pairs, the sandwich, the disagreement])

#diagram([the elbow stops at k=2, the silhouette mean climbs to k=3], length: 12pt, {
  let xs = (2.0, 4.6, 7.2, 9.8)
  let ys = (9.0, 4.2, 0.9, 0.7)
  cdraw.line((1.0, 0.0), (10.8, 0.0), stroke: luma(200))
  for i in range(4) {
    cdraw.content((xs.at(i), -0.9), [k=#(i + 1)], size: 6pt)
    cdraw.circle((xs.at(i), ys.at(i)), radius: 0.3, fill: luma(70), stroke: none)
  }
  for i in range(3) {
    cdraw.line((xs.at(i), ys.at(i)), (xs.at(i + 1), ys.at(i + 1)), stroke: luma(120))
  }
  cdraw.content((2.0, 9.9), [397296], size: 5.5pt)
  cdraw.content((4.6, 5.45), [85392], size: 5.5pt)
  cdraw.content((7.2, 1.8), [2160], size: 5.5pt)
  cdraw.content((9.8, 1.6), [1584], size: 5.5pt)
  cdraw.circle((4.6, 4.2), radius: 0.75, stroke: rgb("#8B0000"))
  cdraw.content((6.5, 9.9), [sse, heights sqrt-scaled, elbow at k=2], size: 6pt)
  cdraw.content((13.6, 9.4), [silhouette mean, exact fractions], size: 6pt)
  cdraw.line((12.4, 0.0), (19.6, 0.0), stroke: luma(200))
  cdraw.content((13.6, -0.9), [k=2], size: 6pt)
  cdraw.content((17.6, -0.9), [k=3], size: 6pt)
  cdraw.rect((12.9, 0.0), (14.3, 5.69), fill: luma(180), stroke: none)
  cdraw.rect((16.9, 0.0), (18.3, 7.25), fill: luma(180), stroke: none)
  cdraw.line((12.4, 6.4), (19.6, 6.4), stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  cdraw.content((19.9, 6.4), [4\/5], size: 6pt)
  cdraw.content((13.6, 5.0), [0.712], size: 5.5pt)
  cdraw.content((17.6, 8.2), [0.906], size: 5.5pt)
  cdraw.content((11.0, -2.5), [sandwich: k2 mean < 4\/5 < k3 mean, each side one], size: 6pt)
  cdraw.content((11.0, -3.5), [int64 cross-multiply, the two means never multiplied], size: 6pt)
  cdraw.content((11.0, -4.5), [disagreement elbow=k2 silhouette=k3], size: 6.5pt)
})

#callout("pitfall", "big exact fractions need safe comparisons", [
  The k=2 mean denominator is $278240524809196950$, about $2.8 times
  10^17$, and int64 tops out near $9.2 times 10^18$. Cross-multiplying
  the two mean fractions multiplies two 17-digit numbers and overflows
  silently in signed arithmetic, the worst kind of wrong answer: a
  comparison that returns garbage without any signal. The pinned route
  compares each mean against the fixed rational 4/5 separately, one
  cross-multiply per side, both provably in range. The same discipline
  built the mean itself, summing over the least common denominator so
  no intermediate product leaves int64.
])

== a negative width and two borrowed rows

Plant one bad assignment, x5 forced into the first cluster, and the
width goes negative, the silhouette's built-in alarm. The dry run: with
owners {x1..x5} together, x5's own-cluster mean is the average distance
back over the 204 gap, $"a"(x_5) = (240 + 228 + 216 + 204)\/4 = 222$,
while the nearest foreign cluster is now the middle AP without it, $"b"
= (12 + 24 + 36)\/3 = 24$. The row prints `mis x5 a=222 b=24 s=-33/37`,
$-198\/222$, and the sign is the whole content: home is nine times
farther than the neighbor, the point is misplaced, no thresholding
needed.

The chapter closes on two borrowed rows, replaying their source
chapters' values: `ch33 census core=6 border=4 noise=2 clusters=2` and
`ch31 elbow k=1..4 sse=2160,1080,144,80 elbow=3`. Validation reads
other chapters' outputs, and the checks pin the same values the source
samples printed: the census describes a clustering that never
took k, and the F12 elbow row reminds that the same rule read a
different table three chapters ago and said 3, not 2. The metric is
the metric; the data decides.

#listing("kdd/samples/src/Ch34/validate.c", first: 328, last: 352,
  caption: [the misassigned x5 row and the two borrowed reuse rows])

#diagram([one point dragged across the 204 gap: a explodes, b collapses, s goes negative], length: 12pt, {
  let px = (0.0, 0.5, 1.0, 1.5, 10.0, 10.5, 11.0, 11.5, 18.5, 19.0, 19.5, 20.0)
  cdraw.line((-0.5, 6.0), (20.5, 6.0), stroke: luma(120))
  for x in px {
    cdraw.line((x, 5.8), (x, 6.2), stroke: luma(120))
  }
  cdraw.circle((10.0, 6.0), radius: 0.32, fill: rgb("#8B0000"), stroke: none)
  cdraw.content((10.0, 7.0), [x5, planted into A], size: 6.5pt)
  let brack = (y, a, b) => {
    cdraw.line((a, y), (b, y), stroke: luma(70))
    cdraw.line((a, y), (a, y + 0.25), stroke: luma(70))
    cdraw.line((b, y), (b, y + 0.25), stroke: luma(70))
  }
  brack(4.8, 0.0, 10.0)
  brack(4.8, 10.0, 11.5)
  brack(4.8, 18.5, 20.0)
  cdraw.content((-1.4, 4.8), [A'], size: 6pt)
  cdraw.content((10.75, 4.0), [B], size: 6pt)
  cdraw.content((19.25, 4.0), [C], size: 6pt)
  cdraw.line((9.7, 5.7), (1.3, 5.0), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.6, 5.75), [a = 222 back over the gap], size: 6pt)
  cdraw.line((10.3, 6.35), (11.3, 6.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((12.9, 7.2), [b = 24 to B], size: 6pt)
  cdraw.rect((12.6, 1.6), (20.0, 3.2), fill: luma(243), radius: 0.05)
  cdraw.content((16.3, 2.65), [s(x5) = (24 - 222)\/222 = -33\/37], size: 6.5pt)
  cdraw.content((16.3, 1.95), [negative width: misplaced, no threshold needed], size: 6pt)
  cdraw.content((8.0, 0.3), [undo the plant and x5 scores 33\/37, the mirror of x4], size: 6pt)
})

sources: the silhouette width and its reading are Rousseeuw 1987,
"Silhouettes: a graphical aid to the interpretation and validation of
cluster analysis", Journal of Computational and Applied Mathematics
20:53-65, and the largest-second-difference elbow with the kneedle-style
crosscheck is Thorndike 1953, Psychometrika 18:267, as pinned for
chapter 31. The fixture S, the disagreement direction with its
ruled-out alternative, the int64 sandwich, and both reuse rows are
pinned by kdd-contract-s7.md and witnessed by
playground/kdd-matrix/gen_s7.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch34`, 41 checks in chapter
34 of the kdd suite.
