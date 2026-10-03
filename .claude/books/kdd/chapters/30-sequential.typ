// ch30, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 38 checks in kdd/samples/src/Ch30/sequential.c or a banked
// provenance note: fixture S (5 sequences over a,b,c,d, minsup 2) is
// purpose-built by the matrix stream so containment is hand-checkable,
// pinned in kdd-contract-s6.md and witnessed by
// playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0. determinism:
// all D0, integer counts and exact strings, no doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= sequential patterns

One sample carries the chapter: `sequential.c` runs the levelwise
sequence census on five small sequences, 38 checks. The chapter makes 4
moves: the shape change from itemsets to sequences, where an element is
a simultaneous itemset and order between elements is data, the
containment test that greedy-matches each pattern element into a
strictly later sequence element, the k=2 census whose twelve candidates
show order asymmetry in raw counts, and the maximal pair that survives,
one two-element shape and one one-element shape over the same items.
The levelwise skeleton is #xref-to("kdd", "apriori")'s, with the
antimonotone law carrying over to subsequences, and the border notion
is the one #xref-to("kdd", "maximal") drew on itemsets.

== elements, order, and the containment test

A sequence is an ordered list of elements, each element a set of items
bought together in one transaction: S1 is a then the pair b,c, S2 is
the pair a,b then c, and those are different sequences even though all
their items are the same letters. A pattern is contained in a sequence
when each pattern element, in order, sits inside a strictly later
sequence element than the one before it. One itemset chapter threw
order away entirely, two baskets were the same basket whenever their
items were, and this chapter reinstates it.

The dry run: the fixture prints as `S1:<{a}{b,c}>`, `S2:<{a,b}{c}>`,
`S3:<{a}{b}{d}>`, `S4:<{b}{c}>`, `S5:<{a,c}{b,c}>`, and the 1-sequence
census counts `1seq <{a}>:4`, `1seq <{b}>:5`, `1seq <{c}>:4`, `1seq
<{d}>:1`, d appearing only in S3 and pruned at 1 below minsup 2. The
canonical trap is already visible: <{a}{b}> asks for a basket with a
and a strictly later basket with b, so it lives in S1, S3 and S5 but
not in S2, whose a and b share one element. Containment is decided by
the greedy leftmost scan, and the greedy choice is safe by a one-line
exchange: matching a pattern element at the earliest sequence element
that fits can only leave more room, never less, for the pattern
elements after it.

#listing("kdd/samples/src/Ch30/sequential.c", first: 73, last: 91,
  caption: [greedy leftmost containment, one cursor over the sequence elements])

#listing("kdd/samples/src/Ch30/sequential.c", first: 136, last: 147,
  caption: [the 1-sequence census, d counted at 1 and pruned])

#diagram([the same two items, one order matches, the shared element does not], length: 13pt, {
  let elem = (x, y, lab, hot) => {
    cdraw.rect((x - 0.85, y - 0.5), (x + 0.85, y + 0.5),
      fill: if hot {luma(214)} else {luma(242)}, radius: 0.02)
    cdraw.content((x, y), lab, size: 6.5pt)
  }
  cdraw.content((4.3, 7.9), [pattern <{a}{b}> against S1], size: 6pt)
  cdraw.content((2.4, 6.9), [S1:], size: 6.5pt)
  elem(4.3, 6.9, [{a}], true)
  cdraw.content((5.6, 6.9), [then], size: 5.4pt)
  elem(7.0, 6.9, [{b,c}], true)
  cdraw.content((2.4, 5.7), [{a} fits 1,], size: 5.6pt)
  cdraw.content((2.4, 5.1), [{b} fits 2, later], size: 5.6pt)
  cdraw.content((4.3, 5.7), [match], size: 6.5pt)
  cdraw.content((12.0, 7.9), [the same pattern against S2], size: 6pt)
  cdraw.content((10.1, 6.9), [S2:], size: 6.5pt)
  elem(12.0, 6.9, [{a,b}], true)
  cdraw.content((13.3, 6.9), [then], size: 5.4pt)
  elem(14.7, 6.9, [{c}], false)
  cdraw.content((10.1, 5.7), [{a} fits 1, {b} must, be strictly later], size: 5.6pt)
  cdraw.content((12.0, 4.9), [element 2 holds only c: no match], size: 6pt)
  cdraw.content((8.6, 3.4), [sharing one element is not succession, the sequence records that a and b were bought together], size: 6pt)
})

#callout("note", "order is information the itemset chapters deleted", [
  As a basket, S2's first element is just the itemset {a,b}, and
  #xref-to("kdd", "apriori") would count it exactly like any other
  occurrence of a and b. As a sequence, {a,b} then c also says a and b
  happened before c, and it says nothing about a before b, because
  inside one element there is no order. The three chapters of the
  association part mined unordered sets, and everything this chapter
  adds comes from putting a clock between the braces.
])

== the k=2 census, twelve candidates

