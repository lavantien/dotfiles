// ch19, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 21 checks in kdd/samples/src/Ch19/tennis.c (14) and text.c (7) or a
// banked provenance note: the conditionals are counted from Mitchell,
// Machine Learning, McGraw-Hill 1997, Table 3.2 p. 59, the same 14-row
// table kdd-contract-s4s5.md pins and chapter 13 grew a tree from. all
// pinned values are witnessed by the sheet +
// playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0. fractions are
// D0 through a reduced int64 fraction type; printed posteriors D2 1e-12.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= naive bayes

Two samples carry the chapter: `tennis.c` scores two queries against the
play-tennis conditionals with and without smoothing, 14 checks, and
`text.c` classifies one three-word document and plants two argmax ties,
7 checks. The chapter makes 4 moves: the naive product that turns one
query into two scores, the zero cell that kills a branch and the add-1
rescue, the multinomial spelling for counted tokens, and the tie-break
rules that make argmax deterministic. Every behavioral claim below is
one of the 21 checks of chapter 19's samples or the banked Mitchell
provenance. The 14 rows are the same table #xref-to("kdd", "id3") split
on entropy, here read as counts instead, the underlying probability is
the material of #xref-to("math", "statistics"), and the verdicts these
scores produce are judged by #xref-to("kdd", "evaluation").

== one query, four conditionals, two classes

Naive Bayes classifies by Bayes' rule with the naive part being the
denominator's factorization: within each class, the four attribute
values are treated as independent, so the posterior score is the class
prior times four conditionals, all multiplied. The conditionals come
from counting Mitchell's table: outlook sunny happens on 2 of the 9 yes
days and 3 of the 5 no days, and so on down the four attributes, every
count a fact about the 14 rows.

The dry run: query (Sunny, Cool, High, Strong). The yes chain is $9\/14
dot 2\/9 dot 3\/9 dot 3\/9 dot 3\/9 = 1\/189$, the no chain $5\/14 dot
3\/5 dot 1\/5 dot 4\/5 dot 3\/5 = 18\/875$, and the sample prints `q1
yes=1/189 no=18/875`, about 0.00529 against 0.02057. Normalizing prints
`q1 posterior yes=125/611 (0.204582651391) no=486/611 (0.795417348609)`,
both posteriors sharing the denominator 611 because the raw common one,
$875 + 18 dot 189 = 4277 = 7 dot 611$, reduces with each numerator. The
argmax needs no normalization at all: the
check "ch19 q1 cross-mult 875 < 3402" compares the two scores by
cross-multiplication, 1 times 875 against 18 times 189, and the larger
product wins, no.

#listing("kdd/samples/src/Ch19/tennis.c", first: 79, last: 86,
  caption: [the score, prior times four conditionals, smoothing optional])

#listing("kdd/samples/src/Ch19/tennis.c", first: 88, last: 105,
  caption: [query 1, scores, posteriors, and the unnormalized argmax])

#diagram([two factor chains from one query, normalize last or not at all], length: 13pt, {
  cdraw.rect((0.5, 5.7), (4.3, 7.3), fill: luma(240), radius: 0.02)
  cdraw.content((2.4, 6.85), [query], size: 6.5pt)
  cdraw.content((2.4, 6.2), [(sunny, cool,], size: 6pt)
  cdraw.content((2.4, 5.25), [high, strong)], size: 6pt)
  let chain(y, boxes, res, tag) = {
    let xs = (5.0, 7.0, 9.0, 11.0, 13.0)
    for i in range(5) {
      cdraw.rect((xs.at(i), y), (xs.at(i) + 1.8, y + 1.1), fill: luma(246), radius: 0.02)
      cdraw.content((xs.at(i) + 0.9, y + 0.72), boxes.at(i).at(0), size: 6.5pt)
      cdraw.content((xs.at(i) + 0.9, y + 0.28), boxes.at(i).at(1), size: 6pt)
    }
    for i in range(4) {
      cdraw.content((xs.at(i) + 1.9, y + 0.55), [x], size: 6pt)
    }
    cdraw.rect((15.0, y), (17.2, y + 1.1), fill: luma(230), radius: 0.02)
    cdraw.content((16.1, y + 0.55), res, size: 6.5pt)
    cdraw.content((16.1, y + 1.4), tag, size: 6pt)
    cdraw.line((4.3, 6.5), (5.0, y + 0.55), stroke: (paint: luma(150), dash: "dashed"))
  }
  chain(6.0, (([9\/14], [prior]), ([2\/9], [sunny]), ([3\/9], [cool]),
    ([3\/9], [high]), ([3\/9], [strong])), [1\/189], [yes])
  chain(4.4, (([5\/14], [prior]), ([3\/5], [sunny]), ([1\/5], [cool]),
    ([4\/5], [high]), ([3\/5], [strong])), [18\/875], [no])
  cdraw.rect((5.0, 1.0), (17.2, 2.6), fill: luma(242), radius: 0.02)
  cdraw.content((11.1, 2.2), [normalize: yes $arrow.r$ 875\/(875 + 3402) = 125\/611], size: 6pt)
  cdraw.content((11.1, 1.65), [no $arrow.r$ 3402\/(875 + 3402) = 486\/611], size: 6pt)
  cdraw.content((11.1, 1.15), [or skip it: cross-mult 875 < 3402, argmax no], size: 6pt)
  cdraw.content((2.4, 3.4), [18 x 189 = 3402], size: 6pt)
})

