// ch18, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 25 checks in kdd/samples/src/Ch18/roc.c (19) and degenerate.c (6) or
// a pinned note of kdd-contract-s4s5.md: the curve rules of its shared
// machinery (descending stable sort, predict + when score >= t, curve
// starts at (0,0), ties worth 0.5) and the documented 8/9-not-11/12 ruling.
// all pinned values are witnessed by the sheet + the hand derivation in
// it + playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0. every row
// is D4-eligible: ch47 replays this fixture in go.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= roc and auc

Two samples carry the chapter: `roc.c` sweeps six pinned scores through
every threshold and counts the curve and its area two independent ways,
19 checks, and `degenerate.c` runs the same six scores with both
degenerate labelings, 6 checks. The chapter makes 4 moves: the threshold
sweep that turns a ranked list into a staircase, the concordant-pair count
that prices the ranking, the trapezoid area that agrees with it, and the
two degenerate curves that break the concordance denominator. Every
behavioral claim below is one of the 25 checks of chapter 18's samples or
a pinned note of the contract sheet. A hard label has one operating
point, the confusion matrix of #xref-to("kdd", "evaluation"), and this
chapter is what happens when the classifier hands over a score instead,
every threshold at once. Moving along the curve to trade false positives
against false negatives on a skewed class mix is
#xref-to("kdd", "imbalance"), and every row here is D4-eligible, the
fixture replays in go in #xref-to("kdd", "bridge").

== one threshold per step, seven points

The fixture is six scores in pinned order, (0.875,+), (0.6875,-),
(0.75,+), (0.625,+), (0.25,-), (0.125,-), three positives P and three
negatives N, every score a dyadic double. The curve rules come from the
sheet: sort descending, stable so equal scores keep input order, predict
positive when score >= t, and start the curve at (0,0), the point nobody
predicted positive. Sweeping the threshold down through the sorted list
walks the curve one point per score, each positive a vertical step of
1\/3 in the true positive rate, each negative a horizontal step of 1\/3
in the false positive rate, and the walk cannot reverse because counters
only increase.

The dry run: the sample prints `P=3 N=3`, then seven point lines, `point
0 (0/3,0/3)` through `point 6 (3/3,3/3)`. Sorted descending the list
reads 0.875+, 0.75+, 0.6875-, 0.625+, 0.25-, 0.125-, so the two best
scores are positives and the curve climbs to (0,2/3) before moving right
at all: `point 1 (0/3,1/3)`, `point 2 (0/3,2/3)`. The 0.6875 negative
walks it to `point 3 (1/3,2/3)`, the 0.625 positive climbs to `point 4
(1/3,3/3)`, and the two remaining negatives march it along the top,
`point 5 (2/3,3/3)`, `point 6 (3/3,3/3)`. Fourteen checks pin the seven
points, an fpr and a tpr fraction each.

#listing("kdd/samples/src/Ch18/roc.c", first: 29, last: 31,
  caption: [six dyadic scores, pinned order, three of each class])

#listing("kdd/samples/src/Ch18/roc.c", first: 59, last: 72,
  caption: [the sweep, one curve point per score, counters only climb])

#listing("kdd/samples/src/Ch18/roc.c", first: 73, last: 82,
  caption: [the seven points checked against pinned thirds])

