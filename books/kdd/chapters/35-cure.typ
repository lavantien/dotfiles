// ch35, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 69 checks in kdd/samples/src/Ch35/centroid.c (10), cure.c (30),
// curepart.c (8), and chameleon.c (21) or a banked provenance note: CURE
// is Guha, Rastogi, Shim, SIGMOD 1998, "CURE: an efficient clustering
// algorithm for large databases",
// dl.acm.org/doi/10.1145/276304.276312, whose partition-then-label
// design curepart.c reproduces, and Chameleon is Karypis, Han, Kumar,
// IEEE Computer 32(8):68-75, 1999, whose RI/RC formulas the sample
// implements as pinned. the fixture is an L of 6 plus a compact 4-point
// rectangle whose edge x = 54 sits inside the calibrated window 52.1 <
// x < 56.3 where centroid linkage errs (4285/4 < 1233) but CURE resists
// (765 < 14545/16); the ordering witness fraction is 14545/16 =
// 909.0625 as computed. all pinned values are witnessed by
// kdd-contract-s7.md + playground/kdd-matrix/gen_s7.py, run 2026-09-22,
// exit 0. determinism: D0 for every merge distance as a reduced int64
// fraction; D1 dyadic for all cluster means and shrunk reps (halves and
// quarters), also exact fractions, never doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= cure and chameleon

Four samples carry the chapter: `centroid.c` runs centroid linkage to
the wrong k=2, 10 checks, `cure.c` runs CURE to the right one and
witnesses the ordering both lanes live or die by, 30 checks,
`curepart.c` reproduces the direct result through the paper's
partition-then-label route, 8 checks, and `chameleon.c` scores merges on
a kNN graph with RI and RC, 21 checks. The chapter makes 4 moves: the
centroid lane and the L it tears, the shrunk representatives that resist
the tear, the partition-then-label scalability that lands on the same
answer, and the graph lane where merge criteria read edge counts. The
erring lane is the fourth linkage of #xref-to("kdd", "hierarchical"),
the means that mislead it are the same statistic #xref-to("kdd",
"kmeans") lives by, and the graph lane hands off to
#xref-to("kdd", "spectral").

== the fixture and the erring centroid lane

The fixture is an L and a blob: p1 through p6 trace an L, a horizontal
arm from (0,0) to (27,0) rising to the arm top p6 = (27,36), and p7
through p10 form a compact 8x9 rectangle at (54,42) to (62,51). The
blob's edge sits at x = 54 by calibration, inside the window 52.1 < x <
56.3 where centroid linkage errs on this L while CURE does not, so the
fixture is a controlled experiment, not a coincidence.

Centroid linkage merges by squared distance between cluster means, and
means hate L shapes: the arm's mass pulls its centroid into the elbow,
far from every actual point. The dry run: the trace prints `cmerge
{1}+{2} d2=36`, the blob's pairs at `64`, `64`, `81`, the arm growing
through `144` and `225` and `1825/4`, and then the fatal row `cmerge
{6}+{7,8,9,10} d2=4285/4`. At that moment {1,2,3,4,5} has mean (15,3)
and the blob has mean (58,93/2); the arm top p6 = (27,36) compares
$12^2 + 33^2 = 1233$ against the blob at $31^2 + (21\/2)^2 = 4285\/4 =
1071.25$, and the blob wins by 161.75. The run closes `cfinal
{1,2,3,4,5}|{6,7,8,9,10}`, the L split, the arm top dragged across the
gap into the rectangle. Every height is an exact fraction, `1825/4` and
`4285/4` among them, because means of integer points carry quarters.

#listing("kdd/samples/src/Ch35/centroid.c", first: 93, last: 110,
  caption: [squared distance between two cluster means, one exact fraction])

#listing("kdd/samples/src/Ch35/centroid.c", first: 122, last: 165,
  caption: [the merge loop and the pinned cfinal that is wrong on purpose])