#callout("note", "naive means the product is the assumption", [
  Nothing in the 14 rows says outlook is independent of humidity given
  the class, and in real weather they are not. The model multiplies the
  conditionals anyway, which is exactly the naivety, and it survives
  because classification only needs the argmax to be right, not the
  posterior to be calibrated. The same table gave
  #xref-to("kdd", "id3") a tree that consults two attributes and ignores
  temperature entirely, and this chapter's classifier consults all four
  every time: two readers, one table.
])

== the zero cell and the laplace rescue

The second query swaps sunny for overcast, and overcast never appeared
with a no day: 4 yes days, 0 no days, so the conditional P(overcast |
no) is the count 0 over 5. Unsmoothed, that single factor zeroes the
whole no branch, $5\/14 dot 0 dot 1\/5 dot 4\/5 dot 3\/5 = 0$, and the
posterior for no reads exactly 0, a certainty no 14-row table has
earned. The fix is add-1 smoothing, the Laplace estimate, but with the
sheet's
exact convention: conditionals become $(c + 1)\/(n_"class" + |"values"|)$
with the value count per attribute, 3 for outlook and temperature, 2 for
humidity and wind, priors left alone.

The dry run: the before line prints `q2 before yes=2/189 no=0/1`, the
reduced form of an exact zero. After smoothing the yes chain is $9\/14
dot 5\/12 dot 4\/12 dot 4\/11 dot 4\/11 = 10\/847$ and the no chain
$5\/14 dot 1\/8 dot 2\/8 dot 5\/7 dot 4\/7 = 25\/5488$, printed as `q2
after  yes=10/847 no=25/5488`. The posterior line prints `q2 posterior
after yes=1568/2173 (0.721583064887) no=605/2173`, and the closing check
notes the verdict never flipped, yes before and after, what changed is
that the no branch went from 0 to a positive number worth comparing
against.

#listing("kdd/samples/src/Ch19/tennis.c", first: 107, last: 123,
  caption: [query 2, the 0/5 cell before smoothing, both branches after])

#diagram([one zero factor kills the branch, add-1 buys it back], length: 13pt, {
  cdraw.content((9.2, 8.35), [query (overcast, cool, high, strong)], size: 6.5pt)
  let row(y, tag, factors, res, note, zero) = {
    cdraw.content((1.3, y + 0.5), tag, size: 6pt)
    let xs = (2.8, 4.8, 6.8, 8.8, 10.8)
    for i in range(5) {
      let hot = zero and i == 1
      cdraw.rect((xs.at(i), y), (xs.at(i) + 1.8, y + 1.0),
        fill: if hot {luma(214)} else {luma(246)}, radius: 0.02)
      cdraw.content((xs.at(i) + 0.9, y + 0.5), factors.at(i), size: 6pt)
      if i < 4 {
        cdraw.content((xs.at(i) + 1.9, y + 0.5), [x], size: 6pt)
      }
    }
    cdraw.rect((13.0, y), (15.2, y + 1.0),
      fill: if zero {luma(214)} else {luma(230)}, radius: 0.02)
    cdraw.content((14.1, y + 0.5), res, size: 6.5pt)
    cdraw.content((16.6, y + 0.5), note, size: 6pt)
  }
  row(6.6, [no, before], ([5\/14], [0\/5], [1\/5], [4\/5], [3\/5]), [0],
    [dead branch], true)
  row(4.9, [no, after], ([5\/14], [1\/8], [2\/8], [5\/7], [4\/7]), [25\/5488],
    [alive again], false)
  row(3.2, [yes, after], ([9\/14], [5\/12], [4\/12], [4\/11], [4\/11]), [10\/847],
    [never zero], false)
  cdraw.rect((4.0, 1.0), (14.4, 2.2), fill: luma(242), radius: 0.02)
  cdraw.content((9.2, 1.75), [add-1: $(c+1)\/(n_"class" + |"values"|)$, priors untouched], size: 6pt)
  cdraw.content((9.2, 1.25), [posterior after: yes 1568\/2173, no 605\/2173, argmax still yes], size: 6pt)
})