Two-item shapes over the surviving letters a, b, c: nine two-element
sequences <{x}{y}> in row-major order, then the three one-element
pairs, exactly the sheet's enumeration order, each counted by
containment over the five sequences.

The dry run: `2seq <{a}{a}>:0`, `2seq <{a}{b}>:3`, `2seq <{a}{c}>:3`,
`2seq <{b}{a}>:0`, `2seq <{b}{b}>:0`, `2seq <{b}{c}>:2`, `2seq
<{c}{a}>:0`, `2seq <{c}{b}>:1`, `2seq <{c}{c}>:1`, `2seq <{a,b}>:1`,
`2seq <{a,c}>:1`, `2seq <{b,c}>:2`. The matrix is visibly asymmetric:
a-then-b happens in 3 sequences and b-then-a in none, and c-then-b in
exactly one, S5, where c rides the first element and b the second. The
one-element pairs count co-occurrence inside a single transaction,
{a,b} only in S2, {a,c} only in S5, {b,c} in S1 and S5. Four of the
twelve clear minsup 2, <{a}{b}>, <{a}{c}>, <{b}{c}> and <{b,c}>,
joining the three singletons toward the frequent listing.

#listing("kdd/samples/src/Ch30/sequential.c", first: 149, last: 174,
  caption: [nine two-element candidates row-major, then the three one-element pairs])

