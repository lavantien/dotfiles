#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at doordash

DoorDash is the arc's data-heavy engineering company. The pinned page
serves 312 questions while the companies index rolls the same company
up to 237, updated 10.01.2026 with 35 added in the last 90 days, and
it is the only page in this arc where a data category outranks coding:
Analytics and Experimentation holds 74 questions against Coding and
Algorithms at 65. The bank splits almost evenly between Software
Engineer and Data Scientist, the loop leans on working services over
one-function algorithms, and the refund thread runs through a dozen
cards. This chapter maps that loop, works its 2 most engaged coding
prompts test-first in go, courier pay across overlapping deliveries
with peak multipliers and the round-robin debug that ends in
consistent hashing, and walks its 2 most doordash-distinctive design
prompts in the #xref-to("repertoire", "design-prompts") voice,
paying dashers reliably while the payment service is down, and
processing orders through a directed acyclic graph with completion
and timeout refunds.

== the loop map [DRILL]

Three stages, counted by the intro paragraph and the FAQ together:
onsites carry 141 questions, technical screens 131, and online
assessments 5. Those 3 buckets sum to 277 against the header's 312,
so the round tags overlap or leave questions untagged, and the page
publishes no reconciliation, the surface discipline this arc keeps
everywhere. HR screens are not stated on this page at all, so this
chapter says absent where other arc chapters count one. The header
counter itself: 312 questions, updated 10.01.2026, 35 added in the
last 90 days, 1 AI-assisted round tag in the whole set. The question
list shows 20 results on page 1 of 16. First-hand experiences split
by surface: the intro paragraph says 41, the footer link says
`All 57 DoorDash interview experiences`, and 8 of them are visible
on page 1.

The stage character is the FAQ's own sentence, quoted verbatim:
`Coding, service-building, and behavioral prompts show up in both the screen and the onsite, while the heavier design work, including the refund workflow modelled as a directed acyclic graph, clusters in onsite rounds.`
Two interview guides on the site cover the engineering and data
science tracks, the FAQ's closing note on the loop.

== the bank [DRILL]

Roles, with each number named to its surface. The intro paragraph
and the FAQ agree: Software Engineer 146, Data Scientist 118, an
unusually even split for a company page. The FAQ adds that Machine
Learning Engineer, Analytics Engineer, and Product Analyst together
account for the remaining 13. The explore-more block says Software
Engineer 181, Data Scientist 118, so Software Engineer is the
disagreement, 146 against 181 on one page, and any claim cites its
surface.

Categories, intro paragraph: Analytics and Experimentation 74,
Coding and Algorithms 65, System Design 40, Behavioral and
Leadership 37, SQL and Python work 28. Analytics is the single
largest category, the only arc page where a data category outranks
coding. The explore-more block counts Analytics and Experimentation
74, Coding and Algorithms 67, System Design 49, Behavioral and
Leadership 45, Software Engineering Fundamentals 34, Data
Manipulation 28, every row at or above the intro's, so the 2
surfaces measure different things and neither explains itself.

Difficulty, from the page's spread block: 181 medium, 76 hard, 20
easy, about a quarter of the set rated hard. The FAQ's own
characterization is worth keeping verbatim for its shape:
`Difficulty tends to come from scope rather than algorithmic trickery: several prompts ask for a working multi-service workflow with failure handling rather than one function.`
Seniority, FAQ block: only 23 questions are tagged Senior+, so the
bulk of the bank aims at general levels.

== quirks of this loop [DRILL]

The ai pair-programming thread is louder than its tag. One recorded
question carries the AI-assisted tag, and 4 of the 8 visible
experience entries mention an ai coding or ai-assisted round, an
ai-coding onsite rejected after system design, a bootstrap screen
with a consistent hashing debug round and an ai coding dag, a
five-round onsite with a live ai coding challenge, and a four-round
onsite with an ai-assisted coding round. The FAQ's advice is quoted
verbatim: `Treat it as something to be ready for rather than something to expect.`
The norms of working with an assistant in a graded round floor on
#xref-to("repertoire", "observed-answers").

The refund thread is the densest family on the page. The visible
cards carry a dag with completion and timeout refunds, 2 interacting
services carrying out a realistic refund flow, a late-order refund
workflow built as separate services and again as a live
api-connected dag, an order-exception microservice with explicit
refund policies, and a donation system with reliable payment and
payout tracking. Payments and ledgers with distributed idempotency
is the house style, and both design walkthroughs below sit inside
it.

