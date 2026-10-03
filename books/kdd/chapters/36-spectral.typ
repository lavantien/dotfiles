// ch36, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 42 checks in kdd/samples/src/Ch36/spectral.c (32) and cuts.c (10)
// or a banked provenance note: the pipeline and its caveats follow von
// Luxburg 2007, "A tutorial on spectral clustering", Stat. Comput.
// 17:395-416, normalized cut is Shi & Malik 2000, IEEE PAMI 22:888-905,
// ratio cut is Hagen & Kahng 1992, "New spectral methods for ratio cut
// partitioning", ICCAD 1991/IEEE TCAD 11:1074-1085, and the Fiedler
// vector is Fiedler 1973, Czech. Math. J. 23:298-305. the C6 spectrum
// is the stock integer one, 2-2cos(2 pi k/6), with a full integer
// orthogonal eigenbasis verified by L.v = lam.v in int arithmetic, so
// nothing here is stochastic (no D3). the QtLQ residual literal
// 0.000e+00 requires Neumaier compensated summation mirroring CPython
// 3.12+ sum(): naive left-to-right accumulation lands one ulp
// (2.220e-16) high. all pinned values are witnessed by
// kdd-contract-s7.md + playground/kdd-matrix/gen_s7.py, run 2026-09-22,
// exit 0. determinism: D0 for the spectrum, eigenbasis, sign split,
// assignment strings, and every cut objective as reduced int64
// fractions; D2 print-only for the handshake residuals and the embedded
// centroid doubles, both bounded 1e-12.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= spectral clustering

Two samples carry the chapter: `spectral.c` builds the cycle graph's
Laplacian, verifies an integer eigenbasis exactly, runs the orthonormal
handshake, reads the Fiedler split, and finishes with k-means on the
embedding, 32 checks, and `cuts.c` enumerates ratio cut and normalized
cut over every split of two six-node graphs, 10 checks. The chapter
makes 4 moves: the Laplacian and a spectrum checked in integer
arithmetic, the orthonormal handshake and why its pinned zero needs
compensated summation, the Fiedler vector whose signs and embedded
k-means agree, and the two cut objectives agreeing on a regular graph
and disagreeing on a star. The eigen machinery is the same family
#xref-to("kdd", "pca") drives with its Jacobi solver, the embedded
k-means reuses the tie rules of #xref-to("kdd", "kmeans") verbatim, and
the graph lane continues what #xref-to("kdd", "cure") started.

== the laplacian and its integer spectrum

Spectral clustering swaps coordinates for a graph and reads the graph's
slowest modes. The unnormalized Laplacian is $L = D - W$, the degree
matrix minus the adjacency, and on the 6-cycle every degree is 2, so L
carries 2 on the diagonal and $-1$ on each ring neighbor: the sample
prints `deg=(2,2,2,2,2,2)` and six rows beginning `L1: 2 -1 0 0 0 -1`.
The cycle is the one graph whose whole spectrum is both closed-form and
integer, $lambda_k = 2 - 2 cos(2 pi k\/6)$, giving `spectrum=0,1,1,3,3,4`
with the one zero the connectivity theorem promises.

The fixture's luxury is an integer eigenbasis: six vectors, one per
eigenvalue counting multiplicity, that the sample verifies by exact
integer arithmetic, evaluating $L v$ coordinatewise in long integers and
comparing against $lambda v$. The dry run: `lam=0 v=(1,1,1,1,1,1)
integer_check=true norm2=6`, the constant vector the zero mode always
wants; `lam=1 v=(2,1,-1,-2,-1,1) ... norm2=12` and its partner
`lam=1 v=(0,1,1,0,-1,-1) ... norm2=4`; the `lam=3` pair; and
`lam=4 v=(1,-1,1,-1,1,-1) ... norm2=6`, the alternating vector at the
top of the spectrum. No float ever enters: the check is `lv == lam * v`
on integers, the basis is orthogonal in the same int arithmetic
(`integer_basis_orthogonal=true`), and the norms squared, 6, 12, 4, 12,
4, 6, are the exact denominators the next facet divides by.

