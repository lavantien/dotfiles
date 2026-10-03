// book 9, chapter 9: the icpc world finals 2018, eleven problems A
// through K, six languages each, listings sliced from the landed
// solver files under books/icpc/samples*/
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= icpc world finals 2018

The 2018 world finals set is eleven problems, A through K, published
by the ICPC Foundation at
#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[icpc.global],
and this chapter works every letter in six languages, 66 solvers plus
the year-local helpers they share. The solutions pdf is the algorithm
reference for every method and complexity claim below, exactly as the
house rules in chapter 1 require, and the spread its scoreboard page
reports for this set is wide: C and J were accepted by no team, D by
5, G by 7. The C and J walkthroughs are therefore the longest, because
a problem nobody solved at the contest deserves the fuller derivation.
Inputs run to 52.8 MB for A, so whole-file readers are load-bearing
across the set, and the judge data that backs the fixtures stays
local, its official sample pairs reprinted below byte for byte with
attribution.

== the year-local helpers: log factorials, clipped geometry, a counting fenwick, and the tour tables

Four helper kits are year-local to 2018, each named in the year spec
with a one-line contract and none duplicating a wave 1 toolbox
module, and everything else the year's solvers import comes from the
toolbox chapters 2 through 7. Each kit states its contract and
prints its twin files below in the book's fixed language order.

The lnfact kit backs problem D and exists for the year's overflow
trap: a table of `ln(k!)` with `lnC(a,b)` as three subtractions
over it, so the gem island recursion evaluates every binomial in
log space and the raw `C(999,500)`, near 1e299, is never built.
C's `Ch09/ch09_lnfact.h` fills the table to 1023 behind
`lnfact_init`, go's `ch09_lnfact.go` builds 1100 entries as a
package var, javascript's `ch09-lnfact.mjs` wraps one `Float64Array`
in a load-time closure, and lua's `ch09_lnfact.lua` builds its
table at require time, while c\# and python inline the same table
inside their D solvers sized to `n+d+2`.

#listing("icpc/samples-c/src/Ch09/ch09_lnfact.h", first: 1, last: 22, caption: [c: lnfact_init fills the table, lnC as three subtractions, out of range held at -1e100])

#listing("icpc/samples-go/ch09/ch09_lnfact.go", first: 1, last: 25, caption: [go: buildLnFact as a package var, lnC with `-Inf` outside the range])

#listing("icpc/samples-js/src/ch09-lnfact.mjs", first: 1, last: 14, caption: [javascript: one Float64Array built in a closure, the same exported lnC])

#listing("icpc/samples-lua/ch09_lnfact.lua", first: 1, last: 21, caption: [lua: fact built at require time, ln_c over three table lookups])

The geo kit backs problem G with the 2d vector algebra no wave 1
toolbox chapter carried, cross products, ray-cast
point-in-polygon, segment intersection, and the half-plane clip of
a convex cell against another site's perpendicular bisector. C's
`Ch09/ch09_geo.h` walks flat `G2` structs with an on-edge rule that
counts the closed park as inside, go's `ch09_geo.go` carries the
same predicates over `pt2` values, javascript's `ch09-geo.mjs`
exports them over plain point objects, and lua's `ch09_geo.lua`
spells them over flat coordinate arrays, while c\# and python
inline the predicates inside their G solvers.

#listing("icpc/samples-c/src/Ch09/ch09_geo.h", first: 17, last: 67, caption: [c: g2inpolygon by ray cast with the closed-park on-edge rule, g2segcross, then the g2clip half-plane cut])

#listing("icpc/samples-go/ch09/ch09_geo.go", first: 79, last: 118, caption: [go: clipCell keeping the half-plane closer to one site, and the line cut it inserts])

#listing("icpc/samples-js/src/ch09-geo.mjs", first: 11, last: 55, caption: [javascript: distPointSeg feeding pointInPoly, segIntersect keeping touching endpoints])

#listing("icpc/samples-lua/ch09_geo.lua", first: 65, last: 99, caption: [lua: clip_cell keeping the side closer to one site, line_cut clamped onto the crossing edge])

The fenwick kit backs problem I with the year's order statistic,
point add and prefix sum over shifted picture columns, an active
base end entering the tree at its corner and leaving when its run
expires. C's `Ch09/ch09_fenwick.h` carries the whole contract in
thirty-one lines, go's `ch09_fenwick.go` walks the same lowbit
steps as `fenwick9`, and lua's `ch09_fenwick.lua` exposes the
module `fen` over a sparse table, while javascript inlines a
`Fenwick9` class in its solver, python replaces the tree with one
big-int bitmask and counts windows by `bit_count`, and c\# folds
the arrays into its `Sweep`.

#listing("icpc/samples-c/src/Ch09/ch09_fenwick.h", first: 1, last: 31, caption: [c: the whole fenwick header, init, point add, prefix sum, three functions])

#listing("icpc/samples-go/ch09/ch09_fenwick.go", first: 1, last: 27, caption: [go: fenwick9 over shifted columns, add and prefix on the lowbit walk])

#listing("icpc/samples-lua/ch09_fenwick.lua", first: 1, last: 28, caption: [lua: fen.add and fen.prefix on the 1-based lowbit walk, empty slots held by `or 0`])

The jtable kit embeds problem J's per-m base tables and cycle
parameters, `Ch09/ch09_jtable.h`, `ch09_jtable.go`,
`ch09-jtable.mjs` and `ch09_jtable.lua`, and all four twins already
print in full inside problem J's own section, so no listing repeats
here. C\# and Python carry no twin file in any of the year's four
kits: their solvers inline the log table in D, the predicates in
G, the arrays and bitmask in I, and the embedded tour tables in J.

== problem A: catch the plane

The plane to the ICPC Finals leaves soon and the only way to the
airport is by bus, but the drivers are considering a strike: every bus
in the schedule runs with its own probability, the events independent,
and you learn whether the bus you tried to board actually runs only at
that moment. You stand at station 0, the airport is station 1, and the
schedule lists each bus's start station, destination, departure time,
arrival time, and run probability. A transfer needs an arrival
strictly earlier than the next bus's departure, arriving exactly at a
departure is too late to board, and among the buses leaving one
station at the same instant you can try to get on only one of them.
Plan the journey that maximizes the probability of standing at the
airport by time k
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is two integers m and n by the problemset pdf, 1 <= m <=
10^6 buses and 2 <= n <= 10^6 stations, then one integer k,
1 <= k <= 10^18, the time by which you must arrive at the airport,
then m bus lines: stations a and b with 0 <= a, b < n and a != b, the
departure and arrival times s and t with 0 <= s < t <= k, and p, the
probability the bus runs, 0 <= p <= 1 written with at most 10 digits
after the decimal point. The output is the single probability of
catching the plane under an optimal course of action, correct to an
absolute error of 1e-6, under the pdf's 10 second limit, and the
harness verifies it in float mode, `2018/A` pinned to `float` in
`ref/icpc/compare.json`.

Official sample 1, reprinted byte for byte from the judge data pair
`A-catch/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints and walks through beside its schedule figure: gamble on the
0.2 direct flight and fall back to the station 3 route, itself worth
`0.5*0.181 + 0.5*0.1` through its 0.1 airport bus and its 0.9 return
loop to the last direct, for `0.2 + 0.8*0.1405 = 0.3124`, while the
certain bus into station 2 arrives exactly at its best onward's
departure.

input:

```
8 4
1000
0 1 0 900 0.2
0 2 100 500 1.0
2 1 500 700 1.0
2 1 501 701 0.1
0 3 200 400 0.5
3 1 500 800 0.1
3 0 550 650 0.9
0 1 700 900 0.1
```

expected output:

```
0.3124
```

Recognition: the bounds set the sweep's budget before the
probabilities do. With m <= 10^6 buses under the 10 second limit,
one sort of the 10^6 events costs about 2*10^7 comparisons and the
backward pass folds one proposal per event, 2*10^6 probability
updates, so O(m log m) is the whole affordable shape and everything
else must fall out of the sorted order itself.

The statement's cue is its timing discipline: you learn whether a
bus runs only at the moment you try to board, an arrival exactly at
a departure is too late, and one try per simultaneous departure,
all constraints about a journey read backwards from the deadline k,
so each station carries one scalar, its onward success
probability, refreshed by the events that pass it. Problem A is
the 2018 face of the event sweep over a sorted axis family, and
the same event sweep over a sorted axis cue drives chapter 09
problem H, chapter 10 problem D, chapter 10 problem J, and chapter
13 problem L.

The tempting alternative, a forward grid over time instants, dies
on k <= 10^18, and enumerating journeys prices out at 2^1000000
strategies against 10^6 buses, so the sorted backward event axis
is the only budget that closes.

The sweep runs backwards over sorted events with every station's
onward success probability initialized to 0 and the airport's to 1: an
arrival snapshots its station's onward success probability, a
departure proposes `r*q + (1-r)*p[station]`, and simultaneous
departures from one station batch so only the best proposal lands,
with arrivals at time t snapshotted before t-departures fold in, which
is exactly the rule that kills the same-instant transfer. The answer
is station 0's probability once the time 0 batch lands, O(m log m) for
the sort and linear past it (solutions.pdf pp. 1-2). The fixture is
four buses where the certain bus into station 2 arrives exactly when
its onward connection leaves, so the direct flight with a weak
fallback wins at 0.55, and the sweep below lands it.

The worked run: trace the model on sample 1. The airport seeds
`p[1] = 1` and every other station 0, and the backward sweep folds
the printed buses latest first. Bus 8's arrival at 900 snapshots
`p[1] = 1`, so its 700 departure from station 0 lands `0.1*1 +
0.9*0 = 0.1`. Bus 7's 650 arrival into station 0 snapshots that
0.1, and its 550 departure from station 3 lands `0.9*0.1 + 0.1*0 =
0.09`. Bus 6's 800 arrival snapshotted 1, so its 500 departure
from station 3 lifts `p[3]` to `0.1*1 + 0.9*0.09 = 0.181`, which
bus 5's 400 arrival snapshots before its 200 departure from
station 0 lands `0.5*0.181 + 0.5*0.1 = 0.1405`. The same-instant
rule then decides the sample: bus 2 arrives at station 2 exactly
at 500, its snapshot sees `p[2] = 0` because bus 3's 500 departure
from station 2 folds only afterwards and lands `1.0*1 + 0.0*0 =
1`, so bus 2's 100 departure proposes `1.0*0 + 0.0*0.1405 = 0` and
waiting keeps 0.1405. The time 0 batch finally proposes bus 1 as
`0.2*1 + 0.8*0.1405 = 0.3124`, and the trace ends at the printed answer `0.3124`.

#table(
  columns: (auto, 1.1fr, 1.2fr, auto),
  inset: 4pt,
  table.header([*instant*], [*event*], [*fold*], [*station value*]),
  [900], [arrival, bus 8], [snapshot `p1`], [q = 1],
  [700], [departure, bus 8], [`0.1*1 + 0.9*0`], [`p0` = 0.1],
  [650], [arrival, bus 7], [snapshot `p0`], [q = 0.1],
  [550], [departure, bus 7], [`0.9*0.1 + 0.1*0`], [`p3` = 0.09],
  [500], [arrival, bus 2], [`p2` before the 500 batch], [q = 0],
  [500], [departure, bus 6], [`0.1*1 + 0.9*0.09`], [`p3` = 0.181],
  [500], [departure, bus 3], [`1.0*1 + 0.0*0`], [`p2` = 1],
  [200], [departure, bus 5], [`0.5*0.181 + 0.5*0.1`], [`p0` = 0.1405],
  [100], [departure, bus 2], [`1.0*0 + 0.0*0.1405`, waiting wins], [`p0` = 0.1405],
  [0], [departure, bus 1], [`0.2*1 + 0.8*0.1405`], [`p0` = 0.3124],
)

#listing("icpc/samples-c/src/Ch09/pA.c", first: 63, last: 108, caption: [c: index sort by packed key, arrivals recorded, one batched best proposal per station and instant])

#listing("icpc/samples/src/Ch09/PA.cs", first: 29, last: 65, caption: [c\#: instant groups collect every arrival before the best-proposal dictionary lands])

#listing("icpc/samples-go/ch09/pa.go", first: 33, last: 78, caption: [go: one sort key orders time, kind, station, the sweep reads it straight through])

#listing("icpc/samples-js/src/ch09-pa-catch.mjs", first: 71, last: 121, caption: [javascript: exact descending time ranks packed as `rank*2^22 + kind*2^21 + src`, then the same sweep])

#listing("icpc/samples-py/src/Ch09/pa.py", first: 19, last: 55, caption: [python: a flipped kind bit in the tuple sort puts arrivals first, the batch loop walks backwards])

#listing("icpc/samples-lua/ch09_pa.lua", first: 42, last: 80, caption: [lua: byte-scanner parse, key sort, station 2 is the airport in 1-based numbering])

The suites pin the fixture `4 3 / 10 / ...` at `0.550000000\n`: three
CHECKs in c (the fixture plus two hand cases, one a same-instant
batch), three [Fact] methods in c\#, four table cases in go, one
assertion in the javascript node:test file, four checks in python, and
four `T.eq` blocks in lua, the extra cases each covering a certain
direct bus, a best-of-batch, and a failed first leg caught by a later
flight. Integer notes: times run to 1e18, so every language keeps them
as 64-bit integers or exact integers, and javascript goes one step
further because a float64 sort key loses integer exactness past 2^53,
so it ranks the distinct times exactly with a `BigInt64Array` first
and packs `rank`, kind, and station into one float key, while python
sorts tuples whose kind bit is flipped and lua sorts tables with the
plain comparison chain.

#diagram([the fixture on one clock: the certain bus reaches station 2 exactly at its onward departure, so the direct flight with the 0.1 fallback is the strategy that survives], length: 12pt, {
  let x0 = 1.0
  let x5 = 1.0 + 5 * 1.8
  let x10 = 1.0 + 10 * 1.8
  // station rails
  let rail(y, name) = {
    cdraw.line((1.0, y), (19.0, y), stroke: luma(160))
    cdraw.content((0.7, y), name, size: 6pt, anchor: "east")
  }
  rail(8.6, [station 0])
  rail(6.9, [station 1, airport])
  rail(5.2, [station 2])
  cdraw.line((x5, 8.6), (x5, 4.4), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((x5 - 0.3, 4.1), [t = 5], size: 6pt, fill: luma(100), anchor: "east")
  // the four buses, labels parked off their lines
  cdraw.line((x0, 8.6), (x10, 6.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((3.6, 10.0), [direct, p = 0.5], size: 6pt, anchor: "south")
  cdraw.line((x0, 8.6), (x5, 5.2), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((1.3, 6.1), [certain, p = 1.0], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((x5, 5.2), (x10, 6.9), stroke: (paint: luma(120), dash: "dashed"), mark: (end: ">"))
  cdraw.content((12.6, 4.4), [onward, p = 0.8, unusable], size: 6pt, fill: luma(120), anchor: "north")
  cdraw.line((x5, 8.6), (x10, 6.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((12.4, 9.6), [fallback, p = 0.1], size: 6pt, anchor: "south")
  cdraw.content((1.0, 2.9), [0.5 * 1 + 0.5 * 0.1 = 0.55, take the direct flight], size: 6.5pt, anchor: "west")
  cdraw.content((1.0, 1.7), [the arrival at 5 cannot board the 5-departure], size: 6.5pt, fill: luma(120), anchor: "west")
})

== problem B: comma sprinkler

Doctor Comma Sprinkler claims to have fixed English comma placement,
frustrating and ambiguous as it is, with two rewrite rules. Rule one:
if a word anywhere in the text is preceded by a comma, put a comma
before every occurrence of that word, except an occurrence that opens
a sentence or already carries one. Rule two: if a word anywhere in the
text is succeeded by a comma, put a comma after every occurrence of
that word, except an occurrence that closes a sentence or already
carries one. The two rules apply repeatedly until neither can add a
comma anywhere, and the task is to print the final text
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is one line of text, at least 2 and at most 10^6 characters
by the problemset pdf, every character a lowercase letter, a comma, a
period, or a space. A word is a maximal run of letters, the text
begins with a word, between every two words sits exactly one of a
single space, a comma and a space, or a period and a space ending one
sentence and opening the next, and the last word of the text is
followed by a period with nothing after it. The output is the text
after both rules run to their fixed point, under the pdf's 8 second
limit.

Official sample 1, reprinted byte for byte from the judge data pair
`B-comma/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints and works through sentence by sentence in its statement:
the comma after spot in the middle sentence plants one after the third
sentence's spot, which is not sentence-final there, and one before the
first sentence's sit, which is not sentence-initial, and that new
comma before the first here forces one before the second here.

