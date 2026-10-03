// ch10, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 42 checks in kdd/samples/src/Ch10/haar.c or a pinned note of
// kdd-contract-s1s2.md (the avg/det convention, the keep-k lowest-index
// tie-break, the dyadic-exactness pin). all pinned values are witnessed
// by kdd-contract-s1s2.md + playground/kdd-matrix/gen_s2.py, run
// 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the haar wavelet transform

One sample carries the chapter: `haar.c` runs the 3-level Haar forward
and inverse transform on two 8-point signals, verifies the single-level
identity, truncates to the 2 largest coefficients with a pinned
tie-break, and accounts for every unit of energy as an exact fraction, 42
checks in all. The chapter makes 4 moves: the averaging pair operator and
the 3-level coefficient layout, the inverse and why reconstruction is
bit-exact here, keep-k truncation and its lowest-index tie-break, and
energy retention as reduced fractions. Every behavioral claim below is
one of the 42 checks of chapter 10's sample or a pinned note of the
contract sheet. #xref-to("kdd", "pca") reduced dimension by rotating
axes, this chapter reduces by throwing detail away, and
#xref-to("kdd", "features") selects columns while this chapter
recombines them.

== averages and differences

The Haar transform runs one pair operator down the signal: avg = (a +
b)\/2 and det = (a - b)\/2. The average keeps what neighboring samples
agree on, the detail keeps what they disagree on, and the pair (avg,
det) is just (a, b) written in a different basis, so nothing is lost,
only re-shelved. Level 1 pairs the samples, level 2 pairs the
averages, level 3 averages those, and an 8-point signal ends as one
overall average plus one detail per scale.

The dry run: the smooth fixture is S = (4, 6, 8, 10, 20, 20, 20, 20), a
ramp then a plateau. Level 1 pairs give avgs (5, 9, 20, 20) and dets
(-1, -1, 0, 0). Level 2 pairs the averages: (7, 20) with dets (-2, 0).
Level 3 averages those: 13.5 with det -6.5. The transform prints as
`T(S) = 13.5 -6.5 -2 0 -1 -1 0 0`, eight checks, one per coefficient.
The noisy fixture N = (4, 12, 4, 12, 20, 12, 20, 12), the same 8/16 step
shape with a +-4 wobble riding it, prints `T(N) = 12 -4 0 0 -4 -4 4 4`:
the same coarse story in the first two slots, but all four level-0
detail slots now carry +-4 wobble instead of zeros.

#listing("kdd/samples/src/Ch10/haar.c", first: 41, last: 60,
  caption: [one pass: averages into the front half, details into the back])

#diagram([the 8 coefficients of each signal shelved by scale], length: 13pt, {
  let bands = (([avg L3], 1), ([det L2], 1), ([dets L1], 2), ([dets L0], 4))
  let shades = (luma(200), luma(216), luma(230), luma(244))
  let strip(y0, vals) = {
    let x = 1.3
    for i in range(8) {
      cdraw.rect((x, y0), (x + 1.9, y0 + 0.72), fill: shades.at(if i == 0 {0} else if i == 1 {1} else if i < 4 {2} else {3}), radius: 0.01)
      cdraw.content((x + 0.95, y0 + 0.36), vals.at(i), size: 6.5pt)
      x += 2.0
    }
    let bx = 1.3
    for b in bands {
      cdraw.content((bx + b.at(1) * 0.95, y0 + 1.0), b.at(0), size: 5.5pt)
      bx += b.at(1) * 2.0
    }
  }
  cdraw.content((0.9, 6.15), [T(S)], size: 6pt)
  strip(4.6, ([13.5], [-6.5], [-2], [0], [-1], [-1], [0], [0]))
  cdraw.content((0.9, 2.9), [T(N)], size: 6pt)
  strip(1.35, ([12], [-4], [0], [0], [-4], [-4], [4], [4]))
  cdraw.content((12.6, 7.35), [coarse on the left], size: 6pt)
  cdraw.content((12.6, 6.7), [fine on the right], size: 6pt)
  cdraw.content((12.6, 2.9), [N pays for its wobble], size: 6pt)
  cdraw.content((12.6, 2.25), [in all four L0 slots], size: 6pt)
})

