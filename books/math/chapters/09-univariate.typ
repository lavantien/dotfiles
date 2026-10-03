#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= single-variable calculus

Everything in this book eventually differentiates or integrates something,
and this chapter builds that machinery for one variable at a time, from the
limit up. Six moves: limits computed on converging ladders, the derivative
as the slope the secants walk toward, the four differentiation rules
verified against hand-coded derivative pairs, taylor series with pinned
remainders and term counts, integration with riemann ladders and the
fundamental theorem, and finally what survives of all this in floats, where
the central difference has an optimum step near $root(epsilon, 3)$. Every
behavioral claim below is one of the 70 checks in the 4 samples of chapter
09 or a sentence quoted from the mml anchor sheet for chapter 5. Where
#xref-to("dsa", "numerical") drives newton iteration and simpson as contest tools,
this chapter builds the limit definitions those drivers stand on, and the
sister chapters on floats (#xref-to("math", "float"), #xref-to("math",
"error")) own the
representation story.

== limits and continuity

A limit is the value a sequence or function settles toward, and the honest
way to compute one in code is a ladder: evaluate at $1/2^k$, watch the gap
to the candidate limit shrink at the rate the algebra predicts. The sequence
$(1 + 1/k)^k$ rises to $e$ with a gap of about $e/(2k)$, and $sin(x)/x$ at
$x = 2^-k$ sits below 1 with a gap of about $x^2/6$. Both predictions are
checks, not prose: at $k = 2^20$ the sequence gap is 1.296e-6 against the
predicted 1.296e-6, and at $x = 2^-10$ the sinc gap is 1.589457e-07 against
$2^-20/6 = 1.58946e-7$. The epsilon-delta definition underneath is the trade
the ladder makes concrete: for every tolerance $epsilon$ on the output there
is a tolerance $delta$ on the input that keeps you inside it.

Why rungs of $1/2^k$ and not $1\/10^k$: every rung is exact in binary, so
the only rounding in the ladder is the function's own arithmetic, never the
evaluation points. A decimal ladder mixes representation error into every
rung and the gap column stops meaning anything below $10^-15$.
#xref-to("math", "float") owns this distinction, the ladder here just exploits it,
which is also why so many checks below can assert exact equality on rung
values.

The dry run: the fixtures are $(1+1/k)^k$ on $k = 1, 4, 2^20$, $sin(x)/x$ on
$x = 0.5, 2^-10$, the squeeze $cos(x) <= sin(x)/x <= 1$ at $x = 0.25$, and
$f(x) = x^2$ at $a = 3$ with $L = 9$ and $epsilon = 1e-3$.

+ The ladder rungs land on exact binary values: $(1+1/1)^1 = 2$ and $(1+1/4)^4 = 625/256 = 2.44140625$.
+ The sinc rung at $x = 0.5$ is 0.9588510772084060, still 4 percent from 1 with the gap $x^2/6 = 0.0417$ large, while at $2^-10$ the value is 0.9999998410542882.
+ For the epsilon-delta machine: $|x^2 - 9| = |x - 3| dot |x + 3|$, and $|x+3| < 7$ whenever $|x-3| < 1$, so any $delta < epsilon/7$ works. With $delta = epsilon/7 = 1.4286e-4$ the residual above 3 is 8.5716e-4 and below 3 it is -8.5712e-4, both inside $epsilon$. With $delta = epsilon/100$ the residual drops to 6.0000e-5.

Continuity is then one sentence: $f$ is continuous at $a$ when the limit
equals the value, $lim_(x -> a) f(x) = f(a)$. The holed expression $g(x) =
(x^2 - 4)/(x - 2)$ is the standard counterexample, undefined at $x = 2$
because the fraction reads 0/0, while its ladder closes on 4, the value of
the filled function $tilde(g)(x) = x + 2$. The check pins both: the rung at
$2 + 2^-5$ evaluates to exactly 4.03125 and the rung at $2 + 2^-10$ to
4.0009765625, one rung from the fill. This removable discontinuity pattern,
expression undefined at the point but limit existing, returns every time a
formula divides by something that vanishes.

#listing("math/samples/src/Ch09/limits.c", first: 22, last: 45, caption: [sequence and function ladders with pinned rungs, limits.c])