#diagram([the seven-point staircase on the unit square, each step named by the score that caused it], length: 13pt, {
  let px(v) = { 2.2 + v * 11.5 }
  let py(v) = { 0.9 + v * 5.6 }
  cdraw.line((1.9, 0.9), (14.3, 0.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.2, 0.6), (2.2, 6.8), stroke: luma(60), mark: (end: ">"))
  for t in ((0.0, [0]), (0.3333, [1\/3]), (0.6667, [2\/3]), (1.0, [1])) {
    cdraw.line((px(t.at(0)), 0.8), (px(t.at(0)), 1.0), stroke: luma(100))
    cdraw.content((px(t.at(0)), 0.45), t.at(1), size: 6pt)
    cdraw.line((2.1, py(t.at(0))), (2.3, py(t.at(0))), stroke: luma(100))
    cdraw.content((1.6, py(t.at(0))), t.at(1), size: 6pt)
  }
  cdraw.content((15.0, 0.9), [fpr], size: 6pt)
  cdraw.content((2.2, 7.15), [tpr], size: 6pt)
  cdraw.line((2.2, 0.9), (13.7, 6.5), stroke: (paint: luma(180), dash: "dashed"))
  cdraw.content((10.6, 3.55), [random, area 1\/2], size: 6pt)
  cdraw.line((2.2, 0.9), (2.2, 4.6333), stroke: 1.1pt + luma(40))
  cdraw.line((2.2, 4.6333), (6.0333, 4.6333), stroke: 1.1pt + luma(40))
  cdraw.line((6.0333, 4.6333), (6.0333, 6.5), stroke: 1.1pt + luma(40))
  cdraw.line((6.0333, 6.5), (13.7, 6.5), stroke: 1.1pt + luma(40))
  for p in ((0.0, 0.0), (0.0, 0.3333), (0.0, 0.6667), (0.3333, 0.6667),
            (0.3333, 1.0), (0.6667, 1.0), (1.0, 1.0)) {
    cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.09, fill: luma(40))
  }
  cdraw.content((3.0, 1.83), [0.875 +], size: 6pt)
  cdraw.content((3.0, 3.7), [0.75 +], size: 6pt)
  cdraw.content((4.12, 5.0), [0.6875 -], size: 6pt)
  cdraw.content((6.7, 5.56), [0.625 +], size: 6pt)
  cdraw.content((7.95, 6.05), [0.25 -], size: 6pt)
  cdraw.content((11.78, 6.05), [0.125 -], size: 6pt)
  cdraw.content((8.2, 2.6), [area under the staircase = 8\/9], size: 6.5pt)
  cdraw.rect((14.7, 1.2), (17.1, 6.8), fill: luma(248), radius: 0.02)
  cdraw.content((15.9, 7.15), [sorted desc], size: 6pt)
  let ladder = ((6.3, [0.875 +]), (5.5, [0.75 +]), (4.7, [0.6875 -]),
    (3.9, [0.625 +]), (3.1, [0.25 -]), (2.3, [0.125 -]))
  for e in ladder {
    cdraw.content((15.9, e.at(0)), e.at(1), size: 6pt)
  }
  cdraw.content((15.9, 1.6), [one step each], size: 6pt)
})

#callout("note", "the curve lives on ranks, not labels", [
  Nothing in the sweep reads a threshold anyone chose. The curve is a
  property of the sorted list alone, the positives' positions among the
  negatives, which is why the same figure serves any scorer that ranks,
  and why the area computed from it in the next facet will count pairs
  rather than integrate a distribution. This construction, the threshold
  sweep from a ranked list, is Fawcett's, and the staircase above is his
  ROC space with the scores written on the steps.
])

== eight of nine pairs

The area under that staircase has a second, distribution-free reading:
the concordance fraction. Count every positive-negative pair, 3 times 3
is 9 of them, call a pair concordant when the positive outscores the
negative, discordant when it does not, and worth 1\/2 on a tie. The
fraction of concordant weight is the AUC, the empirical probability that
a randomly drawn positive outscores a randomly drawn negative, the
Mann-Whitney statistic in ROC clothing.

The dry run: the positives are 0.875, 0.75, 0.625, the negatives
0.6875, 0.25, 0.125. The 0.875 beats all three negatives. The 0.75 beats
all three, 0.75 over 0.6875 included. The 0.625 beats 0.25 and 0.125 but
sits under the 0.6875, and that pair, positive 0.625 ranked below
negative 0.6875, is the fixture's single rank inversion. The count line
prints `concordant=8 discordant=1 ties=0`, and the check closes the
arithmetic as "ch18 AUC 8/9", the fraction asserted as the pair
$(2 dot 8 + 0, 2 dot 9)$ against $(8, 9)$.

#listing("kdd/samples/src/Ch18/roc.c", first: 84, last: 101,
  caption: [all nine cross-class pairs, ties worth half, AUC as a fraction])

