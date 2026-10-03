#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= classics part 2: dynamic programming and tries

Part 2 is the difficulty step up: the dp ladder in three
refinements, the trie as a paying structure rather than a trivia
answer, and the string manipulations that recur across loops. Go
and C\# both, tests first, under `make verify`.

== the ladder: recursion, memo, table [TDD]

"How many ways to climb n stairs taking 1 or 2 steps" is the
fibonacci in disguise, and the answer worth giving is the walk from
the naive recursion to the O(1)-space table, narrating each
refinement:

#listing("interview-repertoire/samples/ch06-go/ladder.go", first: 5, last: 44, caption: [the exponential recursion, the memoized recursion, the two-slot table])

#diagram([one recurrence, three costs: exponential, cached, two rolling slots], length: 13pt, {
  // x is n, y is work: the naive curve leaves the page, the refinements do not
  cdraw.line((2, 0.9), (13.6, 0.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2, 0.9), (2, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.2, 0.3), [n], size: 6pt)
  cdraw.content((2.7, 6.9), [calls], size: 6pt)
  let naive = ((2, 1.0), (4, 1.5), (6, 2.4), (8, 3.9), (10, 6.3))
  for i in range(naive.len() - 1) {
    cdraw.line(naive.at(i), naive.at(i + 1), stroke: luma(60))
  }
  cdraw.line((2, 1.0), (13, 4.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((9.0, 6.6), [naive: 2^n], size: 6pt)
  cdraw.content((8.0, 2.0), [memo: n calls], size: 6pt)
  cdraw.content((17.0, 5.8), [recursion: exponential], size: 6pt)
  cdraw.content((17.0, 4.7), [memo: linear, O(n) space], size: 6pt)
  cdraw.content((17.0, 3.6), [table: two slots, O(1)], size: 6pt)
  cdraw.content((17.0, 2.5), [nothing older is read again], size: 6pt)
})

The suite runs all three against the fibonacci prefix to 15 and
then hands n = 60 to the table only, where the naive version would
make trillions of calls. The priced variant,
`MinCostClimbingStairs`, is the same recurrence with a cost array
and a two-start choice, and its two fixtures are the standard ones.

The narration to give while writing the table version: `prev` and
`cur` hold the last two answers, the loop climbs from rung 2, and
the space dropped from O(n) to O(1) because nothing older is ever
read again. That last sentence is the dp understanding the
interviewer is actually checking.

== the trie earns its keep: autocomplete [TDD]

Chapter 3 built the trie as a structure. Here it carries an
application: a vocabulary that answers prefix queries with
suggestions in alphabetical order, up to a limit:

#listing("interview-repertoire/samples/ch06-go/autocomplete.go", first: 36, last: 68, caption: [suggest walks to the prefix node then enumerates in rune order])

