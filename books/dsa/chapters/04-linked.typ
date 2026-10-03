#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= linked structures

Pointer-linked nodes trade locality for flexibility: constant time
insertion and removal anywhere, once you hold the node. This chapter
builds the singly linked list, the in-place reversal, Floyd's cycle
detection, and the sentinel ring that `LinkedList<T>` is, then says
plainly when not to use any of it.

== the singly linked list

Each node is a value and one forward reference. C makes that literal,
a struct with one pointer, drawn from a static pool so the fixture
never calls malloc.

The dry run: the fixture is the C\# list built by three AddFirst
calls and unspliced at 2, plus the abcdef reversal, asserted by the
C\# suite; the other five languages push 1 through 5 and pin the same
flip on integers.

+ AddFirst(1), AddFirst(2), AddFirst(3) each point a fresh node at
  the old head: the read is 3, 2, 1, count 3.
+ Remove(2) walks to the predecessor 3 and unsplices with two writes:
  the read is 3, 1, while Remove(99) walks off the tail and returns
  false.
+ The reversal fixture builds f e d c b a the same way, one AddFirst
  per letter of abcdef.
+ The three pointers run prev = null, cur = f: each pass stashes
  next, flips cur onto prev, and slides, handing one letter to prev.
+ Six passes later the read is a b c d e f, the flip, and the
  degenerates hold: Reverse(null) returns null, one node ends with
  a null tail.

