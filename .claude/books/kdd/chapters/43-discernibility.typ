// ch43, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 31 checks in kdd/samples/src/Ch43/discern.c or a banked provenance
// note: the discernibility matrix and function tradition is Skowron &
// Rauszer, The Discernibility Matrices and Functions in Information
// Systems, in Intelligent Decision Support, Kluwer 1992, applied here to
// Pawlak's flu table (IJCIS 11(5) 1982 341-356), the same fixture as
// chapters 41 and 42. all pinned values are witnessed by
// kdd-contract-s8s9.md + playground/kdd-matrix/gen_s9.py, run 2026-09-22,
// exit 0. all D0: exact strings. the f_min derivation is HARD two-way,
// brute-force prime implicants asserted to cover with no smaller cover,
// and its implicant set asserted equal to chapter 42's reducts.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= rough sets: discernibility and rule induction

One sample carries the chapter: `discern.c` fills the 15-cell
discernibility matrix of the flu table, multiplies the 7 informative
cells into the discernibility function, minimizes it to two prime
implicants by brute force, and reads a certain-rule set out of each
reduct, 31 checks. The chapter makes 4 moves: the matrix that names the
attributes separating every pair, the empty cell that is an inconsistency
rather than a requirement, the Boolean function whose prime implicants
are exactly the reducts of #xref-to("kdd", "reducts"), and the rules the
reducts license, with the one ambiguous cell left honestly unclassified.
#xref-to("kdd", "rough") bracketed what the table cannot decide, this
chapter names the pairs it cannot separate and converts the survivors
into the rule language of #xref-to("kdd", "rules").

== the matrix of separating attributes

Cell D[pi][pj] lists the attributes on which patients i and j differ,
nothing else. Pairs with the same decision are marked same-dec and
discarded later, they never constrain a classifier that only needs to
separate the classes. Pairs with different decisions carry the weight:
any attribute set that hopes to determine the decision must, for each
such pair, contain at least one attribute from the cell. One pair has
nothing to offer: p2 and p5 agree on all three conditionals and differ
only in the decision, so their cell is empty, tagged conflict, and it is
the matrix portrait of chapter 41's boundary.

The dry run: 15 rows, `D[p1][p2]={H,M} same-dec` down to
`D[p5][p6]={H,M,T}`, one string check each. The seven different-decision
cells are the load-bearing ones, `D[p1][p4]={T}`, `D[p1][p5]={H,M}`,
`D[p2][p4]={H,M,T}`, `D[p3][p4]={H,T}`, `D[p3][p5]={M,T}`,
`D[p4][p6]={T}`, `D[p5][p6]={H,M,T}`, and the conflict row reads exactly
`D[p2][p5]={} conflict`, asserted as "ch43 D[p2][p5]={} conflict". Every
cell is readable straight off the table, p1 = (n, y, high) against p4 =
(n, y, normal) differs in temperature alone, which is the {T} cell, and
temperature is the only attribute separating both (p1,p4) and (p4,p6),
a first hint it cannot be dropped.

#listing("kdd/samples/src/Ch43/discern.c", first: 41, last: 57,
  caption: [a cell is the differing-attribute set of its pair, three comparisons])

#listing("kdd/samples/src/Ch43/discern.c", first: 98, last: 131,
  caption: [all 15 pinned cells with the conflict and same-dec tags])

#diagram([the upper triangle: seven requirements, one conflict, seven same-dec fillers], length: 13pt, {
  let cs = (
    (4.2, 7.0, [H,M], 0), (6.6, 7.0, [H,T], 0), (9.0, 7.0, [T], 1),
    (11.4, 7.0, [H,M], 1), (13.8, 7.0, [T], 1),
    (4.2, 5.5, [M,T], 0), (6.6, 5.5, [H,M,T], 1), (9.0, 5.5, [{}], 2),
    (11.4, 5.5, [H,M,T], 1),
    (4.2, 4.0, [H,T], 1), (6.6, 4.0, [M,T], 1), (9.0, 4.0, [H], 0),
    (4.2, 2.5, [H,M,T], 0), (6.6, 2.5, [T], 1),
    (4.2, 1.0, [H,M,T], 1))
  for c in cs {
    let fill = if c.at(3) == 2 {luma(200)} else if c.at(3) == 1 {luma(232)} else {luma(248)}
    cdraw.rect((c.at(0) - 1.05, c.at(1) - 0.45), (c.at(0) + 1.05, c.at(1) + 0.45),
      fill: fill, radius: 0.02, stroke: luma(160))
    cdraw.content((c.at(0), c.at(1)), c.at(2), size: 6pt)
  }
  let cols = ((4.2, [p2]), (6.6, [p3]), (9.0, [p4]), (11.4, [p5]), (13.8, [p6]))
  for c in cols {
    cdraw.content((c.at(0), 7.75), c.at(1), size: 6.5pt)
  }
  let rows = ((7.0, [p1]), (5.5, [p2]), (4.0, [p3]), (2.5, [p4]), (1.0, [p5]))
  for r in rows {
    cdraw.content((2.0, r.at(0)), r.at(1), size: 6.5pt)
  }
  cdraw.content((8.9, 8.45), [rows p1..p5 against columns p2..p6], size: 6pt)
  cdraw.content((8.9, 0.1), [shaded: different decision, darkest: the conflict], size: 6pt)
})

