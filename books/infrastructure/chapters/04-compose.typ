#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= compose and one click local systems

One container proves a process works. A system is several containers
that find each other, start in a defensible order, and report when
they are actually ready, and compose is the declarative file that says
all of it. The capstone's `compose.yml` is eight services and four
volumes, and the claim it backs is strong: `docker compose up -d
--wait` returning means the chat system works, not merely that eight
containers exist.

== healthchecks, the difference between started and working

A container that has a process in it is "running" even if that process
is still dialing its broker or waiting on its database. The healthcheck
closes that gap: a command the engine runs inside the container on an
interval, and a container is healthy only when the command succeeds.
The capstone compresses the shared timing into one yaml anchor:

#listing("infrastructure/capstone/compose.yml", first: 12, last: 16, caption: [one anchor, seven of eight services: probe every 2s, 30 retries, 3s of startup grace])

#diagram([container states under the shared probe, from started to working], length: 13pt, {
  cdraw.rect((0.0, 5.6), (4.2, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.1, 6.1), [starting], size: 6.5pt)
  cdraw.line((4.2, 6.1), (7.4, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.8, 7.3), [first probe ok], size: 6pt)
  cdraw.rect((7.4, 5.6), (11.6, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((9.5, 6.1), [healthy], size: 6.5pt)
  cdraw.line((11.6, 6.1), (14.8, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.2, 7.3), [fails 30 times], size: 6pt)
  cdraw.rect((14.8, 5.6), (19.6, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.2, 6.1), [unhealthy], size: 6.5pt)
  cdraw.content((2.1, 4.4), [3s start grace], size: 6pt)
  cdraw.content((9.5, 4.4), [compose routes to it], size: 6pt)
  cdraw.content((17.2, 4.4), [detection is bounded], size: 6pt)
  cdraw.content((11.5, 3.3), [probe every 2s, up to 30 tries], size: 6pt)
})

The brokers first, since everything else depends on them:

#listing("infrastructure/capstone/compose.yml", first: 19, last: 36, caption: [nats probes its own monitoring endpoint, mongo pings itself through mongosh])

The nats image exposes a healthz endpoint on its monitoring port, and
the alpine base carries busybox wget to fetch it. The mongo image
carries mongosh, so its probe is a real ping through the real client,
and it is the one service outside the anchor, setting its own slower
timing, a 5s timeout and a 10s start period, because a cold database
needs more grace than a binary answering one route. My own services
each serve a `/healthz` http endpoint from
`internal/boot`, one route per process, so the probe asserts the
process can still answer, which is the definition of alive the
operator wants.

== depends_on with a condition, and why up \-\-wait means it

#listing("infrastructure/capstone/compose.yml", first: 37, last: 53, caption: [chat waits for a healthy nats, and carries its own probe on 8081])

The `condition: service_healthy` form is the load-bearing one. Without
a condition, depends_on only orders container starts, which on a slow
mongo means the history service starts against a dependency that is
seconds from existing and dies, or worse, retries in a loop forever.
With conditions, the dependency graph is a readiness graph:

#listing("infrastructure/capstone/compose.yml", first: 115, last: 138, caption: [the web tier waits for all five services to be healthy before it can be healthy itself])

