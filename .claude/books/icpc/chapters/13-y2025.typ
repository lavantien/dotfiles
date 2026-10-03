// book 9, chapter 13: the 2025 world finals. twelve problems, a
// through l, six languages each, listings sliced from the landed files
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= icpc world finals 2025

The 49th ICPC World Championship ran in Baku in 2025 with twelve
problems, A through L, published as #link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[problemset.pdf].
St Petersburg State University took the title. The set has a judge
killer in C, which no team solved, and an implementation marathon in G,
which fell to two teams at 270 minutes, while L opened the scoreboard
at 6 minutes, D and L each going to 138 teams. Every walkthrough
in this chapter takes its algorithm and complexity from the official
#link("https://icpc.global/worldfinals/problems/2025-ICPC-World-Finals/2025-ICPC-Solutions.pdf")[solutions
sketch], cited per problem, and the fixtures are crafted minis with
hand-derived answers, a few retracing configurations from the public
samples. Two structural exceptions shape the set for
this book: B is output-validating with no judge answers at all, judged
through a validity checker over the matching criterion, and I is
interactive with no answers to diff, judged through a driver that
speaks the protocol against each language's solver core, both beside
the self-check simulators the walkthroughs name where they occur.

== the year-local helpers: kuhn matchings, the rollback sweep engine, slot wheels, and the go scan cursor

Four helper kits are year-local to this chapter, the match, moat, and
wheels engines plus the go package's shared scan cursor, and
everything else the year's solvers import comes from the wave 1
toolbox chapters 2 through 7. The C solvers parse through chapter
11's `ch11_scan.h` beside the chapter 2 io header rather than a
year-local twin, so both print in their own chapters and only go
adds a file for parsing here. Each kit states its contract and
prints its twin files below in the book's fixed language order, and
C\# inlines the match and wheels kits inside its problem B and I
solvers, so its one twin file is the moat engine's Moat.cs.

The match kit backs problem B with Kuhn's augmenting-path bipartite
matching over a caller-built edge list, the parity-of-omega graphs
never exceeding 200 plus 200 nodes below the Bertrand cutover. C
keeps 1-based edge arrays inside `Ch13/ch13_match.h`, go's
`match13` carries the same arrays as slices, javascript's `Match`
class stamps `seen` over Int32Arrays, python's `Match` class walks
plain lists under a raised recursion limit, and lua's `match.kuhn`
takes adjacency lists with 0 the unmatched sentinel. C\# inlines
the whole augment inside its problem B solver:

#listing("icpc/samples-c/src/Ch13/ch13_match.h", first: 41, last: 65, caption: [c, match\_try augments over the 1-based edge list, match\_run stamping seen once per left vertex and returning the size])

#listing("icpc/samples-go/ch13/match.go", first: 31, last: 56, caption: [go, the same try recursion over slice edge lists, run stamping seen per left vertex, 0 sentinel unmatched])

#listing("icpc/samples-js/src/ch13-match.mjs", first: 23, last: 45, caption: [javascript, the Match class, try over Int32Array seen stamps, run refilling matchr and driving every left vertex])

#listing("icpc/samples-py/src/Ch13/ch13_match.py", first: 23, last: 42, caption: [python, the Match class over plain lists, \_try walking nxt with 1-based edge indices, run returning the size])

#listing("icpc/samples-lua/ch13_match.lua", first: 1, last: 30, caption: [lua, match.kuhn whole, the nested augment closure resetting seen per left vertex])

The moat kit backs problem G and is the year's largest contract,
the offline dynamic connectivity sweep: per-triangle cut segments
with linear lengths, lifetimes hung on a segment tree over level
intervals, and a rollback dsu whose components carry the summed
length a + b*h plus west and east border flags, an intrusive list
exposing both-border components, every payload change logged for
undo. C splits the contract in two, the engine's static arrays in
`Ch13/ch13_moat.h` over the inline dsu of `Ch13/ch13_rollback.h`,
go rolls both into the `moat13` struct's slices, javascript's
module-static typed arrays inline the dsu inside `ch13-moat.mjs`,
python's `ch13_rollback.py` holds the whole `Moat` class despite
the name, lua mirrors the c split with `ch13_moat.lua` requiring
`ch13_rollback.lua`, and C\#'s static `Moat.cs` is the language's
one twin file:

#listing("icpc/samples-c/src/Ch13/ch13_moat.h", first: 106, last: 149, caption: [c, ch13\_add\_seg merging child payload, cut length, and border flags into the parent with the list moves logged, ch13\_undo\_unions unwinding both, ch13\_reset\_dsu seeding singletons])

#listing("icpc/samples-c/src/Ch13/ch13_rollback.h", first: 9, last: 42, caption: [c, the dsu half, size-indexed unite logging each child, parent pair with -1 sentinels, undo popping exactly one pair])

#listing("icpc/samples/src/Ch13/Moat.cs", first: 143, last: 180, caption: [c\#, AddSeg with the unite, payload stash, and both-border list splice inlined, lifo against Rblog and Ppay])

#listing("icpc/samples-go/ch13/moat.go", first: 155, last: 191, caption: [go, addSeg saving the parent payload before the merge, undoUnions restoring it beside each logged union])

#listing("icpc/samples-js/src/ch13-moat.mjs", first: 100, last: 142, caption: [javascript, addSeg over module-static typed arrays with the unite inlined, undoUnions unwinding payloads and roots in lockstep])

#listing("icpc/samples-py/src/Ch13/ch13_rollback.py", first: 112, last: 141, caption: [python, the Moat class, add\_seg stashing the parent payload, undo\_unions restoring it beside each logged union])

#listing("icpc/samples-lua/ch13_moat.lua", first: 114, last: 151, caption: [lua, moat.add\_seg through the rollback module's unite, moat.undo\_unions restoring payloads and roots in lifo order])

#listing("icpc/samples-lua/ch13_rollback.lua", first: 1, last: 45, caption: [lua, rb.find, rb.unite pushing child and parent onto the log, rb.undo popping one pair])

The wheels kit backs problem I with the slot-machine friend: n
wheels over one shared cyclic symbol order, `init` normalizing
positions mod n, `rotate` adding an offset mod n and counting
queries, and `k` answering the count of distinct visible symbols,
the judge's only feedback. C's `Ch13/ch13_wheels.h`, go's
`wheels13`, javascript's `Wheels` class, python's `Wheels` class,
and lua's `wheels` module all print whole, and C\# inlines the
simulator as the sealed class its problem I section already shows:

#listing("icpc/samples-c/src/Ch13/ch13_wheels.h", first: 8, last: 38, caption: [c, the Ch13Wheels friend, init normalizing positions mod n, k counting distinct symbols, rotate answering through k])

#listing("icpc/samples-go/ch13/wheels.go", first: 13, last: 39, caption: [go, wheels13, newWheels13 normalizing, k over a fresh seen slice, rotate answering through k])

#listing("icpc/samples-js/src/ch13-wheels.mjs", first: 5, last: 31, caption: [javascript, the Wheels class, k over a Uint8Array of seen symbols, rotate adding j mod n])

#listing("icpc/samples-py/src/Ch13/ch13_wheels.py", first: 7, last: 23, caption: [python, the Wheels class, k as a set of normalized symbols, rotate returning the new count])

#listing("icpc/samples-lua/ch13_wheels.lua", first: 7, last: 33, caption: [lua, wheels.init, wheels.k, wheels.rotate, 1-based positions held mod n])

The scan kit is the go package's io contract, one file the whole
year shares: `scan13` walks the input buffer with a whitespace
`token`, a signed `nextInt`, its 64-bit twin `nextInt64`, and
`line` for the fixed-line judge files, the same cursor design
chapter 12 printed as scan12. All twelve go solvers parse through
it:

#listing("icpc/samples-go/ch13/ch13.go", first: 5, last: 42, caption: [go, scan13: token skips whitespace over the shared buffer, nextInt folds a signed value, nextInt64 the same in 64 bits])

== problem a, a-skew-ed reasoning

A skew heap is a mergeable heap that grows by insertion, and this task
runs its construction backwards. The heap starts empty and a
permutation of 1..n is fed in one value at a time. Inserting x into a
heap rooted at y swaps the root's children and descends left when
y < x, and makes x the new root with the old heap
as its left child when y > x. The input then hands over a binary tree
on the values 1..n, described as children lists rather than as a
permutation, and the task is to name the lexicographically minimal and
the lexicographically maximal insertion permutations that produce
exactly that tree, or declare it impossible.

The input is one integer n, then n lines of two integers each, the left
and right child of node i, 0 meaning no child, with every child index
either 0 or a node numbered above i so the lists always describe a
binary tree. The problemset pdf bounds n at 2e5 with the values 1..n
used exactly once, under a 2 second limit, and the judge data carries
52 cases for the letter, 3 samples and 49 secrets. The output is two
lines of n space-separated integers, minimal first then maximal, or the
single word impossible.

Official sample 1, reprinted byte for byte from the judge data pair
`A-askewedreasoning/sample-1.in` and `sample-1.ans`: the tree gives
node 1 the children 2 and 3 and gives both of them two leaf children, a
full binary tree of depth two, and the two extremes split on where the
root value 1 sits, first position for the minimum and second for the
maximum:

input:

```
7
2 3
4 5
6 7
0 0
0 0
0 0
0 0
```

expected output:

```
1 3 2 7 5 6 4
7 1 5 3 2 6 4
```

Official sample 2, same source: a two-node tree whose root owns only a
right child, and since a fresh root always takes the old heap on its
left, no permutation builds it.

input:

```
2
0 2
0 0
```

expected output:

```
impossible
```

Recognition: n at 2e5 under the 2 second limit buys about 1e8 cheap operations, and the reconstruction needs only n log n of them, each node's interleave touching nothing but the shorter side, about 3.6e6 element moves for the whole build.

The statement prints the growth rule in full, inserting x swaps the root's children and descends left when y < x and re-roots when y > x, then hands over the finished tree and asks for the lexicographically minimal and the maximal permutation building exactly it: a deterministic forward process identified by its final state, the shape to run backwards. Problem A is the 2025 face of the inverting a deterministic process family. Chapter 08 problem G is the other half of the inverting a deterministic process pair.

Searching forward is the priced-out alternative: the candidate permutations run to (2e5)!, and even a backward splice that walks the long side at every node costs (2e5)^2 = 4e10 moves against the limit, four orders past it.

The reconstruction recurses from the root. The root value 1 lands at
some input position q, the prefix before it builds one side's base
heap, and because every later insertion swaps the root's children
before descending left, the post-1 suffix alternates between the sides
at the rate of one element each, the parity of its length fixing which
child ends up left and the pre-1 prefix having built the even-offset
side's base. The two subtree sizes pin q to at most two candidates,
q = size - 2*ls + 1 when the odd-offset side is the left child of size
ls, and q = size - 2*rs otherwise, two candidates only when they land
on the first two positions of the node's span, and min takes the
smaller feasible q at every node while max takes the larger
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 1). Combining a node with its two built sides is an
interleave of the shorter sequence into an equal-length suffix of the
longer one, the mergesort merge, so the whole build runs in O(n log n),
the small side's cost charged each time an element lands there.

The worked run: trace the model on sample 1. The input's tree gives node 1 the children 2 and 3 and both of them two leaf children, so the span is 7 over two subtrees of size 3, and the root candidates are q = 7 - 2 × 3 + 1 = 2 and q = 7 - 2 × 3 = 1, the span's first two positions, min taking 1 and max taking 2. Min, the line 1 3 2 7 5 6 4: the empty prefix leaves both bases empty, the suffix 3, 2, 7, 5, 6, 4 alternates one element per side, dealing 3, 7, and 6 to node 3 and 2, 5, and 4 to node 2, and the leaf recursion below each repeats the split, node 3's triple 3, 7, 6 taking q = 1 so 7 then 6 alternate onto its leaves as 6 left and 7 right, node 2's triple 2, 5, 4 settling 4 left and 5 right, both exactly the input's children lists. Max, the line 7 1 5 3 2 6 4: q = 2, the one-element prefix 7 pre-building node 3's base, the suffix 5, 3, 2, 6, 4 dealing 3 and 6 to node 3 beside that base and 5, 2, and 4 to node 2, and the same leaf recursions end at node 3 with children 6 and 7, the base 7 nested right, and node 2 with children 4 and 5, the input's tree again, and the trace ends at the printed answer `7 1 5 3 2 6 4`.

#diagram([the sample-1 tree, node 1 owning 2 and 3 over four leaves, with the min line's root-first split and the max line's one-element prefix annotated], length: 12pt, {
  cdraw.circle((5.2, 8.6), radius: 0.42, fill: luma(235))
  cdraw.content((5.2, 8.6), [1], size: 7pt)
  cdraw.circle((2.4, 6.4), radius: 0.42, fill: luma(245))
  cdraw.content((2.4, 6.4), [2], size: 7pt)
  cdraw.circle((8.0, 6.4), radius: 0.42, fill: luma(245))
  cdraw.content((8.0, 6.4), [3], size: 7pt)
  for x in (1.0, 3.8, 6.6, 9.4) {
    cdraw.circle((x, 4.2), radius: 0.42, fill: luma(250))
  }
  cdraw.content((1.0, 4.2), [4], size: 7pt)
  cdraw.content((3.8, 4.2), [5], size: 7pt)
  cdraw.content((6.6, 4.2), [6], size: 7pt)
  cdraw.content((9.4, 4.2), [7], size: 7pt)
  cdraw.line((4.9, 8.3), (2.7, 6.7), stroke: 0.8pt + luma(60))
  cdraw.line((5.5, 8.3), (7.7, 6.7), stroke: 0.8pt + luma(60))
  cdraw.line((2.1, 6.1), (1.3, 4.6), stroke: 0.8pt + luma(60))
  cdraw.line((2.7, 6.1), (3.5, 4.6), stroke: 0.8pt + luma(60))
  cdraw.line((7.7, 6.1), (6.9, 4.6), stroke: 0.8pt + luma(60))
  cdraw.line((8.3, 6.1), (9.1, 4.6), stroke: 0.8pt + luma(60))
  cdraw.content((2.4, 7.6), [2, 5, 4 dealt here], size: 6pt, fill: luma(120))
  cdraw.content((8.0, 7.6), [3, 7, 6 dealt here], size: 6pt, fill: luma(120))
  cdraw.content((5.2, 9.5), [min: q = 1, the suffix alternating below 1], size: 6.5pt, fill: luma(100))
  cdraw.content((5.2, 2.9), [max: q = 2, the prefix 7 pre-building node 3's base], size: 6.5pt, fill: luma(100))
})

#listing("icpc/samples-c/src/Ch13/pA.c", first: 74, last: 115, caption: [c, build in two passes, parity forcing the odd-offset side, then one in-place shuffle per node through a shared temp])

The c family writes each node's even side at the head of its output
buffer and its odd side right after it, so the alternation is one
memcpy pair plus a parity-indexed shuffle, and the reverse preorder
makes children settle before the parent splices itself in. The c\# port
is the same algorithm over Array.Copy:

#listing("icpc/samples/src/Ch13/PA.cs", first: 97, last: 144, caption: [c\#, the same build, Array.Copy standing in for memcpy, min and max one bool apart])

