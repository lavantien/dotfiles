// ch11, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 76 checks in kdd/samples/src/Ch11/olap.c or a named term from a
// banked source: Kimball & Ross, The Data Warehouse Toolkit, 2002 (star
// schema and the operation vocabulary), Gray, Bosworth, Layman, Pirahesh,
// Data Cube, ICDE 1996 (cube-lattice cell counting). all pinned values are
// witnessed by kdd-contract-s3.md + playground/kdd-matrix/gen_s3.py, run
// 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= data cubes and olap

One sample carries the chapter: `olap.c` aggregates a 12-row fact table
along three dimension hierarchies and asserts 76 checks, every one an
integer comparison. The chapter makes 4 moves: the star schema and its
one additive measure, the cube lattice the dimensions generate and how
sparse it is, roll-up and drill-down as aggregation up and down the
hierarchies, and slice, dice, and the pivot as selection and reshape.
Every behavioral claim below is one of the 76 checks of chapter 11's
sample or a named term from Kimball and Ross or Gray et al. The ten
preprocessing chapters behind us shaped one table at a time; from here
the book models, and a model consumes exactly the aggregated shapes this
chapter computes, starting with #xref-to("kdd", "regression") next.
#xref-to("kdd", "capstone") rebuilds this whole aggregation lane in go
over duckdb.

== the star, and the twelve facts

A star schema puts the measurements in the middle and the context around
them: a fact table of units sold, one row per (month, product, city)
triple, and a dimension table per axis, each carrying a hierarchy, month
to quarter, product to category, city to country. The vocabulary is
Kimball and Ross's: facts are the numeric events, dimensions are the
axes you slice them along, and the one measure here, units, is additive
along all three axes, which is what makes every sum in this chapter a
sub-sum of one total.

The dry run: the twelve units read 4, 2, 6, 1, 3, 1, 5, 2, 6, 3, 7, 2,
and their sum is the number everything else hangs off, printed as `grand
total units 42` and asserted as "ch11 grand total units 42". That check
is the additive anchor: every later value, group-by cell, roll-up,
slice, dice, and pivot margin, is a partition or sub-sum of the same
twelve numbers, and the closing margin check lands on 42 again from a
completely different direction.

#listing("kdd/samples/src/Ch11/olap.c", first: 28, last: 38,
  caption: [the fact table, 12 rows, one additive measure])

#listing("kdd/samples/src/Ch11/olap.c", first: 44, last: 54,
  caption: [the three hierarchies, quarter, category, country])

#diagram([the star: one fact table, three dimensions, three hierarchies], length: 13pt, {
  cdraw.rect((7.4, 3.2), (11.6, 5.6), fill: luma(240), radius: 0.02)
  cdraw.content((9.5, 5.15), [facts, 12 rows], size: 6.5pt)
  cdraw.content((9.5, 4.5), [month product city], size: 6pt)
  cdraw.content((9.5, 3.9), [measure: units], size: 6pt)
  cdraw.content((9.5, 3.4), [grand total 42], size: 6pt)
  let dim(x0, y0, x1, y1, title, base, up) = {
    cdraw.rect((x0, y0), (x1, y1), fill: luma(246), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y1 - 0.42), title, size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, y1 - 0.98), base, size: 6pt)
    cdraw.content(((x0 + x1) / 2, y1 - 1.54), up, size: 6pt)
  }
  dim(1.0, 6.1, 5.4, 8.0, [time], [feb mar apr], [up: q1 q2])
  dim(12.8, 6.1, 17.2, 8.0, [product], [b1 b2 m1], [up: books media])
  dim(5.2, 0.4, 13.8, 2.3, [store], [paris lyon berlin], [up: fr de])
  cdraw.line((4.2, 6.1), (7.4, 5.2), stroke: luma(60))
  cdraw.line((14.0, 6.1), (11.6, 5.2), stroke: luma(60))
  cdraw.line((8.2, 2.3), (8.2, 3.2), stroke: luma(60))
  cdraw.line((10.8, 2.3), (10.8, 3.2), stroke: luma(60))
})

== the cube lattice, 46 cells of 64

Gray et al's cube operator generalizes group-by to every subset of
dimensions at once: one cuboid per subset, the base cuboid sitting at
(month, product, city), the apex at no dimensions at all, and a lattice
between them where each step up aggregates one dimension away. The
sample counts nonempty cells per cuboid the direct way, marking every
combination of dimension values that some fact row actually hits.

