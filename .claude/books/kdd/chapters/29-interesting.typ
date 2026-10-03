// ch29, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 38 checks in kdd/samples/src/Ch29/interesting.c (15) and multilev.c
// (23) or a banked provenance note: fixtures Q (12 baskets over A,B,C,D),
// T (10 baskets, 2-level taxonomy) and B (8 tuples of age and income) are
// purpose-built by the matrix stream, pinned in kdd-contract-s6.md and
// witnessed by playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0.
// the chi-square critical 3.8415 is the NIST/SEMATECH e-Handbook of
// Statistical Methods sec 1.3.6.7.4 table value at df=1, alpha=0.05
// upper tail, https://www.itl.nist.gov/div898/handbook/eda/section3/
// eda3674.htm (accessed 2026-09-22). determinism: D0 everywhere except
// the family's single D2 row, the 1.5 < 3.8415 double comparison, with
// margin 2.3415 so no tolerance is needed.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= interestingness, multilevel, and quantitative rules

Two samples carry the chapter: `interesting.c` scores three rules from
fixture Q with lift and conviction and runs the chi-square independence
test on one of them, 15 checks, and `multilev.c` mines a two-level
taxonomy and a binned pair of continuous attributes, 23 checks. The
chapter makes 4 moves: the two measures that do not saturate the way
confidence did in #xref-to("kdd", "maximal"), the chi-square test that
refuses to call lift 5/4 significant on 12 baskets, the concept
hierarchy whose roll-up identity holds exactly, and the binning that
turns age and income into items. Support and confidence produced rules,
this chapter asks whether a rule is worth anything.

== lift and conviction

Confidence has two blind spots: it saturates at 1 where it says nothing
about the consequent's marginal rate, and it ignores that rate entirely,
calling {a,b}->{c} at 6/6 interesting even when c appears in 9 of 12
baskets anyway. Lift compares the joint rate to the independence
baseline, $l = N dot "supp"(X union Y)\/("supp"(X) dot "supp"(Y))$, and
conviction measures how far the rule is from implying the consequent
always, $v = (1 - "supp"(Y)\/N)\/(1 - c)$, undefined at $c = 1$.

The dry run: fixture Q has 12 baskets with supp A=6, B=6, C=8, D=4, and
the sample prints all three A-rules, `{A}->{B} s=1/4 c=1/2 l=1 v=1`,
`{A}->{C} s=5/12 c=5/6 l=5/4 v=2`, `{A}->{D} s=1/12 c=1/6 l=1/2 v=4/5`.
The A->C arithmetic: A and C co-occur in 5 baskets, so s is 5/12,
confidence is 5/6, lift is $12 dot 5\/(6 dot 8) = 5\/4$, and conviction
is $(1 - 8\/12)\/(1 - 5\/6) = (1\/3)\/(1\/6) = 2$. The A->B row is the
independence witness: A and B meet in 3 baskets, exactly the
$6 dot 6\/12$ an independent pair would produce, and the check pins
"ch29 Q A and B independent: lift=1 and conviction=1 together". Lift
equals 1 exactly when conviction equals 1, and A->D shows the
complement, lift 1/2 with conviction below 1 at 4/5.

#listing("kdd/samples/src/Ch29/interesting.c", first: 142, last: 160,
  caption: [three rules, four exact fractions each, conviction in closed form])

#diagram([lift against the independence line, conviction underneath], length: 13pt, {
  cdraw.line((1.2, 4.4), (16.6, 4.4), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.content((1.0, 4.95), [lift], size: 6pt)
  cdraw.line((9.0, 2.2), (9.0, 7.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((9.0, 7.9), [independence, l = 1], size: 6pt)
  let mk = (x, top, mid, bot) => {
    cdraw.line((x, 4.15), (x, 4.65), stroke: luma(60))
    cdraw.content((x, 5.35), top, size: 6.2pt)
    cdraw.content((x, 3.7), mid, size: 5.8pt)
    cdraw.content((x, 3.0), bot, size: 5.8pt)
  }
  mk(3.4, [l = 1\/2], [{A}->{D}], [v = 4\/5])
  mk(9.0, [l = 1], [{A}->{B}], [v = 1])
  mk(14.6, [l = 5\/4], [{A}->{C}], [v = 2])
  cdraw.content((3.4, 6.3), [negative side], size: 5.6pt)
  cdraw.content((14.6, 6.3), [positive side], size: 5.6pt)
  cdraw.content((8.9, 1.6), [conviction is 1 exactly at independence, and larger the more the rule beats chance], size: 6pt)
})

#callout("note", "three measures because each is blind somewhere", [
  Confidence is directional and reads like a probability, but it cannot
  distinguish "the consequent always follows" from "the consequent
  almost always happens anyway". Lift fixes the baseline and is
  symmetric, so it cannot tell A->C from C->A. Conviction is directional
  again and unbounded above, but it is undefined at confidence 1, which
  is precisely where confidence is happiest. The fixture plants one rule
  on each side of 1 so no single number tells the whole story.
])

