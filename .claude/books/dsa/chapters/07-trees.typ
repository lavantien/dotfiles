#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= trees

The binary search tree is the first structure whose performance is a
property of its shape rather than its code. This chapter builds it,
breaks it with sorted input, and repairs it with rotations, then maps
the territory onto what the BCL actually ships.

== the search tree invariant

Everything left of a node is smaller, everything right is larger, so
a lookup is a guided binary search that costs one comparison per
level. C carries the core in two functions, insert by recursion,
find by loop.

The dry run: the fixture is 50, 30, 70, 20, 40, 60, 80 plus the
sorted storm 0 through 99, asserted by the C\# suite, while C, Java,
JavaScript, and Lua insert 5, 3, 8, 1, 4, 7, 9, 2, 6 for the same
contract.

+ Insert 50 at the root, then 30 left and 70 right, one comparison
  each.
+ 20 pays two, 20 < 50 then 20 < 30, and 40 pays the same pair the
  other way, 40 < 50 then 40 > 30, both landing under 30.
+ 60 and 80 mirror the right side at two comparisons each, and the
  seven keys close a perfect tree of height 3.
+ Inorder reads 20, 30, 40, 50, 60, 70, 80, sorted out of input
  that arrived level by level.
+ Rebuilt with sorted keys 0 through 99 the same inserts chain
  rightward to height 100, and TryGet(99) compares against every
  node on the chain, 99 + 1 = 100, the pinned meter readout, while
  the same 100 keys shuffled stay under height 20.

