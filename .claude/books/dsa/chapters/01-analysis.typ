#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= complexity analysis and honest benchmarking

Every later chapter claims a cost: hash tables say constant average,
balanced trees say logarithmic, sorts say linearithmic. This chapter
builds the two instruments those claims must survive, operation
counting for structural costs and allocation counting for memory
costs, and shows why wall clock time is the last thing to trust in a
test.

== counting operations

Big-O is a statement about operation counts as n grows, so the honest
test counts operations. A counter with a reset, plus closed-form
models the instrumented run can be checked against. C counts the
copies directly, one growth policy at a time.

The dry run: the fixture is doubling growth from capacity 1, the
step-4 contrast from capacity 4, and the all-pairs loop, asserted by
the C, Java, JavaScript, and Lua suites with the same numbers, Python
walks the same counters with step 1, and C\# and Go state the closed
forms and hold counted runs to them.

+ Nine pushes from capacity 1 grow at sizes 1, 2, 4, 8, and the
  counter folds 1 + 2 = 3, 3 + 4 = 7, 7 + 8 = 15.
+ Thirty-one pushes add one more growth: 15 + 16 = 31 = 2^5 - 1,
  copies exactly equal to pushes.
+ The closed form 2^m - 1 holds at every size: the C\# suite pins the
  doubling count at 1, 2, 10, 13 for n = 2, 3, 1024, 4097 and keeps
  every total under 2n, and Java's Allocs pins the same ladder from
  n = 1, 0 doublings, under the same 2n line.
+ The quadratic counter compares each pair once: ten items give
  10 × 9 / 2 = 45 pairs, the insertion sort worst case of chapter 13.
+ The amortized contrast, amortized meaning the average cost over the
  sequence and chapter 3's subject: 128 pushes from capacity 4 copy
  1984 elements under step-4 growth against 124 under doubling, and
  1984 > 4 × 128 = 512 breaks any constant per-append budget.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*push*], [*buffer full at*], [*copied*], [*total so far*], [*capacity after*]),
  [2], [1], [1], [1], [2],
  [3], [2], [2], [3], [4],
  [5], [4], [4], [7], [8],
  [9], [8], [8], [15], [16],
  [17], [16], [16], [31], [32],
)

The 1984 against 124 is the contrast the meters pin, and the
listings below count the same copies in seven languages.

#listing("dsa/samples-c/src/Ch01/countops.c", first: 17, last: 44, caption: [c, copy totals under doubling and constant-step growth])

The C suite pins the contrast from its main: 128 pushes into a
capacity 4 buffer copy 1984 elements when capacity grows by 4 each
time, and 124 when it doubles. Go keeps the counted doubling loop
beside the closed form that predicts it:

#listing("dsa/samples-go/ch01/countops.go", first: 31, last: 45, caption: [go, the counted doubling loop and the closed form that predicts it])

The doubling model is the whole amortization argument of chapter 3 in
one formula: growing an array by doubling copies `2^m - 1` elements
over n appends, which is less than 2n, so appends are constant on
average even though every m-th one is a full copy. The quadratic model
is the number of inverted pairs, the exact worst-case comparison count
of insertion sort in chapter 13.

The other five languages count the same copies with their own
instruments, each checked against a closed form by its suite. Java
mirrors C's loops in long arithmetic straight from its main, and C\#
factors the idea into a reusable counter plus closed-form cost models:

#listing("dsa/samples-java/src/Ch01/Countops.java", first: 18, last: 51, caption: [java, the three counters in long arithmetic, the same 1984 against 124 pinned from main])

#listing("dsa/samples/src/Ch01/Analysis.cs", first: 3, last: 36, caption: [c\#, the counter and the closed-form cost models])

#listing("dsa/samples-js/src/ch01-countops.mjs", first: 7, last: 34, caption: [javascript, both growth policies as plain functions])

#listing("dsa/samples-py/src/Ch01/countops.py", first: 14, last: 33, caption: [python, the two counters with the grow spelled out in comments])

#listing("dsa/samples-lua/ch01_countops.lua", first: 7, last: 30, caption: [lua, the two counters as local functions])

