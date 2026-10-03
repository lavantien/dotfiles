#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= statistics and inference

Chapter #xref-to("math", "probability") built the forward direction, model to
data: distributions, expectations, the conjugate Beta-Bernoulli pair. This
chapter runs the inverse direction, data to model, in six moves: a seeded
sampling stream and the sample mean, the law of large numbers as a pinned
ladder, the central limit theorem priced as an exact binomial tail against its
normal approximation, estimators with bias and variance settled by enumerating
tiny populations, maximum likelihood and maximum a posteriori as derivative
solves, and the two inference contracts, exact tests with confidence intervals
plus least squares as orthogonal projection. Every behavioral claim below is
one of the 63 checks in the 4 samples of chapter 19 or a sentence quoted from
a canonical source fetched 2026-09-21. The dsa book keeps randomness out of
its algorithms (#xref-to("dsa", "numerical")); this chapter does the opposite
discipline, the randomness is pinned to a fixed xorshift64\* trace so every
statistic is reproducible to the bit.

== sampling and the sample mean

A statistic is a deterministic function of the data, in mml's words "a
deterministic function of that random variable" [printed p 186 / pdf p 192].
The empirical mean is the arithmetic average $bar(x) = 1\/N sum_(n=1)^N x_n$
(mml Definition 6.9, eq 6.41 [printed p 192 / pdf p 198]), and mml states the
divisor convention outright in the margin of that page: "Throughout the book,
we use the empirical covariance, which is a biased estimate. The unbiased
(sometimes called corrected) covariance has the factor N - 1 in the
denominator instead of N." The variance has three faces there (eqs 6.43-6.45
[printed pp 192-193 / pdf pp 198-199]): the definition
$V[x] = E[(x - mu)^2]$, the raw-score one-pass $V[x] = E[x^2] - E[x]^2$
"the mean of the square minus the square of the mean", which is "numerically
unstable" when the two terms nearly cancel, and the pairwise form.

The samples here never touch the heap or the clock. One xorshift64\* generator
(Vigna's three shifts and the odd multiplier) advances a fixed 64-bit state,
and one uniform decimal digit comes from each 31-bit draw by rejecting the
top 8 of the $2^31$ values, so the accepted range $2^31 - 8 = 2147483640$ is
an exact multiple of 10 and the digit is uniform by construction, not
approximately. The whole 10000-draw trace is materialized once and every
statistic reads the same fixed array, the way a real dataset would.

The dry run: the trace under seed 0x9E3779B97F4A7C15 opens
7, 8, 3, 5, 6, 9, 8, 9, 3, 4, 4, 6, its first 100 digits sum to 419, and
the indicator $x_i = 1"[digit < 3]"$ turns it into an exact Bernoulli
stream with $p = 3\/10$.

+ The Bernoulli count in the first 100 draws is $k = 31$, so $bar(x) =
  31\/100 = 0.31$ and the raw-score shortcut gives the centered sum
  $k - k^2\/n = 21.39$, hence $s^2 = 21.39\/99 = 0.216061$.
+ The population behind the digits has mean 4.5 and variance $99\/12 =
  8.25$. Over all 10000 draws the two-pass variance lands at 8.289188439999835
  and the raw-score one-pass at 8.28918844, differing by 1.65e-13, the
  cancellation mml warns about, visible at n = 10000 already.
+ Chebyshev prices the tail of the mean: at $"eps" = 0.05$ and $n = 10000$
  the bound $0.21\/(n "eps"^2) = 0.0084$, and the observed deviation 0.0025
  sits inside it with room.

#listing("math/samples/src/Ch19/sampling.c", first: 22, last: 44, caption: [the seeded stream and the exact-uniform digit, sampling.c])

The law of large numbers says $bar(x)_n -> p$ in probability (Wasserman 2004,
ch 5, by name). The pinned ladder makes that concrete on the fixed trace: the
deviation from $p$ falls by a factor 120 while $n$ grows by a factor 1000.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*n*], [*k*], [*k\/n*], [*\|k\/n - 0.3\|*]),
  [10], [0], [0.0], [0.3],
  [100], [31], [0.31], [0.01],
  [1000], [304], [0.304], [0.004],
  [10000], [3025], [0.3025], [0.0025],
)

#listing("math/samples/src/Ch19/sampling.c", first: 94, last: 129, caption: [the lln rungs with their pinned counts, the chebyshev envelope, and the two-pass versus raw-score variance, sampling.c])

