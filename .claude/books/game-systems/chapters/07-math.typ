#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= deterministic math

Chapter 1 chose the fixed timestep so the same input stream steps the
same simulation. This chapter is the other half of that promise: the
arithmetic inside each step must produce the same bits, and `double`
does not promise that. Not because ieee 754 addition is sloppy, it is
defined exactly, but because a real game does more than add. `Math.Sin`
is implemented by the runtime's math library, transcendental results
are not specified to the last bit, and a replay recorded on one
machine can diverge on another after a few hundred calls. There is
also the smaller honest point most engineers meet first:

#snippet("0.1 + 0.1 + ... ten times\n  double: 0.9999999999999999\n  fixed:  raw 4294967300, bit identical everywhere")

Binary floating point cannot represent 0.1, so ten additions land a
hair under one. That is not a bug, it is the format, and the test
pins both sides of the comparison: the double misses, the fixed
point lands within one part in a billion and, more importantly, lands
on the same raw bits on every machine that runs the line.

== Q31.32 in one struct

#listing("game-systems/samples/src/Ch07/Fp.cs", first: 9, last: 33, caption: [one long, 31 integer bits, 32 fraction bits, checked everywhere])

Fixed point is just integers with a convention: the low 32 bits are
fraction. Addition and subtraction are integer operations, exact.
Multiplication produces a 64.64 intermediate through `Int128`, which
.NET 10 ships natively, then shifts back down, and division expands
the numerator the same way. The `checked` context is the discipline:
when a value leaves the representable range the operation throws
instead of silently wrapping to garbage, because a wrapped coordinate
in a replay is a corruption that surfaces three systems later as a
mystery. The overflow test pins both sides, `2^20` squared throws,
`128` to the fourth is exactly `2^28`.

#diagram([the 64 raw bits of one fixed point value], length: 13pt, {
  cdraw.rect((0, 0), (26, 1.8), radius: 0.05)
  cdraw.line((4, 0), (4, 1.8))
  cdraw.line((11, 0), (11, 1.8))
  cdraw.content((2, 0.9), [sign], size: 6.5pt)
  cdraw.content((7.5, 0.9), [integer, 31 bits], size: 6.5pt)
  cdraw.content((18.5, 0.9), [fraction, 32 bits], size: 6.5pt)
  cdraw.content((2, 2.3), [bit 63], size: 6.5pt)
  cdraw.content((7.5, 2.3), [bits 62 to 32], size: 6.5pt)
  cdraw.content((18.5, 2.3), [bits 31 to 0], size: 6.5pt)
  for x in (0, 4, 11, 26) { cdraw.line((x, 1.8), (x, 2.05)) }
  cdraw.content((13, -0.9), [raw 4294967300 is one integer plus four fraction units of 2^-32], size: 6.5pt)
})

The conversions bracket the boundary honestly. `FromDouble` and
`ToDouble` exist for input, display, and tests, and the rule the
capstone follows is absolute: doubles may cross the skin of the
simulation, never live inside it.

== trig without a math library

#listing("game-systems/samples/src/Ch07/Fp.cs", first: 35, last: 58, caption: [cordic rotation: shifts and adds])

Sin and cos come from cordic, the shift-and-add algorithm from 1959
that hardware still uses in mode. Starting from the constant
`0.60725...` on the x axis, each step rotates the vector by
`atan(2^-i)` toward the target angle, and rotation by a power of two
is just a shift. After 32 steps the vector is `(cos, sin)` to about
nine decimal digits, the tests compare against `Math.Sin` and
`Math.Cos` at `1e-6` and check the pythagorean identity holds inside
fixed point. The catch that matters for replays: the atan table is
generated once and frozen as hex literals in the source, so no
runtime math library can ever move a digit of it. A table computed
lazily from `Math.Atan` would reintroduce the exact dependency this
chapter exists to remove.

The range limit is stated in the code and worth restating: this
`SinCos` converges only for angles under about 1.74 radians, and the
capstone never asks beyond a quarter turn, elevation angles live in
zero to ninety degrees. General angles need range reduction first,
and doing that in fixed point is its own exercise.