Measured across the suites: the counted loops cost 15 lines in Go, 28
in C, 34 in Java, 28 in JavaScript, 20 in Python, and 24 in Lua. The
fixture families differ on purpose. C, Java, JavaScript, and Lua grow
from capacity 4 with step 4, pinning 128 pushes at 1984 copied
elements against doubling's 124. Python grows from capacity 1 and
shows step 1 paying the triangular 45 for 10 pushes. C\# and Go state
the closed forms, 2^m - 1 and n(n-1)/2, and hold the counted runs to
them, and Java spans both lanes across its files, Countops in C's
family and Allocs carrying the closed forms. Every family agrees on
the anchor that matters: doubling's copy total stays linear in n.

#diagram([the counter instruments the run, the closed forms predict it, and the three growth curves carry the shapes], length: 13pt, {
  // left panel: doubling copies zoomed against n and the 2n bound
  let sx = n => 0.4 + n / 64.0 * 8.6
  let sy = v => 1.0 + v / 130.0 * 5.0
  cdraw.line((0.4, 1.0), (9.0, 1.0), stroke: luma(100))
  cdraw.line((0.4, 1.0), (0.4, 6.0), stroke: luma(100))
  cdraw.line((0.4, 1.0), (9.0, sy(64)), stroke: luma(100))
  cdraw.line((0.4, 1.0), (9.0, sy(128)), stroke: (paint: luma(220), dash: "dashed"))
  cdraw.line((0.4, 1.0), (sx(2), 1.0), stroke: luma(100))
  let steps = ((2, 1, 3), (3, 3, 5), (5, 7, 9), (9, 15, 17), (17, 31, 33), (33, 63, 64))
  let prevv = 0
  for s in steps {
    let (t, v, e) = s
    cdraw.line((sx(t), sy(prevv)), (sx(t), sy(v)), stroke: luma(100))
    cdraw.line((sx(t), sy(v)), (sx(e), sy(v)), stroke: luma(100))
    prevv = v
  }
  cdraw.content((6.8, 5.55), [2n ceiling], size: 6pt)
  cdraw.content((5.2, 2.6), [2^m - 1], size: 6pt)
  cdraw.content((7.6, 2.75), [n], size: 6pt)
  cdraw.content((9.0, 0.6), [n = 64], size: 6pt)
  cdraw.content((4.7, 6.5), [copies under doubling growth, zoomed], size: 6.5pt)

  // right panel: the three closed forms at full scale
  cdraw.line((10.6, 1.0), (23.2, 1.0), stroke: luma(100))
  cdraw.line((10.6, 1.0), (10.6, 6.0), stroke: luma(100))
  let rx = n => 10.6 + n / 64.0 * 12.6
  let ry = v => 1.0 + v / 2016.0 * 5.0
  let pts = ((0, 0), (8, 28), (16, 120), (24, 276), (32, 496), (40, 780), (48, 1128), (56, 1640), (64, 2016))
  cdraw.line(..pts.map(p => (rx(p.at(0)), ry(p.at(1)))), stroke: luma(100))
  cdraw.line((rx(0), 1.0), (rx(64), ry(64)), stroke: luma(100))
  cdraw.line((rx(0), 1.0), (rx(64), ry(128)), stroke: (paint: luma(220), dash: "dashed"))
  cdraw.content((20.6, 5.5), [n(n-1)/2], size: 6pt)
  cdraw.content((14.6, 0.55), [n, 2^m - 1], size: 6pt)
  cdraw.content((23.2, 0.6), [n = 64], size: 6pt)
  cdraw.content((17.7, 6.5), [the three closed forms at full scale], size: 6.5pt)
})

== binary search, probed

Binary search's logarithm is verifiable, not just quotable.
Instrumenting the loop to count probes turns the claim into an
inequality every index must satisfy. C hands the count back through
an out parameter.

The dry run: the fixture is 1024 sorted slots, and all seven suites
pin the same anchors, worst present key 11 probes, absence below the
range 10, absence above it 11.