#listing("kdd/samples/src/Ch36/spectral.c", first: 102, last: 140,
  caption: [the cycle, its degrees, and L = D - W printed row by row])

#listing("kdd/samples/src/Ch36/spectral.c", first: 142, last: 185,
  caption: [the eigenbasis verified by L.v = lam.v in integer arithmetic])

#diagram([one graph, one matrix, one spectrum: the cycle is closed form all the way down], length: 12pt, {
  let ring = ((4.0, 0.0), (2.0, 3.46), (-2.0, 3.46), (-4.0, 0.0),
    (-2.0, -3.46), (2.0, -3.46))
  for i in range(6) {
    cdraw.line(ring.at(i), ring.at(calc.rem(i + 1, 6)), stroke: luma(100))
  }
  for i in range(6) {
    cdraw.circle(ring.at(i), radius: 0.5, fill: luma(70), stroke: none)
  }
  let lo = ((4.9, -0.4), (2.7, 4.1), (-2.7, 4.1), (-5.9, -0.4),
    (-2.7, -4.4), (2.7, -4.4))
  for i in range(6) {
    cdraw.content(lo.at(i), [#(i + 1)], size: 6.5pt)
  }
  cdraw.content((0.0, -6.0), [C6, every degree 2], size: 6.5pt)
  let rows = ([L1: 2 -1  0  0  0 -1], [L2: -1  2 -1  0  0  0],
    [L3:  0 -1  2 -1  0  0], [L4:  0  0 -1  2 -1  0],
    [L5:  0  0  0 -1  2 -1], [L6: -1  0  0  0 -1  2])
  for i in range(6) {
    cdraw.content((11.5, 4.2 - 1.15 * i), rows.at(i), size: 6.5pt)
  }
  cdraw.content((11.5, -3.4), [spectrum 0, 1, 1, 3, 3, 4], size: 6.5pt)
  cdraw.content((11.5, -4.7), "= 2 - 2 cos(2 pi k / 6)", size: 6.5pt)
  cdraw.content((11.5, -6.0), [one zero iff the graph is connected], size: 6pt)
})

== the handshake and the compensated zero

Dividing each basis vector by its exact integer norm produces an
orthonormal Q, and the handshake asks Q to live up to its name in
doubles: $Q^T Q = I$ and $Q^T L Q$ diagonal with the spectrum on it. The
residuals print `QtQ_err=2.220e-16` and `QtLQ_err=0.000e+00`, both
under the $10^(-12)$ bound, and the second literal is the interesting
one: it is zero only under compensated summation.

The entries being summed are products of numbers like $2\/sqrt(12)$ and
$1\/sqrt(6)$, irrational in doubles, whose exact totals are 0 by the
integer orthogonality of the basis, pure cancellation. A plain
left-to-right accumulation of six rounded products whose exact sum is
zero can strand the final rounding error, and it does: the naive lane
lands at $2.220 times 10^(-16)$, one ulp at unit scale, $2^(-52)$, high
on QtLQ. Neumaier compensation fixes exactly this: each partial sum
also records the low bits the rounding dropped, `(total - t) + x`, and
the final return adds the accumulated correction back, recovering
0.000e+00. The pin is not arbitrary either: the generator sums with
CPython's builtin `sum()`, compensated since 3.12, so the C mirrors that
summation order and compensation to reproduce the pinned bytes. The
lesson generalizes past this fixture: the handshake passes either way,
both residuals are far under the bound, but byte-reproducible
floating point needs the summation algorithm pinned as tightly as the
values.

#listing("kdd/samples/src/Ch36/spectral.c", first: 83, last: 97,
  caption: [Neumaier compensated summation, the pinned summation order])

#listing("kdd/samples/src/Ch36/spectral.c", first: 202, last: 249,
  caption: [the orthonormal handshake in doubles, residuals bounded 1e-12])

