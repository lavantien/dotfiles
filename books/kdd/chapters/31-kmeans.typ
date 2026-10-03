// ch31, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 30 checks in kdd/samples/src/Ch31/kmeans.c (17) and elbow.c (13) or
// a banked provenance note: the iteration is Lloyd 1982, "Least squares
// quantization in PCM", IEEE Trans. Inf. Theory 28:129-137, the 1957 Bell
// Labs memo published 25 years late, with the streaming spelling from
// MacQueen 1967, and the largest-second-difference elbow from Thorndike
// 1953, Psychometrika 18:267. the tie rules quoted in the last facet are
// the committed go bridge books/kdd/capstone/internal/kddcore/kmeans.go
// verbatim, whose unit test TestLloydTieGoesToLowestIndex is the same TIE
// fixture printed below, so every ch31 row is D4-eligible (c/go byte
// parity by construction). all pinned values are witnessed by
// kdd-contract-s7.md + playground/kdd-matrix/gen_s7.py, run 2026-09-22,
// exit 0. determinism: D0 for every sse, seed, and label vector; D1
// dyadic for the TIE centroid (1/2,0) and sse 1/2, held as exact int64
// fractions, never doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= k-means

Two samples carry the chapter: `kmeans.c` runs Lloyd's iteration on a
planted 12-point fixture, a poisoned initialization of the same size, and
a 3-point tie micro-fixture, 17 checks, and `elbow.c` prices the optimal
k-clustering by exhaustive set-partition enumeration and reads the elbow
off the gains, 13 checks. The chapter makes 4 moves: the two-step pass
that alternates assignment and means, the exhaustive optimum the elbow
heuristic is guessing at, the local minimum a bad init buys, and the tie
rules that make every run reproducible byte for byte in Go. Distances are
the squared euclidean of #xref-to("kdd", "distance"), the elbow returns
in #xref-to("kdd", "validation") as one of two metrics that disagree, and
the tie rules are replayed by the bridge of #xref-to("kdd", "bridge").

== two moves, one pass

Lloyd's algorithm alternates two moves until nothing changes: assign
every point to the nearest centroid by squared euclidean distance, then
move every centroid to the mean of the points it holds. Each pass never
increases the objective, so the run settles into whatever basin the seeds
select, and nothing about the alternation promises the global optimum.
The fixture keeps the arithmetic checkable: F12 is 12 integer points in
three axis-aligned rectangles, planted cluster A the 4x4 square at the
origin, B the 4x4 square at (26,2), C the 4x8 rectangle at (14,20), and
the first three input points are one per cluster, so the seeded init
starts inside the answer.

The dry run: the seeds print as `seeds: (0,0),(24,0),(12,16)` and pass 1
assigns, printing `iter0 cents=(0,0),(24,0),(12,16) assign=012000111222
sse=288`. The vector reads point by point, p1 through p12, and lands A on
cluster 0 (p1, p4, p5, p6), B on cluster 1 (p2, p7, p8, p9), C on
cluster 2 (p3, p10, p11, p12). The 288 is the SSE against the seed
vertices: A and B contribute 64 each, corners at 0, 16, 16, 32 squared
distance, and C contributes 160 because its seed p3 is one corner of a
4x8 rectangle. The update move takes means and every centroid lands on an
integer: A collapses to (2,2), B to (26,2), C to (14,20). Pass 2
reassigns, nothing moves, and the run closes with `iter1
cents=(2,2),(26,2),(14,20) assign=012000111222 sse=144` then `final
iters=2 assign=012000111222`. The iters count includes the confirming
pass: pass 1 moved the assignment, pass 2 changed nothing, so 2. The 144
decomposes as 32 + 32 + 80, the 80 being C's own spread around its mean,
four copies of $2^2 + 4^2$, and that 80 is the number the k=3 row of the
elbow table below has to reproduce.

#listing("kdd/samples/src/Ch31/kmeans.c", first: 129, last: 190,
  caption: [lloyd with the pinned tie rules, exact fractions throughout])

#listing("kdd/samples/src/Ch31/kmeans.c", first: 232, last: 291,
  caption: [the F12 run: seeds, both traced passes, and the k=3 agreement])

