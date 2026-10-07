#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= messaging semantics and idempotency

A message system answers three questions badly or well: does the
message arrive at most once, at least once, or exactly once, in what
order, and what happens when it arrives twice. The first has only
one honest answer in practice, at least once, because
acknowledgments can be lost after delivery just as deliveries can be
lost after sending. Everything else in this chapter is engineering
on top of that fact, and the seven trees all learn it the same way:
the crash is a parameter, the duplicate is a fixture, and no lane
waits on a scheduler to observe either.

== the three semantics

At-most-once is fire and forget, fast and lossy, right for metrics
and telemetry. At-least-once is send and retry until acknowledged,
lossless but duplicating, because the sender cannot distinguish
"lost before processing" from "processed, then the ack drowned".
Exactly-once delivery does not exist across a real network, and what
vendors mean by the phrase is exactly-once effect: at-least-once
delivery into an idempotent consumer. Every tree builds exactly
that, honestly labeled.

The dry run: the dedup contract and which lanes pin each row.

- the duplicator unit: every 2 on id 2 delivers `[2, 2]`, applied
  exactly once, the echo suppressed
- a full replay of a delivered stream applies nothing new, effects
  keep first-delivery order, a row the C, java, and python lanes
  pin, while C\# and lua pin the single envelope and partial
  replays, and java redrives the whole stream twice over, 24
  consume calls for 6 effects
- the frozen go test pins `[2, 2]` itself, the six sibling trees
  pin the same literal against the shared contract

#listing("patterns-concurrency-distributed/samples-c/src/Ch13/consumer.c", first: 29, last: 64, caption: [C, the applied memory is a bitmap over dense ids, deliver is a function the relay calls back])

#listing("patterns-concurrency-distributed/samples/ch13/messaging.go", first: 94, last: 118, caption: [Go, the consumer remembers applied ids, duplicates observed and suppressed])

#listing("patterns-concurrency-distributed/samples-java/src/Ch13/Consumer.java", first: 28, last: 54, caption: [Java, the applied memory a HashSet of ids, the duplicator wraps any Delivery and logs every call])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch13/Consumer.cs", first: 6, last: 54, caption: [C\#, the applied set under a gate, the duplicator wraps any action])

#listing("patterns-concurrency-distributed/samples-js/src/ch13-consumer.mjs", first: 1, last: 37, caption: [JavaScript, a Set holds the memory, the wrapped transport composes])

#listing("patterns-concurrency-distributed/samples-py/src/Ch13/consumer.py", first: 23, last: 50, caption: [Python, a set and two closures, the transport composes the same way])

#listing("patterns-concurrency-distributed/samples-lua/ch13_consumer.lua", first: 7, last: 38, caption: [Lua, a table keyed by id, Deliver reports false on the duplicate])

`Deliver` consults the applied set before doing anything, so a
redelivery costs one membership test and the effect happens once.
The shape of the memory is the idiom row: C indexes a `bool` array
by the id itself, legal because the fixture's ids are dense and
small, C\# keeps a `HashSet` behind a lock and counts calls outside
it, go a map behind a mutex, java a `HashSet` with no lock because
the walk is single-threaded, javascript a `Set`, python a `set`,
and lua a plain table keyed by id, with `Deliver` returning `false`
on the duplicate so the transport can observe what it carried. The
duplicator is a function wrapper in every language, a function
pointer taking the sink in C and a closure over the consume callable
everywhere else.

The idempotency key is the design decision that decides whether any
of this works. It must be stable across retries, which rules out
anything derived from the arrival, the wall clock, or a fresh random
id, and requires the sender to mint it once and resend it verbatim.
The dedup window is the second decision: these samples remember
forever, a production system bounds memory with a TTL or a sequence
floor below which everything is known applied.