#diagram([the delta window inside the epsilon band, not to scale], length: 13pt, {
  // f(x) = x^2 mapped: x = 2.6..3.4 step 0.1 -> 1..9, y = 6.76..11.56 -> 0.25..4.77
  let curve = ((1.0, 0.25), (2.0, 0.75), (3.0, 1.27), (4.0, 1.81), (5.0, 2.36),
    (6.0, 2.93), (7.0, 3.53), (8.0, 4.14), (9.0, 4.77))
  for i in range(curve.len() - 1) {
    cdraw.line(curve.at(i), curve.at(i + 1), stroke: luma(60))
  }
  // epsilon band around L = 9, schematic width
  cdraw.line((1.2, 2.19), (8.8, 2.19), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.2, 2.53), (8.8, 2.53), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.0, 2.12), [L + eps], size: 6pt)
  cdraw.content((1.0, 2.60), [L - eps], size: 6pt)
  // delta window around a = 3
  cdraw.line((4.2, 0.1), (4.2, 5.1), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((5.8, 0.1), (5.8, 5.1), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((3.4, 5.3), [a - delta], size: 6pt)
  cdraw.content((6.0, 5.3), [a + delta], size: 6pt)
  cdraw.circle((5.0, 2.36), radius: 0.09, fill: luma(205), stroke: luma(60))
  cdraw.content((5.5, 1.9), [(a, L)], size: 6pt)
  cdraw.content((9.2, 5.1), [x^2], size: 6pt)
})

#listing("math/samples/src/Ch09/limits.c", first: 51, last: 75, caption: [delta for epsilon on x^2 and the removable hole, limits.c])

The two-number play: $delta = epsilon/7 = 1.43 times 10^-4$ leaves residual
8.57e-4, while $delta = epsilon/100$ leaves 6.0e-5, the same epsilon bought
two ways.

== the derivative as a slope machine

mml Definition 5.1 (Difference Quotient) defines $delta y \/ delta x := (f(x
+ delta x) - f(x)) \/ delta x$ as "the slope of the secant line through two
points on the graph of f" [printed p 141 / pdf p 147], and Definition 5.2
(Derivative) takes the limit, $(dif f)/(dif x) := lim_(h -> 0) (f(x + h) -
f(x)) / h$, where "the secant becomes a tangent" and "the derivative of f
points in the direction of steepest ascent" [printed p 141 / pdf p 147]. In
code the limit is never taken, it is approached: three quotients on a fixed
polynomial, forward $(f(x+h) - f(x))\/h$, backward $(f(x) - f(x-h))\/h$, and
central $(f(x+h) - f(x-h))\/(2h)$, each with its own error law. The fixture
is $f(x) = x^4 - 3x^2 + 7x - 2$ with coded derivative $f'(x) = 4x^3 - 6x +
7$, so $f(1) = 3$ and $f'(1) = 5$ exactly, and the taylor expansion of each
quotient around $h = 0$ reads the error laws straight off: forward misses by
$f''(1)\/2 dot h + f'''(1)\/6 dot h^2 + h^3 = 3h + 4h^2 + h^3$, backward by
the same with the sign of the linear term flipped, central by $f'''(1)\/6
dot h^2 = 4h^2$ with the linear term cancelled.

The dry run: one step of the secant walk at $h = 0.5$, all values exact in
binary.

+ $f(1.5) = 5.0625 - 6.75 + 10.5 - 2 = 6.8125$ and $f(0.5) = 0.0625 - 0.75 + 3.5 - 2 = 0.8125$.
+ Forward: $(6.8125 - 3)\/0.5 = 7.625$. Backward: $(3 - 0.8125)\/0.5 = 4.375$. Central: $(6.8125 - 0.8125)\/1 = 6$. The true slope is 5 and the central quotient already carries only $4h^2 = 1$.
+ One coarse secant across the whole interval, from 1 to 3, has slope $(f(3) - f(1))\/2 = 35$ where the tangent reads 5.

#listing("math/samples/src/Ch09/deriv.c", first: 26, last: 33, caption: [the fixed polynomial and its three quotients, deriv.c])

The order law is the chapter's first pinned convergence rate. On the ladder
$h = 2^-k$ the central error is exactly $4h^2$ while the rungs last,
1.5625e-2 at $k = 4$ and 3.90625e-3 at $k = 5$, and the ratio of consecutive
errors is exactly 4: halve the step, quarter the error. The forward error
carries its $3h$ term, 2.9335e-3 at $h = 2^-10$, and the check pins it
against the full cubic prediction $3h + 4h^2 + h^3$ to 1e-12.

