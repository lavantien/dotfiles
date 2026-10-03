// ch13, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 43 checks in kdd/samples/src/Ch13/id3.c or a banked provenance note:
// the fixture is the play-tennis table transcribed character for character
// from Mitchell, Machine Learning, McGraw-Hill 1997, Table 3.2 p. 59
// (dataset introduced by Quinlan 1986), and the entropy/gain pins reproduce
// Mitchell's ch 3 worked numbers to the printed precision. all pinned
// values are witnessed by kdd-contract-s3.md +
// playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= decision trees: id3

One sample carries the chapter: `id3.c` grows a decision tree on the
14-row play-tennis table and asserts 43 checks, entropy by entropy,
gain by gain, down to a byte-exact serialization of the finished tree.
The chapter makes 5 moves: the fixture and the impurity of its root,
the entropy of every attribute value's row set, information gain as
the split criterion, the recursion and the tree it produces, and the
tree's verdicts on rows it never saw. Every behavioral claim below is
one of the 43 checks of chapter 13's sample or the banked Mitchell
provenance. The same table returns in #xref-to("kdd", "cart") under a
different impurity measure, its tree becomes rules in
#xref-to("kdd", "rules"), and #xref-to("kdd", "pruning") cuts one back.

== the fourteen rows, and one impure root

The fixture is the play-tennis dataset Quinlan introduced in 1986,
transcribed character for character, all six columns lowercased, from
Mitchell's Table 3.2, page 59: 14 days, four categorical attributes
(outlook, temperature, humidity, wind), one class, 9 days that play
and 5 that do not. ID3, Quinlan's iterative dichotomizer, turns that
table into a tree by splitting on whichever attribute most reduces the
class impurity, here measured in bits, $H = -p log_2 p - (1 - p)
log_2 (1 - p)$ with $p$ the yes fraction.

The dry run: the census prints `class counts no=5 yes=9`, and the root
entropy line prints the whole derivation, `H(S) =
-(9/14)lg2(9/14)-(5/14)lg2(5/14) = 0.940285958670631`. That is 0.940
to the three decimals Mitchell prints in his chapter 3 walkthrough,
the first of the six worked numbers this chapter reproduces. The mass
fractions ride along in the print because they are the hand-checkable
part, 9\/14 and 5\/14, while the decimal is a `log2` of non-dyadic
fractions and is pinned at 1e-12.

#listing("kdd/samples/src/Ch13/id3.c", first: 44, last: 58,
  caption: [the 14 rows as value indices, Mitchell's table in scan order])

#listing("kdd/samples/src/Ch13/id3.c", first: 225, last: 228,
  caption: [root entropy, masses printed beside the pinned decimal])

#diagram([the binary entropy curve, the root's 9 of 14 sits near the peak], length: 13pt, {
  let px(p) = { 1.6 + p * 12.8 }
  let py(h) = { 0.9 + h * 5.2 }
  cdraw.line((1.3, 0.7), (15.2, 0.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.3, 0.7), (1.3, 6.3), stroke: luma(60), mark: (end: ">"))
  for p in (0.2, 0.4, 0.6, 0.8) {
    cdraw.line((px(p), 0.5), (px(p), 0.9), stroke: luma(100))
    cdraw.content((px(p), 0.15), [#p], size: 6pt)
  }
  let pts = ()
  for i in range(1, 50) {
    let p = i * 0.02
    let h = -(p * calc.ln(p) + (1 - p) * calc.ln(1 - p)) / calc.ln(2.0)
    pts.push((px(p), py(h)))
  }
  for i in range(pts.len() - 1) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(60))
  }
  let p9 = 9.0 / 14.0
  let h9 = -(p9 * calc.ln(p9) + (1 - p9) * calc.ln(1 - p9)) / calc.ln(2.0)
  cdraw.circle((px(p9), py(h9)), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.line((px(p9), py(h9)), (px(p9), 0.7), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((px(p9) + 0.2, 0.15), [9\/14], size: 6pt)
  cdraw.content((px(p9) + 1.8, py(h9) + 0.3), [H = 0.940], size: 6.5pt)
  cdraw.content((8.4, 6.6), [H(p), one bit at p = 1\/2, zero at both ends], size: 6pt)
})

