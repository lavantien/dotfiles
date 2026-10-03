// book 9, chapter 11: icpc world finals 2022, problems P through Z,
// six languages per problem, listings sliced from the frozen solver
// files under books/icpc/samples*
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= icpc world finals 2022

The 46th world finals were played in Luxor in 2023, and the foundation
published the set as 11 problems lettered P through Z, the lettering
cycle chapter 1 describes. The problemset is
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf],
and every algorithm and complexity claim in this chapter is settled
against the official solutions pdf rather than reinvented. The
solutions pdf also carries the contest statistics: Z was solved by 0
teams and was the judges' pick as the hardest problem, S by exactly 1
team 276 minutes in, X by 8, R by 15, V by 24, Q by 72, T by 79, U by
92, P by 115, W by 116 teams with the first solve at 8 minutes, and Y
by 124 with the first solve at 6. This chapter walks all 11 problems
in the book's fixed order, one section per letter, six listings per
section, c through lua, every listing sliced from a solver file that
ran against the official judge data held locally under `ref/icpc/`.

== the year-local helpers: fenwick counting, planar predicates, io cursors, and the sweep engine

Four helper kits are year-local to this chapter, and everything else
comes from the wave 1 toolboxes the year chapters import. Problem Q
counts untrucked container values
with a 1-based fenwick tree over the value range, point add plus
prefix sum, queried as suffix counts. The six implementations agree
on the interface and differ in how the tree starts life: the C header
and the js class fill it with n point adds, C\# and go allocate an
empty tree, and the python and lua versions are born full in linear
time, `tree[i] = lowbit(i)`, because a tree of ones has a closed
form. The solver then only pays for removals.

#listing("icpc/samples-c/src/Ch11/ch11_fenwick.h", first: 6, last: 17, caption: [c, the year-local fenwick: point add and prefix sum over 1..n])

#listing("icpc/samples/src/Ch11/Fenwick.cs", first: 7, last: 26, caption: [c\#, the same two loops wrapped in the year-local Fenwick class])

#listing("icpc/samples-go/ch11/ch11_fenwick.go", first: 6, last: 26, caption: [go, fenwick11 as a plain struct with int tree slots])

#listing("icpc/samples-js/src/ch11-fenwick.mjs", first: 4, last: 21, caption: [javascript, the class with an Int32Array tree, add and prefix])

#listing("icpc/samples-py/src/Ch11/fenwick.py", first: 5, last: 23, caption: [python, born full via tree[i] = i and -i, so the solver only removes])

#listing("icpc/samples-lua/ch11_fenwick.lua", first: 6, last: 32, caption: [lua, new_ones builds the full tree in linear time, above wraps the suffix count])

Problem T needs three planar predicates, the 2d cross product,
closed-segment intersection with endpoint tolerance, and strict
containment in a CCW convex polygon. C, go, and lua carry them as a
year-local module beside the solver; C\#, javascript, and python embed
the same three predicates directly in the solver file, so their
listings land in section T rather than here.

#listing("icpc/samples-c/src/Ch11/ch11_geo.h", first: 11, last: 53, caption: [c, the geo kit: cross, closed-segment intersection with tolerance, strict convex containment])

#listing("icpc/samples-go/ch11/ch11_geo.go", first: 22, last: 68, caption: [go, the same kit with relative tolerances and a parameterized meeting point])

#listing("icpc/samples-lua/ch11_geo.lua", first: 6, last: 42, caption: [lua, flat coordinate parameters instead of tables, same three predicates])

The scan kit is the year's io contract, and the only kit the year
could not solve without: the 2022 secrets run to 10.7 MB for R,
6.7 MB for Q, 3.5 MB for P, and 1.4 MB for V, so every language
reads the file in one piece before parsing. The contract is a
whitespace cursor over the whole buffer, skip, a signed int64
reader, and one strtod double. C carries it as `Ch11/ch11_scan.h`,
imported by ten of the year's eleven solvers, everything but the
one-line Y, and it is the book's one helper that crosses years:
chapter 12's solvers and its sphinx header and chapter 13's twelve
solvers include it through `../Ch11/ch11_scan.h` paths, twenty-two
importers beyond this chapter. Go keeps the same cursor once per
package as the `scan11` struct inside the solver files, javascript,
python, and C\# split the whole-file string inline, and lua scans
bytes inside each solver, so no second twin file exists.

#listing("icpc/samples-c/src/Ch11/ch11_scan.h", first: 1, last: 39, caption: [c, the scan cursor: skip whitespace, signed int64, strtod double, one const pointer walking the whole input buffer])

The sweep engine is problem S's second lua file, the diagonal
(k, g, l) machine the solver requires as `ch11_psweep`, a port of
the go judge lane `psfast.go`. States live on anti-diagonals k + l,
and the slice below is the expansion core: one live diagonal read
through its bitmask of g slots, the finish pace probed against the
running best, and every pure-slow fan-out landed in a ring of c - 1
future buffers.

#listing("icpc/samples-lua/ch11_psweep.lua", first: 250, last: 287, caption: [lua, the sweep engine's diagonal expansion, pure-slow fan-outs landing in a ring of c-1 future buffers])

== p, turning red

Mei's parents spent a year remodeling their house and left it with a
complicated lighting system. Each room has one LED light showing
red, green, or blue, and buttons around the house are each wired to
a set of lights: pressing a button advances every light it controls
one step around that cycle, red to green, green to blue, blue to
red, and any button may be pressed as often as liked. The wiring
predates crossbars, so each light answers to at most two buttons.
Mei wants every light red and her parents want the buttons to
survive, so the task is the smallest total number of presses that
leaves every light red, or a verdict that all-red cannot be reached
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).
Turning Red is one of the five problem names this finals shares with
the 2023 set: this set's P is 2023's G retold.

The input, per the problemset pdf, is one line of l and b, with
1 <= l <= 2e5 lights and 0 <= b <= 2l buttons, then a line of l
characters over R, G, and B giving each light's starting color, then
b button lines: a count k with 1 <= k <= l followed by the k distinct
lights that button controls, each light appearing at most twice
across all buttons. The output is the minimum press total, or the
word impossible, under the pdf's 3 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`P-turningred/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: six buttons sort out eight lights, and the
cheapest full redden costs 8 presses.

input:

```
8 6
GBRBRRRG
2 1 4
1 2
4 4 5 6 7
3 5 6 7
1 8
1 8
```

expected output:

```
8
```

Official sample 2, same source: the red lights 1 and 4 pin buttons 1
and 3 to zero presses, the green light 2 then forces two presses on
button 2, and the blue light 3 wants two presses on button 3, which
light 4 has already pinned, so no assignment exists.

input:

```
4 3
RGBR
2 1 2
2 2 3
2 3 4
```

expected output:

```
impossible
```

Recognition: the bounds make the propagation linear before any
algebra starts. With l <= 2e5 lights and b <= 2l = 4e5 buttons under
the 3 second limit, one BFS over the light-button graph visits about
6e5 cells, and the three root trials per component triple that to
under 2e6 visits, two orders of magnitude inside budget, so the
whole solve is a handful of linear passes.

The statement's cue is its arithmetic shape: every light answers to
at most two buttons and each press advances a light one fixed step
around the color cycle, so each light is one equation over at most
two unknowns mod 3, the cue that turns the house wiring into an
auxiliary graph where buttons sharing a light chain into components.
Problem P is the 2022 face of the one free value per component
family, and one free value per component is the trick behind
chapter 12 problem G and chapter 13 problem K.

The tempting alternative, Gaussian elimination over all b = 4e5
unknowns, prices out at 4e5 cubed, 6.4e16 operations, and brute
force over press vectors is 3^400000, so the per-component root
trial is the only shape that closes.

With colors as residues mod 3, each light demands that its color plus
its buttons' press counts sum to 0. A light on two buttons is an equation over two
unknowns, a light on one button pins its button outright, and buttons
sharing lights chain into connected components where fixing one root
press count to 0, 1, or 2 determines everything else. Per component
the solver tries the consistent root values and keeps the cheapest
press total, linear in lights plus buttons, the model the solutions
pdf sketches on its page 2, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
Book 8's chapter 34, linear algebra, develops the gaussian
elimination that solves exactly this shape of small modular system,
of which the component propagation below is the sparse special case.
The six walks below all propagate with a BFS over a CSR adjacency,
and differ in how they retry root values:
the C, javascript, and lua versions stamp each trial so no visited
cleanup is needed, go resets only the touched cells, C\# re-walks a
precomputed BFS order and re-validates every edge at the end, and
python never retries at all, carrying each value as affine in the
root, `t + s*r` with `s = +-1`, and solving for the allowed roots
algebraically.

The worked run: trace the model on sample 1. Colors read as
residues, R = 0, G = 1, B = 2, and each light demands that its
color plus its buttons' presses sum to 0 mod 3. Light 2 is blue on
button 2 alone, so x2 = 1, and light 3 is already red on no button,
cost 0. The component of buttons 1, 3 and 4 is chained by lights 4,
5, 6 and 7: light 1, green on button 1, pins x1 = 2, light 4, blue
on buttons 1 and 3, forces x3 = 1 - 2 = 2 mod 3, and lights 5, 6
and 7, red on buttons 3 and 4, force x4 = -2 = 1, a component cost
of 2 + 2 + 1 = 5 with the root pinned rather than tried. Light 8,
green on buttons 5 and 6, wants x5 + x6 = 2, cheapest as 1 + 1 = 2.
The total is 5 + 1 + 2 = 8, and the trace ends at the printed answer
`8`.

#table(
  columns: (auto, 1.6fr, auto, auto),
  inset: 4pt,
  table.header([*unit*], [*forcing*], [*presses*], [*cost*]),
  [button 2], [light 2 blue on it alone, x2 = 1], [1], [1],
  [buttons 1, 3, 4], [light 1 pins x1 = 2, lights 4 to 7 propagate x3, x4], [2, 2, 1], [5],
  [buttons 5, 6], [light 8 green, x5 + x6 = 2], [1, 1], [2],
  [light 3], [red, wired to no button], [none], [0],
)

#listing("icpc/samples-c/src/Ch11/pP.c", first: 32, last: 66, caption: [c, try_component: stamp-carried BFS, press total or -1 on a violated edge or pin])

#listing("icpc/samples/src/Ch11/PP.cs", first: 102, last: 137, caption: [c\#, per root value t: assign in BFS order from any valued neighbor, then re-check every edge and pin])

#listing("icpc/samples-go/ch11/pp.go", first: 75, last: 109, caption: [go, the propagate closure: BFS values from the root, resets only the touched cells])

#listing("icpc/samples-js/src/ch11-pp-turningred.mjs", first: 82, last: 107, caption: [javascript, tryComponent over Int32Arrays, the same stamp trick as C])

#listing("icpc/samples-py/src/Ch11/pp.py", first: 85, last: 134, caption: [python, one BFS per component collects t and s = +-1 per button, then non-tree edges and pins pin the root value algebraically])

#listing("icpc/samples-lua/ch11_pp.lua", first: 110, last: 141, caption: [lua, try_component with per-trial stamps, one-based queue])

The pinned fixture is 6 lights, 4 buttons, colors RRGBRR: buttons 1
through 3 form a triangle through lights 1, 2, 3 whose only
consistent root assignment costs 4, and the blue light 4 sits alone
on button 4, adding one press, for a total of 5. Every suite asserts
`solve` of that exact input equals `5`, and the family around it
holds the four official samples, 8, the impossible one, 6, and 3:
the C, python, and lua suites count 5 checks each, the C\# suite 5
facts, go 5 table rows, js 5 blocks. Press totals stay under 4e5,
so no language needs anything beyond its native integers here, and
none of the six takes any special care.

