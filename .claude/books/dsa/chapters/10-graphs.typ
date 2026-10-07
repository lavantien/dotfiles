#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= graphs

Graphs are the general shape under maps, schedules, dependencies,
and networks: vertices and edges, directed or not, weighted or not.
This chapter builds the adjacency list representation and the four
traversals everything else composes from, once per language.

== representation

A dictionary from vertex to neighbor list handles sparse graphs,
arbitrary labels, and growth. Insertion order in the lists becomes
deterministic traversal order, which is what lets tests pin exact
sequences.

The dry run: the fixture is the labeled store a to b and c, b to d,
c to d, d to e, asserted by the C\# suite, and the integer suites
carry the four-edge fixture 0-1, 0-2, 1-2, 2-3 with degrees 2 2 3 1
and the handshake 8.

+ The first call, a with b and c, opens a's list at b then c and
  opens empty lists for the two new names, three vertices after one
  call.
+ The next calls grow one list each and open one name each: b gains
  d, c gains d, d gains e and opens e, five vertices and five
  edges.
+ The reads pin both ends: a's neighbors return b then c in
  insertion order, e's return nothing.
+ Out-degrees read 2, 1, 1, 1, 0 and sum 2 + 1 + 1 + 1 + 0 = 5,
  the edge count the suite pins.
+ In-degrees read 0, 1, 1, 2, 1 and sum 0 + 1 + 1 + 2 + 1 = 5:
  every arc leaves one list and lands in exactly one other.

#diagram([the store growing one call at a time, the grown list shaded, bare names opening empty], length: 13pt, {
  let calls = (
    ([a with b, c], ([a: b c], [b:], [c:])),
    ([b with d], ([b: d], [d:])),
    ([c with d], ([c: d],)),
    ([d with e], ([d: e], [e:])),
  )
  for (k, c) in calls.enumerate() {
    let x = 0.6 + k * 5.1
    cdraw.content((x + 1.7, 6.4), c.at(0), size: 6.5pt)
    for (i, row) in c.at(1).enumerate() {
      let y = 5.3 - i * 0.95
      cdraw.rect((x, y - 0.33), (x + 3.4, y + 0.33), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 1.7, y), row, size: 6pt)
    }
    if k < 3 { cdraw.line((x + 3.6, 4.9), (x + 4.9, 4.9), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((8.0, 1.7), [the shaded list is the one that grew], size: 6pt)
  cdraw.content((8.0, 0.9), [bare names open empty lists], size: 6pt)
  cdraw.content((8.0, 0.1), [five lists, five entries, both counts pinned], size: 6pt)
})

The 5 and 5 are the pinned counts, and the listings below build the
store seven ways.

#listing("dsa/samples-c/src/Ch10/build.c", first: 21, last: 47, caption: [c, fixed V-by-V lists with degrees and in-degrees, one build for both readings])

#listing("dsa/samples-go/ch10/build.go", first: 10, last: 27, caption: [go, undirected and directed builders over edge structs])

