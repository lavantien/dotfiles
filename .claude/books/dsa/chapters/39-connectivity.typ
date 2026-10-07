#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= graph connectivity and decomposition

The dfs of #xref-to("dsa", "graphs") answers reachability and counts
components. This chapter asks the sharper questions the same walk
cannot answer alone: which vertices are mutually reachable, what holds
a graph together, what can be split by removing one vertex or one
edge, and how a tree decomposes into structures that make path
questions cheap. Kosaraju's two passes label the strongly connected
components, disc and low values expose bridges and articulation
points, degree parity decides eulerian walks, and four tree
decompositions, ancestors by lifting, heavy paths, centroid layers,
and the rings of functional graphs, turn hard path queries into short
walks. The chapter closes with prufer codes, the second-best spanning
tree, and robbins' orientation theorem in prose.

== strongly connected components

Two passes, no recursion anywhere, the iterative house form of the
chapter 10 dfs. The first pass walks the graph forward on an explicit
stack of vertex-and-iterator frames and records vertices by finished
time: a vertex is appended only when its entire subtree is done. The
second pass consumes that order backwards over the reversed graph,
flooding a fresh component label from each unfinished vertex. The
reversal is the whole argument: within a strongly connected group,
finish order survives the reversal, so the backward flood from the
latest-finishing member captures exactly the group and nothing past
it. Canonical labels rename each component by its smallest vertex
index, condensation arcs are deduplicated and sorted, and the
condensation itself is a dag.

The dry run: the fixture is the 8-vertex chain of cycles, arcs 0 to
1, 1 to 2, 2 back to 0, 2 to 3, 3 to 4, 4 to 5, 5 back to 3, 5 to 6,
6 to 7, 7 back to 6, asserted by all seven suites.

+ The first pass runs from 0 and pushes one spine, 0, 1, 2, 3, 4, 5,
  6, 7: every arc leads onward, and the two closers, 2 to 0 and 5 to
  3, both find their targets already seen.
+ Nothing new is reachable, so the unwind appends finished vertices
  deepest first: the order reads 7, 6, 5, 4, 3, 2, 1, 0.
+ The second pass consumes that order backwards over the reversed
  arcs, opening at 0: the flood pulls in 2 and then 1, raw component
  0 claiming {0, 1, 2}.
+ The next unclaimed vertex is 3, whose flood pulls 5 and 4 for raw
  component 1, and 6 opens the last flood with 7 for raw 2.
+ Renaming by smallest member turns the raw ids into labels 0, 3, 6,
  and the two cross arcs dedupe to (0, 3) and (3, 6), a two-arc dag.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*action*], [*state*]),
  [push], [spine 0 through 7, closers seen], [no arc left untried],
  [unwind], [append on finish, deepest first], [order 7, 6, 5, 4, 3, 2, 1, 0],
  [flood 0], [reversed arcs pull 2, 1], [raw 0 = {0, 1, 2}],
  [flood 3], [reversed arcs pull 5, 4], [raw 1 = {3, 4, 5}],
  [flood 6], [reversed arcs pull 7], [raw 2 = {6, 7}],
  [relabel], [smallest member per raw id], [labels 0, 3, 6],
)

The labels 0, 0, 0, 3, 3, 3, 6, 6 over three components with the
arcs (0, 3) and (3, 6) are the pinned row, and the listings below
run both passes in seven languages.

#listing("dsa/samples-c/src/Ch39/scc.c", first: 50, last: 97, caption: [c, the finish-order pass on explicit frames, the reversed-graph flood])
#listing("dsa/samples-go/ch39/scc.go", first: 20, last: 65, caption: [go, the two passes over frame structs, component ids from the flood])
#listing("dsa/samples-java/src/Ch39/Scc.java", first: 51, last: 100, caption: [java, the finish-order pass on explicit frames, the reversed-graph flood, a line-for-line port of the c stack])
#listing("dsa/samples/src/Ch39/Strong.cs", first: 43, last: 91, caption: [c\#, raw components in condensation order, relabeled by smallest member above])
#listing("dsa/samples-js/src/ch39-scc.mjs", first: 8, last: 53, caption: [javascript, the frame stack, the backward flood, raw ids])
#listing("dsa/samples-py/src/Ch39/scc.py", first: 17, last: 65, caption: [python, the two passes then the canonical relabel and condensation])
#listing("dsa/samples-lua/ch39_scc.lua", first: 20, last: 69, caption: [lua, the same two passes in 1-based tables])

Tarjan's one-pass alternative with a live stack carries the same
answer in one sweep and is named here for completeness, kosaraju is
what ships because two simple passes beat one subtle one.

The fixture family runs one graph through all of it: 8 vertices with
arcs 0 to 1, 1 to 2, 2 back to 0, 2 to 3, 3 to 4, 4 to 5, 5 back to 3,
5 to 6, 6 to 7, 7 back to 6. Labels land 0, 0, 0, 3, 3, 3, 6, 6, three
components, condensation arcs (0, 3) and (3, 6). A pure dag stays
split, 0, 1, 2, 3 with the dag itself as its condensation, a bare
3-cycle collapses to one component with no condensation arcs, a lone
vertex is one component, and two vertices with arcs both ways form one
component. Java's two passes are a line-for-line port of the c frame
stack, the iter arrays walking the same orbit, so the finish order and
the labels pin without translation.

#diagram([the fixture graph with its three components as shaded blobs chained by the two condensation arcs], length: 13pt, {
  // blobs around {0,1,2}, {3,4,5}, {6,7}
  cdraw.circle((2.7, 6.2), radius: 1.35, fill: luma(238), stroke: luma(190))
  cdraw.circle((7.3, 6.2), radius: 1.35, fill: luma(238), stroke: luma(190))
  cdraw.circle((11.4, 6.2), radius: 1.0, fill: luma(238), stroke: luma(190))
  let n = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.28, fill: luma(250), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  let e = (p, q) => cdraw.line(p, q, stroke: luma(140))
  // comp 0: 0 -> 1 -> 2 -> 0
  e((2.2, 6.9), (2.2, 5.5))
  e((2.2, 5.5), (3.6, 6.2))
  e((3.6, 6.2), (2.2, 6.9))
  // 2 -> 3 crosses into comp 3
  e((3.6, 6.2), (6.8, 6.9))
  // comp 3: 3 -> 4 -> 5 -> 3
  e((6.8, 6.9), (6.8, 5.5))
  e((6.8, 5.5), (8.4, 6.2))
  e((8.4, 6.2), (6.8, 6.9))
  // 5 -> 6 crosses into comp 6
  e((8.4, 6.2), (11.4, 6.7))
  // comp 6: 6 -> 7 -> 6
  e((11.4, 6.7), (11.4, 5.7))
  e((11.4, 5.7), (11.4, 6.7))
  n(2.2, 6.9, [0])
  n(2.2, 5.5, [1])
  n(3.6, 6.2, [2])
  n(6.8, 6.9, [3])
  n(6.8, 5.5, [4])
  n(8.4, 6.2, [5])
  n(11.4, 6.7, [6])
  n(11.4, 5.7, [7])
  cdraw.content((2.7, 7.9), [comp 0], size: 6pt)
  cdraw.content((7.3, 7.9), [comp 3], size: 6pt)
  cdraw.content((11.4, 7.5), [comp 6], size: 6pt)
  cdraw.content((5.2, 7.4), [0 -> 3], size: 6pt)
  cdraw.content((9.9, 7.4), [3 -> 6], size: 6pt)
  cdraw.content((7.0, 3.4), [finish order feeds the reversed flood], size: 6pt)
  cdraw.content((7.0, 2.5), [labels: smallest member per component], size: 6pt)
  cdraw.content((7.0, 1.6), [condensation is a dag, arcs deduped], size: 6pt)
  cdraw.content((7.0, 0.7), [o(v + e), iterative, tarjan named], size: 6pt)
})

The application is general technique, the substrate under 2-sat below
and every condensation-shaped dp.

== 2-sat

A clause (a or b) is two promises: if a is false then b, and if b is
false then a. Literal x lives at node 2v and its negation at 2v + 1,
uniform across the seven languages, and each clause adds the two
implication arcs, from the negation of one side into the other. One
kosaraju run over that implication graph decides satisfiability: a
variable whose two literals share a component is contradictory, the
component forces x and not x together. Otherwise every variable takes
the literal whose component sits later in the condensation order, the
side with no outgoing path into its negation.

The dry run: the fixture is the forced formula (a) and (not a or
not b) and (b or c), asserted by all seven suites, each brute-checking
that a true, b false, c true is the only satisfying row.

+ Literals sit at 2v and 2v + 1: a at 0, not a at 1, b at 2, not b
  at 3, c at 4, not c at 5.
+ The clauses write five distinct arcs: (a) gives not a to a, (not a
  or not b) gives a to not b and b to not a, and (b or c) gives not
  b to c and not c to b.
+ The embedded kosaraju finishes c, not b, a, not a, b, not c in
  that order: the pass from 0 dies at c, and every later seed finds
  only visited targets.
