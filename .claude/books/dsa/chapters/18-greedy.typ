#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= greedy and backtracking

Greedy algorithms commit to the locally best choice and never look
back. Sometimes that is provably optimal, and the proof shape is the
interesting part. When no such proof exists, backtracking searches
everything with pruning, the honest fallback. This chapter builds
both with their meters on, six languages deep on the greedy side.

== activity selection and rooms

The exchange argument: any optimal schedule can be rearranged to
start with the earliest-finishing activity, so taking it loses
nothing. Sort by finish, take what fits.

The dry run: the fixtures are the eleven-interval CLRS set and the
three rooms cases, asserted by the C\# suite, while C, Go,
JavaScript, and Lua pin the same CLRS answer and Python runs its own
six intervals.

+ Sorted by finish the queue reads 1-4, 3-5, 0-6, 5-7, 3-9, 5-9,
  6-10, 8-11, 8-12, 2-14, 12-16, and 1-4 is taken at once, the
  last finish moving to 4.
+ 3-5 starts at 3 and 0-6 at 0, both inside 4, both skipped.
+ 5-7 starts at 5, past 4, taken, the frontier at 7, and 3-9, 5-9,
  6-10 all start below 7 and die.
+ 8-11 starts at 8, taken, the frontier at 11, and 8-12 and 2-14
  die the same way.
+ 12-16 starts at 12 and the schedule closes at four picks, 1-4,
  5-7, 8-11, 12-16.
+ Rooms on 0-30, 5-10, 15-20: nothing frees before 30, the second
  meeting piles on, and the third reuses the room freed at 10, a
  peak of 2.
+ Back-to-back 0-1, 1-2, 2-3 shares one room, and the pile 0-10,
  1-9, 2-8 frees nothing, 3 rooms.

