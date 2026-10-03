// ch32, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 30 checks in kdd/samples/src/Ch32/linkage.c or a banked provenance
// note: the recurrence is Lance & Williams 1967, "A general theory of
// classificatory sorting strategies: 1. hierarchical systems", Computer
// Journal 9:373-380, and the linkage taxonomy and dendrogram reading are
// Kaufman & Rousseeuw 1990, "Finding Groups in Data", Wiley. the D32
// matrix is purpose-built by seeded local search (probe seed 42) with
// three properties the runs lean on: all 20 triangle inequalities hold,
// no merge decision ties in any of the three linkages, and the three
// dendrogram shapes differ pairwise. all pinned values are witnessed by
// kdd-contract-s7.md + playground/kdd-matrix/gen_s7.py, run 2026-09-22,
// exit 0. determinism: D0 throughout, every height a reduced int64
// fraction pair (integers printed bare), never doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= hierarchical clustering

One sample carries the chapter: `linkage.c` runs single, complete, and
average linkage on one 6x6 integer distance matrix, then recomputes the
hardest merge height by the Lance-Williams recurrence and by hand, 30
checks. The chapter makes 4 moves: the dissimilarity matrix as the whole
input and the metric precondition, the min and max extremes that chain or
drag, the mean in between with its exact fractions, and the recurrence
that keeps the merge loop honest. The matrix is the proximity data of
#xref-to("kdd", "distance") with the points thrown away, the flat
partitions of #xref-to("kdd", "kmeans") come out of this tree by cutting
it, and #xref-to("kdd", "cure") keeps the agglomerative engine and swaps
the distance definition to survive non-convex clusters.

== one matrix, six leaves, no ties

Agglomerative clustering starts with every point its own cluster and
merges the closest pair until one cluster remains. The only input is the
matrix: the algorithm never sees coordinates, so everything downstream
hangs on six rows of integers. The precondition is that those integers
behave like distances, and the sample checks all of it: `metric_ok=true`
asserts all 20 triangle inequalities, the $binom(6, 3)$ triples with all
three inequalities each. Two triples close with equality, $d_13 = 8 =
3 + 5 = d_12 + d_23$ and $d_14 = 15 = 8 + 7 = d_13 + d_34$, so the
quadruple 1, 2, 3, 4 adds up like positions 0, 3, 8, 15 on a line, and
$d_24 = 12$, $d_23 = 5$ fall out of the same arithmetic. A degenerate
triangle is still a triangle: the checker accepts equality, and single
linkage will exploit that collinearity in the next facet.

The fixture was searched, not drawn: a seeded local search over integer
matrices (seed 42) with three demands, metric, no ties at any merge
decision in any of the three linkages, and three pairwise-distinct
dendrogram shapes. The no-ties property is what makes every trace below
data-determined rather than rule-determined: the merge loop does carry a
tie rule, lowest pair of minimum members, and the check "ch32 no merge
decision ties in any of the three linkages" pins that it never fires.

The dry run: the matrix prints row by row, `D1: 0 3 8 15 13 14` through
`D6: 14 12 12 10 4 0`, then `metric_ok=true`. The first two merges are
common to all three runs because at that stage clusters are single points
and every linkage reads the same cell: `merge {1}+{2}@3`, the unique
matrix minimum $d_12 = 3$, then `merge {5}+{6}@4`, $d_56 = 4$. After two
merges the cluster-to-cluster question begins, and the three linkages
part ways.

#listing("kdd/samples/src/Ch32/linkage.c", first: 212, last: 240,
  caption: [the matrix rows and the 20-triangle metric gate])

