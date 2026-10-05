#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= fitting, backtesting, and guarded promotion

The mined tables hand over numbers, and the numbers are not equally
trustworthy: a cell built from 8 matches and a cell built from 800 carry
the same decimal places and wildly different evidence. This chapter builds
the loop that decides which numbers deserve to live in the config hub, in
`godata/internal/fit`: empirical-bayes shrinkage with its alpha measured
from the data rather than tasted in, low-rank matrix completion for the
thin cells, masked-cell cross-validation over a rank and ridge grid, two
comparators that exist to be beaten, a bagged blend fitted by coordinate
ascent, an order-aware replay backtest that cannot see the future, and a
promotion guard that refuses to rewrite a config file without a bootstrap
interval. The machinery is adapted from the dota-helper engine's eval and
analytics packages, rewritten against the chapter 31 stats package so
every statistic on these pages is one the corpus already owns.

== shrinkage toward a prior

A win rate observed n times is a beta posterior in disguise. The fair
prior says `p0`, the evidence says `w/n`, and the beta form blends them
with `a` pseudo-counts: the posterior is `(w + a p0)/(n + a)`, which is
the prior's `a` imaginary trials sitting next to the `n` real ones. Two
boundary checks fall out of the arithmetic. With no evidence the
posterior is exactly the prior, and as `n` grows past `a` the real trials
outvote the imaginary ones and the posterior closes in on the observed
rate. The mined tables store the displacement form, a cell's distance
from fair rather than a raw rate, so the same blend written as a delta
keeps only the `n/(n+a)` share of what was observed:

#listing("go/data/internal/fit/shrink.go", first: 5, last: 24, caption: [the beta blend and its displacement form, one posterior in two notations])

Shrinking the value is half the job. A cell also needs its uncertainty,
and the same alpha gives it: the per-trial sampling variance `sigma2`
scales by the squared shrink factor, so the posterior variance is
`sigma2 n/(n+a)^2`. The shape is the interesting part. It is 0 at `n = 0`
because the prior is certain of itself, it peaks at exactly `n = a`,
the one point where the observed delta and the prior carry equal weight,
and it falls back toward 0 as evidence piles up. The test pins all three
facts, including the peak value `sigma2/(4a)` at `n = a`:

#listing("go/data/internal/fit/shrink.go", first: 26, last: 37, caption: [posterior variance: the value says what to believe, this says how much])

#diagram([posterior paths from the prior to the evidence, one curve per alpha, the fair rate between them], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [evidence n, matches], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [posterior rate], size: 6pt)
  cdraw.line((0.6, 6.1), (23.2, 6.1), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 6.1), [prior p0], size: 6pt)
  cdraw.line((0.6, 1.6), (23.2, 1.6), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 1.6), [observed w/n], size: 6pt)
  // three alpha paths from (0, p0) to (large n, observed)
  cdraw.line((0.6, 6.1), (23.2, 1.9), stroke: luma(60))
  cdraw.content((3.4, 4.6), [a = 50], size: 6pt)
  cdraw.line((0.6, 6.1), (23.2, 2.8), stroke: luma(90))
  cdraw.content((8.6, 5.1), [a = 200], size: 6pt)
  cdraw.line((0.6, 6.1), (23.2, 3.9), stroke: luma(120))
  cdraw.content((15.2, 5.5), [a = 800], size: 6pt)
  // halfway point where observed weight is 1/2
  cdraw.circle((11.9, 4.5), radius: 0.26, fill: luma(160))
  cdraw.line((11.9, 4.5), (11.9, 0.7), stroke: luma(150), dash: "dashed")
  cdraw.content((11.9, 0.2), [n = a: half prior, half evidence], size: 6pt)
  pane(0.6, 8.6, 2.4, [small n cells], [8 matches look like noise], [the pull toward fair is the point])
  cdraw.content((18.6, 0.2), [a cell with n under its alpha is mostly prior], size: 6pt)
})

== the alpha the data chooses

