#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= algorithm patterns: window, pointers, search, greedy, bits

The pattern questions are the mid-loop currency: recognize the
shape, write the loop, state the cost, move on. This chapter
drills six recurring shapes, the sliding window, the inward
pointer pair, binary search plain and rotated, two greedies with
one sentence proofs, the backtrack decision tree, and the xor and
popcount tricks, each written test first in the Go workspace
`samples/ch23-go`, 13 tests run under `make verify` and again
under `go test -race`. The cost vocabulary is floored by
#xref-to("dsa", "analysis").

== longest substring without repeating characters [TDD]

The sliding window earns its keep when the constraint is a run
property, here the longest span of distinct runes. The window
owns a left edge and a last-seen map, each rune admitted updates
both, and the edge jumps past a repeat only when the previous
copy still sits inside the window:

#listing("interview-repertoire/samples/ch23-go/window.go", first: 3, last: 23, caption: [one sweep, the last-seen map guards the left edge])

#diagram([the edge only ever moves right, a repeat outside the window cannot shrink it], length: 13pt, {
  // abcabcbb bracketed twice, the second a's old copy outside the window
  let letters = ("a", "b", "c", "a", "b", "c", "b", "b")
  for i in range(8) {
    cdraw.rect((2 + i * 1.1, 5.4), (3.1 + i * 1.1, 6.4), fill: luma(240), stroke: luma(210), radius: 0.0)
    cdraw.content((2.55 + i * 1.1, 5.9), letters.at(i), size: 6pt)
  }
  cdraw.rect((1.9, 5.3), (5.3, 6.5), stroke: luma(60), radius: 0.02)
  cdraw.content((3.6, 7.1), [abc, best 3], size: 6pt)
  cdraw.rect((2.9, 3.9), (6.4, 5.1), stroke: luma(60), radius: 0.02)
  for i in range(3) { cdraw.content((3.55 + i * 1.1, 4.5), letters.at(i + 1), size: 6pt) }
  cdraw.content((4.6, 3.3), [bca, the a at 0 is outside, the edge holds at 1], size: 6pt)
})

The trap the `abba` fixture pins: the second a's previous copy
lives at index 0, before the window the second b pushed to 1, so
an unconditional `left = j + 1` reports 3. The `j >= left` guard
refuses the jump, and the multibyte row `éaéö` holds the walk to
runes, the lesson #xref-to("repertoire", "classics1") teaches
with the reverser.

#callout("pitfall", "the window that resets to the start", [
  The failing variant restarts at the repeat's old index plus
  one without asking whether it sits behind the current edge,
  so `abba` reports 3. The fix is one comparison, `j >= left`.
])

== two pointers: sorted pair sum, in-place dedupe [TDD]

Sorted input buys direction. The pair sum walks one pointer from
each end, too small a sum moves the left pointer up, too large
moves the right pointer down, and each step discards a value
that provably belongs to no pair. The dedupe runs the same shape
in place, a read index scans, a write index trails, a value
moves forward only when it differs from the last written:

#listing("interview-repertoire/samples/ch23-go/pointers.go", first: 3, last: 23, caption: [the inward walk over ascending input, values returned, not indices])

#listing("interview-repertoire/samples/ch23-go/pointers.go", first: 25, last: 42, caption: [the write index only ever trails the read index])

The ch05 twin owns the index-returning two sum,
#xref-to("repertoire", "classics1"), this one answers the values
variant. The dedupe contract to state unprompted: the returned k
means the first k slots hold the uniques, the tail is stale but
legal.

== binary search and the rotated variant [TDD]

The plain loop keeps a half open interval, lo inclusive, hi
exclusive, so the empty slice and the not-found case fall out of
the loop without special handling. The midpoint is `lo` plus
half the distance, the spelling that cannot overflow:

#listing("interview-repertoire/samples/ch23-go/search.go", first: 3, last: 22, caption: [half open interval, overflow safe midpoint])

The rotated variant leans on one fact: around any midpoint at
least one of the two halves is sorted, and a sorted half answers
in two comparisons whether the target lives inside it:

#listing("interview-repertoire/samples/ch23-go/search.go", first: 24, last: 51, caption: [find the sorted half, ask it the two range questions])

#diagram([mid splits the rotation, the sorted half answers, the other half inherits], length: 13pt, {
  // the rotated row 4 5 6 7 0 1 2, mid at 7, the left half proven sorted
  let vals = (4, 5, 6, 7, 0, 1, 2)
  for i in range(7) {
    cdraw.rect((2 + i * 1.5, 4.6), (3.5 + i * 1.5, 5.6), fill: if i < 4 { luma(215) } else { luma(240) }, stroke: luma(210), radius: 0.0)
    cdraw.content((2.75 + i * 1.5, 5.1), str(vals.at(i)), size: 6pt)
  }
  cdraw.line((7.25, 4.3), (7.25, 3.7), stroke: luma(60))
  cdraw.content((7.25, 3.2), [mid], size: 6pt)
  cdraw.content((5.2, 6.3), [left half sorted, 4..7], size: 6pt)
  cdraw.content((13.4, 3.2), [inside it? go there, outside? the other half], size: 6pt)
})

