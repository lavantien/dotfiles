#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= automatic differentiation

Gradients drive everything downstream of this point in the book: descent in #xref-to("math", "optimization") consumes one $nabla L$ per step and the quality of the step is the quality of the gradient. This chapter builds the two machines that produce gradients exactly, at machine precision, from the same code that computes the value: forward mode over dual numbers, one seeded pass per input, and reverse mode over an expression tape, one forward evaluation plus one backward sweep for every input at once, which is what backpropagation is. The route runs through the accuracy ceiling of finite differences, the dual number algebra, the tape and its adjoint sweep, a 2-layer network with every weight gradient pinned, the cost model that decides which mode wins, and the two-gate verification discipline that keeps all of it honest. Every behavioral claim below is one of the 57 checks in the 3 samples of chapter 12 or a sentence quoted from the mml-book draft 2024-01-15 anchor sheet. Where #xref-to("dsa", "numerical") consumes slopes as driver ingredients, this chapter computes them exactly.

== the accuracy ceiling of finite differences

Chapter 9 differentiated by quotient: perturb, reevaluate, divide. Definition 5.1 of the mml book defines the difference quotient $(f(x + delta x) - f(x)) / delta x$ and its limit as the derivative [printed p 141 / pdf p 147]. Two quotients are standard, the forward one with truncation error $O(h)$ and the central one $(f(x+h) - f(x-h)) / (2h)$ with truncation error $O(h^2)$, and both carry a rounding term of order $epsilon |f| / h$ where $epsilon = 2^(-52)$ is the machine precision of #xref-to("math", "error"). Balancing truncation against rounding puts the forward optimum near $sqrt(epsilon) approx 1.49 times 10^(-8)$ and the central optimum near $epsilon^(1/3) approx 6.06 times 10^(-6)$, the cbrt rule derived in #xref-to("math", "univariate"). Below those step sizes the rounding term dominates and the quotient degrades, above them the truncation term does.

#snippet(
  "double fd = (f(x + h) - f(x)) / h;        // O(h) + eps|f|/h\n" +
  "double cd = (f(x + h) - f(x - h)) / (2*h); // O(h^2) + eps|f|/h",
  lang: "c",
)

Measured on the fixed function that carries this chapter, the mml book's own eq (5.109) $f(x) = sqrt(x^2 + exp(x^2)) + cos(x^2 + exp(x^2))$ [printed p 159 / pdf p 165], at $x = 0.5$ where the true slope is $-1.3604310785982792$:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*h*], [*forward error*], [*central error*]),
  [1e-3], [2.18e-3], [2.23e-7],
  [1e-4], [2.18e-4], [2.23e-9],
  [1e-5], [2.18e-5], [3.07e-11],
  [1e-6], [2.18e-6], [8.03e-11],
  [1e-8], [2.25e-8], [3.02e-10],
  [1e-10], [6.89e-7], [4.22e-7],
  [1e-12], [1.86e-4], [7.48e-5],
  [1e-15], [2.82e-2], [2.82e-2],
  [1e-17], [1.36e0], [1.36e0],
)

The dry run: at $h = 10^(-17)$ the machine cannot represent the perturbed point at all. One ulp of 0.5 is $1.11 times 10^(-16)$, half an ulp is $5.55 times 10^(-17)$, so $0.5 + h$ rounds back to exactly 0.5, both function evaluations return the same double, both quotients return exactly 0, and the error is 1.36, the entire slope. One decade up, at $h = 10^(-8)$, the forward quotient lands $2.25 times 10^(-8)$ from the truth while the central quotient at $h = epsilon^(1/3)$ lands $1.91 times 10^(-12)$ away, the measured floor on this function, right where the cbrt analysis put the optimum. The two columns fall and rise in a V because the two error terms exchange roles, and no choice of $h$ buys more than roughly 11 correct digits.

