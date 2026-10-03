// ch08, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 39 checks in kdd/samples/src/Ch08/subset.c (20) and chisq.c (19) or
// a cited source: NIST/SEMATECH e-Handbook of Statistical Methods,
// chi-square critical values at alpha 0.05, df 1 -> 3.841 and df 2 ->
// 5.991, accessed 2026-09-22 (banked by kdd-contract-s1s2.md). all pinned
// values are witnessed by kdd-contract-s1s2.md + playground/kdd-matrix/
// gen_s2.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= feature selection and chi-square

Two samples carry the chapter: `subset.c` scores all 15 non-empty feature
subsets under a redundancy penalty and searches them best-first, 20
checks, and `chisq.c` runs the chi-square test of independence on a 2x2
and a 2x3 table in exact integer arithmetic, 19 checks. The chapter makes
4 moves: a subset score that subtracts redundancy, the best-first search
and its stop rule, chi-square on the 2x2 with the Yates contrast, and the
2x3 that stays under its threshold. Every behavioral claim below is one
of the 39 checks of chapter 08's samples or the banked NIST critical
values. #xref-to("kdd", "binning") built the categorical shelves, this
chapter decides which columns earn their keep, and #xref-to("kdd",
"hypothesis") owns the testing machinery these tables are a first taste
of.

== a score that hates redundancy

Filter selection needs a number per subset, and the fixture fixes one:
four features with weights w = (A 4, B 4, C 2, D 1), two redundant pairs
(A, B) and (C, D), and the score $S = sum w - 2$ per enclosed redundant
pair. The penalty is the entire lesson. {D} alone is worth 1, and {C, D}
is worth $2 + 1 - 2 = 1$ as well, the pair adds a feature and gains
nothing. The redundancy pair says the second member of a pair carries no
information the first did not already bring.

The dry run: all 15 non-empty subsets print their scores, `score({A}) =
4` through `score({ABCD}) = 7`, and each is its own check, 15 in a row.
The singles read 4, 4, 2, 1. The pairs read ${A, B} = 6$, ${A, C} = 6$,
${B, C} = 6$, ${A, D} = 5$, ${B, D} = 5$, and ${C, D} = 1$, the last one
the penalty's showcase. The triples read ${A, B, C} = 8$, ${A, B, D} =
7$, ${A, C, D} = 5$, ${B, C, D} = 5$, and the full set ${A, B, C, D} =
11 - 4 = 7$ pays both penalties. The best subset is ${A, B, C}$ at 8,
asserted by "ch08 score({ABC}) = 8": it keeps both heavy features,
swallows one penalty for the (A, B) pair, and refuses D, whose only
contribution would be a second penalty.

#listing("kdd/samples/src/Ch08/subset.c", first: 34, last: 51,
  caption: [weights, redundant pairs, penalty 2, and the score function])

#listing("kdd/samples/src/Ch08/subset.c", first: 91, last: 99,
  caption: [all 15 non-empty subsets scored, one check each])

#diagram([the 15 subset scores by size, the winner keeps three features and one penalty], length: 13pt, {
  let rows = ((1, (([A 4], 0), ([B 4], 0), ([C 2], 0), ([D 1], 0))), (2, (([AB 6], 0), ([AC 6], 0), ([BC 6], 0), ([AD 5], 0), ([BD 5], 0), ([CD 1], 2))), (3, (([ABC 8], 1), ([ABD 7], 0), ([ACD 5], 0), ([BCD 5], 0))), (4, (([ABCD 7], 0),)))
  for r in range(4) {
    let y = 6.9 - r * 1.18
    let cells = rows.at(r).at(1)
    cdraw.content((0.9, y + 0.32), [size #(rows.at(r).at(0))], size: 6pt)
    for i in range(cells.len()) {
      let x0 = 2.6 + i * 1.92
      let hot = cells.at(i).at(1)
      cdraw.rect((x0, y - 0.15), (x0 + 1.72, y + 0.62),
        fill: if hot == 1 {luma(190)} else if hot == 2 {luma(212)} else if calc.odd(r) {luma(242)} else {luma(234)}, radius: 0.02)
      cdraw.content((x0 + 0.86, y + 0.24), cells.at(i).at(0), size: 6.5pt)
    }
  }
  cdraw.content((12.0, 6.7), [weights A 4, B 4, C 2, D 1], size: 6pt)
  cdraw.content((12.0, 6.0), [pairs (A,B) and (C,D) cost 2], size: 6pt)
  cdraw.content((12.0, 5.3), [darkest: best {A,B,C} = 8], size: 6pt)
  cdraw.content((12.0, 4.7), [mid: {C,D}, penalty eats the pair], size: 6pt)
  cdraw.content((12.0, 2.6), [adding D to the best drops it to 7], size: 6pt)
  cdraw.content((12.0, 1.9), [the full set pays both penalties: 11 - 4 = 7], size: 6pt)
})

