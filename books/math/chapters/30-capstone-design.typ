#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= capstone: the arena game, design

Twenty-nine chapters of arithmetic now pay for one program: a 2-player
physics arena where boxes collect orbs, ram each other, and hand their
decisions to a search. This chapter is the design document: the game spec,
the module map, the game state as an algebraic data type, the numerics
budget that fixes timestep and tolerances before any code exists, the
two-part ai (an exact mixed-strategy opening book, then budgeted monte
carlo tree search), and the two-lane architecture that keeps one bit-exact
truth across a headless core and a windowed allegro host. Every behavioral
claim below is one of the 64 checks in the capstone test suite or one of
the host gates, both run green on 2026-09-22 (`pwsh -NoProfile -File
playground/math-capstone/build.ps1` and `pwsh -NoProfile -File
tools/run-math-capstone.ps1`), or is a sentence read from the committed
source it describes. The dsa book's games chapter owns combinatorial game
search on discrete boards, so this capstone owns what it cannot: continuous
physics in doubles, deterministic to the bit, with the game theory riding
on top as macro decisions.

== the game

Two player boxes start at (8, 12) and (16, 12) on a 24 by 24 cell arena,
facing each other along the x axis at headings 0 and $pi$. Eight orbs sit
at fixed homes, four on the diagonal ring (5, 5), (19, 5), (19, 19),
(5, 19) and four on the axis ring (5, 12), (12, 5), (19, 12), (12, 19).
A box that touches an orb scores 1 for its player and the orb returns
600 steps later at the same home. Two neutral circles of radius 0.8 drift
as obstacles at (12, 8) and (12, 16), pushed around by contacts but
steering nothing. The game runs 7200 fixed steps of $"DT" = 1\/120$ seconds,
60 seconds of game time, 120 decision windows of 0.5 s each, and the
higher orb count at the horizon wins.

The map is built to be symmetric, not decorated to look symmetric. The
border ring plus exactly 16 interior wall cells: the 2 by 2 center block
at (11, 11) through (12, 12), a diagonal orbit at (6, 6), (17, 6), (6, 17),
(17, 17), and two midline orbits of 4 cells each. Every interior cell's
full orbit under the dihedral group $D_4$ is present, which the state
suite checks cell by cell over all 8 transforms, because chapter
#xref-to("math", "groups") needs the group action to be a symmetry of the
board before any canonical hashing can be sound.

The dry run: the map by arithmetic.

+ 24 by 24 cells is 576, and the walkable interior is 22 by 22 = 484.
+ The border ring is the difference, 576 - 484 = 92 cells.
+ Adding the 16 interior wall cells walls off 108 of 576, and those 16
  cells close into exactly 4 orbits, the center block, the diagonal
  ring, and the two midline rings.

