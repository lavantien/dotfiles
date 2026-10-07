// chapter 42: approximation algorithms, manifest id approximation
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= approximation algorithms

An approximation algorithm is a contract with 2 clauses: return a
feasible answer, and prove how far from the optimum it can sit. This
chapter treats the contract as code. Every test in every tree asserts
the 2 halves separately, the witness is checked against the problem's
own feasibility rule and its value is divided into an exact optimum
computed inside the same test, by brute force or by dynamic
programming at teaching sizes. The chapter walks the proven ratios in
order of machinery: the matching cover at 2, greedy set cover at
ln n + 1, the double tree and christofides for metric tsp at 2 and
1.5, the knapsack ladder from a greedy 1/2 through a ptas to a full
fptas, the bin packing heuristics, and the single-flip discipline of
#xref-to("dsa", "metaheuristics") coming back with a guarantee
attached. Two prose sections close it, the barriers that make some
ratios impossible and the decision table that picks the right
surrender for a given instance size.

== np-hardness as an engineering boundary

Chapter 18 named the wall: some problems carry no known polynomial
exact algorithm, and the theory says that is expected. The exact
lanes of the corpus all pay exponentially for their certainty, the
mask tables of chapter 17 and #xref-to("dsa", "advdp") grow as
2^n x n, the permutation oracle of the tsp fixtures walks (n - 1)!
tours, and the branch and bound of #xref-to("dsa", "pruning") prunes
an exponential tree with no word on when it stops. Past a few dozen
vertices the honest question changes from what the best answer is to
what can be proven about the answer inside the time left. That
question has an engineering answer, and it starts with the exact
optimum at small sizes, because a ratio with nothing to divide is
just a number.

The dry run: the fixtures are the 2 exact lanes whose optima every
ratio in this chapter divides, the 3-disjoint-edge vertex cover and
the capacity 18 knapsack, asserted by all 6 suites with the oracles
built in-test.

+ The cover lane holds nodes a through f with edges (a, b), (c, d),
  (e, f). Vertex subsets arrive in size order, and at k = 3 the
  subset a, c, e touches every edge, so the brute force answers 3.
+ Nothing smaller works: k = 2 covers at most 2 disjoint edges, the
  third edge stands uncovered, and the empty set misses everything.
+ The knapsack lane holds 10 items against capacity 18. The dp table
  fills by capacity descending and closes at 1300, items 5 and 8,
  weights 8 + 10, values 600 + 700.
+ The mask enumeration over all 1024 subsets agrees at 1300, the
  same oracle written the slow way.
+ Every one of these oracles is exponential in something: 64 vertex
  subsets, 1024 masks, and the 5040 tours of the 8 city fixture in
  section 5, which is exactly why they live in the test and not in
  the algorithm under test.

The oracles pin the denominators, cover 3 and knapsack 1300, and the
listings below build the cover lane in 7 languages.

#listing("dsa/samples-c/src/Ch42/ratio.c", first: 35, last: 61, caption: [c, the 3 disjoint edges, the cover test, subsets in size order])
#listing("dsa/samples-go/ch42/ratio.go", first: 17, last: 42, caption: [go, the mask oracle, k ascending, ones count filtering each size])
#listing("dsa/samples-java/src/Ch42/Ratio.java", first: 35, last: 62, caption: [java, the 3 disjoint edges, the cover test, subsets in size order])
#listing("dsa/samples/src/Ch42/Ratio.cs", first: 56, last: 80, caption: [c\#, the subset search, size then lexicographic, first cover wins])
#listing("dsa/samples-js/src/ch42-ratio.mjs", first: 10, last: 35, caption: [javascript, the recursive subset walk with the cover test inside])
#listing("dsa/samples-py/src/Ch42/ratio.py", first: 32, last: 53, caption: [python, combinations as the oracle, the pinned cover 3 beside it])
#listing("dsa/samples-lua/ch42_ratio.lua", first: 11, last: 40, caption: [lua, the same combinations recursion over 1-based nodes])

The same 2 numbers return in every section. The matching cover of
section 3 doubles the 3, the greedy knapsack of section 7 lands 10
under the 1300, and the fptas of section 8 closes the 10 exactly.
One ratio file serves this section and the next, the oracle half
above and the contract half below.

== the approximation ratio

A rho-approximation for a minimization problem returns a feasible
answer of value at most rho x opt, and for a maximization problem a
feasible answer of value at least opt / rho, with rho at least 1 in
both directions. The ratio is a worst case contract over every
instance, and an instance family is tight when the algorithm sits at
rho x opt on it forever, which is the difference between a bound that
holds and a bound that is the whole story. In the tests the ratio is
never computed as a division: the minimization check reads alg less
than or equal rho x opt and the maximization check reads
alg x rho greater than or equal opt, cross-multiplied integers, so
no floating point value ever sits inside an assert.

The dry run: the fixtures are the tight family and the near miss,
asserted by all 6 suites as feasibility first and ratio second.

+ On the 3 disjoint edges the greedy maximal matching takes all 3
  edges, the cover is both endpoints of each, 6 nodes, and the oracle
  says 3. Feasibility holds, every edge covered, and 6 = 2 x 3, the
  ratio is exactly 2, tight.
+ On the knapsack the density greedy of section 7 fills items for
  1290 against the oracle 1300. Feasibility holds, the fill weighs
  exactly the capacity 18, and 2 x 1290 exceeds 1300, so the greedy
  clears its rho = 2 contract with room.
+ The maximization check for that lane reads value x 2 greater than
  or equal opt, the cross-multiplied form, and the better of the fill
  and the best single item is what the guarantee needs: the fill 1290
  already beats the best single item 700.
+ Tightness is a property of the family, never of one instance: k
  disjoint edges push the matching cover to 2k against an optimum of
  k at every k.

#diagram([the two ratio shapes: the cover witness sitting on exactly twice its optimum, the knapsack greedy one step under its optimum], length: 13pt, {
  // left: minimization, opt 3 against the matching witness 6
  let py = v => 1.1 + v * 0.62
  cdraw.content((4.0, 8.7), [minimization: alg \<= rho x opt], size: 6.5pt)
  cdraw.rect((2.0, 1.1), (3.4, py(3)), fill: luma(235), radius: 0.02)
  cdraw.content((2.7, py(3) + 0.34), [3], size: 6pt)
  cdraw.content((2.7, 0.62), [opt], size: 6pt)
  cdraw.rect((4.4, 1.1), (5.8, py(6)), fill: luma(205), radius: 0.02)
  cdraw.content((5.1, py(6) + 0.34), [6], size: 6pt)
  cdraw.content((5.1, 0.62), [witness], size: 6pt)
  cdraw.line((1.9, py(6)), (7.1, py(6)), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((4.0, 6.3), [6 = 2 x 3, tight], size: 6pt)
  cdraw.content((4.0, 7.9), [3 disjoint edges], size: 6pt)
  // right: maximization, opt 1300 against the greedy 1290
  let qy = v => 1.1 + (v - 1280) * 0.33
  cdraw.content((14.3, 8.7), [maximization: alg x rho \>= opt], size: 6.5pt)
  cdraw.line((10.4, qy(1300)), (18.4, qy(1300)), stroke: luma(100))
  cdraw.content((14.4, qy(1300) + 0.34), [opt 1300, the dp oracle], size: 6pt)
  cdraw.rect((12.6, 1.1), (14.0, qy(1290)), fill: luma(205), radius: 0.02)
  cdraw.content((13.3, qy(1290) + 0.34), [1290], size: 6pt)
  cdraw.content((13.3, 0.62), [greedy], size: 6pt)
  cdraw.rect((15.4, 1.1), (16.8, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.1, 2.4 + 0.34), [700], size: 6pt)
  cdraw.content((16.1, 0.62), [best item], size: 6pt)
  cdraw.content((16.1, 1.9), [off scale], size: 5.5pt)
  cdraw.content((14.4, 6.8), [2 x 1290 \>= 1300], size: 6pt)
  cdraw.content((14.4, 6.1), [the fill is the better witness], size: 6pt)
  cdraw.content((14.4, 5.4), [no float inside an assert], size: 6pt)
})

The 6 over 3 and the 1290 under 1300 are the 2 pinned shapes, and
the listings below carry the exact lanes and the contract checks in
7 languages.

