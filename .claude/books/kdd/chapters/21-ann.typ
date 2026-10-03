// ch21, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 69 checks in kdd/samples/src/Ch21/perceptron.c (28), mlp.c (23),
// and backprop.c (18) or a pinned note of kdd-contract-s4s5.md: the AND
// and XOR point sets in cyclic order, w=(b,w1,w2) with x0=1, zero init,
// lr=1, update w+=y*x on misclassification only, sign(0)=+1, and the
// step(z>=0)=1 units of the MLP. determinism classes: the perceptron
// traces and the MLP forward pass are D0 integers, the output gradient
// row is D1 dyadic halves asserted with ==, backprop is D2 relative
// 1e-15 against 17-digit generator pins (libm exp differs by ulps
// across toolchains) with the two dead-input gradients exactly 0, D0.
// all pinned values are witnessed by the sheet +
// playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0, the backprop
// row double-run identical.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= neural networks

Three samples carry the chapter: `perceptron.c` runs the AND epoch trace
to convergence and witnesses XOR failing, 28 checks, `mlp.c` pushes all
four XOR inputs through a hand-set 2-2-1 step network and takes one
exact output-layer gradient step, 23 checks, and `backprop.c` walks a
single sigmoid pass forward and backward, 18 checks. The chapter makes
5 moves: the perceptron rule and the epoch where it finally goes clean,
the XOR fixture no line can separate, the hidden layer that buys XOR
anyway, one gradient step small enough to check by hand, and the chain
rule spread across a net of sigmoids. Every behavioral claim below is
one of the 69 checks of chapter 21's samples or a pinned note of the
contract sheet. This is the eager extreme next to the deferred votes of
#xref-to("kdd", "knn"), the squared loss it descends is the same shape
#xref-to("kdd", "regression") fits in closed form, and the
maximum-margin take on a linear boundary belongs to
#xref-to("kdd", "svm").

== six epochs to a clean pass

The perceptron is a linear classifier learned from its own mistakes. It
predicts the sign of $b + w_1 x_1 + w_2 x_2$ with sign(0)=+1, starts
from the all-zero vector, and on each misclassification adds
$y dot (1, x_1, x_2)$ to $(b, w_1, w_2)$, learning rate 1, visiting the
points in the pinned cyclic order. The fixture is AND, the four points
(0,0,-1), (0,1,-1), (1,0,-1), (1,1,+1).

The dry run: the trace prints one line per epoch, `AND epoch 1:
w=(0,1,1) misclassified=2`, then `AND epoch 2: w=(-1,2,1)
misclassified=3`, `AND epoch 3: w=(-2,2,1) misclassified=3`, `AND
epoch 4: w=(-2,2,2) misclassified=2`, `AND epoch 5: w=(-3,2,1)
misclassified=1`, `AND epoch 6: w=(-3,2,1) misclassified=0`, each line
pinned by two checks, and the close `converged at epoch 6, final
w=(-3,2,1)` with "ch21 AND convergence epoch 6". Epoch 1 is worth
walking by hand: from (0,0,0) the first point (0,0) has activation 0,
so the prediction is sign(0)=+1 against a label of -1, wrong on the
very first guess, and the update subtracts (1,0,0) leaving (-1,0,0);
the two single-one points now read -1 and pass; (1,1) reads -1 against
+1, wrong, and adding (1,1,1) ends the epoch at (0,1,1) with 2 misses.
Epoch 6 adds nothing: it re-tests (-3,2,1), finds activations -3, -2,
-1, 0, and the last one only passes because sign(0)=+1. The converged
boundary $-3 + 2 x_1 + x_2 = 0$ passes exactly through the point (1,1),
so the sign convention is load-bearing at both the first mistake and
the final answer, pinned as "ch21 AND final w classifies all 4".

#listing("kdd/samples/src/Ch21/perceptron.c", first: 27, last: 55,
  caption: [the two point sets and the epoch loop with its update rule])