#diagram([three delivery semantics, three failure points, one real option], length: 13pt, {
  let panels = (
    ((0.4, 7.5), [at-most-once], ([fire and forget], [a drop is gone], [right for metrics]), false),
    ((8.0, 15.6), [at-least-once], ([retry until acked], [lost ack = duplicate], [the only real delivery]), true),
    ((16.1, 23.5), [exactly-once effect], ([at-least-once + dedup], [duplicates suppressed], [effect happens once]), false),
  )
  for ((x0, x1), title, lines, hot) in panels {
    cdraw.rect((x0, 1.0), (x1, 6.0), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.4), title, size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, 4.2), lines.at(0), size: 6pt)
    cdraw.content(((x0 + x1) / 2, 3.1), lines.at(1), size: 6pt)
    cdraw.content(((x0 + x1) / 2, 2.0), lines.at(2), size: 6pt)
  }
})

== the outbox, and a crash in the middle

The transactional outbox pattern solves dual-write: an application
that writes to its database and to a broker in two steps can crash
between them, losing the message while committing the state. The
outbox writes the message into the same transaction as the state,
and a relay drains it afterward. The queue itself is the small half,
an array or list under a lock, and the relay is where at-least-once
becomes visible, so the relay is what the listings show.

The dry run: 10 envelopes, keys cycling k1, k2, k0, bodies b1
through b10, a relay configured to crash after 4 deliveries, a
transport that duplicates every third id.

- crash run: 4 delivered, 6 pending, 5 consume calls with id 3
  duplicated, 4 applied
- resume run: 6 more deliveries, 13 consume calls in total, ids 6
  and 9 duplicated, 10 applied
- the 10 effects land in send order, `k1:b1` through `k1:b10`
- the go lane's frozen test drives the same walk with its own
  constants, 10 envelopes under one key and one body, and pins the
  counts, both verified against the same implementation

#listing("patterns-concurrency-distributed/samples-c/src/Ch13/outbox.c", first: 30, last: 66, caption: [C, enqueue into a fixed array, the crash is a false return mid-loop])

#listing("patterns-concurrency-distributed/samples/ch13/messaging.go", first: 19, last: 40, caption: [Go, enqueue alongside the state, drain independently])

#listing("patterns-concurrency-distributed/samples/ch13/messaging.go", first: 43, last: 92, caption: [Go, drain, crash mid-flight, resume, redelivery is expected])

#listing("patterns-concurrency-distributed/samples-java/src/Ch13/Outbox.java", first: 52, last: 76, caption: [Java, the relay over an ArrayDeque, the crash a false return mid-loop, a clean drain true])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch13/Outbox.cs", first: 50, last: 84, caption: [C\#, the relay is a primary-constructor class draining a locked queue, the crash a typed exception])

#listing("patterns-concurrency-distributed/samples-js/src/ch13-outbox.mjs", first: 7, last: 58, caption: [JavaScript, the queue is an array, run is async so the transport can await])

#listing("patterns-concurrency-distributed/samples-py/src/Ch13/outbox.py", first: 29, last: 73, caption: [Python, the outbox is a list under a lock, the crash raises RelayCrashed])

#listing("patterns-concurrency-distributed/samples-lua/ch13_outbox.lua", first: 8, last: 49, caption: [Lua, table.remove pops the head, the crash returns false with a message])

The crash is a value in every lane, which is what makes the walk
scriptable: a false return in C, a boolean false in java too, a
`RelayCrashedException` in C\#, `ErrCrashed` in go, a thrown
`CrashError` in javascript, a raised `RelayCrashed` in python, and
lua's multiple return, `false` plus the message, the standing error
mapping for the one language here without exceptions. The resumed
relay is a fresh instance over the same queue, so redelivery is
structural, and the consumer from the previous section turns the
duplicates into single effects. This chapter is an exact-lane
chapter: the frozen go tests pin the counts and the crash-resume
shape, the six sibling trees pin the full ordered effect sequence,
and the cross-verification that tied the two together rode go
overlays against the frozen implementation, re-run at closeout.

#flow(
  [the outbox pipeline, the crash point, and where duplicates die],
  node((0, 0), [service]),
  node((2.2, 0), [db + outbox]),
  node((4.4, 0), [relay]),
  node((6.6, 0), [broker]),
  node((8.8, 0), [consumer]),
  node((5.5, 1.6), [crash], corner-radius: 2pt),
  edge((0, 0), (2.2, 0), "-|>", label: [one tx]),
  edge((2.2, 0), (4.4, 0), "-|>", label: [drain]),
  edge((4.4, 0), (6.6, 0), "-|>", label: [at least once]),
  edge((5.5, 1.6), (4.4, 0), "-|>", bend: 20deg, label: [resume, redeliver]),
  edge((6.6, 0), (8.8, 0), "-|>", label: [duplicates die]),
)

