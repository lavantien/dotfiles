#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= probability and distributions

Probability starts where #xref-to("math", "combinatorics") counting stops:
a sample space small enough to hold in a byte, events as bitmasks, and
weights that must obey three axioms before anything deserves the name
chance. This chapter builds the tower in six moves: the axioms and the
random variable as a lookup function, conditioning and Bayes inversion in
exact rationals, the expectation and variance machinery of discrete
variables, the binomial and Poisson families with exact integer kernels,
the gaussian with standardization and mixture algebra carried by
quadrature, and the conjugate beta update plus the change-of-variables
rule that moves densities between scales. Every behavioral claim below is
one of the 60 checks in the 4 samples of chapter 18 or a sentence quoted
from the mml-book draft of 2024-01-15, chapter 6, cached at
ref/mml-book.pdf and reverified on this machine 2026-09-22. The dsa book
treats randomness as an algorithm input, see #xref-to("dsa", "numerical")
for the simpson driver reused here, while this chapter treats it as a
measure first.

== probability spaces

The mml book builds probability on three objects. The sample space $Omega$
is "the set of all possible outcomes of the experiment". The event space
$cal(A)$ collects the subsets of $Omega$ we can observe, "for discrete
probability distributions $cal(A)$ is often the power set of $Omega$". The
probability
$P$ attaches to each event a number with $P(A) in [0, 1]$ and
$P(Omega) = 1$, Kolmogorov's axioms. For a finite space all three live in
one byte here: $Omega$ is the integers 0 to 7, an event is a predicate over
a 3-bit mask, and $P$ is a sum of weights.

A random variable $X : Omega -> cal(T)$ moves probability to a target
space. The book's margin is blunt: "The name 'random variable' is a great
source of misunderstanding as it is neither random nor is it a variable. It
is a function." Its own probability comes from the pre-image, $P_X (S) =
P(X in S) = P(X^(-1)(S))$, so $X$ is a lookup table and the distribution
is the weight it pushes forward.

The dry run: three fair coins give the 8-outcome space, every weight 1/8.
Events are predicates on the mask: coin 1 heads is $b & 1 != 0$, at least
two heads is a popcount of at least 2.

+ Kolmogorov holds by enumeration: the full event measures 8/8 = 1, the
  empty event 0, and complement pairs like "at least two heads" with "at
  most one" sum to 4/8 + 4/8 = 1.
+ Inclusion-exclusion for two events, the counting tie-back, reads
  $P(A union B) = P(A) + P(B) - P(A and B)$, here 4/8 + 4/8 - 2/8 = 6/8.
+ The three-event version is $3 dot 4/8 - 3 dot 2/8 + 1/8 = 7/8$,
  matching the direct count of masks 1 through 7.

Equally likely is a special weighting, not the definition. Two fair dice
make 36 outcomes of weight 1/36 each and $P("sum" = 7) = 6/36 = 1/6$. The
book's funfair game, example 6.1, weights instead: draw two coins with
replacement from a bag where "a draw returns at random a \$ with
probability 0.3", and count the dollars drawn. With $mu = 3/10$ the pmf is
$P(X = 2) = mu^2 = 9/100$, $P(X = 1) = 2 mu (1 - mu) = 42/100$,
$P(X = 0) = (1 - mu)^2 = 49/100$, summing to 1. The same two-draw event
under a uniform weighting would carry 1/4, and the sample pins the
difference: weights change answers.

#listing("math/samples/src/Ch18/spaces.c", first: 71, last: 92, caption: [spaces kernel, the measure as a masked weight sum])

#listing("math/samples/src/Ch18/spaces.c", first: 171, last: 186, caption: [weighted funfair space, the example 6.1 pmf in exact rationals])