#callout("pitfall", "a zero conditional is a verdict of certainty", [
  With the raw counts, one attribute value the class never saw erases
  every other attribute's evidence in that branch, three informative
  factors multiplied by zero. The table has 14 rows, and a conditional
  of exactly 0 claims no overcast no-day will ever occur, which no
  14-row sample can establish. Add-1 spends one phantom observation per
  cell, and the per-attribute denominator matters: outlook spreads its
  phantom over 3 values, humidity over 2, so the sheet's convention
  keeps humidity's rescue weaker than outlook's.
])

== three words, two mailboxes

Text turns the counts into the model directly. The multinomial spelling
scores a document by the product over its tokens of $("count"_"token" +
1)\/("total" + V)$, where total is the class's token count and V the
vocabulary size, priors up front as before. The fixture is a 3-word
vocabulary and two classes, spam tokens free 3, money 2, meeting 0, 5
total, ham tokens free 1, money 0, meeting 3, 4 total, priors 1/2 each,
and the document is "free money money".

The dry run: the spam chain is $1\/2 dot 4\/8 dot 3\/8 dot 3\/8 =
9\/256$ and the ham chain $1\/2 dot 2\/7 dot 1\/7 dot 1\/7 = 1\/343$,
printed as `doc 'free money money': spam=9/256 ham=1/343`. The
posterior prints `posterior spam=3087/3343 (0.923422075980)`, the
numerator being $9 dot 343 = 3087$ over $3087 + 256$, and the argmax
check fires as "ch19 text argmax spam". Money is the telling token:
spam carries 2 of 5 money tokens, ham 0 of 4, so the word money alone
would have hit ham's zero cell from the last facet, and add-1 is what
keeps the ham score at 1/343 instead of 0.

#listing("kdd/samples/src/Ch19/text.c", first: 90, last: 107,
  caption: [one document through the multinomial product with add-1])

#diagram([the token table and the two chains it prices], length: 13pt, {
  cdraw.content((8.8, 8.35), [token counts per class, totals and V = 3], size: 6pt)
  let cols = ((2.6, [free]), (5.6, [money]), (8.6, [meeting]), (11.6, [total]))
  for c in cols {
    cdraw.content((c.at(0), 7.6), c.at(1), size: 6.5pt)
  }
  cdraw.content((14.4, 7.6), [prior], size: 6.5pt)
  let rows = ((6.3, [spam], ([3], [2], [0], [5]), [1\/2]),
    (4.9, [ham], ([1], [0], [3], [4]), [1\/2]))
  for r in rows {
    cdraw.content((1.1, r.at(0)), r.at(1), size: 6.5pt)
    for i in range(4) {
      let x = cols.at(i).at(0)
      cdraw.rect((x - 1.1, r.at(0) - 0.55), (x + 1.1, r.at(0) + 0.55),
        fill: luma(246), radius: 0.02)
      cdraw.content((x, r.at(0)), r.at(2).at(i), size: 6pt)
    }
    cdraw.content((14.4, r.at(0)), r.at(3), size: 6pt)
  }
  let chain(y, tag, fs, res) = {
    cdraw.content((1.1, y + 0.55), tag, size: 6.5pt)
    let xs = (3.4, 6.0, 8.6)
    cdraw.content((2.4, y + 0.55), [1\/2 x], size: 6pt)
    for i in range(3) {
      cdraw.rect((xs.at(i), y), (xs.at(i) + 1.9, y + 1.1), fill: luma(246), radius: 0.02)
      cdraw.content((xs.at(i) + 0.95, y + 0.72), fs.at(i).at(0), size: 6.5pt)
      cdraw.content((xs.at(i) + 0.95, y + 0.28), fs.at(i).at(1), size: 6pt)
      cdraw.content((xs.at(i) + 2.0, y + 0.55), [x], size: 6pt)
    }
    cdraw.rect((11.3, y), (13.5, y + 1.1), fill: luma(230), radius: 0.02)
    cdraw.content((12.4, y + 0.55), res, size: 6.5pt)
  }
  chain(3.0, [spam], (([4\/8], [free]), ([3\/8], [money]), ([3\/8], [money])), [9\/256])
  chain(1.5, [ham], (([2\/7], [free]), ([1\/7], [money]), ([1\/7], [money])), [1\/343])
  cdraw.content((8.8, 0.5), [doc "free money money", posterior spam 3087\/3343 = 0.923422075980], size: 6.5pt)
})

