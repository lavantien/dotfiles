#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= searching and answer spaces

Binary search is one idea with a dozen correct-looking wrong
implementations. This chapter builds the boundary forms that are
always right, the rotated variant, and the search-over-answers
pattern that turns binary search on arrays into binary search on
any monotone predicate. The string matchers live next door in
chapter 15.

== boundaries, not hits

Searching for "an element equal to x" is the fragile framing. The
robust one asks for the first index where the array element is at
least the target, lower bound, or strictly greater, upper bound.
Everything else is arithmetic on those two.

The dry run: the fixture is 1 3 3 3 5 7 9 9, asserted by the C\#
suite, while the integer suites walk the six-element cut 1 3 3 3 5 7
and Go its 1 2 2 2 5 7 twin.

+ Lower bound of 3 opens the half-open 0..8 and probes slot 4: the 5
  there is not below 3, so hi closes to 4 and the upper half is gone.
+ Slots 2 and 1 both hold 3, still not below, hi walks to 2 then 1,
  and slot 0's 1 finally moves lo to 1: the walk returns 1, the
  first slot at least 3.
+ Upper bound keeps equals on lo's side: slots 2 and 3 pass 3 and lo
  walks 3 then 4, three probes closing at 4, the first greater.
+ Count is the subtraction, 4 - 1 = 3, leftmost reads the 1 back,
  and rightmost reads 4 - 1 = 3.
+ The absent 4 inserts at 4, between the 3s and the 5, the off-end
  keys 0 and 100 read back 0 and 8, and leftmost of 8 and rightmost
  of 2 both return -1.

#table(
  columns: (auto, auto, auto, auto, auto, 1.3fr),
  inset: 4pt,
  table.header([*walk*], [*lo*], [*hi*], [*mid*], [*a[mid]*], [*move*]),
  [lower], [0], [8], [4], [5, not below 3], [hi = 4],
  [lower], [0], [4], [2], [3, not below 3], [hi = 2],
  [lower], [0], [2], [1], [3, not below 3], [hi = 1],
  [lower], [0], [1], [0], [1, below 3], [lo = 1],
  [upper], [0], [8], [4], [5, above 3], [hi = 4],
  [upper], [0], [4], [2], [3, equals], [lo = 3],
  [upper], [3], [4], [3], [3, equals], [lo = 4],
)

The 1 and the 4 around the count 3 are the pinned triple, and the
listings below run the same two loops in six languages.

#listing("dsa/samples/src/Ch14/Searching.cs", first: 4, last: 49, caption: [c\#, lower and upper bound, count and leftmost and rightmost on top])

The duplicate-heavy test pins the payoff: count of a value is
upper minus lower, no scans. Both loops return `lo` when the target
is absent, which is exactly the insertion point, so "not found"
carries useful information instead of a bare -1.

#listing("dsa/samples-c/src/Ch14/bounds.c", first: 18, last: 45, caption: [c, the two half-open walks, count by subtraction])

#listing("dsa/samples-go/ch14/bounds.go", first: 8, last: 42, caption: [go, the same pair, insertion point as an alias])

#listing("dsa/samples-js/src/ch14-bounds.mjs", first: 5, last: 33, caption: [javascript, floor-mid walks, count and insertion point])

#listing("dsa/samples-py/src/Ch14/bounds.py", first: 13, last: 34, caption: [python, the half-open interval 0..len])

#listing("dsa/samples-lua/ch14_bounds.lua", first: 6, last: 23, caption: [lua, 1-based walk, answer shifted back to 0-based])

Measured across the suites: C, Lua, and Python share the fixture
1 3 3 3 5 7 and pin the run of 3s at lower 1, upper 4, count 3, the
absent 4 inserting at 4 and out-of-range keys at 0 and 6, C and Lua
sweeping every target against a linear partition check. Go runs the
same boundary story on 1 2 2 2 5 7, three copies of 2, and
JavaScript cross-checks both bounds against linear scans target by
target. The frozen C\# suite adds leftmost and rightmost on top of
the same subtraction. Every loop is the same half-open walk, one
comparison character apart.

