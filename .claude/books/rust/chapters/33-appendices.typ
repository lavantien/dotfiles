#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": rustbook
#import "../coverage/keywords.typ": matrix, strict, reserved, weak, taught-in
#import "../coverage/stdlib.typ": stdlib-coverage
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

#let chapter-label(id) = {
  if id == "unmapped" { return [unmapped] }
  let found = rustbook.chapters.find(c => c.id == id)
  [ch #found.num]
}

The coverage matrices are the book's audit trail. Every strict,
reserved, and weak token enumerated from the rust reference keyword
chapter, every stdlib component family the book touches mapped to
the chapter that teaches it, and the official sources pinned with
their access dates. The build enforces honesty from the other side:
every chapter listing reads a real file the lanes compile and test,
162 api-lane tests plus 5 behind the docker gate and 36 in the
capstone, 85 sample files at 902 checks, zero skipped anywhere, the
inventory chapter 31 recorded on 2026-10-14, every count from
`cargo test --locked` under `CARGO_NET_OFFLINE=true` on the pinned
1.99.0 build.

== keyword coverage

#let unmapped = matrix.filter(r => r.chapter == "unmapped").len()

Chapter 3 owns the census pointer and this table is its accounting:
39 strict keywords, 14 reserved for future use with `gen` joining
through the 2024 edition, and the 5 weak words that parse only in
specific positions. All 39 strict words map to a teaching site, and
the borderline ones map to their one honest home: `if` and `else`
ride chapter 7's pattern forms, guards and `if let` and let-else,
plain `while` is the condvar predicate loop of chapter 13, the only
place the book states its discipline, `loop` is chapter 14's
`block_on` driver, `break` is chapter 10's iterator measurement,
and `continue` appears in exactly one teaching position, chapter 7's
let-else divergence rule beside `return`, `break`, and panic. Of
the reserved set only `gen` and `try` map, both to chapter 2, the
2024 reservation and the word still waiting since 2018. The other
12 reserved words and the weak `safe`, whose `unsafe(...)` mirror
chapter 2 teaches while the `safe(...)` spelling goes unmentioned,
stay unmapped, #unmapped rows in all, named nowhere outside this
matrix.