#listing("dsa/samples-c/src/Ch42/ratio.c", first: 63, last: 90, caption: [c, the matching cover, feasibility, then 6 against 2 x 3 exactly])
#listing("dsa/samples-go/ch42/ratio.go", first: 44, last: 56, caption: [go, the dp knapsack lane, 1300 in 13 lines])
#listing("dsa/samples-java/src/Ch42/Ratio.java", first: 63, last: 95, caption: [java, the matching cover, feasibility, then 6 against 2 x 3 exactly])
#listing("dsa/samples/src/Ch42/Ratio.cs", first: 27, last: 54, caption: [c\#, the mask knapsack oracle, withinMin, the cross-multiplied withinMax])
#listing("dsa/samples-js/src/ch42-ratio.mjs", first: 37, last: 61, caption: [javascript, the mask oracle with the 2 contract predicates])
#listing("dsa/samples-py/src/Ch42/ratio.py", first: 55, last: 79, caption: [python, dp and mask oracles side by side, both landing 1300])
#listing("dsa/samples-lua/ch42_ratio.lua", first: 42, last: 83, caption: [lua, the dp optimum then the density greedy at 1290, cross-multiplied])

The triangle already says something kind: on 3 nodes wired as a
cycle the matching cover is optimal, the ratio is 1, and the reason
is structural, a matching in a triangle never exceeds one edge. The
next section collects the whole fixture family and separates the
instances where the cover is lucky from the family where it is
exactly as bad as the theorem allows.

== vertex cover by maximal matching

Scan the edges in input order, take an edge when both endpoints are
still unmatched, and put both endpoints into the cover. The taken
edges form a maximal matching, maximal in the sense that no remaining
edge can extend it, and the cover is feasible exactly because of
that: an uncovered edge would have 2 free endpoints and the scan
would have taken it. The cost argument counts. Any vertex cover must
touch every edge of a matching, and matching edges share no
endpoints, so the optimum is at least the matching size, and the
returned cover is exactly 2 matching edges' worth of vertices, 2
per edge, hence at most twice the optimum.

The dry run: the fixtures are the 4 pinned graphs, asserted by all 6
suites with feasibility, the brute oracle, and the ratio as separate
checks.

+ 3 disjoint edges: the matching takes all 3, the cover is 6, the
  oracle says 3, ratio exactly 2, the tight family.
+ The triangle a, b, c: the matching takes the first edge only, the
  cover a, b has size 2, the oracle says 2, ratio 1. A matching in a
  triangle never exceeds one edge, every 2 of the 3 nodes cover it.
+ The path a, b, c, d with the middle edge first, (b, c), (a, b),
  (c, d): the greedy takes the middle edge, both endpoints now
  matched, and stops at 1 edge. The cover b, c has size 2 and equals
  the optimum, ratio 1, while a maximum matching of the same path
  holds 2 edges. Maximal is not maximum.
+ The same path in input order, (a, b), (b, c), (c, d): the greedy
  takes a, b then c, d, 2 edges, the cover is all 4 nodes against an
  optimum of 2, ratio 2 again. Edge order alone doubled the answer.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*fixture*], [*matching*], [*cover*], [*opt*], [*ratio*]),
  [3 disjoint edges], [3], [6], [3], [2, tight],
  [triangle], [1], [2], [2], [1],
  [path, middle first], [1], [2], [2], [1],
  [path, input order], [2], [4], [2], [2],
)

#diagram([the matching cover on the 2 tight shapes against the lucky ones: disjoint edges taking every node, the middle-first path stopping at 1 edge, the same path in input order taking all 4], length: 13pt, {
  // panel a: 3 disjoint edges, every endpoint in the cover
  cdraw.content((6.4, 8.7), [disjoint edges: cover 6, opt 3], size: 6.5pt)
  let ea = ((1.6, 7.6, 3.7, 7.6, [a], [b]), (5.6, 7.6, 7.7, 7.6, [c], [d]), (9.6, 7.6, 11.7, 7.6, [e], [f]))
  for e in ea {
    let (x1, y, x2, y2, la, lb) = e
    cdraw.line((x1, y), (x2, y2), stroke: 1.2pt + luma(30))
    cdraw.circle((x1, y), radius: 0.3, fill: luma(205), stroke: luma(120))
    cdraw.content((x1, y), la, size: 6.5pt)
    cdraw.circle((x2, y2), radius: 0.3, fill: luma(205), stroke: luma(120))
    cdraw.content((x2, y2), lb, size: 6.5pt)
  }
  cdraw.content((6.4, 6.7), [every node lands in the cover], size: 6pt)
  // panel b: path, middle edge first
  cdraw.content((13.4, 5.6), [middle first: maximal 1 edge], size: 6.5pt)
  let pb = ((10.0, 4.4, [a], false), (12.1, 4.4, [b], true), (14.2, 4.4, [c], true), (16.3, 4.4, [d], false))
  for (x, y, lab, hot) in pb {
    cdraw.circle((x, y), radius: 0.3, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), lab, size: 6.5pt)
  }
  cdraw.line((10.3, 4.4), (11.8, 4.4), stroke: luma(180))
  cdraw.line((12.1, 4.4), (13.9, 4.4), stroke: 1.2pt + luma(30))
  cdraw.line((14.5, 4.4), (16.0, 4.4), stroke: luma(180))
  cdraw.content((13.4, 3.5), [cover b, c = opt 2, max matching 2], size: 6pt)
  // panel c: the same path in input order
  cdraw.content((13.4, 2.3), [input order: cover 4, opt 2], size: 6.5pt)
  let pc = ((10.0, 1.1, [a], true), (12.1, 1.1, [b], true), (14.2, 1.1, [c], true), (16.3, 1.1, [d], true))
  for (x, y, lab, hot) in pc {
    cdraw.circle((x, y), radius: 0.3, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), lab, size: 6.5pt)
  }
  cdraw.line((10.3, 1.1), (11.8, 1.1), stroke: 1.2pt + luma(30))
  cdraw.line((12.4, 1.1), (13.9, 1.1), stroke: luma(180))
  cdraw.line((14.5, 1.1), (16.0, 1.1), stroke: 1.2pt + luma(30))
  cdraw.content((6.4, 5.4), [maximal is a scan property, maximum is the optimum], size: 6pt)
  cdraw.content((6.4, 4.5), [the order alone moves the same path from 1 to 2], size: 6pt)
})

The table and the figure agree with every suite, and the listings
below run the scan in 7 languages.

#listing("dsa/samples-c/src/Ch42/vc.c", first: 68, last: 90, caption: [c, the scan over the 4 pinned cases, feasibility, oracle, ratio])
#listing("dsa/samples-go/ch42/vc.go", first: 3, last: 21, caption: [go, the whole engine, cover as a bool slice, matched edges beside it])
#listing("dsa/samples-java/src/Ch42/Vc.java", first: 66, last: 90, caption: [java, the scan over the 4 pinned cases, feasibility, oracle, ratio])
#listing("dsa/samples/src/Ch42/Vc.cs", first: 14, last: 34, caption: [c\#, the greedy maximal matching returning cover and matching])
#listing("dsa/samples-js/src/ch42-vc.mjs", first: 8, last: 28, caption: [javascript, the scan and the cover test, first-fit edge order])
#listing("dsa/samples-py/src/Ch42/vc.py", first: 18, last: 41, caption: [python, the matching, the cover test, the combinations oracle])
#listing("dsa/samples-lua/ch42_vc.lua", first: 15, last: 49, caption: [lua, the scan and the brute oracle, plus the maximum-matching contrast])

The correction worth recording: the 2 bound is not tight on disjoint
triangles, there the ratio is 1 because a triangle caps its own
matching at one edge and 2 endpoints cover it. The tight families are
k disjoint edges and the in-order path, both shown above, and the
second one matters more than the first because it needs only 4 nodes
and an unlucky order. The maximum matching counterweight is its own
lane in the python and lua suites, the middle-first path pinning
maximal 1 against maximum 2 there, while the other 4 trees name the
contrast and pin the maximal side alone. The same word pair returns
in section 10 where the locally best partition is not the best
partition.

== set cover by greedy ln n

The ground set has 15 elements, the family has 6 sets, and greedy
takes the set covering the most uncovered ground at every step, ties
to the earliest set in input order. The pinned family is built to
make the harmonic bound visible: a chain G1 through G4 of shrinking
sets, 8, 4, 2, 1 elements, eats the ground from the front while 2
wide sets A and B wait behind it, and A with B cover everything in 2
picks.

The dry run: the fixture is the telescoping family, asserted by all
6 suites with the per-step coverage table, the union of the picks as
feasibility, and the brute-force optimum over family subsets.

+ Step 1, 15 uncovered: G1 covers 8, G2 4, G3 2, G4 1, A 8, B 7. G1
  and A tie at 8 and input order gives G1 the pick.
