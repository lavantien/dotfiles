#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= graphs: dfs, bfs, topological sort

Traversal is the graph interview. Two orders cover the questions:
depth first for reachability, structure, and cycle detection, breadth
first for distance and layering, and topological sort is bfs with a
counter attached. All of it runs in the `ch04-go` module under
`make verify`.

== dfs and bfs, one shape apart [TDD]

The two traversals differ in one data structure: dfs recurses, the
call stack is the frontier, bfs loops over a queue. Both visit the
same set, and the suite proves it by sorting both orders and
comparing:

#listing("interview-repertoire/samples/ch04-go/traverse.go", first: 53, last: 82, caption: [dfs recurses, bfs walks the queue by index])

#diagram([two frontiers, one visited set: the call stack against the head-indexed queue], length: 13pt, {
  // the same house graph twice, the emphasized edges are the ones each walk takes first
  let panel(ox, deep) = {
    let ball(x, y, t) = {
      cdraw.circle((ox + x, y), radius: 0.34, fill: luma(235), stroke: luma(120))
      cdraw.content((ox + x, y), [#t], size: 6.5pt)
    }
    let e(a, b, thick) = {
      let st = if thick { luma(40) } else { luma(170) }
      cdraw.line((ox + a.at(0), a.at(1)), (ox + b.at(0), b.at(1)), stroke: st)
    }
    e((3.5, 7.2), (1.5, 5.9), true)      // 1-2, both walks
    e((3.5, 7.2), (5.5, 5.9), deep == false)  // 1-4, bfs widens first
    e((1.5, 5.9), (3.5, 4.6), deep)      // 2-3, dfs goes deep
    ball(3.5, 7.2, "1")
    ball(1.5, 5.9, "2")
    ball(5.5, 5.9, "4")
    ball(3.5, 4.6, "3")
  }
  panel(0.5, true)
  panel(12.5, false)
  cdraw.content((5.0, 8.4), [dfs, depth first], size: 6.5pt)
  cdraw.content((17.0, 8.4), [bfs, breadth first], size: 6.5pt)
  // the two frontiers, in visit order
  for i in range(4) {
    cdraw.rect((1.4 + i * 1.3, 3.0), (2.7 + i * 1.3, 3.9), fill: luma(230), radius: 0.02)
    cdraw.content((2.05 + i * 1.3, 3.45), str(i + 1), size: 6pt)
    cdraw.rect((13.4 + i * 1.3, 3.0), (14.7 + i * 1.3, 3.9), fill: luma(230), radius: 0.02)
    cdraw.content((14.05 + i * 1.3, 3.45), (str(i + 1), "2", "4", "3").at(i), size: 6pt)
  }
  cdraw.content((5.0, 2.2), [the call stack], size: 6pt)
  cdraw.content((17.4, 2.3), [the slice queue], size: 6pt)
  cdraw.line((13.4, 2.6), (13.4, 3.0), stroke: luma(100))
  cdraw.content((13.4, 1.9), [head], size: 6pt)
  cdraw.content((11.0, 0.6), [same visited set, the suite sorts both and compares], size: 6.5pt)
})

The bfs here is the slice-queue idiom worth narrating: `head`
indexes the front, append pushes the back, and the slice is its own
queue without a container type. On the house graph the two orders
come out `[1 2 3 4]` and `[1 2 4 3]`, same set, different shape.

== shortest path on an unweighted graph [TDD]

Bfs with parent pointers is shortest path whenever edges are
unweighted: the first time a node is seen is via a shortest path,
so recording the parent and walking back reconstructs it:

#listing("interview-repertoire/samples/ch04-go/traverse.go", first: 84, last: 112, caption: [parent map, first-seen recording, path reconstruction])

