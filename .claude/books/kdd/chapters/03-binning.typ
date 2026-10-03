// ch03, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 30 checks in kdd/samples/src/Ch03/bin.c (17) and smooth.c (13) or a
// cited source: Zaki and Meira, Data Mining and Machine Learning, 2nd ed,
// ch 3 categorical attributes, the equal-depth walkthrough of the same
// 9-value series, cs.rpi.edu/~zaki/DMML/slides/pdf/ychap3.pdf, accessed
// 2026-09-22. all pinned values are witnessed by kdd-contract-s1s2.md +
// playground/kdd-matrix/gen_s1.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= binning, smoothing, and discretization

Two samples carry the chapter: `bin.c` cuts a sorted 12-value series into
bins two ways and asserts 17 checks, `smooth.c` replaces the classic
9-value textbook series with per-bin statistics and asserts 13. The
chapter makes 4 moves: equal-width bins and their half-open edges,
equal-frequency bins on the same series, smoothing by bin means and
medians, and smoothing by boundaries with its tie rule. Every behavioral
claim below is one of the 30 checks of chapter 03's samples. Binning is
the first transformation stage move of #xref-to("kdd", "process"): it
turns a noisy scale into a small set of shelves that
#xref-to("kdd", "features") can count against and
#xref-to("kdd", "normalize") can leave alone.

== equal width, four shelves

Equal-width binning asks only for the range and k: width w = (max -
min)\/k, and bin k covers $[L + k w, L + (k + 1) w)$, half open, except
the last bin which closes on the right so the maximum lands somewhere.
The fixture is the sorted series S12 = (2, 5, 9, 13, 14, 20, 25, 26, 33,
38, 44, 50) with k = 4.

The dry run: w = (50 - 2)\/4 = 12, so the shelves are [2, 14), [14, 26),
[26, 38), and [38, 50]. Walking the series fills B1 with (2, 5, 9, 13),
B2 with (14, 20, 25), B3 with (26, 33), B4 with (38, 44, 50), and the
sample prints `width 12 counts 4 3 2 3`. The boundary probes print
`boundaries: 14->1 26->2 38->3 50->3`, zero-based indexes: 14, 26, and 38
each open the next shelf, and 50, equal to the top edge, lands in the
last one because it closes. The 1-based checks read "ch03 boundary 14
opens bin 2" through "ch03 boundary 50 closes bin 4 (last bin)".

#listing("kdd/samples/src/Ch03/bin.c", first: 28, last: 35,
  caption: [the half-open bin index, last bin closed on the right])

#listing("kdd/samples/src/Ch03/bin.c", first: 76, last: 83,
  caption: [the four boundary probes and their checks])

#diagram([S12 in four equal-width shelves, width 12 over 2 to 50], length: 13pt, {
  let px(v) = { 1.2 + (v - 2.0) * 0.335 }
  let edges = (2, 14, 26, 38, 50)
  for i in range(4) {
    cdraw.rect((px(edges.at(i) * 1.0), 2.0), (px(edges.at(i + 1) * 1.0), 5.6),
      fill: if calc.even(i) {luma(244)} else {luma(234)}, radius: 0.01)
  }
  let vals = (2, 5, 9, 13, 14, 20, 25, 26, 33, 38, 44, 50)
  for v in vals {
    cdraw.circle((px(v * 1.0), 4.0), radius: 0.1, fill: luma(210), stroke: luma(60))
    cdraw.content((px(v * 1.0), 4.5), [#v], size: 6pt)
  }
  let centers = ((2 + 14) / 2, (14 + 26) / 2, (26 + 38) / 2, (38 + 50) / 2)
  let ranges = ([2 <= v < 14], [14 <= v < 26], [26 <= v < 38], [38 <= v <= 50])
  let counts = ([4 values], [3 values], [2 values], [3 values])
  for i in range(4) {
    cdraw.content((px(centers.at(i) * 1.0), 6.1), ranges.at(i), size: 6pt)
    cdraw.content((px(centers.at(i) * 1.0), 2.5), counts.at(i), size: 6pt)
  }
  cdraw.line((1.0, 1.5), (17.6, 1.5), stroke: luma(60), mark: (end: ">"))
  for e in edges {
    cdraw.line((px(e * 1.0), 1.3), (px(e * 1.0), 1.7), stroke: luma(60))
    cdraw.content((px(e * 1.0), 0.85), [#e], size: 6pt)
  }
})

#callout("note", "the last bin closes because the width says so", [
  With half-open bins of width 12 over [2, 50], the value 50 satisfies no
  membership test: it is the excluded left edge of a fifth bin that does
  not exist. The convention closes the last bin on the right, and the
  sample asserts the consequence as "ch03 boundary 50 closes bin 4 (last
  bin)". Every equal-width implementation has to answer this question
  somewhere, and the answer belongs in a check, not in a comment.
])