== the inverse, bit for bit

The inverse operator is the same butterfly run backwards: a = avg + det,
b = avg - det. Apply it level by level, doubling the working width each
time, and the original signal comes back. What makes the round trip
exact is arithmetic, not luck: starting from integers, every average and
difference is a half-integer, halving again stays dyadic, and dyadic
rationals are represented exactly in binary floating point. No rounding
ever happens, so `==` against the original is a legitimate assertion,
the same family of pin as the single-sqrt cosine of
#xref-to("kdd", "similarity").

The dry run: the single-level identity on the raw pairs prints `L1 S:
avgs (5, 9, 20, 20) dets (-1, -1, 0, 0)` and `L1 N: avgs (8, 8, 16, 16)
dets (-4, -4, 4, 4)`, and the identity checks assert avg + det and avg
- det reproduce every original sample. The full 3-level round trips are
asserted whole, "ch10 inverse reproduces S exactly" and "ch10 inverse
reproduces N exactly", all sixteen samples compared with `==`. The
plateau pairs are the visible freebie: (20, 20) averages to 20 with
detail 0, agreement costs nothing to encode.

#listing("kdd/samples/src/Ch10/haar.c", first: 62, last: 81,
  caption: [the inverse butterfly, doubling the working width per level])

#listing("kdd/samples/src/Ch10/haar.c", first: 172, last: 192,
  caption: [single-level avgs and dets on both signals, identity asserted])

#diagram([one butterfly forward and back on the pair (4, 6)], length: 13pt, {
  cdraw.rect((1.4, 5.2), (3.4, 6.1), fill: luma(244), radius: 0.02)
  cdraw.content((2.4, 5.65), [4], size: 7pt)
  cdraw.rect((1.4, 3.8), (3.4, 4.7), fill: luma(244), radius: 0.02)
  cdraw.content((2.4, 4.25), [6], size: 7pt)
  cdraw.line((3.4, 5.65), (6.0, 5.65), stroke: luma(60))
  cdraw.line((3.4, 4.25), (6.0, 4.25), stroke: luma(60))
  cdraw.line((3.4, 5.65), (6.0, 4.25), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((3.4, 4.25), (6.0, 5.65), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.rect((6.0, 5.2), (8.0, 6.1), fill: luma(238), radius: 0.02)
  cdraw.content((7.0, 5.65), [avg 5], size: 7pt)
  cdraw.rect((6.0, 3.8), (8.0, 4.7), fill: luma(238), radius: 0.02)
  cdraw.content((7.0, 4.25), [det -1], size: 7pt)
  cdraw.content((4.7, 6.6), [avg = (4 + 6)\/2 = 5], size: 6pt)
  cdraw.content((4.7, 3.25), [det = (4 - 6)\/2 = -1], size: 6pt)
  cdraw.line((8.6, 4.95), (9.6, 4.95), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.0, 4.95), (11.0, 4.95), stroke: luma(60), mark: (end: "<"))
  cdraw.content((10.3, 5.4), [lossless], size: 6pt)
  cdraw.rect((11.4, 5.2), (13.4, 6.1), fill: luma(238), radius: 0.02)
  cdraw.content((12.4, 5.65), [avg 5], size: 7pt)
  cdraw.rect((11.4, 3.8), (13.4, 4.7), fill: luma(238), radius: 0.02)
  cdraw.content((12.4, 4.25), [det -1], size: 7pt)
  cdraw.line((13.4, 5.65), (16.0, 5.65), stroke: luma(60))
  cdraw.line((13.4, 4.25), (16.0, 4.25), stroke: luma(60))
  cdraw.line((13.4, 5.65), (16.0, 4.25), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((13.4, 4.25), (16.0, 5.65), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.rect((16.0, 5.2), (18.0, 6.1), fill: luma(244), radius: 0.02)
  cdraw.content((17.0, 5.65), [4], size: 7pt)
  cdraw.rect((16.0, 3.8), (18.0, 4.7), fill: luma(244), radius: 0.02)
  cdraw.content((17.0, 4.25), [6], size: 6pt)
  cdraw.content((14.7, 6.6), [a = 5 + (-1) = 4], size: 6pt)
  cdraw.content((14.7, 3.25), [b = 5 - (-1) = 6], size: 6pt)
})

#callout("note", "dyadic means the == is honest", [
  Every coefficient of both fixtures is a dyadic rational, an integer
  over a power of two, so the forward transform, the inverse, and the
  truncated reconstruction all compute exactly representable doubles
  and the sample compares them with `==`. The dyadics are closed under
  halving, which is the whole argument: from integer inputs, no level
  of the transform ever produces a value binary floating point cannot
  hold. The same closure is what let #xref-to("kdd", "normalize") divide
  by the power-of-two range 16 and #xref-to("kdd", "similarity") take
  one sqrt of a perfect square.
])