#diagram([bitmask events on the 8-outcome coin space, weight 1/8 each], length: 13pt, {
  let bits(b) = {
    let s = str(b, base: 2)
    while s.len() < 3 { s = "0" + s }
    s
  }
  for b in range(8) {
    let x = 0.4 + b * 1.55
    cdraw.rect((x, 4.6), (x + 1.45, 5.6), stroke: luma(140), radius: 0.02, fill: if calc.odd(b) { luma(205) } else { luma(245) })
    cdraw.content((x + 0.72, 5.1), bits(b), size: 6pt)
    cdraw.content((x + 0.72, 4.25), [1/8], size: 6pt)
  }
  for b in range(8) {
    let x = 0.4 + b * 1.55
    cdraw.rect((x, 2.4), (x + 1.45, 3.4), stroke: luma(140), radius: 0.02, fill: if calc.rem(b, 4) >= 2 { luma(205) } else { luma(245) })
    cdraw.content((x + 0.72, 2.9), bits(b), size: 6pt)
  }
  cdraw.content((0.2, 5.95), [omega as 3-bit masks, shaded = event holds], size: 6.5pt)
  cdraw.content((0.2, 3.7), [top row: coin 1 heads, bottom row: coin 2 heads], size: 6.5pt)
  cdraw.content((0.4, 1.7), [P(coin1) = 4/8, P(coin2) = 4/8, P(both) = 2/8, P(union) = 6/8 = 3/4], size: 6.5pt)
  cdraw.line((0.4, 4.6), (0.4 + 8 * 1.55, 4.6), stroke: luma(100), mark: (end: ">"))
})

#callout("note", "random variables are deterministic", [The distribution of $X$ is $P ∘ X^(-1)$ in the general statement, the book calls it the law, but on a finite space it is simpler: a lookup table from outcomes to states plus the weight each outcome carries. Two random variables on the same space can share every weight and differ only in the lookup, which is why $X$ and $X^2$ in the next section can be dependent while their covariance vanishes.])

== conditional probability and Bayes

Conditioning shrinks the denominator. For a joint table with counts
$n_(i j)$ the book gives $P(Y = y_j | X = x_i) = n_(i j) / c_i$, the cell
over its column sum, and the two fundamental rules follow: the sum rule
$p(x) = sum_y p(x, y)$ marginalizes, the product rule $p(x, y) = p(y | x)
p(x)$ factorizes. Bayes is the product rule read twice, and the book
labels each slot:

$ underbrace(p(x | y), "posterior") = (underbrace(p(y | x), "likelihood") underbrace(p(x), "prior")) / underbrace(p(y), "evidence") $

The evidence is itself an expectation, $p(y) = integral p(y | x) p(x) dif
x = E_X [p(y | x)]$, the expected likelihood under the prior. The book is
strict about vocabulary: the likelihood "is not a distribution in x, but
only in y".

The dry run: a screening table fixed at 1000 people, prevalence 1/100,
sensitivity 9/10, false-positive rate 1/10.

+ The joint counts are 9 and 1 for the ten sick, 99 and 891 for the 990
  well. Marginals: $P("sick") = 1/100$ and $P("+") = 108/1000 = 27/250$.
+ Bayes inverts the table: $P("sick" | "+") = 9/108 = 1/12$, about 8.3%.
+ A second independent positive applies the same rule to the 1/12 prior
  and lands on 9/20. Evidence accumulates multiplicatively.

The two-number play: the test is 90% sensitive, yet one positive means a
1-in-12 chance of sickness. The gap is the base rate, and no accuracy
figure closes it without the evidence denominator.

Independence is a factorization, mml definition 6.10: $p(x, y) = p(x)
p(y)$. The funfair draws satisfy it, $9/100 = (3/10)^2$. Uncorrelated is
weaker. Example 6.5 takes $X$ uniform on {-1, 0, 1} and $Y = X^2$: the
covariance is $"Cov"[x, y] = E[x y] - E[x] E[y] = E[x^3] = 0$ by symmetry,
but the pair is dependent since $P(X = 1, Y = 0) = 0$ against the product
$1/3 dot 1/3 = 1/9$. Covariance, the book says, "measures only linear
dependence". Correlation normalizes it, $"corr"[x, y] = "Cov"[x, y] / sqrt(V[x]
V[y]) in [-1, 1]$, and on the screening indicators the sample pins
$"corr"^2 = 44/669$ exactly, inside the Cauchy-Schwarz bound.