#callout("note", "ordering across retries", [
  The outbox drain is FIFO over one sender, and that is the entire
  ordering guarantee. Once multiple senders or multiple relay
  instances exist, global order is gone and per-key order becomes
  the achievable target, which is the next pattern's job.
])

== per-key ordering, lanes

Total order across a cluster is expensive and usually unnecessary.
What systems actually promise is per-key order: events about the
same entity, same user, same account, apply in sequence, while
events about different entities interleave freely. The
implementation is partitioning applied to lanes,
#xref-to("patterns", "partitioning") is the hash this chapter
reuses, fnv64a finished with the mix64 finalizer, so the high-bit
avalanche lesson carries over unchanged.

The dry run: 3 lanes, 6 keys, 40 rounds.

- the lane map is exact: A and B hash to lane 2, C, D, and E to
  lane 0, F to lane 1
- 240 events total, every key's processing sequence exactly 0
  through 39
- the lane map literals are pinned by the six new trees, the
  frozen go test asserts stability and per-key order without
  pinning the map

#listing("patterns-concurrency-distributed/samples-c/src/Ch13/lanes.c", first: 112, last: 160, caption: [C, one rendezvous channel per lane over mtx and cnd, thrd_join publishes the orders])

#listing("patterns-concurrency-distributed/samples/ch13/messaging.go", first: 136, last: 163, caption: [Go, one channel and one worker per lane, the placement hash picks the lane])

#listing("patterns-concurrency-distributed/samples/ch13/messaging.go", first: 165, last: 191, caption: [Go, fnv64a with the splitmix finalizer, close joins the workers and publishes the orders])

#listing("patterns-concurrency-distributed/samples-java/src/Ch13/Lanes.java", first: 46, last: 73, caption: [Java, a lane is an ArrayBlockingQueue of 1, the chapter 8 rendezvous in the stdlib, the mod unsigned because a mixed hash reads negative as a long])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch13/Lanes.cs", first: 17, last: 63, caption: [C\#, one unbounded Channel per lane, Task.WhenAll publishes])

#listing("patterns-concurrency-distributed/samples-js/src/ch13-lanes.mjs", first: 8, last: 57, caption: [JavaScript, per-lane arrays and wake callbacks, workers park as promises])

#listing("patterns-concurrency-distributed/samples-py/src/Ch13/lanes.py", first: 17, last: 53, caption: [Python, dispatch is a pure function of the key, the lanes are lists])

#listing("patterns-concurrency-distributed/samples-lua/ch13_lanes.lua", first: 64, last: 109, caption: [Lua, coroutine lanes park on empty queues, the scheduler wakes them])

Each key maps to exactly one lane, each lane has exactly one
worker, and FIFO order within the lane preserves the per-key
sequence without a global lock. The substrate is where the languages
split. Go hands each lane a native channel and publishes the order
slices through a `WaitGroup`. C\# hands each lane an unbounded
`Channel<Envelope>` drained by a task, `Task.WhenAll` the publish
edge. C builds the lane out of chapter 8's strict rendezvous shape,
a mutex and two condition variables per slot, and `thrd_join`
publishes. Java gets the same rendezvous shape from the stdlib, one
`ArrayBlockingQueue` of capacity 1 per lane closed by a poison
pill, `join` the publish edge. Javascript keeps a per-lane array
plus a wake callback, the worker a promise that parks when its
queue is empty. Python's walk is the pure function itself,
single-threaded, lane assignment and order deterministic facts
with no scheduler in the picture. Lua runs each lane as a coroutine
that parks on an empty queue. Two lanes carry the unsigned-modulo
trap, lua and java: the hash wraps to a signed 64-bit integer
there, floored `%` on a negative disagrees with go's unsigned
remainder, so lua's mapping goes through an unsigned-modulo helper
and java's through `Long.remainderUnsigned`, because the signed `%`
and even `Math.floorMod` both disagree with C's `uint64` remainder.
Every threaded lane keeps one writer per order slice, and the join
edge is what publishes those slices, chapter 6 applied without
ceremony.