#listing("kdd/samples/src/Ch21/perceptron.c", first: 57, last: 86,
  caption: [six epochs of AND, end weights and misses pinned two checks a line])

#diagram([AND in the plane, the boundary through (1,1), the epoch trace at right], length: 13pt, {
  let px(v) = { 1.6 + v * 2.1 }
  let py(v) = { 1.0 + v * 2.1 }
  cdraw.content((7.6, 7.9), [the plane, then the trace: six epochs, the last one clean], size: 6pt)
  for g in range(0, 3) {
    cdraw.line((px(g * 1.0), py(0.0)), (px(g * 1.0), py(2.3)),
      stroke: (paint: luma(225), dash: "dashed"))
    cdraw.line((px(0.0), py(g * 1.0)), (px(2.3), py(g * 1.0)),
      stroke: (paint: luma(225), dash: "dashed"))
    cdraw.content((px(g * 1.0), 0.5), [#g], size: 6pt)
    cdraw.content((0.75, py(g * 1.0)), [#g], size: 6pt)
  }
  cdraw.line((px(0.5), py(2.0)), (px(1.5), py(0.0)), stroke: 0.9pt + luma(60))
  cdraw.content((4.9, 5.45), [$-3 + 2 x_1 + x_2 = 0$], size: 6pt)
  let pts = (((0, 0), [-], [a = -3], (1.0, 0.72)), ((0, 1), [-], [a = -2], (1.05, 3.35)),
    ((1, 0), [-], [a = -1], (4.3, 0.72)), ((1, 1), [+], [a = 0], (4.2, 3.52)))
  for t in pts {
    let c = (px(t.at(0).at(0) * 1.0), py(t.at(0).at(1) * 1.0))
    if t.at(1) == [+] {
      cdraw.circle(c, radius: 0.13, fill: luma(120))
    } else {
      cdraw.circle(c, radius: 0.13, stroke: luma(120))
    }
    cdraw.content(t.at(3), [#t.at(1) #t.at(2)], size: 6pt)
  }
  cdraw.content((3.5, 0.2), [(1,1) sits on the line and rides sign(0)=+1], size: 6pt)
  let cols = ((7.6, 1.0), (8.7, 3.2), (12.4, 1.4))
  let heads = ([e], [end w], [misses])
  for i in range(3) {
    cdraw.content((cols.at(i).at(0) + cols.at(i).at(1) / 2, 7.0), heads.at(i), size: 6.5pt)
  }
  let rows = (([1], [(0,1,1)], [2]), ([2], [(-1,2,1)], [3]), ([3], [(-2,2,1)], [3]),
    ([4], [(-2,2,2)], [2]), ([5], [(-3,2,1)], [1]), ([6], [(-3,2,1)], [0]))
  for i in range(6) {
    let y = 6.35 - i * 0.82
    for j in range(3) {
      let s = cols.at(j)
      cdraw.rect((s.at(0), y), (s.at(0) + s.at(1), y + 0.72),
        fill: if i == 5 {luma(224)} else {luma(246)}, radius: 0.02)
      cdraw.content((s.at(0) + s.at(1) / 2, y + 0.36), rows.at(i).at(j), size: 6pt)
    }
  }
  cdraw.content((10.35, 1.35), [epoch 6 re-tests (-3,2,1) and touches nothing], size: 6pt)
})

== xor breaks every line

XOR labels the diagonal pairs apart: (0,0) and (1,1) negative, (0,1)
and (1,0) positive. A line separates two classes exactly when their
convex hulls are disjoint, and here the hulls are the unit square's two
diagonals, which cross at the center, so no separator exists at any
precision, integer or otherwise. The sample carries a finite witness of
that geometry: all 343 integer vectors in `{-3..3}^3` are tested
against all four points.

The dry run: the witness prints `xor exhaustive: perfect weight vectors
in {-3..3}^3 = 0`, pinned as "ch21 xor 0 perfect vectors in the box".
Then the run, `xor epoch 1: w=(-1,-1,0) mis=3`, `xor epoch 2:
w=(0,-1,0) mis=3`, and from epoch 3 on every line reads `w=(0,-1,0)
mis=4`, the pair pinned as "ch21 xor epoch 1 end (-1,-1,0)" and "ch21
xor fixed point (0,-1,0) from epoch 2". The fixed point is a closed
loop of four mistakes: starting at (0,-1,0), the point (0,0) activates
0 and predicts + against -, moving to (-1,-1,0); (0,1) activates -1
and predicts - against +, moving to (0,-1,1); (1,0) activates -1
against +, moving to (1,0,1); (1,1) activates 2 against -, and the last
update lands exactly back on (0,-1,0). Four corrections, zero net
movement: the rule is spinning its wheels, not converging slowly.

#listing("kdd/samples/src/Ch21/perceptron.c", first: 88, last: 104,
  caption: [the 343-vector exhaustive witness, zero perfect separators])

#listing("kdd/samples/src/Ch21/perceptron.c", first: 106, last: 122,
  caption: [ten epochs of XOR, the fixed point from epoch 2 on])

#diagram([the XOR square, crossing hulls, and the fixed-point line along the bottom], length: 13pt, {
  let px(v) = { 1.6 + v * 3.4 }
  let py(v) = { 1.3 + v * 3.4 }
  cdraw.content((8.6, 7.9), [hulls cross at the center: no line separates the pairs], size: 6pt)
  cdraw.rect((px(0.0), py(0.0)), (px(1.0), py(1.0)), stroke: luma(150), radius: 0.01)
  cdraw.line((px(0.0), py(0.0)), (px(1.0), py(1.0)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((px(0.0), py(1.0)), (px(1.0), py(0.0)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.circle((px(0.5), py(0.5)), radius: 0.07, fill: luma(60))
  cdraw.content((5.75, 4.5), [hulls cross], size: 6pt)
  let pts = (((0, 0), [-], (1.15, 0.92)), ((0, 1), [+], (1.05, 4.5)),
    ((1, 0), [+], (5.4, 0.92)), ((1, 1), [-], (5.4, 4.55)))
  for t in pts {
    let c = (px(t.at(0).at(0) * 1.0), py(t.at(0).at(1) * 1.0))
    if t.at(1) == [+] {
      cdraw.circle(c, radius: 0.13, fill: luma(120))
    } else {
      cdraw.circle(c, radius: 0.13, stroke: luma(120))
    }
    cdraw.content(t.at(2), t.at(1), size: 7pt)
  }
  cdraw.line((px(-0.15), py(0.0)), (px(1.15), py(0.0)), stroke: 0.9pt + luma(60))
  cdraw.content((3.3, 0.9), [fixed point w = (0,-1,0): line $x_2 = 0$], size: 6pt)
  cdraw.content((3.3, 0.45), [right on 2 of 4 points, like every line], size: 6pt)
  for i in range(10) {
    let x = 8.3 + i * 0.72
    cdraw.rect((x, 4.3), (x + 0.62, 5.0), fill: if i >= 2 {luma(224)} else {luma(246)},
      radius: 0.02)
    cdraw.content((x + 0.31, 4.65), if i >= 2 {[4]} else {[3]}, size: 6.5pt)
    cdraw.content((x + 0.31, 5.35), [#(i + 1)], size: 6pt)
  }
  cdraw.content((11.9, 3.75), [misses per epoch], size: 6pt)
  cdraw.content((11.6, 2.6), [the 343-vector box holds no perfect separator], size: 6pt)
  cdraw.content((11.0, 1.7), [epoch 2 lands on (0,-1,0)], size: 6pt)
  cdraw.content((11.0, 1.25), [and never leaves it again], size: 6pt)
})

#callout("note", "the box is a witness, the crossing hulls are the proof", [
  Zero perfect vectors out of 343 only says no small integer separator
  exists, and the chapter would be overclaiming if it stopped there.
  The separability theorem closes the gap: a hyperplane separates the
  classes exactly when their convex hulls are disjoint, and XOR's
  classes are the two diagonals of the unit square, which intersect.
  No rescaling, no learning rate, no number of epochs changes that,
  and the perceptron convergence guarantee, which promises a finite
  clean epoch whenever the data are separable, stays honest by saying
  nothing at all when they are not.
])

== a hidden layer buys xor

One layer cannot bend, so add a second. The network is 2-2-1 with all
integer weights and step units, step(z)=1 exactly when z is at least 0:
the first hidden unit is OR with weights (2,2,-1), the second is AND
with (2,2,-3), and the output unit reads (2,-2,-1). Each triple is
$(w_(x_1), w_(x_2), "bias")$, the perceptron's (b, w1, w2) with the
bias moved to the end.

The dry run: four lines, `mlp forward (0,0): z=(-1,-3) h=(0,0) z_o=-1
out=0`, `mlp forward (0,1): z=(1,-1) h=(1,0) z_o=1 out=1`, `mlp
forward (1,0): z=(1,-1) h=(1,0) z_o=1 out=1`, and `mlp forward (1,1):
z=(3,1) h=(1,1) z_o=-1 out=0`, sixteen checks, four per input, the
last of each quartet reading like "ch21 mlp (1,1) out 0 == XOR". The
inputs (0,1) and (1,0) produce identical columns, symmetry the fixture
keeps visible. The output computes 2h1 - 2h2 - 1, which is
OR-and-not-AND, and that is exactly XOR. Note that the AND unit here
is the separator (-3,2,2) in the perceptron's bias-first ordering, a
cousin of facet 1's (-3,2,1) that reads activation 1 instead of 0 on
(1,1), so it classifies AND without leaning on the sign(0)=+1 crutch.

#listing("kdd/samples/src/Ch21/mlp.c", first: 25, last: 30,
  caption: [the hand-set integer weights, two hidden steps and a head])

#listing("kdd/samples/src/Ch21/mlp.c", first: 33, last: 47,
  caption: [all four inputs, z, h, z_o, and out pinned as const tables])

#diagram([the 2-2-1 wiring with weights on the edges, truth table beneath], length: 13pt, {
  cdraw.content((8.0, 8.3), [every weight an integer, every unit a step], size: 6pt)
  cdraw.circle((1.2, 6.6), radius: 0.16, stroke: luma(40))
  cdraw.content((1.2, 6.6), [$x_1$], size: 6.5pt)
  cdraw.circle((1.2, 4.6), radius: 0.16, stroke: luma(40))
  cdraw.content((1.2, 4.6), [$x_2$], size: 6.5pt)
  cdraw.rect((4.8, 6.9), (7.8, 7.9), fill: luma(246), radius: 0.02)
  cdraw.content((6.3, 7.55), [$h_1$ = OR], size: 6.5pt)
  cdraw.content((6.3, 7.15), [(2, 2, -1)], size: 6pt)
  cdraw.rect((4.8, 3.4), (7.8, 4.4), fill: luma(246), radius: 0.02)
  cdraw.content((6.3, 4.05), [$h_2$ = AND], size: 6.5pt)
  cdraw.content((6.3, 3.65), [(2, 2, -3)], size: 6pt)
  cdraw.rect((10.6, 5.2), (13.6, 6.2), fill: luma(232), radius: 0.02)
  cdraw.content((12.1, 5.85), [out], size: 6.5pt)
  cdraw.content((12.1, 5.45), [(2, -2, -1)], size: 6pt)
  let edge(a, b, lab, pos) = {
    cdraw.line(a, b, stroke: luma(90))
    cdraw.content(pos, lab, size: 6pt)
  }
  edge((1.36, 6.6), (4.8, 7.4), [2], (2.85, 7.42))
  edge((1.36, 4.6), (4.8, 7.4), [2], (2.55, 6.35))
  edge((1.36, 6.6), (4.8, 3.9), [2], (2.55, 4.85))
  edge((1.36, 4.6), (4.8, 3.9), [2], (2.85, 3.88))
  edge((7.8, 7.4), (10.6, 5.9), [2], (9.2, 7.02))
  edge((7.8, 3.9), (10.6, 5.5), [-2], (9.2, 4.3))
  let cols = ((1.6, 1.5), (4.0, 1.9), (7.6, 3.0), (11.6, 2.0))
  let heads = ([$x_1, x_2$], [h], [$z_o$], [out])
  for i in range(4) {
    cdraw.content((cols.at(i).at(0) + cols.at(i).at(1) / 2, 2.6), heads.at(i), size: 6pt)
  }
  let rows = (([(0,0)], [(0,0)], [-1], [0]), ([(0,1)], [(1,0)], [1], [1]),
    ([(1,0)], [(1,0)], [1], [1]), ([(1,1)], [(1,1)], [-1], [0]))
  for i in range(4) {
    let y = 2.0 - i * 0.55
    for j in range(4) {
      let s = cols.at(j)
      if j == 3 {
        cdraw.rect((s.at(0), y - 0.22), (s.at(0) + s.at(1), y + 0.22),
          fill: luma(232), radius: 0.02)
      }
      cdraw.content((s.at(0) + s.at(1) / 2, y), rows.at(i).at(j), size: 6pt)
    }
  }
  cdraw.content((14.85, 1.5), [bias lives in], size: 6pt)
  cdraw.content((14.85, 1.05), [the box triples], size: 6pt)
})

