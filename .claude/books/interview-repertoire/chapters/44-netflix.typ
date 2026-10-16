#import "../../theme/lib.typ": listing, callout, xref-to, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at netflix

Netflix is the ads-and-autonomy entry in this arc. The pinned page
serves 122 questions updated 10.14.2026, publishes no numeric round or
difficulty counts anywhere, and carries its loop in FAQ prose instead.
What the page does show, loudly, is an ads cluster: ad frequency
capping, a distributed frequency-capping service, an ad pacing system,
3 cards that are really 1 prompt about rate limits keyed by viewer and
slot. This chapter maps that loop, works its 2 most repeated coding
prompts test-first, a key-value store with per-key TTL and eviction in
go and a live-scored playlist in javascript, and walks its 2 biggest
design prompts in the #xref-to("repertoire", "design-prompts") voice,
frequency capping at scale and a shared-cluster ML job scheduler.

== the loop map [DRILL]

The page's FAQ states the whole loop in 1 sentence, quoted verbatim:
the loop `typically begins with a recruiter screen, followed by a technical phone or take-home screen, then a multi-interviewer onsite or virtual loop of roughly four to six rounds, and a hiring-committee decision.`
That prose is the only round source. The header counter says 122
questions and an updated date of 10.14.2026, the question list shows 20
results on page 1 of 7, the footer link says `All 23 Netflix interview experiences` while the intro paragraph carries no experience count,
and the added-in-last-90-days field is not displayed at all. 8 of the
23 experiences are visible on page 1, the rest sit behind the same gate
as list pages 2 through 7.

Role by role, from the same FAQ block: Software Engineer loops
emphasize live coding and system design, Data Scientist loops focus on
SQL, causal inference, experimentation design, and product metrics,
Machine Learning Engineer rounds probe model training, deployment,
optimizers, and transformer details, Data Engineer interviews test data
modeling, rollout, and aggregation patterns. Culture and ownership
rounds run inside every role's loop, the FAQ's own emphasis, evaluating
fit with a high-autonomy environment that prizes direct feedback.

== the bank [DRILL]

The surfaces disagree and each number here names its surface. The intro
paragraph counts Software Engineers at 42 questions, Data Scientists at
28, Machine Learning Engineers at 7, Data Engineers at 3. The
explore-more block says Software Engineer 76 and Data Scientist 28. The
SWE count is the disagreement, 42 against 76 on the same page with no
reconciliation published, so any claim cites its surface. Categories,
explore-more block: Coding & Algorithms 37, System Design 25, Behavioral
& Leadership 17. The intro prose names 2 more categories without
counts, Analytics & Experimentation and Data Manipulation (SQL/Python).

Difficulty has no counts to cite, the page displays none, and the
FAQ's characterization is the honest substitute, again verbatim
anchored: `algorithmic coding problems of medium to hard difficulty for software engineers`, product- and metrics-focused case questions for data
scientists, production-ops plus transformer and deployment questions
for machine learning engineers. Interviewers weight clear trade-off
reasoning, ownership, and connecting technical solutions to business
impact beyond raw problem difficulty, the FAQ's own words on what is
actually being graded.

== quirks of this loop [DRILL]

The ads cluster is the distinctive thread and its engagement says so.
The flagship card, `Design ad frequency capping`, carries 595 likes and
5510 solved on its visible card row, the second-highest like count in
the entire 12-page prachub cache measured over the pinned bytes, behind
only amazon's debug watch-list card at 1173 likes and 12322 solved.
Beside it sit `Design a Distributed Frequency-Capping Service` at 19
likes and 285 solved and `Design an Ad Pacing System` at 62 likes and
550 solved, tagged Hard for senior engineers. 3 cards, 1 subject: a cap
is a rate limit keyed by viewer and slot, which is why this chapter
walks it as the primary design.

