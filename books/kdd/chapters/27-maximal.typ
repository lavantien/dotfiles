// ch27, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 27 checks in kdd/samples/src/Ch27/closed.c (12) and rules.c (15) or
// a banked provenance note: the nine baskets are the running example
// table of Han, Pei, Yin, "Mining Frequent Patterns without Candidate
// Generation", SIGMOD 2000, TIDs 100-900,
// https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf (accessed
// 2026-09-22), the table chapters 25, 26 and 28 mine; fixture R is
// purpose-built by the matrix stream so all six rules from {a,b,c} carry
// clean confidences 3/4, 3/4, 2/3, 1, 1, 6/7. all pinned values are
// witnessed by kdd-contract-s6.md + playground/kdd-matrix/gen_s6.py, run
// 2026-09-22, exit 0. determinism: all D0, integer counts and exact
// reduced fractions, every fraction check comparing p against q never a
// double.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= maximal itemsets and rule generation

Two samples carry the chapter: `closed.c` classifies the 13 frequent
itemsets of #xref-to("kdd", "apriori") into closed, maximal and neither,
12 checks, and `rules.c` splits one frequent triple of a purpose-built
12-basket fixture into all six association rules with exact fractions,
15 checks. The chapter makes 4 moves: the closed border where support
stops falling, the maximal frontier where the frequent set stops
growing, the rule split with its support, confidence and lift fractions,
and the minconf cut that keeps 5 of the 6 rules by cross multiplication.
The borders are the answer to "13 itemsets is already a lot", and the
rules are the answer to "now what is one worth", which
#xref-to("kdd", "interesting") takes further.

== the lattice and its two borders

Chapter 25 harvested 13 frequent itemsets from M2 at minsup 2. Reading
them as a lattice by subset inclusion, two borders matter. An itemset is
closed when no frequent proper superset has the same support, and it is
maximal when no frequent proper superset exists at all. Every maximal
itemset is closed, since a set with no frequent superset certainly has
none at equal support, and the sample pins that direction as
`maximal_subset_of_closed=true`.

The dry run: the sample reprints the three levels identical to chapter
25, then classifies. Nine itemsets are closed, `closed: {I1}=6;{I2}=7;
{I3}=6;{I1,I2}=4;{I1,I3}=4;{I2,I3}=4;{I2,I4}=2;{I1,I2,I3}=2;{I1,I2,I5}=2`.
Three are maximal, `maximal: {I2,I4}=2;{I1,I2,I3}=2;{I1,I2,I5}=2`, both
L3 triples plus a pair: {I2,I4} has no frequent superset because every
candidate third item fails, {I1,I2,I3} and {I1,I2,I5} sit at the top of
their chains. The remaining six closed itemsets are the interior,
`closed_not_maximal: {I1}=6;{I2}=7;{I3}=6;{I1,I2}=4;{I1,I3}=4;{I2,I3}=4`,
singletons and pairs that some frequent superset still grows from.

#listing("kdd/samples/src/Ch27/closed.c", first: 117, last: 142,
  caption: [the 13 frequent itemsets collected and sorted by size then string])

#listing("kdd/samples/src/Ch27/closed.c", first: 170, last: 184,
  caption: [both borders in one scan, any proper superset, then any at equal support])

