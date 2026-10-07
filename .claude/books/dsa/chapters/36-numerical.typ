#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= numerical methods

Continuous problems land on a contest board as doubles, and the
honest way through is deterministic drivers with pinned stopping
rules: every loop count fixed in advance, every assert compared
against a pinned constant inside a stated epsilon, never bit
equality. This chapter builds the four drivers that carry that
discipline, ternary and golden-section search over unimodal
valleys, newton iteration for roots and reciprocals, simpson
integration in composite and adaptive form, and the linear program
duality that turns one world finals flow problem into a one
dimensional search. Simulated annealing closes the chapter in
prose, the one heuristic in the neighborhood, kept honest by the
same seeded determinism the coded sections use. The anchor
application is icpc 2025 problem C (book 10, chapter 13), whose
reservoir model supplies the duality section end to end.

== ternary search

Two domains, one algorithm. On integers the loop probes m1 = l +
(r - l) / 3 and m2 = r - (r - l) / 3 while r - l > 2, keeps the
side holding the smaller probe, and on a tie shrinks both ends,
the plateau rule, because equal probes say nothing about where a
flat stretch ends. A short linear scan closes whatever window of
3 or fewer cells survives. On doubles the same two probes run a
fixed 200 iterations and return the midpoint. The fixed count is
the whole trick for a seven-language book: no float comparison ever
decides control flow differently in c than in lua, so the orbit
of intervals is identical everywhere and the pinned outputs hold
without any tolerance negotiation. The contract is strictly
unimodal input for the clean invariant, minimum inside and both
probes strictly ordered off the floor, with the plateau rule
documented as the safety net.

The dry run: the fixtures are the valley 12, 9, 7, 3, 2, 5, 8, 11
with its rising, falling, and plateau kin, asserted by the C\# suite
and pinned at identical counts in all seven.

+ Round 1 on the valley, window 0 through 7: m1 = 0 + 7 / 3 = 2 and
  m2 = 7 - 7 / 3 = 5, the probes read 7 and 5, 7 > 5 keeps the right
  side, l = 3, meter at 2.
+ Round 2, window 3 through 7: m1 = 3 + 4 / 3 = 4 and
  m2 = 7 - 4 / 3 = 6, the probes read 2 and 8, 2 < 8 keeps the left, r = 5, meter
  at 4.
+ The window 3 through 5 is 3 wide, the loop hands off, and the
  closing scan pays 2 probes, 2 < 3 moving the best to index 4: the
  meter lands 6.
+ The plateau 5, 4, 4, 4, 7 ties its round, 4 = 4 at m1 = 1 and
  m2 = 3, so both ends shrink to 1 through 3 and the strict scan
  keeps the first minimum, index 1, meter 4.
+ The rising 1, 2, 3, 4, 5 pins the left edge, one round and a
  two-step scan, meter 4 at argmin 0, and the falling 9, 7, 5, 3
  pins the right edge, one round and a one-step scan, meter 3 at
  argmin 3.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*fixture*], [*rounds*], [*round probes*], [*scan probes*], [*total*], [*argmin*]),
  [12, 9, 7, 3, 2, 5, 8, 11], [2], [4], [2], [6], [4],
  [1, 2, 3, 4, 5], [1], [2], [2], [4], [0],
  [9, 7, 5, 3], [1], [2], [1], [3], [3],
  [5, 4, 4, 4, 7], [1, tie], [2], [2], [4], [1],
)

The 6 is the meter every suite pins on the valley, and the listings
below run the integer loop and the 200-iteration real driver in seven
languages.

#listing("dsa/samples-c/src/Ch36/ternary.c", first: 24, last: 59, caption: [c, the integer loop with the tie rule, then the fixed-count real driver])
#listing("dsa/samples-go/ch36/ternary.go", first: 7, last: 48, caption: [go, the switch form of the three-way probe outcome])
#listing("dsa/samples-java/src/Ch36/Ternary.java", first: 21, last: 56, caption: [java, the integer loop with the tie rule, then the fixed-count real driver over DoubleUnaryOperator])
#listing("dsa/samples/src/Ch36/Ternary.cs", first: 11, last: 54, caption: [c\#, the same pair, tuple return carrying the probe meter])
#listing("dsa/samples-js/src/ch36-ternary.mjs", first: 10, last: 46, caption: [javascript, floor division by hand, the object return])
#listing("dsa/samples-py/src/Ch36/ternary.py", first: 15, last: 45, caption: [python, the plateau comment marks the tie rule])
#listing("dsa/samples-lua/ch36_ternary.lua", first: 8, last: 44, caption: [lua, the 0-based public face over 1-based tables])

The probe meter is deterministic, so the integer fixtures pin
identical counts in all seven suites. The valley 12, 9, 7, 3, 2, 5,
8, 11 lands its argmin at index 4 on 6 probes, the rising array
1, 2, 3, 4, 5 puts the minimum at the left edge index 0 on 4
probes, and the falling array 9, 7, 5, 3 hits the right edge
index 3 on 3 probes. The plateau family 5, 4, 4, 4, 7 returns
index 1, the first minimum, on 4 probes. Every integer answer is
cross-checked against a linear scan, and the real drivers pin
against the pinned constants: (x - 3)^2 + 0.5 over (0, 10)
returns x within 1e-6 of 3, measured 3.0000000074505806, with
f(x) = 0.5 to 1e-9, and the kinked valley, parabola right of 2
and a ramp left of it, closes on 2.0 exactly on (0, 6).

