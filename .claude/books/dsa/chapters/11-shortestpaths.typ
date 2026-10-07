#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= shortest paths

Chapter 10's BFS finds shortest paths when every edge counts as one.
Weights break it: three cheap edges can beat one expensive edge. This
chapter builds the weighted answer for every input class, non-negative
weights, negative edges, all pairs, and grids with a goal. Two
refinements of the single-source pair follow the classics, 0-1 bfs
for weights capped at one and d'esopo-pape as a queue-driven
bellman-ford.

== dijkstra

BFS with a priority queue instead of a fifo: always settle the
unsettled vertex with the smallest known distance, relax its outgoing
edges, done when the heap empties.

The dry run: the fixture is the labeled weighted graph, a to b at 4
and c at 2, b to c at 5 and d at 10, c to e at 3, d to f at 11, e to
d at 4, asserted by the C\# suite, and the integer suites carry
their own fixtures, 0 3 1 4 7 and 0 7 9 20 20 11.

+ Seed a at 0 and relax its arcs: b takes 4, c takes 2, and c is
  the smaller offer waiting in the heap.
+ Settle c at 2: e takes 2 + 3 = 5.
+ Settle b at 4: the arc into d offers 4 + 10 = 14, d's first
  label.
+ Settle e at 5: the route through e offers 5 + 4 = 9, under 14,
  and d's label drops.
+ Settle d at 9: f takes 9 + 11 = 20, and f settles last when the
  heap empties.
+ Distances read a 0, b 4, c 2, d 9, e 5, f 20, the path to f walks
  a c e d f, all asserted, and bellman-ford agrees everywhere on
  the same graph.

#diagram([the settle order as one chain, smallest live label first, d's label dropping once before it settles], length: 13pt, {
  let chain = (([a], 0), ([c], 2), ([b], 4), ([e], 5), ([d], 9), ([f], 20))
  for (i, s) in chain.enumerate() {
    let x = 1.3 + i * 3.5
    cdraw.rect((x - 0.6, 3.4), (x + 0.6, 4.5), fill: if i == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, 4.15), s.at(0), size: 6.5pt)
    cdraw.content((x, 3.75), [#s.at(1)], size: 6pt)
    if i < 5 { cdraw.line((x + 0.75, 3.95), (x + 2.65, 3.95), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((15.4, 5.8), [d: 4 + 10 = 14 from b, then 5 + 4 = 9 through e], size: 6pt)
  cdraw.content((12.4, 2.4), [every pop takes the smallest live label], size: 6pt)
  cdraw.content((12.4, 1.5), [a settle is final, weights are positive], size: 6pt)
  cdraw.content((12.4, 0.6), [path to f: a c e d f, pinned], size: 6pt)
})

The 9 through c and e against the 14 direct is the trap the suite
pins, and the listings below settle it in seven languages.

#listing("dsa/samples-c/src/Ch11/dijkstra.c", first: 49, last: 75, caption: [c, the (dist, vertex) min-heap, push and pop])

#listing("dsa/samples-c/src/Ch11/dijkstra.c", first: 79, last: 101, caption: [c, dijkstra over the heap, stale entries skipped])

#listing("dsa/samples-go/ch11/dijkstra.go", first: 16, last: 64, caption: [go, the container/heap adapter and the relax loop])

This chapter is the one place the matrix lets the shipped queue in:
the heap is a supporting container here, not the lesson. C and Lua
hand-build one in the same file, and Java does too even though its
`PriorityQueue` sits one import away, the heap entries and the
stale-entry skip are the taught mechanism, so it stays hand-rolled.
JavaScript carries a private heap class, Go wires container/heap
through a five-method adapter, Python rides heapq, and the C\# code
keeps its indexed heap with a true decrease-key while the BCL
PriorityQueue plus its O(n) Remove stands as the shipped
counterpart, chapter 8's callout:

#listing("dsa/samples-java/src/Ch11/Dijkstra.java", first: 78, last: 104, caption: [java, dijkstra over the hand-built heap, stale entries skipped, PriorityQueue left out on purpose])

#listing("dsa/samples/src/Ch11/Paths.cs", first: 25, last: 56, caption: [c\#, dijkstra with an indexed heap, stale entry skipping])

The heap holds one entry per improvement, so a vertex can appear with
several priorities and the stale ones are skipped on pop, the lazy
deletion discipline, which is also how the BCL-only version is
typically written given chapter 8's O(n) `Remove`. The indexed heap
here carries a real decrease-key instead, and both runtimes are
logarithmic per edge. The test graph pins the classic trap: the path
through c and e at total 9 beats the direct a b d route at 14, and
the reconstruction walks the predecessor chain backwards.

#flow(
  [one relax operation, before above, after below],
  node((-1.7, 0), [before]),
  node((0, 0), [u, dist 5]),
  node((2.6, 0), [v, dist 11]),
  edge((0, 0), (2.6, 0), "-|>", label: [w = 3]),
  edge((1.3, -0.6), (1.3, -1.8), "-|>", label: [5 + 3 < 11, relax]),
  node((-1.7, -2.6), [after]),
  node((0, -2.6), [u, dist 5]),
  node((2.6, -2.6), [v, dist 8, pred u]),
  edge((0, -2.6), (2.6, -2.6), "-|>", label: [w = 3]),
)

#callout("warning", "the non-negative precondition is binding", [
  Dijkstra's correctness proof needs every edge weight at least
  zero, because it commits a vertex the moment it is popped and
  never revisits. A negative edge can unlock a shorter path after
  the commitment. The tests show the algorithm silently returning
  suboptimal answers on such graphs, which is why bellman-ford
  exists.
])