Two derivative facts ride inside those error laws. First, the derivative is
itself a function: the sample codes $f'$ and $f''$ and $f'''$ as separate
expressions, $f'(x) = 4x^3 - 6x + 7$, $f''(x) = 12x^2 - 6$, $f'''(x) = 24x$,
with $f''(1) = 6$ and $f'''(1) = 24$ supplying the error-law coefficients 3
and 4. Differentiating the derivative is just applying the machinery again,
and the coefficients in the error laws are how the higher derivatives first
pay rent. Second, the expansion that produced the error laws is itself the
next section's subject: writing $f(x plus.minus h)$ as a polynomial in $h$
and cancelling is exactly what a taylor series does, so the derivative's own
analysis tool becomes the next construction.

#listing("math/samples/src/Ch09/deriv.c", first: 59, last: 80, caption: [dry-run checks and the order pinning ladder, deriv.c])

#diagram([three secants walk toward the tangent at (1, 3)], length: 13pt, {
  let curve = ((0.5, 0.30), (1.6, 0.44), (2.6, 0.85), (3.7, 1.12), (4.7, 1.45),
    (5.8, 1.83), (6.8, 2.40), (7.9, 3.31), (8.9, 4.50), (9.4, 5.23))
  for i in range(curve.len() - 1) {
    cdraw.line(curve.at(i), curve.at(i + 1), stroke: luma(60))
  }
  // secant to x = 2.25 truncated at x = 1.75, slope 16.95
  cdraw.line((4.7, 1.45), (7.9, 4.40), stroke: luma(140))
  cdraw.content((8.0, 4.62), [h = 1.25], size: 6pt)
  // secant to x = 1.5 extended to x = 2.1, slope 7.625
  cdraw.line((4.7, 1.45), (9.4, 3.40), stroke: luma(100))
  cdraw.content((9.0, 3.75), [h = 0.5], size: 6pt)
  // tangent, slope 5
  cdraw.line((0.9, 0.42), (9.4, 2.73), stroke: (paint: luma(100), dash: "dashed"),
    mark: (end: ">"))
  cdraw.content((1.2, 0.9), [tangent 5], size: 6pt)
  cdraw.circle((4.7, 1.45), radius: 0.09, fill: luma(205), stroke: luma(60))
  cdraw.content((4.2, 1.0), [(1, 3)], size: 6pt)
  cdraw.content((9.0, 0.6), [x^4 - 3x^2 + 7x - 2], size: 6pt)
})

The two-number play: forward misses by 2.03e-1 at $h = 2^-4$ while central
misses by 1.56e-2, thirteen times closer for the same two evaluations.

== the differentiation rules

mml section 5.1.2 states the four rules [printed pp 145-146 / pdf pp
151-152]: sum $(f + g)' = f' + g'$ (eq 5.31), product $(f g)' = f' g + f g'$
(eq 5.29), quotient $(f\/g)' = (f' g - f g')\/g^2$ (eq 5.30), chain $(g ∘ f)' = g'(f(x)) f'(x)$ (eq 5.32). This chapter refuses to trust them
symbolically. Each rule is checked numerically against a hand-coded pair, a
function and its derivative both written out explicitly, with the rule's
value compared to a central difference of the composed expression at $h =
1e-6$. The fixtures are $u(x) = x^3$ with $u'(x) = 3x^2$ and $v(x) = e^x$
with $v'(x) = e^x$, evaluated at $x = 0.7$. This is exactly the gradient-
implementation check mml recommends for code that differentiates, finite
differences against the analytic derivative at small $h$ [printed p 149 /
pdf p 155], run here on scalars.

The dry run: the product rule at $x = 0.7$, where $u = 0.343$, $u' = 1.47$,
$v = v' = 2.0137527074704766$.

+ Rule value: $u' v + u v' = 1.47 dot 2.0138 + 0.343 dot 2.0138 = 3.6509336586439738$.
+ Central difference of the product at $h = 1e-6$: 3.6509336587275953, a gap of 8.4e-11, which is the $O(h^2)$ truncation of the central quotient plus a few ulps.
+ The quotient rule on the same pair: $(1.47 dot 2.0138 - 0.343 dot 2.0138)\/2.0138^2 = 0.5596516373729186$ against central 0.5596516373801430.

#listing("math/samples/src/Ch09/deriv.c", first: 82, last: 110, caption: [each rule asserted against a central difference of the coded pair, deriv.c])

The chain rule gets the full mml Example 5.5 treatment [printed pp 145-146 /
pdf pp 151-152]: $h(x) = (2x+1)^4$ as the composition $g ∘ f$ with coded inner
$f(x) = 2x+1$, $f' = 2$ and coded outer $g(t) = t^4$, $g'(t) = 4t^3$. The
composed derivative $g'(f(x)) f'(x)$ evaluates to 32.768 at $x = 0.3$, the
closed form $8(2x+1)^3$ of eq 5.38 also gives 32.768, and the central
difference of the composed function gives 32.768000000051202. Three routes,
one number to 11 digits. The power rule $dif\/dif x x^n = n x^(n-1)$,
derived from the limit definition via the binomial expansion in mml Example
5.2 [printed p 142 / pdf p 148], rides along at $x = 1.3$: $5 dot 1.3^4 =
14.2805$ against central 14.2805000000169.

#diagram([the four rules as one pattern, outer derivatives times inner ones], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(3.4, 5.4, 3.2, [f and f' coded])
  box(0.3, 3.4, 3.0, [(f + g)' = f' + g'])
  box(3.5, 3.4, 3.0, [(f g)' = f' g + f g'])
  box(6.7, 3.4, 3.0, [(f/g)' = (f'g - fg')/g^2])
  box(3.5, 1.4, 3.0, [(g ∘)' = g'(f) f'])
  cdraw.line((5.0, 5.4), (1.8, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.0, 5.4), (5.0, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.0, 5.4), (8.2, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.0, 5.4), (5.0, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.0, 2.5), [substitute and multiply], size: 6pt)
  cdraw.content((0.4, 0.5), [every rule verified against a central difference at h = 1e-6], size: 6pt)
})

#callout("verify", "rules are checked, not trusted", [Each CHECK pairs the rule's closed form with a central difference of the composed expression. If a rule were miscoded the two sides diverge at $O(1)$, if the fixture pair were wrong they diverge at $O(h)$, and only a correct pair agrees to $O(h^2)$. The gap you should see is about 1e-10, and it is.])

The quotient rule deserves its check more than the others. The sign in the
numerator, $f' g - f g'$, is the most commonly flipped sign in applied
differentiation, and a flipped sign fails the CHECK at $O(1)$, a gap of
about 1.1 on this fixture rather than 1e-10. The chain rule deserves its
check for a different reason: it is the only rule whose operands are
functions of different variables, $g'$ evaluated at $f(x)$ rather than at
$x$, and wiring the argument through the composition is where code drifts
from math.

The two-number play: the chain at $x = 0.3$ gives 32.768 in exact form and
32.7680000000512 by difference, while at $x = 1.4$ it gives 438.976, the
same agreement scaled up.

== taylor series

mml Definition 5.3 (Taylor Polynomial) fixes the object, $T_n (x) :=
sum_(k=0)^n (f^((k))(x_0)) / k! (x - x_0)^k$ [printed p 142 / pdf p 148],
and Definition 5.4 (Taylor Series) extends the sum to infinity, calling $f$
analytic when $f(x) = T_∞(x)$ [printed pp 142-143 / pdf pp 148-149]. At $x_0
= 0$ these are maclaurin series. The four working series are $e^x = sum
x^k\/k!$, $sin$ and $cos$ alternating over odd and even factorials (mml eqs
5.26-5.27, printed with the $sin + cos$ combination in Example 5.4 [printed
p 144 / pdf p 150], and #xref-to("math", "trig") builds them again from the angle
identities), and $ln(1+x) = sum (-1)^(k+1) x^k\/k$.

The dry run: $e^x$ at $x = 1$, term by term, with the lagrange remainder
bound $|R_n| <= 3\/(n+1)!$ using $e^xi < 3$ for $xi in (0, 1)$.

+ $T_2(1) = 1 + 1 + 1/2 = 2.5$ exactly. $T_5(1) = 2.7166666666666668$, remainder 1.615e-3, bound $3/720 = 4.17e-3$.
+ The bound crosses 1e-12 between $n = 14$ (3/15! = 2.29e-12, fails) and $n = 15$ (3/16! = 1.43e-13, passes), so 16 terms suffice by the bound. The actual remainder at $n = 15$ is 5.08e-14, nearly three times inside the bound.
+ $sin$ at $x = 1$ is cheaper per digit because its terms carry $1\/(2k+1)!$: $T_9(1) = 0.8414710097001764$ with remainder 2.489e-8, and $n = 14$ already clears 1e-12 by the bound.

#listing("math/samples/src/Ch09/taylor.c", first: 24, last: 73, caption: [the four series machines and the exact polynomial fixture, taylor.c])

#listing("math/samples/src/Ch09/taylor.c", first: 75, last: 91, caption: [remainder bound and term count for exp at x = 1, taylor.c])

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*series*], [*at x*], [*T_n*], [*remainder*], [*bound*]),
  [$e^x$], [1], [$T_5$], [1.615e-3], [4.17e-3],
  [$e^x$], [1], [$T_15$], [5.08e-14], [1.43e-13],
  [$sin x$], [1], [$T_9$], [2.489e-8], [2.76e-7],
  [$ln(1+x)$], [0.5], [$s_20$], [1.537e-8], [2.27e-8],
)

Every bound in the table is a pinned check and every actual remainder sits
inside its bound, which is the whole method: the bound is computable before
you sum, the remainder only after. When the remainder goes to zero for every
$x$ in some interval, $T_∞(x) = f(x)$ there and $f$ is analytic on that
interval, and the largest interval where this happens is set by the term
ratio $|a_(k+1) (x - x_0)^(k+1)| \/ |a_k (x - x_0)^k|$: the series converges
where the ratio's limit stays under 1. The $ln(1+x)$ row shows the
alternating-series bound $x^(n+1)\/(n+1)$, and the radius of convergence is
part of the fixture. The term ratio of the $ln$ series is $x dot k\/(k+1)$,
which tends to $x$, so at $x = 0.5$ the ratio at $k = 20$ is 0.476 and the
partial sums settle, while at $x = 2$ it is 1.905 and they blow up, 5.07 at
5 terms, -64.8 at 10, -34359.7 at 20. Outside the radius the series is not
slow, it is wrong.

#listing("math/samples/src/Ch09/taylor.c", first: 93, last: 134, caption: [sin and cos remainders, the ln radius, and the exact x^4 case, taylor.c])

The polynomial case closes the loop with mml Example 5.3 [printed p 143 /
pdf p 149]: for $f(x) = x^4$ at $x_0 = 1$, the derivatives at 1 are $1, 4,
12, 24, 24, 0, 0$ and the divisions by $k!$ turn eq 5.17 into $T_6 (x) = 1 +
4(x-1) + 6(x-1)^2 + 4(x-1)^3 + (x-1)^4$, which multiplied out is exactly
$x^4$. A degree-n taylor polynomial of a polynomial of degree $k <= n$ is
the polynomial itself, and the check evaluates $T_6$ in powers of $(x-1)$ at
1.5 and 0.5 and gets $5.0625 = 1.5^4$ and $0.0625 = 0.5^4$, both exact in
binary.

#diagram([partial sums of e^x straighten out to the curve as n grows], length: 13pt, {
  let e = ((0.7, 0.93), (2.3, 1.09), (3.9, 1.37), (5.5, 2.44), (7.1, 3.19),
    (8.7, 4.42), (9.7, 5.51))
  let t1 = ((0.7, 0.12), (2.3, 0.69), (3.9, 1.27), (5.5, 2.44), (7.1, 3.02),
    (8.7, 3.59), (9.7, 3.94))
  let t2 = ((0.7, 2.01), (2.3, 1.87), (3.9, 2.01), (5.5, 2.44), (7.1, 3.16),
    (8.7, 4.17), (9.7, 4.91))
  let t4 = ((0.7, 1.00), (2.3, 1.12), (3.9, 1.38), (5.5, 2.44), (7.1, 3.19),
    (8.7, 4.41), (9.7, 5.46))
  for i in range(t1.len() - 1) {
    cdraw.line(e.at(i), e.at(i + 1), stroke: luma(60))
    cdraw.line(t1.at(i), t1.at(i + 1), stroke: (paint: luma(140), dash: "dashed"))
    cdraw.line(t2.at(i), t2.at(i + 1), stroke: luma(140))
    cdraw.line(t4.at(i), t4.at(i + 1), stroke: luma(100))
  }
  cdraw.content((9.4, 5.85), [e^x], size: 6pt)
  cdraw.content((9.4, 5.35), [T_4], size: 6pt)
  cdraw.content((9.4, 4.62), [T_2], size: 6pt)
  cdraw.content((9.4, 4.05), [T_1], size: 6pt)
})

#callout("note", "bounds before sums", [The lagrange bound $3\/(n+1)!$ for $e^x$ on $(0,1)$ costs one factorial to evaluate and one comparison to turn into a term count. The measured remainder 5.08e-14 sits almost three times inside the bound 1.43e-13 because the bound evaluates $e^xi$ at the worst point. Use the bound to choose n, then spend the actual remainder only if you have the true value to compare against.])

The two-number play: five terms of $e^x$ at 1 leave error 1.6e-3, fifteen
terms leave 5.1e-14, ten extra terms buy ten digits.

== integration and the fundamental theorem

The definite integral is the area signature of a function, computed in code
as riemann sums on a lattice of $n$ panels: left and right sums stamp the
height at the panel edges, the midpoint sum at the center. The fixture is
$g(x) = x^3 + 2x$ on $[0, 2]$ with antiderivative $G(x) = x^4/4 + x^2$ and
exact integral $G(2) - G(0) = 8$. The convergence orders are pinned by
doubling $n$: left and right sums carry $O(1\/n)$ error, so doubling halves
it, while the midpoint sum carries $O(1\/n^2)$, so doubling quarters it. For
this cubic the midpoint error is exactly $2\/n^2$, 0.125 at $n = 4$ and
0.03125 at $n = 8$, ratios exactly 4, and the left error ratio is 1.913 from
4 to 8 panels, closing on 2 as the higher Euler-Maclaurin terms fade.

The dry run: the $n = 4$ lattice on $[0, 2]$, panel width 0.5, all sums
exact in binary.

+ Edge values $g(0), g(0.5), g(1), g(1.5), g(2) = 0, 1.125, 3, 6.375, 12$.
+ Left sum: $0.5 dot (0 + 1.125 + 3 + 6.375) = 5.25$, undershooting 8 by 2.75 because $g$ rises.
+ Right sum: $0.5 dot (1.125 + 3 + 6.375 + 12) = 11.25$, overshooting by 3.25.
+ Midpoint sum: $0.5 dot (0.516 + 1.922 + 4.453 + 8.859) = 7.875$, off by 0.125 with the same four evaluations.

#listing("math/samples/src/Ch09/ftc.c", first: 25, last: 59, caption: [the three riemann sums as one loop each, ftc.c])

#diagram([left rectangles under x^3 + 2x, the n = 4 lattice], length: 13pt, {
  let curve = ((0.5, 0.40), (1.8, 0.66), (3.0, 0.96), (4.3, 1.36), (5.5, 1.90),
    (6.8, 2.63), (8.0, 3.59), (9.3, 4.83), (10.5, 6.40))
  cdraw.rect((3.0, 0.4), (5.5, 0.96), fill: luma(245), stroke: luma(140))
  cdraw.rect((5.5, 0.4), (8.0, 1.90), fill: luma(235), stroke: luma(140))
  cdraw.rect((8.0, 0.4), (10.5, 3.59), fill: luma(245), stroke: luma(140))
  for i in range(curve.len() - 1) {
    cdraw.line(curve.at(i), curve.at(i + 1), stroke: luma(60))
  }
  cdraw.line((0.5, 0.4), (10.5, 0.4), stroke: luma(100))
  cdraw.content((6.0, 0.15), [0], size: 6pt)
  cdraw.content((10.5, 0.15), [2], size: 6pt)
  cdraw.content((1.6, 0.7), [empty panel], size: 6pt)
  cdraw.content((10.2, 5.6), [x^3 + 2x], size: 6pt)
  cdraw.content((3.3, 2.2), [left sum 5.25], size: 6pt)
})

#listing("math/samples/src/Ch09/ftc.c", first: 79, last: 100, caption: [the ladder of sums with order ratios pinned, ftc.c])

The $n = 4$ row also shows a free error certificate: on a rising integrand
the left sum undershoots and the right sum overshoots, 5.25 and 11.25
bracketing the true 8, so the pair bounds the answer without knowing the
antiderivative. The bracket width is $(g(b) - g(a)) dot (b - a)\/n = 12 dot
2\/4 = 6$, shrinking as $1\/n$, and the midpoint sits inside it at 7.875. A
bracket plus a rate is often all a caller needs, and #xref-to("dsa",
"numerical")
turns exactly this shape into the simpson drivers the contest book uses.

The fundamental theorem of calculus is the bridge, and it is checked from
both directions on a fixed case. Part 2, integrate then differentiate: the
numeric integrator $G_"num"(x)$, a composite midpoint with 4096 panels from
0 to $x$, is differentiated by a central difference with $h = 1e-5$, and the
result matches $g(1.5) = 6.375$ to 1.0e-7 and $g(0.9) = 2.529$ to 2.2e-8.
Part 1, differentiate then integrate: the exact antiderivative $G$
differenced centrally at 1.1 lands within 2.8e-10 of $g(1.1)$, the gap being
cancellation noise in the difference of two nearly equal values, not
truncation, which is only $G'''(1.1)\/6 dot h^2 = g''(1.1)\/6 dot h^2 =
1.1e-12$, two orders under the noise. Linearity rides along on a second pair,
$x^2$ and $3x$ on $[0,2]$ with exact total $26/3$: the sum of the two
midpoint sums equals the midpoint sum of the sum to the last bit at $n =
128$, both 8.6666259765625.

