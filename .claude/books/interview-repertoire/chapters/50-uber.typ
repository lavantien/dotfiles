#import "../../theme/lib.typ": listing, callout, xref-to, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at uber

Uber's page will not count its own loop. The header says 331 questions,
updated 10.06.2026, the companies index rolls the same company up to
210, the footer links all 57 first-hand experiences, and the question
list runs 17 pages, but no numeric round count and no numeric
difficulty count appears anywhere on the page, the FAQ's prose is the
whole characterization. This chapter maps that prose loop, works 2
coding prompts test-first in go, the real-time top-k ranking system,
the flagship at 441 likes and 5776 solved, and the k smallest squares
of a sorted array, and walks 2 marketplace
design prompts in the #xref-to("repertoire", "design-prompts") voice,
the real-time nearby-driver service and the data flow behind a food
delivery app's restaurant list, because every preparation subtopic the
FAQ names is a two-sided market on a map.

== the loop map [DRILL]

The FAQ carries the sequence in prose, quoted verbatim: `The typical Uber hiring sequence starts with a recruiter screen, followed by one or two technical phone or take-home assessments for some roles, then an onsite or virtual loop of four to six interviews and a hiring-committee review.` Timelines `usually span three to six weeks`, the same paragraph's phrase. That is the whole map, and the honesty to keep is that the counts the other pages in this arc publish as spread tables are absent here by name: round distribution is not displayed as counts, difficulty is not either, and the added-in-last-90-days and AI-assisted fields that other pages display are not displayed at all.

The header counter says 331 questions, updated 10.06.2026. The
question list shows 20 results on page 1 of 17. The footer link says
`All 57 Uber interview experiences`, 8 of them visible on page 1. The
FAQ's one concession to numbers is preparation weeks, not rounds, and
it is worth keeping because it is the only duration the page
publishes: six to twelve for software engineers, three to six for
data scientists, four to eight for machine learning engineers, two to
four for technical program managers.

== the bank [DRILL]

Roles, explore-more block, the one surface on this page that carries
role counts: Software Engineer 188, Data Scientist 109, Machine
Learning Engineer 26. Categories, same block: Coding & Algorithms
157, Analytics & Experimentation 46, System Design 36, Machine
Learning 21, Behavioral & Leadership 19, Statistics & Math 18,
Software Engineering Fundamentals 17. The coding bank alone outnumbers
the next 3 categories combined, 157 against 103, and the
analytics-and-experimentation bank sitting second at 46 is the
marketplace's own signature, one of only 2 loops in this arc where
experimentation outranks system design, meta's the other.

Difficulty, prose only, the FAQ's characterization verbatim where it
binds: questions `range from moderate to very challenging depending
on role and level`, software engineer rounds `emphasize data
structures, algorithms and system-design problems that often require
multi-step solutions and production tradeoffs`, so expect `mid-to-hard coding and design tasks`. The one countable difficulty
signal is a page-1 observation, surface named: 11 of the 20 visible
cards are tagged Hard.

== quirks of this loop [DRILL]

The marketplace is the frame, and the FAQ names its subtopics itself.
Software engineers should concentrate on `queue design for
pickup-area driver matching` and `product-oriented designs like
global nearby-restaurant search`. Data scientists drill marketplace
evaluation, `driver acceptance, membership and priority delivery
impact`. Machine learning engineers add `pickup-location
optimization`. Technical program managers rehearse `unclear-address
resolution`. Supply and demand meeting on a map is the one thread
through all of it, which is why both design walkthroughs below are
geo systems.

The 8 visible first-hand experiences set the tempo, and 2 of them
pair with visible cards. `Four Onsite Rounds, All About the
Follow-Ups` is the round shape to prepare for, the base question is
the entry ticket, the follow-up ladder is the grade. `45 Min Coding
Plus 15 Min Free-Form ML Design, Onsite Invite Next Day` records the
machine learning screen split. `Tracking the Earliest Unrepeated
Visitor` pairs with the visible earliest-id-once card. The rest: an
intern online assessment with a delivery-cost, truck-collision, and
org-tree broadcast problem, a phone screen then an onsite with graph
database design then silence, a three-level robot path optimization
screen, matrix swaps and infrastructure design at Senior+, and a
directory tree traversed with a manual stack, rejected.