#flow(
  [one lane per key, keys interleave across lanes, fifo within each lane],
  node((0, 2.1), [key user a]),
  node((0, 0.7), [key user b]),
  node((0, -0.7), [key user c]),
  node((0, -2.1), [key user d]),
  node((2.9, 1.4), [lane 0,#linebreak()one worker]),
  node((2.9, 0), [lane 1,#linebreak()one worker]),
  node((2.9, -1.4), [lane 2,#linebreak()one worker]),
  node((5.9, 0), [per-key fifo,#linebreak()0, 1, ..., 39]),
  edge((0, 2.1), (2.9, 0), "-|>"),
  edge((0, 0.7), (2.9, 0), "-|>", label: [hash(key) % 3]),
  edge((0, -0.7), (2.9, 1.4), "-|>"),
  edge((0, -2.1), (2.9, -1.4), "-|>"),
  edge((2.9, 1.4), (5.9, 0), "-|>"),
  edge((2.9, 0), (5.9, 0), "-|>"),
  edge((2.9, -1.4), (5.9, 0), "-|>"),
)

== poison messages

A message that consistently fails processing is poison: it fails,
retries, fails again, and in a naive relay wedges the lane behind it
forever. The standard shape is a retry budget per message, then a
dead letter queue, a side queue where the poison lands for human or
automated inspection while the lane flows on. Chapter 15 builds the
retry budget with backoff and jitter, the same machinery pointed at
a different failure, and the tradeoff is always the same: how many
retries before the system trades completeness for liveness. The
poison walk is the one place this chapter's trees stay silent, the
budget itself is chapter 15's sample, so the lifecycle here is the
diagram and the decision, not a fixture.

#flow(
  [the poison message lifecycle, and the lane flows on],
  node((0, 0), [message arrives]),
  node((1.9, 0), [process]),
  node((1.9, 1.4), [applied]),
  node((3.8, 0), [fails]),
  node((5.7, 0), [retry,#linebreak()budget--]),
  node((7.8, 0), [dead letter,#linebreak()queue]),
  edge((0, 0), (1.9, 0), "-|>"),
  edge((1.9, 0), (1.9, 1.4), "-|>", label: [ok]),
  edge((1.9, 0), (3.8, 0), "-|>", label: [error]),
  edge((3.8, 0), (5.7, 0), "-|>"),
  edge((5.7, 0), (1.9, 0), "-|>", bend: -40deg, label: [budget left]),
  edge((5.7, 0), (7.8, 0), "-|>", label: [budget spent]),
)

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [389], [libc plus threads.h],
  [fixed-array outbox, a lane a mutex plus two cnd, thrd_join publishes],
  [go], [145], [stdlib],
  [channel and worker per lane over the frozen hash, ErrCrashed, WaitGroup joins],
  [java], [310], [jdk 27 stdlib],
  [ArrayBlockingQueue rendezvous lanes closed by a poison pill, the lane mod through Long.remainderUnsigned],
  [c\#], [156], [bcl],
  [unbounded Channel per lane, WhenAll publishes, the crash a typed exception],
  [javascript], [114], [node stdlib, one sibling module],
  [ch12's hashString picks the lane, a parked promise wakes per callback],
  [python], [228], [stdlib only],
  [the lane walk is pure and single-threaded, the outbox a list under a lock],
  [lua], [371], [lib.lua harness],
  [coroutine lanes park on empty queues, umod fixes floored % on negatives],
)

sources: Heller, "Reliable Pattern: Outbox", for the dual-write
problem, Kleppmann, "Designing Data-Intensive Applications", chapter
8 for delivery semantics and the exactly-once-as-effect framing,
accessed 2026-09-08. Verified by the seven chapter legs: 3 Ch13 C
programs with 548 embedded checks, `go test` at 3 tests in
`patternsbook/ch13`, the java runner's 48 checks across 3 programs
in `samples-java/src/Ch13`, 6 xunit facts, node's 3 cases in
`test/ch13.test.mjs`, 3 python modules with 32 embedded checks, and
the lua runner's 12 ch13 rows.