The product-rooted thread runs wider than ads. The FAQ names the
grounds interviews use: real Netflix product problems such as ad
frequency capping, homepage rendering deduplication, latency
percentile tracking, experimentation metrics, and ML job scheduling.
The visible cards fill it in, prefix-aware deduplication for homepage
content rows, an ML job scheduler for training and batch inference on
a shared cluster, an open matrix-multiply card, a culture screen
battery, and a TTL cache pair that shows up twice with different
titles, the most repeated coding shape on the page.

The visible experiences set the tempo. A 90-minute OA with 4 multiple
choice and 2 coding questions for an intern. 7 interviews over more
than 2 months, the 1 visible experience ending in an offer. An
open-book coding screen that still ended in rejection, and a
no-feedback rejection after 2 back-to-back coding rounds. A virtual
onsite pairing a billboard rotation coding round with an ML job
scheduler system design. And the prompt this chapter works in go, a
phone screen on a key-value store with TTL that ended in rejection.

== recurring prompts [DRILL]

Where each recurring shape floors in this corpus, by chapter id:

The ads cluster, capping, pacing, and the distributed service, floors
on the rate limiter drill of #xref-to("repertoire", "design-prompts")
and the token bucket built from first principles in
#xref-to("go", "limit"). The distributed card adds shared state across
regions, the territory of #xref-to("repertoire", "distributed-answers").

The TTL pair, `Implement an in-memory key-value store with per-key TTL expiration and tests` and `Implement an In-Memory Key-Value Cache With Per-Entry Time Limits`, plus `Simulate a TTL Cache with LRU Eviction`, floor on the caching lane of #xref-to("go", "cache") and are
worked in full below.

`Multiply Two Sparse Integer Matrices Given as Dense Grids` floors on
the sparse matrix multiplication of #xref-to("dsa", "finegrained").

The culture screen cards, `Answer Netflix Culture Screen Questions`
and the data-platform weakness walk, floor on the register of
#xref-to("repertoire", "behavioral-answers"). The OA, the open-book
screen, and the no-feedback outcomes floor on the observed-round
playbook of #xref-to("repertoire", "observed-answers").

Homepage deduplication is a hash-set shape at heart,
#xref-to("repertoire", "datastructures"), latency percentile tracking
is a metrics contract, #xref-to("repertoire", "design-answers") and the
mean-versus-p99 arithmetic of #xref-to("repertoire",
"estimation-answers"), and the FAQ's sliding-window and tree DFS
variants floor on #xref-to("repertoire", "algopatterns") and the
implemented search trees of #xref-to("repertoire", "datastructures").

3 visible cards have no home in this corpus and saying so is the map:
the transformer attention and KV cache card, the L1 versus L2
normalization card, and the ML basics check on Bayes, forward-pass
arithmetic, and KNN are ML fundamentals, and this book ships no ML
fundamentals chapter.

== the ttl store, worked [TDD]

The prompt, authored from the 2 visible TTL card titles merged with the
real screen experience: build an in-memory key-value store where Set
takes a per-key ttl, Get misses once the deadline passes, capacity is
enforced by eviction, and tests pin all 3 behaviors. The premium card
bodies are gated, so the prompt above is authored from the titles
alone, and the design decisions are the interview.

The contract decisions, each 1 pinned by a test written red first:

Expiry is lazy on read. Get compares the entry deadline against the
injected clock and reaps the entry on a miss, Len reports stored
entries until a read or an eviction removes them. No background sweeper
thread, the dead weight is bounded by capacity and paid back on the
next touch.

Eviction is blind LRU on write. The recency list front is the victim,
dead or live, and the decision is stated rather than hidden: a dead
entry deeper in the list occupies a slot until touched, because
preferring dead victims needs a min-deadline heap, and that refinement
is exactly what the distributed frequency-capping sibling card probes
for. The blind rule keeps Set and Get at O(1) with 1 mutex over a map
and a doubly-linked list, the whole of #xref-to("go", "cache") in
miniature.

