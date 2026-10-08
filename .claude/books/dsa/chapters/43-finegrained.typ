// chapter 43: fine-grained speedups, manifest id finegrained
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= fine-grained speedups

The counting question of #xref-to("dsa", "analysis") asks whether an
algorithm is polynomial. Fine-grained complexity asks a sharper one:
can the exponent itself move. This chapter walks one 2026 paper's
answer end to end, Josh Alman and Virginia Vassilevska Williams, truly
subquadratic 3SUM and truly subcubic APSP via triangles in sparse
lopsided graphs (arXiv 2610.06783). The engine is theorem 1, page 5:
given an N x D matrix times a D x N matrix with N at least D^18 and at
most N^2 / sqrt(D) wanted entries, all wanted entries are computable
deterministically in O(N^2 / D^0.063) time, polynomially less than
one operation per entry of the full product. The chapter builds that
engine in 8 steps, each pinned by fixtures in 7 languages: the
lopsided triangle home problem, Schoenhage's ten-multiplication
identity, the recursion on strings, the tiling that shares encodings,
the pruned recursion with its leaf-count lemmas, the boxes data
structure with O(D^0.437) queries (theorem 3, page 7), the exact
triangle reduction by hashing weights modulo a prime (theorem 17,
page 33), and the consequences for 3SUM and APSP (theorems 19 and 22,
pages 35 and 36). An honesty thread runs through all 8: the exponents
that move are small, the regimes that justify them are enormous, and
the toy fixtures show the algorithms losing on purpose, because a
speedup you cannot price is a slogan.

== the lopsided triangle problem and its baselines

The paper's home problem, Lop-AE-SparseTri(n, D) of definitions 13
and 14, is a triangle question poured into a matrix shape, the graph
vocabulary of #xref-to("dsa", "graphs") with the middle part thinned.
A tripartite graph has parts A and B of n vertices and a middle part
M of D vertices, with biadjacency matrices X in {0,1}^(n x D) and Y
in {0,1}^(D x n), plus a set W of query pairs. Each pair (a, b) asks
how many middle vertices k satisfy X\[a\]\[k\] = 1 and Y\[k\]\[b\] = 1, the
count of a-b triangles through the middle. Three solvers price it.
The per-pair scan walks the D middle vertices per pair for O(|W| D).
The bitset route packs row a of X and column b of Y into D-bit words
and answers each pair with one AND and one popcount. The dense route
computes the full n x n integer product X times Y for O(n^2 D) and
reads the answers off. At the fixture the counted work orders 18 word
ops, 32 entry reads, 144 multiplies.

The bitset win is conditional, and the condition is the chapter's
first honesty point. One D-bit row occupies words(D) = ceil(D / 64)
machine words, 1 word at D = 64, 2 at D = 65, 4 at D = 256. The
paper's regime is D = n^eps with eps about 1/18, so D grows with n
and words(D) grows without bound, and neither baseline reaches the
O(n^2 log^2 D / D^(1/18)) target. Beating the baselines needs
arithmetic that shares work across queries, which is where
Schoenhage's identity enters in the next section.

The dry run: the fixture is n = 6, D = 4, 8 query pairs drawn by the
corpus generator, asserted by all 7 suites against the pinned count
vector.

+ Randomness follows the corpus law everywhere in this chapter: the
  64-bit Knuth LCG, x' = 6364136223846793005 x + 1442695040888963407
  mod 2^64, advancing once per draw and reading x >> 32, the high 32
  bits. Both constants are odd, so bit 0 of the state alternates and
  a raw mod-2 draw would degenerate, which is why only the high half
  is ever read.
+ Seed 4301 regenerates X, Y, and the 8 distinct pairs as a 66-value
  integer stream, pinned element by element in every tree.
+ The pinned count vector is \[1, 1, 0, 0, 0, 2, 0, 1\] and the
  detection vector \[1, 1, 0, 0, 0, 1, 0, 1\]: pair (4, 5) sees 2
  triangles through middle vertices 1 and 3, 4 pairs see a triangle
  at all.
+ All three solvers agree on every pair: scan lengths, AND word
  popcounts, and dense product entries at the query positions.
+ The graph view pins 10 edges from A to M and 11 from M to B, 5
  triangles total over the 8 queries.

