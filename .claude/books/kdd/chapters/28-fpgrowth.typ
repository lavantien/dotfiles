// ch28, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 23 checks in kdd/samples/src/Ch28/fpgrowth.c (16) and mine.c (7) or
// a banked provenance note: the nine baskets are the running example
// table of Han, Pei, Yin, "Mining Frequent Patterns without Candidate
// Generation", SIGMOD 2000, TIDs 100-900,
// https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf (accessed
// 2026-09-22), the table this algorithm was introduced on, mined by
// chapters 25 and 26 by other means. all pinned values are witnessed by
// kdd-contract-s6.md + playground/kdd-matrix/gen_s6.py, run 2026-09-22,
// exit 0. determinism: all D0, counts and exact strings, no doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= fp-growth

Two samples carry the chapter: `fpgrowth.c` builds the tree, the F-list,
the F-ordered transactions and the five conditional pattern bases, 16
checks, and `mine.c` rebuilds the same tree and runs the recursion to
the full enumeration, 7 checks. The chapter makes 4 moves: the two
counting passes and the frequency order that makes prefixes collide, the
prefix tree that compresses 23 item occurrences into 10 nodes, the
conditional pattern bases that slice the tree per item, and the
recursion that enumerates all 13 frequent itemsets without ever
generating a candidate set, landing byte-identical to
#xref-to("kdd", "apriori") and #xref-to("kdd", "vector"). This is the
third lane of the part's one task.

== two passes and the F-list

Fp-growth reads the database exactly twice. The first pass counts
single items, nothing else, and ranks them: descending count, ties
ascending item, so with I1 and I3 both at 6 the F-list reads I1 first,
and with I4 and I5 both at 2 it reads I4 first. The second pass
rewrites every transaction with its items in that F-list order and
nothing else, infrequent items dropped, though on this fixture at minsup
2 every item survives.

The dry run: the sample prints `flist: I2:7 I1:6 I3:6 I4:2 I5:2`, then
the nine rewrites, `ordered 100: I2,I1,I5`, `ordered 200: I2,I4`,
`ordered 300: I2,I3`, `ordered 400: I2,I1,I4`, `ordered 500: I1,I3`,
`ordered 600: I2,I3`, `ordered 700: I1,I3`, `ordered 800: I2,I1,I3,I5`,
`ordered 900: I2,I1,I3`. Basket 100 held {I1,I2,I5} in item order, now
it reads I2 first because I2 is the most frequent item, and the point
of the convention is exactly that: every transaction fronts-loads the
items it is most likely to share with other transactions.

#listing("kdd/samples/src/Ch28/fpgrowth.c", first: 150, last: 172,
  caption: [the F-list, descending count with ties to the smaller item])

#listing("kdd/samples/src/Ch28/fpgrowth.c", first: 186, last: 208,
  caption: [pass 2, each transaction rewritten in F-list order and fed to the tree])

#diagram([rank by count, then write transactions so shared items come first], length: 13pt, {
  let rank = (y, lab, n, w) => {
    cdraw.content((1.0, y), lab, size: 5.8pt)
    cdraw.rect((1.9, y - 0.28), (1.9 + n * 0.62, y + 0.28), fill: luma(170), radius: 0.02)
    cdraw.content((1.9 + n * 0.62 + 0.3, y), [#n], size: 5.8pt)
  }
  cdraw.content((3.4, 8.2), [the F-list], size: 6pt)
  rank(7.3, [I2], 7, 0)
  rank(6.4, [I1], 6, 0)
  rank(5.5, [I3], 6, 0)
  rank(4.6, [I4], 2, 0)
  rank(3.7, [I5], 2, 0)
  cdraw.content((4.1, 2.75), [ties: I1 before I3, I4 before I5], size: 5.6pt)
  let tx = (y, before, after) => {
    cdraw.rect((7.6, y - 0.35), (11.6, y + 0.35), fill: luma(246), radius: 0.02)
    cdraw.content((9.6, y), before, size: 5.8pt)
    cdraw.line((11.8, y), (12.7, y), stroke: (paint: luma(60)), mark: (end: ">"))
    cdraw.rect((12.9, y - 0.35), (16.9, y + 0.35), fill: luma(232), radius: 0.02)
    cdraw.content((14.9, y), after, size: 5.8pt)
  }
  cdraw.content((12.25, 8.2), [item order becomes F order], size: 6pt)
  tx(6.8, [100 {I1,I2,I5}], [I2,I1,I5])
  tx(5.4, [500 {I1,I3}], [I1,I3])
  tx(4.0, [800 {I1,I2,I3,I5}], [I2,I1,I3,I5])
  cdraw.content((12.25, 2.75), [I2 fronts 7 of 9 baskets, so I2 leads], size: 5.6pt)
})

