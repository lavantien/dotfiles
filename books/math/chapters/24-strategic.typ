#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= strategic games

Chapter #xref-to("math", "probability") built expectation over outcomes and
chapter #xref-to("math", "optimization") built duality for constrained
extremes. This chapter spends both on games where players move
simultaneously and payoffs interlock. Six moves: the normal form with
payoff bimatrixes and dominance as pure enumeration, best responses and
pure nash equilibria as mutual best responses, mixed strategies with every
expectation carried in exact rationals, the minimax theorem for zero sum
games and its link back to linear program duality, computing equilibria by
enumerating supports and solving each with cramer, and the regret view
where follow the regularized leader turns online play into equilibria.
Every behavioral claim below is one of the 60 checks in the 4 samples of
chapter 24 or a sentence quoted from a canonical source fetched 2026-09-22.
Chapter #xref-to("dsa", "games") in the dsa book owns combinatorial games
with perfect information and sprague-grundy numbers, this chapter owns the
simultaneous strategic half, and chapter #xref-to("math", "sequential")
extends it to game trees and repetition.

== normal form and dominance

A game in normal form is a list of players, a finite action set for each,
and a payoff for every profile of actions. Two players means two payoff
matrices of the same shape, the bimatrix: row payoff $u_1 (i, j)$ and
column payoff $u_2 (i, j)$ for row action $i$ against column action $j$.
The prisoner's dilemma fixture uses the standard numbers with cooperate
and defect:

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([], [*cooperate*], [*defect*]),
  [cooperate], [$(3, 3)$], [$(0, 4)$],
  [defect], [$(4, 0)$], [$(1, 1)$],
)

Action $d$ strictly dominates $c$ when $u (d, j) > u (c, j)$ against every
opponent action $j$. Here defect pays 4 against 3 and 1 against 0, both
players at once, so two rounds of strict elimination leave the profile
(defect, defect) paying (1, 1) while (cooperate, cooperate) pays (3, 3)
sits one eliminated row away.

The dry run: dominance is four integer comparisons, and the never best
response property is a sweep. Scale the opponent mix $q$ (probability of
cooperate) to eighths: $u (C, q) = 3q$ against $u (D, q) = 1 + 3q$. The
difference is exactly 1 at all 9 points of the grid, the 8 intervals from
$q = 0$ to $q = 1$, at $q = 1\/2$ that is 3/2 against 5/2. A strictly
dominated action loses
by a constant margin no matter what the opponent does, so it is never a
best response, and eliminating it cannot delete an equilibrium. Weak
domination drops the strictness: $u (d, j) >= u (c, j)$ everywhere with a
strict inequality somewhere. The fixture $[[2, 1], [2, 0]]$ has the first
row weakly dominating the second, yet against column 1 both rows pay 2, so
the weakly dominated row is still a best response there.

#listing("math/samples/src/Ch24/normal.c", first: 37, last: 64, caption: [normal.c, strict dominance for both players and weak dominance, each one plain enumeration])

#diagram([the prisoner's dilemma bimatrix, the defect row shaded as the strict dominant reply in both columns], length: 13pt, {
  let cell(x, y, t, hot) = {
    cdraw.rect((x, y), (x + 3.0, y + 1.2), fill: if hot { luma(205) } else { luma(245) }, stroke: luma(140), radius: 0.02)
    cdraw.content((x + 1.5, y + 0.6), t, size: 6.5pt)
  }
  cdraw.content((4.5, 4.7), [cooperate], size: 6pt)
  cdraw.content((7.5, 4.7), [defect], size: 6pt)
  cdraw.content((1.6, 3.6), [cooperate], size: 6pt)
  cdraw.content((1.6, 2.4), [defect], size: 6pt)
  cell(3.0, 3.0, [(3, 3)], false)
  cell(6.0, 3.0, [(0, 4)], false)
  cell(3.0, 1.8, [(4, 0)], true)
  cell(6.0, 1.8, [(1, 1)], true)
  cdraw.line((10.2, 3.55), (10.2, 3.05), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.2, 2.35), (10.2, 1.85), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.6, 3.3), [4 > 3], size: 6pt)
  cdraw.content((11.6, 2.1), [1 > 0], size: 6pt)
})

