#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= coordinate compression and intervals

Array algorithms want dense indices and the world hands out sparse
coordinates. Two ideas close the gap: compress the coordinates to
their ranks so a billion-wide domain fits a small array, and do
interval algebra on endpoints instead of on the cells between them.
This chapter builds both in seven languages, and one convention is
pinned before anything else. Intervals here are half-open, start
inclusive and end exclusive, so an interval ending at t and one
starting at t share the single point t and never merge or stack. The
c\# and lua suites pin exactly that. The c, go, java, javascript,
and python suites pin the touching-fuses reading for merging, go
even names the type Closed, so a touching pair becomes one interval
there. Every section below names which reading its listings use,
and the matrix anchor, (1,3), (2,6), (8,10) merging to two
intervals, agrees in all seven languages.

== coordinate compression

Sort the raw values, drop duplicates, then rank every value by
binary search into that sorted domain. Three invariants survive the
whole construction: order is preserved, a smaller raw value always
gets a smaller rank, ranks are dense, the largest rank is one under
the distinct count, and the lookup is lossless, domain of rank gives
back the original value. The sort pays n log n once and each rank
costs log k. It wins whenever coordinates are huge but few, chapter
21's fenwick tree, this chapter's difference arrays, and sweep
arrays in chapter 24 all want indices, not values.

The dry run: the fixture is 100, 10, 100, 40, 10, asserted by the
C\# suite with lua on the same numbers, while C and java rank 100,
-50, 100, 7, -50, 30 to 3, 0, 3, 1, 0, 2.

+ Distinct then order builds the domain: 10, 40, 100, three slots
  carrying ranks 0, 1, 2.
+ The rank lookup walks the raw list in input order, one search per
  value: 100 reads slot 2, 10 reads slot 0, 100 slot 2 again, 40
  slot 1, 10 slot 0, landing 2, 0, 2, 1, 0.
+ Duplicates never split: both 10s hold rank 0 and both 100s rank 2,
  one slot per distinct value.
+ The reverse lookup is lossless, domain[2] = 100 and domain[0] =
  10, the round trip the suite pins over negatives through 12.
+ The single value 7 compresses to rank 0 over the one-slot domain
  7, and the empty list compresses to nothing.

#diagram([the run as a pipeline, raw values, sorted with duplicates, the deduped domain, then every raw value ranked in input order], length: 13pt, {
  let strip = (y, label, cells, hot) => {
    cdraw.content((0.9, y + 0.45), label, size: 6pt)
    for (i, cc) in cells.enumerate() {
      let x = 3.4 + i * 1.3
      cdraw.rect((x, y), (x + 1.2, y + 0.9), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.6, y + 0.45), cc, size: 6.5pt)
    }
  }
  strip(7.6, [raw], ([100], [10], [100], [40], [10]), ())
  strip(5.9, [sorted], ([10], [10], [40], [100], [100]), (1, 4))
  strip(4.2, [domain], ([10], [40], [100]), ())
  strip(2.5, [ranks], ([2], [0], [2], [1], [0]), (0, 2))
  cdraw.line((9.8, 7.5), (9.8, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.3, 5.85), (4.0, 5.15), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.line((9.2, 5.85), (6.6, 5.15), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((10.8, 5.5), [duplicates merge], size: 6pt)
  cdraw.line((6.0, 4.1), (6.0, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.4, 1.5), [every raw value binary-searches the domain, ranks in input order], size: 6pt)
  cdraw.content((16.9, 6.4), [sort pays n log n once], size: 6pt)
  cdraw.content((16.9, 5.3), [each rank costs log k], size: 6pt)
  cdraw.content((16.9, 4.2), [domain[2] = 100, lossless], size: 6pt)
  cdraw.content((16.9, 3.1), [c: 3, 0, 3, 1, 0, 2 over four slots], size: 6pt)
  cdraw.content((16.9, 2.0), [a billion-wide domain fits k slots], size: 6pt)
})

2, 0, 2, 1, 0 over 10, 40, 100 is the pinned pair and the listings
below sort, dedupe, and rank in seven languages.

