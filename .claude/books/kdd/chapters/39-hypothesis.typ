// ch39, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 46 checks in kdd/samples/src/Ch39/hypo.c (21) and tsim.c (25) or a
// cited constant pinned by the contract sheet: the df=4 two-sided t
// critical 2.7764, standard t table (sheet cites medcalc.org), the one D2
// constant. classes: D0 fractions, D1 dyadic t doubles, D3 sim literals
// (integer-deterministic). the sheet's pmf(9) line prints 10/1024
// unreduced; the sheet's own fraction law and the C both pin the reduced
// 5/512, and the chapter quotes the reduced form. all pinned values are
// witnessed by kdd-contract-s8s9.md + playground/kdd-matrix/gen_s8.py,
// run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= hypothesis testing and p-values

Two samples carry the chapter: `hypo.c` runs the exact binomial test and
the one-sample t-test on fixtures built for exact arithmetic, 21 checks,
and `tsim.c` measures the binomial test's false-alarm rate with a pinned
random stream, 25 checks. The chapter makes 4 moves: the exact one- and
two-sided p-values for eight heads of ten, the rejection region an exact
test can actually afford, the t-statistic that estimates its own spread,
and the simulated type-I rate. Every behavioral claim below is one of
the 46 checks of chapter 39's samples or a cited constant.
#xref-to("kdd", "lof") ended on the question of how often a rule cries
wolf; this chapter prices the crying, and #xref-to("kdd", "fdr") next
handles the pipeline that runs ten tests at once.

== eight heads of ten

The cleanest test bed is a fair coin flipped ten times, and the cleanest
question is whether eight heads is surprising. The null gives every
count k the probability $"pmf"(k) = binom(10, k) \/ 2^10$, all 1024
sequences equally likely, and the sample builds the 11 probabilities
with Pascal's triangle and asserts each as a reduced fraction.

The dry run: the triangle's low rows give $"pmf"(8) = 45\/1024$,
$"pmf"(9) = 10\/1024$, which reduces to 5\/512, and $"pmf"(10) =
1\/1024$, printed as `binom pmf8=45/1024 pmf9=5/512 pmf10=1/1024` and
checked as "ch39 pmf(8) = 45/1024" through "ch39 pmf(10) = 1/1024".
The one-sided question, at least this extreme upward, sums three cells,
$(45 + 10 + 1)\/1024 = 56\/1024 = 7\/128$, printed `pone_ge8=7/128`.
The two-sided question uses the point-probability method: sum every
outcome no more likely than the one observed. For 8 heads that is every
k with $"pmf"(k) <= 45\/1024$, the set {0, 1, 2, 8, 9, 10}, and the
symmetry makes it twice the upper tail, $2 dot 56\/1024 = 112\/1024 =
7\/64$, printed `ptwo_8=7/64` and asserted as "ch39 two-sided p(8) =
7/64". For 9 heads the bar drops to outcomes at most $10\/1024$ likely,
{0, 1, 9, 10}, and `ptwo_9=11/512`. The verdicts then print one line
each, `decide 8heads p=7/64 vs 1/20 reject=false` and `decide 9heads
p=11/512 vs 1/20 reject=true`, checked as "ch39 8 heads fails to reject
at 5%" and "ch39 9 heads rejects at 5%".

#listing("kdd/samples/src/Ch39/hypo.c", first: 66, last: 89,
  caption: [Pascal's triangle builds the pmf, the one-sided p sums three cells])

#listing("kdd/samples/src/Ch39/hypo.c", first: 91, last: 115,
  caption: [the point-probability two-sided p, then both decisions at 1/20])

