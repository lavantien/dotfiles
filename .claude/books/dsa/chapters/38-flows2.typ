#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= network flows ii

Chapter 12 built the residual graph and ran edmonds-karp over it, one
shortest augmenting path at a time. This chapter keeps the residual
graph and changes the search. Dinic stratifies it by levels and pushes
blocking flows, push-relabel abandons paths entirely and ships excess
downhill by height labels, and both answer in numbers the fixture
families pin. Then the family around the flow idea: minimum-cost flow
by successive shortest paths, lower bounds through a super-source
transform, the stoer-wagner global cut, and the matching trio of
kuhn, hungarian, and hall's theorem, each with its own contest face.
The icpc applications run through 2017 problems C and J, 2018 problem
C, 2022 problem X, and 2025 problems B and F.

== dinic's algorithm

Same residual graph as the edmonds-karp baseline of
#xref-to("dsa", "mstflows"), smarter search. A bfs from the source
labels every vertex with its level, the shortest-path distance over
arcs that still carry capacity. The dfs then pushes flow only along
level-plus-one arcs, so every augmenting path is shortest, and it
keeps going until the level graph is blocked, no path remains. The
per-vertex iteration pointer is what makes a phase cheap: when a
recursive push through an arc fails, the arc is abandoned for the
rest of the whole phase, never retried, so the blocking flow costs
one pass of pointer advances. Phase count is O(V) in general and
O(sqrt(E)) on unit-capacity graphs, for the O(V^2 E) total. Arcs live
in one flat list with paired residuals, forward at even indices, the
backward twin at the odd neighbor, so xor with 1 always finds the
reverse arc.

The dry run: the fixture is the pinch network, source 0, sink 6, its
arcs and answers pinned word for word by all seven suites, and the walk
replays the phases on those capacities.

+ The first bfs levels the graph: 1 and 2 land level 1, 3 and 4 land
  level 2, the sink 6 lands level 3, and every push must climb exactly
  one level per arc.
+ The first path runs 0, 1, 3, 6 at bottleneck min(10, 4, 10) = 4 and
  fills the 4-wide 1 to 3 arc exactly.
+ The pointer at 1 steps past its spent arc, so the second path turns
  over 0, 1, 4, 6 at min(6, 8, 3) = 3: the 3-wide pinch saturates.
+ Vertex 4 now has no arc left into level 3, its pointer runs off the
  end of the list, and the third path crosses 0, 2, 3, 6 at
  min(10, 9, 6) = 6, closing 3 to 6 at 4 + 6 = 10 of 10.
+ The blocking flow totals 4 + 3 + 6 = 13 with both sink arcs spent,
  and the second bfs strands the sink at level minus 1: the run
  returns 13.
+ The residual walk from 0 keeps exactly {0, 1, 2, 3, 4}, the cut side
  of value 13, and the parallel-arc fixture folds the same machine to
  5 with its sinkless arc carrying nothing.

#diagram([the pinch network three times, one augmenting path bold per frame, the pinch and the sink arc saturating in sequence], length: 13pt, {
  // three frames of phase 1, capacities labeled, the pushed path dark
  let net = (x0, hot, title) => {
    let p = (s: (x0 + 0.7, 3.2), a: (x0 + 2.7, 4.9), b: (x0 + 2.7, 1.5), c: (x0 + 4.7, 4.9), d: (x0 + 4.7, 1.5), t: (x0 + 6.7, 3.2))
    let arc = (u, v, lab, f) => {
      cdraw.line(p.at(u), p.at(v), stroke: if (u, v) in hot { luma(60) } else { luma(235) })
      let (x1, y1) = p.at(u)
      let (x2, y2) = p.at(v)
      cdraw.content((x1 + f * (x2 - x1), y1 + f * (y2 - y1) + 0.32), lab, size: 6pt)
    }
    arc("s", "a", [10], 0.5); arc("s", "b", [10], 0.5)
    arc("a", "c", [4], 0.5); arc("a", "d", [8], 0.3)
    arc("b", "c", [9], 0.3); arc("b", "d", [6], 0.5)
    arc("c", "t", [10], 0.5); arc("d", "t", [3], 0.5)
    for (k, ch) in (("s", [0]), ("a", [1]), ("b", [2]), ("c", [3]), ("d", [4]), ("t", [6])) {
      cdraw.circle(p.at(k), radius: 0.3, fill: luma(240), stroke: luma(120))
      cdraw.content(p.at(k), ch, size: 7pt)
    }
    cdraw.content((x0 + 3.7, 6.15), title, size: 6pt)
  }
  net(0.4, (("s", "a"), ("a", "c"), ("c", "t")), [push 4 over 0, 1, 3, 6])
  net(7.7, (("s", "a"), ("a", "d"), ("d", "t")), [push 3 over 0, 1, 4, 6])
  net(15.0, (("s", "b"), ("b", "c"), ("c", "t")), [push 6 over 0, 2, 3, 6])
  cdraw.content((9.6, 0.6), [phase 1: 4 + 3 + 6 = 13, both sink arcs spent], size: 6pt)
  cdraw.content((9.6, -0.2), [phase 2 bfs strands the sink at level -1], size: 6pt)
  cdraw.content((9.6, -1.0), [cut side {0, 1, 2, 3, 4} at value 13], size: 6pt)
})

The 13 with the cut side {0, 1, 2, 3, 4} is the seven-suite pin, and
the listings below run these phases in seven languages.

#listing("dsa/samples-c/src/Ch38/dinic.c", first: 47, last: 93, caption: [c, the level bfs, the blocking dfs with the pointer, the phase loop])
#listing("dsa/samples-go/ch38/dinic.go", first: 30, last: 82, caption: [go, levels by bfs, blocking flow by recursion over the level graph])
#listing("dsa/samples-java/src/Ch38/Dinic.java", first: 45, last: 93, caption: [java, the level bfs, the blocking dfs with the pointer, the phase loop])
#listing("dsa/samples/src/Ch38/Flow2.cs", first: 31, last: 82, caption: [c\#, the same phase loop, the nested dfs abandons each dead arc once])
#listing("dsa/samples-js/src/ch38-dinic.mjs", first: 41, last: 83, caption: [javascript, the private dfs and the phase driver, exact on number below 2^53])
#listing("dsa/samples-py/src/Ch38/dinic.py", first: 32, last: 79, caption: [python, the nested dfs with the pointer, the cut side walk below])
#listing("dsa/samples-lua/ch38_dinic.lua", first: 28, last: 73, caption: [lua, the same phases, 1-based tables over the 0-based public face])

The min cut falls out of the last residual graph: the set of vertices
still reachable from the source is exactly the source side of a
minimum cut, and every solver here reports it.

The fixture families pin identical numbers in all seven languages. The
pinch network, source 0, sink 6, arcs (0,1,10), (0,2,10), (1,3,4),
(1,4,8), (2,3,9), (2,4,6), (3,6,10), (4,6,3), flows 13 with the cut
side {0,1,2,3,4}: the arc 4 to 6 of capacity 3 is the pinch. Parallel
arcs (0,1,3) and (0,1,4) against a 5 bottleneck flow 5, a dead arc to
a sinkless vertex carrying nothing. The 2017 problem J mini network in
water-equivalent units answers all three of its questions from the one
solver: a super source feeding stations 1 and 2 at 100 each, pipes
1-3 (4), 2-3 (4), 1-4 (2), 3-4 (2) installed as paired arcs both
ways, sink 3, gives Z = 10, and rerunning without the super source
gives Fmax = 6 from station 1 alone and Wmax = 4 from station 2. The
seeded family draws 40 arcs over 20 plus 20 nodes from the pinned lcg,
and the unit-capacity flow of 18 equals the kuhn matching size of the
same graph, the cross-check the kuhn section below leans on. Java's
copy of that generator keeps the lcg state in a signed int, so the
draw routes through Integer.remainderUnsigned, a plain % goes
negative once the state crosses 2^31 and the arc list drifts.