== the chi-square verdict

Lift 5/4 on 12 baskets is a surplus of exactly one basket over the
independent expectation, and the question is whether 12 baskets can
carry that. The chi-square test of independence folds the 2x2 table of
A against C: observed counts row-major, expected counts as row total
times column total over N, then the statistic $sum (o - e)^2\/e$.

The dry run: the observed table is 5, 1, 3, 3 against expected 4, 2, 4,
2, printed as `cell o=5 e=4`, `cell o=1 e=2`, `cell o=3 e=4`, `cell
o=3 e=2`, the four contributions being $1\/4 + 1\/2 + 1\/4 + 1\/2$, and
the exact sum prints `chi2=3/2`. Then the family's only D2 row: the
statistic is dyadic, exactly 1.5 as a double, the critical value is
pinned as the double literal 3.8415 from the NIST table at df=1 and
alpha=0.05, and the comparison is a plain `<` with margin 2.3415,
printed `chi2 double=1.5 crit=3.8415 df=1 alpha=0.05 reject=false`.
Independence is not rejected: lift 5/4 is not significant on this
table. The machinery is #xref-to("kdd", "hypothesis")'s subject at full
length, and a real mining run tests thousands of rules at once, which
is the multiplicity problem #xref-to("kdd", "fdr") owns.

#listing("kdd/samples/src/Ch29/interesting.c", first: 171, last: 199,
  caption: [expected counts as exact fractions, the statistic summed exactly])

#listing("kdd/samples/src/Ch29/interesting.c", first: 201, last: 208,
  caption: [the D2 row, one double literal against one dyadic statistic])

#diagram([the 2x2 table, four cells, four exact contributions, one verdict], length: 13pt, {
  cdraw.content((4.4, 8.1), [A against C, observed over expected], size: 6pt)
  cdraw.content((5.9, 7.3), [C], size: 6pt)
  cdraw.content((9.3, 7.3), [not C], size: 6pt)
  cdraw.content((1.4, 5.9), [A], size: 6pt)
  cdraw.content((1.0, 3.5), [not A], size: 6pt)
  let cell = (x, y, o, e, contrib) => {
    cdraw.rect((x - 1.55, y - 1.05), (x + 1.55, y + 1.05), fill: luma(244), radius: 0.02)
    cdraw.content((x, y + 0.55), [o = #o], size: 6.5pt)
    cdraw.content((x, y - 0.02), [e = #e], size: 6pt)
    cdraw.content((x, y - 0.6), contrib, size: 5.6pt)
  }
  cell(5.9, 5.9, 5, 4, [(5-4)^2\/4 = 1\/4])
  cell(9.3, 5.9, 1, 2, [(1-2)^2\/2 = 1\/2])
  cell(5.9, 3.5, 3, 4, [(3-4)^2\/4 = 1\/4])
  cell(9.3, 3.5, 3, 2, [(3-2)^2\/2 = 1\/2])
  cdraw.content((11.3, 5.9), [row 6], size: 5.8pt)
  cdraw.content((11.3, 3.5), [row 6], size: 5.8pt)
  cdraw.content((5.9, 1.9), [col 8], size: 5.8pt)
  cdraw.content((9.3, 1.9), [col 4], size: 5.8pt)
  cdraw.rect((12.3, 1.2), (17.3, 4.6), fill: luma(232), radius: 0.02)
  cdraw.content((14.8, 4.05), [1\/4 + 1\/2 + 1\/4 + 1\/2], size: 5.4pt)
  cdraw.content((14.8, 3.4), [chi2 = 3\/2 = 1.5], size: 6.5pt)
  cdraw.content((14.8, 2.75), [1.5 < 3.8415], size: 6.5pt)
  cdraw.content((14.8, 2.1), [independence NOT rejected], size: 5.8pt)
  cdraw.content((14.8, 1.55), [despite lift 5\/4], size: 5.8pt)
})

#callout("pitfall", "the fixture does the arithmetic, not the statistics", [
  All four expected counts are 2 or more, but the classic guidance asks
  for at least 5 per cell before trusting the chi-square approximation,
  and a 12-basket table cannot get there: the cells would need to
  average 3. The verdict line is a faithful computation on a fixture
  too small for the test's own assumptions, exactly the caveat the
  contract sheet banks. What the row does pin is the more transferable
  fact: a one-basket surplus is invisible at df=1, so lift 5/4 on 12
  rows is noise, and only the test says so.
])