== recurring prompts [DRILL]

Where each recurring shape floors in this corpus, by chapter id:

The 2 island cards, `Count Islands of Connected Land Cells in a
Binary Grid`, hard at 4 likes and 30 solved, and `Count Islands After
Each Land Addition to an All-Water Grid`, hard at 1 like and 21
solved, floor on the connected-regions battery of
#xref-to("repertoire", "classics1").

The robot-distance pair, `Find Robots by Nearest-Blocker Distances`,
hard, locked, 6 likes and 102 solved, and its four-direction twin,
plus `Sort a Matrix into Snake Order Using Adjacent Swaps`, hard at 2
likes and 35 solved, floor on the grid walks of
#xref-to("repertoire", "graphs").

The heap under the ranking flagship worked below and the linked-list
walk behind `Return the Earliest ID Seen Exactly Once`, medium at 3
likes and 28 solved, floor on the implemented structures of
#xref-to("repertoire", "datastructures").

Two pointers and binary search own the squares card worked below,
plus the 2 next most engaged cards on the page, `Solve These
Algorithmic Problems`, medium at 68 likes and 544 solved, and
`Determine Balanced k Values in a Permutation`, medium at 47 likes
and 379 solved, all flooring on
#xref-to("repertoire", "algopatterns").

`Answer Repeated Shortest Increasing-Path Queries`, hard at Senior+,
6 likes and 44 solved, floors on
#xref-to("repertoire", "weightedgraphs").

The 2 parking lot cards, the check-in check-out design at hard, 1
like and 16 solved, and the plain system at medium, 0 likes and 6
solved, floor on the object model register of
#xref-to("repertoire", "paradigms").

The marketplace designs walked below floor on the geo predicate of
#xref-to("repertoire", "db-answers") and the sharding of
#xref-to("patterns", "partitioning"), and the graph-database
permissions card, medium at 0 likes and 14 solved, floors on the
modeling half of the same database chapter. The prompt protocol
itself is #xref-to("repertoire", "design-prompts") and the register
it drills is #xref-to("repertoire", "design-answers").

== the real-time top-k ranking system, worked [TDD]

The visible card is titled `Design a Real-Time Top-K Ranking System`,
hard, tagged Software Engineering Fundamentals, Data Structure Design,
and Concurrency, 441 likes, 2 comments, 5776 solved, dated May 2
2026, the most engaged card on the page by likes and by solves, more
than 6 times the likes of any other visible card. The premium body is
gated, so the prompt is authored from the title and the tags: a
stream of engagement events lands on named items, a fixed k is given,
maintain the k highest-scoring items, answer snapshot queries, and
survive concurrent writers and readers.

The structure is a score map over every item beside a bounded
min-heap of the k best, ranked worst-first so the root is the weakest
member, ties broken by item id so the set is deterministic. Every
event is one `Add` at O(log k):

#listing("interview-repertoire/samples/ch50-go/topk.go", first: 44, last: 76, caption: [add: a member only improves and sifts down, an outsider enters only by outranking the root and evicts it in one swap, overflow checked before any state moves])

Two contract decisions are load-bearing and worth saying aloud. Deltas
are positive only: a decrement would let a member fall below
outsiders without leaving the heap, and the lazy repair is a rebuild,
so the honest contract is increments, the natural shape for
engagement events anyway. Membership is then an invariant, not a
guess: scores only rise, so a member stays top-k until an outsider
beats the weakest member, and an evicted item keeps its score in the
map, re-entry is just another `Add`. The heap discipline that holds
the invariant, with the position map maintained through every swap:

#listing("interview-repertoire/samples/ch50-go/topk.go", first: 100, last: 132, caption: [the worst-first heap, up and down with the position map rewritten on every swap])