#diagram([the fixture: a button triangle with one consistent assignment, plus the single-button light that pins its own press], length: 12pt, {
  let node(x, y, t, fill: luma(225)) = {
    cdraw.circle((x, y), radius: 0.55, fill: fill, stroke: luma(120))
    cdraw.content((x, y), t, size: 6.5pt)
  }
  node(3.0, 6.6, [b1 x=2])
  node(1.0, 3.6, [b2 x=1])
  node(5.0, 3.6, [b3 x=1])
  cdraw.line((3.0, 6.6), (1.0, 3.6), stroke: luma(100))
  cdraw.line((3.0, 6.6), (5.0, 3.6), stroke: luma(100))
  cdraw.line((1.0, 3.6), (5.0, 3.6), stroke: luma(100))
  cdraw.content((2.0, 5.4), [L1 R], size: 6pt, fill: luma(100))
  cdraw.content((4.0, 5.4), [L3 G], size: 6pt, fill: luma(100))
  cdraw.content((3.0, 3.0), [L2 R], size: 6pt, fill: luma(100))
  cdraw.content((7.4, 6.6), [root x1 = 2 forces x2 = x3 = 1], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((7.4, 5.7), [1 + 1 = 2 holds, cost 4], size: 6.5pt, anchor: "west", fill: luma(100))
  node(12.6, 3.3, [b4 x=1], fill: luma(238))
  cdraw.circle((12.6, 3.3), radius: 0.95, stroke: luma(60))
  cdraw.content((12.6, 1.8), [L4 B pins 2 + x4 = 0], size: 6pt, fill: luma(100))
  cdraw.content((0.8, 0.8), [5 total, the answer every suite pins], size: 6.5pt, anchor: "west", fill: luma(100))
})

== q, doing the container shuffle

A cargo ship unloads containers 1..n in ship order, and each
container is dropped onto one of two stacks with probability 1/2,
independently, the only randomness in the problem. Trucks then
collect the containers in a given pickup order. Loading a requested
container costs nothing extra only when it tops its stack. Otherwise
the containers above it shuffle to the other stack one at a time
until it tops, and then it moves to the truck. Count every
move except the ship's own unloading: each stack-to-stack shuffle
and each load onto a truck is one move, and the task is the expected
total over the random placements
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).

The input, per the problemset pdf, is one integer n with 1 <= n <=
1e6, then the pickup order as a permutation of 1..n on the second
line. The output is the expected number of moves with an absolute
error of at most 1e-3, under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`Q-doingthecontainershuffle/sample-1.in` and `sample-1.ans`, the
same pair the problems pdf prints: five containers picked as 4, 2,
5, 3, 1 cost 7.000 moves in expectation, the 5 loads plus an
expected 2 shuffles.

input:

```
5
4 2 5 3 1
```

expected output:

```
7.000
```

Official sample 2, same source: even the identity pickup pays, since
the random placement interleaves the two stacks and the interval
sweeps still cross untrucked containers, 15 of them summed over the
six pickups for 7.5 expected shuffles on top of the 6 loads.

input:

```
6
1 2 3 4 5 6
```

expected output:

```
13.500
```

Recognition: n <= 1e6 under the 2 second limit prices one
logarithmic pass and nothing more: a fenwick walk over the value
range costs about 20 tree hops per container, 2e7 hops in total,
while the placement randomness must never be expanded.

The statement's cue is the word expected over every random
placement: the 2^1000000 stack assignments stay implicit, so the
answer has to come from linearity, each container's shuffles
counted separately, the cue that asks for a membership count
instead of a simulation. Problem Q is the 2022 face of the counting
and expectation without enumeration family, and counting and
expectation without enumeration is the shared core of chapter 09
problem D, chapter 09 problem I, chapter 12 problem E, and chapter
12 problem K.

Simulating placements prices out at 2^n, and any dp over joint
stack orders inherits the same exponent, so the half-counted
interval membership is the only budget that closes.

The joint order, stack 1 bottom to
top then stack 2 top to bottom, never changes under shuffles, only
loses trucked containers, so the containers moved before loading
the next one are exactly the still-present members of the
joint-order interval, and a present container v lies in it with
probability 1/2 precisely when its ship value exceeds m, the smaller
of the two pickups bracketing the load. That gives an expectation of
n plus half the sum of untrucked counts above each pair minimum,
tallied with the year-local fenwick as a suffix count in one
logarithmic-tree pass per container, the derivation the solutions pdf
carries on its pages 2 and 3, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
The seam before the first pickup is bounded by a1 itself, and the
incoming endpoint is loaded rather than shuffled, so it never
counts.

The worked run: trace the model on sample 1. The pickup order is 4,
2, 5, 3, 1, and load i pays half the count of still-present ship
values above m, the smaller of the two pickups bracketing it, with
the first load bracketed by a1 = 4 alone. Load 1: of the present 1
to 5, one value, 5, exceeds 4, count 1. Load 2, bracketed by 4 and
2: of the present 1, 2, 3, 5, two values, 3 and 5, exceed m = 2,
count 2. Load 3, bracketed by 2 and 5: of the present 1, 3, 5, two
exceed m = 2, but the endpoint 5 itself is loaded, not shuffled,
count 1. Loads 4 and 5, bracketed by 5 and 3 then 3 and 1: nothing
present exceeds 3, then nothing exceeds 1, counts 0 and 0. The
correction sum is 1 + 2 + 1 = 4, the expectation is n plus half of
it, 5 + 4/2 = 7, and the trace ends at the printed answer `7.000`.

#table(
  columns: (auto, auto, auto, 1.5fr, auto),
  inset: 4pt,
  table.header([*load*], [*bracket*], [*m*], [*present above m*], [*count*]),
  [1], [seam, a1], [4], [5], [1],
  [2], [4, 2], [2], [3, 5], [2],
  [3], [2, 5], [2], [3, the endpoint 5 loads instead], [1],
  [4], [5, 3], [3], [none], [0],
  [5], [3, 1], [1], [none], [0],
)

#listing("icpc/samples-c/src/Ch11/pQ.c", first: 28, last: 55, caption: [c, the whole solver: suffix counts above m, seam bounded by a1, endpoint excluded])

#listing("icpc/samples/src/Ch11/PQ.cs", first: 15, last: 29, caption: [c\#, the same accounting seeded with the seam correction before the loop])

#listing("icpc/samples-go/ch11/pq.go", first: 15, last: 41, caption: [go, per pickup: values above m minus the already-trucked above m, minus the endpoint when it exceeds m])

#listing("icpc/samples-js/src/ch11-pq-doingthecontainershuffle.mjs", first: 13, last: 42, caption: [javascript, present minus prefix with the fenwick shed as trucks load])

#listing("icpc/samples-py/src/Ch11/pq.py", first: 12, last: 33, caption: [python, the born-full fenwick only pays removes, extra counts left - sum])

#listing("icpc/samples-lua/ch11_pq.lua", first: 33, last: 49, caption: [lua, seam first then pairs, printed as (2n + corr) / 2 to stay in integers])

The correction sum is an integer, so E always ends in .0 or .5 and
prints exactly: `%.3f` in C, go, and lua, `F3` with the invariant
culture in C\#, and `toFixed(3)` in javascript, which is why the
judge tolerances are a backstop rather than a necessity. The fixture
is n = 4 with pickup order 3 1 4 2: the seam pair contributes 1/2,
the pair (3, 1) contributes 1, the pair (1, 4) contributes 1/2, and
the last pair nothing, for E = 4 + 2 = 6. Every suite asserts
`6.000` on that input; the family adds the two official samples
`7.000` and `13.500` and the crafted single container `1.000`, four
checks per language except the C\# suite, which folds the two
official samples into one fact.

#diagram([one placement of the fixture: all four containers on stack 1, seven moves counted, expectation 6.000], length: 12pt, {
  let stack(x, items) = {
    for (i, it) in items.enumerate() {
      cdraw.rect((x, 1.0 + i * 0.9), (x + 2.2, 1.8 + i * 0.9), fill: luma(232), stroke: luma(140), radius: 0.02)
      cdraw.content((x + 1.1, 1.4 + i * 0.9), it, size: 6.5pt)
    }
  }
  stack(1.0, ([4], [3], [2], [1]))
  stack(6.2, ())
  cdraw.content((2.1, 5.4), [stack 1], size: 6pt, fill: luma(100))
  cdraw.content((7.3, 5.4), [stack 2], size: 6pt, fill: luma(100))
  cdraw.line((3.2, 4.0), (6.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.7, 4.8), [3 shuffles 2, 4], size: 6pt, fill: luma(100))
  cdraw.line((4.2, 3.1), (8.4, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.4, 2.5), [truck 3, then 1], size: 6pt, fill: luma(100))
  cdraw.content((0.8, 0.3), [E = 4 loads + 1/2 + 1 + 1/2 shuffles = 6.000], size: 6.5pt, anchor: "west", fill: luma(100))
})

== r, zoo management

A zoo's enclosures all hold animals and are joined by two-way
tunnels, and moving anyone is hard because no enclosure may sit
empty mid-move. One move picks a set of animals and sends them
simultaneously down distinct tunnels, each into a neighboring
enclosure that is itself being vacated in the same move, and no
tunnel carries two animals in one move, so a move is exactly a
rotation around one or more vertex-disjoint cycles of the tunnel
graph: two animals cannot simply trade places through one tunnel,
they would meet inside. Enclosure i holds an animal of type b_i at
the start and should hold an animal of type e_i at the end, the
target types a permutation of the start types. Decide whether some
sequence of such moves reaches the target arrangement
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).

The input, per the problemset pdf, is one line of n and m, with
1 <= n <= 4e5 enclosures and 0 <= m <= 4e5 tunnels, then n lines of
b_i and e_i, animal types in 1..1e6 whose targets are a permutation
of the starts, then m tunnel lines x and y with 1 <= x < y <= n and
no pair of enclosures joined twice. The output is possible or
impossible under the pdf's 5 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`R-zoomanagement/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: one triangle of enclosures whose targets are
exactly the starts rotated one step around it, and a single-cycle
component reaches exactly its rotations.

input:

```
3 3
1 4
4 7
7 1
1 2
2 3
1 3
```

expected output:

```
possible
```

Official sample 2, same source: two enclosures joined by their only
tunnel, which is a bridge, and no animal ever crosses a bridge, so
the wanted swap is out of reach.

input:

```
2 1
1 2
2 1
1 2
```

expected output:

```
impossible
```

Recognition: n and m both <= 4e5 under the 5 second limit price one
connectivity pass: a low-link DFS visits 8e5 cells once, and the
per-component verdicts are cycle walks of the same order, so the
whole decide is linear.

The statement's cue is that a move is a rotation around cycles of
the tunnel graph: what any arrangement can reach is decided by how
the enclosures decompose, bridges against 2-edge-connected pieces,
not by planning moves. Problem R is the 2022 face of the component
structure and connectivity family, and the component structure and
connectivity family runs through chapter 09 problem B, chapter 10
problem E, chapter 10 problem H, chapter 13 problem E, and chapter
13 problem G.

Search over arrangements prices out immediately, the target alone
is one of up to (4e5)! permutations, so dropping bridges and
deciding each piece by rotation equality and parity is the only
budget that closes.

No animal ever crosses a bridge, so bridges are dropped and
each 2-edge-connected component is decided alone: a component that is
one simple cycle reaches exactly its cyclic rotations, tested by
cyclic string equivalence, and a component with several cycles
reaches every permutation when some edge lies on two cycles or some
cycle is even, otherwise exactly the even permutations, with the
parity of the required relabeling automatic whenever a type repeats.
Linear in vertices plus edges, per the solutions pdf pages 3 and 4,
problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
Book 8's chapter 39, graph connectivity and decomposition, builds
the bridge-finding and 2-edge-connected decomposition this
drop-bridges step runs on. The six walks find
bridges with one iterative low-link DFS each, then part ways on the
cycle bookkeeping.

The worked run: trace the model on sample 1. The three tunnels 1-2,
2-3 and 1-3 form one component of 3 vertices and 3 edges, no edge
is a bridge, and one simple cycle, a triangle. Walking it from
enclosure 1, the starts read 1, 4, 7 and the targets read 4, 7, 1,
and the target string 471 sits inside the doubled start string
147147 at offset 1, so the wanted arrangement is exactly a one-step
rotation of the animals. The component verdict is possible, it is
the only component, and the trace ends at the printed answer
`possible`.

