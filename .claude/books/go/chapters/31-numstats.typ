#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= numerical statistics in go

The service part taught one program against one database. The data part
teaches the numbers a program computes about itself, and its case study is
the user's own dota-helper engine, a tool that screens hundreds of hero
and item pairs for win-rate effects and has to decide which of those
effects are real. Every idea in this chapter runs there in production:
the exact binomial tail, the 2x2 chi-square with its fallback gate, the
Mann-Whitney AUC, Spearman correlation, a deterministic bootstrap, and
the Holm and Benjamini-Hochberg corrections. Here they are rebuilt as
`godata/internal/stats`, a second module beside the api, stdlib only, and
the same math the kdd book derives in c, #xref-to("kdd", "hypothesis")
and #xref-to("kdd", "fdr") for the theory and this chapter for the go:

#listing("go/data/go.mod", first: 1, last: 3, caption: [the data part's module, stdlib only by the same ruling as the api])

== why a game tool needs exact numbers

A win-rate screen is a family of tests, not a test. Five hundred hero
pairs scored at the conventional 0.05 bar will cross it on noise alone
about 25 times, one in twenty, because that is what the bar means. The
tool that reports those 25 as discoveries is not lying about its
arithmetic, it is asking the wrong question: the family needs a
correction before any single p-value means anything. The measured version
of the paragraph is a test in this package: a null family of 200 uniform
p-values drawn from a pinned PCG stream crosses the 0.05 bar exactly 10
times, 5 percent on the nose, the smallest crossing sitting at 0.0124 far
above the Bonferroni bar 0.00025, and neither correction rejects
anything. The screen works, and the chapter builds it bottom up so every
number in it is one a test asserted first.

