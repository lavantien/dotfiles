#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= error, conditioning, and stability

Floating point rounds every operation to a fixed number of significant
bits, and this chapter is about what that rounding does to a computation
you meant to perform exactly. Six moves: the machine-number grid of ulp
and unit roundoff, error propagation and the condition number of a
subtraction, the quadratic formula as the standard cancellation example,
the line between an ill-conditioned problem and an unstable algorithm,
compensated summation that buys back lost digits, and a precision ladder
that measures what more significand bits pay. Every behavioral claim
below is one of the 55 checks in the 4 samples of chapter 2, a sentence
quoted from Goldberg 1991 or cppreference fetched 2026-09-21, or a
toolchain fact probed on this machine the same day. Where the numerical
chapter of the dsa book treats iteration as a contest driver
(#xref-to("dsa", "numerical")), this chapter asks why the same driver in
different arithmetic returns different answers.

== machine numbers, ulp, and unit roundoff

IEEE 754 binary64 stores a number as a sign, an exponent, and a $p = 53$
bit significand. Every real input $x$ becomes the nearest representable
$"fl"(x)$, and under round-to-nearest with ties to even the relative
error of that storage obeys $abs(x - "fl"(x)) <= u dot abs(x)$ with unit
roundoff $u = 2^(-53)$. Machine epsilon is a different object:
$"DBL_EPSILON" = 2^(-52)$ is the gap between 1 and the next
float, while the unit roundoff is half of it. The gap at a general $x$
is the ulp, and it is not constant: the grid doubles at every power of
two. The nextafter checks in propagate.c pin the three spacings this
section needs, $2^(-52)$ at 1, $2^(-51)$ at 2, and $2^(-54)$ at 0.25,
against integers, where representation is exact and the contrast with
the fixed-width world of #xref-to("c-os-cloud", "machine") is sharpest.

Decimal literals meet this grid immediately, and storing a literal is
the first rounded operation. 0.1 and 0.2 become 0x1.999999999999ap-4 and
0x1.999999999999ap-3, the same significand at adjacent exponents, so
they carry the same relative input error.

The dry run: multiply and divide the stored pair by hand.

+ The exact product of the two stored significands needs 106 bits and
  rounds once, to 0x1.47ae147ae147cp-6.
+ The literal 0.02 stores one grid step lower, at 0x1.47ae147ae147bp-6,
  so the computed product sits exactly 1 ulp above the stored constant:
  relative error 1.7347e-16, which is 1.5625 units of $u$.
+ The quotient is exactly 0.5. Division is correctly rounded, and the
  identical significands cancel: the same mantissa at adjacent
  exponents divides to exactly $2^(-1)$, with zero error from any
  source.

That is the two-number play of this section: the same two inputs, one
multiplication that loses 1.56 units of $u$ and one division that loses
nothing, because error propagation is per-operation, not per-magnitude.

#listing("math/samples/src/Ch02/propagate.c", first: 23, last: 38, caption: [propagate.c, representation error born and moved, one check per pin])

#diagram([ulp grid: tick density halves every binade, spacing doubles at each power of two], length: 13pt, {
  let y = 3
  cdraw.line((0.5, y), (19.5, y), stroke: luma(60))
  let bins = ((1.0, 4.0, 8), (4.0, 8.0, 4), (8.0, 13.0, 2), (13.0, 18.0, 1))
  for (x0, x1, n) in bins {
    for k in range(n) {
      let x = calc.min(x0 + (x1 - x0) * k / n, x1 - 0.4)
      cdraw.line((x, y), (x, y + 0.45), stroke: luma(140))
    }
    cdraw.line((x0, y), (x0, y + 0.85), stroke: luma(60))
  }
  cdraw.line((18.0, y), (18.0, y + 0.85), stroke: luma(60))
  let lab(x, t) = cdraw.content((x, y - 0.55), t, size: 6pt)
  lab(1.0, [1/4]); lab(4.0, [1/2]); lab(8.0, [1]); lab(13.0, [2]); lab(18.0, [4])
})

== propagation and the condition of a subtraction

