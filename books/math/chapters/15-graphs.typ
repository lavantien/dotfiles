#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= graphs and order theory

Graphs are the bare structure of things and their connections, and this
chapter works the theory a programmer actually leans on: the models and
degree identities, walks and connectivity, the tree characterization,
partial orders with hasse diagrams and topological sort, lattices, and
equivalence relations as partitions. Every behavioral claim below is one
of the 60 checks in the 4 samples of chapter 15 or a sentence quoted from
a canonical source fetched 2026-09-21. Where the sibling treatment is
algorithmic, bfs, dfs, shortest paths, flows in #xref-to("dsa",
"graphs"), #xref-to("dsa", "shortestpaths"), and #xref-to("dsa",
"mstflows"), this chapter keeps to structure and proof, and cross
references the algorithm when it appears.

== graph models and degree sums

A graph $G = (V, E)$ is a vertex set and an edge set of unordered pairs,
and the first programming decision is the encoding. The adjacency matrix
holds an $n times n$ grid with $A_(i j) = 1$ exactly when $i j in E$, an
edge test in constant time at $n^2$ cells of storage. The adjacency list
holds one neighbor set per vertex, $sum_v deg(v)$ slots in total, and a
row bitmask is the same list as one machine word per vertex when $n <=
64$. The degree $deg(v)$ is the number of edge ends at $v$, and counting
edge ends two ways gives the handshake lemma:

$ sum_(v in V) deg(v) = 2|E|$

Each edge contributes one end at each of its two vertices, so the degree
column of any real graph adds up to an even number, twice the edge
count. The consequence worth quoting: a finite graph has an even number
of odd-degree vertices, since the sum is even. For a digraph the same
argument split by direction gives $sum_v deg^+ (v) = sum_v deg^- (v) =
|E|$, out-degrees and in-degrees both summing to the arc count
(en.wikipedia.org/wiki/Handshaking_lemma, fetched 2026-09-21).

The dry run: G1 is the undirected fixture of this chapter, 6 vertices
and 8 edges, (0,1), (0,2), (1,2), (1,3), (2,4), (3,4), (3,5), (4,5).

+ Degrees read off the edges: $d(0) = 2$, $d(1) = 3$, $d(2) = 3$,
  $d(3) = 3$, $d(4) = 3$, $d(5) = 2$, so the vector is (2,3,3,3,3,2).
+ The handshake: $2 + 3 + 3 + 3 + 3 + 2 = 16 = 2 dot 8$. Four vertices
  carry odd degree 3, an even count, as the corollary demands.
+ The matrix costs 36 cells, the bitmask 6 words holding 16 set bits
  between them. That 16 is $2|E|$ again, the lemma as a storage number.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*vertex*], [*neighbors*], [*degree*], [*bitmask*]),
  [0], [{1, 2}], [2], [0x06],
  [1], [{0, 2, 3}], [3], [0x0D],
  [2], [{0, 1, 4}], [3], [0x13],
  [3], [{1, 4, 5}], [3], [0x32],
  [4], [{2, 3, 5}], [3], [0x2C],
  [5], [{3, 4}], [2], [0x18],
)

#listing("math/samples/src/Ch15/models.c", first: 65, last: 105, caption: [models.c builds the edge list, the matrix, and the bitmask independently and checks them against the degree vector])

The matrix also counts walks. The entry $(A^k)_(i j)$ of the $k$-th
matrix power is the number of walks of length $k$ from $i$ to $j$,
because a $k$-walk chooses a neighbor per step and the product sums
exactly those choices. Two entries carry the chapter: the diagonal of
$A^2$ is the degree vector, a walk out and back per edge end, and the
trace of $A^3$ counts closed 3-walks, six per triangle, two rotations
times three starting vertices. On G1 that gives $"tr"(A^3) =
12$ and $12\/6 = 2$ triangles, 012 and 345, with the total of 2-walks
$44 = sum_v deg(v)^2 = 4 + 9 + 9 + 9 + 9 + 4$.

