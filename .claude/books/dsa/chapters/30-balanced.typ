#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= balanced trees and order statistics

Randomized balance buys logarithmic operations without any rotation
rules to prove. A treap stores a bst by key and a heap by a random
priority, and the two orders together hold the shape near balanced on
expectation, so split, merge, insert, erase, and lazy range adds all
run in expected logarithmic time. This chapter builds that machine,
pairs it with two meldable heaps that lean on the same coin-flip
reasoning, and closes with the two order-statistic structures built on
top: rank and select over a fenwick tree of frequencies, and the
implicit treap that keys nodes by array position instead. The
flagship application is icpc world finals 2019 problem F (book 10,
chapter 10), a rainfall dp that runs on exactly this treap, and its
rebuild-versus-depth-gate decision is the one the sample suites pin.

== the treap

A binary search tree by key, a max-heap by priority. Every node
carries a random priority drawn from a counter stream, the splitMix32
sequence incremented once per allocation, and the invariant is
two-sided: keys sort left to right inside the tree, priorities heap
upward with the maximum at the root. Two recursive functions do all
the work. Split walks the key order and tears the tree into keys
below the threshold and the rest. Merge joins two trees whose key
ranges do not overlap by letting the larger priority become the parent.
Insert is split, split again to isolate the one key slot, replace the
value in place or allocate, then merge the three pieces back. Erase
merges the children of the isolated node. A range operation splits
twice around the inclusive key range, reads or mutates the isolated
middle as one subtree, and merges back.

The lazy range add is the subtle part. A pending add sits on a node
and applies to the whole subtree below it, so the node's stored sum
covers itself and its children's relative sums plus its own pending
add once per folded child: child sums are relative to the child, the
node's lz rides on top of them. Push moves the pending add onto both
children before any descent that reads or relinks below the node, the
same discipline as the lazy tags of #xref-to("dsa", "ranges").

The dry run: the fixture inserts keys 5, 2, 8, 1, 4, 7, 9, 3, 6 with
values ten times the key, the C\# suite pinning the lazy walk with
the sibling suites on the same script.

+ The build lands the pinned shape first: inorder 1 through 9 with
  values 10 through 90, depth 5, zero rebuilds.
+ The whole-range sum reads the root once: 10 × (1 + 2 + ... + 9) =
  10 × 45 = 450.
+ The lazy add splits twice around keys 2 through 6 and parks +10 on
  the isolated middle of five keys: 450 + 5 × 10 = 500.
+ The reads split clean: keys 3 to 5 give 40 + 50 + 60 = 150, keys 7
  to 9 outside the add give 70 + 80 + 90 = 240, key 4 alone gives 50.
+ Erase(4) drops the 50, 500 - 50 = 450 at size 8, then a -5 add over
  everything leaves sum(2, 3) at (30 - 5) + (40 - 5) = 60.
+ The gate meter: 31 sequential inserts under the default gate
  3 × 5 + 8 = 23 stay at depth 9, zero rebuilds, sum 496, while gate
  4 trips 7 rebuilds and lands depth 6.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*op*], [*arithmetic*], [*lands*]),
  [insert 9 keys], [10 × 45 = 450], [size 9, depth 5, 0 rebuilds],
  [add 10 over 2-6], [450 + 5 × 10 = 500], [sum 500],
  [reads 3-5, 7-9, 4-4], [40 + 50 + 60, 70 + 80 + 90, 50], [150, 240, 50],
  [erase 4], [500 - 50 = 450], [size 8],
  [add -5 over 1-9], [(30 - 5) + (40 - 5) = 60], [sum(2, 3) = 60],
  [31 inserts, gate 23], [3 × 5 + 8 = 23], [depth 9, 0 rebuilds, sum 496],
  [31 inserts, gate 4], [], [depth 6, 7 rebuilds],
)

The 500 down to 60 lazy walk with the 7 rebuilds at gate 4 are the
pinned rows, and the listings below run them in six languages.

#listing("dsa/samples-c/src/Ch30/treap.c", first: 95, last: 143, caption: [c, split by key and merge by priority, the depth meter bumped on entry and unwound on exit])
#listing("dsa/samples/src/Ch30/Treap.cs", first: 98, last: 149, caption: [c\#, the same pair as tuple-returning methods, pull after every relink])
#listing("dsa/samples-go/ch30/treap.go", first: 104, last: 150, caption: [go, split and merge with the meter in the treap struct, push before each descent])
#listing("dsa/samples-js/src/ch30-treap.mjs", first: 92, last: 134, caption: [javascript, the split and merge core, private depth fields, destructured pair returns])
#listing("dsa/samples-py/src/Ch30/treap.py", first: 78, last: 112, caption: [python, split then merge, push on entry, pull on the way out])
#listing("dsa/samples-lua/ch30_treap.lua", first: 60, last: 97, caption: [lua, the same pair, the meter unwound on both return paths])