+ The first probe always lands at the floor midpoint of 0..1023,
  0 + (1023 - 0) / 2 = 511, and key 511 hits on probe one.
+ Key 767 pays two: lo climbs to 512 and the next midpoint is
  512 + (1023 - 512) / 2 = 767. C, JavaScript, and Lua pin both
  paths.
+ Absence below every key, target -5, halves downward through mids
  511, 255, 127, ..., 1, 0, each the floor of a halved interval, and
  the interval empties after 10 probes.
+ Absence above, target 5000, climbs through 511, 767, 895, ...,
  1022, 1023 and pays 11, one more, because the rounded-down midpoint
  descends faster than it ascends.
+ Every present key resolves within 11 = ceil(log2 1024) + 1 probes,
  and exactly one key pays the full 11, pinned by the Python suite.

#diagram([the probe midpoints in visit order, one lane per target, the shared first probe shaded], length: 13pt, {
  let lane = (y, title, mids) => {
    cdraw.content((1.6, y + 0.6), title, size: 6pt)
    let w = if mids.len() >= 10 { 1.45 } else { 1.7 }
    let gap = calc.min(20.6 / mids.len(), 2.4)
    for (k, m) in mids.enumerate() {
      let x = 1.0 + k * gap
      cdraw.rect((x, y - 0.24), (x + w, y + 0.24), fill: if k == 0 { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + w / 2, y), [#m], size: 6pt)
    }
  }
  lane(6.3, [key 511: 1 probe], (511,))
  lane(5.1, [key 767: 2 probes], (511, 767))
  lane(3.3, [absent below, -5: 10 probes], (511, 255, 127, 63, 31, 15, 7, 3, 1, 0))
  lane(1.1, [target 1023: 11 probes], (511, 767, 895, 959, 991, 1007, 1015, 1019, 1021, 1022, 1023))
  cdraw.content((1.6, -0.2), [every target probes 511 first], size: 6pt)
  cdraw.content((1.6, -0.9), [floor mid descends faster: 10 probes below, 11 above], size: 6pt)
})

The 10 against 11 is the anchored asymmetry, and the listings below
carry the instrument in seven languages.

#listing("dsa/samples-c/src/Ch01/probebin.c", first: 17, last: 33, caption: [c, floor-mid search with the probe count as an out parameter])

#listing("dsa/samples-go/ch01/probebin.go", first: 6, last: 25, caption: [go, the probed loop and the worst-case sweep it feeds])

The other five languages carry the same instrument, Java handing the
count back as a record where C uses an out parameter:

#listing("dsa/samples-java/src/Ch01/Probebin.java", first: 18, last: 34, caption: [java, floor-mid search returning a record that pairs index with probes])

#listing("dsa/samples/src/Ch01/Analysis.cs", first: 38, last: 66, caption: [c\#, probe counting search, worst case over all indices])

On 1024 slots every position resolves within 11 probes, the ceiling of
the base-2 logarithm plus one, and some position needs all 11. The
suite pins a subtler fact too, one that interview answers usually miss:

#callout("note", "floor mid makes absence asymmetric", [
  The classic loop computes `mid = lo + (hi - lo) / 2`, rounding down.
  Proving a target below the range is absent takes one probe less than
  proving absence above it, 10 versus 11 on 1024 slots, because the
  rounded-down midpoint descends faster than it ascends. The test
  `Absent_target_costs_no_more_than_the_worst_case` pins both numbers.
])

The other three languages carry the same instrument:

#listing("dsa/samples-js/src/ch01-probebin.mjs", first: 5, last: 19, caption: [javascript, the probe count returned in an object])

#listing("dsa/samples-py/src/Ch01/probebin.py", first: 14, last: 25, caption: [python, floor midpoint with no overflow rewrite needed])

#listing("dsa/samples-lua/ch01_probebin.lua", first: 7, last: 22, caption: [lua, two return values over one-based bounds])

