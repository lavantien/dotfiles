// ch23, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 54 checks in kdd/samples/src/Ch23/bagging.c (17), adaboost.c (19),
// and rf.c (18) or a banked provenance note of kdd-contract-s4s5.md
// (Breiman 1996 for bagging, Freund-Schapire 1997 for the AdaBoost alpha
// = 0.5 ln((1-e)/e), Breiman 2001 for random forests and MDI importance).
// draws and feature subsets are D3 pinned literals, fractions and counts
// D0, the three alphas D2 at 1e-15 over libm log. all pinned values are
// witnessed by the sheet + playground/kdd-matrix/gen_s5.py, run
// 2026-09-22, exit 0, the LCG streams double-run identical.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= bagging, boosting, and random forests

Three samples carry the chapter: `bagging.c` draws five bootstrap
replicates and majority-votes their stumps, 17 checks, `adaboost.c` runs
three rounds of exact-fraction reweighting and casts the final vote as
an integer comparison, 19 checks, and `rf.c` grows three feature-subset
trees and prices their importances, 18 checks. The chapter makes 4 moves:
resampling as the noise source a vote can average away, reweighting as
the loop that concentrates weight on misses, the logarithm that never
has to be computed, and the forest that turns importance into a measured
quantity. Every behavioral claim below is one of the 54 checks of
chapter 23's samples or a banked note of the contract sheet. The single
plane #xref-to("kdd", "svm") hunted for is gone: the model is now a
committee of the gini stumps #xref-to("kdd", "cart") grew, its errors
are counted the way #xref-to("kdd", "evaluation") counts them, and
#xref-to("kdd", "imbalance") will stress these same votes on a skewed
class mix.

== five resamples, one vote

Bagging's bet is that a learner's mistakes on resampled data are partly
noise: draw the training set with replacement a few times, fit one stump
per replicate, and let a majority vote cancel the idiosyncrasies. The
fixture is 9 rows, x = 1 to 9 with labels +,+,-,+,-,-,+,-,-, the learner
is the both-direction stump with the pinned candidate order and tie rule,
and the wave LCG seeded 3076 draws 5 replicates of 9 draws each, every
draw kept, repeats and all.

The dry run: on the full data the stump prints `full-data stump: L2 err
2/9`, wrong only at x = 4 and x = 7, both plus rows beyond the boundary.
The replicates print `bootstrap 1 idx=[8,3,6,7,1,0,6,8,8] stump=L7
err=0/9`, `bootstrap 2 idx=[1,8,3,1,5,4,1,6,5] stump=L4 err=1/9`,
`bootstrap 3 idx=[6,0,4,7,4,4,6,4,6] stump=R6 err=2/9`, `bootstrap 4
idx=[8,6,1,6,1,2,0,0,3] stump=L7 err=1/9`, and `bootstrap 5
idx=[6,1,5,3,1,8,3,5,8] stump=L4 err=1/9`. The draws are D3 pinned
literals, one LCG stream run straight through, so the five lists are one
object, not five coincidences. Replicate 1 draws row 9 three times and
never sees x = 3, 5, 6, which is why its stump can be perfect, err 0/9.
None of the five rediscovers the full-data stump L2, and one faces the
other way entirely, R6.

The three test rows settle the bet. `test (2,+): single=+
votes=[+,+,-,+,+] ensemble=+`, `test (5,-): single=- votes=[+,-,-,+,-]
ensemble=-`, and `test (7,+): single=- votes=[+,-,+,+,-] ensemble=+`. The
single stump misses exactly one test row, x = 7, and the committee fixes
exactly that row, three plus votes against two: check "ch23 exactly 1
flip vs single model" names the whole improvement, one flip, zero
residual errors on the test set, "ch23 ensemble 0 test errors".

#listing("kdd/samples/src/Ch23/bagging.c", first: 47, last: 86,
  caption: [the stump learner, pinned candidate order, strict improvement keeps the first tie winner])

#listing("kdd/samples/src/Ch23/bagging.c", first: 89, last: 119,
  caption: [seed 3076, the full-data baseline stump, then the five replicate draws])

