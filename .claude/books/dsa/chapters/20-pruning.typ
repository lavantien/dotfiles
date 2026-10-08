#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= pruning and branch and bound

Exponential searches fail for two different reasons, and the fixes
are different. Overlapping subproblems call for a memo table,
chapter 17. A search space with hopeless branches calls for pruning,
and a search with a quality bound calls for branch and bound, where
an optimistic estimate of a subtree kills it before it is explored.
This chapter puts the three tools side by side on the same fixture,
then builds the canonical pruned searches: n-queens, the 0/1
knapsack under a fractional bound, and alpha-beta over a game tree.

== the pruning map, one grid three ways

Count the right-and-down paths across a grid. The naive recursion
pays once per path-prefix, the memo table pays once per cell, and a
pruned depth-first walk with a visited set pays once per path, which
is worse than the memo but survives where the memo cannot, on walks
that may revisit cells and would loop forever without the cycle
guard.

The dry run: the fixtures are the open 3 by 3 and 4 by 4 grids,
asserted by the C\# suite, with C carrying the call meter, 19 naive
calls against 9 memoized on the 3 by 3.

+ The memo seeds the top row 1, 1, 1, one way into each cell, then
  fills row by row: row 1 lands 1, 1 + 1 = 2, 2 + 1 = 3, and row 2
  lands 1, 1 + 2 = 3, 3 + 3 = 6 at the corner.
+ The open 4 by 4 fills the same way and ends at 20, and with the
  center blocked the corner drops to 2, both pinned by the suite.
+ Naive recursion pays one call per path prefix, so cell (1,1) is
  entered twice and the corner six times, summing the 3 by 3 to 1 +
  1 + 1 + 1 + 2 + 3 + 1 + 3 + 6 = 19 calls against the memo's 9,
  one per cell.
+ On the 10 by 10 the same split reads 184755 against exactly 100
  calls for the same 48620 paths.
+ The suite adds the walk the memo cannot serve: four-direction
  simple paths corner to corner count 12 on the open 3 by 3 against
  the 6 monotone ones.