== keep 2 of 8

Compression keeps the k largest-magnitude coefficients and zeroes the
rest, and the whole trick is that the coarse shelves carry almost
everything. The selection rule is pinned: sort by descending magnitude,
and an equal magnitude never displaces an earlier index, so ties resolve
to the lowest coefficient index.

The dry run: on T(S) = (13.5, -6.5, -2, 0, -1, -1, 0, 0) the two
largest magnitudes are 13.5 and 6.5 at indices 0 and 1, printed as
`keep-2 S: kept (0, 1) values (13.5, -6.5), recon 7 7 7 7 20 20 20 20`.
The zeroed transform unwinds in three steps: level 3 gives (7, 20),
level 2 spreads to (7, 7, 20, 20), level 1 fills all eight, four 7s and
four 20s. On T(N) the top magnitudes are 12 at index 0 and then a
five-way tie at magnitude 4 spanning indices 1, 4, 5, 6, 7, and the
lowest-index rule keeps index 1, printed as `keep-2 N: kept (0, 1)
values (12, -4), recon 8 8 8 8 16 16 16 16`. The wobble lives entirely
in the discarded slots, so the reconstruction is the clean step shape
with every wiggle gone.

#listing("kdd/samples/src/Ch10/haar.c", first: 84, last: 99,
  caption: [ascending scan, an equal magnitude never displaces])

#listing("kdd/samples/src/Ch10/haar.c", first: 204, last: 224,
  caption: [keep-2 on the smooth signal, reconstruction checked value by value])

#listing("kdd/samples/src/Ch10/haar.c", first: 225, last: 244,
  caption: [keep-2 on the noisy signal, the |4| tie resolving to index 1])

#diagram([the noisy magnitudes, two kept, and the flat step that comes back], length: 13pt, {
  let px(i) = { 1.9 + i * 1.7 }
  let vals = (12, -4, 0, 0, -4, -4, 4, 4)
  cdraw.line((1.2, 7.0), (16.2, 7.0), stroke: luma(60))
  for i in range(8) {
    let h = calc.abs(vals.at(i)) * 0.115
    if h > 0.01 {
      cdraw.rect((px(i) - 0.42, 7.0), (px(i) + 0.42, 7.0 + h),
        fill: if i < 2 {luma(170)} else {luma(226)}, radius: 0.01)
    }
    cdraw.content((px(i), 7.0 + calc.abs(vals.at(i)) * 0.115 + 0.32), [#vals.at(i)], size: 5.5pt)
    cdraw.content((px(i), 6.55), [#i], size: 5.5pt)
  }
  cdraw.content((9.0, 8.6), [T(N) magnitudes, kept indices 0 and 1], size: 6pt)
  let py(v) = { 1.1 + (v - 4) * 0.12 }
  let nz = (4, 12, 4, 12, 20, 12, 20, 12)
  for i in range(8) {
    cdraw.circle((px(i), py(nz.at(i) * 1.0)), radius: 0.09, fill: luma(214), stroke: luma(60))
  }
  for i in range(8) {
    let v = if i < 4 {8} else {16}
    cdraw.rect((px(i) - 0.5, py(v * 1.0) - 0.09), (px(i) + 0.5, py(v * 1.0) + 0.09),
      fill: luma(180), radius: 0.01)
  }
  cdraw.content((9.0, 0.5), [original N as dots, keep-2 reconstruction as the flat step], size: 6pt)
})

== energy, accounted in fractions

Signal energy is the sum of squares, and Parseval's identity for this
orthogonal transform says the coefficients carry the same total energy
as the samples. Truncation spends energy where it discards
coefficients, and the sample keeps the whole accounting in integers:
energies as sums of squares, retentions as reduced fraction pairs, the
doubles only a display of the exact fractions.

The dry run: S's energy is $16 + 36 + 64 + 100 + 4 dot 400 = 1816$, the
reconstruction holds $4 dot 49 + 4 dot 400 = 1796$, and the retention
prints as `energies: S 1816 -> 1796 = 449/454 (0.98898678414096919)`,
the fraction reduced by gcd 4, 449 prime. N's energy is two 4-12 pairs
and two 20-12 pairs, $2(16 + 144) + 2(400 + 144) = 320 + 1088 = 1408$,
its reconstruction $4 dot 64 + 4 dot 256 = 1280$,
retention 10\/11, printed as `N 1408 -> 1280 = 10/11
(0.90909090909090906)`. The contrast check pins the ordering, smooth
beats noisy, by cross-multiplication, and the discarded wobble prints
as `wobble 128/1408 = 1/11 discarded`: the noisy signal loses exactly
one eleventh of its energy, all of it wobble, all of it in the detail
coefficients the last facet threw away.

#listing("kdd/samples/src/Ch10/haar.c", first: 249, last: 266,
  caption: [energies as integer sums of squares, recon energies recomputed])

#listing("kdd/samples/src/Ch10/haar.c", first: 267, last: 286,
  caption: [retentions as reduced pairs, doubles pinned as nearest doubles])