#callout("note", "the decimals are pinned, the fractions are checked", [
  An entropy like 0.940285958670631 contains log2 of 9\/14, which no
  finite binary expansion holds, so the sample pins it at 1e-12 and
  prints the exact mass fractions, 9\/14 and 5\/14, on the same line.
  The clean cases assert harder: an empty class or a 50\/50 mix gives
  exactly 0 or exactly 1, both dyadic, both compared with `==`. The
  same two-tier discipline carried the OLS fractions of
  #xref-to("kdd", "regression").
])

== every branch has an entropy

Splitting the table on one attribute partitions the 14 rows into one
row set per value of that attribute, and each set carries its own
class mix and its own entropy. There are 10 such sets here, 3 for
outlook, 3 for temperature, 2 for humidity, 2 for wind, and the sample
counts and prices every one of them.

The dry run: outlook prints `split outlook=sunny: no=3 yes=2 (n=5)`,
`split outlook=overcast: no=0 yes=4 (n=4)`, `split outlook=rain:
no=2 yes=3 (n=5)`, and the entropies line up as `H(outlook=sunny)
masses yes,no 2/5,3/5 = 0.970950594454669`, `H(outlook=overcast)
masses yes,no 4/0 = 0.000000000000000`, sunny and rain tying at
0.970950594454669 because 2\/5 against 3\/5 is 3\/5 against 2\/5 worn
backwards. Temperature gives `H(temperature=hot) masses yes,no 2/4,2/4
= 1.000000000000000` and strong the same perfect confusion,
`H(wind=strong) masses yes,no 3/6,3/6 = 1.000000000000000`, both
asserted with `==`. The cheapest set in the table is
`H(humidity=normal) masses yes,no 6/7,1/7 = 0.591672778582327`.

#listing("kdd/samples/src/Ch13/id3.c", first: 61, last: 75,
  caption: [two-class entropy in bits, zero counts skipped])

#listing("kdd/samples/src/Ch13/id3.c", first: 254, last: 271,
  caption: [the ten pinned branch entropies, masses carried alongside])

#diagram([all ten branch sets, class mixes and entropies, overcast is free], length: 13pt, {
  let cell(x0, y0, name, mix, h) = {
    cdraw.rect((x0, y0), (x0 + 3.7, y0 + 1.3), fill: luma(246), radius: 0.02)
    cdraw.content((x0 + 1.85, y0 + 1.02), name, size: 6.5pt)
    cdraw.content((x0 + 1.85, y0 + 0.64), mix, size: 6pt)
    cdraw.content((x0 + 1.85, y0 + 0.26), h, size: 6pt)
  }
  cdraw.content((1.6, 8.45), [outlook], size: 6pt)
  cell(3.4, 7.3, [sunny], [2y 3n], [H 0.971])
  cell(7.5, 7.3, [overcast], [4y 0n], [H 0 exactly])
  cell(11.6, 7.3, [rain], [3y 2n], [H 0.971])
  cdraw.content((1.6, 6.85), [temperature], size: 6pt)
  cell(3.4, 5.7, [hot], [2y 2n], [H 1 exactly])
  cell(7.5, 5.7, [mild], [4y 2n], [H 0.918])
  cell(11.6, 5.7, [cool], [3y 1n], [H 0.811])
  cdraw.content((1.6, 5.25), [humidity], size: 6pt)
  cell(3.4, 4.1, [high], [3y 4n], [H 0.985])
  cell(7.5, 4.1, [normal], [6y 1n], [H 0.592])
  cdraw.content((1.6, 3.65), [wind], size: 6pt)
  cell(3.4, 2.5, [weak], [6y 2n], [H 0.811])
  cell(7.5, 2.5, [strong], [3y 3n], [H 1 exactly])
  cdraw.content((9.0, 1.2), [counts are yes against no, as the sample prints them], size: 6pt)
})

== information gain picks the root

Entropy alone does not rank attributes, because a partition into many
small sets could be mostly impure yet cheap on average. Information
gain weighs the children by size, Gain$(S, A) = H(S) - sum_v
(|S_v|\/|S|) H(S_v)$, summing only over values present, and ID3 splits
on the attribute with the largest gain.

The dry run: one line carries all four, `Gain(outlook)=0.246749819774439
Gain(temperature)=0.029222565658955 Gain(humidity)=0.151835501362342
Gain(wind)=0.048127030408270`. Hand-checked for outlook: 0.940 minus
$(5\/14) dot 0.971$ for sunny, zero for overcast, $(5\/14) dot 0.971$
for rain, leaves 0.247. The ranking check fires as "ch13 ranking
outlook > humidity > wind > temperature". These are four more of
Mitchell's worked numbers, 0.247, 0.152, 0.048, 0.029, and the outlook
root they elect is his.

