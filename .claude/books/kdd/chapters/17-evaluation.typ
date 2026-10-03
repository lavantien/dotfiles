// ch17, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 28 checks in kdd/samples/src/Ch17/metrics.c (9) and resample.c (19)
// or a pinned note of kdd-contract-s4s5.md: the metric definitions and the
// tie rules of its shared-machinery section. all pinned values are
// witnessed by the sheet + playground/kdd-matrix/gen_s4.py, run 2026-09-22,
// exit 0; the two D3 draw rows (holdout 8,5,4, bootstrap 2,9,0,1,0,1,4,3,4,5)
// are pinned by double-run identity, two consecutive generator runs.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= classifier evaluation

Two samples carry the chapter: `metrics.c` counts one confusion matrix off
10 pinned rows and derives its five ratios, 9 checks, and `resample.c`
spends the same rows three ways, holdout, 3-fold cross validation, and a
bootstrap with its out-of-bag fraction, 19 checks. The chapter makes 4
moves: the four cells and the five ratios read off them, one holdout split
driven by a pinned draw stream, three folds averaged into one number, and
the bootstrap's built-in holdout. Every behavioral claim below is one of
the 28 checks of chapter 17's samples or a pinned note of the contract
sheet. The procedures here measure whatever learner stands in front of
them, #xref-to("kdd", "bayes") and #xref-to("kdd", "knn") among them, the
score-shaped alternative to their single-threshold verdicts is
#xref-to("kdd", "roc"), and the ratio that breaks first on skewed classes
pays off in #xref-to("kdd", "imbalance").

== the confusion matrix and its five ratios

A classifier that outputs a hard label is right or wrong per row, and two
kinds of right and two kinds of wrong. Crossing truth against prediction
gives four cells: true positives TP, false negatives FN, false positives
FP, true negatives TN. The fixture pins both bit lists, truth 1,1,0,1,0,1,
1,0,0,1 against pred 1,0,0,1,0,1,0,1,0,0, ten rows, every cell reachable.
Row 0 is truth 1 predicted 1, a TP. Row 1 is truth 1 predicted 0, an FN,
the miss. Row 7 is truth 0 predicted 1, the FP, the false alarm. The
other seven rows fill the same three cells plus TN.

The dry run: the counting loop prints `confusion TP=3 FN=3 FP=1 TN=3`,
rows 0, 3, 5 landing TP, rows 1, 6, 9 landing FN, row 7 alone landing FP,
rows 2, 4, 8 landing TN. The ratio line prints unreduced,
`acc=6/10 prec=3/4 rec=3/6 f1=6/10 spec=3/4`, and the checks assert the
reduced forms by cross-multiplication, so "ch17 accuracy 3/5" compares
6/10 against 3/5 as integer products, 6 times 5 against 10 times 3.
Recall 1/2 is the loudest number on the fixture: the classifier finds
half the positives while accuracy says 3/5.

#listing("kdd/samples/src/Ch17/metrics.c", first: 33, last: 48,
  caption: [the four-cell count, one pass, ten rows])

#listing("kdd/samples/src/Ch17/metrics.c", first: 50, last: 58,
  caption: [the five ratios, reduced equality by cross-multiplication])