input:

```
please sit spot. sit spot, sit. spot here now here.
```

expected output:

```
please, sit spot. sit spot, sit. spot, here now, here.
```

Recognition: the text runs to 10^6 characters, say 5*10^5 words and
as many within-sentence adjacencies, under the 8 second limit, and
one closure pass over that graph is linear, so the budget demands
the whole fixed point fall out of a single reachability sweep
rather than from rule applications.

The cue sits in the rules' own wording, every occurrence of that
word, a quantifier over occurrences, with the only exemptions
positional, sentence-initial and sentence-final, so what propagates
is a property of word positions in the separator graph, not of the
text layout. Problem B is the 2018 face of the component structure
and connectivity family, and the component structure and
connectivity family runs through chapter 10 problem E, chapter 10
problem H, chapter 11 problem R, chapter 13 problem E, and chapter
13 problem G.

Reapplying the two rewrite rules textually until quiescence is the
priced-out alternative: one planted comma can force a change in
another sentence, so a text of s sentences can take s full
10^6-character scans, 2.5*10^11 character touches at the bound,
against the closure's single linear pass.

The model is two graph vertices per distinct word, begin and end, with
an edge joining end(prev) to begin(next) for every within-sentence
adjacency: the input's own commas seed marks on end(prev) for a comma
after prev and on begin(next) for a comma before next, a mark on a
begin vertex can only ever force marks on the end vertices joined to
it and vice versa, so one closure over the seeded components decides
every separator, O(n log n) with a dictionary (solutions.pdf p. 2).
The closure is union-find in c and c\# and a stack walk in go,
javascript, python, and lua, and both vehicles land the same bytes on
the fixture, whose only seed `ab,` spreads to three more vertices and
stops.

The worked run: trace the model on sample 1. The three sentences
carry five distinct words, please, sit, spot, here and now, so the
graph is ten vertices with an edge joining end(prev) to begin(next)
for each of the seven within-sentence adjacencies, and the input's
one comma, the one after the middle sentence's spot, seeds two
marks, end(spot) and begin(sit). The closure spreads along
adjacency edges: end(spot) reaches begin(here) across the third
sentence's spot-here, begin(sit) reaches end(please) across the
first sentence's opening, begin(here) reaches end(now) across the
closing now-here, and the component closes at five marked
vertices. Reading marks back to text, end(please) plants the comma
after the first please, begin(sit) plants one before the first
sentence's sit, end(spot) plants one after the third sentence's
spot, which is not sentence-final there, begin(here) plants one
before both of the third sentence's heres, and end(now) plants one
after now, while the first sentence's spot stays bare as
sentence-final and the middle spot already carries its comma, and
the trace ends at the printed answer
`please, sit spot. sit spot, sit. spot, here now, here.`.

#diagram([sample 1's closure graph: the seeded comma closes five vertices of one component, and those five marks print four commas, three of them new], length: 12pt, {
  let v(x, y, t, marked) = {
    cdraw.rect((x, y), (x + 3.1, y + 1.0), fill: if marked { luma(205) } else { luma(240) }, radius: 0.02, stroke: luma(180))
    cdraw.content((x + 1.55, y + 0.5), t, size: 6pt)
  }
  v(1.0, 8.8, [begin please], false)
  v(6.0, 8.8, [begin sit], true)
  v(11.0, 8.8, [begin spot], false)
  v(16.0, 8.8, [begin here], true)
  v(21.0, 8.8, [begin now], false)
  v(1.0, 5.2, [end please], true)
  v(6.0, 5.2, [end sit], false)
  v(11.0, 5.2, [end spot], true)
  v(16.0, 5.2, [end here], false)
  v(21.0, 5.2, [end now], true)
  cdraw.line((2.55, 6.2), (7.55, 8.8), stroke: luma(100))
  cdraw.line((7.55, 6.2), (12.55, 8.8), stroke: luma(100))
  cdraw.line((12.55, 6.2), (7.55, 8.8), stroke: luma(100))
  cdraw.line((12.55, 6.2), (17.55, 8.8), stroke: luma(100))
  cdraw.line((17.55, 6.2), (22.55, 8.8), stroke: luma(100))
  cdraw.line((22.55, 6.2), (17.55, 8.8), stroke: luma(100))
  cdraw.content((12.0, 3.4), [seeded: the comma in spot, sit.], size: 6pt, fill: luma(100))
  cdraw.content((12.0, 2.4), [five marked vertices, four commas printed, three of them new], size: 6.5pt)
})

#listing("icpc/samples-c/src/Ch09/pB.c", first: 100, last: 128, caption: [c: fnv-1a interning into an open-addressed table, union-find closure, one comma per separator])

#listing("icpc/samples/src/Ch09/PB.cs", first: 28, last: 66, caption: [c\#: dictionary vertices `word^` and `word#`, path-halving find, marks seed whole components])

#listing("icpc/samples-go/ch09/pb.go", first: 51, last: 95, caption: [go: the adjacency as a CSR array pair, seeds enqueued, stack closure over it])

#listing("icpc/samples-js/src/ch09-pb-comma.mjs", first: 38, last: 66, caption: [javascript: a Map interns words, adjacency lists in two arrays of arrays, the stack closure])

#listing("icpc/samples-py/src/Ch09/pb.py", first: 38, last: 75, caption: [python: bytearray marks, list-stack closure, rebuild with the exempt cases split out])

#listing("icpc/samples-lua/ch09_pb.lua", first: 41, last: 83, caption: [lua: ids double as a rank list, closure over adjacency tables, table.concat output])

Every suite pins the fixture `ab cd. ef ab, gh. ef cd.` at
`ab, cd. ef, ab, gh. ef, cd.\n` and the two boundary exemptions, a
sentence-final word that never takes a trailing comma and a
sentence-initial word that never takes a leading one: three CHECKs in
c (the fixture plus both official samples), three [Fact] methods in
c\#, five cases in go, five assertions in javascript, five checks in
python, and five `T.eq` blocks in lua, the shared extras being the two
exemptions, a seed whose closure changes nothing, and a comma-free
text that is already a fixed point. No integer notes, the whole
problem is bytes and dictionary ids.

#diagram([the fixture's closure graph: the seeded end(ab) reaches three more vertices, and those four marks are exactly the printed commas], length: 12pt, {
  let v(x, y, t, marked) = {
    cdraw.rect((x, y), (x + 3.4, y + 1.0), fill: if marked { luma(205) } else { luma(240) }, radius: 0.02, stroke: luma(180))
    cdraw.content((x + 1.7, y + 0.5), t, size: 6pt)
  }
  v(1.0, 8.2, [end ab], true)
  v(1.0, 6.0, [begin cd], true)
  v(6.2, 8.2, [begin gh], true)
  v(6.2, 6.0, [end ef], true)
  v(11.4, 8.2, [begin ab], false)
  v(11.4, 6.0, [end cd], false)
  v(16.2, 8.2, [end gh], false)
  v(16.2, 6.0, [begin ef], false)
  cdraw.line((2.7, 6.5), (2.7, 8.2), stroke: luma(100))
  cdraw.line((4.4, 8.7), (6.2, 8.7), stroke: luma(100))
  cdraw.line((13.1, 8.7), (9.6, 6.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.4, 6.5), (6.2, 6.5), stroke: luma(100))
  cdraw.content((10.6, 10.0), [seeded: the comma in ab, gh.], size: 6pt, fill: luma(100))
  cdraw.rect((0.8, 5.8), (9.8, 9.4), stroke: luma(100), radius: 0.05)
  cdraw.content((10.6, 3.6), [output: ab, cd. ef, ab, gh. ef, cd.], size: 6.5pt)
})

== problem C: conquer the world

The volcano lair's deathtraps have, you assume, finally caught the
dashingly handsome spy Waco Powers, so nothing remains but to CONQUER
THE WORLD, and the only obstacle is the travel budget: the lair is
expensive and the evil armies refuse to keep carving their relentless
path of destruction across the puny nations without being paid. The
nations of the world form a tree of transport routes, each route
connecting two nations at a fixed cost per army that uses it and
leaving exactly one way to travel between any two nations. Nation i
currently hosts `x_i` armies and needs at least `y_i` stationed there in
the final configuration. Move the armies into place as cheaply as
possible and report the minimum total cost
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is one integer n, 1 <= n <= 250000 nations by the problemset
pdf, then n-1 route lines u, v, and c with 1 <= u, v <= n and
1 <= c <= 10^6, the cost per army on the bidirectional route, then n
lines of two non-negative integers `x_i` and `y_i`, the armies now in
nation i and the number that must end up there. The pdf promises the
total army count is at least the total requirement and no more than
10^6. The output is the single minimum cost, under the pdf's 8 second
limit.