#diagram([the matrix is the whole input; two cells merge first in every run], length: 12pt, {
  let vals = ((0, 3, 8, 15, 13, 14), (3, 0, 5, 12, 12, 12), (8, 5, 0, 7, 13, 12),
    (15, 12, 7, 0, 8, 10), (13, 12, 13, 8, 0, 4), (14, 12, 12, 10, 4, 0))
  let cell = 1.7
  let ox = 2.4
  for i in range(6) {
    cdraw.content((ox - 1.0, -(i + 0.5) * cell), [#(i + 1)], size: 6.5pt)
    cdraw.content((ox + (i + 0.5) * cell, 1.0), [#(i + 1)], size: 6.5pt)
    for j in range(6) {
      let v = vals.at(i).at(j)
      let hot = (i == 0 and j == 1) or (i == 4 and j == 5)
      cdraw.rect((ox + j * cell, -(i + 1) * cell),
        (ox + (j + 1) * cell, -i * cell),
        fill: if i == j { luma(228) } else { luma(255 - v * 5) },
        stroke: if hot { 1.2pt + rgb("#8B0000") } else { 0.4pt + luma(210) })
      cdraw.content((ox + (j + 0.5) * cell, -(i + 0.5) * cell), [#v],
        size: 6pt)
    }
  }
  cdraw.content((ox + 3 * cell, 2.0), [darker = farther], size: 6pt)
  cdraw.content((16.2, -1.0), [d(1,2) = 3: first merge in all three runs], size: 6pt)
  cdraw.content((16.2, -2.2), [d(5,6) = 4: second merge in all three], size: 6pt)
  cdraw.content((16.2, -3.4), [metric_ok: 20 triangles checked], size: 6pt)
  cdraw.content((16.2, -4.6), [d13 = 3+5, d14 = 8+7: equality], size: 6pt)
  cdraw.content((16.2, -5.8), [holds, 1-2-3-4 act collinear], size: 6pt)
})

== single chains, complete drags

A linkage is a rule for extending point distance to cluster distance.
Single takes the minimum over cross pairs, so a cluster grows by its
nearest neighbor; complete takes the maximum, so nothing merges until
every cross pair is close. On the collinear run 1-2-3-4 the two rules
could not disagree more.

The dry run, single first: after the shared prefix the trace continues
`single merge {1,2}+{3}@5` (the min over cross pairs {8, 5} is $d_23$),
`single merge {1,2,3}+{4}@7` ($d_34$), and `single merge
{1,2,3,4}+{5,6}@8` ($d_45$, the min over eight cross pairs). Each leaf
splices onto the chain at its distance to the chain's nearest endpoint,
and the final merge happens at 8 even though the far pair (1,6) sits 14
apart. The shape string prints `single shape ((((1 2) 3) 4) (5 6))`, a
caterpillar. Complete diverges at the third merge: the candidates are
$d({1,2},{3}) = max(8,5) = 8$ against $d({3},{4}) = 7$, so `complete
merge {3}+{4}@7` fires instead, then `complete merge {3,4}+{5,6}@13` (the
max over $13, 8, 12, 10$), and the run closes at the full diameter
`complete merge {1,2}+{3,4,5,6}@15`, which is $d_14$. The shape prints
`complete shape ((1 2) ((3 4) (5 6)))`, balanced. Same matrix, same
prefix, two different trees: single reads the nearest crossing, complete
reads the farthest, and the check "ch32 the three dendrogram shapes
differ pairwise" already counts this one in.

#listing("kdd/samples/src/Ch32/linkage.c", first: 79, last: 142,
  caption: [the fixture and cludist: min, max, or mean over the cross pairs])

#diagram([two trees from one prefix: min chains into a caterpillar, max balances], length: 11.5pt, {
  let leaf = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
  for i in range(6) {
    cdraw.content((leaf.at(i), -0.9), [#(i + 1)], size: 6.5pt)
    cdraw.content((leaf.at(i) + 10.5, -0.9), [#(i + 1)], size: 6.5pt)
  }
  cdraw.content((3.5, 9.3), [single, heights /2], size: 6.5pt)
  cdraw.content((14.0, 9.3), [complete, heights /2], size: 6.5pt)
  // single panel
  cdraw.line((1.0, 0), (1.0, 1.5), stroke: luma(80))
  cdraw.line((2.0, 0), (2.0, 1.5), stroke: luma(80))
  cdraw.line((1.0, 1.5), (2.0, 1.5), stroke: luma(80))
  cdraw.content((2.35, 1.5), [3], size: 6pt)
  cdraw.line((1.5, 1.5), (1.5, 2.5), stroke: luma(80))
  cdraw.line((3.0, 0), (3.0, 2.5), stroke: luma(80))
  cdraw.line((1.5, 2.5), (3.0, 2.5), stroke: luma(80))
  cdraw.content((3.35, 2.5), [5], size: 6pt)
  cdraw.line((2.0, 2.5), (2.0, 3.5), stroke: luma(80))
  cdraw.line((4.0, 0), (4.0, 3.5), stroke: luma(80))
  cdraw.line((2.0, 3.5), (4.0, 3.5), stroke: luma(80))
  cdraw.content((4.35, 3.5), [7], size: 6pt)
  cdraw.line((5.0, 0), (5.0, 2.0), stroke: luma(80))
  cdraw.line((6.0, 0), (6.0, 2.0), stroke: luma(80))
  cdraw.line((5.0, 2.0), (6.0, 2.0), stroke: luma(80))
  cdraw.content((6.35, 2.0), [4], size: 6pt)
  cdraw.line((2.5, 3.5), (2.5, 4.0), stroke: luma(80))
  cdraw.line((5.5, 2.0), (5.5, 4.0), stroke: luma(80))
  cdraw.line((2.5, 4.0), (5.5, 4.0), stroke: luma(80))
  cdraw.content((5.85, 4.0), [8], size: 6pt)
  cdraw.content((3.5, 7.6), [((((1 2) 3) 4) (5 6))], size: 6.5pt)
  // complete panel, +10.5 in x
  cdraw.line((11.5, 0), (11.5, 1.5), stroke: luma(80))
  cdraw.line((12.5, 0), (12.5, 1.5), stroke: luma(80))
  cdraw.line((11.5, 1.5), (12.5, 1.5), stroke: luma(80))
  cdraw.content((12.85, 1.5), [3], size: 6pt)
  cdraw.line((15.5, 0), (15.5, 2.0), stroke: luma(80))
  cdraw.line((16.5, 0), (16.5, 2.0), stroke: luma(80))
  cdraw.line((15.5, 2.0), (16.5, 2.0), stroke: luma(80))
  cdraw.content((16.85, 2.0), [4], size: 6pt)
  cdraw.line((13.5, 0), (13.5, 3.5), stroke: luma(80))
  cdraw.line((14.5, 0), (14.5, 3.5), stroke: luma(80))
  cdraw.line((13.5, 3.5), (14.5, 3.5), stroke: luma(80))
  cdraw.content((14.85, 3.5), [7], size: 6pt)
  cdraw.line((14.0, 3.5), (14.0, 6.5), stroke: luma(80))
  cdraw.line((16.0, 2.0), (16.0, 6.5), stroke: luma(80))
  cdraw.line((14.0, 6.5), (16.0, 6.5), stroke: luma(80))
  cdraw.content((16.35, 6.5), [13], size: 6pt)
  cdraw.line((12.0, 1.5), (12.0, 7.5), stroke: luma(80))
  cdraw.line((15.0, 6.5), (15.0, 7.5), stroke: luma(80))
  cdraw.line((12.0, 7.5), (15.0, 7.5), stroke: luma(80))
  cdraw.content((15.35, 7.5), [15], size: 6pt)
  cdraw.content((14.0, 8.4), [((1 2) ((3 4) (5 6)))], size: 6.5pt)
  cdraw.content((9.0, -2.2), [single's last merge at 8 is the nearest crossing; complete's at 15 is the diameter], size: 6pt)
})

== average and unavoidable thirds

Average linkage takes the mean over cross pairs, the compromise that
keeps every distance in play. Its price is arithmetic: means of integers
are fractions, and at six points the last merge averages $3 times 3 = 9$
pairs, so thirds arrive.

The dry run: the shared prefix prints `average merge {1}+{2}@3` and
`average merge {5}+{6}@4`, then the mean of cross pair {8, 5} wins the
third merge, `average merge {1,2}+{3}@13/2`, beating $d_34 = 7$ and the
{4} to {5,6} mean of 9. Fourth: `average merge {4}+{5,6}@9`, the mean of
{8, 10}, beating $d({1,2,3},{4}) = 34\/3$ (from 15, 12, 7) and
$d({1,2,3},{5,6}) = 38\/3$ (from 13, 12, 13, 14, 12, 12). The run closes with
`average merge {1,2,3}+{4,5,6}@110/9`, the mean over all nine cross
pairs, and the shape prints `average shape (((1 2) 3) (4 (5 6)))`, the
third distinct tree. The 110/9 is pinned after a ruled-out alternative: a
fully dyadic average trace needs merge sizes that avoid 3+3 at six
points, and that conflicts with the three-distinct-shapes requirement,
a 400k-step seeded search found no matrix that delivers both. So the
final height is an exact reduced fraction, compared as an int64 pair,
and the check "ch32 average final height is the exact fraction 110/9
(thirds)" pins the denominator.

#listing("kdd/samples/src/Ch32/linkage.c", first: 144, last: 210,
  caption: [the merge loop: pick the minimum pair, tie to lowest members, record])

#diagram([average keeps every distance in play and pays in thirds], length: 12pt, {
  for i in range(6) {
    cdraw.content((1.0 * (i + 1), -0.9), [#(i + 1)], size: 6.5pt)
  }
  cdraw.line((1, 0), (1, 1.2), stroke: luma(80))
  cdraw.line((2, 0), (2, 1.2), stroke: luma(80))
  cdraw.line((1, 1.2), (2, 1.2), stroke: luma(80))
  cdraw.content((2.4, 1.2), [3], size: 6pt)
  cdraw.line((5, 0), (5, 1.6), stroke: luma(80))
  cdraw.line((6, 0), (6, 1.6), stroke: luma(80))
  cdraw.line((5, 1.6), (6, 1.6), stroke: luma(80))
  cdraw.content((6.4, 1.6), [4], size: 6pt)
  cdraw.line((1.5, 1.2), (1.5, 2.6), stroke: luma(80))
  cdraw.line((3, 0), (3, 2.6), stroke: luma(80))
  cdraw.line((1.5, 2.6), (3, 2.6), stroke: luma(80))
  cdraw.content((2.7, 3.0), [13\/2], size: 6pt)
  cdraw.line((4, 0), (4, 3.6), stroke: luma(80))
  cdraw.line((5.5, 1.6), (5.5, 3.6), stroke: luma(80))
  cdraw.line((4, 3.6), (5.5, 3.6), stroke: luma(80))
  cdraw.content((5.9, 3.6), [9], size: 6pt)
  cdraw.line((2, 2.6), (2, 4.9), stroke: luma(80))
  cdraw.line((4.75, 3.6), (4.75, 4.9), stroke: luma(80))
  cdraw.line((2, 4.9), (4.75, 4.9), stroke: (paint: rgb("#8B0000")))
  cdraw.content((5.15, 4.9), [110\/9], size: 6.5pt)
  cdraw.content((3.5, 6.4), [(((1 2) 3) (4 (5 6)))], size: 6.5pt)
  cdraw.rect((9.0, 3.2), (19.6, 6.6), fill: luma(243), radius: 0.05)
  cdraw.content((14.3, 6.0), [the final mean runs over 9 pairs], size: 6pt)
  cdraw.content((14.3, 5.2), [15+12+7+13+12+13+14+12+12 = 110], size: 6pt)
  cdraw.content((14.3, 4.4), [thirds are structural at 3+3], size: 6pt)
  cdraw.content((14.3, 3.6), [dyadic needs sizes avoiding 3+3,], size: 6pt)
  cdraw.content((14.3, 2.9), [which kills distinct shapes], size: 6pt)
})

#callout("note", "one recurrence family runs all three", [
  Single, complete, and average are three parameter settings of one
  update formula: the Lance-Williams recurrence expresses the distance
  from a newly merged cluster to any survivor through the two old
  distances and the cluster sizes, with single and complete sitting at
  the $alpha = plus.minus 1\/2$, $beta = 0$ corners and average at
  $alpha_a = n_a\/(n_a + n_b)$, $alpha_b = n_b\/(n_a + n_b)$. That is
  why one merge loop in the sample serves all three runs, and why the
  next facet can verify the hardest row from two old distances alone.
])

== lance-williams, two ways to the same fraction

Rescanning every cross pair at every merge is quadratic bookkeeping. The
recurrence for average linkage is linear in the two old distances:
$d(A union B, C) = (n_a d(A,C) + n_b d(B,C))\/(n_a + n_b)$, so the loop
updates each surviving cluster's distance to the new one from two
numbers. The sample witnesses the hardest row both ways.

The dry run: form {4,5,6} first. To the survivor {1,2,3}, the singleton
{4} sits at $34\/3$ (the mean of 15, 12, 7) and the pair {5,6} at
$38\/3$ (the mean of 13, 12, 13, 14, 12, 12), so the recurrence prints
`lw d({1,2,3},{4,5,6})=(2*38/3+1*34/3)/3=110/9`, the size-2 term first
exactly as the sheet pins it, $(76 + 34)\/9 = 110\/9$. The direct scan
sums the nine cross pairs to 110 and prints `lw direct=110/9 equal=true`.
Both routes land on the same reduced fraction, which is the whole claim:
the recurrence is not an approximation of the mean, it is the mean
rearranged, and because both sides are exact int64 pairs the equality
check is a comparison, not a tolerance. That is the D0 discipline every
height in this chapter rides on.

#listing("kdd/samples/src/Ch32/linkage.c", first: 273, last: 305,
  caption: [the recurrence recompute and the direct mean, equal as fractions])

