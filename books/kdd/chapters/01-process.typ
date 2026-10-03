// ch01, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 22 checks in kdd/samples/src/Ch01/pipeline.c or a quote banked from a
// dated source fetched the same day (Fayyad, Piatetsky-Shapiro, Smyth, AI
// Magazine 17-3, via ojs.aaai.org, accessed 2026-09-22). fixture values are
// pinned by kdd-contract-s1s2.md + playground/kdd-matrix/gen_s1.py, run
// 2026-09-22, exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the knowledge discovery process

One sample carries the chapter: `pipeline.c` pushes a six-record fixture
through a four-stage cleaning chain and asserts every stage count, every
dropped id, and the surviving rows, 22 checks in all. The chapter makes 5
moves: what knowledge discovery is as a process rather than an algorithm,
the chain as code, what survives it and in what order, the four task
families the book's 48 chapters mine, and the c23 lane every later chapter
rides. Every behavioral claim below is one of the 22 checks of chapter 01's
sample or a sentence quoted from Fayyad, Piatetsky-Shapiro, and Smyth
fetched 2026-09-22. The chapters that follow each own one stage of the
process in depth, starting with #xref-to("kdd", "cleaning"), and
#xref-to("kdd", "capstone") reassembles the whole chain in go over duckdb.

== the process, not the step

Fayyad, Piatetsky-Shapiro, and Smyth, fetched 2026-09-22: "KDD is the
nontrivial process of identifying valid, novel, potentially useful, and
ultimately understandable patterns in data." The load-bearing word is
process. "The term process implies that KDD comprises many steps, which
involve data preparation, search for patterns, knowledge evaluation, and
refinement, all repeated in multiple iterations." Mining, the step this
book's middle spends its weight on, is one stage inside that loop: "KDD
refers to the overall process of discovering useful knowledge from data,
and data mining refers to a particular step in this process." The article
walks the loop in stages, and its one-sentence compression names them all:
"The KDD process involves using the database along with any required
selection, preprocessing, subsampling, and transformations of it; applying
data-mining methods (algorithms) to enumerate patterns from it; and
evaluating the products of data mining to identify the subset of the
enumerated patterns deemed knowledge."

The dry run: the chapter fixture is 6 records of (id, age, score), age -1
marking a missing cell. The sample runs the preprocessing lane over all 6
and prints the census first: `stage inputs:  6 5 4 3`, then
`stage outputs: 5 4 3 2`. Each stage sees one fewer record than the last
and hands one fewer on, 6 in and 2 out, which is the cleaning story of
#xref-to("kdd", "cleaning") compressed into two printed lines.

#listing("kdd/samples/src/Ch01/pipeline.c", first: 116, last: 139,
  caption: [the four-stage chain, census arrays filled per stage])

#diagram([the kdd loop of Fayyad et al. 1996, mining is stage 4 of 5], length: 13pt, {
  let stage(x0, n, title, sub) = {
    cdraw.rect((x0, 4.2), (x0 + 2.8, 5.9), fill: luma(240), radius: 0.02)
    cdraw.content((x0 + 1.4, 5.45), [#n #title], size: 6.5pt)
    cdraw.content((x0 + 1.4, 4.6), sub, size: 6pt)
  }
  stage(1.0, [1], [selection], [pick a target set])
  stage(4.4, [2], [preprocessing], [clean and repair])
  stage(7.8, [3], [transformation], [bin, scale, reduce])
  stage(11.2, [4], [data mining], [enumerate patterns])
  stage(14.6, [5], [evaluation], [keep the useful ones])
  for x in (3.8, 7.2, 10.6, 14.0) {
    cdraw.line((x, 5.05), (x + 0.6, 5.05), stroke: luma(60), mark: (end: ">"))
  }
  cdraw.line((16.0, 6.1), (2.4, 6.1),
    stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.2, 6.45), [iterate until the patterns count as knowledge], size: 6pt)
})

#callout("pitfall", "the mining step is the small one", [
  The same article, fetched 2026-09-22: "The additional steps in the KDD
  process, such as data preparation, data selection, data cleaning,
  incorporation of appropriate prior knowledge, and proper interpretation
  of the results of mining, are essential to ensure that useful knowledge
  is derived from the data." Ten of this book's 48 chapters, 01 through 10,
  never leave those additional steps, and the sample of this chapter lives
  entirely inside stage 2.
])

== one filter at a time

The chain is four filters in series over an in-place table: dedupe by id
keeping the first occurrence, drop rows whose age cell is missing, range
filter $0 <= "age" <= 120$, and format filter $0 <= "score" <= 10$. Each
stage compacts the survivors with the same two-pointer move, copying
keepers down with `r[m++] = r[i]` and recording every ejected id, so the
census and the drop log fall out of one pass.

The dry run: stage 1 reads 6 rows. The third row (1,34,8) repeats id 1, so
dedupe keeps the first copy, output count 5, and check "ch01 stage 1 drops
1 (duplicate id)" fires. Stage 2 sees those 5 and drops id 2, whose age is
-1, output 4. Stage 3 drops id 4, age 200 fails the range gate, output 3.
Stage 4 drops id 5, score 12 fails the $[0, 10]$ format, output 2. The
printed order reads `dropped ids in order: 1 2 4 5`, and each stage's
single drop is one of the four census checks.

