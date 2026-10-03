#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= weighted graphs: dijkstra, union-find, mst

Weights are the second graph round. The traversals of
#xref-to("repertoire", "graphs") answered reachability and edge-count
distance, and once edges carry costs the questions become cheapest
path and cheapest connection. The answers here are dijkstra over a
heap frontier, union-find as the cycle oracle, and the kruskal and
prim pair over it. All of it runs in the `ch24-go` module under
`make verify`, 12 tests, stdlib only, `container/heap` carrying both
frontiers. The heap implemented from zero sits in
#xref-to("repertoire", "datastructures"), and the depth floors to
#xref-to("dsa", "shortestpaths") and #xref-to("dsa", "mstflows").

== dijkstra, heap-driven [TDD]

Dijkstra is bfs with a relax loop. Each pop takes the cheapest
candidate distance and offers every neighbor `popped + w`, the
distance map doubles as the finalized set, and a node absent from
the map is at infinity:

#listing("interview-repertoire/samples/ch24-go/dijkstra.go", first: 31, last: 73, caption: [the distance map, the lazily-deleted frontier, the relax loop, the parent walk home])

#diagram([one node, two entries: the shorter candidate wins the pop, the longer surfaces later and is skipped], length: 13pt, {
  // the ladder fixture: the direct 1-2 edge costs 7, the route through 4 and 3 costs 4
  let ball(x, y, t) = {
    cdraw.circle((x, y), radius: 0.34, fill: luma(235), stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6pt)
  }
  ball(2.6, 6.6, "1")
  ball(8.6, 6.6, "2")
  ball(2.6, 3.6, "4")
  ball(8.6, 3.6, "3")
  // the losing direct edge, dashed
  cdraw.line((2.9, 6.6), (8.3, 6.6), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((5.6, 7.0), [7], size: 6pt)
  // the winning route, thick
  cdraw.line((2.6, 6.3), (2.6, 3.9), stroke: luma(40))
  cdraw.line((2.9, 3.6), (8.3, 3.6), stroke: luma(40))
  cdraw.line((8.6, 3.9), (8.6, 6.3), stroke: luma(40))
  cdraw.content((1.9, 5.1), [1], size: 6pt)
  cdraw.content((5.6, 3.2), [2], size: 6pt)
  cdraw.content((9.3, 5.1), [1], size: 6pt)
  // node 2's two heap entries: the stale one dashed, the winner solid
  cdraw.content((14.2, 6.6), [the heap holds both], size: 6pt)
  cdraw.rect((13.0, 4.9), (15.6, 5.8), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((14.3, 5.35), [(4, 2)], size: 6pt)
  cdraw.content((16.6, 5.35), [pops first], size: 6pt)
  cdraw.rect((13.0, 3.2), (15.6, 4.1), fill: luma(250), stroke: (paint: luma(190), dash: "dashed"), radius: 0.02)
  cdraw.content((14.3, 3.65), [(7, 2)], size: 6pt)
  cdraw.content((16.6, 3.65), [stale, skipped], size: 6pt)
  cdraw.content((14.2, 1.9), [dist[2] = 4, the direct edge loses], size: 6pt)
  cdraw.content((5.6, 1.9), [the ladder fixture], size: 6pt)
})

The subtlety worth narrating is the stale entry. Go's
`container/heap` has no decrease-key, so every relaxation pushes a
new entry and the shorter one wins the pop, and when a longer
candidate surfaces later the guard `cur.dist > dist[cur.node]`
skips it. That is lazy deletion, and it is why the heap carries at
most one entry per relaxation. The tie rule is pinned too:
relaxation is strict, neighbors are sorted by id, so equal-cost
routes keep the lowest-id parent, and the square fixture of
`TestDijkstraTieKeepsFirstParent` returns `[1 2 4]`, never
`[1 3 4]`.

The non-negative rule is enforced, and the reason to say out loud is
the pop itself: finalizing a node is the belief that nothing cheaper
can arrive later, and a negative edge breaks the belief, the node's
distance keeps improving after it left the frontier and the answer
goes quietly wrong. The corpus makes it loud instead, `AddEdge`
panics on a negative weight and `TestNegativeWeightPanicsOnAdd`
pins it. What to run instead is the bellman-ford question, drilled
at the bottom of this chapter.

#callout("note", "say the complexity with the heap named", [
  One pop per surviving entry and one push per relaxation puts the
  loop at O(E log E), and since E stays under V^2 the exponent sits
  within a constant of log V, which is why the spoken O(E log V) is
  honest. The space follow-up is the distance and parent maps, both
  vertex-counted, the heap adds at most one entry per relaxation.
])

== union-find with path compression [TDD]

