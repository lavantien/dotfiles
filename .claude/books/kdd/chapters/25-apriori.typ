// ch25, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 23 checks in kdd/samples/src/Ch25/apriori.c or a banked provenance
// note: the nine baskets are the running example table of Han, Pei, Yin,
// "Mining Frequent Patterns without Candidate Generation", SIGMOD 2000,
// TIDs 100-900, https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf
// (accessed 2026-09-22), the same table chapters 26 and 28 mine again by
// other means. all pinned values are witnessed by kdd-contract-s6.md +
// playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0. determinism:
// everything D0, integer support counts and exact strings, no doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= levelwise apriori

One sample carries the chapter: `apriori.c` runs the levelwise loop twice
over the same nine baskets, minsup 2 then minsup 3, 23 checks. The
chapter makes 4 moves: the support count and the antimonotone law that
makes searching by levels cheaper than testing all 32 subsets, the
join-and-prune candidate generator whose killing subsets act before any
scan, the two different ways the loop can stop, and the harvest of 13
frequent itemsets that chapters 26 and 28 recompute from the same table
by entirely different means. The baskets are the fp-growth literature's
own running example, the itemset lattice they live in is the same
exponential-in-dimensions shape #xref-to("kdd", "olap") counts cube
cells in, and the rules these itemsets grow into are
#xref-to("kdd", "maximal") material.

== support and the law named a priori

An itemset is a subset of the item universe, here five items I1..I5, and
its support is the number of transactions whose basket contains it, the
containment test one bitwise AND per row. The fixture is nine baskets,
and the sample prints them as one byte-pinned row, `100:{I1,I2,I5}` on
through `900:{I1,I2,I3}`. Minsup is an absolute count, 2 of 9: a
fraction threshold on nine rows would have to round somewhere, and the
sheet keeps the threshold an integer so every comparison is exact.

The law: every subset of a frequent itemset is frequent, because each
transaction witnessing the superset witnesses all its subsets at once.
The algorithm uses the contrapositive, an itemset with one infrequent
subset cannot itself be frequent, and uses it before touching the data,
which is what the name means. The dry run: one counting pass over the
five singletons prints `C1 gen=5 prune=0 L=5` and `L1: {I1}=6;{I2}=7;
{I3}=6;{I4}=2;{I5}=2`. I2 is the busiest item at 7 of 9 baskets, and
even the two rarest items clear the bar at exactly 2, so level 1 keeps
every candidate and the prune has nothing to do yet.

#listing("kdd/samples/src/Ch25/apriori.c", first: 36, last: 49,
  caption: [the M2 baskets as one bitmask per transaction, Han-Pei-Yin table])

#listing("kdd/samples/src/Ch25/apriori.c", first: 68, last: 76,
  caption: [support as a subset scan, one AND and compare per basket])

#diagram([support falls or holds moving up, one infrequent pair executes its whole upper cone], length: 13pt, {
  let node = (x, y, lab, cnt, dead) => {
    cdraw.rect((x - 1.15, y - 0.5), (x + 1.15, y + 0.5),
      fill: if dead {luma(216)} else {luma(242)}, radius: 0.02)
    cdraw.content((x, y + 0.12), lab, size: 5.8pt)
    cdraw.content((x, y - 0.24), cnt, size: 5.8pt)
    if dead {
      cdraw.line((x - 0.9, y - 0.42), (x + 0.9, y + 0.42), stroke: luma(90))
      cdraw.line((x - 0.9, y + 0.42), (x + 0.9, y - 0.42), stroke: luma(90))
    }
  }
  let edge = (a, b) => {
    cdraw.line((a.at(0), a.at(1) - 0.5), (b.at(0), b.at(1) + 0.5),
      stroke: (paint: luma(150)))
  }
  cdraw.content((3.9, 8.35), [all subsets of a frequent set are frequent], size: 6pt)
  node(3.9, 6.9, [{I1,I2,I3}], "=2", false)
  node(1.5, 4.6, [{I1,I2}], "=4", false)
  node(3.9, 4.6, [{I1,I3}], "=4", false)
  node(6.3, 4.6, [{I2,I3}], "=4", false)
  node(1.5, 2.3, [{I1}], "=6", false)
  node(3.9, 2.3, [{I2}], "=7", false)
  node(6.3, 2.3, [{I3}], "=6", false)
  edge((3.9, 6.9), (1.5, 4.6))
  edge((3.9, 6.9), (3.9, 4.6))
  edge((3.9, 6.9), (6.3, 4.6))
  edge((1.5, 4.6), (1.5, 2.3))
  edge((1.5, 4.6), (3.9, 2.3))
  edge((3.9, 4.6), (1.5, 2.3))
  edge((3.9, 4.6), (3.9, 2.3))
  edge((6.3, 4.6), (3.9, 2.3))
  edge((6.3, 4.6), (6.3, 2.3))
  cdraw.content((12.3, 8.35), [the contrapositive at work], size: 6pt)
  node(12.3, 4.6, [{I3,I5}], "=1", true)
  node(10.4, 6.9, [{I1,I3,I5}], [dead], true)
  node(14.2, 6.9, [{I2,I3,I5}], [dead], true)
  cdraw.line((11.0, 5.1), (10.7, 6.4), stroke: (paint: luma(90)), mark: (end: ">"))
  cdraw.line((13.6, 5.1), (13.9, 6.4), stroke: (paint: luma(90)), mark: (end: ">"))
  cdraw.content((12.3, 3.2), [one pair at 1 kills both triples], size: 6pt)
})