#listing("kdd/samples/src/Ch23/bagging.c", first: 132, last: 166,
  caption: [test rows, the 5-vote majority, and the one-flip accounting])

#diagram([five bootstrap replicates from one LCG stream, and the one flip the vote buys], length: 13pt, {
  cdraw.content((8.75, 8.4), [full data: x = 1..9, labels +,+,-,+,-,-,+,-,-], size: 6.5pt)
  for i in range(9) {
    let xs = 0.95 + i * 1.05
    let plus = (i == 0 or i == 1 or i == 3 or i == 6)
    cdraw.rect((xs - 0.44, 7.35), (xs + 0.44, 8.05),
      fill: if plus {luma(238)} else {luma(216)}, radius: 0.02)
    cdraw.content((xs, 7.8), str(i + 1), size: 6pt)
    cdraw.content((xs, 7.5), if plus {[+]} else {[-]}, size: 6pt)
  }
  cdraw.content((12.6, 7.8), [single stump: L2, err 2/9], size: 6pt)
  cdraw.content((12.6, 7.5), [wrong at x = 4 and x = 7], size: 6pt)
  let rep(y, tag, idx, st, er, note) = {
    cdraw.content((0.75, y), tag, size: 6pt)
    cdraw.content((3.6, y), idx, size: 6pt)
    cdraw.content((7.35, y), st, size: 6pt)
    cdraw.content((8.6, y), er, size: 6pt)
    cdraw.content((13.0, y), note, size: 6pt)
  }
  rep(6.45, [rep 1], [8 3 6 7 1 0 6 8 8], [L7], [0/9],
    [x=9 drawn 3x, x = 3, 5, 6 unseen])
  rep(5.75, [rep 2], [1 8 3 1 5 4 1 6 5], [L4], [1/9], [])
  rep(5.05, [rep 3], [6 0 4 7 4 4 6 4 6], [R6], [2/9],
    [the only right-facing stump])
  rep(4.35, [rep 4], [8 6 1 6 1 2 0 0 3], [L7], [1/9], [])
  rep(3.65, [rep 5], [6 1 5 3 1 8 3 5 8], [L4], [1/9], [])
  cdraw.line((0.7, 3.05), (16.8, 3.05), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((8.75, 2.6), [test rows: the single stump against the 5-vote committee], size: 6.5pt)
  let trow(y, tag, single, votes, hotvotes, ens, note, hot) = {
    if hot {
      cdraw.rect((0.9, y - 0.32), (9.7, y + 0.32), fill: luma(245), radius: 0.02)
    }
    cdraw.content((1.9, y), tag, size: 6pt)
    cdraw.content((3.9, y), single, size: 6pt)
    for m in range(5) {
      let xs = 5.1 + m * 0.6
      cdraw.rect((xs - 0.26, y - 0.26), (xs + 0.26, y + 0.26),
        fill: if hotvotes.at(m) {luma(235)} else {luma(212)}, radius: 0.02)
      cdraw.content((xs, y), votes.at(m), size: 6pt)
    }
    cdraw.rect((8.35, y - 0.28), (9.6, y + 0.28), fill: luma(230), radius: 0.02)
    cdraw.content((8.98, y), ens, size: 6pt)
    cdraw.content((13.2, y), note, size: 6pt)
  }
  trow(1.95, [x=2, truth +], [single +], ([+], [+], [-], [+], [+]),
    (true, true, false, true, true), [ens +], [4-1, agrees], false)
  trow(1.3, [x=5, truth -], [single -], ([+], [-], [-], [+], [-]),
    (true, false, false, true, false), [ens -], [2-3, agrees], false)
  trow(0.65, [x=7, truth +], [single -], ([+], [-], [+], [+], [-]),
    (true, false, true, true, false), [ens +], [3-2, the one flip], true)
})

#callout("note", "a zero-error replicate is nothing special here", [
  Replicate 1's stump separates its 9 rows perfectly, and in a boosting
  frame that would be a problem: alpha has a division by e waiting for
  it. Bagging does not care. Every voter casts one vote regardless of
  its training error, so a perfect stump on a distorted sample and the
  2/9 stump of replicate 3 weigh exactly the same. The vote needs
  diversity between the voters, not excellence of each one, and the
  resampling is what supplies the diversity.
])