#diagram([two lanes summing the same six products: only the compensated lane hits the pinned zero], length: 12pt, {
  cdraw.content((8.8, 9.8), [entries like 2\/sqrt(12) dot 1\/sqrt(6), six rounded products each, exact totals 0 by orthogonality], size: 6pt)
  let lane = (y, tag, res, note, hot) => {
    cdraw.rect((1.0, y), (4.4, y + 1.3), fill: luma(246), radius: 0.05)
    cdraw.content((2.7, y + 0.65), tag, size: 6.5pt)
    let xs = (5.6, 7.3, 9.0, 10.7, 12.4, 14.1)
    for i in range(6) {
      cdraw.content((xs.at(i), y + 0.65), [#$dot$], size: 8pt)
    }
    cdraw.line((15.1, y + 0.65), (15.9, y + 0.65), stroke: luma(60), mark: (end: ">"))
    cdraw.rect((16.2, y), (18.8, y + 1.3),
      fill: if hot { luma(232) } else { luma(240) }, radius: 0.05)
    cdraw.content((17.5, y + 0.65), res, size: 6.5pt)
    cdraw.content((10.0, y - 0.9), note, size: 6pt)
  }
  lane(6.6, [plain sum], [2.220e-16], [left-to-right: the last ulp (2^(-52)) survives the cancellation], true)
  lane(3.6, [Neumaier], [0.000e+00], [c += (total - t) + x recovers the dropped low bits, total + c exact], false)
  cdraw.content((8.8, 1.2), [both lanes far under the 1e-12 bound, only the compensated lane reproduces the pinned bytes], size: 6pt)
})

== the fiedler vector cuts the ring

The Fiedler vector is the eigenvector of the smallest nonzero
eigenvalue, and its signs are the classical 2-way spectral cut. Here it
is dyadic by construction, the $lambda = 1$ eigenvector halved, and the
sample verifies $L f = f$ in exact fractions before printing `fiedler=
(1,1/2,-1/2,-1,-1/2,1/2)`. The signs split the ring into two arcs of 3,
`sign_split={1,2,6}|{3,4,5}`, nodes 1, 2, 6 positive against 3, 4, 5
negative.

The pipeline then embeds each node as its Fiedler value and hands the
one-dimensional points to Lloyd with chapter 31's tie rules verbatim,
first 2 distinct values seed, ties to the lowest index, iters counts
the confirming pass. The dry run: the seeds are 1 and 1/2, pass 1
prints `emb iter1 cents=(1),(-1/5) assign=011111 sse=9/5`, everything
but p1 falling to the second centroid. Pass 2 pulls p2 and p6 home,
`emb iter2 cents=(2/3),(-2/3) assign=001110 sse=1/3`, and pass 3
confirms, `emb final iters=3 assign=001110`, closing with
`emb_matches_sign_split=true`. The centroids are thirds, non-dyadic,
so they are displayed as exact fractions and their doubles compared at
$10^(-12)$, the D2 discipline: the fraction is the value, the double is
a witness. The k-means lands exactly on the sign split, which is the
quiet theorem of the method, relaxation to rounding to consistency.

#listing("kdd/samples/src/Ch36/spectral.c", first: 251, last: 296,
  caption: [the fiedler row, exact fraction verification, the sign split])

#listing("kdd/samples/src/Ch36/spectral.c", first: 316, last: 375,
  caption: [embedded k-means with the ch31 tie rules, three passes to 001110])