#diagram([the four cells with their rows, and the five ratios each cell pair buys], length: 13pt, {
  cdraw.content((9.9, 7.3), [pred +], size: 6.5pt)
  cdraw.content((12.7, 7.3), [pred -], size: 6.5pt)
  cdraw.content((7.2, 5.85), [truth +], size: 6.5pt)
  cdraw.content((7.2, 3.65), [truth -], size: 6.5pt)
  cdraw.rect((8.5, 4.8), (11.3, 6.7), fill: luma(238), radius: 0.02)
  cdraw.content((9.9, 6.05), [TP = 3], size: 7pt)
  cdraw.content((9.9, 5.3), [rows 0, 3, 5], size: 6pt)
  cdraw.rect((11.3, 4.8), (14.1, 6.7), fill: luma(246), radius: 0.02)
  cdraw.content((12.7, 6.05), [FN = 3], size: 7pt)
  cdraw.content((12.7, 5.3), [rows 1, 6, 9], size: 6pt)
  cdraw.rect((8.5, 2.9), (11.3, 4.8), fill: luma(246), radius: 0.02)
  cdraw.content((9.9, 4.15), [FP = 1], size: 7pt)
  cdraw.content((9.9, 3.4), [row 7], size: 6pt)
  cdraw.rect((11.3, 2.9), (14.1, 4.8), fill: luma(238), radius: 0.02)
  cdraw.content((12.7, 4.15), [TN = 3], size: 7pt)
  cdraw.content((12.7, 3.4), [rows 2, 4, 8], size: 6pt)
  cdraw.content((14.75, 5.75), [6], size: 6pt)
  cdraw.content((14.75, 3.55), [4], size: 6pt)
  cdraw.content((9.9, 2.45), [4], size: 6pt)
  cdraw.content((12.7, 2.45), [6], size: 6pt)
  let ratio(x, name, val) = {
    cdraw.rect((x, 0.5), (x + 3.0, 1.5), fill: luma(244), radius: 0.02)
    cdraw.content((x + 1.5, 1.15), name, size: 6pt)
    cdraw.content((x + 1.5, 0.78), val, size: 6.5pt)
  }
  ratio(0.8, [accuracy 6\/10], [3/5])
  ratio(4.05, [precision 3\/4], [TP over pred +])
  ratio(7.3, [recall 3\/6], [1/2])
  ratio(10.55, [F1 6\/10], [3/5])
  ratio(13.8, [specificity 3\/4], [TN over truth -])
})

#callout("pitfall", "accuracy is the ratio that hides the minority", [
  Accuracy 3/5 and recall 1/2 describe the same classifier on the same ten
  rows. Precision 3/4 says three of four predicted positives were real,
  recall 1/2 says half the real positives were found, and neither implies
  the other. F1 is their harmonic mean by exact algebra, $2 p r\/(p + r)
  = 2 "TP"\/(2 "TP" + "FP" + "FN")$, here $2 dot (3/4) dot (1\/2) = 3\/4$
  over $3\/4 + 1\/2 = 5\/4$, so 3/5, which the sample asserts directly
  from the cells. On a skewed class mix accuracy stops even being
  informative, and that failure is planted here for
  #xref-to("kdd", "imbalance") to harvest with its 99/100 fixture.
])

== holdout, three draws and a pinned stream

A holdout split carves test rows out of the training set, and to argue
about the split the draw stream has to be a fixture too. The sample uses
the wave's LCG, the numerical recipes recurrence $s' = 1664525 s +
1013904223 "mod" 2^32$ seeded 1017, drawing indices of 0..9 and keeping
first-seen indices until three distinct test rows exist, rejection
sampling exactly as the generator does. The seed is pinned, so the split
is a fact about the fixture, not a runtime accident.