== three rounds of reweighting

AdaBoost keeps the stump learner and changes the objective: fit the best
stump under the current weights, then move weight onto what it missed.
The update per Freund-Schapire 1997 sets $alpha = 1\/2 ln((1-e)\/e) =
1\/2 ln r$ for stump error $e$, multiplies each miss's weight by
$e^(+alpha)$ and each correct point's by $e^(-alpha)$, then renormalizes.
Both factors carry a square root of $r$, and the sample clears it:
multiply the misses by $r$ instead, leave the rest alone, and divide
everyone by $A r + B$ with $A$ the misclassified weight mass and $B = 1
- A$. Same fixed point, and every weight stays a reduced fraction
computed from integers.

The dry run, all three rounds verbatim. `round 1: stump=L2 e=1/6 r=5/1
alpha=0.8047189562170501` with weights `1/10 1/10 1/10 1/2 1/10 1/10`:
round 1 starts uniform, L2 errs only x4, denominator $(1\/6)(5) + 5\/6 =
5\/3$, so x4 lands on $1\/2$ and the rest on $1\/10$. `round 2:
stump=L4 e=1/10 r=9/1 alpha=1.0986122886681098` with weights `1/18
1/18 1/2 5/18 1/18 1/18`: L4 errs only x3, denominator $(1\/10)(9) +
9\/10 = 9\/5$. `round 3: stump=R4 e=2/9 r=7/2
alpha=0.6263814842476840` with weights `1/8 1/8 9/28 5/28 1/8 1/8`: R4
errs x1, x2, x5, x6 for $e = 4\/18 = 2\/9$, denominator $(2\/9)(7\/2) +
7\/9 = 14\/9$, and each weight vector check closes with its own
sum-to-1. The three alphas are the only non-fractional objects in the
chapter, D2 at 1e-15 because libm log is in the path.

#listing("kdd/samples/src/Ch23/adaboost.c", first: 119, last: 136,
  caption: [one round: weighted-best stump, r, the mis mass A, the cleared reweight])

#listing("kdd/samples/src/Ch23/adaboost.c", first: 137, last: 162,
  caption: [alpha from r, the printed weight vectors, and the sum-to-1 checks])

#diagram([weights after each round as exact fractions, misses shaded], length: 13pt, {
  cdraw.content((8.75, 8.4), [rounds on x = 1..6, labels +,+,-,+,-,-], size: 6.5pt)
  let rnd(y, head, ws, mis, note) = {
    cdraw.content((5.9, y + 0.72), head, size: 6pt)
    for i in range(6) {
      let xs = 1.9 + i * 1.32
      cdraw.rect((xs - 0.56, y - 0.32), (xs + 0.56, y + 0.34),
        fill: if mis.at(i) {luma(216)} else {luma(244)}, radius: 0.02)
      cdraw.content((xs, y + 0.02), ws.at(i), size: 6pt)
      cdraw.content((xs, y - 0.62), [x#(i + 1)], size: 5.5pt)
    }
    cdraw.content((13.9, y + 0.02), note, size: 6pt)
  }
  rnd(6.8, [round 1: stump L2, e = 1/6, r = 5/1],
    ([1/10], [1/10], [1/10], [1/2], [1/10], [1/10]), (false, false, false, true, false, false),
    [miss: x4 only])
  rnd(5.0, [round 2: stump L4, e = 1/10, r = 9/1],
    ([1/18], [1/18], [1/2], [5/18], [1/18], [1/18]), (false, false, true, false, false, false),
    [miss: x3 only])
  rnd(3.2, [round 3: stump R4, e = 2/9, r = 7/2],
    ([1/8], [1/8], [9/28], [5/28], [1/8], [1/8]), (true, true, false, false, true, true),
    [misses: x1, x2, x5, x6])
  cdraw.line((10.9, 5.75), (10.9, 5.45), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.9, 5.6), [times r, divide by A r + B], size: 5.5pt)
  cdraw.line((10.9, 3.95), (10.9, 3.65), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.9, 3.8), [times r, divide by A r + B], size: 5.5pt)
  cdraw.rect((1.0, 0.45), (16.5, 1.95), fill: luma(243), radius: 0.02)
  cdraw.content((8.75, 1.55), [the square root never materializes], size: 6.5pt)
  cdraw.content((8.75, 1.1), [$w'_"mis" = w r\/(A r + B)$, $w'_"ok" = w\/(A r + B)$, $B = 1 - A$], size: 6pt)
  cdraw.content((8.75, 0.68), [weights stay reduced fractions; only $alpha = 1\/2 ln r$ touches libm log], size: 6pt)
})