#diagram([signs on the ring, values on the line, k-means reproducing the split], length: 12pt, {
  let ring = ((3.0, 0.0), (1.5, 2.6), (-1.5, 2.6), (-3.0, 0.0),
    (-1.5, -2.6), (1.5, -2.6))
  for i in range(6) {
    cdraw.line(ring.at(i), ring.at(calc.rem(i + 1, 6)), stroke: luma(150))
  }
  let vals = ([1], [1\/2], [-1\/2], [-1], [-1\/2], [1\/2])
  let lo = ((4.0, -0.4), (2.1, 3.2), (-2.1, 3.2), (-4.6, -0.4),
    (-2.1, -3.5), (2.1, -3.5))
  for i in range(6) {
    if i == 0 or i == 1 or i == 5 {
      cdraw.circle(ring.at(i), radius: 0.5, fill: luma(50), stroke: none)
    } else {
      cdraw.circle(ring.at(i), radius: 0.5, stroke: luma(50))
    }
    cdraw.content(lo.at(i), [#(i + 1)], size: 6pt)
    cdraw.content((lo.at(i).at(0), lo.at(i).at(1) + 0.75), vals.at(i), size: 6pt)
  }
  cdraw.content((0.0, 4.6), [sign split {1,2,6} | {3,4,5}], size: 6.5pt)
  cdraw.line((2.0, -6.0), (14.0, -6.0), stroke: luma(170))
  let line = ((14.0, -6.0), (12.0, -6.0), (8.0, -6.0), (6.0, -6.0),
    (8.0, -6.0), (12.0, -6.0))
  let lab = ((14.3, -5.0), (11.4, -5.0), (7.6, -7.1), (5.4, -5.0),
    (8.6, -7.1), (12.6, -7.1))
  let tags = ([p1], [p2], [p3], [p4], [p5], [p6])
  for i in range(6) {
    cdraw.circle(line.at(i), radius: 0.35, fill: luma(70), stroke: none)
    cdraw.content(lab.at(i), tags.at(i), size: 6pt)
  }
  cdraw.rect((12.67 - 0.3, -6.3), (12.67 + 0.3, -5.7), fill: luma(30))
  cdraw.rect((7.33 - 0.3, -6.3), (7.33 + 0.3, -5.7), fill: luma(30))
  cdraw.content((12.67, -4.0), [2\/3], size: 6pt)
  cdraw.content((7.33, -4.0), [-2\/3], size: 6pt)
  cdraw.line((11.7, -8.0), (14.4, -8.0), stroke: luma(100))
  cdraw.line((11.7, -8.0), (11.7, -7.7), stroke: luma(100))
  cdraw.line((14.4, -8.0), (14.4, -7.7), stroke: luma(100))
  cdraw.line((5.7, -8.0), (8.6, -8.0), stroke: luma(100))
  cdraw.line((5.7, -8.0), (5.7, -7.7), stroke: luma(100))
  cdraw.line((8.6, -8.0), (8.6, -7.7), stroke: luma(100))
  cdraw.content((10.0, -9.2), [k-means on the embedding, assign 001110, iters=3], size: 6pt)
})

== ratio cut against normalized cut

The cut objectives are what the eigenvectors relax, the discrete cut
swapped for the eigenvector problem whose signs are rounded back to a
partition. Ratio cut charges a
split $A | B$ the cut size normalized by cardinality, $"cut" (1\/|A| +
1\/|B|)$, Hagen and Kahng's balanced partitioning objective; normalized
cut swaps cardinality for volume, $"cut" (1\/"vol"(A) +
1\/"vol"(B))$, Shi and Malik's degree-aware version. On the 2-regular
cycle volume is twice cardinality everywhere, so the two objectives are
proportional on every one of the 31 splits and the sample asserts it,
`regular_graph_proportional=true`, both argmins landing on `cut {1,2,3}
cut=2 ratiocut=4/3 ncut=2/3` with `argmin_ratiocut={1,2,3} 4/3` and
`argmin_ncut={1,2,3} 2/3`. Every arc of 3 ties there, the Fiedler signs
of the previous facet picked {1,2,6}, the enumeration records {1,2,3}
by its string tie-break, both optimal.