#diagram([assignment then means: three seeds, one update, integer centroids], length: 10pt, {
  cdraw.line((-1.5, 0), (31, 0), stroke: luma(200))
  cdraw.line((0, -1.5), (0, 26.5), stroke: luma(200))
  cdraw.rect((0, 0), (4, 4), stroke: luma(190), radius: 0.05)
  cdraw.rect((24, 0), (28, 4), stroke: luma(190), radius: 0.05)
  cdraw.rect((12, 16), (16, 24), stroke: luma(190), radius: 0.05)
  let pts = ((0, 0), (24, 0), (12, 16), (4, 0), (0, 4), (4, 4), (28, 0),
    (24, 4), (28, 4), (16, 16), (12, 24), (16, 24))
  for p in pts {
    cdraw.circle(p, radius: 0.5, fill: luma(70), stroke: none)
  }
  let seeds = ((0, 0), (24, 0), (12, 16))
  let means = ((2, 2), (26, 2), (14, 20))
  for s in seeds {
    cdraw.circle(s, radius: 0.95, stroke: luma(70))
  }
  for m in means {
    cdraw.rect((m.at(0) - 0.55, m.at(1) - 0.55), (m.at(0) + 0.55,
      m.at(1) + 0.55), fill: luma(35), stroke: none, radius: 0.02)
  }
  for i in range(3) {
    cdraw.line(seeds.at(i), means.at(i),
      stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  }
  cdraw.content((-3.6, 2.0), [A], size: 7pt)
  cdraw.content((30.6, 2.0), [B], size: 7pt)
  cdraw.content((18.8, 20.0), [C], size: 7pt)
  cdraw.content((-1.9, 1.8), [p1], size: 6pt)
  cdraw.content((24.0, -2.0), [p2], size: 6pt)
  cdraw.content((10.0, 17.4), [p3], size: 6pt)
  cdraw.rect((-1.2, 21.0), (11.0, 26.2), fill: luma(243), radius: 0.05)
  cdraw.content((4.9, 25.4), [open circle = seed, square = mean], size: 6pt)
  cdraw.content((4.9, 24.5), [means (2,2), (26,2), (14,20)], size: 6pt)
  cdraw.content((4.9, 23.6), [sse 288 at seeds $arrow.r$ 144 at means], size: 6pt)
  cdraw.content((4.9, 22.7), [pass 2 moves nothing, iters=2], size: 6pt)
})

== the elbow against the exhaustive optimum

The elbow heuristic reads k off a table of SSE values, and the table worth
reading is the optimal one: for each k the minimum SSE over all
k-partitions, not whatever Lloyd happens to reach. `elbow.c` computes it
exactly by exhaustive set-partition enumeration, on the order of 700k
states across $k = 1..4$ with no heap, scoring each candidate through the
identity $"SSE" = "totsq" - sum_c (s_x(c)^2 + s_y(c)^2)\/n_c$ with totsq
5280, so every comparison is an exact integer cross-multiply. The closed
form anchors the first row, $3552 - 168^2\/12 + 1728 - 96^2\/12 = 2160$,
the total scatter 5280 splitting as $3552 + 1728$ per axis with sums
$(168, 96)$.

The dry run: the table prints `k=1 sse=2160`, `k=2 sse=1080`, `k=3
sse=144`, `k=4 sse=80`, then `gains 1080,936,64`, `d2 144,872`, and
`elbow=3 kneedle_2b_gt_a_plus_c=true`. The pinned rule is the largest
second difference over k=3,4: $1080 - 936 = 144$ against $936 - 64 =
872$, so the elbow is $2 + 1 = 3$, and the kneedle-style crosscheck
agrees, $2 dot 936 = 1872 > 1080 + 64$. Two facts sit behind the table.
The k=2 optimum is a tie, {B} against $A union C$ scoring the same 1080
as {A} against $B union C$: $A union C$ has mean (8,11) and SSE 1048,
plus B's 32. The enumeration under canonical first-use ordering records
the {B} side first, and the sample's check pins the tie explicitly rather
than letting one witness pose as the optimum. And k=4 spends its 64 to
split C into the pairs {p3,p10} and {p11,p12}, C's 80 dropping to 16. The
agreement row closes the loop with the previous facet: the exhaustive k=3
optimum is 144, the same number Lloyd's iter1 printed from the planted
init, and both samples assert it, "ch31 F12 lloyd from the pinned init
attains the k=3 optimum 144 (elbow.c proves it exhaustive)" in `kmeans.c`
and "ch31 D4 agreement: exhaustive k=3 optimum 144 equals Lloyd's pinned
iter1 sse in kmeans.c" in `elbow.c`.

