// book 10, chapter 12: icpc world finals 2023, problems A through K,
// six languages per problem, listings sliced from the frozen solver
// files under books/icpc/samples*
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= icpc world finals 2023

The 47th world finals were played in Luxor concurrently with the 46th,
which is why this set of 11 problems lettered A through K shares five
problem names with the 2022 set of chapter 11 under different letters,
A doubling 2022's W, C doubling V, D doubling T, G doubling P, and J
doubling S. The problemset is
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf],
and every algorithm and complexity claim in this chapter is settled
against the official solutions pdf rather than reinvented. The
solutions pdf also carries the contest statistics: E was solved by 0
teams and was the judges' pick as the hardest problem, J by exactly 1
team at minute 292, B by 7, K by 11, C by 30, F by 26, D by 86, H by
96, I by 110, G by 117, and A by 120. NRU Higher School of Economics
took the title, and the field wrote 98.5 percent of its submissions in
C++ with about 1 percent python and no java at all, a flat opposite of
this book's six-way spread. This chapter walks all 11 problems in
letter order, one section per letter, six listings per section, c
through lua, every listing sliced from a solver file that ran against
the official judge data held locally under `ref/icpc/`.

== the year-local helpers: the sphinx oracle, ordered subsets, score hulls, pyramid vectors, failure functions, and the go scan cursor

Five helper kits are year-local to this chapter, one per problem
that wanted one, plus the go package's shared scan cursor, and
everything else the year's solvers import comes from the wave 1
toolbox chapters 2 through 7. Each kit states its contract and
prints its twin files below in the book's fixed language order. The
C solvers parse through chapter 11's `ch11_scan.h` rather than a
year-local twin, so that cursor prints in chapter 11's helper
section and only go adds a new file for it here. The go judge lane
`pjfast.go`, the twin of chapter 11's `psfast.go`, stays
deliberately unlisted: it is problem J's measured engine, not a
helper.

The sphinx kit backs problem A and is the interesting one, because
it encodes the judge contract for the set's only interactive
problem: the file names the true leg counts, the lying round, and
the additive lie, and `ask` simulates her five answers so the
deduction core stays a pure function of the answer vector. C
carries the struct and its two calls in `Ch12/ch12_sphinx.h` on top
of chapter 11's scan header, javascript exports a factory
returning the ask closure, python a class, and lua a module whose
init walks the file bytes itself. C\# and go carry no twin file:
both read the judge file directly inside their problem A solvers,
the C\# `Solve` answering from line 4 and go's `SolveA` building
the five answers inline.

#listing("icpc/samples-c/src/Ch12/ch12_sphinx.h", first: 15, last: 36, caption: [c, sphinx_init parses the fixed judge file, sphinx_ask answers truth plus the one lie on its round])

#listing("icpc/samples-js/src/ch12-sphinx.mjs", first: 1, last: 16, caption: [javascript, the same contract as a factory returning the ask closure])

#listing("icpc/samples-py/src/Ch12/ch12_sphinx.py", first: 5, last: 17, caption: [python, the Sphinx class, ask adding the delta exactly on the lying round])

#listing("icpc/samples-lua/ch12_sphinx.lua", first: 43, last: 60, caption: [lua, sphinx.init reads the five integers past the header word, sphinx.ask bakes in the one lie])

The combinatorics kit backs problem B with a multiplicative
binomial and a lexicographic k-subset enumerator that stops after m
emissions, ascending position tuples, which is descending
lexicographic order on the indicator strings. C's `ch12_comb.h`
drives a callback emitter, javascript's `firstSubsets` collects
arrays, python's `first_subsets` the same tuples, and lua's
`comb.emit` visits without allocating. C\# and go carry no twin
file: the C\# solver enumerates all 2^(k-1) masks and sorts them
descending, and go's `gen` recursion tries the 1 branch first so it
emits descending lexicographic order naturally.

#listing("icpc/samples-c/src/Ch12/ch12_comb.h", first: 9, last: 41, caption: [c, ch12_binom plus ch12_emit, ascending position tuples, which is descending lexicographic on the indicator strings])

#listing("icpc/samples-js/src/ch12-comb.mjs", first: 4, last: 31, caption: [javascript, binom plus firstSubsets, the m-capped recursion in ascending subset order])

#listing("icpc/samples-py/src/Ch12/ch12_comb.py", first: 5, last: 31, caption: [python, binom with the min(k, n-k) fold, first_subsets advancing one position tuple at a time])

#listing("icpc/samples-lua/ch12_comb.lua", first: 8, last: 38, caption: [lua, comb.binom plus comb.emit, the visitor handed each ascending tuple without allocation])

The hull kit backs problem C: a monotone upper chain over sorted
doubled points plus the two halfplane queries the dice need, the
best y at x <= X and the best x at y >= Y, edges interpolating. C
and python carry chain and queries together in `Ch12/ch12_hull.h`
and `ch12_hull.py`, while the javascript and lua twins carry only
the chain, the full counterclockwise monotone hull in
`ch12-hull.mjs` and the upper chain over parallel arrays in
`ch12_hull.lua`, the two queries living inside their problem C
solvers. C\# and go inline both pieces in the solver files.

#listing("icpc/samples-c/src/Ch12/ch12_hull.h", first: 18, last: 60, caption: [c, the upper hull over sorted doubled points, then max y at x <= X and min x at y >= Y with edge interpolation])

#listing("icpc/samples-js/src/ch12-hull.mjs", first: 4, last: 27, caption: [javascript, monotoneHull, the deduped sort and the two popped chains closing the loop])

#listing("icpc/samples-py/src/Ch12/ch12_hull.py", first: 4, last: 45, caption: [python, upper_hull plus max_y_under and min_x_above, both queries interpolating the straddling edge])

#listing("icpc/samples-lua/ch12_hull.lua", first: 7, last: 25, caption: [lua, hull.upper over parallel coordinate arrays, popping non-strict clockwise turns])

The geometry kit backs problem D with the pyramid primitives:
vector algebra, the cross product, closed-segment intersection with
endpoint tolerance, and strict containment in a convex polygon. C's
`Ch12/ch12_geom.h` also folds in the reflection across a line and
the line-crossing parameter, go keeps one small `pd_geo.go` with
the same predicates in relative tolerances, javascript the same as
arrow functions, while the python and lua twins carry the flat
point algebra, the quarter turn and the cross, with the
intersection and containment inlined in their solvers. C\# embeds
its copies in the `MinLeg` machinery of its problem D solver.

#listing("icpc/samples-c/src/Ch12/ch12_geom.h", first: 12, last: 49, caption: [c, the 2d kit: vector ops, reflection, line-crossing parameter, strict containment])

#listing("icpc/samples-go/ch12/pd_geo.go", first: 22, last: 68, caption: [go, geoSegHitG with relative tolerances and the clamped meeting parameter, geoInsideG strict against a CCW polygon])

#listing("icpc/samples-js/src/ch12-geom.mjs", first: 16, last: 46, caption: [javascript, gCross, segHit rejecting parallel overlaps, insideStrict with the relative bound])

#listing("icpc/samples-py/src/Ch12/ch12_geom.py", first: 7, last: 32, caption: [python, the tuple algebra: sub through l90 and cross, the pyramid walk's atoms])

#listing("icpc/samples-lua/ch12_geom.lua", first: 5, last: 31, caption: [lua, the flat scalar pairs, l90 through len, cross2d reading ccw positive])

The string kit backs problem F: the failure function, an
all-occurrence search, and the minimal period F runs on doubled
cycle strings. The four twins agree on the interface, C's
`Ch12/ch12_kmp.h` reporting hits through a callback, javascript and
python returning positions, lua 1-based with the failure table
reused between calls. C\# and go carry no twin file: the C\#
`CycMatch` walks its own failure function and go's `cycMatch`
closure builds its table inline.

#listing("icpc/samples-c/src/Ch12/ch12_kmp.h", first: 9, last: 41, caption: [c, failure function, all-occurrence search, and the minimal period F uses on doubled cycles])

#listing("icpc/samples-js/src/ch12-kmp.mjs", first: 5, last: 31, caption: [javascript, kmpFail, kmpFindAll through the hit callback, kmpMinPeriod off the last border])

#listing("icpc/samples-py/src/Ch12/ch12_kmp.py", first: 3, last: 34, caption: [python, fail, find_all yielding every overlapping hit, min_period from the last border])

#listing("icpc/samples-lua/ch12_kmp.lua", first: 7, last: 45, caption: [lua, kmp.fail 1-based, kmp.find_all calling hit per occurrence, kmp.min_period])

The scan kit is the go package's io contract, one file the whole
year shares: `scan12` walks the input buffer with a whitespace
`token`, a signed `nextInt`, and `line` for the fixed-line judge
files, the same cursor design chapter 10 named and chapter 11
printed for C. Ten of the eleven go solvers parse through it,
everything but the sphinx's four-line fixed file, which `SolveA`
splits directly.

#listing("icpc/samples-go/ch12/ch12.go", first: 5, last: 53, caption: [go, scan12: token skips whitespace in place, nextInt folds a signed value, line reads through the next newline])

== a, riddle of the sphinx

This is the 2022 W task back under a new letter, and the judge files
for the two years are byte-identical. The statement reverses the
classic riddle: name the number of legs of an axex, a basilisk, and a
centaur, each an unknown nonnegative integer, and instead of guessing
you may ask the sphinx five questions. A question is a triple (a, b,
c), how many legs do a axexes, b basilisks, and c centaurs have in
total, and she answers each with a single integer. The catch is that
sphinxes are tricky: at most one of her five answers may be an
outright lie, and you do not know which one, so the task is to choose
five questions that pin the three leg counts regardless.

This is the set's only interactive problem. There are exactly five
rounds: each round the program writes one line of three integers a,
b, and c with 0 <= a, b, c <= 10 by the problems pdf, then reads her
answer, one integer r with 0 <= r <= 1e5. After the fifth round the
program prints one line of three space-separated nonnegative
integers, the leg counts of the axex, the basilisk, and the centaur,
under the pdf's 2 second limit. The local judge harness replaces the
live interaction with the fixed four-line file described below the
listings, and because the official .ans files are empty transcripts
the harness compares that single output line against the file's
truth through its sphinx mode.

Official sample 1, reprinted byte for byte from the judge data pair
`A-riddleofthesphinx/sample-1.in` and `sample-1.ans`, the same
interaction the problems pdf prints as its first transcript: the
truth is 4 4 4 and the lying round is the second of five with
additive delta 1, so asked (1,1,1), (1,1,1), (5,0,1), (1,0,0), and
(1,1,0) she answers 12, 13, 24, 4, and 8. The .ans side of the pair
is empty by design, so the expected block below prints the line the
sphinx mode demands, the truth triple from line 2:

input:

```
fixed
4 4 4
1 1
4 4 4
```

expected output:

```
4 4 4
```

Recognition: five rounds, coefficients at most 10 and answers at
most 1e5 under the 2 second limit make the budget trivial: six
exclusion hypotheses, no lie or the lie on round k, each resolved
by Cramer's rule on a 3 by 3 system and cross-checked against the
survivors, about sixty tiny solves in all, so the whole difficulty
is the model, not the cost.

The statement's cue is at most one of her five answers may be an
outright lie and you do not know which one: the consistent world is
recovered by excluding each suspect round in turn and keeping the
one hypothesis whose survivors all agree. Problem A is the 2023
face of the consistency under a faulty oracle family. Consistency
under a faulty oracle ties chapter 11 problem W and chapter 13
problem D together.

Searching the triple space is the tempting tool and the numbers
kill it: every answer is a sum of at most thirty coefficient legs
bounded by 1e5, so the triples run past 1e15 candidates against
five answers, and any adaptive questioning that trusts a single
answer is steered wrong by the one lie, while five rows with every
triple independent decide outright.

The book asks the five questions (1,0,0), (0,1,0), (0,0,1), (1,1,1),
(1,2,3), whose every triple of rows is linearly independent, the ten
triple determinants running -2, -2, -1, 1, 1, 1, 1, 1, 1, and 3, the
(q1,q2,q5) triple at 3, a multiset pinned by a reference computation
after an earlier gloss of plain +-1 and +-2 proved wrong for that one
triple. Each exclusion hypothesis, the lie hit round k or there is no
lie, leaves a system where some three surviving rows determine the
legs by Cramer's rule and the other survivors cross-check them, and
exactly one hypothesis survives, the argument on the solutions pdf
page 2, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
Book 9's chapter 34, linear algebra, builds the determinant screen
and the small-system solve this lie isolation rests on. The last row
is not negotiable: replacing (1,2,3) with (1,1,2) or (0,1,2) creates
dependent triples and breaks the guarantee. The deduction is O(1)
after five answers.

The worked run: trace the model on sample 1. The judge file names
truth 4 4 4 and the lie on 0-based round 1 with delta 1, so the
book's five questions (1,0,0), (0,1,0), (0,0,1), (1,1,1), (1,2,3)
draw the answers 4, 5, 4, 12, 24, the second carrying 4 + 1 = 5.
The no-lie hypothesis solves rows one through three for x = 4,
y = 5, z = 4, and row four demands x + y + z = 13 against the
drawn 12, dead. The lie-on-round-two hypothesis survives: rows one
and three give x = 4 and z = 4, row four gives y = 12 - 4 - 4 = 4,
and row five cross-checks `4 + 2*4 + 3*4 = 24` = 24. Every other
placement dies on the same arithmetic, the table below, the legs
are 4 4 4, and the trace ends at the printed answer `4 4 4`.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*hypothesis*], [*legs solved*], [*cross-check*], [*verdict*]),
  [no lie], [4 5 4], [row four 13 vs 12], [dead],
  [lie on row 1], [3 5 4], [row five 25 vs 24], [dead],
  [lie on row 2], [4 4 4], [row five 24 = 24], [the survivor],
  [lie on row 3], [4 5 3], [row five 23 vs 24], [dead],
  [lie on row 4], [4 5 4], [row five 26 vs 24], [dead],
  [lie on row 5], [4 5 4], [row four 13 vs 12], [dead],
)

