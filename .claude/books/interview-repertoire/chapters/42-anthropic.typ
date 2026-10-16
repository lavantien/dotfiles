#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at anthropic

One page, every number named to the surface it came from. PracHub's
Anthropic page carries 245 questions at its own header counter,
updated 10.05.2026, and the surfaces below that counter disagree with
each other on almost every count: the intro paragraph says 31
first-hand interview experiences while the footer link says all 44,
the intro counts Software Engineer at 167 while the explore block at
the page bottom says 217. So the rule for this chapter, and for every
company chapter in this arc, is the no-metrics law: the page's own
header count is the company number, never the index rollup, and each
count below names its surface, intro paragraph, header counter, FAQ
block, explore block, footer, or the page 1 card list, because a
number without its surface is a number nobody can recheck.

The shape the surfaces agree on is a live-round loop with a high
floor. The FAQ's round distribution puts the onsite at 122 questions
against 61 for the technical screen, with 5 from HR screens and 2
from online assessments, an onsite that doubles its screen, the only
page in this arc where it does. Difficulty is published here, and the
page's own words are the whole story: nothing in the set is tagged
easy, 111 questions are medium and 79 are hard. Coverage moves, 41
added in the last 90 days by the intro's count, and exactly 1
question carries the AI-assisted round tag. This is a systems-heavy,
senior-flavored loop, and both worked prompts and both design walks
below are chosen to match it.

== the loop map [DRILL]

The rounds, from the FAQ block verbatim: onsite 122, technical screen
61, HR screens 5, online assessments 2. Coding problems are reported
from both the screen and the onsite, design prompts come from the
screen, and behavioral questions cluster at the onsite. The header
counter block adds the page's own freshness facts: 245 questions,
updated 10.05.2026, and the intro paragraph adds 41 added in the last
90 days and 1 AI-assisted round tag. The list itself shows 20 results
per page and paginates to page 1 of 13, and only that first page, its
20 visible card titles, is public, pages 2 through 13 are premium
gated, which is why every worked prompt in this chapter is authored
from a visible truncated title and nothing else.

