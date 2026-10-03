#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= system design answers

The system design round rewards structure over volume: name the
requirements, sketch the topology, state the bottleneck and the fix,
and answer the follow-up with a tradeoff instead of a product. This
chapter drills the spoken answers with the two topologies the
inventory asks for by name, and every streaming claim floors to
#xref-to("infrastructure", "jetstream"), whose capstone runs the
real thing.

== scaling with and without the cloud [DRILL]

Without the cloud the ladder is: one box, then a load balancer in
front of two boxes, then a shared database behind them, then read
replicas, then cache layers, then a queue to absorb writes, then
sharding when the single writer saturates. Every rung is a
purchase order and an operational liability.

With the cloud the ladder is the same and the purchase order
disappears: managed load balancer, autoscaling groups, managed
database with replicas one flag away, managed cache, managed
queue. The honest close, the one interviewers wait for: the cloud
changes the economics of the ladder, not the ladder. The scaling
problems, the shared database, the thundering herd, the fan-out
write storm, exist in both worlds, and the cloud rents you the
rungs, it does not climb them for you.

#diagram([the scaling ladder: every rung is the same, cloud or not], length: 13pt, {
  // a literal ladder: rails and rungs, the managed versions beside it
  cdraw.line((8.0, 1.5), (8.0, 9.0), stroke: luma(160))
  cdraw.line((14.5, 1.5), (14.5, 9.0), stroke: luma(160))
  let rung(y, t) = {
    cdraw.rect((8.0, y), (14.5, y + 0.7), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((11.25, y + 0.35), [#t], size: 6pt)
  }
  rung(1.8, "one box")
  rung(2.8, "load balancer")
  rung(3.8, "shared database")
  rung(4.8, "read replicas")
  rung(5.8, "cache layer")
  rung(6.8, "write queue")
  rung(7.8, "sharding")
  cdraw.content((18.8, 8.4), [with the cloud:], size: 6pt)
  cdraw.content((18.8, 7.3), [managed balancer,], size: 6pt)
  cdraw.content((18.8, 6.2), [managed database,], size: 6pt)
  cdraw.content((18.8, 5.1), [managed cache, queue], size: 6pt)
  cdraw.content((11.5, 0.6), [the cloud rents the rungs, it does not climb them], size: 6pt)
})

== gateway, reverse proxy, kubernetes [DRILL]

An api gateway is the policy edge: authentication, rate limiting,
routing, tls termination, request shaping. A reverse proxy is the
mechanism underneath, nginx, envoy, caddy, forwarding inbound
connections to upstream services. Kubernetes is the substrate:
pods for units, deployments for replica sets with rolling updates,
services for stable virtual ips, ingress for the http policy edge.
Say the composition: an ingress or gateway product fronting
services, services load balancing across deployment pods, and the
gateway is where cross-cutting policy lives so the services do not
each reimplement it.

#diagram([ingress fronts services, services balance across pods], length: 13pt, {
  // the edge, the service, the pods, and the deployment under them
  cdraw.rect((3.0, 7.3), (20.0, 9.1), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 8.65), [ingress / api gateway], size: 6.5pt)
  cdraw.content((11.5, 7.7), [auth, rate limit, tls, routing], size: 6pt)
  cdraw.line((11.5, 7.3), (11.5, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 5.1), (18.0, 6.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 6.35), [service], size: 6.5pt)
  cdraw.content((11.5, 5.45), [stable virtual ip, load balances], size: 6pt)
  for x in (8.0, 11.5, 15.0) {
    cdraw.line((x, 5.1), (x, 4.4), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((x - 1.3, 3.4), (x + 1.3, 4.4), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 3.9), [pod], size: 6pt)
  }
  cdraw.line((6.7, 3.0), (16.3, 3.0), stroke: luma(160))
  cdraw.content((11.5, 2.5), [deployment: replica set, rolling updates], size: 6pt)
  cdraw.content((11.5, 1.4), [cross-cutting policy lives at the edge], size: 6pt)
})

== bottlenecks: tracing, logging, metrics [DRILL]