#listing("icpc/samples-c/src/Ch12/pA.c", first: 48, last: 77, caption: [c, deduce: every 3-subset of every hypothesis through Cramer, integer and nonnegative, then verify all rows])

#listing("icpc/samples/src/Ch12/PA.cs", first: 26, last: 55, caption: [c\#, Solve reads the four-line judge file: truth on line 2, the lying round answered from line 4 plus the delta])

#listing("icpc/samples-go/ch12/pa.go", first: 30, last: 81, caption: [go, one det3 helper, the first three surviving rows per hypothesis, then the full cross-check])

#listing("icpc/samples-js/src/ch12-pa-riddleofthesphinx.mjs", first: 21, last: 54, caption: [javascript, the exported pure core, null on a singular or non-integer system])

#listing("icpc/samples-py/src/Ch12/pa.py", first: 46, last: 79, caption: [python, deduce as nested comprehensions over hypotheses and triples, solve simulates through the helper])

#listing("icpc/samples-lua/ch12_pa.lua", first: 47, last: 77, caption: [lua, deduce over a flat nine-scalar determinant, legs rejected unless the quotient is exact])

The judge file format cost this wave a retraction, recorded here
because the wrong reading looked green for a year. The four lines are
the literal word `fixed`, the TRUE leg counts, the 0-based lying round
where 5 means never plus an additive delta, and ALTERNATE leg counts.
Every answer is truthful from line 2 except the lying round, answered
from the line-4 triple plus the delta. The 30 use-alt-sol secrets put
a different triple on line 4 with delta 0, the swap itself is the lie,
and the other 20 cases and both samples carry line 4 equal to line 2
with a real delta, sample 2 runs delta -6241 so answers may go
negative. The correct output is always the line-2 triple. The original
2022-era reading treated line 2 as a decoy and emulated from line 4,
which is circular validation, the emulator agreeing with itself rather
than with the sphinx, and it was retracted when commit 64d294b fixed
the harness compare for 2022/W from a four-line parse to the plain
sphinx mode. The C\# port self-played line 4 and failed exactly the 30
use-alt-sol secrets before commit 1367ea9 moved it to truth from line
2 with the lying round from line 4, and its suite now pins both traps,
the swap fixture `fixed / 1 2 3 / 1 0 / 1750 2795 941` answering
`1 2 3` and the delta lie with an identical line 4. The other five
languages answer from line 2 with the delta applied on the lying
round, which provably prints the same triple, since with all-truthful
answers every consistent hypothesis recovers the true legs. All six
languages now judge 50 of 50 on both years.

The crafted fixture is `fixed / 2 5 7 / 3 1`: rounds one through
three read the legs off directly, round four answers 15 instead of 14,
and round five cross-checks at 33, so the lie sits on round four and
the legs are 2 5 7. Every suite asserts that pair plus the never-lying
`fixed / 9 8 7 / 2 0` answering 9 8 7: c runs 2 CHECKs, the C\# suite
4 facts including the two judge traps, go pins 2 table rows,
javascript 2 it blocks carrying 3 assertions, python 2 checks, lua 2
named checks. Products stay under 10 times the leg sums, well inside
int32, so no language needs wider arithmetic than its default int,
and go stores the answers in int64 only because it prints them there.

