// ch05, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 28 checks in kdd/samples/src/Ch05/distance.c or a pinned note of
// kdd-contract-s1s2.md (sqrt exactness on perfect squares, the integer
// cube-root witness, the pythagorean pairs). all pinned values are
// witnessed by the sheet + playground/kdd-matrix/gen_s1.py, run
// 2026-09-22, exit 0. every row of this chapter is D4-eligible: ch47
// replays the fixtures in go.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= distance metrics

One sample carries the chapter: `distance.c` computes the Minkowski
family on one difference vector, exact euclidean distances on
pythagorean pairs, and Mahalanobis distances under a diagonal
covariance, 28 checks in all. The chapter makes 4 moves: the $L_p$
family and its monotone shrink, exact roots and the integer witness
discipline, Mahalanobis as distance with a metric, and the unit balls
that picture the whole family. Every behavioral claim below is one of
the 28 checks of chapter 05's sample or a pinned note of the contract
sheet. Distances feed everything downstream: #xref-to("kdd", "knn")
votes by them, #xref-to("kdd", "kmeans") minimizes them, and
#xref-to("icpc", "y2017") chains them. Every row here is D4-eligible,
the fixtures replay in go in #xref-to("kdd", "bridge").

== the minkowski family

The Minkowski distance of order $p$ between vectors $x$ and $y$ is
$d_p = (sum_i |x_i - y_i|^p)^(1\/p)$, one family containing the
manhattan spelling at $p = 1$ and the euclidean at $p = 2$. The fixture
is $x = (1, 1, 1)$ against $y = (4, 5, 6)$, difference $(3, 4, 5)$,
chosen so every inner sum is a small integer.

The dry run: at $p = 1$ the distance is $3 + 4 + 5 = 12$, printed as
`d1 = 12`. At $p = 2$ the squared distance is $9 + 16 + 25 = 50$,
asserted as an integer, and the root prints `d2 = 7.0710678118654755`,
the print-only row at tolerance 1e-12, exactly $5 sqrt(2)$. At $p = 3$
the cubes sum $27 + 64 + 125 = 216$, and $216 = 6^3$, so $d_3 = 6$
exactly, the sheet's hand note calling (3, 4, 5) the smallest integer
triple whose coordinate cubes sum to a cube. At $p = 4$ the fourth
powers sum $81 + 256 + 625 = 962$ and the root prints
`d4 = 5.5692122278237566`. The four distances strictly decrease,
printed as `monotone: 12 > 7.0710678118654755 > 6 > 5.5692122278237566`
and asserted as "ch05 d1 > d2 > d3 > d4 strict".

#listing("kdd/samples/src/Ch05/distance.c", first: 48, last: 67,
  caption: [p = 1 as a sum, p = 2 as an integer square plus a d2 root])

#listing("kdd/samples/src/Ch05/distance.c", first: 82, last: 94,
  caption: [p = 4 fourth powers and its print-only root])

#diagram([four distances from one difference vector, shrinking in p], length: 13pt, {
  let h(v) = { 0.7 + v * 0.48 }
  let bars = ((2.6, 12.0, [p = 1], [12]), (6.2, 7.0710678, [p = 2], [7.071]), (9.8, 6.0, [p = 3], [6]), (13.4, 5.5692122, [p = 4], [5.569]))
  for b in bars {
    cdraw.rect((b.at(0), 0.7), (b.at(0) + 2.3, h(b.at(1))), fill: luma(238), radius: 0.02)
    cdraw.content((b.at(0) + 1.15, h(b.at(1)) + 0.42), b.at(3), size: 6pt)
    cdraw.content((b.at(0) + 1.15, 0.35), b.at(2), size: 6pt)
  }
  cdraw.content((8.0, 7.4), [the same pair, farther every step down in p], size: 6pt)
})

== exact roots and integer witnesses

Two numerics rules do all the work in this sample, both pinned by the
contract sheet. `sqrt` on a perfect square is IEEE exact, so the
euclidean distances on pythagorean pairs assert with `==`. The $p = 3$
and $p = 4$ roots are not bit-exact through libm `pow` or `cbrt`, so
$p = 3$ asserts through an integer witness instead: a bounded search
for the largest $r$ with $r^3 <= n$, never touching the library.

The dry run: the pair (3, 4) has $3^2 + 4^2 = 25 = 5^2$, and
`sqrt(25.0)` returns 5.0 exactly, checked as "ch05 euclidean(3,4) = 5
exact". The pair (5, 12) has $25 + 144 = 169 = 13^2$, `sqrt(169.0)` is
exactly 13.0, printed on one line as `euclid(3,4) = 5 euclid(5,12) =
13`. The witness on 216 finds $r = 6$ because $6^3 = 216$ and $7^3 =
343 > 216$, printed as `d3^3 = 216, integer cube root = 6` and asserted
three ways: sum 216, root 6 unique, and $6^3 = 216$ as the closing
witness.