The clock is injected, `New(capacity, now)`, so expiry tests advance a
fake clock instead of sleeping, deterministic and milliseconds fast,
the same oracle discipline as the design-prompts allocator. A ttl of 0
means no deadline. The boundary is exact: an entry with a 10 second ttl
is live at 9 seconds and dead at 10, because liveness is
`deadline.After(now)` and the boundary instant itself belongs to the
dead side.

#listing("interview-repertoire/samples/ch44-go/ttlstore.go", first: 39, last: 78, caption: [set with the blind lru eviction loop and the overwrite path, get with lazy expiry and the recency bump])

The eviction battery is a table of 4 facts, each a script over the fake
clock with the stored count, the live set, and the dead keys asserted
after it runs:

#listing("interview-repertoire/samples/ch44-go/ttlstore_test.go", first: 97, last: 147, caption: [the 4 eviction facts as table cases: touch moves recency, the lru victim can already be dead, dead weight deep survives until touched, delete frees capacity])

The oracle is a second implementation. A naive store keeps a flat slice
with a monotonically increasing used counter, re-derives the LRU victim
by linear scan, and re-derives expiry by the same deadline rule,
sharing no code with the list-and-map store. A seeded PCG generator
drives 3000 mixed operations through both, and every 25 steps the test
sweeps every key against the model and compares lengths and hit or
miss with values:

#listing("interview-repertoire/samples/ch44-go/ttlstore_test.go", first: 319, last: 364, caption: [the differential run: 3000 seeded ops, model sweep every 25 steps, the capacity guard after every op])

Concurrency is the third pin. 4 writer goroutines each own 1 key and
write increasing integers with short ttls, 4 readers validate that
every observed value is 1 of the written integers, and after the join
each key must read back its final write. The suite is 8 test functions,
the 4-case battery among them, and 365 lines against 93 lines of store,
run under `go vet` and `go test -race`, and the red run came first, the
store compile-failing against its tests before a line of it existed.

== the live playlist, worked [TDD]

The visible card is titled `Movie Playlist With Live Score Updates and No Repeats per Loop, Plus Thread Safety`, and every word of it is a
requirement. The semantics this workspace pins:

A loop shows every title exactly once. The playlist keeps a remaining
queue and a seen set, and the wrap re-ranks all titles by live score,
so each cycle is a permutation and a loop never repeats a title.

Live scores reorder the remainder, never the past. Rating a title
still in the queue re-sorts only the remaining queue by score, rating a
seen title lands on the next loop, and ties break by insertion order,
deterministic on every run.

Thread safety is claimed in node's own frame, and the frame is the
honest part. Node runs this module on 1 thread, `next()` and `rate()`
are synchronous and never await, so no interleaving can tear a call
apart, the event-loop model of #xref-to("repertoire", "js-core"). The
test earns the claim anyway: 40 loops with rating callbacks landing
from microtasks and `setImmediate` between every pick, asserting the
no-repeat invariant after each loop. What the claim does not cover is
said out loud, a worker isolate sharing this state would need message
passing, the module keeps its state per isolate.

#listing("interview-repertoire/samples/ch44-js/src/playlist.mjs", first: 30, last: 49, caption: [next wraps the loop with a full re-rank of unseen titles, rate re-sorts only the remaining queue])

10 node `--test` cases cover the constructor rejections, the
exactly-once cycle, the initial and mid-loop reorder rules, the
seen-title rule, the second-loop order with insertion ties, negative
scores, detached state snapshots, the unknown-title error, and the 2
interleaved-async invariant runs, with no dependency beyond the
stdlib, the same shape as the onebrc javascript lane of
#xref-to("repertoire", "onebrc").

== ad frequency capping at scale [DRILL]

Requirements first. Cap every viewer's exposure: at most 3 impressions
per ad per viewer per day, at most 1 per ad inside a 30 minute
suppression window, checked on the ad decision path under a 10
millisecond budget, and every impression counted from the render side
where viewability is measurable. Non-functional: the cap check cannot
be a hard dependency that fails closed on a stall, a stale or
unreachable counter must degrade to serving with the last known state.