#diagram([the five question rows, the lie bolted onto round four, the surviving rows solving the fixture], length: 12pt, {
  let row(y, q, a, bolt: false) = {
    cdraw.content((1.0, y), q, size: 6.5pt, anchor: "west")
    cdraw.content((5.4, y), a, size: 6.5pt, anchor: "west")
    if bolt {
      cdraw.line((4.9, y + 0.42), (5.9, y - 0.42), stroke: luma(60))
      cdraw.line((5.1, y + 0.42), (6.1, y - 0.42), stroke: luma(60))
    }
  }
  cdraw.content((1.0, 7.6), [question], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((5.4, 7.6), [answer], size: 6pt, anchor: "west", fill: luma(100))
  row(6.5, [(1,0,0)], [2])
  row(5.4, [(0,1,0)], [5])
  row(4.3, [(0,0,1)], [7])
  row(3.2, [(1,1,1)], [15], bolt: true)
  row(2.1, [(1,2,3)], [33])
  cdraw.content((7.0, 3.2), [the lie: truth 14, plus delta 1], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((1.0, 0.9), [surviving rows give 2 5 7, and `2 + 2*5 + 3*7 = 33` checks out], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((1.0, 0.1), [every triple of the five rows is independent], size: 6.5pt, anchor: "west", fill: luma(100))
})

== b, schedule

The institute for creative product combinations fields n two-person
teams, members (i, 1) and (i, 2), and keeps its pandemic rule that
each week exactly one member of every team is in the office.
Teammates collaborate fine apart, but colleagues from different teams
must meet, and for two of them with shared office weeks w1 < w2 <
... < wk their isolation is the maximum of w1, w2 - w1, ..., wk -
wk-1, and w + 1 - wk, the head before their first shared week, the
gaps between shared weeks, and the tail after the last, or infinity
if they never meet at all. The company's isolation is the worst over
all colleague pairs from different teams, and the task schedules the
w weeks so that worst is as small as it can be.

The input is a single line of two integers, the team count n with
2 <= n <= 1e4 and the week count w with 1 <= w <= 52, by the problems
pdf. The output is one line holding either the minimum isolation as
an integer or the word infinity, followed, when it is finite, by w
schedule lines: line j is a string of length n over the symbols 1
and 2, the ith symbol naming which member of team i comes in during
week j. Any schedule achieving the optimum is accepted, the pdf says
so plainly, which is why this book's harness scores B on the first
line alone, under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`B-schedule/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: two teams over six weeks meet with worst gap 4,
and the judges' block is one of many valid schedules, the book's
canonical rows below answer the same 4 with different lines.

input:

```
2 6
```

expected output:

```
4
11
12
21
22
11
12
```

Official sample 2, same source: with one week and two teams, each
team seats one member and two of the four colleague pairs never
meet, so the answer is infinity.

input:

```
2 1
```

expected output:

```
infinity
```

Recognition: n <= 1e4 teams and w <= 52 weeks under the 2 second
limit price a formula, not a search: the viable block lengths k run
1 through 17, since C(16, 8) = 12870 already seats 1e4 teams, and
the output itself is w lines of n symbols, at most 5.2e5
characters, so the solve is a binomial scan plus one emission
pass.

The statement's cue is schedules the w weeks so that worst is as
small as it can be, plus any schedule achieving the optimum is
accepted: a minimum with a printed witness is the classic shape of
a closed-form characterization, prove exactly which isolations are
achievable at all, then emit one canonical block. Problem B is the
2023 face of the constructive closed-form characterization family.
The constructive closed-form characterization family holds chapter
11 problem U and chapter 13 problem J.

Searching week by week is priced out by counting alone: each week
admits 2^n member choices with n up to 1e4, a number with 3000
digits, chained over 52 weeks, while the block characterization
answers in 17 binomial lookups.

An isolation-k schedule is periodic, the solutions pdf opens, so the
task reduces to the smallest k in which every pair can meet, printing
infinity when that k exceeds w. Code each team as a binary string of
length k, one bit per week naming which member is in: two colleagues
(i, a) and (j, b) share exactly the weeks whose bit pair for teams i
and j reads (a-1, b-1), so two strings are compatible, all four bit
pairs occurring across the k weeks, precisely when every colleague
pair meets somewhere in the block, and repeating a compatible block
cyclically keeps every gap inside one period. Strings starting with
0 and carrying ceil(k/2) ones among the remaining k-1 bits are
pairwise compatible, an antichain in the subset lattice whose equal
suffix weights also force a shared 1 by pigeonhole, and Sperner's
theorem, with a complement argument for odd k, makes C(k-1,
ceil(k/2)) the exact maximum team count, so k stays at most 17 for n
up to 1e4. Emit the n largest such strings in descending
lexicographic order, team 1 taking the largest, and repeat the block
cyclically to w weeks, `O(n*k)` after a tiny binomial search, the
construction on the solutions pdf pages 2 and 3, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
Book 9's chapter 35, combinatorics, teaches the binomial search
over ordered selections that pins this k. Descending lex is the
canonical output every suite pins.

The worked run: trace the model on sample 1. The k search seats
two teams first at k = 4: k = 3 admits C(2, 2) = 1 compatible
string, k = 4 admits C(3, 2) = 3. The judges' printed witness read
column-wise over its first four weeks, 11, 12, 21, 22, hands team
1 the string 0011 and team 2 the string 0101, both cap members
with two ones among the last three bits, and all four colleague
pairs meet inside the block: members (1,1) in week 1, (1,2) in
week 2, (2,1) in week 3, (2,2) in week 4. Weeks 5 and 6 repeat the
block's weeks 1 and 2, so every pair meets again within one period
and the isolation of each pair is at most k, the table below, and
no k = 3 schedule seats two teams, so 4 is optimal. Week 6 repeats
week 2's row, and the trace ends at the printed answer `12`.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*colleague pair*], [*shared weeks*], [*isolation*]),
  [(1,1)], [1 and 5], [max(1, 5 - 1, 7 - 5) = 4],
  [(1,2)], [2 and 6], [max(2, 6 - 2, 7 - 6) = 4],
  [(2,1)], [3], [max(3, 7 - 3) = 4],
  [(2,2)], [4], [max(4, 7 - 4) = 4],
  [company], [all four pairs], [4 = k],
)

#listing("icpc/samples-c/src/Ch12/pB.c", first: 38, last: 68, caption: [c, the whole solve: k search, callback emission of the n largest strings, cyclic repeat to w])

#listing("icpc/samples/src/Ch12/PB.cs", first: 17, last: 57, caption: [c\#, all 2^(k-1) masks with r bits enumerated, sorted descending, rows read off the bits])

#listing("icpc/samples-go/ch12/pb.go", first: 29, last: 63, caption: [go, gen tries the 1 branch first so the recursion itself emits descending lex])

#listing("icpc/samples-js/src/ch12-pb-schedule.mjs", first: 17, last: 39, caption: [javascript, firstSubsets from the year-local comb module, bits mapped to member digits])

#listing("icpc/samples-py/src/Ch12/pb.py", first: 16, last: 33, caption: [python, first_subsets over the one-positions, week 1 is the all-1 column])

#listing("icpc/samples-lua/ch12_pb.lua", first: 14, last: 43, caption: [lua, comb.emit callback builds each string, byte 48 flips bits to office digits])

The fixture is 2 teams over 6 weeks: k = 4 is the first count that
fits two teams, the strings are 0110 and 0101, and the cyclic repeat
prints 11, 22, 21, 12, 11, 22. The colleague pair of both first
members meets in weeks 1 and 5, its gap run is 4, and k = 3 admits
only one string so it cannot cover two teams, making 4 optimal. Every
suite asserts that output plus the crafted `3 4` printing 4 over 111,
221, 212, 122, and `2 1` printing infinity: c 3 CHECKs, the C\# suite
3 facts, go 3 table rows, javascript 3 blocks, python 3 checks, lua 3
named checks. The binomials top out at C(16,8) = 12870, so every
language stays in plain integers.

#diagram([the fixture's two team strings over six weeks, the shared weeks of the first-member pair ringed, the worst gap measured], length: 12pt, {
  let cell(x, y, t, ring: false) = {
    cdraw.rect((x, y), (x + 1.3, y + 1.0), fill: luma(232), stroke: luma(140), radius: 0.02)
    if ring {
      cdraw.rect((x - 0.12, y - 0.12), (x + 1.42, y + 1.12), stroke: 0.9pt + luma(60), radius: 0.05)
    }
    cdraw.content((x + 0.65, y + 0.5), t, size: 7pt)
  }
  cdraw.content((0.8, 6.4), [team 1], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 2.6), [team 2], size: 6.5pt, anchor: "west", fill: luma(100))
  for i in range(6) {
    cell(3.4 + i * 1.5, 5.8, [1], ring: i == 0 or i == 4)
    cell(3.4 + i * 1.5, 4.4, [2])
    cell(3.4 + i * 1.5, 2.0, [1], ring: i == 0 or i == 4)
    cell(3.4 + i * 1.5, 0.6, [2])
  }
  cdraw.line((3.4, 7.2), (4.7, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.9, 7.2), [week], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((12.6, 5.8), [string 0110], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.content((12.6, 2.0), [string 0101], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.line((4.05, 8.0), (11.05, 8.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((7.5, 8.5), [both first members in: weeks 1 and 5], size: 6pt, fill: luma(100))
  cdraw.content((12.6, 7.2), [worst gap 4 = k], size: 6.5pt, anchor: "west", fill: luma(100))
})

== c, three kinds of dice

The 2022 V task returns with fresh numbers, the Warren Buffett and
Bill Gates story of intransitive dice behind it. A die is any
collection of at least one face, each face a positive integer, one
face chosen uniformly per roll. When two dice roll, the higher face
earns its die one point and equal faces earn each die half a point,
score(D, D') is D's expected points per roll, D has an advantage over
D' when the score tops 1/2, and the two dice tie at exactly 1/2.
Given D1 with an advantage over D2, listed on either input line, the
task prints two numbers over all third dice D3, and D3 may be any die
at all, any number of faces of any positive integers: the lowest
score(D3, D2) among the D3 that tie with or beat D1, and the highest
score(D3, D1) among the D3 that D2 ties with or beats. The two scores
need not share one D3, and a first score under 1/2 is exactly an
intransitive trio.

The input is two lines, one die per line: a face count n with
1 <= n <= 1e5 followed by n face values, each 1 <= f <= 1e9, by the
problems pdf, and whichever of the two lines carries the advantage
plays D1. The output is one line with the two scores and an absolute
error of at most 1e-6, under the pdf's 1 second limit. The face
bound binds the input dice only, D3's faces range over all positive
integers, which is the trap the unclamped candidates below return to.

Official sample 1, reprinted byte for byte from the judge data pair
`C-threekindsofdice/sample-1.in` and `sample-1.ans`, the same pair
the problems pdf prints and works its 4/9 example on: the three-face
die 2 4 9 beats the six-face die 1 1 6 6 8 8 by 5/9 to 4/9, so here
D1 is the second line, and the two answers say a tying D3 can be
held to 0.291666667 by D2 while a D2-tied D3 still earns 0.750000000
against D1.

input:

```
6 1 1 6 6 8 8
3 2 4 9
```

expected output:

```
0.291666667 0.750000000
```

Recognition: both dice carry at most 1e5 faces under the 1 second
limit. Doubling the score coordinates makes every achievable point
an integer pair, the candidate values number at most 2n1 + 2n2
plus two, about 4e5, and the sort, the monotone chain and the two
edge walks cost a few million comparisons, two orders of magnitude
inside budget.

The statement's cue is a pair of extrema over all third dice D3
under a tie-or-beat constraint: choosing D3 is choosing a
distribution over face values, so both queries are constrained
optima over one shared achievable set, the cue that the set is a
convex hull and each query a halfplane cut on it. Problem C is the
2023 face of the convex hull of achievable points family. Chapter
11 problem V is the other convex hull of achievable points twin.

Enumerating D3 as multisets of the input face values is the
tempting tool and it is wrong before it is slow: the winning mixes
may need a face one below the union minimum or one past its
maximum, judge secret-55 answers through 999999998 and 1000000001,
faces no bounded enumeration ever emits.

One of two given dice beats the other and the input may list the
winner first or second, so the solver detects the advantage by the
exact pairwise score before anything else. A third die D3 is a
distribution over face values, and a D3 face showing v earns D1
exactly S1(v), faces of D1 above v plus half the ties, likewise
S2(v) against D2, so the achievable average pairs are exactly the
convex hull of the doubled points (2 S1, 2 S2) over the candidate
values: each distinct merged face value u and u+1, one past the
maximum, and one below the minimum when that stays positive, because
D3 faces are positive integers unbounded above and the candidate set
must never clamp to the input range. A die splitting its faces
between two candidate values realizes any point of the segment
joining their points, the face ratio is the mixing weight, so hull
edges are achievable dice and not just bounds. Part 1 maximizes
avgS2 at avgS1 <= n1/2, part 2 minimizes avgS1 at avgS2 >= n2/2,
both read off the upper hull with edge interpolation, and the scores
print as 1 - avg/n, the model on the solutions pdf pages 3 and 4,
O(n log n) for the sort and O(n) for the hull walk, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].

The worked run: trace the model on sample 1. The listed-first die
wins only 8 of the 18 pairings, 8/18 = 4/9 < 1/2, so D1 is the
second line (2, 4, 9) and D2 the first (1, 1, 6, 6, 8, 8). A D3
face showing v earns the doubled integers X(v) against D1 and Y(v)
against D2, candidates v = 1 through 10, the value 0 below the
union minimum dropped because faces are positive, and the upper
hull of the ten points has three vertices, (0, 0) at v = 10,
(2, 8) at v = 5, (6, 10) at v = 1. Part 1 walks the hull edge from
(2, 8) to (6, 10) out to X = 3 = n1, where Y = 8 + (10 - 8)/(6 -
2) = 8.5, the mix (1, 5, 5, 5) tying D1 at exactly 1/2 while D2
earns 8.5/12, so score(D3, D2) = 1 - 8.5/12 = 7/24. Part 2 walks
the edge from (0, 0) to (2, 8) up to Y = 6 = n2, where
`X = 2*6/8` = 1.5, the mix (5, 5, 5, 10) tying D2 at 1/2 while D1 earns
1.5/6, so score(D3, D1) = 1 - 1.5/6 = 3/4, and
the trace ends at the printed answer `0.291666667 0.750000000`.

#diagram([sample 1's doubled score points, the three-vertex upper hull, the two query cuts and their winning mixes], length: 12pt, {
  let ax(u) = 2.2 + u * 1.55
  let ay(v) = 0.6 + v * 0.62
  for (u, v) in ((1, 0), (3, 8), (4, 8), (5, 8), (2, 6), (2, 2)) {
    cdraw.circle((ax(u), ay(v)), radius: 0.18, fill: luma(205), stroke: luma(90))
  }
  for (u, v, t) in ((0, 0, [(0,0)]), (2, 8, [(2,8)]), (6, 10, [(6,10)])) {
    cdraw.circle((ax(u), ay(v)), radius: 0.24, fill: luma(170), stroke: luma(90))
    cdraw.content((ax(u), ay(v) + 0.45), t, size: 6pt, fill: luma(100))
  }
  cdraw.line((ax(0), ay(0)), (ax(2), ay(8)), stroke: luma(60))
  cdraw.line((ax(2), ay(8)), (ax(6), ay(10)), stroke: luma(60))
  cdraw.line((ax(3), 0.3), (ax(3), 7.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.6, ay(6)), (11.7, ay(6)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.circle((ax(3), ay(8.5)), radius: 0.3, stroke: 0.9pt + luma(40))
  cdraw.circle((ax(1.5), ay(6)), radius: 0.3, stroke: 0.9pt + luma(40))
  cdraw.content((2.0, 8.2), [X = 3: mix (1,5,5,5), score 7/24], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((2.0, 7.5), [Y = 6: mix (5,5,5,10), score 3/4], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch12/pC.c", first: 92, last: 131, caption: [c, candidate values, doubled points through a two-pointer merge, then the two hull queries and scores])

#listing("icpc/samples/src/Ch12/PC.cs", first: 49, last: 95, caption: [c\#, tie and strict points per distinct value, gap detection, then the hull edge walk with bounds])

#listing("icpc/samples-go/ch12/pc.go", first: 32, last: 60, caption: [go, the advantage from one sorted merge, duplicated advantage faces counted by run length instead of rescanned, D1 kept only on strictly more than half the pairs])

#listing("icpc/samples-js/src/ch12-pc-threekindsofdice.mjs", first: 36, last: 69, caption: [javascript, the advantage by merge counting, then the candidate values and two-pointer points])

#listing("icpc/samples-py/src/Ch12/pc.py", first: 26, last: 54, caption: [python, union values with gap points and a past-the-cap (0,0), bisect for wins and ties])

#listing("icpc/samples-lua/ch12_pc.lua", first: 38, last: 77, caption: [lua, run-length compressed advantage so all-equal dice stay linear, then the candidate build])

Two judge corrections live in this section. First, hull-edge mixes
beat pure breakpoints: the original derivation priced only dice whose
faces all sit on breakpoints and printed 2/3 and 1/4 on the fixture,
but its own witness D3 = [2] earns 2/6 against D2, contradicting the
2/3, and the corrected answers ride the hull edge from (0,1) to (4,4),
the mix [1,3] ties D1 at exactly 1/2 while scoring 7/12 against D2,
and the six-face mix [1,1,1,1,3,3] holds the D2 tie at avgS1 = 4/3
for a part-2 score of 1/3, so the fixture answers 0.583333333
0.333333333, confirmed 78 of 78 on the judge. Second, the unclamped
candidates: judge secret-55 feeds `1 999999999` against
`1 1000000000` and expects `0.5 0.5`, reachable only through the
faces 999999998 and 1000000001, one below the minimum and one past
the maximum. The fixture is D1 = (2,2) against D2 = (1,1,3), and the
swapped input must return the same pair. Counts: c 2 float CHECKs,
the C\# suite 2 facts, go 3 tolerance rows including official sample
1 at 0.291666667 0.750000000, javascript 2 blocks, python 5 checks
spanning both input orders, the all-ones pair, and the unclamped
999999999 against 1000000000 pair, lua 2 tolerance checks. Go's
first port scored the advantage with a naive double loop plus linear
rescans, judge-green at 78 of 78 but 14.3 seconds on secret-41-gen,
and the sorted-merge run-length pass in the listing above is the
rewrite, green again with secret-41-gen at 0.031 seconds and the
whole 78-case judge run at 1.06 seconds, the defect being complexity
against the five sibling languages rather than wrong answers.
Coordinates double to keep every hull vertex integral, and floats
appear only in the final interpolation and print.

#diagram([the fixture's doubled points, the hull edge from (0,1) to (4,4), the two query lines and their winning points], length: 12pt, {
  let pt(x, y, t, win: false) = {
    cdraw.circle((x, y), radius: if win { 0.34 } else { 0.22 }, fill: if win { luma(170) } else { luma(200) }, stroke: luma(90))
    cdraw.content((x, y + 0.55), t, size: 6pt, fill: luma(100))
  }
  let ax(u) = 1.4 + u * 2.6
  let ay(v) = 0.7 + v * 1.55
  pt(ax(0), ay(0), [(0,0)])
  pt(ax(0), ay(1), [(0,1)])
  pt(ax(2), ay(2), [(2,2)])
  pt(ax(4), ay(4), [(4,4)])
  cdraw.line((ax(0), ay(1)), (ax(4), ay(4)), stroke: luma(60))
  cdraw.line((ax(2), 0.2), (ax(2), 7.0), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((ax(2), 7.4), [x = n1 = 2], size: 6pt, fill: luma(100))
  cdraw.line((0.9, ay(3)), (13.0, ay(3)), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((13.2, ay(3)), [y = n2 = 3], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.circle((ax(2), ay(2.5)), radius: 0.3, stroke: 0.9pt + luma(40))
  cdraw.circle((ax(8 / 3), ay(3)), radius: 0.3, stroke: 0.9pt + luma(40))
  cdraw.content((0.8, 8.2), [mix [1,3]: 7/12 against D2], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((0.8, 7.6), [mix [1,1,1,1,3,3]: 1/3 against D1], size: 6.5pt, anchor: "west", fill: luma(100))
})

== d, carl's vacation

The 2022 T task returns. Carl the ant, veteran of the 2004 and 2009
finals, is on vacation in Egypt and wants to walk from the apex of
one right square pyramid to the apex of another, touching only the
two pyramid surfaces and the plane they stand on, and the task prints
the shortest such walk. Each pyramid is given by one directed base
edge, the body lying to the left of the direction of travel, plus its
height, the apex sitting straight above the base center, and the two
square bases may share edges or corners but never area.

The input is two lines of five integers, x1 y1 x2 y2 and then h for
the first pyramid, the same shape again for the second, by the
problems pdf: the coordinates run to 1e5 in absolute value, the two
edge endpoints are distinct, the height satisfies 1 <= h <= 1e5, and
the base intersection is promised to have area 0. The output is the
minimum travel distance with an absolute or relative error of at
most 1e-6 under the pdf's 1 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`D-carlsvacation/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints with its path figure: the first pyramid rises 4
over the edge from (0,0) to (10,0), and the optimum crosses into the
second pyramid exactly at a base corner, the case that breaks the
solutions' own sketch.

input:

```
0 0 10 0 4
9 18 34 26 42
```

expected output:

```
60.866649532
```

Recognition: coordinates stop at 1e5 and the limit at 1 second, and
the budget is candidate count, not per-candidate work: 16 edge-pair
unfold-straights, 8 one-corner chains, 16 two-corner chains and
the four-corner chain, each leg a convex one-dimensional
minimization priced in a few hundred probes, tens of thousands of
predicate calls in all, thousands of times inside budget.

The statement's cue is shortest such walk over surfaces that
unfold: on unfoldable surfaces an optimum is a straight line in
some unfolding, so the only question is which finitely many hinge
and corner configurations attain it, the cue that turns a
continuous path search into critical-point enumeration. Problem D
is the 2023 face of the geometric critical-point enumeration
family. Geometric critical-point enumeration is the shared shape
of chapter 11 problem T, chapter 08 problem A, chapter 08 problem
D, chapter 09 problem E, and chapter 09 problem G.

Numerically sweeping entry and exit points on a fine grid is the
priced-out alternative: 1e-6 resolution over 1e5-sized coordinates
asks 1e11 samples for a single face pair, sixteen of them, against
the 1 second limit, and any smooth sweep undershoots the corner
entries where this year's optimum lives.

The solutions pdf page 4 sketch, 16 face pairs with both apexes
unfolded onto the ground, is incomplete: implemented literally it
produces no valid candidate on the official sample, whose optimum
enters the second pyramid exactly at a base corner. Unfolding is
reflection arithmetic: for the face hinged at a base edge e of length
s, the apex lands on the ground at the foot of the base center on
the edge line, pushed outward along the edge's outward normal by the
slant sqrt(h^2 + (s/2)^2), and a surface leg from the apex to a
point of e is then a straight segment from that copy. A shortest
path bends only where its medium changes, at the exit edge of
pyramid 1, the entry edge of pyramid 2, or at a base corner, so the
shipped solvers price nine candidate categories per face pair, exit
by unfold, mirror, or corner crossed with the same three entries:
the unfold-straights, the apex rotated about each of the four base
edges onto either side of the plane, accepted when the segment
crosses the two hinge edges in order, the equality t1 = t2 covering
pyramids that share a base edge, with its open middle missing both
square interiors, then the mirror-to-corner hybrids each way, and
the corner bends, paths bending at one or more of the 8 base corners
with each end leg minimized over its exit edge. The completion was
derived for this book and validated against all 45 judge pairs to
1e-6, constant work per face pair, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].