#listing("kdd/samples/src/Ch31/elbow.c", first: 83, last: 139,
  caption: [exhaustive set-partition enumeration with incremental sums])

#listing("kdd/samples/src/Ch31/elbow.c", first: 155, last: 189,
  caption: [the table, the gains, the second differences, the elbow rule])

#diagram([the optimal sse curve and the elbow at the largest second difference], length: 13pt, {
  let xs = (2.0, 6.4, 10.8, 15.2)
  let ys = (9.3, 6.6, 2.4, 1.8)
  let vals = ([2160], [1080], [144], [80])
  cdraw.line((1.0, 0.0), (16.4, 0.0), stroke: luma(200))
  for i in range(4) {
    cdraw.content((xs.at(i), -0.9), [k=#(i + 1)], size: 6.5pt)
    cdraw.circle((xs.at(i), ys.at(i)), radius: 0.35, fill: luma(70), stroke: none)
  }
  for i in range(3) {
    cdraw.line((xs.at(i), ys.at(i)), (xs.at(i + 1), ys.at(i + 1)), stroke: luma(120))
  }
  cdraw.content((2.0, 10.2), [2160], size: 6.5pt)
  cdraw.content((6.4, 7.5), [1080], size: 6.5pt)
  cdraw.content((10.8, 3.8), [144], size: 6.5pt)
  cdraw.content((15.2, 2.7), [80], size: 6.5pt)
  cdraw.content((4.2, 8.7), [gain 1080], size: 6pt)
  cdraw.content((8.6, 5.4), [gain 936], size: 6pt)
  cdraw.content((12.6, 3.4), [gain 64], size: 6pt)
  cdraw.circle((10.8, 2.4), radius: 0.8, stroke: rgb("#8B0000"))
  cdraw.content((13.4, 1.2), [elbow], size: 6.5pt)
  cdraw.content((8.7, -2.3), [d2 144, 872: the second difference peaks at k=3], size: 6pt)
  cdraw.content((8.7, -3.3), [kneedle crosscheck 2 dot 936 > 1080 + 64 holds], size: 6pt)
  cdraw.content((8.7, -4.3), [heights sqrt-scaled for the shape, values exact], size: 5.5pt)
})

#callout("note", "exhaustive is a fixture luxury, chain dp is the 1d luxury", [
  Enumerating $S(12,k)$ is only thinkable because the fixture is 12
  points; one more rectangle and the table needs a different algorithm.
  When the data is 1D and sorted, the optimal k-partition is contiguous
  and a chain DP prices exact k-means in quadratic time, which is exactly
  the trade #xref-to("icpc", "y2017") problem F makes: exact k-means is
  priced out in favor of the chain DP because the points sit on a line.
  In 2D the same enumeration is NP-hard in general, and the elbow table
  is the heuristic standing in for the optimum the way Lloyd stands in
  for the argmin partition.
])

== bad init buys a split local minimum

The second fixture plants the failure. F12b is again 12 points in three
rectangles, but the first two sit close: planted A = {p1,p2,p4,p5} the
6x6 square at the origin, B = {p3,p6,p7,p8} the square at (27,3), C =
{p9,p10,p11,p12} at (33,15), and the input order puts p1, p2, p3 first,
so the seeds are two points of A plus one of B: `seeds:
(0,0),(6,0),(24,0)`.