#diagram([the fixture build with insertion order numbered, then the meter walking the sorted chain], length: 13pt, {
  // left: the 7-key fixture tree, insertion order badged, inorder below
  let p = ((6.0, 6.3), (3.5, 5.0), (8.5, 5.0), (2.2, 3.7), (4.8, 3.7), (7.2, 3.7), (9.8, 3.7))
  let keys = (50, 30, 70, 20, 40, 60, 80)
  for (a, b) in ((0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6)) { cdraw.line(p.at(a), p.at(b), stroke: luma(220)) }
  for i in range(7) {
    cdraw.circle(p.at(i), radius: 0.37, fill: luma(235))
    cdraw.content(p.at(i), [#keys.at(i)], size: 6pt)
    cdraw.content((p.at(i).at(0) + 0.66, p.at(i).at(1) + 0.32), [#(i + 1)], size: 6pt)
    cdraw.rect((2.2 + i * 1.13, 2.2), (3.3 + i * 1.13, 2.95), fill: luma(235), radius: 0.02)
    cdraw.content((2.75 + i * 1.13, 2.575), [#(20 + i * 10)], size: 6pt)
  }
  cdraw.content((6.0, 1.5), [inorder: sorted, worst lookup 3 comparisons], size: 6pt)
  // right: the sorted-insert chain, one probe walk down it
  let chain = ((13.2, 6.5, 0), (14.4, 5.6, 1), (15.6, 4.7, 2), (17.4, 3.2, 98), (18.6, 2.3, 99))
  for i in range(4) { cdraw.line((chain.at(i).at(0), chain.at(i).at(1)), (chain.at(i + 1).at(0), chain.at(i + 1).at(1)), stroke: luma(100)) }
  for i in range(5) {
    cdraw.circle((chain.at(i).at(0), chain.at(i).at(1)), radius: 0.32, fill: luma(235))
    cdraw.content((chain.at(i).at(0), chain.at(i).at(1)), [#(chain.at(i).at(2))], size: 6pt)
  }
  cdraw.content((16.5, 4.05), [...], size: 6pt)
  cdraw.content((21.4, 5.3), [sorted inserts: height 100], size: 6pt)
  cdraw.content((21.4, 4.2), [tryget(99): 99 + 1 = 100], size: 6pt)
  cdraw.content((21.4, 3.1), [shuffled: height under 20], size: 6pt)
  cdraw.content((21.4, 2.0), [the code never changed], size: 6pt)
})

The 3 comparisons of the balanced build against the 100 on the
meter is the section in two numbers, and the listings below carry
both shapes.

#listing("dsa/samples-c/src/Ch07/bst.c", first: 33, last: 48, caption: [c, insert by recursion, find by loop])

#listing("dsa/samples-go/ch07/bst.go", first: 26, last: 52, caption: [go, insert and search as package functions])

Six more languages build the same tree, Java relinking each level
through the subtree its recursion returns:

#listing("dsa/samples-java/src/Ch07/Bst.java", first: 31, last: 46, caption: [java, insert by recursion relinking through return values, find by loop])

The C\# class carries a comparison meter for the same reason the
hash table carried a probe meter:

#listing("dsa/samples/src/Ch07/Trees.cs", first: 4, last: 35, caption: [c\#, the bst with a comparison meter on every operation])

#listing("dsa/samples-js/src/ch07-bst.mjs", first: 13, last: 26, caption: [javascript, insert and find as free functions])

#listing("dsa/samples-py/src/Ch07/bst.py", first: 23, last: 38, caption: [python, insert and search over slots nodes])

#listing("dsa/samples-lua/ch07_bst.lua", first: 6, last: 22, caption: [lua, insert and find over plain tables])

Every suite pins the same contract: inorder comes back sorted no
matter the insertion order, hits land on their node, misses return
nothing. C, Java, JavaScript, and Lua insert 5 3 8 1 4 7 9 2 6 and
read 1 through 9 back. Python inserts seven keys and deletes its way
down to an empty tree. Go guards insert and delete with a search
first, the only suite whose public methods refuse duplicates by
design. C\# is the only one that counts comparisons while it walks.

Insertion walks the same path and attaches a leaf where it falls
off. The three traversals are one recursion with the visit in
different positions, and level order is chapter 5's queue doing
breadth first over a tree:

#listing("dsa/samples-c/src/Ch07/traverse.c", first: 39, last: 77, caption: [c, three recursive walks and the array-queue level order])

#listing("dsa/samples-go/ch07/traverse.go", first: 37, last: 55, caption: [go, level order through a slice queue])

The other five languages walk the same fixture, Java's level order
advancing a head index over one array:

#listing("dsa/samples-java/src/Ch07/Traverse.java", first: 41, last: 80, caption: [java, three recursive walks and the array-queue level order over a head index])

Inorder is the payoff: it enumerates keys sorted regardless of shape,
which is why a tree can back an ordered dictionary and a hash table
cannot.

#listing("dsa/samples/src/Ch07/Trees.cs", first: 62, last: 84, caption: [c\#, inorder, preorder, postorder, and the queue-driven level order])

#listing("dsa/samples-js/src/ch07-traverse.mjs", first: 15, last: 41, caption: [javascript, the four walks as spread-recursive functions])

#listing("dsa/samples-py/src/Ch07/traverse.py", first: 30, last: 57, caption: [python, three recursions and a walking-head queue])

#listing("dsa/samples-lua/ch07_traverse.lua", first: 29, last: 63, caption: [lua, the four walks over table nodes])

The 7-node fixture over 1 through 7 is the anchor, and all seven pin
all four sequences: preorder 4 2 1 3 6 5 7, inorder 1 through 7,
postorder 1 3 2 5 7 6 4, level order 4 2 6 1 3 5 7. The
implementations differ only in queue discipline, C, Java, Lua, and
Python advance a head index over one array, Go reslices the front
away, and JavaScript shifts the front element, the same fifo three
ways.

#diagram([the same keys twice, shuffled input stays a shallow guided search, sorted input degenerates into a chain], length: 13pt, {
  // left: the same keys inserted shuffled, find 13 walks 8 12 14 13
  cdraw.content((5.9, 7.3), [shuffled insert], size: 6.5pt)
  let p = ((5.9, 6.2), (3.4, 5.0), (8.4, 5.0), (2.1, 3.8), (4.7, 3.8), (7.1, 3.8), (9.7, 3.8), (1.4, 2.6), (2.8, 2.6), (4.0, 2.6), (5.4, 2.6), (6.4, 2.6), (7.7, 2.6), (9.0, 2.6), (10.4, 2.6))
  let keys = (8, 4, 12, 2, 6, 10, 14, 1, 3, 5, 7, 9, 11, 13, 15)
  let links = ((0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6), (3, 7), (3, 8), (4, 9), (4, 10), (5, 11), (5, 12), (6, 13), (6, 14))
  let on-path = (0, 2, 6, 13)
  for (a, b) in links {
    let hot = (a in on-path) and (b in on-path)
    cdraw.line(p.at(a), p.at(b), stroke: if hot { luma(100) } else { luma(220) })
  }
  for i in range(15) {
    cdraw.circle(p.at(i), radius: 0.34, fill: if i in on-path { luma(205) } else { luma(235) })
    cdraw.content(p.at(i), [#keys.at(i)], size: 6pt)
  }
  cdraw.content((5.9, 1.4), [any lookup at most 4 comparisons], size: 6.5pt)

  // right: the same keys inserted in order, one right-leaning chain
  cdraw.content((18.3, 7.3), [sorted insert], size: 6.5pt)
  let c = ((16.3, 6.2), (17.5, 5.05), (18.7, 3.9), (19.9, 2.75))
  for i in range(3) { cdraw.line(c.at(i), c.at(i + 1), stroke: luma(100)) }
  for i in range(4) {
    cdraw.circle(c.at(i), radius: 0.34, fill: luma(235))
    cdraw.content(c.at(i), [#(i + 1)], size: 6pt)
  }
  cdraw.line((20.1, 2.55), (21.1, 1.55), stroke: (paint: luma(220), dash: "dashed"))
  cdraw.circle((21.4, 1.2), radius: 0.34, fill: luma(205))
  cdraw.content((21.4, 1.2), [100], size: 6pt)
  cdraw.content((17.6, 1.5), [height 100], size: 6.5pt)
  cdraw.content((17.9, 0.3), [find 100: 100 comparisons], size: 6.5pt)
})

#callout("warning", "the shape is the input's fault", [
  Insert 100 keys in sorted order and the tree is a linked list,
  height 100, the last lookup takes 100 comparisons, both pinned by
  tests. Insert the same keys shuffled and height lands under 20.
  Nothing in the code changed. An unbalanced bst promises logarithmic
  search only for random input, and sorted input is common enough in
  real systems, timestamps, ids, auto-increment counters, that the
  promise must be engineered.
])

== deletion, the three cases

Removing a leaf drops it. Removing a node with one child splices the
child up. Removing a node with two children swaps in the successor,
the leftmost node of the right subtree, which preserves the invariant
because it is the smallest key greater than the removed one.

The dry run: the fixture is the eight keys 50, 30, 70, 20, 40, 60,
80, 35, asserted by the C\# suite, while C, Java, JavaScript, and Lua
run 5, 3, 8, 1, 4, 7, 9, 2, 6 and erase the leaf 2, the one-child 7,
and the two-child root 5.

+ 35 arrives last and walks deepest: 35 < 50, 35 > 30, 35 < 40,
  three comparisons to its slot under 40.
+ Remove(20) drops a leaf, and inorder reads 30, 35, 40, 50, 60,
  70, 80.
+ Remove(30) splices its only subtree up, 40 with 35 below takes
  the slot: 35, 40, 50, 60, 70, 80.
+ Remove(50) is the two-child root, and the successor is the
  leftmost of the right subtree, 60.
+ 60 copies in and leaves a slot where it had no left child, the
  one-child case by construction, and inorder lands 35, 40, 60, 70,
  80 at count 5.
+ Remove(999) finds nothing and the count stays 5.

#table(
  columns: (auto, auto, 1.4fr, auto),
  inset: 4pt,
  table.header([*remove*], [*case*], [*inorder after*], [*count*]),
  [20], [leaf], [30 35 40 50 60 70 80], [7],
  [30], [one child], [35 40 50 60 70 80], [6],
  [50], [two children], [35 40 60 70 80], [5],
  [999], [absent], [35 40 60 70 80], [5],
)

The count resting at 5 after three removals is the pinned landing,
and the listings below carry all three cases.

#listing("dsa/samples-c/src/Ch07/bst.c", first: 50, last: 72, caption: [c, the three-case erase with the successor swap])

#listing("dsa/samples-go/ch07/bst.go", first: 66, last: 88, caption: [go, deletion as one switch over the three cases])

#listing("dsa/samples-java/src/Ch07/Bst.java", first: 48, last: 70, caption: [java, the three-case erase with the successor swap, relinked through return values])

#listing("dsa/samples/src/Ch07/Trees.cs", first: 86, last: 151, caption: [c\#, find and insert, then the three-case removal via successor swap])

#listing("dsa/samples-js/src/ch07-bst.mjs", first: 28, last: 46, caption: [javascript, erase with the successor pulled up])

#listing("dsa/samples-py/src/Ch07/bst.py", first: 41, last: 59, caption: [python, delete with the survivor promoted])

#listing("dsa/samples-lua/ch07_bst.lua", first: 24, last: 42, caption: [lua, erase over table nodes])

C, Java, JavaScript, and Lua run the fixture 5 3 8 1 4 7 9 2 6 and
pin the same three removals, the leaf 2, the one-child node 7, and
the two-child root 5 whose successor 6 takes over, with inorder
sorted after every step. Python works seven keys and drains to an
empty tree, its two-child case swapping 8's successor 9. Go deletes
through one switch and replays the leaf, one-child, and successor
cases in its tests. The successor swap hides a subtlety every
listing covers: after copying the successor into the node, the code
must remove the successor from the right subtree, where it is
guaranteed to have no left child, a one-child case by construction.

#flow(
  [removal, three cases by child count, the successor swap ends in the one-child case],
  node((0, 0), [remove k]),
  node((-3.2, 2.4), [no children, #linebreak() drop the leaf]),
  node((0, 2.4), [one child, #linebreak() splice it up]),
  node((3.2, 2.4), [two children, #linebreak() swap in the successor]),
  node((3.2, 4.8), [the successor is the leftmost #linebreak() of the right subtree]),
  node((3.2, 7.0), [it has no left child, #linebreak() so removing it is #linebreak() the one-child case]),
  edge((0, 0), (-3.2, 2.4), "-|>"),
  edge((0, 0), (0, 2.4), "-|>"),
  edge((0, 0), (3.2, 2.4), "-|>"),
  edge((3.2, 2.4), (3.2, 4.8), "-|>"),
  edge((3.2, 4.8), (3.2, 7.0), "-|>"),
)

== avl, the rotation reflex

The AVL tree keeps the height difference of every node's children at
most 1 and repairs violations on the way back up the insertion path.
Four shapes exist, two single rotations and two doubles, and the
repair is the same decision everywhere, look at the balance of the
heavy child. C folds the decision into the insert itself.

The dry run: the fixture is sorted inserts 0 through 999 plus the
four three-key shapes, asserted by the C\# suite, while C, Java,
JavaScript, and Lua pin the same shapes and ascending 1 through 15
at height 4.

+ Sorted keys are the storm: the plain tree above chains 100 of
  them to height 100.
+ The first repair lands at key 2, where 0, 1, 2 is a right-right
  stick: one left rotation roots 1 with children 0 and 2, height 2.
+ Every insert unwinds its path and rotates wherever the child
  heights differ by 2, and the imbalance probe reads at most 1 for
  the whole run.
+ 1000 keys finish at height 12 or under, 2^10 = 1024 leaves head
  room in 12 levels.
+ The four shapes 3 2 1, 1 2 3, 3 1 2, and 1 3 2 each end height
  2, the left-left case a perfect tree with imbalance 0.
+ Rotations above zero and inorder 0 through 999 close the run:
  sorted input forced the repairs and still lost.

#diagram([ascending keys, one repair per boundary, the root doubling as the count grows: 2, 4, 8], length: 13pt, {
  // three avl states over 1..3, 1..7, 1..15, roots 2, 4, 8
  let put = (x, y, k, hot) => {
    cdraw.circle((x, y), radius: 0.31, fill: if hot { luma(205) } else { luma(235) })
    cdraw.content((x, y), [#k], size: 6pt)
  }
  let link = (a, b) => cdraw.line(a, b, stroke: luma(220))
  let t3 = ((2.2, 6.2), (1.3, 4.9), (3.1, 4.9))
  for (a, b) in ((0, 1), (0, 2)) { link(t3.at(a), t3.at(b)) }
  put(2.2, 6.2, 2, true); put(1.3, 4.9, 1, false); put(3.1, 4.9, 3, false)
  cdraw.content((2.2, 3.8), [3 keys, root 2, one rotation], size: 6pt)
  let t7 = ((6.6, 6.2), (5.4, 4.9), (7.8, 4.9), (4.9, 3.6), (5.9, 3.6), (7.3, 3.6), (8.3, 3.6))
  for (a, b) in ((0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6)) { link(t7.at(a), t7.at(b)) }
  for i in range(7) { put(t7.at(i).at(0), t7.at(i).at(1), (4, 2, 6, 1, 3, 5, 7).at(i), i == 0) }
  cdraw.content((6.6, 2.7), [7 keys, root 4], size: 6pt)
  let t15 = ((14.2, 6.2), (12.0, 4.9), (16.4, 4.9), (10.9, 3.6), (13.1, 3.6), (15.3, 3.6), (17.5, 3.6), (10.4, 2.3), (11.4, 2.3), (12.6, 2.3), (13.6, 2.3), (14.8, 2.3), (15.8, 2.3), (17.0, 2.3), (18.0, 2.3))
  for (a, b) in ((0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6), (3, 7), (3, 8), (4, 9), (4, 10), (5, 11), (5, 12), (6, 13), (6, 14)) { link(t15.at(a), t15.at(b)) }
  for i in range(15) { put(t15.at(i).at(0), t15.at(i).at(1), (8, 4, 12, 2, 6, 10, 14, 1, 3, 5, 7, 9, 11, 13, 15).at(i), i == 0) }
  cdraw.content((14.2, 1.3), [15 keys, root 8, height 4], size: 6pt)
  cdraw.content((21.8, 5.8), [root doubles with the count], size: 6pt)
  cdraw.content((21.8, 4.7), [sorted 1000: height <= 12], size: 6pt)
  cdraw.content((21.8, 3.6), [imbalance never past 1], size: 6pt)
})

The 12 over 1000 sorted keys against the plain tree's 100 over 100
is the repair doing its job, and the listings below meter it.

#listing("dsa/samples-c/src/Ch07/balance.c", first: 60, last: 84, caption: [c, avl insert with the four rotation cases inline])

#listing("dsa/samples-go/ch07/balance.go", first: 75, last: 105, caption: [go, insert then rebalance by the child's balance factor])

The same reflex in the other five languages, Java choosing the case
by the inserted value against the child's key:

#listing("dsa/samples-java/src/Ch07/Balance.java", first: 30, last: 83, caption: [java, cached heights, both rotations, avl insert with the four cases inline])

#listing("dsa/samples/src/Ch07/Trees.cs", first: 188, last: 280, caption: [c\#, the avl with rotation counter and imbalance probe])

A rotation moves a child up and a subtree across, three pointer
assignments plus two height updates, and the invariant check is pure
arithmetic on cached heights:

#listing("dsa/samples/src/Ch07/Trees.cs", first: 281, last: 334, caption: [c\#, rebalance, the double-rotation cases, both rotations])

The tests pin the headline numbers: 1000 sorted inserts leave height
at most 12 where the plain tree reaches 1000, the imbalance probe
never exceeds 1, and the rotation counter proves sorted input is what
forces rotations. The four shape tests insert three keys in each
order, two single and two double rotation cases, and all end height 2.

#listing("dsa/samples-js/src/ch07-balance.mjs", first: 31, last: 49, caption: [javascript, avl insert with the case labels inline])

#listing("dsa/samples-py/src/Ch07/balance.py", first: 53, last: 72, caption: [python, insert with balance factors read off cached heights])

#listing("dsa/samples-lua/ch07_balance.lua", first: 36, last: 58, caption: [lua, insert with the four cases commented])

The four shapes pin identically in C, Java, JavaScript, and Lua:
3 2 1, 1 2 3, 3 1 2, and 1 3 2 all collapse to the root 2 with
children 1 and 3, and ascending 1 through 15 leaves height 4 rooted
at 8. Python runs the four shapes plus the classic 10 20 30 40 50 25
sequence rooting at 30 with height 3. The case choice reads two
routes to the same answer: Go asks the heavy child for its balance
factor, while C, Java, JavaScript, Lua, and Python compare the
inserted value against the child's key. C\# meters rotations, the
only balance factor the others leave uncounted.

#flow(
  [the rotation reflex, the heavy stick before and after one left rotation],
  node((0, 0), [z]),
  node((1.4, 1.2), [y]),
  node((2.8, 2.4), [x]),
  edge((0, 0), (1.4, 1.2), "-|>"),
  edge((1.4, 1.2), (2.8, 2.4), "-|>"),
  edge((3.3, 0.5), (5.0, 0.5), "-|>", label: [rotate left at z]),
  node((5.2, 0), [y]),
  node((6.6, 1.2), [x]),
  node((3.9, 1.2), [z]),
  edge((5.2, 0), (3.9, 1.2), "-|>"),
  edge((5.2, 0), (6.6, 1.2), "-|>"),
)

== what the bcl ships

#diagram([what the bcl ships, red-black recoloring lazier than avl, sortedlist a sorted array pair with o(n) inserts, hash for point lookups], length: 13pt, {
  let cols = ((0.6, 8.0), (8.0, 15.2), (15.2, 19.6), (19.6, 23.2))
  let rows = ((5.5, 6.5), (4.3, 5.3), (3.1, 4.1), (1.9, 2.9))
  let head = ([structure], [inside], [point read], [ranges])
  let body = (
    ([SortedDictionary], [red-black tree], [O(log n)], [yes]),
    ([SortedList], [sorted array pair], [O(log n)], [yes]),
    ([Dictionary], [bucket chains], [O(1)], [no]),
  )
  for c in range(4) {
    cdraw.rect((cols.at(c).at(0), rows.at(0).at(0)), (cols.at(c).at(1), rows.at(0).at(1)), fill: luma(205), radius: 0.02)
    cdraw.content(((cols.at(c).at(0) + cols.at(c).at(1)) / 2, 6.0), head.at(c), size: 6pt)
  }
  for r in range(3) {
    for c in range(4) {
      cdraw.rect((cols.at(c).at(0), rows.at(r + 1).at(0)), (cols.at(c).at(1), rows.at(r + 1).at(1)), fill: luma(235), radius: 0.02)
      cdraw.content(((cols.at(c).at(0) + cols.at(c).at(1)) / 2, rows.at(r + 1).at(0) + 0.5), body.at(r).at(c), size: 6pt)
    }
  }
  cdraw.content((11.9, 1.3), [point lookups want the hash], size: 6.5pt)
  cdraw.content((11.9, 0.1), [ranges and neighbors want a tree], size: 6.5pt)
})

`SortedDictionary<K,V>` is a red-black tree, the same invariant
engineered with recoloring instead of strict heights, and `SortedSet`
is the same tree keyed by values. Red-black rebalances less eagerly
than AVL, fewer rotations per insert at the cost of slightly taller
trees, which is the standard production trade. `SortedList<K,V>` is
not a tree at all, it is a sorted array pair with binary search,
fast reads and O(n) inserts, right for read-mostly tables. The rule:
need ordering, ranges, predecessor and successor queries, use a tree,
need only point lookups, chapter 6's hash wins on constants.

The dry run: no suite carries the shipped containers, the numbers
are hand-derived, and the trade on trial is SortedList's shifts
against the tree's writes.

+ Name the workload first: point lookups only point at the hash,
  ranges and neighbors at a tree, read-mostly at the sorted array
  pair.
+ Descending inserts 40, 30, 20, 10 into SortedList each binary
  search to slot 0 and shift the tail: 0 + 1 + 2 + 3 = 6 element
  moves for 4 keys.
+ The same four into SortedDictionary are 4 node writes, and no
  element ever shifts, shape is the rebalancer's problem.
+ Point reads stay cheap on both sorted shapes: 4 keys resolve in
  at most 3 probes, 1000 keys in at most 10, 2^10 = 1024.
+ The range 20 through 40 is a walk between two boundary searches
  on the tree, a trip the hash table cannot offer at any price.

#diagram([four descending inserts, the array pair shifting its whole tail while the tree writes one node at a time], length: 13pt, {
  // top: sortedlist frames, the shifted cells shaded
  let frames = (((40,), 0), ((30, 40), 1), ((20, 30, 40), 2), ((10, 20, 30, 40), 3))
  for (k, f) in frames.enumerate() {
    let (cells, moved) = f
    let x = 0.8 + k * 4.9
    for (j, v) in cells.enumerate() {
      cdraw.rect((x + j * 0.95, 5.5), (x + j * 0.95 + 0.9, 6.25), fill: if j < moved { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + j * 0.95 + 0.45, 5.875), [#v], size: 6pt)
    }
    cdraw.content((x, 4.95), [#(cells.at(0)) lands at 0, #moved moves], size: 6pt)
  }
  cdraw.content((0.8, 7.0), [sortedlist\<k\>, the four keys descending], size: 6.5pt)
  // bottom: the tree lane, one node per insert, nothing shifts
  let tp = ((2.0, 2.7), (3.3, 1.8), (4.6, 0.9), (5.9, 0.0))
  for i in range(3) { cdraw.line(tp.at(i), tp.at(i + 1), stroke: luma(220)) }
  for i in range(4) {
    cdraw.circle(tp.at(i), radius: 0.32, fill: luma(235))
    cdraw.content(tp.at(i), [#((40, 30, 20, 10).at(i))], size: 6pt)
  }
  cdraw.content((0.8, 3.5), [sorteddictionary\<k\>, one node per insert], size: 6.5pt)
  cdraw.content((0.8, -0.8), [the rotation reflex above keeps even this chain shallow], size: 6pt)
  cdraw.content((12.0, 2.7), [array pair: 0 + 1 + 2 + 3 = 6 moves], size: 6pt)
  cdraw.content((12.0, 1.8), [tree: 4 writes, 0 moves], size: 6pt)
})

The 6 against the 4 is the table above in one run, read-mostly
buys the array pair and anything that moves wants the tree.

== across the seven languages

Build sizes count non-comment source lines over the featured files;
bundled checks count where the language puts them in the same file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [309], [libc only], [nodes come from static pools, recursion over pointers, 31 checks in 3 files],
  [go], [232], [none], [unexported fields keep the height private, rebalance reads the child's balance factor],
  [java], [306], [jdk 27 stdlib], [TreeMap exists in the stdlib and goes unused, insert and erase relink through return values over one shared static root, the avl case reads the inserted value against the child's key],
  [c\#], [293], [bcl only], [generic trees with comparison and rotation meters, the only suite that counts either],
  [javascript], [119], [node stdlib], [spread recursion builds new arrays at every level, fine for fixtures, garbage at scale],
  [python], [208], [stdlib only], [`__slots__` nodes, drains the whole tree through all three delete shapes],
  [lua], [248], [lib.lua harness], [a node is a table with nil-able links, and and or pick the walk direction],
)

sources: learn.microsoft.com, `SortedDictionary<TKey,TValue>` remarks
on the red-black implementation, `SortedList<TKey,TValue>` remarks on
the sorted-array layout and operation costs, accessed 2026-09-08.
Sample behavior verified by `make verify-csharp`, 10 tests in
chapter 7 of the samples suite. The seven-language layer verifies
the same way: 3 C programs with 31 embedded checks, 8 Go tests, the
java runner's 31 Ch07 checks over 3 files under `run-java-samples`,
6 `node --test` cases, 24 Python checks across 3 files, and 14 Lua
checks under `run.lua`.