== the function, and the empty cell it drops

The discernibility function is the conjunction over all nonempty
different-decision cells of the disjunction of that cell's attributes,
a CNF whose satisfying assignments are exactly the attribute sets that
separate every conflicting pair. The conflict cell contributes nothing:
there is no disjunction over the empty set that a set of attributes
could satisfy, and none is needed, because the pair is not a separation
requirement but a proof the requirement system is unsatisfiable for those
two objects.

The dry run: the sample builds the product in row-major pair order and
prints `f_raw=(T) & (H|M) & (H|M|T) & (H|T) & (M|T) & (T) & (H|M|T)`,
asserted as "ch43 f_raw 7-factor product", seven factors for the seven
informative cells, (p2,p5) absent by construction. Minimizing is exact
Boolean algebra, witnessed line by line in the sheet's absorption trace:
$(T)&(H|M)&(H|M|T)&(H|T)&(M|T)$ drops the first $(H|M|T)$ because $T$
absorbs it, then $T&(H|T) = T$ and $T&(M|T) = T$ collapse the two
two-literal factors, leaving $(T)&(H|M)$, which distributes to the
minimal form the sample prints and checks, `f_min=H&T | M&T`.

#listing("kdd/samples/src/Ch43/discern.c", first: 133, last: 148,
  caption: [the raw function: conjunction over informative cells of their disjunctions])

#diagram([absorption in three moves, from seven factors to two prime implicants], length: 13pt, {
  let step(y, expr, note) = {
    cdraw.rect((1.0, y - 0.5), (15.6, y + 0.5), fill: luma(246), radius: 0.02,
      stroke: luma(150))
    cdraw.content((8.3, y), expr, size: 6.5pt)
    cdraw.content((8.3, y - 1.0), note, size: 6pt)
  }
  cdraw.content((8.3, 8.55), [f_raw has 7 factors, f_min has 2 implicants], size: 6pt)
  step(7.5, [(T) & (H|M) & (H|M|T) & (H|T) & (M|T) & (T) & (H|M|T)],
    [the raw conjunction, conflict cell already dropped])
  step(5.5, [(T) & (H|M) & (H|T) & (M|T)],
    [drop (H|M|T), absorbed by (T)])
  step(3.5, [(T) & (H|M)],
    [T&(H|T) = T and T&(M|T) = T])
  step(1.5, [f_min = (T&H) | (T&M)],
    [distribute: two prime implicants])
  cdraw.line((16.4, 6.9), (16.4, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((16.4, 4.9), (16.4, 4.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((16.4, 2.9), (16.4, 2.1), stroke: luma(60), mark: (end: ">"))
})

== prime implicants, brute force, two ways

The sample does not trust the algebra, it hammers the function. A set of
attributes covers when it intersects every nonempty different-decision
cell, and the enumeration checks all 7 subsets in size order, rejecting
any that contains an already-found cover. The two-way hardness is in the
check structure: each surviving implicant must cover, asserted, and no
smaller cover may exist, the singletons are asserted to fail first.

The dry run: "ch43 no single attribute covers (H,M,T each fail)" fires
first, {H} and {M} both miss the (p1,p4) cell, whose only separator is
T, and {T} misses (p1,p5), whose separators are H and M. Then the pair
{H,T} covers all seven cells and {M,T} covers all seven, so the sample
prints `f_min=H&T | M&T` and
asserts "ch43 f_min=H&T | M&T" and "ch43 both prime implicants {H,T},{M,T}
cover (two-way)". The cross-chapter agreement is its own check: the
sample prints `prime set as reducts={H,T};{M,T} (equals ch42 reducts)`
and asserts "ch43 implicant set equals ch42
reducts={H,T};{M,T}". Boolean minimization and dependency enumeration,
two definitions that share no code, produce the same two sets, and the
flu table is small enough that both searches are exhaustive, which is
what makes the agreement evidence rather than coincidence.

#listing("kdd/samples/src/Ch43/discern.c", first: 84, last: 94,
  caption: [coverage: one attribute from every informative cell, or fail])

#listing("kdd/samples/src/Ch43/discern.c", first: 149, last: 188,
  caption: [brute-force implicants in size order, then the asserted agreement with ch42])

