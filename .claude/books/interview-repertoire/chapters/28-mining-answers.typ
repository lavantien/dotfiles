#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= data mining answers

The mining round asks three kinds of question: name the measure and
defend the choice, name the family and defend the parameters, and
place the algorithm inside the discovery process it serves. Every
drill floors to the kdd handbook, and one answer, pagerank, has to
concede out loud what the corpus does not ship.


== similarity and distance measures [DRILL]

Euclidean distance is the length of the difference vector, the
minkowski family at p equals 2, holding manhattan at p equals 1 and
shrinking strictly as p grows, #xref-to("kdd", "distance"). It pays
attention to magnitude, right when the coordinates are the signal,
wrong when one loud axis dwarfs the rest. Cosine is the dot product
over the two lengths, the angle alone, scaling either vector by any
constant changes nothing, the right attitude for counts and
ratings, #xref-to("kdd", "similarity"). Jaccard is for sets,
intersection over union, a fraction from 0 to 1 needing no order,
no magnitudes, no dimensions, the default for baskets and tags.
Normalization is where the answer changes, and saying so is the
answer: z-scoring each axis hands euclidean a new metric where the
loud coordinate stops dominating, centering turns cosine into the
pearson correlation, so pure offset stops counting and only
co-movement does. The chooser, one breath: coordinates take
euclidean, counts take cosine, sets take jaccard, normalization
says which magnitudes count.

#callout("pitfall", "normalization is a modeling decision, not a preprocessing detail", [
  Cosine is blind to magnitude, so on raw ratings it calls a user
  who rated everything 5 identical to one who rated everything 1.
  Z-scoring each axis rewrites euclidean, centering turns cosine
  into correlation, either move changes the neighbor ranking, so
  the spoken answer names the measure and the normalization
  together, never the measure alone.
])

#diagram([the representation picks the measure, normalization decides which magnitudes count], length: 13pt, {
  // chooser grid rows, representation against measure against why, with the two normalization notes under
  let rows = (
    ([coordinates], [euclidean], [the magnitudes are the signal]),
    ([counts, documents], [cosine], [direction only, scaling changes nothing]),
    ([baskets, tags], [jaccard], [intersection over union, no magnitudes]),
  )
  let cell(x, y, w, t, fill: luma(252)) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  for (i, r) in rows.enumerate() {
    let y = 6.4 - i * 1.3
    cell(0.0, y, 5.4, r.at(0))
    cell(5.4, y, 4.6, r.at(1), fill: luma(215))
    cell(10.0, y, 11.2, r.at(2))
  }
  cdraw.content((8.1, 2.5), [z-scoring changes euclidean, centering turns cosine into correlation], size: 6pt)
  cdraw.content((8.1, 1.5), [cosine on raw ratings calls all-5s identical to all-1s], size: 6pt)
})

== clustering: k-means, hierarchical, dbscan [DRILL]

Three families, one sentence each. K-means is the centroid family:
lloyd alternates two moves, assign every point to the nearest
centroid by squared euclidean, then move every centroid to the mean
of what it holds, the objective never increases, the seeds pick the
basin, nothing promises the global optimum,
#xref-to("kdd", "kmeans"). K is an input, and who picks it is the
real question: the elbow, read off a table of sse by k, the table
worth reading being the optimum per k, which the kdd chapter
computes by exhaustive enumeration. Never from thin air.
Hierarchical is the connectivity family: agglomerative, every point
its own cluster, merge the closest pair until one remains, the
distance matrix the only input, the linkage rule extending point
distance to cluster distance, single taking the minimum cross pair
and chaining, complete taking the maximum and dragging, the
dendrogram cut where the task needs it and no k chosen up front,
#xref-to("kdd", "hierarchical"). Dbscan is the density family: a
radius and a core threshold and never a k, a point is core when its
neighborhood holds the threshold count of others, clusters grow
breadth-first from cores, borders absorb the label without
expanding, what nothing reaches is labeled noise, the label the
other families cannot produce, the cluster count an output,
#xref-to("kdd", "dbscan"). Density beats centroids when the
clusters are not spheres, the sizes are uneven, and the noise must
be named rather than force-assigned to the nearest mean.