#diagram([the boundary loops on one duplicate heavy array, lower is the first at least, upper the first greater, count is the difference], length: 13pt, {
  // 2 4 4 4 7 9 9 12 against t = 4: lower 1, upper 4, count 3; t = 8 absent: lo 5
  let vals = (2, 4, 4, 4, 7, 9, 9, 12)
  let strip = (y, hot) => {
    for (i, v) in vals.enumerate() {
      cdraw.rect((3.2 + i * 1.15, y - 0.45), (3.2 + (i + 1) * 1.15, y + 0.45), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((3.2 + i * 1.15 + 0.575, y), [#v], size: 6pt)
    }
  }
  cdraw.content((1.0, 6.7), [t = 4], size: 6pt)
  strip(6.7, (1, 2, 3))
  cdraw.line((4.35, 6.05), (4.35, 6.28), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.8, 6.05), (7.8, 6.28), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.35, 5.55), [lower], size: 6pt)
  cdraw.content((7.8, 5.55), [upper], size: 6pt)
  cdraw.line((4.35, 5.1), (7.8, 5.1), stroke: luma(100))
  cdraw.line((4.35, 5.1), (4.35, 4.95), stroke: luma(100))
  cdraw.line((7.8, 5.1), (7.8, 4.95), stroke: luma(100))
  cdraw.content((6.07, 4.55), [count = 3], size: 6pt)

  cdraw.content((1.0, 3.3), [t = 8], size: 6pt)
  strip(3.3, ())
  cdraw.line((8.95, 2.65), (8.95, 2.88), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.95, 2.15), [index 5], size: 6pt)

  cdraw.content((17.5, 7.45), [the loop, one character apart], size: 6.5pt)
  cdraw.content((17.5, 6.35), [lower: a[mid] < t], size: 6pt)
  cdraw.content((17.5, 5.25), [upper: a[mid] <= t], size: 6pt)
  cdraw.content((17.5, 4.15), [count = upper - lower], size: 6pt)
  cdraw.content((18.2, 3.05), [absent: lo is the insertion point], size: 6pt)
  cdraw.content((17.5, 1.95), [leftmost and rightmost come free], size: 6pt)
  cdraw.content((12.0, 0.7), [not found is not failure, the boundary is the answer], size: 6.5pt)
})

#callout("warning", "the three ways this loop goes wrong", [
  First, `mid = (lo + hi) / 2` overflows for large arrays in
  languages with fixed ints, hence the `lo + (hi - lo) / 2` form
  everywhere here. Second, terminating with `lo > hi` inside an
  equality test misses the boundary semantics. Third, off-by-one
  in the loop body's `<=` versus `<` is the difference between
  lower and upper bound, which is why both exist explicitly.
])

== rotated arrays

A sorted array rotated at an unknown pivot still has one sorted half
at every step, and knowing which half the target belongs to keeps
the search logarithmic.

The dry run: the fixture is 5 7 9 1 3 3, the sorted 1 3 3 5 7 9
rotated by 3, asserted by the C\# suite, while the integer suites pin
the same rule on 4 5 6 7 0 1 2.

+ The hunt for 1 opens 0..5 and probes slot 2: a[2] = 9, and
  a[lo] <= a[mid] names the left half 5 7 9 sorted, with 1 outside
  it, so lo jumps to 3.
+ Slot 4 reads 3, the left half sorts again as 1 3, and this time 1
  sits inside it, so hi drops to 3.
+ Slot 3 reads 1, the hit at the pinned index.
+ The family around it: the duplicate 3 lands at 4 one probe later,
  the leading 5 lands at slot 0 two probes in, and the absent 42
  runs the interval empty for -1.
+ The unrotated 1 2 3 4 5 walks slots 2, 3, 4 to the 5 at index 4,
  rotation zero degenerating into the plain boundary walk above.

#diagram([the hunt for 1 as three probes, each naming the sorted half before the interval moves], length: 13pt, {
  let probes = (
    ([slot 2 = 9], [left half 5 7 9 sorted], [1 outside it, lo = 3]),
    ([slot 4 = 3], [left half 1 3 sorted], [1 inside it, hi = 3]),
    ([slot 3 = 1], [hit], [the pinned index]),
  )
  for (k, p) in probes.enumerate() {
    let x = 0.7 + k * 7.0
    cdraw.rect((x, 4.1), (x + 5.6, 5.5), fill: if k == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 2.8, 5.1), p.at(0), size: 6.5pt)
    cdraw.content((x + 2.8, 4.55), p.at(1), size: 6pt)
    cdraw.content((x + 2.8, 3.4), p.at(2), size: 6pt)
    if k < 2 { cdraw.line((x + 5.8, 4.8), (x + 6.8, 4.8), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((10.5, 2.2), [the array: 5 7 9 1 3 3], size: 6pt)
  cdraw.content((10.5, 1.3), [the duplicate 3 lands one probe later, at 4], size: 6pt)
  cdraw.content((10.5, 0.4), [one probe always names the sorted half], size: 6pt)
})

