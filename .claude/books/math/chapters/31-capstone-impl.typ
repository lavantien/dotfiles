#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= capstone: the arena game, implementation

The design of chapter #xref-to("math", "capstone-design") now turns into
1230 lines of core C in the .c files plus the shared header the design
chapter counts, and this chapter walks each module with the numbers its
tests pin: the fixed verlet step and its oscillator fixture, the
separating axis narrow phase and the impulse solver behind it, the grid
search with its total-order ranking key, the quantized group hash under
the tree search, and the allegro host that renders the same bits. Every
behavioral claim below is one of the 64 checks in the capstone test suite
or one of the host gates, both run green on 2026-09-22
(`pwsh -NoProfile -File playground/math-capstone/build.ps1` and
`pwsh -NoProfile -File tools/run-math-capstone.ps1`), or is a sentence
read from the committed source it describes. Two bugs the pins caught are
retold here at full length because they are the chapter's real content:
what determinism discipline buys is loud failures, and both failures were
loud.

== the fixed step

One `physics_step` is a fixed stage sequence over the state: controls
become accelerations, then the velocity verlet half kick, the drift, the
contact solve in two passes, the closing half kick, one drag multiply,
the orb rules, and the step counter. The order is the contract. Every
module that touches bodies runs in body index order, the two verlet
halves are exposed functions so the chapter
#xref-to("math", "quadrature") oscillator fixture can drive the exact
production integrator with a spring instead of controls, and the drag
multiply is outside the force evaluation so the integrator stays plain
verlet.

#listing("math/capstone/src/physics.c", first: 72, last: 92, caption: [physics.c, physics_step: the fixed stage order, both verlet halves visible, drag as one explicit multiply])

The oscillator gate runs 2400 steps of $a = -4 q$ through those halves
with $"DT" = 1\/120$, so $h omega = 1\/60$ and $E_0 = 2$. Energy ends at
1.9999229536874537, and the worst deviation over the whole run is
1.3888781008541962e-4. The chapter 22 bound is $E_0 (h omega)^2\/4 =
1\/7200 = 1.3888888... times 10^-4$: the measured worst sits at ratio
0.9999922 of the bound, strictly inside it. That phrasing is deliberate.
The bound is an inequality, the fixture lands a hair under it, and the
test name that says "equals" is the one wording the suite gets wrong,
which is why this book writes "within". The same fixture runs the time
reversibility probe, run 1200 steps, flip the velocity, run 1200 more,
flip back: the round trip lands on $q = 1.0000000000000018$,
$v = -5.6 times 10^-17$.

The dry run: sustained full thrust from rest, heading aligned, 360 steps.
Each step is kick, kick, multiply by $1 - 1\/120$, so the speed ladder
climbs geometrically toward the fixed point $"ACC" (1 - "DT") =
4.9583...$.

+ After 120 steps the speed is 3.1418912249516135, past 63 percent of
  the way in one second of thrust.
+ After 240 steps it is 4.292895632539598, and after 360 it is
  4.7145560438758594, the test pin, still 0.244 short of the asymptote
  because the approach decays like $e^(-n\/120)$ and the discrete
  leftover after 360 steps is $(119\/120)^360 = 0.049165$ of the gap.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*steps*], [*speed, both kicks*], [*speed, one kick*], [*asymptote gap*]),
  [0], [0], [0], [4.9583],
  [120], [3.1419], [1.5709], [1.8164],
  [240], [4.2929], [2.1464], [0.6654],
  [360], [4.7146], [2.3573], [0.2438],
)

The one-kick column is not a counterfactual from theory, it is the first
real bug. The original step was missing the second half kick, the test
pinned the analytic ladder, and the run came back at exactly half speed,
2.3572780219379648 against 4.7145560438758594. One verlet half missing
halves the per-step impulse, and the terminal-speed pin failed loudly
instead of letting a sluggish arena ship.

