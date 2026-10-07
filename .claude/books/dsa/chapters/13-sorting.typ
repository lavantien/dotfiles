#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= sorting

Sorting is where complexity analysis meets constant factors and input
distributions. This chapter builds the canonical sorts with comparison
counters attached, then measures what actually distinguishes them:
adaptivity, stability, worst cases, and the no-comparison radix path.

== insertion, the baseline

Shift each element left until it lands. Quadratic worst case, linear
on nearly sorted input, stable by construction.

The dry run: the comparison counts are the contract, identical
literals in all seven suites. Sorted 0 through 4999 costs exactly
4999 comparisons with zero shifts, 5, 4, 3, 2, 1 costs 10, 3, 1, 2
costs 3, 2, 1, 3, 1, 2 costs 7, and 4, 2, 2, 1 costs 6, every
output sorted. The bound lane holds n-1 through n(n-1)/2 on a
shuffled 500 from each tree's own deterministic shuffle, and the Go
and Java lanes return the (comparisons, shifts) pair so their
zero-shift rows assert the adaptive side directly. The C\# meter
keeps its sorted, shuffled, and binary runs, binary insertion held
under 140000 probes.

+ The adaptive fixture is 0 through 4999, already ascending.
+ Each pass compares the newcomer once against its left neighbor,
  smaller, and stops: 5000 - 1 = 4999 comparisons with zero shifts,
  both asserted exactly.
+ The 500-shuffle bounds the meter, at least the n - 1 = 499 floor
  and at most 500 × 499 / 2 = 124750, the triangular price of the
  fully reversed shape.
+ Binary insertion takes 10000 ascending keys and halves for the slot
  instead of walking, about 13.3 probes per element, the meter held
  under 14 × 10000 = 140000.
+ The shifts survive the trade unchanged, only the search turned
  logarithmic.