#diagram([the 3x3 pair grid, eight wins and the one inversion], length: 13pt, {
  cdraw.content((8.8, 8.35), [every positive against every negative], size: 6pt)
  let cols = ((6.4, [- 0.6875]), (10.2, [- 0.25]), (14.0, [- 0.125]))
  for c in cols {
    cdraw.content((c.at(0), 7.6), c.at(1), size: 6pt)
  }
  let rows = ((6.0, [+ 0.875]), (4.2, [+ 0.75]), (2.4, [+ 0.625]))
  for r in rows {
    cdraw.content((3.2, r.at(0)), r.at(1), size: 6pt)
  }
  for r in rows {
    for c in cols {
      let loss = r.at(1) == [+ 0.625] and c.at(1) == [- 0.6875]
      cdraw.rect((c.at(0) - 1.7, r.at(0) - 0.75), (c.at(0) + 1.7, r.at(0) + 0.75),
        fill: if loss {luma(216)} else {luma(244)}, radius: 0.02)
      cdraw.content((c.at(0), r.at(0)), if loss {[loss]} else {[win]}, size: 6.5pt)
    }
  }
  cdraw.rect((5.6, 0.4), (14.8, 1.5), fill: luma(246), radius: 0.02)
  cdraw.content((10.2, 1.12), [the one inversion: + 0.625 sits under - 0.6875], size: 6pt)
  cdraw.content((10.2, 0.68), [AUC = (2 dot 8 + 0)\/(2 dot 9) = 8\/9], size: 6.5pt)
})

#callout("pitfall", "why this fixture says 8/9 and not 11/12", [
  AUC 11/12 needs 12 cross-class pairs, so 3 positives against 4
  negatives, 7 items, with exactly one discordant pair. The pinned
  fixture is 6 scores, 3 against 3, 9 pairs, and the same structure, one
  inversion, gives 8/9. The contract sheet documents the ruling so the
  fixture is not bent chasing a denominator it cannot have: at this size
  the honest numbers are 8, 1, 0, and 8/9, and those are what the checks
  pin.
])

== the area, by thirds

The geometric cross-check integrates the staircase directly with the
trapezoid rule over the same seven points. Three segments carry nonzero
width: from (0,2/3) to (1/3,2/3), width 1\/3 at height 2\/3, area 2\/9;
from (1/3,1) to (2/3,1) and from (2/3,1) to (1,1), each width 1\/3 at
height 1, area 1\/3 apiece. The vertical rises carry zero width and zero
area, so 2\/9 + 3\/9 + 3\/9 = 8\/9, the same number the pair count
produced.

The dry run: the print reads `trapezoid auc=0.888888888888889
|trap-8/9|=1.110e-16`, and the check bounds the gap at 1e-12 rather than
comparing with `==`. The widths are thirds, not dyadic, so no finite
binary double holds them exactly and the accumulated sum lands one or
two ulps off, the same two-tier discipline #xref-to("kdd", "evaluation")
used for its dyadic mean, here with the tolerance leg doing the work.

#listing("kdd/samples/src/Ch18/roc.c", first: 103, last: 111,
  caption: [trapezoid cross-check, thirds kept as doubles, bounded at 1e-12])

#diagram([the three nonzero trapezoids, 2/9 + 1/3 + 1/3 = 8/9], length: 13pt, {
  let px(v) = { 1.8 + v * 12.4 }
  let py(h) = { 0.9 + h * 5.4 }
  cdraw.line((1.5, 0.9), (14.5, 0.9), stroke: luma(60), mark: (end: ">"))
  for t in ((0.0, [0]), (0.3333, [1\/3]), (0.6667, [2\/3]), (1.0, [1])) {
    cdraw.line((px(t.at(0)), 0.8), (px(t.at(0)), 1.0), stroke: luma(100))
    cdraw.content((px(t.at(0)), 0.45), t.at(1), size: 6pt)
  }
  cdraw.content((8.0, 7.5), [2\/9 + 3\/9 + 3\/9 = 8\/9], size: 6.5pt)
  cdraw.rect((px(0.0), 0.9), (px(0.3333), py(0.6667)), fill: luma(240), radius: 0.01)
  cdraw.content((px(0.1667), 2.2), [area 2\/9], size: 6pt)
  cdraw.content((px(0.1667), 3.6), [height 2\/3], size: 6pt)
  cdraw.rect((px(0.3333), 0.9), (px(0.6667), py(1.0)), fill: luma(248), radius: 0.01)
  cdraw.content((px(0.5), 3.0), [area 1\/3], size: 6pt)
  cdraw.content((px(0.5), 4.4), [height 1], size: 6pt)
  cdraw.rect((px(0.6667), 0.9), (px(1.0), py(1.0)), fill: luma(248), radius: 0.01)
  cdraw.content((px(0.8333), 3.0), [area 1\/3], size: 6pt)
  cdraw.content((px(0.8333), 4.4), [height 1], size: 6pt)
  cdraw.line((px(0.0), 0.9), (px(0.0), py(0.6667)), stroke: luma(40))
  cdraw.line((px(0.0), py(0.6667)), (px(0.3333), py(0.6667)), stroke: luma(40))
  cdraw.line((px(0.3333), py(0.6667)), (px(0.3333), py(1.0)), stroke: luma(40))
  cdraw.line((px(0.3333), py(1.0)), (px(1.0), py(1.0)), stroke: luma(40))
  cdraw.content((8.0, 6.78), [the staircase roof over its own area], size: 6pt)
})

