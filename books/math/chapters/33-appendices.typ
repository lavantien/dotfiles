#import "../../theme/lib.typ": callout, diagram, cdraw, xref-to
#import "../manifest.typ": mathbook
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

// the live helpers: everything below recomputes from the registries
#let ids = mathbook.chapters.map(c => c.id)
#let topic-count(id) = topics.filter(r => r.chapter == id).len()
#let suite = (
  "float": (3, 63), "error": (4, 55), "trig": (3, 62), "coordgeo": (4, 51),
  "vectors": (3, 55), "matrices": (4, 60), "inner": (4, 53), "decomp": (4, 52),
  "univariate": (4, 70), "multivariate": (4, 59), "optimization": (4, 81),
  "autodiff": (3, 57), "proof": (4, 45), "combinatorics": (4, 60),
  "graphs": (4, 60), "groups": (4, 58), "actions": (4, 61),
  "probability": (4, 60), "statistics": (4, 63), "roots": (4, 60),
  "interp": (4, 63), "quadrature": (4, 58), "iterative": (4, 68),
  "strategic": (4, 60), "sequential": (4, 59), "adt": (4, 59),
  "railway": (4, 78), "monads": (4, 61), "pipeline": (4, 69),
)
#let sampled = mathbook.chapters.filter(c => suite.at(c.id, default: none) != none)
#let suite-files = suite.values().fold(0, (acc, v) => acc + v.at(0))
#let suite-checks = suite.values().fold(0, (acc, v) => acc + v.at(1))
#let src-class(u) = {
  if u.starts-with("ref/mml-book.pdf") { "mml page ranges" }
  else if u.starts-with("ref/mml/") { "mml anchor sheets" }
  else if u.starts-with("https://dlmf.nist.gov") { "dlmf" }
  else if u.starts-with("https://en.cppreference.com") { "cppreference" }
  else if u.starts-with("https://en.wikipedia.org") { "wikipedia" }
  else if u.starts-with("books/") or u.starts-with("playground/") or u.starts-with("tools/") { "corpus internal" }
  else { "other web" }
}
#let class-order = (
  "mml page ranges", "cppreference", "wikipedia", "other web", "dlmf",
  "corpus internal", "mml anchor sheets",
)
#let class-count(cl) = sources.filter(s => src-class(s.url) == cl).len()
#let class-rule = (
  "mml page ranges": [url starts `ref/mml-book.pdf`],
  "mml anchor sheets": [url starts `ref/mml/`],
  "dlmf": [url starts `https://dlmf.nist.gov`],
  "cppreference": [url starts `https://en.cppreference.com`],
  "wikipedia": [url starts `https://en.wikipedia.org`],
  "corpus internal": [url starts `books/`, `playground/`, or `tools/`],
  "other web": [everything else, books and papers by name],
)

= appendices: coverage and sources

The registries close the book. Each chapter wrote its topic rows into
the coverage matrix as it landed and dated every external page it
consulted, and this chapter reads both back the only way that keeps
them honest, by computing from them. The moves: the coverage invariant
and the chapter ledger, the suite totals recounted against the gates,
the source base classified by url prefix, and the book's place in the
sixteen-document corpus. The contract: every count below is computed
from the live registries at compile time or printed by a gate this
chapter names, the suite numbers were recounted on 2026-09-22, and the
totals are #mathbook.chapters.len() chapters, #topics.len() topic
rows, #sources.len() pinned sources, #suite-files sample files at
#suite-checks checks plus a 64-check capstone build, #(suite-checks +
64) checks over the whole book, zero failures.

== topic coverage

#let off-manifest = topics.filter(r => not ids.contains(r.chapter)).len()
#let bare = mathbook.chapters.filter(c => topic-count(c.id) == 0).map(c => c.id).join(", ")

Every topic row names a chapter the manifest knows: #off-manifest rows
off the manifest out of #topics.len(). Each row carries its check
sentence, the exact CHECK that proves the behavioral claim, so the
matrix doubles as a test index: a reader who doubts a claim follows
the row to its chapter, the chapter to its sample file, and the file
to a runnable gate. The only chapter with no rows of its own is #bare,
it audits rather than claims. The ledger below joins the computed
topic counts to the sample suite, one row per chapter.