#diagram([means against an L: the blob mean stands 1071.25 from p6, the arm mean 1233], length: 11pt, {
  let m = (x, y) => (x * 0.5, y * 0.5)
  cdraw.line(m(0, 0), m(27, 0), stroke: luma(205))
  cdraw.line(m(27, 0), m(27, 36), stroke: luma(205))
  cdraw.rect(m(54, 42), m(62, 51), stroke: luma(205))
  let pts = ((0, 0), (6, 0), (15, 0), (27, 0), (27, 15), (27, 36),
    (54, 42), (62, 42), (54, 51), (62, 51))
  for p in pts {
    cdraw.circle(m(p.at(0), p.at(1)), radius: 0.4, fill: luma(70), stroke: none)
  }
  cdraw.content((13.5, 19.1), [p6], size: 6.5pt)
  cdraw.rect((7.15, 1.15), (7.85, 1.85), fill: luma(30))
  cdraw.content((4.9, 2.5), [mean (15,3)], size: 6pt)
  cdraw.rect((28.65, 22.9), (29.35, 23.6), fill: luma(30))
  cdraw.content((29.8, 25.25), [mean (58,93\/2)], size: 6pt)
  cdraw.line(m(27, 36), m(15, 3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((5.6, 8), [1233, loses], size: 6pt)
  cdraw.line(m(27, 36), m(58, 46.5), stroke: rgb("#8B0000"))
  cdraw.content((22, 22.8), [4285\/4 = 1071.25, wins], size: 6pt)
  cdraw.line(m(0, 0), m(27, 0), m(27, 15), stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  cdraw.content(m(10, 30.5), [cfinal: the L split, p6 with the blob], size: 6pt)
  cdraw.content(m(10, 28.3), [both distances exact fractions, int64 pairs], size: 6pt)
})

== cure: shrink and survive

CURE replaces the single mean with a handful of representatives that
chase the cluster's shape: pick c = 2 points farthest-first from the
mean, the farthest point first, then the farthest from it, ties to the
lowest index, and shrink each toward the mean by $alpha = 1\/2$, shrunk
equals mean + $alpha$ (rep - mean). The cluster distance is the minimum over
shrunk-rep pairs, so one surviving extreme keeps a non-convex cluster
reachable without letting outliers set the whole scale.

The dry run, the two clusters that matter. The arm {1,2,3,4,5} has mean
(15,3); its farthest point is p5 at $288$ squared distance, the farthest
from p5 is p1 at $954$, and the shrunk reps land at (21,9) and
(15/2,3/2). The blob {7,8,9,10} has mean (58,93/2) and a genuine tie,
all four corners sit at squared distance $36.25$ from the mean, so the
lowest index p7 takes the first rep and the farthest-from-p7 takes the
second, shrinking to (56,177/4) and (60,195/4). The final CURE merge
prints `merge {1,2,3,4,5}+{6} d2=765`, the minimum over shrunk-rep
pairs, $6^2 + 27^2 = 765$ from rep (21,9) to p6, witnessed two ways in
the sample, by the hand identity and by the generator. The losing cross
distance is (56,177/4) to (27,36) at $14545\/16 = 909.0625$. So the
ordering witness reads: centroid linkage errs because $4285\/4 < 1233$,
CURE resists because $765 < 14545\/16$, one inequality each way, both
exact. The run closes with the final reps rows, `final
{1,2,3,4,5,6} mean=(17,17/2) shrunk=(22,89/4),(17/2,17/4)` and `final
{7,8,9,10} mean=(58,93/2) shrunk=(56,177/4),(60,195/4)`, and the
partition the chapter wanted, the L whole.

#listing("kdd/samples/src/Ch35/cure.c", first: 128, last: 177,
  caption: [mean, farthest-first reps with lowest-index ties, alpha=1/2 shrink])

#listing("kdd/samples/src/Ch35/cure.c", first: 179, last: 194,
  caption: [cluster distance: minimum over the shrunk-rep pairs])

#listing("kdd/samples/src/Ch35/cure.c", first: 345, last: 373,
  caption: [the right partition, the 765 witness, the ordering witness])

#diagram([shrunk reps: the arm keeps an extreme near p6, the blob pulls its corners in], length: 11pt, {
  let m = (x, y) => (x * 0.5, y * 0.5)
  cdraw.line(m(0, 0), m(27, 0), stroke: luma(205))
  cdraw.line(m(27, 0), m(27, 36), stroke: luma(205))
  cdraw.rect(m(54, 42), m(62, 51), stroke: luma(205))
  let pts = ((0, 0), (6, 0), (15, 0), (27, 0), (27, 15), (27, 36),
    (54, 42), (62, 42), (54, 51), (62, 51))
  for p in pts {
    cdraw.circle(m(p.at(0), p.at(1)), radius: 0.4, fill: luma(70), stroke: none)
  }
  cdraw.line(m(27, 15), m(21, 9), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">"))
  cdraw.line(m(0, 0), m(15, 3), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">"))
  cdraw.content((8.6, 2.8), [(21,9)], size: 6pt)
  cdraw.content((3.75, -1.05), [(15\/2,3\/2)], size: 6pt)
  cdraw.line(m(54, 42), m(56, 44.25), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">"))
  cdraw.line(m(62, 51), m(60, 48.75), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">"))
  cdraw.content((23.4, 22.425), [(56,177\/4)], size: 6pt)
  cdraw.content((33.3, 23.675), [(60,195\/4)], size: 6pt)
  cdraw.line(m(21, 9), m(27, 36), stroke: rgb("#006400"))
  cdraw.content((4.35, 12.65), [765 = 6^2 + 27^2, wins], size: 6pt)
  cdraw.line(m(56, 44.25), m(27, 36), stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  cdraw.content((20, 21.4), [14545\/16 = 909.0625, loses], size: 6pt)
  cdraw.content(m(10, 30.5), [shrunk = mean + 1\/2 (rep - mean)], size: 6pt)
  cdraw.content(m(10, 28.3), [final {1..6} | {7..10}, the L whole], size: 6pt)
})

