// ch14, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 40 checks in kdd/samples/src/Ch14/cart.c or a banked note of
// kdd-contract-s3.md (the multiway-for-comparability convention, the
// exact-rational gini arithmetic, the cross-file paren identity). fixture 1
// is the play-tennis table of Mitchell 1997 Table 3.2 p. 59 (provenance in
// ch13); fixture 2 is constructed on the sheet. all pinned values are
// witnessed by kdd-contract-s3.md + playground/kdd-matrix/gen_s3.py, run
// 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= decision trees: cart and continuous splits

One sample carries the chapter: `cart.c` regrows the tree of
#xref-to("kdd", "id3") under the gini impurity instead of entropy, then
leaves categoricals behind and searches continuous thresholds on an
8-row fixture, 40 checks in all, every gini value an exact rational
asserted by cross-multiplication. The chapter makes 4 moves: gini as
the impurity that needs no logarithm, the delta criterion and the
surprising byte-identical tree, midpoint thresholds on a continuous
axis, and why real CART is binary. Every behavioral claim below is one
of the 40 checks of chapter 14's sample or a named note of the contract
sheet.

== gini, impurity without logarithms

Gini impurity is the probability that two rows drawn with replacement
from a set disagree on class, $1 - sum_i p_i^2$, and for two classes
it simplifies to $2p(1 - p)$ with $p$ the yes fraction. Where entropy
needed `log2` and tolerance pins, gini over integer class counts is
the exact fraction $(n^2 - k_("yes")^2 - k_("no")^2)\/n^2$, reducible
with a gcd and comparable by cross-multiplication.

The dry run: the root prints `gini(S) 45/98 = 0.459183673469388`,
hand-derived as $1 - (9\/14)^2 - (5\/14)^2 = 1 - 81\/196 - 25\/196 =
90\/196 = 45\/98$. All ten attribute values follow, `gini(outlook=sunny)
12/25 = 0.480000000000000`, `gini(outlook=overcast) 0/1 =
0.000000000000000` because 4 yes against 0 no cannot disagree,
`gini(temperature=hot) 1/2 = 0.500000000000000` because 2 against 2
disagrees half the time, down to `gini(humidity=normal) 12/49 =
0.244897959183673`, the cheapest set in the table exactly as entropy
judged it. Ten checks, every one the string "ch14 per-value gini
exact".

#listing("kdd/samples/src/Ch14/cart.c", first: 101, last: 108,
  caption: [gini over class counts, an exact fraction, no logarithm])

#listing("kdd/samples/src/Ch14/cart.c", first: 221, last: 240,
  caption: [the ten per-value ginis, pinned as fractions and cross-multiplied])

#diagram([entropy and gini against the yes fraction, same shape, different peak], length: 13pt, {
  let px(p) = { 1.6 + p * 12.8 }
  let pyE(h) = { 0.9 + h * 5.2 }
  let pyG(h) = { 0.9 + h * 5.2 }
  cdraw.line((1.3, 0.7), (15.2, 0.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.3, 0.7), (1.3, 6.5), stroke: luma(60), mark: (end: ">"))
  let pe = ()
  let pg = ()
  for i in range(1, 50) {
    let p = i * 0.02
    let he = -(p * calc.ln(p) + (1 - p) * calc.ln(1 - p)) / calc.ln(2.0)
    pe.push((px(p), pyE(he)))
    pg.push((px(p), pyG(2.0 * p * (1 - p))))
  }
  for i in range(pe.len() - 1) {
    cdraw.line(pe.at(i), pe.at(i + 1), stroke: luma(60))
    cdraw.line(pg.at(i), pg.at(i + 1), stroke: luma(150))
  }
  cdraw.line((12.6, 5.5), (13.2, 5.5), stroke: luma(60))
  cdraw.content((14.6, 5.5), [entropy], size: 6pt)
  cdraw.line((12.6, 4.8), (13.2, 4.8), stroke: luma(150))
  cdraw.content((14.4, 4.8), [gini 2p(1-p)], size: 6pt)
  let p9 = 9.0 / 14.0
  let g9 = 2.0 * p9 * (1 - p9)
  cdraw.circle((px(p9), pyG(g9)), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(p9) + 0.1, pyG(g9) - 0.5), [45\/98 at 9\/14], size: 6pt)
  cdraw.content((8.2, 6.9), [both peak at p = 1\/2, entropy at 1 bit, gini at 1\/2], size: 6pt)
})

