// ch42, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 23 checks in kdd/samples/src/Ch42/reduct.c or a banked provenance
// note: the dependency degrees, both reducts and the core reproduce the
// published values for Z. Pawlak's flu table (IJCIS 11(5) 1982 341-356),
// the same 6-patient table chapter 41 partitioned and chapter 43 turns
// into rules. all pinned values are witnessed by kdd-contract-s8s9.md +
// playground/kdd-matrix/gen_s9.py, run 2026-09-22, exit 0. all D0: exact
// cross-multiplied fraction pairs and exact member strings.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= rough sets: dependency and reducts

One sample carries the chapter: `reduct.c` scores all 7 nonempty
attribute subsets of the flu table by dependency degree, enumerates the
reducts, intersects them into the core, plants the required non-reduct
row for the full set, and walks three monotonicity edges, 23 checks. The
chapter makes 4 moves: the positive region and the degree k that prices
an attribute subset, the reducts that achieve full dependency at minimum
cost, the core that no reduct can do without, and the monotone lattice
that makes the whole search sane. #xref-to("kdd", "rough") built the
partitions, this chapter ranks them, and #xref-to("kdd", "discernibility")
will derive the same reducts a second way, as Boolean prime implicants.
The question is the one #xref-to("kdd", "features") asked with chi-square
over candidate splits, here answered exactly: which columns can the table
spare without deciding any patient differently.

== the positive region and the degree

A subset B of conditionals determines an object's decision exactly when
B's partition glues it only to same-decision patients. The union of all
such objects is the positive region POS_B(Flu), and the dependency degree
is $k(B) = |"POS"_B|\/6$, the fraction of the table B decides for sure.
The twins of chapter 41 cap the degree at 4/6 no matter what, because p2
and p5 agree on all three conditionals, so their class is mixed under
every subset, even the full one.

The dry run: seven rows, `k {H}=0 POS={}`, `k {M}=0 POS={}`, `k {T}=1/2
POS={p3,p4,p6}`, `k {H,M}=1/6 POS={p3}`, `k {H,T}=2/3 POS={p1,p3,p4,p6}`,
`k {M,T}=2/3 POS={p1,p3,p4,p6}`, `k {H,M,T}=2/3 POS={p1,p3,p4,p6}`, each
degree and each member string its own check. Reading them off the
partitions is one step each: under {T} the classes {p3,p6} and {p4} are
decision-constant while {p1,p2,p5} mixes, so POS is 3 of 6 and k = 1/2.
Under {H,M} only the singleton {p3} is constant, k = 1/6. Under {H,T}
five classes form and only {p2,p5} mixes, so the positive region is the
other four patients and k = 4/6 = 2/3, the ceiling, since no subset can
ever classify the twins. Headache and muscle pain alone decide nothing,
k = 0 twice over: neither attribute's partition separates a single
certain patient.

#listing("kdd/samples/src/Ch42/reduct.c", first: 38, last: 71,
  caption: [the positive region: classes whose Flu decision is constant, members ascending])

#listing("kdd/samples/src/Ch42/reduct.c", first: 101, last: 125,
  caption: [all 7 degrees and positive regions, fractions cross-multiplied])