The mst half rides on one small structure. Union-find tracks
disjoint sets, `Find` returns the root of a set, and `Union`
merges two sets and reports false when both endpoints already
share a root, which is exactly the cycle test an undirected edge
needs:

#listing("interview-repertoire/samples/ch24-go/uf.go", first: 20, last: 50, caption: [two-pass find that re-parents the walked path, union by rank, the cycle refusal])

#diagram([find(7) walks three hops, then re-parents the whole path onto the root], length: 13pt, {
  // left panel before: the chain 7 to 6 to 4 to 0, one hop at a time
  let ball(x, y, t) = {
    cdraw.circle((x, y), radius: 0.34, fill: luma(235), stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6pt)
  }
  let link(p, q, thick) = {
    let st = if thick { luma(40) } else { luma(170) }
    cdraw.line(p, q, stroke: st, mark: (end: ">"))
  }
  link((3.0, 2.6), (3.0, 3.9), false)
  link((3.0, 4.7), (3.0, 6.0), false)
  link((3.0, 6.8), (3.0, 8.1), false)
  ball(3.0, 2.2, "0")
  ball(3.0, 4.3, "4")
  ball(3.0, 6.4, "6")
  ball(3.0, 8.5, "7")
  cdraw.content((5.2, 8.5), [before], size: 6pt)
  // after the find: 7, 6, and 4 all point straight at the root
  link((7.6, 6.1), (9.9, 2.6), true)
  link((10.4, 6.1), (10.4, 2.6), true)
  link((13.2, 6.1), (10.9, 2.6), true)
  ball(7.6, 6.4, "7")
  ball(10.4, 6.4, "6")
  ball(13.2, 6.4, "4")
  ball(10.4, 2.2, "0")
  cdraw.content((15.4, 6.4), [after find(7)], size: 6pt)
  cdraw.content((9.2, 0.7), [compression flattens the walked path, the next find is one hop], size: 6pt)
})

`TestFindCompressesThePathItWalked` is white-box on purpose: it
pairs equal-rank trees until node 7 hangs three hops off the root,
calls `Find(7)` once, then asserts `parent[7]` and `parent[6]`
both hold the root directly. Without compression those slots keep
the old chain. `TestUnionByRankKeepsTheBiggerRoot` pins the attach
direction, a rank-2 root absorbs a rank-1 tree with no rank raise,
so trees stay shallow and the finds stay short. The refusal is the
interface kruskal consumes, `TestUnionRefusesTheCycle` checks every
shape of it, the repeat, the transitive repeat, the closing edge.

== kruskal and prim, the mst pair [TDD]

Kruskal is a sorted edge list plus the cycle oracle: consume edges
cheapest first, take each one whose endpoints union, skip the rest.
The skip is the algorithm, an edge whose endpoints already share a
root closes a cycle and can never sit in a tree:

#listing("interview-repertoire/samples/ch24-go/mst.go", first: 5, last: 23, caption: [sorted edges consumed cheapest first, union as the take-or-skip test])

Prim grows from a start node instead. The cut between the tree and
the unseen nodes is a heap of crossing edges, pop the cheapest,
add it, push its endpoint's edges, and the same lazy deletion runs
here, a pop whose endpoint joined meanwhile is skipped:

#listing("interview-repertoire/samples/ch24-go/mst.go", first: 45, last: 71, caption: [the cut heap, pop the cheapest crossing, skip the stale pops])

#diagram([the box fixture: the 1, 2, and 3 edges span, the 4 and the 6 would close cycles], length: 13pt, {
  // diamond 1 top, 0 left, 2 right, 3 bottom: the taken edges ring it, the rejects cross the middle
  let ball(x, y, t) = {
    cdraw.circle((x, y), radius: 0.34, fill: luma(235), stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6pt)
  }
  ball(2.5, 4.4, "0")
  ball(5.6, 6.9, "1")
  ball(8.7, 4.4, "2")
  ball(5.6, 1.9, "3")
  // the taken ring, thick: 0-1 at 1, 1-2 at 2, 2-3 at 3
  cdraw.line((2.8, 4.6), (5.3, 6.7), stroke: luma(40))
  cdraw.content((3.4, 6.1), [1], size: 6pt)
  cdraw.line((5.9, 6.7), (8.4, 4.6), stroke: luma(40))
  cdraw.content((7.8, 6.1), [2], size: 6pt)
  cdraw.line((8.4, 4.2), (5.9, 2.1), stroke: luma(40))
  cdraw.content((7.8, 2.7), [3], size: 6pt)
  // the rejected crossings, dashed: 0-2 at 4, 1-3 at 6
  cdraw.line((2.9, 4.4), (8.3, 4.4), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((4.3, 4.8), [skip, 4], size: 6pt)
  cdraw.line((5.6, 6.5), (5.6, 2.3), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((6.1, 5.4), [skip, 6], size: 6pt)
  // the ledger kruskal keeps, weights in consume order
  for i in range(5) {
    cdraw.rect((12.6 + i * 1.5, 3.7), (13.9 + i * 1.5, 4.8), fill: luma(230), radius: 0.02)
  }
  for i in range(5) {
    cdraw.content((13.25 + i * 1.5, 4.25), str((1, 2, 3, 4, 6).at(i)), size: 6pt)
  }
  cdraw.content((12.6, 5.5), [consume order], size: 6pt)
  cdraw.content((12.6, 2.7), [take, take, take, skip, skip], size: 6pt)
  cdraw.content((5.6, 0.4), [total 6, both algorithms agree on the box fixture], size: 6pt)
})