#diagram([the lln ladder on one fixed stream, deviation against n, with the 1\/sqrt(n) guide], length: 13pt, {
  // log10 n in [1, 4] -> x in [1.5, 19.5]; log10 |dev| in [-3, 0] -> y in [0.8, 5.6]
  let px(lg) = 1.5 + (lg - 1.0) * 6.0
  let py(lgd) = 0.8 + (lgd + 3.0) * 1.6
  cdraw.line((1.5, 0.8), (19.9, 0.8), stroke: luma(100), mark: (end: ">"))
  for lg in (1.0, 2.0, 3.0, 4.0) {
    cdraw.line((px(lg), 0.72), (px(lg), 0.88), stroke: luma(100))
  }
  cdraw.content((px(1.0), 0.35), [10], size: 6pt)
  cdraw.content((px(2.0), 0.35), [$10^2$], size: 6pt)
  cdraw.content((px(3.0), 0.35), [$10^3$], size: 6pt)
  cdraw.content((px(4.0), 0.35), [$10^4$], size: 6pt)
  cdraw.content((20.4, 0.8), [n], size: 6pt)
  // the 1/sqrt(n) guide, log10 dev = -lg/2
  cdraw.line((px(1.0), py(-0.5)), (px(4.0), py(-2.0)),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((16.3, 3.35), [$1\/sqrt(n)$], size: 6pt)
  // measured rungs: (log10 n, log10 |dev|)
  let pts = ((1.0, -0.523), (2.0, -2.0), (3.0, -2.398), (4.0, -2.602))
  for i in range(pts.len() - 1) {
    cdraw.line((px(pts.at(i).at(0)), py(pts.at(i).at(1))),
      (px(pts.at(i + 1).at(0)), py(pts.at(i + 1).at(1))), stroke: luma(60))
  }
  let labs = ([0.3], [0.01], [0.004], [0.0025])
  for i in range(pts.len()) {
    let (lg, lgd) = pts.at(i)
    cdraw.line((px(lg), 0.8), (px(lg), py(lgd)), stroke: luma(140))
    cdraw.circle((px(lg), py(lgd)), radius: 0.09, fill: luma(205), stroke: luma(60))
    cdraw.content((px(lg) + 0.15, py(lgd) + 0.42), labs.at(i), size: 6pt)
  }
})

The two-number play: the first rung misses by 0.3 because 0 of the first 10
digits are 0, 1, or 2, an event of probability $0.7^10 = 0.028$, and the last
rung misses by 0.0025. The honest reading of a 4-rung ladder is not proof,
the proof is Chebyshev's inequality, the ladder is what convergence looks
like on data you can rerun bit for bit.

#callout("verify", "THE STREAM IS THE POPULATION", [Every sampled number in this chapter is a deterministic function of one 64-bit seed. The pin script in the repo replays each generator in exact integer arithmetic and prints every expected value, so a check that passes is a replication, not a probability. Change the seed and every ladder in this chapter changes, which is exactly why the seed lives in a comment next to the pins.])

== the central limit theorem

Standardize a sum. For Bernoulli($p$) indicators, linearity gives
$E[S_n] = n p$ and, since indicators are independent, variances add the way
mml eq 6.58 states for uncorrelated variables, $V[x + y] = V[x] + V[y]$
[printed pp 195-196 / pdf pp 201-202], so $V[S_n] = n p(1 - p)$. The central
limit theorem (Wasserman 2004, ch 5, by name) says the standardized sum
$z_n = (S_n - n p)\/sqrt(n p(1 - p))$ converges in distribution to the
standard normal, and for coin flips this is the De Moivre-Laplace theorem,
the oldest case.

The dry run: a second stream under seed 0xDEADBEEFCAFEF00D feeds the same
Bernoulli($3\/10$) rule, and the standardized sums walk through units.

+ At $n = 5$ the trace holds $S = 0$ successes, $z = -1.4639$.
+ At $n = 20$, $S = 5$, $z = -0.4880$. At $n = 80$, $S = 25$, $z = +0.2440$.
+ At $n = 320$, $S = 117$, $z = +2.5617$, and the exact binomial tail
  $P(X >= 117) = 0.006883$, the $p$-value scale the next sections use.