A problem's condition number is the worst-case ratio of relative output
error to relative input error. For the subtraction $x - y$ with $x approx.
y$ it is $abs(x) \/ abs(x - y)$, and it is unbounded: subtracting nearly
equal numbers can inflate a tiny input error without performing any new
rounding at all. The companion fact is Sterbenz's lemma: when
$1\/2 <= y\/x <= 2$, the difference $x - y$ is computed exactly. Exact
arithmetic plus a huge condition number is precisely the trap.

The dry run: x = fl(1.0000001) and the subtraction x - 1.0.

+ Storing 1.0000001 rounds to 0x1.000001ad7f29bp+0 with relative error
  5.84e-17, about half a unit of $u$. The 1e-7 part is simply not all
  there.
+ x - 1.0 is exact by Sterbenz: both operands are dyadic and within a
  factor of two. The result is 0x1.ad7f29bp-24, and the trailing zero
  hex digits are the visible tell of an exact result.
+ Measured against the intended 1e-7, that exact difference is off by
  5.84e-10 relative. The amplification is 1.0e7, which is
  $abs(x)\/abs(x - 1)$, the condition number, to the digit.

Nothing rounded in the subtraction. The input error was already there,
and the condition number moved it to the output. The sum
${10^16, 1, -10^16}$ shows the same law on a bigger axis: the exact
answer is 1, the condition number is $2 dot 10^16 + 1$, and ulp at
$10^16$ is 2, so both association orders return exactly 0.0.
Reassociating cannot rescue a conditioned problem.

#listing("math/samples/src/Ch02/propagate.c", first: 40, last: 60, caption: [propagate.c, sterbenz exactness, condition-number amplification, and the sum no ordering can save])

#diagram([the subtraction is exact, the condition number carries the input error out], length: 13pt, {
  let box(x, w, t) = {
    cdraw.rect((x, 3.4), (x + w, 4.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 4.0), t, size: 6pt)
  }
  box(0.5, 5.0, [x = fl(1.0000001)])
  box(13.0, 5.5, [x - 1 = 0x1.ad7f29bp-24])
  cdraw.content((2.9, 3.9), [rel err 5.84e-17], size: 6pt)
  cdraw.content((15.8, 3.9), [rel err 5.84e-10], size: 6pt)
  cdraw.line((5.5, 4.0), (13.0, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.2, 4.35), [subtract 1.0, exact by sterbenz], size: 6pt)
  cdraw.content((9.2, 3.6), [cond abs(x)/abs(x-1) = 1e7], size: 6pt)
})

== the quadratic formula: cancellation in the wild

For $a x^2 + b x + c$ the textbook solution
$x = (-b plus.minus sqrt(b^2 - 4 a c)) \/ (2 a)$ hides two separate
subtractions: the discriminant $b^2 - 4 a c$ and, when $b < 0$, the small
root's $-b - sqrt(d)$. The stable rewrite forms $q = (-b - sqrt(d)) \/ 2$
for the sign of $b$ that avoids cancellation, then returns the roots as
$q\/a$ and $c\/q$, trading one cancellation for two divisions.

Goldberg's coefficients a = 1.22, b = -3.34, c = 2.28 make the
discriminant the crime scene. The dry run: trace the discriminant in
float.

+ On the stored coefficients the exact products are
  $b^2 = 11.155599427$ and $4 a c = 11.126400121$, pinned as doubles.
+ Each rounds to the 24-bit grid with its own error, in opposite
  directions: fl32(b*b) = 11.155599594 is 1.7e-7 high and
  fl32(4ac) = 11.126399994 is 1.3e-7 low.
+ The subtraction itself is exact, and the discriminant inherits the
  difference: 0.0291996002 versus the true 0.0291993053, off by 158
  ulps.
+ The roots barely notice: against the root of the stored coefficients
  the naive small root sits 3.27 ulps low and the q-form 2.27 low, one
  better despite its extra division. A root's absolute sensitivity to
  the discriminant is $1 \/ (4 a sqrt(d))$, which is small here. Ulps of
  the discriminant are not ulps of the answer.

#listing("math/samples/src/Ch02/quadratic.c", first: 35, last: 52, caption: [quadratic.c, goldberg triple in f32: stored pins, exact products, the 158-ulp disc])

