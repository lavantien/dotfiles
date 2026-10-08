#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= advanced dynamic programming

Chapter 17 paid for its tables in full: every copy of every item got
its own scan, every split point of the partition was reweighed from
scratch, and longest increasing subsequence was left out entirely.
This chapter keeps those recurrences and cuts the waste, counts
become binary pieces, then a monotone deque per residue class, the
partition becomes lines on a hull, and the longest run becomes tails
plus binary search. The meter turns each cut into a pinned number:
15 candidate consults drop to 9 on one small instance, 19900 split
points drop to 400 hull touches, and 499500 pairs drop to a ceiling
of ten thousand comparisons.

== the bounded knapsack

The vending machine holds three of each coin, the truck carries two
of each crate: real knapsacks come with counts. The direct
translation of chapter 17's table weighs every copy count at every
cell.

The dry run: the fixture is one item of weight 4, value 5, count 2
against capacity 8, asserted the same way in C, Go, Java, C\#,
JavaScript, Python, and Lua, with the count 3 variant against 12,
fixture A at 31 and fixture B at 25, and the brute walk over every
multiplicity tuple riding along as the oracle in each suite.

+ The copy scan starts at k = 0 and consults all 9 cells, every one
  reading the zero row: capacities 0 to 3 stay 0.
+ k = 1 starts at cell 4, the first its weight fits, and consults 5
  cells: 0 + 5 = 5 lands at capacities 4 through 8.
+ k = 2 starts at cell 8 and consults 1: two whole items fill the
  capacity, 5 + 5 = 10.
+ The meter reads 9 + 5 + 1 = 15 consults and the row closes at 0,
  0, 0, 0, 5, 5, 5, 5, 10, the answer 10 at capacity 8.
+ Count 3 against capacity 12 reads the same way, three whole items
  pay 15, the second pinned answer.
+ The pieces road covers the counts with 0/1 items: 13 splits into
  pieces 1, 2, 4, 6 with 1 + 2 + 4 + 6 = 13, and the suite checks
  every count from 1 to 40 reassembles.