#listing("math/samples/src/Ch18/bayes.c", first: 75, last: 102, caption: [bayes kernel, condition and invert over one fixed joint table])

#listing("math/samples/src/Ch18/bayes.c", first: 137, last: 146, caption: [two-number play, one positive then a second, exact rationals])

#diagram([bayes tree for the screening table, counts out of 1000], length: 13pt, {
  let box(x, y, w, t, fill) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: fill, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, size: 6pt)
  }
  box(0.3, 4.7, 3.2, [1000 people], luma(235))
  box(4.6, 6.1, 3.4, [sick 10], luma(245))
  box(4.6, 3.3, 3.4, [well 990], luma(245))
  box(8.7, 6.7, 3.0, [test+ 9], luma(205))
  box(8.7, 5.5, 3.0, [test- 1], luma(245))
  box(8.7, 3.9, 3.0, [test+ 99], luma(205))
  box(8.7, 2.7, 3.0, [test- 891], luma(245))
  box(12.5, 5.2, 3.3, [evidence 108], luma(235))
  box(12.5, 3.0, 3.3, [P(sick|+) = 1/12], luma(205))
  cdraw.line((3.5, 5.4), (4.6, 6.4), stroke: luma(100))
  cdraw.line((3.5, 4.9), (4.6, 3.9), stroke: luma(100))
  cdraw.line((8.0, 6.7), (8.7, 7.0), stroke: luma(100))
  cdraw.line((8.0, 6.4), (8.7, 6.1), stroke: luma(100))
  cdraw.line((8.0, 3.9), (8.7, 4.2), stroke: luma(100))
  cdraw.line((8.0, 3.6), (8.7, 3.3), stroke: luma(100))
  cdraw.line((11.7, 6.9), (12.5, 5.8), stroke: luma(140))
  cdraw.line((11.7, 4.1), (12.5, 5.5), stroke: luma(140))
  cdraw.line((14.1, 5.2), (14.1, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.9, 5.9), [prior 1/100], size: 6pt)
  cdraw.content((1.9, 4.1), [99/100], size: 6pt)
  cdraw.content((8.2, 7.3), [9/10], size: 6pt)
  cdraw.content((8.2, 5.9), [1/10], size: 6pt)
  cdraw.content((8.2, 4.6), [1/10], size: 6pt)
  cdraw.content((8.2, 3.0), [9/10], size: 6pt)
})

== discrete random variables

For a discrete target space the distribution is the probability mass
function $P(X = x)$, and probability beyond a point rides the cumulative
distribution function $F_X (x) = P(X <= x)$. The expected value of a
function of $X$, mml definition 6.3, is $E_X [g(x)] = sum_(x in cal(X))
g(x) p(x)$, and the mean is the identity special case. Two properties
carry most of the load: linearity, $E[a g(x) + b h(x)] = a E[g(x)] + b
E[h(x)]$, needs no independence assumption, and the variance has three
faces. The definition is $V_X [x] = E[(x - mu)^2]$, the raw-score form is

$ V_X [x] = E_X [x^2] - (E_X [x])^2 , $

and the pairwise identity $1/N^2 sum_(i,j) (x_i - x_j)^2 = 2 [1/N sum_i
x_i^2 - (1/N sum_i x_i)^2]$ rewrites the empirical variance as distances
from the center.

The dry run: two fair dice, $X$ the sum, counts 1, 2, 3, 4, 5, 6, 5, 4,
3, 2, 1 over the 36 outcomes.

+ Direct summation gives $E[X] = 252/36 = 7$, and linearity agrees without
  summing: $E[d_1] + E[d_2] = 7/2 + 7/2$.