== one gradient step, exactly

Training means following a gradient, so take the smallest step that is
still the real thing. Freeze the hidden layer of facet 3 at the value
it holds on input (1,1), namely (1,1), and make the output linear with
weights (1,1,-1) and target t=0 under the loss $1\/2 ("out" - t)^2$,
whose derivative in out is just out minus t. Nothing transcendental
enters, so every number is a dyadic rational and the sample asserts the
updates with plain equality.

The dry run: `gradient row: out=1.0 delta=1.0 g=(1.0,1.0,1.0)` and
`lr 0.5 updates: w=(0.5,0.5,-1.5)`. The forward sum is
$1 dot 1 + 1 dot 1 + (-1) = 1$ against a target of 0, the delta is
$"out" - t = 1$, the gradient of the loss in the three output weights
is the delta times their inputs, $1 dot (1, 1, 1)$, and the half-rate
update subtracts one half from each entry, landing on (0.5, 0.5, -1.5),
pinned one check per weight as "ch21 updated w5 0.5 (D1 ==)", "ch21
updated w6 0.5 (D1 ==)", and "ch21 updated b3 -1.5 (D1 ==)". The bias
row is the one to watch in the next facet, because there the inputs
are sigmoid outputs and the cleanliness disappears.

#listing("kdd/samples/src/Ch21/mlp.c", first: 63, last: 81,
  caption: [one linear output, its delta, gradient, and dyadic update])

