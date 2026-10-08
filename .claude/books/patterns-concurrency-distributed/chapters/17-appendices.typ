#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": patterns
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= appendices: topic matrix and sources

The topic matrix is this book's audit trail: every pattern,
primitive, and protocol the chapters build, the cost it carries,
and the go standard library counterpart to reach for in
production code. The six-voice rebuild gave chapters 1 to 15
five sibling trees and the java wave added the sixth, every
featured listing now exists once per language, c, go, java,
c\#, javascript, python, and lua, built behind the same
fixtures, while the raft capstone of chapter 16 and
this appendix stay go-only by design. The build enforces the
rest, every chapter listing reads a real file that its own
pinned toolchain compiles and tests. The totals: c 64 files and
6755 checks, go 89 sample tests and 19 capstone tests, java 64
files and 703 checks, c\# 178 tests, javascript 121 tests,
python 64 files and 582 asserts, lua 271 checks, zero skipped
anywhere, with the go concurrency
chapters also held under `go test -race`.

== topic coverage

#let unmapped = topics.filter(r => r.chapter == "unmapped").len()

#let chapter-label(id) = {
  let found = patterns.chapters.find(c => c.id == id)
  [ch #found.num]
}

Every topic maps to a chapter: #unmapped unmapped. The counterpart
column carries the book's honest boundary, many rows say `none in
bcl` because the go standard library genuinely ships no raft, no
consistent hash ring, no circuit breaker, and knowing which
problems it leaves to you is the practical knowledge.

#table(
  columns: (1.9fr, auto, 1.5fr, 1.4fr),
  inset: 4pt,
  table.header([*topic*], [*chapter*], [*cost*], [*go stdlib counterpart*]),
  ..topics.map(r => (
    [#r.topic],
    chapter-label(r.chapter),
    [#r.cost],
    [#r.bcl],
  )).flatten(),
)

#diagram([seventeen chapters in clusters, and where the none-in-bcl boundary sits], length: 13pt, {
  let band(y, from, to, title, note, filled: false) = {
    cdraw.rect((0.4, y - 0.75), (23.4, y + 0.75), radius: 0.02, fill: if filled { luma(235) } else { none }, stroke: luma(180))
    cdraw.content((3.4, y), title, size: 6.5pt)
    for n in range(from, to + 1) {
      let x = 7.0 + (n - from) * 1.1
      cdraw.rect((x, y - 0.42), (x + 0.9, y + 0.42), fill: luma(205), radius: 0.02)
      cdraw.content((x + 0.45, y), [#n], size: 6pt)
    }
    cdraw.content((19.2, y), note, size: 6pt)
  }
  band(6.9, 1, 5, [patterns], [the go stdlib answers most rows])
  band(5.0, 6, 9, [concurrency], [the go stdlib answers every row])
  band(3.1, 10, 16, [distributed], [no raft, no ring, no breaker], filled: true)
  band(1.2, 17, 17, [appendix], [the audit trail itself])
  cdraw.content((11.9, 0.0), [the none-in-bcl rows cluster in the distributed half], size: 6pt)
})

== pinned sources

#let early = sources.filter(s => s.accessed == "2026-09-08").len()
#let late = sources.len() - early

Every chapter ends with its own sources line naming the pages
consulted while writing it. The book level pins are:

#table(
  columns: (1.7fr, 2.3fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

#callout("note", "version drift rule", [
  The 2026-09-08 pins were verified against go 1.27.0 on
  windows/amd64, including local `go doc` probes of
  `WaitGroup.Go`, `testing/synctest`, `context.Cause`, and the
  RWMutex fairness wording. The 2026-09-23 pins rode the
  six-voice rebuild, c23 `threads.h` and `stdatomic` ordering,
  `System.Threading.Channels` and `TimeProvider`, node
  `worker_threads` and the `node:test` runner, python
  `threading` and `asyncio`, the lua 5.5 coroutine section, and
  the go stdlib pages the sibling listings consulted. Findings
  that contradicted intuition, the fnv high-bit clustering in
  chapter 12, the slog handler's obligation to call `Resolve`
  in chapter 14, the harness-vs-network message split the raft
  hub needed in chapter 16, are recorded in their chapters as
  verified behavior, and this table is the changelog if a
  future release moves any of them.
])

#diagram([the pin set on its access timeline, two dates, the go doc probes marked], length: 13pt, {
  cdraw.line((1.0, 3.2), (23.0, 3.2), stroke: luma(100))
  cdraw.circle((3.2, 3.2), radius: 0.13, fill: luma(30))
  cdraw.content((3.2, 4.1), [#early pins accessed 2026-09-08], size: 6pt)
  cdraw.circle((15.7, 3.2), radius: 0.13, fill: luma(30))
  cdraw.content((15.7, 4.1), [#late pins accessed 2026-09-23], size: 6pt)
  cdraw.content((6.0, 2.2), [go 1.27.0, windows/amd64], size: 6pt)
  cdraw.content((11.8, 2.2), [#sources.len() book-level pins in all], size: 6pt)
  let probes = ((4.5, [WaitGroup.Go]), (9.7, [testing/#linebreak()synctest]), (14.9, [context.Cause]), (20.1, [RWMutex#linebreak()fairness]))
  for (x, name) in probes {
    cdraw.line((x, 3.2), (x, 1.7), stroke: luma(180))
    cdraw.rect((x - 2.5, 0.3), (x + 2.5, 1.7), fill: luma(235), radius: 0.02)
    cdraw.content((x, 1.0), name, size: 6pt)
  }
  cdraw.content((12.0, -0.5), [local go doc probes from the first date, the changelog if a future release moves one], size: 6pt)
})