#diagram([the half-kick bug as a before and after: speed ladders from the same thrust, the buggy build flattening at exactly half], length: 13pt, {
  let px(n) = { 1.0 + (n / 360.0) * 8.0 }
  let py(v) = { 0.8 + (v / 5.0) * 4.4 }
  cdraw.line((1.0, 0.8), (9.6, 0.8), stroke: luma(140))
  cdraw.line((1.0, 0.8), (1.0, 5.6), stroke: luma(140))
  cdraw.content((5.3, 6.1), [steps of thrust], size: 6pt)
  cdraw.content((0.4, 5.3), [speed], size: 6pt)
  cdraw.line((1.0, py(4.9583)), (9.4, py(4.9583)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((3.4, py(4.9583) + 0.52), [asymptote 4.9583], size: 6pt)
  cdraw.line((px(0), py(0)), (px(120), py(3.1419)), stroke: luma(60))
  cdraw.line((px(120), py(3.1419)), (px(240), py(4.2929)), stroke: luma(60))
  cdraw.line((px(240), py(4.2929)), (px(360), py(4.7146)), stroke: luma(60), mark: (end: ">"))
  cdraw.circle((px(360), py(4.7146)), radius: 0.4, fill: luma(205), stroke: luma(60))
  cdraw.content((10.3, py(4.7146)), [4.7146], size: 6pt)
  cdraw.line((px(0), py(0)), (px(120), py(1.5709)), stroke: luma(100))
  cdraw.line((px(120), py(1.5709)), (px(240), py(2.1464)), stroke: luma(100))
  cdraw.line((px(240), py(2.1464)), (px(360), py(2.3573)), stroke: luma(100), mark: (end: ">"))
  cdraw.circle((px(360), py(2.3573)), radius: 0.4, fill: luma(245), stroke: luma(100))
  cdraw.content((px(360), py(2.3573) - 0.9), [2.3573, one kick], size: 6pt)
})

#callout("verify", "THE BOUND IS AN INEQUALITY",
  [The oscillator worst deviation is 0.9999922 times $E_0 (h omega)^2\/4$,
  inside the chapter 22 bound, not on it. Writing the fixture result as
  an equality is the classic drift from "at most" to "exactly" that
  review exists to catch, and this suite's own test name carries that
  wording fault as a standing reminder. Quote the ratio, keep the
  inequality.])

#listing("math/capstone/src/test_physics.c", first: 60, last: 81, caption: [test_physics.c, the oscillator gate on the production halves: end energy, worst deviation, and the flip-run-flip round trip])

== narrow phase: the separating axis test

Two convex shapes are disjoint if any single axis separates them, so the
narrow phase tests the four box axes, $u_1$, $v_1$, $u_2$, $v_2$, in that
fixed order and keeps the first minimum overlap as the contact normal.
The projection of an oriented box onto an axis $t$ is
$"half"_w |u dot t| + "half"_h |v dot t|$, and the overlap on that axis
is $p_1 + p_2 - |d dot t|$ with $d$ the center offset. Any axis with
overlap at or under 0 exits with no contact, which is the separating
axis theorem doing the work of chapter #xref-to("math", "inner") in
four lines. Circles against boxes and against wall cells
use the closest-point clamp: project the circle center into the box,
and the contact normal is the unit vector from the clamped point.

Determinism lives in the details around the theorem: axes are tested in
index order, the first minimum wins ties so the normal choice can never
flip between builds, the normal points from the lower body index to the
higher, and the broad phase is a plain axis-aligned bounding box check
per pair in index order. Walls are scanned once per body over the cells
its bounding box touches, and only the deepest overlap survives, ties by
scan order, so one body contributes at most one wall contact per step.

#listing("math/capstone/src/collide.c", first: 28, last: 51, caption: [collide.c, sat_boxes: four axes in fixed order, first minimum wins, normal from the sign of the offset])

The dry run: the head-on gate. Two boxes with half extents 0.45 park at
$x = 10.0$ and $x = 10.85$, touching distance 0.9, with velocities
$+1$ and $-1$, controls neutral, restitution 0.5 both, friction 0.