#diagram([ten fair flips: the pmf, shaded where probability is at most 45/1024], length: 13pt, {
  let px(k) = { 1.0 + k * 1.5 }
  let py(v) = { 0.6 + v * 17.0 }
  let cs = (1, 10, 45, 120, 210, 252, 210, 120, 45, 10, 1)
  for k in range(11) {
    let hot = k <= 2 or k >= 8
    cdraw.rect((px(k * 1.0) - 0.5, 0.6), (px(k * 1.0) + 0.5, py(cs.at(k) / 1024.0)),
      fill: if hot {luma(188)} else {luma(232)}, radius: 0.01)
    cdraw.content((px(k * 1.0), 0.25), [#k], size: 6pt)
  }
  cdraw.content((px(5.0), py(252.0 / 1024.0) + 0.4), [252\/1024], size: 6pt)
  cdraw.content((px(2.0), py(45.0 / 1024.0) + 0.4), [45\/1024], size: 6pt)
  cdraw.content((px(8.0), py(45.0 / 1024.0) + 0.4), [45\/1024], size: 6pt)
  cdraw.line((px(8.0) - 0.55, 2.0), (px(10.0) + 0.55, 2.0), stroke: luma(110))
  cdraw.line((px(8.0) - 0.55, 1.86), (px(8.0) - 0.55, 2.14), stroke: luma(110))
  cdraw.line((px(10.0) + 0.55, 1.86), (px(10.0) + 0.55, 2.14), stroke: luma(110))
  cdraw.content((px(9.0), 2.4), [56\/1024 = 7\/128], size: 6pt)
  cdraw.content((8.5, 6.3), [both shaded families: 112\/1024 = 7\/64], size: 6pt)
})

