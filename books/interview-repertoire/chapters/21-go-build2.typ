#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= go build part 2: storefront and live features

Part 2 bolts the live half onto part 1's shapes: a storefront with
transactional stock, a server-to-client event feed on the same
service, and a deploy story that swaps versions without dropping
requests. The `ch21-go` module, 8 tests under `make verify`.

== the storefront and the reservation transaction [TDD]

Inventory in sqlite, and the operation that matters is reserve:
one transaction checks the count and inserts the reservation, so
two concurrent reserves cannot both take the last unit:

#listing("interview-repertoire/samples/ch21-go/storefront.go", first: 105, last: 144, caption: [the reserve transaction, check then decrement then record, then emit])

#diagram([check, take, record in one transaction: no double sell], length: 13pt, {
  // the reserve chain, the second caller waiting outside it
  let st(x0, name, role) = {
    cdraw.rect((x0, 6.2), (x0 + 4.0, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.0, 7.6), [#name], size: 6.5pt)
    cdraw.content((x0 + 2.0, 6.6), [#role], size: 6pt)
  }
  st(0.7, "begin", "the write tx")
  st(5.25, "check", "stock >= 1")
  st(9.8, "take", "stock - 1")
  st(14.35, "record", "reservation")
  st(18.9, "commit", "unit gone")
  cdraw.line((4.7, 7.1), (5.25, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.25, 7.1), (9.8, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.8, 7.1), (14.35, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.35, 7.1), (18.9, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.7, 4.4), (4.7, 5.2), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((2.7, 4.8), [a second reserve], size: 6pt)
  cdraw.line((2.7, 5.2), (2.7, 6.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((7.6, 5.7), [waits, then re-checks], size: 6pt)
  cdraw.content((11.8, 3.2), [one pooled connection queues the writers], size: 6pt)
  cdraw.content((11.8, 2.2), [30 goroutines, 10 units: exactly 10 succeed], size: 6pt)
})

The oversell test is the honest one: 30 goroutines reserve against
a 10 unit stock and exactly 10 succeed, the stock lands at zero,
and no reservation exists for a unit that was not there. The
sqlite note to narrate: one pooled connection, `SetMaxOpenConns(1)`,
makes concurrent writers queue on the single writer sqlite is,
instead of racing into busy errors, the standard go-plus-sqlite
answer this suite learned by failing first.

== the feed, bolted on step by step [TDD]

The realtime feature is one endpoint on the same service, and the
steps are worth narrating in order because the interview asks for
the process. Step one, the storefront already emits every change
through `emit`, stamped with a sequence number from the database.
Step two, the feed holds a bounded history and a subscriber list:

#listing("interview-repertoire/samples/ch21-go/feed.go", first: 6, last: 34, caption: [bounded history, publish to every subscriber without blocking])

#diagram([bounded history plus subscribers: replay after since, then tail], length: 13pt, {
  // emit appends to the ring and fans out; the client replays then tails
  cdraw.rect((0.8, 6.8), (3.4, 7.8), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((2.1, 7.3), [emit], size: 6.5pt)
  cdraw.line((3.4, 7.3), (4.6, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.7, 8.6), [bounded history], size: 6.5pt)
  for i in range(6) {
    let x0 = 4.6 + i * 2.05
    cdraw.rect((x0, 7.0), (x0 + 1.9, 7.8), fill: if i == 5 { luma(205) } else { luma(235) }, stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 0.95, 7.4), [s#(i + 1)], size: 6pt)
  }
  cdraw.line((16.75, 7.4), (18.4, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.4, 6.4), (22.8, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((20.6, 7.6), [client], size: 6.5pt)
  cdraw.content((20.6, 6.75), [since = s3], size: 6pt)
  cdraw.line((2.1, 6.8), (2.1, 6.2), (8.7, 6.2), stroke: luma(150))
  for x in (2.3, 5.5, 8.7) {
    cdraw.line((x, 6.2), (x, 5.2), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((12.6, 6.5), [fan-out, never blocking], size: 6pt)
  cdraw.content((5.5, 5.6), [subscribers], size: 6.5pt)
  for (x0, t) in ((1.0, "sub a"), (4.2, "sub b"), (7.4, "sub c")) {
    cdraw.rect((x0, 4.2), (x0 + 2.6, 5.0), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 1.3, 4.6), [#t], size: 6pt)
  }
  cdraw.line((20.6, 6.4), (20.6, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.4, 5.55), [replay after since], size: 6pt)
  cdraw.line((20.6, 5.1), (20.6, 4.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.4, 4.3), [then tail live], size: 6pt)
  cdraw.content((11.5, 2.6), [flush per event, end on hangup], size: 6pt)
  cdraw.content((11.5, 1.6), [sse one-way and cheap; websockets bidirectional], size: 6pt)
})

Step three, the endpoint is `text/event-stream`, a replay of
everything after the client's `since` parameter, then a live tail,
flushing per event and ending when the client hangs up:

#listing("interview-repertoire/samples/ch21-go/storefront.go", first: 223, last: 247, caption: [the SSE endpoint: replay, tail, flush, hangup])

The stream test holds the connection open over real http, watches
the replay arrive without any publish, then sees a live stock
update flow down the open socket. The boundary to volunteer: sse
is one-directional and cheap, websockets are bidirectional at
protocol cost, chapter 18 implemented both ends of the latter, and
the choice is whether the client ever needs to push on the same
channel.

== graceful shutdown and the live deploy [TDD]

`Shutdown` stops accepting and waits for in-flight requests, and
the test proves the ordering: a slow request starts, shutdown
begins and does not return, the request finishes with its body
intact, shutdown completes, and new connections are refused:

#listing("interview-repertoire/samples/ch21-go/storefront.go", first: 254, last: 288, caption: [the deployable front swaps handlers; GracefulShutdown drains with a timeout])

#diagram([swap the front under traffic; drain, then refuse], length: 13pt, {
  // left: the version swap; right: the shutdown state machine
  cdraw.content((6.0, 8.8), [the swap], size: 6.5pt)
  cdraw.rect((1.2, 7.3), (5.2, 8.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.2, 7.8), [v1 answers], size: 6pt)
  cdraw.line((5.2, 7.8), (6.8, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 7.3), [swap], size: 6pt)
  cdraw.rect((6.8, 7.3), (10.8, 8.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((8.8, 7.8), [v2 answers], size: 6pt)
  cdraw.content((6.0, 5.9), [requests in flight keep], size: 6pt)
  cdraw.content((6.0, 4.9), [answering through the swap], size: 6pt)
  cdraw.content((17.5, 9.9), [the shutdown], size: 6.5pt)
  cdraw.rect((13.6, 7.6), (21.4, 9.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 8.9), [serving], size: 6pt)
  cdraw.content((17.5, 7.95), [stops accepting], size: 6pt)
  cdraw.line((17.5, 7.6), (17.5, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.6, 5.0), (21.4, 6.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 6.3), [draining], size: 6pt)
  cdraw.content((17.5, 5.3), [in-flight finish], size: 6pt)
  cdraw.line((17.5, 5.0), (17.5, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.6, 2.4), (21.4, 4.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 3.7), [refusing], size: 6pt)
  cdraw.content((17.5, 2.7), [new connections], size: 6pt)
  cdraw.content((11.5, 1.2), [the readiness probe is the /version probe generalized], size: 6pt)
})

The deploy test runs one listener behind a swappable front
handler, answers `/version` as v1, swaps to v2 under live traffic,
and the next request sees v2 while storefront routes keep
answering through the swap. The production sentence that finishes
it: the same shape at process scale is the kubernetes rolling
update, new pods up, old pods drained, and the readiness probe is
the `/version` probe generalized.

sources: verified by `go vet` and `go test` through `make verify`,
8 tests in `ch21-go` over sqlite 3.53 through modernc.org/sqlite
v1.58.0. Deploy and drain doctrine floors to
#xref-to("infrastructure", "containers") for the signal and pid 1
mechanics.
