#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= sequential and repeated games

Chapter #xref-to("math", "strategic") fixed what players choose when they
choose at once: one matrix, one mixed strategy each, one equilibrium test.
This chapter fixes what happens when they choose in order, and then when they
choose again and again. Six moves: the extensive-form tree as the honest data
structure for ordered moves, backward induction as the solver that reads
payoffs off the leaves, subgame perfection as the refinement that discards
threats nobody would carry out, information sets and behavioral strategies
for games where moves stay hidden, the discounted infinitely repeated
prisoner's dilemma where cooperation becomes an equilibrium, and the
second-price auction where telling the truth is a dominant strategy. Every
behavioral claim below is one of the 59 checks in the 4 samples of chapter
25 or a sentence paraphrased from a canonical source fetched 2026-09-22. The
#xref-to("dsa", "games") chapter runs the search algorithms over huge game
trees, this chapter is the theory of what those searches compute.

== the tree comes first

A game in extensive form is a specification that makes four things explicit:
the sequencing of the players' possible moves, the choices available at every
decision point, the information each player has when deciding, and the
payoffs for all outcomes. The normal form of chapter
#xref-to("math", "strategic") compresses all of that into a matrix and loses
the order, the extensive form keeps it as a tree. A node is a decision point
belonging to one player, an edge out of a node is one available action, and
a leaf carries a payoff pair, first number for player 1, second for player
2. The solver in this book represents that literally:

#listing("math/samples/src/Ch25/backward.c", first: 40, last: 67, caption: [c, the node record and the rollback recursion])

The recursion returns the subgame value: the payoff pair that plays out from
a node when whoever moves at each point picks the branch maximizing their own
coordinate. That self-interest rule is the whole theory of the chapter, and
it is three lines of code. The fixtures are fixed data, no parsing, no
randomness:

#listing("math/samples/src/Ch25/backward.c", first: 80, last: 95, caption: [c, the two fixed trees as data tables])

The dry run: fixture A. Player 1 opens at the root with $L$ or $R$, player 2
answers at either inner node, the leaves pay as follows.

+ At node 1 player 2 compares $a = (2,1)$ against $b = (0,3)$. The second
  coordinate is theirs, 3 beats 1, so the subgame value at node 1 is $(0,3)$
  reached by $b$.
+ At node 2 the same comparison gives $c = (1,4)$ over $d = (5,2)$, 4 beats
  2, subgame value $(1,4)$ reached by $c$.
+ At the root player 1 compares $(0,3)$ with $(1,4)$. The first coordinate
  is theirs, 1 beats 0, so player 1 enters $R$ and the game pays $(1,4)$.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*node*], [*mover*], [*options pay*], [*subgame value*], [*choice*]),
  [root], [player 1], [$L -> (0,3)$, $R -> (1,4)$], [$(1,4)$], [$R$],
  [node 1], [player 2], [$a -> (2,1)$, $b -> (0,3)$], [$(0,3)$], [$b$],
  [node 2], [player 2], [$c -> (1,4)$, $d -> (5,2)$], [$(1,4)$], [$c$],
)

The two numbers worth remembering from fixture A: player 1 can see payoff 5
sitting on the $d$ leaf under $R$, and rollback hands them 1, because the
branch that pays player 1 5 pays player 2 only 2. Greedy reading of your own
best leaf is not a solution concept.

#diagram([fixture A in extensive form, rollback values beside each node], length: 13pt, {
  let vdot(p, tag) = {
    cdraw.circle(p, radius: 0.42, fill: luma(205), stroke: luma(60))
    cdraw.content((p.at(0) - 1.05, p.at(1)), tag, size: 6pt)
  }
  let ldot(p) = cdraw.circle(p, radius: 0.28, fill: luma(235), stroke: luma(100))
  let edge(a, b, lab, off) = {
    cdraw.line(a, b, stroke: luma(100))
    cdraw.content(((a.at(0) + b.at(0)) / 2 + off.at(0), (a.at(1) + b.at(1)) / 2 + off.at(1)), lab, size: 6pt)
  }
  let root = (5.0, 8.4)
  let n1 = (2.8, 6.4)
  let n2 = (7.2, 6.4)
  let a = (1.4, 4.2)
  let b = (4.2, 4.2)
  let c = (5.8, 4.2)
  let d = (8.6, 4.2)
  edge(root, n1, [L], (-0.45, 0.1))
  edge(root, n2, [R], (0.45, 0.1))
  edge(n1, a, [a], (-0.35, 0.1))
  edge(n1, b, [b], (0.35, 0.1))
  edge(n2, c, [c], (-0.35, 0.1))
  edge(n2, d, [d], (0.35, 0.1))
  for (p, t) in ((a, [(2,1)]), (b, [(0,3)]), (c, [(1,4)]), (d, [(5,2)])) {
    ldot(p)
    cdraw.content((p.at(0), p.at(1) - 0.75), t, size: 6pt)
  }
  vdot(root, [p1])
  vdot(n1, [p2])
  vdot(n2, [p2])
  cdraw.content((5.0, 9.2), [(1,4)], size: 6.5pt)
  cdraw.content((4.0, 6.4), [(0,3)], size: 6.5pt)
  cdraw.content((8.4, 6.4), [(1,4)], size: 6.5pt)
})

