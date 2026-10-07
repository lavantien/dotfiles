#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= game theory and scheduling

Two players, perfect information, no chance: the question is always who
wins, and the answer is a number. The sprague-grundy theorem turns
every impartial game into a nim pile, so the chapter opens with mex
tables and nim sums and the winning move that falls out of an xor. The
second section moves the token onto an arbitrary directed graph, where
win, lose, and draw are decided by one retrograde sweep from the
terminals, and the matching characterization behind the 2025 blackboard
game is stated in prose. The third section reframes the same
minimax thinking as one player against time, four scheduling machines
from the shortest-job-first baseline to the 2017 problem H window
solver, and the chapter's fixtures reproduce that problem's
judge-verified answers byte for byte.

== sprague-grundy and nim

Every position of an impartial game earns a grundy number: the mex of
the grundy numbers of its options, the minimal excluded value, so a
position with options 0 and 2 earns 1 and a position with no options
earns 0. The subtraction game with moves {1, 3, 4} tabulates in one
line per position, and its table over n = 0 through 15 reads 0, 1, 0,
1, 2, 3, 2, 0, 1, 0, 1, 2, 3, 2, 0, 1, periodic with period 7 from
n = 2 onward. The theorem's payload is that grundy numbers add by xor:
a sum of independent games is equivalent to the nim pile whose size is
the xor of the parts, and the first player wins exactly when that xor
is nonzero. Nim itself is the pure case, pile sizes grundy numbers
outright, and the winning move recomputes itself, the pile whose xor
with the total drops.

The dry run: the fixtures are the subtraction table for moves 1, 3,
4 over n = 0 through 15 and the nim family, asserted by the C\# suite
with the same values pinned in C.

+ n = 0 has no move, its option set is empty, and the mex of nothing
  is 0.
+ n = 1 reaches only n = 0, options 0, mex 1, and n = 2 reaches only
  n = 1, options 1, mex 0.
+ n = 3 reaches 2 and 0, both grundy 0, options 0, mex 1, and n = 4
  reaches 3, 1, 0, options 1, 1, 0, mex 2.
+ n = 5 reaches 4, 2, 1, options 2, 0, 1, mex 3, and n = 7 reaches
  6, 4, 3, options 2, 2, 1, mex 0, one of the two zeros in the
  period-7 block that starts at n = 2.
+ Nim adds by xor: 3 xor 4 = 7 and 7 xor 5 = 2, nonzero, so first
  wins by cutting pile 3 to 3 xor 2 = 1, while 1 xor 2 xor 3 = 0
  hands (1, 2, 3) to the second player.
+ The sums agree with the table: g(5) xor g(6) = 3 xor 2 = 1, first,
  and g(7) xor g(9) = 0 xor 0 = 0, second.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*n*], [*options reach grundy*], [*g(n)*]),
  [0], [none], [0],
  [1], [0], [1],
  [2], [1], [0],
  [3], [0, 0], [1],
  [4], [1, 1, 0], [2],
  [5], [2, 0, 1], [3],
  [6], [3, 1, 0], [2],
  [7], [2, 2, 1], [0],
  [8], [0, 3, 2], [1],
)

The period-7 block and the xor verdicts land identically in every
suite, and the listings below build the mex table and the nim
analysis in seven languages.

#listing("dsa/samples-c/src/Ch40/grundy.c", first: 24, last: 59, caption: [c, the mex table build and the nim verdict with its winning move])
#listing("dsa/samples-go/ch40/grundy.go", first: 5, last: 45, caption: [go, the table over sorted moves, the nim analysis])
#listing("dsa/samples-java/src/Ch40/Grundy.java", first: 21, last: 58, caption: [java, the mex table build over a seen array, the nim verdict with its winning move])
#listing("dsa/samples/src/Ch40/Grundy.cs", first: 9, last: 37, caption: [c\#, the option set and its mex, the move from the pile that drops])
#listing("dsa/samples-js/src/ch40-grundy.mjs", first: 8, last: 35, caption: [javascript, the mex loop and the nim analysis, xor on number])
#listing("dsa/samples-py/src/Ch40/grundy.py", first: 14, last: 38, caption: [python, mex as a helper, the table, the move])
#listing("dsa/samples-lua/ch40_grundy.lua", first: 8, last: 35, caption: [lua, the same pair, xor as the ~ operator])

