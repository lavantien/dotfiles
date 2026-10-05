// book 10, chapter 8: icpc world finals 2017, rapid city. twelve problems
// a through l, every one walked in c, c#, go, javascript, python and lua,
// listings sliced from the frozen solver files under samples-c, samples,
// samples-go, samples-js, samples-py and samples-lua
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= icpc world finals 2017

The 2017 World Finals ran in Rapid City, South Dakota with twelve
problems, #link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[A through L on the contest pdf]. By the solved-by counts printed in the official solutions, E, I and C fell to 127, 127 and 105 teams while H fell to none and J to exactly one, so this set pairs reach problems with two that punished every early guess. It was also the first finals where Python was offered, and the judges wrote more Python solutions than the teams did. The problem statements are paraphrased in this book's own words, and the cached
#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/finals2017solutions.pdf")[official solutions pdf] is the algorithm reference for every method and complexity claim in this chapter, cited per problem. Each section walks one problem through the same six solvers, pins a crafted fixture against a hand-computed answer, and closes with one diagram of the method.

== the year-local helpers: chord geometry, matching, flow, and rank selection

Four helper kits are year-local to 2017, one per problem that wanted
one, and everything else the year's solvers import comes from the
wave 1 toolbox chapters 2 through 7. Each kit states its contract
and prints its twin files below in the book's fixed language order.

The geom kit backs problem A with the year's hardest contract: given
a chord's two supporting vertices, classify every contact the island
boundary makes with the chord's line, transversal crossing,
touch-and-return, or a run along the line, and return the longest
closed segment of that line lying on the island. C keeps every
breakpoint an exact fraction n over m compared in `__int128` inside
`Ch08/ch08_geom.h`'s `geo_events`, go walks doubles whose integer
crosses stay exact at these coordinates through
`ch08/ch08_geom.go`, and lua's `ch08_geom.lua` exposes one
`best_span` that does the whole parity walk. C\#, JavaScript and
Python keep their own versions inside their problem A solvers. A
maximal chain of on-line vertices is what the kit earns its keep on:
the chain toggles the crossing parity exactly once, at its entry and
its exit, and the lua solver in section A is the thin driver that
hands every vertex pair to it.

#listing("icpc/samples-c/src/Ch08/ch08_geom.h", first: 46, last: 87, caption: [c: the geo_events vertex walk, on-line vertices classified touch or transversal, collinear edges kept as covered spans])

#listing("icpc/samples-go/ch08/ch08_geom.go", first: 10, last: 53, caption: [go: cross3 and distPointSeg exact in float64 at these coordinates, insidePoly boundary-inclusive by ray parity])

#listing("icpc/samples-lua/ch08_geom.lua", first: 12, last: 62, caption: [lua: best_span collects breakpoints and toggles, a maximal chain of on-line vertices scanned from an off-line start])

The match kit backs problem C with Kuhn's augmenting-path bipartite
matching over at most 200 plus 200 nodes, all the per-height row and
column graphs ever need. C passes a dense n by m byte matrix to
`match_kuhn`, go's `kuhnMatch` takes adjacency lists, lua's
`match.kuhn` the same lists, and all three twins fit whole because
the contract is one recursive augment. JavaScript inlines the
augment over typed arrays, C\# augments directly on the column list,
and Python recurses through a closure, each inside its problem C
solver.

#listing("icpc/samples-c/src/Ch08/ch08_match.h", first: 1, last: 33, caption: [c: kh_try augments over the dense byte matrix, match_kuhn resets and drives it per row])

#listing("icpc/samples-go/ch08/ch08_match.go", first: 1, last: 38, caption: [go: kuhnMatch over adjacency lists, the recursive augment closing over matchR and seen])

#listing("icpc/samples-lua/ch08_match.lua", first: 1, last: 31, caption: [lua: match.kuhn over ipairs adjacency lists, 1-based match_r with 0 for unmatched])

The dinic kit backs problem J with Dinic's max flow over at most 201
nodes in double capacities and epsilon comparisons, the alpha mix of
two integral flows being fractional, edge slots retained so per-pipe
flows read off the residual, and a maxflow that accumulates so the
section's four runs chain on one network. C carries the paired-arc
edge list in `Ch08/ch08_dinic.h`, go, javascript and lua the same
shape in `ch08/ch08_dinic.go`, `ch08-dinic.mjs` and
`ch08_dinic.lua`, the three with a paired-capacity `addUndirected`
for the pipes, while C\#'s dense matrix with conservation asserts
and Python's inline class live inside their problem J solvers.

#listing("icpc/samples-c/src/Ch08/ch08_dinic.h", first: 64, last: 109, caption: [c: dinic_bfs levels the graph, dinic_dfs walks current arcs, dinic_maxflow accumulates, doubles past DINIC_EPS])

#listing("icpc/samples-go/ch08/ch08_dinic.go", first: 64, last: 97, caption: [go: the level-graph dfs on current-arc iter, then maxflow accumulating across sequential source runs])

#listing("icpc/samples-js/src/ch08-dinic.mjs", first: 29, last: 75, caption: [javascript: the same bfs, dfs and accumulating maxflow over adjacency arrays of paired arcs])

#listing("icpc/samples-lua/ch08_dinic.lua", first: 57, last: 89, caption: [lua: dinic.dfs on current-arc iterators, dinic.maxflow accumulating across the four runs])

The fenwick kit backs problem L with a fenwick of counts over
compressed row ranks: select by binary descent for the k-th active
rank, `pred` for the largest active row at most the queried corner,
and `succ` for the smallest above it, the order statistics the
column sweep matches corners with. C's `Ch08/ch08_fenwick.h` carries
the whole contract in fifty lines, go and lua print the descent and
the two queries, javascript the identical class, while Python
inlines the tree in its solver and C\# keeps a private nested
Fenwick with Pred and Succ inside PL.

#listing("icpc/samples-c/src/Ch08/ch08_fenwick.h", first: 1, last: 50, caption: [c: fw_select by binary descent down the counting tree, fw_pred the largest active index at most x])

#listing("icpc/samples-go/ch08/ch08_fenwick.go", first: 29, last: 60, caption: [go: selectK descends the counting tree, pred and succ answer the sweep's corner queries])

#listing("icpc/samples-js/src/ch08-fenwick.mjs", first: 1, last: 45, caption: [javascript: the same class, selectK by descent, pred and succ over prefix counts])

#listing("icpc/samples-lua/ch08_fenwick.lua", first: 29, last: 54, caption: [lua: select_k descends the 1-based counting tree, pred and succ wrapping it])

C\# and Python carry no twin file in any of the four kits: their
solvers inline the predicates, classes and closures in the listings
of sections A, C, J and L.

== problem A, airport construction

Piconesia is a tropical island nation that wants its first airport,
and since a longer landing strip accommodates larger airplanes it
wants the longest strip it can build. The island's boundary is
modeled as a polygon, the strip is a straight line segment that must
lie on the island, it may touch or run along the boundary but must
never intersect the sea, and the task is to print the length of the
longest such segment (#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is one integer n, 3 <= n <= 200 by the problemset pdf, then
n lines of two integers x and y with |x| and |y| at most 10^6, the
polygon's vertices in counterclockwise order. The pdf promises the
polygon is simple, vertices distinct, edges touching only where
consecutive edges share their common vertex, and no two consecutive
edges collinear, a promise that tames every degenerate touching case.
The output is the single length within an absolute or relative error
of 10^-6, the judge answers printed to nine decimals, under the pdf's
2 second time limit.

Official sample 1, reprinted byte for byte from the judge data pair
`A-airport/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: the seven-vertex island's winning strip runs vertex to
vertex for 76.157731059.

input:

```
7
0 20
40 0
40 20
70 50
50 70
30 50
0 50
```

expected output:

```
76.157731059
```

Recognition: the bounds choose the search shape before any geometry
does. With n <= 200 under the 2 second limit, the 200 choose 2 =
19900 vertex-pair lines are enumerable outright, and classifying one
line against the boundary walks the 200 edges once, about 4 million
exact integer crosses for the whole search, an O(n^3) shape with two
orders of magnitude to spare.

The statement's own wording, the longest segment lying on the
island, hands over the candidate set: an optimal strip can always be
slid and stretched until its supporting line pins against two
polygon vertices, the cue that turns a continuous placement search
into 19900 discrete lines. Problem A is the 2017 face of the
geometric critical-point enumeration family. Geometric
critical-point enumeration is the shared shape of chapter 08 problem
D, chapter 09 problem E, chapter 09 problem G, chapter 11 problem T,
and chapter 12 problem D.

The tempting shortcut, rotating calipers over the convex hull, is
priced out by the shape itself: the hull pads every bay with sea,
sample 1's own hull already fills the reflex notch at (40,20), so a
caliper chord can cross water and certifying any hull pair still
needs the O(n) walk against the original boundary that the full
enumeration already pays 19900 times inside the budget, while a
continuous ternary search over strip placement has no unimodality
on a non-convex boundary to exploit.

The solutions pdf, page 2, settles the shape of an optimum: the
strip's line passes through two polygon vertices. So the search tries
all O(n^2) vertex pairs, tests that the chord between a pair lies on
the island, and extends that chord along its line out to the polygon
boundary in both directions, O(n^3) total for n <= 200 and comfortably
inside the limit. The whole difficulty sits in the extension: the
chord's line can touch an edge at a point, run along it, and veer
back to its own side, or cross over to the far side, and only the
crossing toggles the inside parity, so the classifier has to tell a
touch-and-return from a touch-and-cross using exact integer cross
products on the given coordinates. Book 9's chapter 24, lattice
geometry and grid algorithms, develops that lattice polygon
arithmetic from scratch. Six solvers, six exactness strategies on
that classification.

The worked run: trace the model on sample 1. The island is the
seven printed vertices, so the enumeration visits 7 choose 2 = 21
lines, and three of them carry the story. The pair (0,50), (70,50)
is the horizontal y = 50: the boundary lies along it over the edge
from (0,50) to (30,50), that on-line chain toggles the crossing
parity once because its entry and exit sides differ, and the
boundary stretch merges with the interior stretch out to (70,50)
for a run of exactly 70 - 0 = 70. The pair (40,20), (50,70)
exercises the extension: at (40,20) both neighboring edges sit on
the same side of the line, a touch and not a crossing, so the run
does not stop at the vertex but continues to where the line leaves
the island through the edge (0,20)-(40,0), y = 20 - x/2 meeting
y = 5x - 180 at (400/11, 20/11), and from there to (50,70) the
horizontal reach is 50 - 400/11 = 150/11 at slope 5, a run of
(150/11) sqrt(26) = 69.532. The runner-up is the pair (0,20),
(50,70), a plain chord of legs 50 - 0 = 50 and 70 - 20 = 50 worth
50 sqrt(2) = 70.711. The winner is the pair (0,20), (70,50): legs
70 - 0 = 70 and 50 - 20 = 30, and at both endpoints the neighboring
edges sit on opposite sides of the line, crosses +210 against -260
at (0,20) and -120 against +200 at (70,50), so both ends are
transversal crossings, the extension adds nothing, and the run is
exactly the chord, sqrt(70^2 + 30^2) = sqrt(5800) = 76.1577310586,
and the trace ends at the printed answer `76.157731059`.

#diagram([the sample-1 island, the winning chord from (0,20) to (70,50), the rejected (40,20)-(50,70) line extended to its boundary exit], length: 12pt, {
  cdraw.line((1.8, 3.1), (6.2, 0.9), stroke: luma(60))
  cdraw.line((6.2, 0.9), (6.2, 3.1), stroke: luma(60))
  cdraw.line((6.2, 3.1), (9.5, 6.4), stroke: luma(60))
  cdraw.line((9.5, 6.4), (7.3, 8.6), stroke: luma(60))
  cdraw.line((7.3, 8.6), (5.1, 6.4), stroke: luma(60))
  cdraw.line((5.1, 6.4), (1.8, 6.4), stroke: luma(60))
  cdraw.line((1.8, 6.4), (1.8, 3.1), stroke: luma(60))
  cdraw.line((1.8, 3.1), (9.5, 6.4), stroke: luma(20), width: 0.7)
  cdraw.line((5.8, 1.1), (7.3, 8.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((1.8, 3.1), radius: 0.12, stroke: luma(20), fill: white)
  cdraw.circle((9.5, 6.4), radius: 0.12, stroke: luma(20), fill: white)
  cdraw.circle((5.8, 1.1), radius: 0.1, stroke: luma(120))
  cdraw.content((9.8, 6.7), [winner (0,20) to (70,50)], size: 6.5pt, anchor: "west")
  cdraw.content((9.8, 6.0), [sqrt(5800) = 76.157731059], size: 6.5pt, anchor: "west")
  cdraw.content((9.8, 5.3), [both ends cross, the chord is the whole run], size: 6pt, anchor: "west", fill: luma(110))
  cdraw.content((7.7, 9.1), [rejected (40,20)-(50,70), extended, 69.532], size: 6.5pt, anchor: "south", fill: luma(110))
  cdraw.content((6.4, 0.85), [run exits at (400/11, 20/11)], size: 6pt, anchor: "north")
})

#listing("icpc/samples-c/src/Ch08/pA.c", first: 24, last: 64, caption: [c: events as exact fractions sorted in #raw("__int128"), parity plus boundary runs decide the covered gaps])

#listing("icpc/samples/src/Ch08/PA.cs", first: 42, last: 93, caption: [c\#: integer cross products classify edges, double t sorts events, parity walks build the inside spans])

#listing("icpc/samples-go/ch08/pa.go", first: 41, last: 75, caption: [go: float breakpoints and midpoint containment tests collect candidate runs])

#listing("icpc/samples-js/src/ch08-pa-airport.mjs", first: 128, last: 155, caption: [javascript: the same float walk, survivors re-evaluated later in bigint rationals])

#listing("icpc/samples-py/src/Ch08/pa.py", first: 20, last: 53, caption: [python: exact integer crosses drive toggles, collinear edges add boundary pieces])

#listing("icpc/samples-lua/ch08_pa.lua", first: 8, last: 29, caption: [lua: the solver as a thin driver, every vertex pair handed to the year-local geom helper's best_span])

The C solver carries its classification in #raw("ch08_geom.h") as fractions n over m compared in #raw("__int128"), then deliberately drops to doubles for the final metric, and the comparison cannot ask for more: the official answer values sit beyond double precision in both directions, so the harness verifies problem A in its float mode, #raw("2017/A") pinned to #raw("float") in compare.json, the last numeric token checked within the statement's 1e-6 rather than a nine-decimal byte match. Go and JavaScript walk floats, collect every run within an epsilon of the best, and re-evaluate the survivors exactly, Go in #raw("big.Rat") with a 200-bit square root and JavaScript in BigInt rationals with an integer square root and half-up rounding. C\# keeps the per-edge classification in exact integer cross products while sorting double parameters, Python and Lua run the parity argument on exact integer crosses end to end. The measured fixture is the six-vertex L island
`0 0 / 2 0 / 2 1 / 1 1 / 1 2 / 0 2`, where the diagonal through the reflex vertex has length 2*sqrt(2), and every suite asserts the exact output `2.828427125`: the C #raw("CHECK(strcmp(...))"), the C\# #raw("Assert.Equal"), Go's table row, the JavaScript #raw("assert.equal"), the Python #raw("check"), and the Lua #raw("T.eq"). All six suites also pin the 3 by 4 rectangle answering `5.000000000`, and the C suite adds a skinny triangle answering `1000.000000000`.

#diagram([the l island, the winning diagonal through the reflex vertex, one rejected shorter chord], length: 12pt, {
  cdraw.line((3.0, 0.6), (7.0, 0.6), stroke: luma(60))
  cdraw.line((7.0, 0.6), (7.0, 2.6), stroke: luma(60))
  cdraw.line((7.0, 2.6), (5.0, 2.6), stroke: luma(60))
  cdraw.line((5.0, 2.6), (5.0, 4.6), stroke: luma(60))
  cdraw.line((5.0, 4.6), (3.0, 4.6), stroke: luma(60))
  cdraw.line((3.0, 4.6), (3.0, 0.6), stroke: luma(60))
  cdraw.line((3.0, 4.6), (7.0, 0.6), stroke: luma(20), width: 0.7)
  cdraw.line((3.0, 0.6), (7.0, 2.6), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.circle((5.0, 2.6), radius: 0.14, stroke: luma(20), fill: white)
  cdraw.content((5.0, 3.0), [reflex vertex], size: 6pt, anchor: "south")
  cdraw.content((4.6, 2.2), [winner 2.828427125], size: 6.5pt, anchor: "east")
  cdraw.content((6.4, 1.9), [rejected sqrt(5)], size: 6pt, fill: luma(110), anchor: "west")
  cdraw.content((5.0, 0.1), [optimal strips pass through two vertices, then extend to the boundary], size: 6.5pt, anchor: "north")
})

== problem B, get a clue!

The game is Cluedo: twenty-one cards, six persons A to F, six weapons
G to L, nine rooms M to U. One person, one weapon and one room card
are drawn and hidden as the answer, the remaining eighteen are dealt
round-robin to the four players starting with player 1, us, and
moving to the right, hands of 5, 5, 4 and 4. Play rotates the same
way from player 1, and a turn is a suggestion naming a person, a
weapon and a room. The suggester first asks the player to their right
for evidence, then onward around the table: a responder holding
exactly one suggested card must show it, a responder holding several
may show any one, and the questioning stops at the first evidence or
when everyone has passed. The record marks a pass as a dash, an
evidence card we ourselves see, because we made the suggestion or
provided the card, by its letter, and evidence nobody shows us as a
star. Given our five cards and the full history, the task is to print
the three-character answer string, the forced murderer, weapon and
room letters or a question mark per category that is still open
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is one integer n, 1 <= n <= 50 suggestions by the problemset
pdf, then a line with our five dealt cards as uppercase letters A
through U, then n suggestion lines: three characters, person, weapon
and room in that order, followed by up to three responses in
questioning order starting from the suggester's right neighbor, each
a dash or an evidence character, and only the last response can be
evidence. Only valid histories appear. The output is the three
character string under the pdf's 4 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`B-clue/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: we hold none of A, G or M and all three opponents pass,
so the hidden answer is exactly that triple.

input:

```
1
B I P C F
A G M - - -
```

expected output:

```
AGM
```

Official sample 2, same source: this is the input that pins the
conventions. The first suggestion is ours and player 2 shows us M, so
player 2 holds M. If the second suggestion were also ours, player 2
would have to show M again rather than pass, which contradicts the
record, so suggestions must rotate and the second is player 2's own,
asked of players 3 then 4: player 3 passes on F H M, player 4's
unseen star can only be F, since we hold H and player 2 holds M.
Every person but E is then accounted for, weapon and room are not,
and the pdf prints E??.

input:

```
2
A B C D H
F G M M
F H M - *
```

expected output:

```
E??
```

Recognition: the bounds sit on the enumeration, not on any search
through it. The answer triple is one of 6 x 6 x 9 = 324 candidates,
and once a triple is fixed the thirteen cards we never see split
into opponent hands of 5, 4 and 4, C(13,5) x C(8,4) = 1287 x 70 =
90090 deals to test against the history, about 2.9 x 10^7 raw
worlds across all triples, and clause pruning cuts that far below
the 4 second limit.

The statement's own shape, print the forced letters or a question
mark per category that is still open, is a consistency census: every
question mark must survive because at least one consistent deal
exists, and the rule that a responder holding several suggested
cards may show any one means no local deduction closes a category on
its own. Problem B is the 2017 face of the constraint repair with
backtracking family. Chapter 10 problem C is the other constraint
repair with backtracking member.

The tempting shortcut, a forward rule engine that propagates forced
cards and answers from what it can see, is priced out by that same
freedom: whether a category stays open can hinge on a deal that
exists but no recorded suggestion ever exposes, so the census over
deals is the only decider, and the 90090 deal test per triple is
what fits the budget.

Page 3 of the solutions pdf settles the deduction: enumerate the
consistent worlds. The judges' fast shape computes the candidate hand
sets per opponent that are compatible with the history, guesses the
answer triple, then joins, for a player 2 set Si and a player 3 set
Tj it looks up X xor Si xor Tj among the player 4 sets through
a bitmask dictionary over 21-bit integers, worst case bounded on the
C(13,5) scale and fast enough in plain CPython, while a directly
pruned backtracking over the two unknown hands also fits the 4 second
limit. The six solvers split three ways.

The worked run: trace the model on sample 1. Our hand is the printed
B I P C F, the single suggestion A G M is ours because play starts
at player 1, and the three printed dashes are the answers of players
2, 3 and 4 in questioning order. A dash means the responder holds
none of the three suggested cards, so no opponent holds A, G or M,
and checking them against the printed hand, B, I, P, C and F leave
all three untouched there too. Every card is either dealt into one
of the four hands or hidden as the answer, so all three must be the
hidden answer, person A, weapon G and room M, no category stays
open, and the trace ends at the printed answer `AGM`.

#table(
  columns: (auto, auto, auto, 1.4fr, auto),
  inset: 4pt,
  table.header([*card*], [*category*], [*in our hand*], [*responder*], [*therefore*]),
  [A], [person], [no], [player 2 passes, holds none], [hidden],
  [G], [weapon], [no], [player 3 passes, holds none], [hidden],
  [M], [room], [no], [player 4 passes, holds none], [hidden],
)