Every public operation records its maximum split or merge recursion
depth and compares it against a gate. The default gate is 3 times
ceil(log2(n+1)) plus 8, constructor-overridable. A depth past the
gate flags the structure dirty, and the next public operation rebuilds
before running: flatten inorder with the lazy adds applied, rebuild
by the balanced median recursion, assign priorities 0xffffffff minus
depth so the heap order matches the fresh shape exactly, and reset
the allocation counter. The rebuild costs O(n), and the amortized
argument is that an adversarial burst has to spend operations to
deepen the tree before each rebuild can fire. Against
#xref-to("dsa", "trees") the trade is explicit: the avl tree there
guarantees worst-case logarithmic depth through rotations, the treap
only expects it, but the treap's split and merge compose into range
logic the rotation machinery does not give directly.

The fixture families pin identical numbers in all six suites. The
shape family inserts keys 5, 2, 8, 1, 4, 7, 9, 3, 6 with values ten
times the key and reads inorder 1 through 9 with values 10 through
90, size 9, depth 5, the preorder 9, 4, 3, 1, 2, 6, 5, 8, 7, and zero
rebuilds. The algebra family splits at 5 into sizes 4 and 5 holding
keys 1 through 4 and 5 through 9, splits at 0 and at 10 into 0/9 and
9/0, and merges each back to a preorder identical to the base. The
lazy family sums the whole key range at 450, adds 10 over keys 2
through 6, and reads 500, 150, 240, and 50 over ranges 1-9, 3-5,
7-9, and 4-4, with the inorder values pinning the per-key state.
Erasing key 4 returns the total to 450 at size 8, and a -5 add over
everything leaves sum(2,3) at 60.

The gate family is the honest one. Over 31 sequential inserts the
default gate 23 never trips: depth 9, zero rebuilds, sum 496. A tight
gate trips 7 rebuilds, lands at depth 6, keeps inorder 1 through 31
intact, and pins the rebuilt preorder 15, 8, 4, 2, 1, 3, 6, 5, 7,
12, 10, 9, 11, 14, 13, 23, 19, 17, 16, 18, 21, 20, 22, 27, 25, 24,
26, 29, 28, 30, 31. All six languages reach that shape with gate 4,
every meter tracking live recursion, bumped on entry and unwound on
each return. The edge family closes the contract: an empty treap
sizes 0 and sums 0, inserting key 7 twice replaces the value in place
with no allocation, and erasing an absent key is a no-op.