Snapshot reads copy under the same mutex and sort k entries, a
consistent point-in-time answer that never sees a half-applied event.
The suite is 8 test functions under `go vet` and `go test -race`, and
the oracle discipline is a brute-force ranking computed in the test
from a plain map, sharing no code with the heap, 200 seeded random
rounds at every k from 1 to 6:

#listing("interview-repertoire/samples/ch50-go/topk_test.go", first: 114, last: 137, caption: [the differential: seeded random event streams, the brute-force top-k against the heap's answer])

Beside the differential, a structural audit walks the heap after
every 97th op of a 3000-op random stream checking the
parent-worse-than-child order, the position map against the slots,
and the scores map against both, and the concurrency test runs 8
writers over 40 items with snapshot readers interleaved, final state
asserted against the brute force of known totals, green under the
race detector. Hand-built tables pin the rest: eviction and re-entry
in 5 narrated steps, tie order by id, rejection without state change
for a non-positive delta and for the int64 overflow at MaxInt64. The
red run came first, 11 of the 12 functions failing against a stub
that compiled the fields and answered every call with a no-op, the
12th, the squares brute-force differential, passing vacuously against
the empty stub, which is why the differential exists.

== the k smallest squares of a sorted array, worked [TDD]

The visible card is titled `Return the k Smallest Squares of a Sorted
Integer Array in Order`, hard, 4 likes, 0 comments, 33 solved, dated
Sep 29 2026, tagged Coding & Algorithms, Binary Search, Two Pointers
& Sliding Window. The premium body is gated, so the prompt is
authored from the title: an array sorted ascending, negatives
allowed, return the k smallest squared values, ascending.

Squaring turns one sorted run into 2: the negatives descend in
absolute value as the index rises, the non-negatives ascend, and the
smallest squares live at the seam. The walk finds that seam with one
binary search, the first non-negative slot, then 2 pointers walk
outward from it, one deeper into the negatives, one up through the
non-negatives, always emitting the smaller absolute value, squared at
emit, stopping at k. Emission is non-decreasing because each pointer
walks a monotone run and the merge picks the smaller head, so the
output is in order with no sort at all, log n plus k work. Both
halves floor on #xref-to("repertoire", "algopatterns"), the search
family and the two-pointer family:

#listing("interview-repertoire/samples/ch50-go/squares.go", first: 16, last: 53, caption: [the seam by binary search, the outward walk emitting the smaller magnitude squared, the overflow bound checked only where a square is actually taken])

The guards are the interview's real questions. k below 1 and k past
the length are refused. An unsorted input is rejected by a linear
contract check on an O(log n + k) answer, kept because a silently
wrong list costs more than one pass. The overflow bound is 3037000499,
whose square is the largest that fits int64, and it is checked at
emit only, a magnitude never squared is never checked, so an array
holding -4000000000 still answers k=1 correctly off its small tail.
The suite is 4 test functions: a 10-fact table hand-derived, the
contract errors, the overflow boundary pair with the
never-squared escape, and the differential, 400 seeded arrays up to
40 elements across the signed range at every k from 1 to n against a
square-all, sort, take-k brute force:

#listing("interview-repertoire/samples/ch50-go/squares_test.go", first: 80, last: 104, caption: [the differential: seeded arrays, every k, the brute-force k smallest squares against the seam walk])

== the real-time nearby-driver service [DRILL]

From the visible card, `Design a Real-Time Nearby-Driver Service`,
medium, locked, 30 likes, 201 solved, dated Aug 16 2026, tagged
System Design, Geo & Delivery Systems, Partitioning & Consistent
Hashing. The body is premium-gated, so the prompt is authored from
the title and the tags: riders ask for drivers near a pickup point,
driver locations stream in continuously, the answer must be fresh to
seconds. Requirements: enroll driver fixes, answer radius queries
ranked by distance, survive a shard loss without a metro going dark.
Non-functional: p99 read under 100 ms, the write stream absorbed
without backpressure reaching phones, hot spots survivable.