#listing("math/samples/src/Ch02/quadratic.c", first: 54, last: 73, caption: [quadratic.c, both root forms pinned, 3.27 and 2.27 ulps against the double reference])

#callout("pitfall", "cancellation is a symptom, not the disease", [After his worked example Goldberg states it directly: "The subtraction did not introduce any error, but rather exposed the error introduced in the earlier multiplications." The fix is never to avoid subtraction. It is to notice which earlier operation lost the bits the subtraction then reveals.])

The near-equal-roots triple (1, -1e9, 1) is where the formula choice
decides everything. Its roots are $10^9$ and $10^(-9)$, and the
discriminant is $10^18 - 4$: ulp at $10^18$ is 128, the 4 dies in
rounding, and sqrt(disc) comes back as exactly $10^9$. The naive small
root is then $(10^9 - 10^9)\/2 = 0.0$, annihilated, while the q-form
returns $c\/q$ with relative error 6.1e-17 against the true root, 6.2e-17
against the 1e-9 literal. Vieta's formulas audit the
damage in one multiplication each: the naive pair multiplies to 0, the
q-form pair to exactly 1. Two numbers carry the section: relative error
1.0 against 6.1e-17, same problem, same arithmetic, different algebra.

#listing("math/samples/src/Ch02/quadratic.c", first: 75, last: 89, caption: [quadratic.c, the near-equal-roots triple: naive annihilation, q-form survival, vieta audit])

#diagram([small root of (1, -1e9, 1): the naive form returns 0.0, the q-form lands on the true 1e-9], length: 13pt, {
  let y = 3
  cdraw.line((0.5, y), (19.5, y), stroke: luma(60))
  cdraw.line((3.0, y), (3.0, y + 0.9), stroke: luma(100))
  cdraw.line((11.0, y), (11.0, y + 0.9), stroke: luma(100))
  cdraw.content((3.0, y - 0.55), [0.0], size: 6pt)
  cdraw.content((11.0, y - 0.55), [1e-9], size: 6pt)
  cdraw.content((3.0, y + 1.25), [naive root], size: 6pt)
  cdraw.content((11.0, y + 1.25), [true = q-form root], size: 6pt)
  cdraw.line((3.0, y + 1.0), (3.0, y + 0.95), stroke: luma(100))
  cdraw.line((11.0, y + 1.0), (11.0, y + 0.95), stroke: luma(100))
  cdraw.content((7.0, y + 0.35), [16 orders of relative error], size: 6pt)
  cdraw.line((3.6, y + 0.1), (10.4, y + 0.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
})

Run the same goldberg triple in binary64 and the two formulas still
agree bit for bit, now at 0x1.4c7f71ab5a24bp+0. The agreement is not
accuracy: the computed discriminant carries a relative error of 3.3e-14
from its two rounded products, the square root halves it, and both root
forms land 5.14 ulps (small) and 6.08 ulps (big) from the true roots of
the stored coefficients. When the shared upstream error dominates each
formula's own rounding, naive and stable coincide in the same wrong
answer, and a bit-identical pair is no evidence of correctness.

#listing("math/samples/src/Ch02/quadratic.c", first: 108, last: 120, caption: [quadratic.c, the f64 contrast: both forms coincide at the same 5.14-ulp error])

== conditioning versus stability

Conditioning belongs to the problem: how much the exact answer moves
when the inputs move. Stability belongs to the algorithm: how much
avoidable error the method injects on top. The quadratic sections showed
an unstable algorithm losing a well-conditioned root. Now the reverse
corner: a problem no algorithm can save.

Take $a = 1$, $b = -(4 + 2^(-25))$, $c = 4 + 2^(-24)$. The polynomial
factors as $(x - 2)(x - (2 + 2^(-25)))$: roots 2 and $2 + 2^(-25)$, a
gap of $2^(-25)$, and every coefficient is exactly representable. The
exact discriminant is $2^(-50)$. But $b^2 = 16 + 2^(-22) + 2^(-50)$ and
$4 a c = 16 + 2^(-22)$ both round to the same double, $16 + 2^(-22)$,
because ulp at 16 is $2^(-48)$ and the $2^(-50)$ term is a quarter of
it. So fl(disc) is exactly 0.0. The condition number of the
discriminant, $abs(b^2)\/abs(d)$, is 1.80e16: the discriminant of these
stored coefficients genuinely is ambiguous at the double grid.

