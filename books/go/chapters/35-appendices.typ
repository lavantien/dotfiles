#import "../../theme/lib.typ": callout
#import "../manifest.typ": gobook
#import "../coverage/keywords.typ": matrix
#import "../coverage/stdlib.typ": stdlib-coverage
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

The coverage matrices are this book's audit trail. All 25 keywords
enumerated from the specification, every stdlib component family the
book touches, each mapped to the chapter that teaches it, rendered
here at milestone time. The build enforces honesty from the other
side: every chapter listing reads a real file that a go module in
this repo compiles and tests.

== keyword coverage

#let unmapped = matrix.filter(r => r.chapter == "unmapped").len()

#let chapter-label(id) = {
  if id == "unmapped" { return [unmapped] }
  let found = gobook.chapters.find(c => c.id == id)
  [ch #found.num]
}

Go reserves 25 words and freezes the list, so this matrix has one
kind and no unmapped rows: #unmapped. The program structure chapter
carries the statement words, functions and concurrency split the
rest, and the predeclared identifiers that look like keywords, `len`
through `println`, live in chapter 2 as the lexical chapter's
counterexample.

#table(
  columns: (auto, 1fr, auto),
  inset: 4pt,
  table.header([*word*], [*kind*], [*taught in*]),
  ..matrix.map(r => ([#r.word], [#r.kind], chapter-label(r.chapter))).flatten(),
)

== stdlib coverage

Component families against chapters, with the status column marking
the one documented-not-tested entry and the pointers that defer to
the systems books.

#table(
  columns: (1.6fr, auto, 1.4fr),
  inset: 4pt,
  table.header([*component family*], [*chapter*], [*status*]),
  ..stdlib-coverage.map(r => ([#r.component], chapter-label(r.chapter), [#r.status])).flatten(),
)

== pinned sources

Every chapter ends with its own sources line naming the official
sections consulted while writing it. The book level pins are:

#table(
  columns: (1.6fr, 2.2fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

#callout("note", "version drift rule", [
  These pins were fetched 2026-09-08 against go 1.27.0 on windows
  with the module pinned `go 1.27`. If an upstream page changes, the
  delta gets recorded here rather than silently rewriting chapters,
  so this table is also the book's changelog for documentation
  movement. The simd row is the honest boundary: documented from the
  release notes and pkg.go.dev, untested because the experiment gate
  would pin the module to a toolchain configuration.
])