#callout("pitfall", "h below half an ulp is invisible", [
  at $x = 0.5$ any $h < 5.55 times 10^(-17)$ rounds $x + h$ back to $x$, so the quotient is exactly 0 and the reported slope is 0, not a small refinement of the previous estimate. shrinking the step past the representable increment deletes the measurement. the same cliff exists at every scale: near $x = 1000$ the ulp is $1.14 times 10^(-13)$ and the central difference is already unreliable at $h = 10^(-7)$.
])

The alternative to differencing is symbolic manipulation. Applied to (5.109) it produces eq (5.110), a two line closed form whose factored shape $2x (1 + exp(x^2)) (1/(2 sqrt(x^2 + exp(x^2))) - sin(x^2 + exp(x^2)))$ took care to derive, and the book's own verdict is that writing out gradients this way "is often impractical since it often results in a very lengthy expression" [printed p 159 / pdf p 165]. Hand derived gradients also rot: change one term of the function and every derivative line must be redone by hand, with nothing but discipline catching the stale ones. What is wanted is a mechanism that differentiates whatever code computes the value, with the derivative correct to the last representable digit.

The play: the best central difference lands $1.91 times 10^(-12)$ from the true slope at $h = 6.06 times 10^(-6)$, the best forward difference lands $2.25 times 10^(-8)$ away at $h = 10^(-8)$, and the dual number pass in the next section lands within one part in $10^(12)$ of the closed form at the cost of one evaluation.

#diagram([measured absolute error of the two difference quotients on f at x = 0.5, log-log axes, h from 1e-1 down to 1e-17], length: 13pt, {
  let cen = ((13.00, 4.28), (12.19, 3.63), (11.38, 3.04), (10.56, 2.46),
             (9.75, 1.91), (8.94, 2.03), (8.12, 2.20), (7.31, 2.20),
             (6.50, 2.93), (5.69, 3.12), (4.88, 3.37), (4.06, 3.79),
             (3.25, 4.07), (2.44, 4.35), (1.62, 4.54), (0.81, 4.82),
             (0.00, 5.04))
  let fwd = ((13.00, 4.80), (12.19, 4.51), (11.38, 4.22), (10.56, 3.92),
             (9.75, 3.63), (8.94, 3.33), (8.12, 3.04), (7.31, 2.75),
             (6.50, 2.75), (5.69, 3.19), (4.88, 3.57), (4.06, 3.90),
             (3.25, 4.25), (2.44, 4.35), (1.62, 4.54), (0.81, 4.98),
             (0.00, 5.04))
  let segs(pts, st) = {
    for i in range(1, pts.len()) {
      cdraw.line(pts.at(i - 1), pts.at(i), stroke: st)
    }
  }
  cdraw.line((0, 0), (13, 0), stroke: luma(100))
  cdraw.line((0, 0), (0, 5), stroke: luma(100))
  for (tx, lab) in ((13.0, [1e-1]), (9.75, [1e-5]), (6.5, [1e-9]), (3.25, [1e-13]), (0.0, [1e-17])) {
    cdraw.line((tx, 0), (tx, 0.12), stroke: luma(100))
    cdraw.content((tx, -0.45), lab, size: 6pt, anchor: "north")
  }
  for (ty, lab) in ((5.0, [1e0]), (3.24, [1e-6]), (1.76, [1e-11]), (0.29, [1e-16])) {
    cdraw.line((0, ty), (0.12, ty), stroke: luma(100))
    cdraw.content((-0.35, ty), lab, size: 6pt, anchor: "east")
  }
  segs(cen, luma(60))
  segs(fwd, (paint: luma(140), dash: "dashed"))
  cdraw.circle((9.57, 1.55), radius: 0.09, fill: luma(60))
  cdraw.content((9.57, 1.1), [cbrt(eps), 1.9e-12], size: 6pt)
  cdraw.circle((6.9, 2.75), radius: 0.09, fill: luma(245), stroke: luma(60))
  cdraw.content((5.6, 2.4), [sqrt(eps), 2.3e-8], size: 6pt)
  cdraw.content((11.6, 2.55), [central], size: 6pt)
  cdraw.content((11.6, 4.55), [forward], size: 6pt)
  cdraw.content((6.5, -1.05), [step size h], size: 6pt)
})

