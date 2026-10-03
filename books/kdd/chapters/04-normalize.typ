// ch04, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 44 checks in kdd/samples/src/Ch04/znorm.c or a cited source: Leys,
// Allen, Fisher, Lumley 2013, "Detecting outliers: Do not use standard
// deviation around the mean, use absolute deviation around the median",
// J. Exp. Soc. Psych. 49(4) 764-766, banked by kdd-contract-s1s2.md. all
// pinned values are witnessed by kdd-contract-s1s2.md +
// playground/kdd-matrix/gen_s1.py, run 2026-09-22, exit 0. every row of
// this chapter is D4-eligible: ch47 replays the fixtures in go.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= normalization and standardization

One sample carries the chapter: `znorm.c` runs three rescalings over
three short series chosen so every result is dyadic, an integer over a
power of two and therefore exact in binary floating point, and asserts 44
checks with exact `==` comparisons. The chapter makes 4 moves: min-max
to [0,1] and to [-1,1], the z-score with the population divisor, the
robust z built from median and MAD, and the symmetric series where the
two z-scores agree element for element. Every behavioral claim below is
one of the 44 checks of chapter 04's sample. Scaling does not add
information, it changes units, and #xref-to("kdd", "distance") consumes
those units directly. Every row here is D4-eligible, the fixtures replay
in go in #xref-to("kdd", "bridge").

== min-max, two targets

Min-max scaling is the affine map that sends the observed minimum and
maximum to the ends of a chosen interval. To [0,1] it is $(v - L)\/r$
with $r = "max" - "min"$; to [-1,1] it is the image of that composed
with $2u - 1$. The fixture is M = (2, 6, 8, 10, 14, 18), whose range 16
is a power of 2, so every division below is exact in binary.

The dry run: with L = 2 and r = 16 the images are (2 - 2)\/16 = 0,
4\/16 = 0.25, 6\/16 = 0.375, 8\/16 = 0.5, 12\/16 = 0.75, 16\/16 = 1,
printed as `range 16 minmax01: 0 0.25 0.375 0.5 0.75 1`. The [-1,1]
ruler applies 2u - 1 to each, printed as `minmax11: -1 -0.5 -0.25 0 0.5
1`. The map is strictly monotone, asserted by "ch04 minmax01 monotone
0..1", and it is affine, so equal gaps stay equal gaps: the 2-unit gap
between 6 and 8 is a 0.125 gap on both scaled rulers.

#listing("kdd/samples/src/Ch04/znorm.c", first: 96, last: 114,
  caption: [range, the 0..1 map, and the monotone assertion])

#listing("kdd/samples/src/Ch04/znorm.c", first: 116, last: 131,
  caption: [the -1..1 ruler as 2v - 1, checked elementwise])

#diagram([three rulers, same spacing, the affine map at work], length: 13pt, {
  let px(v) = { 1.2 + (v - 2.0) / 16.0 * 15.0 }
  let ruler(y, caption) = {
    cdraw.line((0.9, y), (16.6, y), stroke: luma(60))
    cdraw.content((17.6, y), caption, size: 6pt)
  }
  let vals = (2, 6, 8, 10, 14, 18)
  let labs0 = ([0], [0.25], [0.375], [0.5], [0.75], [1])
  let labs1 = ([-1], [-0.5], [-0.25], [0], [0.5], [1])
  ruler(6.4, [raw M])
  for i in range(6) {
    let x = px(vals.at(i) * 1.0)
    cdraw.line((x, 6.2), (x, 6.6), stroke: luma(60))
    cdraw.content((x, 6.85), [#vals.at(i)], size: 6pt)
    cdraw.line((x, 6.4), (x, 4.3), stroke: (paint: luma(200), dash: "dashed"))
  }
  ruler(4.3, [min-max 0..1])
  for i in range(6) {
    let x = px(vals.at(i) * 1.0)
    cdraw.line((x, 4.1), (x, 4.5), stroke: luma(60))
    cdraw.content((x, 3.75), labs0.at(i), size: 6pt)
    cdraw.line((x, 4.3), (x, 2.2), stroke: (paint: luma(200), dash: "dashed"))
  }
  ruler(2.2, [2v - 1])
  for i in range(6) {
    let x = px(vals.at(i) * 1.0)
    cdraw.line((x, 2.0), (x, 2.4), stroke: luma(60))
    cdraw.content((x, 1.65), labs1.at(i), size: 6pt)
  }
})

== z-scores, the population way

The z-score standardizes by standard deviation instead of range: $z =
(v - mu)\/s$, with $mu$ the mean and $s$ the root of the population
variance, divisor $n$. The fixture is A = (4, 6, 6, 6, 10, 16), one
modest outlier riding five tight values, and every statistic of it is an
integer.