#listing("dsa/samples-c/src/Ch22/coordcompress.c", first: 26, last: 49, caption: [c, qsort then an in-place unique scan, lower bound ranks each value])
#listing("dsa/samples-go/ch22/coordcompress.go", first: 10, last: 19, caption: [go, slices.sort, slices.compact, and slices.binarysearch are the whole build])
#listing("dsa/samples-java/src/Ch22/Coordcompress.java", first: 19, last: 67, caption: [java, arrays.sort then a dedupe scan, a hand lower bound, a stream-distinct lane beside])
#listing("dsa/samples/src/Ch22/Compression.cs", first: 13, last: 23, caption: [c\#, a distinct ordered domain plus a dictionary from value to rank])
#listing("dsa/samples-js/src/ch22-coordcompress.mjs", first: 5, last: 22, caption: [javascript, a set for the uniques, a hand lower bound for the ranks])
#listing("dsa/samples-py/src/Ch22/coordcompress.py", first: 14, last: 30, caption: [python, sorted(set(...)) builds the domain, a closure ranks each value])
#listing("dsa/samples-lua/ch22_coordcompress.lua", first: 8, last: 26, caption: [lua, table.sort, a dedupe scan, a 1-based lower bound shifted back to rank 0])

All seven suites pin the same three invariants on their own
fixtures. C and java compress 100, -50, 100, 7, -50, 30 into ranks
3, 0, 3, 1, 0, 2 over the domain -50, 7, 30, 100. C\# and lua share
the fixture 100, 10, 100, 40, 10 landing at 2, 0, 2, 1, 0 over 10,
40, 100, and C\# asserts the lossless round trip on negatives -5
through 12. Go uses coordinates up to 100000000, python proves
negatives compress too, java's second lane reaches a 1000000
coordinate through `distinct().sorted()` on a stream, and
javascript's lowerBound also answers for absent values, the
insertion point, which is the same search chapter 14 built.
Python's sorted(set(values)) is the whole trick in one expression,
and the domain lookup beside it is a dictionary in C\#, a rank
closure in python, a linear-indexed array in C and java.

#diagram([compression on the c fixture, six raw values ranked into a four slot domain, duplicates share a rank], length: 13pt, {
  // raw 100 -50 100 7 -50 30 -> domain -50 7 30 100, ranks 3 0 3 1 0 2
  let raw = ([100], [-50], [100], [7], [-50], [30])
  let rank = (3, 0, 3, 1, 0, 2)
  let dom = ([-50], [7], [30], [100])
  for (i, v) in raw.enumerate() {
    let x = 1.6 + i * 2.1
    cdraw.rect((x - 0.6, 7.6), (x + 0.6, 8.4), fill: luma(235), radius: 0.02)
    cdraw.content((x, 8.0), v, size: 6.5pt)
    let tx = 2.4 + rank.at(i) * 3.0
    cdraw.line((x, 7.5), (tx, 4.35), stroke: (paint: luma(170), dash: "dashed"), mark: (end: ">"))
    cdraw.content((x, 6.9), [#rank.at(i)], size: 6pt)
  }
  for (j, d) in dom.enumerate() {
    let x = 2.4 + j * 3.0
    cdraw.rect((x - 1.1, 3.6), (x + 1.1, 4.3), fill: luma(205), radius: 0.02)
    cdraw.content((x, 3.95), d, size: 6.5pt)
    cdraw.content((x, 3.1), [#j], size: 6pt)
  }
  cdraw.content((7.0, 2.2), [the sorted unique domain, rank under each slot], size: 6pt)
  cdraw.content((7.0, 1.3), [ranks are dense: 0 to 3], size: 6pt)
  cdraw.content((7.0, 0.4), [domain[rank] restores every value], size: 6pt)
  cdraw.content((17.4, 6.0), [duplicates share a rank], size: 6pt)
  cdraw.content((17.4, 5.1), [order is preserved], size: 6pt)
  cdraw.content((17.4, 4.2), [one sort, log k per lookup], size: 6pt)
  cdraw.content((7.4, 8.9), [raw values], size: 6.5pt)
})

== merging intervals

Sort by start, then fold left to right keeping one open cluster.
Each interval either extends the cluster's right end or starts a new
cluster, so containment and overlap collapse in a single linear
pass after the n log n sort. The one decision that changes answers
is the tie at a shared endpoint. Under the half-open reading a pair
like (1,3) and (3,6) stays two intervals, under the touching-fuses
reading it becomes (1,6), and both are defensible as long as the
code states which one it means.

The dry run: the fixture is (1,3), (2,6), (8,10), asserted by the
C\# suite under the strict fold, with the touching pair (1,3), (3,6)
pinned as two intervals.

+ Sorting by start leaves the fixture in order, and the scrambled
  input (8,10), (2,6), (1,3) folds to the same output.
+ Carry (1,3) open; the next start 2 < 3 overlaps, so the end
  widens to max(3, 6) = 6 and the cluster carries (1,6).
+ The next start 8 fails 8 < 6, so (1,6) is emitted and (8,10)
  opens anew: two intervals out, the pinned count.
+ The touching pair turns on the same comparison, 3 < 3 is false,
  no overlap, two intervals stay two under the half-open reading
  while C, go, java, javascript, and python fuse them.
+ Insert (4,9) into (1,3), (8,10), (15,18): (1,3) ends 3 <= 4 and
  passes through, (8,10) strictly overlaps and widens the item to
  (4,10), and (15,18) starts past 10, emitting (1,3), (4,10),
  (15,18).

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*interval*], [*test*], [*action*], [*carried*]),
  [(1,3)], [first], [open the cluster], [(1,3)],
  [(2,6)], [2 < 3], [widen: max(3, 6) = 6], [(1,6)],
  [(8,10)], [8 < 6 false], [emit, open anew], [(8,10)],
  [(3,6)], [3 < 3 false], [emit, touching stays two], [(3,6)],
)