#listing("icpc/samples-c/src/Ch08/pB.c", first: 23, last: 48, caption: [c: pruned backtracking over the dealt cards, clause cards ordered first])

#listing("icpc/samples/src/Ch08/PB.cs", first: 141, last: 168, caption: [c\#: star evidence placed by backtracking, then Hall's condition over the three hands])

#listing("icpc/samples-go/ch08/pb.go", first: 119, last: 168, caption: [go: per-player hand enumeration with coverage and suffix-reach pruning])

#listing("icpc/samples-js/src/ch08-pb-clue.mjs", first: 41, last: 73, caption: [javascript: the same pruned deal search, 21-bit masks as plain numbers])

#listing("icpc/samples-py/src/Ch08/pb.py", first: 62, last: 97, caption: [python: the judges' join, player 2 and 3 hands enumerated, the rest looked up in a set])

#listing("icpc/samples-lua/ch08_pb.lua", first: 26, last: 69, caption: [lua: the pruned deal search with bit operators on 64-bit integers])

C backtracks over the thirteen undealt cards with response clauses
checked at the leaves and clause cards ordered first so dead branches die early. C\# enumerates all 324 answer triples and tests each with forced-card placement, star disjunctions placed by recursion, and a Hall condition over the three unknown hands. Go, JavaScript and Lua share one algorithm: for each answer triple, a per-player recursive hand builder prunes on coverage, capacity, and whether the evidence sets can still be reached. Python is the judges' shape verbatim, opponent hands enumerated as 21-bit masks, player 2 crossed with player 3, the remainder looked up in the player 4 dictionary, then three-bit slices tried as the answer. The measured fixture is `2 suggestions, our hand A B D E F`, the first suggestion passing C, G and M around the whole table so all three are the hidden answer, and every suite asserts the exact string `CGM`, with the second case forcing `A??` from a hand holding every person but A. Cards are bits 0 to 20 in every language, machine ints throughout, no bigint anywhere.