The dry run: pass 1 prints `iter0 cents=(0,0),(6,0),(24,0)
assign=012012222222 sse=1512`. Cluster 0 takes {p1,p4}, cluster 1 takes
{p2,p5}, and cluster 2 absorbs the other eight points, all of B and all of
C. The update splits A in half, means (0,3) and (6,3), and drags cluster
2's mean to (30,9): `iter1 cents=(0,3),(6,3),(30,9) assign=012012222222
sse=540`. The 540 decomposes as 18 + 18 + 504: each half-A cluster holds
two points at squared distance 9 from its mean, and the 8-point cluster
pays for lumping two rectangles together. The planted partition,
recomputed in the sample from its integer means (3,3), (27,3), (33,15),
scores `planted_sse=216 local_min_worse_by=324`. Lloyd is parked: the
pass is a descent, each move only lowers or holds the SSE, so no further
pass escapes a local minimum, and the run sits 324 above the answer
forever.

#listing("kdd/samples/src/Ch31/kmeans.c", first: 333, last: 366,
  caption: [F12b: the split-A local minimum row and the planted 216 against 540])

#diagram([the same 12 shapes, two answers: planted rectangles against lloyd's hulls], length: 9pt, {
  cdraw.line((-2, 0), (38.5, 0), stroke: luma(210))
  cdraw.rect((0, 0), (6, 6), stroke: luma(60), radius: 0.05)
  cdraw.rect((24, 0), (30, 6), stroke: luma(60), radius: 0.05)
  cdraw.rect((30, 12), (36, 18), stroke: luma(60), radius: 0.05)
  cdraw.line((24, 0), (30, 0), (36, 12), (36, 18), (30, 18), (24, 6),
    close: true, stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  cdraw.circle((0, 3), radius: 1.7, stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  cdraw.circle((6, 3), radius: 1.7, stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  let pts = ((0, 0), (6, 0), (24, 0), (0, 6), (6, 6), (30, 0), (24, 6),
    (30, 6), (30, 12), (36, 12), (30, 18), (36, 18))
  for p in pts {
    cdraw.circle(p, radius: 0.55, fill: luma(70), stroke: none)
  }
  for s in ((0, 0), (6, 0), (24, 0)) {
    cdraw.circle(s, radius: 1.05, stroke: luma(70))
  }
  cdraw.content((-2.6, -2.0), [p1], size: 6pt)
  cdraw.content((6.0, -2.0), [p2], size: 6pt)
  cdraw.content((24.0, -2.0), [p3], size: 6pt)
  cdraw.rect((-1.5, 13.2), (18.5, 19.6), fill: luma(243), radius: 0.05)
  cdraw.content((8.5, 18.7), [solid rects: planted A, B, C, sse 216], size: 6pt)
  cdraw.content((8.5, 17.8), [dashed: lloyd k=2 local minimum, sse 540], size: 6pt)
  cdraw.content((8.5, 16.9), [A split in half, B and C lumped, means], size: 6pt)
  cdraw.content((8.5, 16.0), [(0,3), (6,3), (30,9), worse by 324], size: 6pt)
  cdraw.content((8.5, 15.1), [open circles: seeds p1, p2, p3], size: 6pt)
})

#callout("pitfall", "a descent cannot regret its seeds", [
  The 540-versus-216 gap is not bad luck in the arithmetic, it is the
  algorithm's contract: each Lloyd move is a conditional improvement, so
  the run can only ratchet down inside the basin the seeds picked. The
  standard remedies attack the init, not the pass: restart from many
  different seeds and keep the best SSE, or seed preferentially far
  apart, the k-means++ sketch of Arthur and Vassilvitskii 2007. Nothing
  restarts the pass itself out of a local minimum, which is why the
  fixtures pin both the basin and its price: 324 is what this chapter's
  seeds cost.
])

== ties, exact halves, and the go bridge

Every tie in the assignment step is a fork in the run, and the last
fixture pins the fork. The rules are the committed Go bridge's, verbatim:
init from the first k distinct points in input order, assignment ties go
to the lowest cluster index, a cluster left empty keeps its previous
centroid (unreachable from point-seeded inits on these fixtures, but it
is the rule), stop when a pass changes nothing with iters counting the
confirming pass, and maxIter 100 never binds here.

The dry run: the TIE fixture is three collinear points p1=(0,0),
p2=(2,0), p3=(1,0), the first two distinct points seed, and p3 sits
exactly 1 from each seed. The sample prints `tie p3 d0=1 d1=1 joins=0`,
cluster 0 winning the tie. The update makes cluster 0's mean (1/2,0) and
the run prints `iter1 cents=(1/2,0),(2,0) assign=010 sse=1/2` then
`final iters=2 assign=010`. The 1/2 is exact, two points at squared
distance 1/4 from their mean, held as an int64 fraction: this is the
dyadic case where a double would coincidentally be exact, and the
fraction makes the byte comparison the law rather than an accident. The
fixture is also the D4 witness: the bridge's own test
`TestLloydTieGoesToLowestIndex` replays these exact bytes in Go, so the C
pin and the Go pin are one fixture, and #xref-to("kdd", "bridge") walks
the full parity chain this chapter's rows ride on.

#listing("kdd/samples/src/Ch31/kmeans.c", first: 9, last: 16,
  caption: [the tie rules as pinned, quoted from the go bridge])

#listing("kdd/samples/src/Ch31/kmeans.c", first: 368, last: 391,
  caption: [the TIE fixture: one equal-distance fork, resolved to cluster 0])

#diagram([one tie, one rule: the lowest cluster index wins], length: 13pt, {
  cdraw.line((1.5, 4.0), (16.5, 4.0), stroke: luma(170))
  let p1 = (3.0, 4.0)
  let p3 = (8.0, 4.0)
  let p2 = (13.0, 4.0)
  for p in (p1, p3, p2) {
    cdraw.circle(p, radius: 0.4, fill: luma(70), stroke: none)
  }
  cdraw.content((3.0, 3.0), [p1], size: 6.5pt)
  cdraw.content((8.0, 3.0), [p3], size: 6.5pt)
  cdraw.content((13.0, 3.0), [p2], size: 6.5pt)
  cdraw.line((8.0, 4.4), (5.5, 6.8), (3.0, 4.4),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((8.0, 4.4), (10.5, 6.8), (13.0, 4.4),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((5.5, 7.4), [d0 = 1], size: 6.5pt)
  cdraw.content((10.5, 7.4), [d1 = 1], size: 6.5pt)
  cdraw.line((7.5, 3.5), (6.4, 2.5), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.6, 2.0), (9.4, 2.0), stroke: luma(100))
  cdraw.line((2.6, 2.0), (2.6, 2.4), stroke: luma(100))
  cdraw.line((9.4, 2.0), (9.4, 2.4), stroke: luma(100))
  cdraw.content((6.0, 1.2), [cluster 0 = {p1,p3}, mean (1/2,0)], size: 6pt)
  cdraw.line((12.3, 2.0), (13.7, 2.0), stroke: luma(100))
  cdraw.line((12.3, 2.0), (12.3, 2.4), stroke: luma(100))
  cdraw.line((13.7, 2.0), (13.7, 2.4), stroke: luma(100))
  cdraw.content((13.6, 1.2), [cluster 1 = {p2}], size: 6pt)
  cdraw.rect((0.8, 8.4), (10.0, 11.6), fill: luma(243), radius: 0.05)
  cdraw.content((5.4, 10.9), [pass 1: p3 $arrow.r$ 0 (moved)], size: 6pt)
  cdraw.content((5.4, 10.1), [update: c0 mean (1\/2,0), sse 1\/2], size: 6pt)
  cdraw.content((5.4, 9.3), [pass 2: no change (confirming)], size: 6pt)
  cdraw.content((5.4, 8.5), [iters = 2, assign = 010], size: 6pt)
})

sources: the iteration is Lloyd 1982, "Least squares quantization in
PCM", IEEE Trans. Inf. Theory 28:129-137, the 1957 Bell Labs memorandum
published 25 years later, with the streaming spelling from MacQueen
1967; the largest-second-difference elbow with the kneedle-style
crosscheck is Thorndike 1953, Psychometrika 18:267, and the restart
remedy named in the pitfall is Arthur and Vassilvitskii, "k-means++: the
advantages of careful seeding", SODA 2007. The tie rules and the
iters-counts-the-confirming-pass semantics are pinned by
kdd-contract-s7.md as the committed Go bridge
books/kdd/capstone/internal/kddcore/kmeans.go implements them, witnessed
by playground/kdd-matrix/gen_s7.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch31`, 17 + 13 checks in
chapter 31 of the kdd suite.
