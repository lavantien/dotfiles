// ch46, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 207 checks in kdd/samples/src/Ch46/batch.c (72), grow.c (50), gas.c
// (63) and lvq.c (22) or a banked provenance note: batch SOM and
// supervised LVQ1 per T. Kohonen, Self-Organizing Maps, Springer 3rd ed.
// 2001 (ch 3 batch, supervised LVQ chapter); growing grid per B. Fritzke,
// Growing Grid - a self-organizing network with constant neighborhood
// range and adaptation strength, Neural Processing Letters 2(5) 1995
// 9-13; neural gas per T. Martinetz, S. Berkovich, K. Schulten,
// Neural-Gas Network for Vector Quantization and its Application to
// Time-Series Prediction, IEEE Trans. Neural Networks 4(4) 1993 558-569.
// CONTRACT FLAGS (matrix-b3, binding): the sheet's gas block carries
// three transcription typos and its differ_at annotation says 5,6,7
// where its own pinned sequences differ at {5,7}; the generator won and
// this chapter quotes the generator/C values only: after-x3 u5 dim0
// 1.219751508142508, after-x4 u3 dim1 6.095447339699604, after-x7 u1
// dim1 3.62934196692182, differ set {5,7}. all values witnessed by
// kdd-contract-s8s9.md + playground/kdd-matrix/gen_s9.py, run 2026-09-22,
// exit 0. D3 doubles one-op-per-statement FP_CONTRACT off, D0 fractions,
// D1 dyadic LVQ weights asserted ==.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= som variants

Four samples carry the chapter: `batch.c` reruns the ring training
without a learning rate, 72 checks, `grow.c` inserts a column where the
map hurts, 50, `gas.c` replaces the lattice with ranks, 63, and `lvq.c`
supervises two prototypes, 22. The chapter makes 4 moves: the batch
reformulation whose weights are kernel-weighted averages, the growing
grid that repairs a dead or torn map by adding units, neural gas with
its topology-free rank kernel, and LVQ1, the supervised sibling that
pushes prototypes toward their own class and away from the other. All
four reuse #xref-to("kdd", "som")'s seed, inputs and grid so the
variants diverge for visible reasons, and all are graded by the QE ruler
of #xref-to("kdd", "somanalysis"). The supervised half is the
nearest-prototype decision rule of #xref-to("kdd", "knn") with learned
reference points.

== batch: no learning rate, frozen winners

Batch SOM keeps the seed, the grid, the inputs and the rho2 schedule and
deletes eta entirely. Each epoch computes every BMU against the frozen
epoch-start weights, then sets each unit to the kernel-weighted average
of all inputs, $w_u = sum_i h(d^2(u, b_i)) x_i \/ sum_i h(d^2(u, b_i))$.
A unit nobody's neighborhood reaches has denominator 0 and keeps its
weights, the rule, and it fires exactly once in this run.