== dual numbers and forward mode

Make the derivative a passenger. A dual number is $a + b epsilon$ with $epsilon^2 = 0$, an algebra cousin of the complex numbers with a nilpotent unit instead of an imaginary one. Evaluate a function built from addition, multiplication, division and the elementary functions at the seeded pair $(x, 1)$ and the second component of the result is $f'(x)$, because every arithmetic rule propagates tangents by exactly the rules of chapter 9:

$ (u + u' epsilon)(v + v' epsilon) = u v + (u' v + u v') epsilon $

The $epsilon^2$ term is zero by construction, not by neglect, so no information is lost to cancellation and the tangent is exact up to the rounding of the value arithmetic itself. This is forward mode, the grouping $ (d f \/ d b) ((d b \/ d a) (d a \/ d x))$ of the mml chain rule (5.121), in which "gradients flow with the data" [printed p 161 / pdf p 167].

The dry run: seed $x = 0.5$ with tangent 1 and walk the intermediate variables of the mml example 5.14, eqs (5.123) to (5.128). Each row carries its value and its tangent, and the tangent column is $d f \/ d x$ at every row.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*node*], [*rule*], [*value*], [*tangent*]),
  [$x$], [seed], [0.5], [1],
  [$a = x^2$], [product], [0.25], [1],
  [$b = exp(a)$], [chain], [1.284025], [1.284025],
  [$c = a + b$], [sum], [1.534025], [2.284025],
  [$d = sqrt(c)$], [chain], [1.238558], [0.922050],
  [$e = cos(c)$], [chain], [0.036763], [-2.282481],
  [$f = d + e$], [sum], [1.275320], [-1.360431],
)

The last row is the payoff: value 1.2753204214157405 and slope -1.3604310785982792 from one pass, the slope matching the sympy pinned closed form of eq (5.110) to 12 digits (check 13 of the sample).

#listing("math/samples/src/Ch12/dual.c", first: 40, last: 62, caption: [dual.c, the seeded constructors and the four arithmetic rules with their mml equation numbers])

Seeding is the whole interface. `d_var` turns on the derivative with respect to that input, `d_const` leaves it off, and an unseeded pass returns a tangent lane of exactly 0 (check 15). The function itself is written once, in the intermediate variable order of the book, and it serves both evaluations:

#listing("math/samples/src/Ch12/dual.c", first: 84, last: 102, caption: [dual.c, the mml function and its closed-form derivative written side by side])

One seeded pass produces one column of the jacobian of #xref-to("math", "multivariate"). On the two input function of example 5.7, $f(x_1, x_2) = x_1^2 x_2 + x_1 x_2^3$ at $(2, 3)$, the pass seeded on $x_1$ returns 39 and the pass seeded on $x_2$ returns 58, both exact because every intermediate is an integer below $2^53$ (checks 16 to 19). A function of $n$ inputs needs $n$ seeded passes for all $n$ columns, and each pass costs the same as one evaluation of the function plus one lane of arithmetic.

The play: the same function, one pass, one column. Seed $x_1$, get 39, seed $x_2$, get 58, and notice the price tag: two full traversals for a two dimensional gradient.