#diagram([centroids with k given, a dendrogram cut later, density that labels its own noise], length: 13pt, {
  // one panel per family: points and a centroid square, a two-merge dendrogram, blobs plus one noise point
  let p(x, y, fill: luma(70)) = { cdraw.circle((x, y), radius: 0.16, fill: fill, stroke: none) }
  cdraw.content((3.2, 9.4), [k-means], size: 6.5pt)
  for i in range(4) {
    p(1.2 + i * 0.55, 8.4); p(1.5 + i * 0.55, 7.8)
    p(4.4 + i * 0.55, 8.4); p(4.7 + i * 0.55, 7.8)
  }
  cdraw.rect((1.95, 7.75), (2.25, 8.05), fill: luma(20), stroke: none)
  cdraw.rect((5.15, 7.75), (5.45, 8.05), fill: luma(20), stroke: none)
  cdraw.content((3.2, 6.9), [k given, seeds pick the basin], size: 6pt)
  cdraw.content((12.3, 9.4), [hierarchical], size: 6.5pt)
  let up(x, y1, y2) = { cdraw.line((x, y1), (x, y2), stroke: luma(60)) }
  let lx = (9.9, 11.5, 13.1, 14.7)
  for i in range(4) { cdraw.content((lx.at(i), 7.6), [#(i + 1)], size: 6pt); up(lx.at(i), 7.8, 8.3); up(lx.at(i), 8.3, 8.9) }
  cdraw.line((9.9, 8.3), (11.5, 8.3), stroke: luma(60)); cdraw.line((13.1, 8.3), (14.7, 8.3), stroke: luma(60))
  cdraw.line((9.9, 8.9), (14.7, 8.9), stroke: luma(60))
  cdraw.line((10.7, 8.9), (10.7, 9.05), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((12.3, 6.9), [no k up front, cut the tree later], size: 6pt)
  cdraw.content((20.6, 9.4), [dbscan], size: 6.5pt)
  for i in range(4) { p(17.8 + i * 0.5, 8.3) }
  p(18.6, 7.9); p(19.0, 7.8)
  cdraw.circle((18.6, 7.9), radius: 1.1, stroke: (paint: luma(160), dash: "dashed"))
  for i in range(3) { p(21.8 + i * 0.5, 8.2) }
  cdraw.circle((23.2, 7.6), radius: 0.16, fill: none, stroke: luma(60))
  cdraw.content((23.7, 7.35), [noise], size: 6pt)
  cdraw.content((20.6, 6.9), [eps and a core count, noise is an output], size: 6pt)
})

== itemsets: apriori and fp-growth [DRILL]

Support first, defined out loud: the support of an itemset is the
count or fraction of transactions whose basket contains it. The
confidence of a rule is the support of the union over the support
of the antecedent, a conditional frequency, and confusing the two
is the classic screen, a pair can be confident and useless because
the consequent alone is near universal. Neither is interestingness:
lift divides confidence by what independence would give and reads 1
when the rule says nothing. Apriori is the law named a priori:
every subset of a frequent itemset is frequent, each transaction
witnessing the superset witnessing every subset at once, and the
algorithm runs the contrapositive before counting, one infrequent
subset kills the candidate uncounted, the anti-monotone prune.
Levelwise, that is join the frequent k minus 1 itemsets sharing a
prefix, prune on subsets, count survivors, one database pass per
level, #xref-to("kdd", "apriori"). Fp-growth reads the database
exactly twice: pass one counts singles into the frequency list,
pass two rewrites every transaction in that order into a prefix
tree with counted edges, then mining walks conditional pattern
bases per item, no candidate generation at all,
#xref-to("kdd", "fpgrowth"). The trade, said plainly: apriori
spends passes and keeps the database on disk, fp-growth spends
memory on the compressed tree and stops paying for passes. The
counting pass underneath both is a group by over baskets, the
database answers chapter's home turf,
#xref-to("repertoire", "db-answers").

#diagram([one dead pair kills its whole upper cone, the tree shares prefixes and counts edges], length: 13pt, {
  // left: the lattice with a killed cone on the nine-basket fixture, right: the fp-tree of the same baskets
  let box(x, y, lab, cnt, dead: false) = {
    cdraw.rect((x - 1.35, y - 0.5), (x + 1.35, y + 0.5),
      fill: if dead { luma(250) } else { luma(215) }, stroke: luma(120), radius: 0.02)
    cdraw.content((x, y + 0.12), lab, size: 6pt); cdraw.content((x, y - 0.28), cnt, size: 6pt)
    if dead { cdraw.line((x - 1.0, y - 0.4), (x + 1.0, y + 0.4), stroke: luma(90)) }
  }
  cdraw.content((4.6, 9.6), [apriori, one pass per level], size: 6.5pt)
  box(4.6, 8.3, [{I1,I2}], [4]); box(1.9, 8.3, [{I1,I3}], [4])
  box(7.3, 8.3, [{I3,I5}], [1], dead: true)
  box(4.6, 6.6, [{I1,I2,I3}], [2]); box(7.3, 6.6, [{I1,I3,I5}], [dead], dead: true)
  cdraw.line((7.0, 7.7), (7.3, 7.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((4.6, 5.2), [an infrequent pair executes its whole upper cone, uncounted], size: 6pt)
  cdraw.content((17.6, 9.6), [fp-growth, two passes total], size: 6.5pt)
  cdraw.rect((16.6, 7.6), (18.6, 8.2), fill: luma(240), stroke: luma(120), radius: 0.02)
  cdraw.content((17.6, 7.9), [root], size: 6pt)
  let e(a, b) = { cdraw.line(a, b, stroke: luma(60), mark: (end: ">")) }
  e((17.6, 7.6), (16.6, 6.7)); cdraw.content((16.3, 7.0), [I2, 7], size: 6pt)
  e((16.6, 6.5), (15.6, 5.6)); cdraw.content((15.2, 5.9), [I1, 4], size: 6pt)
  e((16.6, 6.5), (17.7, 5.6)); cdraw.content((18.2, 5.9), [I3, 2], size: 6pt)
  e((17.6, 7.6), (18.7, 6.7)); cdraw.content((19.2, 7.0), [I1, 2], size: 6pt)
  cdraw.content((17.6, 4.4), [shared prefixes, counted edges, no candidates], size: 6pt)
})

== cosine neighbors and smoothed bayes [TDD]

The chooser above says counts take cosine; this workspace computes
it, `ch28-go`, 22 test functions under `make verify-go`, stdlib
only, every number below the suite's measured output. The
representation move comes first and is half the answer: baskets and
draft picks are one-hot sets, so the cosine of two vectors that carry
no magnitudes at all is the shared id count over the sqrt of the two
sizes, computed on sorted ints in one linear merge, no hash map and
no float feature vector anywhere:

#listing("interview-repertoire/samples/ch28-go/sets.go", first: 20, last: 67, caption: [presence is the only fact: sorted ids, one merge for the intersection, cosine as a count over two sqrts])

Measured: {1,2,3} against {2,3,4} shares 2 of sqrt(3 * 3) and scores
0.6667, {1,2} against {2} scores 1 over sqrt(2 * 1), 0.7071, and a
duplicated item in the basket changes nothing because presence is
the only fact the set keeps. kNN on top of that similarity is a sort
and a weighted vote:

#listing("interview-repertoire/samples/ch28-go/knn.go", first: 48, last: 80, caption: [similarity-weighted votes, ties by id, zero-similarity neighbors carry no weight])

The tie the follow-up asks about is pinned: the query {1,3} sits at
cosine 0.5 from a winner {1,2} and at 0.5 from a loser {3,4}, and
the two weighted votes cancel to exactly 0, the chance line. A
zero-similarity neighbor carries no weight at all, so it cannot drag
a real vote toward 0, only real neighbors speak, and similarity ties
break by train id ascending so neighbor selection never depends on
the order drafts were handed to the trainer.

Bernoulli naive bayes is the other comparator on the same sets, the
prior log-odds plus one smoothed log ratio per present item:

#listing("interview-repertoire/samples/ch28-go/naivebayes.go", first: 43, last: 67, caption: [the prior log-odds, laplace-smoothed conditionals, out-of-vocabulary items skipped])

The hand-computable fixture is the spoken answer: two winners
carrying item 1 and one loser without it, alpha 1, and the score of
{1} is ln 2 + ln(9\/4) = ln 4.5, measured 1.5041. Laplace is the
zero-cell rescue, without it one absent count makes the ratio
infinite and a single unseen cell dominates every score; an item
counted zero in both classes is out of vocabulary and skipped,
because scoring a stranger would add another copy of the prior per
stranger and drift every query toward the rarer class. Both
comparators floor to the kdd handbook, #xref-to("kdd",
"similarity") for the measure, #xref-to("kdd", "knn") and
#xref-to("kdd", "bayes") for the families, and the same pair runs
report-only beside the mined dota-helper engine's live linear scorer,
#xref-to("go", "fitting").

#diagram([the tie query cancels its two equal votes, the stranger item adds nothing], length: 13pt, {
  // left: the query {1,3} against two neighbors both at cosine 0.5, votes +1 and -1 cancel; right: the stranger skipped
  cdraw.content((5.2, 9.9), [the tie], size: 6.5pt)
  cdraw.rect((0.6, 7.6), (3.4, 8.7), fill: luma(215), stroke: luma(60), radius: 0.02)
  cdraw.content((2.0, 8.15), [{1,3}], size: 6pt)
  cdraw.line((3.4, 8.15), (5.2, 8.15), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.3, 8.6), [0.5], size: 6pt)
  cdraw.line((3.4, 7.9), (5.2, 7.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.3, 7.2), [0.5], size: 6pt)
  cdraw.rect((5.2, 7.7), (8.0, 8.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((6.6, 8.15), [{1,2}, won], size: 6pt)
  cdraw.content((6.6, 7.05), [vote +0.5], size: 6pt)
  cdraw.rect((1.2, 5.9), (4.0, 6.8), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((2.6, 6.35), [{3,4}, lost], size: 6pt)
  cdraw.line((4.0, 6.35), (5.2, 6.35), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.6, 6.35), [vote -0.5], size: 6pt)
  cdraw.content((5.2, 4.8), [sum 0 over weight 1: the chance line], size: 6pt)
  cdraw.content((16.4, 9.9), [the stranger], size: 6.5pt)
  cdraw.rect((12.0, 7.7), (14.8, 8.6), fill: luma(215), stroke: luma(60), radius: 0.02)
  cdraw.content((13.4, 8.15), [{1,9}], size: 6pt)
  cdraw.content((16.4, 8.15), [item 9 seen in neither class: skipped], size: 6pt)
  cdraw.content((16.4, 7.0), [score({1,9}) = score({1})], size: 6pt)
  cdraw.content((16.4, 5.8), [a stranger adding the prior would drift the score], size: 6pt)
  cdraw.content((16.4, 4.8), [toward whichever class was rarer in train], size: 6pt)
})

