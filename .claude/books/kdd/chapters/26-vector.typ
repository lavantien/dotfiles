// ch26, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 51 checks in kdd/samples/src/Ch26/vector.c or a banked provenance
// note: the nine baskets are the running example table of Han, Pei, Yin,
// "Mining Frequent Patterns without Candidate Generation", SIGMOD 2000,
// TIDs 100-900, https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf
// (accessed 2026-09-22), the same table chapter 25 mined horizontally.
// all pinned values are witnessed by kdd-contract-s6.md +
// playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0. determinism:
// all D0, tidlists, bit vectors, and integer counts, no doubles.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= vector apriori

One sample carries the chapter: `vector.c` transposes chapter 25's nine
baskets into one transaction list per item and recomputes everything
support-related with set operations, 51 checks. The chapter makes 4
moves: the vertical flip that turns row scanning into list
intersection, the compound tidlists that grow itemsets without touching
the baskets again, the bit-vector spelling where intersection is a
single AND and support is a popcount, and the agreement row asserting
all 13 frequent itemsets match #xref-to("kdd", "apriori") count for
count. The part's arc is one task in three implementations, and this is
the lane that stops re-reading the database.

== one column per item

The horizontal layout of #xref-to("kdd", "apriori") stores one basket
per transaction and asks each candidate to walk all nine rows. The
vertical layout stores one column per item, the tidlist of an item being
the set of transaction ids whose baskets contain it, and the support of
any itemset becomes the size of the intersection of its items' tidlists.
One pass over the baskets builds the five lists, and nothing after that
reads a basket again.

The dry run: the sample prints the five lists, `tidlist
I1:{100,400,500,700,800,900}` down to `tidlist I5:{100,800}`, with
`tidlist I2:{100,200,300,400,600,800,900}` the longest at 7 entries,
every basket but 500 and 700. Then all ten pairs, each one intersection:
`pair {I1,I2}=4`, `pair {I1,I3}=4`, `pair {I1,I4}=1`, `pair {I1,I5}=2`,
`pair {I2,I3}=4`, `pair {I2,I4}=2`, `pair {I2,I5}=2`, `pair {I3,I4}=0`,
`pair {I3,I5}=1`, `pair {I4,I5}=0`. Six pairs clear minsup 2 and four
fall below it, the same four whose absence pruned chapter 25's C3, now
seen from underneath as short intersections instead of small row
counts.

#listing("kdd/samples/src/Ch26/vector.c", first: 78, last: 106,
  caption: [the vertical layout and both support spellings, intersect and scan])

#listing("kdd/samples/src/Ch26/vector.c", first: 153, last: 167,
  caption: [all ten pair supports, one intersection each])

#diagram([the same nine baskets read row-wise and column-wise], length: 13pt, {
  cdraw.content((3.0, 8.3), [horizontal: 9 baskets], size: 6pt)
  cdraw.content((12.2, 8.3), [vertical: 5 tidlists], size: 6pt)
  let rows = (("100", [{I1,I2,I5}]), ("200", [{I2,I4}]), ("300", [{I2,I3}]),
    ("400", [{I1,I2,I4}]), ("500", [{I1,I3}]), ("600", [{I2,I3}]),
    ("700", [{I1,I3}]), ("800", [{I1,I2,I3,I5}]), ("900", [{I1,I2,I3}]))
  for i in range(9) {
    let y = 7.5 - i * 0.72
    cdraw.rect((0.5, y - 0.3), (5.5, y + 0.3), fill: luma(246), radius: 0.02)
    cdraw.content((1.3, y), rows.at(i).at(0), size: 5.5pt)
    cdraw.content((3.5, y), rows.at(i).at(1), size: 5.5pt)
  }
  cdraw.line((5.7, 4.5), (7.6, 4.5), stroke: (paint: luma(60)), mark: (end: ">"))
  cdraw.content((6.6, 5.1), [transpose], size: 6pt)
  cdraw.line((7.6, 3.6), (5.7, 3.6), stroke: (paint: luma(60)), mark: (end: ">"))
  let cols = (("I1", [{100,400,500,700,800,900}]),
    ("I2", [{100,200,300,400,600,800,900}]),
    ("I3", [{300,500,600,700,800,900}]), ("I4", [{200,400}]),
    ("I5", [{100,800}]))
  for i in range(5) {
    let y = 7.1 - i * 1.15
    cdraw.rect((7.9, y - 0.42), (16.9, y + 0.42),
      fill: if i == 1 {luma(228)} else {luma(246)}, radius: 0.02)
    cdraw.content((8.5, y), cols.at(i).at(0), size: 5.8pt)
    cdraw.content((12.5, y), cols.at(i).at(1), size: 5.2pt)
  }
  cdraw.content((12.4, 0.5), [row count at left, intersection size at right], size: 6pt)
})

