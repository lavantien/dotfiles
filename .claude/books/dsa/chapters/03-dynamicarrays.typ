#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= dynamic arrays and amortization

`List<T>` is the most used container in the language and almost nobody
can say what its growth curve costs. This chapter rebuilds it with the
copy counter from chapter 1 wired in, so the amortized claim becomes
an assertion instead of folklore.

== the vector

A growable array is a fixed array plus a count plus a growth policy.
Every operation is array work with one twist, growing reallocates and
copies. C keeps the whole anatomy in one struct and grows with a hand
copy loop.

The dry run: the fixture is 33 pushes into a vector born at capacity
4, snapshotted at every growth, asserted by the C, JavaScript, and
Lua suites. Go stops the ladder at 32 pushes and 28 copies, Python
at 16 and 12.

+ Pushes 1 through 4 fill the first block: size 4, capacity 4, no
  copies.
+ Push 5 finds the buffer full and doubles: 4 elements ride into the
  capacity 8 block, cumulative 4.
+ Push 9 doubles 8 to 16: 4 + 8 = 12.
+ Push 17 doubles 16 to 32: 12 + 16 = 28.
+ Push 33 doubles 32 to 64: 28 + 32 = 60, capacity 64 holding size
  33.
+ Born at capacity 1 instead, 31 pushes grow at 1, 2, 4, 8, 16 and
  copy 1 + 2 + 4 + 8 + 16 = 31 = 2^5 - 1, copies equal to pushes.