+ Consumed backwards, each flood dies at its seed, so the raw
  components read a 3, not a 2, b 1, not b 4, c 5, not c 0, six
  singletons in condensation order.
+ No literal shares a component with its negation, so the formula is
  satisfiable, and later wins: 3 > 2 makes a true, 1 > 4 leaves b
  false, 5 > 0 makes c true.

#diagram([the forced formula's run, finish rank above each literal, raw component below, the three comparisons deciding the assignment], length: 13pt, {
  let lit = ([a], [not a], [b], [not b], [c], [not c])
  let rank = ([3rd], [4th], [5th], [2nd], [1st], [6th])
  let comp = ([3], [2], [1], [4], [5], [0])
  for i in range(6) {
    let x = 1.7 + i * 2.9
    cdraw.content((x, 6.1), rank.at(i), size: 6pt)
    cdraw.rect((x - 0.75, 4.7), (x + 0.75, 5.5), fill: luma(235), radius: 0.02)
    cdraw.content((x, 5.1), lit.at(i), size: 6.5pt)
    cdraw.content((x, 4.1), [comp #comp.at(i)], size: 6pt)
  }
  let pair = (x1, x2, txt) => {
    cdraw.line((x1, 3.1), (x2, 3.1), stroke: luma(150))
    cdraw.line((x1, 3.1), (x1, 3.38), stroke: luma(150))
    cdraw.line((x2, 3.1), (x2, 3.38), stroke: luma(150))
    cdraw.content(((x1 + x2) / 2, 2.55), txt, size: 6pt)
  }
  pair(1.7, 4.6, [3 > 2: a true])
  pair(7.5, 10.4, [1 > 4: b false])
  pair(13.3, 16.2, [5 > 0: c true])
  cdraw.content((8.9, 1.5), [later component wins, a plain comparison], size: 6pt)
  cdraw.content((8.9, 0.6), [six singletons: satisfiable], size: 6pt)
})

The unique a true, b false, c true is the pinned row, and the
listings below build the implication graph and read the assignment
out in seven languages.

#listing("dsa/samples-c/src/Ch39/twosat.c", first: 105, last: 125, caption: [c, the contradiction test and the later-component rule, the clause builder two arcs above])
#listing("dsa/samples-go/ch39/twosat.go", first: 10, last: 41, caption: [go, literal encoding, the embedded kosaraju twin, the extraction])
#listing("dsa/samples-java/src/Ch39/Twosat.java", first: 107, last: 129, caption: [java, the contradiction test and the later-component rule, the clause evaluator for the brute twin])
#listing("dsa/samples/src/Ch39/Strong.cs", first: 104, last: 125, caption: [c\#, the clause-to-arcs translation, the value extraction over raw ids])
#listing("dsa/samples-js/src/ch39-twosat.mjs", first: 55, last: 70, caption: [javascript, the clause walk, the share test, the values])
#listing("dsa/samples-py/src/Ch39/twosat.py", first: 57, last: 81, caption: [python, the implication build, the extraction, the evaluator below])
#listing("dsa/samples-lua/ch39_twosat.lua", first: 65, last: 92, caption: [lua, the same build and extraction, the checker beneath])

Each standalone file embeds its own small kosaraju with raw component
ids in condensation order, the trick that makes "later component wins"
a plain integer comparison.

The four sign combinations of (a or b) together are unsatisfiable,
every assignment falsifies one of them. The chain, (a) and (not a or
b) and (not b or c), forces all true. The forced fixture, (a) and
(not a or not b) and (b or c), pins the unique satisfying assignment
a true, b false, c true, and the suites verify the uniqueness by
brute enumeration before pinning it. The edges: (x or x) forces x
true, and (x) with (not x) refuses.

#diagram([the forced fixture's implication graph with the component split and the truth choice per variable], length: 13pt, {
  // literals: a, !a, b, !b, c, !c laid out in two rows, arcs from the three clauses
  let n = (x, y, k, hot) => {
    cdraw.rect((x - 0.5, y - 0.32), (x + 0.5, y + 0.32), fill: if hot { luma(215) } else { luma(240) }, stroke: luma(120), radius: 0.04)
    cdraw.content((x, y), k, size: 7pt)
  }
  let a = (1.6, 6.8, [a], true)
  let na = (1.6, 4.6, [not a], false)
  let b = (5.6, 6.8, [b], false)
  let nb = (5.6, 4.6, [not b], true)
  let c = (9.6, 6.8, [c], true)
  let nc = (9.6, 4.6, [not c], false)
  let p = (x) => (x.at(0), x.at(1))
  let arrow = (x, y, dx1, dx2) => cdraw.line((x.at(0) + dx1, x.at(1)), (y.at(0) + dx2, y.at(1)), stroke: luma(140), mark: (end: ">"))
  // (a): not a -> a
  arrow(na, a, 0.5, -0.5)
  // (not a or not b): a -> not b, b -> not a
  arrow(a, nb, 0.5, -0.5)
  arrow(b, na, 0.5, -0.5)
  // (b or c): not b -> c, not c -> b
  arrow(nb, c, 0.5, -0.5)
  arrow(nc, b, -0.5, 0.5)
  n(..a)
  n(..na)
  n(..b)
  n(..nb)
  n(..c)
  n(..nc)
  cdraw.content((3.6, 7.5), [a -> not b], size: 6pt)
  cdraw.content((7.6, 7.5), [not b -> c], size: 6pt)
  cdraw.content((3.6, 3.9), [b -> not a], size: 6pt)
  cdraw.content((7.6, 3.9), [not c -> b], size: 6pt)
  cdraw.content((1.6, 8.2), [chosen], size: 6pt)
  cdraw.content((5.6, 3.9), [chosen], size: 6pt)
  cdraw.content((5.6, 2.6), [assignment: a true, b false, c true], size: 6pt)
  cdraw.content((5.6, 1.7), [x shares a component with not x: unsat], size: 6pt)
  cdraw.content((5.6, 0.8), [otherwise the later component wins], size: 6pt)
})

The application is general technique, the solver behind scheduling
with conflicts, seating arrangements, and every yes-or-no-per-variable
question whose constraints come in pairs.

== bridges and articulation points

One dfs carries two numbers per vertex: the discovery time disc, the
tick when the vertex was first reached, and the low-link, the earliest
disc reachable from the vertex's subtree using at most one back edge.
The classification happens on the unwind: a child whose low stays
above its parent's disc cannot reach behind the parent, so the tree
edge between them is a bridge, and a non-root vertex whose child's low
reaches only as far as the parent's disc sits at the articulation
hinge. The parent edge is skipped by edge id, not by endpoint, so a
true parallel edge would count as a second way around, the fixtures
carry none. The root is its own trap, it articulates exactly when it
has two or more dfs children, the case the single-edge fixture pins.

The dry run: the fixture is two triangles joined by the single edge
2 to 3, asserted by all seven suites.

+ The timer opens at 1 on root 0 and the spine runs 0, 1, 2, 3, 4,
  5, one discovery each: disc 1 through 6, low starting equal.
+ The closers are back edges: 2 to 0 drops low of 2 to min(3, 1) =
  1, and 5 to 3 drops low of 5 to min(6, 4) = 4.
+ The unwind merges child lows into parents: low of 4 takes min(5,
  4) = 4, low of 3 holds 4, and low of 2, 1, and 0 settle at 1.
+ Classifying as frames pop: low of 4 reads 4 >= disc of 3, so 3
  articulates, and low of 3 reads 4 > disc of 2, so edge (2, 3) is
  the bridge and 2 articulates with it.
+ The root keeps one dfs child and stays out: the verdicts land
  bridge (2, 3) with articulation vertices 2 and 3.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*vertex*], [*disc*], [*low*], [*verdict*]),
  [0], [1], [1], [root, one dfs child, safe],
  [1], [2], [1], [plain],
  [2], [3], [1], [articulation],
  [3], [4], [4], [articulation],
  [4], [5], [4], [plain],
  [5], [6], [4], [plain],
)

The lone bridge with both endpoints hinging is the pinned pair, and
the listings below classify in seven languages.

#listing("dsa/samples-c/src/Ch39/bridges.c", first: 56, last: 105, caption: [c, the iterative unwind merging low and classifying bridge and articulation])
#listing("dsa/samples-go/ch39/bridges.go", first: 34, last: 82, caption: [go, paired arcs per edge, the unwind classifying on the parent frame])
#listing("dsa/samples-java/src/Ch39/Bridges.java", first: 56, last: 108, caption: [java, the iterative unwind merging low and classifying bridge and articulation])
#listing("dsa/samples/src/Ch39/Edges.cs", first: 24, last: 70, caption: [c\#, the same unwind, enumerators on the frame stack, the root child count])
#listing("dsa/samples-js/src/ch39-bridges.mjs", first: 20, last: 57, caption: [javascript, the back-edge min, the unwind, the root rule])
#listing("dsa/samples-py/src/Ch39/bridges.py", first: 27, last: 65, caption: [python, frames as tuples, the unwind with both classifications])
#listing("dsa/samples-lua/ch39_bridges.lua", first: 27, last: 78, caption: [lua, the same unwind over table frames])