#diagram([the run as two grids of the same nine path counts, the memo computing each cell once, the naive walk paying once per path prefix, 19 calls against 9], length: 13pt, {
  let counts = ((1, 1, 1), (1, 2, 3), (1, 3, 6))
  let grid = (x0, seq) => {
    for (r, row) in counts.enumerate() {
      for (c, v) in row.enumerate() {
        let (x, y) = (x0 + c * 1.15, 7.2 - r * 1.0)
        cdraw.rect((x, y), (x + 1.05, y + 0.92), fill: if (r, c) == (2, 2) { luma(205) } else { luma(235) }, radius: 0.02)
        cdraw.content((x + 0.525, y + 0.55), [#v], size: 6.5pt)
        if seq { cdraw.content((x + 0.85, y + 0.2), [#(r * 3 + c + 1)], size: 6pt) }
      }
    }
  }
  cdraw.content((2.95, 8.6), [the memo, one call per cell], size: 6.5pt)
  grid(0.75, true)
  cdraw.content((2.95, 3.4), [9 calls, the corner lands 6], size: 6pt)
  cdraw.content((12.9, 8.6), [the naive walk, once per prefix], size: 6.5pt)
  grid(10.7, false)
  cdraw.content((12.9, 3.4), [1 + 1 + 1 + 1 + 2 + 3 + 1 + 3 + 6 = 19 calls], size: 6pt)
  cdraw.content((19.4, 6.6), [the cell value is the number], size: 6pt)
  cdraw.content((19.4, 6.05), [of prefixes reaching it], size: 6pt)
  cdraw.content((19.4, 4.9), [so naive calls per cell], size: 6pt)
  cdraw.content((19.4, 4.35), [equal the memo value], size: 6pt)
  cdraw.content((19.4, 3.2), [10x10: 184755 against 100], size: 6pt)
  cdraw.content((19.4, 2.1), [both land 48620 paths], size: 6pt)
})

The corner lands 6 both ways and the listings below build the memo,
the pruned walk, and the simple-path count in seven languages.

#listing("dsa/samples-c/src/Ch20/memo_vs_prune.c", first: 25, last: 50, caption: [c, naive with a call meter against the memoized walk])

#listing("dsa/samples-go/ch20/memo_vs_prune.go", first: 38, last: 73, caption: [go, the pruned dfs, unmark on the way out is the whole trick])

#listing("dsa/samples-java/src/Ch20/MemoVsPrune.java", first: 20, last: 52, caption: [java, naive with the meter, the seen-flag memo, guards run before the count])

#listing("dsa/samples/src/Ch20/Pruning.cs", first: 10, last: 48, caption: [c\#, the memo table, then the same count pruned with a visited set])

#listing("dsa/samples-js/src/ch20-memo_vs_prune.mjs", first: 6, last: 35, caption: [javascript, memo rows of minus one, dfs with the cycle guard])

#listing("dsa/samples-py/src/Ch20/memo_vs_prune.py", first: 15, last: 44, caption: [python, the memo count and the pruned count as mirror functions])

#listing("dsa/samples-lua/ch20_memo_vs_prune.lua", first: 7, last: 44, caption: [lua, the memo table, then the dfs with its guard])

The open 3 by 3 grid pins the anchor everywhere: 6 paths. C and
Java carry the meter that makes the map a table of numbers, 19
naive calls against 9 memoized on the 3 by 3, and on the 10 by 10
the split is 184755 against exactly 100, one call per cell, for the
same 48620 paths, Java adding the walled 3 by 3 to the meter table,
9 naive calls against 8 memoized, the blocked cell returning before
the count. With the center blocked every suite still agrees on 2,
and
the C\# suite adds the case the memo cannot serve, four-direction
simple paths between two cells, where the visited set is
load-bearing because the walk can turn back into itself: 12 simple
paths on the open 3 by 3 against the 6 monotone ones.

#diagram([the pruning map on one grid, the memo keeps one value per cell, the visited set guards the cycle the memo cannot], length: 13pt, {
  cdraw.content((5.6, 7.8), [the same 3x3, two tools], size: 6.5pt)
  let grid = ((1, 1, 1), (1, 2, 3), (1, 3, 6))
  for (r, row) in grid.enumerate() {
    for (c, v) in row.enumerate() {
      cdraw.rect((2.0 + c * 1.1, 6.5 - r * 0.95), (3.1 + c * 1.1, 7.45 - r * 0.95), fill: if (r, c) == (2, 2) { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((2.55 + c * 1.1, 6.975 - r * 0.95), [#v], size: 6pt)
    }
  }
  cdraw.content((5.6, 3.5), [memo: one value per cell], size: 6pt)
  cdraw.content((5.6, 2.5), [19 naive calls, 9 memoized], size: 6pt)
  cdraw.content((5.6, 1.5), [10x10: 184755 against 100], size: 6pt)
  cdraw.content((5.6, 0.5), [both land 48620 paths], size: 6pt)

  cdraw.content((17.0, 7.8), [the visited set, when walks can turn back], size: 6.5pt)
  for (r, row) in grid.enumerate() {
    for (c, v) in row.enumerate() {
      let hot = (r, c) in ((0, 0), (0, 1), (0, 2), (1, 2), (2, 2))
      cdraw.rect((13.0 + c * 1.1, 6.5 - r * 0.95), (14.1 + c * 1.1, 7.45 - r * 0.95), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    }
  }
  cdraw.line((14.65, 7.0), (14.65, 6.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.65, 6.55), (15.75, 6.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.75, 6.55), (15.75, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.75, 5.6), (14.65, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.6, 4.3), [mark on entry, unmark on exit], size: 6pt)
  cdraw.content((17.4, 3.3), [no path visits a cell twice], size: 6pt)
  cdraw.content((17.6, 2.3), [12 simple paths, 4 directions], size: 6pt)
  cdraw.content((17.6, 1.3), [6 monotone paths, 2 directions], size: 6pt)
  cdraw.content((17.6, 0.3), [the memo cannot serve this walk], size: 6pt)
})

== n-queens, pruned by three arrays

Place one queen per row, and before recursing check the column, the
diagonal, and the antidiagonal in constant time, row plus column and
row minus column are constant along the two diagonal families. The
board itself never exists, three flag arrays hold the whole state,
and the undo is three assignments.

The dry run: the fixture is n = 4, whose 2 solutions the C\# suite
pins alongside 10 at n = 5 and 92 at n = 8, and C captures the
first placement at columns 1, 3, 0, 2.

+ Row 0 tries column 0 first, its branch dies below, and the first
  surviving landing is column 1: col 1, diag 0 - 1 = -1, anti
  0 + 1 = 1, all fresh.
+ Row 1 rejects column 0 because 1 + 0 = 1 repeats row 0's anti,
  column 1 on the column flag, column 2 because 1 - 2 = -1 repeats
  the diag, and lands column 3: diag -2, anti 4.
+ Row 2 rejects columns 1 and 3 on the column flag and column 2
  because 2 + 2 = 4 repeats row 1's anti, landing column 0: diag 2,
  anti 2.
+ Row 3 rejects columns 0, 1, and 3 on the column flag and lands
  column 2: diag 1, anti 5, the captured placement 1, 3, 0, 2.
+ The undo on the way out is three assignments, the scan finishes on
  the mirror 2, 0, 3, 1, and n = 4 closes at 2.

#diagram([the first 4-queens placement row by row, the three flags each queen sets, dead columns marked before every landing], length: 13pt, {
  let frame = (y, label, dead, q, flags) => {
    cdraw.content((1.2, y), label, size: 6.5pt)
    for c in range(4) {
      let x = 3.2 + c * 1.0
      cdraw.rect((x, y - 0.4), (x + 0.9, y + 0.4), fill: if c == q { luma(205) } else { luma(235) }, radius: 0.02)
      if c == q { cdraw.content((x + 0.45, y), [Q], size: 6.5pt) }
      else if c in dead { cdraw.content((x + 0.45, y), [x], size: 6pt) }
    }
    cdraw.content((9.6, y), flags, size: 6pt)
  }
  frame(7.6, [row 0], (), 1, [col 1, diag -1, anti 1])
  frame(6.1, [row 1], (0, 1, 2), 3, [col 3, diag -2, anti 4])
  frame(4.6, [row 2], (1, 2, 3), 0, [col 0, diag 2, anti 2])
  frame(3.1, [row 3], (0, 1, 3), 2, [col 2, diag 1, anti 5])
  cdraw.content((3.2, 2.0), [x: killed by a flag check, Q: placed, undo is three assignments], size: 6pt)
  cdraw.content((3.2, 1.1), [the scan finishes on the mirror 2, 0, 3, 1: n = 4 pins 2], size: 6pt)
  cdraw.content((17.6, 6.1), [row + c constant on one diagonal], size: 6pt)
  cdraw.content((17.6, 5.0), [row - c constant on the other], size: 6pt)
  cdraw.content((17.6, 3.9), [every check is O(1)], size: 6pt)
  cdraw.content((17.6, 2.8), [n = 8 closes at 92], size: 6pt)
})

Two at n = 4 is the pinned count and the listings below place,
check, and undo in seven languages.

#listing("dsa/samples-c/src/Ch20/nqueens.c", first: 24, last: 54, caption: [c, the three flag arrays, the raw permutation tree for contrast])

#listing("dsa/samples-go/ch20/nqueens.go", first: 8, last: 31, caption: [go, col, diag, antidiag slices, mark and unmark])

#listing("dsa/samples-java/src/Ch20/Nqueens.java", first: 21, last: 58, caption: [java, int flag arrays, the first solution captured, the raw permutation tree beside it])

#listing("dsa/samples/src/Ch20/Pruning.cs", first: 70, last: 96, caption: [c\#, place row by row, constant-time attack checks])

#listing("dsa/samples-js/src/ch20-nqueens.mjs", first: 5, last: 28, caption: [javascript, three Sets keyed by column and both diagonals])

#listing("dsa/samples-py/src/Ch20/nqueens.py", first: 13, last: 39, caption: [python, the solver that returns the solutions, validity checked])

#listing("dsa/samples-lua/ch20_nqueens.lua", first: 6, last: 25, caption: [lua, 0-based diagonals inside, the meter outside])

The 92 anchor holds in every suite: eight queens have exactly 92
solutions, with the small boards pinned alongside, 1, 0, 0, 2, 10,
4 for n = 1 through 6. Lua reaches past the headline and pins 7 at
40 and 9 at 352, Java pins 7 at 40 too, Python and Java return the
actual solutions and check every one peaceful plus duplicate-free,
with the lexicographically first pinned, and C and Java keep the
first 4-queens placement, columns 1, 3, 0, 2, and measure the prune
against the raw permutation tree, 1957 nodes at n = 6 against far
fewer pruned.

#diagram([n-queens prunes on three arrays, column, diagonal, antidiagonal, all constant time], length: 13pt, {
  cdraw.content((9.5, 7.9), [the first 4-queens solution, columns 1, 3, 0, 2], size: 6.5pt)
  let queens = (1, 3, 0, 2)
  for (r, c) in queens.enumerate() {
    for cc in range(4) {
      let hot = cc == c
      cdraw.rect((3.2 + cc * 1.1, 6.6 - r * 1.05), (4.3 + cc * 1.1, 7.65 - r * 1.05), fill: if hot { luma(205) } else { luma(248) }, stroke: if hot { luma(100) }, radius: 0.02)
      if hot {
        cdraw.content((3.75 + cc * 1.1, 7.125 - r * 1.05), [Q], size: 6.5pt)
      }
    }
  }
  for t in range(4) {
    cdraw.content((3.75 + t * 1.1, 7.95), [#t], size: 6pt)
  }
  cdraw.content((16.6, 6.8), [col[c]: one flag per column], size: 6pt)
  cdraw.content((16.9, 5.7), [diag[row + c]: 2n - 1 flags], size: 6pt)
  cdraw.content((17.2, 4.6), [anti[row - c + n]: as many], size: 6pt)
  cdraw.content((16.6, 3.5), [check in O(1), undo in O(1)], size: 6pt)
  cdraw.content((16.6, 2.4), [n = 8: 92 solutions], size: 6pt)
  cdraw.content((16.6, 1.3), [n = 7: 40, n = 9: 352], size: 6pt)
  cdraw.content((16.6, 0.2), [raw tree at n = 6: 1957 nodes], size: 6pt)
})

== branch and bound, the knapsack with a bound

Sort the items by value density, then walk the include-exclude tree
with one extra question at every node: what does the fractional
knapsack say this subtree could still reach, filling the remaining
capacity with slices? If even that optimistic bound cannot beat the
best complete solution found so far, the subtree dies unexplored.

The dry run: the fixture is weights 2, 3, 4, 5 against values 3, 4,
5, 6 at capacity 5, asserted by the C\# suite at best 7 in exactly
5 nodes, the hand trace.

+ Densities 3/2, 4/3, 5/4, 6/5 leave the identity order 0, 1, 2, 3.
+ The root bound fills the sack exactly, item 0 whole plus item 1
  whole, 3 + 4 = 7 with no slice, and 7 beats the incumbent 0.
+ Taking item 0 costs room 5 - 2 = 3 at value 3; the bound there
  adds item 1 whole, 3 + 4 = 7, above the incumbent 3, so the walk
  descends again.
+ Taking item 1 too lands room 0 at value 3 + 4 = 7, the new
  incumbent, and the bound at that node equals 7, so 7 <= 7 stops
  it.
+ Skipping item 1 holds room 3 at value 3; the bound slices item 2
  at 5 x 3 / 4 = 3, landing 3 + 3 = 6, pruned. Skipping item 0 at
  the root holds room 5 at value 0; its bound takes item 1 whole
  then slices item 2 at 5 x 2 / 4 = 2, landing 4 + 2 = 6, pruned
  the same way.

#diagram([the walk as five nodes, each with the fractional fill of its remaining capacity, whole items shaded, the slice outlined], length: 13pt, {
  let row = (y, label, segs, bound, verdict) => {
    cdraw.content((1.2, y), label, size: 6pt)
    let x = 5.2
    for s in segs {
      let (w, txt, slice) = s
      cdraw.rect((x, y - 0.3), (x + w * 0.62, y + 0.3), fill: if slice { none } else { luma(205) }, stroke: if slice { luma(100) } else { none }, radius: 0.02)
      cdraw.content((x + w * 0.31, y), txt, size: 6pt)
      x += w * 0.62
    }
    cdraw.content((12.4, y), bound, size: 6pt)
    cdraw.content((14.2, y), verdict, size: 6pt)
  }
  row(7.5, [root], ((2, [i0], false), (3, [i1], false)), [7], [exact, descend])
  row(6.2, [take i0], ((3, [i1], false),), [7], [descend])
  row(4.9, [take i0, i1], ((2, [i0], false), (3, [i1], false)), [7], [best 7, stops])
  row(3.6, [skip i1], ((3, [i2 3/4], true),), [6], [pruned])
  row(2.3, [skip i0], ((3, [i1], false), (2, [i2 2/4], true)), [6], [pruned])
  cdraw.content((5.2, 8.4), [the bound fills the remaining capacity, the outlined block is the slice], size: 6.5pt)
  cdraw.content((1.2, 1.2), [integer slices: 5 x 3 / 4 = 3 and 5 x 2 / 4 = 2], size: 6pt)
  cdraw.content((1.2, 0.3), [16 brute subsets, 5 nodes, best 7], size: 6pt)
  cdraw.content((18.3, 5.5), [densities keep the order], size: 6pt)
  cdraw.content((18.3, 4.4), [capacity 50 pins 220], size: 6pt)
  cdraw.content((18.3, 3.3), [capacity 29 pins 135], size: 6pt)
})

Best 7 in 5 nodes against 16 brute-force subsets, and the listings
below sort, bound, and prune in seven languages.

#listing("dsa/samples-c/src/Ch20/bandb.c", first: 38, last: 75, caption: [c, the fractional relaxation, the dfs it gates, the dp oracle])

#listing("dsa/samples-go/ch20/bandb.go", first: 17, last: 67, caption: [go, slice the item that does not fit, nodes counted])

#listing("dsa/samples-java/src/Ch20/Bandb.java", first: 26, last: 78, caption: [java, insertion sort by density, the fractional bound gating the dfs, nodes counted])

#listing("dsa/samples/src/Ch20/Pruning.cs", first: 103, last: 147, caption: [c\#, density sort, fractional bound, incumbent pruning])

#listing("dsa/samples-js/src/ch20-bandb.mjs", first: 7, last: 40, caption: [javascript, the bound and the walk, node counts returned])

#listing("dsa/samples-py/src/Ch20/bandb.py", first: 18, last: 54, caption: [python, the fractional bound exact at the root, the descend with choices])

#listing("dsa/samples-lua/ch20_bandb.lua", first: 8, last: 47, caption: [lua, the same walk, hand-traced node counts pinned])

The optimums pin exactly where the suite traces them by hand. C\#,
C, and Java hold the classic capacity-50 fixture at 220 with the
chapter 17 dynamic program as the cross-check, C's and Java's
second fixture, four items at capacity 29, landing 135. Lua
hand-traces its trees: weights 2, 3, 4, 5 at capacity 5 answers 7
in exactly 5 nodes, root, two takes, two bound-pruned rejections,
and the capacity-50 fixture in 12. JavaScript pins the same shape,
optimum 7 in 5 nodes against 16 brute-force leaves, and Python and
Java pin 90 in 6 nodes with the bound arithmetic exposed, the root
bound exact at 90.0 and the one below it at 88.75. Java also runs
its own raw twin with the bound switched off, asserting the pruned
tree never costs a node against it. Node counts beyond the
hand-traced ones are asserted by
inequality only, pruned below raw and raw below the full tree,
because capacity trimming makes hand-counts brittle, and every suite
keeps the brute-force enumeration as the oracle. When the tree stops
finishing inside the budget, #xref-to("dsa", "approximation") is the
planned exit: a proven ratio on the same instance, bought by giving
up the certificate.

#diagram([branch and bound on the knapsack, the fractional bound kills subtrees the incumbent already beats], length: 13pt, {
  cdraw.content((9.5, 7.9), [the include-exclude tree under a bound], size: 6.5pt)
  let node = (x, y, s, hot) => {
    cdraw.rect((x - 0.85, y - 0.26), (x + 0.85, y + 0.26), fill: if hot == 1 { luma(205) } else if hot == 2 { luma(248) } else { luma(235) }, stroke: if hot == 2 { luma(100) }, radius: 0.02)
    cdraw.content((x, y), s, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100))
  e((6.0, 6.8), (3.4, 5.7))
  e((6.0, 6.8), (8.6, 5.7))
  e((3.4, 5.0), (2.0, 3.9))
  e((3.4, 5.0), (4.8, 3.9))
  e((8.6, 5.0), (7.2, 3.9))
  e((8.6, 5.0), (10.0, 3.9))
  node(6.0, 6.8, [root, ub 7], 0)
  node(3.4, 5.7, [take item 1], 0)
  node(8.6, 5.7, [skip item 1], 2)
  node(2.0, 4.5, [take item 0, 7], 1)
  node(4.8, 4.5, [skip item 0], 2)
  node(7.2, 4.5, [bound 7 = best], 2)
  node(10.0, 4.5, [bound too low], 2)
  cdraw.content((9.5, 3.3), [dark: the incumbent 7, outlined: explored], size: 6pt)
  cdraw.content((9.5, 2.4), [faint: killed by the bound], size: 6pt)
  cdraw.content((9.5, 1.5), [capacity 5, optimum 7, 5 nodes], size: 6pt)
  cdraw.content((9.5, 0.6), [the dp table is the oracle], size: 6pt)
  cdraw.content((17.4, 5.9), [sort by value density first], size: 6pt)
  cdraw.content((17.4, 4.8), [slice the misfit item for the bound], size: 6pt)
  cdraw.content((17.4, 3.7), [bound below incumbent: prune], size: 6pt)
  cdraw.content((17.4, 2.6), [capacity 50 pins 220], size: 6pt)
  cdraw.content((17.4, 1.5), [capacity 29 pins 135], size: 6pt)
  cdraw.content((17.4, 0.4), [node counts by inequality only], size: 6pt)
})

