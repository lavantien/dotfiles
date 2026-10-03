#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= nats: pub sub, request reply, queue groups

NATS core is a subject tree with a router in the middle. Publishers
send to subjects, subscribers declare interest in subjects, and the
broker matches, with no persistence, no delivery guarantee beyond
at-most-once to a connected subscriber, and correspondingly no
configuration. It is the smallest useful messaging primitive, and the
capstone's request paths run on it entirely.

== subjects are a hierarchy

A subject is dot separated tokens, `chat.room.general`, and the
wildcards are token wildcards: `*` matches exactly one token, `>`
matches one or more to the end. The probe runs all three subscription
shapes against one publish and counts who saw what:

#listing("infrastructure/samples/ch14/nats_test.go", first: 66, last: 116, caption: [exact, star, and gt against two publishes of different depth])

#diagram([token wildcards: who sees each publish], length: 13pt, {
  cdraw.rect((0.0, 7.4), (8.6, 8.4), fill: luma(205), radius: 0.02)
  cdraw.content((4.3, 7.9), [chat.room.general], size: 6.5pt)
  cdraw.rect((0.0, 4.4), (9.0, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((4.5, 4.9), [chat.room.general.mods], size: 6.5pt)

  cdraw.rect((13.5, 7.4), (22.2, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.85, 7.9), [exact chat.room.general], size: 6pt)
  cdraw.rect((13.5, 5.9), (22.2, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((17.85, 6.4), [star chat.room.\*], size: 6pt)
  cdraw.rect((13.5, 4.4), (22.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.85, 4.9), [gt chat.>], size: 6pt)

  cdraw.line((8.6, 7.9), (13.4, 7.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((8.6, 7.7), (13.4, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((8.6, 7.5), (13.4, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.0, 4.9), (13.4, 4.75), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.5, 3.6), [reaches gt only], size: 6pt)

  cdraw.content((11.0, 2.2), [star is exactly one token], size: 6pt)
  cdraw.content((11.0, 1.1), [gt is one or more to the end], size: 6pt)
  cdraw.content((11.0, 0.0), [nothing suffix-shaped survives], size: 6pt)
})

The second publish is the one that teaches: `chat.room.general.mods`
misses the exact subscription and the star, one token stands for one
token, and reaches the `>` subscription only. Nothing string-suffix
shaped survives this probe, which is the point of running it.

== request reply is one publish with a return address

A request publishes with an inbox subject attached as the reply field
and waits on a fresh subscription to that inbox. The responder
publishes to the inbox it was handed:

#listing("infrastructure/samples/ch14/nats_test.go", first: 120, last: 137, caption: [responder and requester, one round trip, no broker config])

#diagram([request reply: one publish carrying a return address], length: 13pt, {
  cdraw.rect((1.6, 9.0), (6.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 9.45), [requester], size: 6.5pt)
  cdraw.rect((13.6, 9.0), (18.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((16.0, 9.45), [responder], size: 6.5pt)
  cdraw.line((4.0, 9.0), (4.0, 0.6), stroke: luma(220))
  cdraw.line((16.0, 9.0), (16.0, 0.6), stroke: luma(220))

  cdraw.rect((3.85, 7.65), (4.15, 7.95), fill: luma(100))
  cdraw.content((8.6, 7.8), [subscribes a fresh inbox], size: 6pt)
  cdraw.rect((3.85, 6.25), (4.15, 6.55), fill: luma(100))
  cdraw.content((8.5, 6.4), [publish, reply-to: inbox], size: 6pt)

  cdraw.line((4.15, 5.2), (15.85, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.85, 4.15), (16.15, 4.45), fill: luma(100))
  cdraw.content((12.2, 4.3), [responder handles it], size: 6pt)

  cdraw.line((15.85, 3.0), (4.15, 3.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.85, 1.65), (4.15, 1.95), fill: luma(100))
  cdraw.content((7.6, 1.8), [answer on the inbox], size: 6pt)

  cdraw.content((11.0, 0.5), [no broker config anywhere], size: 6.5pt)
})

The capstone wraps exactly this in two functions, one per side, so
every service boundary uses the same encoding and error envelope:

#listing("infrastructure/capstone/internal/bus/rpc.go", first: 24, last: 49, caption: [the caller side: marshal, request, error envelope, decode])

A modern nicety the capstone leans on: a request with no responder
fails fast, the broker answers with a no-responders status instead of
silence, so a missing service is an immediate error rather than a
timeout to stare at:

#listing("infrastructure/samples/ch14/nats_test.go", first: 142, last: 148, caption: [nobody home is an error now, not a hang])

== queue groups: load balancing with no broker config

Plain subscriptions are broadcast, every subscriber sees everything.
Adding a queue name turns a set of subscribers into one logical
subscriber, and the broker delivers each message to exactly one member:

#listing("infrastructure/samples/ch14/nats_test.go", first: 153, last: 205, caption: [fifty messages across three workers: all delivered, none twice, nobody idle])

That is worker pooling with zero configuration, and it is the
primitive the web tier would scale on, every replica sees every
notification because plain, while notify replicas share the stream
work because queue semantics arrive with JetStream's durable
consumers in #xref-to("infrastructure", "jetstream").

== the broker in process

Everything above runs in the test binary. The embedded server is the
same code the compose stack runs in a container, minus the container:

#listing("infrastructure/capstone/internal/testnats/server.go", first: 18, last: 45, caption: [one function: random port, jetstream on, temp store, cleanup registered])

#diagram([the same nats-server code in two homes], length: 13pt, {
  cdraw.rect((7.0, 7.0), (16.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 7.5), [the nats-server code], size: 6.5pt)

  cdraw.line((10.0, 7.0), (5.2, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.6, 7.0), (16.0, 6.2), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((0.0, 4.25), (10.4, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 5.85), [the compose container], size: 6.5pt)
  cdraw.content((5.2, 4.75), [one container in the stack], size: 6pt)

  cdraw.rect((12.8, 3.1), (23.4, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.1, 5.75), [the embedded test server], size: 6.5pt)
  cdraw.content((18.1, 4.65), [random port, jetstream on], size: 6pt)
  cdraw.content((18.1, 3.55), [temp store, cleanup], size: 6pt)

  cdraw.content((5.0, 2.2), [a fake broker would test], size: 6pt)
  cdraw.content((5.0, 1.1), [the fake's idea of nats], size: 6pt)
})

Every capstone test calls this instead of mocking the broker. The
distinction is the chapter's quiet argument: a fake broker would test
the fake's idea of nats, while the embedded server is the real
dispatcher with real subject routing, at the cost of an import.

#flow(
  [who gets what, plain versus queue],
  node((0, 0), [publish, chat.room.general]),
  node((1.7, 0), [broker]),
  node((3.4, 1.0), [sub a, sees all]),
  node((3.4, 0.2), [sub b, sees all]),
  node((3.4, -1.0), [queue w1..w3, one each]),
  edge((0, 0), (1.7, 0), "-|>"),
  edge((1.7, 0), (3.4, 1.0), "-|>"),
  edge((1.7, 0), (3.4, 0.2), "-|>"),
  edge((1.7, 0), (3.4, -1.0), "-|>"),
)

#callout("note", "core nats forgets", [
  A message published with no connected subscriber is gone. That is
  the design: the capstone's durable paths, the chat log and the
  presence bucket, live one chapter over in JetStream, while the
  request reply and notification fanout, where a lost message means a
  missed ping not lost data, stay on core and stay simple.
])

sources: docs.nats.io subject and wildcard semantics, accessed
2026-09-10, plus pkg.go.dev for the embedded server options. Verified
by the ch14 probe suite, 6 tests, and the capstone bus suite, 5
tests, all green under `make verify` 2026-09-10.
