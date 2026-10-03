// ch24, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 41 checks in kdd/samples/src/Ch24/paradox.c (19) and resample.c
// (22) or a banked note of kdd-contract-s4s5.md (the 0/0 precision
// convention, the predict-plus-when-score-at-or-above-t rule, and the
// documented cost-row ruling: the generator pinned cost(0.5) as the FN
// term 20 with the omitted 1*4 FP term giving the full sum 24, and the
// move to 0.4 wins under both readings, exactly as the C header states).
// draws and kept sets are D3 pinned literals, counts and fractions D0.
// fixture A is built by a loop, not 100 literals. all pinned values are
// witnessed by the sheet + playground/kdd-matrix/gen_s5.py, run
// 2026-09-22, exit 0, both LCG streams double-run identical.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= class imbalance

Two samples carry the chapter: `paradox.c` builds a 100-row fixture
where predicting the majority class scores 99/100 and then prices the
threshold move that fixes it, 19 checks, and `resample.c` scores a
20-row fixture before and after both resamplings, 22 checks. The
chapter makes 4 moves: the metric that celebrates failure, the cost
ledger that argues back, duplication of the minority, and subtraction
from the majority. Every behavioral claim below is one of the 41 checks
of chapter 24's samples or a named convention of the contract sheet.
The metric definitions are the ones #xref-to("kdd", "evaluation") pinned
as exact fractions, the threshold sweep is the same predict-plus rule
#xref-to("kdd", "roc") swept, and the votes of #xref-to("kdd",
"ensembles") assumed errors matter equally, which is exactly what this
chapter's class mix denies.

== the paradox of 99 percent

Fixture A is 100 rows built by a loop: 1 positive with score 0.46, and
99 negatives, 4 at 0.7, 6 at 0.44, 89 at 0.1. The classifier under the
microscope ignores scores entirely and predicts negative for every row,
the majority class by construction. On a balanced set that would be a
joke; here it is the best-scoring constant predictor, and the metrics
split on whether it was any good.

The dry run: the confusion line prints `all-negative: TP=0 FP=0 FN=1
TN=99`, so accuracy is $99\/100$, the number the paradox is named for.
The rest of the ledger collapses: recall is $0\/1$, zero of one
detections, and precision hits the degenerate case, $"TP"\/("TP" + "FP")$ with
denominator zero. The sheet's convention, stated in-sample, is
precision 0 when the denominator is 0, and check "ch24 all-negative
precision 0 (0/0 convention)" pins it rather than letting the fraction
be undefined. F1 then reads $"2 TP"\/("2 TP" + "FP" + "FN") = 0\/1 = 0$, and
the closing check names the whole situation outright, "ch24 paradox:
99/100 accuracy with zero detections". The one number that looked like
excellence was the majority class echoing itself.

#listing("kdd/samples/src/Ch24/paradox.c", first: 35, last: 54,
  caption: [fixture A by loop: 1 positive at 0.46, negatives 4 x 0.7, 6 x 0.44, 89 x 0.1])

#listing("kdd/samples/src/Ch24/paradox.c", first: 80, last: 98,
  caption: [the all-negative classifier and the metric ledger it earns])

#diagram([fixture A's score landscape, and the classifier that ignores it], length: 13pt, {
  cdraw.content((8.75, 8.75), [fixture A: 100 rows, 1 positive], size: 6.5pt)
  let sx(s) = { 1.5 + s * 14.0 }
  cdraw.line((1.5, 6.0), (15.8, 6.0), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.5, 5.7), [0], size: 6pt)
  cdraw.content((sx(0.5), 5.7), [0.5], size: 6pt)
  cdraw.content((sx(1.0), 5.7), [1], size: 6pt)
  cdraw.rect((2.55, 6.05), (3.25, 7.95), fill: luma(215), radius: 0.02)
  cdraw.content((2.9, 8.25), [89 negatives, 0.1], size: 6pt)
  cdraw.rect((7.41, 6.05), (7.91, 6.85), fill: luma(215), radius: 0.02)
  cdraw.content((7.66, 7.15), [6 x 0.44], size: 6pt)
  cdraw.rect((11.05, 6.05), (11.55, 6.75), fill: luma(215), radius: 0.02)
  cdraw.content((11.3, 7.05), [4 x 0.7], size: 6pt)
  cdraw.circle((sx(0.46), 6.0), radius: 0.14, fill: luma(120), stroke: luma(60))
  cdraw.content((6.2, 5.5), [the only positive, 0.46], size: 6pt)
  cdraw.line((sx(0.46), 5.8), (sx(0.46), 4.78), stroke: (paint: luma(150), dash: "dashed"),
    mark: (end: ">"))
  cdraw.rect((1.5, 3.9), (15.8, 4.7), fill: luma(240), radius: 0.02)
  cdraw.content((8.65, 4.3), [the all-negative classifier: every row predicted negative], size: 6pt)
  cdraw.rect((1.5, 1.5), (15.8, 3.4), fill: luma(246), radius: 0.02)
  cdraw.content((8.65, 3.0), [what the confusion matrix says], size: 6.5pt)
  cdraw.content((8.65, 2.55), [TP=0 FP=0 FN=1 TN=99, accuracy 99/100], size: 6pt)
  cdraw.content((8.65, 2.15), [recall 0/1, precision 0 (0/0 convention), F1 0], size: 6pt)
  cdraw.content((8.65, 1.8), [99/100 accuracy with zero detections], size: 6pt)
})

