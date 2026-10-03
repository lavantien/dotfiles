// ch41, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 27 checks in kdd/samples/src/Ch41/rough.c or a banked provenance
// note: the flu decision table is Z. Pawlak's running example, Rough Sets,
// International Journal of Computer and Information Sciences 11(5) 1982,
// 341-356, the same 6-patient table chapters 42 and 43 reuse, with the
// upper approximation and Headache classes matching the printed values of
// the paper itself. all pinned values are witnessed by
// kdd-contract-s8s9.md + playground/kdd-matrix/gen_s9.py, run 2026-09-22,
// exit 0. all D0: exact strings and cross-multiplied fraction pairs, no
// doubles anywhere.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= rough sets: indiscernibility and approximations

One sample carries the chapter: `rough.c` builds every indiscernibility
partition of Pawlak's flu table, brackets the flu set between two
approximations, grades each patient by rough membership, and exhibits one
crisp set as the contrast, 27 checks. The chapter makes 4 moves: the
partition an attribute subset induces, the lower and upper approximations
that bracket a set no union of classes can express, the membership
fraction that grades every object inside the boundary, and the crisp case
where the whole bracket collapses. #xref-to("kdd", "id3") read a decision
table with entropy and #xref-to("kdd", "rules") covered it with rules,
both assuming every row's decision follows from its conditionals. This
chapter is the part of the table those chapters quietly dropped: two
patients with identical symptoms and opposite diagnoses, and what a theory
can still say about them. The attribute-value triage that produced T's
three ordered levels is the ordinal end of #xref-to("kdd", "binning").

== one table, seven partitions

Indiscernibility is the whole foundation: two objects are indiscernible
under an attribute subset B when they agree on every attribute in B, and
ind(B) is the partition of the table into classes of mutually
indiscernible objects. The fixture is Pawlak's, 6 patients, 3
conditionals, headache H and muscle pain M binary, temperature T ordinal
with values normal, high, vhigh, and the decision Flu. Three attributes
give 7 nonempty subsets, each partition hand-checkable against the 6 rows.

The dry run: the sample first reprints all 6 rows, `row p1 H=n M=y
T=high Flu=yes` through `row p6 H=n M=y T=vhigh Flu=yes`, each row a
check. Then the 7 partitions, printed and checked one per subset:
`ind {H}: {{p1,p4,p6},{p2,p3,p5}}`, `ind {M}:
{{p1,p3,p4,p6},{p2,p5}}`, `ind {T}: {{p1,p2,p5},{p3,p6},{p4}}`, and on
through `ind {H,T}: {{p1},{p2,p5},{p3},{p4},{p6}}`, `ind {M,T}:
{{p1},{p2,p5},{p3,p6},{p4}}`, and `ind {H,M,T}:
{{p1},{p2,p5},{p3},{p4},{p6}}`. Two facts jump out. Patients p2 and p5
share the full conditional tuple (y, n, high) yet carry opposite
decisions, so they stay glued in every partition, even the one built from
all three attributes. And the partitions for {H,T} and {H,M,T} are
string-identical, the first hint that M is sometimes spendable, which is
exactly the question #xref-to("kdd", "reducts") asks next.

#listing("kdd/samples/src/Ch41/rough.c", first: 43, last: 67,
  caption: [one pass over the table builds a partition: classes by smallest member, members ascending])

#listing("kdd/samples/src/Ch41/rough.c", first: 167, last: 185,
  caption: [the 7 pinned partitions, one string check per subset])