Official sample 1, reprinted byte for byte from the judge data pair
`C-conquertheworld/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: nation 2 holds five spare armies, nation 3 is two
short, and one spare rides 2->1->3 for 5+5 while nation 1's own spare
army covers the second slot for 5, total 15.

input:

```
3
1 2 5
3 1 5
2 1
5 0
1 3
```

expected output:

```
15
```

Recognition: n <= 250000 nations with at most 10^6 armies total
under the 8 second limit prices the job at one tree pass, and the
convex tree dp runs O(n + X log^2 X) for X the army count, about
10^6 heap operations inside a log squared, while anything that
routes armies one at a time cannot fit.

The cue is the movement language, move the armies as cheaply as
possible against per-route costs and per-nation minimums, supply
and demand carried on a shared tree, the min-cost flow shape with
all capacity sitting on the nodes. Problem C is the 2018 face of
the flow modeling on a network family, and the same flow modeling
on a network cue drives chapter 08 problem J.

The wrong tool is a literal min-cost flow with unit augmentations,
10^6 armies each rerouted by an augmenting path over 250000 nodes
for 2.5*10^11 node touches, and even the cheap naive greedy that
matches heaps at every least common ancestor dies on correctness,
16 failures in 300 small random trees, so cost and correctness
kill the alternatives together.

With armies on the nodes of a weighted tree and a garrison requirement
at every node, the task is a minimum-cost flow on a tree where only
sources and sinks carry capacity. Book 8's chapter 38, network flows
ii, develops the min-cost flow formulation this task reduces to. The
shipped vehicle in all six languages is the convex tree dp from the
sketch: each subtree keeps
its cost function as marginal savings f, a non-increasing list stored
as a low side below the split point and a high side above it, each a
lazily shifted heap, plus a base cost, extending across an edge of
cost c maps `f(a) = max(0, f(a) - sgn(delta+a)*c)`, and joins merge
the two lists small-to-large, the extends O(n + X log X) and the joins
O(n + X log^2 X) for X the total army count, with the answer read off
at the root where delta = 0 (solutions.pdf pp. 2-4). A naive greedy
that matches supply and demand heaps at every least common ancestor is
wrong, it fails 16 of 300 small random trees while passing both
official samples, and none of the six solvers ships it.

The worked run: trace the model on sample 1. The printed tree is
the chain 2-1-3 with both routes costing 5, nation 1 holds `x = 2`
against `y = 1` for one spare, nation 2 holds 5 against 0 for five
spares, and nation 3 holds 1 against 3 for a shortfall of two. The
shortfall pulls two armies across the 3-1 route at 5 each, and the
dp reads the marginal cost of each unit at node 1: its own spare
crosses for 5, while a nation 2 spare crosses 2-1 for 5 then 1-3
for 5 more, 10 in total, so meeting both units costs 5 + 10 = 15
against 10 + 10 = 20 for two imported spares,
and the trace ends at the printed answer `15`.

#diagram([sample 1's two shipments: the local spare crosses one edge for 5, the nation 2 spare rides both edges for 10], length: 12pt, {
  let n(x, y, t) = {
    cdraw.circle((x, y), radius: 0.55, fill: luma(230), stroke: luma(120))
    cdraw.content((x, y), t, size: 7pt)
  }
  n(3.0, 8.6, [1])
  n(11.0, 8.6, [2])
  n(3.0, 3.0, [3])
  cdraw.line((3.55, 8.6), (10.45, 8.6), stroke: luma(150))
  cdraw.content((7.0, 8.9), [cost 5], size: 6pt, fill: luma(100))
  cdraw.line((3.0, 8.05), (3.0, 3.55), stroke: luma(150))
  cdraw.content((3.5, 6.0), [cost 5], size: 6pt, fill: luma(100), anchor: "west")
  cdraw.line((3.3, 7.9), (3.3, 3.8), stroke: luma(40), mark: (end: ">"))
  cdraw.content((2.7, 5.6), [local spare, 5], size: 6pt, anchor: "east")
  cdraw.line((10.6, 8.3), (3.6, 8.3), stroke: luma(40), mark: (end: ">"))
  cdraw.line((3.0, 8.0), (3.0, 3.8), stroke: luma(40), width: 0.7)
  cdraw.content((10.9, 7.4), [nation 2 spare, 5 + 5 = 10], size: 6pt, anchor: "north")
  cdraw.content((7.0, 1.6), [y = 3 needs 2, x = 2 and x = 5 supply, 5 + 10 = 15], size: 6.5pt)
})

#listing("icpc/samples-c/src/Ch09/pC.c", first: 124, last: 167, caption: [c: routing into the k-low largest, and extend's rebalance plus the two lazy shifts, runs carry multiplicities])

#listing("icpc/samples/src/Ch09/PC.cs", first: 20, last: 48, caption: [c\#: BCL PriorityQueue and SortedSet, lazy shifts `SigA` and `SigB`, Extend clamps dead highs away])

#listing("icpc/samples-go/ch09/pc.go", first: 182, last: 213, caption: [go: the extend map, split to `max(0, -delta)`, materialize implicit zeros, shift both sides])

#listing("icpc/samples-js/src/ch09-pc-conquertheworld.mjs", first: 121, last: 159, caption: [javascript: extend and join, the cost accumulator is BigInt because 2.5e17 exceeds 2^53])

#listing("icpc/samples-py/src/Ch09/pc.py", first: 41, last: 64, caption: [python: extend, route, answer, and the small-to-large join over heapq lists, one file, no class ceremony])

#listing("icpc/samples-lua/ch09_pc.lua", first: 82, last: 127, caption: [lua: the same extend and route on hand-rolled 1-based heaps, post-order over an explicit stack])

The crafted fixture is the 5-node tree below with answer 14, verified
against an exact assignment brute force during spec derivation: two
armies ride 1->2 at cost 3 each, one rides on to node 5 for 4 more,
node 4's spare covers node 3 for 4, and covering node 3 from node 1
instead would cost 15. The suites pin `14\n` plus a leaf-to-leaf case,
a surplus-stays-home case, a balanced singleton at `0\n`, and a chain:
three CHECKs in c, three [Fact] methods in c\#, five table cases in
go, five assertions in javascript, five checks in python, five `T.eq`
blocks in lua. Integer notes: costs and answers are int64 everywhere
with the judge maximum at 2.5e17, javascript accumulates the base cost
and the answer in BigInt and prints through `toString`, and every other
language rides its native 64-bit type, c packing run multiplicities so
a 1e6-army node costs one heap entry per distinct value.

#diagram([the fixture's optimal shipment: two armies down the cost-3 edge, one continuing to node 5, node 4's spare crossing to node 3, one army never leaves], length: 12pt, {
  let n(x, y, t, fill) = {
    cdraw.circle((x, y), radius: 0.55, fill: fill, stroke: luma(120))
    cdraw.content((x, y), t, size: 6.5pt)
  }
  n(2.0, 8.8, [1], luma(230))
  n(7.0, 10.2, [2], luma(230))
  n(12.6, 11.4, [3], luma(230))
  n(12.6, 8.6, [4], luma(230))
  n(7.0, 8.0, [5], luma(230))
  cdraw.line((2.0, 8.8), (7.0, 10.2), stroke: luma(150))
  cdraw.line((7.0, 10.2), (12.6, 11.4), stroke: luma(150))
  cdraw.line((12.6, 11.4), (12.6, 8.6), stroke: luma(150))
  cdraw.line((7.0, 10.2), (7.0, 8.0), stroke: luma(150))
  cdraw.content((4.0, 10.1), [cost 3], size: 6pt, fill: luma(100))
  cdraw.content((9.4, 11.4), [cost 2], size: 6pt, fill: luma(100))
  cdraw.content((11.7, 9.9), [cost 4], size: 6pt, fill: luma(100), anchor: "east")
  cdraw.content((6.5, 8.7), [cost 1], size: 6pt, fill: luma(100), anchor: "east")
  // flows
  cdraw.line((2.4, 8.6), (6.6, 9.9), stroke: luma(40), mark: (end: ">"))
  cdraw.line((2.4, 9.0), (6.6, 10.4), stroke: luma(40), mark: (end: ">"))
  cdraw.content((5.6, 11.4), [x2, pays 6], size: 6pt, anchor: "south")
  cdraw.line((7.5, 9.8), (7.5, 8.6), stroke: luma(40), mark: (end: ">"))
  cdraw.content((8.4, 9.2), [pays 4], size: 6pt)
  cdraw.line((13.1, 9.1), (13.1, 10.8), stroke: luma(40), mark: (end: ">"))
  cdraw.content((14.0, 9.4), [pays 4], size: 6pt)
  cdraw.circle((2.0, 8.8), radius: 1.0, stroke: luma(60))
  cdraw.content((2.0, 7.3), [unused], size: 6pt, anchor: "north")
  cdraw.content((2.0, 3.9), [2*3 + 4 + 4 = 14, the brute force agrees], size: 6.5pt)
})

== problem D: gem island

Gem Island's n inhabitants each woke up one morning holding a single
sparkling gem that had appeared overnight, and every night afterwards
exactly one gem on the island, uniformly random among all the gems
there, split into two. After d nights the holdings vary widely, some
islanders rich and many with few, and the elders want to know whether
pure chance explains the spread before tensions rise. List the final
holdings in non-increasing order `a_1 >= a_2 >= ... >= a_n` and report
the expected value of `a_1 + ... + a_r`, the gems held collectively by
the r richest islanders
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is a single line with three integers by the problemset pdf,
n, d, and r, with 1 <= n, d <= 500 and 1 <= r <= n. The output is the
expected number of gems the top r islanders hold after d nights, an
absolute or relative error of at most 1e-6 accepted, under the pdf's 3
second limit, and the harness verifies it in float mode, `2018/D`
pinned to `float` in `ref/icpc/compare.json`.

Official sample 1, reprinted byte for byte from the judge data pair
`D-gemisland/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: three splits over two islanders leave holdings
(4,1), (3,2), (2,3), (1,4), the four compositions of 3 extra gems over
2 islanders each equally likely, so the richest holds 4, 3, 3, 4 in
turn and the expectation is exactly 3.5.

input:

```
2 3 1
```

expected output:

```
3.5
```

Recognition: n and d both at most 500 under the 3 second limit
leave room for the O(n^2 d) memo table, 1.25*10^8 float terms at
the corner, and nothing more, while the family it sums over holds
C(n+d-1, d) compositions, C(999,500) near 1e299 at the bound, a
count no enumeration ever touches.

The cue is the word expected over the r richest holdings, an
expectation over an astronomically large implicit family, exactly
the shape a recurrence answers once every composition is known to
be equally likely, the theorem the sketch proves by induction.
Problem D is the 2018 face of the counting and expectation without
enumeration family, and the same counting and expectation without
enumeration cue drives chapter 09 problem I, chapter 11 problem Q,
chapter 12 problem E, and chapter 12 problem K.

The priced-out alternative is enumeration itself, of compositions
or of the d split sequences, and Monte Carlo simulation is just as
dead, 1e299 outcomes sampled nowhere near tightly enough for a
1e-6 answer.

The sketch proves by induction that every composition of the d extra
gems over the n islanders is equally likely, so the answer is a top-r
sum over all `C(n+d-1, d)` compositions divided by that count. Write
S(n,d) for that un-normalized sum: it collapses to
`(n+d)*C(n+d-1,d)` when n <= r, because then everyone counts, and
otherwise `S(n,d) = r*C(n+d-1,d) + sum_g C(n,g)*S(n-g, d-n+g)`, a
memoized recursion over states with `a+b <= n+d`, O(n^2 d) terms
(solutions.pdf pp. 5-6). The shipped recursion is the normalized form
`g(a,b) = r + sum coef(x) g(a-x, b-a+x)` with
`coef(x) = C(a,x) C(b-1,a-x-1) / C(a+b-1,b)`. All six languages
evaluate it in floats with log-space binomials from a shared
ln-factorial table, coefficients in [0,1] summing to 1, so the total
error stays near 1e-11 against a 1e-6 bound. Book 8's chapter 35,
combinatorics, builds the log-space binomial table and the
stars-and-bars counts this recursion draws from.

The worked run: trace the model on sample 1. With n = 2, d = 3 and
r = 1 the equally-likely-compositions theorem is small enough to
see whole, the four compositions of the 3 extra gems and their
richest holdings in the table below, and the recursion compresses
exactly that average. At the state (a,b) = (2,3) the two
coefficients are `C(2,0)*C(2,1)/C(4,3) = 2/4` and
`C(2,1)*C(2,0)/C(4,3) = 2/4`, so `g(2,3) = 1 + 0.5*g(2,1) +
0.5*g(1,2)`. The branch `g(1,2)` is the everyone-counts base, a <=
r, where the total holding is the deterministic `a + b = 3`, and
`g(2,1)` folds once more with its single coefficient
`C(2,1)*C(0,0)/C(2,1) = 1`, giving `g(2,1) = 1 + 1*g(1,0) =
1 + 1 = 2`. So `g(2,3) = 1 + 0.5*2 + 0.5*3 = 3.5`, the same average the
four compositions hand out,
and the trace ends at the printed answer `3.5`.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*extra gems*], [*holdings*], [*richest holds*]),
  [(3,0)], [(4,1)], [4],
  [(2,1)], [(3,2)], [3],
  [(1,2)], [(2,3)], [3],
  [(0,3)], [(1,4)], [4],
  [expectation], [4 compositions], [(4+3+3+4)/4 = 3.5],
)

#listing("icpc/samples-c/src/Ch09/pD.c", first: 17, last: 36, caption: [c: the memoized G over `seen` and `memo`, binomials through the lnfact header's lnC])

#listing("icpc/samples/src/Ch09/PD.cs", first: 12, last: 46, caption: [c\#: local function LnC over an inline table, recursion G with the same guard rails])

#listing("icpc/samples-go/ch09/pd.go", first: 26, last: 54, caption: [go: the closure g over a `-1`-filled memo table, exponent guard at -700])

#listing("icpc/samples-js/src/ch09-pd-gemisland.mjs", first: 12, last: 35, caption: [javascript: solve with the imported lnC, one flat Float64Array memo])

#listing("icpc/samples-py/src/Ch09/pd.py", first: 14, last: 44, caption: [python: the table filled by increasing b so the recursion never nests, lnC inline])

#listing("icpc/samples-lua/ch09_pd.lua", first: 13, last: 40, caption: [lua: the required lnfact module, flat `(n+1)x(d+1)` memo, allocation-free inner loop])

The fixture `3 2 1` walks all six compositions of 2 extra gems over 3
islanders, the (3,1,1) family three times and the (2,2,1) family three
times, so the richest holds 3 or 2 and the expectation is exactly
`2.5000000`. The suites pin that value and the three official samples
as printed-tolerance cases: four CHECKs in c, two [Fact] methods in
c\# whose second runs all three samples, four table cases in go, four
assertions in javascript, four checks in python, four `T.eq` blocks in
lua, the shared extras being all-counted, single-islander, and small
split cases. Integer notes are the warning instead of a divergence:
the raw binomials must never be built, `C(999,500)` sits near 1e299
and overflows a double before any division, which is the entire reason
the helper exists.