#callout("note", "antimonotonicity seen from the side", [
  The subset law of chapter 25 shows up here as set inclusion:
  intersecting can only shrink a list, so every item added to an itemset
  weakens or preserves its tidlist, never grows it. {I3,I5} at
  intersection size 1 retires its upper cone exactly like the horizontal
  prune did, with the verdict visible in the lists themselves rather
  than in a rule applied before counting.
])

== compound tidlists

Nothing limits the intersection to pairs. The tidlist of {I1,I2} is the
intersection of the two single-item lists, and it is itself a list, so
triples are one more intersection against a stored result rather than a
new pass over anything.

The dry run: the sample pins three compound lists, `tidlist
{I1,I2}:{100,400,800,900}`, then `tidlist {I1,I2,I3}:{800,900}` from one
more intersection with I3's list, and `tidlist {I1,I2,I5}:{100,800}`
from I5's instead. The two triples are exactly chapter 25's L3, both at
size 2, and the pair lists make the levelwise structure visible: the
eight transactions that ever buy both I1 and I2 narrow to two that also
buy I3, and to a different two that also buy I5, with transaction 800
the only one buying all of I1, I2 and I3.

#listing("kdd/samples/src/Ch26/vector.c", first: 108, last: 130,
  caption: [tidlist and bit-vector strings, the two pinned spellings])

#listing("kdd/samples/src/Ch26/vector.c", first: 169, last: 181,
  caption: [the three compound tidlists, intersections of stored lists])

