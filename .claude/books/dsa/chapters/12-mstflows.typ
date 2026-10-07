#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= minimum spanning trees and flows

Two more greedy classics. Spanning trees connect everything for
least total weight, and maximum flow asks how much can travel from a
source to a sink through capacity-limited pipes. Both are solved by
repeatedly taking what the current state allows.

== union-find

The supporting actor for both chapters ahead of time: disjoint sets
with two optimizations, path compression in find and union by rank.
Both keep trees effectively flat.

The dry run: the fixture is the C\# four-label script a through d and
the 50-node chain, asserted by the C\# suite; the siblings run their
own scripts, C, Java, and Lua on 10 vertices, the rest on smaller
unions.

+ Four Add calls stand a, b, c, and d each as its own root: SetCount
  reads 4.
+ Union(a, b) fuses the first pair, the equal ranks growing the
  survivor to rank 1: SetCount 4 - 1 = 3.
+ Union(c, d) drops the count to 2, with Connected(a, b) true and
  Connected(a, c) false across the divide.
+ Union(b, d) bridges the two trees and Connected(a, c) flips true
  transitively: SetCount 1.
+ A second pair x, y joins once, then the repeat Union(y, x) refuses:
  the count stays at 1.
+ The chain v0 through v49, unioned upward, sends Find("v49")
  climbing to v0, and the rehang pins the walked path one hop from
  the root.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*action*], [*SetCount*], [*reads*]),
  [add a, b, c, d], [4], [four roots, ranks 0],
  [union(a, b)], [3], [survivor rank 1],
  [union(c, d)], [2], [connected(a, b) true],
  [union(b, d)], [1], [connected(a, c) true],
  [union(x, y), then union(y, x)], [1], [second refuses, count holds],
  [find(v49)], [1], [v0, the path rehung],
)

The 4 to 1 count and the v49 rehang are the C\# pins, and the
listings below build the sets in seven languages.

#listing("dsa/samples-c/src/Ch12/dsu.c", first: 28, last: 58, caption: [c, path halving in find, rank in union, the component count])

#listing("dsa/samples-go/ch12/dsu.go", first: 28, last: 58, caption: [go, two-pass find with the compression rehang, rank-ordered union])

#listing("dsa/samples-java/src/Ch12/Dsu.java", first: 29, last: 52, caption: [java, path halving in find, rank in union, the component count])

#listing("dsa/samples/src/Ch12/Flows.cs", first: 4, last: 53, caption: [c\#, disjoint sets with compression and rank, cycle reporting unions])

Union returns false when both ends are already connected, which is
precisely the cycle test kruskal needs, and the amortized cost with
both optimizations is inverse Ackermann, effectively constant for
any addressable n.

#listing("dsa/samples-js/src/ch12-dsu.mjs", first: 13, last: 36, caption: [javascript, halving find, rank union, parent exposed for the proof])

#listing("dsa/samples-py/src/Ch12/dsu.py", first: 18, last: 38, caption: [python, find walks then rehangs, union by rank, component count])

#listing("dsa/samples-lua/ch12_dsu.lua", first: 15, last: 36, caption: [lua, halving find over plain tables, union by rank])

Measured across the suites: C, Java, and Lua share one 10-vertex
script, 4 components after six unions, a redundant union returning
false and changing nothing, and a find that leaves 8 pointing
straight at its root. JavaScript chains 4 into 1 to make the
compression visible and checks the rank grew, while Go and Python
pin counts through their own scripts with the same refusal. The
accelerations differ in flavor: C, Java, JavaScript, and Lua halve
the path as they walk, the C\# and Go finds walk to the root then
rehang the whole path, and Python ships both, a rehang in the
standalone file and a halving copy inside its kruskal below.