== best-first, and when to stop

Scoring every subset is exponential; search prunes it. The sample runs
best-first over an open list ordered by score first, lexicographic
subset order on ties, pushing every single-feature extension of each
expanded node, and stops when the best open entry can no longer beat the
best subset already found. The tie rule is pinned because equal scores
are everywhere in this fixture, and lexicographic order is what breaks
them: ${A}$ pops before ${B}$ at score 4, and ${A, B}$ pops before ${A,
C}$ at score 6.

The dry run: the expansion trail prints `expand (,0)`, `expand (A,4)`,
`expand (AB,6)`, `expand (ABC,8)`, four expansions in that exact order,
asserted whole as "ch08 best-first expansions (empty,A,AB,ABC) =
(0,4,6,8)". Expanding ${A, B, C}$ pushes ${A, B, C, D}$ at 7, the best
score already seen is 8, and no open entry can top it, so the loop
breaks. The selection prints `selected {ABC} score 8`, the stop prints
`open at stop: 7 entries, {AC} = 6, max {ABD} = 7`, and the checks pin
both the generator's literal assertion, the open node ${A, C}$ at 6
below the best 8, and the stronger one, "ch08 stop rule: every open
entry < best 8". The true open maximum is 7, not 6, and the header of
the sample says so plainly: the pinned 6 is a specific node, the
every-entry check is what actually certifies the stop.

#listing("kdd/samples/src/Ch08/subset.c", first: 115, last: 137,
  caption: [pop the open maximum, record the expansion, push extensions])

#listing("kdd/samples/src/Ch08/subset.c", first: 189, last: 207,
  caption: [the stop rule: one pinned node, then every open entry])

#diagram([four expansions down the spine, the frontier never tops 8], length: 13pt, {
  let chain = (([empty], [0]), ([{A}], [4]), ([{A,B}], [6]), ([{A,B,C}], [8]))
  for i in range(4) {
    let x0 = 1.0 + i * 3.3
    cdraw.rect((x0, 5.3), (x0 + 2.9, 6.3),
      fill: if i == 3 {luma(190)} else {luma(242)}, radius: 0.02)
    cdraw.content((x0 + 1.45, 6.0), chain.at(i).at(0), size: 6.5pt)
    cdraw.content((x0 + 1.45, 5.6), chain.at(i).at(1), size: 6pt)
    if i < 3 {
      cdraw.line((x0 + 2.9, 5.8), (x0 + 3.3, 5.8), stroke: luma(60), mark: (end: ">"))
    }
  }
  cdraw.content((2.45, 6.9), [tie at 4: {A} before {B}; tie at 6: {A,B} before {A,C}], size: 6pt)
  cdraw.content((6.2, 4.4), [frontier at the stop], size: 6pt)
  let fr = (([{A,B,D}], [7]), ([{A,B,C,D}], [7]), ([{A,C}], [6]), ([and 4 more], [6 down]))
  for i in range(4) {
    let x0 = 1.4 + i * 3.3
    cdraw.rect((x0, 2.9), (x0 + 2.9, 3.7), fill: luma(246), radius: 0.02)
    cdraw.content((x0 + 1.45, 3.48), fr.at(i).at(0), size: 6.5pt)
    cdraw.content((x0 + 1.45, 3.12), fr.at(i).at(1), size: 6pt)
  }
  cdraw.line((8.0, 5.25), (8.0, 3.8), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((8.0, 1.9), [stop rule: every open score < best found 8], size: 6pt)
  cdraw.content((8.0, 1.25), [4 expansions instead of 15 scorings], size: 6pt)
})

== the 2x2, and yates

Chi-square tests independence: compare every cell's observed count O
against its expected count E = row total times column total over n, and
sum $(O - E)^2 \/ E$. A large statistic says the rows and columns are
entangled, the feature and the class travel together, which is exactly
what a selected feature should do. The sample computes each cell term as
an exact rational, $(100 O - r c)^2 \/ (100 r c)$, so integers carry the
whole computation and the comparison against the decimal critical value
is a cross-multiplication.

