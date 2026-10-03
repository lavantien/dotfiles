#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": gamesystems
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= appendices: topic matrix and sources

The topic matrix is this book's audit trail: every mechanism the
chapters build, what it costs, and where the wider world ships it.
The build enforces the rest, every chapter listing reads a real
file that the pinned toolchain compiles and tests, 156 sample tests
and 137 capstone tests, zero skipped, and the capstone's battle
engine, balance harness, renderer, and web companion all build from
one solution.

== topic coverage

#let chapter-label(id) = {
  let found = gamesystems.chapters.find(c => c.id == id)
  [ch #found.num]
}

127 topics across the 22 teaching and capstone chapters, each with
its honest cost and its counterpart in the ecosystem. The rows say
"none in bcl" where the base class library genuinely ships nothing,
which is most of this book, a game loop, an ecs, cordic trig, a
turn queue are all structures you own, and knowing which parts have
no library answer is the practical skill the column encodes.

#table(
  columns: (1.9fr, auto, 1.5fr, 1.4fr),
  inset: 4pt,
  table.header([*topic*], [*chapter*], [*cost*], [*ecosystem counterpart*]),
  ..topics.map(r => (
    [#r.topic],
    chapter-label(r.chapter),
    [#r.cost],
    [#r.bcl],
  )).flatten(),
)

#diagram([where the 127 topics landed, none unmapped], length: 13pt, {
  // counts per group: systems ch1-5 = 22, ai and math = 10, physics and terrain = 10,
  // flow chapters = 17, progression ch14-17 = 24, scripting ch18 = 10, capstones ch19-22 = 34
  cdraw.content((13.3, 8.7), [127 topics, 22 chapters, 0 unmapped], size: 6.5pt)
  cdraw.content((13.3, 7.9), [84 of the rows say none in bcl, the column's honest default], size: 6pt)
  cdraw.line((0.3, 1.9), (26.3, 1.9), stroke: luma(100))
  let bar(x, n, count, label, hot) = {
    let h = n * 0.14
    cdraw.rect((x, 1.9), (x + 2.6, 1.9 + h), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.3, 2.35 + h), [#count], size: 6pt)
    cdraw.content((x + 1.3, 1.15), label, size: 6pt)
  }
  bar(0.8, 22, [22], [systems#linebreak()ch 1-5], false)
  bar(4.5, 10, [10], [ai, math#linebreak()ch 6-7], false)
  bar(8.2, 10, [10], [world#linebreak()ch 8-9], false)
  bar(11.9, 17, [17], [flow#linebreak()ch 10-13], false)
  bar(15.6, 24, [24], [gear, pets#linebreak()ch 14-17], false)
  bar(19.3, 10, [10], [scripting#linebreak()ch 18], false)
  bar(23.0, 34, [34], [capstones#linebreak()ch 19-22], true)
})

== pinned sources

Every chapter ends with its own sources line naming the pages
consulted while writing it. The book level pins are:

#table(
  columns: (1.7fr, 2.3fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

#diagram([the 44 url pins by origin, the table's one local probe row sits outside them], length: 13pt, {
  // engines and tools 10 (kni x2, monogame, unity, ecs faq, htmx x2, fontstashsharp x2, nerd fonts),
  // dota 2 and moddota 7 (valve wiki x5 one live, the reborn page, tstl template), warcraft iii and hive 6
  // (patch mirror, hive x4, jassdoc), lua toolchain 5 (nlua x2, keralua x2, lua.org),
  // microsoft docs 3, genre pages 4, practitioners 4, gaffer papers and vendor news 5
  let row(y, label, n) = {
    cdraw.content((4.2, y), [#label], size: 6pt)
    cdraw.rect((9.0, y - 0.35), (9.0 + n * 1.5, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((9.6 + n * 1.5, y), [#n], size: 6pt)
  }
  row(8.3, [engines and tools], 10)
  row(7.15, [dota 2 and moddota], 7)
  row(6.0, [warcraft iii and hive], 6)
  row(4.85, [lua toolchain], 5)
  row(3.7, [gaffer, papers, vendor news], 5)
  row(2.55, [genre pages], 4)
  row(1.4, [practitioners], 4)
  row(0.25, [microsoft docs], 3)
  cdraw.content((13.5, -0.8), [44 url pins with access dates, the local probe row is the 45th], size: 6.5pt)
})

#callout("note", "version drift rule", [
  These pins were verified 2026-09-08 against kni 4.3.9001 and
  htmx 4.0.0 on windows/amd64 under .NET 10, including a restore
  and compile probe of the kni package before the renderer was
  written and a byte level SRI check of the vendored htmx. The
  2.0 additions were verified 2026-09-23 the same way: NLua 1.7.9
  over KeraLua 1.4.9 carrying lua54.dll, and FontStashSharp.Kni
  1.6.1 rasterizing the repo's vendored iosevka term ttf, each
  restored, compiled, and exercised by its own test lane. The
  measured claims, the 2.1x soa ratio, the cordic accuracy, the
  replay size gap, the on-off state hash equivalence, are all
  reproducible from the test suite, and this table is the
  changelog if a future release moves any of them.
])