Two intervals out of three is the pinned merge and the listings
below fold in seven languages.

#listing("dsa/samples-c/src/Ch22/mergeintervals.c", first: 27, last: 45, caption: [c, the fold after qsort, insert appends one interval and remerges])
#listing("dsa/samples-go/ch22/mergeintervals.go", first: 13, last: 31, caption: [go, closed intervals, touching or overlapping absorbs])
#listing("dsa/samples-java/src/Ch22/Mergeintervals.java", first: 18, last: 42, caption: [java, a record interval, sort by start then fold, insert appends and remerges])
#listing("dsa/samples/src/Ch22/Compression.cs", first: 26, last: 39, caption: [c\#, a strict start < end fold, touching pairs stay separate])
#listing("dsa/samples-js/src/ch22-mergeintervals.mjs", first: 4, last: 13, caption: [javascript, sort by start then fold pairs in place])
#listing("dsa/samples-py/src/Ch22/mergeintervals.py", first: 13, last: 26, caption: [python, sorted tuples feed the fold, insert is one re-merge])
#listing("dsa/samples-lua/ch22_mergeintervals.lua", first: 15, last: 27, caption: [lua, the strict fold, the half-open reading stated in the header])

The anchor fixture agrees everywhere, (1,3), (2,6), (8,10) becomes
(1,6) and (8,10) in all seven suites. The touching pair splits
them, C, go, java, javascript, and python fuse (1,2) and (2,3) into
(1,3) while C\# and lua keep two, and go and lua each document the
choice at the type or file level. Inserting into an already merged
list shows three shapes: C and java append the newcomer and rerun
the merge, python and lua rebuild the combined list the same way,
and C\#, go, and javascript walk the sorted list once, widening the
carried interval across every overlap and emitting it before the
first interval that starts past it. Go's insert test pins (4,9)
into (1,3),(8,10) giving (1,3),(4,10), and C\# pins the same seam
with a 15,18 tail.

