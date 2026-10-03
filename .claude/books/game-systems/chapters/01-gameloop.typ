#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the game loop and time

Every real time game is one shape: a loop that reads input, advances
a simulated world, draws that world, and presents the frame, over and
over until the player quits. A server is a request loop, a gui toolkit
is an event loop, a game is a loop that must finish all three passes
in under sixteen milliseconds. That budget is the whole discipline of
this book, and the loop itself is where its most consequential
decision lives: what a step of time means inside `Update`.

== variable or fixed

The naive loop measures the real time since the last frame and hands
it to the simulation as the delta. Rendering at whatever rate the
machine manages looks smooth, and for menus and turn counters it is
fine. The moment anything integrates, a projectile's arc, a cooldown,
a collision sweep, the variable delta leaks into the results: Euler
integration over different sized steps lands in different places, so
the same shot fired twice behaves differently, a replay recorded on a
fast machine diverges from playback on a slow one, and a bug report
becomes unreproducible.

The fixed timestep loop refuses the leak. The simulation always steps
by the same constant dt, sixty steps a second by convention, and real
time is only used to decide when to run the next step. The same input
sequence produces the same world state on every machine, which is the
property the capstone's replays and the testing chapter stand on. The
price is that simulation time and render time come apart, a 60 hertz
simulation shown on a 50 hertz display needs fractional steps, and
that reconciliation is a real algorithm, not a rounding trick.

Integrated as trajectories the leak is two arcs where there should be
one, and the fixed grid is one arc no matter which machine draws it:

#diagram([the same shot under two step sizes lands apart, the fixed grid lands on one point], length: 13pt, {
  // one shot, v0 = (10, 10), gravity 20 down, explicit euler, ground clamp at y = 0
  let v0x = 10; let v0y = 10; let grav = 20
  // euler after n steps: y = h (n v0y - g h n (n - 1) / 2); the shot lands when it returns to 0
  let steps(h) = int(calc.round(1 + 2 * v0y / (grav * h)))
  let ypos(h, n) = h * (n * v0y - grav * h * n * (n - 1) / 2)
  let land-x(h) = v0x * h * steps(h)
  let arc(h, ox, r, fl, st) = {
    for n in range(steps(h) + 1) {
      cdraw.circle((ox + v0x * h * n * 0.62, 0.7 + ypos(h, n) * 0.62), radius: r, fill: fl, stroke: st)
    }
  }
  let land-mark(px, txt) = {
    cdraw.line((px, 0.7), (px, 1.05), stroke: luma(100))
    cdraw.content((px, -0.2), txt, size: 6pt)
  }

  cdraw.line((0.7, 0.7), (9.8, 0.7), stroke: luma(100))
  arc(1.0 / 3.0, 0.9, 0.12, none, luma(100))
  arc(1.0 / 12.0, 0.9, 0.075, luma(100), none)
  land-mark(0.9 + land-x(1.0 / 3.0) * 0.62, [#calc.round(land-x(1.0 / 3.0), digits: 1)])
  land-mark(0.9 + land-x(1.0 / 12.0) * 0.62, [#calc.round(land-x(1.0 / 12.0), digits: 1)])
  cdraw.content((5.0, 5.05), [variable dt], size: 6.5pt)
  cdraw.content((5.0, 4.05), [dt 1/3 open, dt 1/12 filled], size: 6pt)

  cdraw.line((11.9, 0.7), (19.3, 0.7), stroke: luma(100))
  arc(1.0 / 12.0, 12.1, 0.075, luma(100), none)
  land-mark(12.1 + land-x(1.0 / 12.0) * 0.62, [both: #calc.round(land-x(1.0 / 12.0), digits: 1)])
  cdraw.content((15.7, 5.05), [fixed dt], size: 6.5pt)
  cdraw.content((15.7, 4.05), [both step dt 1/12], size: 6pt)

  cdraw.content((11.0, -1.55), [landing x in world units, steps exaggerated], size: 6pt)
})

== the accumulator

The standard machine, old enough that its canonical description is a
2004 article, is an accumulator. Each frame, add the measured real
delta to a pot. While the pot holds at least one dt, run one
simulation step and subtract dt. Whatever remains is carried to the
next frame, and it is also the interpolation alpha, the fraction of
the way the world has moved toward its next step. The renderer lerps
the previous and current states by that fraction, a linear blend, and
the visible result is smooth even though the simulation ticks on a
fixed grid.

#flow(
  [the accumulator in one picture],
  node((0, 0), [frame delta]),
  node((1.7, 0), [accumulator]),
  node((3.6, 0), [Update(dt)]),
  node((1.7, -1.5), [Draw, lerp(prev, current)]),
  edge((0, 0), (1.7, 0), "-|>"),
  edge((1.7, 0), (3.6, 0), "-|>", label: [while pot >= dt]),
  edge((3.6, 0), (1.7, 0), "-|>", bend: 40deg, label: [pot -= dt, max 5 per frame]),
  edge((1.7, 0), (1.7, -1.5), "-|>", label: [alpha = pot / dt]),
)

#listing("game-systems/samples/src/Ch01/Loop.cs", first: 3, last: 38, caption: [fixed step clock: the accumulator, the step budget, the spiral guard])

`Feed` is the entire loop minus the loop. The test suite drives it
with scripted frame deltas instead of a wall clock, so the exact
behavior is pinned without opening a window: a feed of exactly one
interval consumes one step with alpha zero, and a full second of
jittery delivery, lumps of two steps alternating with empty frames,
still totals exactly sixty steps. The accumulator absorbs the jitter,
it does not average it into the physics.

The `MaxStepsPerFrame` budget is the spiral of death guard. When a
loading hitch or a debugger pause delivers a ten second delta, honest
payment would mean six hundred catch up steps, each of which takes
real time, which puts the frame further behind, which buys more
backlog. The clamp runs five steps and drops the rest, the game hiccups
once and continues, and the test pins the exact post clamp state:
five steps consumed, alpha just under one, the backlog gone.

#listing("game-systems/samples/src/Ch01/Loop.cs", first: 41, last: 45, caption: [render side interpolation by the leftover alpha])

`Lerp` is the render side of the contract. The simulation only ever
produces states on the step grid, the renderer asks for the blend
between the previous and current state at the alpha the clock
reports, and the 50 hertz display test shows the pattern such a loop
actually executes: frames of one, one, one, one, then two steps, six
updates per five renders, forever.

== the framework runs this for you

KNI, the framework the capstone renders through, inherits the XNA
`Game` contract: a default fixed time step at sixty hertz
(`IsFixedTimeStep` true, `TargetElapsedTime` one sixtieth), `Update`
called zero or more times per frame as the accumulator drains, `Draw`
called exactly once. That is the same machine as `FixedStepClock`,
wired to the platform's timer and vsync instead of a test's delta
stream. Building it by hand first is not redundant ceremony, it is
the difference between knowing the framework catches up after a stall
and trusting it.

Stacked side by side the two clocks are one machine with two drivers:

#diagram([the kni game contract stacked against the hand built clock], length: 13pt, {
  let row(y0, left, right, fill) = {
    cdraw.rect((0, y0), (10.8, y0 + 0.9), fill: fill, radius: 0.02)
    cdraw.rect((11.4, y0), (22.2, y0 + 0.9), fill: fill, radius: 0.02)
    cdraw.content((5.4, y0 + 0.45), left, size: 6pt)
    cdraw.content((16.8, y0 + 0.45), right, size: 6pt)
  }
  row(3.45, [kni Game, framework], [FixedStepClock, hand], luma(205))
  row(2.3, [platform timer + vsync], [the test's delta stream], luma(235))
  row(1.15, [Update: zero or more], [steps while pot >= dt], luma(235))
  row(0.0, [Draw: exactly once], [Lerp(prev, current, alpha)], luma(235))
  cdraw.rect((0, -1.1), (22.2, -0.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, -0.65), [one accumulator machine, two drivers], size: 6pt)
})

#callout("warning", "the alpha contract cuts both ways", [
  Interpolated rendering means `Draw` may not assume the world is at
  a step boundary. Anything derived from raw simulation state, camera
  follows, muzzle flashes, hit sparks, must blend or it will jitter
  exactly when the step and frame rates disagree. The capstone keeps
  its render state in previous/current pairs for this reason.
])

sources: gafferongames.com "fix your timestep" for the accumulator
and interpolation alpha, docs.monogame.net game loop article for the
xna `IsFixedTimeStep` and `TargetElapsedTime` contract KNI inherits,
github.com/kniEngine/kni release v4.3.9001 verified 2026-09-08 by
compiling the `Game` surface on net10.0. Verified by
`dotnet test books/game-systems/samples/GameSystemsBook.slnx`,
6 tests in `GameSystems.Samples.Tests.Ch01`.
