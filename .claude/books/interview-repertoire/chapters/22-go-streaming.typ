#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= go streaming: jetstream batch pipelines

The streaming round is durable messaging with redelivery
semantics, and the only honest answer is a running one. The
`ch22-go` module runs a real nats server in-process, jetstream
file storage, a batch producer, a durable consumer, nak
redelivery, and a restart test that kills and restarts the broker
against the same store. 3 tests, each heavyweight, under
`make verify`.

== the embedded server, and two windows bugs [TDD]

The server is a library: options, `go srv.Start()`, wait for
readiness. The listing is short because the lesson is in the
comments, both learned from real red runs on this tree:

#listing("interview-repertoire/samples/ch22-go/server.go", first: 14, last: 44, caption: [embedded server with file storage, forward slashes, real durations])

#diagram([options, start, wait ready, and the two windows bugs], length: 13pt, {
  // the startup line, with the two bug stories hanging under it
  let st(x0, name, role) = {
    cdraw.rect((x0, 6.9), (x0 + 5.0, 8.8), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.5, 8.35), [#name], size: 6.5pt)
    cdraw.content((x0 + 2.5, 7.4), [#role], size: 6pt)
  }
  st(1.0, "options", "store dir, slashes")
  st(8.0, "go srv.Start()", "file storage")
  st(15.0, "wait ready", "ReadyForConnections")
  cdraw.line((6.0, 7.85), (8.0, 7.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 7.85), (15.0, 7.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.0, 6.9), (7.0, 5.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((1.0, 3.0), (13.0, 5.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((7.0, 5.15), [a backslash store dir stalls], size: 6pt)
  cdraw.content((7.0, 4.15), [before the listener opens], size: 6pt)
  cdraw.content((7.0, 3.15), [ToSlash fixes it at the edge], size: 6pt)
  cdraw.line((17.5, 6.9), (17.5, 5.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((14.2, 3.0), (23.0, 5.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((18.6, 5.15), [10_000 = microseconds,], size: 6pt)
  cdraw.content((18.6, 4.15), [not ten seconds: the], size: 6pt)
  cdraw.content((18.6, 3.15), [wait returns too early], size: 6pt)
  cdraw.content((11.5, 1.8), [durations are nanoseconds: read the units], size: 6pt)
})

Windows taught two lessons worth telling in an interview as bug
stories. A backslash store dir made the jetstream file store stall
before the listener opened, silent under `NoLog`, and
`filepath.ToSlash` at the options boundary is the fix. And
`srv.ReadyForConnections(10_000)` is not ten seconds, a
`time.Duration` is nanoseconds, so it was ten microseconds and the
wait returned before the server started. Unit-bearing types catch
this at review time only if the reviewer reads the units.

== batch produce, durable consume [TDD]

The producer stamps a `Nats-Msg-Id` for deduplication and
publishes the batch. The worker binds a durable consumer, fetches
in batches, acks successes, and naks failures straight back for
redelivery:

#listing("interview-repertoire/samples/ch22-go/pipeline.go", first: 13, last: 42, caption: [the batch producer with dedupe ids])

#listing("interview-repertoire/samples/ch22-go/pipeline.go", first: 60, last: 104, caption: [the durable worker: upsert the consumer, fetch, ack, nak])

#diagram([stamp for dedupe, bind the durable, ack or nak], length: 13pt, {
  // produce into the stream, the durable worker under it, the two outcomes
  cdraw.rect((0.6, 6.4), (5.6, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.1, 7.9), [producer], size: 6.5pt)
  cdraw.content((3.1, 6.95), [Nats-Msg-Id], size: 6pt)
  cdraw.line((5.6, 7.4), (8.0, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.8, 7.9), [dedupe], size: 6pt)
  cdraw.rect((8.0, 6.4), (13.4, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((10.7, 7.9), [stream], size: 6.5pt)
  cdraw.content((10.7, 6.95), [file storage], size: 6pt)
  cdraw.line((13.4, 7.4), (14.6, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.6, 6.4), (21.6, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((18.1, 7.9), [durable], size: 6.5pt)
  cdraw.content((18.1, 6.95), [explicit config], size: 6pt)
  cdraw.line((18.1, 6.4), (18.1, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.4, 4.6), (19.8, 5.6), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((18.1, 5.1), [fetch], size: 6pt)
  cdraw.line((17.2, 4.6), (16.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.0, 4.6), (20.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.4, 3.0), (18.0, 4.0), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((16.2, 3.5), [ack: done], size: 6pt)
  cdraw.rect((18.8, 3.0), (22.6, 4.0), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((20.7, 3.5), [nak: redeliver], size: 6pt)
  cdraw.content((11.7, 1.9), [a poison payload fails twice, succeeds third], size: 6pt)
  cdraw.content((11.7, 0.9), [restarts bind to the same durable], size: 6pt)
})

The consumer upsert is deliberate: the durable is created with
explicit config once, and restarts bind to it, because binding
with mismatched inline options is an error, another lesson from a
red run. The nak test is observable behavior, a poison payload
fails twice and succeeds on the third attempt, and the suite
counts the attempts.

== the offset is the ack floor [TDD]

`Inspect` reads the two numbers that explain durable semantics,
the stream's message count and the consumer's pending and ack
floor:

#listing("interview-repertoire/samples/ch22-go/pipeline.go", first: 107, last: 133, caption: [stream state, pending count, the ack floor])

The restart test is the chapter's spine. Produce four, consume
two, stop the worker mid-stream, shut the broker down completely,
start a new broker against the same store directory. The stream
still holds four messages, the durable still exists, the ack floor
is still 2, and a fresh worker receives exactly the unacked tail.
That is the "offset" of the kafka vocabulary, persisted by the
broker per consumer, and the kafka comparison is the paragraph to
have ready: kafka exposes the offset and lets the consumer commit
it, jetstream tracks delivery per consumer with explicit acks,
both redeliver on timeout or nack, and the choice between them is
ecosystem and operations, topic partitioning and mirror making
versus jetstream's simpler single-binary model. Book 12's
#xref-to("infrastructure", "jetstream") chapter carries the full
comparison against its own running capstone.

#diagram([kill the broker, restart: the floor survives, the tail is redelivered], length: 13pt, {
  // the restart timeline with the two surviving numbers above it
  cdraw.line((4.0, 5.2), (21.0, 5.2), stroke: luma(180))
  cdraw.content((12.5, 5.6), [stream holds 4], size: 6pt)
  cdraw.line((9.0, 4.2), (21.0, 4.2), stroke: luma(180))
  cdraw.content((15.0, 4.6), [ack floor: 2], size: 6pt)
  cdraw.content((11.5, 7.0), [the unacked tail: exactly messages 3 and 4], size: 6pt)
  cdraw.content((20.0, 6.0), [delivers 3, 4], size: 6pt)
  cdraw.line((1.5, 3.0), (22.5, 3.0), stroke: luma(100), mark: (end: ">"))
  for x in (4.0, 9.0, 14.5, 20.0) {
    cdraw.circle((x, 3.0), radius: 0.1, fill: luma(60))
  }
  cdraw.content((4.0, 2.5), [produce 4], size: 6pt)
  cdraw.content((9.0, 2.5), [consume 2], size: 6pt)
  cdraw.content((14.5, 2.5), [broker restart], size: 6pt)
  cdraw.content((20.0, 2.5), [fresh worker], size: 6pt)
  cdraw.content((11.5, 1.4), [kafka: the consumer commits the offset], size: 6pt)
  cdraw.content((11.5, 0.5), [jetstream: the broker tracks the ack floor], size: 6pt)
})

sources: nats jetstream concepts, durable consumers, ack floors,
redelivery, from docs.nats.io, accessed 2026-09-09 and pinned in
the sources appendix. Verified by `go vet` and `go test` through
`make verify` against an embedded nats-server v2.14.6 with
nats.go v1.53.1, 3 tests in `ch22-go`.