The star is where the objectives part. G2 is a star $K_(1,5)$, center
node 1 joined to 2 through 6, plus one rim edge 2-3, with degrees
`deg2=(5,2,2,1,1,1)`. The dry run: isolating the pendant 4 costs one
edge, `cut {4} cut=1 ratiocut=6/5 ncut=12/11`, while cutting the rim
pair costs two, `cut {2,3} cut=2 ratiocut=3/2 ncut=3/4`. Ratio cut
prefers the pendant, `argmin_ratiocut={4} 6/5`, cardinality barely
distinguishing a 1-against-5 split from anything else, and the other
two pendants tie at the same 6/5 with the string tie-break deciding.
Normalized cut prefers the rim pair, `argmin_ncut={2,3} 3/4`, because
volume is degree-weighted: the side {2,3} carries volume 4 against the
pendant's 1, and the complement's volume is inflated by the center's
degree 5, so the degree-aware objective would rather cut two edges into
a light side than one edge off a heavy graph. The row prints
`disagree=true`, and that is the honest summary of the field: the
eigenvector you relax decides what balance means.

#listing("kdd/samples/src/Ch36/cuts.c", first: 213, last: 264,
  caption: [the star plus rim edge, both cut rows, both argmins, disagree])

#diagram([on the star, ratiocut isolates a pendant, ncut cuts the light rim pair], length: 12pt, {
  let p = ((8.0, 6.0), (12.0, 7.6), (11.2, 3.2), (4.6, 2.2), (3.4, 6.6), (6.2, 9.6))
  for j in range(1, 6) {
    cdraw.line(p.at(0), p.at(j), stroke: luma(130))
  }
  cdraw.line(p.at(1), p.at(2), stroke: luma(130))
  for i in range(6) {
    cdraw.circle(p.at(i), radius: 0.45, fill: luma(70), stroke: none)
  }
  cdraw.circle(p.at(3), radius: 1.3, stroke: (paint: rgb("#8B0000"), dash: "dashed"))
  cdraw.rect((10.6, 2.2), (12.9, 8.4), stroke: (paint: rgb("#006400"), dash: "dashed"), radius: 0.4)
  let degs = ([5], [2], [2], [1], [1], [1])
  let lo = ((8.0, 4.7), (12.8, 8.2), (11.9, 2.6), (2.7, 0.8), (2.2, 7.2), (5.4, 10.4))
  for i in range(6) {
    cdraw.content(lo.at(i), [#(i + 1) (#degs.at(i))], size: 6pt)
  }
  cdraw.content((2.2, 10.6), [degrees (5,2,2,1,1,1)], size: 6pt)
  cdraw.rect((-0.5, -4.6), (17.0, -0.6), fill: luma(243), radius: 0.05)
  cdraw.content((8.2, -1.4), [cut {4}: cut=1   ratiocut=6/5   ncut=12/11], size: 6.5pt)
  cdraw.content((8.2, -2.4), [cut {2,3}: cut=2   ratiocut=3/2   ncut=3/4], size: 6.5pt)
  cdraw.content((8.2, -3.5), [argmin_ratiocut={4} 6/5, argmin_ncut={2,3} 3/4], size: 6.5pt)
  cdraw.content((8.2, -4.2), [disagree=true: volume weights the center at degree 5], size: 6pt)
})

sources: the pipeline, the unnormalized Laplacian, and the caveats about
which eigenvectors to use follow von Luxburg 2007, "A tutorial on
spectral clustering", Statistics and Computing 17:395-416; normalized
cut is Shi & Malik 2000, "Normalized cuts and image segmentation",
IEEE TPAMI 22(8):888-905; ratio cut is Hagen & Kahng 1992, "New
spectral methods for ratio cut partitioning and clustering", IEEE
TCAD 11(9):1074-1085; and the Fiedler vector and its sign structure go
back to Fiedler 1973, Czechoslovak Mathematical Journal 23:298-305. The
Neumaier requirement on the QtLQ literal, the exact-fraction embedded
k-means, and every pinned row are witnessed by kdd-contract-s7.md +
playground/kdd-matrix/gen_s7.py, run 2026-09-22, exit 0. Sample
behavior verified by `pwsh -NoProfile -File tools/run-c-samples.ps1
-SampleRoot books/kdd/samples/src -Chapter Ch36`, 32 + 10 checks in
chapter 36 of the kdd suite.