The worked run: trace the model on sample 1. Pyramid 1 is the
square on (0, 0) to (10, 0) with height 4, apex above (5, 5), and
pyramid 2 the square on the directed edge (9, 18) to (34, 26) with
height 42, corners (9, 18), (34, 26), (26, 51), (1, 43), apex
above the center (17.5, 34.5). Every one of the 16 unfold-straights
fails validity, each straight leaving pyramid 1's near faces
crosses into pyramid 2's interior, so the optimum bends at a
corner, and the winner is the unfold-exit, corner-entry hybrid
through (9, 18). Leg 1 unfolds the apex across the back edge line
to (5, 10 - sqrt(41)), the slant sqrt(5^2 + 4^2) = sqrt(41), and
the straight from there to the corner is sqrt(4^2 + (8 +
sqrt(41))^2) = sqrt(223.450) = 14.948244, crossing the back edge
at (6.778, 10) inside the segment. Leg 2 unfolds apex 2 about the
given edge, landing at (34.911, -19.909) past the edge center
(21.5, 22) by the slant sqrt(42^2 + 13.124^2) = 44.003, and the
corner-to-unfolded-apex straight is sqrt(25.911^2 + 37.909^2) =
sqrt(2108.500) = 45.918406. The plane middle is the corner itself,
and 14.948244 + 45.918406 = 60.866650, and
the trace ends at the printed answer `60.866649532`.