#diagram([the lopsided tripartite graph at the fixture: parts A and B of 6 vertices, a thin middle of 4, the query pair (4, 5) crossing at middle vertices 1 and 3], length: 13pt, {
  let node = (x, y, label, hot) => {
    cdraw.circle((x, y), radius: 0.22, fill: if hot { luma(205) } else { luma(235)}, stroke: luma(120))
    cdraw.content((x, y), label, size: 6pt)
  }
  cdraw.content((2.6, 8.5), [A, 6 vertices], size: 6.5pt)
  cdraw.content((8.0, 8.5), [M, 4 vertices], size: 6.5pt)
  cdraw.content((13.4, 8.5), [B, 6 vertices], size: 6.5pt)
  for i in range(6) { node(2.6, 7.7 - i * 0.85, [#i], i == 4) }
  for i in range(4) { node(8.0, 7.3 - i * 0.95, [#i], i == 1 or i == 3) }
  for i in range(6) { node(13.4, 7.7 - i * 0.85, [#i], i == 5) }
  // the query pair (4, 5): a4 to middle 1 and 3, on to b5
  cdraw.line((2.9, 4.3), (7.7, 6.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.9, 4.3), (7.7, 4.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.3, 6.35), (13.1, 3.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.3, 4.45), (13.1, 3.45), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.2, 5.9), [X\[4\]\[1\] = X\[4\]\[3\] = 1], size: 6pt)
  cdraw.content((10.9, 5.6), [Y\[1\]\[5\] = Y\[3\]\[5\] = 1], size: 6pt)
  cdraw.content((2.6, 1.6), [query (4, 5): count 2], size: 6pt)
  cdraw.content((2.6, 0.8), [8 pairs, 5 triangles, 4 detected], size: 6pt)
  cdraw.content((8.0, 1.6), [|W| = 8 queries], size: 6pt)
  cdraw.content((8.0, 0.8), [n = 6, D = 4], size: 6pt)
})

#diagram([the three solvers priced at the fixture as counted work bars, and the word count of a D-bit set as D grows: the bitset win dies exactly when the paper's regime begins], length: 13pt, {
  let bar = (x, w, y, label, val, hot) => {
    cdraw.rect((x, y), (x + w, y + 0.7), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w + 0.35, y + 0.35), [#val], size: 6pt)
    cdraw.content((x - 0.25, y + 0.35), label, size: 6pt, anchor: "east")
  }
  cdraw.content((7.0, 8.5), [counted work at the fixture], size: 6.5pt)
  let bx = 5.6
  bar(bx, 0.55, 7.2, [bitset], 18, true)
  bar(bx, 0.97, 6.2, [scan], 32, false)
  bar(bx, 4.35, 5.2, [dense], 144, false)
  cdraw.content((7.0, 4.2), [10 words built + 8 one-word queries], size: 6pt)
  cdraw.content((7.0, 3.6), [|W| x D entry reads], size: 6pt)
  cdraw.content((7.0, 3.0), [n x n x D multiplies], size: 6pt)
  // words(D) as D grows
  cdraw.content((7.0, 1.9), [words(D) = ceil(D / 64)], size: 6.5pt)
  let step = (x, d, w) => {
    cdraw.rect((x, 0.4), (x + 1.5, 0.4 + w * 0.28), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.75, 0.05), [D = #d], size: 6pt)
    cdraw.content((x + 0.75, 0.4 + w * 0.28 + 0.18), [#w], size: 6pt)
  }
  step(4.6, 64, 1)
  step(6.6, 65, 2)
  step(8.6, 256, 4)
  cdraw.content((12.2, 0.75), [D = n^(1/18) grows, words(D) unbounded], size: 6pt)
})

The 18 under 32 under 144 and the word growth to its right are the
pinned trade, and the listings below buy it in seven languages.

#listing("dsa/samples-c/src/Ch43/baselines.c", first: 174, last: 220, caption: [c, solver 2 as one AND word plus popcount against the dense thin product, three solvers cross-checked])
#listing("dsa/samples-go/ch43baselines/baselines.go", first: 110, last: 155, caption: [go, scan then pack helpers, empty middle lists pin as nil, the canonical empty slice])
#listing("dsa/samples-java/src/Ch43/Baselines.java", first: 79, last: 128, caption: [java, the scan sized in two passes then arraycopy-trimmed, `Long.bitCount` reads the AND word])
#listing("dsa/samples/src/Ch43/Baselines.cs", first: 99, last: 146, caption: [c\#, the scan as a where-filter over the range, solvers as pure functions over pinned arrays])
#listing("dsa/samples-js/src/ch43-baselines.mjs", first: 103, last: 152, caption: [javascript, hand-rolled popcount by clearing the lowest set bit, the LCG state alone in bigint])
#listing("dsa/samples-py/src/Ch43/baselines.py", first: 88, last: 124, caption: [python, the D-bit word as one arbitrary-precision int, popcount the same clear-lowest-bit loop])
#listing("dsa/samples-lua/ch43_baselines.lua", first: 112, last: 160, caption: [lua, 0-based table keys with +1 offsets at every access, native 64-bit and and or])

The corpus generator is where the trees diverge first. C, go, java,
c\#, and lua multiply and add in native 64-bit integers that wrap mod
2^64 for free. Java's historical trap is the draw itself: casting
`(int)(state >>> 32)` sign-extends when bit 63 is set, so the java
draws stay unsigned until after every modulo, the same
`Integer.remainderUnsigned` discipline the bloom hashes of chapter 25
needed. Javascript keeps only the LCG state in BigInt, one masked
multiply-add per draw, and drops to Number for the fixture values,
which stay exact because D-bit words at D = 4 and counts at most D
sit far below 2^53. Python masks an arbitrary-precision int to 64
bits, and its bitset word is the plain int, unbounded in width, so
its popcount never worries about words(D) at any D. Lua runs the LCG
on native 64-bit integers with a logical shift, and its tables keep
the fixture 0-based, paying a +1 offset at every access so the pinned
indices survive translation. Go dedupes the drawn pairs with a map
keyed on the pair struct and pins the empty middle lists as nil.

== Schoenhage's ten-multiplication identity

To beat the baselines the paper reaches inside fast matrix
multiplication. Coppersmith's 1982 rectangular algorithm builds on an
identity Schoenhage published in 1981, and the paper's contribution
is to keep only the arithmetic that wanted entries need. The identity
at L = 1, lemma 6 of section 2.2: given outer vectors x1, x2, x3 and
y1, y2, y3 plus inner 4-vectors p and q, there exist ten linear forms
phi_0 through phi_9 on the left inputs and psi_0 through psi_9 on
the right, built from zero-sum extensions p-hat whose columns sum to
the zero form and q-hat whose rows sum to the zero form, such that
the ten products phi_t times psi_t decode into all 9 outer entries
x_i y_j and the inner product p dot q. Ten multiplications buy what
schoolbook prices at 9 plus 4 equal 13, and the saving compounds in
the recursion of the next section, the same shared-work-across-
multiplications move that makes Karatsuba win in
#xref-to("dsa", "fastarith") and in #xref-to("icpc", "fastarith"),
whose measured crossovers are the family precedent.

The decode splits clean. Output zij receives only term Pij,
so c\[zij\] equals Mij with no mixing. Output z_0 receives all
ten terms, and there the identity does its canceling: the x_i y_j
monomials appear once with plus and once with minus through the P_0
forms phi_9 = -(x1 + x2 + x3) and psi_9 = y1 + y2 + y3, and the
cross terms vanish because every column of p-hat and every row of
q-hat sums to zero. What survives at z_0 is exactly the four
monomials p11 q11, p12 q12, p21 q21, p22 q22, each coefficient 1:
the schoolbook inner product, exact. Symbolically the full expansion
holds 33 distinct monomial occurrences, 13 pure ones forming the
wanted part G, the 9 outer products and the inner product, and 20
mixed ones forming the error E, and every mixed monomial weds an
outer output variable to an inner input. That shape is what the
tiling of section 4 exploits: outputs nobody wants carry error
nobody has to compute.

The dry run: the fixture is seed 4302, 14 signed draws in [-9, 9],
pinned in all 7 trees, with the identity checked three ways,
numerically, structurally, and symbolically.

+ x = \[-6, 1, -4\], p = \[-4, -1, 0, 1\], y = \[-7, 4, 9\],
  q = \[-8, 5, -7, 9\], and the ten products M pin as \[150, -63, -72,
  -14, 26, 7, 0, -16, -36, 54\].
+ The decode pins c\[z_0\] = 36, and schoolbook p dot q computes
  (-4)(-8) + (-1)(5) + 0(-7) + 1(9) = 36, exact agreement.
+ M_9 pins as -(x1 + x2 + x3)(y1 + y2 + y3) = 54, the P_0 term doing
  the canceling the identity promises.
+ G pins its 10 coefficients, E pins its 10, and the left side pins
  LHS = G + E at every output variable, lemma 6 verified entry by
  entry.
+ The zero sums are checked as forms over the 7 variables: every
  column of p-hat and every row of q-hat sums to the zero form, and
  the extensions are exactly the ones the paper prints.
+ The symbolic z_0 expansion collapses to exactly 4 monomials with
  coefficients summing to 4, the pure and mixed split counts 13
  against 20 across all 10 outputs, and gamma of equation 3 equals
  the symbolic coefficients over all 490 (s, t, z) triples.

#diagram([the identity as a pipeline: outer and inner vectors in, ten phi and psi forms, ten multiplications, decode into nine zij plus z_0 where the zero sums cancel everything except the inner product], length: 13pt, {
  let box = (x, y, w, h, label, hot) => {
    cdraw.rect((x - w / 2, y - h / 2), (x + w / 2, y + h / 2), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 8.6), [encode, multiply, decode at L = 1], size: 6.5pt)
  box(3.0, 7.6, 2.8, 0.55, [x_1 x_2 x_3, p], false)
  box(3.0, 6.2, 2.8, 0.55, [y_1 y_2 y_3, q], false)
  box(7.2, 7.6, 2.9, 0.55, [phi_0 .. phi_9], false)
  box(7.2, 6.2, 2.9, 0.55, [psi_0 .. psi_9], false)
  box(11.6, 6.9, 2.3, 0.55, [10 products], true)
  box(16.6, 7.6, 3.0, 0.55, [z11 .. z33], false)
  box(16.6, 6.2, 3.4, 0.55, [z_0 = sum of all 10], true)
  e((4.4, 7.6), (5.75, 7.6))
  e((4.4, 6.2), (5.75, 6.2))
  e((8.65, 7.6), (10.35, 7.05))
  e((8.65, 6.2), (10.35, 6.75))
  e((12.75, 6.9), (14.8, 7.6))
  e((12.75, 6.9), (14.8, 6.2))
  cdraw.content((3.0, 5.4), [p-hat columns sum 0], size: 6pt)
  cdraw.content((3.0, 4.8), [q-hat rows sum 0], size: 6pt)
  cdraw.content((11.6, 5.6), [phi_9 = -(x_1+x_2+x_3)], size: 6pt)
  cdraw.content((11.6, 5.0), [psi_9 = y_1+y_2+y_3], size: 6pt)
  cdraw.content((16.6, 5.4), [zij takes only Pij], size: 6pt)
  cdraw.content((16.6, 4.8), [z_0: xy cancel, pq survive], size: 6pt)
  cdraw.content((16.6, 4.2), [p.q = 36, exact], size: 6pt)
  cdraw.content((3.0, 3.4), [13 pure monomials = G], size: 6pt)
  cdraw.content((3.0, 2.8), [20 mixed monomials = E], size: 6pt)
  cdraw.content((3.0, 2.2), [every mixed weds outer to inner], size: 6pt)
  cdraw.content((3.0, 1.4), [10 multiplications against 13 schoolbook], size: 6pt)
})

#diagram([the monomial grid over the 7 left and 7 right variables: the pure xy block and pq block shaded, the mixed strips where the error lives], length: 13pt, {
  cdraw.content((7.6, 8.95), [monomials left_s x right_t], size: 6.5pt)
  let cell = (cx, cy, hot, edge) => {
    cdraw.rect((cx, cy), (cx + 0.92, cy + 0.72), fill: if edge { luma(215) } else if hot { luma(205) } else { luma(240) }, radius: 0.02)
  }
  // rows top to bottom = left vars 0..6, cols = right vars 0..6
  for r in range(7) {
    for c in range(7) {
      let pureXY = r < 3 and c < 3
      let purePQ = r >= 3 and c >= 3
      let x = 4.6 + c * 0.98
      let y = 7.3 - r * 0.8
      cell(x, y, pureXY or purePQ, false)
    }
  }
  cdraw.content((4.1, 7.3 - 1 * 0.8 + 0.36), [x], size: 6pt, anchor: "east")
  cdraw.content((4.1, 7.3 - 4 * 0.8 - 0.4), [p], size: 6pt, anchor: "east")
  cdraw.content((4.6 + 1 * 0.98 + 0.46, 8.35), [y], size: 6pt)
  cdraw.content((4.6 + 4 * 0.98 + 0.46, 8.35), [q], size: 6pt)
  cdraw.content((11.9, 7.4), [xy block: 9 cells], size: 6pt, anchor: "west")
  cdraw.content((11.9, 6.8), [the 9 outer products], size: 6pt, anchor: "west")
  cdraw.content((11.9, 5.9), [pq block: 16 cells], size: 6pt, anchor: "west")
  cdraw.content((11.9, 5.3), [z_0 uses 4 of them], size: 6pt, anchor: "west")
  cdraw.content((11.9, 4.4), [mixed strips: 20 occurrences], size: 6pt, anchor: "west")
  cdraw.content((11.9, 3.8), [the error E rides zij], size: 6pt, anchor: "west")
  cdraw.content((11.9, 2.9), [pure total 13 with multiplicity], size: 6pt, anchor: "west")
  cdraw.content((11.9, 2.3), [mixed total 20 across all z], size: 6pt, anchor: "west")
})

Ten multiplications against 13 is the whole saving at L = 1, and the
listings below state the identity in seven languages.

#listing("dsa/samples-c/src/Ch43/schoenhage.c", first: 264, last: 309, caption: [c, encode, the ten multiplies, decode, c\[z_0\] checked against the schoolbook inner product])
#listing("dsa/samples-go/ch43schoenhage/schoenhage.go", first: 162, last: 183, caption: [go, forms as map int to int merged in init, apply returning the ten products and the decode])
#listing("dsa/samples-java/src/Ch43/Schoenhage.java", first: 225, last: 257, caption: [java, the ten products then the z_0 sum, M_9 pinned as -(x1+x2+x3)(y1+y2+y3)])
#listing("dsa/samples/src/Ch43/Schoenhage.cs", first: 150, last: 171, caption: [c\#, form as a required-init record with eval, apply building the decode array])
#listing("dsa/samples-js/src/ch43-schoenhage.mjs", first: 96, last: 120, caption: [javascript, the `|| 0` normalizing -0 products so strict equality still pins the integers])
#listing("dsa/samples-py/src/Ch43/schoenhage.py", first: 139, last: 159, caption: [python, forms as dicts, c = m\[:9\] + \[sum(m)\] as the entire decode])
#listing("dsa/samples-lua/ch43_schoenhage.lua", first: 139, last: 161, caption: [lua, 0-based form maps so no offset leaks into the identity, apply_forms summing the ten products into z_0])

The identity is stated once and checked three ways, and the trees
differ in how they hold a linear form. C packs each form as 3 variable
indices with 3 coefficients, the sparse struct the recursion reuses
as compile-time tables in the next sections. Java mirrors the struct
with small arrays. Go and c\# keep dictionary shapes, go merging
coefficients into map[int]int during init, c\# exposing each form as a
record with required variable and coefficient arrays. Javascript and
python use Map and dict literals, and lua uses 0-based table maps so
the paper's variable numbering survives untouched. Two numerical
footnotes belong to the dynamic languages: javascript normalizes
negative zero, because 0 times a negative gives -0 and -0 fails
strict equality against the pinned 0, and python's arbitrary-precision
ints make the gamma walk over all 490 triples exact without a second
thought, where c guards the same walk with plain int arithmetic that
happens to fit.

== the recursion on strings

One identity is a constant saving. The paper compounds it by indexing
variables with strings, section 2.3.1. Fix levels L and m with m at
most L: each level of a string carries either one of 3 outer digits
or one of 4 inner digits, so a left input is an array over 7^L
strings. Lemma 9 packs C(L, m) products into one array pair: at the
strings whose inner-level set is Q, the left array holds X_Q with
rows over outer digits and columns over inner digits, and the right
array holds Y_Q transposed the same way. The algorithm Full(a, b)
then runs the identity recursively: slice both arrays by the level
variable, apply the ten sparse phi forms to the left slices and psi
forms to the right, recurse on the ten pairs, and decode the ten
child outputs into the nine zij slices plus the z_0 sum. One run
performs 10^L leaf multiplications and returns every one of the
C(L, m) packed products at once, each entry equal to schoolbook.

The shape is the point, and the fixture prices it honestly. At
L = 2, m = 1 there are N0 = 3 outer strings per side, D = 4 inner
strings, and K = C(2, 1) = 2 products packed side by side, so one
49-entry array pair feeds one run of 10^2 = 100 leaf multiplications
and returns all M = K N0^2 = 18 outputs. Schoolbook on those same 2
products costs K N0^2 D = 72. The recursion spends 100 to buy the
many-products-at-once shape, and only the tiling of the next section,
which reuses one run across many tiles, turns that shape into a win.
The encoding of section 2.4.1 is the same machinery run forward as a
recoding: one Yates-style level per string level, each term
string of length L indexing a leaf of the run, so a leaf product can
be read off as encode(a) at tau times encode(b) at tau.

The dry run: the fixture is seed 4303, a 148-value integer stream
pinned element by element and by digest, with the outputs checked
against two independent oracles.

+ Dims pin as N0 = 3, D = 4, K = 2, M = 18, and the first 8 raw LCG
  outputs pin as the seed meter stick.
+ The drawn X_Q and Y_Q matrices pin, and the lemma 9 packing pins
  the full 49-entry a and b arrays element by element.
+ One run of Full counts exactly 100 leaf multiplications, and the
  encoding arrays pin their first entries.
+ Each of the 18 output strings pins, and agrees two ways: Full
  equals the leaf sum over its contributing leaves, and the leaf sum
  equals the schoolbook inner product over the D = 4 middle strings.
+ The all-inner string (9, 9) sums all 100 leaf products, checked
  directly against the encoding arrays.
+ The honesty count: 100 leaf multiplications against 72 schoolbook,
  pinned as a comparison, the recursion losing at toy scale by
  design.

#diagram([the string recursion at L = 2: the 7 x 7 packed array, ten term children of width 7, one hundred leaves, and the 18 outputs read back against schoolbook], length: 13pt, {
  let box = (x, y, w, h, label, hot) => {
    cdraw.rect((x - w / 2, y - h / 2), (x + w / 2, y + h / 2), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 8.6), [Full over strings, L = 2, m = 1], size: 6.5pt)
  box(2.6, 7.0, 2.6, 1.1, [49 strings, 7 x 7], true)
  box(8.0, 7.0, 3.2, 0.9, [10 term children, width 7 each], false)
  box(14.2, 7.0, 2.9, 0.9, [100 leaves], false)
  box(19.6, 7.0, 2.7, 0.9, [18 outputs], true)
  e((3.9, 7.0), (6.4, 7.0))
  e((9.6, 7.0), (12.75, 7.0))
  e((15.65, 7.0), (18.25, 7.0))
  cdraw.content((2.6, 5.9), [inner levels Q = {0} and {1}], size: 6pt)
  cdraw.content((2.6, 5.3), [hold X_Q, Y_Q side by side], size: 6pt)
  cdraw.content((8.0, 5.9), [slice by the level variable], size: 6pt)
  cdraw.content((8.0, 5.3), [phi, psi sparse forms], size: 6pt)
  cdraw.content((14.2, 5.9), [one multiply per leaf], size: 6pt)
  cdraw.content((14.2, 5.3), [read from encodings], size: 6pt)
  cdraw.content((19.6, 5.9), [9 zij + z_0 per tile], size: 6pt)
  cdraw.content((19.6, 5.3), [equals schoolbook], size: 6pt)
  // the counted row
  box(8.0, 3.6, 3.6, 0.7, [Full: 100 leaf multiplies], true)
  box(14.2, 3.6, 3.6, 0.7, [schoolbook: 72], false)
  cdraw.content((11.0, 2.6), [100 \> 72: one run buys all K = 2 products at once], size: 6pt)
  cdraw.content((11.0, 1.9), [the win arrives when tiles share one run], size: 6pt)
})

One run returning a whole family of products is the recursion's
contract, and the listings below run it in seven languages.

#listing("dsa/samples-c/src/Ch43/recursion.c", first: 113, last: 153, caption: [c, Full verbatim, slice, ten children, decode into nine zij slices plus the z_0 sum])
#listing("dsa/samples-go/ch43recursion/recursion.go", first: 98, last: 146, caption: [go, the recursion as a closure over the leaf counter, slices handed down and copied back])
#listing("dsa/samples-java/src/Ch43/Recursion.java", first: 68, last: 105, caption: [java, a static leaf counter, the decode summing the z_0 column, the 148-int stream digest pinned])
#listing("dsa/samples/src/Ch43/Recursion.cs", first: 121, last: 166, caption: [c\#, Full returning leaf count and output as a tuple, Rec a local function])
#listing("dsa/samples-js/src/ch43-recursion.mjs", first: 91, last: 138, caption: [javascript, rec returning its slice, values in Number with only the LCG state in bigint])
#listing("dsa/samples-py/src/Ch43/recursion.py", first: 82, last: 128, caption: [python, slices as list comprehensions, the mix helper applying the sparse forms per level])
#listing("dsa/samples-lua/ch43_recursion.lua", first: 124, last: 171, caption: [lua, the same recursion with the +1 offsets spelled at every array access])

The recursion is where the leaf plumbing divides the trees. C and java
allocate the ten child inputs on fixed-size stack arrays and recurse
with raw pointers or array references. Go, c\#, and javascript build
the children as fresh slices or arrays per level. Python states the
slicing as comprehensions and its packing as a dictionary walk over
itertools.product digit tuples, the same algorithm with the index
arithmetic delegated to tuples. Lua threads 1-based tables through
0-based paper indices, every access paying the explicit +1. Java
carries this section's generator trap visibly: the draw is
`(int)(lcgState >>> 32)` narrowed only after the unsigned modulo, and
the seed meter stick pins the first 8 raw outputs with a
`& 0xFFFFFFFFL` mask so the pin itself cannot sign-extend. The
148-value stream is pinned element by element in c, java, c\#, and
python, and by its sha256 digest in java, go, c\#, javascript, and
python, the chapter's digest rule of decimal integers, one per line.

== tiling and the shared encoding

The recursion computes K products per run. A thin product wants n^2
entries of an n x D times D x n product, so the paper tiles,
section 2.3.4: cut the product into N0 x D by D x N0 block products,
group row blocks into bands of K0 = floor(sqrt(K)) blocks, and run
Full once per tile, exactly the banding move of the sqrt
decomposition in #xref-to("dsa", "blocks"). The saving is that the
phi encoding of a row band and the psi encoding of a column band are
computed once and shared by every tile that touches the band. A tile
run multiplies every leaf of its band encodings, all 10^L of them,
and reads only the 9 output strings whose inner set matches the
tile's fixed subset, the error monomials riding the outputs nobody
reads.

The honest count at the fixture is the section's teaching point. With
N = 6, D = 4, N0 = 3, K = 2, K0 = 1, the grid holds 2 row bands and
2 column bands, so 4 tiles, and the whole 6 x 6 product costs 4
encodings, 2 phi plus 2 psi, and 4 times 10^L = 400 leaf
multiplications. Schoolbook on the same product costs N^2 D = 144.
The algorithm loses by a factor near 3, on purpose, because the
per-tile pass performs a full-leaf run: 400 is the realized cost, not
a modeling artifact. The win is asymptotic, arriving when K grows so
that one shared encoding serves K0 tiles per band and the wanted
fraction of outputs shrinks, and the fixture pins the loss so the
asymptotic claim has a measured floor under it.

The dry run: the fixture is seed 4304, a 50-value integer stream
pinned element by element and by digest.

+ Dims pin as N0 = 3, D = 4, K = 2, K0 = 1, the band count
  (N / N0 / K0)^2 = 4, and the first 8 raw LCG outputs pin.
+ X and Y pin as the 6 x 4 and 4 x 6 drawn matrices, and schoolbook
  pins the full 6 x 6 product XY at exactly 144 multiplies.
+ Exactly 4 encodings are computed, 2 phi for the row bands and 2 psi
  for the column bands, and their first entries pin.
+ The 4 tile runs multiply 400 leaves total, assemble the same XY
  entry for entry, and the corner entries pin, XY\[0\]\[0\] = 16 and
  XY\[5\]\[5\] = 12.
+ The counted row pins as \[400, 144\] with the comparison asserted:
  the algorithm spends more leaf multiplications than schoolbook at
  this scale, and the test says so out loud.

#diagram([the 6 x 6 product as a 2 x 2 grid of 3 x 3 tiles, one phi encoding per row band and one psi per column band shared by the tiles, 400 leaf multiplications against 144 schoolbook], length: 13pt, {
  cdraw.content((9.0, 8.6), [bands of K0 = 1 blocks, one run per tile], size: 6.5pt)
  let tile = (x, y, name, hot) => {
    cdraw.rect((x, y), (x + 2.8, y + 1.7), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.4, y + 1.15), name, size: 6pt)
    cdraw.content((x + 1.4, y + 0.5), [100 leaves], size: 6pt)
  }
  cdraw.content((6.4, 7.6), [psi 0], size: 6pt)
  cdraw.content((10.0, 7.6), [psi 1], size: 6pt)
  cdraw.content((3.9, 7.6), [phi 0], size: 6pt, anchor: "east")
  cdraw.content((3.9, 5.35), [phi 1], size: 6pt, anchor: "east")
  tile(5.0, 5.6, [tile (0, 0)], true)
  tile(8.6, 5.6, [tile (0, 1)], false)
  tile(5.0, 3.4, [tile (1, 0)], false)
  tile(8.6, 3.4, [tile (1, 1)], false)
  cdraw.content((9.0, 2.7), [4 encodings total, 2 phi + 2 psi], size: 6pt)
  cdraw.content((9.0, 2.0), [4 tiles x 10^L = 400 leaf multiplies], size: 6pt)
  cdraw.content((9.0, 1.3), [schoolbook: N^2 D = 144, the tile road loses at toy scale], size: 6pt)
  cdraw.content((15.4, 6.0), [each tile reads 9 output], size: 6pt)
  cdraw.content((15.4, 5.4), [strings, inner set {0},], size: 6pt)
  cdraw.content((15.4, 4.8), [the error rides the rest], size: 6pt)
})