Four more languages settle their own fixtures:

#listing("dsa/samples-js/src/ch11-dijkstra.mjs", first: 5, last: 41, caption: [javascript, the local min-heap kept inline on purpose])

#listing("dsa/samples-js/src/ch11-dijkstra.mjs", first: 45, last: 64, caption: [javascript, dijkstra with -1 for unreachable])

#listing("dsa/samples-py/src/Ch11/dijkstra.py", first: 15, last: 30, caption: [python, heapq as the supporting container])

#listing("dsa/samples-lua/ch11_dijkstra.lua", first: 24, last: 47, caption: [lua, the hand-built heap of key-value pairs])

#listing("dsa/samples-lua/ch11_dijkstra.lua", first: 51, last: 74, caption: [lua, dijkstra skipping stale lazy-deletion entries])

Measured across the suites: Go, JavaScript, and Python share one
fixture where the direct 0 to 1 edge of weight 4 loses to the
two-hop route of 3, pinning 0 3 1 4 7 from the source and
-1 2 0 3 6 from vertex 2. C, Java, and Lua share the classic 6-vertex
undirected fixture, pinning 0 7 9 20 20 11 from vertex 0, the whole
predecessor chain, 11 12 13 for vertices 0 1 3 from source 5, and a
bellman-ford cross-check over the same edges. The frozen C\# suite
pins its own labeled graph, 9 through c and e against 14 direct.
Nobody here does duplicate work: every version pushes on each
improvement and skips the stale pop.


== bellman-ford

Relax every edge, n minus 1 rounds. Nothing clever, entirely general:
negative edges allowed, and one more full pass that still improves
anything proves a negative cycle.

The dry run: the fixture is the negative-edge store, s to a at 4,
s to b at 5, a to c at -3, b to a at -1, asserted by the C\# suite,
and the integer suites carry their own, 0 1 -1 0 in Go, JavaScript,
and Python.

+ Round 1 opens with the source arcs: a takes 0 + 4 = 4, b takes
  0 + 5 = 5.
+ The negative arc follows in store order: c takes 4 - 3 = 1.
+ The last arc offers the detour through b into a, 5 - 1 = 4, which
  ties the incumbent 4, and the strict test refuses the write.
+ Round 2 relaxes all four arcs again, nothing improves, and the
  quiet round exits early, two of the three possible rounds run.
+ The verdict pass changes nothing, no negative cycle, and the
  suite pins a at 4 and c at 1.
+ On the cycle fixture the arcs 1, -2, -2 loop at 1 - 2 - 2 = -3,
  the verdict pass still improves, and the call throws.

#diagram([round 1 as four arcs in store order, three writes and one refused tie, the quiet round underneath], length: 13pt, {
  let arcs = (
    ([s to a, 4], [0 + 4 = 4], true),
    ([s to b, 5], [0 + 5 = 5], true),
    ([a to c, -3], [4 - 3 = 1], true),
    ([b to a, -1], [5 - 1 = 4, ties], false),
  )
  for (i, a) in arcs.enumerate() {
    let x = 0.7 + i * 5.0
    cdraw.content((x + 1.8, 6.3), a.at(0), size: 6pt)
    cdraw.rect((x, 5.3), (x + 3.6, 6.0), fill: if a.at(2) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.8, 5.65), a.at(1), size: 6pt)
    if a.at(2) {
      cdraw.line((x + 1.8, 5.1), (x + 1.8, 4.5), stroke: luma(100), mark: (end: ">"))
    } else {
      cdraw.content((x + 1.8, 4.8), [refused, no write], size: 6pt)
    }
  }
  cdraw.content((2.5, 3.4), [after round 1: s 0, a 4, b 5, c 1], size: 6pt)
  cdraw.content((2.5, 2.5), [round 2 quiet: exit early, verdict pass clean], size: 6pt)
  cdraw.content((2.5, 1.6), [cycle fixture: 1 - 2 - 2 = -3, the verdict throws], size: 6pt)
})

