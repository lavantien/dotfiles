// ch12, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 35 checks in kdd/samples/src/Ch12/ols.c or a named note of
// kdd-contract-s3.md (the fraction convention, the D2 1e-12 ledger); the
// gaussian-noise MLE justification for squaring is banked to the math book
// ch 19 per the same sheet. all pinned values are witnessed by
// kdd-contract-s3.md + playground/kdd-matrix/gen_s3.py, run 2026-09-22,
// exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= simple linear regression

One sample carries the chapter: `ols.c` fits one line to each of two
tiny fixtures and asserts 35 checks, exact fractions wherever the value
is rational, tolerance doubles where it is not. The chapter makes 4
moves: the normal equations and the perfect fixture, the fraction
arithmetic that keeps a slope like 4\/5 exact, the residuals and the
sum they must make, and the decomposition SSE + SSR = Syy that defines
$R^2$. Every behavioral claim below is one of the 35 checks of chapter
12's sample or a named note of the contract sheet. Chapter 11's
aggregates summarized a table, #xref-to("kdd", "olap"); this chapter
fits a model through it, and the whole models arc of the book opens
here.

== the least squares line

Given pairs $(x_i, y_i)$, ordinary least squares picks slope $m$ and
intercept $b$ minimizing the squared vertical errors
$sum_i (y_i - m x_i - b)^2$. Setting both partial derivatives to zero
gives the normal equations, and their solution is closed form:
$m = (n S_("xy") - S_x S_y)\/(n S_("x2") - S_x^2)$ and
$b = S_y\/n - m S_x\/n$. Squaring is a choice with two justifications:
it makes the equations linear, and under gaussian noise the maximum
likelihood line is exactly the least squares line, the derivation this
book keeps in #xref-to("math", "statistics"). Fixture A is perfectly
linear, the five pairs (1,3), (2,5), (3,7), (4,9), (5,11), so every
quantity below is a small integer and the fit is exact.

The dry run: the five sums print as `A: n=5 Sx=15 Sy=35 Sxy=125
sumx2=55 Sxx_centered=50`, where the 50 is the cross-multiplied form
$n sum x^2 - (sum x)^2 = 275 - 225$, five times the centered 10. The
slope numerator is $5 dot 125 - 15 dot 35 = 625 - 525 = 100$, so
$m = 100\/50 = 2$ and $b = 35\/5 - 2 dot 15\/5 = 7 - 6 = 1$, printed
as `A: slope 2/1 = 2.000000000000000, intercept 1/1 =
1.000000000000000` and asserted with plain `==`, both values dyadic.

#listing("kdd/samples/src/Ch12/ols.c", first: 79, last: 95,
  caption: [fixture A's five sums, one pass, all integers])

#listing("kdd/samples/src/Ch12/ols.c", first: 97, last: 104,
  caption: [slope and intercept from the normal equations, exact fractions])

#diagram([fixture A, five points on the line y = 2x + 1, residuals zero], length: 13pt, {
  let px(v) = { 1.8 + (v - 1.0) * 3.1 }
  let py(v) = { 0.9 + (v - 3.0) * 0.55 }
  cdraw.line((1.4, 0.7), (17.0, 0.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.4, 0.7), (1.4, 6.1), stroke: luma(60), mark: (end: ">"))
  for x in (1, 2, 3, 4, 5) {
    cdraw.line((px(x * 1.0), 0.5), (px(x * 1.0), 0.9), stroke: luma(100))
    cdraw.content((px(x * 1.0), 0.15), [#x], size: 6pt)
  }
  cdraw.line((px(1.0), py(3.0)), (px(5.0), py(11.0)), stroke: luma(60))
  for p in ((1, 3), (2, 5), (3, 7), (4, 9), (5, 11)) {
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1) * 1.0)), radius: 0.11,
      fill: luma(210), stroke: luma(60))
    cdraw.content((px(p.at(0) * 1.0), py(p.at(1) * 1.0) + 0.42),
      [(#p.at(0),#p.at(1))], size: 6pt)
  }
  cdraw.content((15.3, py(11.0) - 0.5), [y = 2x + 1], size: 6.5pt)
  cdraw.content((9.0, 3.0), [every residual is exactly 0], size: 6pt)
})

== a slope the cpu cannot hold

Fixture B is four pairs, (1,3), (2,2), (3,4), (4,5), and its slope is
4\/5, a fraction with no finite binary expansion. The sample therefore
carries a reduced-fraction type, `long long` numerator and denominator,
and asserts every rational result by cross-multiplication, `num * q ==
p * den`, exact. The decimal prints ride along as commentary, pinned
separately at tolerance 1e-12, the ledger's D2 class.