#callout("note", "ordering is the compression strategy", [
  Nothing about the baskets changes when they are rewritten, the items
  are the same items. What changes is which prefixes collide: putting
  the most frequent item first means the tree below it amortizes over
  the most transactions. Sorting alphabetically instead would build an
  honest tree that shares almost nothing, and the recursion later would
  walk ten skinny conditional trees instead of a few bushy ones.
])

== the tree: shared prefixes, counted edges

The second pass inserts each F-ordered transaction into a tree that
starts at a null root. Walking the transaction item by item, an existing
child is reused and its count incremented, a missing child is created
with count 1, and children are kept in first-insertion order. Basket
100 builds I2, I1, I5 off the root. Basket 200 shares I2 and forks to
I4. Basket 500 is the first transaction without I2, so it creates the
root's second child I1.

The dry run: after all nine insertions the sample prints the whole tree
as the pinned 11-line string, `null`, `-I2:7`, `--I1:4`, `---I5:1`,
`---I4:1`, `---I3:2`, `----I5:1`, `--I4:1`, `--I3:2`, `-I1:2`, `--I3:2`.
Ten real nodes hold what was 23 item occurrences across the nine
baskets, I2's seven baskets all ride one node, and every count is
legible directly: I2:7 at depth 1, the four baskets that pair I2 with
I1 at depth 2, the lone basket 800 extending I2, I1, I3 with I5 at depth
4. Insertion order is pinned too, children appear when first created,
which is why I5 precedes I4 and I3 under I2-I1.

#listing("kdd/samples/src/Ch28/fpgrowth.c", first: 66, last: 101,
  caption: [insertion, reuse or create, children and node links in first-insertion order])

#diagram([the fp-tree, solid edges share prefixes, the dashed chain is the I5 node link], length: 13pt, {
  let nd = (x, y, lab, hot) => {
    cdraw.rect((x - 0.62, y - 0.38), (x + 0.62, y + 0.38),
      fill: if hot {luma(214)} else {luma(242)}, radius: 0.02)
    cdraw.content((x, y), lab, size: 5.8pt)
  }
  let e = (x1, y1, x2, y2) => {
    cdraw.line((x1, y1 - 0.38), (x2, y2 + 0.38), stroke: (paint: luma(150)))
  }
  nd(7.6, 8.5, [null], false)
  nd(4.6, 6.9, [I2:7], false)
  nd(12.6, 6.9, [I1:2], false)
  nd(2.0, 5.3, [I1:4], false)
  nd(6.0, 5.3, [I4:1], false)
  nd(8.9, 5.3, [I3:2], false)
  nd(0.9, 3.7, [I5:1], true)
  nd(3.1, 3.7, [I4:1], false)
  nd(5.3, 3.7, [I3:2], false)
  nd(8.9, 3.7, [I5:1], true)
  nd(12.6, 5.3, [I3:2], false)
  e(7.6, 8.5, 4.6, 6.9)
  e(7.6, 8.5, 12.6, 6.9)
  e(4.6, 6.9, 2.0, 5.3)
  e(4.6, 6.9, 6.0, 5.3)
  e(4.6, 6.9, 8.9, 5.3)
  e(2.0, 5.3, 0.9, 3.7)
  e(2.0, 5.3, 3.1, 3.7)
  e(2.0, 5.3, 5.3, 3.7)
  e(8.9, 5.3, 8.9, 3.7)
  e(12.6, 6.9, 12.6, 5.3)
  cdraw.line((0.9, 3.32), (0.9, 2.35), stroke: (paint: luma(90), dash: "dashed"))
  cdraw.line((0.9, 2.35), (8.9, 2.35), stroke: (paint: luma(90), dash: "dashed"))
  cdraw.line((8.9, 2.35), (8.9, 3.32), stroke: (paint: luma(90), dash: "dashed"), mark: (end: ">"))
  cdraw.content((4.9, 1.85), [I5 node link, first inserted to last], size: 5.6pt)
  cdraw.content((13.9, 4.6), [10 nodes hold, 23 occurrences], size: 5.6pt)
})