== alpha-beta, the game tree pruned by a window

Minimax assumes the opponent plays optimally and takes the value of
the game. Alpha-beta computes the identical value while refusing to
read leaves that cannot change it: the maximizer at the root carries
alpha, the best value it already owns, and the moment a minimizer's
running minimum drops to alpha or below, its remaining leaves are
dead, the maximizer would never walk into that child.

The dry run: the fixture is the nine leaves 3, 12, 8, 2, 4, 6, 14,
5, 2 at arity 3, asserted by the C\# suite at root value 3 with 9
plain leaf reads against 7 under the window.

+ Group 1 reads all three leaves: the running min steps 3, 12, 8 and
  lands 3, the root maxes to 3, and alpha rises to 3.
+ Group 2 reads one leaf: the 2 drops its running min to 2, beta
  falls to 2, and beta <= alpha closes the window with leaves 4 and
  6 unread.
+ Group 3 reads all three, 14, 5, 2, min 2, and the root keeps 3.
+ Plain minimax pays 3 + 3 + 3 = 9 leaf reads, the window pays 3 +
  1 + 3 = 7, at the identical value 3.
+ The depth-four fixture runs the same story bigger: 27 leaves at
  arity 3 read 27 plain against 21 under the window, 9 + 3 + 9 hand
  traced, value 7.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*leaf*], [*group min now*], [*alpha*], [*beta*], [*what happens*]),
  [3], [3], [-inf], [+inf], [group 1 reads on],
  [12], [3], [-inf], [+inf], [group 1 reads on],
  [8], [3], [3], [+inf], [group 1 done, root max 3],
  [2], [2], [3], [2], [beta <= alpha, 4 and 6 die],
  [14], [14], [3], [+inf], [group 3 reads on],
  [5], [5], [3], [+inf], [group 3 reads on],
  [2], [2], [3], [+inf], [group 3 done, root keeps 3],
)