+ Step 2, 7 uncovered: G2 covers 4, A 3, B 4, the rest less. G2 and
  B tie at 4 and G2 wins the same way.
+ Step 3, 3 uncovered: G3 covers 2, B 2, A 1. The tie goes to G3.
+ Step 4, 1 uncovered: G4 covers 1, A 1. The tie goes to G4, the
  chain is complete, 4 sets.
+ The oracle walks family subsets in size order and answers 2, the
  pair A and B, whose union is the whole ground. The union of the 4
  greedy picks is also the whole ground, feasibility holds, and 4 is
  exactly 2 x 2, ratio 2 at n = 15.

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*step*], [*left*], [*G1*], [*G2*], [*G3*], [*G4*], [*A*], [*B*], [*pick*]),
  [1], [15], [8], [4], [2], [1], [8], [7], [G1 over A, tie],
  [2], [7], [0], [4], [2], [1], [3], [4], [G2 over B, tie],
  [3], [3], [0], [0], [2], [1], [1], [2], [G3 over B, tie],
  [4], [1], [0], [0], [0], [1], [1], [0], [G4 over A, tie],
)

#callout("pitfall", "the tie break is part of the algorithm", [
  Every tie in the table above resolves by input order, and the
  pinned chain exists only because G1 arrives before A. A stable
  ordering is not a cosmetic choice here: an unstable sort in the
  family scan moves the first pick to A, the second to B, and greedy
  answers 2 on the instance built to cost it 4. The tests pin the
  whole pick sequence, the count alone would let a moved tie pass,
  and the full pin fails loudly in all 6 trees at once.
])

#diagram([the greedy telescoping walk over the 15 element ground, one row per step, the newly covered cells shaded, the two waiting 8-sets covering everything in 2 picks below], length: 13pt, {
  let cx = e => 1.8 + (e - 1) * 0.78
  let cell = (e, y, kind) => {
    let fill = if kind == 0 { luma(252) } else if kind == 1 { luma(205) } else { luma(228) }
    cdraw.rect((cx(e), y), (cx(e) + 0.7, y + 0.62), fill: fill, stroke: if kind == 0 { luma(200) }, radius: 0.02)
  }
  // rows: kind 1 newly covered this step, 2 covered earlier, 0 open
  let rows = (
    (7.9, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, [15 left, G1 takes 8]),
    (6.7, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, [7 left, G2 takes 4]),
    (5.5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, [3 left, G3 takes 2]),
    (4.3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, [1 left, G4 takes 1]),
  )
  for row in rows {
    let (y, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, lab) = row
    let marks = (p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15)
    for (k, m) in marks.enumerate() {
      cell(k + 1, y, m)
    }
    cdraw.content((16.2, y + 0.31), lab, size: 6pt)
  }
  // the optimum row: A owns 1-5, 9, 10, 15, B owns the rest
  let owns = (1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 2, 2, 2, 2, 1)
  for (k, o) in owns.enumerate() {
    cell(k + 1, 2.9, if o == 1 { 1 } else { 2 })
  }
  cdraw.content((16.2, 2.4), [opt: A and B, 2 sets], size: 6pt)
  cdraw.content((7.4, 2.2), [2 sets where greedy spent 4], size: 6pt)
  cdraw.content((7.4, 1.4), [the chain halves the remainder], size: 6pt)
  cdraw.content((7.4, 0.6), [ratio 2 at n = 15, ln n + 1 above at 3.7], size: 6pt)
})

The 4 against 2 is the pinned landing, and the listings below run
the greedy loop and the subset oracle in 7 languages.

#listing("dsa/samples-c/src/Ch42/setcover.c", first: 82, last: 104, caption: [c, the greedy loop over bitmasks, the pinned coverages 8, 4, 2, 1])
#listing("dsa/samples-go/ch42/setcover.go", first: 24, last: 42, caption: [go, coverage counts as popcounts over the uncovered mask])
#listing("dsa/samples-java/src/Ch42/Setcover.java", first: 76, last: 99, caption: [java, the greedy loop over bitmasks, the pinned coverages 8, 4, 2, 1])
#listing("dsa/samples/src/Ch42/Setcover.cs", first: 13, last: 56, caption: [c\#, greedy with the per-step coverage table recorded beside the picks])
#listing("dsa/samples-js/src/ch42-setcover.mjs", first: 8, last: 33, caption: [javascript, the same greedy, steps and counts returned together])
#listing("dsa/samples-py/src/Ch42/setcover.py", first: 29, last: 54, caption: [python, the greedy and the combinations oracle landing 4 against 2])
#listing("dsa/samples-lua/ch42_setcover.lua", first: 26, last: 48, caption: [lua, the same loop, ties to the earliest set in family order])

Why the bound has a logarithm in it: after any greedy pick the
uncovered count r shrinks by at least r / opt, because the opt
solution's sets partition the remaining r elements among opt sets
and the widest of them covers at least r / opt, and greedy takes at
least the widest. Shrinking by that factor for k steps leaves
n x (1 - 1/opt)^k, which is under n over e to the k over opt, and
that drops below 1 once k passes opt x ln n. Counting the last
partial pick gives the textbook bound, greedy uses at most
ln n + 1 times the optimum, here 3.7 against the observed 2. The
bound is nearly the truth in both directions: Slavik's tight
analysis pins the greedy worst case at exactly ln n - ln ln n +
theta(1), and the families reaching it are his construction, prose
here because the fixtures above only reach ratio 2. Section 11
returns to the other direction, that doing meaningfully better than
the logarithm would collapse complexity classes.

== metric tsp by double-tree

Give the tsp a metric, symmetric distances that obey the triangle
inequality, and 2 proven facts fall out. Deleting an edge from an
optimal tour leaves a spanning tree, so the minimum spanning tree
weighs at most the optimum. Doubling every tree edge makes all
degrees even, and a connected graph with all even degrees carries an
euler circuit, so a closed walk of weight exactly 2 x mst exists and
costs at most 2 x opt. Shortcutting that walk, keeping the first
visit of every vertex, never lengthens it under the triangle
inequality, because a jump across a skipped stretch costs at most
the stretch itself. The implementation is direct: prim with the scan
order pinned, tree vertices ascending then candidates ascending,
strict improvement so the lowest index pair wins ties, hierholzer
from vertex 0 always taking the first unused arc, then the shortcut.

The dry run: the fixtures are the 3 metric instances, asserted by
all 6 suites with the mst, the permutation check, the recomputed
tour length, and the ratio against the permutation oracle. The
euler walk weights 28, 32, and 88 are pinned by 5 of the 6 trees,
and c carries them as comments beside the pinned lengths.

+ The ring, 8 cities on a 4 by 4 perimeter: mst 14, a path through
  all 8, doubled walk 28, euler circuit 15 visits long, shortcut
  back to the ring order, tour 16, the oracle itself, ratio 1.0.
+ The convex hex: mst 16, walk 32, and the shortcut tour reads
  0, 1, 2, 3, 5, 4 for length 24 against the oracle 20, ratio 1.2
  exactly, 5 x 24 = 6 x 20. This is the non-trivial pin.
+ The hex walk itself reads 0, 1, 2, 3, 2, 1, 0, 5, 4, 5, 0: the
  doubled tree walks out to vertex 3, backtracks 3, 2, 1, 0, then
  crosses to 5 and bounces 5, 4, 5. The shortcut jumps 3 straight
  to 5, paying 6 for the 14 the backtrack spent, and the bounce
  costs the same either way, 32 down to 24.
+ The two cluster instance, 2 tight 2 by 2 blocks 20 apart: mst 44,
  a path inside each block joined by one long edge, walk 88,
  shortcut tour 0, 1, 3, 4, 5, 7, 6, 2 for length 84, the oracle
  itself, ratio 1.0.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*instance*], [*mst*], [*walk*], [*tour length*], [*opt*], [*ratio*]),
  [ring8], [14], [28], [16], [16], [1.0],
  [hex], [16], [32], [24], [20], [1.2],
  [clusters], [44], [88], [84], [84], [1.0],
)