The 4 and the 1 beside the refused tie are the pinned triple, and
the listings below run the rounds in seven languages.

#listing("dsa/samples-c/src/Ch11/bellman.c", first: 22, last: 44, caption: [c, the rounds, the quiet-round exit, the V-th pass verdict])

#listing("dsa/samples-go/ch11/bellman.go", first: 15, last: 51, caption: [go, negative weights in, negative cycles reported, -1 for unreachable])

#listing("dsa/samples-java/src/Ch11/Bellman.java", first: 22, last: 44, caption: [java, the rounds, the quiet-round exit, the V-th pass verdict])

#listing("dsa/samples/src/Ch11/Paths.cs", first: 58, last: 96, caption: [c\#, relaxation rounds, early exit on convergence, the negative cycle check])

The n-1 bound is the depth of the longest possible shortest path, a
simple chain, and the early exit means nice graphs finish in a few
rounds. The equality test runs dijkstra and bellman-ford on the same
positive graph and asserts identical distances everywhere, two
independent implementations agreeing.

#listing("dsa/samples-js/src/ch11-bellman.mjs", first: 8, last: 27, caption: [javascript, infinity internally so a real -1 distance survives])

#listing("dsa/samples-py/src/Ch11/bellman.py", first: 17, last: 33, caption: [python, none for unreachable, ok flag on the cycle])

#listing("dsa/samples-lua/ch11_bellman.lua", first: 9, last: 31, caption: [lua, the same contract, two return values])

Measured across the suites: Go, JavaScript, and Python share the
negative-edge fixture and pin 0 1 -1 0, the -2 edge making vertex 2
cheaper through 1, refuse the 1 2 1 cycle, and ignore a cycle the
source cannot reach, 0 5 -1 -1 -1 in Go and JavaScript. C, Java, and
Lua share their own fixture, distances 0 1 2 3 with vertex 4
stranded, the -3 cycle detected, and the same cycle invisible when
only an unreachable vertex can see it. Zero-weight edges relax
everywhere.

#diagram([bellman-ford, every edge relaxes each round, a quiet round exits early, one more improving pass proves a negative cycle], length: 13pt, {
  // s to a is 4, a to b is -3, s to b is 5: the long way wins
  let g = ((1.8, 7.6), (5.0, 7.6), (7.6, 6.4))
  cdraw.line(g.at(0), g.at(1), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(1), g.at(2), stroke: luma(100), mark: (end: ">"))
  cdraw.line(g.at(0), g.at(2), stroke: luma(220), mark: (end: ">"))
  for (i, ch) in ("s", "a", "b").enumerate() {
    cdraw.circle(g.at(i), radius: 0.3, fill: luma(235))
    cdraw.content(g.at(i), ch, size: 6.5pt)
  }
  cdraw.content((3.4, 7.95), [4], size: 6pt)
  cdraw.content((6.6, 7.2), [-3], size: 6pt)
  cdraw.content((3.9, 6.7), [5], size: 6pt)

  // distances per round, improved cells shaded
  cdraw.content((0.8, 5.7), [round], size: 6pt)
  for (i, ch) in ("s", "a", "b").enumerate() { cdraw.content((2.6 + i * 1.2, 5.7), ch, size: 6pt) }
  let table = (
    ([r0], [0], [-], [-]),
    ([r1], [0], [4], [5]),
    ([r2], [0], [4], [1]),
  )
  let hot = ((1, 2), (2, 3))
  for (r, row) in table.enumerate() {
    let y = 4.6 - r * 1.1
    cdraw.content((0.8, y), row.at(0), size: 6pt)
    for c in range(3) {
      if (r, c + 1) in hot { cdraw.rect((2.2 + c * 1.2, y - 0.42), (3.0 + c * 1.2, y + 0.42), fill: luma(205), radius: 0.02) }
      cdraw.content((2.6 + c * 1.2, y), row.at(c + 1), size: 6pt)
    }
  }
  cdraw.content((2.6, 1.1), [r3 changes nothing, stop], size: 6pt)

  cdraw.content((14.5, 5.7), [every edge relaxes each round], size: 6pt)
  cdraw.content((14.5, 4.6), [n - 1 rounds bound the], size: 6pt)
  cdraw.content((14.5, 3.5), [longest shortest path], size: 6pt)
  cdraw.content((14.5, 2.5), [one more improving pass], size: 6pt)
  cdraw.content((14.5, 1.2), [proves a negative cycle], size: 6pt)
})

== 0-1 bfs

Dijkstra pays for a heap because arbitrary weights create arbitrary
candidate priorities. Cap every weight at 0 or 1 and the priorities
collapse onto two consecutive values, which a plain deque serves:
pop the front vertex, relax its edges, and when a distance improves,
push that vertex to the front for weight 0 and to the back for
weight 1, with the source seeded at distance 0 up front. Chapter
10's fifo queue wearing dijkstra's discipline, and nothing else in
the machinery changes.