#listing("math/samples/src/Ch09/ftc.c", first: 112, last: 142, caption: [antiderivative table, the FTC identity both ways, linearity, ftc.c])

#callout("pitfall", "exact ratios are a fixture property", [The midpoint error ratios reading exactly 4.0 hold because the error of this cubic on this interval is exactly $2\/n^2$ with no lower-order correction. For a generic smooth integrand the ratio approaches 4 from below as $n$ grows, so a check that demands exactly 4.0 on arbitrary fixtures fails. Pin the order with a tolerance, or pick a fixture whose error law you have derived.])

The two-number play: at $n = 4$ the left sum is off by 2.75 and the midpoint
by 0.125, twenty-two times closer for the same four evaluations, and by $n =
512$ the midpoint error is 7.6e-6.

== what survives in floats

The limit $h -> 0$ is a mathematical fiction. In doubles the central
difference error is the sum of truncation $c h^2$ and a rounding floor of a
few ulps of $f(x)$ divided by $h$, and that sum has a minimum. Solving for
the minimum of the two laws, $c h^2 approx u\/h$ gives $h^* approx
root(u\/c, 3)$, which for $epsilon = 2^-52$ and $c = O(1)$ lands near $6
times 10^-6$, between $2^-18$ and $2^-17$. The sweep in the sample confirms
it on the fixed polynomial at the generic point $x = 1.1$: the error rides
the truncation law $4.4 h^2$ (the $f'''(1.1)\/6$ coefficient) while the rungs
are clean, 6.56e-8 against the law's 6.56e-8 at $h = 2^-13$, but the sweep
bottom 4.56e-11 at $h = 2^-18$ already sits below the law's 6.40e-11 there,
because rounding starts subtracting from the truncation term, and beyond it
the error rises to 5.36e-10 at $2^-22$ where cancellation eats the difference
$f(x+h) - f(x-h)$. The argmin over the whole sweep is exactly $k = 18$. This is the same cancellation
mechanism #xref-to("math", "error") dissects at the bit level, seen here through a
calculus operation.

The same algebra run on the forward quotient, whose error law is $c h +
u\/h$, puts its optimum at $h^* approx sqrt(u\/c)$, around $10^-8$ for
doubles, an order tighter than the central one and two orders less accurate
at its best. The central difference is the right default precisely because
its truncation term is squared: same two function values, one extra power of
$h$ bought.

A second, quieter fact rides along. At $x = 1$ with $h = 2^-k$, the points
$1 plus.minus h$ are exact, the polynomial values round symmetrically, and
once $4h^2$ drops under half an ulp of 5 the central quotient collapses to
exactly 5.0, with error 0.0, all the way down to $h = 2^-21$. The U curve is
not a property of the formula, it is a property of the formula at points
whose arithmetic does not cancel. Power-of-two offsets from a clean point
are the lucky case, generic offsets like 1.1 are the honest one, and the two
checks sit next to each other to make the contrast explicit.

The dry run: the sweep at $x = 1.1$, target $f'(1.1) = 5.724$.

+ $k = 13$: error 6.56e-8, clean $4.4 h^2$ truncation territory.
+ $k = 18$: error 4.56e-11, the bottom of the U, $h = 3.81 times 10^-6$.
+ $k = 22$: error 5.36e-10, twelve times worse than the bottom while $h$ is sixteen times smaller.

#listing("math/samples/src/Ch09/deriv.c", first: 112, last: 135, caption: [the exact power-of-two ladder and the generic-point sweep to the argmin, deriv.c])

#diagram([central difference error against h, the U with its floor], length: 13pt, {
  let pts = ((0.6, 0.55), (1.05, 1.00), (1.5, 1.44), (1.95, 1.89), (2.4, 2.33),
    (2.85, 2.78), (3.3, 3.22), (3.75, 3.67), (4.2, 4.11), (4.65, 4.56),
    (5.1, 5.00), (5.55, 5.43), (6.0, 6.01), (6.45, 5.87), (6.9, 5.31),
    (7.35, 5.21), (7.8, 5.21), (8.25, 5.21), (8.7, 5.21), (9.15, 4.32), (9.6, 4.32))
  for i in range(pts.len() - 1) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(60))
  }
  cdraw.line((0.4, 0.3), (9.9, 0.3), stroke: luma(100))
  cdraw.line((0.4, 0.3), (0.4, 6.4), stroke: luma(100))
  cdraw.content((9.7, 0.05), [k = h exponent], size: 6pt)
  cdraw.content((0.1, 6.3), [log error], size: 6pt)
  cdraw.line((5.78, 0.3), (5.78, 6.1), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((5.85, 6.25), [cbrt(eps)], size: 6pt)
  cdraw.content((1.2, 1.6), [truncation 4h^2], size: 6pt)
  cdraw.content((7.6, 4.6), [rounding floor], size: 6pt)
  cdraw.circle((6.0, 6.01), radius: 0.09, fill: luma(205), stroke: luma(60))
  cdraw.content((6.55, 6.05), [2^-18], size: 6pt)
})

#callout("warning", "never push h below cbrt of epsilon", [A central difference at $h = 10^-8$ on values of size 1 discards all but the top few bits of $f(x+h) - f(x-h)$ and returns noise with a straight face. The check pins the failure: the error at $2^-22$ is twelve times the error at the optimum. The workable rule for doubles is $h approx 10^-6$ for central differences, $h approx 10^-8$ never. When you need exact derivatives at machine precision, the next chapters' chain-rule machinery, #xref-to("math", "autodiff"), computes them without any $h$ at all.])

The two-number play: at the lucky point $x = 1$ the error at $h = 2^-21$ is
exactly 0, at the generic point $x = 1.1$ the best error over the whole
sweep is 4.6e-11 and pushing further makes it worse.

The derivative of a function of several variables is the next chapter,
#xref-to("math", "multivariate"), where the single derivative becomes a gradient, a row
vector of partials, and every rule verified here composes one variable at a
time.

sources: mml-book draft 2024-01-15, ch 5, differentiation of univariate
functions, Definitions 5.1 and 5.2 with eqs 5.3-5.4, Example 5.2 polynomial
power rule with eqs 5.5-5.6d, Definition 5.3 and 5.4 with eqs 5.7-5.8,
Example 5.3 exact polynomial taylor case with eq 5.17, Example 5.4 sin plus
cos series with eqs 5.25-5.27, differentiation rules eqs 5.29-5.32, Example
5.5 chain rule with eq 5.38 [printed pp 141-146 / pdf pp 147-152], the
gradient-implementation check remark with $h = 10^-4$ [printed p 149 / pdf p
155], and the automatic differentiation forward and reverse modes with eqs
5.119-5.121 [printed pp 161-164 / pdf pp 167-170], all quoted from the
verified anchor sheet ref/mml/anchors-calc.md (53 numpy recomputes) rather
than re-opened from the pdf. Epsilon-delta, riemann sums, and the
fundamental theorem are standard single-variable calculus, our own words and
code throughout, with #xref-to("dsa", "numerical") owning the algorithmic drivers
these definitions feed. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch09`,
70 checks in chapter 09 of the math suite.