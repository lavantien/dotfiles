#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= dynamic programming ii

Five dp shapes that buy asymptotic speedups by exploiting structure
the plain table ignores. Divide and conquer dp replaces a quadratic
per-layer scan with a recursion whose optimum windows narrow,
Knuth's optimization shrinks interval dp root searches to amortized
constant, broken profile walks grid columns as bitmasks, slope trick
keeps convex cost functions as lazily-shifted heaps of breakpoints,
and value iteration solves markov decision processes by repeated
sweeps to the fixed point. The chapter's applications run through
the icpc book: a 2017 staircase search, a 2022 heap-of-offers sweep,
and a 2023 expected-rolls mdp.

== divide and conquer dp

The layered partition dp: cut weights 4, 2, 7, 1, 5, 3 into exactly k
non-empty consecutive segments minimizing the sum of squared segment
sums plus 20 per segment. Layer k is computed from layer k-1, and
the naive transition scans every split point for every position,
O(k n^2) total. The cost function, a squared prefix-sum difference
plus a constant, satisfies the quadrangle inequality, so the optimum
split index is monotone in the position: the best j for position mid
lies between the best j of the left half and the best j of the right
half. The recursion rec(lo, hi, optl, optr) evaluates candidates for
the midpoint only inside that inherited window, writes dp\[k\]\[mid\],
then hands each half its narrowed window.

The dry run: the fixture is the cut weights 4, 2, 7, 1, 5, 3 at 20
per segment, asserted by the C\# suite with the same layers and
optima pinned in the C and Python suites.

+ The prefix sums fold 4, 4 + 2 = 6, 6 + 7 = 13, 13 + 1 = 14,
  14 + 5 = 19, 19 + 3 = 22.
+ k = 1 takes the whole run as one segment: 22 squared plus 20 =
  504.
+ k = 2 splits after the 7: layer 1's 189 for the 4, 2, 7 plus the
  tail's 81 plus 20 lands 189 + 81 + 20 = 290 over segments 4, 2,
  7 and 1, 5, 3.
+ k = 3 splits 4, 2 | 7, 1 | 5, 3: the segment sums read 6, 8, 8,
  so 36 + 64 + 64 = 164 plus 3 × 20 = 60 closes at 224.
+ The brute enumeration of cut masks agrees on all three, and the
  meter reads 39 candidate evaluations against the full scan's 45.