The safety argument is the monotone frontier. The deque always
reads non-decreasing from front to back, and the values inside span
at most one step. A weight 0 relaxation offers dist[u], never
smaller than the value just popped, so a front push cannot unsort
the row. A weight 1 relaxation offers dist[u] + 1, at least as
large as anything still waiting, so a back push cannot unsort it
either. That sorted order is exactly what dijkstra buys with the
heap, so pops settle vertices in non-decreasing distance order and
every pop is final. Pushes stay linear too: a vertex first labeled
across a 1 edge can drop exactly one more value through a 0 edge
from the same distance class and never again, so each vertex enters
the deque at most twice and the whole run costs O(V + E).

Where it earns its keep is modeling. Any state graph where some
moves are free and the rest cost one, doors you walk through versus
locks you pay to open, is a 0-1 graph, and distances come out
linear where dijkstra would pay E log V and bellman-ford V E. Two
buckets indexed by the current distance work just as well, the
deque is the common spelling.

The dry run: no suite carries this facet, the numbers are
hand-derived, and the fixture is a five-vertex digraph reading
s to a at 1, s to c at 1, s to b at 0, b to c at 0, c to d at 0,
a to d at 1.

+ The source seeds the front at 0, and the first pop reads its three
  arcs: a and c take 1 and enter the back, b takes 0 + 0 = 0 and
  enters the front, the row reads b a c.
+ Pop b at 0: c's label drops 1 to 0 + 0 = 0 across the free arc, a
  front push, and c now waits twice.
+ Pop c at 0: d takes 0 + 0 = 0 at the front, the row reads d a c.
+ Pop d at 0, then a at 1: a's paid arc offers d 1 + 1 = 2 against
  the settled 0 and is refused.
+ The second c pops at the stale 1, dist says 0, and is skipped.
+ Six pops, six pushes over five vertices and six arcs, and the
  distances land s 0, b 0, c 0, d 0, a 1: the free corridor reached
  d before the paid arc reached a.

#diagram([the run as one column per pop, the deque waiting under each, the stale second c shaded], length: 13pt, {
  let pops = (
    ("s 0", ("b 0", "a 1", "c 1")),
    ("b 0", ("c 0", "a 1", "c 1")),
    ("c 0", ("d 0", "a 1", "c 1")),
    ("d 0", ("a 1", "c 1")),
    ("a 1", ("c 1",)),
    ("c 1", ()),
  )
  for (k, p) in pops.enumerate() {
    let x = 1.5 + k * 3.6
    cdraw.rect((x - 0.7, 6.2), (x + 0.7, 6.9), fill: luma(205), radius: 0.02)
    cdraw.content((x, 6.55), [#p.at(0)], size: 6pt)
    for (j, v) in p.at(1).enumerate() {
      let y = 5.1 - j * 0.9
      let stale = k >= 1 and v == "c 1"
      cdraw.rect((x - 0.7, y - 0.33), (x + 0.7, y + 0.33), fill: if stale { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x, y), [#v], size: 6pt)
    }
  }
  cdraw.content((11.5, 1.4), [weight 0 enters the front, weight 1 the back], size: 6pt)
  cdraw.content((11.5, 0.6), [c waited twice, its stale copy is skipped], size: 6pt)
  cdraw.content((11.5, -0.2), [6 pops, 6 pushes, every vertex at most twice], size: 6pt)
})

The four zeros against the lone 1 is the run's landing, corridor
first, paid arc behind.

#diagram([0-1 bfs, the deque stays sorted by distance, weight 0 pushes the front, weight 1 pushes the back, every pop is final], length: 13pt, {
  // the popped vertex at distance 3 offers one candidate per weight class
  cdraw.rect((2.6, 5.6), (5.8, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.2, 6.5), [u at 3, w = 0], size: 6pt)
  cdraw.content((4.2, 6.0), [candidate 3], size: 6.5pt)
  cdraw.rect((9.4, 5.6), (12.6, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 6.5), [u at 3, w = 1], size: 6pt)
  cdraw.content((11.0, 6.0), [candidate 4], size: 6.5pt)
  cdraw.line((4.2, 5.55), (5.55, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.2, 4.7), [to the front], size: 6pt)
  cdraw.line((11.0, 5.55), (9.95, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.1, 4.7), [to the back], size: 6pt)
  // the deque, four slots, non-decreasing, values at most one step apart
  for (i, ch) in ("3", "3", "4", "4").enumerate() {
    let x0 = 5.0 + i * 1.3
    cdraw.rect((x0, 2.9), (x0 + 1.3, 3.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 0.65, 3.35), ch, size: 6.5pt)
  }
  cdraw.content((5.65, 2.5), [front], size: 6pt)
  cdraw.content((9.55, 2.5), [back], size: 6pt)
  cdraw.content((7.3, 1.95), [3 lands at the front, 4 at the back], size: 6pt)
  cdraw.content((7.3, 1.2), [the row never unsorts], size: 6pt)

  cdraw.content((16.4, 6.6), [the deque replaces the heap], size: 6pt)
  cdraw.content((16.4, 5.5), [sorted front to back always], size: 6pt)
  cdraw.content((16.4, 4.4), [every pop is final], size: 6pt)
  cdraw.content((16.4, 3.2), [at most two pushes per vertex], size: 6pt)
  cdraw.content((16.4, 1.9), [O(V + E), no log factor], size: 6pt)
})