The go, javascript, and python engines splice linked lists instead.
Each node walks its base child's list to position q-1 from the nearer
end, so the walk costs at most the fresh side's length, and that
from-the-nearer-end rule is the small-into-large bound made visible:

#listing("icpc/samples-go/ch13/pa.go", first: 72, last: 116, caption: [go, both q candidates scored, min or max picked, then the base walk started from whichever end is closer])

#listing("icpc/samples-js/src/ch13-pa-askewedreasoning.mjs", first: 80, last: 125, caption: [javascript, the splice itself, root appended after the base prefix, fresh and base-suffix nodes alternating onto one prev pointer])

#listing("icpc/samples-py/src/Ch13/pa.py", first: 76, last: 116, caption: [python, the same splice with the alternation collected into one out list, then rewired in a single zip pass])

Lua rejoins the c family, buffer and shuffle, with floor division
where c shifts:

#listing("icpc/samples-lua/ch13_pa.lua", first: 67, last: 112, caption: [lua, pick_q over the two candidates, then the placement pass stamping each node's offset before the reverse shuffle])

The crafted fixture is the four-node tree 1(L:3, R:2(L:4)). The side
sizes force q = 3, the prefix {2,4} builds 2(L:4) in either order, and
the single suffix element 3 swings into the left child after the root
swap, so the answer is "2 4 1 3" then "4 2 1 3". Every suite pins that
pair: c, javascript, python, and lua carry the two-fixture plan with
the single-node tree min = max = 1 as the extra, while c\# adds the
impossible lone right child, whose fresh root would always take the old
heap on the left, and go adds a three-node left comb plus an
exhaustive sweep that brute-forces every permutation for n up to 6 and
checks the solver against the min and max it produces. Per language
this section pins 2 checks in c, 3 facts
in c\#, 3 table cases plus the sweep in go, 2 assertions in javascript,
2 checks in python, and 2 named checks in lua.

#diagram([the crafted fixture: the prefix 2, 4 builds the right chain, the root 1 lands third, and the suffix 3 swings into the left child after the child swap], length: 12pt, {
  cdraw.circle((2.2, 5.6), radius: 0.42, fill: luma(235))
  cdraw.content((2.2, 5.6), [1], size: 7pt)
  cdraw.circle((0.8, 4.0), radius: 0.42, fill: luma(245))
  cdraw.content((0.8, 4.0), [3], size: 7pt)
  cdraw.circle((3.6, 4.0), radius: 0.42, fill: luma(245))
  cdraw.content((3.6, 4.0), [2], size: 7pt)
  cdraw.circle((5.0, 2.6), radius: 0.42, fill: luma(245))
  cdraw.content((5.0, 2.6), [4], size: 7pt)
  cdraw.line((2.2, 5.2), (0.8, 4.4), stroke: 0.8pt + luma(60))
  cdraw.line((2.2, 5.2), (3.6, 4.4), stroke: 0.8pt + luma(60))
  cdraw.line((3.6, 3.6), (5.0, 3.0), stroke: 0.8pt + luma(60))
  cdraw.content((1.0, 4.9), [odd side], size: 6pt, fill: luma(120))
  cdraw.content((4.6, 4.9), [even side, built by the 2 4 prefix], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.content((6.1, 1.4), [2 4 1 3: min, and 4 2 1 3: max], size: 6.5pt, fill: luma(100))
  cdraw.line((5.0, 2.2), (5.9, 1.6), stroke: luma(120), mark: (end: ">"))
})

Integers stay small here, indices up to 2e5 in int32 with plain prints,
and the output is two lines of n numbers, so no language needs anything
beyond its default integer.

== problem b, blackboard game

Numbers 1 through n are written on a blackboard and two players share
one circle. The first player circles any even number, and every later
move must jump the circle from its current number to a never-circled
number that is the current number times a prime or divided by a prime.
The player unable to move loses. Per n the output names the winner:
"second" outright, or "first" together with any even opening move that
belongs to a winning strategy.

The input is one integer t, then t lines each holding one n. The
problemset pdf bounds t at 40, n between 2 and 1e7, and the sum of n
across the tests at 1e7, under a 1 second limit. The judge data
carries 118 cases for the letter, 2 samples and 116 secrets. The
output is one line per test, "second", or "first k" with k even, and
every valid winning k scores alike.

The sample pair cannot be reprinted the usual way, because this is the
set's first structural exception: the judge directory holds the two
sample inputs, n = 5 alone and n = 12 beside n = 17, and not one .ans
file across the letter's 118 cases, so the chapter asserts the
emptiness rather than quoting a pair. Any valid winning opening
scores under the official judge, so the letter judges through
`checker:2025-b` instead of a byte diff: below a boundary of 2'000 the
checker recomputes the criterion exactly, one hopcroft-karp maximum
matching plus alternating reachability out of the exposed vertices,
and above it the pdf's certified opening decides, first 2p with p a
prime above n/4 and at most n/3. Only the exact tier accepts an
arbitrary winning opening, the certified tier validating family
openings with every accepted opening genuinely winning, and the six
solvers emit family openings above their own cutoff, so the lanes
judge their own outputs.

Recognition: t at 40 with the sum of n capped at 1e7 against the 1 second limit leaves no room for per-n work above the engine's cutoff, and below it the retry machine stays small: n = 200 builds about 370 prime-multiple edges, one kuhn pass costs on the order of 200 × 370 ≈ 7e4 augment steps, and the at most 100 even deletions keep a whole verdict under 1e7 steps.

The cue sits in the win condition, any even opening move that belongs to a winning strategy: an opening wins exactly when every opponent reply can be met with a matched partner forever, a matching-avoidance question on the prime-multiple graph. Problem B is the 2025 face of the bipartite assignment feasibility family. The bipartite assignment feasibility family collects chapter 08 problem C, chapter 11 problem X, and chapter 13 problem F. A secondary thread, semiprime certificate for large n, covers the primality test the opening move reduces to.

Game-tree search on the move graph is the priced-out alternative, 2^(1e7) positions at the cap, and even memoized retrograde analysis must hold the whole graph in memory where one maximum matching per deletion answers outright.

Build the undirected graph on 1..n joining x to x*p for primes p. An
even k is a winning opening exactly when some maximum matching of that
graph avoids k, because the first player then answers every opponent
move with the matched partner forever and the opponent can never reach
an unmatched vertex without exhibiting an augmenting path, while if
every maximum matching uses all even numbers the second player mirrors.
Small n runs kuhn over the parity-of-omega bipartition trying each
even deletion, the graph being bipartite because every edge changes
the count of prime factors by exactly one. Past the cutoff the answer
is always "first 2p": the solutions pdf proves first wins for every n
above 176, generalized Bertrand supplies distinct primes p, q, and r
above n/4 and at most n/3, opening 2p leaves the six semiprimes 2p,
3p, 2q, 3q, 2r, and 3r matching perfectly onto 2, 3, p, q, and r, and
the book cuts over at n = 200, the pdf noting any cutoff between about
200 and 1e5 serves
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf pp. 2-3). Book 8's chapter 38, network flows ii, builds
kuhn's augmenting-path matching that the small-n engine runs here.
Book 8's chapter 40, game theory and scheduling, collects the
games-on-graphs strategy arguments the matching criterion
instantiates. Book 8's chapter 28, advanced number theory, carries the
primality testing behind the Bertrand prime hunt, and the c engine
opens the walkthrough.

The worked run: trace the model on sample 1, whose judge directory prints no answers at all because any valid winning opening scores alike, so the trace targets the verdict the matching criterion pins. Sample 1 is n = 5: the graph joins 1 to 2, 3, and 5, and 2 to 4, the parity-of-omega sides {1, 4} against {2, 3, 5}, and the full graph matches at size 2, 1-3 beside 4-2. Deleting k = 2 strands 4, whose only edge dies with it, size 1, and deleting k = 4 leaves the three edges of 1 alone, size 1 again, so both even numbers sit inside every maximum matching, the second player mirrors forever, and the verdict is second.

#diagram([the n = 5 prime-multiple graph, the size-2 matching bolded, both even numbers 2 and 4 covered by every maximum matching], length: 12pt, {
  cdraw.circle((1.6, 6.4), radius: 0.36, fill: luma(245))
  cdraw.content((1.6, 6.4), [1], size: 6.5pt)
  cdraw.circle((4.6, 7.6), radius: 0.36, fill: luma(245))
  cdraw.content((4.6, 7.6), [2], size: 6.5pt)
  cdraw.circle((8.0, 6.4), radius: 0.36, fill: luma(245))
  cdraw.content((8.0, 6.4), [3], size: 6.5pt)
  cdraw.circle((4.6, 2.6), radius: 0.36, fill: luma(245))
  cdraw.content((4.6, 2.6), [4], size: 6.5pt)
  cdraw.circle((1.6, 3.4), radius: 0.36, fill: luma(245))
  cdraw.content((1.6, 3.4), [5], size: 6.5pt)
  cdraw.line((1.9, 6.5), (4.3, 7.5), stroke: 0.5pt + luma(170))
  cdraw.line((1.9, 6.3), (1.8, 3.8), stroke: 0.5pt + luma(170))
  cdraw.line((1.9, 6.4), (7.7, 6.4), stroke: 2.2pt + luma(60))
  cdraw.line((4.6, 7.2), (4.6, 3.0), stroke: 2.2pt + luma(60))
  cdraw.content((4.9, 5.0), [4 = 2 × 2], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.content((4.6, 8.5), [both evens always covered], size: 6pt, fill: luma(100))
  cdraw.content((4.6, 1.5), [no winning opening, the verdict is second], size: 6.5pt, fill: luma(100))
})

#listing("icpc/samples-c/src/Ch13/pB.c", first: 39, last: 86, caption: [c, match_skip rebuilding the graph without one vertex, small_answer trying each even deletion against the full matching])

C links the year-local ch13_match header. C\# inlines the whole thing,
an adjacency array with a stamp-seen augmenting recursion, no helper at
all:

#listing("icpc/samples/src/Ch13/PB.cs", first: 75, last: 116, caption: [c\#, the augmenting path and the edge build inlined, seen stamps instead of a visited reset])

#listing("icpc/samples-go/ch13/pb.go", first: 38, last: 88, caption: [go, omega parity by trial division, the skip closure over the shared matcher, the retry loop])

#listing("icpc/samples-js/src/ch13-pb-blackboardgame.mjs", first: 26, last: 59, caption: [javascript, smallAnswer with the matchSkip closure, one matcher rebuild per candidate])

#listing("icpc/samples-py/src/Ch13/pb.py", first: 31, last: 78, caption: [python, the same engine, primes precomputed once and reused by every skip])

#listing("icpc/samples-lua/ch13_pb.lua", first: 53, last: 85, caption: [lua, small_answer over the shared match module, the parity and the retry loop])

The crafted pair pins the criterion. For n = 6 every even number is in
every maximum matching, so "second", and for n = 8 the matching
{1-7, 4-8, 3-6} keeps size 3 while avoiding 2, so "first 2". All six
suites assert exactly that pair, most add the n = 2 lone-even case,
"second" again, and the c\# and javascript suites reach past the cutoff:
c\# checks n = 1000003 opens "first 666662" and javascript validates any
large-n opening structurally, k even with k/2 above n/4 and at most
n/3, which
is the Bertrand claim asserted as it is used. The book's canonical
output is the smallest even k whose deletion keeps the maximum
matching size, pinned everywhere.

#diagram([the n = 8 prime-multiple graph, the matching 1-7, 4-8, 3-6 bolded, vertex 2 left unmatched as the winning opening], length: 12pt, {
  cdraw.circle((1.0, 5.4), radius: 0.36, fill: luma(245))
  cdraw.content((1.0, 5.4), [1], size: 6.5pt)
  cdraw.circle((3.0, 6.6), radius: 0.36, fill: luma(245))
  cdraw.content((3.0, 6.6), [2], size: 6.5pt)
  cdraw.circle((5.0, 5.4), radius: 0.36, fill: luma(245))
  cdraw.content((5.0, 5.4), [3], size: 6.5pt)
  cdraw.circle((7.0, 6.6), radius: 0.36, fill: luma(245))
  cdraw.content((7.0, 6.6), [4], size: 6.5pt)
  cdraw.circle((2.0, 3.4), radius: 0.36, fill: luma(245))
  cdraw.content((2.0, 3.4), [5], size: 6.5pt)
  cdraw.circle((4.0, 2.6), radius: 0.36, fill: luma(245))
  cdraw.content((4.0, 2.6), [6], size: 6.5pt)
  cdraw.circle((6.0, 3.4), radius: 0.36, fill: luma(245))
  cdraw.content((6.0, 3.4), [7], size: 6.5pt)
  cdraw.circle((8.4, 5.0), radius: 0.36, fill: luma(245))
  cdraw.content((8.4, 5.0), [8], size: 6.5pt)
  cdraw.line((1.0, 5.4), (2.0, 3.4), stroke: 0.5pt + luma(170))
  cdraw.line((1.0, 5.4), (3.0, 6.6), stroke: 0.5pt + luma(170))
  cdraw.line((1.0, 5.4), (5.0, 5.4), stroke: 0.5pt + luma(170))
  cdraw.line((1.0, 5.4), (6.0, 3.4), stroke: 2.2pt + luma(60))
  cdraw.line((3.0, 6.6), (5.0, 5.4), stroke: 0.5pt + luma(170))
  cdraw.line((3.0, 6.6), (4.0, 2.6), stroke: 2.2pt + luma(60))
  cdraw.line((5.0, 5.4), (4.0, 2.6), stroke: 2.2pt + luma(60))
  cdraw.line((7.0, 6.6), (8.4, 5.0), stroke: 2.2pt + luma(60))
  cdraw.line((7.0, 6.6), (4.0, 2.6), stroke: 0.5pt + luma(170))
  cdraw.line((7.0, 6.6), (5.0, 5.4), stroke: 0.5pt + luma(170))
  cdraw.content((3.0, 7.3), [unmatched, the opening], size: 6pt, fill: luma(120))
  cdraw.line((3.0, 7.0), (3.0, 6.95), stroke: luma(120))
})

Everything fits int32, no product beyond n is ever formed, and the
primality checks are trial division, so no sieve and no big integers
anywhere in the six ports.

== problem c, bride of pipe stream

Flubber flows from station 1, the factory, down through ducts. A
station splits its inflow among its ducts in any proportion it likes
and may simply discard what it does not forward, a duct forwards fixed
percentages of its inflow to lower stations or reservoirs and may lose
the rest, and the objective is the largest possible minimum percentage
of factory flow reaching any reservoir, the factory's own inflow
counting as one unit.

The input opens with three integers s, r, and d, then describes each
duct on one line: its station i, its output count k, then k pairs of a
target o and a percentage. The problemset pdf bounds s at 10000, r at
3, d between s and 20000, each duct at 1 to 10 outputs with distinct
targets o above i and percentages 1 to 100 summing to at most 100 per
duct, every station owning at least one duct, and stations numbered by
decreasing altitude so the duct graph is a dag. The limit is 12
seconds with answers accepted inside an absolute error of 1e-6, the
output is one line holding the optimal percentage, and the judge data
carries 82 cases for the letter, 2 samples and 80 secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`C-brideofpipestream/sample-1.in` and `sample-1.ans`: two stations and
three reservoirs, and the optimum splits the factory's unit flow 0.3
and 0.7 between the two station-1 ducts so reservoirs 3 and 4 land
level at 0.24 each while reservoir 5 takes 0.28 through station 2:

input:

```
2 3 3
1 2 3 80 4 10
1 2 2 40 4 30
2 1 5 100
```

expected output:

```
24.0
```

Official sample 2, same source: one station, two reservoirs, three
ducts, the two 50 percent singles and the 40-60 mixer, and the optimum
sends nothing down the second single, splitting 2/7 and 5/7 so both
tanks land at 3/7, the repeating decimal behind the letter's float
compare:

input:

```
1 2 3
1 1 2 50
1 1 3 50
1 2 2 40 3 60
```

expected output:

```
42.8571428571
```

Recognition: s at 1e4 with d at 2e4 and at most 10 outputs per duct bounds one dual propagation at the duct count plus the output count, about 2e5 operations along the altitude order the numbering hands over for free, and the nested simplex searches at about 70 outer and 50 inner probes budget 3500 × 2e5 ≈ 7e8 operations inside the 12 second limit.

The task sentence's shape, the largest possible minimum percentage, names a single scalar objective whose level the propagation prices directly, so the answer is one point on a searched axis rather than a combinatorial object. Problem C is the 2025 face of the one-dimensional answer-space search family. The one-dimensional answer-space search family also collects chapter 08 problem E and chapter 09 problem F. A secondary thread, linear programming duality, covers the equalized-tank target the split converges to.

Modeling the ducts as a max-flow network is the tempting wrong tool and the statement breaks it itself: a duct may forward as little as 1 percent and keep the rest, so conservation fails at every station, and a generic lp over the 2e4 duct variables carries no budget the nested searches do not.

The primal says it in flows: give every duct a flow and every
reservoir receipt a common lower bound t, write conservation at each
station as inflow at least outflow, and maximize t. The dual of that
max-min lp settles it: non-negative weights w with the reservoir
weights summing to exactly 1, each duct forcing w upstream to dominate
the percentage-scaled sum of its downstream weights, minimizing
w(station 1), and strong duality makes the dual optimum the primal
answer fraction. For fixed reservoir weights the station weights are a
max over ducts propagated bottom-up along the altitude order, which the
decreasing station numbering gives for free, so r = 1 is one pass,
r = 2 is a one-dimensional search over the single free weight, and
r = 3 nests one more level on the simplex, about 200 iterations per
level holding the error near 1e-9
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 3). Book 8's chapter 36, numerical methods, develops
the lp duality and dual weights this reduction rests on together with
the ternary and golden-section searches that scan the reservoir
simplex.

The worked run: trace the model on sample 1. Reservoir weights drive the dual: with w3, w4, and w5 summing to 1, the bottom-up pass reads w2 = w5 through duct three's lone 100 and w1 as the max of duct one's 0.8 w3 + 0.1 w4 and duct two's 0.4 w5 + 0.3 w4. Trying w5 = 0 first, the two arms balance where 0.8 w3 + 0.1 w4 = 0.3 w4, that is w4 = 4 w3, and w3 + w4 = 1 hands back w3 = 0.2 with w4 = 0.8, both arms at 0.8 × 0.2 + 0.1 × 0.8 = 0.24. Raising w5 only lifts the balance, the table's three probe rows, so the search parks the simplex at w5 = 0 and the dual value 0.24. The primal confirms the fraction: send x and 1 - x down the two station-1 ducts, reservoir 3 takes 0.8x and reservoir 4 takes 0.3 - 0.2x, the level pair meets at x = 0.3 with both at 0.24, reservoir 5 takes 0.4 × 0.7 = 0.28 above the bound, and the trace ends at the printed answer `24.0`.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*w5*], [*w3*], [*w4*], [*duct arms*], [*w1*]),
  [0.5], [0.3], [0.2], [both 0.26], [0.26],
  [0.25], [0.25], [0.5], [both 0.25], [0.25],
  [0], [0.2], [0.8], [both 0.24], [0.24],
)

#listing("icpc/samples-c/src/Ch13/pC.c", first: 34, last: 66, caption: [c, evalw propagating the max over ducts bottom-up, then the r = 2 ternary on the simplex])

#listing("icpc/samples/src/Ch13/PC.cs", first: 85, last: 128, caption: [c\#, the same two functions, EvalW then Solve2])

#listing("icpc/samples-go/ch13/pc.go", first: 45, last: 94, caption: [go, the three search tiers, ternary over x, inner ternary over y, z = 1 - x - y])

#listing("icpc/samples-js/src/ch13-pc-brideofpipestream.mjs", first: 51, last: 102, caption: [javascript, evalw plus both tiers in one slice, 70 outer and 50 inner iterations])

Python rides golden-section search instead of ternary, one fresh
evaluation per iteration rather than two, and the header measures about
five times fewer full propagations on the large secrets, the same
jointly convex dual for a fraction of the passes:

#listing("icpc/samples-py/src/Ch13/pc.py", first: 40, last: 82, caption: [python, evalw unchanged, then golden section reusing one endpoint value per step, nested once for r = 3])

#listing("icpc/samples-lua/ch13_pc.lua", first: 100, last: 143, caption: [lua, the r dispatch with the ternary inline and the inner closure over y])

The crafted fixture is one station, two reservoirs, two ducts: duct 1
sends 50 percent to reservoir 2, duct 2 sends 30 percent there and 80
percent to reservoir 3. Splitting a + c = 1 equalizes both tanks at
0.5a + 0.3c = 0.8c, which forces a = c and both at 0.4, and the dual
check lands on w3 = 0.2 with value 0.4, so the answer prints
"40.0000000000". Every suite asserts that, most add the r = 1 case
where the 100 percent duct takes everything for "100.0000000000", and
the c and lua suites add a lone 50 percent duct for "50.0000000000".
The judge comparison runs in last-line-float mode because the official answers
print ten decimals and the dual search carries its own tolerance, and
the c\# suite adds a third two-reservoir case with a repeating-decimal
optimum.

#diagram([station 1 splitting its flow between the two ducts, the percentage arrows, and both reservoir tanks filling to the equalized 40 percent line], length: 12pt, {
  cdraw.rect((8.6, 5.8), (11.4, 6.6), fill: luma(245), radius: 0.02)
  cdraw.content((10.0, 6.2), [station 1], size: 6.5pt)
  cdraw.rect((1.2, 1.1), (4.0, 3.4), stroke: luma(120))
  cdraw.rect((1.2, 1.1), (4.0, 1.94), fill: luma(215))
  cdraw.rect((5.8, 1.1), (8.6, 3.4), stroke: luma(120))
  cdraw.rect((5.8, 1.1), (8.6, 1.94), fill: luma(215))
  cdraw.content((2.6, 2.6), [reservoir 2], size: 6.5pt)
  cdraw.content((7.2, 2.6), [reservoir 3], size: 6.5pt)
  cdraw.line((8.6, 5.8), (2.6, 3.4), stroke: 0.8pt + luma(60))
  cdraw.line((11.4, 5.8), (7.2, 3.4), stroke: 0.8pt + luma(60))
  cdraw.content((4.4, 4.9), [duct 1: 50], size: 6pt, fill: luma(120))
  cdraw.content((10.4, 4.9), [duct 2: 30 and 80], size: 6pt, fill: luma(120))
  cdraw.content((4.6, 1.5), [0.4], size: 6.5pt)
  cdraw.content((7.2, 1.5), [0.4], size: 6.5pt)
  cdraw.content((4.6, 0.4), [a + c = 1, a = c], size: 6pt, fill: luma(120))
})

The percentages are integers and every real quantity is a double, so
there is no integer divergence to report, only the print format,
%.10f of a percentage, identical in all six.

== problem d, buggy rover

A rover sits on an r by c grid of flat and rocky cells, one cell
marked S, and carries a preference order over the four directions
N, E, S, W. Each move steps in the first direction of the current
order that stays on the grid and off rocks, so the order only ever
steers among the feasible directions. Cosmic rays may hit between
moves and replace the order wholesale, and given the grid, the start,
and the observed log of moves, the task is the fewest ray hits that
explain the log, some sequence of orders changing at most that many
times.

The input is two integers r and c, then the r grid rows over '.', '\#',
and exactly one 'S', then the move string. The problemset pdf bounds
r and c at 200, the log at 1 to 10000 letters with every logged move
landing on a flat cell, and the limit is 2 seconds. The output is one
integer, and the judge data carries 26 cases for the letter, 3 samples
and 23 secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`D-buggyrover/sample-1.in` and `sample-1.ans`: a 5 by 3 grid with one
rock at the top left, the rover starting mid-bottom, and the N, N, E,
N log. N twice from the fully open interior forces N to rank first,
the E then costs a ray since the interior leaves every direction
feasible, and the final N survives under an E-first order because the
right edge makes E infeasible there, so the answer is 1:

input:

```
5 3
#..
...
...
...
.S.
NNEN
```

expected output:

```
1
```

Recognition: r and c at 200 bound the walk's footprint, the log at 1e4 letters, and only 24 orders exist, so the survivor filter costs 24 × 1e4 = 2.4e5 first-feasible checks against the 2 second limit, microseconds of work, and the whole difficulty is the reset rule.

The cue is the word fewest: the log is an observation stream that a handful of faults must explain, and the consistent world is recovered by intersecting survivor sets and paying one fault whenever the intersection empties. Problem D is the 2025 face of the consistency under a faulty oracle family. Consistency under a faulty oracle ties chapter 11 problem W and chapter 12 problem A together.

Guessing the actual order schedule is the priced-out alternative: 24^10000 candidate sequences dwarf the log, and a dynamic program over order subsets pays 2^24 states times the log where one monotone intersection pass decides.

Only 24 orders exist and the position after each move depends only on
the move index, so per move the solver computes which orders have the
observed direction as their first feasible one, intersects with the
surviving set, and an empty intersection costs one ray and resets to
the current move's set. Keeping the maximal surviving set is optimal
because consistency is monotone under supersets, and the whole pass is
O(24 n)
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf pp. 3-4). The six ports differ only in how they generate
the 24 permutations, a hand-rolled next-permutation everywhere except
python, which imports them.

The worked run: trace the model on sample 1. The rover starts mid-bottom at row 4, column 1, and the position after each move depends only on the move index. Move 1, N: the bottom row leaves N, E, and W feasible, so N must outrank E and W, and 8 of the 24 orders survive. Move 2, N: the interior at row 3 leaves all four feasible, so N must rank first outright, 6 orders inside the 8, no ray. Move 3, E: the interior at row 2 again leaves all four feasible, E first outright contradicts every survivor, one ray, and the set resets to the 6 E-first orders. Move 4, N: the right edge at column 2 makes E infeasible, so N only needs to outrank S and W, and 2 of the E-first orders comply, no second ray. One ray in total, and the trace ends at the printed answer `1`.

