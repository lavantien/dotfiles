#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= capstone: the arena game, verification

The last chapter of the book is an audit. The design of chapter
#xref-to("math", "capstone-design") promised disciplines, the
implementation of chapter #xref-to("math", "capstone-impl") pinned
numbers, and this chapter assembles the evidence: the matrix that maps
every discipline to the module and the test that carries it, the
determinism hash with its three pins proven in-process, cross-process,
and cross-lane, the perturbation and quantization behavior of the state
hash, the ai strength numbers with their caveats stated rather than
buried, the allegro bench gates, and the audit totals. Every behavioral
claim below is one of the 64 checks in the capstone test suite or one of
the host gates, both run green on 2026-09-22 (`pwsh -NoProfile -File
playground/math-capstone/build.ps1` and `pwsh -NoProfile -File
tools/run-math-capstone.ps1`), or a sentence read from the committed
source or the gate output it describes.

== the discipline-to-module matrix

The book taught 29 chapters of mathematics and the capstone owes each of
them a receipt. The matrix below is the accounting: which chapter's
discipline lives in which module, and which capstone test carries the
proof. Reading it by rows says where a chapter went, reading it by
columns says what a module stands on.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*discipline*], [*module*], [*what it contributes*], [*witness*]),
  [ch 2 error], [physics, collide], [exact-bit kernels, tolerance tiers, the sse2 lane], [oscillator and solver pins at 1e-12],
  [ch 22 quadrature], [physics], [fixed timestep, verlet halves, the energy bound], [oscillator gate, 2400 steps],
  [ch 24 strategic], [mixed], [saddle certificate, integer sampler], [test_mixed, 6 checks],
  [ch 25 sequential], [mcts], [sequential-move tree, rollback as limit], [test_mcts root stats],
  [ch 26 adt], [state], [tagged bodies, fixed-capacity value], [test_state init and hash],
  [ch 27 railway], [none], [error track unused, stages return void], [honest empty row],
  [ch 28 monads], [ai], [state threading through explicit arguments], [run_window purity],
  [ch 29 pipeline], [main, host], [pure core, impure shell, two-run gate], [replay mode, bench diff],
  [ch 16-17 groups, actions], [state], [d4 canonical form, quantized orbits], [canonical hash gates],
  [ch 15 graphs], [astar], [total-order ranking, admissible heuristic], [test_astar 12 checks],
)

The two rows that are not rows of credit matter as much as the ones that
are. Chapter #xref-to("math", "railway") taught option and result
plumbing, and the capstone uses none of it: every physics stage returns
void because a fixed-step simulation has no recoverable failure inside a
step, so that discipline appears here as a deliberate empty cell, not an
omission. And chapter #xref-to("math", "monads") contributes no
combinator to the C, only the habit it taught: state moves through
explicit arguments, never static cells, which is why the search trees
live in the driver and the host while the core stays pure. The two
numbers of the matrix: 10 disciplines accounted for across 6 module
groups, and every non-empty cell names one test that would go red if the
discipline regressed.

Read by columns the matrix says what each module stands on. The state
module leans on the algebra chapter for its shape and the group chapters
for its hash, two disciplines in 287 lines, and its 18 checks split
evenly between them. The physics and collision modules are the floating
point book's territory, integrator and tolerance policy, and carry the
largest single suite. The mixed and mcts modules are the game theory
chapters made executable, one as exact integers, the other as a
reproducible stochastic search. The shell column is chapter
#xref-to("math", "pipeline") alone, and it is the column that makes
every other column testable: because the trees and the io live outside
the core, every gate below runs against a pure value.