The experiences set the tempo, 8 visible of the claimed 41 or 57. A
dasher pay phone screen opened on a surprise sweep line with a peak
windows follow-up, the exact screen the first worked prompt below
reconstructs. A senior loop's menu review design got stuck in
schema details until minute 45, the trap the fallback design card
teaches against. One onsite packed resilience, payments, and
concurrent dispatch into a single loop, which matches a bank where
the medium difficulty comes from scope.

== recurring prompts [DRILL]

Where each recurring shape floors in this corpus, by chapter id:

The interval family behind the pay cards, courier pay over
overlapping deliveries with peak multipliers and daily pay from
order events with double rate in peak windows, floors on
#xref-to("repertoire", "algopatterns"), which owns the interval
scheduling and sweep shapes.

Consistent hashing and the partitioning it serves floor on
#xref-to("patterns", "partitioning"), and the debug card worked
below is its on-ramp.

Delivery semantics, retries, and idempotency keys behind every
refund and payment card floor on
#xref-to("repertoire", "distributed-answers"), and money as integer
cents in an append-only ledger floors on
#xref-to("repertoire", "db-answers").

The dag workflow family, job scheduling with coordination, floors
on #xref-to("repertoire", "design-answers") for the shape and
#xref-to("patterns", "messaging") for the outbox and per-key lanes
that keep node transitions atomic.

The bootstrap api cards, aggregating downstream services into the
right http status and partial upstream results with explicit
failure policies, floor on
#xref-to("repertoire", "network-answers").

The ai pair-programming rounds floor on
#xref-to("repertoire", "observed-answers").

The behavioral battery floors on the register of
#xref-to("repertoire", "behavioral-answers").

== courier pay across overlapping deliveries, worked [TDD]

The visible card is titled `Courier Pay From Overlapping Deliveries With Peak-Window Multipliers`,
hard, 23 likes, 2 comments, 206 solved, dated Oct 1 2026, the most
liked unlocked card on page 1. The premium body is gated, so the
prompt is authored from the title alone, and the phone screen
report above says the real round opened on a sweep line and
followed up with peak windows, which fixes the shape: deliveries
each occupy a half-open minute interval `[start, end)` with a cents
per minute rate, peak windows carry a multiplier in percent, and
the job is the dasher's total pay in integer cents.

Four semantic decisions, each pinned by a test. Overlapping
deliveries stack their rates, a dasher carrying 2 orders earns both
pays for the overlap, that is the point of stacked deliveries.
Overlapping peaks take the maximum multiplier, a peak is a market
condition, so 2 concurrent peaks at 150 and 200 percent pay 200,
never the 350 a product would compound. Boundaries are half-open, a
delivery ending at minute 10 and a peak starting at 10 never
interact. And the money rule of
#xref-to("repertoire", "db-answers") holds throughout: rates are
integer cents per minute, multipliers integer percent, the sweep
accumulates rate times minutes times percent, and one floor
division by 100 happens at the very end, because per-segment
rounding drifts, the pin is 2 disjoint 7-minute deliveries at 1
cent inside one 150 percent peak, 21 cents under the single
division against 20 under per-segment floors.

The sweep itself walks the union of both families' boundaries.
Every delivery and peak endpoint goes into one sorted, deduplicated
list of cut points, and inside each segment the active delivery
set and the active peak set are constant, so the segment
contributes rate sum times minutes times max multiplier:

#listing("interview-repertoire/samples/ch51-go/courierpay.go", first: 26, last: 64, caption: [the sweep: one sorted boundary list from both interval families, each segment constant, one final floor division])

The oracle shares no code with the sweep and derives its
expectations from the statement, one minute at a time:

#listing("interview-repertoire/samples/ch51-go/courierpay_test.go", first: 82, last: 108, caption: [the minute oracle: per minute the summed active rate and the max active multiplier, the same single final division])