#diagram([the anchor fixture fusing to two intervals, then one touching pair with both readings, fused or separate], length: 13pt, {
  // axis 0..10, bars (1,3) (2,6) (8,10) -> (1,6) (8,10), and the touching pair below
  let axis = (y, label) => {
    cdraw.line((1.0, y), (13.0, y), stroke: luma(100))
    for t in range(0, 11) {
      cdraw.line((1.0 + t * 1.2, y), (1.0 + t * 1.2, y - 0.12), stroke: luma(100))
      cdraw.content((1.0 + t * 1.2, y - 0.5), [#t], size: 6pt)
    }
    cdraw.content((0.4, y + 0.55), label, size: 6pt)
  }
  let bar = (y, lo, hi, hot) => {
    cdraw.rect((1.0 + lo * 1.2, y), (1.0 + hi * 1.2, y + 0.6), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((1.0 + (lo + hi) * 0.6, y + 0.3), [(#lo, #hi)], size: 6pt)
  }
  axis(7.0, [in])
  bar(7.15, 1, 3, false)
  bar(7.15, 2, 6, false)
  bar(7.15, 8, 10, false)
  axis(5.6, [out])
  bar(5.75, 1, 6, true)
  bar(5.75, 8, 10, false)
  // the touching pair under both readings
  axis(4.1, [tie])
  bar(4.25, 1, 2, false)
  bar(4.25, 2, 3, false)
  cdraw.content((1.0 + 2 * 1.2, 3.55), [t = 2 and t = 3 are shared endpoints], size: 6pt)
  bar(2.55, 1, 3, true)
  cdraw.content((6.4, 2.85), [c, go, javascript, python: fused], size: 6pt)
  bar(1.65, 1, 2, false)
  bar(1.65, 2, 3, false)
  cdraw.content((6.4, 0.95), [c\#, lua: two intervals], size: 6pt)
  cdraw.content((16.0, 6.6), [sort by start, fold once], size: 6pt)
  cdraw.content((16.0, 5.7), [overlap extends the right end], size: 6pt)
  cdraw.content((16.0, 4.2), [the shared endpoint is the], size: 6pt)
  cdraw.content((16.0, 3.7), [whole convention question], size: 6pt)
  cdraw.content((16.0, 1.9), [state the reading, then test it], size: 6pt)
})

== counting overlaps

Two questions about the same intervals. How many cover a point is a
linear scan with the same endpoint test as the merge, half-open
drops the interval exactly at its end. The maximum simultaneous
count is a sweep over events, plus one at every start and minus one
at every end, sorted by coordinate, and the tie rule at equal
coordinates is again the whole convention: ends before starts means
touching intervals never stack, starts before ends means they do.

The dry run: the fixtures are the point probes and the sweep counts
pinned by the C\# suite, while C and java trace their own four
intervals live at 1, 2, 1, 3, 2, 1, 0.

+ The probe at point 3 over (1,4), (2,6), (5,8), (3,7) counts three
  covers, 1 <= 3 < 4, 2 <= 3 < 6, 3 <= 3 < 7, and (5,8) has not
  started, landing 3.
+ At point 4 the first interval drops out because 4 < 4 fails,
  leaving 2 covers, and at 99 nothing covers.
+ The sweep fixture (1,4), (2,5), (3,6), (7,9) posts eight events:
  plus one at 1, 2, 3, 7 and minus one at 4, 5, 6, 9.
+ No coordinate is shared, so the tie rule never fires, and the live
  count steps 1, 2, 3, 2, 1, 0, 1, 0, peaking at 3 when the third
  start lands.
+ Touching (1,3) and (3,5) is the tie rule's proof: the end at 3
  sorts first and live never passes 1.

#diagram([the sweep as a rail of eight events, plus one and minus one, the live count under each event, the peak shaded], length: 13pt, {
  let ev = ((1, [+1], true, 1, false), (2, [+1], true, 2, false), (3, [+1], true, 3, true), (4, [-1], false, 2, false), (5, [-1], false, 1, false), (6, [-1], false, 0, false), (7, [+1], true, 1, false), (9, [-1], false, 0, false))
  for (i, e) in ev.enumerate() {
    let x = 1.8 + i * 2.0
    cdraw.content((x + 0.5, 7.5), [#e.at(0)], size: 6pt)
    cdraw.rect((x, 6.5), (x + 1.0, 7.2), fill: if e.at(2) { luma(235) } else { luma(248) }, stroke: if e.at(2) { none } else { luma(160) }, radius: 0.02)
    cdraw.content((x + 0.5, 6.85), e.at(1), size: 6pt)
    cdraw.line((x + 0.5, 6.4), (x + 0.5, 5.7), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
    cdraw.rect((x, 4.7), (x + 1.0, 5.6), fill: if e.at(4) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.5, 5.15), [#e.at(3)], size: 6pt)
  }
  cdraw.content((1.8, 3.8), [live after each event: 1, 2, 3, 2, 1, 0, 1, 0], size: 6pt)
  cdraw.content((1.8, 2.9), [no shared coordinate, so no tie fires here], size: 6pt)
  cdraw.content((1.8, 2.0), [touching (1,3) and (3,5): the end at 3], size: 6pt)
  cdraw.content((1.8, 1.5), [leaves first, live never passes 1], size: 6pt)
  cdraw.content((16.8, 6.9), [the probe agrees at 3], size: 6pt)
  cdraw.content((16.8, 5.8), [peaks when starts cluster], size: 6pt)
  cdraw.content((16.8, 4.7), [one event per endpoint], size: 6pt)
  cdraw.content((16.8, 3.6), [the comparator is the whole], size: 6pt)
  cdraw.content((16.8, 3.1), [convention question], size: 6pt)
})

Peak 3 by probe and by sweep, and the listings below count both
questions in seven languages.

#listing("dsa/samples-c/src/Ch22/overlaps.c", first: 28, last: 64, caption: [c, the point probe, then events insertion-sorted with ends first])
#listing("dsa/samples-go/ch22/overlaps.go", first: 12, last: 48, caption: [go, a halfopen type, point count and sweep, ends before starts])
#listing("dsa/samples-java/src/Ch22/Overlaps.java", first: 19, last: 58, caption: [java, the half-open point probe, a record event, the comparator ends first, the peak time kept])
#listing("dsa/samples/src/Ch22/Compression.cs", first: 64, last: 88, caption: [c\#, countat under half-open, the sweep orders ties by delta])
#listing("dsa/samples-js/src/ch22-overlaps.mjs", first: 5, last: 30, caption: [javascript, closed point probe, two sorted arrays merged start-first])
#listing("dsa/samples-py/src/Ch22/overlaps.py", first: 16, last: 30, caption: [python, sorted event tuples put -1 ahead of +1 at a tie])
#listing("dsa/samples-lua/ch22_overlaps.lua", first: 6, last: 33, caption: [lua, both passes over half-open pairs, the comparator ends first])

The c and java suites pin the sweep on the same fixture, (1,4),
(2,6), (5,8), (5,7) all half-open: the live count runs 1, 2, 1, 3,
2, 1, 0 and peaks at 3, java naming time 5 as the peak, with a
brute-force max over point probes agreeing. Go peaks at 3 on
(1,4), (2,5), (3,7), (6,8) and lua pins that touching (1,3) and
(3,5) never stack. Python and javascript are the closed-reading
outliers in this section, python counts the last closing point 9
as covered while its sweep still ties ends first, and javascript
ties starts first, so its (1,3) and (3,5) count as simultaneous,
java carrying the closed reading as a second lane beside its
half-open one. Same code shape, opposite answer, entirely decided
by one comparator line.

#diagram([the sweep over the c fixture, four half-open bars, the event trace with the peak of 3 at time 5], length: 13pt, {
  // fixture (1,4) (2,6) (5,8) (5,7), trace 1 2 1 3 2 1 0
  let bars = ((1, 4, [(1,4)]), (2, 6, [(2,6)]), (5, 8, [(5,8)]), (5, 7, [(5,7)]))
  for (r, b) in bars.enumerate() {
    let (lo, hi, lab) = b
    let y = 7.3 - r * 0.75
    cdraw.rect((1.0 + lo * 1.35, y), (1.0 + hi * 1.35, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((1.0 + (lo + hi) * 0.675, y + 0.28), lab, size: 6pt)
  }
  cdraw.line((1.0 + 5 * 1.35, 4.1), (1.0 + 5 * 1.35, 8.1), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((1.0 + 5 * 1.35, 8.5), [t = 5], size: 6pt)
  // the event trace as a stepped line
  let ev = ((1, 1), (2, 2), (4, 1), (5, 3), (6, 2), (7, 1), (8, 0))
  let px = t => 1.0 + t * 1.35
  let py = c => 0.8 + c * 0.55
  for t in range(0, 9) {
    cdraw.line((px(t), 0.6), (px(t), 0.72), stroke: luma(200))
  }
  for c in range(0, 4) {
    cdraw.content((0.6, py(c)), [#c], size: 6pt)
  }
  for (i, (t, c)) in ev.enumerate() {
    if i > 0 {
      let (t0, c0) = ev.at(i - 1)
      cdraw.line((px(t0), py(c0)), (px(t), py(c0)), stroke: luma(120))
      cdraw.line((px(t), py(c0)), (px(t), py(c)), stroke: luma(120))
    }
    cdraw.circle((px(t), py(c)), radius: 0.07, fill: if c == 3 { luma(100) } else { luma(150) })
  }
  cdraw.circle((px(5), py(3)), radius: 0.22, stroke: luma(60))
  cdraw.content((1.0 + 5 * 1.35, 2.9), [peak 3], size: 6pt)
  cdraw.content((17.0, 7.3), [plus one at every start], size: 6pt)
  cdraw.content((17.0, 6.4), [minus one at every end], size: 6pt)
  cdraw.content((17.0, 5.5), [ends leave before starts enter], size: 6pt)
  cdraw.content((17.0, 4.6), [so touching never stacks], size: 6pt)
  cdraw.content((17.0, 3.0), [the trace: 1, 2, 1, 3, 2, 1, 0], size: 6pt)
  cdraw.content((17.0, 2.1), [brute force over points agrees], size: 6pt)
})

== the difference array

Flip a stream of range adds into two point writes each. Adding delta
over lo through hi writes plus delta at lo and minus delta at hi plus
one, and a single prefix-sum pass materializes the final array, so m
range adds over n cells cost m plus n instead of m times n. The
invariant is the telescoping one, every cell's value is the running
sum of writes to its left, and the array carries one extra slot so a
range ending at the last cell still has somewhere to subtract.

The dry run: the fixture is a 6-cell array under three range adds,
asserted by the C\# suite at 2, 5, 5, 2, 2, -1.

+ Add(0, 2, 2) writes two slots: plus 2 at diff[0], minus 2 at
  diff[3].
+ Add(1, 4, 3) writes plus 3 at diff[1] and minus 3 at diff[5].
+ Add(3, 5, -1) writes minus 1 at diff[3] and plus 1 at diff[6], the
  extra seventh slot taking the subtract past the end.
+ The backing array now reads 2, 3, 0, -3, 0, -3, 1 over slots 0
  through 6.
+ One prefix pass materializes the answer: 2, 2 + 3 = 5, 5, 5 - 3 =
  2, 2, 2 - 3 = -1, pinned, and the seventh slot's running sum
  returns to 0.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*op*], [*plus at*], [*minus at*], [*diff now*]),
  [add 2 over 0 to 2], [diff[0] + 2], [diff[3] - 2], [2, 0, 0, -2, 0, 0, 0],
  [add 3 over 1 to 4], [diff[1] + 3], [diff[5] - 3], [2, 3, 0, -2, 0, -3, 0],
  [add -1 over 3 to 5], [diff[3] - 1], [diff[6] + 1], [2, 3, 0, -3, 0, -3, 1],
)

2, 5, 5, 2, 2, -1 out of six writes and one pass, and the listings
below range-add in seven languages.

#listing("dsa/samples-c/src/Ch22/diffarray.c", first: 20, last: 32, caption: [c, two writes per range add, one running sum, inclusive bounds])
#listing("dsa/samples-go/ch22/diffarray.go", first: 15, last: 30, caption: [go, add takes the half-open \[lo, hi), one prefix pass])
#listing("dsa/samples-java/src/Ch22/Diffarray.java", first: 15, last: 58, caption: [java, two writes per add with the hi-plus-one guarded, one prefix pass, a naive-sweep lane])
#listing("dsa/samples/src/Ch22/Compression.cs", first: 107, last: 125, caption: [c\#, bounds checks throw, a plus-one backing array])
#listing("dsa/samples-js/src/ch22-diffarray.mjs", first: 5, last: 18, caption: [javascript, one function from ops to the materialized array])
#listing("dsa/samples-py/src/Ch22/diffarray.py", first: 13, last: 27, caption: [python, inclusive bounds, hi plus one, class and helper])
#listing("dsa/samples-lua/ch22_diffarray.lua", first: 13, last: 30, caption: [lua, 1-based cells shift both writes, nil-safe reads in the fold])

The c and java suites pin the whole pipeline, plus 5 over 0 to 2,
plus 3 over 1 to 4, minus 2 over 3 to 6 leaves the difference array
5, 3, 0, -7, 0, -3, 0, 2 and materializes to 5, 8, 8, 1, 1, -2,
-2, 0. Python, java, and lua cross-check every single range against
a naive cell-by-cell sweep, which is the discipline
that catches an off-by-one at either endpoint. The range convention
splits by language here, C, C\#, java, javascript, python, and lua
take inclusive bounds and write at hi plus one, go alone takes the
half-open [lo, hi) and writes at hi. Lua refuses reversed or
out-of-bounds ranges with error and C\# with an exception, the
other five trust the caller.

#diagram([three range adds as brackets, the difference array they leave, and the prefix pass that materializes the answer], length: 13pt, {
  // +5 [0,2] +3 [1,4] -2 [3,6], diff 5 3 0 -7 0 -3 0 2, out 5 8 8 1 1 -2 -2 0
  let adds = ((0, 2, [+5]), (1, 4, [+3]), (3, 6, [-2]))
  for (r, a) in adds.enumerate() {
    let (lo, hi, d) = a
    let y = 8.0 - r * 0.7
    cdraw.line((1.4 + lo * 1.5, y), (1.4 + (hi + 1) * 1.5, y), stroke: luma(100), mark: (end: ">"))
    cdraw.line((1.4 + lo * 1.5, y - 0.15), (1.4 + lo * 1.5, y + 0.15), stroke: luma(100))
    cdraw.line((1.4 + (hi + 1) * 1.5, y - 0.15), (1.4 + (hi + 1) * 1.5, y + 0.15), stroke: luma(100))
    cdraw.content((1.4 + (lo + hi + 1) * 0.75, y + 0.28), [d over #lo to #hi], size: 6pt)
  }
  let diff = (5, 3, 0, -7, 0, -3, 0, 2)
  let out = (5, 8, 8, 1, 1, -2, -2, 0)
  for i in range(8) {
    let x = 1.4 + i * 1.5
    cdraw.rect((x, 4.4), (x + 1.5, 5.2), fill: if i in (0, 3, 5, 7) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 4.8), [#diff.at(i)], size: 6pt)
    cdraw.rect((x, 2.6), (x + 1.5, 3.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.75, 3.0), [#out.at(i)], size: 6pt)
    if i > 0 {
      cdraw.line((x - 0.75, 3.4), (x - 0.75, 4.4), stroke: none)
    }
    cdraw.content((x + 0.75, 2.25), [#i], size: 6pt)
  }
  cdraw.line((1.4, 5.9), (1.4, 5.35), stroke: luma(120), mark: (end: ">"))
  cdraw.content((2.6, 5.65), [two writes per add: +delta at lo, -delta at hi+1], size: 6pt)
  cdraw.line((2.9, 4.3), (2.9, 3.5), stroke: luma(120), mark: (end: ">"))
  cdraw.content((4.6, 3.95), [one prefix pass], size: 6pt)
  cdraw.content((1.2, 1.5), [running sums: 5, 8, 8, 1, 1, -2, -2, then back to 0], size: 6pt)
  cdraw.content((16.6, 4.8), [shaded: written cells], size: 6pt)
  cdraw.content((16.6, 3.9), [empty range writes nothing], size: 6pt)
  cdraw.content((16.6, 3.0), [m adds over n cells cost m + n], size: 6pt)
  cdraw.content((16.6, 1.5), [no updates, all zeros], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's four sample files, test scripts included where the language
embeds them in the same file:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [254], [`qsort` + fixed arrays], [int coordinates, buffers sized to the fixture, inclusive ranges],
  [c\#], [99], [`List<(long,long)>`, `Dictionary<long,int>`], [tests live in a separate project, bounds checks throw],
  [go], [123], [the `slices` package], [`add` takes the half-open \[lo, hi), the one range convention that differs],
  [java], [397], [jdk 27 stdlib], [records carry the interval and event, the touching-fuses reading, the sweep keeps its peak time, both overlap readings in one file],
  [javascript], [81], [`Array` + `Set`], [number coordinates, closed overlap reading, starts tie first],
  [python], [174], [`list`, `set`, `dict`], [native ints, inclusive ranges, brute-force cross-checks],
  [lua], [215], [`table` + `table.sort`], [1-based cells shift every write, `error()` refuses bad ranges],
)

sources: learn.microsoft.com for tuples and `Dictionary<long,int>`,
go.dev for `slices.Sort`, `slices.Compact`, `slices.BinarySearch`,
developer.mozilla.org for `Set` and `Array.prototype.sort`,
docs.python.org for `sorted` and `set`, lua.org for `table.sort` and
`table.unpack`, accessed 2026-09-14. Sample behavior verified by the
seven suite gates scoped to chapter 22: c 4 files and 44 checks,
c\# 11 tests, go 14 tests, java 4 files and 76 checks, javascript
12 tests, python 4 files and 43 asserts, lua 16 checks, zero
skipped.