#diagram([sample 1's triangle with each enclosure's start and target animal, the one-step rotation carrying all three home], length: 12pt, {
  let enc(x, y, n, has, want) = {
    cdraw.circle((x, y), radius: 0.7, fill: luma(225), stroke: luma(120))
    cdraw.content((x, y), n, size: 7pt)
    cdraw.content((x, y - 1.2), [#has to #want], size: 6pt, fill: luma(100))
  }
  enc(2.0, 6.4, [1], [1], [4])
  enc(0.8, 4.0, [2], [4], [7])
  enc(3.2, 4.0, [3], [7], [1])
  cdraw.line((2.0, 6.4), (3.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.2, 4.0), (0.8, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((0.8, 4.0), (2.0, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 6.4), [walk from 1: starts 147, targets 471], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 5.5), [471 inside 147147 at offset 1], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 4.6), [one cycle, no bridge, rotations reach it], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch11/pR.c", first: 252, last: 285, caption: [c, the several-odd-cycles verdict: free only when a tree edge carries two back-edge paths, else even permutations, dup labels absorb parity])

#listing("icpc/samples/src/Ch11/PR.cs", first: 181, last: 205, caption: [c\#, one simple cycle: walk it, then rotation equality as one string contained in the other doubled])

#listing("icpc/samples-go/ch11/pr.go", first: 95, last: 133, caption: [go, carving biconnected blocks off an edge stack: one edge is a bridge, more edges than verts is multi, else cyclic and even or odd])

#listing("icpc/samples-js/src/ch11-pr-zoomanagement.mjs", first: 57, last: 97, caption: [javascript, the low-link DFS with +1/-1 back-edge path marks and even fundamental cycles on Int32Arrays])

#listing("icpc/samples-py/src/Ch11/pr.py", first: 149, last: 189, caption: [python, a second component DFS marks each tree edge with the back edge that owns it, sharing two owners breaks the cactus])

#listing("icpc/samples-lua/ch11_pr.lua", first: 177, last: 214, caption: [lua, the cycle walk collecting both animal strings, then KMP of one inside the other doubled])

The fixture is two triangles sharing vertex 1, enclosures 1-2-3 and
1-4-5, an all-odd cactus: the desired relabeling rotates the animals
of enclosures 1, 2, 3 as one 3-cycle, which is even, so the answer is
possible, and swapping just two animals instead is a single
transposition, odd, and impossible, a variant every suite pins beside
the official four samples. Counts per language: 6 checks in C and
python, 6 facts in the C\# suite, 6 go rows and 6 js blocks, and the
lua module carries a 7th, a pendant bridge keeping its triangle
honest. Animal types are opaque labels that fit a 32-bit int in
every language, so no integer notes here.

#diagram([the fixture: two odd triangles sharing vertex 1, the relabeling chases three animals around one of them], length: 12pt, {
  let v(x, y, t) = {
    cdraw.circle((x, y), radius: 0.42, fill: luma(225), stroke: luma(120))
    cdraw.content((x, y), t, size: 6.5pt)
  }
  v(2.0, 6.6, [1])
  v(0.8, 4.4, [2])
  v(3.2, 4.4, [3])
  v(5.6, 6.6, [4])
  v(4.4, 4.4, [5])
  cdraw.line((2.0, 6.6), (0.8, 4.4), stroke: luma(100))
  cdraw.line((2.0, 6.6), (3.2, 4.4), stroke: luma(100))
  cdraw.line((0.8, 4.4), (3.2, 4.4), stroke: luma(100))
  cdraw.line((2.0, 6.6), (5.6, 6.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((2.0, 6.6), (4.4, 4.4), stroke: luma(100))
  cdraw.line((5.6, 6.6), (4.4, 4.4), stroke: luma(100))
  cdraw.content((1.6, 5.8), [10], size: 6pt, fill: luma(100))
  cdraw.content((2.6, 5.8), [30], size: 6pt, fill: luma(100))
  cdraw.content((2.0, 4.0), [20], size: 6pt, fill: luma(100))
  cdraw.content((4.0, 1.9), [start 10 20 30, target 30 10 20: a 3-cycle, even], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((4.0, 1.0), [the shared vertex never moves an animal across], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 0.3), [bridge-free rotation, possible], size: 6.5pt, anchor: "west", fill: luma(100))
})

== s, bridging the gap

A group of n walkers reaches a river at night carrying one torch.
The old bridge holds at most c walkers at a time and crossing it
needs the torch, every walker has a fixed crossing time, and a group
crosses at its slowest member's pace. Some walker must always carry
the torch back for the next group, and the task is the shortest
total time for everyone to end on the far side
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).
Bridging the Gap is one of the five problem names this finals shares
with the 2023 set: this set's S is 2023's J retold.

The input, per the problemset pdf, is one line of n and c, with
2 <= n <= 1e4 walkers and 2 <= c <= 1e4 bridge capacity, then n
crossing times t_i with 1 <= t_i <= 1e9. The output is the minimum
total crossing time, under the pdf's 4 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`S-bridgingthegap/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and walks through: the two fastest cross for 2,
the fastest returns for 1, the two slowest cross for 10, the
second-fastest returns for 2, and the two fastest cross again for 2,
totalling 17.

input:

```
4 2
1 2 10 5
```

expected output:

```
17
```

Official sample 2, same source, same walkers at capacity 6: everyone
fits in one batch, so the whole group crosses once at the slowest
pace.

input:

```
4 6
1 2 10 5
```

expected output:

```
10
```

Recognition: n <= 1e4 walkers and c <= 1e4 capacity under the 4
second limit price an exact state machine, not a smarter formula:
the (k, g, l) space holds 5e7 to 3.5e8 live states on the judge
secrets, and both shipped engines visit each state once at O(1)
amortized, which is what the limit buys.

The statement's cue is the torch ledger: every crossing and every
return changes who stands where, and the optimum turns on the
contiguous block of banked fast walkers, the cue that the state
must be engineered by hand rather than read off the input. Problem
S is the 2022 face of the dp over an engineered state space
family, and the dp over an engineered state space family spans
chapter 12 problem J, chapter 09 problem J, chapter 10 problem I,
and chapter 13 problem H.

The tempting alternative, Dijkstra over crossing schedules, pays
the same state space again with a log factor on top, and any
n-by-l cell grid dies on memory alone, terabytes near c = n/2, so
the swept machine with reachability-clamped caps is the shape that
fits.

The exact state, with the times sorted ascending so person 0 is the
fastest, is (k, g, l): the k slowest are delivered, the fast walkers
on the far side are exactly the contiguous block g..g+l-1, the torch
is near, and g canonicalizes to 1 whenever l = 0. Four transitions
move it. The escorted batch sends j >= 1 of the slowest plus
e = c - j escorts with e > g, the e fastest near-side walkers with
person 0 among them, at cost t[n-k-1] for the batch and t[0] for the
escort's return, landing at (k+j, 1, l+e-1). The pure slow batch
sends j of the slowest with j <= min(c, n-k-l) and the fastest
banked walker t[g] brings the torch back, which needs l >= 1, at
cost t[n-k-1] + t[g], landing at (k+j, g+1, l-1). The pure fast
batch sends j > g of the fastest near-side walkers at cost
t[l+j-1] + t[0], banking them into (k, 1, l+j-1). And once
n-k-l <= c, everyone left crosses at the slowest remaining pace
t[n-k-1] and the instance is done. The solutions pdf page 4 sketches
a quadratic dp over a machine of this shape, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf],
and this pinned state and transition set was validated against an
exhaustive dijkstra over more than 3000 random small instances with
zero mismatches, plus both official samples. Two things the sketch
does not carry. First, the g dimension is load-bearing: collapsing
to (k, l) measurably under- and over-counts against brute force.
Second, the editorial's n-squared-over-c bound does not hold for the
exact machine on shuttle instances, which bank on the order of n
walkers for any c, so the l dimension runs its full range and no
cell grid survives the memory rule. The shipped engines are two
shapes of the same recurrence, a pull-based row sweep with lazy
window heaps in C and C\#, and a diagonal sweep s = k + l with
sliding-window materialization in go, javascript, python, and lua.

The worked run: trace the model on sample 1. The times sorted
ascending are t = 1, 2, 5, 10, person 0 the fastest, and the
machine starts at (k, g, l) = (0, 1, 0), torch near, nothing
delivered. The pure fast batch sends j = 2 of the fastest, persons
0 and 1, at cost t[l + j - 1] + t[0] = t[1] + t[0] = 2 + 1 = 3, the
cross at pace 2 and person 0's return at pace 1, landing at
(0, 1, 1) with person 1 banked far side. The pure slow batch then
sends j = 2 of the slowest, persons 2 and 3, at t[n - k - 1] =
t[3] = 10, with banked walker t[g] = t[1] = 2 bringing the torch
back, cost 12, landing at (2, 2, 0). Now n - k - l = 4 - 2 - 0 =
2 <= c, so the finish transition applies: everyone left crosses at
t[n - k - 1] = t[1] = 2. The total is 3 + 12 + 2 = 17, and
the trace ends at the printed answer `17`.

#table(
  columns: (auto, 1.1fr, 1.6fr, auto, auto),
  inset: 4pt,
  table.header([*state*], [*transition*], [*who moves*], [*cost*], [*lands*]),
  [(0, 1, 0)], [pure fast, j = 2], [persons 0, 1 cross, person 0 returns], [2 + 1], [(0, 1, 1)],
  [(0, 1, 1)], [pure slow, j = 2], [persons 2, 3 cross, t[1] returns], [10 + 2], [(2, 2, 0)],
  [(2, 2, 0)], [finish, 2 <= c], [persons 0, 1 cross], [2], [done],
)

#listing("icpc/samples-c/src/Ch11/pS.c", first: 213, last: 262, caption: [c, the per-cell pull: seed, pure-fast column heap, escorted row heap, per-g pure-slow buckets, then the pareto front of (d, g)])

#listing("icpc/samples/src/Ch11/PS.cs", first: 360, last: 398, caption: [c\#, the same pull with positions and spans packed into one int, FIFO rings for the monotone offer streams])

#listing("icpc/samples-go/ch11/psfast.go", first: 331, last: 365, caption: [go, the diagonal expansion: shuttle completion priced from stride prefix sums, pure-slow fan-out as one point write])

#listing("icpc/samples-js/src/ch11-ps-bridgingthegap.mjs", first: 253, last: 297, caption: [javascript, finalize each column into g-prefix minima, then expand every live g with the hoisted shuttle cost, all on flat typed arrays])

#listing("icpc/samples-py/src/Ch11/ps.py", first: 265, last: 306, caption: [python, the column walk over a bitmask of live g slots, finish and pure-slow emission per bit])

The lua twin of the diagonal engine is a year-local module,
`ch11_psweep`, printed with the year's helpers in the section at
the chapter top.

The fixture is 4 walkers, capacity 3, times 1 2 5 10: the two
fastest cross for 2, the fastest walks back for 1, and the remaining
three cross together for 10, totalling 13 against 16 for shipping
the three fastest first. Every suite asserts 13 on that input, plus
the official samples 17 and 10 and the crafted pair 3 7 crossing at
capacity 2 for 7. Totals reach 1e4 times 1e9 = 1e13, which divides
the languages: int64 in C, C\#, and go, lua's 64-bit integer
subtype, exact but boxed python ints, and javascript numbers, exact
below 2^53 and stored here in Float64Array cells at 1e13 with room
to spare.

That same state space is the chapter's hardest measured finding, a
ratified and documented wall in two languages. On the 104 judge
cases the go engine finishes in roughly 11 s at the worst and
javascript in 72.8 s. Lua carries a faithful port of the go engine,
bit-identical on 4670 randoms plus brute force, a restructured
future-buffer-ring variant, and an exact lazy-heap port of the C
engine, validated against a bitmask dijkstra on 3000 randoms and
against C on 3320 cases, and all three share the wall: secret-003
(10000x2) at 142 s, secret-010 (10000x3) at 324 s, secret-013
(10000x8) at 417 s, and secret-042 (9983x18) at 286 s, against the
120 s per-case cap, 1.5 to 3.2 times over. Instrumentation over all
104 cases counts live states from 5e7 at c = 2 to 3.5e8 at c = 18
and 61, with maxL = n - 1, so the l cap never prunes judge data and
no design lever exists: the state space is the work, and go walks
the same states roughly 11 s worth. Python is the same engine
family with a different mechanism: judged 57 of 104 with 47
timeouts and zero wrong answers, every timeout an n = 1e4 secret
with c in [3, 500], while the c = 2 classic recurrence and every
c >= 1000 shape finish comfortably. The deciding mechanism is
CPython integer boxing: totals pass the 30-bit fast-int range, so
every sweep operation allocates a boxed multi-digit integer, and
the sweep becomes allocation-bound where lua's unboxed int64 and
go and javascript native arithmetic are not. The 47 versus 4
timeout asymmetry on the same states is the measured evidence that
the wall is the language's arithmetic model, not the algorithm.
The C\# twin also carries a post-landing allocation fix, 9de5851,
dead-bucket reclaim plus ArrayPool rentals with no algorithm
change: peak working set 3.6 GB on the heaviest cases against the
C twin's 3.2 to 3.4 GB, the engine family's live-data floor, CPU
95 to 129 s loaded against C's 58 to 99 s, the JIT codegen gap,
and 104 of 104 judged after the fix.
Both walls are terminal, recorded here as evidence rather than
todo. Two calibration scars also belong on the record: the hash and
dijkstra engine measured over 100 s at n = 1e4 with 9.5M distinct
states in the first 24k cells at c = 1000, and any cell grid
violates the 4 GB rule near c = n/2, where judge case 10000x5259
would want terabytes. The g chain rule g <= l + 1 bounds the g
ladder, and an unclamped one once produced a 49 GB scratch table.
Random instances keep g <= 4, but the adversarial judge cases push
g to c - 1 with fronts about 48 wide, so every engine carries g
exactly. The scar's lesson is narrower: never size a table by an
unclamped cap, clamp it to the reachable bounds min(G, L + 1). The
pull engines in C and C\# do that outright, deriving their window
bounds from reachability, while the four diagonal engines in go,
javascript, python, and lua cut depth at a measured 120 and cap l
at 4n/c + 8, raised to 3c + c/2 + 64 when n >= 4c, clamps validated
on the judge shapes rather than guessed.