#callout("pitfall", "what the verdict lines do not say", [
  The two misread rows pin the classic doublespeak. `misread p>alpha:
  p=7/64=0.109>0.05 -> fail to reject; NOT proof H0 true`: a missed bar
  says this test cannot tell 8-of-10 from luck, and says nothing about
  the coin's honesty. And `misread p<alpha: p=11/512=0.0215<0.05 ->
  reject H0; NOT P(H0)<5%`: the p-value probabilities outcomes, not
  hypotheses, so 0.0215 is P(data this extreme given a fair coin), never
  P(fair coin given the data). Both rows carry checks on their numeric
  comparisons: "ch39 misread row 7/64 = 0.109 > 0.05, fail to reject"
  and "ch39 misread row 11/512 = 0.0215 < 0.05, reject".
])

== what five percent actually buys

A test over a table of exact probabilities cannot land on alpha = 1/20
on the nose, because every rejection region is a set of cells and every
cell weighs a multiple of 1/1024. The exact test takes the largest
region whose total probability still fits the budget.

The dry run: the sample scores every k by its two-sided p and keeps the
ones under 1/20. k = 0 carries $2\/1024 = 1\/512$ and k = 1 carries
$22\/1024 = 11\/512$, both inside; the next candidate, k = 2 with its
mirror 8, carries $112\/1024 = 7\/64$, more than twice the whole
budget, so the region stops there. It prints `rej_region={0,1,9,10}
exact_type1=11/512`, asserted as "ch39 exact 5% region is {0,1,9,10}
(conservative)" with the size its own check, "ch39 exact type-I size
11/512". The true size is $22\/1024 = 11\/512 = 0.021484375$, a dyadic
decimal, and the nominal five percent is really 2.15. The staircase
between 11\/512 and 7\/64 spans one step of k and a factor of 56\/11,
and no arrangement of binomial cells can close that gap from below.

#listing("kdd/samples/src/Ch39/hypo.c", first: 117, last: 144,
  caption: [every k scored by two-sided p, the region that fits under 1/20])

#diagram([two-sided p per k against the 1/20 budget; the region stops after k = 1], length: 13pt, {
  let px(k) = { 1.4 + k * 2.2 }
  let py(v) = { 0.6 + v * 5.6 }
  let ps = (1.0 / 512.0, 11.0 / 512.0, 7.0 / 64.0, 11.0 / 32.0, 193.0 / 256.0, 1.0)
  for k in range(6) {
    cdraw.rect((px(k * 1.0) - 0.75, 0.6), (px(k * 1.0) + 0.75, py(ps.at(k))),
      fill: if k <= 1 {luma(188)} else {luma(232)}, radius: 0.01)
    cdraw.content((px(k * 1.0), 0.25), [#k], size: 6pt)
  }
  cdraw.line((0.8, py(0.05)), (13.6, py(0.05)), stroke: luma(90))
  cdraw.content((14.9, py(0.05) + 0.08), [1\/20], size: 6pt)
  cdraw.line((0.65, 1.55), (4.35, 1.55), stroke: luma(110))
  cdraw.line((0.65, 1.41), (0.65, 1.69), stroke: luma(110))
  cdraw.line((4.35, 1.41), (4.35, 1.69), stroke: luma(110))
  cdraw.content((2.5, 1.9), [22\/1024 = 11\/512], size: 6pt)
  cdraw.content((px(2.0), py(ps.at(2)) + 0.38), [7\/64], size: 6pt)
  cdraw.content((9.9, 5.5), [k and 10 - k share a p], size: 6pt)
  cdraw.content((7.0, 6.4), [region {0,1,9,10}: true size 11\/512 = 0.021484375], size: 6pt)
})

== four sevens and a two

The t-test replaces a known sigma with an estimate, and the fixture is
built so the estimate is exact: the values (2, 7, 7, 7, 7). Their mean
is 6, deviations (-4, 1, 1, 1, 1), sum of squares 20, so $s^2 = 20\/4 =
5$ and the standard error is $sqrt(s^2\/n) = sqrt(5\/5) = 1$ exactly.
Every number on the path is an integer, which is why the chapter pins t
itself instead of a rounding of t.

The dry run: the stats line prints `tvals mean=6/1 SS=20 s2=5/1 se=1`,
each field its own check from "ch39 t fixture mean = 6" to "ch39 t
fixture se = 1 exactly". Against mu0 = 8 the statistic is $t = (6 -
8)\/1 = -2$, printed `t mu0=8 -> t=-2 |t|=2 reject=false (crit 2.7764)`;
against mu0 = 10 it is -4 and the row ends `reject=true`. The critical
constant is the two-sided df = 4 table entry 2.7764, pinned as the
chapter's one D2 constant by "ch39 df=4 two-sided t critical 2.7764
pinned (D2)". Four degrees of freedom, because estimating the spread
from five values spends one. The same five numbers fail to disprove a
mean of 8 yet disprove a mean of 10, and the only thing that changed is
the claim.

#listing("kdd/samples/src/Ch39/hypo.c", first: 146, last: 167,
  caption: [the dyadic t fixture: mean, SS, s^2, and se exactly 1])

#listing("kdd/samples/src/Ch39/hypo.c", first: 169, last: 184,
  caption: [t against both null values, strict |t| > 2.7764 decisions])

#diagram([the t fixture on the value line: one claimed mean inside the critical band, one outside], length: 13pt, {
  let px(v) = { 1.0 + (v - 1.0) * 1.42 }
  let crit = 2.7764
  cdraw.line((0.7, 3.3), (16.5, 3.3), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((px(6.0 - crit), 3.0), (px(6.0 + crit), 3.6), fill: luma(242), radius: 0.01)
  cdraw.circle((px(2.0), 3.3), radius: 0.11, fill: luma(210), stroke: luma(60))
  cdraw.content((px(2.0), 2.9), [2], size: 6pt)
  let offs = ((0.0, 0.0), (0.17, 0.09), (-0.17, 0.09), (0.0, 0.19))
  for o in offs {
    cdraw.circle((px(7.0) + o.at(0), 3.3 + o.at(1)), radius: 0.09,
      fill: luma(210), stroke: luma(60))
  }
  cdraw.content((px(7.0), 2.9), [7, four times], size: 6pt)
  cdraw.line((px(6.0), 3.6), (px(6.0), 4.1), stroke: luma(60))
  cdraw.content((px(6.0), 4.45), [mean 6], size: 6pt)
  for mu in (8.0, 10.0) {
    cdraw.line((px(mu), 3.7), (px(mu), 4.5), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.content((px(mu), 4.85), [mu0 = #mu], size: 6pt)
  }
  cdraw.line((px(6.0), 2.4), (px(8.0), 2.4), stroke: luma(110), mark: (end: ">"))
  cdraw.content(((px(6.0) + px(8.0)) / 2, 2.05), [t = -2], size: 6pt)
  cdraw.line((px(8.0), 1.5), (px(10.0), 1.5), stroke: luma(110), mark: (end: ">"))
  cdraw.content(((px(8.0) + px(10.0)) / 2, 1.15), [another -2, t = -4], size: 6pt)
  cdraw.content((7.6, 0.65), [mean plus or minus 2.7764 se: fail to reject], size: 6pt)
})

== counting the false alarms

If the coin is fair and the region {0, 1, 9, 10} is applied forever,
the test rejects 11/512 of the time, and that rate can be measured
instead of derived. The generator is the MINSTD of #xref-to("kdd",
"sampling"), Park and Miller's $16807 dot "state" mod (2^31 - 1)$, seed
7, states held in uint64 so no intermediate overflows, and the coin is
bit 16 of each state. Ten flips per trial, 10000 trials, all integer
arithmetic, so the run reproduces itself bit for bit.

The dry run: the header prints `sim seed=7 rule=(state>>16)&1
trials=10000`, then `type1 rejects=212/10000=0.0212`, asserted as "ch39
sim rejects = 212/10000 (D3 literal)". The exact size is dyadic,
$11\/512 = 0.021484375$, checked for bit equality, and the simulated
rate sits about 0.0003 under it, well inside the 0.01 tolerance of
"ch39 sim rate within 0.01 of exact size". The histogram then prints
eleven rows, `hist 0=7 expected=625/64` through `hist 10=5
expected=625/64`, every count and every expected fraction its own
check. The middle row reads `hist 5=2411 expected=39375/16`, the
expectation being $10000 dot 252\/1024 = 39375\/16 = 2460.9375$. The
bars hug their expected ticks, and the two shaded tails hold 105 and 107
counts, exactly the 212 rejections.

#listing("kdd/samples/src/Ch39/tsim.c", first: 53, last: 74,
  caption: [10000 trials of ten bit-16 coins, rejections counted against 11/512])

#listing("kdd/samples/src/Ch39/tsim.c", first: 76, last: 93,
  caption: [eleven counts and eleven expected fractions, every row a check])

#diagram([10000 simulated trials: counts against expected ticks, rejection tails shaded], length: 13pt, {
  let px(k) = { 0.9 + k * 1.55 }
  let py(c) = { 0.6 + c * 5.4 / 2411.0 }
  let obs = (7, 98, 404, 1164, 2085, 2411, 2123, 1171, 430, 102, 5)
  let expd = (625.0 / 64.0, 3125.0 / 32.0, 28125.0 / 64.0, 9375.0 / 8.0,
    65625.0 / 32.0, 39375.0 / 16.0, 65625.0 / 32.0, 9375.0 / 8.0,
    28125.0 / 64.0, 3125.0 / 32.0, 625.0 / 64.0)
  for k in range(11) {
    let hot = k <= 1 or k >= 9
    cdraw.rect((px(k * 1.0) - 0.55, 0.6), (px(k * 1.0) + 0.55, py(obs.at(k) * 1.0)),
      fill: if hot {luma(186)} else {luma(230)}, radius: 0.01)
    cdraw.line((px(k * 1.0) - 0.62, py(expd.at(k))), (px(k * 1.0) + 0.62, py(expd.at(k))),
      stroke: luma(70))
    cdraw.content((px(k * 1.0), 0.25), [#k], size: 6pt)
  }
  cdraw.line((0.3, 1.6), (2.55, 1.6), stroke: luma(110))
  cdraw.line((0.3, 1.46), (0.3, 1.74), stroke: luma(110))
  cdraw.line((2.55, 1.46), (2.55, 1.74), stroke: luma(110))
  cdraw.content((1.42, 1.98), [105], size: 6pt)
  cdraw.line((14.25, 1.6), (17.0, 1.6), stroke: luma(110))
  cdraw.line((14.25, 1.46), (14.25, 1.74), stroke: luma(110))
  cdraw.line((17.0, 1.46), (17.0, 1.74), stroke: luma(110))
  cdraw.content((15.62, 1.98), [107], size: 6pt)
  cdraw.content((4.2, 6.55), [shaded tails: 105 + 107 = 212 rejections = 0.0212], size: 6pt)
  cdraw.content((4.2, 6.0), [exact size 11\/512 = 0.021484375], size: 6pt)
  cdraw.content((11.0, 5.85), [ticks: expected 10000 dot C(10, k)\/1024], size: 6pt)
})

One test, honestly priced: an exact 5% test that is really 2.15, a
p-value that grades outcomes and never hypotheses, and a measured false
alarm rate matching the derived one to three ten-thousandths. The
honesty lasts as long as the pipeline runs one test. Ten tests at 2.15
percent each promise a roughly one-in-five chance of at least one false
discovery, and #xref-to("kdd", "fdr") is that bill.

sources: the fair-coin 8-of-10 example is the canonical small-sample
binomial test pinned by kdd-contract-s8s9.md, two-sided p by the
point-probability method as pinned there. The t critical 2.7764 is the
standard two-sided df = 4 t table entry (sheet cites medcalc.org), the
chapter's one D2 constant. The generator is Park and Miller's MINSTD,
"Random Number Generators: Good Ones Are Hard to Find", Communications
of the ACM 31(10) 1988, 1192-1201, the same family chapter 07's sampling
pin uses. All 46 pinned values witnessed by
kdd-contract-s8s9.md and playground/kdd-matrix/gen_s8.py, run 2026-09-22,
exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch39`,
21 + 25 checks in chapter 39 of the kdd suite.