#listing("kdd/samples/src/Ch05/distance.c", first: 35, last: 42,
  caption: [integer cube root by bounded search, libm untouched])

#listing("kdd/samples/src/Ch05/distance.c", first: 69, last: 80,
  caption: [the p = 3 row through its integer witness])

#diagram([two pythagorean pairs, both roots exact], length: 13pt, {
  cdraw.line((2.0, 2.0), (3.5, 2.0), stroke: luma(60))
  cdraw.line((3.5, 2.0), (3.5, 4.0), stroke: luma(60))
  cdraw.line((2.0, 2.0), (3.5, 4.0), stroke: luma(60))
  cdraw.content((2.75, 1.6), [3], size: 6pt)
  cdraw.content((3.9, 3.0), [4], size: 6pt)
  cdraw.content((2.2, 3.5), [5], size: 6pt)
  cdraw.content((2.75, 0.8), [sqrt(25.0) = 5 exact], size: 6pt)
  cdraw.line((9.5, 1.4), (10.9, 1.4), stroke: luma(60))
  cdraw.line((10.9, 1.4), (10.9, 4.76), stroke: luma(60))
  cdraw.line((9.5, 1.4), (10.9, 4.76), stroke: luma(60))
  cdraw.content((10.2, 1.0), [5], size: 6pt)
  cdraw.content((11.3, 3.1), [12], size: 6pt)
  cdraw.content((9.5, 3.6), [13], size: 6pt)
  cdraw.content((10.2, 0.3), [sqrt(169.0) = 13 exact], size: 6pt)
})

== mahalanobis, distance with a metric

Plain euclidean distance treats every axis alike, which is wrong when
the axes carry different spread. The Mahalanobis distance divides each
direction by its covariance, $D^2 = (p - mu)^T S^(-1) (p - mu)$, so a
step along a noisy axis costs less than the same step along a quiet
one. The fixture is 5 points on 2 features, $f_1 = (-2, -1, 0, 1, 2)$
and $f_2 = (2, -4, 0, 4, -2)$, with population covariance, divisor $n$
as #xref-to("kdd", "normalize") pinned it.

The dry run: both features have mean 0. The variance of $f_1$ is $(4 +
1 + 0 + 1 + 4)\/5 = 2$, of $f_2$ is $(4 + 16 + 0 + 16 + 4)\/5 = 8$,
and the cross term $-4 + 4 + 0 + 4 - 4 = 0$, printed as `var f1 2 var
f2 8 cross 0`. The covariance is diagonal, so $D^2 = p_1^2\/2 +
p_2^2\/8$. The point (3, 6) then sits at $9\/2 + 36\/8 = 4.5 + 4.5 =
9$, distance 3, printed as `pt(3,6): D^2 9 D 3`. The other four
points land at $D = 0, 1, 2, 2, 3$, every $D^2$ an integer and every
$D$ the exact square root of one.

#listing("kdd/samples/src/Ch05/distance.c", first: 111, last: 126,
  caption: [the 2-feature fixture and its diagonal population covariance])

#listing("kdd/samples/src/Ch05/distance.c", first: 128, last: 145,
  caption: [five points, five squared distances, five exact roots])

#diagram([iso-distance contours, each point pinned to its own contour], length: 13pt, {
  let px(f1) = { 9.0 + f1 * 0.9 }
  let py(f2) = { 3.6 + f2 * 0.35 }
  cdraw.line((5.2, py(0.0)), (13.4, py(0.0)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line((px(0.0), 0.2), (px(0.0), 6.5), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((13.2, py(0.0) + 0.3), [f1], size: 6pt)
  cdraw.content((px(0.0) + 0.35, 6.3), [f2], size: 6pt)
  let contour-labs = (([D = 1], 7.6, 4.6), ([D = 2], 6.6, 5.3), ([D = 3], 5.7, 6.0))
  for lab in contour-labs {
    cdraw.content((lab.at(1), lab.at(2)), lab.at(0), size: 6pt)
  }
  for d in (1, 2, 3) {
    let rx = d * calc.sqrt(2.0) * 0.9
    let ry = d * calc.sqrt(8.0) * 0.35
    let pts = ()
    for a in range(0, 371, step: 10) {
      let c = calc.cos(a)
      let s = calc.sin(a)
      pts.push((px(0.0) + rx * c, py(0.0) + ry * s))
    }
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(160))
    }
  }
  let dots = (((0, 0), [(0,0), D 0], (-0.9, -0.3)), ((1, 2), [(1,2), D 1], (0.3, 0.4)),
    ((2, 4), [(2,4), D 2], (0.35, 0.3)), ((2, -4), [(2,-4), D 2], (0.35, -0.35)), ((3, 6), [(3,6), D 3], (0.05, 0.45)))
  for t in dots {
    let p = t.at(0)
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1) * 1.0)), radius: 0.09,
      fill: luma(150), stroke: luma(60))
    cdraw.content((px(p.at(0) * 1.0) + t.at(2).at(0), py(p.at(1) * 1.0) + t.at(2).at(1)),
      t.at(1), size: 6pt)
  }
})