== backward induction

Backward induction solves a finite perfect-information game by rolling back
from the leaves: at each node the mover keeps only the branch maximizing
their own payoff coordinate, the node inherits that branch's value, and the
argument climbs to the root. Why the result deserves the name solution:
induct on depth. A one-ply game is a table lookup, the mover takes their
best leaf. Assume rollback solves every tree of depth $n$, take a depth $n +
1$ tree, the root mover faces $n$-depth subtrees whose values the solver has
already computed, choosing the best of those values is exactly what the root
mover wants, so the induction closes. The rollback profile, one optimal
action per node, is the subgame perfect equilibrium, and in a game where
every node sees the whole history it is the only refinement worth the name.

The centipede is the standard stress test. Four nodes alternate the movers,
at each node the mover can take the pot or pass it along, take payoffs grow
down the chain, and passing all the way through pays the cooperative
terminal $(4,2)$.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*node*], [*mover*], [*take pays*], [*pass leads to*], [*value*], [*choice*]),
  [c4], [player 2], [(2,4)], [(4,2)], [$(2,4)$], [take],
  [c3], [player 1], [(3,1)], [c4 at (2,4)], [$(3,1)$], [take],
  [c2], [player 2], [(0,3)], [c3 at (3,1)], [$(0,3)$], [take],
  [c1], [player 1], [(1,0)], [c2 at (0,3)], [$(1,0)$], [take],
)

The dry run: start at the end. Player 2 at c4 keeps $(2,4)$, their 4 beats
the 2 of letting player 1 collect $(4,2)$. Climb one node: player 1 at c3
takes the certain $(3,1)$, their 3 beats the 2 they would get after c4.
Climb again: player 2 at c2 takes $(0,3)$, the 3 beats the 1 waiting at c3.
At the root player 1 compares the sure $(1,0)$ against $(0,3)$ and takes.
The unraveling is total, and the two numbers of the section are the rollback
terminal $(1,0)$ against the unreached cooperative terminal $(4,2)$: both
players would prefer the walk to the end, neither can afford the first step
of it.

#listing("math/samples/src/Ch25/backward.c", first: 183, last: 204, caption: [c, centipede rollback checks and the unraveling walk])

#diagram([the centipede, take drops out and pass chains right, rollback value above each node], length: 13pt, {
  let y = 6.0
  let xs = (1.2, 3.2, 5.2, 7.2)
  let tags = ([p1], [p2], [p1], [p2])
  let vals = ([(1,0)], [(0,3)], [(3,1)], [(2,4)])
  let takes = ([(1,0)], [(0,3)], [(3,1)], [(2,4)])
  for i in range(4) {
    let x = xs.at(i)
    cdraw.circle((x, y), radius: 0.42, fill: luma(205), stroke: luma(60))
    cdraw.content((x - 0.55, y - 0.95), tags.at(i), size: 6pt)
    cdraw.content((x, y + 1.05), vals.at(i), size: 6.5pt)
    cdraw.line((x, y - 0.55), (x, 3.55), stroke: if i == 0 { luma(60) } else { luma(100) }, mark: (end: ">"))
    cdraw.content((x + 0.5, y - 1.35), [take], size: 6pt)
    cdraw.circle((x, 3.0), radius: 0.28, fill: luma(235), stroke: luma(100))
    cdraw.content((x, 2.25), takes.at(i), size: 6pt)
  }
  for i in range(3) {
    cdraw.line((xs.at(i) + 0.55, y), (xs.at(i + 1) - 0.55, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content(((xs.at(i) + xs.at(i + 1)) / 2, y + 0.55), [pass], size: 6pt)
  }
  cdraw.line((7.75, y), (9.1, y), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.4, y + 0.55), [pass], size: 6pt)
  cdraw.circle((9.5, 6.0), radius: 0.28, fill: luma(235), stroke: luma(100))
  cdraw.content((9.5, 5.25), [(4,2)], size: 6pt)
})