== one hierarchy, two levels

Real taxonomies put items under parents, skim and whole milk under
dairy, wheat and white under bread, and mining can run at either level.
Fixture T is 10 baskets, each buying exactly one dairy item and one
bread item, mined at minsup 3 uniformly at both levels.

The dry run: the concrete level prints `supp skim=6`, `supp wheat=4`,
`supp white=6`, `supp whole=4`, then the six pairs in item order, `pair
{skim,wheat}=3`, `pair {skim,white}=3`, `pair {skim,whole}=0`, `pair
{wheat,white}=0`, `pair {wheat,whole}=1`, `pair {white,whole}=3`. The
two zeros are structural, not statistical: a basket never carries two
dairy items, so {skim,whole} and {wheat,white} cannot occur, and no
amount of data moves them. Rolling up, the sample prints `rolled
{dairy}=10 {bread}=10 {bread,dairy}=10 rollup_sum=10`, and the identity
is exact: the four cross-category concrete pairs sum $3 + 3 + 3 + 1 =
10$, the support of {bread,dairy}, because every basket is counted once
at the concrete level and once at the abstract level. This is the same
move #xref-to("kdd", "olap") makes on cubes, aggregating along a
dimension hierarchy, here with a count identity that closes over 10
baskets exactly.

#listing("kdd/samples/src/Ch29/multilev.c", first: 53, last: 65,
  caption: [the taxonomy as two bits and the roll-up as a mapping])

#listing("kdd/samples/src/Ch29/multilev.c", first: 206, last: 219,
  caption: [the roll-up identity checked as an equality of counts])

#diagram([concrete pairs below, the abstract pair above, zeros structural], length: 13pt, {
  cdraw.content((4.2, 8.1), [the taxonomy], size: 6pt)
  cdraw.content((4.2, 7.3), [dairy], size: 6pt)
  cdraw.content((2.4, 6.2), [skim], size: 5.8pt)
  cdraw.content((6.0, 6.2), [whole], size: 5.8pt)
  cdraw.line((3.9, 7.05), (2.7, 6.6), stroke: (paint: luma(150)))
  cdraw.line((4.5, 7.05), (5.7, 6.6), stroke: (paint: luma(150)))
  cdraw.content((4.2, 5.1), [bread], size: 6pt)
  cdraw.content((2.4, 4.0), [wheat], size: 5.8pt)
  cdraw.content((6.0, 4.0), [white], size: 5.8pt)
  cdraw.line((3.9, 4.85), (2.7, 4.4), stroke: (paint: luma(150)))
  cdraw.line((4.5, 4.85), (5.7, 4.4), stroke: (paint: luma(150)))
  let names = ([skim], [wheat], [white], [whole])
  let vals = ((0, 3, 3, 0), (3, 0, 0, 1), (3, 0, 0, 3), (0, 1, 3, 0))
  for i in range(4) {
    cdraw.content((11.5 + i * 1.35, 7.35), names.at(i), size: 5.2pt, anchor: "west")
    cdraw.content((10.2, 6.9 - i * 1.05), names.at(i), size: 5.2pt, anchor: "east")
    for j in range(4) {
      let v = vals.at(i).at(j)
      let zero = i != j and v == 0
      cdraw.rect((11.4 + j * 1.35, 6.42 - i * 1.05), (12.7 + j * 1.35, 7.32 - i * 1.05),
        fill: if zero {luma(214)} else if i == j {luma(250)} else {luma(238)}, stroke: luma(205))
      cdraw.content((12.05 + j * 1.35, 6.87 - i * 1.05),
        if i == j {[-]} else {[#v]}, size: 5.6pt)
    }
  }
  cdraw.content((13.4, 8.1), [concrete pairs, shaded cells structural 0], size: 6pt)
  cdraw.content((8.8, 1.4), [rolled: {dairy}=10 {bread}=10 {bread,dairy}=10, cross pairs 3+3+3+1 = 10], size: 6pt)
})

== quantitative rules by binning

Continuous attributes join association mining by discretization, the
same move #xref-to("kdd", "binning") made for histograms. Fixture B is
8 tuples of age and income with the sheet's edges: age into [20,30),
[30,40), [40,50] years with the last bin closed, income into low below
40, mid from 40 to under 75, high from 75 up, in thousands per year.

The dry run: the eight bin rows print, `b1 age=22 inc=30
bin=age[20,30),low` through `b8 age=42 inc=60 bin=age[40,50],mid`, the
young three all landing low, the middle two mid, and the old three
splitting two high and one mid. The two pinned rules then read
`age[40,50)->high s=1/4 c=2/3 l=8/3` and `age[20,30)->low s=3/8 c=1
l=8/3`. The first is b6 and b7 out of the three old tuples, 2/8, 2/3,
lift $8 dot 2\/(3 dot 2) = 8\/3$, b8's mid income being the miss. The
second is perfect, 3 of 3, confidence 1, and its lift is $8 dot 3\/(3
dot 3)$, also 8/3: low income never occurs outside the young bin on
this fixture, so the two rules tie. One spelling note the sample pins
in a comment: the bin label is closed, `age[40,50]`, while the rule
antecedent is spelled half-open, `age[40,50)`, matching the sheet's
rule rows, and the chapter quotes both as printed.

#listing("kdd/samples/src/Ch29/multilev.c", first: 138, last: 156,
  caption: [the bin edges, age closed on the last bin, income in three bands])