#diagram([compound supports by intersection alone, no basket read again], length: 13pt, {
  let box = (x, y, hw, lab, sub) => {
    cdraw.rect((x - hw, y - 0.5), (x + hw, y + 0.5), fill: luma(242), radius: 0.02)
    cdraw.content((x, y + 0.12), lab, size: 6pt)
    cdraw.content((x, y - 0.24), sub, size: 5pt)
  }
  box(2.4, 7.3, 1.1, [{I1}], "=6")
  box(6.8, 7.3, 1.1, [{I2}], "=7")
  cdraw.content((4.6, 7.3), [$inter$], size: 8pt)
  cdraw.line((3.2, 6.8), (4.6, 6.0), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.line((6.0, 6.8), (4.6, 6.0), stroke: (paint: luma(120)), mark: (end: ">"))
  box(4.6, 5.5, 1.9, [{I1,I2}=4], [{100,400,800,900}])
  box(10.6, 5.5, 1.1, [{I3}], [6 TIDs])
  box(14.8, 5.5, 1.1, [{I5}], [2 TIDs])
  cdraw.line((6.5, 5.0), (7.4, 3.6), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.line((9.5, 5.0), (7.9, 3.6), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.content((8.9, 4.6), [$inter$ I3], size: 5.8pt)
  box(7.6, 3.1, 1.5, [{I1,I2,I3}=2], [{800,900}])
  cdraw.line((6.3, 5.0), (11.9, 3.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((13.7, 5.0), (12.4, 3.6), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.content((12.0, 4.6), [$inter$ I5], size: 5.8pt)
  box(12.6, 3.1, 1.5, [{I1,I2,I5}=2], [{100,800}])
  cdraw.content((8.6, 1.6), [both triples are chapter 25's L3, at exactly 2], size: 6pt)
})

== bits and popcounts

A tidlist over nine transactions is nine booleans, so the natural
machine spelling is one bit per transaction. The sample prints the
matrix both ways, as transaction vectors `txbits 100:11001` through
`txbits 900:11100`, one char per item in item order, and as item
vectors `itembits I1:100110111` through `itembits I5:100000010`, one
char per transaction in TID order with position 1 the leftmost meaning
T100. It is the same 9 by 5 matrix of 23 set bits read along rows or
down columns.

The payoff is arithmetic. Intersection of two item vectors is one AND,
and support is the popcount of the result. The dry run: `itembits
I2:111101011 popcount=7`, the seven baskets again, and the three pinned
AND rows are `and I1&I2:100100011 popcount=4`, `and I1&I3:000010111
popcount=4`, `and I2&I3:001001011 popcount=4`, the same three 4s the
pair census produced by list intersection, one machine word each.

#listing("kdd/samples/src/Ch26/vector.c", first: 183, last: 206,
  caption: [transaction vectors then item vectors, both byte-pinned])

#listing("kdd/samples/src/Ch26/vector.c", first: 208, last: 221,
  caption: [pairwise AND rows with popcounts, three frequent pairs by name])

#diagram([the vertical matrix as bits, AND intersects, popcount supports], length: 13pt, {
  let tidlab = ("100", "200", "300", "400", "500", "600", "700", "800", "900")
  for c in range(9) {
    cdraw.content((3.3 + c * 0.8, 7.15), tidlab.at(c), size: 4.6pt)
  }
  let bits = ("100110111", "111101011", "001011111", "010100000", "100000010")
  let items = ("I1", "I2", "I3", "I4", "I5")
  for r in range(5) {
    cdraw.content((2.4, 6.6 - r * 0.8), items.at(r), size: 5.5pt)
    for c in range(9) {
      let on = bits.at(r).slice(c, c + 1) == "1"
      cdraw.rect((2.9 + c * 0.8, 6.22 - r * 0.8), (3.7 + c * 0.8, 7.02 - r * 0.8),
        fill: if on {luma(160)} else {luma(250)}, stroke: luma(200))
    }
  }
  cdraw.content((2.4, 1.7), [I1&I2], size: 5.5pt)
  let andbits = "100100011"
  for c in range(9) {
    let on = andbits.slice(c, c + 1) == "1"
    cdraw.rect((2.9 + c * 0.8, 1.32), (3.7 + c * 0.8, 2.12),
      fill: if on {luma(120)} else {luma(250)}, stroke: luma(200))
  }
  cdraw.line((10.3, 4.2), (10.3, 2.0), stroke: (paint: luma(120)), mark: (end: ">"))
  cdraw.content((11.0, 4.55), [AND], size: 6pt)
  cdraw.content((11.0, 1.9), [popcount=4], size: 6pt)
  cdraw.content((8.3, 0.45), [and I1&I2:100100011 popcount=4], size: 6pt)
  cdraw.content((14.3, 4.55), [23 set bits, the same matrix], size: 6pt)
})

#callout("pitfall", "bit order is a convention, and it is load-bearing", [
  The sheet pins position 1 to T100 at the left end, and the printed
  rows are bytes, not numbers: `100100011` read right to left would
  still popcount to 4 but would name the wrong transactions, 800, 400
  and 100 in the wrong order, and any logic keyed on positions, diffsets
  or prefix compression inherits the flip silently. The checks compare
  the full string, not just the count, which is exactly what makes the
  convention testable.
])

== the agreement, all thirteen

The vertical lane can stand alone: enumerate every nonempty itemset,
intersect, keep what clears minsup 2. The sample does exactly that and
sorts the survivors by size then itemset string, and the result must be
chapter 25's harvest, item for item and count for count.