#listing("kdd/samples/src/Ch01/pipeline.c", first: 31, last: 49,
  caption: [stage 1, dedupe by id, keep first, order preserved])

#diagram([six records through four filters, one drop per stage], length: 13pt, {
  let filt(y, title, io, drop) = {
    cdraw.rect((6.0, y), (13.0, y + 0.95), fill: luma(240), radius: 0.02)
    cdraw.content((9.5, y + 0.45), title, size: 6pt)
    cdraw.content((4.9, y + 0.45), io, size: 6pt)
    cdraw.line((13.0, y + 0.45), (14.2, y + 0.45),
      stroke: luma(60), mark: (end: ">"))
    cdraw.rect((14.2, y + 0.02), (17.6, y + 0.88), fill: luma(232), radius: 0.02)
    cdraw.content((15.9, y + 0.45), drop, size: 6pt)
  }
  cdraw.content((9.5, 8.1), [6 records in], size: 6pt)
  cdraw.line((9.5, 7.9), (9.5, 7.55), stroke: luma(60), mark: (end: ">"))
  filt(6.6, [stage 1 dedupe by id, keep first], [6 in, 5 out], [id 1, duplicate])
  filt(5.2, [stage 2 drop missing age, -1], [5 in, 4 out], [id 2, hole])
  filt(3.8, [stage 3 range 0 <= age <= 120], [4 in, 3 out], [id 4, age 200])
  filt(2.4, [stage 4 format 0 <= score <= 10], [3 in, 2 out], [id 5, score 12])
  cdraw.line((9.5, 2.4), (9.5, 1.75), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.5, 1.4), [2 records out], size: 6pt)
})

== what survives, and the order it keeps

A filter chain is only trustworthy when both facts survive it: which rows
live, and what order they landed in. The sample checks membership per id
and the order of the final table separately, because compaction could
easily keep the right ids in the wrong sequence.

The dry run: the last data line prints `final survivors: (1,34,8)
(6,29,7)`. Id 1 passed all four gates on its first occurrence, id 6 passed
on age 29 and score 7, and ids 2, 4, 5 each failed exactly one gate. The
membership checks fire as "ch01 id 1 survives", "ch01 id 2 dropped",
"ch01 id 4 dropped", "ch01 id 5 dropped", "ch01 id 6 survives", and the
order check, "ch01 relative order preserved", pins that id 1 still precedes
id 6, the input order carried through every compaction.

#listing("kdd/samples/src/Ch01/pipeline.c", first: 173, last: 186,
  caption: [the survivor rows and the per-id membership checks])

#diagram([the six input rows, four struck out, two survivors], length: 13pt, {
  let row(y, txt, tag, dead) = {
    cdraw.rect((1.0, y), (7.4, y + 0.62), fill: if dead {luma(234)} else {luma(246)}, radius: 0.02)
    cdraw.content((4.2, y + 0.31), txt, size: 6pt)
    cdraw.content((7.9, y + 0.31), tag, size: 6pt)
    if dead {
      cdraw.line((1.2, y + 0.08), (7.2, y + 0.54), stroke: luma(160))
    }
  }
  row(7.0, [(1,34,8) id 1], [keep], false)
  row(6.14, [(2,-1,4) id 2], [stage 2, hole], true)
  row(5.28, [(1,34,8) id 1 again], [stage 1, duplicate], true)
  row(4.42, [(4,200,5) id 4], [stage 3, range], true)
  row(3.56, [(5,45,12) id 5], [stage 4, format], true)
  row(2.7, [(6,29,7) id 6], [keep], false)
  cdraw.line((9.6, 4.9), (13.3, 4.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((11.45, 5.2), [the chain], size: 6pt)
  cdraw.rect((13.5, 4.55), (17.9, 5.25), fill: luma(246), radius: 0.02)
  cdraw.content((15.7, 4.9), [(1,34,8)], size: 6pt)
  cdraw.rect((13.5, 3.45), (17.9, 4.15), fill: luma(246), radius: 0.02)
  cdraw.content((15.7, 3.8), [(6,29,7)], size: 6pt)
  cdraw.content((15.7, 2.9), [order 1 then 6], size: 6pt)
})

#callout("note", "keep-first is a policy, not a law", [
  Duplicate ids could resolve by newest, by most complete row, or by merge.
  The fixture pins keep-first because it is the cheapest deterministic
  rule, order preserving and one pass. Whatever rule a real pipeline
  picks, it belongs in the drop census: an id that silently survives twice
  poisons every count downstream, which is exactly what check "ch01
  dropped ids in order 1,2,4,5" guards against.
])

== four questions, ten arcs

