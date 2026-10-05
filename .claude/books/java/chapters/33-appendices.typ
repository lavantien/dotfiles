#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": javabook
#import "../coverage/keywords.typ": matrix, reserved, literals, contextual, taught-in
#import "../coverage/stdlib.typ": stdlib-coverage
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

#let chapter-label(id) = {
  if id == "unmapped" { return [unmapped] }
  let found = javabook.chapters.find(c => c.id == id)
  [ch #found.num]
}

The coverage matrices are the book's audit trail. Every reserved,
contextual, and literal token enumerated from the se 27 spec, every
stdlib component family the book touches mapped to the chapter that
teaches it, and the official sources pinned with their access dates.
The build enforces honesty from the other side: every chapter listing
reads a real file the lanes compile and test, 158 junit tests in the
api module plus 5 behind the docker gate, 131 in the capstone beside
21 node tests on the frontend, and 493 sample checks across 58
runnable classes, zero skipped anywhere.

== keyword coverage

#let unmapped = matrix.filter(r => r.chapter == "unmapped").len()

Chapter 3 owns the census and this table is its accounting: 51
reserved character sequences, the list frozen since 9 when the
underscore joined, `enum` the last arrival at 5, `const` and `goto`
reserved and unused since 1.0, `strictfp` an obsolete word 17 turned
into a no-op. Beside them sit the 3 literal tokens, `true`, `false`,
and `null`, reserved like keywords but classified as literals, and
the 17 contextual keywords the spec's recognition rule keeps
shadowable. Unmapped count: #unmapped, the 2 recorded drops, `assert`
and `transient`, the assertion budget riding the ok contract and
junit instead of the statement, the io chapter walking the modern
path instead of object serialization.