#diagram([the arena at step 0: border ring, the 16 interior wall cells in their d4 orbits, 8 orb homes, both spawns, both neutral circles], length: 13pt, {
  let sc(x) = { if x >= 0 { 2.0 + x * 0.5 } else { 2.0 } }
  // arena frame, border ring
  cdraw.rect((2, 1), (14, 13), stroke: luma(60), fill: luma(245))
  cdraw.content((8, 13.5), [24 x 24 cells, border ring walled], size: 6pt)
  // interior wall cells, fill luma 205
  let wall(wx, wy) = { cdraw.rect((sc(wx), sc(wy)), (sc(wx + 1), sc(wy + 1)), fill: luma(205), stroke: luma(140), radius: 0.01) }
  wall(11, 11); wall(11, 12); wall(12, 11); wall(12, 12)
  wall(6, 6); wall(17, 6); wall(6, 17); wall(17, 17)
  wall(6, 11); wall(12, 6); wall(17, 12); wall(11, 17)
  wall(11, 6); wall(6, 12); wall(12, 17); wall(17, 11)
  // orb homes
  let orb(ox, oy) = { cdraw.circle((sc(ox), sc(oy)), radius: 0.4, fill: luma(235), stroke: luma(100)) }
  orb(5, 5); orb(19, 5); orb(19, 19); orb(5, 19)
  orb(5, 12); orb(12, 5); orb(19, 12); orb(12, 19)
  // spawns and circles
  cdraw.rect((sc(8) - 0.35, sc(12) - 0.35), (sc(8) + 0.35, sc(12) + 0.35), fill: luma(245), stroke: luma(60))
  cdraw.rect((sc(16) - 0.35, sc(12) - 0.35), (sc(16) + 0.35, sc(12) + 0.35), fill: luma(245), stroke: luma(60))
  cdraw.content((sc(8), sc(12) + 0.75), [p0], size: 6pt)
  cdraw.content((sc(16), sc(12) + 0.75), [p1], size: 6pt)
  cdraw.circle((sc(12), sc(8)), radius: 0.45, fill: luma(205), stroke: luma(100))
  cdraw.circle((sc(12), sc(16)), radius: 0.45, fill: luma(205), stroke: luma(100))
  cdraw.line((sc(8) + 0.45, sc(12)), (sc(8) + 1.2, sc(12)), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((sc(16) - 0.45, sc(12)), (sc(16) - 1.2, sc(12)), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.circle((8.6, 0.45), radius: 0.4, fill: luma(235), stroke: luma(100))
  cdraw.content((9.3, 0.45), [orb home], size: 6pt)
  cdraw.rect((11.4, 0.25), (12.1, 0.65), fill: luma(205), stroke: luma(140), radius: 0.01)
  cdraw.content((12.45, 0.45), [wall cell], size: 6pt)
})

The bodies carry the material parameters the solver will need: player
boxes have half extents 0.45, inverse mass 1.0, restitution 0.2, coulomb
friction 0.3. The neutral circles have inverse mass 0.5, restitution 0.5,
so a ram transfers momentum into them and they bounce harder off walls
than the players do. Boxes are torque-free by design: heading is kinematic,
set only by the turn control, and every contact applies central impulses
with no torque arms. That is a documented simplification, and it keeps the
impulse solver plain while the interesting dynamics stay in the
translations.

#listing("math/capstone/src/state.c", first: 34, last: 86, caption: [state.c, game_init: both player boxes, both passive circles, and the eight orb homes as two d4 orbits])

== modules and disciplines

The capstone is 8 core modules plus a driver, 1230 lines of core C in
the .c files plus the 81-line shared header, 1311 with the header the
table below counts, every file under the 400 sloc per file rule, and the
split follows the book's own chapter boundaries so each module has
exactly one discipline to answer for. The design rule is the pure core
and impure shell of chapter
#xref-to("math", "pipeline"): no mutable globals anywhere in the core, no
heap, no clock reads, every random stream an explicit struct handed down
the call chain, and the driver plus the allegro host own the two search
trees as their impure state.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*module*], [*lines*], [*role*], [*discipline*]),
  [common .h], [81], [vec2, xorshift64, fnv1a], [ch 2 bit-exact kernels],
  [state], [287], [adt game state, wall map, both hashes], [ch 26, ch 16-17],
  [collide], [302], [sat narrow phase, impulse solver], [ch 2, ch 5 vectors],
  [physics], [92], [fixed-step verlet loop], [ch 22 quadrature],
  [astar], [111], [grid search with total-order keys], [ch 15 graphs],
  [mixed], [35], [opening equilibrium, integer sampler], [ch 24 strategic],
  [mcts], [114], [uct over macro windows, group hash], [ch 25 sequential],
  [ai], [183], [macro actions to controls, run_window], [ch 29 one path],
  [main], [106], [headless driver, three modes], [ch 29 impure shell],
)

The layering is one-directional: physics and collide know state, astar
knows common, ai knows all of them, and nothing below ever calls up. The
determinism contracts sit at the seams: contact emission order is fixed
in collide (dynamic pairs by body index, then one wall contact per body,
deepest cell winning ties by scan order), every loop iterates array
indices rather than pointers, there is no qsort anywhere, and the one
random generator is a value passed by pointer. The verification chapter
closes the loop with a discipline-to-module matrix and the tests that
populate it, this chapter only fixes the assignment.