#callout("note", "same verdicts, cheaper arithmetic", [
  Entropy and gini order these ten branch sets identically, normal at
  0.592 bits and 12\/49 the cheapest, hot and strong the most confused,
  overcast free. That agreement is typical rather than guaranteed, the
  two functions are close cousins on $[0, 1]$, but the chapter never
  leans on it: every ordering here is its own check, and the tree below
  is compared byte for byte, not attribute by attribute.
])

== the delta criterion, and one tree twice

The split criterion swaps entropy for gini, Delta$(S, A) = "gini"(S) -
sum_v (|S_v|\/|S|) "gini"(S_v)$, the same size-weighted children minus
parent shape, now entirely in fractions. The fixture and the recursion
are the same as chapter 13's, so what falls out is a direct experiment:
does the yardstick change the tree?

The dry run: the root line prints `Delta(outlook)=57/490
Delta(temperature)=11/588 Delta(humidity)=9/98 Delta(wind)=3/98`,
outlook hand-derived as $45\/98 - (5\/14)(12\/25) - 0 - (5\/14)(12\/25)
= 45\/98 - 12\/35 = 57\/490$. The ranking check fires as "ch14 ranking
outlook > humidity > wind > temperature", the same string as id3's. The
subtrees agree too, `sunny gini 12/25: humidity 12/25 temperature 7/25
wind 1/75` and `rain gini 12/25: wind 12/25 temperature 1/75 humidity
1/75`. So the tree prints `cart tree outlook(sunny->humidity(high->leaf:no
normal->leaf:yes) overcast->leaf:yes rain->wind(weak->leaf:yes
strong->leaf:no))`, and check 26 is the payoff: "ch14 cart paren ==
id3 paren (cross-file identity)". Two programs written apart, two
impurity functions with different arithmetic, one byte-identical
string.

#listing("kdd/samples/src/Ch14/cart.c", first: 110, last: 126,
  caption: [the gini delta, parent minus size-weighted children, all fractions])

#listing("kdd/samples/src/Ch14/cart.c", first: 243, last: 256,
  caption: [the four root deltas pinned as fractions and ranked])

#listing("kdd/samples/src/Ch14/cart.c", first: 298, last: 313,
  caption: [the cart tree asserted twice, against its pin and against id3's])

#diagram([the four attributes under both yardsticks, the order does not move], length: 13pt, {
  let rows = (([outlook], [0.247], [57\/490]), ([humidity], [0.152], [9\/98]),
    ([wind], [0.048], [3\/98]), ([temperature], [0.029], [11\/588]))
  let scale = ((1.0, 1.0), (0.1518355 / 0.2467498, 9.0 / 98.0 / (57.0 / 490.0)),
    (0.0481270 / 0.2467498, 3.0 / 98.0 / (57.0 / 490.0)),
    (0.0292226 / 0.2467498, 11.0 / 588.0 / (57.0 / 490.0)))
  cdraw.content((4.6, 8.5), [entropy gains, ch13], size: 6pt)
  cdraw.content((12.6, 8.5), [gini deltas, this chapter], size: 6pt)
  for i in range(4) {
    let y = 6.9 - i * 1.5
    cdraw.content((1.4, y + 0.28), rows.at(i).at(0), size: 6.5pt)
    cdraw.rect((3.2, y), (3.2 + 5.4 * scale.at(i).at(0), y + 0.56), fill: luma(238), radius: 0.02)
    cdraw.content((3.2 + 5.4 * scale.at(i).at(0) + 0.3, y + 0.28), rows.at(i).at(1), size: 6pt)
    cdraw.rect((9.6, y), (9.6 + 5.4 * scale.at(i).at(1), y + 0.56), fill: luma(222), radius: 0.02)
    cdraw.content((9.6 + 5.4 * scale.at(i).at(1) + 0.3, y + 0.28), rows.at(i).at(2), size: 6pt)
  }
  cdraw.content((8.6, 0.7), [bars scaled to outlook within each yardstick], size: 6pt)
})