#diagram([the two lanes of one dual multiply, the product rule rides along in the tangent lane], length: 13pt, {
  cdraw.rect((0, 3.8), (3.4, 4.8), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((1.7, 4.3), [u = (value, tangent)], size: 6pt)
  cdraw.rect((0, 1.0), (3.4, 2.0), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((1.7, 1.5), [v = (value, tangent)], size: 6pt)
  cdraw.line((3.4, 4.3), (4.95, 3.35), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.4, 1.5), (4.95, 2.55), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((5.0, 2.45), (6.2, 3.45), fill: luma(205), radius: 0.02, stroke: luma(60))
  cdraw.content((5.6, 2.95), [mul], size: 6pt)
  cdraw.line((6.2, 2.95), (7.35, 2.95), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((7.4, 2.45), (12.6, 3.45), fill: luma(245), radius: 0.02, stroke: luma(100))
  cdraw.content((10.0, 2.95), [$(u v, u' v + u v')$], size: 6pt)
  cdraw.line((0, 0.2), (12.6, 0.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((6.3, 0.55), [one pass, both lanes, the eps^2 term is zero by construction], size: 6pt)
})

== the tape and reverse mode

Reverse mode keeps the graph instead of the passenger. Evaluate once, recording for every intermediate its value, its parents and the local partials, then sweep adjoints backward. The mml book formalizes the computation graph as $x_i = g_i (x_"Pa"(x_i))$ for the computed nodes (5.143) and the sweep as (5.145):

$ (partial f)/(partial x_i) = sum_(x_j : x_i in "Pa"(x_j)) (partial f)/(partial x_j) (partial g_j)/(partial x_i) $

with the seed $partial f \/ partial x_D = 1$ at the output (5.144). Writing the adjoint of node $j$ as $bar(x)_j$, the sweep says: when node $j$ is reached, its adjoint is final, and it contributes $bar(x)_j times (partial g_j \/ partial x_i)$ to each parent $i$. This is the grouping $ ((d f \/ d b) (d b \/ d a)) (d a \/ d x)$ of (5.120), "gradients backward, opposite to data flow" [printed p 161 / pdf p 167].

The dry run: the same seven nodes as the dual table, values filled left to right, then adjoints swept right to left. The fan-in at $c$ is the whole story of eq (5.135): $c$ feeds both $d$ and $e$, so its adjoint is a sum of two contributions.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*node*], [*adjoint formula*], [*value*]),
  [$f$], [seed (5.144)], [1],
  [$d$], [$bar(f) dot 1$], [1],
  [$e$], [$bar(f) dot 1$], [1],
  [$c$], [$1 dot 1/(2 sqrt(c)) + 1 dot (-sin c)$ (5.139)], [-0.595629],
  [$b$], [$bar(c) dot 1$ (5.140)], [-0.595629],
  [$a$], [$bar(b) dot exp(a) + bar(c) dot 1$ (5.141)], [-1.360431],
  [$x$], [$bar(a) dot 2x$ (5.142)], [-1.360431],
)

The last row matches the closed form of eq (5.110) to 12 digits (check 14 of the sample). Every intermediate gradient, not just the input gradient, is available after the sweep, which is what training diagnostics read.

#listing("math/samples/src/Ch12/tape.c", first: 15, last: 29, caption: [tape.c, the node: value, adjoint, two local partials, two parent indices, one op tag])

#listing("math/samples/src/Ch12/tape.c", first: 92, last: 106, caption: [tape.c, the reverse sweep, mml eq (5.145) as a flat array walk])

#callout("note", "creation order is the sweep schedule", [
  the reverse loop walks indices from the root down, and that is valid because every parent has a smaller index than its children: a node is pushed only after its parents exist. that single invariant lets one flat array replace a pointer graph, since no child contributes to a parent before the child's adjoint is final. push a node whose parent is not on the tape yet and the sweep silently reads a stale bar.
])

On the two input function $x_1^2 x_2 + x_1 x_2^3$ at $(2, 3)$ the tape needs one forward pass plus one sweep, and both partials, 39 and 58, fall out together (checks 15 to 17 of the sample), where forward mode spent two seeded passes. For a scalar valued function of $n$ inputs this is the difference between $n$ traversals and two.

The play: two columns, two traversals forward, two traversals reverse. The reverse pair grows no matter how many inputs arrive, which is the entire economic argument of the next sections.

