#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= container networking

Every compose project gets its own bridge network, created
implicitly, and the containers on it can reach each other by service
name. That single sentence is most of container networking, and the
mechanism under it is worth one chapter because it is the difference
between a stack that starts and one that starts then falls over
waiting for a hostname that only exists outside.

== the bridge and the embedded dns server

The bridge network is a virtual switch inside the docker engine. Each
container gets a virtual interface on it with a private address, and
traffic between containers on the same bridge never leaves the host.
Alongside the switch the engine runs an embedded dns server, and every
container's resolver points at it. When the chat service resolves
`nats`, that name never reaches the internet, the embedded server
answers with the nats container's address on the bridge.

That is why the capstone's configuration is bare names everywhere:

#listing("infrastructure/capstone/compose.yml", first: 43, last: 47, caption: [the chat service finds its broker by service name, inside the project bridge])

#diagram([resolving nats inside the project bridge, no further than the engine], length: 13pt, {
  cdraw.rect((0.0, 5.0), (5.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.9, 5.5), [chat's resolver], size: 6.5pt)
  cdraw.line((5.8, 5.5), (7.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.5, 6.6), [asks], size: 6pt)
  cdraw.rect((7.2, 5.0), (14.0, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((10.6, 5.5), [embedded dns server], size: 6.5pt)
  cdraw.line((14.0, 5.5), (15.3, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((14.7, 6.6), [answers], size: 6pt)
  cdraw.rect((15.4, 5.0), (22.2, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((18.8, 5.5), [nats, on the bridge], size: 6.5pt)

  cdraw.content((10.3, 3.9), [nats:4222 is the nats container's bridge address], size: 6pt)
  cdraw.content((10.3, 2.8), [traffic never leaves the host], size: 6pt)
  cdraw.content((10.3, 1.7), [the name never reaches the internet], size: 6pt)
})

`NATS_URL: nats://nats:4222` is not a placeholder that works by luck.
The host `nats` is the compose service name, resolved by the embedded
server, and every service in the file uses the same pattern with zero
ip addresses anywhere. The same stanza carries the one thing that does
punch out of the bridge: the sqlite path on a named volume, so the
database file outlives the container.

== one published port, on purpose

#listing("infrastructure/capstone/compose.yml", first: 121, last: 124, caption: [only the web tier publishes a host port])

The other seven services are reachable inside the bridge and invisible
from the host. That is a design rule, not thrift: the web tier is the
system's only public surface, and keeping the brokers and workers
unpublished means the host's port space stays clean and nothing can
bypass the front door. When a test needs mongo or nats directly, the
docker-gated suite reaches the system through the web port like every
other client.

#flow(
  [who can talk to whom],
  node((0, 0), [browser, on the host]),
  node((1.9, 0), [web :8080, published]),
  node((3.9, 0), [bridge network]),
  node((3.9, -1.2), [nats, mongo, chat, presence, notify, history, analytics]),
  edge((0, 0), (1.9, 0), "-|>", label: [localhost:8080]),
  edge((1.9, 0), (3.9, 0), "-|>", label: [embedded dns]),
  edge((3.9, 0), (3.9, -1.2), "-|>"),
)

== the subject space is the other network

The bridge moves bytes between processes. The application-level
network is the nats subject tree, `chat.room.<room>`,
`notify.user.<user>`, `presence.beat`, and the request subjects, and
the capstone's services never address each other by host at all beyond
the one broker url. A message published on `chat.room.general` is
routed by the broker to whoever expressed interest, on whichever
container that subscriber landed. The two networks compose: dns finds
the broker once at startup, subjects do everything after.

#diagram([two stacked networks: the bridge connects once, the subject tree routes everything after], length: 13pt, {
  cdraw.rect((0.0, 5.0), (23.0, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.7), [the bridge, dns], size: 6.5pt)
  cdraw.content((11.5, 5.6), [finds the broker once, moves the first byte], size: 6pt)

  cdraw.line((11.5, 5.0), (11.5, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((14.0, 4.5), [after connect], size: 6pt)

  cdraw.rect((0.0, 0.0), (23.0, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.5), [the subject tree], size: 6.5pt)
  cdraw.line((11.5, 2.9), (3.9, 2.4), stroke: luma(100))
  cdraw.line((11.5, 2.9), (10.9, 2.4), stroke: luma(100))
  cdraw.line((11.5, 2.9), (18.1, 2.4), stroke: luma(100))
  cdraw.rect((1.2, 1.4), (6.6, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 1.9), [chat.room.\*], size: 6pt)
  cdraw.rect((8.2, 1.4), (13.6, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.9, 1.9), [notify.user.\*], size: 6pt)
  cdraw.rect((15.2, 1.4), (21.0, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.1, 1.9), [presence.beat], size: 6pt)
  cdraw.content((11.5, 0.5), [the broker routes everything after], size: 6pt)
})

#callout("note", "why the unit tests never need dns", [
  The embedded server from #xref-to("infrastructure", "nats") hands
  tests a real client url, so the same code path, connect by url,
  dial, subscribe, runs in-process and in-container. The bridge and
  its dns server exist to make that one url resolvable in production.
  Nothing else in the capstone knows networking exists.
])

sources: docs.docker.com engine network drivers for bridge networking
and the embedded dns server, accessed 2026-09-09. Verified by
`make verify-infra-docker`, whose suite reaches the whole system
through the single published port, green 2026-09-10.