The off-by-one that fails silently: `nums[lo] <= nums[mid]` must
take the equal case as left-sorted, a single element half is
sorted by definition, and dropping the equality breaks a two
element rotation like `[3 1]`. Say the invariant aloud, target
sits in the interval, one half around mid is sorted, both loops
stay O(log n) only while it holds. The suite drives the rotated
row, an unrotated row, absent targets, and the empty slice,
floored by #xref-to("dsa", "searching").

== greedy: jump game and interval scheduling [TDD]

A greedy answer lives or dies by its proof. The jump game's
proof is reach: sweep once, carry the farthest index reachable
so far, fail the moment the sweep passes it, since every index
behind the reach is reachable too. Interval scheduling's is
finish first: sort by end, take what starts at or after the
last taken end, the earliest finisher never costs a later slot:

#listing("interview-repertoire/samples/ch23-go/greedy.go", first: 8, last: 24, caption: [one sweep, the reach is the certificate])

#listing("interview-repertoire/samples/ch23-go/greedy.go", first: 26, last: 43, caption: [finish-first sort, take what fits, the clone keeps the caller's order])

#diagram([reach ratchets up and never revisits, finish first takes three and skips one], length: 13pt, {
  // top: hop arcs for 2 3 1 1 4, bottom: four intervals on a line, one skipped
  let xs = (2, 4.4, 6.8, 9.2, 11.6)
  for i in range(5) {
    cdraw.circle((xs.at(i), 4.4), radius: 0.24, fill: luma(235), stroke: luma(120))
    cdraw.content((xs.at(i), 3.5), str(i), size: 6pt)
  }
  cdraw.line((xs.at(0), 4.6), (xs.at(2), 5.6), (xs.at(2), 4.6), stroke: luma(60))
  cdraw.line((xs.at(1), 4.6), (xs.at(4), 6.4), (xs.at(4), 4.6), stroke: luma(60))
  cdraw.content((6.4, 7.0), [reach ratchets 2 then 4, done], size: 6pt)
  cdraw.line((2, 1.9), (13.5, 1.9), stroke: luma(120), mark: (end: ">"))
  let bar(x1, x2, on) = cdraw.line((x1, if on { 1.4 } else { 0.8 }), (x2, if on { 1.4 } else { 0.8}), stroke: (paint: if on { luma(60) } else { luma(170) }, thickness: 1.6pt))
  let ivs = ((2.0, 6.3, false), (3.4, 4.8, true), (4.8, 7.7, true), (9.1, 12.0, true))
  for v in ivs { bar(v.at(0), v.at(1), v.at(2)) }
  cdraw.content((7.0, -0.1), [2..3, 4..6, 7..9 taken, 1..4 overlaps, skipped], size: 6pt)
})

The zero fixture `[3 2 1 0 4]` is the one worth naming aloud:
every hop lands on the 0, the reach stops at 3, the last slot
sits at 4. The clone is a contract, the test asserts the
caller's slice keeps its order. The wider greedy canon, exchange
arguments included, is floored by #xref-to("dsa", "greedy").

== backtracking: subsets and permutations [TDD]

Backtracking is a decision tree with an undo button. The subsets
walk forks on skip or include at every element, the power set
falls out at the leaves, and the path is copied out at emission
so no emitted subset aliases the recursion's working slice. The
permutations walk picks an unused element at each depth, the
unmark and pop after each return is the backtrack itself:

#listing("interview-repertoire/samples/ch23-go/backtrack.go", first: 3, last: 24, caption: [skip or include, copy at the leaf])

#listing("interview-repertoire/samples/ch23-go/backtrack.go", first: 26, last: 57, caption: [pick, recurse, unmark and pop])

#diagram([two branches per element, the undo runs after each return], length: 13pt, {
  // the subsets tree for two elements, four leaves, one path per subset
  let node(x, y, t, leaf) = {
    cdraw.circle((x, y), radius: 0.3, fill: if leaf { luma(215) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), t, size: 6pt)
  }
  let nodes = ((2, 5, "", false), (6, 6.6, "", false), (6, 3.4, "[1]", false),
    (10.4, 7.6, "[]", true), (10.4, 5.9, "[2]", true), (10.4, 4.1, "[1]", true), (10.4, 2.4, "[1 2]", true))
  for n in nodes { node(n.at(0), n.at(1), n.at(2), n.at(3)) }
  let edges = (((2.3, 5), (5.7, 6.6)), ((2.3, 5), (5.7, 3.4)), ((6.3, 6.6), (10.1, 7.6)),
    ((6.3, 6.6), (10.1, 5.9)), ((6.3, 3.4), (10.1, 4.1)), ((6.3, 3.4), (10.1, 2.4)))
  for e in edges { cdraw.line(e.at(0), e.at(1), stroke: luma(120), mark: (end: ">")) }
  cdraw.content((3.9, 6.7), [skip 1], size: 6pt)
  cdraw.content((3.9, 2.9), [take 1], size: 6pt)
  cdraw.content((15.6, 7.6), [n elements, 2^n leaves], size: 6pt)
  cdraw.content((15.6, 6.5), [every return pops and unmarks], size: 6pt)
})

