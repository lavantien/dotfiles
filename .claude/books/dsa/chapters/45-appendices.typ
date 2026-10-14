#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": dsabook
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= appendices: topic matrix and sources

The topic matrix is this book's audit trail, and the overhaul made
it eight audit trails. Every structure and algorithm the chapters
build now exists once per language, built from scratch behind the
same fixtures and the same anchors, and every chapter listing reads
a real file that the pinned toolchain of its language compiles and
runs. The totals: c 232 files and 4372 checks, rust 232 files and
4342 checks, go 813 tests, java 232 files and 4485 checks, c\# 872
tests, javascript 860 tests, python 232 files and 3239 asserts, lua
1017 checks, and the c\#
capstone of chapter 44 stays single-language inside the same suite.
Zero skipped anywhere.

== topic coverage

#let unmapped = topics.filter(r => r.chapter == "unmapped").len()

#let chapter-label(id) = {
  let found = dsabook.chapters.find(c => c.id == id)
  [ch #found.num]
}

Every topic maps to a chapter: #unmapped unmapped. The bcl column
carries the honest boundary of the original c\# wave, several rows
say `n/a` because the .NET base class library genuinely ships no
counterpart, no deque, no skip list, no dijkstra, and knowing that
is as practical as knowing the ones it does ship.