#diagram([expected false positives against family size at the 0.05 bar, with the measured null family], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [tests in the family], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.2, 7.6), [crossings], size: 6pt)
  // the 0.05 line: 10 tests -> 0.5, 200 -> 10, 500 -> 25
  cdraw.line((0.6, 0.7), (22.6, 6.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((13.6, 5.7), [one crossing per twenty tests, on noise], size: 6pt)
  let mark(x, n, c) = {
    cdraw.circle((x, 0.7 + (x - 0.6) / 22.0 * 6.0), radius: 0.28, fill: luma(160))
    cdraw.content((x, 0.7 + (x - 0.6) / 22.0 * 6.0 + 0.85), [#n tests: #c], size: 6pt)
  }
  mark(5.0, [10], [0.5])
  mark(10.4, [200], [10])
  mark(18.6, [500], [25])
  pane(1.6, 8.8, 7.0, [the measured point], [200 pinned uniforms, 10 crossings])
  cdraw.content((9.0, -0.4), [the family is the unit of decision, never the single p-value], size: 6pt)
})

== the binomial in log space

The workhorse question is does this count surprise this rate: 8 wins of
10 engagements against a 50 percent baseline. The binomial pmf answers
it, and the only decision in its implementation is where the arithmetic
lives. `100!` overflows an int64 and its float approximation loses the
digits that matter, so the cell is evaluated entirely in log space, each
factorial through `math.Lgamma`, and exponentiated once at the end. The
one subtlety left over is the point masses: `p` 0 and 1 collapse the
distribution to a single cell, and `Log(0)` is `-Inf`, so those cases
short-circuit before the logarithms:

#listing("go/data/internal/stats/binomial.go", first: 28, last: 50, caption: [the pmf cell in log space: lgamma factorials, one Exp at the end])

Both exact tails are sums of cells. The one-sided tail `P(X >= k)` adds
the cells from `k` up, no normal approximation anywhere near it: for the
8-of-10 question that is `(45+10+1)/1024`, `7/128`, Pascal's row read
straight off. The two-sided tail is the point-probability method, the
same one the kdd book derives, #xref-to("kdd", "hypothesis"): the bar is
the observed cell's own mass, 45/1024 here, and the p-value is the total
mass of every cell at most as likely, the set {0,1,2,8,9,10} summing to
`7/64`, both tails collected by likelihood rather than by any distance
from a mean. The relative `tieTol` keeps a cell that ties the bar to
within an ulp inside the region:

#listing("go/data/internal/stats/binomial.go", first: 70, last: 82, caption: [the point-probability two-sided tail: cells at most as likely as the observed one])

Both sums leave through `clampProb`, and the clamp is not decoration. A
sum of cells that is 1 in exact arithmetic accumulates rounding error
like any other float sum, and the full row for `n = 141` fair flips
lands at `1.0000000000000713`, seven times ten to the minus fourteenth
past the bound. A p-value above 1 is not a p-value, and the BH step-up
in the last section compares every cell against its bar, so an
unclamped tail would poison the family. The test pins the overshoot on
real input, then the clamp:

#listing("go/data/internal/stats/binomial.go", first: 84, last: 100, caption: [the clamp, no tolerance: the excess is accumulation artifact, never probability])

#listing("go/data/internal/stats/binomial_test.go", first: 140, last: 153, caption: [the overshoot demonstrated, not assumed: the raw row past 1, the tail exactly 1])

#diagram([the n = 10 fair-coin pmf, with the two-sided region of k = 8 shaded], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.line((0.6, 0.7), (0.6, 8.2), stroke: luma(120))
  cdraw.content((0.6, 8.4), [cell mass], size: 6pt)
  // Pascal row 1,10,45,120,210,252,210,120,45,10,1 over 1024, scaled
  let hs = (0.04, 0.29, 1.27, 3.37, 5.9, 7.05, 5.9, 3.37, 1.27, 0.29, 0.04)
  let region = (0, 1, 2, 8, 9, 10)
  for (k, h) in hs.enumerate() {
    let x = 1.0 + k * 2.05
    let in-region = region.find(r => r == k) != none
    cdraw.rect((x, 0.7), (x + 1.6, 0.7 + h), fill: luma(if in-region { 120 } else { 220 }), radius: 0.02)
    cdraw.content((x + 0.8, 0.35), [#k], size: 6pt)
  }
  cdraw.line((0.9, 1.97), (23.0, 1.97), stroke: luma(150), dash: "dashed")
  cdraw.content((22.8, 2.5), [bar 45/1024], size: 6pt)
  cdraw.content((4.4, 4.6), [cells at most as], size: 6pt)
  cdraw.content((4.4, 3.6), [likely as k = 8], size: 6pt)
  cdraw.content((16.6, 5.4), [unshaded cells are], size: 6pt)
  cdraw.content((16.6, 4.4), [more likely: excluded], size: 6pt)
  cdraw.content((11.6, 8.6), [shaded total 112/1024 = 7/64], size: 6pt)
})

== the 2x2 chi-square and its floor

Two counting questions share one shape: wins and losses under two
conditions, a 2x2 table. The chi-square test of independence scores the
table against the counts the marginals imply, expected `row*col/n` per
cell, and with one degree of freedom the upper tail closes as
`erfc(sqrt(stat/2))`, which is why the NIST critical 3.8415 sits exactly
at p 0.05: it is z 1.96 squared, and the erfc form is the two-sided
normal tail in disguise. A hand table keeps the arithmetic visible:
observed `(15, 10, 10, 15)` against expected 12.5 per cell is four
deviations of 2.5, a statistic of exactly 2, and p = `erfc(1)` = 0.1573,
independence standing:

#listing("go/data/internal/stats/chisq.go", first: 21, last: 41, caption: [expected counts from marginals, the df=1 erfc tail, and the floor gate on ok])

The third return value is the honest part. The chi-square statistic is an
approximation, and the classic guidance is to trust it only when every
expected count reaches 5; the function carries that as `ok` instead of
deciding silently, and the caller falls back to the exact binomial tail
of the previous section when it is false. The independence table
`(2,2,2,2)` scores a perfectly ordinary statistic, 0, and still answers
`ok = false` with expected counts of 2: the gate refuses the
approximation, not the data. A negative count, a NaN, an infinity, a
zero total, or a zero row or column leaves some expected count at a
structural zero or no count at all, and the answer is the math package's
`(NaN, NaN, false)`:

#diagram([the fallback decision: the gate on expected counts routes the table to the approximation or the exact tail], length: 13pt, {
  cdraw.content((11.5, 8.6), [a 2x2 table of counts], size: 6.5pt)
  cdraw.line((11.5, 8.3), (11.5, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.3, 6.2), (14.7, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.9), [expected = row*col/n], size: 6pt)
  cdraw.line((11.5, 6.1), (11.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.3, 3.8), (15.7, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 4.6), [every expected count >= 5?], size: 6pt)
  cdraw.line((9.0, 3.7), (4.6, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.0, 3.7), (18.4, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.6, 3.3), [yes], size: 6pt)
  cdraw.content((17.6, 3.3), [no], size: 6pt)
  pane(1.0, 8.6, 2.3, [chi-square p], [erfc(sqrt(stat/2))], [3.8415 <-> 0.05])
  pane(14.6, 22.6, 2.3, [exact binomial], [the log-space tail], [no approximation to refuse])
  pane(1.0, 8.6, 7.6, [the refused inputs], [negative or NaN, zero total, zero margin], [(NaN, NaN, false)])
  cdraw.content((11.5, 1.2), [ok is a fact about the test], size: 6pt)
  cdraw.content((11.5, 0.3), [not a verdict about the data], size: 6pt)
})