The bottleneck answer is method: measure before guessing, and the
three observability legs carry the measurement. Tracing follows
one request across services and names the slow hop. Metrics are
aggregated time series, p99 latency, error rate, saturation, the
red and use dashboards. Logs are the event detail for the hop the
trace indicted. The workflow to narrate: the metric dashboard
shows the symptom, the trace finds the hop, the log explains the
line, and the fix lands behind a load test that reproduces the
original curve. The scoring sentence: a bottleneck nobody can
reproduce is a fix nobody can verify.

#diagram([symptom to hop to line to reproducing fix], length: 13pt, {
  // the observability pipeline with the verification loop under it
  let stage(x0, name, role) = {
    cdraw.rect((x0, 6.0), (x0 + 4.4, 7.8), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.2, 7.3), [#name], size: 6.5pt)
    cdraw.content((x0 + 2.2, 6.4), [#role], size: 6pt)
  }
  stage(1.2, "metrics", "the symptom")
  stage(6.5, "trace", "the slow hop")
  stage(11.8, "log", "the line")
  stage(17.1, "fix", "behind a test")
  cdraw.line((5.6, 6.9), (6.5, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.9, 6.9), (11.8, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 6.9), (17.1, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.3, 6.0), (19.3, 5.0), (3.4, 5.0), (3.4, 6.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.4, 5.4), [verify: reproduce the original curve], size: 6pt)
  cdraw.content((11.5, 1.6), [a bottleneck nobody can reproduce is a fix nobody can verify], size: 6pt)
})

== cap, event-driven, orchestration [DRILL]

Cap: under a network partition a distributed store must pick
between consistency and availability, and real systems pick per
operation. Event-driven architecture is the availability-leaning
shape: services emit facts, consumers react, and the system is
eventually consistent because the facts land asynchronously.
Orchestration versus choreography is the coordination question: an
orchestrator, a workflow engine, calls the steps and owns retries,
visible in one place but a center that can become a bottleneck,
while choreography lets each service react to events, no center to
fail but the flow exists only in the aggregate of subscriptions.
The mature answer mixes them, orchestrating the transactions that
must complete, choreographing the notifications that must not
block.

#diagram([cap picks per operation; center versus no center], length: 13pt, {
  // the partition choice on top, the two coordination shapes below
  cdraw.rect((2.5, 7.3), (20.5, 9.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 8.65), [a partition forces the choice,], size: 6pt)
  cdraw.content((11.5, 7.7), [consistency or availability, per operation], size: 6pt)
  cdraw.line((11.5, 3.0), (11.5, 6.8), stroke: luma(220))
  cdraw.content((5.8, 6.4), [orchestration], size: 6.5pt)
  cdraw.content((5.8, 5.3), [a workflow engine calls steps], size: 6pt)
  cdraw.content((5.8, 4.2), [owns retries, one view], size: 6pt)
  cdraw.content((5.8, 3.1), [a center that can bottleneck], size: 6pt)
  cdraw.content((17.4, 6.4), [choreography], size: 6.5pt)
  cdraw.content((17.4, 5.3), [each service reacts to events], size: 6pt)
  cdraw.content((17.4, 4.2), [no center to fail], size: 6pt)
  cdraw.content((17.4, 3.1), [flow lives in subscriptions], size: 6pt)
  cdraw.content((11.5, 1.7), [mix: orchestrate transactions, choreograph notifications], size: 6pt)
})

== the 300k concurrent users sketch [DRILL]

The numbers first, then the shape. 300k concurrent users at maybe
one request per user per ten seconds is 30k requests per second,
and if each holds a connection, the connections are the first
wall. The topology that stands:

#flow(
  [300k concurrent users, the shape that holds: stateless edges,
   shared cache, queue-absorbed writes, one replicated database],
  node((0, 0), [clients, #linebreak() 300k sockets]),
  node((0, 1.2), [cdn, #linebreak() static]),
  node((0, 2.4), [load balancer, #linebreak() tls termination]),
  node((0, 3.6), [stateless api pods, #linebreak() autoscaled]),
  node((0, 4.8), [redis cache, #linebreak() hot reads]),
  node((0, 6.0), [message queue, #linebreak() write buffering]),
  node((0, 7.2), [database, #linebreak() primary + replicas]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 3.6), (0, 6.0), "-|>"),
  edge((0, 4.8), (0, 7.2), "->"),
  edge((0, 6.0), (0, 7.2), "->"),
)

Walk it aloud: tls terminates at the edge, websocket or sse
connections land on stateless pods that autoscale on connection
count, reads hit a shared cache first, writes land on a queue and
drain to one primary with read replicas carrying analytics. The
follow-ups are arithmetic: 30k requests per second across pods
sized at 2k requests per second is 15 pods plus headroom, cache
hit ratio above 90 percent makes the database see only the tail,
and the queue is what keeps a traffic spike from becoming a
database outage. The bottleneck to volunteer: fan-out writes to
300k live connections, which is where the sse feed of
#xref-to("repertoire", "go-build2") meets its limits and a
dedicated pub/sub layer takes over.

== queue before the database write [DRILL]

#flow(
  [writes go through the queue, the spike absorber],
  node((0, 0), [client write]),
  node((2.2, 0), [queue, #linebreak() the buffer]),
  node((4.4, 0), [consumer, #linebreak() steady drain]),
  node((6.4, 0), [database]),
  edge((0, 0), (2.2, 0), "->", label: [burst]),
  edge((2.2, 0), (4.4, 0), "->", label: [rate]),
  edge((4.4, 0), (6.4, 0), "->"),
)

Accepting a write onto durable storage that is a queue, then
draining to the database at its pace, converts a write spike from
an outage into latency. The cost sentence the interviewer wants:
the user's write is acknowledged before it is queryable, so the
contract shifts from "saved and visible" to "accepted, visible
within x", and that contract change is a product decision, not an
engineering one. Offsets and redelivery semantics, the rest of
that conversation, are #xref-to("repertoire", "go-streaming")
implemented against a real broker.

== the remaining inventory, one paragraph each [DRILL]

Producer consumer: producers publish, consumers pull, the broker
owns ordering and redelivery, and the offset is the consumer's
bookmark, chapter 22 runs it live. S3 listing, the 10gb from
postgres and the 10gb file in go: listing a prefix is paginated,
`ListObjectsV2` pages of 1000, so count and stream instead of
materializing. Ten gigabytes out of postgres is a cursor query
streamed to the wire, never `SELECT` into memory, keyset
paginated, the same discipline as db-answers. A 10gb file in go
is `io.Copy` from file to response, streaming in chunks, since
reading it into ram is the failure the question is checking for.
Cloud cron: a scheduled function or a kubernetes cronjob hitting
an idempotent endpoint, with a lock, because a cron that overlaps
its own previous run is a distributed bug. Notification system:
events onto a queue, a fan-out service resolving recipients, per
channel senders with retries and a dead letter queue, and
templates rendered per locale at the last step, the same shape
the storefront feed of chapter 21 would grow into.

#diagram([the remaining inventory in one composite: queue, page, stream, lock, fan-out], length: 13pt, {
  // five panels, one per paragraph item, each individually labeled
  let panel(x0, x1, y0, title, l1, l2) = {
    cdraw.rect((x0, y0), (x1, y0 + 2.8), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y0 + 2.3), [#title], size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, y0 + 1.35), [#l1], size: 6pt)
    cdraw.content(((x0 + x1) / 2, y0 + 0.45), [#l2], size: 6pt)
  }
  panel(0.4, 7.9, 5.8, "producer/consumer", "publish and pull,", "the offset bookmarks")
  panel(8.3, 15.1, 5.8, "s3 listing", "pages of 1000,", "count, not gather")
  panel(15.7, 22.9, 5.8, "the 10gb streams", "io.Copy in chunks,", "never into ram")
  panel(4.5, 11.5, 2.6, "cloud cron", "idempotent hit,", "behind a lock")
  panel(12.1, 19.1, 2.6, "notifications", "fan-out + retries,", "dead letter queue")
  cdraw.content((11.5, 1.3), [the same shapes repeat: queue, page, stream, lock, fan-out], size: 6pt)
})

sources: no online citations for the design patterns themselves,
the drills are engineering practice floored by
#xref-to("infrastructure", "capstone1") and
#xref-to("infrastructure", "capstone2") topologies, which run
under `docker compose up -d`.