#diagram([the growth ladder as five buffer snapshots, the live prefix shaded, the copy counter under each], length: 13pt, {
  let snaps = (((4, 4, 0), 0.8), ((5, 8, 4), 5.6), ((9, 16, 12), 10.4), ((17, 32, 28), 15.2), ((33, 64, 60), 20.0))
  for (i, s) in snaps.enumerate() {
    let (size, cap, copies) = s.at(0)
    let x = s.at(1)
    let live = 3.4 * size / cap
    cdraw.rect((x, 4.4), (x + live, 5.4), fill: luma(205), radius: 0.02)
    cdraw.rect((x + live, 4.4), (x + 3.4, 5.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.7, 5.9), [size #size], size: 6pt)
    cdraw.content((x + 1.7, 3.85), [cap #cap], size: 6pt)
    cdraw.content((x + 1.7, 3.05), [#copies copies], size: 6pt)
    if i < 4 {
      cdraw.line((x + 3.5, 4.9), (x + 4.45, 4.9), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((12.0, 2.1), [every grow doubles the block, half of it spare], size: 6pt)
  cdraw.content((12.0, 1.3), [copies 0, 4, 12, 28, 60: under 2 per push], size: 6pt)
})

The 60 copies over 33 pushes and the 2^5 - 1 case are pinned, and
the listings below build the vector six ways.

#listing("dsa/samples-c/src/Ch03/vector.c", first: 18, last: 41, caption: [c, the struct, the init, and the push with its grow path])

The C\# version is generic and bounds checked:

#listing("dsa/samples/src/Ch03/Dynamic.cs", first: 4, last: 45, caption: [the vector, counted growth, bounds checked indexer, add with grow on demand])

Insertion and removal at an interior index shift the tail one way or
the other, so they cost proportional to the distance to the end. The
version in the listing keeps that visible with `Array.Copy` doing the
shift, exactly what `List<T>.Insert` does internally:

#listing("dsa/samples/src/Ch03/Dynamic.cs", first: 46, last: 69, caption: [interior insert and remove shift the tail, trim shrinks storage])

#diagram([the vector, a fixed array plus count plus capacity, and the tail shifts interior edits cost], length: 13pt, {
  // anatomy: 8 slots, 5 live
  let cell = (x, y, w: 1.1, h: 0.7, fill: luma(235)) => cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
  let txt = (x, y, s, size: 6pt) => cdraw.content((x, y), s, size: size)
  for i in range(8) {
    cell(1.2 + i * 1.1, 5.0, fill: if i < 5 { luma(205) } else { luma(235) })
  }
  for (i, ch) in ("a", "b", "c", "d", "e").enumerate() {
    txt(1.75 + i * 1.1, 5.35, [#ch])
  }
  cdraw.line((1.2, 6.1), (10.0, 6.1), stroke: luma(100))
  cdraw.line((1.2, 6.1), (1.2, 6.3), stroke: luma(100)); cdraw.line((10.0, 6.1), (10.0, 6.3), stroke: luma(100))
  txt(5.6, 6.6, [capacity = 8: slots owned], size: 6.5pt)
  cdraw.line((1.2, 4.6), (6.7, 4.6), stroke: luma(100))
  cdraw.line((1.2, 4.6), (1.2, 4.4), stroke: luma(100)); cdraw.line((6.7, 4.6), (6.7, 4.4), stroke: luma(100))
  txt(3.95, 4.05, [count = 5: live elements], size: 6.5pt)

  // insert at 2: tail shifts right
  txt(1.7, 2.95, [insert x at 2], size: 6.5pt)
  let bi = ("a", "b", "c", "d", "e", ".")
  for (i, ch) in bi.enumerate() {
    cell(4.2 + i * 1.05, 2.6, w: 1.0, fill: if i == 5 { luma(235) } else { luma(205) })
    txt(4.7 + i * 1.05, 2.95, [#ch])
    txt(4.7 + i * 1.05, 2.25, [#i], size: 6pt)
  }
  cdraw.line((11.0, 2.95), (12.0, 2.95), stroke: luma(100), mark: (end: ">"))
  let ai = ("a", "x", "b", "c", "d", "e")
  for (i, ch) in ai.enumerate() {
    cell(12.4 + i * 1.05, 2.6, w: 1.0, fill: if i == 1 { luma(205) } else { luma(235) })
    txt(12.9 + i * 1.05, 2.95, [#ch])
  }
  txt(15.8, 2.0, [b c d e shifted right one], size: 6pt)

  // remove at 2: tail shifts left
  txt(1.7, 0.85, [remove b at 1], size: 6.5pt)
  let br = ("a", "b", "c", "d", "e")
  for (i, ch) in br.enumerate() {
    cell(4.2 + i * 1.05, 0.5, w: 1.0, fill: luma(205))
    txt(4.7 + i * 1.05, 0.85, [#ch])
    txt(4.7 + i * 1.05, 0.15, [#i], size: 6pt)
  }
  cdraw.line((11.0, 0.85), (12.0, 0.85), stroke: luma(100), mark: (end: ">"))
  let ar = ("a", "c", "d", "e", ".")
  for (i, ch) in ar.enumerate() {
    cell(12.4 + i * 1.05, 0.5, w: 1.0, fill: if i >= 1 and i <= 3 { luma(205) } else { luma(235) })
    txt(12.9 + i * 1.05, 0.85, [#ch])
  }
  txt(15.4, -0.1, [c d e shifted left one], size: 6pt)
})

Four more languages build the same structure:

#listing("dsa/samples-go/ch03/vector.go", first: 23, last: 39, caption: [go, grow doubles and records, push rides on append])

#listing("dsa/samples-js/src/ch03-vector.mjs", first: 24, last: 35, caption: [javascript, the push method and its grow path])

#listing("dsa/samples-py/src/Ch03/vector.py", first: 14, last: 32, caption: [python, the class through push, ladder recorded])

#listing("dsa/samples-lua/ch03_vector.lua", first: 6, last: 21, caption: [lua, init and push over a table that copies anyway])

The capacity ladder is the shared anchor. C, JavaScript, and Lua
snapshot every growth, capacity 4, 8, 16, 32, 64 at sizes 4, 5, 9,
17, 33 with cumulative copies 0, 4, 12, 28, 60, and all three pin
the first-capacity-1 case where 31 pushes copy exactly 2^5 - 1.
Go pins capacities 4, 8, 16, 32 with 28 copies over 32 pushes.
Python pins caps 4, 8, 16 with 12 copies at 9 pushes, its insert
riding spare capacity with no growth. Interior insert differs in
mechanism, C, JavaScript, and Lua push then bubble back, Go, Python,
and C\# shift the tail, and every suite pins the same resulting
order.

== the doubling argument

Chapter 1 stated the identity, this chapter runs it. C runs the two
policies side by side, one counter each.

The dry run: the fixture is the side-by-side table from capacity 4,
row by row, asserted by the C, JavaScript, and Lua suites. C\#
exhibits 4096 appends, Python records a cost per append, Go
cross-checks both totals.

+ One push and four pushes copy nothing: both policies still inside
  the first block.
+ Push 5 grows both: 4 elements copy, 4 against 4.
+ Push 17: doubling has grown at 4, 8, 16 for 4 + 8 + 16 = 28, step
  growth at 4, 8, 12, 16 for 4 + 8 + 12 + 16 = 40.
+ Push 31: doubling holds 28, its next growth waits for size 32,
  while step pays three more growths and reaches 112.
+ Push 65: doubling 124 against step 544, the last row.
+ Between the rows the bound breaks: at 128 appends step pays 1984
  against doubling's 124, and 1984 > 4 × 128 = 512.
+ The C\# exhibit scales the ladder: 4096 appends grow 12 times and
  copy 2^12 - 1 = 4095 elements, under one copy per append.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*pushes*], [*doubling copies*], [*step +4 copies*]),
  [1], [0], [0],
  [4], [0], [0],
  [5], [4], [4],
  [17], [28], [40],
  [31], [28], [112],
  [65], [124], [544],
)

The 4095 copies under one per append is the exhibit the tests pin
exactly, and the listings below run the race in six languages.

#listing("dsa/samples-c/src/Ch03/growth.c", first: 17, last: 42, caption: [c, both counters, doubling against constant step])

The C\# growth routine is two counters and a resize:

#listing("dsa/samples/src/Ch03/Dynamic.cs", first: 71, last: 78, caption: [grow doubles and records the copy cost])

The exhibit is the head to head: doubling against growing by a
constant step, same appends, counted copies:

#listing("dsa/samples/src/Ch03/Dynamic.cs", first: 80, last: 113, caption: [the two growth policies compared on the meter])

For 4096 appends doubling grows 12 times and copies 4095 elements,
under one copy per append on average. Growing by a fixed step copies
the triangular number, over 500 copies per append at the same size,
and the gap widens forever. The tests pin both totals exactly. This is
what amortized analysis means: an operation's average cost over any
sequence, not its worst single call, and the average is what a caller
actually experiences.

#diagram([copies per append on the meter, doubling spikes at powers of two while the constant step pays more every call], length: 13pt, {
  // axis: 32 appends, 0..32 copied elements per call
  let ax = k => 1.0 + (k - 1) / 31.0 * 20.0
  let ay = v => 1.0 + v / 32.0 * 5.0
  cdraw.line((1.0, 1.0), (21.0, 1.0), stroke: luma(100))
  cdraw.line((1.0, 1.0), (1.0, 6.2), stroke: luma(100))
  cdraw.content((1.0, 0.55), [append 1], size: 6pt)
  cdraw.content((21.0, 0.55), [append 32], size: 6pt)
  cdraw.content((0.35, 6.2), [32], size: 6pt)
  cdraw.content((0.35, 3.6), [16], size: 6pt)

  // doubling: a spike only when capacity doubles, height = old capacity
  for (k, h) in ((2, 1), (3, 2), (5, 4), (9, 8), (17, 16)) {
    cdraw.line((ax(k), 1.0), (ax(k), ay(h)), stroke: luma(100))
    cdraw.circle((ax(k), ay(h)), radius: 0.08, fill: luma(100))
  }

  // constant step 1: append k pays k-1
  for k in range(2, 33) {
    cdraw.line((ax(k), 1.0), (ax(k), ay(k - 1)), stroke: luma(205))
  }
  cdraw.content((16.5, 5.7), [step +1: append k copies k-1], size: 6pt)
  cdraw.content((7.2, 4.35), [doubling: spike of 16 at 17], size: 6pt)
  cdraw.content((11.0, 6.7), [4096 appends: 4095 copies versus the triangular number], size: 6.5pt)
})

The other four languages run the same race:

#listing("dsa/samples-go/ch03/growth.go", first: 9, last: 34, caption: [go, both policies as plain counted loops])

#listing("dsa/samples-js/src/ch03-growth.mjs", first: 17, last: 39, caption: [javascript, the two copy counters behind the table])

#listing("dsa/samples-py/src/Ch03/growth.py", first: 14, last: 31, caption: [python, a cost recorded per append, the policy as a function])

#listing("dsa/samples-lua/ch03_growth.lua", first: 6, last: 28, caption: [lua, both counters in while loops])

The numbers line up wherever the topic runs. C, JavaScript, and Lua
pin the side-by-side table, 28 against 40 copies at 17 appends, 124
against 544 at 65, and the bound, doubling never above 4 copies per
append up to 200 while step growth pays 1984 for 128 appends. Python
records a cost per append, 4 then 8 on the doubling ladder, 144
total for 36 step appends, and 612 at 72. Go runs both policies as
plain loops with the totals cross-checked in its tests. C\# exhibits
4096 appends, 12 grow calls, 4095 copied elements against a step
policy past 500 copies per append.

#callout("note", "when the average is a lie", [
  Amortization is honest only when the caller cannot observe the
  expensive call. A realtime or latency-sensitive path can feel every
  doubling of a large list, a hundreds of megabyte array copying
  itself is a pause. The standard mitigations are capacity
  pre-reservation, `List<T>` accepts it in the constructor, and
  pooled buffers, `ArrayPool<T>.Rent`, which trades the copy for
  reuse discipline.
])

== list versus linked, the decision

#flow(
  [list versus linked, where each structure actually wins],
  node((0, 0), [front inserts?]),
  node((-2.9, -1.8), [vector shifts the tail, #linebreak() linked writes one node]),
  node((0, -1.8), [iteration between edits: #linebreak() every hop is a stride walk]),
  node((2.9, -1.8), [remove by held reference: #linebreak() links splice without search]),
  node((0, -3.8), [arrays first, links only when #linebreak() elements move by reference]),
  edge((0, 0), (-2.9, -1.8), "-|>"),
  edge((0, 0), (0, -1.8), "-|>"),
  edge((0, 0), (2.9, -1.8), "-|>"),
  edge((-2.9, -1.8), (0, -3.8), "-|>"),
  edge((0, -1.8), (0, -3.8), "-|>"),
  edge((2.9, -1.8), (0, -3.8), "-|>"),
)

Front insertion is the vector's weak spot and the linked list's
non-event: 500 front inserts into a vector shift the tail 500 times,
while `AddFirst` on a linked list touches 1 node. The test suite runs
both. The honest summary of the whole trade:

#callout("warning", "the constant factors do not cancel", [
  A linked node is a separate allocation with two references of
  overhead and every hop is a pointer chase, chapter 2's strided walk
  at stride one node. In practice a contiguous vector beats a linked
  list even for the linked list's nominal wins unless removals happen
  through held node references rather than searches. BCL guidance
  says the same: `LinkedList<T>` is rarely the right answer, and the
  next chapter's ring exists as much to show why as to show how.
])

The dry run: no suite pins these shift counts, the numbers are
hand-derived, and the C\# suite runs the 500-insert original and
pins its final order.

+ The fixture: five front inserts of 4, 3, 2, 1, 0 into a vector
  with capacity to spare, grow noise removed the way the test
  removes it.
+ Insert 4 shifts nothing, 3 shifts one element, 2 shifts two, 1
  shifts three, 0 shifts four: 0 + 1 + 2 + 3 + 4 = 10 shifted
  elements.
+ The linked list pays the same five inserts at one node write each,
  5 writes, and no element ever moves.
+ Scaled to the test's 500 inserts, the vector shifts
  499 × 500 / 2 = 124750 elements against 500 node writes.
+ The order is pinned at both ends: slot 0 reads 499 and slot 499
  reads 0.

#diagram([five front inserts, the vector's growing shift against the linked list's flat one node per insert], length: 13pt, {
  let frames = (((4,), 0.6), ((3, 4), 5.2), ((2, 3, 4), 9.8), ((1, 2, 3, 4), 14.4), ((0, 1, 2, 3, 4), 19.0))
  for (k, f) in frames.enumerate() {
    let (cells, x) = (f.at(0), f.at(1))
    for (j, v) in cells.enumerate() {
      cdraw.rect((x + j * 0.85, 5.9), (x + j * 0.85 + 0.8, 6.7), fill: if j == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + j * 0.85 + 0.4, 6.3), [#v], size: 6pt)
    }
    cdraw.content((x + 0.4 * cells.len(), 5.45), [shifts #k], size: 6pt)
    if k < 4 {
      let xe = x + 0.85 * cells.len() + 0.82
      cdraw.line((xe + 0.15, 6.3), (xe + 1.05, 6.3), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((0.6, 4.5), [the linked list lane: one new node per insert, nothing moves], size: 6.5pt)
  for (j, v) in (4, 3, 2, 1, 0).enumerate() {
    let x = 0.6 + j * 1.9
    cdraw.rect((x, 3.2), (x + 1.6, 3.9), fill: if j == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.8, 3.55), [#v], size: 6pt)
    if j < 4 { cdraw.line((x + 1.6, 3.55), (x + 1.9, 3.55), stroke: luma(100)) }
  }
  cdraw.content((0.6, 2.6), [insertion order, newest at the right], size: 6pt)
  cdraw.content((0.6, 1.8), [vector: 10 shifts, linked: 5 writes], size: 6pt)
  cdraw.content((0.6, 1.0), [at n = 500: 124750 shifted elements against 500 writes], size: 6pt)
})

The 124750 against 500 is the trade at the test's scale, arrays
first until elements move by reference.

== across the six languages

Build sizes count non-comment source lines over the featured files;
bundled checks count where the language puts them in the same file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [138], [libc + malloc], [the grow path hand copies and frees, copy totals in unsigned long long],
  [c\#], [92], [bcl only], [generic vector, the (uint) cast folds the negative check into the bound],
  [go], [76], [fmt for errors], [append does the copy, the count still records len at each grow],
  [javascript], [79], [node stdlib], [private fields hold the state, push returns this for chaining],
  [python], [103], [stdlib only], [dead slots hold None, pop clears the slot it releases],
  [lua], [125], [lib.lua harness], [tables grow natively, this build copies anyway to keep the count honest],
)

sources: learn.microsoft.com, `List<T>` api page including the growth
remarks, `ArrayPool<T>`, `Array.Resize`, capacity management guidance
in the performance docs, accessed 2026-09-08. Sample behavior
verified by `make verify-csharp`, 9 tests in chapter 3 of the samples
suite. The six-language layer verifies the same way: 2 C programs
under `make verify-c`, 8 Go tests, 6 `node --test` cases, 20 Python
checks across 2 files, and 8 Lua checks under `run.lua`.