#callout("pitfall", "WEAK DOMINATION IS ORDER DEPENDENT",
  [Iterated elimination by strict dominance is safe: a strictly dominated
  action is never a best response against any mix, which normal.c sweeps on
  all 9 points of the eighths grid. Weak elimination is not: eliminating a
  weakly dominated
  action can delete equilibria, and which equilibria survive depends on the
  order of elimination (Osborne 2003, by name). The weak fixture shows the
  mechanism, the covered row still ties as a best response against column
  1, so removing it removes a best reply that some equilibrium may need.])

== best response and pure nash

The best response correspondence picks, for each fixed opponent action, the
actions attaining the maximum payoff. Matching pennies fixes the two
diagonal cells of the row matrix at 1 and the off diagonal at -1: row
wants to match, so the best response to heads is heads and to tails is
tails, while the column player wants the mismatch. A pure nash equilibrium
is a profile where every action played is a best response to the other
side, the mutual fixed point of the two correspondences. Formally $s^*$
is an equilibrium when $u_i (s_i^*, s_(-i)^*) >= u_i (s_i, s_(-i)^*)$ for
every player $i$ and every deviation $s_i$.

The dry run: enumerate all four profiles and count deviators. Pennies has
none stable, at (H, H) the column player collects -1 and flips, at (H, T)
the row player flips, 0 pure equilibria. The prisoner's dilemma has
exactly one, (D, D): both best response maps point there from every
column and every row. Battle of the sexes with row payoff
$[[3, 0], [0, 1]]$ and column payoff $[[1, 0], [0, 3]]$ has two,
(opera, opera) paying (3, 1) and (football, football) paying (1, 3), with
the miscoordinated profiles paying (0, 0) to both.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*fixture*], [*pure equilibria*], [*payoffs*], [*deviators elsewhere*]),
  [pennies], [0], [], [both players want to flip],
  [prisoner's dilemma], [1], [$(1, 1)$], [defection pays],
  [battle of the sexes], [2], [$(3, 1)$, $(1, 3)$], [both miscoordinates fail],
)

#listing("math/samples/src/Ch24/normal.c", first: 78, last: 101, caption: [normal.c, pure nash enumeration: flag the column side's best replies down each row, then keep profiles where both sides are flagged])

#diagram([battle of the sexes deviation arrows, both miscoordinate profiles have a profitable unilateral move and drain into the two shaded equilibria], length: 13pt, {
  let prof(x, y, t, eq) = {
    cdraw.circle((x, y), radius: 0.5, stroke: if eq { luma(60) } else { luma(100) }, fill: if eq { luma(205) } else { luma(245) })
    cdraw.content((x, y), t, size: 6pt)
  }
  prof(3.2, 3.7, [(3, 1)], true)
  prof(9.2, 3.7, [(0, 0)], false)
  prof(3.2, 1.3, [(0, 0)], false)
  prof(9.2, 1.3, [(1, 3)], true)
  cdraw.line((8.5, 3.7), (3.9, 3.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((9.2, 3.1), (9.2, 1.95), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((3.9, 1.3), (8.5, 1.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((3.2, 1.95), (3.2, 3.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.2, 4.65), [opera], size: 6pt)
  cdraw.content((9.2, 4.65), [football], size: 6pt)
  cdraw.content((6.2, 4.65), [column plays], size: 6pt)
  cdraw.content((1.4, 3.7), [opera], size: 6pt)
  cdraw.content((1.4, 1.3), [football], size: 6pt)
  cdraw.content((1.4, 2.5), [row plays], size: 6pt)
})

#callout("note", "EQUILIBRIUM IS NOT OPTIMALITY",
  [The prisoner's dilemma equilibrium pays (1, 1) while (cooperate,
  cooperate) pays (3, 3), and the check pins exactly this: one pure
  equilibrium, at (defect, defect), with strict dominance making
  cooperation unreachable without changing the game. Equilibrium predicts
  what self interested play sustains, not what the players would prefer
  to have agreed on.])

== mixed strategies and nash

Matching pennies has no pure equilibrium, so the strategy space has to
grow. A mixed strategy is a probability vector over actions, and the
payoff of a mixed profile is the expectation
$u_1 (x, y) = sum_i sum_j x_i y_j u_1 (i, j)$, exactly the double sum
chapter #xref-to("math", "probability") used for discrete expectations.
Against a mixed opponent the payoff of each pure action is a dot product,
and the best response set is the argmax of those dot products. Against a
battle of the sexes column player mixing (1/2, 1/2), opera expects
$3 dot 1\/2 = 3\/2$ and football expects $1 dot 1\/2 = 1\/2$, so opera is
the strict best response.

The dry run: solve the pennies equilibrium by indifference. Row is
willing to mix only when both actions pay the same, $u (H, q) = u (T,
q)$, which expands to $2q - 1 = 1 - 2q$ on the mixing
probability $q$ of heads and lands at $q = 1\/2$. Both players equalize,
the profile (1/2, 1/2) against (1/2, 1/2) pays exactly 0 to both, and no
deviation gains: the checks pin 0 with exact fractions, not floats. The
same two equations on battle of the sexes give row mixing (3/4, 1/4)
against column mixing (1/4, 3/4), and the payoff is 3/4 to each player,
below the 1 the disadvantaged side collects at either pure equilibrium.
Nash's theorem guarantees this construction always terminates: "John Nash
showed that there is a Nash equilibrium, possibly in mixed strategies,
for every finite game" (wikipedia, fetched 2026-09-22, the 1950 result
via kakutani and 1951 via brouwer fixed points).