The 3 for the 1 with the 4 one probe behind is the pinned pair, and
the listings below cover both halves in six languages.

#listing("dsa/samples-c/src/Ch14/rotated.c", first: 18, last: 42, caption: [c, which half is sorted, the target inside it or the other])

#listing("dsa/samples/src/Ch14/Searching.cs", first: 52, last: 76, caption: [c\#, the rotated walk, both halves covered])

#listing("dsa/samples-go/ch14/rotated.go", first: 6, last: 27, caption: [go, endpoint comparison picks the sorted half])

#listing("dsa/samples-js/src/ch14-rotated.mjs", first: 5, last: 23, caption: [javascript, the same rule, strict tests on both sides])

#listing("dsa/samples-py/src/Ch14/rotated.py", first: 12, last: 34, caption: [python, chained comparisons name the sorted half])

#listing("dsa/samples-lua/ch14_rotated.lua", first: 5, last: 28, caption: [lua, 1-based indices, answer shifted back])

Measured across the suites: C, Go, JavaScript, Lua, and Python all
pin indices on 4 5 6 7 0 1 2, every member at its slot, 0 at index
4, the absent 3, 8, and -1 refused, then sweep rotation zero,
rotated by one, rotated by four, and the single element. The frozen
C\# suite pins its own fixture under the same rule. The discipline
is one line everywhere: a[lo] <= a[mid] names the sorted half, and
the target either lies inside it or forces the other.