#diagram([all 7 nonempty subsets by size, degree k under each, reducts boxed], length: 13pt, {
  let node(x, y, label, kv, hot) = {
    cdraw.rect((x - 1.15, y - 0.42), (x + 1.15, y + 0.42), fill: if hot {luma(230)} else {luma(246)},
      radius: 0.02, stroke: if hot {luma(60)} else {luma(150)})
    cdraw.content((x, y + 0.12), label, size: 6.5pt)
    cdraw.content((x, y - 0.25), kv, size: 6pt)
  }
  cdraw.content((3.0, 8.4), [1 attribute], size: 6pt)
  cdraw.content((9.0, 8.4), [2 attributes], size: 6pt)
  cdraw.content((15.0, 8.4), [3 attributes], size: 6pt)
  node(3.0, 6.9, [{H}], [k = 0], false)
  node(3.0, 5.2, [{M}], [k = 0], false)
  node(3.0, 3.5, [{T}], [k = 1\/2], false)
  node(9.0, 6.9, [{H,M}], [k = 1\/6], false)
  node(9.0, 5.2, [{H,T}], [k = 2\/3], true)
  node(9.0, 3.5, [{M,T}], [k = 2\/3], true)
  node(15.0, 5.2, [{H,M,T}], [k = 2\/3], false)
  cdraw.content((15.0, 3.9), [not a reduct:], size: 6pt)
  cdraw.content((15.0, 3.35), [contains {H,T}], size: 6pt)
  cdraw.content((9.0, 2.3), [the ceiling is 2\/3, the twins stay mixed everywhere], size: 6pt)
  cdraw.content((9.0, 1.6), [temperature alone reaches 1\/2, both pairs with T reach the ceiling], size: 6pt)
})

== reducts, the minimal full-dependency subsets

A reduct is a subset whose dependency equals the full set's and which
contains no smaller such subset. The sample enumerates all 7 subsets by
size then attribute order, keeps those with k = 2/3, and discards any
that contain an earlier keep. Two survive and none else can, because
{T} scores 1/2 and every pair without T scores at most 1/6.

The dry run: the sample prints `reducts={H,T};{M,T}`, asserted twice,
once as the ordered pair of masks, "ch42 reducts are exactly {H,T} and
{M,T} in order", once as the string, "ch42 reducts={H,T};{M,T}". Both
reducts reproduce the published reduct set of Pawlak's table, the
literature cross-check on top of the enumeration. The two reducts say
something asymmetric about the table: headache pairs with temperature,
or muscle pain pairs with temperature, but temperature is the one
attribute both need, and either binary symptom can substitute for the
other. The 7-subset enumeration is the entire search space here, small
enough to exhaust, and the cap is what keeps it honest, the exponential
subset lattice beyond 8 attributes is exactly why the discernibility
route of #xref-to("kdd", "discernibility") exists.

#listing("kdd/samples/src/Ch42/reduct.c", first: 127, last: 158,
  caption: [exhaustive enumeration, size first, supersets of found reducts dropped])

#diagram([both reducts leave the same four patients certain and the twins ambiguous], length: 13pt, {
  let cols = ((1.6, [H]), (3.1, [M]), (5.2, [T]), (7.9, [Flu]))
  cdraw.content((4.9, 8.35), [the table, POS rows shaded], size: 6.5pt)
  cdraw.content((0.9, 7.8), [pat.], size: 6pt)
  for c in cols {
    cdraw.content((c.at(0), 7.8), c.at(1), size: 6pt)
  }
  let rows = ((6.9, [p1], ([n], [y], [high], [yes]), true),
    (5.95, [p2], ([y], [n], [high], [yes]), false),
    (5.0, [p3], ([y], [y], [vhigh], [yes]), true),
    (4.05, [p4], ([n], [y], [normal], [no]), true),
    (3.1, [p5], ([y], [n], [high], [no]), false),
    (2.15, [p6], ([n], [y], [vhigh], [yes]), true))
  for r in rows {
    let y = r.at(0)
    if r.at(3) {
      cdraw.rect((0.8, y - 0.42), (8.9, y + 0.48), fill: luma(232), radius: 0.02)
    }
    cdraw.content((0.9, y), r.at(1), size: 6pt)
    for i in range(4) {
      cdraw.content((cols.at(i).at(0), y), r.at(2).at(i), size: 6pt)
    }
  }
  cdraw.content((4.85, 1.35), [POS = {p1,p3,p4,p6}, 4 of 6, k = 2\/3], size: 6pt)
  cdraw.content((13.2, 8.35), [the two reducts], size: 6.5pt)
  let rb = ((10.2, 6.4, [{H,T}: classes], [{p1} {p2,p5} {p3} {p4} {p6}]),
    (10.2, 4.7, [{M,T}: classes], [{p1} {p2,p5} {p3,p6} {p4}]),
    (10.2, 3.0, [both], [mixed class {p2,p5} only]))
  for b in rb {
    cdraw.rect((9.9, b.at(1) - 0.65), (16.9, b.at(1) + 0.65), fill: luma(246),
      radius: 0.02, stroke: luma(150))
    cdraw.content((13.4, b.at(1) + 0.25), b.at(2), size: 6.5pt)
    cdraw.content((13.4, b.at(1) - 0.28), b.at(3), size: 6pt)
  }
  cdraw.content((13.2, 1.75), [same POS, same degree, either is enough], size: 6pt)
})