#diagram([G1 with its degrees and adjacency matrix, 36 cells holding 8 edges], length: 13pt, {
  let node(x, y, t, d) = {
    cdraw.circle((x, y), radius: 0.34, fill: luma(235), stroke: luma(60))
    cdraw.content((x, y), t, size: 6pt)
    cdraw.content((x, y - 0.62), [d = #d], size: 6pt, fill: luma(100))
  }
  let e = ((1.2, 4), (3.2, 5.6), (3.2, 2.4), (6.2, 5.6), (6.2, 2.4), (8.4, 4))
  let el = ((0, 1), (0, 2), (1, 2), (1, 3), (2, 4), (3, 4), (3, 5), (4, 5))
  for p in el { cdraw.line(e.at(p.at(0)), e.at(p.at(1)), stroke: luma(140)) }
  let dd = (2, 3, 3, 3, 3, 2)
  for i in range(6) { node(e.at(i).at(0), e.at(i).at(1), [#i], dd.at(i)) }
  // adjacency matrix, filled cell per edge
  let m = ((0, 1, 1, 0, 0, 0), (1, 0, 1, 1, 0, 0), (1, 1, 0, 0, 1, 0),
           (0, 1, 0, 0, 1, 1), (0, 0, 1, 1, 0, 1), (0, 0, 0, 1, 1, 0))
  let ox = 10.6
  let oy = 5.8
  let cs = 0.52
  for i in range(6) {
    cdraw.content((ox - 0.4, oy - i * cs - cs / 2), [#i], size: 5.5pt, fill: luma(100))
    for j in range(6) {
      cdraw.rect((ox + j * cs, oy - i * cs - cs), (ox + j * cs + cs, oy - i * cs),
        fill: if m.at(i).at(j) == 1 { luma(205) } else { luma(245) }, stroke: luma(140))
    }
  }
  for j in range(6) { cdraw.content((ox + j * cs + cs / 2, oy + 0.3), [#j], size: 5.5pt, fill: luma(100)) }
  cdraw.content((ox + 1.6, oy + 0.9), [adjacency matrix], size: 6pt, fill: luma(100))
})

#callout("note", "PICK THE ENCODING BY THE OPERATION",
[The matrix answers "is $i j$ an edge" in one array lookup and costs
$n^2$ cells, 36 for G1. The bitmask answers "list the neighbors of $i$"
by scanning set bits and costs $n$ words holding $2|E|$ set bits, 16
for G1. Matrix powers count walks, list scans find neighborhoods, and
the degree column is free in both.])

== walks, paths, and connectivity

A walk repeats nothing forbidden, a path repeats no vertex, and
reachability is the closure question: can $j$ be reached from $i$ by
some walk. The transitive closure of the adjacency relation answers it
for all pairs at once, and warshall's triple loop computes it in place:
whenever $i$ already reaches $k$, row $i$ absorbs row $k$. Reachability
is reflexive by convention, every vertex reaches itself by the empty
walk, so the closure matrix starts from $A union I$.

The dry run: D1 is the directed fixture, 8 vertices and 8 arcs,
$0 -> 1 -> 2 -> 0$ a cycle, $2 -> 3$ a bridge, $3 -> 4 -> 5 -> 3$ a
second cycle, $6 -> 7$ a tail.

+ Out-degrees run (1,1,2,1,1,1,1,0) and in-degrees (1,1,1,2,1,1,0,1),
  both summing to 8, the directed handshake.
+ Closure row weights come out (6,6,6,3,3,3,2,1): each of 0, 1, 2
  reaches all six of the left block plus the right, each of 3, 4, 5
  reaches only its own 3-cycle, 6 reaches {6,7}, 7 only itself.
+ That is 30 ones including the 8 reflexive loops, so 22 strict
  reachable ordered pairs.

Two component notions split here. A digraph is strongly connected when
every vertex reaches every other, and the strong components are the
equivalence classes of mutual reachability, $i ~ j$ when $i$ reaches $j$
and $j$ reaches $i$, a reflexive symmetric transitive relation by
construction. Weak components ignore direction: take the underlying
undirected graph and count connected pieces. On D1 the closure gives 4
strong components, {0,1,2}, {3,4,5}, {6}, {7}, while the undirected
projection has 2 weak components, {0..5} and {6,7}. The gap between 4
and 2 is the whole reason the distinction exists, and the efficient
linear-time algorithms for both live in #xref-to("dsa", "graphs") and
#xref-to("dsa", "connectivity"), this chapter only pins the definitions
on a fixture small enough to close by hand.

#listing("math/samples/src/Ch15/models.c", first: 182, last: 231, caption: [models.c runs warshall on D1 and reads the strong components off mutual rows])

#diagram([D1: two 3-cycles, a bridge arc, and a tail, 4 strong components under 2 weak ones], length: 13pt, {
  // component backdrops
  cdraw.circle((2.0, 4.7), radius: 1.45, fill: luma(245), stroke: none)
  cdraw.circle((6.0, 4.7), radius: 1.45, fill: luma(245), stroke: none)
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.32, fill: luma(235), stroke: luma(60))
    cdraw.content((x, y), t, size: 6pt)
  }
  let a = ((1.2, 5.2), (2.8, 5.9), (2.0, 3.9), (5.2, 5.9), (6.0, 3.9), (6.8, 5.2), (8.8, 3.6), (10.8, 3.6))
  let arcs = ((0, 1), (1, 2), (2, 0), (2, 3), (3, 4), (4, 5), (5, 3), (6, 7))
  for p in arcs {
    cdraw.line(a.at(p.at(0)), a.at(p.at(1)), stroke: luma(100), mark: (end: ">"))
  }
  for i in range(8) { node(a.at(i).at(0), a.at(i).at(1), [#i]) }
  cdraw.content((2.0, 2.6), [scc {0,1,2}], size: 6pt, fill: luma(100))
  cdraw.content((6.0, 2.6), [scc {3,4,5}], size: 6pt, fill: luma(100))
  cdraw.content((9.8, 4.6), [arc 2 -> 3 joins the blocks], size: 6pt, fill: luma(100))
})

#callout("pitfall", "STRONG AND WEAK ARE DIFFERENT QUESTIONS",
[The same fixture D1 answers 4 to "how many strong components" and 2 to
"how many weak components". Both numbers are correct and neither implies
the other: the tail 6 -> 7 is one weak component and two strong ones,
while a single directed cycle is one of each. State which connectivity
you mean before counting.])

== trees

A tree is a connected acyclic graph, and on finite graphs the
definitions collapse into equivalences: every two vertices are joined
by a unique path, and a tree is minimally connected and maximally
acyclic (Diestel, Graph Theory, 5th ed., theorem 1.5.1, cited by
name). The counting forms carry the same content, connected with
exactly $n - 1$ edges and acyclic with exactly $n - 1$ edges (Rosen,
8th ed., ch 11.1, cited by name). The chapter proves the useful
direction by counting: a connected
graph on $n$ vertices needs at least $n - 1$ edges to escape isolation,
and an acyclic graph admits at most $n - 1$ before a cycle closes, so
connected plus acyclic pins the count exactly, and then every tree with
$n >= 2$ has at least two leaves, strip them one at a time and the
degree sum $2(n - 1)$ cannot live on one leaf alone.

A spanning tree of $G$ is a subgraph that is a tree on all of $V$, and
$G$ has a spanning tree exactly when $G$ is connected. Counting them is
a different game. Kirchhoff's matrix-tree theorem says the number of
spanning trees equals any cofactor of the laplacian $bold(L) = bold(D) -
bold(A)$, degree matrix minus adjacency matrix
(en.wikipedia.org/wiki/Kirchhoff%27s_theorem, fetched 2026-09-21), and
for the complete graph $K_n$ the cofactor evaluates to $n^(n-2)$,
cayley's formula, 16 spanning trees of $K_4$.

The dry run: enumerate all $binom(8, 5) = 56$ edge subsets of G1 and
keep the connected ones.

+ 30 of the 56 subsets connect all 6 vertices, so G1 has 30 spanning
  trees by enumeration.
+ The kirchhoff cofactor of G1 is also 30, one $5 times 5$ determinant
  agreeing with 56 connectivity tests.
+ The lexicographically first tree uses edges (0,1), (0,2), (1,3),
  (2,4), (3,5), mask 0x5B, and leaves the 3 chords (1,2), (3,4), (4,5):
  $m - n + 1 = 3$.
+ Rooted at 0 with smallest-first bfs that tree gives parent
  (-,0,0,1,2,3) and depth (0,1,1,2,2,3), degree sum 10 = 2(n-1), leaves
  {4, 5}.

#listing("math/samples/src/Ch15/trees.c", first: 98, last: 129, caption: [trees.c takes the cofactor determinant by exact bareiss pivots in 64-bit bitint arithmetic])

#listing("math/samples/src/Ch15/trees.c", first: 152, last: 200, caption: [trees.c enumerates the 56 candidate subsets and pins the 30 spanning trees with leaf statistics])

#diagram([G1 with the pinned spanning tree solid and its 3 chords dashed], length: 13pt, {
  let e = ((1.2, 4), (3.2, 5.6), (3.2, 2.4), (6.2, 5.6), (6.2, 2.4), (8.4, 4))
  let tree = ((0, 1), (0, 2), (1, 3), (2, 4), (3, 5))
  let chord = ((1, 2), (3, 4), (4, 5))
  for p in chord {
    cdraw.line(e.at(p.at(0)), e.at(p.at(1)),
      stroke: (paint: luma(150), dash: "dashed"))
  }
  for p in tree { cdraw.line(e.at(p.at(0)), e.at(p.at(1)), stroke: luma(60)) }
  for i in range(6) {
    cdraw.circle(e.at(i), radius: 0.34, fill: luma(235), stroke: luma(60))
    cdraw.content(e.at(i), [#i], size: 6pt)
  }
  cdraw.content((9.0, 6.5), [5 tree edges], size: 6pt, fill: luma(100))
  cdraw.content((9.0, 5.9), [3 chords, m - n + 1], size: 6pt, fill: luma(100))
})

== partial orders

A relation $≤$ on a set is a partial order when it is reflexive,
antisymmetric, and transitive. Antisymmetry is the property that breaks
ties: $x <= y$ and $y <= x$ together force $x = y$, so parity classes
or any equivalence relation with two distinct related elements fails
it. Three fixed relations pin the predicate grid, $≤$ on {0,1,2,3} a
partial order, same-parity an equivalence that fails antisymmetry,
differs-by-1 symmetric but not transitive.

The hasse diagram is the disciplined picture of a finite poset: draw
only cover pairs, $x < y$ with no $z$ strictly between, edge upward,
and leave loops and transitive edges implied. For the chapter's running
poset, the divisors of 12 under divisibility, the relation holds 18
pairs including the 6 reflexive loops, and exactly 7 of them are covers,
1 to 2, 1 to 3, 2 to 4, 2 to 6, 3 to 6, 4 to 12, 6 to 12.

Minimal and maximal are local, minimum and maximum are global. A
minimal element has nothing below it, a minimum sits below everything.
The divisor poset has minimum 1 and maximum 12, unique in both roles.
The V shaped subposet {1, 2, 3} has two maximal elements, 2 and 3, and
no maximum at all, no element sits above both.

A topological order of a poset is a linear listing respecting $<$, and
it always exists: kahn's algorithm repeatedly removes a minimal
element, and a finite poset always has one, so the loop cannot stall
(en.wikipedia.org/wiki/Topological_sorting, fetched 2026-09-21). The
digraph view says the same thing, a topological order exists exactly
when the digraph is acyclic, and a cycle is precisely a stall, no
element of the cycle ever becomes minimal. Counting the orders is
harder: the divisor poset of 12 admits exactly 5 linear extensions.

The dry run: kahn with a smallest-first tie break on the divisor poset.

+ Initial minimal set {1}. Place 1, then 2 and 3 become minimal, take
  2, then 3, then 4 and 6 are minimal, take 4, then 6, then 12.
+ The pinned order is 1, 2, 3, 4, 6, 12, all 6 elements placed.
+ Add the single back arc $12 < 1$ and every vertex has a predecessor:
  kahn places 0 of 6. One arc deletes the entire order structure.

#listing("math/samples/src/Ch15/order.c", first: 339, last: 362, caption: [order.c pins the kahn order, the cyclic stall, and the 5 linear extensions])

#diagram([hasse diagram of the divisors of 12, upward means divides, 7 covers carry 18 pairs], length: 13pt, {
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.34, fill: luma(235), stroke: luma(60))
    cdraw.content((x, y), t, size: 6pt)
  }
  let p1 = (3.6, 0)
  let p2 = (1.8, 1.9)
  let p3 = (5.4, 1.9)
  let p4 = (0.8, 3.8)
  let p6 = (5.4, 3.8)
  let p12 = (3.6, 5.7)
  let cov = ((p1, p2), (p1, p3), (p2, p4), (p2, p6), (p3, p6), (p4, p12), (p6, p12))
  for c in cov { cdraw.line(c.at(0), c.at(1), stroke: luma(100)) }
  node(p1.at(0), p1.at(1), [1])
  node(p2.at(0), p2.at(1), [2])
  node(p3.at(0), p3.at(1), [3])
  node(p4.at(0), p4.at(1), [4])
  node(p6.at(0), p6.at(1), [6])
  node(p12.at(0), p12.at(1), [12])
  cdraw.content((7.0, 5.0), [minimum 1], size: 6pt, fill: luma(100))
  cdraw.content((7.0, 4.4), [maximum 12], size: 6pt, fill: luma(100))
  cdraw.content((7.0, 3.8), [18 pairs, 7 covers], size: 6pt, fill: luma(100))
})

#callout("warning", "DRAW ONLY COVERS",
[The hasse discipline deletes two kinds of edge: the 6 reflexive loops,
and every transitive pair like 1 to 12 that a two-step path already
encodes. Draw either and the diagram stops being a poset picture, it
starts looking like a dataflow graph. Of the divisor poset's 18 pairs,
exactly 7 earn ink.])