#diagram([union-find, find compresses the walked path, union by rank refuses the cycle-closing edge], length: 13pt, {
  // before: find(6) climbs 6 4 2 to the root, that path shaded
  cdraw.content((3.4, 3.3), [find(6) climbs], size: 6.5pt)
  let t1 = ((3.0, 7.5), (1.9, 6.4), (4.1, 6.4), (1.3, 5.3), (4.1, 5.3), (1.3, 4.2))
  let e1 = ((5, 3), (3, 1), (1, 0), (4, 2), (2, 0))
  let hot1 = ((5, 3), (3, 1), (1, 0))
  for (a, b) in e1 { cdraw.line(t1.at(a), t1.at(b), stroke: if (a, b) in hot1 { luma(100) } else { luma(220) }) }
  for i in range(6) {
    cdraw.circle(t1.at(i), radius: 0.3, fill: if i == 0 or i >= 3 and i != 4 { luma(205) } else { luma(235) })
    cdraw.content(t1.at(i), [#(i + 1)], size: 6pt)
  }

  // after: 6 and 4 rehung directly at the root
  cdraw.content((11.0, 3.3), [compression rehung the path], size: 6.5pt)
  let t2 = ((10.8, 7.5), (9.2, 6.4), (12.4, 6.4), (10.2, 6.4), (12.4, 5.3), (11.2, 6.4))
  let e2 = ((1, 0), (2, 0), (3, 0), (5, 0), (4, 2))
  let hot2 = ((3, 0), (5, 0))
  for (a, b) in e2 { cdraw.line(t2.at(a), t2.at(b), stroke: if (a, b) in hot2 { luma(100) } else { luma(220) }) }
  for i in range(6) {
    cdraw.circle(t2.at(i), radius: 0.3, fill: if i == 0 or i == 3 or i == 5 { luma(205) } else { luma(235) })
    cdraw.content(t2.at(i), [#(i + 1)], size: 6pt)
  }

  cdraw.content((7.2, 2.1), [union by rank keeps trees shallow], size: 6.5pt)
  cdraw.content((7.2, 1.0), [a refused union is a cycle], size: 6.5pt)
})

== kruskal

Kruskal sorts all edges and adds each unless it closes a cycle, the
DSU from the section above answering the cycle question in near
constant time.

The dry run: the fixture is the C\# weighted graph, vertices a
through d over edges a-b 1, a-c 4, b-c 2, b-d 6, c-d 3; Go,
JavaScript, and Python run a 5-edge graph to the same total and C,
Java, and Lua a 6-edge one at 13.

+ OrderBy weight lines the candidates up: a-b at 1, b-c at 2, c-d at
  3, a-c at 4, b-d at 6.
+ a-b joins a and b, then b-c pulls c into that component: two edges
  down, d still alone.
+ c-d spans the last vertex: three edges, the n - 1 = 4 - 1 = 3 a
  tree of 4 vertices needs, and the loop breaks.
+ a-c at 4 would close the a-b-c triangle and b-d at 6 meets an old
  friend: both unions refuse.
+ The pinned reads: weights 1, 2, 3 in pick order, tree.Count 3, and
  1 + 2 + 3 = 6 total.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*weight*], [*edge*], [*union*], [*tree so far*], [*total*]),
  [1], [a-b], [joins], [a-b], [1],
  [2], [b-c], [joins], [a-b, b-c], [3],
  [3], [c-d], [joins], [a-b, b-c, c-d], [6],
  [4], [a-c], [refuses], [unchanged], [6],
  [6], [b-d], [refuses], [unchanged], [6],
)

The refused 4 and 6 beside the pinned total 6 are the C\# shape, and
the listings below sort and union in seven languages.

#listing("dsa/samples-c/src/Ch12/kruskal.c", first: 40, last: 69, caption: [c, sort by weight, union accepts, the spanning count])

#listing("dsa/samples-go/ch12/kruskal.go", first: 18, last: 34, caption: [go, slices sort, dsu unions, early break at spanning])

#listing("dsa/samples-java/src/Ch12/Kruskal.java", first: 39, last: 56, caption: [java, sorted edges over the inline dsu, records for the chosen tree])

#listing("dsa/samples/src/Ch12/Flows.cs", first: 60, last: 75, caption: [c\#, kruskal over sorted edges, stop at n-1])

#listing("dsa/samples-js/src/ch12-kruskal.mjs", first: 10, last: 22, caption: [javascript, sorted copy, tree in acceptance order])

#listing("dsa/samples-py/src/Ch12/kruskal.py", first: 36, last: 45, caption: [python, sorted (weight, u, v) triples over the inline dsu])

#listing("dsa/samples-lua/ch12_kruskal.lua", first: 22, last: 40, caption: [lua, table.sort, union-accept, total accumulated])

Kruskal is edge-oriented and shines on sparse graphs, and the cut
property is why it is correct: every light edge across a partition
of the components belongs to some minimum tree.

