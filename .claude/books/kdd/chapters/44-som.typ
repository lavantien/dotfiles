// ch44, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 100 checks in kdd/samples/src/Ch44/som.c (55) and somtrace.c (45) or
// a banked provenance note: SOM per T. Kohonen, Self-Organizing Maps,
// Springer 3rd ed. 2001; the LCG is Park & Miller MINSTD, CACM 31(10)
// 1988. determinism ruling (integrator approved, binding): the
// neighborhood kernel is the truncated quadratic h = max(0, 1 - d^2/rho^2),
// transcendental-free so training is bit-reproducible, FP_CONTRACT OFF,
// one floating operation per statement, no FMA, MINSTD seed 42, D3
// double-run identity with the pinned literals. all pinned values are
// witnessed by kdd-contract-s8s9.md + playground/kdd-matrix/gen_s9.py,
// run 2026-09-22, exit 0, output sha256 f9d6236fcebfb99d407910390a67710
// 4f7b5c6014573ffc6db30b562b546d102. rho2 and eta schedules are dyadic,
// D1 asserted ==.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= self-organizing maps

Two samples carry the chapter: `som.c` builds the seeded initialization,
the schedule table and the neighborhood kernel, 55 checks, and
`somtrace.c` runs the five online epochs and pins every BMU sequence and
weight grid, 45 checks. The chapter makes 4 moves: the lattice and its
seeded random start, the truncated-quadratic kernel and its shrinking
schedules, the epoch loop that moves a whole neighborhood toward each
input, and the arithmetic discipline that makes all of it
bit-reproducible. #xref-to("kdd", "kmeans") quantized with free-floating
centroids, this chapter chains them to a 2x3 grid so nearby units answer
nearby inputs, and the squared euclidean that picks the winner is the
distance of #xref-to("kdd", "distance"). The network learns without
labels, the missing-labels contrast with #xref-to("kdd", "ann"), and the
map it leaves behind is what #xref-to("kdd", "somanalysis") grades and
#xref-to("kdd", "somvariants") grows.

== a 2x3 lattice, a ring, and one seed

The fixture is small on purpose: 6 units on a 2-row by 3-column grid,
unit index $u = 3 r + c$, and 8 integer inputs forming a ring, x1 = (4,0)
through x8 = (2,0) around the perimeter of the square 0..8. Every weight
starts pseudorandom: a MINSTD generator, $s' = 16807 s mod (2^31 - 1)$,
seeded at 42, drawn 12 times in unit-major order, each state divided by
$2^28$ into (0, 8).

The dry run: the sample prints `lcg seed=42 states=705894,1126542223,...`
one line of 12 states ending `...,229968128,1751246343`, each state its
own check, the first two verifiable by hand, $42 times 16807 = 705894$,
then $705894 dot 16807 mod (2^31 - 1) = 1126542223$ with the
intermediates held in uint64 so no 32-bit overflow strikes. Then the init
row, `init u0=(0.0026296600699424744,4.1966968141496181);
u1=(5.8833882547914982,2.1064443252980709);` on through
`u5=(0.85669803619384766,6.5239010117948055)`, all 12 coordinates
asserted with `==`, u2 for instance
being states 3 and 4 over $2^28$. The grid geometry is a check too: the
2x3 lattice
realizes exactly the squared grid distances {0, 1, 2, 4, 5}, no 3, which
is the kernel table's domain, asserted as "ch44 2x3 lattice d2 set is
exactly {0,1,2,4,5}".

#listing("kdd/samples/src/Ch44/som.c", first: 74, last: 81,
  caption: [twelve seeded draws in unit-major order, each over 2^28])

#listing("kdd/samples/src/Ch44/som.c", first: 90, last: 134,
  caption: [the pinned LCG states and init grid, every double asserted ==])

