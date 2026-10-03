// ch02, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 35 checks in kdd/samples/src/Ch02/impute.c (19) and outlier.c (16)
// or a cited source: Tukey, Exploratory Data Analysis, 1977, schematic
// plot fences, verified via en.wikipedia.org/wiki/Box_plot accessed
// 2026-09-22. all pinned values are witnessed by kdd-contract-s1s2.md +
// playground/kdd-matrix/gen_s1.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= data cleaning and imputation

Two samples carry the chapter: `impute.c` repairs a 5-row table with 2
holes and asserts 19 checks, `outlier.c` flags the planted outlier of a
9-value series two independent ways and asserts 16. The chapter makes 4
moves: column statistics over observed cells only, the three classic
fills and the one invariant mean filling keeps, the z-score flag with its
exact fraction arithmetic, and the IQR fences that need no mean and no
variance at all. Every behavioral claim below is one of the 35 checks of
chapter 02's samples or a cited sentence from Tukey 1977. Chapter 01's
chain dropped the row with the missing age, #xref-to("kdd", "process");
this chapter repairs instead of dropping, and
#xref-to("kdd", "normalize") scales what survives.

== the hole, and the column around it

The fixture is 5 people by 2 columns, age and income, with one hole in
each: p2's age and p3's income are missing. Repair starts with
statistics over what is observed, because every fill policy is a function
of those statistics, and the observed sets are small enough to read off:
age (30, 40, 50, 30) and income (40, 50, 60, 40), 4 values each, both an
even count.

The dry run: age sums to 150 over 4 observed, mean 37.5. Sorted age reads
(30, 30, 40, 50), the even split averages its two middle entries, median
(30 + 40)\/2 = 35. The value 30 appears twice, the other two once, so the
mode is 30 with count 2. Income sums to 190 over 4, mean 47.5; sorted
(40, 40, 50, 60) gives median 45, mode 40 with count 2. The sample prints
both lines: `age: mean 37.5 median 35 mode 30 x2` and `income: mean 47.5
median 45 mode 40 x2`, and checks ok 1 through ok 8 pin all eight values.

#listing("kdd/samples/src/Ch02/impute.c", first: 42, last: 65,
  caption: [median over observed cells, insertion sort, even count averaged])

#diagram([the 5-row table, 2 holes, and the observed sets each column keeps], length: 13pt, {
  let cell(x0, y0, txt, hole) = {
    cdraw.rect((x0, y0), (x0 + 1.9, y0 + 0.62),
      fill: if hole {luma(222)} else {luma(246)}, radius: 0.02)
    cdraw.content((x0 + 0.95, y0 + 0.31), txt, size: 6pt)
  }
  let col = (x0, vals, holeat) => {
    for i in range(5) {
      cell(x0, 6.5 - i * 0.78, vals.at(i), i == holeat)
    }
  }
  cdraw.content((2.85, 7.55), [id], size: 6pt)
  cdraw.content((4.8, 7.55), [age], size: 6pt)
  cdraw.content((6.75, 7.55), [income], size: 6pt)
  col(1.9, ([p1], [p2], [p3], [p4], [p5]), (-1))
  col(3.85, ([30], [hole], [40], [50], [30]), 1)
  col(5.8, ([40], [50], [hole], [60], [40]), 2)
  cdraw.content((10.4, 7.55), [observed cells only], size: 6pt)
  cdraw.content((10.4, 6.7), [age (30,40,50,30)], size: 6pt)
  cdraw.content((10.4, 6.2), [mean 37.5, median 35, mode 30 x2], size: 6pt)
  cdraw.content((10.4, 5.3), [income (40,50,60,40)], size: 6pt)
  cdraw.content((10.4, 4.8), [mean 47.5, median 45, mode 40 x2], size: 6pt)
  cdraw.line((7.7, 6.2), (8.6, 6.2), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((7.7, 4.8), (8.6, 4.8), stroke: (paint: luma(150), dash: "dashed"))
})

#callout("note", "missing is a fact, not a zero", [
  A hole is recorded as a flag on the cell, `ok == false`, never as the
  value 0. Writing 0 into an empty age cell would drag the observed mean
  to 30 and invent 5 people who died at birth. The sample's `cell_t`
  carries the flag and the value separately, and the integrity checks
  count 1 hole per column before any fill and 0 after, checks ok 10 and
  ok 11.
])

== three fills, one invariant

Mean, median, and mode filling each replace the hole with one statistic
of the observed cells: 37.5 and 47.5 for the mean, 35 and 45 for the
median, 30 and 40 for the mode. The choice is a bias decision. The mean
keeps the column average but lets every row's estimate drift toward the
center of everything else. The mode keeps values legal, income brackets
and product tiers are countable things, but ignores magnitudes. The
median ignores magnitude almost entirely and resists outliers.