#callout("pitfall", "ties multiply equilibria", [When two branches pay the
mover exactly the same, rollback must keep a set of choices, not a choice,
and every combination down that set is a distinct subgame perfect
equilibrium. The solver keeps the first argmax and so pins one witness,
which is all a check needs, but the theory counts all of them. Every fixture
in this chapter was chosen with strict inequalities at every node.])

== subgame perfection and credible threats

A subgame is a node together with all of its descendants, cut so that it
starts at a single node and never splits an information set. A strategy
profile is a subgame perfect equilibrium when it induces a Nash equilibrium
in every subgame, the whole game included. The equilibrium set only shrinks
under this test: every subgame perfect equilibrium is a Nash equilibrium,
the converse fails exactly when a Nash profile rests on a plan of action the
player would abandon if the moment to execute it ever arrived. Textbooks
call those non-credible threats, and infinite-horizon arguments replace the
direct subgame scan with the one-shot deviation principle, but the finite
test on a tree is the plain one to implement.

Entry deterrence is the canonical fixture. An entrant moves first, in or
out. If the entrant stays out the incumbent keeps the quiet market at
$(1,4)$. If the entrant comes in, the incumbent chooses to fight, a price
war paying $(0,1)$, or accommodate, sharing the market at $(2,3)$.

The dry run: enumerate all four profiles. Against fight the entrant compares
0 with 1 and stays out, against accommodate they compare 2 with 1 and enter.
Against out the incumbent is indifferent, the fight branch is never
exercised, so both replies are best responses. Two profiles survive as Nash:
(out, fight), propped up by a threat, and (in, accommodate). The subgame
test kills the first one, inside the incumbent's subgame fight pays 1 where
accommodate pays 3, so the threat fails the moment it becomes a real
decision.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*profile*], [*induces*], [*entrant best reply*], [*nash*], [*subgame perfect*]),
  [(in, fight)], [$(0,1)$], [no], [no], [no],
  [(in, accommodate)], [$(2,3)$], [yes], [yes], [yes],
  [(out, fight)], [$(1,4)$], [yes], [yes], [no],
  [(out, accommodate)], [$(1,4)$], [no], [no], [no],
)

#listing("math/samples/src/Ch25/backward.c", first: 143, last: 160, caption: [c, the nash test and the node-by-node subgame test])

#listing("math/samples/src/Ch25/backward.c", first: 231, last: 254, caption: [c, enumerating all four profiles])

Two Nash equilibria, one subgame perfect equilibrium, and the difference is
the whole point of the refinement. Rollback from section 2 found (in,
accommodate) without ever writing the normal form down, which is the
practical content of the equivalence: on a tree, backward induction is the
subgame perfection computation.

#diagram([entry deterrence, the dashed box is the incumbent subgame where the threat fails], length: 13pt, {
  let root = (2.6, 7.4)
  let out = (0.9, 5.6)
  let inc = (4.6, 5.6)
  let f = (3.3, 3.4)
  let acc = (6.3, 3.4)
  cdraw.line(root, (1.21, 5.93), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.4, 6.75), [out], size: 6pt)
  cdraw.line(root, (4.19, 5.97), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.85, 6.85), [in], size: 6pt)
  cdraw.line(inc, (3.53, 3.79), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.3, 4.6), [fight], size: 6pt)
  cdraw.line(inc, (6.03, 3.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.35, 4.6), [accommodate], size: 6pt)
  cdraw.circle(root, radius: 0.42, fill: luma(205), stroke: luma(60))
  cdraw.content((2.6, 8.15), [entrant], size: 6pt)
  cdraw.circle(inc, radius: 0.42, fill: luma(205), stroke: luma(60))
  cdraw.content((4.6, 6.3), [incumbent], size: 6pt)
  for (p, t) in ((out, [(1,4)]), (f, [(0,1)]), (acc, [(2,3)])) {
    cdraw.circle(p, radius: 0.28, fill: luma(235), stroke: luma(100))
    cdraw.content((p.at(0), p.at(1) - 0.75), t, size: 6pt)
  }
  cdraw.rect((2.35, 2.45), (7.3, 6.15), stroke: (paint: luma(150), dash: "dashed"), radius: 0.05)
  cdraw.content((3.1, 5.5), [the subgame], size: 6pt)
})