== conditional pattern bases

The node links thread every node of one item together in insertion
order, and following a link collects each node's path back to the root:
the prefix items above it, with the node's own count. That collection
is the item's conditional pattern base, the slice of the database in
which the item occurs, spelled as paths in F-list order.

The dry run: the sample prints all five, `cpb I2 <= <e>:7`, the
frequentest item has no prefix at all, `cpb I1 <= I2:4 ; <e>:2`, one
path through I2 and one direct, `cpb I3 <= I2:2 ; I1:2 ; I2,I1:2`,
I3's three nodes, `cpb I4 <= I2:1 ; I2,I1:1`, and `cpb I5 <= I2,I1:1 ;
I2,I1,I3:1`. The I5 base is the one worked to the bottom. Its
conditional supports are I2 at 2, I1 at 2, but I3 at 1, appearing in
only one of the two paths, and the sheet's rule drops items below
minsup inside the base: the sample prints `cond I3 support=1 minsup=2`
and checks "ch28 I5 base drops I3 (conditional support 1 < 2)". What
remains is a single path, `condtree(I5):` `null`, `-I2:2`, `--I1:2`,
and a single-path tree enumerates directly, every subset of the path
joining the suffix item at the path count: `base_itemsets: {I5}=2;
{I1,I5}=2;{I2,I5}=2;{I1,I2,I5}=2`, four itemsets that are exactly
chapter 25's I5-containing frequent sets.

#listing("kdd/samples/src/Ch28/fpgrowth.c", first: 128, last: 144,
  caption: [one item's paths collected over the node link, prefixes top-down])

#listing("kdd/samples/src/Ch28/mine.c", first: 174, last: 202,
  caption: [conditional support per item, then the rebuild without the dropped ones])

#diagram([the I5 base, its drop, and the single-path conditional tree it becomes], length: 13pt, {
  cdraw.rect((0.4, 4.7), (6.3, 8.0), fill: luma(248), radius: 0.02, stroke: luma(200))
  cdraw.content((3.35, 7.55), [the two I5 paths], size: 6pt)
  cdraw.content((3.35, 6.8), [I2, I1 -> I5 : 1], size: 5.8pt)
  cdraw.content((3.35, 6.1), [I2, I1, I3 -> I5 : 1], size: 5.8pt)
  cdraw.content((3.35, 5.35), [cpb I5 <= I2,I1:1 ;, I2,I1,I3:1], size: 5.4pt)
  cdraw.line((6.3, 6.35), (7.3, 6.35), stroke: (paint: luma(60)), mark: (end: ">"))
  cdraw.rect((7.3, 4.7), (11.4, 8.0), fill: luma(248), radius: 0.02, stroke: luma(200))
  cdraw.content((9.35, 7.55), [conditional support], size: 6pt)
  cdraw.content((9.35, 6.8), [I2: 2 keep], size: 5.8pt)
  cdraw.content((9.35, 6.1), [I1: 2 keep], size: 5.8pt)
  cdraw.content((9.35, 5.4), [I3: 1 drop], size: 5.8pt)
  cdraw.line((11.4, 6.35), (12.4, 6.35), stroke: (paint: luma(60)), mark: (end: ">"))
  cdraw.rect((12.4, 4.7), (17.1, 8.0), fill: luma(248), radius: 0.02, stroke: luma(200))
  cdraw.content((14.75, 7.55), [condtree(I5)], size: 6pt)
  cdraw.content((14.75, 6.8), [null -> I2:2 -> I1:2], size: 5.8pt)
  cdraw.content((14.75, 6.0), [{I5}=2;{I1,I5}=2;], size: 5.4pt)
  cdraw.content((14.75, 5.4), [{I2,I5}=2;{I1,I2,I5}=2], size: 5.4pt)
  cdraw.content((8.75, 3.6), [minsup applies inside the base, I3 at 1 goes, the tree collapses to one path], size: 5.8pt)
})

#callout("pitfall", "path order is F-list order, not alphabetical", [
  The pinned base for I5 reads `I2,I1,I3`, which is not sorted, and
  that is deliberate: the path is the prefix of an F-ordered
  transaction, so it inherits the frequency order. Sorting it to
  `I1,I2,I3` would still describe the same baskets but would break byte
  equality with the pinned string and, worse, would misorder the
  conditional tree's own children, whose first-insertion order is what
  the next recursion level's node links depend on.
])

== the recursion, and the third agreement

Mining is the base construction applied recursively. For each item in
descending F-list order, worst first, the item joins a growing suffix,
its conditional pattern base becomes the next tree, and the recursion
continues inside that fragment. Because transactions are F-ordered, a
prefix path ending at an item can only contain items ranked above it,
so an itemset is always emitted in the branch of its own member that
comes last in the F-list, once and only once.

The dry run: the sample runs the full recursion and prints
`fi_count=13 fi_checksum=45`, then the sorted `fi:` line, then
`equal_to_apriori=true`, checked as "ch28 fp-growth fi equals ch25
apriori (three-way M2 agreement)". The partition by last-F-list member
accounts for all 13: the I5 branch owns the four I5-containing sets,
I4's owns {I4} and {I2,I4}, I3's owns {I3}=6, {I1,I3}=4, {I2,I3}=4 and
{I1,I2,I3}=2, I1's owns {I1}=6 and {I1,I2}=4, and I2's owns {I2}=7
alone, with column sums 8, 4, 16, 10 and 7 adding to the checksum 45.
No candidate was ever generated, no subset was ever tested against a
previous level, and the prune of chapter 25 has no counterpart here
because there is nothing to prune: the tree only ever contains
frequent-prefix material by construction.

#listing("kdd/samples/src/Ch28/mine.c", first: 209, last: 229,
  caption: [the recursion, suffix grows, conditional tree shrinks])

#listing("kdd/samples/src/Ch28/mine.c", first: 382, last: 395,
  caption: [the byte-equal fi line and the equal_to_apriori verdict])

#diagram([the suffix recursion owns each itemset exactly once, by last F-list member], length: 13pt, {
  let col = (x, head, rows, sum) => {
    cdraw.rect((x, 1.7), (x + 3.05, 7.6), fill: luma(246), radius: 0.02)
    cdraw.content((x + 1.52, 7.1), head, size: 6.2pt)
    let y = 6.3
    for r in rows {
      cdraw.content((x + 1.52, y), r, size: 5.4pt)
      y -= 0.68
    }
    cdraw.content((x + 1.52, 2.25), [sum ] + sum, size: 5.8pt)
  }
  col(0.4, [suffix {I5}], ([{I5}=2], [{I1,I5}=2], [{I2,I5}=2], [{I1,I2,I5}=2]), [8])
  col(3.65, [suffix {I4}], ([{I4}=2], [{I2,I4}=2]), [4])
  col(6.9, [suffix {I3}], ([{I3}=6], [{I1,I3}=4], [{I2,I3}=4], [{I1,I2,I3}=2]), [16])
  col(10.15, [suffix {I1}], ([{I1}=6], [{I1,I2}=4]), [10])
  col(13.4, [suffix {I2}], (([{I2}=7]),), [7])
  cdraw.content((8.55, 8.3), [items visited worst-first: I5, I4, I3, I1, I2], size: 6pt)
  cdraw.content((8.55, 0.9), [13 itemsets, column sums 8 + 4 + 16 + 10 + 7 = 45, equal_to_apriori=true], size: 6pt)
})

sources: the nine-basket table, the F-list, the ordering convention, the
tree string, the five conditional pattern bases and the agreement rows
are the running example of Han, Pei, Yin, Mining Frequent Patterns
without Candidate Generation, SIGMOD 2000, TIDs 100-900,
https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf, accessed
2026-09-22, as pinned by kdd-contract-s6.md and witnessed by
playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch28`, 16 + 7 checks in chapter 28 of the
kdd suite.
