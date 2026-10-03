// book 9, chapter 10: icpc world finals 2019. eleven problems, letters
// A through K, each walked in six languages over the frozen solver
// trees under samples-c, samples, samples-go, samples-js, samples-py,
// and samples-lua
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= icpc world finals 2019

The 2019 finals set 11 problems, letters A through K, and this chapter
walks every letter in six languages, the fixed order c, c\#, go,
javascript, python, and lua that the whole book uses. The statements
are paraphrased in this book's own words and read at the source,
#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[the
problemset pdf at icpc.global]. The Foundation's own solution sketch
set, the solutions pdf, is the algorithm reference for this chapter:
every method and complexity claim below is settled against it, and the
sketches' own account of the contest gives the set its shape, A the
easiest letter with 128 accepted teams while C was accepted by none,
I by five teams, K by four, and F by three, with Moscow State
defending the title on a last-hour F. The set skews toward
implementation, and the sketches admit the judges badly misjudged two
letters, C and I, both of which this chapter works in full. Each
section retells its letter in full, states the input and output
contract with every bound, and reprints the letter's official sample
pair byte for byte from the cached judge data before the six solvers
run.

== the year-local helpers: a scan cursor, an order-statistics multiset, and a run treap

Three helper kits are year-local to 2019, and everything else the
year's solvers import comes from the wave 1 toolbox chapters 2
through 7. The scan kit exists because the 2019 inputs reach 19.6 MB
and a million tokens, past what the toolbox line splitter tolerates:
the C solvers read the whole file into one buffer and a const cursor
walks it, `next_int64` parsing digits in place, inside
`Ch10/ch10_scan.h`, the twin the year's A, B and E solvers include.
The other five languages carry no twin file here: C\# splits through
the toolbox `Input.Longs`, go's `scan10` and javascript's
`makeScanner` are byte cursors inside the solver files, python
splits the buffer natively, and lua walks a byte cursor of its own.
The cursor outlived its year: chapters 11, 12 and 13 face the same
oversized inputs and their C solvers include the `ch11_scan.h` twin
of this kit.

#listing("icpc/samples-c/src/Ch10/ch10_scan.h", first: 6, last: 36, caption: [c: scan_skip steps the cursor past whitespace, next_int64 folds digits in place, next_double hands off to strtod])

The oset kit backs problem A with the year's trickiest queries: the
order-statistics multiset over tiles ranked by height, with insert,
erase, max, and the two queries the greedy lives on, `pred_strict(t)`
for the tallest tile strictly
below t, tie to the largest tile index, and `succ_strict(v)` for the
shortest tile strictly above v, tie to the smallest index. Every
language builds it the same way, a fenwick of counts over compressed
tile ranks plus rank and select by binary descent down the counting
tree, and the tie rules are load-bearing: they are what makes the six
walkthroughs print the judge's own witness byte for byte. The
representations differ where the languages do. C compresses heights to
int32 buckets and keeps per-bucket index stacks, C\# keeps a
`SortedSet` of indexes per bucket, and the other four rank tiles by
the composite key height shifted left 32 bits or index, so the tie
rules fall out of the sort order. That composite key is a 64-bit
product-shaped value, which is where the languages split on integers:
go reads it as `uint64`, lua as an exact 64-bit integer, python as a
native int, and javascript must leave `Number`, whose 53-bit mantissa
cannot hold it, and sort `BigInt64Array` keys instead.

#listing("icpc/samples-c/src/Ch10/ch10_oset.h", first: 69, last: 85, caption: [c: prefix count by fenwick sum, then select by binary descent over the counting tree, the k-th smallest height as a bucket id])

#listing("icpc/samples/src/Ch10/Oset.cs", first: 70, last: 92, caption: [c\#: pred strict takes the k-th of the prefix, largest index from the SortedSet bucket, succ strict mirrors it])

#listing("icpc/samples-go/ch10/ch10_oset.go", first: 81, last: 101, caption: [go: pred and succ over composite uint64 ranks, the tie encoded in the key order])

#listing("icpc/samples-js/src/ch10-oset.mjs", first: 57, last: 72, caption: [javascript: the same two queries over bigint composite keys, counts and ranks plain numbers])

#listing("icpc/samples-py/src/Ch10/oset.py", first: 61, last: 93, caption: [python: pred strict binary-searches the rank below t, succ strict the rank from v+1, select closes both])

#listing("icpc/samples-lua/ch10_oset.lua", first: 65, last: 79, caption: [lua: the same pair over exact 64-bit composite keys, one-based rank tables])

The python helper carries its own self-check, six assertions pinning
the tie rules directly: max picks the tallest tile with the largest
index, pred below 9 ties to index 2, nothing lives strictly below 3,
succ above 3 ties to index 0, nothing lives above 9, and size counts
every insertion. Those six checks run beside the 11 problem suites and
are counted separately in the sources paragraph.

#diagram([one query pair of the multiset: pred strict takes the tallest rank below t, succ strict the shortest above v, both resolved as a fenwick select], length: 12pt, {
  // compressed height axis
  cdraw.line((1.0, 6.4), (19.0, 6.4), stroke: luma(100))
  for (i, p) in ([3], [5], [6], [9], [13], [18]).enumerate() {
    let x = 2.0 + i * 3.0
    cdraw.line((x, 6.4), (x, 6.0), stroke: luma(100))
    cdraw.content((x, 5.5), p, size: 6pt)
  }
  // live tiles as ticks above their height
  for (x, n) in ((2.0, 2), (5.0, 1), (8.0, 1), (11.0, 1), (14.0, 0), (17.0, 1)) {
    for j in range(n) {
      cdraw.line((x + j * 0.35, 6.4), (x + j * 0.35, 7.1), stroke: luma(60))
    }
  }
  // t between 5 and 6: pred strict lands on height 5
  cdraw.line((6.6, 9.6), (6.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 10.0), [t], size: 6pt)
  cdraw.circle((5.0, 7.4), radius: 0.16, fill: luma(60))
  cdraw.content((5.2, 7.4), [pred strict answer, tallest below t], size: 6pt, anchor: "west")
  // v between 6 and 9: succ strict lands on height 9
  cdraw.line((9.6, 3.6), (9.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 3.2), [v], size: 6pt)
  cdraw.circle((11.0, 7.4), radius: 0.16, fill: luma(60))
  cdraw.content((11.0, 8.4), [succ strict answer], size: 6pt)
  cdraw.content((11.0, 2.4), [succ strict: shortest above v, smallest index], size: 6pt)
  cdraw.content((1.0, 1.4), [counts per height in a fenwick, both queries one binary descent], size: 6.5pt, fill: luma(100), anchor: "west")
})

The rtreap kit backs problem F with the year's heaviest contract: V,
the piecewise-constant minimum-puncture function over the compressed
cells, lives as a treap of equal-value runs with subtree min and max,
lazy addition, and cell-boundary splits and merges, plus the balanced
rebuild that repairs the heap order run cuts break. C carries the
vehicle whole in `Ch10/ch10_rtreap.h`, C\# splits problem F's sweep
from the vehicle across `PFSweep.cs` and `PFRuns.cs`, go keeps
`pf_runs.go` beside the solver in the year package, javascript
imports the `RunTreap` class from `ch10-rtreap.mjs`, python from
`pf_runs.py`, and lua requires `ch10_pf_runs`. The rebuild trigger is
the split the F section measures: c, C\#, go and javascript flatten
and rebuild on the fixed 4096-tarp cadence, python and lua flag the
structure dirty when a walk passes the depth gate of 96, and lua's
rebuilt core carries near-max priorities so the fresh 28-bit nodes
sink under it instead of chaining at the root.

#listing("icpc/samples-c/src/Ch10/ch10_rtreap.h", first: 41, last: 90, caption: [c: rpull folds child min and max past the lazy add, rapply and rpush keep cut runs absolute, rmerge joins disjoint cell ranges])

#listing("icpc/samples-c/src/Ch10/ch10_rtreap.h", first: 92, last: 128, caption: [c: rsplit cuts at cell boundary c, a straddling run's tail cut into a fresh right-side node])

#listing("icpc/samples/src/Ch10/PFSweep.cs", first: 132, last: 172, caption: [c\#: the endpoint sweep, live tarps ordered by height at the current x, predecessor and successor edges feeding the dag])

#listing("icpc/samples/src/Ch10/PFRuns.cs", first: 138, last: 185, caption: [c\#: SplitCell cuts at c with the straddle tail, Merge joins on priorities, pushes before either walk])

#listing("icpc/samples-go/ch10/pf_runs.go", first: 143, last: 188, caption: [go: splitCell and merge over int32 run ids, the straddle cut into a fresh node, pushes before each walk])

#listing("icpc/samples-js/src/ch10-rtreap.mjs", first: 124, last: 163, caption: [javascript: the same splitCell and merge over plain arrays, values exact below the 2^53 sentinel])

#listing("icpc/samples-py/src/Ch10/pf_runs.py", first: 77, last: 116, caption: [python: the iterative merge, the path stack sign-encoded, a walk past depth 96 flags the structure dirty])

#listing("icpc/samples-lua/ch10_pf_runs.lua", first: 82, last: 120, caption: [lua: the rebuild, a flat in-order walk then a depth-ranked core with near-max priorities])

== problem A, azulejos

Maria and Joao are opening a small azulejo store in Porto, and the
window display must fit on a single shelf holding exactly two rows:
one of Joao's tiles in the back with one of Maria's tiles in front of
it, every back tile hiding one front tile and vice versa. The
hand-crafted tiles come in many sizes and both rows must stay visible
to passers-by, so every back-row tile has to stand strictly taller
than the front-row tile at its position. For the shoppers, each row
must read in non-decreasing order of price from left to right, tiles
of one price freely reordered subject to the height condition. The
task is an ordering of the two rows meeting both constraints, or a
verdict of impossibility
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is one integer n, 1 <= n <= 5e5 by the problemset pdf, then
four lines of n integers each: the back row's prices, the back row's
heights, the front row's prices, the front row's heights, tiles
numbered 1 to n in input order within each row and every price and
height between 1 and 1e9. The output is two lines of n integers when
an ordering exists, a permutation of the back tile numbers over a
permutation of the front ones, any valid pair accepted since the
letter runs on a checker, or the single word impossible, under the
pdf's 10 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`A-azulejos/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: the cheapest back block holds the lone price-1
tile of height 4, and its answer pairs front tile 4 under it before
the price-2 blocks refill both rows.

input:

```
4
3 2 1 2
2 3 4 3
2 1 2 1
2 2 1 3
```

expected output:

```
3 2 4 1
4 2 1 3
```

Recognition: the bounds pay for the whole loop up front. With n <=
5e5 under the 10 second limit, sorting both rows costs about
4e5 log 5e5 key comparisons and each of the n positions spends two
binary descents down a fenwick of counts, roughly 4e6 tree steps
for the pairing, an O(n log n) shape with two orders of magnitude
to spare.

The statement's cue is the double ordering: each row must read in
non-decreasing price while every back tile stands strictly taller
than the front tile it hides, so tiles inside one price block are
interchangeable and the whole task is which front sits under which
back, a strict-dominance pairing one order-statistics query answers
per position. Problem A is the 2019 face of the greedy with a
safety proof family, and greedy with a safety proof is the family
of chapter 08 problem H, chapter 09 problem K, and chapter 12
problem H.

The tempting alternative, a bipartite matching over heights, is
priced out by its own graph: at n = 5e5 the pairing graph holds up
to 2.5e11 edges before any augmenting walk starts, and the
price-block ordering is not an edge property a matching preserves,
while the exchange argument certifying the greedy is a few lines
and free.

The pinned greedy sorts each row by price, so positions fill cheapest
block first and tiles inside one price block are interchangeable, then
fills one position at a time: let t be the tallest back tile of the
current blocks, take the front tile of largest height strictly below
t, largest index on a tie, and pair it with the back tile of smallest
height strictly above that front height, smallest index on a tie.
Consuming the tallest coverable front and the shortest usable back
leaves the shortest front leftovers and the tallest back ones, which
the exchange argument shows optimal, and the moment no front tile sits
strictly below t the answer is impossible (solutions.pdf p. 2, O(n log
n) with the balanced-tree queries). The six solvers run the same loop
over the year-local multiset of the helper section.

The worked run: trace the model on sample 1. Both rows sort by price
into blocks, back price 1 then 2, 2, 3 and front price 1, 1 then 2, 2.
Position 1 tops out at the lone price-1 back tile 3, height 4, so the
front pick is the tallest front strictly below 4, tile 4 at height 3,
and the back pick the shortest strictly above 3, tile 3 itself. The
back block empties and refills to the price-2 backs 2 and 4, both
height 3. Position 2 queries t = 3, takes the price-1 front leftover
tile 2 at height 2, and pairs it with back tile 2, smallest index on
the height tie. The front block empties and refills to the price-2
fronts, tile 1 at height 2 and tile 3 at height 1. Position 3 queries
t = 3 over the remaining back 4, takes front 1. Position 4 refills
the backs to the price-3 tile 1 at height 2 and takes front 3 at
height 1. The rows read back 3 2 4 1 over front 4 2 1 3, prices
non-decreasing and every back strictly taller, and
the trace ends at the printed answer `4 2 1 3`.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*position*], [*t, tallest back*], [*front pick*], [*back pick*], [*pairing*]),
  [1], [4, tile 3], [4, height 3], [3, height 4], [3 over 4],
  [2], [3, tiles 2 and 4], [2, height 2], [2, height 3, tie], [2 over 2],
  [3], [3, tile 4], [1, height 2], [4, height 3], [4 over 1],
  [4], [2, tile 1], [3, height 1], [1, height 2], [1 over 3],
)

#listing("icpc/samples-c/src/Ch10/pA.c", first: 99, last: 121, caption: [c: per position, the tallest back tile tops the query, the largest front bucket below it and the smallest back bucket above it answer, both erased])

#listing("icpc/samples/src/Ch10/PA.cs", first: 45, last: 76, caption: [c\#: the same loop over SortedSet buckets, pred strict then succ strict, erase both hits])

#listing("icpc/samples-go/ch10/pa.go", first: 72, last: 102, caption: [go: block refill by price order, the composite key split back into height and tile index after each query])

#listing("icpc/samples-js/src/ch10-pa-azulejos.mjs", first: 69, last: 95, caption: [javascript: the loop with bigint composite keys, heights and indexes masked back out of each answer])

#listing("icpc/samples-py/src/Ch10/pa.py", first: 30, last: 53, caption: [python: refill, max, pred strict, succ strict, then erase by rank, positions filled in one pass])

#listing("icpc/samples-lua/ch10_pa.lua", first: 62, last: 88, caption: [lua: the same loop, integer division peeling the height off each composite key])

Prices and heights stay under 1e9, so the arithmetic fits int32
everywhere, and javascript's `Number` is exact at that magnitude: the
only wide value in the problem is the composite rank key, which
javascript carries as a bigint and the other five as ordinary 64-bit
or native integers.