The normal side needs $Phi$, and the honest route on doubles is the
complementary error function: $Phi(x) = 1\/2 "erfc"(-x\/sqrt(2))$, erfc
defined by DLMF 7.2.E2 as $(2\/sqrt(pi)) integral_z^infinity e^(-t^2) dif t$
(fetched 2026-09-21) and exposed by C23 as `erfc` with the same formula
(cppreference, fetched 2026-09-21). The samples verify the table cells
rather than trusting the constant: $Phi(0) = 0.5$, $Phi(1.96) =
0.9750021048517796$, the two-sided 95% row of any printed table, and the
pinned quantile $z_(0.975) = 1.9599639845400545$ verified by feeding it back
through $Phi$.

The exact side needs no approximation at all. With $p = 1\/2$ the binomial
cdf is a ratio of integers, $P(X <= k) = (sum_(i=0)^k C(n, i))\/2^n$, and the
samples carry the sum in `unsigned __int128`, exact through $n = 100$ where
$C(100, 50) approx 1.01 times 10^29$. The n = 40 cell: $C(40, 20) =
137846528820$, so $P(X <= 20) = 618679078298\/2^40 = 0.5626853438097896$,
against the continuity-corrected normal value $Phi(0.5\/sqrt(10)) =
0.5628164694185541$, an error of 1.31e-4.

#listing("math/samples/src/Ch19/clt.c", first: 40, last: 76, caption: [erfc to phi, the seeded digit source, and the exact 128-bit binomial cdf, clt.c])

#listing("math/samples/src/Ch19/clt.c", first: 119, last: 144, caption: [the 320-rung tail pinned against its exact integer sum, the z-table cells, and the n = 40 coin-flip cell, clt.c])

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*n*], [*exact P(X <= n\/2)*], [*normal approx*], [*error*]),
  [10], [0.623046875], [0.6240851830], [1.04e-3],
  [20], [0.5880985260], [0.5884683631], [3.70e-4],
  [40], [0.5626853438], [0.5628164694], [1.31e-4],
  [80], [0.5444639394], [0.5445103537], [4.64e-5],
  [100], [0.5397946187], [0.5398278373], [3.32e-5],
)

The error ladder is the theorem's price tag: each halving step of the error
needs roughly a doubling of $n$, and the Berry-Esseen inequality (Wasserman
2004, ch 5, by name) is the matching worst-case guarantee that the error of
the normal cdf approximation is $O(1\/sqrt(n))$, here observed shrinking
1.04e-3 to 3.32e-5, a factor 31 on a 10-fold $n$.

#diagram([binomial(40, 1\/2) as exact bars with the normal curve through the bar tops], length: 13pt, {
  // i in [11, 29] -> x in [1.5, 20]; probability in [0, 0.13] -> y in [0.7, 5.3]
  let px(i) = 1.5 + (i - 11.0) * 1.025
  let py(p) = 0.7 + p * 35.0
  cdraw.line((1.3, 0.7), (20.4, 0.7), stroke: luma(100), mark: (end: ">"))
  for i in (10, 15, 20, 25, 30) {
    cdraw.line((px(i), 0.62), (px(i), 0.78), stroke: luma(100))
    cdraw.content((px(i), 0.3), [#i], size: 6pt)
  }
  let pmf = ((12, 0.00508), (13, 0.01094), (14, 0.02111), (15, 0.03658),
    (16, 0.05716), (17, 0.08070), (18, 0.10312), (19, 0.11940), (20, 0.12537),
    (21, 0.11940), (22, 0.10312), (23, 0.08070), (24, 0.05716), (25, 0.03658),
    (26, 0.02111), (27, 0.01094), (28, 0.00508))
  for (i, p) in pmf {
    cdraw.line((px(i), 0.7), (px(i), py(p)), stroke: luma(140))
  }
  let curve = ((11, 0.00220), (12, 0.00514), (13, 0.01089), (14, 0.02085),
    (15, 0.03614), (16, 0.05669), (17, 0.08044), (18, 0.10329), (19, 0.12000),
    (20, 0.12616), (21, 0.12000), (22, 0.10329), (23, 0.08044), (24, 0.05669),
    (25, 0.03614), (26, 0.02085), (27, 0.01089), (28, 0.00514), (29, 0.00220))
  for k in range(curve.len() - 1) {
    cdraw.line((px(curve.at(k).at(0)), py(curve.at(k).at(1))),
      (px(curve.at(k + 1).at(0)), py(curve.at(k + 1).at(1))), stroke: luma(60))
  }
  cdraw.content((16.6, 5.1), [exact bars], size: 6pt)
  cdraw.content((16.6, 4.55), [normal curve], size: 6pt)
  cdraw.line((13.4, 5.05), (14.9, 5.05), stroke: luma(140))
  cdraw.line((13.4, 4.5), (14.9, 4.5), stroke: luma(60))
})