#diagram([the 13-itemset lattice, dashed edges where support holds instead of falling], length: 13pt, {
  let node = (x, y, hw, lab, kind) => {
    let fill = if kind == 0 {luma(168)} else if kind == 1 {luma(226)} else {luma(248)}
    cdraw.rect((x - hw, y - 0.45), (x + hw, y + 0.45), fill: fill, radius: 0.02)
    cdraw.content((x, y), lab, size: 5.6pt)
  }
  let up = (x1, y1, x2, y2, eq) => {
    cdraw.line((x1, y1 - 0.45), (x2, y2 + 0.45), stroke: if eq {
      (paint: luma(90), dash: "dashed")
    } else {
      (paint: luma(165))
    })
  }
  node(5.2, 7.2, 1.25, [{I1,I2,I3}=2], 0)
  node(11.6, 7.2, 1.25, [{I1,I2,I5}=2], 0)
  node(1.7, 4.6, 1.15, [{I1,I2}=4], 1)
  node(4.5, 4.6, 1.15, [{I1,I3}=4], 1)
  node(7.3, 4.6, 1.15, [{I1,I5}=2], 2)
  node(10.1, 4.6, 1.15, [{I2,I3}=4], 1)
  node(12.9, 4.6, 1.15, [{I2,I4}=2], 0)
  node(15.7, 4.6, 1.15, [{I2,I5}=2], 2)
  node(2.4, 2.0, 0.95, [{I1}=6], 1)
  node(6.2, 2.0, 0.95, [{I2}=7], 1)
  node(10.0, 2.0, 0.95, [{I3}=6], 1)
  node(13.4, 2.0, 0.95, [{I4}=2], 2)
  node(16.2, 2.0, 0.95, [{I5}=2], 2)
  up(5.2, 7.2, 1.7, 4.6, false)
  up(5.2, 7.2, 4.5, 4.6, false)
  up(5.2, 7.2, 10.1, 4.6, false)
  up(11.6, 7.2, 1.7, 4.6, false)
  up(11.6, 7.2, 7.3, 4.6, true)
  up(11.6, 7.2, 15.7, 4.6, true)
  up(1.7, 4.6, 2.4, 2.0, false)
  up(1.7, 4.6, 6.2, 2.0, false)
  up(4.5, 4.6, 2.4, 2.0, false)
  up(4.5, 4.6, 10.0, 2.0, false)
  up(7.3, 4.6, 2.4, 2.0, false)
  up(7.3, 4.6, 16.2, 2.0, true)
  up(10.1, 4.6, 6.2, 2.0, false)
  up(10.1, 4.6, 10.0, 2.0, false)
  up(12.9, 4.6, 6.2, 2.0, false)
  up(12.9, 4.6, 13.4, 2.0, true)
  up(15.7, 4.6, 6.2, 2.0, false)
  up(15.7, 4.6, 16.2, 2.0, true)
  cdraw.rect((0.4, 0.25), (1.1, 0.75), fill: luma(168), radius: 0.02)
  cdraw.content((3.3, 0.5), [maximal, 3], size: 5.8pt)
  cdraw.rect((5.4, 0.25), (6.1, 0.75), fill: luma(226), radius: 0.02)
  cdraw.content((8.6, 0.5), [closed only, 6], size: 5.8pt)
  cdraw.rect((10.7, 0.25), (11.4, 0.75), fill: luma(248), radius: 0.02)
  cdraw.content((14.0, 0.5), [not closed, 4], size: 5.8pt)
  cdraw.line((15.9, 0.5), (16.6, 0.5), stroke: (paint: luma(90), dash: "dashed"))
  cdraw.content((16.6, 0.5), [equal support], size: 5.8pt, anchor: "west")
})

== witnesses and what each border keeps

The four itemsets that fail to close all sit at support 2, and each has
a frequent proper superset holding the same count, its witness. The
sample pins all four pairs.

The dry run: `nonclosed {I4}=2 witness {I2,I4}=2`, then `nonclosed
{I5}=2 witness {I1,I5}=2`, then `nonclosed {I1,I5}=2 witness
{I1,I2,I5}=2` and `nonclosed {I2,I5}=2 witness {I1,I2,I5}=2`. I4 never
appears without I2 in this table, and I5 never appears in a basket that
is not already buying I1, so the smaller sets carry no information
their witnesses do not.

That is the whole trade between the two borders. The closed set, 9 of
13, is lossless: every non-closed itemset's support is recoverable as
its witness's support, so the closed list plus the lattice regenerates
all 13 counts. The maximal set, 3 of 13, is smaller and lossy: it
determines which itemsets are frequent, since every frequent itemset is
a subset of a maximal one, but it no longer pins the counts, {I4} and
{I5} both reducible only to "somewhere under {I2,I4} or {I1,I2,I5}".
Which border to keep depends on whether the counts feed anything
downstream, and the rules in the next two facets need them.

#listing("kdd/samples/src/Ch27/closed.c", first: 214, last: 234,
  caption: [the four non-closed itemsets with their equal-support witnesses])