The misere caveat stays prose: when the loser is the player who takes
the last object instead of the one who cannot move, only the endgame
flips, and for nim specifically the strategy changes exactly when
every pile is of size 1, where the parity of the pile count decides.
Everything before that point plays identically.

The fixture families pin identical values in all seven languages. The
table above and its period. The nim positions: (3, 4, 5) xors to 2,
first wins by cutting the pile of 3 down to 1, (1, 2, 3) xors to 0 and
the second player wins, a lone pile of 7 moves to 0, the twin piles
(5, 5) cancel for the second player, and (1, 1, 2) wins by emptying
the third pile. The sum table over the subtraction game pins
g(5) xor g(5) = 0, g(5) xor g(6) = 1, g(5) xor g(10) = 2, g(7) xor
g(9) = 0, both grundy numbers being 0 there, and g(9) xor g(9) = 0,
first exactly when the cell is nonzero. The edges close it: the empty
position xors to 0 and loses by convention, and a single pile of 1
moves to 0. The c suite asserts the 3, 4, 5 verdict twice in a row, a
literal duplicate, and the java port drops the second copy, 33 grundy
checks where c counts 34.

#diagram([the subtraction grundy ladder with the period-7 block boxed, beside the 3, 4, 5 nim piles and the 3 to 1 winning move], length: 13pt, {
  // left: the grundy ladder n = 0..15
  let g = (0, 1, 0, 1, 2, 3, 2, 0, 1, 0, 1, 2, 3, 2, 0, 1)
  for n in range(16) {
    let x = 1.2 + n * 0.92
    let hot = n >= 2
    cdraw.rect((x, 6.2), (x + 0.92, 7.1), fill: if hot { luma(235) } else { luma(245) }, radius: 0.02)
    cdraw.content((x + 0.46, 6.65), [#g.at(n)], size: 7pt)
    cdraw.content((x + 0.46, 5.9), [#n], size: 5.5pt)
  }
  // the period-7 block boxed: n = 2..8 against 9..15
  cdraw.rect((1.2 + 2 * 0.92, 5.7), (1.2 + 9 * 0.92, 7.35), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((5.0, 4.9), [the boxed block repeats with period 7 from n = 2], size: 6pt)
  // right: the nim piles (3, 4, 5), move 3 -> 1
  let piles = ((3, 16.4), (4, 18.2), (5, 20.0))
  for (v, x) in piles {
    for h in range(v) {
      cdraw.rect((x - 0.3, 6.2 - h * 0.42), (x + 0.3, 6.62 - h * 0.42), fill: if v == 3 and h >= 1 { luma(248) } else { luma(215) }, radius: 0.02)
    }
    cdraw.content((x, 7.5), [#v], size: 7pt)
  }
  // the winning move: pile of 3 keeps 1
  cdraw.line((16.4, 5.3), (16.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.6, 4.9), [3 -> 1: the xor drops to 0], size: 6pt)
  cdraw.content((18.6, 3.9), [3 xor 4 xor 5 = 2, first wins], size: 6pt)
  cdraw.content((8.0, 3.0), [sums xor, first iff nonzero], size: 6pt)
})

The application is general technique. The corpus holds no nim-sum
finals problem, and the 2025 blackboard game is a graph game decided
by matchings, the next section's business.

== games on arbitrary graphs

Move the token onto a directed graph and let the rules be minimal: the
player to move picks an out-edge and slides the token, and the player
with no out-edge loses. Retrograde analysis labels every vertex from
the terminals inward. A vertex with no out-edge loses for the mover.
A vertex with a move into a losing vertex wins. A vertex whose every
successor wins, loses. Whatever the sweep cannot reach draws, the
cycles nobody can force either way. The implementation is degree
counting with a queue over the reverse arcs, one pass, O(V + E).

The dry run: the fixture is the 8-vertex graph with its two
mutations, asserted by the C\# suite and pinned the same way in C.

+ Vertices 5 and 6 have no out-edge, the mover loses, so the queue
  seeds two L verdicts.
+ The wave runs over reverse arcs: vertex 4 points at 5 and 6, both
  L, so 4 is W through terminal 5.
+ Vertex 3 points at 1 and 4, one successor W and one undetermined,
  so no rule fires and its degree never drains, it stays pending.
+ The 3-cycle 1, 2, 3 and the 2-cycle 7, 8 never touch the wave, and
  the sweep leaves them D: D, D, D, W, L, L, D, D.
+ Deleting arc 3 to 4 changes nothing, 4 still wins through 5, and
  adding arc 6 to 5 gives 6 a move into L, flipping it to W: D, D,
  D, W, L, W, D, D.
+ The edges agree: a lone vertex is L, a self-loop only draws, and a
  vertex with an edge into a terminal is W.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*vertex*], [*verdict*], [*why*]),
  [5], [L], [no out-edge, terminal],
  [6], [L], [no out-edge, terminal],
  [4], [W], [a move into 5, an L vertex],
  [3], [D], [successor 1 never decided],
  [1], [D], [the 3-cycle 1, 2, 3],
  [2], [D], [the 3-cycle 1, 2, 3],
  [7], [D], [the 2-cycle 7, 8],
  [8], [D], [the 2-cycle 7, 8],
)

D, D, D, W, L, L, D, D is the pinned string, and the listings below
run the sweep in seven languages.

#listing("dsa/samples-c/src/Ch40/graphgames.c", first: 47, last: 75, caption: [c, the retrograde loop, reverse arcs, degree counting])
#listing("dsa/samples-go/ch40/graphgames.go", first: 20, last: 52, caption: [go, the outcome enum, terminals seeded, predecessors decided])
#listing("dsa/samples-java/src/Ch40/Graphgames.java", first: 46, last: 75, caption: [java, the retrograde loop, reverse arcs, degree counting])
#listing("dsa/samples/src/Ch40/GraphGames.cs", first: 9, last: 53, caption: [c\#, the same sweep, the draw assignment at the end])
#listing("dsa/samples-js/src/ch40-graphgames.mjs", first: 9, last: 47, caption: [javascript, the wave off the terminals, the undecided stay draws])
#listing("dsa/samples-py/src/Ch40/graphgames.py", first: 17, last: 50, caption: [python, the sweep and the draw default])
#listing("dsa/samples-lua/ch40_graphgames.lua", first: 10, last: 53, caption: [lua, the same loop over reverse adjacency])

The fixture graph runs 8 vertices with arcs 1 to 2, 2 to 3, 3 back to
1, 3 to 4, 4 to 5, 4 to 6, 7 to 8, 8 back to 7, and vertices 5 and 6
terminal. Outcomes read D, D, D, W, L, L, D, D: the 3-cycle draws,
vertex 4 wins through terminal 5, both terminals lose, and the 2-cycle
draws. The mutation family probes the labeling: deleting edge 3 to 4
changes nothing, 4 still wins through 5, and adding edge 6 to 5 flips
vertex 6 from losing to winning, its move now reaching a losing
position. The edges: a lone vertex loses, a self-loop only draws, and
a vertex with an edge into a terminal wins.

Against the alpha-beta search of #xref-to("dsa", "pruning"), this is
the same question at graph scale: alpha-beta walks a small game tree
once, retrograde analysis memoizes the whole position graph and answers
every start in one sweep.

The matching characterization stays prose but carries the contest
weight: for the slide-a-token family where moves never repeat a
vertex, the second player wins exactly when a maximum matching covers
the token's starting component, because the matched edge gives the
second player an answer to every first move, and an unmatched start
lets the first player walk the matching forever. That is how the 2025
blackboard game decides its openings, and the matching machinery
itself is the kuhn section of #xref-to("dsa", "flows2").

#diagram([the 8-vertex fixture colored w, l, d, the retrograde wave arrows out of the terminals 5 and 6], length: 13pt, {
  let kind = ("1": "d", "2": "d", "3": "d", "4": "w", "5": "l", "6": "l", "7": "d", "8": "d")
  let pos = ("1": (2.0, 6.8), "2": (4.2, 6.8), "3": (6.4, 6.8), "4": (8.6, 6.8), "5": (10.8, 7.6), "6": (10.8, 6.0), "7": (3.1, 4.4), "8": (5.3, 4.4))
  let fill-of = (k) => if k == "w" { luma(215) } else if k == "l" { luma(190) } else { luma(240) }
  let arrow = (a, b) => cdraw.line(pos.at(a), pos.at(b), stroke: luma(150), mark: (end: ">"))
  arrow("1", "2")
  arrow("2", "3")
  arrow("3", "1")
  arrow("3", "4")
  arrow("4", "5")
  arrow("4", "6")
  arrow("7", "8")
  arrow("8", "7")
  for (v, p) in pos {
    let k = kind.at(v)
    cdraw.circle(p, radius: 0.3, fill: fill-of(k), stroke: luma(120))
    cdraw.content(p, [#v], size: 7pt)
    cdraw.content((p.at(0), p.at(1) + 0.5), upper(k), size: 6pt)
  }
  // the retrograde wave out of the terminals
  cdraw.line((10.8, 7.6), (9.1, 7.15), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.8, 6.0), (9.1, 6.45), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.4, 9.0), [the wave starts at the terminals], size: 6pt)
  cdraw.content((6.0, 2.9), [no out-edge loses, a move to l wins], size: 6pt)
  cdraw.content((6.0, 2.0), [all successors w: loses], size: 6pt)
  cdraw.content((6.0, 1.1), [the unreachable cycles draw], size: 6pt)
  cdraw.content((6.0, 0.2), [one sweep, o(v + e)], size: 6pt)
})

