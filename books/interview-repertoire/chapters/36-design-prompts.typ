#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= system design prompts, four worked

The design round eventually stops asking about shapes and hands over
a prompt: design a url shortener, a rate limiter, a news feed, a chat
service. This chapter works all four with the same protocol, the
300k sketch of #xref-to("repertoire", "design-answers") promoted from
one answer to a method, and one prompt, the shortener, ships
test-driven go code because its two interesting pieces, a base62
codec and a windowed counter allocator, are exactly interview-sized.
The other three are drills floored on systems this corpus actually
runs, and the delivery ladder at the close settles the
long-polling question the network chapter leaves open.

== how to run a design prompt [DRILL]

The protocol, six moves on a clock. Requirements first, functional
and non-functional, and the number you are told, users, requests,
retention, is a requirement, write it down and use it. Estimation is
the opening move, not garnish: run the four-move method of
#xref-to("repertoire", "estimation-answers") on the given number
before any box is drawn, because the arithmetic picks the topology
more often than preference does. Then the topology, drawn, and the
walk-aloud over it, naming what each hop does and what it costs.
Volunteer the bottleneck before being asked, the interviewer is
grading whether you can see it, and meet every follow-up with a
tradeoff, never a defense: the question is rarely "is your design
wrong", it is "what does it cost to be right a different way".