Once the data is clean, the mining step answers one of four questions.
Classify: which label does this row take, the arc from
#xref-to("kdd", "id3") through #xref-to("kdd", "ensembles"). Associate:
which items co-occur, #xref-to("kdd", "apriori") through
#xref-to("kdd", "sequential"). Cluster: which rows group without labels,
#xref-to("kdd", "kmeans") through #xref-to("kdd", "spectral"). Flag: which
rows are anomalous, #xref-to("kdd", "anomaly") and #xref-to("kdd", "lof").
Three quieter arcs sit between them, the statistics pair
#xref-to("kdd", "hypothesis") and #xref-to("kdd", "fdr"), the rough set
triple, and the self-organizing map trilogy that closes the c23 lane.

The dry run: the fixture already separates the four questions' raw
material. Id 4 with age 200 is a range violation, dead at stage 3 of this
chapter, but the same row read against a fitted distribution is the
business of #xref-to("kdd", "anomaly"), and a row that merely sits far
from every cluster is the business of #xref-to("kdd", "lof"). The census
line `dropped ids in order: 1 2 4 5` says the filter caught it here, 47
chapters before a model ever sees it.

#diagram([the 48 chapters in ten arcs, four of them the task families], length: 13pt, {
  let bar(y, w, label, tag, dark) = {
    cdraw.rect((5.2, y), (5.2 + w, y + 0.56),
      fill: if dark {luma(224)} else {luma(242)}, radius: 0.02)
    cdraw.content((0.9, y + 0.28), label, size: 6pt)
    cdraw.content((9.5, y + 0.28), tag, size: 6pt)
  }
  cdraw.content((9.5, 8.3), [tasks the mining step answers], size: 6pt)
  bar(7.72, 2.60, [preprocessing 01-10], [clean, scale, cut], false)
  bar(6.94, 3.64, [models 11-24], [classify], true)
  bar(6.16, 1.56, [patterns 25-30], [associate], true)
  bar(5.38, 1.56, [clusters 31-36], [cluster], true)
  bar(4.60, 0.52, [anomalies 37-38], [flag], true)
  bar(3.82, 0.52, [statistics 39-40], [judge], false)
  bar(3.04, 0.78, [rough sets 41-43], [reduce], false)
  bar(2.26, 0.78, [som 44-46], [map], false)
  bar(1.48, 0.52, [bridge 47], [go port], false)
  bar(0.70, 0.52, [capstone 48], [duckdb], false)
})

== the c lane and its gate

Every theory chapter, 01 through 46, pins its claims the same way: one
standalone c23 program per algorithm family, a CHECK macro that prints one
ok line per assertion and stops the run on the first failure, fixtures
witnessed by a generator script, and a gate that compiles, runs, and
formats the file before it can be committed. No clocks, no ambient
randomness, no filesystem, so a check that passes once passes every time,
the property that lets this book quote sample output as evidence.

The dry run: the gate over this chapter prints `Ch01/pipeline 22 checks`
from the compile-and-run leg, then the summary
`verify-c: 1 files, 22 checks, 0 ir/objdump/roundtrip assertions, format
clean, asan clean`. One file, 22 ok lines, and a format pass that must
leave the file untouched, because later chapters pin line ranges into
these sources and a reformat would strand every pin.

#listing("kdd/samples/src/Ch01/pipeline.c", first: 11, last: 21,
  caption: [the check harness, one ok line per surviving assertion])

#diagram([the gate every sample passes before its chapter compiles], length: 13pt, {
  let lane(x0, title, sub) = {
    cdraw.rect((x0, 4.2), (x0 + 3.7, 5.9), fill: luma(240), radius: 0.02)
    cdraw.content((x0 + 1.85, 5.4), title, size: 6.5pt)
    cdraw.content((x0 + 1.85, 4.6), sub, size: 6pt)
  }
  lane(1.0, [compile], [clang 23, -std=c23, -Werror])
  lane(5.5, [run], [22 ok lines, stop on FAIL])
  lane(10.0, [format], [clang-format, byte clean])
  lane(14.5, [commit], [chapter + sample, pathspec])
  for x in (4.7, 9.2, 13.7) {
    cdraw.line((x, 5.05), (x + 0.8, 5.05), stroke: luma(60), mark: (end: ">"))
  }
  cdraw.content((9.6, 6.5), [deterministic fixture, no clock, no rand, no filesystem], size: 6pt)
})

#callout("note", "the determinism classes, D0 through D3", [
  Every pinned value in this book belongs to one of four classes. D0:
  exact integers and strings, compared with ==. D1: doubles written as
  an integer over a power of two, exact in binary floating point and
  asserted with ==. D2: prints pinned at a stated tolerance, the class
  every rounded or irrational double lands in. D3: a double-run identity
  pin, the sample runs its whole procedure a second time and asserts the
  two runs match value for value. The tags ride chapter headers and
  check names, so the check itself says how hard the pin is.
])

sources: Usama Fayyad, Gregory Piatetsky-Shapiro, Padhraic Smyth, "From
Data Mining to Knowledge Discovery in Databases", AI Magazine 17-3,
ojs.aaai.org/index.php/aimagazine/article/view/1230, fetched 2026-09-22.
Fixture and all 22 pinned values witnessed by kdd-contract-s1s2.md and
playground/kdd-matrix/gen_s1.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch01`, 22 checks in chapter 01 of the kdd
suite.