#diagram([the walk length per element, flat one-hop walks on sorted input against the growing staircase of the reversed shape], length: 13pt, {
  cdraw.content((0.7, 6.6), [sorted], size: 6.5pt)
  for i in range(6) {
    cdraw.rect((2.8 + i * 1.3, 6.0), (2.8 + (i + 1) * 1.3, 6.7), fill: luma(235), radius: 0.02)
  }
  for i in range(1, 6) {
    cdraw.line((2.8 + i * 1.3 - 0.35, 5.7), (2.8 + (i - 1) * 1.3 + 0.35, 5.7), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.4, 6.35), [one compare each], size: 6pt)
  cdraw.content((11.4, 5.7), [4999 total, zero shifts], size: 6pt)
  cdraw.content((0.7, 3.4), [reversed], size: 6.5pt)
  let rev = (5, 4, 3, 2, 1)
  for (i, v) in rev.enumerate() {
    cdraw.rect((2.8 + i * 1.3, 2.8), (2.8 + (i + 1) * 1.3, 3.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.8 + i * 1.3 + 0.65, 3.15), [#v], size: 6pt)
  }
  cdraw.content((2.8 + 5 * 1.3 + 0.7, 3.15), [then 0 arrives], size: 6pt)
  for k in range(1, 5) {
    let y = 2.2 - k * 0.45
    cdraw.line((2.8 + k * 1.3 + 0.65, y), (2.8 + 0.65, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((2.8 + k * 1.3 + 1.0, y), if k == 1 { [1 hop] } else { [#k hops] }, size: 6pt)
  }
  cdraw.content((11.4, 1.4), [1 + 2 + 3 + 4 = 10 for five keys], size: 6pt)
  cdraw.content((11.4, 0.5), [500 × 499 / 2 = 124750 for the 500s], size: 6pt)
})

The exact 4999 with zero shifts is the pinned pair, and the listings
below are the metered runs that produce it seven ways.

#listing("dsa/samples-c/src/Ch13/insertion.c", first: 21, last: 41, caption: [c, the counted walk, shifts reported through an out parameter])

#listing("dsa/samples-go/ch13/insertion.go", first: 3, last: 39, caption: [go, comparisons and shifts returned as a pair, the pinned lcg shuffle beside it])

#listing("dsa/samples-java/src/Ch13/Insertion.java", first: 18, last: 38, caption: [java, comparisons and shifts returned as a record, the coprime-multiplier shuffle inline])

#listing("dsa/samples/src/Ch13/Sorting.cs", first: 7, last: 49, caption: [c\#, insertion sort, then binary insertion with logarithmic slot search])

The comparison counters make both natures visible in tests: sorted
input costs exactly n-1 comparisons with zero shifts, the adaptive
best case, and binary insertion cuts the search to logarithmic while
keeping the same shifts. Insertion sort is not a museum piece, it is
the finisher inside quicksort below and inside many library sorts,
because small ranges are where it wins.

#listing("dsa/samples-js/src/ch13-insertion.mjs", first: 1, last: 21, caption: [javascript, the meter object carries the shift count])

#listing("dsa/samples-py/src/Ch13/insertion.py", first: 14, last: 37, caption: [python, the counted walk, the 64-bit lcg feeding the bound lane])

#listing("dsa/samples-lua/ch13_insertion.lua", first: 6, last: 42, caption: [lua, the pair returned, table.sort as the bound lane's ground truth])

Measured across the suites: all seven pin the counted ladder, 4999 on
the sorted 5000 with the array left untouched, 10 on the reversed
five, 3 on 3, 1, 2, 7 on 2, 1, 3, 1, 2, and 6 on 4, 2, 2, 1, the
equal break stopping each duplicate walk early. The bound lane holds
on each tree's own deterministic shuffle, Go and Python sharing the
pinned 64-bit lcg constants, Lua a 31-bit one, and C and Java a
coprime multiplier permutation built inline. The meter rides
differently per tree: Go, Java, and Lua return comparisons and
shifts as a pair, Java's as a record, C writes the shifts through an
out parameter, JavaScript bumps an optional meter object, and Python
and C\# return the comparison count alone.

#diagram([insertion sort, one element walks the sorted prefix leftward, shifting as it goes], length: 13pt, {
  // 4 walks left through 3 5 8: two shifts, then it lands
  cdraw.content((9.6, 7.3), [sorted prefix], size: 6pt)
  let states = (
    ((3, 5, 8, 4), 3, [4 walks]),
    ((3, 5, none, 8), 3, [8 shifts]),
    ((3, none, 5, 8), 3, [5 shifts]),
    ((3, 4, 5, 8), 4, [4 lands]),
  )
  for (r, row) in states.enumerate() {
    let (vals, live, label) = row
    let y = 6.4 - r * 1.1
    for (i, v) in vals.enumerate() {
      if v == none {
        cdraw.rect((8.2 + i * 0.95, y - 0.45), (8.2 + (i + 1) * 0.95, y + 0.45), stroke: luma(220), radius: 0.02)
      } else {
        let hot = (i == 3 and r == 0) or (i == 1 and r == 3)
        cdraw.rect((8.2 + i * 0.95, y - 0.45), (8.2 + (i + 1) * 0.95, y + 0.45), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
        cdraw.content((8.2 + i * 0.95 + 0.475, y), [#v], size: 6pt)
      }
    }
    cdraw.content((3.4, y), label, size: 6pt)
  }
  cdraw.content((8.5, 1.5), [sorted input: n - 1 comparisons, zero shifts], size: 6pt)
  cdraw.content((8.0, 0.4), [reversed input: the triangular number], size: 6pt)
})

== merge sort, with inversions

Split, sort halves, merge. Stable, linearithmic, guaranteed, at the
price of the buffer. The merge is also a measuring instrument: every
time an element is taken from the right half, it stands inverted with
every remaining element of the left half, so the merge counts
inversions exactly.

The dry run: the fixtures are the C\# reversed and sorted hundreds
plus the interleaved tag set, asserted by the C\# suite; C, Java,
and Lua walk a 5-pair set to ids 4 1 3 0 2 and Go, JavaScript, and
Python pin the same tie rule on interleaved ids.

+ The reversed fixture, 99 down to 0, holds every pair inverted: the
  counter lands 100 × 99 / 2 = 4950.
+ At the top merge run 99..50 meets run 49..0, and every right take
  charges the whole remaining left run: 50 × 50 = 2500 cross pairs
  counted here, the halves carrying 4950 - 2500 = 2450 down.
+ The sorted twin, 0 through 99, takes only from the left: 0
  inversions, asserted equal.
+ The stability fixture interleaves (2, a), (1, b), (2, c), (1, d),
  (2, e), (1, f), and the halves sort to 1 b 2 a 2 c against 1 d 1 f
  2 e.
+ The merge reads the equal 1s as a tie and keeps the left, b before
  d, then f, and the 2s ride through a c e: the pinned order b d f a
  c e.

#diagram([the top merge of the reversed run with the whole-run charge, and the tie read that keeps the left half first], length: 13pt, {
  cdraw.content((6.4, 7.5), [the top merge of 99 down to 0], size: 6.5pt)
  cdraw.rect((0.8, 6.4), (6.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 6.75), [99 .. 50], size: 6pt)
  cdraw.rect((7.6, 6.4), (13.0, 7.1), fill: luma(205), radius: 0.02)
  cdraw.content((10.3, 6.75), [49 .. 0], size: 6pt)
  cdraw.line((6.5, 6.75), (7.3, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.8, 5.5), [each take from the right charges every], size: 6pt)
  cdraw.content((0.8, 4.8), [survivor of the left: 50 × 50 = 2500 here], size: 6pt)
  cdraw.content((0.8, 4.1), [the halves carry 2450 down], size: 6pt)
  cdraw.content((0.8, 3.4), [total 100 × 99 / 2 = 4950, sorted twin 0], size: 6pt)
  let chip = (x, y, t, hot) => {
    cdraw.rect((x, y - 0.3), (x + 1.05, y + 0.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.52, y), t, size: 6pt)
  }
  cdraw.content((6.4, 2.4), [the tie read], size: 6.5pt)
  cdraw.content((0.9, 1.7), [left], size: 6pt)
  chip(2.0, 1.7, [1 b], true)
  chip(3.15, 1.7, [2 a], false)
  chip(4.3, 1.7, [2 c], false)
  cdraw.content((0.9, 0.8), [right], size: 6pt)
  chip(2.0, 0.8, [1 d], true)
  chip(3.15, 0.8, [1 f], false)
  chip(4.3, 0.8, [2 e], false)
  cdraw.content((7.6, 1.7), [equal keys: the left run wins], size: 6pt)
  cdraw.content((7.6, 0.8), [output b d f a c e], size: 6pt)
})

The 4950 against the sorted 0 and the tag order b d f a c e are the
C\# pins, and the listings below merge in seven languages.

#listing("dsa/samples-c/src/Ch13/mergesort.c", first: 23, last: 42, caption: [c, stable merge of key and id pairs, halves to tmp and back])

#listing("dsa/samples-go/ch13/mergesort.go", first: 10, last: 33, caption: [go, the left run wins ties, appended into one buffer])

#listing("dsa/samples-java/src/Ch13/Mergesort.java", first: 21, last: 41, caption: [java, stable merge of record pairs, ties from the left, halves to tmp and back])

#listing("dsa/samples/src/Ch13/Sorting.cs", first: 51, last: 96, caption: [c\#, merge sort returning comparisons and the exact inversion count])

The reversed-array test asserts the triangular number, every pair
inverted, and the sorted-array test asserts zero. Inversion counting
is the canonical divide and conquer that is not a sort but rides one,
and the stability test proves the strict-less rule in the merge keeps
equal keys in input order.

#listing("dsa/samples-js/src/ch13-mergesort.mjs", first: 5, last: 23, caption: [javascript, tmp array per merge, ties from the left])

#listing("dsa/samples-py/src/Ch13/mergesort.py", first: 13, last: 33, caption: [python, merge over (key, tag) tuples, the tie keeps the left run])

#listing("dsa/samples-lua/ch13_mergesort.lua", first: 6, last: 30, caption: [lua, inclusive bounds, one shared tmp])

Measured across the suites: every version sorts tagged pairs and
pins the tie rule. C, Java, and Lua feed (5,0) (3,1) (5,2) (3,3)
(1,4) and land ids 4 1 3 0 2, an all-equal run riding through
untouched. Python pins (2,a) (1,b) (2,c) (1,d) to b d a c, Go and
JavaScript pin the same shape with numeric ids, and the frozen C\#
suite counts comparisons and inversions, the reversed fixture
hitting the triangular number. The tie decision is one character
everywhere, less-or-equal, and the left run wins.

#diagram([merge sort counting inversions, every take from the right charges the remaining left half], length: 13pt, {
  // left 1 3 5 against right 2 4 6: two right takes, three inversions
  let strip = (vals, y, hot-indices) => {
    for (i, v) in vals.enumerate() {
      cdraw.rect((2.2 + i * 1.0, y - 0.42), (2.2 + (i + 1) * 1.0, y + 0.42), fill: if i in hot-indices { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((2.2 + i * 1.0 + 0.5, y), [#v], size: 6pt)
    }
  }
  cdraw.content((0.8, 6.7), [left], size: 6pt)
  strip((1, 3, 5), 6.7, ())
  cdraw.content((0.8, 5.4), [right], size: 6pt)
  strip((2, 4, 6), 5.4, ())
  cdraw.line((6.8, 6.05), (6.8, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.4, 4.8), [merge], size: 6pt)
  cdraw.content((0.8, 3.2), [out], size: 6pt)
  strip((1, 2, 3, 4, 5, 6), 3.2, (1, 3))

  cdraw.content((14.0, 6.7), [take 2 from right: +2 inversions], size: 6pt)
  cdraw.content((14.0, 5.6), [take 4 from right: +1], size: 6pt)
  cdraw.content((14.0, 4.5), [total 3 inversions], size: 6pt)
  cdraw.content((14.0, 3.4), [strict less keeps it stable], size: 6pt)
  cdraw.content((14.0, 2.3), [reversed input hits n(n-1)/2], size: 6pt)
})

== quicksort, defended

Hoare partition with median-of-three pivots, an insertion cutoff for
small ranges, and a tail loop instead of the right recursion.

The dry run: the fixture is the C\# meter over 20000 sorted keys plus
the four adversarial shapes at 2000; the siblings sort smaller
fixtures, C, Java, JavaScript, and Lua on nine keys and Go and
Python against library ground truth.

+ The metered run is 0 through 19999, already sorted, the shape a
  first-element pivot murders: peeling one element per partition
  costs 20000 × 19999 / 2 = 199990000 comparisons.
+ Median of three probes the ends and the middle, 0, 9999, and
  19999, sorts the trio in place, and pivots on 9999, the true
  median: the split lands nearly even.
+ The range halves per level, depth about 14, ranges under 8 fall to
  insertion, and the meter stops under 2000000, the pinned bound.
+ The same defense holds at 2000 on random, sorted, reversed, and
  all-equal input, hoare's crossing cursors splitting the repeated
  pivots between the sides instead of peeling them.

#diagram([the depth profile on sorted input, the one-per-level peel of a first-element pivot against the halving of median of three], length: 13pt, {
  cdraw.content((4.0, 7.5), [first-element pivot], size: 6.5pt)
  for r in range(8) {
    let w = 6.4 - r * 0.75
    cdraw.rect((0.8, 6.6 - r * 0.72), (0.8 + w, 7.2 - r * 0.72), fill: luma(235), radius: 0.02)
  }
  cdraw.content((4.0, 0.3), [peels one per level, depth 20000], size: 6pt)
  cdraw.content((4.0, -0.5), [199990000 comparisons], size: 6pt)
  cdraw.content((17.0, 7.5), [median of three], size: 6.5pt)
  for r in range(5) {
    let w = 8.0 / calc.pow(2, r)
    cdraw.rect((17.0 - w / 2, 6.6 - r * 1.1), (17.0 + w / 2, 7.2 - r * 1.1), fill: if r == 0 { luma(235) } else if r == 1 { luma(225) } else { luma(215) }, radius: 0.02)
  }
  cdraw.content((17.0, 0.9), [halves per level, depth about 14], size: 6pt)
  cdraw.content((17.0, 0.1), [under 2000000 comparisons], size: 6pt)
  cdraw.line((8.9, 3.8), (12.0, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.4, 4.3), [one probe trio], size: 6pt)
})

Staying under 2000000 where the naive run pays 199990000 is the
pinned gap, and the listings below partition in seven languages.

#listing("dsa/samples-c/src/Ch13/quicksort.c", first: 24, last: 58, caption: [c, plain hoare, then the median-of-three variant])

#listing("dsa/samples-go/ch13/quicksort.go", first: 24, last: 62, caption: [go, median of three by sorting three values, the hoare sweep])

#listing("dsa/samples-java/src/Ch13/Quicksort.java", first: 18, last: 55, caption: [java, plain hoare on the first element, then the median-of-three variant])

#listing("dsa/samples/src/Ch13/Sorting.cs", first: 98, last: 179, caption: [c\#, quicksort driver, median-of-three hoare partition, the small-range cutoff])

The defenses matter because naive quicksort is quadratic on sorted
input, first-element pivot plus already ordered data means every
partition peels off one element. The test pins the fix at the meter:
twenty thousand sorted elements sort under two million comparisons,
where the naive version would burn about two hundred million. The
all-equal test matters too, Hoare handles repeated pivots without
crossing into quadratic behavior, where Lomuto's scheme does not.

#listing("dsa/samples-js/src/ch13-quicksort.mjs", first: 12, last: 33, caption: [javascript, hoare around a pivot value, first element plain])

#listing("dsa/samples-py/src/Ch13/quicksort.py", first: 14, last: 43, caption: [python, hoare partition, pivot from the middle by default])

#listing("dsa/samples-lua/ch13_quicksort.lua", first: 7, last: 45, caption: [lua, repeat-until cursors, plain and median-of-three])

Measured across the suites: C, Java, JavaScript, and Lua sort
5 2 8 1 9 3 7 4 6 to 1 through 9 under plain Hoare and again under
median-of-three, duplicates 3 1 2 3 1 landing 1 1 2 3 3, and prove
the permutation with sum and xor. Go runs five fixtures including
the sorted-input worst case against slices.Sort ground truth and
unit-tests the median probe itself, and Python runs seven fixtures
from negatives to all-equal with sorted() as the cross-check, its
default pivot the middle value rather than the first. The frozen
C\# suite is the only one that meters comparisons.

#diagram([quicksort defended, median of three, hoare cursors meet in the middle, small ranges fall to insertion], length: 13pt, {
  // 9 3 15 2 11 7: pivot 9, two swaps, cursors cross
  let states = (
    ((9, 3, 15, 2, 11, 7), (0, 2, 5), [median of three: 9]),
    ((7, 3, 15, 2, 11, 9), (5,), [swap 9 and 7]),
    ((7, 3, 2, 15, 11, 9), (2, 3), [swap 15 and 2]),
  )
  for (r, row) in states.enumerate() {
    let (vals, hot, label) = row
    let y = 6.5 - r * 1.1
    for (i, v) in vals.enumerate() {
      cdraw.rect((8.2 + i * 0.95, y - 0.45), (8.2 + (i + 1) * 0.95, y + 0.45), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((8.2 + i * 0.95 + 0.475, y), [#v], size: 6pt)
    }
    cdraw.content((3.4, y), label, size: 6pt)
  }
  cdraw.content((9.6, 3.3), [< 9], size: 6pt)
  cdraw.content((12.5, 3.3), [>= 9], size: 6pt)

  cdraw.content((18.0, 6.5), [under 8 elements:], size: 6pt)
  cdraw.content((18.0, 5.4), [insertion finishes], size: 6pt)
  cdraw.content((18.0, 4.3), [tail loop replaces], size: 6pt)
  cdraw.content((18.0, 3.2), [the right recursion], size: 6pt)
  cdraw.content((18.0, 2.1), [sorted 20k: under 2m], size: 6pt)
  cdraw.content((18.0, 1.0), [comparisons], size: 6pt)
})

#callout("warning", "quicksort is not stable", [
  Partitioning moves elements past each other without regard to
  original order, so equal keys can swap positions. .NET's
  `Array.Sort` is an introsort, quicksort with a heapsort fallback,
  and is documented unstable. When stability matters the BCL answer
  is LINQ's `OrderBy`, documented stable, at the cost of a full
  buffer. The suite pins both behaviors.
])

== quickselect

The quicksort partition already knows how to split a range around a
pivot. Selection is the question that needs only one half of it: to
find the k-th smallest, partition once, keep the side that contains
the k-th slot, and drop the rest on the floor. Hoare's split with the
same median-of-three pivot as the defended quicksort above serves
unchanged, and each round costs one pass over the surviving range, so
the expected total is n plus n over 2 plus n over 4, a geometric sum
landing at expected O(n), with the quadratic worst case stated and
unfixed, the same risk profile as the sort.

The dry run: the fixture is 7, 1, 5, 3, 9, 2, 8, 6, 4 with k = 5
plus the duplicate and all-equal sets, asserted by the C\# suite and
pinned the same way in all six siblings.

+ Round 1 on the 9-wide range: median of three probes 7, 9, and 4,
  parks 9 at the far end, and pivots on 7, the hoare sweep swaps the
  pivot with 6 and the cursors cross at split 5.
+ The left side holds 5 - 0 + 1 = 6 cells, k = 5 fits inside, so hi
  tightens to 5 and k keeps its numbering.
+ Round 2 sees a 6-wide range, under the cutoff of 8: insertion
  sorts 4, 1, 5, 3, 6, 2 in place and the slot reads a[4] = 5, the
  median.
+ The right side 8, 7, 9 is dropped on the floor unread, the three
  elements the run never touches.
+ The duplicates 3, 1, 3, 2, 3 ride the insertion lane whole: k = 2
  reads a[1] = 2, k = 4 reads a[3] = 3, and the all-equal 5s answer
  5 for every k, the trap that demands a shrinking range.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*round*], [*range*], [*action*], [*k*], [*lands*]),
  [1], [0..8], [pivot 7, split at 5], [5], [left keeps it],
  [2], [0..5], [insertion finish], [5], [a[4] = 5],
  [dups], [0..4], [insertion finish], [2], [a[1] = 2],
  [dups], [0..4], [insertion finish], [4], [a[3] = 3],
  [all-equal], [0..3], [insertion finish], [1..4], [5 every time],
)