Measured across the suites: Go, JavaScript, and Python share a
5-edge fixture and pin total 6 with the tree 0-1, 1-2, 2-3 in pick
order, the heavy edges of weight 4 and 5 refused, and a disconnected
graph left as a forest. C, Java, and Lua share a 6-edge fixture,
total 13 from picks 1 2 4 6, C and Lua proving the spanning property
by transitive closure over the chosen edges. The frozen C\# suite
pins n-1 edges of one total across fixed and twenty random weighted
graphs.

#diagram([kruskal against prim on one graph, sorted unions past cycle closers against one tree through a heap frontier], length: 13pt, {
  // kruskal: the sorted edge list, joins and one refusal
  cdraw.content((3.0, 7.6), [kruskal], size: 7pt)
  let rows = (
    ([1 a b, join], 6.5, true),
    ([2 d e, join], 5.4, true),
    ([2 b c, join], 4.3, true),
    ([3 c d, join], 3.2, true),
    ([4 a c, cycle, skip], 2.1, false),
  )
  for row in rows {
    let (t, y, ok) = row
    if not ok { cdraw.rect((0.7, y - 0.45), (5.5, y + 0.45), fill: luma(205), radius: 0.02) }
    cdraw.content((3.1, y), t, size: 6pt)
  }

  // prim: the same graph, tree edges solid, the rejected edge dashed
  cdraw.content((12.0, 8.2), [prim], size: 7pt)
  let g = ((9.4, 6.5), (11.0, 7.3), (13.0, 7.3), (11.0, 5.7), (15.0, 7.3))
  cdraw.line(g.at(0), g.at(1), stroke: luma(100))
  cdraw.line(g.at(1), g.at(2), stroke: luma(100))
  cdraw.line(g.at(2), g.at(3), stroke: luma(100))
  cdraw.line(g.at(2), g.at(4), stroke: luma(100))
  cdraw.line(g.at(0), g.at(2), stroke: (paint: luma(220), dash: "dashed"))
  for (i, ch) in ("a", "b", "c", "d", "e").enumerate() {
    cdraw.circle(g.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(g.at(i), ch, size: 6pt)
  }
  cdraw.content((10.2, 7.15), [1], size: 6pt)
  cdraw.content((12.1, 7.75), [2], size: 6pt)
  cdraw.content((12.1, 6.3), [3], size: 6pt)
  cdraw.content((14.1, 7.75), [2], size: 6pt)
  cdraw.content((10.3, 6.3), [4], size: 6pt)

  cdraw.content((12.0, 4.4), [prim grows one tree through], size: 6.5pt)
  cdraw.content((12.0, 3.3), [a heap frontier], size: 6.5pt)
  cdraw.content((8.0, 0.9), [both land n-1 edges of identical total], size: 6.5pt)
  cdraw.content((8.0, -0.2), [the light edge across any cut is safe], size: 6.5pt)
})

== prim

Prim grows one tree outward from a start vertex, always absorbing
the cheapest edge that crosses from inside to outside. The frozen
C\# version drives a binary heap frontier of candidate edges, the
other six scan for the smallest key, quadratic on purpose and
clearer than heap machinery at teaching sizes.

The dry run: the fixture is the same weighted graph grown from a
through the C\# heap frontier, the total asserted equal to kruskal's;
the six siblings scan for the smallest key instead, Go, JavaScript,
and Python pinning the same 6 from every start.

+ The heap opens with a's two crossings, a-b at 1 and a-c at 4.
+ ExtractMin pops a-b 1 and b joins: b's crossings b-c 2 and b-d 6
  land beside the aging a-c 4.
+ ExtractMin pops b-c 2 and c joins: c's crossing c-d 3 undercuts
  the stale a-c 4 and the waiting b-d 6.
+ ExtractMin pops c-d 3 and d joins: the tree holds its n - 1 = 3
  edges and the count check ends the run.
+ The stale a-c 4 and the outranked b-d 6 die in the heap unvisited,
  and the total reads 1 + 2 + 3 = 6, kruskal's number, the pinned
  equality.