== lattices

A lattice is a poset where every pair has a least upper bound, the
join $x ∨ y$, and a greatest lower bound, the meet $x ∧ y$.
Both are defined by bounds, not formulas: the join of $x$ and $y$ is
the upper bound with no other upper bound below it, unique when it
exists because two least upper bounds bound each other and antisymmetry
collapses them. The divisor poset of 12 is a lattice where join is lcm
and meet is gcd, $4 ∨ 6 = 12$ and $4 ∧ 6 = 2$, verified by
enumerating bounds, and then cell by cell across all 36 pairs.

The dry run: compute $4 ∨ 6$ from bounds alone.

+ Upper bounds of 4 and 6 inside the fixture: common multiples, only
  12. The least upper bound is 12 with no rival.
+ Lower bounds: common divisors 1 and 2, and 2 sits above 1, so the
  greatest lower bound is 2.
+ The same two loops over all 36 pairs produce tables identical to lcm
  and gcd, an arithmetic agreement check on a structural definition.

Not every poset is a lattice. The V subposet {1, 2, 3} under
divisibility gives 2 and 3 no common upper bound at all, the join does
not exist, while the meet $2 ∧ 3 = 1$ survives. And a lattice can
still fail the stronger law. Distributivity,

$ x ∨ (y ∧ z) = (x ∨ y) ∧ (x ∨ z), $