== the levelwise pass, counted and pruned [TDD]

The itemsets drill above draws the lattice on nine baskets; this
workspace runs the same baskets through the levelwise pass:

#listing("interview-repertoire/samples/ch28-go/apriori.go", first: 29, last: 75, caption: [singles in one sweep, join on the shared prefix, prune every subset before counting, one database pass per level])

Measured at support 2: the singles count 6, 7, 6, 2, 2, all five
frequent; six pairs survive; {3,5} dies at count 1 and its whole
upper cone, {1,3,5} included, is never counted at all, the
anti-monotone law doing its work before the database pass; two
triples survive at count 2 each, {1,2,3} and {1,2,5}; 13 itemsets in
all, and the brute-force cross-check enumerates all 31 subsets of
the five singles and agrees with the levelwise output on every one.
Then the rule arithmetic, counted straight from the database:

#listing("interview-repertoire/samples/ch28-go/apriori.go", first: 94, last: 117, caption: [support, confidence, and lift as three support counts and two divisions])

The pair of rules the trap lives in, measured: {1,2} implies 3 and
{1,2} implies 5 both carry confidence 0.5 and mean opposite things,
lift 0.75 against 2.25, because item 3 shows in 6 of 9 baskets while
item 5 shows in 2, and a near-universal consequent hands confidence
out for free. On the independence fixture, baskets {1}, {2}, {1,2},
and the empty basket, the rule {1} implies 2 reads confidence 0.5
and lift exactly 1, the number that says the rule says nothing.
Floors: #xref-to("kdd", "apriori") for the levelwise law,
#xref-to("kdd", "interesting") for lift as the interestingness
divide.