The estimation, assumptions stated, arithmetic this chapter's own, the
method of #xref-to("repertoire", "estimation-answers"). Assume 200
million members, an evening peak with 20 percent watching, 40 million
concurrent streams, 1 ad break per stream every 15 minutes. That is 40M
over 900 seconds, about 44k ad decisions a second at peak, each
decision evaluating a candidate pod of roughly 20 creatives against
caps, so about 880k cap checks a second. The state: 1 hash per viewer
of ad to count and suppress-until, a viewer meeting 50 distinct ads
inside a day, 40M times 50 keys at 32 bytes is about 64 GB, no single
node holds it, so the counter tier shards by viewer hash. 1 decision
touches 1 viewer's keys, so 1 shard answers 1 decision, and 44k
decisions over 16 shards is about 2.8k reads a second per shard, an
easy number for an in-memory tier whose entries ttl out at the longest
window, 1 day, so the working set is the active viewers and nothing
older.

#flow(
  [the cap tier off the hot path, counters rebuilt from the event log],
  node((0, 0), [playback, #linebreak() ad break]),
  node((0, 1.2), [ad decision, #linebreak() targeting, pod of 20]),
  node((0, 2.4), [cap check, #linebreak() 1 shard, 1 round trip]),
  node((2.2, 2.4), [pacing trim, #linebreak() budget per campaign]),
  node((0, 3.6), [auction, #linebreak() pick and serve]),
  node((0, 4.8), [impression beacon, #linebreak() render side]),
  node((0, 6.0), [event log, #linebreak() stream aggregation]),
  node((0, 7.2), [counter tier, #linebreak() ttl 1 day, 16 shards]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (2.2, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
  edge((0, 6.0), (0, 7.2), "->"),
  edge((0, 7.2), (0, 2.4), "-|>", label: [async]),
)

The walk over hops: playback requests an ad break, the decision service
narrows targeting to a candidate pod, the cap check reads the viewer's
shard and drops suppressed creatives, pacing trims anyone over budget
pace, the auction picks from what survives, the client renders and
fires an impression beacon, and a stream aggregator folds beacons back
into the counters asynchronously. The write path being async is the
same softness trade as the local-bucket design in
#xref-to("repertoire", "design-prompts"), a short window where a
just-served impression is not yet counted, bounded by the aggregation
lag and harmless against a daily cap. Beacons are at-least-once,
duplicates overcount, overcounting under-delivers, and under-delivery
is the safe side of a cap.

The bottleneck, volunteered: not the per-viewer reads, which shard
cleanly, but the per-campaign pacing counters, 1 campaign's global
counter is a single hot key written tens of thousands of times a second
at peak, so pacing state shards by region or slot and aggregates at
read, the same hot-key split any global counter needs.

The traps, 1 line each. Count renders, not decisions, the decision
path overcounts everything a viewer skipped. Key by campaign and by
creative both, the advertiser's contract decides which cap binds. A
fixed daily window is cheap and gappy at midnight, a true sliding
window costs ordered-set state per key, say which you chose. Privacy
regimes without persistent ids force session or household keys, the cap
weakens by exactly that factor. A hard frequency cap interacts with
spend pacing, too strict a cap starves a campaign's own daily budget,
the 2 controls need 1 shared model of expected delivery.

== the ml job scheduler on a shared cluster [DRILL]

From the visible card, `Design a Job Scheduler for ML Training and Batch Inference on a Shared Cluster`. Requirements: submit training jobs
that need multiple GPUs for hours and batch inference jobs that need
1 GPU for minutes, inference latency-sensitive, training
throughput-bound, per-team fair share, preemption with checkpoints,
and no job lost to an agent crash.

Estimation, assumptions stated, arithmetic this chapter's own. Assume a
5000-GPU cluster. Training: 2000 submissions a day averaging 8 GPUs for
6 hours, 2000 times 8 times 6 is 96k GPU-hours a day. Inference: 50k
submissions a day at 1 GPU for 10 minutes, 50k over 6 is about 8.3k
GPU-hours. Demand 104.3k against a 120k supply, 87 percent utilization,
and that 1 number is the design: above roughly 80 percent a FIFO
queue's wait time explodes, so priority tiers, preemption, and
backfilling are not features, they are the only way the cluster stays
usable.

#flow(
  [gang allocation all or nothing, backfill fills the holes],
  node((0, 0), [submit, #linebreak() spec, id, priority]),
  node((0, 1.2), [spec store, #linebreak() persistent]),
  node((0, 2.4), [queues per pool, #linebreak() inference tier first]),
  node((0, 3.6), [scheduler loop, #linebreak() gang, backfill, preempt]),
  node((2.2, 3.6), [fair share, #linebreak() dominant resource]),
  node((0, 4.8), [node agents, #linebreak() gpu alloc, isolation]),
  node((0, 6.0), [status events, #linebreak() idempotent resubmit]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((2.2, 3.6), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
)

The walk: a submission validates and persists its spec with a unique
job id, queues land per pool with the inference tier ahead, the
scheduler loop sorts by priority inside a dominant-resource fair-share
budget, allocates multi-GPU jobs gang-style, all or nothing in 1
decision, and backfills single-GPU inference into the holes. Node
agents hold the GPUs and report status, and a lost agent's jobs
resubmit idempotently by job id. Preemption is the utilization release
valve: training checkpoints every N minutes, eviction costs at most N
minutes of work, and inference is never the victim, it is the reason
the tier exists.

The bottleneck, volunteered: fragmentation at 87 percent. Holes of 2 to
6 GPUs accumulate across nodes, gang jobs cannot fit them, and the
queue stalls behind a big job. The answer is backfill with reservation,
the big job's earliest-finish estimate reserves its GPUs and small jobs
fill only what it cannot use, which keeps both the tail latency of
inference and the wait of the big job bounded.

The traps, 1 line each. Partial gang allocation deadlocks, allocate all
GPUs atomically or release them all. Checkpoint cadence trades
bandwidth for preemption cost, every N minutes is a spend decision.
Fair share by dominant resource stops 1 team's 8-GPU jobs from starving
another's 1-GPU jobs. Spot or preemptible capacity is a cheaper tier
inside the same scheduler, labeled by preemptibility, not a second
scheduler. Multi-node jobs need the internode fabric as a placement
constraint, 8 GPUs on 1 NVLink domain beat 8 scattered.

#callout("pitfall", "what the loop map cannot tell you", [
  The pinned page publishes no numeric round or difficulty counts
  anywhere, so every count in this chapter names its surface, the intro
  paragraph, the explore-more block, the header counter, the footer
  link, or a visible card row, and the surfaces disagree, 42 against 76
  for the SWE role alone. The FAQ prose is the only loop description,
  `roughly four to six rounds`, and any chapter that turns that into a
  histogram invented it. Pages 2 through 7 of the question list and all
  locked card bodies are premium-gated, so the worked prompts here are
  authored from visible page-1 titles only, never reconstructed from
  bodies this book never saw.
])

sources: every count in this chapter traces to
`ref/prachub/netflix/page.md`, fetched 2026-10-15 from
prachub.com/companies/netflix/ and pinned verbatim with a sha256
header, through the transcription at `ref/prachub/netflix/facts.md`.
The cross-cache like ranking was measured over the pinned bytes of all
12 cached company pages, not read from any claim on the page. The
worked prompts are authored from visible truncated card titles only,
premium-gated bodies never quoted or reconstructed, and both design
walkthroughs carry their arithmetic as stated assumptions in the
#xref-to("repertoire", "estimation-answers") method, arithmetic this
chapter's own, not numbers from the page. No other online source was
consulted.
