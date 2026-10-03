#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= sqrt decomposition and offline queries

Cut the array into blocks of about sqrt n cells and every range
question becomes a few whole blocks plus two partial edges. That one
idea, ten minutes to build, updates and queries both in O(sqrt n),
and no recursion anywhere, is the baseline every fancier range
structure of #xref-to("dsa", "ranges") has to beat. This chapter
builds it, then spends the savings: mo's algorithm sorts offline
queries so two pointers walk the whole batch in O((n + q) sqrt n),
the minimum queue packages an O(1) window oracle other algorithms
embed, the li chao tree answers online line queries by segment
descent, the disjoint sparse table buys O(1) range folds for sums and
other non-idempotent folds, and rollback dsu plus a segment tree
over time answer dynamic connectivity offline. The last engine is the
substrate of icpc world finals 2025 problem G (book 9, chapter 13).

== sqrt decomposition

An array of n cells in blocks of b = ceil(isqrt(n)). Each block keeps
its sum, a point set updates one cell and one block sum in O(1), and
a range sum walks three pieces: the partial edge cells at both ends,
scanned directly, and the whole blocks between them, read from the
sum array one block at a time. A query spanning fb through lb block
ids touches exactly r/b - l/b + 1 blocks, the meter the suites pin
alongside every sum.

The dry run: the fixture is the pi digits 3, 1, 4, 1, 5, 9, 2, 6, 5,
3, 5, 8, 9, 7, 9, 3 over n = 16, asserted by the C\# suite with the
same sums in the C, Go, and Python suites.

+ The build folds each block once: 3 + 1 + 4 + 1 = 9, 5 + 9 + 2 +
  6 = 22, 5 + 3 + 5 + 8 = 21, 9 + 7 + 9 + 3 = 28, four sums over
  b = 4 and nb = 4.
+ The whole range touches all 4 blocks and reads 80.
+ Query 3 to 8 straddles blocks 0 and 2: the left edge scans cell 3
  alone at 1, the middle reads block 1 whole at 22, the right edge
  scans cell 8 alone at 5, and 1 + 22 + 5 = 28 touching 3.
+ Query 2 to 6 straddles adjacent blocks, so nothing whole sits
  between: the edges pay (4 + 1) + (5 + 9 + 2) = 21 touching 2.
+ The single cell 4 never leaves its block and scans itself, 5
  touching 1.
+ A point set pays twice: Set(4, 100) adds 100 - 5 = 95 onto block
  1's 22 for 117, the whole range climbs to 175, and restoring the
  cell returns 80.