Seven of nine leaves for the same value 3, and the listings below
run both walks with the leaf meter.

#listing("dsa/samples-c/src/Ch20/alphabeta.c", first: 27, last: 71, caption: [c, plain minimax, then the min side stopping at alpha])

#listing("dsa/samples-go/ch20/alphabeta.go", first: 26, last: 61, caption: [go, fail-low breaks the row scan, the value unchanged])

#listing("dsa/samples-java/src/Ch20/Alphabeta.java", first: 19, last: 73, caption: [java, plain minimax, then the min side stopping at alpha, every leaf metered])

#listing("dsa/samples/src/Ch20/Pruning.cs", first: 194, last: 228, caption: [c\#, the window carried down, leaf visits counted])

#listing("dsa/samples-js/src/ch20-alphabeta.mjs", first: 5, last: 28, caption: [javascript, minimax and alpha-beta over one node tree])

#listing("dsa/samples-py/src/Ch20/alphabeta.py", first: 17, last: 45, caption: [python, both walks with a stats dict counting leaves])

#listing("dsa/samples-lua/ch20_alphabeta.lua", first: 19, last: 61, caption: [lua, the recursive window, beta at or below alpha breaks])

The pinned tree is three groups of three leaves, 3, 12, 8, 2, 4, 6,
14, 5, 2, with root value 3, and the meter is the lesson: plain
minimax reads all 9 leaves, alpha-beta reads 7, the second group
dies after its first leaf because 2 already fails low against the
root's alpha of 3. Java adds two orderings beside the pinned tree,
a rising one where the window prunes nothing at all and a tied one
where five leaf reads suffice, the child-order sensitivity stated
as numbers. The deeper fixture agrees everywhere it pins: 27
leaves at arity 3 read 27 plain against 21 with the window, C\# and
Lua hand-trace it as 9 plus 3 plus 9, and every suite asserts the
two algorithms return the same value whatever the tree.