#callout("note", "subset, not replacement", [Subgame perfection refines Nash,
it never contradicts it: the subgame perfect set is always a subset of the
Nash set, and the ultimatum game is the classic case of a large gap between
the two. When the horizon is infinite and no last subgame exists to start
from, the one-shot deviation principle carries the same filtering role.])

== imperfect information

Perfect information means the mover at every node knows exactly which node
they are at. Drop that and the tree needs one more structure: an information
set is a set of decision nodes, all belonging to one player, that the player
cannot tell apart when the game reaches them. The convention draws the set
as a dotted line through its nodes, and a game with any multi-node set is a
game of imperfect information. Simultaneous moves model as information sets
exactly, chapter #xref-to("math", "strategic") in tree clothing. A strategy
now assigns probabilities to actions at each information set, a behavioral
strategy, and when every player remembers what they knew and did, perfect
recall, Kuhn's theorem says behavioral strategies reach every mixed-strategy
payoff, so nothing is lost by attaching the probabilities to the tree.

Matching pennies in extensive form is the smallest honest example. Player 1
puts a coin down heads or tails, unseen, player 2 calls heads or tails from
one information set spanning both of player 2's nodes, and same sides pays
$(1,-1)$ while a mismatch pays $(-1,1)$. With $p$ the probability of heads
for player 1 and $q$ for player 2, player 1's expectation is
$"EV" = 2(p q + (1-p)(1-q)) - 1$. At $p = 1/2$ the two products balance for
every $q$, the check pins $"EV" = 0$ at $q in {0, 1/4, 1/2}$, while against
$q = 1/4$ the pure reply tails is worth exactly $1/2$ and heads exactly
$-1/2$. Randomizing exactly at the middle is what makes the opponent's
randomization irrelevant, the equalizing idea from chapter
#xref-to("math", "strategic") transplanted into the tree.

#listing("math/samples/src/Ch25/imperfect.c", first: 84, last: 92, caption: [c, the pennies expectation in exact rationals])

Poker is where information sets earn their keep. The fixture is half-street
Kuhn poker: three cards $J < Q < K$, one ante each, player 1 bets or
checks, a bet hands player 2 a call-or-fold decision, checks run to a
showdown over the antes, called bets run to a showdown over the raised pot.
Player 2 decides from information sets keyed by their own card alone, three
sets of two nodes each, because the node reached also encodes player 1's
hidden card. The enumeration walks the six equiprobable deals:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*deal (p1, p2)*], [*p1 line*], [*outcome*], [*conditional EV*]),
  [$(J, Q)$], [check], [showdown loss], [$-1$],
  [$(J, K)$], [check], [showdown loss], [$-1$],
  [$(Q, J)$], [check], [showdown win], [$+1$],
  [$(Q, K)$], [check], [showdown loss], [$-1$],
  [$(K, J)$], [bet], [fold], [$+1$],
  [$(K, Q)$], [bet], [call with $1/2$], [$3/2$],
)

The dry run: profile A bets the king only, calls the king always, calls the
queen with probability $1/2$, folds the jack. The deal column sums to
$1/2$, dividing by 6 deals gives the pinned per-hand value $"EV" = 1/12$, and
the game is zero sum so player 2 loses $1/12$. Profile B adds a jack bluff
with probability $1/4$: the two jack deals now average $-7/8$ and $-5/4$,
the sum drops to $3/8$, and the per-hand value falls to exactly $1/16$.
Bluffing a quarter of the time into an opponent who folds jacks and calls
queens half the time costs exactly $1/48$ per hand. Every row of the deal
table, both intermediates, and both sums are checks in the sample, so the
walk above is pinned column by column, not just in its totals. All of it
lands in exact rational arithmetic, a normalized numerator and denominator
over `long long` with no floating point anywhere.

#listing("math/samples/src/Ch25/imperfect.c", first: 94, last: 124, caption: [c, the kuhn poker per-deal expectation, its sum, and the average])