+ The kicks add nothing, the drift moves each body $1\/120 = 0.008333$,
  so the gap closes to 0.833333 and the sat overlap is
  $0.9 - 0.833333 = 0.066667$, the pinned penetration.
+ The solver fires once in the gate: relative normal velocity $-2$, so
  $j = -(1 + 0.5)(-2)\/(1 + 1) = 1.5$, and the velocities swap to
  $plus.minus 0.5$ before the drag multiply lands them at
  $plus.minus 0.49583333333333335$.
+ The position pass moves each body half of $0.4 (0.066667 - 0.005)$
  weighted by inverse mass, and the final positions pin at 9.996 and
  10.854 with the momentum sum exactly 0.

The same one-step machinery pins the wall rebound: a box at
restitution 0.2 sliding into the west border at $-1$ meets the wall
contact whose restitution mixes to $0.5 (0.2 + 0) = 0.1$, takes
$j = 1.1$, and comes back at $+0.099166666666764$ having been pushed out
to $x = 1.353$.

#diagram([the sat between two boxes: each candidate axis with the projected radii and the gap, the minimum overlap becoming the contact normal], length: 13pt, {
  cdraw.rect((1.2, 1.6), (4.2, 4.0), fill: luma(245), stroke: luma(100), radius: 0.02)
  cdraw.content((2.7, 2.8), [box 1], size: 6pt)
  cdraw.rect((3.9, 2.2), (7.1, 4.6), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((5.7, 3.5), [box 2], size: 6pt)
  cdraw.content((5.6, 1.0), [overlap region shaded], size: 6pt)
  cdraw.rect((3.9, 2.2), (4.2, 4.0), fill: luma(205), stroke: none)
  cdraw.line((1.2, 0.8), (2.4, 0.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.1, 0.8), [u1], size: 6pt)
  cdraw.line((1.2, 0.3), (1.7, 1.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((2.4, 0.35), [v1], size: 6pt)
  cdraw.line((8.0, 2.4), (9.2, 2.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.9, 2.4), [u2], size: 6pt)
  cdraw.line((8.0, 3.4), (8.5, 4.3), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.2, 4.2), [v2], size: 6pt)
  cdraw.content((9.6, 1.5), [min overlap], size: 6pt)
  cdraw.content((9.6, 1.0), [axis wins], size: 6pt)
})

== sequential impulses

Contacts become velocities through a fixed iteration budget, 8 passes
over the contact list in emission order. Each pass walks the same three
questions per contact. Is the approach speed $v_n$ negative? If not,
nothing happens, which is what makes resting contacts rest. The
restitution is the mean of the two bodies' coefficients, and it zeroes
out below $"REST_THRESH" = 0.5$ approach speed so micro-bounces do not
jitter stacks. The normal impulse applies against the accumulated
impulse, clamped nonnegative so a contact can push but never pull. Then
friction: the tangent direction of the relative velocity, the impulse
bound $mu dot j_n$ with $mu$ the geometric mean of the two friction
coefficients, clamped symmetrically.

The position pass is one sweep, not iterated: a baumgarte-style
correction of $"CORR" ("pen" - "slop")$ with $"CORR" = 0.4$ and
$"SLOP" = 0.005$, split by inverse mass. The split is where the second
bug story lives. The C moves each body by $"corr" dot "inv_mass"$, the
mass-weighted split every textbook uses. The python mirror of the pin
moved the first circle by the full corr, and the pin came back
disagreeing with the C at the sixth decimal. The pin was wrong, the
solver was right, and the dry run proves it by symmetry.

The dry run: the two circles, radius 0.8, parked overlapping at
$(12, 8)$ and $(12.9, 8)$, a 0.7 penetration with zero velocity.

+ Both static, so $v_n = 0$, no velocity impulse ever fires, friction
  sees $j_n = 0$ and bounds itself to nothing.