== the vote as an integer comparison

The boosted classifier is $H(x) = "sign"(sum_m alpha_m h_m (x))$, a sum
of three irrational alphas, and the sample never evaluates it as a float.
Substituting $alpha_m = 1\/2 ln r_m$ folds the sum into one logarithm,
$1\/2 ln(A\/B)$, where $A$ multiplies $r_m$ for stumps voting plus and
$B$ multiplies $r_m$ for stumps voting minus. Every $r_m$ is an exact
fraction, 5/1, 9/1, 7/2, so $A$ and $B$ are integer products and the
sign of the vote is the sign of $A - B$: the logarithm is monotone, so
it never has to be computed.

The dry run, six lines: `x=1: vote=0.5*ln(90/7) -> + (truth +)`,
`x=2: vote=0.5*ln(90/7) -> + (truth +)`, `x=3: vote=0.5*ln(18/35) ->
- (truth -)`, `x=4: vote=0.5*ln(63/10) -> + (truth +)`,
`x=5: vote=0.5*ln(7/90) -> - (truth -)`, `x=6: vote=0.5*ln(7/90) ->
- (truth -)`. The hand check at x = 3: L2 votes minus so $A$ takes
$r_1$'s denominator 1 and $B$ its numerator 5, L4 votes plus so $A$
takes 9, R4 votes minus so $A$ takes 2 and $B$ takes 7, giving the
pinned pair (18, 35), the closest call of the six. x = 4 is the
instructive one, pair (63, 10): it is round 1's only miss, the point
whose weight started the whole loop, and the committee now gets it
right. All six agree with the labels, check "ch23 adaboost final
ensemble 6/6, error 0/6", against 5/6 for the best single stump, the
same L2 that opened round 1 with e = 1/6.

#listing("kdd/samples/src/Ch23/adaboost.c", first: 164, last: 187,
  caption: [the vote as two integer products of the exact r fractions, sign only])

#diagram([the weighted vote per point, A against B as integer products], length: 13pt, {
  cdraw.content((8.75, 8.35), [$H(x) = "sign"(sum_m alpha_m h_m (x)) = "sign"(A - B)$], size: 6.5pt)
  let cols = ((1.4, [x]), (3.3, [h1 L2]), (4.9, [h2 L4]), (6.5, [h3 R4]),
    (8.7, [A]), (10.5, [B]), (12.3, [H(x)]), (14.8, [note]))
  for c in cols {
    cdraw.content((c.at(0), 7.55), c.at(1), size: 6.5pt)
  }
  let vrow(y, x, h1, h2, h3, a, b, s, note, hot) = {
    if hot {
      cdraw.rect((0.8, y - 0.28), (13.4, y + 0.28), fill: luma(245), radius: 0.02)
    }
    cdraw.content((1.4, y), x, size: 6pt)
    cdraw.content((3.3, y), h1, size: 6pt)
    cdraw.content((4.9, y), h2, size: 6pt)
    cdraw.content((6.5, y), h3, size: 6pt)
    cdraw.content((8.7, y), a, size: 6pt)
    cdraw.content((10.5, y), b, size: 6pt)
    cdraw.content((12.3, y), s, size: 6pt)
    cdraw.content((14.8, y), note, size: 6pt)
  }
  vrow(6.9, [1], [+], [+], [-], [90], [7], [+], [], false)
  vrow(6.18, [2], [+], [+], [-], [90], [7], [+], [], false)
  vrow(5.46, [3], [-], [+], [-], [18], [35], [-], [closest call], true)
  vrow(4.74, [4], [-], [+], [+], [63], [10], [+], [round 1's miss, fixed], true)
  vrow(4.02, [5], [-], [-], [+], [7], [90], [-], [], false)
  vrow(3.3, [6], [-], [-], [+], [7], [90], [-], [], false)
  cdraw.rect((1.0, 0.9), (16.5, 2.55), fill: luma(243), radius: 0.02)
  cdraw.content((8.75, 2.1), [$A$ multiplies $r_m$ = 5, 9, 7\/2 for agreeing stumps, $B$ for dissenting], size: 6pt)
  cdraw.content((8.75, 1.6), [both are integer products, so the monotone log decides nothing that $A > B$ has not], size: 6pt)
  cdraw.content((8.75, 1.15), [single stump L2: 5/6, the ensemble: 6/6], size: 6pt)
})