The dry run: feed fl(disc) = 0 to both formulas.

+ Naive: both roots come back $-b\/2a = 2 + 2^(-26)$, the same double
  twice.
+ q-form: $q = 2 + 2^(-26)$, then $q\/a$ and the exact-quotient
  $c\/q = 2 + 2\/(2^27 + 1)$, which rounds to $2 + 2^(-26)$ again.
+ Every root slot of both algorithms holds the double 0x1.0000002p+1,
  which is
  exactly the midpoint of the true pair: $(2 + (2 + 2^(-25)))\/2$.

The information that separated the roots was never in the rounded
coefficients, so no cleverer formula can recover it. Higham's remedy in
Accuracy and Stability of Numerical Algorithms (2nd ed.) is to
reformulate: compute the discriminant in wider arithmetic, or
reparameterize the problem. Shopping for a stabler algorithm on an
ill-conditioned input is a category error, and the two numbers of this
section are its whole proof: condition $1.8 dot 10^16$, every computed
root the identical midpoint.

#listing("math/samples/src/Ch02/quadratic.c", first: 91, last: 106, caption: [quadratic.c, the dyadic conditioning triple: both algorithms collapse to the shared midpoint])

#diagram([conditioning versus stability: three measured triples place the quadrants], length: 13pt, {
  let cell(x, yy, w, h, t) = {
    cdraw.rect((x, yy), (x + w, yy + h), fill: luma(245), radius: 0.02)
    cdraw.content((x + w / 2, yy + h / 2), t, size: 6pt)
  }
  cell(6.5, 5.6, 6.0, 1.6, [naive formula])
  cell(12.5, 5.6, 6.0, 1.6, [q-form])
  cell(0.5, 3.8, 6.0, 1.6, [well-conditioned])
  cell(0.5, 1.4, 6.0, 1.6, [ill-conditioned])
  cell(6.5, 3.8, 6.0, 1.6, [goldberg f32: 3.27 ulps fine #linebreak() disaster triple: 0.0 dead])
  cell(12.5, 3.8, 6.0, 1.6, [disaster triple: #linebreak() 1e-9 at 6.1e-17])
  cell(6.5, 1.4, 6.0, 1.6, [dyadic triple: #linebreak() midpoint 2+2^(-26)])
  cell(12.5, 1.4, 6.0, 1.6, [dyadic triple: #linebreak() same midpoint])
})

== compensated summation

Summing many addends concatenates rounding error, and when the running
sum outranges the addends, the small ones vanish entirely. Compensated
summation carries a second variable that remembers what the last
rounded addition dropped. Kahan's form feeds the compensation back into
the next input, $y - c$, computes the rounded sum $t = s + y - c$, and
updates $c = (t - s) - y$ computed exactly by Sterbenz. Neumaier's form
instead accumulates the dropped parts separately and adds them once at
the end.

The pattern for both lanes is one huge addend, then 999998 ones, then
the negated huge addend: exact sum 999998. In float the lane is
[1e8f, 1.0f, ..., -1e8f], in double [2^53, 1.0, ..., -2^53], chosen so
the naive running sum cannot absorb a single 1.

The dry run: the f32 compensation dance, traced by the generator.

+ Naive: $10^8 + 1$ rounds back to $10^8$ every time, since ulp at
  $10^8$ is 8. After the final $-10^8$ the sum is exactly 0.
+ Kahan, first ones: after one add $c = -1$, the next uses
  $y - c = 2$, so $c$ deepens to $-2$, then $-3$, $-4$.
+ At the fifth one the rounded sum itself ratchets to $10^8 + 8$ and
  the sign of $c$ flips: 8 ones move the sum one grid step, and $s$
  tracks the true partial sum. At iteration 999999, $s = 101000000$
  and $c = 2$.
+ Last step: $y - c$ rounds $-10^8 - 2$ to $-10^8$ (the 2 is under
  half of ulp 8), so the final sum lands on 1000000.0f. The exact
  answer 999998 plus the 2 the lane could not represent: 32 ulps off,
  measured, not guessed.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*lane*], [*naive*], [*kahan*], [*neumaier*]),
  [f32 result], [0.0f], [1000000.0f], [999998.0f],
  [f32 error, ulps], [15999968], [32], [0],
  [f64 result], [0.0], [999998.0], [999998.0],
  [f64 error, ulps], [8589917412130816], [0], [0],
)

The two-number play: on the float lane naive loses 16.0 million ulps
and compensation holds the damage to 32, on the double lane naive loses
$8.6 dot 10^15$ ulps and both compensated forms are exact. Compensation
cannot beat the grid, note the 32, but it removes the accumulation.

#listing("math/samples/src/Ch02/kahan.c", first: 26, last: 70, caption: [kahan.c, three summation machines interleaved on both lanes, one loop with dance checkpoints])

#listing("math/samples/src/Ch02/kahan.c", first: 72, last: 99, caption: [kahan.c, the pinned sums, the pinned dance states, and the ulp-scored errors])

#diagram([the dance: s ratchets one grid step per 8 ones while c cycles, trace from the generator], length: 13pt, {
  let ys = 4.4
  let yc = 2.2
  cdraw.line((0.5, ys), (19.0, ys), stroke: luma(60))
  cdraw.line((0.5, yc), (19.0, yc), stroke: luma(60))
  cdraw.content((0.0, ys), [s], size: 6.5pt)
  cdraw.content((0.0, yc), [c], size: 6.5pt)
  let pts = ((2.5, [1e8], [-1]), (6.0, [1e8], [-2]), (9.5, [1e8+8], [+3]), (13.0, [1e8+8], [0]), (16.5, [1e8+16], [+4]))
  for (x, s, c) in pts {
    cdraw.circle((x, ys), radius: 0.12, fill: luma(205), stroke: luma(60))
    cdraw.circle((x, yc), radius: 0.12, fill: luma(235), stroke: luma(100))
    cdraw.content((x, ys + 0.55), s, size: 6pt)
    cdraw.content((x, yc + 0.55), c, size: 6pt)
    cdraw.line((x, ys - 0.15), (x, yc + 0.15), stroke: (paint: luma(150), dash: "dashed"))
  }
  cdraw.content((9.5, 1.1), [iteration 2, 3, 6, 9, 13, then periodic], size: 6pt)
})

== precision ladders and what more bits buy

One computation, several rungs: newton for $sqrt(2)$ from 1.5 with
$x <- x - (x^2 - 2)\/(2x)$, every operation rounded to the rung's
precision, 20 updates. The ladder on this machine has two real rungs:
float with 24 significand bits and double with 53. Long double is
binary64 under the MSVC ABI, pinned by LDBL_MANT_DIG == 53, so that
rung is a relabeling. The bottom rung has to be emulated: this lane's
clang compiles `_Float16` but cannot link it, the conversion builtins
`__extendhfsf2` and `__truncsfhf2` are undefined, probed 2026-09-21. The
sample therefore rounds each double result to an 11-bit significand,
which is how the hardware emulation would store it anyway.

#callout("warning", "float16 compiles here but does not link", [On this toolchain a `_Float16` program passes the frontend (clang documents x86 SSE2 support via float emulation) and then fails at link time on the missing conversion builtins. The 11-bit rung in precision.c is a frexp-and-ldexp rounder instead. Probe before you ship: the ladder you can compile is not always the ladder you can run.])

The dry run: the double rung's first six updates.

+ From 1.5 the updates read 1.4166666666666667, 1.4142156862745099,
  1.4142135623746899: quadratic convergence, the same ladder the dsa
  contest chapters pin.
+ Update 4 lands on 0x1.6a09e667f3bcdp+0, the double $sqrt(2)$.
+ Update 5 steps one ulp down to 0x1.6a09e667f3bccp+0 and update 6
  returns: from here the iterate oscillates between the two, pinned by
  checks at updates 4, 5, and 6.

Each rung stalls where its own grid locks the update map into a fixed
point:

+ 11 bits: the iterate freezes at 1.4140625 after 2 updates, relative
  error 1.068e-4. The correction is under half an ulp and dies in
  rounding.
+ 24 bits: the iterate reaches 0x1.6a09e6p+0f in 3 updates and the
  rounded update maps that value to itself, verified by a 21st pass.
  Relative error 1.711e-8, which is the pure representation error of
  storing $sqrt(2)$ in float.
+ 53 bits: the dry run above, oscillating between the stored value and
  one ulp below, pinned on the stored value at update 20.
  Relative error 6.84e-17, again the representation error of the rung.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*rung*], [*bits*], [*stall value*], [*relative error*]),
  [emulated f16], [11], [1.4140625], [1.068e-4],
  [float], [24], [1.4142135], [1.711e-8],
  [double], [53], [1.4142135623730951], [6.84e-17],
  [long double], [53], [identical to double], [6.84e-17],
)