== midpoints on a continuous axis

Categorical attributes hand you their split values. A continuous x
does not, so CART sorts the values and proposes the midpoint between
every neighboring pair, left branch $x <= t$, and scores each by the
same delta. The fixture is 8 rows, x = 1, 2, 3, 6, 7, 9, 10, 15, with
classes a, a, a, b, b, b, b, a, the last row planted so no prefix is
pure all the way and the search must weigh.

The dry run: the parent prints `continuous parent gini 1/2`, classes
4 against 4. Seven candidates print, from `candidate x<=1.5: L a=1 b=0
R a=3 b=4 Delta 1/14 = 0.0714285714` to `candidate x<=12.5: L a=3 b=4
R a=1 b=0 Delta 1/14`. The winner is `candidate x<=4.5: L a=3 b=0
R a=1 b=4 Delta 3/10 = 0.3000000000`, hand-derived: left $\{1, 2, 3\}$
is all a, gini 0, right carries a = 1 against b = 4, gini 8\/25, so
delta $= 1\/2 - (3\/8) dot 0 - (5\/8)(8\/25) = 1\/2 - 1\/5 = 3\/10$.
The useless middle prints too, `candidate x<=9.5: L a=3 b=3 R a=1 b=1
Delta 0/1 = 0.0000000000`, both sides perfectly balanced and gini
blind to it, and the two tails tie at 1\/14, their own check, "ch14
candidates 1.5 and 12.5 tie at 1/14". The chosen line closes it,
`chosen x<=4.5 delta 3/10; second x<=2.5 delta 1/6`.

#listing("kdd/samples/src/Ch14/cart.c", first: 327, last: 347,
  caption: [one candidate per neighboring midpoint, counts, delta, and pin])