#diagram([the pinch network with the saturated 4 to 6 arc, level numbers on vertices, the minimum cut drawn between the two sides], length: 13pt, {
  let pos = ("0": (1.2, 5.0), "1": (4.2, 6.6), "2": (4.2, 3.4), "3": (7.6, 6.6), "4": (7.6, 3.4), "6": (11.0, 5.0))
  let lvl = ("0": [0], "1": [1], "2": [1], "3": [2], "4": [2], "6": [3])
  let arc = (u, v, label, hot) => {
    let (x1, y1) = pos.at(str(u))
    let (x2, y2) = pos.at(str(v))
    cdraw.line((x1, y1), (x2, y2), stroke: if hot { luma(60) } else { luma(170) })
    cdraw.content(((x1 + x2) / 2, (y1 + y2) / 2 + 0.32), label, size: 6pt)
  }
  arc(0, 1, [10], false)
  arc(0, 2, [10], false)
  arc(1, 3, [4], false)
  arc(1, 4, [8], false)
  arc(2, 3, [9], false)
  arc(2, 4, [6], false)
  arc(3, 6, [10], false)
  arc(4, 6, [3], true)
  for (v, (x, y)) in pos {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), [#v], size: 7pt)
    cdraw.content((x, y - 0.52), [lvl #(lvl.at(v))], size: 6pt)
  }
  cdraw.content((0.5, 5.0), [s], size: 6pt)
  cdraw.content((11.7, 5.0), [t], size: 6pt)
  // the cut line between {0,1,2,3,4} and {6}
  cdraw.line((9.4, 2.2), (9.4, 7.6), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((9.4, 8.1), [cut of value 13], size: 6pt)
  cdraw.content((5.6, 1.2), [flow 13: 10 through 3, 3 through the saturated pinch], size: 6pt)
  cdraw.content((16.4, 7.0), [levels from s, arcs climb one], size: 6pt)
  cdraw.content((16.4, 5.9), [the pointer abandons dead arcs], size: 6pt)
  cdraw.content((16.4, 4.8), [per phase, o(v) phases], size: 6pt)
  cdraw.content((16.4, 3.7), [unit caps: o(sqrt(e)) phases], size: 6pt)
  cdraw.content((16.4, 2.6), [cut side: residual-reachable], size: 6pt)
})

The application is icpc world finals 2017 problem J (book 10, chapter
8), son of pipe stream, whose water-equivalent network is answered by
four dinic runs over exactly this residual machinery, and the F3
fixture above is its crafted sample.

== push-relabel

Drop the augmenting path entirely. A preflow violates conservation on
purpose: the source arcs are saturated at the start, every vertex
holds an excess, and the algorithm moves excess around instead of
building paths. Each vertex carries an integer height label, the
source at n, and an arc is admissible when it carries capacity and
drops exactly one height level. The discharge loop pushes excess along
admissible arcs, and a vertex that cannot push anywhere is relabeled
to one above its lowest reachable neighbor, so the excess always has a
way out. The fifo queue keeps the discharges moving, the sink absorbs
everything that arrives, and the excess at the sink is the flow value.

The dry run: the fixture is the parallel network, twin arcs (0,1,3)
and (0,1,4) folding onto one dense cell of 7 against the 5 bottleneck,
pinned at 5 by all seven suites; the edge family splits after it, python
carrying the unreachable sink at 0 and the single arc of capacity 7.

+ Saturation pushes the whole folded 7 onto vertex 1 and leaves the
  source arc at 0, a preflow on purpose: vertex 1 holds excess 7.
+ Vertex 1 starts at height 0 among neighbors at 0, 0, and 4, stuck,
  so it relabels to 1 + min(4, 0, 0) = 1.
+ Admissible now: the drop to the sink carries min(7, 5) = 5 and the
  sink absorbs it, then the drop to the sinkless vertex 3 takes the
  remaining min(2, 9) = 2.
+ Vertex 3 has one exit, back to 1: it lifts to 1 + 1 = 2 and returns
  the 2, then 1 lifts to 1 + min(4, 2) = 3 and sends them back, then 3
  lifts to 1 + 3 = 4 and returns them again.
+ Vertex 1 finally lifts to 1 + 4 = 5, exactly one above the source,
  and the last 2 drains home through the residual: conservation
  restored everywhere but the sink.
+ The sink's excess reads 5, the pinned value, and the same machine
  answers 13 on the pinch network and 10 on the 2017 problem J graph.

#diagram([the parallel network under push-relabel, the source saturated, the sink filled, the stranded 2 climbing the height ladder home], length: 13pt, {
  // 0 -> 1 -> 2 with the sinkless 3 below 1, final heights beside
  let v = ("0": (1.6, 5.6), "1": (5.6, 5.6), "2": (9.6, 5.6), "3": (5.6, 2.4))
  cdraw.line(v.at("0"), v.at("1"), stroke: luma(170), mark: (end: ">"))
  cdraw.content((3.6, 5.0), [0 of 7, the fold 3 + 4], size: 6pt)
  cdraw.line((5.4, 6.15), (1.9, 6.15), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.65, 6.6), [last 2 home], size: 6pt)
  cdraw.line(v.at("1"), v.at("2"), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.6, 6.15), [5 to the sink], size: 6pt)
  cdraw.line((5.35, 5.3), (5.35, 2.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.85, 2.7), (5.85, 5.3), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.9, 4.0), [2 onto the dead end], size: 6pt)
  cdraw.content((7.4, 4.0), [2 back, twice], size: 6pt)
  cdraw.content((0.75, 5.6), [h 4], size: 6pt)
  cdraw.content((5.6, 6.6), [h 5], size: 6pt)
  cdraw.content((10.45, 5.6), [h 0], size: 6pt)
  cdraw.content((5.6, 1.75), [h 4], size: 6pt)
  for (k, (x, y)) in v {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), [#k], size: 7pt)
  }
  cdraw.content((6.0, 0.9), [saturate 7, relabel 1 + min(4, 0, 0) = 1], size: 6pt)
  cdraw.content((6.0, 0.1), [5 to the sink, 2 onto 3, ladder 2, 3, 4, 5], size: 6pt)
  cdraw.content((6.0, -0.7), [sink excess 5, conservation restored], size: 6pt)
})

The 5 with the stranded units walked home is the seven-suite pin, and
the listings below discharge the same fixtures in seven languages.

#listing("dsa/samples-c/src/Ch38/pushrelabel.c", first: 46, last: 96, caption: [c, saturate the source, the fifo discharge loop, relabel to 1 + the min neighbor height])
#listing("dsa/samples-go/ch38/pushrelabel.go", first: 22, last: 70, caption: [go, saturate, discharge, relabel, the dense capacity matrix folding parallel arcs])
#listing("dsa/samples-java/src/Ch38/Pushrelabel.java", first: 44, last: 96, caption: [java, saturate the source, the fifo discharge loop, relabel to 1 + the min neighbor height])
#listing("dsa/samples/src/Ch38/Flow2.cs", first: 143, last: 172, caption: [c\#, the same discharge loop, the relabel as a linq minimum])
#listing("dsa/samples-js/src/ch38-pushrelabel.mjs", first: 17, last: 54, caption: [javascript, the same machine, heights integer, excess exact on number])
#listing("dsa/samples-py/src/Ch38/pushrelabel.py", first: 17, last: 57, caption: [python, the whole solver, restart-proof guard at s = t])
#listing("dsa/samples-lua/ch38_pushrelabel.lua", first: 26, last: 68, caption: [lua, discharge and relabel, still-stuck vertices requeue])

The O(V^3) bound comes from the height labels: each relabel lifts a
vertex, heights stay bounded, and the total lifting is finite. The
improved variant with the gap heuristic is named in the literature and
stays prose here, the fixture scale never opens a gap. Capacities ride
a dense matrix, so parallel arcs fold into one cell, which is flow-safe
and keeps the fixture graphs tiny.

Every fixture asserts equality with the dinic value on the same graph:
the pinch network 13, the parallel network 5, the 2017 problem J
network 10. The edge family closes it: s equals t returns 0, a vertex
with no entering arc simply never fills, an unreachable sink drains 0,
and a single arc of capacity 7 pushes all 7 through.

#diagram([one relabel step, the vertex with excess stuck at height 2 among neighbors at 2, lifted to 3 with the push arrow], length: 13pt, {
  // u holds excess, neighbors v and w at height 2
  let n = (x, y, k, hot) => {
    cdraw.circle((x, y), radius: 0.34, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  cdraw.line((3.0, 6.4), (1.4, 4.9), stroke: luma(170))
  cdraw.line((3.0, 6.4), (4.6, 4.9), stroke: luma(170))
  cdraw.line((3.0, 6.4), (3.0, 4.2), stroke: luma(170))
  n(1.4, 4.6, [h 2], false)
  n(4.6, 4.6, [h 2], false)
  n(3.0, 3.9, [h 2], false)
  n(3.0, 6.4, [h 2], true)
  cdraw.content((3.0, 7.1), [u, excess 5, stuck], size: 6.5pt)
  cdraw.content((1.4, 4.0), [v], size: 6pt)
  cdraw.content((4.6, 4.0), [w], size: 6pt)
  cdraw.content((3.0, 3.1), [x], size: 6pt)
  // arrow: lift to 3
  cdraw.line((3.6, 6.9), (4.6, 7.6), stroke: luma(100), mark: (end: ">"))
  n(5.0, 7.9, [h 3], true)
  cdraw.content((5.0, 8.6), [relabel: 1 + min(2, 2, 2)], size: 6pt)
  // the push down to v
  cdraw.line((4.66, 7.6), (1.7, 5.1), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.3, 5.2), [push min(excess, cap)], size: 6pt)
  cdraw.content((10.6, 7.9), [admissible: drop of exactly 1], size: 6pt)
  cdraw.content((10.6, 6.8), [stuck: lift past the neighborhood], size: 6pt)
  cdraw.content((10.6, 5.7), [excess at the sink is the flow], size: 6pt)
  cdraw.content((10.6, 4.6), [o(v^3), fifo discharge], size: 6pt)
  cdraw.content((10.6, 3.5), [same answers as dinic, pinned], size: 6pt)
})

