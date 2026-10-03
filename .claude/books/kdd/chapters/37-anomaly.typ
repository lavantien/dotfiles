// ch37, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 57 checks in kdd/samples/src/Ch37/gauss.c (35) and robust.c (22) or
// a cited constant pinned by the contract sheet: the df=2 chi-square
// critical 5.991 from the NIST/SEMATECH e-Handbook 1.3.6.7 table, exact
// form -2 ln 0.05. all pinned values are witnessed by
// kdd-contract-s8s9.md + playground/kdd-matrix/gen_s8.py, run 2026-09-22,
// exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= statistical anomaly detection

Two samples carry the chapter: `gauss.c` z-scores a known-parameter
gaussian series and runs the joint Mahalanobis test on correlated
inliers, 35 checks, and `robust.c` flags outliers with boxplot fences and
with the MAD robust z, 22 checks. The chapter makes 4 moves: the
known-parameter z-score under a strict 3-sigma rule, the joint test that
catches what two per-axis rulers miss, the fences that need no mean at
all, and the masking failure a mean-based rule suffers when outliers
inflate their own yardstick. Every behavioral claim below is one of the
57 checks of chapter 37's samples or a cited constant. Clustering asked
which rows group, #xref-to("kdd", "kmeans") through
#xref-to("kdd", "spectral"); this chapter and #xref-to("kdd", "lof") ask
which rows refuse to, and #xref-to("kdd", "hypothesis") puts error bars
on every verdict from here on.

== the known parameters, and the strict rule

The cleanest anomaly model is a distribution whose parameters nobody has
to estimate. The fixture is 11 measurements from a process known to run
at mu = 50 with sigma = 5, so the z-score of every value is one division,
$(v - 50)\/5$, and the detector asks only whether $|z| > 3$. The rule is
strict by pin: equality does not flag, and the fixture carries a value
parked exactly on the boundary to prove it.

The dry run: the measurements read 50, 45, 55, 40, 60, 48, 52, 70, 46,
54, 35, and the sample prints one z row per value, `z 50=0`, `z 45=-1`,
`z 55=1`, on through `z 70=4` and `z 35=-3`. Only one value clears the
bar, printed as `flags3={70}` and asserted as "ch37 3-sigma flags only 70
(strict > 3)". The value 35 lands at exactly -3, and its row is the
boundary witness: `boundary 35 z=-3.0 flagged=False (strict > 3)` in the
sheet, asserted as "ch37 boundary 35 z=-3 unflagged (strict > 3)". An
inclusive rule would double the flag set on this very fixture, which is
why the inequality sign is a check and not a comment.

#listing("kdd/samples/src/Ch37/gauss.c", first: 60, last: 81,
  caption: [the 11-value fixture, one z per value, strict > 3 flags])

#diagram([11 measurements on the z ruler, the shaded band is the strict interior], length: 13pt, {
  let pz(z) = { 2.4 + (z + 3.0) * 1.86 }
  cdraw.rect((pz(-3.0), 3.5), (pz(3.0), 5.4), fill: luma(242), radius: 0.01)
  cdraw.line((1.0, 4.45), (17.3, 4.45), stroke: luma(60), mark: (end: ">"))
  cdraw.content((17.9, 4.45), [z], size: 6pt)
  let zs = (0.0, -1.0, 1.0, -2.0, 2.0, -0.4, 0.4, 4.0, -0.8, 0.8, -3.0)
  let vs = (50, 45, 55, 40, 60, 48, 52, 70, 46, 54, 35)
  let order = (5, 7, 9, 10, 3, 1, 4, 6, 0, 2, 8)
  for j in range(11) {
    let i = order.at(j)
    let x = pz(zs.at(i))
    let deep = calc.even(j)
    cdraw.circle((x, 4.45), radius: 0.1,
      fill: if zs.at(i) > 3.0 {luma(150)} else {luma(210)}, stroke: luma(60))
    cdraw.content((x, if deep {3.7} else {4.95}), [#vs.at(i)], size: 6pt)
  }
  for z in (-3, 0, 3) {
    cdraw.line((pz(z * 1.0), 4.15), (pz(z * 1.0), 4.75), stroke: luma(100))
    cdraw.content((pz(z * 1.0), 5.85), [#z], size: 6pt)
  }
  cdraw.circle((pz(-3.0), 4.45), radius: 0.13, stroke: luma(60))
  cdraw.content((pz(-3.0), 2.75), [35 sits on -3, unflagged], size: 6pt)
  cdraw.content((pz(4.0), 3.05), [70, z = 4], size: 6pt)
  cdraw.content((pz(0.0), 6.5), [known mu = 50, sigma = 5, band |z| <= 3], size: 6pt)
})

== one ellipse beats two rulers

Scoring each feature against its own spread misses the point when the
features move together. The fixture is 8 two-feature inliers built, by a
t/u decomposition, to have mean exactly (10, 10) and population
covariance exactly `[[4,-3],[-3,4]]`, divisor n as #xref-to("kdd",
"normalize") pinned it, negative correlation locked in. The joint test is
the Mahalanobis distance of #xref-to("kdd", "distance"), $D^2 = (p -
mu)^T S^(-1) (p - mu)$, with $S^(-1) = (1\/7)[[4,3],[3,4]]$ because the
determinant is exactly 7.