The dry run: the stream is three draws long, `holdout draws: 8 5 4`, all
first-seen, so the test set is {4,5,8} and the check "ch17 holdout draws
8,5,4 (D3)" pins the stream itself. The train set prints `train: 0 1 2 3
6 7 9`, whose truth labels read 1,1,0,1,1,0,1, five ones of seven, so the
majority learner answers 1. Scoring it on the test rows prints `holdout
accuracy 1/3 (majority learner)`: rows 4, 5, 8 carry truth 0, 1, 0, the
learner predicts 1 everywhere, and only row 5 agrees.

#listing("kdd/samples/src/Ch17/resample.c", first: 29, last: 34,
  caption: [the wave LCG, verbatim shared machinery, seed set per row])

#listing("kdd/samples/src/Ch17/resample.c", first: 52, last: 70,
  caption: [rejection sampling until 3 distinct test rows, stream pinned])

#listing("kdd/samples/src/Ch17/resample.c", first: 87, last: 99,
  caption: [majority learner on the train fold, scored on the test rows])

#diagram([ten rows split by three pinned draws, the majority learner scores 1 of 3], length: 13pt, {
  cdraw.content((9.0, 8.2), [ten pinned rows, index above truth label, test rows dark], size: 6pt)
  let truth = (1, 1, 0, 1, 0, 1, 1, 0, 0, 1)
  for i in range(10) {
    let x = 0.9 + i * 1.62
    let hot = i == 4 or i == 5 or i == 8
    cdraw.rect((x, 5.6), (x + 1.45, 7.0),
      fill: if hot {luma(222)} else {luma(246)}, radius: 0.02)
    cdraw.content((x + 0.72, 6.55), [#i], size: 6.5pt)
    cdraw.content((x + 0.72, 5.95), [t=#{truth.at(i)}], size: 6pt)
    if hot {
      cdraw.content((x + 0.72, 7.3), [test], size: 6pt)
    }
  }
  cdraw.content((3.3, 4.35), [lcg seed 1017], size: 6pt)
  cdraw.content((3.3, 3.85), [3 draws, 3 distinct], size: 6pt)
  for i in (4, 5, 8) {
    let x = 0.9 + i * 1.62 + 0.72
    cdraw.content((x, 4.35), [drew #i], size: 6pt)
    cdraw.line((x, 4.7), (x, 5.5), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  }
  cdraw.rect((0.9, 2.2), (11.4, 3.1), fill: luma(246), radius: 0.02)
  cdraw.content((6.15, 2.75), [train 0,1,2,3,6,7,9 labels 1,1,0,1,1,0,1], size: 6pt)
  cdraw.content((6.15, 2.4), [majority learner predicts 1], size: 6pt)
  cdraw.rect((11.8, 2.2), (16.9, 3.1), fill: luma(232), radius: 0.02)
  cdraw.content((14.35, 2.75), [predicts 1 on rows 4,5,8], size: 6pt)
  cdraw.content((14.35, 2.4), [truth 0,1,0, right once], size: 6pt)
  cdraw.content((8.9, 1.4), [holdout accuracy 1/3], size: 6.5pt)
})

#callout("note", "the split is a fixture, so the score is a fact", [
  Both D3 rows of this chapter, the holdout stream 8,5,4 and the bootstrap
  indices below, were witnessed identical across two consecutive generator
  runs before being pinned. That is what lets the chapter print
  `holdout accuracy 1/3` as evidence rather than as one sample from a
  distribution. A holdout score on a random split is a random variable,
  and the variance of that variable across splits is exactly what the next
  facet averages away.
])

== three folds, one mean

Cross validation spends every row as test material exactly once. The CV
fixture is 12 labels, 1,1,1,1,1,1,1,0,0,1,1,0, dealt round-robin into
folds by row index modulo 3, fold 0 holding rows {0,3,6,9}, fold 1 rows
{1,4,7,10}, fold 2 rows {2,5,8,11}. Each round trains the same majority
learner on the other two folds, 8 rows, ties broken toward class 0, and
scores it on the held-out four.

The dry run: all three rounds print majority 1, since each 8-row train
set holds five or more ones. The per-round lines read `fold0 rows
{0,3,6,9} majority=1 acc=4/4`, `fold1 rows {1,4,7,10} majority=1 acc=3/4`,
`fold2 rows {2,5,8,11} majority=1 acc=2/4`. Fold 0's rows are all ones,
fold 1 hides the one 0 at row 7, fold 2 carries both remaining zeros at
rows 8 and 11. The mean line prints `cv mean accuracy 9/12`, and the
closing check asserts it twice, as the fraction pair 3/4 and as the
double 0.75 compared with `==`, legitimate because every per-fold
accuracy is dyadic, 1, 3/4, 1/2, so the mean is a dyadic double too.

#listing("kdd/samples/src/Ch17/resample.c", first: 103, last: 119,
  caption: [round-robin folds, per-round majority learner and score])

#listing("kdd/samples/src/Ch17/resample.c", first: 129, last: 137,
  caption: [the mean as a fraction pair and as a dyadic double])

#diagram([three rounds, each fold tests once, mean 9/12 = 3/4], length: 13pt, {
  cdraw.content((8.3, 7.9), [cv labels rows 0..11: 1 1 1 1 1 1 1 0 0 1 1 0], size: 6pt)
  let accs = ([acc 4/4], [acc 3/4], [acc 2/4])
  for f in range(3) {
    let y = 6.0 - f * 1.6
    cdraw.content((1.7, y + 0.5), [round #f], size: 6pt)
    cdraw.content((1.7, y + 0.15), [fold #f tests], size: 6pt)
    for i in range(12) {
      let x = 4.0 + i * 0.98
      cdraw.rect((x, y), (x + 0.88, y + 0.7),
        fill: if calc.rem(i, 3) == f {luma(222)} else {luma(246)}, radius: 0.02)
      cdraw.content((x + 0.44, y + 0.35), [#i], size: 6pt)
    }
    cdraw.content((16.1, y + 0.5), [majority 1], size: 6pt)
    cdraw.content((16.1, y + 0.15), accs.at(f), size: 6pt)
  }
  cdraw.rect((4.0, 1.2), (13.0, 2.0), fill: luma(246), radius: 0.02)
  cdraw.content((8.5, 1.6), [mean (4 + 3 + 2)\/12 = 9\/12 = 3\/4], size: 6.5pt)
  cdraw.content((8.5, 0.55), [dyadic per fold, so the mean asserts as double == 0.75], size: 6pt)
})

== bootstrap and the out-of-bag third

The bootstrap trains on a replicate, n draws with replacement from the n
rows, so some rows appear twice or more and others never appear at all.
The never-drawn rows are out of bag, OOB, and they are a holdout the
bootstrap builds for free: the replica cannot have memorized a row it
never saw. The sample draws 10 indices from the same LCG seeded 2017 and
keeps every draw.

The dry run: the stream prints `bootstrap indices: 2 9 0 1 0 1 4 3 4 5`.
Rows 0, 1, and 4 are drawn twice each, rows 2, 3, 5, 9 once each, and
rows 6, 7, 8 never, so the unique count is 7, asserted as "ch17 bootstrap
unique 7" with the set itself checked as {0,1,2,3,4,5,9}. Ten draws miss
exactly 3 of 10 rows, and the closing check reads "ch17 bootstrap OOB
fraction 3/10". That 3 in 10 is no accident of the seed's neighborhood:
the chance one fixed row survives ten draws untouched is $(9\/10)^10 =
3486784401\/10^10 = 0.3487$, because $9^10 = 3486784401$ exactly, so
about a third of any large row set sits out of any one replicate, the
sequence whose limit is $1\/e$.

#listing("kdd/samples/src/Ch17/resample.c", first: 139, last: 152,
  caption: [ten draws with replacement, the stream pinned as one check])

#listing("kdd/samples/src/Ch17/resample.c", first: 153, last: 163,
  caption: [unique census and the out-of-bag fraction 3/10])

#diagram([ten draws over ten row slots, 7 unique, rows 6, 7, 8 never drawn], length: 13pt, {
  cdraw.content((8.9, 7.5), [lcg seed 2017, 10 draws with replacement, repeat draws dark], size: 6pt)
  let draws = (2, 9, 0, 1, 0, 1, 4, 3, 4, 5)
  for k in range(10) {
    let x = 0.9 + k * 1.62
    let dup = k == 4 or k == 5 or k == 8
    cdraw.rect((x, 5.9), (x + 1.45, 6.9),
      fill: if dup {luma(224)} else {luma(244)}, radius: 0.02)
    cdraw.content((x + 0.72, 6.4), [#{draws.at(k)}], size: 6.5pt)
  }
  for i in range(10) {
    let x = 0.9 + i * 1.62
    let oob = i == 6 or i == 7 or i == 8
    if oob {
      cdraw.rect((x, 2.9), (x + 1.45, 4.3), fill: luma(252), radius: 0.02,
        stroke: (paint: luma(170), dash: "dashed"))
      cdraw.content((x + 0.72, 3.6), [OOB], size: 6pt)
    } else {
      cdraw.rect((x, 2.9), (x + 1.45, 4.3), fill: luma(242), radius: 0.02)
      cdraw.content((x + 0.72, 3.95), [row #i], size: 6pt)
      let cnt = if i == 0 or i == 1 or i == 4 {[drawn 2x]} else {[drawn 1x]}
      cdraw.content((x + 0.72, 3.3), cnt, size: 6pt)
    }
  }
  cdraw.rect((3.2, 1.3), (14.6, 2.1), fill: luma(246), radius: 0.02)
  cdraw.content((8.9, 1.7), [7 unique rows train the replica, 3 of 10 sit out], size: 6.5pt)
  cdraw.content((8.9, 0.6), [OOB fraction 3/10, the bootstrap's free holdout], size: 6pt)
})

sources: all 28 pinned values, the metric definitions (accuracy
(TP+TN)/n, precision TP/(TP+FP), recall TP/(TP+FN), F1 2TP/(2TP+FP+FN),
specificity TN/(TN+FP)), the tie rules, and both D3 draw rows witnessed
by kdd-contract-s4s5.md and playground/kdd-matrix/gen_s4.py, run
2026-09-22, exit 0, the draw rows identical across two consecutive runs.
The OOB arithmetic $(9\/10)^10 = 0.3487$ is exact integer algebra,
$9^10 = 3486784401$, and the $1\/e$ limit of $(1 - 1\/n)^n$ is the
standard compound-interest identity. Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch17`, 9 + 19 checks in chapter 17 of the
kdd suite.