Four shared encodings against four full-leaf runs is the whole
mechanism, and the listings below tile the product in seven
languages.

#listing("dsa/samples-c/src/Ch43/tiling.c", first: 186, last: 235, caption: [c, one phi per row band and one psi per column band, the tile loop reading only the 9 wanted strings])
#listing("dsa/samples-go/ch43tiling/tiling.go", first: 160, last: 191, caption: [go, tile returning the assembled product and the leaf count, bands = N/N0/K0])
#listing("dsa/samples-java/src/Ch43/Tiling.java", first: 148, last: 196, caption: [java, encodings once per band, every leaf of the run multiplied, t1 \< 9 summed into the outputs])
#listing("dsa/samples/src/Ch43/Tiling.cs", first: 140, last: 189, caption: [c\#, band encodings as a tuple-returning pass, tile sharing them across the grid])
#listing("dsa/samples-js/src/ch43-tiling.mjs", first: 112, last: 159, caption: [javascript, spread and fill arrays, `dg / 3 | 0` truncating the row digit])
#listing("dsa/samples-py/src/Ch43/tiling.py", first: 173, last: 218, caption: [python, band arrays built by digit arithmetic, the counted row \[400, 144\] asserted with the comparison])
#listing("dsa/samples-lua/ch43_tiling.lua", first: 179, last: 212, caption: [lua, the tile loop with 1-based band indexing and floor division digits])