#diagram([the sample 5 by 3 grid, the rock top left, the N-N-E-N walk from the mid-bottom S, and the single ray where the E reset happens], length: 12pt, {
  for c in range(3) {
    for r in range(5) {
      cdraw.rect((1.0 + c * 1.7, 1.0 + r * 1.7), (2.7 + c * 1.7, 2.7 + r * 1.7), stroke: luma(150))
    }
  }
  for c in range(3) {
    for r in range(5) {
      let x = 1.85 + c * 1.7
      let y = 1.85 + r * 1.7
      if c == 0 and r == 4 {
        cdraw.content((x, y), [\#], size: 8pt)
      } else if c == 1 and r == 0 {
        cdraw.content((x, y), [S], size: 7pt)
      } else {
        cdraw.content((x, y), [.], size: 7pt)
      }
    }
  }
  cdraw.line((3.55, 2.15), (3.55, 3.25), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.line((3.55, 3.85), (3.55, 4.95), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.line((3.85, 5.25), (4.95, 5.25), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.line((5.25, 5.55), (5.25, 6.65), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.content((3.15, 2.7), [N], size: 6.5pt, fill: luma(120), anchor: "east")
  cdraw.content((3.15, 4.4), [N], size: 6.5pt, fill: luma(120), anchor: "east")
  cdraw.content((4.4, 5.55), [E], size: 6.5pt, fill: luma(120))
  cdraw.content((5.7, 6.1), [N], size: 6.5pt, fill: luma(120), anchor: "west")
  cdraw.line((4.7, 5.6), (5.3, 4.9), stroke: luma(60))
  cdraw.line((5.3, 5.6), (4.7, 4.9), stroke: luma(60))
  cdraw.content((5.9, 4.6), [ray 1, reset to E-first], size: 6pt, fill: luma(120), anchor: "west")
})

#listing("icpc/samples-c/src/Ch13/pD.c", first: 76, last: 101, caption: [c, the survivor filter, mask of consistent orders, intersect, empty means a ray and a reset])

#listing("icpc/samples/src/Ch13/PD.cs", first: 68, last: 98, caption: [c\#, the same filter over a uint mask, the first-feasible-direction scan per order])

#listing("icpc/samples-go/ch13/pd.go", first: 53, last: 86, caption: [go, the filter with the direction decode as a switch])

#listing("icpc/samples-js/src/ch13-pd-buggyrover.mjs", first: 51, last: 77, caption: [javascript, the filter, mask bits over the 24 hand-permuted orders])

#listing("icpc/samples-py/src/Ch13/pd.py", first: 31, last: 51, caption: [python, itertools.permutations instead of a next-permutation loop, the filter eight lines long])

#listing("icpc/samples-lua/ch13_pd.lua", first: 68, last: 99, caption: [lua, the filter over byte compares, 1-based grid bounds, lua 5.4 bitwise and])

The crafted walk is a 3 by 3 grid starting at the bottom left with
moves N, E, N. The first move leaves 12 orders, those ranking N before
E at a cell where both are feasible. The second move needs E ranked
first at a fully open cell, contradicting every survivor, one ray, and
the third move needs N first, contradicting the E-first reset, a second
ray, and no single cut does better, so the answer is 2. Every suite
pins that plus the single-move corridor "0", and c\# adds a third case
where the contradiction lands on move two for "1". Counts per language:
2, 3, 2, 2, 2, 2.

#diagram([the crafted 3 by 3 grid, the N-E-N walk from the bottom-left S, and the two lightning bolts where the preference order had to change], length: 12pt, {
  for c in range(3) {
    for r in range(3) {
      cdraw.rect((1.0 + c * 1.7, 3.2 + r * 1.7), (2.7 + c * 1.7, 4.9 + r * 1.7), stroke: luma(150))
    }
  }
  cdraw.content((1.85, 4.05), [S], size: 7pt)
  cdraw.content((1.85, 5.75), [.], size: 7pt)
  cdraw.content((3.55, 5.75), [.], size: 7pt)
  cdraw.content((5.25, 5.75), [.], size: 7pt)
  cdraw.content((1.85, 7.45), [.], size: 7pt)
  cdraw.content((3.55, 7.45), [.], size: 7pt)
  cdraw.content((5.25, 7.45), [.], size: 7pt)
  cdraw.content((3.55, 4.05), [.], size: 7pt)
  cdraw.content((5.25, 4.05), [.], size: 7pt)
  cdraw.line((1.85, 4.5), (1.85, 5.4), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.line((2.2, 5.75), (3.2, 5.75), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.line((3.55, 6.1), (3.55, 7.0), stroke: 1.4pt + luma(60), mark: (end: ">"))
  cdraw.content((1.3, 4.95), [N], size: 6.5pt, fill: luma(120), anchor: "east")
  cdraw.content((2.3, 5.42), [E], size: 6.5pt, fill: luma(120))
  cdraw.content((3.15, 6.7), [N], size: 6.5pt, fill: luma(120), anchor: "east")
  cdraw.line((2.6, 5.9), (3.2, 6.5), stroke: luma(60))
  cdraw.line((3.2, 5.9), (2.6, 6.5), stroke: luma(60))
  cdraw.line((4.0, 6.45), (4.6, 7.05), stroke: luma(60))
  cdraw.line((4.6, 6.45), (4.0, 7.05), stroke: luma(60))
  cdraw.content((2.35, 6.35), [ray 1], size: 6pt, fill: luma(120), anchor: "east")
  cdraw.content((5.0, 6.75), [ray 2], size: 6pt, fill: luma(120))
})

Plain int32 grid walking, no counts beyond the move length, so the six
languages agree everywhere including the integers.

== problem e, delivery service

A delivery service hires couriers one at a time, and every courier
shuttles daily between a home city and a destination city: home
overnight and at 9:00, at the destination from 12:00 to 14:00, home
again at 17:00. Packages travel only with couriers and pass from one
courier to another exactly when the two share a city at the same time.
After each hire the output is the number of city pairs that can
exchange packages in both directions, meaning some chain of rides and
same-city handoffs moves a package either way between them.

The input is two integers n and m, then m hire lines of two integers
a and b, the home and destination of the hired courier. The problemset
pdf bounds n at 2e5 cities and m at 4e5 couriers, every hire naming
two distinct cities with no repeated pair. The limit is 12 seconds,
the output is one integer per hire, and the judge data carries 25
cases for the letter, a single sample and 24 secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`E-delivery/sample-1.in` and `sample-1.ans`: four hires over four
cities. The second leaves cities 1 and 3 apart even though both share
city 2, because noon 2 and morning 2 are different vertices, the
third adds the pair set of the component holding cities 2, 3, and 4,
and the fourth welds everything into all six pairs:

input:

```
4 4
1 2
2 3
4 3
4 2
```

expected output:

```
1
2
4
6
```

Recognition: n at 2e5 cities doubled to 4e5 vertices and m at 4e5 hires against the 12 second limit rule out any per-hire traversal, 4e5 hires × 4e5 vertices = 1.6e11 visits, while the union-find with small-into-large merging plus the signature table runs O(m log^2 n), about 4e5 × 17^2 ≈ 1.2e8 table operations.

The asked-for count, city pairs that can exchange packages in both directions, is a connectivity closure quantity: it only moves when components weld, and the morning-noon doubling turns every hire into one edge, the cue that the answer lives on the components. Problem E is the 2025 face of the component structure and connectivity family. The component structure and connectivity family runs through chapter 09 problem B, chapter 10 problem E, chapter 10 problem H, chapter 11 problem R, and chapter 13 problem G.

Rebuilding the component map per hire is the tempting alternative and the arithmetic kills it, the 1.6e11 visits above, and recomputing the pair count from scratch per hire adds another factor of n the incrementally maintained score already carries.

The model gives each city a morning vertex and a noon
vertex, because two couriers meet exactly when they share a home or a
destination, so courier (a, b) is the undirected edge {morning(a),
noon(b)}, and two cities are connected when their non-isolated
vertices share a component. One subtlety cost this wave a mid-week
correction: a component that touches both of its own cities, like
{morning 2, noon 4, morning 3} after hiring (2, 4) onto the (3, 4)
component, connects those cities too, and the original walkthrough
narrative missed it until two ports converged on the official
sample's arithmetic
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 4). Counting runs over the 2n vertices with
union-find under small-into-large merging: the score sum of c(C)^2
over components, c(C) the distinct cities a component touches, counts
each connected ordered pair once per shared component, and subtracting
n and X, the sum of f(sig)^2 over the unordered two-component
signatures held in an incrementally updated table, then halving,
yields exactly the unordered pairs, O(m log^2 n) with a balanced tree
behind the table.

The worked run: trace the model on sample 1, four hires over four cities. Hire (1, 2) welds morning 1 onto noon 2, a component touching cities 1 and 2, one pair, printed 1. Hire (2, 3) starts a second component touching cities 2 and 3, city 2's two vertices still apart, so the pairs stay (1, 2) and (2, 3), printed 2. Hire (4, 3) welds morning 4 onto it, a component touching 2, 3, and 4, and the pair set gains (2, 3), (2, 4), and (3, 4) for four in total, printed 4. Hire (4, 2) welds everything into one component touching all four cities, and the score formula agrees, one component with c(C) = 4 contributing 4^2 = 16, so (16 - 4 - 0) / 2 = 6, printed 6, and the trace ends at the printed answer `6`.

#table(
  columns: (auto, 1.5fr, auto),
  inset: 4pt,
  table.header([*hire*], [*components touching cities*], [*pairs*]),
  [(1, 2)], [{1, 2}], [1],
  [(2, 3)], [{1, 2} and {2, 3}], [2],
  [(4, 3)], [{1, 2} and {2, 3, 4}], [4],
  [(4, 2)], [{1, 2, 3, 4}], [6],
)

#listing("icpc/samples-c/src/Ch13/pE.c", first: 111, last: 145, caption: [c, unite under small-into-large, every moved city's signature retired and re-added, city counts and score updated in place])

The signature table is where the languages spread out. C open-addresses
a 64-bit packed key with tombstones so only live signatures occupy
memory, c\# and go and javascript and python use their native maps, and
the c\# slice shows the counting rule itself:

#listing("icpc/samples/src/Ch13/PE.cs", first: 38, last: 60, caption: [c\#, SigDelta over a Dictionary of packed roots, X moving by 2f+1 per add or remove])

#listing("icpc/samples-go/ch13/pe.go", first: 69, last: 111, caption: [go, the unite closure, map-based signatures, the overlap fix when both endpoints already sit together])

#listing("icpc/samples-js/src/ch13-pe-delivery.mjs", first: 62, last: 98, caption: [javascript, unite plus the hire loop printing (score - n - x) / 2 per line])

#listing("icpc/samples-py/src/Ch13/pe.py", first: 57, last: 104, caption: [python, the same engine, dict signatures, the formula in the hire loop])

#listing("icpc/samples-lua/ch13_pe.lua", first: 55, last: 92, caption: [lua, unite with table signatures, the same small-into-large walk])

The crafted instance hires (1, 2), then (3, 4), then (2, 4). The first
two hires give two separate components and pairs (1, 2) and (3, 4), so
the first two lines are 1 and 2. The third hire welds morning 2 onto
the component holding noon 4 and morning 3, city 2 straddles both
components, and the corrected model counts (1, 2), (2, 3), (2, 4),
(3, 4), so the third line is 4. All six suites assert 1, 2, 4 and the
straddling extra "3 2 / 1 2 / 2 3" asserting 1 then 2, which is the
correction lesson in miniature, and c\# adds a third stepwise case
asserting the same two answers. Counts per language: 2, 3, 2, 2, 2, 2.

#diagram([morning vertices above, noon vertices below, the three courier edges, and after the third hire city 2 straddling both shaded components], length: 12pt, {
  let xs = (1.0, 4.0, 7.0, 10.0, 13.0)
  let c1 = luma(228)
  let c2 = luma(205)
  for i in range(5) {
    let x = xs.at(i)
    let top = if i == 0 { c1 } else if i == 1 or i == 2 { c2 } else { luma(246) }
    let bot = if i == 1 { c1 } else if i == 3 { c2 } else { luma(246) }
    cdraw.circle((x, 6.6), radius: 0.34, fill: top)
    cdraw.content((x, 6.6), str(i + 1), size: 6.5pt)
    cdraw.circle((x, 1.4), radius: 0.34, fill: bot)
    cdraw.content((x, 1.4), str(i + 1), size: 6.5pt)
  }
  cdraw.content((14.6, 6.6), [morning], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.content((14.6, 1.4), [noon], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((1.0, 6.3), (4.0, 1.7), stroke: 1.6pt + luma(60))
  cdraw.line((7.0, 6.3), (10.0, 1.7), stroke: 1.2pt + luma(150))
  cdraw.line((4.0, 6.3), (10.0, 1.7), stroke: 1.2pt + luma(120), dash: "dashed")
  cdraw.content((4.0, 8.1), [city 2 straddles both], size: 6pt, fill: luma(100))
  cdraw.line((4.0, 7.8), (4.0, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.circle((1.2, 0.2), radius: 0.26, fill: c1)
  cdraw.content((1.7, 0.2), [component 1: cities 1 and 2], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.circle((9.2, 0.2), radius: 0.26, fill: c2)
  cdraw.content((9.7, 0.2), [component 2: cities 2, 3, 4], size: 6pt, fill: luma(120), anchor: "west")
})

Pair counts reach n(n-1)/2 near 2e10 and score squares 4e10, so c, c\#,
go, and lua carry int64, python is native, and javascript's plain
Number is exact below 2^53, which covers 4e10 with room, so no BigInt
anywhere.

== problem f, herding cats

m distinct catnip varieties go one per pot into a row of m pots. Each
cat walks the row from pot 1, sniffing every pot in turn, and stops at
the first pot holding a variety it likes. Given each cat's liked set
and the pot it is supposed to stop at, the answer is whether some
placement of varieties into pots makes every cat stop exactly at its
target.

The input is a test count t, then per test the cat count n and pot
count m, then n cat blocks: a target pot and a like count k, then the
k distinct liked varieties. The problemset pdf bounds t at 10000, n
and m at 2e5 per test with the sums of n and m over all tests capped
at 2e5 each, and the total like count at 5e5. The limit is 2 seconds,
the output is one line per test, yes or no, and the judge data carries
48 cases for the letter, a single sample and 47 secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`F-herdingcats/sample-1.in` and `sample-1.ans`: two tests over three
cats and five pots, the second identical except the last cat's target
moves from pot 4 to pot 5, which lifts varieties 3 and 4 to lower
bound 5 where only one pot remains and flips the verdict:

input:

```
2
3 5
2 2 1 5
2 3 1 4 5
4 2 3 4
3 5
2 2 1 5
2 3 1 4 5
5 2 3 4
```

expected output:

```
yes
no
```

Recognition: the sums of n and m over all tests cap at 2e5 each and the total like count at 5e5 against the 2 second limit, and the two conditions cost one pass over the cats then one sorted pass over the lower bounds, about 5e5 log 5e5 ≈ 1e7 steps, so the budget is trivial next to the model.

The cue is the placement question, whether some placement of varieties into pots makes every cat stop exactly at its target: feasibility under per-pot intersection quotas and per-prefix counts, Hall's condition in prefix form. Problem F is the 2025 face of the bipartite assignment feasibility family. The bipartite assignment feasibility family collects chapter 08 problem C, chapter 11 problem X, and chapter 13 problem B.

Running an explicit variety-to-pot matching is the priced-out alternative: 5e5 likes through a matching engine cost hundreds of millions of augment steps where two linear scans decide, and a greedy pot-by-pot fill without the prefix test can reject placements that exist.

A cat targeting p means every variety it likes sits at a pot at or
beyond p, so variety z carries the lower bound L(z), the maximum
target over the cats liking it, 1 when unliked. The placement exists
exactly when both of two conditions hold: every pot hosting cats
offers a variety in their intersection with L at most the pot, and for
every prefix q at least q varieties have L at most q, Hall's condition
in prefix form. The two conditions are also sufficient outright,
because filling pots left to right always leaves a legal variety for
the next pot. Both are checkable in one sorted pass, O(n + m + K log K)
with K the total like count
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf pp. 4-5). Book 8's chapter 38, network flows ii, states
hall's theorem in exactly this prefix form and proves it, the
matching argument the two conditions encode.

The worked run: trace the model on sample 1, two tests over the same three cats. Test 1: the liked sets give the lower bounds L(1) = 2 and L(5) = 2 from the two pot-2 cats, L(4) = 4 from the pot-4 cat, L(3) = 4, and L(2) = 1 unliked. Both hosted pots pass the intersection test, pot 2 offering 1 or 5 with L at most 2 and pot 4 offering 4 with L exactly 4, and the prefix counts hold at every q, the table, so the verdict is yes. Test 2 moves the last cat's target to pot 5, lifting L(3) and L(4) to 5, and the prefix count at q = 4 drops to the three varieties 1, 2, and 5 against four pots, Hall fails, and the trace ends at the printed answer `no`.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*q*], [*test 1, varieties with L at most q*], [*test 2*], [*verdict*]),
  [1], [1: {2}], [1: {2}], [both pass],
  [2], [3: {1, 2, 5}], [3: {1, 2, 5}], [both pass],
  [3], [3: {1, 2, 5}], [3: {1, 2, 5}], [both pass],
  [4], [5: {1, 2, 3, 4, 5}], [3: {1, 2, 5}], [test 2 fails],
)

#listing("icpc/samples-c/src/Ch13/pF.c", first: 67, last: 100, caption: [c, per-pot intersection by stamp, the hit test against L, then the prefix count])

#listing("icpc/samples/src/Ch13/PF.cs", first: 59, last: 97, caption: [c\#, the same two conditions, arrays instead of stamps])

#listing("icpc/samples-go/ch13/pf.go", first: 46, last: 89, caption: [go, cat lists threaded through pot buckets, touched varieties collected per pot])

#listing("icpc/samples-js/src/ch13-pf-herdingcats.mjs", first: 41, last: 72, caption: [javascript, the intersection scan and the hit test, the prefix count below])

#listing("icpc/samples-py/src/Ch13/pf.py", first: 36, last: 61, caption: [python, bucket lists and a dict intersection count, any() for the hit test])

#listing("icpc/samples-lua/ch13_pf.lua", first: 62, last: 113, caption: [lua, stamped intersection and the two conditions, the verdict assembled per test])

The crafted pair of tests pins both directions. In the first, two cats
target pot 2 over four pots, L(1) = L(2) = 2 with two unliked
varieties free at pot 1, so a placement like 3, 1, 2, 4 exists and the
verdict is yes. In the second, three cats target pots 2 and 3 and like
all three varieties between them, so no variety can sit at pot 1
without stopping a cat early, the prefix count fails at q = 1, and the
verdict is no. Every suite asserts that yes/no pair, most add the
omnivore cat whose liked set stops it at pot 1 while it targets pot 2,
and c\# adds a single-cat first-pot case. Counts per language: 2, 3, 2,
2, 2, 2.

#diagram([the pot row with varieties planted, two cats walking from the left, and the L bounds bracketed beneath their pots], length: 12pt, {
  for i in range(4) {
    cdraw.rect((1.2 + i * 2.6, 4.6), (3.0 + i * 2.6, 6.2), stroke: luma(150))
    cdraw.line((2.1 + i * 2.6, 5.6), (2.1 + i * 2.6, 6.2), stroke: luma(120))
  }
  cdraw.content((2.1, 5.0), [3], size: 7pt)
  cdraw.content((4.7, 5.0), [1], size: 7pt)
  cdraw.content((7.3, 5.0), [2], size: 7pt)
  cdraw.content((9.9, 5.0), [4], size: 7pt)
  cdraw.line((0.8, 7.6), (2.0, 6.6), stroke: 1.2pt + luma(60), mark: (end: ">"))
  cdraw.line((3.6, 7.6), (4.6, 6.6), stroke: 1.2pt + luma(60), mark: (end: ">"))
  cdraw.content((1.0, 8.0), [cat 1 stops at pot 2], size: 6pt, fill: luma(120))
  cdraw.content((4.2, 8.0), [cat 2 stops at pot 2], size: 6pt, fill: luma(120))
  cdraw.content((2.1, 3.9), [1], size: 6pt, fill: luma(120))
  cdraw.content((4.7, 3.9), [2], size: 6pt, fill: luma(120))
  cdraw.content((7.3, 3.9), [2], size: 6pt, fill: luma(120))
  cdraw.content((9.9, 3.9), [1], size: 6pt, fill: luma(120))
  cdraw.content((5.9, 2.9), [L bounds per variety, pots 1 through 4], size: 6pt, fill: luma(100))
})

Counts fit int32 everywhere, likes total 5e5, and no language needs
more than its default integer.

== problem g, lava moat

A triangulated terrain stretches w by l, every vertex carrying a
distinct integer elevation and every triangle interpolating linearly
between its corners. A lava moat must cross the terrain from the west
border to the east border at one constant elevation, following the
level curve, and the task is the shortest feasible moat length, or
impossible when no level connects the two borders at all.

The input is a test count t, then per test the extents w and l, the
vertex count n, and the triangle count m, then n vertex lines of x, y,
and z and m triangle lines of three vertex indices. The problemset pdf
bounds t at 10000, w and l at 1e6, n between 4 and 50000, m between
n-2 and 2n-6, coordinates at 0 to 1e6 with only the corner vertices on
the west and east borders, all positions and all elevations distinct
with z at most 1e6, a full triangulation, and the sum of n over tests
at 50000. The limit is 4 seconds with a 1e-6 absolute or relative
tolerance, the output is one line per test, the length or impossible,
and the judge data carries 101 cases for the letter, a single sample
and 100 secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`G-lavamoat/sample-1.in` and `sample-1.ans`: three terrains in one
file, the first admitting no west-east level at all, the second
answering 6.708203932, the third 15.849260054,
the mixed impossible-plus-float lines that force the letter's
all-lines float compare:

input:

```
3
6 6 4 2
0 0 1
6 0 4
6 6 3
0 6 2
1 2 3
1 3 4
6 6 4 2
0 0 1
6 0 2
6 6 4
0 6 3
1 2 3
1 3 4
10 6 7 7
6 1 8
10 0 10
10 6 4
2 6 6
0 6 0
4 3 11
0 0 7
2 1 7
2 3 1
3 6 1
3 4 6
6 4 5
5 7 6
7 1 6
```

expected output:

```
impossible
6.708203932
15.849260054
```

Recognition: n summed at 50000 with m near 2n, about 1e5 triangle cuts, against the 4 second limit: the offline sweep hangs each cut's lifetime on a segment tree over at most 5e4 level intervals and unwinds every union, O(n log^2 n), about 5e4 × 17^2 ≈ 1.4e7 logged unions.

The cue is the constant elevation: the moat is one level curve crossing west to east, so the whole task lives on the components the cuts form while the level moves, connectivity under edge lifetimes. Problem G is the 2025 face of the component structure and connectivity family. The component structure and connectivity family runs through chapter 09 problem B, chapter 10 problem E, chapter 10 problem H, chapter 11 problem R, and chapter 13 problem E.

Rebuilding the level-curve graph per candidate elevation is the priced-out alternative: 5e4 anchor levels × 1e5 cuts is 5e9 segment insertions, and even sorting events per level pays n^2 log n where the segment tree touches each cut log n times in total.

Shifting the level changes every cut length linearly, so an optimal
moat sits at a vertex elevation. At a fixed level each triangle cut
contributes a segment joining its two edges that span the level, level
curves are chains over edge-crossing nodes, and sweeping the levels
bottom-up with offline dynamic connectivity, edge lifetimes hung on a
segment tree over level intervals and a union-find that unwinds,
tracks each component's total length as a linear function a + b*h plus
west and east border flags. The answer for an anchor vertex is the
cheapest component touching both borders, O(n log^2 n)
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 5). Book 8's chapter 31, sqrt decomposition and
offline queries, builds this offline dynamic connectivity from
scratch, the segment tree over time carrying the edge lifetimes and
the rollback union-find holding the growing chains. Two solved teams
at 270 minutes, and this book
agrees with them: the sweep engine is the largest of the year, so
every language splits it out of the solver file to stay under the
400-line cap, ch13_moat.h plus ch13_rollback.h in c, moat.go beside
pg.go, ch13-moat.mjs beside the solver in javascript, ch13_moat.lua
plus ch13_rollback.lua, ch13_rollback.py in python, and Moat.cs in c\#.
The sweep scores each leaf twice, once per closed endpoint, crediting
border chains through the corner vertices that own the level.