#listing("dsa/samples-java/src/Ch10/Build.java", first: 21, last: 40, caption: [java, fixed V-by-V lists with degrees and in-degrees, one build for both readings])

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 4, last: 28, caption: [c\#, adjacency lists, fluent adds, counts])

#listing("dsa/samples-js/src/ch10-build.mjs", first: 4, last: 31, caption: [javascript, the two builders and the degree counters])

#listing("dsa/samples-py/src/Ch10/build.py", first: 16, last: 41, caption: [python, both builders, degrees, in and out split])

#listing("dsa/samples-lua/ch10_build.lua", first: 8, last: 25, caption: [lua, one table graph, directed flag picks the reading])

Dense graphs belong in matrices instead, `bool[n, n]` or weights,
where the edge test is O(1) but storage is quadratic and iteration
over neighbors touches every vertex. The sparse list wastes nothing
on absent edges, the same array-versus-hash trade as chapter 6 in
another coat.

Measured across the suites: C, Go, Java, JavaScript, and Lua build
the same four edges, 0-1, 0-2, 1-2, 2-3, and pin identical reads,
undirected degrees 2 2 3 1 with the handshake sum 8, directed out
2 1 1 0 against in 0 1 2 1. Python pins its own edge set with the
same handshake discipline, and the C\# suite pins counts on its
string-labeled store.

#diagram([one graph, two representations, the list against the matrix], length: 13pt, {
  // the graph: a diamond, a to b and c, both into d
  let g = ((3.2, 8.3), (1.6, 7.0), (4.8, 7.0), (3.2, 5.7))
  let gl = ((0, 1), (0, 2), (1, 3), (2, 3))
  for (a, b) in gl { cdraw.line(g.at(a), g.at(b), stroke: luma(100), mark: (end: ">")) }
  for (i, ch) in ("a", "b", "c", "d").enumerate() {
    cdraw.circle(g.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(g.at(i), ch, size: 6.5pt)
  }

  // adjacency list: one row per vertex, only real neighbors
  cdraw.content((2.9, 4.6), [adjacency list], size: 6.5pt)
  let rows = (([a: b c], 3.6), ([b: d], 2.55), ([c: d], 1.5), ([d:], 0.45))
  for row in rows { cdraw.content((1.6, row.at(1)), row.at(0), size: 6pt) }
  cdraw.content((3.7, -0.75), [one entry per edge], size: 6pt)

  // adjacency matrix: rows from, cols to, 1 where the edge exists
  cdraw.content((15.5, 4.6), [adjacency matrix], size: 6.5pt)
  for c in range(4) { cdraw.content((13.4 + c * 0.8, 4.0), ("a", "b", "c", "d").at(c), size: 6pt) }
  for r in range(4) {
    cdraw.content((12.6, 3.5 - r * 0.8), ("a", "b", "c", "d").at(r), size: 6pt)
    for c in range(4) {
      cdraw.rect((13.0 + c * 0.8, 3.1 - r * 0.8), (13.8 + c * 0.8, 3.9 - r * 0.8), fill: luma(235), radius: 0.02)
    }
  }
  let ones = ((0, 1), (0, 2), (1, 3), (2, 3))
  for (r, c) in ones { cdraw.content((13.4 + c * 0.8, 3.5 - r * 0.8), [1], size: 6pt) }
  cdraw.content((15.5, -0.75), [o(1) test, quadratic storage], size: 6pt)
})

== breadth first

Breadth first is a queue: it finishes an entire distance layer
before the next, so the first time it marks a vertex is along a
shortest path in edge count. Distances and a parent chain fall out
of the same loop, and walking parents backward rebuilds the path.

The dry run: the fixture is the same labeled store walked from a,
asserted by the C\# suite, and the integer suites pin the same
layers on the diamond with the rebuilt path 0 1 3 4.

+ The queue opens with a alone, and the first pop labels its two
  neighbors, b at 0 + 1 = 1 and c at 1, both waiting behind it.
+ Pop b: d is unseen, takes 1 + 1 = 2 with parent b, and joins the
  queue behind c.
+ Pop c: its edge into d arrives too late, d already carries 2, and
  the strict test writes nothing.
+ Pop d: e takes 2 + 1 = 3. Pop e: no neighbors, the queue empties.
+ The order reads a b c d e and the distances 0 1 1 2 3, both
  asserted by the suite.
+ Parents walk backward from e through d and b to a, so the
  shortest path to e reads a b d e at three edges.