The tiling code is nearly identical across the trees, because the
mechanism is index arithmetic. The differences are representational:
c computes into a fixed 49-entry band array and reads the encodings
from 100-entry buffers, go and c\# return the band encodings as
slices and tuples, javascript fills fresh arrays per level, python
builds each band array by digit arithmetic into a zero list, and lua
pays its +1 offsets at every band access. Every tree pins the same
counted row, 4 encodings and 400 leaf multiplications against 144
schoolbook multiplies, so the honesty claim is cross-checked by
construction, one loss measured seven ways.

== pruning the recursion and counting leaves

Full multiplies every leaf of every run. The wanted entries are few,
so section 2.4.2 prunes: pass the wanted set U down as sorted suffix
sets, skip every child whose suffix set is empty, and read leaf
values from the precomputed encodings. Child t under 9 receives the
union of suffix slices z_t and z_9, because a z_0 output at this
level consults every term below, and child 9 receives z_9 alone. The
paper then counts what the pruning visits. Lemma 10: the visited
leaves are exactly Leaves(U), the union over wanted strings of their
contributing leaves, the fixed term at zij levels and any term at
z_0 levels. Lemma 11: that union sits under a per-order min of
|U| alpha_d and beta_d, where alpha_d = C(m, d) 9^d counts the
leaves of order d feeding one output string and beta_d = C(L, m-d)
9^(L-m+d) counts them across the whole tree.

The fixture runs two instances off one stream and lands just under
the lemma 11 bounds, which is the closest a small instance can come
to showing the bounds are real. Instance A, L = 3, m = 1, |U| = 12:
the recursion visits 118 leaves, the directly enumerated union is
also 118, and the lemma 11 bound is 120. Instance B, L = 6, m = 2,
|U| = 40: 3996 leaves against a bound of 4000. The calls and the
total suffix-set sizes are instrumented too, 182 calls and a
set_total of 262 for A, 9317 and 10716 for B, the set_total staying
inside (L + 1) times the leaf count, which is the recursion's real
memory discipline.

The dry run: the fixture is seed 4305 with both instances off the
one stream, plus the paper's own arithmetic pinned as tables.

+ The seed meter stick pins 3 raw draws, then instance A draws: X_Q
  spot rows pin, the first wanted string pins as digits \[0, 9, 8\],
  and every wanted string carries exactly one 9.
+ On A the pruned values equal the leaf-sum oracle and the schoolbook
  oracle on all 12 strings, all three pinned.
+ Instance B continues the same stream: dims pin N0 = 81, D = 16,
  K = 15, M = 98415, spot rows and the first wanted string pin, every
  wanted string carries exactly two 9s.
+ On B the same three-way agreement pins on all 40 strings, with
  3996 leaves against the lemma 11 cap of 4000.
+ The paper's own L = 6, m = 2 table pins exactly: alpha = \[1, 18,
  81\], beta = \[98415, 354294, 531441\], sharing C(4+d, d) = \[1, 5,
  15\], and the identity M alpha_d = beta_d C(L-m+d, d) holds as an
  exact equality for every d.
