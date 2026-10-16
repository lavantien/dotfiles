// chapter 45: the meta loop from the pinned prachub page bytes, the
// count anomaly named to its surface, the data-role bank, two worked
// prompts, two design drills floored on the corpus
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at meta

Meta is the only arc company in this book where the largest role block
on the page is a data role, Data Scientist 609 against Software
Engineer 399 in the explore block, and that one fact reroutes the
whole prep. The bank still carries a heavy coding lane, Coding and
Algorithms 326 leads every category in the same block, but analytics,
SQL, and statistics sit directly beside it rather than under it, and
the machine learning cards carry their own two blocks. The page also
disagrees with itself about how big it is, three numbers on one page,
and the disagreement is this chapter's opening discipline: name the
surface every time, the page beats the index.

== the loop map [DRILL]

The page publishes no numeric round counts, anywhere. The FAQ
describes the process in prose only: a recruiter screen, one or two
technical screens or an online assessment, a full loop of onsite-style
interviews, then debrief, committee review, and offer. The full loop
mixes coding, system or product design, role-specific technical
rounds, and behavioral interviews. Any number of rounds you have read
elsewhere is not on this page, and a prep plan that counts rounds is
inventing structure the source does not publish.

The loop bends by role, still in FAQ prose. Software engineer
candidates spend most time on coding and design. Data scientists
focus on SQL, experimentation, and product analytics. Machine learning
engineers see modeling and recommendation design. Data engineers
handle SQL, data modeling, and pipeline questions. Product managers
get product-design and analytics probes.

Difficulty publishes the same way, prose, no counts. The FAQ maps
coding rounds to medium-to-hard algorithmic problems that appear in
top 100 problem lists for software engineers, and says difficulty
scales with level: entry hires see clearer, bounded problems, senior
hires face ambiguous tradeoffs and system-wide thinking. The per-card
tags on the visible page 1 rows do carry an Easy or Medium word each,
but no numeric spread exists to cite.

== the bank [DRILL]

Three counts, three surfaces, one page. The header counter renders
1.2k. The intro paragraph says 1,206 questions. The companies index
rollup says 1,111. The page's own count is the company number, 1,206,
which the header rounds to 1.2k, and the index is a rollup that
disagrees with the page it points at. Updated 09.25.2026 in the
header. The question list shows 20 results on page 1 of 61, and the
footer link counts 129 first-hand interview experiences.

#callout("pitfall", "three numbers, one page", [
  A count without its surface is a defect here. Say the header
  renders 1.2k, say the intro paragraph says 1,206, say the companies
  index says 1,111, and never average, round, or reconcile them. The
  page is the primary source over its own index rollup, the same
  discipline every chapter in this arc applies to its page bytes.
])

The role split, all counts from the explore block:

#table(
  columns: (auto, auto),
  inset: 4.5pt,
  align: (left, right),
  table.header[*role*][*questions*],
  [Data Scientist], [609],
  [Software Engineer], [399],
  [Machine Learning Engineer], [105],
  [Data Engineer], [48],
  [Product Manager], [19],
  [Product Analyst], [16],
)

No other arc company puts a data role on top. The prep consequence is
arithmetic, not sentiment: the analytics and statistics floors of
#xref-to("math", "statistics") and #xref-to("repertoire",
"math-answers") are first-class study material for meta, not garnish
after the grinding.

The category split, same explore block:

#table(
  columns: (auto, auto),
  inset: 4.5pt,
  align: (left, right),
  table.header[*category*][*questions*],
  [Coding and Algorithms], [326],
  [Analytics and Experimentation], [271],
  [Data Manipulation, SQL and Python], [175],
  [Behavioral and Leadership], [129],
  [System Design], [99],
  [Statistics and Math], [89],
  [Machine Learning], [58],
  [ML System Design], [26],
)

Coding still leads, so the software engineer path is not starved, but
second place is analytics and third is SQL, and the ML blocks total 84
across two categories. The bank is wide, and the role you interview
for decides which third of it you drill.

== quirks of this loop [DRILL]

The quirk the whole industry argues about is on the page in one FAQ
sentence: in 2025 to 2026 some teams pilot AI-enabled coding rounds.
This book already pinned the pilot from interviewing.io in the
coverage sources, the row "meta ai-enabled coding round, piloted
october 2025" accessed 2026-09-10, and this chapter cites that pin
rather than re-sourcing it. The opening chapter of this book walks the
same pilot, #xref-to("repertoire", "landscape"), and the norms for
using an assistant without surrendering the round are
#xref-to("repertoire", "observed-answers").