#diagram([21 cards into 3 hidden plus hands of 5, 5, 4, 4, one suggestion passing three times then unseen evidence], length: 12pt, {
  let card(x, y, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + 0.62, y + 0.9), fill: fill, radius: 0.02)
    cdraw.content((x + 0.31, y + 0.45), text(size: 5.5pt)[#t])
  }
  cdraw.content((2.0, 7.6), [hidden: C G M], size: 6.5pt, anchor: "west")
  card(2.0, 6.4, [C], fill: luma(210))
  card(2.7, 6.4, [G], fill: luma(210))
  card(3.4, 6.4, [M], fill: luma(210))
  cdraw.content((6.2, 7.6), [dealt 5 / 5 / 4 / 4], size: 6.5pt, anchor: "west")
  card(6.2, 6.4, [A]); card(6.9, 6.4, [B]); card(7.6, 6.4, [D])
  card(8.3, 6.4, [E]); card(9.0, 6.4, [F])
  cdraw.content((7.6, 5.9), [ours, five cards], size: 6pt, anchor: "north")
  cdraw.content((9.8, 6.9), [13 more to players 2-4], size: 6pt, anchor: "west")
  let ys = (4.0, 4.0, 2.6, 1.2)
  let xs = (0.8, 5.4, 10.2, 15.0)
  cdraw.rect((xs.at(0), ys.at(0)), (xs.at(0) + 3.6, ys.at(0) + 1.0), fill: luma(205), radius: 0.02)
  cdraw.content((xs.at(0) + 1.8, ys.at(0) + 0.5), text(size: 6pt)[p1, us, suggests C G M])
  cdraw.rect((xs.at(1), ys.at(1)), (xs.at(1) + 3.6, ys.at(1) + 1.0), fill: luma(235), radius: 0.02)
  cdraw.content((xs.at(1) + 1.8, ys.at(1) + 0.5), text(size: 6pt)[p2, pass: -])
  cdraw.rect((xs.at(2) - 0.6, ys.at(2)), (xs.at(2) + 3.0, ys.at(2) + 1.0), fill: luma(235), radius: 0.02)
  cdraw.content((xs.at(2) + 1.2, ys.at(2) + 0.5), text(size: 6pt)[p3, pass: -])
  cdraw.rect((xs.at(3) - 6.6, ys.at(3)), (xs.at(3) - 3.0, ys.at(3) + 1.0), fill: luma(235), radius: 0.02)
  cdraw.content((xs.at(3) - 4.8, ys.at(3) + 0.5), text(size: 6pt)[p4, pass: -])
  cdraw.line((xs.at(0) + 3.6, ys.at(0) + 0.5), (xs.at(1), ys.at(1) + 0.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((xs.at(1) + 3.6, ys.at(1) + 0.5), (xs.at(2) - 0.6, ys.at(2) + 0.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((xs.at(2) + 3.0, ys.at(2) + 0.5), (xs.at(3) - 3.0, ys.at(3) + 0.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 0.3), [all three pass, so C G M is the answer], size: 6.5pt)
})

== problem C, mission improbable

Crates of identical size stand in piles on an r by c grid inside a
warehouse. Three security cameras photograph the piles hourly: the
front camera records the height of the tallest pile in each column,
the side camera the tallest pile in each row, and the top camera
which piles are nonempty, and any change in any image sounds the
alarm. Patrick can carry crates out and rearrange what remains, but
he can never add a crate or refill an empty pile, so the task is the
largest number of crates that can leave while all three camera images
stay exactly what they were
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers r and c, each 1 to 100 by the problemset
pdf, then r lines of c integers, the pile heights, each 0 to 10^9
inclusive. The output is one integer, the maximum number of crates
that can be stolen without detection, under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`C-improbable/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints with its before and after figures: the grid holds
45 crates on 20 nonempty piles, the camera views pin 23 of them in
seven tall piles plus 13 single-crate leftovers, so exactly 9 can go.

input:

```
5 5
1 4 0 5 2
2 1 2 0 1
0 2 3 4 4
0 3 0 3 1
1 2 2 1 1
```

expected output:

```
9
```

Recognition: the bounds make every stratum cheap. With r and c at
most 100 the grid holds at most 10^4 nonempty cells, each distinct
height runs one matching over at most 100 rows plus 100 columns, and
the strata are disjoint in their edges, a cell can serve only the
stratum of its own height, so all the matchings together touch at
most those 10^4 cells against the 1 second limit.

The statement's shape, remove the most crates while all three camera
images stay exactly what they were, splits by the images themselves:
every row and every column pins its maximum, and one tall pile can
satisfy a row and a column at once, which is a matching question per
height over the nonempty cells. Problem C is the 2017 face of the
bipartite assignment feasibility family. The bipartite assignment
feasibility family collects chapter 11 problem X, chapter 13 problem
B, and chapter 13 problem F.

The tempting shortcut, the max(m, n) tally that keeps one pile per
row or column maximum, is priced out by exactly the matching: on
sample 1 the height-3 stratum has its row and column crossing on an
empty cell, so it needs two piles of 3 where max(1, 1) buys one, the
tally answers 12 against the printed 9, and on a full grid the error
compounds across every unmatched stratum.

Pages 3 and 4 of the solutions pdf give the method. Process the
distinct heights in decreasing order. For height H, let m be the
columns whose maximum is H and n the rows whose maximum is H: a pile
of height H can satisfy one row and one column at once, but only
where it stands on a cell the top camera sees as nonempty, so a
bipartite matching between those rows and columns over the nonempty
cells places m plus n minus the matching size piles of height H.
After every height is processed, each still-empty originally nonempty
cell keeps exactly one crate, so the kept total is the sum of
H times (m + n - match(H)) over all heights plus the leftover singles,
and the answer is the initial total minus that. Each height runs its
own matching on at most 100 plus 100 nodes, well inside the limit.
Book 9's chapter 38, network flows ii, teaches Kuhn's
augmenting-path bipartite matching from scratch. The matching is
what separates this from the naive max(m, n) tally.

The worked run: trace the model on sample 1. The printed grid sums
to 45 crates on 20 nonempty piles, the row maxima read 5, 2, 4, 3
and 2, the column maxima 2, 4, 3, 5 and 4, and the distinct heights
descend through 5, 4, 3 and 2 with height 1 pinning nothing. Height
5: row 1 and column 4 cross at the printed 5 there, a matching of 1,
so 1 + 1 - 1 = 1 pile of 5. Height 4: row 3 against columns 2 and 5,
and the printed 4 at row 3 column 5 serves both, 1 + 2 - 1 = 2 piles
of 4. Height 3: row 4 against column 3, and the cell where they
cross holds 0, no matching, 1 + 1 - 0 = 2 piles of 3 on the printed
3s of row 4 and column 3. Height 2: rows 2 and 5 against column 1,
the printed 2 at row 2 column 1 serves both, 2 + 1 - 1 = 2 piles of
2. Seven tall piles hold 5 + 8 + 6 + 4 = 23 crates, the other 13
nonempty cells keep one crate each, 23 + 13 = 36 stay, 45 - 36 = 9
can leave, and the trace ends at the printed answer `9`.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*height*], [*rows at max*], [*cols at max*], [*match*], [*piles*], [*crates*]),
  [5], [1], [4], [1], [1], [5],
  [4], [3], [2, 5], [1], [2], [8],
  [3], [4], [3], [0], [2], [6],
  [2], [2, 5], [1], [1], [2], [4],
  [1], [none], [none], [0], [0], [0],
)

#listing("icpc/samples-c/src/Ch08/pC.c", first: 57, last: 77, caption: [c: per height, rows and columns matched over nonempty cells, kept crates tallied])

#listing("icpc/samples/src/Ch08/PC.cs", first: 40, last: 67, caption: [c\#: the same loop, augmenting paths over the column list])

#listing("icpc/samples-go/ch08/pc.go", first: 60, last: 89, caption: [go: distinct heights descending, kuhn over adjacency lists, kept tallied])

#listing("icpc/samples-js/src/ch08-pc-improbable.mjs", first: 13, last: 33, caption: [javascript: the kuhn augmenting path inlined, matchR and seen as typed arrays])

#listing("icpc/samples-py/src/Ch08/pc.py", first: 11, last: 30, caption: [python: recursive augment over adjacency lists])

#listing("icpc/samples-lua/ch08_pc.lua", first: 42, last: 67, caption: [lua: heights descending from a set, matching from the ch08_match module])

Every language runs Kuhn augmenting paths on at most 100 plus 100
nodes per height, and the differences are carrier only: C calls its #raw("ch08_match.h") over a dense byte matrix, C\# augments directly on the column list, Go feeds its #raw("ch08_match") adjacency lists, JavaScript inlines the helper with typed arrays, Python recurses through a closure, Lua requires #raw("ch08_match"). The measured fixture is the 2 by 4 grid `100 1 100 0 / 100 1 100 0`, total 402 crates over 6 nonempty cells, where the two rows and two 100-columns match perfectly so 2 piles of 100 stay, one pile of 1, and three single-crate leftovers, 204 kept and `198` stolen, asserted as an exact string in all six suites. Totals reach 10^13, int64 in C, C\#, Go and Lua, and JavaScript stays exact below 2^53, so no bigint is needed anywhere.

#diagram([the 2 by 4 grid, two 100 piles matched to both rows and both 100 columns, filler cells, three views unchanged], length: 12pt, {
  let cell(x, y, t, fill: luma(240)) = {
    cdraw.rect((x, y), (x + 1.7, y + 1.2), fill: fill, radius: 0.02)
    cdraw.content((x + 0.85, y + 0.6), text(size: 6.5pt)[#t])
  }
  cell(1.0, 4.2, [100], fill: luma(215))
  cell(2.9, 4.2, [1])
  cell(4.8, 4.2, [100], fill: luma(215))
  cell(6.7, 4.2, [0], fill: luma(250))
  cell(1.0, 2.6, [100], fill: luma(215))
  cell(2.9, 2.6, [1])
  cell(4.8, 2.6, [100], fill: luma(215))
  cell(6.7, 2.6, [0], fill: luma(250))
  cdraw.circle((1.85, 4.8), radius: 0.55, stroke: luma(20))
  cdraw.circle((5.65, 4.8), radius: 0.55, stroke: luma(20))
  cdraw.line((1.85, 4.8), (5.65, 4.8), stroke: (paint: luma(20), dash: "dashed"))
  cdraw.content((3.75, 5.7), [matching of size 2], size: 6.5pt)
  cdraw.content((3.75, 1.9), [row maxima 100 100, column maxima 100 1 100 0, six nonempty cells], size: 6.5pt)
  cdraw.content((3.75, 1.1), [kept 200 + 1 + 3, stolen 198], size: 6.5pt, fill: luma(100))
  cdraw.content((3.75, 0.4), [a pile covers one row and one column at once only where the top view is nonempty], size: 6pt)
})

== problem D, money for nothing

We are a middleman in the widget market and may sign with exactly one
producer company and one consumer company. Each producer has a price
per widget and a day its first widget is available, each consumer has
a price it pays and the day immediately after its last required
delivery, and a signed pair means one widget per day bought at the
producer's price and sold at the consumer's, from the producer's
first day through the day before the consumer's end. The profit is
(q - p) times (e - d) where that is positive, and the task is the
maximum over all pairs, 0 if no pair pays
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers m and n, 1 to 500000 each by the problemset
pdf, then m producer lines of two integers pi and di, then n consumer
lines of qj and ej, all four values 1 to 10^9. The output is one
integer, the maximum profit or 0, under the pdf's 5 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`D-money/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: the producer at price 2 from day 1 against the consumer
at price 7 ending after day 2 earns (7 - 2) times (2 - 1) = 5, the
best contract on the table.

input:

```
2 2
1 3
2 1
3 5
7 2
```

expected output:

```
5
```

Recognition: the bounds kill the pairwise scan outright. With m and
n each up to 500000, all m x n = 2.5 x 10^11 producer-consumer
pairs is far past any budget, while sorting both sides, pruning
dominated corners to staircases and dividing the argmax search costs
O((m + n) log n), about 10^6 corners through 20 levels, or 2 x 10^7
touches, trivial inside the 5 second limit.

The statement's shape, one producer and one consumer quantity
multiplied together, is a rectangle in disguise: plotting a producer
at (d, p) and a consumer at (e, q), the profit (q - p)(e - d) is
exactly the axis-aligned rectangle between the two corners, and the
maximum is attained at finitely many staircase corners. Problem D is
the 2017 face of the geometric critical-point enumeration family.
Geometric critical-point enumeration is the shared shape of chapter
08 problem A, chapter 09 problem E, chapter 09 problem G, chapter 11
problem T, and chapter 12 problem D.

The tempting shortcut, a ternary search over each producer's stretch
of the consumer staircase, is priced out by shape: along the
staircase the span e - d grows while the margin q - p shrinks, and
their product is not unimodal, spans 1, 2, 3, 10 against margins 5,
2.4, 2, 1.9 give 5, 4.8, 6 and 19, a dip at the second step before
the peak, so a ternary search can settle on the wrong hill.

Pages 4 and 5 of the solutions pdf recast the search as geometry.
Plot each producer as the lower-left corner (d, p) and each consumer
as the upper-right corner (e, q): the profit of a pair is exactly the
axis-aligned rectangle between the two corners, so the task is the
largest such rectangle. Corners dominated in both coordinates by
another corner of their own kind can never win, which prunes both
sides to staircases, and then a divide and conquer finds every
producer's best consumer: for the middle producer scan the consumers
linearly, and because the optimal consumer index is monotone across
the recursion, each level touches each consumer once, O((m + n) log n)
in total. Book 9's chapter 32, dynamic programming ii, develops the
divide-and-conquer over a monotone argmax that this sweep is the
bare-bones shape of. An alternative half-plane sweep with the same
bound exists.
The six solvers agree on the recursion and split on the objective the
argmax tracks.

The worked run: trace the model on sample 1. The two printed
producers plot at (3, 1) and (1, 2), the two consumers at (5, 3) and
(2, 7), and neither side holds a dominated corner, so both
staircases keep everything. Producer (3, 1) scans its valid
consumers, those with e past 3 and q past 1: (5, 3) pays (3 - 1) x
(5 - 3) = 4, and (2, 7) is invalid because e = 2 never reaches
d = 3. Producer (1, 2) scans both: (5, 3) pays (3 - 2) x (5 - 1) =
4, and (2, 7) pays (7 - 2) x (2 - 1) = 5, the winner. The recursion
splits the two producers one per half, each half scanning the
staircase once, and the trace ends at the printed answer `5`.

#diagram([sample 1's four corners, the winning rectangle from producer (1,2) to consumer (2,7), the invalid pair marked], length: 12pt, {
  cdraw.line((1.2, 1.0), (13.4, 1.0), stroke: luma(120), mark: (end: ">"))
  cdraw.line((1.2, 1.0), (1.2, 7.6), stroke: luma(120), mark: (end: ">"))
  cdraw.content((13.6, 1.0), [d / e], size: 6pt, anchor: "west")
  cdraw.content((1.2, 7.8), [p / q], size: 6pt, anchor: "south")
  cdraw.rect((2.7, 2.5), (4.4, 6.75), fill: luma(230), radius: 0.02)
  cdraw.content((3.55, 4.6), [5], size: 7pt)
  cdraw.circle((2.7, 2.5), radius: 0.16, fill: luma(20))
  cdraw.content((2.7, 2.0), [(1,2)], size: 6pt, anchor: "north")
  cdraw.circle((4.4, 6.75), radius: 0.16, fill: luma(20))
  cdraw.content((4.7, 7.0), [(2,7)], size: 6pt, anchor: "west")
  cdraw.rect((6.1, 1.65), (9.5, 3.35), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((7.8, 2.5), [4], size: 6.5pt)
  cdraw.circle((6.1, 1.65), radius: 0.16, fill: luma(20))
  cdraw.content((6.1, 1.15), [(3,1)], size: 6pt, anchor: "north")
  cdraw.circle((9.5, 3.35), radius: 0.16, fill: luma(20))
  cdraw.content((9.8, 3.6), [(5,3)], size: 6pt, anchor: "west")
  cdraw.line((6.1, 1.65), (4.4, 6.75), stroke: (paint: luma(150), dash: "dotted"))
  cdraw.content((5.9, 3.6), [e < d, 0], size: 6pt, anchor: "east", fill: luma(110))
  cdraw.content((4.6, 5.2), [legs 1 and 5], size: 6pt, anchor: "east")
  cdraw.content((7.4, 0.4), [four pairs, two pay 4, one is invalid, the winner pays 5], size: 6.5pt)
})

#listing("icpc/samples-c/src/Ch08/pD.c", first: 22, last: 50, caption: [c: the argmax tracks the raw signed product, ties break right, clamping is deferred to the end])

#listing("icpc/samples/src/Ch08/PD.cs", first: 43, last: 78, caption: [c\#: divide and conquer with binary-searched valid consumer windows per producer])

#listing("icpc/samples-go/ch08/pd.go", first: 34, last: 59, caption: [go: one closure, the argmax on the raw product, positive-margin pairs feed the answer])

#listing("icpc/samples-js/src/ch08-pd-money.mjs", first: 39, last: 60, caption: [javascript: the same search with every product in bigint])

#listing("icpc/samples-py/src/Ch08/pd.py", first: 41, last: 62, caption: [python: an explicit stack replaces the recursion])

#listing("icpc/samples-lua/ch08_pd.lua", first: 64, last: 86, caption: [lua: 64-bit integers, raw product argmax, max with zero at the end])

Clamping at zero inside the recursion would break the monotonicity
the divide and conquer feeds on, so all six track the raw signed product for the index and only let positive-margin pairs update the answer, with C and C\# holding the invariant through a negative-infinity sentinel and window bounds. The measured fixture is three producers, two consumers, `4 1 / 2 3 / 5 2` against `6 2 / 3 6`, where the producer (5, 2) is dominated, and the rectangle between (3, 2) and (6, 3) wins with area `3`, asserted exactly in all six suites, alongside the no-profit pair answering `0`. This is the chapter's hard integer boundary: (q - p)(e - d) reaches 10^18, past 2^53, so C, C\#, Go and Lua multiply in int64 or Lua's 64-bit integers while JavaScript converts both factors to BigInt for every product, never a JavaScript number.

#diagram([two staircases, the winning rectangle between producer (3,2) and consumer (6,3), the dominated producer crossed out], length: 12pt, {
  cdraw.line((1.2, 1.0), (13.4, 1.0), stroke: luma(120), mark: (end: ">"))
  cdraw.line((1.2, 1.0), (1.2, 7.4), stroke: luma(120), mark: (end: ">"))
  cdraw.content((13.6, 1.0), [d / e], size: 6pt, anchor: "west")
  cdraw.content((1.2, 7.6), [p / q], size: 6pt, anchor: "south")
  cdraw.rect((4.2, 2.8), (9.4, 5.0), fill: luma(230), radius: 0.02)
  cdraw.content((6.8, 3.9), [profit 3], size: 7pt)
  cdraw.circle((4.2, 2.8), radius: 0.16, fill: luma(20))
  cdraw.content((4.2, 2.3), [(3,2)], size: 6pt, anchor: "north")
  cdraw.circle((9.4, 5.0), radius: 0.16, fill: luma(20))
  cdraw.content((9.9, 5.3), [(6,3)], size: 6pt, anchor: "west")
  cdraw.circle((6.8, 2.0), radius: 0.16, fill: luma(20))
  cdraw.content((6.8, 1.5), [(5,2)], size: 6pt, anchor: "north")
  cdraw.line((6.4, 2.4), (7.2, 1.6), stroke: luma(20))
  cdraw.line((6.4, 1.6), (7.2, 2.4), stroke: luma(20))
  cdraw.circle((3.0, 4.2), radius: 0.16, fill: luma(120))
  cdraw.content((3.0, 4.6), [(1,4)], size: 6pt, anchor: "south")
  cdraw.circle((11.6, 6.4), radius: 0.16, fill: luma(120))
  cdraw.content((11.6, 6.8), [(2,6)], size: 6pt, anchor: "south")
  cdraw.content((7.3, 0.4), [staircases prune dominated corners, the optimum index is monotone in the producer], size: 6.5pt)
})