The dry run: the table is [[20, 30], [30, 20]] with n = 100, both row
totals 50 and both column totals 50. Every expected cell is $50 dot 50
\/ 100 = 25$, every deviation is 5, and every term is $25\/25 = 1$, so
chi2 = 4 exactly, printed as `2x2: E all 25, terms all 1, chi2 = 4 =
4/1`. Against the NIST critical value 3.841 at alpha 0.05 with one
degree of freedom, 4 rejects independence, asserted without a single
floating-point comparison as `acc_n * 1000 > 3841 * acc_d`. The Yates
continuity correction subtracts 0.5 from each absolute deviation first:
every corrected term becomes $(5 - 0.5)^2 \/ 25 = 4.5^2 \/ 25 = 0.81$,
the total is $4 dot 0.81 = 3.24$, printed as `yates: term
0.81000000000000005 total 3.2400000000000002 (= 81/25)`, and 3.24 falls
short of 3.841: on this table the correction flips the verdict.

#listing("kdd/samples/src/Ch08/chisq.c", first: 45, last: 54,
  caption: [each cell term as an exact rational, gcd-reduced])

#listing("kdd/samples/src/Ch08/chisq.c", first: 63, last: 89,
  caption: [expected 25 per cell, chi2 exactly 4, reject by cross-multiply])

#listing("kdd/samples/src/Ch08/chisq.c", first: 91, last: 98,
  caption: [yates: 4.5 squared over 25, times 4, no longer rejects])

#diagram([the 2x2 table and the two verdicts against the df 1 threshold], length: 13pt, {
  let obs = (([20], [30]), ([30], [20]))
  for i in range(2) {
    for j in range(2) {
      let x0 = 1.6 + j * 2.2
      let y0 = 6.2 - i * 1.5
      cdraw.rect((x0, y0 - 1.3), (x0 + 2.0, y0), fill: luma(242), radius: 0.02)
      cdraw.content((x0 + 1.0, y0 - 0.45), obs.at(i).at(j), size: 7pt)
      cdraw.content((x0 + 1.0, y0 - 0.95), [E = 25], size: 5.5pt)
    }
  }
  cdraw.content((3.7, 6.35), [class yes], size: 5.5pt)
  cdraw.content((5.9, 6.35), [class no], size: 5.5pt)
  cdraw.content((0.9, 5.55), [feature +], size: 5.5pt)
  cdraw.content((0.9, 4.05), [feature -], size: 5.5pt)
  cdraw.content((3.6, 3.0), [every term (5^2)/25 = 1, chi2 = 4], size: 6pt)
  let px(v) = { 9.3 + v * 1.35 }
  cdraw.line((9.1, 5.8), (16.8, 5.8), stroke: luma(60), mark: (end: ">"))
  for v in (0, 1, 2, 3, 4, 5) {
    cdraw.line((px(v * 1.0), 5.65), (px(v * 1.0), 5.95), stroke: luma(60))
    cdraw.content((px(v * 1.0), 5.25), [#v], size: 6pt)
  }
  cdraw.line((px(3.841), 4.6), (px(3.841), 6.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(3.841), 6.65), [3.841, df 1], size: 6pt)
  cdraw.circle((px(4.0), 4.95), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((px(4.0), 4.45), [4.0, reject], size: 6pt)
  cdraw.circle((px(3.24), 3.75), radius: 0.11, fill: luma(220), stroke: luma(60))
  cdraw.content((px(3.24), 3.25), [3.24 yates, no reject], size: 6pt)
  cdraw.content((12.7, 2.3), [the correction moves the verdict across the line], size: 6pt)
})

#callout("note", "rationals against decimal tables", [
  The critical values come from a printed table as decimals, 3.841 and
  5.991, but the statistic itself is the exact rational the integer
  loop accumulated. The checks compare the two worlds by
  cross-multiplication, `acc_n * 1000 > 3841 * acc_d`, so no rounded
  double ever sits between the statistic and its threshold. The same
  discipline makes the Yates total assertable with `==`: one term is
  computed and then multiplied by 4, and rounding commutes with
  multiplication by a power of two.
])

== a 2x3 that stays under