#diagram([the hex double tree: the mst heavy, the euler walk with its backtrack, the 3 to 5 shortcut chord, the arithmetic 32 against 24], length: 13pt, {
  // the hexagon, points mapped from the fixture coordinates
  let hx = x => 1.4 + x * 0.85
  let hy = y => 5.6 + y * 0.85
  let pts = ((6, 2, [0]), (4, 4, [1]), (2, 4, [2]), (0, 2, [3]), (2, 0, [4]), (4, 0, [5]))
  let p = idx => (hx(pts.at(idx).at(0)), hy(pts.at(idx).at(1)))
  // light hull for orientation
  cdraw.line(p(0), p(1), stroke: luma(225))
  cdraw.line(p(1), p(2), stroke: luma(225))
  cdraw.line(p(2), p(3), stroke: luma(225))
  cdraw.line(p(3), p(4), stroke: luma(225))
  cdraw.line(p(4), p(5), stroke: luma(225))
  cdraw.line(p(5), p(0), stroke: luma(225))
  // mst edges heavy: 0-1, 1-2, 0-5, 4-5, 2-3
  cdraw.line(p(0), p(1), stroke: 1.4pt + luma(30))
  cdraw.line(p(1), p(2), stroke: 1.4pt + luma(30))
  cdraw.line(p(0), p(5), stroke: 1.4pt + luma(30))
  cdraw.line(p(5), p(4), stroke: 1.4pt + luma(30))
  cdraw.line(p(2), p(3), stroke: 1.4pt + luma(30))
  // the shortcut chord 3 to 5, dashed
  cdraw.line(p(3), p(5), stroke: (paint: luma(100), dash: "dashed"))
  for (x, y, lab) in pts {
    cdraw.circle((hx(x), hy(y)), radius: 0.3, fill: luma(235), stroke: luma(120))
    cdraw.content((hx(x), hy(y)), lab, size: 6.5pt)
  }
  cdraw.content((3.0, 9.6), [mst 16 heavy, shortcut 3 to 5 dashed], size: 6pt)
  cdraw.content((11.4, 9.6), [the walk: 0 1 2 3 2 1 0 5 4 5 0], size: 6.5pt)
  let walk = ("0", "1", "2", "3", "2", "1", "0", "5", "4", "5", "0")
  let back = (false, false, false, true, true, true, true, false, false, true, false)
  for (k, v) in walk.enumerate() {
    let hot = back.at(k)
    cdraw.rect((9.4 + k * 1.0, 8.2), (10.3 + k * 1.0, 8.9), fill: if hot { luma(248) } else { luma(235) }, stroke: if hot { luma(160) }, radius: 0.02)
    cdraw.content((9.85 + k * 1.0, 8.55), v, size: 6pt)
  }
  cdraw.content((14.9, 7.4), [outlined: the backtrack the shortcut skips], size: 6pt)
  cdraw.content((14.9, 6.5), [3 to 5 costs 6, the walk spent 14], size: 6pt)
  cdraw.content((14.9, 5.6), [5 4 5 0 to 4 0 saves nothing], size: 6pt)
  cdraw.content((14.9, 4.7), [walk 32, tour 24, opt 20], size: 6pt)
  cdraw.content((14.9, 3.8), [5 x 24 = 6 x 20, ratio 1.2], size: 6pt)
  cdraw.content((3.0, 4.4), [every distance manhattan over integers], size: 6pt)
  cdraw.content((3.0, 3.5), [triangle inequality makes the jump legal], size: 6pt)
})

The ring collapses to its own optimum, the hex pays 1.2, and the
listings below double the tree and walk it in 7 languages.

#listing("dsa/samples-c/src/Ch42/tsp2x.c", first: 111, last: 157, caption: [c, the doubled multigraph with parallel edge ids, hierholzer, the shortcut])
#listing("dsa/samples-go/ch42/tsp2x.go", first: 55, last: 103, caption: [go, the arc list euler tour and the shortcut over first visits])
#listing("dsa/samples-java/src/Ch42/Tsp2x.java", first: 111, last: 153, caption: [java, the doubled multigraph with parallel edge ids, hierholzer, the shortcut])
#listing("dsa/samples/src/Ch42/Tsp2x.cs", first: 123, last: 166, caption: [c\#, the euler walk on a stack of arcs, the shortcut keeping first visits])
#listing("dsa/samples-js/src/ch42-tsp2x.mjs", first: 80, last: 123, caption: [javascript, the walk, the shortcut, the adjacency build with doubled ids])
#listing("dsa/samples-py/src/Ch42/tsp2x.py", first: 59, last: 101, caption: [python, euler by stack, shortcut, the double tree assembly])
#listing("dsa/samples-lua/ch42_tsp2x.lua", first: 66, last: 117, caption: [lua, the same walk and shortcut, the tour length recomputed])

The ring and the hex come from #xref-to("dsa", "metaheuristics") on
purpose: chapter 41 searches that metric pair with 2-opt descents,
tabu tenure, and ant cycles, and the same point lists and manhattan
matrices return here so one instance family carries both stories,
the heuristic that improves with no promise attached and the
algorithm that promises 1.5 on its first pass. The clusters instance
joins from the same manhattan shelf, 2 dense blocks 20 apart, its
odd set straddling the divide so section 6 has a crossing to price.
Reading the 2 chapters against the same hex makes the difference
concrete: chapter 41's 2-opt descent reaches 20 by a chain of
improving reversals, the double tree reaches 24 on the first pass
and stops, and section 6 buys the missing 4 back with a matching.

== christofides 1.5x

The double tree wastes half its budget fixing degrees it broke
itself. Christofides fixes only the ones that need fixing: find the
odd degree vertices of the mst, which are always an even number
because degrees sum to twice the edge count, add a minimum weight
perfect matching on exactly that set, and the union is connected
with all even degrees. Its euler circuit weighs mst plus matching,
the shortcut costs no more, and the ratio is 1.5. The matching half
of the argument: walk an optimal tour and shortcut it to a cycle on
just the odd vertices, legal by the triangle inequality and no
heavier than the tour, then that even cycle's edges alternate into
2 perfect matchings, so the cheaper of the 2 costs at most half the
cycle, and the minimum matching costs no more than that. Mst at most
opt plus matching at most opt over 2 is 1.5 x opt.

Computing that matching is a blossom algorithm in general, and the
prose defers to the matching chapters for the real machinery. At
teaching sizes the honest implementation is exhaustive: the odd set
is at most 6 vertices in these fixtures, permutations of it pair up
as consecutive elements, the lexicographically first minimum wins,
and 720 orderings are nothing.

The dry run: the fixtures are the same 3 metric instances, asserted
by all 6 suites with the odd set, the matching weight, the tour, and
the ratio as 2 x length less than or equal 3 x opt.

+ The ring: mst 14, a path with endpoints 6 and 7 odd, matching
  weight 2 on the pair, euler over tree plus matching, shortcut back
  to the ring order, tour 16, the oracle, ratio 1.0.
+ The hex: mst 16, odd set 3 and 4, matching weight 4, tour the hull
  order 0, 1, 2, 3, 4, 5 at 20, the oracle, ratio 1.0. The double
  tree's 1.2 came from one bad shortcut, and the matching removed
  the degree that caused it.
+ The clusters: mst 44, odd set 2, 4, 6, 7, one vertex of the near
  block and 3 of the far block's 4 corners. The minimum matching
  pairs 2 with 4 across the divide for 39 and 6 with 7 inside the
  far block for 1, weight 40, and the shortcut tour reads
  0, 1, 3, 4, 5, 7, 6, 2 at 84, the oracle, ratio 1.0.
+ The euler graph check rides along: the walk uses exactly
  n - 1 tree edges plus the pairs, 7 plus 2 arcs of matching here,
  and the python suite counts that arc total while the other 5
  trees assert the walk's outcomes.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*instance*], [*mst*], [*odd set*], [*matching*], [*tour length*], [*opt*]),
  [ring8], [14], [{6, 7}], [2], [16], [16],
  [hex], [16], [{3, 4}], [4], [20], [20],
  [clusters], [44], [{2, 4, 6, 7}], [40], [84], [84],
)