#callout("note", "accuracy is a headcount", [
  Accuracy counts rows, and 99 of the 100 rows are negative, so the
  constant no-sayer was guaranteed 99/100 before seeing a single score.
  Any metric that sums over rows inherits the class mix, which is why
  the imbalance toolkit starts by reporting precision, recall, and F1
  separately, the way #xref-to("kdd", "evaluation") defined them. The
  0/0 convention does quiet work here too: without it, precision would
  be undefined and the degenerate classifier would escape the ledger
  through a syntax error rather than a zero.
])

== pricing a miss at 20 false alarms

The scores do exist, so the fix is a threshold with opinions. The rule
is the roc chapter's: predict positive when score $>=$ t. At $t = 0.5$
only the four 0.7 negatives cross, so the lone positive at 0.46 stays
unseen; at $t = 0.4$ the positive crosses along with all six 0.44
negatives. Both sweeps and their ledgers are pinned, and the argument
for moving is a cost model, false alarm at 1, missed positive at 20.

The dry run: `t=0.5: TP=0 FP=4 FN=1 TN=95` with accuracy 19/20,
precision 0, recall 0, F1 0, then `t=0.4: TP=1 FP=10 FN=0 TN=89` with
accuracy 9/10, precision 1/11, recall 1, F1 1/6. Accuracy falls from
19/20 to 9/10 and every other metric rises from zero, which is the
trade the paradox was hiding. The cost line prints `cost FP=1 FN=20:
cost(0.5)=20 (FN) +4 (FP) = 24; cost(0.4)=10`, and the sheet's
documented ruling lives in that line: the generator's row pinned the
FN term alone, cost(0.5) = 20, the full sum with the omitted
$1 times 4$ false-alarm term is 24, and 10 beats both readings, so
check "ch24 cost 10 beats both 20 and 24: move to 0.4 justified" closes
the move without picking a reading.

#listing("kdd/samples/src/Ch24/paradox.c", first: 56, last: 71,
  caption: [the threshold rule, one pass over the scores])

#listing("kdd/samples/src/Ch24/paradox.c", first: 100, last: 120,
  caption: [both sweeps pinned, the two confusions and their ledgers])

#listing("kdd/samples/src/Ch24/paradox.c", first: 122, last: 135,
  caption: [the cost ledger: FN term, FP term, and the verdict under both readings])