#callout("note", "a priori means the prune happens before the scan", [
  Levelwise search never asks the database about a candidate it can
  already reject. The subset law is knowledge about the counting process,
  not about the data, so it applies with zero database access: {I3,I5}
  was counted once, at support 1, and that single fact retires every
  itemset containing I3 and I5 before any of them is ever built. The
  chapters that follow are all attempts to spend even less: the vertical
  lane of #xref-to("kdd", "vector") stops rescanning, and
  #xref-to("kdd", "fpgrowth") stops generating candidates at all.
])

== join, prune, and the killing subsets

Level k candidates are built only from level k-1 survivors. The join
pairs two frequent (k-1)-itemsets that share their first k-2 items in
lexicographic order and unions them. The prune then asks each fresh
candidate whether every one of its (k-1)-subsets survived the last
level, discards it on the first missing subset, and records that subset
as the killer.

The dry run: level 2 joins all ten singleton pairs and the prune has
nothing to kill since every singleton is frequent, printing `C2 gen=10
prune=0 L=6`, then counting finds {I1,I4} at 1, {I3,I4} at 0, {I3,I5} at
1 and {I4,I5} at 0 below the bar. Level 3 starts from the six surviving
pairs. Their joins sharing a first item are {I1,I2,I3}, {I1,I2,I5},
{I1,I3,I5} from the I1 group and {I2,I3,I4}, {I2,I3,I5}, {I2,I4,I5}
from the I2 group, six candidates, and the prune kills four of them:
{I1,I3,I5} and {I2,I3,I5} both die on {I3,I5}, which counted 1,
{I2,I3,I4} dies on {I3,I4} at 0, and {I2,I4,I5} on {I4,I5} at 0. The
line reads `C3 gen=6 prune=4 L=2`, and the check names all four killers
at once, "ch25 C3 prune provenance {I1,I3,I5}/{I2,I3,I5} by {I3,I5},
{I2,I3,I4} by {I3,I4}, {I2,I4,I5} by {I4,I5}". The third counting pass
scores both survivors at exactly the bar, `L3: {I1,I2,I3}=2;{I1,I2,I5}=2`.

Level 4 is where the prune wins outright. The two L3 survivors join into
{I1,I2,I3,I5}, whose subset {I1,I3,I5} counted 1 and never entered L3,
so the candidate dies uncounted: `C4 gen=1 prune=1 L=noscan`.

#listing("kdd/samples/src/Ch25/apriori.c", first: 139, last: 149,
  caption: [the classic join, two survivors sharing their first k-2 items])

#listing("kdd/samples/src/Ch25/apriori.c", first: 150, last: 179,
  caption: [the subset prune, first missing subset recorded as the killer])

