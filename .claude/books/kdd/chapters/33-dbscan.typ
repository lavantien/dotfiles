// ch33, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 39 checks in kdd/samples/src/Ch33/dbscan.c or a banked provenance
// note: the algorithm is Ester, Kriegel, Sander, Xu, KDD-96, "A
// density-based algorithm for discovering clusters in large spatial
// databases with noise", and the minpts convention (neighbors EXCLUDING
// self, core iff |N(p)| >= minpts) is the scikit-learn DBSCAN convention,
// pinned by the contract against
// scikit-learn.org/stable/modules/generated/sklearn.cluster.DBSCAN.html.
// the fixture is purpose-built: all relevant comparisons are integer
// squared distances, the closed ball matters at three exactly-at-eps
// pairs, and every classification is hand-derivable. all pinned values
// are witnessed by kdd-contract-s7.md + playground/kdd-matrix/gen_s7.py,
// run 2026-09-22, exit 0. determinism: D0 throughout, integer d2 only,
// no square roots anywhere.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= dbscan

One sample carries the chapter: `dbscan.c` classifies 12 points into a
rectangle blob, a two-point chain, a two-claim border, a triangle blob,
and 2 noise points, 39 checks. The chapter makes 4 moves: the eps ball
and the core census with the closed-boundary convention, the
breadth-first expansion that grows clusters without a k, the
density-reachability chain that defines what a cluster is, and the
border point two clusters both want. The neighborhoods are the squared
euclidean of #xref-to("kdd", "distance") compared as integers,
#xref-to("kdd", "kmeans") needed k up front while this chapter discovers
the count, #xref-to("kdd", "validation") reuses the census row verbatim,
and #xref-to("kdd", "lof") later grades density per point where this
chapter grades it per neighborhood.

== eps balls and the core census

DBSCAN fixes two parameters and never asks for k: a radius eps, here 5
as a squared-distance budget of 25, and a core threshold minpts, here 3.
A point's neighborhood N(p) is every other point with $d^2 <= 25$, the
CLOSED ball, so pairs at exactly $d = 5$ count as neighbors. A point is
core when its neighborhood holds at least minpts others, self excluded,
the scikit-learn spelling of the original paper's threshold. Everything
stays integer: the sample never takes a square root.

The dry run: the 3-4-5 rectangle at the origin gives `nb p1={2,3,4} n=3
core`, neighbors at squared distances 9, 16, and 25, the last being p4
exactly on the boundary. Corner p4 gains the chain point: `nb
p4={1,2,3,5} n=4 core`. The tail of the second blob shows the same
boundary work: `nb p9={8,10} n=2 noncore`, where p10 sits at squared
distance 25, in. Three exactly-at-eps pairs exist in the fixture, {1,4},
{2,3}, {9,10}, and the check "ch33 closed ball: the three d=5 pairs
{1,4},{2,3},{9,10} are in" pins all three as neighbors, the closed ball
doing real work rather than sitting in a comment. The two far points
print `nb p11={} n=0 noncore` and `nb p12={} n=0 noncore`, empty
neighborhoods that will become noise.

#listing("kdd/samples/src/Ch33/dbscan.c", first: 10, last: 19,
  caption: [the pinned convention: closed ball, self excluded, scan order])

#listing("kdd/samples/src/Ch33/dbscan.c", first: 82, last: 116,
  caption: [the neighbor census and the three exactly-at-eps pairs])