All seven suites pin the same anchors on 1024 slots: the worst present
key costs 11 probes, absence below the range costs 10, absence above
costs 11. C, Java, JavaScript, and Lua pin the path as well, first
probe at 511, second at 767. Python pins that exactly one key pays the
full 11, and adds an 8-slot array that resolves its low extreme in 3
probes and an absent key in 4. Go keeps the instrument inside one
function that reports only what the sweep needs. The return shapes
differ, an out parameter, a record, an object, two values, an early
return, and the anchors do not move.

#diagram([binary search on 1024 slots, each probe halves the surviving range], length: 13pt, {
  let rowy = k => 6.0 - (k - 1) * 0.52
  let lx = i => 0.6 + i / 1023.0 * 10.8
  let rx = i => 12.4 + i / 1023.0 * 10.8
  let bar = (x0, x1, y) => cdraw.rect((x0, y - 0.17), (calc.max(x1, x0 + 0.12), y + 0.17), fill: luma(235), radius: 0.02)
  let dot = (x, y) => cdraw.circle((x, y), radius: 0.09, fill: luma(100))

  // left: target below every key, interval halves exactly, 10 probes
  let left = ((0, 1023, 511), (0, 510, 255), (0, 254, 127), (0, 126, 63), (0, 62, 31), (0, 30, 15), (0, 14, 7), (0, 6, 3), (0, 2, 1), (0, 0, 0))
  for (k, s) in left.enumerate() {
    bar(lx(s.at(0)), lx(s.at(1)), rowy(k + 1))
    dot(lx(s.at(2)), rowy(k + 1))
  }
  cdraw.content((6.6, 6.0), [511], size: 6pt)
  cdraw.content((3.9, 5.48), [255], size: 6pt)
  cdraw.content((2.55, 4.96), [127], size: 6pt)
  cdraw.content((0.95, 1.32), [0], size: 6pt)
  cdraw.content((5.2, 2.1), [mids 511, 255, 127, ..., 1, 0], size: 6pt)
  cdraw.content((6.0, 6.9), [target below every key: 10 probes], size: 6.5pt)

  // right: target 1023, the worst case, interval creeps upward, 11 probes
  let right = ((0, 1023, 511), (512, 1023, 767), (768, 1023, 895), (896, 1023, 959), (960, 1023, 991), (992, 1023, 1007), (1008, 1023, 1015), (1016, 1023, 1019), (1020, 1023, 1021), (1022, 1023, 1022), (1023, 1023, 1023))
  for (k, s) in right.enumerate() {
    bar(rx(s.at(0)), rx(s.at(1)), rowy(k + 1))
    dot(rx(s.at(2)), rowy(k + 1))
  }
  cdraw.content((17.0, 6.0), [511], size: 6pt)
  cdraw.content((19.65, 5.48), [767], size: 6pt)
  cdraw.content((21.0, 4.96), [895], size: 6pt)
  cdraw.content((22.25, 1.35), [1023], size: 6pt)
  cdraw.content((17.3, 2.1), [mids 511, 767, 895, ..., 1023], size: 6pt)
  cdraw.content((17.8, 6.9), [target 1023, worst case: 11 probes], size: 6.5pt)

  cdraw.content((11.9, 0.25), [the rounded-down mid halves exactly downward, so proving absence below costs 10 probes against 11 above], size: 6.5pt)
})

== counting allocations

Managed allocations are countable exactly where the runtime reports
them. `GC.GetAllocatedBytesForCurrentThread()` reports bytes
allocated on the current thread since its start, so differencing it
around an action measures that action's allocation with no sampling
error. The other trees count what they can see, C its own malloc
calls, Go AllocsPerRun, Java the substring call whose fresh string it
cannot avoid, Python tracemalloc snapshots. Time has
jitter, thread switches, frequency scaling. Bytes do not.

The dry run: the fixtures are the headers id+721 and seq+999 plus the
malformed id+7x2, asserted by all seven suites on the same parse
values. Each tree meters the allocation lane its own honest way, and
no lane fakes a count.

+ Parse the digits both ways everywhere: the substring road copies
  the tail after the separator into fresh storage and parses the
  copy, the walk road folds the same characters in place:
  0 × 10 + 7 = 7, 7 × 10 + 2 = 72, 72 × 10 + 1 = 721.