#diagram([the same scores at two thresholds, and the cost ledger that picks], length: 13pt, {
  cdraw.content((4.55, 7.75), [t = 0.5], size: 6.5pt)
  cdraw.content((12.95, 7.75), [t = 0.4], size: 6.5pt)
  cdraw.rect((0.8, 5.1), (8.3, 8.05), fill: luma(246), radius: 0.02)
  cdraw.rect((9.2, 5.1), (16.7, 8.05), fill: luma(246), radius: 0.02)
  cdraw.content((4.55, 7.3), [TP=0 FP=4 FN=1 TN=95], size: 6pt)
  cdraw.content((4.55, 6.9), [acc 19/20, prec 0, rec 0, F1 0], size: 6pt)
  cdraw.content((12.95, 7.3), [TP=1 FP=10 FN=0 TN=89], size: 6pt)
  cdraw.content((12.95, 6.9), [acc 9/10, prec 1/11, rec 1, F1 1/6], size: 6pt)
  let grp(cx, cy, top, bot, hot) = {
    cdraw.rect((cx - 0.8, cy - 0.42), (cx + 0.8, cy + 0.42),
      fill: if hot {luma(228)} else {luma(238)}, radius: 0.02)
    cdraw.content((cx, cy + 0.16), top, size: 5.5pt)
    cdraw.content((cx, cy - 0.18), bot, size: 6pt)
  }
  grp(2.0, 6.1, [4 x 0.7], [-> +], true)
  grp(3.8, 6.1, [1 x 0.46], [-> -], false)
  grp(5.6, 6.1, [6 x 0.44], [-> -], false)
  grp(7.4, 6.1, [89 x 0.1], [-> -], false)
  grp(10.4, 6.1, [4 x 0.7], [-> +], true)
  grp(12.2, 6.1, [1 x 0.46], [-> +], true)
  grp(14.0, 6.1, [6 x 0.44], [-> +], true)
  grp(15.8, 6.1, [89 x 0.1], [-> -], false)
  cdraw.line((8.35, 6.6), (9.15, 6.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((8.75, 7.0), [move], size: 6pt)
  cdraw.rect((0.8, 0.6), (16.7, 4.5), fill: luma(243), radius: 0.02)
  cdraw.content((8.75, 4.1), [cost with FP = 1, FN = 20], size: 6.5pt)
  cdraw.rect((2.7, 1.1), (3.9, 3.5), fill: luma(200), radius: 0.02)
  cdraw.content((4.35, 2.3), [FN term: 20 x 1], size: 6pt)
  cdraw.rect((2.7, 3.5), (3.9, 3.98), fill: luma(225), radius: 0.02)
  cdraw.content((4.35, 3.74), [FP term: 1 x 4], size: 6pt)
  cdraw.content((3.3, 0.85), [t = 0.5: 24], size: 6pt)
  cdraw.rect((7.7, 1.1), (8.9, 2.3), fill: luma(200), radius: 0.02)
  cdraw.content((9.35, 1.7), [FP term: 1 x 10, FN term 0], size: 6pt)
  cdraw.content((8.3, 0.85), [t = 0.4: 10], size: 6pt)
  cdraw.content((13.3, 2.5), [10 beats 20 (FN term alone)], size: 6pt)
  cdraw.content((13.3, 2.1), [and 24 (the full sum)], size: 6pt)
  cdraw.content((13.3, 1.7), [the move is justified either way], size: 6pt)
})

== the balanced set by duplication

Fixture B is 20 rows for the resampling work: positives rows 0 to 4
with scores 0.9, 0.8, 0.7, 0.4, 0.3, negatives row 5 at 0.6 and rows 6
to 19 at 0.2, threshold fixed at 0.5. The baseline first: three
positives clear the bar, two do not, and the 0.6 negative is the single
false alarm, `20-row t=0.5: TP=3 FN=2 FP=1 TN=14`, precision 3/4,
recall 3/5, F1 2/3, accuracy 17/20.

Oversampling duplicates the minority: seed 5024 draws 10 rows with
replacement from the five positives, and the print is `oversample
draws: 1 2 0 2 3 4 2 1 1 4`, a D3 pin covering all five rows, row 2 and
row 1 three times each. The balanced set is 15 negatives against 15
positives, the five originals plus ten copies, and the same threshold
rule on it prints `balanced 15 neg + 15 pos: TP=10 FN=5 FP=1 TN=14`:
the 7 drawn copies at 0.7 or above join the 3 original hits, the 3
drawn copies of 0.4 and 0.3 join the misses, and the negative side is
untouched, FP=1 TN=14. Precision rises to 10/11, recall to 2/3, F1 to
10/13, every one an exact fraction check.

#listing("kdd/samples/src/Ch24/resample.c", first: 51, last: 68,
  caption: [the 20-row baseline at t = 0.5, counts and fractions])

#listing("kdd/samples/src/Ch24/resample.c", first: 70, last: 99,
  caption: [seed 5024, ten replacement draws, the balanced-set ledger])