#diagram([the one step as a pipeline, the three weights before and after], length: 13pt, {
  cdraw.content((8.4, 7.6), [hidden held at (1,1), output linear, t = 0], size: 6pt)
  let box(x, y, w, h, main, sub) = {
    cdraw.rect((x, y), (x + w, y + h), fill: luma(246), radius: 0.02)
    cdraw.content((x + w / 2, y + h - 0.42), main, size: 6.5pt)
    cdraw.content((x + w / 2, y + 0.38), sub, size: 6pt)
  }
  box(0.8, 4.8, 4.2, 1.5, [out = 1], [$1 dot 1 + 1 dot 1 - 1$, t = 0])
  box(6.4, 4.8, 3.8, 1.5, [delta = 1], [$"out" - t$, loss $1\/2 dot 1^2$])
  box(12.2, 4.8, 3.8, 1.5, [g = (1,1,1)], [$"delta" dot (h_1, h_2, 1)$])
  cdraw.line((5.0, 5.55), (6.4, 5.55), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.2, 5.55), (12.2, 5.55), stroke: luma(60), mark: (end: ">"))
  let row(y, tag, before, after, hot) = {
    cdraw.content((1.6, y), tag, size: 6.5pt)
    cdraw.rect((3.4, y - 0.34), (5.8, y + 0.34), fill: luma(246), radius: 0.02)
    cdraw.content((4.6, y), before, size: 6.5pt)
    cdraw.content((6.7, y), [$arrow.r$], size: 6.5pt)
    cdraw.rect((7.9, y - 0.34), (10.3, y + 0.34),
      fill: if hot {luma(224)} else {luma(236)}, radius: 0.02)
    cdraw.content((9.1, y), after, size: 6.5pt)
  }
  row(3.2, [$w_5$], [1], [0.5], false)
  row(2.3, [$w_6$], [1], [0.5], false)
  row(1.4, [$b_3$], [-1], [-1.5], true)
  cdraw.content((12.4, 2.9), [each entry], size: 6pt)
  cdraw.content((12.4, 2.45), [minus $1\/2$], size: 6pt)
  cdraw.content((12.4, 2.0), [times its g], size: 6pt)
})