Pseudo-counts beg the obvious question: how many? A number typed into a
config file is a taste with a decimal point, so the fit measures it. The
population variance of the observed deltas decomposes into true
between-cell spread `tau2` plus mean sampling noise `sigma2/n`, and the
alpha whose displacement shrink reproduces that split is `sigma2/tau2`.
When the spread is fully explained by sampling noise, `tau2` pins at 0,
alpha would be infinite, and the family keeps its current value: no
measurement should manufacture certainty out of variance. The estimator
is ten lines over the family's deltas and counts:

#listing("go/data/internal/fit/shrink.go", first: 39, last: 68, caption: [moment matching: spread minus sampling noise is tau2, and alpha is sigma2 over it])

#diagram([the variance decomposition: observed spread splits into real signal and sampling noise], length: 13pt, {
  cdraw.rect((1.0, 5.2), (22.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 6.9), [observed spread of the deltas], size: 6.5pt)
  cdraw.content((11.8, 5.9), [var(d_i) across the family], size: 6pt)
  cdraw.line((11.8, 5.1), (11.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((1.0, 2.6), (11.4, 4.4), fill: luma(250), radius: 0.02)
  cdraw.content((6.2, 3.9), [tau2: real between-cell spread], size: 6pt)
  cdraw.content((6.2, 3.0), [the signal shrink may keep], size: 6pt)
  cdraw.rect((12.2, 2.6), (22.6, 4.4), fill: luma(250), radius: 0.02)
  cdraw.content((17.4, 3.9), [sigma2/n: sampling noise], size: 6pt)
  cdraw.content((17.4, 3.0), [the part shrink must eat], size: 6pt)
  cdraw.line((6.2, 2.4), (6.2, 1.7), stroke: luma(100), mark: (end: ">>"))
  pane(1.0, 11.8, 1.5, [alpha = sigma2 / tau2], [more noise per trial], [or less real spread], [both raise the pseudo-counts])
  cdraw.line((17.4, 2.4), (17.4, 1.7), stroke: luma(100), mark: (end: ">>"))
  pane(12.2, 22.6, 1.5, [tau2 at the floor 0], [noise explains everything], [the current alpha stays])
})

The measured number lands where the theory says it should. On the
deterministic synthetic family the tests use, 200 cells at 150 to 250
trials each with true spread `tau2 = 0.0004` against the binomial
worst-case `sigma2 = 0.25`, the moment match returns alpha 607.0 with
tau2 0.000412 against the nominal 625, inside the test band. The moment
estimate is not the last word: it sees wide counts, so the fit
cross-checks it against a holdout win record by binomial deviance, twice
the log-likelihood gap between held-out wins and the shrunk prediction,
and lets that grid choice outvote the moment only when at least 30 cells
qualify. On the seeded 40-cell synthetic the check picks grid alpha 200
at mean deviance 1.1871 against 1.4159 for a deliberately tiny current
alpha of 10, the kind of mismatch the check exists to catch:

#listing("go/data/internal/fit/shrink.go", first: 112, last: 148, caption: [the holdout cross-check: deviance of the shrunk prediction against real win records, ties keeping the smaller alpha])

== completing the thin cells

Shrinkage fixes the noisy cells, but a cell with no observations at all
has nothing to shrink. The pool of heroes is small and the roster is
large, so the pool-by-roster grid is mostly holes, and the holes are not
random: a hero nobody picks against a hero nobody picks is a structural
zero. Matrix completion refills those holes with a low-rank
factorization, two thin matrices `u` and `v` whose product approximates
the observed cells, trained by alternating least squares. Fix `v`, and
every row of `u` is an independent ridge solve. Fix `u`, and every
column of `v` is the same solve transposed. Alternate until the factors
stop moving, break on the max-abs factor delta, and refill:

#listing("go/data/internal/fit/complete.go", first: 57, last: 98, caption: [seeded init, fixed row-major order, one convergence test, then the refill])