#diagram([the query 3 to 8 as three reads in order, the running total accumulating under each], length: 13pt, {
  let vals = (3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3)
  for i in range(16) {
    let x = 1.4 + i * 1.5
    let hot = i == 3 or i == 8
    let mid = i >= 4 and i <= 7
    cdraw.rect((x, 6.2), (x + 1.5, 7.1), fill: if hot { luma(205) } else if mid { luma(215) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 6.65), [#vals.at(i)], size: 6pt)
    cdraw.content((x + 0.75, 5.8), [#i], size: 6pt)
  }
  let reads = (([1st: cell 3 reads 1], 1), ([2nd: block 1 reads 22], 23), ([3rd: cell 8 reads 5], 28))
  for (r, step) in reads.enumerate() {
    let y = 4.3 - r * 1.1
    let (what, run) = step
    cdraw.rect((3.6, y - 0.32), (11.2, y + 0.32), fill: if r == 1 { luma(215) } else { luma(205) }, radius: 0.02)
    cdraw.content((7.4, y), what, size: 6pt)
    cdraw.content((12.8, y), [running #run], size: 6pt)
  }
  cdraw.line((1.4 + 3 * 1.5 + 0.75, 5.55), (4.6, 4.7), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((1.4 + 5.5 * 1.5, 5.55), (7.4, 5.4), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((1.4 + 8 * 1.5 + 0.75, 5.55), (10.4, 4.7), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((16.4, 2.1), [touched = 8/4 - 3/4 + 1 = 3], size: 6pt)
  cdraw.content((16.4, 1.3), [1 + 22 + 5 = 28], size: 6pt)
  cdraw.content((16.4, 0.5), [O(sqrt n) walk, O(1) set], size: 6pt)
})

The 28 at 3 blocks touched closes the walk, and the listings below
run it in six languages.

#listing("dsa/samples-c/src/Ch31/sqrtblocks.c", first: 45, last: 62, caption: [c, the three-way sum walk and the touched meter, static arrays])
#listing("dsa/samples/src/Ch31/SqrtBlocks.cs", first: 38, last: 58, caption: [c\#, the same walk, partial edges commented, whole blocks from the sum array])
#listing("dsa/samples-go/ch31/sqrtblocks.go", first: 48, last: 73, caption: [go, sum folds edges then blocks, touched beside])
#listing("dsa/samples-js/src/ch31-sqrtblocks.mjs", first: 31, last: 48, caption: [javascript, the block or edge split, floor division for block ids])
#listing("dsa/samples-py/src/Ch31/sqrtblocks.py", first: 32, last: 49, caption: [python, the left edge, whole blocks, right edge])
#listing("dsa/samples-lua/ch31_sqrtblocks.lua", first: 37, last: 52, caption: [lua, 1-based block table behind a 0-based face])

The fixture family runs n = 16, b = 4, nb = 4 over the pi digits 3,
1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3. The whole range sums 80
touching 4 blocks, range 2-6 sums 21 touching 2, the single cell 4
sums 5 touching 1, range 3-8 sums 28 touching 3, range 5-10 sums 30
touching 2, and both endpoint cells read 3 touching 1. Setting cell 4
to 100 lifts the whole range to 175, range 3-8 to 123, and block 1's
sum to 117, and restoring the cell returns 80. The edge family pins
n = 1 down to b = 1 with sum 7 touching 1. Against the fenwick tree
and the segment tree this loses a factor of sqrt n over log n on
every operation, and wins on the minutes count, which is exactly why
it is also the substrate of the next section.

#diagram([16 cells in 4 blocks, the range 3 to 8 shaded as one partial edge, one whole block, and another partial edge, 3 blocks touched], length: 13pt, {
  let vals = (3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3)
  for i in range(16) {
    let x = 1.6 + i * 1.55
    let blk = calc.floor(i / 4)
    let l = if i == 3 or i == 8 { luma(205) } else if i >= 4 and i <= 7 { luma(215) } else { luma(235) }
    cdraw.rect((x, 5.6), (x + 1.55, 6.6), fill: l, radius: 0.02)
    cdraw.content((x + 0.775, 6.1), [#vals.at(i)], size: 7pt)
    cdraw.content((x + 0.775, 5.25), [#i], size: 6pt)
    if calc.rem(i, 4) == 0 {
      let sums = (9, 22, 21, 28)
      cdraw.rect((x - 0.06, 4.7), (x + 4 * 1.55 + 0.06, 5.1), fill: if blk == 1 { luma(215) } else { luma(245) }, radius: 0.02)
      cdraw.content((x + 3.1, 4.9), [block #blk sum #(sums.at(blk))], size: 6pt)
    }
  }
  cdraw.line((1.6 + 3 * 1.55 + 0.775, 6.85), (1.6 + 8 * 1.55 + 0.775, 6.85), stroke: luma(100), mark: (start: "|", end: "|"))
  cdraw.content((1.6 + 5.5 * 1.55, 7.25), [sum(3, 8) = 28], size: 6.5pt)
  cdraw.content((13.6, 3.7), [touched = 8/4 - 3/4 + 1 = 3], size: 6pt)
  cdraw.content((13.6, 2.9), [edge cells 3 and 8 scanned], size: 6pt)
  cdraw.content((13.6, 2.1), [block 1 read as one number], size: 6pt)
  cdraw.content((13.6, 1.3), [O(sqrt n) query, O(1) point set], size: 6pt)
  cdraw.content((13.6, 0.5), [b = ceil(isqrt(n)) = 4 here], size: 6pt)
})

== mo's algorithm

Flip the order of work: when the array is static and all queries are
known, sort the queries and let one interval answer them all. Sort by
the block of the left endpoint, then by the right endpoint, and walk
a single current interval from query to query with four while loops,
expanding and contracting both ends. Each step moves one pointer by
one cell and touches a frequency table: a value's count crossing
zero to one raises the distinct counter, back to zero lowers it, and
the counter after the four loops is that query's answer. Within one
left block the right pointer only moves forward, so it travels O(n)
per block for O(q) blocks total in one direction, and the left
pointer wanders at most b per query: O((n + q) sqrt n) all in, with
the travel meter as the evidence. The sort must be a total order
stable in the query index, c and go break ties on the index
explicitly, javascript leans on its stable sort, so all six languages
process the same order and pin the same meter.

The dry run: the fixture is 1, 2, 1, 3, 2, 1, 4, 1 with b = 3 and
the six queries (0,7), (0,3), (2,5), (1,1), (4,7), (2,2), asserted
by the C\# suite at 20 total pointer moves.

+ The sort by left block then right endpoint lands the order 3, 5,
  1, 2, 0, 4: five queries of block 0 by rising r, then q4 alone in
  block 1.
+ The interval starts empty. q3 (1,1) opens it, the right pointer
  stepping twice and the left once: the interval 1..1 holds the
  single value 2 and answers 1 at 3 moves.
+ q5 (2,2) slides a step each way to 2..2 and answers 1 again, 5
  moves banked.
+ q1 (0,3) widens to 0..3: the 3 arrives and the returning 1 does
  not raise the count, answer 3 at 8 moves.
+ q2 (2,5) and q0 (0,7) walk the right edge out: answers 3 then 4,
  the 4 first counted over 0..7, 16 moves banked.
+ q4 (4,7) rests the right pointer and walks the left 4 cells off
  the front, dropping the 3 for answer 3, closing at the pinned 20.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*run*], [*query*], [*interval*], [*distinct*], [*moves*]),
  [0], [start], [0..-1], [0], [0],
  [1], [q3 (1,1)], [1..1], [1], [3],
  [2], [q5 (2,2)], [2..2], [1], [5],
  [3], [q1 (0,3)], [0..3], [3], [8],
  [4], [q2 (2,5)], [2..5], [3], [12],
  [5], [q0 (0,7)], [0..7], [4], [16],
  [6], [q4 (4,7)], [4..7], [3], [20],
)

The six answers land 4, 3, 3, 1, 3, 1 in input order for the 20
moves, and the listings below run the walk in six languages.

#listing("dsa/samples-c/src/Ch31/mos.c", first: 91, last: 115, caption: [c, the four while loops, travel counted per pointer move])
#listing("dsa/samples/src/Ch31/Mos.cs", first: 43, last: 73, caption: [c\#, the same walk over the sorted order, closure add and remove])
#listing("dsa/samples-go/ch31/mos.go", first: 51, last: 77, caption: [go, the walk with the add and remove closures above])
#listing("dsa/samples-js/src/ch31-mos.mjs", first: 35, last: 68, caption: [javascript, the four loops over the stably sorted indices])
#listing("dsa/samples-py/src/Ch31/mos.py", first: 42, last: 61, caption: [python, the walk, answers written in input order])
#listing("dsa/samples-lua/ch31_mos.lua", first: 41, last: 65, caption: [lua, the walk, 0-based face over 1-based tables])

The fixture array is 1, 2, 1, 3, 2, 1, 4, 1 with n = 8 and b = 3.
The six queries (0,7), (0,3), (2,5), (1,1), (4,7), (2,2) process in
order 3, 5, 1, 2, 0, 4, answer 4, 3, 3, 1, 3, 1 in input order, and
total 20 pointer moves, with a brute set-size scan agreeing on every
answer. The clustered family 4, 4, 7, 4, 7, 9, 9, 2 forces real
distinct counting: its five queries process 1, 2, 0, 4, 3, answer 4,
1, 3, 3, 4, travel 16, brute agreeing again. The edge family repeats
identical queries, (3,3) twice with (0,0) and (7,7), and pins the
processing order 2, 0, 1, 3 with every answer 1. Offline
distinct-count is the canonical vehicle, and no finals problem in the
corpus rides it, so it stays a general technique here.

#diagram([the six queries sorted by left block then right endpoint over the 8-cell array, the two pointers walking from query to query], length: 13pt, {
  let vals = (1, 2, 1, 3, 2, 1, 4, 1)
  for i in range(8) {
    let x = 1.6 + i * 1.7
    cdraw.rect((x, 6.9), (x + 1.7, 7.8), fill: if i < 3 { luma(235) } else { luma(245) }, radius: 0.02)
    cdraw.content((x + 0.85, 7.35), [#vals.at(i)], size: 7pt)
    cdraw.content((x + 0.85, 6.55), [#i], size: 6pt)
  }
  cdraw.content((5.2, 8.4), [array, b = 3: block 0 = cells 0..2, block 1 = cells 3..7], size: 6pt)
  // the processing ladder: (block, r) order 3,5,1,2,0,4
  let steps = ((3, [q3 (1,1)], 1, 1), (5, [q5 (2,2)], 2, 2), (1, [q1 (0,3)], 0, 3), (2, [q2 (2,5)], 2, 5), (0, [q0 (0,7)], 0, 7), (4, [q4 (4,7)], 4, 7))
  for (s, step) in steps.enumerate() {
    let (run, label, l, r) = step
    let y = 5.7 - s * 0.85
    let lx = 1.6 + l * 1.7 + 0.85
    let rx = 1.6 + r * 1.7 + 0.85
    cdraw.line((lx, y), (rx, y), stroke: (paint: luma(120), thickness: 1.2pt), mark: (start: "|", end: "|"))
    cdraw.content((rx + 0.6, y), label, size: 6pt)
    cdraw.content((1.0, y), [#s], size: 6pt)
  }
  cdraw.content((1.0, 6.55), [run], size: 6pt)
  cdraw.content((14.4, 5.7), [order 3, 5, 1, 2, 0, 4], size: 6pt)
  cdraw.content((14.4, 4.8), [answers 4, 3, 3, 1, 3, 1], size: 6pt)
  cdraw.content((14.4, 3.9), [in the original input order], size: 6pt)
  cdraw.content((14.4, 3.0), [total pointer moves 20], size: 6pt)
  cdraw.content((14.4, 2.1), [right pointer: O(n) per block], size: 6pt)
  cdraw.content((14.4, 1.2), [left pointer: b per query], size: 6pt)
})

== the minimum stack and queue

The sliding-window scans of #xref-to("dsa", "ranges") moved a deque
of survivors one step at a time. Here the object itself is the
deliverable: a minimum oracle other algorithms embed, with every
operation O(1) worst case except one amortized step. The min stack
stores (value, running minimum) pairs, push takes min with the pair
below, and the top pair's second slot answers min in one read. The
min queue is two of those stacks back to back: an inbox that receives
enqueues and an outbox that serves dequeues. When the outbox empties,
the dequeue refills it by popping the whole inbox across, which
reverses the order and, for free, recomputes every running minimum
for the reversed sequence. The queue minimum is the min of the two
stack minima, and the transfer is the amortized seam: every element
crosses it at most once per lifetime, so n operations cost O(n)
total.

The dry run: the fixture is the push run 5, 2, 7, 1, 4, asserted by
the C\# suite, the same family in the other five suites.

+ Push 5 opens the stack with the pair 5, 5, value and running
  minimum agreeing, and min reads 5.
+ Push 2 lands as 2, 2, taking the minimum with the 5 below, and
  min drops to 2.
+ Push 7 lands as 7, 2: the value rises, the minimum does not, and
  min stays 2.
+ Push 1 lands as 1, 1 and push 4 as 4, 1: min reads the pinned run
  5, 2, 2, 1, 1.
+ Two pops shed 4, 1 and 1, 1, the top is again 7, 2, and min
  recovers 2.
+ Two more pops shed 7, 2 and 2, 2, and the lone 5, 5 restores min
  5.

#diagram([the stack one column per push, each pair carrying value and running minimum, the top pair stroked, min under each column], length: 13pt, {
  let cols = (
    (((5, 5)),),
    (((5, 5)), ((2, 2))),
    (((5, 5)), ((2, 2)), ((7, 2))),
    (((5, 5)), ((2, 2)), ((7, 2)), ((1, 1))),
    (((5, 5)), ((2, 2)), ((7, 2)), ((1, 1)), ((4, 1))),
  )
  let pushed = (5, 2, 7, 1, 4)
  let mins = (5, 2, 2, 1, 1)
  for (c, col) in cols.enumerate() {
    let x = 1.8 + c * 2.9
    for (j, pr) in col.enumerate() {
      let y = 6.9 - j * 0.75
      let top = j == col.len() - 1
      cdraw.rect((x, y - 0.3), (x + 1.7, y + 0.3), fill: if top { luma(205) } else { luma(235) }, stroke: if top { luma(100) }, radius: 0.02)
      cdraw.content((x + 0.85, y), [#(pr.at(0)), #(pr.at(1))], size: 6pt)
    }
    cdraw.content((x + 0.85, 2.5), [min #(mins.at(c))], size: 6pt)
    cdraw.content((x + 0.85, 1.7), [push #(pushed.at(c))], size: 6pt)
  }
  cdraw.content((1.8, 8.0), [value, running minimum, one pair per push], size: 6.5pt)
  cdraw.content((18.2, 6.9), [after 2 pops min 2], size: 6pt)
  cdraw.content((18.2, 5.9), [after 4 pops min 5], size: 6pt)
  cdraw.content((18.2, 4.9), [the top's second slot is the read], size: 6pt)
  cdraw.content((18.2, 3.9), [one comparison per push], size: 6pt)
})

The recovered pair 2 then 5 is the pinned landing, and the listings
below build stack and queue in six languages.

#listing("dsa/samples-c/src/Ch31/minstack.c", first: 60, last: 83, caption: [c, the dequeue-with-transfer and the two-stack minimum])
#listing("dsa/samples/src/Ch31/MinStack.cs", first: 46, last: 73, caption: [c\#, dequeue refills from the inbox, min combines the two stack minima])
#listing("dsa/samples-go/ch31/minstack.go", first: 63, last: 98, caption: [go, the transfer loop and the min switch over both tops])
#listing("dsa/samples-js/src/ch31-minstack.mjs", first: 44, last: 62, caption: [javascript, shift transfers then pops, min reads either side])
#listing("dsa/samples-py/src/Ch31/minstack.py", first: 41, last: 61, caption: [python, refill counted as transfers, dequeue and min])
#listing("dsa/samples-lua/ch31_minstack.lua", first: 44, last: 67, caption: [lua, the seam refill reversing the inbox, nil-aware min])

The min stack family pushes 5, 2, 7, 1, 4 and reads the running
minima 5, 2, 2, 1, 1, then two pops restore min 2 and four pops
restore 5. The window family re-runs the chapter 21 kin array 1, 3,
-1, -3, 5, 3, 6, 7 with k = 3 and reads -1, -3, -3, -3, 3, 3, the
same array where chapter 21's maxima scan printed 3, 3, 5, 5, 6, 7,
with a brute running-min cross-check and the seam state pinned
afterward: inbox 0, outbox 3. The edge family runs k = 1, where every
step drains the outbox through a transfer and refills it again and
the output is the array itself, and the refusals behave per language:
pop on an empty stack and min of an empty queue refuse by flag,
exception, or error return.

#diagram([the min queue mid-sweep at the transfer seam, the inbox and outbox min columns shaded, the window minimum reading across both], length: 13pt, {
  // a moment in the k = 3 sweep over 1,3,-1,-3,5,3,6,7: outbox holds -3, inbox holds 5,3,6
  cdraw.content((2.9, 7.9), [outbox], size: 6.5pt)
  cdraw.content((6.1, 7.9), [inbox], size: 6.5pt)
  cdraw.content((2.5, 7.3), [val], size: 6pt)
  cdraw.content((3.3, 7.3), [min], size: 6pt)
  cdraw.content((5.7, 7.3), [val], size: 6pt)
  cdraw.content((6.5, 7.3), [min], size: 6pt)
  // outbox: only -3 remains after the last dequeue
  cdraw.rect((2.1, 6.3), (3.7, 7.1), fill: luma(205), radius: 0.02)
  cdraw.content((2.5, 6.7), [-3], size: 7pt)
  cdraw.content((3.3, 6.7), [-3], size: 7pt)
  // inbox: 5,3,6 pushed, run mins 5,3,3
  let iy = 6.7
  for (v, m) in ((5, 5), (3, 3), (6, 3)) {
    cdraw.rect((5.3, iy - 0.4), (6.9, iy + 0.4), fill: if v == 5 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.7, iy), [#v], size: 7pt)
    cdraw.content((6.5, iy), [#m], size: 7pt)
    iy -= 1.0
  }
  // the transfer arrow: inbox drains reversed into outbox
  cdraw.line((5.1, 4.6), (4.0, 4.6), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((4.6, 4.0), [at the seam the inbox], size: 6pt)
  cdraw.content((4.6, 3.3), [pops across reversed], size: 6pt)
  cdraw.content((9.4, 6.9), [window min = min(-3, 3) = -3], size: 6pt)
  cdraw.content((9.4, 6.0), [k = 3 over 1,3,-1,-3,5,3,6,7], size: 6pt)
  cdraw.content((9.4, 5.1), [output -1,-3,-3,-3,3,3], size: 6pt)
  cdraw.content((9.4, 4.2), [every op O(1), transfer amortized], size: 6pt)
  cdraw.content((9.4, 3.3), [each element crosses the seam once], size: 6pt)
})

== the li chao tree

Chapter 19's convex hull trick answered max-over-lines queries after
sorting slopes offline. The li chao tree answers the same upper
envelope question online, arbitrary insertion order, no sorting: a
segment tree over the integer domain where every node keeps one line,
the line better at that segment's midpoint. Insertion descends from
the root. If the node is empty the line lands there. Otherwise
compare the newcomer with the resident at the midpoint: the midpoint
winner stays, and the loser can only win on one side of the midpoint,
the side where it beats the winner at the segment end, so the
recursion follows that half. A line and its host cross at most once,
so each level of descent eliminates one candidate honestly, and both
insert and query run in O(log C) over a domain of C integers, query
taking the max over the root-to-leaf path.

The dry run: the fixture is the domain x in \[0, 8) with the four
lines (1, 0), (0, 3), (-1, 5), (2, -4), asserted by the C\# suite,
the domain and lines shared by all six suites.

+ y = x enters first and the empty root keeps it: the node over
  0..8 holds it.
+ y = 3 arrives: at the root's midpoint 4 the resident reads 4 and
  stays, and the newcomer wins only at the left end, 3 against 0,
  so it descends and lands over 0..4. The two-line envelope reads
  3, 3, 3, 3, 4, 5, 6, 7, pinned.
+ 5 - x arrives: it loses the root's midpoint at 1 against 4, then
  ties the 0..4 midpoint at 3 = 3 where the resident stays, and
  lands over 0..2.
+ 2x - 4 arrives: it ties the root's midpoint at 4 = 4, the
  resident stays, and the newcomer wins only right, landing over
  4..8.
+ Query(0) descends root, 0..4, 0..2 reading 0, 3, 5: the path max
  is 5. Query(4) reads the root's 4 and the 4..8 node's 2 × 4 - 4 =
  4, the tie the midpoint rule created.
+ The envelope closes at 5, 4, 3, 3, 4, 6, 8, 10, the brute
  max-over-lines agreeing at every x.

#diagram([the four insertions landing one node each over 0 to 8, order chips beside the winners, the two query paths walked heavy], length: 13pt, {
  let node = (x, y, w, label, span, chip, hot) => {
    cdraw.rect((x - w, y - 0.3), (x + w, y + 0.3), fill: if hot { luma(205) } else { luma(240) }, stroke: if hot { luma(100) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
    cdraw.content((x, y - 0.62), span, size: 5.5pt)
    if chip != none { cdraw.content((x + w + 0.5, y + 0.55), chip, size: 6pt) }
  }
  node(7.2, 7.6, 1.5, [y = x], [0..8], [1st], true)
  node(4.4, 5.6, 1.2, [y = 3], [0..4], [2nd], true)
  node(10.4, 5.6, 1.5, [y = 2x - 4], [4..8], [4th], true)
  node(3.0, 3.6, 1.3, [y = 5 - x], [0..2], [3rd], true)
  node(5.9, 3.6, 0.9, [--], [2..4], none, false)
  node(9.0, 3.6, 0.9, [--], [4..6], none, false)
  node(12.1, 3.6, 0.9, [--], [6..8], none, false)
  cdraw.line((6.9, 7.3), (4.9, 5.9), stroke: luma(200))
  cdraw.line((7.5, 7.3), (9.9, 5.9), stroke: luma(200))
  cdraw.line((4.1, 5.3), (3.3, 3.9), stroke: luma(200))
  cdraw.line((4.7, 5.3), (5.5, 3.9), stroke: luma(200))
  cdraw.line((10.1, 5.3), (9.3, 3.9), stroke: luma(200))
  cdraw.line((10.7, 5.3), (11.7, 3.9), stroke: luma(200))
  // the query paths, offset off the structural edges
  cdraw.line((5.4, 7.15), (3.5, 6.15), stroke: 1.1pt + luma(40), mark: (end: ">"))
  cdraw.line((3.2, 5.25), (2.6, 4.0), stroke: 1.1pt + luma(40), mark: (end: ">"))
  cdraw.line((8.9, 7.15), (11.4, 6.15), stroke: (paint: luma(40), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.6, 7.0), [query(0)], size: 6pt)
  cdraw.content((9.8, 7.5), [query(4)], size: 6pt)
  cdraw.content((16.6, 5.6), [query(0): 0, 3, 5 -> 5], size: 6pt)
  cdraw.content((16.6, 4.6), [query(4): 4, 4 -> 4], size: 6pt)
  cdraw.content((16.6, 3.6), [the midpoint winner stays], size: 6pt)
  cdraw.content((16.6, 2.6), [a tie keeps the resident], size: 6pt)
  cdraw.content((16.6, 1.6), [query takes the path max], size: 6pt)
  cdraw.content((16.6, 0.6), [envelope 5,4,3,3,4,6,8,10], size: 6pt)
})

The envelope 5, 4, 3, 3, 4, 6, 8, 10 is the pinned landing, and the
listings below insert these four lines in six languages.

#listing("dsa/samples-c/src/Ch31/lichao.c", first: 28, last: 52, caption: [c, the insert descent, midpoint winner kept, loser recursed one side])
#listing("dsa/samples/src/Ch31/LiChao.cs", first: 26, last: 54, caption: [c\#, the same descent with tuple swaps, nullable query sentinel])
#listing("dsa/samples-go/ch31/lichao.go", first: 22, last: 46, caption: [go, insert keeps the midpoint winner and follows the loser])
#listing("dsa/samples-js/src/ch31-lichao.mjs", first: 20, last: 42, caption: [javascript, the descent over a map of segment nodes])
#listing("dsa/samples-py/src/Ch31/lichao.py", first: 25, last: 41, caption: [python, midpoint swap, left-or-right recursion])
#listing("dsa/samples-lua/ch31_lichao.lua", first: 20, last: 38, caption: [lua, optional-argument defaults thread the segment bounds])

The fixture domain is x in [0, 8). The four lines (m, c) = (1, 0),
(0, 3), (-1, 5), (2, -4) answer 5, 4, 3, 3, 4, 6, 8, 10 across the
whole domain, brute max-over-lines agreeing at every integer. With
only the first two lines the answers are 3, 3, 3, 3, 4, 5, 6, 7, and
re-inserting a duplicate line changes nothing, query(0) stays 3. The
empty container's query returns the sentinel, null in c\# and
javascript, a found flag in c, a bool beside the value in go, and the
edges query at x = 0 and x = 7 once populated, -4 and 10 under the
surviving (2, -4) line. The consumer is the dp transition machinery
of #xref-to("dsa", "advdp"), which needs exactly this online
envelope when the slopes arrive unordered.

#diagram([the four fixture lines over 0 to 8 with the upper envelope segmented and the winning value labeled at each integer], length: 13pt, {
  let m = (x, y) => (1.8 + x * 1.55, 1.2 + y * 0.78)
  // axes
  cdraw.line(m(0, 0), m(8.6, 0), stroke: luma(120))
  cdraw.line(m(0, 0), m(0, 10.5), stroke: luma(120))
  for x in range(9) {
    cdraw.line(m(x, 0), m(x, 0.18), stroke: luma(120))
    cdraw.content(m(x, -0.55), [#x], size: 6pt)
  }
  // the four lines clipped to the drawn box
  let seg = (p, q) => { cdraw.line(m(..p), m(..q), stroke: luma(200)) }
  seg((0, 5), (8, 5))       // -x + 5 full
  seg((0, 3), (8, 3))       // y = 3
  seg((0, 0), (8, 8))       // y = x
  seg((2, 0), (8, 12))      // 2x - 4 from x=2
  // envelope winners: 5,4,3,3,4,6,8,10
  let env = (5, 4, 3, 3, 4, 6, 8, 10)
  for x in range(8) {
    cdraw.circle(m(x + 0.5, env.at(x)), radius: 0.09, fill: luma(60))
    cdraw.content(m(x + 0.5, env.at(x) + 1.4), [#env.at(x)], size: 6.5pt)
  }
  cdraw.content(m(-0.55, 10.4), [y], size: 6pt, anchor: "east")
  cdraw.content((14.8, 8.6), [lines: x, 3, -x + 5, 2x - 4], size: 6pt)
  cdraw.content((14.8, 7.7), [envelope: 5,4,3,3,4,6,8,10], size: 6pt)
  cdraw.content((14.8, 6.8), [one line per segment node], size: 6pt)
  cdraw.content((14.8, 5.9), [the midpoint winner stays], size: 6pt)
  cdraw.content((14.8, 5.0), [O(log C) insert and query], size: 6pt)
  cdraw.content((14.8, 4.1), [online, no slope order needed], size: 6pt)
})

== the disjoint sparse table

The sparse table of #xref-to("dsa", "ranges") answers a range query
with two overlapping power-of-two covers, legal only because min and
max are idempotent. A sum query through that machinery counts the
overlap twice. The disjoint sparse table removes the overlap and
keeps the O(1) query for any associative fold. Level i cuts the array
into aligned blocks of 2^i cells and, at each block midpoint, folds
prefixes rightward into the right half and suffixes leftward into
the left half. A query (l, r) with l < r reads the level named by the
highest differing bit of l and r, where l sits in some left half and
r in the matching right half of one block, and answers suffix(l) +
prefix(r), two cells, no overlap.

The dry run: the fixture is the array 3, 1, 4, 1, 5, 9, 2, 6, 5, 3
at n = 10 and 4 levels, asserted by the C\# suite, the same eight
sums in all six suites.

+ Query 2 to 7 picks its level first: 2 and 7 differ first at bit 2,
  so level 2, whose aligned blocks run 4 cells with this block's
  midpoint at 4.
+ The left half folds suffixes away from the midpoint: V of 3 = 1,
  then 4 + 1 = 5, then 1 + 5 = 6, then 3 + 6 = 9.
+ The right half folds prefixes out of it: U of 4 = 5, then 9 + 5 =
  14, then 2 + 14 = 16, then 6 + 16 = 22.
+ The query reads two cells, V of 2 + U of 7 = 5 + 22 = 27, where
  chapter 21's two covers would pay 19 + 22 = 41 for the same span.
+ The single cell 4 never leaves level 0 and reads itself, 5.

#diagram([the two half-scans running away from midpoint 4 in fill order, suffix cells leftward and prefix cells rightward, the two read cells shaded], length: 13pt, {
  let vals = (3, 1, 4, 1, 5, 9, 2, 6, 5, 3)
  let vs = (9, 6, 5, 1)
  let us = (5, 14, 16, 22)
  for i in range(10) {
    let x = 1.6 + i * 1.5
    let dim = i >= 8
    cdraw.rect((x, 7.4), (x + 1.5, 8.3), fill: if dim { luma(245) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 7.85), [#vals.at(i)], size: 6pt)
    cdraw.content((x + 0.75, 7.0), [#i], size: 6pt)
  }
  cdraw.line((7.6, 6.4), (7.6, 8.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((7.6, 8.85), [midpoint 4], size: 6pt)
  for k in range(4) {
    let i = 3 - k
    let x = 1.6 + i * 1.5
    cdraw.rect((x, 5.6 - 0 * 0), (x + 1.5, 6.5), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 6.05), [V #(vs.at(k))], size: 6pt)
    cdraw.content((x + 0.75, 5.25), [#(k + 1)st fold], size: 6pt)
  }
  for k in range(4) {
    let i = 4 + k
    let x = 1.6 + i * 1.5
    cdraw.rect((x, 5.6), (x + 1.5, 6.5), fill: if i == 7 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 6.05), [U #(us.at(k))], size: 6pt)
    cdraw.content((x + 0.75, 5.25), [#(k + 1)st fold], size: 6pt)
  }
  cdraw.content((4.6, 3.9), [V of 2 + U of 7 = 5 + 22 = 27], size: 6.5pt)
  cdraw.content((4.6, 3.0), [level = highest differing bit of 2, 7], size: 6pt)
  cdraw.content((4.6, 2.1), [two cells, no overlap], size: 6pt)
  cdraw.content((17.6, 6.05), [ch21 covers: 41], size: 6pt)
  cdraw.content((17.6, 5.15), [true sum: 27], size: 6pt)
  cdraw.content((17.6, 4.25), [middle 14 counted twice], size: 6pt)
})

The 27 from two cells is the pinned landing, and the listings below
build the levels in six languages.

#listing("dsa/samples-c/src/Ch31/disjointsparse.c", first: 28, last: 61, caption: [c, the level build's two half-scans and the two-cell query])
#listing("dsa/samples/src/Ch31/DisjointSparse.cs", first: 24, last: 60, caption: [c\#, the build loop per level, sum by first differing bit])
#listing("dsa/samples-go/ch31/disjoint_sparse.go", first: 33, last: 66, caption: [go, buildLevel's half-scans, sum via bits.len])
#listing("dsa/samples-js/src/ch31-disjointsparse.mjs", first: 27, last: 57, caption: [javascript, the build and the clz32 level pick])
#listing("dsa/samples-py/src/Ch31/disjointsparse.py", first: 25, last: 50, caption: [python, prefix and suffix folds per midpoint, the query])
#listing("dsa/samples-lua/ch31_disjointsparse.lua", first: 23, last: 50, caption: [lua, the build and a hand-rolled bit length])

The fixture array is 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, n = 10, 4 levels.
The eight pinned sums: (0,9) = 39, (2,5) = 19, (4,4) = 5, (3,8) = 28,
(7,9) = 14, (1,6) = 22, (0,7) = 31, (2,7) = 27, every one matched by
a prefix-sum brute. The overlap demo is the figure's point: query
(2,7) answered chapter 21 style as two 4-wide covers reads 19 + 22 =
41 against the true 27, the middle 14 counted twice. The edges read
l = r straight from the cell, build n = 1 as a single level, and
span the padding boundary at (7,9) where the level's blocks run past
the array end. Build is O(n log n), query O(1), and the table is
read-only, the same permanence trade as the idempotent original.

#diagram([two levels of half-block tables with query 2 to 7 shaded as suffix(2) plus prefix(7), the chapter 21 two-cover overlap crossed out], length: 13pt, {
  let vals = (3, 1, 4, 1, 5, 9, 2, 6, 5, 3)
  let cw = 1.3
  let cx = (i) => 1.4 + i * cw
  // the array row
  for i in range(10) {
    cdraw.rect((cx(i), 7.0), (cx(i) + cw, 7.9), fill: luma(235), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, 7.45), [#vals.at(i)], size: 7pt)
  }
  cdraw.content((0.8, 7.45), [a], size: 6.5pt)
  // level 2 (half = 4): midpoints at 4; suffix folds left from 3..0, prefix folds right 4..9
  let y2 = 5.4
  for i in range(10) {
    let hot = i == 2 or i == 7
    cdraw.rect((cx(i), y2), (cx(i) + cw, y2 + 0.9), fill: if hot { luma(205) } else { luma(240) }, radius: 0.02)
    cdraw.content((cx(i) + cw / 2, y2 + 0.45), [#(if i <= 3 { "V" } else { "U" })#i], size: 6pt)
  }
  cdraw.content((0.4, y2 + 0.45), [lev 2], size: 6pt)
  cdraw.content((cx(4) - 0.1, y2 + 1.25), [midpoint 4], size: 6pt)
  cdraw.line((cx(4), 4.9), (cx(4), 8.1), stroke: (paint: luma(150), dash: "dashed"))
  // the query: V[2] + U[7] = 5 + 22 = 27
  cdraw.content((15.4, y2 + 0.45), [V2 + U7 = 5 + 22 = 27], size: 6pt)
  // the ch21 two covers crossed out: (2,5) and (4,7)
  let yc = 3.4
  cdraw.line((cx(2) + 0.1, yc + 0.6), (cx(6) - 0.1, yc + 0.6), stroke: luma(120), mark: (start: "|", end: "|"))
  cdraw.line((cx(4) + 0.1, yc), (cx(8) - 0.1, yc), stroke: luma(120), mark: (start: "|", end: "|"))
  cdraw.content((cx(5), yc - 0.6), [overlap 4,5 = 14 counted twice], size: 6pt)
  cdraw.line((cx(4) + 0.3, yc + 0.35), (cx(6) - 0.3, yc + 0.25), stroke: (paint: luma(60), thickness: 1.4pt))
  cdraw.content((15.4, yc + 0.3), [ch21 covers: 19 + 22 = 41], size: 6pt)
  cdraw.content((15.4, yc - 0.5), [wrong for sums, 41 vs 27], size: 6pt)
  cdraw.content((15.4, 8.6), [level = highest bit of 2 xor 7 = 2], size: 6pt)
  cdraw.content((15.4, 1.6), [O(n log n) build, O(1) query], size: 6pt)
  cdraw.content((15.4, 0.8), [read only after build], size: 6pt)
})

== rollback dsu

The disjoint set union of #xref-to("dsa", "mstflows") runs two
optimizations, path compression and union by rank or size. Rewinding
a union needs the second and forbids the first: compression flattens
paths opportunistically and forgets the original parent chain, so
there is nothing to undo. Union by size alone keeps find at O(log n),
and every successful union becomes invertible by recording it: push
the (child, parent) pair onto a stack, and rollback(k) unwinds to
stack depth k, restoring the child's parent and the parent's size one
pop at a time, O(1) per step. A union of two already-connected
vertices pushes nothing, and the current stack depth is the snapshot.

The dry run: the fixture is the 6-vertex time-travel family,
asserted by the C\# suite, the walk reading the chapter's 1-based
labels over the suite's 0-based calls.

+ Four unions (1,2), (3,4), (2,4), (5,6) each join two roots: the
  component count steps 5, 4, 3, 2 and the pair stack grows to
  depth 4, one push per union.
+ Union (4,6) joins the last two components: count 1 at depth 5.
+ Rollback to depth 4 unwinds the (4,6) pair, the child's parent
  and the parent's size return, and count reads 2 with 4 and 6
  apart again.
+ The re-union (4,6) succeeds on the rewound state, count 1 at
  depth 5 again.
+ Rollback to depth 3 leaves 3 components, and rollback to 0 empties
  the stack and restores 6.
+ A duplicate union of an already connected pair pushes nothing: the
  stack stays at depth 1.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*op*], [*stack depth*], [*components*]),
  [union (1,2)], [1], [5],
  [union (3,4)], [2], [4],
  [union (2,4)], [3], [3],
  [union (5,6)], [4], [2],
  [union (4,6)], [5], [1],
  [rollback to 4], [4], [2],
  [union (4,6) again], [5], [1],
  [rollback to 3], [3], [3],
  [rollback to 0], [0], [6],
)

The count returns to 6 with the stack empty, and the listings below
union and unwind in six languages.

#listing("dsa/samples-c/src/Ch31/rollbackdsu.c", first: 45, last: 72, caption: [c, union pushes the pair, rollback unwinds it, snapshot is the depth])
#listing("dsa/samples/src/Ch31/RollbackDsu.cs", first: 43, last: 67, caption: [c\#, union and rollback over the pair stack])
#listing("dsa/samples-go/ch31/rollbackdsu.go", first: 42, last: 70, caption: [go, union by size, rollback slicing the stack])
#listing("dsa/samples-js/src/ch31-rollbackdsu.mjs", first: 28, last: 53, caption: [javascript, union, rollback, snapshot])
#listing("dsa/samples-py/src/Ch31/rollbackdsu.py", first: 27, last: 45, caption: [python, the pair stack and the unwind])
#listing("dsa/samples-lua/ch31_rollbackdsu.lua", first: 29, last: 47, caption: [lua, 1-based tables behind 0-based vertices])

The time-travel family runs on 6 vertices: the four unions (1,2),
(3,4), (2,4), (5,6) walk the component count 5, 4, 3, 2 with
snapshot depths 1 through 4, root(1) equals root(4) and differs from
root(6). Union (4,6) reaches count 1, rollback to depth 4 restores
count 2 and separates them again, the re-union succeeds on the
rewound state, rollback to depth 3 gives 3 components, rollback to 0
gives 6, and a duplicate union of a connected pair leaves the stack
at depth 1. The hop-meter family builds the binomial merge shape on 8
vertices, the worst union-by-size permits, and find from vertices 4,
6, and 7 each walks exactly 2 hops against the log2 8 = 3 bound. This
structure serves icpc world finals 2025 problem G (book 9, chapter
13) through the engine below.

#diagram([the union stack with snapshot ticks and one unwind restoring two components, beside the binomial 8-vertex shape with a 2-hop find path], length: 13pt, {
  // left: the stack after unions (1,2),(3,4),(2,4),(5,6) then (4,6), unwinding to tick 4
  let ops = (([(1,2)], 1), ([(3,4)], 2), ([(2,4)], 3), ([(5,6)], 4), ([(4,6)], 5))
  for (i, item) in ops.enumerate() {
    let y = 7.4 - i * 0.9
    cdraw.rect((2.2, y - 0.32), (5.4, y + 0.32), fill: if i == 4 { luma(215) } else { luma(240) }, stroke: luma(150), radius: 0.02)
    cdraw.content((3.8, y), item.at(0), size: 7pt)
    cdraw.content((5.9, y), [#(item.at(1))], size: 6pt)
    cdraw.line((5.7, y - 0.4), (5.7, y + 0.4), stroke: luma(120))
  }
  cdraw.content((5.9, 8.2), [depth], size: 6pt)
  cdraw.content((3.8, 8.2), [the union stack], size: 6.5pt)
  cdraw.line((6.6, 7.4 - 4 * 0.9), (7.4, 7.4 - 4 * 0.9), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((7.0, 7.4 - 4 * 0.9 - 0.55), [rollback(4)], size: 6pt)
  cdraw.content((1.0, 2.2), [unwind (4,6): count 1 -> 2], size: 6pt)
  cdraw.content((1.0, 1.4), [sizes and parents restored], size: 6pt)
  // right: binomial shape on 8 vertices: 4 over 3 over pairs, probe find(4) walks 2
  let v = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.26, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 6.5pt)
  }
  let e = (p, q) => cdraw.line(p, q, stroke: luma(190))
  e((12.0, 7.6), (11.0, 6.4)); e((12.0, 7.6), (13.0, 6.4))
  e((11.0, 6.4), (10.4, 5.2)); e((13.0, 6.4), (13.6, 5.2))
  e((10.4, 5.2), (10.0, 4.0)); e((13.6, 5.2), (14.0, 4.0))
  e((10.0, 4.0), (9.8, 2.8))
  v(12.0, 7.6, [4]); v(11.0, 6.4, [3]); v(13.0, 6.4, [6]); v(10.4, 5.2, [2])
  v(13.6, 5.2, [7]); v(10.0, 4.0, [1]); v(14.0, 4.0, [8]); v(9.8, 2.8, [5])
  // the 2-hop path 5 -> 1 -> 2
  cdraw.line((9.8, 2.8), (10.0, 4.0), stroke: (paint: luma(60), thickness: 1.3pt), mark: (end: ">"))
  cdraw.line((10.0, 4.0), (10.4, 5.2), stroke: (paint: luma(60), thickness: 1.3pt), mark: (end: ">"))
  cdraw.content((12.6, 2.6), [find(5): 2 hops to root 2], size: 6pt)
  cdraw.content((12.6, 1.8), [binomial tree, worst for size only], size: 6pt)
  cdraw.content((12.6, 1.0), [log2 8 = 3 bound, measured 2], size: 6pt)
})

== offline dynamic connectivity

Edge insertions and deletions defeat plain dsu, but when the whole
timeline is known the problem turns static. Give every edge its
lifetime as a half-open interval of times, insert it into the
O(log T) segment tree nodes covering that interval, then run one dfs
over the tree carrying a rollback dsu: on entering a node, union its
edges, at a leaf answer the queries stamped with that time, and on
leaving, unwind to the snapshot taken on entry. Every edge is unioned
along its cover and rolled back on the way out, so the dsu at leaf t
holds exactly the edges alive at t, and the total cost is O(E log T
log V) with E the sum of interval covers.

The dry run: the fixture is 5 vertices over T = 8 with edges (1,2)
alive \[0,6), (2,3) on \[1,4), (3,4) on \[2,8), (1,4) on \[5,7),
and (4,5) on \[7,8), asserted by the C\# suite with a brute per-time
dsu agreeing cell by cell.

+ The dfs sweeps the leaves t = 0 through 7, unioning on entry,
  answering at the leaf, unwinding on exit.
+ At t = 0 only (1,2) is alive: {1,2}, 3, 4, 5 read 4 components,
  and 1 and 3 sit apart.
+ t = 1 adds (2,3): {1,2,3} at 3 components, and conn(1,3) turns
  true.
+ t = 2 adds (3,4) for 2 components, and t = 3 holds the same 2.
+ t = 4 drops (2,3): {1,2} and {3,4} sit apart at 3 components,
  conn(1,3) false again.
+ t = 5 adds (1,4) for {1,2,3,4} at 2, true, and t = 6 drops (1,2)
  leaving {2} beside {1,3,4} at 3, still true.
+ t = 7 swaps (1,4) for (4,5): {3,4,5} leaves 1 alone at 3
  components, false.

#diagram([the five lifetimes as an on and off strip across the eight times, the two answer rows read at the leaves], length: 13pt, {
  let alive = (
    ([e1 1-2], (true, true, true, true, true, true, false, false)),
    ([e2 2-3], (false, true, true, true, false, false, false, false)),
    ([e3 3-4], (false, false, true, true, true, true, true, true)),
    ([e4 1-4], (false, false, false, false, false, true, true, false)),
    ([e5 4-5], (false, false, false, false, false, false, false, true)),
  )
  for (r, row) in alive.enumerate() {
    let (name, cells) = row
    let y = 7.0 - r * 0.85
    cdraw.content((3.4, y), name, size: 6pt, anchor: "east")
    for t in range(8) {
      let x = 4.2 + t * 1.9
      cdraw.rect((x, y - 0.3), (x + 1.9, y + 0.3), fill: if cells.at(t) { luma(205) } else { luma(240) }, radius: 0.02)
    }
  }
  let conn = (false, true, true, true, false, true, true, false)
  let comps = (4, 3, 2, 2, 3, 2, 3, 3)
  for t in range(8) {
    let x = 4.2 + t * 1.9
    cdraw.content((x + 0.95, 7.55), [#t], size: 6pt)
    cdraw.content((x + 0.95, 2.2), [#(if conn.at(t) { [T] } else { [F] })], size: 6.5pt)
    cdraw.content((x + 0.95, 1.3), [#(comps.at(t))], size: 6.5pt)
  }
  cdraw.content((3.4, 2.2), [conn(1,3)], size: 6pt, anchor: "east")
  cdraw.content((3.4, 1.3), [components], size: 6pt, anchor: "east")
  cdraw.content((20.6, 7.0), [9 unions across the dfs], size: 6pt)
  cdraw.content((20.6, 6.1), [answer at the leaf, unwind after], size: 6pt)
  cdraw.content((20.6, 5.2), [shaded: edge alive], size: 6pt)
})

The sweep answers all eight times for the pinned 9 unions, and the
listings below run the dfs in six languages.

#listing("dsa/samples-c/src/Ch31/offlinedynconn.c", first: 103, last: 123, caption: [c, the dfs: union on entry, answer at the leaf, unwind on exit])
#listing("dsa/samples/src/Ch31/OfflineDynConn.cs", first: 33, last: 54, caption: [c\#, the same dfs as a local function over the node lists])
#listing("dsa/samples-go/ch31/offlinedynconn.go", first: 50, last: 72, caption: [go, the dfs closure, components as vertices minus unions])
#listing("dsa/samples-js/src/ch31-offlinedynconn.mjs", first: 26, last: 47, caption: [javascript, the dfs over a node-to-edges map])
#listing("dsa/samples-py/src/Ch31/offlinedynconn.py", first: 66, last: 84, caption: [python, the dfs with the snapshot mark and rollback])
#listing("dsa/samples-lua/ch31_offlinedynconn.lua", first: 69, last: 88, caption: [lua, the dfs, answers appended leaf by leaf])

The fixture runs 5 vertices over T = 8: edges (1,2) alive \[0,6),
(2,3) on \[1,4), (3,4) on \[2,8), (1,4) on \[5,7), and (4,5) on \[7,8).
Connectivity of 1 and 3 reads F, T, T, T, F, T, T, F across the eight
times, the component counts read 4, 3, 2, 2, 3, 2, 3, 3, the dfs
performs 9 unions total, and a brute per-time dsu agrees on every
cell. The negative family holds: 1 and 5 are never connected, vertex
5 joins only at t = 7 when 1 is already isolated. The edges cover the
whole horizon, an empty interval, and a query at t = 0 before any
edge. This engine is icpc world finals 2025 problem G (book 9,
chapter 13), lava moat: the level sweep runs exactly this machine
over edge lifetimes with per-component length and border flags, at
O(n log^2 n).

#diagram([the segment tree over times 0 to 7 with the five edge lifetimes as shaded node covers, two query rows answered at the leaves], length: 13pt, {
  // tree over [0,8): root, 2 mids, 4 quarters, 8 leaves
  let pos = (node) => {
    let spans = ((0, 8), (0, 4), (4, 8), (0, 2), (2, 4), (4, 6), (6, 8),
      (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8))
    let (lo, hi) = spans.at(node - 1)
    let d = if node == 1 { 0 } else if node <= 3 { 1 } else if node <= 7 { 2 } else { 3 }
    ((1.6 + (lo + hi) / 2 * 1.75), 8.6 - d * 1.25)
  }
  // edges: e1 1-2 [0,6), e2 2-3 [1,4), e3 3-4 [2,8), e4 1-4 [5,7), e5 4-5 [7,8)
  // canonical covers: e1 at [0,4) and [4,6), e2 at [1,2) and [2,4), e3 at [2,4) and [4,8), e4 at [5,6) and [6,7), e5 at [7,8)
  let cover = (
    (1, ()), (2, ("e1",)), (3, ("e3",)),
    (4, ()), (5, ("e2", "e3")), (6, ("e1",)), (7, ()),
    (8, ()), (9, ("e2",)), (10, ()), (11, ()),
    (12, ()), (13, ("e4",)), (14, ("e4",)), (15, ("e5",)),
  )
  let kids = ((1, 2, 3), (2, 4, 5), (3, 6, 7), (4, 8, 9), (5, 10, 11), (6, 12, 13), (7, 14, 15))
  for (p, l, r) in kids {
    cdraw.line(pos(p), pos(l), stroke: luma(210))
    cdraw.line(pos(p), pos(r), stroke: luma(210))
  }
  for (node, es) in cover {
    let (x, y) = pos(node)
    let d = if node == 1 { 0 } else if node <= 3 { 1 } else if node <= 7 { 2 } else { 3 }
    let w = if d <= 1 { 1.3 } else if d == 2 { 1.4 } else { 0.8 }
    cdraw.rect((x - w, y - 0.3), (x + w, y + 0.3), fill: if es.len() > 0 { luma(210) } else { luma(240) }, radius: 0.02)
    cdraw.content((x, y), if es.len() > 0 { es.join(",") } else { [--] }, size: 5.5pt)
  }
  // leaves time labels
  for t in range(8) {
    cdraw.content((1.6 + (t + 0.5) * 1.75, 4.35), [#t], size: 6pt)
  }
  // the two query rows at the leaves: conn(1,3) and components
  let conn = (false, true, true, true, false, true, true, false)
  let comps = (4, 3, 2, 2, 3, 2, 3, 3)
  for t in range(8) {
    let x = 1.6 + (t + 0.5) * 1.75
    cdraw.content((x, 3.5), [#conn.at(t)], size: 6.5pt)
    cdraw.content((x, 2.7), [#comps.at(t)], size: 6.5pt)
  }
  cdraw.content((0.4, 3.5), [conn(1,3)], size: 6pt)
  cdraw.content((0.4, 2.7), [comps], size: 6pt)
  cdraw.content((17.2, 8.6), [edges: e1 1-2 on \[0,6)], size: 6pt)
  cdraw.content((17.2, 7.8), [e2 2-3 on \[1,4), e3 3-4 on \[2,8)], size: 6pt)
  cdraw.content((17.2, 7.0), [e4 1-4 on \[5,7), e5 4-5 on \[7,8)], size: 6pt)
  cdraw.content((17.2, 6.2), [shaded nodes hold whole covers], size: 6pt)
  cdraw.content((17.2, 5.4), [9 unions across the dfs], size: 6pt)
  cdraw.content((17.2, 1.8), [O(E log T log V)], size: 6pt)
})

== across the six languages

Featured build size counted as non-blank, non-comment lines of the
chapter's seven sample files per language, embedded test scripts
included:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [792], [static arrays, qsort for mo], [block ids by integer division, the empty-pop and empty-min sentinel flags],
  [c\#], [396], [arrays, tuples, dictionaries], [nullable long for the li chao sentinel, bitlength by hand and by clz],
  [go], [419], [slices, maps, no imports beyond fmt and bits], [components computed as vertices minus unions, snake_case file for the sparse table],
  [javascript], [324], [map-keyed segment stores], [stable sort carries the mo tie order, private methods throughout],
  [python], [554], [lists, dicts, check harness], [system exit on failure, ok-N print per file],
  [lua], [632], [tables, 1-based inside], [0-based public faces per the ch21 precedent, hand-rolled bit length],
)

sources: cp-algorithms, "Sqrt Decomposition",
cp-algorithms.com/data_structures/sqrt_decomposition.html, whose mo's
algorithm section is the direct source for 31.2, "Minimum stack /
Minimum queue",
cp-algorithms.com/data_structures/stack_queue_modification.html,
"Convex hull trick and Li Chao tree",
cp-algorithms.com/geometry/convex_hull_trick.html, the second half of
that article, "Sparse Table",
cp-algorithms.com/data_structures/sparse-table.html, the base
structure of 31.5 whose disjoint variant is our own extension, and
"Disjoint Set Union",
cp-algorithms.com/data_structures/disjoint_set_union.html, the
substrate of 31.6 whose rollback variant is likewise ours, all
accessed 2026-09-20, cc by-sa 4.0, our own words and code throughout.
The offline connectivity engine of 31.7 has no dedicated article
there and cites icpc world finals 2025 problem G (book 9, chapter 13)
as its application source. Sample behavior verified by the six suite
gates scoped to chapter 31: c 7 files and 136 checks, c\# 23 facts,
go 21 test functions, javascript 21 tests and 68 asserts, python 7
files and 122 asserts, lua 21 checks, zero skipped.