#diagram([the discipline-to-module matrix: filled cells where a chapter's discipline lands in a module, the railway row honestly empty, the monads row carried by the table above rather than the grid], length: 13pt, {
  let cols = ([state], [phys], [astar], [mixed], [mcts], [shell])
  let rows = ([ch 2], [ch 22], [ch 24], [ch 25], [ch 26], [ch 27], [ch 29], [ch 16], [ch 15])
  let filled = (
    0, 1, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 1, 0,
    1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 0, 0,
  )
  let gx(c) = { 3.0 + c * 2.1 }
  let gy(r) = { 8.8 - r * 0.92 }
  for i in range(cols.len()) {
    cdraw.content((gx(i) + 0.95, 9.4), cols.at(i), size: 6pt)
  }
  for j in range(rows.len()) {
    cdraw.content((2.4, gy(j)), rows.at(j), size: 6pt)
    for i in range(6) {
      let on = filled.at(j * 6 + i) == 1
      cdraw.rect((gx(i), gy(j) - 0.36), (gx(i) + 1.9, gy(j) + 0.36), fill: if on { luma(205) } else { luma(245) }, stroke: luma(140), radius: 0.01)
    }
  }
  cdraw.content((9.2, 0.9), [filled cell: a named test witnesses the mapping], size: 6pt)
  cdraw.content((3.6, 0.15), [ch 27 railway: the whole row empty, by design], size: 6pt)
})

#listing("math/capstone/src/main.c", first: 26, last: 42, caption: [main.c, rollout: the scripted controls, one physics step, and the rolling fnv fold over every per-step raw hash])

== the determinism hash and its three pins

The raw hash folds the exact bits of every dynamic double through
fnv1a-64, step after step, and the driver folds again: a rolling hash
over the per-step raw hashes, so the final value is a witness of the
entire trajectory, not just the endpoint. Two runs agree on it if and
only if every bit of every dynamic field agreed at every step. There is
no epsilon, no tolerance, no probability. That is the relational tier of
the numerics budget doing the heaviest lifting in the book.

Three pins anchor it, each at a different scale. Seed 7, 1200 steps,
one tenth of a game: `steps=1200 score=0:0 orbs_taken=0
hash=0x81fb1cc382429465`. Seed 42, 2400 steps, run twice inside one
process by the replay mode, which also memcmps the whole final state:
`replay ok ... hash=0xc03668ca5b407088`. Seed 1, the full 7200-step
game: `hash=0xfbe9b7d168128e74`. The first pin is the workhorse, the
second adds the in-process double run, the third says a whole game holds
the line.

The dry run: what one pin actually covers. Take the 7:1200 rollout.

+ 1200 physics steps, each folding 4 bodies, 8 orbs, scores, and the
  step counter into the raw hash, then the driver folding that in: on
  the order of $10^5$ double bits and counters chained through fnv.
+ One flipped bit anywhere, a contact order swap, a drag multiply
  reordered, changes every hash after it and the final value, which is
  why the pin is a trajectory witness rather than a final-state
  checksum.

Cross-process: the same binary run twice as separate operating system
processes prints byte-identical output, no allocator or address noise
anywhere in the loop. Cross-lane: the gcc-built allegro host, a
different compiler, runtime, and rendering stack, runs the same rollout
in its bench mode and prints the identical hash line plus a render
checksum, and the runner diffs the two processes directly. The road to
that agreement is the trig routing of chapter
#xref-to("math", "capstone-impl"): without it the mingw lane's msvcrt
`sin(pi)`, 0x3ca1a60000000000 against the core's 0x3ca1a62633145c07,
diverges player 1's heading bits at step 0 and lands the hash on
0xe698373cf0161dd6 instead of the pin. The core remains cross-libm
fragile by construction, the routing is witnessed for every heading the
pinned rollouts and the selfplay table generate, and that is evidence,
not a proof over all inputs.

One detail makes the replay gate stronger than it looks: `game_init`
assigns `*g = (struct game){0}` before filling fields, zeroing the
struct's padding bytes, so the replay's `memcmp` over the whole state
compares padding that the hash never folds. A run could in principle
agree on every folded bit while leaving different garbage in padding,
and this gate closes even that gap. Byte equality of the entire value,
not just the semantic fields, is the standard the driver holds.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*seed*], [*steps*], [*gate*], [*hash*], [*agreement*]),
  [7], [1200], [twice-run, build.ps1], [0x81fb1cc382429465], [process, lane],
  [42], [2400], [replay, memcmp, in-process], [0xc03668ca5b407088], [bits and bytes],
  [1], [7200], [full game, host -Full], [0xfbe9b7d168128e74], [process, lane],
)

#listing("math/capstone/src/state.c", first: 101, last: 124, caption: [state.c, raw_hash: the fnv fold over the exact bits of every dynamic double, score, and orb field])