#diagram([the seven-node tape for example 5.14 at x = 0.5, values fill left to right, adjoints sweep right to left], length: 13pt, {
  let names = ([$x$], [$a = x^2$], [$b = exp a$], [$c = a + b$], [$d = sqrt c$], [$e = cos c$], [$f = d + e$])
  let bars = ([-1.3604], [-1.3604], [-0.5956], [-0.5956], [1], [1], [1])
  for i in range(7) {
    let x0 = i * 1.85
    cdraw.rect((x0, 2.0), (x0 + 1.6, 3.2), fill: luma(235), radius: 0.02, stroke: luma(100))
    cdraw.content((x0 + 0.8, 2.6), names.at(i), size: 6pt)
    cdraw.content((x0 + 0.8, 1.55), text(6pt)[#i], size: 6pt)
    cdraw.content((x0 + 0.8, 0.95), bars.at(i), size: 6pt)
  }
  cdraw.line((0.8, 3.55), (11.9, 3.55), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.35, 3.9), [forward fill, creation order], size: 6pt)
  cdraw.line((11.9, 0.25), (0.8, 0.25), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((6.35, -0.1), [reverse sweep, adjoints right to left], size: 6pt)
})

== backpropagation on a layered function

The mml book introduces backpropagation for deep compositions $y = (f_K ∘ f_(K-1) ∘ dots ∘ f_1)(x)$ (5.111) built from layers $f^i = sigma_i (A_(i-1) f^(i-1) + b_(i-1))$ (5.112) under a squared loss $L(theta) = norm(y - f^K (theta, x))^2$ (5.114), and calls it "an efficient way to compute the gradient of an error function with respect to the parameters of the model" [printed pp 159-161 / pdf pp 165-167]. Section 5.6.2 then folds it into the general theory: "backpropagation is a special case of a general technique in numerical analysis called automatic differentiation" [printed p 161 / pdf p 167]. Read through the tape lens, the layer bookkeeping of eq (5.118) is adjacency reuse: the adjoint of a layer node is computed once and read by every weight that feeds the layer.

The fixed network: input $x = 0.5$, hidden layer $h_1 = sigma(w_11 x + b_1)$, $h_2 = sigma(w_12 x + b_2)$ with $(w_11, b_1, w_12, b_2) = (2, -0.5, -1, 0.25)$, output $y = sigma(w_21 h_1 + w_22 h_2 + b_3)$ with $(w_21, w_22, b_3) = (1, 2, -0.75)$, label $t = 0.5$, loss $L = (y - t)^2$. That is eq (5.112) twice with $sigma$ the logistic sigmoid.

The dry run, forward first, all values pinned by sympy:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*quantity*], [*expression*], [*value*]),
  [$z_1$], [$w_11 x + b_1$], [0.5],
  [$h_1$], [$sigma(z_1)$], [0.622459],
  [$z_2$], [$w_12 x + b_2$], [-0.25],
  [$h_2$], [$sigma(z_2)$], [0.437823],
  [$u$], [$w_21 h_1 + w_22 h_2 + b_3$], [0.748106],
  [$y$], [$sigma(u)$], [0.678766],
  [$L$], [$(y - t)^2$], [0.031957],
)

Then backward, each row one application of the sweep at a node:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*gradient*], [*rule*], [*value*]),
  [$partial L \/ partial y$], [$2 (y - t)$], [0.357532],
  [$partial L \/ partial u$], [$bar(y) dot y (1 - y)$], [0.077957],
  [$partial L \/ partial w_21$], [$bar(u) dot h_1$], [0.048525],
  [$partial L \/ partial w_22$], [$bar(u) dot h_2$], [0.034132],
  [$partial L \/ partial b_3$], [$bar(u) dot 1$], [0.077957],
  [$partial L \/ partial h_1$], [$bar(u) dot w_21$], [0.077957],
  [$partial L \/ partial h_2$], [$bar(u) dot w_22$], [0.155914],
  [$partial L \/ partial w_11$], [$bar(h_1) dot h_1 (1 - h_1) dot x$], [0.009160],
  [$partial L \/ partial b_1$], [$bar(h_1) dot h_1 (1 - h_1)$], [0.018320],
  [$partial L \/ partial w_12$], [$bar(h_2) dot h_2 (1 - h_2) dot x$], [0.019188],
  [$partial L \/ partial b_2$], [$bar(h_2) dot h_2 (1 - h_2)$], [0.038376],
  [$partial L \/ partial t$], [$-bar(y)$], [-0.357532],
)