#diagram([the 12, 9, 7, 3, 2, 5, 8, 11 valley over three probe rounds, the kept range shrinking each round, the probe ledger at right], length: 13pt, {
  let a = (12, 9, 7, 3, 2, 5, 8, 11)
  // the pinned orbit: [0,7] probes 2,5 -> 7 > 5 keeps right, l = 3;
  // [3,7] probes 4,6 -> 2 < 8 keeps left, r = 5; [3,5] scan pins 4
  let rounds = (
    (0, 7, 2, 5),
    (3, 7, 4, 6),
    (3, 5, none, none),
  )
  for (rno, rnd) in rounds.enumerate() {
    let (l, r, m1, m2) = rnd
    let y = 6.6 - rno * 2.4
    for i in range(8) {
      let x = 1.2 + i * 1.6
      let hot = i >= l and i <= r
      cdraw.line((x, y), (x, y + a.at(i) * 0.62), stroke: if hot { luma(100) } else { luma(200) })
      if hot {
        cdraw.content((x, y + a.at(i) * 0.62 + 0.32), [#a.at(i)], size: 6pt)
      }
      if i == m1 or i == m2 {
        cdraw.circle((x, y + a.at(i) * 0.62), radius: 0.14, fill: luma(205), stroke: luma(100))
        cdraw.content((x, y - 0.45), if i == m1 { [m1] } else { [m2] }, size: 6pt)
      }
    }
    cdraw.content((1.0, y - 1.05), [round #(rno + 1), window [#l, #r]], size: 6pt)
  }
  cdraw.content((1.2, 7.9), [tall bars carry the values, shaded circles mark the probes], size: 6pt)
  cdraw.content((14.6, 6.1), [round 1: probes 2, 5, 7 > 5, l = 3], size: 6pt)
  cdraw.content((14.6, 5.2), [round 2: probes 4, 6, 2 < 8, r = 5], size: 6pt)
  cdraw.content((14.6, 4.3), [round 3: the scan pins index 4], size: 6pt)
  cdraw.content((14.6, 3.4), [argmin index 4, value 2, 6 probes], size: 6pt)
  cdraw.content((14.6, 2.5), [plateau rule: tie shrinks both ends], size: 6pt)
  cdraw.content((14.6, 1.6), [real driver: 200 fixed iterations], size: 6pt)
  cdraw.content((14.6, 0.7), [no float decides control flow], size: 6pt)
})

The contest face is icpc 2025 problem C (book 10, chapter 13), where
the r = 2 case of the pipe model is exactly this driver over the
free reservoir weight and r = 3 nests two of them, and icpc 2022
problem T (book 10, chapter 11), which refines a grid answer with a
ternary pass over each corner-bend leg. The monotone cousin,
bisection over a boolean answer space, is
#xref-to("dsa", "searching") territory and stays there.

== golden-section search

Ternary spends two evaluations per step because both probe points
land in territory the next step cannot reuse. The golden ratio
fixes the waste: place c = hi - phi(hi - lo) and d = lo + phi(hi
- lo) with phi = (sqrt(5) - 1) / 2 = 0.6180339887498949, and the
symmetry phi^2 = 1 - phi makes one old interior point land exactly
on the next step's opposite probe. Keep that point, evaluate only
the new one, and every step after the warm-up pair costs exactly
one evaluation. The iteration count is pinned at 100, which
shrinks the interval below 1e-19 of its width, far past any useful
epsilon, so evaluation counts and final widths are identical
doubles in all seven languages. The budget arithmetic is the
selling point: 102 total evaluations against 400 for 200 ternary
iterations.

The dry run: the fixture is (x - 1)^2 + 7 over (0, 100) with the
ternary kink riding along, asserted by the C\# suite at exactly 102
evaluations, the width gate, and the phi constants.

+ The warm-up evaluates the first pair, c = 100 - phi × 100 =
  38.1966011250105 and d = phi × 100 = 61.8033988749895, 2 evals on
  the ledger.
+ Both probes sit right of the minimum at 1, fc < fd, so hi takes d
  and the old c is carried: by phi^2 = 1 - phi it lands exactly on
  the next step's d, and only the new c costs a call.
+ The width shrinks one phi per step, 100 × phi = 61.8033988749895
  then 38.1966011250105 then 23.6067977499790, and after step k the
  geometry says 100 × phi^k.
+ The constants family pins 100 × phi^100 = 1.2625133380638542e-19
  within 1e-12 relative, the honest band, since lua's libm pow
  differs from the reference in the fifteenth significant digit.
+ Doubles stop shrinking before the geometry does: the measured
  final width is 2.220446049250313e-16, one double spacing near 1,
  inside the 1e-15 gate, and the midpoint lands 1.0000000210734243
  with f(x) within 1e-12 of 7, the kink landing 2.000000000000001.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*interval width*], [*evals*]),
  [warm-up], [100], [2],
  [1], [61.8033988749895], [3],
  [2], [38.1966011250105], [4],
  [k], [100 × phi^k], [k + 2],
  [100], [1.2625133380638542e-19], [102],
)

The 102 is what every suite pins, half of ternary's 400 for the same
job, and the listings below run the keep-and-replace loop in seven
languages.