The dry run: the sample prints `Jmean=(10,10) Jcov=[[4,-3],[-3,4]]` and
`Jdet=7`, all three asserted exactly. Then three probes. The pair (13,13)
and (13,7) carries the story: both have marginal scores (1.5, 1.5) and
(1.5, -1.5), both dead quiet under any per-axis 3-sigma rule, yet their
rows print `probe (13,13) z=(1.5,1.5) D2=18/1 D=4.2426406871192848
chi2flag=true z3flag=false` and `probe (13,7) z=(1.5,-1.5) D2=18/7
D=1.6035674514745464 chi2flag=false z3flag=false`. The arithmetic is
$D^2 = (4a^2 + 6 a b + 4b^2)\/7$ over the integer deviation $(a, b)$:
(3,3) gives $126\/7 = 18$, (3,-3) gives $18\/7$. The split is asserted
as "ch37 same-marginals pair splits D^2 18 vs 18/7". The flag compares
$D^2$ against the df=2 chi-square critical at 5% exactly, by
cross-multiplication against 5991\/1000: the table value 5.991, exact
form $-2 ln 0.05 = 5.991464547107982$, printed as
`chi2_df2_alpha05=5.991 exact=5.9914645471079817`. The third probe
(14,8) prints `D2=32/7`, under the bar: only the correlated one is
caught, and only the joint rule catches it.

#listing("kdd/samples/src/Ch37/gauss.c", first: 86, last: 109,
  caption: [the 8 inliers, their exact mean and population covariance, determinant 7])

#listing("kdd/samples/src/Ch37/gauss.c", first: 123, last: 135,
  caption: [per-probe D^2 as a reduced fraction, the chi-square flag cross-multiplied])

#diagram([the tilted joint rule: both probes are marginally quiet, only one is outside], length: 13pt, {
  let px(v) = { 2.6 + (v - 4.0) * 0.82 }
  let py(v) = { 0.9 + (v - 4.0) * 0.82 }
  let a = calc.sqrt(5.991)
  let b = calc.sqrt(5.991 * 7.0)
  let pts = ()
  for t in range(0, 371, step: 6) {
    let c = calc.cos(t)
    let s = calc.sin(t)
    pts.push((px(10.0 + (a * c + b * s) / calc.sqrt(2.0)),
      py(10.0 + (a * c - b * s) / calc.sqrt(2.0))))
  }
  for i in range(pts.len() - 1) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(110))
  }
  cdraw.content((4.1, 5.9), [the joint rule,], size: 6pt)
  cdraw.content((4.1, 5.4), [$D^2$ = 5.991], size: 6pt)
  let ins = ((14, 8), (11, 7), (11, 9), (9, 11), (7, 11), (8, 14), (10, 10), (10, 10))
  for p in ins {
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1) * 1.0)), radius: 0.07,
      fill: luma(214), stroke: luma(90))
  }
  cdraw.content((px(10.0) - 2.15, py(10.0) - 0.35), [mean (10,10)], size: 6pt)
  cdraw.circle((px(13.0), py(13.0)), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(13.0) + 1.35, py(13.0) + 0.42), [(13,13), $D^2$ = 18, flagged], size: 6pt)
  cdraw.content((px(13.0) + 1.35, py(13.0) - 0.12), [z = (1.5, 1.5)], size: 6pt)
  cdraw.circle((px(13.0), py(7.0)), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(13.0) + 1.35, py(7.0) + 0.18), [(13,7), $D^2$ = 18\/7], size: 6pt)
  cdraw.content((px(13.0) + 1.35, py(7.0) - 0.36), [z = (1.5, -1.5)], size: 6pt)
  cdraw.content((9.3, 0.35), [correlation, not marginal spread, decides], size: 6pt)
})