The worked run: trace the model on sample 1, three terrains in one file. Terrain 1: the west border vertices carry elevations 1 and 2, the east border 4 and 3, the open bands [1,2] and [3,4] never share a level, and the first line prints impossible. Terrain 2: every level between 2 and 3 draws the same west-east chain, from the west crossing (0, 3(h-1)) through the diagonal point (2(h-1), 2(h-1)) to the east crossing (6, 3(h-2)), the two segments scaling as (h-1) sqrt(5) and (4-h) sqrt(5), a constant 3 sqrt(5), so the sweep's first both-border candidate, scored at the closed endpoint h = 2, prints 6.708203932. Terrain 3: the borders span [0,7] west and [4,10] east, and in the interval just above 6 the sweep scores its both-border chain at the closed endpoint h = 6, from the west crossing (0, 6/7) over (24/11, 48/11) and through the vertex (2,6) whose elevation is exactly 6, then over (58/7, 36/7) and (8, 7/2) to the east crossing (10, 4), five cuts of length 4.129870130, 1.646433661, 6.343886660, 1.667516790, and 2.061552813, and no other level's chain beats it, and the trace ends at the printed answer `15.849260054`.

#diagram([terrain 3 in plan view, the corners and the north vertex labeled with elevations, and the level-6 west-east chain through the vertex (2,6) bolded], length: 12pt, {
  cdraw.line((1.5, 0.9), (11.0, 0.9), stroke: 0.8pt + luma(60))
  cdraw.line((1.5, 0.9), (1.5, 6.0), stroke: 0.8pt + luma(60))
  cdraw.line((11.0, 0.9), (11.0, 6.0), stroke: 0.8pt + luma(60))
  cdraw.line((1.5, 6.0), (11.0, 6.0), stroke: 0.8pt + luma(60))
  cdraw.content((3.4, 6.35), [(2,6) z=6], size: 6pt, fill: luma(120))
  cdraw.content((0.9, 6.35), [(0,6) z=0], size: 6pt, fill: luma(120), anchor: "east")
  cdraw.content((1.0, 0.5), [(0,0) z=7], size: 6pt, fill: luma(120))
  cdraw.content((11.5, 0.5), [(10,0) z=10], size: 6pt, fill: luma(120))
  cdraw.content((11.5, 6.35), [(10,6) z=4], size: 6pt, fill: luma(120))
  cdraw.content((0.6, 3.4), [west], size: 6pt, fill: luma(120), anchor: "east")
  cdraw.content((11.9, 3.4), [east], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((1.5, 1.63), (3.57, 4.61), stroke: 2.2pt + luma(30))
  cdraw.line((3.57, 4.61), (3.4, 6.0), stroke: 2.2pt + luma(30))
  cdraw.line((3.4, 6.0), (9.37, 5.27), stroke: 2.2pt + luma(30))
  cdraw.line((9.37, 5.27), (9.1, 3.88), stroke: 2.2pt + luma(30))
  cdraw.line((9.1, 3.88), (11.0, 4.3), stroke: 2.2pt + luma(30))
  cdraw.circle((3.4, 6.0), radius: 0.14, fill: luma(30))
  cdraw.content((2.0, 1.9), [4.129870], size: 6pt, fill: luma(90))
  cdraw.content((2.0, 5.4), [1.646434], size: 6pt, fill: luma(90), anchor: "east")
  cdraw.content((6.3, 5.75), [6.343887], size: 6pt, fill: luma(90))
  cdraw.content((9.9, 4.75), [1.667517], size: 6pt, fill: luma(90))
  cdraw.content((9.6, 3.5), [2.061553], size: 6pt, fill: luma(90), anchor: "east")
  cdraw.content((6.2, 0.35), [h = 6, the chain through the vertex, length 15.849260054], size: 6.5pt, fill: luma(100))
})

#listing("icpc/samples-c/src/Ch13/pG.c", first: 87, last: 134, caption: [c, credit_and_eval at one endpoint, border credit stamped per root, both-border components scored as a + b*h])

#listing("icpc/samples/src/Ch13/PG.cs", first: 94, last: 141, caption: [c\#, the same endpoint scoring over the static Moat arrays])

#listing("icpc/samples-go/ch13/pg.go", first: 165, last: 188, caption: [go, the segment-tree descent, add every hanging segment, recurse, undo every union and list op])

A second pass drops each cut's first leaf so the anchor's legs dangle,
and through a vertex the shortest west-east path is the shortest west
leg plus the shortest east leg, each leg read off its v-middle
triangle's crossing component:

#listing("icpc/samples-js/src/ch13-pg-lavamoat.mjs", first: 117, last: 145, caption: [javascript, anchorArmEval scoring through-anchor candidates, then the same undo-wrapped dfs])

#listing("icpc/samples-py/src/Ch13/pg.py", first: 36, last: 82, caption: [python, the endpoint scoring again, bisect for the level bounds, arrays from the rollback module])

#listing("icpc/samples-lua/ch13_pg.lua", first: 130, last: 157, caption: [lua, the arm pass, per-anchor west and east legs summed through the crossing components])

The crafted terrain is a unit square with corners z = 0, 2, 4, 2 and
the 1-3 diagonal. The west border spans elevations 0 to 2 and the east
border 2 to 4, so no open level interval touches both, and exactly at
level 2 the curve runs (2, 0) to (1, 1) to (0, 2), both segments of
length sqrt(2) with the diagonal midpoint interpolating to exactly 2,
so the answer is 2.828427125. Every suite pins that plus the
impossible variant z = 0, 2, 3, 1 whose borders never coincide, two
fixtures per language everywhere, and the judge comparison runs in the
all-lines float mode, numeric lines within 1e-4, because the output
mixes "impossible" lines with floats printed to 9 or more significant
digits.

#diagram([the two triangles in plan view, elevations at the corners, and the level-2 polyline through (2,0), (1,1), (0,2) bolded], length: 12pt, {
  cdraw.line((2.0, 1.2), (10.0, 1.2), stroke: 0.8pt + luma(60))
  cdraw.line((2.0, 1.2), (2.0, 7.4), stroke: 0.8pt + luma(60))
  cdraw.line((10.0, 1.2), (10.0, 7.4), stroke: 0.8pt + luma(60))
  cdraw.line((2.0, 7.4), (10.0, 7.4), stroke: 0.8pt + luma(60))
  cdraw.line((2.0, 1.2), (10.0, 7.4), stroke: 0.8pt + luma(60))
  cdraw.line((10.0, 1.2), (6.0, 4.3), stroke: 2.2pt + luma(30))
  cdraw.line((6.0, 4.3), (2.0, 7.4), stroke: 2.2pt + luma(30))
  cdraw.content((1.3, 0.7), [(0,0) z=0], size: 6pt, fill: luma(120))
  cdraw.content((10.7, 0.7), [(2,0) z=2], size: 6pt, fill: luma(120))
  cdraw.content((10.7, 7.9), [(2,2) z=4], size: 6pt, fill: luma(120))
  cdraw.content((1.3, 7.9), [(0,2) z=2], size: 6pt, fill: luma(120))
  cdraw.content((7.5, 3.4), [(1,1) z=2, the midpoint], size: 6pt, fill: luma(30), anchor: "west")
  cdraw.line((7.35, 3.5), (6.4, 4.15), stroke: luma(90), mark: (end: ">"))
  cdraw.content((4.0, 6.4), [h = 2, length 2 sqrt(2)], size: 6.5pt, fill: luma(100))
  cdraw.content((0.4, 4.3), [west], size: 6pt, fill: luma(120), anchor: "east")
  cdraw.content((11.6, 4.3), [east], size: 6pt, fill: luma(120))
})

Squared cut lengths reach 8e12, int64 in c, c\#, go and lua integers,
exact in javascript's Number, and c alone carries its lengths in long
double for the judge's 1e-6 tolerance while printing %.9f like the
rest.

== problem h, score values

A contact-bridge scoreboard starts at 0, every move adds one of n fixed
point values, and any move that would push past the maximum m leaves
the score sitting at m. The club must buy digit signs, and the fewest
of them able to display every score reachable at any moment, where a
6 sign doubles as a 9 by flipping, so a 9 in a number spends a 6 sign.
The report is the per-digit purchase count for the digits 0 through 8.

The input is two integers m and n, then the n point values. The
problemset pdf bounds m at 1e18 and n at 10, the values distinct and
each between 1 and 1000. The limit is 2 seconds, the output is one
"d c" line per digit 0 through 8 in ascending order with zero counts
omitted, the digit 9 never appearing because 6 covers it, and the
judge data carries 108 cases for the letter, 2 samples and 106
secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`H-scorevalues/sample-1.in` and `sample-1.ans`: m = 1000 with the
values 60, 100, 222, and 650. The cap itself supplies three 0 signs,
222 with its double 444 and its triple 666 supplies three 2s, 4s, and
6s, 770 = 650 + 120 supplies two 7s, 888 = 4 times 222 three 8s, and
no reachable score ever repeats a 1, a 3, or a 5:

input:

```
1000 4
60
100
222
650
```

expected output:

```
0 3
1 1
2 3
3 1
4 3
5 1
6 3
7 2
8 3
```

Recognition: m at 1e18 with only 10 generators of size at most 1000 kills every value-indexed table: the split sieves below about 1e6 or 1e7 and runs a digit dp over 19 positions by g by 10 states, at most about 2e6 sieve marks plus 2e5 dp cells against the 2 second limit.

The cue is the purchase order, the fewest signs able to display every score reachable at any moment: the reachable set is a capped semigroup, and the per-digit maxima come from a hand-built state space of digit position, residue mod g, and tightness against m's digits. Problem H is the 2025 face of the dp over an engineered state space family. The dp over an engineered state space family spans chapter 09 problem J, chapter 10 problem I, chapter 11 problem S, and chapter 12 problem J.

Enumerating the reachable scores is the priced-out alternative: past the Frobenius region every multiple of g is reachable, so the count approaches 5e17 values below 1e18, and the sieve tier only exists because the digit dp cannot start below the bound.