#listing("dsa/samples-c/src/Ch36/golden.c", first: 26, last: 50, caption: [c, the keep-and-replace loop, one new evaluation per step])
#listing("dsa/samples-go/ch36/golden.go", first: 12, last: 31, caption: [go, the same multi-assign, evals and width returned])
#listing("dsa/samples-java/src/Ch36/Golden.java", first: 24, last: 47, caption: [java, the keep-and-replace loop, one new evaluation per step])
#listing("dsa/samples/src/Ch36/Golden.cs", first: 11, last: 36, caption: [c\#, the tuple swap keeps the interior point in one statement])
#listing("dsa/samples-js/src/ch36-golden.mjs", first: 12, last: 35, caption: [javascript, the one new evaluation commented where it happens])
#listing("dsa/samples-py/src/Ch36/golden.py", first: 16, last: 34, caption: [python, phi defined from sqrt, the warm-up pair at 2])
#listing("dsa/samples-lua/ch36_golden.lua", first: 12, last: 31, caption: [lua, the same loop over the shared phi constant])

The smooth fixture (x - 1)^2 + 7 over (0, 100) pins the meter
exactly: 102 evaluations, x within 1e-6 of 1, measured
1.0000000210734243, f(x) within 1e-12 of 7, and a final interval
width of 2.220446049250313e-16, under the 1e-15 gate. The kink
function from the ternary section rides the same driver and lands
2.000000000000001 on the same 102 evaluations. The constants
family pins phi to its printed form and checks the shrink factor
100 \* phi^100 = 1.2625133380638542e-19 within 1e-12 relative.
That tolerance is itself a taught decision: 1e-30 relative would
demand bit-identical libm pow across languages, below one ulp of
a double, and lua's pow genuinely differs from the reference in
the fifteenth significant digit, around 1e-15 relative. The
python, c\#, c, and java suites passed at tighter tolerances locally
and stay as committed, the others assert the honest band.

#diagram([the (0, 100) interval cascade, each row a step, the reused interior point shaded, one new probe per line], length: 13pt, {
  let phi = 0.6180339887498949
  let lo = 0.0
  let hi = 100.0
  let x0 = 1.4
  let scale = 6.8 / 100.0
  let steps = 6
  for step in range(steps + 1) {
    let y = 7.0 - step * 0.95
    let c = hi - phi * (hi - lo)
    let d = lo + phi * (hi - lo)
    cdraw.line((x0 + lo * scale, y), (x0 + hi * scale, y), stroke: luma(100))
    // numbers only on the first and last rows, the cascade speaks between
    if step == 0 or step == steps {
      cdraw.content((x0 + lo * scale - 0.5, y), [#lo], size: 5.5pt)
      cdraw.content((x0 + hi * scale + 0.5, y), [#hi], size: 5.5pt)
    }
    // d is carried from the previous step (shaded), c is the fresh probe
    cdraw.circle((x0 + c * scale, y), radius: 0.11, fill: none, stroke: luma(100))
    cdraw.circle((x0 + d * scale, y), radius: 0.11, fill: if step > 0 { luma(205) } else { none }, stroke: luma(100))
    cdraw.content((x0 + c * scale, y - 0.4), [c], size: 6pt)
    cdraw.content((x0 + d * scale, y + 0.4), [d], size: 6pt)
    // the fixture keeps the left side (fc < fd near a min at 1): hi = d,
    // and old c becomes the next step's d, the carried point
    hi = d
  }
  cdraw.content((4.8, 8.8), [one new probe per row, the other carried], size: 6.5pt)
  cdraw.content((4.8, 8.05), [widths shrink by phi per step], size: 6pt)
  cdraw.content((12.4, 6.3), [eval ledger: 2, then 1 per step], size: 6pt)
  cdraw.content((12.4, 5.4), [102 total for 100 steps], size: 6pt)
  cdraw.content((12.4, 4.5), [ternary: 400 for 200 steps], size: 6pt)
  cdraw.content((12.4, 3.6), [final width 2.22e-16 on (0,100)], size: 6pt)
  cdraw.content((12.4, 2.7), [phi^2 = 1 - phi is the whole trick], size: 6pt)
})

No finals problem in the six mined years pins this driver, so its
row reads general technique. The prose claim worth keeping is the
drop-in one: when a dual evaluation is expensive, the 2025/C
driver of the last section runs unchanged on this loop and pays
half the evaluations.

== newton's method

Root finding by tangent lines. For f(x) = x^2 - 2 the update x
\<- x - (x^2 - 2) / (2x) divides by the derivative, and from 1.0
the iterates pin in all seven languages: 1, 1.5, 1.416666666666667,
1.414215686274510, 1.414213562374690, 1.414213562373095, five
updates to the residual bound 1e-12. The pinned error column shows
quadratic convergence, each error roughly the square of the
previous: 4.1e-1, 8.6e-2, 2.5e-3, 2.1e-6, 1.6e-12. The second
loop computes the reciprocal 1/a by x \<- x(2 - ax), which divides
nowhere inside the loop, the property that makes it
hardware-interesting, and from 0.2 for a = 7 it walks 0.2, 0.12,
0.1392, 0.14276352, 0.142857081500467, 0.142857142857117, five
updates to a measured final error of 2.6e-14.

The dry run: the fixtures are the sqrt 2 ladder from 1.0 and the
reciprocal of 7 from 0.2, iterates pinned by the C\# suite at 9
decimals with the same ladders in all seven.

+ The first update is one fraction: at x = 1 the residual is -1 on a
  slope of 2, and 1 - (-1) / 2 = 1.5.
+ The next tangent lands 1.5 - 0.25 / 3 = 1.4166666666666667, and
  three more updates close the ladder, 1.4142156862745099,
  1.4142135623746899, 1.4142135623730951, five updates in all under
  the residual check before each one.
+ The error column squares on the way down, 8.6e-2, 2.5e-3, 2.1e-6,
  1.6e-12: quadratic convergence as plain numbers.
+ The reciprocal loop divides nowhere: 0.2 × (2 - 7 × 0.2) = 0.12,
  then 0.12 × (2 - 7 × 0.12) = 0.1392, then 0.1392 × (2 - 7 ×
  0.1392) = 0.14276352, five updates to 0.142857142857117.
+ The identity case is free, a start at the exact root passes the
  first residual check and exits at 0 updates, and from -1.0 the
  same loop closes on -1.4142135623730951, the negative root.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*update*], [*x on x^2 - 2*], [*error*], [*x on 1 / 7*]),
  [0], [1], [4.1e-1], [0.2],
  [1], [1.5], [8.6e-2], [0.12],
  [2], [1.4166666666666667], [2.5e-3], [0.1392],
  [3], [1.4142156862745099], [2.1e-6], [0.14276352],
  [4], [1.4142135623746899], [1.6e-12], [0.142857081500467],
  [5], [1.4142135623730951], [under 1e-12], [0.142857142857117],
)