#diagram([the odd set matchings: the hex pair 3 and 4 closed for 4, the cluster instance crossing the divide for 39 and closing inside the far block for 1], length: 13pt, {
  // left: the hex, mst light, matching 3-4 dashed heavy
  let hx = x => 1.2 + x * 0.5
  let hy = y => 4.4 + y * 0.5
  let hp = idx => {
    let raw = ((6, 2), (4, 4), (2, 4), (0, 2), (2, 0), (4, 0)).at(idx)
    (hx(raw.at(0)), hy(raw.at(1)))
  }
  for (a, b) in ((0, 1), (1, 2), (2, 3), (0, 5), (5, 4)) {
    cdraw.line(hp(a), hp(b), stroke: luma(180))
  }
  cdraw.line(hp(3), hp(4), stroke: (paint: luma(30), thickness: 1.6pt, dash: "dashed"))
  for v in range(6) {
    let hot = v == 3 or v == 4
    cdraw.circle(hp(v), radius: 0.28, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content(hp(v), [#v], size: 6pt)
  }
  cdraw.content((2.6, 7.3), [hex: odds 3, 4, matching 4], size: 6.5pt)
  cdraw.content((2.6, 3.6), [degrees even after the union], size: 6pt)
  // right: the clusters, mst light, matching 2-4 and 6-7 heavy
  let kx = x => 9.6 + x * 0.29
  let ky = y => 1.4 + y * 0.29
  let kp = idx => {
    let raw = ((0, 0), (1, 0), (0, 1), (1, 1), (20, 20), (21, 20), (20, 21), (21, 21)).at(idx)
    (kx(raw.at(0)), ky(raw.at(1)))
  }
  for (a, b) in ((0, 1), (0, 2), (1, 3), (3, 4), (4, 5), (4, 6), (5, 7)) {
    cdraw.line(kp(a), kp(b), stroke: luma(180))
  }
  cdraw.line(kp(2), kp(4), stroke: (paint: luma(30), thickness: 1.6pt, dash: "dashed"))
  cdraw.line(kp(6), kp(7), stroke: 1.6pt + luma(30))
  for v in range(8) {
    let hot = v in (2, 4, 6, 7)
    cdraw.circle(kp(v), radius: 0.24, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content(kp(v), [#v], size: 5.5pt)
  }
  cdraw.content((11.9, 8.4), [clusters: odds 2, 4, 6, 7], size: 6.5pt)
  cdraw.content((9.9, 4.1), [2 to 4 across, 39], size: 6pt)
  cdraw.content((15.6, 6.6), [6 to 7 inside, 1], size: 6pt)
  cdraw.content((15.6, 5.7), [matching 40, tour 84], size: 6pt)
  cdraw.content((15.6, 4.8), [all 3 fixtures land on opt], size: 6pt)
  cdraw.content((15.6, 3.9), [the 1.5 bound asserted anyway], size: 6pt)
  cdraw.content((15.6, 3.0), [2 x len \<= 3 x opt, cross-multiplied], size: 6pt)
})

All 3 fixtures land on their optima here, which is the honest
reading of 1.5 at these sizes, and the listings below build the
matching and the union in 7 languages.

#listing("dsa/samples-c/src/Ch42/christofides.c", first: 109, last: 130, caption: [c, the minimum perfect matching over odd-set permutations])
#listing("dsa/samples-go/ch42/christofides.go", first: 12, last: 41, caption: [go, fix the smallest odd vertex, try every partner ascending])
#listing("dsa/samples-java/src/Ch42/Christofides.java", first: 109, last: 130, caption: [java, the minimum perfect matching over odd-set permutations])
#listing("dsa/samples/src/Ch42/Christofides.cs", first: 16, last: 55, caption: [c\#, the matching recursion, pairs off consecutive elements of the permutation])
#listing("dsa/samples-js/src/ch42-christofides.mjs", first: 11, last: 38, caption: [javascript, the same permutation minimum, first strict winner])
#listing("dsa/samples-py/src/Ch42/christofides.py", first: 39, last: 66, caption: [python, prim again, the itertools permutations matching])
#listing("dsa/samples-lua/ch42_christofides.lua", first: 66, last: 94, caption: [lua, the matching recursion over the odd set, its own euler walk and shortcut])

The tightness of 1.5 is real and stays prose: families exist where
christofides returns exactly 1.5 x opt, improving the constant stood
open for 4 decades, and the only known improvement, from 2020,
shaves a vanishingly small margin off it. What the fixtures teach
instead is the mechanism, that the matching erases exactly the
parity the double tree created, and on the hex that recovers the
full 1.2 to 1.0.

== knapsack greedy 1/2 and the ptas

The greedy lane first: sort items by value density, value over
weight, and fill the sack in that order. Densities are compared as
cross-multiplied products, v_i x w_j against v_j x w_i, ties by
lower index, so the ordering is an exact rational comparison with no
float anywhere in the decision. The plain fill can be terrible on
its own, so the algorithm keeps the better of the fill and the best
single item, and that refinement is what the 1/2 needs: the fill
plus the first item it rejected together outweigh the optimum, one
of the 2 must hold at least half of it, and the returned witness is
at least that one.

The dry run: the fixture is the capacity 18 knapsack against the dp
oracle 1300. All 6 suites assert the cross-multiplied bound, the
density order array is pinned by the c\#, javascript, and python
trees, the picks by every tree but c, and c pins the values and
the k = 2 seed mask.

+ The density order pins as 9, 5, 2, 4, 8, 7, 0, 3, 1, 6, the 80 of
  item 9, the 75 of item 5, and the tied 70s by index 2, 4, 8.
+ The fill takes 9 at weight 3, 5 at weight 8, skips 2 and 8, takes
  4 at weight 5, and closes with 6 at weight 2: weights 3 + 8 + 5 +
  2 = 18 exactly, values 240 + 600 + 350 + 100 = 1290.
+ The best single item is 8 at value 700, the fill wins, and the
  greedy answers 1290 with 2 x 1290 greater than or equal 1300.
+ The ptas enumerates every k-subset of items that fits and
  density-fills the remainder over the unused items. At k = 1 it is
  the greedy plus the single-item refinement, 1290. At k = 2 the
  pair 5 and 8, weights 8 + 10 = 18, values 600 + 700, is among the
  enumerated seeds and the answer is the optimum 1300. At k = 3 the
  answer falls back to 1290: every fitting 3-subset leaves a
  remainder whose fill scores at most 1290.
+ Monotonicity in k fails at the instance level, 1290, 1300, 1290,
  and that is the teaching row. The guarantee is asymptotic, at
  least 1 - 1 over (k + 1) of the optimum in the worst case, and a
  larger k buys the bound, never a monotone score.

#table(
  columns: (auto, auto, auto, 2.4fr),
  inset: 4pt,
  table.header([*k*], [*value*], [*vs opt*], [*what the enumeration found*]),
  [1], [1290], [0.992], [the greedy fill, items 9, 5, 4, 6],
  [2], [1300], [1.0], [the seed pair 5 and 8, weight 18 exactly],
  [3], [1290], [0.992], [no fitting triple seeds anything better],
)

The 1290 under 1300 and the k = 2 recovery are pinned in every
tree, and the listings below build the density order, the fill, and
the enumeration in 7 languages.

#listing("dsa/samples-c/src/Ch42/ptas.c", first: 44, last: 77, caption: [c, the cross-multiplied insertion sort, the fill from a seeded subset])
#listing("dsa/samples-go/ch42/ptas.go", first: 12, last: 57, caption: [go, the exact comparator and the greedy with its refinement])
#listing("dsa/samples-java/src/Ch42/Ptas.java", first: 44, last: 80, caption: [java, the cross-multiplied insertion sort in long, the fill from a seeded subset])
#listing("dsa/samples/src/Ch42/Ptas.cs", first: 19, last: 69, caption: [c\#, density order by insertion, the fill, the best-single refinement])
#listing("dsa/samples-js/src/ch42-ptas.mjs", first: 13, last: 42, caption: [javascript, the comparator as cross-multiplied products, the fill])
#listing("dsa/samples-py/src/Ch42/ptas.py", first: 36, last: 75, caption: [python, the selection-order density walk, the fill, the pinned 1290])
#listing("dsa/samples-lua/ch42_ptas.lua", first: 26, last: 52, caption: [lua, the sort comparator and the greedy, picks as 1-based indices])

One ptas file serves this section and the next, the greedy and the
enumeration above, the scaled table below. The enumeration cost is
n^k subsets times a linear fill, polynomial for every fixed k and
rising with it, which is the whole meaning of a ptas: pick the
accuracy first, pay a polynomial whose degree depends on it.

== fptas by profit scaling

The ptas pays n^k for its accuracy. The fptas pays n squared over
eps. Scale every profit v_i down to v_i / k with
k = max(1, eps x vmax / n), rounded to integers toward zero, run the
minimum weight dynamic program over scaled profits, dp2 at s holding
the least weight reaching scaled profit s, answer the largest s
whose weight fits, and report the true value of the reconstructed
set. The arithmetic of the bound is 3 lines: each item loses under k
in scaling, n items lose under n x k together, n x k is at most
eps x vmax, and vmax is at most the optimum, so the scaled problem
still contains a set worth at least 1 - eps of the optimum, and the
program finds the best scaled one. The running time is n times the
scaled profit sum, which is n squared vmax over k, which is
n cubed over eps: polynomial in n and in 1 over eps together, the
definition of an fptas. Epsilon travels as the integer pair num
over den, so the bound check, value x den at least (den - num) x
opt, stays integer too.

The dry run: the fixtures are the big instance at 4 epsilons and
the near-tie instance at the same 4, asserted by all 6 suites with
k, the value, feasibility, and the bound per eps.

+ On the big instance every eps is exact: eps 1 scales by k = 70,
  eps 1/2 by 35, eps 1/4 by 17, eps 1/10 by 7, and all 4 runs return
  items 5 and 8 at 1300 with weight 18. The bound
  value x den at least (den - num) x 1300 holds everywhere, with
  room.
+ The near-tie instance holds 4 items of weights 3, 3, 2, 2 and
  values 25, 25, 24, 24 against capacity 6. The optimum is 50, the
  2 heavy items together.
+ At eps 1, k = 6: 25 / 6 and 24 / 6 both round to 4, the scaled
  problem cannot tell the heavy pair from the light pair, and the
  program returns the light pair, true value 48. At eps 1/2, k = 3:
  both round to 8 again, 48 once more.
+ At eps 1/4, k = 1: the profits survive untouched, the answer is
  the heavy pair, 50. At eps 1/10 the floor lands at 0 and the
  clamp holds k at 1, 50 again.
+ The error is visible exactly when the bound allows it: 48 against
  50 is 0.96, above 1 - eps at eps 1 and eps 1/2, and the suite
  asserts the bound at every step, the value only where it pins.

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*eps*], [*big k*], [*big value*], [*near-tie k*], [*near-tie value*], [*bound*]),
  [1], [70], [1300], [6], [48], [48 \>= 0 x 50],
  [1/2], [35], [1300], [3], [48], [96 \>= 50],
  [1/4], [17], [1300], [1], [50], [200 \>= 150],
  [1/10], [7], [1300], [1], [50], [500 \>= 450],
)