#diagram([cordic walking the vector onto the target angle, one shift-add per step], length: 13pt, {
  // successive vector angles for target 50 degrees: 0, 45.0, 71.6, 57.5, 50.4, 50.0
  let o = (4, 2.2)
  let r = 5.6
  cdraw.line((3.6, 2.2), (10.2, 2.2), stroke: luma(220))
  cdraw.line((4, 1.6), (4, 8.9), stroke: luma(220))
  cdraw.arc(o, start: -75deg, stop: 0deg, radius: r, ccw: false, stroke: luma(220))
  let vec(deg, stroke) = {
    let a = deg * 1deg
    cdraw.line(o, (o.at(0) + r * calc.cos(a), o.at(1) + r * calc.sin(a)), stroke: stroke)
  }
  vec(0, luma(150)); vec(45, luma(100)); vec(71.6, luma(100))
  vec(57.5, luma(100)); vec(50.4, luma(100))
  vec(50, 1.2pt + luma(30))
  cdraw.content((8.3, 5.9), [50.0 after 5 steps], size: 6pt)
  cdraw.content((7.2, 1.4), [starts at 0.60725 on x], size: 6pt)

  cdraw.content((17, 9.0), [angles: 0, 45.0, 71.6, 57.5, 50.4, 50.0], size: 6pt)
  cdraw.content((17, 7.8), [each step rotates by atan(2^-i)], size: 6pt)
  cdraw.content((17, 6.6), [a rotation is a shift and an add], size: 6pt)
  cdraw.content((17, 5.4), [z walks toward 0, error halves], size: 6pt)
  cdraw.content((17, 4.2), [32 steps, about 9 digits], size: 6pt)
  cdraw.content((17, 3.0), [the atan table is frozen hex], size: 6pt)
})

#listing("game-systems/samples/src/Ch07/Fp.cs", first: 70, last: 90, caption: [integer newton square root, seeded above the answer])

Square root is newton iteration on integers, seeded at `2^48` which
is above every root a legal raw value can have, so the iteration only
walks down and its stopping rule, stop when the next estimate fails
to decrease, is exact for integer square roots. Any seed above the
answer converges to the same raw bits, which is the whole point.

== what determinism costs

#callout("warning", "determinism is not exactness", [
  Fixed point does not make arithmetic exact, `0.1` is not
  representable in binary fixed point either, and mul followed by
  div does not round trip exactly. What it makes identical: the same
  operation sequence produces the same raw bits on every machine,
  every runtime, every optimization level, because there is no
  library call and no unspecified rounding anywhere in the path.
  Replays need identical, not exact, and identical is a property you
  can test: the projectile test runs a 300 step integration twice
  and compares raw bits, the same assertion the capstone's replay
  suite makes about whole matches.
])

The costs are the other side of the ledger. Range is finite and
throws when exceeded, precision is 32 fraction bits everywhere with
no denormals near zero, and every trig call is a 32 step loop. For
a turn based artillery sim at 60 steps a second with hundreds of
shells, all three costs are invisible, and chapter 13's counting
harness proves it.

#diagram([the cost ledger, fixed point against double], length: 13pt, {
  cdraw.rect((1, 7.2), (6.2, 8.0), fill: luma(205), radius: 0.02)
  cdraw.rect((6.2, 7.2), (14.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.rect((14.6, 7.2), (23.0, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((3.6, 7.6), [the ledger], size: 6.5pt)
  cdraw.content((10.4, 7.6), [Q31.32], size: 6.5pt)
  cdraw.content((18.8, 7.6), [double], size: 6.5pt)

  let rows = (
    ([range], [finite, overflow throws], [vast, silently inf]),
    ([precision], [32 fraction bits, even], [53 bits, library defined]),
    ([one sincos], [32 step shift-add loop], [one call, faster]),
    ([a replay], [bit identical everywhere], [drifts across machines]),
  )
  for i in range(rows.len()) {
    let y0 = 5.85 - i * 1.2
    cdraw.rect((1, y0), (6.2, y0 + 1.2), fill: luma(235), radius: 0.02)
    let (a, b, c) = rows.at(i)
    cdraw.content((3.6, y0 + 0.6), a, size: 6pt)
    cdraw.content((10.4, y0 + 0.6), b, size: 6pt)
    cdraw.content((18.8, y0 + 0.6), c, size: 6pt)
  }

  cdraw.content((12, 1.5), [pay the ledger, get bit identical replays], size: 6pt)
  cdraw.content((12, 0.3), [at 60 steps a second, none of the costs are visible], size: 6pt)
})

sources: learn.microsoft.com System.Math.Sin remarks, "this method
calls into the underlying C runtime, and the exact result or valid
input range may differ between different operating systems or
architectures", which is the portability hole this chapter closes,
the cordic algorithm and convergence constant from the cordic page
on en.wikipedia.org checked against local .NET 10 runs, accessed
2026-09-08. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 8 tests in
`GameSystems.Samples.Tests.Ch07`.