#diagram([the driver's hash discipline as a state machine: seed to init, the step and fold loop, then three comparison gates closing on the pins], length: 13pt, {
  let st(x, y, t) = {
    cdraw.circle((x, y), radius: 0.9, fill: luma(235), stroke: luma(100))
    cdraw.content((x, y), t, size: 6pt)
  }
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(205), stroke: luma(60), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  st(1.7, 8.0, [init])
  st(5.2, 8.0, [step])
  st(8.7, 8.0, [fold])
  st(12.2, 8.0, [pin])
  cdraw.line((2.6, 8.0), (4.3, 8.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.1, 8.0), (7.8, 8.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((9.6, 8.0), (11.3, 8.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((8.7, 7.1), (8.7, 6.7), stroke: luma(60))
  cdraw.line((8.7, 6.7), (5.2, 6.7), stroke: luma(60))
  cdraw.line((5.2, 6.7), (5.2, 7.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.9, 6.35), [steps left], size: 6pt)
  box(9.0, 4.6, 5.4, [gate 1: run twice, diff bytes])
  box(9.0, 3.2, 5.4, [gate 2: two processes, same line])
  box(9.0, 1.8, 5.4, [gate 3: other lane, same hash])
  cdraw.line((12.2, 7.1), (12.2, 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.line((12.2, 4.6), (12.2, 4.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((12.2, 3.2), (12.2, 2.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.0, 4.9), [0x81fb1cc382429465, seed 7], size: 6pt)
  cdraw.content((3.0, 3.5), [0xc03668ca5b407088, seed 42], size: 6pt)
  cdraw.content((3.0, 2.1), [0xfbe9b7d168128e74, seed 1], size: 6pt)
})

#callout("verify", "THE TWO COMMANDS",
  [`pwsh -NoProfile -File playground/math-capstone/build.ps1` builds
  the core with clang 23 msvc-target at `-std=c23 -Werror -Wall -Wextra`,
  runs all 64 checks, then the driver gates: the in-process replay and
  the twice-run hash pin. `pwsh -NoProfile -File
  tools/run-math-capstone.ps1` builds the allegro host with gcc 15,
  runs the offscreen bench twice, checks the pin, and diffs against
  arena.exe directly. Both were run to green on 2026-09-22 to write
  this chapter. The 7:1200 and 42:2400 pins, the check counts, and the
  bench verdicts above come from their output; the 1:7200 pin comes
  from the arena driver leg of the same session, and the libm bit
  patterns from the core's lane as those pins verify it.])

== perturbation, sensitivity, and the quantization caveat

A hash is only as good as its failure behavior, and the suite probes
both directions. Perturbation: change the controls for 60 steps after a
480-step scripted run and the raw hash of the two trajectories diverges,
the test gate for "different inputs, different states". Sensitivity:
score, one body position, one orb's taken flag each flip the raw hash of
the initial state, so no dynamic field is outside the fold. The dry
run: the pinned hash pair. The seed 1 initial state hashes to
0xc0aeb7a9977e46a3, the same constructor at seed 2 to
0x2fdaffeaa0a14f6c, distinct because the seed itself is a folded field,
and both values pin the fold so a silent field change cannot hide. And
the canonical hash, the one the search shares on, has a coarser honesty.

The quantization caveat, stated with numbers. Positions quantize to
64ths of a unit, a quantum of 0.015625, while a body at cruising speed
drifts 0.0393 per step, about 2.5 quanta. Two states whose positions
differ by less than half a quantum, 0.0078, land in the same bin and
share a table entry even though the physics distinguishes them, and
because the drift carries 2.5 quanta per step they separate again within
one window. The chapters therefore never claim distinct states cannot
share an entry. The claim run in the other direction is the one that
holds: states related by an exact symmetry of the map always share, so
the sharing mechanism never splits what the group joins.

The value-invariance caveat is the same honesty one level up. The
canonical hash is exactly invariant under the 8 dihedral transforms for
the map and physics layers, positions, velocities, box headings, orbs.
The player-side semantics are fixed by the identity transform alone:
retreat targets (1, 1) and (22, 22), the opening macros filter orbs by
west against east, rewards key on `score[0]` minus `score[1]`. A rotated
position hashes with its sibling while meaning a different game, so the
transposition table's sharing is a heuristic in exactly the region where
the search consumes it. Exact below the semantics, approximate above
them, and no impossibility claims anywhere.

#diagram([quantization on a number line: two states inside one 1/64 bin collide, the per-step drift spans two and a half bins], length: 13pt, {
  let qx(v) = { 0.8 + v * 52.0 }
  for i in range(6) {
    cdraw.rect((qx(i * 0.015625), 4.6), (qx((i + 1) * 0.015625), 6.2), fill: if calc.even(i) { luma(245) } else { luma(235) }, stroke: luma(140))
  }
  for i in range(7) {
    cdraw.line((qx(i * 0.015625), 4.6), (qx(i * 0.015625), 6.2), stroke: luma(140))
  }
  cdraw.circle((qx(0.0330), 5.4), radius: 0.4, fill: luma(205), stroke: luma(60))
  cdraw.circle((qx(0.0395), 5.4), radius: 0.4, fill: luma(205), stroke: luma(60))
  cdraw.content((qx(0.0363), 3.9), [one bin, two states], size: 6pt)
  cdraw.line((qx(0.0363), 4.15), (qx(0.0363), 4.55), stroke: luma(100), mark: (end: ">"))
  cdraw.line((qx(0.09), 6.9), (qx(0.09 + 0.0393), 6.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((qx(0.115), 7.25), [drift per step, 0.0393], size: 6pt)
  cdraw.content((0.8, 7.9), [position axis, quanta of 1/64 = 0.0156], size: 6pt)
})

#listing("math/capstone/src/state.c", first: 134, last: 143, caption: [state.c, the quantization constants: 64 position quanta per unit, 256 velocity quanta, arena side 1536, headings in quarter-turn bins])

== ai strength, honestly

The strength numbers sit in the witnessed tier of the numerics budget,
and this section says what that means before quoting them. A
witnessed-deterministic pin is a number pinned from a deterministic run
and reproduced by the same binary on every rerun by construction. It is
not independently recomputed, it moves if any budget constant moves, and
it proves the binary is reproducible, not that the strategy is optimal.

With that said, the measurements. Against a seeded random policy over
four fixed 30-window scenarios from a midgame start, the search's orb
leads pin at (2, 1, 1, 4) over seeds 1 to 4, four wins and zero losses.
Selfplay, search against search over three seeds: player 0 wins all
three at 13:8, 14:11, and 15:11. The timing claim is a cadence claim,
because absolute timings are load-sensitive. One game is 240 chooses,
120 windows of 60 steps times 2 players, and the three-game leg is 720.
Measured per choose across machines and loads: 94.6 ms from a 22.7 s
game, 67.1 ms from a 48.3 s three-game leg, 67.5 ms from a fresh 16.2 s
game, all well inside the 0.5 s commit window, which is why the
windowed host needs no decision gating and runs up no frame debt.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*measurement*], [*opponent*], [*result*], [*tier*]),
  [4 scenarios, 30 windows each], [seeded random], [(2, 1, 1, 4), 4-0], [witnessed],
  [selfplay, seeds 101 to 135], [same search], [p0 3 of 3: 13:8, 14:11, 15:11], [witnessed],
  [one choose, budget 160], [], [67 to 95 ms], [across machines and loads],
  [root statistics, same seed twice], [], [bit identical], [relational],
)

The selfplay sweep is 3 for 3 for player 0, and that number is
structural, not evidence of tuning. Two asymmetries point the same way
by construction: inside the tree, player 0 commits the window and
player 1 answers, and the opening payoff table is player-0 sided, value
11/9 in p0's favor. Sequential games with a first-mover advantage
reward moving first, chapter #xref-to("math", "sequential") in one
line, and this arena is one of them. Three games is also a sample of
three, far too small to price the advantage, exactly large enough to
show its sign.

The search measurements are deterministic the same way the physics pins
are, for the same reason: budgets are iteration counts, never clock
reads, the tree's only randomness is the explicit xorshift stream, and
the statistics are integers. The same seed therefore rebuilds the same
tree bit for bit, which is what the root-statistics gates pin, and it
is why a strength number can be a pin at all. Change any budget
constant, 160 iterations, depth 4, playout 2, the exploration constant,
and every strength number in this section moves, which is the caveat
written into the test header rather than the prose.

The idealization disclosure the design chapter owes in full: the tree
models each window as sequential, the mover executes its macro while the
opponent is parked on guard, but live play and the random playouts run
both players' macros through the same window simultaneously. The tree
therefore evaluates positions under an opponent that is more passive
than any real opponent, including itself in selfplay. The one code path
rule keeps this honest in the way that matters: search, live play, and
playouts all execute windows through the same `run_window`, so the
idealization lives only in the tree's bookkeeping of whose macro runs,
never in the physics both sides share. What it costs in playing strength
is not measured here, and the chapter does not guess.

#diagram([strength measurements as bars: the four scenario orb leads (2, 1, 1, 4) and the three selfplay margins (13:8, 14:11, 15:11), all p0-favored], length: 13pt, {
  let bx(i, v, top) = {
    let x = 1.2 + i * 1.5
    let h = (v / top) * 3.6
    cdraw.rect((x, 1.6), (x + 1.0, 1.6 + h), fill: luma(205), stroke: luma(100))
    cdraw.content((x + 0.5, 1.6 + h + 0.35), str(v), size: 6pt)
  }
  cdraw.line((0.8, 1.6), (12.6, 1.6), stroke: luma(140))
  bx(0, 2, 4); bx(1, 1, 4); bx(2, 1, 4); bx(3, 4, 4)
  cdraw.content((4.2, 0.8), [scenario orb leads, seeds 1 to 4], size: 6pt)
  for (i, s) in ((13, 8), (14, 11), (15, 11)).enumerate() {
    let x = 7.6 + i * 1.7
    let h0 = (s.at(0) / 15.0) * 3.6
    let h1 = (s.at(1) / 15.0) * 3.6
    cdraw.rect((x, 1.6), (x + 0.7, 1.6 + h0), fill: luma(205), stroke: luma(100))
    cdraw.rect((x + 0.75, 1.6), (x + 1.45, 1.6 + h1), fill: luma(245), stroke: luma(100))
  }
  cdraw.rect((11.6, 5.4), (12.3, 5.95), fill: luma(205), stroke: luma(100))
  cdraw.content((12.6, 5.65), [p0], size: 6pt)
  cdraw.rect((11.6, 4.7), (12.3, 5.25), fill: luma(245), stroke: luma(100))
  cdraw.content((12.6, 4.95), [p1], size: 6pt)
  cdraw.content((9.5, 0.8), [selfplay scores, p0 3 of 3], size: 6pt)
})

#listing("math/capstone/src/test_mcts.c", first: 96, last: 125, caption: [test_mcts.c, the strength gate: four scenarios against the seeded random policy with the pinned leads and the 4-0 record])

== the allegro bench

The host gates run through one runner script, and its default pass is
the one wired into the corpus verify: build the host with gcc 15 against
the pinned allegro monolith, run the offscreen bench at seed 7 for 1200
steps twice, check the pin 0x81fb1cc382429465, and diff the output line
against the clang-built arena.exe directly, about 20 seconds end to end.
The full gate adds the two longer rollouts, 42:2400 and the whole game
1:7200, both arena-matched, and the selfplay table diff against the core
driver, about 3 minutes.

The bench output carries two numbers per run, and both matter. The
`hash=` line is the core's rolling trajectory hash, identical across
lanes. The `render=` line is an fnv checksum over the locked pixels of
the final framebuffer, proof the offscreen renderer really walked the
same states rather than skipping them, and it is identical on repeated
runs too. The windowed mode has no pin, human input is entropy by
design, so its determinism claim rests on the bench and selfplay
witnesses sharing its code paths, plus a smoke run: seed 7 with 600
frames exits cleanly at `steps=600 score=1:0` in 5.6 seconds of wall
time, which is real-time pacing at 120 hz with all 10 ai searches
absorbed inside the cadence, no frame debt.

Two housekeeping rules keep the gate honest. The executables build and
run from a temporary directory with the allegro toolchain directory
prepended to `PATH`, nothing is copied beside the binaries, so a stale
dll can never leak a wrong libm into a green run. And the accumulator
clamps its debt at 2 windows, so a long stall replays at most one
catch-up window instead of a burst that could mask a timing dependence
inside a supposedly pinned loop.

The hud fits because it is bounded in code, not eyeballed: the builtin
font advances 8 pixels per glyph on a 384-pixel view, 47 characters of
room, line 1 truncates seeds past 7 digits to their low 7 behind an
ellipsis and drops the phase word when the line would still pass 47,
scores are `int8_t` so their field cannot grow, and the worst surviving
line is 46 characters, 368 of the 384 pixels. Determinism grep on the
host source finds no clock or randomness calls feeding state, the one
hit being a timer event source name, a substring false positive, and
the timer only paces the accumulator.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*measurement*], [*value*], [*gate*], [*what it rules out*]),
  [bench 7:1200, twice], [identical lines], [default runner], [nondeterministic render path],
  [render checksum, twice], [identical], [default runner], [skipped offscreen frames],
  [windowed smoke, 600 frames], [5.6 s, steps=600, score 1:0], [--frames exit], [frame debt under search load],
  [hud worst line], [46 chars, 368 of 384 px], [clamped in hud_lines], [clipped hud strings],
  [selfplay diff, 3 games], [table identical to arena.exe], [-Full runner], [steering path divergence],
)