#diagram([sample 1's winning chain: the back-face unfold to apex1', the bend at the corner (9,18), the given-edge unfold to apex2'], length: 12pt, {
  cdraw.rect((1.4, 2.2), (4.4, 5.2), fill: luma(238), stroke: luma(120), radius: 0.02)
  cdraw.content((1.4, 5.8), [pyramid 1, h = 4], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.circle((2.7, 3.0), radius: 0.22, fill: luma(200), stroke: luma(100))
  cdraw.content((2.7, 2.4), [apex1' (5, 10 - sqrt(41))], size: 6pt, anchor: "north", fill: luma(100))
  cdraw.line((2.7, 3.25), (5.7, 8.5), stroke: luma(60))
  cdraw.circle((3.8, 5.2), radius: 0.1, fill: luma(60))
  cdraw.content((3.6, 5.7), [exit (6.778, 10)], size: 6pt, anchor: "east", fill: luma(100))
  let p2 = ((5.7, 8.5), (9.2, 9.4), (8.2, 12.3), (4.7, 11.4))
  cdraw.line(p2.at(0), p2.at(1), stroke: luma(120), width: 0.7)
  cdraw.line(p2.at(1), p2.at(2), stroke: luma(120))
  cdraw.line(p2.at(2), p2.at(3), stroke: luma(120))
  cdraw.line(p2.at(3), p2.at(0), stroke: luma(120))
  cdraw.content((8.2, 12.9), [pyramid 2, h = 42], size: 6pt, fill: luma(100))
  cdraw.content((9.5, 9.3), [the given edge], size: 6pt, anchor: "west", fill: luma(100))
  cdraw.circle(p2.at(0), radius: 0.16, stroke: luma(20), fill: white)
  cdraw.content((5.7, 7.9), [corner (9,18)], size: 6pt, anchor: "north", fill: luma(100))
  cdraw.line(p2.at(0), (9.4, 5.3), stroke: luma(60))
  cdraw.circle((9.4, 5.3), radius: 0.22, fill: luma(200), stroke: luma(100))
  cdraw.content((9.4, 4.7), [apex2' (34.911, -19.909)], size: 6pt, anchor: "north", fill: luma(100))
  cdraw.content((10.1, 8.0), [leg 1 = 14.948244], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((10.1, 7.2), [leg 2 = 45.918406], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((10.1, 6.4), [total = 60.866649532], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch12/pD.c", first: 199, last: 245, caption: [c, corner chains: per-corner best legs over the four edges, then sequences of one, two, and four corners with valid ground])

#listing("icpc/samples/src/Ch12/PD.cs", first: 102, last: 141, caption: [c\#, MinLeg: the unconstrained convex optimum first, then run detection with bisected feasible edges])

#listing("icpc/samples-go/ch12/pd.go", first: 201, last: 248, caption: [go, bestLeg as one eval closure, convex in the edge parameter, infeasible samples priced at infinity])

#listing("icpc/samples-js/src/ch12-pd-carlsvacation.mjs", first: 75, last: 97, caption: [javascript, unfoldLen: both hinge crossings solved by cross products, order and middle clearance checked])

#listing("icpc/samples-py/src/Ch12/pd.py", first: 76, last: 110, caption: [python, the same guarded grid-plus-ternary leg, a port of the judge-green c engine])

#listing("icpc/samples-lua/ch12_pd.lua", first: 89, last: 135, caption: [lua, best_leg over flat scalars, no table allocation inside the sweep])

The fixture is two squares with a two-unit gap, bases
[0,2] and [4,6] with heights 2: the inner unfold lands each apex
inside the other square and the plain segment crosses out of order,
so both apexes mirror across their facing edges, the mirror segment
threads the hinge midpoints (2,1) and (4,1), and its length is
`2 + 2*sqrt(5) = 6.472135955`. The corner-kissing extra, squares
[0,6] and [6,12] on a diagonal touching at (6,6), admits no smooth
mirror crossing and walks the corner chain at `2*sqrt(22) =
9.380831520`. Every suite asserts both, and go's tolerance table adds
the official sample 60.866649532 whose corner entry forced the
completion: c 2 float CHECKs, the C\# suite 2 facts, go 3 tolerance
rows, javascript 2 blocks, python 2 checks, lua 2 tolerance checks,
all compared at 1e-6. Input coordinates are integers and everything
past parsing is double, so the languages diverge nowhere worth
noting.

#diagram([the fixture: both squares, both apexes mirrored across the facing edges, the straight candidate threading both hinge midpoints], length: 12pt, {
  let sq(x) = {
    cdraw.rect((x, 2.2), (x + 3.2, 5.4), fill: luma(238), stroke: luma(120), radius: 0.02)
  }
  sq(2.0)
  sq(11.0)
  cdraw.content((3.6, 6.0), [pyramid 1, h = 2], size: 6pt, fill: luma(100))
  cdraw.content((12.6, 6.0), [pyramid 2, h = 2], size: 6pt, fill: luma(100))
  cdraw.circle((0.65, 3.8), radius: 0.28, fill: luma(200), stroke: luma(100))
  cdraw.content((0.65, 2.9), [apex1'], size: 6pt, fill: luma(100))
  cdraw.circle((15.55, 3.8), radius: 0.28, fill: luma(200), stroke: luma(100))
  cdraw.content((15.55, 2.9), [apex2'], size: 6pt, fill: luma(100))
  cdraw.line((0.93, 3.8), (15.27, 3.8), stroke: luma(60))
  cdraw.circle((5.2, 3.8), radius: 0.15, fill: luma(60))
  cdraw.circle((11.0, 3.8), radius: 0.15, fill: luma(60))
  cdraw.content((5.2, 4.5), [(2,1)], size: 6pt, fill: luma(100))
  cdraw.content((11.0, 4.5), [(4,1)], size: 6pt, fill: luma(100))
  cdraw.content((6.6, 1.4), [slant sqrt(4+1) = sqrt(5) per unfolding], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((6.6, 0.6), [2 + 2 sqrt(5) = 6.472135955], size: 6.5pt, anchor: "west", fill: luma(100))
})

== e, a recurring problem

You wrote down every positive linear recurrence relation on index
cards, one per card, and now they need ordering. A plrr picks an
order k, then k positive coefficients c1 through ck, then k positive
starting values a1 through ak, and generates the rest of its sequence
forever through a(i+k) = c1 a(i) + c2 a(i+1) + ... + ck a(i+k-1),
Fibonacci being the famous case. The cards are indexed from 1 by
lexicographic order of the generated tail, everything after the k
starting values, with ties broken by lexicographic order of the
coefficient list: the pdf's own example, k = 1 with coefficient 2
starting from 2, precedes k = 2 with coefficients 2 and 1 starting
from 1 and 2, even though both generate the same numbers. Given a
card's index n, the task prints the card.

The input is a single line with the integer n, 1 <= n <= 1e9 by the
problems pdf. The output is four lines: the order k, the k
coefficients, the k starting values, and the first ten generated
values, all space separated, under the pdf's 20 second limit, the
widest in the set and headroom the judges grant for a counting dp
they call complicated.

Official sample 1, reprinted byte for byte from the judge data pair
`E-arecurringproblem/sample-1.in` and `sample-1.ans`, the same pair
the problems pdf prints: card 3 is Fibonacci, order 2, coefficients
1 1, starting values 1 1.

input:

```
3
```

expected output:

```
2
1 1
1 1
2 3 5 8 13 21 34 55 89 144
```

Official sample 2, same source: card 1235 is an order-4 card whose
tenth generated value already reaches 22377, the growth that forces
the saturated comparisons below.

input:

```
1235
```

expected output:

```
4
1 1 3 1
3 2 1 1
9 15 44 99 255 611 1519 3706 9129 22377
```

Recognition: n <= 1e9 under the widest limit in the set, 20
seconds, and the judges themselves cite no tighter shape than a
complicated dp: the memo counts prefixes of generated tails, the
walk consumes the index one value at a time, and the measured
state counts peak near 26 million, so the budget is memory and
constant factors, not asymptotics.

The statement's cue is cards indexed from 1 by lexicographic order
of the generated tail, ties broken by the coefficient list: an
index into a lexicographic enumeration is unranking, and unranking
a family far too large to list is counting without enumeration.
Problem E is the 2023 face of the counting and expectation without
enumeration family. Counting and expectation without enumeration
is the shared core of chapter 09 problem D, chapter 09 problem I,
chapter 11 problem Q, and chapter 12 problem K.

Listing the cards in order until index n is the priced-out
alternative: sample 2's card 1235 already generates 22377 at its
tenth value, the tails saturate int64 within forty terms, and n
runs to 1e9 cards, so generation costs 1e9 cards times ten
saturated terms against the one dp the judges grant 20 seconds.

The solutions pdf pages 4 and 5 count with a dp: f(x, a) counts the
plrrs whose tail starts with vector x given the trailing context a,
via f = 1 on the all-zero vector, 0 on any negative entry, and
otherwise the sum over each a0 and c of f on the vector x minus c
times the window (a0, a1, and on), with (a0, and on) as the new
context, memoized and pruned with the forward condition that
dropping the last entry must leave a positive count, since dead ends
never revive. The walk consumes the index n one generated value at a
time, or binary-searches the next entry with a <= y variant of f,
then enumerates directly once fewer than about half a million cards
share the prefix. Zero teams solved it in contest and the judges cite
no tighter bound than a complicated dp, the 20-second limit is the
headroom, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].

The worked run: trace the model on sample 1. The index is n = 3.
The first generated value is a sum of k positive terms, at least k,
so only the k = 1 card c = 1 from a = 1 opens its tail at 1, card
1, the all-ones tail. Cards opening at 2 number three: the k = 1
cards c = 1 from a = 2 with tail 2 2 2 2 and c = 2 from a = 1 with
tail 2 4 8 16, plus the k = 2 card c = 1 1 from a = 1 1, whose
recurrence a(i+2) = a(i) + a(i+1) opens 2 3 5 8. Lexicographic
tail order ranks 2 2 2 2 before 2 3 5 8 before 2 4 8 16, the table
below, so card 2 is c = 1 from a = 2 and card 3 is the k = 2 card:
a3 = 1 + 1 = 2, a4 = 1 + 2 = 3, a5 = 2 + 3 = 5, a6 = 3 + 5 = 8,
on to a11 = 34 + 55 = 89 and a12 = 55 + 89 = 144, and
the trace ends at the printed answer `2 3 5 8 13 21 34 55 89 144`.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*card*], [*k*], [*coefficients*], [*start*], [*tail opens*]),
  [1], [1], [1], [1], [1 1 1 1],
  [2], [1], [1], [2], [2 2 2 2],
  [3], [2], [1 1], [1 1], [2 3 5 8],
  [4], [1], [2], [1], [2 4 8 16],
)

#listing("icpc/samples-c/src/Ch12/pE.c", first: 70, last: 121, caption: [c, f_rec: negative and zero base cases, the forward prune, the capped a0 and c loops, saturation at 4e18])

#listing("icpc/samples/src/Ch12/PE.cs", first: 59, last: 108, caption: [c\#, the same recurrence over List windows with a string-keyed memo and a 4e9 cap])

#listing("icpc/samples-go/ch12/pe.go", first: 111, last: 161, caption: [go, the enumeration walk mirrors f's branching, (c, a0) pairs kept in depth-indexed scratch])

#listing("icpc/samples-js/src/ch12-pe-arecurringproblem.mjs", first: 60, last: 99, caption: [javascript, the typed-array chained hash: 13-word keys packing two 16-bit fields per int, per-depth buffers])

#listing("icpc/samples-py/src/Ch12/pe.py", first: 57, last: 96, caption: [python, f with hoisted memo.get, fixed child tails per c, saturation at 4e18])

#listing("icpc/samples-lua/ch12_pe.lua", first: 53, last: 104, caption: [lua, depth-indexed scratch vectors shared across the prune and the child loop, tails cleared past the live length])

Two measured stories separate the languages here. The dp itself is
heavy: the judge set peaks around 26 million memo states, past the
v8 Map's 2^24 entry ceiling, so javascript packs keys into 16-bit
fields of a typed-array chained hash and runs tail evolution on
BigInt windows saturating at 4e18, and python raises its enumeration
cap to 1.2 million, which stops the walk one prefix entry sooner and
roughly halves both the dp state count and the dict memory. The walk
itself hides the constant-tail trap: the k=1, c=(1) family repeats
its value instead of strictly increasing, it is counted by the dp at
deeper windows, and a walk that resumes the next candidate at
prefix-last + 1 skips it. The constant cards sit at n = 99029,
243835, 600347, and 1478167 for z = 14 through 17, and the z = 17
block lies past the half-million descent threshold, so a
threshold-skipping walk silently misses it. The C\# stream hit this
live, fixed it in 0c01f23 by resuming non-constant tails at
prefix-last + 1 and constant tails at prefix-last itself, and
re-judged 52 of 52 with a scatter-diff against the C engine showing
zero mismatches through n = 999999999. Lua's first port timed out at
276 seconds worst on secrets 37 and 38, 50 of 52, because the go
engine's stack-local child vectors have no lua equivalent and
per-child table allocation became the wall. Depth-indexed scratch
vectors shared across the prune call and the child loop, with
explicit tail clearing past the live length since slots are reused
across branches of different lengths, dropped the worst case to 107
seconds, a re-judge of 52 of 52 with the thinnest margin 13 seconds
under the cap. All six suites pin the fixture family: card 1 is k=1,
c=(1), a=(1) with tail all ones, card 2 is the same recurrence from
a=(2), card 4 is c=(2) from a=(1) printing powers of two, card 5 is
c=(1) from a=(3), so `2` answers `1 / 1 / 2 / 2 2 2 2 2 2 2 2 2 2`.
Counts: c 4 CHECKs, the C\# suite 7 facts including both official
samples and the constant-tail card pinned at 99029, go 4 rows plus a
dedicated count-curve test, javascript 4 blocks, python 4 checks,
lua 4 named checks. The dp counts in int64 with saturation, and the
generated
values grow past int64 quickly, so every engine compares tails on
saturated values and prints only the ten small terms of the final
card.

#diagram([cards ordered by generated tail, the tie at (2,...) split by coefficient lists, the pointer on card 2], length: 12pt, {
  let card(x, y, t, on: false) = {
    cdraw.rect((x, y), (x + 3.6, y + 1.5), fill: if on { luma(215) } else { luma(238) }, stroke: luma(120), radius: 0.03)
    cdraw.content((x + 1.8, y + 0.75), t, size: 6pt)
  }
  card(1.0, 4.8, [1: c=1 a=1 / 1 1 1 ...])
  card(5.4, 4.8, [2: c=1 a=2 / 2 2 2 ...], on: true)
  card(9.8, 4.8, [3: c=1,1 a=1,1 / 2 3 5 ...])
  card(5.4, 1.6, [4: c=2 a=1 / 2 4 8 ...])
  cdraw.line((6.0, 6.7), (7.2, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.0, 7.2), [tail (1,...) < (2,2,...) < (2,3,...) < (2,4,...)], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((1.0, 0.5), [n = 2 lands on the constant card c=1, a=2], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((11.0, 2.2), [the (2,...) tie group splits by coefficients], size: 6pt, anchor: "west", fill: luma(100))
})

== f, tilting tiles

A puzzle found in the attic is an h by w grid in which some cells
carry colored tiles, colors lowercase letters, and tiles of one color
cannot be told apart. Tilting the grid in one of the four cardinal
directions slides every tile that way until it is blocked by the
boundary or by another tile, and given a starting and an ending
arrangement the question is whether some sequence of tilts turns the
one into the other.

The input gives the height and width h and w, each from 1 to 500 by
the problems pdf, then h lines of length w describing the starting
arrangement from top to bottom, a dot for an empty cell and a
lowercase letter for a tile, then one empty line, then h more lines
in the same format for the ending arrangement. The output is yes or
no under the pdf's 3 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`F-tiltingtiles/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and solves in its figure with four tilts: left,
towards you, right, away from you.

input:

```
4 4
.r..
rgyb
.b..
.yr.

yrbr
..yr
...g
...b
```

expected output:

```
yes
```

Recognition: h and w at most 500 give at most 250000 tiles under
the 3 second limit. After one horizontal and one vertical tilt the
outline is frozen, each corner cycle permutes a fixed cell set,
and the work is one permutation build plus a rotation match per
cycle, O(hw) with alphabet-size factors, thousands of times inside
budget.

The statement's cue is whether some sequence of tilts turns the
one arrangement into the other, against tiles that slide flush
every move: after compaction the only freedom left is cyclic
rotation within each corner's cell cycle, the cue that the
reachability question is string rotation. Problem F is the 2023
face of the string borders, rotations, and automata family.
String borders, rotations, and automata connect chapter 08
problem K and chapter 10 problem G; a secondary thread, pairwise
congruence consistency, covers the cycle-length compatibility the
rotation match must satisfy.

Simulating tilts breadth-first from the start is the priced-out
alternative: the reachable anchored states number one per power of
the corner permutation, and the modulus those powers live on is
the lcm this section elsewhere measured overflowing at 1.9e18,
against 250000 cells.

After one horizontal and one vertical tilt the tiles sit flush in a
corner and the outline is frozen, each corner's return cycle,
right-down-left-up and its rotations, induces a fixed permutation of
the tile cells, and from then on the only moves are the four corner
re-anchors. The reachable end states are the handful reachable in
zero or one tilts plus the corner-anchored states along the
permutation's cycles, so per cycle the solutions pdf page 6 reduces
the question to whether some power of the permutation maps the start
string to the end string, which is the end string searched inside the
doubled start cycle, every match at offset a yielding the congruence
n = a (mod m) for m the cycle length, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
Book 9's chapter 33, string algorithms ii, builds the rotation match
on the doubled cycle, z-function and all, that this coset search
runs on. Two contracts the sketch leaves open, and every porting
language hits both. First, the congruences, per cycle the valid
powers form residues best modulo g with g the gcd of the cycle
length and every match difference, are never merged incrementally by
lcm, the accumulator was observed overflowing 64-bit at 1.9e18 and
then by a factor of 185. Keep one canonical residue per distinct
modulus and check every pair with the gcd of the two moduli dividing
the difference of the two residues, which is a chinese-remainder
consistency check in plain text, no constructed solution. Book 9's
chapter 16, number theory and modular arithmetic, develops the
chinese-remainder residue merge over shared prime groups that this
pairwise check stands in for. Moduli divide their cycle lengths, so
distinct moduli sum
to at most the tile count, 250000 tiles admit under 707 distinct
moduli, and same-modulus congruences from cycles of different lengths
compare residues modulo the modulus, never raw rotation offsets.
Second, from an entry corner every word reduces to sigma^r followed
by one monotone path, an away-then-back pair is the identity once
both axes are compact and any full loop conjugates back to the entry
corner's sigma, and the monotone paths are exactly seven per corner:
the empty word, both single away moves, both two-move paths to the
opposite corner, and both three-move paths to an adjacent corner,
which the earlier one-and-two-move word set misses. With clockwise
at index 0 everywhere the words are uniform, and each step resolves
against the current corner's away table, not the entry's.

The worked run: trace the model on sample 1. The four printed
tilts, left, towards you, right, away from you, walk the boards
directly, each one a compaction with order preserved. Left slides
every row flush west: r... / rgyb / b... / yr.. Then towards you
slides every column flush south: r... / r... / bg.. / yryb, all
eight tiles in the bottom-left staircase, column heights 4, 2, 1,
1, the frozen outline. Right slides the rows flush east: ...r /
...r / ..bg / yryb, and away from you slides the columns flush
north into the top-right corner with the same heights 4, 2, 1, 1
reading from the right: yrbr / ..yr / ...g / ...b, exactly the
printed target arrangement. The word is two compacting tilts plus
one return pair, the shape the model's corner cycles generate, so
the target sits on the cycle and the model answers yes, and
the trace ends at the printed answer `yes`.

#diagram([sample 1's four tilts in order: the start, left, plus towards you, plus right, and the final away landing the printed target], length: 12pt, {
  let board(x0, rows, title) = {
    for (i, r) in rows.enumerate() {
      for (j, ch) in r.clusters().enumerate() {
        if ch != "." {
          cdraw.rect((x0 + j * 0.52, 4.9 - i * 0.52), (x0 + j * 0.52 + 0.5, 5.4 - i * 0.52), fill: luma(225), stroke: luma(120), radius: 0.02)
          cdraw.content((x0 + j * 0.52 + 0.25, 5.15 - i * 0.52), ch, size: 5.5pt)
        }
      }
    }
    cdraw.content((x0 + 1.04, 2.6), title, size: 6pt, anchor: "north", fill: luma(100))
  }
  board(1.0, (".r..", "rgyb", ".b..", ".yr."), [start])
  board(3.4, ("r...", "rgyb", "b...", "yr.."), [left])
  board(5.8, ("r...", "r...", "bg..", "yryb"), [then towards you])
  board(8.2, ("...r", "...r", "..bg", "yryb"), [then right])
  board(10.6, ("yrbr", "..yr", "...g", "...b"), [then away: the target])
})

#listing("icpc/samples-c/src/Ch12/pF.c", first: 107, last: 157, caption: [c, crt_add keeping one residue per distinct modulus, cyc_match finding the coset best + gZ on the doubled cycle])

#listing("icpc/samples/src/Ch12/PF.cs", first: 145, last: 192, caption: [c\#, CycMatch through the failure function, matches folded into the gcd, then crt_add])

#listing("icpc/samples-go/ch12/pf.go", first: 110, last: 160, caption: [go, the same cycMatch closure with the crt table carried as a pointer])

#listing("icpc/samples-js/src/ch12-pf-tiltingtiles.mjs", first: 83, last: 126, caption: [javascript, crtAdd plus cycMatch over the KMP failure function from the year-local kit])

#listing("icpc/samples-py/src/Ch12/pf.py", first: 110, last: 160, caption: [python, orbit_hit: per cycle the coset and gcd, residues collected per modulus, pairwise check at the end])

#listing("icpc/samples-lua/ch12_pf.lua", first: 100, last: 147, caption: [lua, crt_add and cyc_match, the failure table from the year-local kmp module])

The C engine's first cut shipped a satisfiability flag that marked 6
of the 55 judge secrets wrong, all large possible boards, fixed in
9586ce6 by the seven-word enumeration and judged 55 of 55, with no
false positives on the 49 previously passing cases and 14 thousand
random boards cross-checked against an exhaustive tilt BFS. Porting
hygiene: the C `run_moves` reused one sigma array for both the entry
corner's cycle and the landing corner's, out-of-bounds reads that
stayed judge-green because they were never load-bearing, and the
oversight crashed the C\# port with an index error on the `1 3`
mini, so the landing cycle now lives in its own array everywhere.
The fixture is the 2x2 board with `ab` on top sliding down to `ab`
on the bottom, answered yes. Every suite also pins the one-row
`ab.` against `.ba`, no, order is preserved along a row so only
rotations of the occupied block are reachable, and the trivial
`1 1` board that needs zero tilts, yes: c 3 CHECKs, the C\# suite 5
facts carrying the crash mini, go 3 rows, javascript 3 blocks,
python 3 checks, lua 3 named checks. No integers beyond cell indices
anywhere.

#diagram([the fixture mid-tilt: both tiles sliding down, the ghost target underneath], length: 12pt, {
  let cell(x, y, t, ghost: false) = {
    cdraw.rect((x, y), (x + 1.6, y + 1.6), fill: if ghost { luma(245) } else { luma(225) }, stroke: if ghost { (paint: luma(170), dash: "dashed") } else { luma(120) }, radius: 0.02)
    cdraw.content((x + 0.8, y + 0.8), t, size: 8pt, fill: if ghost { luma(150) } else { luma(30) })
  }
  cdraw.rect((3.6, 2.0), (7.0, 5.4), stroke: luma(90), radius: 0.02)
  cell(3.75, 3.7, [a])
  cell(5.45, 3.7, [b])
  cell(3.75, 2.15, [a], ghost: true)
  cell(5.45, 2.15, [b], ghost: true)
  cdraw.line((4.55, 3.9), (4.55, 2.6), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.25, 3.9), (6.25, 2.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((7.6, 4.8), [tilt down slides both tiles], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((7.6, 3.9), [order along the slide line is preserved], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((7.6, 3.0), [ghost: the target arrangement, yes], size: 6.5pt, anchor: "west", fill: luma(100))
})

== g, turning red

The 2022 P task returns. Mei's remodeled house gives every room an
LED light that is red, green, or blue, and its pre-crossbar wiring
scatters buttons, each connected to one or more lights, with every
light answering to at most two buttons. Pressing a button steps each
connected light one place around the red, green, blue cycle, buttons
work any number of times, and the fewest total presses turning every
light red is wanted, or impossible.

The input opens with the light count l, 1 <= l <= 2e5, and the
button count b, 0 <= b <= 2l, by the problems pdf, the formal bound
admitting the b = 0 corner that the phrase two positive integers
papers over. A line of l characters R, G, or B gives the initial
colors, and each of the b button lines opens with a count k, 1 <= k
<= l, and lists k distinct lights, with each light appearing at most
twice across all buttons. The output is the minimum press count or
the word impossible under the pdf's 3 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`G-turningred/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: eight lights over six buttons, lights 5, 6, and
7 shared by two buttons and light 8 by two more, and the cheapest
consistent press count per component sums to 8.

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

Recognition: l <= 2e5 lights and b <= 2l = 4e5 buttons under the 3
second limit price linear propagation: one adjacency build plus a
BFS per component, three root trials on the unpinned ones, under
2e6 cell visits in all, two orders of magnitude inside budget.

The statement's cue is arithmetic: every light answers to at most
two buttons and each press advances a light one fixed step around
the red, green, blue cycle, so each light is one equation over at
most two unknowns mod 3, the cue that turns the house wiring into
per-component propagation with one free value. Problem G is the
2023 face of the one free value per component family. One free
value per component is the trick behind chapter 11 problem P and
chapter 13 problem K.

Searching press vectors directly is priced out at 3^b = 3^400000
worlds, and integer shortest paths or flows cannot express the
mod-3 sums at all; the three root trials per component are the
entire search space.

With colors as residues mod 3, a light on two buttons is an edge
demanding that the two
press counts sum to minus its color, a light on one button pins its
button, a light listed twice on the same
button is a self-loop pinning 2x = -c, that is x = c, and a light on
no button must already be red. Buttons sharing lights chain into
connected components, a node per button and an edge per two-button
light, and per component the solver fixes one root
press count to each of 0, 1, 2, propagates, discards inconsistent
roots, and keeps the cheapest, linear in lights plus buttons, the
solutions pdf pages 6 and 7, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
The formal bounds admit b = 0, which the prose's "two positive
integers" hides, and the solvers answer 0 or impossible straight from
the initial colors in that case.

The worked run: trace the model on sample 1. Colors as residues,
R = 0, G = 1, B = 2, the printed string GBRBRRRG reads 1, 2, 0, 2,
0, 0, 0, 1. Lights 1 and 2 sit alone on buttons 1 and 2 and pin
them at x = -c mod 3: x1 = 2, x2 = 1, while light 3 is red and
wired to no button, already right at cost 0. Light 4, blue, joins
buttons 1 and 3 with x1 + x3 = 1 mod 3, forcing x3 = 2, and
lights 5, 6 and 7, all red, join buttons 3 and 4 with x3 + x4 = 0
mod 3, forcing x4 = 1, so the 1-3-4 component, pinned through
light 1 rather than root-tried, costs 2 + 2 + 1 = 5. Light 8,
green, joins buttons 5 and 6 with x5 + x6 = 2 mod 3, an unpinned
pair: the three root trials read (0, 2), (1, 1), (2, 0) and all
press total 2. The whole is 5 + 1 + 2 + 0 = 8, the table below,
and the trace ends at the printed answer `8`.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*component*], [*pins and demands*], [*press total*]),
  [buttons 1, 3, 4], [light 1 G pins x1 = 2, light 4 B forces x3 = 2, lights 5-7 R force x4 = 1], [2 + 2 + 1 = 5],
  [button 2], [light 2 B pins x2 = 1], [1],
  [buttons 5 and 6], [light 8 G demands x5 + x6 = 2], [2],
  [light 3], [red, wired to no button], [0],
  [total], [three components, light 3 unwired], [8],
)

#listing("icpc/samples-c/src/Ch12/pG.c", first: 37, last: 67, caption: [c, try_component: stamp-carried BFS over the CSR adjacency, press total or -1 on a violated edge or pin])

#listing("icpc/samples/src/Ch12/PG.cs", first: 118, last: 155, caption: [c\#, per root t: values assigned in BFS order from any valued neighbor, then every edge and pin re-validated])

#listing("icpc/samples-go/ch12/pg.go", first: 71, last: 101, caption: [go, the propagate closure resetting only the touched cells between root trials])

#listing("icpc/samples-js/src/ch12-pg-turningred.mjs", first: 69, last: 96, caption: [javascript, the same closure over chained edge arrays, touched cells reset afterwards])

#listing("icpc/samples-py/src/Ch12/pg.py", first: 47, last: 93, caption: [python, anchored at the pin when one exists, three roots only for unpinned components])

#listing("icpc/samples-lua/ch12_pg.lua", first: 107, last: 142, caption: [lua, try_component with per-trial stamps, one-based queue like c])

The fixture is 4 lights over 2 buttons, colors RBBB: light 1 is red
and alone on button 1, pinning x1 = 0, light 3 is blue and alone on
button 2, pinning x2 = 1, and lights 2 and 4 sit on both buttons with
x1 + x2 = 1 mod 3, consistent. One press of button 2 turns lights 2,
3, and 4 red, and the answer is 1. The crafted pair carries the
contradiction, both lights green on both buttons demanding x1 + x2
equal 2 and 1 at once, impossible, and the single button with both
lights green, 2. Counts: c 3 CHECKs, the C\# suite 5 facts, go 3
rows, javascript 3 blocks, python 6 checks, lua 3 named checks.
Everything lives mod 3 and press totals stay under 4e5, so no integer
notes.

#diagram([two button nodes joined by two light edges, the single-button leaves pinning x1 and x2], length: 12pt, {
  let node(x, y, t) = {
    cdraw.circle((x, y), radius: 0.55, fill: luma(225), stroke: luma(120))
    cdraw.content((x, y), t, size: 6.5pt)
  }
  node(3.0, 6.2, [b1 x=0])
  node(9.0, 6.2, [b2 x=1])
  cdraw.line((3.0, 6.2), (9.0, 6.2), stroke: luma(100))
  cdraw.content((4.4, 6.9), [L2 B: x1+x2 = 1], size: 6pt, fill: luma(100))
  cdraw.content((4.4, 5.4), [L4 B: x1+x2 = 1], size: 6pt, fill: luma(100))
  cdraw.line((3.0, 5.65), (3.0, 6.75), stroke: luma(100))
  cdraw.line((8.4, 6.2), (9.6, 6.2), stroke: luma(100))
  node(1.0, 3.4, [L1 R])
  cdraw.line((1.0, 3.95), (2.6, 5.75), stroke: luma(130))
  cdraw.content((0.8, 2.3), [pins x1 = 0], size: 6pt, fill: luma(100))
  node(11.0, 3.4, [L3 B])
  cdraw.line((11.0, 3.95), (9.4, 5.75), stroke: luma(130))
  cdraw.content((10.4, 2.3), [pins x2 = 1], size: 6pt, fill: luma(100))
  cdraw.content((4.6, 1.2), [0 + 1 = 1 holds, press button 2 once], size: 6.5pt, anchor: "west", fill: luma(100))
})

== h, jet lag

The world finals pack speeches, events, and the contest itself into
the schedule, and at minute 0 you arrive so exhausted that you must
sleep immediately. A sleep of k whole minutes, k any positive
integer, is followed by k rested minutes in which falling asleep is
impossible, then k functional minutes in which you may sleep again
or stay awake, and past that comes an involuntary endless sleep: a
sleep ending at t must have its successor start inside [t+k, t+2k],
and the final sleep's functional stretch must carry you past the end
of the last activity. Activities occupy fixed intervals you must
attend entirely, no sleep may overlap one, and none may run past the
start of the last, so the task prints any valid schedule or
impossible.

The input is the activity count n, 1 <= n <= 2e5 by the problems
pdf, then n lines of begin and end minutes bi and ei with bi < ei,
ei <= b(i+1) so touching activities are allowed, 0 <= b1, and
en <= 1e10. A valid schedule prints the period count p, the pdf
guaranteeing one with at most 1e6 periods exists whenever any does,
then p lines of start and end times si and ti obeying 0 = s1 < t1 <
s2 < ... < tp <= bn: you may fall asleep the minute an activity
ends, si = ej, and wake the minute one begins, ti = bj, and any
valid schedule is accepted under the pdf's 2 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`H-jetlag/sample-1.in` and `sample-1.ans`, the same pair the problems
pdf prints: three activities, and sleeping the full first gap then
the full last gap covers every window, exactly the greedy's
canonical output. The judges' own sample 3 answer spends five sleeps
where four suffice, both valid, the any-schedule scoring at work.

input:

```
3
30 45
60 90
120 180
```

expected output:

```
2
0 30
90 120
```

Recognition: n <= 2e5 activities with ends to 1e10 under the 2
second limit, and any valid schedule accepted: the greedy's passes
visit each gap once, about 6e5 steps, five orders of magnitude
inside budget, and the pdf itself guarantees a schedule with at
most 1e6 periods exists whenever any does.

The statement's cue is the window law, a sleep ending at t must
have its successor start inside [t+k, t+2k]: the constraint is a
local feasibility window per gap, the cue that a provably safe
local rule, take the full-gap sleep whenever it strictly extends
the awake horizon, then repair, orders the whole schedule. Problem
H is the 2023 face of the greedy with a safety proof family.
Greedy with a safety proof is the family of chapter 08 problem H,
chapter 09 problem K, and chapter 10 problem A.

A dp over the minute timeline is priced out by the coordinates
alone, 1e10 minutes, and a dp over gap subsets costs (2e5)^2 = 4e10
pairs against the linear pass.

The sleep model is the statement's own, pinned against the official
samples and carried on the solutions pdf page 7, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
The greedy walks the gaps between activities, the first gap starting
at 0, takes a full-gap sleep spanning each gap ahead whenever it
strictly extends the awake horizon b + 2(b - e), then repairs
consecutive sleeps: whenever the next start would come before twice
the previous end minus its start, the previous end trims down to half
the sum of the two starts, which only shrinks k, so the crash bounds
survive. Linear time, and
the book's suites pin this exact canonical construction byte for
byte, which is why the judge harness needs a validator rather than a
diff.

The worked run: trace the model on sample 1. The gaps are [0, 30]
before the first activity, [45, 60] between the first two, and
[90, 120] before the last. The greedy takes the full-gap sleep
[0, 30]: k = 30, and the awake horizon becomes b + 2(b - e) = 30 +
2(30 - 0) = 90. The candidate [45, 60] would set the horizon to
60 + 2(60 - 45) = 90, not a strict extension, so it is skipped,
the safety proof's own exchange: the skipped sleep buys no awake
time. The greedy takes [90, 120]: the successor window of [0, 30]
is [t + k, t + 2k] = [60, 90], the start 90 sits at its right end,
the horizon becomes 120 + 2(120 - 90) = 180, and the final sleep's
functional stretch reaches t + 2k = 180 >= 180, the last
activity's end, so no repair pass fires. Two sleeps, printed 0 30
and 90 120, and the trace ends at the printed answer `90 120`.

#diagram([sample 1's timeline: the two taken sleeps, the skipped middle gap crossed out, the crash bound landing exactly at 180], length: 12pt, {
  let mx(m) = 1.2 + m / 180 * 13.4
  let span(m1, m2, y, t, fill) = {
    cdraw.rect((mx(m1), y), (mx(m2), y + 0.7), fill: fill, stroke: luma(140), radius: 0.02)
    cdraw.content(((mx(m1) + mx(m2)) / 2, y + 0.35), t, size: 6pt)
  }
  cdraw.line((1.0, 1.0), (15.0, 1.0), stroke: luma(120), mark: (end: ">"))
  for (m, t) in ((0, [0]), (30, [30]), (45, [45]), (60, [60]), (90, [90]), (120, [120]), (180, [180])) {
    cdraw.line((mx(m), 0.85), (mx(m), 1.15), stroke: luma(120))
    cdraw.content((mx(m), 0.4), t, size: 6pt, fill: luma(100))
  }
  span(0, 30, 5.6, [sleep 0..30], luma(210))
  span(45, 60, 5.6, [45..60], luma(245))
  span(90, 120, 5.6, [sleep 90..120], luma(210))
  cdraw.line((mx(45), 6.5), (mx(60), 5.5), stroke: luma(60))
  cdraw.line((mx(60), 6.5), (mx(45), 5.5), stroke: luma(60))
  cdraw.content((mx(60) + 0.2, 6.6), [skipped: `60 + 2*15 = 90`, no strict gain], size: 6pt, anchor: "west", fill: luma(100))
  for (m1, m2) in ((30, 45), (60, 90), (120, 180)) {
    span(m1, m2, 3.4, [#str(m1) .. #str(m2)], luma(190))
  }
  cdraw.content((1.2, 2.3), [final crash at 120 + 2*30 = 180 = e3, the last end covered], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch12/pH.c", first: 38, last: 78, caption: [c, the greedy pass, the last-window cover check, then the rested-window repair with the trim floor])

#listing("icpc/samples/src/Ch12/PH.cs", first: 30, last: 73, caption: [c\#, the same three passes over long arrays, horizon, cover, repair])

#listing("icpc/samples-go/ch12/ph.go", first: 26, last: 50, caption: [go, the compact core: gap sleeps extending crash, then the one-line trim loop])

#listing("icpc/samples-js/src/ch12-ph-jetlag.mjs", first: 23, last: 42, caption: [javascript, the same core over Float64Array times, floor on the trim])

#listing("icpc/samples-py/src/Ch12/ph.py", first: 21, last: 47, caption: [python, sleeps as [s, t] pairs, the trim rejecting a rest that cannot fit])

#listing("icpc/samples-lua/ch12_ph.lua", first: 32, last: 72, caption: [lua, gap 0 spans [0, b1] through a sentinel pair, repair trims with floor division])

The fixture is one activity 40 to 50: the only gap is [0,40], the
full-gap sleep keeps the window alive to 120, and the answer is
`1 / 0 40`. The repair case, activities 12 to 20 and 30 to 40, takes
both gaps and then trims the first sleep to `0 10`, and the activity
starting at 0 makes any first sleep overlap it, impossible. Every
suite asserts those three exact outputs: c 3 CHECKs, the C\# suite 3
facts, go 3 rows, javascript 3 blocks, python 4 checks, lua 3 named
checks. Times run to 1e10 and window arithmetic to 3e10, so int64 in
c, C\#, go, and lua, and javascript numbers, exact below 2^53 with
room to spare. The validator itself is part of this set's measured
record: the harness's first overlap check was O(p*n) in pure shell
and would never finish on the big cases, about 4e10 iterations, and
the fix is a monotone base pointer over the sleeps plus
`[System.Array]::BinarySearch` for the first activity at or after
each sleep end, O(p log n), roughly 9 seconds per big case and 18
minutes for all 126. Never hand-roll a midpoint binary search in
powershell, its `[int]` cast rounds to even, so `hi = mid` can spin
forever on an odd sum, and go's first patch hung for 90 minutes
exactly that way before the BinarySearch rewrite.

#diagram([the fixture: one full-gap sleep, its rested and functional stretches, the activity inside the window], length: 12pt, {
  let bar(x, w, y, fill) = cdraw.rect((x, y), (x + w, y + 0.7), fill: fill, stroke: luma(140), radius: 0.02)
  bar(1.0, 4.5, 4.6, luma(210))
  cdraw.content((3.25, 5.3), [sleep 0..40], size: 6pt, fill: luma(100))
  bar(5.5, 4.5, 4.6, luma(232))
  cdraw.content((7.75, 5.3), [rested 40..80], size: 6pt, fill: luma(100))
  bar(10.0, 4.5, 4.6, luma(245))
  cdraw.content((12.25, 5.3), [functional 80..120], size: 6pt, fill: luma(100))
  bar(5.5, 1.1, 3.0, luma(190))
  cdraw.content((6.05, 2.0), [activity 40..50], size: 6pt, fill: luma(100))
  cdraw.line((1.0, 0.9), (14.5, 0.9), stroke: luma(120), mark: (end: ">"))
  cdraw.content((1.2, 0.2), [0], size: 6pt, fill: luma(100))
  cdraw.content((14.3, 0.2), [120], size: 6pt, fill: luma(100))
  cdraw.content((1.0, 6.6), [crash only past 120, the activity end at 50 is covered], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((1.0, 1.9), [no sleep may start before 80], size: 6.5pt, anchor: "west", fill: luma(100))
})

== i, waterworld

A faraway rotating planet is measured by a technology the statement
dresses up as relativistic quantum-polarized spectroscopy, and the
model under the dressing is clean: the planet is a sphere turning
about a vertical axis, the telescope resolves only the strip through
that axis, and the read proceeds in m steps of d = 360/m degrees,
each step reporting the water percentage of n equal-height bands from
pole to pole for the slice it just saw, the md = 360 steps together
covering the whole surface. The task is the planet's total water
percentage.

The input is n and m, each from 2 to 1000 by the problems pdf, then n
lines of m integers a(i,j), each 0 to 100, row i holding band i's
readings across the m rotation steps in order. The output is one
percentage with an absolute error of at most 1e-6 under the pdf's 3
second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`I-waterworld/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: 21 readings over 3 bands and 7 steps, their sum
1088, and the average is 51.809523810.

input:

```
3 7
63 61 55 54 77 87 89
73 60 38 5 16 56 91
75 43 11 3 16 20 95
```

expected output:

```
51.809523810
```

Recognition: n and m at most 1000 give at most 1e6 readings under
the 3 second limit, one summation pass, so the cost is trivial and
the only trap is the invariant: the tempting per-band spherical
quadrature, 1000 bands of trig-weighted areas, about 1e6 extra
transcendentals, computes a weighting the equal-area law pins as
constant.

The statement's cue is the planet's total water percentage read in
equal-height bands over a full rotation: spherical zone area is
proportional to height, so every band covers the same surface
fraction at every step, the cue that one proportionality collapses
the whole task to a plain average. Problem I is the 2023 face of
the invariant collapse family. Chapter 11 problem Y is the other
invariant collapse member.

Spherical zone areas are proportional to height, the cylindrical
equal-area projection, so every band covers the same surface fraction
during a full rotation and hence during every step, each of the `n*m`
readings weighs the same, and the planet's water percentage is the
plain average of all of them, the one-line derivation on the
solutions pdf pages 7 and 8, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
This is the set's breather, one sum and one division.

The worked run: trace the model on sample 1. The three printed
band rows sum to 486, 339 and 263, the table below, and
486 + 339 + 263 = 1088 readings-total over the grid's 3 times 7 = 21
readings.
Equal-height bands carry equal zone area and every rotation step
covers the same fraction of each zone, so each of the 21 readings
weighs the same and the planet's water percentage is the plain
average 1088/21 = 51.809523810, and
the trace ends at the printed answer `51.809523810`.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*band*], [*row sum*], [*weight*]),
  [1], [63 + 61 + 55 + 54 + 77 + 87 + 89 = 486], [1/21],
  [2], [73 + 60 + 38 + 5 + 16 + 56 + 91 = 339], [1/21],
  [3], [75 + 43 + 11 + 3 + 16 + 20 + 95 = 263], [1/21],
  [planet], [1088], [1088/21 = 51.809523810],
)

#listing("icpc/samples-c/src/Ch12/pI.c", first: 20, last: 33, caption: [c, the whole solver: sum the n times m readings, print the average at nine decimals])

#listing("icpc/samples/src/Ch12/PI.cs", first: 13, last: 23, caption: [c\#, the same sum over the parsed longs, F9 with the invariant culture])

#listing("icpc/samples-go/ch12/pi.go", first: 10, last: 19, caption: [go, int64 sum, one Sprintf])

#listing("icpc/samples-js/src/ch12-pi-waterworld.mjs", first: 10, last: 18, caption: [javascript, parseFloat accumulation, toFixed(9)])

#listing("icpc/samples-py/src/Ch12/pi.py", first: 8, last: 12, caption: [python, one f-string over the int sum])

#listing("icpc/samples-lua/ch12_pi.lua", first: 27, last: 37, caption: [lua, the double loop over rows and steps, string.format])

The fixture is the 2x2 scan 0 100 / 100 0, whose equal-area average
is exactly 50.000000000, and the crafted all-seven 2x3 grid answers
7.000000000. Counts: c 2 float CHECKs, the C\# suite 3 facts, go 2
rows, javascript 2 blocks, python 3 checks, lua 2 named checks. The
sum tops out at 1e6 readings of 100, one hundred million, an int32
ceiling with margin, so the int accumulators are safe everywhere and
only the final division is floating point.

#diagram([the sphere in equal-height bands, one rotation wedge lifted out, the fixture percentages per band], length: 12pt, {
  cdraw.circle((4.2, 4.2), radius: 3.1, stroke: luma(110))
  for i in range(5) {
    let y = 2.05 + i * 1.07
    cdraw.line((1.28, y), (7.12, y), stroke: (paint: luma(165), dash: "dashed"))
  }
  cdraw.line((4.2, 4.2), (4.2, 7.3), stroke: luma(90), mark: (end: ">"))
  cdraw.content((4.6, 7.0), [rotation axis], size: 6pt, fill: luma(100))
  cdraw.content((1.7, 3.7), [band 1: 0 then 100], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((2.1, 2.62), [band 2: 100 then 0], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((8.6, 4.9), [each band covers the same area], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((8.6, 4.0), [each rotation step weighs the same], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((8.6, 3.1), [(0 + 100 + 100 + 0) / 4 = 50], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.line((4.2, 4.2), (6.85, 5.35), stroke: luma(90))
  cdraw.line((4.2, 4.2), (5.8, 6.7), stroke: luma(90))
  cdraw.line((6.85, 5.35), (9.4, 6.4), stroke: luma(130))
  cdraw.content((9.6, 6.4), [one d-degree wedge], size: 6pt, anchor: "west", fill: luma(100))
})

== j, bridging the gap

The 2022 S task returns with the same input and output shapes. A
group of n walkers reaches a river at night carrying one torch, the
old bridge holds at most c walkers at a time, the torch must travel
with every crossing and come back for the next, a group crosses at
its slowest member's pace, and the task is the minimum total
crossing time. The statement works its own sample by hand, four
walkers of 1, 2, 5, and 10 minutes at capacity 2 finishing in 17:
the two fastest over, the fastest back, the two slowest over, the
second-fastest back, the two fastest over again.

The input is the walker count n, 2 <= n <= 1e4, and the capacity c,
2 <= c <= 1e4, by the problems pdf, then one line of n crossing
times t1 through tn, each from 1 to 1e9 minutes, arriving in any
order. The output is the single minimum total time under the pdf's 4
second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`J-bridgingthegap/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints and works by hand: the four times arrive
unsorted, 1 2 10 5, and the answer is the classic 17.

input:

```
4 2
1 2 10 5
```

expected output:

```
17
```

Recognition: n <= 1e4 and c <= 1e4 under the 4 second limit price
an exact state machine, not a smarter formula: the (k, g, l) space
holds 5e7 to 3.5e8 live states on the judge secrets, and the
shipped engines visit each state once at O(1) amortized, which is
what the limit buys, the same ratification chapter 11 measured.

The statement's cue is the torch ledger: every crossing and every
return changes who stands where, and the optimum turns on the
contiguous block of banked fast walkers, the cue that the state
must be engineered by hand rather than read off the input. Problem
J is the 2023 face of the dp over an engineered state space
family. The dp over an engineered state space family spans chapter
11 problem S, chapter 09 problem J, chapter 10 problem I, and
chapter 13 problem H.

The classic c = 2 greedy shuffle is the tempting rule and the
year's own judge data prices it out: secrets 054 through 102 are
tagged wrong-greedy torture cases, and the shuffle misprices every
one of them, while the exact sweep fits the same limit.

Every language here ships the engine chapter 11 ratified for the 2022
original, and the exact state is (k, g, l), the k slowest delivered,
the far side banking exactly walkers g through g+l-1, torch near.
The structure the solutions pdf page 8 proves keeps the machine
small: a back crossing is always a single walker, and a forward
crossing is the escorted batch, j slow walkers plus c-j escorts who
will cross back, the pure slow batch returned by the banked walker
g, or the pure fast batch, with the person-0 shuttle completion
pricing the endgame. The useful banked count l never passes about
n/c, so the states run O(n^2/c) with O(c) transitions each and the
real cost is O(n^2) after pruning unreachable states, and the judges
warn the implementation is tricky, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
The c solver parses through chapter 11's `ch11_scan.h` and go
through the package's own `ch12.go` twin, and chapter 11's helper
section prints the scan cursor this solver includes.
The 2023 secrets 054 through 102 are tagged wrong-greedy torture
cases, the classic c=2 shuffle is not enough. Two engine shapes
cover the six languages, the pull-based row sweep with lazy window
heaps in C and the diagonal sweep with sliding-window materialization
in go, javascript, python, and lua, and the C\# and javascript
entries literally delegate to their chapter 11 engines.

The worked run: trace the model on sample 1. The times sorted
ascending are t = 1, 2, 5, 10, capacity 2, and the machine opens
at (k, g, l) = (0, 1, 0), torch near, nothing delivered. The pure
fast batch sends persons 0 and 1 over at t[l + j - 1] = t[1] = 2
with person 0 shuttling back at t[0] = 1, cost 2 + 1 = 3, banking
the block g = 1, l = 1 at (0, 1, 1). The pure slow batch sends the
two slowest, persons 2 and 3, over at t[n - k - 1] = t[3] = 10
with the banked walker t[g] = t[1] = 2 returning the torch, cost
10 + 2 = 12, landing at (2, 2, 0). Now n - k - l = 4 - 2 - 0 = 2
<= c, so the finish transition crosses everyone left at the near
side's slowest pace t[n - k - 1] = t[1] = 2. The ledger reads
3 + 12 + 2 = 17, the table below, and
the trace ends at the printed answer `17`.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*transition*], [*batch*], [*cost*], [*landing*]),
  [pure fast, j = 2], [persons 0 and 1 over at 2, person 0 back at 1], [3], [(0, 1, 1)],
  [pure slow, j = 2], [persons 2 and 3 over at 10, banked t[1] = 2 back], [12], [(2, 2, 0)],
  [finish], [everyone left over at t[1] = 2], [2], [done],
  [total], [three machine moves], [17], [],
)