== backpropagation, one number at a time

The full net swaps steps for sigmoids and lets every weight move.
Hidden rows (0.5, -0.25, 0.125) and (0.25, 0.5, -0.125), output row
(0.75, -0.5, 0.25), input (1,0), target 1, learning rate 0.5, the same
$1\/2 (a - t)^2$ loss. The chain rule then runs backwards: the output
delta is $a_o - t$, the gradient in an output weight is that delta
times the hidden activation feeding it, and each hidden delta is
$a (1 - a)$, the sigmoid's own slope, times the output weight times
the output delta.

The dry run: the forward half prints `z_h=(0.625, 0.125)`, both dyadic
and asserted with equality because x2=0 kills the cross terms leaving
$0.5 + 0.125$ and $0.25 - 0.125$, then `a_h=(0.65135486466605419,
0.53120937337375629)`, then `z_o=0.47291146181266247
a_o=0.61607262845280919 loss=0.073700113311567353`. The backward half
prints `delta_o=-0.38392737154719081 g_wo=(-0.25007296113571437,
-0.20394581846061655, -0.38392737154719081)`, then
`delta_h=(-0.065390041033891275, 0.047803944016977289)`, the second
entry positive only because the middle output weight -0.5 flips its
sign, then the hidden gradient rows `g_wh1=(-0.065390041033891275, -0,
-0.065390041033891275)` and `g_wh2=(0.047803944016977289, 0,
0.047803944016977289)`, and the updated output row
`w_o'=(0.87503648056785721, -0.39802709076969173, 0.4419636857735954)`.
The middle entries of the hidden rows are the dead inputs: x2 is 0, so
those weights see no gradient at all, and the print even shows the
first row's zero as -0, a negative delta times a positive zero. Both
are pinned exactly, "ch21 g_wh1_w2 exactly 0 (D0)" and "ch21 g_wh2_w2
exactly 0 (D0)", while every sigmoid-touching number is pinned to 17
digits at relative 1e-15, "ch21 loss 0.07370011331156735 (D2)" among
them.