#diagram([the three pinned rollouts on a steps axis, each with its lane-agreement marks: run twice in-process, two processes, two build lanes], length: 13pt, {
  let sx(n) = { 1.6 + (n / 7200.0) * 9.6 }
  cdraw.line((1.6, 2.0), (11.4, 2.0), stroke: luma(140), mark: (end: ">"))
  cdraw.content((6.4, 1.4), [steps of game time], size: 6pt)
  let pin(y, n, t) = {
    cdraw.line((sx(n), 2.0), (sx(n), y), stroke: (paint: luma(150), dash: "dashed"))
    cdraw.rect((sx(n) - 1.4, y), (sx(n) + 1.4, y + 1.0), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((sx(n), y + 0.5), t, size: 6pt)
  }
  pin(4.9, 1200, [7:1200])
  pin(3.7, 2400, [42:2400])
  pin(2.5, 7200, [1:7200])
  cdraw.content((3.2, 6.35), [hash=0x81fb1cc382429465], size: 6pt)
  cdraw.content((7.2, 4.2), [0xc03668...], size: 6pt)
  cdraw.content((11.2, 3.95), [0xfbe9b7...], size: 6pt)
  cdraw.content((6.4, 0.7), [each: twice identical, arena-matched, host bench matched], size: 6pt)
})