#diagram([the fixture's six compositions as bar stacks, the richest islander's holding shaded, expectation 2.5 across the family], length: 12pt, {
  let stack(x, h1, h2, h3, top) = {
    // bars bottom-up with heights proportional to holdings, h1 the
    // top islander (the richest, shaded), every stack summing to n+d
    let u = 0.31
    let y = 3.2
    for (i, h) in (h3, h2, h1).enumerate() {
      let shade = if i == 2 { luma(200) } else { luma(238) }
      cdraw.rect((x, y), (x + 2.4, y + h * u), fill: shade, stroke: luma(180), radius: 0.01)
      y += h * u
    }
    cdraw.content((x + 1.2, 5.5), top, size: 6.5pt)
  }
  stack(1.0, 3, 1, 1, [3])
  stack(4.0, 3, 1, 1, [3])
  stack(7.0, 3, 1, 1, [3])
  stack(10.0, 2, 2, 1, [2])
  stack(13.0, 2, 2, 1, [2])
  stack(16.0, 2, 2, 1, [2])
  cdraw.content((1.0, 6.6), [family (3,1,1), three orders], size: 6pt, fill: luma(100), anchor: "west")
  cdraw.content((18.4, 6.6), [family (2,2,1), three orders], size: 6pt, fill: luma(100), anchor: "east")
  cdraw.line((9.7, 2.8), (9.7, 1.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.2, 1.8), [(3+3+3+2+2+2) / 6 = 2.5], size: 6.5pt, anchor: "west")
})

== problem E: getting a jump on crime

Robin the superhero patrols the hometown by jumping from roof to
roof, and the hometown is a square grid of dx by dy blocks, each block
one w by w meter building with its own height. Every jump goes from
the center of one roof to the center of another, not necessarily
adjacent, leaves the ground at one fixed takeoff speed v whose
horizontal and vertical components trade off as `vd^2 + vh^2 = v^2`,
flies with constant horizontal velocity under gravity
g = 9.80665 m/s^2 with the cape handling air resistance, and may not
collide with any building along the way, where a jump passing over a
corner at which four buildings meet must clear all four. Robin picks
the takeoff angle and cannot change direction mid-air, so from the
secret hideout's roof the task is the minimum jump count to every
other roof, or X when no chain of jumps reaches it
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is one line of six integers by the problemset pdf, dx, dy,
w, v, and the hideout coordinates lx, ly, with 1 <= dx, dy <= 20, the
building width 1 <= w <= 10^3 meters, the takeoff velocity
1 <= v <= 10^3 meters per second, and 1 <= lx <= dx, 1 <= ly <= dy,
then dy lines of dx non-negative integer heights in meters, each at
most 10^3, line j carrying buildings (1, j) through (dx, j). The pdf
guarantees the answers would not change if any building's height
moved by up to 1e-6, so borderline geometry never occurs. The output
is dy lines of dx values in input order, each the minimum jump count
from the hideout or X, under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`E-gettingjump/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and draws in its cross-section figure: with 100 m
blocks and v = 55 the flat range is 3025/9.80665 = 308.46 m, so the
300 m jump from the height 10 hideout roof to the far roof exists, its
green arc in the figure clearing the 40 m and 60 m roofs mid-flight,
and every roof costs one jump.

input:

```
4 1 100 55 1 1
10 40 60 10
```

expected output:

```
0 1 1 1
```

Recognition: dx and dy at most 20 mean at most 400 roofs and 79800
ordered pairs, each pair's feasibility one quadratic and each
clearance walk O(dx+dy) binding instants, 3.2*10^6 checks inside
the 2 second limit, an O(dx^3 dy^3) worst case of 6.4*10^7 that
still fits, so the budget invites enumerating every roof pair
outright.

The cue is the physics sentence, one fixed takeoff speed whose
components trade off, which hands each jump's feasibility to a
quadratic in the takeoff angle, finitely many critical candidates
per pair instead of a continuum of arcs. Problem E is the 2018
face of the geometric critical-point enumeration family, and the
same geometric critical-point enumeration cue drives chapter 08
problem A, chapter 08 problem D, chapter 09 problem G, chapter 11
problem T, and chapter 12 problem D; a secondary thread, bfs on
the implicit jump graph, covers reaching the door once jump
feasibility is known.

The priced-out wrong tool is a continuous search over takeoff
angles, fine sampling or ternary search per pair: the clearance
margin along an arc family has no single peak to converge on, and
79800 pairs times a 1000-step angle scan times the 40-instant walk
is 3.2*10^9 float evaluations, an order past the limit for nothing
the closed form does not give exactly.

The jump graph connects two roof centers when a parabola clears every
other building. The takeoff condition is a quadratic in
`x = vd^2/v^2`, read off the height equation
`dh = (d/vd)*sqrt(v^2 - vd^2) - g*d^2/(2*vd^2)`: the steeper arc is
the one that matters, and the managed languages recover it through the
larger root and the
root product because the smaller root itself cancels catastrophically
when the roots straddle 0 and 1, while c solves for `vd^2` directly and
takes the smaller root, and c\# front-loads the closed-form existence
test `v^2 >= g*(hypot(d,dh)+dh)` and still solves the quadratic for
the arc it flies, in every case leaning on the fact that the steepest
feasible arc sits pointwise above every other (solutions.pdf pp. 6-7).
Concavity makes the first and last instant
over each footprint the binding checks, the graph build costing
O(dx^2 dy^2 (dx+dy)) or O(dx^3 dy^3), and a breadth-first search
over the resulting graph is the whole solver past that.

The worked run: trace the model on sample 1. The hideout roof sits
at height 10 with the row's other centers 100, 200 and 300 meters
out at heights 40, 60 and 10, v = 55 gives `v^2 = 3025`, and the
existence test `v^2 >= g*(hypot(d,dh)+dh)` prices each jump in one
line. Roof 2: `hypot(100,30) = sqrt(10900) = 104.403`, so
`9.80665*(104.403+30) = 1318.0 <= 3025`. Roof 3: `hypot(200,50) =
sqrt(42500) = 206.155`, so `9.80665*(206.155+50) = 2512.1 <=
3025`. Roof 4: `hypot(300,0) = 300`, so `9.80665*300 = 2942.0 <=
3025`. All three jumps exist from the hideout, the steepest arc
clearing the 40 m and 60 m footprints mid-flight by concavity, so
the bfs opens all three roofs at depth 1 and no roof needs a
second jump, and the trace ends at the printed answer `0 1 1 1`.

#diagram([sample 1's cross-section: all three jumps exist from the height 10 hideout, the steepest arcs clearing the 40 m and 60 m roofs mid-flight], length: 12pt, {
  let cx(m) = 1.2 + m * 0.0455
  let roof(m, h) = {
    cdraw.rect((cx(m) - 0.55, 4.0), (cx(m) + 0.55, 4.0 + h * 0.033), fill: luma(238), stroke: luma(160))
  }
  roof(50, 10)
  roof(150, 40)
  roof(250, 60)
  roof(350, 10)
  cdraw.line((1.2, 4.0), (18.2, 4.0), stroke: luma(170))
  let top(h) = 4.0 + h * 0.033
  let arc(m2, h2, peak) = {
    for t in range(16) {
      let x0 = cx(50) + (cx(m2) - cx(50)) * t / 15
      let y0 = 4.33 + (top(h2) - 4.33) * t / 15 + peak * (4 * t * (15 - t)) / 225.0
      let x1 = cx(50) + (cx(m2) - cx(50)) * (t + 1) / 15
      let y1 = 4.33 + (top(h2) - 4.33) * (t + 1) / 15 + peak * (4 * (t + 1) * (14 - t)) / 225.0
      cdraw.line((x0, y0), (x1, y1), stroke: luma(50))
    }
  }
  arc(150, 40, 1.5)
  arc(250, 60, 3.4)
  arc(350, 10, 4.8)
  cdraw.content((cx(50), 3.5), [0], size: 6pt)
  cdraw.content((cx(150), 3.5), [1], size: 6pt)
  cdraw.content((cx(250), 3.5), [1], size: 6pt)
  cdraw.content((cx(350), 3.5), [1], size: 6pt)
  cdraw.content((1.2, 8.6), [heights 10 40 60 10, all three existence tests pass under v^2 = 3025], size: 6.5pt, anchor: "west")
})

#listing("icpc/samples-c/src/Ch09/pE.c", first: 20, last: 42, caption: [c: launch_vd solves the quadratic for `vd^2` and takes the smaller root, arc_y evaluates the parabola])

#listing("icpc/samples/src/Ch09/PE.cs", first: 84, last: 131, caption: [c\#: the closed-form existence test, steepest arc `y0 + a*s - b*s^2`, slab clipping per footprint])

#listing("icpc/samples-go/ch09/pe.go", first: 76, last: 123, caption: [go: canJump with the stable-root recovery and the two binding instants per footprint])

#listing("icpc/samples-js/src/ch09-pe-gettingjump.mjs", first: 43, last: 84, caption: [javascript: the same canJump, endpoint clearance at 1e-6 as the statement's stability bound demands])

#listing("icpc/samples-py/src/Ch09/pe.py", first: 39, last: 79, caption: [python: `_can_jump` with the product-of-roots recovery, bounding-box footprint scan])

#listing("icpc/samples-lua/ch09_pe.lua", first: 22, last: 56, caption: [lua: can_jump over the shared clip_cell, 1-based grid arithmetic throughout])

The fixture is one flat row, `4 1 120 55 1 1` with all heights 0, so
only range matters: flat-ground reach is `v^2/g = 308.46` m, roofs sit
120, 240, and 360 m out, the first two jumps exist and a flat-to-flat
parabola stays strictly above zero between its ends, and the expected
output is `0 1 1 2`. Suites: three CHECKs in c, three [Fact] methods
in c\#, five table cases in go, five assertions in javascript, five
checks in python, five `T.eq` blocks in lua, the shared extras a
beyond-range tower, a wall between neighbors, a step-up past the apex,
and a mid-row hideout. No integer notes, every value is a double and
g is the statement's 9.80665 exactly, with the 1e-6 endpoint slack
justified by the statement's own perturbation guarantee.

#diagram([cross-section of the flat fixture: the 240 m parabola exists, the 360 m attempt falls to the ground at the 308.46 m range limit], length: 12pt, {
  // roof centers at 60, 180, 300, 420 m, scaled to x
  let cx(m) = 1.2 + m * 0.0425
  let roof(m) = {
    cdraw.rect((cx(m) - 0.5, 4.0), (cx(m) + 0.5, 5.2), fill: luma(238), stroke: luma(160))
  }
  roof(60)
  roof(180)
  roof(300)
  roof(420)
  cdraw.line((1.2, 4.0), (19.5, 4.0), stroke: luma(170))
  // the 240 m parabola from roof 0 to roof 2, arcing above both
  for t in range(21) {
    let x0 = cx(60) + (cx(300) - cx(60)) * t / 20
    let y0 = 5.2 + 3.0 * (4 * t * (20 - t)) / 400.0
    let x1 = cx(60) + (cx(300) - cx(60)) * (t + 1) / 20
    let y1 = 5.2 + 3.0 * (4 * (t + 1) * (19 - t)) / 400.0
    cdraw.line((x0, y0), (x1, y1), stroke: luma(50))
  }
  // the 360 m attempt, dashed: aimed at roof 3, it falls to the
  // ground at the 308.46 m range limit, short of roof 3's far side
  let gx = cx(60) + (cx(420) - cx(60)) * 308.46 / 360.0
  for t in range(20) {
    let x0 = cx(60) + (gx - cx(60)) * t / 20
    let y0 = 5.2 + (4.0 - 5.2) * t / 20 + 2.2 * (4 * t * (20 - t)) / 400.0
    let x1 = cx(60) + (gx - cx(60)) * (t + 1) / 20
    let y1 = 5.2 + (4.0 - 5.2) * (t + 1) / 20
    let y1 = y1 + 2.2 * (4 * (t + 1) * (19 - t)) / 400.0
    cdraw.line((x0, y0), (x1, y1), stroke: (paint: luma(130), dash: "dashed"))
  }
  cdraw.content((cx(60), 2.9), [0], size: 6pt)
  cdraw.content((cx(180), 2.9), [1], size: 6pt)
  cdraw.content((cx(300), 2.9), [2], size: 6pt)
  cdraw.content((cx(420), 2.9), [3], size: 6pt)
  cdraw.line((cx(60), 8.9), (cx(420), 8.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((cx(60), 9.3), [0 m], size: 6pt)
  cdraw.content((cx(180), 9.3), [120], size: 6pt)
  cdraw.content((cx(300), 9.3), [240], size: 6pt)
  cdraw.content((cx(420), 9.3), [360], size: 6pt)
  cdraw.content((1.2, 1.5), [flat range v^2/g = 308.46 m, the 360 m jump does not exist], size: 6.5pt, anchor: "west")
})

== problem F: go with the flow

Typesetters call a river a string of spaces between words that runs
down several lines of text, and celebrated river authority Flo Ng
wants her rivers-of-the-world book to contain the longest typographic
rivers possible. The text is set in a monospaced font, left-aligned in
a column of some fixed width, words packed as tightly as possible on
each line, never split across lines, with exactly one space between
words and no right alignment, and the width is ours to choose, at
least as long as the longest word. For Flo a river is a sequence of
spaces in consecutive lines where each space after the first sits at
most one column away from the space in the line above, trailing
whitespace never joins one. Find the width that produces the longest
river, the smallest such width on ties, and print the width and the
river length
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is one integer n, 2 <= n <= 2500 words by the problemset
pdf, then the words on the following lines, letters only, a single
space between words on the same line, and no word longer than 80
characters. The output is one line, the winning width, a space, and
the longest river's length, under the pdf's 12 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`F-gowithflow/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and sets twice in its own figure: the 21-word
Yangtze text wraps at width 15 into a river of 5, one longer than
width 14 manages, so the answer is 15 5.