The application is general technique, the second max-flow engine in
the toolbox, and the choice when the level graph fights back.

== minimum-cost maximum flow

Augment the cheapest path first and the maximum flow arrives at
minimum cost. Each round finds a shortest path by cost over the
residual graph, pushes the bottleneck along the parent-arc chain, and
accumulates flow times path cost. The shortest-path engine is spfa,
bellman-ford with a queue: negative arcs are fine, which matters
because every residual arc negates the cost of its forward twin. On
these fixtures the residuals never close a negative cycle, the
condition spfa needs to terminate. The potentials form, johnson
distances reused round to round so dijkstra replaces spfa, is the
production upgrade and stays prose.

The dry run: the fixture is the layered network, arcs (0,1,3,1),
(0,2,2,1), (1,3,3,1), (2,3,2,2), (3,4,4,1), (1,4,1,4), pinned at
(5, 19) by all seven suites.

+ Round 1 prices the route 0, 1, 3, 4 at 1 + 1 + 1 = 3, the
  bottleneck min(3, 3, 4) = 3 fills 0 to 1 and 1 to 3 exactly, and
  the round books 3 × 3 = 9.
+ Round 2 rides 0, 2, 3, 4 at 1 + 2 + 1 = 4, where the 3 to 4 arc is
  down to 4 - 3 = 1, so the push caps at 1 and the books read
  9 + 4 = 13.
+ Round 3 finds 3 to 4 spent and takes the residual 3 to 1 at cost
  0 - 1 = -1: the route 0, 2, 3, 1, 4 totals 1 + 2 - 1 + 4 = 6,
  pushes 1, and 13 + 6 = 19.
+ Round 4 sees both source arcs at 0, spfa prices the sink at
  infinity, and the run closes at (5, 19), the fifth unit forced
  through the cost-4 arc.
+ Drop the 1 to 4 arc and only rounds 1 and 2 exist: (4, 13). The
  negative family books 2 × (-3 + 1) = -4 then 2 × 5 = 10 for
  (4, 6), and the 2018 problem C tree pushes 2, 1, 1 along routes of
  3, 4, and 4: 6 + 4 + 4 = 14.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*round*], [*route*], [*bottleneck*], [*route cost*], [*cost so far*]),
  [1], [0-1-3-4], [3], [3], [9],
  [2], [0-2-3-4], [1], [4], [13],
  [3], [0-2-3-1-4], [1], [6], [19],
)

The (5, 19) with its forced expensive unit is the seven-suite pin, and
the listings below run these rounds in seven languages.

#listing("dsa/samples-c/src/Ch38/mcmf.c", first: 53, last: 98, caption: [c, the spfa loop and the augmentation walk, flow times path cost accumulated])
#listing("dsa/samples-go/ch38/mcmf.go", first: 35, last: 84, caption: [go, spfa over the residual, the two walks that push and account])
#listing("dsa/samples-java/src/Ch38/Mcmf.java", first: 53, last: 96, caption: [java, the spfa loop and the augmentation walk, flow times path cost accumulated])
#listing("dsa/samples/src/Ch38/Costs2.cs", first: 34, last: 82, caption: [c\#, the same rounds, the bottleneck pushed along the parent-arc chain])
#listing("dsa/samples-js/src/ch38-mcmf.mjs", first: 25, last: 59, caption: [javascript, the round loop, costs exact on number below 2^53])
#listing("dsa/samples-py/src/Ch38/mcmf.py", first: 31, last: 65, caption: [python, spfa rounds, the residual riding the negative cost back])
#listing("dsa/samples-lua/ch38_mcmf.lua", first: 24, last: 68, caption: [lua, the same rounds in 1-based tables])

The fixtures pin (flow, cost) pairs. The layered network with arcs
(0,1,3,1), (0,2,2,1), (1,3,3,1), (2,3,2,2), (3,4,4,1), (1,4,1,4)
gives (5, 19): the 3 to 4 arc of capacity 4 bottlenecks the cheap
paths, so the expensive 1 to 4 arc of cost 4 is forced for the last
unit. Drop that arc and the answer is (4, 13). The 2018 problem C mini
tree, both-way tree arcs of costs 1, 2, 3, 4 by the spec's shape, a
super source feeding node 1 with 4 and node 4 with 1, and nodes 2, 3,
5 draining 2, 1, 1, lands (4, 14), the sample answer printed in the
problem statement. A negative arc, (0,1,2,-3), (1,2,2,1), (0,2,2,5),
rides to (4, 6) through spfa. The unreachable sink returns (0, 0), and
a demand exceeding supply is detected by flow falling short, the case
the demands transform below handles honestly.

#diagram([the layered cost network with the bottleneck arc shaded and the forced expensive 1 to 4 arc dashed], length: 13pt, {
  let pos = ("0": (1.2, 5.2), "1": (4.6, 7.6), "2": (4.6, 3.2), "3": (8.4, 4.8), "4": (12.0, 5.4))
  let arc = (u, v, label, style) => {
    let (x1, y1) = pos.at(str(u))
    let (x2, y2) = pos.at(str(v))
    cdraw.line((x1, y1), (x2, y2), stroke: style)
    cdraw.content(((x1 + x2) / 2, (y1 + y2) / 2 + 0.32), label, size: 6pt)
  }
  arc(0, 1, [cap 3, cost 1], luma(170))
  arc(0, 2, [cap 2, cost 1], luma(170))
  arc(1, 3, [cap 3, cost 1], luma(170))
  arc(2, 3, [cap 2, cost 2], luma(170))
  arc(3, 4, [cap 4, cost 1], luma(60))
  arc(1, 4, [cap 1, cost 4], (paint: luma(100), dash: "dashed"))
  for (v, (x, y)) in pos {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), [#v], size: 7pt)
  }
  cdraw.content((1.2, 6.0), [s], size: 6pt)
  cdraw.content((12.0, 6.0), [t], size: 6pt)
  cdraw.content((8.4, 3.6), [the 3-4 arc saturates at 4], size: 6pt)
  cdraw.content((8.4, 2.7), [unit 5 must cross 1-4 at cost 4], size: 6pt)
  cdraw.content((8.4, 1.8), [(5, 19): 4 cheap units + 1 forced], size: 6pt)
  cdraw.content((16.8, 6.6), [cheapest path first, always], size: 6pt)
  cdraw.content((16.8, 5.5), [spfa: negative arcs welcome], size: 6pt)
  cdraw.content((16.8, 4.4), [residuals negate the twin cost], size: 6pt)
  cdraw.content((16.8, 3.3), [potentials are the prose upgrade], size: 6pt)
  cdraw.content((16.8, 2.2), [o(f v e) per spfa round], size: 6pt)
})

The application is icpc world finals 2018 problem C (book 10, chapter
9), conquer the world, a min-cost flow on a tree whose finals solution
runs a convex dp with heaps. This section pins the direct flow
formulation the dp replaces.

== flows with demands

Lower bounds break the plain residual graph because zero flow on an
arc is no longer legal. The transform fixes it in one pass: an arc
with bounds \[l, u\] becomes an arc of capacity u - l, and the bound
l itself moves into a per-vertex ledger, d(v) as inflow lower bounds
minus outflow lower bounds. A vertex with positive d received promises
it must honor, so a super source feeds it exactly d. A vertex with
negative d promised outflow it cannot guarantee, so it drains to a
super sink. A free return arc from t to s at infinity closes the
circulation, and the whole system is feasible exactly when every
super-source arc saturates, one dinic run on the transformed graph.
Recovery reads each arc's true flow off its backward twin plus l.

The dry run: the fixture is the three-arc chain with bounds
\[1,2\], \[1,3\], \[2,2\] from source 0 to sink 3, feasible with every
arc forced to 2, asserted by all seven suites.

+ The lower bounds strip out of the capacities first: 2 - 1 = 1,
  3 - 1 = 2, 2 - 2 = 0, the last arc now fixed at its floor.
+ The ledger d(v) = inflow bounds minus outflow bounds reads
  d(0) = 0 - 1 = -1, d(1) = 1 - 1 = 0, d(2) = 1 - 2 = -1,
  d(3) = 2 - 0 = +2.
