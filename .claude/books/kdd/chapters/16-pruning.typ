// ch16, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 39 checks in kdd/samples/src/Ch16/prune.c or a banked note of
// kdd-contract-s3.md (the REP procedure after Quinlan 1987, the minsplit
// pre-pruning rule, the deepest-then-leftmost tie-break, the deliberate
// minsplit=5 == REP-final anchor). both fixtures are constructed on the
// sheet. all pinned values are witnessed by kdd-contract-s3.md +
// playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= overfitting and pruning

One sample carries the chapter: `prune.c` grows a tree on 8 rows
planted with 2 label flips, watches it ace its training set and miss
its validation set, then cuts it back with reduced-error pruning until
the validation verdict is perfect, 39 checks. The chapter makes 4
moves: the fixture and the overgrown tree, the pruning rounds one
collapse at a time, what the pruning cost and bought, and pre-pruning
by minsplit landing on the same tree by another road. Every behavioral
claim below is one of the 39 checks of chapter 16's sample or a named
note of the contract sheet. The growth machinery is chapter 13's,
#xref-to("kdd", "id3"), and the judgment that validation beats
training accuracy is the whole subject of #xref-to("kdd", "evaluation").

== a fixture planted to overfit

The true concept is one rule, x1 means yes and x2 means no, and the
training set is that concept with two label flips, rows 4 and 8, so
the flips are the only impurity a purity-hungry grower can chase. The
attributes y and z are noise, but noise is exactly what depth can
memorize: at the root they look useless, and one level down they look
necessary.

The dry run: the root prints `root H(S) =
-(4/8)lg2(4/8)-(4/8)lg2(4/8) = 1.000000000000000`, four yes against
four no, asserted with `==`. The root gains print `root
Gain(x)=0.188721875540867 Gain(y)=0.000000000000000
Gain(z)=0.000000000000000`: y and z split the root into balanced (2,
2) pairs both ways, gain exactly zero, while x separates into (3 yes,
1 no) on each side. Under either x branch the noise turns useful,
`x=x1 node H(3,1)=0.811278124459133 Gain(y)=0.311278124459133
Gain(z)=0.311278124459133 -> y`, a perfect tie resolved to y by header
order, asserted as "ch16 x2 gains y=z, tie -> y by header order". The
grown tree prints `T0 x(x1->y(y1->leaf:yes y2->z(z1->leaf:no
z2->leaf:yes)) x2->y(y1->leaf:no y2->z(z1->leaf:yes z2->leaf:no)))`,
and the score line is the whole story, `T0 train 8/8 validation 4/6`:
the two z levels exist to encode the two flips.

#listing("kdd/samples/src/Ch16/prune.c", first: 46, last: 65,
  caption: [8 training rows with 2 planted flips, 6 noise-free validation rows])

#listing("kdd/samples/src/Ch16/prune.c", first: 296, last: 321,
  caption: [the y against z tie under each x branch, header order decides])