#diagram([13 frequent, 9 closed and lossless, 3 maximal and lossy], length: 13pt, {
  let bar = (x, w, y, lab) => {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(232), radius: 0.02)
    cdraw.content((x + w + 0.35, y + 0.5), lab, size: 6pt, anchor: "west")
  }
  bar(0.5, 5.0, 6.8, [13 frequent, the fi listing of ch25])
  bar(0.5, 3.6, 5.2, [9 closed, every count recoverable])
  bar(0.5, 1.4, 3.6, [3 maximal, counts lost])
  cdraw.content((1.0, 2.6), [{I2,I4} {I1,I2,I3} {I1,I2,I5}], size: 5.5pt)
  cdraw.content((8.6, 7.4), [the I5 chain, all at 2], size: 6pt)
  let ch = (x, y, lab) => {
    cdraw.rect((x - 0.85, y - 0.42), (x + 0.85, y + 0.42), fill: luma(248), radius: 0.02)
    cdraw.content((x, y), lab, size: 5.6pt)
  }
  ch(10.6, 6.3, [{I5}=2])
  ch(10.6, 4.6, [{I1,I5}=2])
  ch(10.6, 2.9, [{I1,I2,I5}=2])
  cdraw.line((10.6, 5.88), (10.6, 5.02), stroke: (paint: luma(90), dash: "dashed"), mark: (end: ">"))
  cdraw.line((10.6, 4.18), (10.6, 3.32), stroke: (paint: luma(90), dash: "dashed"), mark: (end: ">"))
  ch(14.6, 4.6, [{I2,I5}=2])
  cdraw.line((13.75, 4.6), (11.9, 3.32), stroke: (paint: luma(90), dash: "dashed"), mark: (end: ">"))
  cdraw.content((13.3, 6.3), [witnessed, =2 each], size: 5.6pt)
  cdraw.content((13.3, 5.6), [count is the, same up the chain], size: 5.6pt)
  cdraw.content((10.6, 1.6), [support cannot fall along a dashed edge, so the top box carries the count for all], size: 5.6pt)
})

== six rules from one triple

An association rule X -> Y reads "baskets containing X tend to contain
Y", and it is scored from the support counts chapter 25 computed. This
is the same IF-THEN shape #xref-to("kdd", "rules") read off decision
tree leaves, but grown from co-occurrence counts instead of a tree. The
fixture R is built for the arithmetic: 12 baskets over a, b, c at minsup
6, six of them {a,b,c}, one {b,c}, one {b}, two {a} and two {c}, giving
supports a=8, b=8, c=9, ab=6, ac=6, bc=7, abc=6, so every rule from
{a,b,c} lands on a clean fraction.

The dry run: all six non-empty proper splits print, `{a}->{b,c} s=1/2
c=3/4 l=9/7`, `{b}->{a,c} s=1/2 c=3/4 l=3/2`, `{c}->{a,b} s=1/2 c=2/3
l=4/3`, `{a,b}->{c} s=1/2 c=1 l=4/3`, `{a,c}->{b} s=1/2 c=1 l=3/2`,
`{b,c}->{a} s=1/2 c=6/7 l=9/7`. The three fractions are exact reduced
ratios: support is supp(X union Y) over N, all six at 6/12, confidence
is supp(X union Y) over supp(X), and lift is N times supp(X union Y)
over the product of the two marginal supports. The row `{b,c}->{a}`
shows the fixture's one interesting confidence: 6 of the 7 {b,c}
baskets also buy a, 6/7, while the reverse direction `{a}->{b,c}` gives
6 of 8, 3/4.

#listing("kdd/samples/src/Ch27/rules.c", first: 136, last: 160,
  caption: [fixture R's frequent itemsets at minsup 6, grouped by size])

#listing("kdd/samples/src/Ch27/rules.c", first: 180, last: 207,
  caption: [the six splits, three reduced fractions each, byte-pinned rows])