The dry run: the mean is 48\/6 = 8. The deviations read (-4, -2, -2, -2,
2, 8), their squares sum 16 + 4 + 4 + 4 + 4 + 64 = 96, the population
variance is 96\/6 = 16, and $s = sqrt(16) = 4$, exact because 16 is a
perfect square. Dividing deviations by 4 gives z = (-1, -0.5, -0.5,
-0.5, 0.5, 2), printed as `A mean 8 SS 96 var 16 s 4 z: -1 -0.5 -0.5
-0.5 0.5 2`. The divisor is pinned by the check name itself, "ch04 A
population variance 16 (divisor n)", and it is not the same convention
as #xref-to("kdd", "cleaning"), which divided by n - 1.

#listing("kdd/samples/src/Ch04/znorm.c", first: 140, last: 164,
  caption: [mean, sum of squares, population variance, and the six z values])

#diagram([the same six values on the raw ruler and the z ruler], length: 13pt, {
  let py(v) = { 0.8 + (v - 2.0) * 0.36 }
  cdraw.content((2.2, 6.9), [raw], size: 6pt)
  cdraw.content((15.0, 6.9), [z = (v - 8)\/4], size: 6pt)
  cdraw.line((2.6, 0.9), (2.6, 6.4), stroke: luma(60))
  cdraw.line((14.6, 0.9), (14.6, 6.4), stroke: luma(60))
  let rows = ((4, [4], [-1]), (6, [6], [-0.5, x3]), (10, [10], [0.5]), (16, [16], [2]))
  for t in rows {
    let y = py(t.at(0) * 1.0)
    cdraw.line((2.7, y), (14.5, y), stroke: (paint: luma(200), dash: "dashed"))
    cdraw.circle((3.5, y), radius: 0.1, fill: luma(210), stroke: luma(60))
    cdraw.circle((13.7, y), radius: 0.1, fill: luma(210), stroke: luma(60))
    cdraw.content((1.9, y), t.at(1), size: 6pt)
    cdraw.content((15.5, y), t.at(2), size: 6pt)
  }
  cdraw.line((2.7, py(8.0)), (14.5, py(8.0)), stroke: luma(90))
  cdraw.content((8.6, py(8.0) + 0.3), [mean 8, z 0], size: 6pt)
})

== the robust z, median and MAD

The classic z has a blind spot documented by Leys, Allen, Fisher, and
Lumley in a paper whose title is the instruction: "Detecting outliers:
Do not use standard deviation around the mean, use absolute deviation
around the median". The robust z divides deviation from the median by
the MAD, the median absolute deviation, and this chapter uses their raw
definition, $(v - "median")\/"MAD"$ with no 0.6745 consistency constant.

The dry run: sorted A reads (4, 6, 6, 6, 10, 16), even count, median (6
+ 6)\/2 = 6. Absolute deviations from 6 are (2, 0, 0, 0, 4, 10), sorted
(0, 0, 0, 2, 4, 10), whose even middle averages to MAD = (0 + 2)\/2 = 1.
The robust z is then just the deviation from 6: (-2, 0, 0, 0, 4, 10),
printed as `A median 6 MAD 1 robust z: -2 0 0 0 4 10`. The point 16
tells the story: on the classic ruler it sits 2 standard deviations out,
on the robust ruler 10 deviations out, asserted together as "ch04
contrast classic z(16) = 2" and "ch04 contrast robust z(16) = 10". The
outlier inflated its own yardstick: the squared deviations of the single
value 16 contribute 64 of the 96 sum of squares.

#listing("kdd/samples/src/Ch04/znorm.c", first: 166, last: 189,
  caption: [median, MAD, robust z, and the two-ruler contrast at 16])