#listing("icpc/samples-c/src/Ch12/pJ.c", first: 203, last: 252, caption: [c, the per-cell pull: seed, pure-fast column heap, escorted row heap, per-g pure-slow buckets, in-row handoff, finish])

#listing("icpc/samples/src/Ch12/PJ.cs", first: 1, last: 12, caption: [c\#, the whole file: Solve forwards to the Ch11 S engine, the problems are byte-compatible])

#listing("icpc/samples-go/ch12/pjfast.go", first: 62, last: 96, caption: [go, stride prefix sums price the shuttle in O(1), cells live in one reusable diagonal buffer])

#listing("icpc/samples-js/src/ch12-pj-bridgingthegap.mjs", first: 1, last: 23, caption: [javascript, the entry point imports ch11-ps outright and re-runs its self-check])

#listing("icpc/samples-py/src/Ch12/pj.py", first: 46, last: 92, caption: [python, the c=2 classic shortcut, judged caps, stride prefix sums, and the bitmask diagonal buffer])

#listing("icpc/samples-lua/ch12_pj.lua", first: 26, last: 53, caption: [lua, requires ch11_psweep verbatim, parse and sort only, the wall documented in the header])

The fixture is 3 walkers at capacity 2 with times 1 2 3: the pair 1
and 2 crosses for 2, walker 1 returns for 1, and 1 and 3 cross for 3,
total 6 against 7 for shipping the slow pair first. Every suite
asserts 6, plus the pair crossing together at 7 and the
capacity-covers-all 9: c 3 CHECKs, the C\# suite 3 facts, go 3 rows,
javascript 3 blocks, python 3 checks, lua 4 named checks. Totals
reach about 2e13, int64 in c, C\#, go, and lua, exact below 2^53 in
javascript doubles, native in python. The judged record splits the
families, and this chapter records the walls rather than pretending:
go finishes the 104 cases in roughly 11 seconds worst, javascript in
72.8, c in 58 to 99 seconds of CPU, and C\# in 95 to 129 at JIT
parity with c. Python judges 57 of 104 with exactly 47 timeouts and
zero wrong answers, every timeout an n = 1e4 secret with c in
[3, 500], and the mechanism is CPython's 30-bit fast-int boxing: once
the dp totals pass 1e13 every sweep operation allocates a boxed
multi-digit integer, so the sweep becomes allocation-bound where the
compiled languages are not. Lua's verdict is load-dependent, and the
chapter records both measurements with their context: on a quiet
machine the same `ch11_psweep` engine judges 88 of 104 with 16
timeout-only failures, under four to five concurrent book agents the
count was 70 of 104 with 34, and both runs score zero wrong answers,
which closes the year at 635 of 651 lua cases with ten of eleven
problems fully clean. The 2022 ratification measured this engine at
142 to 417 seconds on the heaviest shapes, and letting three of the
wrong-greedy cases run to 192 to 198 seconds produced answers
matching the official ones, so every failure is interpreter speed,
not correctness. Both walls are terminal in the ratified sense, the
sweep operation is itself the work and no restructure exists, the 47
versus 4 timeout asymmetry between python and lua on the same state
space being the measured evidence.