#diagram([first seen is via a shortest path, the parents walk it home], length: 13pt, {
  // levels left to right, dashed separators are the distance bands
  cdraw.line((1.0, 6.75), (18.5, 6.75), stroke: (paint: luma(200), dash: "dashed"))
  cdraw.line((1.0, 4.2), (18.5, 4.2), stroke: (paint: luma(200), dash: "dashed"))
  cdraw.content((20.3, 6.75), [distance 1], size: 6pt)
  cdraw.content((20.3, 4.2), [distance 2], size: 6pt)
  // discovery edges thin, parent backlinks thick: the path home
  cdraw.line((3.5, 7.15), (6.3, 6.45), stroke: luma(180), mark: (end: ">"))
  cdraw.line((3.5, 6.9), (6.3, 5.15), stroke: luma(180), mark: (end: ">"))
  cdraw.line((7.7, 5.9), (10.3, 3.75), stroke: luma(180), mark: (end: ">"))
  cdraw.line((6.7, 6.45), (3.8, 7.2), stroke: luma(40), mark: (end: ">"))
  cdraw.line((10.9, 3.8), (7.3, 6.0), stroke: luma(40), mark: (end: ">"))
  cdraw.content((5.3, 7.75), [parents], size: 6pt)
  cdraw.line((15.0, 2.95), (12.1, 3.25), stroke: luma(180), mark: (end: ">"))
  let ball(x, y, t, faded: false) = {
    cdraw.circle((x, y), radius: 0.34, fill: if faded { luma(250) } else { luma(235) }, stroke: if faded { luma(190) } else { luma(120) })
    cdraw.content((x, y), [#t], size: 6.5pt)
  }
  ball(3.0, 7.5, "s")
  ball(7.0, 6.2, "a")
  ball(7.0, 4.9, "b")
  ball(11.0, 3.4, "c")
  ball(15.0, 3.4, "u", faded: true)
  cdraw.content((8.0, 1.9), [the path home], size: 6pt)
  cdraw.content((15.6, 2.3), [edge points into c], size: 6pt)
  cdraw.content((15.6, 1.2), [so from c, u unseen], size: 6pt)
  cdraw.content((11.0, -0.1), [first seen is via a shortest path, walk the parents back], size: 6pt)
})

The test pins the direction subtlety: upstream search in a directed
graph correctly reports unreachable, the asymmetric case candidates
forget.

== kahn's topological sort [TDD]

Topological order is in-degree bookkeeping: count incoming edges,
repeatedly emit a zero in-degree node and subtract its outgoing
edges. When the loop consumes every node an order exists, when it
stalls the remainder sits on a cycle:

#listing("interview-repertoire/samples/ch04-go/topo.go", first: 5, last: 55, caption: [in-degree counts, the ready set, and the stall that means a cycle])

#flow([in-degrees drain through the sorted ready set, a stall is the cycle],
  node((0, 0), [count in-degrees]),
  node((2.2, 0), [ready set, sorted]),
  node((4.4, 0), [emit, subtract]),
  node((6.9, 1.3), [an order exists]),
  node((6.9, -1.3), [a cycle remains]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.4, 0), "-|>"),
  edge((4.4, 0), (2.2, 0), "-|>", bend: 40deg, label: [next]),
  edge((4.4, 0), (6.9, 1.3), "-|>", label: [consumed all]),
  edge((4.4, 0), (6.9, -1.3), "-|>", label: [stalled]),
)

The deterministic ready set, kept sorted, makes the test assert the
exact order `[4 5 0 2 3 1]` and every edge's position, a stronger
check than "is a valid order". The course-schedule phrasing of the
same question sits below it, prerequisites as edges from prereq to
course, `true` exactly when the sort exists.

#callout("note", "say the complexity, then prove you know what n is", [
  Dfs and bfs are both O(V + E), vertices plus edges. The follow-up
  that scores is naming the space term: dfs carries the recursion
  depth, worst case the vertex count on a path graph, bfs carries
  the frontier width, worst case also the vertex count on a star.
  Neither is free, and the two worst cases are different graphs.
])

sources: verified by `go test` through `make verify`, 10 tests in
`ch04-go`. Depth on traversal families floors to
#xref-to("dsa", "analysis") and the graph chapters that follow it.