== equal frequency, same series

Equal-frequency binning, also called equal depth, ignores geometry and
cuts the sorted series into k bins of n\/k values each, so every shelf
holds the same count. On S12 with k = 3 the arithmetic is clean, 12
values into 3 bins of 4.

The dry run: the sorted series simply falls in order, B1 (2, 5, 9, 13),
B2 (14, 20, 25, 26), B3 (33, 38, 44, 50), counts all 4, printed as
`freq counts 4 4 4`. The two rules disagree about where the cuts go:
width puts 26 with 33 in a 2-value bin and leaves 38, 44, 50 together,
depth puts 26 with 14 and 20 and 25. The same disagreement shows on the
classic 9-value series C9 = (4, 8, 15, 21, 21, 24, 25, 28, 34): 3
equal-width bins over [4, 34] have width 10 and counts (2, 3, 4),
printed as `C9 width 10 counts 2 3 4`, with 24 and 34 both landing in
bin 3, while equal depth forces (3, 3, 3), the bins the next section
smooths.

#listing("kdd/samples/src/Ch03/bin.c", first: 85, last: 102,
  caption: [equal frequency by position in the sorted series, k divides n])

#diagram([the same 12 values cut by width into 4 and by depth into 3], length: 13pt, {
  let px(v) = { 1.2 + (v - 2.0) * 0.335 }
  let vals = (2, 5, 9, 13, 14, 20, 25, 26, 33, 38, 44, 50)
  let wband(y, x0, x1, txt) = {
    cdraw.rect((x0, y), (x1, y + 1.3), fill: luma(240), radius: 0.01)
    cdraw.content(((x0 + x1) / 2, y + 0.32), txt, size: 6pt)
  }
  cdraw.content((4.4, 7.5), [equal width, 4 bins, width 12], size: 6pt)
  wband(5.5, px(2.0), px(14.0), [4])
  wband(5.5, px(14.0), px(26.0), [3])
  wband(5.5, px(26.0), px(38.0), [2])
  wband(5.5, px(38.0), px(50.0), [3])
  for v in vals { cdraw.circle((px(v * 1.0), 6.5), radius: 0.09, fill: luma(210), stroke: luma(60)) }
  cdraw.line((1.2, 4.4), (17.3, 4.4), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((9.2, 4.05), [the same dots, reshelfed], size: 6pt)
  cdraw.content((4.4, 3.6), [equal frequency, 3 bins of 4], size: 6pt)
  wband(1.6, px(2.0), px(13.5), [4])
  wband(1.6, px(13.5), px(29.5), [4])
  wband(1.6, px(29.5), px(50.0), [4])
  for v in vals { cdraw.circle((px(v * 1.0), 2.6), radius: 0.09, fill: luma(210), stroke: luma(60)) }
})

== smoothing by means and medians

Smoothing replaces each value in a bin with a statistic of the bin,
trading resolution for stability. The fixture is Zaki and Meira's
equal-depth walkthrough series C9 in 3 bins of 3, (4, 8, 15), (21, 21,
24), (25, 28, 34). Means take the average, medians the middle order
statistic, and because the bins are sorted and hold 3 values, the median
is simply the middle entry.

The dry run: bin sums are 27, 66, 87, so the means are 9, 22, 29, all
exact in binary, printed as `bin means: 9 22 29`, and the smoothed
series reads (9, 9, 9, 22, 22, 22, 29, 29, 29). The medians are the
middle entries 8, 21, 28, printed as `bin medians: 8 21 28`, giving (8,
8, 8, 21, 21, 21, 28, 28, 28). The mean erases the within-bin spread by
construction, the median additionally resists a wild value inside a bin,
the difference between the two is the whole of
#xref-to("kdd", "cleaning") replayed one level down.

#listing("kdd/samples/src/Ch03/smooth.c", first: 52, last: 70,
  caption: [every value of a bin replaced by the bin mean])