#diagram([same confidence 0.5, opposite lift: the consequent's own support decides], length: 13pt, {
  // two rules as rows: joint support bar over antecedent support bar, the lift number at the right
  let ruleRow(y, name, joint, ant, cons, lift, verdict) = {
    cdraw.content((2.6, y), [#name], size: 6pt)
    cdraw.rect((5.6, y - 0.35), (5.6 + ant * 9.0, y + 0.35), fill: luma(235), stroke: luma(120), radius: 0.0)
    cdraw.rect((5.6, y - 0.35), (5.6 + joint * 9.0, y + 0.35), fill: luma(205), stroke: luma(60), radius: 0.0)
    cdraw.content((5.2 + ant * 9.0 + 0.9, y), [#cons], size: 6pt)
    cdraw.content((19.4, y), [#lift], size: 6.5pt)
    cdraw.content((19.4, y - 0.85), verdict, size: 6pt)
  }
  cdraw.content((10.8, 10.0), [confidence 2\/4 = 0.5 on both rows], size: 6.5pt)
  ruleRow(8.3, [{1,2} => 3], 2, 4, [3 in 6 of 9], [lift 0.75], [below 1: knowing hurts])
  ruleRow(5.9, [{1,2} => 5], 2, 4, [5 in 2 of 9], [lift 2.25], [above 1: knowing helps])
  cdraw.content((10.8, 3.6), [the dark bar is the joint {1,2,x} at 2, the light bar the antecedent {1,2} at 4], size: 6pt)
  cdraw.content((10.8, 2.6), [lift divides 0.5 by the consequent's own support: 6\/9 against 2\/9], size: 6pt)
})

== pagerank and the pipeline view [DRILL]

The random surfer: a walker sits on a page and at each step either
follows a random out link or teleports to a random page, and the
rank of a page is the share of walkers it holds at equilibrium, the
stationary distribution of the walk. The arithmetic is one line, a
page's rank is the sum over its in-links of each giver's rank
divided by that giver's out degree, a page with one out link hands
its whole rank forward, a page with a hundred hands each a
hundredth. Damping, the textbook 0.85, earns its place twice: a
sink page with no out links would trap the walker forever, and the
teleport term makes the walk ergodic, so the fixed point exists and
plain iteration converges to it. Then the concession, before anyone
asks: the corpus ships no pagerank. What the corpus runs is the
pipeline the question rides in, and that pipeline is the frame for
every mining question: selection, preprocessing, transformation,
mining, evaluation, iterated until the patterns count as knowledge,
mining stage 4 of 5, #xref-to("kdd", "process"). The capstone walks
it end to end, a generated corpus, an embedded store whose cleaning
views fill planted holes, pure go miners over views, and a
planted-truth evaluation scoring what came back against what was
planted, #xref-to("kdd", "capstone"). So have you run pagerank
answers no, and how would you mine a graph answers with the loop,
not the name: what is selected, how cleaned, how transformed, what
mined, how evaluated.

#diagram([the surfer with damping on top, the five-stage loop underneath, mining is stage 4], length: 13pt, {
  // top: three nodes, rank split by out degree, a teleport arc, bottom: the five pipeline stages
  cdraw.content((6.0, 10.4), [pagerank], size: 6.5pt)
  for c in ((2.4, [a]), (6.0, [b]), (9.6, [c])) {
    cdraw.circle((c.at(0), 8.9), radius: 0.55, fill: luma(215), stroke: luma(60))
    cdraw.content((c.at(0), 8.9), c.at(1), size: 6pt)
  }
  cdraw.line((2.95, 8.9), (5.45, 8.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.95, 9.15), (9.05, 9.15), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.55, 8.9), (9.05, 8.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.2, 9.9), (1.2, 8.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((0.9, 7.6), [teleport 1-d], size: 6pt)
  cdraw.content((16.5, 9.5), [a's rank splits across its out degree], size: 6pt)
  cdraw.content((16.5, 8.7), [d = 0.85, sinks cannot trap the walker], size: 6pt)
  cdraw.content((16.5, 7.9), [the corpus ships the loop, not the surfer], size: 6pt)
  let stages = (
    (1.0, [1], [selection], [pick a target set]), (4.9, [2], [preprocessing], [clean and repair]),
    (8.8, [3], [transformation], [bin, scale, reduce]), (12.7, [4], [mining], [enumerate patterns]),
    (16.6, [5], [evaluation], [keep the useful ones]),
  )
  for s in stages {
    cdraw.rect((s.at(0), 4.4), (s.at(0) + 3.4, 6.1), fill: luma(240), stroke: luma(120), radius: 0.02)
    cdraw.content((s.at(0) + 1.7, 5.55), [#s.at(1) #s.at(2)], size: 6.5pt)
    cdraw.content((s.at(0) + 1.7, 4.8), s.at(3), size: 6pt)
  }
  for x in (4.4, 8.3, 12.2, 16.1) { cdraw.line((x, 5.25), (x + 0.5, 5.25), stroke: luma(60), mark: (end: ">")) }
  cdraw.line((18.3, 6.3), (2.7, 6.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((10.5, 6.65), [iterate until the patterns count as knowledge], size: 6pt)
  cdraw.content((10.5, 3.3), [mining is one stage of five, every mining question is answered inside this loop], size: 6pt)
})

floored to: the kdd handbook chapters carrying the gated
implementations, #xref-to("kdd", "distance") and
#xref-to("kdd", "similarity") for the measures,
#xref-to("kdd", "kmeans"), #xref-to("kdd", "hierarchical"), and
#xref-to("kdd", "dbscan") for the families, #xref-to("kdd",
"apriori") and #xref-to("kdd", "fpgrowth") for the itemsets, with
the workspace's own floors at #xref-to("kdd", "knn") and
#xref-to("kdd", "bayes") for the comparators and #xref-to("kdd",
"interesting") for the lift divide, #xref-to("kdd", "process") for
the loop, #xref-to("kdd", "capstone") for the pipeline that runs,
and #xref-to("go", "fitting") where the same cosine and bayes run
report-only on mined engine data.
