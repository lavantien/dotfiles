#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= mathematics answers

The math round is computable or it is nothing: the questions below
are answered with arithmetic you can do at the board, and every
drill here is that arithmetic said out loud, the claim first, the
computation second, the follow-up named before it arrives. The
floors are the math handbook, proof, combinatorics, probability,
statistics, plus the dsa analysis chapter for reading a cost
claim. Drill numbers are textbook values, the workspace's measured.

== asymptotics and solving recurrences [DRILL]

Big-O is a claim about growth, not about speed: $f(n) = O(g(n))$
says there exist witnesses $c > 0$ and $n_0$ with $f(n) <= c g(n)$
for every $n >= n_0$, an upper bound on the rate the work grows
at, carrying no constants, no cache effects, no lower-order
terms. Big-Omega is the same claim from below, big-Theta both
directions, and the honest answer says theta when it can prove
both. The master theorem in one breath: for $T(n) = a T(n\/b) +
f(n)$ with $a >= 1$ and $b > 1$, compare the root's work $f(n)$
against the leaves' work $n^(log_b a)$. Leaves win by a
polynomial and the answer is $Theta(n^(log_b a))$, root wins by a
polynomial with the regularity condition holding and it is
$Theta(f(n))$, tied within a log factor and the log multiplies
in, $Theta(n^(log_b a) log n)$. Mergesort, $2 T(n\/2) + n$, is
the tie case at $n log n$, and binary search and exponentiation by
squaring, $T(n\/2) + O(1)$ on the halved exponent, land at
$Theta(log n)$, the shape the modular exponentiation loop
actually runs, #xref-to("dsa", "numtheory"), and Karatsuba's
$3 T(n\/2) + n$ is the classic $n^(log_2 3)$, about $n^1.585$.
The unclean cases, uneven splits like $T(n) = T(n\/2) + T(n\/3) +
n$ or root work of $n log n$, do not fit the theorem, and the
recursion tree does: draw the splits, sum each level, count the
levels, and the tree is the proof the theorem only shortcuts. The
follow-up is whether $n log n$ beats $n^2$ in practice, answered
from the definition: past some $n_0$ it wins, below it the
quadratic insertion sort's constants win, and reading a cost
claim against a benchmark honestly is a chapter of its own,
#xref-to("dsa", "analysis").

#diagram([the recursion tree sums level by level, the theorem only compares the root against the leaves], length: 13pt, {
  // left: three levels of the mergesort tree with the level sums, right: the three cases as rows
  let node(x, y, t, fill: luma(215)) = {
    cdraw.rect((x, y), (x + 1.4, y + 0.85), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + 0.7, y + 0.42), [#t], size: 6pt)
  }
  cdraw.content((4.0, 10.1), [recursion tree, $2 T(n\/2) + n$], size: 6.5pt)
  node(3.3, 8.9, [n])
  cdraw.line((4.0, 8.9), (2.4, 7.75), stroke: luma(100))
  cdraw.line((4.0, 8.9), (5.5, 7.75), stroke: luma(100))
  node(1.7, 6.9, [$n\/2$])
  node(4.8, 6.9, [$n\/2$])
  for i in range(4) {
    cdraw.line((2.4, 6.9), (0.8 + i * 1.9, 5.85), stroke: luma(150))
    cdraw.line((5.5, 6.9), (0.8 + i * 1.9, 5.85), stroke: luma(150))
    node(0.1 + i * 1.9, 5.0, [$n\/4$], fill: luma(245))
  }
  cdraw.line((8.1, 4.9), (8.1, 9.3), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((4.0, 4.0), [log n levels, each level sums to n], size: 6pt)
  cdraw.content((4.0, 3.0), [total $n log n$, the tree is the proof], size: 6pt)
  let cell(x, y, w, t, head: false) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: if head { luma(252) } else { luma(240) }, stroke: luma(210), radius: 0.0)
    cdraw.content((x + w / 2, y + 0.5), [#t], size: 6pt)
  }
  cdraw.content((16.6, 10.1), [master theorem, $f(n)$ against $n^(log_b a)$], size: 6.5pt)
  let xs = (9.2, 14.2, 18.6)
  let ws = (5.0, 4.4, 5.4)
  cell(xs.at(0), 8.5, ws.at(0), [comparison], head: true)
  cell(xs.at(1), 8.5, ws.at(1), [the answer], head: true)
  cell(xs.at(2), 8.5, ws.at(2), [example], head: true)
  let rows = (
    ([root wins by a polynomial], [$Theta(f(n))$], [$2 T(n\/2) + n^2$ is $n^2$]),
    ([leaves win by a polynomial], [$Theta(n^(log_b a))$], [$2 T(n\/2) + 1$ is $n$]),
    ([tied within a log factor], [$Theta(n^(log_b a) log n)$], [$2 T(n\/2) + n$ is $n log n$]),
  )
  for r in range(rows.len()) {
    for c in range(3) { cell(xs.at(c), 7.3 - r * 1.1, ws.at(c), rows.at(r).at(c)) }
  }
  cdraw.content((16.6, 3.7), [regularity: $a f(n\/b) <= c f(n)$ for some $c < 1$, else the root case fails], size: 6pt)
  cdraw.content((16.6, 2.7), [uneven splits, $T(n\/2) + T(n\/3) + n$, go to the tree], size: 6pt)
})