+ The correction is $0.4 (0.7 - 0.005) = 0.278$, and with inverse
  masses 0.5 and 0.5 each body takes $0.278 dot 0.5 = 0.139$.
+ The circles land at 11.861 and 13.039 exactly, both velocities still
  zero, which is the resting-contact gate: overlap resolved, no energy
  invented.

#listing("math/capstone/src/collide.c", first: 244, last: 282, caption: [collide.c, one contact inside the velocity loop: restitution gate, accumulated impulse clamp, coulomb friction bound])

#diagram([one contact in one solver pass: the three gates in order, approach speed, restitution threshold, friction bound], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  let dec(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(205), stroke: luma(60), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  dec(0.2, 7.4, 3.2, [vn < 0?])
  box(4.4, 8.2, 3.4, [no: skip, rest])
  box(4.4, 6.4, 3.4, [e = mean or 0])
  box(4.4, 4.6, 3.4, [j, clamp acc >= 0])
  box(4.4, 2.8, 3.4, [friction: mu jn])
  cdraw.line((3.4, 7.95), (4.4, 8.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.7, 8.4), [no], size: 6pt)
  cdraw.line((3.4, 7.6), (4.4, 6.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.7, 7.05), [yes], size: 6pt)
  cdraw.line((6.1, 6.4), (6.1, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.1, 4.6), (6.1, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.1, 2.1), [8 iterations, contact order fixed], size: 6pt)
})

#callout("pitfall", "WHEN THE PIN AND THE CODE DISAGREE",
  [The positional-correction mirror moved one circle by the full corr
  while the C moved it by $"corr" dot "inv_mass"$. The instinct on a red
  pin is to fix the C toward the mirror. The right move is to re-derive
  both: the mass-weighted split conserves the center of mass, the full
  shift does not, so the mirror was the bug. A pin is a hypothesis about
  the code, not authority over it.])

== deterministic grid pathfinding

Macro steering needs paths on the 24 by 24 wall grid, and the module is
a textbook 4-connected a\* with manhattan heuristic, admissible and
consistent on unit costs, plus one idea that makes it reproducible: the
frontier is ranked by a single `uint64` key packing $f$, then
$4095 - g$, then the cell index. Equal-cost ties therefore pop in a
fixed order, deeper nodes first, then lower index, forever, with no
qsort and no pointer order anywhere. Chapter #xref-to("math", "graphs")
supplies the order theory, the dsa book owns a\* as an algorithm, and
this module owns only the determinism argument.

The pins come from an independent breadth-first search over the same
grids. Corner to corner, $(1, 1)$ to $(22, 22)$, costs 42. The west
column run $(1, 1)$ to $(1, 22)$ costs 21 straight cells. Into the
center pocket, 5. The serpentine corridor, two wall rows with one gap
each, forces its unique 65-step snake, and a goal sealed by an
8-neighbor wall ring returns -1, the unreachable marker. Repeated
queries after unrelated traffic on the same context reproduce the g and
parent arrays exactly, which is the no-hidden-state gate for the
navigator.

The dry run: spawn to spawn. Player 0 sits at cell (8, 12), player 1 at
(16, 12), and the manhattan distance is 8. But cells (11, 12) and
(12, 12) are the center block, so row 12 is plugged between the spawns.

+ Drop to row 13 at x = 10, cross under the block, climb back at
  x = 13: the walk is 2 + 1 + 3 + 1 + 3 = 10 moves.
+ The pin agrees, 10, and the test says it in one line: manhattan would
  be 8, the arena makes the honest price 10.

#listing("math/capstone/src/astar.c", first: 46, last: 60, caption: [astar.c, relax: one edge, the ranking key recomputed from g and the manhattan remainder, ties pre-ordered in the key bits])