Five updates close both ladders, and the listings below run the two
loops in seven languages.

#listing("dsa/samples-c/src/Ch36/newton.c", first: 24, last: 48, caption: [c, the two update loops, residual checked before each step])
#listing("dsa/samples-go/ch36/newton.go", first: 8, last: 39, caption: [go, the iterate slice returned whole for the ladder asserts])
#listing("dsa/samples-java/src/Ch36/Newton.java", first: 21, last: 43, caption: [java, the two update loops, residual checked before each step])
#listing("dsa/samples/src/Ch36/Newton.cs", first: 10, last: 42, caption: [c\#, both loops as iterate enumerables, the meter outside])
#listing("dsa/samples-js/src/ch36-newton.mjs", first: 9, last: 33, caption: [javascript, iterates collected, updates counted])
#listing("dsa/samples-py/src/Ch36/newton.py", first: 19, last: 43, caption: [python, the division-free comment sits on the reciprocal loop])
#listing("dsa/samples-lua/ch36_newton.lua", first: 6, last: 29, caption: [lua, the same pair, prints pinned to 12 decimals])

The stopping rule is residual-first: check |x^2 - 2| < 1e-12
before each update, so starting at the exact root exits with zero
updates, the identity case every suite pins. The divergence basin
is real and pinned too, from -1.0 the same loop converges to
-1.414213562373095, the negative root, because the tangent at a
negative point never crosses zero. What stays in prose is the
double-root slowdown: on f(x) = x^2 the error halves per step
instead of squaring, since the derivative vanishes at the root,
and the honest fix there is a modified update or a different
method entirely. Iterates print in the 12-decimal form
%.12f, and every final value is checked against the language's
own sqrt and division ground truths, not just against the pinned
ladder.

