// ch15, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 57 checks in kdd/samples/src/Ch15/rulex.c (17) and seqcov.c (40) or a
// banked note of kdd-contract-s3.md (the sheet-defined sequential covering
// procedure after Cohen 1995 and Clark & Boswell 1991, the Laplace prune on
// the full training set, the lexicographic tie-breaks). fixture 1 is the
// play-tennis table of Mitchell 1997 Table 3.2 p. 59 (provenance in ch13);
// fixture 2 is constructed on the sheet. all pinned values are witnessed by
// kdd-contract-s3.md + playground/kdd-matrix/gen_s3.py, run 2026-09-22,
// exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= rules from trees and sequential covering

Two samples carry the chapter: `rulex.c` walks the tree of
#xref-to("kdd", "id3") leaf by leaf and reads one IF-THEN rule off each
path, 17 checks, and `seqcov.c` grows rules from scratch by sequential
covering on a 10-row fixture, 40 checks. The chapter makes 4 moves:
extraction and the partition it inherits, greedy growth one condition
at a time, the Laplace prune that demonstrably fires, and the ordered
evaluation where one row goes wrong on purpose. Every behavioral claim
below is one of the 57 checks of chapter 15's samples or a named note
of the contract sheet.

== one rule per leaf

A decision tree already is a set of rules, one per root-to-leaf path:
the conditions along the path anded together, the leaf's class as the
consequent. Extraction walks the tree depth first, so rule order is
leaf order, and each rule's conditions come out in the order the tree
tested them.