#diagram([spawn to spawn on rows 12 and 13: the straight manhattan line blocked by the center block, the 10-step detour below it], length: 13pt, {
  // world x 8..16 maps to canvas 2.0..11.9, cell width 1.24
  let wx(x) = { 2.0 + (x - 8.0) * 1.24 }
  // row 12 band 5.2..6.4, row 13 band 2.6..3.8, generous corridor between
  cdraw.rect((2.0, 5.2), (12.4, 6.4), fill: luma(245), stroke: luma(140), radius: 0.01)
  cdraw.rect((2.0, 2.6), (12.4, 3.8), fill: luma(245), stroke: luma(140), radius: 0.01)
  cdraw.content((3.9, 6.75), [row 12], size: 6pt)
  cdraw.content((2.8, 4.45), [row 13], size: 6pt)
  // the center block, cells 11..12 of row 12, kept clear of the path corner
  cdraw.rect((wx(11) + 0.2, 5.2), (wx(13) - 0.2, 6.4), fill: luma(205), stroke: luma(60))
  cdraw.content((wx(12), 5.8), [wall], size: 6pt)
  // spawns at cells 8 and 16 of row 12
  cdraw.rect((wx(8) - 0.4, 5.35), (wx(8) + 0.4, 6.25), fill: luma(235), stroke: luma(60))
  cdraw.content((wx(8), 6.75), [p0], size: 6pt)
  cdraw.rect((wx(16) - 0.4, 5.35), (wx(16) + 0.4, 6.25), fill: luma(235), stroke: luma(60))
  cdraw.content((wx(16), 6.75), [p1], size: 6pt)
  // the straight manhattan line along row 12, interrupted by the block
  cdraw.line((wx(8) + 0.45, 6.05), (wx(11) - 0.05, 6.05), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((wx(13) + 0.05, 6.05), (wx(16) - 0.45, 6.05), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((wx(12), 7.15), [manhattan 8, blocked], size: 6pt)
  // the detour: row 12 to x = 10, down through the corridor, row 13 across,
  // up at x = 13, home to p1, all with real clearance
  cdraw.line((wx(8) + 0.45, 5.55), (wx(10), 5.55), stroke: luma(60))
  cdraw.line((wx(10), 5.55), (wx(10), 3.2), stroke: luma(60))
  cdraw.line((wx(10), 3.2), (wx(13), 3.2), stroke: luma(60))
  cdraw.line((wx(13), 3.2), (wx(13), 5.55), stroke: luma(60))
  cdraw.line((wx(13), 5.55), (wx(16) - 0.5, 5.55), stroke: luma(60), mark: (end: ">"))
  cdraw.content((wx(11.5), 2.05), [a\* cost 10: 2 + 1 + 3 + 1 + 3 moves], size: 6pt)
})

== search over the group hash

The midgame search keys its transposition table on the canonical hash
of chapter #xref-to("math", "capstone-design"), and the implementation
is where the quantization meets the group. Positions quantize to 64ths
of a unit on a side of $24 dot 64 = 1536$ quanta, velocities to 256ths,
box headings to quarter-turn bins, and each of the 8 dihedral transforms
then acts as exact integer arithmetic: points as $(x, y) -> (1536 - y,
x)$ and friends, vectors without the offset, headings as $k -> k + 1
"mod" 4$ under rotation and the negation family under reflection. Eight
fnv folds later the minimum is the canonical value.

The dry run: the initial state at seed 1. Its raw hash pins at
0xc0aeb7a9977e46a3. The 8 orbit hashes pin at 0xc15c7a1642de31fc,
0x051763866518b764, 0xa587de6a2bbf29a8, 0xc5e381f336ff4230,
0x5ca491b603e1ee30, 0x86e572001a2b6a98, 0x1b78945b0dda51b0,
0xf42f1e75839a1140. The minimum is the second, the quarter turn, so
0x051763866518b764 is the canonical hash, and the test builds the exact
r90 and flip-y transforms of the state in doubles and checks both land
on that same canonical value while their raw hashes stay distinct.

The third bug is here. The first version of `orbit_hash` applied the
heading transform to every body, circles included. A circle's heading is
a don't-care field, but rotating it changed those bits, so the 8 orbit
hashes of a rotated state no longer matched the original's, symmetric
states stopped sharing, and the canonical equality gate went red. The
fix folds a constant 0 byte for non-box headings: orientation belongs to
boxes, the group action must not act on meaningless fields.