#diagram([value 16 measured on the classic ruler and the robust ruler], length: 13pt, {
  let pxt(z) = { 2.0 + (z + 1.0) / 3.0 * 8.0 }
  let pxb(z) = { 2.0 + (z + 2.0) / 12.0 * 8.0 }
  cdraw.content((2.0, 6.8), [classic z, divisor s = 4], size: 6pt)
  cdraw.line((2.0, 5.5), (10.4, 5.5), stroke: luma(60))
  for t in (-1, 0, 1, 2) {
    cdraw.line((pxt(t * 1.0), 5.3), (pxt(t * 1.0), 5.7), stroke: luma(60))
    cdraw.content((pxt(t * 1.0), 5.0), [#t], size: 6pt)
  }
  for z in (-1.0, -0.5, 0.5, 2.0) {
    cdraw.circle((pxt(z), 5.9), radius: 0.09,
      fill: if z == 2.0 {luma(150)} else {luma(210)}, stroke: luma(60))
  }
  cdraw.content((10.6, 5.9), [16], size: 6pt)
  cdraw.line((10.0, 2.0), (10.0, 6.6), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((11.6, 4.2), [the same value 16], size: 6pt)
  cdraw.content((2.0, 1.2), [robust z, divisor MAD = 1], size: 6pt)
  cdraw.line((2.0, 2.5), (10.4, 2.5), stroke: luma(60))
  for t in (-2, 0, 4, 10) {
    cdraw.line((pxb(t * 1.0), 2.3), (pxb(t * 1.0), 2.7), stroke: luma(60))
    cdraw.content((pxb(t * 1.0), 2.0), [#t], size: 6pt)
  }
  for z in (-2.0, 0.0, 4.0, 10.0) {
    cdraw.circle((pxb(z), 2.9), radius: 0.09,
      fill: if z == 10.0 {luma(150)} else {luma(210)}, stroke: luma(60))
  }
  cdraw.content((10.6, 2.9), [16], size: 6pt)
})

#callout("note", "which deviation constant is a per-book pin", [
  Some texts scale MAD by 1\/0.6745 so that it estimates the standard
  deviation under normality, Leys et al. discuss the choice and this
  book follows their raw ratio, pinned by the contract sheet as
  "robust z = (x - median)/MAD (Leys et al. 2013 definition, no 0.6745
  scaling)". The constant cancels in outlier ranking, all robust z
  values scale together, so the pin is a readability choice, not a
  modeling one.
])

== agreement on symmetric data

The two standardizations disagree exactly when the data is lopsided,
and they agree element for element on symmetric data. The fixture B =
(3, 5, 7, 9, 11, 13, 15) is an arithmetic ladder, perfectly symmetric
about its middle.

The dry run: the mean and the median both land on 9. The deviations (-6,
-4, -2, 0, 2, 4, 6) have squares summing 36 + 16 + 4 + 0 + 4 + 16 +
36 = 112, population variance 112\/7 = 16, so s = 4. The absolute
deviations from 9 are (6, 4, 2, 0, 2, 4, 6), sorted (0, 2, 2, 4, 4, 6,
6), and with odd count the middle one is MAD = 4. Both divisors equal 4
and both centers equal 9, so z and robust z are the same list (-1.5,
-1, -0.5, 0, 0.5, 1, 1.5), printed as `B mean 9 median 9 var 16 s 4 MAD
4` and asserted by seven checks, one per element, each named "ch04 B
z=... equals robust z".

#listing("kdd/samples/src/Ch04/znorm.c", first: 191, last: 210,
  caption: [the symmetric ladder, both divisors 4, seven equality checks])

#diagram([the symmetric ladder, raw values above, z values below], length: 13pt, {
  let px(z) = { 1.5 + (z + 1.5) / 3.0 * 14.5 }
  cdraw.line((1.0, 3.2), (16.6, 3.2), stroke: luma(60))
  let raw = (3, 5, 7, 9, 11, 13, 15)
  let zs = (-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5)
  for i in range(7) {
    let x = px(zs.at(i))
    cdraw.line((x, 3.0), (x, 3.4), stroke: luma(60))
    cdraw.circle((x, 3.9), radius: 0.09, fill: luma(210), stroke: luma(60))
    cdraw.content((x, 4.3), [#raw.at(i)], size: 6pt)
    cdraw.content((x, 2.65), [#zs.at(i)], size: 6pt)
  }
  cdraw.line((px(0.0), 2.1), (px(0.0), 4.9), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((8.75, 5.5), [mirror symmetry forces mean = median and s = MAD], size: 6pt)
})

Two standardizations, one lesson. Rescaling is a units decision with
consequences downstream: #xref-to("kdd", "distance") computes raw gaps
between whatever units it is handed, min-max stretches axes by range,
the z family by spread, and the choice changes which pairs count as
close. The fixtures of this chapter replay bit for bit in go in
#xref-to("kdd", "bridge").

sources: Christophe Leys, Christy Ley, Olivier Klein, Philippe Bernard,
Laurent Licata, "Detecting outliers: Do not use standard deviation
around the mean, use absolute deviation around the median", Journal of
Experimental Social Psychology 49(4), 764-766, 2013, banked by
kdd-contract-s1s2.md, the same sheet that pins the no-0.6745 spelling
used here. All 44 pinned values witnessed by the sheet and
playground/kdd-matrix/gen_s1.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch04`, 44 checks in chapter 04 of the
kdd suite.
