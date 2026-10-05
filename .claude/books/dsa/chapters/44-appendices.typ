#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": dsabook
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= appendices: topic matrix and sources

The topic matrix is this book's audit trail, and the overhaul made
it six audit trails. Every structure and algorithm the chapters
build now exists once per language, built from scratch behind the
same fixtures and the same anchors, and every chapter listing reads
a real file that the pinned toolchain of its language compiles and
runs. The totals: c 222 files and 4140 checks, c\# 784 tests, go 724
tests, javascript 755 tests, python 222 files and 3007 asserts, lua
936 checks, and the c\# capstone of chapter 43 stays single-language
inside the same suite. Zero skipped anywhere.

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
  // table above: chapters 1 to 39, then 41, 42, and the capstone
  let data = ((2, 0), (2, 0), (2, 0), (2, 1), (2, 2), (3, 1), (2, 1), (3, 2), (1, 2), (0, 5), (0, 6), (0, 4), (4, 2), (1, 4), (0, 5), (2, 4), (0, 7), (0, 5), (0, 6), (0, 4), (1, 5), (0, 4), (0, 4), (0, 4), (2, 2), (0, 3), (0, 3), (1, 7), (4, 2), (1, 3), (0, 7), (1, 5), (0, 5), (1, 5), (0, 13), (1, 5), (0, 11), (0, 9), (0, 11), (0, 12), (0, 11), (3, 6))
  let nums = (range(1, 40) + (41, 42, 43))
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

== the six sample trees

One row per sample program, 222 of them across chapters 1 to 42,
and the file that carries it in each language. The roots, relative
to the book directory: c in `dsa/samples-c/src/ChNN`, c\# in
`dsa/samples/src/ChNN`, go in `dsa/samples-go/chNN`, javascript in
`dsa/samples-js/src`, python in `dsa/samples-py/src/ChNN`, lua in
`dsa/samples-lua`. The c\# tree splits most chapters across a few
files and groups sibling topics inside one file, so that column
sometimes repeats the grouping file, go spells one ch31 file
`disjoint_sparse.go` where the other trees say `disjointsparse`,
go's ch37 tree shares one `geo.go` helper beside its ten samples,
and chapter 15's naive matcher lives in its own file beside the
frozen original.