+ The decay ratios pin: beta_1 / beta_0 = 18/5 and beta_2 / beta_1 =
  3/2, and the regimes (19, 1), (38, 2), (21, 2) pin their betas as
  decimal strings, the largest past 10^37 and beyond 64 bits, with
  the lemma 11 closed form checked by 9th powers at L = 19m where
  the bound carries an irrational 2^(-m/9) factor.

#diagram([the pruned recursion on suffix sets: wanted suffixes sliced by leading digit, children merged and deduped, only nonempty children recursed, leaves read from the encodings], length: 13pt, {
  let box = (x, y, w, label, hot) => {
    cdraw.rect((x - w / 2, y - 0.3), (x + w / 2, y + 0.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b, dashed) => cdraw.line(a, b, stroke: if dashed { (paint: luma(160), dash: "dashed") } else { luma(100) }, mark: (end: ">"))
  cdraw.content((10.0, 8.6), [pruned, instance A: 12 strings, 118 leaves], size: 6.5pt)
  box(3.2, 7.6, 3.4, [U sorted, 12 suffixes], true)
  box(9.0, 7.6, 4.4, [slice by leading digit z], false)
  box(15.6, 7.6, 4.6, [child t: union of z_t and z_9], false)
  box(20.6, 6.4, 2.6, [empty children skipped], false)
  box(9.0, 6.4, 3.6, [child 9: z_9 alone], false)
  e((4.9, 7.6), (6.75, 7.6), false)
  e((11.25, 7.45), (12.6, 7.05), false)
  e((11.2, 7.75), (12.6, 8.0), false)
  e((17.9, 7.3), (19.3, 6.7), false)
  cdraw.content((9.0, 5.6), [z_0 suffixes sum every live child], size: 6pt)
  cdraw.content((9.0, 5.0), [values read back by position], size: 6pt)
  box(3.2, 4.2, 3.4, [118 leaves visited], true)
  box(9.0, 4.2, 3.4, [lemma 11 cap 120], false)
  box(15.0, 4.2, 4.4, [enumerated union 118, equal], false)
  e((4.9, 4.2), (7.3, 4.2), false)
  e((10.7, 4.2), (13.3, 4.2), false)
  cdraw.content((3.2, 3.3), [calls 182, set_total 262], size: 6pt)
  cdraw.content((3.2, 2.7), [262 \<= 4 x 118], size: 6pt)
  cdraw.content((10.0, 2.0), [instance B: 3996 leaves under the 4000 cap, 9317 calls], size: 6pt)
  cdraw.content((10.0, 1.3), [pruned = leaf sum = schoolbook on every wanted string], size: 6pt)
})

#diagram([the paper's leaf-count table at L = 6, m = 2 as bars: alpha per output string against beta across the tree, the exact identity M alpha_d = beta_d C(4+d, d), and the decay 18/5 then 3/2], length: 13pt, {
  let bar = (x, w, y, label, val, hot) => {
    cdraw.rect((x, y), (x + w, y + 0.55), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w + 0.3, y + 0.28), [#val], size: 6pt)
    cdraw.content((x - 0.2, y + 0.28), label, size: 6pt, anchor: "east")
  }
  cdraw.content((11.0, 8.6), [alpha: leaves of order d for one string], size: 6.5pt)
  bar(4.4, 0.25, 7.5, [d = 0], 1, false)
  bar(4.4, 1.5, 6.75, [d = 1], 18, true)
  bar(4.4, 5.0, 6.0, [d = 2], 81, false)
  cdraw.content((11.0, 5.3), [beta: leaves of order d, whole tree], size: 6.5pt)
  let bw = v => v / 531441 * 7.2
  bar(4.4, bw(98415), 4.3, [d = 0], 98415, false)
  bar(4.4, bw(354294), 3.55, [d = 1], 354294, true)
  bar(4.4, bw(531441), 2.8, [d = 2], 531441, false)
  cdraw.content((4.4, 2.0), [beta_1 / beta_0 = 18/5, beta_2 / beta_1 = 3/2], size: 6pt)
  cdraw.content((4.4, 1.3), [M alpha_d = beta_d C(4+d, d), exact for every d], size: 6pt)
  cdraw.content((15.5, 4.0), [regimes (19,1), (38,2), (21,2):], size: 6pt)
  cdraw.content((15.5, 3.4), [beta pinned as decimal strings,], size: 6pt)
  cdraw.content((15.5, 2.8), [the (38,2) betas pass 10^37], size: 6pt)
  cdraw.content((15.5, 2.2), [lemma 11 closed form at L = 19m], size: 6pt)
  cdraw.content((15.5, 1.6), [checked by 9th powers], size: 6pt)
})

The pruned values agree with two oracles on every wanted string, and
the listings below prune in seven languages.

#listing("dsa/samples-c/src/Ch43/pruned.c", first: 392, last: 439, caption: [c, suffix sets sliced by leading digit, frame-local child buffers, the z_0 suffix summing every live child])
#listing("dsa/samples-go/ch43pruned/pruned.go", first: 358, last: 404, caption: [go, mergeDedup children, values found by sort.SearchInts inside the closure])
#listing("dsa/samples-java/src/Ch43/Pruned.java", first: 256, last: 296, caption: [java, ArrayList slices, Arrays.binarySearch reading each child value, the 39378-int stream digest pinned])
#listing("dsa/samples/src/Ch43/Pruned.cs", first: 211, last: 260, caption: [c\#, the recursion as a local function in PrunedRun, Array.BinarySearch over merged suffixes])
#listing("dsa/samples-js/src/ch43-pruned.mjs", first: 260, last: 300, caption: [javascript, set-spread merges sorted numerically, a Map from suffix to value at every level])
#listing("dsa/samples-py/src/Ch43/pruned.py", first: 193, last: 226, caption: [python, sorted(set(...)) child merges, dict values keyed by suffix, native ints pin the regime betas whole])
#listing("dsa/samples-lua/ch43_pruned.lua", first: 288, last: 332, caption: [lua, seen-table dedupe then table.sort, the out table keyed by suffix index])

The suffix machinery separates the imperative trees from the
declarative ones. C merges the two sorted slices by hand into
frame-local arrays and reads child values back with a linear scan.
Go, java, and c\# keep the same merge but read values back by binary
search, sort.SearchInts, Arrays.binarySearch, Array.BinarySearch.
Javascript spreads two arrays into a Set and sorts numerically,
python sorts a set comprehension, and lua dedupes through a seen
table before table.sort. The regime tables are where the integer
widths divide the trees: the (38, 2) betas reach 38 digits and pass
64 bits, so c hand-rolls a base-10^9 bignum, lua a base-10^4 one, go
rides math/big, java BigInteger, c\# System.Numerics.BigInteger,
javascript BigInt, and python pins the full integers natively, the
only tree that compares them as numbers, with the decimal strings
pinned beside them for the others.

== boxes, the online data structure

Theorem 3, page 7, turns the offline algorithm into a data
structure: preprocess the pair (X, Y) in O(N^2 / D^0.063) time, then
answer any single entry (XY)[I, J] in O(D^0.437) time. Section 4.2
builds it from boxes. A box is a set of leaves at once: a string over
the ten terms plus a star symbol that allows every term at a level,
with at most m - t special levels split between stars and P_0
markers, the stars sitting below the P_0s. Lemma 29 computes every
box value bottom-up by expanding the highest star, a box with e stars
equal to the sum of its 10 children with e - 1 stars, down to the
zero-star boxes that are single leaf products. Theorem 30 answers a
query for one output string w as the leaves of order below t read
one by one, at t = 1 exactly one private leaf, plus the alpha_t box
values that lemma 28 proves partition the remaining leaves.

The toy shape pins the mechanics and the honesty in one file. At
L = 4, m = 2, t = 1 there are K = 6 inner sets, N0 = 9, D = 16, and
M = 486 output strings. The box count is the formula: (f + 1) C(L, f)
9^(L - f) summed over f from 0 to m - t, which evaluates to 12393.
Every box value equals its brute cube sum, the sum of leaf products
over the box's leaves, and lemma 27's unique-V property holds for all
6 inner sets while lemma 28's boxes partition the order at least t
leaves of every one of the 486 strings. A query then reads 1 private
leaf and 18 box values, 19 reads against the 10^m = 100 leaf
products of the direct cube. The honesty is pinned in the file: the
decay ratio rho = 9m / (L - m + 1) = 6 at this shape, above 1, and
the beta decay that pays for the preprocessing needs L at least 10m,
so the mechanics are exact and no preprocessing efficiency is
claimed.

The dry run: the fixture is seed 4306, a 1751-value integer stream
pinned by digest with spot rows pinned element by element.

+ The seed meter stick pins 3 raw draws, X_Q spot rows pin, and the
  first drawn query pins as digits \[2, 9, 9, 2\] with its 2 nines
  marking the inner levels.
+ The box count pins as 12393, the enumeration matching the closed
  formula, and every enumerated box satisfies the shape rule: at
  most m - t special symbols, stars below the P_0s.
+ The DP values equal the brute cube sums on all 12393 boxes.
+ Lemma 27 holds for all 6 inner sets, and lemma 28's partition holds
  on all 486 output strings, box leaves against order at least t
  leaves, multiset equal.