#diagram([the ring of inputs and the random start the lattice has to organize], length: 13pt, {
  let px(v) = { 2.2 + v * 1.62 }
  let py(v) = { 8.4 - v * 0.82 }
  let ins = (([x1], 4, 0, 0.0, 0.62), ([x2], 7, 2, 0.55, 0.0), ([x3], 8, 5, 0.55, 0.0),
    ([x4], 6, 8, 0.0, 0.62), ([x5], 3, 8, -0.7, 0.5), ([x6], 0, 6, -0.75, 0.0),
    ([x7], 0, 2, -0.75, 0.0), ([x8], 2, 0, -0.1, 0.62))
  for p in ins {
    cdraw.circle((px(p.at(1) * 1.0), py(p.at(2) * 1.0)), radius: 0.13,
      fill: luma(150), stroke: luma(60))
    cdraw.content((px(p.at(1) * 1.0) + p.at(3), py(p.at(2) * 1.0) + p.at(4) * -1.0),
      p.at(0), size: 6pt)
  }
  let units = (([u0], 0.0026296600699424744, 4.196696814149618),
    ([u1], 5.883388254791498, 2.106444325298071),
    ([u2], 3.0097917690873146, 1.5702866055071354),
    ([u3], 7.806991044431925, 4.098544865846634),
    ([u4], 4.243592359125614, 2.056813035160303),
    ([u5], 0.8566980361938477, 6.5239010117948055))
  for u in units {
    cdraw.rect((px(u.at(1)) - 0.3, py(u.at(2)) - 0.28), (px(u.at(1)) + 0.3, py(u.at(2)) + 0.28),
      fill: luma(244), radius: 0.02, stroke: luma(120))
    cdraw.content((px(u.at(1)), py(u.at(2)) + 0.75), u.at(0), size: 6pt)
  }
  cdraw.content((11.0, 0.4), [filled dots: the input ring, boxes: seeded init units], size: 6pt)
  cdraw.content((11.0, 8.4), [grid topology 2x3, u = 3r + c], size: 6pt)
})

== the kernel, truncated so it stays honest

Each adaptation step moves every unit toward the current input, weighted
by a neighborhood kernel of the unit's grid distance to the winner. The
true SOM kernel is Gaussian, $h = exp(-d^2 \/ (2 sigma^2))$ in the books,
and this fixture deliberately does not use it. The pinned kernel is the
truncated quadratic $h(d^2) = max(0, 1 - d^2\/rho^2)$, a compact-support
stand-in with the same bell intent: 1 at the winner, falling with
distance, 0 beyond the radius. Its whole arithmetic is one division and
one subtraction, which is the point, no transcendental is evaluated
anywhere in the SOM family, so no libm rounding differences can creep
between implementations.

The dry run: five schedule rows and five kernel rows, `sched e1 rho2=4
eta=0.5` with `h e1: d2=0:1 d2=1:0.75 d2=2:0.5 d2=4:0 d2=5:0`,
then rho2 = 2.25, 1.0, 0.5625, 0.25 against eta = 0.375, 0.25, 0.1875,
0.125, every schedule value and every kernel value its own `==` check.
The rho2 column is $rho^2$ for rho = 2, 1.5, 1, 0.75, 0.5 and the eta
column halves from 1/2, all dyadic, all exact. The epoch-2 row carries
the family's pet constant: `d2=1:0.55555555555555558`, that is
$1 - 1\/2.25$, and `d2=2:0.11111111111111116`, which is not the double
nearest to 1/9, it is $1 - (2\/2.25)$ with one rounding at the division
and one at the subtraction. By epoch 3, rho2 = 1 kills every nonzero-d2
weight, the kernel becomes the bubble, only the winner itself adapts,
and epochs 3 through 5 share the all-or-nothing row `d2=0:1
d2=1:0 d2=2:0 d2=4:0 d2=5:0`.

#listing("kdd/samples/src/Ch44/som.c", first: 41, last: 54,
  caption: [the kernel: division, subtraction, clamp, each its own statement])

#listing("kdd/samples/src/Ch44/som.c", first: 145, last: 163,
  caption: [five schedules, five kernel rows, every value asserted ==])