input:

```
21
The Yangtze is the third longest
river in Asia and the longest in
the world to flow
entirely in one country
```

expected output:

```
15 5
```

Recognition: n <= 2500 words of at most 80 letters under the 12
second limit, and the naive all-widths sweep costs theta(n^2 L^2)
column steps, `2500^2 * 80^2 = 4*10^10`, which time-limits, so the
budget itself forces the sweep's two prunes, the line-count stop
and the jump between wrap-changing widths.

The cue is the phrase the width is ours to choose, a single scalar
parameter whose every value runs one full greedy simulation, the
one-dimensional answer-space search shape over the widths from the
longest word upward. Problem F is the 2018 face of the
one-dimensional answer-space search family, and the same
one-dimensional answer-space search cue drives chapter 08 problem
E and chapter 13 problem C.

The priced-out alternative is the unpruned sweep itself, every
width from 81 to the whole text on one line each re-wrapping all
2500 words, 4*10^10 column steps at the bound against the pruned
sweep's few dozen wrap-changing widths, each still one linear
river pass.

Wrapping is greedy, and the naive sweep over all widths costs
theta(n^2 L^2) for L the longest word and time-limits, so the pinned
vehicle carries the sketch's first and third fixes together: stop once
the best river reaches the current line count, since wider widths only
shrink the line count, and jump straight to the next width that
changes the wrap, the smallest width at which any line would take one
more word (solutions.pdf p. 7). Per width the river is one column dp
pass, a space at column c of line k continuing any space at `c-1`,
`c`, or `c+1` of line k-1.

The worked run: trace the model on sample 1. At the winning width
15 the greedy wrap packs the printed 21 words into eight lines,
each line the most words that fit, `The Yangtze is` at 14 columns,
`the third` at 9, `longest river` at 13, `in Asia and the` at 15,
`longest in the` at 14, `world to flow` at 13, `entirely in one`
at 15 and `country`, and the interior space columns per line are
listed below. The column dp then walks them: the column 8 chain
runs line 3 to line 5 at lengths 1, 2 and 3, steps to column 9 for
line 6 at 4, holds column 9 for line 7 at 5, and every other
column dies earlier, the column 4 chain at 2, the column 12
restart at 2, the column 3 restart at 1, so the river is 5. The
widths below 15 top out at 4, width 14's own count in the sample
walkthrough, and past 15 the wrap's line count only shrinks toward
5, where the stop rule ends the sweep with the best still 5, so
the smallest winning width holds,
and the trace ends at the printed answer `15 5`.

#table(
  columns: (auto, 1.2fr, auto, auto),
  inset: 4pt,
  table.header([*line*], [*packed words*], [*space columns*], [*river ending on the line*]),
  [1], [The Yangtze is], [4, 12], [1],
  [2], [the third], [4], [2],
  [3], [longest river], [8], [1],
  [4], [in Asia and the], [3, 8, 12], [2],
  [5], [longest in the], [8, 11], [3],
  [6], [world to flow], [6, 9], [4],
  [7], [entirely in one], [9, 12], [5],
  [8], [country], [none], [0],
)

#listing("icpc/samples-c/src/Ch09/pF.c", first: 100, last: 126, caption: [c: the width sweep with both prunes, wrap computing the next wrap-changing width as a side effect])

#listing("icpc/samples/src/Ch09/PF.cs", first: 39, last: 89, caption: [c\#: WrapRiver returns lines, river, and the next width, per-line space columns listed while wrapping])

#listing("icpc/samples-go/ch09/pf.go", first: 72, last: 109, caption: [go: riverOf, the touched-column reset trick keeping the two row arrays reusable])

#listing("icpc/samples-js/src/ch09-pf-gowithflow.mjs", first: 58, last: 91, caption: [javascript: solve with the line-count stop and the merge-threshold jump])

#listing("icpc/samples-py/src/Ch09/pf.py", first: 27, last: 58, caption: [python: `_river`, the same touched-column reset, one line of dp per space])

#listing("icpc/samples-lua/ch09_pf.lua", first: 27, last: 52, caption: [lua: river_of over sparse tables, `prev[c] = nil` instead of a zeroing pass])

The fixture is six alternating words `aa bbb` where width 6 wraps to
three identical lines whose single spaces all sit in column 3, a river
of 3, while widths 3 to 5 put one word per line with no spaces at all
and widths from 8 pack at least two words per line, capping the line
count at 3, so the answer is `6 3`. Suites: three CHECKs in c, three
[Fact] methods in c\#, four table cases in go, four assertions in
javascript, four checks in python, four `T.eq` blocks in lua, the
shared extras a two-word forced space, a single word with river 0, and
a tall column of one-letter words. No integer notes, everything is a
length and a column index well inside every machine word.

#diagram([the fixture at width 6: three lines, one space each, all in column 3, a river of length 3, against the degenerate width-5 wrap beside it], length: 12pt, {
  let row(x, y, t, hot) = {
    cdraw.rect((x, y), (x + 6.4, y + 1.0), fill: if hot { luma(245) } else { luma(250) }, stroke: luma(190), radius: 0.02)
    cdraw.content((x + 1.1, y + 0.5), [aa], size: 6.5pt)
    cdraw.rect((x + 2.5, y + 0.12), (x + 3.3, y + 0.88), fill: luma(140), radius: 0.01)
    cdraw.content((x + 4.7, y + 0.5), [bbb], size: 6.5pt)
  }
  row(1.0, 8.4, [aa bbb], true)
  row(1.0, 7.0, [aa bbb], true)
  row(1.0, 5.6, [aa bbb], true)
  cdraw.line((3.7, 5.6), (3.7, 9.4), stroke: luma(60), mark: (start: "|", end: "|"))
  cdraw.content((4.6, 10.2), [width 6: river 3], size: 6.5pt)
  let drow(x, y, t) = {
    cdraw.rect((x, y), (x + 3.4, y + 0.8), fill: luma(250), stroke: luma(190), radius: 0.02)
    cdraw.content((x + 0.3, y + 0.4), t, size: 6pt)
  }
  drow(12.4, 9.4, [aa])
  drow(12.4, 8.3, [bbb])
  drow(12.4, 7.2, [aa])
  drow(12.4, 6.1, [bbb])
  drow(12.4, 5.0, [aa])
  drow(12.4, 3.9, [bbb])
  cdraw.content((14.1, 2.6), [width 5: one word per line, no spaces], size: 6pt, fill: luma(100))
})

== problem G: panda preserve

Sichuan province has funding for the Great Panda National Park, a
preserve for more than 1800 giant pandas surrounded by a polygonal
fence, and every panda will wear a wireless transmitter. Researchers
place one receiver at each vertex of the enclosing polygon, every
receiver covers a circular area of one shared range centered on
itself, and smaller receivers are cheaper. Find the smallest range
that covers the entire park
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is one integer n, 3 <= n <= 2000 vertices by the problemset
pdf, then n lines of two integers x and y with |x|, |y| <= 10^4, the
polygon's vertices in counter-clockwise order. The pdf promises a
simple polygon, every vertex distinct, and no two edges intersecting
or touching except consecutive edges at their common vertex. The
output is the minimum wireless range, an absolute or relative error of
at most 1e-6 accepted, under the pdf's 10 second limit, and the
harness verifies it in float mode, `2018/G` pinned to `float` in
`ref/icpc/compare.json`.

Official sample 1, reprinted byte for byte from the judge data pair
`G-pandapreserve/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and draws at ranges 35 and 50 in its own figure:
the pentagon's critical point is (100,0) on the bottom edge, exactly
50 from the two plateau vertices (60,30) and (140,30), so here the
covering radius is decided by a voronoi edge crossing a polygon edge
rather than by an interior voronoi vertex like the fixture's center.

input:

```
5
0 0
170 0
140 30
60 30
0 70
```

expected output:

```
50
```

Recognition: n <= 2000 vertices under the 10 second limit prices
the per-vertex cell build at O(n^2 log n), 4*10^6 bisector clips
behind an 11-entry sort each, about 4.4*10^7 comparisons, and the
crossing tests add O(n^2), so enumerating both candidate families
per vertex is the affordable shape.

The cue is smallest range that covers the entire park, an extremal
covering radius, attained at finitely many critical points,
interior voronoi vertices and voronoi-polygon edge crossings, the
enumerate-and-test shape over O(n^2) geometric candidates. Problem
G is the 2018 face of the geometric critical-point enumeration
family, and the same geometric critical-point enumeration cue
drives chapter 08 problem A, chapter 08 problem D, chapter 09
problem E, chapter 11 problem T, and chapter 12 problem D.

Sampling the park instead is the priced-out wrong tool: a 2000 by
2000 grid over the 10^4 coordinate range resolves 10-unit cells,
four orders too coarse for the 1e-6 tolerance, and refining to
10^-3 spacing is a 2*10^13-point scan, while a boundary-only scan
misses the interior voronoi vertices outright.

Receivers sit at every vertex and cover the disc of radius r around
themselves, so the covering radius is the largest over park points of
the distance to the nearest vertex, attained either at a voronoi
vertex of the polygon's vertices that lies inside the polygon or where
a voronoi edge crosses a polygon edge. Each solver builds every
vertex's cell by clipping a box against the perpendicular bisectors of
the other vertices, nearest first with a distance-ordered early break,
then tests those two candidate families, O(n^2 log n) for the cell
build and O(n^2) for the crossing tests (solutions.pdf pp. 7-9). Book
7's chapter 37, computational geometry ii, develops the half-plane
intersection this per-vertex clipping rests on. This is the problem
that forced a year-local geometry helper, cross products, ray-cast
point-in-polygon, segment intersection, and the half-plane clip,
because no wave 1 toolbox carried 2d vector algebra.

The worked run: trace the model on sample 1. The plateau vertices
(60,30) and (140,30) share the perpendicular bisector `x = 100`,
and that bisector crosses the bottom edge from (0,0) to (170,0) at
(100,0), on the park's boundary, so it is a crossing candidate.
Its covering radius is `sqrt(40^2 + 30^2) = sqrt(2500) = 50` from
either plateau vertex, and the two voronoi vertices on the same
bisector fall outside the park: with (0,0) the bisector `2x + y =
75` meets `x = 100` at (100,-125), with (0,70) the bisector
`3x - 2y = -10` meets it at (100,155), above the top edge. Every
other cell peaks lower, the left-edge crossing of the
(0,0)-(0,70) bisector `y = 35` answers 35 and the
(170,0)-(140,30) cut `y = x - 140` meets the bottom edge 30 out at
(140,0), so the binding candidate is the edge crossing at (100,0),
and the trace ends at the printed answer `50`.

#diagram([sample 1's pentagon: the plateau bisector x = 100 crosses the bottom edge at (100,0), exactly 50 from both plateau vertices, both triple points on the bisector falling outside], length: 12pt, {
  let px(x) = 2.2 + x * 0.085
  let py(y) = 2.6 + y * 0.085
  cdraw.line((px(0), py(0)), (px(170), py(0)), stroke: luma(60))
  cdraw.line((px(170), py(0)), (px(140), py(30)), stroke: luma(60))
  cdraw.line((px(140), py(30)), (px(60), py(30)), stroke: luma(60))
  cdraw.line((px(60), py(30)), (px(0), py(70)), stroke: luma(60))
  cdraw.line((px(0), py(70)), (px(0), py(0)), stroke: luma(60))
  cdraw.line((px(100), py(-0.8)), (px(100), py(66)), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((px(100) + 0.2, py(63)), [bisector x = 100], size: 6pt, anchor: "west")
  cdraw.line((px(100), py(0)), (px(60), py(30)), stroke: luma(30))
  cdraw.line((px(100), py(0)), (px(140), py(30)), stroke: luma(30))
  cdraw.content((px(88), py(13)), [sqrt(2500)], size: 6.5pt, fill: luma(40))
  cdraw.circle((px(100), py(0)), radius: 0.16, fill: luma(20))
  cdraw.content((px(100), py(-1.6)), [(100,0)], size: 6pt, anchor: "north")
  cdraw.content((px(60), py(31.5)), [(60,30)], size: 6pt, anchor: "south")
  cdraw.content((px(140), py(31.5)), [(140,30)], size: 6pt, anchor: "south")
  cdraw.content((px(0), py(-1.6)), [(0,0)], size: 6pt, anchor: "north")
  cdraw.content((px(170), py(-1.6)), [(170,0)], size: 6pt, anchor: "north")
  cdraw.content((px(0), py(72)), [(0,70)], size: 6pt, anchor: "south")
})

#listing("icpc/samples-c/src/Ch09/pG.c", first: 38, last: 85, caption: [c: the per-vertex cell build by g2clip against a big box, then in-park cell vertices as candidates])

#listing("icpc/samples/src/Ch09/PG.cs", first: 41, last: 64, caption: [c\#: clip by the algebraic half-plane `f(p) <= 0`, candidates from crossings and in-polygon circumcenters])

#listing("icpc/samples-go/ch09/pg.go", first: 38, last: 88, caption: [go: the box comment, nearest-first clipping with the early break, both candidate scans])

#listing("icpc/samples-js/src/ch09-pg-pandapreserve.mjs", first: 12, last: 60, caption: [javascript: solve importing clipCell, pointInPoly, segIntersect from the ch09-geo module])

#listing("icpc/samples-py/src/Ch09/pg.py", first: 95, last: 141, caption: [python: the same solve with the geometry inlined, per-site sorted neighbors and the box])

#listing("icpc/samples-lua/ch09_pg.lua", first: 24, last: 75, caption: [lua: distance-squared rank-packing into one exact integer sort key, then the shared clip loop])

The fixture is the 10 by 6 rectangle, whose four nearest-corner
quadrants meet at the center, so the answer is the half diagonal
`sqrt(34) = 5.830951895`, printed `%.9f`. Suites: three CHECKs in c,
two [Fact] methods in c\# whose second runs all three official
samples, four table cases in go, four assertions in javascript, four
checks in python, and four `T.eq` blocks in lua, the shared extras a
square, a thin strip peaking at `50.002499938`, and a right triangle
whose peak sits on the hypotenuse. Integer notes: the input coordinates
are integers and the distances are doubles everywhere, and lua packs
`(dx^2+dy^2) * 2048 + id` into one sort key that stays exact as an
integer, where a float key could tie-break wrongly at these
magnitudes.

#diagram([the fixture rectangle: the four voronoi cells meet at the center, the covering radius is the half diagonal sqrt(34)], length: 12pt, {
  // 10 x 6 rectangle scaled 1.35, corner at (3, 3.4)
  let bx(x) = 3.0 + x * 1.35
  let by(y) = 3.4 + y * 1.35
  cdraw.rect((bx(0), by(0)), (bx(10), by(6)), stroke: luma(60), fill: luma(250))
  cdraw.line((bx(5), by(0)), (bx(5), by(6)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((bx(0), by(3)), (bx(10), by(3)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((bx(5), by(3)), radius: 0.3, fill: luma(120))
  cdraw.content((bx(5) + 0.5, by(3) + 0.3), [center], size: 6pt, anchor: "west")
  cdraw.line((bx(5), by(3)), (bx(0), by(0)), stroke: luma(40))
  cdraw.content((bx(3.6), by(0.5)), [sqrt(34) = 5.830951895], size: 6.5pt, fill: luma(40))
  cdraw.content((bx(0), by(0) - 0.7), [(0,0)], size: 6pt, anchor: "north")
  cdraw.content((bx(10), by(0) - 0.7), [(10,0)], size: 6pt, anchor: "north")
  cdraw.content((bx(0), by(6) + 0.7), [(0,6)], size: 6pt, anchor: "south")
  cdraw.content((bx(10), by(6) + 0.7), [(10,6)], size: 6pt, anchor: "south")
  cdraw.content((bx(5), by(6) + 1.6), [each quadrant's farthest point from its corner is the center], size: 6pt, fill: luma(100))
})

== problem H: single cut of failure

The Intrusion and Crime Prevention Company is bidding to guard the
room holding next year's World Finals problem set, a room with a
single door and no other exits, defended against window rappels, air
ducts, impersonated contest directors, and attack submarines by wiring
the door itself: sensors on the four sides, pairs joined by straight
wires, and any still-connected pair sounds the alarm when the door
opens. The one design flaw is that an intruder might cut the wires
first, and assessing that threat is the task: n wires cross the
rectangular door, each anchored at integer points on two different
sides, never at a corner, all anchor locations distinct. A cut is a
straight line segment that starts and ends on different sides of the
door and stays at least 1e-6 away from every wire anchor and every
corner, and a minimum-size set of cuts must intersect every wire
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is one line with n, w, and h by the problemset pdf,
1 <= n <= 10^6 wires on a door of width 1 <= w <= 10^8 and height
1 <= h <= 10^8, then n lines of four integers x1, y1, x2, and y2 with
0 <= x1, x2 <= w and 0 <= y1, y2 <= h, the two anchor points of one
wire. Each wire connects two different sides, no wire is anchored at
any of the four corners, and all locations in the input are distinct.
The output is the number of cuts, then one cut per line as
`x1 y1 x2 y2`, the coordinates may be real, cuts may appear in any
order and each cut's endpoints in either order, any minimum-size set
accepted, under the pdf's 6 second limit. The harness grades this
problem on its first line, `2018/H` pinned to `first-line` in
`ref/icpc/compare.json`, the cut lines beside the count accepted as
one valid witness.

Official sample 1, reprinted byte for byte from the judge data pair
`H-single/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints beside its door figure: one cut from (0,4) on the left side
to (4,3) on the right crosses all four wires, so the minimum is 1.