#diagram([the three optimal segmentations one row per k, groups boxed with their totals beside, the k = 3 row shaded cheapest], length: 13pt, {
  let a = (4, 2, 7, 1, 5, 3)
  for i in range(6) {
    cdraw.content((1.8 + i * 1.9 + 0.95, 7.5), [#i], size: 6pt)
  }
  let rows = (
    ([k = 1], (((0, 5)),), [504], false),
    ([k = 2], (((0, 2)), ((3, 5))), [290], false),
    ([k = 3], (((0, 1)), ((2, 3)), ((4, 5))), [224], true),
  )
  for (r, row) in rows.enumerate() {
    let (lab, groups, cost, hot) = row
    let y = 6.4 - r * 1.3
    cdraw.content((0.7, y), lab, size: 6pt)
    for g in groups {
      for i in g {
        let x = 1.8 + i * 1.9
        cdraw.rect((x, y - 0.35), (x + 1.9, y + 0.35), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
        cdraw.content((x + 0.95, y), [#a.at(i)], size: 6.5pt)
      }
    }
    cdraw.content((14.4, y), cost, size: 6pt)
    if hot { cdraw.content((14.4, y - 0.7), [cheapest], size: 6pt) }
  }
  cdraw.content((16.8, 6.4), [windows inherit and narrow], size: 6pt)
  cdraw.content((16.8, 5.3), [39 evaluations vs 45], size: 6pt)
  cdraw.content((16.8, 4.2), [brute cut masks agree], size: 6pt)
  cdraw.content((16.8, 3.1), [O(k n log n) over O(k n^2)], size: 6pt)
})

The 224 closes the ladder at 39 evaluations against 45, and the
listings below fill the layers in six languages.

#listing("dsa/samples-c/src/Ch32/dncdp.c", first: 34, last: 55, caption: [c, the recursion: midpoint scan inside the inherited window, halves narrowed by bestj])
#listing("dsa/samples/src/Ch32/DncDp.cs", first: 37, last: 61, caption: [c\#, the recursion as a local function over the two layer arrays])
#listing("dsa/samples-go/ch32/dncdp.go", first: 42, last: 68, caption: [go, the closure recursion, infeasible candidates skipped])
#listing("dsa/samples-js/src/ch32-dncdp.mjs", first: 67, last: 90, caption: [javascript, the recursion, the last segment j to mid-1])
#listing("dsa/samples-py/src/Ch32/dncdp.py", first: 32, last: 53, caption: [python, the recursion and the per-layer entry call])
#listing("dsa/samples-lua/ch32_dncdp.lua", first: 56, last: 73, caption: [lua, the recursion, 1-based elements threaded through the window])

The layer table pins the whole computation: layer 1 reads 36, 56,
189, 216, 381, 504 over the first i elements, layer 2 reads
infeasible, 60, 125, 140, 245, 290, layer 3 reads infeasible,
infeasible, 129, 144, 181, 224. The optima land at k = 1 cost 504,
the whole array as 22 squared plus 20, k = 2 cost 290 with segments
4, 2, 7 and 1, 5, 3, and k = 3 cost 224, every k matched against a
brute enumeration of all cut masks. The meter is the point: 39
candidate evaluations across three layers against 45 for the full
scan, 15 per layer. The edges cover k = n, all singles, k = 1, and
the k past n layers staying infeasible. The application is icpc
world finals 2017 problem D (book 9, chapter 8), money for nothing:
after pruning producers and consumers to staircases, the best
consumer index for the middle producer is found by exactly this
monotone-optimum divide and conquer at O((m+n) log n).

#diagram([layer 2's divide tree over the six positions with the optimum windows narrowing, 39 candidate evaluations against the full scan's 45], length: 13pt, {
  // positions 1..6, the mid-first recursion with windows
  let rows = (
    ([call 1], [lo 2 hi 6], [j in 1..3], [evals 3]),
    ([left], [lo 2 hi 2], [j in 1..1], [evals 1]),
    ([right], [lo 4 hi 6], [j in 3..3], [evals 1]),
    ([right-right], [lo 5 hi 6], [j in 3..4], [evals 2]),
  )
  for (r, row) in rows.enumerate() {
    let y = 7.4 - r * 1.15
    let (tag, span, win, cnt) = row
    cdraw.rect((1.6, y - 0.35), (4.4, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((3.0, y), span, size: 6.5pt)
    cdraw.content((0.4, y), tag, size: 6pt)
    cdraw.rect((5.0, y - 0.35), (7.6, y + 0.35), fill: luma(240), radius: 0.02)
    cdraw.content((6.3, y), win, size: 6.5pt)
    cdraw.content((8.2, y), cnt, size: 6.5pt)
  }
  cdraw.content((3.0, 8.4), [position range], size: 6pt)
  cdraw.content((6.3, 8.4), [candidate window], size: 6pt)
  // the layer 2 row: -, 60, 125, 140, 245, 290
  let vals = ([--], [60], [125], [140], [245], [290])
  for (i, v) in vals.enumerate() {
    let x = 1.6 + i * 1.55
    cdraw.rect((x, 1.1), (x + 1.55, 2.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.775, 1.6), v, size: 6.5pt)
    cdraw.content((x + 0.775, 0.7), [#(i + 1)], size: 6pt)
  }
  cdraw.content((3.0, 2.6), [layer 2 over the first i elements], size: 6pt)
  cdraw.content((12.0, 7.4), [39 evaluations, 45 for full scans], size: 6pt)
  cdraw.content((12.0, 6.5), [windows inherit and narrow], size: 6pt)
  cdraw.content((12.0, 5.6), [quadrangle inequality is the license], size: 6pt)
  cdraw.content((12.0, 4.7), [O(k n log n) over O(k n^2)], size: 6pt)
  cdraw.content((12.0, 3.8), [k = 2 optimum 290: 4,2,7 + 1,5,3], size: 6pt)
})

== the knuth optimization

Optimal binary search tree over keys 1..n with access weights 4, 2,
6, 3, 5: dp over every key span, cost the sum of weights times
depth plus one, and the naive transition tries every root. Knuth's
observation is that the optimal root of a span moves monotonically
as the span grows, so the root search for span (i, j) consults only
root candidates between root\[i\]\[j-1\] and root\[i+1\]\[j\], the
optimal roots of the two spans one cell shorter. The conditions
behind it are the quadrangle inequality plus the monotonicity of
opt, and matrix chain multiplication is the other classic instance
of the same shape. The windows shrink the root search so hard that
each of the O(n^2) states pays O(1) amortized consultation.

The dry run: the fixture is the access weights 4, 2, 6, 3, 5,
asserted by the C\# suite with the same 39 and 18 in the C and
Python suites.

+ The length-1 spans root themselves, costs 4, 2, 6, 3, 5 on the
  diagonal.
+ Span (0,1) inherits the window \[0, 1\] from the two diagonal
  roots: root 0 pays 2 + 6 = 8, root 1 pays 4 + 6 = 10, root 0
  wins.
+ Span (0,2) inherits \[root(0,1), root(1,2)\] = \[0, 2\]: three
  candidates, root 2 pays 8 + 0 + 12 = 20 and wins.
+ The windows collapse as spans grow: (1,3) inherits \[2, 2\] and
  consults one root at 2 + 3 + 11 = 16, and both length-4 spans
  and the full span consult exactly one root each.
+ The full span (0,4) consults only root 2: left 8 + right 11 +
  20 = 39, the pinned cost against 42 brute shapes.
+ The meter: length 2 consults 8 candidates, length 3 consults 7,
  lengths 4 and 5 consult 2 + 1 = 3, so 8 + 7 + 2 + 1 = 18 against
  the full scans' 35.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*span length*], [*root windows*], [*consults*], [*running*]),
  [2], [0-1, 1-2, 2-3, 3-4], [8], [8],
  [3], [0-2, 2-2, 2-4], [7], [15],
  [4], [2-2, 2-2], [2], [17],
  [5], [2-2], [1], [18],
)

The full span pays one candidate for the pinned 39, and the
listings below fill the windows in six languages.

#listing("dsa/samples-c/src/Ch32/knuth.c", first: 38, last: 65, caption: [c, the length loop with the root window, candidates metered])
#listing("dsa/samples/src/Ch32/Knuth.cs", first: 32, last: 50, caption: [c\#, the window loop, the root table filled beside the cost])
#listing("dsa/samples-go/ch32/knuth.go", first: 21, last: 42, caption: [go, the diagonal and length loops, window from the root table])
#listing("dsa/samples-js/src/ch32-knuth.mjs", first: 19, last: 47, caption: [javascript, diagonal init then the length loop, r bounded by the two roots])
#listing("dsa/samples-py/src/Ch32/knuth.py", first: 26, last: 43, caption: [python, the length loop, the window range from the root table])
#listing("dsa/samples-lua/ch32_knuth.lua", first: 34, last: 53, caption: [lua, the length loop, the monotone window in one range])

The fixture weights give optimal cost 39, the weighted path length
with the root at depth 0, and the brute ground truth agrees by
enumerating all Catalan(5) = 42 shapes. The root table pins as rows
0, 0, 2, 2, 2, then infeasible, 1, 2, 2, 2, then 2, 2, 2, then 3, 4,
then 4, all 0-based key indices. The meter reads 18 root candidates
consulted against 35 for the full scans. The edges: n = 1 costs its
own weight 7, weights 1, 9 cost 11, four 3s cost 24, and 2, 8 cost
12, every one matched against the shape enumeration. No finals
problem in the corpus rides Knuth directly, so it stays a general
technique carried by its own ground truth.

#diagram([the dp grid over key spans with one cell's root window between the roots of the two shorter spans], length: 13pt, {
  // 5x5 upper triangle, cell (1,3) highlighted with its window r in [root(1,2), root(2,3)] = [2,2]
  for i in range(5) {
    for j in range(i, 5) {
      let x = 2.0 + j * 1.55
      let y = 7.6 - i * 1.15
      let hot = i == 1 and j == 3
      cdraw.rect((x, y - 0.42), (x + 1.55, y + 0.42), fill: if hot { luma(205) } else if i == 1 and j == 2 or i == 2 and j == 3 { luma(220) } else { luma(238) }, radius: 0.02)
      cdraw.content((x + 0.775, y), if i == j { [r#i] } else { [] }, size: 6pt)
    }
  }
  for i in range(5) {
    cdraw.content((1.4, 7.6 - i * 1.15), [i=#i], size: 6pt)
    cdraw.content((2.0 + i * 1.55 + 0.775, 8.5), [#i], size: 6pt)
  }
  cdraw.content((6.2, 9.2), [j across, i down, roots on the diagonal], size: 6pt)
  // the window arrows: cell (1,3) takes r between root(1,2) and root(2,3)
  cdraw.line((2.0 + 2 * 1.55 + 0.775, 7.6 - 1 * 1.15 - 0.5), (2.0 + 3 * 1.55 + 0.4, 7.6 - 1 * 1.15 + 0.35), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.line((2.0 + 3 * 1.55 + 0.775, 7.6 - 2 * 1.15 + 0.5), (2.0 + 3 * 1.55 + 0.4, 7.6 - 1 * 1.15 - 0.35), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((12.6, 7.6), [cell (1,3): r in \[2, 2\]], size: 6pt)
  cdraw.content((12.6, 6.7), [root(1,2) = 2, root(2,3) = 2], size: 6pt)
  cdraw.content((12.6, 5.8), [18 candidates vs 35 full], size: 6pt)
  cdraw.content((12.6, 4.9), [O(n^2) states, O(1) amortized cut], size: 6pt)
  cdraw.content((12.6, 4.0), [optimal cost 39, catalan 42 shapes], size: 6pt)
  cdraw.content((12.6, 3.1), [matrix chain rides the same shape], size: 6pt)
})

== broken profile and the largest zero submatrix

Two grid dps in one file. Broken profile counts domino tilings
column by column, carrying the mask of cells that protrude from the
previous column. The per-column transition fills row by row: a cell
already occupied by a protrusion is skipped, a free cell with a free
neighbor below takes a vertical domino, and otherwise a horizontal
domino protrudes into the next column's mask. Each column is one
sweep of this recursion over all reachable masks, and the tiling
count is the ways to return to the empty mask after the last
column. The largest zero submatrix is the second machine: per row,
maintain the histogram of consecutive zero heights, and take the
maximum rectangle via the monotonic stack, the next-greater scan of
#xref-to("dsa", "ranges") in its histogram role.

The dry run: the fixture is the 4 by 6 zero grid with rows 010000,
010010, 000010, 010010, asserted by the C\# suite at area 8, with
the domino ladder 2, 3, 5, 8 pinned beside it.

+ Row 0 reads 0,1,0,0,0,0: every open cell climbs to height 1 and
  the blocked cell resets, heights 1, 0, 1, 1, 1, 1, best 1 × 4 =
  4 across columns 2 to 5.
+ Row 1 reads 0,1,0,0,1,0: heights 2, 0, 2, 2, 0, 2, best 2 × 2 =
  4 at columns 2 and 3.
+ Row 2 reads 0,0,0,0,1,0: heights 3, 1, 3, 3, 0, 3, best 3 × 2 =
  6 at columns 2 and 3.
+ Row 3 reads 0,1,0,0,1,0: heights 4, 0, 4, 4, 0, 4, best 4 × 2 =
  8 at columns 2 and 3, rows 0 through 3.
+ The stack prices each row's histogram in one pass, and the sweep
  closes at the pinned 8.

#diagram([the histogram sweep one group per row, heights climbing until a 1 resets, the winning 4 by 2 rectangle outlined on the last group], length: 13pt, {
  let rows = (
    ([row 0], (1, 0, 1, 1, 1, 1), [best 4], false),
    ([row 1], (2, 0, 2, 2, 0, 2), [best 4], false),
    ([row 2], (3, 1, 3, 3, 0, 3), [best 6], false),
    ([row 3], (4, 0, 4, 4, 0, 4), [best 8], true),
  )
  for (r, row) in rows.enumerate() {
    let (lab, hs, best, hot) = row
    let x0 = 2.6 + r * 4.5
    cdraw.content((x0 + 1.86, 6.4), lab, size: 6pt)
    for (c, h) in hs.enumerate() {
      let x = x0 + c * 0.62
      if h > 0 {
        cdraw.rect((x, 6.2 - h * 0.32), (x + 0.62, 6.2), fill: luma(215), radius: 0.02)
      }
    }
    cdraw.content((x0 + 1.86, 4.35), best, size: 6pt)
    if hot {
      cdraw.rect((x0 + 2 * 0.62 - 0.05, 6.2 - 4 * 0.32 - 0.05), (x0 + 4 * 0.62 + 0.05, 6.25), stroke: luma(60), radius: 0.02)
    }
  }
  cdraw.content((21.4, 6.0), [heights climb or reset], size: 6pt)
  cdraw.content((21.4, 5.1), [the stack prices a row in one pass], size: 6pt)
  cdraw.content((21.4, 4.2), [8 = 4 × 2 at columns 2, 3], size: 6pt)
  cdraw.content((21.4, 3.3), [2 by n tilings: 2, 3, 5, 8], size: 6pt)
})

The sweep closes at the pinned 8 over all four rows, and the
listings below carry both machines in six languages.

#listing("dsa/samples-c/src/Ch32/brokenprofile.c", first: 27, last: 55, caption: [c, the fill recursion, vertical pairs or horizontal protrusions])
#listing("dsa/samples/src/Ch32/BrokenProfile.cs", first: 44, last: 77, caption: [c\#, the histogram stack half, the fill recursion above it])
#listing("dsa/samples-go/ch32/brokenprofile.go", first: 7, last: 37, caption: [go, the fill recursion inside the column loop])
#listing("dsa/samples-js/src/ch32-brokenprofile.mjs", first: 9, last: 34, caption: [javascript, the fill over map-keyed mask counts])
#listing("dsa/samples-py/src/Ch32/brokenprofile.py", first: 14, last: 35, caption: [python, the fill recursion, dict masks])
#listing("dsa/samples-lua/ch32_brokenprofile.lua", first: 8, last: 32, caption: [lua, the fill, protrusions carried as bits])

The tiling family pins the doubling: 2 by 2 gives 2, 2 by 3 gives
3, 2 by 4 gives 5, 2 by 5 gives 8, the fibonacci cross-check, 3 by 3
gives 0, 3 by 4 gives 11, 4 by 4 gives 36, and the 1-row grids give
1 and 0. The submatrix family runs the 4 by 6 grid with rows 010000,
010010, 000010, 010010 and finds area 8 at columns 2 and 3, all four
rows. The edges: an all-ones 2 by 2 gives 0, an all-zeros 2 by 2
gives the whole grid at 4, a single row 0, 1, 0, 0 gives 2 at
columns 2 and 3, and the reference cross-checked 300 random grids
against brute-force rectangles. Tiling runs O(n 2^m) and the
submatrix O(rows times cols). The counting cousin, the
tiling-tiles style sweep of icpc world finals 2023 problem F
(book 9, chapter 12), stays in the icpc book.

#diagram([the 3 by 4 grid mid-sweep with its protrusion mask, beside the 4 by 6 zero matrix as height bars with the 8-cell rectangle shaded], length: 13pt, {
  // left: 3x4 grid, column 1 filling: incoming mask 100 (row 0 protrudes),
  // column 0 placed a horizontal at row 0 and a vertical at rows 1-2
  for r in range(3) {
    for c in range(4) {
      let x = 1.6 + c * 1.3
      let y = 6.9 - r * 0.85
      let fill = luma(240)
      if c == 0 { fill = luma(200) }
      if c == 1 and r == 0 { fill = luma(215) }
      if c == 1 and (r == 1 or r == 2) { fill = luma(200) }
      cdraw.rect((x, y), (x + 1.3, y + 0.85), fill: fill, radius: 0.02)
    }
  }
  cdraw.line((1.6 + 0 * 1.3 + 0.65, 6.9 - 0 * 0.85 + 0.42), (1.6 + 1 * 1.3 + 0.65, 6.9 - 0 * 0.85 + 0.42), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.line((1.6 + 0 * 1.3 + 0.65, 6.9 - 1 * 0.85 - 0.42), (1.6 + 0 * 1.3 + 0.65, 6.9 - 2 * 0.85 + 0.42), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.line((1.6 + 1 * 1.3 + 0.65, 6.9 - 1 * 0.85 - 0.42), (1.6 + 1 * 1.3 + 0.65, 6.9 - 2 * 0.85 + 0.42), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.content((4.2, 8.6), [3x4 grid, column 1 filling], size: 6.5pt)
  cdraw.content((4.2, 8.05), [dark: placed, mid tone: protrudes from column 0], size: 6pt)
  cdraw.content((4.2, 4.5), [incoming mask 0b100, vertical closes rows 1-2], size: 6pt)
  cdraw.content((4.2, 3.8), [3x4 tilings: 11], size: 6pt)
  // right: 4x6 zero matrix heights and the rectangle
  let g = ((0, 1, 0, 0, 0, 0), (0, 1, 0, 0, 1, 0), (0, 0, 0, 0, 1, 0), (0, 1, 0, 0, 1, 0))
  for (r, row) in g.enumerate() {
    for (c, v) in row.enumerate() {
      let hot = c == 2 or c == 3
      cdraw.rect((9.0 + c * 1.15, 6.9 - r * 0.85), (10.15 + c * 1.15, 7.75 - r * 0.85),
        fill: if v == 1 { luma(120) } else if hot { luma(205) } else { luma(240) }, radius: 0.02)
    }
  }
  // height bars under the grid
  let hts = (0, 4, 4, 4, 1, 0)
  for (c, h) in hts.enumerate() {
    cdraw.rect((9.0 + c * 1.15, 3.4 - h * 0.4), (10.15 + c * 1.15, 3.4), fill: luma(215), radius: 0.02)
    cdraw.content((9.0 + c * 1.15 + 0.575, 3.75), [#h], size: 6pt)
  }
  cdraw.content((13.0, 8.6), [heights per column, last row], size: 6.5pt)
  cdraw.rect((9.0 + 2 * 1.15 - 0.05, 3.4 - 4 * 0.4 - 0.05), (10.15 + 3 * 1.15 + 0.05, 3.4 + 0.05), stroke: luma(60), radius: 0.02)
  cdraw.content((17.0, 3.4), [max rectangle 4 x 2 = 8], size: 6pt)
  cdraw.content((17.0, 2.6), [columns 2..3, rows 0..3], size: 6pt)
  cdraw.content((17.0, 1.8), [monotonic stack pops the answer], size: 6pt)
  cdraw.content((17.0, 1.0), [O(n 2^m) tilings, O(rows cols) rectangle], size: 6pt)
})

== slope trick

The convex dp family, solved as heaps. Start with the two-heap
median oracle: 3, 1, 4, 1, 5, 9, 2, 6 has lower median 3 and
absolute-deviation cost 17. The real machine is the
make-non-decreasing dp: keep a max-heap of the left-branch
breakpoints of a convex piecewise-linear cost function, push each x,
and when the top exceeds x pay top minus x, pop and repush x. The
payment is the slope trick: the repush is the lazy right-shift of
every breakpoint above x, applied by one heap operation instead of a
rebuild. Strictly increasing goes through the index shift z~i~ = a~i~
- i, a whole-branch translate applied outside the heap.

The dry run: the fixture is 3, 2, 5, 1, asserted by the C\# suite
at cost 5 with the final multiset 2, 2, 1, 1 and the shift trace
0, 1, 0, 4.

+ x = 3 pushes and the top equals it: no crossing, no payment,
  running 0.
+ x = 2: the pushed top reads 3, a crossing: pay 3 - 2 = 1, pop
  it, repush 2, and the heap holds 2, 2 at running 1.
+ x = 5: the top reads 5 and does not cross: heap 5, 2, 2, running
  still 1.
+ x = 1: the top 5 crosses by 4: pay 5 - 1 = 4, pop, repush 1, and
  the heap closes at 2, 2, 1, 1, running 5.
+ Every payment is the cost function's minimum rising: the running
  answers read 0, 1, 1, 5, the pinned trace.
+ Strictly increasing runs the same loop over z = 3, 1, 3, -2 and
  pays 7.

#diagram([the running cost function after each element, the heap's breakpoints as dots, the flat minimum shaded, its value rising 0, 1, 1, 5], length: 13pt, {
  let ex = (v) => 2.6 + v * 1.5
  let strips = (
    ([after 3], (3,), (3, 3), 0),
    ([after 2], (2, 2), (2, 3), 1),
    ([after 5], (2, 2), (2, 3), 1),
    ([after 1], (1, 1, 2, 2), (2, 5), 5),
  )
  for (r, s) in strips.enumerate() {
    let (lab, left, plat, minv) = s
    let y = 7.2 - r * 1.7
    cdraw.content((1.2, y), lab, size: 6pt)
    cdraw.line((ex(0), y), (ex(6), y), stroke: luma(170))
    let px0 = ex(plat.at(0))
    let px1 = calc.max(ex(plat.at(1)), px0 + 0.2)
    cdraw.rect((px0, y - 0.16), (px1, y + 0.16), fill: luma(205), radius: 0.02)
    for v in left {
      cdraw.circle((ex(v), y), radius: 0.09, fill: luma(60))
    }
    cdraw.content((12.4, y), [min #minv], size: 6pt)
    if r == 0 {
      for v in range(7) {
        cdraw.content((ex(v), y + 0.55), [#v], size: 5.5pt)
      }
    }
  }
  cdraw.content((15.0, 7.2), [dots: the heap's breakpoints], size: 6pt)
  cdraw.content((15.0, 6.2), [pay, pop, repush: one op], size: 6pt)
  cdraw.content((15.0, 5.2), [the plateau is the min region], size: 6pt)
  cdraw.content((15.0, 4.2), [O(n log n) all in], size: 6pt)
})

The trace closes at the pinned pair, cost 5 and heap 2, 2, 1, 1,
and the listings below pay the crossings in six languages.

#listing("dsa/samples-c/src/Ch32/slopetrick.c", first: 84, last: 105, caption: [c, the one-heap loop, the payment and the lazy repush])
#listing("dsa/samples/src/Ch32/SlopeTrick.cs", first: 23, last: 41, caption: [c\#, the payment loop over a PriorityQueue as a negated max-heap])
#listing("dsa/samples-go/ch32/slopetrick.go", first: 80, last: 92, caption: [go, slopeRun, the heap.Push and Pop pair at the crossing])
#listing("dsa/samples-js/src/ch32-slopetrick.mjs", first: 71, last: 85, caption: [javascript, the loop over the MaxHeap class])
#listing("dsa/samples-py/src/Ch32/slopetrick.py", first: 23, last: 35, caption: [python, the max-heap by negation, the repush after the payment])
#listing("dsa/samples-lua/ch32_slopetrick.lua", first: 58, last: 76, caption: [lua, the loop with the trace table, the shift recorded per element])

The fixtures pin the whole ladder. Non-decreasing on 3, 2, 5, 1
costs 5 and leaves the heap descending 1, 1, 2, 2, with the
per-element trace paying shifts 0, 1, 0, 4 for running answers 0, 1,
1, 5. The 5, 4, 3, 2, 1 descending run costs 6, already-sorted input
costs 0, the single element costs 0, 10, 1, 1 costs 9, and 4, 4, 8,
2 costs 6. Strictly increasing through z maps 3, 2, 5, 1 to 3, 1, 3,
-2 and costs 7, holds 5, 5, 5 at 2 through z 5, 4, 3, and 1, 1, 1
at 2. The reference cross-checked 400 random instances against an
independent dp ground truth for both variants. The kin application
is icpc world finals 2022 problem S (book 9, chapter 11), bridging
the gap: its judge-green engine is a pull-based dp row sweep whose
offers live in lazily-shifted window heaps, the same lazy-offset
heap idiom, kin to the classic objective rather than an instance of
it.

#diagram([the breakpoint multiset growing over the 3, 2, 5, 1 trace with the shift payments shaded, the convex cost accumulating kinks], length: 13pt, {
  // four stages of the heap (descending) with the payment marked
  let stages = (
    ([x = 3], (3,), 0, 0),
    ([x = 2], (3, 2), 1, 1),
    ([x = 5], (5, 3, 2), 0, 1),
    ([x = 1], (3, 2, 1, 1), 4, 5),
  )
  for (s, stage) in stages.enumerate() {
    let (label, heap, shift, run) = stage
    let x0 = 1.6 + s * 4.0
    cdraw.content((x0 + 1.6, 7.6), label, size: 6.5pt)
    for (j, v) in heap.enumerate() {
      cdraw.rect((x0 + j * 0.75, 6.9 - j * 0.75 - 0.3), (x0 + j * 0.75 + 0.75, 6.9 - j * 0.75 + 0.3), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + j * 0.75 + 0.375, 6.9 - j * 0.75), [#v], size: 6.5pt)
    }
    cdraw.content((x0 + 1.6, 3.9), [running #run], size: 6pt)
    if shift > 0 {
      cdraw.rect((x0, 4.35), (x0 + 3.2, 4.85), fill: luma(215), radius: 0.02)
      cdraw.content((x0 + 1.6, 4.6), [shift +#shift], size: 6pt)
    }
  }
  cdraw.content((9.0, 2.6), [the top crosses x: pay top - x, repush x], size: 6pt)
  cdraw.content((9.0, 1.8), [one heap op shifts every breakpoint above x], size: 6pt)
  cdraw.content((9.0, 1.0), [heap desc: 1, 1, 2, 2 at the end], size: 6pt)
  cdraw.content((9.0, 0.2), [strict: z~i~ = a~i~ - i outside the heap], size: 6pt)
  cdraw.content((9.0, -0.6), [O(n log n)], size: 6pt)
})

== value iteration and mdps

A markov decision process on a ladder: states 1 through 5, goal 6
absorbing at cost 0, and two actions per state, walk at cost 1
deterministically to s+1, or gamble at cost 1 with half probability
to min(s+2, 6) and half a fall back to state 2. Value iteration
fixes the bellman equations by Gauss-Seidel sweeps, updating states
in place ascending so each state reads the freshest values below
it, until the maximum delta falls under 1e-13 or the iteration cap.
The contraction guarantees geometric convergence, and the exact
fixed point is confirmed by fraction-arithmetic iteration in the
reference.

The dry run: the fixture is the 5-state ladder with goal 6,
asserted by the C\# suite at V = 4.5, 4, 3, 2, 1.

+ Every value starts at 0. Sweep 1 reads only zeros: each walk
  costs 1 + 0 = 1, and the ladder lands all 1.
+ Sweep 2 climbs the same way: 2, 2, 2, 2, 1.
+ Sweep 3: 3, 3, 3, 2, 1.
+ Sweep 4: 4, 4, 3, 2, 1, state 1 tying at 1 + 3 = 4.
+ Sweep 5 breaks the tie at state 1: the gamble pays 1 + 0.5 × 3 +
  0.5 × 4 = 4.5 under the walk's 1 + 4 = 5, and the sweep closes
  at 4.5, 4, 3, 2, 1.
+ The next sweep reproduces every value, the fixed point, and the
  die mini converges to 6 exactly.

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*sweep*], [*V(1)*], [*V(2)*], [*V(3)*], [*V(4)*], [*V(5)*], [*reads*]),
  [1], [1], [1], [1], [1], [1], [all walks],
  [2], [2], [2], [2], [2], [1], [],
  [3], [3], [3], [3], [2], [1], [],
  [4], [4], [4], [3], [2], [1], [state 1 ties],
  [5], [4.5], [4], [3], [2], [1], [the gamble wins at 1],
)

The fifth sweep lands the pinned 4.5, 4, 3, 2, 1 and the sixth
changes nothing, and the listings below sweep the ladder in six
languages.

#listing("dsa/samples-c/src/Ch32/valueiter.c", first: 24, last: 40, caption: [c, one gauss-seidel sweep ascending, the max delta returned])
#listing("dsa/samples/src/Ch32/ValueIter.cs", first: 15, last: 44, caption: [c\#, the generic sweep over an action table, walk and gamble supplied as data])
#listing("dsa/samples-go/ch32/valueiter.go", first: 12, last: 37, caption: [go, the ladder sweep, gamble falling to state 2])
#listing("dsa/samples-js/src/ch32-valueiter.mjs", first: 57, last: 89, caption: [javascript, the table-driven sweep returning values and actions])
#listing("dsa/samples-py/src/Ch32/valueiter.py", first: 18, last: 36, caption: [python, the sweep and its delta, states ascending])
#listing("dsa/samples-lua/ch32_valueiter.lua", first: 9, last: 28, caption: [lua, the sweep, values kept in a 1-based table])

The ladder values pin at V(1..5) = 4.5, 4.0, 3.0, 2.0, 1.0 with
doubles asserted at 1e-9: gambling is strictly better at state 1,
4.5 against walking's 5, walk and gamble tie at state 2, and walking
wins at 3, 4, and 5. The family deliberately pins no policy label at
the state-2 tie and no sweep count, both float-noise sensitive
across languages, only the values, the strict orderings, and one
ordering that is not: the deterministic variant, walk or leap to
min(s+3, 6), solved by backward dijkstra over predecessors with
(dist, vertex) heap order, gives d(1..5) = 2, 2, 1, 1, 1 and the pop
order 6, 3, 4, 5, 1, 2. The geometric member is the die mini, one
state rolling toward the goal at one sixth: V converges to exactly
6. The edges cover a goal-only mdp at 0, an unreachable state
keeping its initialized 0 by stated convention, and a state whose
every action leads to the goal. The application is icpc world
finals 2023 problem K (book 9, chapter 12), alea iacta est: the
7^d expected-rolls mdp solved by value iteration, the approach
every contest team used where the editorial ran the backward
dijkstra of #xref-to("dsa", "shortestpaths").

#diagram([the ladder with walk and gamble edges and the fixed-point values, beside the die loop whose geometric series sums to 6], length: 13pt, {
  // the ladder 1..5 with goal 6
  for s in range(1, 7) {
    let x = 1.6 + s * 2.2
    cdraw.circle((x, 5.6), radius: 0.34, fill: if s == 6 { luma(200) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, 5.6), [#s], size: 7pt)
    let vs = (4.5, 4.0, 3.0, 2.0, 1.0, 0)
    cdraw.content((x, 4.6), [#vs.at(s - 1)], size: 6.5pt)
  }
  for s in range(1, 6) {
    let x = 1.6 + s * 2.2
    cdraw.line((x + 0.36, 5.6), (x + 2.2 - 0.36, 5.6), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x + 1.1, 6.0), [walk 1], size: 5.5pt)
  }
  // the gamble pair drawn from state 1 only, to keep the fan legible
  let s1 = 1.6 + 1 * 2.2
  cdraw.line((s1, 5.24), (1.6 + 3 * 2.2, 4.55), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.line((s1, 5.24), (1.6 + 2 * 2.2, 4.55), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((4.6, 4.25), [half up], size: 5.5pt)
  cdraw.content((5.6, 4.85), [half to 2], size: 5.5pt)
  cdraw.content((7.0, 7.4), [gamble 1 from every state: half to min(s+2, 6), half to 2], size: 6pt)
  cdraw.content((7.0, 0.6), [goal absorbing at 0], size: 6pt)
  // the die loop
  cdraw.circle((13.4, 5.6), radius: 0.4, fill: luma(240), stroke: luma(120))
  cdraw.content((13.4, 5.6), [\*], size: 8pt)
  cdraw.circle((16.2, 5.6), radius: 0.4, fill: luma(200), stroke: luma(120))
  cdraw.content((16.2, 5.6), [goal], size: 6pt)
  cdraw.line((13.8, 5.75), (15.8, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.8, 6.15), [1/6], size: 6pt)
  cdraw.line((15.8, 5.45), (13.8, 5.45), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((14.8, 5.05), [5/6], size: 6pt)
  cdraw.content((14.8, 4.2), [V(\*) = 1 + 5/6 V(\*)], size: 6pt)
  cdraw.content((14.8, 3.4), [V(\*) = 6 exactly], size: 6pt)
  cdraw.content((14.8, 2.6), [geometric contraction per sweep], size: 6pt)
  cdraw.content((14.8, 1.8), [tolerance 1e-13, cap stated], size: 6pt)
})

== small-to-large merging

The last amortization is one sentence long and worth its own
section. Merging two sets always pours the smaller into the larger.
An element that migrates lands in a set at least twice as big as its
last home, so any element migrates at most log2 n times and n
elements migrate O(n log n) times total, against O(n^2) for merging
by always pouring into a fixed side. It is the same
amortized-doubling argument as the dynamic array growth of
#xref-to("dsa", "dynamicarrays"), applied to set membership instead
of capacity. The consumers are the standard trio: dsu component
lists, subtree queries that merge children into the heaviest first,
and heavy path bookkeeping in tree decompositions. The kin
application is icpc world finals 2025 problem E (book 9, chapter
13), delivery service, whose component-merge accounting runs on
exactly this lemma. No samples ship for it: the proof is the
doubling ladder below, and the tree structures that consume it
belong to later chapters.

The dry run: no suite carries this facet, so the example is
hand-derived over 8 elements.

+ Eight singletons merge pairwise under always-smaller-into-larger:
  4 merges each pour 1 element, 4 moves.
+ The 2-sets pair into 4-sets, each merge pouring 2: 2 + 2 = 4
  moves, and the two 4-sets pour once more for 4: the ladder spends
  4 + 4 + 4 = 12 moves.
+ One element's homes went 1, 2, 4, 8: it crossed 3 = log2 8
  times.
+ Pour the accumulated set into each new singleton instead and the
  same 8 elements cost 1 + 2 + 3 + 4 + 5 + 6 + 7 = 28 moves.
+ The bound reads 8 × log2 8 = 24 crossings, the ladder's 12 under
  it and the fixed side's 28 with no cover.

#diagram([the balanced merge tree with per-level pours on the left, the fixed-side spine's move ledger running to 28 on the right], length: 13pt, {
  // left: 8 leaves under three bracket levels, one pour count per level
  for i in range(8) {
    let x = 1.6 + i * 1.35
    cdraw.circle((x + 0.3, 0.8), radius: 0.13, fill: luma(240), stroke: luma(120))
  }
  let brk = (lo, hi, y) => {
    let x0 = 1.6 + lo * 1.35
    let x1 = 1.9 + hi * 1.35
    cdraw.line((x0, y), (x1, y), stroke: luma(120), mark: (start: "|", end: "|"))
  }
  for p in ((0, 1), (2, 3), (4, 5), (6, 7)) { brk(p.at(0), p.at(1), 2.0) }
  for p in ((0, 3), (4, 7)) { brk(p.at(0), p.at(1), 3.2) }
  brk(0, 7, 4.4)
  cdraw.content((10.6, 2.0), [4 pours × 1 = 4], size: 6pt)
  cdraw.content((10.6, 3.2), [2 pours × 2 = 4], size: 6pt)
  cdraw.content((10.6, 4.4), [1 pour × 4 = 4], size: 6pt)
  cdraw.content((9.6, 5.4), [total 12 = (n/2) log2 n], size: 6pt)
  // right: the fixed-side ledger
  cdraw.content((18.6, 5.4), [fixed side], size: 6.5pt)
  let ledger = ((2, 1, 1), (3, 2, 3), (4, 3, 6), (5, 4, 10), (6, 5, 15), (7, 6, 21), (8, 7, 28))
  for (r, row) in ledger.enumerate() {
    let (size, mv, run) = row
    let y = 4.5 - r * 0.55
    cdraw.content((16.4, y), [into size #size:], size: 6pt, anchor: "east")
    cdraw.content((17.2, y), [move #mv], size: 6pt)
    cdraw.content((19.4, y), [running #run], size: 6pt)
  }
  cdraw.content((17.8, 0.2), [1 + 2 + ... + 7 = 28], size: 6pt)
})

The 12 against 28 is the lemma in numbers, and the doubling ladder
below draws the per-element view.

#diagram([two sets with the smaller's elements migrating, and one element's home sizes doubling at every crossing], length: 13pt, {
  // left: set A (8 elements) and set B (3), B pours into A
  let ac = (2.6, 4.2, 5.8, 7.4, 9.0, 3.4, 6.6, 8.2)
  for x in ac {
    cdraw.circle((x, 6.6), radius: 0.26, fill: luma(240), stroke: luma(120))
  }
  cdraw.rect((1.8, 5.7), (10.0, 7.5), stroke: luma(120), radius: 0.6)
  cdraw.content((5.9, 8.1), [set A, 8 elements], size: 6.5pt)
  let bc = (17.6, 19.8, 21.0)
  for x in bc {
    cdraw.circle((x, 6.6), radius: 0.26, fill: luma(205), stroke: luma(120))
  }
  cdraw.rect((16.6, 5.7), (22.0, 7.5), stroke: luma(120), radius: 0.6)
  cdraw.content((19.3, 8.1), [set B, 3 elements], size: 6.5pt)
  for x in bc {
    cdraw.line((x, 6.3), (10.6, 5.6), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  }
  cdraw.content((13.5, 5.1), [always pour the smaller into the larger], size: 6pt)
  // the doubling ladder of one element's home sizes
  let homes = (1, 2, 4, 8, 16)
  for (i, h) in homes.enumerate() {
    let x = 2.0 + i * 2.6
    cdraw.rect((x, 2.6 - h * 0.12), (x + 2.0, 2.6), fill: luma(220), radius: 0.02)
    cdraw.content((x + 1.0, 2.9), [#h], size: 6pt)
    if i < 4 {
      cdraw.line((x + 2.0, 2.6 - h * 0.12 / 2), (x + 2.6, 2.6 - homes.at(i + 1) * 0.12 / 2), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((13.5, 1.6), [one element's home sizes], size: 6pt)
  cdraw.content((13.5, 0.9), [log2 n crossings each, O(n log n) total], size: 6pt)
  cdraw.content((13.5, 0.1), [the dynamic array's doubling, on members], size: 6pt)
})

== across the six languages

Featured build size counted as non-blank, non-comment lines of the
chapter's five sample files per language, embedded test scripts
included:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [605], [static tables, hand heaps], [double and fraction-free paths, fabs for the delta, pop order recorded from the selection loop],
  [c\#], [301], [priorityqueue, tuples, records], [the value iterator generic over an action table, walk and gamble supplied as data],
  [go], [416], [container/heap, math], [two heap types over one item shape, the die mini converging under 1e-13],
  [javascript], [367], [map tables, class heaps], [actions as plain objects, the sweep returning values and actions together],
  [python], [413], [heapq by negation, fractions in tests], [exact fixed point asserted from fraction iteration, ok-N print],
  [lua], [504], [tables, MaxHeap class], [1-based states, the trace tables returned for run.lua],
)

sources: cp-algorithms, "Divide and Conquer DP",
cp-algorithms.com/dynamic_programming/divide-and-conquer-dp.html,
"Knuth's Optimization",
cp-algorithms.com/dynamic_programming/knuth-optimization.html,
"Dynamic Programming on Broken Profile. Problem \"Parquet\"",
cp-algorithms.com/dynamic_programming/profile-dynamics.html, and
"Finding the largest zero submatrix",
cp-algorithms.com/dynamic_programming/zero_matrix.html, all accessed
2026-09-20, cc by-sa 4.0, our own words and code throughout. The
slope trick and value iteration sections have no cp-algorithms
article and stand as general techniques with their icpc applications
as sources: icpc world finals 2017 problem D (book 9, chapter 8),
2022 problem S (book 9, chapter 11), 2023 problem K (book 9,
chapter 12), and 2025 problem E (book 9, chapter 13) as the kin
clause of the last section. Sample behavior verified by the six
suite gates scoped to chapter 32: c 5 files and 129 checks, c\# 23
facts, go 19 test functions, javascript 18 tests and 66 asserts,
python 5 files and 72 asserts, lua 20 checks, zero skipped.