The two-number play: at $n = 40$ the exact and normal tails agree to
1.31e-4, while the raw, uncorrected normal tail at $Phi(0\/sqrt(10)) = 0.5$
would be off by 6.3e-2. The half-integer shift is worth 480 times the error.

#callout("note", "WHY THE +0.5", [A lattice variable takes integer values, a continuous density does not, and $P(X <= 20)$ corresponds to the normal mass up to 20.5, not 20.0. The continuity correction is the width of one lattice cell moved half a step, and dropping it costs two orders of magnitude, the 6.3e-2 above against the 1.31e-4 in the table.])

== estimators, bias, and variance

Bias is $E[hat(theta)] - theta$. For the sample mean on any population with
a mean, enumeration settles it exactly: with data drawn from the uniform
population {0, 1, 2}, mean 1 and variance $2\/3$, every ordered sample of
size $n$ can be listed, $3^n$ of them, and the estimator averaged without
any randomness at all. The divisor question mml flags in that margin note on
[printed p 192 / pdf p 198] falls out as exact fractions: the plug-in
variance with divisor $n$ averages $frac(n - 1, n) sigma^2$, the $n - 1$
divisor averages $sigma^2$ itself.

The dry run: at $n = 2$ there are 9 ordered samples, from (0, 0) to (2, 2).

+ The 9 sample means average exactly 1, unbiased, and their squares average
  $4\/3$, so the variance of the mean is $4\/3 - 1 = 1\/3 = sigma^2\/n$.
+ The plug-in variance averages $1\/3 = sigma^2\/2$ and the $n - 1$ divisor
  averages $2\/3 = sigma^2$. The mean squared error of $bar(x)$ is
  $0 + 1\/3$, the bias-variance decomposition checked as numbers, not
  algebra.
+ The ladder continues at $n = 3$ (27 samples, $4\/9$ against $2\/3$) and
  $n = 4$ (81 samples, $1\/2$ against $2\/3$), while the corrected divisor
  stays pinned at $2\/3$ for every rung.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*n*], [*samples*], [*E[plug-in, divisor n]*], [*E[divisor n - 1]*]),
  [2], [9], [$1\/3 = sigma^2\/2$], [$2\/3 = sigma^2$],
  [3], [27], [$4\/9$], [$2\/3$],
  [4], [81], [$1\/2$], [$2\/3$],
)

#listing("math/samples/src/Ch19/estimators.c", first: 32, last: 66, caption: [the odometer that enumerates every ordered sample and accumulates the estimator expectations, estimators.c])

#diagram([the exact distribution of the sample mean sharpening with n, uniform {0,1,2} population], length: 13pt, {
  // value in [0, 2] -> x in [1.5, 20]; probability -> y = 0.7 + 24 p
  let px(v) = 1.5 + v * 9.25
  let py(p) = 0.7 + p * 24.0
  cdraw.line((1.3, 0.7), (20.4, 0.7), stroke: luma(100), mark: (end: ">"))
  for v in (0, 1, 2) {
    cdraw.line((px(v), 0.62), (px(v), 0.78), stroke: luma(100))
    cdraw.content((px(v), 0.3), [#v], size: 6pt)
  }
  cdraw.line((px(1), 0.55), (px(1), 5.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(1) + 0.25, 5.85), [mu = 1], size: 6pt)
  for v in (0, 1, 2) {
    cdraw.line((px(v), 0.7), (px(v), py(1.0 / 3.0)), stroke: luma(140))
    cdraw.circle((px(v), py(1.0 / 3.0)), radius: 0.08, fill: luma(245), stroke: luma(140))
  }
  cdraw.content((3.1, py(1.0 / 3.0) + 0.35), [n = 1], size: 6pt)
  let n4 = ((0.0, 0.0123), (0.25, 0.0494), (0.5, 0.1235), (0.75, 0.1975),
    (1.0, 0.2346), (1.25, 0.1975), (1.5, 0.1235), (1.75, 0.0494), (2.0, 0.0123))
  for k in range(n4.len() - 1) {
    cdraw.line((px(n4.at(k).at(0)), py(n4.at(k).at(1))),
      (px(n4.at(k + 1).at(0)), py(n4.at(k + 1).at(1))), stroke: luma(100))
  }
  cdraw.content((px(1.38), py(0.015) + 0.28), [n = 4], size: 6pt)
  let n16 = ((0.625, 0.023), (0.688, 0.039), (0.75, 0.059), (0.812, 0.081),
    (0.875, 0.101), (0.938, 0.115), (1.0, 0.121), (1.062, 0.115),
    (1.125, 0.101), (1.188, 0.081), (1.25, 0.059), (1.312, 0.039),
    (1.375, 0.023))
  for k in range(n16.len() - 1) {
    cdraw.line((px(n16.at(k).at(0)), py(n16.at(k).at(1))),
      (px(n16.at(k + 1).at(0)), py(n16.at(k + 1).at(1))), stroke: luma(60))
  }
  cdraw.content((px(0.69), py(0.028) + 0.26), [n = 16], size: 6pt)
})