#table(
  columns: (auto, 1fr, auto, auto),
  inset: 4pt,
  table.header([*word*], [*kind*], [*since*], [*taught in*]),
  ..matrix.map(r => ([#r.word], [#r.kind], if r.since == none { [] } else { [#r.since] }, chapter-label(r.chapter))).flatten(),
)

#diagram([contextual arrivals by release, the escape valve that kept the frozen list frozen], length: 13pt, {
  cdraw.line((1.0, 3.0), (21.0, 3.0), stroke: luma(100), mark: (end: ">"))
  let tick(x, label, n) = {
    cdraw.line((x, 3.2), (x, 3.6), stroke: luma(100))
    cdraw.content((x, 4.1), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#n words], size: 6pt)
  }
  tick(2.6, [9], [10, modules])
  tick(6.2, [10], [1, var])
  tick(9.0, [14], [1, yield])
  tick(11.4, [16], [1, record])
  tick(14.2, [17], [3, sealed trio])
  tick(17.0, [21], [1, when])
  cdraw.content((11.0, 5.6), [every arrival after 9 rides context, never reservation], size: 6.5pt)
  cdraw.content((11.0, 0.9), [yield previewed 13, record previewed 14, the trio previewed 15, when previewed 17], size: 6pt)
})

#diagram([the census by teaching chapter, counted from the table above], length: 13pt, {
  let rows = javabook.chapters.map(c => (
    num: c.num,
    n: matrix.filter(r => r.chapter == c.id).len(),
  )).filter(x => x.n > 0).sorted(key: x => -x.n)
  let scale = 0.62
  for (i, x) in rows.enumerate() {
    let y = 6.8 - i * 1.05
    cdraw.content((1.5, y), [ch #x.num], size: 6pt)
    cdraw.rect((3.2, y - 0.32), (3.2 + x.n * scale, y + 0.32), fill: luma(205), radius: 0.02)
    cdraw.content((3.2 + x.n * scale + 0.9, y), [#x.n words], size: 6pt)
  }
  cdraw.content((14.5, 6.6), [#reserved.len() reserved, frozen since 9], size: 6.5pt)
  cdraw.content((14.5, 5.5), [#contextual.len() contextual, all 17 dated], size: 6.5pt)
  cdraw.content((14.5, 4.4), [#literals.len() literal neighbors], size: 6.5pt)
  cdraw.content((14.5, 3.3), [#unmapped unmapped, the recorded drops], size: 6.5pt)
})

== stdlib coverage

Component families against chapters, with the honest status column.
The jdk's own sources in `tools/jdk27/build/jdk-27/lib/src.zip`
answered the since tags, read the way every chapter read them.

#table(
  columns: (1.6fr, auto, 1.4fr),
  inset: 4pt,
  table.header([*component family*], [*chapter*], [*status*]),
  ..stdlib-coverage.map(r => ([#r.component], chapter-label(r.chapter), [#r.status])).flatten(),
)

#let covered-n = stdlib-coverage.filter(s => s.status.starts-with("covered")).len()
#let rest-n = stdlib-coverage.len() - covered-n
#let qualified-n = stdlib-coverage.filter(s => s.status.starts-with("covered") and s.status != "covered").len()

#diagram([stdlib coverage, covered in place against the honest exceptions], length: 13pt, {
  cdraw.rect((0.2, 0.0), (11.4, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 6.8), [#covered-n rows covered in place], size: 6.5pt)
  cdraw.content((5.8, 3.5), [the language core, collections and streams, #linebreak() io through channels and the http and ws clients, #linebreak() the concurrency families, the runtime tooling, #linebreak() modules and jlink, reflection, the crypto stack], size: 6pt)
  cdraw.rect((12.4, 0.0), (23.4, 7.4), fill: luma(230), radius: 0.02)
  cdraw.content((17.9, 6.8), [#rest-n rows uncovered, #qualified-n covered with a qualifier], size: 6.5pt)
  cdraw.content((17.9, 4.6), [regex mentioned only, #linebreak() serialization not taught #linebreak() with its keyword twin unmapped], size: 6pt)
  cdraw.content((17.9, 2.0), [covered with an asterisk: compact numbers a #linebreak() non-jep enhancement, json hand-rolled #linebreak() because the jdk ships none, junit vendored], size: 6pt)
  cdraw.content((11.8, -0.7), [the status column is the contract, covered means a chapter demonstrates it], size: 6.5pt)
})

== pinned sources

Every chapter ends with its own sources line naming what it
consulted and how it verified live. The book level pins:

#table(
  columns: (1.6fr, 2.2fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

#callout("note", "version drift rule", [
  34 of these pins were fetched 2026-10-04 and 2026-10-05 against
  the ga jdk 27, build 27+35-2325, with the 19 release pages
  re-verified per release and the spec read at se 27. The one older
  date is the junit maven fetch, 2026-08-07, the day the jar was
  first vendored, and it stands because the sha gate would catch a
  moved artifact. If an upstream page changes,
  the delta gets recorded here rather than silently rewriting
  chapters, so this table is also the book's changelog for
  documentation movement.
])

#callout("note", "the pinned build", [
  Every lane in this book compiles and runs on the oracle jdk 27 ga
  build 27+35-2325 installed sha256-gated into tools/jdk27/build by
  `sh tools/build-jdk27.sh`, because the machine's own java can be a
  release older than the classes, class file version 71 needs 27,
  the fact the capstone's e2e resolves first. Under the corpus
  version currency law the pin rides the newest installable ga
  build, nightlies excepted, and the next lts is dated september
  2027 by the roadmap.
])

#callout("note", "the one external artifact", [
  The spine's standing rule is stdlib-exclusive, no gradle, no
  maven, no spring, and the book makes exactly one vendoring
  decision: the junit console standalone 6.1.3, sha-gated in the
  vendor manifest and rehashed by the lane before anything runs.
  React 19.3.0, vite 8.3.2, and the vite react plugin 6.1.1 are
  pinned exact in the capstone frontend's package.json, outside the
  java lane's dependency surface.
])

#diagram([the access window, when the pins were read and what moves next], length: 13pt, {
  cdraw.line((1.0, 3.0), (21.0, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.6, 3.2), (2.6, 3.6), stroke: luma(100))
  cdraw.content((2.6, 4.1), [2026-10-04], size: 6pt)
  cdraw.line((9.8, 3.2), (9.8, 3.6), stroke: luma(100))
  cdraw.content((9.8, 4.1), [2026-10-05], size: 6pt)
  cdraw.content((6.2, 2.2), [the manual arc and wave 0: spec, 19 release pages, the jep spine], size: 6pt)
  cdraw.content((6.2, 1.1), [the service and capstone waves: rfcs, iana, owasp, junit, docker], size: 6pt)
  cdraw.content((6.2, 0.0), [one pin predates the window, the junit jar fetched 2026-08-07], size: 6pt)
  cdraw.line((15.4, 3.0), (15.4, 2.6), stroke: luma(100))
  cdraw.content((15.4, 1.5), [september 2027, #linebreak() the next lts], size: 6pt)
  cdraw.content((9.2, 5.4), [a moved page becomes a recorded delta, never a silent rewrite], size: 6.5pt)
})

sources: the three coverage files this chapter renders,
`books/java/coverage/keywords.typ`, `stdlib.typ`, and `sources.typ`,
enumerated 2026-10-05 from the chapters' own recorded sources
paragraphs and the se 27 spec census chapter 3 measured live through
`javax.lang.model.SourceVersion` on tools/jdk27/build/jdk-27, build
27+35-2325. The test counts quoted in the opening paragraph are the
commit's own: 158 api junit tests plus 5 integration, 131 capstone
junit tests, 21 node tests, 58 sample files at 493 checks, all green
through `pwsh -NoProfile -File tools/verify-java.ps1` on 2026-10-05.
The IANA registry row re-fetched 2026-10-05, its 1012 to 1014
entries last updated 2025-07-30 there.