Determinism is a property here, not an accident: the init draws from one
PCG stream keyed `(seed, seed)` the corpus convention fixes, the sweep
walks rows before columns in a fixed order, and the scratch buffers `AtA`
and `b` are owned by the call so no allocator state leaks into the
arithmetic. The per-factor solve assembles each side's normal equations
with the ridge `lambda` on the diagonal, which is what keeps the system
solvable when a row saw fewer cells than the rank, and hands them to a
Gaussian elimination that refuses to divide by a pivot under the floor,
leaving the previous estimate standing rather than manufacturing one
from noise:

#listing("go/data/internal/fit/complete.go", first: 101, last: 136, caption: [one factor side: normal equations with a ridge, caller-owned scratch, singular systems keep the old estimate])

#diagram([the pool-by-roster grid: observed cells, thin cells, and holes refilled by low-rank structure], length: 13pt, {
  let cell(x, y, kind) = {
    if kind == 0 { cdraw.rect((x, y), (x + 1.0, y + 1.0), fill: luma(90), radius: 0.02) }
    else if kind == 1 { cdraw.rect((x, y), (x + 1.0, y + 1.0), fill: luma(200), radius: 0.02) }
    else { cdraw.rect((x, y), (x + 1.0, y + 1.0), fill: white, stroke: luma(220), radius: 0.02) }
  }
  let grid = (
    (0, 0, 1, 2, 0, 1), (1, 0, 0, 1, 2, 2), (0, 1, 1, 0, 2, 1),
    (2, 1, 0, 0, 1, 2), (1, 2, 2, 1, 0, 2), (0, 1, 0, 2, 1, 0),
    (2, 2, 1, 0, 0, 1),
  )
  for (r, row) in grid.enumerate() {
    for (c, kind) in row.enumerate() {
      cell(4.6 + c * 1.15, 7.2 - r * 1.15, kind)
    }
  }
  cdraw.content((3.4, 7.6), [pool], size: 6pt)
  cdraw.content((11.6, 1.6), [roster], size: 6pt)
  pane(13.4, 23.0, 7.6, [legend], [dark: observed, wide count], [light: thin, shrunk hard], [outline: hole, no data])
  cdraw.line((13.0, 4.6), (11.9, 3.9), stroke: luma(100), mark: (end: ">"))
  pane(13.4, 23.0, 4.2, [the refill], [u x v at the holes], [structure from neighbors])
  cdraw.content((8.0, -0.4), [a hero nobody meets is a structural zero, not a missing measurement], size: 6pt)
})

The tests grade the completion two ways. On an exact rank-1 grid with
two masked cells and the ridge off, the refill recovers both cells under
`1e-6`, the one regime where recovery can be exact. On a rank-2 fixture
under the production-sized ridge, ALS reaches rmse 1.0433 over the 4
masked cells where filling each hole with its column's observed mean
scores 3.4473, and the observed cells pass through bit-identical: the
completion may only ever add information where information is missing.

== masked-cell cross-validation

Rank and ridge are two more constants that could be tasted in, and the
fit refuses. It hides a seeded fraction of the observed cells, completes
the holed matrix for every candidate on the grid, and scores each
candidate by the Spearman correlation between its predictions and the
held-out truth, the chapter 31 stats package's midrank Spearman reused
as-is. Ties keep the smaller rank, then the smaller ridge. The current
config runs through the same mask, both top candidates re-predict every
held cell, and the winner-minus-current difference gets a percentile
bootstrap interval over held-cell resamples through the same package's
`PercentileCI`: one explicit reuse, two fewer statistics to re-derive
and drift:

#listing("go/data/internal/fit/crossval.go", first: 87, last: 119, caption: [the shared mask, then each grid point scored by reused Spearman against the held-out cells])

#listing("go/data/internal/fit/crossval.go", first: 153, last: 167, caption: [the diff CI: reused PercentileCI over held-cell resamples, constant ranks contributing 0])