== probability you can compute at the board [DRILL]

Start from the sample space: with equally likely outcomes the
probability is favorable over total, and board questions die on
the total, not the favorable. The complement is the first move
whenever the words "at least one" appear, because a union of many
events is messy and "none" is one intersection: P(at least one)
is 1 minus P(none). The birthday staple: the chance that two of
n people share a birthday is $1 - product_(i=1)^(n-1) (365 -
i)\/365$, about 0.12 at 10 people, 0.51 at 23, 0.97 at 50, the
coin flip sitting at 23 people, and the same arithmetic prices
hash collisions, a 64-bit space reaching a coin-flip collision
near $2^32$ keys. Expectations are linearity first: $E[X + Y] =
E[X] + E[Y]$ always, with independence nowhere required, so write
the quantity as a sum of indicators and add. The indicator sum
answers the fixed points of a random permutation: each of the n
positions is fixed with probability $1\/n$, so the expected count
is $n dot 1\/n = 1$, for every n, the derangement ladder
underneath being the combinatorics chapter's,
#xref-to("math", "combinatorics"). The coupon collector is the
other staple: n coupon types, each draw uniform, the expected
draws to see them all is $n H_n$ over the harmonic number $H_n$,
about $n ln n + 0.577 n$, a 52-card deck costing about 236
draws. The follow-up is the variance of a sum, answered
honestly: variances add for independent terms only, $V(X + Y) =
V(X) + V(Y)$, covariance otherwise, and the conditioning
machinery is the probability chapter's,
#xref-to("math", "probability").