The dry run: five rules print in order, `rule 1: IF outlook=sunny AND
humidity=high THEN no` down to `rule 5: IF outlook=rain AND
wind=strong THEN no`, one per leaf of the 5-leaf tree. Coverage and
correctness print per rule, `rule 1: coverage 3 correct 3`,
`rule 2: coverage 2 correct 2`, `rule 3: coverage 4 correct 4`, and so
on, every rule perfect on the training set, and the census closes the
argument: `total coverage 14`, the check named "ch15 rules partition 14
training rows". The ordered list then classifies `ordered-list accuracy
14/14`, though for these rules the order is decoration, no row matches
two of them.

#listing("kdd/samples/src/Ch15/rulex.c", first: 138, last: 152,
  caption: [depth-first extraction, the path accumulated down the tree])

#listing("kdd/samples/src/Ch15/rulex.c", first: 163, last: 170,
  caption: [the IF-THEN grammar, conditions in path order])

#listing("kdd/samples/src/Ch15/rulex.c", first: 199, last: 219,
  caption: [per-rule coverage and correctness, the partition census])

#diagram([the ch13 tree read as five rules, one per root-to-leaf path], length: 13pt, {
  let node(x0, y0, name) = {
    cdraw.rect((x0, y0), (x0 + 2.8, y0 + 0.7), fill: luma(240), radius: 0.02)
    cdraw.content((x0 + 1.4, y0 + 0.35), name, size: 6.5pt)
  }
  let leaf(x0, y0, tag, cls) = {
    cdraw.rect((x0, y0), (x0 + 2.8, y0 + 0.7), fill: luma(248), radius: 0.02)
    cdraw.content((x0 + 1.4, y0 + 0.35), [#tag #cls], size: 6pt)
  }
  node(7.5, 7.3, [outlook])
  node(1.2, 5.6, [humidity])
  leaf(7.6, 5.8, [R3,], [yes])
  node(12.4, 5.6, [wind])
  leaf(0.0, 3.9, [R1,], [no])
  leaf(3.2, 3.9, [R2,], [yes])
  leaf(10.8, 3.9, [R4,], [yes])
  leaf(14.0, 3.9, [R5,], [no])
  cdraw.line((8.0, 7.3), (2.8, 6.3), stroke: luma(60))
  cdraw.content((4.8, 7.2), [sunny], size: 6pt)
  cdraw.line((8.9, 7.3), (8.9, 6.5), stroke: luma(60))
  cdraw.content((9.6, 6.9), [overcast], size: 6pt)
  cdraw.line((9.8, 7.3), (13.6, 6.3), stroke: luma(60))
  cdraw.content((12.0, 7.2), [rain], size: 6pt)
  cdraw.line((2.0, 5.6), (1.4, 4.6), stroke: luma(60))
  cdraw.content((0.8, 5.15), [high], size: 6pt)
  cdraw.line((3.2, 5.6), (4.6, 4.6), stroke: luma(60))
  cdraw.content((4.4, 5.15), [normal], size: 6pt)
  cdraw.line((13.2, 5.6), (12.2, 4.6), stroke: luma(60))
  cdraw.content((11.6, 5.15), [weak], size: 6pt)
  cdraw.line((14.4, 5.6), (15.4, 4.6), stroke: luma(60))
  cdraw.content((15.7, 5.15), [strong], size: 6pt)
  cdraw.content((8.0, 2.4), [rule 3 is one condition long, the others two], size: 6pt)
})

== grow, one condition at a time

Sequential covering builds rules without a tree: pick a class, start
from the empty rule, greedily add the condition that best separates,
accept, delete the rows it covers, repeat. The procedure here is the
contract sheet's deterministic fixing of the ripper shape, grow then
prune, after Cohen 1995 and Clark and Boswell 1991, and the fixture is
10 rows over attributes a, b, c with classes 4 yes against 6 no.

The dry run: classes come in ascending count order, printed as `class
order: yes(4) then no(6)`. Growing for yes, step 1 prices every
candidate with at least one yes hit, `step1 b=b2 p=3 n=0`, `step1
c=c1 p=4 n=1`, `step1 a=a1 p=1 n=1`, down to `step1 b=b1 p=1 n=4`;
b=b2 and c=c1 tie at $p - n = 3$ and the lexicographic rule hands it
to b=b2, the check "ch15 step1 winner b=b2 (lex over c=c1), p=0
excluded" naming both facts, the excluded b=b3, c=c2, c=c3 never
carrying a yes row. One condition already pure, so `R1 IF b=b2 THEN
yes covers 1 2 3`. Round 2 grows on the remaining rows 4 through 10:
`step2 c=c1 p=1 n=1` wins, then on the pair $\{4, 5\}$ both a=a2 and
b=b1 sit at (1, 0), `step3 a=a2 (1,0); b=b1 (1,0)`, and a=a2 wins the
tie, growing `IF c=c1 AND a=a2 THEN yes`.

#listing("kdd/samples/src/Ch15/seqcov.c", first: 44, last: 56,
  caption: [the 10-row fixture, 4 yes against 6 no, constructed on the sheet])

#listing("kdd/samples/src/Ch15/seqcov.c", first: 120, last: 134,
  caption: [the winner, max p minus n, lexicographic tie-break])

#diagram([step 1 candidates by p minus n, two tie at +3, lex picks b=b2], length: 13pt, {
  let zero = 9.4
  let rows = (([b=b2], 3, [+3]), ([c=c1], 3, [+3]), ([a=a1], 0, [0]),
    ([a=a4], 0, [0]), ([a=a2], -1, [-1]), ([a=a3], -1, [-1]), ([b=b1], -3, [-3]))
  cdraw.line((zero, 0.6), (zero, 8.3), stroke: luma(60))
  cdraw.content((zero, 8.65), [0], size: 6pt)
  for i in range(7) {
    let r = rows.at(i)
    let y = 7.8 - i * 1.05
    cdraw.content((2.4, y + 0.28), r.at(0), size: 6.5pt)
    if r.at(1) >= 0 {
      cdraw.rect((zero, y), (zero + r.at(1) * 1.1, y + 0.56), fill: luma(236), radius: 0.02)
      cdraw.content((zero + r.at(1) * 1.1 + 0.35, y + 0.28), r.at(2), size: 6pt)
    } else {
      cdraw.rect((zero + r.at(1) * 1.1, y), (zero, y + 0.56), fill: luma(246), radius: 0.02)
      cdraw.content((zero + r.at(1) * 1.1 - 0.35, y + 0.28), r.at(2), size: 6pt)
    }
  }
  cdraw.content((13.2, 7.8), [lex smaller wins the tie], size: 6pt)
  cdraw.content((13.2, 7.3), [b=b2 < c=c1], size: 6pt)
  cdraw.content((9.0, 0.4), [p=0 candidates excluded: b=b3, c=c2, c=c3], size: 6pt)
})

== the laplace prune, and it fires

A rule grown to purity on a shrinking remainder overfits the
remainder. The prune step scores a rule by the Laplace estimate
$v = (p + 1)\/(p + n + 2)$, computed over the full training set, not
the remainder, and drops the last condition whenever the shorter rule
scores at least as well.

The dry run: the grown rule is c=c1 AND a=a2, pure on the remaining
rows but covering a single row of the full table. The sample prints
`prune: v(rule)=2/3 v(prefix)=5/7 -> DROP`: the two-condition rule
matches only row 4, so $p = 1$, $n = 0$, $v = 2\/3$, while the prefix
c=c1 alone matches rows 1 through 4 plus row 5, $p = 4$, $n = 1$,
$v = 5\/7$. The comparison is exact cross-multiplication, the check
"ch15 cross-mult 15/21 vs 14/21", five sevenths beats two thirds, and
the condition goes. The class no needs no rule at all, `class no:
remaining rows pure, no rule emitted`, so the final line prints
`final: IF b=b2 THEN yes | IF c=c1 THEN yes | default:no`.

#listing("kdd/samples/src/Ch15/seqcov.c", first: 146, last: 158,
  caption: [the Laplace estimate, exact fractions over the full 10 rows])

#listing("kdd/samples/src/Ch15/seqcov.c", first: 224, last: 233,
  caption: [prune from the last condition back, drop on cross-multiplied >=])

#listing("kdd/samples/src/Ch15/seqcov.c", first: 341, last: 351,
  caption: [the pinned fractions and the drop, 2/3 loses to 5/7])

#diagram([two estimates of correctness, 2/3 against 5/7, zoomed at the bottom], length: 13pt, {
  let px(t) = { 1.6 + t * 13.0 }
  let seg(y, tag, t, lab) = {
    cdraw.line((1.6, y), (14.6, y), stroke: luma(60), mark: (end: ">"))
    cdraw.content((1.0, y + 0.3), [0], size: 6pt)
    cdraw.content((15.1, y + 0.3), [1], size: 6pt)
    cdraw.content((2.2, y + 0.3), tag, size: 6pt)
    cdraw.circle((px(t), y), radius: 0.11, fill: luma(150), stroke: luma(60))
    cdraw.content((px(t), y - 0.5), lab, size: 6pt)
  }
  seg(6.6, [v(rule), 2\/3], 2.0 / 3.0, [2\/3 = 14\/21])
  seg(4.6, [v(prefix), 5\/7], 5.0 / 7.0, [5\/7 = 15\/21])
  cdraw.line((px(2.0 / 3.0), 6.2), (8.0, 3.6), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((px(5.0 / 7.0), 4.2), (12.57, 3.6), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((1.6, 2.8), (16.0, 2.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.6, 2.25), [0.60], size: 6pt)
  cdraw.content((16.0, 2.25), [0.75], size: 6pt)
  cdraw.circle((8.0, 2.8), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((8.0, 3.3), [2\/3], size: 6pt)
  cdraw.circle((12.57, 2.8), radius: 0.11, fill: luma(150), stroke: luma(60))
  cdraw.content((12.57, 3.3), [5\/7], size: 6pt)
  cdraw.content((8.8, 1.9), [zoomed, one twenty-first apart], size: 6pt)
  cdraw.content((8.8, 1.2), [the shorter rule scores higher, drop the condition], size: 6pt)
})

#callout("note", "prune looks at all 10 rows, grow looked at 7", [
  Growth priced candidates on the shrinking remainder, rows 4 through
  10, because covering is about what is left. The prune deliberately
  switches back to the full training set, where the two-condition rule
  covers one row and the one-condition rule covers five, and the
  Laplace plus-ones keep a single perfect match from scoring 1.0. That
  asymmetry is the sheet's rule and it is what makes the prune fire
  here: on the remainder alone, the prefix would have looked worse.
])

== the ordered list, and the row that goes wrong

Extracted tree rules were mutually exclusive, each row walking exactly
one leaf. Covering rules are not: rule 2, c=c1, overlaps rows the
first rule already took, so the ruleset is an ordered decision list,
first match wins, with a default class behind the last rule.

The dry run: the audit prints one line per row, `row 1: rule#1 -> yes
actual yes ok` through `row 3`, `row 4: rule#2 -> yes actual yes ok`,
then the planted failure, `row 5: rule#2 -> yes actual no WRONG`, the
a3 b3 c1 row that says no but carries c=c1. Rows 6 through 10 fall
through both rules, `row 6: rule#0 -> no actual no ok`, rule 0 meaning
the default, five lines of it. The summary prints `ordered ruleset
accuracy 9/10` and the full-set statistics explain the wound, `rule 2
full-set coverage 5 correct 4`: the rule was accepted for the one row
it still covered and keeps the four it stole fairly.