#callout("note", "WHAT THE BENCH DOES NOT PIN",
  [Windowed play against a human is unpinned by design, and the trig
  routing's lane equality is witnessed on the headings the pinned runs
  generate, not proven on all inputs. Both limits are stated here so
  the green gates are not read wider than they reach. A red pin on an
  unseen input would be the contract working, not failing.])

== audit totals

The audit ledger closes with its counts. The core suite: 18 state
checks, 20 physics, 12 astar, 6 mixed, 8 mcts, 64 checks total, zero
skipped, zero tolerated failures, every expected value pinned from
exact-arithmetic mirrors or the pinned deterministic runs with the tier
flagged in each test header. The driver gates: the in-process replay
with full-state memcmp, the twice-run cross-process hash, the selfplay
table. The host gates: bench twice-run with the render checksum, the
direct arena diff, the full-gate long rollouts and selfplay diff.
Format checks clean on every core and host file.

The dry run: the ledger sums.

+ 18 + 20 + 12 + 6 + 8 = 64 core checks, and no suite carries a skipped
  or tolerated check.
+ The two commands at the top of the chapter cover four of the six
  modes in under a minute on this machine: the driver's replay and
  twice-run gates, the host's bench and the arena diff. The host's
  selfplay leg rides -Full at about three minutes, and the windowed
  mode is a -Window run.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*suite*], [*checks*], [*representative gates*]),
  [test_state.c], [18], [d4 closure over all cells, raw and canonical pins, r90 and flip-y equality],
  [test_physics.c], [20], [oscillator within bound, round trip, j = 1.5, momentum zero, respawn at 600],
  [test_astar.c], [12], [bfs-pinned costs 42, 10, 21, 5, serpentine 65, sealed -1],
  [test_mixed.c], [6], [saddle certificate 11/9, pinned samples, 6000-draw counts],
  [test_mcts.c], [8], [bit-identical root stats, no hidden state, leads (2, 1, 1, 4)],
  [driver], [3 modes], [replay memcmp, twice-run hash, selfplay table],
  [host], [3 modes], [bench twice-run, arena diff, windowed smoke],
)