#diagram([the 3x3 order grid plus the pairs, frequent cells shaded], length: 13pt, {
  let lab = ("a", "b", "c")
  for j in range(3) {
    cdraw.content((3.6 + j * 2.6, 7.3), [then #lab.at(j)], size: 5.8pt)
  }
  for i in range(3) {
    cdraw.content((1.7, 6.3 - i * 1.7), [#lab.at(i) first], size: 5.8pt)
  }
  let vals = ((0, 3, 3), (0, 0, 2), (0, 1, 1))
  for i in range(3) {
    for j in range(3) {
      let v = vals.at(i).at(j)
      cdraw.rect((2.5 + j * 2.6, 5.45 - i * 1.7), (4.7 + j * 2.6, 7.15 - i * 1.7),
        fill: if v >= 2 {luma(200)} else {luma(246)}, radius: 0.02)
      cdraw.content((3.6 + j * 2.6, 6.3 - i * 1.7), [#v], size: 6.5pt)
    }
  }
  let pairs = ((11.2, [{a,b}], 1), (13.4, [{a,c}], 1), (15.6, [{b,c}], 2))
  for p in pairs {
    cdraw.rect((p.at(0) - 0.95, 3.7), (p.at(0) + 0.95, 4.9),
      fill: if p.at(2) >= 2 {luma(200)} else {luma(246)}, radius: 0.02)
    cdraw.content((p.at(0), 4.55), p.at(1), size: 6.5pt)
    cdraw.content((p.at(0), 4.05), [#p.at(2)], size: 6.5pt)
  }
  cdraw.content((13.4, 5.7), [one-element pairs], size: 6pt)
  cdraw.content((13.4, 2.9), [order grid: 3 versus 0 for a-then-b against b-then-a], size: 5.8pt)
  cdraw.content((6.0, 0.7), [shaded cells clear minsup 2: <{a}{b}>, <{a}{c}>, <{b}{c}>, <{b,c}>], size: 6pt)
})

== eight frequent, two maximal

The enumeration tries every shape over a, b, c with one, two or three
elements, keeps what clears 2, and nothing with three elements
survives. Eight sequences do, and the maximal ones are those no other
frequent sequence contains.

The dry run: the listing prints `freq <{a}>:4`, `freq <{b}>:5`, `freq
<{c}>:4`, `freq <{b,c}>:2`, `freq <{a}{b}>:3`, `freq <{a}{c}>:3`,
`freq <{a}{b,c}>:2`, `freq <{b}{c}>:2`, in element-count order with
one-element shapes first, <{b,c}> sitting among them because it is one
element. The maximal pair prints as `maximal: <{a}{b,c}>:2;<{b}{c}>:2`.
The contrast the check pins by name is the part's cleanest sentence:
"ch30 <{b,c}> vs <{b}{c}>: same items, different shape, same count 2".
The one-element <{b,c}> embeds in <{a}{b,c}>, b and c sharing its
second element, so it cannot be maximal. The two-element <{b}{c}> does
not embed anywhere, no frequent sequence buys b and then c in separate
later transactions except S2 and S4, and it stands maximal at the same
count 2. The antimonotone law holds as on itemsets, every subsequence
of a frequent sequence is frequent, since deleting elements or items
from a witness leaves a witness, which is what makes the levelwise
skeleton legitimate here too.

#listing("kdd/samples/src/Ch30/sequential.c", first: 106, last: 121,
  caption: [shape enumeration by element count, keeping what clears minsup])

#listing("kdd/samples/src/Ch30/sequential.c", first: 195, last: 226,
  caption: [maximality by mutual containment over the frequent listing])

#diagram([the eight frequent sequences, containment edges up, maximal dark], length: 13pt, {
  let node = (x, y, lab, kind) => {
    let fill = if kind == 0 {luma(170)} else {luma(240)}
    cdraw.rect((x - 1.25, y - 0.45), (x + 1.25, y + 0.45), fill: fill, radius: 0.02)
    cdraw.content((x, y), lab, size: 5.5pt)
  }
  let up = (x1, y1, x2, y2) => {
    cdraw.line((x1, y1 - 0.45), (x2, y2 + 0.45), stroke: (paint: luma(160)))
  }
  cdraw.content((8.6, 8.1), [one element below, two above], size: 6pt)
  node(1.8, 2.0, [<{a}>:4], 1)
  node(6.0, 2.0, [<{b}>:5], 1)
  node(10.2, 2.0, [<{c}>:4], 1)
  node(14.4, 2.0, [<{b,c}>:2], 1)
  node(3.0, 5.4, [<{a}{b}>:3], 1)
  node(7.2, 5.4, [<{a}{c}>:3], 1)
  node(11.4, 5.4, [<{b}{c}>:2], 0)
  node(15.6, 5.4, [<{a}{b,c}>:2], 0)
  up(1.8, 2.0, 3.0, 5.4)
  up(1.8, 2.0, 7.2, 5.4)
  up(1.8, 2.0, 15.6, 5.4)
  up(6.0, 2.0, 3.0, 5.4)
  up(6.0, 2.0, 11.4, 5.4)
  up(6.0, 2.0, 15.6, 5.4)
  up(10.2, 2.0, 7.2, 5.4)
  up(10.2, 2.0, 11.4, 5.4)
  up(10.2, 2.0, 15.6, 5.4)
  up(14.4, 2.0, 15.6, 5.4)
  cdraw.content((8.6, 0.8), [maximal: <{a}{b,c}> and <{b}{c}>, one two-element shape, one one-element], size: 6pt)
})

== the match trace, greedily

The sample closes by tracing <{a}{b,c}>, the k=3 winner with three
items in two elements, through all five sequences, printing the
witness positions or the refusal.

The dry run: `S1:match 1,2`, `S2:no`, `S3:no`, `S4:no`, `S5:match 1,2`,
then `supp=2`. The two matches are clean: S1's first element is exactly
{a} and its second is exactly {b,c}, S5 hides a inside {a,c} and takes
{b,c} whole as the second element, both times the greedy cursor landing
on elements 1 and 2. The three refusals each fail for a different
reason worth reading off: S2 spends its first element on {a,b}, which
covers the pattern's {a}, but then no strictly later element contains
both b and c, its second element is only {c}, and the shared-element
trap from the first facet closes the door. S3 has a and then b but no
c at all, d being pruned and useless as a witness. S4 never buys a.
Two witnesses out of five, support 2, and the maximal listing keeps
<{a}{b,c}> as the deepest shape the fixture supports.

#listing("kdd/samples/src/Ch30/sequential.c", first: 252, last: 272,
  caption: [the trace loop, witness positions for matches, the plain refusal otherwise])

#diagram([five sequences, two witnesses, three different reasons to refuse], length: 13pt, {
  let row = (y, name, elems, note, hot) => {
    cdraw.content((1.1, y), name, size: 6.2pt)
    let x = 2.9
    for i in range(elems.len()) {
      cdraw.rect((x, y - 0.42), (x + 1.75, y + 0.42),
        fill: if hot and i < 2 {luma(214)} else {luma(244)}, radius: 0.02)
      cdraw.content((x + 0.87, y), elems.at(i), size: 6.2pt)
      if hot and i < 2 {
        cdraw.content((x + 0.87, y + 0.75), [#(i + 1)], size: 5.6pt)
      }
      x += 1.95
    }
    cdraw.content((10.4, y), note, size: 5.8pt)
  }
  cdraw.content((6.5, 8.1), [pattern <{a}{b,c}>, positions of the witness underlined], size: 6pt)
  row(6.9, [S1], ([{a}], [{b,c}]), [match 1,2], true)
  row(5.5, [S2], ([{a,b}], [{c}]), [after {a,b} covers {a}, nothing later holds b and c], false)
  row(4.1, [S3], ([{a}], [{b}], [{d}]), [no c anywhere], false)
  row(2.7, [S4], ([{b}], [{c}]), [no a at all], false)
  row(1.3, [S5], ([{a,c}], [{b,c}]), [match 1,2, a inside {a,c}], true)
  cdraw.content((6.5, 0.35), [supp=2, S1 and S5], size: 6pt)
})

sources: fixture S, the five sequence strings, the containment law and
its greedy spelling, the k=2 enumeration order, the eight-row frequent
listing, the maximal pair and the match trace are pinned by
kdd-contract-s6.md and witnessed by playground/kdd-matrix/gen_s6.py,
run 2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile
-File tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src
-Chapter Ch30`, 38 checks in chapter 30 of the kdd suite.
