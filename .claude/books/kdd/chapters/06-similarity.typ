// ch06, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 23 checks in kdd/samples/src/Ch06/similarity.c or a cited source:
// Jurafsky and Martin, Speech and Language Processing, 3rd ed. draft, ch 2
// minimum edit distance, the intention/execution alignment (banked by
// kdd-contract-s1s2.md). all pinned values are witnessed by
// kdd-contract-s1s2.md + playground/kdd-matrix/gen_s2.py, run 2026-09-22,
// exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= similarity measures

One sample carries the chapter: `similarity.c` scores three set pairs by
Jaccard, two vector pairs by cosine, three string pairs by unit-cost edit
distance, and two perfectly linear ladders by Pearson r, 23 checks in all.
The chapter makes 4 moves: set overlap as a reduced fraction, vector
alignment with exactly one sqrt call, string distance in its mining
spelling, and correlation as cosine on centered data. Every behavioral
claim below is one of the 23 checks of chapter 06's sample or a cited
alignment from Jurafsky and Martin. #xref-to("kdd", "distance") measured
how far apart two things sit; this chapter turns the question around and
measures how much they share, the quantity #xref-to("kdd", "kmeans")
averages into centroids and #xref-to("kdd", "features") scores features
by before keeping any of them.

== sets: intersection over union

The Jaccard similarity of two sets is the size of their intersection over
the size of their union, $J(A, B) = |A inter B| \/ |A union B|$, a fraction in
$[0, 1]$ that is 0 for disjoint sets and 1 for identical ones. It needs
no order, no magnitudes, and no dimensions, which is why it is the default
similarity for baskets, tags, and any record reduced to a set of items.
The fixture is three set pairs chosen to exercise three regimes: heavy
overlap, a single shared item, and containment.

The dry run: pair 1 is ${a, b, c, d}$ against ${a, b, e, f}$, sharing a
and b, so inter 2 and union $4 + 4 - 2 = 6$, printed as `pair1 {abcd} vs
{abef}: inter 2 union 6 -> 1/3`. Pair 2 is ${1, 2, 3}$ against ${3, 4, 5,
6}$, sharing only 3, inter 1 union 6, reduced to 1\/6. Pair 3 is ${p, q,
r, s, t}$ against ${p, q}$, containment, inter 2 union 5, and 2\/5 is
already reduced. Six checks pin the three integer pairs and the three
reduced fractions, the reduction done by the same `gcd_i` loop that
chapter 02 used, and every value stays an integer until the fraction is
named.

#listing("kdd/samples/src/Ch06/similarity.c", first: 128, last: 147,
  caption: [three set pairs, intersection counted, union by inclusion-exclusion])

#diagram([three set pairs, the shared letters sit in the lens of each panel], length: 13pt, {
  let panel1(cx) = {
    cdraw.circle((cx - 0.55, 4.8), radius: 1.15, stroke: luma(60))
    cdraw.circle((cx + 0.55, 4.8), radius: 1.15, stroke: luma(60))
    cdraw.content((cx - 1.2, 4.8), [c], size: 6pt)
    cdraw.content((cx - 0.95, 5.5), [d], size: 6pt)
    cdraw.content((cx + 0.95, 5.5), [e], size: 6pt)
    cdraw.content((cx + 1.2, 4.8), [f], size: 6pt)
    cdraw.content((cx - 0.25, 5.15), [a], size: 6pt)
    cdraw.content((cx - 0.25, 4.5), [b], size: 6pt)
  }
  let panel2(cx) = {
    cdraw.circle((cx - 1.0, 4.8), radius: 1.15, stroke: luma(60))
    cdraw.circle((cx + 1.0, 4.8), radius: 1.15, stroke: luma(60))
    cdraw.content((cx - 1.5, 4.6), [1], size: 6pt)
    cdraw.content((cx - 0.9, 5.4), [2], size: 6pt)
    cdraw.content((cx, 4.8), [3], size: 6pt)
    cdraw.content((cx + 0.9, 5.4), [4], size: 6pt)
    cdraw.content((cx + 1.5, 4.6), [5], size: 6pt)
    cdraw.content((cx + 0.6, 4.0), [6], size: 6pt)
  }
  let panel3(cx) = {
    cdraw.circle((cx, 4.8), radius: 1.5, stroke: luma(60))
    cdraw.circle((cx - 0.35, 4.65), radius: 0.7, stroke: luma(60))
    cdraw.content((cx - 0.35, 5.05), [p], size: 6pt)
    cdraw.content((cx - 0.35, 4.3), [q], size: 6pt)
    cdraw.content((cx + 0.9, 5.2), [r], size: 6pt)
    cdraw.content((cx + 0.75, 4.3), [s], size: 6pt)
    cdraw.content((cx + 1.25, 4.8), [t], size: 6pt)
  }
  panel1(3.2)
  panel2(9.4)
  panel3(15.4)
  cdraw.content((3.2, 3.15), [inter 2, union 6], size: 6pt)
  cdraw.content((3.2, 2.5), [J = 1\/3], size: 6pt)
  cdraw.content((9.4, 3.15), [inter 1, union 6], size: 6pt)
  cdraw.content((9.4, 2.5), [J = 1\/6], size: 6pt)
  cdraw.content((15.4, 3.15), [inter 2, union 5], size: 6pt)
  cdraw.content((15.4, 2.5), [J = 2\/5], size: 6pt)
  cdraw.content((9.3, 1.4), [one shared vocabulary per panel, letters are the only data], size: 6pt)
})