#callout("pitfall", "the marginal rulers agree on both probes", [
  Per-axis 3-sigma scores (1.5, 1.5) and (1.5, -1.5) are interchangeable
  to any univariate detector, and all three probes carry z3flag=false,
  asserted three times as "ch37 probe (13,13) univariate 3-sigma quiet"
  and its siblings. The covariance inverts the geometry: variance is 1
  along the diagonal, 7 along the anti-diagonal, so a step with the grain
  is cheap and a step against it is expensive. Two rulers see two
  half-quiet scores. One ellipse sees one outlier.
])

== fences that need no mean

The third detector refuses to estimate anything. Tukey's fences flag by
order statistics alone, $Q_1 - 1.5 dot "IQR"$ and $Q_3 + 1.5 dot "IQR"$,
the construction #xref-to("kdd", "cleaning") introduced; here the
quartile convention is the one pinned in chapter 02, odd n excludes the
median and averages each half's middle pair. The fixture is the 9-value
series F9 = (2, 4, 6, 8, 10, 12, 14, 16, 40), the outlier parked in the
last slot where it cannot touch the quartiles.

The dry run: lower half (2, 4, 6, 8) averages its middle pair to Q1 = 5;
upper half (12, 14, 16, 40) averages (14 + 16)\/2 = 15, the outlier
withheld, asserted as "ch37 F9 Q3 = 15, outlier withheld from Q3". IQR =
10, fences 5 - 15 = -10 and 15 + 15 = 30, printed as one row `fence
Q1=5/1 Q3=15/1 IQR=10/1 LF=-10/1 UF=30/1`. Only 40 exceeds its fence,
printed `flags={40}`, asserted as "ch37 F9 fence flags only 40". The
boundary discipline repeats: probes at exactly 30 and exactly -10 print
`fence probe 30 onfence=true flagged=false (strict)` and `fence probe
-10 onfence=true flagged=false (strict)`, both asserted, the fence
analog of the z = -3 row.

#listing("kdd/samples/src/Ch37/robust.c", first: 55, last: 73,
  caption: [quartiles by excluded-median halves, fences as reduced fractions])

#listing("kdd/samples/src/Ch37/robust.c", first: 74, last: 93,
  caption: [the strict fence flag scan and the two on-fence probes])

#diagram([the box and the fences, 40 outside, a probe sitting exactly on the upper fence], length: 13pt, {
  let px(v) = { 1.0 + (v + 12.0) * 0.28 }
  cdraw.line((0.8, 3.9), (17.4, 3.9), stroke: luma(60), mark: (end: ">"))
  for v in (0, 10, 20, 30, 40) {
    cdraw.line((px(v * 1.0), 3.7), (px(v * 1.0), 4.1), stroke: luma(100))
    cdraw.content((px(v * 1.0), 3.25), [#v], size: 6pt)
  }
  cdraw.rect((px(5.0), 4.9), (px(15.0), 6.4), fill: luma(240), radius: 0.02)
  cdraw.content((px(10.0), 6.85), [IQR box, Q1 5 to Q3 15], size: 6pt)
  cdraw.line((px(2.0), 5.65), (px(5.0), 5.65), stroke: luma(60))
  cdraw.line((px(15.0), 5.65), (px(16.0), 5.65), stroke: luma(60))
  cdraw.line((px(-10.0), 4.4), (px(-10.0), 6.95), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((px(30.0), 4.4), (px(30.0), 6.95), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(-10.0), 7.3), [LF -10], size: 6pt)
  cdraw.content((px(30.0), 7.3), [UF 30], size: 6pt)
  for v in (2, 4, 6, 8, 10, 12, 14, 16) {
    cdraw.circle((px(v * 1.0), 5.65), radius: 0.08, fill: luma(210), stroke: luma(60))
  }
  cdraw.circle((px(40.0), 5.65), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(40.0), 5.05), [40], size: 6pt)
  cdraw.circle((px(30.0), 5.65), radius: 0.13, stroke: luma(60))
  cdraw.content((px(30.0) - 4.6, 4.45), [probe 30, on the fence, unflagged], size: 6pt)
})

== masking, and the robust catch

A mean-based rule hands the outliers a vote in their own trial. The
fixture M10 = (4, 6, 8, 10, 12, 14, 16, 18, 58, 74) plants two outliers
on the same side; they drag the mean to 22 and the population variance to
2568\/5, so far that neither lands 3 sigma out. The cure is the robust z
of #xref-to("kdd", "normalize"), deviation from the median over the MAD,
the raw Leys et al. spelling with no 0.6745 constant.