All 12 rows come out of one forward pass and one sweep, each pinned to 12 digits by checks 5 to 12 of the sample. The sigmoid's local partial $s (1 - s)$ is computed once on the forward pass and stored in the node:

#listing("math/samples/src/Ch12/backprop.c", first: 85, last: 90, caption: [backprop.c, the sigmoid node carries its own local partial for the sweep])

#listing("math/samples/src/Ch12/backprop.c", first: 160, last: 179, caption: [backprop.c, the network as 9 input leaves and 13 computed nodes, then one sweep])

The play: one sweep hands over all 12 gradients at once. The largest in magnitude is $partial L \/ partial t = -0.3575$ and the smallest is $partial L \/ partial w_11 = 0.009160$, a 39 to 1 spread that #xref-to("math", "optimization") would otherwise pay 12 inaccurate finite difference evaluations to feel.

#diagram([forward pass solid, adjoint sweep dashed, every number measured in backprop.c at the pinned weights], length: 13pt, {
  let nb(x, y, t) = {
    cdraw.rect((x, y), (x + 1.3, y + 0.8), fill: luma(235), radius: 0.02, stroke: luma(100))
    cdraw.content((x + 0.65, y + 0.4), t, size: 6pt)
  }
  nb(0, 3.0, [$x$])
  nb(3.0, 4.4, [$z_1$])
  nb(5.2, 4.4, [$h_1$])
  nb(3.0, 1.6, [$z_2$])
  nb(5.2, 1.6, [$h_2$])
  nb(7.4, 3.0, [$u$])
  nb(9.6, 3.0, [$y$])
  nb(11.8, 3.0, [$L$])
  let arr(a, b, st) = cdraw.line(a, b, stroke: st, mark: (end: ">"))
  arr((1.3, 3.5), (3.0, 4.6), luma(60))
  cdraw.content((2.0, 4.35), [$w_11$], size: 6pt)
  arr((4.3, 4.8), (5.2, 4.8), luma(60))
  cdraw.content((4.75, 5.1), [$sigma$], size: 6pt)
  arr((1.3, 3.3), (3.0, 2.0), luma(60))
  cdraw.content((2.0, 2.35), [$w_12$], size: 6pt)
  arr((4.3, 2.0), (5.2, 2.0), luma(60))
  cdraw.content((4.75, 2.3), [$sigma$], size: 6pt)
  arr((6.5, 4.6), (7.4, 3.6), luma(60))
  cdraw.content((7.1, 4.35), [$w_21$], size: 6pt)
  arr((6.5, 2.0), (7.4, 3.0), luma(60))
  cdraw.content((7.1, 2.2), [$w_22$], size: 6pt)
  arr((8.7, 3.4), (9.6, 3.4), luma(60))
  cdraw.content((9.15, 3.7), [$sigma$], size: 6pt)
  arr((10.9, 3.4), (11.8, 3.4), luma(60))
  cdraw.content((11.35, 3.7), [$(y - t)^2$], size: 6pt)
  let back = (paint: luma(150), dash: "dashed")
  arr((11.8, 3.0), (10.9, 3.0), back)
  cdraw.content((11.35, 2.65), [0.3575], size: 6pt)
  arr((9.6, 3.0), (8.7, 3.0), back)
  cdraw.content((9.15, 2.65), [0.0780], size: 6pt)
  arr((7.4, 3.8), (6.5, 4.85), back)
  cdraw.content((7.5, 4.85), [0.0780], size: 6pt)
  arr((7.4, 2.7), (6.5, 1.75), back)
  cdraw.content((7.5, 1.75), [0.1559], size: 6pt)
  arr((5.2, 4.3), (4.3, 4.3), back)
  cdraw.content((4.75, 3.95), [0.0183], size: 6pt)
  arr((5.2, 1.5), (4.3, 1.5), back)
  cdraw.content((4.75, 1.15), [0.0384], size: 6pt)
})

== the cost model: columns versus sweeps

Forward mode prices by the number of seeded directions, reverse mode prices at one forward plus one sweep regardless of input count. The mml book states the consequence for learning systems: "In the context of neural networks, where the input dimensionality is often much higher than the dimensionality of the labels, the reverse mode is computationally significantly cheaper than the forward mode" [printed p 161 / pdf p 167].