#callout("note", "a reduct is feature selection with a proof", [
  Dropping M from {H,M,T} changes nothing the analysis can see: the
  partition, the positive region and the degree are all identical, so the
  smaller set is certified equivalent, not merely correlated. The
  chi-square screen of #xref-to("kdd", "features") ranks columns by
  evidence, a reduct asserts exact equality of what the columns determine,
  which is why the search is exponential and the book keeps the fixture at
  3 attributes, 7 subsets, every one of them checked.
])

== the core and the full set that is not a reduct

The core is the intersection of all reducts, the attributes no reduct can
spare. With reducts {H,T} and {M,T} the intersection is {T} alone, so
temperature is indispensable: no subset achieving k = 2/3 exists without
it, consistent with {T} being the only singleton reaching 1/2. The full
set {H,M,T} then supplies the required counterexample row. Its degree is
2/3, equal to the reducts, its positive region is {p1,p3,p4,p6}, member
for member equal, yet it is not a reduct, because minimality fails, it
strictly contains {H,T}.

The dry run: `core={T}`, asserted as "ch42 core={T} (intersection of
reducts)", then `full_set_nonreduct k=2/3 equal_dep=true POS_equal=true`
with the three checks "ch42 full set dependency equal 2/3", "ch42 full
set POS equal to {H,T} POS", and "ch42 {H,M,T} contains reduct {H,T},
not a reduct". Equal numbers do not make a reduct, the containment clause
does. This is the row that stops anyone reading reducts off a k table by
threshold alone: scanning for k = 2/3 catches {H,M,T} first if the scan
runs in mask order, and the enumeration in the sample only avoids it by
checking subsets against the already-found reducts.

#listing("kdd/samples/src/Ch42/reduct.c", first: 160, last: 184,
  caption: [core by intersection, then the non-reduct row: equal k, equal POS, still not minimal])

#diagram([the core is what both reducts share, the full set contains both and is too big], length: 13pt, {
  cdraw.rect((0.8, 1.6), (17.2, 8.0), fill: luma(242), radius: 0.02, stroke: luma(120))
  cdraw.content((9.0, 7.55), [full set {H,M,T}, k = 2\/3, not a reduct], size: 6.5pt)
  cdraw.circle((6.7, 4.7), radius: 2.5, fill: luma(230), stroke: luma(120))
  cdraw.circle((11.3, 4.7), radius: 2.5, fill: luma(230), stroke: luma(120))
  cdraw.content((5.3, 6.55), [reduct {H,T}], size: 6.5pt)
  cdraw.content((11.9, 6.55), [reduct {M,T}], size: 6.5pt)
  cdraw.content((5.3, 4.7), [H], size: 8pt)
  cdraw.content((12.7, 4.7), [M], size: 8pt)
  cdraw.circle((9.0, 4.7), radius: 1.0, fill: luma(214), stroke: luma(90))
  cdraw.content((9.0, 4.7), [T], size: 8pt)
  cdraw.content((9.0, 2.9), [core {T}], size: 6.5pt)
  cdraw.content((9.0, 2.15), [in both reducts, in no smaller full-degree set], size: 6pt)
  cdraw.content((9.0, 1.05), [M sits outside one reduct, H outside the other, T inside both], size: 6pt)
})