+ Both parsers return 721 in every suite, and the six new trees pin
  seq+999 to 999 both ways, C\# exercises that header through its
  meter harness.
+ The walk rejects id+7x2 in every tree, as an exception, a nonzero
  exit code, or a thrown error per the tree's own mechanism.
+ C counts its own mallocs, 1 for the substring road against 0 for
  the walk.
+ Go pins AllocsPerRun at exactly 1 against 0, with a documented sink
  that keeps the digit string live so the substring road honestly
  escapes to the heap instead of staying on the stack.
+ Java counts the substring road's unavoidable fresh strings, exactly
  1 per parse, and the in-place walk leaves the counter untouched.
+ C\# differences the thread's allocated byte count around each parse,
  strictly above 0 for the substring road and exactly 0 for the walk.
+ Python compares tracemalloc snapshots and asserts the slice road
  allocates strictly more than the walk, an inequality, because
  interpreter bookkeeping makes exact byte equality tree-specific.
  JavaScript and Lua assert the parse values and the rejection only.

#diagram([the two parses as step chains, one allocation box against three in-place folds], length: 13pt, {
  let step = (x, y, w, body, hot) => {
    cdraw.rect((x, y - 0.3), (x + w, y + 0.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y), body, size: 6pt)
  }
  let arrow = (x, y) => cdraw.line((x, y), (x + 0.55, y), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.6, 6.6), [substring parse], size: 6.5pt)
  step(0.6, 5.6, 2.6, [read b0], false)
  arrow(3.2, 5.6)
  step(3.75, 5.6, 3.4, [slice 3..: one new string], true)
  arrow(7.15, 5.6)
  step(7.7, 5.6, 3.0, [int.Parse: 721], false)
  arrow(10.7, 5.6)
  step(11.25, 5.6, 3.2, [b1 - b0 > 0], true)
  cdraw.content((0.6, 3.4), [span parse], size: 6.5pt)
  step(0.6, 2.4, 2.6, [read b0], false)
  arrow(3.2, 2.4)
  step(3.75, 2.4, 2.6, [0 × 10 + 7 = 7], false)
  arrow(6.35, 2.4)
  step(6.9, 2.4, 2.8, [7 × 10 + 2 = 72], false)
  arrow(9.7, 2.4)
  step(10.25, 2.4, 3.2, [72 × 10 + 1 = 721], false)
  arrow(13.45, 2.4)
  step(14.0, 2.4, 2.8, [b1 - b0 = 0], true)
  cdraw.content((0.6, 0.9), [same digits, same 721, the meter is the only difference], size: 6.5pt)
})

The strictly positive against exactly 0 is the pinned pair, and the
listings below are the meters that produced it, one per tree:

#listing("dsa/samples-c/src/Ch01/allocs.c", first: 53, last: 85, caption: [c, counted mallocs split the substring road from the walk])

#listing("dsa/samples-go/ch01/allocs.go", first: 84, last: 119, caption: [go, the sink that keeps the substring allocation observable, then both parses])

The other five languages carry the same two roads with the meter each
runtime can honestly support:

#listing("dsa/samples-java/src/Ch01/Allocs.java", first: 60, last: 79, caption: [java, the substring road's one fresh string counted by hand, the walk reads in place])

#listing("dsa/samples/src/Ch01/Analysis.cs", first: 68, last: 108, caption: [c\#, allocation counting, the stopwatch wrapper, two parses])

#listing("dsa/samples-js/src/ch01-allocs.mjs", first: 53, last: 72, caption: [javascript, the slice road and the in-place walk, values asserted only])

#listing("dsa/samples-py/src/Ch01/allocs.py", first: 46, last: 61, caption: [python, the slice road and the in-place walk])

#listing("dsa/samples-lua/ch01_allocs.lua", first: 50, last: 68, caption: [lua, substring against byte walk, values and rejection only])