+ Every one of the 486 strings answers through 1 leaf read plus 18
  box reads and equals schoolbook, and the 5 drawn queries pin their
  values as \[-9, -1, 7, 3, 1\] with the counted row \[19, 100\].
+ rho pins as 6, above 1, with the L at least 10m requirement stated
  and asserted in the same breath.

#diagram([the box lattice and the query path: zero-star boxes as leaf products, one-star boxes as sums of 10 children, and a query reading 1 private leaf plus 18 box values against 100 direct leaf products], length: 13pt, {
  let box = (x, y, w, label, hot) => {
    cdraw.rect((x - w / 2, y - 0.32), (x + w / 2, y + 0.32), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 8.6), [boxes, lemma 29 bottom up], size: 6.5pt)
  box(4.0, 7.4, 4.2, [e = 1: one star, sum of 10 children], true)
  box(4.0, 6.2, 4.2, [e = 0: leaf products], false)
  e((4.0, 7.08), (4.0, 6.52))
  cdraw.content((10.5, 7.4), [12393 boxes at L = 4, m = 2, t = 1], size: 6pt)
  cdraw.content((10.5, 6.8), [every value = its brute cube sum], size: 6pt)
  // query path
  box(4.0, 4.6, 3.0, [query string w], true)
  box(9.0, 4.6, 3.4, [1 private leaf], false)
  box(14.4, 4.6, 4.0, [18 box values, alpha_t], true)
  box(19.8, 4.6, 3.2, [total 19 reads], false)
  e((5.5, 4.6), (7.3, 4.6))
  e((10.7, 4.6), (12.4, 4.6))
  e((16.4, 4.6), (18.2, 4.6))
  box(9.0, 3.2, 3.8, [direct cube: 100 leaf products], false)
  cdraw.content((14.5, 3.2), [lemma 28: the 18 boxes partition], size: 6pt)
  cdraw.content((14.5, 2.6), [the order at least t leaves of w], size: 6pt)
  cdraw.content((4.0, 2.0), [honesty: rho = 9m/(L-m+1) = 6 \> 1], size: 6pt)
  cdraw.content((4.0, 1.4), [the decay needs L at least 10m], size: 6pt)
  cdraw.content((4.0, 0.8), [mechanics exact, efficiency not claimed], size: 6pt)
})

One query priced at 19 reads against 100 is the structure's contract
at toy scale, and the listings below build the lattice in seven
languages.

#listing("dsa/samples-c/src/Ch43/boxes.c", first: 238, last: 286, caption: [c, the DP inline in the enumeration, zero-star boxes as leaf products, others expanding the highest star])
#listing("dsa/samples-go/ch43boxes/boxes.go", first: 288, last: 325, caption: [go, boxes grouped by star count in a map, the base-11 index keying the value slice])
#listing("dsa/samples-java/src/Ch43/Boxes.java", first: 241, last: 273, caption: [java, byStars lists per star count, the 1751-int stream digest pinned beside the spot rows])
#listing("dsa/samples/src/Ch43/Boxes.cs", first: 246, last: 283, caption: [c\#, a byStars dictionary walked in Keys.Order, the star count taken by LINQ])
#listing("dsa/samples-js/src/ch43-boxes.mjs", first: 241, last: 272, caption: [javascript, the +0 normalizing -0 leaf products before they enter the sums])
#listing("dsa/samples-py/src/Ch43/boxes.py", first: 183, last: 219, caption: [python, boxes as tuples keyed in a dict, tuple splicing replacing the highest star])
#listing("dsa/samples-lua/ch43_boxes.lua", first: 242, last: 286, caption: [lua, the DP inline in fill_rest, 1-based star levels, table.unpack copies])

The box enumeration is the same recursion everywhere, and the value
store splits the trees. C and java index a flat array by the base-11
reading of the box, digits 0 through 9 plus the star symbol. Go keeps
the flat slice with the same index but groups boxes by star count in
a map first. C\# groups in a Dictionary and walks Keys.Order.
Javascript keeps the flat array with a Map for grouping. Python keys
a dict by the box tuple itself and splices the highest star with
slice arithmetic, the most literal reading of the lemma. Lua runs the
DP inline in its enumeration helper over 1-based levels. Javascript
carries a second numerical footnote: leaf products that evaluate to
negative zero get a +0 so the pinned integers survive strict
equality, the same normalization the identity section needed.

== exact triangle by hashing weights modulo a prime

The home problem is abstract until something reduces to it. Theorem
17, page 33, reduces exact triangle deterministically: given a
tripartite graph with integer weights, decide whether any a, b, c has
S(a, b, c) = w(a, b) + w(a, c) + w(b, c) equal to 0. The reduction
hashes the weights modulo a prime p in [sqrt(D)/2, sqrt(D)) chosen
for the fewest false positives, builds at most 4ng instances of
Lop-AE-SparseTri(n, D), and scans accepted pairs for a witness. The
counting trick that prices each prime is old and good, Zwick 2002
following a 1997 idea: build matrices P and Q over the ring
Z\[x\]/(x^p - 1) with P\[a\]\[c\] = x^(w(a,c) mod p) and Q\[c\]\[b\] =
x^(w(b,c) mod p), so the coefficient of x^r in the product (PQ)\[a\]\[b\]
counts the c with w(a, c) + w(b, c) congruent to r mod p, and summing
the coefficient of x^(-w(a,b) mod p) over all pairs yields F(p) + Z0,
false positives plus zero triangles. The paper's derandomized
selection scans the primes of the range and picks the minimum, which
lands under the mean: min at most mean. The deterministic prime
selection follows the 3SUM reduction of Fischer, Kaliciak, and Polak,
while the instance construction and witness scan follow Chan and Xu,
both 2024.

An instance is a chunk of pairs against a piece of the c side. The
middle part holds the piece's vertices paired with the p labels, at
most D of them. The pair (a, b) shares the label (c, sigma) exactly
when sigma = w(a, c) + rho and sigma = -w(b, c) mod p, so a common
neighbor in the instance means S(a, b, c) congruent to 0 mod p on
some c of the piece, and acceptance is one AND of two bitmasks over
the piece-times-label positions. A zero triangle always survives
hashing, so the scan of accepted pairs finds a witness iff one
exists, and the decision is exact.

The dry run: the fixture is seed 4301 at n = 16, D = 16, g = 1, with
brute O(n^3) as the oracle throughout.

+ The three weight matrices draw signed in [-16, 16] row major, the
  first rows pin, the last draws pin, and every weight sits within
  the n^1 span.
+ The ring counts pin: 2014 over Z\[x\]/(x^2 - 1) and 1355 over
  Z\[x\]/(x^3 - 1), against Z0 = 91 zero triangles from brute force.
+ The false-positive counts F = \[1923, 1264\], and the choice pins:
  min at most mean reads 2 x 1264 = 2528 at most 1923 + 1264 = 3187,
  so p = 3 wins.
+ The road builds 24 instances, inside the 4ng = 64 bound, with piece
  4, h = 4, cap 64, middle parts of 12 = piece x p vertices inside
  D = 16, the largest chunk at 64 = n^2 / s pairs, and 1024 = n^2 h
  total queries.
+ The oracle accepts 815 pairs, and a direct S congruent 0 mod p
  scan over every instance reproduces the same 815.
+ The witness scan finds (0, 6, 2) with S = 0 verified, while brute
  force reports (0, 2, 10) first: the two witnesses differ and both
  are real, the reduction returns a witness, never the
  lexicographically first one.

#diagram([theorem 17 as a pipeline: weights hashed modulo both primes, the ring counts choosing p = 3, chunk-piece instances with label bitmasks, accepted pairs scanned for a witness], length: 13pt, {
  let box = (x, y, w, label, hot) => {
    cdraw.rect((x - w / 2, y - 0.34), (x + w / 2, y + 0.34), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 8.7), [exact triangle to Lop-AE-SparseTri, deterministically], size: 6.5pt)
  box(2.9, 7.5, 3.6, [weights, 3 matrices], false)
  box(8.6, 7.5, 6.0, [ring counts over Z\[x\]/(x^p - 1)], false)
  box(15.2, 7.5, 3.0, [choose p = 3], true)
  box(19.9, 7.5, 3.2, [24 instances], false)
  e((4.7, 7.5), (5.6, 7.5))
  e((11.6, 7.5), (13.7, 7.5))
  e((16.7, 7.5), (18.3, 7.5))
  cdraw.content((8.6, 6.6), [2014 at p = 2, 1355 at p = 3, Z0 = 91], size: 6pt)
  cdraw.content((8.6, 6.0), [F = [1923, 1264], min \<= mean: 2528 \<= 3187], size: 6pt)
  box(5.8, 5.0, 5.0, [chunks of n^2/s = 64 pairs], false)
  box(12.3, 5.0, 5.8, [pieces of 4 c-vertices x 3 labels], false)
  box(19.0, 5.0, 5.6, [bitmasks x\[a\], y\[b\], AND test], true)
  e((8.3, 5.0), (9.4, 5.0))
  e((15.2, 5.0), (16.2, 5.0))
  box(19.4, 3.7, 4.4, [815 accepted pairs], false)
  box(13.4, 2.6, 5.4, [witness scan: (0, 6, 2), S = 0], true)
  e((19.4, 4.66), (19.4, 4.04))
  e((17.2, 3.6), (16.1, 2.95))
  cdraw.content((6.0, 3.7), [middle parts of 12 \<= D = 16 vertices], size: 6pt)
  cdraw.content((6.0, 3.1), [1024 = n^2 h queries total], size: 6pt)
  cdraw.content((6.0, 2.5), [brute first witness (0, 2, 10), both real], size: 6pt)
})