#diagram([the birthday ladder crosses one half at 23 people, linearity turns sums into additions], length: 13pt, {
  // left: birthday collision bars against the one-half line, right: the linearity and coupon boxes
  cdraw.content((5.4, 10.1), [p(shared birthday), n people], size: 6.5pt)
  let bd = ((10, 0.12), (20, 0.41), (23, 0.51), (30, 0.71), (50, 0.97))
  for i in range(bd.len()) {
    let (ppl, p) = bd.at(i)
    let h = p * 6.8
    cdraw.rect((1.9 + i * 1.6, 2.4), (3.05 + i * 1.6, 2.4 + h), fill: if ppl == 23 { luma(140) } else { luma(215) }, stroke: luma(120), radius: 0.0)
    cdraw.content((2.48 + i * 1.6, 2.4 + h + 0.32), [#p], size: 6pt)
    cdraw.content((2.48 + i * 1.6, 1.85), [#ppl], size: 6pt)
  }
  cdraw.line((1.7, 2.4), (9.7, 2.4), stroke: luma(120))
  cdraw.line((1.7, 5.8), (9.7, 5.8), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((1.0, 5.8), [0.5], size: 6pt)
  cdraw.content((5.4, 0.9), [23 people, about 0.51], size: 6pt)
  cdraw.rect((10.8, 6.9), (23.8, 9.5), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((17.3, 9.05), [linearity, no independence needed], size: 6.5pt)
  cdraw.content((17.3, 8.2), [$E[X + Y] = E[X] + E[Y]$: n indicators, each $1\/n$], size: 6pt)
  cdraw.content((17.3, 7.35), [expected fixed points of a permutation: 1, any n], size: 6pt)
  cdraw.rect((10.8, 3.4), (23.8, 6.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.3, 5.95), [coupon collector], size: 6.5pt)
  cdraw.content((17.3, 5.1), [$n H_n$, about $n ln n + 0.577 n$], size: 6pt)
  cdraw.content((17.3, 4.2), [a 52-card deck: about 236 draws], size: 6pt)
  cdraw.content((17.3, 2.5), [complement first: at least one is 1 minus none], size: 6pt)
})

== counting and combinatorics [DRILL]

Two rules carry everything: stages in sequence multiply,
disjoint alternatives add, and every counting answer is one of
those two or the repair of a miscount. Permutations against
combinations: drawing $k$ from $n$ where order matters gives
$n (n-1) dots (n - k + 1)$ ordered tuples, $4 times 3 = 12$
ordered pairs from four, and order irrelevant means the binomial
coefficient $binom(n, k) = n!\/(k! (n-k)!)$ divides out the
$k!$ orderings that do not matter, $binom(4, 2) = 6$ subsets.
Stars and bars is the identical-items move: k identical candies
into n distinct bins is a string of k stars and $n - 1$ bars,
and choosing the bar positions among the $n + k - 1$ slots gives
$binom(n + k - 1, k)$, four candies into three bins being
$binom(6, 2) = 15$. Inclusion-exclusion is the overcount repair:
summing set sizes counts each overlap twice, so $abs(A union B)
= abs(A) + abs(B) - abs(A inter B)$, three sets subtract the
pairs and add the triple back, and the derangement count $!n$ is
its purest form, walking to $n!\/e$ as n grows, every identity
here pinned in exact arithmetic, #xref-to("math",
"combinatorics"). The pigeonhole principle is the zero-arithmetic
bound, $n + 1$ items into n boxes forces a shared box, the proof
chapter's functions section, #xref-to("math", "proof"). The
follow-up is add or multiply: stages multiply, alternatives add,
and the miscount worth confessing is the one where the stages
were not actually independent.

#diagram([order divides out, bars make bins identical, the overlap is added back once], length: 13pt, {
  // left: ordered pairs against subsets, middle: a stars-and-bars string, right: two circles and the formula
  cdraw.content((3.8, 10.1), [order against subsets], size: 6.5pt)
  cdraw.rect((0.3, 8.0), (7.3, 9.2), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((3.8, 8.6), [ordered pairs from 4: $4 times 3 = 12$], size: 6pt)
  cdraw.line((3.8, 7.9), (3.8, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.0, 7.35), [divide by $k! = 2$], size: 6pt)
  cdraw.rect((0.3, 5.5), (7.3, 6.7), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((3.8, 6.1), [subsets of size 2: $binom(4, 2) = 6$], size: 6pt)
  cdraw.content((3.8, 4.6), [$binom(n, k) = n!\/(k! (n-k)!)$], size: 6pt)
  cdraw.content((3.8, 3.6), [the $k!$ orderings that do not matter, divided out], size: 6pt)
  cdraw.content((11.6, 10.1), [stars and bars], size: 6.5pt)
  let sym = (("*", true), ("*", true), ("*", true), ("|", false), ("*", true), ("|", false))
  for i in range(sym.len()) {
    let (g, star) = sym.at(i)
    cdraw.rect((8.3 + i * 1.1, 7.5), (9.4 + i * 1.1, 8.6), fill: if star { luma(215) } else { luma(140) }, stroke: luma(120), radius: 0.0)
    cdraw.content((8.85 + i * 1.1, 8.05), [#g], size: 6pt)
  }
  cdraw.content((11.6, 6.7), [4 identical candies, 3 bins], size: 6pt)
  cdraw.content((11.6, 5.8), [$binom(4 + 2, 2) = 15$ distributions], size: 6.5pt)
  cdraw.content((11.6, 4.6), [choose the bar positions among $n + k - 1$ slots], size: 6pt)
  cdraw.content((19.8, 10.1), [inclusion-exclusion], size: 6.5pt)
  cdraw.circle((18.1, 6.9), radius: 1.9, stroke: luma(100))
  cdraw.circle((21.5, 6.9), radius: 1.9, stroke: luma(100))
  cdraw.content((17.0, 6.9), [A], size: 6pt)
  cdraw.content((22.6, 6.9), [B], size: 6pt)
  cdraw.content((19.8, 5.7), [counted twice], size: 6pt)
  cdraw.content((19.8, 4.3), [$abs(A union B) = abs(A) + abs(B) - abs(A inter B)$], size: 6pt)
  cdraw.content((19.8, 3.3), [3 sets: subtract the pairs, add the triple back], size: 6pt)
  cdraw.content((19.8, 2.3), [derangements walk to $n!\/e$], size: 6pt)
})

== reading statistics: baselines, p-values, overfitting [DRILL]

A baseline owns the claim because a raw score has no referent:
90 percent accuracy on a 90/10 class split is the majority-class
baseline wearing a model, and the honest claim is the lift,
model score minus trivial predictor, regression judged against
predict-the-mean under squared error. Name the baseline, then the
number, #xref-to("math", "statistics"). The p-value is the
probability, under the null hypothesis, of an outcome at least as
extreme as the one observed: a number about the test and the
data, not the probability that the null is true, not one minus
the probability the effect is real, and not alpha, which is the
size $P("reject" | H_0)$ chosen before the test, the power being
$1 - beta$. A p under alpha rejects the null and confirms nothing
else. Multiple testing is where naive reading breaks: 20
independent tests at $alpha = 0.05$ give at least one false
rejection with probability $1 - 0.95^20$, about 0.64, the
complement trick from the probability section turned against you,
and the repair is a stricter per-test threshold, Bonferroni's
alpha divided by the number of tests. Overfitting is
memorization with a smooth face: training error falls as capacity
grows while held-out error falls, turns, and rises, a degree
$n - 1$ polynomial passing through any n points exactly,
interpolation being the memorization limit, and the cure is
capacity, or data, or both, the bias-variance framing, high bias
underfitting and high variance overfitting, being the estimators
chapter's vocabulary, #xref-to("math", "statistics"). The
follow-up is how you would know, answered with a held-out set
touched once, at the end.

#callout("pitfall", "the p-value is not the probability the null is true", [
  The definition runs one way: it is $P("data this extreme" |
  H_0)$, the probability of the outcome given the null, never
  $P(H_0 | "data")$, the probability of the null given the
  outcome. Swapping the conditionals is the most common statistics
  answer to get wrong at the board, and the swap moves the number
  in both directions.
])

#diagram([the baseline owns the number, the gap opens where the fit memorizes], length: 13pt, {
  // left: majority-class bar against model bar with the lift marked, right: training and held-out error against capacity
  cdraw.content((3.9, 10.1), [the lift over the trivial predictor], size: 6.5pt)
  cdraw.rect((1.4, 2.4), (3.8, 8.7), fill: luma(245), stroke: luma(120), radius: 0.0)
  cdraw.content((2.6, 9.05), [90], size: 6pt)
  cdraw.content((2.6, 1.9), [majority class], size: 6pt)
  cdraw.rect((4.6, 2.4), (7.0, 8.77), fill: luma(215), stroke: luma(120), radius: 0.0)
  cdraw.content((5.8, 9.05), [91], size: 6pt)
  cdraw.content((5.8, 1.9), [the model], size: 6pt)
  cdraw.line((3.8, 8.7), (7.0, 8.77), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((3.9, 0.9), [on a 90/10 split, 91 percent is the baseline plus 1], size: 6pt)
  cdraw.content((17.3, 10.1), [training falls, held-out turns], size: 6.5pt)
  cdraw.line((11.4, 2.2), (23.4, 2.2), stroke: luma(120))
  cdraw.line((11.4, 2.2), (11.4, 9.0), stroke: luma(120))
  cdraw.content((23.3, 1.7), [capacity], size: 6pt)
  cdraw.content((11.0, 9.1), [error], size: 6pt)
  cdraw.line((11.6, 8.6), (14.4, 6.3), (17.2, 4.8), (20.0, 4.0), (22.9, 3.4), stroke: luma(60))
  cdraw.content((21.2, 3.1), [training], size: 6pt)
  cdraw.line((11.6, 8.8), (14.2, 5.6), (16.6, 4.7), (18.8, 5.1), (21.0, 6.2), (22.9, 7.4), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((20.9, 7.7), [held-out], size: 6pt)
  cdraw.circle((16.6, 4.7), radius: 0.12, fill: luma(60))
  cdraw.content((15.4, 4.2), [the turn], size: 6pt)
  cdraw.content((17.3, 1.0), [a degree $n - 1$ polynomial hits any n points exactly: memorization], size: 6pt)
})

== the statistics workspace: exact binomial, auc, bootstrap, verdicts [TDD]

The drill above reads statistics at the board; this section computes
them, a workspace in `ch27-go` a candidate can speak from and run,
26 test functions under `make verify-go`, stdlib only, every number
below measured off the suite's own output. Four answers, one file
each. The exact two-sided binomial first, because exact is the claim
worth defending: no normal approximation anywhere, the p-value summed
over the cells themselves, and the arithmetic in log space so n in
the thousands never forms a factorial that overflows or a product of
tiny cells that underflows, the central cell of a 10k-flip fair coin
coming back 0.0079786 where a product-of-cells path returns plain 0:

#listing("interview-repertoire/samples/ch27-go/binom.go", first: 19, last: 85, caption: [the pmf through lgamma, then the two-sided region visited by ratio, never by factorial])

Two choices inside are the spoken answer. The point-probability
method, not tail doubling: the region is every cell whose probability
is at most the observed cell's, while doubling the smaller tail is
the shortcut that can pass 1 and that on an asymmetric p disagrees
with the cell sum about which cells count as extreme. And the cells
are visited by ratio, $ln P(k+1) = ln P(k) + ln((n-k)\/(k+1)) + ln(p\/(1-p))$, so past the validity check the walk evaluates no
factorials at all, only ratios, whatever the n. Measured: k 3 of
n 10 fair flips sums its eight symmetric tail cells to 0.34375, the
center k 5 admits every cell and returns exactly 1, the pmf of 2
heads in 5 flips is 0.3125, and invalid arguments hand back NaN
rather than a zero that reads as certainty.

The auc is one sort, never the $O(n^2)$ pair loop the definition
suggests: midranks once, every tie sharing the average of the ranks
it spans so a tie is worth exactly half a win, then
$U = R^+ - n_1 (n_1 + 1)\/2$ over $n_1 n_0$, the Mann-Whitney identity:

#listing("interview-repertoire/samples/ch27-go/ranks.go", first: 13, last: 66, caption: [ties share their average rank, the positives' rank sum becomes the auc in one line])

The toy the tests pin: positives 0.2 and 0.4 against negatives 0.1
and 0.3, three of four cross pairs concordant, auc 0.75. A sample
holding one class only has no cross pair, the concordance is
undefined, and 0.5 is the only honest number to say out loud. The
property test is the punchline the interview wants: 300 seeded cases
with quantized scores forcing heavy ties, the midrank auc matching
the brute-force pair loop to the last bit, #xref-to("kdd", "roc")
for the curve the number summarizes.

The bootstrap is deterministic or it cannot be pinned: a PCG stream
seeded (seed, seed), a callback metric over row indices, one buffer
reused across replicates, nearest-rank percentiles:

#listing("interview-repertoire/samples/ch27-go/boot.go", first: 21, last: 46, caption: [the resample loop, the reused index buffer, the nearest-rank readout])

Pinned from a real run: 4000 resamples of a 12-row sample summing to
56, mean 4.67, seed 7, return the 95 percent interval [3, 6.833],
and the same seed replays it byte-identical forever, which is the
only reason a test may pin an interval at all. The reused buffer
carries the contract a range variable carries: look, do not retain.

The verdicts, holm's step-down against benjamini-hochberg's step-up:

#listing("interview-repertoire/samples/ch27-go/multiple.go", first: 18, last: 53, caption: [descending bars that stop the family at the first miss, ascending bars that keep the largest k])

Measured on the triple (0.01, 0.03, 0.04) at level 0.05: holm
rejects one, the first bar alpha over m clearing 0.01 and the second
alpha over 2 stopping the family at 0.03, while bh rejects all three,
0.04 clearing the last bar q itself. Same family, opposite verdict
counts, and the contrast is the answer to which one to use,
family-wise control for proof, false discovery for triage,
#xref-to("kdd", "fdr"). A p-value outside [0,1] or NaN panics both
walks on sight: an input shaped like a probability that is not one
deserves the loud failure now, not a quietly wrong verdict set later.
The production version of this whole workspace runs the user's mined
dota-helper engine, #xref-to("go", "numstats").

#diagram([descending holm bars stop the family at the first miss, ascending bh bars clear all three], length: 13pt, {
  // both panels share the sorted p dots 0.01, 0.03, 0.04 against their bars
  let panel(cx, title, bars, verdicts) = {
    cdraw.content((cx + 3.4, 10.0), [#title], size: 6.5pt)
    let ps = (0.01, 0.03, 0.04)
    for r in range(3) {
      let y = 8.7 - r * 1.3
      cdraw.line((cx, y), (cx + 6.6, y), stroke: luma(225))
      cdraw.line((cx, y), (cx + bars.at(r) / 0.05 * 6.2, y), stroke: luma(60))
      cdraw.circle((cx + ps.at(r) / 0.05 * 6.2, y), radius: 0.13, fill: luma(30), stroke: none)
      cdraw.content((cx + 6.2, y), [#ps.at(r)], size: 6pt)
      cdraw.content((cx + 7.9, y), verdicts.at(r), size: 6pt)
    }
  }
  panel(0.2, [holm, step-down], (0.05 / 3, 0.05 / 2, 0.05), ([reject 0.01], [stop the family], [not rejected]))
  panel(12.6, [bh, step-up], (0.05 / 3, 2 * 0.05 / 3, 0.05), ([reject 0.01], [reject 0.03], [reject 0.04, largest k = 3]))
  cdraw.content((10.5, 2.6), [the dot is the ordered p, the bar is what it must clear], size: 6pt)
  cdraw.content((10.5, 1.6), [holm's bars loosen downward and stop, bh's rise and keep the largest k], size: 6pt)
})

== backtesting without lookahead [DRILL]

The claim a backtest makes is that the score knew the outcome before
the outcome existed, and every leakage bug is some version of the
score reading the future. The discipline is one sentence: at event i
the model may read the state built from strictly earlier events, and
nothing at or after i. The dota-helper engine's replay walker mines
this exactly, #xref-to("go", "fitting"): each draft is walked in
pick order, the state before pick i splits into same-side allies,
opposing enemies, and the taken list covering picks and bans, all of
it built from the events before i and nothing else, and each pick is
then scored against the alternatives that state left available. The
future of the draft is exactly the part of the file the walker must
never open.

Why shuffle-split leaks on temporal data, said plainly: a random
split scatters tomorrow's rows into the training set, so the model is
fitted on the very distribution it is graded against, and adjacent
drafts share players, metas, and patches, so row-level randomness
hands the test set a near twin of every train row. K-fold is the
same leak repeated k times, every row serving as both teacher and
exam. The repairs, in the order the question wants them: split by
time, fit strictly on the past and score strictly on the future, one
pass; when entities repeat, split by entity, never by row; and when
edges or thresholds are fitted, fit them on train and freeze them
before the holdout is touched, the engine's calibration being decile
edges fitted on train scores with the holdout bins expected to form a
monotone ladder.

#diagram([the cursor at pick i reads everything strictly earlier, the file below it stays closed], length: 13pt, {
  // a row of five pick events, the first two shaded as readable, the cursor, the rest dashed as the future
  let ev(x, lab, readable) = {
    cdraw.rect((x - 0.65, 6.4), (x + 0.65, 7.6), fill: if readable { luma(205) } else { luma(248) }, stroke: if readable { luma(60) } else { (paint: luma(150), dash: "dashed") }, radius: 0.02)
    cdraw.content((x, 7.0), [#lab], size: 6pt)
  }
  for i in range(5) { ev(1.6 + i * 1.9, [#(i + 1)], i < 2) }
  cdraw.line((4.45, 5.4), (4.45, 8.4), stroke: luma(20))
  cdraw.content((4.45, 4.9), [pick i], size: 6.5pt)
  cdraw.content((2.4, 3.6), [allies, enemies, taken: built from events 1..i-1], size: 6pt)
  cdraw.content((8.6, 3.6), [the draft's outcome lives here, unopened], size: 6pt)
  cdraw.content((5.5, 2.4), [state at i = strictly earlier events, nothing else], size: 6pt)
})

The follow-up traps, named before they arrive. "The holdout improved
on the second look" is the holdout spent: each consult leaks one
decision back into the fitting, and the honest protocol touches the
holdout once, at the end. "We tuned on the backtest data" is the
first leak with a dashboard on it. "Shuffle the drafts and the
scores barely move" is the confession, because shuffling destroys
exactly the temporal structure deployment will respect, and a score
indifferent to it was never reading time at all. The promotion guard
in the next section is what the honest numbers knock on.

== guarded promotion and multiple testing in a game tool [DRILL]

The scene: a tool screens hero cells by the hundred, each promising a
win-rate lift, and every promise wants to rewrite the live config.
The guard the dota-helper engine runs, #xref-to("go", "fitting"),
is four doors, and every door is checked before any file is opened
for writing. Door one, the proposal carries a sane finite weight
vector, NaN and both infinities refused on sight because a NaN fails
every comparison silently. Door two, the baseline the gain was
measured against still equals the live weights, a config that moved
since making the numbers stale and sending the candidate back to
refit. Door three, the holdout gain clears the floor. Door four, the
bootstrap interval's low end sits strictly above 0, a mean gain that
could be zero being no gain at all, the same interval the workspace
above pins. Any refusal leaves the config bytes identical, and the
proof is a byte comparison, not a promise.

#diagram([four doors, every check before the write, any refusal leaves the bytes identical], length: 13pt, {
  // four door cells in a row, the refusal line under each, the untouched config bar at the bottom
  let door(x, name, refuse) = {
    cdraw.rect((x, 6.2), (x + 5.0, 8.2), fill: luma(238), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 2.5, 7.55), [#name], size: 6.5pt)
    cdraw.content((x + 2.5, 6.7), refuse, size: 6pt)
  }
  door(0.0, [1 finite], [NaN or inf: refuse])
  door(5.2, [2 baseline], [stale: refit])
  door(10.4, [3 gain floor], [under floor: refuse])
  door(15.6, [4 ci above 0], [ci low at 0: refuse])
  cdraw.rect((0.0, 3.6), (20.6, 4.7), fill: luma(205), stroke: luma(60), radius: 0.02)
  cdraw.content((10.3, 4.15), [the live config, rewritten only when all four doors open], size: 6pt)
  cdraw.content((10.3, 2.5), [a refusal proves itself as identical bytes, not as a message], size: 6pt)
})

Multiple testing is why the knock list is short. Screen 200 cells at
0.05 and the all-null expectation alone hands you 10 false
discoveries, m times alpha, the scenario the statistics drill carries
at 20 tests through the complement, 1 - 0.95^20. Family-wise control,
bonferroni and holm, prices
the whole family's false-rejection risk down to 0.05 and prices true
discoveries out of the market too: the workspace's measured triple
keeps only 1 of its 3 bh rejections under holm. False-discovery
control keeps the rejections and bounds their false share instead,
the right currency when the screen is a triage and every survivor
gets a human look, #xref-to("kdd", "fdr"). The composition the
question is fishing for: fdr trims the candidate list, the backtest
prices the survivor, and the four doors decide whether the config
opens at all.

floored to the math handbook and its exact-arithmetic gates:
#xref-to("math", "proof") for the pigeonhole and induction habits,
#xref-to("math", "combinatorics") for the sum and product rules,
the binomial ladder, and inclusion-exclusion with the derangements,
#xref-to("math", "probability") for spaces, conditioning, and
expectations, #xref-to("math", "statistics") for hypothesis tests,
estimators, and baselines, with #xref-to("dsa", "analysis") owning
the cost-claim reading and #xref-to("dsa", "numtheory") the
halving recurrence behind exponentiation by squaring, and the
computed half floored further to #xref-to("kdd", "hypothesis") and
#xref-to("kdd", "roc") behind the workspace's exact test and auc,
#xref-to("kdd", "fdr") behind its verdicts, and #xref-to("go",
"numstats") where the same machinery runs mined engine data. Drill
numbers are textbook values, the workspace's own numbers measured.