== random forests and measured importance

The random forest bags the trees and adds a second die: each tree sees
only a drawn subset of the features, here one subset per tree from the
LCG at seed 4023, redrawn if the draw comes up empty. The learner is the
depth-2 gini tree with exact fraction gains and the pinned tie tuple,
lower feature index first, then lower threshold. The fixture is 8 rows,
(f1, f2, label) = (1,1,A) (1,2,A) (2,1,A) (2,2,A) (3,1,B) (3,2,B)
(4,1,B) (4,2,A), that last row being the trap: among f1 = 4 rows the
labels disagree, so only f2 splits them.

The dry run: `tree 1: feature mask 2 -> {f2}`, `tree 2: feature mask 1
-> {f1}`, `tree 3: feature mask 3 -> {f1,f2}`, the masks D3 pins. Tree 1
is forced down f2 and prints `tree1: f2<=1 gain 1/32, leaves A,A`. Trees
2 and 3 print the same shape, `tree2: f1<=2 gain 9/32 | left leaf A |
right f1<=3 gain 1/8 -> B,A`, and tree 3 identical: at the root f1<=2
gains 9/32 against f2<=1's 1/32, and in the right child f1<=3 and f2<=1
both gain exactly 1/8, so the tie breaks to f1 by index even in tree 3,
which had both features in hand. The four test rows vote `test (2,1)
truth A: preds A,A,A vote A`, `test (3,2) truth B: preds A,B,B vote B`,
`test (4,2) truth A: preds A,A,A vote A`, `test (4,1) truth B: preds
A,A,A vote A`, the lone miss being the (4,1,B) minority row every tree
routes to an A leaf, 3/4 overall.

Importance is where the subset die pays off. MDI credits feature f with
$sum ("n"_"node"\/8) dot "gain"$ over its splits: `tree 1 importance:
f1=0/1 f2=1/32`, `tree 2 importance: f1=11/32 f2=0/1`, tree 3 the same,
the 11/32 being $(8\/8)(9\/32) + (4\/8)(1\/8)$. The mean prints `mean
importance: f1=11/48 f2=1/96`, and the control closes the argument:
`full-feature tree importance: f1=11/32 f2=0/1`. Given both features at
every node, the same tie rule silences f2 completely, so all of f2's
1/96 exists because tree 1 was forced to look at f2 alone.

#listing("kdd/samples/src/Ch23/rf.c", first: 131, last: 152,
  caption: [the split loop: weighted child gini, exact gain, ties to lower feature then threshold])

#listing("kdd/samples/src/Ch23/rf.c", first: 204, last: 221,
  caption: [seed 4023, one feature-subset draw per tree, tree growth])

#listing("kdd/samples/src/Ch23/rf.c", first: 285, last: 305,
  caption: [per-tree MDI as exact fractions, then the 3-tree mean])

#listing("kdd/samples/src/Ch23/rf.c", first: 307, last: 315,
  caption: [the full-feature control: f2 importance exactly 0])