#diagram([six joins, four killed by their pairs, two counted at exactly the bar], length: 13pt, {
  let cand = (x, lab, dead) => {
    cdraw.rect((x - 1.15, 6.7), (x + 1.15, 7.7),
      fill: if dead {luma(216)} else {luma(242)}, radius: 0.02)
    cdraw.content((x, 7.2), lab, size: 5.6pt)
    if dead {
      cdraw.content((x, 5.9), [killed], size: 5.6pt)
    }
  }
  cdraw.content((8.6, 8.4), [C3 gen=6 prune=4 L=2], size: 6.5pt)
  cand(1.7, [{I1,I2,I3}], false)
  cand(4.5, [{I1,I2,I5}], false)
  cand(7.3, [{I1,I3,I5}], true)
  cand(10.1, [{I2,I3,I4}], true)
  cand(12.9, [{I2,I3,I5}], true)
  cand(15.7, [{I2,I4,I5}], true)
  cdraw.content((7.3, 5.15), [by {I3,I5}=1], size: 5.6pt)
  cdraw.content((10.1, 5.15), [by {I3,I4}=0], size: 5.6pt)
  cdraw.content((12.9, 5.15), [by {I3,I5}=1], size: 5.6pt)
  cdraw.content((15.7, 5.15), [by {I4,I5}=0], size: 5.6pt)
  cdraw.line((1.7, 6.7), (1.7, 4.7), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.line((4.5, 6.7), (4.5, 4.7), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.rect((0.55, 3.6), (5.65, 4.7), fill: luma(232), radius: 0.02)
  cdraw.content((3.1, 4.4), [scan 3 counts both at 2], size: 5.8pt)
  cdraw.content((3.1, 3.95), [L3: {I1,I2,I3}=2;{I1,I2,I5}=2], size: 5.8pt)
  cdraw.rect((6.4, 1.1), (16.85, 2.5), fill: luma(216), radius: 0.02)
  cdraw.content((11.6, 2.05), [C4: {I1,I2,I3,I5} killed by {I1,I3,I5}=1], size: 5.8pt)
  cdraw.content((11.6, 1.5), [C4 gen=1 prune=1 L=noscan, scan skipped], size: 5.8pt)
  cdraw.line((6.4, 3.0), (6.4, 2.5), stroke: (paint: luma(120)), mark: (end: ">"))
})

#callout("pitfall", "the join silently misses candidates on unsorted input", [
  The shared-first-(k-2) test only pairs {I2,I3} with {I2,I4} if both are
  read in one lexicographic order, which is why the sample sorts every
  level by itemset string before joining. Joining instead on "differ in
  one item" would also work but generates duplicates, and joining on
  nothing at all generates every pair and loses the guarantee that both
  (k-1)-parents of a generated candidate are themselves in L(k-1), the
  property the prune relies on. Order is not cosmetic here, it is half
  the generator.
])

== two ways to stop

The minsup 2 run stops from the top: a candidate set the prune emptied
before scanning. The `L=noscan` in the C4 line is the sheet's spelling
of that, the counting pass over C4 never happens, and `scans=3` counts
the passes over C1, C2, C3 only. The same nine baskets at minsup 3 stop
from the bottom instead, and every number changes shape.

The dry run: level 1 keeps only the three items at 6 or above, `C1
gen=5 prune=0 L=3` and `L1: {I1}=6;{I2}=7;{I3}=6`, I4 and I5 at 2
dropping. With three survivors the join makes three candidates, all
count frequent, `C2 gen=3 prune=0 L=3` and `L2: {I1,I2}=4;{I1,I3}=4;
{I2,I3}=4`. Level 3 joins {I1,I2} with {I1,I3} into one candidate, the
prune passes it since all three of its pairs are frequent, and the scan
counts it at 2 against the bar of 3: `C3 gen=1 prune=0 L=0`. An empty
level by support, so C4 is never generated at all, and the loop ends
with the same `scans=3` but a different third pass, one candidate
counted and rejected rather than two counted and kept. The harvest
shrinks to `fi_count=6 fi_checksum=31`.

#listing("kdd/samples/src/Ch25/apriori.c", first: 180, last: 198,
  caption: [the noscan break against the counting path, scans only step on a real pass])

#listing("kdd/samples/src/Ch25/apriori.c", first: 336, last: 362,
  caption: [minsup 3 on the same baskets, L3 emptied by support not by prune])