#diagram([the 2 error ladders: the ptas k values 1290, 1300, 1290 against the optimum line, the fptas eps values 48, 48, 50, 50 closing to it], length: 13pt, {
  // left: ptas k ladder
  let by = v => 0.9 + (v - 1280) * 0.28
  cdraw.content((4.4, 8.7), [ptas by k: not monotone per instance], size: 6.5pt)
  cdraw.line((1.4, by(1300)), (7.5, by(1300)), stroke: luma(100))
  cdraw.content((8.35, by(1300)), [opt 1300], size: 6pt)
  let kbars = (([k 1], 1290), ([k 2], 1300), ([k 3], 1290))
  for (k, (lab, v)) in kbars.enumerate() {
    let x = 1.9 + k * 1.9
    cdraw.rect((x, 0.9), (x + 1.2, by(v)), fill: if v == 1300 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.6, by(v) + 0.32), [#v], size: 6pt)
    cdraw.content((x + 0.6, 0.5), lab, size: 6pt)
  }
  cdraw.content((4.4, 7.5), [k 2 finds the pair, k 3 loses it], size: 6pt)
  // right: fptas eps ladder on the near-tie instance
  let cy = v => 0.9 + (v - 46) * 0.5
  cdraw.content((14.2, 8.7), [fptas by eps: 48, 48, 50, 50], size: 6.5pt)
  cdraw.line((9.6, cy(50)), (18.6, cy(50)), stroke: luma(100))
  cdraw.content((11.7, cy(50) + 0.32), [opt 50], size: 6pt)
  let ebars = (([eps 1, k 6], 48), ([eps 1/2, k 3], 48), ([eps 1/4, k 1], 50), ([eps 1/10, k 1], 50))
  for (k, (lab, v)) in ebars.enumerate() {
    let x = 9.9 + k * 2.1
    cdraw.rect((x, 0.9), (x + 1.4, cy(v)), fill: if v == 50 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.7, cy(v) + 0.32), [#v], size: 6pt)
    cdraw.content((x + 0.7, 0.5), lab, size: 5.5pt)
  }
  cdraw.content((14.1, 4.4), [25 / 6 and 24 / 6 both round to 4], size: 6pt)
  cdraw.content((14.1, 3.7), [scaling blind exactly where the bound permits], size: 6pt)
})

The ladders are the pinned values of both instances, and the
listings below run the scaled table in 7 languages.

#listing("dsa/samples-c/src/Ch42/ptas.c", first: 110, last: 157, caption: [c, the fptas whole: k from the eps pair, scaled profits, dp2, rebuild])
#listing("dsa/samples-go/ch42/ptas.go", first: 125, last: 160, caption: [go, the scale factor, the fill, the largest feasible s])
#listing("dsa/samples-java/src/Ch42/Ptas.java", first: 118, last: 164, caption: [java, the fptas whole: k from the eps pair as num over den, scaled profits, dp2, the rebuild])
#listing("dsa/samples/src/Ch42/Ptas.cs", first: 144, last: 190, caption: [c\#, the min-weight table over scaled profit, the backward rebuild])
#listing("dsa/samples-js/src/ch42-ptas.mjs", first: 85, last: 130, caption: [javascript, scaled dp with the take table, value recomputed at the end])
#listing("dsa/samples-py/src/Ch42/ptas.py", first: 107, last: 136, caption: [python, the same table, integer division on profits, both instances pinned])
#listing("dsa/samples-lua/ch42_ptas.lua", first: 103, last: 148, caption: [lua, the scaled dp, 1 << 30 as the sentinel, k pinned per eps])

The near-tie instance is what an fptas at work honestly looks
like. It does not gently approach the optimum as eps shrinks, it is
blind below a threshold and exact above it, the threshold sits
where the scaling step is as wide as the value differences, and the
bound is what the blindness costs, never more. Section 11 records
the other half: knapsack is as far as this comfort reaches.

== bin packing first fit

3 orderings of one rule: first fit scans the open bins in creation
order and takes the first with room, else opens a new bin. First fit
decreasing sorts the items non-increasing first, stable so equal
sizes keep input order, then runs the same scan. Next fit keeps a
single open bin and closes it the moment an item does not fit. The
oracle is branch and bound over item to bin assignments, each item
trying the existing bins by load with equal loads pruned as
symmetric and the fresh bin last, exact at n up to 9. The bounds are
prose: next fit never doubles the optimum, pairing each closed bin
with the item that killed it fills 2 bins past the cap for every
pair, and first fit decreasing lands within 11/9 of the optimum plus
2/3, Johnson's ratio with Dosa's tight constant.

The dry run: the fixtures are the 5 pinned instances, asserted by
all 6 suites as bin counts. The c tree adds the pinned ffd loads
and the factor 2 bounds, and the other 5 check that loads conserve
the items and stay under the cap on every bin.

+ The first instance, 5, 5, 4, 4, 3, 3, 3, 3 at cap 10: ff 4, ffd 4,
  nf 4, opt 3, the classic shape where every heuristic sits one bin
  above. The ffd loads pin as 10, 8, 9, 3, the first bin exactly
  full and 3 stranded units in the last.
+ The second, 6, 6, 4, 4 at cap 10: ff 2, ffd 2, nf 3, opt 2. Next
  fit closes the first bin at 6 when the second 6 arrives, pairs
  6 + 4 and 6 + 4 fit, but the closed bin stays closed, 3 against 2.
+ The third, 7, 6, 3, 4, 5, 4, 7, 3 at cap 10: 4, 4, 5, 4.
+ The fourth, 8, 5, 5, 8, 6, 4, 4, 6 at cap 13: 4, 4, 4, 4, nothing
  to prove, everything lands on the optimum.
+ The fifth, 4, 4, 4, 6, 6, 6, 5, 5, 5 at cap 10: ff 6, ffd 5,
  nf 6, opt 5. Input order alone costs first fit a bin, its loads
  read 8, 10, 6, 6, 10, 5 while the sorted pass reads 10, 10, 10,
  10, 5.

#table(
  columns: (2.2fr, auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*items*], [*cap*], [*ff*], [*ffd*], [*nf*], [*opt*]),
  [5, 5, 4, 4, 3, 3, 3, 3], [10], [4], [4], [4], [3],
  [6, 6, 4, 4], [10], [2], [2], [3], [2],
  [7, 6, 3, 4, 5, 4, 7, 3], [10], [4], [4], [5], [4],
  [8, 5, 5, 8, 6, 4, 4, 6], [13], [4], [4], [4], [4],
  [4, 4, 4, 6, 6, 6, 5, 5, 5], [10], [6], [5], [6], [5],
)