The visible first-hand experience entries, 8 titles on page 1 of the
experiences list, make the pilot concrete. A senior+ data engineer
was rejected over "not enough impact" after a leadership and fullstack
phone screen. A machine learning engineer ran a four-round onsite and
was rejected after two AI coding rounds. A senior software engineer
spent six weeks of E5 preparation and closed with an equity
negotiation and an offer. Another software engineer describes a phone
screen plus a four-round virtual onsite, and one more an AI system
explanation and a maze solved with AI. These are card titles, single
experiences, never a census, and the count discipline above applies:
the footer says 129 exist.

The FAQ's recurring software engineer themes read like a syllabus:
timestamped state and versioned systems, leaderboards and ranking,
maze and graph traversal, tree and array transforms, delimiter and
CSV parsing, and scalable or flight-search style designs. Machine
learning engineers see place and friend recommendation design,
sparse-matrix operations, ranking and loss choices, and feed dislike
or personalization models. Data engineers face entity modeling for
feed and booking data, utilization and reservation SQL, and
capacity-aware aggregation.

The FAQ also answers the prep timeline question with a six-week plan:
weeks one and two on fundamentals, weeks three and four on timed
problem practice and role-specific cases, week five on design and
behavioral storytelling, week six on full mock loops. It is a sane
frame and this book supplies every piece of it.

== recurring prompts, floored [DRILL]

Every visible card on page 1 lands on a floor this book already owns.
The two sum card, "Find the Unique Pair of Array Indices Whose Values
Sum to a Target", is the complement map of
#xref-to("repertoire", "classics1"), and the grid cards there and in
the maze theme below floor on the same chapter's islands walk. The
maze and graph traversal theme is
#xref-to("repertoire", "graphs"), breadth first over eight
directions, topological sort when ordering is the question. The tree
cards, lowest common ancestor from level order, range sum, and
vertical column grouping, floor on the tree implementations of
#xref-to("repertoire", "datastructures").

The machine learning from-scratch genre, K-means on page 1, floors on
#xref-to("kdd", "kmeans"), and this chapter works the transformer
card below in the same spirit. The real-time chat card is already
worked end to end in #xref-to("repertoire", "design-prompts") and is
never reworked here. The notification system card is worked below,
with the events inventory of #xref-to("repertoire", "design-answers")
as its floor. The single-server crash diagnosis card, concrete Linux
evidence, floors on #xref-to("repertoire", "systems-answers") and the
debugging round method of #xref-to("repertoire", "observed-answers").
The behavioral cards, ambiguous problems, impact and credit, mentor
growth, are the story cards of #xref-to("repertoire",
"behavioral-answers"). The scalable search theme floors on the
scaling answers of #xref-to("repertoire", "design-answers"), and the
SQL and analytics cards ride the statistics and math floors cited in
the bank.

== worked: the eight-direction clear path [TDD]

The page 1 card reads "Shortest 8-Directional Clear Path Across a
Binary Grid", tagged Easy, Coding and Algorithms with Grids and
Matrices and Graphs tags, 9 likes and 65 solves on the card row, and
the title alone carries the contract. A binary grid, start top left,
end bottom right, a move steps to one of 8 neighbors, clear cells
only, and the answer is the number of cells on the shortest clear
path, counting both ends, or -1 when no path exists.

BFS is the answer because every move costs the same, and the BFS
layers of #xref-to("repertoire", "graphs") are then shortest by
construction. The 4-directional instinct is the trap: the 8-neighbor
move set makes diagonal hops legal, so the all-clear 3 by 3 grid
crosses in 3 cells, not 5, and the floor on any path length is the
Chebyshev distance plus one, never the Manhattan distance plus one.

The go lane went test first, and the tests caught the author twice,
which is the section's real lesson. The first red run failed compile,
no implementation. The first green run failed on a hand-written
expectation of 5 for a 2 by 4 snake grid, because the hand had
counted orthogonal moves and the contract allows the diagonal from
the third cell of the top row straight to the end cell, 4 cells. The
expectation was wrong, not the code, and the fix moved the number,
never the assertion shape. The suite pins the one-cell grid at 1,
blocked starts, ends, and walled-off targets at -1, the 2 by 2 cross
at 2, the pinch corridor at 7, rectangular grids, and a sweep over
all 512 three by three grids checked against an independent
reachability walk, so the BFS length and the existence oracle agree
everywhere:

#listing("interview-repertoire/samples/ch45-go/clearpath.go", first: 3, last: 46, caption: [the 8-neighbor move set, then bfs marking cells visited at enqueue, distance counted in cells from 1])

Complexity stated up front, the FAQ's own tip: O(V + E) with V the
cells and E at most 8 V, so linear in the grid, each cell enqueues
exactly once, and the distance array doubles as the visited set at
O(V) space. Three traps, one line each.
The path counts cells, not moves, so a 2-cell answer is one hop.
Mark visited at enqueue, never at dequeue, or one cell enters the
queue eight times and the layers rot. Chebyshev is the floor,
Manhattan is the 4-directional reflex, and the 8-neighbor set makes
it wrong.