What the totals deliberately do not claim. Navigation quality: a\*
optimality is pinned, steering is naive, boxes can buzz in tight
corners, and no chapter says otherwise. Hash-sharing impossibility: the
quantization caveat of this chapter bars exactly that claim, the table
shares entries as a heuristic. Cross-libm equality in general: the
routing is witnessed evidence on this machine, on these lanes, for these
runs. Optimal play: the strength numbers are witnessed-deterministic
pins riding one binary and one set of budget constants, and the
first-mover structure means selfplay percentages are not a fair coin
either.

The gates have already earned their keep four times, which is the
strongest argument for running them, and the ledger of catches is part
of the audit.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*gate that fired*], [*defect*], [*signal*]),
  [terminal speed pin], [missing second verlet half kick], [speed exactly half the ladder, 2.3573 vs 4.7146],
  [canonical equality gate], [circle headings rotated by the group action], [r90 states stopped sharing the orbit minimum],
  [cross-lane bench pin], [msvcrt trig bits at heading pi], [hash 0xe698373cf0161dd6 at step 0, not the pin],
  [positional-correction mirror], [the pin itself, not the solver], [mass-weighted split re-derived, pin corrected],
)

Every gate in this chapter has fired on a real defect, one on a defect
in the audit apparatus itself, which is the difference between an audit
and a decoration.