#listing("math/samples/src/Ch25/imperfect.c", first: 153, last: 186, caption: [c, the behavioral profiles with per-deal and average pins])

#callout("verify", "rederiving the pins", [Every fraction in this section
reproduces from the one-off `playground/math-ch25/pin.py`, python with
`fractions.Fraction` and no floats, run 2026-09-22. The script mirrors the C
expression order, so a mismatch between the two is a bug in the chapter, not
in the arithmetic.])

#diagram([matching pennies in extensive form, the dotted line is player 2's information set], length: 13pt, {
  let root = (5.0, 8.0)
  let lh = (2.9, 6.0)
  let lt = (7.1, 6.0)
  let e = ((1.7, 4.0), (4.1, 4.0), (5.9, 4.0), (8.3, 4.0))
  let pays = ([(1,-1)], [(-1,1)], [(-1,1)], [(1,-1)])
  let labs = ([h], [t], [h], [t])
  cdraw.line(root, lh, stroke: luma(100))
  cdraw.content((3.55, 7.25), [H], size: 6pt)
  cdraw.line(root, lt, stroke: luma(100))
  cdraw.content((6.45, 7.25), [T], size: 6pt)
  cdraw.line(lh, e.at(0), stroke: luma(100))
  cdraw.content((1.95, 5.15), [h], size: 6pt)
  cdraw.line(lh, e.at(1), stroke: luma(100))
  cdraw.content((3.85, 5.15), [t], size: 6pt)
  cdraw.line(lt, e.at(2), stroke: luma(100))
  cdraw.content((6.15, 5.15), [h], size: 6pt)
  cdraw.line(lt, e.at(3), stroke: luma(100))
  cdraw.content((8.05, 5.15), [t], size: 6pt)
  cdraw.line((3.45, 6.0), (6.55, 6.0), stroke: (paint: luma(150), dash: "dotted"))
  cdraw.content((5.0, 6.45), [information set], size: 6pt)
  cdraw.circle(root, radius: 0.42, fill: luma(205), stroke: luma(60))
  cdraw.content((5.0, 8.75), [p1], size: 6pt)
  for p in (lh, lt) {
    cdraw.circle(p, radius: 0.42, fill: luma(205), stroke: luma(60))
  }
  cdraw.content((2.9, 6.6), [p2], size: 6pt)
  cdraw.content((7.1, 6.6), [p2], size: 6pt)
  for i in range(4) {
    cdraw.circle(e.at(i), radius: 0.28, fill: luma(235), stroke: luma(100))
    cdraw.content((e.at(i).at(0), 3.25), pays.at(i), size: 6pt)
  }
})

== repetition and the discount factor

Play the prisoner's dilemma once and defection dominates, chapter
#xref-to("math", "strategic") says so and the stage payoffs say why:
temptation $T = 5$, reward $R = 3$, punishment $P = 1$, sucker $S = 0$.
Play it forever with future payoffs discounted by $delta$ per round and the
value of cooperating forever is $R/(1-delta)$, a perpetuity the code
computes as one exact fraction. Grim trigger is the simplest cooperative
plan: cooperate unless anyone has ever defected, then defect forever. It
sustains cooperation when deviating does not pay inside any clean-history
subgame, and the comparison collapses to one line,
$T + (delta P)/(1-delta) <= R/(1-delta)$, which rearranges to
$delta >= (T - R)/(T - P)$. For this stage game the threshold is
$(5-3)/(5-1) = 1/2$, exactly.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*delta*], [*grim pair*], [*always-defect pair*], [*one-shot deviation*], [*verdict*]),
  [$2/3$], [$9$], [$3$], [$7$], [cooperation holds, $9 > 7$],
  [$1/2$], [$6$], [$2$], [$6$], [knife edge, exact tie],
  [$2/5$], [$5$], [$5/3$], [$17/3$], [deviation wins, $17/3 > 5$],
)

The dry run at $delta = 2/3$: the grim pair is worth $3/(1/3) = 9$ per
player, mutual defection forever is worth $1/(1/3) = 3$, and a player who
abandons cooperation in some round collects 5 once then 1 forever,
$5 + (2/3) times 3 = 7$. The deviation gain is $-2$ at every round, the
$delta^k$ prefix cancels, and multiplying by $delta$ each round keeps the
sign negative forever, verified exactly through round 20. At $delta = 1/2$
the gain is identically zero, the knife edge the formula predicts, and at
$delta = 2/5$ it turns positive at $2/3$. The scan over the grid $k/10$
finds the flip exactly between $4/10$ and $5/10$.