#diagram([the fixture: two boundary pairs sit exactly on the closed eps ball], length: 9.5pt, {
  cdraw.line((-2.5, 0), (33, 0), stroke: luma(215))
  cdraw.line((0, -2.5), (0, 22.5), stroke: luma(215))
  let pts = ((0, 0), (3, 0), (0, 4), (3, 4), (7, 4), (7, 8), (11, 4),
    (15, 4), (18, 4), (15, 8), (30, 10), (5, 20))
  for p in pts {
    cdraw.circle(p, radius: 0.5, fill: luma(70), stroke: none)
  }
  cdraw.circle((0, 0), radius: 5, stroke: (paint: luma(160), dash: "dashed"))
  cdraw.circle((18, 4), radius: 5, stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((-1.6, -1.9), [p1], size: 6pt)
  cdraw.content((3.0, -1.9), [p2], size: 6pt)
  cdraw.content((-2.2, 4.6), [p3], size: 6pt)
  cdraw.content((3.7, 5.0), [p4], size: 6pt)
  cdraw.content((7.0, -1.9), [p5], size: 6pt)
  cdraw.content((8.1, 8.3), [p6], size: 6pt)
  cdraw.content((11.0, -1.9), [p7], size: 6pt)
  cdraw.content((15.0, -1.9), [p8], size: 6pt)
  cdraw.content((18.6, 2.6), [p9], size: 6pt)
  cdraw.content((14.0, 9.2), [p10], size: 6pt)
  cdraw.content((30.0, 11.4), [p11], size: 6pt)
  cdraw.content((5.0, 21.4), [p12], size: 6pt)
  cdraw.content((6.3, 5.9), [p4 exactly at d = 5, in], size: 6pt)
  cdraw.content((16.4, 10.6), [p10 exactly at d = 5, in], size: 6pt)
  cdraw.content((25.5, 18.5), [eps = 5, closed ball d2 $<=$ 25], size: 6.5pt)
  cdraw.content((25.5, 17.2), [dashed circles drawn at radius 5], size: 6pt)
  cdraw.line((6.6, 6.2), (3.6, 5.4), stroke: luma(150), mark: (end: ">"))
  cdraw.line((17.6, 10.3), (15.6, 9.0), stroke: luma(150), mark: (end: ">"))
})

#callout("pitfall", "two conventions decide the whole census", [
  The closed ball and the self-excluded count are not cosmetic choices,
  they move points across classes here. An open ball would drop {1,4},
  {2,3}, {9,10} from the neighbor lists: p1 would read n=2 and lose
  core, and p10 would drop out of p9's list entirely. Counting self the
  other way, p7's row would read n=3 and a border would become a core,
  changing the census and with it the two-claim story of the last facet.
  The sample pins both conventions in its header and the checks hold them
  to the pinned rows.
])

== expansion, borders, and noise

Clusters grow breadth-first from the first unvisited core in input
order, and the rule for growth is one line: a core claims every
unvisited neighbor, a border absorbs its label but never expands. Points
no cluster ever reaches stay noise, labeled -1.

The dry run: p1 is the first core in input order and seeds cluster 0.
The BFS absorbs the rectangle {p1,p2,p3,p4}, walks to p5 through p4's
neighborhood, and takes the borders p6 and p7 with it, printing
`cluster0={1,2,3,4,5,6,7}`. The scan resumes, finds p8 unvisited, and
seeds cluster 1, absorbing p9 and p10: `cluster1={8,9,10}`. The label
rows carry the taxonomy per point, `label p6=0 border` and `label
p8=1 core` among them, and the two unreached points print `label
p11=-1 noise` and `label p12=-1 noise`, collected as `noise={11,12}`.
The census closes the accounting: `census core=6 border=4 noise=2
clusters=2`. The cluster count was never an input, it is what the
parameters found: 6 cores carry the structure, 4 borders ride it, 2
points are too far from everything to belong.

#listing("kdd/samples/src/Ch33/dbscan.c", first: 118, last: 155,
  caption: [breadth-first expansion: cores claim, borders absorb, noise stays])

#listing("kdd/samples/src/Ch33/dbscan.c", first: 157, last: 201,
  caption: [the census, the two membership rows, and the noise row])