#callout("note", "the mean is a summary, the reps are a portrait", [
  The arm's mean (15,3) describes a point that belongs to no cluster and
  lies 33 vertical units from the arm top it is supposed to represent.
  CURE's shrunk reps keep one foot at each extreme, close enough to the
  shape that a distant blob cannot outbid them for the arm top, shrunk
  enough that a single outlier cannot stretch the cluster across the
  map. The alpha is the dial: 0 collapses to centroid linkage, 1 keeps
  the raw extremes, 1/2 is the paper's middle and the pinned value here.
])

== partition then label

CURE's answer to scale is to not touch all pairs at once: partition the
input, cluster each partition with the same CURE, then label, merging
across partitions by the same min-over-shrunk-reps rule. The sample runs
exactly that and asks the only question that matters, whether the
two-phase route lands where the direct run did.

The dry run: P1 = p1..p5 and P2 = p6..p10 in input order. Each
partitions internally to k=2, printing `partial {1,2,3}`, `partial
{4,5}`, `partial {6}`, `partial {7,8,9,10}`. The cross-partition phase
then merges greedily by rep distance: `cross {1,2,3}+{4,5} d2=4321/16`,
reunifying the arm, then `cross {1,2,3,4,5}+{6} d2=765`, the same 765
the direct run paid, and closes `partition_final
{1,2,3,4,5,6}|{7,8,9,10}`. The two routes agree member for member: on
this fixture the partition boundary p5|p6 splits exactly where the true
clusters part, and even where a boundary cut through a cluster the
labeling phase would stitch it back, which is the paper's design claim
and the check "ch35 partition-then-label reproduces the direct cure
result".

#listing("kdd/samples/src/Ch35/curepart.c", first: 243, last: 287,
  caption: [two partitions, two internal runs, two cross merges, one answer])

#diagram([partition, cluster each side, label across: the same final partition], length: 11pt, {
  let m = (x, y) => (x * 0.5, y * 0.5)
  cdraw.line((4.6, -0.5), (4.6, 26.5), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((2.2, 27.3), [P1 = p1..p5], size: 6.5pt)
  cdraw.content((15.0, 27.3), [P2 = p6..p10], size: 6.5pt)
  cdraw.line(m(0, 0), m(15, 0), stroke: luma(205))
  cdraw.line(m(27, 0), m(27, 15), stroke: luma(205))
  cdraw.rect(m(54, 42), m(62, 51), stroke: luma(205))
  let pts = ((0, 0), (6, 0), (15, 0), (27, 0), (27, 15), (27, 36),
    (54, 42), (62, 42), (54, 51), (62, 51))
  for p in pts {
    cdraw.circle(m(p.at(0), p.at(1)), radius: 0.4, fill: luma(70), stroke: none)
  }
  cdraw.circle(m(15, 0), radius: 2.2, stroke: luma(120))
  cdraw.circle(m(27, 7.5), radius: 2.2, stroke: luma(120))
  cdraw.circle(m(27, 36), radius: 1.4, stroke: luma(120))
  cdraw.circle(m(58, 46.5), radius: 3.4, stroke: luma(120))
  cdraw.content((1.6, 3.4), [{1,2,3}], size: 6pt)
  cdraw.content((16.8, 3.75), [{4,5}], size: 6pt)
  cdraw.content((15.9, 19.4), [{6}], size: 6pt)
  cdraw.content((34.6, 23.65), [{7,8,9,10}], size: 6pt)
  cdraw.line(m(15, 0), m(27, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.5, 5.1), [cross d2 = 4321\/16], size: 6pt)
  cdraw.line(m(27, 7.5), m(27, 36), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.2, 11), [cross d2 = 765], size: 6pt)
  cdraw.content((10.5, -2.0), [partition_final {1,2,3,4,5,6}|{7,8,9,10}, equals the direct run], size: 6.5pt)
})

== chameleon: the graph lane

Chameleon throws the coordinates away after one step: build a k nearest
neighbor graph, k = 2 under the union rule, an edge exists when either
endpoint lists the other among its two nearest, 2-NN ties broken by the
lower node index, then cluster on the graph alone. On the 6-point
fixture the graph has exactly 8 edges, and the planted clusters read
A = {p1,p2} and C = {p3,p4} interwoven along the line with B = {p5,p6}
floating above: p2 and p3 are mutual neighbors at $d^2 = 4$, while the
A to B edges cost $d^2 = 100$ each.