#diagram([the readiness graph the conditions build, and what up --wait waits for], length: 13pt, {
  cdraw.rect((3.4, 0.0), (7.0, 1.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 0.5), [nats], size: 6.5pt)
  cdraw.rect((11.8, 0.0), (15.4, 1.0), fill: luma(235), radius: 0.02)
  cdraw.content((13.6, 0.5), [mongo], size: 6.5pt)

  cdraw.rect((0.0, 2.8), (3.0, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((1.5, 3.3), [chat], size: 6.5pt)
  cdraw.rect((3.9, 2.8), (6.9, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 3.3), [notify], size: 6.5pt)
  cdraw.rect((7.8, 2.8), (10.8, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((9.3, 3.3), [presence], size: 6.5pt)
  cdraw.rect((11.7, 2.8), (14.7, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((13.2, 3.3), [history], size: 6.5pt)
  cdraw.rect((15.6, 2.8), (18.6, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 3.3), [analytics], size: 6.5pt)

  cdraw.rect((6.8, 5.6), (12.6, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((9.7, 6.1), [web], size: 6.5pt)

  cdraw.line((1.5, 2.8), (4.2, 1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((3.0, 3.3), (3.9, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.3, 2.8), (5.5, 1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.6, 2.8), (6.3, 1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.8, 2.8), (13.6, 1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.9, 2.8), (6.9, 1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((7.4, 5.6), (1.8, 3.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((8.7, 5.6), (5.3, 3.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.9, 5.6), (9.3, 3.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.1, 5.6), (13.2, 3.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.3, 5.6), (17.1, 3.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.6, 6.1), [every edge is service_healthy], size: 6pt)
  cdraw.content((11.5, 7.4), [up --wait returns zero only when every node is healthy], size: 6pt)
})

`--wait` turns the whole command synchronous: compose brings the graph
up and returns zero only when every container reports healthy. That is
what licenses the capstone's one-click claim, and it is why the
docker-gated suite in #xref-to("infrastructure", "capstone2") can
start testing the moment `up` returns.

== volumes and teardown discipline

Four named volumes hold the nats jetstream store, the durable log
#xref-to("infrastructure", "jetstream") builds on, the mongo files,
the chat sqlite database, and the analytics duckdb file. The make
target that drives this stack
tears down with `down -v` even when the tests fail, wrapped in a shell
trap, because a half-torn stack with stale volumes is exactly the kind
of local drift that makes the next run fail for reasons that are not
in the code. The failure mode the trap guards against is simple: a red
suite that also leaves a running stack, which the next `up --wait`
then passes against stale state.

#diagram([the make target lifecycle, the trap that tears down whatever happened], length: 13pt, {
  cdraw.rect((0.0, 6.8), (4.4, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((2.2, 7.3), [preflight], size: 6.5pt)
  cdraw.line((4.4, 7.3), (5.2, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.2, 6.8), (11.4, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((8.3, 7.3), [up --build --wait], size: 6.5pt)
  cdraw.line((11.4, 7.3), (12.2, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((12.2, 6.8), (18.0, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.1, 7.3), [tagged suite], size: 6.5pt)
  cdraw.line((18.0, 7.3), (18.8, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((18.8, 6.8), (23.4, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((21.1, 7.3), [down -v], size: 6.5pt)

  cdraw.line((15.1, 6.8), (15.1, 5.6), stroke: luma(100))
  cdraw.line((15.1, 5.6), (21.1, 5.6), stroke: luma(100))
  cdraw.line((21.1, 5.6), (21.1, 6.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.1, 5.0), [suite red: trap still tears down], size: 6pt)

  cdraw.content((11.7, 3.9), [without the trap, the drift:], size: 6.5pt)
  cdraw.rect((0.0, 1.6), (5.4, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.7, 2.1), [red suite], size: 6.5pt)
  cdraw.line((5.4, 2.1), (6.2, 2.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.2, 1.6), (13.4, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 2.1), [stack left running], size: 6.5pt)
  cdraw.line((13.4, 2.1), (14.2, 2.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((14.2, 1.6), (23.4, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((18.8, 2.1), [next up passes stale], size: 6.5pt)
})

#callout("warning", "the healthcheck is not a monitoring system", [
  A healthcheck is a liveness contract for orchestration, one command,
  one interval, no history. It tells compose whether to route to this
  container. It is not metrics, not alerting, and not a substitute for
  the logging the services already do. Keeping the probe tiny and
  dependency-free, `wget` on localhost, is what keeps restarts cheap.
])

sources: docs.docker.com compose file reference for healthcheck,
depends_on conditions, and the `--wait` flag, accessed 2026-09-09 and
2026-09-10. Verified by `make verify-infra-docker`, which runs exactly
this lifecycle, up, wait, test, down with volumes, green 2026-09-10.
