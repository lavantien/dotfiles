// ch40, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 60 checks in kdd/samples/src/Ch40/fdr.c (list P 35, family-size 2,
// list Q 23) or a definition quoted from a banked source: the Bonferroni
// correction; Holm, Scand. J. Statist. 6(2) 1979 65-70; Benjamini and
// Hochberg, JRSS-B 57(1) 1995 289-300, banked by kdd-contract-s8s9.md.
// the sheet's staircase hand-note concedes its own arithmetic slip, a
// first pass wrote the k = 8 raw as 5/8 where (10/8)(1/4) = 5/16; the
// fenced generator block and the C pin the corrected values and this
// chapter follows them. all arithmetic is exact fractions (D0). all
// pinned values are witnessed by the sheet +
// playground/kdd-matrix/gen_s8.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= multiple testing: bonferroni and fdr

One sample carries the chapter: `fdr.c` runs three rejection procedures
over two pinned lists of p-values and checks every step of every one,
60 checks. List P is ten hypotheses, list Q is six, both at alpha = q =
1/20. The chapter makes 4 moves: the Bonferroni threshold and the
family-size bill it sends, Holm's step-down that spends the budget as it
walks, Benjamini-Hochberg and the largest k that holds, and the adjusted
p staircase that turns the procedure into one number per hypothesis.
Every behavioral claim below is one of the 60 checks of chapter 40's
sample or a definition from the three banked papers. #xref-to("kdd",
"hypothesis") priced one test at a true 2.15 percent; a pipeline like
the chi-squared screen of #xref-to("kdd", "features") runs one test per
column, and this chapter is what ten simultaneous 2.15 percents cost.

== one threshold for ten tests

The naive way to fire ten tests at 5 percent each is to fire them, and
collect roughly one false alarm per pipeline by accident. Bonferroni's
fix is one threshold for the whole family: reject when $p <= alpha\/m$,
which caps the chance of any false rejection at alpha no matter how the
p-values correlate. List P carries ten pinned p-values, H1 through H10,
and the sample sorts them once, asserted as "ch40 P ascending sort
order" with `P sorted=H2,H6,H5,H4,H8,H3,H1,H9,H10,H7`.

The dry run: the threshold is $(1\/20)\/10 = 1\/200$, printed `P
bonf_thr=1/200 reject={H2,H6} n=2` and asserted as "ch40 P bonferroni
thr 1/200 n=2". Only H2 at 1\/1000 = 0.001 and H6 at 9\/2000 = 0.0045
duck under it; H5 at 1\/160 = 0.00625 misses by a quarter of the bar.
The price is the family-size block: the very same p = 1\/160 against
$m = 5$ gives threshold $(1\/20)\/5 = 1\/100$ and `familysize m=5
thr=1/100 reject=true`, asserted as "ch40 1/160 clears the m=5
bonferroni bar 1/100"; against $m = 50$ the threshold is 1\/1000 and
`familysize m=50 thr=1/1000 reject=false`, "ch40 1/160 fails the m=50
bonferroni bar 1/1000". Yesterday's discovery evaporates the day forty
innocent tests join the family, which is Bonferroni's honesty and its
weakness in one row.

#listing("kdd/samples/src/Ch40/fdr.c", first: 227, last: 252,
  caption: [list P: ten pinned p-values and every expected step of every procedure])

#listing("kdd/samples/src/Ch40/fdr.c", first: 117, last: 137,
  caption: [bonferroni: one threshold alpha/m, cross-multiplied against every p])

#listing("kdd/samples/src/Ch40/fdr.c", first: 254, last: 263,
  caption: [the same p under family sizes 5, 10, and 50])