== problem E, need for speed

Sheila's student car lost its speedometer needle and she glued it
back at a possibly wrong angle, so when the speedometer reads s the
true speed is s + c for an unknown constant c that may be negative.
She recorded a journey of n segments, distance and reading per
segment, the whole journey took time t, and her true speed was
positive on every segment. Distances are in miles, time in hours,
speeds in miles per hour, and the task is to recover c
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers n and t by the problemset pdf, n from 1 to
1000 the number of segments and t from 1 to 10^6 the total time, then
n lines of two integers each, the distance with 1 <= d <= 1000 and
the reading with |s| <= 1000. The output is c in miles per hour
within an absolute or relative error of 10^-6, under the pdf's 1
second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`E-speed/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: 4 over c minus 1, plus 4 over c, plus 10 over c plus 3
sums to exactly 5 at c = 3.

input:

```
3 5
4 -1
4 0
10 3
```

expected output:

```
3.000000000
```

Recognition: the bounds invite the cheapest possible search. The
unknown c is one real number, a probe costs n = 1000 fraction
additions, and two hundred bisection iterations cost 2 x 10^5
divisions, nothing against the 1 second limit, while the bracket is
honest: strictly above minus the smallest reading, where the slowest
true speed reaches zero, up to 10^6 + 1000.

The statement's shape hands over the monotonicity: every segment
contributes its distance over its true speed, d over s + c, and
every such term strictly decreases as c grows across the valid
range, so the whole journey took time t pins one crossing of one
falling curve. Problem E is the 2017 face of the one-dimensional
answer-space search family. The one-dimensional answer-space search
family also collects chapter 09 problem F and chapter 13 problem C.

The tempting shortcut, solving the equation in closed form, is
priced out by degree: the sum clears to a degree-n polynomial,
cubic already at n = 3 and degree 1000 here, and a Newton walk needs
derivatives and can jump across the pole at c = -min s, while two
hundred monotone probes bracket the root to 10^-9 by construction.

Page 5 of the solutions pdf is the whole story: the time sum, each
segment's distance over its true speed, is strictly decreasing in c
across the valid range, so bisect the sum against t. The bounds
matter more than the loop: the low bound is minus the smallest
reading, exclusive, where a speed hits zero, and the high bound is
10^6 + 1000 rather than 10^6, because a journey of a thousand
1000-mile segments inside one hour forces true speeds up to a million
against readings as low as minus a thousand. The pdf prescribes one
hundred iterations of a linear evaluation, doubled to two hundred in
every landed suite. The set's easiest problem is the chapter's
control group, six languages, one identical algorithm.

The worked run: trace the model on sample 1. The readings are -1, 0
and 3, so the pole sits at c = 1 and the bracket opens just above 1,
where the first term 4 over c - 1 blows past t = 5, and closes at
10^6 + 1000, where the sum is near zero. Probe 1 at (1 + 1001000) /
2 = 500500.5 sums about 18 / 500500 = 3.6 x 10^-5, below 5, so the
high half dies. Probe 2 at (1 + 500500.5) / 2 = 250250.75 sums
about 18 / 250250 = 7.2 x 10^-5, again below, and the bracket keeps
halving, 999999 / 2^k wide after k probes, under 10^-9 by probe 50.
The root itself is exact: 4 / (3 - 1) + 4 / 3 + 10 / (3 + 3) = 2 +
4/3 + 5/3 = 2 + 3 = 5 = t, so the falling sum crosses t precisely
at c = 3, and the trace ends at the printed answer `3.000000000`.

#table(
  columns: (auto, 1.3fr, 1.3fr, auto, auto),
  inset: 4pt,
  table.header([*probe*], [*mid*], [*sum, about*], [*against t = 5*], [*bracket top*]),
  [open], [1 to 1001000], [past 5 down to 0], [crosses once], [1001000],
  [1], [500500.5], [18 / 500500 = 3.6 x 10^-5], [below], [500500.5],
  [2], [250250.75], [18 / 250250 = 7.2 x 10^-5], [below], [250250.75],
  [50], [halved 50 times], [999999 / 2^50 = 8.9 x 10^-10 wide], [below], [1 + 9 x 10^-10],
  [root], [3], [2 + 4/3 + 5/3 = 5], [equals t], [c = 3],
)

#listing("icpc/samples-c/src/Ch08/pE.c", first: 24, last: 46, caption: [c: bisect with a nonpositive-speed guard pushing the low bound up])

#listing("icpc/samples/src/Ch08/PE.cs", first: 20, last: 33, caption: [c\#: the same loop, low starts one epsilon above minus the smallest reading])

#listing("icpc/samples-go/ch08/pe.go", first: 26, last: 45, caption: [go: the time sum as a closure, the high-bound comment naming 1e6+1000])

#listing("icpc/samples-js/src/ch08-pe-speed.mjs", first: 14, last: 26, caption: [javascript: total as an arrow function, toFixed(9) for the output])

#listing("icpc/samples-py/src/Ch08/pe.py", first: 15, last: 25, caption: [python: the bisection in eleven lines])

#listing("icpc/samples-lua/ch08_pe.lua", first: 31, last: 46, caption: [lua: the time sum closure and the %.9f format])

The measured fixture is two segments, `4 -1` and `8 1` with t equal
to 4, where 4 over c minus 1 plus 8 over c plus 1 equals 4 exactly at c = 3, and every suite asserts `3.000000000` as an exact string, alongside the single fast segment forcing the negative answer `-1.000000000`. Everything runs in doubles, and the only divergence is the guard at the pole, C checks for a nonpositive speed mid-loop, C\# lifts the low bound by 1e-9, the others bisect between the strict bounds and let the sum blow up past t. Output formatting differs per language, `%.9f`, `F9`, `toFixed(9)`, all landing on the same nine decimals.

#diagram([the c axis, the strictly decreasing time sum against the horizontal t, the bracket closing on 3], length: 12pt, {
  cdraw.line((1.2, 1.0), (14.6, 1.0), stroke: luma(120), mark: (end: ">"))
  cdraw.content((14.8, 1.0), [c], size: 6.5pt, anchor: "west")
  cdraw.line((1.2, 1.0), (1.2, 7.2), stroke: luma(120), mark: (end: ">"))
  cdraw.content((1.2, 7.4), [sum d/(s+c)], size: 6.5pt, anchor: "south")
  cdraw.line((1.2, 4.4), (14.2, 4.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.2, 4.7), [t], size: 6.5pt, anchor: "south")
  cdraw.line((2.2, 7.0), (4.0, 6.2), stroke: luma(30))
  cdraw.line((4.0, 6.2), (8.0, 4.9), stroke: luma(30))
  cdraw.line((8.0, 4.9), (12.6, 3.4), stroke: luma(30))
  cdraw.line((12.6, 3.4), (14.2, 3.0), stroke: luma(30))
  cdraw.line((8.6, 1.0), (8.6, 4.4), stroke: luma(20))
  cdraw.circle((8.6, 4.4), radius: 0.14, fill: luma(20))
  cdraw.content((8.6, 0.6), [c = 3], size: 6.5pt, anchor: "north")
  cdraw.content((2.4, 1.4), [low = -min s], size: 6pt, anchor: "south")
  cdraw.content((13.6, 1.4), [high = 1e6+1000], size: 6pt, anchor: "south")
  cdraw.content((8.0, 6.8), [strictly decreasing, so the root is unique], size: 6pt, fill: luma(110))
})

== problem F, posterize

Posterizing a picture replaces each color channel by at most k chosen
integer levels, and this problem tracks only the red channel, values
0 to 255. Each pixel's red intensity maps to the nearest allowed
level, and the editing tool picks the k levels that minimize the sum
of squared errors across all pixels. The picture arrives compressed
as d distinct red values with their pixel counts, and the task is
that minimum sum (#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers d and k by the problemset pdf, d from 1 to
256 the number of distinct red values and k from 1 to d the number of
levels allowed, then d lines of two integers each, the red value r
from 0 to 255 and the pixel count p from 1 to 2^26, the lines in
increasing order of r. The output is one integer, the minimum
achievable sum of squared errors, under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`F-posterize/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: one level for 20000 pixels at 50 and 10000 at
150 sits at the weighted mean 83.33, and the level 83 costs 20000
times 33 squared plus 10000 times 67 squared, exactly 66670000.

input:

```
2 1
50 20000
150 10000
```

expected output:

```
66670000
```

Recognition: the bounds are the whole dynamic program case. Distinct
values d at most 256 and levels k at most d make the transition
table O(d^2 k) = 256^2 x 256, about 1.7 x 10^7 cells against the 2
second limit, with the d^2 one-color costs precomputed in one pass
each.

The statement's shape, pick k levels so each pixel maps to its
nearest one for the least squared error, is clustering on a line:
the values arrive sorted, an optimal level set never needs two
levels sharing a boundary with no value between them, so the
clusters are contiguous runs and the last chosen breakpoint drives
each transition. Problem F is the 2017 face of the chain dp over
sorted positions family. Chapter 10 problem B carries the same chain
dp over sorted positions shape.

The tempting shortcut, generic k-means with Lloyd iterations, is
priced out twice: it promises no global optimum, and with pixel
counts to 2^26 every recentering pass multiplies through huge
weights, while the exact level-set enumeration faces C(256,128),
about 10^76 choices, and the dp is both exact and 1.7 x 10^7 cells.

Pages 5 and 6 of the solutions pdf give the dynamic program over the
sorted values. Optimal clusters are contiguous runs on the sorted
list, so C(i, j), the best cost of covering the first i values with j
levels, is the minimum over i' < i of C(i', j-1) + F(i'+1, i), where
F(a, b) is the one-color cost of the run r_a through r_b. That cost
is a quadratic in the chosen level, minimized at the run's
pixel-weighted mean rounded to the nearest integer, and all d squared
F values precompute in one pass, leaving the dp itself O(d^2 k). The
six solvers differ on how the one-color cost is evaluated.

The worked run: trace the model on sample 1. The printed values
carry weights 20000 at 50 and 10000 at 150, and k = 1 forces the
whole sorted list into one cluster, C(2, 1) = F(1, 2). The one-color
moments are sum p = 20000 + 10000 = 30000 and sum p x r = 20000 x 50
+ 10000 x 150 = 2500000, so the weighted mean sits at 2500000 /
30000 = 83.33 and the level rounds to 83. The cost at 83 is 20000 x
33^2 + 10000 x 67^2 = 21780000 + 44890000 = 66670000, the neighbor
84 costs 20000 x 34^2 + 10000 x 66^2 = 66680000, one more, so 83
stands and the trace ends at the printed answer `66670000`.

#table(
  columns: (auto, 1.4fr, auto, auto),
  inset: 4pt,
  table.header([*step*], [*quantity*], [*value*], [*source*]),
  [1], [sum p], [30000], [printed counts],
  [2], [sum p x r], [2500000], [20000 x 50 + 10000 x 150],
  [3], [mean, level], [83.33, 83], [2500000 / 30000, rounded],
  [4], [cost at 83], [66670000], [20000 x 1089 + 10000 x 4489],
  [5], [cost at 84], [66680000], [neighbor test, rejected],
  [6], [C(2, 1)], [66670000], [one cluster, k = 1],
)

#listing("icpc/samples-c/src/Ch08/pF.c", first: 22, last: 61, caption: [c: F(a,b) at the clamped weighted mean, both neighbors tested, then the dp])

#listing("icpc/samples/src/Ch08/PF.cs", first: 18, last: 45, caption: [c\#: floor and ceil of the mean, explicit cost loops, dp over at most k levels])

#listing("icpc/samples-go/ch08/pf.go", first: 29, last: 66, caption: [go: three running moments give F in closed form, rolling dp arrays])

#listing("icpc/samples-js/src/ch08-pf-posterize.mjs", first: 20, last: 51, caption: [javascript: the same closed form, exact in doubles under 2^53])

#listing("icpc/samples-py/src/Ch08/pf.py", first: 20, last: 46, caption: [python: the cost rows as lists, the dp as a min comprehension])

#listing("icpc/samples-lua/ch08_pf.lua", first: 18, last: 48, caption: [lua: closed-form moments, integer division and rounding by hand])

Go, JavaScript, Python and Lua accumulate the three moments sum p,
sum p times r, sum p times r squared and evaluate the cost as
x squared times sum p minus two x times the weighted sum plus the raw moment sum, in one pass per starting index. C and C\# instead evaluate the cost explicitly at the rounded weighted mean, C testing x and both neighbors clamped into the run's value range, C\# testing the floor and the ceiling. The measured fixture is three values with counts `0 2 / 10 3 / 11 2` and k equal to 2, where the split at 0 and a shared level for 10 and 11 costs 2 and every suite asserts the exact integer `2`, alongside k equal to d answering `0`. The integer boundary is real but one-sided: d at most 256 values at p at most 2^26 each parks up to 2^34 pixels in one cluster, and their error around the cluster's weighted mean averages at most 255^2 over 4 per pixel, so the worst cluster costs about 2.8 times 10^14, int64 territory in C, C\#, Go and Lua, and every intermediate in the closed form stays below 2^53, so JavaScript's doubles are exact and no bigint appears.

