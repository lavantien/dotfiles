// ch22, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 40 checks in kdd/samples/src/Ch22/margin.c (20), kernel.c (6), and
// smo.c (14) or a banked note of kdd-contract-s4s5.md (the SMO selection
// rules and Platt b1/b2 bias update per Platt, MSR-TR-98-14, 1998; the
// integer surd identity; the soft-margin flat edge b in [1,2]; the
// 801x801 exact-rational grid witness). all pinned values are witnessed
// by the sheet + playground/kdd-matrix/gen_s5.py, run 2026-09-22, exit 0,
// the SMO trace double-run identical.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= support vector machines

Three samples carry the chapter: `margin.c` solves a four-point fixture
by hand and then prices a soft-margin grid exactly, 20 checks,
`kernel.c` verifies the degree-2 polynomial kernel as an integer
identity, 6 checks, and `smo.c` runs Platt's sequential minimal
optimization from a cold start to the analytic plane, 14 checks. The
chapter makes 4 moves: the hard-margin geometry with its margin in
exact surds, the soft margin and its flat edge, the kernel trick that
separates a circle without ever building the feature vector, and SMO's
three updates from zero. Every behavioral claim below is one of the 40
checks of chapter 22's samples or a named note of the contract sheet.
The perceptron of #xref-to("kdd", "ann") stops at the first plane that
separates, this chapter is the machinery that keeps going to the widest
one, and #xref-to("kdd", "ensembles") will abandon single planes for
committees.

== the hard margin, solved by hand

Among all planes separating the classes, the widest street is wanted,
and scaling $w$ and $b$ by a positive constant moves no points, so the
canonical convention fixes the street's edges at $y f(x) = 1$ with
$f(x) = w dot x + b$. Maximizing the street width $2\/|w|$ then means
minimizing $w dot w\/2$, a problem whose solution touches the data at
only a few points. The fixture is plus (3,3) and (3,4) against minus
(1,1) and (0,0), small enough to solve with no solver at all: the
widest street is centered on the closest cross-class pair, midpoint
(2,2), normal direction (1,1), the plane $x + y = 4$.

The dry run: the closest cross pair prints `closest cross pair
(3,3)/(1,1) d2=8`, squared distance 8, and the canonical plane `w=(1/2,
1/2), b = -2` prints as `canonical w=(0.5,0.5) b=-2`. The four
functional margins read `f(3,3)=1 yf=1`, `f(3,4)=1.5 yf=1.5`,
`f(1,1)=-1 yf=1`, `f(0,0)=-2 yf=2`: exactly the two supports sit at
$y f = 1$, so check "ch22 support vectors {(3,3),(1,1)}" names the only
two points the plane depends on, and dropping either (3,4) or (0,0)
changes nothing. Then `w.w=0.5 |w|=1/sqrt2`, and the surds close as
integer facts: `w_hat=(1,1)/sqrt(2): p^2+q^2=2, w_hat^2=2/2=1` asserts
the unit normal's squared length as $k\/k$ with $p^2 + q^2 = k = 2$,
never a floating comparison, and `margin=1/|w|=sqrt(2) margin^2=2
b_hat^2=8` pins $1\/|w| = sqrt(2)$ and $b_hat = -2 sqrt(2)$ through
their integer squares 2 and 8. The reconciliation is check "ch22 min
cross d^2=8=(2*margin)^2": the street's full width $2 sqrt(2)$ is
exactly the gap that fixed it.

#listing("kdd/samples/src/Ch22/margin.c", first: 35, last: 56,
  caption: [the closest cross pair fixes the canonical plane, w and b as dyadics])

#listing("kdd/samples/src/Ch22/margin.c", first: 58, last: 72,
  caption: [functional margins at all four points, the supports sit at yf = 1])

#listing("kdd/samples/src/Ch22/margin.c", first: 78, last: 93,
  caption: [the surd ledger: every irrational asserted through its integer square])