#diagram([the prompt clock: six moves, the estimate second, never last], length: 13pt, {
  // a horizontal clock strip of the six protocol moves
  let stage(x0, name, line) = {
    cdraw.rect((x0, 5.4), (x0 + 3.4, 7.8), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 1.7, 7.15), [#name], size: 6.5pt)
    cdraw.content((x0 + 1.7, 6.15), [#line], size: 6pt)
  }
  stage(0.4, "requirements", "functional, and the number")
  stage(4.3, "estimate", "the opening move")
  stage(8.2, "topology", "drawn, not narrated")
  stage(12.1, "walk", "each hop, each cost")
  stage(16.0, "bottleneck", "volunteered first")
  stage(19.9, "tradeoffs", "answers, not defenses")
  for x in (3.8, 7.7, 11.6, 15.5, 19.4) {
    cdraw.line((x, 6.6), (x + 0.4, 6.6), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.9, 3.9), [the arithmetic picks the topology more often than preference], size: 6pt)
  cdraw.content((11.9, 2.2), [the follow-up asks what right costs a different way,#linebreak()never whether you were wrong], size: 6pt)
})

== url shortener [TDD]

The arithmetic first, from a stated assumption of 100 million new
links a year. That is 3 writes a second steady, 30 at a 10x peak,
and a 10 to 1 read ratio makes reads 300 a second at peak. The
five-year store is 500 million links at about 150 bytes a row, 75
gigabytes of payload, twice that with the index, so 150 gigabytes
before replicas, call the honest band 150 to 250. The keyspace
arithmetic is the part worth saying slowly: 62^7 is about 3.5
trillion codes, seven characters cover 500 million links roughly
seven-thousand-fold, so length is never the constraint and growth
buys decades, not a migration.

Code assignment is the one real decision, and the workspace ships
it test-driven. A hash of the url needs a collision check on every
insert, a database round trip on the hot path, while a counter hands
out integers that are unique by construction and encodes them in
base62. The codec, with the overflow guard checked before the
multiply because a wrapped int64 is silent:

#listing("interview-repertoire/samples/ch36-go/base62.go", first: 19, last: 61, caption: [encode by repeated division, decode with the pre-multiply overflow check])

The allocator is the piece interviewers probe: two api instances
must never mint the same code. The answer is windows, each instance
reserves a range from one persistent counter and serves it from
local arithmetic, so the hot path coordinates nothing:

#listing("interview-repertoire/samples/ch36-go/allocator.go", first: 8, last: 60, caption: [the counter is the one coordination point, once per window])

The suite pins the properties the design claims: every one- and
two-character code round-trips, 3,906 of them, max int64 round-trips
at exactly eleven characters, non-alphabet input and past-int64
values are errors, two allocators over one counter hand out disjoint
codes, and a drained pool returns the exhaustion error rather than a
repeated code, eleven tests under `go vet`, `go test`, and
`go test -race`.

#flow(
  [the shortener: stateless edges, an allocator per pod, one store, cache beside],
  node((0, 0), [clients]),
  node((0, 1.2), [load balancer]),
  node((0, 2.4), [stateless api, #linebreak() encode + redirect]),
  node((2.2, 2.4), [cache, #linebreak() hot reads]),
  node((0, 3.6), [id allocator, #linebreak() windowed counter]),
  node((0, 4.8), [kv store, #linebreak() primary + replicas]),
  node((2.2, 4.8), [analytics queue, #linebreak() clicks, drain]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (2.2, 2.4), "->", label: [miss]),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.2, 4.8), "->"),
)

The punchline to volunteer before being asked: at a 10 to 1 read
ratio and 300 reads a second, the shortener is a cache problem
wearing a design crown, hot codes live in memory with a ttl near the
code's lifetime, cold codes in a kv store one lookup deep, and the
redirect is one line of handler. The traps, one line each. Hash with
collision check against counter assignment, counter wins, the
collision check is a store hit on every write. Custom aliases, a
unique index and a clean rejection, never a retry loop. 301 against
302: 301 is cached by browsers and stops the analytics, 302 keeps
every click visible and pays the redirect, say which you are choosing
and why. Expiry is a lazy delete, a ttl checked on read plus a
nightly sweep, the store never blocks on it. Rate limiting the
creator, not the reader, is the abuse surface, the bucket shape and
its 429 contract are #xref-to("go", "limit").

== rate limiter [DRILL]

The arithmetic from the stated load: 100k requests a second peak,
10 million active users, a limit of 100 requests per minute per
user. The bucket per user refills at 100 over 60, about 1.67 tokens
a second, with burst 100. State is the number that decides the
shape: 64 bytes a user is 640 megabytes for everyone, about a
gigabyte all in, so the full state fits one machine and the question
becomes where the check runs. The trade, quantified with the
datacenter round trip: a shared-store check costs about 0.5
milliseconds per request, which at 100k a second is 50 seconds of
added latency across the fleet every second, while a local bucket
adds nothing but n instances can allow n times the limit until they
converge. Converge by asynchronous sync, buckets ship their deltas to
the shared store every second and load their neighbors' state on
startup, and say the approximation out loud: the limit is soft
between syncs, worst case the burst times the sync interval, and a
soft limit is the correct product answer for a rate limiter, an
exact one is for money.

#flow(
  [local buckets on the hot path, the shared store off it, sync in between],
  node((0, 0), [client]),
  node((0, 1.2), [gateway middleware, #linebreak() key, then bucket]),
  node((0, 2.4), [local token bucket, #linebreak() allow or 429]),
  node((0, 3.6), [service]),
  node((2.4, 2.4), [async sync, #linebreak() deltas, every second]),
  node((2.4, 3.6), [shared store, #linebreak() the global view]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 2.4), (2.4, 2.4), "-|>"),
  edge((2.4, 2.4), (2.4, 3.6), "->"),
)

The floors are the six limit chapters the service corpus shipped,
one per language, the token bucket from first principles and its 429
contract in #xref-to("go", "limit"), the platform contrast where the
same bucket rides middleware in #xref-to("csharp-net", "limit"), and
the limiter as a resilience pattern beside retries and breakers in
#xref-to("patterns", "resilience"). The traps: 429 carries
`Retry-After`, a client that cannot learn when to come back will
hammer anyway. Burst against sustained, a limit of 100 a minute is
not 100 at every instant, the bucket shape is the difference.
Fairness across keys, one hot tenant must not eat the shared
capacity, key the buckets and cap per key. What a paying tier buys is
a higher refill, which is the same bucket with different constants,
say that and the product conversation ends.

== news feed [DRILL]

The arithmetic: 10 million users, 200 follows each, 2 posts a day
each, so 20 million posts a day. Fanout-on-write multiplies each post
by its audience: 20 million times 200 is 4 billion timeline writes a
day, about 46k a second sustained, with the morning spike a multiple
of that, and that is the write storm. Fanout-on-read inverts it: 200
merges per view, every reader pays the fanout, the store stays small
and the read path is a distributed query. The celebrity number to say
aloud: one post by a 1M-follower user is 1 million fanout writes in
pure push, one user's Tuesday is more than twenty seconds of the
entire fleet's write budget. The
resolution is hybrid push-pull: push for ordinary users, pull at read
time for celebrity follows, the threshold a tuned product number, and
the same logic pulls for inactive users whose pushed timelines are
never read. The timeline store is trimmed to 300 to 500 items per
user, about 300 gigabytes at 100 bytes an item for 10 million users,
and the trim is stated as a product contract change, the feed
promises a window not a history, the same move as the queue-first
contract shift in #xref-to("repertoire", "design-answers").

#flow(
  [posts through a queue to fanout workers, readers hit the timeline],
  node((0, 0), [client]),
  node((0, 1.2), [feed api]),
  node((0, 2.4), [timeline store, #linebreak() 300-500 items]),
  node((0, 3.6), [fanout workers, #linebreak() push-pull decision]),
  node((2.2, 3.6), [follow graph store]),
  node((0, 4.8), [queue]),
  node((0, 6.0), [post service]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 3.6), (0, 2.4), "->", label: [writes]),
  edge((0, 4.8), (0, 3.6), "->"),
  edge((0, 6.0), (0, 4.8), "->"),
  edge((2.2, 3.6), (0, 3.6), "->"),
)

The floors: per-key ordering and the outbox that keeps a post and
its fanout message atomic are #xref-to("patterns", "messaging"), and
the feed that actually runs in this book, bounded history, replay
after a sequence number, live tail, is #xref-to("repertoire",
"go-build2"), the same shape with one publisher and no fanout. The
traps: deletion propagates as tombstones, a deleted post must leave
every timeline it already entered. Ranking against chronological is a
product decision that changes the store, ranked feeds precompute
scores and the timeline becomes a cache of a model. Pagination
consistency, a cursor into a moving timeline, the cursor must be a
post id snapshot, never an offset. The user who follows 1 million is
the celebrity problem seen from below, pull for them too, their view
is a live merge the API assembles.

== chat [DRILL]

The arithmetic: 1 million concurrent, 10 messages per user-hour, so
10 million messages an hour, about 2.8k a second, at 200 bytes each
roughly 0.55 megabytes a second. Bandwidth is trivial, and saying so
is the point: connections are the wall. A gateway pod holds about
100k sockets, the epoll economics of #xref-to("repertoire",
"systems-answers"), so 1 million concurrent is 10 pods before
headroom. Route by consistent hash on the conversation id so both
participants land on the same pod, the partitioning logic of
#xref-to("patterns", "partitioning"), and an in-memory conversation
becomes possible: both sockets in one process, delivery is a channel
send. Presence is ttl heartbeats, 1 million over 30 seconds is about
33k writes a second, coalesced into batches, and a missed heartbeat
expires into "last seen", never "gone". Offline is ch19's
notification shape: an inbox queue per offline user, a push
notification on arrival, a dead letter queue for the push that
cannot land, delivery on reconnect. Receipts are at-least-once with
client message-id dedupe, the exactly-once-effect contract of
#xref-to("repertoire", "distributed-answers").

#flow(
  [hash by conversation, both sockets on one pod, inbox for the offline],
  node((0, 0), [clients, #linebreak() 1 million sockets]),
  node((0, 1.2), [gateway pods, #linebreak() 100k sockets each]),
  node((0, 2.4), [conversation, #linebreak() both sockets colocated]),
  node((0, 3.6), [per-conversation log, #linebreak() ordered]),
  node((0, 4.8), [fanout, #linebreak() online: channel send]),
  node((0, 6.0), [inbox queue + push, #linebreak() offline, dead letter]),
  node((2.2, 1.2), [presence store, #linebreak() ttl heartbeats]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "-|>"),
  edge((2.2, 1.2), (0, 1.2), "->"),
)

The floors: the chat that actually runs under `docker compose up -d`,
nats subjects, jetstream durability, htmx over sse, is
#xref-to("infrastructure", "capstone2"), the durable consumer and
its ack floor are #xref-to("infrastructure", "jetstream"), and the
frames underneath, the websocket handshake arithmetic and the frame
codec, are #xref-to("repertoire", "network-answers"). The traps:
per-conversation ordering is the contract, global ordering is a
non-goal that costs a single writer, say the scope before drawing.
Offline sync is the inbox replay plus cursor, the same dedupe keys
guarding the double delivery. Group fanout is the news feed's
problem at conversation scale, a 500-member room is 500 fanout
writes per message and the same hybrid logic applies. End-to-end
encryption is the honest concession: the server can route and store
ciphertext, key exchange and ratchets are a different discipline,
#xref-to("math", "actions") for the structures, and a design round
answer that claims e2ee and server-side search has not thought about
either.

== long polling, sse, websockets: the delivery ladder [DRILL]

Three mechanisms, by cost and semantics. Long polling is a held
request: the client asks, the server holds the response open until
data arrives or a timeout, the client re-asks. It costs one request
per delivery, works through every proxy and firewall, and needs
nothing from the server but a slow handler. Sse is a server-to-client
stream over plain http, `text/event-stream`, one response held open
with events flushed down it: one-way, cheap, reconnects built into
the browser, the mechanism the feed of #xref-to("repertoire",
"go-build2") uses. Websockets are bidirectional frames after an http
upgrade handshake, both directions on one connection, the highest
capability and the highest cost, the handshake arithmetic and the
frame codec the network chapter implements from the metal. Each wins
somewhere: polling when the network is hostile and the client is
dumb, sse when the flow is server-to-client, which most feeds,
tickers, and notifications are, websockets when the client pushes on
the same channel, chat, games, collaborative editing. The fallback
ladder is part of the design: try websockets, degrade to sse when a
proxy strips the upgrade, degrade to long polling when even the
stream is refused, the client names its mechanism, the server speaks
all three, and the long-polling rung closes the gap this book had,
it was the one delivery mechanism named in prompts and never worked.

#diagram([push against pull: the same fanout through both delivery shapes], length: 13pt, {
  // left: one event pushed down three held streams, right: three
  // pollers each paying a request per event
  cdraw.content((5.5, 9.3), [push: one event, three streams], size: 6.5pt)
  cdraw.rect((3.8, 7.4), (7.2, 8.5), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((5.5, 7.95), [one event], size: 6pt)
  for x in (2.0, 5.5, 9.0) {
    cdraw.line((5.5, 7.3), (x, 6.2), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((x - 1.1, 5.2), (x + 1.1, 6.2), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 5.7), [stream], size: 6pt)
  }
  cdraw.content((5.5, 4.1), [three flushes, zero new requests], size: 6pt)
  cdraw.content((17.6, 9.3), [pull: three pollers, same event], size: 6.5pt)
  cdraw.rect((15.9, 7.4), (19.3, 8.5), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((17.6, 7.95), [one event], size: 6pt)
  for x in (14.1, 17.6, 21.1) {
    cdraw.rect((x - 1.1, 5.2), (x + 1.1, 6.2), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 5.7), [poller], size: 6pt)
    cdraw.line((x, 6.3), (17.6, 7.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
    cdraw.content((x, 6.75), [ask], size: 6pt)
  }
  cdraw.content((17.6, 4.1), [three requests per event, at every event], size: 6pt)
  cdraw.content((11.5, 2.4), [the ladder: websockets, then sse, then long polling,#linebreak()the client names the mechanism, the server speaks all three], size: 6pt)
})

floored to: no measurements in this chapter, every number is
arithmetic, the running systems it leans on are real. The estimation
method is #xref-to("repertoire", "estimation-answers"). The
shortener's keyspace arithmetic floors on #xref-to("dsa",
"hashing") for the hash map behavior it declines and
#xref-to("patterns", "partitioning") for the consistent hash it
borrows. Ordering, the outbox, and per-key lanes are
#xref-to("patterns", "messaging"). The queue and the chat that run
are #xref-to("infrastructure", "jetstream"),
#xref-to("infrastructure", "capstone1"), and
#xref-to("infrastructure", "capstone2") under `docker compose up -d`.
The wire underneath the delivery ladder is
#xref-to("repertoire", "network-answers"), and the bucket behind the
rate limiter is the six limit chapters, one per language of the
service corpus.
