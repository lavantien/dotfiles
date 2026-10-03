#import "../../theme/lib.typ": callout, diagram, cdraw, xref-to
#import "../manifest.typ": luabook
#import "../coverage/keywords.typ": matrix
#import "../coverage/stdlib.typ": stdlib-coverage
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

The coverage matrices are this book's audit trail. All 23 reserved
words of 5.5, `global` included, mapped to the chapter that teaches
them, and every standard library family with its status, including
the one honest row that stays documented rather than tested, the
compact internal arrays, which have no observable semantics. The c
api row turned covered in the 3.0 wave: six hosts run under
`make verify-lua-c` and the capstone embeds the game in an allegro
host. The build enforces the rest: every chapter listing reads a
real file that the pinned interpreter executes under
`make verify-lua`.

#diagram([how the keyword matrix is proven, word by word], length: 13pt, {
  // the probe pipeline, line widths measured against the boxes
  cdraw.rect((0.5, 7.4), (8.0, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.25, 8.85), [the probe], size: 6pt)
  cdraw.content((4.25, 7.75), [23 words as names], size: 6pt)
  cdraw.line((8.2, 8.5), (8.9, 8.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.1, 7.4), (15.0, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((12.05, 8.5), [22 refuse to load], size: 6pt)
  cdraw.line((15.2, 8.5), (15.9, 8.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.1, 7.4), (21.5, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((18.8, 8.85), [words mapped], size: 6pt)
  cdraw.content((18.8, 7.75), [to its chapter], size: 6pt)
  // the survivor and the guarantee
  cdraw.content((11.0, 6.2), [one word survives as a name under compat: global], size: 6.5pt)
  cdraw.content((11.0, 5.0), [the matrix below is the result, zero words unmapped], size: 6.5pt)
  cdraw.content((11.0, 3.8), [every chapter listing is a real file the pinned interpreter runs], size: 6.5pt)
})

#diagram([the coverage boundary, tested against documented only], length: 13pt, {
  // the tested families, one line per family set
  cdraw.rect((0.5, 7.2), (21.5, 10.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 10.1), [tested under make verify-lua], size: 6pt)
  cdraw.content((11.0, 8.9), [basic, string, table, math, io, os,], size: 6pt)
  cdraw.content((11.0, 7.7), [coroutine, debug, package, utf8, the ffi], size: 6pt)
  // the c hosts joined the tested side in the 3.0 wave
  cdraw.content((11.0, 6.0), [the c api: 6 hosts and the allegro capstone host, verified], size: 6pt)
  // the one honest row left, shaded
  cdraw.rect((0.5, 4.4), (21.5, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 5.1), [compact arrays: documented, nothing observable to test], size: 6pt)
  cdraw.content((11.0, 2.9), [the status column carries this boundary], size: 6.5pt)
  cdraw.content((11.0, 1.7), [everything else runs as listings under the pinned binary], size: 6.5pt)
})

== keyword coverage

#let unmapped = matrix.filter(r => r.chapter == "unmapped").len()

#let chapter-label(id) = {
  let found = luabook.chapters.find(c => c.id == id)
  [ch #found.num]
}

Every reserved word maps to a chapter: #unmapped unmapped. One word
carries a note the whole book repeats: `global`, reserved by the
manual, contextual in the stock 5.5.1 build through the
`LUA_COMPAT_GLOBAL` default, pinned in #xref-to("lua", "lexical"),
#xref-to("lua", "environments"), and #xref-to("lua", "incompat").

#table(
  columns: (auto, auto, auto, 1.6fr),
  inset: 4pt,
  table.header([*word*], [*kind*], [*taught in*], [*note*]),
  ..matrix.map(r => ([#r.word], [#r.kind], chapter-label(r.chapter), [#r.note])).flatten(),
)

== stdlib coverage

Component families against chapters, with the status column carrying
the honest boundary: what runs under test, what is documented only.

#table(
  columns: (1.7fr, auto, 1.4fr),
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

#diagram([the drift rule, one binary, one fetch date, one changelog], length: 13pt, {
  // the pin timeline
  cdraw.line((0.8, 6.0), (21.5, 6.0), stroke: luma(100), mark: (end: ">"))
  let event(x, half, txt) = {
    cdraw.rect((x - half, 4.5), (x + half, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x, 5.5), txt, size: 6pt)
  }
  event(3.4, 2.4, [lua 5.5.1, #linebreak() the one binary])
  event(9.6, 2.0, [pins fetched, #linebreak() 2026-09-08])
  event(16.4, 3.6, [contradictions logged, #linebreak() chapter by chapter])
  // what the rule means
  cdraw.content((11.0, 3.4), [the compat default, the param range, the section 8 deltas], size: 6.5pt)
  cdraw.content((11.0, 2.2), [a future 5.5.x that moves any of them: this table is the changelog], size: 6.5pt)
})

#callout("note", "version drift rule", [
  These pins were fetched 2026-09-08 against lua 5.5.1 built from the
  official tarball into `tools/lua55`, run on windows with the
  interpreter and luac from that one build. Findings that contradicted
  the manual, the compat default for `global`, the out-of-range
  acceptance of `param` values, the beyond-section-8 changes of
  #xref-to("lua", "incompat"), are recorded in their chapters as verified behavior of
  this binary, and this table is the changelog if a future 5.5.x
  moves any of them.
])
