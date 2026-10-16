#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at citadel

Citadel closes the arc as its trading shop. The pinned page serves
114 questions against the companies index rollup of 77, updated
10.07.2026 with 8 added in the last 90 days, and it is the only page
in this arc that states its assistant policy outright, in its own
words: `no AI-assisted rounds in these reports`. The bank is the
arc's most even split between Software Engineer and Data Scientist,
statistics sits second behind coding the way it does nowhere else
here, and the visible cards keep handing back heaps, order books,
and C++ asked to run inside microseconds. This chapter maps that
loop, works 2 corroborated coding prompts test-first in go, the
order book with per-exchange bbo and cross-exchange nbbo queries
and the k-way merge of timestamp-sorted price feeds into a running
absolute price, both intern-tagged cards whose experience reports
sit on the same page, and walks its 2 most citadel-distinctive
design prompts in the #xref-to("repertoire", "design-prompts")
voice, the low-latency trading system and the low-latency metrics
and alerting platform.

== the loop map [DRILL]

Four stages, counted by the intro paragraph and the FAQ together:
technical screens carry 63 questions, online assessments 16, onsite
loops 15, and HR screens 4. Those 4 buckets sum to 98 against the
header's 114, so round tags overlap or leave questions untagged, and
the page publishes no reconciliation, the surface discipline this
arc keeps everywhere. The HR bucket is porous in a familiar way: the
FAQ's own sentence is `The HR-screen entries are coding problems rather than pure recruiter conversations.`,
the same boundary #xref-to("repertoire", "microsoft") draws with its
11, an hr slot at this company still expects code on the board.

The header counter itself: 114 questions, updated 10.07.2026, 8
added in the last 90 days, and 0 AI-assisted round tags, the page's
own words `no AI-assisted rounds in these reports`, the only arc
page that says so outright, so every report on it is a human round.
The question list shows 20 results on page 1 of 6. First-hand
experiences split by surface: the intro paragraph says 12, the
footer link says `All 20 Citadel interview experiences`, and 8 of
them are visible on page 1.

== the bank [DRILL]

Roles, each number named to its surface. The intro paragraph and
the FAQ agree: Software Engineer 48, Data Scientist 46, close to
even, with a few from site reliability, frontend and machine
learning engineering. The explore-more block says Software Engineer
61, Data Scientist 48, so Software Engineer is the disagreement, 48
against 61 on one page, and any claim cites its surface.

Categories, intro paragraph and FAQ together: Coding and Algorithms
39, Statistics and Math 17, Machine Learning 14, System Design 8,
Behavioral and Leadership 8. Statistics in second place is the
quant flavor, doordash's analytics category outranks coding
outright, this page keeps coding first and puts math directly
behind it, and the hard tail lives there. The explore-more block
counts Coding and
Algorithms 45, Statistics and Math 18, Machine Learning 16, every
row at or above the intro's, the 2 surfaces measure different
things and neither explains itself.

Difficulty, from the intro paragraph and the FAQ: 65 medium, 22
hard, 11 easy. The FAQ's own characterization is worth keeping verbatim for
where the hard tail sits: `The hard entries cluster in Statistics & Math, including computing summary statistics from a frequency array, and in a behavioral prompt asking candidates to discuss a project they are proud of and how they work.`
Coding problems are mostly medium and lean on classic structures,
the FAQ's closing note, and the visible cards bear it out.

== quirks of this loop [DRILL]

The C++ performance culture is the loudest thread. The visible card
`Refactor a Correct but Quadratic C++ Routine Under a Microsecond Budget`,
medium, 14 likes, 145 solved, dated Aug 17 2026, puts a correct
answer and a time budget in the same title, and the online
assessment experience `Optimizing a Correct C++ Function to Run
Under 100 Microseconds` reports the same shape from inside the
loop. Correct is table stakes here, the round grades the constant,
and the profile arithmetic of
#xref-to("repertoire", "systems-answers") is the drill that
prepares it.

The intern weight: 6 of the 20 visible cards are tagged Software
Engineer Intern, the order book and the k-way
price merge worked below, the shared-content file pair, the
dependency order, and the task queue. The bank's even
Software Engineer split reaches down into the intern pool, and the
two corroborating experiences for the worked prompts are both intern
reports from technical screens.