#listing("math/samples/src/Ch25/repeated.c", first: 81, last: 100, caption: [c, perpetuities, deviation gains, and the finite-horizon counter])

#listing("math/samples/src/Ch25/repeated.c", first: 106, last: 114, caption: [c, values at three discount factors])

Two further facts complete the picture. The folk theorem, in sketch: for
patient enough players, every feasible payoff vector that gives each player
more than their minmax security level can be sustained as an equilibrium,
and the feasible set is the convex hull of the stage payoff pairs, the same
convex-combination geometry mml-book draft 2024-01-15 develops in its
chapter 7.3 convexity discussion. And the finite horizon kills everything:
a 10-round game against grim cooperates on paper but the last round is a
one-shot dilemma with no tomorrow, so holding the one defection to round 9
earns $9 times 3 + 5 = 32$ against 30 for full cooperation, immediate
defection earns a flat 14, and each round of delay is worth exactly 2. The
unraveling is the centipede's logic wearing a calendar.

#listing("math/samples/src/Ch25/repeated.c", first: 152, last: 171, caption: [c, the ten-round unraveling enumeration])

#diagram([stage payoffs by round at delta 2/3, flat 3 for cooperation against 5 then 1 for deviation], length: 13pt, {
  let x0 = 0.9
  let y0 = 0.9
  let unit = 1.0
  let tick = (1.8, 3.3, 4.8, 6.3, 7.8, 9.3)
  cdraw.line((x0, y0), (10.6, y0), stroke: luma(140), mark: (end: ">"))
  cdraw.line((x0, y0), (x0, 6.6), stroke: luma(140), mark: (end: ">"))
  for t in range(6) {
    cdraw.content((tick.at(t), y0 - 0.45), str(t), size: 6pt)
    cdraw.circle((tick.at(t), y0), radius: 0.06, fill: luma(100))
  }
  for v in (1, 3, 5) {
    cdraw.content((x0 - 0.45, y0 + v * unit), str(v), size: 6pt)
    cdraw.line((x0 - 0.1, y0 + v * unit), (x0 + 0.1, y0 + v * unit), stroke: luma(140))
  }
  cdraw.content((10.4, y0 - 0.45), [round], size: 6pt)
  cdraw.content((1.35, 6.5), [payoff], size: 6pt)
  cdraw.line((1.8, y0 + 3 * unit), (9.3, y0 + 3 * unit), stroke: luma(140))
  cdraw.content((5.5, y0 + 3 * unit + 0.35), [cooperate forever: 3 per round, value 9], size: 6pt)
  cdraw.line((1.8, y0 + 5 * unit), (3.3, y0 + 5 * unit), stroke: luma(60))
  cdraw.line((3.3, y0 + 5 * unit), (3.3, y0 + 1 * unit), stroke: luma(60))
  cdraw.line((3.3, y0 + 1 * unit), (9.3, y0 + 1 * unit), stroke: luma(60))
  cdraw.content((6.4, y0 + 1 * unit + 0.35), [deviate: 5 once then 1, value 7], size: 6pt)
})

#callout("warning", "normalization changes numbers, not verdicts", [Some
texts average discounted payoffs as $(1-delta) sum delta^t u_t$, which
rescales every value here, the grim pair 9 becomes 3 times $(1-delta)$, but
never flips a comparison, because the rescaling is a positive constant per
profile. The pins in this chapter use the plain sum convention, state which
one you are reading before comparing across sources.])

== paying the second price

An auction is a game whose tree the designer writes, and mechanism design is
the discipline of writing it so the equilibrium is the outcome you wanted.
The sealed-bid second-price auction, the Vickrey auction, is the cleanest
specimen: bidders submit sealed bids, the highest bidder wins, the price
paid is the second-highest bid. Bidding your true value is a dominant
strategy. The argument is two cases, with $v$ your value, $b$ your bid, and
$m$ the best opposing bid. Bid above value, $b > v$: if $m < v$ you won
anyway at price $m$ and the raise did nothing, if $v <= m < b$ the raise
hands you a win at price above value, negative utility. Bid below value,
$b < v$: if $m >= v$ you lost anyway, if $b <= m < v$ the shave turns a win
at price $m$ below value into a loss, throwing away surplus $v - m$. No
deviation ever strictly helps, whatever the others do.

