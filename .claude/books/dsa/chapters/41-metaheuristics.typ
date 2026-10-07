#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= local search and metaheuristics

Exact methods buy guarantees and pay in scale: held-karp dies around 20
cities, branch and bound dies on the wrong instance shape. This
chapter is about what runs when the exact tool stops scaling, under
three house rules: keep the objective an integer, keep the search
reproducible from a seed, and know exactly what the guarantee became.
Every algorithm here is a seeded deterministic program with its
accepted moves, counters, and finals pinned by test, in all seven
languages, never a coin flip. The tour runs from hill climbing through
2-opt, simulated annealing with a rational Metropolis rule, tabu
search with a move-expiry memory, genetic algorithms, ant colony
optimization with integer pheromones, and restart portfolios, all on
small integer fixtures whose optima a brute force confirms in-test.

== local search: the frame

Three questions define every algorithm of the chapter. What is the
state, here a city permutation or a bitstring. What is the
neighborhood, the set of states one move away. What is the objective,
an integer energy to minimize. Given the three, the driver is one
paragraph of code: scan the neighborhood in a fixed order, take the
first strictly better move, restart the scan from the beginning after
every accept, stop when a full scan finds nothing. The accepted-move
sequence is then a pure function of the start state, the energy, and
the scan order, which is what makes the exact lane assertable byte for
byte across seven languages.

The stochastic algorithms later only swap the acceptance rule for
draws from a seeded generator, so the generator is the chapter's meter
stick and gets pinned first. The state x is an unsigned 64-bit
integer, each step computes x = (A x + C) mod 2^64 with
A = 6364136223846793005 and C = 1442695040888963407, and the output is
the high 32 bits u read as unsigned. A bounded draw below(k) =
floor(u k / 2^32) consumes exactly one u, so draw counts are meters
too. The constants split into exact 32-bit limbs, A = 0x5851F42D4C957F2D
and C = 0x14057B7EF767814F, and JavaScript carries the state as two
32-bit halves multiplied through 16-bit limbs, because a single
decimal literal past 2^53 is an inexact Number and BigInt stays out.
Java sits at the opposite pole: long is 64-bit and wraps mod 2^64, so
the multiply-add is one statement with zero limb work, and below(k)
masks both operands to 32 bits, multiplies into a long, and shifts
>>> 32.

The dry run: the seven-way contract pins identical literals and expected
values in every suite, the lcg vectors first, then the ring fixture
with its brute-force optimum.

+ Seed 1 opens 1817669548, 2187888307, 2784682393, 1644385741 and
  seed 42 opens 2440530669, 968358053: 24 integers, 8 per seed across
  seeds 1, 2, 42, asserted as the first test of each tree's
  localsearch file.
+ below(k) consumes exactly one output, the draw meter asserted in
  python, c\#, and javascript: lua pins below(65536) = u >> 16 as an
  identity, javascript and c\# recompute the fold against a bigint
  oracle across k, below(8) = u >> 29 is the derivation behind the
  tournament draws of section 8, and below(1) is always 0, asserted
  in python and c.
+ The ring F1 is 8 cities on a 4x4 grid perimeter under the Manhattan
  metric: d\[0\]\[4\] = 8, d\[3\]\[5\] = 4, and the identity tour 0..7
  costs 16.
+ The brute-force oracle over the 5040 permutations with city 0 fixed
  finds 16, c pinning the first winner as the ring order itself.
+ The swap neighborhood at n = 8 holds 28 moves, counted in c and
  python, and the insert neighborhood holds 56, n(n-1), counted in
  python.
+ The driver on the identity start accepts nothing, trace \[16\]
  pinned in python and go, and the start with positions 0 and 1
  exchanged repairs in one move, trace 20, 16, pinned in python.

The frame lands its first two numbers, 16 and 5040, and the listings
below ship the generator and the fixture in seven languages.

#listing("dsa/samples-c/src/Ch41/localsearch.c", first: 18, last: 38, caption: [c, the wrapped multiply-add generator, its high-32 output, the bounded draw, the ring matrix as data])
#listing("dsa/samples-go/ch41/localsearch.go", first: 9, last: 34, caption: [go, the generator struct, the high-32 next, the floor draw with its meter])
#listing("dsa/samples-java/src/Ch41/Localsearch.java", first: 18, last: 38, caption: [java, the multiply-add generator straight on long, the >>> 32 output, the bounded draw, the ring matrix as data])
#listing("dsa/samples/src/Ch41/Localsearch.cs", first: 9, last: 37, caption: [c\#, the lcg as one unchecked multiply-add over ulong, the bounded draw metered])
#listing("dsa/samples-js/src/ch41-localsearch.mjs", first: 10, last: 48, caption: [javascript, the state as 32-bit halves multiplied through 16-bit limbs, no bigint])
#listing("dsa/samples-py/src/Ch41/localsearch.py", first: 17, last: 37, caption: [python, the mask-and-multiply generator, the same 24 integers asserted first])
#listing("dsa/samples-lua/ch41_localsearch.lua", first: 8, last: 22, caption: [lua, integer arithmetic wrapping mod 2^64, the logical shift output])

The fixture family behind the section: the 24 witness integers, the
below laws with one draw per call, the pinned 8x8 matrix with its
perimeter rows, the 5040-permutation oracle returning 16 with the ring
order as first winner, the 28 and 56 neighborhood counts, and the two
driver checks, zero moves from the optimum and one swap repair from
\[1, 0, 2, 3, 4, 5, 6, 7\]. The convex hex F2 rides along as the
second fixture: 6 lattice points in convex position, Manhattan matrix
pinned the same way, optimum 20 achieved by the hull order 0..5 and
confirmed by a brute force over the 120 permutations.

