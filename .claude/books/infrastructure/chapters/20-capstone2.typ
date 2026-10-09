#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to
#import "../manifest.typ": infrastructure
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= capstone part 2: chat and notifications, one click

Part 1 built the services. This chapter is the face on them and the
proof they compose: an htmx page that polls fragments, and a gated
suite that proves the whole stack works from one compose command.

== htmx, vendored and pinned

The ui is one page plus five fragments, and htmx is the only script,
vendored into the binary with its sri digest inline:

#listing("infrastructure/capstone/internal/web/page.go", first: 16, last: 16, caption: [the digest of the vendored htmx.min.js, the same recipe as the game-systems companion])

The script tag carries the digest and the file is embedded through
`go:embed`, so the running binary cannot serve a script other than
the one pinned, and swapping the file breaks the page loudly instead
of silently. The page itself is a template function with everything
escaped through the html package:

#listing("infrastructure/capstone/internal/web/page.go", first: 35, last: 70, caption: [the index: polling targets, the send form, user and room carried in the query])

Every fragment endpoint is one NATS request,
#xref-to("infrastructure", "capstone1") showed the handler side. The
one piece of server-side state is the notification inbox, a per user
ring fed by a lazy subscription:

#listing("infrastructure/capstone/internal/web/inbox.go", first: 36, last: 46, caption: [drain: subscribe on first poll, hand over the ring, clear it])