The fixture pins it exhaustively: values $(10, 7, 4)$, all opponent bid
pairs in $0..12$, all own deviations in $0..12$, ties to the lowest index.
Truth pays the winner $10 - 7 = 3$, losers pay nothing, and the improvement
count over truth is zero for every bidder, 3 x 2197 evaluated profiles. The
same grid under the first-price rule, winner pays own bid, tells the
opposite story: truth earns the winner $10 - 10 = 0$, shaving to 7 against
truthful rivals wins the tie and earns 3, and 385 grid points strictly beat
truth for bidder 1. One payment rule makes honesty safe, the other taxes it.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*rule*], [*winner pays*], [*utility of bidder 1*], [*deviations beating truth*]),
  [second price, truthful bids], [second bid 7], [$3$], [0 of 2197],
  [first price, truthful bids], [own bid 10], [$0$], [385 of 2197],
)

#listing("math/samples/src/Ch25/auction.c", first: 40, last: 64, caption: [c, winner rule and the two payment rules])

#listing("math/samples/src/Ch25/auction.c", first: 66, last: 87, caption: [c, the improvement-counting grid scan])

The dry run on the two boundary cases the proof isolates: bidder 2 with
value 7 facing rivals bidding 10 and 4 loses truthfully for 0, overbidding
to 11 wins and pays 10 for utility $-3$. Bidder 1 with value 10 facing 6
and 4 wins truthfully at price 6 for utility 4, shaving to 5 loses it all
for 0. Raising bids can only create wins at prices above value, lowering
them can only cancel wins at prices below it, and that asymmetry is the
entire mechanism. The generalization, paying each winner the externality
they impose, is the VCG family, and the second-price auction is its
single-item case.

#diagram([the same bids under two payment rules, truth pays 3 at second price and 0 at first price], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  let arrow(a, b) = cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.5, 7.6), [second price], size: 6.5pt)
  box(0.4, 6.2, 2.6, [bids (10,7,4)])
  box(3.8, 6.2, 2.8, [bidder 1 wins])
  box(7.4, 6.2, 3.4, [pays second bid 7])
  arrow((3.0, 6.7), (3.8, 6.7))
  arrow((6.6, 6.7), (7.4, 6.7))
  cdraw.content((9.1, 5.75), [u = 10 - 7 = 3, truth dominant], size: 6pt)
  cdraw.content((5.5, 3.1), [first price], size: 6.5pt)
  box(0.4, 1.7, 2.6, [bids (10,7,4)])
  box(3.8, 1.7, 2.8, [bidder 1 wins])
  box(7.4, 1.7, 3.4, [pays own bid 10])
  arrow((3.0, 2.2), (3.8, 2.2))
  arrow((6.6, 2.2), (7.4, 2.2))
  cdraw.content((9.1, 1.25), [u = 0, shading to 7 earns 3], size: 6pt)
})

The equilibrium ideas scale past auctions into any protocol where
participants report private information, and the next chapter
#xref-to("math", "adt") leaves the referee's standpoint entirely, building
the tagged data types that carry exactly such structured outcomes through
real C programs.

sources: Martin J. Osborne, An Introduction to Game Theory, Oxford
University Press 2004, chapters 5 through 7 for extensive games, backward
induction, subgame perfection and repeated games, cited by name and edition,
no page text quoted. H. W. Kuhn, "Simplified Two-Person Poker", in
Contributions to the Theory of Games I, Princeton University Press 1950,
the three-card fixture, cited by name. Wikipedia, "Extensive-form game",
en.wikipedia.org/wiki/Extensive-form_game, "Subgame perfect equilibrium",
en.wikipedia.org/wiki/Subgame\_perfect\_equilibrium, "Grim trigger",
en.wikipedia.org/wiki/Grim\_trigger, "Vickrey auction",
en.wikipedia.org/wiki/Vickrey\_auction, all fetched 2026-09-22, cc by-sa
4.0, our own words and code throughout. mml-book draft 2024-01-15: game
theory has no mapped chapter, the convex-hull sentence in section 5 points
at its ch 7.3 convexity material as a prose bridge without quotation. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch25`,
59 checks in chapter 25 of the math suite, format and asan clean.