This facet ships prose only this edition: the wave scoped it as an
extension with no new suite, and the dijkstra listings above
already pin the machinery it reuses.

== d'esopo-pape

Bellman-ford relaxes every edge every round because it cannot tell
which vertices still matter. D'esopo-pape, a label-correcting
refinement, keeps a worklist instead: only a vertex whose label
moved goes back to work, and only its edges get rescanned. The
queue discipline is the whole idea. A vertex queued for the first
time enters the back. A vertex already waiting is not duplicated,
its label improves where it sits. A vertex that had already
finished and improves again jumps to the front, the bet is that its
label is still moving and its neighbors should hear the news early.

It stays bellman-ford where it counts: negative edges are fine, and
a reachable negative cycle still runs forever, so the same cycle
guard or an iteration cap belongs in any production version. The
worst case also gets worse: adversarial orders exist where the
front-jump reactivations multiply into exponential time, worth
knowing before reaching for this under a judge's time limit. The
received experience, passed along by the cp-algorithms article
without a benchmark behind it, is that it usually runs fast, often
ahead of dijkstra, and the same label-correcting loop over a plain
fifo queue is better known as spfa, the shortest path faster
algorithm. Treat the speed as folklore: often true, never promised.

The dry run: no suite carries this facet, the numbers are
hand-derived, and the fixture is a five-vertex digraph reading
s to t at 10, s to a at 1, s to b at 4, a to b at 0, b to c at 2,
c to t at 1.

+ Pop s: three first-time labels enter the back in arc order, t at
  0 + 10 = 10, a at 1, b at 4, the queue reads t a b.
+ Pop t at 10: it finishes, and with no arc out of t the label
  looks final.
+ Pop a at 1: b is still waiting, the free arc drops its label to
  1 + 0 = 1 in place, no second copy enters.
+ Pop b at 1: c takes 1 + 2 = 3 at the back.
+ Pop c at 3: t's label drops to 3 + 1 = 4, and because t already
  finished it jumps the front, the queue reads t alone.
+ Pop t again at 4: the route s a b c t stands against the 10
  direct, and t is the one vertex the worklist ran twice.

#table(
  columns: (auto, 2.2fr, 1.3fr, 1.6fr),
  inset: 4pt,
  table.header([*pop*], [*event*], [*queue after*], [*labels*]),
  [s], [t, a, b first time, to the back], [t a b], [t 10, a 1, b 4],
  [t], [finishes at 10], [a b], [unchanged],
  [a], [b improves while waiting], [b], [b 1],
  [b], [c first time, to the back], [c], [c 3],
  [c], [t improves, jumps the front], [t], [t 4],
  [t], [runs again, label final], [], [t 4],
)

The 4 against the 10 with one vertex run twice is the whole trade,
and the bellman-ford listings above carry the loop this facet
refines.

#diagram([d'esopo-pape, one worklist replaces the rounds, first discovery enters the back, a finished vertex that improves again jumps the front, waiting vertices are not duplicated], length: 13pt, {
  // v finished once and just improved again, w is queued for the first time
  cdraw.rect((2.3, 5.5), (6.1, 6.7), fill: luma(205), radius: 0.02)
  cdraw.content((4.2, 6.35), [v, finished once], size: 6pt)
  cdraw.content((4.2, 5.85), [label just dropped], size: 6pt)
  cdraw.rect((9.4, 5.5), (12.6, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 6.35), [w, never queued], size: 6pt)
  cdraw.content((11.0, 5.85), [label improved], size: 6pt)
  cdraw.line((4.2, 5.45), (6.1, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.1, 4.6), [jumps the front], size: 6pt)
  cdraw.line((11.0, 5.45), (9.4, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.3, 4.6), [enters the back], size: 6pt)
  // the worklist, three waiting vertices
  for (i, ch) in ("b", "c", "d").enumerate() {
    let x0 = 5.8 + i * 1.3
    cdraw.rect((x0, 2.9), (x0 + 1.3, 3.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 0.65, 3.35), ch, size: 6.5pt)
  }
  cdraw.content((6.45, 2.5), [front], size: 6pt)
  cdraw.content((9.05, 2.5), [back], size: 6pt)
  cdraw.content((7.8, 1.95), [a waiting vertex improves in place, no copy], size: 6pt)
  cdraw.content((7.8, 1.2), [only moved labels rescan their edges], size: 6pt)

  cdraw.content((16.6, 6.4), [the rounds become one worklist], size: 6pt)
  cdraw.content((16.6, 5.3), [negative edges still fine], size: 6pt)
  cdraw.content((16.6, 4.2), [negative cycles still loop], size: 6pt)
  cdraw.content((16.6, 3.0), [exponential worst case], size: 6pt)
  cdraw.content((16.6, 1.9), [usually fast, no guarantee], size: 6pt)
})

