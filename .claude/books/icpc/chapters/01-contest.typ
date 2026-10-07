// book 10, chapter 1: the contest, the content rules, and the chapter shape
// every later chapter follows. no listings here: this chapter reads the
// cached finals pdfs and defines the rules the sample suites obey
#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= the contest and the house rules

The International Collegiate Programming Contest, the ICPC, is a
worldwide contest for university students, run through regional
contests that feed a world finals. The finals is a five-hour
competition between teams of three, and this book works six of them,
2017, 2018, 2019, 2022, 2023, and 2025, 68 problems in all, in seven
languages built from first principles. The chapter you are reading
is the contract for how: the shape of a finals, the anatomy of one
problem, the content rules that govern everything this book says
about the problem sets, the chapter template every later chapter
follows, and the integer ground rules the seven languages bring with
them. The seven toolbox chapters behind this one, one per language,
are the shared substrate the finals chapters import and extend.

== what the contest is

A finals team is three students with one machine. For five hours the
team works the whole set at once, ten to thirteen problems, reading
them in any order and submitting source code that a judge compiles,
runs against hidden inputs, and verdicts. The verdict vocabulary is
short: accepted, wrong answer, time limit exceeded, run time error.
There is no partial credit and no score for style, the output has to
match what the judge expects, and each problem carries its own time
limit, a small number of seconds, so a program that is right but too
slow scores exactly like a program that is wrong.

The only progress signal on the contest floor is balloons. Each
problem has a color, and a balloon is delivered to a team when its
submission for that problem is accepted, so the whole room can read
who is ahead. Strategy lives under those balloons. Three people, one
keyboard, and a single clock mean the hardest skill is deciding what
to type next, who types it, and what the other two do while it is
being typed.

== the shape of a finals

The format holds constant across the six sets this book works. What
moves a little is the set itself. Four sets carry 11 problems and two
carry 12, 68 in all, and every problem in every set carries a letter.
Five sets letter from A through K or A through L. The 2022 set runs
P through Z, which is exactly how the ICPC Foundation published that
cycle, and this book keeps the letters as printed, so the 2022
chapter's problem sections run P to Z. The table lists the six finals
with their counts, their letters, and both pdfs the Foundation
publishes for each:

#table(
  columns: (auto, 1fr, 1.3fr, 1.3fr),
  inset: 4pt,
  table.header([*finals*], [*problems*], [*problemset pdf*], [*solutions pdf*]),
  [2017], [12, A through L], [#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/icpc2017.pdf")[icpc2017.pdf]], [#link("https://icpc.global/worldfinals/problems/2017-ICPC-World-Finals/finals2017solutions.pdf")[finals2017solutions.pdf]],
  [2018], [11, A through K], [#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/icpc2018.pdf")[icpc2018.pdf]], [#link("https://icpc.global/worldfinals/problems/2018-ICPC-World-Finals/finals2018solutions.pdf")[finals2018solutions.pdf]],
  [2019], [11, A through K], [#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/icpc2019.pdf")[icpc2019.pdf]], [#link("https://icpc.global/worldfinals/problems/2019-ICPC-World-Finals/finals2019solutions.pdf")[finals2019solutions.pdf]],
  [2022], [11, P through Z], [#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/icpc2022.pdf")[icpc2022.pdf]], [#link("https://icpc.global/worldfinals/problems/2022-ICPC-World-Finals/finals2022solutions.pdf")[finals2022solutions.pdf]],
  [2023], [11, A through K], [#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/icpc2023.pdf")[icpc2023.pdf]], [#link("https://icpc.global/worldfinals/problems/2023-ICPC-World-Finals/finals2023solutions.pdf")[finals2023solutions.pdf]],
  [2025], [12, A through L], [#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[problemset.pdf]], [#link("https://icpc.global/worldfinals/problems/2025-ICPC-World-Finals/2025-ICPC-Solutions.pdf")[2025-icpc-solutions.pdf]],
)

Both pdfs were accessed 2026-09-14 from icpc.global and
worldfinals.icpc.global, and both are cached under `ref/icpc/` with
sha256 digests and byte counts in `ref/icpc/INDEX.md`, so every
claim the finals chapters make is checked against a local copy of
the exact bytes. The problems pdf is the statement of record:
letter, title, story, input and output contracts, constraints,
samples, time limit. The solutions pdf is the Foundation's own
solution sketch set, one short editorial per problem from the
problem setters, and it is the algorithm reference for this book.

A set spreads wide. The 2017 sketch counts one problem accepted by
127 teams and one accepted by none. The 2025 sketch counts four
problems accepted by 135 teams or more and one accepted by none.
That spread is the design: the first hours belong to the problems
most of the room solves, the middle band separates the field, and
the last problems decide the title. Working every letter, the solved
ones and the unsolved ones, is what makes six sets fill six
chapters.

Ranking is arithmetic, and the arithmetic shapes the endgame. A team
is ranked by problems solved first, and ties break on total time:
for each solved problem, the minute the accepted submission landed
plus a penalty for every earlier wrong submission on that problem,
summed. A wrong submission on a problem the team never solves costs
nothing, which is why teams gamble on hard letters in the last hour,
and a wrong submission on a problem the team later solves is minutes
on the score for good.

#diagram([how the scoreboard sees one team: solve minutes on the clock plus a penalty block per wrong submission, summed over the solved problems], length: 12pt, {
  // clock axis, 0..300 minutes mapped onto 6.5..19.5
  let f(m) = 6.5 + m * 0.0433
  cdraw.line((6.5, 8.9), (19.5, 8.9), stroke: luma(100))
  for h in range(6) {
    let x = 6.5 + h * 2.6
    let lab = if h == 0 { [0] } else { [#h h] }
    cdraw.line((x, 8.75), (x, 9.05), stroke: luma(100))
    cdraw.content((x, 8.35), lab, size: 6pt)
  }
  // where the three accepted submissions landed
  for (l, m) in (([A], 142), ([D], 96), ([G], 210)) {
    cdraw.line((f(m), 8.9), (f(m), 9.3), stroke: luma(100))
    cdraw.content((f(m), 9.6), l, size: 6pt)
  }
  // one row per solved problem, clock bar plus penalty blocks
  let row(y, l, m, wrong) = {
    cdraw.content((6.3, y), [#l: #m min], size: 6pt, anchor: "east")
    cdraw.rect((6.5, y - 0.28), (f(m), y + 0.28), fill: luma(235), radius: 0.02)
    for i in range(wrong) {
      let x = f(m) + i * 0.5
      cdraw.rect((x, y - 0.28), (x + 0.4, y + 0.28), fill: luma(120), radius: 0.02)
    }
    cdraw.content((f(m) + wrong * 0.5 + 0.2, y), [#wrong wrong], size: 6pt, anchor: "west")
  }
  row(7.4, [A], 142, 3)
  row(6.25, [D], 96, 1)
  row(5.1, [G], 210, 2)
  // legend
  cdraw.rect((6.5, 4.25), (6.9, 4.65), fill: luma(235), radius: 0.02)
  cdraw.content((7.1, 4.45), [solve minutes], size: 6pt, anchor: "west")
  cdraw.rect((11.2, 4.25), (11.6, 4.65), fill: luma(120), radius: 0.02)
  cdraw.content((11.8, 4.45), [penalty per wrong try], size: 6pt, anchor: "west")
  cdraw.line((10.6, 3.95), (10.6, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.0, 2.1), (19.0, 3.3), fill: luma(245), radius: 0.02)
  cdraw.content((10.0, 2.7), [ranked by problems solved, ties broken by summed time], wrap: text.with(size: 6.5pt))
})

== the anatomy of a problem

Every problem in every set arrives in the same shape, and the shape
is a contract. A letter and a title identify the problem. A story
sets the scene, a paragraph or two of prose in the world of the
problem. The task states once, precisely, the quantity to compute.
The input section names every token the program will read and bounds
every value, the output section says exactly what to print, and one
or more sample pairs close the statement, small worked inputs with
their expected outputs. The time limit rides with the letter.

The bounds deserve their own sentence because they carry the
algorithmic content of the statement. A bound of a few hundred items
invites exhaustive search, a bound in the hundreds of thousands
invites something linear or near-linear in it, and the distance
between those two is the distance between accepted and time limit
exceeded. Reading the constraints before the story is the first
habit of a finals solver, and every walkthrough in this book states
the bounds it solved against.

#diagram([the anatomy every problem carries: letter and title, story, task, input with its bounds, output, samples, time limit], length: 12pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  box(1.0, 7.8, 18.4, [the letter, the title, the time limit])
  box(1.0, 5.8, 8.2, [the story, a page of scene setting])
  box(10.6, 5.8, 8.2, [the task, the quantity to compute])
  cdraw.line((5.1, 7.8), (5.1, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.7, 7.8), (14.7, 6.9), stroke: luma(100), mark: (end: ">"))
  box(1.0, 3.8, 8.2, [input: every token, every bound], fill: luma(245))
  box(10.6, 3.8, 8.2, [output: exactly what to print], fill: luma(245))
  cdraw.line((5.1, 5.8), (5.1, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.7, 5.8), (14.7, 4.9), stroke: luma(100), mark: (end: ">"))
  box(3.4, 1.8, 14.4, [samples, worked input and output pairs])
  cdraw.line((5.1, 3.8), (5.1, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.7, 3.8), (14.7, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.6, 0.6), [the bounds are the complexity contract], size: 6.5pt, fill: luma(100))
})

The samples are the one part of a statement a solver needs verbatim,
so this book carries them. Every problem section reprints at least
one official sample pair exactly as the Foundation printed it, and
the reprint is checked byte for byte against the cached judge data,
so the pair on the page is the pair the judge grades. The story
around it stays paraphrase, and the suites still pin crafted
fixtures of their own with hand-computed answers, because a fixture
whose answer is derived beside it is the teaching artifact. The
sample pair is the running target: feed it to any solver in this
book and the output matches the printed answer.

== what the problems ask for

Six sets, 68 problems, and the same families keep returning. Every
problem starts as input to parse, line lists, token rows, character
grids, blank-line groups, which is why every toolbox has an input
module that reads lines, a string module or byte-level idiom that
splits and trims, and grid modules that carry the r times cols plus
c index law with the 4- and 8-neighbor tables ready. Past the
parsing, counting problems want a dictionary and a set, search
problems want a heap and a deque, reachability wants walks and flood
fills, and the arithmetic problems want gcd and modular
exponentiation or a big integer that survives the count.

The sets also reach past the toolbox. World finals problems ask for
geometry, network flows, game trees, and reductions the shared
modules do not carry, and the house rule for those is year-local:
such helpers are built inside the year chapter with a one-line spec
in the year's suite. That boundary is deliberate. The toolbox holds
what all seven languages need across all six years, and everything
specific to one problem lives with that problem.

#diagram([the recurring problem families on the left, the toolbox that carries each on the right, year-local where no shared module exists], length: 12pt, {
  let row(y, shape, mod) = {
    cdraw.rect((0.6, y - 0.45), (9.0, y + 0.45), fill: luma(238), radius: 0.02)
    cdraw.content((4.8, y), shape, wrap: text.with(size: 6pt))
    cdraw.rect((12.0, y - 0.45), (19.4, y + 0.45), fill: luma(205), radius: 0.02)
    cdraw.content((15.7, y), mod, wrap: text.with(size: 6pt))
    cdraw.line((9.0, y), (12.0, y), stroke: luma(100), mark: (end: ">"))
  }
  row(8.6, [token lines, grids, grouped records], [io lines, split and trim, grid])
  row(7.45, [frequency counts, membership, dedup], [map or dictionary, set])
  row(6.3, [priority queues, best-first search], [heap])
  row(5.15, [frontier walks, sliding windows], [deque])
  row(4.0, [counts past 64 bits, wide products], [bigint, wrap-safe mulmod])
  row(2.85, [nested shapes, digests], [json decoder, md5])
  row(1.7, [geometry, flows, game trees], [year-local helpers, one-line spec])
  cdraw.content((4.8, 9.7), [what the problems keep asking for], size: 6.5pt, fill: luma(100))
  cdraw.content((15.7, 9.7), [what carries it], size: 6.5pt, fill: luma(100))
})

None of this solves a problem. Knowing a problem wants a heap does
not say what the heap should order by, and the hard third of a
finals set is hard in the model or the proof first. What the toolbox
removes is everything around the problem: parsing that works,
containers already tested, arithmetic that cannot wrap. The finals
chapters spend their length on the problem and import the rest.

== the content policy

The problems are not this book's to copy. The rulebook the whole
book is written under states the policy, and it is restated here
because every chapter that mentions a problem is bound by it:

#callout("pitfall", "the house rules", [
  Statements are retold in this book's own words and linked to the
  year's problemset pdf at icpc.global, and the retelling is
  complete: task, input and output contracts, every bound, the time
  limit, and at least one official sample pair reprinted exactly.
  The story prose is never copied. The problemset and solutions
  pdfs are cached under ref/icpc for private reference, sha256
  digests in ref/icpc/INDEX.md. Judge data under
  ref/icpc/<year>/data/ is local only and never committed: its
  sample files are the byte-exact source for the sample pairs this
  book prints, and its secret inputs are never quoted. Sources rows
  attribute the ICPC Foundation and icpc.global with access dates.
  The official solutions pdf is the algorithm reference for every
  method and complexity claim, and it is cited where used. The 2025
  set postdates training data, so everything this book says about it
  derives strictly from the cached pdfs.
])

Each clause has a mechanical consequence in this book, and it is
enforced by two gates: every suite pins its solver to crafted
fixtures with hand-computed answers, and the committed
`ref/icpc/verify-data.ps1` maps every problem letter to its input
and answer pairs under the local judge data in
`ref/icpc/<year>/data/`, runs the solvers against them, and reports
counts.

== the problem-chapter template

Every finals chapter follows the same shape, so a reader who has
seen one can navigate all of them. One section per problem, in the
letter order of the set, P through Z in the 2022 chapter exactly as
the pdf prints them. A section opens with the task in this book's
own words and the links, then states the input and output contracts:
every token the program reads, every bound on every value, the time
limit. An official sample pair follows, reprinted exactly and
attributed. Before the derivation comes recognition: the bounds read
as a complexity budget, the statement's shape names the structure,
the family names the siblings in other years, and the rejected
alternatives are priced out. The derivation comes next, the method
built up with the solutions sketch cited. The model is then traced
by hand on the official sample before any code is printed, as a
figure when the run is visual and a numbered state table when it is
tabular, ending at the byte-exact printed answer. After the trace
the solver walks in seven listings, one per language, in the fixed
order c, go, java, c\#, javascript, python, lua. That order is book
9's order with java slotted after go, the data structures book this
series pairs with, and keeping
it means a reader moving between the two books always knows where a
language's version of a structure lives. A helper section opens the
chapter when year-local kits exist, and every file a printed solver
imports is itself printed there, so the reader never leaves the book
to follow an import. Each problem section carries its worked run as
a figure or state table before the listings and one diagram of the
method after them. Every walkthrough pins its answer: the official
sample above and the crafted fixture beside it, the hand-computed
expectation derived in the prose, and the suite assertion that ties
them. A closing section compares the seven languages on that set, and
a sources paragraph carries the attribution, the urls, the access
date, the solutions cite, and the suite counts.

#diagram([the problem-chapter template: the task in our words, the contracts and bounds, an official sample pair, recognition, the worked run, seven listings in the fixed order, pinned answers, the closing table], length: 12pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 9.6, 9.2, [the task, in our words])
  box(10.4, 9.6, 6.8, [both pdfs linked])
  cdraw.content((18.0, 10.1), [our words, cited], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.line((5.2, 9.6), (5.2, 8.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.8, 9.6), (13.8, 8.8), stroke: luma(100), mark: (end: ">"))
  box(0.6, 7.8, 10.4, [input, output, every bound, the time limit], fill: luma(245))
  box(11.6, 7.8, 10.6, [an official sample pair, byte-exact], fill: luma(245))
  cdraw.line((5.8, 7.8), (5.8, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.9, 7.8), (16.9, 7.0), stroke: luma(100), mark: (end: ">"))
  box(0.6, 6.0, 10.4, [the bounds, the complexity budget], fill: luma(245))
  box(11.6, 6.0, 10.6, [the family, the siblings, the priced-out rejects], fill: luma(245))
  cdraw.line((5.8, 6.0), (5.8, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.9, 6.0), (16.9, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 4.2), (22.2, 5.2), fill: luma(238), radius: 0.02)
  cdraw.content((11.4, 4.7), [the model traced on sample 1, figure or state table, ending byte-exact], wrap: text.with(size: 6.5pt))
  cdraw.line((11.4, 4.2), (11.4, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 2.4), (22.2, 3.4), fill: luma(238), radius: 0.02)
  cdraw.content((11.4, 2.9), [seven listings in the fixed order: c, go, java, c\#, javascript, python, lua], wrap: text.with(size: 6.5pt))
  box(0.6, 1.3, 8.2, [the method diagram, after the listings])
  box(9.3, 1.3, 6.2, [spec fixture, pinned answer])
  box(16.0, 1.3, 6.2, [closing table, seven languages])
  cdraw.content((11.4, 0.3), [sample pairs print the public judge samples, secrets stay local], size: 6.5pt, fill: luma(100))
})

The fixed order is also a promise about interchangeability. The seven
languages do not solve each problem identically, integer semantics
differ, container choices differ, and the walkthroughs say so out
loud. When a cross-language anchor exists, the same hand-computed
value must come out everywhere: 2^100 mod 1e9+7 landing at 976371285,
the 92 eight-queens solutions, the failure table of ababa. When
fixtures differ between languages, the walkthrough cites its own
fixture's answer and the prose never claims the outputs match. That
honesty rule holds for the toolbox chapters too.

Behind every chapter stands the judge harness, run locally. It pipes
each official input to the solver and diffs the official answer, and
the chapter reports those runs as counts. The sample inputs and
answers are public statement data and this book prints them, checked
byte for byte against the cache; the secret inputs and answers stay
on the machine, so the judge data stays a private second gate.

== the seven languages and their integers

The seven languages were not chosen for this book. They are the
series: six language manuals and C, the same seven that book 9
rebuilt every data structure in, in the same order. What differs
between them, and what every toolbox chapter has to say out loud,
is what happens when a product outgrows the machine word, and a
finals set asks for that often enough: combinatorial counts past 64
bits, coordinate arithmetic that overflows mid-computation, answers
with dozens of digits. The rules below are binding for the whole
book and each toolbox chapter repeats the ones it lives under.

#table(
  columns: (auto, 1fr, 1.6fr, 1.6fr),
  inset: 4pt,
  table.header([*language*], [*machine word*], [*big integers*], [*wrap-safe product*]),
  [c], [`unsigned long long`], [toolbox bigint, 12 limbs of 9 digits], [add-and-double with a remainder every step],
  [go], [`uint64` / `int64`], [`math/big` where needed], [`math/bits.Mul64` for the wide product],
  [java], [`long`], [`BigInteger` at the c `__int128` sites], [`Math.multiplyHigh` plus the shift-subtract lane],
  [c\#], [`long`], [`System.Numerics.BigInteger`], [checked 64-bit, checked bigint],
  [javascript], [`Number`], [`BigInt` past the safe 53-bit range], [`BigInt` at the boundary, stated in a comment],
  [python], [native `int`], [unbounded, no ceremony], [native],
  [lua], [int64, wraps silently], [toolbox bigint over tables], [doubling mulmod, boundary test pinned],
)

Two of those rows carry a story this book tells in full later. C's
`__uint128_t` multiplies fine under clang 23 on this machine, but the
link then fails for want of `__umodti3`, the runtime helper for a
128-bit remainder, so the C toolbox and every C modular routine use
add-and-double instead, and #xref-to("icpc", "toolbox-c") shows the
whole decision. Lua's integers wrap without a sound, and the Lua
toolbox pins the proof in a test, `math.maxinteger * 2 == -2`, then
builds its mulmod on doubling so no wrap can happen, and
#xref-to("icpc", "toolbox-lua") walks it. Python, C\#, and Java sit at the
other pole, where big integers are native and the chapter's job is to
show what the machine is doing for you. The row for javascript is the
one that bites contest solvers most often, because `Number`
arithmetic that is fine in the small example loses precision on the
judge input's magnitudes with no error raised, so the boundary is
stated in a comment at every place a toolbox crosses it.

== the toolbox layer

The seven chapters between this one and the finals chapters are
toolboxes, one per language: #xref-to("icpc", "toolbox-c"),
#xref-to("icpc", "toolbox-go"), #xref-to("icpc", "toolbox-java"),
#xref-to("icpc", "toolbox-cs"), #xref-to("icpc", "toolbox-js"),
#xref-to("icpc", "toolbox-py"),
and #xref-to("icpc", "toolbox-lua"). Each is a small from-scratch
library covering what the problem sets keep asking for: big integers
beyond the machine word, a string-to-value dictionary and a set, a
binary min-heap, a deque, grid index math with neighbor tables,
input reading, modular arithmetic with a multiplication that cannot
wrap, md5 from the RFC, and a json decoder. The finals chapters
import and extend these. They never re-derive a container inline,
because a chapter about a hard search problem should spend its
length on the search, and because a container built once and tested
once beats seven private re-derivations with seven private bugs.

The measured size of the layer is part of the story. The C toolbox is
11 header files, 1125 lines, in `books/icpc/samples-c/src/Ch02/`,
tested by 10 programs with 251 internal checks. The Lua toolbox is 9
modules, 1088 lines, in `books/icpc/samples-lua/`, with 45 checks
through its runner. The other five languages carry their own chapters
and their own counts. Those numbers are counted from the tree, not
estimated, raw line totals for C and Lua and non-blank lines for the
other five, and the chapter that owns each suite restates its own.

#diagram([the layering: finals chapters import the toolbox of their language, never re-derive containers], length: 12pt, {
  let cell(x, w, y, t, fill: luma(205)) = {
    cdraw.rect((x, y), (x + w, y + 0.8), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.4), t, size: 6pt)
  }
  // the six finals chapters across one row
  for (i, yr) in ((0, [2017]), (1, [2018]), (2, [2019]), (3, [2022]),
                  (4, [2023]), (5, [2025])) {
    cell(0.8 + i * 3.35, 2.9, 6.4, yr, fill: luma(225))
  }
  cdraw.content((10.6, 7.7), [the six finals chapters, 9 through 14], size: 6.5pt, fill: luma(100))
  for (i, l) in ([c], [go], [java], [c\#], [js], [py], [lua]).enumerate() {
    cell(0.8 + i * 2.95, 2.55, 2.6, l)
  }
  cdraw.content((10.6, 1.5), [the seven toolboxes, chapters 2-8], size: 6.5pt, fill: luma(100))
  cdraw.line((10.6, 6.4), (10.6, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 4.3), [import and extend], size: 6.5pt, fill: luma(100), anchor: "west")
})

The test discipline is the same across all seven, and it is the same
discipline book 9's suites run under. Tests are table-driven over
crafted fixtures with hand-computed answers. No network, no clock,
no randomness unless it is seeded deterministically. Brute-force
cross-checks are welcome and counted, because a clever method that
agrees with a naive one on a small fixture is worth more than either
alone. Every language's suite prints or asserts so its gate can
count: the C gate compiles every module under `-Werror` and counts
one ok line per program, the Lua runner counts checks per module,
and the managed-language suites run their native test frameworks. The
footer of every toolbox chapter states its own verified counts.

Crafted fixtures with hand-computed answers are the committed gate,
and the judge data is the second one, run locally forever, not just
for the toolboxes but for every finals chapter that follows. The
policy above is the reason, and the practice also keeps the suites
fast, deterministic, and offline. When a walkthrough needs a wide
product or a large count to make its point, it builds a fixture whose
answer is derived in the prose beside it, and the reader can check
the arithmetic by hand.

sources: ICPC Foundation, icpc.global and worldfinals.icpc.global,
the six problemset and solutions pdfs linked in the table above,
accessed 2026-09-14 and cached under `ref/icpc/` with sha256 digests
in `ref/icpc/INDEX.md`. The solution sketches settle the algorithm
and complexity claims made here, and the 2025 set postdates training
data, so everything said about it derives from the cached pdfs. This
chapter has no sample suite. The suites begin with chapter 2, whose
gate line is 10 files and 251 internal checks, and chapter 8, whose
runner reports 45 checks across 9 modules.