+ The super source feeds vertex 3 exactly 2, vertices 0 and 2 drain 1
  each to the super sink, and the free return 3 to 0 closes the
  circulation.
+ The two units route S, 3, 0, T and S, 3, 0, 1, 2, T: need 2, got 2,
  every super-source arc saturated, feasible.
+ Recovery reads the backward twins at 1, 1, and 0 and adds the
  floors back: 1 + 1 = 2, 1 + 1 = 2, 2 + 0 = 2, the forced flow.
+ Tighten the first arc to \[2,2\] against a \[1,1\] middle: every
  transformed capacity drops to 0, the return arc delivers 1 against
  a need of 1 + 1 = 2, and the super source refuses to saturate.

#diagram([the chain after the transform, the super source feeding 2, both units crossing the return arc, recovery adding the floors back], length: 13pt, {
  // chain 0-1-2-3, S under 3, T under 0, the return arc over the top
  let pos = ("0": (2.0, 5.8), "1": (4.9, 5.8), "2": (7.8, 5.8), "3": (10.7, 5.8))
  let hot = (a, b) => cdraw.line(pos.at(a), pos.at(b), stroke: luma(60), mark: (end: ">"))
  hot("0", "1")
  cdraw.content((3.45, 6.15), [1 of 1], size: 6pt)
  hot("1", "2")
  cdraw.content((6.35, 6.15), [1 of 2], size: 6pt)
  cdraw.line(pos.at("2"), pos.at("3"), stroke: luma(200), mark: (end: ">"))
  cdraw.content((9.25, 6.15), [0 of 0], size: 6pt)
  cdraw.line((10.7, 3.15), (10.7, 5.45), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.65, 4.3), [2 of 2], size: 6pt)
  cdraw.line((2.0, 5.45), (2.0, 3.15), stroke: luma(60), mark: (end: ">"))
  cdraw.line((7.8, 5.45), (2.5, 3.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.3, 4.75), [1 of 1], size: 6pt)
  cdraw.line((10.7, 6.15), (10.7, 7.3), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((10.7, 7.3), (2.0, 7.3), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((2.0, 7.3), (2.0, 6.15), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((6.35, 7.7), [return t to s at INF, carries 2], size: 6pt)
  for (k, (x, y)) in pos {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), [#k], size: 7pt)
  }
  cdraw.circle((10.7, 2.8), radius: 0.3, fill: luma(225), stroke: luma(120))
  cdraw.content((10.7, 2.8), [S], size: 7pt)
  cdraw.circle((2.0, 2.8), radius: 0.3, fill: luma(225), stroke: luma(120))
  cdraw.content((2.0, 2.8), [T], size: 7pt)
  cdraw.content((6.35, 1.6), [recovery: 1 + 1, 1 + 1, 2 + 0, every arc at 2], size: 6pt)
  cdraw.content((6.35, 0.8), [need 2 = got 2: feasible], size: 6pt)
  cdraw.content((6.35, 0.0), [tightened chain: need 2, got 1, refused], size: 6pt)
})

The forced 2 on every arc is the seven-suite pin, and the listings
below run this transform in seven languages.

#listing("dsa/samples-c/src/Ch38/demands.c", first: 100, last: 137, caption: [c, the transform, the deficit ledger, the feasibility check and flow recovery])
#listing("dsa/samples-go/ch38/demands.go", first: 30, last: 68, caption: [go, excess bookkeeping, the arc transplant into dinic, recovery by the residual])
#listing("dsa/samples-java/src/Ch38/Demands.java", first: 101, last: 136, caption: [java, the transform, the deficit ledger, the feasibility check and flow recovery])
#listing("dsa/samples/src/Ch38/Costs2.cs", first: 92, last: 123, caption: [c\#, the same transform over the chapter's dinic, lower bounds added back at the end])
#listing("dsa/samples-js/src/ch38-demands.mjs", first: 13, last: 50, caption: [javascript, the whole transform, dinic adopted over prebuilt arc arrays])
#listing("dsa/samples-py/src/Ch38/demands.py", first: 74, last: 99, caption: [python, the ledger, the super arcs, the saturation test])
#listing("dsa/samples-lua/ch38_demands.lua", first: 78, last: 108, caption: [lua, the same transform, flows read off the paired arcs])

The chain s = 0 to t = 3 with arcs (0,1,\[1,2\]), (1,2,\[1,3\]),
(2,3,\[2,2\]) is feasible and forced: every arc carries 2. Tighten the
first arc to (0,1,\[2,2\]) against (1,2,\[1,1\]) and the middle chain
cannot carry 2, infeasible, the super source refuses to saturate. A
circulation over a 3-cycle with every arc \[1,2\] is feasible with the
per-arc flows only asserted to lie inside the bounds and conserve,
the split between 1 and 2 is genuinely not unique.

#diagram([one arc split into its mandatory l block and free u minus l block, the super source and sink feeding the deficits], length: 13pt, {
  // the arc u -> v split into blocks
  cdraw.circle((1.6, 6.6), radius: 0.3, fill: luma(240), stroke: luma(120))
  cdraw.content((1.6, 6.6), [u], size: 7pt)
  cdraw.circle((9.6, 6.6), radius: 0.3, fill: luma(240), stroke: luma(120))
  cdraw.content((9.6, 6.6), [v], size: 7pt)
  cdraw.rect((3.2, 6.3), (5.6, 6.9), fill: luma(205), radius: 0.02)
  cdraw.content((4.4, 6.6), [l, mandatory], size: 6pt)
  cdraw.rect((5.7, 6.3), (8.0, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((6.85, 6.6), [u - l, free], size: 6pt)
  cdraw.line((1.9, 6.6), (3.2, 6.6), stroke: luma(170))
  cdraw.line((8.0, 6.6), (9.3, 6.6), stroke: luma(170))
  // the ledger: super source feeds surplus, deficits drain
  cdraw.circle((1.6, 3.4), radius: 0.3, fill: luma(225), stroke: luma(120))
  cdraw.content((1.6, 3.4), [S], size: 7pt)
  cdraw.circle((9.6, 3.4), radius: 0.3, fill: luma(225), stroke: luma(120))
  cdraw.content((9.6, 3.4), [T], size: 7pt)
  cdraw.line((1.9, 3.6), (5.0, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.9, 4.7), [d(v) > 0: feed d], size: 6pt)
  cdraw.line((6.4, 6.3), (9.3, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.3, 4.7), [d(u) < 0: drain], size: 6pt)
  cdraw.line((10.6, 6.6), (12.6, 6.6), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((13.9, 6.6), [t -> s at infinity], size: 6pt)
  cdraw.content((5.6, 1.9), [feasible iff every S arc saturates], size: 6pt)
  cdraw.content((5.6, 1.0), [flow on the arc = l + residual twin], size: 6pt)
  cdraw.content((5.6, 0.1), [one max flow decides it], size: 6pt)
})

The application is general technique, the standard bridge from a
constraint with a floor on it to a plain max flow.

== global minimum cut, stoer-wagner

The min cut of chapter 12 asks for the best split naming two
terminals. The global cut asks for the best split of any shape. The
stoer-wagner answer runs n - 1 phases on the shrinking graph: build a
maximum adjacency ordering, repeatedly move the vertex most tightly
connected to the already-moved set, and the cut of the phase is the
total weight incident to the last vertex of that order. Then merge the
last two vertices of the order into one, folding their weights, and
repeat. Some phase cut is the global minimum. The bookkeeping that
makes the answer readable is the merged group: each live vertex knows
which original vertices it absorbed, so the winning phase reports the
side that contains vertex 0, complemented when the phase cut named the
other side.

The dry run: the fixture is the two weight-10 triangles joined by
weight-2 bridges, cut 4 on the side {0,1,2}, asserted by all seven
suites.

+ Phase 1 pulls triangle members after triangle members, the ordering
  runs 0, 1, 2, 3, 4, 5, and the cut at the last vertex 5 is
  10 + 10 = 20. The merge folds 5 into 4, so the 3 to 5 rim reads
  10 + 10 = 20 into the merged cell.
+ Phase 2 orders 0, 1, 2, 3, 4 and cuts at 0 + 2 + 0 + 20 = 22, then
  folds 4 into 3: the group {3,4,5} is now one live vertex.
+ Phase 3 orders 0, 1, 2, 3, and the last vertex is the merged
  triangle: its crossing weight is exactly the two bridges,
  2 + 2 = 4, the new best.
+ Phases 4 and 5 cut 10 + 12 = 22 and 20 against the folded groups,
  so the best stays 4.
+ The winning side is the group {3,4,5}, which misses vertex 0, so
  the report complements it to {0,1,2}, and the cycle-with-diagonals
  and single-edge fixtures pin their 7s the same way.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*phase*], [*ordering*], [*cut at the last*], [*best so far*]),
  [1], [0, 1, 2, 3, 4, 5], [20], [20],
  [2], [0, 1, 2, 3, 4], [22], [20],
  [3], [0, 1, 2, 3], [4], [4],
  [4], [0, 1, 2], [22], [4],
  [5], [0, 1], [20], [4],
)