#listing("kdd/samples/src/Ch29/multilev.c", first: 241, last: 265,
  caption: [the two binned rules with exact fractions of N=8])

#diagram([age against income, the bin grid, and where the two rules live], length: 13pt, {
  cdraw.line((3.2, 1.4), (3.2, 7.6), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.line((3.2, 1.4), (16.8, 1.4), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.content((2.9, 4.5), [income], size: 6pt)
  cdraw.content((10.0, 0.7), [age], size: 6pt)
  let px = (a) => { 3.2 + (a - 18) * 0.52 }
  let py = (v) => { 1.4 + v * 0.062 }
  for a in (30, 40) {
    cdraw.line((px(a), 1.4), (px(a), 7.6), stroke: (paint: luma(190), dash: "dashed"))
  }
  cdraw.content((px(25), 7.9), "[20,30)", size: 5.4pt)
  cdraw.content((px(35), 7.9), "[30,40)", size: 5.4pt)
  cdraw.content((px(45), 7.9), "[40,50]", size: 5.4pt)
  for v in (40, 75) {
    cdraw.line((3.2, py(v)), (16.8, py(v)), stroke: (paint: luma(190), dash: "dashed"))
  }
  cdraw.content((16.9, py(20)), [low], size: 5.4pt, anchor: "west")
  cdraw.content((16.9, py(57)), [mid], size: 5.4pt, anchor: "west")
  cdraw.content((16.9, py(90)), [high], size: 5.4pt, anchor: "west")
  let pts = ((22, 30, [b1]), (27, 28, [b2]), (29, 33, [b3]), (35, 60, [b4]),
    (36, 52, [b5]), (45, 90, [b6]), (48, 95, [b7]), (42, 60, [b8]))
  for i in range(8) {
    let p = pts.at(i)
    cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.14, fill: luma(70))
    cdraw.content((px(p.at(0)) + 0.35, py(p.at(1)) + 0.28), p.at(2), size: 5.2pt)
  }
  cdraw.rect((px(41), py(75)), (px(50), py(100)), stroke: luma(60))
  cdraw.rect((px(20), py(0)), (px(30), py(40)), stroke: luma(60))
  cdraw.content((px(45.5), py(97)), [s=1\/4 c=2\/3 l=8\/3], size: 5.4pt, anchor: "west")
  cdraw.content((px(20.5), py(4)), [s=3\/8 c=1 l=8\/3], size: 5.4pt, anchor: "west")
})

sources: fixtures Q, T and B, the lift and conviction formulas, the
chi-square cell convention and the 3/2 statistic, the roll-up identity
3+3+3+1 = 10, the bin edges and both binned rule rows are pinned by
kdd-contract-s6.md and witnessed by playground/kdd-matrix/gen_s6.py,
run 2026-09-22, exit 0. The critical value 3.8415 is from the
NIST/SEMATECH e-Handbook of Statistical Methods, sec 1.3.6.7.4,
https://www.itl.nist.gov/div898/handbook/eda/section3/eda3674.htm,
accessed 2026-09-22, pinned as a double literal per the sheet's D2
ruling. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch29`, 15 + 23 checks in chapter 29 of the kdd suite.