== vectors: one sqrt, not two

The cosine similarity of two vectors is their dot product over their
lengths, $cos(u, v) = (u dot v) \/ (|u| |v|)$, the cosine of the angle
between them. Unlike a distance it ignores magnitude entirely: scaling u
by 1000 changes nothing, only direction counts, which is the right
attitude for documents represented by word counts and users by item
ratings. The fixture is two pairs, both built so the norms are perfect
squares and the quotient is exact.

The dry run: pair 1 is u = (1, 1, 0) against v = (1, 0, 1). The dot
product is 1, both squared norms are 2, and $1 \/ sqrt(2 dot 2) = 1\/2$,
printed as `cos1: dot 1 |u|^2 2 |v|^2 2 cos 0.5` and asserted by the
exact comparison "ch06 cosine1 = 1/sqrt(4) = 0.5 exact". Pair 2 is u =
(2, 1) against v = (1, 2): dot $2 dot 1 + 1 dot 2 = 4$, squared norms 5
apiece, and $sqrt(5 dot 5) = 5$ exactly, so cos = 4\/5 = 0.8. The printed
line reads `cos2: dot 4 |u|^2 5 |v|^2 5 cos 0.80000000000000004`,
seventeen significant digits of the same double the check compares `==`
against the literal 0.8, both spellings the nearest double to 4\/5.

#listing("kdd/samples/src/Ch06/similarity.c", first: 60, last: 73,
  caption: [cosine with the pinned single-sqrt spelling])

#callout("pitfall", "the formula pin is load-bearing, not style", [
  The contract sheet pins the spelling `dot / sqrt(su * sv)`, one sqrt
  call over an exact integer product. The double-sqrt spelling
  `dot / (sqrt(su) * sqrt(sv))` is algebraically identical and
  numerically different: on pair 1, sqrt(2) is irrational, both copies
  round, their product lands just above 2, and the quotient becomes
  0.4999999999999999, which fails the exact `c == 0.5`. With one sqrt
  the radicand 4 is a perfect square, sqrt is IEEE exact, and the
  division is correctly rounded. The same pin holds for Pearson below,
  where sqrt(400.0) = 20 exactly. Determinism here is a property of the
  written formula, and the checks freeze it.
])