The dry run: the base cuboid holds 12 nonempty cells of the 3 x 3 x 3 =
27 possible, and the density check is exact fraction arithmetic,
"ch11 base cuboid density 4/9" asserted by cross-multiplication, 12 x
9 = 4 x 27. The three 2-D cuboids print as `cuboid cells (month,product)=8
(month,city)=9 (product,city)=7` and the singles as `singles month=3
product=3 city=3 apex=1 full cube 46 of 64`. The 46 is the sum 12 + 8 +
9 + 7 + 3 + 3 + 3 + 1 across the eight cuboids, and the 64 is not a
coincidence: the possible-cell total is $27 + 3 dot 9 + 3 dot 3 + 1 =
(3 + 1)^3$, the binomial theorem counting, per dimension, its 3 values
plus the choice to aggregate it away.

#listing("kdd/samples/src/Ch11/olap.c", first: 112, last: 125,
  caption: [base-cuboid cells, every combination a fact row hits])

#listing("kdd/samples/src/Ch11/olap.c", first: 193, last: 201,
  caption: [the eight cuboids summed, 46 nonempty of 64 possible])

#diagram([the cube lattice, nonempty cells per cuboid, 46 of 64], length: 13pt, {
  let cub(x0, y0, txt, fillv) = {
    cdraw.rect((x0, y0), (x0 + 2.6, y0 + 0.6), fill: fillv, radius: 0.02)
    cdraw.content((x0 + 1.3, y0 + 0.3), txt, size: 6pt)
  }
  cdraw.content((8.7, 8.7), [apex], size: 6pt)
  cub(7.4, 7.7, [1 cell], luma(238))
  cub(2.4, 6.2, [(month) 3], luma(246))
  cub(7.7, 6.2, [(product) 3], luma(246))
  cub(13.0, 6.2, [(city) 3], luma(246))
  cub(3.6, 4.0, [(m,p) 8], luma(246))
  cub(7.6, 4.0, [(m,c) 9], luma(246))
  cub(11.6, 4.0, [(p,c) 7], luma(246))
  cub(7.4, 1.4, [base 12], luma(240))
  cdraw.line((8.4, 7.7), (4.4, 6.8), stroke: luma(160))
  cdraw.line((8.7, 7.7), (9.0, 6.8), stroke: luma(160))
  cdraw.line((9.0, 7.7), (13.6, 6.8), stroke: luma(160))
  cdraw.line((4.1, 6.2), (5.3, 4.6), stroke: luma(160))
  cdraw.line((4.7, 6.2), (8.6, 4.6), stroke: luma(160))
  cdraw.line((9.3, 6.2), (6.0, 4.6), stroke: luma(160))
  cdraw.line((9.0, 6.2), (12.6, 4.6), stroke: luma(160))
  cdraw.line((13.9, 6.2), (10.2, 4.6), stroke: luma(160))
  cdraw.line((14.0, 6.2), (13.2, 4.6), stroke: luma(160))
  cdraw.line((5.1, 4.0), (8.5, 2.0), stroke: luma(160))
  cdraw.line((8.9, 4.0), (8.9, 2.0), stroke: luma(160))
  cdraw.line((12.9, 4.0), (9.3, 2.0), stroke: luma(160))
  cdraw.content((8.7, 0.6), [one cuboid per subset of dimensions, edges drop one dimension], size: 6pt)
})

#callout("pitfall", "the lattice is exponential in dimensions", [
  Three dimensions give eight cuboids, $2^3$, and the sample walks all
  eight. Twenty dimensions give over a million, $2^20 = 1048576$, which
  no engine materializes in full. Gray et al's operator defines the
  whole lattice, but a warehouse computes cuboids on demand or
  materializes only the hot ones, and that engineering choice, picked
  per query pattern, is exactly what #xref-to("kdd", "capstone")
  revisits on duckdb.
])

== roll-up and drill-down

Roll-up aggregates a dimension up its hierarchy, city to country or
month to quarter; drill-down walks the same ladder the other way, q1
back to feb and mar. Both are group-by underneath: the sample's one
base aggregate takes a dimension index or a wildcard per axis, and the
hierarchy variant matches rows at the rolled-up level instead.