#diagram([the parabola y = x^2 - 2 with the tangent ladder from (1, -1) closing on the root, the error column squaring beside each step], length: 13pt, {
  let m = (x, y) => (1.6 + (x + 0.4) * 2.1, 0.9 + (y + 1.6) * 1.55)
  // the parabola from x=-0.3..2.05
  let pts = ()
  let x = -0.3
  while x < 2.06 {
    pts.push(m(x, x * x - 2))
    x += 0.08
  }
  cdraw.line(..pts, stroke: luma(100))
  // x axis and y axis hints
  cdraw.line(m(-0.4, 0), m(2.15, 0), stroke: (paint: luma(190), dash: "dashed"))
  cdraw.line(m(0, -1.7), m(0, 2.4), stroke: (paint: luma(190), dash: "dashed"))
  // tangent at x0=1: y = -1 + 2(x-1), crosses the axis at 1.5
  cdraw.line(m(0.5, -2.0), m(1.9, 0.8), stroke: luma(140))
  // tangent at 1.5: y = 0.25 + 3(x-1.5), crosses the axis at 1.4167
  cdraw.line(m(1.28, -0.41), m(1.62, 0.61), stroke: luma(140))
  let xs = (1, 1.5, 1.416666666666667, 1.414215686274510, 1.414213562373095)
  let errs = ("4.1e-1", "8.6e-2", "2.5e-3", "2.1e-6", "1.6e-12")
  for (i, xv) in xs.enumerate() {
    let yv = xv * xv - 2
    let p = m(xv, yv)
    cdraw.circle(p, radius: 0.09, fill: luma(60))
    cdraw.line(p, (p.at(0), m(xv, 0).at(1)), stroke: (paint: luma(180), dash: "dotted"))
    cdraw.content((14.0, 6.4 - i * 1.05), [x#(i + 1) = #xv], size: 6pt)
    cdraw.content((18.4, 6.4 - i * 1.05), [err #errs.at(i)], size: 6pt)
  }
  cdraw.content((m(1.4142135, 0).at(0) + 0.3, m(1.4142135, 0).at(1) - 0.45), [root], size: 6pt)
  cdraw.content((4.2, 8.3), [each tangent lands on the next iterate], size: 6.5pt)
  cdraw.content((14.0, 0.5), [each error about the square of the last], size: 6pt)
})

The row's bcl entry is Math.Sqrt, the library call this loop
reproduces when the hardware or the language gives you no sqrt and
only multiplication is trusted.

== simpson integration

The composite rule fits a parabola through every pair of panels:
weights 1, 4, 2, 4, ..., 4, 1 over n even panels, the even-n
precondition asserted at the door because the weights pair off.
One parabola integrates cubics exactly, so x^2 over (0, 1) on n =
100 returns 1/3 and x^3 over (0, 2) returns 4, both residuals pure
rounding, measured 0.3333333333333334 and 4.000000000000001.
The adaptive variant compares the whole interval's parabola
against its two halves, accepts when the gap is at most 15 eps,
and on accept adds back the Richardson correction (left + right -
whole) / 15, the classical extrapolation of the error estimate.
On recursion eps halves and a depth cap of 24 stops runaway
splits. Reference values are closed forms where they exist, 1/3,
4, 2 for sin over (0, pi) measured 1.9999999999999991, and the
erf-based constant 0.746824132812427 for e^-x^2 over (0, 1):
adaptive lands 0.7468241328124992 and composite n = 1000 lands
0.746824132812436, both inside the 1e-9 gate.

The dry run: the fixtures are the exact-through-cubics family, sin
over (0, pi), and the e^-x^2 bump against the erf constant, asserted
by the C\# suite with the printed forms pinned as strings in Python
and Java.

+ One panel is the whole kernel: x^2 over (0, 1) at n = 2 reads
  h / 3 × (0 + 4 × 0.25 + 1) = 0.5 / 3 × 2 = 1 / 3 exactly, the edge
  the suite pins at 12 decimals.
+ The adaptive rule on e^-x^2 prices the whole panel first, (1 +
  4 × 0.7788007830714049 + 0.3678794411714423) / 6 =
  0.7471804289095104.
+ Its halves price (1 + 4 × 0.9394130628134758 + 0.7788007830714049)
  over 12 at 0.4613710861937757, and (0.7788007830714049 + 4 ×
  0.5697828247309230 + 0.3678794411714423) over 12 at
  0.2854842935972116.
+ The gap |0.7468553797909873 - 0.7471804289095104| = 3.25e-4 dwarfs
  the 15 eps = 1.5e-9 gate, both halves recurse at eps halved, and
  the recursion accepts its way down to 0.7468241328124992.
+ The composite road at n = 1000 lands 0.746824132812436, both
  inside 1e-9 of the erf reference 0.746824132812427, sin lands
  1.9999999999999991 against 2, and the nine-decimal prints
  0.333333333, 4.000000000, 2.000000000, 0.746824133 pin as
  strings.
+ The edges refuse at the door: a zero-width interval returns 0 and
  odd panel counts are rejected, exception in C\#, assert in Python.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*piece*], [*folded sum*], [*value*]),
  [whole (0, 1)], [(1 + 3.1152031322856195 + 0.3678794411714423) / 6], [0.7471804289095104],
  [left (0, 0.5)], [(1 + 3.7576522512539032 + 0.7788007830714049) / 12], [0.4613710861937757],
  [right (0.5, 1)], [(0.7788007830714049 + 2.279131298923692 + 0.3678794411714423) / 12], [0.2854842935972116],
  [halves], [0.4613710861937757 + 0.2854842935972116], [0.7468553797909873],
  [gap vs gate], [3.25e-4 against 15 × 1e-10], [recurse],
)

The erf reference holds both roads inside 1e-9, and the listings
below ship the kernel, the composite weights, and the recursion in
seven languages.

#listing("dsa/samples-c/src/Ch36/simpson.c", first: 26, last: 49, caption: [c, the 1/6 kernel, the composite weights, the adaptive accept-or-recurse])
#listing("dsa/samples-go/ch36/simpson.go", first: 18, last: 64, caption: [go, the closure recursion passing cached endpoint values down])
#listing("dsa/samples-java/src/Ch36/Simpson.java", first: 31, last: 53, caption: [java, the 1/6 kernel, the composite weights, the adaptive accept-or-recurse])
#listing("dsa/samples/src/Ch36/Simpson.cs", first: 9, last: 43, caption: [c\#, odd panel counts refused by exception, the recursive accept with correction])
#listing("dsa/samples-js/src/ch36-simpson.mjs", first: 8, last: 36, caption: [javascript, the kernel as a local arrow function, depth default 24])
#listing("dsa/samples-py/src/Ch36/simpson.py", first: 16, last: 41, caption: [python, the even-n assert and the richardson-corrected return])
#listing("dsa/samples-lua/ch36_simpson.lua", first: 7, last: 35, caption: [lua, the same recursion, odd panels refused by assert])

The edge family pins the corners: a single panel n = 2 on x^2 is
exactly 1/3, a zero-width interval integrates to 0, and the
printed nine-decimal forms are pinned as strings, 0.333333333,
4.000000000, 2.000000000, 0.746824133. The printed-form pin is
deliberate: it freezes the rounding behavior the prose quotes, so
a language whose adaptive path lands one ulp off the composite
path still prints the pinned digits. Java formats under
Locale.ROOT so the decimal separator never goes locale-dependent,
and Math ships no erf, so its reference constant comes from a
60-term Maclaurin series asserted against the adaptive landing to
1e-12.

#diagram([e^-x^2 over (0, 1) with the first adaptive parabolas, split points accumulating where the curve bends], length: 13pt, {
  let m = (x, y) => (1.8 + x * 11.5, 0.8 + y * 5.2)
  let f = (x) => calc.exp(-1.0 * x * x)
  // the curve
  let pts = ()
  let x = 0.0
  while x < 1.005 {
    pts.push(m(x, f(x)))
    x += 0.02
  }
  cdraw.line(..pts, stroke: luma(100))
  // a parabola arc through (a, fa), (mid, fm), (b, fb), lagrange form
  let arc = (a, b, fa, fm, fb, hot) => {
    let sub = ()
    let t = 0
    while t < 1.01 {
      let xi = a + (b - a) * t
      let s = (xi - (a + b) / 2) / ((b - a) / 2)
      let yi = fm + (fb - fa) / 2 * s + (fa - 2 * fm + fb) / 2 * s * s
      sub.push(m(xi, yi))
      t += 0.05
    }
    cdraw.line(..sub, stroke: if hot { luma(160) } else { (paint: luma(180), dash: "dashed") })
  }
  arc(0.5, 1.0, f(0.5), f(0.75), f(1.0), true)
  arc(0.0, 0.5, f(0.0), f(0.25), f(0.5), true)
  arc(0.0, 1.0, f(0.0), f(0.5), f(1.0), false)
  for xi in (0.25, 0.5, 0.75) {
    let p = m(xi, f(xi))
    cdraw.circle(p, radius: 0.1, fill: luma(205), stroke: luma(100))
    cdraw.line(p, (p.at(0), m(xi, 0).at(1)), stroke: (paint: luma(190), dash: "dotted"))
  }
  cdraw.line(m(0, 0), m(1, 0), stroke: luma(160))
  cdraw.content((4.5, 6.8), [dashed: the whole parabola, solid: the halves], size: 6.5pt)
  cdraw.content((16.4, 5.2), [accept when gap <= 15 eps], size: 6pt)
  cdraw.content((16.4, 4.3), [else recurse, eps halved, depth cap 24], size: 6pt)
  cdraw.content((16.4, 3.4), [accept adds (l + r - w) / 15], size: 6pt)
  cdraw.content((16.4, 2.5), [exact through cubics by construction], size: 6pt)
  cdraw.content((16.4, 1.6), [area 0.746824133 printed], size: 6pt)
})