#diagram([the fixture's three crossings on a timeline, torch return walks dashed], length: 12pt, {
  let bar(x, w, y, t, fill: luma(225)) = {
    cdraw.rect((x, y), (x + w, y + 0.7), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.35), t, size: 6pt)
  }
  cdraw.line((1.0, 0.8), (1.0, 7.0), stroke: luma(120), mark: (end: ">"))
  cdraw.content((0.7, 7.5), [0], size: 6pt, fill: luma(100))
  bar(1.0, 4.0, 5.8, [1 and 2 cross, 2], fill: luma(232))
  bar(5.0, 2.0, 4.6, [1 returns, 1], fill: luma(245))
  bar(7.0, 10.0, 3.4, [1, 5, 10 cross, 10], fill: luma(232))
  cdraw.line((5.0, 6.5), (7.0, 3.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((9.6, 5.6), [dashed: torch return], size: 6pt, fill: luma(100))
  cdraw.content((1.3, 1.6), [total 13, capacity 3 spent on the last batch], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((1.3, 0.5), [state (k, g, l) machine, both engine shapes agree here], size: 6.5pt, anchor: "west", fill: luma(100))
})

== t, carl's vacation

Carl the ant returns for a third finals walk, this time between the
apexes of two right square pyramids standing on a common plane, and
the desert heat rules out everything but the surfaces: the path may
travel over the pyramids' faces and the plane and nothing else. Each
pyramid is given by one directed edge of its square base, with the
pyramid's body on the left of that direction, plus its height, and
the apex sits directly above the base center. The two base squares
may touch but their interiors do not overlap. Print the shortest
surface distance between the apexes
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).
Carl's Vacation is one of the five problem names this finals shares
with the 2023 set: this set's T is 2023's D retold.

The input, per the problemset pdf, is two lines of five integers
each, x1 y1 x2 y2 h: the directed base edge and the height. The
coordinates lie within 1e5 in absolute value, the edge's endpoints
are distinct, h is between 1 and 1e5, and the two bases intersect in
zero area. The answer carries an absolute or relative error of at
most 1e-6, printed to nine decimals by the judge, under the pdf's
1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`T-carlsvacation/sample-1.in` and `sample-1.ans`, the only sample
this problem carries and the pair that forced the completion below:
the optimum enters the second pyramid exactly at a base corner,
where no unfold-straight is valid.

input:

```
0 0 10 0 4
9 18 34 26 42
```

expected output:

```
60.866649532
```

Recognition: the coordinates stop at 1e5 and the limit at 1 second,
and the budget is candidate count, not per-candidate work: 16
edge-pair unfold-straights, 8 one-corner chains and 16 two-corner
chains, each leg minimized by a grid sweep plus ternary refinement
in a few hundred probes, tens of thousands of predicate calls in
total, thousands of times inside budget.

The statement's cue is shortest surface path: on unfoldable
surfaces the optimum is a straight line in some unfolding, so the
only question is which finitely many hinge and corner
configurations attain it, the cue that turns a continuous path
search into enumeration over unfold-straights and corner bends.
Problem T is the 2022 face of the geometric critical-point
enumeration family, and geometric critical-point enumeration is the
shared shape of chapter 12 problem D, chapter 08 problem A, chapter
08 problem D, chapter 09 problem E, and chapter 09 problem G.

The tempting alternative, a dense mesh with Dijkstra over it,
prices out at 1e6 nodes before any accuracy argument and still
resolves the path only to 1e-3 against the 1e-6 tolerance, while
the closed candidate set certifies every digit.

For each of the 16 base-edge pairs the solver rotates each apex about its
edge's line down onto the plane, and the straight segment between the
two landings is a candidate whenever it crosses both hinge edges in
order and its open middle misses both square interiors. The
solutions pdf pages 4 and 5, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf],
stop at that sketch, and the sketch alone
is incomplete: the official sample's optimum enters pyramid 2 exactly
at a base corner and no unfold-straight is valid there, so the
shipped solvers add corner bends, paths through one or two of the 8
base corners with each end leg minimized independently by a grid
sweep plus ternary refinement under segment validity, plus the 16
two-corner chains. The completion was validated against a dense
two-parameter sweep reference on 60 random pyramid pairs with a
worst difference of 4e-14. Book 8's chapter 36, numerical methods,
builds the ternary-search refinement those corner legs are minimized
with. Every predicate is a cross product from
the year-local geo kit, endpoints shrink by a relative 1e-9 before
the crossing tests to dodge endpoint-rounding artifacts, and the
minimum prints at nine decimals.

The worked run: trace the model on sample 1. Pyramid 1 is the
square on (0,0) to (10,0) with height 4, apex over (5, 5), and
pyramid 2 the square on the directed edge (9,18) to (34,26) with
height 42, corners (9,18), (34,26), (26,51), (1,43), apex over the
center (17.5, 34.5). Every one of the 16 edge-pair
unfold-straights fails validity, each straight that leaves pyramid
1's near faces runs through pyramid 2's interior, so the optimum
bends at a corner, and the winner is the one-corner chain through
(9,18). Leg 1 crosses pyramid 1's back face: reflecting the apex
across the back edge line, offset sqrt(5^2 + 4^2) = sqrt(41) =
6.403, lands it at (5, 10 - sqrt(41)), and the straight from there
to (9,18) is sqrt(4^2 + (8 + sqrt(41))^2) = sqrt(223.450) =
14.948244, exiting the back edge inside the segment at (6.778, 10).
Leg 2 climbs pyramid 2's face on the given edge: unfolding apex 2
about that edge, from the edge center (21.5, 22) the slant
sqrt(13.125^2 + 42^2) = 44.004 lands at (34.911, -19.909), and the
corner-to-unfolded-apex straight is sqrt(25.911^2 + 37.909^2) =
sqrt(2108.500) = 45.918406. The plane middle is the corner itself,
so the path totals 14.948244 + 45.918406 = 60.866650, and
the trace ends at the printed answer `60.866649532`.