The dry run: the sample prints `mask mean=22/1 SS=5136 var_pop=2568/5`,
with SS = 5136 and the variance each a check. The mean-based squared
scores reduce to fractions, printed `z2 58=270/107 |z|=1.5885101466409677`
and `z2 74=1690/321 |z|=2.2945146562591754`, both under 9, so the flag
line reads `flags3_mean={} (masked)`, asserted as "ch37 mean-based
3-sigma flags nothing (masking)". The robust half prints `med=13/1
MAD=5/1`, then `rz 58=9/1` and `rz 74=61/5`, the value 74 sitting 61/5 =
12.2 deviations from the median, and the flag line `flags_rz3={58,74}`,
asserted as "ch37 MAD robust-z flags both 58 and 74". The largest inlier
holds at 9\/5, printed `inlier rz max |4-13|/5=9/5` and asserted under
the same 3 bar, so the robust rule separates cleanly: inliers at most
1.8, outliers 9 and 12.2.

#listing("kdd/samples/src/Ch37/robust.c", first: 117, last: 139,
  caption: [mean-based squared scores as fractions, the masked flag count])

#listing("kdd/samples/src/Ch37/robust.c", first: 160, last: 180,
  caption: [robust z from median and MAD, both outliers flagged, strict > 3])

#diagram([the same ten values under the mean band and the robust band], length: 13pt, {
  let px(v) = { 1.0 + (v + 50.0) * 0.155 }
  let vals = (4, 6, 8, 10, 12, 14, 16, 18, 58, 74)
  let s3 = 3.0 * calc.sqrt(2568.0 / 5.0)
  cdraw.content((0.9, 8.0), [mean rule, band 22 plus or minus 3s], size: 6pt)
  cdraw.rect((px(22.0 - s3), 6.2), (px(22.0 + s3), 7.5), fill: luma(242), radius: 0.01)
  cdraw.content((px(22.0 - s3) - 1.1, 7.3), [-46], size: 6pt)
  cdraw.content((px(22.0 + s3) + 1.0, 7.3), [90], size: 6pt)
  for v in vals {
    cdraw.circle((px(v * 1.0), 6.85), radius: 0.09, fill: luma(210), stroke: luma(60))
  }
  cdraw.content((8.9, 5.6), [flags3_mean = {}, both outliers inside], size: 6pt)
  cdraw.content((0.9, 4.6), [robust rule, band 13 plus or minus 3 MAD], size: 6pt)
  cdraw.rect((px(-2.0), 2.8), (px(28.0), 4.1), fill: luma(242), radius: 0.01)
  cdraw.content((px(-2.0) - 0.9, 3.9), [-2], size: 6pt)
  cdraw.content((px(28.0) + 0.9, 3.9), [28], size: 6pt)
  for v in vals {
    cdraw.circle((px(v * 1.0), 3.45), radius: 0.09,
      fill: if v > 28 {luma(150)} else {luma(210)}, stroke: luma(60))
  }
  cdraw.content((px(58.0), 2.4), [58, rz = 9], size: 6pt)
  cdraw.content((px(74.0), 1.7), [74, rz = 61\/5], size: 6pt)
  cdraw.content((px(16.0), 4.45), [inliers end at rz = 9\/5], size: 6pt)
})

#callout("note", "strict on every boundary, four times over", [
  This chapter pins strict inequality at four separate fences: $|z| > 3$
  on the gaussian ruler, where 35 sits at exactly -3 unflagged; $D^2 >
  5.991$ on the joint rule; $x > "UF"$ on the fences, where the probe 30
  sits exactly on the upper fence unflagged; and $|z| > 3$ again on the
  robust ruler. Inclusive variants would flag 35 and the fence probe on
  this very fixture. The sign is behavior, so it lives in check names,
  four of them.
])

Two detectors per half, and one lesson per pair: the joint rule beats the
marginal ones because correlation is information, and the robust ones
beat the mean-based ones because outliers should not grade their own
papers. Both chapters behind, #xref-to("kdd", "cleaning") and
#xref-to("kdd", "normalize"), built the tools; this chapter pointed them
at detection. What none of them handle is the case where density itself
varies across the map, and that is #xref-to("kdd", "lof") next.

sources: NIST/SEMATECH e-Handbook of Statistical Methods, section 1.3.6.7,
chi-square distribution table, df = 2 critical 5.991 at alpha = 0.05,
exact form -2 ln 0.05, www.itl.nist.gov/div898/handbook, accessed
2026-09-22, pinned by the contract sheet. The MAD robust-z definition,
raw ratio with no 0.6745 scaling, from Leys, Ley, Klein, Bernard, Licata,
Journal of Experimental Social Psychology 49(4) 764-766, 2013, banked by
kdd-contract-s1s2.md. All 57 pinned values witnessed by
kdd-contract-s8s9.md and playground/kdd-matrix/gen_s8.py, run 2026-09-22,
exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch37`,
35 + 22 checks in chapter 37 of the kdd suite.