== midranks, the shared tie primitive

Every rank-based statistic in this package answers the same question
first: where does each value place, and what happens when values tie.
The package answers it once. `midranks` sorts positions, walks the tie
groups, and hands each group the mean of the rank span it covers, so
{7, 1, 7, 7, 2} ranks as 4, 1, 4, 4, 2, the three sevens sharing the
mean of ranks 3, 4, and 5. The AUC's half credits, Spearman's tie
blocks, and the percentile positions below all flow through this one
function, which is why tie policy is decided in one place instead of
four quietly different ones:

#listing("go/data/internal/stats/rank.go", first: 15, last: 39, caption: [positions sorted by value, each tie group assigned its mean rank])

One consumer deserves its eight lines. Percentile normalization maps
each midrank to the plotting position `(r - 1/2)/n`, ties sharing one
position, {1, 2, 2, 3} landing at 0.125, 0.5, 0.5, 0.875. The half
offset is the whole point: every output stays strictly inside (0, 1), so
an inverse-normal transform of the positions, the normal scores the
regression chapter will want, never asks for `+Inf` at the extremes:

#listing("go/data/internal/stats/rank.go", first: 45, last: 52, caption: [the plotting position: midranks over n, half-offset inside (0,1)])

#diagram([one tie group under integer ranks and under midranks], length: 13pt, {
  cdraw.content((5.8, 8.2), [integer ranks], size: 6.5pt)
  cdraw.content((17.6, 8.2), [midranks], size: 6.5pt)
  let vals = ([1], [2], [2], [3])
  let naive = ([1], [2], [3], [4])
  let mid = ([1], [2.5], [2.5], [4])
  for i in range(4) {
    cdraw.content((5.8, 7.0 - i * 1.3), vals.at(i), size: 6.5pt)
    cdraw.content((3.4, 7.0 - i * 1.3), naive.at(i), size: 6pt)
    cdraw.content((17.6, 7.0 - i * 1.3), vals.at(i), size: 6.5pt)
    cdraw.content((15.2, 7.0 - i * 1.3), mid.at(i), size: 6pt)
  }
  // the tie pair: two ranks on the left, one shared rank on the right
  cdraw.line((3.0, 5.75), (3.0, 4.45), stroke: luma(150))
  cdraw.line((2.8, 5.75), (3.2, 5.75), stroke: luma(150))
  cdraw.line((2.8, 4.45), (3.2, 4.45), stroke: luma(150))
  cdraw.line((13.6, 5.1), (14.6, 5.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.8, 1.6), [the tie pair splits 2 and 3], size: 6pt)
  cdraw.content((17.6, 1.6), [the pair shares 2.5], size: 6pt)
  pane(9.6, 23.0, 0.4, [why one primitive], [auc half credits], [spearman tie blocks], [percentile positions], [one tie policy, not four])
})

== auc as a rank statistic

A backtest scores rows and wants to know if the scores order the wins
above the losses. The area under the ROC curve is the concordance
fraction: the share of positive-negative pairs where the positive
outscores the negative, a tie worth 1/2. Computing that as a pair loop
is O(n^2) and a 20k-row backtest pays for it; computing it as the
Mann-Whitney U statistic is O(n log n), one midrank pass plus one sum,
`U = R+ - n1(n1+1)/2` over `n1*n0`, and the ties resolve themselves
because the midranks already averaged them. The chapter fixture is six
scores, three positives against three negatives, one positive losing:
six concordant pairs of nine, AUC = 2/3:

#listing("go/data/internal/stats/auc.go", first: 13, last: 36, caption: [the Mann-Whitney U over midranks: one sort, one sum, no pair loop])