#diagram([both runs take three scans and stop for different reasons], length: 13pt, {
  let step = (x, y, txt, dark) => {
    cdraw.rect((x - 2.9, y), (x + 2.9, y + 1.05),
      fill: if dark {luma(216)} else {luma(242)}, radius: 0.02)
    cdraw.content((x, y + 0.52), txt, size: 5.8pt)
  }
  cdraw.content((4.3, 8.4), [minsup 2], size: 6.5pt)
  cdraw.content((12.9, 8.4), [minsup 3], size: 6.5pt)
  step(4.3, 7.0, [C1 gen=5 prune=0 L=5], false)
  step(4.3, 5.5, [C2 gen=10 prune=0 L=6], false)
  step(4.3, 4.0, [C3 gen=6 prune=4 L=2], false)
  step(4.3, 2.5, [C4 gen=1 prune=1 L=noscan], true)
  cdraw.content((4.3, 1.7), [prune emptied C4, scan skipped], size: 5.6pt)
  step(12.9, 7.0, [C1 gen=5 prune=0 L=3], false)
  step(12.9, 5.5, [C2 gen=3 prune=0 L=3], false)
  step(12.9, 4.0, [C3 gen=1 prune=0 L=0], true)
  cdraw.rect((10.0, 2.5), (15.8, 3.55), radius: 0.02, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((12.9, 3.0), [C4 never generated], size: 5.8pt)
  cdraw.content((12.9, 1.7), [L3 empty by support, {I1,I2,I3}=2 < 3], size: 5.6pt)
  for y in (7.0, 5.5, 4.0) {
    cdraw.line((4.3, y), (4.3, y - 0.45), stroke: (paint: luma(120)), mark: (end: ">"))
    cdraw.line((12.9, y), (12.9, y - 0.45), stroke: (paint: luma(120)), mark: (end: ">"))
  }
  cdraw.content((8.6, 0.5), [scans=3 both times, the third pass counts 2 candidates at left, 1 at right], size: 6pt)
})

== thirteen itemsets, three implementations

The minsup 2 run's full harvest is 13 itemsets across three levels, and
the sample folds them into one line sorted by size then itemset string,
the `fi:` line, with checksum 45, the plain sum of all 13 supports. That
line is the point of the whole part: the same nine baskets are mined
again in #xref-to("kdd", "vector") by intersecting transaction lists and
in #xref-to("kdd", "fpgrowth") by recursing through a prefix tree, and
the contract pins all three to byte-identical `fi:` strings with the
same count 13 and checksum 45. Three implementations that share no
machinery agree on every item and every count, which is the strongest
statement a fixture this size can make about an implementation.

The cost accounting explains why two more chapters exist. This chapter's
horizontal layout reads every basket on every pass, three passes here,
testing 5 then 10 then 2 candidates per row. The vertical lane builds
one column per item and never rescans, and fp-growth compresses the
baskets into a tree and grows patterns inside conditional fragments of
it. Same 13 answers, three different bills.

#listing("kdd/samples/src/Ch25/apriori.c", first: 321, last: 334,
  caption: [the fi aggregate, count 13, checksum 45, byte-pinned string])

#diagram([three implementations, one enumeration, the three-way M2 agreement], length: 13pt, {
  let lane = (y, txt) => {
    cdraw.rect((0.55, y), (7.35, y + 1.3), fill: luma(242), radius: 0.02)
    cdraw.content((3.95, y + 0.65), txt, size: 6pt)
    cdraw.line((7.35, y + 0.65), (9.05, 4.3), stroke: (paint: luma(120)), mark: (end: ">"))
  }
  lane(6.9, [ch25 horizontal: 3 scans over 9 baskets])
  lane(4.7, [ch26 vertical: tidlist intersections])
  lane(2.5, [ch28 fp-growth: prefix-tree recursion])
  cdraw.rect((9.05, 2.9), (17.05, 5.7), fill: luma(232), radius: 0.02)
  cdraw.content((13.05, 5.0), [fi: 13 itemsets over M2], size: 6.5pt)
  cdraw.content((13.05, 4.35), [fi_count=13 fi_checksum=45], size: 6.5pt)
  cdraw.content((13.05, 3.6), [byte-identical fi string in all three], size: 6pt)
  cdraw.content((13.05, 3.1), [checks pin it 3 times, once per lane], size: 6pt)
})

sources: the nine-basket table is the running example of Han, Pei, Yin,
Mining Frequent Patterns without Candidate Generation, SIGMOD 2000, TIDs
100-900, https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf, accessed
2026-09-22, pinned by kdd-contract-s6.md for chapters 25, 26 and 28
together so the cross-chapter agreement rows rest on one shared table.
The candidate line format, the noscan and scans semantics, the prune
provenance rows and the minsup 3 run are pinned by the same sheet and
witnessed by playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch25`, 23 checks in chapter 25
of the kdd suite.