#diagram([the frontier round by round, the popped winner above the heap it came from, the stale entries never popped], length: 13pt, {
  let chip = (x, y, t, hot, stale) => {
    cdraw.rect((x - 1.15, y - 0.3), (x + 1.15, y + 0.3), fill: if stale { none } else if hot { luma(205) } else { luma(235) }, stroke: if stale { (paint: luma(160), dash: "dashed") }, radius: 0.02)
    cdraw.content((x, y), t, size: 6pt)
  }
  cdraw.content((4.0, 7.5), [round 1], size: 6.5pt)
  chip(4.0, 6.6, [pop a-b 1], true, false)
  chip(4.0, 5.7, [a-c 4], false, false)
  cdraw.content((4.0, 4.8), [b joins], size: 6pt)
  cdraw.content((11.0, 7.5), [round 2], size: 6.5pt)
  chip(11.0, 6.6, [pop b-c 2], true, false)
  chip(11.0, 5.7, [a-c 4], false, false)
  chip(11.0, 4.9, [b-d 6], false, false)
  cdraw.content((11.0, 4.0), [c joins], size: 6pt)
  cdraw.content((18.0, 7.5), [round 3], size: 6.5pt)
  chip(18.0, 6.6, [pop c-d 3], true, false)
  chip(18.0, 5.7, [a-c 4], false, true)
  chip(18.0, 4.9, [b-d 6], false, false)
  cdraw.content((18.0, 4.0), [d joins, done], size: 6pt)
  cdraw.content((4.0, 2.9), [totals 1, then 1 + 2 = 3, then 3 + 3 = 6], size: 6pt)
  cdraw.content((11.5, 1.9), [a-c 4 turned stale the moment c joined], size: 6pt)
  cdraw.content((11.5, 1.0), [both survivors die unpopped], size: 6pt)
})

The 6 matching kruskal on the same graph is the pinned pair, and the
listings below grow the tree in seven languages.

#listing("dsa/samples-c/src/Ch12/prim.c", first: 37, last: 60, caption: [c, key array over the adjacency matrix, min-scan pick])

#listing("dsa/samples-go/ch12/prim.go", first: 7, last: 43, caption: [go, best-key scan over adjacency lists, forest flag])

#listing("dsa/samples-java/src/Ch12/Prim.java", first: 34, last: 59, caption: [java, key, parent, and taken arrays over the matrix, min-scan pick])

#listing("dsa/samples/src/Ch12/Flows.cs", first: 78, last: 107, caption: [c\#, prim through the heap frontier, tie break on names])

#listing("dsa/samples-js/src/ch12-prim.mjs", first: 8, last: 35, caption: [javascript, key and parent arrays over the matrix])

#listing("dsa/samples-py/src/Ch12/prim.py", first: 13, last: 29, caption: [python, cheapest crossing edge from the sorted inside set])

#listing("dsa/samples-lua/ch12_prim.lua", first: 27, last: 54, caption: [lua, key, taken, parent, the min-scan loop])

Measured across the suites: Go, JavaScript, and Python land the same
6 as their kruskal from every start vertex, Python pinning the pick
order and the rerouted picks from vertex 1, all three flagging a
forest when a vertex is unreachable. C, Java, and Lua share their
6-edge fixture, total 13 with parents pinned from vertex 0 and the
same 13 from starts 4 and 2 under a different parent shape. The
frozen C\# suite pins equal totals against kruskal on its random
graphs.

#diagram([prim mid-growth, the cheapest edge crossing from the tree to the outside wins], length: 13pt, {
  // the tree so far: 0-1 (1), 1-2 (2); vertex 3 outside, three crossings
  let t = ((2.2, 5.9), (4.6, 6.6), (7.0, 5.9), (4.6, 3.6))
  cdraw.line(t.at(0), t.at(1), stroke: luma(100))
  cdraw.line(t.at(1), t.at(2), stroke: luma(100))
  cdraw.line(t.at(1), t.at(3), stroke: (paint: luma(100), thickness: 1.2pt))
  cdraw.line(t.at(0), t.at(3), stroke: (paint: luma(180), dash: "dashed"))
  cdraw.line(t.at(2), t.at(3), stroke: (paint: luma(180), dash: "dashed"))
  for (i, ch) in ("0", "1", "2", "3").enumerate() {
    let inside = i < 3
    cdraw.circle(t.at(i), radius: 0.3, fill: if inside { luma(205) } else { luma(235) })
    cdraw.content(t.at(i), ch, size: 6.5pt)
  }
  cdraw.content((3.4, 7.0), [1], size: 6pt)
  cdraw.content((6.0, 7.0), [2], size: 6pt)
  cdraw.content((4.0, 4.9), [3, the winner], size: 6pt)
  cdraw.content((2.7, 4.3), [4], size: 6pt)
  cdraw.content((6.2, 4.3), [5], size: 6pt)

  cdraw.content((14.6, 6.3), [inside: the tree so far], size: 6pt)
  cdraw.content((14.6, 5.2), [crossings: 3, 4, 5], size: 6pt)
  cdraw.content((14.6, 4.1), [the lightest one is safe], size: 6pt)
  cdraw.content((14.6, 3.0), [by the cut property], size: 6pt)
  cdraw.content((14.6, 1.9), [repeat n-1 times], size: 6pt)
})