#diagram([list P against the 1/200 bar; below, one p against three family sizes], length: 13pt, {
  let px(i) = { 1.1 + i * 1.62 }
  let py(v) = { 0.6 + v * 5.8 }
  let ids = ("H2", "H6", "H5", "H4", "H8", "H3", "H1", "H9", "H10", "H7")
  let ps = (1.0 / 1000.0, 9.0 / 2000.0, 1.0 / 160.0, 7.0 / 400.0, 7.0 / 200.0,
    3.0 / 20.0, 1.0 / 5.0, 1.0 / 4.0, 3.0 / 10.0, 9.0 / 10.0)
  for i in range(10) {
    cdraw.rect((px(i) - 0.5, 0.6), (px(i) + 0.5, py(ps.at(i))),
      fill: if i <= 1 {luma(186)} else {luma(232)}, radius: 0.01)
    cdraw.content((px(i), 0.25), [#ids.at(i)], size: 6pt)
  }
  cdraw.line((0.7, py(1.0 / 200.0)), (17.2, py(1.0 / 200.0)), stroke: luma(90))
  cdraw.content((6.7, 0.98), [1\/200], size: 6pt)
  cdraw.content((px(0.0), 1.06), [1\/1000], size: 6pt)
  cdraw.content((px(1.0), 1.08), [9\/2000], size: 6pt)
  cdraw.content((px(2.0), 1.12), [1\/160], size: 6pt)
  cdraw.content((px(5.0), py(3.0 / 20.0) + 0.36), [3\/20], size: 6pt)
  cdraw.content((px(9.0), py(9.0 / 10.0) + 0.36), [9\/10], size: 6pt)
  let qy(v) = { -4.0 + v * 300.0 }
  let qx(i) = { 4.2 + i * 4.0 }
  cdraw.line((3.3, -2.5), (13.2, -2.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((14.4, -2.25), [1\/200, m = 10], size: 6pt)
  cdraw.line((3.4, -4.0), (13.3, -4.0), stroke: luma(170))
  let fam = ((1.0 / 1000.0, [1\/1000 (m = 50)]), (1.0 / 160.0, [1\/160 (the p)]),
    (1.0 / 100.0, [1\/100 (m = 5)]))
  for i in range(3) {
    let x = qx(i)
    cdraw.rect((x - 0.5, -4.0), (x + 0.5, qy(fam.at(i).at(0))),
      fill: if i == 1 {luma(186)} else {luma(232)}, radius: 0.01)
    cdraw.content((x, qy(fam.at(i).at(0)) + 0.4), fam.at(i).at(1), size: 6pt)
  }
  cdraw.content((1.1, -2.6), [one p,], size: 6pt)
  cdraw.content((1.1, -3.15), [three bars], size: 6pt)
})

== holm's shrinking bar

Bonferroni charges every hypothesis the full family tax. Holm's
step-down walks the sorted p-values from smallest up and relaxes the bar
as it goes: at step k the threshold is $alpha\/(m - k + 1)$, and the
first miss stops the walk, everything after it inherits the stop. The
procedure controls the family-wise error at alpha like Bonferroni and
rejects at least as much, for free.

The dry run: the sample prints one line per step, ten for list P. The
first three read `holm H2 k=1 p=1/1000 thr=1/200 reject`, `holm H6 k=2
p=9/2000 thr=1/180 reject`, and the boundary row `holm H5 k=3 p=1/160
thr=1/160 reject`, where p equals the threshold exactly and the rule's
<= lets it through, asserted as "ch40 P holm k=3 thr 1/160 reject".
Step four is the first miss, `holm H4 k=4 p=7/400 thr=1/140 STOP`:
7\/400 = 0.0175 against 1\/140 = 0.0071, and the remaining six lines all
print STOP with thresholds relaxing on paper, 1\/120 down to 1\/20, that
nothing can spend. The summary prints `P holm_reject={H2,H6,H5} n=3`,
asserted as "ch40 P holm rejects n=3". Bonferroni bought 2, Holm bought
3, and H5 is exactly the extra one, caught at the boundary where p
equals the bar.

#listing("kdd/samples/src/Ch40/fdr.c", first: 139, last: 166,
  caption: [holm step-down: alpha/(m - k + 1), first miss stops the walk])

#diagram([holm's walk over sorted list P: three rejects, an exact boundary, one stop], length: 13pt, {
  let bx(k) = { 1.05 + k * 1.68 }
  let ids = ("H2", "H6", "H5", "H4", "H8", "H3", "H1", "H9", "H10", "H7")
  let ps = ("1/1000", "9/2000", "1/160", "7/400", "7/200", "3/20", "1/5", "1/4", "3/10", "9/10")
  let ts = ("1/200", "1/180", "1/160", "1/140", "1/120", "1/100", "1/80", "1/60", "1/40", "1/20")
  for k in range(10) {
    let stop = k >= 3
    cdraw.rect((bx(k) - 0.72, 2.6), (bx(k) + 0.72, 4.6),
      fill: if stop {luma(246)} else {luma(224)},
      stroke: if k == 2 {(paint: luma(60), dash: "dashed")} else if stop {luma(220)} else {luma(150)},
      radius: 0.02)
    cdraw.content((bx(k), 4.28), [#ids.at(k)], size: 6pt)
    cdraw.content((bx(k), 3.78), [p #ps.at(k)], size: 6pt)
    cdraw.content((bx(k), 3.18), [thr #ts.at(k)], size: 6pt)
    cdraw.content((bx(k), 2.25), [#(k + 1)], size: 6pt)
  }
  cdraw.content((bx(2.0), 5.0), [p = thr = 1\/160, reject by <=], size: 6pt)
  cdraw.content((bx(3.0), 1.7), [first miss: 7\/400 > 1\/140], size: 6pt)
  cdraw.content((10.6, 1.05), [everything after inherits the stop], size: 6pt)
})

== the largest k that holds

Benjamini-Hochberg changes the currency: instead of bounding the chance
of any false rejection, it bounds the expected share of rejections that
are false, the false discovery rate, at most q. The rule reads backward
from Holm: sort ascending, and take the largest k with $p(k) <= (k\/m)
q$; reject the first k. The bar rises with k instead of shrinking, so
the game is finding how far up the sorted list the p-values can keep
pace with a line that grows.

The dry run: the sample prints one comparison per step. The holding
edge is `bh k=4 H4 p=7/400 thr=1/50 <=`, asserted as "ch40 P bh k=4 thr
1/50 <=": 7\/400 = 0.0175 against $(4\/10)(1\/20) = 1\/50 = 0.02$. The
next step misses, `bh k=5 H8 p=7/200 thr=1/40 >`, 0.035 against 0.025,
and every later step misses by more. The largest k that holds is 4, so
`P bh_kstar=4 reject={H2,H6,H5,H4} n=4`, asserted as "ch40 P bh k\*=4":
one more discovery than Holm, two more than Bonferroni, paid for in the
weaker promise.

#listing("kdd/samples/src/Ch40/fdr.c", first: 168, last: 190,
  caption: [benjamini-hochberg: largest k with p(k) <= (k/m) q, reject the first k])

#diagram([sorted p against the rising (k/m) q bar: the pace holds through k = 4, breaks at k = 5], length: 13pt, {
  let px(k) = { 1.5 + (k - 1) * 3.05 }
  let py(v) = { 0.7 + v * 117.0 }
  let ramp = ((1, 0.005), (2, 0.01), (3, 0.015), (4, 0.02), (5, 0.025))
  for i in range(4) {
    cdraw.line((px(ramp.at(i).at(0) * 1.0), py(ramp.at(i).at(1))),
      (px(ramp.at(i + 1).at(0) * 1.0), py(ramp.at(i + 1).at(1))), stroke: luma(90))
  }
  cdraw.content((6.2, 2.3), [the bar (k\/m) q], size: 6pt)
  let dots = ((1, 0.001), (2, 0.0045), (3, 0.00625), (4, 0.0175), (5, 0.035))
  for d in dots {
    cdraw.circle((px(d.at(0) * 1.0), py(d.at(1))), radius: 0.1,
      fill: if d.at(0) <= 4 {luma(170)} else {luma(215)}, stroke: luma(60))
  }
  cdraw.content((2.6, 0.95), [1\/1000], size: 6pt)
  cdraw.content((5.65, 1.35), [9\/2000], size: 6pt)
  cdraw.content((8.7, 1.55), [1\/160], size: 6pt)
  cdraw.content((12.55, 4.95), [7\/200], size: 6pt)
  cdraw.content((12.9, 4.3), [7\/400 <= 1\/50 at k = 4, holds], size: 6pt)
  cdraw.content((12.3, 5.75), [7\/200 > 1\/40 at k = 5, misses], size: 6pt)
  for k in range(1, 6) {
    cdraw.content((px(k * 1.0), -0.1), [#k], size: 6pt)
  }
  cdraw.content((7.5, 0.45), [largest k that holds: k\* = 4], size: 6pt)
  cdraw.content((5.5, 6.2), [k = 6..10 miss by an order of magnitude], size: 6pt)
})

== the staircase, and a stubborn list

The three procedures answer yes or no. The adjusted p-value answers
how small q would have to be, and for BH it is a staircase: $"padj"(k) =
min_(j >= k) (m\/j) p(j)$, the backward running minimum of the scaled
p-values, so a hypothesis can only inherit a larger value from the
steps above it. The sample computes it in one backward sweep and prints
one line per hypothesis, REJECT appended when the result fits under
1\/20.

The dry run: the raw staircase for list P reads $(m\/k) p(k)$ = 1\/100,
9\/400, 1\/48, 7\/160, 7\/100, 1\/4, 2\/7, 5\/16, 1\/3, 9\/10, and the
sweep changes exactly one entry: 9\/400 at k = 2 sits above the 1\/48
waiting at k = 3, so it is absorbed and `padj H6=1/48 REJECT` matches
`padj H5=1/48 REJECT`, a flat pair, asserted as "ch40 P padj(H6) =
1/48 REJECT". Four values fit the budget, `padj H2=1/100 REJECT`
through `padj H4=7/160 REJECT`, the fifth `padj H8=7/100` does not,
and the count closes the loop: `P padj_reject_n=4 agrees_kstar=true`,
asserted as "ch40 P padj count 4 agrees with k\*". Then list Q, six
hypotheses built to embarrass the single threshold. Bonferroni at 1\/120
rejects nothing, `Q bonf_thr=1/120 reject={} n=0`, and Holm stops on
its first step, `holm H1 k=1 p=1/80 thr=1/120 STOP`. BH does not care:
`bh k=2 H2 p=1/80 thr=1/60 <=`, so `Q bh_kstar=2 reject={H1,H2} n=2`,
asserted as "ch40 Q bh k\*=2". The Q staircase absorbs k = 1's 3\/40
into k = 2's 3\/80 and both print `padj H1=3/80 REJECT` and `padj
H2=3/80 REJECT`. Two rules that cannot speak, one that can.

#listing("kdd/samples/src/Ch40/fdr.c", first: 192, last: 223,
  caption: [the backward cummin staircase, one padj per hypothesis, count agreeing with k\*])

#listing("kdd/samples/src/Ch40/fdr.c", first: 265, last: 283,
  caption: [list Q: bonferroni and holm reject nothing, BH rejects two])

#diagram([the staircase as boxes: raw (m/k) p above, adjusted p below, lists P and Q], length: 13pt, {
  let bx(k) = { 1.55 + k * 3.0 }
  let pbox = (([1\/100], [1\/100]), ([9\/400], [1\/48]), ([1\/48], [1\/48]),
    ([7\/160], [7\/160]), ([7\/100], [7\/100]))
  for k in range(5) {
    let rej = k <= 3
    cdraw.rect((bx(k) - 1.35, 3.6), (bx(k) + 1.35, 5.8),
      fill: if rej {luma(224)} else {luma(246)},
      stroke: if k == 1 {(paint: luma(60), dash: "dashed")} else {luma(170)}, radius: 0.02)
    cdraw.content((bx(k), 5.32), [raw #pbox.at(k).at(0)], size: 6pt)
    cdraw.content((bx(k), 4.52), [padj #pbox.at(k).at(1)], size: 6pt)
    cdraw.content((bx(k), 6.15), [k = #(k + 1)], size: 6pt)
  }
  cdraw.content((2.2, 6.75), [list P, m = 10], size: 6pt)
  cdraw.content((bx(1.0), 3.15), [9\/400 absorbed up to the k = 3 value], size: 6pt)
  cdraw.content((11.3, 3.15), [padj <= 1\/20: k = 1..4, four = k\*], size: 6pt)
  let qbox = (([3\/40], [3\/80]), ([3\/80], [3\/80]))
  for k in range(2) {
    let x = 4.5 + k * 3.0
    cdraw.rect((x - 1.35, 0.4), (x + 1.35, 2.6), fill: luma(224),
      stroke: if k == 0 {(paint: luma(60), dash: "dashed")} else {luma(170)}, radius: 0.02)
    cdraw.content((x, 2.12), [raw #qbox.at(k).at(0)], size: 6pt)
    cdraw.content((x, 1.32), [padj #qbox.at(k).at(1)], size: 6pt)
    cdraw.content((x, 0.05), [k = #(k + 1)], size: 6pt)
  }
  cdraw.content((1.4, 2.95), [list Q, m = 6], size: 6pt)
  cdraw.content((11.6, 1.5), [bonf 1\/120: nothing; BH k\* = 2: both], size: 6pt)
})

#callout("pitfall", "why 5 over 16, and not 5 over 8", [
  The sheet records a conceded slip worth retelling: a first hand pass
  wrote the k = 8 raw staircase value as 5\/8 and let padj(H9) slide
  into its neighbor's 1\/3. The arithmetic is one division, $(10\/8)
  (1\/4) = 5\/16$, and the corrected generator run pins `padj H9=5/16`
  alongside `padj H10=1/3`. The staircase is where the transcription
  errors live, ten multiplications and a running minimum in exact
  fractions, which is why every adjusted value is asserted as a reduced
  pair and the padj count must equal k\*, a cross-check the sheet itself
  calls the hard one.
])

Three procedures, one trade: Bonferroni and Holm promise no false
rejections at all and pay in power, BH promises a bounded share of them
and pays in the promise. List P prices the spread at 2, 3, and 4
discoveries, list Q prices the single-threshold rules at zero. The
statistics families close here, and the book turns to structure again
with #xref-to("kdd", "rough").

sources: the Bonferroni correction, reject at alpha/m for a family of
m tests, per the Boole-Bonferroni inequality as banked by
kdd-contract-s8s9.md. Sture Holm, "A Simple Sequentially Rejective
Multiple Test Procedure", Scandinavian Journal of Statistics 6(2) 1979,
65-70, the step-down with threshold alpha/(m - k + 1). Yoav Benjamini
and Yosef Hochberg, "Controlling the False Discovery Rate: A Practical
and Powerful Approach to Multiple Testing", Journal of the Royal
Statistical Society, Series B 57(1) 1995, 289-300, the step-up and the
adjusted-p staircase. All 60 pinned values witnessed by the sheet and
playground/kdd-matrix/gen_s8.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch40`, 35 + 2 + 23 checks in
chapter 40 of the kdd suite.