The bellman-ford listings above already pin the machinery this facet
refines.

== floyd-warshall

All pairs shortest paths by dynamic programming over intermediate
vertices: `dist[i, j]` is the best route using only the first k
vertices as way points, and k grows in the outermost loop.

The dry run: the fixture is the same labeled weights loaded into a
6 by 6 matrix, asserted by the C\# suite against the dijkstra row,
and C and Lua pin a 7-arc digraph whose row 0 reads 0 3 5 6.

+ The load writes the direct arcs, so row a opens 0 4 2 with the
  far cells unreachable.
+ k = b: d reads 4 + 10 = 14 through b, the two-hop route.
+ k = c: e reads 2 + 3 = 5.
+ k = d: the e row buys the arc to f at 4 + 11 = 15, and row a's
  f reads 14 + 11 = 25.
+ k = e: d drops to 5 + 4 = 9 and f drops to 5 + 15 = 20, both
  through e.
+ Row a finishes 0 4 2 9 5 20, every cell equal to the dijkstra
  single-source answers, the cross-check the suite asserts.

#table(
  columns: (auto, 3fr, auto),
  inset: 4pt,
  table.header([*k*], [*writes*], [*row a after*]),
  [load], [the direct arcs], [0 4 2 inf inf inf],
  [b], [d = 4 + 10], [0 4 2 14 inf inf],
  [c], [e = 2 + 3], [0 4 2 14 5 inf],
  [d], [e to f = 4 + 11, a to f = 14 + 11], [0 4 2 14 5 25],
  [e], [d = 5 + 4, f = 5 + 15], [0 4 2 9 5 20],
)

The 9 and the 20 in the finished row are the cells the suite pins,
and the listings below close the loop in seven languages.

#listing("dsa/samples-c/src/Ch11/floyd.c", first: 21, last: 35, caption: [c, matrix load, the k-outermost triple loop])

#listing("dsa/samples-go/ch11/floyd.go", first: 5, last: 27, caption: [go, closure over a copied matrix, 2^61 as infinity])

#listing("dsa/samples-java/src/Ch11/Floyd.java", first: 21, last: 35, caption: [java, matrix load, the k-outermost triple loop])

#listing("dsa/samples/src/Ch11/Paths.cs", first: 99, last: 114, caption: [c\#, three nested loops, the k in the middle of the recurrence outside])

Cubic time and quadratic space buys every pair's distance at once,
which wins over n dijkstra runs when the graph is dense and small.
The test cross-checks the first row against dijkstra's single source
answers.

#listing("dsa/samples-js/src/ch11-floyd.mjs", first: 4, last: 14, caption: [javascript, copy in, relax, return])

#listing("dsa/samples-py/src/Ch11/floyd.py", first: 16, last: 24, caption: [python, the same triple loop on a copy])

#listing("dsa/samples-lua/ch11_floyd.lua", first: 19, last: 30, caption: [lua, nested numeric for loops over the table matrix])

Measured across the suites: Go, JavaScript, and Python pin the full
closure of a 4-node matrix where 0 to 3 improves 10 to 9 through
1 and 2, Python adding a dense triangle whose 6 relaxes to 5 and a
dijkstra sweep that agrees with every cell. C, Java, and Lua share a
7-edge digraph, pin all 16 cells, row 0 reading 0 3 5 6, check the
triangle inequality over the finished closure, and keep an
unreachable pair at infinity. Seven listings, one loop nest, k on
the outside in every one.