== simulated annealing

No samples ship for this section, on purpose: annealing is a
randomized heuristic whose every interesting claim is probabilistic,
and a deterministic seven-language pin of a float walk would teach the
wrong lesson. The idea earns the page. Model the problem as an energy
landscape, current solution plus a neighbor move, and walk with the
Metropolis rule: a move that lowers energy is always taken, a move
raising energy by delta is taken with probability exp(-delta / T), and
the temperature T decays geometrically so late steps become a pure
local search. The honest ranking stays: exact algorithms first, local
search next, annealing last, when nothing structural is left to
exploit.

The full treatment lives in #xref-to("dsa", "metaheuristics"), where
the rule runs in an integer form a seeded generator can pin exactly,
with counter-exact runs, cooling and reheat schedules, and restart
budgets, all asserted by the seven language suites.

== LP duality and dual weights

The 2025/C pipe model is a max-min problem: stations split
inflow among ducts, each duct forwards fixed percentages to
higher-numbered targets, and the answer is the largest percentage
of flow guaranteed to reach the reservoirs. Linear program
duality turns that max-min into a one-dimensional minimization.
Assign a weight w to every station and reservoir, reservoir
weights summing to exactly 1, and require each duct to force
w(upstream) >= the sum of percentage-scaled downstream weights,
w(station) = max over its ducts. Weak duality says every such
weight assignment upper-bounds the primal answer, strong duality
says the best bound is tight. Because targets are always
higher-numbered, the dual is a dag: fix the free reservoir
weight t and the weights propagate bottom-up in one pass over
decreasing station id, each station taking the max over its
ducts. r = 1 has no free weight and is one pass at t = 1, r = 2
hands the pass to the ternary driver of the first section, 200
fixed iterations over the single free reservoir weight, each dual
evaluation O(V), and r = 3 nests two ternary loops, stated in
prose because the machinery is identical.

The dry run: the fixtures are F1, one station and two reservoirs,
F2 the perfect duct, and F3 the interior kink, asserted by the C\#
suite and cross-checked by Python's dense grid of 2000001 points.

+ Fix the free weight t and F1 propagates in one pass: w(2) = t,
  w(3) = 1 - t, and station 1 takes the max of its ducts, 0.5 × t
  against 0.3 × t + 0.8 × (1 - t) = 0.8 - 0.5 × t.
+ The two duct values cross at 0.5 × t = 0.8 - 0.5 × t, that is
  t = 0.8: both bind at exactly 0.4, so the dual minimum is 0.4 and
  the answer prints 100 × 0.4 = 40.0000000000 at weights 0.8, 0.2.
+ F2 at t = 1 is a single pass, w(2) = 1 and station 1 takes
  max(1.0 × 1, 0.4 × 1) = 1.0, answering 100.0000000000.