#diagram([the loop: coding and design both at the screen, the onsite doubling it], length: 13pt, {
  cdraw.rect((0.4, 5.2), (7.4, 7.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.9, 7.0), [technical screen, 61], size: 6.5pt)
  cdraw.content((3.9, 6.1), [coding and design, both], size: 6pt)
  cdraw.rect((9.4, 5.2), (18.8, 7.6), fill: luma(225), stroke: luma(120), radius: 0.02)
  cdraw.content((14.1, 7.0), [onsite, 122], size: 6.5pt)
  cdraw.content((14.1, 6.1), [coding, more design, behavioral cluster], size: 6pt)
  cdraw.line((7.6, 6.4), (9.2, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((20.6, 5.2), (23.6, 7.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((22.1, 7.0), [hr screens, 5], size: 6pt)
  cdraw.content((22.1, 6.1), [online, 2], size: 6pt)
  cdraw.content((11.8, 3.9), [the onsite doubles the screen, 122 against 61,#linebreak()the only page in this arc where it does], size: 6pt)
  cdraw.content((11.8, 2.2), [design prompts report from the screen, behavioral clusters at the onsite], size: 6pt)
})

The experiences tell the same story in the first person. The intro
paragraph counts 31 first-hand experiences, the footer link says all
44, and both are quoted here because the disagreement is the page's
own. Eight experience entries are visible on page 1: four screen
write-ups, two HR screens, and two onsites, including the screen that
rescheduled around a telemetry design interview and its naming
variants, and the onsite that spent its time reviewing and improving
pull requests with Claude Code.

== the bank, every surface named [DRILL]

Roles, three surfaces. The intro paragraph: Software Engineer 167,
Machine Learning Engineer 22. The FAQ block repeats both and adds
Backend Engineer 1. The explore block: Software Engineer 217, Machine
Learning Engineer 23. The intro and FAQ agree with each other and
disagree with the explore block, so the chapter carries the intro and
FAQ pair as the bank's role counts and names the explore block as the
dissenting surface. Seniority is FAQ-only: mostly General, with 9
questions marked Senior+.

Categories, two surfaces that disagree on three of four shared rows.
The intro paragraph: Coding and Algorithms 83, System Design 44,
Behavioral and Leadership 30, ML System Design 18. The explore block:
Coding and Algorithms 83, System Design 52, Behavioral and Leadership
51, Software Engineering Fundamentals 27, ML System Design 24. The
coding row agrees at 83, the other three shared rows differ, and the
explore block carries a category the intro never names.

Difficulty, published on this page and nowhere to hide. The intro
paragraph and the FAQ block both say 111 medium and 79 hard, and the
intro's own sentence is "Nothing in the set is tagged easy". The card
list disagrees with itself once: the visible page 1 card "Explain Why
You Want to Work at Anthropic", a behavioral prompt with 35 likes and
700 solvers by the card table, carries an Easy tag. The chapter
carries both honestly, the distribution counts as the difficulty
surfaces state them and the single Easy-tagged behavioral card as the
exception the surfaces disagree on, and the disagreement is itself
the drill: quote the surface, not the summary.

== quirks of this loop [DRILL]

The screen is a two-headed round. The FAQ names five screen-tagged
prompts, and they split exactly as claimed: converting streaming
call-stack samples into function events is coding, while large
model-weight distribution to GPU workers, peer-to-peer model
distribution under a shared link cap, a resilient chat system, and a
low-latency GPU inference service are design. A screen that hands you
a design prompt is the page's own quirk, and two of the five are
model-distribution problems, the same theme twice at one stage.

The hard end is systems-flavoured, the FAQ's phrase, and its named
hard prompts are large model-weight distribution, a versioned
in-memory database, and simulating threshold infection efficiently.
The versioned in-memory database has no home in this corpus, the
in-memory structures of #xref-to("repertoire", "datastructures")
cover the data shape but not versioning, so it stays a named gap
until a chapter owns it.

Behavioral weight sits at the onsite and the most-liked visible card
proves it: "Respond to a Hypothetical Loss of Employer Equity Value",
a behavioral hypothetical with 130 likes and 1,092 solvers per the
card table, the page's like leader by a factor of 2 over the
runner-up design card's 64. The visible experience entries add three
first-person quirks: a screen that constrained the candidate to
single-threaded code, an onsite spent reviewing and improving pull
requests with Claude Code, and a rescheduled telemetry design
interview that turned on naming variants. The AI-assisted round tag
lands on exactly 1 question, and the card list shows it: "Review and
Improve Four AI-Assisted TypeScript Pull Requests", hard, locked, 18
likes, 367 solvers.

== recurring prompts, mapped [DRILL]

The page's prompts recur elsewhere in this book, and the map is the
point, a chapter that restates what another chapter owns is filler.

The concurrent crawler card, "Make a Web Crawler Concurrent with
Thread-Safe Visited State", 23 likes and 178 solvers by the card
table, is #xref-to("repertoire", "graphs") for the traversal shape
and #xref-to("go", "capstone") for the crawler that actually runs
with its worker fan and shared visited state. The telemetry pipeline
card, 23 likes and 204 solvers, is the ingestion and naming-variant
problem of #xref-to("go", "obs") and #xref-to("patterns",
"observability"). The resilient chat system, a FAQ screen prompt, is
worked end to end in #xref-to("repertoire", "design-prompts"), its
gateway, colocated conversations, and offline inbox. The low-latency
GPU inference service, also a FAQ screen prompt, meets its batched
sibling in the first design walk below. The behavioral bank, the
recruiter screen prep card, the equity hypothetical, and the AI risk
values round all drill from #xref-to("repertoire",
"behavioral-answers"). The AI-assisted pull-request review onsite
runs on the ai-assist norms of #xref-to("repertoire",
"observed-answers"). Every estimation in both design walks uses the
method of #xref-to("repertoire", "estimation-answers"), and the
prompt protocol itself is #xref-to("repertoire", "design-prompts").
The sharded matrix multiply performance model, 14 likes and 126
solvers, is the roofline arithmetic this book leaves to the gpu
chapters that own it, stated as absent rather than restated badly.

== worked prompt: greedy longest-match tokenization [TDD]

The visible card, from the page 1 card table: "Greedy Longest-Match
Tokenization of a String Against a Fixed Vocabulary", medium, Coding
and Algorithms plus String Algorithms, 25 likes, 3 comments, 278
solvers, Sep 18, 2026. The visible body stops mid sentence at "You
are given a string text and a list vocab of distinct, non-empty
strings. The to...", so the contract below is authored from the title
and that fragment alone, and its decisions are stated as authored.

The contract: scan left to right, at each anchor take the longest
vocabulary entry that matches a prefix of the remainder, advance by
its length, and when no entry matches at an anchor, fail loudly with
the anchor's byte offset. The anchored scan is the whole prompt: a
match must start exactly at the anchor, the scanner never skips
ahead to find one, and greedy longest is deterministic because the
vocabulary is distinct. Construction validates what the title
asserts, non-empty and distinct, and indexes the vocabulary into a
membership set plus the distinct entry lengths sorted descending:

#listing("interview-repertoire/samples/ch42-go/tokenizer.go", first: 20, last: 42, caption: [vocabulary validation, the membership set, the distinct lengths sorted descending])

The scan walks the anchors, and at each one tries the lengths
longest first until one lands on a vocabulary entry. Every candidate
is a whole-entry byte comparison, so multi-byte utf-8 entries match
as whole sequences and byte offsets are the error's currency:

#listing("interview-repertoire/samples/ch42-go/tokenizer.go", first: 44, last: 70, caption: [the anchor loop: longest match first, the loud no-match error carrying the byte offset])

The cost is one membership probe per distinct entry length per
anchor, hash probes with no backtracking, and the plain road is the
one to write at a board. The trie alternative, one root-to-leaf walk
per anchor that shares prefixes across entries, wins when entries
share long prefixes, and saying when it wins is the follow-up worth
volunteering: a vocabulary of a thousand entries all sharing a
three-letter stem makes the length ladder pay for the shared stem on
every entry while the trie walks it once.

The suite, 5 test functions under vet and the race detector, builds
every expected table by hand, the oracle discipline this book
always demands: longest-wins pairs, a full-sentence split, a
round-trip that tokenizes every vocabulary entry to itself, the
error table with its dead-end and never-skip-ahead cases, and
multi-byte entries. Red first: against a compiling stub the suite
failed 4 of 5 functions before the implementation existed.

== worked prompt: the buggy lru and its write-ahead log [TDD]

The visible card: "Fix a Buggy LRU Cache, Then Make It Durable with
a Write-Ahead Log", medium, Software Engineering Fundamentals plus
Data Structure Design plus Debugging, 17 likes, 127 solvers, Sep 18,
2026. The visible body hands over an in-memory cache misbehaving in
production and stops at "Then extend it so that its c...", so both
the defect set and the durability contract are authored, and the
suite pins them red-first the same way.

The buggy cut this chapter authors carries the three defects such a
cache ships with in the wild, one per test: a Get that answers
without promoting, so the least-recently-used victim is chosen from
an order nobody maintains, an overwrite that inserts a second entry
instead of updating and promoting the existing one, and eviction
that fires without the capacity guard rejecting zero up front. The
fixed core is a map over a doubly-linked list with sentinels, O(1)
on both operations:

#listing("interview-repertoire/samples/ch42-go/lru.go", first: 40, last: 61, caption: [get promotes on hit, put updates or inserts then evicts past capacity])

#listing("interview-repertoire/samples/ch42-go/lru.go", first: 99, last: 108, caption: [move to front over the sentinels, the victim always the tail's neighbor])

The durability half is the prompt's second sentence, and the
write-ahead log is named in the title, so the semantics floor on
#xref-to("infrastructure", "sqlite-wal"): the log is the record of
truth, the memory is a rebuildable cache of it. Each record frames
one operation, op byte, key length, key, value length, value, and a
crc32 over the frame:

#listing("interview-repertoire/samples/ch42-go/wal.go", first: 40, last: 50, caption: [one append per operation, the crc closes the frame])

Replay walks the committed prefix and stops at the first frame that
is short, fails its crc, or names an unknown op, the same crash
contract sqlite's wal carries, a torn tail is recovery's normal
morning, not an error:

#listing("interview-repertoire/samples/ch42-go/wal.go", first: 52, last: 93, caption: [replay applies the committed prefix and stops, decode validates length, crc, and op before trusting a frame])

#callout("pitfall", "the window between log and apply", [
  The write path logs first and applies second, and the order is
  the durability. Crash after the apply but before the log and the
  write vanishes on restart, a silent loss the caller cannot see.
  Crash after the log but before the apply and replay reinstates
  the write, one operation late instead of gone. Logging first
  converts a silent loss into a late arrival, and replay is what
  makes the arrival happen.
])