Two triangles sharing vertex 0 have no bridges and exactly one
articulation vertex, 0. Two triangles joined by the single bridge 2 to
3 report the bridge and both of its endpoints as articulation points.
A path of four vertices makes every edge a bridge and both interior
vertices articulation points, and a single edge is a bridge with no
articulation vertex at all, the root trap: the root has one child.

#diagram([two triangles joined by the bridge 2 to 3, the bridge cut, the two biconnected blobs, both articulation vertices ringed], length: 13pt, {
  let n = (x, y, k, art: false) => {
    if art { cdraw.circle((x, y), radius: 0.4, stroke: (paint: luma(100), dash: "dashed")) }
    cdraw.circle((x, y), radius: 0.28, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  cdraw.circle((2.6, 6.5), radius: 1.35, fill: luma(238), stroke: luma(190))
  cdraw.circle((6.6, 6.5), radius: 1.35, fill: luma(238), stroke: luma(190))
  let e = (p, q, hot: false) => cdraw.line(p, q, stroke: if hot { luma(60) } else { luma(150) })
  e((2.0, 7.2), (3.2, 7.2))
  e((3.2, 7.2), (2.6, 5.6))
  e((2.6, 5.6), (2.0, 7.2))
  e((2.6, 5.6), (6.0, 7.2), hot: true)
  e((6.0, 7.2), (7.2, 7.2))
  e((7.2, 7.2), (6.6, 5.6))
  e((6.6, 5.6), (6.0, 7.2))
  n(2.0, 7.2, [0])
  n(3.2, 7.2, [1])
  n(2.6, 5.6, [2], art: true)
  n(6.0, 7.2, [3], art: true)
  n(7.2, 7.2, [4])
  n(6.6, 5.6, [5])
  cdraw.content((4.3, 4.9), [the bridge (2, 3)], size: 6pt)
  cdraw.content((2.6, 3.6), [bridge: low child > disc parent], size: 6pt)
  cdraw.content((2.6, 2.7), [articulation: low child >= disc parent], size: 6pt)
  cdraw.content((2.6, 1.8), [root: two or more dfs children], size: 6pt)
  cdraw.content((2.6, 0.9), [the ringed 2 appears on both sides], size: 6pt)
})

The application is icpc world finals 2022 problem R (book 10, chapter
11), zoo management, which drops every bridge and solves each
2-edge-connected component alone. The online variant, bridges under
edge insertion via link-cut machinery, is one prose paragraph in the
sources and stays out of the code.

== eulerian paths

Degree parity is the whole decision. A connected multigraph with
exactly two odd-degree vertices has an open eulerian path between
them, zero odd vertices has a closed circuit, and anything else has no
walk at all, konigsberg's four lands with degrees 5, 3, 3, 3 included.
Hierholzer's construction walks greedily from the canonical start, the
smallest odd vertex or else the smallest non-isolated one, always
taking the smallest-indexed unused edge by multigraph edge id, and
appends the current vertex to the walk when stuck. The stack order
reversed is the walk, and the smallest-next rule makes it identical in
all seven languages.

The dry run: the fixture is the triangle 0, 1, 2 plus the tail 2 to
3, 3 to 4, asserted by all seven suites.

+ Degrees read 2, 2, 3, 2, 1: exactly two odd vertices, 2 and 4, so
  an open path exists and the canonical start is the smaller, 2.
+ The stack opens at 2 and the smallest-unused rule walks 0, 1, back
  to 2, then 3, then 4: the stack reads 2, 0, 1, 2, 3, 4.
+ Vertex 4 has spent its only edge and is stuck, and so is every
  frame beneath it once control returns: the pops append 4, 3, 2, 1,
  0, 2.
+ Reversing the append order reads the walk 2, 0, 1, 2, 3, 4, five
  edges, each spent exactly once.

#diagram([the run as two sequences, the stack growing under the smallest-unused rule above, the stuck-append unwind below, the reverse landing the walk], length: 13pt, {
  let row = (y, title, vals, hot) => {
    cdraw.content((10.5, y + 1.15), title, size: 6pt)
    for (i, v) in vals.enumerate() {
      let x = 3.2 + i * 2.6
      cdraw.circle((x, y), radius: 0.32, fill: if v == hot { luma(205) } else { luma(235) }, stroke: luma(120))
      cdraw.content((x, y), [#v], size: 6.5pt)
      if i < vals.len() - 1 {
        cdraw.line((x + 0.44, y), (x + 2.16, y), stroke: luma(140), mark: (end: ">"))
      }
    }
  }
  row(5.8, [pushes: the stack grows, smallest unused edge first], (2, 0, 1, 2, 3, 4), 4)
  row(3.1, [appends on stuck: the pops unwind], (4, 3, 2, 1, 0, 2), 2)
  cdraw.rect((3.2, 0.9), (17.8, 1.9), fill: luma(205), radius: 0.02)
  cdraw.content((10.5, 1.4), [reverse the appends: 2, 0, 1, 2, 3, 4], size: 6.5pt)
  cdraw.content((10.5, 0.3), [five edges, each spent exactly once], size: 6pt)
})

The walk 2, 0, 1, 2, 3, 4 is the pinned row, and the listings below
trace it in seven languages.

#listing("dsa/samples-c/src/Ch39/euler.c", first: 54, last: 99, caption: [c, parity and start, the stack loop taking the smallest unused edge, the reverse])
#listing("dsa/samples-go/ch39/euler.go", first: 44, last: 79, caption: [go, the paired arc ids, the sorted adjacency, the loop and reverse])
#listing("dsa/samples-java/src/Ch39/Euler.java", first: 55, last: 101, caption: [java, parity and start, the stack loop taking the smallest unused edge, the reverse])
#listing("dsa/samples/src/Ch39/Edges.cs", first: 99, last: 134, caption: [c\#, the odd count, the canonical start, the stuck-append loop])
#listing("dsa/samples-js/src/ch39-euler.mjs", first: 20, last: 50, caption: [javascript, parity, start, the pre-sorted neighbors, the reverse])
#listing("dsa/samples-py/src/Ch39/euler.py", first: 15, last: 46, caption: [python, the whole walk, sorted next-hops, append on stuck])
#listing("dsa/samples-lua/ch39_euler.lua", first: 22, last: 68, caption: [lua, parity and start, per-vertex pointers, the reverse])

Konigsberg refuses with all four lands odd. The triangle 0, 1, 2 plus
the tail 2 to 3, 3 to 4 has odd vertices 2 and 4, and the canonical
walk reads 2, 0, 1, 2, 3, 4. The bare triangle closes the circuit 0,
1, 2, 0 from vertex 0. The edges: a lone vertex with no edges walks
itself as the single vertex 0, parallel edges make a two-cycle
circuit, and an isolated vertex stays out of the walk entirely.

#diagram([the konigsberg graph with its four odd lands beside the triangle-plus-tail walk numbered by step], length: 13pt, {
  // left: konigsberg, degrees 5 3 3 3
  let n = (x, y, k, d) => {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
    cdraw.content((x, y - 0.55), [deg #d], size: 6pt)
  }
  cdraw.line((1.6, 6.8), (4.0, 6.8), stroke: luma(150))
  cdraw.line((1.6, 6.8), (4.6, 5.0), stroke: luma(150))
  cdraw.line((1.6, 6.8), (2.4, 4.4), stroke: luma(150))
  cdraw.line((4.0, 6.8), (4.6, 5.0), stroke: luma(150))
  cdraw.line((4.0, 6.8), (2.4, 4.4), stroke: luma(150))
  cdraw.line((4.6, 5.0), (2.4, 4.4), stroke: luma(150))
  cdraw.content((2.8, 7.25), [2x], size: 6pt)
  cdraw.content((2.8, 5.35), [2x], size: 6pt)
  n(1.6, 6.8, [0], [5])
  n(4.0, 6.8, [1], [3])
  n(4.6, 5.0, [2], [3])
  n(2.4, 4.4, [3], [3])
  cdraw.content((3.1, 3.2), [four odd lands, no walk], size: 6pt)
  // right: the walk 2, 0, 1, 2, 3, 4
  let pts = ((10.2, 6.6), (12.2, 7.4), (14.2, 6.6), (10.2, 6.6), (10.4, 4.9), (12.4, 4.2))
  for i in range(5) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(150), mark: (end: ">"))
  }
  let labels = ([1], [2], [3], [4], [5])
  let mid = ((11.2, 7.35), (13.2, 7.35), (12.3, 6.2), (10.1, 5.8), (11.5, 4.2))
  for (i, m) in mid.enumerate() {
    cdraw.content(m, labels.at(i), size: 6pt)
  }
  for p in ((10.2, 6.6), (12.2, 7.4), (14.2, 6.6), (10.4, 4.9), (12.4, 4.2)) {
    cdraw.circle(p, radius: 0.28, fill: luma(240), stroke: luma(120))
  }
  cdraw.content((10.2, 6.6), [2], size: 7pt)
  cdraw.content((12.2, 7.4), [0], size: 7pt)
  cdraw.content((14.2, 6.6), [1], size: 7pt)
  cdraw.content((10.4, 4.9), [3], size: 7pt)
  cdraw.content((12.4, 4.2), [4], size: 7pt)
  cdraw.content((12.2, 3.2), [walk 2, 0, 1, 2, 3, 4, ends odd], size: 6pt)
  cdraw.content((12.2, 2.3), [smallest next: canonical everywhere], size: 6pt)
})

