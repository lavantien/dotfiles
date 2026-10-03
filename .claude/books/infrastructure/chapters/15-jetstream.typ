#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= jetstream: streams, consumers, kv, kafka compared

Core NATS forgets. JetStream is the layer that remembers: a stream
declares a set of subjects the server durably records, and consumers
read that recording at their own pace with their own position. One
small config object turns the capstone's fire-and-forget chat publish
into the system's durable log:

#listing("infrastructure/capstone/internal/jet/chat.go", first: 16, last: 37, caption: [the whole jetstream agreement of the capstone: one stream, two durables, in one file])

The chat service keeps publishing to `chat.room.general` exactly as
before. The stream captures it because the subjects match, and two
services read the same log independently, each with its own offset.
The analytics service adds a third durable of its own,
#xref-to("infrastructure", "capstone1").

== durable consumers are offsets with a name

A consumer with a durable name holds its position on the server. That
position is the ack floor, the earliest message not yet acknowledged:
everything below it is settled, and acking the floor message advances
it. The notify service is one, and its handler is the whole delivery
discipline:

#listing("infrastructure/capstone/internal/notify/notify.go", first: 89, last: 117, caption: [settle the message: fan out and ack, or delay the nak and retry])

Two hard-won details live in those lines. The malformed payload is
acked, not retried, because it will never parse better, and a
poisoned consumer is worse than a dropped bad message. And the retry
is `NakWithDelay`, not a plain `Nak`, and the reason is a debugging
story worth telling: the first implementation used a plain nak, and
the redelivery test burned through the entire delivery budget
(`MaxDeliver`, the consumer config's redelivery cap, pinned at 50) in
two milliseconds. A nak means redeliver immediately, so a dependency that
is down for half a second eats every retry at once. Delaying the nak
spaces redeliveries by the ack wait, which is what the failing test
actually wanted:

#listing("infrastructure/capstone/internal/notify/notify_test.go", first: 131, last: 163, caption: [presence down, then up: the delayed nak redelivers and the message survives])

The history service is the second durable over the same stream, same
shape, different name, and its restart test proves the offset is
server side: the service closes with the first message acked, a second
message lands while nobody is consuming, and the restarted service
receives only the second.

#flow(
  [one stream, three durables, three independent offsets],
  node((0, 0), [chat, publishes]),
  node((1.6, 0), [CHAT stream, chat.room.>]),
  node((3.3, 1.0), [notifiers, floor 5]),
  node((3.3, -1.0), [historians, floor 3]),
  node((3.3, -3.0), [analysts, its own floor]),
  node((4.9, 1.0), [fanout]),
  node((4.9, -1.0), [mongo]),
  node((4.9, -3.0), [duckdb]),
  edge((0, 0), (1.6, 0), "-|>"),
  edge((1.6, 0), (3.3, 1.0), "-|>"),
  edge((1.6, 0), (3.3, -1.0), "-|>"),
  edge((1.6, 0), (3.3, -3.0), "-|>"),
  edge((3.3, 1.0), (4.9, 1.0), "-|>"),
  edge((3.3, -1.0), (4.9, -1.0), "-|>"),
  edge((3.3, -3.0), (4.9, -3.0), "-|>"),
)

== kv: a bucket with a ttl

A key value bucket is a stream wearing an api, keys as subjects,
values as payloads. Presence is one: heartbeats put the room under
the user key, and the bucket's TTL expires stale users server side:

#listing("infrastructure/capstone/internal/presence/presence.go", first: 134, last: 140, caption: [a heartbeat is one put, and the put refreshes the ttl])

The chapter's second debugging story came from trusting the watch api
here. A KV watch delivers puts and deletes, but a TTL expiry is
neither: it is the stream quietly dropping an aged message, and the
watcher saw nothing, tested nothing, shipped nothing. The fix is the
sweep, a periodic roster diff that publishes the joins and leaves the
watch cannot see:

#listing("infrastructure/capstone/internal/presence/presence.go", first: 87, last: 122, caption: [reconcile, at a third of the ttl: what appeared is a join, what vanished is a leave])

#diagram([a bucket with a ttl: the silent drop, and the sweep that sees it], length: 13pt, {
  cdraw.content((11.0, 8.8), [a bucket is a stream wearing an api], size: 6.5pt)
  cdraw.rect((0.0, 6.4), (8.0, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 6.9), [put, ttl refreshes], size: 6.5pt)
  cdraw.line((8.0, 6.9), (9.4, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.4, 6.4), (20.2, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((14.8, 6.9), [expiry: the stream drops it], size: 6.5pt)

  cdraw.rect((0.0, 3.8), (8.6, 4.8), fill: white, stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((4.3, 4.3), [the watch sees nothing], size: 6pt)
  cdraw.line((8.6, 4.3), (10.0, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.0, 3.8), (18.6, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((14.3, 4.3), [sweep at ttl/3 diffs], size: 6pt)

  cdraw.content((11.0, 2.6), [publishes the joins and leaves], size: 6pt)
  cdraw.content((11.0, 1.5), [detection latency = the cadence], size: 6pt)
})

The pattern generalizes past NATS: any TTL system whose expiry is
invisible to notification needs a reconciler, and the reconciler's
cadence is the detection latency you signed up for.

== kafka, compared honestly

The shapes map almost one to one. Kafka's partitioned log is the
stream, the consumer group is the durable consumer, committed offsets
are the ack floor, and compaction is what a KV bucket's per-key
history is doing. The differences are in defaults and operations:
kafka's partition count is fixed at topic creation and keys route to
partitions, so parallelism is planned up front, while a JetStream
stream parallelizes through consumers and leaves subject structure to
the application. Kafka's retention is the product, built for long
replay and heavy fan-in at high throughput; JetStream's defaults
favor smaller systems that already speak NATS. The capstone
implements the NATS side and treats kafka as this paragraph, because
the second implementation would teach the api, and the api is not the
hard part, the delivery semantics are, and those are what the tests
here pin.

#diagram([kafka to jetstream: the shapes map, the defaults differ], length: 13pt, {
  cdraw.content((6.0, 8.9), [kafka], size: 6.5pt)
  cdraw.content((18.0, 8.9), [jetstream], size: 6.5pt)
  cdraw.line((0.6, 8.3), (22.0, 8.3), stroke: luma(220))

  let pair(y, k, j) = {
    cdraw.content((6.0, y), [#k], size: 6pt)
    cdraw.content((12.0, y), [=], size: 6pt)
    cdraw.content((18.0, y), [#j], size: 6pt)
  }
  pair(7.6, [partitioned log], [stream])
  pair(6.4, [consumer group], [durable consumer])
  pair(5.2, [committed offsets], [ack floor])
  pair(4.0, [compaction], [per-key kv history])

  cdraw.line((0.6, 3.3), (22.0, 3.3), stroke: luma(220))
  cdraw.content((11.0, 2.3), [partitions fixed up front vs consumers scale], size: 6pt)
  cdraw.content((11.0, 1.2), [retention as product vs smaller defaults], size: 6pt)
})

#callout("warning", "exactly once is a pipeline property, not a flag", [
  The consumer acks after the fanout, so a crash between publish and
  ack redelivers, and a recipient can see a notification twice. The
  capstone accepts this because notifications are idempotent to read.
  The history consumer pays for stronger semantics instead, the
  upsert keyed on message id from #xref-to("infrastructure", "mongo"),
  which is the standard answer: make the sink idempotent, and
  at-least-once delivery is enough.
])

sources: docs.nats.io jetstream concepts, subjects, and the kv
developer page, accessed 2026-09-10, and the nats.go jetstream
package api verified against the vendored module source, v1.53.1.
Verified by the notify suite, 5 tests, the history suite, 5 tests,
and the presence suite, 4 tests, green under `make verify` 2026-09-10.