The reduction is exact and its constants are countable, and the
listings below build the road in seven languages.

#listing("dsa/samples-c/src/Ch43/extriangle.c", first: 111, last: 158, caption: [c, x\[a\] and y\[b\] as bitmasks over piece times label positions, acceptance one AND])
#listing("dsa/samples-go/ch43/extriangle.go", first: 204, last: 243, caption: [go, uint32 label masks, the witness scan in instance order with named fields])
#listing("dsa/samples-java/src/Ch43/Extriangle.java", first: 110, last: 158, caption: [java, masks at ci x p + label, chunks of n^2/s pairs, the 772-int stream digest pinned])
#listing("dsa/samples/src/Ch43/Extriangle.cs", first: 155, last: 195, caption: [c\#, tuple lists and a goto done exiting the witness scan, the road as a record])
#listing("dsa/samples-js/src/ch43-extriangle.mjs", first: 116, last: 158, caption: [javascript, a labeled break outer for the witness, ceil and sqrt from Math])
#listing("dsa/samples-py/src/Ch43/extriangle.py", first: 94, last: 141, caption: [python, comprehension chunks, ceilings by negated floor division, isqrt for the prime range])
#listing("dsa/samples-lua/ch43_extriangle.lua", first: 108, last: 149, caption: [lua, (x[v] or 0) folds building the masks, 1-based piece ranges])

The instances are built identically everywhere, and the masks divide
the trees by width. C uses unsigned words, go uint32, java and c\#
and javascript int, python arbitrary precision, lua native 64-bit.
The witness scan exits by flag, break, or jump in the sample corpus: c sets a
found flag, go and java break through labeled state, c\# jumps to a
goto label, javascript breaks a labeled outer loop, python breaks
out of nested loops with witness checks, lua walks with explicit
breaks. Java and go pin the whole 772-value stream by sha256 digest,
the same decimal-per-line rule as every stream in this chapter, while
c, c\#, and lua pin representative rows, and python pins both rows
and digest.

== consequences: 3SUM, min-plus products, and bridges

The end of the chain is where the paper's title lives. Theorem 19,
page 35: exact triangle is decidable in O(n^(3-0.00175) log n),
weakened to O(n^2.9983) without the log, by plugging the data
structure of section 6 into theorem 17's instances, and the same tower
with theorem 5 at its base gives O(n^(3-1/648) log^2 n) for exact
triangle as its other bound. Theorem
22, page 36: 3SUM on n integers falls to n^(2-1/1296), about
n^1.99923, and APSP and the min-plus product fall to
O(n^(3-1/1944)), about n^2.99949. This section pins the min-plus leg
as code: repeated squaring with witnesses meeting the floyd-warshall
of #xref-to("dsa", "shortestpaths") on a pinned matrix, one greedy
level of Zwick's bridging-set reduction brute-verified per stage, and
the 3SUM chain run against a hash baseline with the op difference
counted. The bridge word needs one disambiguation: a bridging set of
Zwick 2002 is a set of vertices through which long shortest paths
pass, unrelated to the graph bridges of #xref-to("dsa",
"connectivity").

The squaring fixture draws an n = 24 digraph at 12 percent edge
probability with weights h(v) - h(u) + r and r at least 0, so the
potential h kills every negative cycle while 15 edges still go
negative, the no-negative-cycle precondition the theorems carry. Five
squarings, ceil(log2 24), at 28141 min-comparisons land the same
576-entry distance matrix as floyd-warshall at 2290 finite
relaxations, every finite entry carrying a valid argmin witness, 89
pairs unreachable, the longest fewest-edge shortest path at 10 edges.
The sentinel leak is pinned as a regression: with the guard, an
unreachable pair stays at INF, without it, INF plus a negative edge
reads 9999995 and the sentinel poisons the matrix.

The bridge fixture runs Zwick's schedule with s doubling 1, 2, 4, 8,
16, 24 and slack C growing by C' = 2C + 2 through 1, 4, 10, 22, 46.
Each level recovers walks of at most horizon = C x s edges through
every current bridge vertex, erases cycles, keeps paths of at least
ceil(s/2) edges, and hits them with the greedy set cover of
#xref-to("dsa", "greedy"). The chain shrinks 24, 16, 10, 5, 1, and
every level's output is brute-verified as an (s, C)-bridge: every
pair with eta at least s has a shortest walk through a bridge vertex
within C eta edges. The honesty row is stage 2 at s = 8, where road A pays
29563 realized walk edges against a budget of n^2 s = 4608: the
deterministic reduction loses at toy scale exactly as the tiling of
section 4 did, and only the subcubic solver at the top of the tower
pays off.

The dry run closes the chapter's honesty account, worked from the
paper's own constants.

+ The graph pins its potential row and adjacency rows, 56 edges of
  552 cells at the 12 percent draw, 15 negative, diagonal zero.
+ Floyd-warshall pins 2290 finite relaxations and the full 576-entry
  matrix, 89 unreachable, no negative cycle on the diagonal.
+ Five squarings pin 28141 min-comparisons, the same matrix, and a
  valid witness for every finite entry, with the op difference
  against floyd-warshall asserted, 28141 over 2290.
+ The leak regression pins both readings of one unreachable pair:
  INF guarded, 9999995 leaked.
+ The bridge schedule pins all four stages, sizes 16, 10, 5, 1 after
  the initial 24, with kept paths, walks, and realized edges per
  stage, the (s, C)-bridge property brute-verified at every level,
  and the stage 2 row 29563 against 4608 asserted as the honest loss.
+ The 3SUM chain draws three 16-value lists from the continuing
  stream, finds a zero triple with no planting needed, and pins the
  hash baseline at 257 ops with witness (16, -11, -5) against the
  road at 12349 ops over 20 instances with witness (3, 2, -5), both
  summing to 0.
+ The regime math, stated from the paper's exponents: D at most
  n^(1/18) evaluates to 1.67 at n = 10^4 and 2.53 at n = 1.8 x 10^7,
  so the middle part holds 1 or 2 vertices at every real size. The
  D^0.063 preprocessing saving reaches a factor of 2 only at D about
  6 x 10^4, which forces N at least D^18, about 10^86. The exact
  triangle exponent saves 1.9 percent at n = 10^5 and 3.5 percent at
  10^9, 3SUM 0.9 and 1.6 percent, APSP 0.6 and 1.1. The reduction's
  own constants sit on top: 4ng instances, and a Strassen ring
  multiplication n^(log2 7) D^(3/2), about n^2.89 at D = n^(1/18),
  still costing about 28 percent of the brute cube at n = 10^5. The
  paper keeps only half the exponent saving through its exact
  triangle reduction, its own accounting, and states on page 61 that
  the balanced case of AE-SparseTri is explicitly not improved.

#diagram([zwick's bridge chain 24, 16, 10, 5, 1: s doubling, slack C growing by 2C + 2, horizon = C x s, each level brute-verified as an (s, C)-bridge], length: 13pt, {
  let box = (x, y, w, label, hot) => {
    cdraw.rect((x - w / 2, y - 0.32), (x + w / 2, y + 0.32), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 8.6), [the bridge chain, one greedy level each], size: 6.5pt)
  box(3.0, 7.3, 1.7, [24], true)
  box(7.4, 7.3, 1.7, [16], false)
  box(11.8, 7.3, 1.7, [10], false)
  box(16.2, 7.3, 1.7, [5], false)
  box(20.6, 7.3, 1.7, [1], true)
  e((3.85, 7.3), (6.55, 7.3))
  e((8.25, 7.3), (10.95, 7.3))
  e((12.65, 7.3), (15.35, 7.3))
  e((17.05, 7.3), (19.75, 7.3))
  cdraw.content((3.0, 6.4), [s = 1, C = 1], size: 6pt)
  cdraw.content((7.4, 6.4), [s = 2, C = 4], size: 6pt)
  cdraw.content((11.8, 6.4), [s = 4, C = 10], size: 6pt)
  cdraw.content((16.2, 6.4), [s = 8, C = 22], size: 6pt)
  cdraw.content((20.6, 6.4), [s = 16, C = 46], size: 6pt)
  cdraw.content((11.0, 5.6), [horizon = C x s: 2, 16, 80, 352], size: 6pt)
  cdraw.content((11.0, 5.0), [walks recovered, cycles erased, paths of at least ceil(s/2) edges kept], size: 6pt)
  cdraw.content((11.0, 4.4), [greedy set cover hits the kept paths, ties by smallest vertex], size: 6pt)
  cdraw.content((11.0, 3.7), [every level brute-verified: an (s, C)-bridge], size: 6pt)
  cdraw.content((11.0, 3.1), [eta(u, b) + eta(b, v) at most C x eta(u, v) on a shortest route], size: 6pt)
  cdraw.content((11.0, 2.2), [honest row, stage s = 8: 29563 realized edges against the n^2 s = 4608 budget], size: 6pt)
  cdraw.content((11.0, 1.5), [road A loses at toy scale, the win rides the subcubic solver], size: 6pt)
})