#callout("note", "the f2 axis is stretched, and that is the point", [
  The contour of $D = 1$ is an ellipse, 2 units tall in $f_1$ and 8
  wide in variance terms, so in the plot the $f_2$ axis reaches
  $sqrt(8)$ while $f_1$ reaches $sqrt(2)$. A point 4 units out on
  $f_2$ and a point 2 units out on $f_1$ are the same distance from
  the center, both $D = 2$, which is exactly what the two planted
  points (2, 4) and (2, -4) assert.
])

== the shrinking ball, and the name

As $p$ grows the distance shrinks toward the largest single coordinate
gap, the monotonicity asserted at the top of the chapter, and the unit
ball $sum_i |x_i|^p = 1$ swells from the $p = 1$ diamond to the $p = 2$
circle toward the axis-aligned square. The balls are the picture to
keep: which ball a miner uses decides which pairs it calls close, the
diamond forgives nothing on any axis, the square forgives everything
but the worst axis.

The dry run: the monotone line prints `monotone: 12 >
7.0710678118654755 > 6 > 5.5692122278237566` over the one difference
vector (3, 4, 5), the same numbers the bars of the first figure drew.

#listing("kdd/samples/src/Ch05/distance.c", first: 96, last: 99,
  caption: [strict monotonicity of the family, one check])

#diagram([unit balls for p = 1, 2, 4, all at distance 1 from the center], length: 13pt, {
  let cx = 6.2
  let cy = 3.4
  let s = 1.55
  cdraw.line((cx - 2.1, cy), (cx + 2.1, cy), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line((cx, cy - 2.1), (cx, cy + 2.1), stroke: (paint: luma(190), dash: "dashed"))
  for p in (1.0, 2.0, 4.0) {
    let pts = ()
    for a in range(0, 371, step: 10) {
      let c = calc.abs(calc.cos(a))
      let si = calc.abs(calc.sin(a))
      let r = calc.pow(calc.pow(c, p) + calc.pow(si, p), -1.0 / p)
      pts.push((cx + r * calc.cos(a) * s, cy + r * calc.sin(a) * s))
    }
    for i in range(pts.len() - 1) {
      cdraw.line(pts.at(i), pts.at(i + 1),
        stroke: if p == 1.0 {luma(60)} else if p == 2.0 {luma(110)} else {luma(160)})
    }
  }
  cdraw.line((11.3, 4.6), (11.9, 4.6), stroke: luma(60))
  cdraw.content((13.3, 4.6), [p = 1], size: 6pt)
  cdraw.line((11.3, 3.9), (11.9, 3.9), stroke: luma(110))
  cdraw.content((13.3, 3.9), [p = 2], size: 6pt)
  cdraw.line((11.3, 3.2), (11.9, 3.2), stroke: luma(160))
  cdraw.content((13.3, 3.2), [p = 4], size: 6pt)
  cdraw.content((6.2, 0.5), [same center, same radius 1, three geometries], size: 6pt)
})

#callout("note", "minkowski distance is not the minkowski sum", [
  This chapter owns the Minkowski distance, the $L_p$ metric
  $root(sum_i |x_i - y_i|^p, p)$ of this sample. The Minkowski sum of
  convex geometry is a different object entirely, the set $A + B = {a
  + b : a in A, b in B}$ built by sliding one shape around the
  boundary of another, and it measures no distance at all. The sum has
  its own chapter in #xref-to("dsa", "geometry2"), and the two share
  only Hermann Minkowski's name.
])

sources: all 28 pinned values and both numerics notes (sqrt exactness
on perfect squares, the integer cube-root witness discipline) witnessed
by kdd-contract-s1s2.md and playground/kdd-matrix/gen_s1.py, run
2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch05`, 28 checks in chapter 05 of the kdd suite.