#diagram([pair 2 in the plane, equal lengths, cos of the angle 0.8], length: 13pt, {
  let px(a) = { 4.4 + a * 1.05 }
  let py(b) = { 1.5 + b * 1.05 }
  cdraw.line((4.4, 1.2), (4.4, 5.6), stroke: (paint: luma(200), dash: "dashed"))
  cdraw.line((3.6, py(0.0)), (8.6, py(0.0)), stroke: (paint: luma(200), dash: "dashed"))
  cdraw.content((4.15, 1.05), [0], size: 6pt)
  let arcpts = ()
  for a in range(27, 64, step: 6) {
    arcpts.push((px(0.95 * calc.cos(a)), py(0.95 * calc.sin(a))))
  }
  for i in range(arcpts.len() - 1) {
    cdraw.line(arcpts.at(i), arcpts.at(i + 1), stroke: luma(120))
  }
  cdraw.line((px(0.0), py(0.0)), (px(2.0), py(1.0)), stroke: luma(60), mark: (end: ">"))
  cdraw.line((px(0.0), py(0.0)), (px(1.0), py(2.0)), stroke: luma(60), mark: (end: ">"))
  cdraw.content((px(2.0) + 0.25, py(1.0) - 0.05), [u = (2,1)], size: 6pt)
  cdraw.content((px(1.0) - 0.55, py(2.0) + 0.25), [v = (1,2)], size: 6pt)
  cdraw.content((px(1.1), py(0.55)), [theta], size: 6pt)
  cdraw.content((12.3, 5.3), [dot = 2 + 2 = 4], size: 6pt)
  cdraw.content((12.3, 4.6), [|u|^2 = |v|^2 = 5], size: 6pt)
  cdraw.content((12.3, 3.9), [sqrt(5 dot 5) = 5 exact], size: 6pt)
  cdraw.content((12.3, 3.2), [cos theta = 4\/5 = 0.8], size: 6pt)
  cdraw.content((12.3, 2.2), [scaling either arrow changes nothing], size: 6pt)
})

== strings: five edits, one alignment

Edit distance counts the cheapest single-character operations that turn
one string into the other. This chapter's pin is unit-cost Levenshtein,
insert 1, delete 1, substitute 1, no transposition, and the sample keeps
only the mining framing: strings are attributes too, product codes and
names and addresses, and record linkage scores their pairs exactly this
way. The full dynamic programming treatment, recurrence proofs and
space-rolling and seven languages of implementation, belongs to
#xref-to("dsa", "dp"); here the three canonical pairs are the payload.

The dry run: kitten to sitting takes 3, substitute k to s, substitute e
to i, insert g. flaw to lawn takes 2, delete f and insert n, and 2 is
optimal because the longest common subsequence law has length 3, and $4
+ 4 - 2 dot 3 = 2$ is exactly the edit distance when only insertions and
deletions pay. intention to execution takes 5, the Jurafsky and
Martin alignment: i against nothing, n to e, t to x, e against e, n to
c, nothing against u, then t, i, o, n all matching, one delete, three
substitutions, one insert. The sample prints `edit: kitten->sitting 3,
flaw->lawn 2, intention->execution 5` and asserts each distance as its
own check.

#listing("kdd/samples/src/Ch06/similarity.c", first: 75, last: 102,
  caption: [two rolling rows, the classic space O(min(m, n)) spelling])

#listing("kdd/samples/src/Ch06/similarity.c", first: 174, last: 181,
  caption: [the three pairs and their checks])

#diagram([the intention to execution alignment, five paid cells], length: 13pt, {
  let top = (([i], [del]), ([n], [sub]), ([t], [sub]), ([e], [match]), ([n], [sub]), ([-], [ins]), ([t], [match]), ([i], [match]), ([o], [match]), ([n], [match]))
  let bot = ([ - ], [e], [x], [e], [c], [u], [t], [i], [o], [n])
  let cost = (1, 1, 1, 0, 1, 1, 0, 0, 0, 0)
  for i in range(10) {
    let x0 = 0.9 + i * 1.58
    let paid = cost.at(i) > 0
    cdraw.rect((x0, 5.9), (x0 + 1.38, 6.6), fill: if paid {luma(228)} else {luma(246)}, radius: 0.01)
    cdraw.content((x0 + 0.69, 6.25), top.at(i).at(0), size: 6.5pt)
    cdraw.rect((x0, 5.1), (x0 + 1.38, 5.8), fill: if paid {luma(228)} else {luma(246)}, radius: 0.01)
    cdraw.content((x0 + 0.69, 5.45), bot.at(i), size: 6.5pt)
    cdraw.content((x0 + 0.69, 4.55), top.at(i).at(1), size: 5.5pt)
    cdraw.content((x0 + 0.69, 3.95), [#cost.at(i)], size: 6pt)
  }
  cdraw.content((0.95, 7.3), [intention], size: 6pt)
  cdraw.content((0.95, 4.55), [ops], size: 5.5pt)
  cdraw.content((0.95, 3.95), [cost], size: 6pt)
  cdraw.content((9.0, 2.9), [1 delete + 3 substitutions + 1 insert = 5], size: 6pt)
  cdraw.content((9.0, 2.25), [four free matches carry the rest], size: 6pt)
})