The dry run: the sums are $S_x = 10$, $S_y = 14$,
$S_("xy") = 39$, $sum x^2 = 30$, so the slope numerator is
$4 dot 39 - 10 dot 14 = 156 - 140 = 16$ over $4 dot 30 - 100 = 20$,
reducing to 4\/5. The intercept is $14\/4 - (4\/5)(10\/4) = 7\/2 - 2 =
3\/2$. The sample prints `B: slope 4/5 = 0.800000000000000,
intercept 3/2 = 1.500000000000000`, asserts "ch12 B slope 4/5 exact"
by cross-multiplication and "ch12 B slope double 0.8 at 1e-12", and
asserts the intercept 3\/2 both ways because halves are dyadic.

#listing("kdd/samples/src/Ch12/ols.c", first: 40, last: 51,
  caption: [the reduced-fraction constructor, gcd and sign handled])

#listing("kdd/samples/src/Ch12/ols.c", first: 145, last: 154,
  caption: [fixture B's slope and intercept, exact fraction plus tolerance double])

#diagram([fixture B, four points, the line y = 4x/5 + 3/2 through them], length: 13pt, {
  let px(v) = { 2.4 + (v - 1.0) * 3.4 }
  let py(v) = { 0.9 + (v - 2.0) * 1.05 }
  cdraw.line((1.8, 0.7), (17.0, 0.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((1.8, 0.7), (1.8, 5.6), stroke: luma(60), mark: (end: ">"))
  for x in (1, 2, 3, 4) {
    cdraw.line((px(x * 1.0), 0.5), (px(x * 1.0), 0.9), stroke: luma(100))
    cdraw.content((px(x * 1.0), 0.15), [#x], size: 6pt)
  }
  cdraw.line((px(0.6), py(0.6 * 0.8 + 1.5)), (px(4.6), py(4.6 * 0.8 + 1.5)),
    stroke: luma(60))
  let pts = ((1, 3), (2, 2), (3, 4), (4, 5))
  for p in pts {
    let yh = 0.8 * p.at(0) + 1.5
    cdraw.line((px(p.at(0) * 1.0), py(p.at(1) * 1.0)),
      (px(p.at(0) * 1.0), py(yh)), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1) * 1.0)), radius: 0.11,
      fill: luma(210), stroke: luma(60))
    cdraw.content((px(p.at(0) * 1.0) + 0.5, py(p.at(1) * 1.0)),
      [(#p.at(0),#p.at(1))], size: 6pt)
  }
  cdraw.content((14.0, 4.9), [slope 4\/5, intercept 3\/2], size: 6.5pt)
  cdraw.content((9.2, 1.3), [dashed segments are the residuals], size: 6pt)
})

#callout("note", "two assertions, one number", [
  The slope 4\/5 is one number with two pins. The fraction pin
  cross-multiplies, exact forever; the double pin checks the printed
  0.8 to 1e-12 because 0.8 is not representable in binary and the
  nearest double sits about 4.4 parts in $10^17$ away. The contract
  ledger measured the arithmetic-ordering spread across evaluation
  orders at 5.6 parts in $10^17$, so the 1e-12 tolerance carries four
  orders of margin while staying tight enough to catch a wrong formula.
])

== residuals, and the sum that must be zero

The residual $r_i = y_i - (m x_i + b)$ is the part of $y_i$ the line
misses. Two facts hold for every least squares fit, both forced by the
normal equations rather than by luck: the residuals sum to zero, and
they are orthogonal to the x values, $sum_i r_i x_i = 0$. The sample
checks the first on both fixtures and uses the second implicitly every
time it reuses the same m and b.

The dry run: on fixture A the five residual lines print
`A: residual x=1 0.000000000000000` through `x=5` all zero, and
`A: residual sum 0.000000000000000`, asserted with `==` six times. On
fixture B the sample scales by ten and stays in integers: the
prediction at $x$ is $(8x + 15)\/10$, so it prints `B: 10*yhat(x=1) =
23` up to
`B: 10*yhat(x=4) = 47`, and the residuals `B: 10*residual(x=1) = 7`,
`= -11`, `= 1`, `= 3`, summing to zero, "ch12 B residual sum 0". The
squared tenths sum $49 + 121 + 1 + 9 = 180$, so
$S S E = 180\/100 = 9\/5$, printed as `B: SSE 9/5 = 1.800000000000000`
and pinned both as a fraction and at 1e-12.

#listing("kdd/samples/src/Ch12/ols.c", first: 156, last: 172,
  caption: [residuals in integer tenths, 10y - 8x - 15, summing to zero])

#listing("kdd/samples/src/Ch12/ols.c", first: 174, last: 182,
  caption: [SSE from the squared tenths, 180 over 100, reduced to 9/5])