Maximum likelihood turns the model around: mml section 8.3.1 defines the
negative log-likelihood for data $x$ and parameter family $p(x | theta)$
[printed p 265 / pdf p 271] and minimizes it over $theta$. For the Bernoulli
count the derivative solve is one line, $k\/p - (n - k)\/(1 - p) = 0$, so
$hat(p) = k\/n$. For a Gaussian sample both stationary points close at once,
$hat(mu) = bar(x)$ and $hat(sigma)^2 = 1\/n sum (x_i - bar(x))^2$, the pair
mml derives for linear regression noise from the Gaussian log-likelihood of
eq 9.9, which drops every term that does not involve the parameters [printed
p 293 / pdf p 299]: the mean half at eqs 9.10-9.12 [printed p 294 / pdf p
300], the noise variance at eq 9.22, "the empirical mean of the squared
distances" [printed p 298 / pdf p 304].

The dry run: 7 successes in 10 draws, and the dataset {2, 5, 5, 8, 10}.

+ Bernoulli: $hat(p) = 0.7$ with log-likelihood -6.108643, and the neighbors
  0.69 and 0.71 sit 2.4e-3 lower, the solve is a real maximum.
+ Gaussian: $hat(mu) = 30\/5 = 6$, $hat(sigma)^2 = 38\/5 = 7.6$, profile
  negative log-likelihood 12.165063, minimal against 5.999, 6.001 and
  against 7.5, 7.7.
+ MAP with the conjugate prior: a Beta(3, 2) prior on the same 7/10 data
  gives posterior Beta(10, 5), mode $(10 - 1)\/(10 + 5 - 2) = 9\/13 =
  0.6923$, mean $10\/15 = 2\/3$, and normalizer $B(10, 5) = 9!4!\/14! =
  1\/10010$ as an exact integer ratio. The flat Beta(1, 1) prior returns
  mode 0.7, the MLE: eq 8.20 makes the posterior proportional to likelihood
  times prior [printed p 269 / pdf p 275], so a flat prior leaves the
  posterior proportional to the likelihood and the two maxima coincide.

#listing("math/samples/src/Ch19/estimators.c", first: 82, last: 114, caption: [the enumeration pins and the bernoulli mle solve, estimators.c])

#listing("math/samples/src/Ch19/estimators.c", first: 116, last: 152, caption: [the gaussian mle solve and the beta posterior mode with its exact normalizer, estimators.c])

The two-number play: same data, two priors, 0.6923 against 0.7. The
Beta(3, 2) prior contributes 2 successes and 1 failure worth of belief, and
the posterior mode lands between the prior's pull and the data.

#callout("pitfall", "THE BETA MODE NEEDS A, B > 1", [The closed form $(a - 1)\/(a + b - 2)$ for the Beta mode is only the interior maximum. With $a <= 1$ or $b <= 1$ the density is unbounded at an endpoint and the mode sits on the boundary of [0, 1]. The conjugate update keeps this safe once the data arrives with both outcomes, since $a + k >= 2$ and $b + n - k >= 2$ whenever the prior had $a, b >= 1$ and the sample shows at least one of each outcome.])

== hypothesis tests

A test is a partition of the sample space. The null hypothesis $H_0$ fixes a
distribution, the rejection region fixes which outcomes count against it,
the size is $alpha = P("reject" | H_0)$, the type II error at an alternative
is $beta = P("accept" | H_1)$, and the power is $1 - beta$. The p-value is
the probability under $H_0$ of an outcome at least as extreme as the one
observed, a number about the test, not a probability that $H_0$ is true.

