#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": csharpnet
#import "../coverage/keywords.typ": matrix, reserved, contextual, taught-in, fsharp-tour
#import "../coverage/stdlib.typ": stdlib-coverage
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

#let chapter-label(id) = {
  if id == "unmapped" { return [unmapped] }
  let found = csharpnet.chapters.find(c => c.id == id)
  [ch #found.num]
}

The coverage matrices are the book's audit trail. Every reserved and
contextual keyword enumerated from the official keywords page, every
stdlib component family, each mapped to the chapter that teaches it,
and rendered here at milestone time. The build enforces honesty from
the other side: every chapter listing reads a real file that the
sample suite compiles and tests, 211 tests in the samples suite, 54
in the capstone, 20 in the f\# port, zero skipped anywhere.

== keyword coverage

#let unmapped = matrix.filter(r => r.chapter == "unmapped").len()

#chapter-label("toolchain") is where `var` and `args` land,
#chapter-label("lexical") carries the literal surface, and the
reserved words are spread from there. The census matches chapter 2's
recount: 77 reserved words, the set frozen since C\# 1, against 49
contextual, with `union` filed contextual on the union reference
page's word rather than the live index table's, which had not listed
it at the recount date. Unmapped count: #unmapped.

#table(
  columns: (auto, 1fr, auto),
  inset: 4pt,
  table.header([*word*], [*kind*], [*taught in*]),
  ..matrix.map(r => ([#r.word], [#r.kind], chapter-label(r.chapter))).flatten(),
)

The f\# side is a tour, chapters 19 through 21, not a census, and
claims no count over the language's own keyword table. These are the
words and symbols the tour exercises, enumerated from the official
f\# language reference, with `and!` read from the task expressions
page:

#table(
  columns: (auto, 1fr, auto),
  inset: 4pt,
  table.header([*word or symbol*], [*kind*], [*taught in*]),
  ..fsharp-tour.map(r => ([#r.word], [#r.kind], chapter-label(r.chapter))).flatten(),
)

#diagram([the keyword census, #reserved.len() reserved against #contextual.len() contextual], length: 13pt, {
  // per chapter split read from the word lists themselves, sorted by total
  let rows = csharpnet.chapters.map(c => (
    num: c.num,
    r: reserved.filter(w => taught-in.at(w, default: "unmapped") == c.id).len(),
    k: contextual.filter(w => taught-in.at(w, default: "unmapped") == c.id).len(),
  )).filter(x => x.r + x.k > 0).sorted(key: x => -(x.r + x.k))
  let top = rows.slice(0, count: 8)
  let rest-r = rows.slice(8).fold(0, (a, x) => a + x.r)
  let rest-k = rows.slice(8).fold(0, (a, x) => a + x.k)
  let scale = 0.44
  cdraw.line((3.2, 7.35), (3.2, -2.0), stroke: luma(220))
  for (i, x) in top.enumerate() {
    let y = 6.8 - i * 1.05
    cdraw.content((1.5, y), [ch #x.num], size: 6pt)
    cdraw.rect((3.2, y - 0.32), (3.2 + x.r * scale, y + 0.32), fill: luma(205), radius: 0.02)
    cdraw.rect((3.2 + x.r * scale, y - 0.32), (3.2 + (x.r + x.k) * scale, y + 0.32), fill: luma(235), radius: 0.02)
    cdraw.content((3.2 + (x.r + x.k) * scale + 0.9, y), [#(x.r + x.k)], size: 6pt)
  }
  let y-last = 6.8 - 8 * 1.05
  cdraw.content((1.5, y-last), [rest], size: 6pt)
  cdraw.rect((3.2, y-last - 0.32), (3.2 + rest-r * scale, y-last + 0.32), fill: luma(205), radius: 0.02)
  cdraw.rect((3.2 + rest-r * scale, y-last - 0.32), (3.2 + (rest-r + rest-k) * scale, y-last + 0.32), fill: luma(235), radius: 0.02)
  cdraw.content((3.2 + (rest-r + rest-k) * scale + 0.9, y-last), [#(rest-r + rest-k)], size: 6pt)
  cdraw.rect((15.7, 6.7), (16.3, 6.94), fill: luma(205), radius: 0.02)
  cdraw.content((19.6, 6.82), [reserved, #reserved.len()], size: 6.5pt)
  cdraw.rect((15.7, 5.5), (16.3, 5.74), fill: luma(235), radius: 0.02)
  cdraw.content((19.6, 5.62), [contextual, #contextual.len()], size: 6.5pt)
  cdraw.content((10.5, -2.8), [every word mapped to a chapter, unmapped count #unmapped], size: 6.5pt)
})

== stdlib coverage

Component families against chapters, with the honest status column.
Rows marked as pointers delegate the deep treatment to the systems
books that follow, where the components are built rather than used.

#table(
  columns: (1.6fr, auto, 1.4fr),
  inset: 4pt,
  table.header([*component family*], [*chapter*], [*status*]),
  ..stdlib-coverage.map(r => ([#r.component], chapter-label(r.chapter), [#r.status])).flatten(),
)

#let covered-n = stdlib-coverage.filter(s => s.status.starts-with("covered")).len()
#let pointed-n = stdlib-coverage.len() - covered-n

#diagram([stdlib coverage, covered in place against pointers], length: 13pt, {
  // the covered set at left, the pointer rows at right, counts from the table
  cdraw.rect((0.2, 0.0), (11.4, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 6.8), [#covered-n rows covered in place], size: 6.5pt)
  cdraw.content((5.8, 3.5), [collections, numerics, #linebreak() decimal floats, spans, json, #linebreak() unions on the wire, io, http, #linebreak() channels, text, utilities, #linebreak() linq, joins, exceptions, #linebreak() nullable, pools, reflection, generators], size: 6pt)
  cdraw.rect((12.4, 0.0), (23.4, 7.4), fill: luma(230), radius: 0.02)
  cdraw.content((17.9, 6.8), [#pointed-n rows point elsewhere], size: 6.5pt)
  cdraw.content((17.9, 3.15), [`Regex` to the ch 13 generator, #linebreak() threading and locks to book 11, #linebreak() diagnostics to book 11, #linebreak() utf8 reader, writer, complex, #linebreak() mentioned only], size: 6pt)
  cdraw.content((11.8, -0.7), [the pointer rows are promises the systems books keep], size: 6.5pt)
})

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
  These pins were fetched 2026-09-07 and 2026-09-08 against C\# 14
  and .NET 10 (SDK 10.0.400) with C\# 15 and .NET 11 read at
  preview 7, then re-read and extended 2026-09-13 at the 2.0
  closeout: the C\# 15 what's new page, the .NET 11 overview
  re-read plus its runtime and libraries notes, and the f\#
  reference set, all against the RC1 SDK. If an upstream page
  changes, the delta gets recorded here rather than silently
  rewriting chapters, so this table is also the book's changelog
  for documentation movement.
])

#callout("note", "the rc1 build pin", [
  Since the C\# 15 folds, this book builds and tests on the .NET 11
  SDK at 11.0.100-rc.1, pinned by the book local `global.json` with
  `latestFeature` roll forward, while the repository root stays on
  10.0.401 for the other books. Under the corpus version currency
  law this pin rides the newest build the vendor makes installable,
  nightlies excepted, and it was verified current 2026-09-30: the
  dotnet release feed shows RC1, shipped september 8, as the newest
  .NET 11 build with no RC2 yet and GA expected november 2026, and
  the three taught RC1 quirks re-probed unchanged on that date, the
  per-type `[JsonNamingPolicy]` attribute rejecting `PascalCase`
  with `ArgumentOutOfRangeException` while the options lever and the
  snake attribute serialize clean, `StringStream` reporting
  `CanSeek` false with `Length` throwing
  `NotSupportedException`, and the F\# 11 what's new page still
  absent. Whenever a newer build ships, RC2 or GA, the pin moves to
  it, `make verify-csharp` re-runs, and any behavioral delta lands
  here rather than silently editing chapters.
])

#callout("note", "the f# versioning evidence", [
  No what's new in F\# 11 page existed at RC1 and the .NET 11
  overview names no F\# language version, so the F\# 11 claim rests
  on the SDK itself: `dotnet fsi` under 11.0.100-rc.1 loads
  `FSharp.Core 11.0.0.0` on a runtime reporting 11.0.0, the same
  pairing the F\# 9 and F\# 10 pages document for their releases.
  Re-checked 2026-09-30, the canonical url still answers 404, so
  the SDK witness stands. When the F\# 11 page ships, pin it in the
  table above and re-check chapter 21's versioning section against
  it.
])

#diagram([the pin timeline, when the pins were read and when they drift], length: 13pt, {
  // the axis, the read window bracketed below it, the re-read tick, the future ga
  cdraw.line((1.0, 3.0), (21.0, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.6, 3.2), (2.6, 3.6), stroke: luma(100))
  cdraw.content((2.6, 4.1), [2026-09-07], size: 6pt)
  cdraw.line((7.2, 3.2), (7.2, 3.6), stroke: luma(100))
  cdraw.content((7.2, 4.1), [2026-09-08], size: 6pt)
  cdraw.line((1.2, 3.0), (1.2, 2.5), stroke: luma(100))
  cdraw.line((9.0, 3.0), (9.0, 2.5), stroke: luma(100))
  cdraw.line((1.2, 2.5), (9.0, 2.5), stroke: luma(100))
  cdraw.content((5.1, 1.3), [c\# 14 / .net 10 pinned, #linebreak() c\# 15 / .net 11 at preview 7], size: 6pt)
  cdraw.line((11.4, 3.0), (11.4, 3.6), stroke: luma(100))
  cdraw.content((11.4, 4.1), [2026-09-13], size: 6pt)
  cdraw.content((11.4, 2.3), [2.0 re-read], size: 6pt)
  cdraw.line((17.2, 3.0), (17.2, 2.6), stroke: luma(100))
  cdraw.content((17.2, 1.5), [nov 2026, #linebreak() .net 11 ga expected], size: 6pt)
  cdraw.content((9.2, 5.4), [the book now builds on .net 11, sdk 11.0.100-rc.1], size: 6.5pt)
  cdraw.content((9.2, -0.35), [a moved page becomes a recorded delta], size: 6.5pt)
})