#listing("kdd/samples/src/Ch14/cart.c", first: 364, last: 382,
  caption: [the argmax split's branch counts, threshold, delta, and runner-up])

#diagram([the 8-row axis, 7 midpoint candidates, 4.5 wins with 3/10], length: 13pt, {
  let px(v) = { 1.6 + v * 0.92 }
  cdraw.line((1.2, 5.0), (16.4, 5.0), stroke: luma(60), mark: (end: ">"))
  for p in (4, 8, 12) {
    cdraw.line((px(p * 1.0), 4.8), (px(p * 1.0), 5.2), stroke: luma(100))
    cdraw.content((px(p * 1.0), 4.45), [#p], size: 6pt)
  }
  let pts = ((1, 0), (2, 0), (3, 0), (6, 1), (7, 1), (9, 1), (10, 1), (15, 0))
  for p in pts {
    cdraw.circle((px(p.at(0) * 1.0), 5.0), radius: 0.11,
      fill: if p.at(1) == 0 {luma(215)} else {luma(150)}, stroke: luma(60))
    cdraw.content((px(p.at(0) * 1.0), 5.55), [#p.at(0)], size: 6pt)
  }
  cdraw.circle((13.6, 6.7), radius: 0.1, fill: luma(215), stroke: luma(60))
  cdraw.content((14.5, 6.7), [class a], size: 6pt)
  cdraw.circle((13.6, 6.15), radius: 0.1, fill: luma(150), stroke: luma(60))
  cdraw.content((14.5, 6.15), [class b], size: 6pt)
  let cands = ((1.5, [1\/14]), (2.5, [1\/6]), (4.5, [3\/10]), (6.5, [1\/8]),
    (8.0, [1\/30]), (9.5, [0]), (12.5, [1\/14]))
  for c in cands {
    let hot = c.at(0) == 4.5
    cdraw.line((px(c.at(0)), 3.7), (px(c.at(0)), 4.2),
      stroke: if hot {luma(40)} else {luma(140)}, mark: (start: "|", end: "|"))
    cdraw.content((px(c.at(0)), 3.3), [#c.at(0)], size: 6pt)
    cdraw.content((px(c.at(0)), 2.7), c.at(1), size: 6pt)
    if hot {
      cdraw.rect((px(c.at(0)) - 0.75, 2.4), (px(c.at(0)) + 0.75, 3.55),
        stroke: luma(60), radius: 0.02)
      cdraw.content((px(c.at(0)), 1.85), [chosen], size: 6pt)
    }
  }
  cdraw.content((8.6, 0.9), [ticks are candidate midpoints, deltas underneath], size: 6pt)
})

== binary, the real cart

Everything above 3-valued outlook split three ways because the sheet
pinned the multiway convention to keep chapters 13 and 14 comparable on
one fixture. CART itself is binary everywhere: a numeric attribute
splits at a threshold, a k-valued categorical splits into a subset
against its complement, and a binary question never has an answer the
tree has not accounted for.

The dry run: the chosen split routes every real number, 4.5 sends
$\{1, 2, 3\}$ left and everything else right, and the branch census is
already pinned, left a = 3 against b = 0, right a = 1 against b = 4.
Contrast the categorical hole of chapter 13, where a row carrying an
unseen value returns the unclassifiable -1: an $x <= t$ test has no
unseen answer. The cost is search, a k-valued attribute offers
$2^(k - 1) - 1$ distinct subset splits, three for outlook, and a
continuous attribute offers one candidate per neighboring gap, the
seven the previous facet scored. #xref-to("kdd", "binning") buys the
same continuity by destroying it first, chopping x into categories;
the threshold keeps x whole. #xref-to("kdd", "rules") will read rules
off this tree, and #xref-to("kdd", "pruning") will ask whether any of
it should have been grown at all.

#listing("kdd/samples/src/Ch14/cart.c", first: 197, last: 206,
  caption: [the continuous fixture and the count-pair gini helper])

#listing("kdd/samples/src/Ch14/cart.c", first: 143, last: 158,
  caption: [the argmax over attributes, fraction comparison, header-order ties])

#diagram([binary encodings: three subset splits for outlook, one threshold for x], length: 13pt, {
  let row(y, q, lft, rgt) = {
    cdraw.rect((0.9, y), (5.6, y + 0.75), fill: luma(240), radius: 0.02)
    cdraw.content((3.25, y + 0.37), q, size: 6pt)
    cdraw.line((5.6, y + 0.45), (6.5, y + 0.6), stroke: luma(60), mark: (end: ">"))
    cdraw.line((5.6, y + 0.3), (6.5, y - 0.05), stroke: luma(60), mark: (end: ">"))
    cdraw.rect((6.6, y + 0.34), (10.0, y + 0.9), fill: luma(246), radius: 0.02)
    cdraw.content((8.3, y + 0.62), lft, size: 6pt)
    cdraw.rect((6.6, y - 0.3), (10.0, y + 0.26), fill: luma(246), radius: 0.02)
    cdraw.content((8.3, y - 0.02), rgt, size: 6pt)
  }
  row(7.2, [outlook in {sunny}], [sunny], [overcast, rain])
  row(5.4, [outlook in {overcast}], [overcast], [sunny, rain])
  row(3.6, [outlook in {rain}], [rain], [sunny, overcast])
  row(1.8, [x <= 4.5], [3 rows, all a], [1 a, 4 b])
  cdraw.content((12.0, 6.0), [a 3-valued attribute], size: 6pt)
  cdraw.content((12.0, 5.5), [has 3 subset splits], size: 6pt)
  cdraw.content((12.0, 2.2), [a continuous attribute], size: 6pt)
  cdraw.content((12.0, 1.7), [has one threshold per gap], size: 6pt)
})

#callout("pitfall", "the multiway tree has holes, the binary tree has none", [
  Chapter 13's walker returned -1 for a value absent at a node, and
  the fixture dodged it by construction. A threshold $x <= t$ cannot
  dodge, cannot miss: every real number answers yes or no. That
  robustness, not raw accuracy, is a large part of why production tree
  implementations descend from CART's binary discipline, and it is why
  this book's own pruning fixture of #xref-to("kdd", "pruning") grows
  multiway for pedagogy but evaluates on values the table contains.
])

sources: fixture 1 is the play-tennis table of Mitchell, Machine
Learning, McGraw-Hill 1997, Table 3.2 p. 59, provenance carried from
chapter 13 (dataset introduced by Quinlan 1986). The multiway gini
convention, the exact-rational arithmetic, the continuous fixture, and
the cross-file paren identity are kdd-contract-s3.md rows witnessed by
playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch14`, 40 checks in chapter
14 of the kdd suite.