#diagram([the circle-heading bug: rotating a state's meaningless heading bits broke orbit equality, the fix folds them constant], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.content((3.0, 7.9), [before, headings rotated on circles], size: 6.5pt)
  box(0.2, 6.4, 2.6, [state s])
  box(3.6, 6.4, 2.6, [r90 of s])
  box(0.2, 4.6, 2.6, [orbit hash a])
  box(3.6, 4.6, 2.6, [orbit hash b])
  cdraw.content((3.2, 5.1), [!=], size: 7pt)
  cdraw.line((1.5, 6.4), (1.5, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.9, 6.4), (4.9, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.2, 3.7), [canonical gate red], size: 6pt)
  cdraw.content((10.4, 7.9), [after, circles fold 0], size: 6.5pt)
  box(7.6, 6.4, 2.6, [state s])
  box(11.0, 6.4, 2.6, [r90 of s])
  box(7.6, 4.6, 2.6, [orbit hash a])
  box(11.0, 4.6, 2.6, [orbit hash a])
  cdraw.content((10.6, 5.1), [=], size: 7pt)
  cdraw.line((8.9, 6.4), (8.9, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.3, 6.4), (12.3, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.6, 3.7), [canonical gate green], size: 6pt)
})

On top of the hash sits the search proper. Nodes live in a 2048-slot
open-addressing table keyed by the canonical hash mixed with a mover
byte, statistics are integer half-wins so every add is exact, and one
search round is: probe the root, take the first untried action in index
order or else the ucb argmax with ties to the lowest index, run one
window of the mover's macro with the opponent parked on guard, recurse,
back the outcome up as 0, 1, or 2 half-wins. The budgets are counts,
160 iterations, 4 windows of tree, 2 playout windows, and a full table
degrades to playouts rather than failing. The gates: the root records
exactly 160 visits, the action visits sum to it, rewards stay within 2
per visit, two searches from the same seed produce bit-identical root
statistics, and a fresh search after unrelated interference reproduces
them, no hidden state.

#listing("math/capstone/src/mcts.c", first: 66, last: 84, caption: [mcts.c, simulate: probe, choose, run the mover's window, recurse, back up integer half-wins])

#callout("note", "WHAT THE GROUP HASH SHARES",
  [The canonical hash shares table entries across exact symmetries of
  the map and physics. It is exact there and a heuristic above: retreat
  corners and west/east orb filters are fixed by the identity transform
  alone, and rewards are player-keyed, so a rotated position hashes with
  its sibling while meaning a different game. Quantization also merges
  physics-distinguishable states: drift per step 0.0393 against a
  position quantum of 0.015625. The hash is a sharing mechanism, not an
  equality proof, and the strength numbers below ride the deterministic
  binary, not a claim of state uniqueness.])

The strength gate runs four fixed 30-window scenarios against a seeded
random policy from a midgame start: the search's orb leads pin at
(2, 1, 1, 4) over seeds 1 to 4, four wins, zero losses. Those counts are
witnessed-deterministic, pinned from the run and reproduced by the same
binary, which is the honest tier of chapter 30's budget, and chapter
#xref-to("math", "capstone-verify") measures what they do and do not
prove.

== the allegro host

The host is the impure shell: it owns a display, a keyboard, two search
trees, and a timer, and it never re-implements a line of core logic.
Its windowed mode is window-commit play, one macro per 0.5 s against
the search, because `run_window` is the only execution path the core
exports and duplicating per-step steering in the host would fork the one
code path the design forbids. The accumulator advances by $"DT"$ per
timer tick and executes a whole window per 60 ticks, clamped at 2
windows of debt so a stall owes at most one catch-up window. One search
costs tens of milliseconds, load-sensitive, 67 to 95 ms per choose
across measurements, well inside the window's 500 ms of idle time, so
interactive play runs the identical, pinned-strength ai with no
decision gating.