#diagram([the intensity line, three pixel masses, allowed values at 0 and 10, the error bar from 11], length: 12pt, {
  cdraw.line((1.4, 2.2), (16.6, 2.2), stroke: luma(120), mark: (end: ">"))
  cdraw.content((16.8, 2.2), [red value], size: 6pt, anchor: "west")
  cdraw.rect((1.4, 2.2), (2.4, 4.2), fill: luma(215), radius: 0.02)
  cdraw.content((1.9, 4.6), [2 px at 0], size: 6pt, anchor: "south")
  cdraw.rect((9.0, 2.2), (11.4, 5.2), fill: luma(215), radius: 0.02)
  cdraw.content((10.2, 5.6), [3 px at 10], size: 6pt, anchor: "south")
  cdraw.rect((11.8, 2.2), (13.4, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((12.6, 4.6), [2 px at 11], size: 6pt, anchor: "south")
  cdraw.circle((1.9, 2.2), radius: 0.18, fill: luma(20))
  cdraw.content((1.9, 1.5), [level 0], size: 6pt, anchor: "north")
  cdraw.circle((10.2, 2.2), radius: 0.18, fill: luma(20))
  cdraw.content((10.2, 1.5), [level 10], size: 6pt, anchor: "north")
  cdraw.line((12.6, 2.0), (10.4, 1.7), stroke: luma(20), mark: (end: ">"))
  cdraw.content((11.6, 1.1), [error 2, both 11 pixels map to 10], size: 6.5pt, anchor: "north")
  cdraw.content((8.2, 0.3), [k = 2 levels, clusters are contiguous on the sorted values], size: 6.5pt)
})

== problem G, replicate replicate rfplicbte

A cellular lattice of two-state cells replicates parts: at each
discrete step every cell updates simultaneously, becoming filled
exactly when an odd number of the nine cells of its 3 by 3
neighborhood, itself included, are filled. A bug crept in: after each
step at most one cell in the lattice may spontaneously flip its
state. The original patterns are lost and only a possibly corrupted
final pattern remains, and the task is a smallest possible nonempty
initial pattern, by bounding-box area, that could have produced it,
printed with '.' for empty and '\#' for filled in the fewest rows and
columns that display it. If several minima exist any one is accepted,
though the answer is in fact unique
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers w and h, each 1 to 300 by the problemset
pdf, the width and height of the final pattern's bounding box, then h
lines of w characters, '.' or '\#', with at least one filled cell on
every side of the box. The output is the minimum-size pattern in its
tight bounding box, under the pdf's 3 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`G-replicate/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints in its corrupted-replication figure: the ten by
ten board, a flipped cell in two of its four steps, walks back to a
two by two seed.

input:

```
10 10
.#...#...#
##..##..##
##.#.##...
##.#.##...
.#...#####
...##..#.#
......###.
##.#.##...
#..#..#..#
##..##..##
```

expected output:

```
.#
##
```

Recognition: the bounds price the backward walk directly. The box is
at most 300 by 300, every forward step grows it by at least one cell
per side, so at most min((w+1)/2, (h+1)/2) = 150 backward steps
exist and each is a linear sweep with at most one repair, the
chapter's O((w+h)^3) worst case about 2 x 10^8 byte xors against the
3 second limit.

The statement's shape is the inversion itself: the forward rule,
filled exactly when an odd number of the nine neighborhood cells are
filled, is fully known and deterministic, and a smallest initial
pattern asks which earlier states could have produced the final one,
so the run walks the rule backwards and repairs the at most one
flipped cell each step leaves. Problem G is the 2017 face of the
inverting a deterministic process family. Chapter 13 problem A is
the other half of the inverting a deterministic process pair.

The tempting shortcut, searching forward from candidate seeds, is
priced out by the space: patterns inside a 300 by 300 box run
2^90000 deep before the per-step flips, unenumerable at any limit,
while the backward recurrence hands out every earlier cell in one
xor of already-known neighbors.

Page 6 of the solutions pdf runs the rule backwards. Each step grows
the bounding box by at least one cell in each dimension, so at most
min((w+1)/2, (h+1)/2) backward steps exist, and each step inverts the
rule cell by cell: sweeping row-major, X(r,c) equals the stored
Y(r-1,c-1) up-left of it xor the eight X cells around that up-left
position, all of them already reconstructed. A flipped cell poisons exactly two
cells of this reconstruction and then self-heals on the third, so the
two cells just past each row's end verify every row, and on failure a
second column-major sweep pinpoints the flipped cell by where the two
sweeps disagree, undo it, and redo the step. The sweep stops at a
single filled cell, worst case O((n+m)^3), and the answer is unique,
so byte comparison verifies.

The worked run: trace the model on sample 1. The reconstruction
sweeps the printed ten by ten box padded by one ring on every side,
solving X(r, c) = Y(r - 1, c - 1) xor the eight already-rebuilt
neighbors of that up-left cell, and the two cells past every row end
and column end must come out empty. The first pass is clean, all
sentinels zero, and the ten by ten collapses to an eight by eight.
The second step fails its row sentinels first at row 4 and its
column sentinels at column 6, so the crossed sweeps pin the bug's
flip at Y(4, 6), a cell the bug filled that the clean pattern
leaves empty: undo it, redo, and the eight by eight walks back to a
six by six. The third pass is clean again, six by six to four by
four. The fourth fails both checks at row 2, column 0, a cell the
bug emptied that the clean pattern fills, and undoing it lands on
the two by two `.#` over `##`. The fifth step still fails, its one
localized repair tried and discarded, so the two by two has no
consistent pre-image and is itself the minimum, and
the trace ends at the printed answer `##`, the second of its two lines.

#diagram([sample 1 walked backwards, clean and repaired steps alternating, the 2x2 seed certified by the failed fifth], length: 12pt, {
  let sq(x, w, lab) = {
    cdraw.rect((x, 4.2 - w), (x + w, 4.2), fill: luma(240), stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, 4.2 - w - 0.45), text(size: 6pt)[#lab], anchor: "north")
  }
  sq(0.8, 3.0, [10 x 10])
  sq(5.2, 2.4, [8 x 8])
  sq(9.2, 1.8, [6 x 6])
  sq(12.6, 1.2, [4 x 4])
  sq(15.4, 0.6, [2 x 2])
  let arr(x0, x1, lab) = {
    cdraw.line((x0, 2.6), (x1, 2.6), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x0 + (x1 - x0) / 2, 2.95), lab, size: 6pt, anchor: "south")
  }
  arr(3.9, 5.1, [clean])
  arr(7.7, 9.1, [undo (4,6)])
  arr(11.1, 12.5, [clean])
  arr(13.9, 15.3, [undo (2,0)])
  cdraw.line((16.2, 2.6), (17.4, 2.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((17.5, 2.6), [no pre-image, minimal], size: 6pt, anchor: "west", fill: luma(110))
  cdraw.content((0.8, 0.2), [a flip poisons two rebuilt cells, self-heals on the third, the sentinels catch it], size: 6.5pt, anchor: "south-west")
})

#listing("icpc/samples-c/src/Ch08/pG.c", first: 20, last: 56, caption: [c: reconstruct over the padded frame, the two sentinel cells past every row and column end])

#listing("icpc/samples/src/Ch08/PG.cs", first: 88, last: 115, caption: [c\#: the row sweep enforcing every box equation, the first bad row reported])

#listing("icpc/samples-go/ch08/pg.go", first: 185, last: 227, caption: [go: one backward step, the flip localized by the crossed sweeps and retried])

#listing("icpc/samples-js/src/ch08-pg-replicate.mjs", first: 100, last: 125, caption: [javascript: the same repair, typed-array rows])

#listing("icpc/samples-py/src/Ch08/pg.py", first: 15, last: 53, caption: [python: rows as ints, groups of three bits prefix-xored through a 32768-entry transition table])

#listing("icpc/samples-lua/ch08_pg.lua", first: 54, last: 95, caption: [lua: row and column sweeps over flat 1-based grids, zero outside])

Five of the six walk cells in nested loops, C over one padded frame
with the sentinels folded into the same grid, C\# over the full
shrunk rectangle, Go, JavaScript and Lua over sentinel columns per row. Python is the outlier: each row is one arbitrary-precision integer, the three-cell recurrence becomes a prefix-xor over bit groups, and a precomputed table advances four groups at a time, the same transition-table trick the Python judge solutions favored. The measured fixture is the solid 3 by 3 block, one clean backward step collapses it to the single center cell, and every suite asserts the one-character output `#`, alongside the already-minimal 1 by 1 block. Cells are bytes or bits everywhere, no integer concerns.

#diagram([the 3x3 block with the xor stencil centered on (1,1) collapsing to one cell, the arrow pointing backwards], length: 12pt, {
  let cell(x, y, fill: luma(205)) = cdraw.rect((x, y), (x + 1.3, y + 1.3), fill: fill, radius: 0.02)
  cell(1.6, 4.6); cell(3.1, 4.6); cell(4.6, 4.6)
  cell(1.6, 3.1); cell(3.1, 3.1); cell(4.6, 3.1)
  cell(1.6, 1.6); cell(3.1, 1.6); cell(4.6, 1.6)
  cdraw.rect((2.85, 2.85), (5.75, 5.75), stroke: luma(20))
  cdraw.content((3.75, 6.1), [the 3x3 window], size: 6pt, anchor: "south")
  cdraw.line((6.4, 3.75), (9.4, 3.75), stroke: luma(20), mark: (end: ">"))
  cdraw.content((7.9, 4.1), [backward step], size: 6.5pt, anchor: "south")
  cell(10.0, 3.1)
  cdraw.content((10.65, 2.5), [one cell], size: 6.5pt, anchor: "north")
  cdraw.content((6.0, 1.4), [X(r,c) = Y(r-1,c-1) xor the eight earlier neighbors], size: 6.5pt, anchor: "west")
  cdraw.content((6.0, 0.6), [a flipped cell poisons two, then self-heals on the third], size: 6pt, anchor: "west", fill: luma(110))
})

== problem H, scenery

A day in Rapid City, one camera, n photographs of Badlands features.
Feature i has an earliest start time a and a completion deadline b,
and each shot occupies the photographer for t consecutive time units
that must fall entirely inside its window, one shot at a time. The
task is to decide whether every photo fits in the day, yes or no in
lowercase (#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]). Zero teams solved it in contest.

The input is two integers n and t by the problemset pdf, n from 1 to
10^4 the number of photographs and t from 1 to 10^5 the time each one
takes, then n lines of two nonnegative integers a and b with
a + t <= b <= 10^9, the earliest start and the completion deadline of
each shot. The output is the single word yes or no under the pdf's 6
second limit.

Official sample 2, reprinted byte for byte from the judge data pair
`H-scenery/sample-2.in` and `sample-2.ans`, the judge data's only
infeasible sample: the [1,15] photo's shot spans [s, s+10] for some s
from 1 to 5, which cuts the day into end pieces of at most 5 and 9
time units, never the 10 consecutive units the [0,20] photo still
needs, so no.

input:

```
2 10
1 15
0 20
```

expected output:

```
no
```

Recognition: the bounds pin the method to bookkeeping over photos,
never over time. Deadlines reach 10^9, so anything that walks clock
ticks is dead on arrival, while n = 10^4 photos make the
forbidden-region phase O(n^2) = 10^8 integer comparisons and the
greedy pass O(n log n), together comfortable inside the 6 second
limit.

The statement's shape, does every photo fit when each shot takes the
same t units somewhere inside its own window, is interval scheduling
with equal lengths, and the certified answer runs an earliest
deadline pass that avoids regions proven to starve a subproblem, an
exchange argument behind every placement. Problem H is the 2017 face
of the greedy with a safety proof family. Greedy with a safety proof
is the family of chapter 09 problem K, chapter 10 problem A, and
chapter 12 problem H.

The tempting shortcut, the plain greedy that shoots at time zero
whenever the clock allows, is priced out by the chapter's own
fixture, windows 0 8, 1 3 and 4 6 with t = 2, where opening at [0,2]
strands [1,3], and the 10^9-wide deadline axis prices out every
per-tick dynamic program in the same breath.

Pages 7 and 8 of the solutions pdf, adapted from Garey, Johnson,
Simons and Tarjan 1981, give two phases. Phase one computes forbidden
regions: for each interval [s, e] with s a photo's start time and e
any photo's end time, processed with s latest-first, take the photos
whose windows sit inside [s, e], schedule them as late as possible
while respecting the regions already found, and let C be the first
shot's start time. If C falls below s the day is infeasible, and if C
sits within t of s then starting a shot in [C - t, s) starves this
subproblem, so that span is marked forbidden for starts, collapsed
per s. Incremental bookkeeping makes the phase O(n^2). Phase two runs
a forward earliest-deadline greedy that never starts a shot inside a
forbidden region, and the solutions prove that a greedy failure
always exhibits a phase-one failure, so a greedy success is final.
Book 9's chapter 40, game theory and scheduling, collects the
Garey-Johnson-Simons-Tarjan window scheduling family this comes
from. A greedy that shoots at time zero on the fixture is exactly
the trap.

The worked run: trace the model on the section's printed sample,
official sample 2, the judge data's only infeasible one. The photos
are [1,15] and [0,20] with t = 10, the distinct start times 1 and 0
are swept latest first, and the distinct ends are 15 and 20. At
s = 1 the subproblem [1,15] holds only the [1,15] photo, stacked as
late as it fits, the shot [5,15] with C = 5, and [1,20] holds the
same photo stacked [10,20] with C = 10; the per-s collapse takes
minC = 5, and since 5 - 1 = 4 < 10, every start in (C - t, s) =
(-5, 1) starves a subproblem, which forbids the one nonnegative
integer start 0. At s = 0 the subproblem [0,20] holds both photos,
stacked [10,20] and then [0,10], but the start 0 is forbidden, the
second shot slides to -5, and C = -5 < s = 0 declares the day
infeasible before the greedy ever runs, and
the trace ends at the printed answer `no`.

#table(
  columns: (auto, auto, 1.3fr, auto, 1.3fr),
  inset: 4pt,
  table.header([*[s, e]*], [*photos*], [*as-late stack*], [*C*], [*verdict*]),
  [[1, 15]], [1], [5 to 15], [5], [slack 4 < 10, forbid start 0],
  [[1, 20]], [1], [10 to 20], [10], [collapsed into minC = 5],
  [[0, 15]], [1], [5 to 15], [5], [holds, never binds],
  [[0, 20]], [1, 2], [10 to 20, then -5 to 5], [-5], [C < s: infeasible],
)

#listing("icpc/samples-c/src/Ch08/pH.c", first: 110, last: 140, caption: [c: the as-late chain kept incrementally, activation and cascade over deadline order])