#diagram([the module map: the impure shells on top, decisions, navigation, simulation, and the state layer below, one direction of calls], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.6), t, size: 6pt)
  }
  let impure(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: luma(205), stroke: luma(60), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.6), t, size: 6pt)
  }
  let drop(x, y1, y2) = { cdraw.line((x, y1), (x, y2), stroke: luma(60), mark: (end: ">")) }
  impure(0.8, 9.4, 4.6, [main.c driver])
  impure(6.2, 9.4, 5.4, [allegro host, impure])
  cdraw.content((9.0, 10.9), [owns the search trees], size: 6pt)
  box(0.6, 7.2, 3.4, [ai 183])
  box(4.4, 7.2, 3.4, [mcts 114])
  box(8.2, 7.2, 3.4, [mixed 35])
  box(1.6, 5.0, 4.0, [astar 111])
  box(6.4, 5.0, 5.2, [physics 92, collide 302])
  box(2.6, 2.8, 7.6, [state 287: adt, wall map, hashes])
  box(3.1, 0.8, 6.6, [common 81: vec2, rng, fnv])
  drop(3.1, 9.4, 8.4)
  drop(8.9, 9.4, 8.4)
  drop(6.1, 7.2, 6.2)
  drop(9.9, 7.2, 6.2)
  drop(4.6, 5.0, 4.0)
  drop(9.0, 5.0, 4.0)
  drop(6.4, 2.8, 2.0)
  cdraw.content((1.4, 8.85), [decisions], size: 6pt)
  cdraw.content((2.2, 6.7), [navigation and simulation], size: 6pt)
  cdraw.content((1.4, 4.55), [state], size: 6pt)
  cdraw.content((1.4, 2.45), [kernels], size: 6pt)
})

== the state is a value

Chapter #xref-to("math", "adt") gave C tagged sums, and the game state is
where that pays. `struct game` is one flat value: a step counter, both
scores, 4 bodies in a fixed-capacity array, 8 orbs in another. Each body
is a tagged product, `BODY_BOX` or `BODY_CIRCLE`, sharing the position,
velocity, and material fields and carrying the extents or the radius for
whichever kind it is. No heap, no pointers between parts, no global game.
The whole state copies with one assignment, hashes by walking its bytes
and fields, and replays by re-running the same inputs into a fresh copy.
That is the entire reason the determinism proofs of chapter
#xref-to("math", "capstone-verify") can exist: there is one value to
compare, and it has no identity beyond its contents.

Two hashes live on top of the value. The raw hash folds the exact bits of
every dynamic double through fnv1a-64: 4 bodies times position, velocity,
and heading, plus orb state and scores. It is the strongest bit-identity
probe available, since two runs agree on it if and only if every bit of
every dynamic field agrees. The canonical hash is the chapter
#xref-to("math", "groups") canonical-form trick on top: quantize the
state to integers (positions in 64ths of a unit, velocities in 256ths,
box headings to quarter-turn bins), apply each of the 8 dihedral
transforms as exact integer arithmetic, hash each transform, and take the
minimum. A state and any rotation or reflection of it land on the same
orbit minimum, so the search's transposition table shares entries across
the arena's 8-fold symmetry.

Honesty about what that sharing is: a heuristic, in two ways. First, the
group action is a symmetry of the map and the physics, not of the
player-side semantics. Retreat targets the mover's own corner, (1, 1) or
(22, 22), the opening macros filter orbs by west versus east half, and
rewards are keyed to `score[0]` against `score[1]`. Rotate a live position
90 degrees and it hashes to the same canonical entry while meaning a
different game. Exact in the map and physics layers, approximate as soon
as player-side semantics enter, and chapter
#xref-to("math", "capstone-impl") shows the one place that difference
forced a real fix. Second, quantization can merge physics-distinguishable
states: the position quantum is 1/64 = 0.015625 while a body at cruising
speed drifts 0.0393 units per step, so two states less than half a
quantum apart collide in the table and separate again within one window.
The canonical hash is a sharing mechanism, not an equality proof, and the
chapters below never claim otherwise.