== worked: multi-head attention from scratch [TDD]

The flagship machine learning card on page 1 reads "Implement the
Forward Pass of Multi-Head Attention From Scratch", tagged Medium,
Machine Learning with ML Coding and Transformers and Attention tags,
11 likes and 138 solves on the card row, the highest solve count
visible on the page. Meta's explore block gives the ML weight behind
it, Machine Learning 58 plus ML System Design 26, and the card is
matrix arithmetic, which is why this lane ships in plain javascript
under this book's selective js ruling: no tensor library, no
autograd, just the forward pass with every dimension stated by hand.

The dimensions first, because the card grades them. The input x is a
sequence of T rows, each D wide, the model width. The four weight
matrices are D by D. Heads split D into h slices of headDim = D / h
each, and h must divide D exactly. Each head projects x into q, k,
and v, attends over its own slice with scores scaled by
1 / sqrt(headDim), softmaxes each query row, mixes its value slice,
and the concatenated heads pass through the output projection wo.
The scale uses headDim, never D, and the softmax needs its row max
subtracted first or exp overflows on real logits.

The js lane also went test first, and the tests caught the author
twice more, both times in hand arithmetic rather than code. One
expected matrix product was legal math the reject test meant to
forbid. One two-head expectation put the value slice on the wrong
column of the input, head 0 reads x column 0, and the delta was
exactly 1 on two entries, the signature of a swapped slice. The
oracle values all come from closed forms, softmax of log odds, the
sigmoid constants e^-2, e^-4, e^-6, and e^-8, so the expectations
are independent of the implementation, the same discipline as the
clear path sweep. The stable softmax and the forward pass:

#listing("interview-repertoire/samples/ch45-js/src/attention.mjs", first: 27, last: 41, caption: [the row max subtracted before exp, the uniform row an exact fixed point])

#listing("interview-repertoire/samples/ch45-js/src/attention.mjs", first: 43, last: 80, caption: [the forward pass: project, slice per head, scaled dot product, softmax, mix values, concat, output projection])

The suite, 13 node --test cases, pins the algebra and the edges:
identical tokens are a fixed point under identity weights, one-hot
tokens mix by hand-derived weights, permuting input rows permutes
output rows, two heads with identity weights attend strictly inside
their slices, doubling wo doubles the output, and the dimension
guards throw RangeError on ragged products and on a head count that
does not divide D. The from-scratch genre is the same one as
#xref-to("kdd", "kmeans"), no library, the arithmetic on the board.

Three traps, one line each. Forgetting wo entirely is the most common
card failure, the output projection is part of the forward pass.
Splitting heads by copying data is wasted work, the slice is an
offset walk. Softmax without the max subtraction returns NaN on
logits past 700, and the dimension guards must fail loudly before
any multiply, the loud-failure law of every lane in this book.

== design: people you may know [DRILL]

The requirements first. Surface likely-friend candidates on a
friendship graph, ranked, filtered against existing edges and blocks,
fresh within hours of a new friendship, served in under 200
milliseconds. The number nobody gives you is the graph size, so
state it and use it, the method of
#xref-to("repertoire", "estimation-answers").

The arithmetic, mine, from stated assumptions. Three billion users,
an average of 400 friends each, 5 new friendships per user per year.
The friends-of-friends pool for one user is 400 times 400, 160k raw
candidates, which is why candidate generation is offline batch work,
never a live 2-hop walk. Edge writes are 3 billion times 5 a year,
about 500 per second steady, spiking with the news. The adjacency
store is 3 billion users times 400 edges at 8 bytes each, doubled
for both directions, about 19 TB raw, call the band 10 to 20 TB
varint compressed. The candidate lists, 200 entries
at 8 bytes for 3 billion users, are about 5 TB per replica. And the
write fanout is the news feed's arithmetic applied to a graph, one
new edge disturbs the 2-hop view of up to 800 neighbors, the two
400-friend sides, which is exactly the fanout storm of
#xref-to("repertoire", "design-prompts") read sideways.