input:

```
4 4 6
0 1 4 4
0 5 2 0
0 3 3 6
2 6 4 2
```

expected output:

```
1
0 4 4 3
```

Recognition: n <= 10^6 wires under the 6 second limit prices one
sort of the 2*10^6 anchors plus a linear two-pointer window, about
4*10^7 comparisons with the fold, and any per-pair geometry over
wires, `10^12` pairwise intersections, is dead on arrival.

The cue is the reformulation the statement invites: a cut is an
arc once the boundary is unrolled onto a perimeter circle, and it
splits exactly the wires with one anchor strictly inside, so the
whole task becomes one sweep over sorted anchor positions. Problem
H is the 2018 face of the event sweep over a sorted axis family,
and the same event sweep over a sorted axis cue drives chapter 09
problem A, chapter 10 problem D, chapter 10 problem J, and chapter
13 problem L.

The priced-out alternative is treating cuts as arbitrary segments
and searching a minimum line cover over 10^6 wires, pairwise
candidate generation alone costing `5*10^11` pairs, while a
per-wire interval formulation loses the arc structure that makes
the one-cut test a single window.

Wires cross a rectangular door anchored at integer points on two
different sides, and an intruder cuts them with straight segments that
start and end on different sides, keeping 1e-6 clearance from every
anchor and corner. Unrolling the boundary to a perimeter circle turns
a cut into an open arc: it crosses exactly the wires with one anchor
strictly inside the arc, one cut suffices iff some arc splits every
wire, and the sweep over sorted anchors finds it with a two-pointer
window that never lets a wire fall fully inside, O(n log n)
(solutions.pdf pp. 9-10). The candidate endpoints are the midpoints of
the open gaps between consecutive anchors, in quarter units, with a
midpoint landing exactly on a door corner shifted a quarter forward,
and the one-cut acceptance additionally demands endpoints on different
door sides.

Two corner rules in that acceptance are the story of this problem, and
all six languages landed the same fix family for them. First, a gap
that strictly contains a corner lets its endpoint sit on either side
of that corner, so only gaps lying strictly inside one side carry a
side label, and the wrap gap between the last and first anchor always
strictly contains ring corner 0 because anchors never sit at corners,
so it always straddles even when no midpoint corner lies inside:
labeling it single-side under-reports single cuts, 113 of 6000
mismatches against a quarter-grid brute, and the regression door
`2 10 10` with anchors `0 3 5 0` and `7 0 8 0` is the pinned witness,
one cut from `0 0.25` to `7.5 0`, its s endpoint snapped one quarter
past corner 0 onto the left side. A wrap midpoint landing exactly one
lap, which is corner 0 again, reduces modulo the ring before the
corner test. Second, the witness render snaps: a straddling endpoint
whose gap midpoint happens to render on the same side as the other
endpoint slides one quarter past its contained corner onto the
differing side, so the two printed endpoints really differ.

The worked run: trace the model on sample 1. The 4 by 6 door has
perimeter `2*(4+6) = 20`, and unrolling counter-clockwise from
corner (0,0) puts the eight printed anchors at ring positions: wire
1's (0,1) at `20-1 = 19` and (4,4) at `4+4 = 8`, wire 2's (0,5) at
15 and (2,0) at 2, wire 3's (0,3) at 17 and (3,6) at `14-3 = 11`,
wire 4's (2,6) at `14-2 = 12` and (4,2) at 6. The sweep slides a
window that never contains both anchors of one wire, and the
winning arc runs from the midpoint of gap (15,17), position 16,
wrapping forward to the midpoint of gap (6,8), position 7. Inside
that arc sit anchors 17, 19, 2 and 6, one per wire, wire 1's 19,
wire 2's 2, wire 3's 17, wire 4's 6, so a single arc splits all
four wires, zero cuts never guards anything with wires present,
and the minimum is 1. The arc's endpoints render back on the
boundary as (0,4) on the left side and (4,3) on the right side,
`20-4 = 16` and `4+3 = 7`, two different sides,
and the trace ends at the printed answer `0 4 4 3`.

#diagram([sample 1's anchors unrolled on the perimeter ring: the winning arc from midpoint 16 wraps past corner 0 to midpoint 7 and holds exactly one anchor of each wire], length: 12pt, {
  let px(p) = 1.6 + p * 0.82
  cdraw.line((px(0), 6.4), (px(20), 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((px(16), 6.4), (px(20), 7.5), fill: luma(205), radius: 0.02)
  cdraw.rect((px(0), 6.4), (px(7), 7.5), fill: luma(205), radius: 0.02)
  for p in (2, 6, 8, 11, 12, 15, 17, 19) {
    cdraw.line((px(p), 6.1), (px(p), 6.7), stroke: luma(100))
    cdraw.content((px(p), 5.6), [#p], size: 6pt)
  }
  cdraw.content((px(20), 7.9), [wrap], size: 6pt, anchor: "south")
  cdraw.content((px(0), 5.0), [0], size: 6pt)
  cdraw.content((px(20), 5.0), [20], size: 6pt)
  cdraw.content((px(16), 8.2), [endpoint 16, left side (0,4)], size: 6pt, anchor: "south")
  cdraw.content((px(7), 8.2), [endpoint 7, right side (4,3)], size: 6pt, anchor: "south")
  cdraw.content((px(10), 3.9), [arc holds 17, 19, 2, 6: one anchor per wire, count 1], size: 6.5pt)
  cdraw.content((px(10), 3.0), [wire 1: 19 and 8, wire 2: 15 and 2, wire 3: 17 and 11, wire 4: 12 and 6], size: 6pt, fill: luma(110))
})

#listing("icpc/samples-c/src/Ch09/pH.c", first: 109, last: 147, caption: [c: gap midpoints with the one-lap reduction, corner-straddle flags, and the wrap gap forced to straddle])

#listing("icpc/samples/src/Ch09/PH.cs", first: 25, last: 65, caption: [c\#: the same gap table in x4 units, corner4 test, wrap rule last])

#listing("icpc/samples-go/ch09/ph.go", first: 56, last: 99, caption: [go: gapAfter, gapSingle, gapCorner, gapSide, with the wrap-gap block verbatim])

#listing("icpc/samples-js/src/ch09-ph-single.mjs", first: 94, last: 139, caption: [javascript: the window sweep, the differ-sides test, and the witness snap past the corner])

#listing("icpc/samples-py/src/Ch09/ph.py", first: 98, last: 145, caption: [python: the same sweep and snap, quarter formatter, two-cut fallback])

#listing("icpc/samples-lua/ch09_ph.lua", first: 49, last: 88, caption: [lua: the gap classification in quarter units, wrap rule included])

The fixture is two wires crossing at the center of a 4 by 6 door, both
split by the vertical cut through the crossing, expected
`1\n2 0 2 6\n`. The suites pin that fixture, the two-cut fallback for
parallel wires, a half-unit gap midpoint, a single wire, and three
parallel wires cut at the middle gap: three CHECKs in c, five [Fact]
methods in c\#, six table cases in go, six assertions in the
javascript node:test file, six checks in python, and six `T.eq` blocks
in lua, and the wrap-gap regression door above is a pinned case in all
six suites. Integer notes: everything runs in
quarter-unit integer arithmetic, coordinates and the ring fit int64,
javascript's plain Numbers are exact at these magnitudes, and the
clearance is structural, gap midpoints stay at least a quarter unit
from every integer anchor and corner, so no epsilon ever appears.

#diagram([the fixture door with its crossing wires and the winning vertical cut, and below it the boundary unrolled with the winning arc shaded], length: 12pt, {
  // door 4 x 6 scaled 1.4 at (2.0, 6.2)
  cdraw.rect((2.0, 6.2), (7.6, 14.6), stroke: luma(60), fill: luma(252))
  cdraw.line((2.0, 7.6), (7.6, 13.2), stroke: luma(90))
  cdraw.line((2.0, 13.2), (7.6, 7.6), stroke: luma(90))
  cdraw.line((4.8, 6.2), (4.8, 14.6), stroke: luma(40), mark: (start: "|", end: "|"))
  cdraw.content((4.8, 15.2), [cut x = 2], size: 6pt)
  cdraw.content((1.6, 7.6), [1], size: 6pt, anchor: "east")
  cdraw.content((1.6, 13.2), [5], size: 6pt, anchor: "east")
  cdraw.content((8.0, 7.6), [5], size: 6pt, anchor: "west")
  cdraw.content((8.0, 13.2), [1], size: 6pt, anchor: "west")
  // unrolled perimeter 0..20 below, anchors at 5, 9, 15, 19
  let px(p) = 11.0 + p * 0.44
  cdraw.line((px(0), 9.4), (px(20), 9.4), stroke: luma(100))
  for p in (5, 9, 15, 19) {
    cdraw.line((px(p), 9.1), (px(p), 9.7), stroke: luma(100))
    cdraw.content((px(p), 8.4), [#p], size: 6pt)
  }
  cdraw.rect((px(2), 9.4), (px(12), 10.1), fill: luma(205), radius: 0.02)
  cdraw.content((px(7), 10.7), [arc s=2 to t=12, both wires split], size: 6pt)
  cdraw.content((px(0), 7.6), [0], size: 6pt)
  cdraw.content((px(20), 7.6), [20], size: 6pt)
})

== problem I: triangles

The trip to Beijing comes with plenty of puzzle books, and the puzzle
is the oldest one in them: how many triangles are in the picture? The
picture here is an ascii rendering of a triangular lattice with r rows
and c columns of vertices. Every vertex is marked `x`, a horizontal
unit edge between neighboring vertices is three dashes, and a diagonal
unit edge is one `/` or one `\`, on staggered vertex rows: picture
lines 1, 5, 9, and so on carry vertices in columns 1, 5, 9, and so on,
picture lines 3, 7, 11 carry vertices in columns 3, 7, 11, and the
even lines between carry the diagonal edge characters exactly between
the vertices they join. Count every triangle of any size whose sides
are straight grid lines
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is two integers r and c by the problemset pdf, 1 <= r <=
3000 vertex rows and 1 <= c <= 6000 vertex columns, then 2r-1 picture
lines of at most 2c-1 characters each, spaces everywhere except the
`x` vertices, the dash triples of horizontal edges, and the single
slash or backslash of each diagonal edge. The pdf notes that trailing
whitespace on a line may be omitted, which is why the leading blanks
carry the geometry. The output is the single count of triangles of any
size, under the pdf's 6 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`I-triangles/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: the top dashes and the two upper diagonals close
one downward triangle, the bottom vertex row carries no dashes so the
upward orientation never forms, and the count is 1.

input:

```
3 3
x---x
 \ /
  x
 / \
x   x
```

expected output:

```
1
```

Recognition: r <= 3000 and c <= 6000 mean 1.8*10^7 vertices under
the 6 second limit, the run tables cost one O(rc) pass, and each
row's order statistic is an O(log c) fenwick step per corner,
about 2.3*10^8 tree touches across both orientations, inside the
budget only because the sweep is linear past the sort.

The cue is the count-every-triangle wording over an ascii lattice,
a count over an implicit family far larger than any listing of
triangles, and the sheared-grid recurrence turns it into run
lengths plus an order statistic with scheduled removals. Problem I
is the 2018 face of the counting and expectation without
enumeration family, and the same counting and expectation without
enumeration cue drives chapter 09 problem D, chapter 11 problem Q,
chapter 12 problem E, and chapter 12 problem K.

Brute force prices out plainly: every corner at every size is
`r*c*min(r,c) = 5.4*10^10` candidate triangles at the bound, each
verified against runs, thirty times the budget even at one
nanosecond per candidate.

Shearing the staggered grid turns one diagonal family
vertical, a corner with an s-step horizontal run and an s-step
same-family diagonal run forms a triangle exactly when the opposite
family's run from the far base end covers s steps, and the count per
row is an order statistic over active base ends with scheduled
removals, O(n^2 log n) over both orientations, the second counted by
the mirrored sweep (solutions.pdf pp. 10-11). The pictures are ragged,
leading spaces are significant and trailing spaces may be gone, so
every parser reads raw lines by position, never by token.

The worked run: trace the model on sample 1. The picture puts two
vertices on the top row, the apex between on the middle row and two
on the bottom row, and the run tables read straight off the printed
characters: the top dashes give one horizontal run of one step, the
bottom row prints no dashes at all, so its horizontal runs are
empty, and each diagonal family carries the two one-step runs the
printed slashes draw through the apex. The downward sweep opens at
the top row's left corner: it holds an s = 1 horizontal run and an
s = 1 same-family diagonal run, and the opposite family's run from
the far base end covers 1 step, so the sweep counts exactly one
triangle, the apex-closing one the picture draws. The upward sweep
needs a bottom horizontal run to open any corner and finds none,
the bare dash row kills every one, so the total is 1 + 0,
and the trace ends at the printed answer `1`.

#diagram([sample 1's lattice: the one downward triangle the sweep counts, the bottom row's missing dash run killing the upward orientation], length: 12pt, {
  let v(x, y) = {
    cdraw.circle((x, y), radius: 0.16, fill: luma(70))
  }
  v(3.0, 9.8)
  v(11.0, 9.8)
  v(7.0, 6.4)
  v(3.0, 3.0)
  v(11.0, 3.0)
  cdraw.line((3.0, 9.8), (11.0, 9.8), stroke: luma(40), width: 0.8)
  cdraw.line((3.0, 9.8), (7.0, 6.4), stroke: luma(40), width: 0.8)
  cdraw.line((11.0, 9.8), (7.0, 6.4), stroke: luma(40), width: 0.8)
  cdraw.line((3.0, 3.0), (7.0, 6.4), stroke: luma(120))
  cdraw.line((11.0, 3.0), (7.0, 6.4), stroke: luma(120))
  cdraw.content((7.0, 7.9), [counted: 1], size: 6.5pt, fill: luma(40))
  cdraw.content((7.0, 2.2), [no dashes printed here, the upward corner never opens], size: 6pt, fill: luma(110), anchor: "north")
})

