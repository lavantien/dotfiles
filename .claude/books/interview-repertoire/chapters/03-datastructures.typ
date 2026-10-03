#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= data structures, implemented

"Implement a hash map" and its siblings are the medium-difficulty
loop staples. This chapter carries the seven structures the
inventory names, dynamic array, linked list, hash map, binary
search tree, heap, trie, and graph, each implemented from zero with
its tests, in Go and in C\#. Both suites are test-first and run
under `make verify`. The complexity claims are floored by
#xref-to("dsa", "analysis"), which builds the instruments a cost
claim must survive, and the per-structure chapters of the same book
carry the depth this chapter drills from memory.

== the dynamic array [TDD]

The claim to narrate: append is constant on average because growth
doubles capacity, so the copies over n appends stay under 2n. The
suite pins go's actual growth policy, strict doubling while small
and a gentler factor above a few hundred slots, rather than the
folk version that doubles forever:

#listing("interview-repertoire/samples/ch03-go/dynamic.go", first: 5, last: 49, caption: [push, pop, insert, and the capacity probe the doubling test reads])

#diagram([the capacity stair-step against n, why append is constant on average], length: 13pt, {
  // x is appends, y is capacity: each growth doubles, the rises copy the live slice
  cdraw.line((2, 0.9), (14.6, 0.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2, 0.9), (2, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.3, 0.3), [appends], size: 6pt)
  cdraw.content((2.6, 6.35), [capacity], size: 6pt)
  let y(c) = { 1.35 + calc.log(c, base: 2) * 1.03 }
  let x(n) = { 2.0 + n * 0.75 }
  // the staircase: hold, double, hold
  let steps = ((0, 1), (1, 2), (2, 4), (4, 8), (8, 16))
  for i in range(steps.len() - 1) {
    let (n0, c0) = steps.at(i)
    let (n1, c1) = steps.at(i + 1)
    cdraw.line((x(n0), y(c0)), (x(n1), y(c0)), stroke: luma(60))
    cdraw.line((x(n1), y(c0)), (x(n1), y(c1)), stroke: luma(60))
    cdraw.circle((x(n1), y(c1)), radius: 0.08, fill: luma(60))
  }
  cdraw.line((x(8), y(16)), (x(16), y(16)), stroke: luma(60))
  // the y = n reference and the amortized claim
  cdraw.line((2, 1.35), (14, y(16)), stroke: (paint: luma(180), dash: "dashed"))
  cdraw.content((13.0, 4.35), [y = n], size: 6pt)
  for (n, c) in ((1, 2), (2, 4), (4, 8), (8, 16)) {
    cdraw.content((x(n), y(c) + 0.45), [#n], size: 6pt)
  }
  cdraw.content((19.0, 4.9), [each rise copies], size: 6pt)
  cdraw.content((19.0, 3.8), [the live slice,], size: 6pt)
  cdraw.content((19.0, 2.7), [copies stay under 2n], size: 6pt)
})

The C\# mirror is the same contract over `T[]` with `Array.Resize`,
and the insert operation states its honest cost: shifting the tail
is linear, and the test says so instead of hiding it.

== the linked list [TDD]

The three-pointer reverse is the centerpiece, `prev`, `cur`,
`next`, one pass, constant extra space:

#listing("interview-repertoire/samples/ch03-go/linked.go", first: 24, last: 60, caption: [reverse rewires in place; the scan and the unlink])