The reachable scores are 0, the semigroup values capped at m, and m
itself, always reachable by repeating the largest value. With a single
point value the dp tracks value mod p directly, and with several the
large scores are exactly the multiples of g = gcd of the values, so
the normalized generators drive an integer knapsack sieve below the
split and the digit dp above it. Past the Frobenius region, bounded by
the square of the largest generator, at most 1e6
here, every multiple of g is reachable, so the
solver sieves the semigroup below a cap and runs a digit dp above it,
value mod g per position tracking the best count of the target digit,
with m's own length staying tight along m's digits, a sieve to about
2e6 plus 9 digits by 19 lengths by g by 10 in the dp
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf pp. 5-6). Book 8's chapter 35, combinatorics, carries
the frobenius numerical-semigroup bound this split rides on.

The worked run: trace the model on sample 1, m = 1000 with the values 60, 100, 222, and 650. The generators share gcd 2, and m sits inside the sieve tier, so the reachable scores are enumerated outright and the nine counts read off their witnesses, the table. The cap itself is reachable, 1000 = 10 × 100, and supplies three 0 signs, 222 with its multiples 444 and 666 supplies three 2s, 4s, and 6s, 770 = 650 + 2 × 60 supplies two 7s, 888 = 4 × 222 supplies three 8s, and no reachable score repeats a 1, a 3, or a 5, the repeated-1 candidates 110 through 118 all missing from the semigroup and 1100 sitting past the cap, so those digits peak at one sign, and the trace ends at the printed answer `8 3`.

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*digit*], [*witness score*], [*signs*]),
  [0], [1000 = 10 × 100], [3],
  [1], [100 = 1 × 100], [1],
  [2], [222 = 1 × 222], [3],
  [3], [300 = 5 × 60], [1],
  [4], [444 = 2 × 222], [3],
  [5], [500 = 5 × 100], [1],
  [6], [666 = 3 × 222], [3],
  [7], [770 = 650 + 2 × 60], [2],
  [8], [888 = 4 × 222], [3],
)

#listing("icpc/samples-c/src/Ch13/pH.c", first: 130, last: 163, caption: [c, the tight pass at m's length, free digits below the prefix, m itself appended at the end])

#listing("icpc/samples/src/Ch13/PH.cs", first: 123, last: 155, caption: [c\#, the free-length dp, every residue carrying the best digit count])

#listing("icpc/samples-go/ch13/ph.go", first: 118, last: 148, caption: [go, the same free lengths, residues over g, hit() folding 9 into 6])

#listing("icpc/samples-js/src/ch13-ph-scorevalues.mjs", first: 86, last: 104, caption: [javascript, the free tier compact, m parsed as BigInt because 1e18 exceeds 2^53])

The caps diverge by design. C, c\#, go, and javascript sieve to 1e7 and
start the residue dp at eight digits, python sieves to 1e6 + 1000 and
lua to 1e6, both starting the dp at seven digits, which the Frobenius
bound of at most 1e6 licenses, and lua walks the sieve once maintaining
the per-digit decimal counts incrementally instead of formatting each
reachable value:

#listing("icpc/samples-py/src/Ch13/ph.py", first: 66, last: 95, caption: [python, the free-length residue dp from seven digits on, one row swap per position])

#listing("icpc/samples-lua/ch13_ph.lua", first: 68, last: 101, caption: [lua, the sieve sweep with digit counts carried incrementally, 9s merging into the 6 tally])

The crafted case is m = 200 with values 3 and 5. The semigroup is 3,
5, 6, and everything from 8 up, digit 0 peaks in 100 and 200 for 2,
digit 1 peaks in 111, which is 3 times 37, for 3, every other digit
peaks twice,
and 6 never triples because 666 exceeds the cap and 9s count as 6s, so
the answer is the nine lines 0 2 through 8 2. Every suite pins that
and the unit case m = 1, value 1, answering 0 1 and 1 1, two per
language.

#diagram([a strip of reachable scores up to 200, with 100, 111 and 200 highlighted and one repeated-digit pair marked per digit], length: 12pt, {
  cdraw.line((1.0, 4.4), (17.0, 4.4), stroke: 0.8pt + luma(60))
  for x in (1.0, 5.0, 9.0, 13.0, 17.0) {
    cdraw.line((x, 4.2), (x, 4.6), stroke: 0.8pt + luma(60))
  }
  cdraw.content((1.0, 3.7), [0], size: 6pt)
  cdraw.content((5.0, 3.7), [8], size: 6pt)
  cdraw.content((13.0, 3.7), [111], size: 6pt)
  cdraw.content((17.0, 3.7), [200], size: 6pt)
  cdraw.content((9.0, 3.7), [55], size: 6pt)
  cdraw.circle((9.0, 4.4), radius: 0.3, stroke: luma(60))
  cdraw.circle((13.0, 4.4), radius: 0.3, stroke: luma(60))
  cdraw.circle((17.0, 4.4), radius: 0.3, stroke: luma(60))
  cdraw.circle((1.0, 4.4), radius: 0.3, stroke: luma(60))
  cdraw.content((13.0, 5.4), [111, three ones], size: 6pt, fill: luma(120))
  cdraw.content((17.0, 6.0), [200, two zeros], size: 6pt, fill: luma(120))
  cdraw.content((9.0, 5.4), [55, a pair], size: 6pt, fill: luma(120))
  cdraw.content((4.0, 2.2), [8 and up all reachable, so each digit's maximum is a formatting question], size: 6.5pt, fill: luma(100))
})

m reaches 1e18, so c, c\#, go, and lua use 64-bit integers, python is
native, and javascript parses m and walks its digits as BigInt while
the residues stay small.

== problem i, slot machine

A slot machine carries n wheels, each showing one of n symbols at a
time, and the symbols sit in the same cyclic order on every wheel, the
wheels merely pointing at different positions on that shared cycle.
One action rotates any single wheel any number of steps, and after
each action the machine reports k, the count of distinct symbols
currently visible across the wheels. The task is to reach the jackpot,
every wheel showing the same symbol so k reads 1, within the round
budget.

The interaction opens by reading n, then one line per round holding
k, the count of distinct symbols the friend currently sees: the shown
symbols never cross the wire, the initial configuration being the
judge's private state, fixed in advance and carried by the case file.
The problemset pdf bounds n between 3 and
50 and guarantees the initial configuration is
not already solved. Each round prints one line holding i and j, with
1 <= i <= n and j any integer, which rotates wheel i by j steps, then
reads the new k, and the program exits once k reads 1, all inside
10000 rotations under a 2 second limit. The judge data carries 64
cases for the letter, 2 samples and 62 secrets.

No sample pair can be reprinted the usual way, because this is the
set's second structural exception: the problem is interactive, the
judge directory holds the two fixed wheel configurations, a
five-wheel one and a three-wheel one, plus .interaction transcripts
that mark every judge line with '<' and every contestant line with
'>', and not one .ans file, so there is nothing to byte-diff and the
chapter asserts the emptiness rather than quoting a transcript.

Recognition: n at most 50 wheels under 10000 rotations and 2 seconds makes the budget countable in rounds: the two-phase strategy spends around 3n^2 rotations, the measured worst 8241 at n = 50 sitting near 3.3n^2, inside the cap with room, and every k recount costs O(n).

The cue is the protocol itself, print a rotation, read k, reach the jackpot: the algorithm is the query strategy, feedback steering hidden state toward a goal, not a function of a fixed input. Problem I is the 2025 face of the interactive strategy by feedback family, the only member of its family in this book.

Blind alignment is the priced-out alternative: without the distinctness phase the offsets stay entangled, n^(n-1) alignments at n = 50, and even pairwise probing without undoing every probe costs n^3 = 1.25e5 rounds against the 10000 budget.

Phase one makes all symbols distinct, sweeping each wheel
through its positions and keeping the argmax, which works because the
other wheels occupy at most n - 1 symbols so a fresh symbol always
wins. Phase two recovers the relative offsets, nudging one wheel
forward and another back, the count staying at n exactly when the
second sits one symbol further along, every probe undone literally so
all relations refer to one frozen state, the successor cycle's last
edge forced, and n - 1 final rotations align everything, about 3n^2
rounds at n = 50
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 6). Every language exposes the pure
driver, solve over a query callback, and the self-check runs crafted
configurations through a bundled simulator, the year's ch13_wheels
helper, asserting the jackpot, the round budget, and protocol
well-formedness. The judge lane drives the same cores through
`interactive:2025-i`: the interactor implements the judge side of the
protocol, spawning each language's solver core as a child through
harness shims under `ref/icpc/driver/`, lua replayed from its
judge-mode transcript instead, answering every rotation from its own
machine and passing iff the jackpot lands inside 10000 well-formed
actions. The pdf's exit rule, stop forever at the first k = 1, lives
in those shims: the strategy cores keep probing when a probe leg
lands on the jackpot mid-sweep, the already-distinct sample 2 being
the official witness, so the adapters carry the exit the cores omit.

The worked run: trace the crafted fixture, the three wheels at positions 1, 2, 1, because the interactive judge ships transcripts rather than answers, so the trace targets the jackpot the simulator must report. The wheels show symbols 1, 2, and 1, so k reads 2. Phase one sweeps wheel 1 through its three rotations: at symbol 2 the row reads 2, 2, 1 with k = 2, and at symbol 3 it reads 3, 2, 1 with k = 3, the argmax kept, the table, and wheels 2 and 3 sweep and keep their symbols too, either move dropping k back to 2, so after 9 rotations the row is distinct at 3, 2, 1. Phase two probes pairs, rotating one wheel forward and another back, the count staying at 3 exactly when the second sat one symbol further along, every probe undone, and the final n - 1 = 2 rotations align wheels 2 and 3 onto wheel 1's symbol. The simulator reports k = 1 well inside the 3n^2 + 10 = 37-round fixture budget.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*wheel 1 shows*], [*row*], [*k*], [*kept*]),
  [1], [1 2 1], [2], [start],
  [2], [2 2 1], [2], [no],
  [3], [3 2 1], [3], [yes, the argmax],
)

#listing("icpc/samples-c/src/Ch13/pI.c", first: 32, last: 75, caption: [c, the distinctness sweep then the pair probes through one function-pointer query, every probe literally undone])

C\# is the one language that inlines the simulator as a sealed class
instead of shipping a helper file:

#listing("icpc/samples/src/Ch13/PI.cs", first: 20, last: 57, caption: [c\#, the Wheels simulator inlined, position p showing symbol ((p-1) mod n) + 1, rotate adding j mod n])

#listing("icpc/samples-go/ch13/pi.go", first: 42, last: 80, caption: [go, phase one and the probe loop over the wheels13 engine])

#listing("icpc/samples-js/src/ch13-pi-slotmachine.mjs", first: 29, last: 67, caption: [javascript, the same two phases, the probe pair and its literal undo])

#listing("icpc/samples-py/src/Ch13/pi.py", first: 38, last: 77, caption: [python, the probes, the forced last edge, and the alignment chain built from succ])

#listing("icpc/samples-lua/ch13_pi.lua", first: 62, last: 100, caption: [lua, the reverse probe, the forced edge, and the final alignment rotations])

The crafted configurations are n = 3 at positions 1, 2, 1, n = 3
already distinct, and n = 4 alternating 2, 4, 2, 4, and every suite
asserts the simulator reports k = 1 within 3n^2 + 10 rounds on each.
The c\# suite sticks to the three, go and python match it, the c suite
carries four checks, javascript ten assertions including protocol
bounds and the pinned worst-round sweep, and lua adds a fourth,
five-wheel configuration. One
cross-language measurement came out of this problem, re-measured
under the interactive driver: sweeping the same 383 deterministic
configurations up to n = 50 through javascript and c, the per-config
round counts agree exactly, zero mismatches over the whole sweep, the
worst 8241 at n = 50 in both, and the official inputs measure worst
8045 in every language, so the originally quoted 8037-versus-8045
spread was sampling noise from sweeping different generated config
sets, not callback discipline: the strategy is step-identical, and
the javascript suite pins the deterministic sweep's worst count.

#diagram([five wheels as symbol columns with the visible row highlighted, one rotation arrow, and a distinct-count readout that shrinks toward 1 as rounds pass], length: 12pt, {
  let syms = (([2], [3], [1], [4], [5]), ([3], [1], [4], [5], [2]),
              ([1], [4], [5], [2], [3]), ([4], [5], [2], [3], [1]),
              ([5], [2], [3], [1], [4]))
  for w in range(5) {
    for r in range(5) {
      cdraw.rect((1.4 + w * 2.9, 7.6 - r * 1.5), (3.6 + w * 2.9, 9.1 - r * 1.5), stroke: luma(160))
      cdraw.content((2.5 + w * 2.9, 8.35 - r * 1.5), syms.at(w).at(r), size: 7pt)
    }
    cdraw.rect((1.4 + w * 2.9, 7.6), (3.6 + w * 2.9, 9.1), fill: rgb("eef3fa"), stroke: luma(60))
    cdraw.content((2.5 + w * 2.9, 8.35), syms.at(w).at(0), size: 7pt)
  }
  cdraw.line((0.7, 8.6), (0.7, 7.1), stroke: luma(120), mark: (end: ">"))
  cdraw.content((2.5, 9.9), [wheel 1, top row visible], size: 6pt, fill: luma(120))
  cdraw.content((8.3, 0.9), [k readout: 4, 3, 3, 3, 2, 1], size: 6.5pt, fill: luma(100))
  cdraw.content((8.3, 0.15), [rotate any wheel, any number of steps, one round each], size: 6pt, fill: luma(120))
})

n is at most 50 and rotation offsets stay small, so plain integers
carry everything and the only divergence is the callback shape, a
function pointer in c, a delegate-shaped closure elsewhere.

== problem j, stacking cups

Cup i is 2i-1 centimeters tall with a 1 centimeter base, diameters
grow with i so cup i nests inside cup j exactly when i is below j, and
the smallest cup is all base, a single centimeter of sentiment. After
washing, the n cups are stacked into one tower: each cup drops
centered and upright onto the common axis, a falling cup passes
straight through the interiors of wider cups already placed, and the
tower's height is the vertical distance from the lowest point of any
cup to the highest. The task names a placement order whose final tower
spans exactly the favorite number h, using all n cups, or answers
impossible.

The input is a single line of two integers, n and h. The problemset
pdf bounds n at 2e5 and h at 4e10, under a 2 second limit, and the
judge data carries 136 cases for the letter, 2 samples and 134
secrets. The output is the n cup heights in placement order, and the
pdf accepts any one valid ordering, which is why the letter judges
through validity rather than bytes.

Official sample 1, reprinted byte for byte from the judge data pair
`J-stackingcups/sample-1.in` and `sample-1.ans`: four cups and
favorite height 9. The judges' order drops the 7 cm cup on the ground,
the 3 cm cup inside it onto its floor, the 5 cm cup onto the smaller
one's rim spanning 4 to 9, and the 1 cm cup hidden inside on the 5 cm
cup's floor at 5, the top rim closing the tower at 9:

input:

```
4 9
```

expected output:

```
7 3 5 1
```

Official sample 2, same source: four cups wanting height 100, past the
n^2 = 16 ceiling, so impossible.

input:

```
4 100
```

expected output:

```
impossible
```