#diagram([the game state as one value: scalar bookkeeping, a tagged body array, and an orb array, everything fixed capacity], length: 13pt, {
  let cell(x, y, w, t, hot) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: if hot { luma(205) } else { luma(235) }, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.rect((0.6, 3.0), (12.6, 9.2), fill: luma(245), stroke: luma(60), radius: 0.02)
  cdraw.content((6.6, 8.8), [struct game], size: 6.5pt)
  cell(1.2, 7.2, 1.8, [step], false)
  cell(3.4, 7.2, 1.8, [seed], false)
  cell(5.6, 7.2, 2.0, [score 2], false)
  cdraw.content((9.6, 7.7), [uint32, u64], size: 6pt)
  cdraw.content((9.6, 7.2), [int8 each], size: 6pt)
  cell(1.2, 5.4, 2.4, [box p0], true)
  cell(4.0, 5.4, 2.4, [box p1], true)
  cell(6.8, 5.4, 2.6, [circle], false)
  cell(9.8, 5.4, 2.6, [circle], false)
  cdraw.content((6.6, 6.8), [bodies 4: kind tag, pos, vel, acc, heading, material], size: 6pt)
  cdraw.rect((1.2, 3.6), (11.6, 4.6), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((6.4, 4.1), [orbs 8: home vec2, taken bool, respawn uint16], size: 6pt)
  cdraw.content((6.6, 2.3), [copy with one assignment, hash by walking fields, replay from a fresh copy], size: 6pt)
})

#listing("math/capstone/src/state.h", first: 9, last: 38, caption: [state.h, the tagged body, the orb, and the whole game as flat fixed-capacity values])

== the numerics budget

Before any physics code existed, the budget was fixed, and it reads like a
contract from chapters #xref-to("math", "error") and
#xref-to("math", "quadrature"). One timestep, $"DT" = 1\/120$, declared
exactly once in common.h and used everywhere, because two modules that
disagree about the step size cannot agree about anything downstream. The
integrator is velocity verlet, one force evaluation per step, chosen for
the bounded energy wobble chapter 22 pinned at $E_0 (h omega)^2\/4$ rather
than the euler drift. Drag is an explicit per-step multiply, $1 -
"DAMP" dot "DT"$ with $"DAMP" = 1$, outside the verlet force so the
integrator itself stays clean.

The tolerance policy has three tiers, and every comparison in the test
suite declares which tier it is in. Analytic pins: hand-computed or
offline-computed constants compared inside a stated epsilon, 1e-12 for
values derived in exact arithmetic, 1e-9 where a wall bounce accumulates
more rounding. Relational pins: two runs of the same inputs must agree on
the raw hash, which is bit equality on every dynamic double, no epsilon
at all. Witnessed pins: numbers that come from long deterministic runs,
like search strength counts, pinned from the binary and flagged as such
in the test headers, because no short derivation reproduces them.

The determinism policy is a list of prohibitions backed by chapter 2's
lane discipline: no `rand()`, no `time()`, no heap addresses feeding
order, no qsort (whose comparison ties are library business), no
`-ffast-math`, x86-64 sse2 as the evaluation lane with no x87 excess
precision. Every stochastic need is the explicit xorshift64 struct that
chapters #xref-to("math", "strategic") and #xref-to("math", "sequential")
already pinned, seeded through fnv1a so seed 0 still yields a nonzero
stream. The two numbers of the budget: $"DT" = 1\/120$ exactly, and a
full-thrust box tops out at speed 4.7145560438758594 after 360 steps,
inside the $"ACC"\/"DAMP" = 5$ bound, as chapter
#xref-to("math", "capstone-impl") traces step by step.

#diagram([the three pin tiers: analytic constants inside a stated epsilon, relational bit equality across runs, witnessed numbers pinned from the deterministic binary], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.6), t, size: 6pt)
  }
  cdraw.content((7.1, 8.6), [a claim needs a check], size: 6.5pt)
  box(0.2, 6.6, 4.4, [analytic pin])
  box(4.9, 6.6, 4.4, [relational pin])
  box(9.6, 6.6, 4.4, [witnessed pin])
  box(0.2, 4.8, 4.4, [exact offline math])
  box(4.9, 4.8, 4.4, [two runs, one seed])
  box(9.6, 4.8, 4.4, [one pinned run])
  box(0.2, 3.5, 4.4, [j = 1.5 at 1e-12])
  box(4.9, 3.5, 4.4, [raw hash equal])
  box(9.6, 3.5, 4.4, [flagged in test])
  cdraw.line((2.4, 6.6), (2.4, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.1, 6.6), (7.1, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 6.6), (11.8, 6.0), stroke: luma(100), mark: (end: ">"))
})