#diagram([the consequence chain with the toy op count and the end exponents: 3SUM lists into exact triangle weights into mod-p instances into a witness, 257 baseline ops against 12349 road ops, and the asymptotic savings where they actually bite], length: 13pt, {
  let box = (x, y, w, label, hot) => {
    cdraw.rect((x - w / 2, y - 0.34), (x + w / 2, y + 0.34), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), label, size: 6pt)
  }
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 8.7), [3SUM to exact triangle to the 43.7 road], size: 6.5pt)
  box(3.0, 7.5, 3.2, [3 lists of 16 ints], false)
  box(9.2, 7.5, 4.4, [weights A\[a\], B\[b\], C\[c\]], false)
  box(15.8, 7.5, 3.8, [mod-p instances, 20], false)
  box(21.2, 7.5, 2.8, [witness scan], true)
  e((4.6, 7.5), (7.0, 7.5))
  e((11.4, 7.5), (13.9, 7.5))
  e((17.7, 7.5), (19.8, 7.5))
  cdraw.content((9.2, 6.6), [S(a, b, c) = A\[a\] + B\[b\] + C\[c\], so], size: 6pt)
  cdraw.content((9.2, 6.0), [zero triangles are zero triples], size: 6pt)
  box(6.2, 4.9, 4.6, [hash baseline: 257 ops], false)
  box(13.4, 4.9, 5.2, [the road: 12349 ops], true)
  cdraw.content((9.8, 4.1), [witnesses (16, -11, -5) and (3, 2, -5), both summing to 0], size: 6pt)
  cdraw.content((9.8, 3.5), [over 20 instances, the road loses by 48 x at n = 16, winning only asymptotically], size: 6pt)
  // end exponents
  cdraw.content((3.2, 2.4), [exact triangle: n^2.9983], size: 6pt)
  cdraw.content((3.2, 1.8), [3SUM: n^1.99923], size: 6pt)
  cdraw.content((3.2, 1.2), [APSP: n^2.99949], size: 6pt)
  cdraw.content((13.6, 2.4), [saving at n = 10^5: 1.9, 0.9, 0.6 percent], size: 6pt)
  cdraw.content((13.6, 1.8), [saving at n = 10^9: 3.5, 1.6, 1.1 percent], size: 6pt)
  cdraw.content((13.6, 1.2), [factor 2 in D^0.063 needs D about 6 x 10^4, N about 10^86], size: 6pt)
})

Two witnesses, both real, one road paying 48 times the baseline at
toy scale, and the exponents where the win lives, all pinned, and the
listings below close the chapter in seven languages.

#listing("dsa/samples-c/src/Ch43/minplus.c", first: 225, last: 261, caption: [c, one greedy bridge level, walks recovered within a horizon, cycles erased, greedy hitting over bitmasks])
#listing("dsa/samples-go/ch43/minplus.go", first: 291, last: 328, caption: [go, the scan closure shared by both directions, road A's bound 2n x |B| x horizon returned beside the picks])
#listing("dsa/samples-java/src/Ch43/Minplus.java", first: 233, last: 258, caption: [java, bridgeLevel with a scan helper, the 601-int stream digest pinned with the stage table])
#listing("dsa/samples/src/Ch43/Minplus.cs", first: 299, last: 334, caption: [c\#, the bridge level as a BridgeResult record over uint masks, greedy hitting inline])
#listing("dsa/samples-js/src/ch43-minplus.mjs", first: 227, last: 256, caption: [javascript, mpBridgeLevel with its scan closure, keep filtering by path length])
#listing("dsa/samples-py/src/Ch43/minplus.py", first: 226, last: 279, caption: [python, walk recovery through the bounded dp, greedy hitting with sizes beside the masks])
#listing("dsa/samples-lua/ch43_minplus.lua", first: 233, last: 268, caption: [lua, the bridge level with 1-based recover and erase, the same stage pins])

The min-plus lane leans on the floyd-warshall habits of chapter 11 and
differs mostly in storage. C and java flatten the bounded dp into one
array indexed k, u, v. Go keeps the flat slice behind a Di helper.
C\# and python nest lists, python's d\[k\]\[u\]\[v\] with row aliases pulled
out per level. Lua walks 1-based indices through the same layout. The
witness discipline is shared: every finite entry names an argmin k
that reproduces the entry as a two-hop sum, checked for all 576
entries. The 3SUM chain is stated once per tree with the baseline and
the road in the same function so the op counts are comparable by
construction, and the baseline's hash table is the plain dictionary
of every corpus language, chapter 6's structure doing the honest
opposite of the fancy road.

== across the seven languages

Featured build size counted as non-blank, non-comment source lines of
the chapter's 8 sample files per language in the c, go, java, c\#,
javascript, python, and lua trees, go test files excluded:

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto, auto, 1.6fr),
  inset: 4pt,
  table.header([*stem*], [*c*], [*go*], [*java*], [*c\#*], [*javascript*], [*python*], [*lua*], [*note*]),
  [baselines], [241], [125], [199], [107], [109], [151], [279], [three solvers and the work model, the thinnest stem],
  [schoenhage], [421], [201], [327], [194], [138], [179], [368], [the identity, its forms, and the 490-triple gamma walk],
  [recursion], [270], [167], [216], [224], [143], [319], [418], [one run of Full, 100 leaves, 18 outputs],
  [tiling], [199], [152], [171], [200], [134], [182], [279], [4 shared encodings, the \[400, 144\] counted row],
  [pruned], [656], [419], [536], [454], [270], [446], [870], [two instances, the paper table, the regime bignums],
  [boxes], [536], [560], [558], [570], [422], [355], [633], [12393 boxes, lemmas 27 and 28, the query path],
  [extriangle], [207], [222], [223], [183], [146], [236], [233], [theorem 17 end to end against brute force],
  [minplus], [606], [451], [576], [442], [351], [606], [1200], [squaring, the bridge chain, the 3SUM chain, the pinned 576-entry matrix],
)

The heavy rows are the pins. Pruned carries the regime decimal
strings, 446 lines in python and 870 in lua beside the base-10^4
bignum and 1-based adjustments. Minplus's 576-entry distance matrix
lands in full only in lua, a sibling pins module required by the
main file and never listed by run.lua. c pins spot rows plus
downstream values, and python anchors the stream by sha256 digest
with the matrix pinned as a checksum, edge rows, and spot cells,
landing beside the c twin at 606 lines. Go keeps the fixtures in
test files beside the code, so its columns stay the lowest, 2297
lines across 7 packages, extriangle and minplus sharing the ch43
package. Javascript holds the whole
chapter under 1750 lines by importing nothing and leaning on Number
where the values provably fit, with the LCG state alone in bigint.
The c tree carries the hand-rolled base-10^9 bignum in pruned at 656
lines and the flat dp array in minplus at 606.

Sample behavior verified by the 7 suite gates scoped to chapter 43:
c 8 files and 192 checks, go 7 packages and 75 test functions, java 8
files and 186 checks under run-java-samples, c\# 74 facts,
javascript 8 suites and 91 tests, python 8 files and 201 checks, lua
8 modules and 68 checks inside the 1004-check full suite, zero
skipped.

sources: Josh Alman and Virginia Vassilevska Williams, truly
subquadratic 3SUM and truly subcubic APSP via triangles in sparse
lopsided graphs, arXiv 2610.06783v1, theorem 1 on page 5, theorems 2
and 3 on page 7, corollary 16 on page 32, theorem 17 on page 33,
theorems 19 and 22 on pages 35 and 36, and the balanced-case remark
on page 61, read against the local copy at ref/2610.06783v1.pdf.
A. Schoenhage, the 1981 identity, and D. Coppersmith's 1982
rectangular matrix multiplication, both as cited in the paper's
section 2. U. Zwick, all pairs shortest paths using bridging sets
and matrix products, 2002, behind the bridge schedule and the ring
trick. Fischer, Kaliciak, and Polak, the 2024 3SUM reduction whose
deterministic minimum-count prime selection the paper follows, and
T. M. Chan and H. Xu, the 2024 derandomized instance construction and
witness scan the paper builds on. Fixtures generated and verified by
the reference implementation at playground/ch43-spine, the corpus
64-bit Knuth LCG with one advance per draw reading the high 32 bits,
accessed 2026-10-08.