The application is general technique, the mail-carrier and
circuit-tracing family, and the parity gate is always checked before
any walking starts.

== lowest common ancestors

Two solvers share one file. Binary lifting builds a parent table by
bfs, children visited in ascending index order so every derived array
is identical across languages, then doubles it: level k of the table
holds the 2^k-th ancestor, each level a plain lookup into the one
below. A query lifts the deeper node by the bits of the depth
difference, then walks both nodes down from the top level while their
ancestors differ, converging one step above the answer. Tarjan's
offline solver is the other half: a dfs with a dsu, where each vertex
merges into its parent on return and stamps the component's ancestor,
and a query whose other endpoint is already finished resolves at that
moment through find. Both assert all nine fixtures of the pinned
tree, and the rmq equivalence, euler tour plus the sparse table of
#xref-to("dsa", "ranges"), is the prose third way.

The dry run: the fixture is the pinned 9-vertex tree, asserted by
all seven suites; the walk uses the 0-based labels the suites store,
one below the book's reading.

+ The bfs visits 0 through 8 with children ascending: parent of 7 is
  4, depth of 7 and 8 is 3, the pinned structural row.
+ Level 0 of the table is the parent row 0, 0, 0, 1, 1, 2, 2, 4, 4
  with the root lifting to itself, and one doubling moves only 7 and
  8, to 1: level 1 reads 0, 0, 0, 0, 0, 0, 0, 1, 1.
+ The query (6, 9) of the fixture family is (5, 8) here at depths 2
  and 3: the deeper 8 aligns by one level-0 lift onto 4.
+ Now 4 and 5 sit level: the 2-jumps agree, both 0, and only the
  single steps differ, 1 against 2, so both lift to the root's
  children.
+ The meeting point is their parent: 0 here, vertex 1 in the book's
  labels, the pinned answer.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*action*], [*lands*]),
  [bfs], [children ascending from root 0], [parent 4 for 7, depths 3 and 3],
  [level 0], [parent row, root self-lift], [0, 0, 0, 1, 1, 2, 2, 4, 4],
  [level 1], [one doubling], [0, 0, 0, 0, 0, 0, 0, 1, 1],
  [align], [8 lifts one, depth 3 to 2], [8 lands on 4],
  [diverge], [2-jumps agree, singles differ], [1 against 2],
  [answer], [parent of the pair], [0, book vertex 1],
)

The meeting at 1 is one of nine rows both solvers pin, and the
listings below lift and walk offline in seven languages.

#listing("dsa/samples-c/src/Ch39/lca.c", first: 90, last: 137, caption: [c, the lift query, then the tarjan pass with its dsu])
#listing("dsa/samples-go/ch39/lca.go", first: 81, last: 105, caption: [go, the lift query, the tarjan twin lives below in the same file])
#listing("dsa/samples-java/src/Ch39/Lca.java", first: 85, last: 135, caption: [java, the lift query, then the tarjan pass with its dsu])
#listing("dsa/samples/src/Ch39/Paths2.cs", first: 49, last: 81, caption: [c\#, the doubling table above, the lift query, depths and split search])
#listing("dsa/samples-js/src/ch39-lca.mjs", first: 39, last: 67, caption: [javascript, the doubling build and the lift closure])
#listing("dsa/samples-py/src/Ch39/lca.py", first: 55, last: 76, caption: [python, the table, the lift, the split search])
#listing("dsa/samples-lua/ch39_lca.lua", first: 45, last: 76, caption: [lua, make lifting returns the query closure, doubling inside])

The pinned tree is 9 vertices rooted at 1 with edges 1-2 (5), 1-3 (7),
2-4 (3), 2-5 (9), 3-6 (2), 3-7 (8), 5-8 (4), 5-9 (6). The structural
family pins the bfs order 1 through 9, the parent of 8 as 5, and the
depth of 8 and 9 as 3. The query family, both solvers on every row:
(4,8) meets at 2, (6,9) at 1, (8,8) at itself, (4,1) at 1, (5,7) at 1,
(8,9) at 5, (4,6) at 1, (2,5) at 2, (7,9) at 1.

#diagram([the pinned 9-node tree with the 4 to 8 and 8 to 9 paths shaded up to their meeting points], length: 13pt, {
  let n = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.28, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  // tree: 1 root, 2 (1.9,5.6), 3 (6.1,5.6), 4 (0.9,3.9), 5 (3.1,3.9), 6 (5.1,3.9), 7 (7.1,3.9), 8 (2.1,2.2), 9 (4.1,2.2)
  let p = ("1": (4.0, 7.0), "2": (1.9, 5.6), "3": (6.1, 5.6), "4": (0.9, 3.9), "5": (3.1, 3.9), "6": (5.1, 3.9), "7": (7.1, 3.9), "8": (2.1, 2.2), "9": (4.1, 2.2))
  let e = (a, b, hot) => cdraw.line(p.at(a), p.at(b), stroke: if hot { luma(60) } else { luma(180) })
  e("1", "2", false)
  e("1", "3", false)
  e("2", "4", true)
  e("2", "5", true)
  e("3", "6", false)
  e("3", "7", false)
  e("5", "8", true)
  e("5", "9", true)
  for (k, (x, y)) in p {
    n(x, y, [#k])
  }
  cdraw.content((4.0, 7.7), [root 1], size: 6pt)
  cdraw.content((1.9, 6.3), [lca(4, 8) = 2], size: 6pt)
  cdraw.content((3.1, 1.4), [lca(8, 9) = 5], size: 6pt)
  cdraw.content((10.6, 6.4), [lifting: o(log n) per query], size: 6pt)
  cdraw.content((10.6, 5.4), [tarjan: offline, near linear], size: 6pt)
  cdraw.content((10.6, 4.4), [rmq on the euler tour, third way], size: 6pt)
  cdraw.content((10.6, 3.4), [children ascending keeps builds equal], size: 6pt)
})

The application is general technique, the meeting point under every
distance-on-tree question, and the speedup the next two sections
assume.

== heavy-light decomposition

Split the tree into vertical chains. One dfs computes subtree sizes
and marks each vertex's heavy child, the child with the largest
subtree, ties to the smaller index. A second walk assigns every vertex
a chain head and a base position, heavy child first, so each chain
occupies one contiguous run of the base array. Any root-to-vertex path
crosses at most one light edge per chain change, and the chains it
rides are contiguous, so a path query decomposes into O(log n)
contiguous base ranges, each answered by a segment tree, here the
point-update max shape of #xref-to("dsa", "ranges") rebuilt in file.
The walk goes head to head, the deeper head first, taking the max edge
weight over each crossed chain's run.

The dry run: the fixture is the same pinned tree in the 0-based
labels the suites store, asserted by all seven suites.

+ The size pass picks heavy children: 1 at the root with subtree 5
  against 2's 3, 4 at 1 with 3 against 3's 1, and the size-1 ties at
  2 and 4 resolve to the smaller index, 5 and 7.
+ The second walk goes heavy child first: the root chain 0, 1, 4, 7
  takes positions 0, 1, 2, 3, vertex 8 opens its own lane at 4, 3 at
  5, and the 2, 5 chain closes at 6, 7 with 6 at 8.
+ Heads read 0, 0, 2, 3, 0, 2, 6, 0, 8 and the base visit order 0,
  1, 4, 7, 8, 3, 2, 5, 6, both arrays pinned.
+ The query (7, 9) of the fixture family is (6, 8) here: it rides
  four runs, 8's own edge at 6, 6's at 8, 2's at 7, then the shared
  lane's max(5, 9).
+ The best over the runs is 9, and the walk never touches a fifth
  range.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*chain head*], [*vertices*], [*positions*], [*parent-edge weights on the lane*]),
  [0], [0, 1, 4, 7], [0, 1, 2, 3], [5, 9, 4],
  [8], [8], [4], [6],
  [3], [3], [5], [3],
  [2], [2, 5], [6, 7], [7, 2],
  [6], [6], [8], [8],
)

The 9 over four contiguous runs is the pinned row, and the listings
below decompose and query in seven languages.

#listing("dsa/samples-c/src/Ch39/hld.c", first: 151, last: 185, caption: [c, the segment query and the path walk, deeper head first])
#listing("dsa/samples-go/ch39/hld.go", first: 110, last: 160, caption: [go, the range max tree and the head-to-head walk])
#listing("dsa/samples-java/src/Ch39/Hld.java", first: 152, last: 186, caption: [java, the flat-tree range max, the path walk, deeper head first])
#listing("dsa/samples/src/Ch39/Paths2.cs", first: 238, last: 274, caption: [c\#, the range max and the path walk over chains])
#listing("dsa/samples-js/src/ch39-hld.mjs", first: 113, last: 131, caption: [javascript, the path walk over the private segment tree])
#listing("dsa/samples-py/src/Ch39/hld.py", first: 110, last: 135, caption: [python, the recursive range query and the walk])
#listing("dsa/samples-lua/ch39_hld.lua", first: 90, last: 117, caption: [lua, the range scan and the walk, -1 for no edges])