#diagram([the hard-margin street: supports at yf = 1, margin sqrt(2) per side], length: 13pt, {
  let px(x) = { 1.7 + x * 1.72 }
  let py(y) = { 0.8 + y * 1.12 }
  cdraw.line((px(-0.3), py(0.0)), (px(5.3), py(0.0)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line((px(0.0), py(-0.3)), (px(0.0), py(5.3)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((11.2, 0.55), [x1], size: 6pt)
  cdraw.content((1.35, 7.0), [x2], size: 6pt)
  cdraw.line((px(-0.3), py(2.3)), (px(2.3), py(-0.3)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((px(0.7), py(5.3)), (px(5.3), py(0.7)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((px(-0.3), py(4.3)), (px(4.3), py(-0.3)), stroke: luma(60))
  cdraw.content((1.15, 3.95), [x+y=2], size: 6pt)
  cdraw.content((9.85, 0.9), [x+y=4], size: 6pt)
  cdraw.content((2.3, 7.25), [x+y=6], size: 6pt)
  cdraw.line((px(1), py(1)), (px(3), py(3)), stroke: luma(120),
    mark: (end: ">", start: ">"))
  cdraw.circle((px(2), py(2)), radius: 0.07, fill: luma(150))
  cdraw.content((5.5, 1.3), [2 sqrt(2)], size: 6pt)
  cdraw.line((px(2.4), py(2.4)), (px(2.85), py(2.85)), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.1, 3.7), [$w\/|w|$], size: 6pt)
  let dot(p, sup, lab, dx, dy) = {
    cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.12,
      fill: if sup {luma(150)} else {luma(225)}, stroke: luma(60))
    cdraw.content((px(p.at(0)) + dx, py(p.at(1)) + dy), lab, size: 6pt)
  }
  dot((0, 0), false, [(0,0) yf=2], 0.2, -0.42)
  dot((1, 1), true, [(1,1) yf=1], -1.05, -0.5)
  dot((3, 3), true, [(3,3) yf=1], 0.45, 0.4)
  dot((3, 4), false, [(3,4) yf=3\/2], 0.45, 0.1)
  cdraw.rect((11.3, 2.2), (17.2, 6.6), fill: luma(246), radius: 0.02)
  cdraw.content((14.25, 6.1), [the surd ledger], size: 6.5pt)
  cdraw.content((14.25, 5.35), [$w\/|w| = (1,1)\/sqrt(2)$], size: 6pt)
  cdraw.content((14.25, 4.65), [$p^2 + q^2 = 2 = k$, $hat(w)^2 = k\/k = 1$], size: 6pt)
  cdraw.content((14.25, 3.95), [margin $= 1\/|w| = sqrt(2)$], size: 6pt)
  cdraw.content((14.25, 3.25), [$"margin"^2 = 2$, $hat(b)^2 = 8$], size: 6pt)
  cdraw.content((14.25, 2.6), [min cross $d^2 = 8$], size: 6pt)
})

== the soft margin and its flat edge

A hard margin assumes the street can stay empty. The soft margin lets
points inside pay rent, $G(w, b) = w^2\/2 + C sum max(0, 1 - y f(x))$,
and the fixture is 1D with $C = 4$: plus at 1, minus at -1, and a
second plus at $-1\/2$ that sits inside any clean street. On the edge
$b = w - 1$, where the minus point lands exactly on its margin, only
the intruder's hinge is active, $G = w^2\/2 + 4(2 - w\/2)$, and the
derivative $w - 2$ vanishes at $w = 2$, $b = 1$, $G = 6$.

The dry run: the sample sweeps the exact-rational grid $w = i\/200$,
$b = j\/200$, scaled by 80000 into integers where $80000 G = i^2 + 800
sum h_k$ exactly, and prints `grid witness 801x801 step 1/200: min
80000*G=480000 at i=400 j=200, points at G=6: 201`. The minimum
$480000\/80000 = 6$ sits at $i = 400$, $j = 200$, which is $w = 2$,
$b = 1$, and no lattice point lands below. The 201 hits are not noise,
they are the flat edge: `flat edge w=2, b in [1,2]: 201 of 201 grid
points at G=6` says every $b$ in $[1, 2]$ scores 6 at $w = 2$, the
minus point's slack trading exactly against the plus point's as the
street slides. At the pinned endpoint the rent ledger prints
`xi=(0,0,400)/400, objective=480000/80000`, the intruder alone pays, and
check "ch22 slack point on the boundary yf=0 (f(-1/2)=0)" places it
exactly on the decision boundary, one full slack deep. The closing line
prices both streets, `margin 1/|w|=0.5; clean-pair hard margin w=1
b=0 margin=1`: renting to the intruder halves the margin.

#listing("kdd/samples/src/Ch22/margin.c", first: 98, last: 117,
  caption: [the whole 801x801 grid priced in exact integers, 80000 G])

#listing("kdd/samples/src/Ch22/margin.c", first: 122, last: 143,
  caption: [the flat edge walk and the slacks at the pinned optimum])

#listing("kdd/samples/src/Ch22/margin.c", first: 145, last: 153,
  caption: [the soft street 1/2 wide against the clean-pair street 1 wide])

#diagram([the soft-margin fixture on a line, and the flat edge of its optimum], length: 13pt, {
  let pl(v) = { 1.6 + (v + 1.5) * 4.7 }
  cdraw.content((9.0, 7.7), [the street at w = 2, b = 1], size: 6.5pt)
  cdraw.rect((pl(-1.0), 5.95), (pl(0.0), 6.85), fill: luma(240), radius: 0.01)
  cdraw.content((pl(-0.5), 6.4), [margin slab, width $1\/2$], size: 6pt)
  cdraw.line((1.6, 5.9), (16.4, 5.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((pl(-0.5), 5.35), (pl(-0.5), 6.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((pl(-0.5), 7.15), [f = 0 here], size: 6pt)
  cdraw.circle((pl(-1.0), 5.9), radius: 0.11, fill: luma(255), stroke: luma(60))
  cdraw.content((pl(-1.0), 5.15), [-1, minus], size: 6pt)
  cdraw.circle((pl(-0.5), 5.9), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((pl(-0.5), 4.75), [-1\/2, plus, xi = 1], size: 6pt)
  cdraw.circle((pl(1.0), 5.9), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((pl(1.0), 5.15), [1, plus], size: 6pt)
  cdraw.content((11.6, 4.15), [the flat edge: every b in [1,2] scores G = 6], size: 6.5pt)
  cdraw.line((8.4, 2.9), (14.8, 2.9), stroke: luma(60))
  cdraw.line((8.4, 2.9), (6.4, 3.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((14.8, 2.9), (16.6, 3.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((11.6, 3.35), [G = 6], size: 6pt)
  cdraw.circle((8.4, 2.9), radius: 0.09, fill: luma(150), stroke: luma(60))
  cdraw.content((8.4, 2.3), [b = 1, one slack], size: 6pt)
  cdraw.circle((14.8, 2.9), radius: 0.09, fill: luma(150), stroke: luma(60))
  cdraw.content((14.8, 2.3), [b = 2, slack moved], size: 6pt)
  cdraw.line((2.2, 1.7), (15.0, 1.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((8.4, 1.5), (8.4, 1.9), stroke: luma(60))
  cdraw.line((14.8, 1.5), (14.8, 1.9), stroke: luma(60))
  cdraw.content((8.4, 1.05), [1], size: 6pt)
  cdraw.content((14.8, 1.05), [2], size: 6pt)
  cdraw.content((11.6, 0.45), [b at w = 2], size: 6pt)
})

#callout("note", "a flat optimum is a choice point", [
  At $w = 2$ every $b$ in $[1, 2]$ attains $G = 6$, so "the" optimum is
  a segment, and a segment cannot be asserted. The sheet pins the
  endpoint $(2, 1)$, the one point of the edge where exactly one
  example carries slack, the same way #xref-to("kdd", "process") pinned
  keep-first for duplicates: a convention named before it is checked.
  The KKT subgradient test agrees, $d G\/d w = w + 2 - [0, 4]$ and
  $d G\/d b = -4 + [0, 4]$ both contain 0 there, and the grid witness
  corroborates over 801 x 801 exact-rational points.
])

== the kernel trick, a circle by a plane

Four positives on the unit circle around a negative at the origin have
no separating line: any line leaving the origin behind cuts the ring.
The degree-2 map $phi(x) = (x_1^2, sqrt(2) x_1 x_2, x_2^2)$ lifts them
into a space where a plane exists, and the plane is almost embarrassing,
$z_1 + z_3 = 1\/2$, because every ring point has $z_1 + z_3 = x_1^2 +
x_2^2 = 1$ and the origin has 0. The trick is that the dual and the
plane both need only inner products, and $(x dot z)^2 = phi(x) dot
phi(z)$ holds exactly: the middle coordinate's two $sqrt(2)$ factors
multiply to the rational 2, so the identity is verified in integers.

The dry run: three pairs check the identity both ways, `K((1,0),(0,1))=0
phi.phi(integers)=0`, `K((2,1),(1,3))=25 phi.phi(integers)=25`,
`K((1,1),(1,1))=4 phi.phi(integers)=4`. The kernel squares the integer
dot products 0, 5, 2 into 0, 25, 4, and the explicit feature dot,
$x_1^2 z_1^2 + 2 (x_1 x_2)(z_1 z_2) + x_2^2 z_2^2$, agrees every time
without a single irrational step. Classification then never builds a
$phi$: the ring prints four lines `ring (1,0): z1+z3=1 > 1/2 -> +` down
to `(0,-1)`, the origin prints `origin: z1+z3=0 < 1/2 -> -`, and check
"ch22 circle set classified 5/5" closes it. The predictor is the
integer test $2 (x_1^2 + x_2^2) > 1$, the plane scaled by 2.

#listing("kdd/samples/src/Ch22/kernel.c", first: 26, last: 43,
  caption: [the kernel, the explicit feature dot, and the plane as an integer test])

#listing("kdd/samples/src/Ch22/kernel.c", first: 46, last: 60,
  caption: [three identity pairs, kernel against feature dot, both integers])

#listing("kdd/samples/src/Ch22/kernel.c", first: 62, last: 75,
  caption: [the ring classifies 5/5 through the plane alone])

#diagram([left: no line separates, right: phi flattens the ring onto z1+z3=1], length: 13pt, {
  let cx = 4.6
  let cy = 4.9
  let r = 1.55
  let pts = ()
  for a in range(0, 371, step: 10) {
    pts.push((cx + r * calc.cos(a), cy + r * calc.sin(a)))
  }
  for i in range(pts.len() - 1) {
    cdraw.line(pts.at(i), pts.at(i + 1), stroke: luma(160))
  }
  cdraw.circle((cx, cy), radius: 0.1, fill: luma(255), stroke: luma(60))
  cdraw.content((cx, cy - 0.5), [origin, -], size: 6pt)
  let ring = (((cx + r, cy), [(1,0) +], 0.85, 0.3), ((cx, cy + r), [(0,1) +], 0.0, 0.5),
    ((cx - r, cy), [(-1,0) +], -1.0, 0.3), ((cx, cy - r), [(0,-1) +], 0.0, -0.5))
  for t in ring {
    cdraw.circle(t.at(0), radius: 0.1, fill: luma(150), stroke: luma(60))
    cdraw.content((t.at(0).at(0) + t.at(2), t.at(0).at(1) + t.at(3)), t.at(1), size: 6pt)
  }
  cdraw.content((cx, 7.5), [input space: no line separates], size: 6.5pt)
  cdraw.line((8.6, 4.9), (10.2, 4.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.4, 5.35), [phi], size: 6.5pt)
  let fz(z) = { 11.2 + z * 3.0 }
  let fy(z) = { 2.0 + z * 3.0 }
  cdraw.line((fz(-0.1), fy(0.0)), (fz(1.3), fy(0.0)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line((fz(0.0), fy(-0.1)), (fz(0.0), fy(1.3)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((fz(1.4), fy(0.0)), [z1], size: 6pt)
  cdraw.content((fz(0.0), fy(1.45)), [z3], size: 6pt)
  cdraw.line((fz(-0.16), fy(0.66)), (fz(0.66), fy(-0.16)), stroke: luma(60))
  cdraw.content((fz(0.95), fy(0.75)), [z1+z3 = 1\/2], size: 6pt)
  cdraw.circle((fz(1.0) - 0.08, fy(0.0)), radius: 0.09, fill: luma(150), stroke: luma(60))
  cdraw.circle((fz(1.0) + 0.08, fy(0.0)), radius: 0.09, fill: luma(150), stroke: luma(60))
  cdraw.content((fz(1.0) + 0.1, fy(0.0) - 0.5), [(1,0) twice], size: 6pt)
  cdraw.circle((fz(0.0), fy(1.0) - 0.08), radius: 0.09, fill: luma(150), stroke: luma(60))
  cdraw.circle((fz(0.0), fy(1.0) + 0.08), radius: 0.09, fill: luma(150), stroke: luma(60))
  cdraw.content((fz(0.0) + 0.95, fy(1.0) + 0.35), [(0,1) twice], size: 6pt)
  cdraw.circle((fz(0.0), fy(0.0)), radius: 0.1, fill: luma(255), stroke: luma(60))
  cdraw.content((fz(0.45), fy(0.0) - 0.7), [(0,0)], size: 6pt)
  cdraw.content((13.4, 7.5), [feature space: the ring flattens], size: 6.5pt)
})

== smo, three updates from zero

The dual, the same minimization rewritten with one multiplier per point,
keeps only inner products, $w = sum_i a_i y_i x_i$ with
$a_i >= 0$, so the solver's whole job is the multiplier vector. SMO,
Platt's MSR-TR-98-14, moves two multipliers at a time: take the
lowest-index KKT violator as $i$, take $j$ maximizing $|E_i - E_j|$
with ties by index, fall back to the next-best $j$ when the box is
degenerate ($L = H$), the step is uphill ($eta >= 0$), or the move
stalls, then clip $a_j$ into its box, compensate $a_i$ to keep the
constraint sum, and set $b$ by the $b_1\/b_2$ midpoint rule. The
fixture is 5 points, plus (6,6), (6,8), (4,6) and minus (2,2), (0,0),
whose analytic solution is the plane $x + 2y = 11$ in canonical form
$w = (1\/5, 2\/5)$, $b = -11\/5$, with dual multipliers $a_2 = a_3 =
1\/10$.

#callout("note", "smo selection, the six moves restated", [
  1. scan the points in index order and take the lowest-index KKT
  violator as $i$. 2. take $j$ maximizing $|E_i - E_j|$, ties by index.
  3. when the box is degenerate ($L = H$), the step is uphill
  ($eta >= 0$), or the move stalls, fall back to the next-best $j$.
  4. clip $a_j$ into its box. 5. compensate $a_i$ to keep the constraint
  sum. 6. set $b$ by the $b_1\/b_2$ midpoint rule.
])

The dry run: `smo updates: 3` is the whole trace. `iter 1: i=0 j=3
alpha_i=0.0625 alpha_j=0.0625 b=-2`: from all-zero every error is
$E_i = -y_i$, the widest gap pairs (6,6) with (2,2), $eta = 2 dot 24 -
72 - 8 = -32$, and both multipliers rise to 1/16. `iter 2: i=2 j=0
alpha_i=0.0625 alpha_j=0 b=-1`: the first candidate $j = 1$ is skipped
for $L = H$, both class plus at $a = 0$, and $a_0$ clips back down to
its box floor 0. `iter 3: i=3 j=2 alpha_i=0.10000000000000001
alpha_j=0.10000000000000001 b=-2.2000000000000002` lands both at
exactly 1/10. The converged line prints `converged alphas: 0 0
0.10000000000000001 0.10000000000000001 0 b=-2.2000000000000002`, and
the per-point comparison against the analytic plane bottoms out at
`x=(6,6) y=+1 f_smo=1.3999999999999995 f_analytic=1.3999999999999999
|diff|=4.441e-16`, closing `ch22 smo: 14 checks (max analytic diff
4.441e-16)`.

#listing("kdd/samples/src/Ch22/smo.c", first: 62, last: 84,
  caption: [violator scan and the j ordering by descending error gap, ties by index])

#listing("kdd/samples/src/Ch22/smo.c", first: 87, last: 106,
  caption: [the L, H box, the eta test, and the unclipped step])

#listing("kdd/samples/src/Ch22/smo.c", first: 113, last: 126,
  caption: [the constraint-sum compensation and Platt's b1/b2 bias rule])

#listing("kdd/samples/src/Ch22/smo.c", first: 180, last: 195,
  caption: [the solver's f checked against the analytic plane on all 5 points])

#diagram([the 5-point fixture and the plane SMO finds, supports at (4,6) and (2,2)], length: 13pt, {
  let px(x) = { 2.6 + x * 1.5 }
  let py(y) = { 0.8 + y * 0.6 }
  cdraw.line((px(0.0), py(-0.2)), (px(6.4), py(-0.2)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line((px(-0.2), py(0.0)), (px(-0.2), py(8.4)), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.content((10.4, 0.5), [x1], size: 6pt)
  cdraw.content((2.05, 6.15), [x2], size: 6pt)
  cdraw.line((px(0.0), py(8.0)), (px(6.0), py(5.0)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((px(0.0), py(5.5)), (px(6.0), py(2.5)), stroke: luma(60))
  cdraw.line((px(0.0), py(3.0)), (px(6.0), py(0.0)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((1.55, 6.6), [x+2y=16], size: 6pt)
  cdraw.content((1.55, 5.1), [x+2y=11], size: 6pt)
  cdraw.content((1.55, 3.4), [x+2y=6], size: 6pt)
  let dot(p, sup, lab, dx, dy) = {
    cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.12,
      fill: if sup {luma(150)} else {luma(225)}, stroke: luma(60))
    cdraw.content((px(p.at(0)) + dx, py(p.at(1)) + dy), lab, size: 6pt)
  }
  dot((0, 0), false, [(0,0) yf=11\/5], 0.0, -0.45)
  dot((2, 2), true, [(2,2) yf=1], -1.15, -0.65)
  dot((4, 6), true, [(4,6) yf=1], 0.35, 0.5)
  dot((6, 6), false, [(6,6) yf=7\/5], -0.05, 0.5)
  dot((6, 8), false, [(6,8) yf=11\/5], 0.0, 0.45)
  cdraw.rect((12.8, 2.15), (17.35, 6.05), fill: luma(246), radius: 0.02)
  cdraw.content((15.07, 5.65), [smo, from zero], size: 6.5pt)
  cdraw.content((15.07, 5.05), [alphas end], size: 6pt)
  cdraw.content((15.07, 4.5), [(0, 0, 0.1, 0.1, 0)], size: 6pt)
  cdraw.content((15.07, 3.95), [b = -2.2], size: 6pt)
  cdraw.content((15.07, 3.4), [f = (x+2y-11)/5], size: 6pt)
  cdraw.content((15.07, 2.85), [worst gap 4.4e-16], size: 6pt)
})

#callout("pitfall", "the trace belongs to the pinned heuristics", [
  Which pair SMO moves is heuristic, and the sheet fixes the heuristics:
  lowest-index violator, widest error gap, index tie-breaks, the
  fallback ladder. A different but equally legal choice of $j$ in
  update 2 gives a different intermediate trace on the way to the same
  dual optimum, so the D3 pins name this sample's rules, not SMO's.
  What is not heuristic is the arithmetic class: every pin is asserted
  with `==` on the double because the loop only adds, subtracts,
  multiplies, and divides values seeded from integer kernel entries,
  and IEEE 754 exactly rounds those four operations on every
  conforming platform. The libm `exp` that forced the backprop pins of
  #xref-to("kdd", "ann") down to tolerance never enters a linear
  kernel, so bit-exactness is honest here.
])

sources: SMO selection rules and the $b_1\/b_2$ bias update per John C.
Platt, Sequential Minimal Optimization: A Fast Algorithm for Training
Support Vector Machines, technical report MSR-TR-98-14, Microsoft
Research, 1998, banked by kdd-contract-s4s5.md. All 40 pinned values
witnessed by the same sheet and playground/kdd-matrix/gen_s5.py, run
2026-09-22, exit 0, the SMO trace reconciled update by update and
identical across two consecutive runs. Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch22`, 20 + 6 + 14 checks in chapter 22
of the kdd suite.