+ $E[X^2] = 1974/36 = 329/6$, so both variance routes land on $329/6 - 49
  = 35/6$.
+ The cdf stops at $F(7) = 21/36 = 7/12$.
+ On the fixed sample {0, 2, 2, 5, 6} the pairwise sum is 240 over 25
  pairs, $48/5$, which is twice the empirical variance $24/5$.

Linearity over indicators is the quiet superpower. The expected heads in
3 tosses is $1/2 + 1/2 + 1/2 = 3/2$ with no case analysis, and the
expected fixed points of a random permutation of 4 elements is
$4 dot 1/4 = 1$, which the sample confirms by averaging over all 24
permutations, 24 fixed points in total. The book's geometric coda ties
covariance to #xref-to("math", "inner"): for zero-mean variables
$⟨X, Y⟩ := "Cov"[x, y]$ is an inner product, the length $norm(X) = sqrt(V[x])$
is the standard deviation, and the correlation is the cosine of the angle
between two random variables.

#listing("math/samples/src/Ch18/discrete.c", first: 89, last: 105, caption: [moment loop, E[X^2] and both variance routes on the dice table])

#listing("math/samples/src/Ch18/discrete.c", first: 128, last: 147, caption: [indicator bound, all 24 permutations enumerated against 4 times 1/4])