Recognition: n at 2e5 cups and h at 4e10 under the 2 second limit rule out both search over orders and any height-indexed table: the achievable set is proved in closed form, 2n-1 through n^2 except the single hole n^2-2, the construction emits the order in one pass, and n at most 5 brute-forces the remainder.

The cue is the exact favorite height, a placement order whose final tower spans exactly h: a characterization question, which heights are achievable at all, answered by an interval-with-one-hole theorem plus a canonical witness. Problem J is the 2025 face of the constructive closed-form characterization family. The constructive closed-form characterization family holds chapter 11 problem U and chapter 12 problem B.

Trying orders is the priced-out alternative, (2e5)! permutations, and even a dynamic program over the values of h needs 4e10 states where the interval theorem answers in one comparison.

The resting law came out
of this wave's judge witnesses rather than the statement's gloss: all
cups share one axis, and a dropped cup stops with its base bottom at
the highest obstacle below it, the maximum over the rim of every
narrower placed cup and the interior floor, base bottom plus 1, of
every wider placed cup it descends into, or the ground. The original
narrowest-floor-only reading, derived from the printed sample story,
agreed on every achievable span yet misplaced cups from n = 4 on, and
sixteen official witnesses reject it while all 136 pass under the
corrected law, so the solvers simulate the corrected one. Achievable
heights are exactly 2n-1 through n^2 except n^2-2, because every cup
contributes 0, 1, or its full height and the only 2 centimeter
reduction from the n^2 stack is tucking the smallest cup inside. The
construction recurses, the largest cup goes on top when h is high
enough, adding 2k-1, or to the bottom when it is not, lifting the rest
by exactly 1, the two ranges overlap from n = 6, and n at most 5
brute-forces permutations in lexicographic order
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf pp. 6-7). The judge runs through a validity checker,
checker:2025-j, which accepts any permutation of the odd heights whose
simulated tower equals h, validated over the 136 official witnesses
plus 183 mutated rejections, with "impossible" still exact.

The worked run: trace the model on sample 1, four cups wanting height 9, the odd heights 1, 3, 5, and 7. The judges' order 7 3 5 1 drops cup 7 on the ground first, base bottom 0 and rim at 7. Cup 3 descends through 7's interior and stops on its floor, the obstacle at 0 + 1 = 1, spanning 1 to 4. Cup 5 meets two obstacles, cup 3's rim at 4 and cup 7's floor at 1, and stops on the higher, spanning 4 to 9. Cup 1 descends into both wider cups and meets cup 3's rim at 4, cup 5's floor at 4 + 1 = 5, and cup 7's floor at 1, stops on the highest at 5, hidden inside cup 5 and spanning 5 to 6. The tower runs from the ground 0 to cup 5's rim 9, exactly h, and the trace ends at the printed answer `7 3 5 1`.