The dry run: the fixture is the 13-node network of the previous section and its 7 weights, and the counters come out 91 elementary evaluations for forward mode against 26 for reverse.

The network of the previous section is a 13-node graph, and the counts are measured by the sample, not asserted. Forward mode needs one seeded pass per weight: 7 weights times 13 nodes is 91 elementary evaluations. Reverse mode needs 13 forward plus 13 sweep visits, 26 in total. The two curves tie at exactly 2 seeded inputs and reverse wins everywhere beyond, while forward mode keeps an advantage the plot does not show: it stores no graph, so its memory is $O(1)$ extra per intermediate.

#listing("math/samples/src/Ch12/backprop.c", first: 199, last: 207, caption: [backprop.c, the measured traversal counts for both modes on the same graph])

#callout("warning", "the tape is memory, not magic", [
  reverse mode buys 26 versus 91 by remembering every intermediate, 48 bytes per node in this chapter's tapes. a 10-layer network over a million activations holds hundreds of megabytes of nodes and adjoints. production frameworks checkpoint layer boundaries and recompute the forward pass in chunks during the sweep, trading a bounded factor of time for memory that no longer grows with depth.
])

The rule of thumb falls out of the same counting. A scalar loss with many parameters is the learning shape and belongs to reverse mode. A function of few inputs, or a request for directional derivatives along a handful of directions, belongs to forward mode, which also vectorizes naturally when one pass carries a vector of tangents.

The play: 91 versus 26 elementary evaluations for the same 7 gradients, and the tie point sits at 2 inputs, which is exactly where the two-input function of the earlier sections sat when forward mode spent 2 passes and reverse spent 2 traversals.

#diagram([elementary evaluations against the number of seeded inputs, forward grows as 13 per input, reverse stays flat at 26], length: 13pt, {
  let fpts = ((0.0, 0.75), (1.714, 1.5), (3.429, 2.25), (5.143, 3.0), (6.857, 3.75),
              (8.571, 4.5), (10.286, 5.25), (12.0, 6.0))
  for i in range(1, fpts.len()) {
    cdraw.line(fpts.at(i - 1), fpts.at(i), stroke: luma(60))
  }
  cdraw.line((0, 1.5), (12, 1.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((0, 0), (12, 0), stroke: luma(100))
  cdraw.line((0, 0), (0, 6), stroke: luma(100))
  for (tx, lab) in ((0.0, [1]), (1.714, [2]), (5.143, [4]), (12.0, [8])) {
    cdraw.line((tx, 0), (tx, 0.12), stroke: luma(100))
    cdraw.content((tx, -0.45), lab, size: 6pt, anchor: "north")
  }
  for (ty, lab) in ((1.5, [26]), (3.0, [52]), (5.25, [91])) {
    cdraw.line((0, ty), (0.12, ty), stroke: luma(100))
    cdraw.content((-0.35, ty), lab, size: 6pt, anchor: "east")
  }
  cdraw.circle((1.714, 1.5), radius: 0.09, fill: luma(245), stroke: luma(60))
  cdraw.content((2.9, 1.95), [tie at 2 inputs], size: 6pt)
  cdraw.content((9.3, 4.7), [forward, 13 per pass], size: 6pt)
  cdraw.content((9.3, 1.95), [reverse, 13 + 13], size: 6pt)
  cdraw.content((6.0, -1.05), [inputs seeded], size: 6pt)
})

== verification discipline

An autodiff implementation is a small interpreter for the chain rule, and interpreters get wiring bugs: a dropped parent edge, a missed fan-in accumulation, a stale adjoint read. The mml book prescribes the gradient check in a remark in section 5.2 [printed p 149 / pdf p 155]: compare the analytic gradient $d f_i$ against the finite-difference approximation $d h_i$ from (5.39) at a small $h$, the book's example being $h = 10^(-4)$, componentwise through the criterion