The dry run: fill p2's age with the mean and the age column reads (30,
37.5, 40, 50, 30), sum 187.5 over 5, still 37.5. The mean fill preserves
the column mean exactly, and the sample asserts it twice, one per column,
as "ch02 post-impute age mean 37.5" and "ch02 post-impute income mean
47.5". The median and mode fills do not preserve it: the median-filled
age column averages (30 + 35 + 40 + 50 + 30)\/5 = 37, which no check
claims and no check needs. All three fills land as checks ok 12 through
ok 19.

#listing("kdd/samples/src/Ch02/impute.c", first: 98, last: 106,
  caption: [one fill function serves all three policies])

#listing("kdd/samples/src/Ch02/impute.c", first: 159, last: 171,
  caption: [the three fills checked per hole, mean invariant pinned twice])

#diagram([the age hole filled three ways, the filled cell shaded], length: 13pt, {
  let cell(x0, y, txt, hot) = {
    cdraw.rect((x0, y), (x0 + 2.0, y + 0.62),
      fill: if hot {luma(224)} else {luma(246)}, radius: 0.02)
    cdraw.content((x0 + 1.0, y + 0.31), txt, size: 6pt)
  }
  let colr(x0, cap) = {
    cdraw.content((x0 + 1.0, 7.4), cap, size: 6pt)
    cell(x0, 6.5, [30], false)
    cell(x0, 5.7, [37.5], true)
    cell(x0, 4.9, [40], false)
    cell(x0, 4.1, [50], false)
    cell(x0, 3.3, [30], false)
  }
  cdraw.content((2.4, 7.4), [holed], size: 6pt)
  cell(1.4, 6.5, [30], false)
  cell(1.4, 5.7, [hole], true)
  cell(1.4, 4.9, [40], false)
  cell(1.4, 4.1, [50], false)
  cell(1.4, 3.3, [30], false)
  cdraw.line((3.7, 5.0), (5.4, 5.0), stroke: luma(60), mark: (end: ">"))
  colr(5.7, [mean fill])
  colr(8.9, [median fill])
  colr(12.1, [mode fill])
  cdraw.content((8.9, 2.4), [one statistic of the observed 4, written into the hole], size: 6pt)
})

== one bad apple, measured in sigmas

The second fixture is a 9-value series with one planted outlier, E = (10,
12, 14, 16, 18, 20, 22, 24, 44). The z-score asks how many standard
deviations a value sits from the mean, and the sample keeps the whole
computation in integers until the final division: sum of squares first,
then the flag rule as an exact fraction comparison rather than a
floating-point subtraction.

The dry run: the sum is 180 over 9, mean exactly 20. The deviations read
(-10, -8, -6, -4, -2, 0, 2, 4, 24), they sum to 0, and their squares sum
100 + 64 + 36 + 16 + 4 + 0 + 4 + 16 + 576 = 816. The sample variance
divides by n - 1 = 8, giving 102. The outlier's squared score is
24^2\/102 = 576\/102 = 96\/17 after reduction, and the flag rule
$|z| > 2$ is equivalent to $z^2 > 4$, checked exactly as 96 > 68. The
next-largest squared score is 100\/102 = 50\/51, from the value 10, well
under 4. The printed display value reads `z(44) =
2.3763541031440183`, a print-only row pinned at tolerance 1e-12, and the
final count check fires as "ch02 z-score flags only 44".

#listing("kdd/samples/src/Ch02/outlier.c", first: 47, last: 65,
  caption: [mean and sum of squares in integers, sample variance divisor 8])

#listing("kdd/samples/src/Ch02/outlier.c", first: 67, last: 76,
  caption: [the flag rule as a reduced fraction, exact arithmetic])

#diagram([the series against the mean and the 2-sigma band, only 44 escapes], length: 13pt, {
  let py(v) = { 0.9 + v * 0.147 }
  cdraw.line((1.5, py(20.0)), (15.6, py(20.0)), stroke: luma(60))
  cdraw.content((1.4, py(20.0) + 0.32), [mean 20], size: 6pt)
  cdraw.line((1.5, py(20.0 - 2.0 * calc.sqrt(102.0))), (15.6, py(20.0 - 2.0 * calc.sqrt(102.0))),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.5, py(20.0 + 2.0 * calc.sqrt(102.0))), (15.6, py(20.0 + 2.0 * calc.sqrt(102.0))),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((15.0, py(20.0 - 2.0 * calc.sqrt(102.0)) - 0.34), [mean - 2s], size: 6pt)
  cdraw.content((15.0, py(20.0 + 2.0 * calc.sqrt(102.0)) - 0.34), [mean + 2s], size: 6pt)
  let vals = (10, 12, 14, 16, 18, 20, 22, 24, 44)
  for i in range(9) {
    let x = 2.2 + i * 1.5
    cdraw.circle((x, py(vals.at(i))), radius: 0.11,
      fill: if i == 8 {luma(150)} else {luma(210)}, stroke: luma(60))
    cdraw.content((x, 0.28), [#vals.at(i)], size: 6pt)
    cdraw.line((x, 0.5), (x, py(vals.at(i))), stroke: luma(220))
  }
  cdraw.content((13.6, py(44.0) + 0.4), [44, z = 2.376], size: 6pt)
})