The dry run: group-by month prints `sum month=feb 13`, `sum month=mar
11`, `sum month=apr 18`, the three sub-sums 4+2+6+1, 3+1+5+2, 6+3+7+2.
Rolling product up one level prints `sum category=books 24` and `sum
category=media 18`, and month up to quarter prints `sum quarter=q1 24`
and `sum quarter=q2 18`. The mixed roll-up over (month, country) walks
six cells, from `rollup feb/fr count=3 sum=11` to `rollup apr/de
count=1 sum=3`, with counts 3, 1, 3, 1, 3, 1 because berlin is the only
German city. Drill-down reverses direction over the same tables:
`drilldown q1=24 feb=13 mar=11` splits the quarter cell, and `drilldown
fr: paris=28 lyon=4; de: berlin=10` splits both countries.

#listing("kdd/samples/src/Ch11/olap.c", first: 82, last: 96,
  caption: [the hierarchy aggregate, matching rows at quarter, category, country level])

#listing("kdd/samples/src/Ch11/olap.c", first: 257, last: 271,
  caption: [roll-up (month, country), six cells, sums and counts pinned in scan order])

#diagram([the time hierarchy, roll-up aggregates up, drill-down refines down], length: 13pt, {
  cdraw.rect((7.3, 7.5), (10.1, 8.1), fill: luma(240), radius: 0.02)
  cdraw.content((8.7, 7.8), [all 42], size: 6pt)
  cdraw.rect((3.2, 5.9), (6.2, 6.5), fill: luma(246), radius: 0.02)
  cdraw.content((4.7, 6.2), [q1 24], size: 6pt)
  cdraw.rect((11.2, 5.9), (14.2, 6.5), fill: luma(246), radius: 0.02)
  cdraw.content((12.7, 6.2), [q2 18], size: 6pt)
  cdraw.rect((0.8, 4.0), (3.8, 4.6), fill: luma(246), radius: 0.02)
  cdraw.content((2.3, 4.3), [feb 13], size: 6pt)
  cdraw.rect((4.4, 4.0), (7.4, 4.6), fill: luma(246), radius: 0.02)
  cdraw.content((5.9, 4.3), [mar 11], size: 6pt)
  cdraw.rect((11.8, 4.0), (14.8, 4.6), fill: luma(246), radius: 0.02)
  cdraw.content((13.3, 4.3), [apr 18], size: 6pt)
  cdraw.line((8.0, 7.5), (4.7, 6.5), stroke: luma(60))
  cdraw.line((9.4, 7.5), (12.7, 6.5), stroke: luma(60))
  cdraw.line((4.2, 5.9), (2.3, 4.6), stroke: luma(60))
  cdraw.line((5.2, 5.9), (5.9, 4.6), stroke: luma(60))
  cdraw.line((12.7, 5.9), (13.3, 4.6), stroke: luma(60))
  cdraw.line((15.8, 4.3), (15.8, 7.7), stroke: luma(120), mark: (end: ">"))
  cdraw.content((15.8, 8.1), [roll-up], size: 6pt)
  cdraw.line((17.0, 7.7), (17.0, 4.3), stroke: luma(120), mark: (end: ">"))
  cdraw.content((17.0, 3.95), [drill-down], size: 6pt)
  cdraw.content((8.7, 2.9), [the q1 split, 13 + 11, is recomputed from the facts], size: 6pt)
})

#callout("pitfall", "aggregation is not invertible", [
  The cell q1 = 24 does not remember that it was 13 + 11. Drill-down in
  the sample re-reads the 12-row fact table and regroups at month level;
  it does not unpack the quarter cell, because nothing is left to unpack.
  A warehouse that stores only an aggregated cuboid has burned the
  detail below it, which is why production schemas keep the base facts
  and compute roll-ups on the fly or refresh them from below.
])

== slice, dice, and the pivot

Slice fixes one dimension to one value, dice fixes two or more, and the
pivot reshapes what survives into a cross-tab with sub-totals, the
cross-tab and sub-totals that Gray et al fold into the same cube
operator. All three ride the one wildcard aggregate: a slice on
month = feb is the group-by cell (feb) with its count kept alongside
the sum.