The count tests demand exactly 2^n subsets and n! orderings,
all distinct, empty input included, which kills a walk that
emits the empty set twice or drops it. Heap's single swap walk,
#xref-to("repertoire", "classics1"), is the cheaper generator
when order does not matter, the memoized cousin is the dp ladder
in #xref-to("repertoire", "classics2").

== bit manipulation: single number, counting bits [TDD]

Xor is its own inverse and commutative, so folding a slice
where every value appears twice except one cancels the pairs in
any order and leaves the loner, one pass, no map, negatives
included since two's complement xor is still bitwise. The
popcount ladder fills the table in one linear pass: count[i] is
the count of its parent i >> 1 plus the dropped last bit, so no
row loops over bits:

#listing("interview-repertoire/samples/ch23-go/bits.go", first: 3, last: 14, caption: [the xor fold, pairs cancel, the loner survives])

#listing("interview-repertoire/samples/ch23-go/bits.go", first: 16, last: 27, caption: [count[i] = count[i >> 1] + (i & 1), parent first])

#diagram([the ladder's row is its parent plus the bit it dropped], length: 13pt, {
  // bars for 0..8 of height popcount, arrows from 6 and 7 back to 3
  let h = (0, 1, 1, 2, 1, 2, 2, 3, 1)
  for i in range(9) {
    cdraw.rect((2 + i * 1.5, 3), (3.1 + i * 1.5, 3 + h.at(i) * 1.1), fill: luma(215), stroke: luma(180), radius: 0.0)
    cdraw.content((2.55 + i * 1.5, 2.4), str(i), size: 6pt)
  }
  cdraw.line((11.5, 5.5), (7.2, 6.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((13.0, 6.6), (7.4, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.3, 7.6), [6 = 110b reads 3 = 11b, dropped bit 0], size: 6pt)
  cdraw.content((9.3, 8.6), [7 = 111b reads 3 = 11b, dropped bit 1], size: 6pt)
})

The ladder test cross-checks every row against `math/bits`
`OnesCount` from 0 to 16, two implementations of one function so
neither can drift. The bit family, masks, clears, and the xor
swap's honest limits, is floored by #xref-to("dsa", "numtheory").

== sorting internals, which sort when [DRILL]

The spoken answer, three sentences. Go's `sort` and `slices`
packages run pdqsort, pattern defeating quicksort: it detects
adversarial inputs, falls to insertion sort on small runs and
heapsort when the recursion deepens, so average and worst case
both sit at O(n log n). Comparison sorting cannot beat n log n,
the decision tree has n! leaves and a log n! depth, so the
answer is the library unless the keys carry structure: counting
sort at O(n + k) and radix sort at O(n k) win when keys are
small or fixed width, bucketing by value or digit instead of
comparing. Mergesort stays the stability answer, Go's slice
sort is not stable, `slices.SortStableFunc` is.

The follow-up to expect: why not always radix. Because k grows
with the key width, a 64 bit key costs eight passes plus the
bucket array, and pdqsort wins on comparables until n is large
and the keys dense. The floor treatment is #xref-to("dsa",
"sorting"), and the Go surface to name, `slices.SortFunc` with
`cmp.Compare` as this chapter's greedy does, is catalogued by
#xref-to("icpc", "toolbox-go").

#diagram([the decision is structure first, comparisons only when the keys are opaque], length: 13pt, {
  // one row per family, three cells: name, cost, the honest when
  let cell(x, y, w, t, head: false) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: if head { luma(252) } else { luma(240) }, stroke: luma(210), radius: 0.0)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  let xs = (0, 5.2, 9.8)
  let ws = (5.2, 4.6, 13.6)
  cell(0, 6.4, 5.2, [family], head: true)
  cell(5.2, 6.4, 4.6, [cost], head: true)
  cell(9.8, 6.4, 13.6, [the honest when], head: true)
  let rows = (
    ([pdqsort, the stdlib], [n log n], [comparables, no adversarial input]),
    ([counting sort], [n + k], [small dense integer keys, k under log n]),
    ([radix sort], [n k], [fixed width keys, large n, keys dense]),
    ([stable mergesort], [n log n], [equal keys must keep input order]),
  )
  for r in range(rows.len()) { for c in range(3) { cell(xs.at(c), 5.3 - r * 1.1, ws.at(c), rows.at(r).at(c)) } }
})

sources: verified by `go vet`, `go test`, and `go test -race` in
`samples/ch23-go`, 13 Go tests green, workspace `ch23-go`.