#diagram([walk to the prefix node, enumerate in rune order, cap at the limit], length: 13pt, {
  // the query cells hang over the nodes they match, badges give the emit order
  let ball(x, y, t, word: false) = {
    cdraw.circle((x, y), radius: 0.34, fill: if word { luma(205) } else { luma(235) }, stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6.5pt)
  }
  let badge(x, y, n) = {
    cdraw.circle((x, y), radius: 0.26, fill: luma(245), stroke: luma(100))
    cdraw.content((x, y), [#n], size: 6pt)
  }
  cdraw.line((2.6, 4.5), (4.1, 4.5), stroke: luma(120))
  cdraw.line((4.9, 4.5), (6.4, 4.5), stroke: luma(120))
  cdraw.line((7.1, 4.5), (8.6, 4.5), stroke: luma(120))
  cdraw.line((9.9, 4.1), (11.4, 3.4), stroke: luma(120))
  cdraw.line((9.9, 4.9), (11.4, 5.6), stroke: luma(120))
  ball(2.0, 4.5, "")
  ball(4.5, 4.5, "c")
  ball(7.0, 4.5, "a")
  ball(9.5, 4.5, "r", word: true)
  ball(11.9, 3.4, "d", word: true)
  ball(11.9, 5.6, "e", word: true)
  badge(9.5, 5.5, 1)
  badge(12.9, 3.4, 2)
  badge(12.9, 5.6, 3)
  // the query cells above the matched path
  cdraw.content((4.5, 6.2), [c], size: 6.5pt)
  cdraw.content((7.0, 6.2), [a], size: 6.5pt)
  cdraw.content((9.5, 6.2), [r], size: 6.5pt)
  cdraw.content((7.0, 7.1), [the query: car, limit 3], size: 6.5pt)
  cdraw.line((4.5, 5.85), (4.5, 4.84), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((7.0, 5.85), (7.0, 4.84), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((9.5, 5.85), (9.5, 5.76), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((17.6, 4.6), [car, card, care], size: 6pt)
  cdraw.content((17.6, 3.5), [d before e: rune order], size: 6pt)
  cdraw.content((17.6, 2.4), [a miss returns nil], size: 6pt)
})

The deterministic output, alphabetical under a sorted rune walk,
is what lets the test assert `Suggest("car", 3)` equals exactly
`[car card care]` against a six word vocabulary. The miss case
returns nil, not an empty slice, and the test distinguishes them.

== string manipulation [TDD]

Run length encoding with counts always emitted, first unique
character in two passes, and anagram grouping by sorted signature:

#listing("interview-repertoire/samples/ch06-go/strings.go", first: 5, last: 27, caption: [run length encoding, counts always written])

#diagram([counts always emitted: singles grow, runs shrink], length: 13pt, {
  // two encodes side by side, the verdict under each
  let cells(x, y, items) = {
    for i in range(items.len()) {
      cdraw.rect((x + i * 0.8, y), (x + i * 0.8 + 0.8, y + 0.9), fill: luma(235), radius: 0.02)
      cdraw.content((x + i * 0.8 + 0.4, y + 0.45), items.at(i), size: 6.5pt)
    }
  }
  cdraw.content((1.0, 5.6), [abc], size: 6.5pt)
  cells(3.0, 5.3, ("a", "b", "c"))
  cdraw.line((5.9, 5.75), (8.1, 5.75), stroke: luma(100), mark: (end: ">"))
  cells(8.6, 5.3, ("a", "1", "b", "1", "c", "1"))
  cdraw.content((15.9, 5.75), [grows: 3 to 6], size: 6pt)
  cdraw.content((0.8, 2.9), [aaaaaaab], size: 6.5pt)
  cells(5.4, 2.6, ("a", "a", "a", "a", "a", "a", "a", "b"))
  cdraw.line((12.5, 3.05), (14.7, 3.05), stroke: luma(100), mark: (end: ">"))
  cells(15.2, 2.6, ("a", "7", "b", "1"))
  cdraw.content((21.1, 3.05), [shrinks: 8 to 4], size: 6pt)
  cdraw.content((12.0, 1.0), [the count is always written, the one-line guard is the follow-up], size: 6pt)
})

The honesty callout the tests encode: `Compress` always emits a
count, so a string of single letters grows, `abc` becomes `a1b1c1`.
The version that returns the original when the encoding would not
shrink is a one-line guard candidates offer as the follow-up, and
the fixture table pins the unguarded behavior first.

#listing("interview-repertoire/samples/ch06-go/strings.go", first: 29, last: 56, caption: [two-pass first unique, bucketed anagrams with deterministic ordering])

Grouped anagrams come back sorted inside and across buckets,
because a hash map's iteration order is not a contract, in go or
in C\#, and a test that depends on it is a flake in waiting. The
longest common prefix by column scan rounds out the set, and the
C\# twin runs the same fixtures with `StringBuilder` and
`SortedDictionary` spelling.

sources: verified by `go test` and `dotnet test` through `make
verify`, 10 Go tests and 13 C\# tests, chapter ids `ch06-go` and
`ch06-cs`. The dp family's wider ladder floors to
#xref-to("dsa", "analysis") neighbors on dynamic programming.