#callout("note", "spanning trees are not shortest path trees", [
  The MST minimizes total edge weight, dijkstra minimizes per-vertex
  distance, and the two answers genuinely differ on shared inputs.
  A delivery network laying cable wants the MST, a navigation app
  routing each vehicle wants shortest paths. Chapter 11's tree and
  this chapter's tree are different objects with different
  optimality claims, a standard interview trap.
])

== maximum flow, edmonds-karp

Ford-Fulkerson repeatedly pushes flow along any augmenting path.
Edmonds-Karp fixes the path choice to BFS, shortest augmenting path
first, which bounds the whole algorithm polynomially. The residual
graph is the machinery: every edge carries capacity minus used flow,
and pushing flow creates reverse residual capacity, the undo
permission that lets later paths reroute earlier greed.

The dry run: the fixture is the C\# textbook network, s to a at 10,
s to b at 5, a to b at 15, a to t at 10, b to t at 10; the siblings
run smaller nets, Go, JavaScript, and Python pinning flow 5 and C,
Java, and Lua the classic 6-vertex 23.

+ The first BFS fans out from s, a and b join the wave, and t is
  reached through a: the path s, a, t runs at bottleneck
  min(10, 10) = 10.
+ The push fills s-a and a-t to 10 each, both residuals dropping to
  10 - 10 = 0.
+ The second BFS finds s-a spent, the wave reaches b, and the path
  s, b, t runs at bottleneck min(5, 10) = 5.
+ The total climbs 10 + 5 = 15, s-b sits saturated, and the third
  BFS stalls at the source with both exits at residual 0.
+ The per-edge reads land s-a 10, s-b 5, a-t 10, b-t 5, and the
  cross a-b 0, unneeded, with the flow value 15 pinned.
+ The all-capacity-1 trap graph lands flow 2 whatever order the
  paths take, the undo the reverse residual sells.

#diagram([the run as three bfs frames, two augmenting paths then the stall at a saturated source], length: 13pt, {
  let g = (x0, title, hot, l1, l2, note) => {
    let p = ((x0 + 1.2, 3.5), (x0 + 4.2, 5.3), (x0 + 4.2, 1.7), (x0 + 7.2, 3.5))
    cdraw.content((x0 + 4.2, 6.4), title, size: 6.5pt)
    cdraw.line(p.at(0), p.at(1), stroke: if "sa" in hot { luma(100) } else { luma(220) }, mark: (end: ">"))
    cdraw.line(p.at(0), p.at(2), stroke: if "sb" in hot { luma(100) } else { luma(220) }, mark: (end: ">"))
    cdraw.line(p.at(1), p.at(3), stroke: if "at" in hot { luma(100) } else { luma(220) }, mark: (end: ">"))
    cdraw.line(p.at(2), p.at(3), stroke: if "bt" in hot { luma(100) } else { luma(220) }, mark: (end: ">"))
    cdraw.line(p.at(1), p.at(2), stroke: luma(240))
    for (i, ch) in ("s", "a", "b", "t").enumerate() {
      cdraw.circle(p.at(i), radius: 0.3, fill: luma(235))
      cdraw.content(p.at(i), ch, size: 6pt)
    }
    cdraw.content((x0 + 2.3, 4.85), l1, size: 6pt)
    cdraw.content((x0 + 2.3, 2.15), l2, size: 6pt)
    cdraw.content((x0 + 4.2, 0.4), note, size: 6pt)
  }
  g(0.4, [path 1: s a t], ("sa", "at"), [10/10], [still open], [push 10])
  g(8.4, [path 2: s b t], ("sb", "bt"), [spent], [5/5], [push 5])
  g(16.4, [no path left], (), [0 left], [0 left], [value 15])
})