#diagram([alpha-beta on the pinned tree, the second group dies after one leaf, the value is still 3], length: 13pt, {
  cdraw.content((9.5, 7.9), [3 12 8 / 2 4 6 / 14 5 2: root value 3], size: 6.5pt)
  cdraw.rect((5.0, 5.9), (14.0, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((9.5, 6.3), [max, alpha rises to 3], size: 6pt)
  let groups = ((2.0, (3, 12, 8), 1), (7.0, (2, 4, 6), 2), (12.0, (14, 5, 2), 1))
  for g in groups {
    let (x, leaves, kind) = g
    cdraw.line((9.5, 5.9), (x + 1.5, 5.0), stroke: luma(100))
    cdraw.rect((x, 4.3), (x + 3.0, 5.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.5, 4.65), [min], size: 6pt)
    for (i, v) in leaves.enumerate() {
      let dead = kind == 2 and i > 0
      cdraw.line((x + 1.5, 4.3), (x + 0.35 + i * 0.75, 3.5), stroke: if dead { (paint: luma(200), dash: "dashed") } else { luma(100) })
      cdraw.rect((x + i * 0.75, 2.9), (x + 0.7 + i * 0.75, 3.5), fill: if dead { luma(248) } else { luma(205) }, radius: 0.02)
      cdraw.content((x + 0.35 + i * 0.75, 3.2), [#v], size: 6pt)
    }
  }
  cdraw.content((9.5, 2.2), [group 1 reads all 3, value 3], size: 6pt)
  cdraw.content((9.5, 1.3), [group 2 dies after the 2: fails low], size: 6pt)
  cdraw.content((9.5, 0.4), [7 leaves read of 9, same root value], size: 6pt)
  cdraw.content((18.2, 5.8), [alpha: the best max owns], size: 6pt)
  cdraw.content((18.2, 4.7), [beta: the best min owns], size: 6pt)
  cdraw.content((18.2, 3.6), [beta at or below alpha: stop], size: 6pt)
  cdraw.content((18.2, 2.5), [27 leaves: 27 against 21], size: 6pt)
  cdraw.content((18.2, 1.4), [the value never changes], size: 6pt)
  cdraw.content((18.2, 0.3), [only the work shrinks], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines over this chapter's
four featured files per language, checks included where they share
the file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [325], [libc only], [flag arrays sized by constants, the raw permutation tree kept as the contrast, node counts by inequality],
  [go], [198], [slices], [slices.SortFunc orders by density, closures carry the dfs, the brute enumerates 2^n leaves],
  [java], [585], [jdk 27 stdlib], [the raw tree beside every prune, first solutions captured, the set-based queens solver with a local Walker class, two extra alpha-beta orderings],
  [c\#], [199], [bcl only], [HashSet for the visited set, the simple-paths case the memo cannot serve, 27 and 21 hand traced],
  [javascript], [109], [node stdlib], [three Sets for the queens flags, minus-one memo sentinel, the node tree walked recursively],
  [python], [198], [stdlib only], [the solver returns solutions checked peaceful and duplicate-free, set for the visited guard],
  [lua], [276], [lib.lua harness], [maxinteger infinities, hand-traced node counts 5 and 12, 40 and 352 beyond the 92 anchor],
)

sources: learn.microsoft.com, `HashSet<T>` for the visited set,
`Array.Sort` comparison overloads, accessed 2026-09-08, plus the
CLRS branch-and-bound and the Knuth alpha-beta treatment cited in
the chapter text. Sample behavior verified by `make verify-csharp`,
9 tests in chapter 20 of the samples suite. The seven-language
layer verifies the same way: 4 C programs with 51 embedded checks
under `make verify-c`, 4 Ch20 java programs with 81 checks under
`run-java-samples`, 9 Go tests, 8 `node --test` cases, 33 Python
checks across 4 files, and 14 Lua checks under `run.lua`.