#diagram([the fifth instance at cap 10: first fit opening 6 bins in input order against the sorted pass closing in 5, the slack shaded], length: 13pt, {
  // items 4,4,4,6,6,6,5,5,5 cap 10, ff loads 8,10,6,6,10,5, ffd 10,10,10,10,5
  let bx = 1.4
  let pitch = 2.35
  cdraw.content((7.0, 8.7), [cap 10, total 45, opt 5 bins], size: 6.5pt)
  let cap = 10
  let row = (y, loads, label) => {
    cdraw.content((0.6, y + 0.28), label, size: 6pt)
    for (b, v) in loads.enumerate() {
      let x = bx + b * pitch
      let fill = if v < cap { luma(248) } else { luma(205) }
      cdraw.rect((x, y), (x + 2.0, y + 0.62), fill: none, stroke: luma(190), radius: 0.02)
      cdraw.rect((x, y), (x + v * 0.2, y + 0.62), fill: fill, radius: 0.02)
      cdraw.content((x + 1.0, y + 1.0), [#v], size: 6pt)
    }
  }
  row(6.6, (8, 10, 6, 6, 10, 5), [ff 6])
  row(4.2, (10, 10, 10, 10, 5), [ffd 5])
  cdraw.content((7.0, 3.1), [the order alone strands 2 half-empty bins], size: 6pt)
  cdraw.content((7.0, 2.2), [the sorted pass fills 4 bins to 10 exactly], size: 6pt)
  cdraw.content((7.0, 1.3), [nf also opens 6 here], size: 6pt)
  cdraw.content((7.0, 0.4), [ffd within 11/9 opt + 2/3, prose], size: 6pt)
})

The 6 against 5 and the pinned loads carry the section, and the
listings below ship the 3 heuristics and the oracle in 7 languages.

#listing("dsa/samples-c/src/Ch42/binpack.c", first: 30, last: 75, caption: [c, first fit, the stable decreasing sort, next fit])
#listing("dsa/samples-go/ch42/binpack.go", first: 7, last: 43, caption: [go, the scans and the stable non-increasing sort])
#listing("dsa/samples-java/src/Ch42/Binpack.java", first: 27, last: 77, caption: [java, first fit, the stable decreasing sort, next fit])
#listing("dsa/samples/src/Ch42/Binpack.cs", first: 15, last: 54, caption: [c\#, the 3 scans over a growing bin list])
#listing("dsa/samples-js/src/ch42-binpack.mjs", first: 9, last: 39, caption: [javascript, the same 3 rules over plain arrays])
#listing("dsa/samples-py/src/Ch42/binpack.py", first: 14, last: 37, caption: [python, the fill with the for-else open, next fit, one flag for ffd])
#listing("dsa/samples-lua/ch42_binpack.lua", first: 10, last: 48, caption: [lua, the insertion-sorted decreasing pass, the 2 scans])

The oracle earns a note of its own: it is the chapter 20 machinery
in miniature, its bound the count of open bins in place of a value,
pruning symmetric branches the heuristics never see, and it
runs in microseconds at n = 9 and in years at n = 20, which is the
whole reason the heuristics exist.

== local search as an approximation engine

Chapter 41 improved its states one move at a time and promised
nothing about where the moves stop. The single-flip driver here,
strictly improving flips from a fixed vertex order, inherits a
theorem: at a local optimum every
vertex has at least as many crossing edges as same-side edges, a
flipping vertex would gain the difference, so summing over vertices
counts each crossing edge twice on the crossing ledger and each
internal edge twice on the other, giving cut at least half the
edges. The guarantee is rho = 2 for maximization, cut x 2 at least
m, and it needs nothing but the stop condition, no order, no
restarts, no schedule.

The dry run: the fixture is k5 minus the edges a to d and d to e, 8
edges over 5 vertices, asserted by all 6 suites with the flip count,
the side, the oracle over all 32 assignments, and the bound.

+ All 5 vertices start on one side, cut 0, and the first pass flips
  a, then b: 2 flips, both strictly improving, side a, b against
  c, d, e.
+ No single flip helps from there: flipping a drops the 2 crossing
  edges a to c and a to e and lifts only a to b, flipping d trades
  b to d for c to d, the partition is flip-stable and the suite
  checks every vertex.
+ The local optimum cuts 5 edges, the brute force over the 32 sides
  finds 6, and 2 x 5 is at least 8, the bound holds with room, the
  achieved ratio is 5/6.
+ The optimum itself splits a, d, e against b, c: 6 crossing edges,
  and the 2 left inside are a to e and b to c, the cheapest pair of
  edges that settles all 5 triangles hiding in the fixture.

#diagram([the flip search stopping at 5 of 8 edges against the optimal split at 6, cut edges heavy in both panels], length: 13pt, {
  // both panels: k5 minus a-d and d-e, heavy edges cross the sides, light stay inside
  let draw-panel = (cx, title, cut-label, pos, edges, dark) => {
    cdraw.content((cx, 8.7), title, size: 6.5pt)
    for (u, v, hot) in edges {
      cdraw.line(pos.at(u), pos.at(v), stroke: if hot { 1.4pt + luma(30) } else { luma(200) })
    }
    for (name, p) in pos {
      cdraw.circle(p, radius: 0.3, fill: if name in dark { luma(205) } else { luma(240) }, stroke: luma(120))
      cdraw.content(p, [#name], size: 6.5pt)
    }
    cdraw.content((cx, 3.4), cut-label, size: 6pt)
  }
  draw-panel(
    3.75,
    [local optimum: cut 5 of 8],
    [side a, b: 2 flips, flip-stable],
    (a: (1.4, 7.7), b: (1.4, 5.5), d: (3.6, 5.6), c: (6.1, 7.5), e: (6.1, 4.6)),
    (("a", "b", false), ("a", "c", true), ("a", "e", true), ("b", "c", true), ("b", "d", true), ("b", "e", true), ("c", "d", false), ("c", "e", false)),
    ("a", "b"),
  )
  draw-panel(
    12.75,
    [optimum: cut 6 of 8],
    [side a, d, e against b, c],
    (a: (10.4, 7.7), d: (10.4, 5.5), e: (12.4, 7.0), b: (15.1, 7.5), c: (15.1, 4.6)),
    (("a", "b", true), ("a", "c", true), ("a", "e", false), ("b", "c", false), ("b", "d", true), ("b", "e", true), ("c", "d", true), ("c", "e", true)),
    ("a", "d", "e"),
  )
  cdraw.content((9.6, 2.2), [missing edges a to d and d to e], size: 6pt)
  cdraw.content((9.6, 1.3), [2 x 5 \>= 8, the rho 2 contract], size: 6pt)
  cdraw.content((9.6, 0.4), [the stop condition alone is the proof], size: 6pt)
})

The 5 against 6 with the bound intact is the pinned landing, and the
listings below run the flip driver in 7 languages.

#listing("dsa/samples-c/src/Ch42/maxcut.c", first: 30, last: 73, caption: [c, the oracle over 32 sides, the flip loop with its guard, the checks])
#listing("dsa/samples-go/ch42/maxcut.go", first: 7, last: 33, caption: [go, the same driver, the order a parameter, the brute beside it])
#listing("dsa/samples-java/src/Ch42/Maxcut.java", first: 28, last: 70, caption: [java, the oracle over 32 sides, the flip loop with its guard, the checks])
#listing("dsa/samples/src/Ch42/Maxcut.cs", first: 25, last: 47, caption: [c\#, the pass over the fixed order, keep the flip only when it gains])
#listing("dsa/samples-js/src/ch42-maxcut.mjs", first: 16, last: 34, caption: [javascript, the flip pass and the reverted probe])
#listing("dsa/samples-py/src/Ch42/maxcut.py", first: 30, last: 50, caption: [python, the cut, the local search, the flip-stability check below])
#listing("dsa/samples-lua/ch42_maxcut.lua", first: 25, last: 44, caption: [lua, the driver mirrored from chapter 41, the revert path])

The bridge back to #xref-to("dsa", "metaheuristics") is the point
of the section. There a single flip earns annealing schedules, tabu
tenure, and restarts to escape exactly this kind of stop, and none
of it carries a number. Here the stop is the theorem, the number is
2, and the fixtures show the slack, 5 of a possible 6.
Between them sits a refinement the corpus states without sampling:
on cubic graphs the locally optimal cut reaches 2/3 of the optimum,
and this fixture is not cubic, degrees run 2 through 4, so 5/6
clearing 2/3 is luck of the instance and nothing stronger.

== inapproximability: a reader's map

Everything above the line costs a ratio. The map below says where
the line is, and it is written as prose because the content is
reduction sketches, not code the fixtures could pin.