#diagram([T0, six leaves, the two z levels exist only to fit the flips], length: 13pt, {
  let node(x0, y0, name) = {
    cdraw.rect((x0, y0), (x0 + 2.2, y0 + 0.62), fill: luma(240), radius: 0.02)
    cdraw.content((x0 + 1.1, y0 + 0.31), name, size: 6.5pt)
  }
  let leaf(x0, y0, cls, rows, flip) = {
    cdraw.rect((x0, y0), (x0 + 2.6, y0 + 0.62),
      fill: if flip {luma(226)} else {luma(248)}, radius: 0.02)
    cdraw.content((x0 + 1.3, y0 + 0.31), [#cls, #rows], size: 6pt)
  }
  node(7.9, 7.6, [x])
  node(2.4, 6.0, [y])
  node(13.0, 6.0, [y])
  node(0.2, 4.0, [z])
  node(12.6, 4.0, [z])
  leaf(0.6, 2.2, [no], [row 4], true)
  leaf(3.4, 2.2, [yes], [row 2], false)
  leaf(3.0, 5.2, [yes], [rows 1,3], false)
  leaf(12.9, 2.2, [yes], [row 8], true)
  leaf(15.7, 2.2, [no], [row 6], false)
  leaf(15.3, 5.2, [no], [rows 5,7], false)
  cdraw.line((8.4, 7.6), (3.9, 6.62), stroke: luma(60))
  cdraw.content((5.4, 7.35), [x1], size: 6pt)
  cdraw.line((9.6, 7.6), (13.7, 6.62), stroke: luma(60))
  cdraw.content((12.1, 7.35), [x2], size: 6pt)
  cdraw.line((2.9, 6.0), (3.7, 5.82), stroke: luma(60))
  cdraw.content((2.1, 5.5), [y1], size: 6pt)
  cdraw.line((4.2, 6.0), (2.0, 4.62), stroke: luma(60))
  cdraw.content((4.5, 5.4), [y2], size: 6pt)
  cdraw.line((13.5, 6.0), (15.9, 5.82), stroke: luma(60))
  cdraw.content((14.6, 5.55), [y1], size: 6pt)
  cdraw.line((13.2, 6.0), (14.2, 4.62), stroke: luma(60))
  cdraw.content((12.3, 5.4), [y2], size: 6pt)
  cdraw.line((1.2, 4.0), (1.6, 2.82), stroke: luma(60))
  cdraw.content((0.8, 3.4), [z1], size: 6pt)
  cdraw.line((1.9, 4.0), (5.0, 2.82), stroke: luma(60))
  cdraw.content((4.4, 3.4), [z2], size: 6pt)
  cdraw.line((13.9, 4.0), (14.5, 2.82), stroke: luma(60))
  cdraw.content((13.6, 3.4), [z1], size: 6pt)
  cdraw.line((14.3, 4.0), (17.2, 2.82), stroke: luma(60))
  cdraw.content((16.6, 3.4), [z2], size: 6pt)
  cdraw.content((9.0, 1.1), [shaded leaves are the planted flips, rows 4 and 8], size: 6pt)
})

#callout("note", "noise looks useless at the root and load-bearing below it", [
  Gain zero for y and z at the root is not evidence of irrelevance, it
  is an average. Each side of the x split holds one flip, and below x
  the noise attributes separate that flip perfectly, gain 0.311 each
  way. A purity criterion cannot tell memorization from structure, it
  only sees impurity falling, which is why the fix has to come from
  outside the training set.
])

== three collapses, then a stop

Reduced-error pruning, Quinlan 1987, as fixed by the sheet: every
internal node is a candidate to become a leaf labeled with the
majority class of the training rows reaching it, the payoff is delta,
validation-correct after the collapse minus before, and the winner is
max delta with ties going deepest, then leftmost in serialization
order; a collapse applies whenever delta $>=$ 0.

The dry run: round 1 lists all five internal nodes, from `r1 cand x ->
leaf:no delta=-1 val 3/6` to three nodes tied at +1, and the deepest
of them wins, "ch16 r1 deepest of +1 tie chosen", `r1 cand x=x2/y=y2/z
-> leaf:no delta=1 val 5/6`, validation moving 4 to 5 of 6. Round 2
has a unique best, `r2 cand x=x1/y -> leaf:yes delta=1 val 6/6`, the
tree now perfect on validation. Round 3 still fires, `r3 cand x=x2/y
-> leaf:no delta=0 val 6/6`, because zero delta qualifies under the
$>=$ 0 rule, collapsing a node whose children already agree. Round 4
sees only the root at delta -3 and stops. The sequence prints `final
tree x(x1->leaf:yes x2->leaf:no) (3 collapses)`, the true concept
recovered.

#listing("kdd/samples/src/Ch16/prune.c", first: 352, last: 375,
  caption: [one round: price every node, take max delta, deepest then leftmost])

