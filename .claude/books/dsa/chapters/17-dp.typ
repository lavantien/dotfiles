#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= dynamic programming

Dynamic programming is not a technique so much as a recognition: when
a recursive solution recomputes the same subproblems, storing them
turns exponential into polynomial. This chapter runs the same
recurrences three ways, naive, memoized, tabulated, with call
counters making the difference a number, then builds the canonical
tables with reconstruction, six languages deep.

== the three fibonaccis

The naive recursion recomputes subproblems, and the call tree grows
like the fibonacci numbers themselves. The meter proves it: fib of 10
makes 177 calls, not 10.

The dry run: the fixture is n = 10 on the C\# meter, 177 naive
calls for the value 55, with the memo pin 12586269025 at n = 50;
C and Python pin 21891 against 39 at n = 20, Go counts only real
evaluations at 9, and Lua's memo meter reads 19.

+ The naive meter counts every entry, leaf and interior alike,
  and the tree at 10 closes at 177 calls for the value 55.
+ The memoized road evaluates each argument once, 0 through 10,
  and reads the cache after that.
+ The tabulated road runs a pair, one fold per row of the table
  below, from 0 + 1 = 1 to the register holding 55.
+ All eighty values agree across memo and table, the pin that
  makes the three roads one function.
+ fib(50) = 12586269025 answers from the memo instantly, the size
  the naive tree cannot reach.
+ The ladder of 10 rungs is the same recurrence shifted one, and
  its count is 89.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*i*], [*prev*], [*cur*], [*prev + cur*]),
  [2], [0], [1], [0 + 1 = 1],
  [3], [1], [1], [1 + 1 = 2],
  [4], [1], [2], [1 + 2 = 3],
  [5], [2], [3], [2 + 3 = 5],
  [6], [3], [5], [3 + 5 = 8],
  [7], [5], [8], [5 + 8 = 13],
  [8], [8], [13], [8 + 13 = 21],
  [9], [13], [21], [13 + 21 = 34],
  [10], [21], [34], [21 + 34 = 55],
)

The 177 calls against the pair's ten folds is the recognition in
two numbers, and the listings below run all three roads in six
languages.

#listing("dsa/samples-c/src/Ch17/memo.c", first: 19, last: 57, caption: [c, naive with a call meter, memo arrays, the table, the ladder])

#listing("dsa/samples/src/Ch17/Dp.cs", first: 4, last: 43, caption: [c\#, naive with a call meter, memoized, tabulated])

#listing("dsa/samples-go/ch17/memo.go", first: 6, last: 46, caption: [go, the meter as a pointer, the memo as a map, real evaluations counted])

#listing("dsa/samples-js/src/ch17-memo.mjs", first: 7, last: 36, caption: [javascript, meter object, Map memo, fib 78 is the exact ceiling])

#listing("dsa/samples-py/src/Ch17/memo.py", first: 14, last: 47, caption: [python, a dict memo by hand, functools.cache is the named counterpart])

#listing("dsa/samples-lua/ch17_memo.lua", first: 6, last: 31, caption: [lua, the closure over the memo table, the pair walk])

Memoization is top-down with a cache, one call per distinct argument,
and the fifty-fifth fibonacci computes instantly where the naive
version would need billions of calls. Tabulation is bottom-up, a
running pair instead of a table, and the agreement test checks all
eighty values match across both. The recognition to carry forward:
overlapping subproblems, the cache fixes them, and optimal
substructure, the answer composes from subanswers. Both must hold or
the memo is just a cache on wrong math.

The call-count anchors line up with one deliberate split in what the
meter counts. At n = 10 the naive tree is 177 calls in C\#,
JavaScript, Go, and Lua, and the memoized run is 19 calls in Lua,
every argument touched once. C and Python pin the bigger instance
instead, fib of 20 at 21891 naive calls against 39 memoized, and C
adds the warm-cache fact, a second memoized run costs exactly 1
call. Go counts only real evaluations, the cache probe is free, so
its memo meter reads 9 at n = 10. The ladder recurrence, one or two
rungs at a time, is fibonacci shifted by one, and ladder of 10 is 89
wherever it is pinned.