#listing("math/capstone/src/common.h", first: 14, last: 27, caption: [common.h, every timing constant declared once, including the fixed timestep the whole core shares])

== the opening book and the search

The ai is two systems with one interface: a macro id per window. During
the opening, 360 steps = 6 windows, each player follows a mixed strategy
over 3 openings, rush west, rush east, or guard. The payoff table is the
orb differential after the opening, [[2, 0, 1], [0, 3, 2], [1, 2, 0]],
solved offline in exact rationals: value 11/9 for player 0, both optimal
mixes (5, 3, 1) over 9. The runtime never floats the game theory, chapter
#xref-to("math", "strategic") discipline: the C carries the integers and
an integer-comparison sampler, and the test suite re-proves optimality
with the saddle certificate, every row against the column mix paying
exactly 11 and every column against the row mix conceding exactly 11.

The dry run: `rng_seed(1)` draws the pinned sequence 1, 0, 2, 0, 0, 1, 0,
0, 1, 0, 1, 0 over 12 samples, and 6000 draws give counts 3321, 2022,
657, the 5:3:1 mix showing through the sampling.

Midgame windows belong to monte carlo tree search over the macro actions.
The design constraints come straight from chapter
#xref-to("math", "sequential"): information is perfect, so the search is
a sequential-move tree where player 0 commits a window and player 1
answers, the zero-iteration limit of that tree being exactly the rollback
induction of chapter 25. Nodes live in a fixed open-addressing
transposition table, 2048 slots, keyed by the canonical group hash mixed
with a mover byte, so rotated and reflected equal positions share one
entry. Rewards are integer half-wins, 0, 1, or 2, so tree statistics are
exact by construction and bit-reproducible. Budgets are counts, never
clock reads: 160 iterations, 4 windows of explicit tree, 2 random
playout windows past the frontier, expansion of the first untried action
in index order, ucb ties to the lowest index.

One design fact is stated here and measured in chapter
#xref-to("math", "capstone-verify"): the tree models the window as
sequential, the mover acting while the opponent parks on guard, while
live play and the playouts run both players' macros through the same
window simultaneously. That idealization is deliberate, it keeps the
tree small and the code one path, and the verification chapter discloses
what it costs. And the game has a structural first-mover advantage:
player 0 commits first in the tree and the payoff table is player-0
sided, so selfplay results lean p0 by construction, not by tuning.

#diagram([the decision pipeline: one macro id per window, from the sampled opening book or the 160-iteration search, into the single execution path], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  let dec(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(205), stroke: luma(60), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  box(0.2, 7.2, 2.9, [game state])
  dec(4.0, 7.2, 3.0, [in opening?])
  box(8.2, 8.2, 3.4, [sample once, hold: book])
  box(8.2, 6.2, 3.4, [mcts_decide, 160 iters])
  cdraw.line((3.1, 7.75), (4.0, 7.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.0, 8.1), (8.2, 8.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.4, 8.45), [yes], size: 6pt)
  cdraw.line((7.0, 7.4), (8.2, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.4, 6.85), [no], size: 6pt)
  cdraw.line((9.9, 8.2), (9.9, 7.3), stroke: luma(100), mark: (end: ">"))
  box(4.0, 4.6, 7.6, [one macro id in {seek, ram, retreat, guard}])
  cdraw.line((6.0, 6.2), (6.0, 5.7), stroke: luma(100), mark: (end: ">"))
  box(4.0, 2.9, 7.6, [run_window: 60 physics steps, replan every 30])
  cdraw.line((7.8, 4.6), (7.8, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.6, 2.2), [search, live play, and playouts all execute here], size: 6pt)
})

#listing("math/capstone/src/ai.h", first: 11, last: 35, caption: [ai.h, the macro enum with two book-only rushes, and run_window, the one execution path the core exports])