The dry run: the batch epoch-1 BMU sequence prints `batch epoch1
bmu=2,1,3,3,5,5,0,2`, and the per-unit rows show the averaging, `batch
epoch1 u5 den=4 num=(11,15) -> (2.75,3.75)` among them, hand-derived as
$0.75 + 0.5 + 0 + 0 + 1 + 1 + 0 + 0.75 = 4$ over the winners
u2,u1,u3,u3,u5,u5,u0,u2 with numerator $(11, 15)$. The rule fires at
epoch 3, `batch epoch3 u1 den=0 keeps weights`, the dead unit of
#xref-to("kdd", "som") now provably unreachable rather than merely
unpicked. And the map goes exact: `batch after epoch 3
u0=(7.5,3.5);u1=(3.9166666666666665,2.9583333333333335);
u2=(3,0);u3=(6,8);u4=(3,8);u5=(0,4)`, because in the
bubble epochs the kernel is 1 only at the winner, so every reached unit
is the plain centroid of its inputs, u2 the mean of x1 and x8, u5 the
mean of x6 and x7, and epochs 4 and 5 reprint the same grid, pinned.
The contrast row is the chapter's flagged correction: `batch epoch1
bmu=2,1,3,3,5,5,0,2` against online's `2,1,3,3,0,5,2,2`, and the sample
prints `differ at input 5 (batch 5 vs online 0)` and `differ at input 7
(batch 0 vs online 2)` and nothing else, asserted as "ch46 batch vs
online differ_at=5,7 (sheet's 5,6,7 annotation contradicts its own
sequences)". The sheet's annotation was wrong, inputs 6 and 8 agree, and
the computed set is law. The census closes with `delta_max=u0 dim0
5.7263214481363995` and `QE_batch=1.1452847075210475`, the best QE in
the family.

#listing("kdd/samples/src/Ch46/batch.c", first: 158, last: 222,
  caption: [frozen-start BMUs, kernel-weighted sums, den=0 keeps weights])

#listing("kdd/samples/src/Ch46/batch.c", first: 250, last: 269,
  caption: [the batch-vs-online contrast, differ set computed from both sequences])

#diagram([the two epoch-1 sequences, winners differ exactly where online has already moved], length: 13pt, {
  let row(y, tag, vals) = {
    cdraw.content((1.6, y), tag, size: 6.5pt)
    for i in range(8) {
      let hot = i == 4 or i == 6
      cdraw.rect((3.4 + i * 1.75, y - 0.45), (5.1 + i * 1.75, y + 0.45),
        fill: if hot {luma(214)} else {luma(246)},
        radius: 0.02, stroke: luma(150))
      cdraw.content((4.25 + i * 1.75, y), [#vals.at(i)], size: 6.5pt)
    }
  }
  cdraw.content((4.25 + 3.5, 7.95), [x1, x2, x3, x4, x5, x6, x7, x8 winners], size: 6pt)
  row(6.8, [batch], (2, 1, 3, 3, 5, 5, 0, 2))
  row(4.9, [online], (2, 1, 3, 3, 0, 5, 2, 2))
  cdraw.content((10.6, 3.6), [differ at inputs 5 and 7 only], size: 6pt)
  cdraw.content((10.6, 2.9), [online has already adapted when x5 arrives], size: 6pt)
  cdraw.content((10.6, 2.2), [batch reads all winners off the frozen start], size: 6pt)
  cdraw.content((10.6, 1.2), [input 6: 5 vs 5, input 8: 2 vs 2, the sheet said 5,6,7], size: 6pt)
})

== growing grid: add units where it hurts

A fixed grid either wastes units or starves regions. Fritzke's growing
grid accumulates each unit's quantization error, finds the worst unit,
and inserts a new row or column between it and its most dissimilar grid
neighbor. The sample runs one insertion on the chapter 44 map: per-unit
errors `gerr u0=6.7415446740885399 n=2` through `gerr
u4=7.5961914342770864 n=2`, with `gerr u1=0 n=0`, the dead unit
contributing nothing, then `grow worst=u4 neighbors=1,3,5
dissimilar=u5 dist2=35.333217300545932 horiz=true`, the same torn edge
the u-matrix of #xref-to("kdd", "somanalysis") painted dark.

The dry run: the insertion goes between u4 and u5, same row, so a column
slots between columns 1 and 2 and the grid becomes 2x4, each new unit
the per-row midpoint of its flanking units, op order $t = a + b$, $w =
0.5 t$, pinned as `grown grid 2x4` with new units u2 and u6 at
`u2=(2.8521999042434572,1.6936644628811091)` and
`u6=(3.5869879047549702,2.7391967037930525)`. The census then delivers the
punched line: `grown bmu u0={5,6}`, `grown bmu u3={1,8}`, `grown bmu
u4={4}`, `grown bmu u5={2,3}`, `grown bmu u7={7}`, with u1, u2 and u6
winning nothing, and `QE_grown_after_insertion=1.4362362499549604`,
identical to before, asserted, because new units placed on segment
midpoints win nothing yet. Three relief epochs of bubble training, eta
1/8, rho2 1/4, then pull the winners inward, each epoch's full 2x4 grid
pinned, ending at `QE_grown_relief=1.2762259134584661`. Growth bought a
real error reduction, 1.436 to 1.276, at the cost of one column and
three cheap epochs.

#listing("kdd/samples/src/Ch46/grow.c", first: 183, last: 226,
  caption: [worst unit by error, most dissimilar von Neumann neighbor, distance pinned])

#listing("kdd/samples/src/Ch46/grow.c", first: 228, last: 260,
  caption: [column insertion, new units as per-row midpoints, t = a + b then 0.5 t])

#diagram([2x3 to 2x4: the new column between the worst unit and its farthest neighbor], length: 13pt, {
  let g23 = ((2.9, 6.9), (5.7, 6.9), (8.5, 6.9), (2.9, 3.3), (5.7, 3.3), (8.5, 3.3))
  let lbl = ([u0], [u1], [u2], [u3], [u4], [u5])
  let err = ([6.74], [0.0], [2.19], [1.11], [7.60], [0.69])
  for i in range(6) {
    let hot = i == 4
    cdraw.circle(g23.at(i), radius: 0.42,
      fill: if hot {luma(214)} else {luma(246)},
      stroke: if hot {luma(60)} else {luma(140)})
    cdraw.content(g23.at(i), lbl.at(i), size: 6.5pt)
    cdraw.content((g23.at(i).at(0), g23.at(i).at(1) + 0.85), err.at(i), size: 6pt)
  }
  cdraw.line((5.7, 3.3), (8.5, 3.3), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.content((7.1, 2.5), [dist2 = 35.33, the tear], size: 6pt)
  cdraw.content((5.7, 8.35), [before: per-unit error e_u], size: 6pt)
  cdraw.line((9.9, 5.1), (11.3, 5.1), stroke: luma(60), mark: (end: ">"))
  let gx = (12.4, 13.9, 15.4, 17.0)
  let rnames = ([u0], [u1], [new], [u2])
  let rnames2 = ([u3], [u4], [new], [u5])
  for i in range(4) {
    let hot = i == 2
    cdraw.circle((gx.at(i), 6.9), radius: 0.4,
      fill: if hot {luma(226)} else {luma(246)}, stroke: if hot {luma(60)} else {luma(140)})
    cdraw.content((gx.at(i), 6.9), rnames.at(i), size: 6pt)
    cdraw.circle((gx.at(i), 3.3), radius: 0.4,
      fill: if hot {luma(226)} else {luma(246)}, stroke: if hot {luma(60)} else {luma(140)})
    cdraw.content((gx.at(i), 3.3), rnames2.at(i), size: 6pt)
  }
  cdraw.line((15.4, 3.3), (17.0, 3.3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((14.8, 8.35), [after: 2x4, midpoints win nothing yet], size: 6pt)
  cdraw.content((14.8, 1.9), [3 relief epochs: QE 1.436 -> 1.276], size: 6pt)
})

== neural gas: rank instead of lattice

Neural gas drops the grid entirely. For each input, all units are ranked
by distance, and the update strength is a function of rank alone,
$h = 2^(-"rank")$ here, every unit moves toward the input, the closest
most, the farthest barely. Topology is neither preserved nor claimed,
which is the point: with no lattice to respect, gas spreads units freely
through the data, and the cost shows up as a topology error if you ever
ask for one.

The dry run: for x1 the rank order prints `gas rank=2,4,1,3,0,5`, the
hand distance table off the seeded init reading u2 3.446, u4 4.290, u1
7.984, u3 31.29, u0 33.59, u5 52.44, and the kernel rows print
`gas h_rank0=u2 h=1` down to `gas h_rank5=u5 h=0.03125`, each half the
one before, all dyadic. One epoch over x1..x8 at constant eta = 0.5
follows, all eight after-input grids pinned, for example `gas after x3`
carrying `u5=(1.2197515081425081,6.310594608995217)` and `gas after x4`
carrying `u3=(6.8566976445290493,6.0954473396996036)`. Three of those 48
step-grid pairs were transcribed wrong in the contract sheet and
corrected by the generator rerun, the binding flag recorded in the
sample header: the pinned literals read u5 x = 1.219751508142508 after
x3, u3 y = 6.095447339699604 after x4 and u1 y = 3.62934196692182 after
x7, and every quote here carries the generator values. The rank-0
update of x1 lands u2 on `(3.5048958845436573,0.7851433027535677)`,
bit-identical to chapter 44's online first update, same h = 1, same eta,
independent code path, asserted as the free cross-witness. The epoch
ends at `QE_gas_epoch=1.772083269243151`, the worst QE in the family:
one epoch of gas from a cold start against five epochs of scheduled SOM.

#listing("kdd/samples/src/Ch46/gas.c", first: 154, last: 199,
  caption: [rank every unit, halve the strength per rank, one epoch, cross-witness the first step])

#diagram([x1's six units on the distance ladder, strength halving with rank], length: 13pt, {
  let rows = (([u2], [3.446], [1.0], 1.0, 7.0), ([u4], [4.290], [0.5], 0.5, 5.8),
    ([u1], [7.984], [0.25], 0.25, 4.6), ([u3], [31.29], [0.125], 0.125, 3.4),
    ([u0], [33.59], [0.0625], 0.0625, 2.2), ([u5], [52.44], [0.03125], 0.03125, 1.0))
  cdraw.content((8.7, 8.4), [x1 = (4,0) against the seeded init], size: 6pt)
  cdraw.content((2.3, 7.85), [unit], size: 6pt)
  cdraw.content((5.0, 7.85), [d2], size: 6pt)
  cdraw.content((8.0, 7.85), [h = 2^-rank], size: 6pt)
  cdraw.content((13.6, 7.85), [pull toward x1], size: 6pt)
  for i in range(6) {
    let r = rows.at(i)
    let y = r.at(4)
    cdraw.rect((1.4, y - 0.45), (4.0, y + 0.45), fill: luma(246), radius: 0.02, stroke: luma(150))
    cdraw.content((2.7, y), r.at(0), size: 6.5pt)
    cdraw.content((5.3, y), r.at(1), size: 6.5pt)
    cdraw.content((8.3, y), r.at(2), size: 6.5pt)
    let w = r.at(3) * 7.2
    cdraw.rect((10.2, y - 0.28), (10.2 + w, y + 0.28), fill: luma(180), radius: 0.02)
  }
  cdraw.content((8.7, 0.4), [no lattice, no topology claim, just rank], size: 6pt)
})

== LVQ1: prototypes with a teacher

Everything so far was unsupervised. LVQ1 takes labeled data and a small
set of prototypes, one per class planted at a labeled example, and for
each input moves the nearest prototype: toward the input if their labels
agree, away if they disagree. The fixture plants A at x1 = (4,0) and B
at x5 = (3,8), no LCG anywhere, eta = 1/4, one epoch over the ring with
labels A = {x1..x4}, B = {x5..x8}.

The dry run: the trace rows print `lvq x1 lab=A near=A reward` through
`lvq x8 lab=B near=A punish`, with exactly three punishments, x4 labeled
A but nearer B, x7 and x8 labeled B but nearer A, each row a check. The
final prototypes print `lvq final A=(8.19140625,1.9140625)
B=(1.828125,7.5)`, both asserted `==`, and both exactly representable:
integer inputs and eta = 1/4 stack quarters, so every intermediate weight
is dyadic, the D1 spine of the sample. Follow B by hand: it never
rewards after x4 pushes it away, x5 and x6 pull it to (1.828125, 7.5),
and it stays. The classification pass then scores 6 of 8, `lvq
accuracy=6/8`, asserted as the reduced 3/4, with exactly the two
boundary inputs x4 and x8 wrong, the same patients any 1-NN on these
prototypes would miss. The closing compare row pins the whole family on
one line, `compare QE_online=1.4362362499549604
QE_batch=1.1452847075210475 QE_grown_relief=1.2762259134584661
QE_gas_epoch=1.772083269243151 LVQ_acc=6/8`, with the ordering batch
below grown below online below gas asserted as its own check. Batch wins
quantization on this fixture, growth buys most of batch's win while
keeping an explicit topology, and the supervised variant trades the QE
game for a decision rule with a measured accuracy.

#listing("kdd/samples/src/Ch46/lvq.c", first: 58, last: 82,
  caption: [nearest prototype, tie to A, reward toward, punish away, quarters all the way])

#listing("kdd/samples/src/Ch46/lvq.c", first: 104, last: 113,
  caption: [the family compare row and the asserted QE ordering])

#diagram([two prototypes drift apart: rewards pull, punishments push], length: 13pt, {
  let px(v) = { 1.6 + v * 1.55 }
  let py(v) = { 7.8 - v * 0.72 }
  let ins = (([x1], 4, 0, true, 0.45, 0.25), ([x2], 7, 2, true, 0.5, -0.45),
    ([x3], 8, 5, true, 0.5, 0.25), ([x4], 6, 8, true, 0.45, -0.5),
    ([x5], 3, 8, false, -0.5, 0.3), ([x6], 0, 6, false, -0.6, 0.0),
    ([x7], 0, 2, false, -0.6, 0.0), ([x8], 2, 0, false, -0.15, -0.5))
  for p in ins {
    cdraw.circle((px(p.at(1) * 1.0), py(p.at(2) * 1.0)), radius: 0.12,
      fill: if p.at(3) {luma(214)} else {luma(170)}, stroke: luma(90))
    cdraw.content((px(p.at(1) * 1.0) + p.at(4), py(p.at(2) * 1.0) + p.at(5)), p.at(0), size: 6pt)
  }
  cdraw.circle((px(4.0), py(0.0)), radius: 0.2, fill: none, stroke: luma(60))
  cdraw.circle((px(3.0), py(8.0)), radius: 0.2, fill: none, stroke: luma(60))
  cdraw.line((px(4.0), py(0.0)), (px(8.19140625), py(1.9140625)), stroke: luma(60), mark: (end: ">"))
  cdraw.line((px(3.0), py(8.0)), (px(1.828125), py(7.5)), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((px(8.19140625), py(1.9140625)), radius: 0.25, fill: luma(244), stroke: luma(60))
  cdraw.content((px(8.19140625) + 0.5, py(1.9140625) + 0.3), [A], size: 7pt)
  cdraw.circle((px(1.828125), py(7.5)), radius: 0.25, fill: luma(244), stroke: luma(60))
  cdraw.content((px(1.828125) - 0.55, py(7.5) + 0.4), [B], size: 7pt)
  cdraw.content((8.4, 8.5), [hollow: planted at x1, x5, filled: final], size: 6pt)
  cdraw.content((8.4, 0.5), [x4 punished B away, x7 x8 punished A, accuracy 6\/8], size: 6pt)
})

sources: batch SOM and LVQ1 are from T. Kohonen, Self-Organizing Maps,
Springer Series in Information Sciences 30, 3rd ed. 2001, chapter 3 for
the batch form and the supervised LVQ chapter for LVQ1. Growing grid is
B. Fritzke, Neural Processing Letters 2(5) 1995, 9-13. Neural gas is T.
Martinetz, S. Berkovich, K. Schulten, IEEE Transactions on Neural
Networks 4(4) 1993, 558-569. Every pinned double, the corrected gas
literals and the computed differ set {5,7} are witnessed by
kdd-contract-s8s9.md and playground/kdd-matrix/gen_s9.py, run 2026-09-22,
exit 0, with the sheet's four transcription corrections recorded in the
sample headers. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch46`,
72 + 50 + 63 + 22 checks in chapter 46 of the kdd suite.