#diagram([three trees on drawn feature subsets, and what importance measures], length: 13pt, {
  cdraw.content((8.75, 8.4), [tree 1 sees only f2, trees 2 and 3 choose f1 anyway], size: 6.5pt)
  let nbox(x, y, w, txt) = {
    cdraw.rect((x - w, y - 0.28), (x + w, y + 0.28), fill: luma(246), radius: 0.02)
    cdraw.content((x, y), txt, size: 6pt)
  }
  let lbox(x, y, txt) = {
    cdraw.rect((x - 0.4, y - 0.28), (x + 0.4, y + 0.28), fill: luma(230), radius: 0.02)
    cdraw.content((x, y), txt, size: 6pt)
  }
  nbox(3.3, 7.4, 0.85, [f2 <= 1])
  cdraw.line((2.95, 7.12), (1.85, 6.35), stroke: luma(120))
  cdraw.line((3.65, 7.12), (4.75, 6.35), stroke: luma(120))
  lbox(1.8, 6.05, [A])
  lbox(4.8, 6.05, [A])
  cdraw.content((3.3, 5.35), [tree 1: gain 1/32, leaves A, A], size: 6pt)
  nbox(12.4, 7.55, 0.85, [f1 <= 2])
  cdraw.line((11.75, 7.27), (10.35, 6.75), stroke: luma(120))
  cdraw.line((13.05, 7.27), (14.15, 6.75), stroke: luma(120))
  lbox(10.2, 6.5, [A])
  nbox(14.4, 6.5, 0.85, [f1 <= 3])
  cdraw.line((13.85, 6.22), (13.25, 5.75), stroke: luma(120))
  cdraw.line((14.95, 6.22), (15.55, 5.75), stroke: luma(120))
  lbox(13.2, 5.45, [B])
  lbox(15.6, 5.45, [A])
  cdraw.content((12.4, 4.75), [trees 2 and 3: gains 9/32 and 1/8], size: 6pt)
  cdraw.content((12.4, 4.35), [the 1/8 tie vs f2 <= 1 goes to f1 by index], size: 6pt)
  cdraw.content((4.0, 3.65), [mean MDI over 3 trees], size: 6.5pt)
  cdraw.content((5.2, 2.85), [f1], size: 6pt)
  cdraw.rect((5.7, 2.65), (10.3, 3.05), fill: luma(210), radius: 0.02)
  cdraw.content((11.1, 2.85), [11/48], size: 6pt)
  cdraw.content((5.2, 2.0), [f2], size: 6pt)
  cdraw.rect((5.7, 1.8), (5.92, 2.2), fill: luma(210), radius: 0.02)
  cdraw.content((6.7, 2.0), [1/96], size: 6pt)
  cdraw.content((8.75, 1.05), [full-feature tree alone: f1 = 11/32, f2 = 0], size: 6pt)
  cdraw.content((8.75, 0.55), [f2's entire 1/96 is tree 1's forced viewpoint], size: 6pt)
})

#callout("pitfall", "importance is a property of this forest", [
  MDI sums the gains a feature actually received, under the drawn
  subsets and the pinned tie rule. The right child's 1/8 tie went to f1
  twice, and once more in the full-feature control; a different tie rule
  or a different seed moves f2's mean off 1/96 without any change to the
  data. The number answers "how much did f2 participate in these three
  trees", which is a fact about the ensemble, and only a hint about the
  generating process. The honest reading is the comparison the sample
  pins: 1/96 with forced diversity against exactly 0 without it.
])

sources: bagging per Leo Breiman, Bagging Predictors, Machine Learning
24(2):123-140, 1996. The AdaBoost update with $alpha = 1\/2 ln((1-e)\/e)$
per Yoav Freund and Robert E. Schapire, A decision-theoretic
generalization of on-line learning and an application to boosting,
Journal of Computer and System Sciences 55(1):119-139, 1997. Random
forests with feature subsetting and mean decrease in impurity per Leo
Breiman, Random Forests, Machine Learning 45(1):5-32, 2001. All three
banked by kdd-contract-s4s5.md. All 54 pinned values witnessed by the
same sheet and playground/kdd-matrix/gen_s5.py, run 2026-09-22, exit 0,
the bootstrap, subset, and feature draws identical across two consecutive
runs. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch23`, 17 + 19 + 18 checks in chapter 23 of the kdd suite.