== correlation: cosine after centering

The Pearson correlation coefficient of two equal-length series is
$r = S_(x y) \/ sqrt(S_(x x) S_(y y))$ with $S_(x y) = sum (x_i - bar(x))
(y_i - bar(y))$, and it is exactly the cosine similarity of the two
mean-centered series. That is the whole connection between this facet
and the last one: Pearson is cosine with the means subtracted first, so
pure offset changes nothing and only linear co-movement counts.

The dry run: over x = 1..5 and y = 2x, the x deviations from mean 3 are
(-2, -1, 0, 1, 2), the y deviations are doubled, and $S_(x y) = 8 + 2 +
0 + 2 + 8 = 20$, $S_(x x) = 10$, $S_(y y) = 4 dot 10 = 40$. One sqrt:
sqrt(400.0) = 20 exactly, so r = 20\/20 = 1, printed as `pearson+: Sxy
20 Sxx 10 Syy 40 r 1` and asserted by "ch06 pearson+ r = 1.0 exact".
Flipping y to 12 - 2x flips every y deviation, so Sxy becomes -20 and r
becomes -1, printed as `pearson-: Sxy -20 r -1`. Both fixtures are
perfect lines, and r only ever spans $[-1, 1]$, the two endpoints pinned
by two checks.

#listing("kdd/samples/src/Ch06/similarity.c", first: 104, last: 125,
  caption: [pearson r, deviations first, the same single-sqrt pin])

#listing("kdd/samples/src/Ch06/similarity.c", first: 183, last: 196,
  caption: [the perfect line, Sxy 20, Sxx 10, Syy 40, r exactly 1])

#diagram([two perfect lines, one rising, one falling, r at both endpoints], length: 13pt, {
  let pa(x) = { 2.6 + (x - 1) * 0.95 }
  let pb(x) = { 10.9 + (x - 1) * 0.95 }
  let pyv(y) = { 1.4 + (y - 2) * 0.4 }
  let xs = (1, 2, 3, 4, 5)
  let up = (2, 4, 6, 8, 10)
  let dn = (10, 8, 6, 4, 2)
  for i in range(5) {
    cdraw.circle((pa(xs.at(i) * 1.0), pyv(up.at(i) * 1.0)), radius: 0.1, fill: luma(210), stroke: luma(60))
    cdraw.circle((pb(xs.at(i) * 1.0), pyv(dn.at(i) * 1.0)), radius: 0.1, fill: luma(210), stroke: luma(60))
  }
  cdraw.line((pa(1.0), pyv(2.0)), (pa(5.0), pyv(10.0)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.line((pb(1.0), pyv(10.0)), (pb(5.0), pyv(2.0)), stroke: (paint: luma(170), dash: "dashed"))
  cdraw.content((pa(3.0), 5.1), [y = 2x], size: 6pt)
  cdraw.content((pa(3.0), 4.5), [r = +1], size: 6pt)
  cdraw.content((pb(3.0), 5.1), [y = 12 - 2x], size: 6pt)
  cdraw.content((pb(3.0), 4.5), [r = -1], size: 6pt)
  cdraw.content((2.6, 0.9), [same Sxx 10, Syy 40, Sxy plus and minus 20], size: 6pt)
  cdraw.content((11.0, 0.9), [r = Sxy \/ sqrt(Sxx Syy)], size: 6pt)
})

Four similarity families, one discipline. Sets, vectors, strings, and
series each got a score that lives in a known range, is computed from
integers or exact dyadic squares, and is pinned by an exact check.
#xref-to("kdd", "features") sharpens the question from how similar two
values are to how much a whole column matters, and chi-square answers it
with the same integer-first arithmetic.

sources: Daniel Jurafsky and James H. Martin, Speech and Language
Processing, 3rd ed. draft, ch 2, minimum edit distance, the
intention/execution alignment, web.stanford.edu/~jurafsky/slp3/,
banked by kdd-contract-s1s2.md. All 23 pinned values, both formula pins
(the single-sqrt cosine and pearson spellings), and the flaw/lawn LCS
optimality note witnessed by kdd-contract-s1s2.md and
playground/kdd-matrix/gen_s2.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch06`, 23 checks in chapter 06 of the kdd
suite.