#diagram([the seven requirements against five candidate sets, only the two pairs cover all], length: 13pt, {
  let pairs = (([p1,p4], [T]), ([p1,p5], [H,M]), ([p2,p4], [H,M,T]),
    ([p3,p4], [H,T]), ([p3,p5], [M,T]), ([p4,p6], [T]), ([p5,p6], [H,M,T]))
  let sets = ([{H}], [{M}], [{T}], [{H,T}], [{M,T}])
  let hits = ((false, false, true, true, true),
    (true, true, false, true, true),
    (true, true, true, true, true),
    (true, false, true, true, true),
    (false, true, true, true, true),
    (false, false, true, true, true),
    (true, true, true, true, true))
  cdraw.content((8.6, 8.4), [requirement hit table, X means the cell is missed], size: 6pt)
  let ys = (7.3, 6.4, 5.5, 4.6, 3.7, 2.8, 1.9)
  for i in range(7) {
    cdraw.content((2.4, ys.at(i)), pairs.at(i).at(0), size: 6pt)
    cdraw.content((4.9, ys.at(i)), [{] + pairs.at(i).at(1) + [}], size: 6pt)
  }
  let xs = (7.4, 9.2, 11.0, 12.8, 14.6)
  for j in range(5) {
    cdraw.content((xs.at(j), 8.0), sets.at(j), size: 6pt)
  }
  for i in range(7) {
    for j in range(5) {
      let covered = hits.at(i).at(j)
      cdraw.circle((xs.at(j), ys.at(i)), radius: 0.17,
        fill: if covered {luma(180)} else {white}, stroke: luma(120))
      if not covered {
        cdraw.content((xs.at(j), ys.at(i) - 0.045), [X], size: 5.5pt)
      }
    }
  }
  cdraw.rect((11.9, 1.45), (13.7, 7.75), fill: none, stroke: luma(60))
  cdraw.rect((13.7, 1.45), (15.5, 7.75), fill: none, stroke: luma(60))
  cdraw.content((8.6, 1.0), [every column has an X except the two boxed pairs], size: 6pt)
})

== rules, and the one rule the table refuses

Each reduct's partition turns into rules directly: a decision-constant
class is a certain rule, its conjunction of attribute tests on the left,
the decision on the right, the class size as support. A mixed class
produces no certain rule at all, and the sample says so in the format
`ambiguous (...)=>? [1|1] no-certain-rule`, the vote count in brackets
rather than a fabricated verdict.

The dry run: from {H,T}, `rules from {H,T}:` then five rows, `rule
(H=n&T=high)=>Flu=yes [1]`, `ambiguous (H=y&T=high)=>? [1|1]
no-certain-rule`, `rule (H=y&T=vhigh)=>Flu=yes [1]`, `rule
(H=n&T=normal)=>Flu=no [1]`, `rule (H=n&T=vhigh)=>Flu=yes [1]`, and the
closer `certain_rules_cover=4 of 6`, asserted as "ch43 reduct 1
certain_rules_cover=4 of 6". From {M,T}, four rows only, because its
partition merges the two vhigh patients into one class, `rule
(M=y&T=vhigh)=>Flu=yes [2]` carrying support 2, and the same closer, 4 of
6. The two reducts classify exactly the positive region of
#xref-to("kdd", "reducts") and leave exactly the twins, {p2,p5},
unclassified, both asserted. The contrast is the payoff of choosing a
reduct: {M,T} buys a shorter rule set with one doubly-supported rule,
{H,T} pays one extra rule for rules that never merge classes.

#listing("kdd/samples/src/Ch43/discern.c", first: 190, last: 238,
  caption: [each class one rule, mixed classes named ambiguous, support in brackets])

#diagram([two rule sets, one shared hole: the twins classify under neither], length: 13pt, {
  let rl(x0, title, rules, cover) = {
    cdraw.content((x0 + 3.4, 8.3), title, size: 6.5pt)
    let y = 7.4
    for r in rules {
      let amb = r.at(1)
      cdraw.rect((x0, y - 0.42), (x0 + 6.8, y + 0.42),
        fill: if amb {luma(214)} else {luma(246)}, radius: 0.02, stroke: luma(150))
      cdraw.content((x0 + 3.4, y), r.at(0), size: 6pt)
      y -= 1.06
    }
    cdraw.content((x0 + 3.4, y + 0.5), cover, size: 6pt)
  }
  rl(0.7, [rules from {H,T}], (([H=n & T=high => yes [1]], false),
    ([H=y & T=high => ? [1|1] ambiguous], true),
    ([H=y & T=vhigh => yes [1]], false),
    ([H=n & T=normal => no [1]], false),
    ([H=n & T=vhigh => yes [1]], false)), [certain cover 4 of 6, {p2,p5} left out])
  rl(9.5, [rules from {M,T}], (([M=y & T=high => yes [1]], false),
    ([M=n & T=high => ? [1|1] ambiguous], true),
    ([M=y & T=vhigh => yes [2]], false),
    ([M=y & T=normal => no [1]], false)), [certain cover 4 of 6, one rule doubly supported])
  cdraw.content((8.5, 1.4), [both reducts refuse the same cell, honesty over coverage], size: 6pt)
})

sources: the discernibility matrix and function are A. Skowron and C.
Rauszer, The Discernibility Matrices and Functions in Information
Systems, in R. Slowinski, editor, Intelligent Decision Support, Handbook
of Applications and Advances of the Rough Sets Theory, Kluwer 1992,
331-362, applied to Pawlak's flu table as banked by
kdd-contract-s8s9.md. All 31 pinned values witnessed by the same sheet
and playground/kdd-matrix/gen_s9.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch43`, 31 checks in chapter 43
of the kdd suite.