The estimation, assumptions stated, arithmetic this chapter's own in
the method of #xref-to("repertoire", "estimation-answers"). Assume
100k online drivers in a metro, each phone emitting a fix every 4
seconds: 25k location writes a second steady, the number that decides
the shape. Assume 20k riders actively hailing, refreshing their map
every 5 seconds: 4k nearby reads a second, 1 read per 6 writes, so
the write stream is the wall and the read path is a cache problem
beside it. Driver state at 64 bytes is 6.4 MB for the metro, one
process's memory, which is why the shard boundary is the cell, not
the machine. A 60 km by 40 km metro at 1 km cells is 2400 cells,
about 40 drivers a cell on average, and a 3 km radius search touches
the 29 cells whose centers lie inside it, 45 if the ring counts
every cell it grazes.

#flow(
  [fixes shard by cell on a consistent hash ring, searches fan out to the cells in radius],
  node((0, 0), [driver app, #linebreak() fix every 4 s]),
  node((0, 1.2), [ingest api, #linebreak() 25k writes a second]),
  node((0, 2.4), [cell router, #linebreak() consistent hash on cell]),
  node((0, 3.6), [cell shard, #linebreak() drivers in memory]),
  node((0, 4.8), [replica, #linebreak() failover, lag bounded]),
  node((2.4, 2.4), [rider app]),
  node((2.4, 3.6), [search api, #linebreak() radius to cells, merge]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((2.4, 2.4), (2.4, 3.6), "->"),
  edge((2.4, 3.6), (0, 3.6), "->", label: [read the cells in radius]),
)

The walk over hops: the driver phone emits a fix every 4 seconds, the
ingest api stamps it and derives the cell, the router places the
write on the consistent-hash ring, the owning shard keeps the
driver's record in memory and streams it to a replica whose lag is
bounded and watched, a rider search expands its coordinates to the
cells in radius, fans out to the owning shards, and merges the
candidates by haversine distance at the search api, never inside the
store. The ring itself is #xref-to("patterns", "partitioning") and
the distance predicate and the cell shapes floor on the geo answers
of #xref-to("repertoire", "db-answers").

The bottleneck, volunteered: skew, not volume. The airport cell holds
hundreds of idling drivers and every search near it, so one shard on
the ring runs hot while its neighbors idle. The answer is cell
splitting, the same ring carrying finer subcell keys for dense cells,
with the search taking nearest subcells first so the fan-out cap
holds even where the density does not.

The traps, 1 line each. Staleness is a contract with 2 tiers, a 4
second old fix serves the map, matching re-reads the live record
before the offer locks. Ownership moves with the driver, not the
phone, a fix from the wrong cell is a routing bug that strands the
record. Distance at the merge, the store answers sets, not
arithmetic. A driver that goes offline mid-search is a filtered
record minutes later, pair the location stream with a presence ttl.
The rebalance storm when the fleet grows is the ring's own cost,
virtual nodes and a slow migration window, say it before the
interviewer does.

== the data flow behind the restaurant list [DRILL]

From the visible card, `Design the Data Flow Behind a Food Delivery
App's Restaurant List`, hard, 1 like, 0 comments, 27 solved, dated
Sep 29 2026, tagged System Design, Geo & Delivery Systems, Caching.
The prompt is authored from the title: the list is the product's
front door, and the design question is the flow that keeps it fresh,
ranked, and fast. Requirements: eaters see open, deliverable
restaurants near them with an eta and a rank, restaurants mutate
hours, prep time, inventory, and promotions continuously, and a
closed kitchen must leave the list within seconds. Non-functional:
list p99 under 200 ms, per-city cache coherence, the write side
never blocking the read side.

The estimation, assumptions stated, arithmetic this chapter's own.
Assume a metro of 20k restaurants at 2 KB a record: 40 MB of shared
state per city, one cache node's memory, which is the whole reason
the cache key is the city, never the user. Assume 200k active eaters
at dinner peak refreshing every 20 seconds: 10k list reads a second
per metro. The write side is quiet by comparison, one mutation per
restaurant per minute across the fleet is 333 writes a second, each
fanning one invalidation, so the design's hard part is coherence,
not capacity.

#flow(
  [writes flow through an ordered log, reads hit the versioned city cache],
  node((0, 0), [eater app]),
  node((0, 1.2), [list api, #linebreak() geo cells, cursor]),
  node((2.2, 1.2), [ranking merge, #linebreak() distance, prep, courier eta]),
  node((0, 2.4), [city cache, #linebreak() versioned, 40 MB]),
  node((0, 3.6), [projector, #linebreak() city store]),
  node((2.2, 3.6), [invalidation bus, #linebreak() idempotent]),
  node((0, 4.8), [change log, #linebreak() ordered, replayable]),
  node((0, 6.0), [restaurant ops, #linebreak() hours, prep, promos]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (2.2, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->", label: [candidates]),
  edge((0, 4.8), (0, 3.6), "->"),
  edge((0, 6.0), (0, 4.8), "->"),
  edge((0, 3.6), (0, 2.4), "->", label: [rebuild]),
  edge((0, 3.6), (2.2, 3.6), "->"),
  edge((2.2, 3.6), (0, 2.4), "-|>", label: [bump version]),
)

The walk over hops: a restaurant mutation lands on the ordered change
log, the projector folds it into the city store and bumps a version,
the invalidation bus carries the version to the city caches
idempotently, because restaurant state flaps and a replayed
invalidation must be free, the list api expands the eater's location
to geo cells, pulls candidate restaurants from the versioned city
cache, and hands them to the ranking merge, which orders by distance,
prep time, and courier eta and returns a cursor-paginated page. The
geo candidate predicate floors on
#xref-to("repertoire", "db-answers").

The bottleneck, volunteered: freshness of the open and closed
signals, not read volume. A closed kitchen staying on the list for
minutes manufactures orders that cannot be fulfilled, the exact
defect the invalidation path exists to prevent, so its lag is the
metric to alarm on while the read path hums at 10k a second off one
cache node.

The traps, 1 line each. Cursor pagination, an offset into a re-ranked
list lies the moment ranking shifts, and the cursor carries the
ranking version it was built under. Cache per city, a per-user cache
multiplies 40 MB by the eater count for zero reuse. The eta is a
prediction, render a band, a promise converts a model's variance into
a support ticket. Prep time is the restaurant's own report, weight it
against observed fulfillment or the slow kitchen drifts up the
ranking. Cold-start cities rebuild from the change log, replay is the
backfill, a snapshot is just a replay that finished.

#callout("pitfall", "the page that will not count itself", [
  Uber's page publishes no numeric round counts and no numeric
  difficulty counts, the FAQ prose is the only characterization, and
  the 2 freshness fields other pages in this arc display, added in
  the last 90 days and AI-assisted, are not displayed here, absent is
  the honest reading, never zero. Meanwhile the companies index
  rolls the same company up to 210 questions while the page's own
  header says 331, updated 10.06.2026, a gap of 121. The page's own
  count is the company number everywhere in this arc, the rollup is
  a stale measurement published with no method, and the one
  countable difficulty signal left is the page-1 observation with
  its surface named, 11 of the 20 visible cards tagged Hard.
])

sources: every count in this chapter traces to
`ref/prachub/uber/page.md`, fetched 2026-10-15 from
prachub.com/companies/uber/ and pinned verbatim, through the
transcription at `ref/prachub/uber/facts.md`, with the companies-index
rollup read from the pinned index bytes at `ref/prachub/index.md`.
The worked prompts are authored from visible truncated card titles
only, premium-gated bodies never quoted or reconstructed, and both
design walkthroughs carry their arithmetic as stated assumptions in
the #xref-to("repertoire", "estimation-answers") method, arithmetic
this chapter's own, not numbers from the page. No other online
source was consulted for this chapter.