On the pinned tree of the ancestor section the decomposition arrays
pin exactly: heads 0, 0, 2, 3, 0, 2, 6, 0, 8 and positions 0, 1, 6, 5,
2, 7, 8, 3, 4 with base visit order 0, 1, 4, 7, 8, 3, 2, 5, 6, all
0-indexed. The nine path maxima over the weighted edges: (4,8) hits 9,
(6,9) hits 9, (8,8) reports -1 for no edges, (4,1) hits 5, (5,7) hits
9, (8,9) hits 6, (4,6) hits 7, (2,5) hits 9, (7,9) hits 9.

The star fixture is the honest one, corrected against its own first
draft: a center with leaves 1 through 5 has all leaf subtrees tied at
size 1, the tie rule gives the center's heavy child to leaf 1, so the
center and leaf 1 share a chain and the other four leaves hang as
singletons, heads 0, 0, 2, 3, 4, 5. Leaf-to-center queries cross two
chains except through leaf 1's shared edge, where they ride one.

#diagram([the pinned tree drawn as chains in vertical lanes, the 6 to 9 query shaded as it crosses three of them], length: 13pt, {
  // lanes: chain {0,1,4,7}, chain {8}, chain {2,5}, chain {6}, chain {3}
  let lane = (x, verts, hot) => {
    let y = 6.8
    for i in range(1, verts.len()) {
      cdraw.line((x, y - (i - 1) * 1.3 - 0.28), (x, y - i * 1.3 + 0.28), stroke: luma(180))
    }
    for (i, v) in verts.enumerate() {
      cdraw.circle((x, y - i * 1.3), radius: 0.28, fill: if hot { luma(215) } else { luma(240) }, stroke: luma(120))
      cdraw.content((x, y - i * 1.3), [#v], size: 7pt)
    }
  }
  lane(1.6, (0, 1, 4, 7), true)
  lane(3.4, (8,), true)
  lane(6.0, (2, 5), true)
  lane(8.0, (6,), true)
  lane(10.0, (3,), false)
  // light edges between lanes: 0-2, 1-3, 4-8, 2-6
  cdraw.line((1.6, 6.8), (6.0, 6.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.6, 5.5), (10.0, 6.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.6, 4.2), (3.4, 6.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((6.0, 6.8), (8.0, 6.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.6, 7.6), [head 0], size: 6pt)
  cdraw.content((3.4, 7.6), [head 8], size: 6pt)
  cdraw.content((6.0, 7.6), [head 2], size: 6pt)
  cdraw.content((8.0, 7.6), [head 6], size: 6pt)
  cdraw.content((10.0, 7.6), [head 3], size: 6pt)
  // query path: 6 -> 2 -> 0 -> 4 -> 8
  cdraw.line((8.0, 6.8), (6.0, 6.8), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.0, 6.8), (1.6, 6.8), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.6, 6.8), (1.6, 4.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.6, 4.2), (3.4, 6.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.6, 2.6), [query (6, 9): 6 to 2 to 0 to 4 to 8], size: 6pt)
  cdraw.content((6.6, 1.7), [three chains, three contiguous ranges], size: 6pt)
  cdraw.content((6.6, 0.8), [max edge on the path: 9], size: 6pt)
})

The application is general technique, path updates and queries on
trees, the machinery under every heaviest-edge and path-sum question.

== centroid decomposition

Peel the tree from the top. The centroid of a component is the vertex
whose largest remaining piece after removal is smallest, found by
walking from any vertex toward the subtree holding the majority and
stopping when no side does, ties resolved to the smaller index.
Removing it splits the component into pieces of at most half the size,
so the recursion is O(log n) deep and every original vertex hangs
under O(log n) centroids. Hop distances from each centroid over its
own component are bfs-precomputed at build, and the query machinery
follows: marking a vertex updates its distance at every centroid
ancestor, and the closest marked vertex to a query walks the same
ancestor chain, because the path from the query to any marked vertex
passes through their common centroid ancestor.

The dry run: the fixture is the same pinned tree in 0-based labels,
asserted by all seven suites.

+ The majority walk from 0 steps into child 1, whose subtree of 5
  outweighs the parent side's 9 - 5 = 4, and no piece of 1 beats
  half of 9: vertex 1 is the root centroid.
+ Removing 1 leaves {3}, {4, 7, 8}, and {0, 2, 5, 6}: the big piece
  centers on 2, whose largest side is one leaf, the middle on 4, and
  the lone 3 centers on itself, so the parent array reads 2, -1, 1,
  1, 1, 2, 2, 4, 4.
+ The script opens mark 5: vertex 3 and the mark meet only at the
  root centroid, dist 1 + 3 = 4, the row the section's figure draws.
+ Marking 7 too tightens it to dist 1 + 2 = 3, unmarking 7 restores
  the 4, and marking 0 answers query 8 at dist 2 + 1 = 3, the query
  two hops and the mark one hop off the centroid root.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*action*], [*ancestor chains*], [*answer*]),
  [mark 5], [3, 1 against 5, 2, 1], [1 + 3 = 4],
  [mark 7 too], [3, 1 against 7, 4, 1], [1 + 2 = 3],
  [unmark 7], [only 5 remains marked], [4],
  [mark 0, query 8], [8, 4, 1 against 0, 2, 1], [2 + 1 = 3],
)

The 4, 3, 4, 3 script is the pinned row, and the listings below
build and query in seven languages.

#listing("dsa/samples-c/src/Ch39/centroid.c", first: 124, last: 165, caption: [c, the recursive build with its bfs tables, the ancestor-walking query])
#listing("dsa/samples-go/ch39/centroid.go", first: 123, last: 162, caption: [go, mark relaxing ancestors, the query walking them])
#listing("dsa/samples-java/src/Ch39/Centroid.java", first: 124, last: 166, caption: [java, the recursive build with its bfs tables, the ancestor-walking query])
#listing("dsa/samples/src/Ch39/Centers.cs", first: 79, last: 93, caption: [c\#, mark, unmark, and closest by the ancestor walk, tables built above])
#listing("dsa/samples-js/src/ch39-centroid.mjs", first: 86, last: 114, caption: [javascript, mark and unmark keep sorted distance lists per centroid])
#listing("dsa/samples-py/src/Ch39/centroid.py", first: 102, last: 125, caption: [python, the owning-centroid join and the pinned query script])
#listing("dsa/samples-lua/ch39_centroid.lua", first: 83, last: 118, caption: [lua, mark, unmark, closest, distance counts per centroid])

On the pinned tree the centroid parents land 2, -1, 1, 1, 1, 2, 2, 4,
4 with root centroid 1, all 0-indexed, and the query script runs
verbatim: mark 5 and query 3 for 4, mark 7 and the same query drops to
3, unmark 7 and it returns to 4, mark 0 and query 8 for 3. A path
graph of five vertices centers on the exact middle with parents 1, 2,
-1, 2, 3, and a lone marked vertex queried at itself answers 0.