The cache composes the two under one mutex, log-then-apply on every
mutation:

#listing("interview-repertoire/samples/ch42-go/wal.go", first: 129, last: 137, caption: [log first, apply second, the error surface the caller maps to a 503])

One property the suite pins that interviews miss: eviction replays
identically. Replay feeds the same puts in the same order into the
same capacity, so the live run's eviction choices are reproduced
exactly, and the test closes the cache mid-history, reopens it, and
demands the same key order. The suite is 13 test functions across
the two files, 6 for the cache and 7 for the log, every expected
value hand-built, the torn-tail and corrupt-frame cases included,
and the concurrent hammer runs 8 goroutines under the race detector
before the close-and-reopen check. Red first: both suites failed
against compiling stubs before either implementation existed.

== design: the batched inference service [DRILL]

The prompt, the page's flagship card: "Design a Batched LLM Inference
Service Assuming Each Batch Takes 100 ms", hard, 64 likes, 558
solvers, the like leader of the page's design cards by the card
table. The visible body says each client sends one request
containing a prompt and waits, a synchronous contract, and stops
there. The protocol is the one from #xref-to("repertoire",
"design-prompts"): requirements, then arithmetic before boxes, then
the topology, the walk, the bottleneck volunteered, traps one line
each.

Requirements, functional plus the stated assumptions, mine, not the
page's: serve synchronous single-prompt requests, 10k requests per
second at peak, answer under half a second at the median, batch
execution is fixed at the given 100 ms per step, batch capacity 32
from the kv cache budget, weights are read-only after load.