The 15 with the cross edge flat at 0 is the pinned read, and the
listings below push through the residual graph in seven languages.

#listing("dsa/samples-c/src/Ch12/maxflow.c", first: 47, last: 83, caption: [c, bfs over arc pairs, bottleneck push, xor to flip an arc])

#listing("dsa/samples-go/ch12/maxflow.go", first: 35, last: 71, caption: [go, matrix residual, bfs parent chain, bottleneck update])

#listing("dsa/samples-java/src/Ch12/Maxflow.java", first: 44, last: 87, caption: [java, bfs over arc pairs, endpoint flips an arc by its bit, the bottleneck push])

#listing("dsa/samples/src/Ch12/Flows.cs", first: 111, last: 199, caption: [c\#, residual capacities, bottleneck pushes, the bfs augmenting path])

The reverse-edge trick is the part worth staring at, and the test
named for it builds the classic trap graph where the first greedy
path through the cross edge must later be partially undone. Flow
conservation and capacity limits are asserted per edge on every
test.

#listing("dsa/samples-js/src/ch12-maxflow.mjs", first: 30, last: 70, caption: [javascript, arc pairs, private bfs, the push loop])

#listing("dsa/samples-py/src/Ch12/maxflow.py", first: 23, last: 50, caption: [python, residual copy, bfs, the path bottleneck])

#listing("dsa/samples-lua/ch12_maxflow.lua", first: 37, last: 81, caption: [lua, 1-based arc ids, bfs, the two push walks])

Measured across the suites: Go, JavaScript, and Python share a
5-edge network and pin flow 5 with the min cut at the saturated
source edges 0-1 and 0-2, plus a narrow middle edge bounding a
second fixture at 4. C, Java, and Lua share the classic 6-vertex
network, flow 23, per-edge flows 12 11 12 0 11 0 19 7 4,
conservation checked at every internal vertex, and the
residual-reachable set 0 1 2 4 cutting at capacity 23. The frozen
C\# suite pins the trap graph and asserts conservation and capacity
per edge.

#flow(
  [the trap graph, one augmenting path, and the reverse edge it opens],
  node((0, 0), [s]),
  node((2.4, 1.2), [a]),
  node((2.4, -1.2), [b]),
  node((4.8, 0), [t]),
  edge((0, 0), (2.4, 1.2), "-|>", label: [cap 10]),
  edge((2.4, 1.2), (2.4, -1.2), "-|>", label: [cap 1], label-side: right),
  edge((2.4, -1.2), (4.8, 0), "-|>", label: [cap 10]),
  edge((0, 0), (2.4, -1.2), "-|>", label: [cap 10]),
  edge((2.4, 1.2), (4.8, 0), "-|>", label: [cap 10]),
  edge((2.4, -1.2), (2.4, 1.2), "-", bend: -30deg, label: [rev, undo]),
)

== max-flow min-cut, verified

The theorem says the maximum flow equals the minimum capacity of any
s-t cut. The reachable set in the final residual graph is one side
of a minimum cut, saturated across the boundary.

The dry run: the fixtures are identical literals in all seven
suites. The textbook net, s-a 10, s-b 5, a-b 15, a-t 10, b-t 10,
lands flow
15 with the per-edge use 10, 5, 10, 5 and the cross flat at 0, cut
side {s}, cut capacity 15. The all-ones undo net lands flow 2 with
every flow inside its capacity. The parallel lane is two edges (s, t,
3) and (s, t, 4) accumulating to value 7. The verification lane
recomputes the residual-reachable cut and asserts its capacity equals
the flow value, with conservation at every internal vertex.

+ The residual walk seeds the reachable set with s and queues it.
+ Both exits are spent, s-a at 10 - 10 = 0 and s-b at 5 - 5 = 0, so
  neither a nor b ever joins: the reachable set is s alone, t
  outside.
+ The cut sums the original capacities crossing that boundary, s-a
  at 10 and s-b at 5: 10 + 5 = 15, asserted equal to the flow value
  15, the theorem checked by construction.
+ The two-pipe graph stacks parallel s-t edges of 3 and 4 into one
  capacity of 3 + 4 = 7, and the flow lands 7, the accumulation
  pinned.