The visible experiences set the tempo, 8 of the claimed 12 or 20. A
deep dive on the classic orderbook problem in a technical screen
and a technical round 3 built on merging k timestamped price feeds
are the two worked prompts' own corroborating reports, heard from
this company before this chapter touched either shape. File
deduplication
with size checks and reference counts, a maddeningly vague data
sampling question, and a course schedule variant that didn't quite
run round out the coding screens. One onsite design round was
interrupted nonstop by a confused interviewer, and one rejected
candidate's two first rounds carried progressive matrix questions,
the only puzzle-shaped report on the page.

== recurring prompts [DRILL]

Where each recurring shape floors in this corpus, by chapter id:

The heap behind both worked prompts, the task queue card with
insert, delete and execute at 70 likes and 491 solved, and the
external merge sort with a heap, floor on
#xref-to("repertoire", "datastructures"), which owns the priority
queue from first principles, and the external merge sort's
sorting half floors on #xref-to("dsa", "sorting").

The dependency order card, `Return a Valid Dependency Order for
Named Tasks`, at 38 likes and 454 solved the most engaged locked
coding card on page 1, floors on the topological sort of
#xref-to("repertoire", "graphs").

The palindromic-block two-pointer card, the sliding-window top-k
card, and the greedy days-off conversion card floor on the window,
pointer, and greedy families of #xref-to("repertoire",
"algopatterns").

The statistics band, summary statistics from a frequency array
among the hard entries, floors on #xref-to("math", "statistics")
for the inference and #xref-to("repertoire", "math-answers") for
the interview-shaped answers.

The sampling card, `Choose 200 of a Million Records to Label,
Improving on Uniform Random Sampling`, floors on
#xref-to("kdd", "sampling"), which owns the stratified and
biased-sample machinery the card is really asking about.

The latency pair, both design walkthroughs below, floor on
#xref-to("repertoire", "estimation-answers") for the arithmetic
and #xref-to("repertoire", "systems-answers") for the runtime
economics. The idempotency tag on the trading system card floors
on #xref-to("repertoire", "distributed-answers"), and the
inventory availability card's isolation questions floor on
#xref-to("repertoire", "db-answers").

Absent homes, stated: the mex card, `Every MEX Reachable With At
Most One Bounded Increment`, hard at 171 solved, has no corpus
home, and neither does the two-player
terminal battleship card with its state machines, nor the
progressive matrix rounds from the experiences. The submatrix sum
card is a 2d prefix sum, close to the range queries of
#xref-to("dsa", "ranges") but not close enough to claim a floor.

== the order book with per-exchange bbo and cross-exchange nbbo, worked [TDD]

The visible card is titled `Order Book With Per-Exchange BBO and Cross-Exchange NBBO Queries`,
medium, 17 likes, 1 comment, 201 solved, dated Sep 10 2026, tagged
Software Engineering Fundamentals, Data Structure Design, and Heaps
and Priority Queues, and the experience report of a deep dive on
the classic orderbook problem says the real round went the same
way. The premium body is gated, so the prompt is authored from the
title alone: each venue keeps a price-level book, a query returns
one venue's best bid and offer, and a second query returns the
consolidated cross-venue quote, the nbbo, best bid as the max of
venue best bids, best ask as the min, and size re-summed at the
consolidated price across every venue quoting it.

Two structural decisions, each pinned by a test. Cancels drain a
level to zero without touching the heap, and the best query pops
the stale head lazily, so the cancel path stays a map write and
the heap repairs itself at read time. And a price joins its side's
heap only on the transition from empty to live, so a level drained
and revived never strands a duplicate the query would misprice:

#listing("interview-repertoire/samples/ch53-go/orderbook.go", first: 109, last: 130, caption: [add validates first, then a price enters its side's heap only on the empty-to-live transition, so the heap never holds two live copies of one level])

#listing("interview-repertoire/samples/ch53-go/orderbook.go", first: 153, last: 175, caption: [bestLevel pops drained levels at query time, cancel stays a map write, and bbo is two peeks])

The consolidated query is the card's second half, and the
re-sizing is the part worth saying slowly: the winning bid price
is the max over venue best bids, and its size is the sum of live
bid size at exactly that price across all venues, which is why the
walk visits every book even after the winner is known:

#listing("interview-repertoire/samples/ch53-go/orderbook.go", first: 177, last: 210, caption: [nbbo takes the best bid and ask across venues, then re-sizes each side at the consolidated price, summing every venue quoting it])

#diagram([three venue books, each side its own heap, the consolidated quote beneath], length: 13pt, {
  for pair in ((0.4, "venue a", "ask 105 x 3", "bid 100 x 5"), (6.4, "venue b", "ask 104 x 6", "bid 101 x 2"), (12.4, "venue c", "ask 106 x 1", "bid 100 x 7")) {
    let x0 = pair.at(0)
    cdraw.rect((x0, 5.0), (x0 + 5.2, 7.8), fill: luma(240), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.6, 7.2), [#pair.at(1)], size: 6.5pt)
    cdraw.rect((x0 + 0.3, 6.2), (x0 + 4.9, 6.9), fill: luma(225), stroke: luma(140), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.55), [#pair.at(2)], size: 6pt)
    cdraw.rect((x0 + 0.3, 5.4), (x0 + 4.9, 6.1), fill: luma(225), stroke: luma(140), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.75), [#pair.at(3)], size: 6pt)
  }
  cdraw.line((3.0, 5.0), (8.4, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.0, 5.0), (9.0, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 5.0), (9.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.4, 1.4), (12.6, 3.6), fill: luma(210), stroke: luma(120), radius: 0.02)
  cdraw.content((9.0, 3.0), [nbbo, the consolidated quote], size: 6.5pt)
  cdraw.content((9.0, 2.2), [bid 101 x 2, ask 104 x 6], size: 6.5pt)
  cdraw.content((9.0, 0.6), [best bid is the max of venue best bids, best ask the min,#linebreak()size re-summed at the consolidated price across every venue quoting it], size: 6pt)
})

The suite is 7 test functions under `go vet` and `go test -race`: a
named-facts table for one-venue bbo, the drain-and-revive pin, the
nbbo table whose size-aggregation row cancels the leader and
watches the size jump from 2 to 12 across two venues, the
constructor and argument error batteries, a seeded differential
that drives 600 random adds and cancels over 3 venues and checks
every step against a brute scan of the level maps, and a race test
with 6 goroutines adding, canceling, and querying concurrently:

#listing("interview-repertoire/samples/ch53-go/orderbook_test.go", first: 175, last: 207, caption: [the differential: seeded adds and cancels over 3 venues, every step checked against a brute scan of the level maps])

The red run came first, all 7 failing against stubs that answered
every call with the not-implemented error before a heap existed.

== merging k timestamp-sorted price feeds, worked [TDD]

The visible card is titled `Merge K Timestamp-Sorted Price Feeds into a Running Absolute Price`,
medium, 21 likes, 210 solved, dated Sep 20 2026, tagged Coding and
Algorithms and Heaps and Priority Queues, and the intern experience
`Merging K Timestamped Price Feeds into a Running Price in
Technical Round 3` reports it straight from a technical screen. The
premium body is gated, so the shape is authored from the title: k
feeds, each sorted by timestamp, merge them into one stream ordered
by timestamp, and the running absolute price after any event is the
price of the most recent event, a last-writer-wins quote.

The tie rule is the one semantic decision, and it is pinned
end to end: two feeds quoting the same timestamp emit in feed
order, lower index first, so the later feed's price wins as the
running price at that instant. The heap orders cursors by
timestamp, then by feed index:

#listing("interview-repertoire/samples/ch53-go/mergefeed.go", first: 21, last: 38, caption: [the cursor heap, earlier timestamp first, lower feed index on exact ties])

The merge loop replaces the heap root in place and fixes when the
feed still has ticks, pops it when the feed runs dry, one log k
step per event:

#listing("interview-repertoire/samples/ch53-go/mergefeed.go", first: 61, last: 72, caption: [the merge loop, replace-and-fix while the feed has ticks, pop when it runs dry])

The running-price query is a binary search for the last tick at or
before the asked timestamp, the same last-writer-wins rule read
backward through the merged stream, and an unsorted feed is
rejected up front with its own error. The differential is the
interesting test: flatten the feeds in feed order and run one
stable sort by timestamp alone, which is exactly the tie rule
stated as a sort, and compare every tick plus a random
`PriceAt` against a linear scan:

#listing("interview-repertoire/samples/ch53-go/mergefeed_test.go", first: 103, last: 124, caption: [the differential, flatten in feed order, one stable sort by timestamp, ties fall out in feed order])

The suite is 6 test functions under `go vet` and `go test -race`:
the hand-derived table with equal timestamps inside one feed, the
tie-break pin that reads the running price back through PriceAt,
the error and empty batteries, the stable-sort differential over
400 seeded rounds, and the PriceAt boundary table. The red run
came first, all 6 failing against a stub that returned the
not-implemented error.

== the low-latency trading system [DRILL]

From the visible card, `Design a low-latency trading system`,
hard, 151 likes, 1575 solved, dated Aug 9 2025, the page flagship
by a wide margin on both counts, tagged Trading Systems and
Distributed Transactions and Idempotency. Requirements: a quote
observed on the wire becomes an order inside a fixed microsecond
budget, no wrong trade is ever the price of a fast one, so risk
invariants hold at any speed, market data is lossless or
explicitly resynchronized, and the whole decision path replays
deterministically for post-trade analysis.

The estimation, assumptions stated, arithmetic this chapter's own
in the method of #xref-to("repertoire", "estimation-answers").
Assume 200 symbols each quoting 1000 updates a second at peak:
200k market-data packets a second inbound. A packet averages 100
bytes, so 20 MB a second, bandwidth is trivial and saying so is
the point, the wall is per-packet cost. A syscall pair per
packet at about 2 microseconds is 0.4 seconds of cpu per second of
wall on one core, so the plain socket path is already spent at
this rate and the choice is kernel bypass or busy-polled receive,
the epoll economics of #xref-to("repertoire", "systems-answers")
pushed past polling into pinning. The order side is quieter,
assume 5k orders a second peak against a 10 microsecond
tick-to-trade budget: 4 network hops at about 1 microsecond each,
1 to normalize into the book, 2 for the signal, 1 for the inline
risk check, 1 to serialize and hand to the gateway, the budget
closes with a microsecond of slack and the network owns almost
half of it.

#flow(
  [market data and orders on separate paths, the budget spent where the wire is],
  node((0, 0), [exchange multicast, #linebreak() increments]),
  node((0, 1.2), [feed handler, #linebreak() normalize, build book]),
  node((0, 2.4), [strategy, #linebreak() one writer per symbol]),
  node((0, 3.6), [risk gate, #linebreak() inline, in-memory limits]),
  node((0, 4.8), [order gateway, #linebreak() sequence, checksum]),
  node((2.4, 1.2), [snapshot store, #linebreak() drop and resync]),
  node((2.4, 4.8), [exchange order port, #linebreak() acks return]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.4, 4.8), "->"),
  edge((2.4, 1.2), (0, 1.2), "-|>", label: [resync]),
)

The walk over hops: the feed handler drains multicast increments
into the per-symbol book, the same level-and-heap structure the
first worked prompt built, and a handler that falls behind drops
its incremental state and rebuilds from the snapshot store, market
data is never queued, stale data trades as real risk. The strategy
keeps
one writer per symbol so the book read that fires a signal is
never a lock away. The risk gate is inline on the order path, an
in-memory position and credit check at about a microsecond,
because an asynchronous risk check is a wrong trade at high speed.
The gateway sequences orders, checksums, and sends, and the ack
returns along the same path to update position.

The bottleneck, volunteered: the kernel and the nic, the wire
itself, which is why the design's one exotic spend is bypass and
everything upstream of it is deliberately boring. Second order:
the lock domain on the book, dissolved by the single-writer rule.

The traps, 1 line each. Timestamps come from the exchange clock,
local clocks measure nothing comparable. A retried order carries
an idempotent client order id, the delivery semantics of
#xref-to("repertoire", "distributed-answers"), or the retry is a
double trade. Allocation is preallocated and pooled, a garbage
collection pause inside the budget is a design defect, and the
replay log is written off the hot path, never on it.

== the low-latency metrics and alerting platform [DRILL]

From the visible card, `Design a Low-Latency Metrics and Alerting Platform`,
medium, 53 likes, 571 solved, dated Jul 12 2026, the only
Senior+-tagged card on page 1, tagged Observability and Storage
and Sharding. Requirements: thousands of services ingest samples,
queries over windows answer inside a second, alerts evaluate
within seconds of the sample that tripped them, a broker or node
loss costs at most a reshard, and retention runs years at coarse
granularity.

The estimation, assumptions stated, arithmetic this chapter's own.
Assume 5000 services with 200 active series each: 1 million
series, sampled every 10 seconds, so 100k samples a second and
8.6 billion a day. At 16 bytes a value the raw day is about 138
GB before tags, so retention tiers carry the load: raw for 3 days
near half a terabyte, 5-minute rollups for 30 days at 288 rows a
series a day, about 4.6 GB a day, and 1-hour rollups for 2 years
at 24 rows a series a day, about 300 GB all in. Alert evaluation:
assume 20k rules averaging 50 series each, 1 million series-rule
visits per 10-second window, 100k a second, each an O(1) read
against a window maintained incrementally at ingest, which is why
the evaluator sits beside the data instead of querying it.

#flow(
  [hash series to shards, evaluate beside the data, query fans out last],
  node((0, 0), [services, #linebreak() 1M series]),
  node((0, 1.2), [ingest gate, #linebreak() cardinality budget]),
  node((0, 2.4), [series routers, #linebreak() hash by series id]),
  node((0, 3.6), [shard writers, #linebreak() wal, then flush]),
  node((2.4, 3.6), [alert evaluator, #linebreak() windows in memory]),
  node((2.4, 4.8), [alert manager, #linebreak() dedupe, group, route]),
  node((0, 4.8), [tsdb and object store, #linebreak() raw, 5m, 1h tiers]),
  node((0, 6.0), [query api, #linebreak() fan out, merge]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (2.4, 3.6), "->"),
  edge((2.4, 3.6), (2.4, 4.8), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
)

The walk over hops: samples pass an ingest gate that enforces a
per-tenant series budget and rejects new cardinality past it, the
rejection is the design's most important message. Routers hash by
series id so one series lives on exactly one shard, the
consistent-hash placement that keeps a shard failure to a reshard.
Shard writers append to a write-ahead log, ack, and flush to the
tiered store. The alert evaluator subscribes at the router,
maintains each rule's window incrementally, and hands a crossing
to the alert manager, which dedupes, groups, and routes, off the
query path entirely. The query api fans out to shards only for
what it cannot answer from rollups, and merges on the way back.

The bottleneck, volunteered: the query-time fan-out over
high-cardinality tags, one unpriced tag multiplies the series
count by its distinct values, fought with the ingest budget at
the front door, because the shard that must scan it is the shard
everyone waits on.

The traps, 1 line each. Counter resets inside a rate need reset
detection, not a restarted maximum. Out-of-order samples are
accepted inside a watermark and rejected past it. Flapping alerts
get for-until windows and hysteresis, an alert that fires on one
sample is a pager incident factory. Evaluation lives beside the
series shard, a query-path evaluator is an outage inside the
outage story, and the wal is acked before the sample is believed.

#callout("pitfall", "the bank where statistics is the second sport", [
  Statistics and Math holds 17 questions against Coding and
  Algorithms at 39, the intro paragraph's own order, and the
  difficulty block puts the hard tail there too. Where doordash's
  analytics category outranks coding outright, this page keeps
  coding first and puts math directly behind it. Here the frequency
  array and the 200-of-a-million sampling card are mainline
  preparation, the inference of #xref-to("math", "statistics")
  beside the shapes of #xref-to("repertoire", "math-answers"),
  and the FAQ reports coding and design problems in both the
  technical screen and the onsite.
])

sources: every count in this chapter traces to
`ref/prachub/citadel/page.md`, fetched 2026-10-15 from
prachub.com/companies/citadel/ and pinned verbatim, through the
transcription at `ref/prachub/citadel/facts.md`, and each count
names its surface, the header counter, the intro paragraph, the
FAQ, the explore-more block, or a visible card row, because the
surfaces disagree, 114 questions on the page against the companies
index rollup of 77, and 12 experiences in the intro against 20 in
the footer. The page's statement `no AI-assisted rounds in these
reports` is quoted from its own bytes, the only arc page that
carries it. The worked prompts are authored from visible truncated
card titles only, premium-gated bodies never quoted or
reconstructed, and both design walkthroughs carry their arithmetic
as stated assumptions in the
#xref-to("repertoire", "estimation-answers") method, arithmetic
this chapter's own, not numbers from the page. No other online
source was consulted.