The dry run: one commit window. 60 ticks at $"DT" = 1\/120$ each is
0.5 s of game time, the search inside it costs tens of milliseconds,
and the remainder absorbs the event queue and one rendered frame. A
stall clamps at 2 windows of debt, so the worst catch-up the loop can
owe is a single window, never a burst.

The bench mode is the determinism witness. No display is created, one
memory bitmap receives a render of every step, and the mode prints the
core's exact rolling hash line plus a fnv checksum over the locked
pixels, proof the render actually ran on the same states. The scripted
control pattern and the selfplay loop are mirrored from the core driver
in a few lines each, because one binary owns one `main`, and the pins
make any drift between the copies loud: bench 7:1200 prints
`hash=0x81fb1cc382429465`, byte-matching the clang-built `arena.exe`,
and the selfplay table diffs clean against it.

One accommodation the host makes is structural: the mingw lane resolves
double `sin`, `cos`, and `atan2` through msvcrt.dll, whose bits differ
from the core's ucrt, and player 1 starts at heading exactly $pi$, so
without routing the state hash diverges at step 0. The host defines
those three functions to resolve through ucrtbase.dll, probed
bit-identical to the core's static ucrt, and refuses to run if that dll
is missing. The core stays cross-libm fragile by construction, the
routing is a lane accommodation rather than core logic, and chapter
#xref-to("math", "capstone-verify") puts numbers on both halves.

#listing("math/capstone/host/main.c", first: 191, last: 211, caption: [host main.c, the accumulator loop: one window per 60 dt ticks, both macros committed together through run_window])

#diagram([the windowed loop as a state machine: timer ticks feed the accumulator, whole windows commit, every frame renders], length: 13pt, {
  let st(x, y, t) = {
    cdraw.circle((x, y), radius: 0.9, fill: luma(235), stroke: luma(100))
    cdraw.content((x, y), t, size: 6pt)
  }
  st(1.6, 7.4, [wait])
  st(5.4, 7.4, [tick])
  st(9.2, 7.4, [commit])
  st(12.6, 7.4, [render])
  cdraw.line((2.5, 7.4), (4.5, 7.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.5, 7.7), [event], size: 6pt)
  cdraw.line((6.3, 7.4), (8.3, 7.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.3, 7.7), [acc >= 60 dt], size: 6pt)
  cdraw.line((10.1, 7.4), (11.7, 7.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((12.6, 6.5), (12.6, 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.line((12.6, 5.6), (1.6, 5.6), stroke: luma(60))
  cdraw.line((1.6, 5.6), (1.6, 6.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.1, 5.25), [frame done], size: 6pt)
  cdraw.content((7.1, 4.35), [commit: queued macro + ai_choose, then one run_window], size: 6pt)
  cdraw.content((7.1, 3.55), [clamp: a stall owes one window, never a burst], size: 6pt)
})

Every module now has its numbers on the table. Chapter
#xref-to("math", "capstone-verify") assembles the matrix of disciplines
to modules, runs the determinism proofs across processes and lanes, and
measures the ai honestly.

sources: implementation facts read from the committed capstone source,
books/math/capstone/src physics.c, collide.c, astar.c, mcts.c, ai.c,
state.c, test_physics.c and books/math/capstone/host main.c, 2026-09-22.
Bridge chapters quoted from the corpus's own text: quadrature for the
verlet bound and round trip, inner for the projection arithmetic behind
sat, graphs for the order-theory reading of the ranking key, groups and
actions for the quantized dihedral action, capstone-design for the pin
tiers and module map. No external pages fetched for this chapter, none
cited. All pins witnessed by `pwsh -NoProfile -File playground/math-capstone/build.ps1`,
64 checks plus driver gates, format clean, and `pwsh -NoProfile -File
tools/run-math-capstone.ps1`, host bench 7:1200 matching arena.exe bit
for bit, both run green on 2026-09-22.