#diagram([the same recurrence three ways, the naive tree recomputes, the memo keeps one call per argument, the table keeps a running pair], length: 13pt, {
  // naive fib tree to depth two, repeats shaded; then chain and pair
  cdraw.content((4.3, 7.7), [naive: the tree recomputes], size: 6.5pt)
  let node = (pos, v, hot) => {
    cdraw.rect((pos.at(0) - 0.35, pos.at(1) - 0.25), (pos.at(0) + 0.35, pos.at(1) + 0.25), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content(pos, [#v], size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100))
  e((4.3, 6.75), (2.2, 6.15))
  e((4.3, 6.75), (6.4, 6.15))
  e((2.2, 5.65), (1.2, 5.05))
  e((2.2, 5.65), (3.2, 5.05))
  e((6.4, 5.65), (5.4, 5.05))
  e((6.4, 5.65), (7.4, 5.05))
  node((4.3, 7.0), [10], false)
  node((2.2, 5.9), [9], false)
  node((6.4, 5.9), [8], false)
  node((1.2, 4.8), [8], true)
  node((3.2, 4.8), [7], false)
  node((5.4, 4.8), [7], true)
  node((7.4, 4.8), [6], false)
  for x in (1.2, 3.2, 5.4, 7.4) {
    cdraw.line((x, 4.55), (x, 4.2), stroke: luma(220))
    cdraw.content((x, 3.95), [...], size: 6pt)
  }
  cdraw.content((4.3, 3.1), [repeats shaded], size: 6pt)
  cdraw.content((4.3, 2.0), [fib(10): 177 calls], size: 6pt)
  cdraw.content((4.3, 0.9), [fib(55) needs billions], size: 6pt)

  cdraw.content((13.2, 7.7), [memoized: the cache], size: 6.5pt)
  node((12.0, 6.5), [10], false)
  node((12.0, 5.4), [9], false)
  node((12.0, 4.3), [8], false)
  cdraw.content((12.0, 3.4), [...], size: 6pt)
  node((12.0, 2.5), [0], false)
  for y in ((6.25, 5.68), (5.15, 4.58), (4.05, 3.6), (3.2, 2.78)) {
    cdraw.line((12.0, y.at(0)), (12.0, y.at(1)), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.rect((13.9, 3.6), (15.3, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((14.6, 4.5), [memo], size: 6pt)
  cdraw.line((12.4, 5.4), (13.9, 4.8), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((13.2, 1.75), [one call per argument], size: 6pt)
  cdraw.content((12.9, 0.65), [the tree becomes a chain], size: 6pt)

  cdraw.content((20.3, 7.7), [tabulated: a pair], size: 6.5pt)
  cdraw.content((18.7, 6.55), [prev], size: 6pt)
  cdraw.content((21.6, 6.55), [cur], size: 6pt)
  node((18.7, 5.9), [0], false)
  node((21.6, 5.9), [1], false)
  cdraw.line((19.6, 5.35), (20.7, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.7, 4.95), (19.6, 4.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((20.3, 4.2), [prev becomes cur], size: 6pt)
  cdraw.content((20.3, 3.1), [cur becomes the sum], size: 6pt)
  cdraw.content((20.3, 2.0), [no recursion at all], size: 6pt)
  cdraw.content((20.3, 0.9), [n steps to fib(n)], size: 6pt)
  cdraw.content((12.0, -0.5), [all eighty values agree, the meter is the only difference], size: 6.5pt)
})

== grid paths

Grid paths with obstacles is the cleanest 2d recurrence: ways into a
cell is ways from above plus ways from the left, walls contribute
zero.

The dry run: the fixtures are the open 3 by 3 at 6, the
center-wall at 2, and the sealed corner at 0, all asserted by the
C\# suite; C pins the 4 by 4 double-block table at 4, Lua adds the
open 4 by 4 at 20, and Python reruns the count through a memo.

+ The open grid seeds its corner at 1 and the borders follow:
  row 0 reads 1, 1, 1 and column 0 the same.
+ The interior folds: 1 + 1 = 2 at the center, 2 + 1 = 3 beside
  it, and the far corner lands 3 + 3 = 6, the choose 4 pick 2
  count, pinned.
+ Wall the center: the cell folds in nothing, row 1 reads
  1, 0, 1, and the corner recomputes 1 + 1 = 2, the two border
  routes, pinned.
+ Seal (0, 1) and (1, 0): row 1 reads 1, 0, 0, nothing reaches
  the far corner, and the answer is 0.
+ The sweep is row-major, one line per cell, so a wall costs
  nothing extra: it is a cell that contributes zero.

#diagram([the walled 3 by 3 sweeping row by row, the wall contributing zero, the corner landing 2], length: 13pt, {
  let grids = (
    (((1, 1), (1, 1), (1, 1)), ((0, 0), (0, 2), (0, 0)), ((0, 0), (0, 0), (0, 0))),
    (((1, 1), (1, 1), (1, 1)), ((1, 1), (0, 2), (1, 1)), ((0, 0), (0, 0), (0, 0))),
    (((1, 1), (1, 1), (1, 1)), ((1, 1), (0, 2), (1, 1)), ((1, 1), (1, 1), (2, 1))),
  )
  let titles = ([after row 0], [after row 1], [after row 2])
  for (g, grid) in grids.enumerate() {
    let x0 = 0.8 + g * 5.0
    cdraw.content((x0 + 1.65, 7.6), titles.at(g), size: 6pt)
    for (r, row) in grid.enumerate() {
      for (c, cell) in row.enumerate() {
        let (v, kind) = cell
        let x = x0 + c * 1.1
        let y = 6.3 - r * 0.95
        if kind == 2 {
          cdraw.rect((x, y - 0.42), (x + 1.0, y + 0.45), fill: none, stroke: luma(100), radius: 0.02)
        } else if kind == 1 {
          cdraw.rect((x, y - 0.42), (x + 1.0, y + 0.45), fill: if g == 2 and r == 2 and c == 2 { luma(205) } else { luma(235) }, radius: 0.02)
          cdraw.content((x + 0.5, y + 0.01), [#v], size: 6pt)
        } else {
          cdraw.rect((x, y - 0.42), (x + 1.0, y + 0.45), fill: none, stroke: (paint: luma(200), dash: "dashed"), radius: 0.02)
        }
      }
    }
    if g < 2 { cdraw.line((x0 + 3.4, 4.7), (x0 + 4.8, 4.7), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((8.0, 2.9), [open grid: the corner folds 3 + 3 = 6], size: 6pt)
  cdraw.content((8.0, 1.9), [sealed corner: 0 paths arrive], size: 6pt)
  cdraw.content((8.0, 0.9), [one line per cell, walls fold zero], size: 6pt)
})

The 6 against the walled 2 is the pinned pair, and the listings
below sweep the grid in six languages.

#listing("dsa/samples-c/src/Ch17/gridpaths.c", first: 19, last: 41, caption: [c, one line per cell, the 4x4 double block table pinned])

#listing("dsa/samples/src/Ch17/Dp.cs", first: 45, last: 63, caption: [c\#, grid paths, one line per cell, walls as zeros])

#listing("dsa/samples-go/ch17/gridpaths.go", first: 3, last: 31, caption: [go, first row and column seeded, then the sweep])

#listing("dsa/samples-js/src/ch17-gridpaths.mjs", first: 4, last: 16, caption: [javascript, the add-from-above-and-left loop])

#listing("dsa/samples-py/src/Ch17/gridpaths.py", first: 13, last: 48, caption: [python, the table, then the same count through a recursive memo])

#listing("dsa/samples-lua/ch17_gridpaths.lua", first: 5, last: 22, caption: [lua, the grid read as strings, a hash walls the cell])

The anchors hold across all six: the open 3 by 3 counts 6, the
choose 4 pick 2 of monotone paths, and blocking the center leaves
exactly 2, the two border routes. C pins a full 4 by 4 table with
two interior walls and the answer 4, Lua adds the open 4 by 4 at 20
and the sealed corner at 0, and Python runs the same count a second
way through a recursive memo, the table and the cache agreeing, which
is the whole chapter in one fixture.

#diagram([grid paths as a table, one line per cell, walls as zeros, the answer in the far corner], length: 13pt, {
  // 3x4 grid, wall at r1c2, answer corner shaded
  cdraw.content((6.6, 7.95), [grid paths as a table], size: 6.5pt)
  let grid = ((1, 1, 1, 1), (1, 2, 0, 1), (1, 3, 3, 4))
  for (r, row) in grid.enumerate() {
    for (c, v) in row.enumerate() {
      let wall = r == 1 and c == 2
      let corner = r == 2 and c == 3
      cdraw.rect((2.2 + c * 1.1, 6.4 - r * 0.85), (3.3 + c * 1.1, 7.25 - r * 0.85), fill: if wall { none } else if corner { luma(205) } else { luma(235) }, stroke: if wall { luma(100) }, radius: 0.02)
      if not wall {
        cdraw.content((2.75 + c * 1.1, 6.825 - r * 0.85), [#v], size: 6pt)
      }
    }
  }
  cdraw.content((6.6, 3.6), [ways in = above + left], size: 6pt)
  cdraw.content((6.6, 2.5), [walls contribute zero], size: 6pt)
  cdraw.content((6.6, 1.4), [one line per cell, row by row], size: 6pt)
  cdraw.content((6.6, 0.3), [the answer sits in the far corner], size: 6pt)
  cdraw.content((16.6, 5.9), [open 3x3: 6 paths], size: 6pt)
  cdraw.content((16.6, 4.8), [center wall: 2 border routes], size: 6pt)
  cdraw.content((16.6, 3.7), [open 4x4: 20 paths], size: 6pt)
  cdraw.content((16.6, 2.6), [sealed corner: 0], size: 6pt)
  cdraw.content((16.6, 1.5), [same answer from the memo side], size: 6pt)
})

== the zero one knapsack

The knapsack is the one interviewers mean when they say dp. The
table indexes items against remaining capacity, each cell choosing
between skipping and taking the item, and the reconstruction walks
the table backwards asking which choice was made.

The dry run: the fixture is weights 2, 3, 4, 5 against values
3, 4, 5, 6 at capacity 5, asserted by the C\# suite at 7 with
items 0 and 1 rebuilt, and C, Python, and Lua carry the same
fixture.

+ Row item 0, weight 2 value 3: capacities 0 and 1 hold 0, and
  2 through 5 fill at 0 + 3 = 3.
+ Row item 1, weight 3 value 4: capacity 3 improves to 0 + 4 = 4,
  and capacity 5 takes 3 + 4 = 7.
+ Row item 2, weight 4 value 5: capacity 4 improves to 0 + 5 = 5,
  and capacity 5's offer of 0 + 5 = 5 loses to the incumbent 7.
+ Row item 3, weight 5 value 6: the offer of 0 + 6 = 6 loses too,
  and the corner reads 7, pinned.
+ The backwalk asks each row whether its cell differs from the
  cell above: items 3 and 2 tie at 7 and drop, item 1 differs,
  7 against 3, taken at c = 5 - 3 = 2, and item 0 differs,
  3 against 0, taken: items 0 and 1, pinned.
+ The zero-one boundary: three weight-4 items in capacity 8 land
  5 + 5 = 10 at exactly two whole items, never a fraction.

#diagram([the capacity row landing item by item, the corner holding 7, the backwalk dropping through the ties to items 0 and 1], length: 13pt, {
  let rows = (
    ([item 0, w2 v3], (0, 0, 3, 3, 3, 3)),
    ([item 1, w3 v4], (0, 0, 3, 4, 4, 7)),
    ([item 2, w4 v5], (0, 0, 3, 4, 5, 7)),
    ([item 3, w5 v6], (0, 0, 3, 4, 5, 7)),
  )
  cdraw.content((8.4, 7.3), [capacity 0 through 5], size: 6pt)
  for (r, row) in rows.enumerate() {
    let y = 6.5 - r * 1.1
    cdraw.content((1.3, y), row.at(0), size: 6pt)
    for (c, v) in row.at(1).enumerate() {
      cdraw.rect((4.6 + c * 1.0, y - 0.33), (5.6 + c * 1.0, y + 0.33), fill: if c == 5 and r >= 1 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((5.1 + c * 1.0, y), [#v], size: 6pt)
    }
  }
  cdraw.content((1.3, 1.6), [backwalk: 7 = 7, 7 = 7, drop, drop], size: 6pt)
  cdraw.content((1.3, 0.7), [then 7 vs 3 takes item 1, 3 vs 0 item 0], size: 6pt)
})

The 7 rebuilt as items 0 and 1 is the pinned pair, and the
listings below pack six ways.

#listing("dsa/samples-c/src/Ch17/knapsack.c", first: 23, last: 43, caption: [c, the full table, then the row rolled right to left])

#listing("dsa/samples/src/Ch17/Dp.cs", first: 65, last: 96, caption: [c\#, zero one knapsack with item reconstruction])

#listing("dsa/samples-go/ch17/knapsack.go", first: 9, last: 54, caption: [go, the table with backwalk, the rolled row beside it])

#listing("dsa/samples-js/src/ch17-knapsack.mjs", first: 5, last: 33, caption: [javascript, the table, the backwalk, the rolled row])

#listing("dsa/samples-py/src/Ch17/knapsack.py", first: 13, last: 43, caption: [python, the table, the rolled row, the readback])

#listing("dsa/samples-lua/ch17_knapsack.lua", first: 6, last: 36, caption: [lua, nested tables, the downward capacity walk])

The zero-one test matters as a boundary: three identical weight-4
items in capacity 8 yields exactly two whole items, never a
fraction, and the fractional comparison in chapter 18 beats it at
240 versus 220 on shared input, the two problem variants genuinely
differing.

The shared fixture is weights 2, 3, 4, 5 against values 3, 4, 5, 6
at capacity 5, and the answer 7 with items 0 and 1 taken pins in C,
Python, and Lua, with Python's second fixture, weights 1, 2, 3
against values 6, 10, 12, landing the classic 22 with items 1 and 2.
The rolled row agrees with the full table everywhere it exists, and
the downward capacity walk is why: sweeping right to left means an
item can never feed its own cell, which is the one-use rule stated
as a loop direction. C\# keeps its own fixtures and the fractional
contrast, Lua brute-forces every mask as a cross-check.

#diagram([the knapsack table as memory, cells choosing skip or take, rebuild from the corner], length: 13pt, {
  // three weight 4 items, capacity 8, taken cells shaded
  cdraw.content((18.7, 8.15), [knapsack, capacity 0 to 8], size: 6.5pt)
  let ks = ((0, 0, 0, 0, 0), (0, 0, 5, 5, 5), (0, 0, 5, 5, 10), (0, 0, 5, 5, 10))
  let taken = ((1, 2), (2, 4))
  for (r, row) in ks.enumerate() {
    cdraw.content((13.55, 6.8 - r * 0.8), [#r], size: 6pt)
    for (c, v) in row.enumerate() {
      let hot = (r, c) in taken
      cdraw.rect((14.0 + c, 6.4 - r * 0.8), (15.0 + c, 7.2 - r * 0.8), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((14.5 + c, 6.8 - r * 0.8), [#v], size: 6pt)
    }
  }
  cdraw.content((5.6, 6.4), [skip: the cell above], size: 6pt)
  cdraw.content((5.6, 5.3), [take: up-left plus value], size: 6pt)
  cdraw.content((5.6, 4.2), [shaded: the chosen items], size: 6pt)
  cdraw.content((5.6, 3.1), [rebuild from the corner], size: 6pt)
  cdraw.content((5.6, 2.0), [rolled row sweeps backward], size: 6pt)
  cdraw.content((5.6, 0.9), [an item never feeds its own cell], size: 6pt)
})

== sequences and their tables

Longest common subsequence and edit distance are the same table
shape wearing different recurrences, match extends the diagonal,
otherwise take the better neighbor.

The dry run: the fixtures are ABCBDAB against BDCABA at length 4
with the rebuild checked as a property, and the edit distance
family, kitten to sitting 3, flaw to lawn 2, empty against abc 3,
same against same 0, all asserted by the C\# suite.

+ The lcs corner reads 4 and the rebuild walks (7, 6) backward,
  emitting only on matches.
+ B against A mismatches and the row above wins, so the walk steps
  up into the A pair: a match emits A, and the diagonal beneath
  holds 4 - 1 = 3.
+ D against B mismatches and steps up into the B pair: emit B,
  diagonal 3 - 1 = 2.
+ C against A steps left into the C pair: emit C, diagonal
  2 - 1 = 1.
+ B against D steps left into the B pair: emit B, diagonal
  1 - 1 = 0, and the border ends the walk.
+ Reversed, the emission reads BCAB, one of several optimal
  answers, accepted because both strings contain it at the pinned
  length 4.

#diagram([the rebuild walking backward, every match emitting one letter and dropping the counter by one, the reversed emission a valid answer], length: 13pt, {
  let stations = (
    ([start at (7, 6)], [4], none),
    ([A = A], [3], [A]),
    ([B = B], [2], [B]),
    ([C = C], [1], [C]),
    ([B = B], [0], [B]),
  )
  for (i, s) in stations.enumerate() {
    let x = 0.8 + i * 3.4
    cdraw.content((x + 0.9, 7.0), s.at(0), size: 6pt)
    cdraw.rect((x, 5.4), (x + 1.8, 6.3), fill: if i == 0 { luma(235) } else { luma(205) }, radius: 0.02)
    cdraw.content((x + 0.9, 5.85), s.at(1), size: 6.5pt)
    if s.at(2) != none { cdraw.content((x + 2.7, 5.85), [emit #s.at(2)], size: 6pt) }
    if i < 4 { cdraw.line((x + 1.9, 5.85), (x + 3.3, 5.85), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((0.8, 4.4), [reversed:], size: 6pt)
  let out = ([B], [C], [B], [A])
  for (i, ch) in out.enumerate() {
    cdraw.rect((2.6 + i * 1.0, 3.9), (3.5 + i * 1.0, 4.8), fill: if i == 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.05 + i * 1.0, 4.35), ch, size: 6.5pt)
  }
  cdraw.content((0.8, 2.9), [BCAB: a subsequence of both, length 4], size: 6pt)
  cdraw.content((0.8, 1.9), [mismatch steps never emit], size: 6pt)
  cdraw.content((0.8, 0.9), [edit distance: same shape, three prices], size: 6pt)
  cdraw.content((0.8, 0.0), [kitten to sitting 3, flaw to lawn 2], size: 6pt)
})

The 4, rebuilt as BCAB and accepted by property, is the pin, and
the listings below fill both tables.

#listing("dsa/samples/src/Ch17/Dp.cs", first: 97, last: 128, caption: [c\#, lcs with reconstruction, the chapter 15 fixture family])

LCS reconstruction must be checked as a property, both strings
contain the output as a subsequence and its length hits four,
because multiple optimal answers exist. Edit distance gets the
textbook cases plus symmetry:

#listing("dsa/samples-c/src/Ch17/editdist.c", first: 21, last: 36, caption: [c, the full table, substitution priced 1 or 2])

#listing("dsa/samples/src/Ch17/Dp.cs", first: 130, last: 150, caption: [c\#, unit costs, the min of three neighbors])

#listing("dsa/samples-go/ch17/editdist.go", first: 3, last: 26, caption: [go, borders seeded, the built-in min of three])

#listing("dsa/samples-js/src/ch17-editdist.mjs", first: 4, last: 20, caption: [javascript, the whole table, match free])

#listing("dsa/samples-py/src/Ch17/editdist.py", first: 13, last: 30, caption: [python, sub_cost a parameter, a recursive brute cross-check])

#listing("dsa/samples-lua/ch17_editdist.lua", first: 5, last: 18, caption: [lua, two rows ping-ponged, O(min) memory])

The kitten to sitting anchor, distance 3, holds in every suite. The
variants split by memory and by price: Lua keeps two rows and swaps
them, the whole table never exists, C and Python price substitution
at 2 as a parameter and watch the answer rise to 5, insert plus
delete arithmetic, and C pins interior cells of the table plus the
abcdef to azced case at 3. Lua adds the symmetry check on a long
pair and the bound by the longer side.

#diagram([the same table shape under two recurrences, lcs extends the diagonal, edit distance prices three moves], length: 13pt, {
  // lcs of abc against ac; edit distance of ab against its reverse
  cdraw.content((5.4, 7.7), [lcs: the diagonal extends], size: 6.5pt)
  let cell = (x, y, w, h, body) => {
    cdraw.rect((x, y), (x + w, y + h), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), body, size: 6pt)
  }
  // header row then the a, b, c rows against columns a, c
  cell(3.8, 6.43, 1.0, 0.72, [a])
  cell(4.8, 6.43, 1.0, 0.72, [c])
  cell(2.8, 5.71, 1.0, 0.72, [a])
  cell(3.8, 5.71, 1.0, 0.72, [1])
  cell(4.8, 5.71, 1.0, 0.72, [1])
  cell(2.8, 4.99, 1.0, 0.72, [b])
  cell(3.8, 4.99, 1.0, 0.72, [1])
  cell(4.8, 4.99, 1.0, 0.72, [1])
  cell(2.8, 4.27, 1.0, 0.72, [c])
  cell(3.8, 4.27, 1.0, 0.72, [1])
  cell(4.8, 4.27, 1.0, 0.72, [2])
  cdraw.line((4.5, 5.15), (4.95, 4.85), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.4, 3.4), [a match extends the diagonal], size: 6pt)
  cdraw.content((5.4, 2.3), [a mismatch takes the best neighbor], size: 6pt)
  cdraw.content((5.4, 1.2), [the rebuild is a checked property], size: 6pt)

  cdraw.content((15.6, 7.7), [edit distance: three prices], size: 6.5pt)
  cell(13.35, 6.55, 0.85, 0.6, [b])
  cell(14.2, 6.55, 0.85, 0.6, [a])
  cell(12.5, 5.95, 0.85, 0.6, [a])
  cell(13.35, 5.95, 0.85, 0.6, [1])
  cell(14.2, 5.95, 0.85, 0.6, [1])
  cell(12.5, 5.35, 0.85, 0.6, [b])
  cell(13.35, 5.35, 0.85, 0.6, [1])
  cell(14.2, 5.35, 0.85, 0.6, [2])
  cdraw.content((15.6, 4.7), [insert, delete, substitute], size: 6pt)
  cdraw.content((15.6, 3.7), [each priced one], size: 6pt)
  cdraw.content((15.6, 2.6), [kitten to sitting: 3], size: 6pt)
  cdraw.content((15.6, 1.5), [sub at price 2: 5], size: 6pt)
  cdraw.content((15.6, 0.4), [flaw to lawn: 2], size: 6pt)
})

== coin change, the greedy killer

With coins 1, 5, 11 and amount 15, taking the largest coin first
strands you at four singles for 5 coins while the table finds three
fives.

The dry run: the fixture is coins 1, 5, 11 asserted by the C\#
suite, amount 10 at 2 and the greedy killer 15 at 3, while C and
Python run the 1, 5, 12 family, where 15 costs 3 against greedy's
4.

+ The table seeds at amount 0 with 0 coins, everything past it
  impossible.
+ The 1 coin climbs the low amounts: table[1] = 0 + 1 = 1 through
  table[4] = 4.
+ The 5 coin lands at 5 with 0 + 1 = 1, and 10 follows at 1 + 1 =
  2, the suite's other pin, two fives.
+ The 11 coin lands at 11 with 0 + 1 = 1.
+ Amount 15 tries all three roads: the 1 coin offers 4 + 1 = 5,
  the 11 coin offers 4 + 1 = 5, and the 5 coin offers 2 + 1 = 3:
  the table keeps 3, three fives, pinned.
+ Greedy takes 11 first and strands at 4, paying 1 + 4 = 5 coins,
  and the unreachable channel shows {2, 4} at 7 reading -1 out.

#diagram([the min-coin table sweeping amounts 0 to 15, the 5 and 11 coins landing, the three offers at 15 with the cheapest shaded], length: 13pt, {
  let vals = (0, 1, 2, 3, 4, 1, 2, 3, 4, 5, 2, 1, 2, 3, 4, 3)
  for (i, v) in vals.enumerate() {
    let x = 0.9 + i * 1.15
    cdraw.rect((x, 4.6), (x + 1.0, 5.5), fill: if i == 15 { luma(205) } else if i in (5, 10, 11) { luma(220) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.5, 5.05), [#v], size: 6pt)
    cdraw.content((x + 0.5, 4.2), [#i], size: 6pt)
  }
  let offers = ([1 coin: 4 + 1 = 5], [11 coin: 4 + 1 = 5], [5 coin: 2 + 1 = 3])
  for (i, o) in offers.enumerate() {
    let x = 0.9 + i * 5.0
    cdraw.rect((x, 2.4), (x + 4.4, 3.2), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 2.2, 2.8), o, size: 6pt)
  }
  cdraw.content((0.9, 1.5), [greedy: 11 then four singles, 5 coins], size: 6pt)
  cdraw.content((0.9, 0.6), [{2, 4} at 7 never fills, -1 out], size: 6pt)
})

The 3 against greedy's 5 is the pinned kill, and the listings
below count coins six ways.

#listing("dsa/samples-c/src/Ch17/coins.c", first: 20, last: 51, caption: [c, minimum coins, combinations, greedy for contrast])

#listing("dsa/samples/src/Ch17/Dp.cs", first: 152, last: 168, caption: [c\#, fewest coins, unreachable marked])

#listing("dsa/samples-go/ch17/coins.go", first: 5, last: 38, caption: [go, min coins with an error, combinations one loop per coin])

#listing("dsa/samples-js/src/ch17-coins.mjs", first: 5, last: 23, caption: [javascript, Infinity for impossible, the coin-outer count])

#listing("dsa/samples-py/src/Ch17/coins.py", first: 13, last: 39, caption: [python, None for unreachable, greedy beside the table])

#listing("dsa/samples-lua/ch17_coins.lua", first: 7, last: 35, caption: [lua, maxinteger for impossible, -1 back out])

The awkward coinage splits into two families, both real: C and
Python use 1, 5, 12, where amount 15 costs 3 against greedy's 4 and
amount 16 costs 4 as 5+5+5+1 against 12+1+1+1+1, and C\#,
JavaScript, and Lua use 1, 5, 11, where 15 costs 3 against greedy's
5. The canonical trap, coins 1, 3, 4 at amount 6, dp says 3+3 while
greedy says 4+1+1, pins in C and Python. The combination counter
puts its coin loop on the outside so order never double counts, and
its anchors are 4 ways for 1, 2, 3 at 4 and 5 ways for 1, 5, 12 at
15. The unreachable channel is per language again, minus one in C\#
and Lua, null in JavaScript, None in Python, an error in Go.

#callout("note", "when greedy fails, this is why", [
  Greedy makes one irreversible choice per step. It is optimal when
  the choice has an exchange argument, chapter 18 builds several
  that do. Coin change has none: the locally best coin can be
  globally wrong. The general test of greedy is exactly this, look
  for a counterexample before trusting it, and reach for the table
  when one exists.
])

#diagram([coin change kills the greedy take, the table finds three fives where greedy strands on singles], length: 13pt, {
  cdraw.content((6.0, 2.45), [greedy], size: 6pt)
  let g = (11, 1, 1, 1, 1)
  for (i, v) in g.enumerate() {
    cdraw.rect((1.2 + i * 0.9, 2.2), (2.1 + i * 0.9, 2.7), fill: luma(235), radius: 0.02)
    cdraw.content((1.65 + i * 0.9, 2.45), [#v], size: 6pt)
  }
  cdraw.content((7.3, 2.45), [5 coins], size: 6pt)
  cdraw.content((6.0, 1.35), [table], size: 6pt)
  let t = (5, 5, 5)
  for (i, v) in t.enumerate() {
    cdraw.rect((1.2 + i * 0.9, 1.1), (2.1 + i * 0.9, 1.6), fill: luma(205), radius: 0.02)
    cdraw.content((1.65 + i * 0.9, 1.35), [#v], size: 6pt)
  }
  cdraw.content((5.4, 1.35), [3 coins], size: 6pt)
  cdraw.content((4.0, 0.25), [coin change, the greedy killer], size: 6pt)

  cdraw.content((16.6, 5.9), [coins 1, 3, 4 at amount 6], size: 6pt)
  cdraw.content((16.6, 4.8), [dp: 3 + 3, two coins], size: 6pt)
  cdraw.content((16.6, 3.7), [greedy: 4 + 1 + 1, three], size: 6pt)
  cdraw.content((16.6, 2.6), [combinations: coin loop outside], size: 6pt)
  cdraw.content((16.6, 1.5), [1, 2, 3 at 4: four ways], size: 6pt)
  cdraw.content((16.6, 0.4), [unreachable: minus one, null, none, error], size: 6pt)
})

== longest increasing subsequence

Two speeds, one question. The quadratic table lets every element
extend the best earlier smaller element and keeps parent links, so
it can rebuild an actual subsequence. The patience method keeps
tails, the smallest tail that ends a run of each length, and binary
searches each arrival into place, an n log n length with no
subsequence to show for it unless parents ride along.

The dry run: the fixture is 10, 9, 2, 5, 3, 7, 101, 18, walked by
the C\# build of chapter 19 with the length pinned at 4 and the
rebuild accepted as a property, while Python and Lua pin the run
2, 5, 7, 101 on the same array and C rebuilds 3, 4, 5, 9 on the
other fixture.

+ 10 opens the ladder alone, then 9 and 2 each replace it: one
  rung holding index 2, the value 2.
+ 5 clears the ladder and appends: the tails hold indices 2 and 3
  with parent[3] = 2.
+ 3 replaces the second rung with parent[4] = 2: the ladder reads
  the values 2, 3.
+ 7 and 101 append, parents 4 then 5, and 18 replaces 101 with
  parent[7] = 5: the final tails hold indices 2, 4, 5, 7 at
  length 4, pinned.
+ The rebuild walks the parents from the last tail, 7 to 5 to 4 to
  2, reading 18, 7, 3, 2 backward: the run 2, 3, 7, 18 forward, a
  different valid answer from Python and Lua's 2, 5, 7, 101.
+ Both answers pass the property, strictly increasing, correct
  length, drawn from the input, and the all-equal and falling
  arrays give 1.

#diagram([the parent chain under the C\# walk on 10 9 2 5 3 7 101 18, indices 2, 4, 5, 7 shaded, the rebuild reading 2, 3, 7, 18], length: 13pt, {
  let a = (10, 9, 2, 5, 3, 7, 101, 18)
  let chain = (2, 4, 5, 7)
  for (i, v) in a.enumerate() {
    let x = 0.9 + i * 2.3
    cdraw.rect((x, 5.5), (x + 2.0, 6.4), fill: if i in chain { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.0, 5.95), [#v], size: 6pt)
    cdraw.content((x + 1.0, 5.0), [#i], size: 6pt)
  }
  for k in range(3) {
    let x0 = 0.9 + chain.at(k) * 2.3 + 1.0
    let x1 = 0.9 + chain.at(k + 1) * 2.3 + 1.0
    cdraw.line((x0, 4.5), (x1, 4.5), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((9.9, 3.5), [final tails: values 2, 3, 7, 18, length 4], size: 6pt)
  cdraw.content((9.9, 2.5), [python and lua rebuild 2, 5, 7, 101], size: 6pt)
  cdraw.content((9.9, 1.5), [two right answers, one length], size: 6pt)
  cdraw.content((9.9, 0.5), [all equal: 1, falling: 1], size: 6pt)
})

The 4, reached by two different valid runs, is the pin, and the
listings below climb both roads.

#listing("dsa/samples-c/src/Ch17/lis.c", first: 18, last: 54, caption: [c, the n^2 table with reconstruction, the patience tails])

#listing("dsa/samples/src/Ch19/AdvDp.cs", first: 239, last: 275, caption: [c\#, the tails ladder with parent links, the advanced chapter's build])

#listing("dsa/samples-go/ch17/lis.go", first: 5, last: 55, caption: [go, the quadratic dp, then tails over slices.BinarySearch])

#listing("dsa/samples-js/src/ch17-lis.mjs", first: 7, last: 45, caption: [javascript, both roads return a subsequence, different valid ones])

#listing("dsa/samples-py/src/Ch17/lis.py", first: 14, last: 47, caption: [python, dp with parents, tails by hand-rolled binary search])

#listing("dsa/samples-lua/ch17_lis.lua", first: 7, last: 48, caption: [lua, the parent walk reversed, tails by integer midpoint])

Two fixtures cover the field and every suite pins length 4 on both:
3, 1, 4, 1, 5, 9, 2, 6, where C rebuilds 3, 4, 5, 9 from the
parents, and 10, 9, 2, 5, 3, 7, 101, 18, where Python and Lua pin
the run 2, 5, 7, 101 and the C\# suite of chapter 19 does its parent
walk on the same array. JavaScript's file says the interesting part
out loud: its two roads return different subsequences, and both are
valid answers, which is why reconstruction is checked as a property,
strictly increasing, correct length, drawn from the input. The
all-equal array gives length 1 everywhere, strictness is one
comparison, and the falling array gives 1 with the first element as
the witness.

#diagram([two roads to length 4 on the same array, the quadratic parents chain 3 4 5 9, the patience tails settle at 1 2 5 6], length: 13pt, {
  cdraw.content((5.6, 7.6), [the quadratic dp on 3 1 4 1 5 9 2 6], size: 6.5pt)
  let a = (3, 1, 4, 1, 5, 9, 2, 6)
  let lens = (1, 1, 2, 1, 3, 4, 2, 4)
  for (i, v) in a.enumerate() {
    let x = 1.6 + i * 1.15
    cdraw.rect((x, 5.9), (x + 1.0, 6.7), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.5, 6.3), [#v], size: 6pt)
    cdraw.rect((x, 4.7), (x + 1.0, 5.5), fill: if i in (0, 2, 4, 5) { luma(205) } else { luma(248) }, radius: 0.02)
    cdraw.content((x + 0.5, 5.1), [#(lens.at(i))], size: 6pt)
  }
  cdraw.line((2.1, 4.7), (3.3, 4.2), stroke: luma(100))
  cdraw.line((3.3, 4.2), (4.45, 4.2), stroke: luma(100))
  cdraw.line((4.45, 4.2), (5.6, 4.2), stroke: luma(100))
  cdraw.line((5.6, 4.2), (6.75, 4.2), stroke: luma(100))
  cdraw.line((6.75, 4.2), (7.35, 4.7), stroke: luma(100))
  cdraw.content((4.7, 3.7), [shaded: the parent chain 3, 4, 5, 9], size: 6pt)
  cdraw.content((4.9, 2.8), [len[i] extends the best earlier smaller], size: 6pt)
  cdraw.content((4.9, 1.9), [10 9 2 5 3 7 101 18: 2, 5, 7, 101], size: 6pt)
  cdraw.content((4.9, 1.0), [all equal: length 1, strict], size: 6pt)
  cdraw.content((4.9, 0.1), [falling: length 1], size: 6pt)

  cdraw.content((17.3, 7.6), [the patience tails settle], size: 6.5pt)
  let steps = ((3,), (1,), (1, 4), (1, 4), (1, 4, 5), (1, 4, 5, 9), (1, 2, 5, 9), (1, 2, 5, 6))
  for (r, s) in steps.enumerate() {
    let y = 6.6 - r * 0.78
    cdraw.content((11.6, y), [#(a.at(r))], size: 6pt)
    for (k, v) in s.enumerate() {
      cdraw.rect((12.6 + k * 1.0, y - 0.26), (13.6 + k * 1.0, y + 0.26), fill: if r == 7 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((13.1 + k * 1.0, y), [#v], size: 6pt)
    }
  }
  cdraw.content((17.3, 1.9), [replace or append by binary search], size: 6pt)
  cdraw.content((17.3, 1.0), [final tails 1, 2, 5, 6: length 4], size: 6pt)
  cdraw.content((17.3, 0.1), [the tails are not a subsequence], size: 6pt)
})

== bitmask subsets

When the state is a set of at most about twenty things, the subset
becomes an integer bitmask and the table is two to the n. The
assignment problem, one worker per task, is the canonical case.

The dry run: the fixtures are identical literals in all six suites.
The 3 by 3 cost matrix reads 1, 100, 100, then 2, 50, 60, then 3,
40, 80, pinned at 101 against the greedy row walk's 131, and the 4
by 4 reads 7, 3, 9, 2, then 4, 8, 3, 6, then 6, 7, 2, 5, then 9,
2, 4, 7, pinned at 10 through the permutation 3, 0, 2, 1. A brute
force over permutations agrees in-test on both. The relaxation meter
counts every inner (mask, task) pair, 8 rows and 24 attempts at n =
3, Lua's meter bumping only on a free bit for 12 there. Python adds
the lone worker at 5 and the 2 by 2 diagonal at 2, Lua its own 2 by
2 at 5.

+ best[000] = 0 seeds the sweep, and popcount of the mask names
  the worker placing next.
+ Mask 000 calls worker 0: task 0 costs 0 + 1 = 1 while tasks 1
  and 2 cost 100 each, so best[001] = 1 and best[010] =
  best[100] = 100.
+ Mask 001 calls worker 1: task 1 costs 1 + 50 = 51 and task 2
  costs 1 + 60 = 61, the cross move greedy will miss.
+ Masks 010 and 100 also call worker 1: their offers, 100 + 2 =
  102 and 100 + 50 = 150, lose where they meet the cheaper
  parents.
+ The full mask fills from the three two-bit states: 51 + 80 =
  131, 61 + 40 = 101, 150 + 3 = 153, and best[111] keeps 101.
+ The 101 road is the cross assignment, worker 1 on task 2 and
  worker 2 on task 1, and the brute-forced 3 by 3 case agrees
  exactly.

#diagram([the sweep over the eight masks, best costs landing in numeric order, the winning road 000 to 001 to 101 to 111 shaded], length: 13pt, {
  let masks = ([000], [001], [010], [011], [100], [101], [110], [111])
  let best = (0, 1, 100, 51, 100, 61, 150, 101)
  let path = (0, 1, 5, 7)
  for (i, m) in masks.enumerate() {
    let x = 0.8 + i * 2.4
    cdraw.rect((x, 4.6), (x + 2.1, 6.0), fill: if i in path { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.05, 5.5), m, size: 6pt)
    cdraw.content((x + 1.05, 4.95), [#best.at(i)], size: 6.5pt)
    if i < 7 { cdraw.line((x + 2.15, 5.3), (x + 2.35, 5.3), stroke: luma(220)) }
  }
  for k in range(3) {
    let x0 = 0.8 + path.at(k) * 2.4 + 1.05
    let x1 = 0.8 + path.at(k + 1) * 2.4 + 1.05
    cdraw.line((x0, 6.3), (x1, 6.3), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((8.4, 7.2), [the shaded road: 1 + 60 + 40 = 101], size: 6pt)
  cdraw.content((0.8, 3.5), [popcount of the mask picks the worker], size: 6pt)
  cdraw.content((0.8, 2.5), [greedy row by row collects 131], size: 6pt)
  cdraw.content((0.8, 1.5), [2^n states, n transitions each], size: 6pt)
  cdraw.content((0.8, 0.5), [the brute force agrees at n = 3], size: 6pt)
})

The 101 against greedy's 131 is the pinned spread, and the listings
below sweep the subsets six ways.

#listing("dsa/samples/src/Ch17/Dp.cs", first: 170, last: 197, caption: [assignment over subsets, popcount picks the worker])

The state is which tasks are done, and popcount of the mask says
which worker places next. Twelve workers is four thousand ninety-six
states times twelve transitions, while brute force over permutations
is four hundred seventy-nine million, and the test brute-forces the
three by three case to confirm exact agreement. Exactness ends at
the width of the mask: past about twenty tasks the table stops
fitting memory, and #xref-to("dsa", "approximation") picks up with
provable ratios in place of exact answers.

#listing("dsa/samples-c/src/Ch17/assignment.c", first: 22, last: 57, caption: [c, popcount by hand, the mask sweep with rows and attempts metered])

#listing("dsa/samples-go/ch17/assignment.go", first: 10, last: 60, caption: [go, popcount and the sweep, relaxations counted before the bit test])

#listing("dsa/samples-js/src/ch17-assignment.mjs", first: 1, last: 26, caption: [javascript, the worker counted by a bit loop, Infinity for unreachable])

#listing("dsa/samples-py/src/Ch17/assignment.py", first: 16, last: 38, caption: [python, bit_count names the worker, None for unreachable masks])

#listing("dsa/samples-lua/ch17_assignment.lua", first: 6, last: 41, caption: [lua, popcount by hand, nil marks the unreachable masks])

Measured across the suites: the optimum 101 with greedy at 131 and
the 4 by 4 at 10 pin in all six, every sibling cross-checking the
table against a brute-force walk over permutations. The meters agree
on the rows, every reachable mask touched, and on the attempts, 24
at n = 3 in C, Go, JavaScript, and Python where the bump lands once
per (mask, task) pair, Lua counting only evaluated free bits for 12.
Popcount comes from BitOperations in C\#, bit_count in Python, and a
hand-rolled bit loop in the other four.

#diagram([the subset lattice as the state space, the mask is which tasks are done, popcount picks the next worker], length: 13pt, {
  // the n = 3 lattice, every edge adds one task bit
  cdraw.content((6.0, 8.2), [the subset lattice, n = 3], size: 6.5pt)
  let node = (pos, v) => {
    cdraw.rect((pos.at(0) - 0.45, pos.at(1) - 0.25), (pos.at(0) + 0.45, pos.at(1) + 0.25), fill: luma(235), radius: 0.02)
    cdraw.content(pos, [#v], size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(220))
  e((5.5, 7.15), (2.2, 6.35))
  e((5.5, 7.15), (5.5, 6.35))
  e((5.5, 7.15), (8.8, 6.35))
  e((2.2, 5.85), (3.85, 5.05))
  e((2.2, 5.85), (6.5, 5.05))
  e((5.5, 5.85), (3.85, 5.05))
  e((5.5, 5.85), (8.0, 5.05))
  e((8.8, 5.85), (6.5, 5.05))
  e((8.8, 5.85), (8.0, 5.05))
  e((3.85, 4.55), (6.0, 3.75))
  e((6.5, 4.55), (6.0, 3.75))
  e((8.0, 4.55), (6.0, 3.75))
  node((5.5, 7.4), [000])
  node((2.2, 6.1), [100])
  node((5.5, 6.1), [010])
  node((8.8, 6.1), [001])
  node((3.85, 4.8), [110])
  node((6.5, 4.8), [101])
  node((8.0, 4.8), [011])
  node((6.0, 3.5), [111])
  cdraw.content((11.2, 7.4), [0], size: 6pt)
  cdraw.content((11.2, 6.1), [1], size: 6pt)
  cdraw.content((11.2, 4.8), [2], size: 6pt)
  cdraw.content((11.2, 3.5), [3], size: 6pt)
  cdraw.content((11.2, 2.7), [bits set], size: 6pt)

  cdraw.content((17.5, 7.2), [the mask is which tasks are done], size: 6pt)
  cdraw.content((17.5, 6.1), [popcount picks the next worker], size: 6pt)
  cdraw.content((17.5, 5.0), [each edge adds one task bit], size: 6pt)
  cdraw.content((17.5, 3.9), [2^n states times n transitions], size: 6pt)
  cdraw.content((17.5, 2.8), [n = 12: 4096 x 12 states], size: 6pt)
  cdraw.content((17.5, 1.7), [against 479 million permutations], size: 6pt)
  cdraw.content((17.5, 0.6), [exact agreement brute forced at n = 3], size: 6pt)
})

== across the six languages

The build sizes count non-comment source lines. The first table
covers the chapter's original featured files, the C\# row counting
`Dp.cs` plus the lis section of the chapter 19 file where its tails
build lives:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [343], [libc only], [memo arrays sized 64, fib(50) in long long, ladder and fib cross-tied],
  [c\#], [231], [bcl only], [Dictionary memo, BitOperations.PopCount for the subset dp, unreachable coins read minus one],
  [go], [232], [slices], [slices.BinarySearch inside lis tails, map memo counting real evaluations only],
  [javascript], [132], [node stdlib], [fib(78) = 8944394323798636 is the last exact Number, stated at the top of the memo file],
  [python], [299], [stdlib only], [dict memo by hand, functools.cache named as the counterpart, brute cross-checks in three files],
  [lua], [346], [lib.lua harness], [two-row edit distance never builds the table, integer midpoint search, mask brute force],
)

The assignment sweep lands as its own file in the five sibling
trees, the C\# build staying inside the chapter's one Dp.cs:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [115], [libc only], [popcount by hand, rows and attempts through out parameters, a next-permutation oracle and greedy contrast in the same file],
  [c\#], [26], [bcl only], [AssignmentCost inside Dp.cs, BitOperations.PopCount, the MaxValue guard skips dead masks],
  [go], [62], [slices], [the meter behind a pointer, relaxations counted before the bit test, greedy rows beside it],
  [javascript], [21], [node stdlib], [the worker counted by a bit loop, Infinity for unreachable, an optional meter object],
  [python], [73], [stdlib only], [None for unreachable masks, bit_count names the worker, permutation oracle and greedy rows in the checks],
  [lua], [111], [lib.lua harness], [nil marks unreachable, the relax meter bumps on free bits only, a factorial-walk oracle],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>` used by the
memo, `BitOperations.PopCount`, `Array.Fill`, accessed 2026-09-08,
go.dev/pkg/slices for `BinarySearch`, accessed 2026-09-14. Sample
behavior verified by `make verify-csharp`, 12 tests in chapter 17 of
the samples suite. The six-language layer verifies the same way: 7 C
programs with 97 embedded checks under `make verify-c`, 26 Go tests,
22 `node --test` cases, 76 Python checks across 7 files, and 32 Lua
checks under `run.lua`.