#diagram([the 9-key treap with the 2 to 6 range isolated for a lazy add, and the depth-gated rebuild from a deep chain into the median shape], length: 13pt, {
  // left panel: the treap, preorder 9,4,3,1,2,6,5,8,7, x by inorder slot
  let xof = (k) => 1.2 + (k - 1) * 1.5
  let yof = (d) => 8.8 - d * 1.2
  let nodes = ((9, 0), (4, 1), (3, 2), (6, 2), (1, 3), (2, 4), (5, 3), (8, 3), (7, 4))
  let at = (k, d) => (xof(k), yof(d))
  let edge = (a, ad, b, bd) => cdraw.line(at(a, ad), at(b, bd), stroke: luma(190))
  edge(9, 0, 4, 1); edge(4, 1, 3, 2); edge(4, 1, 6, 2); edge(3, 2, 1, 3)
  edge(1, 3, 2, 4); edge(6, 2, 5, 3); edge(6, 2, 8, 3); edge(8, 3, 7, 4)
  for (k, d) in nodes {
    let hot = k >= 2 and k <= 6
    cdraw.circle(at(k, d), radius: 0.32, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content(at(k, d), [#k], size: 7pt)
  }
  cdraw.content((7.2, 9.6), [inorder 1..9, depth 5, rebuilds 0], size: 6pt)
  // the dashed frame around exactly the shaded keys
  cdraw.rect((2.25, 3.35), (9.15, 8.05), stroke: (paint: luma(160), dash: "dashed"), radius: 0.05)
  cdraw.content((7.2, 0.9), [shaded: keys 2..6, the subtree under 4 minus key 1 and the 8-7 branch], size: 6pt)
  cdraw.content((7.2, 0.1), [split at 2 unhooks key 1, the +10 add parks on 4], size: 6pt)
  // right panel: deep chain -> rebuild -> balanced
  let cx = 15.2
  for d in range(6) {
    cdraw.circle((cx, 8.8 - d * 0.95), radius: 0.24, fill: luma(240), stroke: luma(120))
  }
  for d in range(5) {
    cdraw.line((cx, 8.8 - d * 0.95), (cx, 8.8 - (d + 1) * 0.95), stroke: luma(190))
  }
  cdraw.content((cx, 9.6), [depth past the gate], size: 6pt)
  cdraw.content((cx, 2.55), [dirty flag set, next entry rebuilds], size: 6pt)
  cdraw.line((cx, 2.15), (cx, 1.75), stroke: luma(100), mark: (end: ">"))
  // balanced 7-node median build
  let lvl = (d, off) => (cx + (off - 1.5) * 1.15, 1.4 - d * 0.85)
  for (p, q) in (((0, 1.5), (1, 0.5)), ((0, 1.5), (1, 2.5)), ((1, 0.5), (2, 0.0)), ((1, 2.5), (2, 2.0))) {
    cdraw.line(lvl(..p), lvl(..q), stroke: luma(190))
  }
  for p in ((0, 1.5), (1, 0.5), (1, 2.5), (2, 0.0), (2, 2.0)) {
    cdraw.circle(lvl(..p), radius: 0.24, fill: luma(205), stroke: luma(120))
  }
  cdraw.content((cx + 2.2, 1.4), [median build], size: 6pt)
  cdraw.content((cx + 2.2, 0.6), [pri = 0xffffffff - depth], size: 6pt)
  cdraw.content((cx + 2.2, -0.2), [counter reset, O(n)], size: 6pt)
  cdraw.content((cx + 2.2, -1.0), [gate = 3 ceil(log2(n+1)) + 8], size: 6pt)
})

The application is icpc world finals 2019 problem F (book 10, chapter
10), directing rainfall. The shipped solver's piecewise dp lives on a
run treap with lazy adds, subtree min and max, and splits at cell
boundaries, and its authors faced exactly this chapter's decision:
the go and c solvers rebuild on a fixed every-4096 cadence, the lua
solver runs a depth gate of 96, and the measured maximum recursion
depth across the judge inputs is 52. The chapter sample is the
explicit-key teaching form of that vehicle, and the pf_runs
implementation in the icpc book is the contest-grade sibling.

== the splay tree

The splay tree answers the same question without randomness. Every
access splays its node to the root through three local shapes: zig,
one rotation when the parent is the root, zig-zig for a straight
grandparent-parent-node chain, rotated from the top down, and zig-zag
for a bent chain, two rotations that lift the node two levels. The
amortized O(log n) bound comes from a potential argument, summing
logarithms of subtree sizes across the tree and showing each splay
pays for itself plus a bounded potential drop, so a sequence of m
operations on n keys costs O((m + n) log n) with no probability
anywhere. The payoff beyond the bound is working-set locality:
recently touched keys sit near the root, so hot workloads run faster
than the worst case, and the access-lease structure is what link and
cut trees consume downstream.

Positioned against the neighbors: the treap above reaches the same
amortized expectation through random priorities and composes through
split and merge, while the splay tree reaches it through pointer
surgery on every access and composes through joins. The avl tree of
#xref-to("dsa", "trees") keeps a worst-case bound and no locality at
all. No samples ship for it: the interesting claim is the potential
argument rather than another metered port, and the treap suites
already carry the randomized half of the comparison.

The dry run: no suite carries the splay tree, the numbers here are
hand-derived, and the run inserts 1 through 5 in order.

+ Every insert lands right of the last, so the tree is a pure right
  chain under root 1 with node 5 at depth 4.
+ Access 5 meets a straight chain, so one zig-zig rotates 3 under 4
  then 4 under 5: node 5 rises to depth 2 with 4 and 3 parked on its
  left.
+ The chain is straight again, so a second zig-zig rotates 1 under 2
  then 2 under 5, and 5 is the root: 2 its left child holding 1 and
  4, with 3 under 4, tree depth 3.
+ Access 1 next: the path 5, 2, 1 is a straight left chain, one
  zig-zig rotates 5 under 2 then 2 under 1, and 1 is the root with
  the formerly hot 5 sunk to depth 2.
+ Inorder never moves off 1, 2, 3, 4, 5 through any of it, the
  rotations only ever relink.
+ The two accesses cost 4 + 2 = 6 rotations total, and the second
  found its key two levels from the root, the locality the bound
  pays for.

#diagram([the run as three tree states, the right chain, root 5 after the first access, root 1 after the second], length: 13pt, {
  let n = (x, y, k, hot: false) => {
    cdraw.circle((x, y), radius: 0.32, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  let e = (p, q) => cdraw.line(p, q, stroke: luma(190))
  // state 1: the pure right chain
  let c1 = ((1.2, 7.4), (2.5, 6.4), (3.8, 5.4), (5.1, 4.4), (6.4, 3.4))
  for i in range(4) { e(c1.at(i), c1.at(i + 1)) }
  for i in range(5) { n(..c1.at(i), [#(i + 1)], hot: i == 4) }
  cdraw.content((3.0, 8.3), [after the inserts: depth 4], size: 6pt)
  // state 2: root 5, left child 2 holding 1 and 4, 3 under 4
  e((9.6, 7.4), (8.2, 6.1))
  e((8.2, 6.1), (7.2, 4.8)); e((8.2, 6.1), (9.4, 4.8)); e((9.4, 4.8), (8.6, 3.5))
  n(9.6, 7.4, [5], hot: true); n(8.2, 6.1, [2])
  n(7.2, 4.8, [1]); n(9.4, 4.8, [4]); n(8.6, 3.5, [3])
  cdraw.content((9.0, 8.3), [access 5: two zig-zigs, depth 3], size: 6pt)
  // state 3: root 1, right chain 2, 5, with 4 and 3 hanging left of 5
  e((15.2, 7.4), (16.3, 6.1)); e((16.3, 6.1), (17.4, 4.8))
  e((17.4, 4.8), (16.4, 3.5)); e((16.4, 3.5), (15.6, 2.2))
  n(15.2, 7.4, [1], hot: true); n(16.3, 6.1, [2]); n(17.4, 4.8, [5])
  n(16.4, 3.5, [4]); n(15.6, 2.2, [3])
  cdraw.content((15.8, 8.3), [access 1: one zig-zig], size: 6pt)
  cdraw.line((6.9, 5.4), (7.5, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.5, 5.4), (13.1, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.2, 0.9), [inorder 1, 2, 3, 4, 5 through all three states], size: 6pt)
  cdraw.content((7.2, 0.1), [4 + 2 = 6 rotations, hot keys float up], size: 6pt)
})

Six rotations carry the chain through both accesses and back, and the
figure below draws the local shapes the run passes through.

#diagram([the three splay steps as before and after pairs, the accessed x rising to the root each time], length: 13pt, {
  let n = (x, y, k) => {
    cdraw.circle((x, y), radius: 0.3, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  let e = (p, q) => cdraw.line(p, q, stroke: luma(190))
  // zig: before p above x, after x above p
  e((1.4, 7.4), (1.4, 6.2)); n(1.4, 7.6, [p]); n(1.4, 6.0, [x])
  cdraw.content((2.9, 6.8), [zig], size: 6.5pt)
  cdraw.line((3.4, 6.8), (4.0, 6.8), stroke: luma(100), mark: (end: ">"))
  e((5.0, 7.4), (5.0, 6.2)); n(5.0, 6.0, [x]); n(5.0, 7.6, [p])
  cdraw.content((1.4, 5.2), [one rotation at the root], size: 6pt)
  // zig-zig: straight chain g p x, rotated top down
  e((0.9, 3.9), (1.1, 3.0)); e((1.1, 3.0), (1.3, 2.1))
  n(0.9, 4.1, [g]); n(1.1, 2.8, [p]); n(1.3, 1.9, [x])
  cdraw.content((2.9, 3.0), [zig-zig], size: 6.5pt)
  cdraw.line((3.7, 3.0), (4.3, 3.0), stroke: luma(100), mark: (end: ">"))
  e((5.1, 4.1), (5.3, 3.0)); e((5.3, 3.0), (5.5, 1.9))
  n(5.5, 4.1, [x]); n(5.3, 2.8, [p]); n(5.1, 1.9, [g])
  cdraw.content((1.4, 1.0), [straight chain, rotate g-p first], size: 6pt)
  // zig-zag: bent chain, x lands between g and p
  e((8.4, 7.4), (7.8, 6.4)); e((7.8, 6.4), (8.2, 5.4))
  n(8.4, 7.6, [g]); n(7.8, 6.2, [p]); n(8.2, 5.2, [x])
  cdraw.content((9.9, 6.4), [zig-zag], size: 6.5pt)
  cdraw.line((10.6, 6.4), (11.2, 6.4), stroke: luma(100), mark: (end: ">"))
  e((12.4, 7.4), (12.0, 6.4)); e((12.4, 7.4), (12.8, 6.4))
  n(12.0, 7.6, [p]); n(12.8, 7.6, [g]); n(12.4, 6.2, [x])
  cdraw.content((8.4, 4.4), [bent chain, two rotations lift x past both], size: 6pt)
  cdraw.content((14.6, 7.6), [x rises to the root on every access], size: 6pt)
  cdraw.content((14.6, 6.6), [amortized O(log n) by the potential sum], size: 6pt)
  cdraw.content((14.6, 5.6), [working-set locality: hot keys float up], size: 6pt)
  cdraw.content((14.6, 4.6), [link and cut trees consume the lease], size: 6pt)
})

== meldable heaps

Two priority queues whose only structural operation is meld, and both
fit in one screen. The randomized heap links by the smaller key, then
flips a coin to decide which child the losing root descends into: the
winner stays the parent, the coin swaps or keeps its two children,
and the loser melds into the left link. Each element sits on a
randomly chosen root-to-leaf path, so the expected depth is
logarithmic and meld runs in expected O(log n). Insert is a meld with
a singleton, O(1) to start. Pop melds the two children of the root.
The skew heap is the same function with the coin replaced by an
unconditional swap: no randomness, no single-operation bound, and an
amortized O(log n) over any sequence because the swaps charge against
the right paths they shorten. Against the array heap of
#xref-to("dsa", "heaps"), whose meld would rebuild at O(n), these two
trade pointer chasing for the O(1) union.

The dry run: the fixture pushes 5, 1, 8 into heap A and 3, 9, 2 into
heap B, melds, and drains, the C\# suite pinning the drain order and
the comparison meters with the sibling suites on the same script.

+ The builds tick 4: each push past the first melds a singleton at
  one comparison, 2 for A and 2 for B.
+ The meld ticks 2: the roots compare 1 against 2, the winner's left
  child meets the arriving 2, and the coin parks it there, meter 6.
+ The drain pops six roots and spends 10 - 6 = 4 more comparisons
  where both children exist, closing the meter at 10.
+ The skew heap posts the same 4, 2, 10 on the same script, its
  unconditional swap agreeing with the drawn coins here.
+ Duplicates 2, 2, 1 drain 1, 2, 2 on 2 comparisons, and melding an
  empty heap compares nothing.

#diagram([the comparison meter through the script, one bar per phase, the running total under each], length: 13pt, {
  let phase = (x, w, title, adds, total, hot) => {
    cdraw.rect((x, 5.6), (x + w, 6.7), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, 6.4), title, size: 6pt)
    cdraw.content((x + w / 2, 5.95), [+#adds], size: 6.5pt)
    cdraw.rect((x, 4.1), (x + w, 5.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 4.55), [meter #total], size: 6pt)
  }
  phase(1.0, 3.7, [builds, 2 + 2], 4, 4, false)
  phase(5.6, 3.7, [the meld], 2, 6, true)
  phase(10.2, 3.7, [drain, 6 pops], 4, 10, false)
  cdraw.content((1.0, 7.4), [A pushes 5, 1, 8, B pushes 3, 9, 2], size: 6pt)
  cdraw.content((1.0, 3.3), [drain: 1, 2, 3, 5, 8, 9], size: 6pt)
  cdraw.content((1.0, 2.4), [meld: roots 1 against 2, then the], size: 6pt)
  cdraw.content((1.0, 1.55), [child against 2, the coin parks it], size: 6pt)
  cdraw.content((1.0, 0.7), [the skew twin posts the same 4, 2, 10], size: 6pt)
  cdraw.content((15.4, 6.4), [one comparison per], size: 6pt)
  cdraw.content((15.4, 5.5), [singleton meld], size: 6pt)
  cdraw.content((15.4, 4.55), [meter closes at 10], size: 6pt)
})

The meter closing at 10 over the drain 1, 2, 3, 5, 8, 9 is the
pinned pair, and the listings below meld both heaps in six languages.

#listing("dsa/samples-c/src/Ch30/mergeheap.c", first: 63, last: 101, caption: [c, the two melds adjacent, one coin flip against one unconditional swap])
#listing("dsa/samples/src/Ch30/MergeHeap.cs", first: 45, last: 58, caption: [c\#, the coin meld, the skew twin below swaps unconditionally])
#listing("dsa/samples-go/ch30/mergeheap.go", first: 19, last: 41, caption: [go, the coin draw and the randomized meld, comparison meter inside])
#listing("dsa/samples-js/src/ch30-mergeheap.mjs", first: 39, last: 55, caption: [javascript, the randomized meld, the loser descends left after the coin])
#listing("dsa/samples-py/src/Ch30/mergeheap.py", first: 46, last: 86, caption: [python, both melds, the whole contrast in one slice])
#listing("dsa/samples-lua/ch30_mergeheap.lua", first: 33, last: 70, caption: [lua, the coin meld and the skew meld, table heaps])

The fixtures run both structures through the same script. Heap A
pushes 5, 1, 8, heap B pushes 3, 9, 2, the meld drains 1, 2, 3, 5,
8, 9 from both. The comparison meters post 4 for the builds, 2 for
the meld, and 10 after the drain, and the coincidence is honest: on
this fixture the coins happened to agree with the unconditional swap,
so the skew heap posts the same 4/2/10 while its meter stays its own.
Duplicates push 2, 2, 1 and drain 1, 2, 2 on 2 comparisons in both,
and melding with an empty heap costs nothing and returns the other
heap unchanged. The edges refuse politely per language house style, a
sentinel flag in c, an exception in c\#, go, javascript, and python,
a nil-indexing throw in lua, and the python suite pins the self-meld
identity on a singleton.

#diagram([two 3-node heaps melding, the coin swapping the winner's children before the descent, the merged heap with the minimum at the root], length: 13pt, {
  // heap A: 1(5, 8); heap B: 2(3, 9)
  let n = (x, y, k, hot: false) => {
    cdraw.circle((x, y), radius: 0.3, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), k, size: 7pt)
  }
  let e = (p, q) => cdraw.line(p, q, stroke: luma(190))
  e((1.4, 7.4), (0.9, 6.5)); e((1.4, 7.4), (1.9, 6.5))
  n(1.4, 7.6, [1], hot: true); n(0.9, 6.3, [5]); n(1.9, 6.3, [8])
  cdraw.content((1.4, 8.4), [heap A], size: 6.5pt)
  e((4.6, 7.4), (4.1, 6.5)); e((4.6, 7.4), (5.1, 6.5))
  n(4.6, 7.6, [2]); n(4.1, 6.3, [3]); n(5.1, 6.3, [9])
  cdraw.content((4.6, 8.4), [heap B], size: 6.5pt)
  // the coin swap: a dashed arrow under 1's children
  cdraw.line((0.9, 5.85), (1.15, 5.45), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((1.15, 5.45), (1.65, 5.45), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((1.65, 5.45), (1.9, 5.85), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((1.4, 4.9), [coin = splitmix32(next) and 1], size: 6pt)
  cdraw.content((1.4, 4.1), [swap the children, loser melds left], size: 6pt)
  // result: 1 at root, left subtree holds the merged rest
  e((1.4, 2.6), (0.7, 1.6)); e((1.4, 2.6), (2.1, 1.6))
  n(1.4, 2.8, [1], hot: true); n(2.1, 1.4, [8])
  e((0.7, 1.4), (0.2, 0.5)); e((0.7, 1.4), (1.2, 0.5))
  n(0.7, 1.4, [2]); n(0.2, 0.3, [3]); n(1.2, 0.3, [5])
  cdraw.content((4.0, 2.8), [min at the root], size: 6pt)
  cdraw.content((4.0, 1.9), [drain: 1, 2, 3, 5, 8, 9], size: 6pt)
  cdraw.content((4.0, 1.0), [one drawn shape, expected log depth], size: 6pt)
  cdraw.content((9.8, 7.6), [skew heap: the same meld, the swap unconditional], size: 6pt)
  cdraw.content((9.8, 6.7), [randomized: expected O(log n) meld], size: 6pt)
  cdraw.content((9.8, 5.8), [skew: amortized O(log n), no single-op bound], size: 6pt)
  cdraw.content((9.8, 4.9), [insert = meld with a singleton, O(1)], size: 6pt)
  cdraw.content((9.8, 4.0), [pop = meld of the root's two children], size: 6pt)
})

== order statistics

Two machines for the k-th smallest question. The first is the fenwick
tree of #xref-to("dsa", "ranges") repurposed as a frequency table
over a value universe: add(v, plus or minus 1) moves a count, rank(v)
is the prefix below v, freq differs two prefixes, and select runs the
bit-jump descent. The descent starts at the largest power of two that
fits the universe and halves: if the node ahead holds fewer than the
remaining k, skip past its whole range and subtract, otherwise stay.
Each step fixes one bit of the answer's position, so rank and select
both run in O(log U) with no tree walk at all. The second machine is
the implicit treap: the same split and merge as the section above,
keyed by subtree size instead of by key. Split by index walks until
the left subtree is exactly k positions, so insert_at, erase_at,
at(k), sum_range, and move_to_front all decompose into cuts and
merges over positions, the rope the textbooks promise, with expected
O(log n) per operation.

The dry run: the fixture loads 3, 1, 4, 1, 5, 9, 2, 6, 5 as
frequencies over a universe of 16 and runs the rope script, the C\#
suite pinning both with the sibling suites on the same digits.

+ The per-value counts: 1 appears 2 times, 5 appears 2 times, every
  other loaded value once, so the cumulative over values 1, 2, 3 runs
  2, 3, 4.
+ kth(4) descends from the power 16: node 16 holds the total 9, node
  8 holds 8, node 4 holds 5, none below the remaining k.
+ Node 2 holds 3, below 4, so the jump lands at pos 2 with
  k = 4 - 3 = 1, and node 3's 1 is not below 1: the answer is pos +
  1 = 3.
+ The rope starts 10, 20, 30, 40, 50 at 10 + 20 + 30 + 40 + 50 =
  150, and move_to_front(2, 3) cuts 30, 40 out and merges them ahead
  for 30, 40, 10, 20, 50.
+ The reads follow the cut: sum(1, 3) gives 40 + 10 + 20 = 70,
  insert_at(1, 99) lifts the total to 150 + 99 = 249, and erase_at(4)
  returns the 20 while at(0), at(2) read 30 and 40.

#diagram([the rope run as four list states, the moved block 30, 40 shaded wherever it sits], length: 13pt, {
  let strip = (y, label, vals, hot) => {
    cdraw.content((0.8, y + 0.45), label, size: 6pt)
    for (i, v) in vals.enumerate() {
      let x = 3.4 + i * 1.5
      cdraw.rect((x, y), (x + 1.4, y + 0.9), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.7, y + 0.45), [#v], size: 6.5pt)
    }
  }
  strip(6.4, [build], (10, 20, 30, 40, 50), (2, 3))
  strip(4.7, [move 2, 3], (30, 40, 10, 20, 50), (0, 1))
  strip(3.0, [insert at 1], (30, 99, 40, 10, 20, 50), (0, 2))
  strip(1.3, [erase at 4], (30, 99, 40, 10, 50), (0, 2))
  cdraw.content((0.8, 7.3), [sum 150], size: 6pt)
  cdraw.content((0.8, 0.4), [sum(1, 3) = 70, then 249, then 20 leaves], size: 6pt)
  cdraw.content((14.0, 6.85), [the cut block leads after the move], size: 6pt)
  cdraw.content((14.0, 5.95), [splits by position, merges back], size: 6pt)
  cdraw.content((14.0, 5.05), [kth walks 16, 8, 4, 2: node 2 jumps], size: 6pt)
  cdraw.content((14.0, 4.15), [k = 4 - 3 = 1, node 3 stays], size: 6pt)
  cdraw.content((14.0, 3.25), [answer pos + 1 = 3], size: 6pt)
  cdraw.content((14.0, 2.35), [rank and select both O(log U)], size: 6pt)
})

The kth(4) answer of 3 beside the rope's mid-run 249 are the pinned
pair, and the listings below walk both machines in six languages.

#listing("dsa/samples-c/src/Ch30/orderstats.c", first: 50, last: 75, caption: [c, the kth bit-jump descent, rank as a clamped prefix, freq by differencing])
#listing("dsa/samples/src/Ch30/OrderStats.cs", first: 116, last: 135, caption: [c\#, the implicit split by index, subtree size steering the recursion])
#listing("dsa/samples-go/ch30/orderstats.go", first: 34, last: 54, caption: [go, kth walking the powers of two down, refusal outside 1..total])
#listing("dsa/samples-js/src/ch30-orderstats.mjs", first: 108, last: 122, caption: [javascript, split by index, the left tree keeps the first k positions])
#listing("dsa/samples-py/src/Ch30/orderstats.py", first: 43, last: 57, caption: [python, the kth descent over the frequency fenwick])
#listing("dsa/samples-lua/ch30_orderstats.lua", first: 95, last: 108, caption: [lua, the implicit split, 0-based public face over 1-based tables])

The fenwick family loads the chapter 21 fixture digits 3, 1, 4, 1,
5, 9, 2, 6, 5 as frequencies, nine values in a universe of 16: the
total is 9, kth of 1 through 9 reads 1, 1, 2, 3, 4, 5, 5, 6, 9, rank
at 1, 2, 5, 7, 10 reads 0, 2, 5, 8, 9, and freq at 1, 5, 6 reads 2,
2, 1. Removing one of the two 4s shifts kth of 4, 5, 6 to 3, 5, 5
and rank(5) to 4. The rope family builds 10, 20, 30, 40, 50, sums
150, moves positions 2 and 3 to the front for 30, 40, 10, 20, 50
with sum(1,3) at 70, inserts 99 at position 1 for a total of 249,
erases position 4 for the value 20, and reads at(0) and at(2) as 30
and 40. Then the interleaved script runs 40 operations off the house
lcg with seed 30, insert_at, erase_at, and sum_range mixed, every sum
checked against a shadow list, javascript driving the generator
through Math.imul so its 32-bit multiplies agree with the other five,
and the final list pins at 16, 27, 40, 1, 27. The edges: an empty
rope sums 0, a single-element move_to_front is a no-op, kth refuses
at 0 and past the total, and rank outside the universe clamps to 0
and to the total.

#diagram([the fenwick bit descent selecting kth(4), beside the rope's move_to_front cut of positions 2 and 3], length: 13pt, {
  // left: value slots 1..8 of the universe with cumulative counts, the descent for kth(4)
  let cum = (0, 2, 3, 4, 6, 8, 8, 9)
  for i in range(8) {
    let x = 1.2 + i * 1.5
    cdraw.rect((x, 6.6), (x + 1.5, 7.5), fill: if i in (2, 3) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 7.05), [#(i + 1)], size: 7pt)
    cdraw.content((x + 0.75, 6.25), [cum #(cum.at(i))], size: 6pt)
  }
  cdraw.content((7.0, 8.0), [kth(4): the running count reaches 4 at value 3], size: 6pt)
  cdraw.line((2.7, 5.8), (2.7, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.0, 5.3), [jumps 8, 4, 2: one bit of the answer each], size: 6pt)
  cdraw.content((7.0, 4.4), [O(log U) rank and select, no tree walk], size: 6pt)
  // right: the rope cut
  let vals = (10, 20, 30, 40, 50)
  for (i, v) in vals.enumerate() {
    let x = 1.2 + i * 1.5
    let hot = i == 2 or i == 3
    cdraw.rect((x, 2.2), (x + 1.5, 3.1), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 2.65), [#v], size: 7pt)
    cdraw.content((x + 0.75, 1.85), [#i], size: 6pt)
  }
  cdraw.content((7.0, 3.3), [split at 2 and at 4 cut positions 2..3], size: 6pt)
  let out = (30, 40, 10, 20, 50)
  for (i, v) in out.enumerate() {
    let x = 1.2 + i * 1.5
    let hot = i == 0 or i == 1
    cdraw.rect((x, 0.0), (x + 1.5, 0.9), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 0.45), [#v], size: 7pt)
  }
  cdraw.content((7.0, 1.2), [merge(m, merge(c, b)): the cut leads], size: 6pt)
  cdraw.content((7.0, 0.3), [expected O(log n) per rope op], size: 6pt)
})

The unranked kth has its own chapter already: the quickselect
extension of #xref-to("dsa", "searching") answers one offline k-th
smallest in expected linear time without any structure, and the
fenwick here is the online upgrade that answers rank and select
repeatedly under inserts and removals.

== across the six languages

Featured build size counted as non-blank, non-comment lines of the
chapter's three sample files per language, embedded test scripts
included:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [865], [static pool arrays, index 0 the null node], [long long sums, uint32 priorities, the empty-pop sentinel flag],
  [c\#], [574], [nullable node classes, tuples], [default gate from size, gate override in the constructor, exceptions at the boundaries],
  [go], [541], [struct with meters, no imports beyond fmt], [error returns on empty pops and kth out of range],
  [javascript], [451], [class fields, private methods], [Math.imul on every 32-bit multiply, splitMix32 and the lcg included],
  [python], [665], [`__slots__` nodes, check harness], [system exit on failure, ok-N print, the self-meld identity pinned],
  [lua], [630], [tables, 1-based inside], [64-bit integers keep the priority products exact],
)

sources: cp-algorithms, "Treap (Cartesian tree)",
cp-algorithms.com/data_structures/treap.html, covering the explicit
and implicit treap sections, "Randomized Heap",
cp-algorithms.com/data_structures/randomized_heap.html, "Fenwick
Tree", cp-algorithms.com/data_structures/fenwick.html, whose
rank/select extension is taught in our own words, and "K-th order
statistic in O(N)", cp-algorithms.com/sequences/k-th.html, the
quickselect kin, all accessed 2026-09-20, cc by-sa 4.0, our own words
and code throughout. Application source: icpc world finals 2019
problem F (book 10, chapter 10). Sample behavior verified by the six
suite gates scoped to chapter 30: c 3 files and 82 checks, c\# 17
facts, go 12 test functions, javascript 13 tests and 73 asserts,
python 3 files and 57 asserts, lua 14 checks, zero skipped.