#diagram([the pinned tree, its centroid tree beside it, one query walking up the centroid ancestors with distances written], length: 13pt, {
  // left: the tree shape (same as lca)
  let p = ("0": (1.8, 6.8), "1": (1.0, 5.3), "2": (2.8, 5.3), "3": (0.4, 3.8), "4": (1.6, 3.8), "5": (2.4, 3.8), "6": (3.4, 3.8), "7": (1.0, 2.3), "8": (2.2, 2.3))
  let e = (a, b) => cdraw.line(p.at(a), p.at(b), stroke: luma(180))
  e("0", "1")
  e("0", "2")
  e("1", "3")
  e("1", "4")
  e("2", "5")
  e("2", "6")
  e("4", "7")
  e("4", "8")
  for (k, (x, y)) in p {
    let hot = k == "1"
    cdraw.circle((x, y), radius: 0.26, fill: if hot { luma(215) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), [#k], size: 6.5pt)
  }
  cdraw.content((1.8, 7.5), [the tree, centroid root 1], size: 6pt)
  // right: centroid tree, parent links up
  let q = ("1": (9.6, 7.0), "2": (7.8, 5.4), "4": (11.4, 5.4), "0": (6.6, 3.8), "5": (8.6, 3.8), "6": (10.2, 3.8), "3": (12.6, 3.8), "7": (10.8, 2.2), "8": (12.6, 2.2))
  let ce = (a, b) => cdraw.line(q.at(a), q.at(b), stroke: luma(180))
  ce("1", "2")
  ce("1", "4")
  ce("2", "0")
  ce("2", "5")
  ce("2", "6")
  ce("4", "3")
  ce("4", "7")
  ce("4", "8")
  for (k, (x, y)) in q {
    cdraw.circle((x, y), radius: 0.26, fill: if k == "1" { luma(215) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), [#k], size: 6.5pt)
  }
  cdraw.content((9.6, 7.7), [the centroid tree], size: 6pt)
  // the query walk: 3's ancestors are 3, 4, 1, mark 5 lives under 5, 2, 1
  cdraw.content((16.6, 6.6), [query 3: ancestors 3, 4, 1], size: 6pt)
  cdraw.content((16.6, 5.6), [mark 5: ancestors 5, 2, 1], size: 6pt)
  cdraw.content((16.6, 4.6), [common centroid 1 only], size: 6pt)
  cdraw.content((16.6, 3.6), [dist(3, 1) + dist(5, 1) = 1 + 3], size: 6pt)
  cdraw.content((16.6, 2.6), [answer 4, through the root centroid], size: 6pt)
})

The application is general technique, closest-marked-vertex and
path-counting questions on trees at O(n log n) build and O(log n) per
query.

== functional graphs

Every vertex has exactly one successor, so the graph is a set of rings
with trees hanging off them, and the 2019 problem H question over it,
for every station, how many distinct stations' journeys of at most k
legs reach it, splits along that seam. The indegree peel, leaves
first, children before parents, splits ring nodes from tree nodes.
Tree nodes answer bottom-up in peel order: each hanging tree counts
its own subtree starts within k legs, exact-distance bookkeeping
folding the overcount out. Ring nodes share a difference array: every
node whose ring entry is reached within k casts an arc of length
min(k - d + 1, ring length) starting at its entry, wraps split into a
head and tail contribution, and one prefix sum turns the arcs into
per-station counts. The walk is deterministic, so counting distinct
stations is counting starts whose first arrival lands inside the
budget, and a brute that walks k plus 1 steps per start cross-checks
every fixture.

The dry run: the fixture is the 2019 problem H sample, successors 2,
3, 2, 5, 4, 5, 6 in the statement's reading with k = 2, asserted by
all seven suites against a walking brute.

+ The indegree peel splits two rings, 1 with 2 and 3 with 4: station
  0 hangs one leg off 1, and the chain 6, 5 enters the second ring
  at 4.
+ A ring node's budget covers its whole pair, the arc length min(2 +
  1, 2) = 2, so the ring's own starts add 2 to both stations of each
  pair.
+ The trees fold in bottom-up: 0's two legs reach 1 and 2, lifting
  that pair to 2 + 1 = 3, while 5 adds itself, 3, and 4, and 6 adds
  itself, 5, and 4.
+ Station 4 collects the most, ring 2 plus 5 plus 6 = 4, and station
  6 keeps only itself at 1.

#table(
  columns: (auto, auto),
  inset: 4pt,
  table.header([*start*], [*stations reached within 2 legs*]),
  [0], [0, 1, 2],
  [1], [1, 2],
  [2], [1, 2],
  [3], [3, 4],
  [4], [3, 4],
  [5], [3, 4, 5],
  [6], [4, 5, 6],
)

Counting the starts per station reads the answer row 1, 3, 3, 3, 4,
2, 1, and the listings below peel and count in seven languages.

#listing("dsa/samples-c/src/Ch39/functional.c", first: 96, last: 136, caption: [c, the ring walk, the difference-array arcs, the prefix fold])
#listing("dsa/samples-go/ch39/functional.go", first: 58, last: 84, caption: [go, the ring collected in walk order, addarc, the ring's own arcs])
#listing("dsa/samples-java/src/Ch39/Functional.java", first: 76, last: 130, caption: [java, the ring walk, the difference-array arcs, the doubled prefix fold])
#listing("dsa/samples/src/Ch39/Centers.cs", first: 170, last: 216, caption: [c\#, the cast helper with its wraps, the entry walk, the fold])
#listing("dsa/samples-js/src/ch39-functional.mjs", first: 138, last: 163, caption: [javascript, the ring arcs and the doubled prefix, the tree part above])
#listing("dsa/samples-py/src/Ch39/functional.py", first: 66, last: 103, caption: [python, the ring walk, split arcs, the running sum])
#listing("dsa/samples-lua/ch39_functional.lua", first: 72, last: 116, caption: [lua, addarc over 2l slots, the doubled prefix, flat whole-ring arcs])

The 2019 problem H sample is the anchor: successors 2, 3, 2, 5, 4, 5,
6 in the statement's 1-indexed reading, k = 2, answers 1, 3, 3, 3, 4,
2, 1, exactly the spec's crafted case. A pure ring of 3 with k = 1
counts 2 for every station. A chain into a ring reads 1, 3, 2 at k = 1
and 1, 3, 3 at k = 2, the ring saturating as the budget grows.

#diagram([the 2019 problem H fixture as two rings with trees hanging, every station labeled with its answer, one arc drawn thick on a ring], length: 13pt, {
  let n = (x, y, k, ans) => {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
    cdraw.content((x, y - 0.55), [#ans], size: 6pt)
  }
  // ring A: 1 <-> 2 (0-indexed), tree 0 -> 1
  cdraw.circle((4.2, 6.2), radius: 1.35, fill: luma(238), stroke: luma(190))
  cdraw.line((3.6, 6.7), (4.8, 6.7), stroke: luma(140), mark: (end: ">"))
  cdraw.line((4.8, 5.7), (3.6, 5.7), stroke: luma(60), mark: (end: ">"))
  n(3.4, 6.7, [1], [3])
  n(4.8, 6.7, [2], [3])
  cdraw.line((3.5, 4.5), (3.4, 6.4), stroke: luma(140), mark: (end: ">"))
  n(3.5, 4.2, [0], [1])
  // ring B: 3 <-> 4, trees 5 -> 4, 6 -> 5
  cdraw.circle((10.4, 6.2), radius: 1.35, fill: luma(238), stroke: luma(190))
  cdraw.line((9.6, 6.7), (10.8, 6.7), stroke: luma(140), mark: (end: ">"))
  cdraw.line((10.8, 5.7), (9.6, 5.7), stroke: luma(140), mark: (end: ">"))
  n(9.6, 6.7, [3], [3])
  n(10.8, 6.7, [4], [4])
  cdraw.line((11.2, 4.5), (10.9, 6.4), stroke: luma(140), mark: (end: ">"))
  n(11.4, 4.2, [5], [2])
  cdraw.line((11.4, 3.9), (11.4, 3.1), stroke: luma(140), mark: (end: ">"))
  n(11.4, 2.8, [6], [1])
  cdraw.content((4.2, 3.3), [k = 2: the thick arc adds +1 around], size: 6pt)
  cdraw.content((4.2, 2.4), [trees count subtree starts within k], size: 6pt)
  cdraw.content((4.2, 1.5), [answers 1, 3, 3, 3, 4, 2, 1], size: 6pt)
})

The application is icpc world finals 2019 problem H (book 10, chapter
10), hobson's trains, exactly this structure at n of 5e5 with
k-th-ancestor counts and ring difference arrays, and the chapter
sample is the contest's own crafted case.

== the 2-core

The maximal subgraph of minimum degree 2 is one queue away. Every
vertex of degree at most 1 leaves, its removal decrements each
neighbor, and anything that drops to degree 1 joins the queue, the
same degree-array idiom the graph chapter of #xref-to("dsa", "graphs")
uses for component counting. What survives the peel is the 2-core, and
the edges between a survivor and a peeled vertex form the boundary,
the exact seam the dead-end sign question cares about.

The dry run: the fixture is the 2019 problem E sample graph, edges
1-2, 2-3, 3-1, 3-4, 4-5, 6-7 in the statement's reading, asserted by
all seven suites.

+ Degrees start 3, 2, 2, 2, 1, 1, 1 over the 0-based labels:
  vertices 4, 5, 6 open the queue.
+ Peeling 4 decrements 3 from 2 to 1, and 3 joins the queue; 5 and 6
  peel each other down to 0.
+ Peeling 3 decrements 0 from 3 to 2: nothing drops back to 1, and
  the queue empties.
+ The survivors are 0, 1, 2, the triangle, and the one edge from a
  survivor to a peeled vertex is (0, 3), the boundary.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*queue after*], [*degrees after*]),
  [open], [4, 5, 6], [3, 2, 2, 2, 1, 1, 1],
  [peel 4], [5, 6, 3], [3, 2, 2, 1, 0, 1, 1],
  [peel 5, 6], [3], [3, 2, 2, 1, 0, 0, 0],
  [peel 3], [empty], [2, 2, 2, 0, 0, 0, 0],
  [survivors], [none left], [core 0, 1, 2, boundary (0, 3)],
)

The core 0, 1, 2 with the single boundary edge (0, 3) is the pinned
pair, and the listings below peel in seven languages.

#listing("dsa/samples-c/src/Ch39/twocore.c", first: 51, last: 85, caption: [c, the peel queue, the survivor collection, the boundary edges])
#listing("dsa/samples-go/ch39/twocore.go", first: 17, last: 60, caption: [go, the queue, the decrement, the boundary collection and sort])
#listing("dsa/samples-java/src/Ch39/Twocore.java", first: 52, last: 83, caption: [java, the peel queue, the survivor collection, the boundary edges])
#listing("dsa/samples/src/Ch39/Centers.cs", first: 226, last: 257, caption: [c\#, the same peel, core and boundary as linq reads])
#listing("dsa/samples-js/src/ch39-twocore.mjs", first: 16, last: 38, caption: [javascript, the peel and both output lists])
#listing("dsa/samples-py/src/Ch39/twocore.py", first: 16, last: 40, caption: [python, the whole peel with the boundary read])
#listing("dsa/samples-lua/ch39_twocore.lua", first: 20, last: 55, caption: [lua, the queue peel in 1-based tables])