#diagram([the three-pointer reverse rewires next in place], length: 13pt, {
  // one instant of the pass: prev is done, cur is being rewired, next is saved
  let node(x, t) = {
    cdraw.rect((x, 2.0), (x + 3.0, 3.0), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.line((x + 1.8, 2.0), (x + 1.8, 3.0), stroke: luma(120))
    cdraw.content((x + 0.9, 2.5), [#t], size: 6.5pt)
  }
  node(1.5, "a")
  node(6.0, "b")
  node(10.5, "c")
  // the dead forward links, dashed
  cdraw.line((4.5, 2.5), (6.0, 2.5), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line((9.0, 2.5), (10.5, 2.5), stroke: (paint: luma(190), dash: "dashed"))
  // the rewire just decided: b.next now aims at a
  cdraw.line((7.8, 2.0), (7.8, 1.5), (4.0, 1.5), (4.0, 2.0), stroke: luma(60), mark: (end: ">"))
  // c.next is still nil, the pointer trio under the boxes
  cdraw.line((13.5, 2.5), (14.8, 2.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((15.3, 2.5), [nil], size: 6.5pt)
  cdraw.content((3.0, 0.75), [prev], size: 6pt)
  cdraw.content((7.5, 0.75), [cur], size: 6pt)
  cdraw.content((12.0, 0.75), [next], size: 6pt)
  cdraw.line((3.0, 1.1), (3.0, 2.0), stroke: luma(160))
  cdraw.line((7.5, 1.1), (7.5, 2.0), stroke: luma(160))
  cdraw.line((12.0, 1.1), (12.0, 2.0), stroke: luma(160))
  cdraw.content((19.3, 1.8), [b.next rewired to a], size: 6pt)
  cdraw.content((19.3, 0.7), [one pass, no new nodes], size: 6pt)
})

The trap in the room: remove on a head node. The dummy head in
`Remove` deletes the special case, and the Go table test walks
middle, head, tail, and missing in one function.

== the hash map [TDD]

Separate chaining with growth: buckets are small vectors, the load
factor crossing 0.75 doubles the table, and every entry re-buckets.
The hash itself comes from the stdlib, `maphash.Comparable`, the
seeded hash go's own map uses, folded by the bucket count:

#listing("interview-repertoire/samples/ch03-go/hashmap.go", first: 5, last: 59, caption: [chained buckets, the seeded hash, put and get])

#diagram([chained buckets, doubling at load factor 0.75], length: 13pt, {
  // four bucket cells, three occupied, chains hanging below
  for i in range(4) {
    cdraw.rect((2.0 + i * 2.0, 5.2), (4.0 + i * 2.0, 6.2), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((3.0 + i * 2.0, 5.7), [#i], size: 6.5pt)
  }
  let entry(x, y, t) = {
    cdraw.rect((x - 0.85, y), (x + 0.85, y + 0.8), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((x, y + 0.4), [#t], size: 6pt)
  }
  entry(3.0, 3.9, "k=7")
  entry(3.0, 2.6, "k=15")
  entry(7.0, 3.9, "k=2")
  entry(9.0, 3.9, "k=11")
  cdraw.line((3.0, 5.2), (3.0, 4.7), mark: (end: ">"))
  cdraw.line((3.0, 3.9), (3.0, 3.4), mark: (end: ">"))
  cdraw.line((7.0, 5.2), (7.0, 4.7), mark: (end: ">"))
  cdraw.line((9.0, 5.2), (9.0, 4.7), mark: (end: ">"))
  cdraw.content((17.6, 5.7), [load factor = entries / buckets], size: 6pt)
  cdraw.content((17.6, 4.6), [crossing 0.75 doubles the table], size: 6pt)
  cdraw.content((17.6, 3.5), [and re-buckets every entry], size: 6pt)
  cdraw.content((17.6, 2.4), [chains stay short: get is O(1)], size: 6pt)
})

#listing("interview-repertoire/samples/ch03-go/hashmap.go", first: 72, last: 87, caption: [the doubling rehash, the moment average constant time is preserved])

The 500-key growth test is the line to quote: the load check runs
before every put, so inserts 7, 13, 25, 49, 97, 193 and 385 each
double the table, seven rehashes that land 500 keys in 1024
buckets, Len still 500, every 37th key still reading back and one
absent key still missing, which is the claim rehashing exists to
keep. The C\# twin hashes through
`GetHashCode` with the unsigned fold, because dotnet hashes can be
negative and a naive modulo goes negative for about half of all
hash codes, so the first negative index throws instead of
bucketing.

== the binary search tree [TDD]

In-order traversal emitting sorted keys is the property
interviewers probe, and the two height tests are the honest
counterweight: sorted insertion makes a chain of height 6 from 7
nodes, balanced insertion makes height 2, same algorithm:

#listing("interview-repertoire/samples/ch03-go/bst.go", first: 46, last: 68, caption: [in-order walk and height, the balance story in two functions])

#diagram([same algorithm, two shapes: height 6 against height 2], length: 13pt, {
  // left: sorted insertion builds a chain; right: the same seven nodes balanced
  let ball(x, y, t) = {
    cdraw.circle((x, y), radius: 0.32, fill: luma(235), stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6pt)
  }
  cdraw.content((3.0, 7.6), [sorted insertion], size: 6.5pt)
  for i in range(7) {
    let yy = 6.7 - i
    if i > 0 { cdraw.line((3.0, yy + 1 - 0.32), (3.0, yy + 0.32), stroke: luma(120)) }
    ball(3.0, yy, str(i + 1))
  }
  cdraw.content((3.0, -0.3), [height 6], size: 6.5pt)
  cdraw.content((17.0, 7.6), [balanced insertion], size: 6.5pt)
  cdraw.line((17.0, 6.5), (14.3, 5.2), stroke: luma(120))
  cdraw.line((17.0, 6.5), (19.7, 5.2), stroke: luma(120))
  cdraw.line((14.3, 5.2), (13.0, 3.9), stroke: luma(120))
  cdraw.line((14.3, 5.2), (15.6, 3.9), stroke: luma(120))
  cdraw.line((19.7, 5.2), (18.4, 3.9), stroke: luma(120))
  cdraw.line((19.7, 5.2), (21.0, 3.9), stroke: luma(120))
  ball(17.0, 6.5, "4")
  ball(14.3, 5.2, "2")
  ball(19.7, 5.2, "6")
  ball(13.0, 3.9, "1")
  ball(15.6, 3.9, "3")
  ball(18.4, 3.9, "5")
  ball(21.0, 3.9, "7")
  cdraw.content((17.0, 2.9), [height 2], size: 6.5pt)
  cdraw.content((8.2, 4.6), [same seven nodes,], size: 6pt)
  cdraw.content((8.2, 3.7), [same walk, same code], size: 6pt)
})

Delete carries the fiddly case: two children means swapping in the
in-order successor and recursing. The suite exercises leaf,
one-child, and two-child deletes and asserts the traversal stays
sorted after each.

== the heap [TDD]

A min-heap over one slice, children of i at `2i+1` and `2i+2`, no
pointers, push sifts up and pop sifts down:

#listing("interview-repertoire/samples/ch03-go/heap.go", first: 21, last: 34, caption: [sift up to the root])

#diagram([one slice as a tree: children of i at 2i+1 and 2i+2], length: 13pt, {
  // the strip above, the implicit tree below, same indexes
  let vals = ("1", "3", "2", "7", "5", "4", "6")
  for i in range(7) {
    cdraw.rect((2.0 + i * 1.7, 5.2), (3.7 + i * 1.7, 6.2), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((2.85 + i * 1.7, 5.7), vals.at(i), size: 6.5pt)
    cdraw.content((2.85 + i * 1.7, 4.75), [#i], size: 6pt)
  }
  let cell(i) = { (2.85 + i * 1.7, 4.75) }
  let tnode(x, y, idx, v) = {
    cdraw.rect((x - 0.6, y - 0.4), (x + 0.6, y + 0.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x, y), [#v], size: 6.5pt)
    cdraw.content((x, y + 0.75), [#idx], size: 6pt)
  }
  cdraw.line((7.85, 4.4), (7.85, 4.15), stroke: luma(180))
  cdraw.line((8.0, 3.6), (5.6, 2.4), stroke: luma(120))
  cdraw.line((8.0, 3.6), (10.4, 2.4), stroke: luma(120))
  cdraw.line((5.6, 2.4), (4.2, 1.2), stroke: luma(120))
  cdraw.line((5.6, 2.4), (7.0, 1.2), stroke: luma(120))
  cdraw.line((10.4, 2.4), (9.0, 1.2), stroke: luma(120))
  cdraw.line((10.4, 2.4), (11.8, 1.2), stroke: luma(120))
  cdraw.content((6.6, 3.9), [2i+1], size: 6pt)
  cdraw.content((9.4, 3.9), [2i+2], size: 6pt)
  tnode(8.0, 3.6, 0, "1")
  tnode(5.6, 2.4, 1, "3")
  tnode(10.4, 2.4, 2, "2")
  tnode(4.2, 1.2, 3, "7")
  tnode(7.0, 1.2, 4, "5")
  tnode(9.0, 1.2, 5, "4")
  tnode(11.8, 1.2, 6, "6")
  cdraw.content((17.6, 4.3), [one slice, no pointers], size: 6pt)
  cdraw.content((17.6, 3.2), [push sifts up], size: 6pt)
  cdraw.content((17.6, 2.1), [pop sifts down], size: 6pt)
})

The randomized test is the one that matters: 300 random pushes
drained must equal `slices.Sort` on the same input, which catches
every off-by-one the small cases miss.

== the trie [TDD]

Prefix trees answer the autocomplete question in word length,
independent of corpus size. `Leaf` marks whole words, prefixes are
the nodes themselves:

#listing("interview-repertoire/samples/ch03-go/trie.go", first: 29, last: 71, caption: [word search, prefix search, and the suggestion walk])

#diagram([shared prefixes are shared nodes, shaded leaves mark whole words], length: 13pt, {
  // root to c-a-r, then d and e hanging off the r node
  let ball(x, y, t, word: false) = {
    cdraw.circle((x, y), radius: 0.34, fill: if word { luma(205) } else { luma(235) }, stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6.5pt)
  }
  cdraw.line((2.6, 4.4), (4.1, 4.4), stroke: luma(120))
  cdraw.line((4.9, 4.4), (6.4, 4.4), stroke: luma(120))
  cdraw.line((7.1, 4.4), (8.6, 4.4), stroke: luma(120))
  cdraw.line((9.9, 4.1), (11.4, 3.4), stroke: luma(120))
  cdraw.line((9.9, 4.7), (11.4, 5.4), stroke: luma(120))
  ball(2.0, 4.4, "")
  ball(4.5, 4.4, "c")
  ball(7.0, 4.4, "a")
  ball(9.5, 4.4, "r", word: true)
  ball(11.9, 3.4, "d", word: true)
  ball(11.9, 5.4, "e", word: true)
  cdraw.content((0.9, 4.4), [root], size: 6pt)
  // the bracket under the shared prefix chain
  cdraw.line((4.5, 3.75), (9.5, 3.75), stroke: luma(180))
  cdraw.line((4.5, 3.75), (4.5, 3.95), stroke: luma(180))
  cdraw.line((9.5, 3.75), (9.5, 3.95), stroke: luma(180))
  cdraw.content((6.2, 3.1), [one chain, three words], size: 6pt)
  cdraw.content((17.0, 4.9), [suggestions walk], size: 6pt)
  cdraw.content((17.0, 3.8), [the subtree in rune order], size: 6pt)
  cdraw.content((17.0, 2.7), [shaded = a whole word], size: 6pt)
})

The negative cases in the test are the scoring ones: `ca` is a
prefix but not a word, `carts` is a word extension past `car`, and
both must report exactly false.

== the graph [TDD]

The adjacency list is the representation to reach for: a map from
node id to neighbor ids, undirected edges stored both ways:

#listing("interview-repertoire/samples/ch03-go/graph.go", first: 5, last: 58, caption: [the adjacency map and its honest edge counting])

#diagram([undirected edges live in both adjacency lists], length: 13pt, {
  // left: three nodes, two edges; right: the map the code stores
  let ball(x, y, t) = {
    cdraw.circle((x, y), radius: 0.34, fill: luma(235), stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6.5pt)
  }
  cdraw.line((3.0, 5.5), (1.9, 4.15), stroke: luma(120))
  cdraw.line((3.0, 5.5), (4.1, 4.15), stroke: luma(120))
  ball(3.0, 5.5, "a")
  ball(1.8, 3.8, "b")
  ball(4.2, 3.8, "c")
  cdraw.content((3.0, 6.4), [two edges], size: 6pt)
  cdraw.content((3.0, 2.9), [a-b and a-c], size: 6pt)
  cdraw.rect((8.0, 2.6), (15.5, 6.3), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((11.75, 5.75), [a: [b, c]], size: 6.5pt)
  cdraw.content((11.75, 4.65), [b: [a]], size: 6.5pt)
  cdraw.content((11.75, 3.55), [c: [a]], size: 6.5pt)
  cdraw.content((19.5, 5.6), [each edge stored twice], size: 6pt)
  cdraw.content((19.5, 4.5), [four adjacency entries], size: 6pt)
  cdraw.content((19.5, 3.4), [EdgeCount halves to two], size: 6pt)
})

The suite pins one honesty point interviewers like: a plain
adjacency list keeps a repeated `AddEdge` as two stored edges, and
`EdgeCount` says so rather than silently deduplicating.

sources: complexity instruments and per-structure depth floor to
#xref-to("dsa", "analysis") and its neighbors. Verified by `go
test` and `dotnet test` through `make verify`, 25 Go tests and 22
C\# tests, chapter ids `ch03-go` and `ch03-cs`.