+ F3 settles station 2 first, w(2) = w(3) = t, then station 1 takes
  max(0.5 × t + 0.2 × (1 - t), 1 - t), and the crossing solves
  1.3 × t = 0.8, t = 8 / 13, both ducts binding at 5 / 13, the
  answer 100 × 5 / 13 = 38.4615384615.
+ The dense grid agrees: its F3 minimum reads 0.3846155 at
  t = 0.6153845, the grid point just under the exact 8 / 13, and
  its F1 minimum reproduces 0.4.

#diagram([F1's dual as two duct lines over t, the max traced as a v, the ternary probes narrowing onto the kink at 0.8], length: 13pt, {
  // t in [0, 1] mapped right, dual weight up; duct a rises, duct b falls
  let m = (t, w) => (1.4 + t * 10.8, 0.9 + w * 5.0)
  cdraw.line(m(0, 0), m(1, 0), stroke: luma(160))
  cdraw.line(m(0, 0), m(0, 1), stroke: luma(160))
  cdraw.line(m(0, 0), m(1, 0.5), stroke: luma(180))
  cdraw.line(m(0, 0.8), m(1, 0.3), stroke: luma(180))
  // the max of the two, thick v through the kink at t = 0.8
  cdraw.line(m(0, 0.8), m(0.8, 0.4), stroke: (paint: luma(100), thickness: 1.2pt))
  cdraw.line(m(0.8, 0.4), m(1, 0.5), stroke: (paint: luma(100), thickness: 1.2pt))
  cdraw.circle(m(0.8, 0.4), radius: 0.16, fill: luma(205), stroke: luma(100))
  cdraw.content((m(0.8, 0.4).at(0) - 1.3, m(0.8, 0.4).at(1) + 0.5), [t = 0.8, w = 0.4], size: 6pt)
  // ternary probes: round 1 at 1/3 and 2/3, round 2 at 5/9 and 7/9
  cdraw.circle(m(1 / 3, 0.6333), radius: 0.11, fill: none, stroke: luma(100))
  cdraw.circle(m(2 / 3, 0.4667), radius: 0.11, fill: none, stroke: luma(100))
  cdraw.circle(m(5 / 9, 0.5222), radius: 0.11, fill: none, stroke: luma(100))
  cdraw.circle(m(7 / 9, 0.4111), radius: 0.11, fill: luma(205), stroke: luma(100))
  cdraw.content((m(1 / 3, 0).at(0), 0.45), [m1 = 1/3], size: 6pt)
  cdraw.content((m(2 / 3, 0).at(0), 0.45), [m2 = 2/3], size: 6pt)
  cdraw.content(m(0.02, 0.9), [duct b: 0.8 - 0.5 × t], size: 6pt)
  cdraw.content(m(0.72, 0.62), [duct a: 0.5 × t], size: 6pt)
  cdraw.content((12.6, 0.45), [t], size: 6pt)
  cdraw.content((14.6, 6.1), [the max of two lines is a v], size: 6pt)
  cdraw.content((14.6, 5.2), [kink at 0.8, answer 100 × 0.4 = 40], size: 6pt)
  cdraw.content((14.6, 4.3), [f3: kink at 8/13, 38.4615384615], size: 6pt)
  cdraw.content((14.6, 3.4), [f2: one pass at t = 1, answer 100], size: 6pt)
  cdraw.content((14.6, 2.5), [each dual eval is one pass], size: 6pt)
  cdraw.content((14.6, 1.6), [ternary probes narrow on the kink], size: 6pt)
})

F1's 40.0000000000 with both ducts binding is the pinned landing,
and the listings below run the bottom-up pass and the drivers in
seven languages.

#listing("dsa/samples-c/src/Ch36/lpdual.c", first: 38, last: 75, caption: [c, the bottom-up dual evaluation feeding the ternary driver])
#listing("dsa/samples-go/ch36/lpdual.go", first: 22, last: 66, caption: [go, dual-eval on the duct structs, r = 1 shortcut at t = 1])
#listing("dsa/samples-java/src/Ch36/Lpdual.java", first: 23, last: 58, caption: [java, the bottom-up dual evaluation over record ducts feeding the ternary driver])
#listing("dsa/samples/src/Ch36/LpDual.cs", first: 14, last: 63, caption: [c\#, solve-dual over duct tuples, the optimum returning weights and t])
#listing("dsa/samples-js/src/ch36-lpdual.mjs", first: 12, last: 47, caption: [javascript, weights in a flat array, ducts as pairs])
#listing("dsa/samples-py/src/Ch36/lpdual.py", first: 15, last: 43, caption: [python, the descending station pass with the max over ducts])
#listing("dsa/samples-lua/ch36_lpdual.lua", first: 11, last: 47, caption: [lua, ducts as nested tables, the same two functions])

Answers print as percentages in the %.10f form and assert within
1e-6 of the exact rationals. F1, the crafted 2025/C case, is one
station and two reservoirs with ducts 50 percent to reservoir 2
and 30 to 2 plus 80 to 3: the answer is 40.0000000000 at weights
w(2) = 0.8 and w(3) = 0.2, and complementary slackness is visible,
at the optimum both ducts of the station bind at exactly 0.4. F2
is the r = 1 case, a perfect 100 percent duct against a 40
percent one, answering 100.0000000000 in a single pass. F3 is
the interior kink, two stations and two reservoirs, answering
38.4615384615 = 100 times 5/13 at w(3) = 8/13 with both of
station 1's ducts binding at the crossing. The cross-check is a
deterministic dense grid of 2000001 points over the free weight,
step 5e-7: it reproduces F1's minimum 0.4 and F3's minimum
0.3846155 at t = 0.6153845, which is a multiple of 1/2000000,
not of 1/2000, the grid is genuinely that dense.