The dry run: 9 successes in 10 fair-coin flips, then the region $x >= 15$
for 20 flips.

+ One-sided exact test: $P(X >= 9) = (C(10, 9) + C(10, 10))\/2^10 =
  11\/1024 = 0.0107421875$, binary-exact. The two-sided p-value doubles the
  small tail by symmetry, $11\/512 = 0.021484375$, and the doubling itself
  is checked as $p_2 = 2 p_1$ to the bit.
+ The region $x >= 15$ at $n = 20$ has numerator $15504 + 4845 + 1140 + 190
  + 20 + 1 = 21700$, so the size is $21700\/2^20 = 0.0207$. Under the fixed
  alternative $p = 0.7$ the same six terms weight $7^i 3^(20 - i)$ and sum
  to $41637082944748138372\/10^20$, power 0.4164, type II 0.5836.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*quantity*], [*value*], [*where*]),
  [size $alpha$], [$21700\/2^20 = 0.0207$], [under $H_0: p = 0.5$],
  [power $1 - beta$], [$0.4164$], [at $H_1: p = 0.7$],
  [type II $beta$], [$0.5836$], [same fixed alternative],
)

#listing("math/samples/src/Ch19/inference.c", first: 80, last: 117, caption: [the exact binomial test, the rejection region size, and the 128-bit power sum, inference.c])

#diagram([the two binomials behind the test, rejection region x >= 15 shaded darker], length: 13pt, {
  // i in [5.5, 20.5] -> x in [1.5, 20]; probability -> y = 0.7 + 24 p
  let px(i) = 1.5 + (i - 5.5) * 0.9667
  let py(p) = 0.7 + p * 24.0
  cdraw.line((1.3, 0.7), (20.4, 0.7), stroke: luma(100), mark: (end: ">"))
  for i in (5, 10, 15, 20) {
    cdraw.line((px(i), 0.62), (px(i), 0.78), stroke: luma(100))
    cdraw.content((px(i), 0.3), [#i], size: 6pt)
  }
  // rejection region boundary between 14 and 15
  cdraw.line((px(14.5), 0.7), (px(14.5), 5.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(16.2), 5.5), [reject x >= 15], size: 6pt)
  let p5 = ((6, 0.0370), (7, 0.0739), (8, 0.1201), (9, 0.1602), (10, 0.1762),
    (11, 0.1602), (12, 0.1201), (13, 0.0739), (14, 0.0370), (15, 0.0148),
    (16, 0.0046), (17, 0.0011))
  for (i, p) in p5 {
    cdraw.line((px(i), 0.7), (px(i), py(p)), stroke: luma(140))
  }
  let p7 = ((6, 0.0002), (7, 0.0010), (8, 0.0039), (9, 0.0120), (10, 0.0308),
    (11, 0.0654), (12, 0.1144), (13, 0.1643), (14, 0.1916), (15, 0.1789),
    (16, 0.1304), (17, 0.0716), (18, 0.0278), (19, 0.0068), (20, 0.0008))
  for (i, p) in p7 {
    cdraw.line((px(i), 0.7), (px(i), py(p)), stroke: luma(60))
  }
  cdraw.content((px(7.6), py(0.186)), [$H_0: p = 0.5$], size: 6pt)
  cdraw.content((px(18.1), py(0.163)), [$H_1: p = 0.7$], size: 6pt)
  cdraw.content((px(17.2), 1.15), [$alpha = 0.0207$], size: 6pt)
  cdraw.content((px(18.5), py(0.128)), [power 0.4164], size: 6pt)
})

The two-number play: the same test pays 0.0207 for a false alarm and 0.5836
for a missed detection at $p = 0.7$. Twenty flips simply cannot buy more,
and the power calculation prices that honestly before any data is spent.

#callout("note", "EXACT BEATS ASYMPTOTIC AT SMALL N", [The normal approximation to this very test would compare $(15 - 10)\/sqrt(5) = 2.236$ against 1.96 and declare significance at the 5% level, but the exact size is 0.0207, not 0.05, because no integer rejection region hits 0.05 exactly. With counts in the dozens the exact binomial sum is a few 128-bit additions, so there is no reason to borrow the normal's error.])

== confidence intervals