#listing("kdd/samples/src/Ch16/prune.c", first: 381, last: 397,
  caption: [the eleven pinned candidate deltas across the applied rounds])

#diagram([the pruning rounds, validation climbing 4, 5, 6, 6 of 6, then stop], length: 13pt, {
  let st(x0, name, val, hot) = {
    cdraw.rect((x0, 4.6), (x0 + 3.0, 6.2),
      fill: if hot {luma(234)} else {luma(246)}, radius: 0.02)
    cdraw.content((x0 + 1.5, 5.75), name, size: 6.5pt)
    cdraw.content((x0 + 1.5, 5.1), [val #val], size: 6pt)
  }
  st(0.7, [T0], [4\/6], true)
  st(4.6, [T1], [5\/6], false)
  st(8.5, [T2], [6\/6], false)
  st(12.4, [T3], [6\/6], false)
  let ar(x0, lab) = {
    cdraw.line((x0, 5.4), (x0 + 0.9, 5.4), stroke: luma(60), mark: (end: ">"))
    cdraw.content((x0 + 0.45, 6.5), lab, size: 6pt)
  }
  ar(3.7, [collapse z])
  ar(7.6, [collapse y])
  ar(11.5, [collapse y, delta 0])
  cdraw.line((15.4, 5.4), (16.3, 5.4), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.content((15.85, 6.5), [stop], size: 6pt)
  cdraw.content((15.4, 4.5), [root at -3], size: 6pt)
  cdraw.content((8.4, 3.3), [T3 = x(x1->leaf:yes x2->leaf:no)], size: 6.5pt)
  cdraw.content((8.4, 2.6), [the one-rule concept, recovered], size: 6pt)
})

== what the pruning cost, and what it bought

The pruned tree is worse where the overgrown one shined. T0 scored
8\/8 on training because it memorized the flips; T3 scores 6 of 8
there, exactly the two flips it now gets wrong, and 6 of 6 on
validation, exactly the noise it stopped chasing.

The dry run: the closing block prints `final train 6/8 validation
6/6`, with both fractions asserted by cross-multiplication,
"ch16 final train fraction 3/4" and "ch16 final validation fraction
1". Compare the opening `T0 train 8/8 validation 4/6`: training
accuracy fell by a quarter, validation rose by a third, and the two
training rows T3 misses are rows 4 and 8, the planted flips. The tree
that admits two errors on data it saw is the one that makes none on
data it did not.

#listing("kdd/samples/src/Ch16/prune.c", first: 189, last: 196,
  caption: [accuracy on any table, an optional trial collapse built in])

#listing("kdd/samples/src/Ch16/prune.c", first: 421, last: 430,
  caption: [the post-prune score, both fractions cross-multiplied])

#diagram([train falls, validation rises, the trade is the point], length: 13pt, {
  let h(v) = { 0.7 + v * 5.6 }
  let grp(x0, tag, tr, va) = {
    cdraw.content((x0 + 1.55, 7.35), tag, size: 6.5pt)
    cdraw.rect((x0, 0.7), (x0 + 1.3, h(tr)), fill: luma(238), radius: 0.02)
    cdraw.content((x0 + 0.65, h(tr) + 0.4), [train #tr], size: 6pt)
    cdraw.rect((x0 + 1.8, 0.7), (x0 + 3.1, h(va)), fill: luma(218), radius: 0.02)
    cdraw.content((x0 + 2.45, h(va) + 0.4), [val #va], size: 6pt)
  }
  cdraw.line((1.0, 0.7), (16.6, 0.7), stroke: luma(60))
  grp(3.0, [T0, grown to purity], 1.0, 4.0 / 6.0)
  grp(10.0, [T3, after REP], 6.0 / 8.0, 1.0)
  cdraw.content((8.3, 3.2), [bars are fractions of each set answered correctly], size: 6pt)
})

#callout("pitfall", "the metric you prune by is the metric you keep", [
  REP improves validation accuracy because it optimizes validation
  accuracy, and this fixture hands it a clean, noise-free set to
  optimize against. Prune against a noisy or tiny validation set and
  the same greedy loop will happily fit the noise in that set instead.
  The honest protocols hold out a third sample to score the final
  tree, the machinery of #xref-to("kdd", "evaluation"), and
  #xref-to("kdd", "ensembles") takes the opposite road entirely,
  averaging many overfit trees rather than cutting one back.
])

