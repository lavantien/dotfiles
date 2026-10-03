#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= physics

The physics an artillery game needs is one hundred and fifty years
old: a point mass under constant gravity and a wind field, flying
until it meets the ground. What makes it game physics instead of
textbook physics are the three constraints around it: it must be
cheap enough for hundreds of shells at sixty steps a second, it must
be deterministic per chapter 7 so replays replay, and it must not
tunnel, a fast shell stepping over a thin hill and hitting the far
side that is not there.

== integration, velocity first

#listing("game-systems/samples/src/Ch08/Physics.cs", first: 10, last: 18, caption: [semi-implicit euler: velocity, then position with the new velocity])

The one-line difference between explicit euler, position first, and
semi-implicit euler, velocity first, is the difference between
gaining energy every step and not. Semi-implicit euler is
symplectic, the discrete orbit it traces has a bounded energy error
instead of a growing one, and for a ballistics game under constant
acceleration it is the whole correct answer. The tests check it
against the analytic parabola three ways: height after five seconds
of flight within half a meter of the closed form, a forty five
degree shot at one hundred units per second landing within two
percent of the analytic `v^2/g` range, and the apex within one of
`250`, with all arithmetic in fixed point.

Wind is an acceleration like gravity, so a tailwind is literally the
same `Step` with a positive `wind` term, and the tailwind outranges
headwind test is a property of the integrator rather than a special
case in it.

#diagram([one shot, two integrators, explicit gains energy every step], length: 13pt, {
  // v0 = (6, 10), g = 10, dt = 0.25 s; explicit lands at n = 9, analytic at t = 2
  let X(t) = 1 + 9.3 * t
  let Y(y) = 0.8 + y
  cdraw.line((0.6, 0.8), (22.6, 0.8), stroke: luma(100))

  let xs = range(10).map(n => X(n * 0.25))
  let ey = (0, 2.5, 4.375, 5.625, 6.25, 6.25, 5.625, 4.375, 2.5, 0)
  let sy = (0, 1.875, 3.125, 3.75, 3.75, 3.125, 1.875, 0)
  for n in range(9) {
    cdraw.line((xs.at(n), Y(ey.at(n))), (xs.at(n + 1), Y(ey.at(n + 1))), stroke: luma(100))
  }
  for n in range(7) {
    cdraw.line((xs.at(n), Y(sy.at(n))), (xs.at(n + 1), Y(sy.at(n + 1))), stroke: (paint: luma(100), dash: "dashed"))
  }
  let prev = none
  for k in range(21) {
    let t = k * 0.1
    let p = (X(t), Y(10 * t - 5 * t * t))
    if prev != none { cdraw.line(prev, p, stroke: luma(200)) }
    prev = p
  }
  for n in range(10) { cdraw.circle((xs.at(n), Y(ey.at(n))), radius: 0.1, fill: luma(30)) }
  for n in range(8) { cdraw.circle((xs.at(n), Y(sy.at(n))), radius: 0.1, stroke: luma(30)) }

  cdraw.content((3.5, 7.6), [dt 0.25 s, one dot per step], size: 6pt)
  cdraw.content((12.8, 7.6), [explicit, position first], size: 6pt)
  cdraw.content((5.0, 4.9), [semi-implicit, velocity first], size: 6pt)
  cdraw.content((18.5, 2.9), [the analytic parabola], size: 6pt)
  cdraw.content((11.5, -0.4), [explicit gains energy each step, lands long], size: 6pt)
  cdraw.content((11.5, -1.6), [semi-implicit hugs the parabola, error bounded], size: 6pt)
})

== the heightfield and its questions

#listing("game-systems/samples/src/Ch08/Physics.cs", first: 21, last: 39, caption: [columns sampled linearly, how high is the ground at x])

Terrain here is one height per integer column, the representation
chapter 9 generates and the renderer draws. `HeightAt` answers
"how high is the ground at x" by linear interpolation between the
two neighbors, all in raw fixed point: the column index is the high
32 bits of x, the fraction is the low 32, and there is a rounding
fact worth noticing, the fraction is an unsigned interpretation of
bits that `Raw` holds signed, so the mask comes before anything
else touches it.

#listing("game-systems/samples/src/Ch08/Physics.cs", first: 41, last: 53, caption: [carving a crater as an integer parabola])

`Carve` answers "what does an explosion do to the shape": each
column within the blast radius is depressed by a parabola, and the
depth is computed with one integer expression, `((r^2 - dx^2)
<< 30) / r`. An earlier draft of this method used a `double` in the
middle, quietly reintroducing exactly the nondeterminism chapter 7
exists to remove, and the code review rule that caught it is the
book's rule: doubles may cross the skin of the simulation, never
live inside it.