#diagram([floyd-warshall, k grows in the outermost loop, every pair's distance at cubic total], length: 13pt, {
  // two distance matrices over a b c, way points limited to the first k
  let mat = (x0, m, hotcell) => {
    for c in range(3) { cdraw.content((x0 + c * 0.9 + 0.45, 5.55), ("a", "b", "c").at(c), size: 6pt) }
    for r in range(3) {
      cdraw.content((x0 - 0.35, 5.05 - r * 0.9), ("a", "b", "c").at(r), size: 6pt)
      for c in range(3) {
        let hot = (r, c) == hotcell
        cdraw.rect((x0 + c * 0.9, 4.65 - r * 0.9), (x0 + (c + 1) * 0.9, 5.55 - r * 0.9), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
        cdraw.content((x0 + c * 0.9 + 0.45, 5.1 - r * 0.9), m.at(r).at(c), size: 6pt)
      }
    }
  }
  mat(1.6, (([0], [3], [12]), ([-], [0], [4]), ([-], [-], [0])), none)
  cdraw.line((5.0, 4.1), (8.9, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 4.65), [k outermost], size: 6pt)
  mat(9.7, (([0], [3], [7]), ([-], [0], [4]), ([-], [-], [0])), (0, 2))
  cdraw.content((13.4, 2.6), [via b: 3 + 4 = 7], size: 6pt)

  cdraw.content((17.5, 4.6), [d[i,j] = min(d[i,j],], size: 6pt)
  cdraw.content((17.5, 3.5), [d[i,k] + d[k,j])], size: 6pt)
  cdraw.content((17.5, 1.4), [every pair, cubic total], size: 6pt)
})

== a star

Dijkstra explores by distance from the source. A star explores by
distance plus an estimate to the goal, and when the estimate never
overestimates, admissible, the first pop of the goal is still
optimal.

The dry run: the fixture is the 5 by 5 grid walled across row 2
with the gap at column 4, searched from the corner to the corner,
asserted by the C\# suite, and the integer suites pin expansion
counts under documented tie-breaks.

+ The heuristic at the start reads 4 + 0 = 4, an honest lower
  bound, and the wall kills every 4-step route.
+ The search moves right along row 0, each step buying one g and
  paying one h: f climbs 1 + 5 = 6, 2 + 6 = 8, 3 + 7 = 10.
+ The gap column tops out at 4 + 8 = 12, and that cell is the
  turn.
+ Down the gap: 5 + 7, 6 + 6, 7 + 5, every f 12, with the middle
  cell the pinned detour point.
+ The run turns left along row 4: 9 + 3, 10 + 2, 11 + 1, each left
  step spends one g and refunds one h, f holds to the goal.
+ The goal pops at g = 12 over 13 cells, both pinned, and the open
  8 by 8 lands 7 + 7 = 14 over 15 cells the same way.

#diagram([f along the 13-cell detour, climbing by two per right step, flat 12 from the gap home], length: 13pt, {
  let fs = (4, 6, 8, 10, 12, 12, 12, 12, 12, 12, 12, 12, 12)
  let marks = ((0, [g 0 + h 4]), (4, [g 4 + h 8]), (6, [g 6 + h 6]), (12, [g 12 + h 0]))
  for (i, f) in fs.enumerate() {
    let x = 1.0 + i * 1.5
    cdraw.rect((x, 3.2), (x + 1.35, 4.3), fill: if f == 12 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.675, 3.75), [#f], size: 6.5pt)
  }
  for m in marks {
    let x = 1.0 + m.at(0) * 1.5 + 0.675
    cdraw.line((x, 3.1), (x, 2.55), stroke: (paint: luma(160), dash: "dashed"))
    cdraw.content((x, 2.15), m.at(1), size: 6pt)
  }
  cdraw.content((3.4, 5.0), [row 0: f climbs 4, 6, 8, 10], size: 6pt)
  cdraw.content((15.0, 5.0), [gap column and row 4: f flat at 12], size: 6pt)
  cdraw.content((10.5, 1.0), [the gap cell sits on the path, cost 12 over 13 cells], size: 6pt)
})

The 12 around the wall and the 14 across the open grid are the
pinned pair, and the listings below search in seven languages.

#listing("dsa/samples-c/src/Ch11/astar.c", first: 90, last: 125, caption: [c, the search loop, closed set, tie-broken heap pushes])

#listing("dsa/samples-go/ch11/astar.go", first: 54, last: 100, caption: [go, open queue by f then insertion order, parent rebuild])

#listing("dsa/samples-java/src/Ch11/Astar.java", first: 88, last: 124, caption: [java, the search loop, closed set, tie-broken heap pushes over the hand-built heap])

#listing("dsa/samples/src/Ch11/Paths.cs", first: 117, last: 161, caption: [c\#, a star on a grid with the manhattan heuristic])

Manhattan distance is admissible for unit-cost grid steps because no
route can beat the straight-line block count. The random-grid test
asserts the deeper property, a star's cost equals the BFS distance
on one hundred twenty random walls, optimal search without exploring
the whole maze. A heavier point: the same code with the heuristic
set to zero is dijkstra, and a heuristic that overestimates trades
optimality for speed, which is exactly the dial game developers
turn.

#listing("dsa/samples-js/src/ch11-astar.mjs", first: 55, last: 97, caption: [javascript, the grid walk over the private heap])