$ sqrt((sum_i (d h_i - d f_i)^2) / (sum_i (d h_i + d f_i)^2)) < 10^(-6) $

The loose gate catches structural errors, which typically shift gradients by whole factors. It cannot catch drift, because the central difference itself is only good to about $10^(-9)$ on this network, per the ceiling of the first section. So this chapter pins every gradient twice, and the samples enforce both gates on every number: the sympy exact value at relative $10^(-12)$ and the mml criterion against central differences.

The dry run: the mml criterion over all 7 weights at $h = 10^(-4)$ measures $1.02 times 10^(-9)$ on the fixed network, three decades inside the $10^(-6)$ gate (check 18). The one-weight spelling puts the central difference at 0.0091601191772 against the pinned 0.0091601191794 (check 19).

#listing("math/samples/src/Ch12/backprop.c", first: 213, last: 229, caption: [backprop.c, the mml criterion computed over all 7 weights at h = 1e-4])

The exact pins run at $10^(-12)$ relative throughout, which finite differences can never meet at any step size.

#callout("verify", "pin the gradient twice", [
  every gradient in this chapter answers to two independent authorities: the central difference through the mml section 5.2 criterion below $10^(-6)$, which catches wiring bugs, and the sympy pinned exact value at relative $10^(-12)$, which catches drift and regressions. a gradient that passes only the loose gate can still be wrong in its fourth digit, and one that passes only the tight gate may be pinned to a formula that no longer matches the code.
])

#diagram([the two-gate rule, loose agreement with differences and tight agreement with the pinned exact value], length: 13pt, {
  cdraw.rect((0, 2.0), (3.9, 3.0), fill: luma(235), radius: 0.02, stroke: luma(100))
  cdraw.content((1.95, 2.5), [autodiff gradient], size: 6pt)
  cdraw.rect((5.1, 3.3), (10.5, 4.5), fill: luma(245), radius: 0.02, stroke: luma(100))
  cdraw.content((7.8, 4.1), [central difference gate], size: 6pt)
  cdraw.content((7.8, 3.6), [mml 5.2 criterion < 1e-6, measured 1.02e-9], size: 6pt)
  cdraw.rect((5.1, 0.5), (10.5, 1.7), fill: luma(245), radius: 0.02, stroke: luma(100))
  cdraw.content((7.8, 1.3), [exact pin gate], size: 6pt)
  cdraw.content((7.8, 0.8), [relative error < 1e-12 vs sympy], size: 6pt)
  cdraw.line((3.9, 2.8), (5.1, 3.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.9, 2.2), (5.1, 1.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.5, 3.9), (11.7, 2.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.5, 1.1), (11.7, 2.1), stroke: luma(60), mark: (end: ">"))
  cdraw.rect((11.7, 2.0), (14.5, 3.0), fill: luma(205), radius: 0.02, stroke: luma(60))
  cdraw.content((13.1, 2.5), [both pass], size: 6pt)
})

This discipline is the contract the rest of the book leans on. The capstone planner's cost model needs gradients the moment its weights become tunable, and the machinery drops in unchanged: the objective is just another tape, forward once, sweep once, pin every number twice. The continuous half of the book ends here. #xref-to("math", "proof") opens the discrete half with the proof vocabulary these pinned checks have been using informally.

sources: mml-book draft 2024-01-15, ch 5, sec 5.6 backpropagation and automatic differentiation [printed pp 159-164 / pdf pp 165-170] including eqs (5.109)-(5.145) and example 5.14, sec 5.5 gradient identities [printed pp 158-159 / pdf pp 164-165], the gradient-check remark of sec 5.2 [printed p 149 / pdf p 155], and eqs (5.29)-(5.32), (5.110), (5.123)-(5.128), (5.135)-(5.142) as cited, all read from the verified anchor sheet ref/mml/anchors-calc.md. Griewank and Walther, Evaluating Derivatives, 2nd ed, cited by name via mml sec 5.9 further reading. Expected values computed with sympy in the one-off playground/math-ch12/gen.py. Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch12`, 57 checks in chapter 12 of the math suite, probed on this machine 2026-09-21.