#diagram([the fixture's three crossings on a timeline, the torch return dashed], length: 12pt, {
  let bar(x, w, y, t, fill: luma(225)) = {
    cdraw.rect((x, y), (x + w, y + 0.7), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.35), t, size: 6pt)
  }
  cdraw.line((1.0, 0.8), (1.0, 7.0), stroke: luma(120), mark: (end: ">"))
  cdraw.content((0.7, 7.5), [0], size: 6pt, fill: luma(100))
  bar(1.0, 2.0, 5.8, [1 and 2 cross, 2])
  bar(3.0, 1.0, 4.6, [1 returns, 1], fill: luma(245))
  bar(4.0, 3.0, 3.4, [1 and 3 cross, 3])
  cdraw.line((3.0, 6.5), (4.0, 3.7), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((7.4, 5.6), [dashed: torch return], size: 6pt, fill: luma(100))
  cdraw.content((1.3, 1.6), [total 6, the exact (k, g, l) sweep agrees with brute force], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((1.3, 0.6), [capacity 2 forbids the single three-walker trip], size: 6.5pt, anchor: "west", fill: luma(100))
})

== k, alea iacta est

The game plays with d fair six-sided dice, each face carrying one
symbol, and a dictionary of valid words, every word exactly d symbols
long. You roll all the dice, and after each roll you may lock any
dice and reroll the rest, stopping as soon as the shown symbols can
be arranged into a dictionary word, and the task prints the expected
number of rolls under optimal play, or impossible when no play ever
spells one. The statement walks its own sample: five dice first show
P, X, R, E, and S, you keep P, E, and S, the two rerolled dice yield
E and A, then you keep four symbols and reroll the last die, one
with three C faces, a 50 percent shot at PEACE.