#listing("kdd/samples/src/Ch15/seqcov.c", first: 366, last: 388,
  caption: [the ordered walk, first rule wins, default behind them all])

#listing("kdd/samples/src/Ch15/seqcov.c", first: 391, last: 404,
  caption: [full-set statistics, rule 2 covers 5 and gets 4 right])

#diagram([the 10-row audit, rule fired, prediction, and the one wrong row], length: 13pt, {
  let cell(x0, y0, id, r, pred, act, wrong) = {
    cdraw.rect((x0, y0), (x0 + 3.4, y0 + 1.2),
      fill: if wrong {luma(226)} else {luma(248)}, radius: 0.02)
    cdraw.content((x0 + 1.7, y0 + 0.92), [row #id], size: 6.5pt)
    cdraw.content((x0 + 1.7, y0 + 0.55), [#r -> #pred], size: 6pt)
    cdraw.content((x0 + 1.7, y0 + 0.2),
      if wrong {[actual #act, WRONG]} else {[actual #act, ok]}, size: 6pt)
  }
  cell(1.0, 6.4, [1], [rule 1], [yes], [yes], false)
  cell(1.0, 5.0, [2], [rule 1], [yes], [yes], false)
  cell(1.0, 3.6, [3], [rule 1], [yes], [yes], false)
  cell(1.0, 2.2, [4], [rule 2], [yes], [yes], false)
  cell(1.0, 0.8, [5], [rule 2], [yes], [no], true)
  cell(10.0, 6.4, [6], [default], [no], [no], false)
  cell(10.0, 5.0, [7], [default], [no], [no], false)
  cell(10.0, 3.6, [8], [default], [no], [no], false)
  cell(10.0, 2.2, [9], [default], [no], [no], false)
  cell(10.0, 0.8, [10], [default], [no], [no], false)
  cdraw.content((7.2, 4.4), [9 of 10], size: 7pt)
})

#callout("pitfall", "the tree's rules never overlap, covering rules must be ordered", [
  The extraction sample classified 14 of 14 with no default because
  tree rules partition: a row walks one path. Covering rules grow
  greedily toward one class and stay greedy about others' rows, rule 2
  fires yes on a no row, so the list order and the default are
  load-bearing parts of the hypothesis, not presentation. The same
  IF-THEN shape returns with no class at all as association rules in
  #xref-to("kdd", "apriori"), where the THEN side is another item, and
  the cost of rule complexity is judged by the machinery of
  #xref-to("kdd", "pruning").
])

sources: sequential covering procedure fixed by kdd-contract-s3.md
after Cohen, "Fast Effective Rule Induction", ICML 1995, and Clark and
Boswell, "Rule Induction with CN2", ECML 1991. Fixture 1 is the
play-tennis table of Mitchell, Machine Learning, McGraw-Hill 1997,
Table 3.2 p. 59, provenance carried from chapter 13. All 57 pinned
values witnessed by kdd-contract-s3.md and
playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch15`, 17 + 40 checks in
chapter 15 of the kdd suite.