#diagram([the fixture's three positions: back tiles over front tiles, prices non-decreasing along both rows, the dashed lines where each row's price block refills], length: 12pt, {
  // decks
  cdraw.line((1.0, 9.0), (19.0, 9.0), stroke: luma(120))
  cdraw.line((1.0, 3.6), (19.0, 3.6), stroke: luma(120))
  cdraw.content((0.7, 9.0), [back], size: 6pt, anchor: "east")
  cdraw.content((0.7, 3.6), [front], size: 6pt, anchor: "east")
  let pos = ((4.0, 6, 5, 1, 1), (10.0, 3, 2, 1, 2), (16.0, 5, 4, 2, 2))
  for (x, bh, fh, bp, fp) in pos {
    cdraw.rect((x - 1.4, 9.0), (x + 1.4, 9.0 + bh * 0.5), fill: luma(225), radius: 0.02)
    cdraw.rect((x - 1.4, 3.6), (x + 1.4, 3.6 + fh * 0.5), fill: luma(238), radius: 0.02)
    cdraw.content((x, 9.0 + bh * 0.25), [#bh], size: 6pt)
    cdraw.content((x, 3.6 + fh * 0.25), [#fh], size: 6pt)
    cdraw.line((x + 1.7, 3.6 + fh * 0.5), (x + 1.7, 9.0), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x + 1.9, 6.4), [#bh > #fh], size: 6pt, anchor: "west")
    cdraw.content((x, 8.5), [price #bp], size: 6pt)
    cdraw.content((x, 3.1), [price #fp], size: 6pt)
  }
  // block refills: back between positions 2 and 3, front between 1 and 2
  cdraw.line((13.0, 9.3), (13.0, 12.0), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((13.3, 11.6), [back refills to the price-2 block], size: 6pt, anchor: "west")
  cdraw.line((7.0, 3.9), (7.0, 6.3), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((7.3, 6.0), [front refills to the price-2 block], size: 6pt, anchor: "west")
})

The crafted fixture is three tiles per row, back prices 1 1 2 with
heights 3 6 5, front prices 1 2 2 with heights 5 2 4. The expectation,
derived in the spec and pinned by every suite, is the back permutation
2 1 3 over the front permutation 1 2 3, both price rows
non-decreasing, heights 6 over 5, 3 over 2, and 5 over 4. The C
suite's three `CHECK` compares pin the fixture, official sample 1's
canonical 3 2 4 1 over 4 2 1 3, and official sample 2's impossible,
the C\# suite's `Fixture` and `TallestCoverablePairsSortedOrder`
facts pin it and an equal-price block, Go's two table cases take the
fixture and the crafted impossible board, the javascript `it` blocks
assert the fixture strings, python's first check and lua's `three
tiles pair tallest-coverable first` do the same, and every suite past
the C one carries the crafted n = 2 board where a front 6 towers over
every back leftover.

== problem B, beautiful bridges

The Arch Bridges Construction company builds the classical form:
pillars rise from the ground to a deck at height h above sea level,
and consecutive pillars are joined by a semicircular arch of radius
half their horizontal separation, its crown touching the deck at
midspan and its springs sitting on the two pillars half a span below
the deck. The ground profile is a piecewise-linear function given by n
key points, intermediate pillars may stand only at key points with the
first and last mandatory, and an arch may touch the ground but never
extend below it, which rules some placements out entirely. A bridge
with k pillars of heights h1 through hk at separations d1 through
d(k-1) costs alpha times the pillar heights plus beta times the
squared separations, and the task is the cheapest valid bridge across
the whole profile, or impossible
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is four integers n, h, alpha, beta on one line, 2 <= n <=
1e4 key points, 1 <= h <= 1e5 deck height, and cost factors 1 <=
alpha, beta <= 1e4 by the problemset pdf, then n lines of two
integers xi, yi, the key points with 0 <= x1 < x2 < ... < xn <= 1e5
and elevations 0 <= yi < h. The output is the minimum cost as one
integer or the word impossible, under the pdf's 10 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`B-beautifulbridges/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: a five-point valley under a 60 high deck with
alpha 18 and beta 2, and the cheapest bridge trades pillar shafts
against squared spans for 6460.

input:

```
5 60 18 2
0 0
20 20
30 10
50 30
70 20
```

expected output:

```
6460
```

Recognition: n <= 1e4 key points under the 10 second limit prices
the direct quadratic walk: 1e4 anchors each scanning leftward with
running extrema, about 1e8 amortized-constant steps with room for
two orders of magnitude more, provided the arch test itself
collapses to O(1) per pair, since testing every interior point
naively per pair is 1e12 visits.

The statement's cue is ordered placement with pairwise validity:
pillars may stand only at key points, which arrive sorted by x, and
an arch's legality couples exactly its two endpoints and the
points between them, the shape of a dp over the last chosen pillar
with a per-pair validity window. Problem B is the 2019 face of the
chain dp over sorted positions family, and chapter 08 problem F
carries the same shape.

The tempting alternative, a knuth-style or divide-and-conquer
speedup on the transitions, is priced out by the windows: the
bounds L(u,d) to R(u,d) do not satisfy the monotonicity the
quadrangle inequality feeds on, and the plain O(n^2) already fits
the limit a hundred times over, so the machinery buys nothing.

The model is the one the judge data settled on 2026-09-17 after an
earlier deck-centered reading failed: the arch of span s between j and
i is the upper semicircle with center (mid, h - s/2), a key point at
anchor-distance u and depth d clears when d >= s/2 or it lies inside
the arch's disk, which rearranges in s to L(u,d) <= s <= R(u,d) with L
and R equal to 2(u+d) minus and plus 2 sqrt(2ud), and the far anchor
reduces to s <= 2 d, an anchor shallower than half its span unable to
reach its own springing. The disk is convex, so checking the key
points suffices, no interpolated ground segment can cut the arc where
the key points on both of its ends do not. The dp walks the last
pillar with those bounds, dp i the minimum over valid predecessors j
of dp j plus alpha times the last pillar height plus beta times the
squared span, per anchor i moving j leftward while tracking the
running minimum R and maximum L over the interior points entered and
breaking once the half-span passes the minimum R (solutions.pdf p. 2,
O(n^2)). The six dp loops follow.

The worked run: trace the model on sample 1. Pillar heights above
the five points are 60, 40, 50, 30, 40, so dp starts at
`18 * 60 = 1080` for the mandatory west pillar. Pillar 2 admits only
j = 1 with span 20, dp `1080 + 720 + 2 * 20^2 = 2600`. Pillar 3
takes j = 2, dp 2600 + 900 + 200 = 3700, under j = 1's 3780. Pillar
4 takes j = 2 with span 30, dp 2600 + 540 + 1800 = 4940, under
j = 3's 5040 and j = 1's 6620. Pillar 5 takes j = 4 with span 20,
dp 4940 + 720 + 800 = 6460, under j = 3's 7620, j = 2's 8320, and
j = 1's 11600: the whole-profile arch of span 70 is valid, points
2 and 3 deep enough at 40 and 50 against the springing depth 35,
point 4 inside the disk with u = 50, d = 30,
L = 160 - 2 sqrt(3000) = 50.46 <= 70, but its span alone costs `2 * 70^2 = 9800`. The
winning chain 1, 2, 4, 5 pays `18 * (60 + 40 + 30 + 40) = 3060` in
shafts plus `2 * (20^2 + 30^2 + 20^2) = 3400` in spans, and
the trace ends at the printed answer `6460`.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*pillar*], [*shaft, `18 * height`*], [*winning j, span*], [*dp*]),
  [1], [`18 * 60 = 1080`], [mandatory], [1080],
  [2], [`18 * 40 = 720`], [j = 1, span 20], [2600],
  [3], [`18 * 50 = 900`], [j = 2, span 10], [3700],
  [4], [`18 * 30 = 540`], [j = 2, span 30], [4940],
  [5], [`18 * 40 = 720`], [j = 4, span 20], [6460],
)

#listing("icpc/samples-c/src/Ch10/pB.c", first: 43, last: 69, caption: [c: dp over the last pillar, half-surds compared in double, the leftward walk breaking when the span outgrows the shrinking minimum R])

#listing("icpc/samples/src/Ch10/PB.cs", first: 32, last: 65, caption: [c\#: the same walk keeping half-surds, far anchor checked as s <= 2 d at j, L only binding when u > 2 d])

#listing("icpc/samples-go/ch10/pb.go", first: 37, last: 75, caption: [go: the surd bounds factored into surdSum and surdDiff, the walk with the 1e-6 epsilon])

#listing("icpc/samples-js/src/ch10-pb-beautifulbridges.mjs", first: 35, last: 69, caption: [javascript: the dp in Float64Array cells, costs under 2^53 so plain Numbers stay exact])

#listing("icpc/samples-py/src/Ch10/pb.py", first: 28, last: 62, caption: [python: running extrema per anchor, the break when the half-span passes the shrinking minimum, costs in native ints])

#listing("icpc/samples-lua/ch10_pb.lua", first: 38, last: 70, caption: [lua: the same walk, inf at 1 << 62, surds through math.sqrt])

Costs stay under alpha times 1e9 plus beta times 1e10, below 2e14, so
int64 carries them in c, C\#, go, and lua and python natively, and
javascript's `Number` is exact below 2^53 with room to spare, which is
why its dp cells are plain doubles. The surds compare in float64 with
a 1e-6 epsilon: distinct values of A plus or minus sqrt(B) with
integer A and B up to 2 times 1e5 squared differ by far more than
that, so the epsilon decides order and ties exactly.

#diagram([the fixture in cross-section: the deck, the one valid arch whose springs sit at depth s/2, the hill passing under the arc, and the dashed short arches a shallow middle pillar cannot spring], length: 12pt, {
  // to scale, 0.9 units per meter on both axes: deck h=10 at y 9, ground at y 0
  // field x 0..10 draws as x 2..11, so the span-10 arch has radius 4.5 and
  // its springs sit 4.5 below the deck, depth s/2 equal to the radius
  cdraw.line((0.8, 9.0), (12.2, 9.0), stroke: luma(100))
  cdraw.content((12.6, 9.4), [deck, height h], size: 6pt, anchor: "west")
  // ground: 0 at x=2, hill (6,9) as a plateau at y 8.1, end at x=11
  cdraw.line((2.0, 0.0), (6.9, 8.1), (7.9, 8.1), (11.0, 0.0), stroke: luma(60))
  // pillars at both ends, ground to deck
  cdraw.line((2.0, 0.0), (2.0, 9.0), stroke: luma(60))
  cdraw.line((11.0, 0.0), (11.0, 9.0), stroke: luma(60))
  // the single arch: radius 4.5, center (6.5, 4.5), crown (6.5, 9) on the deck
  cdraw.arc((11.0, 4.5), start: 0deg, stop: 180deg, radius: 4.5, stroke: luma(60))
  cdraw.circle((2.0, 4.5), radius: 0.14, fill: luma(60))
  cdraw.circle((11.0, 4.5), radius: 0.14, fill: luma(60))
  cdraw.content((6.5, 9.5), [crown touches the deck], size: 6pt)
  cdraw.content((11.5, 4.5), [spring at depth s/2], size: 6pt, anchor: "west")
  // the hill point sits below the arc, inside the disk
  cdraw.circle((7.4, 8.1), radius: 0.14, fill: luma(60))
  cdraw.content((11.5, 8.1), [the hill at (6, 9), inside the disk], size: 6pt, anchor: "west")
  // dashed middle pillar with its failed short arches, crowns on the deck,
  // springs at depths 3 and 2 landing inside the 1-deep hill
  cdraw.line((7.4, 8.1), (7.4, 9.0), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.arc((7.4, 6.3), start: 0deg, stop: 180deg, radius: 2.7, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.arc((11.0, 7.2), start: 0deg, stop: 180deg, radius: 1.8, stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((6.5, 0.5), [dashed crowns touch the deck, springs land inside the hill], size: 6pt)
})

The crafted fixture is a three-point ground, 0 0, 6 9, 10 0 under
h = 10 with alpha = beta = 1. The single arch spans the whole profile,
its springs at depth 5, the hill point at u = 6, d = 1 sits below the
arc because L = 7.07 <= 10 <= R = 20.93, and the middle-pillar
alternative dies on both short arches since 2 d = 2 there. Expected
cost 120, two pillar shafts of 10 plus one span squared of 100. The C
suite's four `CHECK` cases pin 120, the high-alpha 344 board, official
sample 1's 6460, and official sample 2's impossible, while the C\#
facts, Go's table cases, the javascript `it` blocks, and python's and
lua's checks pin the same 120, 344, and impossible answers with the
crafted ground-touching 1100 board sitting in sample 1's slot, so the
six suites agree on three pins and split on the fourth here.

== problem C, checks post facto

The board game club's draughts records fell into a puddle, and all
that survived of a game is its first mover and a middle fragment of
the move list. English draughts is played on the dark squares of an 8
by 8 board, numbered 1 to 32 row-wise from the top with Black at the
top and White at the bottom. Black and White alternate turns, each
piece is a man or a king, a man slides one dark square diagonally
toward the far side or jumps an adjacent enemy piece to the empty
square immediately beyond, removing it, while a king slides or jumps
in any of the four diagonal directions. A jump chain repeats with the
same piece as long as properly positioned victims remain. Captures are
forced: if any jump exists at the start of a turn, the mover must
jump and may not stop jumping with that piece while jumps remain, and
a man reaching the farthest row is promoted to a king with the turn
ending immediately, so a freshly promoted king cannot jump backward in
the same turn. A simple move from a to b is written a-b and a jump
chain a, b1, ..., bk as axb1xb2x...xbk. The task is a setup of pieces
from which the recorded moves replay as a legal game, printed before
and after, and the setup may not hold black men on the bottom row or
white men on the top row, since those would already have been promoted
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is a character c, B or W, naming the first mover, and an
integer n, 1 <= n <= 100 moves by the problemset pdf, then n move
lines in the notation above over the squares 1 to 32 numbered row-wise
from the top, the rows holding 1 to 4, 5 to 8, and so on. The input is
guaranteed to admit a legal reconstruction. The output is eight lines,
each the
before-board's row, one space, and the after-board's row, cells
written with a dash for light squares, a dot for empty dark squares,
lowercase b and w for the two colors' men and uppercase B and W for
their kings, any valid setup accepted since the letter runs on a
checker, all under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`C-checks/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: White steps 21-17, a black king chains the three jumps
13x22x31x24 sweeping all three white men it meets, and the white king
answers 19x28 over the visiting king, the judge's witness keeping two
bystander men that no rule needs.

input:

```
W 3
21-17
13x22x31x24
19x28
```

expected output:

```
-b-.-.-. -b-.-.-.
.-.-.-.- .-.-.-.-
-.-.-.-. -.-.-.-.
B-.-w-.- .-.-w-.-
-.-.-W-. -.-.-.-.
w-.-.-.- .-.-.-.-
-.-w-w-. -.-.-.-W
.-.-.-.- .-.-.-.-
```

Recognition: the board is 32 squares and the log at most 100 moves,
so the replay itself is microscopic, 100 moves over a handful of
squares each, and the only budget question is the search's
branching: every repair adds one piece or one promotion and
restarts, at most one piece per rule the log can trip, so a
consistent witness costs a few dozen adds and the sole forks are
blocker colors, binary and few.

The statement's cue is its reconstruction wording: the task wants
a setup of pieces from which the recorded moves replay as a legal
game, a hidden initial state rebuilt from a partial observation
log, every rule the replay trips over turning into a constraint
that adds a witness piece or crowns one. Problem C is the 2019
face of the constraint repair with backtracking family, and
chapter 08 problem B is its only sibling.

The tempting alternative, enumerating setups directly, is priced
out by the universe: five piece states over 32 squares is about
10^22 boards before the log gets a vote, while the replay-driven
repair touches a dozen squares because every add is forced by a
rule the log itself breaks.

The pinned solver replays from an empty setup and repairs:
a missing source piece adds a man of the mover's color, a simple move
while any capture exists blocks the smallest landing square of the
cheapest kill, a man moving backward must have been a king at the
start and is promoted in the setup, a jump over an empty square adds
an enemy man there, a man landing on its promotion row mid-sequence
must have been a king, and a jump chain that could continue is blocked
at its smallest landing square. Every repair restarts the replay,
blocker colors are choice points tried black then white, and the
search forks over them depth first (solutions.pdf p. 3). The six
repair drivers follow.

The worked run: trace the model on sample 1. The replay from an
empty setup repairs as the log trips it. Move 21-17 adds the white
man at 21 and walks it to 17. Move 13x22x31x24 adds a black man at
13, jumps the fresh white at 17, finds victim 26 empty and adds a
white man there, then on the restart crowns the mover, 31 to 24
being a backward hop, before victim 27 turns out empty too and
adds a second white man. Move 19x28 adds a white man at 19. The
next restart changes move 2's ending: the stopped chain sits on 24
with the white man on 19 one diagonal away, so the no-continuation
rule blocks its landing square 15, two rows up from 19, and tries
black first. That blocker arms a white capture at move 1, the man
on 19 jumping it forward onto 10, so the simple 21-17 is illegal
and the forced-capture rule blocks square 10, black first again.
One more restart crowns the mover on 19, its hop onto 28 running
backward, and with both blockers and both kings aboard the replay
runs consistent: the chain sweeps 17, 26 and 27, 19x28 sweeps the
visitor, and the white king ends on 28. The model's witness
carries the two black blockers where the judge's carries two
bystander men, both boards legal under the checker, and the shared
empty last row reads byte for byte, so
the trace ends at the printed answer `.-.-.-.- .-.-.-.-`.

#table(
  columns: (auto, 1.3fr, auto, auto),
  inset: 4pt,
  table.header([*move*], [*rule tripped*], [*repair*], [*restarts*]),
  [21-17], [source empty], [add w at 21], [yes],
  [13x22x31x24], [source empty], [add b at 13], [yes],
  [13x22x31x24], [victim 26 empty], [add w at 26], [yes],
  [13x22x31x24], [backward hop 31 to 24], [crown 13], [yes],
  [13x22x31x24], [victim 27 empty], [add w at 27], [yes],
  [19x28], [source empty], [add w at 19], [yes],
  [13x22x31x24], [chain could continue onto 19], [block 15, black], [yes],
  [21-17], [capture now exists, landing 10], [block 10, black], [yes],
  [19x28], [backward hop onto 28], [crown 19], [yes],
)

#listing("icpc/samples-c/src/Ch10/pC.c", first: 227, last: 252, caption: [c: the repair driver forks on a blocker square black then white, kings on the promotion rows, restarts re-replay from the setup])

#listing("icpc/samples/src/Ch10/PC.cs", first: 108, last: 147, caption: [c\#: the replay ladder, missing source, forced-capture block, backward man promoted at its origin square])

#listing("icpc/samples-go/ch10/pc.go", first: 117, last: 167, caption: [go: the drive loop, blocker choice points cloned as fresh maps, an occupied promotion restart dies as a no-progress branch])

#listing("icpc/samples-js/src/ch10-pc-checks.mjs", first: 159, last: 193, caption: [javascript: the same loop over Map boards, choice points black first, a re-add that makes no progress fails the branch])

#listing("icpc/samples-py/src/Ch10/pc.py", first: 144, last: 171, caption: [python: the drive loop restarts on every repair, forking over blocker colors with copied dicts, home squares carried in the piece tuple])

#listing("icpc/samples-lua/ch10_pc.lua", first: 144, last: 173, caption: [lua: the drive loop over sparse table boards, the same b-then-w fork at choice squares])

The board is 32 entries and pieces are four kinds, so no language
touches its integer edges here. The representations do split: C keeps
piece ids with a per-piece kind and color, C\# renders pieces as chars
and marks promotions with a dedicated 'P' repair, and the other four
carry a {black, king, home} record per piece in a sparse map, the home
square being what lets a backward-moving man be crowned where it
started. Python's suite adds the rule checker the judge harness itself
needs: it replays the fixture's pinned before-board through the move
list and asserts the after-board comes out legal.

#diagram([the fixture's two boards side by side, the black king and the white king each stepping backward, the moves a legal game only because both were kings at the start], length: 12pt, {
  // two 8x8 boards, cells 0.5 units: before at x 1..5, after at x 6..15
  let cell = 0.5
  let boardat = (bx, r, c) => (bx + c * cell, 9.0 - r * cell)
  for (name, bx) in (([before], 1.0), ([after], 6.5)) {
    for r in range(8) {
      for c in range(8) {
        let (x, y) = boardat(bx, r, c)
        cdraw.rect((x, y - cell), (x + cell, y), fill: if calc.rem(r + c, 2) == 0 { luma(245) } else { luma(120) }, radius: 0.0)
      }
    }
    cdraw.content((bx + 2.0 * cell, 9.4), name, size: 6pt)
  }
  // fixture pieces: before has W at square 9 (r2,c1), B at 23 (r5,c4)
  let put = (bx, sq, ch) => {
    let r = (sq - 1) // 4
    let k = calc.rem(sq - 1, 4)
    let c = 2 * k + 1 - calc.rem(r, 2)
    let (x, y) = boardat(bx, r, c)
    cdraw.content((x + cell / 2, y - cell / 2), ch, size: 6.5pt)
  }
  put(1.0, 9, [W])
  put(1.0, 23, [B])
  // after: W at 13, B at 18
  put(6.5, 13, [W])
  put(6.5, 18, [B])
  // arrows: 23 -> 18 and 9 -> 13, both toward decreasing row
  cdraw.line((3.4, 7.6), (8.2, 8.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.6, 7.2), [23-18, backward], size: 6pt)
  cdraw.line((2.4, 8.1), (7.3, 7.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.6, 8.6), [9-13, backward], size: 6pt)
  cdraw.content((1.0, 1.2), [both movers stepped toward their own back row, so both were kings in the setup], size: 6pt, anchor: "west")
})

The crafted fixture is the two-move game B, 23-18 then 9-13. Both
moves run toward decreasing rows, black from row 6 and white from row
3, so both movers were kings at the start, and the pinned output is
the eight before-and-after row pairs with a white king on 9 and a
black king on 23 moving to 13 and 18. The C suite's two `CHECK`
string compares pin the fixture and the official first sample's
canonical board, the C\# facts pin the fixture plus three derived
boards including a jump that adds its victim, Go's single table case
carries the fixture, the javascript `it` blocks pin the fixture, a
forward white man, and a backward jump, python's four checks add the
forward man, the jump with two kings, and the rule-checker replay, and
lua's four checks add a forward jump promoting on the last row and a
no-capture game whose minimal board suffices.

== problem D, circular dna

A bioinformatics group has reduced a strand of DNA to its gene
markers: a sequence of n markers in a reading direction fixed by
molecular properties, each marker the start or the end marker of a
numbered gene type, the two marker spellings unique to their type. A
type is properly nested in the sequence when the subsequence of all
its markers, none left out, is built from the grammar siei, or siNei
wrapping another nested structure N, or the concatenation AB of two
nested structures, which is exactly the bracket condition that the
type's running balance never dips below zero and ends at zero. Book
7's chapter 35, combinatorics, counts these balanced-bracket families
exactly. The
strand under study is circular DNA, a closed loop, and whether a type
nests depends on where the loop is cut. The task is the cut, made just
before the p-th input marker, that maximizes the number of properly
nested gene types, the smallest p breaking ties
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is one integer n, 1 <= n <= 1e6 by the problemset pdf, then
one line of n markers, each the letter s or e followed by a gene type
id from 1 to 1e6, the sequence as cut from the circle at an arbitrary
point. The output is p and m on one line, the best cut position and
the number of types nesting there, under the pdf's 3 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`D-circular/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: nine markers in which type 2's end lands before
its start and type 42 stands alone, so only type 1's three s and three
e markers can ever close, and they close exactly when the circle is
cut before marker 3.

input:

```
9
e1 e1 s1 e2 s1 s2 e42 e1 s1
```

expected output:

```
3 1
```

Recognition: n <= 1e6 markers under the 3 second limit prices
exactly two linear passes: 1e6 steps to collect per type the total
and the minimum prefix balance, 1e6 more to rotate the cut past
every marker, an O(n) shape with three orders of magnitude to
spare, so the solution never touches a marker twice after the
first pass.

The statement's cue is the circular cut: whether a type nests
depends on where the loop is cut, nesting is the bracket condition
on one type's running balance, and the whole question is which
cuts leave every type's balance at its minimum, one rotating
aggregate per type. Problem D is the 2019 face of the event sweep
over a sorted axis family, and the same event sweep over a sorted
axis cue drives chapter 09 problem A, chapter 09 problem H,
chapter 10 problem J, and chapter 13 problem L.

The tempting alternative, rotating the marker string per cut and
re-checking bracket balance per type, is priced out at 1e6 cuts
times 1e6 markers, 1e12 visits against a 3 second budget that
holds about 1e9, three orders of magnitude past the limit.

The one-pass form: a balanced type is nested at cut p exactly when its
prefix balance at p-1 equals its minimum prefix balance over all
prefixes, so the solver precomputes per type the total and the
minimum, then rotates the cut past each marker and maintains the count
of types whose running balance equals its minimum (solutions.pdf
p. 3, O(n)). The six sweeps follow.

The worked run: trace the model on sample 1. The first pass
collects per type the total and minimum prefix balance: type 1's
markers at positions 1, 2, 3, 5, 8, 9 run the balance -1, -2, -1,
0, -1, 0, total 0 and minimum -2 after position 2; type 2 runs -1
then 0, total 0, minimum -1; type 42 totals -1 and never nests. A
type nests at cut p exactly when total 0 meets prefix balance
p-1 equal to the minimum, so the sweep starts at cut 1 with every
balance 0 against minima -2 and -1, nothing nested. Cut 2 passes
one e of type 1, balance -1, still short. Cut 3 has passed both
e's, balance -2 equals the minimum, and type 2's balance 0 misses
its -1, so exactly one type nests and m = 1. Type 2 reaches its
minimum only at cut 5, where type 1 sits at -1, so no cut nests
two and the smallest best cut wins, and
the trace ends at the printed answer `3 1`.

#diagram([type 1's prefix balance over the nine markers dipping to its minimum -2 after marker 2, and the rotated balance from cut 3 staying at or above zero], length: 12pt, {
  let px = (i) => 2.0 + i * 1.8
  let py = (b) => 11.0 + b * 0.7
  cdraw.line((1.4, py(0)), (18.8, py(0)), stroke: luma(120))
  let bal = (-1, -2, -1, -1, 0, 0, 0, -1, 0)
  for i in range(9) {
    cdraw.line((px(i), py(bal.at(i))), (px(i + 1), py(bal.at(i))), stroke: luma(60))
    if i < 8 and bal.at(i + 1) != bal.at(i) {
      cdraw.line((px(i + 1), py(bal.at(i))), (px(i + 1), py(bal.at(i + 1))), stroke: luma(60))
    }
  }
  cdraw.line((1.4, py(-2)), (18.8, py(-2)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.circle((px(2), py(-2)), radius: 0.14, fill: luma(60))
  cdraw.content((px(2) + 0.3, py(-2) + 0.5), [minimum -2 after marker 2], size: 6pt, anchor: "west")
  cdraw.line((px(2), py(1.6)), (px(2), 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((px(2) + 0.3, py(1.4)), [cut 3], size: 6pt, anchor: "west")
  let ry = (b) => 5.2 + b * 0.7
  let rot = (1, 2, 1, 2, 1, 0)
  for i in range(6) {
    cdraw.line((px(i) + 0.4, ry(rot.at(i))), (px(i + 1) - 0.2, ry(rot.at(i))), stroke: luma(60))
    if i < 5 and rot.at(i + 1) != rot.at(i) {
      cdraw.line((px(i + 1) - 0.2, ry(rot.at(i))), (px(i + 1) - 0.2, ry(rot.at(i + 1))), stroke: luma(60))
    }
  }
  cdraw.line((1.4, ry(0)), (18.8, ry(0)), stroke: luma(120))
  cdraw.content((1.4, ry(2) + 0.5), [type 1 rotated from cut 3], size: 6pt, anchor: "west")
  cdraw.content((18.8, ry(0) - 0.5), [ends at 0, never negative], size: 6pt, anchor: "east")
})

#listing("icpc/samples-c/src/Ch10/pD.c", first: 69, last: 91, caption: [c: the cut-1 count over types with total 0 and min 0, then one sweep applying each passed marker's sign to its type's balance])

#listing("icpc/samples/src/Ch10/PD.cs", first: 39, last: 62, caption: [c\#: dictionaries per type, the nested flag recomputed as cur crosses min, best cut updated only on strict improvement])

#listing("icpc/samples-go/ch10/pd.go", first: 32, last: 75, caption: [go: int32 per-type arrays sized by the largest type id, the sweep entering each marker into cur and toggling nested])

#listing("icpc/samples-js/src/ch10-pd-circular.mjs", first: 38, last: 77, caption: [javascript: typed arrays for balances and a Uint8Array of nested flags, the same rotation sweep])

#listing("icpc/samples-py/src/Ch10/pd.py", first: 23, last: 52, caption: [python: one pass for total and minimum prefix balance, one sweep moving the cut, the count flipped per type])

#listing("icpc/samples-lua/ch10_pd.lua", first: 36, last: 79, caption: [lua: hash tables per type over sparse ids, cur seeded from the final balances, the sweep in marker order])

Balances live in plus or minus n, so int32 carries them and no
language crosses an integer edge. The representation splits on how the
per-type arrays are sized: c, go, and javascript allocate by the
largest type id up to 1e6, C\# and lua keep dictionaries over the ids
that appear, and python sizes its lists off max(types), the dense and
sparse wings of the same sweep.

#diagram([the fixture as a ring of six markers with the winning cut before s1, and the unrolled balance of type 2 dipping to -1 at the losing linearization], length: 12pt, {
  // ring of 6 markers around center (5.2, 6.2), radius 3.0
  let ctr = (5.2, 6.2)
  let rad = 3.0
  let mk = (i) => (ctr.at(0) + rad * calc.cos(-90deg + i * 60deg), ctr.at(1) + rad * calc.sin(-90deg + i * 60deg))
  cdraw.circle(ctr, radius: rad, stroke: luma(150))
  let names = ([e1], [s1], [s2], [e2], [e2], [s2])
  for i in range(6) {
    let (x, y) = mk(i)
    cdraw.circle((x, y), radius: 0.34, fill: luma(235))
    cdraw.content((x, y), names.at(i), size: 6pt)
  }
  // winning cut before s1 (marker index 1): tick on the arc between e1 and s1
  let (cx, cy) = mk(0)
  let (dx, dy) = mk(1)
  cdraw.content(((cx + dx) / 2 + 0.9, (cy + dy) / 2 + 0.7), [cut 2], size: 6pt)
  cdraw.line(((cx + dx) / 2, (cy + dy) / 2), (((cx + dx) / 2) * 1.14, ((cy + dy) / 2) * 1.02), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.2, 6.2), [type 1 nests here], size: 6pt)
  // unrolled type-2 balance under the losing cut 1
  cdraw.line((11.0, 4.6), (19.0, 4.6), stroke: luma(120))
  cdraw.content((11.0, 5.0), [type 2 unrolled from cut 1], size: 6pt, anchor: "west")
  // balance steps: s2 +1, e2 0, e2 -1, s2 0 across the four markers of type 2
  let pts = ((11.5, 4.6), (11.5, 2.6), (14.5, 2.6), (14.5, 0.8), (17.5, 0.8), (17.5, 2.6), (18.5, 2.6))
  cdraw.line(..pts, stroke: luma(60))
  cdraw.line((10.8, 2.6), (19.0, 2.6), stroke: (paint: luma(200), dash: "dashed"))
  cdraw.circle((14.5, 0.8), radius: 0.14, fill: luma(60))
  cdraw.content((14.5, 0.4), [dip to -1, cut 1 loses type 2], size: 6pt)
})

The crafted fixture is six markers, e1 s1 s2 e2 e2 s2. Type 1 has
balance -1 then 0 with minimum -1, type 2 runs 1, 0, -1, 0 with
minimum -1, both totals zero, and the sweep finds cut 2 first holding
one nested type, so the pinned answer is 2 1. The C suite runs five
`CHECK` cases including this fixture, both official samples, the
single marker s7 pinning 1 0, and the wrap pair e1 s1 pinning 2 1,
the C\# suite runs five with the same marker and wrap pins over
crafted boards, Go's two table cases take the fixture and the lone
marker, the javascript `it` blocks take those plus the wrap pair, and
python and lua each run five checks with the wrap pair aboard, so the
wrap case where the cut travels all the way around to nest a reversed
pair is pinned in five of the six suites and the fixture in all six.

== problem E, dead-end detector

The town council wants dead-end signs placed as sparingly as the rules
allow. The road map is a collection of locations joined by two-way
streets, and a street's x-entrance earns a sign when, after entering
that street from x, a driver cannot come back to x without making a
U-turn, an immediate 180-degree reversal. Signs are then pruned for
redundancy: if street S carries a sign at its x-entrance and street T
one at its y-entrance, and a driver entering S from x can reach y and
enter T without any U-turn, the sign at y on T is redundant and stays
unbuilt. The task is the complete placement of non-redundant signs
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is two integers n and m, 1 <= n <= 5e5 locations and 0 <= m
<= 5e5 streets by the problemset pdf, then m lines of two integers v
and w, 1 <= v < w <= n, every location pair named at most once. The
output is the sign count k on one line, then k lines of v and w
marking a sign at the v-entrance of the street joining v and w, sorted
ascending by v then by w, under the pdf's 5 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`E-deadend/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: a triangle, where no entrance is a dead end, plus a loose
two-street path, where only the two leaf entrances keep their signs.

input:

```
6 5
1 2
1 3
2 3
4 5
5 6
```

expected output:

```
2
4 5
6 5
```

Recognition: n and m both <= 5e5 under the 5 second limit price
one linear decomposition: a degree pass, a peel queue over
degree-at-most-one vertices, and the boundary sign pass, about
2e6 steps against a budget that holds 1e9, three orders of
magnitude to spare.

The statement's cue is its reachability phrasing: a sign is earned
when a driver cannot come back without a U-turn and pruned when
another entrance reaches this one without turning, both facts
about whole components of the road graph rather than any single
street, and the components that matter are exactly the 2-core and
what peels off it. Problem E is the 2019 face of the component
structure and connectivity family, and the component structure
and connectivity family runs through chapter 09 problem B,
chapter 10 problem H, chapter 11 problem R, chapter 13 problem E,
and chapter 13 problem G.

The tempting alternative, a reachability walk per entrance, is
priced out at up to 1e6 entrances times an O(n + m) traversal
each, 1e12 steps, while the peel answers every entrance in one
sweep because U-turn-freedom is exactly membership in the same
2-core boundary.

The solver peels degree-at-most-one vertices, the 2-core: a
component that peels entirely is a tree, where only the original leaf
entrances survive redundancy pruning, and otherwise every street with
exactly one peeled endpoint keeps its sign at the core endpoint, since
everything on the peeled branch reaches that entrance without a
U-turn (solutions.pdf p. 4, O(n + m)). Book 8's chapter 39, graph
connectivity and decomposition, builds this 2-core peel, degree queues
and all, from scratch. The six peelings follow.

The worked run: trace the model on sample 1. Degrees start at 2,
2, 2, 1, 2, 1, so the peel queue holds 4 and 6. Removing 4 and 6
drops location 5 to degree 0, and 5 peels too, leaving the
triangle 1, 2, 3 as the one surviving core. The path component
4-5-6 peeled entirely, so it is a tree and only its original leaf
entrances keep signs: a driver entering street 4-5 from 4 reaches
5 and can only U-turn back, and the mirror holds at 6, so signs
4 5 and 6 5 survive redundancy pruning, each leaf entrance
reaching the other's street through the tree without turning. The
triangle keeps nothing, every entrance leaving and returning
around the cycle. Two signs sorted by v then w, and
the trace ends at the printed answer `6 5`.

#diagram([sample 1: the triangle survives as the 2-core, the path 4-5-6 peels to a tree keeping only its two leaf signs], length: 12pt, {
  // triangle 1-2-3, filled core vertices
  let v1 = (4.6, 8.6)
  let v2 = (2.6, 5.4)
  let v3 = (6.6, 5.4)
  cdraw.line(v1, v2, stroke: luma(60))
  cdraw.line(v2, v3, stroke: luma(60))
  cdraw.line(v3, v1, stroke: luma(60))
  for (p, l) in ((v1, [1]), (v2, [2]), (v3, [3])) {
    cdraw.circle(p, radius: 0.42, fill: luma(120))
    cdraw.content(p, l, size: 6pt, fill: white)
  }
  cdraw.content((4.6, 4.3), [the core, no signs], size: 6pt)
  // peeled path 4-5-6, hollow vertices
  let v4 = (11.4, 5.4)
  let v5 = (14.6, 5.4)
  let v6 = (17.8, 5.4)
  cdraw.line(v4, v5, stroke: luma(60))
  cdraw.line(v5, v6, stroke: luma(60))
  for (p, l) in ((v4, [4]), (v5, [5]), (v6, [6])) {
    cdraw.circle(p, radius: 0.42, fill: white, stroke: luma(120))
    cdraw.content(p, l, size: 6pt)
  }
  // the two leaf signs
  cdraw.line((10.0, 6.4), (11.0, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((10.5, 7.0), [4 5], size: 6pt)
  cdraw.line((18.2, 6.4), (17.2, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((17.7, 7.0), [6 5], size: 6pt)
  cdraw.content((11.4, 3.6), [the tree keeps its two leaf entrances], size: 6pt, anchor: "north")
  cdraw.content((14.6, 8.8), [peeled: degree 1, then degree 0], size: 6pt)
})

#listing("icpc/samples-c/src/Ch10/pE.c", first: 62, last: 98, caption: [c: the peel queue over degree counts, then the flood that marks which components kept a core])

#listing("icpc/samples/src/Ch10/PE.cs", first: 38, last: 65, caption: [c\#: symmetric csr adjacency, the 2-core peel, and the boundary streets signed at their core endpoints])

#listing("icpc/samples-go/ch10/pe.go", first: 99, last: 124, caption: [go: the sign emission, tree leaves inside fully peeled components, core-end signs on boundary streets])

#listing("icpc/samples-js/src/ch10-pe-deadend.mjs", first: 32, last: 71, caption: [javascript: the peel over typed arrays, then component labels tracking which components kept a core])

#listing("icpc/samples-py/src/Ch10/pe.py", first: 24, last: 53, caption: [python: peel by stack, then a flood fill per component recording all-peeled trees])

#listing("icpc/samples-lua/ch10_pe.lua", first: 46, last: 74, caption: [lua: the same peel queue over half-edge lists, adjacency keyed by node])

Vertices and degrees stay under 5e5, so counts fit int32 and the
languages differ only in adjacency shape: C XORs the two endpoints out
of a packed half-edge, C\# builds a symmetric csr array, go, js, and
lua thread half-edge lists, and python keeps per-vertex lists.

#diagram([the fixture graph: the triangle core keeps the sign at its boundary street, the two peeled vertices render hollow, and the isolated tree keeps both leaf signs], length: 12pt, {
  // triangle 1-2-3 on the left, path 3-4-5, edge 6-7 on the right
  let v = ((2.0, 5.0, [1]), (5.2, 7.4, [2]), (5.2, 2.6, [3]), (9.0, 2.6, [4]), (12.6, 2.6, [5]), (16.0, 5.0, [6]), (19.0, 5.0, [7]))
  let at = (i) => (v.at(i).at(0), v.at(i).at(1))
  // edges
  cdraw.line(at(0), at(1), stroke: luma(60))
  cdraw.line(at(1), at(2), stroke: luma(60))
  cdraw.line(at(2), at(0), stroke: luma(60))
  cdraw.line(at(2), at(3), stroke: luma(60))
  cdraw.line(at(3), at(4), stroke: luma(60))
  cdraw.line(at(5), at(6), stroke: luma(60))
  // core vertices filled, peeled hollow
  for i in (0, 1, 2) {
    cdraw.circle(at(i), radius: 0.42, fill: luma(120))
    cdraw.content(at(i), v.at(i).at(2), size: 6pt, fill: white)
  }
  for i in (3, 4, 5, 6) {
    cdraw.circle(at(i), radius: 0.42, fill: white, stroke: luma(120))
    cdraw.content(at(i), v.at(i).at(2), size: 6pt)
  }
  // signs: 3 -> 4 at the core end, 6 -> 7 and 7 -> 6 both kept
  cdraw.line((8.2, 3.4), (9.6, 3.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((8.9, 3.9), [3 4], size: 6pt)
  cdraw.line((16.8, 5.6), (18.2, 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((17.5, 6.1), [6 7], size: 6pt)
  cdraw.line((18.2, 4.4), (16.8, 4.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((17.5, 3.9), [7 6], size: 6pt)
  cdraw.content((1.0, 8.6), [filled: the 2-core, hollow: peeled], size: 6pt, anchor: "west")
  cdraw.content((1.0, 0.6), [the sign (4, 3) dies: 4 reaches 3's entrance without a U-turn], size: 6pt, anchor: "west")
})

The crafted fixture is seven vertices and six streets, a triangle with
a two-edge tail plus one isolated edge. The triangle survives as the
core, street 3-4 keeps its sign at 3, and the isolated tree keeps both
leaf signs, so the pinned output is three lines, 3 4, 6 7, 7 6. The C
suite's four `CHECK` cases pin the fixture, the two official samples,
and the two-vertex street, the C\# facts pin four answers over the
same family, Go's table takes the fixture and the isolated edge, the
javascript `it` blocks take those two, python's four checks add a
star tree whose leaves all survive, and lua's four run the same
family, so the both-directions rule for an isolated street is pinned
in every suite.

== problem F, directing rainfall

The International Consortium of Port Connoisseurs has hung sun tarps
over its Douro Valley vineyards, and the tarps, entirely waterproof,
now threaten the harvest. In the two-dimensional model the vineyard is
an interval on the x-axis and every tarp is a slanted line segment
above it. Rain falls straight down from infinitely high, rain landing
on a tarp flows along it toward the tarp's lower end and falls off
there, unless it meets a puncture between its landing point and the
lower end, in which case it drops vertically through the puncture and
keeps falling, landing on whatever is below and repeating the same
logic until it reaches the ground. The consortium wants the fewest
punctures that bring some rain to the vineyard, and legality adds one
twist: at least some of the rain reaching the vineyard must have
started from directly above the vineyard itself, so a plan that only
steals a neighboring vineyard's rain does not count
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is three integers l, r, and n, the vineyard 0 <= l < r <=
1e9 and the tarp count 0 <= n <= 5e5 by the problemset pdf, then n
lines of four integers x1 y1 x2 y2, each tarp's lower end (x1, y1)
and higher end (x2, y2) with 0 <= x1, x2 <= 1e9, x1 never equal to
x2, and 0 < y1 < y2 <= 1e9, every x-coordinate in the input including
l and r distinct, the tarps pairwise non-intersecting and no tarp
endpoint lying on another tarp. The output is one integer, the minimum
number of punctures, an answer always existing since puncturing
straight down through everything above any field point works, under
the pdf's 15 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`F-directingrainfall/sample-1.in` and `sample-1.ans`, the same pair
the problems pdf prints: five tarps stacked over the interval 10 to
20, and two punctures walk one drop from above the field all the way
down into it.

input:

```
10 20 5
32 50 12 60
30 60 8 70
25 70 0 80
15 30 28 40
5 20 14 25
```

expected output:

```
2
```

Recognition: n <= 5e5 tarps under the 15 second limit price an
endpoint sort plus one ordered-set step per endpoint, about 1e6
live-structure operations at 19 tree levels each, then one batch
dp update per tarp over run-encoded cells, an O(n log n) shape
with an order of magnitude to spare.

The statement's cue is its layered geometry: tarps are
non-crossing slanted segments, water lands on one, flows to the
lower end, or drops through a puncture, all verbs of vertical
stacking order at a moving x, so the shape is a left-to-right
sweep holding the live tarps ordered by height, with the dp the
drops feed sitting underneath. Problem F is the 2019 face of the
sweep line with an ordered active set family, chapter 08 problem
L is its only sibling, and a secondary thread, dp over a
piecewise-constant function, covers the water trajectory under
the tarps.

The tempting alternative, processing the tarps in order of
lower-end height, is priced out by correctness rather than time:
a puncture near a tarp's high end can drop water onto a tarp
whose lower end sits higher, so no static height key orders the
dp, and only the sweep's adjacency dag does.

The pinned solution runs in three
parts. Tarps are first ordered by vertical adjacency, an endpoint
sweep over a live structure ordered by height whose adjacency edges
feed a topological order, and the solver must never sort by lower-end
height alone, since a puncture near a high end can drop water onto a
tarp whose lower end is higher. The dp then runs over the
piecewise-constant function V on the compressed cells between tarp
endpoints, V zero on the field cells and infinity outside, each tarp
updating its span by the batch contract: water at a cell either drips
off the tarp's low end for the drip value vd, or exits through the
first puncture for 1 plus the minimum below, so the update flattens
the far side of the valley to min(vd, vmin + 1), lifts the near-drip
slope short of vd by one, and flattens the rest to vd. The drip value
itself reads the covered side: on a left drip vd is the value of the
first covered cell of the span, equal to the outside-left cell unless
the field edge coincides with the drip coordinate, and on a right drip
the first cell past the span, while the initial field is zero on
exactly its own cells plus one extra initial cell past the right edge,
which is what makes an edge drip free instead of infinite. Answers
that come out too small trace to four spots, the argmin taken on the
wrong side and the flat region widened with it, vd read from the wrong
side, a missing +1 on the lifted run, or that extra initial cell. The
contract was pinned by a property sweep against a built puncture-set
oracle over random valid instances, and the oracle choice is
load-bearing: a naive reimplementation that reads, on a left drip, the
cell left of the tarp agrees on valid boards but diverges from the
first-covered-cell semantics on synthetic shapes outside the
statement's domain, which is why the sweep compares against the built
oracle and not a naive one. The answer is
the minimum V over the field cells (solutions.pdf pp. 4-5, amortized
O(n log n) in the official two-ordered-set structure). The six batch
updates follow.

The worked run: trace the model on sample 1. Compressed between
the tarp endpoints and the field edges, the x-axis splits into
cells, and V starts at 0 on the field cells 10 to 20 plus one
extra cell past 20, infinity elsewhere. Bottom-up, tarp 5 first:
it spans 5 to 14, drips left at 5 into nothing, vd infinity, so
puncturing is the only exit and the two field cells under it lift
from 0 to 1. Tarp 4 spans 15 to 28, drips left at 15 where its
first covered cell, the field cell 15 to 20, holds 0, so vd = 0
flattens the whole span: anything on tarp 4 reaches the field
free. Tarp 1 spans 12 to 32, drips right at 32 off the world, vd
infinity, so each cell takes 1 plus the running minimum below:
cells 14 to 28 drop to 1 through tarp 4's flat 0, cells 28 to 32
stay infinite. Tarp 2 spans 8 to 30, drips right at 30 onto tarp
1's infinite tail, and lifts its span to 2 over those 1s, cells
28 to 30 staying infinite. Tarp 3 spans 0 to 25, drips right at
25 where tarp 2 reads 2, so vd = 2 caps its whole span, the
puncture option 3 never beating the drip. The field cells 10 to
20 all read 2, and
the trace ends at the printed answer `2`.

#diagram([sample 1's five tarps and the two-puncture trajectory: onto tarp 3, drip at 25 onto tarp 2, puncture onto tarp 1, puncture onto tarp 4, drip left at 15 into the field], length: 12pt, {
  cdraw.rect((7.0, 0.2), (12.0, 0.7), fill: luma(230), radius: 0.0)
  cdraw.content((9.5, -0.4), [vineyard 10 to 20], size: 6pt)
  cdraw.line((14.5, 8.6), (2.0, 9.8), stroke: luma(60))
  cdraw.content((1.8, 10.0), [t3, drips right at 25], size: 6pt, anchor: "west")
  cdraw.line((17.0, 7.4), (6.0, 8.6), stroke: luma(60))
  cdraw.content((18.0, 8.3), [t2, drips right at 30], size: 6pt, anchor: "west")
  cdraw.line((18.0, 6.2), (8.0, 7.4), stroke: luma(60))
  cdraw.content((18.6, 6.6), [t1, drips right at 32], size: 6pt, anchor: "west")
  cdraw.line((9.5, 3.8), (16.0, 5.0), stroke: luma(60))
  cdraw.content((16.6, 5.0), [t4, drips left at 15], size: 6pt, anchor: "west")
  cdraw.line((4.5, 2.6), (9.0, 3.2), stroke: luma(60))
  cdraw.content((2.2, 2.3), [t5, drips left at 5], size: 6pt, anchor: "west")
  cdraw.line((11.0, 10.6), (11.0, 9.0), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.3, 10.4), [rain from above the field], size: 6pt, anchor: "west")
  cdraw.line((11.0, 8.94), (14.5, 8.6), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.line((14.5, 8.6), (14.5, 7.67), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.line((14.5, 7.67), (15.5, 7.56), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.line((15.5, 7.56), (15.5, 6.5), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.line((15.5, 6.5), (15.5, 4.9), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.line((15.5, 4.9), (9.5, 3.8), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.line((9.5, 3.8), (9.5, 0.9), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.circle((15.5, 7.56), radius: 0.16, fill: luma(60))
  cdraw.circle((15.5, 6.5), radius: 0.16, fill: luma(60))
  cdraw.content((15.9, 7.2), [punctures at x = 27], size: 6pt, anchor: "west")
})

#listing("icpc/samples-c/src/Ch10/pF.c", first: 291, last: 341, caption: [c: vd read at the drip-side cell, then the left-drip and right-drip batch forms over the run treap, splits, lifts, and flat runs])

#listing("icpc/samples/src/Ch10/PF.cs", first: 101, last: 148, caption: [c\#: the same contract on its RunTreap, the sweep and vehicle split into PFSweep.cs and PFRuns.cs])

#listing("icpc/samples-go/ch10/pf.go", first: 148, last: 197, caption: [go: min at the valley edge, the first or last cell at or above vd, the lifted run and the flat c and vd tails])

#listing("icpc/samples-js/src/ch10-pf-directingrainfall.mjs", first: 238, last: 269, caption: [javascript: the mirrored left and right drip updates over the shared run treap module])

#listing("icpc/samples-py/src/Ch10/pf.py", first: 149, last: 188, caption: [python: the dp loop over the sweep order, rebuild gated on the dirty flag, both batch forms])

#listing("icpc/samples-lua/ch10_pf.lua", first: 302, last: 352, caption: [lua: the same loop, one extra initial cell so right-edge drips read a real value, rebuild when the depth gate fired])

The vehicle is the year's own: V lives as a run treap, equal-value
runs in a treap with subtree min and max, lazy addition, and
cell-boundary splits and merges, ported from the judge-green go
implementation. Book 8's chapter 30, balanced trees and order
statistics, builds this treap from scratch, lazy adds and subtree
aggregates included. Run cuts cannot keep a treap heap-consistent under
adversarial cut orders, so the vehicle rebuilds, and the rebuild
trigger is language-tunable: c, C\#, go, and javascript rebuild on a
fixed cadence, every 4096 tarps, one linear flattening pass, python
and lua gate on recursion depth instead, an operation walking deeper
than 96 flags the structure dirty and the dp loop rebuilds at the next
tarp boundary, which lua cannot afford at the fixed cadence and which
never fired on the judge data anyway, the measured maximum depth there
being 52, while the gate cut lua's worst secret from 141.4 s to 30.0 s
and go passed 96 of 96 secrets at a 4.42 s maximum on the fixed
cadence. The sweep itself also splits by integer honesty: c compares
tarp heights by exact cross products in `__int128` and python by exact
integer products over small ordered blocks, while go, javascript,
C\#, and lua order the live set by the float height at the query x.
All values stay at most n and coordinates fit int32, so no language
crosses a product edge in the dp itself, and C\# runs the recursive
splits on a dedicated 64 MB thread stack because cut orders between
rebuilds can chain the treap depth.

#diagram([the fixture's two tarps over the vineyard, the two punctures as dots, and the dashed drop path from above the field through both into the vineyard], length: 12pt, {
  // x-axis with the vineyard 10..12 shaded, one scale throughout:
  // field x -> drawing 8.8 + (x - 10) * 1.8, the tarps' own 1.8 units per meter
  cdraw.line((1.0, 1.4), (19.0, 1.4), stroke: luma(60))
  cdraw.rect((8.8, 1.4), (12.4, 2.2), fill: luma(230), radius: 0.0)
  cdraw.content((10.6, 0.9), [vineyard, l = 10 to r = 12], size: 6pt)
  // tarp B (13,1)-(10,2): lower end right, spans 10..13 -> x 8.8..14.2
  cdraw.line((8.8, 2.8), (14.2, 1.8), stroke: luma(60))
  cdraw.content((15.0, 1.8), [B, drips right at 13], size: 6pt, anchor: "west")
  // tarp A (9,3)-(13,4): lower end left, above B on the shared span
  cdraw.line((6.4, 5.4), (14.2, 6.6), stroke: luma(60))
  cdraw.content((15.0, 6.6), [A, drips left at 9], size: 6pt, anchor: "west")
  // punctures: A at x=10 -> 8.8, B at x=11 -> 10.6
  cdraw.circle((8.8, 5.61), radius: 0.18, fill: luma(60))
  cdraw.content((8.8, 7.2), [puncture A at 10], size: 6pt)
  cdraw.circle((10.6, 2.47), radius: 0.18, fill: luma(60))
  cdraw.content((10.9, 3.6), [puncture B at 11], size: 6pt)
  // drop path: rain from above onto A at x=10, through the puncture, onto B, right to 11, into the field
  cdraw.line((8.8, 9.4), (8.8, 5.8), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.line((8.8, 5.4), (8.8, 2.7), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((6.9, 9.4), [rain], size: 6pt)
  cdraw.line((8.8, 2.3), (10.6, 2.3), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.line((10.6, 2.0), (10.6, 1.6), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
})

The crafted fixture is the vineyard 10 12 with two tarps, 13 1 10 2
and 9 3 13 4. Tarp A sits above B on the shared span and drips left
outside the field, B drips right, and two punctures walk the water
down, one in A at x = 10 dropping onto B and one in B at x = 11 inside
the vineyard, so the pinned answer is 2. The C suite pins it with
three more `CHECK` cases, the official samples answering 2 and 1 and
the empty-tarp board answering 0, the C\# facts pin four boards over
the same family, Go's table takes the fixture and the empty board,
the javascript `it` blocks take those two, python's four checks add a
free in-field drip and a one-puncture board whose drip lands outside,
and lua's four add a tarp clear of the field and one tarp over the
whole field, so the empty and one-tarp edges are pinned across all
six suites.

== problem G, first of her name

The Royal Historian analyzes the Royal Ladies' names. There have been
n ladies, and each lady's name is a single uppercase letter
concatenated in front of her mother's name, lady 1 being the founder
whose name is that one letter alone, so the mother pointers generate
every name and all names are distinct, AENERYS the daughter of ENERYS
for one. For each of k interesting strings the task is the number of
ladies whose name has that string as a prefix
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is two integers n and k, both between 1 and 1e6 by the
problemset pdf, then n lines of an uppercase letter ci and an integer
pi naming lady i's mother, with p1 = 0 and 1 <= pi < i for i > 1,
then k nonempty uppercase query strings whose total length is at most
1e6. The output is k lines, one count per query in order, under the
pdf's 10 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`G-firstofhername/sample-1.in` and `sample-1.ans`, the only sample the
letter carries, the same pair the problems pdf prints: a royal line
running S, YS, RYS, ERYS, NERYS, ENERYS down to AENERYS, who has the
two daughters DAENERYS and YAENERYS, the latter with daughter
RYAENERYS, and the five queries RY, E, N, S, AY answer 2, 2, 1, 1, 0.

input:

```
10 5
S 0
Y 1
R 2
E 3
N 4
E 5
A 6
D 7
Y 7
R 9
RY
E
N
S
AY
```

expected output:

```
2
2
1
1
0
```

Recognition: n and the total query length both <= 1e6 under the 10
second limit price one automaton build over the reversed queries
and one walk of the mother tree, a goto step per lady and a
fold per state, about 2e6 automaton steps with two orders of
magnitude to spare, so nothing that respells a name per query
survives.

The statement's cue is the direction of construction: each name
is one letter concatenated in front of the mother's, so a prefix
query on names is a suffix query on the root-to-node paths of the
mother tree, and counting every lady's path against all queries
at once is exactly what a pattern automaton with suffix links
does. Problem G is the 2019 face of the string borders,
rotations, and automata family, and string borders, rotations,
and automata connect chapter 08 problem K and chapter 12
problem F.

The tempting alternative, materializing the names, is priced out
at about 5e11 characters for one chain of 1e6 ladies before any
query lands, and scanning per query multiplies that by k, while
the automaton never spells a name at all.

A name has prefix s exactly when the
reversed name ends with reversed s, and the reversed names are the
root-to-node paths of the mother tree, so the solver builds an
aho-corasick automaton of the reversed queries, walks it down the
mother tree carrying each lady's state from her mother's, adds one at
each lady's state, and propagates the counts up the suffix-link tree
in reverse bfs order (solutions.pdf p. 5, O(n + sum of query
lengths)). The six walkers follow.

The worked run: trace the model on sample 1. The five queries
reverse into YR, E, N, S and YA and build a six-state trie, root
children Y, E, N and S, with R and A under Y, every fail link
running to the root. Each lady's state is one goto step from her
mother's: down the founder's line the states run S, Y, YR, E, N,
lady 6's ENERYS fails N to root and lands on E, lady 7's AENERYS
finds no A under root and stays root, lady 8's DAENERYS stays
root on D, lady 9's YAENERYS climbs onto Y, and lady 10's
RYAENERYS ends on YR. One hit per lady at her end state, folded
up the fail tree, which is flat here: the states read S 1, Y 2,
YR 2, E 2, N 1, root 2, so the answers are YR 2, E 2, N 1, S 1
and YA 0, and the trace ends at the printed answer `0`.

#diagram([the sample's query trie over the reversed queries with the hit counts, every fail link running to the root, so each query state answers its own hits], length: 12pt, {
  let root = (9.0, 3.2)
  cdraw.circle(root, radius: 0.4, fill: luma(120))
  cdraw.content(root, [root], size: 6pt, fill: white)
  cdraw.content((10.0, 3.2), [2 hits], size: 6pt, anchor: "west")
  let nodes = ((3.0, 6.6, [S], [1]), (6.4, 7.6, [E], [2]), (9.0, 8.0, [N], [1]), (14.2, 7.6, [R, query YR], [2]), (14.2, 5.2, [A, query YA], [0]))
  for (x, y, l, h) in nodes {
    cdraw.line(root, (x, y), stroke: luma(150))
  }
  let ynode = (11.6, 6.4)
  cdraw.line(root, ynode, stroke: luma(150))
  cdraw.circle(ynode, radius: 0.4, fill: luma(235))
  cdraw.content(ynode, [Y], size: 6pt)
  cdraw.content((11.6, 5.6), [2 hits], size: 6pt)
  cdraw.line(ynode, (14.2, 7.6), stroke: luma(150))
  cdraw.line(ynode, (14.2, 5.2), stroke: luma(150))
  for (x, y, l, h) in nodes {
    cdraw.circle((x, y), radius: 0.44, fill: luma(235))
    cdraw.content((x, y), l, size: 6pt)
    cdraw.content((x, y - 0.95), h, size: 6pt)
  }
  // every fail link runs to the root, drawn dashed once for YR
  cdraw.line((13.6, 7.1), (9.7, 4.0), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((12.4, 4.4), [fail links, all to root], size: 6pt)
})

#listing("icpc/samples-c/src/Ch10/pG.c", first: 112, last: 129, caption: [c: preorder over the mother tree by explicit stack, one dense-goto step per lady, then counts summed up the suffix links in reverse bfs])

#listing("icpc/samples/src/Ch10/PG.cs", first: 76, last: 107, caption: [c\#: kids lists built reversed for preorder, each state one goto row lookup, occurrences pushed into fail parents])

#listing("icpc/samples-go/ch10/pg.go", first: 103, last: 131, caption: [go: the iterative dfs with child cursors, state of each lady read off its mother's row, propagation in reverse bfs])

#listing("icpc/samples-js/src/ch10-pg-firstofhername.mjs", first: 95, last: 113, caption: [javascript: the same stack walk over the dense Int32Array goto table, counts folded up suffix links])

#listing("icpc/samples-py/src/Ch10/pg.py", first: 87, last: 105, caption: [python: one stack of frame cursors walks the family, states counted, then reverse-bfs propagation])

#listing("icpc/samples-lua/ch10_pg.lua", first: 87, last: 106, caption: [lua: the memoized transition walks the fail chain and stamps the target on every state it passed, keeping the amortization alive])

The automaton splits the languages in two. C, C\#, go, javascript, and
python build the dense 26-wide goto table, each trie node owning a
full row either as an array slice or an int32 span, which is the
upgrade the sketch's second approach allows when memory holds it. Lua
keeps hash children and a memoized transition instead, and the memo
must saturate: every state on the fail chain a query walks shares the
target, so a cold chain is stamped end to end in one pass, the failure
mode being a re-walk per step that degrades the walk quadratically.
Counts reach 1e6, inside int32 and exact in javascript's `Number`.

#diagram([the fixture's mother chain on the left, the query trie of reversed queries on the right, the name OPOT walking the heavy path TOPO whose suffix links feed the O and P queries], length: 12pt, {
  // mother chain: founder T at top, O, P, O down
  let ladies = ((3.0, 9.0, [T]), (3.0, 7.0, [O]), (3.0, 5.0, [P]), (3.0, 3.0, [O]))
  for i in range(3) {
    cdraw.line((ladies.at(i).at(0), ladies.at(i).at(1) - 0.4), (ladies.at(i + 1).at(0), ladies.at(i + 1).at(1) + 0.4), stroke: luma(60))
  }
  for (i, l) in ladies.enumerate() {
    cdraw.circle((l.at(0), l.at(1)), radius: 0.4, fill: luma(235))
    cdraw.content((l.at(0), l.at(1)), l.at(2), size: 6pt)
  }
  cdraw.content((0.8, 10.0), [the mother tree, names T, OT, POT, OPOT], size: 6pt, anchor: "west")
  // query trie of the reversed queries P, O, TO, PO, X: the reversed
  // queries spell O under T (TO) and O under P (PO), never T or P under O
  let root = (12.8, 6.0)
  cdraw.circle(root, radius: 0.34, fill: luma(120))
  let ch = ((9.8, 8.4, [O]), (9.8, 3.6, [X]), (15.8, 8.4, [T]), (15.8, 3.6, [P]))
  for l in ch {
    cdraw.line(root, (l.at(0), l.at(1)), stroke: luma(150))
    cdraw.circle((l.at(0), l.at(1)), radius: 0.32, fill: luma(235))
    cdraw.content((l.at(0), l.at(1)), l.at(2), size: 6pt)
  }
  // the O of TO hangs under T, the O of PO under P
  cdraw.line((15.8, 8.4), (18.4, 9.6), stroke: luma(150))
  cdraw.circle((18.4, 9.6), radius: 0.32, fill: luma(235))
  cdraw.content((18.4, 9.6), [O], size: 6pt)
  cdraw.content((19.0, 9.6), [TO], size: 6pt, anchor: "west")
  cdraw.line((15.8, 3.6), (18.4, 2.4), stroke: luma(150))
  cdraw.circle((18.4, 2.4), radius: 0.32, fill: luma(235))
  cdraw.content((18.4, 2.4), [O], size: 6pt)
  cdraw.content((19.0, 2.4), [PO], size: 6pt, anchor: "west")
  // the reversed name TOPO walks root -> T -> TO, its third letter
  // fails over the suffix chain to P, and the fourth lands on PO
  cdraw.line(root, (15.8, 8.4), stroke: luma(40))
  cdraw.line((15.8, 8.4), (18.4, 9.6), stroke: luma(40))
  cdraw.line((18.4, 9.6), (15.8, 3.6), stroke: (paint: luma(40), dash: "dashed"))
  cdraw.content((16.7, 6.5), [fail over], size: 6pt, anchor: "east")
  cdraw.line((15.8, 3.6), (18.4, 2.4), stroke: luma(40))
  cdraw.content((10.5, 10.8), [the walk TOPO reads T, O, then the third letter fails over to P and ends on PO], size: 6pt)
  cdraw.content((10.5, 1.4), [the counts of TO and PO ride their suffix links down to O], size: 6pt)
  cdraw.content((10.5, 0.5), [O answers 2: OT and OPOT, P answers 1: POT], size: 6.5pt, fill: luma(100))
})

The crafted fixture is the four-lady family T, then O under T, P under
O, O under P, with the five queries P, O, OT, OP, X. The names are T,
OT, POT, and OPOT, so the pinned answers are 1, 2, 1, 1, and 0, one
per line. The C suite pins it with a founder-only case and the AB
versus BA pair that anchors prefix direction, three `CHECK` compares,
the C\# facts run four over the same family, Go's table carries the
fixture, the javascript `it` blocks take the fixture, the founder,
and AB against BA, python's four checks add a deep fifth lady, and
lua's four run the same family, so the direction case, where AB
matches the name AB but BA does not, is pinned in every suite that
carries more than the fixture.

== problem H, hobson's trains

Mr. Hobson has traded his stable for a rail network and kept his
commitment to sparing passengers any choice: the network has n
stations, and from each station a passenger can catch exactly one
train, one leg, to exactly one other station, a one-way trip that
might have no way back. The only ticket on sale allows up to k legs in
one trip, and the single reader at each station's exit must carry the
list of starting stations it accepts, so the task is, for every
station A, the number of stations including A itself from which A is
reachable in at most k legs
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is two integers n and k, 2 <= n <= 5e5 stations and 1 <= k
<= n - 1 legs by the problemset pdf, then n lines of one integer di,
1 <= di <= n and di never equal to i, the one-leg destination from
station i. The output is n lines, the ith holding the count for
station i, under the pdf's 5 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`H-hobsonstrains/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: a three-station chain and a side tail feeding a
two-station ring, and station 4 tops the table at five, its ring
partner, two chain stations, and the tail station all reaching it
within two legs.

input:

```
6 2
2
3
4
5
4
3
```

expected output:

```
1
2
4
5
3
1
```

Recognition: n <= 5e5 stations under the 5 second limit price one
functional-graph decomposition: an indegree pass, a peel queue,
and two tree folds, about 2e6 steps against a budget holding 1e9,
three orders of magnitude to spare.

The statement's cue is the exactly-one-train rule: one outgoing
leg per station makes the network a functional graph, rings with
trees hanging off them, and a station's reachers within k legs
are its own subtree count plus an arc of its ring, component
structure answering a question that reads like a search. Problem
H is the 2019 face of the component structure and connectivity
family, and the component structure and connectivity family runs
through chapter 09 problem B, chapter 10 problem E, chapter 11
problem R, chapter 13 problem E, and chapter 13 problem G.

The tempting alternative, a backward breadth-first search per
station, is priced out at 5e5 stations times up to 5e5 reached
each, 2.5e11 leg walks, while the peel answers all n stations in
one pass because the k-leg reachers are subtree counts plus
wrapped ring arcs.

A functional graph gives every station exactly one outgoing leg, and
the pinned solver
peels trees off the rings with an indegree queue, then counts in two
layers: per tree an iterative dfs carries the ancestor path on a
stack, so f of v counts subtree nodes at exact distance k by a k-deep
lookback, and a children-before-parents pass folds g of v, the subtree
nodes within k, as one plus the sum over children of g minus f. Every
node whose ring entry is reached within k legs, ring nodes at distance
zero included, adds one to the forward ring arc of length
min(k - dist + 1, ring length) starting at its entry, accumulated with
a wrapped difference array, and ring answers are the arc prefix sums
while tree answers are g (solutions.pdf pp. 5-6, O(n)). Book 8's
chapter 39, graph connectivity and decomposition, develops the
functional graph itself, this ring-with-hanging-trees decomposition
included. The six tree walks follow.

The worked run: trace the model on sample 1. The successor list 2,
3, 4, 5, 4, 3 closes the ring 4-5 and hangs the trees under 4:
3 feeds it with 6 and 2 feeding 3, and 1 feeds 2. The tree folds
give g, the reachers within k = 2 legs inside each subtree: g of 1
is 1, g of 2 is 2, itself and 1, g of 6 is 1, and g of 3 is
1 + 2 + 1 = 4 after dropping each child's exact-distance-2 count,
zero on these small subtrees. The ring arcs then charge every
node that reaches its entry within 2 legs: entries 4 and 5
themselves contribute length min(2 + 1, 2) = 2 each, node 3 at
distance 1 contributes length 2, nodes 6 and 2 at distance 2
contribute length 1 onto station 4 alone, and node 1 at distance
3 never reaches the ring. Station 4's arc sums to 1 + 1 + 1 + 1 +
1 = 5, station 5's to 3, and the tree answers are the g values,
so the six lines read 1, 2, 4, 5, 3, 1 and
the trace ends at the printed answer `1`.

#diagram([sample 1's ring 4-5 with its hanging tree, every station labeled with its answer, station 4's five reachers marked], length: 12pt, {
  // ring {4,5}
  cdraw.circle((6.0, 7.4), radius: 0.5, stroke: luma(60))
  cdraw.circle((6.0, 4.6), radius: 0.5, stroke: luma(60))
  cdraw.line((6.0, 6.9), (6.0, 5.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.35, 5.3), (6.35, 6.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.0, 7.4), [4], size: 6.5pt, anchor: "east")
  cdraw.content((5.0, 6.7), [5], size: 6pt, anchor: "east")
  cdraw.content((5.0, 4.6), [5], size: 6.5pt, anchor: "east")
  cdraw.content((5.0, 3.9), [3], size: 6pt, anchor: "east")
  // tree 3 -> 4 with 6, 2 under 3 and 1 under 2
  cdraw.line((6.0, 7.9), (6.0, 9.2), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((6.0, 9.7), radius: 0.42, stroke: luma(60))
  cdraw.content((6.7, 9.7), [3], size: 6.5pt, anchor: "west")
  cdraw.content((6.7, 9.0), [4], size: 6pt, anchor: "west")
  cdraw.line((6.0, 10.2), (3.4, 11.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.0, 10.2), (8.6, 11.4), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((3.0, 11.7), radius: 0.42, stroke: luma(60))
  cdraw.content((2.3, 11.7), [6], size: 6.5pt, anchor: "east")
  cdraw.content((2.3, 11.0), [1], size: 6pt, anchor: "east")
  cdraw.circle((9.0, 11.7), radius: 0.42, stroke: luma(60))
  cdraw.content((9.7, 11.7), [2], size: 6.5pt, anchor: "west")
  cdraw.content((9.7, 11.0), [2], size: 6pt, anchor: "west")
  cdraw.line((9.0, 12.2), (9.0, 13.4), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((9.0, 13.9), radius: 0.42, stroke: luma(60))
  cdraw.content((9.7, 13.9), [1], size: 6.5pt, anchor: "west")
  cdraw.content((9.7, 13.2), [1], size: 6pt, anchor: "west")
  cdraw.content((12.6, 7.4), [k = 2: station 4 collects itself, 5, 3, 6, 2], size: 6.5pt, anchor: "west", wrap: text.with(size: 6.5pt))
})

#listing("icpc/samples-c/src/Ch10/pH.c", first: 54, last: 97, caption: [c: the euler dfs with the ancestor path on a stack, f charged to the k-th ancestor on entry, g folded in peel order])

#listing("icpc/samples/src/Ch10/PH.cs", first: 76, last: 105, caption: [c\#: the k-th-ancestor pointer path, f counted per tree node, g summed deepest first])

#listing("icpc/samples-go/ch10/ph.go", first: 104, last: 147, caption: [go: per ring entry, the dfs frames carry depth and cursor, arcs charged on entry, g on the leave step])

#listing("icpc/samples-js/src/ch10-ph-hobsonstrains.mjs", first: 70, last: 106, caption: [javascript: the same frame stack, path lookback for f, children totals for g])

#listing("icpc/samples-py/src/Ch10/ph.py", first: 75, last: 104, caption: [python: ring arcs for the entry itself, then the hanging trees, enter and leave steps over one stack])

#listing("icpc/samples-lua/ch10_ph.lua", first: 102, last: 145, caption: [lua: parallel stacks for vertex, depth, and cursor, the ancestor path charged on entry])

Answers stay at most 5e5, int32 and exact in `Number`. The layout
splits on the ring accumulation: C lays every ring's doubled
difference array consecutively in one global buffer and reads each
node as the sum of its two wrapped prefix readings, the other five
keep one local array per ring and handle the wrap inside the add, the
same arithmetic in two shapes.

#diagram([the fixture's two rings with their hanging trees, every station labeled with its answer, station 6's +1 arc drawn as a heavy ring segment], length: 12pt, {
  // ring {2,3} at left with tree 1 -> 2; ring {4,5} at right with 7 -> 6 -> 5
  let ring1 = ((4.4, 7.4), (4.4, 4.6))
  cdraw.circle(ring1.at(0), radius: 0.5, stroke: luma(60))
  cdraw.circle(ring1.at(1), radius: 0.5, stroke: luma(60))
  cdraw.line((4.4, 6.9), (4.4, 5.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((4.75, 5.3), (4.75, 6.7), stroke: luma(60), mark: (end: ">"))
  let lab1 = ((3.4, 7.4, [2], [3]), (3.4, 4.6, [3], [3]))
  for (lx, ly, nm, an) in lab1 {
    cdraw.content((lx, ly), nm, size: 6.5pt, anchor: "east")
    cdraw.content((lx, ly - 0.75), [#an], size: 6pt, anchor: "east")
  }
  // tree 1 hanging off 2
  cdraw.line((4.4, 7.9), (4.4, 9.3), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((4.4, 9.8), radius: 0.4, stroke: luma(60))
  cdraw.content((5.1, 9.8), [1], size: 6.5pt, anchor: "west")
  cdraw.content((5.1, 9.1), [1], size: 6pt, anchor: "west")
  // ring {4,5} with a heavy arc contributed by station 6
  let ring2 = ((14.6, 7.4), (14.6, 4.6))
  cdraw.circle(ring2.at(0), radius: 0.5, stroke: luma(60))
  cdraw.circle(ring2.at(1), radius: 0.5, stroke: luma(60))
  // heavy +1 arc: station 6 enters at 5 with length 2, the whole ring
  cdraw.arc((14.6, 6.0), start: -90deg, stop: 90deg, radius: 1.4, ccw: true, stroke: luma(40))
  cdraw.line((14.6, 5.1), (14.6, 6.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((13.6, 7.4), [4], size: 6.5pt, anchor: "east")
  cdraw.content((13.6, 6.65), [3], size: 6pt, anchor: "east")
  cdraw.content((13.6, 4.6), [5], size: 6.5pt, anchor: "east")
  cdraw.content((13.6, 3.85), [4], size: 6pt, anchor: "east")
  // trees 7 -> 6 -> 5
  cdraw.line((14.6, 4.1), (14.6, 3.0), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((14.6, 2.5), radius: 0.4, stroke: luma(60))
  cdraw.content((15.3, 2.5), [6], size: 6.5pt, anchor: "west")
  cdraw.content((15.3, 1.8), [2], size: 6pt, anchor: "west")
  cdraw.line((14.6, 2.0), (14.6, 1.0), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((14.6, 0.5), radius: 0.4, stroke: luma(60))
  cdraw.content((15.3, 0.5), [7], size: 6.5pt, anchor: "west")
  cdraw.content((15.3, -0.2), [1], size: 6pt, anchor: "west")
  cdraw.content((9.8, 9.8), [k = 2, station 6's arc covers both ring nodes], size: 6.5pt, fill: luma(100))
})

The crafted fixture is seven stations at k = 2 with successor list
2, 3, 2, 5, 4, 5, 6: rings 2-3 and 4-5, tree 1 hanging off 2, tree
7-6 hanging off 5. The pinned answers are 1 3 3 3 4 2 1, one per
line, station 5 collecting four because both 6 and 7 reach it within
two legs. The C suite pins the fixture, both official samples, and a
pure ring in four `CHECK` compares, the C\# facts run four over the
same family, Go's table takes the fixture and the pure ring, the
javascript `it` blocks take those two, python's four checks add a
ring with a tail and a k = 1 board, and lua's four run the same
family, so the pure ring, where every arc wraps fully and the
difference array alone answers, is pinned in every suite.

== problem I, karel the robot

The educational language Karel, named for the writer Karel Capek,
controls a robot on a grid of unit squares, some free and some holding
a barrier, the robot always on a free square facing north, south,
east, or west. A program is a string of five command shapes: m moves
one square forward unless a barrier blocks it, l turns left, a
capital letter invokes the procedure of that name, i followed by a
condition and two parenthesized sub-programs runs the first when the
condition holds and the second otherwise, and u followed by a
condition and one sub-program does nothing when the condition holds,
else runs the sub-program and repeats itself. The one-letter
conditions are b, holding exactly when the next square in the current
heading holds a barrier, and the four headings n, s, e, w, so ub(m)
reads as keep moving until a wall and un(l) as turn to face north.
Procedure definitions X=program bind names, forward references are
allowed, and every square outside the given grid is a barrier, so the
robot can never leave. The task is the interpreter itself: run each
given program from its start cell and heading, printing the final cell
and heading, or inf when the run never terminates
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is four integers r, c, d, e, grid dimensions 1 <= r, c <=
40, at most 26 procedure definitions, and 1 <= e <= 10 programs by the
problemset pdf, then r grid lines of c characters each, a dot for free
and a hash for barrier, running north to south and west to east, then
d definition lines with no name defined twice, then 2e lines in pairs,
a start line i j h whose cell is guaranteed free and the program text.
Every body and program is 1 to 100 characters, syntactically correct,
whitespace-free, and invokes only defined procedures. The output is e
lines, the final position in the same two-numbers-and-heading format
or the word inf, under the pdf's 10 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`I-karel/sample-1.in` and `sample-1.ans`, the only sample the letter
carries, the same pair the problems pdf prints: five procedures,
seven programs, and two of them diverge, the wall-follower G cycling
from its east start and the self-recursive I, defined as III, from
anywhere.

input:

```
4 8 5 7
.......#
..#....#
.###...#
.....###
R=lll
G=ub(B)
B=ub(m)lib(l)(m)
H=ib()(mmHllmll)
I=III
1 1 w
G
1 1 e
G
2 2 n
G
2 6 w
BR
4 1 s
ib(lib()(mmm))(mmmm)
1 1 e
H
2 2 s
I
```

expected output:

```
1 1 w
inf
1 1 w
2 4 s
4 4 e
1 4 e
inf
```

Recognition: the configuration space is 40 by 40 cells times 4
headings, 6400 states, against at most 26 procedures of
100-character bodies, call it 2600 segment offsets, so the memo
table holds about 1.7e7 cells and each is written once, an
O(rcs) shape comfortable inside the 10 second limit, and the
same table is what proves termination.

The statement's cue is the two-word escape hatch: print inf when
the run never terminates, which turns the task from interpreting
a program into mapping a transition function over robot
configurations and code positions, divergence being exactly a
cycle in that product. Problem I is the 2019 face of the dp over
an engineered state space family, and the dp over an engineered
state space family spans chapter 09 problem J, chapter 11
problem S, chapter 12 problem J, and chapter 13 problem H.

The tempting alternative, running the program under a step
counter with a guessed bound, is priced out by honesty rather
than time: no counter certifies non-termination, and the 1 by 1
world's us(m) loop already runs forever on a three-character
program, so only the three-color memo over packed states answers
inf.

The solver compiles every procedure, program, and
parenthesized sub-program into its own segment, then evaluates the
function that maps a configuration and a segment offset to the
configuration at the segment end, memoized with three colors over the
packed row, column, heading id, where a revisit of an in-progress
state means the evaluation cannot terminate and every state it
touched goes divergent, and results are caller-independent so the
memo carries across all programs (solutions.pdf pp. 6-7, O(rcs) over
the configuration space times the code). The interpreter machine is
book 8's chapter 27, an opcode machine, a memoized program-counter
interpreter with configuration-space cycle detection, and this letter
is its contest form. The machine runs in two vehicles
here: c, javascript, and python evaluate over an explicit resume
stack, the form javascript needs because its fixed call stack is the
shallowest of the six, while go, C\#, and lua let the same machine
recurse, their stacks carrying the segment depth, with until loops
iterating a seen-set of configurations in place of recursion. The six
machines follow.

The worked run: trace the model on sample 1. Program 1 runs G =
ub(B) from 1 1 west: the next square west is off the grid, a
barrier, so the until condition holds at once and the answer is
the start itself, 1 1 w. Program 2 runs the same G facing east:
B's ub(m) walks row 1 to 1 7 before the column-8 wall, one l
faces north where the grid edge blocks, the if's l branch turns
west, and B ends 1 7 w. The next B runs west to 1 1, turns south,
steps to 2 1; the third runs south to 4 1, turns east, steps to
4 2; the fourth east to 4 5, north, steps to 3 5; the fifth north
to 1 5, west, steps to 1 4; the sixth west to 1 1, south, steps
to 2 1 again, the configuration the until loop already saw, so
the seen set closes a cycle and the answer is inf. Program 7's
I = III calls itself at its own entry, the memo revisits the
in-progress state at once, also inf. The terminating programs
resolve by the same table, program 4's B ending 2 4 east before
R's three lefts turn it south, and
the trace ends at the printed answer `inf`.

#diagram([sample 1's grid with the wall block shaded and program 2's wall-following lap: east to 1 7, around the block through 2 1, 4 2, 3 5 and 1 4, back to 2 1 south], length: 12pt, {
  // 4x8 grid, cell 1.5: cols 1..8 -> x 3..15, rows 1..4 -> y 9.6 down to 5.1
  let cell = 1.5
  let at = (r, c) => (2.2 + c * cell, 10.4 - r * cell)
  for r in range(1, 5) {
    for c in range(1, 9) {
      let wall = (r == 1 and c == 8) or (r == 2 and c == 3) or (r == 2 and c == 8) or (r == 3 and c == 8) or (r == 3 and c >= 2 and r == 3 and c <= 4) or (r == 4 and c >= 6)
      cdraw.rect(at(r, c), (at(r, c).at(0) + cell, at(r, c).at(1) - cell), fill: if wall { luma(120) } else { luma(242) }, radius: 0.0)
    }
  }
  // the lap: 1,1 east to 1,7, then the six B segments ending 2,1 s
  cdraw.line(at(1, 1), at(1, 7), stroke: (paint: luma(40), dash: "dashed"), mark: (end: ">"))
  cdraw.content((at(1, 4).at(0), at(1, 1).at(1) + 0.7), [ub(m) east to 1 7], size: 6pt, anchor: "south")
  cdraw.line(at(2, 1), at(4, 1), stroke: luma(40), mark: (end: ">"))
  cdraw.content((at(3, 1).at(0) - 0.9, at(3, 1).at(1)), [south to 4 1], size: 6pt, anchor: "east")
  cdraw.line(at(4, 2), at(3, 5), stroke: luma(40), mark: (end: ">"))
  cdraw.content((at(4, 3).at(0), at(4, 1).at(1) - 0.8), [east, north, around the block], size: 6pt, anchor: "north")
  cdraw.line(at(1, 5), at(1, 2), stroke: luma(40), mark: (end: ">"))
  cdraw.content((at(1, 3).at(0), at(1, 1).at(1) - 0.5), [west, south], size: 6pt, anchor: "north")
  cdraw.circle(at(2, 1), radius: 0.2, fill: luma(60))
  cdraw.content((at(2, 1).at(0), at(2, 1).at(1) - 0.7), [2 1 s, seen twice: inf], size: 6.5pt, anchor: "north")
})

#listing("icpc/samples-c/src/Ch10/pI.c", first: 195, last: 228, caption: [c: op dispatch on the resume stack, a finished segment resolving its mark frame, an until re-entry returning to the same op])

#listing("icpc/samples/src/Ch10/PI.cs", first: 159, last: 200, caption: [c\#: the recursive evaluator, call and branch delegating to sub-segments, the until loop cycling on a seen set])

#listing("icpc/samples-go/ch10/pi.go", first: 154, last: 178, caption: [go: the three-color memo core, done states replay from the result table, a cycle through the evaluation poisons it])

#listing("icpc/samples-js/src/ch10-pi-karel.mjs", first: 126, last: 174, caption: [javascript: the frame machine, run, sub, and until phases over one explicit stack, settle stamps a whole frame done])

#listing("icpc/samples-py/src/Ch10/pi.py", first: 158, last: 193, caption: [python: the dispatch loop advancing a frame under the three-color protocol, a finished frame unwinding on exceptions])

#listing("icpc/samples-lua/ch10_pi.lua", first: 94, last: 138, caption: [lua: the recursive evaluator over a hashed memo key, until loops cycling on seen configurations])

Grids are 40 by 40 with at most 26 procedures and 100-character
bodies, so configurations pack into one int32 and every language fits
its memo densely except lua, whose hash key folds configuration,
segment, and offset into one integer. No integer edges are crossed.

#diagram([the fixture's 2 by 3 grid: the barrier cell, program 1 walking east until the wall, programs 2 and 3 turning in place, the until op drawn as a loop arrow], length: 12pt, {
  let cell = 1.7
  let org = (3.4, 8.6)
  for r in range(2) {
    for c in range(3) {
      let x = org.at(0) + c * cell
      let y = org.at(1) - r * cell
      cdraw.rect((x, y - cell), (x + cell, y), fill: if r == 0 and c == 2 { luma(120) } else { luma(242) }, radius: 0.0)
    }
  }
  cdraw.content((org.at(0) + 2.5 * cell, org.at(1) + 0.35), [the wall at column 3], size: 6pt)
  // program 1: (1,1) e -> (1,2), stops before the wall
  cdraw.line((org.at(0) + 0.6, org.at(1) - 0.85), (org.at(0) + 1.6, org.at(1) - 0.85), stroke: luma(40), mark: (end: ">"))
  cdraw.content((org.at(0) + 0.85, org.at(1) - 0.5), [ub(m)m walks east, stops at (1,2)], size: 6pt)
  // program 3: turns in place e -> n -> w -> s
  cdraw.arc((org.at(0) + 0.85, org.at(1) - cell - 0.85), start: 0deg, stop: 270deg, radius: 0.55, ccw: true, stroke: luma(60))
  cdraw.content((org.at(0) + 2.2, org.at(1) - cell - 0.3), [us(l) spins e, n, w, to s], size: 6pt)
  // program 2 marker
  cdraw.content((org.at(0) + 0.85, org.at(1) - 2 * cell - 0.75), [Rm from south: three lefts then a blocked step], size: 6pt)
  cdraw.arc((org.at(0) + 0.85, org.at(1) - 2 * cell - 0.85), start: 90deg, stop: 200deg, radius: 0.5, ccw: false, stroke: luma(100))
  // the until loop symbol
  cdraw.arc((13.4, 6.4), start: 0deg, stop: 300deg, radius: 1.5, ccw: true, stroke: luma(60))
  cdraw.content((13.4, 6.4), [u], size: 8pt)
  cdraw.content((13.4, 4.2), [run the body, re-check the condition at the same op: the memo state (cfg, op) catches the cycle], size: 6.5pt, wrap: text.with(size: 6.5pt))
  cdraw.content((13.4, 8.6), [memo: unseen, in progress, done, divergent], size: 6pt)
})

The crafted fixture is a 2 by 3 grid with a wall at the top right,
one procedure R of three lefts, and three programs: ub(m)m from
(1, 1) east ends at 1 2 e, Rm from (1, 1) south ends at 1 1 w, and
us(l) from (1, 1) east ends at 1 1 s. The pinned output is those
three lines. The C suite adds the 1 by 1 world where us(m) never
satisfies its condition and the official first sample with all seven
programs byte-identical to the judge answer, three `CHECK` compares,
the C\# facts run three keeping the 1 by 1 world beside a conditional
board, Go's table carries the fixture alone, the javascript `it`
blocks take the fixture, the full official sample, and the stuck 1 by
1 loop, and python's and lua's three checks keep the 1 by 1 world with
one crafted extra each, so the divergence witness is pinned in five of
the six suites, only go's table stopping at the fixture.

== problem J, miniature golf

A group of friends has finished a round of miniature golf, and nobody
can remember l, the cap the course puts on a hole score: a player who
has hit the ball l times without sinking it scores l and the turn
ends. They played without any cap and recorded the true hit counts,
intending to look up l afterward and adjust, replacing any per-hole
score above l with l, with the total the sum over holes and lower
better. The rank of a player is the number of players whose adjusted
total is less than or equal to theirs, so with adjusted totals 3, 5,
5, 4, 3 the ranks read 2, 5, 5, 3, 2. The task is each player's
smallest possible rank over every choice of the positive integer l
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is two integers p and h, 2 <= p <= 500 players and 1 <= h
<= 50 holes by the problemset pdf, then p lines of h positive
integers, player i's hole scores, each at most 1e9. The output is p
lines, player i's minimum possible rank in input order, under the
pdf's 6 second limit.

Official sample 2, reprinted byte for byte from the judge data pair
`J-minigolf/sample-2.in` and `sample-2.ans`, the same pair the
problems pdf prints: six players over four holes, and the answers are
not a permutation, two players tying at rank 5, because rank counts
everyone at or below a total rather than ordering the players.

input:

```
6 4
3 1 2 2
4 3 2 2
6 6 3 2
7 3 4 3
3 4 2 4
2 3 3 5
```

expected output:

```
1
2
5
5
4
3
```

Recognition: p <= 500 players and h <= 50 holes price the pairwise
machine: 500 choose 2 = 124750 pairs, each walking at most 2h =
100 merged breakpoints, about 1.2e7 steps plus a 500-position
event sweep per player, O(p^2 h) with two orders of magnitude to
spare inside the 6 second limit.

The statement's cue is the single scalar cap: the rank is asked
over every choice of the positive integer l, and each adjusted
total is piecewise linear in l with breakpoints at the scores, so
the whole question lives on one axis where each pair's preference
is an interval and the best rank is the deepest overlap.
Problem J is the 2019 face of the event sweep over a sorted axis
family, and the same event sweep over a sorted axis cue drives
chapter 09 problem A, chapter 09 problem H, chapter 10 problem D,
and chapter 13 problem L.

The tempting alternative, evaluating the rank at every candidate
cap, is priced out twice over: the scores run to 1e9, and even
the 2e4 distinct score values times 500^2 rank computations is
6e9 steps, five hundred times the pair walk.

Adjusted totals are piecewise
linear in l with breakpoints at the scores, so the difference of two
players' totals is linear on each segment between their merged
breakpoints, the player beats the opponent exactly where it is
negative, and a sign flip inside a segment pins the integer interval
by exact division, past the last breakpoint by the total-order
comparison. Per player, a plus-and-minus event sweep over those
intervals takes the best overlap, and the rank is 1 + (p - 1 - best)
(solutions.pdf pp. 7-8, O(p^2 h log(ph))). The six sweeps follow.

The worked run: trace the model on sample 2, the pair the section
prints. Capping at l = 2 flattens every row but player 1's second
hole: player 1 totals 7 while the other five total 8 each, five
opponents strictly above, rank 1 + (6 - 1 - 5) = 1. Player 2 caps
to 10 at l = 3 against 8, 11, 12, 11, 11, four above, rank 2, and
never reaches 1 because player 1's total stays at or below
player 2's at every cap. Player 3 totals 11 at l = 3 with only
player 4's 12 above it, rank 5, and its other caps tie it into
the 8s at l = 2 or put its 17 on top at l = 6, both rank 6.
Player 4 waits for l = 6, total 16 with only player 3's 17
above, rank 5. Player 5 at l = 6 totals 13 under the 17 and 16,
rank 4. Player 6 at l = 4 totals 12 under 13, 14 and 13, rank 3.
The six lines read 1, 2, 5, 5, 4, 3 and
the trace ends at the printed answer `3`.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*player*], [*best cap*], [*own total*], [*opponents above*], [*rank*]),
  [1], [2], [7], [5], [1],
  [2], [3], [10], [4], [2],
  [3], [3], [11], [1], [5],
  [4], [6], [16], [1], [5],
  [5], [6], [13], [2], [4],
  [6], [4], [12], [3], [3],
)

#listing("icpc/samples-c/src/Ch10/pJ.c", first: 89, last: 118, caption: [c: per segment the endpoints' differences give the slope, the flip emits an interval by floor or ceil division, the tail extends to the sentinel])

#listing("icpc/samples/src/Ch10/PJ.cs", first: 74, last: 113, caption: [c\#: Beats yields closed intervals between consecutive breakpoints, the three flip cases plus the infinity tail])

#listing("icpc/samples-go/ch10/pj.go", first: 85, last: 114, caption: [go: beatsInterval returns the integer subinterval where the difference is negative, exact at the flip])

#listing("icpc/samples-js/src/ch10-pj-minigolf.mjs", first: 55, last: 84, caption: [javascript: adjusted totals from a sorted prefix table, events swept position by position])

#listing("icpc/samples-py/src/Ch10/pj.py", first: 42, last: 81, caption: [python: the pair walk advances running sums and counts across the merged breakpoints, no adjusted total recomputed])

#listing("icpc/samples-lua/ch10_pj.lua", first: 60, last: 99, caption: [lua: the same incremental walk, events packed as at times four plus their delta so the sweep sorts plain integers])

Adjusted totals reach 5e10 and the division arithmetic stays bounded
by the slope's magnitude at most h before any product, so int64
carries c, C\#, go, and lua, python is native, and javascript's
`Number` is exact below 2^53 with the same bound. The vehicles split
on the pair walk: c, C\#, and go recompute both adjusted totals at
each breakpoint, javascript reads them off a sorted prefix table, and
python and lua advance running sums and counts, the incremental shape
lua needs because a recomputing walk costs p^2 h^2 interpreter steps.

#diagram([the fixture's three adjusted-total lines over the cap axis, the cap 2 dashed vertical where player 1 first stands alone on top, the later crossover past player 1's 9], length: 12pt, {
  // axes: l from 0..10 -> x 2..18, totals 0..10 -> y 1.6..9.2
  let px = (l) => 2.0 + l * 1.6
  let py = (t) => 1.6 + t * 0.76
  cdraw.line((2.0, 1.6), (18.4, 1.6), stroke: luma(100))
  cdraw.line((2.0, 1.6), (2.0, 9.4), stroke: luma(100))
  for l in range(0, 11) {
    cdraw.line((px(l), 1.5), (px(l), 1.7), stroke: luma(100))
  }
  cdraw.content((18.4, 1.1), [cap l], size: 6pt, anchor: "east")
  cdraw.content((2.0, 9.8), [adjusted totals], size: 6pt)
  // player 1: (1,2),(2,3),(3,4),(4,5),(9,10)
  cdraw.line((px(1), py(2)), (px(4), py(5)), (px(9), py(10)), stroke: luma(40))
  // player 2: (1,2),(2,4),(3,6),(4,8),(9,8)
  cdraw.line((px(1), py(2)), (px(4), py(8)), (px(9), py(8)), stroke: luma(70))
  // player 3: (1,2),(2,4),(3,6),(4,7),(9,8)
  cdraw.line((px(1), py(2)), (px(4), py(7)), (px(9), py(8)), stroke: luma(100))
  cdraw.content((px(9), py(10)), [1], size: 6pt, anchor: "south-west")
  cdraw.content((px(9), py(8.4)), [2 and 3], size: 6pt, anchor: "south-west")
  // the dashed cap-2 line where player 1 stands alone on top
  cdraw.line((px(2), 1.6), (px(2), 9.4), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((px(2), 9.8), [l = 2], size: 6pt)
  cdraw.content((11.5, 0.9), [player 1 beats both from l = 2, players 2 and 3 wait for the 9 to cap], size: 6.5pt)
})

The crafted fixture is three players over two holes, scores 1 9,
4 4, and 5 3. The adjusted totals cross at cap 2, where player 1's
3 beats the 4s, player 3 passes player 2 at cap 4 where 7 beats 8,
and past player 1's 9 the totals settle at 10, 8, 8, so the pinned
ranks are 1, 2, and 2, one per line. The C suite pins the fixture,
official sample 2, and a uniform crafted board in three `CHECK`
compares, the C\# facts and python's and lua's three checks stay on
crafted boards, the tied 2 by 2 pair and blowout spreads among them,
Go's table carries the fixture, and the javascript `it` blocks alone
take the fixture and both official samples, answering 1 2 2 and
1 2 5 5 4 3, so sample 2 lives in two suites, sample 1 only in the
javascript one, and the fixture in all six.

== problem K, traffic blights

The Urban Traffic Control department wants a theoretical account of
Main Street's lights before anyone risks observing real cars. Lights
sit at various points along the street, each cycling red for r seconds
then green for g with every light just turned red at time 0. An ideal
car mystically appears at the west end of the street at a uniformly
random real time in the interval from 0 to 2019 factorial and crawls
east at one meter per second until it meets a red light, where it
stops forever. For each light the task is the probability that it is
the first red light the car hits, followed by the probability the car
never stops at all
(#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[statement]).

The input is one integer n, 1 <= n <= 500 by the problemset pdf, then
n lines of three integers x, r, g, the light's position 1 <= x <=
1e5 strictly increasing down the list and its durations with 0 <= r,
g and 1 <= r + g <= 100, so a light may be never-red or never-green.
The output is n + 1 lines, one probability per light in position
order then the never-stop probability, accepted within an absolute
error of 1e-6, under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`K-trafficblights/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: four lights, and the answer file itself mixes the
statement's short decimals with the judge machine's twelve-decimal
form, the letter comparing floats within its 1e-6 tolerance.

input:

```
4
1 2 3
6 2 3
10 2 3
16 3 4
```

expected output:

```
0.4
0
0.2
0.171428571429
0.228571428571
```

Recognition: r + g <= 100 and n <= 500 under the 2 second limit
collapse the departure phase mod 2520, and the whole computation
is 2520 residues times the group walks, each light visited once
per phase of its group, about 1e6 steps total, an arithmetic
universe small enough to sit in cache.

The statement's cue is the absurd sampling window, a uniform
real time from 0 to 2019 factorial: only the departure's phase
matters, and 2019 factorial is divisible by 2520, so the universe
of departures is 2520 residues, grouped by shared primes and
independent across groups by the chinese remainder theorem.
Problem K is the 2019 face of the algebraic reduction to a small
universe family, and algebraic reduction to a small universe
covers chapter 08 problem I and chapter 11 problem Z.

The tempting alternative, multiplying per-light marginals, is
priced out by correctness rather than time: lights whose periods
share a prime correlate through the same departure residue,
sample 1's three period-5 lights are dependent, and the
independence product would answer light 3 with 3/5 times 1/5 =
0.12 against the true 0.2.

Because
2019 factorial is divisible by X = 2520 = 2^3 3^2 5 7, the departure
time splits as t0 plus 2520 j, a light of period p sees the phase
(t0 + x + 2520 j) mod p, and 2520 j mod p cycles with reduced period
p over gcd(p, 2520), which is 1 or a prime power. Lights whose
reduced periods share a prime join one group whose modulus is the
least common multiple of the members, since their free phases
correlate through the shared j residue, distinct groups are
independent by the chinese remainder theorem, and the q = 1 lights
form one extra group of period one. Book 8's chapter 16, number
theory and modular arithmetic, develops the chinese remainder theorem
this independence rides on, and book 8's chapter 28, advanced number
theory, reconstructs each merged residue the garner way. Per residue
t0, each group walks
its lights in position order over its k phases for first-red counts
and survival, another group's lights only matter through the fraction
with all of its members before the queried light green, and the
fractions multiply across groups (solutions.pdf pp. 7-8). That
grouping is one refinement past the sketch text, which groups by
reduced period alone: same-prime periods are dependent, and the six
solvers all ship the shared-prime groups. The six residue walks follow.

The worked run: trace the model on sample 1. The four periods are
5, 5, 5 and 7, so the first three lights share the prime 5 and
form one group of modulus 5, light 4 forms its own group of
modulus 7, and the two groups are independent by the chinese
remainder theorem. Walk the mod-5 group over the departure
residue a: light 1 sees phase a + 1, red below 2, so a = 4 and
a = 0 stop there, 2 of 5. Light 2 sees phase a + 6 = a + 1, green
on every surviving residue, never first. Light 3 sees phase a +
10 = a, red only for a = 1, 1 of 5. Light 4 sees phase b + 16 =
b + 2 mod 7 against red 3, red for b = 5, 6 and 0, 3 of 7, and
only the 2-in-5 survivors of the first group ever arrive, so
light 4 answers 2/5 times 3/7 = 6/35 and survival answers 2/5
times 4/7 = 8/35. The five lines read 0.4, 0, 0.2, 6/35, 8/35,
and the trace ends at the printed answer `0.228571428571`.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*residue a*], [*light 1, phase a+1*], [*light 2, phase a+1*], [*light 3, phase a*], [*outcome*]),
  [0], [1, red], [1, green], [-], [light 1 first],
  [1], [2, green], [2, green], [1, red], [light 3 first],
  [2], [3, green], [3, green], [2, green], [survives],
  [3], [4, green], [4, green], [3, green], [survives],
  [4], [0, red], [-], [-], [light 1 first],
)

#listing("icpc/samples-c/src/Ch10/pK.c", first: 101, last: 152, caption: [c: per residue, each group's first red per phase, green suffix counts, then the per-light attribution across groups])

#listing("icpc/samples/src/Ch10/PK.cs", first: 90, last: 115, caption: [c\#: the per-group phase walk stopping at the first red, survival counted, stop fractions divided out])

#listing("icpc/samples-go/ch10/pk.go", first: 72, last: 106, caption: [go: the group walk over phase k, prefix survival as one minus the running stop sum])

#listing("icpc/samples-js/src/ch10-pk-trafficblights.mjs", first: 69, last: 103, caption: [javascript: the same walk, per-group stop fractions and prefix-green arrays, survival per residue])

#listing("icpc/samples-py/src/Ch10/pk.py", first: 69, last: 99, caption: [python: red phases precomputed as bit masks per arrival base, the walk popcount arithmetic])

#listing("icpc/samples-lua/ch10_pk.lua", first: 55, last: 103, caption: [lua: the residue loop over groups, phases walked in position order, fractions in doubles])

Probabilities live in 0 to 1 as doubles, printed at twelve decimals,
and no integer edge is near. The vehicles differ only in the inner
walk: python precomputes each light's red phases over its reduced
period as a bit mask indexed by the arrival base, so the per-residue
walk counts bits, while the other five evaluate the phase per k
directly.

#diagram([the fixture's three lights as timeline strips over the departure residues 0 to 5, red and green bands offset by position, the surviving phase shaded on the last strip], length: 12pt, {
  let x0 = 2.6
  let w = 2.4
  let strips = ((8.6, [light 1, x = 2, r 1 g 1]), (6.0, [light 2, x = 5, r 2 g 1]), (3.4, [light 3, x = 9, never red]))
  // per strip: red pattern over t in 0..5 computed by hand
  let reds = ((true, false, true, false, true, false), (false, true, true, false, true, true), (false, false, false, false, false, false))
  for (si, st) in strips.enumerate() {
    let (y, name) = st
    cdraw.content((x0 - 0.4, y), name, size: 6pt, anchor: "east")
    for t in range(6) {
      cdraw.rect((x0 + t * w, y - 0.7), (x0 + (t + 1) * w, y + 0.7), fill: if reds.at(si).at(t) { luma(120) } else { luma(240) }, radius: 0.0)
    }
  }
  // residue labels
  for t in range(6) {
    cdraw.content((x0 + (t + 0.5) * w, 1.8), [#t], size: 6pt)
  }
  cdraw.content((x0 + 3 * w, 9.8), [departure residue t0], size: 6pt)
  // surviving phase t0 = 3: light 1 green, light 2 green at t0=3, light 3 green
  cdraw.rect((x0 + 3 * w, 8.6 - 0.7), (x0 + 4 * w, 3.4 + 0.7), fill: none, stroke: (paint: luma(40), dash: "dashed"))
  cdraw.content((x0 + 3.5 * w, 0.9), [t0 = 3 survives: 1/2 times 1/3 = 1/6], size: 6.5pt)
  cdraw.content((19.4, 8.6), [red], size: 6pt, anchor: "east")
  cdraw.content((19.4, 7.9), [green], size: 6pt, anchor: "east")
})

The crafted fixture is three lights, at 2 with r 1 g 1, at 5 with
r 2 g 1, and at 9 never red. The first is red on half the residues,
the second on two thirds of those where the first is green, the
never-red light stops nothing, and the probability the car never
stops is the product one half times one third, so the pinned output
is 0.500000000000, 0.333333333333, 0.000000000000, and
0.166666666667. The C suite pins the fixture and the crafted single
light 3 4 6 answering 0.4 then 0.6 in two `CHECK` compares, the
C\# facts run the fixture, the always-red 0 3 0 light, and the
alternating pair 0 1 1 at 0 with 3 1 1, Go's table carries the
fixture, the javascript `it` blocks alone take the fixture and both
samples at this book's twelve-decimal rendering, and python's and
lua's three checks stay on crafted families, an always-red or
never-red single light and a two-light split, every suite comparing
twelve-decimal strings because the judge answers mix statement and
machine formats.

== across the six languages

The 2019 set put the six languages under the same eleven problems and
the trees answered with the same pinned algorithms in different
vehicles, and the differences are the table below. Two problems
split the languages outright. Problem F's run treap rebuilds on a
fixed 4096-tarp cadence in c, C\#, go, and javascript and on a depth
gate of 96 in python and lua, and problem I's interpreter machine
runs over an explicit resume stack in c, javascript, and python while
go, C\#, and lua recurse with a seen-set per until loop. Everywhere
else the split is a representation choice, dense or sparse type
tables in D, dense or memoized automata in G, recomputing or
incremental pair walks in J, and the integer edges never moved past
the B surds' float64 compares, the J divisions' int64 bounds, and
javascript's bigint rank keys on A.

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 3pt,
  table.header([*problem*], [*c*], [*c\#*], [*go*], [*javascript*], [*python*], [*lua*]),
  [oset], [bucket stacks], [SortedSet buckets], [uint64 keys], [bigint keys], [composite ranks], [int64 keys],
  [A], [stack ties], [set ties], [key order], [key order], [key ranks], [key ranks],
  [B], [int64, double surds], [same], [surd helpers], [Number under 2^53], [native ints], [inf 1 << 62],
  [C], [piece ids], [char boards, P repair], [map clone fork], [Map fork], [dict fork], [table fork],
  [D], [dense arrays], [dictionaries], [int32 arrays], [typed arrays], [lists off max id], [hash tables],
  [E], [xor adjacency], [csr adjacency], [half-edge lists], [typed arrays], [lists], [arrays],
  [F], [pending lists, 4096], [split files, 4096], [dag sweep, 4096], [dag sweep, 4096], [block dag, gate 96], [dag sweep, gate 96],
  [G], [dense goto], [dense goto], [fail walk, then fill], [dense goto], [dense goto], [memo fallback],
  [H], [doubled ring buffer], [by-depth lists], [per-ring diff], [per-ring diff], [per-ring diff], [per-ring diff],
  [I], [resume stack], [recursion, seen set], [recursion, seen set], [frame stack], [resume stack], [recursion, seen set],
  [J], [recompute totals], [interval yields], [recompute totals], [prefix table], [running sums], [packed events],
  [K], [direct phases], [direct], [direct], [direct], [bitmask popcount], [direct],
  [suite], [37 checks], [42 facts], [19 cases], [30 its], [42 checks], [42 checks],
)

The suite shapes themselves differ by language, and the sources
paragraph counts what each tree actually carries: c scatters its
checks through per-problem `CHECK` macros, C\# keeps one test class
per letter, go folds every fixture into a single table-driven test,
javascript writes one describe block per letter, python embeds a
self-check in each solver file, and lua returns named test tables
that the runner executes under pcall.

sources: ICPC Foundation, icpc.global, the problemset pdf
#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[icpc2019.pdf]
and the solution sketches
#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/finals2019solutions.pdf")[finals2019solutions.pdf],
both accessed 2026-09-14 and cached under `ref/icpc/2019/` with
sha256 digests in `ref/icpc/INDEX.md`. The solutions pdf is the
algorithm reference for every method and complexity claim in this
chapter, and the contest account in the opening paragraph is its
own. The committed suites pin the fixtures above, counted from the
frozen trees: 37 `CHECK` invocations across the 11 c solvers, 42
`[Fact]` methods across the 11 c\# test files, one table-driven go
test carrying 19 cases, 30 `it` blocks across the 11 javascript test
files, 42 check calls across the 11 python solvers, and 42 assertions
across the 11 lua modules, 212 checks in total, each counted in its
own suite's unit, plus the python oset helper's own six-check
self-check.
Judge data under `ref/icpc/2019/data/` is local only and never
committed: 583 input files mapped to answer pairs by the committed
`ref/icpc/verify-data.ps1`, and every sample pair reprinted in this
chapter is the byte-exact content of that problem's sample-N.in and
sample-N.ans files, attributed in place, with A and C accepted on any
valid answer since those letters run on checkers and K compared
within its 1e-6 float tolerance.