Reading a red gate is part of the discipline. A divergence at step 0
with everything after it wrong means the inputs or the elementary
functions disagree, the libm class. A divergence late in a run with an
early agreement window points at contact ordering or a tie break, the
determinism class. A clean hash with a wrong physical number means the
arithmetic runs but the physics is miscompiled conceptually, a
missing-stage class like the half kick, and the terminal-speed pin is
tuned to catch exactly that. The two commands at the top of the chapter
reproduce any of these in under a minute on this machine, which is the
whole point of pinning numbers small enough to re-derive and large
enough to matter.

#diagram([the audit ledger: 64 core checks stacked by suite, the driver and host gates beside them], length: 13pt, {
  let suites = (([state], 18), ([physics], 20), ([astar], 12), ([mixed], 6), ([mcts], 8))
  let x = 1.0
  for p in suites {
    let s = p.at(0)
    let n = p.at(1)
    let w = n * 0.16
    cdraw.rect((x, 2.6), (x + w, 4.6), fill: luma(205), stroke: luma(100))
    cdraw.content((x + w / 2, 5.0), s, size: 6pt)
    cdraw.content((x + w / 2, 3.6), str(n), size: 6pt)
    x += w + 0.25
  }
  cdraw.content((3.5, 1.9), [64 core checks], size: 6.5pt)
  cdraw.rect((12.8, 3.9), (17.4, 4.9), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((15.1, 4.4), [driver: replay, twice-run], size: 6pt)
  cdraw.rect((12.8, 2.6), (17.4, 3.6), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((15.1, 3.1), [host: bench, arena diff], size: 6pt)
})

Twenty-nine chapters built a toolkit, three spent it on one program, and
the program closes with a receipt for every tool it used. The appendices
collect the coverage and sources for the whole book.

sources: verification facts read from the committed capstone source,
books/math/capstone/src main.c, state.c, test_mcts.c, test_physics.c
headers, and books/math/capstone/host main.c, 2026-09-22. Gate output
quoted from the two runs of this session: `pwsh -NoProfile -File
playground/math-capstone/build.ps1`, 64 checks, replay ok, twice-run
hash identical, format clean, and `pwsh -NoProfile -File
tools/run-math-capstone.ps1`, host gates green with bench 7:1200
arena-matched, both on 2026-09-22. Bridge material quoted from the
corpus's own chapters: error, quadrature, strategic, sequential, adt,
railway, monads, pipeline, groups, graphs. No external pages fetched
for this chapter, none cited.