#listing("icpc/samples-c/src/Ch09/pI.c", first: 100, last: 135, caption: [c: the sweep with chained scheduled adds and removals over the fenwick header])

#listing("icpc/samples/src/Ch09/PI.cs", first: 127, last: 156, caption: [c\#: Sweep, the shared engine both orientations call, expiry lists bucketed by firing column])

#listing("icpc/samples-go/ch09/pi.go", first: 149, last: 175, caption: [go: countRightDown's row pass, a fresh fenwick9 per row, removals fired off a sorted list])

#listing("icpc/samples-js/src/ch09-pi-triangles.mjs", first: 93, last: 135, caption: [javascript: countRightDown with the inlined Fenwick9 class, run tables filled bottom-up])

#listing("icpc/samples-py/src/Ch09/pi.py", first: 73, last: 116, caption: [python: pass 1 with an integer bitmask replacing the fenwick, window counts by `bit_count`])

#listing("icpc/samples-lua/ch09_pi.lua", first: 114, last: 140, caption: [lua: the fenwick sweep with removals bucketed per firing column instead of a sort])

Five languages answer the order statistic with the year-local fenwick
helper, point add and prefix sum over shifted columns, and python
replaces it with a big-int bitmask over the row, activation and
removal as bit sets and clears, and the window count as a shift plus
`bit_count`, which is the same data structure wearing python's
arbitrary-precision integers. The fixture is the three-row picture
that carries exactly one triangle per orientation, expected `2\n`:
the top dashes plus the two upper diagonals close a downward triangle,
the bottom dashes plus the two lower diagonals close an upward one,
and no two-step straight run exists. Suites: one CHECK in c on the
fixture, three [Fact] methods in c\#, four table cases in go, four
assertions in javascript, four checks in python, four `T.eq` blocks in
lua, the shared extras a lattice with only horizontals, an empty
lattice of bare vertices, and long dashes without diagonals. Integer
notes: the count reaches 1.1e11, int64 in c, c\#, go, and lua, and
javascript's plain Numbers stay exact below 2^53 so nothing special is
needed.