#diagram([the reversal as passes, the flipped prefix growing one letter at a time while the remainder waits], length: 13pt, {
  let row = (y, label, flipped, waiting) => {
    cdraw.content((0.7, y + 0.35), label, size: 6pt)
    for (i, ch) in flipped.enumerate() {
      cdraw.rect((2.2 + i * 0.95, y), (3.15 + i * 0.95, y + 0.7), fill: luma(205), radius: 0.02)
      cdraw.content((2.675 + i * 0.95, y + 0.35), [#ch], size: 6pt)
    }
    let bx = 2.2 + flipped.len() * 0.95 + 0.4
    if waiting.len() > 0 {
      cdraw.line((bx, y - 0.1), (bx, y + 0.8), stroke: (paint: luma(100), dash: "dashed"))
    }
    for (i, ch) in waiting.enumerate() {
      let wx = bx + 0.75 + i * 0.95
      cdraw.rect((wx, y), (wx + 0.95, y + 0.7), fill: luma(235), radius: 0.02)
      cdraw.content((wx + 0.475, y + 0.35), [#ch], size: 6pt)
    }
  }
  row(5.9, [pass 0], (), ("f", "e", "d", "c", "b", "a"))
  row(4.6, [pass 1], ("f",), ("e", "d", "c", "b", "a"))
  row(3.3, [pass 3], ("d", "e", "f"), ("c", "b", "a"))
  row(2.0, [pass 6], ("a", "b", "c", "d", "e", "f"), ())
  cdraw.content((3.55, 4.0), [cur], size: 6pt)
  cdraw.line((3.55, 4.15), (3.55, 4.45), stroke: luma(220))
  cdraw.content((13.4, 5.9), [shaded: prev owns the flipped prefix], size: 6pt)
  cdraw.content((13.4, 4.6), [dashed line: where cur stands], size: 6pt)
  cdraw.content((13.4, 3.3), [six passes flip six letters], size: 6pt)
  cdraw.content((13.4, 2.0), [no allocation anywhere], size: 6pt)
})

The 3, 2, 1 into 3, 1 and the abcdef round trip are the C\# pins,
and the listings below build the spine in six languages.

#listing("dsa/samples-c/src/Ch04/slist.c", first: 31, last: 53, caption: [c, push, reverse, find, and to-array over a node pool])

Removal unsplices by finding the predecessor, a search followed by a
two-line fixup, the shape the C\# class carries:

#listing("dsa/samples/src/Ch04/Linked.cs", first: 4, last: 44, caption: [add first, remove by scan, iterate])

Reversal is the canonical three pointer dance, `prev`, `cur`, `next`,
one pass, no allocation, and it works on any head someone hands you:

#listing("dsa/samples/src/Ch04/Linked.cs", first: 46, last: 61, caption: [in-place reversal, forward walk])

Four more languages carry the same spine:

#listing("dsa/samples-go/ch04/slist.go", first: 18, last: 36, caption: [go, push front and the three pointer reverse as methods])

#listing("dsa/samples-js/src/ch04-slist.mjs", first: 11, last: 27, caption: [javascript, push front and reverse as free functions over nodes])

#listing("dsa/samples-py/src/Ch04/slist.py", first: 21, last: 43, caption: [python, push, walk out, reverse with the third pointer saved])

#listing("dsa/samples-lua/ch04_slist.lua", first: 5, last: 25, caption: [lua, each node a table with a next field])

Every suite pins the reversal. C, JavaScript, and Lua push 1 through
5, read the list back as 5 4 3 2 1, and read 1 2 3 4 5 after the
flip. Go reverses a 3 node list to 3 2 1. Python pushes 5 4 3 2 1 so
the list reads 1 through 5, flips it twice, and checks the round
trip. Node shapes differ, a static pool in C, `__slots__` in Python,
a fresh table per node in Lua, and the reversal loop stays within a
dozen lines in all six.

#diagram([the three pointer reversal, one iteration: stash next, flip cur onto prev, slide both], length: 13pt, {
  let box = (x, y, ch) => {
    cdraw.rect((x, y), (x + 1.7, y + 0.85), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.85, y + 0.42), [#ch], size: 6.5pt)
  }
  // step k: prev is null, cur at a, next at b
  cdraw.content((0.7, 6.0), [step k], size: 6.5pt)
  for (i, ch) in ("a", "b", "c", "d").enumerate() { box(4.2 + i * 3.0, 5.6, ch) }
  for i in range(3) {
    cdraw.line((5.9 + i * 3.0, 6.0), (7.2 + i * 3.0, 6.0), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.line((14.9, 6.0), (16.2, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.9, 6.0), [null], size: 6pt)
  cdraw.content((5.05, 5.1), [cur], size: 6pt)
  cdraw.content((8.05, 5.1), [next], size: 6pt)
  cdraw.content((2.5, 5.1), [prev = null], size: 6pt)

  // step k+1: a flipped onto prev, cur slid to b
  cdraw.content((0.7, 2.8), [step k+1], size: 6.5pt)
  for (i, ch) in ("a", "b", "c", "d").enumerate() { box(4.2 + i * 3.0, 2.4, ch) }
  for i in range(3) {
    cdraw.line((5.9 + i * 3.0, 2.8), (7.2 + i * 3.0, 2.8), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.line((14.9, 2.8), (16.2, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.9, 2.8), [null], size: 6pt)
  cdraw.line((4.2, 2.8), (3.6, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.15, 2.8), [null], size: 6pt)
  cdraw.content((5.05, 1.9), [prev], size: 6pt)
  cdraw.content((8.05, 1.9), [cur], size: 6pt)
  cdraw.content((11.05, 1.9), [next], size: 6pt)
})

#callout("note", "the interview shape of reversal", [
  Draw three boxes, prev, cur, next, and move them one node at a
  time: stash `next`, flip `cur` onto `prev`, slide both forward.
  Every test here is that loop with a different assertion, including
  the empty list, `Reverse(null)` returns null, and the single node,
  which must end with a null tail.
])

== floyd's cycle detection

Can a fast and a slow pointer find a loop without a hash set? Yes,
and the reason is arithmetic: if the list has a cycle of length k,
once both pointers are inside it, the gap between them shrinks by one
every step modulo k, so it must pass through zero. C runs both races,
one to detect, one from the head to find the entry.

The dry run: the fixture is the rho 1, 2, 3, 4, 5 with the tail bent
back onto 3, pinned by the C, JavaScript, and Lua suites at entry 3,
mu 2, lambda 3; Go pins the length, Python bends onto 2 instead, and
C\# flips a 10 node chain from acyclic to cyclic.

+ Both pointers start at the head 1: slow steps one node per turn,
  fast two.
+ Turn 1: slow sits at 2, fast has already reached 3, inside the
  loop.
+ Turn 2: slow reaches 3, the entry, while fast reaches 5, two
  ahead.
+ Turn 3: slow hops to 4 while fast hops 5 to 3 to 4: the meet, on 4.
+ The entry race walks head and meet in lockstep, 1 against 4, 2
  against 5, then both land on 3: the entry, mu = 2.
+ Once around from 3 the loop reads 4, 5, back to 3: lambda = 3.

#diagram([the rho 1 to 5 with the tail bent onto 3, the race positions turn by turn, then the lockstep walk to the entry], length: 13pt, {
  for i in range(5) {
    cdraw.rect((1.6 + i * 1.5, 6.1), (2.9 + i * 1.5, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((2.25 + i * 1.5, 6.45), [#(i + 1)], size: 6pt)
  }
  for i in range(4) {
    cdraw.line((2.9 + i * 1.5, 6.45), (3.1 + i * 1.5, 6.45), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.line((8.75, 6.1), (8.75, 5.55), stroke: luma(100))
  cdraw.line((8.75, 5.55), (5.0, 5.55), stroke: luma(100))
  cdraw.line((5.0, 5.55), (5.0, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 5.15), [the tail bends back onto 3], size: 6pt)
  let turn = (y, label, s, f, note) => {
    cdraw.content((0.7, y + 0.32), label, size: 6pt)
    for i in range(5) {
      let hot = i + 1 == s and i + 1 == f
      cdraw.rect((2.6 + i * 1.3, y), (3.7 + i * 1.3, y + 0.64), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((3.15 + i * 1.3, y + 0.32), [#(i + 1)], size: 6pt)
    }
    cdraw.circle((3.15 + (s - 1) * 1.3, y + 0.92), radius: 0.11, fill: luma(100))
    cdraw.circle((3.15 + (f - 1) * 1.3, y - 0.28), radius: 0.11, fill: none, stroke: luma(100))
    cdraw.content((11.2, y + 0.32), note, size: 6pt)
  }
  turn(3.7, [turn 1], 2, 3, [slow 2, fast 3])
  turn(2.2, [turn 2], 3, 5, [slow 3, fast 5])
  turn(0.7, [turn 3], 4, 4, [both on 4: the meet])
  cdraw.content((0.7, 4.75), [filled dot slow, open dot fast], size: 6pt)
  cdraw.content((11.2, 4.75), [entry race: 1 vs 4, 2 vs 5, both on 3], size: 6pt)
  cdraw.content((11.2, -0.2), [mu = 2, lambda = 3], size: 6pt)
})

The meet at 4 with mu 2 and lambda 3 is pinned three suites deep,
and the listings below run both races in six languages.

#listing("dsa/samples-c/src/Ch04/slist.c", first: 62, last: 91, caption: [c, meet detection, entry race, cycle length])

#listing("dsa/samples/src/Ch04/Linked.cs", first: 63, last: 79, caption: [tortoise and hare, O(1) space])

The test builds a 10 node chain, splices the tail onto the third
node, and asserts the detection flips. The same machinery extends to
finding the cycle's entry point, the point where the distances
aligned, and to finding the middle of a list in one pass.

#listing("dsa/samples-go/ch04/slist.go", first: 81, last: 91, caption: [go, has cycle returns the meeting node for the second race])

#listing("dsa/samples-js/src/ch04-slist.mjs", first: 40, last: 59, caption: [javascript, meet, entry race, and cycle length])

#listing("dsa/samples-py/src/Ch04/slist.py", first: 54, last: 67, caption: [python, both races folded into one function])

#listing("dsa/samples-lua/ch04_slist.lua", first: 37, last: 63, caption: [lua, meet, entry, and length over table nodes])

The rho fixtures differ where the suites chose them. C, JavaScript,
and Lua bend 1 2 3 4 5 back onto the node holding 3 and pin the
entry, mu 2, lambda 3. Go bends the same list and pins the cycle
length 3. Python bends the tail onto 2, entry value 2, cycle length
4. C\# splices a 10 node chain onto the third node and asserts the
detection flips. The argument is identical everywhere, the second
race from the head lands on the entry because both walkers then sit
the same distance above it.

#diagram([floyd's rho, once both pointers are inside the cycle the gap closes by one per step], length: 13pt, {
  let nx = i => 2.2 + i * 2.1
  for i in range(10) {
    cdraw.circle((nx(i), 4.6), radius: 0.3, fill: luma(235), stroke: luma(100))
    cdraw.content((nx(i), 4.6), [#(i + 1)], size: 6pt)
  }
  for i in range(9) {
    cdraw.line((nx(i) + 0.3, 4.6), (nx(i + 1) - 0.3, 4.6), stroke: luma(100), mark: (end: ">"))
  }
  // the tail node splices back onto node 3
  cdraw.line((nx(9), 4.3), (nx(9), 3.0), stroke: luma(100))
  cdraw.line((nx(9), 3.0), (nx(2), 3.0), stroke: luma(100))
  cdraw.line((nx(2), 3.0), (nx(2), 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((nx(2) - 0.1, 5.6), (nx(9) + 0.1, 5.6), stroke: luma(100))
  cdraw.line((nx(2), 5.6), (nx(2), 5.85), stroke: luma(100)); cdraw.line((nx(9), 5.6), (nx(9), 5.85), stroke: luma(100))
  cdraw.content((nx(5) + 0.1, 6.2), [cycle, k = 8], size: 6.5pt)
  cdraw.content((nx(0) + 1.05, 3.6), [tail], size: 6.5pt)
  cdraw.circle((nx(4), 3.95), radius: 0.12, fill: luma(100))
  cdraw.content((nx(4) - 0.8, 3.95), [slow], size: 6pt)
  cdraw.circle((nx(8), 3.95), radius: 0.12, fill: luma(100))
  cdraw.content((nx(8) - 0.75, 3.95), [fast], size: 6pt)
  cdraw.content((11.6, 2.2), [each step closes the gap by one, modulo k], size: 6.5pt)
})

== the sentinel ring

The production shape of a doubly linked list is a ring around a
sentinel node. The sentinel deletes every null check: the list is
never empty, it always contains the sentinel, and `_sentinel.Next` is
the first element, `_sentinel.Prev` the last. In C the same ring is a
file-scope sentinel plus four splices.

The dry run: the fixture is the C\# ring across its three shapes,
both-end order, position-free removal, and the version counter,
asserted by the C\# suite; C, JavaScript, and Lua push 1, 0, 2, 9 and
read 9 0 1 2 instead.

+ AddLast b, AddLast c, AddFirst a: forward reads a b c, backward
  reads c b a, count 3, the sentinel invisible at both ends.
+ The int ring AddLast 1, 2, 3 hands back the node references, then
  Remove(b) splices 1 straight onto 3 with no traversal: 1, 3.
+ Remove(a) and Remove(c) drain it, forward reads empty, and
  AddLast(9) still lands: the sentinel never left.
+ MoveToFront(x) unsplices and reinserts at the head in two
  constant-time splices: x y z reads x y z.
+ Every structural change bumps the version, v0 + 1 on the add, v0 +
  2 after the remove, so in-flight enumeration is invalidated.

#diagram([the int ring run, add three, unsplice the middle, drain, reinsert, the same sentinel node at both ends of every frame], length: 13pt, {
  let frame = (y, label, inner, note) => {
    cdraw.content((0.7, y + 0.35), label, size: 6pt)
    cdraw.rect((2.8, y), (3.7, y + 0.7), fill: luma(205), radius: 0.02)
    cdraw.content((3.25, y + 0.35), [s], size: 6pt)
    for (i, v) in inner.enumerate() {
      let cx = 4.1 + i * 0.95
      cdraw.rect((cx, y), (cx + 0.95, y + 0.7), fill: luma(235), radius: 0.02)
      cdraw.content((cx + 0.475, y + 0.35), [#v], size: 6pt)
    }
    let ex = 4.1 + inner.len() * 0.95 + 0.35
    cdraw.rect((ex, y), (ex + 0.9, y + 0.7), fill: luma(205), radius: 0.02)
    cdraw.content((ex + 0.45, y + 0.35), [s], size: 6pt)
    cdraw.content((ex + 2.0, y + 0.35), note, size: 6pt)
  }
  frame(5.6, [after adds], ("1", "2", "3"), [forward 1 2 3])
  frame(4.3, [remove b], ("1", "3"), [two writes, no traversal])
  frame(3.0, [drained], (), [the two s boxes are one node])
  frame(1.7, [addlast 9], ("9",), [the ring never died])
  cdraw.content((4.0, 0.7), [count 3, 2, 0, 1: the sentinel constant], size: 6pt)
})

The 1, 3 unsplice, the 9 after the drain, and the version bumps are
the C\# pins, and the listings below build the ring in six languages.

#listing("dsa/samples-c/src/Ch04/ring.c", first: 26, last: 57, caption: [c, ring init, both-end pushes, remove by node])

The C\# class wraps the identical shape:

#listing("dsa/samples/src/Ch04/Linked.cs", first: 82, last: 113, caption: [the ring with sentinel, both-end insertion])

Removal by node reference is the structure's whole value: the node
knows both neighbors, no traversal happens. The test removes a
middle node, then the first, then the last, then re-adds after
emptying, and the sentinel keeps every case identical. The version
counter is the enumerator-safety discipline `LinkedList<T>` also
carries, structural changes invalidate in-flight iteration:

#listing("dsa/samples/src/Ch04/Linked.cs", first: 115, last: 151, caption: [position-free removal, both directions, move to front])

#diagram([the sentinel ring, never empty, both-end inserts and neighbor-known removal], length: 13pt, {
  let c = (5.5, 4.2)
  let ring = ((3.4, 4.2, [s], true), (5.5, 6.3, [a], false), (7.6, 4.2, [b], false), (5.5, 2.1, [c], false))
  // doubly linked edges around the ring
  let pairs = (((3.4, 4.2), (5.5, 6.3)), ((5.5, 6.3), (7.6, 4.2)), ((7.6, 4.2), (5.5, 2.1)), ((5.5, 2.1), (3.4, 4.2)))
  for p in pairs {
    let (a, b) = p
    let d = ((b.at(0) - a.at(0)), (b.at(1) - a.at(1)))
    let len = calc.sqrt(d.at(0) * d.at(0) + d.at(1) * d.at(1))
    let u = (d.at(0) / len, d.at(1) / len)
    cdraw.line((a.at(0) + u.at(0) * 0.45, a.at(1) + u.at(1) * 0.45), (b.at(0) - u.at(0) * 0.45, b.at(1) - u.at(1) * 0.45), stroke: luma(100), mark: (end: ">"))
  }
  for n in ring {
    cdraw.circle((n.at(0), n.at(1)), radius: 0.42, fill: if n.at(3) { luma(205) } else { luma(235) }, stroke: luma(100))
    cdraw.content((n.at(0), n.at(1)), n.at(2), size: 6.5pt)
  }
  cdraw.content((1.6, 4.2), [sentinel], size: 6pt)
  cdraw.content((16.0, 6.1), [never empty: sentinel always inside], size: 6.5pt)
  cdraw.content((16.0, 4.3), [insert = splice before the sentinel], size: 6.5pt)
  cdraw.content((16.0, 2.5), [remove by node: no traversal needed], size: 6.5pt)
  cdraw.content((16.0, 0.9), [version++ invalidates iteration], size: 6.5pt)
})

`MoveToFront` is the LRU cache operation in miniature, remove plus
reinsert at the head, both constant, which is why LRU caches are
built as a hash map into a ring of nodes, chapter 6 meets chapter 4.

The other four rings:

#listing("dsa/samples-go/ch04/ring.go", first: 25, last: 38, caption: [go, one splice helper feeds both pushes])

#listing("dsa/samples-js/src/ch04-ring.mjs", first: 16, last: 40, caption: [javascript, the ring class with both pushes and remove])

#listing("dsa/samples-py/src/Ch04/ring.py", first: 23, last: 44, caption: [python, insert after, both pushes, local remove])

#listing("dsa/samples-lua/ch04_ring.lua", first: 6, last: 27, caption: [lua, the sentinel table and its four splices])

C, JavaScript, and Lua pin the same both-end fixture, pushes 1, 0, 2,
9 land as 9 0 1 2, the middle 1 unlinks to 9 0 2, and after a full
drain the sentinel points at itself while remaining a valid node.
Go pins pushes to 0 1 2, removal to 2 3, and a reinsert after drain
to 9. Python walks both directions, 0 1 2 3 forward and its mirror
backward, removes a middle node to 0 1 3, and proves the emptied
ring folds onto the sentinel. C\# adds what the others leave out, a
version counter and `MoveToFront`, the LRU splice.

== when to reach for links

#flow(
  [when to reach for links, the honest ranking],
  node((0, 0), [what is the workload?]),
  node((-2.9, -1.8), [arrays and List<T> first #linebreak() on locality alone]),
  node((2.9, -1.8), [links when elements #linebreak() move by reference]),
  node((0, -3.8), [iteration heavy: never, #linebreak() each hop is a miss]),
  edge((0, 0), (-2.9, -1.8), "-|>"),
  edge((0, 0), (2.9, -1.8), "-|>"),
  edge((-2.9, -1.8), (0, -3.8), "-|>"),
  edge((2.9, -1.8), (0, -3.8), "-|>"),
)

The honest ranking in this language: arrays and `List<T>` first, the constant
factors of locality win almost everything. `LinkedList<T>` when
elements must be removed or moved by reference from several places at
once, an LRU, a scheduler wheel, a free list. Never for iteration
heavy or search heavy work, every hop is a cache miss that chapter 2
already priced. The BCL itself uses linked structures sparingly, and
the chapters ahead quietly prefer arrays with indices as node
handles, a heap in an array, a union-find in arrays, a trie as a flat
map, for exactly this reason.

The dry run: no suite carries this walk, the numbers are hand-derived
on chapter 2's line model, and the workload on trial is one pass over
2^20 = 1048576 elements followed by three removals.

+ The array lane packs 16 ints to a 64 byte line, so the pass touches
  1048576 / 16 = 65536 lines.
+ The linked lane gives every node its own allocation, a value plus a
  next pointer, and the allocator scatters them: 1048576 hops, one
  line each.
+ The ratio 1048576 / 65536 = 16 is chapter 2's stride-16 degenerate
  case, which is why iteration-heavy work never gets links.
+ The one win: removing 3 held nodes from a 1000 element vector, at
  the front, the middle, the end, shifts 999 + 499 + 0 = 1498
  elements, the ring splices each in 2 writes, 3 × 2 = 6, no search.
+ The ranking falls out: arrays first, links when elements move by
  reference, never when the loop dominates the cost.

#diagram([the walk price, packed array lanes against scattered nodes, then the removal contrast running the other way], length: 13pt, {
  cdraw.content((0.6, 6.5), [the walk], size: 6.5pt)
  for i in range(16) {
    cdraw.rect((0.8 + i * 0.62, 5.5), (1.42 + i * 0.62, 6.1), fill: luma(235), radius: 0.02)
  }
  cdraw.line((0.8, 6.4), (10.7, 6.4), stroke: luma(100))
  cdraw.line((0.8, 6.4), (0.8, 6.6), stroke: luma(100))
  cdraw.line((10.7, 6.4), (10.7, 6.6), stroke: luma(100))
  cdraw.content((5.75, 6.9), [array: one line holds 16 ints], size: 6pt)
  cdraw.content((13.0, 5.8), [1048576 ints: 65536 lines], size: 6pt)
  let spots = ((0.9, 3.0), (2.6, 2.6), (4.6, 3.2), (6.6, 2.6), (8.6, 3.1), (10.4, 2.6))
  for (i, p) in spots.enumerate() {
    cdraw.rect((p.at(0), p.at(1)), (p.at(0) + 0.75, p.at(1) + 0.6), fill: luma(235), radius: 0.02)
    cdraw.line((p.at(0) + 0.37, p.at(1) + 0.6), (p.at(0) + 0.37, p.at(1) + 0.9), stroke: (paint: luma(160), dash: "dashed"))
    if i < 5 {
      let q = spots.at(i + 1)
      cdraw.line((p.at(0) + 0.75, p.at(1) + 0.3), (q.at(0), q.at(1) + 0.3), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((0.6, 2.2), [linked: every hop, a fresh line], size: 6pt)
  cdraw.content((13.0, 2.9), [1048576 nodes: 1048576 lines], size: 6pt)
  cdraw.content((0.6, 1.3), [remove 3 held nodes from 1000], size: 6.5pt)
  cdraw.rect((0.8, 0.2), (6.6, 0.9), fill: luma(205), radius: 0.02)
  cdraw.content((3.7, 0.55), [vector: 1498 shifted], size: 6pt)
  cdraw.rect((7.2, 0.2), (13.0, 0.9), fill: luma(235), radius: 0.02)
  cdraw.content((10.1, 0.55), [ring: 3 × 2 = 6 writes], size: 6pt)
})

The 16 to 1 walk price against the 6 writes is the whole trade in two
numbers, arrays first unless elements move by reference.

== across the six languages

Build sizes count non-comment source lines over the featured files;
bundled checks count where the language puts them in the same file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [208], [libc only], [nodes come from static pools, no malloc anywhere in the fixtures, 21 checks in 2 files],
  [c\#], [122], [bcl only], [generic rings with a version counter, the only suite that invalidates in-flight iteration],
  [go], [127], [none], [unexported next pointers keep the list encapsulated, Tail and NodeAfter exist for the tests],
  [javascript], [99], [node stdlib], [identity comparison is the cycle test, === on node references],
  [python], [144], [stdlib only], [`__slots__` nodes, is comparison for the meet, floyd folds both races into one function],
  [lua], [165], [lib.lua harness], [a node is a plain table, the sentinel carries a label value],
)

sources: learn.microsoft.com, `LinkedList<T>` api page including the
sentinel-based implementation remarks, `LinkedListNode<T>`,
enumeration and thread safety notes, accessed 2026-09-08. Sample
behavior verified by `make verify-csharp`, 9 tests in chapter 4 of
the samples suite. The six-language layer verifies the same way:
2 C programs with 21 embedded checks, 7 Go tests, 7 `node --test`
cases, 16 Python checks across 2 files, and 9 Lua checks under
`run.lua`.