#callout("note", "the divisor is a convention, and this book pins it", [
  The z-score of this chapter divides the sum of squares by n - 1, the
  sample variance, pinned by the contract sheet and asserted as
  "ch02 sample variance 102 (divisor n-1)". The standardization chapter
  divides by n, the population variance, over its own fixtures. Both are
  correct under their own convention and the difference is real, 816/8
  against 816/9 on this very series, so any pipeline mixing chapters must
  say which divisor it uses where. The sheet,
  kdd-contract-s1s2.md, states the convention per row.
])

== fences that need no mean

Tukey's schematic plot flags outliers with quartiles alone: fences at
$Q_1 - 1.5 dot "IQR"$ and $Q_3 + 1.5 dot "IQR"$, where IQR is the
interquartile range. The constant 1.5 is a convention Tukey chose for
schematic summaries, not a derived threshold, and the rule never computes
a mean or a variance, which is its whole point: no outlier can inflate
the yardstick that would measure it.

The dry run: 9 sorted values, odd count, so the middle value is excluded
and the quartiles come from the halves. Lower half (10, 12, 14, 16), its even
split averages the middle pair, Q1 = (12 + 14)\/2 = 13. Upper half (20,
22, 24, 44), Q3 = (22 + 24)\/2 = 23. IQR = 10, fences 13 - 15 = -2 and
23 + 15 = 38. The sample prints `Q1 13 Q3 23 IQR 10 fences -2 38`, every
value is a check, and the final count fires as "ch02 IQR flags only 44",
the same single flag the z-score raised.

#listing("kdd/samples/src/Ch02/outlier.c", first: 118, last: 141,
  caption: [quartiles by excluded-median halves, fences, and the flag count])

#diagram([the box between the fences, 44 sits outside both], length: 13pt, {
  let px(v) = { 1.2 + (v + 6.0) * 0.315 }
  cdraw.line((1.0, 3.9), (17.3, 3.9), stroke: luma(60), mark: (end: ">"))
  for v in (10, 20, 30, 40) {
    cdraw.line((px(v), 3.7), (px(v), 4.1), stroke: luma(100))
    cdraw.content((px(v), 3.2), [#v], size: 6pt)
  }
  cdraw.rect((px(13.0), 4.9), (px(23.0), 6.4), fill: luma(240), radius: 0.02)
  cdraw.content((px(18.0), 6.8), [the IQR box, Q1 13 to Q3 23], size: 6pt)
  cdraw.line((px(10.0), 5.65), (px(13.0), 5.65), stroke: luma(60))
  cdraw.line((px(23.0), 5.65), (px(24.0), 5.65), stroke: luma(60))
  cdraw.content((px(10.0), 5.05), [10], size: 6pt)
  cdraw.content((px(24.0), 5.05), [24], size: 6pt)
  cdraw.line((px(-2.0), 4.4), (px(-2.0), 6.9),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((px(38.0), 4.4), (px(38.0), 6.9),
    stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(-2.0), 7.25), [fence -2], size: 6pt)
  cdraw.content((px(38.0), 7.25), [fence 38], size: 6pt)
  cdraw.circle((px(44.0), 5.65), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(44.0), 5.05), [44], size: 6pt)
})

Two methods, one verdict. The z-score needed the mean, the variance, and
a divisor convention; the fences needed three order statistics and a
constant. That the two agree on this fixture is a property of the
planted outlier, and #xref-to("kdd", "anomaly") revisits the disagreement
when they don't.

sources: John W. Tukey, Exploratory Data Analysis, Addison-Wesley 1977,
schematic plots and the 1.5 fence convention, verified via
en.wikipedia.org/wiki/Box_plot, accessed 2026-09-22. All 35 pinned values
witnessed by kdd-contract-s1s2.md and playground/kdd-matrix/gen_s1.py,
run 2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile
-File tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch02`, 19 + 16 checks in chapter 02 of the kdd suite.