#diagram([the flu table and the partition its best pair of attributes induces], length: 13pt, {
  let cols = ((1.6, [H]), (3.1, [M]), (5.2, [T]), (7.9, [Flu]))
  cdraw.content((0.8, 8.35), [the decision table], size: 6.5pt)
  cdraw.content((0.9, 7.8), [pat.], size: 6pt)
  for c in cols {
    cdraw.content((c.at(0), 7.8), c.at(1), size: 6pt)
  }
  let rows = ((6.9, [p1], ([n], [y], [high], [yes]), false),
    (5.95, [p2], ([y], [n], [high], [yes]), true),
    (5.0, [p3], ([y], [y], [vhigh], [yes]), false),
    (4.05, [p4], ([n], [y], [normal], [no]), false),
    (3.1, [p5], ([y], [n], [high], [no]), true),
    (2.15, [p6], ([n], [y], [vhigh], [yes]), false))
  for r in rows {
    let y = r.at(0)
    if r.at(3) {
      cdraw.rect((0.8, y - 0.42), (8.9, y + 0.48), fill: luma(228), radius: 0.02)
    }
    cdraw.content((0.9, y), r.at(1), size: 6pt)
    for i in range(4) {
      cdraw.content((cols.at(i).at(0), y), r.at(2).at(i), size: 6pt)
    }
  }
  cdraw.content((4.85, 1.1), [p2 and p5: same symptoms, opposite flu], size: 6pt)
  cdraw.line((9.3, 5.2), (10.6, 5.2), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.5, 5.65), [ind {H,T}], size: 6pt)
  let bl = ((11.4, 7.4, [p1], false), (11.4, 6.1, [p2, p5], true),
    (11.4, 4.5, [p3], false), (11.4, 3.5, [p4], false), (11.4, 2.5, [p6], false))
  cdraw.content((13.4, 8.35), [five classes, the twins stay glued], size: 6pt)
  for b in bl {
    cdraw.rect((11.4, b.at(1) - 0.42), (15.4, b.at(1) + 0.42),
      fill: if b.at(3) {luma(228)} else {luma(244)}, radius: 0.02, stroke: luma(150))
    cdraw.content((13.4, b.at(1)), b.at(2), size: 6pt)
  }
})

#callout("note", "the partition is the data the rough set sees", [
  A rough set analysis never consults the rows directly after the partition
  is built. Every question this chapter and the next two answer, is a set
  a union of classes, how much of the decision do these attributes
  determine, which attributes can be dropped, is answered inside the
  lattice of partitions. The 6-row table and the twin patients enter only
  through ind(B), which is why the same fixture can carry three chapters.
])

== lower, upper, boundary

Take the set of flu patients Xyes = {p1, p2, p3, p6} and ask which union
of ind({H,M,T}) classes equals it. None does, because the class {p2, p5}
straddles the decision. The theory's answer is a bracket. The lower
approximation is the union of classes fully inside X, objects that
certainly have flu given their symptoms. The upper approximation is the
union of classes that touch X at all, objects that possibly have flu. The
boundary is upper minus lower, and the accuracy $|"lower"|\/|"upper"|$
measures how tight the bracket is.

The dry run: for Xyes the sample prints `Xyes lower={p1,p3,p6}
upper={p1,p2,p3,p5,p6} boundary={p2,p5} accuracy=3/5`, asserted as "ch41
Xyes lower/upper/boundary" plus "ch41 Xyes accuracy 3/5" by
cross-multiplication, $3 dot 5 = 5 dot 3$. The upper approximation
{p1,p2,p3,p5,p6} is one of the values printed in Pawlak's 1982 paper
itself, an external cross-check on top of the hand derivation. For the
complement Xno = {p4, p5} the row reads `Xno lower={p4}
upper={p2,p4,p5} boundary={p2,p5} accuracy=1/3`. Both decisions share the
same boundary {p2,p5}, which is the structural statement of the problem:
the twins are ambiguous for flu and for its negation at once, and the
yes-bracket is tighter than the no-bracket, 3/5 against 1/3.

#listing("kdd/samples/src/Ch41/rough.c", first: 119, last: 148,
  caption: [the bracket: all-in classes to the lower, any-in classes to the upper, the rest is boundary])

#listing("kdd/samples/src/Ch41/rough.c", first: 196, last: 222,
  caption: [both decision sets approximated, accuracies as cross-multiplied pairs])