#listing("icpc/samples/src/Ch08/PH.cs", first: 41, last: 67, caption: [c\#: phase one over distinct ends, big arrays of first starts, regions merged sorted])

#listing("icpc/samples-go/ch08/ph.go", first: 111, last: 144, caption: [go: the latest-first sweep with C pushed below regions per packed photo])

#listing("icpc/samples-js/src/ch08-ph-scenery.mjs", first: 66, last: 105, caption: [javascript: phase one with a region set answered by binary search])

#listing("icpc/samples-py/src/Ch08/ph.py", first: 63, last: 93, caption: [python: the per-s minimum kept running, regions as descending interval lists])

#listing("icpc/samples-lua/ch08_ph.lua", first: 107, last: 139, caption: [lua: the same sweep, the region metatable carrying below and above])

C is the structural outlier, it keeps the as-late schedule as an
incrementally maintained chain over deadline order with a successor structure, so each activation cascades downward instead of rebuilding. The other five share the [s, e] subproblem sweep over distinct end times with a region set answered by binary search, the region container differing per language, sorted arrays in C\#, a descending-interval struct in Go and JavaScript and Python and Lua with bisect in Python and a metatable in Lua. The measured fixture is three windows `0 8 / 1 3 / 4 6` with t equal to 2, where [1,3] and [4,6] lock and [0,8] takes [6,8], so every suite asserts `yes`, alongside the two identical windows answering `no` and the pair forcing a start at zero answering `yes`. Times stay under a billion and n times t under a billion, int64-safe in the four int64 languages and exact in JavaScript's doubles.

#diagram([three windows, the two short shots locked late, the [0,8] shot at [6,8], the greedy's wrong [0,2] start crossed out], length: 12pt, {
  let win(y, x0, x1, t, fill: luma(235)) = {
    cdraw.rect((x0, y), (x1, y + 0.85), fill: fill, radius: 0.02)
    cdraw.content((x0 - 0.15, y + 0.42), text(size: 6pt)[#t], anchor: "east")
  }
  cdraw.line((1.6, 0.8), (16.4, 0.8), stroke: luma(120), mark: (end: ">"))
  cdraw.content((16.6, 0.8), [time], size: 6pt, anchor: "west")
  let sx = (x) => 1.6 + x * 1.7
  win(6.0, sx(0), sx(8), [[0,8]])
  win(4.4, sx(1), sx(3), [[1,3]], fill: luma(205))
  win(2.8, sx(4), sx(6), [[4,6]], fill: luma(205))
  cdraw.rect((sx(6), 6.0), (sx(8), 6.85), fill: luma(180), radius: 0.02)
  cdraw.content((sx(7), 7.1), [shot at [6,8]], size: 6pt, anchor: "south")
  cdraw.line((sx(1), 6.0), (sx(1), 6.85), stroke: luma(20))
  cdraw.line((sx(3), 6.0), (sx(3), 6.85), stroke: luma(20))
  cdraw.content((sx(2), 5.2), [must fit here], size: 6pt, anchor: "north")
  cdraw.rect((sx(0), 6.0), (sx(2), 6.85), stroke: (paint: luma(20), dash: "dashed"))
  cdraw.line((sx(0) + 0.2, 6.2), (sx(2) - 0.2, 6.65), stroke: luma(20))
  cdraw.line((sx(0) + 0.2, 6.65), (sx(2) - 0.2, 6.2), stroke: luma(20))
  cdraw.content((sx(1), 8.0), [greedy's [0,2] start, wrong], size: 6pt, anchor: "south")
  cdraw.content((8.0, 1.6), [phase one forbids the starts that starve a locked subproblem], size: 6.5pt)
})

== problem I, secret chamber at mount rushmore

A hidden chamber at Mount Rushmore holds documents enciphered
letter by letter. The key is a list of directed translations between
lowercase letters, some letters with several translations, some with
none, and applying them repeatedly turns one letter into another. A
pair of words matches when the words have equal length and each
letter of the first can be turned into the letter at the same
position of the second through zero or more translations, and the
task is to answer yes or no for every pair
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers m and n by the problemset pdf, m from 1 to
500 the number of translations and n from 1 to 50 the number of word
pairs, then m lines of two distinct letters each, a can translate to
b, every ordered pair appearing at most once, then n word-pair lines.
All words are lowercase and 1 to 50 letters long. The output is one
yes or no line per pair under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`I-secretchamber/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: the identical pair needs zero translations, out
matches the through o to c to t to e, u to h and t to e, while can
fails on a, which has no translation at all, and work fails on r
reaching no l, giving yes no no yes yes.

input:

```
9 5
c t
i r
k p
o c
r o
t e
t f
u h
w p
we we
can the
work people
it of
out the
```

expected output:

```
yes
no
no
yes
yes
```

Recognition: the bounds collapse the universe. Up to 500
translations live on 26 letters, and 50 word pairs of at most 50
letters each are at most 2500 position checks, so the whole task is
one 26^3 = 17576-operation closure and then constant-time lookups,
trivially inside the 1 second limit.

The statement's shape, each letter of the first word can be turned
into the letter at the same position of the second through zero or
more translations, is per-position reachability: a length mismatch
fails at once, and otherwise the only question is which of the 26
letters reach which. Problem I is the 2017 face of the algebraic
reduction to a small universe family. Algebraic reduction to a small
universe covers chapter 10 problem K and chapter 11 problem Z.

The tempting shortcut, checking one translation step per position or
walking the 500-edge graph per position, is priced out both ways:
one step is refuted by the sample itself, o reaches t only through
o to c to t, and a per-position walk pays 2500 x 500 = 1.25 x 10^6
edge visits for what the 17576-operation closure answers once.

Page 9 of the solutions pdf closes the letter graph transitively:
build the directed graph on the 26 letters, run Floyd-Warshall in 26
cubed, and every query position becomes one reachability lookup, with
a length mismatch an immediate no. Tied with E at the set's highest
solve count, 127 teams, this is the chapter's baseline, and all six
solvers are the same program in six spellings.

The worked run: trace the model on sample 1. The nine printed
translations close over the 26 letters: c reaches t, then e through
t, i reaches r then o, o reaches c then t, then e and f through the
t edges, r reaches o, u reaches h, w and k reach p, and every letter
reaches itself in zero steps. The five pairs then read off position
by position. we against we needs zero translations, yes. can against
the fails at the first a, which has no translation at all, no. work
against people fails on length, 4 against 6, no. it against of needs
i to o, which runs i to r to o, and t to f directly, yes. out
against the needs o to t through c, u to h, and t to e, all of them
hold, yes, and the trace ends at the printed answer `yes`.

#table(
  columns: (auto, auto, 1.5fr, auto),
  inset: 4pt,
  table.header([*pair*], [*lengths*], [*positions*], [*verdict*]),
  [we we], [2 = 2], [w to w, e to e, zero steps], [yes],
  [can the], [3 = 3], [a reaches nothing], [no],
  [work people], [4 and 6], [mismatch], [no],
  [it of], [2 = 2], [i to r to o, t to f], [yes],
  [out the], [3 = 3], [o to c to t, u to h, t to e], [yes],
)

#listing("icpc/samples-c/src/Ch08/pI.c", first: 20, last: 50, caption: [c: self-reach seeded, warshall over the byte matrix, per-pair scan])

#listing("icpc/samples/src/Ch08/PI.cs", first: 11, last: 38, caption: [c\#: the 26 by 26 bool matrix, same triple loop])

#listing("icpc/samples-go/ch08/pi.go", first: 19, last: 59, caption: [go: arrays of 26 bools, zero translations always suffice])

#listing("icpc/samples-js/src/ch08-pi-secretchamber.mjs", first: 12, last: 42, caption: [javascript: typed-array rows, same closure])

#listing("icpc/samples-py/src/Ch08/pi.py", first: 10, last: 28, caption: [python: the per-pair check as one all() generator])

#listing("icpc/samples-lua/ch08_pi.lua", first: 12, last: 45, caption: [lua: pattern-matched tokens, same closure and scan])

The one honest detail is the diagonal, Go, JavaScript and Lua seed
i reaching i before the closure, C prints the diagonal in its initialization loop, C\# lets the loop's k equal i case do it, Python builds the matrix with i equal j. The measured fixture is four translations `a b / b c / x y / y x` against four query pairs, the chain answers `ab` versus `cc` with yes, the cross-family pair and the length mismatch answer no, asserted as the exact four-line string `no / yes / no / no` in all six suites, alongside the two-letter cycle answering `yes / yes`. Booleans only, no integer concerns.

#diagram([the letter digraph, the a-b-c chain, the x-y cycle, one query pair aligned position by position], length: 12pt, {
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.42, fill: luma(235), stroke: luma(80))
    cdraw.content((x, y), text(size: 7pt)[#t])
  }
  node(2.2, 6.4, [a]); node(5.0, 6.4, [b]); node(7.8, 6.4, [c])
  cdraw.line((2.62, 6.4), (4.58, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.42, 6.4), (7.38, 6.4), stroke: luma(60), mark: (end: ">"))
  node(11.4, 6.4, [x]); node(14.2, 6.4, [y])
  cdraw.line((11.78, 6.55), (13.82, 6.55), stroke: luma(60), mark: (end: ">"))
  cdraw.line((13.82, 6.25), (11.78, 6.25), stroke: luma(60), mark: (end: ">"))
  cdraw.content((2.2, 4.9), [query: ab vs cc], size: 6.5pt)
  cdraw.rect((1.8, 3.0), (3.0, 4.1), fill: luma(245), radius: 0.02)
  cdraw.rect((3.4, 3.0), (4.6, 4.1), fill: luma(245), radius: 0.02)
  cdraw.content((2.4, 3.55), [a], size: 7pt)
  cdraw.content((4.0, 3.55), [b], size: 7pt)
  cdraw.rect((6.4, 3.0), (7.6, 4.1), fill: luma(245), radius: 0.02)
  cdraw.rect((8.0, 3.0), (9.2, 4.1), fill: luma(245), radius: 0.02)
  cdraw.content((7.0, 3.55), [c], size: 7pt)
  cdraw.content((8.6, 3.55), [c], size: 7pt)
  cdraw.line((2.4, 4.1), (7.0, 4.6), stroke: luma(60), mark: (end: ">"))
  cdraw.line((4.0, 4.1), (8.6, 4.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.5, 2.2), [a reaches c via b, b reaches c: yes], size: 6.5pt)
  cdraw.content((5.5, 1.4), [length mismatch: no], size: 6pt, fill: luma(110))
})

== problem J, son of pipe stream

The hometown flubber network needs a routing. Node 1 is the flubber
factory, node 2 the water source, node 3 the flubber department that
consumes both, and the p bidirectional pipes carry both fluids at
once. Flubber is sluggish with viscosity v, so a pipe whose water
capacity is c liters per second moves only 1 liter per second of pure
flubber and scales linearly for mixtures: rates f and w in one pipe
must obey v times f plus w at most c. The two fluids may never flow
in opposite directions through the same pipe, and membranes at every
node separate and reorganize incoming mixtures at will, so each fluid
conserves at every node except its own source and the department.
Maximize the value F to the a times W to the 1 minus a of the
delivered rates, print the flubber and water rate of every pipe in
input order, negative when the fluid moves from the pipe's second
node to its first, then print the maximum value
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is four values by the problemset pdf: n from 3 to 200
locations, p from n-1 up to n(n-1)/2 pipes, the viscosity v with
1 <= v <= 10 and the mixture weight a with 0.01 <= a <= 0.99, the two
reals carrying at most 10 digits after the decimal point. Then p
lines of j < k and the integer capacity c with 1 <= c <= 10. No two
pipes join the same pair and the network is connected. The output is
p pipe lines then the value, everything within an absolute error of
10^-4, any valid optimal routing accepted, under the pdf's 5 second
limit.

Official sample 1, reprinted byte for byte from the judge data pair
`J-sonofpipestream/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: the cut into node 3 totals Z = 4
water-equivalents, Fmax is 4 and Wmax is 4, a times Z = 2.64 lands
inside [0, 4], so flubber leaves node 1 at 2.64 water-equivalents,
0.88 liters per second at v = 3, against 1.36 of water, and the six
pipe lines end in the value 1.02037965897.

input:

```
6 6 3.0 0.66
2 4 8
4 6 1
3 6 1
4 5 5
1 5 7
3 5 3
```

expected output:

```
0.000000000 1.360000000
0.000000000 1.000000000
0.000000000 -1.000000000
0.000000000 0.360000000
0.880000000 0.000000000
-0.880000000 -0.360000000
1.02037965897
```

Recognition: the bounds fit four max flows and nothing fancier. The
network runs at most 200 nodes and 19900 pipes, one Dinic pass over
201 nodes and about 39800 arcs is 10^9 double operations at the
O(V^2 E) worst case, four passes fit the 5 second limit with
capacity doubles and an epsilon, and the integer capacities keep
every water-equivalent flow the mix quotes exact.

The statement's shape, two fluids sharing pipes under the linear law
v f + w at most c with a product objective, is supply moving through
shared capacity: bill one flubber liter as v capacity units and both
fluids become one commodity whose total the max flow fixes and whose
split between the sources the objective chooses. Problem J is the
2017 face of the flow modeling on a network family. Chapter 09
problem C is the other half of the flow modeling on a network pair.

The tempting shortcut, a genuine two-commodity flow that routes the
fluids independently, is priced out before any bound is read:
two-commodity integral flow has no max-flow integrality to lean on
and the no-opposing-flows rule is not convex, while the
water-equivalent billing makes one commodity that four Dinic runs
answer exactly.

Pages 9 and 10 of the solutions pdf show the viscosity is a red
herring once flubber is billed v capacity units per liter. Work in
water-equivalent units, where a pipe holds c units total and a
flubber liter counts as v of them, and the integer capacities make
every max flow integral. Three flows settle the optimum: Z, the max
flow from a super source feeding both node 1 and node 2 into node 3,
Fmax from node 1 alone, Wmax from node 2 alone. The optimal total is
always the full Z, with flubber clamped into the interval from
Z - Wmax to Fmax, F* = clamp(a times Z, Z - Wmax, Fmax) and water
Z - F*, and the solutions' convexity argument shows the
no-opposing-flows constraint never binds at that split. The routing
is built from two combined routings: max flubber first with the
residual carrying water gives f1, max water first with the residual
carrying flubber gives f2, mixing alpha times f1 plus 1 minus alpha
times f2 reaches the target totals, and one final max flubber flow
from node 1 through a digraph whose arcs are the mixed usages splits
each pipe into flubber plus leftover water. Book 9's chapter 38,
network flows ii, builds Dinic's algorithm from scratch. Four Dinic
runs per input.

The worked run: trace the model on sample 1. The cut into node 3 is
the printed pipes (3,5) with capacity 3 and (3,6) with capacity 1,
so Z = 4 water-equivalents and nothing beats it. Flubber alone from
node 1 pushes 3 through (1,5) and (3,5) plus 1 more through (5,4),
(4,6) and (3,6), so Fmax = 4; water alone from node 2 pushes the
mirror routes, 3 through (2,4), (4,5) and (3,5) plus 1 through
(2,4), (4,6) and (3,6), so Wmax = 4. The clamp interval is [Z - Wmax,
Fmax] = [0, 4], and a Z = 0.66 x 4 = 2.64 lands inside: F\* = 2.64
water-equivalents of flubber, 2.64 / 3 = 0.88 liters per second at
v = 3, against W = 4 - 2.64 = 1.36 of water. The printed routing
carries exactly that, flubber 0.88 along (1,5) into (3,5), water
1.00 along (2,4), (4,6) into (3,6) and 0.36 along (2,4), (4,5) into
(3,5), where v f + w = 3 x 0.88 + 0.36 = 3 saturates the capacity,
and the value 0.88^0.66 x 1.36^0.34 reads 1.02037965897, and
the trace ends at the printed answer `1.02037965897`.

#diagram([sample 1's six pipes, flubber thick along 1-5-3, water split 1.00 through 4-6 and 0.36 through 4-5], length: 12pt, {
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.45, fill: luma(235), stroke: luma(80))
    cdraw.content((x, y), text(size: 7pt)[#t])
  }
  node(2.2, 6.2, [1]); node(2.2, 1.6, [2]); node(6.8, 6.2, [5])
  node(6.8, 3.9, [4]); node(10.2, 2.4, [6]); node(13.0, 4.6, [3])
  cdraw.line((2.65, 6.2), (6.35, 6.2), stroke: luma(20), width: 0.9, mark: (end: ">"))
  cdraw.content((4.5, 6.5), [f = 0.88, c 7], size: 6pt, anchor: "south")
  cdraw.line((6.8, 6.2), (12.55, 4.75), stroke: luma(20), width: 0.9, mark: (end: ">"))
  cdraw.content((9.4, 6.0), [f = 0.88, w = 0.36], size: 6pt, anchor: "south")
  cdraw.content((10.4, 4.6), [vf + w = 3 = c], size: 6pt, anchor: "north", fill: luma(110))
  cdraw.line((2.65, 1.6), (6.35, 3.75), stroke: luma(60), width: 0.4, mark: (end: ">"))
  cdraw.content((3.8, 2.4), [w = 1.36, c 8], size: 6pt, anchor: "north")
  cdraw.line((6.8, 3.65), (6.8, 6.0), stroke: luma(60), width: 0.4, mark: (end: ">"))
  cdraw.content((7.2, 5.1), [w = 0.36, c 5], size: 6pt, anchor: "west")
  cdraw.line((7.15, 3.7), (9.85, 2.55), stroke: luma(60), width: 0.4, mark: (end: ">"))
  cdraw.content((8.2, 3.4), [w = 1.00, c 1], size: 6pt, anchor: "north")
  cdraw.line((10.55, 2.7), (12.7, 4.3), stroke: luma(60), width: 0.4, mark: (end: ">"))
  cdraw.content((11.9, 3.1), [w = 1.00, c 1], size: 6pt, anchor: "south")
  cdraw.content((7.4, 0.6), [Z = 4, F\* = 2.64 water-equivalents, W = 1.36, value 1.02037965897], size: 6.5pt)
})