holds in every divisor lattice, 216 triples checked on the fixture
with zero failures. The pentagon $N_5$, the lattice shaped as 0 below a
chain $0 < x < 1$ beside a chain $0 < y < z < 1$, keeps every join and
meet but breaks distributivity on the witness triple: $y ∨ (x
∧ z) = y ∨ 0 = y$ against $(y ∨ x) ∧ (y
∨ z) = 1 ∧ z = z$, and $y != z$.

#listing("math/samples/src/Ch15/order.c", first: 192, last: 231, caption: [order.c searches bounds for the least upper bound, the anonymous union carrying the index when it exists])

#listing("math/samples/src/Ch15/order.c", first: 364, last: 406, caption: [order.c checks all 36 joins and meets, the gcd and lcm agreement, distributivity, and the V poset failure])

#diagram([the pentagon N5: every pair joins and meets, distributivity fails on the witness triple], length: 13pt, {
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.32, fill: luma(235), stroke: luma(60))
    cdraw.content((x, y), t, size: 6pt)
  }
  let b = (2.0, 0)
  let x = (0.7, 2.2)
  let top = (2.0, 4.4)
  let y = (3.9, 1.4)
  let z = (3.9, 3.2)
  for p in ((b, x), (x, top), (b, y), (y, z), (z, top)) {
    cdraw.line(p.at(0), p.at(1), stroke: luma(100))
  }
  node(x.at(0), x.at(1), [x])
  node(y.at(0), y.at(1), [y])
  node(z.at(0), z.at(1), [z])
  node(b.at(0), b.at(1), [0])
  node(top.at(0), top.at(1), [1])
  cdraw.content((7.2, 3.4), [y join (x meet z) = y], size: 6pt, fill: luma(100))
  cdraw.content((7.2, 2.8), [(y join x) meet (y join z) = z], size: 6pt, fill: luma(100))
})