The first barrier is the oldest one. If a polynomial algorithm
approximated an NP-complete problem with a ratio close enough to 1
to separate a reduction's yes and no cases, a separation reduction
turns it into an exact polynomial algorithm: build an instance
where the yes and no cases sit a known factor apart, run the
approximation, and read the answer off the side it lands on. That
would solve an NP-complete problem in polynomial time, so unless
P = NP the exact version is out of reach and every ratio in this
chapter is a negotiation with the barrier, priced individually. The
statement is not that approximation is useless, the sections above
are the counterexample.

The second barrier is the metric itself. Drop the triangle
inequality from the tsp and no finite ratio survives: encode any
hamiltonian cycle question as a complete graph with edge weights 1
and w, w huge, the weight at which a tour exists and a tour does not
differ by more than any fixed rho, so a rho-approximation would
decide hamiltonicity. The metric instances of sections 5 and 6 are
not a convenience of the fixtures, the hypothesis carries the
theorem, and the manhattan matrices of the chapter keep it
witnessed in integers.

The third barrier prices the logarithm. Set cover admits the
ln n + 1 of section 4 and nothing polynomial meaningfully better:
no algorithm reaches (1 - eps) x ln n for any eps unless problems
in NP fall to quasi-polynomial time, the conditional hardness of
Feige's reduction, and Slavik's analysis shows the greedy sits
exactly at ln n - ln ln n + theta(1), so the classic algorithm and
the barrier nearly touch. Vertex cover sits in the opposite
situation, its 2 is ancient, no polynomial 1.9x is known, and the
known hardness stops well short of forbidding one, the widest open
spread in the field.

The fourth barrier is the quiet one, and it is good news. Knapsack
carries an fptas, section 8, and that is the best class of
guarantee an NP-hard problem can hold: any strongly NP-hard
problem, hard even when every number is polynomially bounded,
admits no fptas unless P = NP, because epsilon small enough makes
the running time polynomial and the error zero at once. Knapsack is
only weakly hard, its numbers are the enemy and scaling disarms
them, and the fptas is the exact shape of that weakness. When a new
problem arrives, the first structural question after the exact
lanes fail is which side of this line its hardness lives on.

== choosing the right surrender

The corpus now holds every tier of the trade, and the choice is a
table lookup once the instance size and the required guarantee are
on the table.

+ Under a few million states, exact wins outright: the mask and
  interval tables of chapters 17 and 19, the assignment and flow
  solvers of chapter 38, all polynomial or singly exponential in
  one small parameter, all returning the optimum with a witness.
+ When the states explode but the structure prunes, chapter 20's
  branch and bound buys the same exactness on luck, the fractional
  bound deciding how much luck.
+ When exactness leaves the budget and a proven ratio suffices,
  this chapter: the 2 of the matching cover, the ln n + 1 of greedy
  set cover, the 1.5 of christofides, the bin packing heuristics,
  each with its feasibility check and its oracle in the test.
+ When the ratio itself must be chosen, knapsack's ptas and fptas,
  sections 7 and 8, accuracy as an input, polynomial time in n and
  1 over eps.
+ When no ratio is known or the instance is simply too large,
  #xref-to("dsa", "metaheuristics"), anytime improvement with no
  promise, run against a clock and kept if it beats what is on
  hand.

#table(
  columns: (auto, auto, auto, 1.9fr),
  inset: 4pt,
  table.header([*tool*], [*guarantee*], [*instance size*], [*where*]),
  [exact dp], [optimal, exponential in one parameter], [under a few million states], [chapters 17 and 19, masks, intervals, tables],
  [branch and bound], [optimal, bound dependent], [unpredictable, seconds to hours], [chapter 20, the fractional knapsack bound],
  [flows and matching], [optimal, polynomial], [tens of thousands of edges], [chapter 38, kuhn and the flow solvers],
  [proven ratio], [2, ln n + 1, 1.5, 11/9], [any size the scan fits], [this chapter, sections 3 through 6 and 9],
  [ptas and fptas], [1 - eps, polynomial in n and 1 over eps], [knapsack shapes at any size], [this chapter, sections 7 and 8],
  [#xref-to("dsa", "metaheuristics")], [none, anytime], [anything, budget the clock], [chapter 41, annealing, tabu, genetic],
)

The rows read as a pipeline, and the corpus
chapters cross-link along it: chapter 17 points forward to here
when its tables stop fitting memory, chapter 20 points here when
its trees stop finishing, and section 10 points back at
#xref-to("dsa", "metaheuristics") for the driver it borrowed. The
last rule of the table is the one the
whole chapter argues: whatever the row, the answer it returns is a
witness with a check attached, feasible by construction and priced
against an oracle in the same test, and a result that cannot say
both of those things about itself is not an approximation, it is a
guess.

== across the seven languages

Featured build size counted as non-blank, non-comment source lines
of the chapter's 8 sample files per language in the c, go, java,
javascript, python, and lua trees, the c\# row counting non-blank
lines of its 8 files, go test files excluded:

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto, auto, 1.6fr),
  inset: 4pt,
  table.header([*stem*], [*c*], [*go*], [*java*], [*c\#*], [*javascript*], [*python*], [*lua*], [*note*]),
  [ratio], [109], [44], [112], [76], [48], [55], [90], [serves sections 1 and 2, oracle half and contract half],
  [vc], [80], [15], [80], [46], [20], [59], [105], [go leans on ratio.go for the oracle and feasibility],
  [setcover], [102], [62], [94], [89], [43], [57], [113], [bitmask ground in c and go, sets elsewhere],
  [tsp2x], [182], [97], [174], [172], [121], [106], [181], [matrices restated per file in c, python, lua],
  [christofides], [218], [54], [208], [92], [56], [115], [218], [c\# and js import the tsp2x and ch41 helpers],
  [ptas], [182], [152], [183], [187], [115], [127], [183], [serves sections 7 and 8, greedy and both tables],
  [binpack], [115], [63], [119], [85], [56], [72], [121], [the oracle is branch and bound at n up to 9],
  [maxcut], [58], [43], [56], [64], [39], [57], [73], [the thinnest stem, one driver and one oracle],
)

The small numbers are sharing. Go's vc is 15 source lines because
the oracle and the feasibility predicate live in ratio.go and the
matching engine is all that is left to state, and go's christofides
at 54 composes the prim, euler, and shortcut helpers of tsp2x.go
instead of restating them. The c\# tree keeps the fixtures and the
shared walkers in tsp2x.cs and the chapter 41 localsearch class, so
christofides.cs is 92 lines of matching and assembly, and
javascript imports eulerWalk, mstPrim, and shortcut across the
stem boundary the same way. C, python, and lua restate the
matrices and the walkers per file, 3 trees times 8 files, which is
why their columns run high, lua adding the 1-based index adjustments
and the run.lua check rows on top. Java restates the same way, every
stem standalone, prim and the euler walk rebuilt inside tsp2x and
christofides rather than imported, and its density and ratio
comparisons ride long products cross-multiplied, never doubles.

The corpus placement is honest silence: the icpc book's mined
finals problems all yielded to exact algorithms, so no chapter
there cites an approximation technique, and this chapter's contest
relevance is the negative space, the tier that takes over when the
exact tool the icpc chapters teach does not finish. The nearest
neighbors in this book are the held-karp mask tables of
#xref-to("dsa", "advdp") that hold the optima section 5's
permutation oracles walk the slow way, the pruning discipline of
#xref-to("dsa", "pruning") that section 9's oracle miniaturizes,
and the single-flip discipline of
#xref-to("dsa", "metaheuristics") that section 10 returns with a
theorem.

sources: V. V. Vazirani, "Approximation Algorithms", Springer, 2001,
the vertex cover and set cover chapters behind sections 3 and 4.
D. P. Williamson and D. B. Shmoys, "The Design of Approximation
Algorithms", Cambridge University Press, 2011, the greedy, tsp, and
knapsack sections behind sections 4 through 8. T. H. Cormen,
C. E. Leiserson, R. L. Rivest, and C. Stein, "Introduction to
Algorithms", third edition, MIT Press, 2009, chapter 35, sections
35.1 through 35.5, the set cover, tsp, and subset sum fptas
treatments. P. Slavik, "A tight analysis of the greedy algorithm
for set cover", Journal of Algorithms 25, 1997, the exact greedy
worst case named in section 4. The bin packing bounds follow
D. S. Johnson's 1973 thesis and G. Dosa's 2007 tightening of the
additive constant. Sample behavior verified by the 7 suite gates
scoped to chapter 42: c 8 files and 8 checks, go 17 test functions,
java 8 files and 224 checks under run-java-samples, c\# 24 facts,
javascript 24 tests across 8 suites, python 8 files and 8 checks, lua
37 checks, zero skipped.