#diagram([the fixture rendered as a lattice: one downward triangle and one upward triangle share the middle apex], length: 12pt, {
  let v(x, y) = {
    cdraw.circle((x, y), radius: 0.16, fill: luma(70))
  }
  // vertex rows: two outer rows of two vertices, the staggered apex between
  v(3.0, 9.8)
  v(11.0, 9.8)
  v(7.0, 6.4)
  v(3.0, 3.0)
  v(11.0, 3.0)
  // edges: horizontal runs on the outer rows, diagonals through the apex
  cdraw.line((3.0, 9.8), (11.0, 9.8), stroke: luma(70))
  cdraw.line((3.0, 3.0), (11.0, 3.0), stroke: luma(70))
  cdraw.line((3.0, 9.8), (7.0, 6.4), stroke: luma(70))
  cdraw.line((11.0, 9.8), (7.0, 6.4), stroke: luma(70))
  cdraw.line((3.0, 3.0), (7.0, 6.4), stroke: luma(70))
  cdraw.line((11.0, 3.0), (7.0, 6.4), stroke: luma(70))
  cdraw.content((7.0, 11.1), [downward triangle: top dashes plus the upper two diagonals], size: 6pt, anchor: "south")
  cdraw.content((7.0, 1.7), [upward triangle: bottom dashes plus the lower two diagonals], size: 6pt, anchor: "north")
  cdraw.content((14.5, 6.4), [input: `x---x`, ` \ /`, `  x`, ` / \`, `x---x`], size: 6.5pt, anchor: "west")
})

== problem J: uncrossed knight's tour

The classic puzzle tours every square of an 8 by 8 chessboard with a
knight, no repeats, ending back at the start. This harder version runs
on a rectangular m by n board, a knight jump being one square in one
direction and two in an orthogonal direction, and imagines the path as
the straight line segments joining the centers of consecutive squares:
those segments must form a simple polygon, no two of them crossing or
touching except consecutive segments at their shared endpoint, and the
knight must still return to its starting square. The no-crossing
constraint makes visiting every square impossible, so the task is the
maximum number of squares one closed, non-crossing tour can visit, 0
when no such tour exists at all
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is a single line with two integers by the problemset pdf, m
and n, 1 <= m <= 8 and 1 <= n <= 10^15. The output is the largest
number of squares a knight can visit in a tour that does not cross its
own path, or 0 if no such tour exists, under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`J-uncrossedknights/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints with its figure of an optimal tour: 12 squares of
the 6 by 6 board close one simple polygon.

input:

```
6 6
```

expected output:

```
12
```

Official sample 2, same source, reprinted because it is the transpose
witness: `v(8,3) = 6 = v(3,8)`, the one official sample whose answer
per-m tables looked up without swapping the dimensions get wrong.

input:

```
8 3
```

expected output:

```
6
```

Recognition: m <= 8 but n <= 10^15 under a 2 second limit, so no
per-query dp over columns can ever run, 10^15 columns times even
one profile state is 10^17 transitions, five orders past the
budget, and the only affordable shape is a table built offline plus
an O(1) lookup with cycle extrapolation.

The cue is the pair of bounds itself, one dimension tiny and one
astronomical, which forces an engineered compact state per row,
visitation kind, vertical jump pattern, canonicalized
connectivity, whose values fall into a cycle `v(n+P) = v(n)+A` once
the window is deep enough. Problem J is the 2018 face of the dp
over an engineered state space family, and the same dp over an
engineered state space cue drives chapter 10 problem I, chapter 11
problem S, chapter 12 problem J, and chapter 13 problem H.

The priced-out alternative is running that profile dp at judge
time or searching tours directly, and the contest itself priced
it: no team accepted the problem, and the official solution
literally says precompute locally then submit a table.

A knight tours an m by n board visiting as many squares as possible in
a closed loop whose straight jump segments never cross or touch, and
the count is wanted for n up to 1e15, which is why nobody solved it at
the finals and why the official solution is literally precompute
locally then submit a table (solutions.pdf pp. 11-12). The derivation
is a broken-profile dp over rows, state mixing visitation kind,
vertical jump pattern, and canonicalized connectivity, run offline
until each width's values fall into a cycle `v(n+P) = v(n)+A`, and the
shipped solvers are exactly that final step: per-m base tables plus
cycle extrapolation, one algorithm and one table shared by all six
languages, with every value cross-checked against all 277 judge cases.

One correction to the naive table model is load-bearing: boards
transpose, `v(m,n) = v(n,m)`, so the transpose happens before any
lookup, and `v(8,3) = 6 = v(3,8)` is the one official sample the
unswapped tables get wrong. Width 7 hides the other surprise, its
cycle runs period 33 with add 142, and width 8 has no linear closed
form at all, `v(17) = 80` and `v(19) = 92` both sit below any
`6n - c` line, so the table window plus the cycle is the whole
answer.

The worked run: trace the model on sample 1. The query is m = 6,
n = 6, the transpose leaves it unchanged, and the width-6 branch
reads its base window: n <= 15, so the answer is the table entry
`j6_base[6-3]`, the value 12, with the cycle machinery idle. The
regime boundary checks in one step on each side: the window's last
entry `j6_base[12] = 46` serves n = 15, and the linear law `4n -
14` gives `4*15 - 14 = 46` there, so beyond the window the formula
continues the table seamlessly. The entry itself is what the
offline dp froze, the 12-square simple polygon of the section's
figure, and the trace ends at the printed answer `12`.

#table(
  columns: (auto, 1fr, 1fr),
  inset: 4pt,
  table.header([*width m*], [*base window*], [*beyond the window*]),
  [3], [0 below 5, then 4 at n = 5], [period 4, add 4, phases -2, -2, 2, 2],
  [4], [0 below 4], [`2n - 4` from n = 4],
  [5], [`j5_base`, n = 3 to 14], [add 26 per 10],
  [6], [`j6_base`, n = 3 to 15], [`4n - 14`],
  [7], [`j7_base`, n = 3 to 65], [add 142 per 33],
  [8], [`j8_base`, n = 4 to 19], [add 36 per 6],
)

#listing("icpc/samples-c/src/Ch09/ch09_jtable.h", first: 20, last: 66, caption: [c: jtour, transpose first, per-m base arrays, cycle extrapolation by one division])

#listing("icpc/samples/src/Ch09/PJ.cs", first: 25, last: 74, caption: [c\#: V over embedded tables, the Cycle helper reducing past the window with one division])

#listing("icpc/samples-go/ch09/ch09_jtable.go", first: 30, last: 75, caption: [go: knightTour, the switch over m with each cycle's period and add])

#listing("icpc/samples-js/src/ch09-jtable.mjs", first: 20, last: 56, caption: [javascript: knightTour, values stay under 2^53 so plain Numbers carry them exactly])

#listing("icpc/samples-py/src/Ch09/pj.py", first: 97, last: 135, caption: [python: `_tour`, the same tables and cycles embedded in the solver])

#listing("icpc/samples-lua/ch09_jtable.lua", first: 21, last: 53, caption: [lua: jt.tour, 1-based table indexing, floor division in the extrapolation])

The fixture is the official sample `6 6`, expected `12\n`, and
optimality is not hand-provable, the offline dp is the only witness,
so the suites pin the sample plus the other official boards and one
extrapolation case drawn from judge data: five CHECKs in c, two [Fact]
methods in c\# whose first runs all four official samples, five table
cases in go, five assertions in javascript, five checks in python,
five `T.eq` blocks in lua, the transpose case `8 3` at 6, `7 20` at
80, `2 6` at 0, and `3 1000000000000000` at 999999999999998. Integer
notes: values reach 6e15, int64 in the native languages, and
javascript documents the bound instead of switching types, plain
Numbers are exact below `2^53 = 9.007e15` and `v(8, 10^15) =
5999999999999980` stays under it.

#diagram([the 6 x 6 board with a 12-square uncrossed closed tour, found by search and pinned here as one simple polygon], length: 12pt, {
  let cell(c, r) = (2.2 + c * 1.5, 2.2 + (5 - r) * 1.5)
  // grid
  for i in range(7) {
    cdraw.line((2.2 + i * 1.5, 2.2), (2.2 + i * 1.5, 11.2), stroke: luma(200))
    cdraw.line((2.2, 2.2 + i * 1.5), (11.2, 2.2 + i * 1.5), stroke: luma(200))
  }
  let tour = ((0,0), (1,2), (2,4), (4,5), (5,3), (3,4), (4,2), (2,3), (3,1), (5,2), (4,0), (2,1))
  for i in range(tour.len()) {
    let a = cell(..tour.at(i))
    let nxt = if i + 1 == tour.len() { 0 } else { i + 1 }
    let b = cell(..tour.at(nxt))
    cdraw.line(a, b, stroke: luma(40))
  }
  for sq in tour {
    cdraw.circle(cell(..sq), radius: 0.18, fill: luma(40))
  }
  cdraw.content((6.7, 12.4), [12 squares, every jump a knight move, no two segments crossing or touching], size: 6.5pt)
  cdraw.content((6.7, 1.2), [v(6,6) = 12, the table's pinned optimum], size: 6pt, fill: luma(100))
})

== problem K: wireless is the new fiber

A new unbounded-bandwidth wireless technology is replacing the
struggling fiber network. The old network is a set of n nodes and m
fiber links, each link joining two different nodes, with at least one
route between every pair of nodes and sometimes several links between
the same pair for bandwidth. The replacement uses as few wireless
links as possible while keeping exactly one way to travel between
every pair of nodes, and every node was built with its current number
of connections in mind: a node whose link count changes must be
reorganized, which is costly. Design the new network so the fewest
nodes change their number of connections, and print the count plus any
achieving layout
(#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[statement]).

The input is two integers n and m by the problemset pdf, 2 <= n <=
10^4 nodes numbered 0 to n-1 and 1 <= m <= 10^5 fiber links, then m
lines of two distinct integers a and b, the endpoints of one link,
with the pdf guaranteeing a path between every pair of nodes. The
output is the smallest number of nodes whose link count changes, then
a line with the node count and the wireless link count, then the links
in the input's own format, any valid layout accepted, under the pdf's
2 second limit. The harness grades this problem on its first line,
`2018/K` pinned to `first-line` in `ref/icpc/compare.json`, any
achieving tree passing beside the count.

Official sample 1, reprinted byte for byte from the judge data pair
`K-newfiber/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints with its before and after figures, the answer
file's final blank line included in the bytes: the seven degrees are
4, 5, 5, 1, 1, 3, 3, the two degree-3 raises cost 2 each and fit
inside the n-2 = 5 spare budget while neither degree-5 raise fits
after them, so exactly three nodes change, nodes 1, 2, and 5 in the
printed layout.

input:

```
7 11
0 1
0 2
0 5
0 6
1 3
2 4
1 2
1 2
1 5
2 6
5 6
```

expected output:

```
3
7 6
0 1
0 2
0 5
0 6
3 6
4 6

```

Recognition: n <= 10^4 nodes and m <= 10^5 links under the 2
second limit price the whole job at one degree sort plus one fifo
build, `10^4 log 10^4` comparisons and a linear pass, with the
counting argument, tree degrees sum to 2n-2, doing all the real
work.

The cue is the double objective, fewest wireless links and fewest
nodes whose link count changes, and the second reduces to handing
out the n-2 spare degree increments cheapest-first, a local rule
made safe by the exchange argument that any kept set of size k
costs at least the k cheapest increments. Problem K is the 2018
face of the greedy with a safety proof family, and the same greedy
with a safety proof cue drives chapter 08 problem H, chapter 10
problem A, and chapter 12 problem H.

The priced-out alternative is searching over subsets of nodes to
keep, `2^10000` subsets, or building the tree by min-cost flow with
degree bonuses, 10^4 nodes of flow against a sort, both paying
orders more for an answer the exchange argument certifies
directly.

A connected multigraph on n nodes is to be replaced by a tree, a node
is happy when its tree degree equals its old degree, and the task is
the fewest unhappy nodes plus any achieving tree. Only the input
degrees matter: a tree's degrees are at least 1 and sum to 2n-2, so
after the mandatory 1 per node there are n-2 spare increments, handing
them out to keep degrees cheapest-first, by `(d_i - 1, id)` ascending,
maximizes the kept set because any kept set of size k costs at least
the k cheapest increments, and a leftover budget dumps onto one changed
node (solutions.pdf pp. 12-13). The tree then builds by adding nodes
in decreasing target degree, ties by id, onto a fifo of outstanding
slots.

The worked run: trace the model on sample 1. The eleven printed
links give degrees 4, 5, 5, 1, 1, 3 and 3 for nodes 0 through 6,
a tree needs `2n-2 = 12` degree units against the mandatory 7, so
`n-2 = 5` spare increments, and keeping node i costs `d_i - 1` of
them. Cheapest first, nodes 3 and 4 cost 0 each, nodes 5 and 6
cost 2 each, spending 4 of 5, and the next keep, node 0, costs 3
more, 7 against 5, so at most four nodes keep their degrees and
the count is `7 - 4 = 3`. The printed witness spends the same
budget the other way, keeping nodes 0, 3, 4 and 6 for `3 + 0 + 0
+ 2 = 5`, exactly the whole budget with no leftover to raise, and
its six edges give node 0 degree 4, node 6 degree 3 and the rest
1, precisely those targets, any such fifo tree accepted beside the
first-line count, and the trace ends at the printed answer `4 6`.

#table(
  columns: (auto, auto, auto, 1.1fr),
  inset: 4pt,
  table.header([*node*], [*input degree*], [*keep cost `d-1`*], [*printed witness*]),
  [0], [4], [3], [kept, degree 4],
  [1], [5], [4], [changed, degree 1],
  [2], [5], [4], [changed, degree 1],
  [3], [1], [0], [kept, degree 1],
  [4], [1], [0], [kept, degree 1],
  [5], [3], [2], [changed, degree 1],
  [6], [3], [2], [kept, degree 3],
)

#listing("icpc/samples-c/src/Ch09/pK.c", first: 55, last: 84, caption: [c: the cheapest-first keep loop over the id-sorted order, then the leftover rho raise])

#listing("icpc/samples/src/Ch09/PK.cs", first: 21, last: 62, caption: [c\#: keep order as one long key, the raise, and the LinkedList fifo attach])

#listing("icpc/samples-go/ch09/pk.go", first: 33, last: 68, caption: [go: the keep-set sort and budget walk, the raise for leftover budget])

#listing("icpc/samples-js/src/ch09-pk-newfiber.mjs", first: 19, last: 60, caption: [javascript: keep-set, raise, and the fifo construction in one pass])

#listing("icpc/samples-py/src/Ch09/pk.py", first: 18, last: 44, caption: [python: the whole solver, sort by degree then id, fifo of `[node, remaining]`])

#listing("icpc/samples-lua/ch09_pk.lua", first: 44, last: 93, caption: [lua: target fill, keep walk, raise, and the two-array fifo])

The fixture is a 4-cycle where every node has degree 2, so every keep
costs one increment and the budget `n-2 = 2` keeps exactly nodes 0 and
1, three keeps would cost 3, and the targets are `[2,2,1,1]` with no
leftover: expected count 2 and the edges `0 1`, `0 2`, `1 3`. Suites:
two CHECKs in c, five [Fact] methods in c\#, four table cases in go,
four assertions in javascript, six checks in python, six `T.eq` blocks
in lua, the shared extras a path and a star that are already happy
trees at count 0 and a five-cycle, with python and lua additionally
validating the five-cycle's output structurally, spanning, hanging off
the root, and counting two. No integer notes, degrees and counts sit
far below every machine word.

#diagram([the input 4-cycle beside the constructed tree, the two changed nodes shaded], length: 12pt, {
  let n(x, y, t, ch) = {
    cdraw.circle((x, y), radius: 0.62, fill: if ch { luma(200) } else { luma(240) }, stroke: luma(110))
    cdraw.content((x, y), t, size: 6.5pt)
  }
  n(2.6, 9.6, [0], false)
  n(7.0, 11.6, [1], false)
  n(11.4, 9.6, [2], true)
  n(7.0, 7.6, [3], true)
  cdraw.line((2.6, 9.6), (7.0, 11.6), stroke: luma(140))
  cdraw.line((7.0, 11.6), (11.4, 9.6), stroke: luma(140))
  cdraw.line((11.4, 9.6), (7.0, 7.6), stroke: luma(140))
  cdraw.line((7.0, 7.6), (2.6, 9.6), stroke: luma(140))
  cdraw.content((7.0, 12.9), [input, every degree 2], size: 6pt)
  cdraw.line((13.0, 9.6), (15.4, 9.6), stroke: luma(100), mark: (end: ">"))
  n(16.6, 11.2, [0], false)
  n(16.6, 8.0, [1], false)
  n(20.6, 11.2, [2], true)
  n(20.6, 8.0, [3], true)
  cdraw.line((16.6, 11.2), (16.6, 8.0), stroke: luma(60))
  cdraw.line((16.6, 11.2), (20.6, 11.2), stroke: luma(60))
  cdraw.line((16.6, 8.0), (20.6, 8.0), stroke: luma(60))
  cdraw.content((18.6, 12.9), [tree, targets 2,2,1,1, two changed], size: 6pt)
})

== across the six languages

The same eleven problems, solved six times each, and the table reads
the year off the solvers' own choices:

#table(
  columns: (auto, 1fr, 1.4fr, 1.2fr),
  inset: 4pt,
  table.header([*language*], [*size*], [*integer vehicle*], [*suite*]),
  [c], [11 solvers, 1979 lines, plus 192 lines of year headers], [`long long` everywhere, run-length heaps with multiplicities in C, quarter units in H], [33 CHECKs across 11 self-checks],
  [c\#], [11 solvers, 1233 lines, 329 test lines], [`long`, big integers never needed this year], [34 [Fact] methods],
  [go], [package ch09, 1948 lines including the test table], [`int64` exact, one hand-rolled `itoa64`], [50 table cases],
  [javascript], [11 solvers and 3 modules, 1561 lines, 347 test lines], [`BigInt` accumulator in C, exact BigInt64 time ranks in A, plain Numbers below 2^53 elsewhere], [47 assertions in node:test],
  [python], [11 solvers, 1499 lines], [native int, the I bitmask replacing the fenwick], [52 checks],
  [lua], [11 solvers and 4 modules, 1765 lines], [int64 exact, rank-packed sort keys in G], [52 T.eq blocks],
)

Two divergences shaped the year. Problem A's 1e18 timestamps forced
javascript to rank times exactly before sorting while the other five
sorted native integers, and problem C's 2.5e17 cost ceiling forced the
BigInt accumulator in javascript alone. Everywhere else the six
languages agreed on the arithmetic, and the disagreements were
structural instead: union-find against stack closure in B, four takes
on one quadratic in E, a fenwick against a bitmask in I, and two
inline table styles in D and G where the compiled languages reached
for helper files. 268 suite assertions stand behind the chapter, 33 in
c, 34 test methods in c\#, 50 cases in go, 47 assertions in
javascript, 52 checks in python, and 52 `T.eq` blocks in lua, counted
from the frozen sources, not estimated.

sources: ICPC Foundation, icpc.global, the 2018 problemset at
#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[icpc2018.pdf]
and the solution sketches at
#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/finals2018solutions.pdf")[finals2018solutions.pdf],
both accessed 2026-09-14 and cached under `ref/icpc/2018/` with sha256
digests in `ref/icpc/INDEX.md`. The solutions pdf is the algorithm
reference for every method and complexity claim in this chapter, cited
where used. Judge data is local-only under `ref/icpc/2018/data/`,
never committed, 931 input files mapped to answer pairs by the
committed `ref/icpc/verify-data.ps1`, and every sample pair reprinted
in this chapter is the byte-exact content of that problem's
`sample-N.in` and `sample-N.ans` files, attributed in place, with the
float-tolerant answers of A, D, and G and the any-layout outputs of H
and K graded through the non-exact compare modes recorded in
`ref/icpc/compare.json`. The committed suites carry the reader with
crafted fixtures whose expectations are derived in the prose beside
them.