#listing("math/samples/src/Ch24/mixed.c", first: 68, last: 94, caption: [mixed.c, mixed expectations as exact fraction sums and the 2x2 equilibrium from the indifference equations, one denominator per player])

#diagram([battle of the sexes indifference, row's two pure payoffs cross at column mix q = 1/4 where both earn 3/4], length: 13pt, {
  let X(q) = { 2.0 + 8.0 * q }
  let Y(v) = { 0.5 + 1.3 * v }
  cdraw.line((0.8, 0.5), (10.6, 0.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.0, 0.2), (2.0, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((X(0), Y(0)), (X(1), Y(3)), stroke: luma(60))
  cdraw.line((X(0), Y(1)), (X(1), Y(0)), stroke: luma(140))
  cdraw.line((X(0.25), 0.5), (X(0.25), Y(0.75)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((X(0.25), Y(0.75)), radius: 0.11, fill: luma(30), stroke: none)
  cdraw.content((10.0, Y(2.6)), [$3 q$], size: 6pt)
  cdraw.content((10.0, Y(0.45)), [$1 - q$], size: 6pt)
  cdraw.content((X(0.25), 0.15), [$1\/4$], size: 6pt)
  cdraw.content((2.0, 0.15), [0], size: 6pt)
  cdraw.content((10.0, 0.15), [1], size: 6pt)
  cdraw.content((1.0, Y(0.75)), [$3\/4$], size: 6pt)
})

Two numbers to keep: the mixed battle of the sexes pays both players 3/4
where the pure equilibria pay 3 and 1, and pennies at (1/2, 1/2) pays 0
where every pure profile pays plus or minus 1.

== the minimax theorem

Zero sum strips the bimatrix to one matrix, $u_2 = -u_1$, all conflict.
Row's guaranteed payoff for a mixed $x$ is $min_j x^T A e_j$, and the
maximin is the best such guarantee. Column's cap is $max_i e_i^T A y$,
minimized. Pure enumeration reads both off the matrix: the saddle
fixture $[[3, 2, 4], [1, 2, 0], [5, 1, 6]]$ has row minima (2, 0, 1) and
column maxima (5, 2, 6), maximin 2 and minimax 2, the saddle at row 1
column 2. The gap fixture $[[2, 0], [0, 1]]$ has both row minima 0 and
both column maxima above it, maximin 0 against minimax 1, and no pure
equilibrium: the pure numbers bracket the truth without pinning it.

The dry run: close the gap with a mix. Row plays (p, 1 - p), guaranteeing
$min (2p, 1 - p)$, a tent that peaks where the two lines cross, $2p = 1 -
p$, so $p = 1\/3$ and the guarantee is 2/3. Column's equalization gives
the same (1/3, 2/3) from the other side, and the value is exactly 2/3
with both columns paying $x^T A e_j = 2\/3$ and both rows paying $A y =
2\/3$. A twelfths grid sweep finds the same peak at k = 4, and weak
duality, no row guarantee above any column cap, holds on all 169
enumerated pairs with the tightest margin exactly 0 at the optimum. This
is the content of the theorem: "max x in X min y in Y x^T A y = min y in
Y max x in X x^T A y" over the strategy simplexes, von Neumann 1928
(wikipedia, fetched 2026-09-22). The gap fixture closes 0 < 2/3 < 1.

#listing("math/samples/src/Ch24/zerosum.c", first: 78, last: 120, caption: [zerosum.c, pure maximin and minimax by enumeration, then the 2x2 mixed solve by equalizing one denominator])

#diagram([the gap game guarantee min(2p, 1 - p), a tent peaking at p = 1/3 with value 2/3 between the pure maximin 0 and minimax 1], length: 13pt, {
  let X(p) = { 2.0 + 8.0 * p }
  let Y(v) = { 0.5 + 2.6 * v }
  cdraw.line((0.8, 0.5), (10.6, 0.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.0, 0.2), (2.0, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((X(0), Y(0)), (X(1.0 / 3.0), Y(2.0 / 3.0)), stroke: luma(60))
  cdraw.line((X(1.0 / 3.0), Y(2.0 / 3.0)), (X(0.95), Y(0.05)), stroke: luma(60))
  cdraw.line((2.0, Y(2.0 / 3.0)), (X(1.0 / 3.0), Y(2.0 / 3.0)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((X(1.0 / 3.0), Y(2.0 / 3.0)), radius: 0.11, fill: luma(30), stroke: none)
  cdraw.content((X(1.0 / 3.0), 0.15), [$1\/3$], size: 6pt)
  cdraw.content((2.0, 0.15), [0], size: 6pt)
  cdraw.content((10.0, 0.15), [1], size: 6pt)
  cdraw.content((0.6, Y(2.0 / 3.0)), [$2\/3$], size: 6pt)
  cdraw.content((6.0, Y(0.18)), [$min (2p, 1 - p)$], size: 6pt)
  cdraw.content((8.4, Y(0.75)), [maximin 2\/3], size: 6pt)
})

The link back to chapter #xref-to("math", "optimization") is exact: the
maximin side is a linear program in $x$ plus a level variable, the
minimax side is its dual, and the minimax equality is strong duality for
that pair (Boyd and Vandenberghe 2004, by name). Every check in this
chapter is that duality made enumerable: 169 weak pairs, one tight.

== computing equilibria by support enumeration

Indifference turns equilibrium solving into linear algebra. On a support
pair (S, T), the sets of actions each player mixes over, the equal size
case stacks the equations: each column player action in T must pay row
the same $v$, each row action in S must pay column the same $v$, and the
probabilities sum to 1. That is a $(k + 1) times (k + 1)$ linear system
per player, solvable by cramer in exact rationals with the determinant
machinery of chapter #xref-to("math", "matrices"). A candidate survives
only if every probability is strictly positive, every column pays at
least $v$ against $x$, and every row pays at most $v$ against $y$.

The dry run: pennies first, 5 systems. The 4 pure supports solve
trivially and die on the inequalities, 2 columns exploited, 2 rows. The
full support solves to (1/2, 1/2) with $v = 0$ and survives. Rock paper
scissors runs 19 systems: 9 pure, 9 of size 2, 1 full. Three of the
size 2 systems are singular, the stacked determinant is exactly 0, and
the survivor is the uniform (1/3, 1/3, 1/3) with value 0. The chapter
fixture $[[2, -1, 0], [-1, 1, 3], [0, 3, -1]]$ is the stress test: also
19 systems, 3 rejected for negative probabilities, 15 exploitable, and
one survivor, both players at exactly (14/31, 9/31, 8/31) with value
19/31, confirmed by direct evaluation of all 6 indifference equations.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*fixture*], [*systems*], [*singular*], [*negative*], [*exploitable*], [*survivor*]),
  [pennies], [5], [0], [0], [4], [(1/2, 1/2), $v = 0$],
  [rock paper scissors], [19], [3], [0], [15], [(1/3, 1/3, 1/3), $v = 0$],
  [3x3 fixture], [19], [0], [3], [15], [(14/31, 9/31, 8/31), $v = 19\/31$],
)

#listing("math/samples/src/Ch24/zerosum.c", first: 175, last: 221, caption: [zerosum.c, one support pair: stack both indifference systems with the probability sums, reject singular determinants, extract by cramer in fractions])

#listing("math/samples/src/Ch24/zerosum.c", first: 222, last: 243, caption: [zerosum.c, the validation half: positive probabilities, then no column dips below v and no row rises above v])

#diagram([support enumeration as a decision flow, each pair solved then filtered by singular, negative, and exploitability gates], length: 13pt, {
  let box(x, y, w, t, f) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: f, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, size: 6pt)
  }
  box(4.6, 8.2, 5.2, [support pair (S, T)], luma(235))
  box(4.6, 6.6, 5.2, [stack indifference systems], luma(245))
  box(4.6, 5.0, 5.2, [cramer solve x, y, v], luma(245))
  box(10.6, 6.6, 4.4, [singular: det = 0], luma(245))
  box(10.6, 5.0, 4.4, [negative probability], luma(245))
  box(10.6, 3.4, 4.4, [exploitable], luma(245))
  box(4.6, 3.4, 5.2, [check inequalities], luma(245))
  box(4.6, 1.8, 5.2, [accept equilibrium], luma(205))
  cdraw.line((7.2, 8.2), (7.2, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.line((7.2, 6.6), (7.2, 5.9), stroke: luma(60), mark: (end: ">"))
  cdraw.line((7.2, 5.0), (7.2, 4.3), stroke: luma(60), mark: (end: ">"))
  cdraw.line((7.2, 3.4), (7.2, 2.7), stroke: luma(60), mark: (end: ">"))
  cdraw.line((9.8, 7.05), (10.6, 7.05), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((9.8, 5.45), (10.6, 5.45), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((9.8, 3.85), (10.6, 3.85), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
})

#callout("pitfall", "TWO BLIND SPOTS OF EQUAL SIZE SUPPORTS",
  [A singular determinant is not an error, it is information: rock paper
  scissors makes three size 2 supports singular because the equalization
  degenerates, and the enumeration skips them. The equal size restriction
  is the other blind spot: degenerate games can hold equilibria whose two
  supports have different sizes, which this enumeration never visits. The
  general bimatrix case also drops the shared $v$, each player equalizes
  only the opponent's support. Both caveats are standard (Porter,
  Nudelman, Shoham, Simple Search Methods for Finding a Nash Equilibrium,
  AAAI 2004, journal version in Games and Economic Behavior 63(2), 2008,
  by name).])

== regret and follow the regularized leader

Equilibria are fixed points, but players arrive at them by playing.
Online learning reframes the problem: at each round the learner picks a
distribution over actions, the opponent reveals a move, and the loss
lands in [0, 1]. The cumulative regret is the gap between what the
learner paid and what the best single fixed action would have paid,
$R_T = sum_t ell (p^t, b^t) - min_i sum_t ell (i, b^t)$. Follow the
regularized leader with negative entropy collapses to exponential
weights: $w_i prop exp(-eta L_i)$ over the cumulative loss $L_i$, the
multiplicative weights update (Cesa-Bianchi and Lugosi 2006, by name).
For losses in [0, 1] the regret bound is $ln(n)\/eta + eta T\/8$.

The dry run: rock paper scissors losses win 0, tie 1/2, lose 1, a fixed
opponent stream from a seeded xorshift64, and the learner plays its own
distribution so every round is an exact expectation with no sampling
noise. The stream pins: the first two outputs 0xdc1b77ae0bf34dad and
0x64f0eeb9026e6076, opening actions 0, 0, 0, 0, 2, 0, 1, 0, 1, 1. After
200 rounds the fixed action losses are (101, 95.5, 103.5), best fixed is
paper, the learner paid 103.7574209924925, so the regret is
8.257420992492499, average 0.0413, inside the bound 26.09861228866811
and down from 0.0473 at round 50. The average regret ladder runs
0.1420, 0.0712, 0.0473, 0.0535, 0.0413 at rounds 10, 25, 50, 100, 200:
noisy round to round, decaying in trend.

#listing("math/samples/src/Ch24/ftrl.c", first: 65, last: 114, caption: [ftrl.c, the exponential weights loop against the fixed xorshift stream, regret captured at rounds 10, 25, 50, 100, 200])

#diagram([average regret of the pinned run, decaying from 0.142 at round 10 to 0.041 at round 200], length: 13pt, {
  let X(t) = { 2.0 + 10.0 * (t - 10) / 190.0 }
  let Y(r) = { 0.5 + 22.0 * r }
  let pts = ((10, 0.1420), (25, 0.0712), (50, 0.0473), (100, 0.0535), (200, 0.0413))
  for i in range(pts.len() - 1) {
    cdraw.line((X(pts.at(i).at(0)), Y(pts.at(i).at(1))), (X(pts.at(i + 1).at(0)), Y(pts.at(i + 1).at(1))), stroke: luma(60))
  }
  for p in pts {
    cdraw.circle((X(p.at(0)), Y(p.at(1))), radius: 0.11, fill: luma(30), stroke: none)
  }
  cdraw.line((0.8, 0.5), (12.4, 0.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.0, 0.2), (2.0, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.0, Y(0.0413)), (12.0, Y(0.0413)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((2.55, 0.14), [10], size: 6pt)
  cdraw.content((X(100), 0.15), [100], size: 6pt)
  cdraw.content((11.7, 0.15), [200], size: 6pt)
  cdraw.content((1.2, Y(0.1420) - 0.1), [0.142], size: 6pt)
  cdraw.content((1.2, Y(0.0413) + 0.1), [0.041], size: 6pt)
})

Why regret is the route to equilibria: in a two player zero sum game, if
both players' average regret goes to 0, the time average profile
approaches a minimax equilibrium and the average payoff approaches the
value. Outside zero sum the guarantee weakens: vanishing regret buys
welfare bounds for smooth games, not convergence to equilibrium (the folk
theorem of no regret learning, by name). The second phase checks the
zero sum half live: two learners with rates 1 and 0.7
self play the chapter's 3x3 fixture for 400 rounds, losses normalized
into [0, 1], and their average strategies land at (0.4385, 0.3116,
0.2499) and (0.4271, 0.2965, 0.2764), within 0.025 of the enumerated
equilibrium (14/31, 9/31, 8/31) with the average payoff 0.6350 against
the value 19/31 = 0.6129. The enumeration from the last section and the
learning dynamics in this one agree on the answer.

#listing("math/samples/src/Ch24/ftrl.c", first: 152, last: 188, caption: [ftrl.c, two rate self play on the 3x3 fixture, averages closing on the enumerated equilibrium])

#callout("verify", "AVERAGES CONVERGE, TRAJECTORIES DO NOT",
  [Exponential weights on a cyclic game oscillates forever: by round 200
  the phase 1 weights sit at 0.0041, 0.9956, 0.0003, nearly pure paper,
  and would swing on if the stream demanded it. Only the uniform time
  average (0.319, 0.341, 0.340) is meaningful, and it is the average the
  checks pin. This is also why the self play phase pins averages within
  0.025 rather than trajectories within an epsilon.])