#diagram([the kernel over grid distance, five shrinking epochs, bubble by epoch 3], length: 13pt, {
  let px(d) = { 2.6 + d * 2.3 }
  let py(h) = { 1.2 + h * 5.6 }
  cdraw.line((2.2, 1.2), (16.2, 1.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((16.8, 1.2), [d2], size: 6pt)
  for d in (0, 1, 2, 4, 5) {
    cdraw.line((px(d * 1.0), 1.0), (px(d * 1.0), 1.4), stroke: luma(100))
    cdraw.content((px(d * 1.0), 0.45), [#d], size: 6pt)
  }
  cdraw.line((2.2, py(1.0)), (2.2, 1.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.7, py(1.0) + 0.35), [h], size: 6pt)
  let segs = ((4.0, luma(60), 6.9), (2.25, luma(90), 5.6), (1.0, luma(120), 4.3))
  for s in segs {
    let r2 = s.at(0)
    cdraw.line((px(0.0), py(1.0)), (px(r2), py(0.0)), stroke: s.at(1))
    cdraw.line((px(r2), py(0.0)), (px(5.0), py(0.0)), stroke: (paint: s.at(1)))
    cdraw.content((px(r2), py(1.0)), [rho2 = #s.at(0)], size: 6pt)
  }
  for d in (1, 2) {
    cdraw.line((px(d * 1.0), 1.25), (px(d * 1.0), py(0.75)), stroke: (paint: luma(150), dash: "dashed"))
  }
  cdraw.circle((px(1.0), py(0.55555555555555558)), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(1.0) + 0.3, py(0.55555555555555558) + 0.28), [0.55555555555555558], size: 6pt)
  cdraw.content((px(2.0) + 0.1, py(0.11111111111111116) + 0.42), [0.11111111111111116], size: 6pt)
  cdraw.content((9.5, 8.5), [epochs 3-5: rho2 <= 1, only the winner adapts], size: 6pt)
})

== five epochs, one dead unit

Training is online with immediate updates: sweep x1 through x8, for each
input find the best-matching unit, the BMU, by plain squared euclidean
over both dimensions with strict `<` so ties keep the lowest index, then
move every unit by $w_u <- w_u + eta dot h(d^2(u, "bmu")) dot (x -
w_u)$. Five epochs, one schedule row each. The grid organizes fast, and
one unit never makes it.

The dry run: epoch 1 prints `epoch 1 bmu=2,1,3,3,0,5,2,2` and the full
after-epoch grid starting `after epoch 1
u0=(4.0755163159265066,6.7447139665709983);...`, epoch 2
`bmu=2,1,3,3,0,0,5,2`, and epochs 3
through 5 the settled `bmu=2,4,4,3,0,0,5,2`, all 40 BMU digits and all
60 grid coordinates asserted with `==` against the pinned literals, the
HARD two-way core of the chapter. The final row opens `final
u0=(1.7736785518636009,6.7858215993753985)` and runs on through
`u5=(0.78802150923085545,1.7396510860930761)`, with u1 frozen at
`u1=(2.9240485376881993,3.1672306950233438)`. Unit u1 is the story: it
wins x2
in epochs 1 and 2, loses it to u4 from epoch 3 on, and once the kernel
is a bubble only winners move, so u1's row is frozen at its epoch-2
value forever, printed as `dead unit u1 frozen from epoch 2: true` and
asserted twice, "ch44 u1 dead unit frozen from epoch 2" and "ch44 u1
never a BMU in epochs 3-5". A dead unit is a real SOM failure mode, not
a fixture decoration, and #xref-to("kdd", "somvariants") exists partly
to fix it by growing the grid where the error is.

#listing("kdd/samples/src/Ch44/somtrace.c", first: 54, last: 69,
  caption: [BMU: squared euclidean, one op per statement, strict < keeps the lowest index])

#listing("kdd/samples/src/Ch44/somtrace.c", first: 147, last: 190,
  caption: [the epoch loop: sweep inputs, adapt the whole neighborhood, pin everything])

#diagram([BMU per input per epoch: u1 wins x2 twice, then dies], length: 13pt, {
  let seqs = (([e1], (2, 1, 3, 3, 0, 5, 2, 2)), ([e2], (2, 1, 3, 3, 0, 0, 5, 2)),
    ([e3], (2, 4, 4, 3, 0, 0, 5, 2)), ([e4], (2, 4, 4, 3, 0, 0, 5, 2)),
    ([e5], (2, 4, 4, 3, 0, 0, 5, 2)))
  cdraw.content((9.4, 8.5), [BMU of x1..x8 per epoch], size: 6pt)
  for i in range(8) {
    cdraw.content((4.4 + i * 1.72, 7.9), [x#(i + 1)], size: 6pt)
  }
  let ys = (6.9, 5.6, 4.3, 3.0, 1.7)
  for r in range(5) {
    cdraw.content((2.2, ys.at(r)), seqs.at(r).at(0), size: 6.5pt)
    let row = seqs.at(r).at(1)
    for i in range(8) {
      let v = row.at(i)
      let dead = r >= 2 and v == 1
      let was = r < 2 and i == 1
      cdraw.rect((3.7 + i * 1.72, ys.at(r) - 0.45), (5.3 + i * 1.72, ys.at(r) + 0.45),
        fill: if was {luma(214)} else if dead {luma(200)} else {luma(246)},
        radius: 0.02, stroke: luma(150))
      cdraw.content((4.5 + i * 1.72, ys.at(r)), [#v], size: 6.5pt)
    }
  }
  cdraw.content((9.4, 0.7), [u1 wins x2 in e1, e2, nothing after: frozen at its e2 weights], size: 6pt)
})

#callout("pitfall", "a map that cannot be rerun is a map you cannot trust", [
  Every grid coordinate in this chapter is pinned to 17 digits and the
  samples assert `==`, not closeness. That only works because the whole
  computation is transcendental-free with one floating operation per
  statement: each step is a single correctly-rounded IEEE operation, so
  any conforming implementation in any language that mirrors the op order
  produces bit-identical doubles. Swap in the Gaussian kernel and you
  inherit every libm's private exp, and the last ulp becomes
  platform-dependent, which is why the truncated quadratic was pinned by
  ruling. The discipline is the chapter's method, not its trivia, and
  #xref-to("kdd", "somvariants") leans on it to bit-compare batch, gas
  and online variants against each other.
])

== the update, one operation at a time

The ruling deserves its own reading, because the sample's C is shaped by
it. The files open with `#pragma STDC FP_CONTRACT OFF` and are never
built with contraction or fast-math, and each arithmetic step is its own
statement in a fixed order: the kernel computes `t = d2 / rho2`, then
`t = 1.0 - t`, then clamps, and the weight update computes `a = x - w`,
`p1 = h * a`, `p2 = eta * p1`, then `w = w + p2`. No expression writes
`w + eta * h * (x - w)` in one line, because a compiler would be allowed
to fuse the multiply-add and change the result in the last ulp.

The dry run: `somtrace.c` isolates the very first update of training,
x1's arrival at its BMU u2, applies the epoch-1 kernel and eta to u2
alone, and prints `first update
u2=(3.5048958845436573,0.7851433027535677)`, asserted against both
literals. The value is the midpoint of the
seeded weight and the input, h = 1 and eta = 1/2 make the step exactly
half the gap, and it is a cross-witness besides: chapter 46's neural gas
applies h = 1, eta = 0.5 to the same unit through an independent code
path and must land on the same 17 digits, asserted there as
"ch46 gas rank-0 x1
u2=(3.5048958845436573,0.7851433027535677) == ch44 online first update".
One pinned arithmetic identity gluing two chapters, free of charge.

#listing("kdd/samples/src/Ch44/somtrace.c", first: 128, last: 145,
  caption: [the isolated first update, pinned and cross-witnessed by ch46's gas])

#diagram([two statement chains, each box one correctly-rounded operation], length: 13pt, {
  let chain(y, title, steps) = {
    cdraw.content((3.4, y + 1.15), title, size: 6.5pt)
    let x = 1.2
    for s in steps {
      cdraw.rect((x, y - 0.4), (x + 2.7, y + 0.5), fill: luma(246), radius: 0.02,
        stroke: luma(150))
      cdraw.content((x + 1.35, y + 0.05), s, size: 6pt)
      if x < 12.5 {
        cdraw.line((x + 2.8, y + 0.05), (x + 3.4, y + 0.05), stroke: luma(60), mark: (end: ">"))
      }
      x += 3.5
    }
  }
  chain(6.6, [kernel], ([t = d2 \/ rho2], [t = 1.0 - t], [h = t > 0 ? t : 0]))
  chain(3.6, [update], ([a = x - w], [p1 = h \* a], [p2 = eta \* p1], [w = w + p2]))
  cdraw.content((9.2, 8.4), [FP_CONTRACT OFF, no fma, no exp, one op per statement], size: 6pt)
  cdraw.rect((0.9, 1.1), (17.3, 2.4), fill: luma(240), radius: 0.02)
  cdraw.content((9.1, 1.95), [1.0 - 2.0\/2.25 = 0.11111111111111116, two roundings, not the nearest 1\/9], size: 6pt)
  cdraw.content((9.1, 1.45), [first update = midpoint: h = 1, eta = 1\/2, w2 = (w + x)\/2], size: 6pt)
})

sources: the self-organizing map, the batch variant of chapter 46 and the
supervised LVQ of chapter 46 are T. Kohonen, Self-Organizing Maps,
Springer Series in Information Sciences 30, 3rd ed. 2001, with the
truncated-quadratic kernel, the MINSTD seed 42, the schedule values and
every pinned grid witnessed by kdd-contract-s8s9.md and
playground/kdd-matrix/gen_s9.py, run 2026-09-22, exit 0. The generator
is W. H. Press and S. A. Teukolsky's portable MINSTD of Park & Miller,
Communications of the ACM 31(10) 1988, 1192-1201, the same family as the
chapter 07 pin. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch44`,
55 + 45 checks in chapter 44 of the kdd suite.