The arithmetic, the method of #xref-to("repertoire",
"estimation-answers"). One replica completes one batch of 32 per
100 ms, so 320 requests per second per replica, and 10k peak needs
32 replicas at perfect fill, call it 40 with fill slack. Little's
law checks the queue: 320 in flight per replica at 0.1 s is exactly
the batch of 32, so the batcher's queue is the only elasticity in
the system and its depth is the latency budget. Weights dominate
memory: a 70B model at 8 bits is about 70 GB, one accelerator card
per replica before any kv cache, and the kv cache per request is
what actually caps the batch, the real reason batch capacity is an
assumption rather than a choice.

#flow(
  [the batched service: bounded queue, fill-or-deadline batcher, fixed-step replicas],
  node((0, 0), [clients, #linebreak() one prompt, one wait]),
  node((0, 1.2), [gateway, #linebreak() auth, admission]),
  node((0, 2.4), [bounded queue, #linebreak() overflow is a 429]),
  node((0, 3.6), [batcher, #linebreak() fill 32 or deadline]),
  node((0, 4.8), [replica pool, #linebreak() 100 ms steps, 40 replicas]),
  node((0, 6.0), [weights, #linebreak() read-only after load]),
  node((2.4, 4.8), [metrics, #linebreak() fill, depth, step time]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 6.0), (0, 4.8), "->"),
  edge((0, 4.8), (2.4, 4.8), "->"),
)

The walk, hop by hop. The gateway authenticates and enforces
admission, its 429 is the queue's overflow valve. The queue is
bounded because an unbounded one converts a spike into a permanent
latency debt. The batcher collects until 32 requests arrive or a
deadline passes, tens of milliseconds, whichever first, and hands
the replica a full batch. The replica runs the 100 ms step and
returns 32 answers, which fan back by request id. The metrics lane
watches fill ratio and queue depth, the two numbers that tell you
which lever to pull.

The bottleneck, volunteered: the step is a fixed cost, so per-request
speed is not a lever anywhere in this design, throughput scales only
with batch fill, and the tail at peak is queue depth. At 10k per
second against 12.8k capacity the queue stays near empty, one hot
model or one viral prompt and the depth grows a 100 ms step at a
time, which is why the deadline on the batcher and the 429 on the
gateway are the same decision made twice.

Traps, one line each. Waiting to fill: every millisecond of fill
wait is latency paid by every request in the batch, the deadline
prices it. Prompt variance: one long prompt eats the kv budget and
shrinks the batch, bin by length or cap the prompt. A crash mid
batch: 32 requests fail together, retry by id into the queue, and
the id makes it idempotent. Streaming: the visible contract says
the client waits, one response, a streaming design is a different
contract and a different queue, say which you are designing. The
review card on the same page, "Review a Batched GPU Inference API
Design Doc", 16 likes, is this same system seen from the reviewer's
chair, and the sharded matmul card is its performance-model cousin.

== design: 500 gb of weights to 1,000 workers [DRILL]

The prompt: "Distribute 500 GB of Model Weights to 1,000 GPU Workers:
Lower Bound and Design", medium, 9 likes, 150 solvers. The visible
body gives the fleet as somewhere between 100 and 1,000 machines and
asks for the lower bound first, so the arithmetic leads, and every
rate below is my stated assumption at the estimation chapter's
powers-of-two ladder: a 10 Gbps link is 1.25 GB/s, a 25 Gbps link is
3.1 GB/s, a 100 Gbps link is 12.5 GB/s.

The lower bound, said aloud before any box. Every worker must
receive 500 GB, so the total movement is 1,000 times 500 GB, 500 TB,
and no design moves less. A single source serving serially over one
10 Gbps link needs 400 s per worker, 400,000 s for the fleet, more
than 4.6 days. Give the source a 100 Gbps pipe and serial service
still needs 40,000 s, 11 hours, because the source is one link no
matter how fast. The per-worker floor is the receiving side: 500 GB
at 3.1 GB/s is about 160 s, and no distribution shape beats it. So
the only road between days and minutes is to stop treating the
source as the only sender and let workers serve what they already
hold, which is the peer-to-peer model distribution the FAQ names as
a screen prompt under a shared link cap, the same design family,
the cap is this walk's constraint side.

#flow(
  [weights out: a chunk manifest from the source, a swarm that serves what it holds],
  node((0, 0), [source store, #linebreak() 500 GB, read-only]),
  node((0, 1.2), [manifest, #linebreak() sha256 per chunk]),
  node((0, 2.4), [seed peers, #linebreak() a few full copies first]),
  node((0, 3.6), [swarm, #linebreak() chunks from any holder]),
  node((0, 4.8), [worker, #linebreak() verify, assemble, ready]),
  node((2.4, 3.6), [link caps, #linebreak() per host, per rack]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((2.4, 3.6), (0, 3.6), "-|>"),
)

The design. Split the weights into about 8k chunks of 64 MB. The
source publishes a manifest with each chunk's sha256. A handful of
seed peers take full copies over the source's fattest pipe, then
every worker fetches chunks from any peer that holds one, verifying
each chunk against the manifest on arrival, and starts serving the
chunks it has verified while it fetches the rest. A tree with fanout
10 over 1,000 workers is 3 generations, and if the 10 Gbps uplink is
each host's wall, a generation costs on the order of 400 s, roughly
20 minutes end to end against the serial road's 4.6 days, while a
chunked swarm pipelines instead of locking generations and approaches
the 160 s per-worker floor. Resumption is free: a worker that dies
mid-download re-asks for its missing chunks by hash, the same
contract as the page's parallel and resumable model downloader card,
5 likes, 93 solvers.

The bottleneck, volunteered: aggregate uplink and the cold start.
For the first minutes only the seeds hold chunks, the swarm's
serve-what-you-hold engine has nothing to serve, and the seed uplink
is the whole system's rate, which is why multiple seeds and a
randomized chunk order, so seeds are not asked for chunk 1 by a
thousand workers at once, are the first two decisions, and the link
cap makes them enforceable per host and per rack.

Traps, one line each. Verify per chunk, never at the end, a 500 GB
copy that fails its hash at minute 19 has cost the whole 20. Keep
fanout rack-local where the switch allows, cross-rack bisection is
the next wall after the uplinks. A straggler worker is expected,
readiness is per worker, the fleet serves when enough workers are
ready, not when all are. Chunk order matters for time-to-first-serve
if workers may load layers incrementally, otherwise any order
verifies the same. The versioned in-memory database the FAQ names
beside this prompt in the hard end has no corpus home yet, and this
walk does not pretend otherwise.

sources: every count, card, and quote in this chapter traces to the
pinned page bytes at `ref/prachub/anthropic/page.md`, fetched
2026-10-15 from https://prachub.com/companies/anthropic/, sha256
e6ef5368f781f35a043662e07dfd21a960f990c76585f5ddc0639452dca6e5d3,
transcribed into `ref/prachub/anthropic/facts.md` with its surfaces
labeled. Only page 1 of the question list is public, its 20 visible
card titles and their truncated bodies, pages 2 through 13 and every
locked body are premium gated, not fetched, not reconstructed, and
both worked prompts and both design walks are authored from visible
titles with their arithmetic stated as this chapter's own. The
design walkthrough method is #xref-to("repertoire", "design-prompts")
and #xref-to("repertoire", "estimation-answers"), and the wal
semantics floor is #xref-to("infrastructure", "sqlite-wal").