#table(
  columns: (auto, 1fr, auto, auto),
  inset: 4pt,
  table.header([*word*], [*kind*], [*since*], [*taught in*]),
  ..matrix.map(r => ([#r.word], [#r.kind], if r.since == none { [] } else { [#r.since] }, chapter-label(r.chapter))).flatten(),
)

#diagram([the edition promotions, words that arrived after 1.0 and the escape that softened them], length: 13pt, {
  cdraw.line((1.0, 3.0), (21.0, 3.0), stroke: luma(100), mark: (end: ">"))
  let tick(x, label, n) = {
    cdraw.line((x, 3.2), (x, 3.6), stroke: luma(100))
    cdraw.content((x, 4.1), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#n], size: 6pt)
  }
  tick(3.0, [1.27], [dyn, 2018 ed.])
  tick(7.0, [1.30], [raw identifiers])
  tick(11.0, [1.39], [async, await])
  tick(17.5, [1.85], [gen reserved, 2024 ed.])
  cdraw.content((11.0, 5.6), [every promotion rides the r\# escape rather than a break], size: 6.5pt)
  cdraw.content((11.0, 0.9), [try reserved since the 2018 edition still waits, chapter 2's own note], size: 6pt)
})

#diagram([the census by teaching chapter, counted from the table above], length: 13pt, {
  let rows = rustbook.chapters.map(c => (
    num: c.num,
    n: matrix.filter(r => r.chapter == c.id).len(),
  )).filter(x => x.n > 0).sorted(key: x => -x.n)
  let scale = 0.62
  for (i, x) in rows.enumerate() {
    let y = 6.8 - i * 1.05
    cdraw.content((1.5, y), [ch #x.num], size: 6pt)
    cdraw.rect((3.2, y - 0.32), (3.2 + x.n * scale, y + 0.32), fill: luma(205), radius: 0.02)
    cdraw.content((3.2 + x.n * scale + 0.9, y), [#x.n word#if x.n > 1 { [s] }], size: 6pt)
  }
  cdraw.content((14.5, 6.6), [#strict.len() strict, all mapped], size: 6.5pt)
  cdraw.content((14.5, 5.5), [2 of #reserved.len() reserved mapped, both ch 2], size: 6.5pt)
  cdraw.content((14.5, 4.4), [#weak.len() weak words, 4 mapped], size: 6.5pt)
  cdraw.content((14.5, 3.3), [#unmapped unmapped, 12 reserved plus safe], size: 6.5pt)
})

== stdlib coverage

Component families against chapters, with the honest status column.
The std pages were read from the offline 1.99.0 rust-docs share, the
same oracle every chapter read, and each row below was grepped
against its chapter on 2026-10-14: taught with checks means the
chapter's own samples or its lane's tests exercise the family,
stated means the chapter names it without a demonstration.

#table(
  columns: (1.6fr, auto, 1.4fr),
  inset: 4pt,
  table.header([*component family*], [*chapter*], [*status*]),
  ..stdlib-coverage.map(r => ([#r.component], chapter-label(r.chapter), [#r.status])).flatten(),
)

#let taught-n = stdlib-coverage.filter(s => s.status.starts-with("taught")).len()
#let rest-n = stdlib-coverage.len() - taught-n

#diagram([stdlib coverage, #taught-n families taught with checks against the one honest stated row], length: 13pt, {
  cdraw.rect((0.2, 0.0), (12.4, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((6.3, 6.8), [#taught-n rows taught with checks], size: 6.5pt)
  cdraw.content((6.3, 3.5), [collections through process in chapter 15, #linebreak() the concurrency families in 13, #linebreak() pointers and cells in 12, futures in 14, #linebreak() fs in the store lane of 24, ffi in 17], size: 6pt)
  cdraw.rect((13.4, 0.0), (23.4, 7.4), fill: luma(230), radius: 0.02)
  cdraw.content((18.4, 6.8), [#rest-n row stated], size: 6.5pt)
  cdraw.content((18.4, 4.2), [alloc, the allocator api named #linebreak() as an escape hatch in chapter 12, #linebreak() never demonstrated, #linebreak() the no-gc contrast stands without it], size: 6pt)
  cdraw.content((11.8, -0.7), [the status column is the contract, taught with checks means a chapter or its lane runs it], size: 6.5pt)
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

#callout("note", "the offline oracle", [
  The pin under every row is the 1.99.0 rust-docs component under
  `~/.rustup/toolchains/stable-x86_64-pc-windows-msvc`, its
  `share/doc/rust/html` tree reached through `rustup doc --book`,
  the same pages the api and capstone lanes compile against
  offline. Each url row was verified against that offline copy the
  same day it was accessed, so a moved upstream page is a recorded
  delta here, never a silent rewrite of a chapter.
])

#callout("note", "the pinned build", [
  Every lane in this book compiles and runs on rustc 1.99.0
  (b940084d7 2026-09-28), resolved through the rustup lane of
  chapter 1 and asserted by `tools/verify-rust.ps1` before anything
  runs, because the machine's own default toolchain can drift a
  release from the book. The receipts are `cargo test --locked`
  under `CARGO_NET_OFFLINE=true`, the same invocation every chapter
  quotes. Under the corpus version currency law the pin rides the
  newest installable ga build.
])

#callout("note", "the std-only stance", [
  Std is the only dependency the book allows itself, chapter 15's
  standing rule: the api lane's manifest declares no dependencies at
  all and the capstone crate is one package in its `Cargo.lock`,
  with no `unsafe` anywhere in its 1765 lines. The one external
  surface is deployment, and chapter 30 pins it by digest, the
  builder `rust:1.99` and the runtime `debian:trixie-slim`, both
  recorded in `deploy.rs` with the dates they were resolved.
])

#diagram([the access window, when the pins were read], length: 13pt, {
  cdraw.line((1.0, 3.0), (21.0, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 3.2), (6.0, 3.6), stroke: luma(100))
  cdraw.content((6.0, 4.1), [2026-10-13], size: 6pt)
  cdraw.line((15.0, 3.2), (15.0, 3.6), stroke: luma(100))
  cdraw.content((15.0, 4.1), [2026-10-14], size: 6pt)
  cdraw.content((11.0, 2.3), [on the 13th, the manual arc and the early service chapters: #linebreak() the reference, the book, the edition guide, the std api, the rfc spine], size: 6pt)
  cdraw.content((11.0, 0.8), [on the 14th, the later service chapters and the capstone: #linebreak() the std task and net pages, the tokio wheel, #linebreak() rfc 6585 and 9111, prometheus, the docker docs], size: 6pt)
  cdraw.content((9.2, 5.4), [every row re-verified against the offline share the same day], size: 6.5pt)
})

sources: the three coverage files this chapter renders,
`books/rust/coverage/keywords.typ`, `stdlib.typ`, and `sources.typ`,
enumerated 2026-10-13 and filled 2026-10-14 from the chapters' own
recorded sources paragraphs, the taught-in map grepped from the 32
written chapters for each word's teaching site, and the sources
table checked row by row against every chapter 19 through 32
trailing paragraph, the prometheus and docker rows the only
additions the sweep found. The test counts quoted in the opening
paragraph are chapter 31's and 32's own recorded runs of
2026-10-14 and 2026-10-15: 162 plain-lane tests plus 5 behind the docker gate,
36 capstone tests, 85 sample files at 902 checks with all 3
multi-language suites present.