== two degenerate curves

Break the class balance and the two AUC readings come apart. Relabel all
six scores positive and the sweep climbs the left edge, fpr pinned at 0
because there is no negative to add, six vertical steps to (0,1) and the
closing corner (1,1), 8 points, trapezoid area exactly 1. Relabel all
six negative and the curve crawls the bottom edge to (1,0) before the
corner, 8 points, area exactly 0. Both labelings have P*N = 0, no
cross-class pair exists, so the concordant count has no denominator and
the sample says so in words.

The dry run: `all-positive: n_points=8 area=1.000000000000000
crossclass_pairs=0` then `auc undefined (no cross-class pairs)`, and
`all-negative: n_points=8 area=0.000000000000000 crossclass_pairs=0`
with the same undefined line. The areas are exact doubles, 1.0 and 0.0,
asserted with `==` because every term in those sums is dyadic, while the
concordance checks only pin the fact of the empty denominator, "ch18
all-positive concordance undefined P*N=0" and its all-negative twin. A
curve of area 1 with no defined AUC is not a contradiction, it is the
two definitions refusing to pretend a one-class world ranks anything.

#listing("kdd/samples/src/Ch18/degenerate.c", first: 39, last: 50,
  caption: [the degenerate sweep, denominator 1 where a class count is 0])

#listing("kdd/samples/src/Ch18/degenerate.c", first: 51, last: 64,
  caption: [exact areas, and concordance declared undefined in words])

#diagram([both degenerate curves on one unit square, hugging different edges], length: 13pt, {
  let px(v) = { 3.0 + v * 8.0 }
  let py(v) = { 0.9 + v * 5.4 }
  cdraw.line((2.7, 0.9), (11.7, 0.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.0, 0.6), (3.0, 6.7), stroke: luma(60), mark: (end: ">"))
  for t in ((0.3333, [1\/3]), (0.6667, [2\/3]), (1.0, [1])) {
    cdraw.content((px(t.at(0)), 0.45), t.at(1), size: 6pt)
    cdraw.content((2.4, py(t.at(0))), t.at(1), size: 6pt)
  }
  cdraw.line((px(0.0), py(0.0)), (px(0.0), py(1.0)), stroke: 1.1pt + luma(40))
  cdraw.line((px(0.0), py(1.0)), (px(1.0), py(1.0)), stroke: 1.1pt + luma(40))
  cdraw.line((px(0.0), py(0.0)), (px(1.0), py(0.0)),
    stroke: (thickness: 1.1pt, paint: luma(40), dash: "dashed"))
  cdraw.line((px(1.0), py(0.0)), (px(1.0), py(1.0)),
    stroke: (thickness: 1.1pt, paint: luma(40), dash: "dashed"))
  cdraw.circle((px(1.0), py(1.0)), radius: 0.09, fill: luma(40))
  cdraw.content((7.0, 5.75), [all-positive, up then across, area exactly 1], size: 6pt)
  cdraw.content((7.0, 1.55), [all-negative, across then up, area exactly 0], size: 6pt)
  cdraw.content((7.0, 3.5), [same six scores, all labels flipped, P*N = 0 both times], size: 6pt)
})

sources: the threshold-sweep construction of a ROC curve from a ranked
list and the AUC-as-ranking reading follow Tom Fawcett, "An introduction
to ROC analysis", Pattern Recognition Letters 27(8):861-874, 2006,
doi.org/10.1016/j.patrec.2005.10.010, accessed 2026-09-22. All 25 pinned
values, the curve rules, and the 8/9-not-11/12 ruling witnessed by
kdd-contract-s4s5.md, its hand derivation, and
playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch18`, 19 + 6 checks in chapter 18 of the
kdd suite.