#listing("kdd/samples/src/Ch13/id3.c", first: 84, last: 100,
  caption: [gain, parent entropy minus the size-weighted child entropies])

#listing("kdd/samples/src/Ch13/id3.c", first: 290, last: 306,
  caption: [the four root gains pinned and ranked in one check])

#diagram([the four root gains, outlook wins, temperature never helped], length: 13pt, {
  let h(v) = { 0.7 + v * 13.0 }
  let bars = (([outlook], 0.2467498, [0.247], 2.2), ([humidity], 0.1518355, [0.152], 6.4),
    ([wind], 0.0481270, [0.048], 10.6), ([temperature], 0.0292226, [0.029], 14.8))
  for b in bars {
    cdraw.rect((b.at(3), 0.7), (b.at(3) + 2.9, h(b.at(1))), fill: luma(238), radius: 0.02)
    cdraw.content((b.at(3) + 1.45, h(b.at(1)) + 0.4), b.at(0), size: 6.5pt)
    cdraw.content((b.at(3) + 1.45, 0.35), b.at(2), size: 6pt)
  }
  cdraw.content((9.6, 7.8), [Mitchell's printed values under each bar], size: 6pt)
})

== recursion, subtrees, and a byte-exact tree

The root chosen, the algorithm recurses into each row set with outlook
spent. Both impure children land at entropy 0.970950594454669, and
each elects a different second split. The finished tree is serialized
in a fixed grammar, attribute first, branches in the order each value
first appears scanning the whole table, leaves as `leaf:yes` or
`leaf:no`, so the string is byte-comparable across programs.

