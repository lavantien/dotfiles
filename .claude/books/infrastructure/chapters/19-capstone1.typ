#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge
#import "../manifest.typ": infrastructure

= capstone part 1: services and topology

Everything before this chapter was one layer at a time. The capstone
composes them: six Go services, one broker, one database server, two
embedded engines, one connection each, brought up by a single compose
command. This chapter
is the topology and the service interiors, the next is the interface
on top.

== the shape

#table(
  columns: (auto, 1.5fr, 1.7fr, 1.2fr),
  inset: 4pt,
  table.header([*service*], [*speaks*], [*does*], [*owns*]),
  [chat], [chat.send, chat.recent, publishes chat.room.\<room\>], [validates, persists, publishes after commit], [the sqlite file],
  [presence], [presence.beat, presence.online, presence.events], [kv puts with ttl, roster, join and leave sweep], [the kv bucket],
  [notify], [durable notifiers on CHAT], [fans notifications to everyone but the sender], [no state],
  [history], [durable historians on CHAT, history.stats], [upserts documents, aggregates], [the mongo collection],
  [analytics], [durable analysts on CHAT, analytics.stats], [upserts rows into duckdb, sql aggregates], [the duckdb file],
  [web], [http on 8080, all fragments], [the only public surface, per user inboxes], [nothing durable],
)

#flow(
  [the system, one message's path],
  node((0, 0), [browser, htmx]),
  node((1.5, 0), [web :8080]),
  node((3.0, 0), [nats]),
  node((4.6, 1.0), [chat, sqlite]),
  node((4.6, -1.0), [CHAT stream]),
  node((6.2, -1.0), [notify]),
  node((6.2, 1.0), [history, mongo]),
  node((6.2, -2.2), [analytics, duckdb]),
  node((4.6, 0), [presence, kv]),
  edge((0, 0), (1.5, 0), "-|>"),
  edge((1.5, 0), (3.0, 0), "-|>"),
  edge((3.0, 0), (4.6, 1.0), "-|>"),
  edge((4.6, 1.0), (4.6, -1.0), "-|>"),
  edge((4.6, -1.0), (6.2, -1.0), "-|>"),
  edge((4.6, -1.0), (6.2, 1.0), "-|>"),
  edge((4.6, -1.0), (6.2, -2.2), "-|>"),
  edge((3.0, 0), (4.6, 0), "-|>"),
)

The load-bearing decisions are three. Every service boundary is a
subject, so services never address each other, the broker does.
Everything durable is behind a service that owns exactly one store,
one file for chat, one duckdb file for analytics, one bucket for
presence, one collection for history, so no two writers share a lock
domain. And the web tier owns nothing durable at all, which is why it
can be scaled, restarted, or replaced without a migration in sight.

== the wire, one page

Every request and reply crossing those subjects is one of six shapes,
defined once:

#listing("infrastructure/capstone/internal/wire/wire.go", first: 10, last: 17, caption: [the message, the unit the whole system moves])

#diagram([the six wire shapes, one type per subject], length: 13pt, {
  cdraw.content((11.6, 8.4), [six shapes, sixty lines], size: 6.5pt)
  let cell(x0, y, label) = {
    cdraw.rect((x0, y), (x0 + 6.4, y + 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 3.2, y + 0.6), [#label], size: 6pt)
  }
  cell(0.0, 6.4, [message])
  cell(8.4, 6.4, [send req + reply])
  cell(16.8, 6.4, [recent request])
  cell(0.0, 4.8, [beat request])
  cell(8.4, 4.8, [presence row])
  cell(16.8, 4.8, [stats blocks])
  cdraw.content((11.6, 2.9), [one type per subject], size: 6.5pt)
  cdraw.content((11.6, 1.8), [one place to read the wire], size: 6pt)
})

The full set lives in sixty lines: the send and recent requests, the
heartbeat, the roster entry, and the stats blocks. One type per
subject keeps the contract tests from #xref-to("infrastructure",
"mocks") meaningful, because there is exactly one place to read what
crosses the wire.