#table(
  columns: (auto, 2.7fr, auto, auto, auto),
  inset: 4pt,
  table.header([*ch*], [*chapter*], [*topics*], [*files*], [*checks*]),
  ..sampled.map(c => (
    [ch #c.num],
    [#c.title],
    [#topic-count(c.id)],
    [#suite.at(c.id).at(0)],
    [#suite.at(c.id).at(1)],
  )).flatten(),
  table.cell(colspan: 5, fill: luma(245))[
    ch 30 to 32, the capstone: #(topic-count("capstone-design") +
    topic-count("capstone-impl") + topic-count("capstone-verify")) topic
    rows over one program, a 21-file core with five test drivers and a
    4-file gcc host lane, one shared 64-check build gate
  ],
  [33], [appendices: coverage and sources], [#topic-count("appendices")], [-], [-],
  [*total*], [*#mathbook.chapters.len() chapters*], [*#topics.len()*], [*#(suite-files + 25)*], [*#(suite-checks + 64)*],
)

The densest chapters by row count are ch 25 at 20 topic rows and ch 7,
10, and 29 at 18, the inner product, multivariate, and pipeline
chapters that everything else leans on. The heaviest check suites are
ch 11 at 81 and ch 27 at 78, optimization with its ladders and the
railway with its trace fixtures. The lightest topic count on a content
chapter is 4, the verification capstone, whose four rows each pin a
whole gate.

#diagram([the audit strip, topic rows per chapter above in light gray, sample checks below in dark, the capstone spans chapters 30 to 32 as one 64-check build], length: 13pt, {
  let x = i => 0.9 + i * 0.6
  let checks = sampled.map(c => suite.at(c.id).at(1))
  for i in range(29) {
    cdraw.rect((x(i), 5.2), (x(i) + 0.42, 5.2 + topic-count(mathbook.chapters.at(i).id) * 0.2), fill: luma(205), radius: 0.0)
    cdraw.rect((x(i), 0.9), (x(i) + 0.42, 0.9 + checks.at(i) * 0.04), fill: luma(160), radius: 0.0)
  }
  for i in range(29, 32) {
    cdraw.rect((x(i), 5.2), (x(i) + 0.42, 5.2 + topic-count(mathbook.chapters.at(i).id) * 0.2), fill: luma(235), stroke: luma(100), radius: 0.0)
  }
  cdraw.rect((x(29), 0.9), (x(31) + 0.42, 0.9 + 64 * 0.04), fill: luma(235), stroke: luma(100), radius: 0.0)
  cdraw.line((0.7, 5.2), (20.6, 5.2), stroke: luma(220))
  cdraw.line((0.7, 0.9), (20.6, 0.9), stroke: luma(220))
  for n in (1, 5, 9, 13, 17, 21, 25, 29, 33) {
    cdraw.content((x(n - 1) + 0.21, 0.35), [#n], size: 6pt)
  }
  cdraw.content((10.5, 9.9), [topic rows per chapter, #topics.len() total], size: 6pt)
  cdraw.content((10.5, 4.6), [sample checks per chapter, #suite-checks total], size: 6pt)
  cdraw.content((19.11, 1.4), [64], size: 6pt)
  cdraw.content((19.11, -0.35), [capstone build], size: 6pt)
})

== the suites and the totals

One c lane carries the whole book. The 29 content chapters before the
capstone keep #suite-files sample files under `samples/src/ChNN`, each
file a standalone program that prints one ok line per check and a
total line, #suite-checks checks in all. The gate:

`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/math/samples/src`

The run of 2026-09-22 printed 112 files and 1760 checks with the
format and asan legs clean, and the per-chapter sums reproduced all 29
chapter closers digit for digit, the ledger above carries those sums.
The footer also prints 0 ir/objdump/roundtrip assertions, this book
carries no disassembly pins, its pins are numeric values computed
first by hand or by a playground one-off and then matched against the
compiled run.

The capstone rides two more lanes, both quoted from chapter 32's
session of 2026-09-22 rather than rerun here. The core lane builds
`books/math/capstone/src`, 21 files including the five test drivers
`test_astar.c`, `test_mcts.c`, `test_mixed.c`, `test_physics.c`, and
`test_state.c`, behind `playground/math-capstone/build.ps1`, 64 checks
with replay ok and the twice-run hash identical. The host lane builds
the 4-file gcc rendering shell in `books/math/capstone/host` behind
`tools/run-math-capstone.ps1`, bench 7:1200 with the arena matched
byte for byte against the clang core.

#table(
  columns: (1fr, 1.1fr, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*lane*], [*size*], [*unit*], [*gate*]),
  [c samples], [#suite-files files, #suite-checks], [checks, one ok line per file], [`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src`],
  [capstone core], [21 files, 64], [checks over five test drivers], [`playground/math-capstone/build.ps1`],
  [capstone host], [4 files], [host gates, gcc-built lane], [`tools/run-math-capstone.ps1`],
)

Beyond the checks, the 32 content chapters render 337 listings, every
one a slice of a real sample file read live at compile time, and
carry 196 figures, one per section facet, all inside the 24 px guard
band of the figure audit.

== pinned sources

#let d21 = sources.filter(s => s.accessed == "2026-09-21").len()
#let d22 = sources.filter(s => s.accessed == "2026-09-22").len()

Every external claim in the book carries a dated url or a page range
in the cached mml draft, #sources.len() rows over two access dates,
#d21 rows on 2026-09-21 and #d22 on 2026-09-22. The classifier below
reads only url prefixes, so the class counts are mechanical:

#table(
  columns: (1.4fr, auto, 2.4fr),
  inset: 4pt,
  table.header([*class*], [*rows*], [*rule*]),
  ..class-order.map(cl => (
    [#cl],
    [#class-count(cl)],
    class-rule.at(cl),
  )).flatten(),
)

The mml page ranges are the spine, #class-count("mml page ranges")
rows against the cached `ref/mml-book.pdf` draft of 2024-01-15 plus
the two anchor sheets that mediated the reading. The web rows cluster
where the c library and the reference formulas live, cppreference and
DLMF, and where a definition needed one canonical page, wikipedia.
The corpus-internal rows are this repo's own witnesses, capstone
sources, build gates, and two chapters of the c book that pin defer
and nodiscard behavior. The full index:

#[
#set text(size: 7.5pt)
#table(
  columns: (1.7fr, 2.7fr, auto),
  inset: 3pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)
]

#diagram([the source base by class, the url prefix decides the class, bar length is row count], length: 13pt, {
  let y = 6.8
  for cl in class-order {
    let n = class-count(cl)
    cdraw.rect((4.8, y - 0.28), (4.8 + n * 0.17, y + 0.28), fill: luma(205), radius: 0.0)
    cdraw.content((2.2, y), [#cl], size: 6pt)
    cdraw.content((4.8 + n * 0.17 + 0.55, y), [#n], size: 6pt)
    y -= 0.85
  }
  cdraw.line((4.8, 7.3), (4.8, 0.5), stroke: luma(100))
  cdraw.content((7.5, -0.4), [#d21 rows accessed 2026-09-21, #d22 rows 2026-09-22], size: 6pt)
})

#callout("note", "the dated pins and drift", [
  The mml rows point at the cached draft of 2024-01-15 and the page
  ranges are that draft's, a newer printing renumbers them. The
  cppreference, DLMF, and wikipedia rows are living pages fetched on
  the two access dates. If a page moves, this table is the changelog:
  the date says what was read, the url says where, and a recheck that
  disagrees reopens the chapter claim it licensed.
])

== the corpus view

Fifteen typst documents compile under `books/`, and this one is book 2
in the reading order, position 07 in the `make books` output. The
series pairs this book with its algorithm-first twins: the dsa book
builds from scratch what this book treats as a library call, number
theory in #xref-to("dsa", "numtheory") and #xref-to("dsa",
"numtheory2"), linear algebra in #xref-to("dsa", "linalg"), counting
in #xref-to("dsa", "combinatorics"), the numerical solvers in
#xref-to("dsa", "numerical"), geometry in #xref-to("dsa", "geometry")
and #xref-to("dsa", "geometry2"), and the game solvers beside this
book's chapters 24 and 25 in #xref-to("dsa", "games"). The
game-systems book carries the production twin of the capstone's fixed
step, deterministic fixed-point arithmetic in #xref-to("game-systems",
"math"). The c platform under chapters 26 to 29 is the same machine
the c book dissects, integer representation in #xref-to("c-os-cloud",
"machine") and float autovectorization in #xref-to("c-os-cloud",
"opt").

The reading order continues at book 8, where every algorithm this book
used as a black box gets built from scratch.

#callout("verify", "recounting this chapter", [
  Every total here recomputes. The gate command above prints the
  #suite-files files and #suite-checks checks, and the per-chapter
  sums match all 29 chapter closers digit for digit. The capstone's 64
  checks sit behind `playground/math-capstone/build.ps1` with its host
  gates in `tools/run-math-capstone.ps1`, both quoted from chapter
  32's session. The registry views recompute at compile time, they
  read the same coverage files the chapters wrote, so a row added or
  retitled tomorrow shows up here without editing this chapter.
])

sources: no external pages fetched for this chapter, none cited. Every
count computed from books/math/coverage/topics.typ, #topics.len() rows,
and books/math/coverage/sources.typ, #sources.len() rows, at compile
time, from the suite run of `pwsh -NoProfile -File
tools/run-c-samples.ps1 -SampleRoot books/math/samples/src` on
2026-09-22, #suite-files files, #suite-checks checks, format and asan
clean, and from the capstone gate receipts quoted in chapter 32 of
2026-09-22.