#diagram([two-coin pmf bars with cdf steps, heights exact], length: 13pt, {
  // pmf 0.49, 0.42, 0.09 scaled by 6, cdf 0.49, 0.91, 1.00 scaled by 6
  cdraw.line((0.6, 0.6), (10.4, 0.6), stroke: luma(140), mark: (end: ">"))
  cdraw.line((0.6, 0.6), (0.6, 6.9), stroke: luma(140), mark: (end: ">"))
  cdraw.rect((1.2, 0.6), (2.6, 3.54), fill: luma(205), stroke: luma(100))
  cdraw.rect((3.2, 0.6), (4.6, 3.12), fill: luma(205), stroke: luma(100))
  cdraw.rect((5.2, 0.6), (6.6, 1.14), fill: luma(205), stroke: luma(100))
  cdraw.content((1.9, 3.8), [0.49], size: 6pt)
  cdraw.content((3.9, 3.4), [0.42], size: 6pt)
  cdraw.content((5.9, 1.4), [0.09], size: 6pt)
  cdraw.content((1.9, 0.25), [0], size: 6pt)
  cdraw.content((3.9, 0.25), [1], size: 6pt)
  cdraw.content((5.9, 0.25), [2], size: 6pt)
  cdraw.content((0.2, 7.2), [dollar count X], size: 6.5pt)
  cdraw.line((0.9, 3.54), (2.9, 3.54), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((2.9, 3.54), (2.9, 5.46), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((2.9, 5.46), (4.9, 5.46), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.9, 5.46), (4.9, 6.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.9, 6.0), (6.6, 6.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((7.0, 5.7), [F(1) = 91/100], size: 6pt)
  cdraw.content((7.0, 6.3), [F(2) = 1], size: 6pt)
  cdraw.content((7.2, 3.9), [cdf steps], size: 6pt)
  cdraw.content((7.2, 2.2), [pmf bars], size: 6pt)
})

== binomial and Poisson families

The bernoulli is one weighted coin, $p(x | mu) = mu^x (1 - mu)^(1 - x)$
for $x in {0, 1}$, with $E[x] = mu$ and $V[x] = mu (1 - mu)$. The
binomial, mml example 6.9, counts the successes in $N$ independent draws:

$ p(m | N, mu) = binom(N, m) mu^m (1 - mu)^(N - m), quad E[m] = N mu, quad V[m] = N mu (1 - mu) $

The binomial coefficients come from chapter 14's Pascal kernel, so the
whole family is counting plus one parameter. For rational $mu$ the pmf is
exact integer arithmetic.

The dry run: $N = 15$, $mu = 3/10$, the funfair coin drawn 15 times.

+ Each pmf entry is $binom(15, m) 3^m 7^(15 - m)$ over the common
  denominator $10^15$, and the numerators sum to $(3 + 7)^15 = 10^15$
  exactly, the binomial theorem as a normalization check.
+ $E[m] = 45/10 = 9/2$ and $E[m^2] - E[m]^2 = 63/20$, both matching the
  closed forms $N mu$ and $N mu (1 - mu)$.
+ The mode is $m = 4$ with pmf 0.218623131339795, and the neighbors sit
  below it on both sides.

The Poisson is what the binomial becomes when successes are rare: fix
$lambda = N mu$ and let $N$ grow, and the pmf converges to $e^(-lambda)
lambda^m \/ m!$. The sample watches it happen at $lambda = 2$, comparing
$(1 - mu)^N$ against $e^(-2)$ for $N = 50, 100, 200$. The gaps are
-5.449e-3, -2.716e-3, -1.356e-3, roughly halving each time $N$ doubles,
and at $N = 200$ the $m = 1$ entry is already within 4.557e-6 of
$2 e^(-2)$. No sampling noise, just the limit observed on fixed traces.

#listing("math/samples/src/Ch18/discrete.c", first: 149, last: 183, caption: [binomial kernel, exact numerators over 10^15 with closed-form moments])

#listing("math/samples/src/Ch18/discrete.c", first: 185, last: 198, caption: [poisson limit, the gap to e^minus2 halving as n doubles])

#diagram([binomial pmf bars for N = 15, mu = 0.3, mean line at 4.5], length: 13pt, {
  // heights are pmf/0.22*6: 0.13, 0.83, 2.50, 4.64, 5.96, 5.62, 4.02, 2.21, 0.95, 0.32, 0.08
  cdraw.line((0.5, 0.6), (13.5, 0.6), stroke: luma(140), mark: (end: ">"))
  cdraw.line((0.5, 0.6), (0.5, 6.9), stroke: luma(140), mark: (end: ">"))
  let bars = ((0, 0.13), (1, 0.83), (2, 2.50), (3, 4.64), (4, 5.96), (5, 5.62), (6, 4.02), (7, 2.21), (8, 0.95), (9, 0.32), (10, 0.08))
  for (k, h) in bars {
    cdraw.rect((0.9 + k, 0.6), (0.9 + k + 0.8, 0.6 + h), fill: luma(205), stroke: luma(100))
  }
  cdraw.line((5.8, 0.6), (5.8, 6.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((5.8, 6.95), [E = 4.5], size: 6pt)
  cdraw.content((4.2, 6.3), [0.2186], size: 6pt)
  cdraw.content((0.3, 7.25), [p], size: 6pt)
  cdraw.content((1.3, 0.25), [0], size: 6pt)
  cdraw.content((6.3, 0.25), [5], size: 6pt)
  cdraw.content((11.3, 0.25), [10], size: 6pt)
  cdraw.content((11.4, 3.0), [mode 4], size: 6pt)
  cdraw.content((11.4, 2.4), [V = 63/20], size: 6pt)
})

== continuous densities and the gaussian

A pdf, mml definition 6.1, is any $f >= 0$ with $integral f(x) dif x = 1$,
and probability is area, $P(a <= X <= b) = integral_a^b f(x) dif x$. Point
probability evaporates, $P(X = x)$ is "a set of measure zero", and the cdf
$F_X (x) = P(X <= x)$ carries the recoverable information. Normalization
does not cap the height: the book's uniform on [0.9, 1.6] has density
$1/0.7 approx 1.43$, greater than 1 everywhere it lives.

The gaussian is the family everything else wants to be:

$ p(x | mu, sigma^2) = 1/(sqrt(2 pi sigma^2)) exp(-((x - mu)^2)/(2 sigma^2)) $

The central limit theorem, the book notes, makes it "arise naturally when
we consider sums of independent and identically distributed random
variables". Two algebraic facts do the rest of its work. Standardization:
any gaussian probability is a standard normal one, since $(X - mu) /
sigma$ is $cal(N)(0, 1)$, so one table of $Phi$ values serves every
$(mu, sigma)$ pair. Affine closure: a mixture of two gaussian densities
with weight $alpha$, theorem 6.12, keeps the weighted mean $E[x] = alpha
mu_1 + (1 - alpha) mu_2$ and a variance with a between-component term,

$ V[x] = [alpha sigma_1^2 + (1 - alpha) sigma_2^2] + [alpha mu_1^2 + (1 - alpha) mu_2^2] - [alpha mu_1 + (1 - alpha) mu_2]^2 . $

Marginals and conditionals of a joint gaussian stay gaussian, the
computation the Kalman filter runs every step, and sampling a general
gaussian is a Cholesky factor away from the standard one, #xref-to("math",
"decomp").