#diagram([the residual probe stalling at a lone reachable source, and the two parallel pipes merging into one capacity], length: 13pt, {
  let p = ((1.4, 3.5), (4.6, 5.4), (4.6, 1.6), (7.8, 3.5))
  cdraw.rect((0.5, 2.4), (2.3, 4.6), fill: luma(205), radius: 0.05)
  cdraw.line((2.75, 2.4), (2.75, 4.6), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line(p.at(0), p.at(1), stroke: luma(100), mark: (end: ">"))
  cdraw.line(p.at(0), p.at(2), stroke: luma(100), mark: (end: ">"))
  cdraw.line(p.at(1), p.at(3), stroke: luma(220), mark: (end: ">"))
  cdraw.line(p.at(2), p.at(3), stroke: luma(220), mark: (end: ">"))
  cdraw.line(p.at(1), p.at(2), stroke: luma(240))
  for (i, ch) in ("s", "a", "b", "t").enumerate() {
    cdraw.circle(p.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(p.at(i), ch, size: 6pt)
  }
  cdraw.content((2.6, 5.05), [x], size: 7pt)
  cdraw.content((2.6, 1.95), [x], size: 7pt)
  cdraw.content((4.4, 4.8), [10 - 10 = 0], size: 6pt)
  cdraw.content((4.4, 2.2), [5 - 5 = 0], size: 6pt)
  cdraw.content((4.6, 0.7), [reachable: s alone, cut 10 + 5 = 15], size: 6pt)
  cdraw.content((15.6, 5.6), [parallel pipes], size: 6.5pt)
  cdraw.circle((12.4, 3.6), radius: 0.3, fill: luma(235))
  cdraw.content((12.4, 3.6), [s], size: 6pt)
  cdraw.circle((17.6, 3.6), radius: 0.3, fill: luma(235))
  cdraw.content((17.6, 3.6), [t], size: 6pt)
  cdraw.line((12.75, 3.78), (17.25, 3.98), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.9, 4.55), [cap 3], size: 6pt)
  cdraw.line((12.75, 3.42), (17.25, 3.22), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.9, 2.65), [cap 4], size: 6pt)
  cdraw.content((19.6, 4.3), [one (s, t) pair], size: 6pt)
  cdraw.content((19.6, 3.5), [capacity 3 + 4 = 7], size: 6pt)
  cdraw.content((19.6, 2.7), [flow 7], size: 6pt)
})

The 15 against 15 and the two-pipe 7 are the pins, and the listings
below are the seven readers that compute them.

#listing("dsa/samples-c/src/Ch12/mincut.c", first: 116, last: 142, caption: [c, residual reachability from s, then the cut capacity over the original edge records])

#listing("dsa/samples-go/ch12/mincut.go", first: 120, last: 137, caption: [go, the min cut side rebuilt from the residual graph])

#listing("dsa/samples-java/src/Ch12/Mincut.java", first: 116, last: 143, caption: [java, residual reachability from s, then the cut capacity over the original edge records])

#listing("dsa/samples/src/Ch12/Flows.cs", first: 202, last: 235, caption: [c\#, residual reachability gives the min cut side])

The test computes the cut capacity crossing that partition and
asserts it equals the flow value, the theorem checked by
construction rather than quoted. Parallel edges accumulate into one
capacity, which the two-pipe test pins.

#listing("dsa/samples-js/src/ch12-mincut.mjs", first: 84, last: 112, caption: [javascript, reachability over positive residual, the cut side as a set])

#listing("dsa/samples-py/src/Ch12/mincut.py", first: 68, last: 85, caption: [python, the reachable set walked off the final used map])

#listing("dsa/samples-lua/ch12_mincut.lua", first: 60, last: 86, caption: [lua, the bottleneck pushes, then the reach walk inside the same pass])

Measured across the suites: the three networks pin identically
everywhere, flow 15 with the cut side {s} of capacity 15, flow 2 on
the all-ones undo net, and 7 on the parallel pair, the merged arc
carrying all of it. C sums the cut capacity over the original edge
records and proves conservation as a signed out-sum of zero per
vertex, Java doing the same over string labels with parallel arcs
accumulated into one matrix cell, Python re-derives cut and
conservation from the used map alone, Go and JavaScript return the
reachable set for their tests to check, and Lua folds the reach
walk into the max-flow function, returning the set beside the flow
value.