The degenerate cases are contracts, not afterthoughts. A sample with
only one class has no cross-class pair and the concordance is undefined;
the API answers the 0.5 chance line, the value that claims no
information, and the empty sample is that same case. Length-mismatched
slices are a caller bug and panic, the loud failure the emit layer of
the case study settled on too. The property tests carry the weight: the
rank form is checked against the O(n^2) definition it replaces on tied
random data, five trials of 200 rows, and flipping every label reflects
the curve through the chance diagonal, `AUC + AUC' = 1` to the last bit
on 300 rows:

#diagram([the fixture's roc curve: a step per threshold, area 2/3 over the chance diagonal], length: 13pt, {
  // axes: fpr 0..1 over x 0.8..15.8, tpr 0..1 over y 0.7..7.7
  cdraw.line((0.8, 0.7), (15.8, 0.7), stroke: luma(120))
  cdraw.content((12.0, 0.1), [false positive rate], size: 6pt)
  cdraw.line((0.8, 0.7), (0.8, 8.0), stroke: luma(120))
  cdraw.content((0.4, 8.2), [true positive rate], size: 6pt)
  // chance diagonal
  cdraw.line((0.8, 0.7), (15.8, 7.7), stroke: luma(190), dash: "dashed")
  cdraw.content((13.6, 6.3), [chance], size: 6pt)
  // thresholds descending 0.9P 0.8N 0.7P 0.6N 0.5P 0.1N: the curve steps
  // up on a positive, right on a negative, one third per score
  cdraw.line((0.8, 0.7), (0.8, 3.03), stroke: luma(60))
  cdraw.line((0.8, 3.03), (5.8, 3.03), stroke: luma(60))
  cdraw.line((5.8, 3.03), (5.8, 5.37), stroke: luma(60))
  cdraw.line((5.8, 5.37), (10.8, 5.37), stroke: luma(60))
  cdraw.line((10.8, 5.37), (10.8, 7.7), stroke: luma(60))
  cdraw.line((10.8, 7.7), (15.8, 7.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.3, 2.1), [0.9 clears all three], size: 6pt)
  cdraw.content((8.3, 4.4), [0.7 clears 0.6 and 0.1], size: 6pt)
  cdraw.content((13.3, 6.8), [0.5 clears 0.1 only], size: 6pt)
  cdraw.content((12.4, 4.3), [area 6/9], size: 6pt)
  cdraw.content((12.4, 3.4), [two thirds], size: 6pt)
  pane(16.6, 23.2, 3.0, [the same area as], [the concordance], [fraction, ties 1/2], [kdd ch 18 derives it])
  cdraw.content((9.0, -0.4), [one discordant pair of nine: the positive 0.5 sits under the negative 0.6], size: 6pt)
})

== spearman, pearson on ranks

The correlation the backtest wants is between ordinals, win-rate
movement against pick-order movement, and the Pearson correlation of raw
values would let one runaway match dominate. Spearman is Pearson run on
the midranks instead: monotone input gives exactly +-1 whatever the
values, a tie block is averaged once by the shared primitive, and the
whole function is the familiar three sums over rank deviations. Constant
input on either side has zero rank variance, 0 over 0, and returns NaN
the way the math package answers its own degenerate cases, and the
length mismatch panics like AUC's:

#listing("go/data/internal/stats/rankcorr.go", first: 12, last: 36, caption: [Pearson's three sums over midranks: sxy over sqrt(sxx*syy)])

The hand-worked tie block keeps the function honest. For xs {10, 20,
30, 40} against ys {7, 5, 7, 9}, the ys rank as 2.5, 1, 2.5, 4, the rank
deviations are dx -1.5, -0.5, 0.5, 1.5 against dy 0, -1.5, 0, 1.5, and
the three sums land at `sxy = 3`, `sxx = 5`, `syy = 4.5`, a correlation
of `3/sqrt(22.5) = sqrt(2/5)`, all asserted bit for bit in the test. The
exact +-1 on monotone input is the same discipline: squares, square
roots, any strictly monotone map of xs correlates at 1, because ranks
are invariant under monotone maps and the test says so:

#diagram([values versus ranks: a nonlinear monotone pair flattens to the diagonal], length: 13pt, {
  cdraw.content((5.8, 8.4), [values, y = x squared], size: 6.5pt)
  cdraw.content((17.6, 8.4), [midranks], size: 6.5pt)
  // left: (1,1) (2,4) (3,9) (4,16) (5,25) scaled, kept below the pane
  cdraw.line((0.8, 0.9), (11.0, 0.9), stroke: luma(120))
  cdraw.line((0.8, 0.9), (0.8, 4.1), stroke: luma(120))
  let sx = 9.6 / 5.0
  let sy = 0.11
  for i in range(5) {
    cdraw.circle((1.2 + i * sx, 1.1 + (i * i) * sy), radius: 0.26, fill: luma(120))
  }
  cdraw.content((4.0, 0.35), [curved, but climbing], size: 6pt)
  // right: ranks 1..5 against 1..5 on the diagonal
  cdraw.line((12.6, 0.9), (22.8, 0.9), stroke: luma(120))
  cdraw.line((12.6, 0.9), (12.6, 7.8), stroke: luma(120))
  cdraw.line((12.8, 1.1), (22.4, 7.4), stroke: luma(60))
  for i in range(5) {
    cdraw.circle((12.8 + i * 2.4, 1.1 + i * 1.575), radius: 0.26, fill: luma(120))
  }
  cdraw.content((18.6, 6.6), [exactly the diagonal], size: 6pt)
  pane(0.8, 11.0, 7.6, [the lesson], [spearman 1, pearson under 1])
  cdraw.content((15.4, -0.2), [ranks are invariant under monotone maps], size: 6pt)
})

== the deterministic bootstrap

A p-value says an effect is there; a confidence interval says how big.
The percentile bootstrap builds one without any distributional assumption
about the metric: resample the rows with replacement, recompute the
metric on each replicate, read the interval off the sorted replicates at
the chosen percentiles. The go decision is that the resample must be
reproducible, so the stream is a PCG generator from `math/rand/v2`
seeded `(seed, seed)`, and the same seed replays a byte-identical
interval, which turns any pinned interval into a permanent regression
case. The metric arrives as a callback over a row-index slice, one
buffer reused across replicates with a documented must-not-retain
contract, the same shape a range loop's variable carries:

#listing("go/data/internal/stats/bootstrap.go", first: 21, last: 36, caption: [the resample loop: PCG stream, reused index buffer, sorted replicates])

The determinism test is the chapter's insurance policy: 80 uniforms from
one pinned stream, resampled 200 times at seed 7, must return
`(0.46601909707261074, 0.58610135085900195)` to the last bit on every
run, and seed 8 must move it:

#listing("go/data/internal/stats/bootstrap_test.go", first: 25, last: 43, caption: [the pinned interval: full-precision equality, the seed is the only input])

The percentiles are nearest-rank, the `ceil(p/100 * m)`-th smallest,
clamped so 0 picks the minimum and 100 the maximum. The order of
operations is load-bearing: the product `pct*m` is formed before the
`/100`, so a dyadic percent with an exact integer rank, 2.5 percent of
400 resamples, lands on the 10th smallest instead of one ulp above it
and silently the 11th. Each replicate draws n of n rows with
replacement, so on average `1 - 1/e`, 63.2 percent, of the rows appear
in a given replicate and the rest stay out of the bag; the measured
first replicate at seed 1 over 500 rows touches 315 distinct rows, 63.0
percent, the same out-of-bag arithmetic the kdd evaluation chapter
teaches, #xref-to("kdd", "evaluation"):

#diagram([the resample loop as a pipeline, determinism and buffer reuse pinned], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [rows, n], [the sample])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(5.9, [pcg (seed, seed)], [n draws with replacement])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.5, [metric(idx)], [one reused buffer])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.1, [sort, percentile], [nearest-rank lo, hi])
  pane(0.3, 11.2, 3.2, [determinism], [same seed, same bytes], [any pin is a regression case])
  pane(12.4, 23.2, 3.2, [out of bag], [315 of 500 distinct], [1 - 1/e = 63.2 percent])
  cdraw.content((11.5, 1.4), [the callback must not retain idx, the next replicate overwrites it], size: 6pt)
})

== correcting the family

Back to the opening number: the family is the unit of decision. Two
classical corrections answer two different questions about it. Holm
1979 controls the family-wise error rate, the chance of even one false
rejection: sort the p-values ascending, walk them against descending
bars `alpha/(m-k+1)`, reject while each ordered p stays at or under its
bar, and the first miss stops the family. Its first bar is `alpha/m`,
plain Bonferroni, and the walk only loosens from there. Benjamini and
Hochberg 1995 control the false discovery rate, the expected share of
rejections that are wrong: the bars ascend as `(k/m)*q`, and the answer
is the largest k whose p clears its bar, all k hypotheses below it
rejected. One conservative guarantee about any mistake, one
proportional guarantee about the mistake rate, and the verdicts come
back in input order either way:

#listing("go/data/internal/stats/multiple.go", first: 18, last: 30, caption: [Holm: step-down, the first miss stops the family])

#listing("go/data/internal/stats/multiple.go", first: 38, last: 53, caption: [BH: step-up, the largest clearing k rejects below it])

A four-hypothesis family shows why a tool needs both. At alpha 1/20,
the sorted ps (0.01, 0.02, 0.03, 0.04): Holm's second bar is 1/60, about
0.0167, and 0.02 misses it, so exactly one hypothesis survives, while
BH's fourth bar is 1/20 and 0.04 clears it, so all four do. Three of
four verdicts differ. The boundary family in the tests sharpens the
rule: at Holm's k = 3 the bar is `(1/20)/2 = 1/40` and the p is exactly
`1/40`, equal to the last bit because halving a rounded double is exact,
and the rule's `<=` decides the row, reject:

#listing("go/data/internal/stats/multiple_test.go", first: 10, last: 29, caption: [the contrast family: Holm one of four, BH four of four, derivation in the comments])

The input policy is a panic, and the panic is the interesting part:

#listing("go/data/internal/stats/multiple.go", first: 68, last: 82, caption: [validateFamily: a p-value is a probability, and the caller has no error channel])

#callout("note", "NaN answers and panic answers", [
  This package returns NaN for a chi-square table with a zero margin and
  panics for a p-value of 1.5. Both are right. The zero-margin table is
  bad data, an answer of no-information in the math package's own
  idiom. The out-of-range p-value is a caller bug: a probability-shaped
  argument that is not a probability has no sane interpretation to
  return, an error return would be ignored at a screen site, and a loud
  failure at the call beats a quietly wrong verdict set in production.
])

#diagram([the contrast family under both bar ladders: step-down stops early, step-up clears all four], length: 13pt, {
  cdraw.line((0.8, 0.8), (22.8, 0.8), stroke: luma(120))
  cdraw.content((23.0, 0.8), [p-value], size: 6pt)
  cdraw.line((0.8, 0.8), (0.8, 7.8), stroke: luma(120))
  cdraw.content((0.4, 8.0), [bar], size: 6pt)
  // k = 1..4, x spaced; holm bars descend, bh bars ascend
  let ks = (3.2, 8.2, 13.2, 18.2)
  let ps = (0.01, 0.02, 0.03, 0.04)
  let holm = (0.0125, 0.0167, 0.025, 0.05)
  let bh = (0.0125, 0.025, 0.0375, 0.05)
  let sc = 6.4 / 0.05
  for i in range(4) {
    cdraw.circle((ks.at(i), 0.8 + ps.at(i) * sc), radius: 0.24, fill: luma(60))
    cdraw.content((ks.at(i), 0.35), [#(i + 1)], size: 6pt)
    // the holm bar as a gray column, the bh bar as a black tick above it
    cdraw.rect((ks.at(i) - 0.3, 0.8), (ks.at(i) + 0.3, 0.8 + holm.at(i) * sc), fill: luma(225), radius: 0.02)
    cdraw.line((ks.at(i) - 0.55, 0.8 + bh.at(i) * sc), (ks.at(i) + 0.55, 0.8 + bh.at(i) * sc), stroke: luma(60))
  }
  cdraw.content((10.2, 0.8 + 0.02 * sc + 1.6), [holm stops], size: 6pt)
  cdraw.content((10.2, 0.8 + 0.02 * sc + 0.9), [0.02 over 1/60], size: 6pt)
  cdraw.content((18.2, 0.8 + 0.04 * sc - 0.9), [bh k\* = 4: 0.04], size: 6pt)
  cdraw.content((18.2, 0.8 + 0.04 * sc - 1.6), [under 1/20], size: 6pt)
  pane(1.2, 7.2, 7.6, [the family, m = 4], [holm gray, down], [bh black, up])
})

== the screening chain