#listing("icpc/samples-c/src/Ch08/pJ.c", first: 44, last: 74, caption: [c: Z, the two orderings f1 and f2, the clamp, the convex mix])

#listing("icpc/samples/src/Ch08/PJ.cs", first: 41, last: 73, caption: [c\#: the same four runs over a dense capacity matrix, with conservation asserts])

#listing("icpc/samples-go/ch08/pj.go", first: 61, last: 101, caption: [go: paired-capacity undirected edges, net usage read off the residual])

#listing("icpc/samples-js/src/ch08-pj-sonofpipestream.mjs", first: 46, last: 87, caption: [javascript: the same shape over the ch08-dinic module])

#listing("icpc/samples-py/src/Ch08/pj.py", first: 108, last: 143, caption: [python: the two orderings, the clamp, the repush digraph])

#listing("icpc/samples-lua/ch08_pj.lua", first: 39, last: 76, caption: [lua: the year's ch08_dinic module under the same four runs])

All six carry the same two combined routings, flubber-first and
water-first, mix them to the clamped target, and push max flubber through a digraph whose arcs are the mixed usages, water per pipe is what remains. The carrier differs, C and the Go, JavaScript, Lua and Python helpers keep paired arcs in edge lists or adjacency arrays with capacities as doubles and an epsilon, C\# runs a dense n by n matrix and throws when a phase falls short, which is how it self-checks conservation. The measured fixture is the four-pipe network `1 3 4 / 2 3 4 / 1 4 2 / 3 4 2` with v equal to 2 and a equal to 0.5, Z = 10, the interval collapses to [6, 6], flubber saturates its cut at 3 liters, and every suite asserts all four pipe lines plus the value `3.46410161514` exactly, alongside the interior-alpha junction case ending in `2.82842712475`. Capacities are integers but the mix is decimal, so the max flows run in doubles with epsilon comparisons throughout, no bigint.

#diagram([the four-node network, flubber liters thick, water thin, the node 4 junction, the budget on pipe (1,3)], length: 12pt, {
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.45, fill: luma(235), stroke: luma(80))
    cdraw.content((x, y), text(size: 7pt)[#t])
  }
  node(2.4, 6.4, [1]); node(2.4, 2.6, [2]); node(12.6, 4.5, [3]); node(7.4, 4.5, [4])
  cdraw.line((2.85, 6.4), (12.15, 4.5), stroke: luma(20), width: 0.9, mark: (end: ">"))
  cdraw.content((7.2, 6.0), [f = 2 liters, w = 0], size: 6pt, anchor: "south")
  cdraw.content((7.4, 5.4), [v*f + w = 4 <= c], size: 6pt, fill: luma(110), anchor: "north")
  cdraw.line((2.85, 2.6), (12.15, 4.5), stroke: luma(60), width: 0.4, mark: (end: ">"))
  cdraw.content((7.4, 2.7), [w = 4], size: 6pt, anchor: "north")
  cdraw.line((2.85, 6.15), (6.95, 4.75), stroke: luma(20), width: 0.6, mark: (end: ">"))
  cdraw.content((4.2, 5.8), [f = 1], size: 6pt, anchor: "south")
  cdraw.line((7.85, 4.5), (12.15, 4.5), stroke: luma(20), width: 0.6, mark: (end: ">"))
  cdraw.content((9.9, 4.9), [f = 1, node 4 to 3, printed negative], size: 6pt, anchor: "south")
  cdraw.content((7.4, 3.4), [junction 4 conserves both fluids], size: 6pt)
  cdraw.content((7.4, 0.9), [Z = 10 water-equivalents, flubber clamped to 6, value 3.46410161514], size: 6.5pt)
})

== problem K, tarot sham boast

The rival plays n rounds of rock paper scissors, choosing uniformly
at random and independently every round. Each of s fortune-tellers
predicted one string of the rival's choices, all predictions the same
length, and the task is to rank the predictions by the probability
that each appears somewhere in the match as a contiguous block of the
rival's sequence, most likely first, ties kept in input order
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is two integers n and s by the problemset pdf, n from 1 to
10^6 the number of rounds and s from 1 to 10 the number of
predictions, then s lines, each a string over R, P and S, all of one
common length from 1 up to the smaller of n and 10^5. The output is
the s predictions in sorted order under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`K-tarotshamboast/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: with n = 3 and length 2 the truncation threshold
2 l - n is 1, PS carries no border and leads, then PP, RR and SS tie
on border length 1 and keep their input order.

input:

```
3 4
PP
RR
PS
SS
```

expected output:

```
PS
PP
RR
SS
```

Recognition: the bounds keep it linear. Predictions are at most 10
strings of at most 10^5 letters over n = 10^6 rounds, so each
failure function costs one O(l) pass and the stable sort costs s log
s, about 33 comparisons, a few million character touches inside the
2 second limit.

The statement's shape, rank predictions by the probability each
appears as a contiguous block of the random sequence, hides a
collapse: for one common length the first-order inclusion-exclusion
terms are identical across strings, so only self-overlap separates
them, and self-overlap is exactly the border sequence read off the
KMP failure chain. Problem K is the 2017 face of the string borders,
rotations, and automata family. String borders, rotations, and
automata connect chapter 10 problem G and chapter 12 problem F.

The tempting shortcut, computing the probabilities exactly, is
priced out by the state space: the rival's sequence ranges over
3^1000000 outcomes and exact inclusion-exclusion over the n - l + 1
placements walks 2^999999 subset terms, while the truncated border
sequences rank the same order in one failure pass per string.

Pages 10 and 11 of the solutions pdf give the ranking rule. The
first-order inclusion-exclusion terms are identical for all strings
of one length, so the differences come entirely from self-overlaps:
the rank key of a prediction X is its border sequence, the border
lengths of X in decreasing order, equivalently the shifts at which X
overlaps itself, read off the KMP failure chain, truncated at the
threshold 2 l - n because two occurrences cannot both fit in n rounds
below it, and a uniform trailing zero entry never affects the order,
so it is dropped. A lexicographically smaller border sequence means a
more likely prediction, so the sort is ascending and stable, O(l + s
log s) overall. Book 9's chapter 35, combinatorics, carries the
inclusion-exclusion machinery the ranking's first-order terms are an
instance of. Both official samples fall out of the rule, the
second one ranking the border-free PRSPS first and the 4-3-2-1 chain
of SSSSS last. The correctness proof lives in a separate document the
solutions cite.

The worked run: trace the model on sample 1. The common length is
l = 2 against n = 3 rounds, so the truncation threshold is 2l - n =
1 and borders at or above 1 count. The failure pass walks each
printed string: PP's prefix P equals its suffix P, border length 1;
RR the same, 1; PS's P and S differ, no border at all; SS the same
as PP, 1. Truncated, the rank keys read PS [], PP [1], RR [1] and
SS [1], ascending lexicographic order puts the empty sequence
first, PS, and the three equal [1] sequences keep their input order
PP, RR, SS, and the trace ends at the printed answer `SS`.

#table(
  columns: (auto, 1.3fr, auto, auto),
  inset: 4pt,
  table.header([*prediction*], [*border walk*], [*key at 2l - n = 1*], [*output rank*]),
  [PP], [P equals P, length 1], [[1]], [2],
  [RR], [R equals R, length 1], [[1]], [3],
  [PS], [P against S, none], [[]], [1],
  [SS], [S equals S, length 1], [[1]], [4],
)

#listing("icpc/samples-c/src/Ch08/pK.c", first: 43, last: 65, caption: [c: the failure function per prediction, borders kept at or above 2l-n])

#listing("icpc/samples/src/Ch08/PK.cs", first: 40, last: 62, caption: [c\#: borders as a list, compare by element then length])

#listing("icpc/samples-go/ch08/pk.go", first: 46, last: 74, caption: [go: borderSeq off the failure chain, sort.SliceStable for ties])

#listing("icpc/samples-js/src/ch08-pk-tarotshamboast.mjs", first: 13, last: 33, caption: [javascript: the same border walk, the stable array sort])

#listing("icpc/samples-py/src/Ch08/pk.py", first: 15, last: 33, caption: [python: borders and index as one sorted tuple])

#listing("icpc/samples-lua/ch08_pk.lua", first: 10, last: 33, caption: [lua: table.sort is not stable, the index tiebreak is spelled out])

The interesting per-language question is who guarantees the tie
order. C and Lua spell it, C's comparator falls back to the input index and Lua's to a.idx, Go uses #raw("sort.SliceStable") and JavaScript the stable array sort, Python sorts (borders, index) tuples so the tiebreak is positional, C\# compares border lists with #raw("List.Sort") and no index fallback. The measured fixture is n equal to 10 with `RRR / RPR / PPP / PPR / RPP`, border-free PPR and RPP first in input order, then RPR, then RRR before PPP, asserted as the exact five-line ranking in all six suites, alongside the truncation case n equal to 4 where the 2l minus n threshold erases the length-1 borders and `RPR / RRP / RRR` falls out. Border lengths fit any integer type, no concerns.

#diagram([RRR's failure chain 2-1-0 against RPR's 1-0, the truncation threshold drawn at 2l-n], length: 12pt, {
  let bar(x, y, w, t, fill: luma(215)) = {
    cdraw.rect((x, y), (x + w, y + 0.75), fill: fill, radius: 0.02)
    cdraw.content((x + w + 0.25, y + 0.37), text(size: 6pt)[#t], anchor: "west")
  }
  cdraw.content((2.0, 7.4), [RRR], size: 7pt, anchor: "east")
  bar(2.4, 6.3, 4.4, [border 2])
  bar(2.4, 5.3, 2.2, [border 1])
  cdraw.content((2.0, 4.4), [RPR], size: 7pt, anchor: "east")
  bar(2.4, 3.9, 2.2, [border 1])
  cdraw.line((1.6, 2.7), (15.6, 2.7), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((1.6, 2.35), [threshold 2l - n], size: 6.5pt, anchor: "north")
  cdraw.content((9.6, 1.5), [n = 10: threshold -4, all borders count], size: 6.5pt)
  cdraw.content((9.6, 0.7), [n = 4: threshold 2, the length-1 borders drop], size: 6.5pt, fill: luma(110))
  cdraw.content((12.0, 6.7), [smaller border sequence, more likely], size: 6.5pt, anchor: "west")
})

== problem L, visual python++

Visual Python++ draws every statement block as a rectangle of
characters with a top-left corner and a bottom-right corner. In a
syntactically correct program every two blocks are either nested, one
inside the other, or disjoint, and in both cases their borders may
not overlap. Programmers only mark the top-left and bottom-right
corners, the parser must match them up, and the task is exactly that
parser step: n top-left corners and n bottom-right corners arrive
unmatched, and the output is the matching as a permutation, or the
literal syntax error when no valid nesting exists
(#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[statement]).

The input is one integer n, 1 to 10^5 by the problemset pdf, then n
lines of two integers r and c, 1 to 10^9, the top-left corners in
input order, then n lines of bottom-right corners the same way, all
2n locations distinct. The output is n lines, line i naming the
bottom-right corner matched to top-left corner i, corners of each
kind numbered from 1 in input order, any valid matching accepted, or
the two words syntax error, under the pdf's 5 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`L-visual/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: the (9,8) top-left closes first against the (14,17)
bottom-right, so line 2 answers 1 before line 1 answers 2, and the
rows 9 to 14 rectangle nests inside rows 4 to 19.