#diagram([the two logarithmic walks, the rotated array asks which half is sorted, the answer space binary searches a monotone predicate], length: 13pt, {
  // left: (4 5 6 7 1 2 3), t = 5, two probes; right: capacity 8..18, answer 9
  cdraw.content((5.9, 7.6), [the rotated walk], size: 6.5pt)
  let vals = (4, 5, 6, 7, 1, 2, 3)
  for (i, v) in vals.enumerate() {
    cdraw.rect((0.9 + i * 0.95, 6.05), (1.85 + i * 0.95, 6.95), fill: if i == 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((1.375 + i * 0.95, 6.5), [#v], size: 6pt)
  }
  cdraw.rect((0.9, 5.33), (7.55, 5.67), fill: luma(235), radius: 0.02)
  cdraw.circle((4.225, 5.5), radius: 0.09, fill: luma(100))
  cdraw.rect((0.9, 4.53), (3.75, 4.87), fill: luma(235), radius: 0.02)
  cdraw.circle((2.325, 4.7), radius: 0.09, fill: luma(100))
  cdraw.rect((1.85, 3.73), (2.8, 4.07), fill: luma(205), radius: 0.02)
  cdraw.content((5.9, 3.5), [probe 1: mid 7, left half sorted], size: 6pt)
  cdraw.content((5.9, 2.4), [5 sits in it: hi = mid - 1], size: 6pt)
  cdraw.content((5.9, 1.3), [probe 2: mid 5, hit], size: 6pt)
  cdraw.content((5.9, 0.2), [one half is always sorted], size: 6pt)

  // right: weights 1 8 2 4 3 in 3 days, feasible from capacity 9 on
  cdraw.content((18.0, 7.6), [the answer space], size: 6.5pt)
  let cx = c => 13.4 + (c - 8) * 0.92
  cdraw.content((18.0, 6.5), [weights 1 8 2 4 3, deadline 3 days], size: 6pt)
  cdraw.content((12.75, 5.6), [8], size: 6pt)
  cdraw.content((23.2, 5.6), [18], size: 6pt)
  cdraw.rect((cx(8), 5.43), (cx(18), 5.77), fill: luma(235), radius: 0.02)
  cdraw.circle((cx(13), 5.6), radius: 0.09, fill: luma(100))
  cdraw.rect((cx(8), 4.63), (cx(13), 4.97), fill: luma(235), radius: 0.02)
  cdraw.circle((cx(10), 4.8), radius: 0.09, fill: luma(100))
  cdraw.rect((cx(8), 3.83), (cx(10), 4.17), fill: luma(235), radius: 0.02)
  cdraw.circle((cx(9), 4.0), radius: 0.09, fill: luma(100))
  cdraw.rect((cx(8), 3.03), (cx(9), 3.37), fill: luma(205), radius: 0.02)
  cdraw.content((16.3, 3.35), [lo = hi = 9], size: 6pt)
  cdraw.content((18.0, 2.2), [capacity 13: 2 days, hi = 13], size: 6pt)
  cdraw.content((18.0, 1.1), [10 then 9 fit: hi walks down], size: 6pt)
  cdraw.content((18.0, 0.0), [8 needs 4: lo = 9, done], size: 6pt)
})

== the answer space

The pattern that extends binary search beyond arrays: when a
predicate is monotone in some quantity, false then true as the
quantity grows, binary search finds the transition. The
package-shipping question asks for the minimum daily capacity that
finishes within a deadline. The answer is not in any array, it is a
number whose feasibility predicate is monotone.

The dry run: the C\# fixture is the weights 1 through 10 against a
5-day deadline, asserted at 15, and the integer suites carry the
chapter's cross-language anchor, 1 8 2 4 3 in 3 days landing 9.

+ The bracket opens at the heaviest package, lo = 10, and closes at
  the total, hi = 55, the one-day answer the suite pins beside it.
+ Probe 10 + (55 - 10) / 2 = 32: day one holds 1 through 7, the rest
  takes one more day, 2 days, feasible, hi = 32.
+ Probe 10 + (32 - 10) / 2 = 21: day one fills exactly on
  1 + 2 + 3 + 4 + 5 + 6 = 21, two more days finish, hi = 21.
+ Probe 10 + (21 - 10) / 2 = 15: the days pack 1 through 5, then 6
  and 7, then 8, 9, 10 alone, five days, exactly the deadline, and
  hi = 15.
+ Probes 12 and 14 both break on the same edge, 10 + 5 = 15 over
  either cap, and each needs a sixth day: lo walks 13 then 15 and the
  bisect closes on 15, the pinned answer.
+ The edges beside it: one day forces the full 55, ten days drop the
  answer to the heaviest package, 10.

#diagram([the feasible packing at capacity 15, five day bins with their loads, the probe walk that closed on it underneath], length: 13pt, {
  let days = (([1 2 3 4 5], [15]), ([6 7], [13]), ([8], [8]), ([9], [9]), ([10], [10]))
  for (i, d) in days.enumerate() {
    let x = 0.8 + i * 3.5
    cdraw.rect((x, 5.4), (x + 3.1, 6.9), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.55, 6.45), d.at(0), size: 6.5pt)
    cdraw.content((x + 1.55, 5.95), [#d.at(1)], size: 6pt)
    cdraw.content((x + 1.55, 5.05), [day #(i + 1)], size: 6pt)
  }
  cdraw.content((8.7, 4.2), [capacity 15: five days, exactly the deadline], size: 6pt)
  let probes = (
    ([32], [2 days], [hi = 32]),
    ([21], [3 days], [hi = 21]),
    ([15], [5 days], [hi = 15]),
    ([12], [6 days], [lo = 13]),
    ([14], [6 days], [lo = 15]),
  )
  for (k, p) in probes.enumerate() {
    let x = 0.8 + k * 4.4
    cdraw.rect((x, 1.5), (x + 3.8, 3.1), fill: if k == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.9, 2.65), [capacity #p.at(0)], size: 6pt)
    cdraw.content((x + 1.9, 2.2), [#p.at(1)], size: 6pt)
    cdraw.content((x + 1.9, 1.8), [#p.at(2)], size: 6pt)
    if k < 4 { cdraw.line((x + 3.95, 2.3), (x + 4.25, 2.3), stroke: luma(100), mark: (end: ">")) }
  }
})

The 15 as the first feasible capacity is the pinned landing, and the
listings below bisect the same predicate in six languages.

#listing("dsa/samples-c/src/Ch14/answerspace.c", first: 20, last: 47, caption: [c, the greedy day count, the feasibility test, the bisect])

#listing("dsa/samples/src/Ch14/Searching.cs", first: 79, last: 106, caption: [c\#, the bracket max-to-total, the bisect on feasibility])

#listing("dsa/samples-go/ch14/answerspace.go", first: 9, last: 41, caption: [go, days needed, min capacity over the bracket])

#listing("dsa/samples-js/src/ch14-answerspace.mjs", first: 9, last: 40, caption: [javascript, infinity marks an overflowing weight, the bisect])

#listing("dsa/samples-py/src/Ch14/answerspace.py", first: 16, last: 42, caption: [python, day counts pinned around the answer, the bisect])

#listing("dsa/samples-lua/ch14_answerspace.lua", first: 9, last: 35, caption: [lua, 1000 as the overflow sentinel, the bisect])

Measured across the suites: this is the chapter's cross-language
anchor, weights 1 8 2 4 3 in 3 days, and every language lands 9. The
day counts agree around it, 4 days at capacity 8 and 2 at 9, the
bracket opens at the heaviest single weight, 8, and closes at the
total, 18, and the monotonicity check, feasible once means feasible
forever, runs in suite after suite. Python adds the edges: 5 days
drops the answer to 8, one day forces the full 18.

#diagram([the answer space, a monotone predicate over capacities, false then true, bisection finds the transition], length: 13pt, {
  // the capacity band 8..18: 8 infeasible, 9 and up feasible
  let cx = c => 1.6 + (c - 8) * 1.7
  for c in range(11) {
    let cap = 8 + c
    let ok = cap >= 9
    cdraw.rect((cx(cap), 5.6), (cx(cap) + 1.55, 6.5), fill: if ok { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((cx(cap) + 0.78, 6.05), [#cap], size: 6pt)
  }
  cdraw.content((2.3, 5.1), [4 days], size: 6pt)
  cdraw.content((5.7, 5.1), [2 days], size: 6pt)
  cdraw.content((10.9, 7.15), [false at 8, true from 9 on], size: 6pt)

  // the bracket and the probes
  cdraw.line((cx(8), 4.3), (cx(18) + 1.55, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((cx(8) + 0.7, 3.8), [lo = heaviest = 8], size: 6pt)
  cdraw.content((cx(16), 3.8), [hi = total = 18], size: 6pt)
  let probes = ((13, 4.3), (10, 4.3), (9, 4.3))
  for pr in probes {
    cdraw.circle((cx(pr.at(0)) + 0.78, pr.at(1)), radius: 0.09, fill: luma(100))
  }
  cdraw.content((12.4, 2.6), [13: 2 days, hi = 13], size: 6pt)
  cdraw.content((12.4, 1.7), [10: 2 days, hi = 10], size: 6pt)
  cdraw.content((12.4, 0.8), [9: 2 days, hi = 9, done], size: 6pt)

  cdraw.content((20.8, 5.1), [bisect the predicate], size: 6pt)
  cdraw.content((20.6, 3.1), [not an array], size: 6pt)
  cdraw.content((20.6, 2.1), [false then true], size: 6pt)
  cdraw.content((20.6, 1.1), [the first true is the answer], size: 6pt)
})

== kadane's scan

The maximum subarray question is a search over spans, and the one-pass
answer keeps exactly two numbers: the best subarray sum ending at the
current index, extended or restarted, and the global best. If the
running sum plus the new element is worse than the element alone, the
old prefix was dead weight and the span restarts here, otherwise it
extends. The champion's start and end ride along, restarted and
advanced with the sums, so the winning span falls out of the same
pass.

The dry run: the fixture is -2, 1, -3, 4, -1, 2, 1, -5, 4, asserted
by every suite against a double-loop brute, the one fixture all six
share.

+ The scan seeds on -2, and the first arrival already restarts:
  -2 + 1 = -1 loses to the 1 alone, so the span reopens at index 1
  with best 1.
+ The -3 drags the ending sum to 1 - 3 = -2 without touching the
  best.
+ The 4 restarts again, -2 + 4 = 2 under the 4 alone, and the
  champion opens at index 3 with best 4.
+ Three extends follow, 4 - 1 = 3, 3 + 2 = 5, 5 + 1 = 6, the best
  steps up twice and the champion holds 3 through 6.
+ The tail only moves the ending sum, 6 - 5 = 1 then 1 + 4 = 5, and
  the answer lands (best, start, end) at (6, 3, 6), pinned.
+ The edges ride the same loop: -3, -1, -2 keeps -1 at index 1 with
  the empty-allowed 0, a single 5 is its own span, and 2, 3, 1 spans
  everything at 6.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*i*], [*decision*], [*ending here*], [*best*], [*champion*]),
  [1], [restart, -2 + 1 = -1], [1], [1], [1..1],
  [2], [extend, 1 - 3 = -2], [-2], [1], [1..1],
  [3], [restart, -2 + 4 = 2], [4], [4], [3..3],
  [4], [extend, 4 - 1 = 3], [3], [4], [3..3],
  [5], [extend, 3 + 2 = 5], [5], [5], [3..5],
  [6], [extend, 5 + 1 = 6], [6], [6], [3..6],
  [7], [extend, 6 - 5 = 1], [1], [6], [3..6],
  [8], [extend, 1 + 4 = 5], [5], [6], [3..6],
)

The 6 over 3 through 6 with the brute agreeing is the pinned
champion, and the listings below run the same scan in six languages.

#listing("dsa/samples-c/src/Ch14/kadane.c", first: 21, last: 38, caption: [c, the loop, restart beats extend, the champion span tracked])
#listing("dsa/samples/src/Ch14/Searching.cs", first: 116, last: 143, caption: [c\#, the same loop, the empty-allowed variant one max away])
#listing("dsa/samples-go/ch14/kadane.go", first: 6, last: 35, caption: [go, the scan and the empty-allowed wrapper])
#listing("dsa/samples-js/src/ch14-kadane.mjs", first: 6, last: 26, caption: [javascript, the whole scan, best, start, end out])
#listing("dsa/samples-py/src/Ch14/kadane.py", first: 15, last: 47, caption: [python, the scan, the brute oracle, the empty-allowed wrapper])
#listing("dsa/samples-lua/ch14_kadane.lua", first: 8, last: 23, caption: [lua, the same loop over 1-based indices])

The nonempty variant is the pinned one, the empty subarray scores
nothing, and the empty-allowed variant is the max of the best with 0,
stated rather than shipped twice. The classic fixture -2, 1, -3, 4,
-1, 2, 1, -5, 4 peaks at 6 over indices 3 through 6, and every suite
brute-checks the champion span with the double loop before pinning
it. All-negative input keeps the nonempty best, -1 at index 1 of -3,
-1, -2, and the empty-allowed variant reads 0. A single 5 is its own
span, and 2, 3, 1 spans everything at 6.

#diagram([the fixture as bars with the winning span shaded and the running best ending here drawn beneath], length: 13pt, {
  let a = (-2, 1, -3, 4, -1, 2, 1, -5, 4)
  let ending = (-2, 1, -2, 4, 3, 5, 6, 1, 5)
  for (i, v) in a.enumerate() {
    let x = 1.6 + i * 1.55
    let hot = i >= 3 and i <= 6
    let y0 = if v >= 0 { 5.2 - v * 0.55 } else { 5.2 }
    let y1 = if v >= 0 { 5.2 } else { 5.2 - v * 0.55 }
    cdraw.rect((x, y0), (x + 1.35, y1), fill: if hot { luma(215) } else { luma(238) }, radius: 0.02)
    cdraw.content((x + 0.67, if v >= 0 { y0 - 0.3 } else { y1 + 0.32 }), [#v], size: 6pt)
    // the running best ending here as a small marker column
    cdraw.circle((x + 0.67, 2.9 - ending.at(i) * 0.22), radius: 0.08, fill: luma(100))
  }
  cdraw.line((1.2, 2.9), (16.0, 2.9), stroke: (paint: luma(180), dash: "dashed"))
  cdraw.content((1.2, 2.35), [best ending here], size: 6pt)
  for (i, e) in ending.enumerate() {
    cdraw.content((1.6 + i * 1.55 + 0.67, 1.25), [#e], size: 5.5pt)
  }
  cdraw.content((8.0, 0.8), [the champion: 6 over indices 3..6], size: 6pt)
  cdraw.content((8.0, -0.1), [restart when the prefix drags, else extend], size: 6pt)
})

The application is general technique, the inner loop of every
best-interval question.

== mex

The minimal excluded value asks which non-negative integer a list
fails to contain, and the answer never exceeds the list length: n
values can cover at most n slots, so a seen array of n + 1 booleans
catches every candidate that could bind. One marking pass, negatives
skipped since they exclude nothing, and one first-false scan close
it in O(n) with no allocation beyond the array. The prefix form
answers the streaming question, mex of every prefix, with a marker
that only ever advances: mark each arrival, walk the marker past the
newly filled gap, record.

The dry run: the fixtures are the family the whole chapter pins,
0, 1, 2, 4, 5 with its neighbors, asserted by the C\# suite and
carried by the integer suites.

+ The anchor 0, 1, 2, 4, 5 allocates six slots, n + 1, and the
  marking pass fills five of them, every slot but 3.
+ The first-false scan steps over 0, 1, 2, all true, and stops on
  the hole: mex 3, pinned.
+ The neighbors move the hole: 0, 0, 1, 1 marks two slots and stops
  at 2, and 2, 0, 1 fills the first three for 3.
+ The negative -7 fails the bounds test and never marks, so -7, 0, 1
  reads 2, the same answer as 0, 1 alone.
+ The full house 0 through 5 fills all six slots and the scan runs
  off the end at 6, the k of 0 through k - 1, pinned at k = 6.
+ The streaming twin over 0, 2, 1, 0, 5 runs 1, 1, 3, 3, 3, the
  marker stepping to 1, stalling, then jumping to 3 on the third
  arrival, pinned.

#diagram([the flat walk, five arrivals darkening six slots, the first-false scan stopping on the hole], length: 13pt, {
  let marks = (0, 1, 2, 4, 5)
  for (k, v) in marks.enumerate() {
    let x = 0.8 + k * 4.4
    cdraw.content((x + 1.45, 6.9), [#v], size: 6.5pt)
    for s in range(6) {
      let on = s != 3 and s <= v
      cdraw.rect((x + s * 0.58, 5.5), (x + (s + 1) * 0.58, 6.3), fill: if s == v { luma(205) } else if on { luma(222) } else { luma(240) }, radius: 0.01)
    }
  }
  cdraw.content((0.8, 4.9), [the slot axis 0 through 5 under each frame, 3 stays empty], size: 6pt)
  for s in range(6) {
    let x = 0.8 + s * 0.58
    cdraw.rect((x, 3.1), (x + 0.58, 3.9), fill: if s == 3 { luma(248) } else if s < 3 { luma(222) } else { luma(240) }, stroke: if s == 3 { luma(100) }, radius: 0.01)
  }
  cdraw.line((1.1, 2.6), (2.55, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.8, 2.1), [the scan stops on 3], size: 6pt)
  cdraw.content((9.5, 4.0), [five marks, one hole], size: 6pt)
  cdraw.content((9.5, 3.1), [mex 3, pinned], size: 6pt)
  cdraw.content((9.5, 2.2), [negatives never mark], size: 6pt)
  cdraw.content((9.5, 1.3), [0 through 5 runs off the end at 6], size: 6pt)
})

The 3 beside the off-the-end 6 is the pinned pair, and the listings
below run both forms in six languages.

#listing("dsa/samples-c/src/Ch14/mex.c", first: 24, last: 46, caption: [c, the seen array and first-false scan, the prefix table below])
#listing("dsa/samples/src/Ch14/Searching.cs", first: 153, last: 181, caption: [c\#, both forms, the marker advancing inside the stream loop])
#listing("dsa/samples-go/ch14/mex.go", first: 7, last: 38, caption: [go, the scan, the prefix table over a presence map])
#listing("dsa/samples-js/src/ch14-mex.mjs", first: 7, last: 27, caption: [javascript, both forms, the set-backed prefix table])
#listing("dsa/samples-py/src/Ch14/mex.py", first: 15, last: 36, caption: [python, the seen scan, the prefix table with its moving marker])
#listing("dsa/samples-lua/ch14_mex.lua", first: 8, last: 31, caption: [lua, slot v + 1 holds value v, both forms])

The pinned family reads: mex of the empty list is 0, of 0 is 1, of 1,
2, 3 is 0, of 0, 1, 2, 4, 5 is 3, of 0, 0, 1, 1 is 2, of -7, 0, 1 is
2 with the negative skipped, and of 2, 0, 1 is 3. The prefix table of
0, 2, 1, 0, 5 runs 1, 1, 3, 3, 3, the marker stepping twice and
stalling. The edges: mex of 0 through k minus 1 is k itself, pinned
at k = 6, an empty stream has no prefixes, and negatives never move
the marker.

#diagram([the value axis 0 through 6 under the prefix fixture, seen slots darkening and the mex marker stepping], length: 13pt, {
  let steps = ((0, 1), (2, 1), (1, 3), (0, 3), (5, 3))
  // the stream written left to right, one column per arrival
  let stream = (0, 2, 1, 0, 5)
  for (i, v) in stream.enumerate() {
    let x = 1.8 + i * 2.6
    cdraw.content((x, 6.6), [#v], size: 7pt)
    cdraw.rect((x - 0.4, 6.2), (x + 0.4, 6.9), fill: none, stroke: luma(190), radius: 0.02)
  }
  // the value axis with the seen set growing per column
  for (i, (v, m)) in steps.enumerate() {
    let x = 1.8 + i * 2.6
    let seen = if i == 0 { (0,) } else if i == 1 { (0, 2) } else if i == 2 { (0, 1, 2) } else if i == 3 { (0, 1, 2) } else { (0, 1, 2, 5) }
    for s in range(7) {
      let dark = s in seen
      cdraw.rect((x - 1.1 + s * 0.33, 4.6), (x - 1.1 + (s + 1) * 0.33, 5.3), fill: if dark { luma(205) } else { luma(240) }, radius: 0.01)
    }
    // the mex marker above the first gap
    cdraw.circle((x - 1.1 + m * 0.33 + 0.165, 5.8), radius: 0.12, fill: luma(100))
    cdraw.content((x, 3.9), [mex #m], size: 6pt)
  }
  cdraw.content((7.0, 3.0), [0  1  2  3  4  5  6 under each column], size: 6pt)
  cdraw.content((7.0, 2.1), [seen slots darken, the marker only advances], size: 6pt)
  cdraw.content((7.0, 1.2), [negatives never move it], size: 6pt)
  cdraw.content((7.0, 0.3), [grundy numbers consume exactly this], size: 6pt)
})

The application is general technique, and the grundy numbers of
#xref-to("dsa", "games") are the named kin: a game position's value is
the mex of its options, computed by this scan.

== across the six languages

The build sizes count non-comment source lines over this chapter's
five featured files per language, the three search topics plus the
two scan extensions. The C\# suite packs all five topics into one
file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [319], [libc only], [overflow sentinels 1000 for days, the kadane brute rides along, checks share the file with main, 70 of them],
  [c\#], [153], [bcl only], [leftmost and rightmost ride the bounds, kadane and mex as static classes, 10 tests],
  [go], [143], [none], [insertion point as a named alias, degenerate rotations swept, the empty-allowed kadane wrapper, tests in separate files, 14 tests],
  [javascript], [113], [node stdlib], [Infinity marks an overflowing weight, floor midpoints, the two scans as small modules, 14 tests],
  [python], [224], [stdlib only], [chained comparisons in the rotated walk, the double-loop kadane oracle, 50 checks],
  [lua], [284], [lib.lua harness], [1-based walks shifted back to 0-based answers, slot v + 1 holds value v in mex, checks ride in the module, 18 of them],
)

sources: learn.microsoft.com, `Array.BinarySearch` documentation as
the boundary vocabulary reference, accessed 2026-09-08, and
cp-algorithms, "Search the subsegment with the maximum/minimum sum",
cp-algorithms.com/others/maximum_average_segment.html, and "MEX task
(Minimal Excluded element in an array)",
cp-algorithms.com/sequences/mex.html, both accessed 2026-09-20, cc
by-sa 4.0, our own words and code throughout. Sample behavior
verified by `make verify-csharp`, 10 tests in chapter 14 of the
samples suite. The six-language layer verifies the same way: 5 C
programs with 70 embedded checks under `make verify-c`, 14 Go tests,
14 `node --test` cases, 50 Python checks across 5 files, and 18 Lua
checks under `run.lua`.
