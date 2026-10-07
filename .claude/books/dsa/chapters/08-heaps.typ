#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= heaps and priority queues

A priority queue answers "smallest next" without keeping everything
sorted. The binary heap gets that from partial order in an array: the
parent is never larger than either child, and the tree lives entirely
in index arithmetic, children at `2i+1` and `2i+2`, parent at
`(i-1)/2`. Every language in this chapter builds it by hand, the
matrix rule, even where a shipped priority queue sits one import away.

== the array heap

Add appends at the end and sifts up, swapping with the parent until
order holds. Extract takes the root, moves the last element there,
and sifts down against the smaller child.

The dry run: the fixture is 5, 3, 8, 1, 9, 2, 7 drained to sorted
order plus the descending storm, asserted by the C\# suite, while
C, Java, JavaScript, and Lua push 5, 3, 8, 1, 9, 2 and pop 1, 2, 3,
5, 8, 9 with the property re-asserted after every operation.

+ Add 5, then 3: 3 < 5 swaps up, the array reads 3, 5.
+ Add 8 under the root: 8 > 3 stays put, 3, 5, 8.
+ Add 1: 1 < 5 swaps, then 1 < 3 swaps, two hops to the root:
  1, 3, 8, 5.
+ Add 9: its parent 3 is smaller, it stays. Add 2: 2 < 8 swaps
  once, 2 > 1 stops: 1, 3, 2, 5, 9, 8.
+ Add 7: parent 2 is smaller, it stays, and the heap closes at
  1, 3, 2, 5, 9, 8, 7, valid at every step.
+ ExtractMin takes 1 and moves the tail 7 to the root: 7 swaps
  with the smaller child 2, leaving 2, 3, 7, 5, 9, 8, and the
  drain runs 1, 2, 3, 5, 7, 8, 9 down to count 0.
+ Descending 99 to 0 makes every add sift to the root: the swap
  meter reads at least 100, peek 0.