#listing("kdd/samples/src/Ch10/haar.c", first: 288, last: 297,
  caption: [the wobble 128/1408 reduced to 1/11, discarded with the details])

#diagram([two signals, two retentions, the wobble is exactly one eleventh], length: 13pt, {
  let bars = ((3.2, [S], 1816, 1796, [449/454, 98.9 percent]), (10.6, [N], 1408, 1280, [10/11, 90.9 percent]))
  for b in bars {
    let x0 = b.at(0)
    let h1 = b.at(2) * 0.0029
    let h2 = b.at(3) * 0.0029
    cdraw.rect((x0, 1.5), (x0 + 2.0, 1.5 + h1), fill: luma(232), radius: 0.01)
    cdraw.rect((x0 + 2.5, 1.5), (x0 + 4.5, 1.5 + h2), fill: luma(170), radius: 0.01)
    cdraw.content((x0 + 1.0, 1.5 + h1 + 0.35), [#b.at(2)], size: 6pt)
    cdraw.content((x0 + 3.5, 1.5 + h2 + 0.35), [#b.at(3)], size: 6pt)
    cdraw.content((x0 + 1.0, 1.0), [#b.at(1), original], size: 6pt)
    cdraw.content((x0 + 3.5, 1.0), [keep-2], size: 6pt)
    cdraw.content((x0 + 2.25, 7.75), b.at(4), size: 6pt)
  }
  cdraw.content((4.4, 4.6), [the smooth pair is nearly level], size: 6pt)
  cdraw.content((4.4, 3.9), [the noisy pair loses its wobble], size: 6pt)
  cdraw.content((12.9, 3.2), [discarded: 128/1408 = 1/11], size: 6pt)
  cdraw.content((12.9, 2.5), [all of it detail energy], size: 6pt)
})

Two signals, one verdict. The smooth fixture keeps 449 of every 454
energy units with a quarter of the coefficients, the noisy one keeps 10
of 11, and both reconstructions were exact integers before any double
was printed. That is the transformation arc of the book's first ten
chapters closed: #xref-to("kdd", "binning") shrank values,
#xref-to("kdd", "pca") rotated axes, and this chapter kept two shelves
and dropped the rest, each with its arithmetic pinned to the last
integer.

sources: all 42 pinned values, the avg/det convention (avg = (a + b)/2,
det = (a - b)/2, inverse a = avg + det, b = avg - det), the keep-k
lowest-index tie-break, and the dyadic-exactness note witnessed by
kdd-contract-s1s2.md and playground/kdd-matrix/gen_s2.py, run 2026-09-22,
exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch10`,
42 checks in chapter 10 of the kdd suite.