The application is icpc world finals 2025 problem B (book 10, chapter
13), blackboard game, the prime-multiple graph whose openings are
decided by the matching characterization stated above, with the kuhn
solver of chapter 38 doing the matching.

== scheduling

One player against time is still a game, lose only when the deadline
arrives, and the winning moves are orders. Four machines ship in one
file. On a single machine minimizing total completion time, the
shortest-processing-time order wins, every swap of a longer job in
front of a shorter one delays everyone behind. On two machines in
series, johnson's rule wins: jobs with a under b sorted by a ascending,
then the rest by b descending, and the makespan falls out of the
max-cascade, machine 2 waiting for machine 1 and for its own previous
job. Unit jobs with deadlines are feasible exactly under the
earliest-deadline-first order, slot k meeting the k-th tightest
deadline or nothing will. The fourth machine is the 2017 problem H
window solver, photos of common duration t inside per-photo windows
\[a, b\], decided by the two-phase garey-johnson-simons-tarjan
construction: phase 1 sweeps release times descending, stacks each
suffix as late as possible pushed out of forbidden start regions, and
marks \[C-t+1, s-1\] forbidden when the chain leaves C - s under t,
phase 2 runs the earliest-deadline greedy over candidate starts, the
current time, release times, and region ends, never starting inside a
region.