#diagram([fixture B on the score line, then ten drawn copies of the minority], length: 13pt, {
  cdraw.content((8.75, 8.4), [fixture B at t = 0.5: 5 positives, 15 negatives], size: 6.5pt)
  let sx(s) = { 1.5 + s * 13.5 }
  cdraw.line((1.5, 6.9), (15.8, 6.9), stroke: luma(60), mark: (end: ">"))
  for s in (0.7, 0.8, 0.9) {
    cdraw.circle((sx(s), 6.9), radius: 0.13, fill: luma(150), stroke: luma(60))
  }
  cdraw.content((sx(0.7), 7.35), [0.7 +], size: 5.5pt)
  cdraw.content((sx(0.8), 7.7), [0.8 +], size: 5.5pt)
  cdraw.content((sx(0.9), 7.35), [0.9 +], size: 5.5pt)
  cdraw.circle((sx(0.3), 6.9), radius: 0.13, fill: luma(225), stroke: luma(60))
  cdraw.circle((sx(0.4), 6.9), radius: 0.13, fill: luma(225), stroke: luma(60))
  cdraw.content((sx(0.3), 6.45), [0.3 +], size: 5.5pt)
  cdraw.content((sx(0.4), 6.1), [0.4 +], size: 5.5pt)
  cdraw.circle((sx(0.6), 6.9), radius: 0.13, fill: luma(255), stroke: luma(60))
  cdraw.content((10.15, 6.42), [0.6 -, the only FP], size: 5.5pt)
  cdraw.rect((3.75, 7.0), (4.65, 7.45), fill: luma(215), radius: 0.02)
  cdraw.content((4.2, 7.75), [14 x 0.2 -], size: 5.5pt)
  cdraw.line((sx(0.5), 5.85), (sx(0.5), 7.95), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((sx(0.5), 5.5), [t = 0.5], size: 6pt)
  cdraw.content((8.75, 4.85), [seed 5024: ten replacement draws from rows 0..4], size: 6.5pt)
  let draws = ((1, [0.8], true), (2, [0.7], true), (0, [0.9], true), (2, [0.7], true),
    (3, [0.4], false), (4, [0.3], false), (2, [0.7], true), (1, [0.8], true),
    (1, [0.8], true), (4, [0.3], false))
  for k in range(10) {
    let xs = 2.2 + k * 1.32
    let d = draws.at(k)
    cdraw.rect((xs - 0.5, 3.7), (xs + 0.5, 4.45),
      fill: if d.at(2) {luma(238)} else {luma(214)}, radius: 0.02)
    cdraw.content((xs, 4.2), [row #d.at(0)], size: 6pt)
    cdraw.content((xs, 3.9), d.at(1), size: 6pt)
  }
  cdraw.content((8.75, 3.3), [7 copies clear 0.5, 3 do not: TP 3 -> 10, FN 2 -> 5], size: 6pt)
  cdraw.rect((1.0, 0.6), (16.5, 2.9), fill: luma(243), radius: 0.02)
  cdraw.content((8.75, 2.5), [the same rule, baseline against balanced 15 + 15], size: 6.5pt)
  cdraw.content((4.0, 2.1), [metric], size: 6pt)
  cdraw.content((8.0, 2.1), [20 rows], size: 6pt)
  cdraw.content((12.5, 2.1), [15 + 15], size: 6pt)
  cdraw.content((4.0, 1.7), [precision], size: 6pt)
  cdraw.content((8.0, 1.7), [3/4], size: 6pt)
  cdraw.content((12.5, 1.7), [10/11], size: 6pt)
  cdraw.content((4.0, 1.3), [recall], size: 6pt)
  cdraw.content((8.0, 1.3), [3/5], size: 6pt)
  cdraw.content((12.5, 1.3), [2/3], size: 6pt)
  cdraw.content((4.0, 0.9), [F1], size: 6pt)
  cdraw.content((8.0, 0.9), [2/3], size: 6pt)
  cdraw.content((12.5, 0.9), [10/13], size: 6pt)
})

== the balanced set by subtraction

Undersampling shrinks the majority instead: seed 6024 draws by
rejection until 5 distinct rows of the negative 15 are seen, keeping
first-seen indices exactly as the generators do. The print is
`undersample kept: 6 7 11 15 16`, a D3 pin, and the sort into ascending
order is part of the pin. Row 5, the 0.6 false positive, is never drawn,
which the sample states outright, check "ch24 row 5 (the only 0.6 false
positive) excluded". The balanced set is 5 positives against those 5
negatives, all at 0.2, and the ledger prints `balanced 5 neg + 5 pos:
TP=3 FN=2 FP=0 TN=5`: precision 1, recall 3/5, F1 3/4, accuracy 4/5,
recall untouched because the positive side never moved.