== the chat interior

The chat service is the book's sqlite argument in miniature. One
transaction resolves or inserts the names, inserts the message, and
commits. Only after the commit does the publish happen:

#listing("infrastructure/capstone/internal/chat/chat.go", first: 92, last: 135, caption: [validate, one transaction, then publish the committed shape])

The order is the concurrency contract: anything reacting to the event
can read the row, a property the chat suite pins directly by querying
inside the subscription callback. Reversing the two lines would create
a consumer that races its own database, the kind of bug that shows up
as a flaky downstream test and nowhere else.

The reads walk the normalized join from
#xref-to("infrastructure", "sqlite-schema"):

#listing("infrastructure/capstone/internal/chat/chat.go", first: 169, last: 204, caption: [newest of one room off the (room_id, id) index, reversed for the reader])

#diagram([send is a strict sequence, and the publish waits for the commit], length: 13pt, {
  cdraw.rect((0.0, 6.6), (4.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.2, 7.1), [validate], size: 6.5pt)
  cdraw.line((4.4, 7.1), (5.8, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.8, 6.6), (16.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.2, 7.1), [one transaction: names, insert], size: 6pt)
  cdraw.line((16.6, 7.1), (18.0, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((18.0, 6.6), (23.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((20.7, 7.1), [commit], size: 6.5pt)

  cdraw.line((20.7, 6.6), (18.7, 4.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((14.0, 3.4), (23.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.7, 3.9), [publish committed shape], size: 6pt)
  cdraw.content((7.0, 3.9), [only after commit], size: 6.5pt)

  cdraw.content((11.0, 2.2), [reads: the (room_id, id) index], size: 6pt)
  cdraw.content((11.0, 1.1), [newest first, reversed for the reader], size: 6pt)
})

== the analytics interior, the columnar twin

History mirrors the stream into mongo documents and answers
`history.stats` with pipelines. Analytics is the same shape pointed at
the other engine: its own durable consumer over the same CHAT stream,
rows landing in one duckdb file, stats answered by sql the engine
folds vectorized. The store has no interface seam, because the engine
itself is cheap to embed, so the tests run the real sql against a real
file and never a fake of it. The whole schema and query set is
constants:

#listing("infrastructure/capstone/internal/analytics/store.go", first: 27, last: 87, caption: [one table mirroring the wire message, an upsert by id, and the four aggregations as plain sql])

The insert upserts by message id for the same reason mongo's does: a
redelivery after a crash between insert and ack rewrites the same row
instead of appending a duplicate. Open is where the engine gets its
seat:

#listing("infrastructure/capstone/internal/analytics/store.go", first: 95, last: 125, caption: [open: threads=2 in the dsn, one pooled connection, and a schema version that is refused when newer than the code])

`threads=2` is the honest size for a service sharing a machine with
five peers, and the schema version stamp is the migrate discipline
from #xref-to("infrastructure", "migrations") in miniature: a file
carrying anything newer than this code understands is refused, not
guessed at. The stats side returns the same `wire.Stats` shape history
returns, so the web tier renders both engines identically:

#listing("infrastructure/capstone/internal/analytics/store.go", first: 155, last: 182, caption: [stats wiring: count, top talkers and rooms, the busiest hour bucket, top words])

The service half is a mirror of history's consumer with its own name.
The durable name lives in this package, so `internal/jet` stays
untouched and a new reader adds its own offset instead of editing the
shared one:

#listing("infrastructure/capstone/internal/analytics/service.go", first: 22, last: 40, caption: [the analysts durable, its ack wait, and the service holding store, consumer, responder])

#listing("infrastructure/capstone/internal/analytics/service.go", first: 42, last: 78, caption: [new: ensure the chat stream, create or update the analysts durable, serve analytics.stats, consume])

#diagram([three durables fan off one stream, each with its own offset], length: 13pt, {
  cdraw.rect((0.0, 4.6), (7.2, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.6, 6.05), [the CHAT stream], size: 6.5pt)
  cdraw.content((3.6, 5.0), [one append only log], size: 6pt)

  let reader(x0, name, store) = {
    cdraw.line((7.2, 5.6), (x0, 5.6), stroke: luma(100), mark: (end: ">>"))
    cdraw.rect((x0 + 0.1, 4.6), (x0 + 5.3, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.7, 6.05), [#name], size: 6.5pt)
    cdraw.content((x0 + 2.7, 5.0), [#store], size: 6pt)
  }
  reader(8.0, [notifiers], [no state])
  reader(14.2, [historians], [the mongo collection])
  reader(20.4, [analysts], [the duckdb file])

  cdraw.content((12.0, 3.4), [each durable is its own cursor], size: 6.5pt)
  cdraw.content((12.0, 2.3), [analytics can lag or replay, history never notices], size: 6pt)
  cdraw.content((12.0, 1.2), [a rebuild means a new durable, zero migration], size: 6pt)
})

The handler is the ack discipline from
#xref-to("infrastructure", "jetstream") applied once more:

#listing("infrastructure/capstone/internal/analytics/service.go", first: 90, last: 106, caption: [unparseable now means unparseable on every retry, so ack it; a failed insert naks with delay])

The pair of lines at the top is the whole poison message policy: an
unparseable body would fail identically on every redelivery, so it is
acknowledged and dropped, while a store failure is a `NakWithDelay`,
spaced by `AckWait`, so the retry budget burns slowly.

== boot, shared by all six

Every main is the same dozen lines, connect with retries, construct,
serve healthz, park on signal, close in reverse, and the shared parts
live in one package:

#listing("infrastructure/capstone/internal/boot/boot.go", first: 22, last: 37, caption: [dial with retries: a service starting beside its broker still comes up])

#diagram([the shared main, one timeline every service walks], length: 13pt, {
  let step(y, label) = {
    cdraw.rect((0.0, y), (10.0, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((5.0, y + 0.5), [#label], size: 6.5pt)
  }
  step(8.0, [connect, bounded retries])
  cdraw.line((5.0, 8.0), (5.0, 7.5), stroke: luma(100), mark: (end: ">>"))
  step(6.4, [construct])
  cdraw.line((5.0, 6.4), (5.0, 5.9), stroke: luma(100), mark: (end: ">>"))
  step(4.8, [serve healthz])
  cdraw.line((5.0, 4.8), (5.0, 4.3), stroke: luma(100), mark: (end: ">>"))
  step(3.2, [park on signal])
  cdraw.line((5.0, 3.2), (5.0, 2.7), stroke: luma(100), mark: (end: ">>"))
  step(1.6, [close in reverse])

  cdraw.content((17.0, 8.5), [depends_on orders the graph], size: 6pt)
  cdraw.content((17.0, 7.4), [reconnect-anyway survives], size: 6pt)
  cdraw.content((17.0, 6.3), [broker restarts], size: 6pt)
  cdraw.content((5.0, 0.4), [the same dozen lines, six mains], size: 6pt)
})

The retry matters in compose specifically: `depends_on` orders
readiness for the declared graph, but reconnect-anyway is what keeps
a broker restart from becoming a service restart.

#callout("note", "where the failure modes went", [
  Each mechanism this capstone leans on failed somewhere first: the
  nak that burned its budget and the ttl that watches cannot see in
  #xref-to("infrastructure", "jetstream"), the commit that waits for
  readers in #xref-to("infrastructure", "sqlite-transactions"). The
  topology does not add new failure modes, it composes known ones,
  and the suite is arranged so each keeps its own test.
])

sources: the compose file and the code listings above are the
specification. Verified by the full module suite, 61 tests in the
duckdb lane, and the docker-gated end to end walk, green 2026-09-20
under `make verify` and `make verify-infra-docker`.