The dry run: thirteen agreement rows print, `agree {I1} vertical=6
horizontal=6` through `agree {I1,I2,I5} vertical=2 horizontal=2`, each
one an intersection size checked against a fresh subset scan, then the
aggregate `fi_count=13 fi_checksum=45` and the sorted `fi:` line,
byte-equal to chapter 25's. This is the second third of the part's
three-way M2 agreement: the levelwise scan, the tidlist intersection,
and #xref-to("kdd", "fpgrowth")'s tree recursion all land on the same 13
itemsets over the same baskets, pinned once per chapter. The vertical
lane got there without a second look at the baskets, which is the whole
argument for it.

#listing("kdd/samples/src/Ch26/vector.c", first: 223, last: 252,
  caption: [enumerate, intersect, keep, the vertical miner and its sort])

#listing("kdd/samples/src/Ch26/vector.c", first: 253, last: 277,
  caption: [thirteen agreement rows, the aggregate, the byte-pinned fi line])

#diagram([one pass builds the columns, every later count is pure set work], length: 13pt, {
  cdraw.rect((0.5, 5.4), (3.5, 7.0), fill: luma(242), radius: 0.02)
  cdraw.content((2.0, 6.5), [9 baskets], size: 6pt)
  cdraw.content((2.0, 5.9), [M2, read once], size: 5.5pt)
  cdraw.line((3.5, 6.2), (4.6, 6.2), stroke: (paint: luma(60)), mark: (end: ">"))
  cdraw.content((4.05, 6.7), [1 pass], size: 5.5pt)
  cdraw.rect((4.6, 5.4), (8.2, 7.0), fill: luma(242), radius: 0.02)
  cdraw.content((6.4, 6.5), [5 tidlists], size: 6pt)
  cdraw.content((6.4, 5.9), [or 5 bit columns], size: 5.5pt)
  cdraw.line((8.2, 6.2), (9.3, 6.2), stroke: (paint: luma(60)), mark: (end: ">"))
  cdraw.content((8.75, 6.7), [$inter$ / AND], size: 5.5pt)
  cdraw.rect((9.3, 5.4), (12.9, 7.0), fill: luma(242), radius: 0.02)
  cdraw.content((11.1, 6.5), [compound lists], size: 6pt)
  cdraw.content((11.1, 5.9), [popcount], size: 5.5pt)
  cdraw.line((12.9, 6.2), (14.0, 6.2), stroke: (paint: luma(60)), mark: (end: ">"))
  cdraw.rect((14.0, 5.4), (17.3, 7.0), fill: luma(232), radius: 0.02)
  cdraw.content((15.65, 6.6), [fi: 13 itemsets], size: 5.8pt)
  cdraw.content((15.65, 6.05), [checksum 45], size: 5.8pt)
  cdraw.content((15.65, 5.6), "= ch25 = ch28", size: 5.5pt)
  cdraw.rect((0.5, 2.2), (17.3, 4.2), fill: luma(248), radius: 0.02, stroke: luma(200))
  cdraw.content((8.9, 3.65), [the horizontal lane it replaces], size: 6pt)
  cdraw.content((8.9, 3.0), [scan all 9 baskets for C1, again for C2, again for C3], size: 5.8pt)
  cdraw.content((8.9, 2.45), [3 full passes, each candidate tested row by row], size: 5.8pt)
  cdraw.content((8.9, 1.1), [same 13 answers, the baskets are read once instead of three times], size: 6pt)
})

sources: the nine-basket table is the running example of Han, Pei, Yin,
Mining Frequent Patterns without Candidate Generation, SIGMOD 2000, TIDs
100-900, https://www.cs.sfu.ca/~jpei/publications/sigmod00.pdf, accessed
2026-09-22, pinned by kdd-contract-s6.md for chapters 25, 26 and 28
together. The tidlist and bit-vector formats, the leftmost-means-T100
convention, and the agreement rows are pinned by the same sheet and
witnessed by playground/kdd-matrix/gen_s6.py, run 2026-09-22, exit 0.
Sample behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch26`, 51 checks in chapter 26
of the kdd suite.