The input is d and w, the die count 1 <= d <= 6 and the word count
1 <= w <= 2e5 by the problems pdf, then d lines of 6 symbols each,
the faces of each die, then w distinct words of exactly d symbols
over uppercase A through Z and digits 0 through 9. The output is the
expected roll count with an absolute or relative error of at most
1e-6, or the word impossible, under the pdf's 10 second limit.

Official sample 1, reprinted byte for byte from the judge data pair
`K-aleaiactaest/sample-1.in` and `sample-1.ans`, the same pair the
problems pdf prints: the five dice and eight P-words of the story,
and optimal play averages 9.677887141 rolls.

input:

```
5 8
ABCDEP
AEHOXU
AISOLR
ABCDEF
ABCSCC
PARSE
PAUSE
PHASE
POISE
PROSE
PULSE
PURSE
PEACE
```

expected output:

```
9.677887141
```

Recognition: d <= 6 and w <= 2e5 under the 10 second limit price
the state machine: 7^d lock vectors, 7^6 = 117649 at worst, with
2^d - 1 = 63 starring choices per fixed state, about 8e6
transitions materialized once and swept in place, while the w
words hash in O(w d), linear in everything that matters.

The statement's cue is the expected number of rolls under optimal
play, or impossible: an expectation over an enormous implicit
outcome tree, priced by a fixed point over the lock states rather
than by listing plays. Problem K is the 2023 face of the counting
and expectation without enumeration family. Counting and
expectation without enumeration is the shared core of chapter 09
problem D, chapter 09 problem I, chapter 11 problem Q, and chapter
12 problem E.

Enumerating play sequences is the priced-out alternative: each
round branches 63 starring choices into up to 6^6 = 46656 roll
outcomes, and the expectation needs the whole tree, while the
fixed point is 117649 cells swept to convergence.

Each die shows at most six distinct symbols, so per die the symbols
map to local ids with face multiplicities and digit 6 marks
rerolling, and states are base-7 vectors, 7^6 = 117649 at worst.
From a starred state one roll costs 1 and lands on the
multiplicity-weighted average of its outcome refinements, from a
fixed non-goal state any nonempty subset may be starred at cost 0,
and the goal states are the fixed states whose shown symbols sort to
a dictionary word's sorted multiset, each word canonicalized by
sorting into one hash set of w entries. The solutions pdf pages 8
and 9 run dijkstra backwards with incremental sums, per
undetermined state a count of processed refinements and their
running dist sum relaxing dist at (6^s + sum) / count, about
O(7^d * d + w * d), but the book's engines sweep in-place value
iteration to a 1e-13 fixed point, because the backward dijkstra
shortcut can freeze early when refinements with larger distances pop
late, and the pdf itself notes every contest team used value
iteration, problem at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf].
Book 9's chapter 32, dynamic programming ii, develops this style of
value iteration over the word-multiset states.

The worked run: trace the model on sample 1. The five printed dice
map to per-symbol face counts and the eight printed words all open
with P, a symbol only die 1 carries, on one face of six. The lock
space is 7^5 = 16807 vectors, the goal states the fixed vectors
whose sorted symbols match one of the eight sorted words. The
statement's own walk plays the model's moves: from P, X, R, E, S
no word matches, and the move keeps P, E, S, starring X and R.
The reroll yields E and A, giving P, E, A, E, S, still no match,
and the move keeps four symbols, rerolling only die 5, whose
printed faces A, B, C, S, C, C carry C on three of six: the shot
at PEACE is 3/6 = 1/2. The sweep prices every such decision
together and settles at the expectation the judge prints, and
the trace ends at the printed answer `9.677887141`.

#diagram([sample 1's statement walk: the kept symbols shaded at each state, the final shot at PEACE priced off die 5], length: 12pt, {
  let state(x0, letters, keep, title) = {
    for (i, ch) in letters.enumerate() {
      let kept = i in keep
      cdraw.rect((x0 + i * 0.62, 4.6), (x0 + i * 0.62 + 0.58, 5.5), fill: if kept { luma(215) } else { luma(240) }, stroke: luma(120), radius: 0.02)
      cdraw.content((x0 + i * 0.62 + 0.29, 5.05), ch, size: 7pt)
    }
    cdraw.content((x0 + 1.55, 4.1), title, size: 6pt, anchor: "north", fill: luma(100))
  }
  state(1.0, ("P", "X", "R", "E", "S"), (0, 3, 4), [keep P, E, S])
  state(5.4, ("P", "E", "A", "E", "S"), (0, 1, 2, 3), [keep P, E, A, E])
  state(9.8, ("P", "E", "A", "E", "?"), (0, 1, 2, 3), [reroll die 5])
  cdraw.line((7.3, 3.3), (9.6, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.45, 3.65), [die 5: C on 3 of 6], size: 6pt, anchor: "south", fill: luma(100))
  cdraw.content((1.0, 2.3), [3/6 = 1/2 shot at PEACE, and the sweep prices every such line together], size: 6.5pt, anchor: "west", fill: luma(100))
})

#listing("icpc/samples-c/src/Ch12/pK.c", first: 157, last: 205, caption: [c, the Gauss-Seidel sweep: outcome enumeration by combo odometer over the starred dice, starring masks for fixed states])

#listing("icpc/samples/src/Ch12/PK.cs", first: 130, last: 176, caption: [c\#, transitions materialized once into flat outY and outM arrays so every sweep is a linear scan])

#listing("icpc/samples-go/ch12/pk.go", first: 93, last: 143, caption: [go, the same sweep in decreasing state order, the odometer over per-die live symbols])

#listing("icpc/samples-js/src/ch12-pk-aleaiactaest.mjs", first: 98, last: 141, caption: [javascript, the outcome odometer and the 2^d-1 starring masks over typed arrays])

#listing("icpc/samples-py/src/Ch12/pk.py", first: 63, last: 94, caption: [python, the contraction dag: rows map each subset's cells onto its parent's layout, work shared down the hierarchy])

#listing("icpc/samples-lua/ch12_pk.lua", first: 108, last: 149, caption: [lua, outcome pairs and starring targets precomputed into flat arrays, poff slicing per state])

The fixture is one die ABBBBB against the word A: each roll shows A
with probability 1/6, the roll count is geometric, and the answer is
6.000000000 with no choices to optimize. The crafted pair adds the
free die, AAAAAA beside ABCDEF spelling AB still averages 6 because
only the second die matters, and the word B on an all-A die is
impossible. Counts: c 3 float CHECKs, the C\# suite 3 facts, go 3
rows, javascript 3 blocks, python 4 checks including the
deterministic AAAAAA BBBBBB pair at 1.000000000, lua 3 named checks.
Doubles throughout, 7^6 states, and the 1e18 seed separates
impossible cleanly. Performance is where the languages split, and K
is the set's constructive counterpoint to J: the wall was table
construction, not the arithmetic, and it restructured away. Python's
first value iteration capped at about 700 Gauss-Seidel sweeps and ran
the four d=6 secrets at 190 to 230 seconds against the 10-second
limit. Porting lua's precomputed transition arrays brought flat
sweeps with zero per-state construction, lua's plain sweeps needing
about 400 passes on the d=6 cases before the precompute, and got
python to 98 to 132 seconds. Replacing the starred half of each
python sweep with a contraction hierarchy over the 63 subset sums,
refinements of reroll-S share their work down a dag, cut each sweep
from roughly 205 to 85 milliseconds and closed the d=6 secrets at 61
to 81 seconds, 33 to 50 percent under the cap, judged 27 of 27 with
correctness held against an 80-instance independent reference within
4e-9. The contrast is one sentence: K's wall was build cost and
moved, J's sweep arithmetic is the work itself and does not move.

#diagram([the one-die state ladder: A on top, the star rung below, the 1/6 chance up, the 5/6 self-loop], length: 12pt, {
  cdraw.rect((6.0, 5.6), (10.0, 6.8), fill: luma(215), stroke: luma(110), radius: 0.06)
  cdraw.content((8.0, 6.2), [state A, goal, dist 0], size: 6.5pt)
  cdraw.rect((6.0, 2.4), (10.0, 3.6), fill: luma(235), stroke: luma(110), radius: 0.06)
  cdraw.content((8.0, 3.0), [state \*, rerolling], size: 6.5pt)
  cdraw.line((6.6, 3.6), (6.6, 5.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.4, 4.6), [1/6 up], size: 6.5pt, fill: luma(100))
  cdraw.circle((11.9, 3.0), radius: 0.75, stroke: luma(110))
  cdraw.line((10.7, 3.3), (11.3, 3.6), stroke: luma(110), mark: (end: ">"))
  cdraw.line((11.3, 2.4), (10.7, 2.7), stroke: luma(110), mark: (end: ">"))
  cdraw.content((11.9, 1.6), [5/6 stay], size: 6.5pt, fill: luma(100))
  cdraw.content((2.0, 6.4), [E = 1 + (5/6) E, so E = 6], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((2.0, 5.4), [the die ABBBBB rolls A with probability 1/6], size: 6.5pt, anchor: "west", fill: luma(100))
  cdraw.content((2.0, 0.8), [d = 1 of the 7^d state space], size: 6.5pt, anchor: "west", fill: luma(100))
})

== across the six languages

#table(
  columns: 5,
  table.header([*problem*], [*kernel*], [*c and c\#*], [*go and js*], [*python and lua*]),
  [a], [exclusion hypotheses over triples of the five rows], [all ten triples per hypothesis, c\# reads line 4 at the lie], [first three surviving rows, one det3], [comprehension walk, nine-scalar det],
  [b], [sperner cap, n largest strings, cyclic repeat], [callback enumerator vs sorted masks], [recursive gen, 1 branch first], [`first_subsets` helpers over one-positions],
  [c], [doubled score points, two hull halfplane queries], [`ch12_hull` kit, cs edge walk with bounds], [monotone chain, per-edge interpolation], [bisect counts, hull modules],
  [d], [unfold-straights plus corner chains], [1024-grid ternary legs, cs run bisection], [closure-based bestLeg, js crossing order], [grid ternary ports over flat scalars],
  [e], [counting dp with forward prune, direct enumeration], [c saturating int128 sums, cs string-keyed memo], [js typed-array chained hash past the Map cap], [depth-indexed scratch, py raised cap],
  [f], [corner sigma cycles, rotation congruences pairwise], [`crt_add` per distinct modulus, kmp kit], [same closures, crt table by pointer], [orbit walk, residues per modulus],
  [g], [mod-3 propagation over button components], [stamp-retry BFS, cs revalidates BFS order], [touched-cell reset closures], [anchored at pins, lua stamps like c],
  [h], [full-gap greedy plus rested-window repair], [three passes over long arrays], [compact cores, floor trims], [pair lists, floor division trims],
  [i], [equal-area bands, plain average], [int sums, F9 culture], [one Sprintf, toFixed(9)], [one f-string, string.format],
  [j], [exact (k, g, l) machine, no safe caps], [c pull sweep with lazy heaps, cs delegates], [diagonal sweep, js imports `ch11-ps`], [bitmask sweep, lua requires `ch11_psweep`],
  [k], [value iteration to a 1e-13 fixed point], [combo odometer, cs flat transition arrays], [decreasing-order sweep, typed arrays], [py contraction dag, lua precomputed pairs],
)

The pattern this set adds to the book's ledger: one interactive
problem whose judge-file reading was retracted as circular validation
and re-derived from the file format itself, A, one hull problem where
the judge corrected the book's own first derivation and the candidate
range, C, one problem zero teams solved whose constant-tail family
hides past the enumeration threshold, E, one constructive fix where
the official sketch admits no candidate at all on its own sample, D,
and the two interpreter walls of J carried over from 2022 beside K's
restructured wall that moved. Everything else is the standing lesson
again, the same derivation ports across six languages and the ports
agree because the suites pin the same fixtures everywhere.

sources: ICPC Foundation and icpc.global, the problemset at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf]
and the solutions at
#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/finals2023solutions.pdf")[finals2023solutions.pdf],
both accessed 2026-09-14 and cached under `ref/icpc/2023/` with
sha256 digests in `ref/icpc/INDEX.md`. The solutions pdf is the
algorithm and complexity reference for every section above, and its
page 1 statistics are the contest counts in the introduction. The
judge data, 1302 inputs across the 11 letters, sits local-only under
`ref/icpc/2023/data/`, and the official sample pairs reprinted in the
sections above are byte-for-byte its sample-N.in and sample-N.ans
files, attributed per section. The chapter's suites are
the frozen solver files: C runs 30 CHECK-family self-checks across
the 11 Ch12 programs, the C\# suite is 40 [Fact] tests including the
two post-fix sphinx traps, go pins the fixtures in 10 table-driven
test functions across its two ch12 test files, javascript runs 30 it
blocks carrying 31 assertions, python's 16 Ch12 files carry 81
`check(` occurrences, and lua reports 31 named checks through run.lua,
2 to 4 per file.