== two lanes, one truth

The core builds with clang on the msvc abi and links the sdk's static
ucrt. The allegro host, a windowed front end with an offscreen bench
mode, builds with gcc 15 on mingw, because the allegro monolith is
mingw-flavored and the clang lane cannot link it. Two lanes, one truth:
the host never re-implements core logic, it calls the same objects, and
its bench mode runs the exact headless rollout, printing the identical
rolling hash plus a render checksum, so the pinned hash values witness
lane agreement bit for bit.

The one real hazard on that road is the libm. The core is cross-libm
fragile by construction: it computes `sin`, `cos`, and `atan2` on
arbitrary arguments, and different c runtimes return different bits for
those. The mingw lane resolves the double transcendentals through
msvcrt.dll, where `sin(pi)` comes back 0x3ca1a60000000000, off by a
relative 3.3e-5, roughly 15 bits, while the core's ucrt gives the
correctly rounded 0x3ca1a62633145c07. Player 1
starts at heading exactly $pi$, so the raw-bit state hash diverged on
step 0, 0xe698373cf0161dd6 against the pin 0x81fb1cc382429465, the first
time the cross-lane gate ran. The host's answer is a routing shim:
define the three functions so the core objects resolve them through
ucrtbase.dll, probed bit-identical to the core's static ucrt, and exit
loudly if that dll cannot load rather than compute quietly wrong bits.
The durable fix, pinning the trig inside the core, was deliberately left
undone, and chapter #xref-to("math", "capstone-verify") carries the
honest line: lane equality is witnessed for every heading the pinned
rollouts generate, it is not a proof over all inputs.

#diagram([two build lanes over one core: the clang-built driver and the gcc-built host, their bench hashes meeting at the pinned value through the ucrt routing], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  let core(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(205), stroke: luma(60), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  box(0.4, 8.6, 4.6, [clang, msvc abi, ucrt])
  box(6.6, 8.6, 5.4, [gcc 15, mingw, allegro])
  box(0.4, 6.8, 4.6, [arena.exe, driver])
  box(6.6, 6.8, 5.4, [host --bench, offscreen])
  core(0.6, 4.6, 6.6, [core objects, src minus main])
  box(8.0, 4.6, 4.2, [trig.c: sin cos atan2])
  cdraw.content((10.1, 4.05), [to ucrtbase.dll], size: 6pt)
  cdraw.line((2.7, 8.6), (2.7, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.3, 8.6), (9.3, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.7, 6.8), (3.4, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.3, 6.8), (6.8, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.1, 6.8), (10.1, 5.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((6.4, 3.2), [both print steps=1200 ... hash=0x81fb1cc382429465], size: 6pt)
  cdraw.line((4.0, 4.6), (5.0, 3.7), stroke: luma(100), mark: (end: ">"))
})

#listing("math/capstone/host/main.c", first: 56, last: 84, caption: [host main.c, bench_mode: the headless rollout plus one offscreen render per step, printing the core hash line and a pixel checksum])

The design is now complete on paper: a symmetric arena, a value-typed
state, a budgeted numerics contract, a two-part ai over macro windows,
and two lanes pinned to one truth. Chapter
#xref-to("math", "capstone-impl") builds every module and walks the
pinned numbers through each one.

sources: arena and interface facts read from the committed capstone
source, books/math/capstone/src common.h, state.h, state.c, physics.h,
ai.h, main.c and books/math/capstone/host main.c, trig.c, 2026-09-22.
Design bridges quote the corpus's own chapters: error for the tolerance
tiers, quadrature for the verlet energy bound, groups and actions for
the d4 canonical form, strategic for the mixed opening, sequential for
the tree, adt for the tagged state, pipeline for the pure core and
impure shell. No external pages fetched for this chapter, none cited.
All pins witnessed by `pwsh -NoProfile -File playground/math-capstone/build.ps1`,
64 checks plus the replay and twice-run driver gates, format clean, and
`pwsh -NoProfile -File tools/run-math-capstone.ps1`, host bench 7:1200
matching arena.exe bit for bit, both run green on 2026-09-22.