input:

```
2
4 7
9 8
14 17
19 18
```

expected output:

```
2
1
```

Official sample 3, same source, the one that needs both sweeps: the
first sweep pairs both corners without complaint, but the rectangles
it forms, rows 9 to 19 against rows 4 to 14, cross instead of
nesting, and the second sweep rejects the program.

input:

```
2
4 8
9 7
14 18
19 17
```

expected output:

```
syntax error
```

Recognition: the bounds demand one sorted pass. Corners reach 10^5
of each kind, so 2 x 10^5 events through an ordered structure is
about 2 x 10^6 set operations at n log n, comfortably inside the
5 second limit, while the naive pairing of every top-left with every
bottom-right is n^2 = 10^10 candidates before any nesting check
runs.

The statement's shape, every two blocks nested or disjoint with
borders never overlapping, hands over the discipline: sweeping
columns left to right, the unmatched top-left corners form a set
ordered by row, and a bottom-right corner at row r2 matches the
largest open row at most r2, exactly the predecessor question an
ordered active set answers. Problem L is the 2017 face of the sweep
line with an ordered active set family. Chapter 10 problem F is the
other member of the sweep line with an ordered active set family.

The tempting shortcut, pairing each top-left with the bottom-right
of nearest column and testing the n^2 leftovers, is priced out at
the same 10^10 with no pruning, and column proximity alone picks
wrong whenever an inner rectangle closes before an outer one, which
the sample's own nesting does.

Page 11 of the solutions pdf matches the corners by sweeping columns
left to right over the 2n events with an active set of unmatched
top-left corners ordered by row. On a top-left corner, a duplicate
row already in the set fails. On a bottom-right corner at row r2,
match the active top-left with the largest row at most r2, none
available fails. That first sweep is O(n log n) with an ordered
structure, and a second sweep over the now-known rectangles checks
that adjacent active pairs never let borders touch or cross. The
matching is unique when it exists, so byte comparison verifies.

The worked run: trace the model on sample 1. The printed corners
give four events, top-left (4,7), top-left (9,8), bottom-right
(14,17) and bottom-right (19,18), and the sweep reads them in column
order 7, 8, 17, 18 with no column ties to break. Column 7 opens row
4, column 8 opens row 9, the active set holds the two distinct rows
4 and 9. Column 17 closes at row 14: the largest active row at most
14 is 9, so top-left 2 pairs with bottom-right 1 and line 2 answers
1. Column 18 closes at row 19: the only open row left is 4, top-left
1 pairs with bottom-right 2 and line 1 answers 2. The second sweep
checks the two rectangles it just formed, rows 4 to 19 against rows
9 to 14 and columns 7 to 18 against 8 to 17, the inner sits strictly
inside with no borders touching, the output reads 2 then 1 down the
lines, and the trace ends at the printed answer `1`.

#diagram([the sample 1 rectangles nested, the sweep line on column 17 closing the inner block first], length: 12pt, {
  cdraw.rect((2.0, 0.8), (14.0, 6.5), fill: luma(248), stroke: luma(120), radius: 0.02)
  cdraw.content((8.0, 6.8), [rows 4 to 19, cols 7 to 18], size: 6pt, anchor: "south")
  cdraw.rect((3.1, 2.7), (12.9, 4.6), fill: luma(232), stroke: luma(80), radius: 0.02)
  cdraw.content((8.0, 2.3), [rows 9 to 14, cols 8 to 17], size: 6pt, anchor: "north")
  cdraw.circle((2.0, 6.5), radius: 0.14, fill: luma(20))
  cdraw.content((1.8, 6.9), [TL1 (4,7)], size: 6pt, anchor: "south")
  cdraw.circle((3.1, 4.6), radius: 0.14, fill: luma(20))
  cdraw.content((2.9, 5.0), [TL2 (9,8)], size: 6pt, anchor: "south")
  cdraw.circle((12.9, 2.7), radius: 0.14, stroke: luma(20), fill: white)
  cdraw.content((13.1, 2.3), [BR1 (14,17)], size: 6pt, anchor: "north")
  cdraw.circle((14.0, 0.8), radius: 0.14, stroke: luma(20), fill: white)
  cdraw.content((14.3, 0.5), [BR2 (19,18)], size: 6pt, anchor: "north")
  cdraw.line((12.9, 0.4), (12.9, 7.3), stroke: luma(20))
  cdraw.content((12.9, 7.6), [sweep at col 17], size: 6.5pt, anchor: "south")
  cdraw.line((12.6, 2.7), (3.5, 4.5), stroke: (paint: luma(20), dash: "dashed"), mark: (end: ">"))
  cdraw.content((8.0, 1.4), [BR1 at row 14 takes the largest open row at most 14, the 9], size: 6pt)
  cdraw.content((0.9, 0.1), [line 2 answers 1, line 1 answers 2], size: 6.5pt, anchor: "south-west")
})

#listing("icpc/samples-c/src/Ch08/pL.c", first: 96, last: 142, caption: [c: sweep one over compressed row ranks, fenwick predecessor picks the match])

#listing("icpc/samples/src/Ch08/PL.cs", first: 72, last: 93, caption: [c\#: the open set as a dictionary, matching through the nested fenwick's Pred])

#listing("icpc/samples-go/ch08/pl.go", first: 41, last: 81, caption: [go: events sorted opens-first on equal columns, the helper's pred answers matches])

#listing("icpc/samples-js/src/ch08-pl-visual.mjs", first: 30, last: 63, caption: [javascript: rank map over both corner kinds, same sweep])

#listing("icpc/samples-py/src/Ch08/pL.py", first: 66, last: 92, caption: [python: events as tuples, the inline fenwick's pred and later succ])

#listing("icpc/samples-lua/ch08_pl.lua", first: 29, last: 63, caption: [lua: the tie order judge-verified on the secrets, the ch08 fenwick required])

One tie order decides correctness on the official data, top-left
corners open before bottom-right corners close on the same column, and Go and Lua carry the comment naming the two secret files that pinned it. The order-statistics carrier is a Fenwick tree of counts over compressed row ranks with predecessor and successor everywhere, a shared helper for Go, JavaScript and Lua, an inline class in Python, a private nested class in C\#, and in C a helper for the first sweep plus a max segment tree for the second. The measured fixture is six corners matching as `2 / 3 / 1` with the rows 2 to 3 rectangle nested inside rows 1 to 8, asserted exactly in all six suites, alongside two syntax-error cases, two top-lefts sharing a row, and crossing rectangles caught by the second sweep. Rows reach a billion and row differences two billion, so C stores long long and the other int64 languages match, JavaScript's doubles are exact at this range.

#diagram([the column sweepline between cols 4 and 6, the active top-left set as a row-ordered rail, one match arrow], length: 12pt, {
  cdraw.rect((1.0, 2.0), (5.6, 4.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((3.3, 4.9), [rows 5-6, cols 1-4], size: 6pt, anchor: "south")
  cdraw.rect((7.2, 0.8), (12.4, 6.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((9.8, 6.9), [rows 1-8, cols 6-9], size: 6pt, anchor: "south")
  cdraw.rect((8.4, 3.6), (11.2, 5.2), fill: luma(230), stroke: luma(80), radius: 0.02)
  cdraw.content((9.8, 3.2), [rows 2-3, cols 7-8], size: 6pt, anchor: "north")
  cdraw.line((6.4, 0.4), (6.4, 7.2), stroke: luma(20))
  cdraw.content((6.4, 7.6), [sweep between cols 4 and 6], size: 6.5pt, anchor: "south")
  cdraw.circle((1.0, 2.0), radius: 0.16, fill: luma(20))
  cdraw.content((0.8, 1.5), [TL r5], size: 6pt, anchor: "north")
  cdraw.circle((5.6, 2.0), radius: 0.16, stroke: luma(20))
  cdraw.content((6.0, 1.4), [BR r6], size: 6pt, anchor: "north")
  cdraw.line((14.0, 6.8), (14.0, 0.6), stroke: luma(140))
  cdraw.content((15.6, 6.9), [active rail], size: 6pt)
  cdraw.circle((14.0, 3.4), radius: 0.14, fill: luma(60))
  cdraw.content((14.4, 3.4), [r1], size: 6pt, anchor: "west")
  cdraw.circle((14.0, 2.2), radius: 0.14, fill: luma(60))
  cdraw.content((14.4, 2.2), [r2], size: 6pt, anchor: "west")
  cdraw.line((5.6, 2.0), (14.0, 2.9), stroke: (paint: luma(20), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.4, 1.1), [BR at r6 matches the largest active row <= 6], size: 6pt)
})

== across the six languages

One set, twelve problems, and the same six solvers every time. The
table reads the chapter back from the language axis, what each problem was and where the six implementations genuinely diverged, which is rarely the algorithm and always the exactness carrier, the sort contract, or the data structure holding the state:

#table(
  columns: (1.4fr, 2.2fr, 2.4fr),
  inset: 4pt,
  table.header([*problem*], [*the method (solutions cite)*], [*where the six languages split*]),
  [A airport], [vertex-pair chords, boundary classification, O(n^3)], [exactness ladder: c fractions in #raw("__int128"), go big.Rat and js bigint re-evaluation, cs integer crosses, py and lua exact toggles],
  [B clue], [enumerate answer triples and consistent deals], [c clause backtracking, cs Hall condition, go/js/lua pruned deal search, py the judges' dictionary join],
  [C improbable], [per-height bipartite matching, m+n-match piles], [carrier only: dense byte matrix, column lists, adjacency lists, inlined, closure, module],
  [D money], [staircase prune, divide and conquer, O((m+n) log n)], [the 1e18 product: int64 in c/cs/go/lua, bigint multiply in js],
  [E speed], [bisection on a monotone time sum], [identical, only the pole guard and the nine-decimal formatting differ],
  [F posterize], [d^2 one-color costs, O(d^2 k) dp], [closed-form moments in go/js/py/lua, explicit cost loops at the rounded mean in c and cs],
  [G replicate], [backward xor sweeps, one localized repair], [nested-loop sweeps in five, bit-parallel rows through a transition table in py],
  [H scenery], [forbidden regions, then earliest-deadline greedy], [c keeps an incremental as-late chain, the other five sweep [s,e] subproblems over distinct ends],
  [I chamber], [26-closure by floyd-warshall, O(1) lookups], [nothing but spelling],
  [J pipe stream], [four dinic runs in water-equivalent units], [edge-list doubles with eps in c/go/js/py/lua, dense matrix with asserts in cs],
  [K tarot], [border sequences off the kmp chain, stable sort], [c and lua spell the index tiebreak, go and js use stable sorts, py sorts tuples, cs relies on List.Sort],
  [L visual], [column sweep, fenwick predecessor matching, second sweep], [helper modules in go/js/lua, inline class in py, nested class in cs, segment tree for sweep two in c],
)

The pattern the table keeps finding is that the 2017 problems
punished arithmetic and bookkeeping, not algorithm invention, so the six-language spread lands on which exactness a language can afford. Four problems needed more than a double or a 32-bit word, D past 2^53 where only JavaScript had to switch types, C past int32 but under 2^53, F under 2^53 but past int32, and L past int32 in the row differences. Two needed doubles with epsilon discipline end to end, A's boundary chords and J's flows, and both are exactly where the suites re-derive the printed decimals from exact arithmetic rather than trusting the float walk. The remaining six ran on machine ints, bytes, or booleans, E alone among them in plain doubles, a bisection with no integer boundary to police, and there the six listings are the same program wearing six syntaxes, which is its own finding about the set.

sources: the problems are
#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[icpc2017.pdf] and the algorithm reference for every method and complexity claim in this chapter is
#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/finals2017solutions.pdf")[finals2017solutions.pdf], both from the ICPC Foundation at icpc.global, both accessed 2026-09-14 and cached under ref/icpc with sha256 digests eb78eeba and 599e518a recorded in ref/icpc/INDEX.md, the solved-by counts and the first-python-finals note from the solutions pdf's first page. Judge data is local-only under ref/icpc/2017/data, never committed, 778 input files mapped to answer pairs by the committed ref/icpc/verify-data.ps1, and every sample pair reprinted in this chapter is the byte-exact content of that problem's sample-N.in and sample-N.ans files, attributed in place, with three problems on non-exact compare modes recorded in ref/icpc/compare.json: A in float, the last numeric token within the statement's 1e-6, because the official answers sit beyond double precision in both directions, E in float because the secrets mix shortest-form floats with %.9f samples and one answer sits 4e-7 off exact, verified 18 of 18, and J in last-line-float, the last non-empty line's last numeric token within 1e-4, because per-pipe routings are arbitrary among valid ones and only the maximum value is unique. The listings are sliced from the frozen solvers in books/icpc/samples-c/src/Ch08, books/icpc/samples/src/Ch08 with its tests under books/icpc/samples/tests/Ch08, books/icpc/samples-go/ch08, books/icpc/samples-js/src and test, books/icpc/samples-py/src/Ch08, and books/icpc/samples-lua, and every fixture this chapter pins is crafted, not taken from the pdfs. Suite counts, measured from those files: C 40 #raw("CHECK") assertions, C\# 26 #raw("[Fact]") test methods, Go 26 table-driven cases in ch08_test.go, JavaScript 26 node:test assertions across the twelve ch08 test files, Python 26 self-check #raw("check") calls, and Lua 26 #raw("T.eq") blocks through run.lua, the last three verified green on this machine on 2026-09-18, the first three counted from the frozen sources.