On the seeded synthetic, two exact rank-3 grids at 75 percent observed
with 30 percent of cells masked, the grid of ranks 1 through 4 against
ridges 0.001 to 0.1 picks the true rank 3 with held-out Spearman 0.9991
against 0.8064 for a crippled current candidate at rank 1, over 86
masked cells, with the difference CI landing at [0.1072, 0.2655]: the
guard evidence, computed, not asserted.

#diagram([the cv pipeline: mask, sweep the grid, score against the held-out truth, bootstrap the diff], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 4.6), (x0 + w, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.2), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 5.2), [#l1], size: 6pt)
  }
  step(0.3, 4.6, [observed matrix], [wide + thin cells])
  cdraw.line((5.1, 5.7), (5.5, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(5.5, 4.6, [seeded mask], [hide 30 percent])
  cdraw.line((10.3, 5.7), (10.7, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.0, [grid sweep], [rank x lambda, ALS each])
  cdraw.line((15.9, 5.7), (16.3, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(16.3, 6.9, [score vs held-out], [stats.Spearman, reused])
  cdraw.line((5.6, 4.4), (5.6, 3.5), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 11.0, 3.3, [current too], [same mask, same scoring], [no home advantage])
  cdraw.line((18.0, 4.4), (18.0, 3.5), stroke: luma(100), mark: (end: ">>"))
  pane(13.4, 23.0, 3.3, [diff CI], [winner minus current], [stats.PercentileCI, reused])
  cdraw.content((11.5, 1.6), [the winner must beat the incumbent outside the interval, not on it], size: 6pt)
})

== comparators that never feed the live score

A fit that only ever races its own incumbent can drift into a local
pride, so the backtest also runs two comparators built on deliberately
different assumptions. Both read the same feature space, a draft's final
pick set as ascending item ids, and both answer one question: does this
set look more like the winners or the losers in train. The kNN is a
retrieval engine, cosine similarity over one-hot sets, which for sorted
id slices is the intersection count over the sqrt of the two sizes, a
linear merge with no hash and no float feature vector. Its neighbors
vote weighted by similarity, and similarity ties break by train id
ascending so the vote never depends on the order drafts were handed in,
the property the test proves by reversing the train slice and scoring
again. The naive Bayes is a counting engine, per-item win and loss
counts with a Laplace add-alpha rescue so a zero cell scores a finite
ratio. Its one subtle rule is the out-of-vocabulary skip: an item
counted zero in both classes contributes nothing, because scoring it
would add another copy of the class prior per unknown item and a draft
full of strangers would drift toward whichever class was rarer:

#listing("go/data/internal/fit/knn.go", first: 111, last: 133, caption: [cosine over one-hot sets as a sorted-int merge, the norm precomputed at train time])

#listing("go/data/internal/fit/naivebayes.go", first: 42, last: 64, caption: [bernoulli log-odds with the laplace rescue and the unknown-item skip])

#diagram([two comparators, one feature space: retrieval by similarity versus counting by class], length: 13pt, {
  cdraw.content((11.5, 8.0), [the final pick set, ascending ids], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  pane(3.0, 20.0, 7.0, [one shared feature space], [#"[3, 7, 11, 19]"], [presence only, no weights inside])
  cdraw.line((6.5, 4.0), (6.5, 3.3), stroke: luma(100), mark: (end: ">>"))
  pane(1.0, 12.0, 3.1, [kNN: retrieval], [cosine to every train set], [k nearest vote, id breaks ties])
  cdraw.line((16.5, 4.0), (16.5, 3.3), stroke: luma(100), mark: (end: ">>"))
  pane(11.0, 22.0, 3.1, [naive bayes: counting], [per-item win/loss counts], [laplace rescue, OOV skipped])
  cdraw.content((11.5, 1.2), [report only: neither score ever feeds the live table], size: 6pt)
})

The hygiene lesson is the wiring, not the math. Both comparators score
into the report and stop there: no comparator output reaches the live
config, because a comparator's job is to lose informatively. The day a
comparator beats the fitted model is the day the fit needs redoing, not
the day the comparator gets promoted around the guard.

== a bagged blend under coordinate ascent

The blend is where the fitted model meets the comparators: an authored
draft-advantage component, the bagged naive Bayes score, the bagged kNN
score, three non-negative weights over them. Bagging draws B bootstrap
resamples of the train drafts, trains both comparators in every bag, and
averages: a single comparator's split idiosyncrasies are noise, and the
resampled average trades a little bias for a lot of stability, leaving
roughly `1/e` of the drafts out of bag in each. The weights are fitted
by coordinate ascent on train AUC, the stats package's Mann-Whitney AUC
reused as the objective. Each weight scans the multiples of the step up
to the cap with the others fixed, keeps a value only on strict
improvement so ties keep the earlier, lower value, and a pass that
improves nothing stops the ascent:

#listing("go/data/internal/fit/ensemble.go", first: 40, last: 70, caption: [bags from one PCG stream, comparators per bag, components handed to the ascent])

#listing("go/data/internal/fit/ensemble.go", first: 134, last: 174, caption: [coordinate ascent on AUC: strict improvement only, early stop, ratios over levels])

One property of the objective deserves its sentence in the config
review. AUC reads only the order of the blended scores, so scaling every
weight by the same constant changes nothing: the absolute level is
meaningless and only the ratios carry information. That scale invariance
is why the grid may stay coarse, and the test states it as a property,
scaling one component by 100 and watching the fitted AUC hold still.

#diagram([one ascent over a two-weight slice: the sweep, the keep rule, the stop], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [weight on component j], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [train AUC], size: 6pt)
  cdraw.line((0.6, 1.3), (4.4, 1.35), stroke: luma(60))
  cdraw.line((4.4, 1.35), (9.4, 4.9), stroke: luma(60))
  cdraw.line((9.4, 4.9), (23.2, 5.15), stroke: luma(60))
  // grid ticks the sweep scans
  for i in range(8) {
    let x = 2.2 + i * 3.0
    cdraw.line((x, 0.5), (x, 0.9), stroke: luma(150))
  }
  cdraw.content((11.0, 1.6), [the grid: multiples of the step], size: 6pt)
  cdraw.circle((9.4, 4.9), radius: 0.26, fill: luma(160))
  cdraw.content((9.8, 5.7), [kept: first strict improvement], size: 6pt)
  cdraw.content((17.0, 4.3), [flat tail: equal AUC keeps the lower value], size: 6pt)
  pane(2.6, 10.6, 2.2, [next pass], [revisit every j], [interactions get their turn])
  cdraw.content((11.5, -0.4), [a pass that improves nothing stops the whole ascent], size: 6pt)
})

== replaying drafts without lookahead

Every metric so far scores tables against tables. The backtest that
matters walks real drafts pick by pick and asks the only question a
picker cares about: at this moment, with this much of the draft visible,
where did the taken hero rank among the alternatives. The discipline is
one function: the state at pick i is built from events strictly before
i, same-side earlier picks as allies, opposing earlier picks as enemies,
picks and bans together as taken. Nothing at or after i leaks in, and
the property test holds the walker to it by permuting the draft's future
at three cut points and asserting every earlier pick's score and rank
come out bit-identical: a shuffled future is invisible or the backtest
is lying:

#listing("go/data/internal/fit/replay.go", first: 31, last: 51, caption: [stateBefore: everything strictly earlier, split into allies, enemies, taken])

The rank itself is order-independent by construction: score descending,
ties by ascending item id, over the roster minus the taken list with the
picked item competing. The mean percentile and the top-k hit rate read
directly off the ranks, skipping single-candidate fields where no
ranking exists:

#listing("go/data/internal/fit/replay.go", first: 87, last: 125, caption: [the walk: each pick scored against the alternatives its state left available])

#diagram([one draft on a timeline: the visibility window at pick i is everything left of it], length: 13pt, {
  cdraw.line((0.6, 4.2), (23.2, 4.2), stroke: luma(120))
  cdraw.content((23.4, 4.2), [pick order], size: 6pt)
  let ev(x, y, label, pick) = {
    if pick { cdraw.circle((x, y), radius: 0.26, fill: luma(160)) }
    else { cdraw.rect((x - 0.24, y - 0.24), (x + 0.24, y + 0.24), fill: luma(210), radius: 0.02) }
    cdraw.content((x, y + 0.85), [#label], size: 6pt)
  }
  ev(1.6, 4.2, [ban], false)
  ev(3.4, 4.2, [pick a], true)
  ev(5.2, 4.2, [pick e], true)
  ev(7.0, 4.2, [pick b], true)
  ev(12.6, 4.2, [pick i], true)
  ev(15.4, 4.2, [pick e], true)
  ev(17.2, 4.2, [ban], false)
  ev(19.0, 4.2, [pick a], true)
  ev(21.6, 4.2, [pick e], true)
  // the visible window
  cdraw.rect((0.6, 3.7), (12.6, 4.7), fill: rgb("e8eef7"), radius: 0.02, stroke: none)
  cdraw.circle((12.6, 4.2), radius: 0.3, fill: luma(60))
  cdraw.content((7.0, 5.6), [the window: events 0..i-1 only], size: 6pt)
  cdraw.content((6.6, 3.1), [allies: earlier same-side picks], size: 6pt)
  cdraw.content((6.6, 2.2), [enemies: earlier opposing picks], size: 6pt)
  cdraw.content((6.6, 1.3), [taken: picks and bans, both], size: 6pt)
  pane(14.4, 23.2, 1.8, [the future], [events i..n stay unread], [shuffling them moves nothing])
  cdraw.content((11.5, 0.2), [hindsight scoring would read the whole line, and flatter every table], size: 6pt)
})

Scores also need calibration, a number that means the same thing on
holdout as it meant on train. The fit slices train pick scores into
decile edges, upper-edge inclusive, collapses repeated edges so heavy
ties leave no zero-width bin, bins the holdout scores against those
edges, and counts adjacent nonempty bins whose realized win rate drops:
monotonicity violations. On the seeded synthetic the climbing ladder
scores 0 violations and its inversion scores 9, one per adjacent pair,
and the count rides in the report where a promotion decision can read
it:

#listing("go/data/internal/fit/replay.go", first: 175, last: 220, caption: [decile calibration: edges from train, rates from holdout, drops counted])

== guarded promotion

Everything upstream writes proposals, never configs. The promotion is
the single choke point where a fitted number may enter the hub, and it
is guarded four ways. The proposal is re-read from disk, because the
bytes that get promoted must be the bytes that were audited. The
baseline is pinned: the proposal records the live weights its gain was
measured against, and a hub that moved since makes the numbers stale,
so the guard refuses and asks for a rerun rather than comparing a fresh
gain against an old truth. The holdout gain must clear its floor. And
the bootstrap interval's low end must sit strictly above 0, because a
mean gain that could be zero is no gain:

#listing("go/data/internal/fit/promote.go", first: 24, last: 46, caption: [the guard: finite weights, pinned baseline, gain floor, CI low above zero])

The write path is shaped so refusal is provably harmless. Every check
runs before any file is opened for writing, and the single rewrite
unmarshals the hub, replaces the blend weights, and re-indents at two
spaces with sorted keys, so the same hub rewrites to the same bytes. The
test states the property the operator actually needs: a gain below the
floor returns an error and the config file's bytes compare identical
before and after, not as a promise but as an assertion:

#listing("go/data/internal/fit/promote.go", first: 48, last: 92, caption: [promote: re-read, guard, then and only then the one rewrite])

#diagram([the guard decision flow: four doors, and every refusal leaves the file untouched], length: 13pt, {
  cdraw.content((11.5, 8.4), [proposal on disk], size: 6.5pt)
  cdraw.line((11.5, 8.1), (11.5, 7.4), stroke: luma(100), mark: (end: ">>"))
  let door(y, q) = {
    cdraw.rect((6.7, y), (16.3, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.5, y + 0.75), [#q], size: 6pt)
  }
  door(5.9, [weights finite, baseline equals live?])
  door(4.1, [gain at or above the floor?])
  door(2.3, [gain CI low strictly above 0?])
  cdraw.line((11.5, 5.9), (11.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 4.1), (11.5, 3.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 2.3), (11.5, 2.0), stroke: luma(100), mark: (end: ">>"))
  pane(17.6, 23.4, 6.9, [all four pass], [one rewrite, sorted keys], [round-trip, trailing newline])
  cdraw.line((16.3, 6.6), (17.6, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 6.0, 6.9, [any refusal], [error names the door], [file bytes identical])
  cdraw.line((6.7, 6.6), (6.0, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 1.0), [the test proves the refusal case with bytes.Equal, before and after], size: 6pt)
})

== the fit loop

The pieces close into a cycle. The fit measures against the current hub
and writes proposals: an alpha per family with its cross-check, a
completion candidate with its diff CI, a blend weight vector with its
gain interval. The guard re-reads each proposal, re-checks it against
the live hub, and either promotes through the single rewrite or refuses
with the file untouched. A promoted hub changes the baseline every
later fit measures against, which is the point: the loop's next pass
must beat the promoted numbers, not the numbers they replaced. Every
fitted constant carries its provenance, the procedure that produced it
and the measurement it must answer to again, because a config file full
of unexplained decimals is where models go to rot quietly.

#diagram([the loop: fit measures the hub, guard re-checks, promote rewrites, refit must beat what promotion made live], length: 13pt, {
  let node(x, y, title, l1) = {
    cdraw.rect((x, y), (x + 5.4, y + 2.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.7, y + 1.55), [#title], size: 6pt)
    cdraw.content((x + 2.7, y + 0.6), [#l1], size: 6pt)
  }
  node(0.4, 5.4, [fit], [measure, propose])
  cdraw.line((5.8, 6.4), (7.2, 6.4), stroke: luma(100), mark: (end: ">>"))
  node(7.2, 5.4, [guard], [re-read, re-check])
  cdraw.line((12.6, 6.4), (14.0, 6.4), stroke: luma(100), mark: (end: ">>"))
  node(14.0, 5.4, [promote], [one rewrite])
  cdraw.line((16.7, 5.4), (16.7, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.1, 4.8), [pass], size: 6pt)
  cdraw.line((16.7, 4.3), (16.7, 3.6), stroke: luma(100), mark: (end: ">>"))
  node(14.0, 1.5, [refit], [baseline moves])
  cdraw.line((14.0, 2.5), (12.4, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.2, 2.9), [beat the promoted hub], size: 6pt)
  cdraw.line((7.0, 2.5), (3.1, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((3.1, 2.5), (3.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.9, 5.4), (9.9, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.9, 4.1), [refuse], size: 6pt)
  pane(0.4, 7.6, 4.4, [refusal path], [file untouched], [the hub stays])
  cdraw.content((19.6, 0.9), [every fitted constant carries its procedure], size: 6pt)
})

sources: pkg.go.dev/math/rand/v2 for the PCG generator the seeded init
and bags draw from, read against the go 1.27 module cache source, plus
the dota-helper engine (`poolguide`, local repository) whose eval and
analytics and mine packages this chapter adapts: shrinkage and posterior
variance from analytics/shrink.go and mine/cell.go, the moment-matched
alpha with its holdout deviance cross-check from eval/fitalpha.go, the
ALS completion and masked-cell CV from analytics/complete.go and
eval/fitcompletion.go, the comparators from eval/knn.go and
eval/naivebayes.go, the blend from eval/ensemble.go, the replay and
calibration from eval/replay.go and eval/metrics.go, and the guarded
promotion from eval/promote.go, all accessed 2026-10-05. Verified by
`go/data/internal/fit` tests under `go vet`, `go test`, and the race
detector, with the Spearman, AUC, and PercentileCI machinery reused
from `go/data/internal/stats`.