#diagram([the census on the plane: 6 cores, 4 borders, 2 noise, 2 clusters], length: 9.5pt, {
  cdraw.line((-2.5, 0), (33, 0), stroke: luma(215))
  cdraw.line((0, -2.5), (0, 22.5), stroke: luma(215))
  cdraw.line((0, 0), (3, 0), (11, 4), (7, 8), (0, 4), close: true,
    stroke: luma(190), fill: luma(246))
  cdraw.line((15, 4), (18, 4), (15, 8), close: true,
    stroke: luma(190), fill: luma(246))
  let cores = ((0, 0), (3, 0), (0, 4), (3, 4), (7, 4), (15, 4))
  let borders = ((7, 8), (11, 4), (18, 4), (15, 8))
  for p in cores {
    cdraw.circle(p, radius: 0.55, fill: luma(60), stroke: none)
  }
  for p in borders {
    cdraw.circle(p, radius: 0.55, stroke: luma(60))
  }
  for p in ((30, 10), (5, 20)) {
    cdraw.line((p.at(0) - 0.7, p.at(1) - 0.7), (p.at(0) + 0.7, p.at(1) + 0.7),
      stroke: luma(60))
    cdraw.line((p.at(0) - 0.7, p.at(1) + 0.7), (p.at(0) + 0.7, p.at(1) - 0.7),
      stroke: luma(60))
  }
  cdraw.content((4.5, 10.5), [cluster 0: 5 cores + 2 borders], size: 6pt)
  cdraw.content((16.5, 9.4), [cluster 1: 1 core + 2 borders], size: 6pt)
  cdraw.rect((20.0, 13.5), (32.5, 20.5), fill: luma(243), radius: 0.05)
  cdraw.content((26.2, 19.6), [filled = core, 6], size: 6pt)
  cdraw.content((26.2, 18.6), [open = border, 4], size: 6pt)
  cdraw.content((26.2, 17.6), [crossed = noise, 2], size: 6pt)
  cdraw.content((26.2, 16.2), [census core=6 border=4], size: 6pt)
  cdraw.content((26.2, 15.4), [noise=2 clusters=2], size: 6pt)
  cdraw.content((26.2, 14.2), [hulls = cluster membership], size: 6pt)
})

== density reachability

The definition underneath the BFS: q is directly density-reachable from
p when p is core and q is in N(p), and density-reachable when a chain of
such steps exists, every intermediate point core. The chain may end at a
border because only the reaching endpoint must be core, which is exactly
why borders ride clusters without ever expanding them.

The dry run: the sample walks the longest chain in the fixture, from the
rectangle into the border p7: `reach p1->p4 d2=25 core->core`, `reach
p4->p5 d2=16 core->core`, `reach p5->p7 d2=16 core->border`. Each row is
checked twice, once as a printed line and once as the assertion that the
reaching point is core and the target is its neighbor. The first hop is
the closed ball again: p4 is directly density-reachable from p1 at
distance exactly 5, on the boundary, in. The last hop shows the
asymmetry: p5->p7 is a legal step and p7->p5 would not begin a chain,
because p7 is not core. Density-connectivity, the true cluster
definition, is reachability plus symmetry at the far end, and the
breadth-first expansion of the previous facet computes it without ever
naming it.

#listing("kdd/samples/src/Ch33/dbscan.c", first: 203, last: 217,
  caption: [the chain trace, each step core reaches neighbor])

#diagram([three hops, every intermediate core, ending at a border], length: 11pt, {
  cdraw.circle((0, 0), radius: 5, stroke: (paint: luma(205), dash: "dashed"))
  cdraw.circle((3, 4), radius: 5, stroke: (paint: luma(205), dash: "dashed"))
  cdraw.circle((7, 4), radius: 5, stroke: (paint: luma(205), dash: "dashed"))
  let chain = ((0, 0), (3, 4), (7, 4), (11, 4))
  for (i, p) in chain.enumerate() {
    if i < 3 {
      cdraw.circle(p, radius: 0.6, fill: luma(60), stroke: none)
    }
  }
  cdraw.circle((11, 4), radius: 0.6, stroke: luma(60))
  cdraw.content((-1.2, -1.6), [p1], size: 6.5pt)
  cdraw.content((3.0, 5.3), [p4], size: 6.5pt)
  cdraw.content((7.0, 2.2), [p5], size: 6.5pt)
  cdraw.content((11.0, 2.8), [p7], size: 6.5pt)
  cdraw.content((-1.2, -3.0), [core], size: 6pt)
  cdraw.content((3.0, 7.0), [core], size: 6pt)
  cdraw.content((7.0, 0.8), [core], size: 6pt)
  cdraw.content((11.0, 1.7), [border], size: 6pt)
  cdraw.line((0, 0), (3, 4), stroke: luma(40), mark: (end: ">"))
  cdraw.line((3, 4), (7, 4), stroke: luma(40), mark: (end: ">"))
  cdraw.line((7, 4), (11, 4), stroke: luma(40), mark: (end: ">"))
  cdraw.content((0.0, 3.0), [d2 = 25], size: 6pt)
  cdraw.content((5.0, 4.8), [d2 = 16], size: 6pt)
  cdraw.content((9.0, 3.2), [d2 = 16], size: 6pt)
  cdraw.content((4.0, -3.6), [every intermediate core, the chain may end at a border], size: 6pt)
  cdraw.content((4.0, -4.8), [p7 -> p5 would not start a chain], size: 6pt)
})