The median 5 read off the 9-wide fixture is the pinned answer, and
the listings below select in seven languages.

#listing("dsa/samples-c/src/Ch13/quickselect.c", first: 43, last: 73, caption: [c, hoare around the median-of-three pivot, then the single-sided loop])
#listing("dsa/samples-go/ch13/quickselect.go", first: 3, last: 21, caption: [go, the whole loop over the shared hoare partition])
#listing("dsa/samples-java/src/Ch13/Quickselect.java", first: 43, last: 73, caption: [java, hoare around the median-of-three pivot, then the single-sided loop])
#listing("dsa/samples/src/Ch13/Sorting.cs", first: 217, last: 247, caption: [c\#, the small-range insertion finish, the k renumbered inside the right side])
#listing("dsa/samples-js/src/ch13-quickselect.mjs", first: 10, last: 32, caption: [javascript, the partition imported from the quicksort module, the recursion])
#listing("dsa/samples-py/src/Ch13/quickselect.py", first: 15, last: 42, caption: [python, the hoare loop, the trio-sorted pivot, the kept side])
#listing("dsa/samples-lua/ch13_quickselect.lua", first: 9, last: 38, caption: [lua, the pivot rule in-file, the loop in 1-based indices])

The equal-keys trap is the one that bites: an all-equal array must
still shrink the range every round or the loop never ends. Hoare's
split guarantees it here, the crossing cursors always leave at least
one element on each side, and the three-way-partition alternative that
handles repeated keys by grouping them is the standard note. The
fixture families pin it: 7, 1, 5, 3, 9, 2, 8, 6, 4 answers k = 1
through 9 with 1 through 9 against the sorted ground truth, k = 5
reading the median 5; the duplicates 3, 1, 3, 2, 3 answer k = 2 with 2
and k = 4 with 3; all-equal 5, 5, 5, 5 answers 5 for every k and a
single 42 answers itself; and a seeded lcg permutation of 40 elements
matches sorted\[k-1\] on five sampled k. The permutation's lcg is
32-bit unsigned c: Java's int multiply wraps identically, so only
the mod needs `Integer.remainderUnsigned`.