#listing("kdd/samples/src/Ch21/backprop.c", first: 36, last: 54,
  caption: [forward: dyadic preactivations, sigmoid pins, the loss])

#listing("kdd/samples/src/Ch21/backprop.c", first: 56, last: 86,
  caption: [backward: deltas, both gradient rows, the dead column])

#listing("kdd/samples/src/Ch21/backprop.c", first: 88, last: 96,
  caption: [the half-rate update on the output row])

#diagram([one example down the net, backward chain root on top, dead column boxed], length: 13pt, {
  cdraw.content((8.0, 8.2), [forward down the left, backward on the right, chain root on top], size: 6pt)
  let fbox(x, y, w, h, main, sub, fill) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h - 0.4), main, size: 6.5pt)
    cdraw.content((x + w / 2, y + 0.36), sub, size: 5.5pt)
  }
  fbox(0.7, 6.6, 3.0, 1.3, [x = (1, 0)], [input], luma(246))
  fbox(0.7, 4.7, 3.0, 1.3, [$z_h$ dyadic], [(0.625, 0.125)], luma(246))
  fbox(0.7, 2.8, 3.0, 1.3, [$a_h$ sigmoid], [(0.651355, 0.531209)], luma(246))
  fbox(0.7, 0.9, 3.0, 1.3, [loss 0.0737001], [$a_o$ = 0.616073], luma(232))
  cdraw.line((2.2, 6.6), (2.2, 6.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.2, 4.7), (2.2, 4.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.2, 2.8), (2.2, 2.2), stroke: luma(60), mark: (end: ">"))
  fbox(5.3, 6.6, 4.4, 1.3, [delta_o = -0.383927], [$a_o$ - t, chain root], luma(236))
  fbox(5.3, 4.7, 4.4, 1.3, [g = delta x a_h], [(-0.250073, -0.203946, -0.383927)], luma(236))
  fbox(5.3, 2.8, 4.4, 1.3, [delta_h], [(-0.065390, +0.047804), a(1-a) w delta], luma(236))
  cdraw.line((7.5, 6.6), (7.5, 6.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((5.3, 7.25), (4.55, 7.25), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.55, 7.25), (4.55, 3.45), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.55, 3.45), (5.3, 3.45), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  fbox(10.9, 4.7, 5.0, 1.3, [w_o' updated], [(0.875036, -0.398027, 0.441964)], luma(236))
  cdraw.line((9.7, 5.35), (10.9, 5.35), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((10.9, 2.6), (15.9, 3.9), fill: luma(224), radius: 0.02)
  cdraw.content((13.4, 3.5), [g_wh rows], size: 6.5pt)
  cdraw.content((13.4, 3.02), [middle entry dead, $x_2$ = 0], size: 6pt)
  cdraw.line((9.7, 3.45), (10.9, 3.45), stroke: luma(60), mark: (end: ">"))
  cdraw.content((13.4, 1.9), [-0 prints as the first row's zero, 0 as the second's], size: 6pt)
  cdraw.content((13.4, 1.35), [D2 rel 1e-15 on the 17-digit pins, the zeros D0], size: 6pt)
})

#callout("pitfall", "a bit-exact pin on a sigmoid is a lie", [
  The generator prints 17 significant digits and its two consecutive
  runs agree exactly, so the pins themselves are stable. The pinned
  sample still refuses to assert equality, because exp comes from the
  toolchain's libm and differs by an ulp or two between builds, and
  one ulp in a gradient becomes visible drift after enough half-rate
  steps. The honest contract is the one the sample implements:
  relative 1e-15 against the printed pin for anything a sigmoid
  touched, plain equality for the dyadic preactivations, and exact
  zero for the dead column, where x2=0 multiplies the gradient away
  before any transcendental can touch it.
])

sources: all 69 pinned values, both point sets, the update and sign
conventions, the step and sigmoid units, and the D0/D1/D2 class
assignments are witnessed by kdd-contract-s4s5.md and
playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0, the backprop
row double-run identical. Sample behavior verified by `pwsh -NoProfile
-File tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch21`, 28 + 23 + 18 checks in chapter 21 of the kdd suite.