Chapter #xref-to("math", "sequential") moves the players onto trees, where
one side observes the other before moving and the analysis tool becomes
backward induction instead of the fixed point.

sources: Osborne, An Introduction to Game Theory, Oxford University Press
2003, fixtures and dominance treatment cited by name and edition. The
minimax statement quoted from `en.wikipedia.org/wiki/Minimax_theorem` and
the nash existence sentence "John Nash showed that there is a Nash
equilibrium, possibly in mixed strategies, for every finite game" quoted
from `en.wikipedia.org/wiki/Nash_equilibrium`, both fetched 2026-09-22,
von Neumann 1928 and Nash 1950 as dated there. The LP duality link by
name from Boyd and Vandenberghe, Convex Optimization, Cambridge
University Press 2004, chapter 5, joined to the duality material of
chapter optimization. The regret bound form by name from Cesa-Bianchi
and Lugosi, Prediction, Learning, and Games, Cambridge University Press
2006, chapter 2, and Hazan, Introduction to Online Convex Optimization,
2nd edition, MIT Press, September 2022, chapter 5, the wikipedia FTRL and
multiplicative weights pages returned 404 on 2026-09-22 so no url is
cited for them. Support enumeration practice by name from Porter,
Nudelman, Shoham, Simple Search Methods for Finding a Nash Equilibrium,
AAAI 2004, journal version Games and Economic Behavior 63(2), 2008. No
mml mapping exists for game theory,
so this chapter cites the references above instead of mml page ranges.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/math/samples/src -Chapter Ch24`, 60 checks in chapter
24 of the math suite, zero failures, format and asan legs clean.