#diagram([one partition of the fixture array around the median of three, the k = 5 slot shaded on the kept side], length: 13pt, {
  // 7 1 5 3 9 2 8 6 4, pivot 7 (median of a[0], a[4], a[8] = 7, 9, 4), one hoare pass
  let before = (7, 1, 5, 3, 9, 2, 8, 6, 4)
  let after = (4, 1, 5, 3, 6, 2, 8, 9, 7)
  for (i, v) in before.enumerate() {
    cdraw.rect((1.4 + i * 1.35, 6.4), (2.75 + i * 1.35, 7.3), fill: if i in (0, 4, 8) { luma(225) } else { luma(240) }, radius: 0.02)
    cdraw.content((2.07 + i * 1.35, 6.85), [#v], size: 7pt)
  }
  cdraw.content((1.4, 7.9), [median of three probes 7, 9, 4: pivot 7], size: 6pt)
  // arrow down
  cdraw.line((7.4, 6.0), (7.4, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.6, 5.65), [one hoare pass], size: 6pt)
  for (i, v) in after.enumerate() {
    let kept = i <= 5
    cdraw.rect((1.4 + i * 1.35, 3.4), (2.75 + i * 1.35, 4.3), fill: if kept { luma(225) } else { luma(245) }, radius: 0.02)
    cdraw.content((2.07 + i * 1.35, 3.85), [#v], size: 7pt)
  }
  // the k = 5 slot on the kept side: positions 0..4 hold the 5 smallest
  cdraw.rect((1.4 + 4 * 1.35, 3.1), (2.75 + 4 * 1.35, 4.6), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((2.07 + 4 * 1.35, 2.75), [k = 5 lives here], size: 6pt)
  cdraw.content((1.4, 2.0), [right side dropped: 8, 9, 7 are all past the slot], size: 6pt)
  cdraw.content((1.4, 1.1), [expected o(n), worst o(n^2) stated], size: 6pt)
})

The application is general technique, the offline k-th smallest, and
the online upgrade that answers rank and select repeatedly under
inserts is the fenwick machine of #xref-to("dsa", "balanced").

== counting and radix

Comparison sorts have a floor, log n factorial comparisons. Counting
sort steps around the floor by tallying keys, and radix sort stacks
stable counting passes least significant digit up. Each pass must be
stable or the previous pass's work dies.

The dry run: the fixtures are the sign-flip ladder and the two radix
runs, asserted by the C\# suite; C, Go, Java, JavaScript, and Lua pin
the counting fixture 4 2 2 8 3 3 1 instead and Python sorts digit
tuples.

+ The flip is one xor of bit 63, and the ladder reads
  RadixKey(min) < RadixKey(-1) < RadixKey(0) < RadixKey(1) <
  RadixKey(max): unsigned byte order now equals signed long order.
+ The 5000-value fixture spans -1000000 to 1000000, and the byte
  passes land exactly Order()'s result, negatives first.
+ Each pass tallies 256 buckets and skips free when counts[0]
  equals the length, every key agreeing on that byte.
+ The agreeing fixture's 1000 keys live in 0 through 9999: after the
  flip byte 7 is uniformly 128 and bytes 6 down to 2 uniformly 0, so
  six of the eight passes skip.
+ Everything left rides the low two bytes, 8 - 6 = 2 passes of real
  work, the couple of passes the small magnitudes cost.

#diagram([the sign flip bending the signed line into unsigned order, then the eight byte passes with six skipped free], length: 13pt, {
  cdraw.content((5.8, 7.7), [xor 1 << 63], size: 6.5pt)
  cdraw.line((1.2, 6.9), (12.4, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.5, 6.35), [-2^63], size: 6pt)
  cdraw.content((6.5, 6.35), [0], size: 6pt)
  cdraw.content((11.2, 6.35), [2^63 - 1], size: 6pt)
  cdraw.line((12.7, 6.9), (12.7, 5.7), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((1.2, 5.4), (12.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.5, 4.85), [min maps to 0], size: 6pt)
  cdraw.content((6.0, 4.85), [-1 | 0], size: 6pt)
  cdraw.content((11.0, 4.85), [max maps to the top], size: 6pt)
  cdraw.content((15.8, 6.2), [negatives now order below positives], size: 6pt)
  cdraw.content((15.8, 5.3), [in one unsigned space], size: 6pt)
  cdraw.content((5.8, 3.6), [the 1000-key run, bytes 7 down to 0], size: 6.5pt)
  for b in range(8) {
    let x = 1.6 + b * 1.65
    let skip = b < 6
    cdraw.rect((x, 2.3), (x + 1.45, 3.2), fill: if skip { none } else { luma(205) }, stroke: if skip { (paint: luma(160), dash: "dashed") }, radius: 0.02)
    cdraw.content((x + 0.72, 2.75), [#(7 - b)], size: 6pt)
    cdraw.content((x + 0.72, 1.8), if skip { [skip] } else { [work] }, size: 6pt)
  }
  cdraw.content((9.0, 0.7), [bytes 7..2 uniform across 0..9999: 8 - 6 = 2 passes of work], size: 6pt)
})

The ladder order and the two working passes are the C\# pins, and
the listings below bucket in seven languages.

#listing("dsa/samples-c/src/Ch13/counting.c", first: 18, last: 56, caption: [c, counting sort, one stable digit pass, radix driver])

#listing("dsa/samples-go/ch13/counting.go", first: 8, last: 55, caption: [go, tally-and-emit counting, two stable byte passes over 16-bit keys])

#listing("dsa/samples-java/src/Ch13/Counting.java", first: 18, last: 53, caption: [java, backward fill for stability, decimal radix over record pairs])

#listing("dsa/samples/src/Ch13/Sorting.cs", first: 181, last: 215, caption: [c\#, lsd radix on bytes, sign-bit key flip, the uniform-pass skip])

Two subtleties are pinned. Signed longs do not sort correctly as raw
unsigned bytes, negatives would land after positives, so the key
flips the sign bit into an order where unsigned comparison equals
signed order, and flips back at the end. And a pass whose bucket
count says every element shares the byte is skipped for free, which
is why small-magnitude ints finish in a couple of passes.

#listing("dsa/samples-js/src/ch13-counting.mjs", first: 9, last: 35, caption: [javascript, backward fill for stability, byte radix])

#listing("dsa/samples-py/src/Ch13/counting.py", first: 15, last: 34, caption: [python, counting sort keyed by a function, radix over digit tuples])

#listing("dsa/samples-lua/ch13_counting.lua", first: 7, last: 50, caption: [lua, backward walk with 1-based out slots, decimal radix])

Measured across the suites: C, Go, Java, JavaScript, and Lua all
counting-sort 4 2 2 8 3 3 1 to 1 2 2 3 3 4 8. The radix half splits
by family: C, Java, and Lua run the classic 3-digit fixture
329 457 657 839 436 720 355 to 329 355 436 457 657 720 839 with
tags surviving in order, Go and JavaScript run 16-bit keys in two
stable byte passes, and Python sorts (hi, lo) digit tuples, probing
the low pass alone to show it leaves the high digits alone. The
frozen C\# suite radixes longs by bytes with the sign flip.
Stability is load-bearing: least-significant-first only works
because each pass preserves the one before it.

#diagram([radix pass by pass, counting buckets on the low digit, read out, repeat on the next], length: 13pt, {
  // the ones pass over six keys: buckets 0, 2, 4, 5, read back in order
  let input = (170, 45, 75, 90, 802, 24)
  for (i, v) in input.enumerate() {
    cdraw.rect((8.2 + i * 1.5, 6.5), (8.2 + (i + 1) * 1.5, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((8.2 + i * 1.5 + 0.75, 6.95), [#v], size: 6pt)
  }
  cdraw.content((3.4, 6.95), [ones pass], size: 6pt)

  let buckets = (((0,), (170, 90)), ((2,), (802,)), ((4,), (24,)), ((5,), (45, 75)))
  for (r, row) in buckets.enumerate() {
    let (dig, vals) = row
    let y = 5.3 - r * 1.1
    cdraw.content((8.5, y), [#dig], size: 6pt)
    for (i, v) in vals.enumerate() {
      cdraw.rect((9.6 + i * 1.5, y - 0.45), (9.6 + (i + 1) * 1.5, y + 0.45), fill: luma(235), radius: 0.02)
      cdraw.content((9.6 + i * 1.5 + 0.75, y), [#v], size: 6pt)
    }
  }
  let out = (170, 90, 802, 24, 45, 75)
  for (i, v) in out.enumerate() {
    cdraw.rect((8.2 + i * 1.5, 0.3), (8.2 + (i + 1) * 1.5, 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((8.2 + i * 1.5 + 0.75, 0.75), [#v], size: 6pt)
  }
  cdraw.content((3.4, 0.75), [read out], size: 6pt)
  cdraw.content((8.0, -0.6), [then the tens pass, then the hundreds, no comparisons anywhere], size: 6pt)
})

#callout("note", "an honest finding about the comparer contract", [
  `Array.Sort` documents an `ArgumentException` for comparers that
  return inconsistent results. Probing net10.0 shows neither a
  flipping comparer nor one that reports equal elements as greater
  triggers it at sizes 10 through 1000, the sort completes and the
  output is an unspecified order, with the multiset intact. The
  documented check is not a safety net to rely on, the test suite
  records the probing result rather than the documented promise.
])

== the stability probe

Stability is observable only when keys repeat and records carry
identity. The probe sorts tagged pairs twice, once with the stable
merge from this chapter, once with a deliberately unstable contrast,
and reads the tags: equal keys must keep their input order under the
first and are free to lose it under the second.

The dry run: the fixture is the C, Java, and Lua pair set (2, 0),
(2, 1), (1, 2) through both sorts, the contrast this section
teaches, with Go, JavaScript, and Python on three equal 2s and the
C\# suite pinning the stable half alone, OrderBy reading b d a c.

+ The set plants two equal 2s, ids 0 and 1, bracketing a 1 at id 2.
+ The stable merge outputs the 1 first, then reads the equal keys as
  a tie and keeps the left: ids 2 0 1, pinned.
+ Selection sort scans for the minimum, finds the 1 at index 2, and
  swaps it home in one long jump: (1, 2), (2, 1), (2, 0), id 0
  riding the swap back past id 1.
+ Keys still read 1 2 2 ascending in both rows and only the equal
  pair moved: ids 2 1 0, the lost promise.
+ The longer set (3, 0), (1, 1), (3, 2), (3, 3) keeps ids 1 0 2 3
  under both sorts, its only swap jumping over no equal:
  instability is a standing risk, not a certainty.

#diagram([the long swap of selection sort carrying id 0 back past id 1, the one move the stable merge never makes], length: 13pt, {
  let row = (y, vals) => {
    for (i, t) in vals.enumerate() {
      cdraw.rect((2.8 + i * 1.8, y), (2.8 + (i + 1) * 1.8, y + 0.8), fill: luma(235), radius: 0.02)
      cdraw.content((2.8 + i * 1.8 + 0.9, y + 0.4), [#t], size: 6pt)
    }
  }
  cdraw.content((0.7, 6.9), [the scan], size: 6.5pt)
  row(6.0, ([2,0], [2,1], [1,2]))
  cdraw.line((7.3, 5.75), (7.3, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 6.4), [the minimum lives at index 2], size: 6pt)
  cdraw.content((0.7, 4.4), [the swap], size: 6.5pt)
  row(3.5, ([1,2], [2,1], [2,0]))
  cdraw.line((7.3, 4.45), (3.7, 4.45), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.5, 4.85), [(1,2) jumps home], size: 6pt)
  cdraw.line((3.7, 3.15), (7.3, 3.15), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.5, 2.7), [(2,0) rides back, past (2,1)], size: 6pt)
  cdraw.content((0.7, 1.6), [the outcomes], size: 6.5pt)
  cdraw.content((2.8, 1.0), [merge: 2 0 1], size: 6pt)
  cdraw.content((9.6, 1.0), [selection: 2 1 0], size: 6pt)
  cdraw.content((15.4, 4.0), [both leave keys at 1 2 2], size: 6pt)
  cdraw.content((15.4, 3.1), [only the equal pair moved], size: 6pt)
})

The 2 0 1 against 2 1 0 contrast is the pinned pair, and the
listings below probe it in seven languages.

#listing("dsa/samples-c/src/Ch13/stability.c", first: 23, last: 58, caption: [c, the stable merge against selection sort's long swap])

#listing("dsa/samples-go/ch13/stability.go", first: 8, last: 38, caption: [go, heapsort over records as the unstable contrast, two wrappers])

#listing("dsa/samples-java/src/Ch13/Stability.java", first: 21, last: 57, caption: [java, the stable merge against selection sort's long swap])

#listing("dsa/samples/src/Ch13/Sorting.cs", first: 71, last: 96, caption: [c\#, the merge halves, strict less is the stable decision])

#listing("dsa/samples-js/src/ch13-stability.mjs", first: 5, last: 48, caption: [javascript, stable merge sort, heapsort walking equals out reversed])

#listing("dsa/samples-py/src/Ch13/stability.py", first: 15, last: 54, caption: [python, tagged tuples through merge and heapsort])

#listing("dsa/samples-lua/ch13_stability.lua", first: 6, last: 42, caption: [lua, nested msort, selection sort contrast])

Measured across the suites: C, Java, and Lua feed (2,0) (2,1) (1,2),
the stable merge emits ids 2 0 1 while selection sort emits 2 1 0,
its long swap pulling id 0 past id 1, and a longer fixture shows the
contrast is a standing risk rather than a certainty. Go, JavaScript,
and Python feed three equal 2s and a single 1, keep ids 0 1 2 under
the stable merge, and watch heapsort walk them out reversed. Both
sorts land ascending keys either way: instability is not a wrong
answer, it is a lost promise, the one `Array.Sort` documents in the
callout above.

#diagram([the stability probe, one fixture, two sorts, only the equal keys move], length: 13pt, {
  // input: (2,a) (2,b) (1,c); merge keeps a b, selection flips them
  let cell = (x, y, key, tag, hot) => {
    cdraw.rect((x - 0.5, y - 0.45), (x + 0.5, y + 0.45), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), [#key #tag], size: 6.5pt)
  }
  let row = (label, y, items, hot) => {
    cdraw.content((2.0, y), label, size: 6.5pt)
    for (i, it) in items.enumerate() {
      cell(6.4 + i * 1.5, y, it.at(0), it.at(1), i in hot)
    }
  }
  row([input], 7.3, (([2], [a]), ([2], [b]), ([1], [c])), ())
  row([merge, stable], 5.7, (([1], [c]), ([2], [a]), ([2], [b])), (1, 2))
  row([selection, unstable], 4.1, (([1], [c]), ([2], [b]), ([2], [a])), (1, 2))

  cdraw.line((4.0, 7.3), (4.0, 5.7), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((15.0, 7.3), [keys ascend in both rows], size: 6pt)
  cdraw.content((15.0, 6.0), [stable: a before b], size: 6pt)
  cdraw.content((15.0, 4.7), [the swap flipped a and b], size: 6pt)
  cdraw.content((15.0, 3.4), [only the equal keys moved], size: 6pt)
})

The selection rule the whole chapter earns: default to the library
sort, `Array.Sort` for primitives and sizes, `OrderBy` when stability
matters, radix when keys are dense integers and n is large, insertion
when the range is small or nearly ordered. The capstone's compaction
does no sorting at all, it merges already sorted runs, chapter 8's
k-way merge, which is the third way ordering appears in systems.

== across the seven languages

The build sizes count non-comment source lines. The first table
covers the chapter's five original featured files per language,
quicksort, mergesort, counting, the stability probe, and quickselect,
the C\# file carrying the insertion pair and the metered quicksort
too, one file for the whole chapter:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [433], [libc only], [static tmp buffers, one file per sort, plain and median-of-three quicksort side by side, checks share the file with main, 53 of them],
  [go], [162], [slices], [slices.Sort as ground truth only, radix over uint16 keys, quickselect over the shared partition, tests in separate files, 13 tests],
  [java], [413], [jdk 27 stdlib], [one file per sort, plain and median-of-three quicksort side by side, records carry the tags, decimal radix, the shuffle lcg's mod rides Integer.remainderUnsigned, 38 checks in 5 files],
  [c\#], [212], [bcl only], [comparison meters and inversion counting throughout, insertion cutoff inside quicksort and quickselect, 16 tests],
  [javascript], [160], [node stdlib], [destructured swaps, radix over 16-bit keys in two byte passes, quickselect importing the quicksort pivot, 13 tests],
  [python], [297], [stdlib only], [sorted() as ground truth only, tagged tuples make stability visible, the seeded permutation property, 45 checks],
  [lua], [353], [lib.lua harness], [repeat-until hoare cursors, decimal radix base 10, checks ride in the module, 19 of them],
)

The counted insertion baseline lands as its own file in the six
sibling trees, the C\# lane keeping its generic pair inside the
chapter's one file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [74], [libc only], [long counters, shifts through an out parameter, the bound permutation built inline from the coprime multiplier 31],
  [go], [31], [slices], [the pair (comparisons, shifts) returned, DeterministicShuffle feeding the bound lane],
  [java], [73], [jdk 27 stdlib], [long counters in a record pair, the bound permutation built inline from the same coprime multiplier 31, 14 checks],
  [c\#], [41], [bcl only], [the generic insertion pair, plain and binary, over IComparable<T>, the comparison count as the meter],
  [javascript], [16], [node stdlib], [an optional meter object carries the shift count, the smallest build of the set],
  [python], [61], [stdlib only], [comparisons alone returned, the 64-bit lcg shuffle beside it, shuffled slices checked too],
  [lua], [90], [lib.lua harness], [1-based walk, the pair returned, table.sort as the bound lane's ground truth],
)

sources: learn.microsoft.com, `Array.Sort` remarks including the
introsort and instability notes, `Enumerable.OrderBy` stability
remarks, `Array.Fill`, accessed 2026-09-08, plus probing of the
runtime itself for the comparer finding, and cp-algorithms, "K-th
order statistic in O(N)", cp-algorithms.com/sequences/k-th.html,
accessed 2026-09-20, cc by-sa 4.0, our own words and code throughout.
Sample behavior verified by `make verify-csharp`, 16 tests in chapter
13 of the samples suite. The seven-language layer verifies the same
way: 6 C programs with 67 embedded checks under `make verify-c`, 16
Go tests, the java runner's 52 Ch13 checks over 6 files under
`run-java-samples`, 19 `node --test` cases, 60 Python checks across
6 files, and 26 Lua checks under `run.lua`.