Set against the oversample, the two resamplings trade differently:
duplication bought recall 2/3 at precision 10/11 with the false alarm
still present, subtraction bought precision 1 with recall back at 3/5
and the false alarm gone, F1 10/13 against 3/4, both above the baseline
2/3. Which trade to want is the cost question of the second facet
again, now answered by dataset surgery instead of a threshold.

#listing("kdd/samples/src/Ch24/resample.c", first: 101, last: 127,
  caption: [seed 6024, rejection until 5 distinct majority rows, ascending pin])

#listing("kdd/samples/src/Ch24/resample.c", first: 128, last: 138,
  caption: [the 5 + 5 ledger, precision 1 with recall untouched])

#diagram([the 15 majority rows, 5 kept by rejection, and the two resamplings compared], length: 13pt, {
  cdraw.content((8.75, 8.4), [the majority side: rows 5..19, one score each], size: 6.5pt)
  for k in range(15) {
    let row = 5 + k
    let xs = 1.7 + k * 1.05
    let hit = (row == 6 or row == 7 or row == 11 or row == 15 or row == 16)
    cdraw.rect((xs - 0.45, 6.9), (xs + 0.45, 7.6),
      fill: if row == 5 {luma(210)} else if hit {luma(235)} else {luma(246)},
      stroke: if hit {luma(60)} else {luma(190)}, radius: 0.02)
    cdraw.content((xs, 7.38), [row #row], size: 5.5pt)
    if row == 5 {
      cdraw.content((xs, 7.08), [0.6], size: 5.5pt)
    } else {
      cdraw.content((xs, 7.08), [0.2], size: 5.5pt)
    }
  }
  cdraw.content((4.0, 6.35), [ringed: kept 6, 7, 11, 15, 16], size: 6pt)
  cdraw.content((12.5, 6.35), [row 5, the 0.6 false positive, never drawn], size: 6pt)
  cdraw.rect((1.0, 3.4), (16.5, 5.6), fill: luma(246), radius: 0.02)
  cdraw.content((8.75, 5.2), [balanced 5 + 5 under the same rule], size: 6.5pt)
  cdraw.content((8.75, 4.75), [TP=3 FN=2 FP=0 TN=5], size: 6pt)
  cdraw.content((8.75, 4.35), [precision 1, recall 3/5, F1 3/4, accuracy 4/5], size: 6pt)
  cdraw.content((8.75, 3.95), [recall untouched: the positive side never changed], size: 6pt)
  cdraw.rect((1.0, 0.7), (16.5, 3.0), fill: luma(243), radius: 0.02)
  cdraw.content((8.75, 2.6), [the two resamplings side by side], size: 6.5pt)
  cdraw.content((8.75, 2.15), [oversample 15+15: prec 10/11, rec 2/3, F1 10/13], size: 6pt)
  cdraw.content((8.75, 1.75), [undersample 5+5: prec 1, rec 3/5, F1 3/4], size: 6pt)
  cdraw.content((8.75, 1.35), [both clear the baseline F1 2/3 by different trades], size: 6pt)
})

#callout("pitfall", "the resampled set is the thing measured", [
  Both resamplings here keep the threshold rule fixed and re-score the
  balanced set, so the pins measure what duplication and subtraction do
  to the ledger, not what a retrained model would do on fresh data.
  And the undersample's clean precision 1 carries a seed's fingerprint:
  row 5 happened to be never drawn, and a different draw that keeps the
  0.6 row leaves FP = 1 and drops precision off its pedestal. The D3
  pins make that visible instead of magical, the same way the
  #xref-to("kdd", "svm") trace named its selection heuristics: the
  number is this sample's number.
])

sources: the class imbalance problem and the systematic study of
resampling's effect on classifiers per Nathalie Japkowicz and Shaju
Stephen, The Class Imbalance Problem: A Systematic Study, Intelligent
Data Analysis 6(5):429-449, 2002, banked by kdd-contract-s4s5.md. The
0/0 precision convention, the predict-plus-when-score-at-or-above-t
rule, and the cost-row ruling with both readings are pinned by the same
sheet. All 41 pinned values witnessed by the sheet and
playground/kdd-matrix/gen_s5.py, run 2026-09-22, exit 0, both draw
streams identical across two consecutive runs. Sample behavior verified
by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch24`, 19 + 22 checks in chapter 24 of
the kdd suite.