== monotone along the lattice

Adding an attribute can only refine a partition, and refining can only
grow the positive region, so k must be nondecreasing along every lattice
edge. The sample walks three edges and compares the endpoint degrees as
exact fractions by cross-multiplication, no floating point anywhere near
the claim.

The dry run: `monotone H<=HM=true` compares 0 against 1/6, `monotone
T<=HT=true` compares 1/2 against 2/3, which is $1 dot 3 = 3 <= 4 = 2
dot 2$, and `monotone HM<=HMT=true` compares 1/6 against 2/3, $1 dot 3
= 3 <= 12 = 6 dot 2$. Three checks, each an edge of the cube in the
first figure. Monotonicity is what licenses the search pattern the
enumeration used, subsets ordered by size, because a set that already
misses the ceiling cannot be rescued by supersets that contain a reduct.
The other direction is the useful one for pruning: any subset B with
$k(B)$ below the full degree can still sit inside a reduct path, {T}
with k = 1/2 does, so monotonicity bounds the search, it does not
collapse it.

#listing("kdd/samples/src/Ch42/reduct.c", first: 186, last: 198,
  caption: [three lattice edges, endpoint degrees compared by cross-multiplication])

#diagram([k is nondecreasing up every edge, three witnessed climbs], length: 13pt, {
  let base(y, tag, k0) = {
    cdraw.rect((1.2, y - 0.42), (5.2, y + 0.42), fill: luma(246), radius: 0.02,
      stroke: luma(150))
    cdraw.content((3.2, y), tag, size: 6.5pt)
    cdraw.content((6.6, y), k0, size: 6.5pt)
  }
  let top(y, tag, k1) = {
    cdraw.rect((11.8, y - 0.42), (15.8, y + 0.42), fill: luma(232), radius: 0.02,
      stroke: luma(150))
    cdraw.content((13.8, y), tag, size: 6.5pt)
    cdraw.content((10.6, y), k1, size: 6.5pt)
  }
  cdraw.content((8.5, 8.4), [add attributes, k never drops], size: 6pt)
  base(7.0, [{H}], [0])
  top(7.0, [{H,M}], [1\/6])
  base(4.6, [{T}], [1\/2])
  top(4.6, [{H,T}], [2\/3])
  base(2.2, [{H,M}], [1\/6])
  top(2.2, [{H,M,T}], [2\/3])
  cdraw.line((5.4, 7.0), (11.6, 7.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.4, 4.6), (11.6, 4.6), stroke: luma(60), mark: (end: ">"))
  cdraw.line((5.4, 2.2), (11.6, 2.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((8.5, 7.45), [add M], size: 6pt)
  cdraw.content((8.5, 5.05), [add H], size: 6pt)
  cdraw.content((8.5, 2.65), [add T], size: 6pt)
  cdraw.content((8.5, 1.2), [cross-multiplied: 1\/2 <= 2\/3 is 3 <= 4], size: 6pt)
})

sources: the dependency degree, reduct and core definitions follow Z.
Pawlak, Rough Sets, International Journal of Computer and Information
Sciences 11(5) 1982, 341-356, and the two reducts {Headache,Temperature}
and {Muscle-pain,Temperature} with the nonempty core {Temperature}
reproduce the published values for this table, corroborated against the
reprint excerpted at mimuw.edu.pl, accessed 2026-09-22, banked by
kdd-contract-s8s9.md. All 23 pinned values witnessed by
kdd-contract-s8s9.md and playground/kdd-matrix/gen_s9.py, run 2026-09-22,
exit 0. Sample behavior verified by `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/kdd/samples/src -Chapter Ch42`,
23 checks in chapter 42 of the kdd suite.