#diagram([two interval families, one boundary list, constant segments between cuts], length: 13pt, {
  cdraw.rect((0.6, 8.4), (22.8, 9.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.7, 8.8), [minutes, the shared axis of both families], size: 6pt)
  for x in (3.4, 8.2, 12.6, 17.4, 21.2) {
    cdraw.line((x, 8.4), (x, 2.6), stroke: (paint: luma(170), dash: "dashed"))
  }
  cdraw.rect((3.4, 6.4), (12.6, 7.2), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((8.0, 6.8), [delivery a, 100 c per min], size: 6pt)
  cdraw.rect((8.2, 5.2), (17.4, 6.0), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((12.8, 5.6), [delivery b, 100 c per min], size: 6pt)
  cdraw.rect((3.4, 4.0), (12.6, 4.8), fill: luma(225), stroke: luma(120), radius: 0.02)
  cdraw.content((8.0, 4.4), [peak, 150 percent], size: 6pt)
  for pair in ((3.4, 8.2, "100"), (8.2, 12.6, "150 of 200c"), (12.6, 17.4, "100")) {
    cdraw.content(((pair.at(0) + pair.at(1)) / 2, 3.2), [#pair.at(2)], size: 6pt)
  }
  cdraw.line((3.4, 2.6), (22.8, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.7, 1.9), [cuts at every endpoint of either family, each segment aggregates once], size: 6pt)
})

The suite is 4 test functions under `go vet` and `go test -race`: a
9-row table of named facts, the empty-input pin, the error battery
for reversed and zero-length windows, negative rates, and
non-positive multipliers, and a seeded differential that drives 500
random scenes against the minute oracle. The red run came first,
all 4 failing against a stub that answered every call with the
not-implemented error before the sweep existed.

== the round-robin debug and the hash ring, worked [TDD]

The visible card is titled `Debug a Round-Robin Load Balancer, Then Implement Consistent Hashing`,
medium, 12 likes, 1 comment, 140 solved, dated Sep 7 2026. The
premium body is gated, so the two-part shape is authored from the
title: a hunt that pins a defect in a working round-robin, then the
consistent-hash replacement the system actually needs, the
partitioning logic of #xref-to("patterns", "partitioning").

The artifact under audit is a working modulo round-robin, and its
defect is weight blindness:

#listing("interview-repertoire/samples/ch51-go/naive.go", first: 8, last: 23, caption: [the artifact under audit: the weight field is never read, the counter cycles names])

The hunt test pins the defect as behavior: over 60 draws a 5 to 1
capacity pair splits 30 to 30, capacity says 50 to 10, and the
small backend melts under 5 times its share. The fix is smooth
weighted round-robin, every backend accrues its weight per draw,
the leader is picked and pays back the total, so a 2 to 1 pair
interleaves a, b, a and a 5 to 1 pair spreads its light node
mid-cycle instead of in one burst:

#listing("interview-repertoire/samples/ch51-go/balance.go", first: 51, last: 65, caption: [smooth weighted round-robin: accrue weights, pick the leader, pay back the total, one mutex for the counter])

The second half of the card replaces routing for key-addressed
traffic. Modulo by backend count reshuffles every key when the
fleet changes size, so the ring hashes each backend onto 160
virtual nodes per weight and a key walks clockwise to the first
vnode, one binary search over a sorted slice, no map iteration
anywhere on the hot path, which is what makes the placement
deterministic across processes:

#listing("interview-repertoire/samples/ch51-go/balance.go", first: 122, last: 134, caption: [get by one binary search over the sorted vnodes, the wraparound to index zero])

The hash detail the suite forced: fnv-1a over a name plus a
replica counter has fnv's own weakness, inputs differing in one
final byte land a constant offset apart, so the first cut's vnodes
clustered, one node held 59 percent of 3000 keys and adding a
fourth node moved 49 percent of them. A murmur-style finalizer mix
over the combined state is the fix, avalanche before the ring:

#listing("interview-repertoire/samples/ch51-go/balance.go", first: 145, last: 171, caption: [the vnode hash and the finalizer, fnv over name and replica then the mix that scatters it])

The property the card is really about is minimal disruption, and
it is pinned exactly:

#listing("interview-repertoire/samples/ch51-go/balance_test.go", first: 215, last: 248, caption: [the disruption law: adding a node may only move keys onto the new node, and the moved share sits in the 1-in-4 neighborhood])

Measured on the committed suite: 3 equal nodes hold 1014, 980, and
1006 of 3000 keys, adding a fourth moves 212 of 1000 keys, 21.2
percent against the ideal 25, and a 3 to 1 weight pair gives the
heavy node 2998 of 4000, 74.95 percent. The suite is 12 test
functions, including the removal law that only the removed node's
keys move, determinism across identically built rings, the error
battery, and 2 race tests, concurrent next under the smooth counter
and concurrent get while a node churns on and off the ring. The
red run came first, 15 of 16 failing against stubs while the hunt
pin on the naive artifact stayed green, the defect it documents
still shipped.

== paying dashers when the payment service is down [DRILL]

From the visible card, `Paying Dashers Reliably When the Payment Service Is Unavailable`,
medium, 10 likes, 0 comments, 135 solved, dated Sep 23 2026.
Requirements: a delivery completion produces pay exactly once, a
payout may lag without a ceiling the dasher can see, the dasher
balance reflects earned pay immediately, every payout is auditable,
and a 30 minute payment provider outage at peak breaks nothing.

The estimation, assumptions stated, arithmetic this chapter's own
in the method of #xref-to("repertoire", "estimation-answers").
Assume 2 million dashers active in a week and 500 thousand inside
the evening peak hour, each finishing 2.5 deliveries in that hour:
1.25 million completions in the peak hour, about 350 a second, call
the band 100 to 350 pay intents a second. A ledger row at 200 bytes
is 250 MB in the peak hour, about 6 GB a day, 2 TB a year raw, so 3
years of history is 6 TB with a 90 day hot window near 540 GB.
Buffering is the cheap part: a 30 minute outage at 350 a second is
630 thousand pending intents, about 630 MB of queue, so the design
spends nothing clever on storage and everything on the contract.

#flow(
  [the intent is the money, the provider is a lagging side effect],
  node((0, 0), [dispatch, #linebreak() delivery complete]),
  node((0, 1.2), [pay-intent writer, #linebreak() idempotency key, #linebreak() unique index]),
  node((0, 2.4), [append-only ledger, #linebreak() cents, amount snapshotted]),
  node((2.2, 2.4), [dasher balance, #linebreak() credit on intent]),
  node((0, 3.6), [outbox relay]),
  node((0, 4.8), [payment queue, #linebreak() retry, backoff]),
  node((0, 6.0), [provider adapter, #linebreak() down, so queue grows]),
  node((0, 7.2), [settle + reconcile, #linebreak() intents against acks]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (2.2, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
  edge((0, 6.0), (0, 7.2), "->"),
)

The walk over hops: dispatch emits delivery-completed, the
pay-intent writer keys on dasher id plus delivery id against a
unique index, so a replayed event is a no-signal duplicate, and the
row snapshotts the amount in cents at creation because peak
multipliers are config that changes, the intent is the money. The
dasher balance credits on the intent, so the visible balance never
waits on the provider. The outbox relay moves intents to the
payment queue without a distributed transaction, the delivery
semantics and the outbox shape are
#xref-to("repertoire", "distributed-answers") and
#xref-to("patterns", "messaging"). The queue retries with backoff
while the provider is down, the adapter settles confirmations back
onto the ledger, and the reconciler sweeps the gap between intents
and acknowledgements.

The bottleneck, volunteered: the provider's throughput and
availability, never our write path. The number to dashboard is
queue depth against payout latency, the poison intents that fail
repeatedly land in a dead letter queue with a support owner, and
the honest statement is at-least-once delivery with an
exactly-once effect bought by the idempotency key, never a claim of
exactly-once delivery.

The traps, 1 line each. Compute the amount at intent time, a
multiplier change mid-flight must never move an earned pay. Timeouts
on provider acks are retried by key, a slow ack is a duplicate
payout without one. Partial batch acknowledgements reconcile per
intent, never per batch. The dasher asking where the pay is, is the
ledger's real consumer, support tooling is a requirement here.
Clock skew across services means no local deadline decides a
refund, the ledger's own timestamps do.

== orders through a refund dag [DRILL]

From the visible card, `Process Orders Through a DAG with Completion and Timeout Refunds`,
medium, 4 likes, 0 comments, 70 solved, dated Sep 10 2026. The
refund family's systems-engineering card, beside the two-service
and separate-services cards on the same page. Requirements: an
order walks a dag of stages, validate, prepare, assign, pickup,
deliver, with a parallel branch under assign, each stage can
complete, fail, or time out, a cancellation after payment triggers
a completion refund, a stage over its sla triggers a timeout
refund, and an order's position is queryable for support.

The estimation, assumptions stated, arithmetic this chapter's own.
Assume 250 thousand orders in the evening peak hour, about 70 a
second, each walking 7 node transitions across the dag's paths:
about 490 transitions a second peak. Workflow state at 1 KB per
order is 250 MB per peak hour of live instances, small. The number
that decides the shape is timers: 4 timed stages averaging 15
minutes outstanding at 70 orders a second inflow is about 250
thousand concurrent timers, which forbids one polled row per timer
and demands time-partitioned timer shards, a wheel per shard, and
timers enqueued at their deadline's shard.

#flow(
  [nodes as queues, timers as shards, refunds as one idempotent service],
  node((0, 0), [order api]),
  node((0, 1.2), [workflow store, #linebreak() dag instance, born version]),
  node((0, 2.4), [node workers, #linebreak() one queue per node type]),
  node((2.2, 2.4), [timer shards, #linebreak() wheel, sla deadlines]),
  node((0, 3.6), [advance, #linebreak() per-path order, branches commute]),
  node((0, 4.8), [refund service, #linebreak() key order plus reason]),
  node((0, 6.0), [payment ledger, #linebreak() cents, append only]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (2.2, 2.4), "-|>", label: [sla armed]),
  edge((2.2, 2.4), (0, 4.8), "-|>", label: [timeout]),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "-|>", label: [cancelled after pay]),
  edge((0, 4.8), (0, 6.0), "->"),
)

The walk over hops: the order api creates the dag instance under a
born version, the workflow store is the one durable authority on
position, each node type drains its own queue and reports
completion, advance follows the dag's edges with ordering only
inside a path since parallel branches commute, and the outbox
pattern of #xref-to("patterns", "messaging") keeps a node
transition and its emitted message atomic. Arming a sla enqueues a
timer at the deadline's shard, a fired timer that finds the node
already completed is a no-op, one that finds it late emits the
timeout refund. Both refund triggers funnel into one idempotent
refund service keyed by order id plus reason code, so a
cancellation racing a timeout produces one refund, and the ledger
is the same append-only cents store the previous walkthrough built.

The bottleneck, volunteered: the prepare node's queue at dinner
peak, the kitchen is the physical constraint the software wraps,
so the prepare queue gets its own depth alert and the dag admits
backpressure by slowing admission, an order rejected early is
cheaper than one refunded late.

The traps, 1 line each. A dag version change must leave in-flight
orders on their born version, mixed fleets are the norm during a
deploy. Node retries are keyed, a replayed transition is a no-op.
Poison orders park after n attempts with the support timeline
attached, they never loop. A refund that itself fails retries
forever and alerts, compensation has no compensation. Per-order
visibility is a requirement at write time, reconstructing history
from logs after the support ticket exists is the failure mode.

#callout("pitfall", "the bank where analytics outranks coding", [
  Analytics and Experimentation holds 74 questions against Coding
  and Algorithms at 65, the intro paragraph's own order, and the
  role split is 146 Software Engineer against 118 Data Scientist.
  Every other arc page puts coding first by a wide margin. At this
  company the sql and experimentation fluency of
  #xref-to("repertoire", "db-answers") is not a side quest, it is
  the single largest category on the page, and the loop map says
  those prompts appear in both the screen and the onsite.
])

sources: every count in this chapter traces to
`ref/prachub/doordash/page.md`, fetched 2026-10-15 from
prachub.com/companies/doordash/ and pinned verbatim, through the
transcription at `ref/prachub/doordash/facts.md`, and each count
names its surface, the header counter, the intro paragraph, the
FAQ, the explore-more block, or a visible card row, because the
surfaces disagree, 312 questions on the page against the companies
index rollup of 237, and 41 experiences in the intro against 57 in
the footer. The worked prompts are authored from visible truncated
card titles only, premium-gated bodies never quoted or
reconstructed, and both design walkthroughs carry their arithmetic
as stated assumptions in the
#xref-to("repertoire", "estimation-answers") method, arithmetic
this chapter's own, not numbers from the page. No other online
source was consulted.