One degree of freedom is the most forgiving chi-square there is, so the
second fixture widens the table. Two rows, three columns, [[15, 10, 15],
[15, 20, 25]], row totals (40, 60), column totals (30, 30, 40), n = 100,
and two degrees of freedom, threshold 5.991.

The dry run: the expected counts print as `2x3: expected 12 12 16 18 18
24`, row 1 getting $40 dot 30\/100, 40 dot 30\/100, 40 dot 40\/100$ and
row 2 getting the 60-side versions. The six cell terms are the fractions
3\/4, 1\/3, 1\/16, 1\/2, 2\/9, 1\/24, printed as `term(0,0) = 3/4, x144
= 108` through `term(1,2) = 1/24, x144 = 6`: scaled by the common
denominator 144 the terms become 108, 48, 9, 72, 32, 6, integers
summing to 275, printed as `scaled sum 275, chi2 = 275/144 =
1.9097222222222223`. And 275\/144 is nowhere near 5.991: the sample
fails to reject independence, "ch08 2x3 fail to reject: 275/144 < 5.991
(df 2)". The feature and the class are compatible with independence on
this table, and the integer pair (275, 144) is the D0 witness, the
1e-9 double only a display.

#listing("kdd/samples/src/Ch08/chisq.c", first: 127, last: 147,
  caption: [the six terms scaled by 144, exact integers, one check each])

#listing("kdd/samples/src/Ch08/chisq.c", first: 148, last: 161,
  caption: [275/144 as the D0 pair, the double at 1e-9, fail to reject])

#diagram([observed against expected in six cells, the statistic far under the df 2 line], length: 13pt, {
  let obs = (([15], [10], [15]), ([15], [20], [25]))
  let exp = (([12], [12], [16]), ([18], [18], [24]))
  for i in range(2) {
    for j in range(3) {
      let x0 = 1.2 + j * 2.05
      let y0 = 6.4 - i * 1.35
      cdraw.rect((x0, y0 - 1.15), (x0 + 1.85, y0), fill: luma(242), radius: 0.02)
      cdraw.content((x0 + 0.92, y0 - 0.42), obs.at(i).at(j), size: 7pt)
      cdraw.content((x0 + 0.92, y0 - 0.85), [E #exp.at(i).at(j)], size: 5.5pt)
    }
  }
  cdraw.content((4.6, 6.75), [observed above, expected below], size: 6pt)
  cdraw.content((4.6, 3.0), [terms over LCD 144: 108 + 48 + 9 + 72 + 32 + 6 = 275], size: 6pt)
  cdraw.content((4.6, 2.3), [chi2 = 275/144 = 1.9097], size: 6pt)
  let px(v) = { 9.6 + v * 1.1 }
  cdraw.line((9.4, 5.9), (16.8, 5.9), stroke: luma(60), mark: (end: ">"))
  for v in (0, 2, 4, 6) {
    cdraw.line((px(v * 1.0), 5.75), (px(v * 1.0), 6.05), stroke: luma(60))
    cdraw.content((px(v * 1.0), 5.35), [#v], size: 6pt)
  }
  cdraw.line((px(5.991), 4.9), (px(5.991), 6.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((px(5.991), 6.75), [5.991, df 2], size: 6pt)
  cdraw.circle((px(1.9097), 5.25), radius: 0.11, fill: luma(220), stroke: luma(60))
  cdraw.content((px(1.9097), 4.75), [1.9097], size: 6pt)
  cdraw.content((12.4, 4.1), [fail to reject: independence fits], size: 6pt)
})

Two selection lenses, one habit. The subset score asks which columns work
together and charges for saying the same thing twice; chi-square asks a
single column how far its class distribution drifts from independence
and prices the drift against a tabled threshold. #xref-to("kdd",
"interesting") reuses the same drift logic to score whole patterns, and
#xref-to("kdd", "hypothesis") builds the general test machinery the
tabled values abbreviate.

sources: NIST/SEMATECH e-Handbook of Statistical Methods, tabled
upper-tail chi-square critical values at alpha 0.05, df 1 3.841 and df
2 5.991, itl.nist.gov/div898/handbook, accessed 2026-09-22,
banked by kdd-contract-s1s2.md. All 39 pinned values, the x144 scaling,
the (275, 144) pair, and the cross-multiplication comparisons witnessed
by kdd-contract-s1s2.md and playground/kdd-matrix/gen_s2.py, run
2026-09-22, exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch08`,
20 + 19 checks in chapter 08 of the kdd suite.