== when scores tie

An argmax over exact fractions can tie, and a classifier that breaks
ties by floating-point accident is not reproducible. The sample's rule
is the sheet's, in fixed order: highest score wins, equal scores fall to
the larger prior, still equal falls to the lexicographically smaller
class name. Both tie levels are planted, not narrated.

The dry run: the sample prints its rule in words, `tie-break: equal
scores -> larger prior wins; equal priors -> lexicographically smaller
class name (ham < spam)`. The first plant scores both classes 1/6 with
priors 1/2 each, and the check reads "ch19 planted tie (equal score,
equal prior) -> ham", ham winning because it sorts before spam. The
second plant keeps the equal scores but tilts the priors to 1/3 against
2/3, and "ch19 planted tie (equal score) -> larger prior (spam 2/3)"
fires, the second rung overruling the third.

#listing("kdd/samples/src/Ch19/text.c", first: 66, last: 76,
  caption: [the three-rung argmax, score, prior, then name])

#listing("kdd/samples/src/Ch19/text.c", first: 112, last: 120,
  caption: [two planted ties, one resolved at each rung])

#diagram([the tie ladder, each rung only reached when the one above ties], length: 13pt, {
  let rung(y, q, ex, res) = {
    cdraw.rect((1.6, y), (6.6, y + 1.4), fill: luma(246), radius: 0.02)
    cdraw.content((4.1, y + 1.0), q, size: 6.5pt)
    cdraw.content((4.1, y + 0.35), ex, size: 6pt)
    cdraw.line((6.6, y + 0.7), (7.6, y + 0.7), stroke: luma(60), mark: (end: ">"))
    cdraw.content((7.1, y + 1.1), [tie?], size: 6pt)
    cdraw.rect((8.6, y), (13.2, y + 1.4), fill: luma(232), radius: 0.02)
    cdraw.content((10.9, y + 0.5), res, size: 6.5pt)
  }
  cdraw.content((9.0, 8.0), [the argmax ladder, fall through on equality], size: 6pt)
  rung(6.2, [scores differ?], [9\/256 vs 1\/343], [larger score wins, spam])
  rung(4.3, [scores equal?], [1\/6 vs 1\/6, priors 1\/3, 2\/3], [larger prior wins, spam])
  rung(2.4, [priors equal too?], [1\/6 vs 1\/6, priors 1\/2, 1\/2], [lex smaller name, ham])
  cdraw.line((10.9, 6.2), (10.9, 5.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((10.9, 4.3), (10.9, 3.8), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((12.6, 5.95), [fall], size: 6pt)
  cdraw.content((12.6, 4.05), [fall], size: 6pt)
  cdraw.content((9.0, 1.2), [exact fractions make the equality testable at all], size: 6pt)
})

sources: the play-tennis conditionals are counted from Mitchell, Machine
Learning, McGraw-Hill 1997, Table 3.2 p. 59, the dataset introduced by
Quinlan 1986, the same table pinned for chapter 13. The smoothing
convention, add-1 on conditionals with per-attribute denominators
$n_"class" + |"values"|$ and unsmoothed priors, and the tie-break order
are pinned by kdd-contract-s4s5.md and witnessed by
playground/kdd-matrix/gen_s4.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch19`, 14 + 7 checks in chapter 19 of the
kdd suite.