#[
#set text(size: 7.5pt)
#table(
  columns: (1.1fr, auto, 1.35fr, 1.35fr, 1.35fr, 1.5fr, 1.35fr, 1.5fr),
  inset: 3pt,
  table.header([*topic*], [*ch*], [*c*], [*c\#*], [*go*], [*javascript*], [*python*], [*lua*]),
  [allocs], [ch 1], [allocs.c], [Analysis.cs], [allocs.go], [ch01-allocs.mjs], [allocs.py], [ch01_allocs.lua],
  [countops], [ch 1], [countops.c], [Analysis.cs], [countops.go], [ch01-countops.mjs], [countops.py], [ch01_countops.lua],
  [probebin], [ch 1], [probebin.c], [Analysis.cs], [probebin.go], [ch01-probebin.mjs], [probebin.py], [ch01_probebin.lua],
  [bounds], [ch 2], [bounds.c], [Bounds.cs], [bounds.go], [ch02-bounds.mjs], [bounds.py], [ch02_bounds.lua],
  [cache], [ch 2], [cache.c], [Arrays.cs], [cache.go], [ch02-cache.mjs], [cache.py], [ch02_cache.lua],
  [rowmajor], [ch 2], [rowmajor.c], [Arrays.cs], [rowmajor.go], [ch02-rowmajor.mjs], [rowmajor.py], [ch02_rowmajor.lua],
  [spans], [ch 2], [spans.c], [Arrays.cs], [spans.go], [ch02-spans.mjs], [spans.py], [ch02_spans.lua],
  [growth], [ch 3], [growth.c], [Dynamic.cs], [growth.go], [ch03-growth.mjs], [growth.py], [ch03_growth.lua],
  [vector], [ch 3], [vector.c], [Dynamic.cs], [vector.go], [ch03-vector.mjs], [vector.py], [ch03_vector.lua],
  [ring], [ch 4], [ring.c], [Linked.cs], [ring.go], [ch04-ring.mjs], [ring.py], [ch04_ring.lua],
  [slist], [ch 4], [slist.c], [Linked.cs], [slist.go], [ch04-slist.mjs], [slist.py], [ch04_slist.lua],
  [deque], [ch 5], [deque.c], [Deque.cs], [deque.go], [ch05-deque.mjs], [deque.py], [ch05_deque.lua],
  [ringqueue], [ch 5], [ringqueue.c], [Buffers.cs], [ringqueue.go], [ch05-ringqueue.mjs], [ringqueue.py], [ch05_ringqueue.lua],
  [shunting], [ch 5], [shunting.c], [Buffers.cs], [shunting.go], [ch05-shunting.mjs], [shunting.py], [ch05_shunting.lua],
  [stack], [ch 5], [stack.c], [Buffers.cs], [stack.go], [ch05-stack.mjs], [stack.py], [ch05_stack.lua],
  [chainmap], [ch 6], [chainmap.c], [Hashing.cs], [chainmap.go], [ch06-chainmap.mjs], [chainmap.py], [ch06_chainmap.lua],
  [fnv], [ch 6], [fnv.c], [Hashing.cs], [fnv.go], [ch06-fnv.mjs], [fnv.py], [ch06_fnv.lua],
  [hashset], [ch 6], [hashset.c], [HashSet.cs], [hashset.go], [ch06-hashset.mjs], [hashset.py], [ch06_hashset.lua],
  [openaddr], [ch 6], [openaddr.c], [Hashing.cs], [openaddr.go], [ch06-openaddr.mjs], [openaddr.py], [ch06_openaddr.lua],
  [balance], [ch 7], [balance.c], [Trees.cs], [balance.go], [ch07-balance.mjs], [balance.py], [ch07_balance.lua],
  [bst], [ch 7], [bst.c], [Trees.cs], [bst.go], [ch07-bst.mjs], [bst.py], [ch07_bst.lua],
  [traverse], [ch 7], [traverse.c], [Trees.cs], [traverse.go], [ch07-traverse.mjs], [traverse.py], [ch07_traverse.lua],
  [heap], [ch 8], [heap.c], [Heaps.cs], [heap.go], [ch08-heap.mjs], [heap.py], [ch08_heap.lua],
  [heapsort], [ch 8], [heapsort.c], [Heaps.cs], [heapsort.go], [ch08-heapsort.mjs], [heapsort.py], [ch08_heapsort.lua],
  [kway], [ch 8], [kway.c], [Heaps.cs], [kway.go], [ch08-kway.mjs], [kway.py], [ch08_kway.lua],
  [topk], [ch 8], [topk.c], [TopK.cs], [topk.go], [ch08-topk.mjs], [topk.py], [ch08_topk.lua],
  [prefixscan], [ch 9], [prefixscan.c], [Tries.cs], [prefixscan.go], [ch09-prefixscan.mjs], [prefixscan.py], [ch09_prefixscan.lua],
  [suffixarray], [ch 9], [suffixarray.c], [Tries.cs], [suffixarray.go], [ch09-suffixarray.mjs], [suffixarray.py], [ch09_suffixarray.lua],
  [suffixsearch], [ch 9], [suffixsearch.c], [Tries.cs], [suffixsearch.go], [ch09-suffixsearch.mjs], [suffixsearch.py], [ch09_suffixsearch.lua],
  [trie], [ch 9], [trie.c], [Tries.cs], [trie.go], [ch09-trie.mjs], [trie.py], [ch09_trie.lua],
  [bfs], [ch 10], [bfs.c], [Graphs.cs], [bfs.go], [ch10-bfs.mjs], [bfs.py], [ch10_bfs.lua],
  [build], [ch 10], [build.c], [Graphs.cs], [build.go], [ch10-build.mjs], [build.py], [ch10_build.lua],
  [components], [ch 10], [components.c], [Graphs.cs], [components.go], [ch10-components.mjs], [components.py], [ch10_components.lua],
  [dfs], [ch 10], [dfs.c], [Graphs.cs], [dfs.go], [ch10-dfs.mjs], [dfs.py], [ch10_dfs.lua],
  [topo], [ch 10], [topo.c], [Graphs.cs], [topo.go], [ch10-topo.mjs], [topo.py], [ch10_topo.lua],
  [astar], [ch 11], [astar.c], [Paths.cs], [astar.go], [ch11-astar.mjs], [astar.py], [ch11_astar.lua],
  [bellman], [ch 11], [bellman.c], [Paths.cs], [bellman.go], [ch11-bellman.mjs], [bellman.py], [ch11_bellman.lua],
  [dijkstra], [ch 11], [dijkstra.c], [Paths.cs], [dijkstra.go], [ch11-dijkstra.mjs], [dijkstra.py], [ch11_dijkstra.lua],
  [floyd], [ch 11], [floyd.c], [Paths.cs], [floyd.go], [ch11-floyd.mjs], [floyd.py], [ch11_floyd.lua],
  [dsu], [ch 12], [dsu.c], [Flows.cs], [dsu.go], [ch12-dsu.mjs], [dsu.py], [ch12_dsu.lua],
  [kruskal], [ch 12], [kruskal.c], [Flows.cs], [kruskal.go], [ch12-kruskal.mjs], [kruskal.py], [ch12_kruskal.lua],
  [maxflow], [ch 12], [maxflow.c], [Flows.cs], [maxflow.go], [ch12-maxflow.mjs], [maxflow.py], [ch12_maxflow.lua],
  [mincut], [ch 12], [mincut.c], [Flows.cs], [mincut.go], [ch12-mincut.mjs], [mincut.py], [ch12_mincut.lua],
  [prim], [ch 12], [prim.c], [Flows.cs], [prim.go], [ch12-prim.mjs], [prim.py], [ch12_prim.lua],
  [counting], [ch 13], [counting.c], [Sorting.cs], [counting.go], [ch13-counting.mjs], [counting.py], [ch13_counting.lua],
  [insertion], [ch 13], [insertion.c], [Sorting.cs], [insertion.go], [ch13-insertion.mjs], [insertion.py], [ch13_insertion.lua],
  [mergesort], [ch 13], [mergesort.c], [Sorting.cs], [mergesort.go], [ch13-mergesort.mjs], [mergesort.py], [ch13_mergesort.lua],
  [quickselect], [ch 13], [quickselect.c], [Sorting.cs], [quickselect.go], [ch13-quickselect.mjs], [quickselect.py], [ch13_quickselect.lua],
  [quicksort], [ch 13], [quicksort.c], [Sorting.cs], [quicksort.go], [ch13-quicksort.mjs], [quicksort.py], [ch13_quicksort.lua],
  [stability], [ch 13], [stability.c], [Sorting.cs], [stability.go], [ch13-stability.mjs], [stability.py], [ch13_stability.lua],
  [answerspace], [ch 14], [answerspace.c], [Searching.cs], [answerspace.go], [ch14-answerspace.mjs], [answerspace.py], [ch14_answerspace.lua],
  [bounds], [ch 14], [bounds.c], [Searching.cs], [bounds.go], [ch14-bounds.mjs], [bounds.py], [ch14_bounds.lua],
  [kadane], [ch 14], [kadane.c], [Searching.cs], [kadane.go], [ch14-kadane.mjs], [kadane.py], [ch14_kadane.lua],
  [mex], [ch 14], [mex.c], [Searching.cs], [mex.go], [ch14-mex.mjs], [mex.py], [ch14_mex.lua],
  [rotated], [ch 14], [rotated.c], [Searching.cs], [rotated.go], [ch14-rotated.mjs], [rotated.py], [ch14_rotated.lua],
  [aho], [ch 15], [aho.c], [Strings.cs], [aho.go], [ch15-aho.mjs], [aho.py], [ch15_aho.lua],
  [horspool], [ch 15], [horspool.c], [Strings.cs], [horspool.go], [ch15-horspool.mjs], [horspool.py], [ch15_horspool.lua],
  [kmp], [ch 15], [kmp.c], [Strings.cs], [kmp.go], [ch15-kmp.mjs], [kmp.py], [ch15_kmp.lua],
  [naive], [ch 15], [naive.c], [Naive.cs], [naive.go], [ch15-naive.mjs], [naive.py], [ch15_naive.lua],
  [rabinkarp], [ch 15], [rabinkarp.c], [Strings.cs], [rabinkarp.go], [ch15-rabinkarp.mjs], [rabinkarp.py], [ch15_rabinkarp.lua],
  [crt], [ch 16], [crt.c], [NumTheory.cs], [crt.go], [ch16-crt.mjs], [crt.py], [ch16_crt.lua],
  [factors], [ch 16], [factors.c], [NumTheory.cs], [factors.go], [ch16-factors.mjs], [factors.py], [ch16_factors.lua],
  [gcdlcm], [ch 16], [gcdlcm.c], [NumTheory.cs], [gcdlcm.go], [ch16-gcdlcm.mjs], [gcdlcm.py], [ch16_gcdlcm.lua],
  [modinv], [ch 16], [modinv.c], [NumTheory.cs], [modinv.go], [ch16-modinv.mjs], [modinv.py], [ch16_modinv.lua],
  [modpow], [ch 16], [modpow.c], [NumTheory.cs], [modpow.go], [ch16-modpow.mjs], [modpow.py], [ch16_modpow.lua],
  [sieve], [ch 16], [sieve.c], [NumTheory.cs], [sieve.go], [ch16-sieve.mjs], [sieve.py], [ch16_sieve.lua],
  [assignment], [ch 17], [assignment.c], [Dp.cs], [assignment.go], [ch17-assignment.mjs], [assignment.py], [ch17_assignment.lua],
  [coins], [ch 17], [coins.c], [Dp.cs], [coins.go], [ch17-coins.mjs], [coins.py], [ch17_coins.lua],
  [editdist], [ch 17], [editdist.c], [Dp.cs], [editdist.go], [ch17-editdist.mjs], [editdist.py], [ch17_editdist.lua],
  [gridpaths], [ch 17], [gridpaths.c], [Dp.cs], [gridpaths.go], [ch17-gridpaths.mjs], [gridpaths.py], [ch17_gridpaths.lua],
  [knapsack], [ch 17], [knapsack.c], [Dp.cs], [knapsack.go], [ch17-knapsack.mjs], [knapsack.py], [ch17_knapsack.lua],
  [lis], [ch 17], [lis.c], [Dp.cs], [lis.go], [ch17-lis.mjs], [lis.py], [ch17_lis.lua],
  [memo], [ch 17], [memo.c], [Dp.cs], [memo.go], [ch17-memo.mjs], [memo.py], [ch17_memo.lua],
  [backtrack], [ch 18], [backtrack.c], [Greedy.cs], [backtrack.go], [ch18-backtrack.mjs], [backtrack.py], [ch18_backtrack.lua],
  [huffman], [ch 18], [huffman.c], [Greedy.cs], [huffman.go], [ch18-huffman.mjs], [huffman.py], [ch18_huffman.lua],
  [intervals], [ch 18], [intervals.c], [Greedy.cs], [intervals.go], [ch18-intervals.mjs], [intervals.py], [ch18_intervals.lua],
  [jumpgame], [ch 18], [jumpgame.c], [JumpGame.cs], [jumpgame.go], [ch18-jumpgame.mjs], [jumpgame.py], [ch18_jumpgame.lua],
  [bitmask], [ch 19], [bitmask.c], [AdvDp.cs], [bitmask.go], [ch19-bitmask.mjs], [bitmask.py], [ch19_bitmask.lua],
  [bounded], [ch 19], [bounded.c], [AdvDp.cs], [bounded.go], [ch19-bounded.mjs], [bounded.py], [ch19_bounded.lua],
  [cht], [ch 19], [cht.c], [AdvDp.cs], [cht.go], [ch19-cht.mjs], [cht.py], [ch19_cht.lua],
  [digitdp], [ch 19], [digitdp.c], [DigitDp.cs], [digitdp.go], [ch19-digitdp.mjs], [digitdp.py], [ch19_digitdp.lua],
  [grouped], [ch 19], [grouped.c], [AdvDp.cs], [grouped.go], [ch19-grouped.mjs], [grouped.py], [ch19_grouped.lua],
  [intervaldp], [ch 19], [intervaldp.c], [IntervalDp.cs], [intervaldp.go], [ch19-intervaldp.mjs], [intervaldp.py], [ch19_intervaldp.lua],
  [tails], [ch 19], [tails.c], [AdvDp.cs], [tails.go], [ch19-tails.mjs], [tails.py], [ch19_tails.lua],
  [window], [ch 19], [window.c], [AdvDp.cs], [window.go], [ch19-window.mjs], [window.py], [ch19_window.lua],
  [alphabeta], [ch 20], [alphabeta.c], [Pruning.cs], [alphabeta.go], [ch20-alphabeta.mjs], [alphabeta.py], [ch20_alphabeta.lua],
  [bandb], [ch 20], [bandb.c], [Pruning.cs], [bandb.go], [ch20-bandb.mjs], [bandb.py], [ch20_bandb.lua],
  [memo_vs_prune], [ch 20], [memo_vs_prune.c], [Pruning.cs], [memo_vs_prune.go], [ch20-memo_vs_prune.mjs], [memo_vs_prune.py], [ch20_memo_vs_prune.lua],
  [nqueens], [ch 20], [nqueens.c], [Pruning.cs], [nqueens.go], [ch20-nqueens.mjs], [nqueens.py], [ch20_nqueens.lua],
  [fenwick], [ch 21], [fenwick.c], [Ranges.cs], [fenwick.go], [ch21-fenwick.mjs], [fenwick.py], [ch21_fenwick.lua],
  [maxima], [ch 21], [maxima.c], [Ranges.cs], [maxima.go], [ch21-maxima.mjs], [maxima.py], [ch21_maxima.lua],
  [nextgreater], [ch 21], [nextgreater.c], [Ranges.cs], [nextgreater.go], [ch21-nextgreater.mjs], [nextgreater.py], [ch21_nextgreater.lua],
  [prefix], [ch 21], [prefix.c], [Prefix.cs], [prefix.go], [ch21-prefix.mjs], [prefix.py], [ch21_prefix.lua],
  [segtree], [ch 21], [segtree.c], [Ranges.cs], [segtree.go], [ch21-segtree.mjs], [segtree.py], [ch21_segtree.lua],
  [sparsetable], [ch 21], [sparsetable.c], [Ranges.cs], [sparsetable.go], [ch21-sparsetable.mjs], [sparsetable.py], [ch21_sparsetable.lua],
  [coordcompress], [ch 22], [coordcompress.c], [Compression.cs], [coordcompress.go], [ch22-coordcompress.mjs], [coordcompress.py], [ch22_coordcompress.lua],
  [diffarray], [ch 22], [diffarray.c], [Compression.cs], [diffarray.go], [ch22-diffarray.mjs], [diffarray.py], [ch22_diffarray.lua],
  [mergeintervals], [ch 22], [mergeintervals.c], [Compression.cs], [mergeintervals.go], [ch22-mergeintervals.mjs], [mergeintervals.py], [ch22_mergeintervals.lua],
  [overlaps], [ch 22], [overlaps.c], [Compression.cs], [overlaps.go], [ch22-overlaps.mjs], [overlaps.py], [ch22_overlaps.lua],
  [closestpair], [ch 23], [closestpair.c], [Geometry.cs], [closestpair.go], [ch23-closestpair.mjs], [closestpair.py], [ch23_closestpair.lua],
  [hull], [ch 23], [hull.c], [Geometry.cs], [hull.go], [ch23-hull.mjs], [hull.py], [ch23_hull.lua],
  [orientation], [ch 23], [orientation.c], [Geometry.cs], [orientation.go], [ch23-orientation.mjs], [orientation.py], [ch23_orientation.lua],
  [sweep], [ch 23], [sweep.c], [Geometry.cs], [sweep.go], [ch23-sweep.mjs], [sweep.py], [ch23_sweep.lua],
  [floodfill], [ch 24], [floodfill.c], [Lattice.cs], [floodfill.go], [ch24-floodfill.mjs], [floodfill.py], [ch24_floodfill.lua],
  [neighbors], [ch 24], [neighbors.c], [Lattice.cs], [neighbors.go], [ch24-neighbors.mjs], [neighbors.py], [ch24_neighbors.lua],
  [raycast], [ch 24], [raycast.c], [Lattice.cs], [raycast.go], [ch24-raycast.mjs], [raycast.py], [ch24_raycast.lua],
  [shoelace], [ch 24], [shoelace.c], [Lattice.cs], [shoelace.go], [ch24-shoelace.mjs], [shoelace.py], [ch24_shoelace.lua],
  [bloom], [ch 25], [bloom.c], [Practical.cs], [bloom.go], [ch25-bloom.mjs], [bloom.py], [ch25_bloom.lua],
  [countmin], [ch 25], [countmin.c], [Practical.cs], [countmin.go], [ch25-countmin.mjs], [countmin.py], [ch25_countmin.lua],
  [lru], [ch 25], [lru.c], [Practical.cs], [lru.go], [ch25-lru.mjs], [lru.py], [ch25_lru.lua],
  [skiplist], [ch 25], [skiplist.c], [Practical.cs], [skiplist.go], [ch25-skiplist.mjs], [skiplist.py], [ch25_skiplist.lua],
  [asteval], [ch 26], [asteval.c], [Parsing.cs], [asteval.go], [ch26-asteval.mjs], [asteval.py], [ch26_asteval.lua],
  [rdparse], [ch 26], [rdparse.c], [Parsing.cs], [rdparse.go], [ch26-rdparse.mjs], [rdparse.py], [ch26_rdparse.lua],
  [tokens], [ch 26], [tokens.c], [Parsing.cs], [tokens.go], [ch26-tokens.mjs], [tokens.py], [ch26_tokens.lua],
  [jumps], [ch 27], [jumps.c], [Machine.cs], [jumps.go], [ch27-jumps.mjs], [jumps.py], [ch27_jumps.lua],
  [modes], [ch 27], [modes.c], [Machine.cs], [modes.go], [ch27-modes.mjs], [modes.py], [ch27_modes.lua],
  [opcodes], [ch 27], [opcodes.c], [Machine.cs], [opcodes.go], [ch27-opcodes.mjs], [opcodes.py], [ch27_opcodes.lua],
  [cfrac], [ch 28], [cfrac.c], [CFrac.cs], [cfrac.go], [ch28-cfrac.mjs], [cfrac.py], [ch28_cfrac.lua],
  [diophantine], [ch 28], [diophantine.c], [Diophantine.cs], [diophantine.go], [ch28-diophantine.mjs], [diophantine.py], [ch28_diophantine.lua],
  [dlog], [ch 28], [dlog.c], [DLog.cs], [dlog.go], [ch28-dlog.mjs], [dlog.py], [ch28_dlog.lua],
  [garner], [ch 28], [garner.c], [Garner.cs], [garner.go], [ch28-garner.mjs], [garner.py], [ch28_garner.lua],
  [graytern], [ch 28], [graytern.c], [GrayTern.cs], [graytern.go], [ch28-graytern.mjs], [graytern.py], [ch28_graytern.lua],
  [linsieve], [ch 28], [linsieve.c], [LinSieve.cs], [linsieve.go], [ch28-linsieve.mjs], [linsieve.py], [ch28_linsieve.lua],
  [primality], [ch 28], [primality.c], [Primality.cs], [primality.go], [ch28-primality.mjs], [primality.py], [ch28_primality.lua],
  [totdiv], [ch 28], [totdiv.c], [TotDiv.cs], [totdiv.go], [ch28-totdiv.mjs], [totdiv.py], [ch28_totdiv.lua],
  [bigint], [ch 29], [bigint.c], [BigNum.cs], [bigint.go], [ch29-bigint.mjs], [bigint.py], [ch29_bigint.lua],
  [divmod], [ch 29], [divmod.c], [DivMod.cs], [divmod.go], [ch29-divmod.mjs], [divmod.py], [ch29_divmod.lua],
  [fft], [ch 29], [fft.c], [Fft.cs], [fft.go], [ch29-fft.mjs], [fft.py], [ch29_fft.lua],
  [karatsuba], [ch 29], [karatsuba.c], [Karatsuba.cs], [karatsuba.go], [ch29-karatsuba.mjs], [karatsuba.py], [ch29_karatsuba.lua],
  [ntt], [ch 29], [ntt.c], [Ntt.cs], [ntt.go], [ch29-ntt.mjs], [ntt.py], [ch29_ntt.lua],
  [polyops], [ch 29], [polyops.c], [PolyOps.cs], [polyops.go], [ch29-polyops.mjs], [polyops.py], [ch29_polyops.lua],
  [mergeheap], [ch 30], [mergeheap.c], [MergeHeap.cs], [mergeheap.go], [ch30-mergeheap.mjs], [mergeheap.py], [ch30_mergeheap.lua],
  [orderstats], [ch 30], [orderstats.c], [OrderStats.cs], [orderstats.go], [ch30-orderstats.mjs], [orderstats.py], [ch30_orderstats.lua],
  [treap], [ch 30], [treap.c], [Treap.cs], [treap.go], [ch30-treap.mjs], [treap.py], [ch30_treap.lua],
  [disjointsparse], [ch 31], [disjointsparse.c], [DisjointSparse.cs], [disjoint_sparse.go], [ch31-disjointsparse.mjs], [disjointsparse.py], [ch31_disjointsparse.lua],
  [lichao], [ch 31], [lichao.c], [LiChao.cs], [lichao.go], [ch31-lichao.mjs], [lichao.py], [ch31_lichao.lua],
  [minstack], [ch 31], [minstack.c], [MinStack.cs], [minstack.go], [ch31-minstack.mjs], [minstack.py], [ch31_minstack.lua],
  [mos], [ch 31], [mos.c], [Mos.cs], [mos.go], [ch31-mos.mjs], [mos.py], [ch31_mos.lua],
  [offlinedynconn], [ch 31], [offlinedynconn.c], [OfflineDynConn.cs], [offlinedynconn.go], [ch31-offlinedynconn.mjs], [offlinedynconn.py], [ch31_offlinedynconn.lua],
  [rollbackdsu], [ch 31], [rollbackdsu.c], [RollbackDsu.cs], [rollbackdsu.go], [ch31-rollbackdsu.mjs], [rollbackdsu.py], [ch31_rollbackdsu.lua],
  [sqrtblocks], [ch 31], [sqrtblocks.c], [SqrtBlocks.cs], [sqrtblocks.go], [ch31-sqrtblocks.mjs], [sqrtblocks.py], [ch31_sqrtblocks.lua],
  [brokenprofile], [ch 32], [brokenprofile.c], [BrokenProfile.cs], [brokenprofile.go], [ch32-brokenprofile.mjs], [brokenprofile.py], [ch32_brokenprofile.lua],
  [dncdp], [ch 32], [dncdp.c], [DncDp.cs], [dncdp.go], [ch32-dncdp.mjs], [dncdp.py], [ch32_dncdp.lua],
  [knuth], [ch 32], [knuth.c], [Knuth.cs], [knuth.go], [ch32-knuth.mjs], [knuth.py], [ch32_knuth.lua],
  [slopetrick], [ch 32], [slopetrick.c], [SlopeTrick.cs], [slopetrick.go], [ch32-slopetrick.mjs], [slopetrick.py], [ch32_slopetrick.lua],
  [valueiter], [ch 32], [valueiter.c], [ValueIter.cs], [valueiter.go], [ch32-valueiter.mjs], [valueiter.py], [ch32_valueiter.lua],
  [lyndon], [ch 33], [lyndon.c], [Lyndon.cs], [lyndon.go], [ch33-lyndon.mjs], [lyndon.py], [ch33_lyndon.lua],
  [manacher], [ch 33], [manacher.c], [Manacher.cs], [manacher.go], [ch33-manacher.mjs], [manacher.py], [ch33_manacher.lua],
  [suffixautomaton], [ch 33], [suffixautomaton.c], [SuffixAutomaton.cs], [suffixautomaton.go], [ch33-suffixautomaton.mjs], [suffixautomaton.py], [ch33_suffixautomaton.lua],
  [suffixtree], [ch 33], [suffixtree.c], [SuffixTree.cs], [suffixtree.go], [ch33-suffixtree.mjs], [suffixtree.py], [ch33_suffixtree.lua],
  [zfunc], [ch 33], [zfunc.c], [Zfunc.cs], [zfunc.go], [ch33-zfunc.mjs], [zfunc.py], [ch33_zfunc.lua],
  [cramer], [ch 34], [cramer.c], [Cramer.cs], [cramer.go], [ch34-cramer.mjs], [cramer.py], [ch34_cramer.lua],
  [determinant], [ch 34], [determinant.c], [Determinant.cs], [determinant.go], [ch34-determinant.mjs], [determinant.py], [ch34_determinant.lua],
  [gauss], [ch 34], [gauss.c], [Gauss.cs], [gauss.go], [ch34-gauss.mjs], [gauss.py], [ch34_gauss.lua],
  [kirchhoff], [ch 34], [kirchhoff.c], [Kirchhoff.cs], [kirchhoff.go], [ch34-kirchhoff.mjs], [kirchhoff.py], [ch34_kirchhoff.lua],
  [matpow], [ch 34], [matpow.c], [Matpow.cs], [matpow.go], [ch34-matpow.mjs], [matpow.py], [ch34_matpow.lua],
  [zpk], [ch 34], [zpk.c], [Zpk.cs], [zpk.go], [ch34-zpk.mjs], [zpk.py], [ch34_zpk.lua],
  [binom], [ch 35], [binom.c], [Binom.cs], [binom.go], [ch35-binom.mjs], [binom.py], [ch35_binom.lua],
  [bishops], [ch 35], [bishops.c], [Bishops.cs], [bishops.go], [ch35-bishops.mjs], [bishops.py], [ch35_bishops.lua],
  [brackets], [ch 35], [brackets.c], [Brackets.cs], [brackets.go], [ch35-brackets.mjs], [brackets.py], [ch35_brackets.lua],
  [burnside], [ch 35], [burnside.c], [Burnside.cs], [burnside.go], [ch35-burnside.mjs], [burnside.py], [ch35_burnside.lua],
  [catalan], [ch 35], [catalan.c], [Catalan.cs], [catalan.go], [ch35-catalan.mjs], [catalan.py], [ch35_catalan.lua],
  [frobenius], [ch 35], [frobenius.c], [Frobenius.cs], [frobenius.go], [ch35-frobenius.mjs], [frobenius.py], [ch35_frobenius.lua],
  [incexc], [ch 35], [incexc.c], [IncExc.cs], [incexc.go], [ch35-incexc.mjs], [incexc.py], [ch35_incexc.lua],
  [josephus], [ch 35], [josephus.c], [Josephus.cs], [josephus.go], [ch35-josephus.mjs], [josephus.py], [ch35_josephus.lua],
  [ksubset], [ch 35], [ksubset.c], [KSubset.cs], [ksubset.go], [ch35-ksubset.mjs], [ksubset.py], [ch35_ksubset.lua],
  [labeled], [ch 35], [labeled.c], [Labeled.cs], [labeled.go], [ch35-labeled.mjs], [labeled.py], [ch35_labeled.lua],
  [sperner], [ch 35], [sperner.c], [Sperner.cs], [sperner.go], [ch35-sperner.mjs], [sperner.py], [ch35_sperner.lua],
  [starsbars], [ch 35], [starsbars.c], [StarsBars.cs], [starsbars.go], [ch35-starsbars.mjs], [starsbars.py], [ch35_starsbars.lua],
  [golden], [ch 36], [golden.c], [Golden.cs], [golden.go], [ch36-golden.mjs], [golden.py], [ch36_golden.lua],
  [lpdual], [ch 36], [lpdual.c], [LpDual.cs], [lpdual.go], [ch36-lpdual.mjs], [lpdual.py], [ch36_lpdual.lua],
  [newton], [ch 36], [newton.c], [Newton.cs], [newton.go], [ch36-newton.mjs], [newton.py], [ch36_newton.lua],
  [simpson], [ch 36], [simpson.c], [Simpson.cs], [simpson.go], [ch36-simpson.mjs], [simpson.py], [ch36_simpson.lua],
  [ternary], [ch 36], [ternary.c], [Ternary.cs], [ternary.go], [ch36-ternary.mjs], [ternary.py], [ch36_ternary.lua],
  [calipers], [ch 37], [calipers.c], [Calipers.cs], [calipers.go], [ch37-calipers.mjs], [calipers.py], [ch37_calipers.lua],
  [circles], [ch 37], [circles.c], [Geometry2.cs], [circles.go], [ch37-circles.mjs], [circles.py], [ch37_circles.lua],
  [halfplane], [ch 37], [halfplane.c], [Calipers.cs], [halfplane.go], [ch37-halfplane.mjs], [halfplane.py], [ch37_halfplane.lua],
  [manhattan], [ch 37], [manhattan.c], [Calipers.cs], [manhattan.go], [ch37-manhattan.mjs], [manhattan.py], [ch37_manhattan.lua],
  [mincircle], [ch 37], [mincircle.c], [Calipers.cs], [mincircle.go], [ch37-mincircle.mjs], [mincircle.py], [ch37_mincircle.lua],
  [minkowski], [ch 37], [minkowski.c], [Geometry2.cs], [minkowski.go], [ch37-minkowski.mjs], [minkowski.py], [ch37_minkowski.lua],
  [ottmann], [ch 37], [ottmann.c], [Voronoi.cs], [ottmann.go], [ch37-ottmann.mjs], [ottmann.py], [ch37_ottmann.lua],
  [pinconvex], [ch 37], [pinconvex.c], [Geometry2.cs], [pinconvex.go], [ch37-pinconvex.mjs], [pinconvex.py], [ch37_pinconvex.lua],
  [segunion], [ch 37], [segunion.c], [Geometry2.cs], [segunion.go], [ch37-segunion.mjs], [segunion.py], [ch37_segunion.lua],
  [voronoi], [ch 37], [voronoi.c], [Voronoi.cs], [voronoi.go], [ch37-voronoi.mjs], [voronoi.py], [ch37_voronoi.lua],
  [assign], [ch 38], [assign.c], [Hungarian.cs], [assign.go], [ch38-assign.mjs], [assign.py], [ch38_assign.lua],
  [demands], [ch 38], [demands.c], [Costs2.cs], [demands.go], [ch38-demands.mjs], [demands.py], [ch38_demands.lua],
  [dinic], [ch 38], [dinic.c], [Flow2.cs], [dinic.go], [ch38-dinic.mjs], [dinic.py], [ch38_dinic.lua],
  [hall], [ch 38], [hall.c], [Match.cs], [hall.go], [ch38-hall.mjs], [hall.py], [ch38_hall.lua],
  [hungarian], [ch 38], [hungarian.c], [Hungarian.cs], [hungarian.go], [ch38-hungarian.mjs], [hungarian.py], [ch38_hungarian.lua],
  [kuhn], [ch 38], [kuhn.c], [Match.cs], [kuhn.go], [ch38-kuhn.mjs], [kuhn.py], [ch38_kuhn.lua],
  [mcmf], [ch 38], [mcmf.c], [Costs2.cs], [mcmf.go], [ch38-mcmf.mjs], [mcmf.py], [ch38_mcmf.lua],
  [pushrelabel], [ch 38], [pushrelabel.c], [Flow2.cs], [pushrelabel.go], [ch38-pushrelabel.mjs], [pushrelabel.py], [ch38_pushrelabel.lua],
  [stoerwagner], [ch 38], [stoerwagner.c], [Cuts.cs], [stoerwagner.go], [ch38-stoerwagner.mjs], [stoerwagner.py], [ch38_stoerwagner.lua],
  [bridges], [ch 39], [bridges.c], [Edges.cs], [bridges.go], [ch39-bridges.mjs], [bridges.py], [ch39_bridges.lua],
  [centroid], [ch 39], [centroid.c], [Centers.cs], [centroid.go], [ch39-centroid.mjs], [centroid.py], [ch39_centroid.lua],
  [euler], [ch 39], [euler.c], [Edges.cs], [euler.go], [ch39-euler.mjs], [euler.py], [ch39_euler.lua],
  [functional], [ch 39], [functional.c], [Centers.cs], [functional.go], [ch39-functional.mjs], [functional.py], [ch39_functional.lua],
  [hld], [ch 39], [hld.c], [Paths2.cs], [hld.go], [ch39-hld.mjs], [hld.py], [ch39_hld.lua],
  [lca], [ch 39], [lca.c], [Paths2.cs], [lca.go], [ch39-lca.mjs], [lca.py], [ch39_lca.lua],
  [prufer], [ch 39], [prufer.c], [Prufer.cs], [prufer.go], [ch39-prufer.mjs], [prufer.py], [ch39_prufer.lua],
  [scc], [ch 39], [scc.c], [Strong.cs], [scc.go], [ch39-scc.mjs], [scc.py], [ch39_scc.lua],
  [twocore], [ch 39], [twocore.c], [Centers.cs], [twocore.go], [ch39-twocore.mjs], [twocore.py], [ch39_twocore.lua],
  [twosat], [ch 39], [twosat.c], [Strong.cs], [twosat.go], [ch39-twosat.mjs], [twosat.py], [ch39_twosat.lua],
  [graphgames], [ch 40], [graphgames.c], [GraphGames.cs], [graphgames.go], [ch40-graphgames.mjs], [graphgames.py], [ch40_graphgames.lua],
  [grundy], [ch 40], [grundy.c], [Grundy.cs], [grundy.go], [ch40-grundy.mjs], [grundy.py], [ch40_grundy.lua],
  [scheduling], [ch 40], [scheduling.c], [Scheduling.cs], [scheduling.go], [ch40-scheduling.mjs], [scheduling.py], [ch40_scheduling.lua],
  [aco], [ch 41], [aco.c], [Aco.cs], [aco.go], [ch41-aco.mjs], [aco.py], [ch41_aco.lua],
  [anneal], [ch 41], [anneal.c], [Anneal.cs], [anneal.go], [ch41-anneal.mjs], [anneal.py], [ch41_anneal.lua],
  [ga], [ch 41], [ga.c], [Ga.cs], [ga.go], [ch41-ga.mjs], [ga.py], [ch41_ga.lua],
  [hill], [ch 41], [hill.c], [Hill.cs], [hill.go], [ch41-hill.mjs], [hill.py], [ch41_hill.lua],
  [localsearch], [ch 41], [localsearch.c], [Localsearch.cs], [localsearch.go], [ch41-localsearch.mjs], [localsearch.py], [ch41_localsearch.lua],
  [restarts], [ch 41], [restarts.c], [Restarts.cs], [restarts.go], [ch41-restarts.mjs], [restarts.py], [ch41_restarts.lua],
  [tabu], [ch 41], [tabu.c], [Tabu.cs], [tabu.go], [ch41-tabu.mjs], [tabu.py], [ch41_tabu.lua],
  [twoopt], [ch 41], [twoopt.c], [TwoOpt.cs], [twoopt.go], [ch41-twoopt.mjs], [twoopt.py], [ch41_twoopt.lua],
  [binpack], [ch 42], [binpack.c], [Binpack.cs], [binpack.go], [ch42-binpack.mjs], [binpack.py], [ch42_binpack.lua],
  [christofides], [ch 42], [christofides.c], [Christofides.cs], [christofides.go], [ch42-christofides.mjs], [christofides.py], [ch42_christofides.lua],
  [maxcut], [ch 42], [maxcut.c], [Maxcut.cs], [maxcut.go], [ch42-maxcut.mjs], [maxcut.py], [ch42_maxcut.lua],
  [ptas], [ch 42], [ptas.c], [Ptas.cs], [ptas.go], [ch42-ptas.mjs], [ptas.py], [ch42_ptas.lua],
  [ratio], [ch 42], [ratio.c], [Ratio.cs], [ratio.go], [ch42-ratio.mjs], [ratio.py], [ch42_ratio.lua],
  [setcover], [ch 42], [setcover.c], [Setcover.cs], [setcover.go], [ch42-setcover.mjs], [setcover.py], [ch42_setcover.lua],
  [tsp2x], [ch 42], [tsp2x.c], [Tsp2x.cs], [tsp2x.go], [ch42-tsp2x.mjs], [tsp2x.py], [ch42_tsp2x.lua],
  [vc], [ch 42], [vc.c], [Vc.cs], [vc.go], [ch42-vc.mjs], [vc.py], [ch42_vc.lua],
)

]