The two-number play: 11 bits to 24 bits is a factor 6200 in final
error, 24 to 53 another 250000, and the driver is the same newton the
dsa contest chapters tune (#xref-to("dsa", "numerical")). More bits do
not make a better algorithm, they move the fixed point closer to the
real number.

The last measurement is Dekker's fast two-sum on $10^16 + 1$. The sum
itself is an exact tie between $10^16$ and $10^16 + 2$, and ties go to
even: $10^16$ has an even significand, so the 1 dies in the rounded
sum. Two-sum recovers it exactly, $z = a - s$ then $e = z + b$, both
exact by Sterbenz, and the pair $(s, e)$ satisfies $s + e = a + b$
over the reals while the single double $s + e$ still rounds back to
$s$. When the error term matters it has to stay a separate variable,
which is the whole design of the compensated summation above and of
the autovectorization hazards in #xref-to("c-os-cloud", "opt"): a
compiler that reassociates $s + e$ across your two variables quietly
deletes the compensation.

#listing("math/samples/src/Ch02/precision.c", first: 42, last: 71, caption: [precision.c, the four ladder rungs, one update map, four roundings])

#listing("math/samples/src/Ch02/precision.c", first: 111, last: 119, caption: [precision.c, dekker fast two-sum: the lost 1 recovered exactly, and why it must stay separate])

#diagram([precision ladder: each rung's stall error, three decades apart per rung], length: 13pt, {
  let step(x, w, h, t) = {
    cdraw.line((x, h), (x + w, h), stroke: luma(60))
    cdraw.line((x, h), (x, 0.6), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.content((x + w / 2, h + 0.45), t, size: 6pt)
  }
  step(1.0, 5.0, 4.6, [f16: 1.068e-4])
  step(6.0, 5.0, 2.9, [float: 1.711e-8])
  step(11.0, 5.0, 1.2, [double: 6.84e-17])
  cdraw.line((1.0, 0.6), (18.0, 0.6), stroke: luma(60))
  cdraw.content((3.5, 0.15), [11 bits], size: 6pt)
  cdraw.content((8.5, 0.15), [24 bits], size: 6pt)
  cdraw.content((13.5, 0.15), [53 bits], size: 6pt)
  cdraw.content((18.6, 4.6), [newton stalls], size: 6pt, anchor: "west")
})

The next chapter, #xref-to("math", "trig"), takes these arithmetic
rules onto the unit circle, where range reduction is the conditioning
question and the identities are the stable reformulations.

sources: David Goldberg, "What Every Computer Scientist Should Know
About Floating-Point Arithmetic", ACM Computing Surveys 23(1), 1991,
cancellation example and quoted sentence from its cancellation section,
oracle text fetched 2026-09-21. Nicholas J. Higham, Accuracy and
Stability of Numerical Algorithms, 2nd ed, SIAM 2002, cited by name and
edition for the conditioning-versus-stability remedy, no page text
quoted. cppreference fenv, en.cppreference.com/w/c/numeric/fenv,
fetched 2026-09-21. clang LanguageExtensions, `_Float16` on x86,
clang.llvm.org/docs/LanguageExtensions.html, fetched 2026-09-21.
`FLT_`, `DBL_`, `LDBL_` constants, the `_Float16` link failure, and long double
as binary64 probed on this machine 2026-09-21, playground/math-ch02.
Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch02`,
55 checks in chapter 2 of the math suite.