#diagram([each value pulled to its bin mean, 9, 22, 29], length: 13pt, {
  let px(v) = { 1.4 + (v - 4.0) * 0.52 }
  let bins = ((4, 8, 15), (21, 21, 24), (25, 28, 34))
  let means = (9, 22, 29)
  let spans = ((1.4, 7.12), (10.24, 11.8), (12.32, 17.0))
  for i in range(3) {
    cdraw.line((spans.at(i).at(0), 2.6), (spans.at(i).at(1), 2.6), stroke: luma(60))
    cdraw.circle((px(means.at(i) * 1.0), 2.6), radius: 0.1, fill: luma(180), stroke: luma(60))
    cdraw.content((px(means.at(i) * 1.0), 2.05), [#means.at(i)], size: 6pt)
    cdraw.content((spans.at(i).at(0) - 0.2, 1.55), [bin #i + 1], size: 6pt)
  }
  for b in bins {
    for v in b {
      let x = px(v * 1.0)
      cdraw.circle((x, 6.5), radius: 0.09, fill: luma(210), stroke: luma(60))
      cdraw.content((x, 6.95), [#v], size: 6pt)
      cdraw.line((x, 6.3), (x, 2.85), stroke: (paint: luma(180), dash: "dashed"),
        mark: (end: ">"))
    }
  }
  cdraw.content((9.2, 7.6), [C9, sorted], size: 6pt)
})

== smoothing by boundaries

Boundary smoothing keeps the bin's own extremes instead of its center:
each value snaps to the nearer of the bin's first and last values, so
the output vocabulary is the input vocabulary. The contract sheet,
kdd-contract-s1s2.md, the wave's fixture ledger, pins the tie rule: an
equal distance to both boundaries takes the lower one, and values
already sitting on a boundary stay put.

The dry run: bin (4, 8, 15). The value 8 sits 4 away from 4 and 7 away
from 15, so it snaps down to 4, giving (4, 4, 15). Bin (21, 21, 24)
already lives on its boundaries, 24 is its own upper bound, so it passes
through unchanged as (21, 21, 24). Bin (25, 28, 34): 28 sits 3 from 25
and 6 from 34, so it snaps down to 25, giving (25, 25, 34). The sample
prints all three lines and the concatenation check pins the full
sequence (4, 4, 15, 21, 21, 24, 25, 25, 34) as
"ch03 boundary-smoothed full sequence".

#listing("kdd/samples/src/Ch03/smooth.c", first: 37, last: 43,
  caption: [nearest boundary, a tie takes the lower one])

#listing("kdd/samples/src/Ch03/smooth.c", first: 107, last: 119,
  caption: [the full 9-value smoothed sequence as one check])

#diagram([each bin's values snap to the nearer of its two boundary posts], length: 13pt, {
  let lane(y, lo, hi, vals, name, result) = {
    let px(v) = { 1.6 + (v - lo) / (hi - lo) * 13.4 }
    cdraw.line((px(lo * 1.0), y - 0.55), (px(lo * 1.0), y + 0.55), stroke: luma(60))
    cdraw.line((px(hi * 1.0), y - 0.55), (px(hi * 1.0), y + 0.55), stroke: luma(60))
    for v in vals {
      let x = px(v * 1.0)
      cdraw.circle((x, y), radius: 0.09, fill: luma(210), stroke: luma(60))
      cdraw.content((x, y - 0.45), [#v], size: 6pt)
      if v != lo and v != hi {
        cdraw.line((x - 0.25, y + 0.28), (px(lo * 1.0) + 0.3, y + 0.28),
          stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
      }
    }
    cdraw.content((0.7, y), name, size: 6pt)
    cdraw.content((16.9, y), result, size: 6pt)
  }
  lane(6.5, 4, 15, (4, 8, 15), [bin 1], [(4,4,15)])
  lane(4.5, 21, 24, (21, 21, 24), [bin 2], [(21,21,24)])
  lane(2.5, 25, 34, (25, 28, 34), [bin 3], [(25,25,34)])
  cdraw.content((8.0, 0.8), [the posts are the bin's own first and last values], size: 6pt)
})

Two smoothers, two vocabularies. Means and medians invent values no
record ever had, which is fine for scale noise and wrong for codes.
Boundaries keep the vocabulary and move the counts, which is why
discretized features downstream in #xref-to("kdd", "features") prefer
them when the values are grades, tiers, or labels.

sources: Mohammed J. Zaki and Wagner Meira Jr., Data Mining and Machine
Learning: Fundamental Concepts and Algorithms, 2nd ed, ch 3 categorical
attributes, the equal-depth binning walkthrough of the same 9-value
series, cs.rpi.edu/~zaki/DMML/slides/pdf/ychap3.pdf, accessed 2026-09-22.
All 30 pinned values witnessed by kdd-contract-s1s2.md and
playground/kdd-matrix/gen_s1.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch03`, 17 + 13 checks in chapter 03 of
the kdd suite.