The dry run: the fixtures are the spt durations 5, 2, 8, 1, the
johnson five-job set, the edf deadline families, and the 2017
problem H windows, asserted by the C\# suite against the judge
answers.

+ Spt sorts 5, 2, 8, 1 into durations 1, 2, 5, 8: the clock reads
  1, 1 + 2 = 3, 3 + 5 = 8, 8 + 8 = 16, total 28 against the input
  order's 43.
+ Johnson splits (3, 5), (1, 2), (4, 1), (2, 6), (5, 4): jobs with
  a under b lead sorted by a, 1, 2, 3, the rest trail by b
  descending, 4, 1, so the order reads 1, 3, 0, 4, 2.
+ The cascade: machine 1 finishes 1, 3, 6, 11, 15 while machine 2
  pays max(t2, t1) + b, landing 3, 9, 14, 18, 19, the makespan 19
  the 120-order brute confirms.
+ Edf checks slot k against the k-th tightest deadline: 3, 3, 3, 7,
  7, 7 passes at 1, 2, 3, 4, 5, 6, and 3, 1, 2, 3 stalls at slot 4,
  deadline 3, infeasible.
+ The window mini, three photos of t = 2 in (0,8), (1,3), (4,6):
  phase 1 stacks the release-4 suffix to start 6 - 2 = 4 and, zero
  slack above the release, marks 4 - 2 + 1 = 3 forbidden, then the
  release-1 suffix lands (1,3) at 3 - 2 = 1 and marks start 0.
+ Phase 2 then starts (1,3) at 1, (4,6) at 4, (0,8) at 6, ending
  3, 6, 8, the verdict yes.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*job (a, b)*], [*t1 after*], [*t2 = max + b*]),
  [1], [(1, 2)], [1], [max(0, 1) + 2 = 3],
  [2], [(2, 6)], [3], [max(3, 3) + 6 = 9],
  [3], [(3, 5)], [6], [max(9, 6) + 5 = 14],
  [4], [(5, 4)], [11], [max(14, 11) + 4 = 18],
  [5], [(4, 1)], [15], [max(18, 15) + 1 = 19],
)

The 19 equals the brute optimum and the window verdicts reproduce
2017 problem H, and the listings below ship the four machines in
seven languages.