The 2019 problem E sample graph, edges 1-2, 2-3, 3-1, 3-4, 4-5, 6-7 in
its 1-indexed reading, keeps the core {0, 1, 2} with boundary edge
(0, 3), and the {5, 6} component peels entirely, its leaf entrances
keeping signs on both ends, the redundancy rule that problem's
statement adds on top. A bare 4-cycle keeps everyone with no boundary,
a path peels to nothing, a single edge peels to nothing, isolated
vertices peel immediately, and parallel edges hold degree 2 on both
sides and survive.

#diagram([the 2019 problem E fixture with peeled vertices hollow, the core shaded, the boundary arrow at vertex 3], length: 13pt, {
  // core triangle 0-1-2, 3 boundary, 4 peeled, 5-6 peeled pair
  cdraw.circle((3.0, 6.2), radius: 1.4, fill: luma(238), stroke: luma(190))
  let solid = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.28, fill: luma(250), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  let hollow = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.28, fill: none, stroke: (paint: luma(120), dash: "dashed"))
    cdraw.content((x, y), k, size: 7pt)
  }
  cdraw.line((2.2, 7.0), (3.8, 7.0), stroke: luma(150))
  cdraw.line((3.8, 7.0), (3.0, 5.4), stroke: luma(150))
  cdraw.line((3.0, 5.4), (2.2, 7.0), stroke: luma(150))
  cdraw.line((3.0, 5.4), (5.2, 5.0), stroke: luma(60))
  cdraw.line((5.2, 5.0), (6.8, 4.4), stroke: luma(150))
  cdraw.line((9.6, 5.6), (11.0, 5.6), stroke: luma(150))
  solid(2.2, 7.0, [0])
  solid(3.8, 7.0, [1])
  solid(3.0, 5.4, [2])
  hollow(5.2, 5.0, [3])
  hollow(6.8, 4.4, [4])
  hollow(9.6, 5.6, [5])
  hollow(11.0, 5.6, [6])
  cdraw.content((4.1, 4.3), [boundary (0, 3)], size: 6pt)
  cdraw.content((3.0, 3.4), [hollow: peeled, shaded: the 2-core], size: 6pt)
  cdraw.content((3.0, 2.5), [the {5, 6} pair peels entirely], size: 6pt)
  cdraw.content((3.0, 1.6), [one queue, degree drops drive it], size: 6pt)
})

The application is icpc world finals 2019 problem E (book 10, chapter
10), dead-end detector, this peel plus a sign-placement rule on the
boundary edges, and the fixture above is its sample graph.

== prufer codes and the second-best mst

A labeled tree of n vertices compresses to n - 2 numbers: repeatedly
remove the smallest-labeled leaf and record its unique neighbor. The
decode inverts it by degree bookkeeping, each code entry lifts one
degree, the smallest current leaf pairs with it, and the last two
leaves close the tree. Prufer labels are 1-indexed by convention and
the lua port asserts the list unchanged. The same file answers the
second-best spanning tree: kruskal from #xref-to("dsa", "mstflows")
builds the base tree, then every non-tree edge scores a swap, its
weight minus the heaviest edge on the tree path between its endpoints,
and the best positive swap over the minimum total is the runner-up.
The path maximum is an honest O(n) parent walk per edge here, with the
lifting speedup of the ancestor section above cross-named for the
logarithmic form.

The dry run: the fixtures are the 6-vertex tree and the 7-edge
second-best graph, asserted by all seven suites.

+ The encode strips smallest leaves: 1 goes recording 3, 2 goes
  recording 3, 3 goes recording 4, 5 goes recording 4, and 4, 6
  close, the pinned code 3, 3, 4, 4 that decode rebuilds exactly.
+ Kruskal lines the 7 edges up by weight, 1, 1, 2, 2, 3, 4, 5: the
  first four unions span all 5 vertices at 1 + 1 + 2 + 2 = 6, the
  mst.
+ The three non-tree edges each score a swap against the heaviest
  edge on their tree path: (3,4) at 3 meets a 2, (4,5) at 4 the same
  2, and (5,1) at 5 the same 2 again.
+ The cheapest wins: adding (3,4) closes the cycle through 3, 2, 4
  and drops the path's heaviest edge (2,3), landing the runner-up at
  6 + 1 = 7.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*candidate*], [*heaviest on tree path*], [*gain*], [*total*]),
  [mst picks], [(1,2), (2,4), (2,3), (3,5)], [], [6],
  [(3,4) at 3], [(2,3) at 2], [3 - 2 = 1], [7],
  [(4,5) at 4], [(2,3) at 2], [4 - 2 = 2], [8],
  [(5,1) at 5], [(2,3) or (3,5) at 2], [5 - 2 = 3], [9],
)

The mst 6 and the runner-up 7 by the (2,3) for (3,4) swap are the
pinned pair, and the listings below encode, decode, and scan in seven
languages.

#listing("dsa/samples-c/src/Ch39/prufer.c", first: 30, last: 61, caption: [c, the encode loop removing the smallest leaf, decode below])
#listing("dsa/samples-go/ch39/prufer.go", first: 23, last: 59, caption: [go, the leaf pick and removal, the neighbor recorded 1-indexed])
#listing("dsa/samples-java/src/Ch39/Prufer.java", first: 26, last: 55, caption: [java, the encode loop removing the smallest leaf over an inline adjacency matrix, decode below])
#listing("dsa/samples/src/Ch39/Prufer.cs", first: 11, last: 40, caption: [c\#, the priority-queue encode, the degree decode below])
#listing("dsa/samples-js/src/ch39-prufer.mjs", first: 35, last: 62, caption: [javascript, the encode loop over adjacency sets])
#listing("dsa/samples-py/src/Ch39/prufer.py", first: 18, last: 40, caption: [python, the heap-driven encode, the code 1-indexed out])
#listing("dsa/samples-lua/ch39_prufer.lua", first: 26, last: 47, caption: [lua, the scan for the smallest leaf, the removal])

The tree with edges 1-3, 2-3, 3-4, 4-5, 4-6 encodes to 3, 3, 4, 4 and
decodes back identically. Five seeded trees from the pinned lcg
round-trip, the first a star on 5 vertices coding 1, 1, 1. The java
copy of the seeded family draws its trees through
Integer.remainderUnsigned and hands pruferEncode an
Arrays.copyOf(edges, vn - 1) slice, because its generator buffer keeps
all 8 rows whatever vn the lcg picks. The
second-best fixtures: the 7-edge graph over 5 vertices has its mst at
weight 6 on edges (1,2), (2,3), (2,4), (3,5), and the runner-up at 7
by swapping (2,3) for (3,4), both matched against spanning-tree
enumeration. The complete graph on 4 vertices with weights 1 through 6
around runs mst 6 and second-best 8.

#diagram([the 6-vertex tree with the removal order numbered on leaves, the code 3, 3, 4, 4 written below], length: 13pt, {
  let n = (x, y, k, ord: none) => {
    cdraw.circle((x, y), radius: 0.28, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
    if ord != none {
      cdraw.content((x, y + 0.55), ord, size: 6pt)
    }
  }
  // tree: 1-3, 2-3, 3-4, 4-5, 4-6
  cdraw.line((1.6, 6.6), (3.4, 6.6), stroke: luma(170))
  cdraw.line((5.2, 6.6), (3.4, 6.6), stroke: luma(170))
  cdraw.line((3.4, 6.6), (5.2, 4.8), stroke: luma(170))
  cdraw.line((5.2, 4.8), (4.4, 3.2), stroke: luma(170))
  cdraw.line((5.2, 4.8), (6.2, 3.2), stroke: luma(170))
  n(1.6, 6.6, [1], ord: [1st])
  n(3.4, 6.6, [3])
  n(5.2, 6.6, [2], ord: [2nd])
  n(5.2, 4.8, [4], ord: [3rd])
  n(4.4, 3.2, [5], ord: [4th])
  n(6.2, 3.2, [6])
  cdraw.content((3.9, 2.0), [code: 3, 3, 4, 4], size: 6.5pt)
  cdraw.content((3.9, 1.1), [remove 1 record 3, remove 2 record 3, remove 3 record 4, remove 5 record 4], size: 6pt)
  cdraw.content((11.8, 6.2), [n - 2 numbers, bijection], size: 6pt)
  cdraw.content((11.8, 5.2), [decode: degrees from the code], size: 6pt)
  cdraw.content((11.8, 4.2), [second-best: one swap over the mst], size: 6pt)
  cdraw.content((11.8, 3.2), [swap gain = w(e) - max on path], size: 6pt)
  cdraw.content((11.8, 2.2), [the honest walk is o(n) per edge], size: 6pt)
})