The dry run: simpson quadrature on the standard density, 4000 panels, with
expectations pinned to 1e-12 above the measured error 5e-15. The error
theory itself is #xref-to("math", "quadrature") territory.

+ The central bands are 0.6826894921370857, 0.9544997361036417,
  0.9973002039367398, the 68-95-99.7 rule with all digits.
+ For $X tilde cal(N)(1, 0.25)$ the tail $P(X <= 2)$ equals $Phi(2)$, and
  the central band $P(|X - 1| <= 1)$ equals the standard $P(|Z| <= 2)$ to
  1e-12, standardization as a pinned identity rather than a slogan.
+ Moments by quadrature: $E[X] = 1$ and $E[X^2] = 1.25$, so $V = 0.25$.
+ The mixture $0.3 cal(N)(-1, 0.5) + 0.7 cal(N)(2, 1.5)$ integrates to 1
  with mean 1.1 and variance 3.09, and theorem 6.12's closed forms agree
  to 1e-9.

#listing("math/samples/src/Ch18/gaussian.c", first: 81, last: 92, caption: [density and simpson driver, the quadrature leg every check rides])

#listing("math/samples/src/Ch18/gaussian.c", first: 133, last: 148, caption: [band and standardization checks, erf-based truth at 1e-12])

#listing("math/samples/src/Ch18/gaussian.c", first: 155, last: 167, caption: [theorem 6.12 by quadrature, closed forms against the integrals])

#callout("pitfall", "densities are not probabilities", [A pmf entry is a probability and cannot exceed 1. A pdf value is a density and routinely does: the uniform on [0.9, 1.6] sits at height 1.43 across an interval of length 0.7, and $1.43 dot 0.7 = 1$. Only the integral over a set is a probability. Treating $p(x)$ as $P(X = x)$ is the standing error, and for continuous variables that quantity is exactly zero.])