#diagram([the build as one row per arrival, the cells each sift touched shaded, then the first extraction], length: 13pt, {
  // rows: the array after each add, hot cells are the ones the sift moved
  let states = (
    ((5,), ()), ((3, 5), (0, 1)), ((3, 5, 8), ()),
    ((1, 3, 8, 5), (0, 1, 3)), ((1, 3, 8, 5, 9), ()),
    ((1, 3, 2, 5, 9, 8), (2, 5)), ((1, 3, 2, 5, 9, 8, 7), ()),
    ((2, 3, 7, 5, 9, 8), (0, 2)),
  )
  let tags = ([+5], [+3], [+8], [+1], [+9], [+2], [+7], [pop 1])
  for (r, row) in states.enumerate() {
    let (vals, hot) = row
    let y = 7.4 - r * 0.82
    cdraw.content((0.55, y), tags.at(r), size: 6pt)
    for (i, v) in vals.enumerate() {
      cdraw.rect((1.7 + i * 0.92, y - 0.3), (2.62 + i * 0.92, y + 0.3), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((2.16 + i * 0.92, y), [#v], size: 6pt)
    }
  }
  cdraw.content((10.4, 7.4), [1 climbs two parents to the root], size: 6pt)
  cdraw.content((10.4, 5.8), [2 buys one swap past 8], size: 6pt)
  cdraw.content((10.4, 4.2), [pop: 7 to the root, one swap down], size: 6pt)
  cdraw.content((10.4, 2.6), [drain: 1 2 3 5 7 8 9, count 0], size: 6pt)
  cdraw.content((10.4, 1.0), [descending 99..0: swaps at least 100], size: 6pt)
})

The drain landing 1, 2, 3, 5, 7, 8, 9 from shuffled input is the
pinned pair, and the listings below meter every swap of it.

#listing("dsa/samples-c/src/Ch08/heap.c", first: 26, last: 66, caption: [c, both sifts, push, peek, pop, and the invariant checker])

#listing("dsa/samples-go/ch08/heap.go", first: 14, last: 57, caption: [go, push sifts up, pop moves the tail to the root and sifts down, errors as values])

#listing("dsa/samples-java/src/Ch08/Heap.java", first: 27, last: 69, caption: [java, both sifts, push, peek, pop, and the invariant checker over one static array])

#listing("dsa/samples/src/Ch08/Heaps.cs", first: 4, last: 56, caption: [c\#, add, peek, extract, the invariant checker, drain to sorted])

#listing("dsa/samples/src/Ch08/Heaps.cs", first: 57, last: 86, caption: [c\#, sift up against the parent, sift down against the smaller child])

#listing("dsa/samples-js/src/ch08-heap.mjs", first: 20, last: 52, caption: [javascript, private sift up and sift down behind push and pop])

#listing("dsa/samples-py/src/Ch08/heap.py", first: 17, last: 51, caption: [python, the MinHeap class, push, pop, and the invariant check])

#listing("dsa/samples-lua/ch08_heap.lua", first: 19, last: 48, caption: [lua, the same heap one index over, parent at i div 2, children at 2i])

Both sifts are logarithmic because the tree is complete, its height
is the base-2 log of the count. The swap meter tells the story the
tests check: descending input makes every add sift to the root, the
maximum work, while the heap stays valid throughout. Note what the
heap is not: only the root is guaranteed minimal. The invariant
checkers walk parent against child, a full sort is not maintained,
and iteration order is meaningless. Lua shifts every formula by one
because its arrays start at 1, parent at `i//2`, children at `2i` and
`2i+1`, the one translation that touches every line.

Measured across the suites: the C, Java, JavaScript, and Lua files
push 5 3 8 1 9 2 and pop 1 2 3 5 8 9 with the property re-asserted
after every operation, 29 checks on the C side. Python pins 5 1 4 2
8 0 to 0 1 2 4 5 8 and refuses the empty pop with IndexError. Go
pushes a shuffled 1 to 9 and checks the property on a snapshot after
each push and pop, and the C\# class drains its 7-value fixture to
1 2 3 5 7 8 9 while metering swaps, 100 descending adds cost at
least 100.

#diagram([one heap twice, the tree and the array it lives in], length: 13pt, {
  // the complete tree, node text is the array index
  let p = ((2.4, 6.2), (1.2, 4.7), (3.6, 4.7), (0.6, 3.2), (1.8, 3.2), (3.0, 3.2), (4.2, 3.2))
  let links = ((0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6))
  for (a, b) in links { cdraw.line(p.at(a), p.at(b)) }
  for i in range(7) {
    cdraw.circle(p.at(i), radius: 0.34, fill: luma(230))
    cdraw.content(p.at(i), [#i], size: 6pt)
  }
  cdraw.content((2.4, 7.0), [the tree], size: 7pt)

  // the same heap as a flat array
  cdraw.content((15.4, 7.0), [the array], size: 7pt)
  for i in range(7) {
    cdraw.rect((10.6 + i * 1.35, 5.4), (10.6 + (i + 1) * 1.35, 6.3), fill: luma(230), radius: 0.02)
    cdraw.content((10.6 + i * 1.35 + 0.67, 5.85), [#i], size: 6pt)
  }
  cdraw.content((15.4, 4.6), [children of i: 2i+1 and 2i+2, parent of i: (i-1)/2], size: 6.5pt)
  cdraw.content((15.4, 3.9), [lua alone: children 2i and 2i+1, parent i div 2], size: 6.5pt)
  cdraw.content((15.4, 3.2), [no pointers anywhere, the shape is the index arithmetic], size: 6.5pt)
})

== heapsort

Heapsort is the heap wearing a sort's clothes: heapify the array
in place from the back, then repeatedly swap the maximum to the end
and re-sift the shrunk heap. Every version here builds a max-heap so
the root is the maximum.

The dry run: the fixture is the theory row 5, 3, 8, 1, 9, 2, 7
sorted in place, asserted by the C\# suite against the ordered
copy, while C, Java, JavaScript, and Lua sort the pi fixture 3, 1,
4, 1, 5, 9, 2, 6, 5 and Python returns its build peak of 9.

+ Heapify walks backward from index 2: node 8 already dominates
  its children 2 and 7, no swap.
+ Index 1: 3 swaps with its larger child 9, index 0: 5 swaps with
  9, and the max-heap reads 9, 5, 8, 1, 3, 2, 7.
+ The first extraction parks 9 at slot 6; the tail 7 sifts once,
  past 8, leaving 8, 5, 7, 1, 3, 2.
+ 8 parks, and the tail 2 swaps past 7: 7, 5, 2, 1, 3. Then 7
  parks, and the tail 3 swaps past 5: 5, 3, 2, 1.
+ 5, 3, and 2 park in order, each sift touching at most two nodes,
  and the array ends 1, 2, 3, 5, 7, 8, 9.
+ The theory's other rows arrive already sorted and reversed and
  land the same place, and the sift never fires on 100 equal
  sevens.

#table(
  columns: (auto, 1.7fr, 1.3fr),
  inset: 4pt,
  table.header([*step*], [*array*], [*parked tail*]),
  [input], [5 3 8 1 9 2 7], [],
  [heapify], [9 5 8 1 3 2 7], [],
  [9 out], [8 5 7 1 3 2], [9],
  [8 out], [7 5 2 1 3], [8 9],
  [7 out], [5 3 2 1], [7 8 9],
  [5 out], [3 1 2], [5 7 8 9],
  [3 out], [2 1], [3 5 7 8 9],
  [2 out], [1], [2 3 5 7 8 9],
)

The parked tail swallowing the array until only 1 survives is the
whole sort, and the listings below run it on every shape.

#listing("dsa/samples-c/src/Ch08/heapsort.c", first: 24, last: 45, caption: [c, max-heap sift-down, heapify backward, extract to the end])

#listing("dsa/samples-go/ch08/heapsort.go", first: 7, last: 34, caption: [go, heapsort and its max-heap sift-down])

#listing("dsa/samples-java/src/Ch08/Heapsort.java", first: 24, last: 46, caption: [java, max-heap sift-down, heapify backward, extract to the end])

#listing("dsa/samples/src/Ch08/Heaps.cs", first: 88, last: 118, caption: [c\#, in-place heapsort, heapify then extract to the back])

#listing("dsa/samples-js/src/ch08-heapsort.mjs", first: 10, last: 31, caption: [javascript, heapsort over the in-place max-heap])

#listing("dsa/samples-py/src/Ch08/heapsort.py", first: 15, last: 39, caption: [python, sift-down, heapify, extract, the build peak returned])

#listing("dsa/samples-lua/ch08_heapsort.lua", first: 7, last: 26, caption: [lua, 1-based heapsort, heapify from the middle down])

It is the honest sort of this book's chapter 13 lineup: worst case
linearithmic with no quicksort-style adversarial collapse, entirely
in place with no merge-sort auxiliaries, and slower than both on
typical data because sift-down touches memory with poor locality.
Nobody allocates: each version repairs the one array it was handed.

Measured across the suites: C, Java, JavaScript, and Lua sort the pi
fixture 3 1 4 1 5 9 2 6 5 to 1 1 2 3 4 5 5 6 9 and prove the
permutation with sum and xor, the two 1s and two 5s counted one by
one. Go runs five shapes from reversed to empty against slices.Sort
ground truth plus a count map, Python returns the build-phase maximum
on its 7 2 9 4 3 1 fixture, 9, before leaving 1 2 3 4 7 9 behind and
cross-checking the permutation with Counter, and C\# presses 2000
values drawn from 50 keys plus an all-equal array.

#diagram([heapsort, heapify walks backward from the middle, then each swap parks the maximum at the shrinking end], length: 13pt, {
  // six states of one array: input, heapified, two extractions, the end
  let states = (
    ((3, 9, 2, 7, 5, 1), 6, [input]),
    ((9, 7, 2, 3, 5, 1), 6, [heapify backward]),
    ((7, 5, 2, 3, 1, 9), 5, [swap 9 to the end]),
    ((5, 3, 2, 1, 7, 9), 4, [swap 7 out]),
    ((2, 1, 3, 5, 7, 9), 2, [heap shrinks]),
    ((1, 2, 3, 5, 7, 9), 1, [sorted, in place]),
  )
  for (r, row) in states.enumerate() {
    let (vals, live, label) = row
    let y = 6.6 - r * 1.1
    for (i, v) in vals.enumerate() {
      let sorted = i >= live
      cdraw.rect((8.2 + i * 0.95, y - 0.45), (8.2 + (i + 1) * 0.95, y + 0.45), fill: if sorted { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((8.2 + i * 0.95 + 0.475, y), [#v], size: 6pt)
    }
    cdraw.content((3.4, y), label, size: 6pt)
  }
})

== streaming top-k

Keep the k largest of a stream without storing it all: a min-heap
capped at k, where the root is the entry ticket. A newcomer below the
root changes nothing, a newcomer above it evicts the root and sifts
down, so the heap always holds the best k so far and its root is the
running k-th largest. Cost is log k per value and k of memory, the
shape every leaderboard, heavy-hitter counter, and recommendation
pre-pass reduces to.

The dry run: the fixture is the stream 4, 9, 1, 7, 3, 8, 6, 5, 2
at k = 3, asserted by the C\# suite, while Java pins the same 9 8 7
with the equal-value, short-stream, and k = 1 edge laws, Go pins the
same 9 8 7 on its own shuffle, and Python meters four skips and one
eviction on its own stream.

+ Fill on 4, 9, 1: the heap reads 1, 9, 4 with 1 at the root, the
  entry ticket now that the heap is full.
+ Feed 7: 7 > 1 evicts the root, and 7 sifts past 4 into the heap
  4, 9, 7, ticket 4.
+ Feed 3: 3 < 4, skip, nothing moves.
+ Feed 8: 8 > 4 evicts, 8 sifts past 7, heap 7, 9, 8, ticket 7.
+ Feed 6, 5, 2: all below 7, three skips.
+ Count 3 with the threshold at 7, and draining largest first
  reads 9, 8, 7, the k-th largest settled at 7.
+ The pinned edge laws: equal values never displace the ticket,
  7, 7, 7, 7 at k = 2 keeps 7, 7, a short stream keeps everything,
  and k = 1 is a running maximum at threshold 9.

#diagram([the stream as nine arrivals, the verdict and the running ticket under each], length: 13pt, {
  let stream = (4, 9, 1, 7, 3, 8, 6, 5, 2)
  let verdict = ([fill], [fill], [fill], [evict], [skip], [evict], [skip], [skip], [skip])
  let out = (none, none, none, [1 out], none, [4 out], none, none, none)
  let ticket = (4, 4, 1, 4, 4, 7, 7, 7, 7)
  for i in range(9) {
    let x = 0.9 + i * 2.35
    cdraw.rect((x, 6.6), (x + 1.9, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.95, 7.0), [#stream.at(i)], size: 6.5pt)
    cdraw.content((x + 0.95, 6.2), verdict.at(i), size: 6pt)
    if out.at(i) != none { cdraw.content((x + 0.95, 5.7), out.at(i), size: 6pt) }
    let changed = i == 0 or ticket.at(i) != ticket.at(calc.max(i - 1, 0))
    cdraw.rect((x + 0.25, 4.5), (x + 1.65, 5.2), fill: if changed { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.95, 4.85), [#ticket.at(i)], size: 6pt)
  }
  cdraw.content((0.9, 3.7), [the ticket is the root, the entry price], size: 6pt)
  cdraw.content((0.9, 2.9), [two evictions, four skips, settles at 7], size: 6pt)
  cdraw.content((0.9, 2.1), [result 9 8 7, k = 1 reads threshold 9], size: 6pt)
})

The ticket settling at 7 with the drain reading 9, 8, 7 is the
pinned landing, and the listings below cap every stream the same
way.

#listing("dsa/samples-c/src/Ch08/topk.c", first: 45, last: 73, caption: [c, begin, feed with fill and evict, drain descending])

#listing("dsa/samples-go/ch08/topk.go", first: 17, last: 41, caption: [go, add against the weakest survivor, best drains largest first])

#listing("dsa/samples-java/src/Ch08/Topk.java", first: 46, last: 74, caption: [java, begin, feed with fill and evict, drain descending])

#listing("dsa/samples/src/Ch08/TopK.cs", first: 16, last: 42, caption: [c\#, feed with fill and evict, the threshold getter, survivors descending])

#listing("dsa/samples-js/src/ch08-topk.mjs", first: 29, last: 52, caption: [javascript, feed with inline sifts, the threshold getter])

#listing("dsa/samples-py/src/Ch08/topk.py", first: 37, last: 57, caption: [python, TopK with skip and eviction meters])

#listing("dsa/samples-lua/ch08_topk.lua", first: 31, last: 55, caption: [lua, feed, evict at the root, result sorted descending])

Measured across the suites: C, C\#, Java, JavaScript, and Lua stream
4 9 1 7 3 8 6 5 2 with k = 3 and pin 9 8 7, the root settling at 7,
the k-th largest so far. Go pins the same 9 8 7 over its own shuffled
1 to 9, and Python's tracker meters the mechanics on 8 3 9 1 7 2 6 5,
four skips and one eviction, the root sequence 3 3 7 7 7 7. Three
properties recur everywhere: a value equal to the threshold never
displaces it, a stream shorter than k keeps everything, and k = 1
degrades to a running maximum.

#diagram([streaming top-k, a min-heap of size k, the root is the entry ticket, evictions only from above], length: 13pt, {
  // the stream, the three survivors shaded
  let stream = (4, 9, 1, 7, 3, 8, 6, 5, 2)
  let live = (1, 3, 5)
  for (i, v) in stream.enumerate() {
    let hot = i in live
    cdraw.rect((0.9 + i * 1.15, 7.3), (0.9 + (i + 1) * 1.15, 8.2), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((0.9 + i * 1.15 + 0.575, 7.75), [#v], size: 6pt)
  }
  cdraw.content((11.2, 8.9), [the stream, the survivors shaded], size: 6.5pt)

  // three moments of the bounded heap: fill, one eviction, the settled state
  let moments = (
    ([after 4 9 1: full], (1, 4, 9), 5.9),
    ([7 evicts 1, 3 skips], (4, 7, 9), 3.8),
    ([8 evicts 4, 6 5 2 skip], (7, 8, 9), 1.7),
  )
  for row in moments {
    let (label, vals, y) = row
    cdraw.content((3.0, y), label, size: 6pt)
    let cells = ((8.8, y, vals.at(0)), (7.6, y - 1.1, vals.at(1)), (10.0, y - 1.1, vals.at(2)))
    cdraw.line(cells.at(0).slice(0, 2), cells.at(1).slice(0, 2), stroke: luma(140))
    cdraw.line(cells.at(0).slice(0, 2), cells.at(2).slice(0, 2), stroke: luma(140))
    for (i, c) in cells.enumerate() {
      cdraw.rect((c.at(0) - 0.45, c.at(1) - 0.4), (c.at(0) + 0.45, c.at(1) + 0.4), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((c.at(0), c.at(1)), [#c.at(2)], size: 6pt)
    }
  }

  cdraw.content((15.6, 5.9), [the root is the k-th largest], size: 6pt)
  cdraw.content((15.6, 4.8), [below it: skip, above it: evict], size: 6pt)
  cdraw.content((15.6, 3.7), [final answer 9 8 7], size: 6pt)
  cdraw.content((15.6, 2.6), [k cells, log k per value], size: 6pt)
})

== the k-way merge

Merge k sorted runs with a heap of cursors: each cursor holds the
next unconsumed element of its run, the heap orders cursors by that
element, and each extraction yields the global minimum then reinserts
the cursor if its run has more.

The dry run: the fixture is the tie pair, both runs holding 1 2 3,
asserted by all seven suites, and the six new trees add the pinned
deterministic set, the four-run grid, the empty and lone runs, and
the uneven tails, each checked by an oracle lane against the sorted
concatenation of the runs.

+ Two cursors open in the heap, one per run, each holding its run's
  head, and ties break to the lower run index.
+ Both hold 1: run 0 wins the tie, emits 1, and its cursor reenters
  holding 2.
+ Run 1's 1 is now the minimum: it emits, and the cursors hold 2
  and 2.
+ The 2s and 3s follow the same way, run 0 always first at each
  tie: 1 1 2 2 3 3, stability pinned.
+ An empty run never enters the heap: no runs emit nothing, and a
  lone run of 4 5 emits 4 5 unchanged.
+ Scaled up on the C\# side, 4 seeded runs of 200 values merge to
  exactly the sort of the 800-value concatenation, 4 x 200 = 800. The
  seeded random lane stays C\# only, the other trees pin deterministic
  fixtures instead.

#diagram([the tie fixture as an emission sequence, run 0 first whenever the values tie], length: 13pt, {
  // the two runs, heads at the left
  let run = (y, tag, vals) => {
    cdraw.content((0.7, y), tag, size: 6pt)
    for (i, v) in vals.enumerate() {
      cdraw.rect((2.6 + i * 1.0, y - 0.38), (3.6 + i * 1.0, y + 0.38), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((3.1 + i * 1.0, y), [#v], size: 6pt)
    }
  }
  run(7.1, [run 0], (1, 2, 3))
  run(5.9, [run 1], (1, 2, 3))
  // the six emissions in order, the winning run tagged under each
  let emit = ((1, 0), (1, 1), (2, 0), (2, 1), (3, 0), (3, 1))
  for (i, e) in emit.enumerate() {
    let x = 0.9 + i * 2.1
    cdraw.rect((x, 2.7), (x + 1.8, 3.6), fill: if calc.even(i) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.9, 3.35), [#e.at(0)], size: 6.5pt)
    cdraw.content((x + 0.9, 2.95), [r#e.at(1)], size: 6pt)
  }
  cdraw.line((9.5, 5.4), (9.5, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.9, 1.9), [ties leave in run order: 1 1 2 2 3 3], size: 6pt)
  cdraw.content((0.9, 1.1), [empty runs never enter the heap], size: 6pt)
  cdraw.content((0.9, 0.3), [a lone run of 4 5 emits 4 5 unchanged], size: 6pt)
})

The 1 1 2 2 3 3 with run 0 leading every tie is the pinned order,
and the listings below are the merges that produced it.

#listing("dsa/samples-c/src/Ch08/kway.c", first: 76, last: 114, caption: [c, the cursor merge loop and its sorted-concatenation oracle])

#listing("dsa/samples-go/ch08/kway.go", first: 61, last: 84, caption: [go, k-way over the cursor heap, ties keyed by run index])

The other five languages build the same merge on the chapter's own
heap, Java's cursors records breaking ties by run index:

#listing("dsa/samples-java/src/Ch08/Kway.java", first: 71, last: 99, caption: [java, the cursor merge loop over record cursors and its sorted-concatenation oracle])

#listing("dsa/samples/src/Ch08/Heaps.cs", first: 120, last: 169, caption: [c\#, k-way merge over cursors, run-index tie break])

#listing("dsa/samples-js/src/ch08-kway.mjs", first: 47, last: 61, caption: [javascript, the merge loop over value, run, position cursors])

#listing("dsa/samples-py/src/Ch08/kway.py", first: 57, last: 88, caption: [python, the cursor heap merge with its pinned fixtures])

#listing("dsa/samples-lua/ch08_kway.lua", first: 42, last: 65, caption: [lua, the merge loop and the sorted-concatenation oracle])

Measured across the suites: the tie pair drains to 1 1 2 2 3 3 with
run 0 leading every tie in all seven languages. The six new trees
also merge the four-run grid to 0 through 13, pass the empty runs and
the lone run straight through with empty input to empty output, and
interleave the uneven tails to 1 2 3 10 20 100, each fixture checked
against the sorted concatenation. C\# runs that same oracle on its
seeded four-run lane.

The cost is n log k, not n log n, k being the run count, and the tie
break on run index makes the merge stable, equal elements leave in
run order, which every suite pins. This exact routine is the
capstone's compaction pass, merging sorted segment files, and it is
also how external database sorts are built. The comparators put value
first and run index second everywhere, and the heaps are the
chapter's own binary heap, no shipped priority queue anywhere.

#diagram([the k-way merge, a heap of cursors over sorted runs, extraction yields the global minimum], length: 13pt, {
  // three sorted runs, the head cell of each is the cursor's element
  let runs = (((2, 5, 8), 6.5), ((2, 6), 5.5), ((4, 7), 4.5))
  for (r, run) in runs.enumerate() {
    let (vals, y) = run
    cdraw.content((1.1, y), [r#r:], size: 6pt)
    for (i, v) in vals.enumerate() {
      cdraw.rect((2.2 + i * 1.0, y - 0.4), (2.2 + (i + 1) * 1.0, y + 0.4), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((2.2 + i * 1.0 + 0.5, y), [#v], size: 6pt)
    }
  }
  cdraw.line((5.7, 4.3), (5.7, 6.7), stroke: luma(100))
  cdraw.line((5.7, 5.5), (7.0, 5.35), stroke: luma(100), mark: (end: ">"))

  // the heap of three cursors, ordered by the held element, ties to the lower run
  let hnode = (x, y, t) => {
    cdraw.rect((x - 1.0, y - 0.42), (x + 1.0, y + 0.42), fill: luma(235), radius: 0.02)
    cdraw.content((x, y), t, size: 6pt)
  }
  hnode(9.2, 6.5, [2 : r0])
  hnode(8.1, 5.1, [2 : r1])
  hnode(10.3, 5.1, [4 : r2])
  cdraw.line((9.2, 6.08), (8.1, 5.52))
  cdraw.line((9.2, 6.08), (10.3, 5.52))
  cdraw.content((9.2, 7.6), [heap of cursors, n log k], size: 6.5pt)

  // extraction leaves from the root, down to the merged output
  cdraw.line((10.2, 6.5), (12.4, 6.5), stroke: luma(100))
  cdraw.line((12.4, 6.5), (12.4, 3.85), stroke: luma(100), mark: (end: ">"))
  let out = (2, 2, 4, 5, 6, 7, 8)
  for (i, v) in out.enumerate() {
    cdraw.rect((7.0 + i * 1.0, 2.9), (7.0 + (i + 1) * 1.0, 3.7), fill: if i < 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((7.0 + i * 1.0 + 0.5, 3.3), [#v], size: 6pt)
  }
  cdraw.content((10.5, 2.2), [extract the min, reinsert its cursor], size: 6pt)
  cdraw.content((10.5, 1.1), [ties go to the lower run index, stable], size: 6pt)
})

== the bcl priority queue

#diagram([the shipped heap against the teaching one, wider nodes, fused sifts, remove emulating decrease key], length: 13pt, {
  let cols = ((0.6, 7.4), (7.4, 13.2), (13.2, 23.0))
  let rows = ((5.9, 6.9), (4.7, 5.7), (3.5, 4.5), (2.3, 3.3), (1.1, 2.1))
  let head = ([aspect], [chapter 8 heap], [priorityqueue\<t\>])
  let body = (
    ([children], [2], [4, one less sift level]),
    ([enqueuedequeue], [two calls], [one fused sift]),
    ([decrease key], [not built in], [remove then reenqueue, O(n)]),
    ([ties], [no promise], [no fifo guarantee]),
  )
  for c in range(3) {
    cdraw.rect((cols.at(c).at(0), 5.9), (cols.at(c).at(1), 6.9), fill: luma(205), radius: 0.02)
    cdraw.content(((cols.at(c).at(0) + cols.at(c).at(1)) / 2, 6.4), head.at(c), size: 6pt)
  }
  for r in range(4) {
    for c in range(3) {
      cdraw.rect((cols.at(c).at(0), rows.at(r + 1).at(0)), (cols.at(c).at(1), rows.at(r + 1).at(1)), fill: luma(235), radius: 0.02)
      cdraw.content(((cols.at(c).at(0) + cols.at(c).at(1)) / 2, rows.at(r + 1).at(0) + 0.5), body.at(r).at(c), size: 6pt)
    }
  }
})

`PriorityQueue<TElement,TPriority>` is an array-backed quaternary
min-heap, four children per node for one less level of sift. It
dequeues the lowest priority value first and does not guarantee fifo
among equals. Two fused operations exist for the hot loop,
`EnqueueDequeue` adds then extracts in one sift and `DequeueEnqueue`
extracts then adds, both documented as cheaper than the two calls
they replace.

#callout("note", "decrease-key, emulated in .NET 9", [
  Array heaps cannot update a buried element's priority without a
  position index, so `PriorityQueue` gained `Remove` in .NET 9: a
  linear scan that extracts the element, then you reenqueue it at the
  new priority. It is O(n), and the docs say plainly that this
  unblocks dijkstra-style algorithms for education and prototyping
  where the asymptote does not hurt. The tests exercise it as the
  documented emulation. Serious graph work keeps its own heap with
  a position map, which is what chapter 11's dijkstra does.
])

The dry run: the fixture is the shipped-queue trio asserted by the
C\# suite, priorities 10, 1, 5 through dequeue, then 1 and 3 under
one fused call, then b at 20 among 10, 20, 30.

+ Enqueue low at 10, high at 1, mid at 5: three nodes fill two
  levels, a quaternary root holds 4 children, 1 + 4 = 5 slots
  before a third level exists.
+ Dequeue drains by priority: high, mid, low.
+ EnqueueDequeue(2, 2) on a queue holding 1 and 3 adds 2 and
  extracts the minimum in one sift: it returns 1.
+ The queue then dequeues 2 and 3, the fused call replacing two
  full operations.
+ Remove emulates decrease-key: with a at 10, b at 20, c at 30,
  Remove("b") scans, extracts b, reports oldPriority 20, and
  reenqueue at 1 puts b at the front.
+ Dequeue returns b first, and Remove("missing") returns false.

#diagram([the shipped queue in three moments, priority order out, the fused sift, the remove-then-reenqueue path], length: 13pt, {
  // moment 1: three elements, the min at the root of a 4-ary heap
  cdraw.content((2.6, 7.7), [by priority], size: 6.5pt)
  cdraw.rect((1.8, 6.4), (3.4, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((2.6, 6.8), [high 1], size: 6pt)
  cdraw.rect((0.6, 5.1), (2.2, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((1.4, 5.5), [mid 5], size: 6pt)
  cdraw.rect((3.0, 5.1), (4.6, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 5.5), [low 10], size: 6pt)
  cdraw.line((2.6, 6.4), (1.4, 5.9), stroke: luma(220))
  cdraw.line((2.6, 6.4), (3.8, 5.9), stroke: luma(220))
  cdraw.content((2.6, 4.4), [dequeue: high, mid, low], size: 6pt)
  // moment 2: the fused add-then-extract
  cdraw.content((9.6, 7.7), [one fused sift], size: 6.5pt)
  cdraw.rect((6.0, 6.4), (7.6, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.8, 6.8), [1, 3], size: 6pt)
  cdraw.line((7.6, 6.8), (8.2, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.2, 6.4), (10.9, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((9.55, 6.8), [enqueuedq(2, 2)], size: 6pt)
  cdraw.line((10.9, 6.8), (11.5, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.3, 6.8), [returns 1], size: 6pt)
  cdraw.content((9.6, 5.6), [then 2, then 3], size: 6pt)
  // moment 3: remove then reenqueue
  cdraw.content((17.6, 7.7), [decrease key, emulated], size: 6.5pt)
  cdraw.content((14.4, 6.8), [a 10, b 20, c 30], size: 6pt)
  cdraw.line((17.4, 6.4), (17.4, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.4, 5.5), [remove b: scan, old 20], size: 6pt)
  cdraw.line((17.4, 5.1), (17.4, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.4, 4.2), [reenqueue b at 1], size: 6pt)
  cdraw.line((17.4, 3.8), (17.4, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.4, 2.9), [dequeue: b first], size: 6pt)
  cdraw.content((0.6, 1.4), [remove is O(n), the documented emulation], size: 6pt)
})

The b leaving first after its 20 became 1 is the pinned emulation,
the trade the table above prices at O(n).

== across the seven languages

The build sizes count non-comment source lines over this chapter's
four featured files per language. Where a language bundles its
checks into the same file the count carries them, and no shipped
priority queue appears anywhere in the featured code:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [417], [libc only], [fixed static capacity, 64 heap slots, 16 top-k slots, 8 merge cursors, checks share the file with main, 65 of them],
  [go], [190], [fmt for errors], [container/heap named as the stdlib counterpart and left unused, tests in separate files, errors returned not thrown, 12 tests],
  [java], [405], [jdk 27 stdlib], [java.util.PriorityQueue named as the stdlib counterpart and left unused, heaps over one static array, cursors as records breaking ties by run index, 65 checks in 4 files],
  [c\#], [201], [bcl only], [the k-way merge and the streaming top-k ride the file set, 17 tests],
  [javascript], [180], [node stdlib], [private class fields over one array, tests in test/, 14 tests],
  [python], [256], [stdlib only], [heapq named as the stdlib counterpart and left unused, native ints, empty pop raises IndexError, 43 checks],
  [lua], [310], [lib.lua harness], [1-based heaps shift every index formula, checks ride in the module, 18 of them],
)

sources: learn.microsoft.com, `PriorityQueue<TElement,TPriority>`
class remarks on the quaternary heap and fifo caveats,
`EnqueueDequeue` and `DequeueEnqueue` method pages, `Remove` method
page, what's new in .NET 9 libraries for the decrease-key notes,
accessed 2026-09-08. Sample behavior verified by
`make verify-csharp`, 17 tests in chapter 8 of the samples suite.
The seven-language layer verifies the same way: 4 C programs with 65
embedded checks under `make verify-c`, 12 Go tests, the java runner's
65 Ch08 checks over 4 files under `run-java-samples`, 14
`node --test` cases, 43 Python checks across 4 files, and 18 Lua
checks under `run.lua`.