#diagram([the same fraction from two old distances or nine cross pairs], length: 12pt, {
  cdraw.content((5.2, 9.6), [d(A union B, C) = (n_a d(A,C) + n_b d(B,C))\/(n_a + n_b)], size: 6.5pt)
  cdraw.rect((0.4, 6.4), (3.4, 7.6), fill: luma(246), radius: 0.05)
  cdraw.content((1.9, 7.0), [{4}: mean 34\/3], size: 6pt)
  cdraw.rect((0.4, 4.4), (3.4, 5.6), fill: luma(246), radius: 0.05)
  cdraw.content((1.9, 5.0), [{5,6}: mean 38\/3], size: 6pt)
  cdraw.rect((4.6, 5.4), (7.6, 6.6), fill: luma(246), radius: 0.05)
  cdraw.content((6.1, 6.0), [{1,2,3}], size: 6.5pt)
  cdraw.line((3.4, 7.0), (6.1, 6.6), stroke: luma(150))
  cdraw.line((3.4, 5.0), (6.1, 5.4), stroke: luma(150))
  cdraw.content((4.0, 7.6), [x1], size: 6pt)
  cdraw.content((4.0, 4.2), [x2], size: 6pt)
  cdraw.rect((1.0, 1.6), (7.0, 3.0), fill: luma(232), radius: 0.05)
  cdraw.content((4.0, 2.55), [(2 dot 38\/3 + 1 dot 34\/3)\/3], size: 6.5pt)
  cdraw.content((4.0, 1.95), "= 110/9", size: 6.5pt)
  cdraw.line((4.0, 4.4), (4.0, 3.0), stroke: luma(120), mark: (end: ">"))
  let gx = (10.4, 12.0, 13.6)
  let gy = (8.2, 6.6, 5.0)
  let grid = ((15, 13, 14), (12, 12, 12), (7, 13, 12))
  let cols = ([4], [5], [6])
  let rows = ([1], [2], [3])
  for j in range(3) {
    cdraw.content((gx.at(j), 8.9), cols.at(j), size: 6pt)
  }
  for i in range(3) {
    cdraw.content((9.6, gy.at(i)), rows.at(i), size: 6pt)
    for j in range(3) {
      cdraw.rect((gx.at(j) - 0.7, gy.at(i) - 0.6), (gx.at(j) + 0.7, gy.at(i) + 0.6),
        fill: luma(246), radius: 0.03)
      cdraw.content((gx.at(j), gy.at(i)), [#grid.at(i).at(j)], size: 6.5pt)
    }
  }
  cdraw.content((12.0, 4.0), [sum 110 over 9 pairs, /9 = 110\/9], size: 6.5pt)
  cdraw.rect((9.2, 1.6), (14.8, 3.0), fill: luma(232), radius: 0.05)
  cdraw.content((12.0, 2.3), [equal = true, exact fractions], size: 6.5pt)
  cdraw.line((9.2, 2.3), (7.0, 2.3), stroke: luma(120), mark: (end: ">"))
})

sources: the recurrence and its parameter family are Lance & Williams
1967, "A general theory of classificatory sorting strategies: 1.
hierarchical systems", Computer Journal 9:373-380, and the linkage
taxonomy with the dendrogram reading follows Kaufman & Rousseeuw 1990,
"Finding Groups in Data: An Introduction to Cluster Analysis", Wiley.
The D32 matrix is purpose-built by seeded local search, probe seed 42,
with metric, no-ties, and three-distinct-shapes asserted in the sample,
and every pinned row is witnessed by kdd-contract-s7.md +
playground/kdd-matrix/gen_s7.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch32`, 30 checks in chapter 32 of the kdd
suite.