#diagram([the walk in finish-sorted order, taken intervals shaded, the frontier advancing pick by pick, the rooms trio beside it], length: 13pt, {
  // 11 intervals in finish order across the top, accepted shaded
  let ivs = (([1-4], true), ([3-5], false), ([0-6], false), ([5-7], true), ([3-9], false), ([5-9], false), ([6-10], false), ([8-11], true), ([8-12], false), ([2-14], false), ([12-16], true))
  for (i, iv) in ivs.enumerate() {
    let (lab, hot) = iv
    let x = 1.2 + i * 2.1
    cdraw.rect((x, 7.0), (x + 1.75, 7.85), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.875, 7.42), lab, size: 6pt)
    cdraw.content((x + 0.875, 6.5), if hot { [take] } else { [skip] }, size: 6pt)
  }
  // the frontier value after each take
  for (col, f) in ((0, 4), (3, 7), (7, 11), (10, 16)) {
    let x = 2.075 + col * 2.1
    cdraw.line((x, 6.1), (x, 5.55), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x, 5.1), [#f], size: 6pt)
  }
  cdraw.content((12.8, 5.1), [last finish after each take], size: 6pt)
  // rooms: 0-30 holds room 1, the room freed at 10 is reused at 15
  let tx = t => 1.2 + t * 0.33
  cdraw.content((1.2, 3.95), [rooms], size: 6.5pt)
  cdraw.rect((tx(0), 3.0), (tx(30), 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((tx(15), 3.3), [0-30], size: 6pt)
  cdraw.rect((tx(5), 2.05), (tx(10), 2.65), fill: luma(205), radius: 0.02)
  cdraw.content((tx(7.5), 2.35), [5-10], size: 6pt)
  cdraw.rect((tx(15), 2.05), (tx(20), 2.65), fill: luma(205), radius: 0.02)
  cdraw.content((tx(17.5), 2.35), [15-20], size: 6pt)
  cdraw.content((12.8, 3.3), [room 1 holds 0-30], size: 6pt)
  cdraw.content((12.8, 2.35), [room 2 freed at 10, reused at 15], size: 6pt)
  cdraw.content((12.8, 1.4), [peak 2, back to back 1, pile 3], size: 6pt)
  cdraw.content((12.8, 0.5), [four picks, the clrs answer], size: 6pt)
})

The four picks and the three-room pile are the pinned landings, and
the listings below run the scan in six languages, rooms in the C\#
one.

#listing("dsa/samples-c/src/Ch18/intervals.c", first: 21, last: 36, caption: [c, qsort by finish, keep what starts after the last pick])

#listing("dsa/samples/src/Ch18/Greedy.cs", first: 6, last: 40, caption: [c\#, activity selection, then interval partitioning through a room heap])

#listing("dsa/samples-go/ch18/intervals.go", first: 14, last: 30, caption: [go, half-open intervals, sort a clone, keep the compatible])

#listing("dsa/samples-js/src/ch18-intervals.mjs", first: 4, last: 15, caption: [javascript, stable sort by finish, minus infinity start])

#listing("dsa/samples-py/src/Ch18/intervals.py", first: 15, last: 23, caption: [python, sort by end, plus an exhaustive brute cross-check])

#listing("dsa/samples-lua/ch18_intervals.lua", first: 7, last: 22, caption: [lua, table.sort by finish then start, the clrs fixture])

The rooms problem is greedy by start time with chapter 8's heap
holding room release times, and the maximum simultaneous occupancy
is the answer. The tests use the classic eleven-interval CLRS set,
which selects exactly four, and the boundary cases: back-to-back
meetings share one room, three overlapping meetings need three.

The eleven-interval CLRS fixture and its answer, four picks at 1-4,
5-7, 8-11, 12-16, pin in C, C\#, Go, JavaScript, and Lua. Python
runs its own six-interval set with the pinned choice of three and
then does what only Python does cheaply, an exhaustive
`itertools.combinations` sweep proving no larger compatible subset
exists. Lua checks maximality too, by hand: every discarded interval
must overlap an accepted one. Back-to-back compatibility, a start
equal to the last finish, is asserted everywhere, and the all-stack
fixture pins the earliest finisher surviving alone.

#diagram([intervals on a time axis, earliest finish wins the schedule, the heap of end times counts the rooms], length: 13pt, {
  // A 0-3, B 2-5, C 4-7, D 1-8, E 6-9, F 8-11: selection A C F, rooms 3
  let tx = t => 2.6 + t
  cdraw.content((8.1, 8.05), [pick by earliest finish], size: 6.5pt)
  let bar = (a, b, y, hot, name) => {
    cdraw.rect((tx(a), y - 0.16), (tx(b), y + 0.16), fill: if hot { luma(205) } else { none }, stroke: luma(100), radius: 0.02)
    cdraw.content((tx(a) + 0.35, y), name, size: 6pt)
  }
  bar(0, 3, 7.35, true, [A])
  bar(2, 5, 6.95, false, [B])
  bar(4, 7, 7.35, true, [C])
  bar(1, 8, 6.55, false, [D])
  bar(6, 9, 6.95, false, [E])
  bar(8, 11, 7.35, true, [F])
  cdraw.line((5.1, 7.35), (5.9, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.1, 7.35), (9.9, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.6, 6.1), (13.6, 6.1), stroke: luma(100))
  for t in range(12) {
    cdraw.line((tx(t), 6.1), (tx(t), 5.95), stroke: luma(100))
    cdraw.content((tx(t), 5.7), [#t], size: 6pt)
  }

  cdraw.content((1.15, 4.75), [room 1], size: 6pt)
  cdraw.content((1.15, 3.9), [room 2], size: 6pt)
  cdraw.content((1.15, 3.05), [room 3], size: 6pt)
  bar(0, 3, 4.75, true, [A])
  bar(4, 7, 4.75, true, [C])
  bar(8, 11, 4.75, true, [F])
  bar(1, 8, 3.9, false, [D])
  bar(2, 5, 3.05, false, [B])
  bar(6, 9, 3.05, false, [E])

  cdraw.content((18.0, 7.35), [earliest finish first], size: 6pt)
  cdraw.content((18.7, 6.35), [the exchange loses nothing], size: 6pt)
  cdraw.content((18.7, 4.75), [rooms: heap of end times], size: 6pt)
  cdraw.content((18.3, 3.65), [pop every past end time], size: 6pt)
  cdraw.content((18.8, 2.55), [back to back shares a room], size: 6pt)
  cdraw.content((18.7, 1.45), [the peak is the answer: 3], size: 6pt)
  cdraw.content((18.7, 0.35), [clrs 11: four picks, three rooms], size: 6pt)
})

== huffman

Huffman coding is greedy with a proof: repeatedly merge the two
lightest symbols, and the resulting prefix-free code minimizes
weighted code length. The heap from chapter 8 does the selecting.

The dry run: the fixture is the CLRS weights 45, 13, 12, 16, 9, 5,
pinned by the C, Go, JavaScript, and Lua suites at cost 224, while
C\# asserts the round trip and the one-bit lone symbol and Python
runs 5, 2, 1, 1 at cost 15.

+ Round 1 marries the two lightest, 5 and 9: 5 + 9 = 14.
+ Round 2: the next pair is 12 and 13: 12 + 13 = 25.
+ Round 3: the 14 meets 16: 14 + 16 = 30.
+ Round 4: 25 + 30 = 55.
+ Round 5 closes the tree: 45 + 55 = 100.
+ The merge weights sum to the cost, 14 + 25 + 30 + 55 + 100 = 224,
  the same 224 read again as weight times depth with lengths a 1,
  b, c, d 3, e, f 4.

#diagram([the merge loop as one row per round, the two lightest shaded on each row, the fresh merged weight boxed], length: 13pt, {
  // the sorted forest at each round, pair shaded, the new node stroked
  let rows = (
    (((5, 9, 12, 13, 16, 45)), (0, 1), -1, [5 + 9 = 14]),
    (((12, 13, 14, 16, 45)), (0, 1), 2, [12 + 13 = 25]),
    (((14, 16, 25, 45)), (0, 1), 2, [14 + 16 = 30]),
    (((25, 30, 45)), (0, 1), 2, [25 + 30 = 55]),
    (((45, 55)), (0, 1), 1, [45 + 55 = 100]),
    (((100,)), (), 0, [one tree]),
  )
  for (r, row) in rows.enumerate() {
    let (vals, pair, boxed, lab) = row
    let y = 7.6 - r * 1.1
    for (i, v) in vals.enumerate() {
      cdraw.rect((1.6 + i * 1.35, y - 0.32), (2.85 + i * 1.35, y + 0.32), fill: if i in pair { luma(205) } else { luma(235) }, stroke: if i == boxed { luma(100) }, radius: 0.02)
      cdraw.content((2.225 + i * 1.35, y), [#v], size: 6pt)
    }
    cdraw.content((10.8, y), lab, size: 6pt)
  }
  cdraw.content((10.8, 0.7), [14 + 25 + 30 + 55 + 100 = 224], size: 6pt)
  cdraw.content((10.8, -0.2), [lengths a 1, b c d 3, e f 4], size: 6pt)
  cdraw.content((10.8, -1.1), [c\# and python: 5 2 1 1, cost 15], size: 6pt)
})

The 224 lands as both the merge sum and the weighted length, and
the listings below build this tree in six languages.

#listing("dsa/samples-c/src/Ch18/huffman.c", first: 29, last: 80, caption: [c, marry the two lightest, depths by parent walks, the identity])

#listing("dsa/samples/src/Ch18/Greedy.cs", first: 42, last: 113, caption: [c\#, the huffman machine, heap merging, code walking, encode])

#listing("dsa/samples/src/Ch18/Greedy.cs", first: 114, last: 168, caption: [c\#, decode with the reverse table, weighted cost, the fractional knapsack contrast])

#listing("dsa/samples-go/ch18/huffman.go", first: 11, last: 60, caption: [go, two min scans marry the lightest, lengths by depth walk])

#listing("dsa/samples-js/src/ch18-huffman.mjs", first: 16, last: 56, caption: [javascript, a hand-built heap keyed by weight then insertion order])

#listing("dsa/samples-py/src/Ch18/huffman.py", first: 14, last: 28, caption: [python, sort as the queue, member lists lift every merged symbol])

#listing("dsa/samples-lua/ch18_huffman.lua", first: 7, last: 31, caption: [lua, sort by weight then order, the merge sum accumulates])

The tests pin the properties rather than one lucky code: encode and
decode round trip, no code prefixes another, frequent symbols get
short codes, weighted cost beats fixed-length coding on skewed
input, and the degenerate single-symbol alphabet still gets its one
bit. The fractional knapsack beside it is the greedy that works
precisely because splitting is allowed, and its 240 beats the
zero-one table's 220 on the same items.

The CLRS six-symbol fixture, weights 45, 13, 12, 16, 9, 5, pins the
same tree in C, Go, JavaScript, and Lua: code lengths 1, 3, 3, 3,
4, 4 and total cost 224, which is also the sum of the merge weights,
14 plus 25 plus 30 plus 55 plus 100, an identity every one of those
suites asserts. Python and C\# run the four-symbol 5, 2, 1, 1
fixture with lengths 1, 2, 3, 3 and cost 15, and Python adds the
Kraft equality, the code lengths summing to exactly 1 as negative
powers of two. The selector is the per-language story: C scans for
the two smallest, Go does two min scans, Lua sorts the whole forest
each round with an insertion-order tie-break, JavaScript hand-builds
a binary heap with the same tie-break, and Python lets `sort` stand
in for the priority queue because the fixture is tiny.

#diagram([huffman, the two lightest merge each round, codes lengthen with depth, prefix freedom holds by construction], length: 13pt, {
  // a5 b2 c1 d1: merge c+d, then b+that, then a+that; cost 15 vs fixed 18
  cdraw.content((5.5, 8.0), [the merge loop, lightest first], size: 6.5pt)
  let cell = (x, y, s, hot) => {
    cdraw.rect((x, y - 0.25), (x + 1.5, y + 0.25), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, y), s, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cell(1.2, 7.2, [a: 5], false)
  cell(3.0, 7.2, [b: 2], false)
  cell(4.8, 7.2, [c: 1], false)
  cell(6.6, 7.2, [d: 1], false)
  e((5.55, 6.95), (5.3, 6.4))
  e((7.35, 6.95), (6.0, 6.4))
  cell(1.2, 6.1, [a: 5], false)
  cell(3.0, 6.1, [b: 2], false)
  cell(4.8, 6.1, [n: 2], true)
  e((3.75, 5.85), (5.1, 5.35))
  e((5.55, 5.85), (5.75, 5.35))
  cell(1.2, 5.0, [a: 5], false)
  cell(4.8, 5.0, [n: 4], true)
  e((1.95, 4.75), (3.35, 4.25))
  e((5.55, 4.75), (4.05, 4.25))
  cell(3.0, 3.9, [r: 9], false)
  cdraw.content((5.5, 2.8), [the two lightest merge each round], size: 6pt)
  cdraw.content((5.5, 1.7), [the heap picks the pair], size: 6pt)
  cdraw.content((5.5, 0.6), [total weight rides up], size: 6pt)

  cdraw.content((18.0, 8.0), [codes grow with depth], size: 6.5pt)
  let leaf = (pos, s) => {
    cdraw.rect((pos.at(0) - 0.675, pos.at(1) - 0.25), (pos.at(0) + 0.675, pos.at(1) + 0.25), fill: luma(235), radius: 0.02)
    cdraw.content(pos, s, size: 6pt)
  }
  let t = (a, b) => cdraw.line(a, b, stroke: luma(100))
  t((16.0, 6.85), (14.0, 6.25))
  t((16.0, 6.85), (18.5, 6.25))
  t((14.0, 5.75), (13.0, 5.15))
  t((14.0, 5.75), (15.5, 5.15))
  t((13.0, 4.65), (12.2, 4.05))
  t((13.0, 4.65), (14.2, 4.05))
  cdraw.content((14.35, 6.85), [0], size: 6pt)
  cdraw.content((17.5, 6.85), [1], size: 6pt)
  cdraw.content((13.0, 5.5), [0], size: 6pt)
  cdraw.content((15.35, 5.55), [1], size: 6pt)
  cdraw.content((12.1, 4.4), [0], size: 6pt)
  cdraw.content((14.15, 4.45), [1], size: 6pt)
  leaf((16.0, 7.1), [9])
  leaf((14.0, 6.0), [n 4])
  leaf((18.5, 6.0), [a 5])
  leaf((13.0, 4.9), [n 2])
  leaf((15.5, 4.9), [b 2])
  leaf((12.2, 3.8), [c 1])
  leaf((14.2, 3.8), [d 1])
  cdraw.content((18.5, 2.8), [a: 1, b: 01, c: 000, d: 001], size: 6pt)
  cdraw.content((18.5, 1.7), [5 + 4 + 3 + 3 = 15 bits], size: 6pt)
  cdraw.content((18.5, 0.6), [fixed length would cost 18], size: 6pt)
  cdraw.content((18.5, -0.5), [prefix free by construction], size: 6pt)
  cdraw.content((6.5, -0.6), [clrs 45 13 12 16 9 5: lengths 1 3 3 3 4 4, cost 224], size: 6pt)
})

== the jump game

Reachability first: scan left to right keeping the farthest index
within reach, and the moment the loop index passes that frontier
the end is unreachable, no search needed. The minimum jump count is
the same scan with level boundaries, the current jump covers a
window, the next jump ends wherever the farthest reach inside the
window says, and the counter ticks once per window. Both answers are
greedy with proofs, the frontier never needs to shrink and the
window walk is a breadth-first layering in disguise.

The dry run: the fixtures are 2, 3, 1, 1, 4 at 2 jumps and the
trapped 3, 2, 1, 0, 4, asserted by the C\# suite and pinned the same
way in all five sibling suites.

+ The reach scan over 2, 3, 1, 1, 4 lifts the frontier twice:
  0 + 2 = 2, then 1 + 3 = 4, and the frontier already covers the
  last index.
+ The level walk pays one hop over window 0 to 0, which reaches to
  2, then a second over 1 to 2, which reaches 4: 2 jumps.
+ Over 3, 2, 1, 0, 4 the frontier moves once, 0 + 3 = 3, then
  stalls: 1 + 2 = 3, 2 + 1 = 3, 3 + 0 = 3.
+ Index 4 sits past the stalled frontier, the scan reports
  unreachable, and the level walk returns minus 1.
+ One step at a time over 1, 1, 1, 1 pays 3 hops, the single 5 over
  5, 0, 0 clears in 1, and standing on 0 costs 0.

#diagram([two reach traces, the classic lifting its frontier to 4 at index 1, the trapped run stalling at 3 until index 4 passes it], length: 13pt, {
  // top: values then reach after each index for 2 3 1 1 4; bottom: the stall
  let panel = (y0, a, far, hot) => {
    for (i, v) in a.enumerate() {
      let x = 1.6 + i * 2.0
      cdraw.rect((x, y0), (x + 1.6, y0 + 0.8), fill: luma(235), radius: 0.02)
      cdraw.content((x + 0.8, y0 + 0.4), [#v], size: 6pt)
      cdraw.content((x + 0.8, y0 - 0.4), [#i], size: 6pt)
      let f = far.at(i)
      cdraw.rect((x, y0 - 1.6), (x + 1.6, y0 - 0.8), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.8, y0 - 1.2), if f == none { [past] } else { [#f] }, size: 6pt)
    }
  }
  cdraw.content((12.9, 8.3), [2 3 1 1 4, the reach row], size: 6.5pt)
  panel(7.0, (2, 3, 1, 1, 4), (2, 4, 4, 4, 5), (1,))
  cdraw.content((12.9, 5.2), [windows 0-0 then 1-2: 2 jumps], size: 6pt)
  cdraw.content((12.9, 4.2), [3 2 1 0 4, the reach row stalls], size: 6.5pt)
  panel(2.6, (3, 2, 1, 0, 4), (3, 3, 3, 3, none), (1, 2, 3, 4))
  cdraw.content((12.9, 0.4), [index 4 past frontier 3: unreachable], size: 6pt)
  cdraw.content((12.9, -0.4), [both pinned: 2 jumps, minus 1], size: 6pt)
})

The pair of 2 and minus 1 is the pinned landing, and the listings
below run both scans in six languages.

#listing("dsa/samples-c/src/Ch18/jumpgame.c", first: 19, last: 49, caption: [c, the running frontier, then the level windows])

#listing("dsa/samples/src/Ch18/JumpGame.cs", first: 13, last: 44, caption: [c\#, the running frontier, then the level windows, spans over the array])

#listing("dsa/samples-go/ch18/jumpgame.go", first: 6, last: 43, caption: [go, reach by sweep, jumps by window boundary])

#listing("dsa/samples-js/src/ch18-jumpgame.mjs", first: 4, last: 29, caption: [javascript, the frontier, then the window commit])

#listing("dsa/samples-py/src/Ch18/jumpgame.py", first: 13, last: 33, caption: [python, furthest reach, end of level pays one hop])

#listing("dsa/samples-lua/ch18_jumpgame.lua", first: 6, last: 30, caption: [lua, 1-based indices shifted down, the same two scans])

The classic anchors hold in every suite that carries the topic: 2,
3, 1, 1, 4 is reachable in 2 jumps, 3, 2, 1, 0, 4 is trapped by the
zero, one step at a time over four cells costs 3, and a single big
first hop costs 1. Python returns None when stuck, the other five
return minus one. Lua's consistency check is worth copying: whenever
the minimum is finite,
the reachability scan must say yes, one fixture set answering both
questions.

#diagram([the jump game as level windows, each jump covers a window, the next window ends at the farthest reach inside it], length: 13pt, {
  let a = (2, 3, 1, 1, 4)
  cdraw.content((9.5, 7.6), [2 3 1 1 4 in two jumps], size: 6.5pt)
  for (i, v) in a.enumerate() {
    cdraw.rect((3.2 + i * 1.7, 5.6), (4.9 + i * 1.7, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((4.05 + i * 1.7, 6.05), [#v], size: 6pt)
    cdraw.content((4.05 + i * 1.7, 5.25), [#i], size: 6pt)
  }
  cdraw.line((3.2, 4.6), (6.6, 4.6), stroke: luma(100))
  cdraw.line((3.2, 4.6), (3.2, 4.45), stroke: luma(100))
  cdraw.line((6.6, 4.6), (6.6, 4.45), stroke: luma(100))
  cdraw.content((4.9, 4.15), [jump 1 covers 0 to 2], size: 6pt)
  cdraw.line((3.2, 3.1), (11.7, 3.1), stroke: luma(100))
  cdraw.line((3.2, 3.1), (3.2, 2.95), stroke: luma(100))
  cdraw.line((11.7, 3.1), (11.7, 2.95), stroke: luma(100))
  cdraw.content((7.45, 2.65), [jump 2 covers the rest, via index 1 or 2], size: 6pt)
  cdraw.line((4.9, 5.6), (6.05, 4.75), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.line((6.05, 4.55), (10.0, 3.25), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.5, 1.6), [reach = max(reach, i + a[i])], size: 6pt)
  cdraw.content((9.5, 0.7), [the frontier never shrinks], size: 6pt)
  cdraw.content((9.5, -0.2), [3 2 1 0 4: the zero traps the run], size: 6pt)
})

== backtracking

N-queens is the canonical backtrack: place row by row, prune on
column and both diagonals, recurse, undo. The meter counts
placements and prunes.

The dry run: the fixtures are identical literals in all six suites.
Queens pins the triples (solutions, placements, prunes) at n = 1
through 5 and 8: (1, 1, 0), (0, 6, 4), (0, 18, 13), (2, 60, 44),
(10, 220, 167), and (92, 15720, 13664), a placement counted per
column tried before the conflict test and a prune per rejected
column. Subset sum takes 3, 34, 4, 12, 5, 2 to 9 true and 30 false,
the single 7 against 7 true, the empty set against 1 false, and 8,
2 against 0 true. Permutations of 4 emit 24 distinct orders, first
0, 1, 2, 3, second 0, 1, 3, 2, third 0, 2, 1, 3, last 3, 2, 1, 0.

+ At n = 1 the lone cell is a solution, count 1, while n = 2 and
  n = 3 die on the flags, count 0 each.
+ At n = 4 the first live walk tries column 0 at row 0, dies inside
  row 2, backs out, and column 1 lands the solution 1, 3, 0, 2,
  every column and diagonal flag fresh at each placement.
+ Undoing to row 0 and trying column 2 lands the mirror 2, 0, 3, 1,
  and the count closes at 2.
+ n = 5 pins 10 and n = 8 pins 92, with the pruned meter under
  100000 placements against the raw tree's 8^8 = 16777216.
+ Subset sum takes 3, 9 - 3 = 6, skips 34, takes 4, 6 - 4 = 2,
  skips 12 and 5, takes 2, 2 - 2 = 0, true, while the same set
  against 30 exhausts the tree false.
+ Permutations of 4 enumerate 4 x 3 x 2 x 1 = 24 orders, first 0,
  1, 2, 3, last 3, 2, 1, 0.

#diagram([the n = 4 board, the first solution shaded column by column, its mirror stroked, the counts and the meter beside it], length: 13pt, {
  // sol1 (1,3,0,2) shaded, mirror (2,0,3,1) stroked, they share no cells
  for r in range(4) {
    for c in range(4) {
      cdraw.rect((1.4 + c * 1.1, 6.6 - r * 1.1), (2.5 + c * 1.1, 7.7 - r * 1.1), fill: luma(248), radius: 0.02)
    }
  }
  for (r, c) in ((0, 1), (1, 3), (2, 0), (3, 2)) {
    cdraw.rect((1.4 + c * 1.1, 6.6 - r * 1.1), (2.5 + c * 1.1, 7.7 - r * 1.1), fill: luma(205), radius: 0.02)
    cdraw.content((1.95 + c * 1.1, 7.15 - r * 1.1), [q], size: 6pt)
  }
  for (r, c) in ((0, 2), (1, 0), (2, 3), (3, 1)) {
    cdraw.rect((1.48 + c * 1.1, 6.68 - r * 1.1), (2.42 + c * 1.1, 7.62 - r * 1.1), fill: none, stroke: luma(100), radius: 0.02)
    cdraw.content((1.95 + c * 1.1, 7.15 - r * 1.1), [q], size: 6pt)
  }
  cdraw.content((3.6, 8.2), [first 1 3 0 2 shaded, mirror stroked], size: 6pt)
  cdraw.content((10.2, 7.2), [flags: column, r+c, r-c], size: 6pt)
  cdraw.content((10.2, 6.2), [place, recurse, undo], size: 6pt)
  cdraw.content((10.2, 5.2), [counts 1, 0, 0, 2, 10, 92], size: 6pt)
  cdraw.content((10.2, 4.2), [under 100000 placements], size: 6pt)
  cdraw.content((10.2, 3.2), [raw tree 8^8 = 16.7 million], size: 6pt)
  cdraw.content((10.2, 2.2), [subset: 9 - 3 - 4 - 2 = 0], size: 6pt)
  cdraw.content((10.2, 1.2), [target 30 exhausts false], size: 6pt)
  cdraw.content((10.2, 0.2), [perms of 4: 24, last 3 2 1 0], size: 6pt)
})

The count rests at 92 for under a hundred thousand placements, and
the listings below carry the whole machine, queens to permutations,
six ways.

#listing("dsa/samples/src/Ch18/Greedy.cs", first: 170, last: 254, caption: [c\#, n-queens with diagonal pruning, subset sum, next permutation])

The known solution counts are pinned, one, zero, zero, two, ten,
through ninety-two at n equal 8, and the meter shows what pruning
buys: under a hundred thousand placements against sixteen point
seven million for the unpruned tree. The O(1) attack and undo on
three flat boolean arrays is the standard trick, no board is ever
materialized. Subset sum is the same shape with include and exclude
branches, and the permutation enumerator is backtracking in its
amortized next-permutation form. Chapter 20 returns to n-queens with
the pruning map around it.

#listing("dsa/samples-c/src/Ch18/backtrack.c", first: 31, last: 58, caption: [c, the flag arrays, the metered place and undo])

#listing("dsa/samples-go/ch18/backtrack.go", first: 11, last: 46, caption: [go, closure recursion, the meter behind a pointer])

#listing("dsa/samples-js/src/ch18-backtrack.mjs", first: 1, last: 31, caption: [javascript, an optional meter object, destructured flag writes])

#listing("dsa/samples-py/src/Ch18/backtrack.py", first: 14, last: 34, caption: [python, the stats triple closed over by the recursion])

#listing("dsa/samples-lua/ch18_backtrack.lua", first: 7, last: 30, caption: [lua, 1-based diagonal slots, nil clears the flags])

Measured across the suites: all six pin the same meter triples, from
(1, 1, 0) at n = 1 to (92, 15720, 13664) at n = 8, the bump landing
the moment a column is tried so the counts stay comparable. Subset
sum answers true on 9 and false on 30 with the same take-then-skip
branch order, and the permutation enumerators emit the same 24
lexicographic orders with first, second, third, and last pinned. The
meter rides a pointer struct in Go, a stats triple in Python, an
optional object in JavaScript, a plain struct in C, a keyed table in
Lua, and a class in C\#, six shapes for one contract.

#diagram([the n-queens tree twice, every row against every column unpruned, three flat boolean arrays cut it to under a hundred thousand], length: 13pt, {
  // left: raw branching, right: the same tree with cut branches
  cdraw.content((5.5, 8.0), [n-queens unpruned], size: 6.5pt)
  let node = (pos) => cdraw.rect((pos.at(0) - 0.3, pos.at(1) - 0.21), (pos.at(0) + 0.3, pos.at(1) + 0.21), fill: luma(235), radius: 0.02)
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100))
  e((5.5, 6.99), (2.5, 6.21))
  e((5.5, 6.99), (5.5, 6.21))
  e((5.5, 6.99), (8.5, 6.21))
  node((5.5, 7.2))
  cdraw.content((5.5, 7.2), [q], size: 6pt)
  for x in (2.5, 5.5, 8.5) {
    node((x, 6.0))
    e((x, 5.79), (x - 1.1, 5.01))
    e((x, 5.79), (x, 5.01))
    e((x, 5.79), (x + 1.1, 5.01))
  }
  for x in (1.4, 2.5, 3.6, 4.4, 5.5, 6.6, 7.4, 8.5, 9.6) {
    node((x, 4.8))
  }
  for x in (1.4, 2.5, 3.6, 4.4, 5.5, 6.6, 7.4, 8.5, 9.6) {
    cdraw.content((x, 3.7), [...], size: 6pt)
  }
  cdraw.content((5.5, 2.6), [every row tries every column], size: 6pt)
  cdraw.content((5.5, 1.5), [8^8 = 16.7 million placements], size: 6pt)
  cdraw.content((5.5, 0.4), [92 solutions buried in the tree], size: 6pt)
  cdraw.content((5.5, -0.7), [the meter counts placements], size: 6pt)

  cdraw.content((18.0, 8.0), [pruned by three arrays], size: 6.5pt)
  e((18.0, 6.99), (15.0, 6.21))
  e((18.0, 6.99), (18.0, 6.21))
  e((18.0, 6.99), (21.0, 6.21))
  node((18.0, 7.2))
  cdraw.content((18.0, 7.2), [q], size: 6pt)
  node((15.0, 6.0))
  node((18.0, 6.0))
  node((21.0, 6.0))
  e((15.0, 5.79), (13.8, 5.01))
  e((15.0, 5.79), (16.2, 5.01))
  e((15.0, 5.79), (15.0, 5.4))
  e((18.0, 5.79), (18.0, 5.01))
  e((18.0, 5.79), (16.9, 5.4))
  e((18.0, 5.79), (19.1, 5.4))
  e((21.0, 5.79), (21.0, 5.4))
  node((13.8, 4.8))
  node((16.2, 4.8))
  node((18.0, 4.8))
  cdraw.content((15.0, 5.0), [x], size: 6pt)
  cdraw.content((16.9, 5.0), [x], size: 6pt)
  cdraw.content((19.1, 5.0), [x], size: 6pt)
  cdraw.content((21.0, 5.0), [x], size: 6pt)
  cdraw.content((13.8, 3.7), [...], size: 6pt)
  cdraw.content((16.2, 3.7), [...], size: 6pt)
  cdraw.content((18.0, 3.7), [...], size: 6pt)
  cdraw.content((18.0, 2.6), [column and both diagonals as flags], size: 6pt)
  cdraw.content((18.0, 1.5), [place, recurse, undo], size: 6pt)
  cdraw.content((18.0, 0.4), [under 100 thousand placements], size: 6pt)
  cdraw.content((18.0, -0.7), [no board is ever materialized], size: 6pt)
})

#callout("warning", "backtracking is exponential, honestly", [
  Pruning changes constants, not the complexity class. N-queens has
  no polynomial formula, subset sum is NP-complete, and the meters
  exist to show the tree is smaller, not that it is small. The
  engineering line: backtracking for small n or heavy structure,
  the chapter 17 table when the recurrence has overlapping
  subproblems, and an approximation or a solver when neither holds.
  The approximation chapter, #xref-to("dsa", "approximation"), builds
  that third road with its ratios measured.
])

The chapter ends with the selection rule the whole spine argues
for: measure the shape of the input, name the invariant you can
maintain in the data structure, count the operations honestly, and
pick the simplest structure whose counted cost fits the budget.
Four more chapters push the table, the range query, the plane, and
the probabilistic structure further, then the capstone puts all of
it into one running system.

== across the six languages

The build sizes count non-comment source lines. The first table
covers the chapter's original featured files, the C\# row carrying
its whole `Greedy.cs` plus the jump game build, the backtracking
section counted again in the second table:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [174], [libc only], [qsort with a comparator function, huffman weights in unsigned long long, jumps return minus one],
  [c\#], [248], [bcl only], [rooms ride the chapter 8 heap, fractional knapsack at 240 against the table's 220, ReadOnlySpan jump scans],
  [go], [104], [slices], [slices.SortFunc orders intervals, two min scans select the huffman pair, single-symbol codes forced to length 1],
  [javascript], [110], [node stdlib], [a hand-built heap keyed by weight then insertion order keeps the fixture tree deterministic],
  [python], [115], [stdlib only], [sort stands in for the priority queue, itertools.combinations brute-checks the schedule, stuck jumps read None],
  [lua], [217], [lib.lua harness], [insertion-order tie-break in every sort, encode and decode round trip abcdef, maximality checked by hand],
)

The backtracking section lands as its own file in the five sibling
trees, the C\# build staying the Backtrack class inside `Greedy.cs`:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [128], [libc only], [a meter struct by pointer, three flag arrays, lexicographic order proved by a comparator walk],
  [c\#], [72], [bcl only], [the Backtrack class inside Greedy.cs, iterator permutations, a nullable Meter class],
  [go], [82], [slices], [closure recursion, the meter behind a pointer, Permutations materialized as copies],
  [javascript], [51], [node stdlib], [generator permutations, an optional meter object, destructured flag writes],
  [python], [82], [stdlib only], [a stats triple closed over by the recursion, slice reversal flips the tail],
  [lua], [111], [lib.lua harness], [1-based diagonal slots, nil clears the flags, table.concat keys prove distinctness],
)

sources: learn.microsoft.com, `BinaryHeap` usage here rides the
chapter 8 implementation, `OrderBy` remarks, `StringBuilder`,
accessed 2026-09-08, plus the CLRS activity selection and huffman
treatments cited in the chapter text. Sample behavior verified by
`make verify-csharp`, 13 tests in chapter 18 of the samples suite.
The six-language layer verifies the same way: 4 C programs with 61
embedded checks under `make verify-c`, 14 Go tests, 13 `node --test`
cases, 49 Python checks across 4 files, and 18 Lua checks under
`run.lua`.