#diagram([the run as five pops, the queue waiting under each, every new label landing one layer down], length: 13pt, {
  let pops = (
    (([a], 0), ([b], [c])),
    (([b], 1), ([c], [d])),
    (([c], 1), ([d],)),
    (([d], 2), ([e],)),
    (([e], 3), ()),
  )
  for (k, p) in pops.enumerate() {
    let x = 1.4 + k * 4.3
    cdraw.rect((x - 0.55, 6.1), (x + 0.55, 7.0), fill: luma(205), radius: 0.02)
    cdraw.content((x, 6.55), [#p.at(0).at(0) #p.at(0).at(1)], size: 6.5pt)
    for (j, v) in p.at(1).enumerate() {
      let y = 5.0 - j * 0.95
      cdraw.rect((x - 0.55, y - 0.35), (x + 0.55, y + 0.35), fill: luma(235), radius: 0.02)
      cdraw.content((x, y), v, size: 6pt)
    }
    if k < 4 { cdraw.line((x + 0.75, 6.55), (x + 3.35, 6.55), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((2.0, 2.6), [queue after the pop, front on top], size: 6pt)
  cdraw.content((10.0, 1.7), [the c to d edge lands on a labeled vertex], size: 6pt)
  cdraw.content((10.0, 0.9), [one layer drains before the next opens], size: 6pt)
})

The 0 1 1 2 3 with the order a b c d e is the pinned pair, and the
listings below run the queue in seven languages.

#listing("dsa/samples-c/src/Ch10/bfs.c", first: 27, last: 48, caption: [c, the ring-buffer queue, distances, parents, visit order])

#listing("dsa/samples-go/ch10/bfs.go", first: 7, last: 27, caption: [go, slice-as-queue, -1 marks unreachable])

The other five run the queue, Java walking a head cursor over one
array queue:

#listing("dsa/samples-java/src/Ch10/Bfs.java", first: 29, last: 51, caption: [java, the array queue with a head cursor, distances, parents, visit order])

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 30, last: 47, caption: [c\#, bfs with a distance map, TryAdd as the seen test])

#listing("dsa/samples-js/src/ch10-bfs.mjs", first: 4, last: 29, caption: [javascript, head index walks the array queue, path rebuild])

#listing("dsa/samples-py/src/Ch10/bfs.py", first: 23, last: 44, caption: [python, none for unreached, the parent chain reversed])

#listing("dsa/samples-lua/ch10_bfs.lua", first: 16, last: 35, caption: [lua, 1-based queue with a head cursor])

Measured across the suites: C, Java, and Lua walk an undirected
diamond plus tail and Go and JavaScript its directed twin, and all
five pin the same numbers, distances 0 1 1 2 3, parents with vertex
3 discovered through 1, and the rebuilt path 0 1 3 4. Python runs a
six-vertex fixture, distances 0 1 1 2 3 3 with the path to 5 reading
0 1 3 5, and checks both lanes to a tie. The C\# suite walks its
labeled graph by layers.

#diagram([breadth first on the diamond plus tail, one layer per row, the parent chain is a shortest path], length: 13pt, {
  // the fixture drawn as layers: 0, then 1 and 2, then 3, then 4
  let layers = (
    ((0,), 6.6, [layer 0]),
    ((1, 2), 5.2, [layer 1]),
    ((3,), 3.8, [layer 2]),
    ((4,), 2.4, [layer 3]),
  )
  let at = (layer, i, count) => (7.6 - (count - 1) * 0.65 + i * 1.3, layer)
  let pos = ((), (), (), ())
  for (r, row) in layers.enumerate() {
    let (vs, y, label) = row
    cdraw.content((2.6, y), label, size: 6pt)
    let pts = ()
    for (i, v) in vs.enumerate() {
      let p = at(y, i, vs.len())
      pts.push(p)
      cdraw.circle(p, radius: 0.3, fill: luma(235))
      cdraw.content(p, [#v], size: 6.5pt)
    }
    pos.at(r) = pts
  }
  // parent edges: 0-1, 0-2, 1-3 (3 through 1), 3-4
  cdraw.line(pos.at(0).at(0), pos.at(1).at(0), stroke: luma(100), mark: (end: ">"))
  cdraw.line(pos.at(0).at(0), pos.at(1).at(1), stroke: luma(100), mark: (end: ">"))
  cdraw.line(pos.at(1).at(0), pos.at(2).at(0), stroke: luma(100), mark: (end: ">"))
  cdraw.line(pos.at(2).at(0), pos.at(3).at(0), stroke: luma(100), mark: (end: ">"))
  // the cross edge 2-3 discovered too late, drawn dashed
  cdraw.line(pos.at(1).at(1), pos.at(2).at(0), stroke: (paint: luma(180), dash: "dashed"), mark: (end: ">"))

  cdraw.content((15.4, 6.6), [the queue drains a layer], size: 6pt)
  cdraw.content((15.4, 5.6), [before the next is touched], size: 6pt)
  cdraw.content((15.4, 4.4), [3 is seen through 1 first,], size: 6pt)
  cdraw.content((15.4, 3.6), [the 2 to 3 edge arrives late], size: 6pt)
  cdraw.content((15.4, 2.4), [walk parents back for the path], size: 6pt)
  cdraw.content((9.0, 0.9), [distances 0 1 1 2 3, path 0 1 3 4], size: 6pt)
})

== depth first

Depth first is a stack, recursion here: it dives along one path
until it dead ends, then unwinds. The iterative twin pushes
neighbors reversed so its pop order matches the recursive walk, and
the recursion state, gray on the path, black finished, is what
cycle detection reads.

The dry run: the fixture is the same labeled store dove from a,
asserted by the C\# suite, and the integer suites pin the matching
preorder 0 1 3 4 2 with the iterative twin agreeing.

+ The recursion opens a and follows its first neighbor b, insertion
  order decides, then b's only neighbor d, then d's only neighbor
  e: the dive runs a b d e before any unwind.
+ e has no neighbors and finishes, and the unwind closes d, then b.
+ Back at a the second neighbor c opens, and its edge into d meets
  a finished vertex, a cross edge, not a cycle.
+ c finishes, then a, and the preorder reads a b d e c, asserted.
+ The forest on two separate arcs, a to b and x to y, stamps the
  finish order b a y x, each child closing before its parent.
+ The verdicts: a self loop and a two vertex cycle both flag, the
  diamond's two paths to one vertex do not.

#diagram([the recursion as a depth profile, one tick per event, shaded dots are opens, hollow dots are finishes], length: 13pt, {
  let depths = (1, 2, 3, 4, 3, 2, 1, 2, 1, 0)
  let labels = ("a", "b", "d", "e", "e", "d", "b", "c", "c", "a")
  let opens = (0, 1, 2, 3, 7)
  let px = i => 1.0 + i * 2.0
  let py = d => 0.9 + d * 1.15
  cdraw.line(..depths.enumerate().map(p => (px(p.at(0)), py(p.at(1)))), stroke: luma(100))
  for i in range(depths.len()) {
    let open = i in opens
    cdraw.circle((px(i), py(depths.at(i))), radius: 0.17, fill: if open { luma(205) } else { luma(255) }, stroke: luma(100))
    cdraw.content((px(i), py(depths.at(i)) + if open { 0.55 } else { -0.5 }), labels.at(i), size: 6pt)
  }
  cdraw.content((3.0, 6.7), [the dive], size: 6pt)
  cdraw.content((11.5, 2.9), [the unwind], size: 6pt)
  cdraw.content((15.0, 5.7), [c opens after b closed], size: 6pt)
  cdraw.content((20.6, 0.4), [open ticks read a b d e c], size: 6pt)
})

The preorder a b d e c is the pinned walk, and the listings below
carry the stack in seven languages.

#listing("dsa/samples-c/src/Ch10/dfs.c", first: 25, last: 57, caption: [c, recursive three-color dfs and the explicit-stack twin])

#listing("dsa/samples-go/ch10/dfs.go", first: 6, last: 45, caption: [go, recursive and iterative dfs, reversed pushes match the preorder])

The other five carry the stack, Java's iterative twin pushing
neighbors reversed to match the recursive preorder:

#listing("dsa/samples-java/src/Ch10/Dfs.java", first: 30, last: 63, caption: [java, recursive three-color dfs and the explicit-stack twin])

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 50, last: 64, caption: [c\#, recursive dfs over the seen set])

The forest version stamps discovery and finish ticks on every
vertex, which topological sort and cycle detection both read:

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 71, last: 94, caption: [c\#, dfs forest with discover and finish times])

The alternative order is DFS finish order reversed, free from the
stamps the forest already computes. Cycle detection needs the open
versus done distinction: a back edge into a vertex still on the
recursion stack is a cycle, a cross edge into a finished vertex is
not. The diamond test proves the difference, two paths to one vertex
are not a cycle:

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 122, last: 144, caption: [c\#, back edge detection with open and done states])

Three more languages carry the walk:

#listing("dsa/samples-js/src/ch10-dfs.mjs", first: 4, last: 38, caption: [javascript, three-color walk with the cycle flag, stack twin])

#listing("dsa/samples-py/src/Ch10/dfs.py", first: 24, last: 50, caption: [python, recursive and iterative over sorted adjacency])

#listing("dsa/samples-lua/ch10_dfs.lua", first: 17, last: 54, caption: [lua, nested functions carry the walk state])

Measured across the suites: C, Go, Java, JavaScript, and Lua walk
the same dag, 0 to 1 and 2, both into 3, then 4, and pin the
preorder 0 1 3 4 2 with the iterative walk matching the recursive
one exactly, the same 2 3 4 from a mid start, and a back edge 2 to
1 plus a self loop both flagged. Python sorts each adjacency list
and walks an undirected fixture instead, 0 1 3 4 5 2, with the
cycle test reading the came-from parent. The C\# suite pins
`a b d e c` on its labeled graph.

#diagram([the three dfs states, a back edge into open is the cycle, a cross edge into done is not], length: 13pt, {
  // the state machine: unseen to open to done, with the two edge verdicts
  cdraw.rect((0.6, 7.0), (3.0, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 7.45), [unseen], size: 6pt)
  cdraw.rect((5.4, 7.0), (7.8, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((6.6, 7.45), [open], size: 6pt)
  cdraw.rect((10.2, 7.0), (12.6, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((11.4, 7.45), [done], size: 6pt)
  cdraw.line((3.0, 7.45), (5.4, 7.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.8, 7.45), (10.2, 7.45), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.2, 8.15), [discover], size: 6pt)
  cdraw.content((9.0, 8.15), [finish], size: 6pt)
  cdraw.content((5.4, 5.9), [back edge into open: cycle], size: 6pt)
  cdraw.content((5.4, 4.8), [cross edge into done: fine], size: 6pt)

  // the diamond mid-dfs: a b d finished, c on the stack, c to d is a cross edge
  let g = ((3.2, 3.4), (1.6, 2.1), (4.8, 2.1), (3.2, 0.8))
  cdraw.line(g.at(0), g.at(1), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(0), g.at(2), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(1), g.at(3), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(2), g.at(3), stroke: (paint: luma(180), dash: "dashed"), mark: (end: ">"))
  for (i, ch) in ("a", "b", "c", "d").enumerate() {
    let open-node = i == 2
    cdraw.circle(g.at(i), radius: 0.3, fill: if open-node { luma(205) } else { luma(235) }, stroke: if open-node { luma(100) } else { luma(220) })
    cdraw.content(g.at(i), ch, size: 6.5pt)
  }
  cdraw.content((14.5, 3.4), [open: c, done: a b d], size: 6pt)
  cdraw.content((16.0, 1.5), [two paths are not a cycle], size: 6pt)
})

== topological order

A topological order is a linear layout where every edge points
forward. Kahn's algorithm repeatedly removes a zero in-degree vertex,
which must exist in a dag, and queues the vertices it releases. A
queue that drains before the whole graph is the cycle verdict.

The dry run: the fixture is the same labeled dag, asserted by the
C\# suite edge by edge, and C, Java, Lua, and Python pin the exact
order 4 5 2 0 3 1 on the classic six-vertex fixture.

+ The five arcs leave in-degrees a 0, b 1, c 1, d 2, e 1, and the
  sum 0 + 1 + 1 + 2 + 1 = 5 matches the edge count.
+ Only a sits at zero, so the ready queue opens with a alone.
+ Pop a: b and c both drop to 0 and enqueue in neighbor order,
  b then c.
+ Pop b: d drops 2 to 1. Pop c: d hits 0 and joins.
+ Pop d releases e, pop e ends the drain, 5 of 5 emitted in the
  order a b c d e with every edge pointing forward.
+ On the arcs a to b, b to c, c back to a the in-degrees read
  1 1 1, the queue never opens, and the sort throws.

#table(
  columns: (auto, auto, auto, auto, auto, auto, 1.2fr),
  inset: 4pt,
  table.header([*pop*], [*a*], [*b*], [*c*], [*d*], [*e*], [*ready queue*]),
  [], [0], [1], [1], [2], [1], [a],
  [a], [], [], [], [2], [1], [b c],
  [b], [], [], [], [1], [1], [c],
  [c], [], [], [], [0], [1], [d],
  [d], [], [], [], [], [0], [e],
)

The 5 of 5 drain against the empty refusal is the pinned pair, and
the listings below drain the queue in seven languages.

#listing("dsa/samples-c/src/Ch10/topo.c", first: 25, last: 41, caption: [c, the in-degree queue, emitted count below V means a cycle])

#listing("dsa/samples-go/ch10/topo.go", first: 6, last: 27, caption: [go, kahn over in-degrees, drained flag returned])

#listing("dsa/samples-java/src/Ch10/Topo.java", first: 28, last: 44, caption: [java, the in-degree queue, emitted count below V means a cycle])

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 96, last: 120, caption: [c\#, kahn's algorithm, the cycle refusal])

#listing("dsa/samples-js/src/ch10-topo.mjs", first: 5, last: 17, caption: [javascript, head cursor walks the ready queue])

#listing("dsa/samples-py/src/Ch10/topo.py", first: 14, last: 31, caption: [python, ascending-id ready list, ok flag])

#listing("dsa/samples-lua/ch10_topo.lua", first: 17, last: 33, caption: [lua, 1-based work queue, count-out contract])

Measured across the suites: C, Java, Lua, and Python run the classic
six-vertex fixture, 5 to 2 and 0, 4 to 0 and 1, 2 to 3, 3 to 1, and
pin the exact order 4 5 2 0 3 1 under the fifo ready queue seeded in
ascending id order,
with two cycles holding all but the chain 2 3 hostage in C, Java,
and Lua and a three-cycle draining to nothing in Python. Go and
JavaScript pin the forced order 0 1 2 3 on the diamond, check every
edge points forward on the dag, and flag the cycle by an empty
drain. The C\# suite pins its order and throws on the cycle.

#flow(
  [graph traversal pick order],
  node((0, 0), [adjacency list]),
  node((1.7, 0), [queue: bfs layers]),
  node((3.4, 0), [stack: dfs paths]),
  node((1.7, -1), [shortest unweighted paths]),
  node((3.4, -1), [topo order, cycles, components]),
  edge((0, 0), (1.7, 0), "-|>"),
  edge((0, 0), (3.4, 0), "-|>", bend: -25deg),
  edge((1.7, 0), (1.7, -1), "-|>"),
  edge((3.4, 0), (3.4, -1), "-|>"),
)

== connectivity

Components under the undirected view are flood fills, one per
unvisited vertex. The method builds the symmetric adjacency on the
fly rather than mutating the directed store.

The dry run: the fixture is the mixed store a to b to c, d to e,
and f alone, asserted by all seven suites. The six new trees pin the
exact ids in vertex first-seen order and run a union-find oracle over
the same edges, and their isolation lane adds z with no edges.

+ Stored directed, the graph holds three arcs, a to b, b to c, d to
  e, with f isolated.
+ Symmetrized on the fly each arc lands in two lists: b's reads
  a then c, every other touched vertex reads one neighbor, f none.
+ The fill from a takes b, and from b the walk sees a already
  labeled and takes c: a, b, c share id 0.
+ The scan resumes at d, fills e with it as id 1, and finishes at f
  alone as id 2.
+ Three fills cover 3 + 2 + 1 = 6 vertices, and the suite pins the
  three distinct ids with d and f apart from each other and from a.
+ The one-way check: a store holding only a to b still fills as one
  island, the directed arc joins its endpoints the moment direction
  is ignored.

#diagram([the three fills in run order, one recursion per island, the shaded vertex where each fill starts], length: 13pt, {
  let fills = (
    ([fill 0], (([a], true), ([b], false), ([c], false))),
    ([fill 1], (([d], true), ([e], false))),
    ([fill 2], (([f], true),)),
  )
  for (k, f) in fills.enumerate() {
    let y = 6.4 - k * 1.9
    cdraw.content((1.4, y), f.at(0), size: 6pt)
    for (i, v) in f.at(1).enumerate() {
      let x = 3.4 + i * 1.5
      cdraw.circle((x, y), radius: 0.34, fill: if v.at(1) { luma(205) } else { luma(235) })
      cdraw.content((x, y), v.at(0), size: 6.5pt)
      if i < f.at(1).len() - 1 { cdraw.line((x + 0.42, y), (x + 1.08, y), stroke: luma(100), mark: (end: ">")) }
    }
  }
  cdraw.content((9.2, 6.4), [b's symmetrized list reads a then c,], size: 6pt)
  cdraw.content((9.2, 5.5), [the fill turns back at a, already labeled], size: 6pt)
  cdraw.content((9.2, 3.6), [3 + 2 + 1 = 6 vertices, three ids pinned], size: 6pt)
  cdraw.content((9.2, 1.7), [a lone a to b arc still fills one island], size: 6pt)
})

The three ids over six vertices are the pinned count, and the
listings below are the flood fills that produced them.

#listing("dsa/samples-c/src/Ch10/components.c", first: 50, last: 82, caption: [c, symmetrize both directions, stack fill, ids in insertion order])

#listing("dsa/samples-go/ch10/components.go", first: 37, last: 69, caption: [go, recursive flood over the symmetrized map, ids in name order])

The other five languages fill the same islands, Java's component
file switching to string labels over a first-seen id map:

#listing("dsa/samples-java/src/Ch10/Components.java", first: 43, last: 81, caption: [java, symmetrize both directions, stack fill, ids in first-seen order])

#listing("dsa/samples/src/Ch10/Graphs.cs", first: 146, last: 185, caption: [c\#, undirected flood fill components])

#listing("dsa/samples-js/src/ch10-components.mjs", first: 27, last: 56, caption: [javascript, the flood over Map adjacency, first-seen ids])

#listing("dsa/samples-py/src/Ch10/components.py", first: 14, last: 52, caption: [python, the insertion-order store and the depth-first fill])

#listing("dsa/samples-lua/ch10_components.lua", first: 38, last: 63, caption: [lua, the flood over symmetrized tables, ids in order])

Measured across the suites: all seven agree a, b, c share one id,
d and e a second, f a third, 3 components over 6 vertices, and that
a single directed edge still joins its endpoints when direction is
ignored. The six new trees pin the exact numbering, 0, 1, 2 in
first-seen order, check the union-find oracle on every pair and on
the count, and run the isolation lane, z with no edges stays
untouched by any traversal from a. That is the connectivity question
for undirected reachability, answered by ignoring direction.

#diagram([connectivity, the directed store viewed symmetric, one flood fill per unvisited vertex], length: 13pt, {
  // stored directed: two linked pairs, one via a single one-way edge, e alone
  let top = ((2.0, 7.3), (4.4, 7.3), (9.0, 7.3), (11.4, 7.3), (17.0, 7.3))
  cdraw.content((6.7, 8.2), [stored directed], size: 6.5pt)
  cdraw.line(top.at(0), top.at(1), stroke: luma(100), mark: (end: ">"))
  cdraw.line(top.at(2), top.at(3), stroke: luma(100), mark: (end: ">"))
  for (i, ch) in ("a", "b", "c", "d", "e").enumerate() {
    cdraw.circle(top.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(top.at(i), ch, size: 6.5pt)
  }

  cdraw.line((6.7, 6.8), (6.7, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 5.7), [symmetrized on the fly], size: 6pt)

  // viewed undirected: three islands, shaded behind their vertices
  let bot = ((2.0, 3.7), (4.4, 3.7), (9.0, 3.7), (11.4, 3.7), (17.0, 3.7))
  cdraw.rect((1.4, 3.1), (5.0, 4.3), fill: luma(205), radius: 0.05)
  cdraw.rect((8.4, 3.1), (12.0, 4.3), fill: luma(205), radius: 0.05)
  cdraw.rect((16.4, 3.1), (17.6, 4.3), fill: luma(205), radius: 0.05)
  cdraw.line(bot.at(0), bot.at(1), stroke: luma(100))
  cdraw.line(bot.at(2), bot.at(3), stroke: luma(100))
  for (i, ch) in ("a", "b", "c", "d", "e").enumerate() {
    cdraw.circle(bot.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(bot.at(i), ch, size: 6.5pt)
  }
  cdraw.content((9.0, 2.2), [one flood fill per unvisited vertex, three islands], size: 6.5pt)
  cdraw.content((14.5, 1.1), [a single directed edge still joins its endpoints], size: 6pt)
})

Everything ahead composes these four primitives: Dijkstra is BFS
with a heap instead of a fifo, chapter 11, Kruskal and Prim build
spanning trees from component walks and heap orders, chapter 12, and
the capstone's segment merge graph is a dag by construction.

== across the seven languages

The build sizes count non-comment source lines over this chapter's
five featured files per language. The C\# file carries the labeled
graph with its components walk and the forest stamps, and the
integer-vertex suites keep drivers in the featured file where the
language has no separate test project:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [451], [libc only], [fixed V-by-V adjacency with degree counters, both readings from one build, checks share the file with main, 62 of them],
  [go], [227], [none], [integer vertices, tests in separate files, HasCycleDirected returns the three-color verdict, 15 tests],
  [java], [469], [jdk 27 stdlib], [fixed V-by-V adjacency like c, one build for both readings, the components file alone switches to string labels over a first-seen id map],
  [c\#], [160], [bcl only], [string labels and Dictionary adjacency, forest stamps and components in the same file, 11 tests],
  [javascript], [183], [node stdlib], [array-of-arrays adjacency, head cursor instead of dequeue, 16 tests],
  [python], [276], [stdlib only], [sorted adjacency pins the walk order, undirected cycle rule reads the parent, 43 checks],
  [lua], [415], [lib.lua harness], [adjacency grown by assignment, 1-based queues, checks ride in the module, 21 of them],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>` and
`Queue<T>` pages used by the implementation, `HashSet<T>` set
operations, accessed 2026-09-08. Sample behavior verified by
`make verify-csharp`, 11 tests in chapter 10 of the samples suite.
The seven-language layer verifies the same way: 5 C programs with 62
embedded checks under `make verify-c`, 15 Go tests, the java runner's
62 Ch10 checks over 5 files under `run-java-samples`, 16
`node --test` cases, 43 Python checks across 5 files, and 21 Lua
checks under `run.lua`.