#flow(
  [candidates precomputed offline, the online path one ranked read],
  node((0, 0), [client]),
  node((0, 1.2), [recs api]),
  node((0, 2.4), [ranker, #linebreak() filter known edges]),
  node((0, 3.6), [candidate store, #linebreak() top k per user]),
  node((2.2, 3.6), [batch counter, #linebreak() common friends]),
  node((0, 4.8), [edge log, #linebreak() friendship events]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((2.2, 3.6), (0, 3.6), "->"),
  edge((0, 4.8), (2.2, 3.6), "->"),
)

The walk over hops. Friendship events land in an append-only edge
log. A batch job counts common friends per pair, the
friends-of-friends table, and writes the top k candidates per user
into the candidate store, a kv read at serve time. The ranker blends
common friend count with interaction recency and entity signals like
shared workplace or school. The filter removes existing edges and
blocks last, cheap set lookups. The online path touches no graph at
all.

The bottleneck, volunteered: the 2-hop expansion at recompute, 160k
candidates per user, plus the 800-neighbor invalidation per new edge.
Both stay offline, and the hybrid resolution is the feed's: recompute
on edge events for active users, on cron for the rest, pull for
inactive users whose lists are never read.

Traps, one line each. Friends-of-friends alone is a popularity
contest, cap the contribution of any single friend or one
influencer floods every list. Freshness is a product promise, an
hour-old friendship should surface, so the recompute triggers on the
edge event, not the nightly batch alone. Cold start has no graph
signal, fall back to entity graphs, workplace, school, city. Ranking
without the last-minute filter shows users their existing friends,
and that bug ships embarrassingly often.

== design: notifications at scale [DRILL]

The requirements. Deliver events, likes, comments, mentions, group
posts, to recipients across push, in-app, email, and sms, with a
per-user ordered inbox, dedupe, per-channel caps, and quiet hours.
At-least-once delivery with idempotent handling, the semantics of
#xref-to("repertoire", "distributed-answers"). The chat card of
#xref-to("repertoire", "design-prompts") is the real-time sibling
already worked there, and the events inventory floors on
#xref-to("repertoire", "design-answers").

The arithmetic, mine, from stated assumptions. Two billion daily
actives generating 20 notification-worthy events each per day is 40
billion notifications a day, about 460k per second sustained, and a
morning peak of 2 to 3x lands near 1.4 million per second. At 1 KB an
entry that is 40 TB a day, and 7 days of online retention is about
280 TB, call the band 300 to 600 TB with a replica.

#flow(
  [events through a bus to fanout, per-channel workers behind the caps],
  node((0, 0), [clients, #linebreak() push, in-app, email, sms]),
  node((0, 1.2), [delivery workers, #linebreak() caps, quiet hours]),
  node((0, 2.4), [fanout service, #linebreak() one entry per recipient]),
  node((0, 3.6), [event bus, #linebreak() queue, replay]),
  node((0, 4.8), [producer services, #linebreak() likes, mentions, posts]),
  node((2.2, 2.4), [inbox log, #linebreak() per user, ordered]),
  edge((0, 4.8), (0, 3.6), "->"),
  edge((0, 3.6), (0, 2.4), "->"),
  edge((0, 2.4), (0, 1.2), "->"),
  edge((0, 2.4), (2.2, 2.4), "->"),
  edge((0, 1.2), (0, 0), "->"),
)

The walk over hops. Producer services emit domain events to a bus,
never straight to delivery, the queue-first contract. The fanout
service expands one event to its recipient list, writing one inbox
entry per recipient with an idempotency key of event id plus
recipient. Delivery workers poll the inbox per channel, respect the
caps and quiet hours, and call the platform gateways, APNs and FCM
for push, providers for email and sms. The in-app read path is the
same inbox log. A failed provider call retries with jittered backoff
and a circuit breaker, the resilience pattern of
#xref-to("patterns", "resilience").

The bottleneck, volunteered: the viral burst. One post by a user with
a million followers is a million fanout writes in a moment, and no
worker pool absorbs it unshaped. The answer is collapse rules, "5
others liked your post", merged at fanout, which cuts write volume by
the merge factor and is a product decision that outperforms any
infrastructure choice on this path.

Traps, one line each. Exactly-once is a claim to refuse, at-least-once
plus idempotency keys is the honest contract. Push tokens rotate and
die, store them versioned and reap the dead or the bounce rate poisons
the channel. Quiet hours and caps are product requirements, not
optimizations, they define the deliverable. Read receipts and open
tracking feed the loop, but the notification log is append-only, the
ordering contract of the inbox.

sources: every count in this chapter traces to the pinned page bytes
at `ref/prachub/meta/page.md`, fetched 2026-10-15 from
https://prachub.com/companies/meta/, and the transcription at
`ref/prachub/meta/facts.md`. The page's own numbers are the company
numbers, the header counter 1.2k, the intro paragraph 1,206, against
the companies index rollup 1,111, and each is named to its surface
where it appears. Only page 1 of the 61 list pages is public, its 20
visible card titles, and both worked prompts are authored from those
truncated titles alone, with no premium-gated body quoted,
paraphrased, or reconstructed. The AI-enabled coding round pilot
cites the pin already in this book's coverage sources, accessed
2026-09-10, not re-sourced here. The estimation arithmetic in both
design walkthroughs is mine, stated assumptions per the method of
#xref-to("repertoire", "estimation-answers"), and no company count
was invented anywhere a count is absent.