The application is general technique, the counting license for labeled
trees and the runner-up question whenever the mst itself is not
enough.

== strong orientation

An undirected graph admits a strongly connected orientation, an
assignment of directions making every vertex reachable from every
other, exactly when it is connected and bridgeless. That is robbins'
theorem, and both halves read off the machinery above: connectivity is
the baseline walk of #xref-to("dsa", "graphs"), and bridgeless is the
disc and low classification of the bridges section, since a bridge in
the underlying graph is a one-way bottleneck under any assignment of
directions, whatever crosses it can never come back. When the graph
qualifies, the constructive rule is a dfs orientation: every tree edge
points away from the root along the dfs, every back edge points toward
the ancestor, and every cycle of the graph becomes a directed cycle,
which is exactly the local strong connectivity the flood needs. No
samples ship for this section, the decision is two existing tools
composed, and the theorem is the prose payoff. Icpc world finals 2022
problem R (book 10, chapter 11) is the reachability kin, its
2-edge-connected components being the maximal pieces that qualify.

The dry run: no suite carries this section, the numbers are
hand-derived over the shared-vertex triangles of the bridges
fixture.

+ The gate reads twice: the triangles form one component and carry
  zero bridges, so robbins promises a strong orientation.
+ A dfs from 0 orients the tree edges away, 0 to 1, 1 to 2 and 0 to
  3, 3 to 4, and the closers 2 to 0 and 4 to 0 point back at the
  ancestor.
+ Each triangle is now a directed cycle, 0, 1, 2 and 0, 3, 4,
  sharing vertex 0: every vertex rides its own cycle to 0, then the
  other cycle anywhere.
+ The bridged cousin of the same fixture fails the second read:
  whichever way the bridge 2 to 3 points, the far side can never
  route anything back, so no orientation exists at all.

#diagram([the shared-vertex triangles oriented by the dfs rule, two directed cycles welded at vertex 0], length: 13pt, {
  let n = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.28, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  let o = (5.2, 6.6)
  let a1 = (2.4, 7.3)
  let a2 = (2.4, 5.9)
  let b1 = (8.0, 7.3)
  let b2 = (8.0, 5.9)
  cdraw.line(o, a1, stroke: luma(140), mark: (end: ">"))
  cdraw.line(a1, a2, stroke: luma(140), mark: (end: ">"))
  cdraw.line(a2, o, stroke: luma(140), mark: (end: ">"))
  cdraw.line(o, b1, stroke: luma(140), mark: (end: ">"))
  cdraw.line(b1, b2, stroke: luma(140), mark: (end: ">"))
  cdraw.line(b2, o, stroke: luma(140), mark: (end: ">"))
  n(5.2, 6.6, [0])
  n(2.4, 7.3, [1])
  n(2.4, 5.9, [2])
  n(8.0, 7.3, [3])
  n(8.0, 5.9, [4])
  cdraw.content((2.4, 8.0), [cycle 0, 1, 2], size: 6pt)
  cdraw.content((8.0, 8.0), [cycle 0, 3, 4], size: 6pt)
  cdraw.content((5.2, 4.7), [tree edges away, back edges at the ancestor], size: 6pt)
  cdraw.content((5.2, 3.8), [shared 0 welds the two cycles], size: 6pt)
  cdraw.content((5.2, 2.9), [a bridge refuses every direction], size: 6pt)
})

Both reads cost one existing pass each, and the figure below draws
the orientable and the bridged side by side.

#diagram([a bridgeless graph oriented by the dfs rule, beside the same graph with its bridge cut and no strong orientation possible], length: 13pt, {
  // left: a square with one diagonal, oriented strongly
  let a = (1.4, 6.8)
  let b = (3.8, 6.8)
  let c = (3.8, 4.8)
  let d = (1.4, 4.8)
  cdraw.line(a, b, stroke: luma(140), mark: (end: ">"))
  cdraw.line(b, c, stroke: luma(140), mark: (end: ">"))
  cdraw.line(c, d, stroke: luma(140), mark: (end: ">"))
  cdraw.line(d, a, stroke: luma(140), mark: (end: ">"))
  cdraw.line(a, c, stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  for (p, k) in ((a, [0]), (b, [1]), (c, [2]), (d, [3])) {
    cdraw.circle(p, radius: 0.26, fill: luma(240), stroke: luma(120))
    cdraw.content(p, k, size: 7pt)
  }
  cdraw.content((2.6, 7.7), [bridgeless: strongly orientable], size: 6pt)
  cdraw.content((2.6, 3.9), [tree edges down, back edges up], size: 6pt)
  // right: the same graph with the diagonal as a bridge
  let e = (9.0, 6.8)
  let f = (11.4, 6.8)
  let g = (11.4, 4.8)
  let h = (9.0, 4.8)
  cdraw.line(e, f, stroke: luma(140), mark: (end: ">"))
  cdraw.line(f, g, stroke: luma(140), mark: (end: ">"))
  cdraw.line(g, h, stroke: luma(140), mark: (end: ">"))
  cdraw.line(h, e, stroke: luma(140), mark: (end: ">"))
  cdraw.line(e, g, stroke: luma(60))
  cdraw.content((10.2, 5.8), [bridge], size: 6pt)
  cdraw.line((8.3, 4.4), (12.1, 7.2), stroke: (paint: luma(100), dash: "dashed"))
  for (p, k) in ((e, [0]), (f, [1]), (g, [2]), (h, [3])) {
    cdraw.circle(p, radius: 0.26, fill: luma(240), stroke: luma(120))
    cdraw.content(p, k, size: 7pt)
  }
  cdraw.content((10.2, 7.7), [the diagonal bridges the square], size: 6pt)
  cdraw.content((10.2, 3.9), [cut it: both halves orient, joined never], size: 6pt)
  cdraw.content((10.2, 3.0), [whatever crosses cannot return], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's ten sample files per language, c\# spread over its five
family files, go test files excluded:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [1563], [static arc arrays, per-file mains], [the shared 9-node tree inlined per file, 1-based fixtures translated at the boundary],
  [go], [1134], [slices, sort], [the treeadj helper shared across lca, hld, centroid, functional ports fully iterative],
  [java], [1607], [jdk 27 stdlib], [the frame-stack dfs ports verbatim from c, the prufer lcg draws through Integer.remainderUnsigned and trims its 8-row buffer by Arrays.copyOf, no stdlib sort in the chapter],
  [c\#], [815], [lists, linq, tuples], [five family files, the 2-sat solver reuses the scc raw pass, priority queues in prufer],
  [javascript], [837], [classes with private fields], [1-indexed public faces over 0-based internals in lca and hld, the fenwick inside functional],
  [python], [956], [stdlib only, inline asserts], [brute twins per section, recursion where it reads best, iterative dfs throughout],
  [lua], [1245], [tables, 1-based inside], [0-based reported positions, integer division for the lcg, check tables for run.lua],
)

sources: cp-algorithms, "Strongly Connected Components and Condensation
Graph", cp-algorithms.com/graph/strongly-connected-components.html,
"2-SAT", cp-algorithms.com/graph/2SAT.html, "Finding Bridges in
O(N+M)", cp-algorithms.com/graph/bridge-searching.html, "Finding
Articulation Points in O(N+M)", cp-algorithms.com/graph/cutpoints.html,
"Finding Bridges Online", cp-algorithms.com/graph/bridge-searching-online.html,
for the prose note on the link-cut variant, "Eulerian Path",
cp-algorithms.com/graph/euler_path.html, "Lowest Common Ancestor",
cp-algorithms.com/graph/lca.html, "Lowest Common Ancestor - Binary
Lifting", cp-algorithms.com/graph/lca_binary_lifting.html, "Lowest
Common Ancestor - Tarjan's off-line algorithm",
cp-algorithms.com/graph/lca_tarjan.html, "Solve RMQ by finding LCA",
cp-algorithms.com/graph/rmq_linear.html, for the prose equivalence,
"Heavy-light decomposition", cp-algorithms.com/graph/hld.html,
"Centroid decomposition", cp-algorithms.com/graph/centroid_decomposition.html,
"Prüfer code", cp-algorithms.com/graph/pruefer_code.html, "Second best
Minimum Spanning Tree - Using Kruskal and Lowest Common Ancestor",
cp-algorithms.com/graph/second_best_mst.html, and "Strong
Orientation", cp-algorithms.com/graph/strong-orientation.html, all
accessed 2026-09-20, cc by-sa 4.0, our own words and code throughout.
Functional graphs and the 2-core have no dedicated cp-algorithms
article, both taught as general technique with the icpc world finals
2019 problem H and problem E solutions (book 10, chapter 10) as the
application sources, alongside icpc world finals 2022 problem R (book
9, chapter 11). Sample behavior verified by the seven suite gates scoped
to chapter 39: c 10 files and 208 checks, go 32 test functions, java 10
files and 210 checks under run-java-samples, c\# 32 facts,
javascript 33 tests and 79 asserts across its two split files, python
10 files and 80 asserts, lua 33 checks, zero skipped.