#diagram([F1's station 1 splitting into two ducts, the percentage arrows, both reservoir tanks filling to the equalized 40 percent line, the dual weights on the tank rims], length: 13pt, {
  // station 1 at left, two ducts to reservoirs 2 and 3
  cdraw.rect((1.4, 3.8), (3.4, 5.4), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((2.4, 4.6), [station 1], size: 7pt)
  cdraw.content((2.4, 5.9), [both ducts bind at 0.4], size: 6pt)
  // duct a: 50% to reservoir 2 (upper tank)
  cdraw.line((3.4, 5.0), (8.2, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.2, 6.2), [duct a: 50% to 2], size: 6pt)
  // duct b: 30% to 2, 80% to 3 (lower tank)
  cdraw.line((3.4, 4.2), (8.2, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.0, 3.6), [duct b: 30% to 2, 80% to 3], size: 6pt)
  // reservoir tanks, 40 percent fill, dual weight above, level label right
  let tank = (y0, lab, wl) => {
    let x0 = 8.2
    let w = 2.0
    let h = 2.4
    let fill-h = 0.4 * h
    cdraw.rect((x0, y0), (x0 + w, y0 + h), fill: none, stroke: luma(120), radius: 0.03)
    cdraw.rect((x0, y0), (x0 + w, y0 + fill-h), fill: luma(205))
    cdraw.content((x0 + w / 2, y0 + h + 0.45), lab, size: 7pt)
    cdraw.content((x0 + w / 2, y0 + h + 1.1), [dual w = #wl], size: 6pt)
    cdraw.line((x0 - 0.25, y0 + fill-h), (x0 + w + 0.25, y0 + fill-h), stroke: (paint: luma(100), dash: "dashed"))
    cdraw.content((x0 + w + 0.9, y0 + fill-h), [40%], size: 5.5pt)
  }
  tank(5.0, [reservoir 2], [0.8])
  tank(1.6, [reservoir 3], [0.2])
  cdraw.content((1.6, 2.8), [0.5 \* 0.8 = 0.4], size: 6pt)
  cdraw.content((1.6, 2.0), [0.3 \* 0.8 + 0.8 \* 0.2 = 0.4], size: 6pt)
  cdraw.content((13.8, 5.2), [weights sum to exactly 1], size: 6pt)
  cdraw.content((13.8, 4.3), [station weight = max over ducts], size: 6pt)
  cdraw.content((13.8, 3.4), [answer 40.0000000000%], size: 6pt)
  cdraw.content((13.8, 2.5), [strong duality: bound is tight], size: 6pt)
  cdraw.content((13.8, 1.6), [r = 2: ternary over t, O(V) per eval], size: 6pt)
})

The application is icpc 2025 problem C (book 10, chapter 13), the
anchor for the whole construction: the primal formulation, the
dual collapse to bottom-up max propagation on this dag, and the
final one-dimensional search are all its solution's shape, and
the icpc chapter carries the full recovery algorithm.

== across the seven languages

Featured build size counted as non-blank, non-comment lines of
the chapter's five sample files per language, embedded test
scripts included where the language embeds them:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [422], [libc math only], [function pointers for the drivers, the golden pow pin asserted at tighter than 1e-12 relative],
  [go], [191], [fmt and math], [dual-eval errors returned not thrown, ternary real exported for the lpdual driver],
  [java], [402], [jdk 27 stdlib, java.util.function], [DoubleUnaryOperator where c takes function pointers, Math ships no erf so the reference runs a 60-term Maclaurin series, nine-decimal prints under Locale.ROOT, the golden width pinned at the double-ulp floor],
  [c\#], [205], [bcl only, tuples], [iterates as enumerables in newton, exceptions refuse odd simpson panels, long eval meter],
  [javascript], [146], [node stdlib], [object returns carry the meters, floor division written by hand],
  [python], [311], [stdlib math], [printed forms pinned as strings, the dense grid cross-check runs 2000001 points in-suite],
  [lua], [309], [lib.lua harness], [in-file approx helper, the pow pin documented at 1e-12 relative with the libm caveat],
)

sources: cp-algorithms, "Ternary Search",
cp-algorithms.com/num_methods/ternary_search.html, "Newton's
method for finding roots",
cp-algorithms.com/num_methods/roots_newton.html, "Integration by
Simpson's formula",
cp-algorithms.com/num_methods/simpson-integration.html, and
"Simulated Annealing",
cp-algorithms.com/num_methods/simulated_annealing.html, all
accessed 2026-09-20, cc by-sa 4.0, our own words and code
throughout. Golden-section search has no cp-algorithms page and
is derived here from the ternary article, cited as such. LP
duality likewise has no cp-algorithms article. Application
sources: icpc 2025 problem C (book 10, chapter 13) and icpc 2022
problem T (book 10, chapter 11). Sample behavior verified by the
seven suite gates scoped to chapter 36: c 5 files and 74 checks,
go 15 test functions, java 5 files and 74 checks under
run-java-samples, c\# 21 facts, javascript 19 tests and 56
asserts, python 5 files and 59 asserts, lua 18 checks, zero
skipped.