A 95% confidence interval for a mean with known variance $sigma^2$ is
$bar(x) ± z_(0.975) sigma\/sqrt(n)$ with $z_(0.975) = 1.9599639845400545$
from the last section. The reading is the coverage statement: across
repeated streams, 95% of the intervals contain the true mean, any single
interval does or does not, it carries no probability of its own. When
$sigma$ must itself be estimated the exchange $z -> t$ widens every interval
(Student's t, Wasserman 2004 by name). The $t$ density is the standard
normal with the estimated variance folded in, one shape per degrees of
freedom $n - 1$, wider than the normal and converging to it as $n$ grows:
$t_(0.975)(24) = 2.0638985$ against
$z_(0.975) = 1.9599640$, a widening of 5.3% at $n = 25$, and the samples
verify the table constant by integrating the $t$ density.

The dry run: 40 streams of $n = 25$ digits against the known population
values, mean 4.5, variance 8.25.

+ The half width is $1.9599639845400545 dot sqrt(8.25\/25) = 1.125914$, the
  same arithmetic in every stream since $n$ and $sigma$ are fixed.
+ Stream 0 sums to 119, mean 4.76, interval [3.6341, 5.8859], containing
  4.5.
+ Of the 40 intervals, 38 contain 4.5. The misses are stream 5, mean 3.28,
  and stream 35, mean 3.16, both low. Empirical coverage $38\/40 = 0.95$.

#listing("math/samples/src/Ch19/inference.c", first: 119, last: 149, caption: [the coverage count over 40 fixed streams, then the t quantile verified by integration, inference.c])

#diagram([the first 24 intervals against the true mean 4.5, stream 5 misses], length: 13pt, {
  // mean value in [2, 7] -> x in [1.8, 20]; stream t -> y = 6.2 - 0.24 t
  let px(v) = 1.8 + (v - 2.0) * 3.64
  for t in range(24) {
    let y = 6.2 - 0.24 * t
    let (lo, hi, cov) = ((3.634, 5.886, true), (3.474, 5.726, true),
      (2.914, 5.166, true), (2.594, 4.846, true), (2.794, 5.046, true),
      (2.154, 4.406, false), (2.354, 4.606, true), (3.474, 5.726, true),
      (3.674, 5.926, true), (3.674, 5.926, true), (3.554, 5.806, true),
      (3.474, 5.726, true), (3.034, 5.286, true), (4.354, 6.606, true),
      (2.834, 5.086, true), (3.274, 5.526, true), (3.354, 5.606, true),
      (2.874, 5.126, true), (4.434, 6.686, true), (3.314, 5.566, true),
      (2.754, 5.006, true), (2.954, 5.206, true), (3.994, 6.246, true),
      (3.394, 5.646, true)).at(t)
    if cov {
      cdraw.line((px(lo), y), (px(hi), y), stroke: luma(60))
    } else {
      cdraw.line((px(lo), y), (px(hi), y),
        stroke: (paint: luma(140), dash: "dashed"))
      cdraw.content((px(lo) - 0.85, y), [stream 5], size: 6pt)
    }
  }
  let xm = px(4.5)
  cdraw.line((xm, 0.1), (xm, 6.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((xm + 0.25, 6.55), [mu = 4.5], size: 6pt)
  cdraw.content((1.6, 6.2), [0], size: 6pt)
  cdraw.content((1.6, 0.52), [23], size: 6pt)
  cdraw.content((11.0, -0.5), [stream mean scale 2 to 7], size: 6pt)
})

The two-number play: nominal coverage 0.95, counted coverage 38 of 40. The
count is an integer, so the empirical rate snaps to 0.95 exactly here, one
quiet accident of the fixed streams worth reporting as what it is.

== least squares statistics

Regression closes the chapter where the linear algebra lives, chapter
#xref-to("math", "inner"). Least squares fits $y = a + b x$ by minimizing the
residual sum of squares, and setting the two partial derivatives to zero
gives the normal equations $b = S_(x y)\/S_(x x)$ and $a = bar(y) - b bar(x)$
in terms of the centered sums $S_(x y) = sum (x_i - bar(x))(y_i - bar(y))$
and $S_(x x) = sum (x_i - bar(x))^2$. The same pair falls out of maximum
likelihood: mml section 9.2.1 shows the Gaussian-noise likelihood of the
linear model reduces to the squared residual loss, eq 9.9 [printed p 293 /
pdf p 299], so the least-squares line is the MLE under Gaussian noise, and
the MAP version of that fit is ridge regularization in disguise (mml
sections 9.2.3-9.2.4 [printed pp 300-302 / pdf pp 306-308]).

The dry run: $x = 0..6$ against $y = 3, 4, 8, 13, 12, 18, 19$, integers
throughout.

+ Centered sums: $S_(x x) = 28$, $S_(x y) = 80$, $S_(y y) = 240$, so
  $b = 80\/28 = 20\/7$ and $a = 11 - 3 dot 20\/7 = 17\/7$, both exact
  rationals.
+ $R^2 = S_(x y)^2\/(S_(x x) S_(y y)) = 6400\/6720 = 20\/21 = 0.9524$,
  computed from the same three integers.
+ The residuals sum to exactly 0.0 in the doubles, the $x$-weighted residual
  sum is 5.3e-15, residual noise not an algebra failure, the residual sum of
  squares is $240\/21 = 11.4286$, and $1 - "SSR"\/"SST"$ returns 20/21 to
  1e-12, the ANOVA identity closing on the numbers.

#listing("math/samples/src/Ch19/inference.c", first: 151, last: 180, caption: [integer normal equations, R^2 as an integer ratio, and the orthogonality pins, inference.c])

#diagram([the fit y = 17\/7 + 20\/7 x through seven integer points with residuals], length: 13pt, {
  // x in [0, 6] -> canvas [1.5, 20]; y in [0, 21] -> [0.6, 5.6]
  let px(v) = 1.5 + v * 3.083
  let py(v) = 0.6 + v * 0.2381
  cdraw.line((1.3, 0.6), (20.4, 0.6), stroke: luma(100), mark: (end: ">"))
  for v in (0, 2, 4, 6) {
    cdraw.line((px(v), 0.52), (px(v), 0.68), stroke: luma(100))
    cdraw.content((px(v), 0.2), [#v], size: 6pt)
  }
  cdraw.line((1.3, 0.6), (1.3, 5.9), stroke: luma(100), mark: (end: ">"))
  let pts = ((0, 3), (1, 4), (2, 8), (3, 13), (4, 12), (5, 18), (6, 19))
  for (x, y) in pts {
    let fy = 17.0 / 7.0 + 20.0 / 7.0 * x
    cdraw.line((px(x), py(y)), (px(x), py(fy)), stroke: luma(140))
    cdraw.circle((px(x), py(y)), radius: 0.09, fill: luma(205), stroke: luma(60))
  }
  cdraw.line((px(0), py(17.0 / 7.0)), (px(6), py(19.0 + 4.0 / 7.0)),
    stroke: luma(60))
  cdraw.content((px(2.1), py(21.0)), [fit 17\/7 + 20\/7 x], size: 6pt)
  cdraw.content((px(3.15), py(13.0) + 0.3), [(3, 13), r = 2], size: 6pt)
  cdraw.content((px(5.9), py(0.9)), [x], size: 6pt)
  cdraw.content((0.75, 5.75), [y], size: 6pt)
})

The two-number play: the least-squares slope is $20\/7 = 2.857$, the
endpoint slope $(19 - 3)\/6$ is 2.667. Orthogonality, not compromise, is
what the normal equations buy, the fit line honors the center of the data
more than its ends.

Chapter #xref-to("math", "roots") turns from inference to solvers, and the
transition is natural: every derivative solve in this chapter became a
number because the model was small enough to close by hand, and root finding
is what carries that step when it does not.

sources: mml-book draft 2024-01-15, ch 6 sec 6.4 pp 186-197 (statistics
definitions, eqs 6.41-6.45, 6.58, the N versus N-1 margin note), ch 8 sec
8.3 pp 264-269 (negative log-likelihood, MAP estimation), ch 9 sec 9.2 pp
292-302 (gaussian likelihood eq 9.9, MAP as regularization), verified
against ref/mml-book.pdf pp 192-203, 270-275, 298-308; NIST DLMF section
7.2 eq 7.2.E2, https://dlmf.nist.gov/7.2, and cppreference "erfc, erfcf,
erfcl", https://en.cppreference.com/c/numeric/math/erfc, both fetched
2026-09-21; Wasserman, All of Statistics, Springer 2004, and Casella and
Berger, Statistical Inference, 2nd ed, Duxbury 2002, cited by name for the
LLN, CLT, Chebyshev, Berry-Esseen, t intervals, and testing chapters. Probed
on this machine the same day. Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch19`,
63 checks in chapter 19 of the math suite.