== the border with two claims

A border point within eps of cores from two different clusters is
legitimately claimable by both, and the assignment is a convention the
sample pins rather than a theorem the algorithm proves: the border joins
the cluster of the first core that reaches it in the scan order.

The dry run: p7's neighborhood is exactly the two cores, and the row
prints `border p7 nb={5,8} cores p5(cluster0) p8(cluster1)`. Both claims
are legal density steps, p7 within eps of p5 of cluster 0 and of p8 of
cluster 1. The resolution prints `claimed_by=0
rule=first_core_in_input_order`, p5 preceding p8 in the input, and the
loser is recorded rather than discarded, `also_core={8} cluster=1`. The
order is not incidental: the breadth-first scan of the previous facet
seeded cluster 0 at p1 and reached p5 before p8 was ever visited, so the
deterministic rule and the traversal agree. Swap the input order of p5
and p8 and the same rule hands p7 to cluster 1, which is the honest
statement of what a two-claim border is: a point the parameters cannot
decide, decided by an order someone chose.

#listing("kdd/samples/src/Ch33/dbscan.c", first: 219, last: 263,
  caption: [the two claims, the pinned rule, and the recorded loser])

#diagram([one border, two legal claims, one pinned rule], length: 12.5pt, {
  cdraw.circle((11, 4), radius: 5, stroke: (paint: luma(170), dash: "dashed"))
  for p in ((7, 4), (15, 4)) {
    cdraw.circle(p, radius: 0.6, fill: luma(60), stroke: none)
  }
  cdraw.circle((11, 4), radius: 0.6, stroke: luma(60))
  cdraw.content((7.0, 1.6), [p5 core, cluster 0], size: 6.5pt)
  cdraw.content((15.0, 1.6), [p8 core, cluster 1], size: 6.5pt)
  cdraw.content((11.0, 9.8), [p7 border], size: 6.5pt)
  cdraw.line((7.7, 4.0), (10.3, 4.0), stroke: luma(40), mark: (end: ">"))
  cdraw.content((9.0, 4.8), [claimed_by = 0], size: 6pt)
  cdraw.line((14.5, 2.6), (11.6, 2.6),
    stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((13.1, 1.9), [also_core = {8} cluster = 1], size: 6pt)
  cdraw.content((11.0, -1.0), [both p5 and p8 sit inside p7's eps ball at d = 4], size: 6pt)
  cdraw.content((11.0, -2.2), [rule = first_core_in_input_order, p5 before p8], size: 6pt)
})

#callout("note", "border assignment is a convention, not geometry", [
  Nothing about the distances breaks the tie: p7 is 4 from both claimant
  cores, an exact tie in the data. The original algorithm leaves border
  membership to the order clusters happen to expand, and different
  implementations differ exactly here. The pin makes the choice explicit
  and testable, first core in input order, with the losing claim printed
  beside the winner, so the row reads as a decision with a record rather
  than an accident with an output.
])

sources: the algorithm and the reachability definitions are Ester,
Kriegel, Sander, Xu 1996, "A density-based algorithm for discovering
clusters in large spatial databases with noise", Proceedings of the
Second International Conference on Knowledge Discovery and Data Mining
(KDD-96), AAAI Press, pp. 226-231, and the minpts-counts-neighbors-
excluding-self convention is scikit-learn's DBSCAN documentation as
pinned by kdd-contract-s7.md. The fixture and every pinned row are
witnessed by the contract + playground/kdd-matrix/gen_s7.py, run
2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch33`, 39 checks in chapter 33 of the kdd suite.