#diagram([the six confidences with their lifts, certainty at the right], length: 13pt, {
  cdraw.line((1.2, 4.6), (16.8, 4.6), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.content((1.0, 5.15), [confidence], size: 6pt)
  let tick = (c, lab, rules) => {
    let x = 1.2 + (c - 0.6) * 39.0
    cdraw.line((x, 4.35), (x, 4.85), stroke: luma(60))
    cdraw.content((x, 5.15), lab, size: 6pt)
    cdraw.content((x, 3.9), rules.at(0), size: 5.6pt)
    if rules.len() > 1 {
      cdraw.content((x, 3.25), rules.at(1), size: 5.6pt)
    }
  }
  tick(2.0 / 3.0, [2\/3], ([{c}->{a,b}], [l = 4\/3]))
  tick(3.0 / 4.0, [3\/4], ([{a}->{b,c} l = 9\/7], [{b}->{a,c} l = 3\/2]))
  tick(6.0 / 7.0, [6\/7], ([{b,c}->{a}], [l = 9\/7]))
  tick(1.0, [1], ([{a,b}->{c} l = 4\/3], [{a,c}->{b} l = 3\/2]))
  cdraw.content((8.9, 6.6), [every support is 1\/2, the six rules differ only in confidence and lift], size: 6pt)
  cdraw.content((8.9, 1.9), [confidence 1 means the consequent never fails, lift still varies there], size: 6pt)
})

== the minconf cut, by cross multiplication

A rule survives a minimum confidence threshold when c >= minconf, and
with both sides exact fractions the comparison is cross multiplication,
never a double. The sheet plants the boundary cases deliberately.

The dry run: at minconf 2/3 the sample prints `minconf 2/3
survivors=6`, all six rules clear it, the weakest being exactly 2/3. At
minconf 3/4 it prints `minconf 3/4 survivors=5`, and names the casualty:
`drop {c} c=2/3`, since 2 times 4 is 8 against 3 times 3 is 9, while
the nearest survivor holds, `keep {b,c}->{a} c=6/7`, 6 times 4 being 24
against 3 times 7 being 21. The two rules at confidence 1,
{a,b}->{c} and {a,c}->{b}, pass any threshold below 1 without
arithmetic, and their conviction is undefined, the denominator 1 minus c
being zero, which is #xref-to("kdd", "interesting")'s opening problem:
confidence saturates, lift and conviction do not.

#listing("kdd/samples/src/Ch27/rules.c", first: 209, last: 239,
  caption: [exact threshold tests by cross multiplication, the drop and the keep])

#diagram([two boundary fractions, one drops at 3/4, one survives], length: 13pt, {
  let panel = (x, rule, cfrac, lhs, rhs, verdict, drop) => {
    cdraw.rect((x, 2.4), (x + 7.9, 6.6), fill: if drop {luma(246)} else {luma(240)}, radius: 0.02)
    cdraw.content((x + 3.95, 6.0), rule, size: 6.5pt)
    cdraw.content((x + 3.95, 5.3), [c = ] + cfrac, size: 6.5pt)
    cdraw.content((x + 3.95, 4.3), lhs, size: 6.5pt)
    cdraw.content((x + 3.95, 3.65), rhs, size: 6.5pt)
    cdraw.content((x + 3.95, 2.95), verdict, size: 6.5pt)
  }
  panel(0.5, [{c}->{a,b}], [2\/3], [2 x 4 = 8], [3 x 3 = 9], [8 < 9, drops], true)
  panel(9.1, [{b,c}->{a}], [6\/7], [6 x 4 = 24], [3 x 7 = 21], [24 > 21, survives], false)
  cdraw.content((8.75, 7.3), [c >= 3\/4 tested as numerator x 4 against 3 x denominator], size: 6pt)
  cdraw.content((8.75, 1.5), [minconf 2/3 survivors=6, minconf 3/4 survivors=5], size: 6pt)
})

sources: the nine-basket table is the running example of Han, Pei, Yin,
Mining Frequent Patterns without Candidate Generation, SIGMOD 2000, TIDs
100-900, https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf, accessed
2026-09-22, mined identically by chapters 25, 26 and 28. Fixture R, its
supports a=8 b=8 c=9 ab=6 ac=6 bc=7 abc=6 realized by 6x{a,b,c} plus
{b,c}, {b}, {a}, {a}, {c}, {c}, the closed and maximal listings, the
witness rows and both minconf filters are pinned by kdd-contract-s6.md
and witnessed by playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit
0. Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch27`, 12 + 15 checks in
chapter 27 of the kdd suite.