#diagram([the script's chain of custody, and the ring as read receipt], length: 13pt, {
  cdraw.rect((0.0, 7.0), (6.4, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 7.5), [htmx.min.js], size: 6.5pt)
  cdraw.line((6.4, 7.5), (7.8, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.1, 8.6), [go:embed], size: 6pt)
  cdraw.rect((7.8, 7.0), (15.8, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 7.5), [embedded in the binary], size: 6pt)
  cdraw.line((15.8, 7.5), (17.2, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.2, 7.0), (23.4, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((20.3, 7.5), [digest checked], size: 6pt)
  cdraw.content((5.5, 5.8), [a swapped file fails the digest loudly], size: 6pt)

  cdraw.rect((0.0, 3.4), (7.0, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 3.9), [ring, per user], size: 6.5pt)
  cdraw.line((7.0, 3.9), (8.4, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.4, 3.4), (16.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((12.4, 3.9), [drain on first poll], size: 6pt)
  cdraw.line((16.4, 3.9), (17.8, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.8, 3.4), (23.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((20.6, 3.9), [read receipt], size: 6pt)

  cdraw.content((11.0, 2.2), [each notification seen once], size: 6pt)
  cdraw.content((11.0, 1.1), [a closed tab ages out, bounded], size: 6pt)
})

The drain is the read receipt. A polling tab sees each notification
once, and a closed tab's notifications age out with the ring bound.
The roster fragment doubles as the heartbeat, so a live tab stays
online by doing what it was doing anyway, and the browser needs no
javascript beyond htmx itself.

The escaping is a test, not a hope: the suite sends a script tag as a
message body and asserts it arrives entity-encoded in the fragment,
in both the in-process and the docker-gated runs.

The stats and analytics panels are the engine pair made visible. Both
are one NATS request per poll, `history.stats` to mongo and
`analytics.stats` to duckdb, both every ten seconds, and both render
the same `wire.Stats` shape, so the only visible difference between
the panels is which engine answered:

#listing("infrastructure/capstone/internal/web/page.go", first: 64, last: 71, caption: [the two ten second panels: mongo answers stats, duckdb answers analytics])

`renderAnalytics` is `renderStats` with a duckdb label on the
headings, deliberately. If the two panels ever disagree, a bug in one
of the engines or in the stream fanout is on the table, and this page
is the fastest place to see it.

== the one command

`docker compose up -d --wait` brings up nats, mongo, and the six
services, every container behind a healthcheck, the web tier waiting
on all five below it. The make target owns the lifecycle:

#snippet("verify-infra-docker: verify-duckdb-race\n"
  + "\t@docker info >/dev/null 2>&1 || { \\\n"
  + "\t\techo \"docker daemon not reachable.\" >&2; \\\n"
  + "\t\techo \"start Docker Desktop (or the engine), then rerun: make verify-infra-docker\" >&2; \\\n"
  + "\t\texit 1; \\\n"
  + "\t}\n"
  + "\t@cd books/infrastructure/capstone && trap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\tgo test -tags docker ./integration/...; rc=$$?; exit $$rc", lang: "make")

#diagram([the one command as a state machine, no skip edges anywhere], length: 13pt, {
  cdraw.rect((0.0, 8.0), (8.6, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.3, 8.5), [preflight], size: 6.5pt)
  cdraw.line((4.3, 8.0), (4.3, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.5, 8.5), [absent: red, exit 1], size: 6pt)

  cdraw.rect((0.0, 6.4), (8.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.3, 6.9), [up --build --wait], size: 6pt)
  cdraw.line((4.3, 6.4), (4.3, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.5, 7.2), [green only when every], size: 6pt)
  cdraw.content((17.5, 6.1), [container is healthy], size: 6pt)

  cdraw.rect((0.0, 4.8), (8.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.3, 5.3), [tagged suite], size: 6.5pt)
  cdraw.line((4.3, 4.8), (4.3, 4.3), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((0.0, 3.2), (8.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.3, 3.7), [trap: down -v, always], size: 6pt)

  cdraw.content((4.3, 2.0), [no skip edges anywhere], size: 6.5pt)
})

Three properties worth naming. The preflight exits 1 with two
plain-English lines when the daemon is absent, a red gate, never a
skip. The trap tears down with volumes even on failure, so a red run
leaves nothing behind. And the suite runs only after `--wait`
returned, which is why its first request can be the web port with no
sleep anywhere.

The analytics service is the one deliberate exception inside that
graph. Its image is debian rather than the shared alpine, because the
duckdb driver is cgo and its default static bindings want the glibc
toolchain the golang image already carries, a plain `go build` with no
tag. The same file carries the module's race pass: tsan plus cgo has
no supported path on windows regardless of compiler, so
`make verify-duckdb-race` builds the selftest stage and runs
`go test -race` on linux over the exact source snapshot the image
ships, while the runtime stage stays compose's default build target.
The data lands on the `analyticsdata` volume, the fourth named
volume, and the compose seat is otherwise identical to its peers:

#listing("infrastructure/capstone/analytics.Dockerfile", first: 1, last: 35, caption: [the one debian image: cgo build, the linux race stage, the slim runtime])

The gated walk is the system's whole story in one test: two users
join through roster polls, one sends, the message persists to sqlite
and appears in the room fragment, the notifier fans it to the other
user's inbox, the stats fragment answers from real mongo aggregation,
and the analytics fragment answers the same questions from real
duckdb sql:

#listing("infrastructure/capstone/integration/stack_test.go", first: 96, last: 111, caption: [the walk: presence, send, persistence, notification, analytics])

== topic matrix

#let unmapped = topics.filter(r => r.chapter == "unmapped").len()

#let chapter-label(id) = {
  let found = infrastructure.chapters.find(c => c.id == id)
  [ch #found.num]
}

Every topic maps to a chapter: #unmapped unmapped. The proof column
is where the running evidence lives, a test, a listing, or a gate.

#table(
  columns: (1.8fr, auto, 1.5fr, 1.6fr),
  inset: 4pt,
  table.header([*topic*], [*chapter*], [*cost or guarantee*], [*proof*]),
  ..topics.map(r => (
    [#r.topic],
    chapter-label(r.chapter),
    [#r.cost],
    [#r.proof],
  )).flatten(),
)

#diagram([where the 63 topics landed, none unmapped], length: 13pt, {
  cdraw.content((11.0, 9.0), [63 topics, 20 chapters, 0 unmapped], size: 6.5pt)
  cdraw.line((0.5, 1.6), (22.0, 1.6), stroke: luma(100))
  let bar(x, h, count, label, hot) = {
    cdraw.rect((x, 1.6), (x + 3.0, 1.6 + h), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.5, 1.6 + h + 0.45), [#count], size: 6pt)
    cdraw.content((x + 1.5, 0.4), [#label], size: 6pt)
  }
  bar(1.0, 3.1, [11], [containers], false)
  bar(5.4, 6.4, [23], [engines], true)
  bar(9.8, 3.9, [14], [stores], false)
  bar(14.2, 3.1, [11], [testing], false)
  bar(18.6, 1.1, [4], [capstone], false)
})

== pinned sources

#table(
  columns: (1.7fr, 2.3fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

#diagram([the 29 pinned sources by origin, each with its access date], length: 13pt, {
  let row(y, label, n) = {
    cdraw.content((3.8, y), [#label], size: 6pt)
    cdraw.rect((8.0, y - 0.35), (8.0 + n * 1.5, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((8.6 + n * 1.5, y), [#n], size: 6pt)
  }
  row(8.3, [sqlite.org], 11)
  row(7.2, [duckdb.org], 4)
  row(6.1, [docs.docker.com], 3)
  row(5.0, [docs.nats.io], 3)
  row(3.9, [pkg.go.dev], 3)
  row(2.8, [github.com], 1)
  row(1.7, [install.duckdb.org], 1)
  row(0.6, [artifacts.duckdb.org], 1)
  row(-0.5, [mongodb.com], 1)
  row(-1.6, [htmx.org], 1)
  cdraw.content((14.0, -2.7), [29 sources, each with an access date], size: 6.5pt)
})

#callout("note", "the two gates, closed", [
  `make verify` runs this book's 103 docker-free go tests, 61 in the
  capstone module and 42 in the probe module, the probes splitting
  into 25 compiler-free tests under plain `go test ./...` and 17
  duckdb-tagged tests behind the pinned dll, and it compiles every
  listing you have read against the files that passed them.
  `make verify-infra-docker` adds the linux race stage for the
  analytics module and runs the four tagged tests against the composed
  system, absent daemon a red with instructions. Both were green on
  2026-09-20, the day this chapter was updated, which is the only
  kind of claim this series makes.
])