The 4 on {0,1,2} is the seven-suite pin, and the listings below run
these phases in seven languages.

#listing("dsa/samples-c/src/Ch38/stoerwagner.c", first: 43, last: 90, caption: [c, the maximum adjacency ordering, the phase cut, the merge of the last two])
#listing("dsa/samples-go/ch38/stoerwagner.go", first: 28, last: 79, caption: [go, the ascending scan keeps the order deterministic, the merge folds weights])
#listing("dsa/samples-java/src/Ch38/Stoerwagner.java", first: 46, last: 89, caption: [java, the maximum adjacency ordering, the phase cut, the merge of the last two])
#listing("dsa/samples/src/Ch38/Cuts.cs", first: 22, last: 63, caption: [c\#, the same phase loop, linq summing the incident weight])
#listing("dsa/samples-js/src/ch38-stoerwagner.mjs", first: 21, last: 62, caption: [javascript, the ordering, the cut, the merge, sets for the frontier])
#listing("dsa/samples-py/src/Ch38/stoerwagner.py", first: 27, last: 51, caption: [python, the whole phase loop in 25 lines])
#listing("dsa/samples-lua/ch38_stoerwagner.lua", first: 29, last: 80, caption: [lua, the same phases over the dense matrix])

The dense form is O(n^3) per the matrix scan, the heap form
O(V E + V^2 log V), and fixture graphs stay at n of at most 6. Four
vertices with a cycle of weight 3 plus diagonals of weight 1 cut at 7
on the side {0,1,2}. Two triangles of weight 10 joined by two bridges
of weight 2 cut at 4, again {0,1,2}: the bridges are the weak seam,
and no s-t machinery would have known to look there. Two vertices with
one weight-7 edge cut at 7 on {0}.