#diagram([max-flow min-cut by construction, the residual reachable set is the source side, its boundary is saturated], length: 13pt, {
  // the trap graph at maximum flow: flow/capacity on every edge
  cdraw.rect((1.1, 6.1), (2.9, 7.5), fill: luma(205), radius: 0.05)
  let g = ((2.0, 6.8), (6.4, 8.0), (6.4, 5.6), (10.8, 6.8))
  cdraw.line(g.at(0), g.at(1), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(0), g.at(2), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(1), g.at(2), stroke: luma(220))
  cdraw.line(g.at(1), g.at(3), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(2), g.at(3), stroke: luma(100), mark: (end: ">"))
  for (i, ch) in ("s", "a", "b", "t").enumerate() {
    cdraw.circle(g.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(g.at(i), ch, size: 6.5pt)
  }
  cdraw.content((3.9, 7.75), [10/10], size: 6pt)
  cdraw.content((3.9, 5.6), [10/10], size: 6pt)
  cdraw.content((7.1, 6.8), [0/1], size: 6pt)
  cdraw.content((8.7, 7.65), [10/10], size: 6pt)
  cdraw.content((8.7, 5.85), [10/10], size: 6pt)

  cdraw.content((17.5, 5.9), [the reachable set in the], size: 6pt)
  cdraw.content((17.5, 4.8), [final residual is the cut], size: 6pt)
  cdraw.content((16.8, 3.5), [every edge across is saturated], size: 6pt)
  cdraw.content((16.6, 2.4), [cut capacity = flow value = 20], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines. The first table
covers the chapter's four original featured files per language, the
kruskal files folding their own DSU copy in C, Java, Python, and
Lua where the language has one file per topic:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [335], [libc only], [static arrays and qsort, arc pairs as 2i and 2i+1, checks share the file with main, 72 of them],
  [go], [198], [slices], [slices sort and clone, one DSU type shared by the package, prim min-scan by design, 11 tests],
  [java], [349], [jdk 27 stdlib], [one file per topic with the dsu inlined where kruskal needs it, records for the chosen tree, arcs flipped by their bit, 47 checks in 4 files],
  [c\#], [201], [bcl only], [string labels, prim rides the chapter 8 heap with a name tie break, min cut in the same file, 10 tests],
  [javascript], [145], [node stdlib], [arc-pair FlowNet with private fields, the dsu exports its parent for the compression proof, 11 tests],
  [python], [220], [stdlib only], [two dsu flavors, rehang and halving, residual copy per run, 32 checks],
  [lua], [347], [lib.lua harness], [1-based arc ids offset by one, xor flips arcs, maxinteger as the initial bottleneck, 15 checks],
)

The min-cut section lands as its own file in the six sibling trees,
the C\# side staying the reader inside the shared flow class:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [190], [libc only], [fixed arrays, the edge records kept whole, cut capacity summed over them, conservation as a signed out-sum],
  [go], [117], [slices], [pair-keyed maps, the cut side returned as a set for the tests to verify against the flow],
  [java], [190], [jdk 27 stdlib], [string labels over a first-seen name table, parallel arcs accumulated into one capacity cell, cut capacity and conservation asserted, 21 checks],
  [c\#], [33], [bcl only], [the MinCutSides reader inside the shared flow class, the flow it reads sits above it in the same file],
  [javascript], [95], [node stdlib], [pair keys joined on a nul byte, the used map reports positive forward entries only],
  [python], [112], [stdlib only], [deque bfs, the checks re-derive cut capacity and conservation from the used map],
  [lua], [153], [lib.lua harness], [the reach walk folded into the max-flow pass, maxinteger as the initial bottleneck, 5 check rows],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>` and
`HashSet<T>` pages used by the implementation, `Enumerable.OrderBy`
remarks, accessed 2026-09-08. Sample behavior verified by
`make verify-csharp`, 10 tests in chapter 12 of the samples suite.
The seven-language layer verifies the same way: 5 C programs with 93
embedded checks under `make verify-c`, 15 Go tests, the java
runner's 68 Ch12 checks over 5 files under `run-java-samples`, 16
`node --test` cases, 49 Python checks across 5 files, and 20 Lua
checks under `run.lua`.