#diagram([sample 1's one-corner winner: down pyramid 1's back face, across to the corner (9,18), up pyramid 2's given-edge face], length: 12pt, {
  cdraw.rect((2.0, 2.0), (5.0, 5.0), fill: luma(238), stroke: luma(120), radius: 0.02)
  cdraw.content((3.5, 3.5), [apex 1], size: 6pt, fill: luma(100))
  cdraw.content((3.5, 1.4), [pyramid 1, h = 4], size: 6pt, fill: luma(100))
  let pb = ((9.6, 5.8), (13.8, 7.1), (12.6, 10.3), (8.4, 9.0))
  cdraw.line(pb.at(0), pb.at(1), stroke: luma(120))
  cdraw.line(pb.at(1), pb.at(2), stroke: luma(120))
  cdraw.line(pb.at(2), pb.at(3), stroke: luma(120))
  cdraw.line(pb.at(3), pb.at(0), stroke: luma(60), width: 0.7)
  cdraw.content((11.0, 8.4), [apex 2], size: 6pt, fill: luma(100))
  cdraw.content((15.0, 11.0), [pyramid 2, h = 42], size: 6pt, fill: luma(100))
  cdraw.circle((4.3, 5.0), radius: 0.12, stroke: luma(20), fill: white)
  cdraw.content((4.3, 5.5), [exit (6.778, 10)], size: 6pt, anchor: "south", fill: luma(100))
  cdraw.line((3.5, 3.5), (4.3, 5.0), stroke: luma(60))
  cdraw.line((4.3, 5.0), (9.6, 5.8), stroke: luma(60))
  cdraw.line((9.6, 5.8), (11.0, 8.4), stroke: luma(60))
  cdraw.circle((9.6, 5.8), radius: 0.14, stroke: luma(20), fill: white)
  cdraw.content((9.6, 5.1), [corner (9,18)], size: 6pt, anchor: "north", fill: luma(100))
  cdraw.content((5.6, 4.4), [leg 1 = 14.948244 over the back face], size: 6pt, anchor: "south", fill: luma(100))
  cdraw.content((5.9, 5.2), [plane to the corner], size: 6pt, anchor: "north", fill: luma(100))
  cdraw.content((11.6, 7.4), [leg 2 = 45.918406 up the given edge], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((2.0, 0.4), [total 60.866649532, the corner entry no unfold-straight reaches], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch11/pT.c", first: 97, last: 136, caption: [c, best_leg: 1024-point grid over the edge, then ternary refinement, validity checked per sample])

#listing("icpc/samples/src/Ch11/PT.cs", first: 100, last: 141, caption: [c\#, MinLeg: the unconstrained convex optimum first, then run detection with bisected feasible edges])

#listing("icpc/samples-go/ch11/pt.go", first: 115, last: 149, caption: [go, unfoldLen: both hinge crossings in order, the shared-hinge case, then the middle cleared])

#listing("icpc/samples-js/src/ch11-pt-carlsvacation.mjs", first: 129, last: 168, caption: [javascript, the 16 edge pairs times both landing sides, crossing parameters solved by cross products])

#listing("icpc/samples-py/src/Ch11/pt.py", first: 79, last: 122, caption: [python, the same guarded grid-plus-ternary leg, infeasible samples priced at 1e30])

#listing("icpc/samples-lua/ch11_pt.lua", first: 87, last: 134, caption: [lua, best_leg over flat scalars, no table allocation in the sweep])

The crafted fixture is two squares twenty units apart, bases [0,10] and
[30,40] on the x axis with heights 4: the apexes land at
10 - sqrt(41) and 30 + sqrt(41) after unfolding across the facing
edges, and the horizontal candidate is 20 plus twice sqrt(41) =
32.806248475. Every suite asserts that value, plus the official
sample 60.866649532, whose optimum is the corner entry that forced
the completion, and the crafted close pair at 15.211102551, all
tolerance-checked at 1e-6, three checks per language. Input
coordinates are integers and everything past parsing is double, so
the languages diverge nowhere numerically worth noting.

#diagram([the fixture: both squares, the unfolded apexes outside them, one straight candidate crossing both hinges], length: 12pt, {
  let sq(x, t) = {
    cdraw.rect((x, 2.2), (x + 3.2, 5.4), fill: luma(238), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 1.6, 6.0), t, size: 6pt, fill: luma(100))
  }
  sq(2.0, [pyramid 1, h = 4])
  sq(11.0, [pyramid 2, h = 4])
  cdraw.circle((0.6, 3.8), radius: 0.28, fill: luma(200), stroke: luma(100))
  cdraw.content((0.6, 2.9), [apex1'], size: 6pt, fill: luma(100))
  cdraw.circle((15.6, 3.8), radius: 0.28, fill: luma(200), stroke: luma(100))
  cdraw.content((15.6, 2.9), [apex2'], size: 6pt, fill: luma(100))
  cdraw.line((0.88, 3.8), (15.32, 3.8), stroke: luma(60))
  cdraw.content((8.1, 4.3), [the straight candidate], size: 6pt, fill: luma(100))
  cdraw.content((5.2, 1.6), [20 + 2 sqrt(41) = 32.806248475], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((5.2, 0.7), [slant sqrt(4^2 + 5^2) = sqrt(41) on each unfolding], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 0.1), [corner bends cover what no unfold-straight reaches], size: 6.5pt, anchor: "west", fill: luma(100))
})

== u, toy train tracks

The Toy Train Tracks Construction Company sells exactly two piece
shapes, straight segments and 90-degree curves, and every piece
occupies one cell of a square grid, rotatable in quarter turns. A
proper course is a single connected closed loop that never
intersects itself. Customers arrive with a bag of s straights and c
curves and want the largest course their bag allows: build the
longest valid loop and print it
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).

The input, per the problemset pdf, is one line with s and c,
0 <= s <= 1e5 straight pieces and 4 <= c <= 1e5 curves. The output
is one string read off a single traversal of the loop, S for each
straight piece, L for a left curve, R for a right curve, and any
loop of maximal length is accepted, under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`U-toytraintracks/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints beside its picture of the layout: all four
straights and all twelve curves spend, sixteen pieces, and the
judge's loop is one of several equally long maxima.

input:

```
4 12
```

expected output:

```
LSRLLRLSLSRLLSRL
```

Official sample 2, same source: the odd straight wastes, one curve
wastes, and the four remaining curves close the unit ring.

input:

```
1 5
```

expected output:

```
LLLL
```

Recognition: s and c each stop at 1e5 under the 1 second limit, and
the output itself is at most s + c = 2e5 characters, so the budget
is a formula plus one emission pass, and anything that searches
over layouts is already over.

The statement's cue is the largest course their bag allows, build
it and print it: a maximum with a printed witness is the classic
shape of a closed-form characterization, prove exactly which totals
are achievable, then emit one canonical loop. Problem U is the 2022
face of the constructive closed-form characterization family, and
the constructive closed-form characterization family holds chapter
12 problem B and chapter 13 problem J.

Search prices out at 4^200000 turn sequences before
self-avoidance even enters, and a dp over grid shapes has no budget
either, so the achievable-total table plus the canonical strings is
the only shape that closes.

Odd budgets waste one piece, s halves to an even count. With no
usable straights the achievable totals are exactly 4 and every
multiple of 4 from 12 up, built from the unit LLRLLR plus LR
repeated, taken twice: totals 6, 8, 10, 14, 18 are impossible, since
a closed walk nets +-4 quarter turns and self-avoidance kills every
candidate below 12 except 4, verified by exhaustive search through
length 18. The constructions follow the solutions pdf pages 5 and 6,
problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
With two or more usable straights, every piece spends:
the curve budget drops only to even, c' = c - (c mod 2), and the
canonical emission joins two mirrored halves. That corrected budget
is a judge-verified fix, not a first draft: the earlier rule that c'
must be a multiple of 4 rejects 22 of the 75 official answers, every
s >= 2 case with c mod 4 in {2, 3}, while nine of them, secrets 34,
38, 42, 46, 50, 54, 64, 67, and 69, actually made the then-shipped
solvers emit short, silently validating suboptimal loops as passes,
and the corrected budget accepts 75 of 75, with the obsolete
`2 6` to LLSLLS emission as the discriminant. The odd curve count
4q + 6 is the porting trap, found twice in the C\# stream: it splits
asymmetrically, X S LL swap(X) with the straight split a = 1 then
sp/2 - 1 and sp/2 on the two arms, and a naive symmetric split
undercounts straights by 2. Every case also runs a grid-walking
validator, closed, self-avoiding, within budget, and the go suite
sweeps it over 544 budgets.

The worked run: trace the model on sample 1. The bag is s = 4
straights and c = 12 curves, c is already even so c' = 12, and with
two or more usable straights every piece spends, a total of 16. The
printed witness is one of the equally long maxima: walking
LSRLLRLSLSRLLSRL from the origin heading east, turn then step,
visits 16 distinct cells and closes at the origin, 8 lefts and 4
rights netting +4 quarter turns over 4 straights, a closed
self-avoiding loop that spends the whole bag, and
the trace ends at the printed answer `LSRLLRLSLSRLLSRL`.

#diagram([sample 1's sixteen-cell loop walked from the origin heading east, 8 lefts, 4 rights, 4 straights, every piece spent], length: 12pt, {
  let cell(x, y) = cdraw.rect((x, y), (x + 1.0, y + 1.0), fill: luma(232), stroke: luma(140), radius: 0.02)
  cell(3.0, 1.5)
  cell(3.0, 2.5)
  cell(4.0, 2.5)
  cell(4.0, 3.5)
  cell(3.0, 3.5)
  cell(3.0, 4.5)
  cell(2.0, 4.5)
  cell(1.0, 4.5)
  cell(1.0, 3.5)
  cell(1.0, 2.5)
  cell(0.0, 2.5)
  cell(0.0, 1.5)
  cell(1.0, 1.5)
  cell(2.0, 1.5)
  cell(2.0, 0.5)
  cell(3.0, 0.5)
  cdraw.content((3.4, 0.2), [start, heading east], size: 6pt, anchor: "north", fill: luma(100))
  cdraw.line((3.2, 0.7), (3.8, 0.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.0, 4.6), [16 distinct cells, closed], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 3.7), [8 lefts, 4 rights, net +4 quarter turns], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 2.8), [4 straights + 12 curves, all spent], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch11/pU.c", first: 55, last: 98, caption: [c, the straight forms: mirrored halves when 4 divides c', the asymmetric 4q+6 split otherwise])

#listing("icpc/samples/src/Ch11/PU.cs", first: 24, last: 61, caption: [c\#, the same two forms, StringBuilder halves joined back to back])

#listing("icpc/samples-go/ch11/pu.go", first: 60, last: 106, caption: [go, the achievable count the table pins and the grid walker that validates every emitted loop])

#listing("icpc/samples-js/src/ch11-pu-toytraintracks.mjs", first: 16, last: 40, caption: [javascript, the whole solve: even c' spends fully, one string per shape])

#listing("icpc/samples-py/src/Ch11/pu.py", first: 12, last: 31, caption: [python, the same emission in five string expressions])

#listing("icpc/samples-lua/ch11_pu.lua", first: 80, last: 108, caption: [lua, the validator: walk L as turn-then-step, assert closed, distinct cells, budget])

The fixture is 0 straights and 12 curves, the full ring LLRLLRLLRLLR:
walking it from the origin heading east, 8 lefts and 4 rights net +4
quarter turns and the twelve cells are distinct. Every suite asserts
that string, plus the official `1 5` collapsing to LLLL, the
corrected `2 6` spending all six curves as LSLLRLLS for a total of
8, and `4 12` as LSLRLRLSLSLRLRLS. Counts stay under 1e5 pieces, so
no language diverges on integers.

#diagram([the fixture's twelve-cell ring, start and heading marked], length: 12pt, {
  let cell(x, y) = cdraw.rect((x, y), (x + 1.0, y + 1.0), fill: luma(232), stroke: luma(140), radius: 0.02)
  cell(2.0, 6.0)
  cell(1.0, 6.0)
  cell(1.0, 5.0)
  cell(1.0, 4.0)
  cell(2.0, 4.0)
  cell(2.0, 3.0)
  cell(3.0, 3.0)
  cell(3.0, 4.0)
  cell(3.0, 5.0)
  cell(4.0, 5.0)
  cell(4.0, 6.0)
  cell(3.0, 6.0)
  cdraw.content((2.5, 7.3), [start, heading east], size: 6pt, fill: luma(100))
  cdraw.line((2.2, 6.9), (2.8, 6.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.0, 5.4), [walk reads L L R L L R, taken twice], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 4.5), [8 lefts, 4 rights, net +4 quarter turns], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 3.6), [twelve distinct cells, closed], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.0, 2.7), [0 12 spends every curve], size: 6.5pt, anchor: "west", fill: luma(100))
})

== v, three kinds of dice

The Buffett and Gates dice story: pick from three intransitive dice
and the second chooser always wins. A die is any collection of one
or more faces, each face a positive integer, with one face drawn
uniformly per roll. When two dice roll against each other, the
higher face earns its die 1 point and equal faces earn each die half
a point, and score(D, D') is the expected points D earns per roll,
so D has an advantage over D' when score(D, D') > 1/2 and the dice
tie at exactly 1/2. Given two dice where one has an advantage over
the other, whichever order they are listed in, the advantaged one is
D1. Among all dice D3 that have an advantage over or tie with D1,
report the lowest score D3 can manage against D2, and among all D3
that D2 has an advantage over or ties with, report the highest score
D3 can manage against D1: a first value under 1/2 beside a second at
or above it is an intransitive trio. The two answers may come from
different dice
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).
Three Kinds of Dice is one of the five problem names this finals
shares with the 2023 set: this set's V is 2023's C retold.

The input, per the problemset pdf, is two lines, one per die in
either order, each holding its face count n with 1 <= n <= 1e5 and
then the n face values, each between 1 and 1e9, and the pdf promises
one of the two really has the advantage. The output is the two
scores on one line with an absolute error of at most 1e-6, under the
pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`V-threekindsofdice/sample-1.in` and `sample-1.ans`, the same pair
the problems pdf prints: the 6-face die listed first loses the
matchup, winning only 8 of 18 pairings, so the advantaged D1 is the
3-face die listed second, the trap that pins the order test.

input:

```
6 1 1 6 6 8 8
3 2 4 9
```

expected output:

```
0.291666667 0.750000000
```

Official sample 2, same source: the 4-face die wins 10 of 12
pairings and is D1, and both queries land at one half.

input:

```
4 9 3 7 5
3 4 2 3
```

expected output:

```
0.500000000 0.500000000
```

Recognition: both dice carry at most 1e5 faces under the 1 second
limit. Doubled score coordinates make every achievable point an
integer pair, the candidate face values number about 2n1 + 2n2,
4e5 of them, and a sort plus one monotone-chain hull costs about
4e6 comparisons, two orders of magnitude inside budget.

The statement's cue is the pair of extrema over all dice D3 subject
to a tie-or-beat constraint: choosing D3 is choosing a distribution
over face values, so both queries are constrained optima over one
achievable set, the cue that the set is a convex hull and each
query a halfplane cut on it. Problem V is the 2022 face of the
convex hull of achievable points family, and chapter 12 problem C
is the other convex hull of achievable points twin.

Enumerating dice prices out at unbounded multisets over values to
1e9, and a linear program discretized over every value still pays
1e9 weights, so the 4e5-candidate hull is the only budget that
closes.

Die D1 beats die D2, and the input may list them in either order, so
the first move is detecting the advantage by the exact pairwise
score, doubled to 2 per win and 1 per tie, since the official
sample 1 lists the winning die second. A D3 face showing v earns D1
an expected S1(v) = wins plus half the ties, likewise S2(v) against
D2, and choosing D3 is choosing a distribution over face values, so
the achievable average pairs are exactly the convex hull of the
points (S1(v), S2(v)). Part 1 maximizes the average against D2
subject to tying or beating D1, the hull's highest y at x <= n1/2,
and part 2 minimizes the average against D1 subject to D2 tying or
beating D3, the leftmost x at y >= n2/2, both read off the hull with
exact edge interpolation, and the score is 1 - avg/n, the model on
the solutions pdf page 6, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
The candidate face values are a
judge-corrected detail: for each distinct union value u the solver
generates both u and u + 1, plus one below the minimum when that
stays positive and one past the maximum, because S1 and S2 step at
each die's own thresholds. All coordinates double, so half-integer
expectations stay exact integers on the hull and floats appear only
in the final division and print.

The worked run: trace the model on sample 1. The 6-face die wins
only 8 of 18 pairings against the 3-face die, 8/18 = 4/9 < 1/2, so
D1 is the listed-second die (2, 4, 9) and D2 is (1, 1, 6, 6, 8, 8).
A D3 face showing v earns the doubled integers X(v) = 2 wins + tie
against D1 and Y(v) against D2, and the candidates run v = 1 to 10,
the value 0 below the union minimum dropped because faces are
positive. The upper hull of the ten points has three vertices,
(0, 0) at v = 10, (2, 8) at v = 5 and (6, 10) at v = 1. Part 1
lets D3 tie D1, X <= n1 = 3, and the hull's best Y sits on the
edge from (2, 8) to (6, 10): at X = 3 it reads Y = 8.5, witnessed
by the die (5, 5, 5, 1), which ties D1 at exactly 1/2 and holds D2
to 17/24, so score(D3, D2) = 1 - 8.5/12 = 7/24. Part 2 lets D2 tie
D3, Y >= n2 = 6, and the hull's lowest X sits on the edge from
(0, 0) to (2, 8) at X = 1.5, witnessed by (5, 5, 5, 10), which
ties D2 at 1/2 and loses only 1/4 to D1, so score(D3, D1) =
1 - 1.5/6 = 3/4, and the trace ends at the printed answer
`0.291666667 0.750000000`.

#table(
  columns: (auto, auto, auto, 1.3fr),
  inset: 4pt,
  table.header([*face v*], [*X(v)*], [*Y(v)*], [*hull place*]),
  [1], [6], [10], [vertex],
  [2], [5], [8], [below the top edge],
  [3], [4], [8], [below the top edge],
  [4], [3], [8], [below the top edge],
  [5], [2], [8], [vertex],
  [6], [2], [6], [inside],
  [7], [2], [4], [inside],
  [8], [2], [2], [inside],
  [9], [1], [0], [inside],
  [10], [0], [0], [vertex],
)

#listing("icpc/samples-c/src/Ch11/pV.c", first: 141, last: 186, caption: [c, the upper hull over doubled points, then both queries with edge-crossing interpolation])

#listing("icpc/samples/src/Ch11/PV.cs", first: 49, last: 81, caption: [c\#, candidate generation: each distinct value contributes its tie point and, across a gap, its strict point])

#listing("icpc/samples-go/ch11/pv.go", first: 99, last: 142, caption: [go, both hull queries as edge walks over the full monotone chain, crossings interpolated as floats])

#listing("icpc/samples-js/src/ch11-pv-threekindsofdice.mjs", first: 35, last: 49, caption: [javascript, the advantage test: a merge-counted doubled score decides which die is D1])

#listing("icpc/samples-py/src/Ch11/pv.py", first: 76, last: 113, caption: [python, the upper hull keeping right turns, then the peak and the crossing edge])

#listing("icpc/samples-lua/ch11_pv.lua", first: 117, last: 158, caption: [lua, the hull over parallel x and y arrays sorted through an index table])

The fixture is D1 = (2, 6) against D2 = (1, 1): every candidate
point lies under the hull edge from (0, 0) to (2, 1), so the best
D3 that ties D1 still scores 0.75 against D2, witnessed by the die
(1, 7), and part 2 forces all-ones, which loses every matchup
against D1, for 0. Every suite asserts `0.750000000 0.000000000` on
that input, tolerance-checked at 1e-6, and the C, C\#, javascript,
python, and lua suites also pin both official samples,
`0.291666667 0.750000000` and `0.500000000 0.500000000`; the go
tolerance table carries the fixture alone, its three rows for t and
one for v covering the family's float side.

#diagram([the fixture's (S1, S2) points, the hull, and the two query lines], length: 12pt, {
  let pt(x, y, t) = {
    cdraw.circle((x, y), radius: 0.22, fill: luma(180), stroke: luma(100))
    cdraw.content((x, y + 0.55), t, size: 6pt, fill: luma(100))
  }
  pt(2.0, 2.5, [(2,1)])
  pt(4.0, 1.2, [(1.5,0)])
  pt(6.5, 0.6, [(1,0)])
  pt(9.0, 0.6, [(0.5,0)])
  pt(11.5, 0.6, [(0,0)])
  cdraw.line((11.5, 0.6), (2.0, 2.5), stroke: luma(60))
  cdraw.line((0.8, 2.15), (13.6, 2.15), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((13.8, 2.15), [x = n1/2], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.line((5.2, 0.2), (5.2, 3.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((5.2, 3.7), [y = n2/2], size: 6pt, fill: luma(100))
  cdraw.content((0.8, -0.7), [doubled coordinates keep every hull vertex integral], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, -1.6), [part 1 rides the dashed row, part 2 the dashed column], size: 6.5pt, anchor: "west", fill: luma(100))
})

== w, riddle of the sphinx

The sphinx of Thebes asked Oedipus a riddle about legs. This problem
hands the riddle to us in reverse. An axex, a basilisk, and a
centaur stand before a sphinx, and their leg counts are unknown
nonnegative integers we may not look up. The sphinx grants exactly
five question rounds, each asking how many legs some number of the
creatures have in total, and at most one of her five answers is an
outright lie we cannot identify in advance. Name the three leg
counts
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).
Riddle of the Sphinx is one of the five problem names this finals
shares with the 2023 set: this set's W is 2023's A retold, and the
two years' judge files are byte-identical across all 50 cases. The
interaction, laid out by the problemset pdf, is line based: each
round we write `a b c` with each of a, b, c between 0 and 10, the
question a axexes plus b basilisks plus c centaurs, and one integer
r between 0 and 1e5 comes back as her answer, and after the fifth
reply we print `la lb lc`, all under the pdf's 2 second limit.

The judge data scripts that interaction rather than piping it, so
each `.in` file is a four-line driver spec and every `.ans` file is
empty, 0 bytes: an interactive runner spawns the solver, answers its
five questions, and checks only the final line, which is why W can
never byte-diff. Official sample 1, reprinted byte for byte from
`W-riddleofthesphinx/sample-1.in`, the layout read in full below:

input:

```
fixed
4 4 4
1 1
4 4 4
```

Line 2 is the true triple, here (4, 4, 4), line 3 lies on the second
round with delta +1, so the question (0,1,0) draws 5 instead of 4,
and line 4 repeats the truth, so the runner must see `4 4 4`
printed. Sample 2 carries legs (0, 42, 2024) with delta -6241, so
scripted answers may go negative.

Recognition: five rounds and answers up to 1e5 under the 2 second
limit make the budget trivial, six exclusion hypotheses each solved
by Cramer's rule on a 3 by 3 system, microseconds of work, so the
whole difficulty is the model, not the cost.

The statement's cue is at most one of her five answers is an
outright lie we cannot identify in advance: the consistent world is
recovered by excluding each suspect row in turn and keeping the one
hypothesis whose survivors all agree, the cue of a faulty-oracle
consistency problem. Problem W is the 2022 face of the consistency
under a faulty oracle family, and consistency under a faulty oracle
ties chapter 12 problem A and chapter 13 problem D together.

The tempting alternative, spending rounds hunting the lie before
naming legs, breaks the five-question budget the deduction needs,
and brute force over leg triples is (1e5)^3 = 1e15 candidates, so
the exclusion machine is the only shape that closes.

The sphinx answers five questions of the form (a, b, c) with the
dot product of the question and the three leg counts, and at most
one answer is an arbitrary lie. The
five questions (1,0,0), (0,1,0), (0,0,1), (1,1,1), (1,2,3) have the
property that any three are linearly independent, so for each
exclusion hypothesis, the lie hit round k or there is no lie, some
three surviving rows determine the leg counts by Cramer's rule, and
exactly one hypothesis leaves a system that also satisfies every
other surviving row, the argument on the solutions pdf page 7, problem
at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
The
pure core is `deduce(answers)`, answers in, legs out, trying each
exclusion hypothesis and returning the surviving triple. The judge
data scripts the interaction over four lines: line 2 carries the
TRUE leg counts, line 3 the 0-based lying round, 5 meaning never,
plus an additive delta, and line 4 alternate leg counts. Every
answer is computed truthfully from line 2 except the lying round,
which she answers from the line-4 triple plus the delta: the 30
use-alt-sol secrets put a different triple on line 4 with delta 0,
the swap being the lie itself, while the other 20 secrets and both
samples carry line 4 equal to line 2 with a real delta, sample 2
using -6241 so scripted answers may go negative, and the correct
output is always the line-2 triple. This section first landed the
reading backwards, truth on line 4 and a decoy on line 2, and that
validation was circular: the retired sphinx:4 compare mode echoed
whichever line the solver read, so the wrong model confirmed
itself. Re-adjudicated against the judge data, with the 2022 W and
2023 A judge files byte-identical across all 50 cases, the fix wave
re-landed all six languages, c in 64d294b, python and lua in
dbc8658, go and javascript in fc54da4, and c\# in 1367ea9, and 2022
W judges 50 of 50 in every one of them post-fix on main.

The worked run: trace the model on sample 1, whose official answer
files are empty because the judge scripts the interaction, so the
trace targets the prose-stated output, the line-2 triple 4 4 4 the
runner must see printed. The five questions are (1,0,0), (0,1,0),
(0,0,1), (1,1,1), (1,2,3), and the driver scripts the answers
truthfully from (4, 4, 4) except the second round, which draws the
delta +1: the answers read 4, 5, 4, 12, 24, the fifth truthful at
4 + 8 + 12 = 24. Excluding each round in turn, rows 1, 3, 4 and 5
solve to la = 4, lc = 4, lb = 12 - 8 = 4, and row 5 checks
4 + 2*4 + 3*4 = 24 exactly, the one consistent hypothesis, while
every other exclusion leaves a surviving row off by 1 or 2. The
recovered legs are 4 4 4, the line-2 truth.

#table(
  columns: (auto, auto, 1.6fr),
  inset: 4pt,
  table.header([*lie assumed at*], [*solved triple*], [*leftover check*]),
  [no lie], [(4, 5, 4)], [row 4 reads 13 against 12, row 5 reads 26 against 24],
  [round 1], [(3, 5, 4)], [row 5 reads 25 against 24],
  [round 2], [(4, 4, 4)], [row 5 reads 24, consistent],
  [round 3], [(4, 5, 3)], [row 5 reads 23 against 24],
  [round 4], [(4, 5, 4)], [row 5 reads 26 against 24],
  [round 5], [(4, 5, 4)], [row 4 reads 13 against 12],
)

#listing("icpc/samples-c/src/Ch11/pW.c", first: 99, last: 126, caption: [c, the file mode: line 2 truth, line 3 round and delta, line 4 alternate, one answer overwritten])

#listing("icpc/samples/src/Ch11/PW.cs", first: 26, last: 55, caption: [c\#, the same file mode, crafted three-line fixtures defaulting to the line-2 triple])

#listing("icpc/samples-go/ch11/pw.go", first: 20, last: 38, caption: [go, tokens read straight: true legs, lie spec, alternate legs, the lie applied to one answer])

#listing("icpc/samples-js/src/ch11-pw-riddleofthesphinx.mjs", first: 68, last: 89, caption: [javascript, solve: the token comment pins the layout, the lying round answered from line 4 plus the delta])

#listing("icpc/samples-py/src/Ch11/pw.py", first: 70, last: 81, caption: [python, solve: three split lines, truthful answers from line 2, one overwritten at the lying round])

#listing("icpc/samples-lua/ch11_pw.lua", first: 109, last: 134, caption: [lua, the file mode: skip the header, read truth then alternate, apply the single lie])

The fixture is the answer sequence 4 4 4 12 18: the truthful fifth
answer for legs (4,4,4) is 24, so the lie must sit on round 5, and
the remaining rows give la = lb = lc = 4 directly. Every suite
drives `deduce` on that sequence and expects `4 4 4`, plus the
no-lie answers 12 7 3 22 35, a lie at round 1 with delta +1, and a
lie at round 3 with a large negative delta, -1000 in five languages
and -40 on the go row, all still recovering the legs,
and the fix wave's file-mode pair, the alt-sol swap and the
equal-triples delta lie, lifts every suite to six checks per
language. Answers stay within 1e5 and legs within 1e4, so no
integer divergence.

#diagram([the five question rows, the lying answer struck through, the recovered legs underneath], length: 12pt, {
  let row(y, q, a, struck: false) = {
    cdraw.content((1.0, y), q, size: 6.5pt, anchor: "west")
    cdraw.content((5.0, y), a, size: 6.5pt, anchor: "west")
    if struck {
      cdraw.line((4.7, y), (6.6, y), stroke: luma(60))
    }
  }
  cdraw.content((1.0, 7.5), [question], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((5.0, 7.5), [answer], size: 6pt, anchor: "west", fill: luma(100))
  row(6.4, [(1,0,0)], [4])
  row(5.3, [(0,1,0)], [4])
  row(4.2, [(0,0,1)], [4])
  row(3.1, [(1,1,1)], [12])
  row(2.0, [(1,2,3)], [18], struck: true)
  cdraw.content((7.4, 2.0), [the lie, delta -6], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((1.0, 0.7), [surviving rows solve to la = lb = lc = 4], size: 6.5pt, anchor: "west", fill: luma(100))
})

== x, quartets

Four children play quartets with a 32-card deck of 8 sets of 4
cards, named 1A through 8D, the first digit the set. Every player is
dealt 8 cards and player 1 starts. On a turn a player asks another
player for one particular card, and the ask is legal only when the
asker already holds at least one card of that card's set. If the
asked player holds the card they must hand it over and the asker
keeps the turn and asks again. Otherwise they say no, the asker's
turn ends, and the asked player's turn begins. During a turn a
player holding all four cards of a set may lay that quartet aside
for a point, removing its four cards from the game. A player out of
cards leaves, the turn passing to the next player in 1-2-3-4 order
who still holds cards, nobody may ask for a removed card or ask a
player who has left, and asking for a card the asked player cannot
possibly hold, one sitting in the asker's own hand, is foolish but
legal. Cheating is exactly two claims: asking while holding no card
of that set, and denying a held card. Given the log of a game's
first n actions, decide whether some initial deal of the 32 cards
makes the whole log the play of honest players, and if not, print
the first action number after which someone must already have
cheated
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).

The input, per the problemset pdf, is one integer n with 1 <= n <=
1000, then n action lines in one of three shapes: `x A y sk yes`,
player x asks player y for card sk and receives it, `x A y sk no`,
the ask draws a denial and y's turn begins, or `x Q s`, player x
lays quartet s aside, with x and y distinct players in 1..4, sets s
in 1..8, and ranks k among A, B, C, D. The log obeys every rule
except possibly the two cheat forms. The output is `yes`, or `no`
and the first incriminating action number, under the pdf's 2 second
limit.

Official sample 1, reprinted byte for byte from the judge data pair
`X-quartets/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and explains: both askers needed a set-3 card in
hand, the transfers pin 3A with player 3 and 3D with player 4, and
both players 1 and 2 deny holding 3C, so 3B and 3C must have started
with players 1 and 2 in some order while neither denial leaves room
for 3C anywhere: no deal survives action 4.

input:

```
4
1 A 2 3C no
2 A 3 3A yes
2 A 4 3D yes
2 A 1 3C no
```

expected output:

```
no
4
```

Official sample 2, same source: the fourth denial lands on 3B
instead, an honest deal still exists, and player 1 later completes
set 5 and lays it down.

input:

```
6
1 A 2 3C no
2 A 3 3A yes
2 A 4 3D yes
2 A 1 3B no
1 A 4 5B yes
1 Q 5
```

expected output:

```
yes
```

Recognition: n <= 1000 actions against a fixed 32-card deck under
the 2 second limit. One feasibility test per action at 32 slots
through augmenting paths costs at most 32 · 32 = 1024 augment
steps, about 1e6 for the whole log, three orders of magnitude
inside budget.

The statement's cue is decide whether some initial deal makes the
whole log honest: the deal places 32 cards into start slots under
pins and bans, and the question after every action is exactly
whether a perfect matching still exists, the cue of a
feasibility-as-matching shape. Problem X is the 2022 face of the
bipartite assignment feasibility family, and the bipartite
assignment feasibility family collects chapter 08 problem C,
chapter 13 problem B, and chapter 13 problem F.

Enumerating deals prices out at 32! over (8!)^4, about 1e17, and
tracking one candidate deal goes wrong the first time a denial
leaves several homes, so the per-action matching is the only budget
that closes.

The solver tracks knowledge about the initial deal: a card's
start owner when a transfer reveals it, a card's non-owners on
honest-sounding denials, current holders of moved cards, and one
pending started-with-some-card-of-set-S constraint per player and
set. After every action a perfect matching of the 32 start slots to
the 32 cards, hard pins, forbidden edges, and demand slots
restricted to their set, decides whether some deal still explains
everything, and the first failing action is the answer, with the
matching cost 32 cards per action through augmenting paths, per the
solutions pdf pages 7 and 8, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
Book 8's chapter 38, network flows ii, builds kuhn's
augmenting-path bipartite matching this feasibility test runs once
per action. Directly visible contradictions, denying a card visibly held,
handing a card held elsewhere, laying a quartet containing someone
else's card, answer immediately. The trap that cost one stream a
judge case is the demand registration: pending demands must be
registered unconditionally at every ask. Registering them only when
a justification is still visible lets a provably unjustifiable ask
slide, the matching never fails, and the log ends in a false yes,
judge witness secret-154-per, old output yes, truth `no` at action
917. The go and js engines compute the justification mask
explicitly and answer `no` on the spot when it comes up empty; C,
C\#, python, and lua register the demand and let the matching reject
it, and both encodings are provably the same model.

The worked run: trace the model on sample 1. Action 1, player 1
asks player 2 for 3C and draws a denial: the ask registers player
1's demand for a set-3 starter, the denial bans 3C from player 2,
and a deal still exists since 3B or 3C can start with player 1.
Actions 2 and 3 transfer 3A from player 3 and 3D from player 4 to
player 2, pinning both cards' starts, and the demand side stays
satisfiable through 3B or 3C. Action 4, player 2 asks player 1 for
3C and is denied: 3C is now banned from players 1 and 2, and with
3A pinned to player 3 and 3D to player 4, the only set-3 card
either demand slot can still take is 3B, one card for the two
demands of players 1 and 2, so the matching fails. The first
incriminating action is 4, and the trace ends at the printed answer
`4`.

#table(
  columns: (auto, 1.2fr, 1.2fr, 1.2fr),
  inset: 4pt,
  table.header([*set-3 card*], [*start pinned*], [*banned from*], [*after action 4*]),
  [3A], [player 3, action 2], [], [one home left],
  [3B], [], [], [the only card both demands can take],
  [3C], [], [player 2, action 1; player 1, action 4], [players 3, 4 only],
  [3D], [player 4, action 3], [], [one home left],
)

#listing("icpc/samples-c/src/Ch11/pX.c", first: 55, last: 98, caption: [c, the matching engine: allow, augmenting path, deal_exists with one dedicated slot per demand])

#listing("icpc/samples/src/Ch11/PX.cs", first: 106, last: 142, caption: [c\#, Feasible: demand slots first, free slots behind them, then the 32-card matching])

#listing("icpc/samples-go/ch11/px.go", first: 164, last: 187, caption: [go, the ask branch: askKnown triage, the computed mask, and the immediate no when no card can justify the ask])

#listing("icpc/samples-js/src/ch11-px-quartets.mjs", first: 111, last: 133, caption: [javascript, the same triage and mask-0 rejection, denials recorded as notStart bits])

#listing("icpc/samples-py/src/Ch11/px.py", first: 27, last: 59, caption: [python, the nested allow, aug, and deal_exists the action loop calls after every step])

#listing("icpc/samples-lua/ch11_px.lua", first: 117, last: 166, caption: [lua, the action loop: quartets pin never-moved cards, asks register demands, denials forbid])

The fixture is four actions, each player denying 7B in turn: 7B
never moves, so each denial excludes the denying player as its
starter, the fourth action closes the last escape, and the answer is
`no` at action 4. Every suite asserts that plus both official
samples. The C, C\#, python, and lua suites add the crafted yes case
whose laid quartet start-matches three cards to player 1, four
checks each. Go swaps that crafted yes for the pinned regression of
the registration trap, `2 A 1 3B no / 3 A 1 3C no / 4 A 1 3D no /
2 A 3 3A yes / 1 A 4 3C yes`, which must answer `no` at action 5,
and javascript carries that regression beside the crafted yes, five
blocks to the others' four. Cards are 32 two-character tokens and
players fit in a bitmask everywhere, so no integer notes.

#diagram([four denials arranged around card 7B, the fourth closing the circle], length: 12pt, {
  cdraw.rect((7.6, 3.4), (11.6, 5.0), fill: luma(225), stroke: luma(100), radius: 0.05)
  cdraw.content((9.6, 4.2), [7B], size: 8pt)
  let arc(x, y, t, bold: false) = {
    cdraw.line((x, y), (9.6, 4.8), stroke: if bold { luma(40) } else { luma(130) })
    cdraw.content((x, y), t, size: 6.5pt, fill: luma(100))
  }
  arc(4.0, 6.4, [1 denies])
  arc(4.0, 2.0, [2 denies])
  arc(15.2, 2.0, [3 denies])
  arc(15.2, 6.4, [4 denies], bold: true)
  cdraw.content((0.8, 7.3), [7B never moved, every denial excludes a starter], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 0.6), [the fourth denial leaves no home: no, action 4], size: 6.5pt, anchor: "west", fill: luma(100))
})