Measured across the suites: both roads parse id+721 to 721 in all
seven languages and seq+999 to 999 in the six new trees, and every
walk rejects id+7x2.
The meter lanes stay honest per tree. C counts mallocs, 1 against 0.
Go pins AllocsPerRun at exactly 1 against 0. Java counts the
substring road's fresh string as one call the walk never makes. C\#
differences the GC byte counter, strictly positive against exactly 0.
Python's tracemalloc shows the slice road allocating strictly more
than the walk. JavaScript and Lua stop at the values, nothing they
carry exposes a countable allocation meter.

That contrast, allocation as a cost with an exact meter where the
runtime offers one, recurs through this book whenever a data
structure is asked whether it really avoids copying.

#diagram([the allocation meter differenced around the call, substring against span], length: 13pt, {
  cdraw.content((7.0, 6.2), [one meter, differenced around the call], size: 6.5pt)
  cdraw.rect((0.5, 5.0), (2.3, 5.7), fill: luma(235), radius: 0.02)
  cdraw.content((1.4, 5.35), [b0], size: 6pt)
  cdraw.rect((3.7, 5.0), (6.3, 5.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 5.35), [action()], size: 6pt)
  cdraw.rect((7.7, 5.0), (9.5, 5.7), fill: luma(235), radius: 0.02)
  cdraw.content((8.6, 5.35), [b1], size: 6pt)
  cdraw.rect((10.9, 5.0), (13.6, 5.7), fill: luma(235), radius: 0.02)
  cdraw.content((12.25, 5.35), [b1 - b0], size: 6pt)
  cdraw.line((2.3, 5.35), (3.7, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.3, 5.35), (7.7, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.5, 5.35), (10.9, 5.35), stroke: luma(100), mark: (end: ">"))

  cdraw.content((1.3, 3.4), [substring parse], size: 6pt)
  cdraw.rect((4.6, 3.1), (19.0, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 3.4), [one fresh string for the digits], size: 6pt)
  cdraw.content((21.0, 3.4), [bytes > 0], size: 6pt)

  cdraw.content((1.3, 2.1), [span parse], size: 6pt)
  cdraw.rect((4.6, 1.8), (19.0, 2.4), stroke: luma(100), radius: 0.02)
  cdraw.content((11.8, 2.1), [walks the same chars in place], size: 6pt)
  cdraw.content((21.0, 2.1), [bytes = 0], size: 6pt)

  cdraw.content((11.9, 0.9), [same digits, same answer, the meter is the only difference], size: 6.5pt)
})

#callout("warning", "what this harness is not", [
  This is a teaching harness. Production measurement belongs in
  BenchmarkDotNet, which handles warmup iterations, outlier
  filtering, and statistical comparison, and whose docs are listed in
  the sources line. `Stopwatch` plus allocation counting earns its
  place in a test suite because its assertions are deterministic, not
  because it is a rigorous benchmark.
])

== reading a cost claim