#listing("dsa/samples-c/src/Ch40/scheduling.c", first: 149, last: 195, caption: [c, the phase 1 sweep, the as-late chain pushed out of regions, the forbidden marking])
#listing("dsa/samples-go/ch40/scheduling.go", first: 163, last: 209, caption: [go, the release sweep, the tightest-deadline batch, the marking])
#listing("dsa/samples-java/src/Ch40/Scheduling.java", first: 139, last: 185, caption: [java, the phase 1 sweep, the as-late chain pushed out of regions, the forbidden marking, a byte-for-byte port of the c loop])
#listing("dsa/samples/src/Ch40/Scheduling.cs", first: 83, last: 120, caption: [c\#, the same sweep, adjust down, the region merge, the greedy below])
#listing("dsa/samples-js/src/ch40-scheduling.mjs", first: 76, last: 105, caption: [javascript, phase 1 whole, the region bookkeeping])
#listing("dsa/samples-py/src/Ch40/scheduling.py", first: 90, last: 113, caption: [python, releases descending, the chain, the too-tight region])
#listing("dsa/samples-lua/ch40_scheduling.lua", first: 98, last: 136, caption: [lua, the same sweep and marking, phase 2 below])

The simplified teaching form is O(n^2) against the shipped solver's
sorts, with the semantics mirrored exactly, and the reference
reproduces all six judge-verified answers of the 2017 problem H
statement.

The spt fixture runs durations 5, 2, 8, 1: order the jobs 1, 2, 8, 5
by index, completions 1, 3, 8, 16, total 28 against the input order's
43. Johnson on (3,5), (1,2), (4,1), (2,6), (5,4) pins the canonical
order and makespan 19, equal to the brute optimum over all 120 orders,
the brute's own lexicographic optimum differing at the tail and the
canonical output being the pinned one, and the all-ties instance of
three (2,3) jobs keeps input order at makespan 11. The edf family:
deadlines 1, 2, 3 feasible in order, 3, 3, 3, 7, 7, 7 feasible, 3, 1,
2, 3 infeasible because the greedy stalls at slot 4, and 1, 1, 2
infeasible outright. The window machine: the six judge-verified cases
of 2017 problem H answer yes, no, yes, yes, no, yes, and the crafted
pair, a single photo in a generous window and four photos fighting for
overlapping windows, answer yes and no. Java's window machine ports
the c phase 1 loop statement for statement, adjust-down and the region
merge identical, so the six verdicts land on the same orbit. The edges: a single photo is
feasible whenever its window fits t, and two identical windows decide
by 2t against the span, both fitting at a span of 4 with t = 2,
neither at a span of 3.