#table(
  columns: (auto, 1.2fr, 1.4fr, 1.8fr),
  inset: 4pt,
  table.header([*language*], [*suite size*], [*unit*], [*gate*]),
  [c], [222 files, 4140], [checks, one ok line per file], [`make verify-c` scope `books/dsa/samples-c/src`],
  [c\#], [784], [tests, dotnet test], [`make verify-csharp`],
  [go], [724], [tests, go test], [`make verify-go`],
  [javascript], [755], [tests, node test runner], [`node --test` over `test/*.test.mjs`],
  [python], [222 files, 3007], [asserts, one ok line per file], [`make verify-py` scope `books/dsa/samples-py/src`],
  [lua], [936], [checks, the run.lua runner], [`make verify-lua`],
)

The icpc toolbox suites ride beside these in book 10 and share
the same six toolchains, 26 c\# tests, 36 javascript tests, 67
python asserts, and 45 lua checks over 6 to 10 files per language.

== pinned sources

Every chapter ends with its own sources line naming the official
pages consulted while writing it. The book level pins are:

#table(
  columns: (1.7fr, 2.3fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

The six-language wave adds its own toolchain pins, verified
2026-09-14 against the gates above:

#let toolchains = (
  (topic: [c], pin: [clang 23, `-std=c23`, msvc headers, lld], url: [releases.llvm.org], accessed: [2026-09-14]),
  (topic: [c\#], pin: [dotnet sdk 10.0.401, net10.0], url: [dotnet.microsoft.com], accessed: [2026-09-14]),
  (topic: [go], pin: [go 1.27], url: [go.dev/dl], accessed: [2026-09-14]),
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
  this toolchain, recorded in the chapter 16 listing header. The
  chinese remainder implementations split policy, python refuses
  every non-coprime system while go merges the consistent ones,
  chapter 16 names the difference. The skip list promotions are
  deterministic in five languages with four stated policies,
  chapter 25. And chapter 22's interval convention is half-open
  where c\# and lua pin it, touching-fuses in the other four.
])