#diagram([the heightfield: lerp between columns, carve an integer parabola], length: 13pt, {
  // left: one height per column, HeightAt interpolates at a fractional x
  let hs = (2, 2, 3, 5, 3.5, 2, 2, 2)
  for i in range(8) {
    cdraw.rect((1.5 + i, 0.8), (2.5 + i, 0.8 + hs.at(i) * 0.8), fill: luma(235), radius: 0.02)
  }
  cdraw.line((1.2, 0.8), (9.8, 0.8), stroke: luma(100))
  cdraw.line((5.0, 3.2), (6.0, 4.8), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((5.5, 0.8), (5.5, 4.0), stroke: (paint: luma(160), dash: "dotted"))
  cdraw.circle((5.5, 4.0), radius: 0.11, fill: luma(30))
  cdraw.content((5.5, 6.5), [one height per integer column], size: 6pt)
  cdraw.content((5.5, 5.3), [HeightAt lerps by the fraction], size: 6pt)
  cdraw.content((5.5, 0.25), [x is a column index plus 32 fraction bits], size: 6pt)

  // right: the same field after a blast, dashed line is the ground before
  let after = (2, 2, 1.3, 3.0, 1.8, 1.3, 2, 2)
  for i in range(8) {
    cdraw.rect((14.5 + i, 0.8), (15.5 + i, 0.8 + after.at(i) * 0.8), fill: luma(235), radius: 0.02)
    let y-old = 0.8 + hs.at(i) * 0.8
    cdraw.line((14.5 + i, y-old), (15.5 + i, y-old), stroke: (paint: luma(160), dash: "dashed"))
  }
  cdraw.line((14.2, 0.8), (22.8, 0.8), stroke: luma(100))
  cdraw.content((18.5, 6.5), [a blast depresses every column in radius], size: 6pt)
  cdraw.content((18.5, 5.3), [the depth is one integer parabola], size: 6pt)
  cdraw.content((18.5, 0.25), [dashed line: the ground before], size: 6pt)
})

== collision without tunneling

#listing("game-systems/samples/src/Ch08/Physics.cs", first: 55, last: 89, caption: [segment against heightfield, first crossing wins])

The flight step gives a segment from the old position to the new
one, and the collision test walks that segment across every terrain
column it passes over, comparing the segment's height with the
ground's at each column. Because the test is continuous along the
segment rather than sampled at the endpoints, a fast shell cannot
tunnel: the crossing column pins the impact between two heights,
and the impact point is interpolated on the segment. The start of
the segment is skipped, a shell launches from the surface, and
`t == 0` is a starting condition, not a crossing. The tests pin the
cases, a descending segment over a rising hill reports the crossing
on the hill's side, an ascending path over flat ground never hits,
a vertical drop is handled without dividing by zero on the
zero-width segment, and a segment launched from the surface itself
neither lands at its launch column nor skips the crossing past it.

#diagram([one flight step against the heightfield, the crossing column wins], length: 13pt, {
  // one height per integer column, the shape chapter 9 generates
  let hs = (1, 1, 1, 1, 1, 1, 1.6, 2.2, 1.7, 1.2, 1, 1, 1, 1, 1, 1)
  for i in range(16) {
    cdraw.rect((i * 1.6, 0), (i * 1.6 + 1.6, hs.at(i) * 0.9), fill: luma(230), radius: 0.02)
  }
  // the flight step is a straight segment from old position to new
  cdraw.line((7.6, 2.15), (23.4, 0.55), stroke: 1pt)
  cdraw.content((5.0, 2.8), [segment start, skipped], size: 6.5pt)
  cdraw.line((6.2, 2.62), (7.6, 2.2))
  cdraw.content((19.8, 2.9), [step: old position to new], size: 6.5pt)
  cdraw.circle((10.4, 1.72), radius: 0.12, fill: luma(30))
  cdraw.content((15.2, 2.4), [impact, interpolated on the segment], size: 6.5pt)
  cdraw.line((13.8, 2.28), (10.6, 1.8))
  cdraw.content((12.8, -0.8), [the walk visits every column the segment passes over, so no tunneling], size: 6.5pt)
})

#callout("note", "what this physics is not", [
  No rigid bodies, no rotation, no restitution, no friction beyond
  stopping, and no continuous collision between shells. The game is
  turn based artillery, the only bodies are points, and the only
  surfaces are the heightfield. Adding circle-shell collision later
  means distance checks against the same segment machinery, and
  restitution means the integrator gains a velocity reflection at
  the impact normal. Both are doors, not requirements.
])

sources: semi-implicit euler and its symplectic property follow
Glenn Fiedler's integration chapters on gafferongames.com, the same
series chapter 1 cites for the fixed timestep, accessed 2026-09-08.
Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 9 tests in
`GameSystems.Samples.Tests.Ch08`.