The dry run: slice month=feb keeps 4 rows summing 13, slice city=paris
keeps 6 rows summing 28, and both print through the same aggregate the
group-by used. The dice month in {feb, mar} and country=de keeps 2 rows,
the two berlin facts, summing 2 + 5 = 7, printed as `dice feb|mar AND
de: count=2 sum=7`; the dice category=books and city=paris keeps 4 rows
summing 15. The pivot prints the whole month x city matrix, `feb 10 1
2`, `mar 5 1 5`, `apr 13 2 3` over columns paris, lyon, berlin, and the
margins line `margins rows 13 11 18 cols 28 4 10 grand 42` closes the
loop on the chapter's first check: the grand cell and the additive
anchor are the same 42.

#listing("kdd/samples/src/Ch11/olap.c", first: 341, last: 352,
  caption: [dice as a two-predicate scan over the fact table])

#listing("kdd/samples/src/Ch11/olap.c", first: 370, last: 385,
  caption: [the pivot matrix, every cell one wildcard aggregate])

#listing("kdd/samples/src/Ch11/olap.c", first: 389, last: 397,
  caption: [margins, row totals, column totals, and the grand 42])

#diagram([the month x city pivot with margins, the dashed pair is the dice], length: 13pt, {
  let cell(x0, y0, txt, fillv) = {
    cdraw.rect((x0, y0), (x0 + 2.2, y0 + 0.8), fill: fillv, radius: 0.02)
    cdraw.content((x0 + 1.1, y0 + 0.4), txt, size: 6pt)
  }
  cdraw.content((5.3, 6.85), [paris], size: 6pt)
  cdraw.content((7.5, 6.85), [lyon], size: 6pt)
  cdraw.content((9.7, 6.85), [berlin], size: 6pt)
  cdraw.content((11.9, 6.85), [row sum], size: 6pt)
  cdraw.content((3.0, 6.0), [feb], size: 6pt)
  cdraw.content((3.0, 5.0), [mar], size: 6pt)
  cdraw.content((3.0, 4.0), [apr], size: 6pt)
  cdraw.content((3.0, 2.8), [col sum], size: 6pt)
  cell(4.2, 5.6, [10], luma(246))
  cell(6.4, 5.6, [1], luma(246))
  cell(8.6, 5.6, [2], luma(246))
  cell(10.8, 5.6, [13], luma(234))
  cell(4.2, 4.6, [5], luma(246))
  cell(6.4, 4.6, [1], luma(246))
  cell(8.6, 4.6, [5], luma(246))
  cell(10.8, 4.6, [11], luma(234))
  cell(4.2, 3.6, [13], luma(246))
  cell(6.4, 3.6, [2], luma(246))
  cell(8.6, 3.6, [3], luma(246))
  cell(10.8, 3.6, [18], luma(234))
  cell(4.2, 2.4, [28], luma(234))
  cell(6.4, 2.4, [4], luma(234))
  cell(8.6, 2.4, [10], luma(234))
  cell(10.8, 2.4, [42], luma(224))
  cdraw.rect((8.55, 4.55), (10.78, 6.45), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((14.1, 5.5), [dice {feb,mar} x de], size: 6pt)
  cdraw.content((14.1, 5.0), [2 + 5 = 7], size: 6pt)
  cdraw.content((7.5, 1.5), [slice keeps one row whole, feb sums 13], size: 6pt)
})

The pivot is also where this chapter hands off. Everything above is one
aggregate over wildcards, and a warehouse engine is that aggregate with
indexes and columnar storage behind it, the lane
#xref-to("kdd", "capstone") runs in go. The next chapter fits a line
through numbers instead of summing them,
#xref-to("kdd", "regression"), still on fixtures small enough to check
by hand.

sources: Kimball & Ross, The Data Warehouse Toolkit, Wiley 2002, star
schema and the slice, dice, roll-up, drill-down vocabulary. Gray,
Bosworth, Layman, Pirahesh, "Data Cube: A Relational Aggregation
Operator Generalizing Group-By, Cross-Tab and Sub-Totals", ICDE 1996,
cube-lattice cell counting. All 76 pinned values witnessed by
kdd-contract-s3.md and playground/kdd-matrix/gen_s3.py, run 2026-09-22,
exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter
Ch11`, 76 checks in chapter 11 of the kdd suite.