== y, compression

The Infinite Compression Plan Consortium's DRY scheme exploits
repetition: whenever the string contains two consecutive copies of
the same substring, it deletes one of them, and later deletions may
use opportunities that earlier ones uncover. When several doubled
substrings are on offer the choice matters, and DRY must pick the
removal order that drives the final length as low as possible. The
task works this on binary strings: given the string, print a
shortest result any sequence of legal deletions can reach
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).

The input, per the problemset pdf, is one nonempty line of zeroes
and ones of length at most 1e5, and any shortest reachable result is
an accepted answer, under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`Y-compression/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: a uniform string collapses to its one value.

input:

```
1111
```

expected output:

```
1
```

Official sample 3, same source: the endpoints 1 and 0 both survive,
and 10 is already square-free.

input:

```
10110
```

expected output:

```
10
```

Sample 2, also official, is the fixed point: 101 admits no deletion
and prints itself.

Recognition: the string runs to 1e5 characters under the 1 second
limit, so the budget is one scan, and even an O(n^2) repetition
scan at 1e10 pair checks is already an order of magnitude over.

The statement's cue is any sequence of legal deletions: the
reachable set sounds like a search, but the first and last
characters never change, no value dies, and the end state admits
no further deletion, meaning square-free, and binary square-free
strings stop at length 3, so one invariant collapses the task to
three cases with no search at all. Problem Y is the 2022 face of
the invariant collapse family, and chapter 12 problem I is the
other invariant collapse twin.

Greedy deletion orders price out at exponentially many choice
points, and a dp over positions and lengths has no statement bound
to hang on, so the invariant is the only budget that closes.

The first and last characters can never change, no character value vanishes
entirely, and the final string admits no further deletion, meaning
it is square-free, and binary square-free strings have length at
most 3. Book 8's chapter 33, string algorithms ii, finds the square
repetitions a square-free string must avoid. So the answer is the
single character when the input is
uniform, the two endpoints when they differ, and the endpoints
around the other value otherwise, reachable and unique, per the
solutions pdf pages 8 and 9, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
The solvers are three branches and a
print, and the interesting listing is which scan each language
uses.

The worked run: trace the model on sample 1. The input is 1111,
uniform, exactly one value present. The first and last characters
are both 1, the value set cannot shrink to empty, and the final
string must be square-free: deleting one copy of every doubled
block drives 1111 to 11 to 1, and the single character 1 is
square-free at length 1, so the trace ends at the printed answer
`1`.

#table(
  columns: (1.2fr, 1.6fr, auto),
  inset: 4pt,
  table.header([*input shape*], [*law*], [*answer*]),
  [uniform, sample 1], [one value present, collapse to it], [the character],
  [endpoints differ, sample 3], [both survive, length 2 is square-free], [both endpoints],
  [endpoints equal, mixed middle], [endpoints keep one middle value], [length 3],
)

#listing("icpc/samples-c/src/Ch11/pY.c", first: 21, last: 48, caption: [c, solve: trim, then the three-case answer over the endpoints])

#listing("icpc/samples/src/Ch11/PY.cs", first: 14, last: 39, caption: [c\#, one pass counting both values while catching first and last])

#listing("icpc/samples-go/ch11/py.go", first: 11, last: 40, caption: [go, the byte-level twin of the C branch])

#listing("icpc/samples-js/src/ch11-py-compression.mjs", first: 11, last: 19, caption: [javascript, the whole solve: includes decides uniform])

#listing("icpc/samples-py/src/Ch11/py.py", first: 10, last: 17, caption: [python, set(s) of length 1 is the uniform test])

#listing("icpc/samples-lua/ch11_py.lua", first: 9, last: 20, caption: [lua, a pattern negation tests uniformity in one find])

The fixture is 0110: keep first 0, last 0, and one 1, and length 2
cannot hold all three because 00 is itself a doubled block, so 010,
reached by deleting one of the doubled 1s. Every suite asserts
`010`, plus the official samples 1111 to 1, 101 staying 101, and
10110 to 10, plus the crafted 00000 to 0: five checks per language
in C, C\#, python, and lua, the same five asserts in javascript
folded into four blocks with 00000 riding the uniform one, and four
go rows that stop at the official samples. One binary line of at
most 1e5 characters, no integers at all.

#diagram([the fixture: one of the doubled 1s removed, the irreducible result underneath], length: 12pt, {
  let ch(x, y, t, dim: false) = {
    cdraw.content((x, y), t, size: 9pt, fill: if dim { luma(170) } else { luma(30) })
  }
  ch(5.0, 6.2, [0])
  ch(7.0, 6.2, [1])
  ch(9.0, 6.2, [1], dim: true)
  ch(11.0, 6.2, [0])
  cdraw.line((9.0, 7.0), (9.0, 5.4), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.0, 5.0), [one copy deleted], size: 6pt, fill: luma(100))
  ch(6.0, 3.4, [0])
  ch(8.0, 3.4, [1])
  ch(10.0, 3.4, [0])
  cdraw.content((13.0, 3.4), [square-free, irreducible], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((5.0, 1.6), [endpoints never change, no value dies, length <= 3], size: 6.5pt, anchor: "west", fill: luma(100))
})

== z, archaeological recovery

Professor Z Mummer's newly found tomb wall holds a row of k
pyramid-shaped stone slabs, each showing one of three hieroglyphs
face up: an ankh, an eye of Horus, or an ibis. Beside the wall stand
n levers, and each lever rotates some of the pyramids one step,
clockwise or counter-clockwise, leaving the others untouched.
Flipping a lever back reverses exactly its own rotation, and the
levers act independently, so the wall state under any setting of the
levers is the sum of the chosen rotations. A student enumerated all
2^n lever settings and tallied the resulting wall configurations,
multiplicities included, but an ink disaster destroyed the only
record of the individual levers. From the multiset of reachable
configurations alone, print any lever list that produces exactly
that multiset
(#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[statement]).

The input, per the problemset pdf, is one line of n, k, and t, with
1 <= n <= 40 levers, 1 <= k <= 5 pyramids, and 1 <= t <= 3^k
distinct configurations, then t lines: a string of k characters over
A, E, and I naming the hieroglyph face up on each pyramid, and a
count f with 1 <= f <= 2^n, the number of lever settings reaching
it. The configurations are pairwise distinct, the counts sum to
exactly 2^n, and at least one lever list is guaranteed to exist. The
output is n lever strings over +, -, and 0, clockwise,
counter-clockwise, and no rotation per pyramid, any valid list
accepted, under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`Z-archaeologicalrecovery/sample-1.in` and `sample-1.ans`, the same
pair the problems pdf prints beside its figure: the first lever
turns pyramid 1 clockwise and pyramid 2 counter-clockwise, the
second turns all three clockwise, and each of the four states is
reached exactly once.

input:

```
2 3 4
EEE 1
EIA 1
IAE 1
AAA 1
```

expected output:

```
+-0
+++
```

Official sample 2, same source: two pyramids, three levers, two
configurations reached 4 times each, one real lever and two that
move nothing.

input:

```
3 2 2
IA 4
AA 4
```

expected output:

```
-0
00
00
```

Recognition: n <= 40 levers but k <= 5 pyramids and t <= 3^k = 243
configurations under the 1 second limit. The counts live in the
3^5 = 243-cell universe, the identity and the convolution cost
n·3^k, about 1e4 cell updates, and the shift search 3^k, thousands
of operations in total, and the tight n is what forces the algebra,
since the counts themselves reach 2^40.

The statement's cue is from the multiset alone, print any lever
list: the multiset of 2^n sums is pinned by residues mod 3 over a
3^k universe, the cue that the whole configuration space collapses
into Z_3^k and the levers are read off its projections. Problem Z
is the 2022 face of the algebraic reduction to a small universe
family, and algebraic reduction to a small universe covers chapter
08 problem I and chapter 10 problem K.

Enumerating lever lists prices out at 3^(n·k) = 3^200, and fitting
the multiset by simulating 2^40 settings per candidate is equally
dead, so the valuation identity is the only budget that closes.

States encode as digits
A/E/I for 0/1/2, levers print over 0, +, and -. Projecting the state
multiset onto any x gives three residue counts whose minimum 2-adic
valuation is the number of levers orthogonal to x: appending a zero
lever doubles all three counts, a nonzero lever permutes them as a
3-cycle and keeps one odd. A counting identity then hands out the
levers, the number in the subspace G is 3 times the f-sum over
G-perp, divided by the perp size, minus n, all over 2, evaluated at
G = {0} for the zero levers and at each antipodal line {0, x, -x}
for the rest. The solver emits zeros and one + representative per
line member, convolves the 2^n subset sums over arrays of size 3^k
carrying reachability witnesses, finds the shift v whose shifted
multiset equals the input, and flips the signs of any lever subset
summing to v, which shifts the whole multiset uniformly onto the
input, with the work dominated by 3^k times n plus 3^k, per the
solutions pdf pages 9 and 10, problem at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf].
Book 8's chapter 34, linear algebra, carries the linear-system
machinery over Z_p^k this reconstruction runs on.
Zero teams solved it in contest.

The worked run: trace the model on sample 1. Encoding A, E, I as
0, 1, 2, the four states are AAA = (0, 0, 0), EEE = (1, 1, 1),
EIA = (1, 2, 0) and IAE = (2, 0, 1), each reached exactly once, and
the counts sum to 4 = 2^2, so n = 2 levers. All four counts are
odd, so no lever is the zero lever, a zero lever would double every
count to 2. The emission reads the levers off the small universe as
`+-0` = (1, 2, 0) and `+++` = (1, 1, 1), and the closing check,
simulating every subset sum, verifies them: neither lever on is
(0, 0, 0) = AAA, `+-0` alone is EIA, `+++` alone is EEE, and both
on sum to (1, 2, 0) + (1, 1, 1) = (2, 0, 1) mod 3, exactly IAE.
Every input state is hit once, and the trace ends at the printed answer
`+++`.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*levers on*], [*sum mod 3*], [*state*], [*input count*]),
  [none], [(0, 0, 0)], [AAA], [1],
  [`+-0`], [(1, 2, 0)], [EIA], [1],
  [`+++`], [(1, 1, 1)], [EEE], [1],
  [both], [(2, 0, 1)], [IAE], [1],
)

#listing("icpc/samples-c/src/Ch11/pZ.c", first: 85, last: 125, caption: [c, f(x) as the min 2-adic valuation of the projected counts, then zeros and per-line lever counts from the identity])

#listing("icpc/samples/src/Ch11/PZ.cs", first: 42, last: 69, caption: [c\#, the same projection through one gcd then one valuation loop, m of 0 set to n])

#listing("icpc/samples-go/ch11/pz.go", first: 99, last: 145, caption: [go, the identity as one space closure, then the subset-sum convolution with witness bitmasks])

#listing("icpc/samples-js/src/ch11-pz-archaeologicalrecovery.mjs", first: 83, last: 107, caption: [javascript, the convolution and the snapshot rule: witness sources must predate the lever])

#listing("icpc/samples-py/src/Ch11/pz.py", first: 50, last: 69, caption: [python, fcnt, the zeros identity, and the per-line counts])

#listing("icpc/samples-lua/ch11_pz.lua", first: 127, last: 174, caption: [lua, convolution, snapshot witnesses, and the shift search])

The fixture is k = 1, n = 2, counts A 1, E 1, I 2: the projections
are the counts themselves, valuation 0 means no zero lever, the
antipodal line holds both, both start at +, their subset sums give
counts 1, 2, 1, the input is that multiset shifted by 2, and
flipping both levers lands on it, so the canonical answer is two
minus signs. Every suite asserts `-` and `-`, plus the crafted
`2 1 2` answering + and 0, plus both official samples, and every
case re-verifies by simulating all 2^n sums, four checks per
language. Frequencies reach 2^40, which pins the containers: int64
in C, C\#, and go, lua's 64-bit integers, python's exact ints, and
javascript numbers exact below 2^53 with the counts held in a
Float64Array. The counting identity divides by |G-perp| and halved,
and both divisions land on integers first.

#diagram([the fixture's projected counts as three towers, the valuation trick and the double flip], length: 12pt, {
  let tower(x, h, t) = {
    cdraw.rect((x, 1.2), (x + 1.6, 1.2 + h * 1.1), fill: luma(222), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 0.8, 0.7), t, size: 6.5pt, fill: luma(100))
    cdraw.content((x + 0.8, 1.2 + h * 1.1 + 0.4), str(h), size: 6pt, fill: luma(100))
  }
  tower(4.0, 1, [A, 0])
  tower(7.0, 1, [E, 1])
  tower(10.0, 2, [I, 2])
  cdraw.content((13.2, 2.6), [min 2-adic valuation 0], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((13.2, 1.8), [no zero lever, both on the line], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 5.2), [start +, +: subset sums 1, 2, 1], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 4.4), [input is that multiset shifted by 2], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 3.6), [flip both levers: - and -], size: 6.5pt, anchor: "west", fill: luma(100))
})

== across the six languages

#table(
  columns: 5,
  table.header([*problem*], [*kernel*], [*c and c\#*], [*go and js*], [*python and lua*]),
  [p], [mod-3 propagation over button components], [stamp-retry BFS, c-sharp revalidates BFS order], [same engine on typed arrays and slices], [affine root algebra, no retries, lua stamps like c],
  [q], [fenwick suffix counts over the joint order], [long long tree, F3 culture], [class and struct trees], [born-full trees, removals only],
  [r], [bridges dropped, rotations and parity per component], [lazy heaps not needed: cover marks, KMP], [go carves blocks, js cover marks], [py marks tree-edge owners, lua KMP over the walk],
  [s], [exact (k, g, l) machine, caps clamped to reachability], [pull sweep with lazy window heaps], [diagonal sweep, sliding windows], [same sweep, boxed ints in py, future ring in lua],
  [t], [unfold-straights plus corner bends], [1024-grid ternary legs], [run detection and bisected edges], [grid ternary, flat lua scalars],
  [u], [corrected even curve budget, canonical strings], [mirrored halves, 4q+6 split], [same emission, plus the walk validator], [one-expression emissions],
  [v], [hull of doubled score points], [upper hull, tie and strict candidates], [monotone chain, edge queries], [hull over parallel arrays],
  [w], [exclusion hypotheses over 3-subsets, Cramer], [deduce with integer checks], [same, file-mode scripted answers], [nested comprehensions, truth-line file mode],
  [x], [per-action perfect matching of 32 slots], [matching with dedicated demand slots], [explicit mask, immediate no when empty], [demand flags, matching rejects],
  [y], [square-free endpoint invariant], [pointer trim, three branches], [byte endpoints], [set or pattern uniformity test],
  [z], [2-adic valuations hand out levers, witness flip], [int64 counts, index digits], [witness bitmasks, Float64Array in js], [exact ints, snapshot witnesses],
)

The pattern this set adds to the book's ledger: one problem, S,
where the exact state machine outruns two interpreters on honest
code and the chapter records the measured wall rather than a
workaround, one constructive problem, U, where the judge corrected
the budget mathematics after the fact, and one knowledge problem,
X, where the difference between registering a constraint
unconditionally and registering it conditionally was one full judge
case. Everything else is the book's standing lesson again, that the
same derivation ports across six languages and the ports agree
because the suites pin the same fixtures everywhere.

sources: ICPC Foundation and icpc.global, the problemset at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf]
and the solutions at
#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/finals2022solutions.pdf")[finals2022solutions.pdf],
both accessed 2026-09-14 and cached under `ref/icpc/2022/` with
sha256 digests in `ref/icpc/INDEX.md`. The solutions pdf is the
algorithm and complexity reference for every section above, and its
page 1 statistics are the contest counts in the introduction. The
judge data, 1304 inputs across the 11 letters, is local-only under
`ref/icpc/2022/data/`, its secret files are never quoted, and every
sample pair reprinted above is the byte-exact content of that
problem's `sample-N.in` and `sample-N.ans` files, attributed in
place, with W's pair carried as its driver spec because that problem
is adjudicated by an interactive runner against empty answer files.
The chapter's suites
are the frozen solver files: C runs 48 self-checks across the 11
programs through its CHECK, CHECKD, CHECKS, and CHECKF macros, the
C\# suite is 47 [Fact] methods carrying 49 assertions, go pins 41
table rows, 33 exact, 4 tolerance, and 4 convolution
re-verifications, plus the 544-budget walk validator for u,
javascript runs 49 it blocks with 60 assertions, python 48 check
self-checks, and lua reports 49 named checks through run.lua, 48
of the shared family plus the pendant-bridge variant on r.