When each wins is a representation question. Kruskal wants the
edge list, sort once and stream, so it wins on sparse graphs and
when edges arrive pre-sorted. Prim wants adjacency and a start
node, so it wins on dense graphs and when the answer must hang off
one component. The suite proves them interchangeable on totals,
`TestPrimMatchesKruskalAndReportsDisconnection` asserts both return
6 on the box fixture, and both carry the same disconnection
verdict.

#callout("pitfall", "a disconnected graph ships a forest unless you check", [
  Both functions answer ok false when no spanning tree exists:
  kruskal returns the minimum forest across the components, prim
  from a start node returns the tree of the component it can reach.
  A caller that ignores the third return ships a forest labeled as
  a tree, and the disconnected fixtures in both test functions
  exist to keep that failure loud.
])

== when bellman-ford and floyd-warshall [DRILL]

The spoken answer, one breath: dijkstra is single source over
non-negative weights with a heap, O(E log V). Bellman-ford is
single source with negative edges allowed, V-1 rounds of relaxing
every edge, O(V E), and a V-th round that still improves something
proves a negative cycle, so no shortest paths exist. Floyd-warshall
is all pairs, dynamic programming over a V by V matrix, O(V^3),
negative edges fine, negative cycles visible as a negative
diagonal. The corpus implements both in the handbook,
#xref-to("dsa", "shortestpaths"), not here: the loop asks for
dijkstra and the mst pair as code and these two as a precise when,
and this book keeps that split, the same division
#xref-to("dsa", "graphs") draws for the unweighted family.

#diagram([the when table, said before any code: scope and contract pick the algorithm], length: 13pt, {
  // three columns: algorithm, scope, contract and cost
  let cell(x, y, w, h, t, fill: luma(235), size: 6pt) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), [#t], size: size)
  }
  cell(0.0, 6.2, 5.4, 1.2, "", fill: luma(252))
  cell(5.4, 6.2, 5.8, 1.2, [scope], fill: luma(215))
  cell(11.2, 6.2, 9.0, 1.2, [contract, cost], fill: luma(215))
  cell(0.0, 4.8, 5.4, 1.3, [dijkstra], fill: luma(252))
  cell(5.4, 4.8, 5.8, 1.3, [one source])
  cell(11.2, 4.8, 9.0, 1.3, [non-negative, heap, O(E log V)])
  cell(0.0, 3.3, 5.4, 1.3, [bellman-ford], fill: luma(252))
  cell(5.4, 3.3, 5.8, 1.3, [one source])
  cell(11.2, 3.3, 9.0, 1.3, [negatives ok, V-1 rounds, O(V E)])
  cell(0.0, 1.8, 5.4, 1.3, [floyd-warshall], fill: luma(252))
  cell(5.4, 1.8, 5.8, 1.3, [every pair])
  cell(11.2, 1.8, 9.0, 1.3, [matrix dp, O(V^3), small V])
  cdraw.content((10.8, 0.5), [a V-th improving round is the negative-cycle detector], size: 6pt)
})

The follow-up to expect: why not always run floyd-warshall, one
answer for every pair. Because V^3 is brutal past a few hundred
nodes and the single-source question asks for a fraction of the
work, one heap pass. The reverse follow-up: why does dijkstra fail
on negative edges. The pop finalizes, finalization is a belief, and
the belief only holds when every step forward adds cost, which is
the same sentence as the non-negative contract this chapter
enforces in `AddEdge`.

sources: verified by `go test` through `make verify`, 12 tests in
`ch24-go`. Depth on the shortest-path family floors to
#xref-to("dsa", "shortestpaths"), the mst and flows depth to
#xref-to("dsa", "mstflows"), and the unweighted traversals this
chapter builds on stay in #xref-to("repertoire", "graphs").