The parts now compose into the case study's spine. The engine hands the
package raw pair counts; each pair becomes a 2x2 table; the chi-square
scores it fast and its gate routes thin tables to the exact binomial
tail; the survivors' p-values enter Holm or BH as one family, and the
tool chooses BH because a game balance tool prefers a bounded share of
false leads over a guarantee of none, a hundred candidate buffs is a
worklist, not a publication; the survivors' effect sizes then get
bootstrap intervals, the deterministic kind, so a pinned run replays
byte for byte; and the shrinkage step the next chapter builds keeps the
screened effects from overfitting their own noise. Significance
screens, correction prunes, intervals size, shrinkage stabilizes, in
that order, because each stage's output is the next stage's contract:

#snippet("ps := make([]float64, 0, len(pairs))\nfor _, p := range pairs {\n\tif _, pv, ok := stats.ChiSquare2x2(p.W, p.L, p.CW, p.CL); ok {\n\t\tps = append(ps, pv)\n\t} else {\n\t\tps = append(ps, stats.BinomialOneSided(p.W, p.W+p.L, 0.5))\n\t}\n}\nfor i, keep := range stats.BH(ps, 0.05) {\n\tif keep {\n\t\tpairs[i].CI = stats.PercentileCI(pairs[i].Effect, len(rows), 400, pairs[i].Seed, 2.5, 97.5)\n\t}\n}", lang: "go")

The kdd book owns the derivations this chapter compiled: the
point-probability tail and the p-value grammar in
#xref-to("kdd", "hypothesis"), the roc curve and the Mann-Whitney
identity in #xref-to("kdd", "roc"), the bootstrap and its out-of-bag
third in #xref-to("kdd", "evaluation"), and the correction theory, both
ladders and their guarantees, in #xref-to("kdd", "fdr"). What go adds
is the engineering: log space where factorials would overflow, one tie
primitive where four statistics would each invent one, a seeded PCG
where a flaky test suite would live, and a panic where a wrong verdict
set would ship.

#diagram([the screening chain: each stage's output is the next stage's contract], length: 13pt, {
  let stage(x0, w, title, l1) = {
    cdraw.rect((x0, 5.0), (x0 + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.6), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 5.6), [#l1], size: 6pt)
  }
  stage(0.3, 4.6, [pair counts], [w/l tables])
  cdraw.line((5.1, 6.1), (5.5, 6.1), stroke: luma(100), mark: (end: ">>"))
  stage(5.5, 4.6, [exact tests], [chi-sq, binomial])
  cdraw.line((10.3, 6.1), (10.7, 6.1), stroke: luma(100), mark: (end: ">>"))
  stage(10.7, 4.6, [holm / bh], [the family verdicts])
  cdraw.line((15.5, 6.1), (15.9, 6.1), stroke: luma(100), mark: (end: ">>"))
  stage(15.9, 4.0, [bootstrap ci], [seeded, pinned])
  cdraw.line((20.1, 6.1), (20.5, 6.1), stroke: luma(100), mark: (end: ">>"))
  stage(20.5, 2.8, [shrinkage], [next chapter])
  cdraw.content((11.6, 4.2), [significance screens, correction prunes], size: 6pt)
  cdraw.content((11.6, 3.4), [intervals size, shrinkage stabilizes], size: 6pt)
  cdraw.content((11.6, 2.6), [a game tool picks bh: a worklist, not a publication], size: 6pt)
  pane(0.3, 11.4, 2.0, [this chapter], [the tests and the corrections], [all stdlib])
  pane(13.6, 23.3, 2.0, [the data part's spine], [fit sizes, engine replays])
})

sources: pkg.go.dev/math for Lgamma, Erfc, Log1p, and the NaN idiom, and
pkg.go.dev/math/rand/v2 for the PCG source and its compatibility
guarantee, both read against the go 1.27 module cache, accessed
2026-09-30; Holm, a simple sequentially rejective multiple test
procedure, Scandinavian Journal of Statistics 6(2), pp 65-70, 1979, and
Benjamini and Hochberg, controlling the false discovery rate, Journal of
the Royal Statistical Society Series B 57(1), pp 289-300, 1995; the NIST
SEMATECH e-Handbook of Statistical Methods for the df=1 critical 3.8415,
accessed 2026-09-30; and the case study's own engine,
github.com/lavantien/dota-helper, whose internal stats package these
ideas were mined from. Verified by `go/data/internal/stats` tests, 48 of
them under `go vet`, `go test`, and the race detector, gofmt clean over
the module, every number in the prose pinned or banded by one of them.