#diagram([the copy scan as one row per count, every cell each k consults shaded, the finished row and its 10 below], length: 13pt, {
  // rows k = 0, 1, 2 over capacities 0..8, then the final row
  for k in range(3) {
    let y = 7.2 - k * 0.95
    cdraw.content((0.6, y), [k = #k], size: 6pt)
    for c in range(9) {
      cdraw.rect((1.9 + c * 1.15, y - 0.32), (3.0 + c * 1.15, y + 0.32), fill: if c >= 4 * k { luma(205) } else { luma(235) }, radius: 0.02)
    }
    cdraw.content((12.7, y), [#(9 - 4 * k) consults], size: 6pt)
  }
  let fin = (0, 0, 0, 0, 5, 5, 5, 5, 10)
  for c in range(9) {
    cdraw.rect((1.9 + c * 1.15, 3.4), (3.0 + c * 1.15, 4.15), fill: if c == 8 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.45 + c * 1.15, 3.66), [#(fin.at(c))], size: 6pt)
    cdraw.content((2.45 + c * 1.15, 4.6), [#c], size: 6pt)
  }
  cdraw.content((0.6, 3.66), [final], size: 6pt)
  cdraw.content((12.7, 3.78), [15 consults, answer 10], size: 6pt)
  cdraw.content((12.7, 2.6), [count 3 vs 12: 15], size: 6pt)
  cdraw.content((12.7, 1.7), [pieces of 13: 1 + 2 + 4 + 6], size: 6pt)
})

The 15 consults close at the pinned 10, and the listings below
carry the naive pass, the pieces, and the reused 0/1 walk in seven
languages.

#listing("dsa/samples-c/src/Ch19/bounded.c", first: 22, last: 60, caption: [c, the copy scan with its per-k meter, then the binary pieces])

#listing("dsa/samples-go/ch19/bounded.go", first: 8, last: 48, caption: [go, the naive scan behind a meter struct, the pieces beside it])

#listing("dsa/samples-java/src/Ch19/Bounded.java", first: 22, last: 61, caption: [java, the metered copy scan with its per-k split, then the binary pieces])

#listing("dsa/samples/src/Ch19/AdvDp.cs", first: 11, last: 71, caption: [c\#, bounded knapsack by copy count, binary pieces, the reused 0/1 pass])

#listing("dsa/samples-js/src/ch19-bounded.mjs", first: 5, last: 46, caption: [javascript, the metered naive, the pieces, the 0/1 handoff])

#listing("dsa/samples-py/src/Ch19/bounded.py", first: 27, last: 65, caption: [python, the naive with a per-k meter dict, the pieces, the scaled pass])

#listing("dsa/samples-lua/ch19_bounded.lua", first: 7, last: 57, caption: [lua, the naive noting consults per k, the pieces, the 0/1 walk])

The naive is honest but repetitious. On one item of weight 4, value
5, count 2 against capacity 8 it consults 15 cells, 9 for zero
copies, 5 for one, 1 for two, and answers 10, two whole items
filling weight 8. Count 3 against capacity 12 answers 15 the same
way. The C\# suite adds 25 seeded instances of up to 4 items
against a brute force that enumerates every multiplicity vector.
Binary decomposition buys the same answers cheaper: count 13 splits
into pieces 1, 2, 4, 6 whose subset sums cover every count from 0
to 13, each item collapses to a logarithmic number of 0/1 pieces,
and the chapter 17 backward pass does the rest. The pieces always
reassemble, the suite checks every count from 1 to 40.

The six new lanes answer from the same literals: 10 and 15 on the
single item, 31 on fixture A and 25 on fixture B, the pieces of 13
reading 1, 2, 4, 6 and of 7 reading 1, 2, 4 with the 1 to 40
reassembly lane beside them. The meter granularity splits by tree:
C, Java, Python, and Lua record the per-k counts 9, 5, 1 next to
the 15 total, Go and JavaScript count the 15 alone, and every tree
keeps the multiplicity brute force as its oracle. The scaled pieces
multiply weight and value together in all six, and a piece scaled
on weight alone would fail the oracle lanes.

#diagram([the bounded knapsack as memory, copies tried per cell on the left, binary pieces as 0/1 rows on the right, the shading marks where values rise], length: 13pt, {
  // item (w4, v5, x2) against capacity 8, count rows beside piece rows
  cdraw.content((7.0, 8.45), [count table: copies 0 to 2], size: 6.5pt)
  cdraw.content((19.0, 8.45), [decomposed: 0/1 pieces], size: 6.5pt)
  let count = (
    ((0, 0, 0, 0, 0, 0, 0, 0, 0), [0 copies], ()),
    ((0, 0, 0, 0, 5, 5, 5, 5, 5), [1 copy], (1, 4)),
    ((0, 0, 0, 0, 5, 5, 5, 5, 10), [2 copies], (2, 8)),
  )
  let pieces = (
    ((0, 0, 0, 0, 5, 5, 5, 5, 5), [1x w4 v5], ()),
    ((0, 0, 0, 0, 5, 5, 5, 5, 10), [2x w8 v10], (1, 8)),
  )
  let grid = (rows, x0, lx) => {
    for (r, row) in rows.enumerate() {
      let (vals, label, hot) = row
      cdraw.content((lx, 7.1 - r * 0.9), label, size: 6pt)
      for (c, v) in vals.enumerate() {
        let chosen = hot.len() == 2 and hot.at(0) == r and hot.at(1) == c
        cdraw.rect((x0 + c * 0.9, 6.7 - r * 0.9), (x0 + 0.9 + c * 0.9, 7.5 - r * 0.9), fill: if chosen { luma(205) } else { luma(235) }, radius: 0.02)
        cdraw.content((x0 + 0.45 + c * 0.9, 7.1 - r * 0.9), [#v], size: 6pt)
      }
    }
  }
  grid(count, 3.0, 1.3)
  grid(pieces, 14.9, 12.9)
  for c in range(9) {
    cdraw.content((3.45 + c * 0.9, 7.95), [#c], size: 6pt)
    cdraw.content((15.35 + c * 0.9, 7.95), [#c], size: 6pt)
  }
  cdraw.content((7.0, 4.3), [each cell tries k = 0, 1, 2 copies], size: 6pt)
  cdraw.content((7.0, 3.4), [15 consults on this instance], size: 6pt)
  cdraw.content((7.0, 2.5), [the answer 10 needs both copies], size: 6pt)
  cdraw.content((19.0, 5.2), [count 2 = pieces 1x, 1x], size: 6pt)
  cdraw.content((19.0, 4.3), [one pass per piece], size: 6pt)
  cdraw.content((19.0, 3.4), [final rows agree exactly], size: 6pt)
  cdraw.content((19.0, 2.5), [fewer scans, same answers], size: 6pt)
})

== the sliding window shortcut

Decomposition removed the counts from the item dimension, but the
cell dimension still pays for them, and the naive reweighs
candidates that cannot have changed. The structure to notice is
vertical: a cell of capacity c only ever reads cells c - k*w for k
up to the count, and those are the earlier cells of one residue
class of capacity mod w. Number the class by j and the recurrence
collapses to a window maximum, subtract j*v from the previous row,
keep the max of the last count+1 entries, add j*v back.

The dry run: the fixture is the same single item, weight 4, value 5,
count 2 against capacity 8, asserted by all seven suites with both
meters attached, 9 window consults against the count scan's 15 on
the same answer 10.

+ Capacity mod 4 splits the nine cells into four classes: 0, 4, 8
  then 1, 5 then 2, 6 then 3, 7.
+ Class 0 numbers its cells j = 0, 1, 2 and reads the previous row
  through g = prev - j x 5, landing 0, -5, -10.
+ The deque keeps j = 0 as its front against both arrivals, so the
  cells pay 0 + 0 = 0, 0 + 5 = 5, 0 + 10 = 10.
+ The three two-cell classes never see a rival candidate, and the
  row closes 0, 0, 0, 0, 5, 5, 5, 5, 10, the same 10.
+ The window meter reads 3 + 2 + 2 + 2 = 9, one consult per capacity
  cell, against the count scan's 15.

#diagram([the capacity axis split into its four residue classes, one consult pip per cell, the class 0 lane carrying its g values and its winning front], length: 13pt, {
  // four lanes at capacity-proportional x, class 0 holds 0,4,8 with g 0,-5,-10
  let cx = c => 2.2 + c * 1.7
  let lanes = (
    (((0, 4, 8)), (0, -5, -10), (0, 5, 10), [class 0], true),
    (((1, 5)), (0, -5), (0, 5), [class 1], false),
    (((2, 6)), (0, -5), (0, 5), [class 2], false),
    (((3, 7)), (0, -5), (0, 5), [class 3], false),
  )
  for (l, lane) in lanes.enumerate() {
    let (cells, gs, dps, name, hot) = lane
    let y = 7.6 - l * 1.9
    cdraw.content((0.6, y), name, size: 6pt)
    for (k, c) in cells.enumerate() {
      cdraw.rect((cx(c) - 0.66, y - 0.7), (cx(c) + 0.66, y + 0.7), fill: if hot { luma(205) } else { luma(235) }, stroke: if hot and k == 0 { luma(100) }, radius: 0.02)
      cdraw.content((cx(c), y + 0.5), [c#c], size: 6pt)
      cdraw.content((cx(c), y + 0.08), [g #(gs.at(k))], size: 6pt)
      cdraw.content((cx(c), y - 0.34), [#(dps.at(k))], size: 6pt)
      cdraw.circle((cx(c), y - 1.05), radius: 0.09, fill: luma(100))
    }
  }
  cdraw.content((17.6, 7.6), [one pip, one consult], size: 6pt)
  cdraw.content((17.6, 6.5), [front j = 0 wins each window], size: 6pt)
  cdraw.content((17.6, 5.4), [row: 0 0 0 0 5 5 5 5 10], size: 6pt)
  cdraw.content((17.6, 4.3), [3 + 2 + 2 + 2 = 9 consults], size: 6pt)
  cdraw.content((17.6, 3.2), [the count scan paid 15], size: 6pt)
  cdraw.content((17.6, 2.1), [same answer: 10], size: 6pt)
})

The 9 against 15 on the same answer 10 is the pinned pair, and the
listings below run the class walk in seven languages.

#listing("dsa/samples-c/src/Ch19/window.c", first: 78, last: 111, caption: [c, the g value helper, the deque per residue class, one consult per cell])

#listing("dsa/samples-go/ch19/window.go", first: 3, last: 36, caption: [go, one class per residue, the deque holding plain prev indices])

#listing("dsa/samples-java/src/Ch19/Window.java", first: 73, last: 104, caption: [java, the g helper over a copied prev row, one deque per residue class, a consult per cell])

#listing("dsa/samples/src/Ch19/AdvDp.cs", first: 73, last: 103, caption: [c\#, bounded knapsack by residue class, a monotone deque serves each window])

#listing("dsa/samples-js/src/ch19-window.mjs", first: 1, last: 31, caption: [javascript, rows kept by swapping, dominated candidates pop from the back])

#listing("dsa/samples-py/src/Ch19/window.py", first: 15, last: 36, caption: [python, the class walk, candidates scored by a closure over prev])

#listing("dsa/samples-lua/ch19_window.lua", first: 52, last: 79, caption: [lua, the G closure over prev, table.remove aging the head])

A monotone deque serves that max with one consult per cell: on the
pinned instance the count table consults 15 candidates and the
window consults 9, one per capacity cell, both answering 10. The
figure follows residue class 0 of a real two item instance at
capacity 18: the row 0, 7, 14, 14, 14, 14, 14 was left by an item
of weight 3 and value 7, then the item of weight 3, value 4, count 2
walks the class with its deque. Each index enters the deque once and
leaves at most once, from the back when a better candidate dominates
it, from the front when it slides past the count, so the total work
is items times capacity whatever the counts say, and the C\# suite's
25 seeded instances agree with the naive exactly.

The six new lanes pin the same 9 against 15 pair, and the
agreement lane widens it: window, count scan, and binary
decomposition answer 31 on fixture A and 25 on fixture B, and the
window matches the count scan at every capacity from 0 to 12 of
fixture A. C and Java score their candidates through a g helper,
Go, JavaScript, and Python close over the previous row inside the
walk, and JavaScript alone keeps that row by swapping two arrays
where the others copy. Lua carries the lane furthest with 39
consults on fixture A,
13 cells for each of 3 items, and a pinned deque trace showing an
equal g pops the older candidate, the <= that keeps the window
strict.

#diagram([one residue class of capacity mod 3 under the second item, the deque under each cell, back evictions shaded below, front evictions above], length: 13pt, {
  // items (w3, v7, x2) then (w3, v4, x2), capacity 18, residue 0
  cdraw.content((9.3, 8.75), [item (w3, v4, x2) over residue 0 of capacity mod 3], size: 6.5pt)
  let caps = (0, 3, 6, 9, 12, 15, 18)
  let gs = (0, 3, 6, 2, -2, -6, -10)
  let dps = (0, 7, 14, 18, 22, 22, 22)
  let stacks = ((0,), (1,), (2,), (2, 3), (2, 3, 4), (3, 4, 5), (4, 5, 6))
  let back = ((), (0,), (1,), (), (), (), ())
  let front = ((), (), (), (), (), (2,), (3,))
  for j in range(7) {
    let cx = 1.5 + j * 2.25
    cdraw.content((cx, 8.1), [c=#caps.at(j)], size: 6pt)
    cdraw.content((cx, 7.55), [g=#gs.at(j)], size: 6pt)
    cdraw.rect((cx - 0.5, 6.8), (cx + 0.5, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((cx, 7.1), [#dps.at(j)], size: 6pt)
    let dq = stacks.at(j)
    for (k, idx) in dq.enumerate() {
      let y = 5.85 - k * 0.55
      cdraw.rect((cx - 0.3, y - 0.22), (cx + 0.3, y + 0.22), fill: luma(235), stroke: if k == 0 { luma(100) }, radius: 0.02)
      cdraw.content((cx, y), [#idx], size: 6pt)
    }
    for idx in back.at(j) {
      let y = 5.85 - dq.len() * 0.55
      cdraw.rect((cx - 0.3, y - 0.22), (cx + 0.3, y + 0.22), fill: luma(205), radius: 0.02)
      cdraw.content((cx, y), [#idx], size: 6pt)
    }
    for idx in front.at(j) {
      cdraw.rect((cx - 0.3, 6.18), (cx + 0.3, 6.62), fill: luma(205), radius: 0.02)
      cdraw.content((cx, 6.4), [#idx], size: 6pt)
    }
  }
  cdraw.content((19.7, 7.1), [prev: 0, 7, 14, 14], size: 6pt)
  cdraw.content((19.7, 6.1), [g = prev - j*v], size: 6pt)
  cdraw.content((19.7, 5.1), [max of last 3], size: 6pt)
  cdraw.content((19.7, 4.1), [stroked front wins], size: 6pt)
  cdraw.content((19.7, 3.1), [shaded: evicted], size: 6pt)
  cdraw.content((19.7, 2.1), [back: dominated], size: 6pt)
  cdraw.content((19.7, 1.1), [front: too far back], size: 6pt)
  cdraw.content((19.7, 0.2), [one consult per cell], size: 6pt)
})

#callout("pitfall", "the window reads the previous row", [
  The deque trick stays bounded only because every candidate comes
  from `prev`, the row as it stood before this item. Reading the
  live `dp` array while updating it lets a candidate reuse copies of
  the current item through cells already written this pass, which is
  exactly the unbounded knapsack, and the answers drift upward on
  any item with count 2 or more. The `Array.Copy` snapshot per item
  is the whole correctness argument, one line of it.
])

== the grouped knapsack

The other generalization keeps exclusivity and drops counts: the
menu has groups, and the knapsack must take exactly one option from
each. The recurrence takes a max over options where the 0/1 table
chose between skipping and taking, and an unreachable marker carries
the budgets no option fits.

The dry run: the fixture is the three-group menu against capacity
10, asserted by all seven suites, the groups reading 2 or 4 at 20 or
40, 3 or 6 at 30 or 60, 5 or 1 at 50 or 10, with the capacity 7
answer of 60 and the infeasible capacities 5 and 3 at -1 pinned
beside it.

+ Group 0 alone fills the first row: capacity 2 reads 0 + 20 = 20
  and capacity 4 reads 0 + 40 = 40.
+ Group 1 over that row: capacity 5 reads 30 + 20 = 50, capacity 9
  reads 60 + 20 = 80, capacity 10 reads 60 + 40 = 100.
+ Group 2 over that: capacity 10 weighs 50 + 50 = 100 against 10 +
  80 = 90 and the table closes at 100.
+ The rebuild walks back through weights 2, 3, 5, spending 2 + 3 +
  5 = 10 exactly, one option per group, 20 + 30 + 50 = 100.
+ Greedy per group takes 40 then 60, spends 4 + 6 = 10, strands
  group 2, and serves only 2 of the 3 groups at the same total.

#diagram([the budget bar filling group by group along the table's chosen path, the greedy bar below spending 4 and 6 with nothing left for group 2], length: 13pt, {
  // three table bars then the greedy bar, each 10 units wide
  let bars = (
    ((((2, 20),)), [after group 0], 20),
    ((((2, 20), (3, 30))), [after group 1], 50),
    ((((2, 20), (3, 30), (5, 50))), [after group 2], 100),
  )
  let bx = 2.4
  for (b, bar) in bars.enumerate() {
    let (segs, lab, val) = bar
    let y = 7.2 - b * 1.15
    cdraw.content((0.6, y), lab, size: 6pt)
    let x = bx
    for (w, v) in segs {
      cdraw.rect((x, y - 0.3), (x + w, y + 0.3), fill: luma(205), radius: 0.02)
      cdraw.content((x + w / 2, y), [#w: #v], size: 6pt)
      x += w
    }
    cdraw.rect((x, y - 0.3), (bx + 10, y + 0.3), fill: none, stroke: luma(160), radius: 0.02)
    cdraw.content((14.0, y), [total #val], size: 6pt)
  }
  // the greedy bar: 4 then 6, no room left for group 2
  let y = 7.2 - 3 * 1.15
  cdraw.content((0.6, y), [greedy], size: 6pt)
  cdraw.rect((bx, y - 0.3), (bx + 4, y + 0.3), fill: luma(205), radius: 0.02)
  cdraw.content((bx + 2, y), [4: 40], size: 6pt)
  cdraw.rect((bx + 4, y - 0.3), (bx + 10, y + 0.3), fill: luma(235), radius: 0.02)
  cdraw.content((bx + 7, y), [6: 60], size: 6pt)
  cdraw.content((14.0, y), [100, two groups], size: 6pt)
  cdraw.content((8.5, 1.6), [table spends 2 + 3 + 5 = 10 exactly], size: 6pt)
  cdraw.content((8.5, 0.7), [greedy strands group 2], size: 6pt)
})

The table serves all three groups at 100 with the bar exactly full,
and the listings below carry the build and its rebuild in seven
languages.

#listing("dsa/samples-c/src/Ch19/grouped.c", first: 30, last: 72, caption: [c, capacity ascending then options ascending, the choice table read back])

#listing("dsa/samples-go/ch19/grouped.go", first: 17, last: 65, caption: [go, min int over 4 marking unreachable, picks rebuilt from the choice grid])

#listing("dsa/samples-java/src/Ch19/Grouped.java", first: 20, last: 67, caption: [java, a record per option, the quarter-of-min unreachable sentinel, the choice table read back])

#listing("dsa/samples/src/Ch19/AdvDp.cs", first: 105, last: 149, caption: [c\#, grouped knapsack, one option per group, reconstruction from the choice table])

#listing("dsa/samples-js/src/ch19-grouped.mjs", first: 8, last: 45, caption: [javascript, minus infinity sentinels, value and chosen returned together])

#listing("dsa/samples-py/src/Ch19/grouped.py", first: 16, last: 44, caption: [python, none flags unreachable cells, no sentinel arithmetic at all])

#listing("dsa/samples-lua/ch19_grouped.lua", first: 6, last: 41, caption: [lua, nil for unreachable, one-based options emitted zero-based])

On the instance of three groups against capacity 10 the answer is
100, weights 2, 3 and 5 summing to the budget exactly, and the
reconstruction is property checked: the indices are valid, one per
group, the weight stays within 10, the values sum back to 100.
Greedy per group takes the best option of each, 40 then 60, spends
the whole budget and strands the third group with only two groups
served, while the table serves all three and still totals 100. Any
bundle that must pick one vendor per slot is this shape.

Every lane pins the same three landings: 100 with the picks 0, 0,
0 at capacity 10, 60 with the picks 0, 0, 1 at capacity 7 where
the light 1 for 10 option replaces the heavy 5 for 50, and -1 at
capacities 5 and 3 where the minimum load of 6 cannot fit. The
unreachable marker is where the trees part: C and Java guard a long
min over 4, Go a min int over 4, JavaScript minus infinity, Python
a none flag that skips the arithmetic, Lua nil. The readback lands
the same picks everywhere because the scans run capacity ascending
then options ascending and only a strictly greater candidate
rewrites a cell, and the brute force over the 8 option tuples
confirms 100 and 60 in each suite.

#diagram([the grouped knapsack, one shaded option per group, the budget bar filled exactly by weights 2, 3 and 5], length: 13pt, {
  // groups ((2,20),(4,40)), ((3,30),(6,60)), ((5,50),(1,10)) at capacity 10
  cdraw.content((8.4, 8.15), [three groups, one option each, capacity 10], size: 6.5pt)
  let groups = (
    (((2, 20), true), ((4, 40), false)),
    (((3, 30), true), ((6, 60), false)),
    (((5, 50), true), ((1, 10), false)),
  )
  let segs = ((3.4, 5.4, 2), (5.4, 8.4, 3), (8.4, 13.4, 5))
  for (g, col) in groups.enumerate() {
    let cx = 3.4 + g * 5.2
    cdraw.content((cx, 7.3), [group #g], size: 6pt)
    for (o, cell) in col.enumerate() {
      let (opt, chosen) = cell
      let y = 6.4 - o * 1.1
      cdraw.rect((cx - 1.3, y - 0.4), (cx + 1.3, y + 0.4), fill: if chosen { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((cx, y), [(#opt.at(0), #opt.at(1))], size: 6pt)
      if chosen {
        let (sx0, sx1, wgt) = segs.at(g)
        cdraw.line((cx, y - 0.4), ((sx0 + sx1) / 2, 3.55), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
      }
    }
  }
  cdraw.content((2.0, 3.1), [budget], size: 6pt)
  for (sx0, sx1, wgt) in segs {
    cdraw.rect((sx0, 2.7), (sx1, 3.5), fill: luma(205), radius: 0.02)
    cdraw.content(((sx0 + sx1) / 2, 3.1), [#wgt], size: 6pt)
  }
  cdraw.content((3.4, 2.2), [0], size: 6pt)
  cdraw.content((13.4, 2.2), [10], size: 6pt)
  cdraw.content((8.4, 1.5), [10 of 10 spent], size: 6pt)
  cdraw.content((19.0, 7.3), [one option per group], size: 6pt)
  cdraw.content((19.0, 6.2), [greedy: 40 then 60], size: 6pt)
  cdraw.content((19.0, 5.1), [group 2 strands], size: 6pt)
  cdraw.content((19.0, 4.0), [dp: 20+30+50 = 100], size: 6pt)
  cdraw.content((19.0, 2.9), [weight exactly 10], size: 6pt)
  cdraw.content((8.4, 0.6), [the rebuild returns one index per group], size: 6pt)
})

== convex hull trick

Partition costs hide a quadratic in plain sight. Split a sequence
into consecutive groups, pay the square of each group sum plus a
constant per group, and the recurrence weighs every split point
against every prefix: dp of i is the minimum over j below i of dp of
j plus the square of the gap between prefix sums plus the constant.
Expand that square and the part that still depends on j is a line in
the prefix sum S(j), slope minus 2 S(j), intercept dp of j plus S(j)
squared, and the query lands at x equal to S(i). Prefix sums of
nonnegative values only grow, so the slopes arrive strictly
decreasing and the queries only move right, exactly the contract of
a pointer hull.

The dry run: the fixture is 1, 2, 3 with constant 10, asserted by
all seven suites at 38, with constant 0 at 14, 3, 1, 4, 1, 5 at
constant 2 at 62, and 2, 2, 2, 2 at constant 3 at 28, the naive
split scan agreeing in every tree, and the C\# suite alone running
the seeded n = 200 meters.

+ The prefix sums read S = 0, 1, 3, 6, and every candidate split
  hangs off them.
+ Solo groups 1, 2, 3 cost 1 + 4 + 9 = 14 plus 3 x 10 = 30, a
  total of 44.
+ The split after the 2 costs 9 + 9 = 18 plus 2 x 10 = 20, a total
  of 38, the cheapest.
+ The split after the 1 costs 1 + 25 = 26 plus 20, a total of 46,
  and the whole run costs 36 + 10 = 46.
+ At n = 200 the naive weighs its pinned 19900 split points while
  the hull adds 200 lines and answers 200 queries, 200 + 200 = 400
  touches, the same totals.

#diagram([every split of 1, 2, 3 weighed, groups boxed with their costs beside, the cheapest after the 2 shaded], length: 13pt, {
  // rows: [1][2][3] 44, [1 2][3] 38, [1][2 3] 46, [1 2 3] 46
  let rows = (
    ((((0,), (1,), (2,))), 44, false),
    ((((0, 1), (2,))), 38, true),
    ((((0,), (1, 2))), 46, false),
    ((((0, 1, 2),)), 46, false),
  )
  for (r, row) in rows.enumerate() {
    let (groups, cost, hot) = row
    let y = 7.6 - r * 1.2
    for g in groups {
      let x0 = 1.6 + g.first() * 1.5
      let x1 = 1.6 + g.last() * 1.5 + 1.3
      cdraw.rect((x0, y - 0.35), (x1, y + 0.35), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
      for i in g {
        cdraw.content((2.25 + i * 1.5, y), [#(i + 1)], size: 6pt)
      }
    }
    cdraw.content((7.6, y), [#cost], size: 6pt)
    if hot { cdraw.content((9.0, y), [cheapest, after the 2], size: 6pt) }
  }
  cdraw.content((14.6, 6.4), [prefix sums 0, 1, 3, 6], size: 6pt)
  cdraw.content((14.6, 5.2), [cost = sum of squares + 10 a group], size: 6pt)
  cdraw.content((14.6, 3.2), [n = 200: naive 19900], size: 6pt)
  cdraw.content((14.6, 2.2), [hull 200 + 200 = 400], size: 6pt)
  cdraw.content((14.6, 1.2), [same totals, pinned], size: 6pt)
})

The 38 is the small pinned landing and 400 the metered big one, and
the listings below drive the recurrence through the hull in seven
languages.

#listing("dsa/samples-c/src/Ch19/cht.c", first: 33, last: 76, caption: [c, the cross-multiplied overtaken test, add, query, the partition loop])

#listing("dsa/samples-go/ch19/cht.go", first: 36, last: 77, caption: [go, the forward pointer, the overtaken test, the recurrence and its naive twin])

#listing("dsa/samples-java/src/Ch19/Cht.java", first: 21, last: 74, caption: [java, a nested Hull carrying its own line and query meters, the cross-multiplied test, the recurrence])

#listing("dsa/samples/src/Ch19/AdvDp.cs", first: 151, last: 214, caption: [c\#, a monotone hull of lines, then the partition recurrence driven through it])

#listing("dsa/samples-js/src/ch19-cht.mjs", first: 5, last: 56, caption: [javascript, a private-field hull, cross-multiplied overtaken, forward pointer])

#listing("dsa/samples-py/src/Ch19/cht.py", first: 22, last: 68, caption: [python, the hull then the partition recurrence it serves])

#listing("dsa/samples-lua/ch19_cht.lua", first: 7, last: 55, caption: [lua, closures over the line arrays, the recurrence in one-based prefix sums])

The naive weighs n(n-1)/2 split points, 19900 at n = 200, and the
C\# suite pins that count on the seeded instance. The hull adds one
line per split point and answers one query per prefix, 200 and 200,
a total of 400 touches, and returns the same totals as the naive
there, on the C\# suite's 25 seeded arrays up to 60 elements, and on
the small case: 1, 2, 3 with constant 10 costs 38, cheapest split
after the 2. Dominated lines pop on arrival and the query pointer
never walks backward, so each line and each query is touched once,
which is what the counters assert.

The six new lanes hold the same envelope. The overtaken test
cross-multiplies in 64-bit integers and reads <= in every tree,
long long in C, long in Java with every product exact, int64 in Go,
Lua integers, Python's native ints, and JavaScript numbers exact at
these magnitudes, and the query
pointer only walks forward. The counter lane agrees everywhere, 3
values grow 3 hull lines and answer 3 queries, and the naive scan
returns 38, 14, 62, and 28 on the four fixtures in each suite. Lua
squares the gap by multiplication to stay in integers and pins the
naive meter at 10 interior splits for the 5 value fixture, the
quadratic count the hull removes.

#diagram([the split points as lines, the lower envelope heavier, three queries at successive x positions], length: 13pt, {
  // y = b + m*x for four arriving lines, lower envelope, queries at 3, 6, 9
  cdraw.content((9.3, 8.15), [four lines arrive, the envelope holds the minimum], size: 6.5pt)
  let rx = x => 1.8 + x * 1.4
  let ry = y => 1.2 + (y + 7.0) / 20.0 * 6.2
  cdraw.line((rx(0), ry(13)), (rx(0), ry(-7)), stroke: luma(100))
  cdraw.line((rx(0), ry(-7)), (rx(10), ry(-7)), stroke: luma(100))
  let seg = (m, b, x0, x1, heavy) => cdraw.line((rx(x0), ry(m * x0 + b)), (rx(x1), ry(m * x1 + b)), stroke: if heavy { (paint: luma(100), thickness: 2.5pt) } else { luma(180) })
  seg(-0.6, 3, 0, 10, false)
  seg(-1.0, 5, 0, 10, false)
  seg(-1.4, 8, 0, 10, false)
  seg(-1.7, 12, 0, 10, false)
  seg(-0.6, 3, 0, 5, true)
  seg(-1.0, 5, 5, 7.5, true)
  seg(-1.4, 8, 7.5, 10, true)
  let labels = (([j1], 4.55), ([j2], 5.3), ([j3], 6.15), ([j4], 7.2))
  for (label, y) in labels {
    cdraw.content((2.35, y), label, size: 6pt)
  }
  for (x, m, b) in ((3, -0.6, 3), (6, -1.0, 5), (9, -1.4, 8)) {
    let y = m * x + b
    cdraw.line((rx(x), ry(y)), (rx(x), ry(-7)), stroke: (paint: luma(180), dash: "dashed"))
    cdraw.circle((rx(x), ry(y)), radius: 0.09, fill: luma(100))
  }
  let names = ([1st], [2nd], [3rd])
  for (i, x) in (3, 6, 9).enumerate() {
    cdraw.content((rx(x), 0.85), names.at(i), size: 6pt)
  }
  cdraw.line((rx(3), 0.35), (rx(8.6), 0.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, -0.3), [the j dependent part of dp of j plus the squared gap is a line in S(j)], size: 6pt)
  cdraw.content((19.6, 7.3), [slopes arrive falling], size: 6pt)
  cdraw.content((19.6, 6.3), [queries move right], size: 6pt)
  cdraw.content((19.6, 5.3), [the pointer rises], size: 6pt)
  cdraw.content((19.6, 4.3), [j4 wins past x = 10], size: 6pt)
  cdraw.content((19.6, 3.3), [naive weighs 19900], size: 6pt)
  cdraw.content((19.6, 2.3), [hull touches 400], size: 6pt)
  cdraw.content((19.6, 1.3), [agrees with naive], size: 6pt)
})

#callout("warning", "the pointer hull is conditional", [
  The pointer walk is amortized constant only while the contract
  holds: slopes arrive strictly decreasing and queries land at
  nondecreasing x. The partition keeps both because values are
  nonnegative, so prefix sums only grow, slopes only fall, and query
  positions only rise. One negative value breaks all three at once.
  Outside the contract the fix is a binary search inside `Query` or
  a Li Chao tree, a log factor either way, and the naive stays the
  cross-check.
])

== longest increasing subsequence

The last speedup is the same story in miniature: keep less, search
what you keep. The array tails holds, for each length, the index of
the smallest value that ends an increasing run of that length. The
tracked values stay sorted, so every element lower bounds into the
array, replaces the first tail it cannot extend and links its
parent, or appends and grows the run.

The dry run: the fixture is 10, 9, 2, 5, 3, 7, 101, 18, asserted by
all seven suites with the 2, 2, 2 pair and the 1, 2, 2, 3 pair beside
it, the n = 1000 meter a C\# lane, and the pairs table oracle
carried in every tree.

+ 10 opens the tails, 9 and 2 each replace it, and 5 appends: the
  tails read 2, 5 at length 2.
+ 3 replaces 5, 7 appends, 101 appends: 2, 3, 7, 101 at length 4.
+ 18 replaces 101 by the lower bound and the tails close at 2, 3,
  7, 18, length 4.
+ The parents chain back from index 7: 7 to 5 to 4 to 2, and the
  rebuild reads indices 2, 4, 5, 7 with values 2, 3, 7, 18,
  climbing in both position and value.
+ On 2, 2, 2 the strict lower bound keeps length 1 while the upper
  bound variant keeps all three, 3.
+ At n = 1000 the pairs table consults its pinned 499500 pairs while
  the tails search stays inside 10 x 1000 = 10000 comparisons.

#diagram([the run shaded on the array, the parent chain walking back from index 7, the strict and slack readings of 2, 2, 2 below], length: 13pt, {
  // 10 9 2 5 3 7 101 18 with run indices 2,4,5,7 shaded
  let a = (10, 9, 2, 5, 3, 7, 101, 18)
  let run = (2, 4, 5, 7)
  for (i, v) in a.enumerate() {
    let x = 1.6 + i * 2.1
    cdraw.rect((x, 6.7), (x + 1.7, 7.5), fill: if i in run { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.85, 7.1), [#v], size: 6pt)
    cdraw.content((x + 0.85, 6.25), [#i], size: 6pt)
  }
  // the parent links: 7 -> 5 -> 4 -> 2 at staggered depths
  let ax = i => 2.45 + i * 2.1
  cdraw.line((ax(7) - 0.25, 5.75), (ax(5) + 0.55, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((ax(5) - 0.25, 5.15), (ax(4) + 0.55, 5.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((ax(4) - 0.25, 4.55), (ax(2) + 0.55, 4.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.4, 5.75), [parents], size: 6pt)
  cdraw.content((12.4, 4.55), [2 3 7 18, indices 2 4 5 7], size: 6pt)
  // 2 2 2 twice: strict keeps one, slack keeps three
  for (r, lab, hot) in ((3.0, [strict], (0,)), (1.9, [slack], (0, 1, 2))) {
    cdraw.content((1.6, r - 0.35), lab, size: 6pt)
    for c in range(3) {
      cdraw.rect((3.0 + c * 1.1, r - 0.75), (4.0 + c * 1.1, r + 0.05), fill: if c in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((3.5 + c * 1.1, r - 0.35), [2], size: 6pt)
    }
  }
  cdraw.content((7.6, 2.45), [strict 1, slack 3], size: 6pt)
  cdraw.content((12.4, 1.4), [n = 1000: 499500 pairs], size: 6pt)
  cdraw.content((12.4, 0.5), [tails inside 10 x 1000 = 10000], size: 6pt)
})

The length 4 with its rebuilt indices is the pinned landing, and the
listings below carry the tails, the parents, and the slack variant
in seven languages.

#listing("dsa/samples-c/src/Ch19/tails.c", first: 19, last: 65, caption: [c, the strict lower bound with parent links, the upper bound variant])

#listing("dsa/samples-go/ch19/tails.go", first: 6, last: 52, caption: [go, the strict walk with its probe meter, parents rebuilt backward])

#listing("dsa/samples-java/src/Ch19/Tails.java", first: 19, last: 73, caption: [java, the strict lower bound with parent links, the upper bound variant one comparison away])

#listing("dsa/samples/src/Ch19/AdvDp.cs", first: 239, last: 299, caption: [c\#, strict lis with tails and parents, the non-decreasing variant one bound away])

#listing("dsa/samples-js/src/ch19-tails.mjs", first: 6, last: 47, caption: [javascript, hand-rolled bounds, both variants, indices matching the other lanes])

#listing("dsa/samples-py/src/Ch19/tails.py", first: 14, last: 55, caption: [python, the lower bound replaces equals, the upper bound extends them])

#listing("dsa/samples-lua/ch19_tails.lua", first: 7, last: 53, caption: [lua, a one-based search emitting zero-based indices, both bounds])

On 10, 9, 2, 5, 3, 7, 101, 18 the run 2, 3, 7, 18 has length 4 and
the parent links rebuild its indices, which the test checks strictly
increasing in both position and value. Strict versus slack is one
comparison swapped, the lower bound for the upper, with a number
pinned to it: 2, 2, 2 has strict length 1 and non-decreasing length
3. At n = 1000 the naive pairs table consults 499500 pairs whatever
the data holds, while the tails search stays inside 10 comparisons
per element, the ceiling the C\# suite pins alongside the agreement
of the two lengths.

The new lanes rebuild the same witnesses: indices 2, 4, 5, 7 with
values 2, 3, 7, 18 on the classic fixture, the dip fixture 1, 3, 5,
2, 4, 6 rerouting through 0, 3, 4, 5 with values 1, 2, 4, 6, and
the 16 element fixture landing length 6 through 0, 4, 6, 9, 13,
15. Strict versus slack stays one bound apart everywhere, the
lower bound replaces an equal tail, the upper bound extends past
it, and on 2, 2, 2 that is 1 against 3. The Go lane pins the
strict witness index of 2, 2, 2 at [2], the last of the three
equals, where the other trees assert the length there, and the
n^2 pairs table agrees on length in every suite. JavaScript, Java,
and Lua roll the binary search by hand so the emitted indices match
the other lanes exactly.

#diagram([longest increasing subsequence on 10 9 2 5 3 7 101 18, the tails after each element, replaced tails shaded, appended tails stroked], length: 13pt, {
  // one row per element: the value, the tails array, the cell written this step
  cdraw.content((5.9, 8.15), [the tails array after each element], size: 6.5pt)
  let steps = (
    ([10], (10,), 0, true),
    ([9], (9,), 0, false),
    ([2], (2,), 0, false),
    ([5], (2, 5), 1, true),
    ([3], (2, 3), 1, false),
    ([7], (2, 3, 7), 2, true),
    ([101], (2, 3, 7, 101), 3, true),
    ([18], (2, 3, 7, 18), 3, false),
  )
  for (r, step) in steps.enumerate() {
    let (elem, tails, changed, appended) = step
    let y = 7.4 - r * 0.92
    cdraw.rect((1.9, y - 0.3), (3.0, y + 0.3), fill: luma(235), radius: 0.02)
    cdraw.content((2.45, y), elem, size: 6pt)
    for (k, v) in tails.enumerate() {
      let hot = k == changed and not appended
      cdraw.rect((3.8 + k, y - 0.3), (4.8 + k, y + 0.3), fill: if hot { luma(205) } else { luma(235) }, stroke: if k == changed and appended { luma(100) }, radius: 0.02)
      cdraw.content((4.3 + k, y), [#v], size: 6pt)
    }
    cdraw.content((4.5 + tails.len(), y), [#(tails.len())], size: 6pt)
  }
  cdraw.content((17.4, 7.4), [smallest tail per length], size: 6pt)
  cdraw.content((17.4, 6.3), [lower bound finds the slot], size: 6pt)
  cdraw.content((17.4, 5.2), [shaded: replaced], size: 6pt)
  cdraw.content((17.4, 4.1), [stroked: appended], size: 6pt)
  cdraw.content((17.4, 3.0), [parents rebuild 2 3 7 18], size: 6pt)
  cdraw.content((17.4, 1.9), [answer length 4], size: 6pt)
  cdraw.content((17.4, 0.8), [2 2 2: strict 1, slack 3], size: 6pt)
})

== subsets as state, tsp by held-karp

The assignment problem of chapter 17 compressed a set into an
integer and paid two to the n times n for it. The traveling salesman
is the same mask table with a second coordinate, dp of mask and v is
the cheapest path that starts home, visits exactly the cities in the
mask, and ends at v, and the tour closes by adding the edge home
from every ending city. Brute force over orderings is factorial,
held-karp is two to the n times n squared, and the four-city fixture
prices the difference in code, six table relaxations against six
permutations, but the table keeps winning as cities are added.

The dry run: the fixture is the four-city matrix, 10, 15, 20
against 35, 25, 30, pinned by the C, Go, Java, JavaScript, Python,
and Lua suites at tour cost 80, the C\# build predating the topic,
and the
walk reads the C suite's table cells.

+ The seed is mask 0001 at city 0, value 0: home alone.
+ The first hops land three cells: mask 0011 at city 1 reads 10,
  0101 at city 2 reads 15, 1001 at city 3 reads 20.
+ Two hops share mask 1011: at city 3 it reads 10 + 25 = 35 by way
  of 1, at city 1 it reads 20 + 25 = 45 by way of 3.
+ The full mask at city 2 reads 10 + 25 + 30 = 65, the path 0, 1,
  3, 2.
+ Closing the loop adds the 15 home: 65 + 15 = 80, and the mirror
  0, 2, 3, 1, 0 costs the same.
+ The brute sweep over the six inner orderings agrees at 80, the
  cross-check C, Go, JavaScript, Python, and Lua all carry.

#diagram([the mask table filling by population count, the pinned cells shaded from the seed down to the full mask, the close home at 80], length: 13pt, {
  // levels: 0001@0; 0011@1, 0101@2, 1001@3; 1011@3, 1011@1; 1111@2; close
  let cell = (x, y, mask, city, v) => {
    cdraw.rect((x - 0.9, y - 0.34), (x + 0.9, y + 0.34), fill: luma(205), radius: 0.02)
    cdraw.content((x, y + 0.09), [#mask at #city], size: 6pt)
    cdraw.content((x, y - 0.17), [#v], size: 6pt)
  }
  let lv = l => 7.5 - l * 1.35
  cell(6.0, lv(0), [0001], [0], [0])
  cell(2.4, lv(1), [0011], [1], [10])
  cell(6.0, lv(1), [0101], [2], [15])
  cell(9.6, lv(1), [1001], [3], [20])
  cell(4.2, lv(2), [1011], [3], [35])
  cell(7.8, lv(2), [1011], [1], [45])
  cell(6.0, lv(3), [1111], [2], [65])
  for (a, b) in (((6.0, lv(0)), (2.4, lv(1))), ((6.0, lv(0)), (6.0, lv(1))), ((6.0, lv(0)), (9.6, lv(1)))) {
    cdraw.line(a, b, stroke: luma(220))
  }
  cdraw.line((2.4, lv(1)), (4.2, lv(2)), stroke: luma(100))
  cdraw.line((9.6, lv(1)), (7.8, lv(2)), stroke: luma(100))
  cdraw.line((4.2, lv(2)), (6.0, lv(3)), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.1, lv(2) + 0.75), [+30], size: 6pt)
  cdraw.line((6.0, lv(3) - 0.34), (6.0, lv(3) - 0.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, lv(3) - 1.3), [close home: 65 + 15 = 80], size: 6pt)
  cdraw.content((14.6, lv(1)), [one line per hop], size: 6pt)
  cdraw.content((14.6, 4.3), [mirror 0 2 3 1 0: also 80], size: 6pt)
  cdraw.content((14.6, 3.2), [brute: six orderings agree], size: 6pt)
  cdraw.content((14.6, 2.1), [20 cities: a million masks], size: 6pt)
})

The tour closes at the pinned 80, and the listings below fill this
table in six languages plus the C\# assignment build it grows from.

#listing("dsa/samples-c/src/Ch19/bitmask.c", first: 26, last: 48, caption: [c, the mask table, relax into unvisited cities, close the loop])

#listing("dsa/samples-go/ch19/bitmask.go", first: 10, last: 49, caption: [go, the relax loop, then the tour rebuilt by walking the table])

#listing("dsa/samples-java/src/Ch19/Bitmask.java", first: 24, last: 64, caption: [java, the mask table, the permutation sweep beside it, the arbitrary-matrix walk too])

#listing("dsa/samples/src/Ch17/Dp.cs", first: 170, last: 197, caption: [c\#, the subset dp this chapter builds on, the assignment build])

#listing("dsa/samples-js/src/ch19-bitmask.mjs", first: 5, last: 26, caption: [javascript, infinity for unreachable, one mask per array row])

#listing("dsa/samples-py/src/Ch19/bitmask.py", first: 19, last: 42, caption: [python, the same table, every useful mask contains the start])

#listing("dsa/samples-lua/ch19_bitmask.lua", first: 14, last: 48, caption: [lua, 0-based masks over 1-based tables, maxinteger for infinity])

The four-city fixture is the classic symmetric matrix, 10, 15, 20
against 35, 25, 30, and the tour cost 80 pins in C, Go, Java,
JavaScript, Python, and Lua, with two mirror tours both optimal, 0
to 1 to 3 to 2 and back, 10 plus 25 plus 30 plus 15. Python and
Lua accept either mirror in their order checks, Go rebuilds the
actual tour by walking the table backwards asking which predecessor
still adds up, C and Java brute-force the six inner permutations to
confirm the table, and Java carries Python's arbitrary-matrix walk
beside it, a two-city pair at 2 and the 3, 4, 5 triangle at 12.
The C\# suite predates the topic, so its listing is the assignment
build the mask idea comes from. At twenty cities the table is a
million masks times twenty endpoints and the permutation sweep is
twenty factorial, which is the whole pitch.

#diagram([held-karp on four cities, the mask table ends at every city, the tour closes from the cheapest], length: 13pt, {
  cdraw.content((9.5, 7.9), [the four-city fixture, tour cost 80], size: 6.5pt)
  let pts = ((2.2, 6.4, [0]), (8.2, 7.2, [1]), (8.8, 3.4, [3]), (1.6, 2.6, [2]))
  let d = ((0, 1, [10]), (0, 2, [15]), (0, 3, [20]), (1, 3, [25]), (2, 3, [30]), (1, 2, [35]))
  for e in d {
    let (a, b, lab) = e
    let pa = pts.at(a)
    let pb = pts.at(b)
    let hot = (a, b) in ((0, 1), (1, 3), (2, 3), (0, 2))
    cdraw.line((pa.at(0), pa.at(1)), (pb.at(0), pb.at(1)), stroke: if hot { 1.2pt + luma(30) } else { luma(180) })
    cdraw.content(((pa.at(0) + pb.at(0)) / 2, (pa.at(1) + pb.at(1)) / 2 + 0.25), lab, size: 6pt)
  }
  for p in pts {
    cdraw.circle((p.at(0), p.at(1)), radius: 0.32, fill: luma(235), radius2: 0.32)
    cdraw.content((p.at(0), p.at(1)), p.at(2), size: 6.5pt)
  }
  cdraw.content((9.5, 1.4), [heavy tour: 0 1 3 2 0 = 80], size: 6pt)
  cdraw.content((9.5, 0.5), [its mirror costs the same 80], size: 6pt)
  cdraw.content((16.6, 6.3), [dp[mask][v]: path ends at v], size: 6pt)
  cdraw.content((16.6, 5.2), [relax only into unvisited cities], size: 6pt)
  cdraw.content((16.6, 4.1), [close the loop from every end], size: 6pt)
  cdraw.content((16.6, 3.0), [2^n x n states, n^2 each], size: 6pt)
  cdraw.content((16.6, 1.9), [against n factorial orderings], size: 6pt)
  cdraw.content((16.6, 0.8), [20 cities: a million masks], size: 6pt)
})

== digit dp, counting under a bound

Counting the numbers up to N with some digit property is a walk over
the decimal numeral, not over the numbers. The state is the position,
a tight flag saying the prefix still equals N's prefix, a started
flag for leading zeros, and whatever the property carries, and once
a prefix goes loose every digit is free, which is what collapses a
count over N into a table over the digits of N.

The dry run: the fixture is the hand-count staircase under 99,
asserted by the C\# suite with C, Go, JavaScript, and Lua pinning
the same seven-counts, while Python and Java count weakly
increasing digits instead, 26 at 30 and 54 at 99.

+ Below 7 nothing qualifies, count 0, and 7 alone makes 1.
+ The units column builds toward 70: 7, 17, through 67, count 7 at
  N = 69.
+ At 70 the seventies decade joins: 7 + 1 = 8.
+ At 77 the column meets the decade, the 77 shared: 8 + 8 - 1 = 15.
+ At 99 the full column plus the full decade reads 10 + 10 - 1 = 19,
  which holds at 100.
+ A full thousand misses 9^3 = 729 no-seven strings, so the count
  lands 1000 - 729 = 271.

#diagram([the hand-count staircase rising toward 99, the seventies decade joining at 70, the column and decade meeting at 77], length: 13pt, {
  // bars at n = 7, 69, 70, 77, 99 with counts 1, 7, 8, 15, 19
  let steps = ((7, 1, [7 alone]), (69, 7, [units column]), (70, 8, [70s join]), (77, 15, [meet at 77]), (99, 19, [19 at 99]))
  for (i, s) in steps.enumerate() {
    let (nn, v, lab) = s
    let x = 1.8 + i * 2.6
    cdraw.rect((x, 0.8), (x + 1.6, 0.8 + v * 0.32), fill: if i == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.8, 1.2 + v * 0.32), [#v], size: 6pt)
    cdraw.content((x + 0.8, 0.35), [#nn], size: 6pt)
    cdraw.content((x + 0.8, -0.25), lab, size: 6pt)
  }
  cdraw.content((16.4, 5.6), [at 77: 8 + 8 - 1 = 15], size: 6pt)
  cdraw.content((16.4, 4.6), [at 99: 10 + 10 - 1 = 19], size: 6pt)
  cdraw.content((16.4, 3.6), [at 1000: 1000 - 729 = 271], size: 6pt)
  cdraw.content((16.4, 2.6), [the brute scan is the oracle], size: 6pt)
})

The staircase rests at 19 under 99 and 271 at the thousand, and the
listings below walk the numeral in seven languages.

#listing("dsa/samples-c/src/Ch19/digitdp.c", first: 38, last: 62, caption: [c, loose and tight rows, the has-7 property, per position])

#listing("dsa/samples-go/ch19/digitdp.go", first: 12, last: 61, caption: [go, the memoized walk keyed by position, flags, state])

#listing("dsa/samples-java/src/Ch19/Digitdp.java", first: 36, last: 60, caption: [java, loose and tight rows over the has-7 property, the py climb lane in the same file])

#listing("dsa/samples/src/Ch19/DigitDp.cs", first: 13, last: 51, caption: [c\#, loose and tight rows, the has-7 property, the destination row is seen or this digit])

#listing("dsa/samples-js/src/ch19-digitdp.mjs", first: 8, last: 24, caption: [javascript, the same walk, the digit a parameter])

#listing("dsa/samples-py/src/Ch19/digitdp.py", first: 13, last: 38, caption: [python, digits only climb, the zero artifact subtracted])

#listing("dsa/samples-lua/ch19_digitdp.lua", first: 20, last: 43, caption: [lua, string-keyed memo, the tight prefix never cached])

The properties split, and both are the real technique: C, Go, Java,
C\#, JavaScript, and Lua count numbers containing the digit 7,
with the anchor 19 numbers up to 99 and the staircase of hand
counts below it, 7 alone, 8 at 70, 15 at 77, while Python counts
weakly increasing digits and pins 54 up to 99 with the climb from
26 at 30, Java carrying that climb lane beside its has-7 rows.
Every suite carries the brute-force oracle, a linear scan over the
same range, and the agreement is the test. The caching rule is the
subtle part worth reading twice: the tight path is a single chain,
so Go and Lua memoize only the loose states, Python's leading
zeros cover every shorter number, leaving one all-zero artifact to
subtract, and Java's climb memo holds every state keyed on the
position, previous digit, and flag packed into one long, harmless
because each tight state is visited once anyway.

#diagram([digit dp walks the numeral, the tight prefix is one chain, every loose prefix fans out to all digits], length: 13pt, {
  cdraw.content((9.5, 7.9), [counting 7s up to 99: the numeral walk], size: 6.5pt)
  let digits = ("9", "9")
  for (i, d) in digits.enumerate() {
    cdraw.rect((3.0 + i * 4.2, 5.9), (4.4 + i * 4.2, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((3.7 + i * 4.2, 6.35), [#d], size: 6.5pt)
  }
  cdraw.content((2.1, 6.35), [N =], size: 6pt)
  // tight chain: 0..9 at pos 0, only the equal digit stays tight
  cdraw.line((3.7, 5.9), (3.7, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.6, 4.55), [tight], size: 6pt)
  cdraw.rect((1.4, 4.15), (6.0, 4.95), fill: luma(205), radius: 0.02)
  cdraw.content((3.7, 4.55), [prefix = N's prefix], size: 6pt)
  cdraw.content((8.6, 4.55), [loose: 10 choices each], size: 6pt)
  cdraw.rect((6.6, 4.15), (12.6, 4.95), fill: none, stroke: luma(100), radius: 0.02)
  cdraw.line((7.9, 5.9), (7.9, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.7, 4.15), (3.7, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.1, 2.9), [state], size: 6pt)
  cdraw.rect((1.4, 2.5), (6.0, 3.3), fill: luma(235), radius: 0.02)
  cdraw.content((3.7, 2.9), [(pos, tight, started, seen7)], size: 6pt)
  cdraw.content((16.0, 6.3), [tight is one chain, never memoized], size: 6pt)
  cdraw.content((16.0, 5.2), [loose states repeat, cache them], size: 6pt)
  cdraw.content((16.0, 4.1), [up to 99: 19 numbers hold a 7], size: 6pt)
  cdraw.content((16.0, 3.0), [up to 77: 15, up to 70: 8], size: 6pt)
  cdraw.content((16.0, 1.9), [python: nondecreasing, 54 at 99], size: 6pt)
  cdraw.content((16.0, 0.8), [the brute scan is the oracle], size: 6pt)
})

== interval dp, palindromes

The last compression makes the interval itself the state.
best of i and j is the longest palindromic subsequence of the slice
from i to j, the base case is single characters at length one, and
an interval is solved from its two immediate shrinkings, ends match
and wrap the inside by two, ends differ and drop one end. Because a
span reads its strictly shorter spans, filling by increasing length
is a valid order and no recursion is needed at all.

The dry run: the fixtures are cbbd at 2 and bbbab at 4 with their
interior cells, asserted by the C\# suite and pinned the same way in
C, Go, Java, JavaScript, Python, and Lua.

+ Span 1 seeds the diagonal: c, b, b, d each score 1.
+ Span 2: cb and bd differ at the ends and keep 1, while bb matches
  and wraps its empty inside, 0 + 2 = 2.
+ Span 3: cbb reads the max of cb and bb, 1 and 2 = 2, and cbd
  reads the max of bb and bd, 2 and 1 = 2.
+ Span 4: the ends c and d differ, cbbd reads the max of cbb and
  bbd, 2 and 2 = 2, the whole-string answer.
+ On bbbab the same order lands 4 at the far corner, with the
  interior cells bab at 3 and ba at 1.
+ The degenerate family closes it: empty 0, single 1, two equal 2,
  two different 1.

#diagram([the cbbd table as a triangle, span bands rising off the diagonal, the bb cell feeding the corner through both shrinkings], length: 13pt, {
  // dp[i][j] over cbbd, hot: the bb pair and the corner
  let m = ((1, 1, 1, 2), (1, 2, 2), (1, 1), (1,))
  let s = ("c", "b", "b", "d")
  for i in range(4) {
    for k in range(4 - i) {
      let j = i + k
      let (x, y) = (1.8 + j * 1.3, 7.2 - i * 1.05)
      let hot = (i, j) == (1, 2) or (i, j) == (0, 3)
      cdraw.rect((x, y), (x + 1.2, y + 0.9), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.6, y + 0.45), [#(m.at(i).at(k))], size: 6pt)
    }
  }
  for j in range(4) {
    cdraw.content((2.4 + j * 1.3, 8.55), [#(s.at(j))], size: 6pt)
  }
  for i in range(4) {
    cdraw.content((1.1, 7.65 - i * 1.05), [#(s.at(i))], size: 6pt)
  }
  // the corner reads its two shrinkings: dp[1][3] below, dp[0][2] left
  cdraw.line((6.3, 7.05), (6.3, 7.25), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.55, 7.65), (5.72, 7.65), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.4, 8.3), [span 1: the diagonal seeds], size: 6pt)
  cdraw.content((7.4, 7.3), [span 2: bb matches, 0 + 2 = 2], size: 6pt)
  cdraw.content((7.4, 6.2), [span 4: max of 2 and 2 = 2], size: 6pt)
  cdraw.content((12.9, 4.9), [bbbab: 4 at the corner], size: 6pt)
  cdraw.content((12.9, 3.9), [interior bab 3, ba 1], size: 6pt)
  cdraw.content((12.9, 2.9), [empty 0, aa 2, ab 1], size: 6pt)
})

The corner lands at 2 over cbbd and 4 over bbbab, and the listings
below fill the table in seven languages.

#listing("dsa/samples-c/src/Ch19/intervaldp.c", first: 19, last: 32, caption: [c, the table by increasing span, interior cells pinned])

#listing("dsa/samples-go/ch19/intervaldp.go", first: 3, last: 29, caption: [go, ends match: wrap by two, else the better shrinking])

#listing("dsa/samples-java/src/Ch19/Intervaldp.java", first: 16, last: 53, caption: [java, the table by increasing span, then the corner-in readback with its property checks])

#listing("dsa/samples/src/Ch19/IntervalDp.cs", first: 12, last: 32, caption: [c\#, the table by increasing span, the zero inside is the second base case])

#listing("dsa/samples-js/src/ch19-intervaldp.mjs", first: 5, last: 18, caption: [javascript, the two-base-case trick, length 2 wraps zero])

#listing("dsa/samples-py/src/Ch19/intervaldp.py", first: 13, last: 45, caption: [python, the length, then the readback that rebuilds abdba])

#listing("dsa/samples-lua/ch19_intervaldp.lua", first: 6, last: 25, caption: [lua, the table plus the brute recursion as oracle])

The anchors hold in every suite that carries the topic: `bbbab`
gives 4, `agbdba` gives 5 with `abdba` rebuilt in Python and Java,
`cbbd` gives 2, and the degenerate family, empty, single, two
equal, two different, pins alongside. C, C\#, and Java read
interior cells out of the table,
the `bab` slice of `bbbab` scoring 3 against its own reading, Java
property-checks its rebuilt witnesses, a palindrome and a
subsequence at the pinned length, and
Lua keeps the unmemoized recursion as the oracle the table must
agree with.

#diagram([interval dp grows by span, ends match and wrap the inside, agbdba rebuilds abdba], length: 13pt, {
  cdraw.content((9.5, 7.9), [agbdba: drop the g, keep abdba], size: 6.5pt)
  let s = ("a", "g", "b", "d", "b", "a")
  for (i, ch) in s.enumerate() {
    cdraw.rect((1.6 + i * 1.5, 6.2), (3.1 + i * 1.5, 7.1), fill: if i in (0, 2, 4, 5) { luma(235) } else { luma(205) }, radius: 0.02)
    cdraw.content((2.35 + i * 1.5, 6.65), [#ch], size: 6.5pt)
  }
  cdraw.content((11.5, 6.65), [shaded: dropped], size: 6pt)
  let spans = ((0, 5, 5.5, [span 6: 5]), (0, 4, 4.4, [span 5 would wrap a..b]), (2, 4, 3.3, [span 3: bdb = 3]), (2, 3, 2.2, [span 2: bd = 1]))
  for sp in spans {
    let (a, b, y, lab) = sp
    cdraw.line((2.35 + a * 1.5, y), (2.35 + b * 1.5, y), stroke: luma(100))
    cdraw.content((8.2, y), lab, size: 6pt)
  }
  cdraw.content((9.5, 1.3), [ends match: inside plus two], size: 6pt)
  cdraw.content((9.5, 0.4), [ends differ: drop one, keep the better], size: 6pt)
  cdraw.content((17.4, 5.9), [fill by increasing span], size: 6pt)
  cdraw.content((17.4, 4.8), [each cell reads shorter cells], size: 6pt)
  cdraw.content((17.4, 3.7), [bbbab: 4, cbbd: 2], size: 6pt)
  cdraw.content((17.4, 2.6), [o(n^2) intervals, o(1) each], size: 6pt)
  cdraw.content((17.4, 1.5), [the table is its own proof], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines over this chapter's
8 featured files per language in the six younger trees, the mask
walk, the digit walk, the interval table, bounded, window, grouped,
hull, and tails. The C\# row is its 3 files, the deepened original
carrying the bounded, window, grouped, hull, and tails builds plus
the digit and interval walks:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [767], [libc only], [tsp masks as 1 \<\< v, digit rows carried by hand, per-k consult meters, cross-multiplied overtaken tests],
  [go], [429], [strconv, math], [FormatInt splits the numeral, memo keys are arrays, meters as one-field structs, min int over 4 unreachable],
  [java], [932], [jdk 27 stdlib], [every table an exact long, the hull's line and query meters ride the nested Hull class, both digit-dp properties in one file, memo keys packed into a long],
  [c\#], [348], [bcl only], [the deepened original plus the digit and interval walks, lis with parents, no tsp build],
  [javascript], [276], [node stdlib], [infinity sentinels in both knapsack tables, a private-field hull, rows kept by swapping],
  [python], [569], [stdlib only], [digit dp counts a different property, weakly increasing digits, none-flagged unreachable cells, a per-k meter dict],
  [lua], [772], [lib.lua harness], [string-keyed memo tables, maxinteger as infinity, nil sentinels, one-based tables emitting zero-based answers],
)

sources: learn.microsoft.com, `List<T>` behind the pieces and the
tails, `Array.Copy` snapshotting the previous item row,
`Array.Resize` growing the hull, accessed 2026-09-12. Sample
behavior verified by `make verify-csharp`, 19 tests in chapter 19 of
the samples suite. The seven-language layer verifies the same way:
8 C programs with 110 embedded checks under `make verify-c`, 8 Ch19
java programs with 133 checks under `run-java-samples`, 28 Go
tests, 33 `node --test` cases, 110 Python checks across 8 files,
and 42 Lua checks under `run.lua`.