#flow(
  [reading a cost claim, three questions and the three famous hides],
  node((0, 0), [name n: elements, #linebreak() key length, requests]),
  node((0, -1.7), [name the counted operation: #linebreak() comparisons, probes, copies]),
  node((0, -3.4), [name the worst case]),
  node((-2.9, -5.3), [hash O(1) hides #linebreak() the rehash]),
  node((0, -5.3), [quicksort average hides #linebreak() the adversarial pivot]),
  node((2.9, -5.3), [amortized append hides #linebreak() the doubling copy]),
  edge((0, 0), (0, -1.7), "-|>"),
  edge((0, -1.7), (0, -3.4), "-|>"),
  edge((0, -3.4), (-2.9, -5.3), "-|>"),
  edge((0, -3.4), (0, -5.3), "-|>"),
  edge((0, -3.4), (2.9, -5.3), "-|>"),
)

Three questions turn a claim like "O(1) average" into something
checkable. What is n, the element count, the key length, the request
rate. What is the operation being counted, comparisons, probes,
bytes copied. And what does the worst case look like, because the
hash table's average hides the rehash, the quicksort's average hides
the adversarial pivot, and the amortized append hides the doubling
copy. The rest of the book answers those questions per structure,
with a counter where a skeptic can put a breakpoint.

The dry run: no suite carries this walk, the numbers are
hand-derived, and the claim on trial is that appending to a growable
array costs O(1) on average.

+ Name n: the element count, one hundred appends into an array born
  at capacity 1.
+ Name the counted operation: elements physically copied by growth,
  not milliseconds.
+ Name the worst case: the 65th append lands on a full buffer of 64
  and copies all 64, one call hiding 64 copies.
+ The total for the run: growths at sizes 1, 2, 4, 8, 16, 32, 64
  copy 1 + 2 + 4 + 8 + 16 + 32 + 64 = 127 = 2^7 - 1.
+ The average the claim means: 127 / 100 = 1.27 copies per append,
  inside 2 × 100 = 200 for the whole run.

#diagram([the three questions applied to one claim, the worst call against the average it hides], length: 13pt, {
  let q = (x, w, body) => {
    cdraw.rect((x, 6.2), (x + w, 7.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.65), body, size: 6pt)
  }
  q(0.8, 6.6, [1. name n: 100 appends])
  cdraw.line((7.4, 6.65), (8.0, 6.65), stroke: luma(100), mark: (end: ">"))
  q(8.0, 6.6, [2. count copies, not time])
  cdraw.line((14.6, 6.65), (15.2, 6.65), stroke: luma(100), mark: (end: ">"))
  q(15.2, 7.2, [3. worst call: 64 copies])
  cdraw.line((0.8, 1.0), (18.0, 1.0), stroke: luma(100))
  cdraw.rect((7.0, 1.0), (8.6, 5.3), fill: luma(205), radius: 0.02)
  cdraw.content((7.8, 5.7), [worst single call: 64], size: 6pt)
  cdraw.rect((12.4, 1.0), (14.0, 1.1), fill: luma(235), stroke: luma(160), radius: 0.02)
  cdraw.content((13.2, 1.6), [average: 1.27], size: 6pt)
  cdraw.content((9.4, 0.3), [growth copies 1 + 2 + ... + 64 = 127 across 100 appends], size: 6pt)
})

The 64-copy call inside the 1.27 average is what the three questions
expose, and chapter 3 runs the same argument on real meters.

== across the seven languages

The build sizes count non-comment source lines over this chapter's
featured files. Where a language bundles its checks into the same
file the count carries them, and where the suite lives in a separate
test project it does not, which is most of the C and Lua gap:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [257], [libc only], [checks share the file with main, 66 of them, counters are unsigned long long],
  [go], [151], [errors, strconv, strings], [the closed form shifts 1 << m inside int64, a documented sink keeps the substring road's one allocation observable],
  [java], [250], [jdk 27 stdlib], [no malloc to hook and no exposed allocation byte counter, the meter hand-counts the substring road's one fresh string, long exact since every count sits far below 2^63],
  [c\#], [85], [bcl only], [gc byte counting stays the finest meter of the seven, each tree asserts what its runtime honestly exposes],
  [javascript], [97], [node stdlib], [every count sits far below 2^53, Number is exact with no boundary in play, the parse lanes assert values only],
  [python], [173], [stdlib only], [native ints, the floor midpoint needs no overflow-safe rewrite, tracemalloc compares the parse roads by inequality],
  [lua], [248], [lib.lua harness], [1-based indexing moves the bounds, floor division has its own operator, checks ride in the module],
)

sources: learn.microsoft.com, `GC.GetAllocatedBytesForCurrentThread`
and `Stopwatch` api pages, `Memory<T> and Span<T>` usage guidelines,
benchmarkdotnet docs at benchmarkdotnet.org, accessed 2026-09-08.
Sample behavior verified by `make verify-csharp`, 10 tests in chapter
1 of the samples suite. The seven-language layer verifies the same
way: 3 C programs with 66 embedded checks under `make verify-c`, 17
Go tests, the java runner's 66 Ch01 checks over 3 files under
`run-java-samples`, 20 `node --test` cases, 51 Python checks across
3 files, and 19 Lua checks under `run.lua`.