#listing("dsa/samples-py/src/Ch11/astar.py", first: 15, last: 48, caption: [python, heapq with a tick counter for fifo ties])

#listing("dsa/samples-lua/ch11_astar.lua", first: 46, last: 82, caption: [lua, cells keyed r*cols+c, (f, h, seq) heap])

Measured across the suites: C, Java, and Lua pin 7 expansions on an
open 4 by 4 and 5 around a center-walled 3 by 3, under a documented
tie-break, f first, then smaller h, then insertion order, with
neighbors offered right down left up. Go, JavaScript, and Python
use a 3 by 3 where every f ties at 4, so all 9 cells expand before
the goal pops, and the wall fixture pins the 7-cell detour path,
Go and Python counting 7 expansions while JavaScript bounds
expansions by the grid size. Expansion counts are tie-break facts,
not constants: reorder the neighbors and the counts move, the path
lengths do not.

#diagram([a star on the grid, f = g + h, the manhattan heuristic never overestimates so the goal's first pop is optimal], length: 13pt, {
  // h written in every cell, one wall, the optimal path through the valley
  for r in range(3) {
    for c in range(6) {
      let x = 1.8 + c * 1.15
      let y = 5.85 - r * 1.15
      let wall = (c, r) == (3, 1)
      cdraw.rect((x, y - 1.15), (x + 1.15, y), fill: if wall { luma(205) } else { luma(235) }, radius: 0.02)
      if wall {
        cdraw.content((x + 0.575, y - 0.575), [wall], size: 6pt)
      } else if (c, r) == (0, 0) {
        cdraw.content((x + 0.575, y - 0.575), [S], size: 6.5pt)
      } else if (c, r) == (5, 2) {
        cdraw.content((x + 0.575, y - 0.575), [G], size: 6.5pt)
      } else {
        cdraw.content((x + 0.575, y - 0.575), [#((5 - c) + (2 - r))], size: 6pt)
      }
    }
  }
  let path = ((0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (4, 1), (5, 1), (5, 2))
  let ctr = (c, r) => (1.8 + c * 1.15 + 0.575, 5.85 - r * 1.15 - 0.575)
  for i in range(path.len() - 1) { cdraw.line(ctr(..path.at(i)), ctr(..path.at(i + 1)), stroke: luma(100)) }

  cdraw.content((13.0, 6.3), [f = g + h], size: 6.5pt)
  cdraw.content((14.5, 5.2), [h is block count, admissible], size: 6pt)
  cdraw.content((15.0, 4.1), [f stays 7 on optimal paths], size: 6pt)
  cdraw.content((15.0, 3.0), [first pop of the goal is optimal], size: 6pt)
  cdraw.content((14.8, 1.9), [h = 0 degenerates to dijkstra], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines over this chapter's
four featured files per language. This is the matrix's one
container exception: the priority queue under dijkstra and a star is
the shipped one where a language ships it, hand-built where it does
not:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [380], [libc only], [hand heaps in the dijkstra and astar files, 64 and 128 slot arrays, checks share the file with main, 55 of them],
  [go], [199], [container/heap], [the chapter exception in force, adapters per file, -1 marks unreachable, 11 tests],
  [java], [390], [jdk 27 stdlib], [PriorityQueue left unused, the exception declined because the heap entries and the stale-entry skip are the taught mechanism, hand heaps of record pairs, INF a billion],
  [c\#], [218], [bcl only], [frozen suite, indexed heap with decrease-key in the same file, PriorityQueue named as the shipped twin, 10 tests],
  [javascript], [165], [node stdlib], [private local heaps inline by design, Infinity internally in bellman-ford so -1 distances survive, 12 tests],
  [python], [213], [heapq], [heapq as the supporting container, tick counters pin tie order, 26 checks],
  [lua], [350], [lib.lua harness], [hand heaps with 1-based index math, maxinteger as infinity, checks ride in the module, 16 of them],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>`,
`HashSet<T>`, and `Queue<T>` pages used by the implementation,
accessed 2026-09-08. The two prose-only extensions draw on
cp-algorithms, the articles 0-1 BFS at
https://cp-algorithms.com/graph/01_bfs.html and D'Esopo-Pape
algorithm at https://cp-algorithms.com/graph/desopo_pape.html, both
accessed 2026-09-20 under cc by-sa 4.0, taught here in our own
words. Sample behavior verified by
`make verify-csharp`, 10 tests in chapter 11 of the samples suite.
The seven-language layer verifies the same way: 4 C programs with 55
embedded checks under `make verify-c`, 11 Go tests, the java
runner's 52 Ch11 checks over 4 files under `run-java-samples`, 12
`node --test` cases, 26 Python checks across 4 files, and 16 Lua
checks under `run.lua`.