#diagram([two weight-10 triangles joined by weight-2 bridges, one merge folding a triangle, the phase cut, then the true 4-cut], length: 13pt, {
  // left: the original graph, triangles {0,1,2} and {3,4,5}, bridges 1-4 and 2-3
  let v = ((1.6, 6.0, [0]), (0.7, 4.6, [1]), (2.5, 4.6, [2]), (5.7, 5.2, [3]), (7.5, 6.3, [4]), (6.9, 3.9, [5]))
  let at = (i) => (v.at(i).at(0), v.at(i).at(1))
  for (a, b) in ((0, 1), (0, 2), (1, 2), (3, 4), (3, 5), (4, 5)) {
    cdraw.line(at(a), at(b), stroke: luma(170))
  }
  cdraw.line(at(1), at(4), stroke: luma(100))
  cdraw.line(at(2), at(3), stroke: luma(100))
  cdraw.content((4.0, 5.75), [2], size: 6pt)
  cdraw.content((4.0, 4.85), [2], size: 6pt)
  for (x, y, k) in v {
    cdraw.circle((x, y), radius: 0.28, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  // the true cut between the triangles
  cdraw.line((4.1, 3.4), (4.1, 6.8), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((4.1, 7.3), [cut {0,1,2} against {3,4,5}: 4], size: 6pt)
  cdraw.content((4.1, 2.6), [rim edges weight 10, both bridges weight 2], size: 6pt)
  // right: the merge view
  cdraw.circle((13.4, 7.4), radius: 0.28, fill: luma(240), stroke: luma(120))
  cdraw.content((13.4, 7.4), [0], size: 7pt)
  cdraw.circle((12.3, 5.9), radius: 0.44, fill: luma(225), stroke: luma(120))
  cdraw.content((12.3, 5.9), [1+2], size: 6.5pt)
  cdraw.line((13.2, 7.2), (12.5, 6.3), stroke: luma(170))
  cdraw.line((11.9, 5.9), (11.2, 5.3), stroke: luma(100))
  cdraw.content((10.9, 5.0), [the merged group remembers its members], size: 6pt)
  cdraw.content((11.4, 4.0), [the winning phase reports the side], size: 6pt)
  cdraw.content((11.4, 3.1), [holding vertex 0, complemented if not], size: 6pt)
  cdraw.content((11.4, 2.2), [n - 1 phases, o(n^3) dense], size: 6pt)
})

The application is general technique, the cut tool when no terminal
pair is given, undirected and weighted.

== kuhn's bipartite matching

Walk the left vertices in index order and let each one try its
neighbors in index order. A free neighbor is taken at once. An owned
neighbor triggers the recursive question, can the current owner move
somewhere else, and the reassignment ripples down an alternating path
until some left vertex settles into a free slot or the attempt fails.
Visited stamps reset per left vertex so a right vertex is contested at
most once per attempt. The rule is deterministic, first-free-or-
reassign in index order, so the matching itself pins wherever it is
unique.

The dry run: the fixture is the 2017 problem C crate layer, rows
{0,1} against columns {0,2}, the one place the suites pin the owner
array itself, and all seven agree on (1, -1, 0) at size 2.

+ Row 0 opens on column 0, finds it free, and takes it: one match.
+ Row 1 opens on column 0 too: owned, so the current owner is asked
  whether it can move, the recursive question at the heart of the
  method.
+ Row 0's scan steps past the visited column 0 and finds column 2
  free: row 0 relocates, row 1 settles at column 0.
+ The owner array reads (1, -1, 0) with column 1 idle, and the
  height-1 layer with its empty row side matches 0.
+ The 2025 problem B bank at n = 8 walks left 1, 4, 6 in index order,
  the alternating path reaching two owners deep, and closes at size
  3: erasing 2 or 8 holds the 3, erasing 4 or 6 drops it to 2, so the
  first move is 2.
+ The denial shape matches 3 of 4 with card 3 forbidden and 4 once the
  fourth player may take it, the empty right side pins 0, the complete
  3 × 3 pins 3.

#diagram([the crate layer before and after row 1 arrives, the ask rippling row 0 over to column 2, column 1 idle throughout], length: 13pt, {
  // rows left, columns right, complete over {0, 2}, col 1 unedged
  let panel = (x0, title, settled, ask) => {
    let r = ("0": (x0 + 0.8, 7.0), "1": (x0 + 0.8, 4.8))
    let c = ("0": (x0 + 6.6, 7.6), "1": (x0 + 6.6, 6.0), "2": (x0 + 6.6, 4.4))
    for (a, b) in (("0", "0"), ("0", "2"), ("1", "0"), ("1", "2")) {
      cdraw.line(r.at(a), c.at(b), stroke: if (a, b) in settled { luma(60) } else { luma(235) })
    }
    for (k, (x, y)) in r {
      cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
      cdraw.content((x, y), [#k], size: 7pt)
    }
    for (k, (x, y)) in c {
      cdraw.circle((x, y), radius: 0.3, fill: if k == "1" { luma(248) } else { luma(240) }, stroke: if k == "1" { luma(160) } else { luma(120) })
      cdraw.content((x, y), [#k], size: 7pt)
    }
    cdraw.content((x0 + 0.8, 3.9), [rows], size: 6pt)
    cdraw.content((x0 + 6.6, 3.6), [columns], size: 6pt)
    cdraw.content((x0 + 3.7, 8.6), title, size: 6pt)
    if ask {
      cdraw.content((x0 + 5.6, 6.0), [idle], size: 6pt)
    }
  }
  panel(0.6, [row 0 takes column 0], (("0", "0"),), false)
  panel(11.4, [row 1 asks, row 0 slides to column 2], (("0", "2"), ("1", "0")), true)
  // the relocation beside the right panel's column bank
  cdraw.line((19.2, 7.6), (19.2, 4.4), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((21.0, 6.0), [slides], size: 6pt)
  cdraw.content((9.6, 2.4), [owner (1, -1, 0): column 0 held by row 1, column 2 by row 0], size: 6pt)
  cdraw.content((9.6, 1.6), [column 1 contested by nobody, size 2], size: 6pt)
})

The owner array beside the size 2 is the seven-suite pin, and the
listings below ripple these asks in seven languages.

#listing("dsa/samples-c/src/Ch38/kuhn.c", first: 39, last: 61, caption: [c, the recursive try and the driver, the deterministic owner array])
#listing("dsa/samples-go/ch38/kuhn.go", first: 12, last: 37, caption: [go, kuhn full, the right-side owner array returned for pinning])
#listing("dsa/samples-java/src/Ch38/Kuhn.java", first: 40, last: 63, caption: [java, the recursive try and the driver, the deterministic owner array])
#listing("dsa/samples/src/Ch38/Match.cs", first: 10, last: 34, caption: [c\#, the local try function, first-free-or-reassign])
#listing("dsa/samples-js/src/ch38-kuhn.mjs", first: 7, last: 25, caption: [javascript, the whole matcher, size and match r out])
#listing("dsa/samples-py/src/Ch38/kuhn.py", first: 14, last: 30, caption: [python, the try recursion and the driver])
#listing("dsa/samples-lua/ch38_kuhn.lua", first: 8, last: 30, caption: [lua, the same recursion over 1-based tables])

The bound is O(V E), one depth-first try per left vertex over the
whole edge list, and hopcroft-karp's O(sqrt(V) E) is the named upgrade
that stays prose. Matching is unit max flow, and the seeded family of
the dinic section above runs both engines on the same graph to the
same 18.

The fixtures are three contest shapes. The 2017 problem C crate layer,
rows {0,1} against columns {0,2} as a complete bipartite graph,
matches 2, and the deterministic rule pins the owner array (1, -1, 0):
row 0 takes column 0 first, row 1 reassigns to column 2. The height-1
layer with an empty row side matches 0. The 2022 problem X denial
shape, 4 slots against cards {0,1,2,3} with card 3 forbidden to every
player, matches 3, and 3 under 4 flags the infeasibility, while
opening card 3 to the fourth player completes the matching at 4. The
2025 problem B prime-multiple graph splits the numbers 1 through n by
omega parity, the count of prime factors with multiplicity, even bank
against odd bank, edges where one divides the other. At n = 6 the
matching is 3 and deleting any even vertex drops it to 2, so every
opening loses, second wins. At n = 8 the matching is 3, deleting 2 or
8 keeps 3 while deleting 4 or 6 drops to 2, so the first player opens
by erasing 2. The edges close with an empty right side at 0 and a
complete 3 by 3 at 3.

#diagram([the n = 8 prime-multiple graph, the matching 1-7, 4-8, 3-6 bold, vertex 2 unmatched as the winning opening], length: 13pt, {
  // left bank [1, 4, 6], right bank [2, 3, 5, 7, 8]
  let lpos = ("1": (3.4, 7.9), "4": (3.4, 6.3), "6": (3.4, 4.7))
  let rpos = ("2": (9.8, 8.3), "3": (9.8, 6.9), "5": (9.8, 5.5), "7": (9.8, 4.1), "8": (9.8, 2.7))
  let lx = (v) => lpos.at(str(v)).at(0)
  let ly = (v) => lpos.at(str(v)).at(1)
  let rx = (v) => rpos.at(str(v)).at(0)
  let ry = (v) => rpos.at(str(v)).at(1)
  let edges = ((1, 2), (1, 3), (1, 5), (1, 7), (1, 8), (4, 2), (4, 8), (6, 2), (6, 3))
  for (a, b) in edges {
    let hot = (a, b) in ((1, 7), (4, 8), (6, 3))
    cdraw.line((lx(a), ly(a)), (rx(b), ry(b)), stroke: if hot { luma(60) } else { luma(200) })
  }
  for v in (1, 4, 6) {
    cdraw.circle((lx(v), ly(v)), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((lx(v), ly(v)), [#v], size: 7pt)
  }
  for v in (2, 3, 5, 7, 8) {
    let hot = v in (7, 8, 3)
    cdraw.circle((rx(v), ry(v)), radius: 0.3, fill: if hot { luma(215) } else { luma(240) }, stroke: luma(120))
    cdraw.content((rx(v), ry(v)), [#v], size: 7pt)
  }
  cdraw.content((1.6, 8.6), [even omega], size: 6pt)
  cdraw.content((1.6, 8.1), [1, 4, 6], size: 6pt)
  cdraw.content((11.6, 8.6), [odd omega], size: 6pt)
  cdraw.content((11.6, 8.1), [2, 3, 5, 7, 8], size: 6pt)
  cdraw.content((6.6, 2.2), [matching size 3: 1-7, 4-8, 6-3], size: 6pt)
  cdraw.content((6.6, 1.3), [delete 2 or 8: still 3, first wins with 2], size: 6pt)
  cdraw.content((6.6, 0.4), [delete 4 or 6: drops to 2], size: 6pt)
})

The applications are icpc world finals 2017 problem C (book 10,
chapter 8), mission improbable, one matching per distinct crate height
with m + n minus match piles left standing, icpc world finals 2022
problem X (book 10, chapter 11), quartets, re-testing the 32-slot
matching after every action and reporting the first failure, and icpc
world finals 2025 problem B (book 10, chapter 13), blackboard game,
whose openings are decided by whether some maximum matching avoids the
erased vertex.

== the hungarian algorithm

The assignment problem asks for the cheapest perfect matching on a
square cost matrix, and the hungarian method solves it in O(n^3) with
potentials. Each row carries a potential u and each column a potential
v, and a cell (i, j) is tight when u of i plus v of j equals the cost
there. One row at a time, an alternating tree grows over the tight
cells: the slack of a column is how far its cost sits above the
potentials, the tree extends through the smallest-slack column, and
when every reachable column has been visited the potentials adjust by
the common delta, tightening at least one more cell without loosening
any visited one. The tree reaches a free column, the augmenting path
commits along the parent links, and the matching grows by one.

The dry run: the fixture is the 3 × 3 matrix 4, 1, 3 over 2, 0, 5
over 3, 2, 2, cost 5 on the unique assignment (1, 0, 2), asserted by
all seven suites.

+ Row 0 grows over slacks 4, 1, 3: the smallest sits at column 1, the
  delta is 1, and the free column commits at once.
+ Row 1 finds column 1 tight at slack 0 but owned, so the tree
  extends through row 0's cells: the remaining slacks run 2 and 2,
  the common delta is 2, and after u(0) += 2 and u(1) += 2 against
  v(1) -= 2 column 0 comes tight and free, the commit lands there.
+ Row 2 prices its cells at 3, 4, 2 against the standing potentials:
  delta 2, column 2 free, the third commit closes the matching.
+ The potentials settle at u = 3, 2, 2 and v = 0, -2, 0, and their
  sum 3 + 2 + 2 + 0 - 2 + 0 = 5 equals the assignment cost
  1 + 2 + 2 = 5, the dual pair the method maintains.
+ The 4 × 4 answers 13 against the permutation brute, the 1 × 1 of 7
  answers 7, and the profit matrix maximizes at 21 by negating on the
  way in and the way out.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*entering row*], [*deltas paid*], [*commits*], [*cell cost*]),
  [0], [1], [column 1, free at once], [1],
  [1], [0, then 2], [column 0, freed by the shift], [2],
  [2], [2], [column 2, free at once], [2],
)

The cost 5 on the unique assignment (1, 0, 2) is the seven-suite pin,
and the listings below grow these trees in seven languages.

#listing("dsa/samples-c/src/Ch38/hungarian.c", first: 35, last: 73, caption: [c, one row's tree growth, the delta adjustment, the augmenting commit])
#listing("dsa/samples-go/ch38/hungarian.go", first: 14, last: 62, caption: [go, the shortest-slack column, the delta, the commit])
#listing("dsa/samples-java/src/Ch38/Hungarian.java", first: 36, last: 74, caption: [java, one row's tree growth, the delta adjustment, the augmenting commit])
#listing("dsa/samples/src/Ch38/Hungarian.cs", first: 18, last: 64, caption: [c\#, the same row loop, way links the parents, the commit walk])
#listing("dsa/samples-js/src/ch38-hungarian.mjs", first: 13, last: 52, caption: [javascript, the same row loop, values exact on number])
#listing("dsa/samples-py/src/Ch38/hungarian.py", first: 26, last: 59, caption: [python, the tree growth with the tightest column, the commit walk])
#listing("dsa/samples-lua/ch38_hungarian.lua", first: 19, last: 60, caption: [lua, the potentials loop in 1-based columns])

The solver minimizes, and maximization negates the matrix and negates
the answer. Big entries model forbidden pairs, the trick the next
section builds on. The 3 by 3 matrix 4, 1, 3 over 2, 0, 5 over 3, 2, 2
costs 5 on the unique assignment (1, 0, 2), row i takes column a of i,
cross-checked against the permutation brute. The 4 by 4 costs 13 with
the assignment asserted a valid permutation of exactly that cost. The
1 by 1 of 7 answers 7, and the profit matrix 3, 8, 4 over 9, 1, 6 over
7, 5, 2 maximizes at 21 by negation.

#diagram([the 3 by 3 cost grid with the three chosen cells shaded and one row of potential adjustments written beside it], length: 13pt, {
  let m = ((4, 1, 3), (2, 0, 5), (3, 2, 2))
  let pick = ((0, 1), (1, 0), (2, 2))
  for (r, row) in m.enumerate() {
    for (c, v) in row.enumerate() {
      let hot = (r, c) in pick
      cdraw.rect((1.6 + c * 1.5, 6.4 - r * 1.1), (3.1 + c * 1.5, 7.5 - r * 1.1), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((2.35 + c * 1.5, 6.95 - r * 1.1), [#v], size: 7pt)
    }
  }
  for r in range(3) {
    cdraw.content((1.0, 6.95 - r * 1.1), [#r], size: 6pt)
  }
  for c in range(3) {
    cdraw.content((2.35 + c * 1.5, 7.9), [#c], size: 6pt)
  }
  cdraw.content((2.85, 8.6), [cost 5 on cells (0,1), (1,0), (2,2)], size: 6pt)
  // the potential row for row 1's growth
  cdraw.content((9.6, 7.6), [row 1 enters: slacks 2, 0, 5], size: 6pt)
  cdraw.content((9.6, 6.7), [tree takes column 1 at slack 0], size: 6pt)
  cdraw.content((9.6, 5.8), [next slacks 2, -, 5, delta 2], size: 6pt)
  cdraw.content((9.6, 4.9), [u(1) += 2, v(1) -= 2], size: 6pt)
  cdraw.content((9.6, 4.0), [column 0 tightens, tree extends], size: 6pt)
  cdraw.content((9.6, 3.1), [free column found, path commits], size: 6pt)
  cdraw.content((9.6, 2.0), [o(n^3) over n rows], size: 6pt)
})

The application is general technique, the exact assignment engine
whenever the matrix is small and the costs are real.

== assignment problems

The modeling facet around the hungarian solver: how the messy
question becomes the square matrix. Forbidden pairs, worker w cannot
do task t, become an entry of 1e9, far past any real cost, so a
feasible assignment never touches one and a total at or past the same
threshold proves no feasible assignment exists. A rectangular n by m
problem with m above n pads zero-cost dummy columns up to the square,
and which real tasks get done falls out of the solve, the dummies
absorbing the idle rows. Maximization negates going in and coming
out.

The dry run: the fixtures are the forbidden matrix, 4, 1e9, 6 over
7, 3, 5 over 6, 5, 4 with worker 0 barred from task 1, and the 3 × 5
rectangle, the unique cost 11 and the 9 over real tasks {0, 1, 2},
asserted by all seven suites.

+ The 1e9 at cell (0, 1) never turns tight: it prices past every
  delta the tree ever pays, so the solver walks around it and the
  diagonal commits at 4 + 3 + 4 = 11.
+ The rectangle pads columns 5 and 6 at zero, a 3 × 7 square, and the
  solve picks (0, 1), (1, 0), (2, 2) at 4 + 3 + 2 = 9 with both
  dummies idle.
+ All three rows keep real tasks, the pinned read {0, 1, 2}, and in
  general it is the dummies that absorb whatever rows sit out.
+ The 1 × 1 pair pins its single cost, 7 in the C\# suite and 5 in C,
  and a full-forbidden row drives the total to the threshold itself:
  the same number that models the ban reports the infeasibility.

#diagram([the forbidden matrix with the big cell struck through, the walk around it shaded on the diagonal, the threshold read beside], length: 13pt, {
  let m = ((4, 10, 3), (7, 3, 5), (6, 5, 4))
  let pick = ((0, 0), (1, 1), (2, 2))
  for (r, row) in m.enumerate() {
    for (c, v) in row.enumerate() {
      let ban = r == 0 and c == 1
      cdraw.rect((1.6 + c * 1.7, 6.4 - r * 1.25), (3.3 + c * 1.7, 7.65 - r * 1.25), fill: if (r, c) in pick { luma(205) } else if ban { luma(248) } else { luma(235) }, stroke: if ban { luma(160) } else { none }, radius: 0.02)
      cdraw.content((2.45 + c * 1.7, 7.02 - r * 1.25), if ban [1e9] else [#v], size: 7pt)
    }
  }
  // the strike through the forbidden cell
  cdraw.line((3.35, 7.6), (4.9, 6.45), stroke: luma(100))
  cdraw.line((3.35, 6.45), (4.9, 7.6), stroke: luma(100))
  for r in range(3) {
    cdraw.content((1.0, 7.02 - r * 1.25), [#r], size: 6pt)
  }
  for c in range(3) {
    cdraw.content((2.45 + c * 1.7, 8.05), [#c], size: 6pt)
  }
  cdraw.content((4.0, 3.3), [worker 0 barred at cell (0, 1)], size: 6pt)
  cdraw.content((10.6, 7.3), [the 1e9 cell prices past every delta], size: 6pt)
  cdraw.content((10.6, 6.4), [around it: 4 + 3 + 4 = 11], size: 6pt)
  cdraw.content((10.6, 5.5), [unique assignment (0, 1, 2)], size: 6pt)
  cdraw.content((10.6, 4.6), [full-forbidden row: total at 1e9], size: 6pt)
  cdraw.content((10.6, 3.7), [rectangle: pad zeros, dummies idle], size: 6pt)
  cdraw.content((10.6, 2.8), [3 × 5 at 9, real tasks {0, 1, 2}], size: 6pt)
})

The 11 around the ban and the 9 over real tasks are the seven-suite
pins, and the listings below model these matrices in seven languages.

#listing("dsa/samples-c/src/Ch38/assign.c", first: 83, last: 92, caption: [c, the rectangle squared by zero padding, forbidden pairs enter as the 1e9 constant])
#listing("dsa/samples-go/ch38/assign.go", first: 3, last: 24, caption: [go, the forbidden constant, the square and rectangle wrappers])
#listing("dsa/samples-java/src/Ch38/Assign.java", first: 85, last: 92, caption: [java, the rectangle squared by zero padding, forbidden pairs enter as the 1e9 constant])
#listing("dsa/samples/src/Ch38/Hungarian.cs", first: 87, last: 105, caption: [c\#, the assign facet over the solver, dummy cells at zero])
#listing("dsa/samples-js/src/ch38-assign.mjs", first: 9, last: 19, caption: [javascript, the solver imported and called, padding inline])
#listing("dsa/samples-py/src/Ch38/assign.py", first: 68, last: 77, caption: [python, square up, solve, strip the padding from the report])
#listing("dsa/samples-lua/ch38_assign.lua", first: 79, last: 94, caption: [lua, the padded square in the fixture, dummy columns doing nothing])

Each language calls the solver of the previous section rather than
recoding it, in-file where the house form keeps samples standalone.
The forbidden fixture, 4, inf, 6 over 7, 3, 5 over 6, 5, 4 with worker
0 barred from task 1, costs 11 on the unique assignment (0, 1, 2). The
3 by 5 rectangle 6, 4, 5, 8, 7 over 3, 6, 4, 5, 6 over 8, 3, 2, 4, 5
pads two zero columns and costs 9, rows taking tasks (1, 0, 2), the
real tasks used exactly {0, 1, 2}. The 1 by 1 forced pair pins, and a
full-forbidden row reports a cost at the threshold, infeasibility by
the same number that models it.

#diagram([the 3 by 5 rectangle padded to a square, the two dummy columns shaded, the chosen cells marked], length: 13pt, {
  let m = ((6, 4, 5, 8, 7), (3, 6, 4, 5, 6), (8, 3, 2, 4, 5))
  let pick = ((0, 1), (1, 0), (2, 2))
  for (r, row) in m.enumerate() {
    for c in range(7) {
      let v = if c < 5 { row.at(c) } else { 0 }
      let hot = (r, c) in pick
      let dummy = c >= 5
      cdraw.rect((1.4 + c * 1.3, 5.6 - r * 1.05), (2.7 + c * 1.3, 6.65 - r * 1.05), fill: if hot { luma(205) } else if dummy { luma(248) } else { luma(235) }, stroke: if dummy { luma(190) } else { none }, radius: 0.02)
      cdraw.content((2.05 + c * 1.3, 6.12 - r * 1.05), [#v], size: 7pt)
    }
  }
  for r in range(3) {
    cdraw.content((0.8, 6.12 - r * 1.05), [#r], size: 6pt)
  }
  cdraw.content((2.05 + 2 * 1.3 + 0.65, 7.1), [real tasks 0..4], size: 6pt)
  cdraw.content((2.05 + 5 * 1.3 + 0.65, 7.1), [dummies], size: 6pt)
  cdraw.content((5.4, 1.7), [padded 3 x 7, solved, dummies dropped], size: 6pt)
  cdraw.content((5.4, 0.8), [cost 9 on cells (0,1), (1,0), (2,2)], size: 6pt)
  cdraw.content((5.4, -0.1), [forbidden pairs ride 1e9 entries], size: 6pt)
})

The application is general technique, and the same modeling carries
to any solver of the assignment shape.

== hall's theorem

A bipartite graph with left side L saturates L exactly when every
subset S of L has at least as many neighbors, |S| at most |N(S)|. The
theorem converts a matching question into a counting question, and
this section ships two checkers. The general one enumerates all 2^n
left subsets for n up to 20, unions the neighbor bitmasks, and fails
on the first subset that outgrows its neighborhood. The prefix
counting form is the useful special case for lower-bounded slot
families: each item i demands at least L of i slots among the first
ones, and the condition collapses to, for every prefix length q, at
least q items carry L at most q, checked by sorting the bounds and
scanning, with the first violated q reported.

The dry run: the fixtures are the four 2025 problem F bound families
plus the seeded agreement family, asserted by all seven suites, and the
walk runs the prefix form.

+ Sorted, the feasible family 2, 2, 1, 1 reads 1, 1, 2, 2: the
  prefix counts run 2, 4, 4, 4 against the needs 1, 2, 3, 4, every
  fence covered.
+ The family 3, 2, 3 fails at the first fence: sorted 2, 3, 3 counts
  0 items at or below q = 1, no variety tolerates a single slot.
+ The family 1, 2, 2 counts 1, 3, 3 against 1, 2, 3 and holds, while
  2, 2, 2 counts 0, 3, 3 and fails at q = 1 again.
+ The seeded agreement family draws five bipartite graphs where hall
  holds exactly when kuhn saturates all ten lefts: the pins read
  (fails, 9), (fails, 9), (holds, 10), (fails, 9), (fails, 8).
+ The degenerates: a lone left vertex with no neighbors has |S| = 1
  against |N(S)| = 0 and fails both checkers, and the empty left side
  holds with nothing to check.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*bounds*], [*m*], [*sorted*], [*counts at q = 1 to m*], [*verdict*]),
  [2, 2, 1, 1], [4], [1, 1, 2, 2], [2, 4, 4, 4], [holds],
  [3, 2, 3], [3], [2, 3, 3], [0, 1, 3], [fails at q = 1],
  [1, 2, 2], [3], [1, 2, 2], [1, 3, 3], [holds],
  [2, 2, 2], [3], [2, 2, 2], [0, 3, 3], [fails at q = 1],
)

The two holds and the two q = 1 failures are the seven-suite pins, and
the listings below sweep subsets and prefixes in seven languages.

#listing("dsa/samples-c/src/Ch38/hall.c", first: 64, last: 98, caption: [c, the bitmask sweep and the prefix scan, first violated q out])
#listing("dsa/samples-go/ch38/hall.go", first: 5, last: 48, caption: [go, the subset form, bitcount, the prefix form])
#listing("dsa/samples-java/src/Ch38/Hall.java", first: 64, last: 98, caption: [java, the bitmask sweep and the prefix scan, first violated q out, bitCount from the stdlib])
#listing("dsa/samples/src/Ch38/Match.cs", first: 43, last: 71, caption: [c\#, both checkers, popcount on the unioned neighbors])
#listing("dsa/samples-js/src/ch38-hall.mjs", first: 7, last: 38, caption: [javascript, popcount, the subset sweep, the prefix scan])
#listing("dsa/samples-py/src/Ch38/hall.py", first: 15, last: 34, caption: [python, the subset sweep, the prefix form with the kuhn partner below])
#listing("dsa/samples-lua/ch38_hall.lua", first: 9, last: 47, caption: [lua, both forms, hand-rolled bit counts])

The agreement family runs five seeded bipartite graphs beside the
kuhn matcher of the matching section above: hall holds exactly when
the kuhn size is the full left side, and the pins read (fails, 9),
(fails, 9), (holds, 10), (fails, 9), (fails, 8). The edge family: a
single left vertex with no neighbors fails hall and matches 0, and the
empty left side holds trivially.

The prefix form carries the 2025 problem F fixtures: lower bounds
2, 2, 1, 1 over m = 4 slots are feasible, 3, 2, 3 over m = 3 fails
first at q = 1, no variety tolerates a single slot, 1, 2, 2 over m = 3
holds, and 2, 2, 2 over m = 3 fails at q = 1 again.

#diagram([the pot row with the lower-bound brackets of the failing family, the violated q = 1 prefix shaded], length: 13pt, {
  // pots 1..3 with brackets L = 3, 2, 3
  for i in range(3) {
    let x = 2.2 + i * 2.4
    cdraw.rect((x, 4.6), (x + 1.5, 6.2), fill: luma(235), radius: 0.06)
    cdraw.line((x + 0.15, 4.6), (x + 0.15, 6.2), stroke: luma(190))
    cdraw.line((x + 0.75, 4.6), (x + 0.75, 6.2), stroke: luma(190))
    cdraw.line((x + 1.35, 4.6), (x + 1.35, 6.2), stroke: luma(190))
  }
  // bracket over pot 1 demanding 3 slots
  cdraw.line((2.2, 3.9), (2.2, 3.3), stroke: luma(100))
  cdraw.line((2.2, 3.3), (9.1, 3.3), stroke: luma(100))
  cdraw.line((9.1, 3.3), (9.1, 3.9), stroke: luma(100))
  cdraw.content((5.6, 2.9), [variety 1 needs L = 3 slots], size: 6pt)
  cdraw.line((4.6, 2.2), (4.6, 1.7), stroke: luma(100))
  cdraw.line((4.6, 1.7), (7.0, 1.7), stroke: luma(100))
  cdraw.line((7.0, 1.7), (7.0, 2.2), stroke: luma(100))
  cdraw.content((5.8, 1.3), [variety 2 needs L = 2], size: 6pt)
  // the violated prefix q = 1
  cdraw.rect((1.9, 4.3), (4.3, 6.5), fill: none, stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((3.1, 6.9), [q = 1], size: 6pt)
  cdraw.content((5.6, 0.4), [q = 1: no variety with L <= 1, fails], size: 6pt)
  cdraw.content((14.2, 6.2), [subset form: 2^n, n <= 20], size: 6pt)
  cdraw.content((14.2, 5.1), [prefix form: sort, one scan], size: 6pt)
  cdraw.content((14.2, 4.0), [holds iff kuhn saturates the left], size: 6pt)
  cdraw.content((14.2, 2.9), [the counting face of matching], size: 6pt)
})

The application is icpc world finals 2025 problem F (book 10, chapter
13), herding cats, where variety lower bounds L(z) and the prefix
sufficiency check are the whole solution. Hall has no dedicated
cp-algorithms article, and the sources below cite the kuhn article
where the theorem section lives.

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's nine sample files per language, c\# spread over its five
family files, go test files excluded:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [1118], [static arc arrays, paired residuals], [long long capacities, xor-1 twins, per-file mains printing ok N],
  [go], [563], [slices, no imports beyond fmt and sort], [shared helpers per package, the deterministic stoer-wagner scan documented],
  [java], [1156], [jdk 27 stdlib], [cap[e ^ 1] paired arcs port directly on int arc ids, the seeded lcg draws through Integer.remainderUnsigned, each file standalone like c],
  [c\#], [465], [lists, linq, tuples], [five family files, the demands solver reuses the chapter dinic through accessors],
  [javascript], [385], [classes with private fields], [number capacities with the below-2^53 note, es modules importing dinic for demands],
  [python], [763], [stdlib only, inline asserts], [float("inf") as the flow infinity, brute twins on hungarian and the bipartite family],
  [lua], [970], [tables, 1-based inside], [0-based public faces, integer division for the infinity sentinels, check tables for run.lua],
)

sources: cp-algorithms, "Maximum flow - Dinic's algorithm",
cp-algorithms.com/graph/dinic.html, "Maximum flow - Push-relabel
algorithm", cp-algorithms.com/graph/push-relabel.html, whose improved
variant is named in prose only, "Minimum-cost flow",
cp-algorithms.com/graph/min_cost_flow.html, "Flows with demands",
cp-algorithms.com/graph/flow_with_demands.html, "Minimum cut -
Stoer-Wagner algorithm", cp-algorithms.com/graph/stoer_wagner_mincut.html,
"Kuhn's Algorithm - Maximum Bipartite Matching",
cp-algorithms.com/graph/kuhn_maximum_bipartite_matching.html, where
the hall's theorem section also lives, that article being the closest
cp-algorithms carries to a dedicated hall page, "Hungarian
algorithm", cp-algorithms.com/graph/hungarian-algorithm.html, and
"Assignment problem", cp-algorithms.com/graph/Assignment-problem-min-flow.html,
all accessed 2026-09-20, cc by-sa 4.0, our own words and code
throughout. Application sources: icpc world finals 2017 problems C and
J, 2018 problem C, 2022 problem X, and 2025 problems B and F (book 10).
Sample behavior verified by the seven suite gates scoped to chapter
38: c 9 files and 83 checks, go 26 test functions, java 9 files and
83 checks under run-java-samples, c\# 28 facts,
javascript 29 tests and 66 asserts across its two split files, python
9 files and 83 asserts, lua 33 checks, zero skipped.