#diagram([the bracket around each decision: shaded boundary ring between lower and upper], length: 13pt, {
  let panel(x0, title, lo, up, bn) = {
    cdraw.content((x0 + 3.1, 8.3), title, size: 6.5pt)
    cdraw.rect((x0, 2.2), (x0 + 6.2, 7.4), fill: luma(226), radius: 0.02,
      stroke: luma(120))
    cdraw.content((x0 + 3.1, 6.95), [upper, possibly], size: 6pt)
    cdraw.rect((x0 + 0.7, 2.9), (x0 + 5.5, 6.4), fill: luma(246), radius: 0.02,
      stroke: luma(120))
    cdraw.content((x0 + 3.1, 6.05), [lower, certainly], size: 6pt)
    cdraw.content((x0 + 0.5, 2.45), [boundary = {p2,p5}], size: 6pt)
    let lus = ((x0 + 1.7, 5.3, [p1]), (x0 + 3.1, 5.3, [p3]), (x0 + 4.5, 5.3, [p6]))
    for p in lus {
      cdraw.circle((p.at(0), p.at(1)), radius: 0.28, fill: luma(210), stroke: luma(90))
      cdraw.content((p.at(0), p.at(1)), p.at(2), size: 6pt)
    }
    cdraw.content((x0 + 3.1, 4.4), lo, size: 6pt)
    cdraw.content((x0 + 3.1, 3.7), up, size: 6pt)
    cdraw.content((x0 + 3.1, 3.0), bn, size: 6pt)
  }
  panel(0.6, [Xyes, accuracy 3\/5], [lower = {p1,p3,p6}],
    [upper = {p1,p2,p3,p5,p6}], [boundary = {p2,p5}])
  panel(9.4, [Xno, accuracy 1\/3], [lower = {p4}],
    [upper = {p2,p4,p5}], [boundary = {p2,p5}])
  cdraw.content((9.0, 1.2), [the same twin ring is both sets' boundary], size: 6pt)
})

== rough membership

The boundary is not featureless mush, it has grades. The rough membership
of object p in X under the full conditionals is $mu_X (p) =
|[p] ∩ X| \/ |[p]|$, the fraction of p's indiscernibility class that lies
in X. Objects in pure classes score 1 or 0, the twins score exactly 1/2,
and the function agrees with the bracket: scoring 1 is being in the lower,
scoring 0 is being outside the upper, anything between is boundary.

The dry run: six rows, `mu_Xyes p1=1`, `mu_Xyes p2=1/2`, `mu_Xyes p3=1`,
`mu_Xyes p4=0`, `mu_Xyes p5=1/2`, `mu_Xyes p6=1`, each asserted as its
own check, "ch41 mu_Xyes p2=1/2" among them, the fraction compared by
cross-multiplication, one hit in a two-member class against the reduced
pair 1 over 2. The class {p1} is pure yes so p1 scores 1, the class {p4}
is pure no so p4 scores 0, and the class {p2,p5} holds one yes and one
no, so both twins score 1/2. The membership function is where the rough
set touches #xref-to("kdd", "bayes"), a posterior per object, but earned
by counting a partition instead of assuming independence.

#listing("kdd/samples/src/Ch41/rough.c", first: 224, last: 247,
  caption: [membership as a class census, fractions checked cross-multiplied])

#diagram([the five classes of the full partition, each member carrying its membership grade], length: 13pt, {
  cdraw.content((8.6, 8.3), [ind {H,M,T} classes and $mu_"Xyes"$ per member], size: 6pt)
  let box(x, y, w, members, grades, hot) = {
    cdraw.rect((x, y), (x + w, y + 1.3), fill: if hot {luma(228)} else {luma(246)},
      radius: 0.02, stroke: luma(150))
    let n = members.len()
    for i in range(n) {
      let cx = x + w * (i + 0.5) / n
      cdraw.content((cx, y + 0.92), members.at(i), size: 6.5pt)
      cdraw.content((cx, y + 0.38), grades.at(i), size: 6.5pt)
    }
  }
  box(1.0, 5.4, 2.6, ([p1],), ([1],), false)
  box(4.0, 5.4, 5.0, ([p2], [p5]), ([1\/2], [1\/2]), true)
  box(9.4, 5.4, 2.6, ([p3],), ([1],), false)
  box(12.4, 5.4, 2.4, ([p4],), ([0],), false)
  box(15.1, 5.4, 2.6, ([p6],), ([1],), false)
  cdraw.line((4.0, 5.2), (4.0, 4.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((6.5, 4.25), [one yes, one no: 1\/2 each], size: 6pt)
  cdraw.content((8.6, 3.3), [mu = 1 means certainly in, mu = 0 means certainly out], size: 6pt)
  cdraw.content((8.6, 2.6), [1\/2 means boundary, the twins], size: 6pt)
  cdraw.content((8.6, 1.6), [p4 is the only certain no], size: 6pt)
})