#diagram([the four fixture B residuals in tenths, positive and negative, sum zero], length: 13pt, {
  let px(v) = { 2.6 + (v - 1.0) * 3.6 }
  let py(r) = { 4.0 + r * 0.22 }
  cdraw.line((1.4, py(0)), (16.6, py(0)), stroke: luma(60))
  cdraw.content((16.9, py(0)), [0], size: 6pt)
  let rs = ((1, 7), (2, -11), (3, 1), (4, 3))
  for t in rs {
    let x = px(t.at(0) * 1.0)
    cdraw.rect((x - 0.55, calc.min(py(0), py(t.at(1) * 1.0))),
      (x + 0.55, calc.max(py(0), py(t.at(1) * 1.0))), fill: luma(230),
      radius: 0.02, stroke: luma(160))
    if t.at(1) > 0 {
      cdraw.content((x, py(t.at(1) * 1.0) + 0.4), [+#t.at(1)], size: 6pt)
    } else {
      cdraw.content((x, py(t.at(1) * 1.0) - 0.4), [#t.at(1)], size: 6pt)
    }
    cdraw.content((x, 0.4), [x = #t.at(0)], size: 6pt)
  }
  cdraw.content((9.0, 7.1), [7 - 11 + 1 + 3 = 0, the normal equations force it], size: 6pt)
})

== the decomposition, and R squared

Total scatter splits into explained and unexplained:
$S_("yy") = S S R + S S E$, where SSR is the squared length the line
accounts for, $m^2$ times the centered x scatter, and $R^2 =
S S R\/S_("yy")$ is the fraction of $y$'s variance the line explains.
Fixture A explains everything; fixture B explains 16\/25 of it.

The dry run: fixture A prints `A: SSE 0.000000000000000 Syy 40/1 R2
1.000000000000000`, with $S_("yy") = (5 dot 285 - 1225)\/5 = 40$ over
$y^2$ values 9 + 25 + 49 + 81 + 121 = 285. Fixture B prints `B: Syy
5/1, SSR 16/5 = 3.200000000000000` and `B: R2 16/25 =
0.640000000000000`: $S_("yy") = (4 dot 54 - 196)\/4 = 5$, $S S R =
(16\/25) dot 5 = 16\/5$, and indeed $16\/5 + 9\/5 = 25\/5 = 5$,
the decomposition closing on itself, "ch12 B SSR 16/5 exact" and
"ch12 B R2 16/25 exact" both cross-multiplied.

#listing("kdd/samples/src/Ch12/ols.c", first: 121, last: 134,
  caption: [fixture A's SSE 0, Syy 40, and R2 1, all dyadic])

#listing("kdd/samples/src/Ch12/ols.c", first: 184, last: 194,
  caption: [fixture B's Syy and SSR, exact fractions from the same m])

#listing("kdd/samples/src/Ch12/ols.c", first: 196, last: 200,
  caption: [R2 as the fraction SSR over Syy, 16/25, plus the double pin])

#diagram([variance explained, fixture A fills the bar, fixture B fills 16 of 25], length: 13pt, {
  let bar(y, tag, fracv, lab) = {
    cdraw.content((1.0, y + 0.3), tag, size: 6pt)
    cdraw.rect((5.0, y), (17.0, y + 0.6), fill: luma(240), radius: 0.02)
    cdraw.rect((5.0, y), (5.0 + 12.0 * fracv, y + 0.6), fill: luma(214),
      radius: 0.02)
    cdraw.content((9.0, y + 0.95), lab, size: 6pt)
  }
  bar(6.0, [A], 1.0, [Syy 40 = SSR 40 + SSE 0, R2 = 1])
  bar(3.4, [B], 16.0 / 25.0, [Syy 5 = SSR 16\/5 + SSE 9\/5, R2 = 16\/25 = 0.64])
  cdraw.content((9.0, 1.8), [filled length is the fraction of y variance the line explains], size: 6pt)
})

#callout("note", "R2 is a report, not a grade", [
  A perfect fit earned $R^2 = 1$ on five collinear points, and 0.64 on
  four noisy ones, but the number says nothing about whether the line
  is the right model, only how much of this sample's spread it
  absorbs. Two points always give $R^2 = 1$, any two, which is why the
  evaluation chapters judge models on held-out data,
  #xref-to("kdd", "evaluation"), not on the quantity their fit
  minimized.
])

sources: all 35 pinned values, the reduced-fraction convention, and the
D2 1e-12 tolerance ledger witnessed by kdd-contract-s3.md and
playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0. The
gaussian-noise MLE justification for least squares is banked to the
math book ch 19 (statistics) per the same sheet. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch12`, 35 checks in chapter 12 of the
kdd suite.