== the same tree by another road

Post-pruning grows too much and cuts back. Pre-pruning refuses to
grow: the sheet's rule splits a node only when it holds at least
minsplit rows and at least two classes. On this fixture the z nodes
see 2 rows each and the y nodes see 4, so minsplit 3 freezes the z
level and minsplit 5 freezes the y level.

The dry run: minsplit 3 prints `minsplit=3 x(x1->y(y1->leaf:yes
y2->leaf:no) x2->y(y1->leaf:no y2->leaf:no)) train 6/8`, an
intermediate tree that already matches T3's training score without
ever seeing the validation set. Minsplit 5 prints `minsplit=5
x(x1->leaf:yes x2->leaf:no) train 6/8`, and check 39 is the pinned
cross-check, "ch16 minsplit=5 paren == REP final paren": two code
paths that never share a line of pruning logic, a growth-time row
count and a validation-driven collapse loop, producing byte-identical
strings. The anchor is deliberate, planted by the contract sheet so
the two halves of this chapter cannot drift apart silently.

#listing("kdd/samples/src/Ch16/prune.c", first: 127, last: 130,
  caption: [the pre-pruning gate, too few rows means a majority leaf])

#listing("kdd/samples/src/Ch16/prune.c", first: 432, last: 450,
  caption: [minsplit 3 and 5 regrown, and the identity with the REP result])

#diagram([three sizes of tree, pre-pruning and post-pruning meet in the middle], length: 13pt, {
  let panel(x0, tag, sub, ni, nl) = {
    cdraw.content((x0 + 2.1, 7.3), tag, size: 6.5pt)
    cdraw.content((x0 + 2.1, 6.75), sub, size: 6pt)
    let xs(n, i) = {
      if n == 1 { x0 + 2.1 } else { x0 + 0.3 + i * 3.6 / (n - 1) }
    }
    let internals = ()
    for i in range(ni) {
      let x = xs(ni, i)
      internals.push(x)
      cdraw.circle((x, 5.4), radius: 0.16, fill: luma(226), stroke: luma(60))
    }
    let leaves = ()
    for j in range(nl) {
      let x = xs(nl, j)
      leaves.push(x)
      cdraw.rect((x - 0.14, 3.9), (x + 0.14, 4.18), fill: luma(240), stroke: luma(60))
    }
    for a in internals {
      for b in leaves {
        cdraw.line((a, 5.24), (b, 4.18), stroke: luma(200))
      }
    }
  }
  panel(0.8, [T0, grown to purity], [5 internal, 6 leaves, val 4\/6], 5, 6)
  panel(6.4, [minsplit = 3], [3 internal, 4 leaves, train 6\/8], 3, 4)
  panel(12.0, [minsplit = 5 = REP], [1 internal, 2 leaves, train 6\/8], 1, 2)
  cdraw.content((4.6, 3.0), [post-prune walks left], size: 6pt)
  cdraw.line((4.9, 2.6), (2.6, 2.0), stroke: luma(120), mark: (end: ">"))
  cdraw.content((13.8, 2.4), [both roads end here], size: 6pt)
})

sources: reduced-error pruning per Quinlan 1987, and the minsplit
pre-pruning rule, both fixed by kdd-contract-s3.md, with both fixtures
constructed there and every pinned value witnessed by
playground/kdd-matrix/gen_s3.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch16`, 39 checks in chapter
16 of the kdd suite.