#table(
  columns: (1.9fr, auto, 1.5fr, 1.4fr),
  inset: 4pt,
  table.header([*topic*], [*chapter*], [*cost*], [*bcl counterpart*]),
  ..topics.map(r => (
    [#r.topic],
    chapter-label(r.chapter),
    [#r.cost],
    [#r.bcl],
  )).flatten(),
)

#diagram([the matrix as one strip, one bar per chapter that carries matrix rows, height is topic count, dark is shipped], length: 13pt, {
  // (shipped, n/a) per chapter in manifest order, counted from the
  // table above: chapters 1 to 39, then 41 to 43, and the capstone
  let data = ((2, 0), (2, 0), (2, 0), (2, 1), (2, 2), (3, 1), (2, 1), (3, 2), (1, 2), (0, 5), (0, 6), (0, 4), (4, 2), (1, 4), (0, 5), (2, 4), (0, 7), (0, 5), (0, 6), (0, 4), (1, 5), (0, 4), (0, 4), (0, 4), (2, 2), (0, 3), (0, 3), (1, 7), (4, 2), (1, 3), (0, 7), (1, 5), (0, 5), (1, 5), (0, 13), (1, 5), (0, 11), (0, 9), (0, 11), (0, 12), (0, 11), (1, 7), (3, 6))
  let nums = (range(1, 40) + (41, 42, 43, 44))
  for (i, d) in data.enumerate() {
    let (shipped, na) = d
    let x = 0.8 + i * 0.52
    cdraw.rect((x, 3.4), (x + 0.4, 3.4 + shipped * 0.35), fill: luma(160), radius: 0.0)
    cdraw.rect((x, 3.4 + shipped * 0.35), (x + 0.4, 3.4 + (shipped + na) * 0.35), fill: luma(235), radius: 0.0)
    cdraw.content((x + 0.2, 2.85), [#nums.at(i)], size: 6pt)
  }
  cdraw.content((1.0, 1.9), [meters], size: 6pt)
  cdraw.content((1.6, 0.8), [memory], size: 6pt)
  cdraw.content((4.1, 1.9), [keyed], size: 6pt)
  cdraw.content((6.2, 0.8), [graphs], size: 6pt)
  cdraw.content((7.5, 1.9), [ordered], size: 6pt)
  cdraw.content((8.3, 0.8), [strings], size: 6pt)
  cdraw.content((9.8, 1.9), [dp], size: 6pt)
  cdraw.content((11.6, 0.8), [ranges], size: 6pt)
  cdraw.content((13.7, 1.9), [parsing], size: 6pt)
  cdraw.content((18.3, 1.9), [the advanced half, chapters 28 to 42], size: 6pt)
  cdraw.content((21.6, -0.3), [the capstone], size: 6pt)
  cdraw.content((12.0, -0.3), [the n/a column is the honest boundary of the book], size: 6pt)
})

== the eight sample trees

One row per sample program, 232 of them across chapters 1 to 43,
and the file that carries it in each language. The roots, relative
to the book directory: c in `dsa/samples-c/src/ChNN`, rust in
`dsa/samples-rust/src/ChNN`, go in
`dsa/samples-go/chNN`, java in `dsa/samples-java/src/ChNN`, c\# in
`dsa/samples/src/ChNN`, javascript in `dsa/samples-js/src`, python
in `dsa/samples-py/src/ChNN`, lua in `dsa/samples-lua`. The c\#
tree splits most chapters across a few files and groups sibling
topics inside one file, so that column sometimes repeats the
grouping file, go spells one ch31 file `disjoint_sparse.go` where
the other trees say `disjointsparse`, go's ch37 tree shares one
`geo.go` helper beside its ten samples, go's ch43 grid splits its 10
samples over 9 packages with extriangle and minplus sharing the
ch43 package, java spells every stem in pascal case so
`memo_vs_prune.c` is `MemoVsPrune.java`, chapter 15's naive matcher
lives in its own file beside the frozen original, and lua's ch43
minplus keeps its pinned matrix in a sibling pins module the main
file requires and run.lua never lists.

#[
#set text(size: 7.5pt)
#table(
  columns: (1.1fr, auto, 1.35fr, 1.35fr, 1.35fr, 1.35fr, 1.35fr, 1.5fr, 1.35fr, 1.5fr),
  inset: 3pt,
  table.header([*topic*], [*ch*], [*c*], [*rust*], [*go*], [*java*], [*c\#*], [*javascript*], [*python*], [*lua*]),
  [allocs], [ch 1], [allocs.c], [allocs.rs], [allocs.go], [Allocs.java], [Analysis.cs], [ch01-allocs.mjs], [allocs.py], [ch01_allocs.lua],
  [countops], [ch 1], [countops.c], [countops.rs], [countops.go], [Countops.java], [Analysis.cs], [ch01-countops.mjs], [countops.py], [ch01_countops.lua],
  [probebin], [ch 1], [probebin.c], [probebin.rs], [probebin.go], [Probebin.java], [Analysis.cs], [ch01-probebin.mjs], [probebin.py], [ch01_probebin.lua],
  [bounds], [ch 2], [bounds.c], [bounds.rs], [bounds.go], [Bounds.java], [Bounds.cs], [ch02-bounds.mjs], [bounds.py], [ch02_bounds.lua],
  [cache], [ch 2], [cache.c], [cache.rs], [cache.go], [Cache.java], [Arrays.cs], [ch02-cache.mjs], [cache.py], [ch02_cache.lua],
  [rowmajor], [ch 2], [rowmajor.c], [rowmajor.rs], [rowmajor.go], [Rowmajor.java], [Arrays.cs], [ch02-rowmajor.mjs], [rowmajor.py], [ch02_rowmajor.lua],
  [spans], [ch 2], [spans.c], [spans.rs], [spans.go], [Spans.java], [Arrays.cs], [ch02-spans.mjs], [spans.py], [ch02_spans.lua],
  [growth], [ch 3], [growth.c], [growth.rs], [growth.go], [Growth.java], [Dynamic.cs], [ch03-growth.mjs], [growth.py], [ch03_growth.lua],
  [vector], [ch 3], [vector.c], [vector.rs], [vector.go], [Vector.java], [Dynamic.cs], [ch03-vector.mjs], [vector.py], [ch03_vector.lua],
  [ring], [ch 4], [ring.c], [ring.rs], [ring.go], [Ring.java], [Linked.cs], [ch04-ring.mjs], [ring.py], [ch04_ring.lua],
  [slist], [ch 4], [slist.c], [slist.rs], [slist.go], [Slist.java], [Linked.cs], [ch04-slist.mjs], [slist.py], [ch04_slist.lua],
  [deque], [ch 5], [deque.c], [deque.rs], [deque.go], [Deque.java], [Deque.cs], [ch05-deque.mjs], [deque.py], [ch05_deque.lua],
  [ringqueue], [ch 5], [ringqueue.c], [ringqueue.rs], [ringqueue.go], [Ringqueue.java], [Buffers.cs], [ch05-ringqueue.mjs], [ringqueue.py], [ch05_ringqueue.lua],
  [shunting], [ch 5], [shunting.c], [shunting.rs], [shunting.go], [Shunting.java], [Buffers.cs], [ch05-shunting.mjs], [shunting.py], [ch05_shunting.lua],
  [stack], [ch 5], [stack.c], [stack.rs], [stack.go], [Stack.java], [Buffers.cs], [ch05-stack.mjs], [stack.py], [ch05_stack.lua],
  [chainmap], [ch 6], [chainmap.c], [chainmap.rs], [chainmap.go], [Chainmap.java], [Hashing.cs], [ch06-chainmap.mjs], [chainmap.py], [ch06_chainmap.lua],
  [fnv], [ch 6], [fnv.c], [fnv.rs], [fnv.go], [Fnv.java], [Hashing.cs], [ch06-fnv.mjs], [fnv.py], [ch06_fnv.lua],
  [hashset], [ch 6], [hashset.c], [hashset.rs], [hashset.go], [Hashset.java], [HashSet.cs], [ch06-hashset.mjs], [hashset.py], [ch06_hashset.lua],
  [openaddr], [ch 6], [openaddr.c], [openaddr.rs], [openaddr.go], [Openaddr.java], [Hashing.cs], [ch06-openaddr.mjs], [openaddr.py], [ch06_openaddr.lua],
  [balance], [ch 7], [balance.c], [balance.rs], [balance.go], [Balance.java], [Trees.cs], [ch07-balance.mjs], [balance.py], [ch07_balance.lua],
  [bst], [ch 7], [bst.c], [bst.rs], [bst.go], [Bst.java], [Trees.cs], [ch07-bst.mjs], [bst.py], [ch07_bst.lua],
  [traverse], [ch 7], [traverse.c], [traverse.rs], [traverse.go], [Traverse.java], [Trees.cs], [ch07-traverse.mjs], [traverse.py], [ch07_traverse.lua],
  [heap], [ch 8], [heap.c], [heap.rs], [heap.go], [Heap.java], [Heaps.cs], [ch08-heap.mjs], [heap.py], [ch08_heap.lua],
  [heapsort], [ch 8], [heapsort.c], [heapsort.rs], [heapsort.go], [Heapsort.java], [Heaps.cs], [ch08-heapsort.mjs], [heapsort.py], [ch08_heapsort.lua],
  [kway], [ch 8], [kway.c], [kway.rs], [kway.go], [Kway.java], [Heaps.cs], [ch08-kway.mjs], [kway.py], [ch08_kway.lua],
  [topk], [ch 8], [topk.c], [topk.rs], [topk.go], [Topk.java], [TopK.cs], [ch08-topk.mjs], [topk.py], [ch08_topk.lua],
  [prefixscan], [ch 9], [prefixscan.c], [prefixscan.rs], [prefixscan.go], [Prefixscan.java], [Tries.cs], [ch09-prefixscan.mjs], [prefixscan.py], [ch09_prefixscan.lua],
  [suffixarray], [ch 9], [suffixarray.c], [suffixarray.rs], [suffixarray.go], [Suffixarray.java], [Tries.cs], [ch09-suffixarray.mjs], [suffixarray.py], [ch09_suffixarray.lua],
  [suffixsearch], [ch 9], [suffixsearch.c], [suffixsearch.rs], [suffixsearch.go], [Suffixsearch.java], [Tries.cs], [ch09-suffixsearch.mjs], [suffixsearch.py], [ch09_suffixsearch.lua],
  [trie], [ch 9], [trie.c], [trie.rs], [trie.go], [Trie.java], [Tries.cs], [ch09-trie.mjs], [trie.py], [ch09_trie.lua],
  [bfs], [ch 10], [bfs.c], [bfs.rs], [bfs.go], [Bfs.java], [Graphs.cs], [ch10-bfs.mjs], [bfs.py], [ch10_bfs.lua],
  [build], [ch 10], [build.c], [build.rs], [build.go], [Build.java], [Graphs.cs], [ch10-build.mjs], [build.py], [ch10_build.lua],
  [components], [ch 10], [components.c], [components.rs], [components.go], [Components.java], [Graphs.cs], [ch10-components.mjs], [components.py], [ch10_components.lua],
  [dfs], [ch 10], [dfs.c], [dfs.rs], [dfs.go], [Dfs.java], [Graphs.cs], [ch10-dfs.mjs], [dfs.py], [ch10_dfs.lua],
  [topo], [ch 10], [topo.c], [topo.rs], [topo.go], [Topo.java], [Graphs.cs], [ch10-topo.mjs], [topo.py], [ch10_topo.lua],
  [astar], [ch 11], [astar.c], [astar.rs], [astar.go], [Astar.java], [Paths.cs], [ch11-astar.mjs], [astar.py], [ch11_astar.lua],
  [bellman], [ch 11], [bellman.c], [bellman.rs], [bellman.go], [Bellman.java], [Paths.cs], [ch11-bellman.mjs], [bellman.py], [ch11_bellman.lua],
  [dijkstra], [ch 11], [dijkstra.c], [dijkstra.rs], [dijkstra.go], [Dijkstra.java], [Paths.cs], [ch11-dijkstra.mjs], [dijkstra.py], [ch11_dijkstra.lua],
  [floyd], [ch 11], [floyd.c], [floyd.rs], [floyd.go], [Floyd.java], [Paths.cs], [ch11-floyd.mjs], [floyd.py], [ch11_floyd.lua],
  [dsu], [ch 12], [dsu.c], [dsu.rs], [dsu.go], [Dsu.java], [Flows.cs], [ch12-dsu.mjs], [dsu.py], [ch12_dsu.lua],
  [kruskal], [ch 12], [kruskal.c], [kruskal.rs], [kruskal.go], [Kruskal.java], [Flows.cs], [ch12-kruskal.mjs], [kruskal.py], [ch12_kruskal.lua],
  [maxflow], [ch 12], [maxflow.c], [maxflow.rs], [maxflow.go], [Maxflow.java], [Flows.cs], [ch12-maxflow.mjs], [maxflow.py], [ch12_maxflow.lua],
  [mincut], [ch 12], [mincut.c], [mincut.rs], [mincut.go], [Mincut.java], [Flows.cs], [ch12-mincut.mjs], [mincut.py], [ch12_mincut.lua],
  [prim], [ch 12], [prim.c], [prim.rs], [prim.go], [Prim.java], [Flows.cs], [ch12-prim.mjs], [prim.py], [ch12_prim.lua],
  [counting], [ch 13], [counting.c], [counting.rs], [counting.go], [Counting.java], [Sorting.cs], [ch13-counting.mjs], [counting.py], [ch13_counting.lua],
  [insertion], [ch 13], [insertion.c], [insertion.rs], [insertion.go], [Insertion.java], [Sorting.cs], [ch13-insertion.mjs], [insertion.py], [ch13_insertion.lua],
  [mergesort], [ch 13], [mergesort.c], [mergesort.rs], [mergesort.go], [Mergesort.java], [Sorting.cs], [ch13-mergesort.mjs], [mergesort.py], [ch13_mergesort.lua],
  [quickselect], [ch 13], [quickselect.c], [quickselect.rs], [quickselect.go], [Quickselect.java], [Sorting.cs], [ch13-quickselect.mjs], [quickselect.py], [ch13_quickselect.lua],
  [quicksort], [ch 13], [quicksort.c], [quicksort.rs], [quicksort.go], [Quicksort.java], [Sorting.cs], [ch13-quicksort.mjs], [quicksort.py], [ch13_quicksort.lua],
  [stability], [ch 13], [stability.c], [stability.rs], [stability.go], [Stability.java], [Sorting.cs], [ch13-stability.mjs], [stability.py], [ch13_stability.lua],
  [answerspace], [ch 14], [answerspace.c], [answerspace.rs], [answerspace.go], [Answerspace.java], [Searching.cs], [ch14-answerspace.mjs], [answerspace.py], [ch14_answerspace.lua],
  [bounds], [ch 14], [bounds.c], [bounds.rs], [bounds.go], [Bounds.java], [Searching.cs], [ch14-bounds.mjs], [bounds.py], [ch14_bounds.lua],
  [kadane], [ch 14], [kadane.c], [kadane.rs], [kadane.go], [Kadane.java], [Searching.cs], [ch14-kadane.mjs], [kadane.py], [ch14_kadane.lua],
  [mex], [ch 14], [mex.c], [mex.rs], [mex.go], [Mex.java], [Searching.cs], [ch14-mex.mjs], [mex.py], [ch14_mex.lua],
  [rotated], [ch 14], [rotated.c], [rotated.rs], [rotated.go], [Rotated.java], [Searching.cs], [ch14-rotated.mjs], [rotated.py], [ch14_rotated.lua],
  [aho], [ch 15], [aho.c], [aho.rs], [aho.go], [Aho.java], [Strings.cs], [ch15-aho.mjs], [aho.py], [ch15_aho.lua],
  [horspool], [ch 15], [horspool.c], [horspool.rs], [horspool.go], [Horspool.java], [Strings.cs], [ch15-horspool.mjs], [horspool.py], [ch15_horspool.lua],
  [kmp], [ch 15], [kmp.c], [kmp.rs], [kmp.go], [Kmp.java], [Strings.cs], [ch15-kmp.mjs], [kmp.py], [ch15_kmp.lua],
  [naive], [ch 15], [naive.c], [naive.rs], [naive.go], [Naive.java], [Naive.cs], [ch15-naive.mjs], [naive.py], [ch15_naive.lua],
  [rabinkarp], [ch 15], [rabinkarp.c], [rabinkarp.rs], [rabinkarp.go], [Rabinkarp.java], [Strings.cs], [ch15-rabinkarp.mjs], [rabinkarp.py], [ch15_rabinkarp.lua],
  [crt], [ch 16], [crt.c], [crt.rs], [crt.go], [Crt.java], [NumTheory.cs], [ch16-crt.mjs], [crt.py], [ch16_crt.lua],
  [factors], [ch 16], [factors.c], [factors.rs], [factors.go], [Factors.java], [NumTheory.cs], [ch16-factors.mjs], [factors.py], [ch16_factors.lua],
  [gcdlcm], [ch 16], [gcdlcm.c], [gcdlcm.rs], [gcdlcm.go], [Gcdlcm.java], [NumTheory.cs], [ch16-gcdlcm.mjs], [gcdlcm.py], [ch16_gcdlcm.lua],
  [modinv], [ch 16], [modinv.c], [modinv.rs], [modinv.go], [Modinv.java], [NumTheory.cs], [ch16-modinv.mjs], [modinv.py], [ch16_modinv.lua],
  [modpow], [ch 16], [modpow.c], [modpow.rs], [modpow.go], [Modpow.java], [NumTheory.cs], [ch16-modpow.mjs], [modpow.py], [ch16_modpow.lua],
  [sieve], [ch 16], [sieve.c], [sieve.rs], [sieve.go], [Sieve.java], [NumTheory.cs], [ch16-sieve.mjs], [sieve.py], [ch16_sieve.lua],
  [assignment], [ch 17], [assignment.c], [assignment.rs], [assignment.go], [Assignment.java], [Dp.cs], [ch17-assignment.mjs], [assignment.py], [ch17_assignment.lua],
  [coins], [ch 17], [coins.c], [coins.rs], [coins.go], [Coins.java], [Dp.cs], [ch17-coins.mjs], [coins.py], [ch17_coins.lua],
  [editdist], [ch 17], [editdist.c], [editdist.rs], [editdist.go], [Editdist.java], [Dp.cs], [ch17-editdist.mjs], [editdist.py], [ch17_editdist.lua],
  [gridpaths], [ch 17], [gridpaths.c], [gridpaths.rs], [gridpaths.go], [Gridpaths.java], [Dp.cs], [ch17-gridpaths.mjs], [gridpaths.py], [ch17_gridpaths.lua],
  [knapsack], [ch 17], [knapsack.c], [knapsack.rs], [knapsack.go], [Knapsack.java], [Dp.cs], [ch17-knapsack.mjs], [knapsack.py], [ch17_knapsack.lua],
  [lis], [ch 17], [lis.c], [lis.rs], [lis.go], [Lis.java], [Dp.cs], [ch17-lis.mjs], [lis.py], [ch17_lis.lua],
  [memo], [ch 17], [memo.c], [memo.rs], [memo.go], [Memo.java], [Dp.cs], [ch17-memo.mjs], [memo.py], [ch17_memo.lua],
  [backtrack], [ch 18], [backtrack.c], [backtrack.rs], [backtrack.go], [Backtrack.java], [Greedy.cs], [ch18-backtrack.mjs], [backtrack.py], [ch18_backtrack.lua],
  [huffman], [ch 18], [huffman.c], [huffman.rs], [huffman.go], [Huffman.java], [Greedy.cs], [ch18-huffman.mjs], [huffman.py], [ch18_huffman.lua],
  [intervals], [ch 18], [intervals.c], [intervals.rs], [intervals.go], [Intervals.java], [Greedy.cs], [ch18-intervals.mjs], [intervals.py], [ch18_intervals.lua],
  [jumpgame], [ch 18], [jumpgame.c], [jumpgame.rs], [jumpgame.go], [Jumpgame.java], [JumpGame.cs], [ch18-jumpgame.mjs], [jumpgame.py], [ch18_jumpgame.lua],
  [bitmask], [ch 19], [bitmask.c], [bitmask.rs], [bitmask.go], [Bitmask.java], [AdvDp.cs], [ch19-bitmask.mjs], [bitmask.py], [ch19_bitmask.lua],
  [bounded], [ch 19], [bounded.c], [bounded.rs], [bounded.go], [Bounded.java], [AdvDp.cs], [ch19-bounded.mjs], [bounded.py], [ch19_bounded.lua],
  [cht], [ch 19], [cht.c], [cht.rs], [cht.go], [Cht.java], [AdvDp.cs], [ch19-cht.mjs], [cht.py], [ch19_cht.lua],
  [digitdp], [ch 19], [digitdp.c], [digitdp.rs], [digitdp.go], [Digitdp.java], [DigitDp.cs], [ch19-digitdp.mjs], [digitdp.py], [ch19_digitdp.lua],
  [grouped], [ch 19], [grouped.c], [grouped.rs], [grouped.go], [Grouped.java], [AdvDp.cs], [ch19-grouped.mjs], [grouped.py], [ch19_grouped.lua],
  [intervaldp], [ch 19], [intervaldp.c], [intervaldp.rs], [intervaldp.go], [Intervaldp.java], [IntervalDp.cs], [ch19-intervaldp.mjs], [intervaldp.py], [ch19_intervaldp.lua],
  [tails], [ch 19], [tails.c], [tails.rs], [tails.go], [Tails.java], [AdvDp.cs], [ch19-tails.mjs], [tails.py], [ch19_tails.lua],
  [window], [ch 19], [window.c], [window.rs], [window.go], [Window.java], [AdvDp.cs], [ch19-window.mjs], [window.py], [ch19_window.lua],
  [alphabeta], [ch 20], [alphabeta.c], [alphabeta.rs], [alphabeta.go], [Alphabeta.java], [Pruning.cs], [ch20-alphabeta.mjs], [alphabeta.py], [ch20_alphabeta.lua],
  [bandb], [ch 20], [bandb.c], [bandb.rs], [bandb.go], [Bandb.java], [Pruning.cs], [ch20-bandb.mjs], [bandb.py], [ch20_bandb.lua],
  [memo_vs_prune], [ch 20], [memo_vs_prune.c], [memo_vs_prune.rs], [memo_vs_prune.go], [MemoVsPrune.java], [Pruning.cs], [ch20-memo_vs_prune.mjs], [memo_vs_prune.py], [ch20_memo_vs_prune.lua],
  [nqueens], [ch 20], [nqueens.c], [nqueens.rs], [nqueens.go], [Nqueens.java], [Pruning.cs], [ch20-nqueens.mjs], [nqueens.py], [ch20_nqueens.lua],
  [fenwick], [ch 21], [fenwick.c], [fenwick.rs], [fenwick.go], [Fenwick.java], [Ranges.cs], [ch21-fenwick.mjs], [fenwick.py], [ch21_fenwick.lua],
  [maxima], [ch 21], [maxima.c], [maxima.rs], [maxima.go], [Maxima.java], [Ranges.cs], [ch21-maxima.mjs], [maxima.py], [ch21_maxima.lua],
  [nextgreater], [ch 21], [nextgreater.c], [nextgreater.rs], [nextgreater.go], [Nextgreater.java], [Ranges.cs], [ch21-nextgreater.mjs], [nextgreater.py], [ch21_nextgreater.lua],
  [prefix], [ch 21], [prefix.c], [prefix.rs], [prefix.go], [Prefix.java], [Prefix.cs], [ch21-prefix.mjs], [prefix.py], [ch21_prefix.lua],
  [segtree], [ch 21], [segtree.c], [segtree.rs], [segtree.go], [Segtree.java], [Ranges.cs], [ch21-segtree.mjs], [segtree.py], [ch21_segtree.lua],
  [sparsetable], [ch 21], [sparsetable.c], [sparsetable.rs], [sparsetable.go], [Sparsetable.java], [Ranges.cs], [ch21-sparsetable.mjs], [sparsetable.py], [ch21_sparsetable.lua],
  [coordcompress], [ch 22], [coordcompress.c], [coordcompress.rs], [coordcompress.go], [Coordcompress.java], [Compression.cs], [ch22-coordcompress.mjs], [coordcompress.py], [ch22_coordcompress.lua],
  [diffarray], [ch 22], [diffarray.c], [diffarray.rs], [diffarray.go], [Diffarray.java], [Compression.cs], [ch22-diffarray.mjs], [diffarray.py], [ch22_diffarray.lua],
  [mergeintervals], [ch 22], [mergeintervals.c], [mergeintervals.rs], [mergeintervals.go], [Mergeintervals.java], [Compression.cs], [ch22-mergeintervals.mjs], [mergeintervals.py], [ch22_mergeintervals.lua],
  [overlaps], [ch 22], [overlaps.c], [overlaps.rs], [overlaps.go], [Overlaps.java], [Compression.cs], [ch22-overlaps.mjs], [overlaps.py], [ch22_overlaps.lua],
  [closestpair], [ch 23], [closestpair.c], [closestpair.rs], [closestpair.go], [Closestpair.java], [Geometry.cs], [ch23-closestpair.mjs], [closestpair.py], [ch23_closestpair.lua],
  [hull], [ch 23], [hull.c], [hull.rs], [hull.go], [Hull.java], [Geometry.cs], [ch23-hull.mjs], [hull.py], [ch23_hull.lua],
  [orientation], [ch 23], [orientation.c], [orientation.rs], [orientation.go], [Orientation.java], [Geometry.cs], [ch23-orientation.mjs], [orientation.py], [ch23_orientation.lua],
  [sweep], [ch 23], [sweep.c], [sweep.rs], [sweep.go], [Sweep.java], [Geometry.cs], [ch23-sweep.mjs], [sweep.py], [ch23_sweep.lua],
  [floodfill], [ch 24], [floodfill.c], [floodfill.rs], [floodfill.go], [Floodfill.java], [Lattice.cs], [ch24-floodfill.mjs], [floodfill.py], [ch24_floodfill.lua],
  [neighbors], [ch 24], [neighbors.c], [neighbors.rs], [neighbors.go], [Neighbors.java], [Lattice.cs], [ch24-neighbors.mjs], [neighbors.py], [ch24_neighbors.lua],
  [raycast], [ch 24], [raycast.c], [raycast.rs], [raycast.go], [Raycast.java], [Lattice.cs], [ch24-raycast.mjs], [raycast.py], [ch24_raycast.lua],
  [shoelace], [ch 24], [shoelace.c], [shoelace.rs], [shoelace.go], [Shoelace.java], [Lattice.cs], [ch24-shoelace.mjs], [shoelace.py], [ch24_shoelace.lua],
  [bloom], [ch 25], [bloom.c], [bloom.rs], [bloom.go], [Bloom.java], [Practical.cs], [ch25-bloom.mjs], [bloom.py], [ch25_bloom.lua],
  [countmin], [ch 25], [countmin.c], [countmin.rs], [countmin.go], [Countmin.java], [Practical.cs], [ch25-countmin.mjs], [countmin.py], [ch25_countmin.lua],
  [lru], [ch 25], [lru.c], [lru.rs], [lru.go], [Lru.java], [Practical.cs], [ch25-lru.mjs], [lru.py], [ch25_lru.lua],
  [skiplist], [ch 25], [skiplist.c], [skiplist.rs], [skiplist.go], [Skiplist.java], [Practical.cs], [ch25-skiplist.mjs], [skiplist.py], [ch25_skiplist.lua],
  [asteval], [ch 26], [asteval.c], [asteval.rs], [asteval.go], [Asteval.java], [Parsing.cs], [ch26-asteval.mjs], [asteval.py], [ch26_asteval.lua],
  [rdparse], [ch 26], [rdparse.c], [rdparse.rs], [rdparse.go], [Rdparse.java], [Parsing.cs], [ch26-rdparse.mjs], [rdparse.py], [ch26_rdparse.lua],
  [tokens], [ch 26], [tokens.c], [tokens.rs], [tokens.go], [Tokens.java], [Parsing.cs], [ch26-tokens.mjs], [tokens.py], [ch26_tokens.lua],
  [jumps], [ch 27], [jumps.c], [jumps.rs], [jumps.go], [Jumps.java], [Machine.cs], [ch27-jumps.mjs], [jumps.py], [ch27_jumps.lua],
  [modes], [ch 27], [modes.c], [modes.rs], [modes.go], [Modes.java], [Machine.cs], [ch27-modes.mjs], [modes.py], [ch27_modes.lua],
  [opcodes], [ch 27], [opcodes.c], [opcodes.rs], [opcodes.go], [Opcodes.java], [Machine.cs], [ch27-opcodes.mjs], [opcodes.py], [ch27_opcodes.lua],
  [cfrac], [ch 28], [cfrac.c], [cfrac.rs], [cfrac.go], [Cfrac.java], [CFrac.cs], [ch28-cfrac.mjs], [cfrac.py], [ch28_cfrac.lua],
  [diophantine], [ch 28], [diophantine.c], [diophantine.rs], [diophantine.go], [Diophantine.java], [Diophantine.cs], [ch28-diophantine.mjs], [diophantine.py], [ch28_diophantine.lua],
  [dlog], [ch 28], [dlog.c], [dlog.rs], [dlog.go], [Dlog.java], [DLog.cs], [ch28-dlog.mjs], [dlog.py], [ch28_dlog.lua],
  [garner], [ch 28], [garner.c], [garner.rs], [garner.go], [Garner.java], [Garner.cs], [ch28-garner.mjs], [garner.py], [ch28_garner.lua],
  [graytern], [ch 28], [graytern.c], [graytern.rs], [graytern.go], [Graytern.java], [GrayTern.cs], [ch28-graytern.mjs], [graytern.py], [ch28_graytern.lua],
  [linsieve], [ch 28], [linsieve.c], [linsieve.rs], [linsieve.go], [Linsieve.java], [LinSieve.cs], [ch28-linsieve.mjs], [linsieve.py], [ch28_linsieve.lua],
  [primality], [ch 28], [primality.c], [primality.rs], [primality.go], [Primality.java], [Primality.cs], [ch28-primality.mjs], [primality.py], [ch28_primality.lua],
  [totdiv], [ch 28], [totdiv.c], [totdiv.rs], [totdiv.go], [Totdiv.java], [TotDiv.cs], [ch28-totdiv.mjs], [totdiv.py], [ch28_totdiv.lua],
  [bigint], [ch 29], [bigint.c], [bigint.rs], [bigint.go], [Bigint.java], [BigNum.cs], [ch29-bigint.mjs], [bigint.py], [ch29_bigint.lua],
  [divmod], [ch 29], [divmod.c], [divmod.rs], [divmod.go], [Divmod.java], [DivMod.cs], [ch29-divmod.mjs], [divmod.py], [ch29_divmod.lua],
  [fft], [ch 29], [fft.c], [fft.rs], [fft.go], [Fft.java], [Fft.cs], [ch29-fft.mjs], [fft.py], [ch29_fft.lua],
  [karatsuba], [ch 29], [karatsuba.c], [karatsuba.rs], [karatsuba.go], [Karatsuba.java], [Karatsuba.cs], [ch29-karatsuba.mjs], [karatsuba.py], [ch29_karatsuba.lua],
  [ntt], [ch 29], [ntt.c], [ntt.rs], [ntt.go], [Ntt.java], [Ntt.cs], [ch29-ntt.mjs], [ntt.py], [ch29_ntt.lua],
  [polyops], [ch 29], [polyops.c], [polyops.rs], [polyops.go], [Polyops.java], [PolyOps.cs], [ch29-polyops.mjs], [polyops.py], [ch29_polyops.lua],
  [mergeheap], [ch 30], [mergeheap.c], [mergeheap.rs], [mergeheap.go], [Mergeheap.java], [MergeHeap.cs], [ch30-mergeheap.mjs], [mergeheap.py], [ch30_mergeheap.lua],
  [orderstats], [ch 30], [orderstats.c], [orderstats.rs], [orderstats.go], [Orderstats.java], [OrderStats.cs], [ch30-orderstats.mjs], [orderstats.py], [ch30_orderstats.lua],
  [treap], [ch 30], [treap.c], [treap.rs], [treap.go], [Treap.java], [Treap.cs], [ch30-treap.mjs], [treap.py], [ch30_treap.lua],
  [disjointsparse], [ch 31], [disjointsparse.c], [disjointsparse.rs], [disjoint_sparse.go], [Disjointsparse.java], [DisjointSparse.cs], [ch31-disjointsparse.mjs], [disjointsparse.py], [ch31_disjointsparse.lua],
  [lichao], [ch 31], [lichao.c], [lichao.rs], [lichao.go], [Lichao.java], [LiChao.cs], [ch31-lichao.mjs], [lichao.py], [ch31_lichao.lua],
  [minstack], [ch 31], [minstack.c], [minstack.rs], [minstack.go], [Minstack.java], [MinStack.cs], [ch31-minstack.mjs], [minstack.py], [ch31_minstack.lua],
  [mos], [ch 31], [mos.c], [mos.rs], [mos.go], [Mos.java], [Mos.cs], [ch31-mos.mjs], [mos.py], [ch31_mos.lua],
  [offlinedynconn], [ch 31], [offlinedynconn.c], [offlinedynconn.rs], [offlinedynconn.go], [Offlinedynconn.java], [OfflineDynConn.cs], [ch31-offlinedynconn.mjs], [offlinedynconn.py], [ch31_offlinedynconn.lua],
  [rollbackdsu], [ch 31], [rollbackdsu.c], [rollbackdsu.rs], [rollbackdsu.go], [Rollbackdsu.java], [RollbackDsu.cs], [ch31-rollbackdsu.mjs], [rollbackdsu.py], [ch31_rollbackdsu.lua],
  [sqrtblocks], [ch 31], [sqrtblocks.c], [sqrtblocks.rs], [sqrtblocks.go], [Sqrtblocks.java], [SqrtBlocks.cs], [ch31-sqrtblocks.mjs], [sqrtblocks.py], [ch31_sqrtblocks.lua],
  [brokenprofile], [ch 32], [brokenprofile.c], [brokenprofile.rs], [brokenprofile.go], [Brokenprofile.java], [BrokenProfile.cs], [ch32-brokenprofile.mjs], [brokenprofile.py], [ch32_brokenprofile.lua],
  [dncdp], [ch 32], [dncdp.c], [dncdp.rs], [dncdp.go], [Dncdp.java], [DncDp.cs], [ch32-dncdp.mjs], [dncdp.py], [ch32_dncdp.lua],
  [knuth], [ch 32], [knuth.c], [knuth.rs], [knuth.go], [Knuth.java], [Knuth.cs], [ch32-knuth.mjs], [knuth.py], [ch32_knuth.lua],
  [slopetrick], [ch 32], [slopetrick.c], [slopetrick.rs], [slopetrick.go], [Slopetrick.java], [SlopeTrick.cs], [ch32-slopetrick.mjs], [slopetrick.py], [ch32_slopetrick.lua],
  [valueiter], [ch 32], [valueiter.c], [valueiter.rs], [valueiter.go], [Valueiter.java], [ValueIter.cs], [ch32-valueiter.mjs], [valueiter.py], [ch32_valueiter.lua],
  [lyndon], [ch 33], [lyndon.c], [lyndon.rs], [lyndon.go], [Lyndon.java], [Lyndon.cs], [ch33-lyndon.mjs], [lyndon.py], [ch33_lyndon.lua],
  [manacher], [ch 33], [manacher.c], [manacher.rs], [manacher.go], [Manacher.java], [Manacher.cs], [ch33-manacher.mjs], [manacher.py], [ch33_manacher.lua],
  [suffixautomaton], [ch 33], [suffixautomaton.c], [suffixautomaton.rs], [suffixautomaton.go], [Suffixautomaton.java], [SuffixAutomaton.cs], [ch33-suffixautomaton.mjs], [suffixautomaton.py], [ch33_suffixautomaton.lua],
  [suffixtree], [ch 33], [suffixtree.c], [suffixtree.rs], [suffixtree.go], [Suffixtree.java], [SuffixTree.cs], [ch33-suffixtree.mjs], [suffixtree.py], [ch33_suffixtree.lua],
  [zfunc], [ch 33], [zfunc.c], [zfunc.rs], [zfunc.go], [Zfunc.java], [Zfunc.cs], [ch33-zfunc.mjs], [zfunc.py], [ch33_zfunc.lua],
  [cramer], [ch 34], [cramer.c], [cramer.rs], [cramer.go], [Cramer.java], [Cramer.cs], [ch34-cramer.mjs], [cramer.py], [ch34_cramer.lua],
  [determinant], [ch 34], [determinant.c], [determinant.rs], [determinant.go], [Determinant.java], [Determinant.cs], [ch34-determinant.mjs], [determinant.py], [ch34_determinant.lua],
  [gauss], [ch 34], [gauss.c], [gauss.rs], [gauss.go], [Gauss.java], [Gauss.cs], [ch34-gauss.mjs], [gauss.py], [ch34_gauss.lua],
  [kirchhoff], [ch 34], [kirchhoff.c], [kirchhoff.rs], [kirchhoff.go], [Kirchhoff.java], [Kirchhoff.cs], [ch34-kirchhoff.mjs], [kirchhoff.py], [ch34_kirchhoff.lua],
  [matpow], [ch 34], [matpow.c], [matpow.rs], [matpow.go], [Matpow.java], [Matpow.cs], [ch34-matpow.mjs], [matpow.py], [ch34_matpow.lua],
  [zpk], [ch 34], [zpk.c], [zpk.rs], [zpk.go], [Zpk.java], [Zpk.cs], [ch34-zpk.mjs], [zpk.py], [ch34_zpk.lua],
  [binom], [ch 35], [binom.c], [binom.rs], [binom.go], [Binom.java], [Binom.cs], [ch35-binom.mjs], [binom.py], [ch35_binom.lua],
  [bishops], [ch 35], [bishops.c], [bishops.rs], [bishops.go], [Bishops.java], [Bishops.cs], [ch35-bishops.mjs], [bishops.py], [ch35_bishops.lua],
  [brackets], [ch 35], [brackets.c], [brackets.rs], [brackets.go], [Brackets.java], [Brackets.cs], [ch35-brackets.mjs], [brackets.py], [ch35_brackets.lua],
  [burnside], [ch 35], [burnside.c], [burnside.rs], [burnside.go], [Burnside.java], [Burnside.cs], [ch35-burnside.mjs], [burnside.py], [ch35_burnside.lua],
  [catalan], [ch 35], [catalan.c], [catalan.rs], [catalan.go], [Catalan.java], [Catalan.cs], [ch35-catalan.mjs], [catalan.py], [ch35_catalan.lua],
  [frobenius], [ch 35], [frobenius.c], [frobenius.rs], [frobenius.go], [Frobenius.java], [Frobenius.cs], [ch35-frobenius.mjs], [frobenius.py], [ch35_frobenius.lua],
  [incexc], [ch 35], [incexc.c], [incexc.rs], [incexc.go], [Incexc.java], [IncExc.cs], [ch35-incexc.mjs], [incexc.py], [ch35_incexc.lua],
  [josephus], [ch 35], [josephus.c], [josephus.rs], [josephus.go], [Josephus.java], [Josephus.cs], [ch35-josephus.mjs], [josephus.py], [ch35_josephus.lua],
  [ksubset], [ch 35], [ksubset.c], [ksubset.rs], [ksubset.go], [Ksubset.java], [KSubset.cs], [ch35-ksubset.mjs], [ksubset.py], [ch35_ksubset.lua],
  [labeled], [ch 35], [labeled.c], [labeled.rs], [labeled.go], [Labeled.java], [Labeled.cs], [ch35-labeled.mjs], [labeled.py], [ch35_labeled.lua],
  [sperner], [ch 35], [sperner.c], [sperner.rs], [sperner.go], [Sperner.java], [Sperner.cs], [ch35-sperner.mjs], [sperner.py], [ch35_sperner.lua],
  [starsbars], [ch 35], [starsbars.c], [starsbars.rs], [starsbars.go], [Starsbars.java], [StarsBars.cs], [ch35-starsbars.mjs], [starsbars.py], [ch35_starsbars.lua],
  [golden], [ch 36], [golden.c], [golden.rs], [golden.go], [Golden.java], [Golden.cs], [ch36-golden.mjs], [golden.py], [ch36_golden.lua],
  [lpdual], [ch 36], [lpdual.c], [lpdual.rs], [lpdual.go], [Lpdual.java], [LpDual.cs], [ch36-lpdual.mjs], [lpdual.py], [ch36_lpdual.lua],
  [newton], [ch 36], [newton.c], [newton.rs], [newton.go], [Newton.java], [Newton.cs], [ch36-newton.mjs], [newton.py], [ch36_newton.lua],
  [simpson], [ch 36], [simpson.c], [simpson.rs], [simpson.go], [Simpson.java], [Simpson.cs], [ch36-simpson.mjs], [simpson.py], [ch36_simpson.lua],
  [ternary], [ch 36], [ternary.c], [ternary.rs], [ternary.go], [Ternary.java], [Ternary.cs], [ch36-ternary.mjs], [ternary.py], [ch36_ternary.lua],
  [calipers], [ch 37], [calipers.c], [calipers.rs], [calipers.go], [Calipers.java], [Calipers.cs], [ch37-calipers.mjs], [calipers.py], [ch37_calipers.lua],
  [circles], [ch 37], [circles.c], [circles.rs], [circles.go], [Circles.java], [Geometry2.cs], [ch37-circles.mjs], [circles.py], [ch37_circles.lua],
  [halfplane], [ch 37], [halfplane.c], [halfplane.rs], [halfplane.go], [Halfplane.java], [Calipers.cs], [ch37-halfplane.mjs], [halfplane.py], [ch37_halfplane.lua],
  [manhattan], [ch 37], [manhattan.c], [manhattan.rs], [manhattan.go], [Manhattan.java], [Calipers.cs], [ch37-manhattan.mjs], [manhattan.py], [ch37_manhattan.lua],
  [mincircle], [ch 37], [mincircle.c], [mincircle.rs], [mincircle.go], [Mincircle.java], [Calipers.cs], [ch37-mincircle.mjs], [mincircle.py], [ch37_mincircle.lua],
  [minkowski], [ch 37], [minkowski.c], [minkowski.rs], [minkowski.go], [Minkowski.java], [Geometry2.cs], [ch37-minkowski.mjs], [minkowski.py], [ch37_minkowski.lua],
  [ottmann], [ch 37], [ottmann.c], [ottmann.rs], [ottmann.go], [Ottmann.java], [Voronoi.cs], [ch37-ottmann.mjs], [ottmann.py], [ch37_ottmann.lua],
  [pinconvex], [ch 37], [pinconvex.c], [pinconvex.rs], [pinconvex.go], [Pinconvex.java], [Geometry2.cs], [ch37-pinconvex.mjs], [pinconvex.py], [ch37_pinconvex.lua],
  [segunion], [ch 37], [segunion.c], [segunion.rs], [segunion.go], [Segunion.java], [Geometry2.cs], [ch37-segunion.mjs], [segunion.py], [ch37_segunion.lua],
  [voronoi], [ch 37], [voronoi.c], [voronoi.rs], [voronoi.go], [Voronoi.java], [Voronoi.cs], [ch37-voronoi.mjs], [voronoi.py], [ch37_voronoi.lua],
  [assign], [ch 38], [assign.c], [assign.rs], [assign.go], [Assign.java], [Hungarian.cs], [ch38-assign.mjs], [assign.py], [ch38_assign.lua],
  [demands], [ch 38], [demands.c], [demands.rs], [demands.go], [Demands.java], [Costs2.cs], [ch38-demands.mjs], [demands.py], [ch38_demands.lua],
  [dinic], [ch 38], [dinic.c], [dinic.rs], [dinic.go], [Dinic.java], [Flow2.cs], [ch38-dinic.mjs], [dinic.py], [ch38_dinic.lua],
  [hall], [ch 38], [hall.c], [hall.rs], [hall.go], [Hall.java], [Match.cs], [ch38-hall.mjs], [hall.py], [ch38_hall.lua],
  [hungarian], [ch 38], [hungarian.c], [hungarian.rs], [hungarian.go], [Hungarian.java], [Hungarian.cs], [ch38-hungarian.mjs], [hungarian.py], [ch38_hungarian.lua],
  [kuhn], [ch 38], [kuhn.c], [kuhn.rs], [kuhn.go], [Kuhn.java], [Match.cs], [ch38-kuhn.mjs], [kuhn.py], [ch38_kuhn.lua],
  [mcmf], [ch 38], [mcmf.c], [mcmf.rs], [mcmf.go], [Mcmf.java], [Costs2.cs], [ch38-mcmf.mjs], [mcmf.py], [ch38_mcmf.lua],
  [pushrelabel], [ch 38], [pushrelabel.c], [pushrelabel.rs], [pushrelabel.go], [Pushrelabel.java], [Flow2.cs], [ch38-pushrelabel.mjs], [pushrelabel.py], [ch38_pushrelabel.lua],
  [stoerwagner], [ch 38], [stoerwagner.c], [stoerwagner.rs], [stoerwagner.go], [Stoerwagner.java], [Cuts.cs], [ch38-stoerwagner.mjs], [stoerwagner.py], [ch38_stoerwagner.lua],
  [bridges], [ch 39], [bridges.c], [bridges.rs], [bridges.go], [Bridges.java], [Edges.cs], [ch39-bridges.mjs], [bridges.py], [ch39_bridges.lua],
  [centroid], [ch 39], [centroid.c], [centroid.rs], [centroid.go], [Centroid.java], [Centers.cs], [ch39-centroid.mjs], [centroid.py], [ch39_centroid.lua],
  [euler], [ch 39], [euler.c], [euler.rs], [euler.go], [Euler.java], [Edges.cs], [ch39-euler.mjs], [euler.py], [ch39_euler.lua],
  [functional], [ch 39], [functional.c], [functional.rs], [functional.go], [Functional.java], [Centers.cs], [ch39-functional.mjs], [functional.py], [ch39_functional.lua],
  [hld], [ch 39], [hld.c], [hld.rs], [hld.go], [Hld.java], [Paths2.cs], [ch39-hld.mjs], [hld.py], [ch39_hld.lua],
  [lca], [ch 39], [lca.c], [lca.rs], [lca.go], [Lca.java], [Paths2.cs], [ch39-lca.mjs], [lca.py], [ch39_lca.lua],
  [prufer], [ch 39], [prufer.c], [prufer.rs], [prufer.go], [Prufer.java], [Prufer.cs], [ch39-prufer.mjs], [prufer.py], [ch39_prufer.lua],
  [scc], [ch 39], [scc.c], [scc.rs], [scc.go], [Scc.java], [Strong.cs], [ch39-scc.mjs], [scc.py], [ch39_scc.lua],
  [twocore], [ch 39], [twocore.c], [twocore.rs], [twocore.go], [Twocore.java], [Centers.cs], [ch39-twocore.mjs], [twocore.py], [ch39_twocore.lua],
  [twosat], [ch 39], [twosat.c], [twosat.rs], [twosat.go], [Twosat.java], [Strong.cs], [ch39-twosat.mjs], [twosat.py], [ch39_twosat.lua],
  [graphgames], [ch 40], [graphgames.c], [graphgames.rs], [graphgames.go], [Graphgames.java], [GraphGames.cs], [ch40-graphgames.mjs], [graphgames.py], [ch40_graphgames.lua],
  [grundy], [ch 40], [grundy.c], [grundy.rs], [grundy.go], [Grundy.java], [Grundy.cs], [ch40-grundy.mjs], [grundy.py], [ch40_grundy.lua],
  [scheduling], [ch 40], [scheduling.c], [scheduling.rs], [scheduling.go], [Scheduling.java], [Scheduling.cs], [ch40-scheduling.mjs], [scheduling.py], [ch40_scheduling.lua],
  [aco], [ch 41], [aco.c], [aco.rs], [aco.go], [Aco.java], [Aco.cs], [ch41-aco.mjs], [aco.py], [ch41_aco.lua],
  [anneal], [ch 41], [anneal.c], [anneal.rs], [anneal.go], [Anneal.java], [Anneal.cs], [ch41-anneal.mjs], [anneal.py], [ch41_anneal.lua],
  [ga], [ch 41], [ga.c], [ga.rs], [ga.go], [Ga.java], [Ga.cs], [ch41-ga.mjs], [ga.py], [ch41_ga.lua],
  [hill], [ch 41], [hill.c], [hill.rs], [hill.go], [Hill.java], [Hill.cs], [ch41-hill.mjs], [hill.py], [ch41_hill.lua],
  [localsearch], [ch 41], [localsearch.c], [localsearch.rs], [localsearch.go], [Localsearch.java], [Localsearch.cs], [ch41-localsearch.mjs], [localsearch.py], [ch41_localsearch.lua],
  [restarts], [ch 41], [restarts.c], [restarts.rs], [restarts.go], [Restarts.java], [Restarts.cs], [ch41-restarts.mjs], [restarts.py], [ch41_restarts.lua],
  [tabu], [ch 41], [tabu.c], [tabu.rs], [tabu.go], [Tabu.java], [Tabu.cs], [ch41-tabu.mjs], [tabu.py], [ch41_tabu.lua],
  [twoopt], [ch 41], [twoopt.c], [twoopt.rs], [twoopt.go], [Twoopt.java], [TwoOpt.cs], [ch41-twoopt.mjs], [twoopt.py], [ch41_twoopt.lua],
  [binpack], [ch 42], [binpack.c], [binpack.rs], [binpack.go], [Binpack.java], [Binpack.cs], [ch42-binpack.mjs], [binpack.py], [ch42_binpack.lua],
  [christofides], [ch 42], [christofides.c], [christofides.rs], [christofides.go], [Christofides.java], [Christofides.cs], [ch42-christofides.mjs], [christofides.py], [ch42_christofides.lua],
  [maxcut], [ch 42], [maxcut.c], [maxcut.rs], [maxcut.go], [Maxcut.java], [Maxcut.cs], [ch42-maxcut.mjs], [maxcut.py], [ch42_maxcut.lua],
  [ptas], [ch 42], [ptas.c], [ptas.rs], [ptas.go], [Ptas.java], [Ptas.cs], [ch42-ptas.mjs], [ptas.py], [ch42_ptas.lua],
  [ratio], [ch 42], [ratio.c], [ratio.rs], [ratio.go], [Ratio.java], [Ratio.cs], [ch42-ratio.mjs], [ratio.py], [ch42_ratio.lua],
  [setcover], [ch 42], [setcover.c], [setcover.rs], [setcover.go], [Setcover.java], [Setcover.cs], [ch42-setcover.mjs], [setcover.py], [ch42_setcover.lua],
  [tsp2x], [ch 42], [tsp2x.c], [tsp2x.rs], [tsp2x.go], [Tsp2x.java], [Tsp2x.cs], [ch42-tsp2x.mjs], [tsp2x.py], [ch42_tsp2x.lua],
  [vc], [ch 42], [vc.c], [vc.rs], [vc.go], [Vc.java], [Vc.cs], [ch42-vc.mjs], [vc.py], [ch42_vc.lua],
  [baselines], [ch 43], [baselines.c], [baselines.rs], [baselines.go], [Baselines.java], [Baselines.cs], [ch43-baselines.mjs], [baselines.py], [ch43_baselines.lua],
  [schoenhage], [ch 43], [schoenhage.c], [schoenhage.rs], [schoenhage.go], [Schoenhage.java], [Schoenhage.cs], [ch43-schoenhage.mjs], [schoenhage.py], [ch43_schoenhage.lua],
  [recursion], [ch 43], [recursion.c], [recursion.rs], [recursion.go], [Recursion.java], [Recursion.cs], [ch43-recursion.mjs], [recursion.py], [ch43_recursion.lua],
  [tiling], [ch 43], [tiling.c], [tiling.rs], [tiling.go], [Tiling.java], [Tiling.cs], [ch43-tiling.mjs], [tiling.py], [ch43_tiling.lua],
  [pruned], [ch 43], [pruned.c], [pruned.rs], [pruned.go], [Pruned.java], [Pruned.cs], [ch43-pruned.mjs], [pruned.py], [ch43_pruned.lua],
  [boxes], [ch 43], [boxes.c], [boxes.rs], [boxes.go], [Boxes.java], [Boxes.cs], [ch43-boxes.mjs], [boxes.py], [ch43_boxes.lua],
  [extriangle], [ch 43], [extriangle.c], [extriangle.rs], [extriangle.go], [Extriangle.java], [Extriangle.cs], [ch43-extriangle.mjs], [extriangle.py], [ch43_extriangle.lua],
  [minplus], [ch 43], [minplus.c], [minplus.rs], [minplus.go], [Minplus.java], [Minplus.cs], [ch43-minplus.mjs], [minplus.py], [ch43_minplus.lua],
  [strassen], [ch 43], [strassen.c], [strassen.rs], [strassen.go], [Strassen.java], [Strassen.cs], [ch43-strassen.mjs], [strassen.py], [ch43_strassen.lua],
  [profile], [ch 43], [profile.c], [profile.rs], [profile.go], [Profile.java], [Profile.cs], [ch43-profile.mjs], [profile.py], [ch43_profile.lua],
)

]

#table(
  columns: (auto, 1.2fr, 1.4fr, 1.8fr),
  inset: 4pt,
  table.header([*language*], [*suite size*], [*unit*], [*gate*]),
  [c], [232 files, 4372], [checks, one ok line per file], [`make verify-c` scope `books/dsa/samples-c/src`],
  [rust], [232 files, 4342], [checks, one ok line per file], [`make verify-rust` scope `books/dsa/samples-rust/src`],
  [go], [813], [tests, go test], [`make verify-go`],
  [java], [232 files, 4485], [checks, one ok line per file], [`make verify-java` scope `books/dsa/samples-java/src`],
  [c\#], [872], [tests, dotnet test], [`make verify-csharp`],
  [javascript], [860], [tests, node test runner], [`node --test` over `test/*.test.mjs`],
  [python], [232 files, 3239], [asserts, one ok line per file], [`make verify-py` scope `books/dsa/samples-py/src`],
  [lua], [1017], [checks, the run.lua runner], [`make verify-lua`],
)

The icpc toolbox suites ride beside these in book 11 and share
the same eight toolchains, 26 c\# tests, 36 javascript tests, 67
python asserts, 45 lua checks, and 278 rust checks over 6 to 11
files per language.

== pinned sources

Every chapter ends with its own sources line naming the official
pages consulted while writing it. The book level pins are:

#table(
  columns: (1.7fr, 2.3fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

The six-language wave pinned six toolchains, verified 2026-09-14
against the gates above, the java wave adds the seventh, verified
2026-10-06, and the rust wave the eighth, verified 2026-10-13:

#let toolchains = (
  (topic: [c], pin: [clang 23, `-std=c23`, msvc headers, lld], url: [releases.llvm.org], accessed: [2026-09-14]),
  (topic: [rust], pin: [rustc 1.99.0, edition 2024, msvc], url: [static.rust-lang.org], accessed: [2026-10-13]),
  (topic: [go], pin: [go 1.27], url: [go.dev/dl], accessed: [2026-09-14]),
  (topic: [java], pin: [oracle jdk 27, build 27+35-2325], url: [download.oracle.com/java/27], accessed: [2026-10-06]),
  (topic: [c\#], pin: [dotnet sdk 10.0.401, net10.0], url: [dotnet.microsoft.com], accessed: [2026-09-14]),
  (topic: [javascript], pin: [node 26.3.0, esm], url: [nodejs.org], accessed: [2026-09-14]),
  (topic: [python], pin: [cpython 3.14.7], url: [python.org], accessed: [2026-09-14]),
  (topic: [lua], pin: [lua 5.5, built as tools/lua55], url: [lua.org], accessed: [2026-09-14]),
)

#table(
  columns: (auto, 2.3fr, 1.6fr, auto),
  inset: 4pt,
  table.header([*topic*], [*pin*], [*url*], [*accessed*]),
  ..toolchains.map(s => ([#s.topic], [#s.pin], [#s.url], [#s.accessed])).flatten(),
)

#diagram([the pin set on its access timeline, ten pins in four groups, all on one date], length: 13pt, {
  // every source above carries accessed 2026-09-08
  cdraw.content((12.0, 7.9), [the pins, all accessed 2026-09-08], size: 6.5pt)
  cdraw.line((14.0, 0.8), (14.0, 7.1), stroke: luma(100))
  cdraw.circle((14.0, 3.95), radius: 0.1, fill: luma(100))
  let tick = y => cdraw.line((13.2, y), (13.9, y), stroke: luma(220))
  tick(6.8)
  cdraw.content((6.5, 6.8), [microsoft docs: collections, spans, apis], size: 6pt)
  tick(5.7)
  cdraw.content((6.5, 5.7), [priority queue, net 9, integration tests], size: 6pt)
  tick(4.6)
  cdraw.content((6.5, 4.6), [htmx docs and the npm package pin], size: 6pt)
  tick(3.5)
  cdraw.content((6.5, 3.5), [benchmarkdotnet for the meters], size: 6pt)
  tick(2.4)
  cdraw.content((6.5, 2.4), [runtime probes run locally], size: 6pt)
  cdraw.content((19.0, 4.6), [4.0.0 from the npm next tag], size: 6pt)
  cdraw.content((19.0, 3.5), [verified by digest], size: 6pt)
  cdraw.content((6.5, 1.3), [one date, one toolchain: net 10.0.400], size: 6pt)
  cdraw.content((6.5, 0.2), [drift turns this table into a changelog], size: 6pt)
  cdraw.circle((17.5, 5.7), radius: 0.1, fill: luma(160))
  cdraw.content((19.0, 5.7), [the six toolchains pin 2026-09-14], size: 6pt)
})

#callout("note", "version drift rule", [
  These pins were verified 2026-09-08 against .NET 10.0.400 and
  the language version it ships, with htmx 4.0.0 taken from the npm
  `next` tag and vendored by digest. Findings that contradicted
  documentation, the absent BCL deque, the silent tolerance of
  inconsistent comparers, the single-dollar raw string brace rule,
  the floor-mid probe asymmetry, are recorded in their chapters as
  verified behavior of this toolchain, and this table is the
  changelog if a future release moves any of them.
])

#callout("note", "cross-language pins from the six-language wave", [
  Four findings are pinned at book level because they differ by
  language on purpose. C's mulmod runs add-and-double with a modulo
  every step because the 128-bit remainder helper fails to link on
  this toolchain, recorded in the chapter 16 listing header, and
  rust's twin mirrors c on purpose though its native `u128` links
  free. The chinese remainder implementations split policy, python
  refuses every non-coprime system while go and rust merge the
  consistent ones and refuse the conflict, chapter 16 names the
  difference. The skip list promotions are deterministic in seven
  languages with four stated policies, java and rust joining the
  ruler sequence, chapter 25. And chapter 22's interval convention is half-open
  where c\# and lua pin it, touching-fuses in the other six.
])