== equivalence relations and partitions

An equivalence relation is reflexive, symmetric, and transitive, and it
is the same object as a partition, a family of nonempty disjoint
blocks covering the set. From a partition, "same block" is an
equivalence. From an equivalence, the classes $[x] = {y : x ~ y}$ form
blocks, and transitivity is exactly what keeps classes from overlapping
half of one and half of another. The round trip, partition to relation
to partition, returns the starting partition, which the sample checks
pairwise on a fixed 3-block partition of {0..7}.

A relation that is merely reflexive and symmetric still generates an
equivalence: take the transitive closure, the same warshall loop as the
reachability run of this chapter. The fixture holds the 8 loops plus
0 tilde 1 and 1 tilde 2 in both directions, 12 ordered pairs, and
fails transitivity because 0 tilde 2 is missing in both directions.
Closure adds exactly those 2 pairs, the block {0,1,2} contributes 9
pairs plus 5 singleton loops for 14 total, and the induced partition
is one 3-element block with 5 singletons.

Union-find maintains a partition under merging, and the theory says
what its invariant is: at every moment the structure encodes exactly
one equivalence relation, find(i) = find(j) iff $i ~ j$. The sample
drives a fixed sequence of 9 unions over 10 singletons with union by
size and path halving, and after every call rescans to confirm the
recorded size at each root equals the live count of its elements.