A merge is scored by two ratios. Relative interconnectivity, $"RI" =
"EC"_"ij" \/ (("EC"_i + "EC"_j)\/2)$, the cross-edge count against the
average internal count, and relative closeness, $"RC" = "Sbar"_"ij" \/
((n_i "Sbar"_i + n_j "Sbar"_j)\/(n_i + n_j))$, the average cross weight
against the size-weighted internal averages. The dry run: `pair A,C
EC=1,1,3 RI=3 RC=1 score=3`, `pair A,B EC=1,1,2 RI=2 RC=1 score=2`,
`pair B,C EC=1,1,0 RI=0 RC=1 score=0`. With unit weights every Sbar is
exactly 1, computed from the actual edge weights rather than assumed,
so RC = 1 on every pair and RI does all the discriminating: A and C
share three edges against one internal edge each, RI = 3, the
interwoven pair merges. The contrast row records the pinned caveat:
`merge_choice=A+C score=3 min_size_pref=A+B score=2`, because at three
clusters of size 2 a minimum-size preference is degenerate, all sizes
tie, so the contrast pits the RI-max choice against the deterministic
lowest-index-pair preference instead, and the sample prints both.

#listing("kdd/samples/src/Ch35/chameleon.c", first: 103, last: 124,
  caption: [the union kNN graph and its exactly 8 edges])

#listing("kdd/samples/src/Ch35/chameleon.c", first: 136, last: 194,
  caption: [EC counts, RI and RC as exact rationals, the three pair scores])

#diagram([eight edges, three pairs: interwoven A and C share three of them], length: 12pt, {
  let p = ((0, 0), (4, 0), (6, 0), (10, 0), (0, 10), (4, 10))
  let edges = ((0, 1, 16), (0, 2, 36), (0, 4, 100), (1, 2, 4), (1, 3, 36),
    (1, 5, 100), (2, 3, 16), (4, 5, 16))
  for e in edges {
    cdraw.line(p.at(e.at(0)), p.at(e.at(1)), stroke: luma(140))
  }
  let tags = ([p1], [p2], [p3], [p4], [p5], [p6])
  let off = ((-0.7, -1.1), (0.0, -1.1), (-0.6, 1.2), (0.9, -1.1), (-1.5, 0.4), (0.7, 0.9))
  for i in range(6) {
    cdraw.circle(p.at(i), radius: 0.35, fill: luma(70), stroke: none)
    cdraw.content((p.at(i).at(0) + off.at(i).at(0), p.at(i).at(1) + off.at(i).at(1)),
      tags.at(i), size: 6.5pt)
  }
  cdraw.content((5.0, 12.4), [A = {p1,p2}, C = {p3,p4} on the line, B = {p5,p6} above], size: 6pt)
  cdraw.content((5.0, -2.9), [union kNN graph, k = 2, exactly 8 edges], size: 6pt)
  cdraw.rect((16.0, 1.4), (27.6, 11.4), fill: luma(243), radius: 0.05)
  cdraw.content((21.8, 10.7), [pair   EC      RI   RC   score], size: 6pt)
  cdraw.content((21.8, 9.6), [A,C   1,1,3    3    1    3], size: 6pt)
  cdraw.content((21.8, 8.6), [A,B   1,1,2    2    1    2], size: 6pt)
  cdraw.content((21.8, 7.6), [B,C   1,1,0    0    1    0], size: 6pt)
  cdraw.content((21.8, 6.2), [RC = 1 exactly, unit weights], size: 6pt)
  cdraw.content((21.8, 5.2), [computed from the edges, not assumed], size: 6pt)
  cdraw.content((21.8, 3.8), [merge_choice = A+C, score 3], size: 6.5pt)
  cdraw.content((21.8, 2.8), [min-size degenerate at 2,2,2], size: 6pt)
  cdraw.content((21.8, 2.0), [contrast: A+B would score 2], size: 6pt)
})

sources: CURE, the shrinking recipe, c representatives, and the
partition-then-label design are Guha, Rastogi, Shim 1998, "CURE: an
efficient clustering algorithm for large databases", Proceedings of
SIGMOD 1998, ACM, pp. 73-84. Chameleon, the kNN graph construction, and
the RI and RC formulas as implemented are Karypis, Han, Kumar 1999,
"Chameleon: hierarchical clustering using dynamic modeling", IEEE
Computer 32(8):68-75. The fixture's calibrated window, the ordering
witness 4285/4 < 1233 against 765 < 14545/16, and every pinned row are
witnessed by kdd-contract-s7.md + playground/kdd-matrix/gen_s7.py, run
2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch35`, 10 + 30 + 8 + 21 checks in chapter 35 of the kdd suite.