#diagram([the ring f1 and the convex hex f2 with their optimal tours, 16 and 20, every edge a manhattan lattice distance], length: 13pt, {
  // left: the ring f1, 4x4 perimeter, tour 0..7 drawn heavy
  let m = (x, y) => (1.4 + x * 0.85, 1.0 + y * 0.85)
  let ring = ((0, 0), (0, 2), (0, 4), (2, 4), (4, 4), (4, 2), (4, 0), (2, 0))
  for k in range(8) {
    let a = ring.at(k)
    let b = ring.at(calc.rem(k + 1, 8))
    cdraw.line(m(a.at(0), a.at(1)), m(b.at(0), b.at(1)), stroke: 1.2pt + luma(40))
  }
  for (k, p) in ring.enumerate() {
    cdraw.circle(m(p.at(0), p.at(1)), radius: 0.3, fill: luma(235), stroke: luma(110))
    cdraw.content(m(p.at(0), p.at(1)), [#k], size: 7pt)
  }
  cdraw.content((2.0, 5.4), [f1, the ring: tour 0..7], size: 6.5pt)
  cdraw.content((2.0, 4.6), [cost 16, brute over 5040], size: 6pt)
  // right: the hex f2, hull walk 0..5 heavy
  let h = (x, y) => (11.4 + x * 0.7, 1.0 + y * 0.7)
  let hex = ((6, 2), (4, 4), (2, 4), (0, 2), (2, 0), (4, 0))
  for k in range(6) {
    let a = hex.at(k)
    let b = hex.at(calc.rem(k + 1, 6))
    cdraw.line(h(a.at(0), a.at(1)), h(b.at(0), b.at(1)), stroke: 1.2pt + luma(40))
  }
  for (k, p) in hex.enumerate() {
    cdraw.circle(h(p.at(0), p.at(1)), radius: 0.3, fill: luma(235), stroke: luma(110))
    cdraw.content(h(p.at(0), p.at(1)), [#k], size: 7pt)
  }
  cdraw.content((12.6, 4.9), [f2, the convex hex: hull walk 0..5], size: 6.5pt)
  cdraw.content((12.6, 4.1), [cost 20, brute over 120], size: 6pt)
  cdraw.content((18.9, 3.4), [convex position: the], size: 6pt)
  cdraw.content((18.9, 2.5), [hull walk is optimal], size: 6pt)
  cdraw.content((18.9, 1.6), [every distance an integer], size: 6pt)
  cdraw.content((18.9, 0.7), [manhattan over lattice], size: 6pt)
})

The generator has one more teaching point worth the ink: the multiplier
and increment are Knuth's recommendations for 64-bit congruential
generators, and every language reaches the same stream through its own
native wrap, unsigned overflow in C, unchecked ulong in C\#, uint64 in
Go, a mask in Python, integer arithmetic in Lua, and the limb dance in
JavaScript. When a fixture looks wrong in one tree, the 24 integers
say which side drifted.

#diagram([the seeded lcg as the chapter's meter stick: the wrapped multiply-add, the high 32 bits, the bounded fold, the limb spelling], length: 13pt, {
  let box = (x, y, w, title, sub) => {
    cdraw.rect((x, y), (x + w, y + 1.5), fill: luma(235), radius: 0.03)
    cdraw.content((x + w / 2, y + 1.02), title, size: 6.5pt)
    cdraw.content((x + w / 2, y + 0.42), sub, size: 6pt)
  }
  box(0.8, 7.0, 4.4, [state x], [unsigned 64 bit])
  box(7.4, 7.0, 6.6, [x' = (A x + C) mod 2^64], [wraps in place])
  box(16.2, 7.0, 4.2, [output u], [the high 32 bits])
  cdraw.line((5.2, 7.75), (7.4, 7.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.0, 7.75), (16.2, 7.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 5.9), [below(k) = floor(u k / 2^32), one u per call, draws never skip], size: 6pt)
  // witness strip: seed 1's first three outputs
  cdraw.content((0.9, 4.9), [seed 1 opens], size: 6pt)
  let vals = (1817669548, 2187888307, 2784682393)
  for (i, v) in vals.enumerate() {
    cdraw.rect((3.6 + i * 4.4, 4.4), (7.7 + i * 4.4, 5.4), fill: luma(240), radius: 0.03)
    cdraw.content((5.65 + i * 4.4, 4.9), [#v], size: 6pt)
  }
  cdraw.content((17.2, 4.9), [24 pinned in, 24 asserted out], size: 6pt)
  // the limb spelling and the js caveat
  cdraw.content((0.9, 3.3), [A = 0x5851F42D4C957F2D, C = 0x14057B7EF767814F], size: 6pt)
  cdraw.content((0.9, 2.4), [js keeps (xh, xl) halves, products through 16-bit limbs], size: 6pt)
  cdraw.content((0.9, 1.5), [one decimal literal past 2^53 is an inexact number], size: 6pt)
  cdraw.content((0.9, 0.6), [below(8) = u >> 29, below(65536) = u >> 16], size: 6pt)
})

== hill climbing and plateaus

First improvement takes the first strictly better neighbor in scan
order and restarts the scan after the accept, eager and cheap per
round. Best improvement scans the whole neighborhood and applies the
single minimum, first move winning ties, more work per round for a
steeper step. On the same energy surface the two rules walk different
accepted-move sequences, and both are deterministic: pin the scan
order, ascending position pairs (i, j) with i \< j, and the traces
follow. Strict descent has one blind spot, the plateau: an
equal-energy move is never taken, so a run that steps onto level
ground stops there even when the path across it leads down.

The dry run: the seven-way contract pins the two swap traces and the
plateau boundary, byte-identical energy sequences in all seven suites.

+ The swap climb from \[0, 4, 1, 5, 2, 6, 3, 7\] walks 44, 36, 32, 28,
  24, 20, 16 and finishes on the ring order 0..7, the optimum.
+ The swap climb from \[0, 2, 4, 6, 1, 3, 5, 7\] walks 32, 28 and stops
  at \[0, 6, 4, 2, 1, 3, 5, 7\], a different local optimum.
+ Best improvement from the first start walks 44, 28, 24, the trace
  pinned in python and lua with lua carrying the final tour, go,
  javascript, and c\# checking the strictly decreasing and swap-local
  invariants, c shipping no best variant: two full scans, two
  accepted moves, a third scan finds nothing.
+ At \[0, 1, 2, 4, 5, 6, 3, 7\], energy 24, no swap neighbor is
  strictly better and equal-energy swaps exist: the plateau the strict
  rule refuses to cross.
+ Every trace is strictly decreasing and every final tour is a fixed
  point, a second climb accepts nothing.

#table(
  columns: (auto, auto, 1.9fr, 1.6fr, auto),
  inset: 4pt,
  table.header([*rule*], [*start*], [*trace*], [*final*], [*verdict*]),
  [first], [\[0,4,1,5,2,6,3,7\]], [44, 36, 32, 28, 24, 20, 16], [\[0..7\]], [optimum],
  [first], [\[0,2,4,6,1,3,5,7\]], [32, 28], [\[0,6,4,2,1,3,5,7\]], [local],
  [best], [\[0,4,1,5,2,6,3,7\]], [44, 28, 24], [\[3,2,1,5,4,6,0,7\]], [local, py and lua],
)

The 16 against the 28 is the section's pair of numbers, and the
listings below run both rules in seven languages.

#listing("dsa/samples-c/src/Ch41/hill.c", first: 31, last: 62, caption: [c, the swap climb, ascending scan, restart after every accept])
#listing("dsa/samples-go/ch41/hill.go", first: 5, last: 36, caption: [go, the swap climb delegating to the shared driver, the best-improvement variant])
#listing("dsa/samples-java/src/Ch41/Hill.java", first: 34, last: 58, caption: [java, the swap climb, ascending scan, restart after every accept])
#listing("dsa/samples/src/Ch41/Hill.cs", first: 12, last: 39, caption: [c\#, first improvement with the swap applied and undone, the restart comment])
#listing("dsa/samples-js/src/ch41-hill.mjs", first: 9, last: 30, caption: [javascript, the eager loop, the first better neighbor wins])
#listing("dsa/samples-py/src/Ch41/hill.py", first: 36, last: 65, caption: [python, first and best improvement side by side])
#listing("dsa/samples-lua/ch41_hill.lua", first: 28, last: 50, caption: [lua, the same pair over 1-based positions])

The full fixture family: the two pinned swap traces with their finals,
the best-improvement trace 44, 28, 24 with the final tour carried by
lua, go, javascript, and c\# asserting the strictly decreasing trace
and the swap-local stop while c ships no best variant, the plateau
facts at energy 24, no strictly better swap and sideways swaps
present, and the fixed-point re-climb. The 24 plateau is not
incidental scenery: it is exactly where the 2-opt run of the next
section dies, and the tabu run of section 6 walks across it with
sideways moves.

#diagram([the two swap traces as staircases, the first run walking 44 down to 16, the second stopping at 28, the 24 plateau marked where sideways swaps live], length: 13pt, {
  let py = (v) => 1.1 + (v - 14) * 0.27
  let px = (i) => 1.6 + i * 2.2
  // the plateau band at 24
  cdraw.line((1.4, py(24)), (16.4, py(24)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((17.0, py(24)), [the 24 plateau], size: 6pt)
  // run 1: 44, 36, 32, 28, 24, 20, 16
  let r1 = (44, 36, 32, 28, 24, 20, 16)
  for i in range(r1.len() - 1) {
    cdraw.line((px(i), py(r1.at(i))), (px(i + 1), py(r1.at(i + 1))), stroke: 1.1pt + luma(40))
  }
  for (i, v) in r1.enumerate() {
    cdraw.circle((px(i), py(v)), radius: 0.13, fill: luma(205), stroke: luma(100))
    cdraw.content((px(i), py(v) + 0.55), [#v], size: 6pt)
  }
  cdraw.content((1.4, py(44) + 1.1), [run 1: first improvement, 6 swaps to the optimum], size: 6pt)
  // run 2 offset right: 32, 28
  let r2 = (32, 28)
  for i in range(r2.len() - 1) {
    cdraw.line((px(i) + 0.5, py(r2.at(i))), (px(i + 1) + 0.5, py(r2.at(i + 1))), stroke: 1.1pt + luma(40))
  }
  for (i, v) in r2.enumerate() {
    cdraw.circle((px(i) + 0.5, py(v)), radius: 0.13, fill: luma(235), stroke: luma(100))
    cdraw.content((px(i) + 0.5, py(v) - 0.6), [#v], size: 6pt)
  }
  cdraw.content((10.2, py(32) + 0.75), [run 2 stalls at 28], size: 6pt)
  cdraw.content((2.0, 0.4), [equal-energy swaps exist at 24, strict descent refuses them], size: 6pt)
  cdraw.content((11.4, 0.4), [2-opt from run 1's start stops at 24], size: 6pt)
})

== tsp neighborhoods: swap, insert, 2-opt

Three move sets dominate the traveling salesman literature. Swap
exchanges the cities at two positions, 28 moves at n = 8. Insert pulls
a city out and slides it into another position, 56 moves, n(n-1).
2-opt cuts the tour at two positions and reverses the segment between,
which is the move that keeps the object a tour while swapping exactly
two edges, and it shares the pair count with swap, 28. The economic
argument for 2-opt is incremental evaluation: reversing t\[i..j\]
removes the edges (a, b) and (c, e) and adds (a, c) and (b, e), where
a is the cyclic predecessor of position i, b the city at i, c the city
at j, and e the cyclic successor of j, four matrix lookups instead of
a full rescan. The whole-tour reversal maps the cycle onto itself and
prices at delta 0, an honest non-move.

The dry run: the seven-way contract pins the three 2-opt traces, one
accepted-move sequence per start, identical in all seven suites, and
the delta identity, priced against full recomputation in go,
javascript, python, lua, and c\#, with c asserting the stall half
alone, no candidate in negative delta at its stopped tour.

+ 2-opt from \[0, 4, 1, 5, 2, 6, 3, 7\] walks 44, 36, 32, 24 and stops
  at \[0, 1, 2, 4, 5, 6, 3, 7\], a local optimum 8 over the global 16.
+ The first move prices itself exactly: reversing positions 1..2
  removes edges (0, 4) of length 8 and (1, 5) of length 4, adds (0, 1)
  of length 2 and (4, 5) of length 2, delta -8, and 44 lands on 36.
+ 2-opt from \[0, 2, 4, 6, 1, 3, 5, 7\] walks 32, 28 and stops at
  \[6, 4, 2, 0, 1, 3, 5, 7\].
+ On the convex hex from \[0, 3, 1, 4, 2, 5\] the walk is 32, 28, 24,
  20, the hull order, and 20 is the brute-force optimum over 120.
+ The delta equals full recomputation on every one of the 28 candidates
  of the pinned start, and the delta-priced driver accepts the identical
  move sequence.
+ At the stalled 24 tour no candidate has negative delta: the stop is
  genuine, and the swap neighborhood from the same start reaches 16,
  while on the second start both neighborhoods stop at 28. Neither
  dominates.

The worked delta, -8 for the first accepted move, is the number to
remember, and the listings below ship the reversal, the delta, and the
descent in seven languages.

#listing("dsa/samples-c/src/Ch41/twoopt.c", first: 39, last: 81, caption: [c, the four-edge delta with the whole-cycle guard, the reversal in place, the descent])
#listing("dsa/samples-go/ch41/twoopt.go", first: 3, last: 28, caption: [go, the reversal move over the shared driver, the same four lookups])
#listing("dsa/samples-java/src/Ch41/Twoopt.java", first: 38, last: 76, caption: [java, the four-edge delta with the whole-cycle guard, the reversal in place, the descent])
#listing("dsa/samples/src/Ch41/TwoOpt.cs", first: 24, last: 60, caption: [c\#, the delta and the first-improvement loop over the pairs])
#listing("dsa/samples-js/src/ch41-twoopt.mjs", first: 19, last: 49, caption: [javascript, the delta function and the eager loop])
#listing("dsa/samples-py/src/Ch41/twoopt.py", first: 104, last: 146, caption: [python, the delta and the fast driver that accepts the identical sequence])
#listing("dsa/samples-lua/ch41_twoopt.lua", first: 44, last: 75, caption: [lua, the descent and the four-edge delta with cyclic wrap])

The fixture family: the ring traces 44, 36, 32, 24 and 32, 28 with
their final tours, the hex trace 32, 28, 24, 20 onto the hull order,
the hex matrix reproduced from its points before use, the brute
optima 16 and 20, the delta identity over all candidates, and the
cross-neighborhood verdict, swaps reach 16 where 2-opt holds 24, both
hold 28 on the second start. For points in convex position the hull
walk is the optimal tour, the shoelace fact, and through Manhattan
edges its length is exactly computable, which is why F2 is a fair
witness for any tour builder.

#diagram([the 2-opt move on the pinned start: positions 1..2 reversed, edges (0,4) and (1,5) leaving dashed, edges (0,1) and (4,5) entering heavy, delta -8], length: 13pt, {
  let t = (0, 4, 1, 5, 2, 6, 3, 7)
  let cx = (i) => 1.6 + i * 2.3
  // the tour as a row of cells, segment 1..2 shaded
  for i in range(8) {
    let hot = i == 1 or i == 2
    cdraw.rect((cx(i), 6.1), (cx(i) + 1.9, 7.0), fill: if hot { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((cx(i) + 0.95, 6.55), [#t.at(i)], size: 7pt)
    cdraw.content((cx(i) + 0.95, 5.7), [pos #i], size: 5.5pt)
  }
  // leaving edges above: (0,4) and (1,5)
  cdraw.line((cx(0) + 0.95, 7.0), (cx(1) + 0.95, 8.3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((cx(1) + 0.95, 7.0), (cx(0) + 0.95, 8.3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((cx(0) + 0.95, 8.7), [leaves: d(0,4) = 8], size: 6pt)
  cdraw.line((cx(2) + 0.95, 7.0), (cx(3) + 0.95, 8.3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((cx(3) + 0.95, 7.0), (cx(2) + 0.95, 8.3), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((cx(2) + 0.6, 8.7), [leaves: d(1,5) = 4], size: 6pt)
  // entering edges below the row
  cdraw.line((cx(0) + 0.95, 6.1), (cx(2) + 0.95, 4.8), stroke: 1.2pt + luma(40))
  cdraw.line((cx(1) + 0.95, 6.1), (cx(3) + 0.95, 4.8), stroke: 1.2pt + luma(40))
  cdraw.content((cx(0) + 0.2, 4.4), [enters: d(0,1) = 2], size: 6pt)
  cdraw.content((cx(2) + 0.3, 4.4), [enters: d(4,5) = 2], size: 6pt)
  // the delta line
  cdraw.content((2.0, 3.3), [delta = (2 + 2) - (8 + 4) = -8, energy 44 -> 36], size: 6.5pt)
  cdraw.content((2.0, 2.4), [the segment reversal is an edge swap], size: 6pt)
  cdraw.content((2.0, 1.5), [inner edges keep their lengths], size: 6pt)
  cdraw.content((2.0, 0.6), [whole-tour reversal: delta 0], size: 6pt)
})

== simulated annealing and the metropolis rule

Strict descent dies on the first plateau. The Metropolis rule lets the
walk climb: a downhill or level move is always taken, an uphill move
with energy increase delta is taken with a probability that decreases
in delta and relaxes as the temperature T falls. The textbook form is
exp(-delta / T), a floating transcendental, and this chapter makes a
stated engineering substitution: accept with probability T / (T +
delta), the rational sibling with the same decreasing shape in delta,
realized exactly as the integer test below(T + delta) \< T. One draw,
integer arithmetic, and zero cross-language libm divergence, so all
seven suites assert the same accept and reject counts. The draw happens
only on the uphill branch, which keeps the meter honest.

The landscape is F4, a 12-bit QUBO: energy(x) = c + sum a_i x_i + sum
b_ij x_i x_j with c = -7, the coefficient vector 3, -4, 2, 5, -6, 1,
-2, 4, 3, -5, 2, -3, and b = -6 on exactly 14 index pairs. Every
coefficient is an integer, so all 4096 states price exactly, and the
brute-force oracle runs in-test. The contract: 200 iterations, start
all-zero, T_i = max(1, 64 >> (i / 25)), move = flip bit below(12).

The dry run: the seven-way contract pins the three counter triples and
the finals, exact equality, with the best asserted against the
brute-force optimum at ratio 1.0.

+ Brute force over the 4096 states finds the minimum -91 at
  x = 4095, all bits on, and prices the all-zero state at -7.
+ Seed 1: 106 accepted, 94 rejected, 47 of the accepts uphill, best
  -91, final state 4095.
+ Seed 2: 106, 94, 50, best -91, final state 4095.
+ Seed 42: 123, 77, 58, best -91, final state 4094, one bit short of
  the optimum on the final state while the best bank holds 4095's
  energy.
+ accepted + rejected = 200 in every run: every iteration lands on one
  side of the rule.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*seed*], [*accepted*], [*rejected*], [*uphill*], [*best*], [*final x*]),
  [1], [106], [94], [47], [-91], [4095],
  [2], [106], [94], [50], [-91], [4095],
  [42], [123], [77], [58], [-91], [4094],
)

The -91 on every seed is the pinned landing, and the listings below
run the rule in seven languages.

#listing("dsa/samples-c/src/Ch41/anneal.c", first: 57, last: 81, caption: [c, the schedule, the bit flip, downhill and the rational uphill test])
#listing("dsa/samples-go/ch41/anneal.go", first: 73, last: 96, caption: [go, the shared engine through the uphill accept])
#listing("dsa/samples-java/src/Ch41/Anneal.java", first: 56, last: 80, caption: [java, the schedule, the bit flip, downhill and the rational uphill test])
#listing("dsa/samples/src/Ch41/Anneal.cs", first: 44, last: 81, caption: [c\#, the same run, the uphill draw on the else branch])
#listing("dsa/samples-js/src/ch41-anneal.mjs", first: 32, last: 60, caption: [javascript, coolT and the run loop, the integer rule])
#listing("dsa/samples-py/src/Ch41/anneal.py", first: 70, last: 94, caption: [python, the metropolis comment and the sa driver])
#listing("dsa/samples-lua/ch41_anneal.lua", first: 50, last: 77, caption: [lua, the same loop, max and floor shifts by hand])

The fixture family: the brute oracle, -91 at 4095 and -7 at 0, the
three counter rows with their finals, the 200 accounting identity, and
the tolerance lane stated as ratio 1.0 against the oracle. The compact
prose treatment in #xref-to("dsa", "numerical") keeps the exp form
and points here for the integer rule and the pinned runs.

#diagram([the rational metropolis rule T / (T + delta) at four temperatures over delta up to 12, high T accepting most climbs, T = 1 nearly greedy], length: 13pt, {
  let px = (d) => 1.7 + d * 1.02
  let py = (p) => 0.9 + p * 6.1
  // axes
  cdraw.line((px(0), py(0)), (px(12.6), py(0)), stroke: luma(120), mark: (end: ">"))
  cdraw.line((px(0), py(0)), (px(0), py(1.08)), stroke: luma(120), mark: (end: ">"))
  for d in range(13) {
    cdraw.content((px(d), 0.35), [#d], size: 5.5pt)
  }
  cdraw.content((px(12.6), -0.35), [delta], size: 6pt)
  cdraw.content((0.7, py(1.0)), [1], size: 5.5pt)
  // the four curves
  let curve = (T, paint) => {
    let sub = ()
    let d = 0.0
    while d < 12.01 {
      sub.push((px(d), py(T / (T + d))))
      d += 0.25
    }
    cdraw.line(..sub, stroke: paint)
  }
  curve(64, luma(170))
  curve(16, luma(140))
  curve(4, luma(110))
  curve(1, luma(50))
  let seg = (y, paint, txt) => {
    cdraw.line((15.6, y), (16.3, y), stroke: paint)
    cdraw.content((16.55, y), txt, size: 6pt)
  }
  seg(7.0, luma(170), [T = 64])
  seg(5.6, luma(140), [T = 16])
  seg(4.2, luma(110), [T = 4])
  seg(1.6, luma(50), [T = 1])
  cdraw.content((15.6, 7.9), [accept iff below(T + delta) \< T], size: 6pt)
  cdraw.content((15.6, 8.7), [the integer sibling of exp(-delta / T)], size: 6pt)
  cdraw.content((8.0, -0.35), [same decreasing shape, no libm anywhere], size: 6pt)
})

== cooling schedules, restarts, reheating

The temperature program is where annealing earns its tuning. The
chapter's schedule is geometric and integral: T_i = max(1, T0 >>
(i / 25)) halves every 25 iterations, so 200 iterations from T0 = 64
read 64, 32, 16, 8, 4, 2, then 1 forever, a ladder with no float in
it. Restarting and reheating answer the failure mode where the walk
freezes in a bad basin: after 20 consecutive non-accepted moves the
state resets to the best-so-far, T0 doubles, and the cooling clock
restarts, so T indexes iterations since the last reheat. The reheat
iteration itself does not advance the clock, one off-by-one that
changes counters and is pinned on purpose.

#callout("pitfall", "the clock indexes reheats, not iterations", [
  After a reheat the schedule does not resume at the global iteration
  count. `s` restarts at 0, so iteration 182 of the seed 1 run reads
  `T = 128 >> (0 / 25) = 128`, a full-hot temperature late in the run.
  Forgetting the reset, or advancing `s` on the reheat iteration
  itself, shifts every later draw and both counter columns drift. The
  pinned reheat logs exist to catch exactly this.
])

The dry run: the seven-way contract pins the three reheat runs with
their logs, counters exact in all seven suites, and the ladder values,
asserted in python and lua.

+ The ladder reads 64 through iteration 24, 32 at 25, and 1 from
  iteration 150 on: 64, 32, 16, 8, 4, 2, 1, 1 sampled every 25.
+ Seed 1: 124 accepted, 76 rejected, 59 uphill, 1 reheat at iteration
  181 doubling T0 to 128, best -91, final state 2614.
+ Seed 2: 111, 89, 54, 1 reheat at 193 to T0 128, best -91, final
  state 2030.
+ Seed 42: 123, 77, 58, 0 reheats, best -91, final state 4094: the
  accept rate never dies 20 draws in a row, itself a teaching row.
+ Seed 42 never reheats, so its plain and reheat drivers agree counter
  for counter.

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*seed*], [*acc*], [*rej*], [*uphill*], [*reheats*], [*best*], [*reheat log*]),
  [1], [124], [76], [59], [1], [-91], [ (181, 128) ],
  [2], [111], [89], [54], [1], [-91], [ (193, 128) ],
  [42], [123], [77], [58], [0], [-91], [ ],
)

The 181 and the 193 are the section's pinned pair, and the listings
below ship the reheat contract in seven languages.

#listing("dsa/samples-c/src/Ch41/anneal.c", first: 82, last: 107, caption: [c, the rejection branch, the streak, the reheat with its log, the clock])
#listing("dsa/samples-go/ch41/anneal.go", first: 98, last: 118, caption: [go, the reject branch and the reheat event recorded])
#listing("dsa/samples-java/src/Ch41/Anneal.java", first: 81, last: 106, caption: [java, the rejection branch, the streak, the reheat with its log, the clock and best bank])
#listing("dsa/samples/src/Ch41/Anneal.cs", first: 99, last: 145, caption: [c\#, the reheat driver, reset to best, double T0, restart the clock])
#listing("dsa/samples-js/src/ch41-anneal.mjs", first: 62, last: 111, caption: [javascript, saReheat whole, the log array and the clock reset])
#listing("dsa/samples-py/src/Ch41/anneal.py", first: 113, last: 152, caption: [python, reheat from best with the pinned tuple returned])
#listing("dsa/samples-lua/ch41_anneal.lua", first: 79, last: 124, caption: [lua, the same loop, the reheated flag keeping the clock honest])

The fixture family: the ladder values, the three reheat rows with
counter triples, best, final state, and log, the 200 identity again,
and the seed 42 agreement between drivers. A reheat is a restart with
a memory: the state comes back from the bank, the temperature comes
back from the schedule, and the walk tries a second descent from the
best it owns.

#diagram([the cooling ladder halving every 25 iterations, the seed 1 reheat at 181 and seed 2 at 193 jumping back to T0 128, seed 42 never reheating], length: 13pt, {
  let x = (i) => 1.4 + i * 0.087
  let y = (t) => 0.8 + t * 0.052
  // the base ladder
  let rungs = ((0, 64), (25, 32), (50, 16), (75, 8), (100, 4), (125, 2), (150, 1))
  for (idx, step) in rungs.enumerate() {
    let (start, t) = step
    let stop = if start == 150 { 181 } else { start + 25 }
    cdraw.line((x(start), y(t)), (x(stop), y(t)), stroke: 1.1pt + luma(40))
    if start < 150 {
      let (_, nt) = rungs.at(idx + 1)
      cdraw.line((x(stop), y(t)), (x(stop), y(nt)), stroke: luma(120))
    }
    cdraw.content((x(start) + 0.45, y(t) + 0.42), [#t], size: 6pt)
  }
  // the tail at T = 1 before the reheat markers, then the reheat plateaus
  cdraw.line((x(181), y(1)), (x(199), y(1)), stroke: 1.1pt + luma(40))
  cdraw.line((x(181), y(1)), (x(181), y(128)), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((x(181), y(128)), (x(199), y(128)), stroke: 1.1pt + luma(40))
  cdraw.line((x(193), y(1)), (x(193), y(128)), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((x(193), y(128)), (x(199), y(128)), stroke: 1.1pt + luma(140))
  cdraw.content((x(60), 8.4), [T = max(1, T0 >> (i / 25))], size: 6.5pt)
  cdraw.content((x(150), 8.05), [seed 1: reheat at 181, T0 128], size: 6pt)
  cdraw.content((x(140), 2.6), [seed 42 never reheats], size: 6pt)
  cdraw.content((x(181), -0.4), [181], size: 5.5pt)
  cdraw.content((x(193), -0.4), [193], size: 5.5pt)
  cdraw.content((x(120), 5.3), [seed 2 reheats at 193, seed 1 at 181], size: 6pt)
  cdraw.content((1.2, 0.2), [after a reheat the clock restarts: T indexes iterations since the last reheat], size: 6pt)
})

== tabu search and tenure

Hill climbing's memory is one state. Tabu search adds a recency
memory over moves: a move taken at iteration it is banned for tenure
iterations, realized as an expiry stamp it + 3 that stays ahead of the
clock, and the ban is what legalizes sideways and uphill moves, the
thing strict descent refused. Each iteration picks the minimum-length
candidate scanning (i, j) ascending with the first move winning ties,
applies it, and stamps it tabu. The run can therefore walk across
plateaus and climb, because the moves it just used are the ones it
cannot immediately reuse.

The dry run: the seven-way contract pins the 12-iteration log move by
move and energy by energy, identical in all seven suites.

+ Iterations 0, 1, 2 improve 44 to 36 to 28 to 24 with moves (1, 2),
  (2, 4), (3, 4).
+ Iterations 3 through 5 hold 24 with sideways moves (0, 5), (0, 6),
  (0, 1) while earlier bans expire: this is the plateau crossing.
+ Iteration 6 lifts to 20 with (1, 2), legal again after its ban from
  iteration 0 expired, and iteration 7 reaches 16 with (2, 3), the
  optimum.
+ Iterations 8 through 11 hold 16 with (0, 6), (0, 7), (1, 7), (0, 6),
  and the run ends on the ring order.
+ The best bank reads 16 where plain 2-opt from the same start died
  at 24: the tenure memory carried the search off the plateau.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*iteration*], [*move*], [*energy*], [*tabu until*]),
  [0], [\[1,2\]], [36], [3],
  [1], [\[2,4\]], [28], [4],
  [2], [\[3,4\]], [24], [5],
  [3], [\[0,5\]], [24], [6],
  [4], [\[0,6\]], [24], [7],
  [5], [\[0,1\]], [24], [8],
  [6], [\[1,2\]], [20], [9],
  [7], [\[2,3\]], [16], [10],
  [8], [\[0,6\]], [16], [11],
  [9], [\[0,7\]], [16], [12],
  [10], [\[1,7\]], [16], [13],
  [11], [\[0,6\]], [16], [14],
)

The 16 at iteration 7 is the pinned landing, and the listings below
run the memory in seven languages.

#listing("dsa/samples-c/src/Ch41/tabu.c", first: 79, last: 117, caption: [c, the pick, the stall case, the ban store with expiry, the log])
#listing("dsa/samples-go/ch41/tabu.go", first: 41, last: 87, caption: [go, the whole engine, expiry map, first-wins ties])
#listing("dsa/samples-java/src/Ch41/Tabu.java", first: 87, last: 111, caption: [java, the stall case, the move commit, the ban store pruned by expiry and extended, the log])
#listing("dsa/samples/src/Ch41/Tabu.cs", first: 37, last: 66, caption: [c\#, the scan with the expiry dictionary, aspiration inside])
#listing("dsa/samples-js/src/ch41-tabu.mjs", first: 13, last: 60, caption: [javascript, the core with the expiry list pruned on commit])
#listing("dsa/samples-py/src/Ch41/tabu.py", first: 35, last: 70, caption: [python, the engine with frozenset moves and the log])
#listing("dsa/samples-lua/ch41_tabu.lua", first: 41, last: 83, caption: [lua, the same engine over string-keyed expiry])

The fixture family: the full 12-row log above, tenure 3 with the
expiry column, best 16 with the final tour the ring order, and the
contrast row, plain 2-opt stalls at 24 on the identical start. The
memory is small, a dictionary of move pairs, and it is the whole
difference between dead at 24 and done at 16.

#diagram([the tenure timeline: each accepted move bans itself for 3 iterations, lanes per move, the plateau crossing and the 16 arrival marked], length: 13pt, {
  let x = (it) => 3.2 + it * 1.28
  // vertical gridlines per iteration
  for it in range(13) {
    cdraw.line((x(it), 0.9), (x(it), 8.5), stroke: luma(235))
    if it < 12 {
      cdraw.content((x(it) + 0.62, 0.55), [#it], size: 5.5pt)
    }
  }
  // lanes: move -> iterations taken
  let lanes = (
    ((1, 2), (0, 6)), ((2, 4), (1,)), ((3, 4), (2,)), ((0, 5), (3,)),
    ((0, 6), (4, 8, 11)), ((0, 1), (5,)), ((2, 3), (7,)), ((0, 7), (9,)),
    ((1, 7), (10,)),
  )
  for (l, lane) in lanes.enumerate() {
    let (mv, takes) = lane
    let y = 8.2 - l * 0.74
    cdraw.content((0.4, y), [move \[#mv.at(0),#mv.at(1)\]], size: 5.5pt)
    for it in takes {
      cdraw.rect((x(it) + 0.14, y - 0.2), (x(it + 3), y + 0.2), fill: luma(210), radius: 0.02)
      cdraw.line((x(it), y), (x(it) + 0.14, y), stroke: luma(100))
      cdraw.circle((x(it), y), radius: 0.09, fill: luma(60))
    }
  }
  // energies along the bottom
  let energies = (36, 28, 24, 24, 24, 24, 20, 16, 16, 16, 16, 16)
  for (it, e) in energies.enumerate() {
    cdraw.content((x(it) + 0.62, -0.15), [#e], size: 5.5pt)
  }
  cdraw.content((0.4, -0.15), [energy], size: 5.5pt)
  cdraw.content((8.0, 9.3), [a bar spans the banned iterations, the dot marks the take], size: 6pt)
  cdraw.content((x(3) + 0.3, 2.2), [sideways holds 24], size: 5.5pt)
  cdraw.content((x(7) + 0.1, 1.4), [16 at it 7], size: 5.5pt)
})

== aspiration and candidate lists

Two refinements polish the memory. Aspiration lifts a ban when the
tabu candidate beats the global best, on the theory that a banned move
good enough to improve the incumbent should never be blocked by
bookkeeping. Candidate lists shrink the scan: instead of all 28 pairs,
restrict each iteration to the 2-opt moves (i, j) with i == p or
j == p, where p is the current position of city 0, n - 1 = 7 candidates
per iteration, a quarter of the work.

The pinned logs keep both honest. The base run's global best reaches
the optimum 16 at iteration 7, and no later tabu candidate can beat
it, so the aspiration branch never fires: the machinery stays in the
code and every suite asserts lifts == 0 as a fact about this instance,
a dormant branch is not a dead branch. The candidate list pays for its
speed the other way.

The dry run: the seven-way contract pins the candidate-list log, its
best tour, its end state, and the zero lift counts.

+ lifts == 0 on both the full-scan and the candidate-list runs,
  asserted with the lift branch present in the code.
+ The candidate-list log reads energies 44, 36, 32, 32, 32, 28, 28,
  24, 24, 24, 24, 28 over moves \[0,1\], \[1,3\], \[0,3\], \[0,4\],
  \[1,4\], \[0,1\], \[0,5\], \[1,5\], \[1,6\], \[0,6\], \[0,5\],
  \[1,5\].
+ The best tour banks 24 as \[6, 0, 2, 1, 5, 4, 3, 7\].
+ The end state after the 12th move is \[3, 0, 2, 1, 5, 4, 6, 7\] at
  energy 28: the run leaves its best behind, best tour and end state
  are different objects.
+ The restricted scan never reaches the 16 the full scan found: 7
  candidates per iteration buy speed and lose the optimum.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*iteration*], [*move*], [*energy*]),
  [0], [\[0,1\]], [44],
  [1], [\[1,3\]], [36],
  [2], [\[0,3\]], [32],
  [3], [\[0,4\]], [32],
  [4], [\[1,4\]], [32],
  [5], [\[0,1\]], [28],
  [6], [\[0,5\]], [28],
  [7], [\[1,5\]], [24],
  [8], [\[1,6\]], [24],
  [9], [\[0,6\]], [24],
  [10], [\[0,5\]], [24],
  [11], [\[1,5\]], [28],
)

The 24 against the full scan's 16 is the closing contrast, and the
listings below ship both refinements in seven languages.

#listing("dsa/samples-c/src/Ch41/tabu.c", first: 51, last: 78, caption: [c, the city 0 position guard, the candidate filter, the ban test with aspiration and the lift counter])
#listing("dsa/samples-go/ch41/tabu.go", first: 23, last: 39, caption: [go, the full scan and the candidate-list wrappers])
#listing("dsa/samples-java/src/Ch41/Tabu.java", first: 49, last: 77, caption: [java, the city 0 position guard, the candidate filter, the ban test with aspiration and the lift counter])
#listing("dsa/samples/src/Ch41/Tabu.cs", first: 14, last: 34, caption: [c\#, the two entry points and the expiry dictionary])
#listing("dsa/samples-js/src/ch41-tabu.mjs", first: 22, last: 42, caption: [javascript, the position guard, the expiry test, the aspiration line])
#listing("dsa/samples-py/src/Ch41/tabu.py", first: 46, last: 61, caption: [python, the candidate guard and the aspiration inside the scan])
#listing("dsa/samples-lua/ch41_tabu.lua", first: 49, last: 71, caption: [lua, the cand_only filter with the lift counter])

The fixture family: the 12-row candidate log, best 24 with its tour,
end state \[3, 0, 2, 1, 5, 4, 6, 7\] at 28, the zero lift counts on
both runs, and the headline trade, 7 candidates against 28 bought a
local optimum 8 worse. Best tour and end state diverge here, which is
why the result type carries both.

== genetic algorithms: encoding and selection

A genetic algorithm searches a population instead of a point. The
encoding decides everything downstream: a bitstring for the knapsack,
where bit i means item i is packed, or a permutation for the tour,
where crossover must respect the one-city-each shape. Selection is the
pressure knob. Roulette is fitness-proportional: sort the population,
sum the fitness, draw one below(total), walk the cumulative sums until
the draw is passed. Tournament is simpler and stiffer: two below(n)
draws, the larger index wins, no sorting and no floats, and the pinned
mini-run shows the mechanism, seed 1 draws (3, 4) and keeps 4, seed 2
draws (6, 7) and keeps 7, seed 42 draws (4, 1) and keeps 4, each draw
being below(8) = u >> 29.

The fixture is F5: 10 items with weights 7, 4, 9, 3, 5, 8, 2, 6, 10, 3
and values 12, 6, 18, 5, 10, 17, 3, 11, 20, 7 against capacity 18. The
in-test oracle is the chapter 17 dynamic program, optimum 37, and the
brute force agrees, best bitstring 288, items 5 and 8, weights 8 + 10
and values 17 + 20.

The dry run: the seven-way contract pins the oracle, the tournament
draws, and the three run rows with exact counters.

+ The dynamic program lands 37 at capacity 18 and the brute force over
  all 1024 bitstrings lands 37 at x = 288.
+ Tournament pins: seed 1 (3, 4) to 4, seed 2 (6, 7) to 7, seed 42
  (4, 1) to 4.
+ Seed 1: best fitness 31, 140 crossovers, 57 mutation flips, best
  individual 266.
+ Seed 2: best fitness 0, 140 crossovers, 49 flips.
+ Seed 42: best fitness 34, 140 crossovers, 52 flips, best individual
  22.
+ 140 = 7 children x 20 generations, exact on every seed, and seeds 1
  and 42 stay within ratio 0.75 of the optimum while seed 2 asserts
  its 0.

#table(
  columns: (auto, auto, auto, auto, auto, 1.5fr),
  inset: 4pt,
  table.header([*seed*], [*best fitness*], [*crossovers*], [*flips*], [*best x*], [*verdict*]),
  [1], [31], [140], [57], [266], [ratio 31/37, within 0.75],
  [2], [0], [140], [49], [ ], [converged onto infeasible],
  [42], [34], [140], [52], [22], [ratio 34/37, within 0.75],
)

The cautionary row is seed 2, and the listings below run the whole
contract in seven languages.

#listing("dsa/samples-c/src/Ch41/ga.c", first: 91, last: 132, caption: [c, the run whole: seeded population, insertion sort, roulette walks, children])
#listing("dsa/samples-go/ch41/ga.go", first: 85, last: 120, caption: [go, the metered run, the scored sort, two draws per child])
#listing("dsa/samples-java/src/Ch41/Ga.java", first: 67, last: 118, caption: [java, the run whole: seeded population, insertion sort with the tie chain, roulette walks, children])
#listing("dsa/samples/src/Ch41/Ga.cs", first: 47, last: 96, caption: [c\#, the run body with the roulette closure over the scored array])
#listing("dsa/samples-js/src/ch41-ga.mjs", first: 34, last: 82, caption: [javascript, the run with the stable scored sort and the cumulative pick])
#listing("dsa/samples-py/src/Ch41/ga.py", first: 64, last: 95, caption: [python, the generator, elitism 1, the pick closure, the child loop])
#listing("dsa/samples-lua/ch41_ga.lua", first: 49, last: 100, caption: [lua, the contract comment, the comparator, pick, and children])

#callout("warning", "selection pressure can kill the run", [
  Seed 2's population converged onto individuals that overflow the
  capacity, every fitness 0, and roulette over a total of 0 returns
  the last individual of the sorted array: the population is frozen
  and mutation at 4 percent per bit never digs all 8 individuals out
  within 20 generations. The assert states the 0. The honest readings
  are a smaller mutation grid, a repair operator, or tournament
  selection whose pressure does not depend on fitness sums.
])

The fixture family: the oracle pair 37 and 288, the three tournament
pins, the three run rows with 140 crossovers exact and flip counts 57,
49, 52, the ratio lane at 0.75, and the seed 2 anatomy, all 8
final individuals at fitness 0. Flip counts sit near their
expectation, 4 percent of 1400 mutation draws is 56, and the three
seeds land 57, 49, and 52 around it.

#diagram([the generation pipeline: scored sort, elite kept, two draws, the mask crossover, per-bit mutation, and the pinned tournament mini-run], length: 13pt, {
  // top: the pipeline
  let stage = (x, w, title, sub) => {
    cdraw.rect((x, 7.6), (x + w, 9.0), fill: luma(235), radius: 0.03)
    cdraw.content((x + w / 2, 8.5), title, size: 6.5pt)
    cdraw.content((x + w / 2, 7.95), sub, size: 6pt)
  }
  stage(0.8, 3.0, [population 8], [below(1024) draws])
  stage(4.8, 3.2, [scored sort], [elite kept, tie rule])
  stage(9.0, 3.2, [two draws], [roulette or tournament])
  stage(13.2, 3.0, [crossover], [cut = below(9) + 1])
  stage(17.2, 3.2, [mutation], [below(100) \< 4 flips])
  cdraw.line((3.8, 8.3), (4.8, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.0, 8.3), (9.0, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.2, 8.3), (13.2, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 8.3), (17.2, 8.3), stroke: luma(100), mark: (end: ">"))
  // left bottom: the mask strip, cut c = 4 on an example parent
  cdraw.content((1.6, 6.3), [child = (p1 & (2^c - 1)) | (p2 & ~mask), c = 4 on an example], size: 6pt)
  let b1 = (0, 1, 1, 0, 1, 0, 0, 1, 1, 0)
  for i in range(1, 11) {
    let hot = i < 5
    cdraw.rect((1.4 + i * 1.15, 4.7), (2.5 + i * 1.15, 5.6), fill: if hot { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((1.95 + i * 1.15, 5.15), [#b1.at(i - 1)], size: 6pt)
    cdraw.content((1.95 + i * 1.15, 4.35), [#(i - 1)], size: 5pt)
  }
  cdraw.content((1.4, 5.15), [p1], size: 6pt)
  cdraw.content((5.6, 3.7), [shaded: low c bits of parent 1], size: 6pt)
  cdraw.content((5.6, 2.9), [plain: high bits of parent 2], size: 6pt)
  // right bottom: the tournament pins
  cdraw.content((12.0, 6.3), [tournament: two below(8) draws, larger wins], size: 6pt)
  let rows = (([seed 1], [3, 4], [4]), ([seed 2], [6, 7], [7]), ([seed 42], [4, 1], [4]))
  for (r, row) in rows.enumerate() {
    let (sd, dr, win) = row
    let y = 5.4 - r * 0.95
    cdraw.content((12.2, y), sd, size: 6pt)
    cdraw.content((14.4, y), [draws (#dr)], size: 6pt)
    cdraw.content((17.6, y), [winner #win], size: 6pt)
  }
  cdraw.content((12.2, 2.2), [below(8) = u >> 29, one output per draw], size: 6pt)
  cdraw.content((12.2, 1.3), [140 crossovers = 7 children x 20 generations], size: 6pt)
})

== crossover, mutation, ox

On bitstrings the operators are masks. Single-point crossover draws a
cut below(9) + 1 between 1 and 9 and builds the child as the low cut
bits of parent 1 glued to the high bits of parent 2, one mask and one
or per child. Mutation walks the 10 bits in ascending order, draws
below(100) for each, and flips when the draw lands under 4, a 4
percent per-bit rate realized without a float. Elitism carries the
best individual of the sorted population forward untouched, 7 children
fill the rest, which is why the crossover meter reads exactly 140.

Permutations cannot be masked, a slice of one parent pasted into the
other duplicates cities. Order crossover, OX, is the repair: the child
keeps positions cut1..cut2-1 of parent 1, then fills the remaining
positions cycling from cut2 with the genes of parent 2 in order,
skipping the kept ones. It is deterministic, no rng anywhere, and both
worked examples pin.

The dry run: the seven-way contract pins the two OX children and the
exact mutation ledger.

+ The worked pair: ox(\[1, 2, 3, 4, 5\], \[3, 1, 2, 5, 4\], 1, 3)
  returns \[4, 2, 3, 1, 5\]: positions 1..2 keep \[2, 3\], the fill list
  is parent 2's genes minus the kept pair, 1, 5, 4, and the slots
  cycle 3, 4, 0, landing 1, 5, 4 into positions 3, 4, 0.
+ The second pin: ox(\[5, 4, 3, 2, 1\], \[2, 1, 4, 3, 5\], 1, 4)
  returns \[5, 4, 3, 2, 1\], the case where OX reproduces parent 1
  exactly, 4 of 5 genes kept and the fill order cooperating.
+ The child is a permutation in both cases, checked, and the flip
  ledger reads 57, 49, 52 against the expectation of 56, 4 percent of
  the 1400 mutation draws of a run.

The fill cycling is the whole algorithm, and the listings below ship
OX in seven languages.

#listing("dsa/samples-c/src/Ch41/ga.c", first: 134, last: 151, caption: [c, order crossover keeping the cut segment, the two-phase cycling fill])
#listing("dsa/samples-go/ch41/ga.go", first: 133, last: 161, caption: [go, the kept map and the wrapped slot walk])
#listing("dsa/samples-java/src/Ch41/Ga.java", first: 122, last: 137, caption: [java, order crossover keeping the cut segment, the two-phase cycling fill])
#listing("dsa/samples/src/Ch41/Ga.cs", first: 113, last: 137, caption: [c\#, ox with the kept set and the fill list])
#listing("dsa/samples-js/src/ch41-ga.mjs", first: 84, last: 98, caption: [javascript, ox through filter and the cycling slot order])
#listing("dsa/samples-py/src/Ch41/ga.py", first: 141, last: 159, caption: [python, the fill list and the wrapped slot order, both pins beside it])
#listing("dsa/samples-lua/ch41_ga.lua", first: 102, last: 122, caption: [lua, the 1-based cut arithmetic mirroring the contract])

The fixture family: the two OX children, the permutation checks, the
140 crossover identity, and the flip counts with their expectation.
The mask operators and OX are the two encodings' halves of the same
idea, mix two parents without leaving the representable set, a
bitstring any bitstring, a permutation any permutation.

#diagram([the ox worked example: positions 1..2 kept from parent 1, the fill list 1, 5, 4 cycling into slots 3, 4, 0, the child assembled], length: 13pt, {
  let row = (y, label, cells, hot) => {
    cdraw.content((0.4, y), label, size: 6pt)
    for (i, v) in cells.enumerate() {
      let kept = i in hot
      cdraw.rect((2.6 + i * 1.7, y - 0.45), (4.1 + i * 1.7, y + 0.45), fill: if kept { luma(205) } else { luma(238) }, radius: 0.02)
      cdraw.content((3.35 + i * 1.7, y), [#v], size: 7pt)
      cdraw.content((3.35 + i * 1.7, y - 0.95), [#i], size: 5.5pt)
    }
  }
  row(8.2, [parent 1], (1, 2, 3, 4, 5), (1, 2))
  row(6.4, [parent 2], (3, 1, 2, 5, 4), ())
  row(2.4, [child], (4, 2, 3, 1, 5), (1, 2))
  // the fill list between parent 2 and child
  cdraw.content((13.6, 6.4), [fill = 1, 5, 4], size: 6.5pt)
  cdraw.content((13.6, 5.5), [p2 minus the kept pair], size: 6pt)
  cdraw.content((13.6, 4.6), [slots cycle 3, 4, 0], size: 6pt)
  // arrows: fill 1 -> slot 3, fill 5 -> slot 4, fill 4 -> slot 0
  let cellx = (i) => 3.35 + i * 1.7
  cdraw.line((cellx(1), 5.9), (cellx(3), 2.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((cellx(3), 5.9), (cellx(4), 2.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((cellx(4), 5.9), (cellx(0), 2.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.9, 4.9), [arrows drawn in fill order, first to last], size: 6pt)
  cdraw.content((2.2, 0.9), [second pin: ox of \[5,4,3,2,1\] and \[2,1,4,3,5\] at cuts 1 and 4 reproduces parent 1], size: 6pt)
  cdraw.content((2.2, 0.1), [deterministic, no rng anywhere], size: 6pt)
})

== ant colony optimization and the pheromone model

The ant moves the memory outside the search. A pheromone value tau
sits on every directed edge, all initialized to tau0 = 100, and each
of 4 ants builds a tour greedily but randomly: ant k starts at city
k mod 8, and each next city is drawn among the unvisited with integer
weight w = tau\[cur\]\[j\] times (10000 / d), one below(total) draw then
a cumulative walk. After the tours, every off-diagonal pheromone
evaporates, tau = tau times 9 / 10 with integer division, and every ant
deposits 10000 / L along both directions of its tour edges, so short
tours lay stronger trails. Every rational step is a floor, never a
rounded float, and the whole model stays in integers.

The weights make the preference explicit: at equal tau the weight
ratio is the inverse distance ratio, so an edge of length 2 carries
5000 per unit tau, 10000 over 2, against 1250 for length 8, four to
one. The deposit arithmetic prices an optimal tour at 625 per edge,
10000 over 16, and evaporation floors, 137 times 9 over 10 = 123.

The dry run: the seven-way contract pins the three base runs, their best
tours, and the exact draw count.

+ Seed 1: best 16, tour \[2, 1, 0, 7, 6, 5, 4, 3\].
+ Seed 2: best 16, tour \[0, 1, 2, 3, 4, 5, 6, 7\].
+ Seed 42: best 16, tour \[2, 3, 4, 5, 6, 7, 0, 1\].
+ 280 draws = 4 ants x 7 choices x 10 iterations, exact on every seed,
  and best = 16 = OPT, ratio 1.0 stated as the tolerance.
+ The integer facts, asserted in lua: 10000 // 16 = 625, 100 times 9
  // 10 = 90, 137 times 9 // 10 = 123.

#table(
  columns: (auto, auto, 1.9fr, auto),
  inset: 4pt,
  table.header([*seed*], [*best*], [*best tour*], [*draws*]),
  [1], [16], [\[2,1,0,7,6,5,4,3\]], [280],
  [2], [16], [\[0,1,2,3,4,5,6,7\]], [280],
  [42], [16], [\[2,3,4,5,6,7,0,1\]], [280],
)

Every seed reaches the optimum, and the listings below run the model
in seven languages.

#listing("dsa/samples-c/src/Ch41/aco.c", first: 64, last: 114, caption: [c, the ant walk with integer weights, the draw and cumulative pick, the base update])
#listing("dsa/samples-go/ch41/aco.go", first: 57, last: 99, caption: [go, the ant loop, the best bank, the evaporation sweep])
#listing("dsa/samples-java/src/Ch41/Aco.java", first: 62, last: 114, caption: [java, the ant walk with long weights, the draw and cumulative pick, the base update])
#listing("dsa/samples/src/Ch41/Aco.cs", first: 46, last: 86, caption: [c\#, the ant build loop and the weighted choice])
#listing("dsa/samples-js/src/ch41-aco.mjs", first: 22, last: 67, caption: [javascript, the walk, the banked best, the evaporation])
#listing("dsa/samples-py/src/Ch41/aco.py", first: 47, last: 88, caption: [python, the model whole, weights, walk, evaporate, deposit])
#listing("dsa/samples-lua/ch41_aco.lua", first: 55, last: 96, caption: [lua, the same loop with floor division throughout])

The fixture family: the three tours, the 280 draw identity, the
deposit and evaporation floors, and the optimum reached on all seeds.
The trail is the algorithm's state and it is shared: one matrix of
integers, updated once per iteration, read by every ant of the next
one.

#diagram([the weight rule on the ring: short edges carry four times the weight of long ones at equal tau, and the tau arithmetic strip: 100, evaporate to 90, deposit 625], length: 13pt, {
  // left: the ring with three edge classes from city 0
  let m = (x, y) => (4.6 + x * 0.72, 1.0 + y * 0.72)
  let ring = ((0, 0), (0, 2), (0, 4), (2, 4), (4, 4), (4, 2), (4, 0), (2, 0))
  for k in range(8) {
    let a = ring.at(k)
    let b = ring.at(calc.rem(k + 1, 8))
    cdraw.line(m(a.at(0), a.at(1)), m(b.at(0), b.at(1)), stroke: luma(200))
  }
  // from city 0: short 0-1 (d 2) heavy, mid 0-2 (d 4), long 0-4 (d 8) light
  cdraw.line(m(0, 0), m(0, 2), stroke: 2.0pt + luma(30))
  cdraw.line(m(0, 0), m(0, 4), stroke: 1.0pt + luma(90))
  cdraw.line(m(0, 0), m(4, 4), stroke: 0.6pt + luma(150))
  for (k, p) in ring.enumerate() {
    cdraw.circle(m(p.at(0), p.at(1)), radius: 0.26, fill: luma(235), stroke: luma(110))
    cdraw.content(m(p.at(0), p.at(1)), [#k], size: 6.5pt)
  }
  cdraw.content((1.6, 4.5), [d 2: w = tau x 5000], size: 6pt)
  cdraw.content((1.6, 3.7), [d 4: w = tau x 2500], size: 6pt)
  cdraw.content((1.6, 2.9), [d 8: w = tau x 1250], size: 6pt)
  cdraw.content((1.6, 2.1), [equal tau, 4 to 1 for short], size: 6pt)
  // right: the tau arithmetic strip
  let strip = (100, 90, 715)
  let labels = ([tau0 = 100], [x 9 / 10 = 90], [+ 10000 / 16 = 715])
  for (i, v) in strip.enumerate() {
    let y = 6.6 - i * 1.7
    cdraw.rect((11.6, y - 0.55), (16.4, y + 0.55), fill: luma(238), radius: 0.03)
    cdraw.content((14.0, y), [#v], size: 7pt)
    cdraw.content((17.0, y), labels.at(i), size: 6pt)
    if i < 2 {
      cdraw.line((14.0, y - 0.55), (14.0, y - 1.15), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((11.6, 0.9), [evaporate then deposit, floors everywhere], size: 6pt)
  cdraw.content((11.6, 0.1), [deposit 10000 / L on both directions], size: 6pt)
})

== aco variants

The variants change only the update rule, never ant movement, so every
run consumes the same 280 draws and only the trail differs. Elitist
adds an extra deposit of 10000 / L along the best-so-far tour after
every ant has deposited, and the best is banked before the deposits
each iteration so the extra is defined from iteration 0.
Iteration-best lets only the round's best ant deposit, ties going to
the lower ant index, concentrating the trail on one tour per round.
MMAS, max-min ant system, keeps the iteration-best deposit and clamps
every off-diagonal tau into \[5, 200\] after the update, bounding how
strong any trail can grow and how far an unused edge can fade.

The dry run: the seven-way contract pins the variant tours on seeds 1
and 2, all at best 16 and 280 draws.

+ Elitist: seed 1 pins \[3, 4, 5, 6, 7, 0, 1, 2\], seed 2 pins
  \[2, 3, 4, 5, 6, 7, 0, 1\].
+ Iteration-best: seed 1 pins \[0, 7, 6, 5, 4, 3, 2, 1\], seed 2 pins
  \[2, 3, 4, 5, 6, 7, 0, 1\].
+ MMAS: seed 1 pins \[1, 0, 7, 6, 5, 4, 3, 2\], seed 2 pins
  \[0, 1, 2, 3, 4, 5, 6, 7\].
+ Every variant run answers 16, the optimum, ratio 1.0, on 280 draws
  exact: the clamp and the deposit changes never touch the draw
  sequence.

#table(
  columns: (auto, 1.9fr, 1.9fr, auto),
  inset: 4pt,
  table.header([*variant*], [*seed 1 tour*], [*seed 2 tour*], [*draws*]),
  [base], [\[2,1,0,7,6,5,4,3\]], [\[0,1,2,3,4,5,6,7\]], [280],
  [elitist], [\[3,4,5,6,7,0,1,2\]], [\[2,3,4,5,6,7,0,1\]], [280],
  [iterbest], [\[0,7,6,5,4,3,2,1\]], [\[2,3,4,5,6,7,0,1\]], [280],
  [mmas], [\[1,0,7,6,5,4,3,2\]], [\[0,1,2,3,4,5,6,7\]], [280],
)

Same reach, different tours: the update rule shapes the trail, and the
listings below ship the four rules in seven languages.

#listing("dsa/samples-c/src/Ch41/aco.c", first: 115, last: 158, caption: [c, the variant updates: rank, evaporate, deposits, the elitist extra, the mmas clamp])
#listing("dsa/samples-go/ch41/aco.go", first: 100, last: 125, caption: [go, the variant switch and the mmas min-max clamp])
#listing("dsa/samples-java/src/Ch41/Aco.java", first: 115, last: 159, caption: [java, the variant updates: the banked best first, evaporate, the elitist extra, iteration-best, the mmas clamp])
#listing("dsa/samples/src/Ch41/Aco.cs", first: 87, last: 136, caption: [c\#, the banked best, the evaporation, the variant branches with Math.Clamp])
#listing("dsa/samples-js/src/ch41-aco.mjs", first: 68, last: 109, caption: [javascript, the deposit branches and the clamp])
#listing("dsa/samples-py/src/Ch41/aco.py", first: 89, last: 105, caption: [python, the variant branches, elitist extra, iterbest pick, clamp])
#listing("dsa/samples-lua/ch41_aco.lua", first: 97, last: 129, caption: [lua, depositors, the elitist extra, the mmas band])

The fixture family: the six variant tours of the table, the base tours
for context, the 280 identity holding across all twelve runs, and the
clamp bounds 5 and 200 asserted directly in lua, math.min(200,
math.max(5, 3)) = 5 and the same at 999 landing 200. On this fixture
the variants are a wash at the optimum and differ only in which
optimal rotation
they bank, which is the honest reading: at n = 8 the instance is easy,
the variants exist for the sizes where the trail shape decides
convergence.

#diagram([the four update rules: base deposits from all ants, elitist adds the best-so-far, iteration-best from one ant, mmas from one ant plus the clamp band], length: 13pt, {
  let panel = (y, name, sub) => {
    cdraw.content((0.6, y), name, size: 6.5pt)
    cdraw.content((0.6, y - 0.75), sub, size: 5.5pt)
    for k in range(4) {
      cdraw.circle((6.0 + k * 1.1, y), radius: 0.28, fill: luma(235), stroke: luma(110))
      cdraw.content((6.0 + k * 1.1, y), [#k], size: 5.5pt)
    }
    // tau bar at right
    cdraw.rect((14.4, y - 0.35), (18.4, y + 0.35), fill: luma(240), radius: 0.03)
    cdraw.content((16.4, y + 0.75), [tau matrix], size: 5.5pt)
  }
  let arrow = (x0, y) => cdraw.line((x0, y - 0.3), (14.4, y + 0.42), stroke: luma(100), mark: (end: ">"))
  panel(8.0, [base], [every ant deposits])
  for k in range(4) {
    arrow(6.0 + k * 1.1, 8.0)
  }
  panel(5.6, [elitist], [plus the best-so-far tour])
  for k in range(4) {
    arrow(6.0 + k * 1.1, 5.6)
  }
  cdraw.line((10.6, 4.9), (12.6, 5.3), stroke: 1.4pt + luma(40), mark: (end: ">"))
  cdraw.content((11.0, 4.5), [extra 10000 / L], size: 5.5pt)
  panel(3.2, [iteration-best], [only the round's best ant])
  arrow(7.1, 3.2)
  panel(0.8, [mmas], [iteration-best plus the clamp])
  arrow(7.1, 0.8)
  // the clamp band
  cdraw.content((19.3, 0.8), [clamp \[5, 200\]], size: 6pt)
  cdraw.content((19.3, 0.0), [bounds the trail], size: 6pt)
  cdraw.content((19.3, 5.6), [280 draws in all four], size: 6pt)
  cdraw.content((19.3, 4.7), [movement never changes], size: 6pt)
})

== stopping: portfolios and restart budgets

The last question is when to stop, and the honest answer is a budget.
Sequential restarts of the swap hill climb give the cheapest portfolio:
restart r seeds the generator with 1000 + r, the start tour is a
Fisher-Yates shuffle over \[0..7\] drawing j = below(i + 1) for i from 7
down to 1, 7 draws per shuffle, and the exact-lane climb runs to its
local optimum. The portfolio banks the cumulative best, so the
anytime answer only improves: every completed restart either lowers
the bank or leaves it, and a late restart stuck on a plateau never
erases what earlier restarts banked. A stopping rule can therefore be
an acceptance threshold on the bank, a wall-clock budget, or a fixed
restart count, and the run answers sensibly under all three.

The dry run: the seven-way contract pins the five starts, traces,
finals, and the bank after each restart.

+ r0 starts \[2, 1, 6, 4, 7, 3, 5, 0\], walks 36, 32, 28, 24, 20, 16,
  finishes at \[0, 7, 6, 5, 4, 3, 2, 1\], the bank opens at 16.
+ r1 starts \[6, 7, 5, 2, 0, 4, 1, 3\], walks 40, 36, 28, 24, 20, 16,
  finishes at \[4, 5, 6, 7, 0, 1, 2, 3\].
+ r2 starts \[2, 1, 3, 5, 0, 7, 4, 6\] and r3 starts
  \[3, 2, 6, 1, 5, 4, 7, 0\], both walk 36, 32, 28, 24, 20, 16,
  finishing at \[4, 3, 2, 1, 0, 7, 6, 5\] and \[1, 2, 3, 4, 5, 6, 7, 0\].
+ r4 starts \[0, 1, 2, 6, 5, 4, 7, 3\], walks 32, 24, and stops at
  \[2, 1, 0, 6, 5, 4, 7, 3\], a local optimum of 24: the anytime row.
+ The bank reads 16 from restart 0 onward, so a budget satisfied at 16
  stops after one restart, and the fifth plateau cannot touch it.

#table(
  columns: (auto, 1.7fr, 1.9fr, 1.7fr, auto, auto),
  inset: 4pt,
  table.header([*restart*], [*start*], [*trace*], [*final*], [*local opt*], [*bank*]),
  [r0], [\[2,1,6,4,7,3,5,0\]], [36,32,28,24,20,16], [\[0,7,6,5,4,3,2,1\]], [16], [16],
  [r1], [\[6,7,5,2,0,4,1,3\]], [40,36,28,24,20,16], [\[4,5,6,7,0,1,2,3\]], [16], [16],
  [r2], [\[2,1,3,5,0,7,4,6\]], [36,32,28,24,20,16], [\[4,3,2,1,0,7,6,5\]], [16], [16],
  [r3], [\[3,2,6,1,5,4,7,0\]], [36,32,28,24,20,16], [\[1,2,3,4,5,6,7,0\]], [16], [16],
  [r4], [\[0,1,2,6,5,4,7,3\]], [32,24], [\[2,1,0,6,5,4,7,3\]], [24], [16],
)

Four of five restarts bank the optimum and the fifth plateaus at 24,
and the listings below run the portfolio in seven languages.

#listing("dsa/samples-c/src/Ch41/restarts.c", first: 46, last: 89, caption: [c, the fisher-yates start generator and the restart file's own climb])
#listing("dsa/samples-go/ch41/restarts.go", first: 30, last: 56, caption: [go, the portfolio banking the best local optimum])
#listing("dsa/samples-java/src/Ch41/Restarts.java", first: 46, last: 86, caption: [java, the fisher-yates start generator over the shared lcg, the restart file's own climb])
#listing("dsa/samples/src/Ch41/Restarts.cs", first: 14, last: 43, caption: [c\#, the seeded shuffle and the portfolio rows with the bank])
#listing("dsa/samples-js/src/ch41-restarts.mjs", first: 11, last: 33, caption: [javascript, shuffle and portfolio over the imported climb])
#listing("dsa/samples-py/src/Ch41/restarts.py", first: 72, last: 100, caption: [python, the shuffle, the pinned portfolio, the bank checks])
#listing("dsa/samples-lua/ch41_restarts.lua", first: 41, last: 78, caption: [lua, the climb and the fisher-yates over the shared lcg])

The fixture family: the five starts, the four identical 16 traces and
r1's 40 lead, the r4 row 32, 24 at a different final tour, the bank
constant at 16, and the shuffle meter, 7 draws per restart. The same
seed discipline closes the chapter the way it opened: a restart
portfolio is just the lcg walked twice, once for the shuffle and once
inside the climb it feeds.

#diagram([the anytime curve: cumulative best flat at 16 from restart 0, the five local optima as dots, r4 plateauing at 24 above the bank], length: 13pt, {
  let x = (r) => 2.2 + r * 3.3
  let y = (e) => 1.1 + (e - 14) * 0.40
  // the bank line at 16
  cdraw.line((x(0), y(16)), (x(4) + 1.2, y(16)), stroke: 1.4pt + luma(40))
  cdraw.content((x(4) + 1.5, y(16)), [bank 16], size: 6pt)
  // local optima dots
  let opts = (16, 16, 16, 16, 24)
  for (r, e) in opts.enumerate() {
    cdraw.circle((x(r), y(e)), radius: 0.16, fill: if e == 16 { luma(205) } else { luma(235) }, stroke: luma(100))
    cdraw.content((x(r), y(e) + 0.6), [#e], size: 6pt)
  }
  // r4's trace: 32 -> 24 dashed
  cdraw.line((x(4) - 1.2, y(32)), (x(4), y(24)), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((x(4) - 2.3, y(28) + 0.5), [r4: 32, 24], size: 6pt)
  // restart axis
  cdraw.line((x(0), 0.9), (x(4) + 1.2, 0.9), stroke: luma(120), mark: (end: ">"))
  for r in range(5) {
    cdraw.content((x(r), 0.45), [r#r], size: 6pt)
  }
  cdraw.content((1.0, 0.45), [restarts], size: 6pt)
  cdraw.content((1.0, 8.6), [energy], size: 6pt)
  cdraw.content((3.4, 6.5), [every completed restart], size: 6pt)
  cdraw.content((3.4, 5.6), [only improves the bank], size: 6pt)
  cdraw.content((3.4, 4.7), [the budget can stop at 16], size: 6pt)
  cdraw.content((3.4, 3.8), [r4's plateau never erases it], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's eight sample files per language, go test files excluded,
the c column dropping its preprocessor lines:

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*stem*], [*c*], [*go*], [*java*], [*c\#*], [*javascript*], [*python*], [*lua*]),
  [localsearch], [103], [108], [104], [61], [75], [118], [127],
  [hill], [96], [26], [84], [64], [48], [66], [91],
  [twoopt], [109], [16], [99], [51], [40], [118], [126],
  [anneal], [135], [88], [136], [131], [108], [136], [160],
  [tabu], [146], [67], [131], [69], [56], [88], [107],
  [ga], [180], [132], [170], [132], [82], [118], [156],
  [aco], [176], [114], [167], [133], [105], [106], [176],
  [restarts], [108], [43], [103], [33], [24], [71], [109],
  [total], [1053], [594], [994], [674], [538], [821], [1052],
)

The small numbers are sharing, not absence. Go's twoopt is 16 lines
because the descent itself is the shared Descend of the localsearch
file and twoopt only contributes the reversal move and the delta, and
go's hill and restarts lean on the same helpers the same way. The C\#
tree keeps Lcg and the fixture data in the first file and references
them everywhere, javascript imports the limb generator and the hill
climb across stems, and restarts is thin in three trees because it
reuses the climb instead of restating it. C and python restate the
generator and matrix per file, 8 times each, which is why their totals
run high, and lua restates the same way with the 1-based boundary
shifts and the run.lua check rows added, its total one line under c.
Java restates per stem too, the ring matrix in six files and the lcg
in the five that draw, each generator one multiply-add on long with
the >>> 32 output and no limb work, and java.util.Random never appears
in the tree.

The corpus placement is honest silence: the icpc book's mined finals
problems all yielded to exact algorithms, so no chapter there cites a
metaheuristic, and this chapter's contest relevance is the negative
space, the methods that run when the exact tool the icpc chapters
teach does not finish. The nearest neighbors in this book are the
pruning discipline of #xref-to("dsa", "pruning"), the same
determinism contract over a search tree, and the compact annealing
prose of #xref-to("dsa", "numerical") that this chapter's section 4
replaces at full depth.

sources: E. Aarts and J. K. Lenstra, editors, "Local Search in
Combinatorial Optimization", Wiley, 1997, the survey that named the
frame of section 1. S. Kirkpatrick, C. D. Gelatt, and M. P. Vecchi,
"Optimization by Simulated Annealing", Science 220, 1983, sections 4
and 5. F. Glover, "Tabu Search: Part I", ORSA Journal on Computing 1,
1989, sections 6 and 7, tenure and aspiration as introduced. D. E.
Goldberg, "Genetic Algorithms in Search, Optimization, and Machine
Learning", Addison-Wesley, 1989, sections 8 and 9. M. Dorigo, V.
Maniezzo, and A. Colorni, "Ant System: Optimization by a Colony of
Cooperating Agents", IEEE Transactions on Systems, Man, and
Cybernetics, 1996, sections 10 and 11, and T. Stutzle and H. Hoos,
"MAX-MIN Ant System", Future Generation Computer Systems, 2000, the
clamp of section 11. The generator constants follow D. Knuth, "The
Art of Computer Programming", volume 2, seminumerical algorithms, the
64-bit congruential recommendations. Sample behavior verified by the
seven suite gates scoped to chapter 41, zero skipped, all pins from the
witness ledger of the wave brief. Java's gate runs the same pins under
run-java-samples, 8 files and 359 checks.