#diagram([standard gaussian with the 1, 2, and 3 sigma bands], length: 13pt, {
  // phi scaled by 12, z mapped x = 4 + 1.2 z, points at 0.5 steps:
  // 12*phi = 4.79, 4.22, 2.90, 1.55, 0.65, 0.21, 0.05 from z = 0 outward
  let pts = ((0.4, 0.05), (1.0, 0.21), (1.6, 0.65), (2.2, 1.55), (2.8, 2.90), (3.4, 4.22), (4.0, 4.79), (4.6, 4.22), (5.2, 2.90), (5.8, 1.55), (6.4, 0.65), (7.0, 0.21), (7.6, 0.05))
  cdraw.line((0.2, 0.6), (7.8, 0.6), stroke: luma(140), mark: (end: ">"))
  let prev = pts.first()
  for p in pts.slice(1) {
    cdraw.line(prev, p, stroke: luma(60))
    prev = p
  }
  for z in (1, 2, 3) {
    let x = 4.0 - 1.2 * z
    cdraw.line((x, 0.6), (x, 3.6), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.line((8.0 - x, 0.6), (8.0 - x, 3.6), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.content((x, 0.25), [-#z], size: 6pt)
    cdraw.content((8.0 - x, 0.25), [#z], size: 6pt)
  }
  cdraw.content((4.0, 0.25), [0], size: 6pt)
  cdraw.content((3.9, 5.15), [0.3989], size: 6pt)
  cdraw.content((8.7, 2.6), [1σ 0.6827], size: 6pt)
  cdraw.content((8.7, 2.0), [2σ 0.9545], size: 6pt)
  cdraw.content((8.7, 1.4), [3σ 0.9973], size: 6pt)
})

== conjugacy, the exponential family, and change of variables

Bayesian updating multiplies a prior by a likelihood, and conjugacy, mml
definition 6.13, is when "the posterior is of the same form/type as the
prior", so the update is arithmetic on parameters instead of integration.
The beta prior over a coin weight,

$ p(mu | alpha, beta) = (Gamma(alpha + beta))/(Gamma(alpha) Gamma(beta)) mu^(alpha - 1) (1 - mu)^(beta - 1) , $

is conjugate to the binomial. For integer $alpha$ and $beta$ the gamma
normalizer collapses to factorials, $integral_0^1 mu^(a-1) (1 - mu)^(b-1)
dif mu = ((a-1)! (b-1)!)/((a + b - 1)!)$, and every moment becomes exact
integer arithmetic.

The dry run: prior Beta(2, 3), then 3 heads in 5 flips.

+ The prior normalizer is $4! / (1! dot 2!) = 12$, the mean is
  $E[mu] = 2/5$, and the variance is $1/25$, matching the closed form
  $alpha beta / ((alpha + beta)^2 (alpha + beta + 1))$.
+ The likelihood $mu^3 (1 - mu)^2$ lifts the exponents, so the posterior
  is $"Beta"(2 + 3, 3 + 5 - 3) = "Beta"(5, 5)$ with normalizer $9! / (4!
  4!) = 630$ and mean $1/2$.
+ The posterior density at $mu = 1/2$ is $630 / 2^8 = 315/128$, exactly
  2.4609375, and the mean $1/2$ lands between the prior mean $2/5$ and
  the data mean $3/5$.

Conjugacy is a corollary of a bigger structure. The exponential family,
$p(x | theta) = h(x) exp(theta^top phi(x) - A(theta))$, carries all
parameter dependence through the sufficient statistics $phi(x)$, and the
Fisher-Neyman theorem says these are the only families with
finite-dimensional sufficient statistics under repeated sampling. The
gaussian sits inside with $phi(x) = vec(x, x^2)$ and natural parameters
$theta = vec(mu/sigma^2, -1/(2 sigma^2))$, which the sample verifies as
the identity $theta^top phi(x) + (x - mu)^2 / (2 sigma^2) = mu^2 / (2
sigma^2)$ at three points. The bernoulli sits inside with $phi(x) = x$ and
$theta = log(mu / (1 - mu))$, whose inverse map is the sigmoid.

Change of variables moves distributions between scales. The
distribution-function technique for $Y = X^2$ under $f(x) = 3x^2$ on
[0, 1], mml example 6.16, runs $F_Y (y) = P(X^2 <= y) = F_X (y^(1/2)) =
y^(3/2)$, so

$ f(y) = 3/2 y^(1/2) , $

pinned by quadrature: the new density integrates to 1, $E[Y] = E[X^2] =
3/5$ from either side of the transformation, and $F_Y (1/4) = 1/8$. The
general rule, theorem 6.16, substitutes the inverse and multiplies by the
absolute Jacobian determinant, $f(y) = f_x (U^(-1)(y)) dot |det (partial
U^(-1)(y) / partial y)|$. The affine case is the one to memorize: $Y = a X
+ b$ divides the density by $|a|$ at the reflected point, moves the mean
to $a mu + b$, and scales the variance by $a^2$, all three checked on
$Y = 2 X + 1$ with $V[Y] = 4 dot 3/80 = 3/20$. Theorem 6.15 runs the
pipeline backwards, $F_X (X)$ is uniform, which is how inverse cdf
sampling works.

Chapter 19, #xref-to("math", "statistics"), turns this vocabulary into
inference: empirical means and covariances, maximum likelihood through
the exponential family's concave log-likelihood, and posterior updating
at scale.

#listing("math/samples/src/Ch18/gaussian.c", first: 200, last: 224, caption: [beta-binomial update, exact factorial arithmetic from prior to posterior])

#listing("math/samples/src/Ch18/gaussian.c", first: 181, last: 190, caption: [change-of-variables checks, squared and affine pushes pinned by quadrature])

#callout("verify", "the posterior sandwich", [Conjugate updating cannot jump past the data. The prior mean is $2/5$, the observed head rate is $3/5$, and the posterior mean $1/2$ lands strictly between them, closer to the data because five flips outweigh a weak prior. The sample asserts the sandwich $2/5 < 1/2 < 3/5$ in exact rationals, and the same ordering holds for every conjugate update, a cheap sanity check on any Bayesian implementation.])

#diagram([prior, likelihood, and posterior on the coin weight], length: 13pt, {
  // mu in [0,1] mapped to x = 1 + 14 mu, densities scaled by 2.4
  cdraw.line((0.8, 0.6), (15.6, 0.6), stroke: luma(140), mark: (end: ">"))
  cdraw.line((0.8, 0.6), (0.8, 6.6), stroke: luma(140), mark: (end: ">"))
  let prior = ((1.0, 0.0), (2.4, 2.33), (3.8, 3.69), (5.2, 4.23), (6.6, 4.15), (8.0, 3.60), (9.4, 2.76), (10.8, 1.81), (12.2, 0.92), (13.6, 0.26), (15.0, 0.0))
  let like = ((1.0, 0.0), (2.4, 0.10), (3.8, 0.61), (5.2, 1.59), (6.6, 2.76), (8.0, 3.75), (9.4, 4.15), (10.8, 3.70), (12.2, 2.46), (13.6, 0.87), (15.0, 0.0))
  let post = ((1.0, 0.0), (2.4, 0.10), (3.8, 0.99), (5.2, 2.94), (6.6, 5.02), (8.0, 5.91), (9.4, 5.02), (10.8, 2.94), (12.2, 0.99), (13.6, 0.10), (15.0, 0.0))
  let prev = prior.first()
  for p in prior.slice(1) {
    cdraw.line(prev, p, stroke: luma(60))
    prev = p
  }
  prev = like.first()
  for p in like.slice(1) {
    cdraw.line(prev, p, stroke: (paint: luma(150), dash: "dashed"))
    prev = p
  }
  prev = post.first()
  for p in post.slice(1) {
    cdraw.line(prev, p, stroke: luma(100))
    prev = p
  }
  cdraw.content((3.6, 4.6), [prior Beta(2,3)], size: 6pt)
  cdraw.content((11.6, 4.6), [likelihood x50], size: 6pt)
  cdraw.content((8.0, 6.45), [posterior Beta(5,5)], size: 6pt)
  cdraw.content((0.8, 0.25), [0], size: 6pt)
  cdraw.content((7.8, 0.25), [1/2], size: 6pt)
  cdraw.content((14.8, 0.25), [1], size: 6pt)
  cdraw.content((11.8, 5.9), [means 2/5, 1/2, 3/5], size: 6pt)
})

sources: mml-book draft 2024-01-15, Deisenroth, Faisal, Ong, "Mathematics
for Machine Learning", ch 6, pp 172-221 (printed), verified against the
cached pdf pages 178-227 on 2026-09-22, all definitions and equations
quoted or paraphrased from those pages. cppreference, "Common
mathematical functions", en.cppreference.com/w/c/numeric/math, fetched
2026-09-22, the
exp, pow, sqrt, and fabs calls the samples lean on. Sample behavior
verified by pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/math/samples/src -Chapter Ch18, 60 checks in chapter 18 of the math
suite, zero failures, format clean.