#diagram([cross-section of the sample tower, cup 7 on the ground, cup 3 on its floor, cup 5 on cup 3's rim, cup 1 hidden inside cup 5 on its floor, the spans labeled up to 9], length: 12pt, {
  cdraw.line((0.6, 1.0), (12.4, 1.0), stroke: 0.8pt + luma(60))
  cdraw.content((0.5, 0.5), [ground], size: 6pt, fill: luma(120))
  cdraw.rect((3.0, 1.0), (10.2, 7.3), stroke: luma(60), fill: luma(242))
  cdraw.content((10.7, 4.1), [7], size: 7pt)
  cdraw.rect((5.0, 1.0), (8.2, 3.7), stroke: luma(90), fill: luma(248))
  cdraw.content((8.7, 2.3), [3], size: 7pt)
  cdraw.rect((3.9, 4.0), (9.3, 8.5), stroke: luma(60), fill: rgb("eef3fa"))
  cdraw.content((9.8, 6.2), [5], size: 7pt)
  cdraw.rect((6.1, 5.0), (7.1, 5.9), stroke: luma(90), fill: luma(248))
  cdraw.content((7.6, 5.45), [1], size: 7pt)
  cdraw.line((3.9, 4.0), (9.3, 4.0), stroke: 0.5pt + luma(150))
  cdraw.content((2.2, 4.0), [4], size: 6pt, fill: luma(120))
  cdraw.content((2.2, 1.0), [0], size: 6pt, fill: luma(120))
  cdraw.content((2.2, 5.0), [5], size: 6pt, fill: luma(120))
  cdraw.content((2.2, 8.5), [9], size: 6pt, fill: luma(120))
  cdraw.content((11.6, 7.6), [cup 5's rim closes the tower at 9], size: 6pt, fill: luma(100), anchor: "west")
  cdraw.content((11.6, 5.0), [cup 1 on 5's floor], size: 6pt, fill: luma(120), anchor: "west")
})

#listing("icpc/samples-c/src/Ch13/pJ.c", first: 30, last: 74, caption: [c, two max segment trees, the drop as max of narrower rims and wider floors, the width-n leaf zeroed through index 2n])

The c comment pins a real porting trap: the floor query reads width n's
leaf at tree index 2n, so the per-simulation zeroing must cover it, and
the c self-check catches the stale leaf instantly. Python is the one
port that swaps the segment trees for two max fenwicks, a prefix rim
tree and a reversed suffix floor tree:

#listing("icpc/samples/src/Ch13/PJ.cs", first: 57, last: 83, caption: [c\#, Simulate over the same two trees, stop, top, and the two set operations])

#listing("icpc/samples-go/ch13/pj.go", first: 57, last: 84, caption: [go, the jSim drop loop over its own segment trees])

#listing("icpc/samples-js/src/ch13-pj-stackingcups.mjs", first: 46, last: 65, caption: [javascript, the simulate method, fill(0, 0, 2n + 1) covering the same stale-leaf trap])

#listing("icpc/samples-py/src/Ch13/pj.py", first: 25, last: 61, caption: [python, two fenwick max trees instead, prefix rims against suffix floors, i and i - 1 walking the masks])

#listing("icpc/samples-lua/ch13_pj.lua", first: 52, last: 80, caption: [lua, the drop loop over the year's second segment-tree idiom])

The crafted case is n = 3, h = 6. Brute force in lexicographic order
finds (1, 3, 2): cup 1 sits on the ground, cup 3 rests on its rim
spanning 1 to 6, and cup 2 stops on cup 1's rim hidden inside 3, so
the output is "1 5 3". All six suites pin the same four fixtures, that
one, n = 3 h = 7 hitting the n^2-2 hole for "impossible", the single
cup "1", and n = 2 h = 3 nesting the small cup for "3 1". The emitted
order is re-simulated before printing in every port, and lua's own
assembly of the final order moved to a membership set during the wave,
its worst judge case dropping to half a second.

#diagram([cross-section of the crafted tower, cup 1 on the ground, cup 3 resting on its rim, cup 2 hidden inside 3, the spans labeled up to 6], length: 12pt, {
  cdraw.line((0.6, 1.0), (12.4, 1.0), stroke: 0.8pt + luma(60))
  cdraw.content((0.5, 0.5), [ground], size: 6pt, fill: luma(120))
  cdraw.rect((5.6, 1.0), (6.8, 2.0), stroke: luma(60), fill: luma(240))
  cdraw.content((6.2, 1.5), [1], size: 6.5pt)
  cdraw.rect((4.6, 2.0), (7.8, 5.0), stroke: luma(60), fill: luma(248))
  cdraw.content((9.9, 4.3), [3], size: 6.5pt)
  cdraw.line((4.6, 2.0), (7.8, 2.0), stroke: 0.5pt + luma(150))
  cdraw.rect((5.4, 2.0), (6.9, 3.0), stroke: luma(90), fill: rgb("eef3fa"))
  cdraw.content((6.15, 2.5), [2], size: 6.5pt)
  cdraw.content((8.4, 2.5), [cup 2 rests on cup 1's rim at 1], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((8.3, 2.5), (7.0, 2.5), stroke: luma(120), mark: (end: ">"))
  cdraw.content((8.4, 5.3), [cup 3 spans 1 to 6], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((8.3, 5.0), (7.8, 5.0), stroke: luma(120), mark: (end: ">"))
  cdraw.line((0.9, 1.0), (0.9, 5.0), stroke: 0.5pt + luma(150), mark: (end: ">"))
  cdraw.line((0.75, 1.0), (1.05, 1.0), stroke: 0.5pt + luma(150))
  cdraw.line((0.75, 5.0), (1.05, 5.0), stroke: 0.5pt + luma(150))
  cdraw.content((0.2, 3.0), [6], size: 6.5pt)
})

h and n^2 reach 4e10, int64 in c, c\#, go, and lua, python native, and
javascript's Number is exact below 2^53, so no BigInt is needed.

== problem k, treasure map

Captain Blackbeard's hypsometric map covers a rectangular stretch of
ocean floor, an n by m array of depth marks over an (n-1) by (m-1)
grid of unit squares, and time has left only k of the marks legible.
There is no single natural interpolation across a unit square, so the
mapmaker's rule matters: whichever of the two diagonal triangulations
of a square you interpolate over, the result must come out the same,
and the known region carries no islets, every depth non-negative. The
task decides whether the legible depths extend to a full map obeying
the rule, and if so reports the smallest depth the treasure cell can
carry.

The input is five integers, n, m, k, and the treasure cell's two
coordinates, then k lines of a cell's coordinates and depth. The
problemset pdf bounds n and m at 3e5, k at 3e5 with no duplicated
cells and depths from 0 to 1e9. The limit is 4 seconds, the output is
one integer or impossible, and the judge data carries 55 cases for the
letter, 5 samples and 50 secrets.

Official sample 1, reprinted byte for byte from the judge data pair
`K-treasuremap/sample-1.in` and `sample-1.ans`: a 3 by 3 map with five
legible depths, all tied into one component through row 2 and column
3, so the treasure at (1,1) is the forced same-component sum, r1 + c1
equal to 3, immune to shifting:

input:

```
3 3 5 1 1
1 3 1
3 3 2
2 3 3
2 2 4
2 1 5
```

expected output:

```
3
```

Official sample 4, same source: four legible depths closing a cycle
through rows 1 and 2 and columns 1 and 3, opposite corners summing 8
against 6, and no r_i + c_j map can say both:

input:

```
3 3 4 3 2
2 1 2
2 3 3
1 3 4
1 1 5
```

expected output:

```
impossible
```

Recognition: n and m at 3e5 with k at 3e5 against the 4 second limit: the row-column graph holds at most n + m = 6e5 nodes and k = 3e5 edges, and one breadth-first sweep per component decides feasibility, treasure depth, and shifting all at once, linear work.

The cue is the interpolation rule, whichever diagonal triangulation you interpolate over the result must come out the same: that forces every depth to the form r_i + c_j, pairwise additive constraints with exactly one free value per component, fixed by any known cell and propagated. Problem K is the 2025 face of the one free value per component family. One free value per component is the trick behind chapter 11 problem P and chapter 12 problem G.

Filling the grid square by square is the priced-out alternative: (n-1) × (m-1) runs to 9e10 cells before any consistency check, and a linear program over the same cells pays a solver where six-int arithmetic per edge settles it.

The two interpolations agree on a square exactly
when opposite corners sum equally, which over the whole grid forces
every depth to the form r_i + c_j. Build the bipartite row-column
graph with known cells as edges, one value per component is free and
the rest are forced by breadth-first search, contradictions answering
impossible. Per component the invariant a + b, the minimum row value
plus the minimum column value, survives shifting, the map is feasible
exactly when every component has a + b at least 0, and the treasure is
the fixed sum when its row and column share a component, the shifted
bridge sum when they do not, one side's shift when the other is
unconstrained, else 0, all O(n + m + k)
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 7).

The worked run: trace the model on sample 1, a 3 by 3 map with five legible depths and the treasure at (1,1). The known cells tie everything into one component: column 3 carries (1,3), (3,3), and (2,3), and row 2 reaches (2,2) and (2,1). Seeding the free value r2 = 0 forces c3 = 3 - 0 = 3, c2 = 4 - 0 = 4, and c1 = 5 - 0 = 5, then r1 = 1 - 3 = -2 and r3 = 2 - 3 = -1. The treasure's row and column share the component, so its depth is the fixed sum r1 + c1 = -2 + 5 = 3, immune to any shift, and the trace ends at the printed answer `3`.

#diagram([the sample's row-column graph, the five known cells as edges, the seeded r2 = 0 with the forced values beside their nodes, and the treasure query dashed between r1 and c1], length: 12pt, {
  for i in range(3) {
    cdraw.circle((1.8, 7.2 - i * 1.8), radius: 0.34, fill: luma(240))
    cdraw.content((1.8, 7.2 - i * 1.8), [r#str(i + 1)], size: 6.5pt)
  }
  for j in range(3) {
    cdraw.circle((10.6, 7.2 - j * 1.8), radius: 0.34, fill: luma(240))
    cdraw.content((10.6, 7.2 - j * 1.8), [c#str(j + 1)], size: 6.5pt)
  }
  cdraw.line((2.2, 7.25), (10.2, 5.63), stroke: 1.2pt + luma(60))
  cdraw.line((2.2, 3.65), (10.2, 5.57), stroke: 1.2pt + luma(60))
  cdraw.line((2.2, 5.4), (10.2, 5.6), stroke: 1.2pt + luma(60))
  cdraw.line((2.2, 5.35), (10.2, 7.25), stroke: 1.2pt + luma(60))
  cdraw.line((2.2, 5.3), (10.2, 3.65), stroke: 1.2pt + luma(60))
  cdraw.line((2.2, 7.2), (10.2, 3.6), stroke: 1.4pt + luma(90), dash: "dashed")
  cdraw.content((0.9, 7.2), [-2], size: 6.5pt, fill: luma(100), anchor: "east")
  cdraw.content((0.9, 5.4), [0], size: 6.5pt, fill: luma(100), anchor: "east")
  cdraw.content((0.9, 3.6), [-1], size: 6.5pt, fill: luma(100), anchor: "east")
  cdraw.content((11.5, 7.2), [5], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((11.5, 5.4), [4], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((11.5, 3.6), [3], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((6.2, 6.7), [depth 1], size: 6pt, fill: luma(120))
  cdraw.content((6.2, 4.9), [depths 3, 4, and 5], size: 6pt, fill: luma(120))
  cdraw.content((5.2, 2.4), [treasure: r1 + c1 = -2 + 5 = 3], size: 6.5pt, fill: luma(90))
})

#listing("icpc/samples-c/src/Ch13/pK.c", first: 65, last: 109, caption: [c, the component bfs forcing values edge by edge, min row and min column carried per component])

#listing("icpc/samples/src/Ch13/PK.cs", first: 116, last: 132, caption: [c\#, the four treasure cases, same component, bridge, one-sided shift, free])

#listing("icpc/samples-go/ch13/pk.go", first: 60, last: 107, caption: [go, the seeded bfs with the want = depth - base forcing rule])

#listing("icpc/samples-js/src/ch13-pk-treasuremap.mjs", first: 49, last: 97, caption: [javascript, the bfs and the treasure dispatch, values in Float64Array])

#listing("icpc/samples-py/src/Ch13/pk.py", first: 34, last: 75, caption: [python, the bfs with minr and minc per component, the feasibility verdict at the end])

#listing("icpc/samples-lua/ch13_pk.lua", first: 69, last: 114, caption: [lua, the while-loop bfs, 4e18 sentinels on the unused side])

The crafted map is 3 rows by 4 columns with four known depths. They
split into two components, {row 1, column 1} and {rows 2 and 3,
columns 2 and 4}, with a + b equal to 3 and 4, both non-negative, so
the map is feasible. The treasure sits at row 2, column 1, one side in
each component, and the bridge gives r2 - a2 plus c1 - b1 = 2 + 0 = 2,
with an explicit witness shifting component 2 to rows 2 and 0. Every
suite pins answer 2, and every suite adds the unit square whose cycle
contradicts, 1 + 2 against 3 + 4, for "impossible", with c also
carrying a same-component treasure case as its second fixture. Counts
per language: 3, 2, 2, 2, 2, 3.

#diagram([rows and columns as the two banks of a bipartite graph, the two components by line weight, the treasure cell a dashed bridge between them], length: 12pt, {
  for i in range(3) {
    cdraw.circle((1.6, 6.8 - i * 1.5), radius: 0.32, fill: luma(240))
    cdraw.content((1.6, 6.8 - i * 1.5), [r#str(i + 1)], size: 6pt)
  }
  let cy = (7.3, 5.7, 4.1, 2.5)
  for j in range(4) {
    cdraw.circle((12.0, cy.at(j)), radius: 0.32, fill: luma(240))
    cdraw.content((12.0, cy.at(j)), [c#str(j + 1)], size: 6pt)
  }
  cdraw.line((2.0, 6.85), (11.6, 7.28), stroke: 1.4pt + luma(60))
  cdraw.line((2.0, 5.35), (11.6, 5.73), stroke: 0.9pt + luma(150))
  cdraw.line((2.0, 3.85), (11.6, 5.67), stroke: 0.9pt + luma(150))
  cdraw.line((2.0, 3.85), (11.6, 2.55), stroke: 0.9pt + luma(150))
  cdraw.line((2.0, 5.35), (11.6, 7.28), stroke: 1.2pt + luma(90), dash: "dashed")
  cdraw.content((4.4, 6.45), [treasure: r2 to c1], size: 6pt, fill: luma(90))
  cdraw.content((3.2, 8.2), [component 1: r1 with c1], size: 6pt, fill: luma(120))
  cdraw.content((10.6, 8.2), [component 2: r2, r3 with c2, c4], size: 6pt, fill: luma(120))
  cdraw.line((2.6, 1.2), (3.4, 1.2), stroke: 1.4pt + luma(60))
  cdraw.content((3.6, 1.2), [component 1 edge], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((7.4, 1.2), (8.2, 1.2), stroke: 0.9pt + luma(150))
  cdraw.content((8.4, 1.2), [component 2 edges], size: 6pt, fill: luma(120), anchor: "west")
  cdraw.line((12.2, 1.2), (13.0, 1.2), stroke: 1.2pt + luma(90), dash: "dashed")
  cdraw.content((13.2, 1.2), [the treasure query], size: 6pt, fill: luma(120), anchor: "west")
})

Forced values drift up to k times 1e9, about 3e14, so c, c\#, and go
carry int64, lua's integers are 64-bit, python is native, and
javascript keeps the forced values in a Float64Array, exact because
3e14 sits far below 2^53.

== problem l, walking on sunshine

The walk runs from the contest point to the awards point across a
plane dotted with n shaded rectangles, axis-aligned and pairwise
disjoint, neither touching nor crossing. Any movement with a southward
component hurts, adding its length to the hurting distance, unless it
happens inside shade, while horizontal movement and northward movement
are always free, and the task is the smallest total hurting distance.

The input is n and the four walk coordinates, contest then awards,
then n rectangle lines of x1, y1, x2, y2. The problemset pdf bounds
n at 1e5, every coordinate and both walk endpoints within +-1e6, and
the rectangles non-touching and non-intersecting. The limit is 2
seconds with a 1e-7 absolute or relative tolerance, the output is one
line, and the judge data carries 59 cases for the letter, 6 samples
and 53 secrets, the sample answers printing one decimal.

Official sample 1, reprinted byte for byte from the judge data pair
`L-walkingonsunshine/sample-1.in` and `sample-1.ans`: contest at
(1,7), awards at (5,1), a descent of 6 past two rectangles whose
y-bands contribute the low sliver of [6,9] clipped to 6 through 7 and
the whole of [3,5], 3 of the descent in shade and 3 hurting:

input:

```
2 1 7 5 1
3 6 5 9
2 3 6 5
```

expected output:

```
3.0
```

Recognition: n at 1e5 rectangles under the 2 second limit: sorting the y-projections and merging costs n log n ≈ 1.7e6 comparisons in one pass, and the arithmetic on the walk's own span is constant, so the budget is trivial.

The cue is the asymmetry sentence, horizontal movement and northward movement are always free: x never matters, the walk collapses onto the y-axis, and the answer is one descent minus one union of sorted intervals, a single sweep over a sorted axis. Problem L is the 2025 face of the event sweep over a sorted axis family. The same event sweep over a sorted axis cue drives chapter 09 problem A, chapter 09 problem H, chapter 10 problem D, and chapter 10 problem J.

Building the rectangle geometry is the priced-out alternative: pairwise checks over the rectangles cost n^2 = 1e10 crossings, and any shortest-path model over the free space pays far more than the one merge pass the collapse licenses.

It is a trick question: x never matters because horizontal
movement is free, so the walk collapses onto the y-axis, total
southward travel is exactly max(0, yc - ya), and shade at height y is
any rectangle whose y-interval covers y, entered by walking
horizontally into its x-range first. The answer is that descent minus
the length of the union of the rectangle y-projections clipped to the
walk's y range, a sort by lower bound and one merge pass, O(n log n)
(#link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[statement],
solutions.pdf p. 8). Every port is the same eight statements, so the
listings show the whole algorithm each time and the comparison is one
of spelling.

The worked run: trace the model on sample 1. The walk runs from (1,7) to (5,1), so the total southward travel is 7 - 1 = 6 and the relevant y-range is [1,7]. The first rectangle's y-band [6,9] clips to [6,7], length 1, the second's [3,5] lies wholly inside, length 2, and the two never touch, so the sorted merge holds them apart and the union length is 3. The hurting distance is 6 - 3 = 3, and the trace ends at the printed answer `3.0`.

#diagram([the y-axis track, contest at 7 and awards at 1, the band 6 to 9 clipped at the contest's level, the band 3 to 5 whole, and the two unshaded gaps summing to 3], length: 12pt, {
  cdraw.line((2.0, 0.8), (2.0, 9.6), stroke: 0.8pt + luma(60))
  cdraw.content((2.5, 9.6), [contest, y = 7], size: 6.5pt, fill: luma(120), anchor: "west")
  cdraw.content((2.5, 0.8), [awards, y = 1], size: 6.5pt, fill: luma(120), anchor: "west")
  cdraw.line((1.7, 7.0), (2.3, 7.0), stroke: 1.4pt + luma(60))
  cdraw.line((1.7, 1.0), (2.3, 1.0), stroke: 1.4pt + luma(60))
  cdraw.rect((3.4, 6.0), (8.4, 9.0), fill: luma(230), stroke: luma(150))
  cdraw.rect((3.4, 7.0), (8.4, 9.0), fill: luma(245), stroke: luma(180))
  cdraw.content((5.9, 7.9), [clipped away], size: 6pt, fill: luma(120))
  cdraw.content((5.9, 6.5), [6 to 7], size: 6pt)
  cdraw.rect((3.4, 3.0), (8.4, 5.0), fill: luma(230), stroke: luma(150))
  cdraw.content((5.9, 4.0), [3 to 5], size: 6pt)
  cdraw.line((1.6, 5.0), (2.4, 5.0), stroke: 1.6pt + luma(30))
  cdraw.line((1.6, 6.0), (2.4, 6.0), stroke: 1.6pt + luma(30))
  cdraw.line((1.6, 1.0), (2.4, 1.0), stroke: 1.6pt + luma(30))
  cdraw.line((1.6, 3.0), (2.4, 3.0), stroke: 1.6pt + luma(30))
  cdraw.content((0.9, 5.5), [1], size: 6.5pt)
  cdraw.content((0.9, 2.0), [2], size: 6.5pt)
  cdraw.content((5.9, 1.6), [descent 6, shade 3, hurting distance 3], size: 6.5pt, fill: luma(100))
})

#listing("icpc/samples-c/src/Ch13/pL.c", first: 59, last: 82, caption: [c, drop, merge, clip, subtract, print %.1f])

#listing("icpc/samples/src/Ch13/PL.cs", first: 35, last: 70, caption: [c\#, the merge over an index sort, Clip as a two-line helper])

#listing("icpc/samples-go/ch13/pl.go", first: 33, last: 71, caption: [go, the sort.Slice comparator and the clip closure])

#listing("icpc/samples-js/src/ch13-pl-walkingonsunshine.mjs", first: 23, last: 43, caption: [javascript, clip as an arrow function, toFixed(1) at the end])

#listing("icpc/samples-py/src/Ch13/pl.py", first: 25, last: 46, caption: [python, tuple sort, the merge loop, the f-string with .1f])

#listing("icpc/samples-lua/ch13_pl.lua", first: 54, last: 84, caption: [lua, table.sort with a comparator, string.format("%.1f")])

The crafted walk descends from y = 8 to y = 2 past two rectangles
whose y-intervals clip to the ranges 6 through 8 and 3 through 5, union
length 4, so the
hurting distance is 6 - 4 = 2 and the answer prints "2.0". Every
suite pins that plus the northbound no-shade case "0.0". The solvers
keep %.1f everywhere while the judge comparison runs in float mode:
the official sample answers print one decimal but the secret answers
print bare integers, so an exact byte diff would fail more than half
the cases, and compare.json carries 2025/L as float, exact on integral
values either way.

#diagram([the y-axis as a vertical track, contest and awards marked, the two shaded bands crossing it, and the unshaded gaps summing to 2], length: 12pt, {
  cdraw.line((2.0, 0.8), (2.0, 8.6), stroke: 0.8pt + luma(60))
  cdraw.content((2.5, 8.6), [contest, y = 8], size: 6.5pt, fill: luma(120), anchor: "west")
  cdraw.content((2.5, 0.8), [awards, y = 2], size: 6.5pt, fill: luma(120), anchor: "west")
  cdraw.line((1.7, 8.0), (2.3, 8.0), stroke: 1.4pt + luma(60))
  cdraw.line((1.7, 2.0), (2.3, 2.0), stroke: 1.4pt + luma(60))
  cdraw.rect((3.4, 6.0), (8.4, 8.0), fill: luma(230), stroke: luma(150))
  cdraw.content((5.9, 7.0), [shade 6 to 8], size: 6pt)
  cdraw.rect((3.4, 3.0), (8.4, 5.0), fill: luma(230), stroke: luma(150))
  cdraw.content((5.9, 4.0), [shade 3 to 5], size: 6pt)
  cdraw.line((1.6, 6.0), (2.4, 6.0), stroke: 1.6pt + luma(30))
  cdraw.line((1.6, 5.0), (2.4, 5.0), stroke: 1.6pt + luma(30))
  cdraw.line((1.6, 3.0), (2.4, 3.0), stroke: 1.6pt + luma(30))
  cdraw.line((1.6, 2.0), (2.4, 2.0), stroke: 1.6pt + luma(30))
  cdraw.content((0.9, 5.5), [1], size: 6.5pt)
  cdraw.content((0.9, 2.5), [1], size: 6.5pt)
  cdraw.content((5.9, 1.6), [descent 6, shade 4, hurting distance 2], size: 6.5pt, fill: luma(100))
})

Every coordinate is an integer and the answer is an integer printed
with one decimal, so the six languages differ only in print spelling.

== across the six languages

The 2025 set pushes the six ports in different directions, and the
closing table lines them up. Every language ships all twelve solvers.
Judge verdicts: all twelve problems ran 874 official cases each in
c, c\#, go, javascript, python, and lua, all green, B judging through
its validity checker and I through the interactive driver, both
closing the phase 4 ledger, and J's judge runs through the validity
checker described in its section.

#table(
  columns: (auto, 1fr, auto, 1.3fr),
  inset: 4pt,
  [language], [2025 solver shape], [self-checks], [notes],
  [c], [12 solvers in samples-c/src/Ch13 plus ch13_match.h, ch13_wheels.h, ch13_moat.h, ch13_rollback.h], [30 CHECK assertions], [long double lengths in G, function-pointer queries in I],
  [c\#], [12 solvers in samples/src/Ch13 plus Moat.cs, tests in samples/tests/Ch13], [34 facts], [inlines the B matcher and the I simulator instead of helpers],
  [go], [12 solvers in samples-go/ch13 plus match.go, moat.go, wheels.go, cmd/ch13 dispatch], [28 table cases and one exhaustive sweep], [the only brute-force equivalence test, problem A over every n up to 6],
  [javascript], [12 solvers in samples-js/src plus ch13-match.mjs, ch13-moat.mjs, ch13-wheels.mjs], [36 assertions], [BigInt only where m reaches 1e18, in H],
  [python], [12 solvers in samples-py/src/Ch13 plus ch13_match.py, ch13_rollback.py, ch13_wheels.py], [27 checks], [golden section in C, fenwicks in J, sieve cut to 1e6 in H],
  [lua], [12 solvers in samples-lua plus ch13_match.lua, ch13_moat.lua, ch13_rollback.lua, ch13_wheels.lua], [30 named checks], [engine split keeps every file under 400 lines, incremental digit counts in H],
)

sources: ICPC Foundation, icpc.global and worldfinals.icpc.global, the
2025 problemset at #link("https://worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf")[worldfinals.icpc.global/problems/2025/finals/problems/problemset.pdf]
and the official solutions at #link("https://icpc.global/worldfinals/problems/2025-ICPC-World-Finals/2025-ICPC-Solutions.pdf")[icpc.global/worldfinals/problems/2025-ICPC-World-Finals/2025-ICPC-Solutions.pdf],
both accessed 2026-09-14 and cached under `ref/icpc/` with sha256
digests in `ref/icpc/INDEX.md`. The solutions pdf is the algorithm and
complexity reference for every walkthrough above. The 2025 set
postdates training data, so every statement fact, sample derivation,
and judge behavior in this chapter comes from the cached pdfs and the
local judge runs, never from memory. Judge data under
`ref/icpc/2025/data/` is local-only with its secret cases never quoted,
and the official sample pairs reprinted in the sections above are
byte-for-byte its sample-N.in and sample-N.ans files, attributed per
section. The data verifies
the solvers through `ref/icpc/verify-data.ps1`, 874 official inputs,
874 judged verdicts per language over all twelve problems in c, c\#,
go, javascript, python, and lua, with B carrying no answers at all and
judging through its checker, I interactive through the driver, and J
checked by validity. The committed
self-check suites measured for this chapter are 30 CHECK assertions in
the c files, 34 facts in the c\# tests, 28 table-driven go cases plus
the exhaustive A sweep, 36 assertions in the javascript tests, 27
python checks, and 30 named lua checks, 185 checks in total, each
counted in its own suite's unit.