#diagram([the spt timeline against the input-order one, the johnson gantt with its makespan cascade, and the forbidden region blocking the naive start in the 2017 problem H mini], length: 13pt, {
  // panel 1: spt vs input order over 5, 2, 8, 1
  let bar = (x, y, w, label, hot) => {
    cdraw.rect((x, y), (x + w, y + 0.55), fill: if hot { luma(215) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.28), label, size: 6pt)
  }
  cdraw.content((6.0, 9.6), [spt: total 28], size: 6.5pt)
  bar(1.2, 8.7, 1.0, [1], true)
  bar(2.2, 8.7, 2.0, [2], false)
  bar(4.2, 8.7, 8.0, [8], false)
  bar(12.2, 8.7, 5.0, [5], false)
  for (x, t) in ((2.2, [1]), (4.2, [3]), (12.2, [8]), (17.2, [16])) {
    cdraw.content((x, 9.4), t, size: 5.5pt)
  }
  cdraw.content((6.0, 7.9), [input order: total 43], size: 6.5pt)
  bar(1.2, 7.0, 5.0, [5], false)
  bar(6.2, 7.0, 2.0, [2], false)
  bar(8.2, 7.0, 8.0, [8], false)
  bar(16.2, 7.0, 1.0, [1], false)
  for (x, t) in ((6.2, [5]), (8.2, [7]), (16.2, [15]), (17.2, [16])) {
    cdraw.content((x, 7.9), t, size: 5.5pt)
  }
  // panel 2: the johnson gantt, order [1, 3, 0, 4, 2]
  cdraw.content((6.0, 6.1), [johnson: makespan 19], size: 6.5pt)
  let m1 = ((0.0, 1.0, [1]), (1.0, 2.0, [3]), (3.0, 3.0, [0]), (6.0, 5.0, [4]), (11.0, 4.0, [2]))
  let m2 = ((1.0, 2.0, [1]), (3.0, 6.0, [3]), (9.0, 5.0, [0]), (14.0, 4.0, [4]), (18.0, 1.0, [2]))
  for (st, w, k) in m1 {
    bar(1.2 + st * 0.88, 4.8, w * 0.88, k, false)
  }
  for (st, w, k) in m2 {
    bar(1.2 + st * 0.88, 3.9, w * 0.88, k, true)
  }
  cdraw.content((0.6, 5.1), [m1], size: 6pt)
  cdraw.content((0.6, 4.2), [m2], size: 6pt)
  cdraw.line((1.2 + 19 * 0.88, 3.7), (1.2 + 19 * 0.88, 5.6), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((1.2 + 19 * 0.88, 3.3), [19], size: 6pt)
  cdraw.content((1.2 + 9 * 0.88, 3.25), [m2 waits for m1 at job 0], size: 5.5pt)
  // panel 3: the 2017/H mini, windows (0,8), (1,3), (4,6), t = 2
  cdraw.content((6.0, 2.6), [windows (0,8), (1,3), (4,6), t = 2], size: 6.5pt)
  cdraw.line((1.2, 0.6), (19.2, 0.6), stroke: luma(140), mark: (end: ">"))
  for (x, t) in ((1.2, [0]), (3.2, [1]), (5.2, [2]), (7.2, [3]), (9.2, [4]), (11.2, [5]), (13.2, [6]), (15.2, [7]), (17.2, [8]), (19.2, [])) {
    cdraw.content((x, 0.25), t, size: 5.5pt)
  }
  // the naive start of the [0,8] photo as a dashed ghost above, dead
  cdraw.rect((1.2, 1.5), (5.2, 2.1), fill: none, stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((7.2, 1.8), [naive (0,8) start dies], size: 5.5pt)
  bar(3.2, 0.75, 4.0, [(1,3)], true)
  bar(9.2, 0.75, 4.0, [(4,6)], true)
  bar(13.2, 0.75, 4.0, [(0,8)], false)
  cdraw.content((11.2, -0.5), [the schedule that works: 1-3, 4-6, 6-8], size: 6pt)
})

The application is icpc world finals 2017 problem H (book 10, chapter
8), scenery, where the garey-johnson-simons-tarjan two-phase machine
is exactly the fourth solver, and the shipped seven-language solvers of
the icpc book are its contest-grade siblings. When an instance
outruns every exact solver, the next tier over surrenders on purpose
and keeps a number: #xref-to("dsa", "approximation") and its proven
ratios.

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's three sample files per language, go test files excluded:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [440], [static arrays, insertion sorts], [all four machines in one file, the judge-verified windows answers pinned, 65 checks],
  [go], [328], [slices, sort], [the johnson brute as ground truth, the outcome enum for retrograde],
  [java], [447], [jdk 27 stdlib], [the phase 1 window machine a byte-for-byte port of the c loop, the grundy port drops the c suite's one duplicated verdict check, insertion sorts hand-rolled],
  [c\#], [225], [linq ordering throughout], [the window machine as one method, phase comments mirroring the shipped solver],
  [javascript], [179], [node stdlib], [tightest file of the wave, the window machine under 70 lines],
  [python], [263], [stdlib only, inline asserts], [itertools permutations as the johnson oracle, four families pinned],
  [lua], [338], [tables, lib.lua harness], [1-based jobs and deadlines shifted at the boundary, check tables for run.lua],
)

sources: cp-algorithms, "Sprague-Grundy theorem. Nim",
cp-algorithms.com/game_theory/sprague-grundy-nim.html, "Games on
arbitrary graphs", cp-algorithms.com/game_theory/games_on_graphs.html,
"Scheduling jobs on one machine",
cp-algorithms.com/schedules/schedule_one_machine.html, "Scheduling
jobs on two machines", cp-algorithms.com/schedules/schedule_two_machines.html,
and "Optimal schedule of jobs given their deadlines and durations",
cp-algorithms.com/schedules/schedule-with-completion-duration.html,
all accessed 2026-09-20, cc by-sa 4.0, our own words and code
throughout. Application sources: icpc world finals 2025 problem B and
2017 problem H (book 10, chapters 13 and 8). Sample behavior verified
by the seven suite gates scoped to chapter 40: c 3 files and 65 checks, go 12 test
functions, java 3 files and 64 checks under run-java-samples, c\# 12
facts, javascript 12 tests and 47 asserts, python 3 files and 41
asserts, lua 12 checks, zero skipped.