The dry run: under sunny, `Gain(humidity)=0.970950594454669` beats
temperature's 0.570950594454669 and wind's 0.019973094021975, and
humidity splits sunny perfectly. Under rain, wind gains
0.970950594454669 while temperature and humidity tie all the way down
at 0.019973094021975, the tie itself a check, "ch13 rain tie
temperature=humidity, wind wins". The recursion prints `id3 tree
outlook(sunny->humidity(high->leaf:no normal->leaf:yes)
overcast->leaf:yes rain->wind(weak->leaf:yes strong->leaf:no))`,
asserted by `strcmp`, then `leaves 5 max depth 2`. This is the tree
Mitchell's chapter 3 grows from the same table, in executable form.

#listing("kdd/samples/src/Ch13/id3.c", first: 109, last: 133,
  caption: [the recursion's fork, pure leaf, best attribute, header-order ties])

#listing("kdd/samples/src/Ch13/id3.c", first: 151, last: 169,
  caption: [grammar v1 serialization, branch order fixed by first appearance])

#diagram([the learned tree, five leaves, depth 2, gains at each split], length: 13pt, {
  let node(x0, y0, name, gain) = {
    cdraw.rect((x0, y0), (x0 + 3.0, y0 + 1.0), fill: luma(240), radius: 0.02)
    cdraw.content((x0 + 1.5, y0 + 0.68), name, size: 6.5pt)
    cdraw.content((x0 + 1.5, y0 + 0.28), gain, size: 6pt)
  }
  let leaf(x0, y0, cls) = {
    cdraw.rect((x0, y0), (x0 + 2.6, y0 + 0.6), fill: luma(248), radius: 0.02)
    cdraw.content((x0 + 1.3, y0 + 0.3), cls, size: 6pt)
  }
  node(7.4, 7.2, [outlook], [gain 0.247])
  node(1.4, 5.5, [humidity], [gain 0.971])
  leaf(7.6, 5.7, [leaf: yes])
  node(12.2, 5.5, [wind], [gain 0.971])
  leaf(0.2, 3.8, [leaf: no])
  leaf(3.2, 3.8, [leaf: yes])
  leaf(10.6, 3.8, [leaf: yes])
  leaf(13.8, 3.8, [leaf: no])
  cdraw.line((7.9, 7.2), (3.0, 6.5), stroke: luma(60))
  cdraw.content((4.9, 7.15), [sunny], size: 6pt)
  cdraw.line((8.9, 7.2), (8.9, 6.3), stroke: luma(60))
  cdraw.content((9.6, 6.75), [overcast], size: 6pt)
  cdraw.line((9.9, 7.2), (13.6, 6.5), stroke: luma(60))
  cdraw.content((12.0, 7.15), [rain], size: 6pt)
  cdraw.line((2.2, 5.5), (1.5, 4.4), stroke: luma(60))
  cdraw.content((0.9, 5.05), [high], size: 6pt)
  cdraw.line((3.6, 5.5), (4.5, 4.4), stroke: luma(60))
  cdraw.content((4.7, 5.05), [normal], size: 6pt)
  cdraw.line((13.0, 5.5), (11.9, 4.4), stroke: luma(60))
  cdraw.content((11.4, 5.05), [weak], size: 6pt)
  cdraw.line((14.4, 5.5), (15.1, 4.4), stroke: luma(60))
  cdraw.content((15.4, 5.05), [strong], size: 6pt)
  cdraw.content((8.0, 2.5), [5 leaves, max depth 2 with the root at depth 0], size: 6pt)
})

== the tree on rows it has never seen

A tree is judged by classification. Walking it is a per-node branch
lookup, and two constructed rows exercise paths the growth never
explicitly chose: their attribute values all exist in the table, but
the combinations do not.

The dry run: on the 14 training rows the tree scores
`training accuracy 14/14`, which is guaranteed for ID3 on categorical
data grown to purity and is still worth the check. The held-out line
prints `held-out rain/mild/high/weak -> yes; sunny/cool/high/weak ->
no`: the first row takes rain then wind weak then yes, the second
takes sunny then humidity high then no, temperature never consulted in
either. A row carrying a value absent at its node would return the
unclassifiable marker, the sample's -1, which is the multiway tree's
honest answer that it never saw that branch, and the reason
#xref-to("kdd", "binning") exists for continuous inputs and
#xref-to("kdd", "cart") for splits that do not need categories at all.

#listing("kdd/samples/src/Ch13/id3.c", first: 171, last: 186,
  caption: [the walker, branch lookup per node, -1 on an absent value])

#listing("kdd/samples/src/Ch13/id3.c", first: 385, last: 393,
  caption: [the two constructed rows and their verdicts])

#diagram([two held-out rows walked through the tree, two different paths], length: 13pt, {
  let step(x0, y, txt, hot) = {
    cdraw.rect((x0, y), (x0 + 2.9, y + 0.7),
      fill: if hot {luma(228)} else {luma(246)}, radius: 0.02)
    cdraw.content((x0 + 1.45, y + 0.35), txt, size: 6pt)
  }
  cdraw.content((1.0, 7.5), [rain, mild, high, weak], size: 6.5pt)
  step(1.0, 6.2, [outlook = rain], false)
  step(4.6, 6.2, [wind], false)
  step(8.2, 6.2, [weak], false)
  step(11.8, 6.2, [yes], true)
  cdraw.content((1.0, 4.6), [sunny, cool, high, weak], size: 6.5pt)
  step(1.0, 3.3, [outlook = sunny], false)
  step(4.6, 3.3, [humidity], false)
  step(8.2, 3.3, [high], false)
  step(11.8, 3.3, [no], true)
  for x in (3.9, 7.5, 11.1) {
    cdraw.line((x, 6.55), (x + 0.7, 6.55), stroke: luma(60), mark: (end: ">"))
    cdraw.line((x, 3.65), (x + 0.7, 3.65), stroke: luma(60), mark: (end: ">"))
  }
  cdraw.content((9.0, 1.9), [temperature decides neither row], size: 6pt)
})

#callout("pitfall", "training accuracy is a tautology, not a result", [
  A purity-grown multiway tree classifies its own training rows
  perfectly by construction, every leaf pure, so 14\/14 says the walk
  and the growth agree and nothing more. The two held-out rows are the
  first honest test in the chapter, two rows out of two, and the real
  machinery for that judgment, held-out sets, cross validation, and
  the error rates that come out of them, is
  #xref-to("kdd", "evaluation"). Overfitting gets its own fixture in
  #xref-to("kdd", "pruning").
])

sources: the play-tennis fixture, its 14 rows, and the six reproduced
worked numbers 0.940, 0.971, 0.247, 0.152, 0.048, 0.029 are from
Mitchell, Machine Learning, McGraw-Hill 1997, Table 3.2 p. 59 and the
chapter 3 walkthrough, the dataset introduced by Quinlan, "Induction
of Decision Trees", Machine Learning 1:81-106, 1986. All 43 pinned
values witnessed by kdd-contract-s3.md and
playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch13`, 43 checks in chapter
13 of the kdd suite.