The dry run: the sequence (0,1), (2,3), (0,2), (4,5), (6,7), (5,7),
(4,6), (0,4), (8,9).

+ Merged component sizes run 2, 2, 4, 2, 2, 4, 8, 2, and the seventh
  call, union(4,6), finds both ends already in the size-4 component
  {4,5,6,7} and merges nothing: 9 unions, 8 merges, 1 no-op.
+ The final partition is {0..7} of size 8 and {8,9} of size 2, two
  components, class labels by least element reading 0 eight times then
  8 twice.

#listing("math/samples/src/Ch15/partitions.c", first: 120, last: 159, caption: [partitions.c checks the induced equivalence and the round trip on the 3-block fixture])

#listing("math/samples/src/Ch15/partitions.c", first: 195, last: 230, caption: [partitions.c drives the 9 unions with the size invariant rescanned after each])

#diagram([the fixed union sequence: 10 singletons collapse into components of size 8 and 2], length: 13pt, {
  for i in range(10) {
    let x = 0.4 + i * 1.15
    cdraw.rect((x, 4.6), (x + 0.85, 5.45), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + 0.42, 5.0), [#i], size: 5.5pt)
  }
  cdraw.line((5.8, 4.2), (5.8, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.0, 3.6), [9 unions, 8 merges], size: 6pt, fill: luma(100))
  cdraw.content((7.0, 3.0), [1 redundant union(4,6)], size: 6pt, fill: luma(100))
  cdraw.rect((0.4, 0.8), (9.65, 1.9), fill: luma(205), stroke: luma(60), radius: 0.02)
  cdraw.content((5.0, 1.35), [{0,1,2,3,4,5,6,7} of size 8], size: 6pt)
  cdraw.rect((10.1, 0.8), (11.8, 1.9), fill: luma(205), stroke: luma(60), radius: 0.02)
  cdraw.content((10.95, 1.35), [{8,9} size 2], size: 6pt)
})

#callout("verify", "AUDIT THE PARTITION, NOT THE POINTERS",
[Union-find code is easy to write and easy to corrupt: path halving
rewrites parents, sizes live only at roots. The cheap audit is
structural, after every mutation rescan and confirm each root's
recorded size equals the number of elements that find to it, and
confirm the implied relation is still reflexive, symmetric,
transitive. Two loops over 10 elements, run 9 times in the sample.])

Equivalence classes of elements under a group action are the next
chapter's opening move, and #xref-to("math", "groups") builds them on
exactly this partition machinery.

sources: Rosen, Discrete Mathematics and Its Applications, 8th ed.,
McGraw-Hill 2019, ch 10.1-10.2 (graph models, degree sums), ch 11.1
(trees), ch 9.1-9.6 (relations, hasse diagrams, equivalence classes),
cited by name and edition, no page text quoted; Diestel, Graph Theory,
5th ed., Springer 2017, theorem 1.5.1, cited by name; CLRS,
Introduction to Algorithms, 4th ed., MIT Press 2022, ch 20.4, cited by
name. Fetched and quoted 2026-09-21:
en.wikipedia.org/wiki/Handshaking_lemma (degree sum formula, directed
variant, odd-vertex corollary),
en.wikipedia.org/wiki/Kirchhoff%27s_theorem (laplacian cofactor,
cayley $n^(n-2)$), en.wikipedia.org/wiki/Topological_sorting (kahn
existence iff acyclic). No mml anchor sheet exists for graph theory,
so this chapter has no mml-book page mapping, and every numeric claim
was computed rather than transcribed. Probed on this machine the same
day. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter
Ch15`, 60 checks in chapter 15 of the math suite, 4 files, zero
failures, format clean.