== the crisp contrast

Not everything in this table is rough. Take Z = {p3, p6}, the two
very-high-fever patients, and bracket it under the same full partition:
the class {p3} is inside, the class {p6} is inside, no other class touches
Z, so lower, upper and Z itself are the same set and the boundary is
empty. Z is crisp, or in the lattice language, exactly definable, and it
is definable by a single descriptor besides: the T = vhigh class of the
one-attribute partition ind({T}) is already {p3, p6}.

The dry run: the sample prints `Z={p3,p6} lower={p3,p6} upper={p3,p6}
boundary={} crisp=true`, three checks, "ch41 Z={p3,p6} crisp
lower=upper", "ch41 Z boundary empty crisp=true", and then `definable
Z=T:vhigh equal=true`, asserted as "ch41 definable Z=T:vhigh equal=true"
by fishing the T = vhigh class out of ind({T}) and string-comparing it to
{p3,p6}. The contrast is the chapter's landing point: Xyes needed a
bracket and a membership grade because the conditionals underdetermine
the decision, Z needs neither because one attribute value pins it. Which
subsets B still determine the decision as well as all three do is not a
matter of inspection anymore, and that degree is the business of
#xref-to("kdd", "reducts").

#listing("kdd/samples/src/Ch41/rough.c", first: 250, last: 275,
  caption: [the crisp set: empty boundary, then definability by the single descriptor T=vhigh])

#diagram([Xyes needs a bracket, Z is exactly one class of ind {T}], length: 13pt, {
  cdraw.content((4.4, 8.3), [Xyes, rough], size: 6.5pt)
  cdraw.rect((0.8, 4.6), (8.0, 7.4), fill: luma(226), radius: 0.02, stroke: luma(120))
  cdraw.rect((1.5, 5.3), (7.3, 6.7), fill: luma(246), radius: 0.02, stroke: luma(120))
  cdraw.content((4.4, 7.0), [upper {p1,p2,p3,p5,p6}], size: 6pt)
  cdraw.content((4.4, 6.15), [lower {p1,p3,p6}], size: 6pt)
  cdraw.content((4.4, 4.95), [boundary {p2,p5}, accuracy 3\/5], size: 6pt)
  cdraw.content((4.4, 4.0), [no union of classes equals it], size: 6pt)
  cdraw.line((8.6, 6.0), (9.6, 6.0), stroke: luma(60), mark: (end: ">"))
  cdraw.content((10.2, 8.3), [Z = {p3,p6}, crisp], size: 6.5pt)
  let tb = ((10.2, 6.3, 5.6, [p1, p2, p5], [T = high], false),
    (10.2, 4.9, 5.6, [p3, p6], [T = vhigh], true),
    (10.2, 3.5, 5.6, [p4], [T = normal], false))
  for b in tb {
    cdraw.rect((b.at(0), b.at(1) - 0.55), (b.at(0) + b.at(2), b.at(1) + 0.55),
      fill: if b.at(5) {luma(214)} else {luma(244)}, radius: 0.02, stroke: luma(150))
    cdraw.content((b.at(0) + 1.9, b.at(1)), b.at(3), size: 6pt)
    cdraw.content((b.at(0) + 4.35, b.at(1)), b.at(4), size: 6pt)
  }
  cdraw.content((13.0, 2.3), [lower = upper = Z, boundary empty], size: 6pt)
  cdraw.content((9.0, 1.5), [one descriptor, T = vhigh, defines Z exactly], size: 6pt)
})

sources: the flu decision table and the approximation framework are Z.
Pawlak, Rough Sets, International Journal of Computer and Information
Sciences 11(5) 1982, 341-356, the running example of the paper, with the
upper approximation {p1,p2,p3,p5,p6} and the Headache classes matching
its printed values, corroborated against the reprint excerpted at
mimuw.edu.pl, accessed 2026-09-22, banked by kdd-contract-s8s9.md. The
membership grading belongs to the same tradition and reappears as
decision-relative support in #xref-to("kdd", "discernibility"). All 27
pinned values witnessed by kdd-contract-s8s9.md and
playground/kdd-matrix/gen_s9.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch41`, 27 checks in chapter 41 of the kdd
suite.
